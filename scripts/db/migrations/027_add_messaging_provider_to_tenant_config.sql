-- Migration 027: Add messaging_provider column to tenant_config
-- Supports messaging abstraction layer (Evolution API / Chatwoot)

ALTER TABLE tenant_config
ADD COLUMN IF NOT EXISTS messaging_provider VARCHAR(20) DEFAULT 'evolution'
CHECK (messaging_provider IN ('evolution', 'chatwoot'));

COMMENT ON COLUMN tenant_config.messaging_provider IS 'Messaging provider for this tenant: evolution (WhatsApp via Evolution API) or chatwoot';

-- Update existing tenants to use evolution (already the default)
UPDATE tenant_config SET messaging_provider = 'evolution' WHERE messaging_provider IS NULL;
