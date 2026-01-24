#!/bin/bash
set -e

# ============================================================================
# Database Reset Script - Clean and Recreate Database
# ============================================================================
# This script drops all data and recreates the database from scratch.
# WARNING: This will DELETE ALL DATA!
#
# Usage: ./scripts/reset-db.sh
# ============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database connection parameters
DB_NAME="${POSTGRES_DB:-n8n_clinic_db}"
DB_USER="${POSTGRES_USER:-n8n_clinic}"

echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║         ⚠️  DATABASE RESET - DESTRUCTIVE OPERATION ⚠️        ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}║  This will DELETE ALL DATA and recreate the database!        ║${NC}"
echo -e "${RED}║                                                               ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Database: ${DB_NAME}${NC}"
echo -e "${YELLOW}User: ${DB_USER}${NC}"
echo ""

# Check if container is running
if ! docker compose ps postgres | grep -q "Up"; then
    echo -e "${RED}❌ PostgreSQL container is not running!${NC}"
    echo "Start it with: docker compose up -d postgres"
    exit 1
fi

# Confirm action
read -p "$(echo -e ${RED}Type 'RESET' to confirm: ${NC})" confirmation
if [ "$confirmation" != "RESET" ]; then
    echo -e "${YELLOW}Operation cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}🔄 Starting database reset...${NC}"
echo ""

# Step 1: Drop and recreate database
echo -e "${BLUE}📦 Step 1/5: Dropping and recreating database...${NC}"

# Try to connect as postgres user first (most common)
docker compose exec -T postgres psql -U postgres -c "SELECT 1;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    # Connected as postgres - can drop/create
    docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
    docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || \
    docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE ${DB_NAME};"
    docker compose exec -T postgres psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>/dev/null || true
else
    # Can't connect as postgres - drop schema instead
    echo -e "${YELLOW}   Cannot connect as postgres user, dropping schema instead...${NC}"
    docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO ${DB_USER}; GRANT ALL ON SCHEMA public TO public;" 2>/dev/null || true
fi

echo -e "${GREEN}✅ Database recreated${NC}"
echo ""

# Step 2: Run migrations in order
echo -e "${BLUE}📦 Step 2/5: Running migrations...${NC}"
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
    MIGRATION_PATH="scripts/migrations/${migration}"
    if [ -f "$MIGRATION_PATH" ]; then
        echo -e "   Running ${YELLOW}${migration}${NC}..."
        docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" < "$MIGRATION_PATH"
        if [ $? -eq 0 ]; then
            echo -e "   ${GREEN}✅ ${migration}${NC}"
        else
            echo -e "   ${RED}❌ Error in ${migration}${NC}"
            exit 1
        fi
    else
        echo -e "   ${YELLOW}⚠️  ${migration} not found, skipping...${NC}"
    fi
done

echo -e "${GREEN}✅ All migrations completed${NC}"
echo ""

# Step 3: Verify database structure
echo -e "${BLUE}📦 Step 3/5: Verifying database structure...${NC}"
TABLE_COUNT=$(docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE';" | tr -d ' ')

if [ "$TABLE_COUNT" -gt "0" ]; then
    echo -e "${GREEN}✅ Database structure verified (${TABLE_COUNT} tables)${NC}"
else
    echo -e "${RED}❌ No tables found!${NC}"
    exit 1
fi
echo ""

# Step 4: Show summary
echo -e "${BLUE}📦 Step 4/5: Database summary...${NC}"
docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" <<EOF
\echo ''
\echo '════════════════════════════════════════════════════════════════'
\echo '📊 DATABASE SUMMARY'
\echo '════════════════════════════════════════════════════════════════'
\echo ''
\echo 'Tenants:'
SELECT tenant_name, clinic_name, is_active FROM tenant_config ORDER BY tenant_name;
\echo ''
\echo 'Services Catalog:'
SELECT COUNT(*) as total_services FROM services_catalog WHERE is_active = true;
\echo ''
\echo 'FAQ Entries:'
SELECT COUNT(*) as total_faq_entries FROM tenant_faq WHERE is_active = true;
\echo ''
\echo '════════════════════════════════════════════════════════════════'
EOF

echo ""
echo -e "${BLUE}📦 Step 5/5: Testing catalog function...${NC}"
docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT get_services_catalog_for_prompt((SELECT tenant_id FROM tenant_config WHERE is_active = true LIMIT 1));" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Catalog function working${NC}"
else
    echo -e "${YELLOW}⚠️  Catalog function test failed (may be expected if no tenants)${NC}"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║              ✅ DATABASE RESET COMPLETED! ✅                  ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📝 Next steps:${NC}"
echo "   1. Configure your tenant data if needed"
echo "   2. Start all services: docker compose up -d"
echo "   3. Import workflows in n8n UI"
echo ""
