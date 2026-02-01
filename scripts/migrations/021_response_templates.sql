-- Migration 021: Response Templates for Database-Driven Responses
-- Reduces AI calls by providing pre-built template responses

-- Create response_templates table
CREATE TABLE IF NOT EXISTS response_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
  template_key VARCHAR(100) NOT NULL,
  template_text TEXT NOT NULL,
  variables JSONB DEFAULT '{}',
  category VARCHAR(50) DEFAULT 'general',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(tenant_id, template_key)
);

-- Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_response_templates_tenant_key 
ON response_templates(tenant_id, template_key) WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_response_templates_category
ON response_templates(tenant_id, category) WHERE is_active = true;

-- Insert default templates (these will be customized per tenant)
-- Using a placeholder tenant_id that should be replaced during setup

-- Greeting templates
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'greeting_new',
  E'Olá {{patient_name}}! 👋\n\nSeja bem-vindo(a) à *{{clinic_name}}*!\n\nComo posso ajudar você hoje?\n\n1️⃣ Agendar consulta\n2️⃣ Reagendar consulta\n3️⃣ Cancelar consulta\n4️⃣ Informações sobre serviços\n5️⃣ Horário e localização\n\n_Digite o número da opção desejada_',
  '{"patient_name": "Nome do paciente", "clinic_name": "Nome da clínica"}',
  'greeting'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'greeting_returning',
  E'Olá {{patient_name}}! 👋\n\nQue bom ter você de volta!\n\nComo posso ajudar?\n\n1️⃣ Agendar nova consulta\n2️⃣ Ver meus agendamentos\n3️⃣ Reagendar consulta\n4️⃣ Falar com atendente\n\n_Digite o número da opção_',
  '{"patient_name": "Nome do paciente"}',
  'greeting'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Location and hours template
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'hours_location',
  E'📍 *Localização*\n{{address}}\n\n🕐 *Horário de Funcionamento*\n{{business_hours}}\n\n📞 *Telefone*\n{{phone}}\n\n🗺️ *Como chegar*\n{{maps_link}}',
  '{"address": "Endereço completo", "business_hours": "Horários", "phone": "Telefone", "maps_link": "Link do Google Maps"}',
  'info'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Service catalog template
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'service_catalog',
  E'📋 *Nossos Serviços*\n\n{{service_list}}\n\n_Digite o número do serviço para mais informações ou para agendar_',
  '{"service_list": "Lista de serviços formatada"}',
  'services'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'service_details',
  E'💉 *{{service_name}}*\n\n📝 {{description}}\n⏱️ Duração: {{duration}} minutos\n💰 Valor: R$ {{price}}\n\n👨‍⚕️ *Profissionais disponíveis:*\n{{professionals_list}}\n\n_Digite o número do profissional para ver horários disponíveis_',
  '{"service_name": "Nome", "description": "Descrição", "duration": "Duração", "price": "Preço", "professionals_list": "Lista de profissionais"}',
  'services'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Professional selection template
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'professional_list',
  E'👨‍⚕️ *Profissionais Disponíveis*\n\n{{professional_list}}\n\n_Digite o número do profissional desejado_',
  '{"professional_list": "Lista formatada de profissionais"}',
  'scheduling'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'professional_details',
  E'👨‍⚕️ *{{professional_name}}*\n{{specialty}}\n\n📅 *Próximos horários disponíveis:*\n{{available_slots}}\n\n_Digite o número do horário para confirmar_',
  '{"professional_name": "Nome", "specialty": "Especialidade", "available_slots": "Horários disponíveis"}',
  'scheduling'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Appointment confirmation templates
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'appointment_confirm_request',
  E'📋 *Confirme seu agendamento:*\n\n📅 *Data:* {{date}}\n🕐 *Horário:* {{time}}\n👨‍⚕️ *Profissional:* {{professional}}\n💉 *Serviço:* {{service}}\n💰 *Valor:* R$ {{price}}\n\n✅ Digite *SIM* para confirmar\n❌ Digite *NÃO* para cancelar\n🔙 Digite *VOLTAR* para escolher outro horário',
  '{"date": "Data", "time": "Horário", "professional": "Profissional", "service": "Serviço", "price": "Valor"}',
  'scheduling'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'appointment_confirmed',
  E'✅ *Agendamento Confirmado!*\n\n📅 *Data:* {{date}}\n🕐 *Horário:* {{time}}\n👨‍⚕️ *Profissional:* {{professional}}\n💉 *Serviço:* {{service}}\n💰 *Valor:* R$ {{price}}\n📍 *Local:* {{address}}\n\n⚠️ *Importante:*\n• Chegue com 10 minutos de antecedência\n• Traga documento com foto\n{{additional_instructions}}\n\nAguardamos você! 🙂',
  '{"date": "Data", "time": "Horário", "professional": "Profissional", "service": "Serviço", "price": "Valor", "address": "Endereço", "additional_instructions": "Instruções adicionais"}',
  'scheduling'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'appointment_cancelled',
  E'❌ *Agendamento Cancelado*\n\nSeu agendamento foi cancelado com sucesso.\n\nDeseja agendar uma nova consulta?\n\n1️⃣ Sim, agendar nova consulta\n2️⃣ Não, obrigado',
  '{}',
  'scheduling'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Reminder templates
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'reminder_24h',
  E'🔔 *Lembrete de Consulta*\n\nOlá {{patient_name}}!\n\nSua consulta está agendada para *amanhã*:\n\n📅 *Data:* {{date}}\n🕐 *Horário:* {{time}}\n👨‍⚕️ *Profissional:* {{professional}}\n📍 *Local:* {{address}}\n\n✅ Digite *CONFIRMAR* para confirmar presença\n❌ Digite *CANCELAR* para cancelar\n📅 Digite *REAGENDAR* para reagendar',
  '{"patient_name": "Nome", "date": "Data", "time": "Horário", "professional": "Profissional", "address": "Endereço"}',
  'reminders'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'reminder_1h',
  E'⏰ *Sua consulta é em 1 hora!*\n\nOlá {{patient_name}}!\n\n🕐 *Horário:* {{time}}\n👨‍⚕️ *Profissional:* {{professional}}\n📍 *Local:* {{address}}\n\nEstamos te esperando! 🙂',
  '{"patient_name": "Nome", "time": "Horário", "professional": "Profissional", "address": "Endereço"}',
  'reminders'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Error and fallback templates
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'invalid_option',
  E'❓ Desculpe, não entendi sua resposta.\n\nPor favor, digite apenas o *número* da opção desejada.\n\n{{available_options}}',
  '{"available_options": "Opções disponíveis"}',
  'error'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'no_slots_available',
  E'😔 Infelizmente não há horários disponíveis para {{professional}} nos próximos dias.\n\nDeseja:\n1️⃣ Ver outros profissionais\n2️⃣ Entrar na lista de espera\n3️⃣ Voltar ao menu principal',
  '{"professional": "Nome do profissional"}',
  'scheduling'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'escalate_human',
  E'👤 *Transferindo para atendente humano*\n\nAguarde um momento, em breve um de nossos atendentes irá te responder.\n\n_Horário de atendimento: {{business_hours}}_',
  '{"business_hours": "Horário de atendimento"}',
  'escalation'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'outside_hours',
  E'🌙 *Fora do horário de atendimento*\n\nNosso horário de atendimento é:\n{{business_hours}}\n\nMas você pode:\n1️⃣ Agendar uma consulta (sistema automático)\n2️⃣ Deixar uma mensagem para retornarmos\n\n_Digite o número da opção_',
  '{"business_hours": "Horário de atendimento"}',
  'info'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

