# Backup & Recovery

## Overview

The system stores all critical data in PostgreSQL. Regular backups are essential for disaster recovery.

---

## PostgreSQL Backup Strategy

### Daily Automated Backup (`pg_dump`)

Add to crontab on the host or as a Docker exec:

```bash
#!/bin/bash
# /opt/clinic/backup.sh
set -euo pipefail

BACKUP_DIR="/opt/clinic/backups"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="n8n_clinic_db"
DB_USER="n8n_clinic"

mkdir -p "$BACKUP_DIR"

# Full database dump (compressed)
docker exec postgres pg_dump -U "$DB_USER" -d "$DB_NAME" \
  --format=custom --compress=9 \
  > "$BACKUP_DIR/clinic_${TIMESTAMP}.dump"

# Verify backup is not empty
BACKUP_SIZE=$(stat -f%z "$BACKUP_DIR/clinic_${TIMESTAMP}.dump" 2>/dev/null || stat -c%s "$BACKUP_DIR/clinic_${TIMESTAMP}.dump")
if [ "$BACKUP_SIZE" -lt 1000 ]; then
  echo "ERROR: Backup file suspiciously small ($BACKUP_SIZE bytes)"
  exit 1
fi

# Clean old backups
find "$BACKUP_DIR" -name "clinic_*.dump" -mtime +${RETENTION_DAYS} -delete

echo "Backup complete: clinic_${TIMESTAMP}.dump ($BACKUP_SIZE bytes)"
```

### Crontab Entry

```bash
# Daily at 2 AM
0 2 * * * /opt/clinic/backup.sh >> /var/log/clinic-backup.log 2>&1
```

---

## What to Back Up

| Component | Method | Frequency |
|---|---|---|
| PostgreSQL (all tables) | `pg_dump` | Daily |
| n8n workflows (JSON exports) | Git repository | On change |
| Docker volumes | Volume snapshot | Weekly |
| `.env` configuration | Manual copy | On change |
| SSL certificates | File copy | On renewal |

### Tables by Priority

**Critical** (must restore):
- `tenant_config`, `tenant_secrets` — tenant configuration
- `appointments` — scheduled appointments
- `conversation_state` — active conversations
- `calendars`, `professionals`, `professional_services` — business data

**Important** (should restore):
- `tenant_faq` — learned FAQ cache (rebuilds over time if lost)
- `response_templates`, `state_definitions` — can be re-seeded
- `services_catalog` — can be re-seeded

**Ephemeral** (can be recreated):
- `message_queue` — transient processing state
- `conversation_locks` — auto-expires
- `tenant_activity_log` — audit trail (keep if compliance requires)

---

## Recovery Procedures

### Full Restore

```bash
# 1. Stop n8n to prevent writes during restore
docker compose stop n8n

# 2. Restore from backup
docker exec -i postgres pg_restore -U n8n_clinic -d n8n_clinic_db \
  --clean --if-exists \
  < backups/clinic_20260213_020000.dump

# 3. Restart n8n
docker compose start n8n
```

### Partial Table Restore

```bash
# Restore specific tables only
docker exec -i postgres pg_restore -U n8n_clinic -d n8n_clinic_db \
  --table=appointments --table=conversation_state \
  --data-only \
  < backups/clinic_20260213_020000.dump
```

### Point-in-Time Recovery

For production systems handling many tenants, enable PostgreSQL WAL archiving:

```yaml
# docker-compose.yaml postgres environment
POSTGRES_INITDB_ARGS: "--wal-segsize=16"
```

```sql
-- postgresql.conf additions
archive_mode = on
archive_command = 'cp %p /backups/wal/%f'
```

---

## Verification

After any restore, verify:

```sql
-- Check tenant count
SELECT COUNT(*) FROM tenant_config WHERE is_active = true;

-- Check recent appointments exist
SELECT COUNT(*) FROM appointments WHERE start_at > NOW();

-- Check conversation states are intact
SELECT current_state, COUNT(*) FROM conversation_state GROUP BY current_state;
```

---

## Off-site Backup

For production, sync backups to cloud storage:

```bash
# Example: sync to S3-compatible storage
aws s3 sync /opt/clinic/backups/ s3://clinic-backups/ --storage-class STANDARD_IA
```
