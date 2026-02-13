# Quick Start Guide

## Prerequisites

- Docker & Docker Compose installed
- PostgreSQL client (`psql`) for manual DB access
- Python 3.9+ (for CLI tool and validation script)

---

## 1. Start Services

```bash
docker compose up -d
```

Verify all containers are running:
```bash
docker compose ps
# Expected: postgres, redis, n8n, evolution-api all "running"/"healthy"
```

---

## 2. Initialize Database

```bash
# Using DATABASE_URL
DATABASE_URL=postgres://n8n_clinic:password@localhost:5432/n8n_clinic_db ./scripts/init-db.sh

# Or with individual env vars
PGHOST=localhost PGPORT=5432 PGDATABASE=n8n_clinic_db PGUSER=n8n_clinic ./scripts/init-db.sh
```

This runs:
1. `scripts/db/schema/schema.sql` — creates all tables, functions, and the `n8n_app` role
2. `scripts/db/seeds/01-07*.sql` — seeds state definitions, sample tenant, services, professionals, templates, FAQ, calendars

To also run pending migrations:
```bash
RUN_MIGRATIONS=true DATABASE_URL=... ./scripts/init-db.sh
```

---

## 3. Add a Tenant

```bash
python scripts/cli/cli.py add-tenant \
  --name "Clinica Demo" \
  --instance-name "clinica-demo" \
  --clinic-name "Clinica Demo Ltda" \
  --clinic-phone "+55 16 99999-0000" \
  --clinic-address "Rua Demo, 123" \
  --telegram-chat-id "-123456789"
```

Or via SQL directly:
```sql
INSERT INTO tenant_config (tenant_name, evolution_instance_name, clinic_name, ...)
VALUES ('Clinica Demo', 'clinica-demo', ...);
```

---

## 4. Configure Evolution API (WhatsApp)

1. Create an instance named matching `evolution_instance_name` in the tenant config
2. Set webhook URL: `http://your-server:5678/webhook/whatsapp-main`
3. Enable event: `messages.upsert`
4. Connect WhatsApp via QR code

---

## 5. Set Up Google Calendar OAuth

Follow the detailed guide: `docs/SETUP_GOOGLE_CALENDAR_API.md`

Summary:
1. Create Google Cloud project with Calendar API enabled
2. Create OAuth 2.0 credentials (Web application type)
3. Complete OAuth flow to get refresh token
4. Store credentials in `calendars` table or `tenant_secrets`

---

## 6. Import Workflows to n8n

### Automated import:
```bash
N8N_URL=http://localhost:5678 N8N_API_KEY=your_key python scripts/import-workflows.py
```

### Manual import:
1. Open n8n UI: `http://localhost:5678`
2. Create credentials (Settings > Credentials):
   - PostgreSQL, OpenRouter, Evolution API, Telegram Bot
3. Import workflow JSON files from `workflows/` directory

### Post-import:
4. Replace `{{PLACEHOLDER}}` tokens with actual credential/workflow IDs (see `workflows/README.md` for full list)
5. Activate main workflows (01, 02, 03, 04)

---

## 7. Send a Test Message

Send a WhatsApp message to your connected number:

```
Oi
```

Expected: Bot responds with greeting from FAQ/template.

Check n8n Executions tab to see the workflow run.

---

## Validation

Run the workflow validation script to check for common issues:

```bash
python tests/validate-workflows.py
```

Expected output: `PASSED` with 0 errors.

---

## Useful Commands

```bash
# Check service health
docker compose ps
curl http://localhost:5678/healthz

# View n8n logs
docker compose logs -f n8n

# Reset database (development only)
./scripts/reset-db.sh

# Run integration tests (requires running n8n)
WEBHOOK_URL=http://localhost:5678/webhook/whatsapp-main ./tests/run-integration-tests.sh
```

---

## Documentation

| Document | Description |
|---|---|
| `workflows/README.md` | Workflow structure, dependency graph, placeholder reference |
| `docs/DEPLOYMENT.md` | Full production deployment guide |
| `docs/SETUP_GOOGLE_CALENDAR_API.md` | Google Calendar OAuth setup |
| `docs/MONITORING.md` | Error alerts, queue monitoring, metrics |
| `docs/BACKUP.md` | Backup strategy and recovery procedures |
| `docs/ARCHITECTURE.md` | System architecture overview |

---

*Last updated: 2026-02-13*
