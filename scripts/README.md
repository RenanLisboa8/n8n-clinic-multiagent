# Scripts Directory

This directory contains all database management scripts and CLI tools for the multi-tenant clinic SaaS platform.

## 📁 Directory Structure

```
scripts/
├── README.md                    # This file
├── db/
│   ├── schema/
│   │   └── schema.sql           # Consolidated DDL (all tables, functions, views)
│   ├── seeds/
│   │   ├── 01_state_definitions.sql    # Conversation state machine
│   │   ├── 02_tenant_dev.sql           # Development tenant
│   │   ├── 03_services_catalog.sql     # Service definitions
│   │   ├── 04_tenant_professionals.sql # Sample professionals
│   │   └── 05_response_templates.sql   # Response templates
│   └── migrations/              # Future schema changes (V1, V2, ...)
│       └── .gitkeep
├── ops/
│   ├── setup.sh                 # Initialize database with schema + seeds
│   └── reset.sh                 # DEV ONLY: Wipe and rebuild database
├── cli/
│   ├── cli.py                   # Python CLI for tenant/professional management
│   └── requirements.txt         # CLI dependencies
└── migrations_legacy_archive/   # Archived legacy migrations (reference only)
```

## 🚀 Quick Start

### 1. Initial Setup

```bash
# Start postgres and apply schema + seeds
./scripts/ops/setup.sh

# Without seeds (schema only)
./scripts/ops/setup.sh --no-seeds
```

### 2. Reset Database (Development Only)

```bash
# With confirmation prompt
./scripts/ops/reset.sh

# Auto-confirm (CI/CD)
RESET_DEV=1 ./scripts/ops/reset.sh
```

### 3. Using the CLI

```bash
# Install dependencies
pip install -r scripts/cli/requirements.txt

# Set database connection
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=n8n_clinic_db
export PGUSER=n8n_clinic
export PGPASSWORD=your_password

# List tenants
python scripts/cli/cli.py list-tenants

# Add a new tenant
python scripts/cli/cli.py add-tenant \
  --name "My Clinic" \
  --evolution-instance "my_clinic_instance" \
  --whatsapp "+5511999999999"

# Add a professional
python scripts/cli/cli.py add-professional \
  --clinic "My Clinic" \
  --name "Dr. Smith" \
  --specialty "Dermatologist" \
  --calendar-id "dr-smith@group.calendar.google.com"

# List professionals
python scripts/cli/cli.py list-professionals --clinic "My Clinic"
```

## 📋 Database Schema

The consolidated schema (`db/schema/schema.sql`) includes:

### Tables
| Table | Description |
|-------|-------------|
| `tenant_config` | Multi-tenant configuration (clinic info, prompts, features) |
| `tenant_secrets` | API keys and sensitive credentials |
| `tenant_activity_log` | Activity logging and audit trail |
| `tenant_faq` | Cached FAQ to reduce AI calls |
| `services_catalog` | Global service definitions |
| `professionals` | Clinic staff with Google Calendar config |
| `professional_services` | Custom pricing/duration per professional |
| `response_templates` | Pre-built response templates |
| `state_definitions` | Conversation state machine definitions |
| `conversation_state` | Per-user conversation tracking |
| `calendars` | Google Calendar configuration |
| `appointments` | Appointment records with sync status |

### Key Functions
- `get_tenant_by_instance()` - Tenant resolution by Evolution instance
- `find_professionals_for_service()` - Service-to-professional matching
- `get_services_catalog_for_prompt()` - AI-friendly service list
- `get_or_create_conversation_state()` - Conversation state management
- `create_appointment()` - Appointment creation with validation
- `cancel_appointment()` / `reschedule_appointment()` - Appointment management

## 🔄 Migration Strategy

### Current State
The `schema.sql` is the baseline. For new environments, only run `schema.sql` + seeds.

### Future Changes
1. Create a new file: `db/migrations/V1_description.sql`
2. Add idempotent SQL (use `IF NOT EXISTS`, `DO $$ ... $$` guards)
3. Apply manually or via a simple runner script

Example migration:
```sql
-- db/migrations/V1_add_patient_email_verified.sql
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'appointments' 
        AND column_name = 'email_verified'
    ) THEN
        ALTER TABLE appointments ADD COLUMN email_verified BOOLEAN DEFAULT false;
    END IF;
END $$;
```

## 🗑️ Legacy Files (Archived)

Legacy migration scripts and obsolete shell scripts have been archived:

| Archived Item | Current Replacement |
|---------------|---------------------|
| `migrations/001_*.sql` through `024_*.sql` | `db/schema/schema.sql` + `db/seeds/` |
| `apply-migrations.sh` | `ops/setup.sh` |
| `init-db.sh` | `ops/setup.sh` |
| `reset-db.sh` | `ops/reset.sh` |

The archived files are located in `migrations_legacy_archive/` for reference only. **Do not run them.**

## 🔧 Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_DB` | `n8n_clinic_db` | Database name |
| `POSTGRES_USER` | `n8n_clinic` | Database user |
| `POSTGRES_PASSWORD` | - | Database password |
| `PGHOST` | `localhost` | Database host (for CLI) |
| `PGPORT` | `5432` | Database port (for CLI) |
| `APPLY_SEEDS` | `true` | Apply seed files in setup.sh |
| `RESET_DEV` | `0` | Skip confirmation in reset.sh |

## 📚 Related Documentation

- [DATABASE_ERD.md](../docs/DATABASE_ERD.md) - Entity relationship diagram
- [DEPLOYMENT.md](../docs/DEPLOYMENT.md) - Deployment guide
- [SERVICE_RESOLVER_ARCHITECTURE.md](../docs/SERVICE_RESOLVER_ARCHITECTURE.md) - Service resolution logic