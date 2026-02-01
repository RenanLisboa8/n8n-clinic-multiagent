-- ============================================================================
-- SEED: RESPONSE TEMPLATES
-- Description: Pre-built response templates per tenant
-- ============================================================================

DO $$
DECLARE
    v_tenant_id UUID;
BEGIN
    SELECT tenant_id INTO v_tenant_id 
    FROM tenant_config 
    WHERE evolution_instance_name = 'clinic_moreira_instance';
    
    IF v_tenant_id IS NULL THEN
        RAISE NOTICE 'Tenant not found. Run 02_tenant_dev.sql first.';
        RETURN;
    END IF;

    -- Greeting templates
    INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
    (v_tenant_id, 'greeting_new',
     E'Olá {{patient_name}}! 👋\n\nSeja bem-vindo(a) à *{{clinic_name}}*!\n\nComo posso ajudar?\n\n1️⃣ Agendar consulta\n2️⃣ Reagendar\n3️⃣ Cancelar\n4️⃣ Serviços\n5️⃣ Horários e localização\n\n_Digite o número_',
     '{"patient_name": "Nome", "clinic_name": "Clínica"}', 'greeting'),
    (v_tenant_id, 'greeting_returning',
     E'Olá {{patient_name}}! 👋\n\nQue bom ter você de volta!\n\n1️⃣ Agendar nova consulta\n2️⃣ Ver agendamentos\n3️⃣ Reagendar\n4️⃣ Falar com atendente',
     '{"patient_name": "Nome"}', 'greeting')
    ON CONFLICT (tenant_id, template_key) DO NOTHING;

    -- Info templates
    INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
    (v_tenant_id, 'hours_location',
     E'📍 *Localização*\n{{address}}\n\n🕐 *Horário*\n{{business_hours}}\n\n📞 {{phone}}',
     '{"address": "Endereço", "business_hours": "Horários", "phone": "Telefone"}', 'info'),
    (v_tenant_id, 'service_catalog',
     E'📋 *Nossos Serviços*\n\n{{service_list}}\n\n_Digite o número para mais informações_',
     '{"service_list": "Lista"}', 'services'),
    (v_tenant_id, 'service_details',
     E'💉 *{{service_name}}*\n\n📝 {{description}}\n⏱️ {{duration}} min\n💰 {{price}}\n\n👨‍⚕️ *Profissionais:*\n{{professionals_list}}',
     '{"service_name": "Nome", "description": "Descrição", "duration": "Duração", "price": "Preço", "professionals_list": "Lista"}', 'services')
    ON CONFLICT (tenant_id, template_key) DO NOTHING;

    -- Scheduling templates
    INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
    (v_tenant_id, 'professional_list',
     E'👨‍⚕️ *Profissionais*\n\n{{professional_list}}\n\n_Digite o número_',
     '{"professional_list": "Lista"}', 'scheduling'),
    (v_tenant_id, 'professional_details',
     E'👨‍⚕️ *{{professional_name}}*\n{{specialty}}\n\n📅 *Horários:*\n{{available_slots}}\n\n_Digite o número_',
     '{"professional_name": "Nome", "specialty": "Especialidade", "available_slots": "Horários"}', 'scheduling'),
    (v_tenant_id, 'appointment_confirm_request',
     E'📋 *Confirme seu agendamento:*\n\n📅 {{date}}\n🕐 {{time}}\n👨‍⚕️ {{professional}}\n💉 {{service}}\n💰 {{price}}\n\n✅ SIM | ❌ NÃO | 🔙 VOLTAR',
     '{"date": "Data", "time": "Horário", "professional": "Profissional", "service": "Serviço", "price": "Valor"}', 'scheduling'),
    (v_tenant_id, 'appointment_confirmed',
     E'✅ *Agendamento Confirmado!*\n\n📅 {{date}} às {{time}}\n👨‍⚕️ {{professional}}\n💉 {{service}}\n📍 {{address}}\n\n⚠️ Chegue 10 min antes.',
     '{"date": "Data", "time": "Horário", "professional": "Profissional", "service": "Serviço", "address": "Endereço"}', 'scheduling'),
    (v_tenant_id, 'appointment_cancelled',
     E'❌ *Agendamento Cancelado*\n\nDeseja agendar novamente?\n\n1️⃣ Sim\n2️⃣ Não',
     '{}', 'scheduling')
    ON CONFLICT (tenant_id, template_key) DO NOTHING;

    -- Reminder templates
    INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
    (v_tenant_id, 'reminder_24h',
     E'🔔 *Lembrete*\n\nSua consulta é *amanhã*:\n\n📅 {{date}} às {{time}}\n👨‍⚕️ {{professional}}\n📍 {{address}}\n\n✅ CONFIRMAR | ❌ CANCELAR | 📅 REAGENDAR',
     '{"date": "Data", "time": "Horário", "professional": "Profissional", "address": "Endereço"}', 'reminders'),
    (v_tenant_id, 'reminder_1h',
     E'⏰ *Sua consulta é em 1 hora!*\n\n🕐 {{time}}\n👨‍⚕️ {{professional}}\n📍 {{address}}\n\nAguardamos você! 🙂',
     '{"time": "Horário", "professional": "Profissional", "address": "Endereço"}', 'reminders')
    ON CONFLICT (tenant_id, template_key) DO NOTHING;

    -- Error templates
    INSERT INTO response_templates (tenant_id, template_key, template_text, variables, category) VALUES
    (v_tenant_id, 'invalid_option',
     E'❓ Não entendi. Digite o *número* da opção.\n\n{{available_options}}',
     '{"available_options": "Opções"}', 'error'),
    (v_tenant_id, 'no_slots_available',
     E'😔 Sem horários para {{professional}}.\n\n1️⃣ Ver outros profissionais\n2️⃣ Lista de espera\n3️⃣ Menu principal',
     '{"professional": "Profissional"}', 'scheduling'),
    (v_tenant_id, 'escalate_human',
     E'👤 *Transferindo para atendente*\n\nAguarde, em breve você será atendido.\n\n_Horário: {{business_hours}}_',
     '{"business_hours": "Horário"}', 'escalation'),
    (v_tenant_id, 'outside_hours',
     E'🌙 *Fora do horário*\n\nAtendimento: {{business_hours}}\n\n1️⃣ Agendar (automático)\n2️⃣ Deixar mensagem',
     '{"business_hours": "Horário"}', 'info')
    ON CONFLICT (tenant_id, template_key) DO NOTHING;

    RAISE NOTICE '✅ Response templates seeded successfully';
END $$;