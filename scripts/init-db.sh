#!/bin/bash
# ====================================
# Database Initialization Script
# For n8n Clinic Multi-Agent System
# ====================================

set -e

echo "🔧 Initializing PostgreSQL database..."

# SQL commands to execute
SQL_COMMANDS=$(cat <<-EOSQL
    -- Enable UUID extension
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Enable pgcrypto for encryption functions
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    
    -- Create schema for Evolution API if not exists
    CREATE SCHEMA IF NOT EXISTS evolution;
    
    -- Grant permissions (using current user)
    GRANT ALL PRIVILEGES ON SCHEMA evolution TO CURRENT_USER;
EOSQL
)

# Check if running inside Docker container or externally
if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    # Running inside container (Docker entrypoint)
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "$SQL_COMMANDS"
else
    # Running externally - use docker exec
    CONTAINER_NAME="${POSTGRES_CONTAINER:-clinic_postgres}"
    DB_NAME="${POSTGRES_DB:-n8n_clinic_db}"
    DB_USER="${POSTGRES_USER:-n8n_clinic}"
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ PostgreSQL container '$CONTAINER_NAME' is not running"
        echo "ℹ Start it with: docker compose up -d postgres"
        exit 1
    fi
    
    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "$SQL_COMMANDS"
fi

echo "✅ Database initialization completed successfully!"
