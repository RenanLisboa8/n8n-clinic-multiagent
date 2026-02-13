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
│   │   ├── 05_response_templates.sql   # Response templates
│   │   ├── 06_faq_common.sql          # Common FAQ entries
│   │   └── 07_calendars.sql           # Calendar configuration
│   └── migrations/              # Incremental schema changes
├── cli/
│   ├── cli.py                   # Python CLI for tenant/professional management
│   └── requirements.txt         # CLI dependencies
├── import-workflows.py          # Import workflows to n8n via API
├── import-workflows.sh          # Shell wrapper for workflow import
├── init-db.sh                   # Initialize database (schema + seeds)
└── reset-db.sh                  # DEV ONLY: Wipe and rebuild database
```

## 🚀 Quick Start

### 1. Initial Setup

```bash
# Apply schema + seeds
DATABASE_URL=postgres://n8n_clinic:password@localhost:5432/n8n_clinic_db ./scripts/init-db.sh

# With migrations
RUN_MIGRATIONS=true DATABASE_URL=... ./scripts/init-db.sh
```

### 2. Import Workflows to n8n

```bash
# Python (recommended)
N8N_URL=http://localhost:5678 N8N_API_KEY=your_key python scripts/import-workflows.py

# Shell wrapper
./scripts/import-workflows.sh
```

### 3. Reset Database (Development Only)

```bash
./scripts/reset-db.sh
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

## Environment Variables

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
- [ARCHITECTURE.md](../docs/ARCHITECTURE.md) - System architecture (includes service resolution)