-- ============================================================================
-- SEED: CALENDARS
-- Description: Sample Google Calendar configuration for development professionals
-- Depends on: 02_tenant_dev.sql, 04_tenant_professionals.sql
-- ============================================================================

DO $$
DECLARE
    v_tenant_id UUID;
    v_prof_id UUID;
BEGIN
    -- Get the development tenant
    SELECT tenant_id INTO v_tenant_id
    FROM tenant_config
    WHERE evolution_instance_name = 'clinic_moreira_instance';

    IF v_tenant_id IS NULL THEN
        RAISE NOTICE 'Tenant not found. Run 02_tenant_dev.sql first.';
        RETURN;
    END IF;

    -- Create calendar entry for each professional
    FOR v_prof_id IN
        SELECT professional_id FROM professionals WHERE tenant_id = v_tenant_id
    LOOP
        INSERT INTO calendars (
            tenant_id,
            professional_id,
            google_calendar_id,
            google_calendar_label,
            credential_type,
            is_primary,
            calendar_type,
            timezone,
            is_active
        )
        SELECT
            v_tenant_id,
            p.professional_id,
            p.google_calendar_id,
            p.professional_name || ' - Agenda',
            'oauth_database',
            true,
            'appointments',
            'America/Sao_Paulo',
            true
        FROM professionals p
        WHERE p.professional_id = v_prof_id
          AND p.google_calendar_id IS NOT NULL
        ON CONFLICT (tenant_id, google_calendar_id) DO NOTHING;
    END LOOP;

    RAISE NOTICE 'Calendars seed complete for tenant %', v_tenant_id;
END $$;
