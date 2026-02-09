-- ============================================================================
-- SEED: COMMON FAQ ENTRIES
-- Description: Pre-populate tenant_faq with responses for common intents
--              to avoid unnecessary AI calls from first interaction
-- ============================================================================

DO $$
DECLARE
    v_tenant_id UUID;
    v_clinic_name VARCHAR;
    v_address TEXT;
    v_hours_start TIME;
    v_hours_end TIME;
    v_days_display VARCHAR;
    v_phone VARCHAR;
BEGIN
    -- Seed for each active tenant
    FOR v_tenant_id, v_clinic_name, v_address, v_hours_start, v_hours_end, v_days_display, v_phone IN
        SELECT tenant_id, clinic_name, clinic_address, hours_start, hours_end, days_open_display, clinic_phone
        FROM tenant_config
        WHERE is_active = true
    LOOP
        RAISE NOTICE 'Seeding FAQs for tenant: %', v_clinic_name;

        -- Greeting FAQs (captures: oi, olá, bom dia, boa tarde, boa noite, hey, hello)
        INSERT INTO tenant_faq (tenant_id, question_original, question_normalized, answer, answer_type, keywords, intent, view_count)
        VALUES
        (v_tenant_id, 'oi', 'oi',
         E'Olá! 👋\n\nSeja bem-vindo(a) à *' || v_clinic_name || E'*!\n\nComo posso ajudar?\n\n1️⃣ Agendar consulta\n2️⃣ Reagendar\n3️⃣ Informações\n4️⃣ Horários e localização\n\n_Digite o número da opção desejada_',
         'text', ARRAY['oi', 'olá', 'ola', 'bom dia', 'boa tarde', 'boa noite', 'hey', 'hello'], 'greeting', 10),

        (v_tenant_id, 'olá', 'olá',
         E'Olá! 👋\n\nSeja bem-vindo(a) à *' || v_clinic_name || E'*!\n\nComo posso ajudar?\n\n1️⃣ Agendar consulta\n2️⃣ Reagendar\n3️⃣ Informações\n4️⃣ Horários e localização\n\n_Digite o número da opção desejada_',
         'text', ARRAY['olá', 'ola'], 'greeting', 5),

        (v_tenant_id, 'bom dia', 'bom dia',
         E'Bom dia! 👋\n\nSeja bem-vindo(a) à *' || v_clinic_name || E'*!\n\nComo posso ajudar?\n\n1️⃣ Agendar consulta\n2️⃣ Reagendar\n3️⃣ Informações\n4️⃣ Horários e localização\n\n_Digite o número da opção desejada_',
         'text', ARRAY['bom dia'], 'greeting', 5),

        -- Hours/Location FAQs
        (v_tenant_id, 'horário', 'horário',
         E'📍 *Localização*\n' || COALESCE(v_address, 'Endereço não informado') || E'\n\n🕐 *Horário de Funcionamento*\n' || v_hours_start::TEXT || ' às ' || v_hours_end::TEXT || ' (' || COALESCE(v_days_display, 'Segunda-Sábado') || E')\n\n📞 ' || COALESCE(v_phone, ''),
         'text', ARRAY['horário', 'horario', 'hora', 'abre', 'fecha', 'aberto', 'funciona'], 'hours', 5),

        (v_tenant_id, 'endereço', 'endereço',
         E'📍 *Localização*\n' || COALESCE(v_address, 'Endereço não informado') || E'\n\n🕐 *Horário de Funcionamento*\n' || v_hours_start::TEXT || ' às ' || v_hours_end::TEXT || ' (' || COALESCE(v_days_display, 'Segunda-Sábado') || ')',
         'text', ARRAY['endereço', 'endereco', 'onde', 'localização', 'localizacao', 'fica', 'chegar'], 'location', 5),

        -- Help FAQ
        (v_tenant_id, 'ajuda', 'ajuda',
         E'Posso ajudar com:\n\n1️⃣ Agendar consulta\n2️⃣ Reagendar\n3️⃣ Informações sobre serviços\n4️⃣ Horários e localização\n\n_Digite o número ou descreva o que precisa_',
         'text', ARRAY['ajuda', 'help', 'socorro', 'não entendi', 'nao entendi'], 'help', 5)

        ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

    END LOOP;

    RAISE NOTICE '✅ Common FAQ entries seeded successfully';
END $$;
