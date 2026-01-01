# 📚 Multi-Tenant Documentation Index

## 🎯 Start Here

**New to Multi-Tenant?** → [`README_MULTITENANT.md`](README_MULTITENANT.md)  
**Migrating from v1.x?** → [`docs/MIGRATION_GUIDE.md`](docs/MIGRATION_GUIDE.md)  
**Setting up from scratch?** → [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md)

---

## 📖 Documentation Files

### Core Documentation

| File | Purpose | Audience | Reading Time |
|------|---------|----------|--------------|
| [`README_MULTITENANT.md`](README_MULTITENANT.md) | Project overview, what changed in v2.0 | Everyone | 10 min |
| [`DELIVERY_SUMMARY.md`](DELIVERY_SUMMARY.md) | What was delivered, success criteria | Project managers | 5 min |
| [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) | Cheat sheet for daily operations | Developers/DevOps | 3 min |
| [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md) | Visual architecture diagrams | Architects/Developers | 5 min |

### Setup & Migration

| File | Purpose | Audience | Reading Time |
|------|---------|----------|--------------|
| [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md) | Complete setup guide (new installation) | DevOps | 30 min |
| [`docs/MIGRATION_GUIDE.md`](docs/MIGRATION_GUIDE.md) | Migrate from monolithic to multi-tenant | DevOps | 45 min |

### Technical Files

| File | Purpose | Audience | Type |
|------|---------|----------|------|
| [`scripts/migrations/001_create_tenant_tables.sql`](scripts/migrations/001_create_tenant_tables.sql) | Database schema creation | Developers/DBAs | SQL |
| [`scripts/migrations/002_seed_tenant_data.sql`](scripts/migrations/002_seed_tenant_data.sql) | Seed your first tenant | Developers/DBAs | SQL |
| [`scripts/manage-tenants.sh`](scripts/manage-tenants.sh) | Tenant management CLI | DevOps | Bash |

### Workflow Files

| File | Purpose | Status |
|------|---------|--------|
| [`workflows/sub/tenant-config-loader.json`](workflows/sub/tenant-config-loader.json) | Loads tenant config from DB | ✅ Active |
| [`workflows/main/01-whatsapp-patient-handler-multitenant.json`](workflows/main/01-whatsapp-patient-handler-multitenant.json) | Multi-tenant WhatsApp handler | ✅ Active |
| [`workflows/main/02-telegram-internal-assistant-multitenant.json`](workflows/main/02-telegram-internal-assistant-multitenant.json) | Multi-tenant Telegram assistant | ✅ Active |
| [`workflows/original-monolithic-workflow.json`](workflows/original-monolithic-workflow.json) | Original monolithic workflow | ⚠️ Deprecated |

---

## 🚀 Quick Navigation

### I want to...

**Understand the architecture**  
→ Start with [`README_MULTITENANT.md`](README_MULTITENANT.md) → Then [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md)

**Set up a new multi-tenant system**  
→ Follow [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md) step by step

**Migrate my existing system**  
→ Follow [`docs/MIGRATION_GUIDE.md`](docs/MIGRATION_GUIDE.md)

**Add a new clinic**  
→ See "Adding New Clinic" in [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)

**Troubleshoot an issue**  
→ Check troubleshooting sections in [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md)

**Manage tenants (activate/deactivate/quotas)**  
→ Use [`scripts/manage-tenants.sh`](scripts/manage-tenants.sh) (see [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md))

**Understand what changed**  
→ Read [`DELIVERY_SUMMARY.md`](DELIVERY_SUMMARY.md)

**Daily operations**  
→ Keep [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) handy

---

## 📋 Reading Order by Role

### **DevOps Engineer**
1. [`README_MULTITENANT.md`](README_MULTITENANT.md) - Overview
2. [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md) - Setup instructions
3. [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) - Daily commands
4. [`docs/MIGRATION_GUIDE.md`](docs/MIGRATION_GUIDE.md) - If migrating

### **Software Architect**
1. [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md) - Visual architecture
2. [`README_MULTITENANT.md`](README_MULTITENANT.md) - Technical details
3. [`DELIVERY_SUMMARY.md`](DELIVERY_SUMMARY.md) - Implementation details
4. `scripts/migrations/001_create_tenant_tables.sql` - Database schema

### **Project Manager**
1. [`DELIVERY_SUMMARY.md`](DELIVERY_SUMMARY.md) - What was delivered
2. [`README_MULTITENANT.md`](README_MULTITENANT.md) - Business benefits
3. [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md) - Implementation plan

### **Developer**
1. [`README_MULTITENANT.md`](README_MULTITENANT.md) - Overview
2. [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md) - How it works
3. Workflow JSON files - Code structure
4. [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) - Quick commands

---

## 🔍 Search by Topic

### **Database**
- Schema: `scripts/migrations/001_create_tenant_tables.sql`
- Seeding: `scripts/migrations/002_seed_tenant_data.sql`
- Queries: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) → "Useful Queries"

