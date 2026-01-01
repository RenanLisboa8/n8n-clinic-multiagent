-- ============================================================================
-- MULTI-TENANT MIGRATION SCRIPT
-- Version: 1.0.0
-- Date: 2026-01-01
-- Description: Creates tenant configuration tables for multi-tenant support
-- ============================================================================

-- ============================================================================
-- 1. CREATE TENANT_CONFIG TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_config (
    -- Primary Key
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Tenant Identification
    tenant_name VARCHAR(100) NOT NULL UNIQUE,
    tenant_slug VARCHAR(50) NOT NULL UNIQUE,
    evolution_instance_name VARCHAR(100) NOT NULL UNIQUE,
    
    -- Status & Metadata
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Business Information
    clinic_name VARCHAR(200) NOT NULL,
    clinic_address TEXT,
    clinic_phone VARCHAR(20),
    clinic_email VARCHAR(100),
    timezone VARCHAR(50) NOT NULL DEFAULT 'America/Sao_Paulo',
    
    -- Business Hours
    hours_start TIME NOT NULL DEFAULT '08:00',
    hours_end TIME NOT NULL DEFAULT '19:00',
    days_open_display VARCHAR(50) DEFAULT 'Segunda–Sábado',
    operating_days JSONB DEFAULT '["1","2","3","4","5","6"]'::jsonb,
    
    -- Integration Configuration (Non-Sensitive)
    google_calendar_id VARCHAR(255),
    google_calendar_public_link TEXT,
    google_tasks_list_id VARCHAR(255),
    mcp_calendar_endpoint TEXT,
    
    -- Communication Configuration
    telegram_internal_chat_id VARCHAR(50),
    whatsapp_number VARCHAR(20),
    
    -- AI Configuration
    system_prompt_patient TEXT NOT NULL,
    system_prompt_internal TEXT NOT NULL,
    system_prompt_confirmation TEXT NOT NULL,
    llm_model_name VARCHAR(100) DEFAULT 'gemini-2.0-flash-exp',
    llm_temperature NUMERIC(2,1) DEFAULT 0.7,
    
    -- Feature Flags
    features JSONB DEFAULT '{
        "audio_transcription": true,
        "image_ocr": true,
        "appointment_confirmation": true,
        "telegram_internal_assistant": true,
        "human_escalation": true
    }'::jsonb,
    
    -- Limits & Quotas
    monthly_message_limit INTEGER DEFAULT 10000,
    current_message_count INTEGER DEFAULT 0,
    last_quota_reset DATE DEFAULT CURRENT_DATE,
    
    -- Subscription & Billing
    subscription_tier VARCHAR(50) DEFAULT 'basic',
    subscription_status VARCHAR(50) DEFAULT 'active',
    next_billing_date DATE,
    
    -- Audit
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT valid_hours CHECK (hours_start < hours_end),
    CONSTRAINT valid_temperature CHECK (llm_temperature BETWEEN 0.0 AND 2.0),
    CONSTRAINT valid_tier CHECK (subscription_tier IN ('basic', 'professional', 'enterprise')),
    CONSTRAINT valid_status CHECK (subscription_status IN ('active', 'suspended', 'cancelled', 'trial'))
);

-- ============================================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Fast lookup by Evolution API instance name (most common query)
CREATE INDEX idx_tenant_evolution_instance 
ON tenant_config(evolution_instance_name) 
WHERE is_active = true;

-- Fast lookup by slug (for admin UI)
CREATE INDEX idx_tenant_slug 
ON tenant_config(tenant_slug) 
WHERE is_active = true;

-- Filter active tenants
CREATE INDEX idx_tenant_active 
ON tenant_config(is_active);

-- Quota management queries
CREATE INDEX idx_tenant_quota_reset 
ON tenant_config(last_quota_reset);

-- ============================================================================
-- 3. CREATE UPDATE TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_tenant_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tenant_config_updated_at
    BEFORE UPDATE ON tenant_config
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_config_timestamp();

-- ============================================================================
-- 4. CREATE TENANT_SECRETS TABLE (Optional - for future use)
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_secrets (
    secret_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    secret_key VARCHAR(100) NOT NULL,
    secret_value_encrypted TEXT NOT NULL,
    secret_type VARCHAR(50) NOT NULL DEFAULT 'api_key',
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    last_rotated_at TIMESTAMPTZ,
    
    UNIQUE(tenant_id, secret_key),
    CONSTRAINT valid_secret_type CHECK (secret_type IN ('api_key', 'oauth_token', 'password', 'webhook_secret'))
);

