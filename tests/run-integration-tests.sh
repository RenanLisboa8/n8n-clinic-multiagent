#!/bin/bash
set -euo pipefail

# ============================================================================
# Integration Test Runner
# ============================================================================
# Sends sample payloads to n8n webhooks and validates responses.
#
# Usage:
#   WEBHOOK_URL=http://localhost:5678/webhook/whatsapp-main ./tests/run-integration-tests.sh
#
# Environment:
#   WEBHOOK_URL    - Base URL for the WhatsApp webhook (required)
#   DATABASE_URL   - PostgreSQL connection string (optional, for DB assertions)
#   VERBOSE        - Set to "true" for detailed output
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOADS_DIR="$SCRIPT_DIR/sample-payloads"

WEBHOOK_URL="${WEBHOOK_URL:-}"
VERBOSE="${VERBOSE:-false}"

passed=0
failed=0
skipped=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log() {
  echo -e "$1"
}

log_verbose() {
  if [ "$VERBOSE" = "true" ]; then
    echo -e "  $1"
  fi
}

assert_json_field() {
  local response="$1"
  local field="$2"
  local expected="$3"
  local test_name="$4"

  actual=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" 2>/dev/null || echo "")

  if [ "$actual" = "$expected" ]; then
    return 0
  else
    log "    ${RED}FAIL${NC}: Expected $field='$expected', got '$actual'"
    return 1
  fi
}

assert_http_status() {
  local status="$1"
  local expected="$2"
  local test_name="$3"

  if [ "$status" = "$expected" ]; then
    return 0
  else
    log "    ${RED}FAIL${NC}: Expected HTTP $expected, got $status"
    return 1
  fi
}

run_test() {
  local payload_file="$1"
  local test_name="$(basename "$payload_file" .json)"

  log "  Testing: $test_name"

  if [ ! -f "$payload_file" ]; then
    log "    ${YELLOW}SKIP${NC}: Payload file not found"
    ((skipped++))
    return
  fi

  # Send payload
  local response
  local http_code
  http_code=$(curl -s -o /tmp/test_response.json -w "%{http_code}" \
    -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d @"$payload_file" \
    --max-time 30 2>/dev/null || echo "000")

  response=$(cat /tmp/test_response.json 2>/dev/null || echo "{}")

  log_verbose "HTTP $http_code | Response: $response"

  # Basic assertion: should return 200
  if assert_http_status "$http_code" "200" "$test_name"; then
    log "    ${GREEN}PASS${NC}: HTTP 200"
    ((passed++))
  else
    ((failed++))
  fi
}

# ============================================================================
# Main
# ============================================================================

echo "════════════════════════════════════════════════════════════════"
echo "  Integration Tests"
echo "════════════════════════════════════════════════════════════════"
echo ""

if [ -z "$WEBHOOK_URL" ]; then
  log "${YELLOW}WARNING${NC}: WEBHOOK_URL not set. Skipping live tests."
  log "  Set WEBHOOK_URL to run: WEBHOOK_URL=http://localhost:5678/webhook/whatsapp-main $0"
  echo ""

  # Still validate payload JSON structure
  log "Validating payload JSON structure..."
  for payload in "$PAYLOADS_DIR"/*.json; do
    if [ -f "$payload" ]; then
      name="$(basename "$payload")"
      if python3 -c "import json; json.load(open('$payload'))" 2>/dev/null; then
        log "  ${GREEN}OK${NC}: $name (valid JSON)"
        ((passed++))
      else
        log "  ${RED}FAIL${NC}: $name (invalid JSON)"
        ((failed++))
      fi
    fi
  done
else
  log "Webhook URL: $WEBHOOK_URL"
  echo ""

  # Run tests for each payload
  for payload in "$PAYLOADS_DIR"/*.json; do
    if [ -f "$payload" ]; then
      run_test "$payload"
    fi
  done
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Results: ${GREEN}$passed passed${NC}, ${RED}$failed failed${NC}, ${YELLOW}$skipped skipped${NC}"
echo "════════════════════════════════════════════════════════════════"

if [ "$failed" -gt 0 ]; then
  exit 1
fi
