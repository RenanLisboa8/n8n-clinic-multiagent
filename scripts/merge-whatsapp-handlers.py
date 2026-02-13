#!/usr/bin/env python3
"""
Merge two WhatsApp handler workflows into 01-whatsapp-main.json.

Architecture:
- State machine backbone (from state-machine handler) as control flow
- 3-layer defense (FAQ → Template → AI) within AI-processing states (from AI handler)
- All AI agent tools preserved from AI handler
- Uses tenant-config-loader sub-workflow
- Placeholder credential IDs ({{POSTGRES_CREDENTIAL_ID}}, etc.)
"""

import json
import copy
import os
import uuid

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
WORKFLOWS_DIR = os.path.join(PROJECT_ROOT, "workflows", "main")

SM_FILE = os.path.join(WORKFLOWS_DIR, "01-whatsapp-optimized-state-machine.json")
AI_FILE = os.path.join(WORKFLOWS_DIR, "01-whatsapp-patient-handler-optimized.json")
OUTPUT_FILE = os.path.join(WORKFLOWS_DIR, "01-whatsapp-main.json")


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def new_id():
    return str(uuid.uuid4())


def replace_credential_placeholders(node):
    """Replace hardcoded credential IDs with placeholder tokens."""
    node_str = json.dumps(node)
    # Known hardcoded Postgres credential IDs
    for cred_id in ["XCqM1aDUIHVebSzp", "9Rg0MgrsgZNRKTC0"]:
        node_str = node_str.replace(cred_id, "{{POSTGRES_CREDENTIAL_ID}}")
    # Known hardcoded OpenRouter credential IDs
    for cred_id in ["KuGKBDcL6dsjIWc0", "QfRFeOCfFzxb41Xh"]:
        node_str = node_str.replace(cred_id, "{{OPENROUTER_CREDENTIAL_ID}}")
    # Known hardcoded Evolution API credential IDs
    for cred_id in ["xQSYKSSdn2xKsrdJ"]:
        node_str = node_str.replace(cred_id, "{{EVOLUTION_CREDENTIAL_ID}}")
    return json.loads(node_str)


def get_node_by_name(nodes, name):
    for n in nodes:
        if n.get("name") == name:
            return n
    return None


