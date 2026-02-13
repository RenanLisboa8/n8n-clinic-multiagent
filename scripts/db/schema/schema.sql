-- ============================================================================
-- CONSOLIDATED DATABASE SCHEMA
-- Version: 1.0.0
-- Date: 2026-02-01
-- Description: Single consolidated DDL for the multi-tenant clinic SaaS platform
--              Includes all tables, indexes, triggers, functions, and views
-- ============================================================================
--
-- This file replaces migrations 001, 003, 004, 015, 018, 020, 021, 022, 023, 024
-- Run this file once on a fresh database to set up the complete schema.
-- For existing databases, use migrations under db/migrations/
--
-- ============================================================================

-- ============================================================================
-- 0. EXTENSIONS
-- ============================================================================

-- Enable pgcrypto for gen_random_uuid() if not already enabled
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. TENANT_CONFIG TABLE (Core multi-tenant configuration)
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
    clinic_type VARCHAR(50) DEFAULT 'mixed',
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
    default_google_credential_id VARCHAR(255),
    
    -- Communication Configuration
    telegram_internal_chat_id VARCHAR(50),
    telegram_bot_token TEXT,
    whatsapp_number VARCHAR(20),
    messaging_provider VARCHAR(20) DEFAULT 'evolution',
    
    -- AI Configuration
    system_prompt_patient TEXT NOT NULL,
    system_prompt_internal TEXT NOT NULL,
    system_prompt_confirmation TEXT NOT NULL,
    llm_model_name VARCHAR(100) DEFAULT 'gemini-2.0-flash-lite',
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
    CONSTRAINT valid_status CHECK (subscription_status IN ('active', 'suspended', 'cancelled', 'trial')),
    CONSTRAINT valid_clinic_type CHECK (clinic_type IN ('medical', 'aesthetic', 'mixed', 'dental', 'other')),
    CONSTRAINT valid_messaging_provider CHECK (messaging_provider IN ('evolution', 'chatwoot'))
);

COMMENT ON TABLE tenant_config IS 'Core multi-tenant configuration table';
COMMENT ON COLUMN tenant_config.clinic_type IS 'Type of clinic: medical, aesthetic, mixed, dental, other';
COMMENT ON COLUMN tenant_config.default_google_credential_id IS 'Default n8n credential ID for Google Calendar';

-- Indexes for tenant_config
CREATE INDEX IF NOT EXISTS idx_tenant_evolution_instance 
ON tenant_config(evolution_instance_name) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_tenant_slug 
ON tenant_config(tenant_slug) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_tenant_active 
ON tenant_config(is_active);

CREATE INDEX IF NOT EXISTS idx_tenant_quota_reset 
ON tenant_config(last_quota_reset);

-- ============================================================================
-- 2. TENANT_SECRETS TABLE
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

