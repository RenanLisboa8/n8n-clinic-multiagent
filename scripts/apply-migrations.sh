#!/bin/bash
set -e

# ============================================================================
# Apply Pending Migrations Script
# ============================================================================
# This script applies migrations to an existing database.
# Use this when you want to update without losing data.
#
# Usage: ./scripts/apply-migrations.sh
# ============================================================================

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Database connection parameters
DB_NAME="${POSTGRES_DB:-n8n_clinic_db}"
DB_USER="${POSTGRES_USER:-n8n_clinic}"

echo -e "${BLUE}📦 Applying pending migrations...${NC}"
echo ""

# Check if container is running
if ! docker compose ps postgres | grep -q "Up"; then
    echo -e "${RED}❌ PostgreSQL container is not running!${NC}"
    echo "Start it with: docker compose up -d postgres"
    exit 1
fi

# Migrations to apply (only newer ones that might not be in init-db.sh)
MIGRATIONS=(
    "017_add_services_faq.sql"
    "018_unique_services_catalog.sql"
    "019_update_appointment_faq_show_catalog.sql"
    "020_get_service_by_number.sql"
)

APPLIED=0
SKIPPED=0

for migration in "${MIGRATIONS[@]}"; do
    MIGRATION_PATH="scripts/migrations/${migration}"
    if [ -f "$MIGRATION_PATH" ]; then
        echo -e "${BLUE}Applying ${YELLOW}${migration}${NC}..."
        docker compose exec -T postgres psql -U "${DB_USER}" -d "${DB_NAME}" < "$MIGRATION_PATH" 2>&1 | grep -v "NOTICE" || true
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo -e "${GREEN}✅ ${migration} applied${NC}"
            ((APPLIED++))
        else
            echo -e "${YELLOW}⚠️  ${migration} may have errors (check output above)${NC}"
            ((SKIPPED++))
        fi
        echo ""
    else
        echo -e "${YELLOW}⚠️  ${migration} not found${NC}"
        ((SKIPPED++))
    fi
done

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    Migration Summary                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✅ Applied: ${APPLIED}${NC}"
if [ $SKIPPED -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Skipped/Errors: ${SKIPPED}${NC}"
fi
echo ""