-- Payment templates
INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'payment_pix',
  E'💰 *Pagamento via PIX*\n\n*Valor:* R$ {{amount}}\n\n*Chave PIX:*\n```{{pix_key}}```\n\n*Ou escaneie o QR Code:*\n_(O QR Code será enviado em seguida)_\n\nApós o pagamento, envie o comprovante aqui.',
  '{"amount": "Valor", "pix_key": "Chave PIX"}',
  'payment'
),
(
  (SELECT tenant_id FROM tenant_config LIMIT 1),
  'payment_received',
  E'✅ *Pagamento Confirmado!*\n\nRecebemos seu pagamento de R$ {{amount}}.\n\nSeu agendamento está confirmado!\n\nObrigado! 🙂',
  '{"amount": "Valor"}',
  'payment'
)
ON CONFLICT (tenant_id, template_key) DO NOTHING;

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
  -- Get template
  SELECT template_text INTO v_template
  FROM response_templates
  WHERE tenant_id = p_tenant_id 
    AND template_key = p_template_key
    AND is_active = true;
  
  IF v_template IS NULL THEN
    RETURN NULL;
  END IF;
  
  -- Replace variables
  FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_variables)
  LOOP
    v_template := REPLACE(v_template, '{{' || v_key || '}}', COALESCE(v_value, ''));
  END LOOP;
  
  RETURN v_template;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT ON response_templates TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_template_response TO PUBLIC;

COMMENT ON TABLE response_templates IS 'Pre-built response templates to reduce AI calls';
COMMENT ON FUNCTION get_template_response IS 'Retrieves a template and replaces variables with provided values';