CREATE INDEX idx_tenant_secrets_tenant ON tenant_secrets(tenant_id);
CREATE INDEX idx_tenant_secrets_expiry ON tenant_secrets(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================================================
-- 5. CREATE TENANT_ACTIVITY_LOG TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_activity_log (
    log_id BIGSERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    activity_type VARCHAR(50) NOT NULL,
    workflow_execution_id VARCHAR(100),
    workflow_name VARCHAR(200),
    
    metadata JSONB,
    error_message TEXT,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT valid_activity_type CHECK (activity_type IN (
        'message_received', 'message_sent', 'workflow_executed', 
        'error', 'quota_exceeded', 'unknown_instance', 'config_updated'
    ))
);

-- Partitioned index for time-series queries
CREATE INDEX idx_tenant_activity_tenant_date 
ON tenant_activity_log(tenant_id, created_at DESC);

CREATE INDEX idx_tenant_activity_type 
ON tenant_activity_log(activity_type, created_at DESC);

-- ============================================================================
-- 6. MODIFY LANGCHAIN MEMORY TABLE FOR TENANT ISOLATION
-- ============================================================================

-- Add tenant_id column to existing memory table if it exists
DO $$ 
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'langchain_pg_memory'
    ) THEN
        -- Add column if not exists
        IF NOT EXISTS (
            SELECT FROM information_schema.columns 
            WHERE table_name = 'langchain_pg_memory' 
            AND column_name = 'tenant_id'
        ) THEN
            ALTER TABLE langchain_pg_memory ADD COLUMN tenant_id UUID;
            
            -- Add index
            CREATE INDEX idx_memory_tenant_session 
            ON langchain_pg_memory(tenant_id, session_id);
            
            -- Add foreign key (optional - can be disabled if causing issues)
            ALTER TABLE langchain_pg_memory
            ADD CONSTRAINT fk_memory_tenant
            FOREIGN KEY (tenant_id) REFERENCES tenant_config(tenant_id) ON DELETE CASCADE;
        END IF;
    END IF;
END $$;

-- ============================================================================
-- 7. CREATE HELPER FUNCTIONS
-- ============================================================================

-- Function to get active tenant by instance name
CREATE OR REPLACE FUNCTION get_tenant_by_instance(p_instance_name VARCHAR)
RETURNS TABLE (
    tenant_id UUID,
    tenant_name VARCHAR,
    clinic_name VARCHAR,
    google_calendar_id VARCHAR,
    google_tasks_list_id VARCHAR,
    mcp_calendar_endpoint TEXT,
    telegram_internal_chat_id VARCHAR,
    system_prompt_patient TEXT,
    system_prompt_internal TEXT,
    system_prompt_confirmation TEXT,
    features JSONB,
    timezone VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tc.tenant_id,
        tc.tenant_name,
        tc.clinic_name,
        tc.google_calendar_id,
        tc.google_tasks_list_id,
        tc.mcp_calendar_endpoint,
        tc.telegram_internal_chat_id,
        tc.system_prompt_patient,
        tc.system_prompt_internal,
        tc.system_prompt_confirmation,
        tc.features,
        tc.timezone
    FROM tenant_config tc
    WHERE tc.evolution_instance_name = p_instance_name
    AND tc.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Function to increment message count
CREATE OR REPLACE FUNCTION increment_message_count(p_tenant_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE tenant_config
    SET current_message_count = current_message_count + 1
    WHERE tenant_id = p_tenant_id;
END;
$$ LANGUAGE plpgsql;

-- Function to reset monthly quotas (run via cron)
CREATE OR REPLACE FUNCTION reset_monthly_quotas()
RETURNS INTEGER AS $$
DECLARE
    reset_count INTEGER;
BEGIN
    UPDATE tenant_config
    SET 
        current_message_count = 0,
        last_quota_reset = CURRENT_DATE
    WHERE last_quota_reset < DATE_TRUNC('month', CURRENT_DATE)
    AND is_active = true;
    
    GET DIAGNOSTICS reset_count = ROW_COUNT;
    RETURN reset_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 8. CREATE VIEWS FOR CONVENIENCE
-- ============================================================================

-- View for active tenants with usage stats
CREATE OR REPLACE VIEW v_active_tenants AS
SELECT 
    t.tenant_id,
    t.tenant_name,
    t.evolution_instance_name,
    t.clinic_name,
    t.subscription_tier,
    t.current_message_count,
    t.monthly_message_limit,
    ROUND((t.current_message_count::NUMERIC / NULLIF(t.monthly_message_limit, 0)) * 100, 2) as quota_used_percent,
    t.created_at,
    COUNT(DISTINCT l.log_id) as total_activities,
    MAX(l.created_at) as last_activity_at
FROM tenant_config t
LEFT JOIN tenant_activity_log l ON l.tenant_id = t.tenant_id
WHERE t.is_active = true
GROUP BY t.tenant_id;

-- ============================================================================
-- 9. GRANT PERMISSIONS
-- ============================================================================

-- Grant permissions to n8n database user
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT SELECT, INSERT, UPDATE ON tenant_config TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_secrets TO n8n_user;
        GRANT SELECT, INSERT ON tenant_activity_log TO n8n_user;
        GRANT USAGE, SELECT ON SEQUENCE tenant_activity_log_log_id_seq TO n8n_user;
        GRANT SELECT ON v_active_tenants TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_tenant_by_instance(VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION increment_message_count(UUID) TO n8n_user;
    END IF;
END $$;

-- ============================================================================
-- 10. MIGRATION COMPLETE
-- ============================================================================

-- Log migration completion
DO $$
BEGIN
    RAISE NOTICE '✅ Multi-tenant migration completed successfully';
    RAISE NOTICE 'Tables created: tenant_config, tenant_secrets, tenant_activity_log';
    RAISE NOTICE 'Next steps: Run seed data script (002_seed_tenant_data.sql)';
END $$;

