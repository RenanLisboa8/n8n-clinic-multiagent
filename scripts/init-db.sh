#!/bin/bash
set -euo pipefail

# ============================================================================
# PostgreSQL Database Initialization Script
# ============================================================================
# Runs the consolidated schema and seed files in order.
#
# Usage:
#   DATABASE_URL=postgres://user:pass@host:5432/dbname ./scripts/init-db.sh
#
# Or with individual env vars:
#   PGHOST=localhost PGPORT=5432 PGDATABASE=n8n_clinic_db PGUSER=n8n_clinic ./scripts/init-db.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SCHEMA_FILE="$PROJECT_ROOT/scripts/db/schema/schema.sql"
SEEDS_DIR="$PROJECT_ROOT/scripts/db/seeds"
MIGRATIONS_DIR="$PROJECT_ROOT/scripts/db/migrations"

# Build psql connection args
if [ -n "${DATABASE_URL:-}" ]; then
  PSQL_CMD="psql $DATABASE_URL"
else
  DB_HOST="${PGHOST:-localhost}"
  DB_PORT="${PGPORT:-5432}"
  DB_NAME="${PGDATABASE:-n8n_clinic_db}"
  DB_USER="${PGUSER:-n8n_clinic}"
  PSQL_CMD="psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
fi

echo "════════════════════════════════════════════════════════════════"
echo "  Database Initialization"
echo "════════════════════════════════════════════════════════════════"

# Step 1: Run consolidated schema
if [ -f "$SCHEMA_FILE" ]; then
  echo ""
  echo "Step 1: Running consolidated schema..."
  $PSQL_CMD -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE" 2>&1 | grep -v "^NOTICE:" || true
  echo "  Schema applied successfully."
else
  echo "ERROR: Schema file not found at $SCHEMA_FILE"
  exit 1
fi

# Step 2: Run seed files in order
if [ -d "$SEEDS_DIR" ]; then
  echo ""
  echo "Step 2: Running seed files..."
  for seed in "$SEEDS_DIR"/[0-9]*.sql; do
    if [ -f "$seed" ]; then
      echo "  Running: $(basename "$seed")"
      $PSQL_CMD -v ON_ERROR_STOP=1 -f "$seed" 2>&1 | grep -v "^NOTICE:" || true
    fi
  done
  echo "  Seeds applied successfully."
else
  echo "WARNING: Seeds directory not found at $SEEDS_DIR, skipping."
fi

# Step 3: Run pending migrations (optional)
if [ -d "$MIGRATIONS_DIR" ] && [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
  echo ""
  echo "Step 3: Running migrations..."
  for migration in "$MIGRATIONS_DIR"/[0-9]*.sql; do
    if [ -f "$migration" ]; then
      echo "  Running: $(basename "$migration")"
      $PSQL_CMD -v ON_ERROR_STOP=1 -f "$migration" 2>&1 | grep -v "^NOTICE:" || true
    fi
  done
  echo "  Migrations applied successfully."
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Database initialized successfully!"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Configure tenant with: python scripts/cli/cli.py add-tenant ..."
echo "  2. Set up Google Calendar OAuth credentials"
echo "  3. Import workflows to n8n (replace {{PLACEHOLDER}} tokens)"
echo ""