def build_merged_workflow():
    sm = load_json(SM_FILE)
    ai = load_json(AI_FILE)

    sm_nodes = {n["name"]: n for n in sm["nodes"]}
    ai_nodes = {n["name"]: n for n in ai["nodes"]}

    # =========================================================================
    # MERGED NODES
    # =========================================================================
    merged_nodes = []

    # --- ENTRY SECTION (from AI handler - uses tenant-config-loader sub-workflow) ---

    # 1. WhatsApp Webhook (from AI handler - has proper webhookId)
    webhook = copy.deepcopy(ai_nodes["WhatsApp Webhook"])
    webhook["parameters"]["path"] = "whatsapp-main"
    webhook["webhookId"] = "whatsapp-main-handler"
    webhook["position"] = [0, 400]
    merged_nodes.append(webhook)

    # 2. Load Tenant Config (sub-workflow call from AI handler)
    tenant_loader = copy.deepcopy(ai_nodes["Load Tenant Config"])
    tenant_loader["position"] = [240, 400]
    merged_nodes.append(tenant_loader)

    # 3. Parse Webhook Data (from AI handler)
    parse = copy.deepcopy(ai_nodes["Parse Webhook Data"])
    parse["position"] = [480, 400]
    merged_nodes.append(parse)

    # 4. Message Type Switch (from AI handler - routes text/image/audio)
    msg_switch = copy.deepcopy(ai_nodes["Message Type Switch"])
    msg_switch["position"] = [720, 400]
    merged_nodes.append(msg_switch)

    # 5. Process Audio (from AI handler - disabled, will be enabled in Step 6)
    proc_audio = copy.deepcopy(ai_nodes["Process Audio"])
    proc_audio["position"] = [960, 600]
    merged_nodes.append(proc_audio)

    # 6. Process Image (from AI handler - disabled, will be enabled in Step 6)
    proc_image = copy.deepcopy(ai_nodes["Process Image"])
    proc_image["position"] = [960, 250]
    merged_nodes.append(proc_image)

    # --- STATE MACHINE SECTION (from state-machine handler) ---

    # 7. Get Conversation State (adapted from SM - uses tenant_id from Parse Webhook Data)
    get_state = copy.deepcopy(sm_nodes["Get Conversation State"])
    get_state["id"] = new_id()
    get_state["parameters"]["query"] = (
        "SELECT * FROM get_or_create_conversation_state("
        "'{{ $('Parse Webhook Data').item.json.tenant_id }}'::uuid, "
        "'{{ $('Parse Webhook Data').item.json.remote_jid }}'::varchar);"
    )
    get_state["position"] = [1200, 400]
    merged_nodes.append(get_state)

    # 8. Transition State (adapted from SM)
    transition = copy.deepcopy(sm_nodes["Transition State"])
    transition["id"] = new_id()
    transition["parameters"]["query"] = (
        "SELECT * FROM transition_conversation_state(\n"
        "  '{{ $('Parse Webhook Data').item.json.tenant_id }}'::uuid,\n"
        "  '{{ $('Parse Webhook Data').item.json.remote_jid }}',\n"
        "  '{{ $('Parse Webhook Data').item.json.message_text }}'\n"
        ");"
    )
    transition["position"] = [1440, 400]
    merged_nodes.append(transition)

    # 9. Requires AI? (from SM - checks transition result)
    requires_ai = copy.deepcopy(sm_nodes["Requires AI?"])
    requires_ai["id"] = new_id()
    requires_ai["position"] = [1680, 300]
    merged_nodes.append(requires_ai)

    # --- 3-LAYER DEFENSE BRANCH (for AI states - from AI handler) ---

    # 10. Intent Classifier (from AI handler)
    intent = copy.deepcopy(ai_nodes["Intent Classifier"])
    intent["position"] = [1920, 100]
    merged_nodes.append(intent)

    # 11. Check FAQ Cache (from AI handler)
    faq_cache = copy.deepcopy(ai_nodes["Check FAQ Cache"])
    faq_cache["position"] = [2160, 100]
    merged_nodes.append(faq_cache)

    # 12. Merge FAQ Result (from AI handler)
    merge_faq = copy.deepcopy(ai_nodes["Merge FAQ Result"])
    merge_faq["position"] = [2400, 100]
    merged_nodes.append(merge_faq)

    # 13. Needs AI? (from AI handler)
    needs_ai = copy.deepcopy(ai_nodes["Needs AI?"])
    needs_ai["position"] = [2640, 100]
    merged_nodes.append(needs_ai)

    # 14. Build Prompt with Catalog (from AI handler)
    build_prompt = copy.deepcopy(ai_nodes["Build Prompt with Catalog"])
    build_prompt["position"] = [2880, -100]
    merged_nodes.append(build_prompt)

    # 15. Patient Assistant Agent (from AI handler)
    agent = copy.deepcopy(ai_nodes["Patient Assistant Agent"])
    agent["position"] = [3360, -100]
    merged_nodes.append(agent)

    # 16. OpenRouter Chat Model (from AI handler)
    llm = copy.deepcopy(ai_nodes["OpenRouter Chat Model"])
    llm["position"] = [2880, 100]
    merged_nodes.append(llm)

    # 17. Postgres Chat Memory (from AI handler)
    memory = copy.deepcopy(ai_nodes["Postgres Chat Memory"])
    memory["position"] = [3000, 100]
    merged_nodes.append(memory)

    # AI Agent Tools (from AI handler)
    tool_names = [
        "Find Professionals Tool", "List Calendar Events",
        "Check Calendar Availability", "Create Calendar Event",
        "Human Escalation Tool", "Update Calendar Event",
        "Delete Calendar Event"
    ]
    tool_x = 3120
    for tn in tool_names:
        if tn in ai_nodes:
            tool_node = copy.deepcopy(ai_nodes[tn])
            tool_node["position"] = [tool_x, 100]
            tool_x += 128
            merged_nodes.append(tool_node)

    # 18. No-AI Router (from AI handler)
    no_ai_router = copy.deepcopy(ai_nodes["No-AI Router"])
    no_ai_router["position"] = [2880, 300]
    merged_nodes.append(no_ai_router)

    # 19. Use FAQ Answer (from AI handler)
    use_faq = copy.deepcopy(ai_nodes["Use FAQ Answer"])
    use_faq["position"] = [3360, 500]
    merged_nodes.append(use_faq)

    # 20. Resolve Template (from AI handler)
    resolve_tpl = copy.deepcopy(ai_nodes["Resolve Template"])
    resolve_tpl["position"] = [3120, 400]
    merged_nodes.append(resolve_tpl)

    # 21. Use Template Answer (from AI handler)
    use_tpl = copy.deepcopy(ai_nodes["Use Template Answer"])
    use_tpl["position"] = [3360, 400]
    merged_nodes.append(use_tpl)

    # --- NON-AI (TEMPLATE) BRANCH (from SM handler) ---

    # 22. Get Template Response (from SM)
    get_tpl = copy.deepcopy(sm_nodes["Get Template Response"])
    get_tpl["id"] = new_id()
    # Update references to use Parse Webhook Data instead of Load Tenant Config
    get_tpl["parameters"]["query"] = (
        "SELECT get_template_response(\n"
        "  CAST('{{ $('Parse Webhook Data').item.json.tenant_id }}' AS uuid),\n"
        "  CAST('{{ $('Transition State').item.json.template_key || \"\" }}' AS varchar(100)),\n"
        "  CAST('{{ JSON.stringify({\n"
        "    \"patient_name\": $('Parse Webhook Data').item.json.push_name || \"Cliente\",\n"
        "    \"clinic_name\": $('Parse Webhook Data').item.json.tenant_config.clinic_name\n"
        "  }) }}' AS jsonb)\n"
        ") as response_text;"
    )
    get_tpl["position"] = [1920, 500]
    merged_nodes.append(get_tpl)

    # 23. Needs Available Options? (from SM)
    needs_opts = copy.deepcopy(sm_nodes["Needs Available Options?"])
    needs_opts["id"] = new_id()
    needs_opts["position"] = [2160, 500]
    merged_nodes.append(needs_opts)

    # 24. Get Available Options (from SM)
    get_opts = copy.deepcopy(sm_nodes["Get Available Options"])
    get_opts["id"] = new_id()
    get_opts["position"] = [2400, 600]
    merged_nodes.append(get_opts)

    # 25. Needs Dynamic Data? (from SM)
    needs_data = copy.deepcopy(sm_nodes["Needs Dynamic Data?"])
    needs_data["id"] = new_id()
    needs_data["position"] = [2640, 500]
    merged_nodes.append(needs_data)

    # 26. Get Services List (from SM - adapted)
    get_services = copy.deepcopy(sm_nodes["Get Services List"])
    get_services["id"] = new_id()
    get_services["parameters"]["query"] = (
        "SELECT get_services_catalog_for_prompt("
        "'{{ $('Parse Webhook Data').item.json.tenant_id }}'::uuid) as service_list;"
    )
    get_services["position"] = [2880, 500]
    merged_nodes.append(get_services)

    # 27. Merge Template + Data (from SM - adapted)
    merge_tpl_data = copy.deepcopy(sm_nodes["Merge Template + Data"])
    merge_tpl_data["id"] = new_id()
    # Update JS references: WhatsApp Webhook → Parse Webhook Data, Load Tenant Config → Parse Webhook Data
    js = merge_tpl_data["parameters"]["jsCode"]
    js = js.replace("$('WhatsApp Webhook').item.json.body.data.key.remoteJid",
                     "$('Parse Webhook Data').item.json.remote_jid")
    js = js.replace("$('WhatsApp Webhook').item.json.body.pushName",
                     "$('Parse Webhook Data').item.json.push_name")
    js = js.replace("$('Load Tenant Config').item.json.tenant_id",
                     "$('Parse Webhook Data').item.json.tenant_id")
    js = js.replace("$('Load Tenant Config').item.json.clinic_name",
                     "$('Parse Webhook Data').item.json.tenant_config.clinic_name")
    merge_tpl_data["parameters"]["jsCode"] = js
    merge_tpl_data["position"] = [3120, 700]
    merged_nodes.append(merge_tpl_data)

    # 28. Use Template Directly (from SM)
    use_direct = copy.deepcopy(sm_nodes["Use Template Directly"])
    use_direct["id"] = new_id()
    use_direct["position"] = [3360, 600]
    merged_nodes.append(use_direct)

    # --- SERVICE SELECTION BRANCH (from SM handler - adapted) ---

    # 29. Service Selected? (from SM - adapted)
    svc_selected = copy.deepcopy(sm_nodes["Service Selected?"])
    svc_selected["id"] = new_id()
    svc_selected["position"] = [1680, 700]
    merged_nodes.append(svc_selected)

    # 30. Get Selected Service (from SM - adapted)
    get_svc = copy.deepcopy(sm_nodes["Get Selected Service"])
    get_svc["id"] = new_id()
    get_svc["parameters"]["query"] = (
        "SELECT\n"
        "  service_id AS id,\n"
        "  service_name AS name,\n"
        "  service_code,\n"
        "  service_category,\n"
        "  service_number\n"
        "FROM get_service_by_number(\n"
        "  '{{ $('Parse Webhook Data').item.json.tenant_id }}'::uuid,\n"
        "  {{ $('Parse Webhook Data').item.json.message_text }}::integer\n"
        ");"
    )
    get_svc["position"] = [1920, 700]
    merged_nodes.append(get_svc)

    # 31. Save Service Selection (from SM - adapted)
    save_svc = copy.deepcopy(sm_nodes["Save Service Selection"])
    save_svc["id"] = new_id()
    save_svc["parameters"]["query"] = (
        "SELECT update_conversation_state_data(\n"
        "  '{{ $('Parse Webhook Data').item.json.tenant_id }}'::uuid,\n"
        "  '{{ $('Parse Webhook Data').item.json.remote_jid }}',\n"
        "  '{{ $json.id }}'::uuid,\n"
        "  NULL,\n"
        "  NULL,\n"
        "  '{\"selected_service_name\": \"{{ $json.name }}\"}'\n"
        ");"
    )
    save_svc["position"] = [2160, 700]
    merged_nodes.append(save_svc)

    # 32. Get Professionals for Service (from SM)
    get_profs = copy.deepcopy(sm_nodes["Get Professionals for Service"])
    get_profs["id"] = new_id()
    get_profs["position"] = [2400, 700]
    merged_nodes.append(get_profs)

    # 33. Format Professionals List (from SM)
    fmt_profs = copy.deepcopy(sm_nodes["Format Professionals List"])
    fmt_profs["id"] = new_id()
    fmt_profs["position"] = [2640, 700]
    merged_nodes.append(fmt_profs)

    # --- OUTPUT SECTION ---

    # 34. Format Message (Code) (from AI handler - universal formatter)
    fmt_msg = copy.deepcopy(ai_nodes["Format Message (Code)"])
    fmt_msg["position"] = [3600, 400]
    merged_nodes.append(fmt_msg)

    # 35. Normalize Message Text (from SM handler - handles multiple input formats)
    normalize = copy.deepcopy(sm_nodes["Normalize Message Text"])
    normalize["id"] = new_id()
    normalize["position"] = [3840, 400]
    merged_nodes.append(normalize)

    # 36. Send WhatsApp Response (from AI handler - uses tenant_config)
    send = copy.deepcopy(ai_nodes["Send WhatsApp Response"])
    send["position"] = [4080, 300]
    merged_nodes.append(send)

    # 37. Update FAQ Cache (from AI handler)
    update_faq = copy.deepcopy(ai_nodes["Update FAQ Cache"])
    update_faq["position"] = [4080, 500]
    merged_nodes.append(update_faq)

    # 38. Service selection nodes from AI handler (direct path)
    if "Get Service by Number" in ai_nodes:
        gsbn = copy.deepcopy(ai_nodes["Get Service by Number"])
        gsbn["name"] = "Get Service by Number (AI Path)"
        gsbn["id"] = new_id()
        gsbn["position"] = [3120, 300]
        merged_nodes.append(gsbn)

    if "Find Professionals (Direct)" in ai_nodes:
        fpd = copy.deepcopy(ai_nodes["Find Professionals (Direct)"])
        fpd["position"] = [3360, 300]
        merged_nodes.append(fpd)

    if "Process Professionals" in ai_nodes:
        pp = copy.deepcopy(ai_nodes["Process Professionals"])
        pp["position"] = [3600, 300]
        merged_nodes.append(pp)

    if "Single Professional?" in ai_nodes:
        sp = copy.deepcopy(ai_nodes["Single Professional?"])
        sp["position"] = [3840, 300]
        merged_nodes.append(sp)

    if "Check Calendar (Direct)" in ai_nodes:
        ccd = copy.deepcopy(ai_nodes["Check Calendar (Direct)"])
        ccd["position"] = [4080, 200]
        merged_nodes.append(ccd)

    if "Format Calendar Slots" in ai_nodes:
        fcs = copy.deepcopy(ai_nodes["Format Calendar Slots"])
        fcs["position"] = [4320, 200]
        merged_nodes.append(fcs)

    # Documentation sticky note
    sticky = {
        "parameters": {
            "content": (
                "## 📋 01 - WhatsApp Main Handler (Merged)\n\n"
                "**Version**: 5.0 — State Machine + 3-Layer Defense\n\n"
                "### Architecture\n"
                "- **Backbone**: DB-driven conversation state machine (12 states)\n"
                "- **AI Defense**: FAQ Cache → Template → AI Agent (3-layer)\n"
                "- **Media**: Audio transcription + Image OCR (gated by feature flags)\n"
                "- **Multi-tenant**: All queries scoped by tenant_id\n\n"
                "### Flow\n"
                "1. Webhook → Tenant Config Loader (sub-workflow)\n"
                "2. Parse → Message Type Switch\n"
                "3. State Machine: get/create state → transition\n"
                "4. If requires_ai → 3-layer defense (FAQ → Template → AI)\n"
                "5. If !requires_ai → DB template response with dynamic data\n"
                "6. Format → Normalize → Send WhatsApp\n\n"
                "### Credential Placeholders\n"
                "- `{{POSTGRES_CREDENTIAL_ID}}`\n"
                "- `{{OPENROUTER_CREDENTIAL_ID}}`\n"
                "- `{{EVOLUTION_CREDENTIAL_ID}}`"
            ),
            "height": 500,
            "width": 450,
            "color": 5
        },
        "id": new_id(),
        "name": "Sticky Note - Documentation",
        "type": "n8n-nodes-base.stickyNote",
        "position": [-400, 100],
        "typeVersion": 1
    }
    merged_nodes.append(sticky)

    # =========================================================================
    # REPLACE CREDENTIAL PLACEHOLDERS IN ALL NODES
    # =========================================================================
    merged_nodes = [replace_credential_placeholders(n) for n in merged_nodes]

    # =========================================================================
    # CONNECTIONS
    # =========================================================================
    connections = {
        # Entry chain
        "WhatsApp Webhook": {"main": [[{"node": "Load Tenant Config", "type": "main", "index": 0}]]},
        "Load Tenant Config": {"main": [[{"node": "Parse Webhook Data", "type": "main", "index": 0}]]},
        "Parse Webhook Data": {"main": [[{"node": "Message Type Switch", "type": "main", "index": 0}]]},
        "Message Type Switch": {"main": [
            [{"node": "Get Conversation State", "type": "main", "index": 0}],   # text
            [{"node": "Process Image", "type": "main", "index": 0}],            # image
            [{"node": "Process Audio", "type": "main", "index": 0}]             # audio
        ]},
        "Process Audio": {"main": [[{"node": "Get Conversation State", "type": "main", "index": 0}]]},
        "Process Image": {"main": [[{"node": "Get Conversation State", "type": "main", "index": 0}]]},

        # State machine
        "Get Conversation State": {"main": [[{"node": "Transition State", "type": "main", "index": 0}]]},
        "Transition State": {"main": [[
            {"node": "Requires AI?", "type": "main", "index": 0},
            {"node": "Service Selected?", "type": "main", "index": 0}
        ]]},

        # AI branch: requires_ai=true → 3-layer defense
        "Requires AI?": {"main": [
            [{"node": "Intent Classifier", "type": "main", "index": 0}],       # true → AI defense
            [{"node": "Get Template Response", "type": "main", "index": 0}]    # false → template
        ]},

        # 3-layer defense chain
        "Intent Classifier": {"main": [[{"node": "Check FAQ Cache", "type": "main", "index": 0}]]},
        "Check FAQ Cache": {"main": [[{"node": "Merge FAQ Result", "type": "main", "index": 0}]]},
        "Merge FAQ Result": {"main": [[{"node": "Needs AI?", "type": "main", "index": 0}]]},
        "Needs AI?": {"main": [
            [{"node": "Build Prompt with Catalog", "type": "main", "index": 0}],  # true → AI
            [{"node": "No-AI Router", "type": "main", "index": 0}]               # false → no-AI
        ]},

        # AI agent path
        "Build Prompt with Catalog": {"main": [[{"node": "Patient Assistant Agent", "type": "main", "index": 0}]]},
        "Patient Assistant Agent": {"main": [[{"node": "Format Message (Code)", "type": "main", "index": 0}]]},

        # No-AI router paths
        "No-AI Router": {"main": [
            [{"node": "Get Service by Number (AI Path)", "type": "main", "index": 0}],  # service_selection
            [{"node": "Resolve Template", "type": "main", "index": 0}],                 # template
            [{"node": "Use FAQ Answer", "type": "main", "index": 0}],                   # faq
            [{"node": "Build Prompt with Catalog", "type": "main", "index": 0}]         # fallback
        ]},
        "Resolve Template": {"main": [[{"node": "Use Template Answer", "type": "main", "index": 0}]]},
        "Use Template Answer": {"main": [[{"node": "Format Message (Code)", "type": "main", "index": 0}]]},
        "Use FAQ Answer": {"main": [[{"node": "Format Message (Code)", "type": "main", "index": 0}]]},

        # Service selection from AI path
        "Get Service by Number (AI Path)": {"main": [[{"node": "Find Professionals (Direct)", "type": "main", "index": 0}]]},
        "Find Professionals (Direct)": {"main": [[{"node": "Process Professionals", "type": "main", "index": 0}]]},
        "Process Professionals": {"main": [[{"node": "Single Professional?", "type": "main", "index": 0}]]},
        "Single Professional?": {"main": [
            [{"node": "Check Calendar (Direct)", "type": "main", "index": 0}],
            [{"node": "Check Calendar (Direct)", "type": "main", "index": 0}]
        ]},
        "Check Calendar (Direct)": {"main": [[{"node": "Format Calendar Slots", "type": "main", "index": 0}]]},
        "Format Calendar Slots": {"main": [[{"node": "Format Message (Code)", "type": "main", "index": 0}]]},

        # Non-AI template branch (state machine path)
        "Get Template Response": {"main": [[{"node": "Needs Available Options?", "type": "main", "index": 0}]]},
        "Needs Available Options?": {"main": [
            [{"node": "Get Available Options", "type": "main", "index": 0}],
            [{"node": "Needs Dynamic Data?", "type": "main", "index": 0}]
        ]},
        "Get Available Options": {"main": [[{"node": "Needs Dynamic Data?", "type": "main", "index": 0}]]},
        "Needs Dynamic Data?": {"main": [
            [{"node": "Get Services List", "type": "main", "index": 0}],
            [{"node": "Use Template Directly", "type": "main", "index": 0}]
        ]},
        "Get Services List": {"main": [[{"node": "Merge Template + Data", "type": "main", "index": 0}]]},

        # Service selection from SM path
        "Service Selected?": {"main": [
            [{"node": "Get Selected Service", "type": "main", "index": 0}]
        ]},
        "Get Selected Service": {"main": [[{"node": "Save Service Selection", "type": "main", "index": 0}]]},
        "Save Service Selection": {"main": [[{"node": "Get Professionals for Service", "type": "main", "index": 0}]]},
        "Get Professionals for Service": {"main": [[{"node": "Format Professionals List", "type": "main", "index": 0}]]},
        "Format Professionals List": {"main": [[{"node": "Merge Template + Data", "type": "main", "index": 0}]]},

        # Converge to output
        "Merge Template + Data": {"main": [[{"node": "Normalize Message Text", "type": "main", "index": 0}]]},
        "Use Template Directly": {"main": [[{"node": "Normalize Message Text", "type": "main", "index": 0}]]},

        # Format → Normalize → Send
        "Format Message (Code)": {"main": [[
            {"node": "Normalize Message Text", "type": "main", "index": 0}
        ]]},
        "Normalize Message Text": {"main": [[
            {"node": "Send WhatsApp Response", "type": "main", "index": 0},
            {"node": "Update FAQ Cache", "type": "main", "index": 0}
        ]]},

        # AI Agent sub-connections
        "OpenRouter Chat Model": {"ai_languageModel": [[{"node": "Patient Assistant Agent", "type": "ai_languageModel", "index": 0}]]},
        "Postgres Chat Memory": {"ai_memory": [[{"node": "Patient Assistant Agent", "type": "ai_memory", "index": 0}]]},
    }

    # AI tool connections
    for tn in tool_names:
        if tn in ai_nodes:
            connections[tn] = {"ai_tool": [[{"node": "Patient Assistant Agent", "type": "ai_tool", "index": 0}]]}

    # =========================================================================
    # FINAL WORKFLOW
    # =========================================================================
    merged = {
        "name": "01 - WhatsApp Main Handler",
        "nodes": merged_nodes,
        "pinData": {},
        "connections": connections,
        "active": False,
        "settings": {
            "executionOrder": "v1",
            "availableInMCP": False,
            "errorWorkflow": "={{ $env.ERROR_WORKFLOW_ID || '04 - Error Handler' }}"
        },
        "versionId": str(uuid.uuid4()),
        "meta": {
            "templateCredsSetupCompleted": True,
            "instanceId": sm.get("meta", {}).get("instanceId", "")
        },
        "id": "merged-whatsapp-main",
        "tags": [
            {"name": "production", "id": new_id()},
            {"name": "main", "id": new_id()},
            {"name": "multi-tenant", "id": new_id()},
            {"name": "state-machine", "id": new_id()},
            {"name": "optimized", "id": new_id()}
        ]
    }

    return merged


def main():
    print("🔄 Merging WhatsApp handlers...")
    print(f"   State Machine: {SM_FILE}")
    print(f"   AI Optimized:  {AI_FILE}")

    merged = build_merged_workflow()

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)

    node_count = len([n for n in merged["nodes"] if n["type"] != "n8n-nodes-base.stickyNote"])
    conn_count = len(merged["connections"])

    print(f"✅ Created: {OUTPUT_FILE}")
    print(f"   Nodes: {node_count} (excluding sticky notes)")
    print(f"   Connections: {conn_count}")
    print(f"   Error workflow: configured")
    print(f"   Credential placeholders: ✅")
    print()
    print("Next steps:")
    print("  1. Import into n8n")
    print("  2. Replace {{PLACEHOLDER}} credential IDs")
    print("  3. Test state transitions")


if __name__ == "__main__":
    main()
