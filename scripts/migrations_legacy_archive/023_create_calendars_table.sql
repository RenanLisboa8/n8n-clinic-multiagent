-- ============================================================================
-- CALENDARS TABLE MIGRATION
-- Version: 1.0.0
-- Date: 2026-02-01
-- Description: Creates calendars table for multi-tenant Google Calendar integration
--              Supports per-professional calendar IDs and credential references
-- ============================================================================
-- 
-- ARCHITECTURE:
-- 
-- This table centralizes Google Calendar configuration per professional/tenant.
-- It enables:
-- 1. One calendar per professional (today's pattern)
-- 2. Credential reference storage (n8n credential id or env key)
-- 3. Multiple calendars per tenant (e.g., different locations)
-- 4. Easy onboarding: new clinic = DB inserts only, no workflow edits
--
--   ┌─────────────────────┐
--   │   tenant_config     │
--   │   (Clinic Config)   │
--   └─────────┬───────────┘
--             │ 1:N
--             ▼
--   ┌─────────────────────┐         ┌─────────────────────┐
--   │    professionals    │         │     calendars       │
--   │  (Doctors/Staff)    │◀────────│ (Calendar Configs)  │
--   └─────────────────────┘  1:1    └─────────────────────┘
--                                              │
--                                              │ 1:N
--                                              ▼
--                                   ┌─────────────────────┐
--                                   │   appointments      │
--                                   │ (Audit & Tracking)  │
--                                   └─────────────────────┘
--
-- ============================================================================

-- ============================================================================
-- 1. CREATE CALENDARS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS calendars (
    -- Primary Key
    calendar_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    professional_id UUID REFERENCES professionals(professional_id) ON DELETE SET NULL,
    
    -- Google Calendar Configuration
    google_calendar_id VARCHAR(255) NOT NULL,        -- The Google Calendar ID (e.g., "email@gmail.com" or calendar ID)
    google_calendar_label VARCHAR(100),              -- Display name: 'Agenda Dr. José'
    
    -- Credential Reference
    -- This can be:
    -- 1. n8n credential ID (preferred for multi-tenant)
    -- 2. Environment variable key (e.g., 'GOOGLE_CALENDAR_CREDENTIAL_CLINIC_A')
    -- 3. NULL if using tenant's default credential
    credential_ref VARCHAR(255),
    credential_type VARCHAR(50) DEFAULT 'n8n_credential', -- 'n8n_credential', 'env_key', 'tenant_default'
    
    -- Calendar Properties
    calendar_color VARCHAR(20) DEFAULT '#4285f4',    -- Color for UI display
    timezone VARCHAR(50),                            -- Override tenant timezone if needed
    
    -- Calendar Purpose
    is_primary BOOLEAN DEFAULT false,                -- Primary calendar for the professional
    calendar_type VARCHAR(50) DEFAULT 'appointments', -- 'appointments', 'availability', 'shared'
    
    -- Sync Settings
    sync_enabled BOOLEAN DEFAULT true,               -- Whether to sync with this calendar
    last_sync_at TIMESTAMPTZ,                        -- Last successful sync timestamp
    sync_error TEXT,                                 -- Last sync error if any
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT unique_google_calendar_per_tenant UNIQUE(tenant_id, google_calendar_id),
    CONSTRAINT valid_credential_type CHECK (credential_type IN ('n8n_credential', 'env_key', 'tenant_default')),
    CONSTRAINT valid_calendar_type CHECK (calendar_type IN ('appointments', 'availability', 'shared', 'other'))
);

COMMENT ON TABLE calendars IS 'Centralizes Google Calendar configuration per professional/tenant for multi-tenant SaaS';
COMMENT ON COLUMN calendars.google_calendar_id IS 'Google Calendar ID - unique per tenant';
COMMENT ON COLUMN calendars.credential_ref IS 'Reference to n8n credential or env variable key';
COMMENT ON COLUMN calendars.is_primary IS 'True if this is the primary calendar for the associated professional';

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================

-- Fast lookup by tenant
CREATE INDEX idx_calendars_tenant 
ON calendars(tenant_id) 
WHERE is_active = true;

-- Fast lookup by professional
CREATE INDEX idx_calendars_professional 
ON calendars(professional_id) 
WHERE is_active = true AND professional_id IS NOT NULL;

-- Find primary calendar for a professional
CREATE INDEX idx_calendars_primary 
ON calendars(tenant_id, professional_id, is_primary) 
WHERE is_active = true AND is_primary = true;

-- Sync status index
CREATE INDEX idx_calendars_sync 
ON calendars(last_sync_at) 
WHERE sync_enabled = true;

-- ============================================================================
-- 3. CREATE UPDATE TRIGGER
-- ============================================================================

DROP TRIGGER IF EXISTS calendars_updated_at ON calendars;
CREATE TRIGGER calendars_updated_at
    BEFORE UPDATE ON calendars
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- 4. ADD OPTIONAL FK FROM PROFESSIONALS TO CALENDARS
-- ============================================================================

-- Add default_calendar_id column to professionals table
-- This provides a direct reference to the professional's primary calendar
ALTER TABLE professionals 
ADD COLUMN IF NOT EXISTS default_calendar_id UUID REFERENCES calendars(calendar_id) ON DELETE SET NULL;

COMMENT ON COLUMN professionals.default_calendar_id IS 'Reference to the primary calendar for this professional (from calendars table)';

-- ============================================================================
-- 5. ADD DEFAULT CREDENTIAL TO TENANT_CONFIG
-- ============================================================================

-- Add default_google_credential_id to tenant_config for fallback
ALTER TABLE tenant_config 
ADD COLUMN IF NOT EXISTS default_google_credential_id VARCHAR(255);

COMMENT ON COLUMN tenant_config.default_google_credential_id IS 'Default n8n credential ID for Google Calendar (used when calendar has no specific credential_ref)';

-- ============================================================================
-- 6. HELPER FUNCTIONS
-- ============================================================================

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

-- Function: Get all calendars for a tenant (for sync operations)
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
    -- Get tenant timezone
    SELECT timezone INTO v_timezone
    FROM tenant_config
    WHERE tenant_id = p_tenant_id;
    
    -- If setting as primary, unset any existing primary for this professional
    IF p_is_primary THEN
        UPDATE calendars
        SET is_primary = false
        WHERE tenant_id = p_tenant_id
        AND professional_id = p_professional_id
        AND is_primary = true;
    END IF;
    
    -- Insert new calendar
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
    
    -- Update professional's default_calendar_id if primary
    IF p_is_primary THEN
        UPDATE professionals
        SET default_calendar_id = v_calendar_id
        WHERE professional_id = p_professional_id;
    END IF;
    
    RETURN v_calendar_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Migrate existing google_calendar_id from professionals to calendars
-- Run this once after migration to populate calendars from existing data
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
        
        -- Update professional's default_calendar_id
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
-- 7. CREATE VIEW FOR CALENDAR OVERVIEW
-- ============================================================================

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

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================

DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON calendars TO n8n_user;
        GRANT SELECT ON v_calendars_overview TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_calendar_for_professional(UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_tenant_calendars(UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION register_professional_calendar(UUID, UUID, VARCHAR, VARCHAR, BOOLEAN) TO n8n_user;
        GRANT EXECUTE ON FUNCTION migrate_professional_calendars() TO n8n_user;
    END IF;
END $$;

-- Public grants for development
GRANT SELECT, INSERT, UPDATE, DELETE ON calendars TO PUBLIC;
GRANT SELECT ON v_calendars_overview TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_calendar_for_professional TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_tenant_calendars TO PUBLIC;
GRANT EXECUTE ON FUNCTION register_professional_calendar TO PUBLIC;
GRANT EXECUTE ON FUNCTION migrate_professional_calendars TO PUBLIC;

-- ============================================================================
-- 9. MIGRATION COMPLETE
-- ============================================================================

DO $$
DECLARE
    v_migrated INTEGER;
BEGIN
    -- Auto-migrate existing calendar data from professionals table
    SELECT migrate_professional_calendars() INTO v_migrated;
    
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CALENDARS TABLE MIGRATION COMPLETE';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Table created: calendars';
    RAISE NOTICE 'Columns added: professionals.default_calendar_id';
    RAISE NOTICE 'Columns added: tenant_config.default_google_credential_id';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions created:';
    RAISE NOTICE '  • get_calendar_for_professional() - Get calendar config for a professional';
    RAISE NOTICE '  • get_tenant_calendars() - Get all calendars for a tenant';
    RAISE NOTICE '  • register_professional_calendar() - Register/update calendar';
    RAISE NOTICE '  • migrate_professional_calendars() - Migrate existing data';
    RAISE NOTICE '';
    RAISE NOTICE 'Migrated % existing calendar configurations from professionals table', v_migrated;
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 024_create_appointments_table.sql';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;