#!/bin/bash
set -e

# ============================================================================
# PostgreSQL Database Initialization Script
# ============================================================================
# This script runs automatically when the PostgreSQL container is first
# initialized (only when the data directory is empty).
#
# Note: For existing databases, run migrations manually using:
#   ./scripts/apply-migrations.sh
# ============================================================================

echo "Initializing database schema..."

# Get database connection parameters from environment
DB_NAME="${POSTGRES_DB:-n8n_clinic_db}"
DB_USER="${POSTGRES_USER:-n8n_clinic}"

# Directory where migration files are located (mounted from host)
MIGRATIONS_DIR="/docker-entrypoint-initdb.d/migrations"

# Check if migrations directory exists and has files
if [ -d "$MIGRATIONS_DIR" ] && [ "$(ls -A $MIGRATIONS_DIR/*.sql 2>/dev/null)" ]; then
    echo "Running migration files from $MIGRATIONS_DIR..."
    
    # Run migrations in order (all migrations including latest)
    MIGRATIONS=(
        "001_create_tenant_tables.sql"
        "002_seed_tenant_data.sql"
        "003_create_faq_table.sql"
        "004_create_service_catalog_architecture.sql"
        "005_seed_service_catalog_data.sql"
        "015_add_clinic_type_field.sql"
        "017_add_services_faq.sql"
        "018_unique_services_catalog.sql"
        "019_update_appointment_faq_show_catalog.sql"
        "020_get_service_by_number.sql"
    )
    
    for migration in "${MIGRATIONS[@]}"; do
        migration_path="$MIGRATIONS_DIR/$migration"
        if [ -f "$migration_path" ]; then
            echo "Running $(basename $migration)..."
            psql -v ON_ERROR_STOP=1 --username "$DB_USER" --dbname "$DB_NAME" < "$migration_path" 2>&1 | grep -v "^NOTICE:" || true
        else
            echo "Warning: $migration not found, skipping..."
        fi
    done
    
    echo "Database initialization completed successfully!"
else
    echo "No migration files found in $MIGRATIONS_DIR"
    echo "Skipping migrations - database will be initialized with default schema only"
    echo "Run migrations manually after container startup if needed"
fi
