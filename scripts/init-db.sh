#!/bin/bash
# ====================================
# Database Initialization Script
# For n8n Clinic Multi-Agent System
# ====================================

set -e

echo "🔧 Initializing PostgreSQL database..."

# Create extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable UUID extension
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Enable pgcrypto for encryption functions
    CREATE EXTENSION IF NOT EXISTS "pgcrypto";
    
    -- Create schema for Evolution API if not exists
    CREATE SCHEMA IF NOT EXISTS evolution;
    
    -- Grant permissions
    GRANT ALL PRIVILEGES ON SCHEMA evolution TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
EOSQL

echo "✅ Database initialization completed successfully!"

