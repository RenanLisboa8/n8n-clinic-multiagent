# 🚀 Multi-Tenant Setup Guide
## n8n Clinic Management System

**Version**: 1.0.0  
**Date**: 2026-01-01  
**Estimated Setup Time**: 30-45 minutes

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Step-by-Step Setup](#step-by-step-setup)
4. [Adding New Tenants](#adding-new-tenants)
5. [Shared Credentials Setup](#shared-credentials-setup)
6. [Testing Multi-Tenancy](#testing-multi-tenancy)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

---

## 🎯 Prerequisites

### Required Services

- **Docker** & **Docker Compose** (v3.8+)
- **PostgreSQL 16** (included in docker-compose)
- **Redis 7** (included in docker-compose)
- **n8n** (latest, included in docker-compose)
- **Evolution API v2.2.3** (included in docker-compose)

### Required Accounts

- ✅ **Google Workspace** (for Calendar & Tasks)
- ✅ **Google AI Studio** (for Gemini API key)
- ✅ **Telegram Bot** (via @BotFather)
- ✅ **Domain/Server** (for hosting)

### Skills Required

- Basic SQL knowledge
- Basic Docker knowledge
- Understanding of n8n workflows

---

## 🏗️ Architecture Overview

### Before (Monolithic)
```
1 Workflow = 1 Clinic
→ Duplicate workflow for each new client
→ Hardcoded: Calendar ID, Prompts, Instance Name
```

### After (Multi-Tenant)
```
1 Workflow = N Clinics
→ Configuration in PostgreSQL database
→ Dynamic: Everything loaded per tenant
→ Shared: API credentials
```

### Data Flow
```
WhatsApp → Evolution API → n8n Webhook
                            ↓
                   Load Tenant Config (SQL)
                            ↓
                   Tenant-Specific Processing
                            ↓
                   Send Response (Tenant's Instance)
```

---

## 🔧 Step-by-Step Setup

### **Phase 1: Database Migration (10 min)**

#### 1.1 Start the Infrastructure

```bash
cd /Users/renanlisboa/Documents/n8n-clinic-multiagent

# Copy environment file
cp env.multitenant.example .env

# Edit .env with your actual values
nano .env  # or vim, code, etc.

# Start services
docker-compose up -d postgres redis
```

#### 1.2 Wait for PostgreSQL to be ready

```bash
# Check if PostgreSQL is healthy
docker-compose ps

# Should show "healthy" status for postgres
```

#### 1.3 Run Database Migrations

```bash
# Run migration script
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/001_create_tenant_tables.sql

# Verify tables were created
docker exec -it clinic_postgres psql -U n8n -d n8n -c "\dt"

# You should see:
# - tenant_config
# - tenant_secrets
# - tenant_activity_log
```

#### 1.4 Seed Your First Tenant (Migrate Existing Clinic)

```bash
# IMPORTANT: Edit 002_seed_tenant_data.sql FIRST
# Update the VALUES section with your actual clinic data:
# - evolution_instance_name (must match Evolution API)
# - google_calendar_id
# - google_tasks_list_id
# - mcp_calendar_endpoint
# - telegram_internal_chat_id
# - system_prompt_patient (your custom prompt)

nano scripts/migrations/002_seed_tenant_data.sql

# Then run the seed
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/002_seed_tenant_data.sql

# Verify insertion
docker exec -it clinic_postgres psql -U n8n -d n8n -c "SELECT tenant_name, evolution_instance_name, is_active FROM tenant_config;"
```

**Expected Output:**
```
     tenant_name      | evolution_instance_name | is_active 
----------------------+------------------------+-----------
 Clínica Moreira      | clinic_moreira_instance| t
```

---

### **Phase 2: n8n Configuration (15 min)**

#### 2.1 Start n8n

```bash
docker-compose up -d n8n evolution_api

# Wait for n8n to start (check logs)
docker-compose logs -f n8n

# Look for: "Editor is now accessible via: http://localhost:5678/"
```

#### 2.2 Access n8n UI

Open browser: `http://localhost:5678`

Create admin account (first-time setup).

#### 2.3 Setup Shared Credentials

**These credentials are used by ALL tenants.**

##### **A) Google Calendar OAuth2**

1. Go to **Settings → Credentials → Add Credential**
2. Search: `Google Calendar`
3. Select: `OAuth2 API`
4. Name: `Google OAuth Shared`
5. Follow Google OAuth setup:
   - Create project in Google Cloud Console
   - Enable Calendar API & Tasks API
   - Create OAuth 2.0 credentials
   - Copy Client ID & Client Secret
6. Click **Save** and authorize

##### **B) Google Tasks OAuth2**

1. Add Credential → `Google Tasks OAuth2 API`
2. Name: `Google Tasks Shared`
3. Use same OAuth credentials as above
4. Authorize access

##### **C) Google Gemini API**

1. Add Credential → `Google PaLM API` (used for Gemini)
2. Name: `Google Gemini Shared`
3. API Key: From [Google AI Studio](https://makersuite.google.com/app/apikey)

##### **D) Evolution API**

1. Add Credential → `Evolution API`
2. Name: `Evolution API Master`
3. Base URL: Your Evolution API URL (e.g., `https://evolution.yourdomain.com`)
4. API Key: From your `.env` file (`EVOLUTION_API_KEY`)

##### **E) Telegram Bot**

1. Add Credential → `Telegram API`
2. Name: `Telegram Bot Shared`
3. Access Token: From [@BotFather](https://t.me/botfather)

##### **F) PostgreSQL**

1. Add Credential → `PostgreSQL`
2. Name: `Postgres account`
3. Host: `postgres`
4. Port: `5432`
5. Database: `n8n`
6. User: From `.env` (`POSTGRES_USER`)
7. Password: From `.env` (`POSTGRES_PASSWORD`)

#### 2.4 Import Workflows

##### Import Sub-Workflow First:

1. Go to **Workflows**
2. Click **Import from File**
3. Select: `workflows/sub/tenant-config-loader.json`
4. Click **Save**

##### Import Main Workflows:

Repeat for:
- `workflows/main/01-whatsapp-patient-handler-multitenant.json`
- `workflows/main/02-telegram-internal-assistant-multitenant.json`

#### 2.5 Update Workflow Credentials

For **each imported workflow**:

1. Open workflow
2. For each node with `{{CREDENTIAL_ID}}`:
   - Click the node
   - Select the corresponding shared credential created above
   - Example: `{{POSTGRES_CREDENTIAL_ID}}` → `Postgres account`
3. Click **Save**

**Mapping:**
```
{{POSTGRES_CREDENTIAL_ID}}       → Postgres account
{{GOOGLE_GEMINI_CREDENTIAL_ID}}  → Google Gemini Shared
{{EVOLUTION_API_CREDENTIAL_ID}}  → Evolution API Master
{{TELEGRAM_BOT_CREDENTIAL_ID}}   → Telegram Bot Shared
{{GOOGLE_TASKS_CREDENTIAL_ID}}   → Google Tasks Shared
```

#### 2.6 Activate Workflows

1. Open `Tenant Config Loader` → Click **Active** toggle (top right)
2. Open `01 - WhatsApp Patient Handler (Multi-Tenant)` → Activate
3. Open `02 - Telegram Internal Assistant (Multi-Tenant)` → Activate

---

### **Phase 3: Evolution API Setup (10 min)**

#### 3.1 Access Evolution API

Open: `http://localhost:8080` (or your Evolution API URL)

Use API key from `.env` (`EVOLUTION_API_KEY`)

#### 3.2 Create Instance for Your Clinic

**Via API (Recommended):**

```bash
curl -X POST 'http://localhost:8080/instance/create' \
  -H 'apikey: YOUR_EVOLUTION_API_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "instanceName": "clinic_moreira_instance",
    "qrcode": true,
    "integration": "WHATSAPP-BAILEYS",
    "webhookUrl": "http://n8n:5678/webhook/whatsapp-webhook",
    "webhookByEvents": true,
    "webhookBase64": false,
    "webhookEvents": [
      "MESSAGES_UPSERT",
      "SEND_MESSAGE"
    ]
  }'
```

**IMPORTANT:** `instanceName` MUST match `evolution_instance_name` in your `tenant_config` table!

#### 3.3 Connect WhatsApp

1. Get QR Code:
```bash
curl 'http://localhost:8080/instance/connect/clinic_moreira_instance' \
  -H 'apikey: YOUR_EVOLUTION_API_KEY'
```

2. Scan QR code with WhatsApp (Phone → Settings → Linked Devices)

3. Wait for connection (check status):
```bash
curl 'http://localhost:8080/instance/connectionState/clinic_moreira_instance' \
  -H 'apikey: YOUR_EVOLUTION_API_KEY'

# Should return: "state": "open"
```

---

### **Phase 4: Verification (5 min)**

#### 4.1 Test Tenant Config Loader

1. In n8n, open `Tenant Config Loader` workflow
2. Click **Execute Workflow**
3. Paste test data:
```json
{
  "body": {
    "instance": "clinic_moreira_instance"
  }
}
```
4. Click **Execute**
5. **Expected Output**: Your tenant config loaded from database

#### 4.2 Test WhatsApp Workflow

Send a WhatsApp message to your connected number:

```
Olá! Gostaria de agendar uma consulta.
```

Check:
- ✅ Message received in n8n
- ✅ Tenant config loaded correctly
- ✅ AI responded with appropriate greeting
- ✅ Response sent back via WhatsApp

#### 4.3 Test Telegram Workflow

Send a Telegram message to your bot:

```
Listar consultas de amanhã
```

Check:
- ✅ Bot recognized your chat ID
- ✅ Tenant config loaded
- ✅ Calendar queried
- ✅ Response received

---

## ➕ Adding New Tenants

### Quick Process (< 5 minutes per tenant)

#### 1. Insert Tenant Configuration

```sql
-- Connect to database
docker exec -it clinic_postgres psql -U n8n -d n8n

-- Insert new tenant
INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
    clinic_address,
    clinic_phone,
    google_calendar_id,
    google_tasks_list_id,
    mcp_calendar_endpoint,
    telegram_internal_chat_id,
    system_prompt_patient,
    system_prompt_internal,
    system_prompt_confirmation
) VALUES (
    'Clínica Nova',
    'clinica-nova',
    'nova_clinic_instance',  -- MUST be unique!
    'Clínica Nova Esperança',
    'Av. Paulista, 1000 - São Paulo',
    '+5511988887777',
    'nova_calendar@group.calendar.google.com',
    'nova_tasks_list_id',
    'https://mcp.yourdomain.com/nova/calendar/sse',
    '987654321',  -- Telegram chat ID
    'Você é o assistente da Clínica Nova...',
    'Você é o assistente interno...',
    'Você confirma consultas...'
);

-- Verify
SELECT tenant_name, evolution_instance_name, is_active FROM tenant_config;
```

#### 2. Create Evolution API Instance

```bash
curl -X POST 'http://localhost:8080/instance/create' \
  -H 'apikey: YOUR_EVOLUTION_API_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "instanceName": "nova_clinic_instance",
    "qrcode": true,
    "webhookUrl": "http://n8n:5678/webhook/whatsapp-webhook"
  }'
```

#### 3. Connect WhatsApp for New Clinic

Get QR code and scan with clinic's WhatsApp number.

#### 4. Done! ✅

No workflow changes needed. The new tenant is automatically recognized.

---

## 🔐 Shared Credentials Setup

### Why Shared Credentials?

**Modern APIs use resource-based access:**
- One Google OAuth → Access multiple calendars via `calendar_id`
- One Evolution API key → Manage multiple instances via `instance_name`
- One Gemini API key → Unlimited usage (quota-based)

### Security Considerations

**✅ Safe:**
- Each tenant has isolated data in database
- Memory is scoped by `tenant_id`
- Calendar access controlled by `calendar_id`
- Evolution API isolates by `instance_name`

**❌ Not Safe:**
- Sharing the same Telegram chat ID (each tenant needs unique)
- Using same Google Calendar for multiple tenants

---

## 🧪 Testing Multi-Tenancy

### Test 1: Isolated Memory

**Clinic A:**
```
User: "Meu nome é João"
Bot: "Olá João! Como posso ajudar?"
```

**Clinic B (different instance):**
```
User: "Qual meu nome?"
Bot: "Ainda não me informou seu nome."
```

**Expected**: Bot does NOT remember "João" from Clinic A.

### Test 2: Isolated Calendar

**Clinic A:**
```
User: "Quais consultas temos amanhã?"
Bot: [Lists appointments from Clinic A's calendar only]
```

**Clinic B:**
```
User: "Quais consultas temos amanhã?"
Bot: [Lists appointments from Clinic B's calendar only]
```

**Expected**: Calendars are completely isolated.

### Test 3: Unknown Instance Handling

Send message from unregistered Evolution API instance.

**Expected**:
- Workflow execution fails gracefully
- Admin receives Telegram notification
- Entry logged in `tenant_activity_log`

---

## 🐛 Troubleshooting

### Issue: "Unknown Instance" Error

**Symptoms**: Workflow fails with `⚠️ UNKNOWN INSTANCE` error

**Solution**:
1. Check `evolution_instance_name` in database:
```sql
SELECT evolution_instance_name FROM tenant_config WHERE is_active = true;
```
2. Compare with instance name in Evolution API
3. Ensure they match EXACTLY (case-sensitive)

### Issue: Calendar Not Loading

**Symptoms**: Agent can't access calendar

**Solution**:
1. Check `mcp_calendar_endpoint` in database
2. Verify endpoint is accessible
3. Test endpoint manually:
```bash
curl 'YOUR_MCP_ENDPOINT/sse' -H 'Accept: text/event-stream'
```

### Issue: Shared Credentials Not Working

**Symptoms**: "Credentials not found" error

**Solution**:
1. Open workflow in n8n
2. Click each node with credentials
3. Re-select the shared credential
4. Save workflow

### Issue: Tenant Config Not Loading

**Symptoms**: `tenant_config` is null or empty

**Solution**:
1. Check if tenant is active:
```sql
SELECT * FROM tenant_config WHERE evolution_instance_name = 'YOUR_INSTANCE';
```
2. Ensure `is_active = true`
3. Restart n8n if needed:
```bash
docker-compose restart n8n
```

---

## 🛠️ Maintenance

### Daily Tasks

**None!** System runs automatically.

### Weekly Tasks

**Monitor Quotas:**
```bash
./scripts/manage-tenants.sh health
```

### Monthly Tasks

**Reset Quotas (Automatic on 1st of month):**
```sql
SELECT reset_monthly_quotas();
```

**Backup Database:**
```bash
docker exec clinic_postgres pg_dump -U n8n n8n > backup_$(date +%Y%m%d).sql
```

### Adding/Removing Tenants

**List all tenants:**
```bash
./scripts/manage-tenants.sh list
```

**View tenant details:**
```bash
./scripts/manage-tenants.sh show clinic_moreira_instance
```

**Deactivate tenant (without deleting):**
```bash
./scripts/manage-tenants.sh deactivate clinic_moreira_instance
```

**Reactivate tenant:**
```bash
./scripts/manage-tenants.sh activate clinic_moreira_instance
```

---

## 📊 Monitoring

### Check Tenant Activity

```sql
SELECT 
    t.tenant_name,
    COUNT(l.log_id) as total_activities,
    MAX(l.created_at) as last_activity
FROM tenant_config t
LEFT JOIN tenant_activity_log l ON l.tenant_id = t.tenant_id
WHERE t.is_active = true
GROUP BY t.tenant_id, t.tenant_name
ORDER BY last_activity DESC;
```

### Check Message Quotas

```sql
SELECT 
    tenant_name,
    current_message_count,
    monthly_message_limit,
    ROUND((current_message_count::NUMERIC / monthly_message_limit) * 100, 2) as usage_percent
FROM tenant_config
WHERE is_active = true
ORDER BY usage_percent DESC;
```

---

## 🎉 Success Checklist

- ✅ PostgreSQL running with `tenant_config` table
- ✅ Redis running
- ✅ n8n running with shared credentials configured
- ✅ Evolution API running with instance(s) created
- ✅ All workflows imported and activated
- ✅ WhatsApp connected and responding
- ✅ Telegram bot responding to staff
- ✅ Multi-tenancy tested (isolated memory/calendar)

---

## 📞 Support

- **Documentation**: `/docs/` folder
- **Issues**: Check `tenant_activity_log` table
- **Logs**: `docker-compose logs -f n8n`

---

**Congratulations! Your multi-tenant clinic system is live! 🚀**

