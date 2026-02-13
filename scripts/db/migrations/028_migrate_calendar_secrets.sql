-- Migration 028: Move Google OAuth credentials from calendars to tenant_secrets
-- This improves security by centralizing secrets in the encrypted secrets table

-- Migrate google_client_secret
INSERT INTO tenant_secrets (tenant_id, secret_key, secret_value_encrypted, secret_type)
SELECT c.tenant_id,
       'google_client_secret_' || c.calendar_id::text,
       c.google_client_secret,
       'oauth'
FROM calendars c
WHERE c.google_client_secret IS NOT NULL
ON CONFLICT DO NOTHING;

-- Migrate google_refresh_token
INSERT INTO tenant_secrets (tenant_id, secret_key, secret_value_encrypted, secret_type)
SELECT c.tenant_id,
       'google_refresh_token_' || c.calendar_id::text,
       c.google_refresh_token,
       'oauth'
FROM calendars c
WHERE c.google_refresh_token IS NOT NULL
ON CONFLICT DO NOTHING;

-- Migrate google_access_token
INSERT INTO tenant_secrets (tenant_id, secret_key, secret_value_encrypted, secret_type)
SELECT c.tenant_id,
       'google_access_token_' || c.calendar_id::text,
       c.google_access_token,
       'oauth'
FROM calendars c
WHERE c.google_access_token IS NOT NULL
ON CONFLICT DO NOTHING;

-- Add credential_ref to link calendars to their secrets
UPDATE calendars
SET credential_ref = 'tenant_secrets:google_*_' || calendar_id::text
WHERE credential_ref IS NULL AND google_client_secret IS NOT NULL;

-- NOTE: After verifying migration, run these to drop the columns:
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_client_secret;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_refresh_token;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_access_token;
-- ALTER TABLE calendars DROP COLUMN IF EXISTS google_token_expires_at;
