#!/usr/bin/env python3
"""
Workflow Validation Script
Validates n8n workflow JSON files for production readiness.

Checks:
1. Naming conventions
2. SQL tenant_id presence in Postgres nodes
3. No forbidden node types (native Google Calendar)
4. errorWorkflow settings in main workflows
5. Placeholder syntax for credentials
6. No $env fallbacks in tool workflows
7. Disabled nodes report
"""

import json
import os
import re
import sys
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"
MAIN_DIR = WORKFLOWS_DIR / "main"
TOOLS_DIR = WORKFLOWS_DIR / "tools"
SUB_DIR = WORKFLOWS_DIR / "sub"

FORBIDDEN_NODE_TYPES = [
    "n8n-nodes-base.googleCalendar",
    "n8n-nodes-base.googleCalendarTrigger",
]

PLACEHOLDER_PATTERN = re.compile(r"\{\{[A-Z_]+\}\}")
RAW_CREDENTIAL_ID_PATTERN = re.compile(r'"id":\s*"[A-Za-z0-9]{16}"')
ENV_FALLBACK_PATTERN = re.compile(r"\$env\.")

# These $env references are allowed (infrastructure-level, not tenant-specific)
ALLOWED_ENV_REFS = [
    "$env.FALLBACK_TELEGRAM_CHAT_ID",
    "$env.N8N_WEBHOOK_URL",
    "$env.ERROR_WORKFLOW_ID",
]


class ValidationResult:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.info = []

    def error(self, file: str, msg: str):
        self.errors.append(f"ERROR [{file}]: {msg}")

    def warn(self, file: str, msg: str):
        self.warnings.append(f"WARN  [{file}]: {msg}")

    def note(self, file: str, msg: str):
        self.info.append(f"INFO  [{file}]: {msg}")

    @property
    def ok(self):
        return len(self.errors) == 0


def load_workflow(path: Path):
    try:
        with open(path) as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        return None


def check_naming(path: Path, result: ValidationResult):
    """Check workflow file naming conventions."""
    name = path.stem
    parent = path.parent.name

    if parent == "main":
        if not re.match(r"^\d{2}-", name):
            result.warn(path.name, f"Main workflow should match XX-name pattern: {name}")
    elif parent != ".claude":
        if not name.endswith("-tool") and parent != "sub" and not name.endswith("-client"):
            result.note(path.name, f"Tool workflow name does not end with '-tool': {name}")


def check_forbidden_nodes(wf: dict, filename: str, result: ValidationResult):
    """Check for forbidden node types."""
    for node in wf.get("nodes", []):
        node_type = node.get("type", "")
        if node_type in FORBIDDEN_NODE_TYPES:
            result.error(filename, f"Forbidden node type '{node_type}' in node '{node.get('name')}'")


def check_tenant_id_in_sql(wf: dict, filename: str, result: ValidationResult):
    """Check that Postgres nodes include tenant_id in queries."""
    for node in wf.get("nodes", []):
        node_type = node.get("type", "")
        if "postgres" not in node_type.lower():
            continue

        params = node.get("parameters", {})
        query = params.get("query", "")

        # Skip nodes that don't run queries
        if not query or params.get("operation") not in ("executeQuery", None):
            continue

        # Check for tenant_id in query
        if "tenant_id" not in query.lower() and "tenant" not in query.lower():
            node_name = node.get("name", "unknown")
            # Skip system-level queries (e.g., cleanup functions)
            if any(kw in query.lower() for kw in ["cleanup_expired", "release_conversation", "acquire_conversation", "enqueue_message"]):
                continue
            result.warn(filename, f"Postgres node '{node_name}' query may be missing tenant_id filter")


def check_error_workflow(wf: dict, filename: str, result: ValidationResult):
    """Check that main workflows have errorWorkflow configured."""
    settings = wf.get("settings", {})
    error_wf = settings.get("errorWorkflow", "")

    if not error_wf:
        result.error(filename, "Missing settings.errorWorkflow")
    elif "{{ERROR_HANDLER_WORKFLOW_ID}}" not in error_wf and "04" not in error_wf:
        result.warn(filename, f"errorWorkflow may not point to canonical error handler: {error_wf}")


