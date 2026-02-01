# Legacy Migrations Archive

> ⚠️ **DO NOT RUN** — Reference only.

These migrations have been superseded by the unified schema at `scripts/db/schema/schema.sql`.

## Replaced By

The schema file (`schema.sql`) consolidates and replaces migrations:
- 001, 003, 004, 015, 018, 020, 021, 022, 023, 024

Seeds are now in `scripts/db/seeds/`:
- `01_state_definitions.sql`
- `02_tenant_dev.sql`
- `03_services_catalog.sql`
- `04_tenant_professionals.sql`
- `05_response_templates.sql`

## Current DB Management

Use these scripts for database operations:
- **Init/Setup:** `scripts/ops/setup.sh`
- **Reset (dev only):** `scripts/ops/reset.sh`

---

*Archived on 2026-02-01 as part of the Grand Unification Plan.*
