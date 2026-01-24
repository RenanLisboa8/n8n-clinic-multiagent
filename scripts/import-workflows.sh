#!/bin/bash
set -e

# ============================================================================
# Import Workflows to n8n
# ============================================================================
# This script imports all workflow JSON files to n8n via REST API
#
# Usage: ./scripts/import-workflows.sh
# ============================================================================

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_USER="${N8N_USER:-admin}"
N8N_PASS="${N8N_PASS:-}"

# Check if n8n is accessible
echo -e "${BLUE}📦 Checking n8n availability...${NC}"
if ! curl -s "${N8N_URL}/healthz" > /dev/null 2>&1; then
    echo -e "${RED}❌ n8n is not accessible at ${N8N_URL}${NC}"
    echo "Make sure n8n is running: docker compose up -d n8n"
    exit 1
fi
echo -e "${GREEN}✅ n8n is accessible${NC}"
echo ""

# Try to import without authentication first (n8n may not require auth)
# If authentication is needed, user can set N8N_PASS environment variable
AUTH_HEADER=""
if [ -n "$N8N_PASS" ]; then
    AUTH_HEADER="-u ${N8N_USER}:${N8N_PASS}"
    echo -e "${BLUE}🔐 Using Basic Auth${NC}"
else
    echo -e "${BLUE}🔓 Attempting import without authentication${NC}"
    echo -e "${YELLOW}   (If it fails, set N8N_PASS env var or import manually via UI)${NC}"
fi
echo ""

# Find all workflow JSON files
WORKFLOWS=($(find workflows -name "*.json" -type f | sort))
TOTAL=${#WORKFLOWS[@]}
IMPORTED=0
FAILED=0

echo -e "${BLUE}📦 Found ${TOTAL} workflows to import${NC}"
echo ""

# Import each workflow
for workflow_file in "${WORKFLOWS[@]}"; do
    workflow_name=$(basename "$workflow_file" .json)
    echo -e "${BLUE}Importing ${YELLOW}${workflow_name}${NC}..."
    
    # Read workflow JSON
    if [ ! -f "$workflow_file" ]; then
        echo -e "  ${RED}❌ File not found${NC}"
        ((FAILED++))
        continue
    fi
    
    # Import workflow via API
    response=$(curl -s -w "\n%{http_code}" ${AUTH_HEADER} \
        -X POST \
        -H "Content-Type: application/json" \
        -d @"${workflow_file}" \
        "${N8N_URL}/api/v1/workflows" 2>&1)
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo -e "  ${GREEN}✅ Imported successfully${NC}"
        ((IMPORTED++))
    elif [ "$http_code" -eq 401 ] || [ "$http_code" -eq 403 ]; then
        echo -e "  ${RED}❌ Authentication failed${NC}"
        echo -e "${YELLOW}   Please import manually via n8n UI${NC}"
        ((FAILED++))
    else
        # Check if workflow already exists (409 Conflict or similar)
        if echo "$body" | grep -q "already exists\|duplicate\|409"; then
            echo -e "  ${YELLOW}⚠️  Already exists (skipping)${NC}"
            ((IMPORTED++))
        else
            echo -e "  ${RED}❌ Failed (HTTP ${http_code})${NC}"
            echo -e "  ${YELLOW}Response: ${body:0:200}${NC}"
            ((FAILED++))
        fi
    fi
    echo ""
done

# Summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Import Summary                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✅ Imported: ${IMPORTED}${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ Failed: ${FAILED}${NC}"
fi
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Some workflows failed to import${NC}"
    echo -e "${YELLOW}   You can import them manually via n8n UI: ${N8N_URL}${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All workflows imported successfully!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next steps:${NC}"
    echo "1. Open n8n UI: ${N8N_URL}"
    echo "2. Configure credentials (see CONFIGURACAO_POS_IMPORT.md)"
    echo "3. Activate main workflows:"
    echo "   - 01 - WhatsApp Patient Handler (AI Optimized)"
    echo "   - 04 - Error Handler"
    echo "4. Deactivate tool workflows (they are called by main workflows)"
fi
