# 🏥 n8n Multi-Tenant Clinic Management System

**Version**: 2.0.0 (Multi-Tenant)  
**Architecture**: Hybrid Multi-Tenant with Shared Credentials  
**Status**: Production Ready

---

## 🎯 What Changed in Version 2.0

### Before (v1.x - Monolithic)
- ❌ One workflow per clinic (duplicate for each client)
- ❌ Hardcoded: Calendar IDs, System Prompts, Instance Names
- ❌ Manual workflow editing for configuration changes
- ❌ No data isolation between clinics
- ❌ Scaling = Linear resource growth

### After (v2.0 - Multi-Tenant)
- ✅ One workflow for unlimited clinics
- ✅ Database-driven configuration (PostgreSQL)
- ✅ Add new clinic via SQL INSERT (< 2 minutes)
- ✅ Complete data isolation per tenant
- ✅ Shared infrastructure, shared credentials
- ✅ Scaling = Logarithmic resource growth

---

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Evolution API (WhatsApp)                                   │
│  • Multiple instances (1 per clinic)                        │
│  • Shared API Key                                           │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  n8n Workflow Engine                                        │
│  • Single workflow set                                      │
│  • Dynamic tenant resolution                                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  PostgreSQL Database                                        │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ tenant_config (Configuration)                         │ │
│  │ • evolution_instance_name → Tenant identifier         │ │
│  │ • google_calendar_id → Calendar per tenant            │ │
│  │ • system_prompt_patient → Custom AI per tenant        │ │
│  │ • telegram_internal_chat_id → Staff chat              │ │
│  │ • ... (20+ config fields)                             │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ tenant_secrets (Encrypted, Optional)                  │ │
│  │ • Custom API keys per tenant (if needed)              │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ tenant_activity_log (Auditing)                        │ │
│  │ • Message counts, errors, unknown instances           │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ langchain_pg_memory (Tenant-Isolated)                 │ │
│  │ • session_id = tenant_id + remote_jid                 │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### For New Installations

```bash
# 1. Clone repository
git clone <your-repo-url>
cd n8n-clinic-multiagent

# 2. Copy environment file
cp env.multitenant.example .env

# 3. Edit with your values
nano .env

# 4. Start infrastructure
docker-compose up -d

# 5. Run migrations
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/001_create_tenant_tables.sql

# 6. Seed your first tenant
# (Edit 002_seed_tenant_data.sql first!)
docker exec -i clinic_postgres psql -U n8n -d n8n < scripts/migrations/002_seed_tenant_data.sql

# 7. Access n8n
open http://localhost:5678

# 8. Follow MULTI_TENANT_SETUP.md
```

### For Existing Installations (Migration)

**See**: `docs/MIGRATION_GUIDE.md`

Estimated time: 1-2 hours (10 min downtime)

---

## 📁 Project Structure

```
n8n-clinic-multiagent/
├── docs/
│   ├── ARCHITECTURE.md              # Original architecture (v1.x)
│   ├── DEPLOYMENT.md                # Deployment guide
│   ├── QUICK_START.md               # Original quick start
│   ├── MULTI_TENANT_SETUP.md        # ⭐ NEW: Multi-tenant setup guide
│   └── MIGRATION_GUIDE.md           # ⭐ NEW: Migration instructions
│
├── scripts/
│   ├── init-db.sh                   # Database initialization
│   ├── manage-tenants.sh            # ⭐ NEW: Tenant management CLI
│   └── migrations/
│       ├── 001_create_tenant_tables.sql  # ⭐ NEW: Create multi-tenant tables
│       └── 002_seed_tenant_data.sql      # ⭐ NEW: Seed your first tenant
│
├── workflows/
│   ├── main/
│   │   ├── 01-whatsapp-patient-handler.json              # v1.x (deprecated)
│   │   ├── 01-whatsapp-patient-handler-multitenant.json  # ⭐ NEW: v2.0
│   │   ├── 02-telegram-internal-assistant.json           # v1.x (deprecated)
│   │   └── 02-telegram-internal-assistant-multitenant.json # ⭐ NEW: v2.0
│   │
│   ├── sub/
│   │   └── tenant-config-loader.json  # ⭐ NEW: Tenant config resolver
│   │
│   └── tools/
│       ├── ai-processing/
│       ├── calendar/
│       ├── communication/
│       └── escalation/
│
├── docker-compose.yaml              # Updated for multi-tenant
├── env.example                      # v1.x environment vars (deprecated)
├── env.multitenant.example          # ⭐ NEW: v2.0 environment vars
└── README.md                        # This file
```

---

## 🔐 Security & Data Isolation

### How Multi-Tenancy is Enforced

| **Layer** | **Isolation Mechanism** | **Example** |
|-----------|------------------------|-------------|
| **Webhook** | Instance name validation | Only registered instances processed |
| **Database** | `tenant_id` in all queries | `WHERE tenant_id = 'abc-123'` |
| **Memory** | Tenant-scoped session keys | `{tenant_id}_{remote_jid}` |
| **Calendar** | Separate calendar per tenant | `clinic_a@group.calendar.google.com` |
| **Evolution** | Separate instance per tenant | `clinic_a_instance` |
| **Telegram** | Separate chat ID per tenant | Each clinic has unique chat |

### Shared vs. Tenant-Specific

**✅ Shared (Same for all tenants):**
- Google OAuth credentials
- Evolution API credentials
- Gemini API key
- Telegram bot token
- n8n workflows (code)

**🔒 Tenant-Specific (Isolated per clinic):**
- Google Calendar ID
- Google Tasks List ID
- MCP Calendar Endpoint
- System Prompts (AI personality)
- Telegram Chat ID
- WhatsApp Instance Name
- Chat memory
- Activity logs

---