CREATE INDEX IF NOT EXISTS idx_tenant_secrets_tenant ON tenant_secrets(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_secrets_expiry ON tenant_secrets(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================================================
-- 3. TENANT_ACTIVITY_LOG TABLE
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

CREATE INDEX IF NOT EXISTS idx_tenant_activity_tenant_date 
ON tenant_activity_log(tenant_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tenant_activity_type 
ON tenant_activity_log(activity_type, created_at DESC);

-- ============================================================================
-- 4. TENANT_FAQ TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS tenant_faq (
    faq_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    -- Question storage
    question_original TEXT NOT NULL,
    question_normalized TEXT NOT NULL,
    
    -- Answer storage
    answer TEXT NOT NULL,
    answer_type VARCHAR(50) DEFAULT 'text',
    
    -- Metadata for matching
    keywords TEXT[] DEFAULT '{}',
    intent VARCHAR(50),
    
    -- Performance tracking
    view_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Management
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    UNIQUE(tenant_id, question_normalized)
);

COMMENT ON TABLE tenant_faq IS 'Caches frequently asked questions to reduce AI API calls';
COMMENT ON COLUMN tenant_faq.question_normalized IS 'Lowercase normalized version for efficient matching';
COMMENT ON COLUMN tenant_faq.keywords IS 'Array of keywords for fuzzy matching via GIN index';

CREATE INDEX IF NOT EXISTS idx_faq_tenant ON tenant_faq(tenant_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_faq_normalized ON tenant_faq(question_normalized) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_faq_keywords ON tenant_faq USING GIN(keywords);
CREATE INDEX IF NOT EXISTS idx_faq_intent ON tenant_faq(intent) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_faq_popularity ON tenant_faq(tenant_id, view_count DESC) WHERE is_active = true;

-- ============================================================================
-- 5. SERVICES_CATALOG TABLE (Global Service Definitions)
-- ============================================================================

CREATE TABLE IF NOT EXISTS services_catalog (
    service_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Service Identity
    service_code VARCHAR(50) NOT NULL UNIQUE,
    service_name VARCHAR(200) NOT NULL,
    service_category VARCHAR(100) NOT NULL,
    
    -- Search & AI Matching
    service_keywords TEXT[] NOT NULL DEFAULT '{}',
    service_description TEXT,
    
    -- Default Values (can be overridden per professional)
    default_duration_minutes INTEGER NOT NULL DEFAULT 30,
    default_price_cents INTEGER NOT NULL DEFAULT 0,
    
    -- Requirements & Constraints
    requires_preparation BOOLEAN DEFAULT false,
    preparation_instructions TEXT,
    min_interval_days INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    display_order INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE services_catalog IS 'Global catalog of all services - professionals customize via junction table';
COMMENT ON COLUMN services_catalog.service_code IS 'Unique machine-readable code for programmatic access';
COMMENT ON COLUMN services_catalog.default_duration_minutes IS 'Default duration - professionals can override';
COMMENT ON COLUMN services_catalog.default_price_cents IS 'Default price in cents - professionals can override';

CREATE INDEX IF NOT EXISTS idx_services_catalog_category ON services_catalog(service_category) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_services_catalog_keywords ON services_catalog USING gin(service_keywords);
CREATE INDEX IF NOT EXISTS idx_services_catalog_code ON services_catalog(service_code);

-- ============================================================================
-- 6. PROFESSIONALS TABLE (Clinic Staff)
-- ============================================================================

CREATE TABLE IF NOT EXISTS professionals (
    professional_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Key to Tenant
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    -- Professional Identity
    professional_name VARCHAR(200) NOT NULL,
    professional_slug VARCHAR(100) NOT NULL,
    professional_title VARCHAR(50),
    specialty VARCHAR(200) NOT NULL,
    specialty_keywords TEXT[] DEFAULT '{}',
    
    -- Professional Details
    professional_bio TEXT,
    professional_crm VARCHAR(50),
    professional_photo_url TEXT,
    
    -- Google Calendar Configuration (INDIVIDUAL)
    google_calendar_id VARCHAR(255),
    google_calendar_label VARCHAR(100),
    google_calendar_color VARCHAR(20) DEFAULT '#4285f4',
    default_calendar_id UUID,
    
    -- Working Schedule (Default)
    working_hours_start TIME NOT NULL DEFAULT '08:00',
    working_hours_end TIME NOT NULL DEFAULT '18:00',
    working_days JSONB NOT NULL DEFAULT '["1","2","3","4","5"]'::jsonb,
    lunch_break_start TIME DEFAULT '12:00',
    lunch_break_end TIME DEFAULT '13:00',
    
    -- Scheduling Rules
    slot_interval_minutes INTEGER NOT NULL DEFAULT 30,
    buffer_between_appointments INTEGER DEFAULT 10,
    max_daily_appointments INTEGER,
    advance_booking_days INTEGER DEFAULT 60,
    min_notice_hours INTEGER DEFAULT 2,
    
    -- Contact
    professional_phone VARCHAR(20),
    professional_email VARCHAR(100),
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_accepting_new_patients BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(tenant_id, professional_slug),
    CONSTRAINT valid_working_hours CHECK (working_hours_start < working_hours_end),
    CONSTRAINT valid_slot_interval CHECK (slot_interval_minutes BETWEEN 5 AND 120)
);

COMMENT ON TABLE professionals IS 'Clinic professionals - each has their own Google Calendar';
COMMENT ON COLUMN professionals.google_calendar_id IS 'Individual calendar ID - CRITICAL for correct booking';
COMMENT ON COLUMN professionals.slot_interval_minutes IS 'Base slot granularity for availability calculation';
COMMENT ON COLUMN professionals.default_calendar_id IS 'Reference to the primary calendar for this professional';

CREATE INDEX IF NOT EXISTS idx_professionals_tenant ON professionals(tenant_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_professionals_specialty ON professionals(tenant_id, specialty) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_professionals_keywords ON professionals USING gin(specialty_keywords);
CREATE INDEX IF NOT EXISTS idx_professionals_slug ON professionals(tenant_id, professional_slug);

-- ============================================================================
-- 7. PROFESSIONAL_SERVICES TABLE (Custom Pricing & Duration)
-- ============================================================================

CREATE TABLE IF NOT EXISTS professional_services (
    ps_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    professional_id UUID NOT NULL REFERENCES professionals(professional_id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES services_catalog(service_id) ON DELETE CASCADE,
    
    -- Custom Duration & Price (REQUIRED - override catalog defaults)
    custom_duration_minutes INTEGER NOT NULL,
    custom_price_cents INTEGER NOT NULL,
    
    -- Pricing Display
    price_display VARCHAR(50),
    price_notes TEXT,
    
    -- Availability Constraints (per professional/service)
    available_days JSONB,
    available_hours_start TIME,
    available_hours_end TIME,
    max_per_day INTEGER,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(professional_id, service_id),
    CONSTRAINT valid_duration CHECK (custom_duration_minutes BETWEEN 5 AND 480),
    CONSTRAINT valid_price CHECK (custom_price_cents >= 0)
);

COMMENT ON TABLE professional_services IS 'Junction table with CUSTOM duration and price per professional';
COMMENT ON COLUMN professional_services.custom_duration_minutes IS 'CRITICAL: This duration is used for slot calculation and calendar booking';
COMMENT ON COLUMN professional_services.custom_price_cents IS 'Price in cents - must be presented to patient before booking';

CREATE INDEX IF NOT EXISTS idx_ps_professional ON professional_services(professional_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ps_service ON professional_services(service_id) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_ps_professional_service ON professional_services(professional_id, service_id);

-- ============================================================================
-- 8. RESPONSE_TEMPLATES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS response_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    template_key VARCHAR(100) NOT NULL,
    template_text TEXT NOT NULL,
    variables JSONB DEFAULT '{}',
    category VARCHAR(50) DEFAULT 'general',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(tenant_id, template_key)
);

COMMENT ON TABLE response_templates IS 'Pre-built response templates to reduce AI calls';

CREATE INDEX IF NOT EXISTS idx_response_templates_tenant_key 
ON response_templates(tenant_id, template_key) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_response_templates_category
ON response_templates(tenant_id, category) WHERE is_active = true;

-- ============================================================================
-- 9. STATE_DEFINITIONS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS state_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    valid_inputs JSONB DEFAULT '{}',
    next_states JSONB DEFAULT '{}',
    template_key VARCHAR(100),
    requires_ai BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE state_definitions IS 'Defines valid states and transitions for the conversation state machine';

-- ============================================================================
-- 10. CONVERSATION_STATE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS conversation_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    remote_jid VARCHAR(50) NOT NULL,
    current_state VARCHAR(50) DEFAULT 'initial',
    state_data JSONB DEFAULT '{}',
    selected_service_id UUID REFERENCES services_catalog(service_id) ON DELETE SET NULL,
    selected_professional_id UUID REFERENCES professionals(professional_id) ON DELETE SET NULL,
    selected_slot JSONB,
    last_interaction TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours'),
    UNIQUE(tenant_id, remote_jid)
);

COMMENT ON TABLE conversation_state IS 'Tracks conversation state for each user, replacing AI memory';

CREATE INDEX IF NOT EXISTS idx_conversation_state_lookup 
ON conversation_state(tenant_id, remote_jid);

CREATE INDEX IF NOT EXISTS idx_conversation_state_remote_jid
ON conversation_state(remote_jid);

CREATE INDEX IF NOT EXISTS idx_conversation_state_expires
ON conversation_state(expires_at) WHERE current_state != 'completed';

-- ============================================================================
-- 11. CALENDARS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS calendars (
    calendar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    professional_id UUID REFERENCES professionals(professional_id) ON DELETE SET NULL,
    
    -- Google Calendar Configuration
    google_calendar_id VARCHAR(255) NOT NULL,
    google_calendar_label VARCHAR(100),
    
    -- Credential Reference
    credential_ref VARCHAR(255),
    credential_type VARCHAR(50) DEFAULT 'n8n_credential',
    
    -- Calendar Properties
    calendar_color VARCHAR(20) DEFAULT '#4285f4',
    timezone VARCHAR(50),
    
    -- Calendar Purpose
    is_primary BOOLEAN DEFAULT false,
    calendar_type VARCHAR(50) DEFAULT 'appointments',
    
    -- Sync Settings
    sync_enabled BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMPTZ,
    sync_error TEXT,
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Constraints
    -- OAuth Credentials (from migration 025)
    google_client_id VARCHAR(255),
    google_client_secret TEXT,
    google_refresh_token TEXT,
    google_access_token TEXT,
    google_token_expires_at TIMESTAMPTZ,
    google_oauth_scope TEXT DEFAULT 'https://www.googleapis.com/auth/calendar',
    
    -- Constraints
    CONSTRAINT unique_google_calendar_per_tenant UNIQUE(tenant_id, google_calendar_id),
    CONSTRAINT valid_credential_type CHECK (credential_type IN ('n8n_credential', 'env_key', 'tenant_default', 'oauth_database')),
    CONSTRAINT valid_calendar_type CHECK (calendar_type IN ('appointments', 'availability', 'shared', 'other'))
);

COMMENT ON TABLE calendars IS 'Centralizes Google Calendar configuration per professional/tenant';
COMMENT ON COLUMN calendars.google_calendar_id IS 'Google Calendar ID - unique per tenant';
COMMENT ON COLUMN calendars.credential_ref IS 'Reference to n8n credential or env variable key';
COMMENT ON COLUMN calendars.is_primary IS 'True if this is the primary calendar for the associated professional';
COMMENT ON COLUMN calendars.google_client_id IS 'Google OAuth Client ID from Google Cloud Console';
COMMENT ON COLUMN calendars.google_client_secret IS 'Google OAuth Client Secret (encrypted at rest recommended)';
COMMENT ON COLUMN calendars.google_refresh_token IS 'Long-lived refresh token for obtaining access tokens';
COMMENT ON COLUMN calendars.google_access_token IS 'Short-lived access token (cached, regenerated on expiry)';
COMMENT ON COLUMN calendars.google_token_expires_at IS 'Timestamp when the current access token expires';
COMMENT ON COLUMN calendars.google_oauth_scope IS 'OAuth scope granted during authorization';

CREATE INDEX IF NOT EXISTS idx_calendars_tenant 
ON calendars(tenant_id) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_calendars_professional 
ON calendars(professional_id) 
WHERE is_active = true AND professional_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_calendars_primary 
ON calendars(tenant_id, professional_id, is_primary) 
WHERE is_active = true AND is_primary = true;

CREATE INDEX IF NOT EXISTS idx_calendars_sync 
ON calendars(last_sync_at) 
WHERE sync_enabled = true;

CREATE INDEX IF NOT EXISTS idx_calendars_token_expiry 
ON calendars(google_token_expires_at) 
WHERE google_refresh_token IS NOT NULL AND sync_enabled = true;

-- Add FK from professionals to calendars (deferred to avoid circular reference)
ALTER TABLE professionals 
DROP CONSTRAINT IF EXISTS fk_professionals_default_calendar;

ALTER TABLE professionals 
ADD CONSTRAINT fk_professionals_default_calendar 
FOREIGN KEY (default_calendar_id) REFERENCES calendars(calendar_id) ON DELETE SET NULL;

-- ============================================================================
-- 12. APPOINTMENTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS appointments (
    appointment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(professional_id) ON DELETE RESTRICT,
    service_id UUID NOT NULL REFERENCES services_catalog(service_id) ON DELETE RESTRICT,
    calendar_id UUID REFERENCES calendars(calendar_id) ON DELETE SET NULL,
    
    -- Google Calendar Reference
    google_event_id VARCHAR(255),
    google_event_link TEXT,
    
    -- Scheduling Information
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL,
    
    -- Patient Information
    patient_contact VARCHAR(50) NOT NULL,
    patient_name VARCHAR(200),
    patient_email VARCHAR(100),
    patient_notes TEXT,
    
    -- Appointment Details
    service_name VARCHAR(200) NOT NULL,
    professional_name VARCHAR(200) NOT NULL,
    price_cents INTEGER,
    price_display VARCHAR(50),
    
    -- Status Management
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
    status_reason TEXT,
    status_changed_at TIMESTAMPTZ,
    status_changed_by VARCHAR(100),
    
    -- Confirmation & Reminders
    confirmation_sent_at TIMESTAMPTZ,
    reminder_24h_sent_at TIMESTAMPTZ,
    reminder_1h_sent_at TIMESTAMPTZ,
    patient_confirmed_at TIMESTAMPTZ,
    
    -- Reschedule Tracking
    rescheduled_from_id UUID REFERENCES appointments(appointment_id),
    reschedule_count INTEGER DEFAULT 0,
    
    -- Soft Delete
    deleted_at TIMESTAMPTZ,
    deleted_by VARCHAR(100),
    deleted_reason TEXT,
    
    -- Sync Status
    sync_status VARCHAR(50) DEFAULT 'pending',
    sync_error TEXT,
    last_synced_at TIMESTAMPTZ,
    
    -- Source Tracking
    created_via VARCHAR(50) DEFAULT 'whatsapp',
    conversation_id UUID,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT valid_appointment_times CHECK (start_at < end_at),
    CONSTRAINT valid_status CHECK (status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show', 'rescheduled')),
    CONSTRAINT valid_sync_status CHECK (sync_status IN ('pending', 'synced', 'error', 'deleted')),
    CONSTRAINT valid_created_via CHECK (created_via IN ('whatsapp', 'telegram', 'web', 'api', 'manual', 'migration')),
    CONSTRAINT valid_duration CHECK (duration_minutes BETWEEN 5 AND 480)
);

COMMENT ON TABLE appointments IS 'Appointment records with audit trail, soft delete, and Google Calendar sync';
COMMENT ON COLUMN appointments.deleted_at IS 'Soft delete - NULL means active, timestamp means deleted';
COMMENT ON COLUMN appointments.google_event_id IS 'Google Calendar event ID for sync operations';

CREATE INDEX IF NOT EXISTS idx_appointments_tenant_date 
ON appointments(tenant_id, start_at) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_professional 
ON appointments(professional_id, start_at) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_patient 
ON appointments(tenant_id, patient_contact, start_at) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_status 
ON appointments(tenant_id, status, start_at) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_sync 
ON appointments(sync_status, created_at) 
WHERE deleted_at IS NULL AND sync_status != 'synced';

CREATE INDEX IF NOT EXISTS idx_appointments_google_event 
ON appointments(google_event_id) 
WHERE google_event_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_appointments_reminders 
ON appointments(start_at, reminder_24h_sent_at, reminder_1h_sent_at) 
WHERE deleted_at IS NULL AND status IN ('scheduled', 'confirmed');

CREATE INDEX IF NOT EXISTS idx_appointments_deleted 
ON appointments(tenant_id, deleted_at) 
WHERE deleted_at IS NOT NULL;

-- ============================================================================
-- 13. TRIGGERS (Shared update_timestamp function)
-- ============================================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tenant config trigger
CREATE OR REPLACE FUNCTION update_tenant_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tenant_config_updated_at ON tenant_config;
CREATE TRIGGER tenant_config_updated_at
    BEFORE UPDATE ON tenant_config
    FOR EACH ROW
    EXECUTE FUNCTION update_tenant_config_timestamp();

-- FAQ trigger
CREATE OR REPLACE FUNCTION update_faq_updated_at() 
RETURNS TRIGGER AS $$ 
BEGIN 
    NEW.updated_at = NOW(); 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS faq_updated_at ON tenant_faq;
CREATE TRIGGER faq_updated_at 
    BEFORE UPDATE ON tenant_faq 
    FOR EACH ROW 
    EXECUTE FUNCTION update_faq_updated_at();

-- Services catalog trigger
DROP TRIGGER IF EXISTS services_catalog_updated_at ON services_catalog;
CREATE TRIGGER services_catalog_updated_at
    BEFORE UPDATE ON services_catalog
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Professionals trigger
DROP TRIGGER IF EXISTS professionals_updated_at ON professionals;
CREATE TRIGGER professionals_updated_at
    BEFORE UPDATE ON professionals
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Professional services trigger
DROP TRIGGER IF EXISTS professional_services_updated_at ON professional_services;
CREATE TRIGGER professional_services_updated_at
    BEFORE UPDATE ON professional_services
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Response templates trigger
DROP TRIGGER IF EXISTS response_templates_updated_at ON response_templates;
CREATE TRIGGER response_templates_updated_at
    BEFORE UPDATE ON response_templates
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Calendars trigger
DROP TRIGGER IF EXISTS calendars_updated_at ON calendars;
CREATE TRIGGER calendars_updated_at
    BEFORE UPDATE ON calendars
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Appointments trigger
DROP TRIGGER IF EXISTS appointments_updated_at ON appointments;
CREATE TRIGGER appointments_updated_at
    BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- 14. TENANT FUNCTIONS
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

-- Function to reset monthly quotas
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
-- 15. FAQ FUNCTIONS
-- ============================================================================

-- Clean up unused FAQs (not accessed in 90 days and low view count)
CREATE OR REPLACE FUNCTION cleanup_stale_faqs()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    WITH deleted AS (
        DELETE FROM tenant_faq
        WHERE 
            view_count < 3
            AND last_used_at < NOW() - INTERVAL '90 days'
        RETURNING *
    )
    SELECT COUNT(*) INTO deleted_count FROM deleted;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 16. SERVICE RESOLVER FUNCTIONS
-- ============================================================================

-- Function: Find professionals who offer a specific service
CREATE OR REPLACE FUNCTION find_professionals_for_service(
    p_tenant_id UUID,
    p_search_text TEXT
)
RETURNS TABLE (
    professional_id UUID,
    professional_name VARCHAR,
    specialty VARCHAR,
    google_calendar_id VARCHAR,
    service_id UUID,
    service_name VARCHAR,
    service_code VARCHAR,
    duration_minutes INTEGER,
    price_cents INTEGER,
    price_display VARCHAR,
    match_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.professional_id,
        p.professional_name,
        p.specialty,
        p.google_calendar_id,
        sc.service_id,
        sc.service_name,
        sc.service_code,
        ps.custom_duration_minutes as duration_minutes,
        ps.custom_price_cents as price_cents,
        ps.price_display,
        CASE
            WHEN LOWER(sc.service_name) = LOWER(p_search_text) THEN 1.0
            WHEN LOWER(sc.service_code) = UPPER(p_search_text) THEN 0.95
            WHEN LOWER(sc.service_name) ILIKE '%' || LOWER(p_search_text) || '%' THEN 0.8
            WHEN EXISTS (
                SELECT 1 FROM unnest(sc.service_keywords) kw 
                WHERE LOWER(p_search_text) ILIKE '%' || LOWER(kw) || '%'
            ) THEN 0.7
            ELSE 0.5
        END::NUMERIC as match_score
    FROM professional_services ps
    JOIN professionals p ON ps.professional_id = p.professional_id
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    WHERE p.tenant_id = p_tenant_id
    AND p.is_active = true
    AND ps.is_active = true
    AND sc.is_active = true
    AND (
        LOWER(sc.service_name) ILIKE '%' || LOWER(p_search_text) || '%'
        OR LOWER(sc.service_code) ILIKE '%' || LOWER(p_search_text) || '%'
        OR EXISTS (
            SELECT 1 FROM unnest(sc.service_keywords) kw 
            WHERE LOWER(p_search_text) ILIKE '%' || LOWER(kw) || '%'
        )
    )
    ORDER BY match_score DESC, p.display_order;
END;
$$ LANGUAGE plpgsql;

-- Function: Get service details for a specific professional
CREATE OR REPLACE FUNCTION get_professional_service_details(
    p_professional_id UUID,
    p_service_id UUID
)
RETURNS TABLE (
    professional_id UUID,
    professional_name VARCHAR,
    google_calendar_id VARCHAR,
    slot_interval_minutes INTEGER,
    buffer_minutes INTEGER,
    service_id UUID,
    service_name VARCHAR,
    service_code VARCHAR,
    duration_minutes INTEGER,
    price_cents INTEGER,
    price_display VARCHAR,
    requires_preparation BOOLEAN,
    preparation_instructions TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.professional_id,
        p.professional_name,
        p.google_calendar_id,
        p.slot_interval_minutes,
        p.buffer_between_appointments,
        sc.service_id,
        sc.service_name,
        sc.service_code,
        ps.custom_duration_minutes,
        ps.custom_price_cents,
        ps.price_display,
        sc.requires_preparation,
        sc.preparation_instructions
    FROM professional_services ps
    JOIN professionals p ON ps.professional_id = p.professional_id
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND p.is_active = true
    AND ps.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate end time based on service duration
CREATE OR REPLACE FUNCTION calculate_appointment_end_time(
    p_start_time TIMESTAMPTZ,
    p_professional_id UUID,
    p_service_id UUID
)
RETURNS TIMESTAMPTZ AS $$
DECLARE
    v_duration_minutes INTEGER;
BEGIN
    SELECT ps.custom_duration_minutes INTO v_duration_minutes
    FROM professional_services ps
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND ps.is_active = true;
    
    IF v_duration_minutes IS NULL THEN
        RAISE EXCEPTION 'Service not found for this professional';
    END IF;
    
    RETURN p_start_time + (v_duration_minutes || ' minutes')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- Function: Validate slot availability
CREATE OR REPLACE FUNCTION validate_slot_for_service(
    p_slot_start TIMESTAMPTZ,
    p_slot_end TIMESTAMPTZ,
    p_professional_id UUID,
    p_service_id UUID
)
RETURNS TABLE (
    is_valid BOOLEAN,
    slot_duration_minutes INTEGER,
    required_duration_minutes INTEGER,
    calculated_end_time TIMESTAMPTZ,
    error_message TEXT
) AS $$
DECLARE
    v_required_duration INTEGER;
    v_slot_duration INTEGER;
    v_calculated_end TIMESTAMPTZ;
BEGIN
    SELECT ps.custom_duration_minutes INTO v_required_duration
    FROM professional_services ps
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND ps.is_active = true;
    
    IF v_required_duration IS NULL THEN
        RETURN QUERY SELECT 
            false::BOOLEAN,
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::TIMESTAMPTZ,
            'Service not found for this professional'::TEXT;
        RETURN;
    END IF;
    
    v_slot_duration := EXTRACT(EPOCH FROM (p_slot_end - p_slot_start)) / 60;
    v_calculated_end := p_slot_start + (v_required_duration || ' minutes')::INTERVAL;
    
    IF v_slot_duration >= v_required_duration THEN
        RETURN QUERY SELECT 
            true::BOOLEAN,
            v_slot_duration,
            v_required_duration,
            v_calculated_end,
            NULL::TEXT;
    ELSE
        RETURN QUERY SELECT 
            false::BOOLEAN,
            v_slot_duration,
            v_required_duration,
            v_calculated_end,
            format('Slot too short: available %s min, required %s min', v_slot_duration, v_required_duration)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Get all services for a professional
CREATE OR REPLACE FUNCTION get_professional_services_list(p_professional_id UUID)
RETURNS TABLE (
    service_id UUID,
    service_code VARCHAR,
    service_name VARCHAR,
    service_category VARCHAR,
    duration_minutes INTEGER,
    price_cents INTEGER,
    price_display VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.service_id,
        sc.service_code,
        sc.service_name,
        sc.service_category,
        ps.custom_duration_minutes,
        ps.custom_price_cents,
        ps.price_display
    FROM professional_services ps
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    WHERE ps.professional_id = p_professional_id
    AND ps.is_active = true
    AND sc.is_active = true
    ORDER BY sc.service_category, sc.display_order, sc.service_name;
END;
$$ LANGUAGE plpgsql;

-- Function: Get services catalog for AI prompt (unique services, numbered)
CREATE OR REPLACE FUNCTION get_services_catalog_for_prompt(p_tenant_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_catalog TEXT := '';
    v_current_category TEXT := '';
    v_category_emoji TEXT;
    v_service_counter INTEGER := 0;
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT DISTINCT
            sc.service_category,
            sc.service_name,
            sc.service_id,
            sc.display_order
        FROM services_catalog sc
        WHERE sc.service_id IN (
            SELECT DISTINCT ps.service_id
            FROM professionals p
            JOIN professional_services ps ON p.professional_id = ps.professional_id
            WHERE p.tenant_id = p_tenant_id
            AND p.is_active = true
            AND ps.is_active = true
        )
        AND sc.is_active = true
        ORDER BY sc.service_category, sc.display_order, sc.service_name
    LOOP
        IF v_current_category IS DISTINCT FROM rec.service_category THEN
            v_category_emoji := CASE rec.service_category
                WHEN 'Odontologia' THEN '🦷'
                WHEN 'Estética' THEN '💆'
                WHEN 'Cardiologia' THEN '❤️'
                WHEN 'Clínico Geral' THEN '👨‍⚕️'
                ELSE '📋'
            END;
            
            IF v_catalog != '' THEN
                v_catalog := v_catalog || E'\n';
            END IF;
            
            v_catalog := v_catalog || format('%s *%s*',
                v_category_emoji,
                UPPER(rec.service_category)
            );
            v_current_category := rec.service_category;
        END IF;
        
        v_service_counter := v_service_counter + 1;
        v_catalog := v_catalog || E'\n' || format('%s. %s',
            v_service_counter::TEXT,
            rec.service_name
        );
    END LOOP;
    
    RETURN COALESCE(v_catalog, 'Nenhum serviço cadastrado.');
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_services_catalog_for_prompt(UUID) IS 'Returns formatted unique services catalog grouped by category';

-- Function: Get service by number in catalog
CREATE OR REPLACE FUNCTION get_service_by_number(
    p_tenant_id UUID,
    p_service_number INTEGER
)
RETURNS TABLE (
    service_id UUID,
    service_name VARCHAR,
    service_code VARCHAR,
    service_category VARCHAR,
    service_number INTEGER
) AS $$
DECLARE
    v_service_counter INTEGER := 0;
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT DISTINCT
            sc.service_id,
            sc.service_name,
            sc.service_code,
            sc.service_category,
            sc.display_order
        FROM services_catalog sc
        WHERE sc.service_id IN (
            SELECT DISTINCT ps.service_id
            FROM professionals p
            JOIN professional_services ps ON p.professional_id = ps.professional_id
            WHERE p.tenant_id = p_tenant_id
            AND p.is_active = true
            AND ps.is_active = true
        )
        AND sc.is_active = true
        ORDER BY sc.service_category, sc.display_order, sc.service_name
    LOOP
        v_service_counter := v_service_counter + 1;
        
        IF v_service_counter = p_service_number THEN
            RETURN QUERY SELECT 
                rec.service_id,
                rec.service_name,
                rec.service_code,
                rec.service_category,
                v_service_counter;
            RETURN;
        END IF;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_service_by_number(UUID, INTEGER) IS 'Returns service details by its number in the catalog';

-- ============================================================================
-- 17. RESPONSE TEMPLATE FUNCTIONS
-- ============================================================================

-- Function to get template with variable replacement
CREATE OR REPLACE FUNCTION get_template_response(
    p_tenant_id UUID,
    p_template_key VARCHAR(100),
    p_variables JSONB DEFAULT '{}'
)
RETURNS TEXT AS $$
DECLARE
    v_template TEXT;
    v_key TEXT;
    v_value TEXT;
BEGIN
    SELECT template_text INTO v_template
    FROM response_templates
    WHERE tenant_id = p_tenant_id 
    AND template_key = p_template_key
    AND is_active = true;
    
    IF v_template IS NULL THEN
        RETURN NULL;
    END IF;
    
    FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_variables)
    LOOP
        v_template := REPLACE(v_template, '{{' || v_key || '}}', COALESCE(v_value, ''));
    END LOOP;
    
    RETURN v_template;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_template_response IS 'Retrieves a template and replaces variables with provided values';

-- ============================================================================
-- 18. CONVERSATION STATE FUNCTIONS
-- ============================================================================

-- Function to get or create conversation state
CREATE OR REPLACE FUNCTION get_or_create_conversation_state(
    p_tenant_id UUID,
    p_remote_jid VARCHAR(50)
)
RETURNS conversation_state AS $$
DECLARE
    v_state conversation_state;
BEGIN
    SELECT * INTO v_state
    FROM conversation_state
    WHERE tenant_id = p_tenant_id 
    AND remote_jid = p_remote_jid
    AND expires_at > NOW();
    
    IF v_state.id IS NULL THEN
        INSERT INTO conversation_state (tenant_id, remote_jid, current_state, state_data)
        VALUES (p_tenant_id, p_remote_jid, 'initial', '{}')
        ON CONFLICT (tenant_id, remote_jid) 
        DO UPDATE SET 
            current_state = 'initial',
            state_data = '{}',
            selected_service_id = NULL,
            selected_professional_id = NULL,
            selected_slot = NULL,
            last_interaction = NOW(),
            expires_at = NOW() + INTERVAL '24 hours'
        RETURNING * INTO v_state;
    END IF;
    
    RETURN v_state;
END;
$$ LANGUAGE plpgsql;

-- Function to transition state
CREATE OR REPLACE FUNCTION transition_conversation_state(
    p_tenant_id UUID,
    p_remote_jid VARCHAR(50),
    p_input TEXT,
    p_additional_data JSONB DEFAULT '{}'
)
RETURNS TABLE(
    new_state VARCHAR(50),
    template_key VARCHAR(100),
    requires_ai BOOLEAN,
    state_data JSONB
) AS $$
DECLARE
    v_current_state conversation_state;
    v_state_def state_definitions;
    v_normalized_input TEXT;
    v_next_state TEXT;
    v_action TEXT;
BEGIN
    SELECT * INTO v_current_state
    FROM get_or_create_conversation_state(p_tenant_id, p_remote_jid);
    
    SELECT * INTO v_state_def
    FROM state_definitions
    WHERE state_name = v_current_state.current_state;
    
    v_normalized_input := LOWER(TRIM(p_input));
    
    IF v_normalized_input ~ '^\d+$' THEN
        IF v_state_def.valid_inputs ? 'number' THEN
            v_action := v_state_def.valid_inputs->>'number';
        ELSIF v_state_def.valid_inputs ? v_normalized_input THEN
            v_action := v_state_def.valid_inputs->>v_normalized_input;
        END IF;
    ELSE
        IF v_state_def.valid_inputs ? v_normalized_input THEN
            v_action := v_state_def.valid_inputs->>v_normalized_input;
        END IF;
    END IF;
    
    IF v_action IS NULL THEN
        IF LENGTH(p_input) > 20 OR p_input LIKE '%?%' THEN
            v_next_state := 'complex_query';
        ELSE
            RETURN QUERY SELECT 
                v_current_state.current_state,
                'invalid_option'::VARCHAR(100),
                false,
                v_current_state.state_data;
            RETURN;
        END IF;
    ELSE
        v_next_state := v_state_def.next_states->>v_action;
    END IF;
    
    UPDATE conversation_state
    SET 
        current_state = COALESCE(v_next_state, v_current_state.current_state),
        state_data = v_current_state.state_data || p_additional_data,
        last_interaction = NOW(),
        expires_at = NOW() + INTERVAL '24 hours'
    WHERE tenant_id = p_tenant_id AND remote_jid = p_remote_jid;
    
    SELECT * INTO v_state_def
    FROM state_definitions
    WHERE state_name = COALESCE(v_next_state, v_current_state.current_state);
    
    RETURN QUERY SELECT 
        COALESCE(v_next_state, v_current_state.current_state)::VARCHAR(50),
        v_state_def.template_key,
        v_state_def.requires_ai,
        v_current_state.state_data || p_additional_data;
END;
$$ LANGUAGE plpgsql;

-- Function to update state data
CREATE OR REPLACE FUNCTION update_conversation_state_data(
    p_tenant_id UUID,
    p_remote_jid VARCHAR(50),
    p_service_id UUID DEFAULT NULL,
    p_professional_id UUID DEFAULT NULL,
    p_slot JSONB DEFAULT NULL,
    p_additional_data JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
    UPDATE conversation_state
    SET 
        selected_service_id = COALESCE(p_service_id, selected_service_id),
        selected_professional_id = COALESCE(p_professional_id, selected_professional_id),
        selected_slot = COALESCE(p_slot, selected_slot),
        state_data = state_data || p_additional_data,
        last_interaction = NOW()
    WHERE tenant_id = p_tenant_id AND remote_jid = p_remote_jid;
END;
$$ LANGUAGE plpgsql;

-- Function to reset conversation state
CREATE OR REPLACE FUNCTION reset_conversation_state(
    p_tenant_id UUID,
    p_remote_jid VARCHAR(50)
)
RETURNS VOID AS $$
BEGIN
    UPDATE conversation_state
    SET 
        current_state = 'initial',
        state_data = '{}',
        selected_service_id = NULL,
        selected_professional_id = NULL,
        selected_slot = NULL,
        last_interaction = NOW(),
        expires_at = NOW() + INTERVAL '24 hours'
    WHERE tenant_id = p_tenant_id AND remote_jid = p_remote_jid;
END;
$$ LANGUAGE plpgsql;

-- Cleanup function for expired states
CREATE OR REPLACE FUNCTION cleanup_expired_conversation_states()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM conversation_state
    WHERE expires_at < NOW()
    RETURNING COUNT(*) INTO v_count;
    
    RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 19. CALENDAR FUNCTIONS
-- ============================================================================

-- Function: Check if calendar token needs refresh
CREATE OR REPLACE FUNCTION calendar_token_needs_refresh(p_calendar_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_expires_at TIMESTAMPTZ;
    v_buffer_minutes INTEGER := 5; -- Refresh 5 minutes before expiry
BEGIN
    SELECT google_token_expires_at 
    INTO v_expires_at
    FROM calendars 
    WHERE calendar_id = p_calendar_id;
    
    -- If no expiry set or expired, needs refresh
    IF v_expires_at IS NULL OR v_expires_at < (NOW() + (v_buffer_minutes || ' minutes')::INTERVAL) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$;

COMMENT ON FUNCTION calendar_token_needs_refresh IS 'Returns TRUE if calendar access token needs refresh (expired or near expiry)';

-- Function: Get calendar configuration for a professional
CREATE OR REPLACE FUNCTION get_calendar_for_professional(
    p_tenant_id UUID,
    p_professional_id UUID
)
RETURNS TABLE (
    calendar_id UUID,
    google_calendar_id VARCHAR,
    credential_ref VARCHAR,
    credential_type VARCHAR,
    timezone VARCHAR,
    is_primary BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.calendar_id,
        c.google_calendar_id,
        COALESCE(c.credential_ref, tc.default_google_credential_id) as credential_ref,
        c.credential_type,
        COALESCE(c.timezone, tc.timezone) as timezone,
        c.is_primary
    FROM calendars c
    JOIN tenant_config tc ON c.tenant_id = tc.tenant_id
    WHERE c.tenant_id = p_tenant_id
    AND c.professional_id = p_professional_id
    AND c.is_active = true
    ORDER BY c.is_primary DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function: Get all calendars for a tenant
CREATE OR REPLACE FUNCTION get_tenant_calendars(p_tenant_id UUID)
RETURNS TABLE (
    calendar_id UUID,
    professional_id UUID,
    professional_name VARCHAR,
    google_calendar_id VARCHAR,
    credential_ref VARCHAR,
    timezone VARCHAR,
    last_sync_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.calendar_id,
        c.professional_id,
        p.professional_name,
        c.google_calendar_id,
        COALESCE(c.credential_ref, tc.default_google_credential_id) as credential_ref,
        COALESCE(c.timezone, tc.timezone) as timezone,
        c.last_sync_at
    FROM calendars c
    JOIN tenant_config tc ON c.tenant_id = tc.tenant_id
    LEFT JOIN professionals p ON c.professional_id = p.professional_id
    WHERE c.tenant_id = p_tenant_id
    AND c.is_active = true
    AND c.sync_enabled = true
    ORDER BY p.display_order, c.created_at;
END;
$$ LANGUAGE plpgsql;

-- Function: Register a new calendar for a professional
CREATE OR REPLACE FUNCTION register_professional_calendar(
    p_tenant_id UUID,
    p_professional_id UUID,
    p_google_calendar_id VARCHAR,
    p_credential_ref VARCHAR DEFAULT NULL,
    p_is_primary BOOLEAN DEFAULT true
)
RETURNS UUID AS $$
DECLARE
    v_calendar_id UUID;
    v_timezone VARCHAR;
BEGIN
    SELECT timezone INTO v_timezone
    FROM tenant_config
    WHERE tenant_id = p_tenant_id;
    
    IF p_is_primary THEN
        UPDATE calendars
        SET is_primary = false
        WHERE tenant_id = p_tenant_id
        AND professional_id = p_professional_id
        AND is_primary = true;
    END IF;
    
    INSERT INTO calendars (
        tenant_id,
        professional_id,
        google_calendar_id,
        credential_ref,
        timezone,
        is_primary
    ) VALUES (
        p_tenant_id,
        p_professional_id,
        p_google_calendar_id,
        p_credential_ref,
        v_timezone,
        p_is_primary
    )
    ON CONFLICT (tenant_id, google_calendar_id) DO UPDATE SET
        professional_id = EXCLUDED.professional_id,
        credential_ref = COALESCE(EXCLUDED.credential_ref, calendars.credential_ref),
        is_primary = EXCLUDED.is_primary,
        is_active = true,
        updated_at = NOW()
    RETURNING calendar_id INTO v_calendar_id;
    
    IF p_is_primary THEN
        UPDATE professionals
        SET default_calendar_id = v_calendar_id
        WHERE professional_id = p_professional_id;
    END IF;
    
    RETURN v_calendar_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Migrate existing google_calendar_id from professionals to calendars
CREATE OR REPLACE FUNCTION migrate_professional_calendars()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
    rec RECORD;
BEGIN
    FOR rec IN 
        SELECT 
            p.professional_id,
            p.tenant_id,
            p.google_calendar_id,
            p.google_calendar_label
        FROM professionals p
        WHERE p.google_calendar_id IS NOT NULL
        AND NOT EXISTS (
            SELECT 1 FROM calendars c 
            WHERE c.tenant_id = p.tenant_id 
            AND c.google_calendar_id = p.google_calendar_id
        )
    LOOP
        INSERT INTO calendars (
            tenant_id,
            professional_id,
            google_calendar_id,
            google_calendar_label,
            is_primary,
            calendar_type
        ) VALUES (
            rec.tenant_id,
            rec.professional_id,
            rec.google_calendar_id,
            rec.google_calendar_label,
            true,
            'appointments'
        );
        
        UPDATE professionals
        SET default_calendar_id = (
            SELECT calendar_id FROM calendars 
            WHERE tenant_id = rec.tenant_id 
            AND google_calendar_id = rec.google_calendar_id
        )
        WHERE professional_id = rec.professional_id;
        
        v_count := v_count + 1;
    END LOOP;
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 20. APPOINTMENT FUNCTIONS
-- ============================================================================

-- Function: Create a new appointment
CREATE OR REPLACE FUNCTION create_appointment(
    p_tenant_id UUID,
    p_professional_id UUID,
    p_service_id UUID,
    p_start_at TIMESTAMPTZ,
    p_patient_contact VARCHAR(50),
    p_patient_name VARCHAR(200) DEFAULT NULL,
    p_created_via VARCHAR(50) DEFAULT 'whatsapp'
)
RETURNS TABLE (
    appointment_id UUID,
    end_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    service_name VARCHAR,
    professional_name VARCHAR,
    price_display VARCHAR,
    google_calendar_id VARCHAR,
    calendar_id UUID
) AS $$
DECLARE
    v_appointment_id UUID;
    v_end_at TIMESTAMPTZ;
    v_duration INTEGER;
    v_service_name VARCHAR;
    v_professional_name VARCHAR;
    v_price_cents INTEGER;
    v_price_display VARCHAR;
    v_google_calendar_id VARCHAR;
    v_calendar_id UUID;
BEGIN
    SELECT 
        ps.custom_duration_minutes,
        sc.service_name,
        p.professional_name,
        ps.custom_price_cents,
        ps.price_display,
        p.google_calendar_id,
        p.default_calendar_id
    INTO 
        v_duration,
        v_service_name,
        v_professional_name,
        v_price_cents,
        v_price_display,
        v_google_calendar_id,
        v_calendar_id
    FROM professional_services ps
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    JOIN professionals p ON ps.professional_id = p.professional_id
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND ps.is_active = true
    AND p.is_active = true;
    
    IF v_duration IS NULL THEN
        RAISE EXCEPTION 'Service not found for this professional';
    END IF;
    
    v_end_at := p_start_at + (v_duration || ' minutes')::INTERVAL;
    
    INSERT INTO appointments (
        tenant_id,
        professional_id,
        service_id,
        calendar_id,
        start_at,
        end_at,
        duration_minutes,
        patient_contact,
        patient_name,
        service_name,
        professional_name,
        price_cents,
        price_display,
        created_via,
        status,
        sync_status
    ) VALUES (
        p_tenant_id,
        p_professional_id,
        p_service_id,
        v_calendar_id,
        p_start_at,
        v_end_at,
        v_duration,
        p_patient_contact,
        p_patient_name,
        v_service_name,
        v_professional_name,
        v_price_cents,
        v_price_display,
        p_created_via,
        'scheduled',
        'pending'
    )
    RETURNING appointments.appointment_id INTO v_appointment_id;
    
    RETURN QUERY SELECT 
        v_appointment_id,
        v_end_at,
        v_duration,
        v_service_name,
        v_professional_name,
        v_price_display,
        v_google_calendar_id,
        v_calendar_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Cancel an appointment (soft delete)
CREATE OR REPLACE FUNCTION cancel_appointment(
    p_appointment_id UUID,
    p_cancelled_by VARCHAR(100) DEFAULT 'patient',
    p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    google_event_id VARCHAR,
    google_calendar_id VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_appointment appointments;
    v_google_calendar_id VARCHAR;
BEGIN
    SELECT * INTO v_appointment
    FROM appointments
    WHERE appointment_id = p_appointment_id
    AND deleted_at IS NULL;
    
    IF v_appointment.appointment_id IS NULL THEN
        RETURN QUERY SELECT false::BOOLEAN, NULL::VARCHAR, NULL::VARCHAR, 'Appointment not found'::TEXT;
        RETURN;
    END IF;
    
    SELECT google_calendar_id INTO v_google_calendar_id
    FROM professionals
    WHERE professional_id = v_appointment.professional_id;
    
    UPDATE appointments
    SET 
        status = 'cancelled',
        status_reason = p_reason,
        status_changed_at = NOW(),
        status_changed_by = p_cancelled_by,
        deleted_at = NOW(),
        deleted_by = p_cancelled_by,
        deleted_reason = p_reason,
        sync_status = 'pending'
    WHERE appointment_id = p_appointment_id;
    
    RETURN QUERY SELECT 
        true::BOOLEAN, 
        v_appointment.google_event_id::VARCHAR,
        v_google_calendar_id::VARCHAR,
        'Appointment cancelled successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function: Reschedule an appointment
CREATE OR REPLACE FUNCTION reschedule_appointment(
    p_appointment_id UUID,
    p_new_start_at TIMESTAMPTZ,
    p_rescheduled_by VARCHAR(100) DEFAULT 'patient'
)
RETURNS TABLE (
    new_appointment_id UUID,
    new_end_at TIMESTAMPTZ,
    old_google_event_id VARCHAR,
    google_calendar_id VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_old_appointment appointments;
    v_new_appointment_id UUID;
    v_new_end_at TIMESTAMPTZ;
    v_google_calendar_id VARCHAR;
BEGIN
    SELECT * INTO v_old_appointment
    FROM appointments
    WHERE appointment_id = p_appointment_id
    AND deleted_at IS NULL
    AND status IN ('scheduled', 'confirmed');
    
    IF v_old_appointment.appointment_id IS NULL THEN
        RETURN QUERY SELECT 
            NULL::UUID, 
            NULL::TIMESTAMPTZ, 
            NULL::VARCHAR, 
            NULL::VARCHAR, 
            'Appointment not found or cannot be rescheduled'::TEXT;
        RETURN;
    END IF;
    
    SELECT google_calendar_id INTO v_google_calendar_id
    FROM professionals
    WHERE professional_id = v_old_appointment.professional_id;
    
    v_new_end_at := p_new_start_at + (v_old_appointment.duration_minutes || ' minutes')::INTERVAL;
    
    UPDATE appointments
    SET 
        status = 'rescheduled',
        status_reason = 'Rescheduled to new date/time',
        status_changed_at = NOW(),
        status_changed_by = p_rescheduled_by,
        deleted_at = NOW(),
        deleted_by = p_rescheduled_by,
        deleted_reason = 'Rescheduled',
        sync_status = 'pending'
    WHERE appointment_id = p_appointment_id;
    
    INSERT INTO appointments (
        tenant_id,
        professional_id,
        service_id,
        calendar_id,
        start_at,
        end_at,
        duration_minutes,
        patient_contact,
        patient_name,
        patient_email,
        patient_notes,
        service_name,
        professional_name,
        price_cents,
        price_display,
        created_via,
        rescheduled_from_id,
        reschedule_count,
        status,
        sync_status
    ) VALUES (
        v_old_appointment.tenant_id,
        v_old_appointment.professional_id,
        v_old_appointment.service_id,
        v_old_appointment.calendar_id,
        p_new_start_at,
        v_new_end_at,
        v_old_appointment.duration_minutes,
        v_old_appointment.patient_contact,
        v_old_appointment.patient_name,
        v_old_appointment.patient_email,
        v_old_appointment.patient_notes,
        v_old_appointment.service_name,
        v_old_appointment.professional_name,
        v_old_appointment.price_cents,
        v_old_appointment.price_display,
        v_old_appointment.created_via,
        p_appointment_id,
        v_old_appointment.reschedule_count + 1,
        'scheduled',
        'pending'
    )
    RETURNING appointment_id INTO v_new_appointment_id;
    
    RETURN QUERY SELECT 
        v_new_appointment_id,
        v_new_end_at,
        v_old_appointment.google_event_id::VARCHAR,
        v_google_calendar_id::VARCHAR,
        'Appointment rescheduled successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function: Update appointment with Google Event ID
CREATE OR REPLACE FUNCTION update_appointment_google_event(
    p_appointment_id UUID,
    p_google_event_id VARCHAR,
    p_google_event_link TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE appointments
    SET 
        google_event_id = p_google_event_id,
        google_event_link = p_google_event_link,
        sync_status = 'synced',
        last_synced_at = NOW()
    WHERE appointment_id = p_appointment_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get patient's appointments
CREATE OR REPLACE FUNCTION get_patient_appointments(
    p_tenant_id UUID,
    p_patient_contact VARCHAR(50),
    p_include_past BOOLEAN DEFAULT false
)
RETURNS TABLE (
    appointment_id UUID,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    service_name VARCHAR,
    professional_name VARCHAR,
    status VARCHAR,
    price_display VARCHAR,
    google_event_link TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.start_at,
        a.end_at,
        a.service_name,
        a.professional_name,
        a.status,
        a.price_display,
        a.google_event_link
    FROM appointments a
    WHERE a.tenant_id = p_tenant_id
    AND a.patient_contact = p_patient_contact
    AND a.deleted_at IS NULL
    AND (p_include_past OR a.start_at >= NOW())
    ORDER BY a.start_at;
END;
$$ LANGUAGE plpgsql;

-- Function: Get appointments needing reminders
CREATE OR REPLACE FUNCTION get_appointments_for_reminders(
    p_reminder_type VARCHAR(10)
)
RETURNS TABLE (
    appointment_id UUID,
    tenant_id UUID,
    patient_contact VARCHAR,
    patient_name VARCHAR,
    start_at TIMESTAMPTZ,
    service_name VARCHAR,
    professional_name VARCHAR,
    clinic_name VARCHAR,
    clinic_phone VARCHAR
) AS $$
DECLARE
    v_start_range TIMESTAMPTZ;
    v_end_range TIMESTAMPTZ;
BEGIN
    IF p_reminder_type = '24h' THEN
        v_start_range := NOW() + INTERVAL '23 hours';
        v_end_range := NOW() + INTERVAL '25 hours';
    ELSIF p_reminder_type = '1h' THEN
        v_start_range := NOW() + INTERVAL '55 minutes';
        v_end_range := NOW() + INTERVAL '65 minutes';
    ELSE
        RAISE EXCEPTION 'Invalid reminder type: %', p_reminder_type;
    END IF;
    
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.tenant_id,
        a.patient_contact,
        a.patient_name,
        a.start_at,
        a.service_name,
        a.professional_name,
        tc.clinic_name,
        tc.clinic_phone
    FROM appointments a
    JOIN tenant_config tc ON a.tenant_id = tc.tenant_id
    WHERE a.deleted_at IS NULL
    AND a.status IN ('scheduled', 'confirmed')
    AND a.start_at BETWEEN v_start_range AND v_end_range
    AND (
        (p_reminder_type = '24h' AND a.reminder_24h_sent_at IS NULL)
        OR (p_reminder_type = '1h' AND a.reminder_1h_sent_at IS NULL)
    );
END;
$$ LANGUAGE plpgsql;

-- Function: Mark reminder as sent
CREATE OR REPLACE FUNCTION mark_reminder_sent(
    p_appointment_id UUID,
    p_reminder_type VARCHAR(10)
)
RETURNS VOID AS $$
BEGIN
    IF p_reminder_type = '24h' THEN
        UPDATE appointments
        SET reminder_24h_sent_at = NOW()
        WHERE appointment_id = p_appointment_id;
    ELSIF p_reminder_type = '1h' THEN
        UPDATE appointments
        SET reminder_1h_sent_at = NOW()
        WHERE appointment_id = p_appointment_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Get appointment statistics
CREATE OR REPLACE FUNCTION get_appointment_stats(
    p_tenant_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    total_appointments BIGINT,
    completed BIGINT,
    cancelled BIGINT,
    no_shows BIGINT,
    scheduled BIGINT,
    total_revenue_cents BIGINT,
    avg_duration_minutes NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_appointments,
        COUNT(*) FILTER (WHERE status = 'completed')::BIGINT as completed,
        COUNT(*) FILTER (WHERE status = 'cancelled')::BIGINT as cancelled,
        COUNT(*) FILTER (WHERE status = 'no_show')::BIGINT as no_shows,
        COUNT(*) FILTER (WHERE status IN ('scheduled', 'confirmed'))::BIGINT as scheduled,
        COALESCE(SUM(price_cents) FILTER (WHERE status = 'completed'), 0)::BIGINT as total_revenue_cents,
        ROUND(AVG(duration_minutes), 1) as avg_duration_minutes
    FROM appointments
    WHERE tenant_id = p_tenant_id
    AND start_at::DATE BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 21. VIEWS
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

-- FAQ analytics view
CREATE OR REPLACE VIEW faq_analytics AS
SELECT 
    t.tenant_name,
    t.clinic_name,
    f.question_original,
    f.answer,
    f.intent,
    f.view_count,
    f.last_used_at,
    CASE 
        WHEN f.view_count > 10 THEN 'high'
        WHEN f.view_count > 5 THEN 'medium'
        ELSE 'low'
    END as popularity,
    f.created_at
FROM tenant_faq f
JOIN tenant_config t ON f.tenant_id = t.tenant_id
WHERE f.is_active = true
ORDER BY f.view_count DESC;

-- View: Complete service catalog with professional customizations
CREATE OR REPLACE VIEW v_service_offerings AS
SELECT 
    tc.tenant_id,
    tc.tenant_name,
    tc.clinic_name,
    p.professional_id,
    p.professional_name,
    p.professional_title,
    p.specialty,
    p.google_calendar_id,
    sc.service_id,
    sc.service_code,
    sc.service_name,
    sc.service_category,
    sc.service_keywords,
    ps.custom_duration_minutes as duration_minutes,
    ps.custom_price_cents as price_cents,
    ps.price_display,
    ps.is_active
FROM tenant_config tc
JOIN professionals p ON tc.tenant_id = p.tenant_id
JOIN professional_services ps ON p.professional_id = ps.professional_id
JOIN services_catalog sc ON ps.service_id = sc.service_id
WHERE tc.is_active = true
AND p.is_active = true
AND ps.is_active = true
AND sc.is_active = true;

-- View: AI-friendly professional + services context
CREATE OR REPLACE VIEW v_professionals_services_prompt AS
SELECT 
    p.tenant_id,
    p.professional_id,
    p.professional_name,
    p.specialty,
    string_agg(
        format('%s: %s min, %s', 
            sc.service_name, 
            ps.custom_duration_minutes,
            COALESCE(ps.price_display, 'Consultar')
        ),
        ' | '
        ORDER BY sc.service_name
    ) as services_summary
FROM professionals p
JOIN professional_services ps ON p.professional_id = ps.professional_id
JOIN services_catalog sc ON ps.service_id = sc.service_id
WHERE p.is_active = true AND ps.is_active = true AND sc.is_active = true
GROUP BY p.tenant_id, p.professional_id, p.professional_name, p.specialty;

-- View: Calendar overview
CREATE OR REPLACE VIEW v_calendars_overview AS
SELECT 
    c.calendar_id,
    c.tenant_id,
    tc.tenant_name,
    tc.clinic_name,
    c.professional_id,
    p.professional_name,
    p.specialty,
    c.google_calendar_id,
    c.google_calendar_label,
    c.credential_ref,
    c.credential_type,
    COALESCE(c.timezone, tc.timezone) as effective_timezone,
    c.is_primary,
    c.calendar_type,
    c.sync_enabled,
    c.last_sync_at,
    c.sync_error,
    c.is_active,
    c.created_at
FROM calendars c
JOIN tenant_config tc ON c.tenant_id = tc.tenant_id
LEFT JOIN professionals p ON c.professional_id = p.professional_id;

-- View: Active appointments
CREATE OR REPLACE VIEW v_active_appointments AS
SELECT 
    a.appointment_id,
    a.tenant_id,
    tc.tenant_name,
    tc.clinic_name,
    a.professional_id,
    a.professional_name,
    a.service_id,
    a.service_name,
    a.start_at,
    a.end_at,
    a.duration_minutes,
    a.patient_contact,
    a.patient_name,
    a.status,
    a.price_display,
    a.google_event_id,
    a.google_event_link,
    a.confirmation_sent_at,
    a.patient_confirmed_at,
    a.created_at,
    a.created_via
FROM appointments a
JOIN tenant_config tc ON a.tenant_id = tc.tenant_id
WHERE a.deleted_at IS NULL;

-- View: Today's appointments
CREATE OR REPLACE VIEW v_todays_appointments AS
SELECT *
FROM v_active_appointments
WHERE start_at::DATE = CURRENT_DATE
ORDER BY start_at;

-- View: Pending sync appointments
CREATE OR REPLACE VIEW v_pending_sync_appointments AS
SELECT 
    a.appointment_id,
    a.tenant_id,
    a.professional_id,
    p.google_calendar_id,
    c.credential_ref,
    a.start_at,
    a.end_at,
    a.patient_name,
    a.patient_contact,
    a.service_name,
    a.status,
    a.sync_status,
    a.google_event_id
FROM appointments a
JOIN professionals p ON a.professional_id = p.professional_id
LEFT JOIN calendars c ON a.calendar_id = c.calendar_id
WHERE a.sync_status = 'pending'
ORDER BY a.created_at;

-- ============================================================================
-- 22. PERMISSIONS
-- ============================================================================

-- Grant permissions to n8n database user if exists
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        -- Tables
        GRANT SELECT, INSERT, UPDATE ON tenant_config TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_secrets TO n8n_user;
        GRANT SELECT, INSERT ON tenant_activity_log TO n8n_user;
        GRANT USAGE, SELECT ON SEQUENCE tenant_activity_log_log_id_seq TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON tenant_faq TO n8n_user;
        GRANT SELECT, INSERT, UPDATE ON services_catalog TO n8n_user;
        GRANT SELECT, INSERT, UPDATE ON professionals TO n8n_user;
        GRANT SELECT, INSERT, UPDATE ON professional_services TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON response_templates TO n8n_user;
        GRANT SELECT ON state_definitions TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_state TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON calendars TO n8n_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON appointments TO n8n_user;
        
        -- Views
        GRANT SELECT ON v_active_tenants TO n8n_user;
        GRANT SELECT ON faq_analytics TO n8n_user;
        GRANT SELECT ON v_service_offerings TO n8n_user;
        GRANT SELECT ON v_professionals_services_prompt TO n8n_user;
        GRANT SELECT ON v_calendars_overview TO n8n_user;
        GRANT SELECT ON v_active_appointments TO n8n_user;
        GRANT SELECT ON v_todays_appointments TO n8n_user;
        GRANT SELECT ON v_pending_sync_appointments TO n8n_user;
        
        -- Functions
        GRANT EXECUTE ON FUNCTION get_tenant_by_instance(VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION increment_message_count(UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION reset_monthly_quotas() TO n8n_user;
        GRANT EXECUTE ON FUNCTION cleanup_stale_faqs() TO n8n_user;
        GRANT EXECUTE ON FUNCTION find_professionals_for_service(UUID, TEXT) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_professional_service_details(UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION calculate_appointment_end_time(TIMESTAMPTZ, UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION validate_slot_for_service(TIMESTAMPTZ, TIMESTAMPTZ, UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_professional_services_list(UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_services_catalog_for_prompt(UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_service_by_number(UUID, INTEGER) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_template_response(UUID, VARCHAR, JSONB) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_or_create_conversation_state(UUID, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION transition_conversation_state(UUID, VARCHAR, TEXT, JSONB) TO n8n_user;
        GRANT EXECUTE ON FUNCTION update_conversation_state_data(UUID, VARCHAR, UUID, UUID, JSONB, JSONB) TO n8n_user;
        GRANT EXECUTE ON FUNCTION reset_conversation_state(UUID, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION cleanup_expired_conversation_states() TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_calendar_for_professional(UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_tenant_calendars(UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION register_professional_calendar(UUID, UUID, VARCHAR, VARCHAR, BOOLEAN) TO n8n_user;
        GRANT EXECUTE ON FUNCTION migrate_professional_calendars() TO n8n_user;
        GRANT EXECUTE ON FUNCTION create_appointment(UUID, UUID, UUID, TIMESTAMPTZ, VARCHAR, VARCHAR, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION cancel_appointment(UUID, VARCHAR, TEXT) TO n8n_user;
        GRANT EXECUTE ON FUNCTION reschedule_appointment(UUID, TIMESTAMPTZ, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION update_appointment_google_event(UUID, VARCHAR, TEXT) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_patient_appointments(UUID, VARCHAR, BOOLEAN) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_appointments_for_reminders(VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION mark_reminder_sent(UUID, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_appointment_stats(UUID, DATE, DATE) TO n8n_user;
    END IF;
END $$;

-- ============================================================================
-- APPLICATION ROLE (replaces PUBLIC grants)
-- ============================================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_app') THEN
    CREATE ROLE n8n_app LOGIN PASSWORD '{{N8N_APP_PASSWORD}}';
  END IF;
END $$;

GRANT USAGE ON SCHEMA public TO n8n_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO n8n_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO n8n_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO n8n_app;
REVOKE CREATE ON SCHEMA public FROM n8n_app;

-- ============================================================================
-- MESSAGE QUEUE & DEDUPLICATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS message_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id),
  phone VARCHAR(20) NOT NULL,
  message_id VARCHAR(100) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'duplicate')),
  lock_key VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  UNIQUE (tenant_id, message_id)
);

CREATE TABLE IF NOT EXISTS conversation_locks (
  tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id),
  phone VARCHAR(20) NOT NULL,
  locked_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '5 minutes',
  PRIMARY KEY (tenant_id, phone)
);

CREATE INDEX IF NOT EXISTS idx_message_queue_status ON message_queue(status, created_at);
CREATE INDEX IF NOT EXISTS idx_message_queue_tenant ON message_queue(tenant_id, message_id);
CREATE INDEX IF NOT EXISTS idx_conversation_locks_expires ON conversation_locks(expires_at);

-- Function: Enqueue message with deduplication
CREATE OR REPLACE FUNCTION enqueue_message(
  p_tenant_id UUID,
  p_phone VARCHAR,
  p_message_id VARCHAR,
  p_payload JSONB
)
RETURNS TABLE (queue_id UUID, status VARCHAR) AS $$
BEGIN
  INSERT INTO message_queue (tenant_id, phone, message_id, payload, status)
  VALUES (p_tenant_id, p_phone, p_message_id, p_payload, 'pending')
  ON CONFLICT (tenant_id, message_id) DO NOTHING;

  IF NOT FOUND THEN
    RETURN QUERY SELECT id, 'duplicate'::VARCHAR FROM message_queue
      WHERE tenant_id = p_tenant_id AND message_id = p_message_id LIMIT 1;
  ELSE
    RETURN QUERY SELECT id, 'queued'::VARCHAR FROM message_queue
      WHERE tenant_id = p_tenant_id AND message_id = p_message_id LIMIT 1;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Acquire conversation lock
CREATE OR REPLACE FUNCTION acquire_conversation_lock(
  p_tenant_id UUID,
  p_phone VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
  -- Clean expired locks first
  DELETE FROM conversation_locks WHERE expires_at < NOW();

  -- Try to acquire
  INSERT INTO conversation_locks (tenant_id, phone)
  VALUES (p_tenant_id, p_phone)
  ON CONFLICT (tenant_id, phone) DO NOTHING;

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function: Release conversation lock
CREATE OR REPLACE FUNCTION release_conversation_lock(
  p_tenant_id UUID,
  p_phone VARCHAR
)
RETURNS VOID AS $$
BEGIN
  DELETE FROM conversation_locks
  WHERE tenant_id = p_tenant_id AND phone = p_phone;
END;
$$ LANGUAGE plpgsql;

-- Function: Cleanup expired locks (for scheduler)
CREATE OR REPLACE FUNCTION cleanup_expired_locks()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM conversation_locks WHERE expires_at < NOW();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 23. SCHEMA MIGRATIONS TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(14) PRIMARY KEY,
  name VARCHAR(255),
  applied_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 24. SCHEMA COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CONSOLIDATED SCHEMA APPLIED SUCCESSFULLY';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  • tenant_config, tenant_secrets, tenant_activity_log';
    RAISE NOTICE '  • tenant_faq';
    RAISE NOTICE '  • services_catalog, professionals, professional_services';
    RAISE NOTICE '  • response_templates, state_definitions, conversation_state';
    RAISE NOTICE '  • calendars, appointments';
    RAISE NOTICE '  • message_queue, conversation_locks';
    RAISE NOTICE '  • schema_migrations';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '  1. Run seed files from db/seeds/ to populate initial data';
    RAISE NOTICE '  2. Configure tenant with actual Evolution API instance name';
    RAISE NOTICE '  3. Set up Google Calendar credentials';
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;