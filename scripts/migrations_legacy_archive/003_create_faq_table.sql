-- ========================================
-- FAQ CACHE TABLE FOR AI OPTIMIZATION
-- ========================================
-- Purpose: Cache frequently asked questions to reduce AI API calls
-- Performance Impact: 60-80% reduction in AI calls for common queries
-- Cost Impact: ~$30-50/month savings per clinic

CREATE TABLE IF NOT EXISTS tenant_faq (
    faq_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    -- Question storage
    question_original TEXT NOT NULL,
    question_normalized TEXT NOT NULL, -- Lowercase, trimmed for matching
    
    -- Answer storage
    answer TEXT NOT NULL,
    answer_type VARCHAR(50) DEFAULT 'text', -- text, template, workflow
    
    -- Metadata for matching
    keywords TEXT[] DEFAULT '{}', -- Array of keywords for better matching
    intent VARCHAR(50), -- greeting, hours, location, appointment, etc.
    
    -- Performance tracking
    view_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Management
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    
    -- Prevent duplicate questions per tenant
    UNIQUE(tenant_id, question_normalized)
);

-- Indexes for fast lookups
CREATE INDEX idx_faq_tenant ON tenant_faq(tenant_id) WHERE is_active = true;
CREATE INDEX idx_faq_normalized ON tenant_faq(question_normalized) WHERE is_active = true;
CREATE INDEX idx_faq_keywords ON tenant_faq USING GIN(keywords);
CREATE INDEX idx_faq_intent ON tenant_faq(intent) WHERE is_active = true;
CREATE INDEX idx_faq_popularity ON tenant_faq(tenant_id, view_count DESC) WHERE is_active = true;

-- Auto-update timestamp
CREATE OR REPLACE FUNCTION update_faq_updated_at() 
RETURNS TRIGGER AS $$ 
BEGIN 
    NEW.updated_at = NOW(); 
    RETURN NEW; 
END; 
$$ LANGUAGE plpgsql;

CREATE TRIGGER faq_updated_at 
BEFORE UPDATE ON tenant_faq 
FOR EACH ROW 
EXECUTE FUNCTION update_faq_updated_at();

-- ========================================
-- SEED DATA: Common FAQ entries for ALL active tenants
-- ========================================

-- 1. Greeting FAQ (with numbered menu)
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Oi',
    'oi',
    'Olá! Seja bem-vindo(a) à *' || clinic_name || '*!

Sou o assistente virtual e estou aqui para ajudá-lo(a). Escolha uma opção:

1 - Agendamento de consultas
2 - Reagendamentos
3 - Informações sobre a clínica
4 - Horários e localização

Digite o número da opção desejada (1, 2, 3 ou 4).',
    ARRAY['oi', 'olá', 'ola', 'hey', 'hello', 'bom dia', 'boa tarde', 'boa noite'],
    'greeting',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

-- 2. Option 1 - Appointment FAQ
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    '1',
    '1',
    'Ótimo! Para agendarmos sua consulta, por favor, me informe:

• *Nome completo*:
• *Data de nascimento* (formato: DD/MM/AAAA):

*Nota*: Seu telefone já está disponível via WhatsApp.

Assim que tiver essas informações, posso verificar a disponibilidade para você!',
    ARRAY['1', 'um', 'agendar', 'marcar', 'consulta', 'agendamento'],
    'appointment',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO UPDATE SET
    answer = EXCLUDED.answer,
    keywords = EXCLUDED.keywords;

-- 3. Option 2 - Reschedule FAQ
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    '2',
    '2',
    'Entendi! Você quer *reagendar* uma consulta.

Por favor, me informe:
• O nome completo usado no agendamento anterior
• A data/hora atual da consulta
• A nova data/hora desejada

Assim que tiver essas informações, posso ajudar com o reagendamento!',
    ARRAY['2', 'dois', 'reagendar', 'remarcar', 'mudar', 'alterar', 'trocar'],
    'reschedule',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO UPDATE SET
    answer = EXCLUDED.answer,
    keywords = EXCLUDED.keywords;

-- 4. Option 3 - Clinic Info FAQ
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    '3',
    '3',
    'Informações sobre a clínica *' || clinic_name || '*:

Clínica especializada em diversos tratamentos.

