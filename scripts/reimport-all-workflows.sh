#!/bin/bash
set -e

# ============================================================================
# Reimport All Workflows to n8n
# ============================================================================
# This script reimports all workflow JSON files to n8n
# It tries multiple methods in order of preference:
# 1. Python script (most robust - updates existing workflows)
# 2. REST API script (bash with curl)
# 3. CLI script (uses n8n CLI inside container)
#
# Usage: ./scripts/reimport-all-workflows.sh
# ============================================================================

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}🚀 Reimporting all workflows to n8n${NC}"
echo ""

# Configuration
N8N_URL="${N8N_URL:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"

# Method 1: Try Python script (most robust)
if command -v python3 &> /dev/null && python3 -c "import requests" 2>/dev/null; then
    echo -e "${BLUE}📦 Method 1: Using Python script (recommended)${NC}"
    echo ""
    cd "$PROJECT_DIR"
    if [ -n "$N8N_API_KEY" ]; then
        N8N_URL="$N8N_URL" N8N_API_KEY="$N8N_API_KEY" python3 scripts/import-workflows-n8n.py
    else
        N8N_URL="$N8N_URL" python3 scripts/import-workflows-n8n.py
    fi
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Import completed successfully!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Python script failed, trying alternative method...${NC}"
        echo ""
    fi
fi

# Method 2: Try REST API script
if command -v curl &> /dev/null; then
    echo -e "${BLUE}📦 Method 2: Using REST API script${NC}"
    echo ""
    cd "$PROJECT_DIR"
    if [ -n "$N8N_PASS" ]; then
        N8N_URL="$N8N_URL" N8N_USER="${N8N_USER:-admin}" N8N_PASS="$N8N_PASS" bash scripts/import-workflows.sh
    else
        N8N_URL="$N8N_URL" bash scripts/import-workflows.sh
    fi
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Import completed successfully!${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  REST API script failed, trying CLI method...${NC}"
        echo ""
    fi
fi

# Method 3: Try CLI script (requires Docker)
if command -v docker &> /dev/null && docker compose ps n8n 2>/dev/null | grep -q "Up"; then
    echo -e "${BLUE}📦 Method 3: Using n8n CLI (inside container)${NC}"
    echo ""
    cd "$PROJECT_DIR"
    bash scripts/import-all-workflows-cli.sh
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✅ Import completed successfully!${NC}"
        exit 0
    fi
fi

# If all methods failed
echo -e "${RED}❌ All import methods failed${NC}"
echo ""
echo -e "${YELLOW}📝 Manual import instructions:${NC}"
echo "1. Open n8n UI: ${N8N_URL}"
echo "2. Go to Workflows > Import from File"
echo "3. Import each workflow from:"
echo "   - workflows/main/*.json"
echo "   - workflows/sub/*.json"
echo "   - workflows/tools/**/*.json"
echo ""
echo -e "${BLUE}💡 Tips:${NC}"
echo "- Make sure n8n is running: docker compose up -d n8n"
echo "- Check n8n is accessible: curl ${N8N_URL}/healthz"
echo "- Set N8N_API_KEY if using API authentication"
echo "- Set N8N_PASS if using basic auth"
exit 1
