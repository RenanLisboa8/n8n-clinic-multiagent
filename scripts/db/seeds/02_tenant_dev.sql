-- ============================================================================
-- SEED: DEVELOPMENT TENANT
-- Description: Sample tenant for development and testing
-- ============================================================================

INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
    clinic_type,
    clinic_address,
    clinic_phone,
    clinic_email,
    timezone,
    hours_start,
    hours_end,
    days_open_display,
    operating_days,
    google_calendar_id,
    google_calendar_public_link,
    google_tasks_list_id,
    mcp_calendar_endpoint,
    telegram_internal_chat_id,
    whatsapp_number,
    system_prompt_patient,
    system_prompt_internal,
    system_prompt_confirmation,
    llm_model_name,
    llm_temperature,
    features,
    subscription_tier,
    subscription_status,
    monthly_message_limit
) VALUES (
    'Clínica Moreira',
    'clinica-moreira',
    'clinic_moreira_instance',
    'Clínica Moreira',
    'mixed',
    'Rua Rio Casca, 417 – Belo Horizonte, MG',
    '+5531999999999',
    'contato@clinicamoreira.com.br',
    'America/Sao_Paulo',
    '08:00',
    '19:00',
    'Segunda–Sábado',
    '["1","2","3","4","5","6"]'::jsonb,
    'your-calendar-id@group.calendar.google.com',
    'https://calendar.google.com/calendar/embed?src=your-calendar-id',
    'your-tasks-list-id',
    'https://your-mcp-endpoint/calendar/sse',
    '100',
    '+5531999999999',
    'Você é a atendente virtual da Clínica Moreira. Responda de forma objetiva e profissional.',
    'Você é o assistente interno da Clínica Moreira para a equipe.',
    'Você envia lembretes de consulta da Clínica Moreira.',
    'gemini-2.0-flash-lite',
    0.7,
    '{"audio_transcription": true, "image_ocr": true, "appointment_confirmation": true, "telegram_internal_assistant": true, "human_escalation": true}'::jsonb,
    'professional',
    'active',
    10000
)
ON CONFLICT (evolution_instance_name) DO UPDATE SET
    updated_at = NOW();

-- Optional: Test tenant
INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
    clinic_type,
    clinic_address,
    clinic_phone,
    timezone,
    hours_start,
    hours_end,
    google_calendar_id,
    telegram_internal_chat_id,
    system_prompt_patient,
    system_prompt_internal,
    system_prompt_confirmation,
    subscription_tier,
    subscription_status,
    monthly_message_limit
) VALUES (
    'Clínica Teste',
    'clinica-teste',
    'test_clinic_instance',
    'Clínica Teste',
    'mixed',
    'Rua Teste, 123 - São Paulo, SP',
    '+5511888888888',
    'America/Sao_Paulo',
    '09:00',
    '18:00',
    'test-calendar@group.calendar.google.com',
    '999',
    'Assistente da Clínica Teste.',
    'Assistente interno da Clínica Teste.',
    'Lembretes da Clínica Teste.',
    'basic',
    'trial',
    1000
)
ON CONFLICT (evolution_instance_name) DO NOTHING;

DO $$
DECLARE
    tenant_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO tenant_count FROM tenant_config WHERE is_active = true;
    RAISE NOTICE '✅ Tenant seed complete. Active tenants: %', tenant_count;
END $$;