def check_credentials(wf: dict, filename: str, result: ValidationResult):
    """Check credential references use placeholder syntax."""
    raw = json.dumps(wf)

    # Check for raw credential IDs (16-char alphanumeric that aren't UUIDs)
    for node in wf.get("nodes", []):
        creds = node.get("credentials", {})
        for cred_type, cred_val in creds.items():
            cred_id = cred_val.get("id", "")
            # Skip placeholders
            if "{{" in cred_id and "}}" in cred_id:
                continue
            # Skip empty
            if not cred_id:
                continue
            # Flag non-placeholder credential IDs
            if re.match(r"^[A-Za-z0-9]{10,20}$", cred_id):
                result.warn(filename, f"Credential '{cred_type}' in node '{node.get('name')}' has non-placeholder ID: {cred_id}")


def check_env_fallbacks(wf: dict, filename: str, result: ValidationResult):
    """Check for $env fallbacks in tool workflows."""
    raw = json.dumps(wf)

    matches = ENV_FALLBACK_PATTERN.findall(raw)
    for match in matches:
        # Check if this is an allowed $env reference
        if any(allowed in raw[max(0, raw.index(match) - 50):raw.index(match) + 80] for allowed in ALLOWED_ENV_REFS):
            continue
        result.warn(filename, f"Found $env reference: ...{match}...")


def check_disabled_nodes(wf: dict, filename: str, result: ValidationResult):
    """Report disabled nodes."""
    for node in wf.get("nodes", []):
        if node.get("disabled"):
            result.note(filename, f"Disabled node: '{node.get('name')}' (type: {node.get('type')})")


def validate_file(path: Path, result: ValidationResult, is_main: bool = False, is_tool: bool = False):
    """Validate a single workflow file."""
    wf = load_workflow(path)
    if wf is None:
        result.error(path.name, "Invalid JSON")
        return

    filename = path.name

    check_naming(path, result)
    check_forbidden_nodes(wf, filename, result)
    check_tenant_id_in_sql(wf, filename, result)
    check_credentials(wf, filename, result)
    check_disabled_nodes(wf, filename, result)

    if is_main:
        # Skip error handler itself for errorWorkflow check
        if "error-handler" not in filename:
            check_error_workflow(wf, filename, result)

    if is_tool:
        check_env_fallbacks(wf, filename, result)


def main():
    result = ValidationResult()
    files_checked = 0

    print("=" * 60)
    print("  n8n Workflow Validation")
    print("=" * 60)
    print()

    # Validate main workflows
    if MAIN_DIR.exists():
        for f in sorted(MAIN_DIR.glob("*.json")):
            validate_file(f, result, is_main=True)
            files_checked += 1

    # Validate sub workflows
    if SUB_DIR.exists():
        for f in sorted(SUB_DIR.glob("*.json")):
            validate_file(f, result)
            files_checked += 1

    # Validate tool workflows (recursive)
    if TOOLS_DIR.exists():
        for f in sorted(TOOLS_DIR.rglob("*.json")):
            if ".claude" in str(f):
                continue
            validate_file(f, result, is_tool=True)
            files_checked += 1

    # Print results
    print(f"Files checked: {files_checked}")
    print()

    if result.info:
        print("--- Info ---")
        for msg in result.info:
            print(f"  {msg}")
        print()

    if result.warnings:
        print("--- Warnings ---")
        for msg in result.warnings:
            print(f"  {msg}")
        print()

    if result.errors:
        print("--- Errors ---")
        for msg in result.errors:
            print(f"  {msg}")
        print()

    print("=" * 60)
    if result.ok:
        print(f"  PASSED ({files_checked} files, {len(result.warnings)} warnings)")
    else:
        print(f"  FAILED ({len(result.errors)} errors, {len(result.warnings)} warnings)")
    print("=" * 60)

    return 0 if result.ok else 1


if __name__ == "__main__":
    sys.exit(main())
