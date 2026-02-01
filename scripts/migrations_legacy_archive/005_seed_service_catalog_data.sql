-- ============================================================================
-- SEED SERVICE CATALOG DATA
-- Version: 2.0.0
-- Date: 2026-01-02
-- Description: Seeds sample data for multi-provider multi-service architecture
--              Includes the "Dr. José" example with Implant (2h) and Botox
-- ============================================================================

-- ============================================================================
-- 1. SEED GLOBAL SERVICES CATALOG
-- ============================================================================
-- These are the master service definitions. 
-- Professionals will customize duration and price via the junction table.

INSERT INTO services_catalog (
    service_code,
    service_name,
    service_category,
    service_keywords,
    service_description,
    default_duration_minutes,
    default_price_cents,
    requires_preparation,
    preparation_instructions,
    display_order
) VALUES
    -- Odontologia
    ('IMPLANT_DENTAL', 'Implante Dentário', 'Odontologia',
     ARRAY['implante', 'dente', 'prótese', 'dental', 'titânio', 'osseointegração'],
     'Procedimento cirúrgico para substituição de raiz dentária com implante de titânio',
     120, 500000, true, 'Jejum de 8 horas. Não tomar anti-inflamatórios 48h antes.',
     1),
    
    ('CANAL_ROOT', 'Tratamento de Canal', 'Odontologia',
     ARRAY['canal', 'endodontia', 'raiz', 'dor de dente'],
     'Tratamento endodôntico para remoção de polpa infectada',
     90, 150000, false, NULL,
     2),
    
    ('CLEANING_DENTAL', 'Limpeza Dentária', 'Odontologia',
     ARRAY['limpeza', 'profilaxia', 'tártaro', 'placa'],
     'Limpeza profissional e remoção de tártaro',
     45, 25000, false, NULL,
     3),
    
    ('WHITENING', 'Clareamento Dental', 'Odontologia',
     ARRAY['clareamento', 'branqueamento', 'dente branco', 'estética dental'],
     'Clareamento dental a laser ou com moldeira',
     60, 80000, false, NULL,
     4),
    
    -- Estética
    ('BOTOX_FACIAL', 'Aplicação de Botox', 'Estética',
     ARRAY['botox', 'toxina botulínica', 'rugas', 'expressão', 'testa', 'pés de galinha'],
     'Aplicação de toxina botulínica para redução de rugas de expressão',
     60, 80000, false, NULL,
     10),
    
    ('FILLER_FACIAL', 'Preenchimento Facial', 'Estética',
     ARRAY['preenchimento', 'ácido hialurônico', 'volume', 'lábios', 'bigode chinês'],
     'Preenchimento com ácido hialurônico para volumização facial',
     90, 150000, false, NULL,
     11),
    
    ('PEELING', 'Peeling Químico', 'Estética',
     ARRAY['peeling', 'manchas', 'melasma', 'acne', 'rejuvenescimento'],
     'Tratamento químico para renovação da pele',
     45, 35000, false, NULL,
     12),
    
    -- Cardiologia
    ('CONSULT_CARDIO', 'Consulta Cardiológica', 'Cardiologia',
     ARRAY['consulta', 'cardiologia', 'coração', 'pressão', 'cardiovascular'],
     'Consulta de avaliação cardiovascular completa',
     45, 35000, false, NULL,
     20),
    
    ('ECG', 'Eletrocardiograma', 'Cardiologia',
     ARRAY['ecg', 'eletro', 'eletrocardiograma', 'exame cardíaco'],
     'Exame de atividade elétrica do coração',
     30, 15000, false, NULL,
     21),
    
    ('STRESS_TEST', 'Teste Ergométrico', 'Cardiologia',
     ARRAY['teste ergométrico', 'esteira', 'esforço', 'coração'],
     'Teste de esforço cardiovascular na esteira',
     60, 40000, true, 'Trazer roupa confortável e tênis. Evitar café 4h antes.',
     22),
    
    -- Clínico Geral
    ('CONSULT_GENERAL', 'Consulta Clínica Geral', 'Clínico Geral',
     ARRAY['consulta', 'clínico', 'geral', 'médico', 'atendimento'],
     'Consulta médica de clínica geral',
     30, 20000, false, NULL,
     30),
    
    ('CHECKUP', 'Check-up Completo', 'Clínico Geral',
     ARRAY['checkup', 'check-up', 'exames', 'rotina', 'saúde'],
     'Avaliação completa de saúde com solicitação de exames',
     60, 45000, false, NULL,
     31)

