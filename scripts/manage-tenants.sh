#!/bin/bash

# ============================================================================
# TENANT MANAGEMENT CLI UTILITY
# Version: 1.0.0
# Description: Manage tenants via command line
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Database connection from environment
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-n8n}"
DB_USER="${POSTGRES_USER:-n8n}"
DB_PASSWORD="${POSTGRES_PASSWORD}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

execute_sql() {
    local sql="$1"
    PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$sql"
}

# ============================================================================
# COMMAND FUNCTIONS
# ============================================================================

list_tenants() {
    log_info "Listing all tenants..."
    echo ""
    
    PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            tenant_name,
            evolution_instance_name,
            clinic_name,
            subscription_tier,
            CASE WHEN is_active THEN '✅ Active' ELSE '❌ Inactive' END as status,
            current_message_count || '/' || monthly_message_limit as quota,
            created_at::date as created
        FROM tenant_config
        ORDER BY created_at DESC;
    "
}

show_tenant() {
    local instance_name="$1"
    
    if [ -z "$instance_name" ]; then
        log_error "Instance name required"
        echo "Usage: $0 show <instance_name>"
        exit 1
    fi
    
    log_info "Fetching details for: $instance_name"
    echo ""
    
    PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            tenant_name,
            evolution_instance_name,
            clinic_name,
            clinic_address,
            clinic_phone,
            clinic_email,
            timezone,
            hours_start || ' - ' || hours_end as business_hours,
            google_calendar_id,
            telegram_internal_chat_id,
            subscription_tier,
            subscription_status,
            current_message_count || '/' || monthly_message_limit as quota,
            CASE WHEN is_active THEN '✅ Active' ELSE '❌ Inactive' END as status,
            created_at,
            updated_at
        FROM tenant_config
        WHERE evolution_instance_name = '$instance_name';
    "
}

deactivate_tenant() {
    local instance_name="$1"
    
    if [ -z "$instance_name" ]; then
        log_error "Instance name required"
        echo "Usage: $0 deactivate <instance_name>"
        exit 1
    fi
    
    log_warning "Deactivating tenant: $instance_name"
    
    execute_sql "UPDATE tenant_config SET is_active = false WHERE evolution_instance_name = '$instance_name';"
    
    log_success "Tenant deactivated: $instance_name"
}

activate_tenant() {
    local instance_name="$1"
    
    if [ -z "$instance_name" ]; then
        log_error "Instance name required"
        echo "Usage: $0 activate <instance_name>"
        exit 1
    fi
    
    log_info "Activating tenant: $instance_name"
    
    execute_sql "UPDATE tenant_config SET is_active = true WHERE evolution_instance_name = '$instance_name';"
    
    log_success "Tenant activated: $instance_name"
}

reset_quota() {
    local instance_name="$1"
    
    if [ -z "$instance_name" ]; then
        log_error "Instance name required"
        echo "Usage: $0 reset-quota <instance_name>"
        exit 1
    fi
    
    log_info "Resetting message quota for: $instance_name"
    
    execute_sql "UPDATE tenant_config SET current_message_count = 0, last_quota_reset = CURRENT_DATE WHERE evolution_instance_name = '$instance_name';"
    
    log_success "Quota reset for: $instance_name"
}

reset_all_quotas() {
    log_info "Resetting all monthly quotas..."
    
    result=$(execute_sql "SELECT reset_monthly_quotas();")
    
    log_success "Reset $result tenant quotas"
}

check_health() {
    log_info "Checking tenant configuration health..."
    echo ""
    
    # Check for tenants without calendar config
    echo "Tenants missing calendar configuration:"
    PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT tenant_name, evolution_instance_name
        FROM tenant_config
        WHERE is_active = true
        AND (google_calendar_id IS NULL OR mcp_calendar_endpoint IS NULL);
    "
    
    echo ""
    echo "Tenants exceeding quota:"
    PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            tenant_name,
            current_message_count,
            monthly_message_limit,
            ROUND((current_message_count::NUMERIC / monthly_message_limit) * 100, 2) as usage_percent
        FROM tenant_config
        WHERE is_active = true
        AND current_message_count >= monthly_message_limit;
    "
}

show_usage() {
    cat << EOF
Tenant Management CLI

Usage: $0 <command> [options]

Commands:
    list                    List all tenants
    show <instance_name>    Show detailed tenant information
    activate <instance>     Activate a tenant
    deactivate <instance>   Deactivate a tenant
    reset-quota <instance>  Reset message quota for tenant
    reset-all-quotas        Reset all monthly quotas
    health                  Check tenant configuration health
    help                    Show this help message

Examples:
    $0 list
    $0 show clinic_moreira_instance
    $0 deactivate test_clinic_instance
    $0 reset-quota clinic_moreira_instance

EOF
}

# ============================================================================
# MAIN
# ============================================================================

if [ -z "$DB_PASSWORD" ]; then
    log_error "POSTGRES_PASSWORD environment variable not set"
    exit 1
fi

case "$1" in
    list)
        list_tenants
        ;;
    show)
        show_tenant "$2"
        ;;
    activate)
        activate_tenant "$2"
        ;;
    deactivate)
        deactivate_tenant "$2"
        ;;
    reset-quota)
        reset_quota "$2"
        ;;
    reset-all-quotas)
        reset_all_quotas
        ;;
    health)
        check_health
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac

