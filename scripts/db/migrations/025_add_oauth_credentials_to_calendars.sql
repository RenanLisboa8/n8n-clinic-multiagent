-- ============================================================================
-- MIGRATION: Add OAuth Credentials to Calendars Table
-- Version: 025
-- Date: 2026-02-01
-- Description: Adds Google OAuth credential columns to support dynamic multi-tenant
--              calendar authentication without n8n credential management
-- ============================================================================

-- ============================================================================
-- 1. ADD NEW COLUMNS FOR OAUTH CREDENTIALS
-- ============================================================================

-- Google OAuth client credentials (per-tenant or per-calendar)
ALTER TABLE calendars 
ADD COLUMN IF NOT EXISTS google_client_id VARCHAR(255);

ALTER TABLE calendars 
ADD COLUMN IF NOT EXISTS google_client_secret TEXT;

-- Encrypted refresh token for long-lived access
ALTER TABLE calendars 
ADD COLUMN IF NOT EXISTS google_refresh_token TEXT;

-- Optional: store the last access token (short-lived, can be regenerated)
ALTER TABLE calendars 
ADD COLUMN IF NOT EXISTS google_access_token TEXT;

-- Token expiry tracking
ALTER TABLE calendars 
ADD COLUMN IF NOT EXISTS google_token_expires_at TIMESTAMPTZ;

-- OAuth scope granted
ALTER TABLE calendars 
ADD COLUMN IF NOT EXISTS google_oauth_scope TEXT DEFAULT 'https://www.googleapis.com/auth/calendar';

-- ============================================================================
-- 2. UPDATE CREDENTIAL TYPE CONSTRAINT
-- ============================================================================

-- Drop existing constraint and recreate with new type
ALTER TABLE calendars 
DROP CONSTRAINT IF EXISTS valid_credential_type;

ALTER TABLE calendars 
ADD CONSTRAINT valid_credential_type CHECK (
    credential_type IN ('n8n_credential', 'env_key', 'tenant_default', 'oauth_database')
);

-- ============================================================================
-- 3. ADD COMMENTS
-- ============================================================================

COMMENT ON COLUMN calendars.google_client_id IS 'Google OAuth Client ID from Google Cloud Console';
COMMENT ON COLUMN calendars.google_client_secret IS 'Google OAuth Client Secret (encrypted at rest recommended)';
COMMENT ON COLUMN calendars.google_refresh_token IS 'Long-lived refresh token for obtaining access tokens';
COMMENT ON COLUMN calendars.google_access_token IS 'Short-lived access token (cached, regenerated on expiry)';
COMMENT ON COLUMN calendars.google_token_expires_at IS 'Timestamp when the current access token expires';
COMMENT ON COLUMN calendars.google_oauth_scope IS 'OAuth scope granted during authorization';

-- ============================================================================
-- 4. ADD INDEX FOR TOKEN EXPIRY (for cache invalidation queries)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_calendars_token_expiry 
ON calendars(google_token_expires_at) 
WHERE google_refresh_token IS NOT NULL AND sync_enabled = true;

-- ============================================================================
-- 5. HELPER FUNCTION: Check if token needs refresh
-- ============================================================================

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

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- To rollback this migration, run:
--
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_client_id;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_client_secret;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_refresh_token;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_access_token;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_token_expires_at;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_oauth_scope;
-- ALTER TABLE calendars DROP CONSTRAINT IF EXISTS valid_credential_type;
-- ALTER TABLE calendars ADD CONSTRAINT valid_credential_type CHECK (credential_type IN ('n8n_credential', 'env_key', 'tenant_default'));
-- DROP FUNCTION IF EXISTS calendar_token_needs_refresh;
-- ============================================================================
