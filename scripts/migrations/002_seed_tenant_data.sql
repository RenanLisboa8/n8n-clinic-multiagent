-- ============================================================================
-- SEED TENANT DATA
-- Version: 1.0.0
-- Date: 2026-01-01
-- Description: Seeds initial tenant data (migrate your existing clinic)
-- ============================================================================

-- ============================================================================
-- IMPORTANT: UPDATE THESE VALUES WITH YOUR ACTUAL CLINIC DATA
-- ============================================================================

-- Insert your existing clinic configuration
INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
    clinic_address,
    clinic_phone,
    clinic_email,
    timezone,
    hours_start,
    hours_end,
    days_open_display,
    operating_days,
    
    -- Google Integration
    google_calendar_id,
    google_calendar_public_link,
    google_tasks_list_id,
    mcp_calendar_endpoint,
    
    -- Telegram
    telegram_internal_chat_id,
    whatsapp_number,
    
    -- AI Prompts
    system_prompt_patient,
    system_prompt_internal,
    system_prompt_confirmation,
    
    -- Configuration
    llm_model_name,
    llm_temperature,
    features,
    
    -- Subscription
    subscription_tier,
    subscription_status,
    monthly_message_limit
) VALUES (
    -- Basic Info
    'Clínica Moreira',  -- tenant_name
    'clinica-moreira',  -- tenant_slug (URL-safe)
    'clinic_moreira_instance',  -- evolution_instance_name (MUST match Evolution API)
    'Clínica Moreira',  -- clinic_name (display name)
    'Rua Rio Casca, 417 – Belo Horizonte, MG',  -- clinic_address
    '+5531999999999',  -- clinic_phone (update with real number)
    'contato@clinicamoreira.com.br',  -- clinic_email
    'America/Sao_Paulo',  -- timezone
    '08:00',  -- hours_start
    '19:00',  -- hours_end
    'Segunda–Sábado',  -- days_open_display
    '["1","2","3","4","5","6"]'::jsonb,  -- operating_days (Mon-Sat)
    
    -- Google Integration (UPDATE WITH YOUR ACTUAL IDs)
    'a57a3781407f42b1ad7fe24ce76f558dc6c86fea5f349b7fd39747a2294c1654@group.calendar.google.com',  -- google_calendar_id
    'https://calendar.google.com/calendar/embed?src=a57a3781407f42b1ad7fe24ce76f558dc6c86fea5f349b7fd39747a2294c1654%40group.calendar.google.com&ctz=America%2FArgentina%2FBuenos_Aires',  -- google_calendar_public_link
    'bDQ5ZlNVV2lPQ3pYT3NsNA',  -- google_tasks_list_id (from your workflow)
    'https://engaging-seahorse-19.rshare.io/mcp/ceb17fa5-1937-405f-8000-ea3be7d2b032/mcp/:tool/calendar/sse',  -- mcp_calendar_endpoint
    
    -- Telegram (UPDATE WITH YOUR CHAT ID)
    '100',  -- telegram_internal_chat_id (your actual Telegram chat ID)
    '+5531999999999',  -- whatsapp_number
    
    -- AI Prompts (Patient-facing assistant)
    'Hoje é {{ $now }}

PAPEL:
Você é a atendente virtual da Clínica Moreira, especializada em atendimento humanizado via WhatsApp.

OBJETIVO:
1. Atender pacientes de forma ágil e eficiente
2. Responder dúvidas sobre a clínica e serviços
3. Agendar, remarcar e cancelar consultas
4. Processar imagens (receitas, exames) e áudios

INFORMAÇÕES DA CLÍNICA:
- Nome: Clínica Moreira
- Endereço: Rua Rio Casca, 417 – Belo Horizonte, MG
- Telefone: +5531999999999
- Horário: Segunda–Sábado, 08h–19h
- Domingo e feriados: FECHADO
- Link da Agenda: https://calendar.google.com/calendar/embed?src=a57a3781407f42b1ad7fe24ce76f558dc6c86fea5f349b7fd39747a2294c1654%40group.calendar.google.com

FERRAMENTAS DISPONÍVEIS:
1. MCP_CALENDAR - Para consultar, criar, atualizar e excluir eventos no Google Calendar
2. CallToHuman - Para escalar casos urgentes ou complexos para atendimento humano

DIRETRIZES:
1. Sempre cordial, empática e profissional
2. Use linguagem clara e acessível (sem jargões médicos)
3. Para agendamentos, SEMPRE confirme: nome completo, data de nascimento, telefone
4. SEMPRE verifique disponibilidade antes de confirmar horários usando AVALIABILITY_CALENDAR
5. NUNCA invente informações - se não sabe, seja honesto
6. Use formatação WhatsApp: *negrito* para ênfase (não use **)
7. Evite emojis excessivos, use com moderação

PROCEDIMENTOS DE AGENDAMENTO:
1. Cumprimente e peça: nome completo, data de nascimento, telefone
2. Pergunte data e turno preferidos
3. Use AVALIABILITY_CALENDAR para verificar horários livres (Start_Time 08:00, End_Time 19:00)
4. Após paciente escolher, use CREATE_CALENDAR com:
   - start, end (formato ISO)
   - Description: SEMPRE incluir telefone, nome completo, data de nascimento
5. AGUARDE retorno do MCP_CALENDAR antes de confirmar ao paciente

REMARCAÇÃO:
1. Solicite dados e nova preferência
2. Use GET_ALL_CALENDAR para localizar evento antigo
3. DELETE_CALENDAR no Event_ID antigo
4. CREATE_CALENDAR para novo horário
5. Confirme após sucesso

CANCELAMENTO:
1. Solicite dados do paciente
2. Localize Event_ID via GET_ALL_CALENDAR
3. DELETE_CALENDAR
4. Confirme cancelamento

ESCALAÇÃO PARA HUMANO (CallToHuman):
Dispare IMEDIATAMENTE quando:
- Urgência médica ou mal-estar grave
- Pedido de diagnóstico ou opinião médica
- Insatisfação expressa do paciente
- Assuntos fora do escopo da clínica
- Paciente solicita falar com humano

IMPORTANTE:
- Agendamentos APENAS em datas futuras
- NUNCA confirme sem retorno do MCP_CALENDAR
- Mantenha tom profissional sempre',
    
    -- AI Prompts (Internal assistant for staff)
    'Hoje é {{ $now }}

PAPEL:
Você é o assistente interno de reagendamento da Clínica Moreira, acionado diretamente por profissionais via Telegram.

OBJETIVO:
1. Gerenciar agenda (Consultar/Reagendar consultas)
2. Adicionar itens na lista de compras da clínica

FERRAMENTAS:
- MCP Google Calendar: Para ver disponibilidade, consultar e editar eventos
- Google Tasks: Para adicionar itens na lista de compras
- Ferramenta_Envio_Wpp: Para enviar mensagens de confirmação/remarcação aos pacientes

PROCEDIMENTOS:
1. Reagendamento:
   - Use MCP Google Calendar para localizar a consulta
   - Extraia o telefone do paciente na descrição do evento
   - Atualize o evento ou crie novo
   - SEMPRE use Ferramenta_Envio_Wpp para avisar o paciente

2. Lista de Compras:
   - Use Google Tasks para adicionar o item solicitado

IMPORTANTE:
- Você atende APENAS a equipe interna
- SEMPRE notifique o paciente após reagendar
- Mantenha linguagem profissional',
    
    -- AI Prompts (Appointment confirmation)
    'Hoje é {{ $now }}

PAPEL:
Você é o agente de confirmação de consultas da Clínica Moreira.

OBJETIVO:
1. Listar eventos agendados para o próximo dia no MCP Calendar
2. Obter número de telefone na descrição de cada evento
3. Enviar mensagem de confirmação usando a ferramenta "relembraAGENDAMENTO"

IMPORTANTE:
- Você NÃO recebe respostas diretamente
- O retorno do paciente é tratado por outro agente
- Envie confirmações de forma clara e objetiva',
    
    -- Model Configuration
    'gemini-2.0-flash-exp',  -- llm_model_name
    0.7,  -- llm_temperature
    
    -- Features
    '{
        "audio_transcription": true,
        "image_ocr": true,
        "appointment_confirmation": true,
        "telegram_internal_assistant": true,
        "human_escalation": true
    }'::jsonb,
    
    -- Subscription
    'professional',  -- subscription_tier
    'active',  -- subscription_status
    10000  -- monthly_message_limit
)
ON CONFLICT (evolution_instance_name) DO UPDATE SET
    updated_at = NOW(),
    system_prompt_patient = EXCLUDED.system_prompt_patient,
    system_prompt_internal = EXCLUDED.system_prompt_internal,
    system_prompt_confirmation = EXCLUDED.system_prompt_confirmation;

