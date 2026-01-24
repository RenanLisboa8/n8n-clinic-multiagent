#!/bin/bash
set -e

# Don't fail on errors in workflow import (n8n CLI may return error codes even on success)
set +e

# ============================================================================
# Import ALL Workflows to n8n using n8n CLI
# ============================================================================
# This script imports all workflows (main, sub, tools) using n8n CLI
# It tries multiple strategies for workflows that fail initially
#
# Usage: ./scripts/import-all-workflows-cli.sh
# ============================================================================

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Importing ALL workflows using n8n CLI${NC}"
echo ""

# Check if n8n container is running
if ! docker compose ps n8n | grep -q "Up"; then
    echo -e "${RED}❌ n8n container is not running!${NC}"
    echo "Start it with: docker compose up -d n8n"
    exit 1
fi

echo -e "${GREEN}✅ n8n container is running${NC}"
echo ""

# Find all workflow JSON files in order: main, sub, tools
MAIN_WORKFLOWS=($(find workflows/main -name "*.json" -type f | sort))
SUB_WORKFLOWS=($(find workflows/sub -name "*.json" -type f | sort))
TOOL_WORKFLOWS=($(find workflows/tools -name "*.json" -type f | sort))

ALL_WORKFLOWS=("${MAIN_WORKFLOWS[@]}" "${SUB_WORKFLOWS[@]}" "${TOOL_WORKFLOWS[@]}")
TOTAL=${#ALL_WORKFLOWS[@]}
IMPORTED=0
UPDATED=0
FAILED=0
FAILED_FILES=()

echo -e "${BLUE}📦 Found ${TOTAL} workflows to import${NC}"
echo -e "${BLUE}   - Main: ${#MAIN_WORKFLOWS[@]}${NC}"
echo -e "${BLUE}   - Sub: ${#SUB_WORKFLOWS[@]}${NC}"
echo -e "${BLUE}   - Tools: ${#TOOL_WORKFLOWS[@]}${NC}"
echo ""

# Function to import a workflow
import_workflow() {
    local workflow_file="$1"
    local workflow_name=$(basename "$workflow_file")
    local attempt="$2"
    
    # Copy workflow to container temp directory
    docker cp "$workflow_file" clinic_n8n:/tmp/"${workflow_name}" > /dev/null 2>&1
    
    # Try different import strategies
    local output=""
    if [ "$attempt" == "1" ]; then
        # First attempt: standard import
        output=$(docker compose exec -T n8n n8n import:workflow --input=/tmp/"${workflow_name}" 2>&1 || true)
    elif [ "$attempt" == "2" ]; then
        # Second attempt: with --force flag
        output=$(docker compose exec -T n8n n8n import:workflow --input=/tmp/"${workflow_name}" --force 2>&1 || true)
    else
        # Third attempt: try to update existing workflow by name
        # Extract workflow name from JSON
        local wf_name=$(docker compose exec -T n8n sh -c "cat /tmp/${workflow_name} | grep -o '\"name\":\"[^\"]*\"' | head -1 | cut -d'\"' -f4" 2>/dev/null || echo "")
        if [ -n "$wf_name" ]; then
            # Try to get workflow ID by name and update
            output=$(docker compose exec -T n8n n8n import:workflow --input=/tmp/"${workflow_name}" --update 2>&1 || true)
        else
            output=$(docker compose exec -T n8n n8n import:workflow --input=/tmp/"${workflow_name}" 2>&1 || true)
        fi
    fi
    
    # Cleanup
    docker compose exec -T n8n rm -f /tmp/"${workflow_name}" > /dev/null 2>&1
    
    # Check output for success
    if echo "$output" | grep -qiE "Successfully imported|Workflow.*imported|already exists"; then
        echo "$output"
        return 0
    elif echo "$output" | grep -qiE "updated|Updated"; then
        echo "$output"
        return 2
    else
        echo "$output"
        return 1
    fi
}

# Import each workflow
for workflow_file in "${ALL_WORKFLOWS[@]}"; do
    workflow_name=$(basename "$workflow_file")
    workflow_type=""
    
    # Determine workflow type for display
    if [[ "$workflow_file" == *"/main/"* ]]; then
        workflow_type="[MAIN]"
    elif [[ "$workflow_file" == *"/sub/"* ]]; then
        workflow_type="[SUB]"
    else
        workflow_type="[TOOL]"
    fi
    
    echo -e "${BLUE}Importing ${workflow_type} ${YELLOW}${workflow_name}${NC}..."
    
    # Try importing with multiple attempts
    success=false
    for attempt in 1 2 3; do
        if [ $attempt -gt 1 ]; then
            echo -e "  ${YELLOW}  Retry attempt ${attempt}...${NC}"
        fi
        
        output=$(import_workflow "$workflow_file" "$attempt")
        result=$?
        
        if [ $result -eq 0 ]; then
            echo -e "  ${GREEN}✅ Imported successfully${NC}"
            ((IMPORTED++))
            success=true
            break
        elif [ $result -eq 2 ]; then
            echo -e "  ${GREEN}✅ Updated successfully${NC}"
            ((UPDATED++))
            success=true
            break
        fi
    done
    
    if [ "$success" = false ]; then
        echo -e "  ${RED}❌ Failed after 3 attempts${NC}"
        # Show last error
        error_msg=$(echo "$output" | grep -iE "error|failed|constraint" | tail -1)
        if [ -n "$error_msg" ]; then
            echo -e "  ${YELLOW}   Error: ${error_msg:0:100}${NC}"
        fi
        ((FAILED++))
        FAILED_FILES+=("$workflow_file")
    fi
    echo ""
done

# Summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Import Summary                             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "${GREEN}✅ Imported: ${IMPORTED}${NC}"
if [ $UPDATED -gt 0 ]; then
    echo -e "${GREEN}🔄 Updated: ${UPDATED}${NC}"
fi
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}❌ Failed: ${FAILED}${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  Failed workflows:${NC}"
    for failed_file in "${FAILED_FILES[@]}"; do
        echo -e "${YELLOW}   - ${failed_file}${NC}"
    done
    echo ""
    echo -e "${YELLOW}💡 Try importing manually via n8n UI:${NC}"
    echo "   1. Open: http://localhost:5678"
    echo "   2. Go to: Workflows > Import from File"
    echo "   3. Import each failed workflow"
else
    echo -e "${GREEN}✅ All workflows imported successfully!${NC}"
    echo ""
    echo -e "${BLUE}📝 Next steps:${NC}"
    echo -e "${BLUE}   1. Open n8n UI: http://localhost:5678${NC}"
    echo -e "${BLUE}   2. Configure credentials (see CONFIGURACAO_POS_IMPORT.md)${NC}"
    echo -e "${BLUE}   3. Activate main workflows:${NC}"
    echo -e "${BLUE}      - 01 - WhatsApp Patient Handler (AI Optimized)${NC}"
    echo -e "${BLUE}      - 04 - Error Handler${NC}"
fi

if [ $FAILED -gt 0 ]; then
    exit 1
fi
