#!/usr/bin/env python3
"""
Import workflows to n8n automatically
Requires: requests library (pip install requests)
"""
import json
import os
import sys
import glob
from pathlib import Path
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configuration
N8N_URL = os.getenv("N8N_URL", "http://localhost:5678")
N8N_API_KEY = os.getenv("N8N_API_KEY", "")
WORKFLOWS_DIR = "workflows"

# Colors for output
class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def print_status(message, color=Colors.BLUE):
    print(f"{color}{message}{Colors.NC}")

def print_success(message):
    print_status(f"✅ {message}", Colors.GREEN)

def print_error(message):
    print_status(f"❌ {message}", Colors.RED)

def print_warning(message):
    print_status(f"⚠️  {message}", Colors.YELLOW)

def create_session():
    """Create requests session with retry strategy"""
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session

def check_n8n_health(session):
    """Check if n8n is accessible"""
    try:
        response = session.get(f"{N8N_URL}/healthz", timeout=5)
        return response.status_code == 200
    except Exception as e:
        print_error(f"n8n is not accessible: {e}")
        return False

def get_existing_workflows(session):
    """Get list of existing workflows"""
    headers = {}
    if N8N_API_KEY:
        headers["X-N8N-API-KEY"] = N8N_API_KEY
    
    try:
        response = session.get(f"{N8N_URL}/api/v1/workflows", headers=headers, timeout=10)
        if response.status_code == 200:
            return {wf["name"]: wf["id"] for wf in response.json().get("data", [])}
        elif response.status_code == 401:
            print_warning("API requires authentication")
            return None
        else:
            print_warning(f"Could not fetch existing workflows: {response.status_code}")
            return {}
    except Exception as e:
        print_warning(f"Error fetching workflows: {e}")
        return {}

def import_workflow(session, workflow_path, existing_workflows=None):
    """Import a single workflow"""
    headers = {"Content-Type": "application/json"}
    if N8N_API_KEY:
        headers["X-N8N-API-KEY"] = N8N_API_KEY
    
    try:
        # Read workflow file
        with open(workflow_path, 'r', encoding='utf-8') as f:
            workflow_data = json.load(f)
        
        workflow_name = workflow_data.get("name", Path(workflow_path).stem)
        
        # Check if workflow already exists
        if existing_workflows and workflow_name in existing_workflows:
            workflow_id = existing_workflows[workflow_name]
            # Update existing workflow
            response = session.put(
                f"{N8N_URL}/api/v1/workflows/{workflow_id}",
                headers=headers,
                json=workflow_data,
                timeout=30
            )
            if response.status_code in [200, 201]:
                return True, "updated"
            else:
                return False, f"HTTP {response.status_code}: {response.text[:100]}"
        else:
            # Create new workflow
            response = session.post(
                f"{N8N_URL}/api/v1/workflows",
                headers=headers,
                json=workflow_data,
                timeout=30
            )
            if response.status_code in [200, 201]:
                return True, "created"
            else:
                return False, f"HTTP {response.status_code}: {response.text[:100]}"
    
    except FileNotFoundError:
        return False, "File not found"
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, str(e)

def main():
    print_status("🚀 n8n Workflow Importer", Colors.BLUE)
    print_status(f"n8n URL: {N8N_URL}")
    print()
    
    # Check n8n health
    session = create_session()
    if not check_n8n_health(session):
        print_error("n8n is not accessible. Make sure it's running.")
        sys.exit(1)
    print_success("n8n is accessible")
    
    # Get existing workflows
    print_status("📋 Checking existing workflows...")
    existing_workflows = get_existing_workflows(session)
    if existing_workflows is None:
        print_warning("Could not authenticate. Trying import anyway...")
        existing_workflows = {}
    
    # Find all workflow JSON files
    workflow_files = sorted(glob.glob(f"{WORKFLOWS_DIR}/**/*.json", recursive=True))
    if not workflow_files:
        print_error(f"No workflow files found in {WORKFLOWS_DIR}/")
        sys.exit(1)
    
    print_status(f"📦 Found {len(workflow_files)} workflows to import")
    print()
    
    # Import workflows
    imported = 0
    updated = 0
    failed = 0
    
    for workflow_path in workflow_files:
        workflow_name = Path(workflow_path).name
        print_status(f"Importing {workflow_name}...", Colors.BLUE)
        
        success, message = import_workflow(session, workflow_path, existing_workflows)
        
        if success:
            if message == "updated":
                print_success(f"Updated: {workflow_name}")
                updated += 1
            else:
                print_success(f"Imported: {workflow_name}")
                imported += 1
        else:
            print_error(f"Failed: {workflow_name} - {message}")
            failed += 1
        print()
    
    # Summary
    print_status("╔═══════════════════════════════════════════════════════════════╗", Colors.BLUE)
    print_status("║                    Import Summary                             ║", Colors.BLUE)
    print_status("╚═══════════════════════════════════════════════════════════════╝", Colors.BLUE)
    print_success(f"Imported: {imported}")
    if updated > 0:
        print_status(f"Updated: {updated}", Colors.YELLOW)
    if failed > 0:
        print_error(f"Failed: {failed}")
        sys.exit(1)
    else:
        print_success("All workflows imported successfully!")
        print()
        print_status("📝 Next steps:")
        print_status("1. Open n8n UI: http://localhost:5678")
        print_status("2. Configure credentials (see CONFIGURACAO_POS_IMPORT.md)")
        print_status("3. Activate main workflows:")
        print_status("   - 01 - WhatsApp Patient Handler (AI Optimized)")
        print_status("   - 04 - Error Handler")

if __name__ == "__main__":
    main()
