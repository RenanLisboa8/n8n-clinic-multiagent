-- ============================================================================
-- SEED: TENANT PROFESSIONALS
-- Description: Sample professionals and their services for development tenant
-- ============================================================================

DO $$
DECLARE
    v_tenant_id UUID;
    v_dr_jose_id UUID;
    v_dra_maria_id UUID;
    v_dr_carlos_id UUID;
BEGIN
    -- Get the development tenant
    SELECT tenant_id INTO v_tenant_id 
    FROM tenant_config 
    WHERE evolution_instance_name = 'clinic_moreira_instance';
    
    IF v_tenant_id IS NULL THEN
        RAISE NOTICE 'Tenant not found. Run 02_tenant_dev.sql first.';
        RETURN;
    END IF;

    -- ========================================================================
    -- DR. JOSÉ - DENTISTA
    -- ========================================================================
    INSERT INTO professionals (
        tenant_id, professional_name, professional_slug, professional_title,
        specialty, specialty_keywords, professional_bio, professional_crm,
        google_calendar_id, google_calendar_label, google_calendar_color,
        working_hours_start, working_hours_end, working_days,
        slot_interval_minutes, buffer_between_appointments, display_order
    ) VALUES (
        v_tenant_id, 'José Silva', 'dr-jose-silva', 'Dr.',
        'Dentista - Implantodontista',
        ARRAY['dentista', 'odontologia', 'implante', 'dente'],
        'Especialista em Implantodontia com 15 anos de experiência.',
        'CRO-MG 12345',
        'dr-jose-agenda@group.calendar.google.com', 'Agenda Dr. José', '#4285f4',
        '08:00', '18:00', '["1","2","3","4","5"]'::jsonb,
        30, 15, 1
    )
    ON CONFLICT (tenant_id, professional_slug) DO UPDATE SET updated_at = NOW()
    RETURNING professional_id INTO v_dr_jose_id;

    -- Dr. José's Services
    INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
    SELECT v_dr_jose_id, service_id, duration, price, display FROM (VALUES
        ('IMPLANT_DENTAL', 120, 500000, 'R$ 5.000,00'),
        ('BOTOX_FACIAL', 90, 50000, 'R$ 500,00'),
        ('CANAL_ROOT', 90, 150000, 'R$ 1.500,00'),
        ('CLEANING_DENTAL', 45, 25000, 'R$ 250,00'),
        ('WHITENING', 60, 80000, 'R$ 800,00')
    ) AS t(code, duration, price, display)
    JOIN services_catalog sc ON sc.service_code = t.code
    ON CONFLICT (professional_id, service_id) DO UPDATE SET
        custom_duration_minutes = EXCLUDED.custom_duration_minutes,
        custom_price_cents = EXCLUDED.custom_price_cents,
        price_display = EXCLUDED.price_display,
        updated_at = NOW();

    -- ========================================================================
    -- DRA. MARIA - DERMATOLOGISTA / ESTÉTICA
    -- ========================================================================
    INSERT INTO professionals (
        tenant_id, professional_name, professional_slug, professional_title,
        specialty, specialty_keywords, professional_bio, professional_crm,
        google_calendar_id, google_calendar_label, google_calendar_color,
        working_hours_start, working_hours_end, working_days,
        slot_interval_minutes, buffer_between_appointments, display_order
    ) VALUES (
        v_tenant_id, 'Maria Costa', 'dra-maria-costa', 'Dra.',
        'Dermatologista - Estética',
        ARRAY['dermatologista', 'dermatologia', 'pele', 'estética', 'botox'],
        'Dermatologista especializada em procedimentos estéticos.',
        'CRM-MG 54321',
        'dra-maria-agenda@group.calendar.google.com', 'Agenda Dra. Maria', '#ea4335',
        '09:00', '19:00', '["1","2","3","4","5","6"]'::jsonb,
        30, 10, 2
    )
    ON CONFLICT (tenant_id, professional_slug) DO UPDATE SET updated_at = NOW()
    RETURNING professional_id INTO v_dra_maria_id;

    -- Dra. Maria's Services
    INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
    SELECT v_dra_maria_id, service_id, duration, price, display FROM (VALUES
        ('BOTOX_FACIAL', 60, 60000, 'R$ 600,00'),
        ('FILLER_FACIAL', 90, 150000, 'R$ 1.500,00'),
        ('PEELING', 45, 35000, 'R$ 350,00')
    ) AS t(code, duration, price, display)
    JOIN services_catalog sc ON sc.service_code = t.code
    ON CONFLICT (professional_id, service_id) DO UPDATE SET
        custom_duration_minutes = EXCLUDED.custom_duration_minutes,
        custom_price_cents = EXCLUDED.custom_price_cents,
        price_display = EXCLUDED.price_display,
        updated_at = NOW();

    -- ========================================================================
    -- DR. CARLOS - CARDIOLOGISTA
    -- ========================================================================
    INSERT INTO professionals (
        tenant_id, professional_name, professional_slug, professional_title,
        specialty, specialty_keywords, professional_bio, professional_crm,
        google_calendar_id, google_calendar_label, google_calendar_color,
        working_hours_start, working_hours_end, working_days,
        slot_interval_minutes, buffer_between_appointments, display_order
    ) VALUES (
        v_tenant_id, 'Carlos Oliveira', 'dr-carlos-oliveira', 'Dr.',
        'Cardiologista',
        ARRAY['cardiologista', 'cardiologia', 'coração', 'pressão'],
        'Cardiologista com especialização em ergometria.',
        'CRM-MG 67890',
        'dr-carlos-agenda@group.calendar.google.com', 'Agenda Dr. Carlos', '#34a853',
        '07:00', '16:00', '["1","2","3","4","5"]'::jsonb,
        30, 10, 3
    )
    ON CONFLICT (tenant_id, professional_slug) DO UPDATE SET updated_at = NOW()
    RETURNING professional_id INTO v_dr_carlos_id;

    -- Dr. Carlos's Services
    INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
    SELECT v_dr_carlos_id, service_id, duration, price, display FROM (VALUES
        ('CONSULT_CARDIO', 45, 35000, 'R$ 350,00'),
        ('ECG', 30, 15000, 'R$ 150,00'),
        ('STRESS_TEST', 60, 40000, 'R$ 400,00'),
        ('CHECKUP', 90, 60000, 'R$ 600,00')
    ) AS t(code, duration, price, display)
    JOIN services_catalog sc ON sc.service_code = t.code
    ON CONFLICT (professional_id, service_id) DO UPDATE SET
        custom_duration_minutes = EXCLUDED.custom_duration_minutes,
        custom_price_cents = EXCLUDED.custom_price_cents,
        price_display = EXCLUDED.price_display,
        updated_at = NOW();

    RAISE NOTICE '✅ Professionals seeded: Dr. José, Dra. Maria, Dr. Carlos';
END $$;