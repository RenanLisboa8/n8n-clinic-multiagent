#!/usr/bin/env bash
# ============================================================================
# RESET SCRIPT (DEV ONLY)
# Description: Wipe database and re-apply schema + seeds
# Usage: RESET_DEV=1 ./reset.sh
# ============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
DB_NAME="${POSTGRES_DB:-n8n_clinic_db}"
DB_USER="${POSTGRES_USER:-n8n_clinic}"

echo "════════════════════════════════════════════════════════════════"
echo "⚠️  DATABASE RESET (DEV ONLY)"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "This will DROP ALL DATA in the database: $DB_NAME"
echo ""

# Safety check
if [[ "$RESET_DEV" != "1" ]]; then
    read -p "Type RESET to confirm: " confirm
    if [[ "$confirm" != "RESET" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo ""
echo "[reset] Dropping and recreating database..."

# Try dropping the database (requires postgres superuser)
if docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null; then
    docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || true
    echo "[reset] ✅ Database recreated"
else
    # Fallback: drop all tables in public schema
    echo "[reset] Cannot drop database, dropping all objects in public schema..."
    docker compose exec -T postgres psql -U "$DB_USER" -d "$DB_NAME" -c "
        DROP SCHEMA public CASCADE;
        CREATE SCHEMA public;
        GRANT ALL ON SCHEMA public TO ${DB_USER};
        GRANT ALL ON SCHEMA public TO public;
    " 2>/dev/null || true
    echo "[reset] ✅ Schema reset"
fi

echo ""
echo "[reset] Running setup..."
exec "$SCRIPT_DIR/setup.sh"