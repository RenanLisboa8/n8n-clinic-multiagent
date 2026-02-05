-- ============================================================================
-- MIGRATION: Add Telegram Bot Token to Tenant Config
-- Version: 026
-- Date: 2026-02-01
-- Description: Stores Telegram bot token per tenant for scalable multi-tenant
--              notifications without n8n credential management
-- ============================================================================

-- ============================================================================
-- 1. ADD TELEGRAM BOT TOKEN COLUMN
-- ============================================================================

ALTER TABLE tenant_config
ADD COLUMN IF NOT EXISTS telegram_bot_token TEXT;

COMMENT ON COLUMN tenant_config.telegram_bot_token IS 'Telegram Bot API token for this tenant (from @BotFather). Used for sendMessage and internal assistant.';

-- ============================================================================
-- ROLLBACK INSTRUCTIONS
-- ============================================================================
-- To rollback this migration, run:
--
-- ALTER TABLE tenant_config DROP COLUMN IF EXISTS telegram_bot_token;
-- ============================================================================