## ➕ Adding a New Clinic (< 5 minutes)

### Step 1: Insert Configuration

```sql
-- Connect to database
docker exec -it clinic_postgres psql -U n8n -d n8n

-- Insert tenant
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
    'nova_instance',  -- Unique!
    'Clínica Nova Esperança',
    'Av. Paulista, 1000',
    '+5511999998888',
    'nova@group.calendar.google.com',
    'task_list_xyz',
    'https://mcp.com/nova/calendar',
    '987654321',
    'Você é o assistente da Clínica Nova...',
    'Você é o assistente interno...',
    'Você confirma consultas...'
);
```

### Step 2: Create Evolution Instance

```bash
curl -X POST 'http://localhost:8080/instance/create' \
  -H 'apikey: YOUR_API_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "instanceName": "nova_instance",
    "webhookUrl": "http://n8n:5678/webhook/whatsapp-webhook"
  }'
```

### Step 3: Connect WhatsApp

Scan QR code with clinic's WhatsApp.

### Step 4: Done! ✅

**No workflow changes needed.**

---

## 🛠️ Management Tools

### Tenant Management CLI

```bash
# List all tenants
./scripts/manage-tenants.sh list

# Show tenant details
./scripts/manage-tenants.sh show clinic_moreira_instance

# Activate/Deactivate tenant
./scripts/manage-tenants.sh deactivate test_clinic
./scripts/manage-tenants.sh activate test_clinic

# Reset message quota
./scripts/manage-tenants.sh reset-quota clinic_moreira_instance

# Health check
./scripts/manage-tenants.sh health
```

### Database Queries

```sql
-- View all active tenants
SELECT * FROM v_active_tenants;

-- Check message usage
SELECT 
    tenant_name,
    current_message_count || '/' || monthly_message_limit as quota,
    ROUND((current_message_count::NUMERIC / monthly_message_limit) * 100, 2) || '%' as usage
FROM tenant_config
WHERE is_active = true;

-- View activity log
SELECT 
    t.tenant_name,
    l.activity_type,
    l.created_at
FROM tenant_activity_log l
JOIN tenant_config t ON t.tenant_id = l.tenant_id
ORDER BY l.created_at DESC
LIMIT 20;
```

---

## 📊 Resource Comparison

### Single Clinic vs. Multi-Tenant

| **Metric** | **Monolithic (v1.x)** | **Multi-Tenant (v2.0)** |
|------------|----------------------|------------------------|
| **Workflows** | 1 per clinic | 3 total (shared) |
| **Database Size** | N/A | +50 MB (config) |
| **Memory** | 512 MB per clinic | 512 MB + (50 MB × N) |
| **CPU** | 1 vCPU per clinic | 1-2 vCPU total |
| **Credentials** | 5 per clinic | 6 total (shared) |
| **Time to Add Clinic** | 2-4 hours | < 5 minutes |
| **Maintenance** | High (edit N workflows) | Low (SQL UPDATE) |

### Scaling Example (10 Clinics)

**Monolithic:**
- 10 workflow copies
- 50 credentials
- ~5 GB RAM
- ~10 vCPU

**Multi-Tenant:**
- 3 workflows
- 6 credentials
- ~1 GB RAM
- ~2 vCPU

**Savings**: ~80% resources

---

## 🧪 Testing Multi-Tenancy

### Test Scenario: 2 Clinics

**Clinic A** (`clinic_a_instance`):
```
User: Olá, meu nome é João
Bot: Olá João! Sou o assistente da Clínica A.
```

**Clinic B** (`clinic_b_instance`):
```
User: Qual é o meu nome?
Bot: Ainda não me informou seu nome.
```

**✅ Expected**: Bot does NOT remember "João" from Clinic A.

---

## 📞 Support & Documentation

- **Setup Guide**: `docs/MULTI_TENANT_SETUP.md`
- **Migration Guide**: `docs/MIGRATION_GUIDE.md`
- **Architecture**: `docs/ARCHITECTURE.md`
- **Troubleshooting**: See guides above

### Common Issues

**Issue**: "Unknown Instance" error  
**Solution**: Check `evolution_instance_name` matches exactly

**Issue**: Calendar not loading  
**Solution**: Verify `mcp_calendar_endpoint` is accessible

**Issue**: Shared credentials not working  
**Solution**: Re-select credentials in workflow nodes

---

## 🎉 Success Metrics

Your multi-tenant system is successful when:

- ✅ Add new clinic in < 5 minutes (SQL INSERT)
- ✅ Zero workflow duplication
- ✅ Complete data isolation between tenants
- ✅ Single infrastructure for N clinics
- ✅ Centralized configuration management
- ✅ Automatic tenant resolution (no manual routing)

---

## 📈 Roadmap

### v2.1 (Planned)
- [ ] Web-based admin panel for tenant management
- [ ] Automatic quota alerts via Telegram
- [ ] Multi-language support per tenant
- [ ] Custom branding per tenant

### v2.2 (Planned)
- [ ] API for tenant CRUD operations
- [ ] Tenant-specific analytics dashboard
- [ ] Backup/restore per tenant
- [ ] Role-based access control (RBAC)

---

## 🏆 Credits

**Architecture**: Hybrid Multi-Tenant with Shared Credentials  
**Database**: PostgreSQL 16  
**Workflow Engine**: n8n  
**WhatsApp Integration**: Evolution API v2  
**AI Models**: Google Gemini 2.0 Flash

---

## 📄 License

[Your License Here]

---

## 🚀 Get Started

1. **New User?** → Follow `docs/MULTI_TENANT_SETUP.md`
2. **Migrating?** → Follow `docs/MIGRATION_GUIDE.md`
3. **Need Help?** → Check troubleshooting sections in guides

**Welcome to the Multi-Tenant Era! 🎊**