-- ============================================================================
-- CREATE A TEST TENANT (Optional - for testing multi-tenancy)
-- ============================================================================

INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
    clinic_address,
    clinic_phone,
    timezone,
    hours_start,
    hours_end,
    google_calendar_id,
    google_tasks_list_id,
    mcp_calendar_endpoint,
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
    'test_clinic_instance',  -- Create this instance in Evolution API
    'Clínica Teste',
    'Rua Teste, 123 - São Paulo, SP',
    '+5511888888888',
    'America/Sao_Paulo',
    '09:00',
    '18:00',
    'test_calendar@group.calendar.google.com',  -- Create separate calendar
    'test_tasks_list_id',
    'https://mcp-server.com/test/calendar/sse',
    '999',  -- Different Telegram chat
    'Você é o assistente da Clínica Teste...',
    'Você é o assistente interno da Clínica Teste...',
    'Você envia confirmações da Clínica Teste...',
    'basic',
    'trial',
    1000
)
ON CONFLICT (evolution_instance_name) DO NOTHING;

-- ============================================================================
-- VERIFY INSERTION
-- ============================================================================

DO $$
DECLARE
    tenant_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO tenant_count FROM tenant_config WHERE is_active = true;
    RAISE NOTICE '✅ Tenant data seeded successfully';
    RAISE NOTICE 'Active tenants: %', tenant_count;
    RAISE NOTICE 'Next step: Update docker-compose.yaml and restart n8n';
END $$;

-- Display inserted tenants
SELECT 
    tenant_name,
    evolution_instance_name,
    clinic_name,
    subscription_tier,
    is_active
FROM tenant_config
ORDER BY created_at;