ON CONFLICT (service_code) DO UPDATE SET
    service_name = EXCLUDED.service_name,
    service_keywords = EXCLUDED.service_keywords,
    updated_at = NOW();

-- ============================================================================
-- 2. SEED PROFESSIONALS FOR THE CLINIC
-- ============================================================================

DO $$
DECLARE
    v_tenant_id UUID;
    v_dr_jose_id UUID;
    v_dra_maria_id UUID;
    v_dr_carlos_id UUID;
    
    -- Service IDs
    v_implant_id UUID;
    v_canal_id UUID;
    v_cleaning_id UUID;
    v_whitening_id UUID;
    v_botox_id UUID;
    v_filler_id UUID;
    v_peeling_id UUID;
    v_cardio_consult_id UUID;
    v_ecg_id UUID;
    v_stress_id UUID;
    v_general_consult_id UUID;
    v_checkup_id UUID;
BEGIN
    -- Get tenant ID (assumes clinic_moreira_instance exists from previous migration)
    SELECT tenant_id INTO v_tenant_id 
    FROM tenant_config 
    WHERE evolution_instance_name = 'clinic_moreira_instance';
    
    IF v_tenant_id IS NULL THEN
        -- Create a default tenant if not exists
        INSERT INTO tenant_config (
            tenant_name, tenant_slug, evolution_instance_name, clinic_name,
            system_prompt_patient, system_prompt_internal, system_prompt_confirmation
        ) VALUES (
            'Clínica Moreira', 'clinica-moreira', 'clinic_moreira_instance', 'Clínica Moreira',
            'Sistema prompt paciente', 'Sistema prompt interno', 'Sistema prompt confirmação'
        )
        RETURNING tenant_id INTO v_tenant_id;
    END IF;
    
    RAISE NOTICE '✅ Using tenant: %', v_tenant_id;
    
    -- Get service IDs
    SELECT service_id INTO v_implant_id FROM services_catalog WHERE service_code = 'IMPLANT_DENTAL';
    SELECT service_id INTO v_canal_id FROM services_catalog WHERE service_code = 'CANAL_ROOT';
    SELECT service_id INTO v_cleaning_id FROM services_catalog WHERE service_code = 'CLEANING_DENTAL';
    SELECT service_id INTO v_whitening_id FROM services_catalog WHERE service_code = 'WHITENING';
    SELECT service_id INTO v_botox_id FROM services_catalog WHERE service_code = 'BOTOX_FACIAL';
    SELECT service_id INTO v_filler_id FROM services_catalog WHERE service_code = 'FILLER_FACIAL';
    SELECT service_id INTO v_peeling_id FROM services_catalog WHERE service_code = 'PEELING';
    SELECT service_id INTO v_cardio_consult_id FROM services_catalog WHERE service_code = 'CONSULT_CARDIO';
    SELECT service_id INTO v_ecg_id FROM services_catalog WHERE service_code = 'ECG';
    SELECT service_id INTO v_stress_id FROM services_catalog WHERE service_code = 'STRESS_TEST';
    SELECT service_id INTO v_general_consult_id FROM services_catalog WHERE service_code = 'CONSULT_GENERAL';
    SELECT service_id INTO v_checkup_id FROM services_catalog WHERE service_code = 'CHECKUP';

    -- ========================================================================
    -- DR. JOSÉ - DENTISTA (The main example)
    -- Services: Implante (2h, R$ 5k), Botox (1.5h, R$ 500), Canal, Limpeza
    -- ========================================================================
    
    INSERT INTO professionals (
        tenant_id, professional_name, professional_slug, professional_title,
        specialty, specialty_keywords, professional_bio, professional_crm,
        google_calendar_id, google_calendar_label, google_calendar_color,
        working_hours_start, working_hours_end, working_days,
        slot_interval_minutes, buffer_between_appointments,
        display_order
    ) VALUES (
        v_tenant_id,
        'José Silva',
        'dr-jose-silva',
        'Dr.',
        'Dentista - Implantodontista',
        ARRAY['dentista', 'odontologia', 'implante', 'dente', 'cirurgião dentista'],
        'Especialista em Implantodontia com 15 anos de experiência. Também realiza procedimentos estéticos faciais.',
        'CRO-MG 12345',
        'dr-jose-agenda@group.calendar.google.com',  -- UPDATE WITH REAL ID
        'Agenda Dr. José',
        '#4285f4',  -- Blue
        '08:00', '18:00',
        '["1","2","3","4","5"]'::jsonb,  -- Mon-Fri
        30,  -- 30 min slot granularity
        15,  -- 15 min buffer between appointments
        1
    )
    ON CONFLICT (tenant_id, professional_slug) DO UPDATE SET
        specialty_keywords = EXCLUDED.specialty_keywords,
        professional_bio = EXCLUDED.professional_bio,
        updated_at = NOW()
    RETURNING professional_id INTO v_dr_jose_id;
    
    RAISE NOTICE '✅ Created: Dr. José (ID: %)', v_dr_jose_id;
    
    -- Dr. José's Services with CUSTOM duration and price
    INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
    VALUES
        -- IMPLANTE: 2 HORAS (120 min), R$ 5.000,00
        (v_dr_jose_id, v_implant_id, 120, 500000, 'R$ 5.000,00'),
        
        -- BOTOX: 1.5 HORAS (90 min), R$ 500,00
        (v_dr_jose_id, v_botox_id, 90, 50000, 'R$ 500,00'),
        
        -- CANAL: 90 min, R$ 1.500,00
        (v_dr_jose_id, v_canal_id, 90, 150000, 'R$ 1.500,00'),
        
        -- LIMPEZA: 45 min, R$ 250,00
        (v_dr_jose_id, v_cleaning_id, 45, 25000, 'R$ 250,00'),
        
        -- CLAREAMENTO: 60 min, R$ 800,00
        (v_dr_jose_id, v_whitening_id, 60, 80000, 'R$ 800,00')
    ON CONFLICT (professional_id, service_id) DO UPDATE SET
        custom_duration_minutes = EXCLUDED.custom_duration_minutes,
        custom_price_cents = EXCLUDED.custom_price_cents,
        price_display = EXCLUDED.price_display,
        updated_at = NOW();
    
    RAISE NOTICE '✅ Dr. José services: Implante (120min), Botox (90min), Canal, Limpeza, Clareamento';

    -- ========================================================================
    -- DRA. MARIA - DERMATOLOGISTA / ESTÉTICA
    -- Services: Botox (1h, R$ 600), Preenchimento, Peeling
    -- Note: Her Botox is FASTER (60min vs Dr. José's 90min) but more expensive
    -- ========================================================================
    
    INSERT INTO professionals (
        tenant_id, professional_name, professional_slug, professional_title,
        specialty, specialty_keywords, professional_bio, professional_crm,
        google_calendar_id, google_calendar_label, google_calendar_color,
        working_hours_start, working_hours_end, working_days,
        slot_interval_minutes, buffer_between_appointments,
        display_order
    ) VALUES (
        v_tenant_id,
        'Maria Costa',
        'dra-maria-costa',
        'Dra.',
        'Dermatologista - Estética',
        ARRAY['dermatologista', 'dermatologia', 'pele', 'estética', 'botox', 'preenchimento'],
        'Dermatologista especializada em procedimentos estéticos minimamente invasivos.',
        'CRM-MG 54321',
        'dra-maria-agenda@group.calendar.google.com',  -- UPDATE WITH REAL ID
        'Agenda Dra. Maria',
        '#ea4335',  -- Red
        '09:00', '19:00',
        '["1","2","3","4","5","6"]'::jsonb,  -- Mon-Sat
        30,
        10,
        2
    )
    ON CONFLICT (tenant_id, professional_slug) DO UPDATE SET
        specialty_keywords = EXCLUDED.specialty_keywords,
        updated_at = NOW()
    RETURNING professional_id INTO v_dra_maria_id;
    
    RAISE NOTICE '✅ Created: Dra. Maria (ID: %)', v_dra_maria_id;
    
    -- Dra. Maria's Services - NOTE: Different duration/price for Botox!
    INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
    VALUES
        -- BOTOX: 1 HORA (60 min), R$ 600,00 (faster but more expensive than Dr. José!)
        (v_dra_maria_id, v_botox_id, 60, 60000, 'R$ 600,00'),
        
        -- PREENCHIMENTO: 90 min, R$ 1.500,00
        (v_dra_maria_id, v_filler_id, 90, 150000, 'R$ 1.500,00'),
        
        -- PEELING: 45 min, R$ 350,00
        (v_dra_maria_id, v_peeling_id, 45, 35000, 'R$ 350,00')
    ON CONFLICT (professional_id, service_id) DO UPDATE SET
        custom_duration_minutes = EXCLUDED.custom_duration_minutes,
        custom_price_cents = EXCLUDED.custom_price_cents,
        price_display = EXCLUDED.price_display,
        updated_at = NOW();
    
    RAISE NOTICE '✅ Dra. Maria services: Botox (60min), Preenchimento, Peeling';

    -- ========================================================================
    -- DR. CARLOS - CARDIOLOGISTA
    -- Services: Consulta Cardiológica, ECG, Teste Ergométrico
    -- ========================================================================
    
    INSERT INTO professionals (
        tenant_id, professional_name, professional_slug, professional_title,
        specialty, specialty_keywords, professional_bio, professional_crm,
        google_calendar_id, google_calendar_label, google_calendar_color,
        working_hours_start, working_hours_end, working_days,
        slot_interval_minutes, buffer_between_appointments,
        display_order
    ) VALUES (
        v_tenant_id,
        'Carlos Oliveira',
        'dr-carlos-oliveira',
        'Dr.',
        'Cardiologista',
        ARRAY['cardiologista', 'cardiologia', 'coração', 'pressão', 'cardiovascular'],
        'Cardiologista com especialização em ergometria e medicina preventiva.',
        'CRM-MG 67890',
        'dr-carlos-agenda@group.calendar.google.com',  -- UPDATE WITH REAL ID
        'Agenda Dr. Carlos',
        '#34a853',  -- Green
        '07:00', '16:00',
        '["1","2","3","4","5"]'::jsonb,  -- Mon-Fri
        30,
        10,
        3
    )
    ON CONFLICT (tenant_id, professional_slug) DO UPDATE SET
        specialty_keywords = EXCLUDED.specialty_keywords,
        updated_at = NOW()
    RETURNING professional_id INTO v_dr_carlos_id;
    
    RAISE NOTICE '✅ Created: Dr. Carlos (ID: %)', v_dr_carlos_id;
    
    -- Dr. Carlos's Services
    INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
    VALUES
        -- CONSULTA: 45 min, R$ 350,00
        (v_dr_carlos_id, v_cardio_consult_id, 45, 35000, 'R$ 350,00'),
        
        -- ECG: 30 min, R$ 150,00
        (v_dr_carlos_id, v_ecg_id, 30, 15000, 'R$ 150,00'),
        
        -- TESTE ERGOMÉTRICO: 60 min, R$ 400,00
        (v_dr_carlos_id, v_stress_id, 60, 40000, 'R$ 400,00'),
        
        -- CHECK-UP: 90 min, R$ 600,00 (combo consulta + exames)
        (v_dr_carlos_id, v_checkup_id, 90, 60000, 'R$ 600,00')
    ON CONFLICT (professional_id, service_id) DO UPDATE SET
        custom_duration_minutes = EXCLUDED.custom_duration_minutes,
        custom_price_cents = EXCLUDED.custom_price_cents,
        price_display = EXCLUDED.price_display,
        updated_at = NOW();
    
    RAISE NOTICE '✅ Dr. Carlos services: Consulta (45min), ECG (30min), Teste Ergométrico (60min)';
    
END $$;

-- ============================================================================
-- 3. VERIFY DATA
-- ============================================================================

-- Show the comparison: Same service (Botox), different professionals
SELECT 
    '═══ BOTOX COMPARISON ═══' as section;
    
SELECT 
    p.professional_name,
    sc.service_name,
    ps.custom_duration_minutes as duration_min,
    ps.price_display
FROM professional_services ps
JOIN professionals p ON ps.professional_id = p.professional_id
JOIN services_catalog sc ON ps.service_id = sc.service_id
WHERE sc.service_code = 'BOTOX_FACIAL'
ORDER BY p.display_order;

-- Show Dr. José's services (the main example)
SELECT 
    '═══ DR. JOSÉ SERVICES ═══' as section;
    
SELECT 
    sc.service_name,
    ps.custom_duration_minutes as duration_min,
    ps.price_display
FROM professional_services ps
JOIN professionals p ON ps.professional_id = p.professional_id
JOIN services_catalog sc ON ps.service_id = sc.service_id
WHERE p.professional_slug = 'dr-jose-silva'
ORDER BY sc.display_order;

-- Test the find_professionals_for_service function
SELECT 
    '═══ FIND PROFESSIONALS FOR "implante" ═══' as section;

SELECT 
    professional_name,
    service_name,
    duration_minutes,
    price_cents / 100.0 as price_reais,
    match_score
FROM find_professionals_for_service(
    (SELECT tenant_id FROM tenant_config WHERE evolution_instance_name = 'clinic_moreira_instance'),
    'implante'
);

-- Test slot validation
SELECT 
    '═══ SLOT VALIDATION TEST ═══' as section;

-- Test: Can a 1-hour slot fit an Implant (2h)?
SELECT 
    'Testing 1h slot for Implant (needs 2h)' as test,
    (validate_slot_for_service(
        NOW(),
        NOW() + interval '1 hour',
        (SELECT professional_id FROM professionals WHERE professional_slug = 'dr-jose-silva'),
        (SELECT service_id FROM services_catalog WHERE service_code = 'IMPLANT_DENTAL')
    )).*;

-- Test: Can a 3-hour slot fit an Implant (2h)?
SELECT 
    'Testing 3h slot for Implant (needs 2h)' as test,
    (validate_slot_for_service(
        NOW(),
        NOW() + interval '3 hours',
        (SELECT professional_id FROM professionals WHERE professional_slug = 'dr-jose-silva'),
        (SELECT service_id FROM services_catalog WHERE service_code = 'IMPLANT_DENTAL')
    )).*;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ SEED DATA COMPLETE';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: The "Dr. José" example is now configured:';
    RAISE NOTICE '  • Implante Dentário: 120 min (2h), R$ 5.000,00';
    RAISE NOTICE '  • Botox: 90 min (1.5h), R$ 500,00';
    RAISE NOTICE '';
    RAISE NOTICE 'Compare with Dra. Maria''s Botox:';
    RAISE NOTICE '  • Botox: 60 min (1h), R$ 600,00';
    RAISE NOTICE '';
    RAISE NOTICE 'The AI must use custom_duration_minutes for slot calculation!';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;

