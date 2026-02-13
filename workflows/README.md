# Workflows — Multi-Tenant Clinic Management System

**Version**: 4.0 — Production-Hardened (State Machine + 3-Layer Defense + Messaging Abstraction)

---

## Directory Structure

```
workflows/
├── main/                           # Main orchestrator workflows
│   ├── 01-whatsapp-main.json       # WhatsApp patient handler (merged state machine + AI defense)
│   ├── 02-telegram-internal-assistant-multitenant.json  # Telegram ops for staff
│   ├── 03-appointment-confirmation-scheduler.json       # Daily reminder scheduler (DB-based)
│   └── 04-error-handler.json       # Multi-tenant error handler
├── sub/                            # Sub-workflows (shared utilities)
│   └── tenant-config-loader.json   # Loads tenant config from DB by instance_name
└── tools/                          # Tool workflows for AI agents
    ├── calendar/
    │   ├── google-calendar-client.json          # OAuth HTTP client (shared)
    │   ├── google-calendar-availability-tool.json  # Check free/busy slots
    │   ├── google-calendar-create-event-tool.json  # Create appointment
    │   ├── google-calendar-update-event-tool.json  # Reschedule appointment
    │   ├── google-calendar-delete-event-tool.json  # Cancel appointment
    │   └── google-calendar-list-events-tool.json   # List events in range
    ├── communication/
    │   ├── messaging-send-tool.json    # Messaging router (Evolution/Chatwoot)
    │   ├── whatsapp-send-tool.json     # Evolution API adapter
    │   ├── chatwoot-send-tool.json     # Chatwoot adapter
    │   ├── telegram-client.json        # Telegram HTTP client
    │   └── telegram-notify-tool.json   # Telegram notification helper
    ├── service/
    │   └── find-professionals-tool.json  # Find professionals by service
    ├── escalation/
    │   └── call-to-human-tool.json     # Escalate to human via Telegram
    └── ai-processing/
        ├── audio-transcription-tool.json  # WhatsApp audio → text
        └── image-ocr-tool.json            # Image → text extraction
```

---

## Dependency Graph

```
                  ┌─────────────────────┐
                  │   01-whatsapp-main   │
                  └─────────┬───────────┘
                            │
         ┌──────────────────┼──────────────────────┐
         │                  │                      │
         ▼                  ▼                      ▼
  tenant-config-loader   messaging-send-tool   calendar tools
                            │                      │
                    ┌───────┴───────┐       ┌──────┴──────┐
                    ▼               ▼       ▼             ▼
             whatsapp-send   chatwoot-send  google-calendar-client
                                            (shared OAuth)

  02-telegram ──► messaging-send-tool ──► whatsapp-send / chatwoot-send
  03-scheduler ──► messaging-send-tool ──► whatsapp-send / chatwoot-send
  04-error-handler ──► telegram-client (direct HTTP, no n8n credential)
```

---

## Main Workflows

### 01 - WhatsApp Main Handler
- **Architecture**: DB-driven state machine (13 states) + 3-layer AI defense (FAQ → Template → AI)
- **Message Dedup**: `enqueue_message()` with UNIQUE constraint on `(tenant_id, message_id)`
- **Conversation Lock**: `acquire_conversation_lock()` / `release_conversation_lock()`
- **Media**: Audio transcription + Image OCR (gated by `tenant_config.features` flags)
- **Flow**: Webhook → Tenant Config → Parse → Dedup → Lock → State Machine → AI Defense → Format → Send → Release Lock

### 02 - Telegram Internal Assistant
- **Auth**: Identifies tenant by `telegram_internal_chat_id`
- **Tools**: Calendar (MCP), Google Tasks, Messaging (via abstraction layer)
- **Model**: Claude 3.5 Sonnet (via OpenRouter)

### 03 - Appointment Confirmation Scheduler
- **Trigger**: Cron daily at 8 AM
- **Data Source**: `get_appointments_for_reminders('24h')` stored function (NOT native Google Calendar node)
- **Dedup**: `mark_reminder_sent()` prevents duplicate reminders
- **Send**: Via messaging abstraction layer

### 04 - Error Handler
- **Multi-tenant**: Extracts `tenant_id` from failed execution data
- **Fallback**: Sends to `$env.FALLBACK_TELEGRAM_CHAT_ID` when tenant unknown
- **Delivery**: Uses `telegram-client.json` sub-workflow (no n8n Telegram credential needed)

---

## Placeholder Reference

All workflow JSON files use placeholders for environment-specific values. Replace before importing to n8n.

### Credential Placeholders

| Placeholder | Description |
|---|---|
| `{{POSTGRES_CREDENTIAL_ID}}` | PostgreSQL credential in n8n |
| `{{OPENROUTER_CREDENTIAL_ID}}` | OpenRouter API credential |
| `{{EVOLUTION_API_CREDENTIAL_ID}}` | Evolution API credential |
| `{{TELEGRAM_BOT_CREDENTIAL_ID}}` | Telegram Bot API credential |
| `{{GOOGLE_TASKS_CREDENTIAL_ID}}` | Google Tasks OAuth2 credential |

### Workflow ID Placeholders

| Placeholder | Points To |
|---|---|
| `{{TENANT_CONFIG_LOADER_WORKFLOW_ID}}` | `sub/tenant-config-loader.json` |
| `{{GOOGLE_CALENDAR_CLIENT_WORKFLOW_ID}}` | `tools/calendar/google-calendar-client.json` |
| `{{ERROR_HANDLER_WORKFLOW_ID}}` | `main/04-error-handler.json` |

### Environment Variable Placeholders

| Placeholder | Description |
|---|---|
| `{{N8N_APP_PASSWORD}}` | Password for the `n8n_app` PostgreSQL role |

### Allowed `$env` References

These remain as runtime environment variables (infrastructure-level, not tenant-specific):

| Variable | Used In | Purpose |
|---|---|---|
| `$env.FALLBACK_TELEGRAM_CHAT_ID` | 04-error-handler | System admin alert channel |
| `$env.N8N_WEBHOOK_URL` | 04-error-handler | Link to n8n execution details |

---

## Critical Rules

1. **NO native n8n Google Calendar nodes** — use `google-calendar-client.json` sub-workflow
2. **Always use `google_calendar_id` from `FindProfessionals`** — never hardcode
3. **Always use `duration_minutes` from `professional_services`** — varies by professional
4. **All SQL must filter by `tenant_id`** — strict multi-tenant isolation
5. **Use messaging abstraction layer** — `messaging-send-tool.json`, not direct `whatsapp-send-tool.json`

---

**Last Updated**: 2026-02-13
**Version**: 4.0 — Post-hardening with messaging abstraction, dedup, and security