### **Workflows**
- Config Loader: `workflows/sub/tenant-config-loader.json`
- WhatsApp Handler: `workflows/main/01-whatsapp-patient-handler-multitenant.json`
- Telegram Assistant: `workflows/main/02-telegram-internal-assistant-multitenant.json`

### **Configuration**
- Environment: `env.multitenant.example`
- Docker: `docker-compose.yaml`
- Tenant Config: See `tenant_config` table in database

### **Security**
- Data Isolation: [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md) → "Data Isolation"
- Shared Credentials: [`README_MULTITENANT.md`](README_MULTITENANT.md) → "Shared vs Tenant-Specific"

### **Operations**
- Add Tenant: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) → "Add New Clinic"
- Management: `scripts/manage-tenants.sh`
- Monitoring: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) → "Useful Queries"

---

## 📊 Documentation Status

| Category | Files | Status |
|----------|-------|--------|
| Core Docs | 4 files | ✅ Complete |
| Setup Guides | 2 files | ✅ Complete |
| SQL Migrations | 2 files | ✅ Complete |
| Workflows | 3 files | ✅ Complete |
| Scripts | 1 file | ✅ Complete |
| Configuration | 2 files | ✅ Complete |

**Total Documentation**: 14 files, ~8,000 lines

---

## 🎯 Key Concepts

### **Tenant** 
A clinic using the system. Identified by `evolution_instance_name`.

### **Tenant Config** 
Database table storing all tenant-specific configuration (calendars, prompts, etc.).

### **Shared Credentials** 
n8n credentials used by all tenants (e.g., Google OAuth, Evolution API key).

### **Tenant Isolation** 
Data separation ensuring Clinic A cannot access Clinic B's data.

### **Dynamic Loading** 
Workflows load configuration from database at runtime (no hardcoding).

---

## 🆘 Support Paths

### **Setup Issues**
1. Check [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md) → Troubleshooting
2. Review [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) → "Troubleshooting"
3. Check logs: `docker-compose logs -f n8n`

### **Migration Issues**
1. Check [`docs/MIGRATION_GUIDE.md`](docs/MIGRATION_GUIDE.md) → "Common Issues"
2. Rollback procedure in same guide
3. Verify database: `./scripts/manage-tenants.sh health`

### **Runtime Issues**
1. Check [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md) → "Troubleshooting"
2. Check activity log: `SELECT * FROM tenant_activity_log`
3. Verify tenant config: `SELECT * FROM tenant_config`

---

## 📦 Files by Directory

```
/
├── README_MULTITENANT.md           ⭐ Start here
├── DELIVERY_SUMMARY.md             📋 What was delivered
├── QUICK_REFERENCE.md              ⚡ Daily operations
├── ARCHITECTURE_DIAGRAMS.md        🏗️ Visual diagrams
├── env.multitenant.example         ⚙️ Environment template
├── docker-compose.yaml             🐳 Docker config
│
├── docs/
│   ├── MULTI_TENANT_SETUP.md       📖 Setup guide
│   └── MIGRATION_GUIDE.md          🔄 Migration guide
│
├── scripts/
│   ├── manage-tenants.sh           🛠️ Management CLI
│   └── migrations/
│       ├── 001_create_tenant_tables.sql  🗄️ Schema
│       └── 002_seed_tenant_data.sql      🌱 Seed data
│
└── workflows/
    ├── sub/
    │   └── tenant-config-loader.json     🔑 Config loader
    └── main/
        ├── 01-whatsapp-patient-handler-multitenant.json  📱 WhatsApp
        └── 02-telegram-internal-assistant-multitenant.json  💬 Telegram
```

---

## ✅ Completion Checklist

Use this to verify documentation usage:

- [ ] Read overview (`README_MULTITENANT.md`)
- [ ] Followed setup guide (`docs/MULTI_TENANT_SETUP.md`)
- [ ] Ran database migrations
- [ ] Imported workflows
- [ ] Configured shared credentials
- [ ] Tested with your first tenant
- [ ] Added second tenant (test multi-tenancy)
- [ ] Bookmarked `QUICK_REFERENCE.md`
- [ ] Tested troubleshooting procedures
- [ ] Trained team on new system

---

## 🔄 Version History

- **v2.0** (2026-01-01): Multi-tenant implementation
- **v1.x**: Monolithic single-clinic system (deprecated)

---

## 📞 Quick Links

- **Database Schema**: `scripts/migrations/001_create_tenant_tables.sql`
- **Add Tenant**: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md#add-new-clinic)
- **Troubleshooting**: [`docs/MULTI_TENANT_SETUP.md`](docs/MULTI_TENANT_SETUP.md#troubleshooting)
- **Architecture**: [`ARCHITECTURE_DIAGRAMS.md`](ARCHITECTURE_DIAGRAMS.md)
- **Daily Commands**: [`QUICK_REFERENCE.md`](QUICK_REFERENCE.md)

---

**Welcome to the Multi-Tenant Documentation! 🎉**

*Start with [`README_MULTITENANT.md`](README_MULTITENANT.md) if this is your first time.*

