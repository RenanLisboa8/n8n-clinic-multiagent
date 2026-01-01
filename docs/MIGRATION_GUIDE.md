# 🔄 Migration Guide: Monolithic → Multi-Tenant
## From Single Clinic to Multi-Tenant System

**Time Required**: 1-2 hours  
**Downtime**: ~10 minutes  
**Rollback**: Yes (backup provided)

---

## 📋 Pre-Migration Checklist

### ✅ Before You Start

- [ ] **Backup current system**
  ```bash
  # Backup PostgreSQL
  docker exec clinic_postgres pg_dump -U n8n n8n > backup_pre_migration.sql
  
  # Backup n8n workflows
  docker cp clinic_n8n:/home/node/.n8n/workflows ./workflows_backup_$(date +%Y%m%d)
  ```

- [ ] **Document current configuration**
  ```bash
  # Export current environment variables
  docker exec clinic_n8n env | grep -E "GOOGLE_|CLINIC_|MCP_|TELEGRAM_|EVOLUTION_" > current_config.txt
  ```

- [ ] **Test current system** (ensure it's working before migration)

- [ ] **Prepare maintenance window** (recommend off-hours)

---

## 🎯 Migration Strategy

### Overview

```
Phase 1: Database Setup (No downtime)
   ↓
Phase 2: Data Migration (No downtime)
   ↓
Phase 3: Workflow Refactoring (10 min downtime)
   ↓
Phase 4: Testing & Validation
   ↓
Phase 5: Cleanup
```

---

## 🔧 Phase 1: Database Setup (15 min, No Downtime)

### Step 1.1: Run Migration Scripts

```bash
# Navigate to project directory
cd /Users/renanlisboa/Documents/n8n-clinic-multiagent

# Create migrations folder if not exists
mkdir -p scripts/migrations

# Run tenant tables creation
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/001_create_tenant_tables.sql

# Verify
docker exec -it clinic_postgres psql -U n8n -d n8n -c "
SELECT tablename FROM pg_tables 
WHERE tablename IN ('tenant_config', 'tenant_secrets', 'tenant_activity_log');
"
```

**Expected Output:**
```
      tablename       
----------------------
 tenant_config
 tenant_secrets
 tenant_activity_log
```

---

## 📊 Phase 2: Data Migration (20 min, No Downtime)

### Step 2.1: Extract Current Configuration

Run this script to extract your current hardcoded values:

```bash
cat > extract_current_config.sh << 'EOF'
#!/bin/bash

# Extract configuration from current workflow
WORKFLOW_FILE="workflows/original-monolithic-workflow.json"

echo "=== Extracting Current Configuration ==="
echo ""

# Calendar ID
CALENDAR_ID=$(grep -o 'a57a3781407f42b1ad7fe24ce76f558dc6c86fea5f349b7fd39747a2294c1654@group.calendar.google.com' "$WORKFLOW_FILE" | head -1)
echo "CALENDAR_ID: $CALENDAR_ID"

# Tasks List ID
TASKS_ID=$(grep -o '"task": "[^"]*"' "$WORKFLOW_FILE" | head -1 | cut -d'"' -f4)
echo "TASKS_ID: $TASKS_ID"

# MCP Endpoint
MCP_ENDPOINT=$(grep -o 'https://engaging-seahorse-19.rshare.io/mcp/[^"]*' "$WORKFLOW_FILE" | head -1)
echo "MCP_ENDPOINT: $MCP_ENDPOINT"

# Telegram Chat ID (from Postgres Chat Memory)
TELEGRAM_CHAT=$(grep -o '"sessionKey": "[0-9]*"' "$WORKFLOW_FILE" | head -1 | cut -d'"' -f4)
echo "TELEGRAM_CHAT_ID: $TELEGRAM_CHAT"

# Instance Name (from env or guess)
echo "EVOLUTION_INSTANCE: clinic_moreira_instance (UPDATE IF DIFFERENT!)"

echo ""
echo "=== Copy these values to 002_seed_tenant_data.sql ==="
EOF

chmod +x extract_current_config.sh
./extract_current_config.sh
```

### Step 2.2: Update Seed Data Script

Edit `scripts/migrations/002_seed_tenant_data.sql`:

```sql
-- Update these VALUES with output from extraction script above
INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,      -- ⚠️ UPDATE: From Evolution API
    clinic_name,
    clinic_address,                -- ⚠️ UPDATE: From your system prompt
    clinic_phone,                  -- ⚠️ UPDATE
    google_calendar_id,            -- ⚠️ UPDATE: From extraction
    google_tasks_list_id,          -- ⚠️ UPDATE: From extraction
    mcp_calendar_endpoint,         -- ⚠️ UPDATE: From extraction
    telegram_internal_chat_id,     -- ⚠️ UPDATE: From extraction
    system_prompt_patient,         -- ⚠️ COPY from line 102 of original workflow
    system_prompt_internal,        -- ⚠️ COPY from line 9 of original workflow
    system_prompt_confirmation     -- ⚠️ COPY from line 155 of original workflow
) VALUES (
    -- Fill in your values here
);
```

### Step 2.3: Run Seed Script

```bash
# After editing 002_seed_tenant_data.sql
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/002_seed_tenant_data.sql

# Verify data
docker exec -it clinic_postgres psql -U n8n -d n8n -c "
SELECT 
    tenant_name, 
    evolution_instance_name, 
    clinic_name, 
    is_active 
FROM tenant_config;
"
```

**Expected Output:**
```
    tenant_name     | evolution_instance_name |    clinic_name    | is_active 
--------------------+------------------------+-------------------+-----------
 Clínica Moreira    | clinic_moreira_instance| Clínica Moreira   | t
```

---

## 🔄 Phase 3: Workflow Refactoring (30 min, 10 min downtime)

### Step 3.1: Prepare New Workflows (No Downtime)

```bash
# Verify new workflow files exist
ls -la workflows/main/*multitenant.json
ls -la workflows/sub/tenant-config-loader.json

# Should show:
# - 01-whatsapp-patient-handler-multitenant.json
# - 02-telegram-internal-assistant-multitenant.json
# - tenant-config-loader.json
```

### Step 3.2: Setup Shared Credentials in n8n (No Downtime)

**Access n8n UI**: `http://localhost:5678`

**Create these credentials** (see MULTI_TENANT_SETUP.md for details):
1. Google OAuth Shared
2. Google Tasks Shared
3. Google Gemini Shared
4. Evolution API Master
5. Telegram Bot Shared
6. Postgres account

**⏰ This takes ~15 minutes**

### Step 3.3: Import New Workflows (No Downtime)

In n8n UI:
1. Import `workflows/sub/tenant-config-loader.json`
2. Import `workflows/main/01-whatsapp-patient-handler-multitenant.json`
3. Import `workflows/main/02-telegram-internal-assistant-multitenant.json`

**Update credential placeholders** in each workflow:
- Replace `{{POSTGRES_CREDENTIAL_ID}}` with actual credential
- Replace `{{GOOGLE_GEMINI_CREDENTIAL_ID}}` with actual credential
- Etc. (see MULTI_TENANT_SETUP.md)

**⏰ This takes ~10 minutes**

### Step 3.4: Downtime Begins (10 min) ⚠️

```bash
# Deactivate old workflows in n8n UI
# 1. Open "Multi-Agent AI Clinic Management" (old workflow)
# 2. Click "Active" toggle to OFF
# 3. Save

# Or via API:
curl -X PATCH 'http://localhost:5678/api/v1/workflows/YOUR_OLD_WORKFLOW_ID' \
  -H 'X-N8N-API-KEY: YOUR_API_KEY' \
  -d '{"active": false}'
```

### Step 3.5: Activate New Workflows

```bash
# In n8n UI:
# 1. Open "Tenant Config Loader" → Toggle Active ON
# 2. Open "01 - WhatsApp Patient Handler (Multi-Tenant)" → Toggle Active ON
# 3. Open "02 - Telegram Internal Assistant (Multi-Tenant)" → Toggle Active ON
```

### Step 3.6: Downtime Ends ✅

System is now multi-tenant!

---

## ✅ Phase 4: Testing & Validation (15 min)

### Test 1: Tenant Config Loads Correctly

Send WhatsApp message to your clinic's number:
```
Olá! Teste do sistema multi-tenant.
```

**Check n8n execution logs:**
- ✅ `Load Tenant Config` node executed successfully
- ✅ `tenant_config` object present in data
- ✅ Correct `clinic_name` loaded
- ✅ Response sent via WhatsApp

### Test 2: Calendar Access

```
User: Quais horários disponíveis amanhã?
```

**Expected**: Bot queries YOUR calendar (from database), not a hardcoded one.

### Test 3: Memory Isolation

```bash
# Check session key format
docker exec -it clinic_postgres psql -U n8n -d n8n -c "
SELECT session_id, tenant_id 
FROM langchain_pg_memory 
ORDER BY created_at DESC 
LIMIT 5;
"
```

**Expected**: `session_id` includes `tenant_id` prefix.

### Test 4: Telegram Internal Assistant

Send message to Telegram bot:
```
Listar consultas de hoje
```

**Expected**: 
- ✅ Bot responds
- ✅ Uses correct calendar
- ✅ No errors

### Test 5: Unknown Instance Handling

```bash
# Simulate message from unregistered instance
curl -X POST 'http://localhost:5678/webhook/whatsapp-webhook' \
  -H 'Content-Type: application/json' \
  -d '{
    "body": {
      "instance": "fake_unknown_instance",
      "data": {
        "key": {"remoteJid": "5511999999999@s.whatsapp.net"},
        "message": {"conversation": "Test"}
      }
    }
  }'
```

**Expected**:
- ❌ Execution fails with "Unknown Instance" error
- ✅ Admin receives notification (if configured)
- ✅ Logged in `tenant_activity_log`

---

## 🧹 Phase 5: Cleanup (10 min)

### Step 5.1: Archive Old Workflow

```bash
# Don't delete immediately - keep for 30 days as backup

# In n8n UI:
# 1. Rename old workflow: "DEPRECATED - Multi-Agent AI Clinic Management"
# 2. Add tag: "deprecated"
# 3. Keep inactive

# Or export and delete:
# Settings → Export → Save JSON
# Then delete from n8n
```

### Step 5.2: Update Environment Variables

```bash
# Edit .env file
nano .env

# Comment out deprecated variables:
# GOOGLE_CALENDAR_ID=...  # DEPRECATED - now in tenant_config table
# GOOGLE_TASKS_LIST_ID=... # DEPRECATED
# CLINIC_NAME=...          # DEPRECATED

# Add new variables:
SYSTEM_ADMIN_TELEGRAM_ID=your_telegram_user_id
SHARED_GOOGLE_GEMINI_API_KEY=your_api_key

# Save and restart n8n
docker-compose restart n8n
```

### Step 5.3: Verify No Hardcoded Values

```bash
# Search for hardcoded values in active workflows
docker exec -it clinic_postgres psql -U n8n -d n8n -c "
SELECT name, active FROM workflow WHERE active = true;
"

# Manually verify each active workflow has NO hardcoded:
# - Calendar IDs
# - Instance names
# - System prompts
```

---

## 🔙 Rollback Plan

### If Something Goes Wrong

#### Option A: Quick Rollback (< 5 min)

```bash
# 1. Deactivate new workflows
# In n8n UI: Toggle OFF all multi-tenant workflows

# 2. Reactivate old workflow
# In n8n UI: Toggle ON "Multi-Agent AI Clinic Management"

# 3. System restored to previous state
```

#### Option B: Full Rollback (< 15 min)

```bash
# 1. Restore PostgreSQL backup
docker exec -i clinic_postgres psql -U n8n -d n8n < backup_pre_migration.sql

# 2. Restart services
docker-compose restart

# 3. Verify old workflow is active
```

---

## 📊 Migration Checklist

- [ ] **Pre-Migration**
  - [ ] System backup created
  - [ ] Current config documented
  - [ ] Maintenance window scheduled

- [ ] **Database Setup**
  - [ ] Migration scripts executed
  - [ ] Tables created successfully
  - [ ] Data seeded correctly

- [ ] **Workflow Setup**
  - [ ] Shared credentials created
  - [ ] New workflows imported
  - [ ] Credentials mapped
  - [ ] Old workflows deactivated
  - [ ] New workflows activated

- [ ] **Testing**
  - [ ] WhatsApp messages working
  - [ ] Telegram bot working
  - [ ] Calendar access verified
  - [ ] Memory isolation confirmed
  - [ ] Unknown instance handling tested

- [ ] **Cleanup**
  - [ ] Old workflow archived
  - [ ] Environment variables updated
  - [ ] Documentation updated

- [ ] **Post-Migration**
  - [ ] Monitor system for 24 hours
  - [ ] Check error logs
  - [ ] Verify quotas tracking
  - [ ] Delete backup after 30 days (if stable)

---

## 📞 Support During Migration

### Common Issues

#### Issue: "tenant_config is null"

**Cause**: Instance name mismatch

**Fix**:
```sql
-- Check instance name in database
SELECT evolution_instance_name FROM tenant_config;

-- Check instance name in Evolution API
curl 'http://localhost:8080/instance/fetchInstances' \
  -H 'apikey: YOUR_API_KEY'

-- Update database if needed
UPDATE tenant_config 
SET evolution_instance_name = 'CORRECT_NAME' 
WHERE tenant_id = 'YOUR_TENANT_ID';
```

#### Issue: Credentials not found

**Cause**: Placeholder IDs not replaced

**Fix**: Manually update each node in workflow with correct credential.

#### Issue: Old system still receiving messages

**Cause**: Old workflow still active

**Fix**: 
```bash
# In n8n UI, verify:
SELECT name, active FROM workflow;

# Ensure only multi-tenant workflows are active
```

---

## 🎉 Success Criteria

Migration is successful when:

- ✅ All WhatsApp messages processed via new workflow
- ✅ Telegram bot responds correctly
- ✅ No errors in n8n execution logs
- ✅ Calendar operations work
- ✅ Memory is isolated per tenant
- ✅ Zero downtime after activation
- ✅ Old workflow remains as backup (inactive)

---

## 📈 Next Steps After Migration

1. **Monitor for 24 hours** (check logs daily)
2. **Add second tenant** (test multi-tenancy)
3. **Setup monitoring** (quotas, errors)
4. **Document tenant onboarding** (for clients)
5. **Train staff** on new system

---

**Migration Complete! Your system is now multi-tenant! 🚀**

