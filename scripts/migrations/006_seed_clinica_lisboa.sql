-- ============================================================================
-- SEED CLÍNICA LISBOA
-- Date: 2026-01-03
-- Description: Creates tenant configuration for Clínica Lisboa
-- ============================================================================

INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
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
    'Clínica Lisboa',
    'clinica-lisboa',
    'clinica_lisboa_tenant',
    'Clínica Lisboa',
    '+5516997831310',
    'renan.lisboa8@gmail.com',
    'America/Sao_Paulo',
    '06:00',
    '20:00',
    'Segunda–Sábado',
    '["1","2","3","4","5","6"]'::jsonb,
    
    -- Google Integration
    'renan.lisboa8@gmail.com',
    'https://calendar.google.com/calendar/embed?src=renan.lisboa8%40gmail.com&ctz=America%2FSao_Paulo',
    
    -- Telegram
    '643763205',
    '+5516997831310',
    
    -- AI Prompts (Patient-facing assistant)
    'Hoje é {{ $now }}

PAPEL:
Você é a atendente virtual da Clínica Lisboa, especializada em atendimento humanizado via WhatsApp.

OBJETIVO:
1. Atender pacientes de forma ágil e eficiente
2. Responder dúvidas sobre a clínica e serviços
3. Agendar, remarcar e cancelar consultas
4. Processar imagens (receitas, exames) e áudios

INFORMAÇÕES DA CLÍNICA:
- Nome: Clínica Lisboa
- Telefone: +5516997831310
- E-mail: renan.lisboa8@gmail.com
- Horário: Segunda–Sábado, 06h–20h
- Domingo e feriados: FECHADO
- Link da Agenda: https://calendar.google.com/calendar/embed?src=renan.lisboa8%40gmail.com

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
3. Use AVALIABILITY_CALENDAR para verificar horários livres (Start_Time 06:00, End_Time 20:00)
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
Você é o assistente interno de reagendamento da Clínica Lisboa, acionado diretamente por profissionais via Telegram.

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
Você é o agente de confirmação de consultas da Clínica Lisboa.

OBJETIVO:
1. Listar eventos agendados para o próximo dia no MCP Calendar
2. Obter número de telefone na descrição de cada evento
3. Enviar mensagem de confirmação usando a ferramenta "relembraAGENDAMENTO"

IMPORTANTE:
- Você NÃO recebe respostas diretamente
- O retorno do paciente é tratado por outro agente
- Envie confirmações de forma clara e objetiva',
    
    -- Model Configuration
    'gemini-2.0-flash-exp',
    0.7,
    
    -- Features
    '{
        "audio_transcription": true,
        "image_ocr": true,
        "appointment_confirmation": true,
        "telegram_internal_assistant": true,
        "human_escalation": true
    }'::jsonb,
    
    -- Subscription
    'professional',
    'active',
    10000
)
ON CONFLICT (evolution_instance_name) DO UPDATE SET
    updated_at = NOW(),
    clinic_name = EXCLUDED.clinic_name,
    clinic_phone = EXCLUDED.clinic_phone,
    clinic_email = EXCLUDED.clinic_email,
    hours_start = EXCLUDED.hours_start,
    hours_end = EXCLUDED.hours_end,
    google_calendar_id = EXCLUDED.google_calendar_id,
    telegram_internal_chat_id = EXCLUDED.telegram_internal_chat_id,
    system_prompt_patient = EXCLUDED.system_prompt_patient,
    system_prompt_internal = EXCLUDED.system_prompt_internal,
    system_prompt_confirmation = EXCLUDED.system_prompt_confirmation;

-- ============================================================================
-- STORE GEMINI API KEY IN SECRETS TABLE
-- ============================================================================

-- First get the tenant_id
DO $$
DECLARE
    v_tenant_id UUID;
BEGIN
    SELECT tenant_id INTO v_tenant_id 
    FROM tenant_config 
    WHERE evolution_instance_name = 'clinica_lisboa_tenant';
    
    IF v_tenant_id IS NOT NULL THEN
        -- Insert or update the Gemini API key
        INSERT INTO tenant_secrets (tenant_id, secret_key, secret_value_encrypted, secret_type)
        VALUES (v_tenant_id, 'gemini_api_key', 'AIzaSyBiKu5Kjj7xGTGgguOGTJwRPtXiW23aNdE', 'api_key')
        ON CONFLICT (tenant_id, secret_key) DO UPDATE SET
            secret_value_encrypted = EXCLUDED.secret_value_encrypted,
            last_rotated_at = NOW();
            
        RAISE NOTICE '✅ Gemini API key stored for Clínica Lisboa';
    END IF;
END $$;

-- ============================================================================
-- VERIFY INSERTION
-- ============================================================================

SELECT 
    tenant_name,
    evolution_instance_name,
    clinic_name,
    clinic_email,
    hours_start || ' - ' || hours_end as horario,
    subscription_tier,
    is_active
FROM tenant_config
WHERE evolution_instance_name = 'clinica_lisboa_tenant';