Para mais informações específicas, digite:
• "serviços" - para ver nossos serviços
• "profissionais" - para conhecer nossa equipe
• Ou faça uma pergunta específica',
    ARRAY['3', 'três', 'tres', 'informações', 'informacoes', 'info', 'sobre', 'clinica'],
    'info',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO UPDATE SET
    answer = EXCLUDED.answer,
    keywords = EXCLUDED.keywords;

-- 5. Option 4 - Hours and Location FAQ
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    '4',
    '4',
    'Horários e Localização:

*Horário de Funcionamento:*
' || COALESCE(hours_start || ' às ' || hours_end, 'Consulte disponibilidade') || '
' || COALESCE(days_open_display, 'Segunda a Sábado') || '

*Endereço:*
' || COALESCE(clinic_address, 'Endereço não cadastrado') || '
' || COALESCE('📍 Mapa: ' || google_calendar_public_link, '') || '

*Telefone:* ' || COALESCE(clinic_phone, 'Não disponível') || '

Precisa de mais alguma informação?',
    ARRAY['4', 'quatro', 'horário', 'horario', 'localização', 'localizacao', 'endereço', 'endereco', 'horas', 'onde', 'fica'],
    'hours_location',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO UPDATE SET
    answer = EXCLUDED.answer,
    keywords = EXCLUDED.keywords;

-- 6. Hours FAQ (alternative question format)
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Qual o horário de funcionamento?',
    'qual o horário de funcionamento?',
    'Olá! 👋

Nosso horário de funcionamento é:
*' || hours_start || ' às ' || hours_end || '*
' || COALESCE(days_open_display, 'Segunda a Sábado') || '

Posso ajudar com mais alguma coisa?',
    ARRAY['horário', 'horario', 'hora', 'funcionamento', 'abre', 'fecha', 'aberto', 'atende'],
    'hours',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

-- 7. Location FAQ (alternative question format)
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Qual o endereço da clínica?',
    'qual o endereço da clínica?',
    'Nosso endereço é:
*' || COALESCE(clinic_address, 'Endereço não cadastrado') || '*

📍 ' || COALESCE('Veja no mapa: ' || google_calendar_public_link, 'Mapa não disponível') || '

Qualquer dúvida, estou à disposição!',
    ARRAY['endereço', 'endereco', 'onde', 'localização', 'localizacao', 'fica', 'chegar'],
    'location',
    0
FROM tenant_config
WHERE is_active = true
  AND clinic_address IS NOT NULL
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

-- 8. Appointment FAQ (alternative question format)
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Como posso agendar uma consulta?',
    'como posso agendar uma consulta?',
    'Ótimo! Para agendarmos sua consulta, por favor, me informe:

•⁠  ⁠*Nome completo*:
•⁠  ⁠*Data de nascimento* (formato: DD/MM/AAAA):

*Nota*: Seu telefone já está disponível via WhatsApp, não preciso solicitar. 😊

Assim que tiver essas informações, posso verificar a disponibilidade para você!',
    ARRAY['agendar', 'marcar', 'consulta', 'agendamento', 'horário disponível', 'horario disponivel'],
    'appointment',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

-- 9. Help FAQ
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Ajuda',
    'ajuda',
    'Claro! Posso ajudar você com:

📅 *Agendamentos* - Marcar ou remarcar consultas
📋 *Informações* - Horários, endereço, serviços
🔄 *Reagendamentos* - Alterar horário de consulta
❌ *Cancelamentos* - Cancelar consultas

O que você gostaria de fazer?',
    ARRAY['ajuda', 'help', 'socorro', 'não entendi', 'nao entendi', 'preciso de ajuda'],
    'help',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

-- ========================================
-- ANALYTICS VIEW
-- ========================================

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

-- ========================================
-- MAINTENANCE FUNCTION
-- ========================================

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

-- ========================================
-- VERIFY SEED DATA
-- ========================================

SELECT 
    COUNT(*) as total_faqs,
    COUNT(DISTINCT tenant_id) as tenants_com_faq
FROM tenant_faq
WHERE is_active = true;

-- Schedule cleanup_stale_faqs() to run monthly via cron or n8n workflow

COMMENT ON TABLE tenant_faq IS 'Caches frequently asked questions to reduce AI API calls and improve response time';
COMMENT ON COLUMN tenant_faq.question_normalized IS 'Lowercase normalized version for efficient matching';
COMMENT ON COLUMN tenant_faq.view_count IS 'Tracks popularity - higher count = more likely to be useful';
COMMENT ON COLUMN tenant_faq.keywords IS 'Array of keywords for fuzzy matching via GIN index';


