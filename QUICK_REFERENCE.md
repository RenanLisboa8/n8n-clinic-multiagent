# 🚀 Multi-Tenant Quick Reference Card

## 📊 Architecture Summary

```
Evolution API (instance_name) → n8n Webhook → Load Tenant Config (SQL)
                                      ↓
                                 tenant_config loaded
                                      ↓
                          Process with tenant-specific:
                          • System prompts
                          • Calendar ID
                          • Isolated memory
                                      ↓
                          Send response via tenant's instance
```

---

## ⚡ Quick Commands

### Database Operations
```bash
# Run migrations
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/001_create_tenant_tables.sql
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/002_seed_tenant_data.sql

# Connect to database
docker exec -it clinic_postgres psql -U n8n -d n8n

# List tenants
SELECT tenant_name, evolution_instance_name, is_active FROM tenant_config;

# View tenant details
SELECT * FROM tenant_config WHERE evolution_instance_name = 'YOUR_INSTANCE';
```

### Tenant Management
```bash
# List all
./scripts/manage-tenants.sh list

# Show details
./scripts/manage-tenants.sh show clinic_moreira_instance

# Activate/Deactivate
./scripts/manage-tenants.sh deactivate test_clinic
./scripts/manage-tenants.sh activate test_clinic

# Health check
./scripts/manage-tenants.sh health
```

### Docker Operations
```bash
# Start all services
docker-compose up -d

# Restart n8n
docker-compose restart n8n

# View logs
docker-compose logs -f n8n

# Check service status
docker-compose ps
```

---

## ➕ Add New Clinic (< 5 min)

### 1. Database Insert
```sql
INSERT INTO tenant_config (
    tenant_name, tenant_slug, evolution_instance_name,
    clinic_name, clinic_address, clinic_phone,
    google_calendar_id, google_tasks_list_id,
    mcp_calendar_endpoint, telegram_internal_chat_id,
    system_prompt_patient, system_prompt_internal, system_prompt_confirmation
) VALUES (
    'Clínica Nova', 'clinica-nova', 'nova_instance',
    'Clínica Nova', 'Endereço', '+55119999999',
    'calendar_id', 'tasks_id', 'https://mcp.com/endpoint',
    '123456', 'Prompt patient', 'Prompt internal', 'Prompt confirm'
);
```

### 2. Evolution API Instance
```bash
curl -X POST 'http://localhost:8080/instance/create' \
  -H 'apikey: YOUR_API_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"instanceName": "nova_instance", "webhookUrl": "http://n8n:5678/webhook/whatsapp-webhook"}'
```

### 3. Connect WhatsApp
Get QR → Scan → Done!

---

## 🔍 Troubleshooting

### Issue: "Unknown Instance"
```sql
-- Check instance name
SELECT evolution_instance_name FROM tenant_config WHERE is_active = true;

-- Update if needed
UPDATE tenant_config 
SET evolution_instance_name = 'CORRECT_NAME' 
WHERE tenant_id = 'xxx';
```

### Issue: Calendar Not Working
```sql
-- Check endpoint
SELECT mcp_calendar_endpoint FROM tenant_config WHERE evolution_instance_name = 'YOUR_INSTANCE';

-- Test endpoint
curl 'YOUR_MCP_ENDPOINT/sse' -H 'Accept: text/event-stream'
```

### Issue: Credentials Not Found
- Open workflow in n8n
- Click each node with `{{CREDENTIAL_ID}}`
- Select correct shared credential
- Save workflow

---

## 🧪 Testing Checklist

### Basic Tests
```bash
# 1. Test WhatsApp
# Send: "Olá"
# Expected: Bot responds with greeting

# 2. Test Telegram
# Send: "Listar consultas"
# Expected: Bot lists appointments

# 3. Test Multi-Tenancy
# Send same message to 2 different instances
# Expected: Different responses based on tenant config
```

### SQL Verification
```sql
-- Check tenant loaded
SELECT * FROM tenant_activity_log ORDER BY created_at DESC LIMIT 5;

-- Check memory isolation
SELECT session_id, tenant_id FROM langchain_pg_memory ORDER BY created_at DESC LIMIT 5;

-- Check quotas
SELECT tenant_name, current_message_count, monthly_message_limit FROM tenant_config;
```

---

## 📁 Important Files

### Must Edit Before Deploy
- `scripts/migrations/002_seed_tenant_data.sql` - Your clinic data
- `.env` - Environment variables
- Workflow credential IDs (after import)

### Documentation
- `docs/MULTI_TENANT_SETUP.md` - Full setup guide
- `docs/MIGRATION_GUIDE.md` - Migration instructions
- `DELIVERY_SUMMARY.md` - What was delivered

### Workflows
- `workflows/sub/tenant-config-loader.json` - Loads config
- `workflows/main/01-whatsapp-patient-handler-multitenant.json` - Main flow
- `workflows/main/02-telegram-internal-assistant-multitenant.json` - Internal

---

## 🔐 Shared Credentials (One-Time Setup)

Create in n8n UI:
1. **Google OAuth Shared** - OAuth2 for Calendar
2. **Google Tasks Shared** - OAuth2 for Tasks
3. **Google Gemini Shared** - API Key
4. **Evolution API Master** - HTTP Header Auth
5. **Telegram Bot Shared** - API Token
6. **Postgres account** - PostgreSQL connection

---

## 📊 Useful Queries

### Active Tenants with Usage
```sql
SELECT * FROM v_active_tenants;
```

### Recent Activity
```sql
SELECT 
    t.tenant_name,
    l.activity_type,
    l.created_at
FROM tenant_activity_log l
JOIN tenant_config t ON t.tenant_id = l.tenant_id
ORDER BY l.created_at DESC LIMIT 20;
```

### Quota Usage
```sql
SELECT 
    tenant_name,
    ROUND((current_message_count::NUMERIC / monthly_message_limit) * 100, 2) as usage_percent
FROM tenant_config
WHERE is_active = true
ORDER BY usage_percent DESC;
```

### Tenants Near Quota
```sql
SELECT tenant_name, current_message_count, monthly_message_limit
FROM tenant_config
WHERE current_message_count >= monthly_message_limit * 0.8
AND is_active = true;
```

---

## 🚨 Emergency Procedures

### Rollback to Monolithic
```bash
# 1. Deactivate multi-tenant workflows (n8n UI)
# 2. Activate old workflow (n8n UI)
# 3. Restore backup if needed:
docker exec -i clinic_postgres psql -U n8n -d n8n < backup_pre_migration.sql
docker-compose restart
```

### Disable Problematic Tenant
```sql
UPDATE tenant_config 
SET is_active = false 
WHERE evolution_instance_name = 'PROBLEM_INSTANCE';
```

### Check System Health
```bash
./scripts/manage-tenants.sh health
docker-compose ps
docker-compose logs --tail=50 n8n
```

---

## 📞 Support Resources

- **Setup**: `docs/MULTI_TENANT_SETUP.md`
- **Migration**: `docs/MIGRATION_GUIDE.md`
- **Overview**: `README_MULTITENANT.md`
- **This Card**: `QUICK_REFERENCE.md`

---

## ✅ Success Indicators

Your system is working correctly when:
- ✅ Messages from different instances load different configs
- ✅ Calendar operations use tenant-specific calendars
- ✅ Memory doesn't leak between tenants
- ✅ Unknown instances are rejected gracefully
- ✅ Can add new tenant in < 5 minutes
- ✅ No hardcoded values in workflows

---

**Keep this card handy for daily operations! 📋**

