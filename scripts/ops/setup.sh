#!/usr/bin/env bash
# ============================================================================
# SETUP SCRIPT
# Description: Initialize database with schema and optional seeds
# Usage: ./setup.sh [--no-seeds]
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
DB_NAME="${POSTGRES_DB:-n8n_clinic_db}"
DB_USER="${POSTGRES_USER:-n8n_clinic}"
SCHEMA_FILE="${SCRIPT_DIR}/../db/schema/schema.sql"
SEEDS_DIR="${SCRIPT_DIR}/../db/seeds"
APPLY_SEEDS="${APPLY_SEEDS:-true}"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-seeds)
            APPLY_SEEDS="false"
            shift
            ;;
    esac
done

echo "════════════════════════════════════════════════════════════════"
echo "🚀 DATABASE SETUP"
echo "════════════════════════════════════════════════════════════════"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo "Apply seeds: $APPLY_SEEDS"
echo ""

# Check if postgres container is running
echo "[setup] Checking PostgreSQL..."
if ! docker compose ps postgres 2>/dev/null | grep -q "Up"; then
    echo "[setup] Starting postgres..."
    docker compose up -d postgres
    echo "[setup] Waiting for postgres to be ready..."
    sleep 5
fi

# Wait for postgres to be ready
echo "[setup] Waiting for database connection..."
for i in {1..30}; do
    if docker compose exec -T postgres pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
        echo "[setup] Database is ready!"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "[setup] ERROR: Postgres did not become ready within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Apply schema
echo ""
echo "[setup] Applying schema..."
if docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$SCHEMA_FILE"; then
    echo "[setup] ✅ Schema applied successfully"
else
    echo "[setup] ❌ ERROR: Schema apply failed"
    exit 1
fi

# Apply seeds if enabled
if [[ "$APPLY_SEEDS" == "true" ]] && [[ -d "$SEEDS_DIR" ]]; then
    echo ""
    echo "[setup] Applying seed files..."
    for f in "$SEEDS_DIR"/*.sql; do
        [[ -f "$f" ]] || continue
        filename=$(basename "$f")
        echo "[setup] Seeding $filename..."
        if docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" < "$f"; then
            echo "[setup] ✅ $filename applied"
        else
            echo "[setup] ⚠️  WARNING: $filename failed (non-fatal)"
        fi
    done
fi

# Health check
echo ""
echo "[setup] Running health check..."
TABLE_COUNT=$(docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')

if [[ "$TABLE_COUNT" -gt 0 ]]; then
    echo "[setup] ✅ Database has $TABLE_COUNT tables"
else
    echo "[setup] ❌ ERROR: No tables found"
    exit 1
fi

# Show summary
TENANT_COUNT=$(docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -t -c \
    "SELECT COUNT(*) FROM tenant_config WHERE is_active = true;" 2>/dev/null | tr -d ' ' || echo "0")

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ SETUP COMPLETE"
echo "════════════════════════════════════════════════════════════════"
echo "Tables: $TABLE_COUNT"
echo "Active tenants: $TENANT_COUNT"
echo ""
echo "Next steps:"
echo "  1. Update tenant config with real Evolution API instance name"
echo "  2. Configure Google Calendar credentials"
echo "  3. Run: docker compose up -d"
echo "════════════════════════════════════════════════════════════════"