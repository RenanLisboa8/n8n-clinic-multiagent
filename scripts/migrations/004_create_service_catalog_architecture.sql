-- ============================================================================
-- MULTI-PROVIDER & MULTI-SERVICE ARCHITECTURE
-- Version: 2.0.0 (Definitive)
-- Date: 2026-01-02
-- Description: Robust relational schema for professional-specific service pricing
--              and duration with slot calculation support
-- ============================================================================
-- 
-- ARCHITECTURE OVERVIEW:
--
--   ┌─────────────────────┐         ┌─────────────────────────┐
--   │   tenant_config     │         │    services_catalog     │
--   │   (Clinic Config)   │         │   (Global Services)     │
--   └─────────┬───────────┘         └───────────┬─────────────┘
--             │ 1:N                              │
--             ▼                                  │
--   ┌─────────────────────┐                     │
--   │    professionals    │                     │
--   │  (Doctors/Staff)    │                     │
--   └─────────┬───────────┘                     │
--             │                                  │
--             │         N:M (Junction)          │
--             └──────────────┬──────────────────┘
--                            ▼
--              ┌─────────────────────────────┐
--              │   professional_services     │
--              │ (Custom Duration & Price)   │
--              └─────────────────────────────┘
--
-- ============================================================================

-- ============================================================================
-- 1. CREATE SERVICES_CATALOG TABLE (Global Service Definitions)
-- ============================================================================
-- This is the master list of all services offered by any clinic.
-- Individual clinics/professionals can customize duration and price.

CREATE TABLE IF NOT EXISTS services_catalog (
    -- Primary Key
    service_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Service Identity
    service_code VARCHAR(50) NOT NULL UNIQUE,      -- Machine-readable: 'IMPLANT_DENTAL', 'BOTOX_FACIAL'
    service_name VARCHAR(200) NOT NULL,            -- Human-readable: 'Implante Dentário'
    service_category VARCHAR(100) NOT NULL,        -- Category: 'Odontologia', 'Estética', 'Cardiologia'
    
    -- Search & AI Matching
    service_keywords TEXT[] NOT NULL DEFAULT '{}', -- Keywords for AI matching: ['implante', 'dente', 'prótese']
    service_description TEXT,                      -- Detailed description for AI context
    
    -- Default Values (can be overridden per professional)
    default_duration_minutes INTEGER NOT NULL DEFAULT 30,
    default_price_cents INTEGER NOT NULL DEFAULT 0,
    
    -- Requirements & Constraints
    requires_preparation BOOLEAN DEFAULT false,     -- Patient needs to prepare? (fasting, etc.)
    preparation_instructions TEXT,                  -- Instructions if requires_preparation = true
    min_interval_days INTEGER DEFAULT 0,            -- Minimum days between same service
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    display_order INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE services_catalog IS 'Global catalog of all services - professionals customize via junction table';
COMMENT ON COLUMN services_catalog.service_code IS 'Unique machine-readable code for programmatic access';
COMMENT ON COLUMN services_catalog.default_duration_minutes IS 'Default duration - professionals can override';
COMMENT ON COLUMN services_catalog.default_price_cents IS 'Default price in cents - professionals can override';

-- ============================================================================
-- 2. CREATE PROFESSIONALS TABLE (Clinic Staff)
-- ============================================================================
-- Each professional belongs to a tenant and has their own Google Calendar

CREATE TABLE IF NOT EXISTS professionals (
    -- Primary Key
    professional_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Key to Tenant
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    -- Professional Identity
    professional_name VARCHAR(200) NOT NULL,
    professional_slug VARCHAR(100) NOT NULL,         -- URL-safe: 'dr-jose-silva'
    professional_title VARCHAR(50),                  -- 'Dr.', 'Dra.', 'Psic.', etc.
    specialty VARCHAR(200) NOT NULL,                 -- Primary specialty
    specialty_keywords TEXT[] DEFAULT '{}',          -- For AI matching: ['dentista', 'odontologia']
    
    -- Professional Details
    professional_bio TEXT,                           -- Short bio for patient info
    professional_crm VARCHAR(50),                    -- Professional registration number
    professional_photo_url TEXT,                     -- Profile photo URL
    
    -- Google Calendar Configuration (INDIVIDUAL)
    google_calendar_id VARCHAR(255) NOT NULL,        -- Each professional has their own calendar
    google_calendar_label VARCHAR(100),              -- Display name: 'Agenda Dr. José'
    google_calendar_color VARCHAR(20) DEFAULT '#4285f4',
    
    -- Working Schedule (Default)
    working_hours_start TIME NOT NULL DEFAULT '08:00',
    working_hours_end TIME NOT NULL DEFAULT '18:00',
    working_days JSONB NOT NULL DEFAULT '["1","2","3","4","5"]'::jsonb,  -- Mon-Fri
    lunch_break_start TIME DEFAULT '12:00',
    lunch_break_end TIME DEFAULT '13:00',
    
    -- Scheduling Rules
    slot_interval_minutes INTEGER NOT NULL DEFAULT 30,   -- Minimum slot granularity
    buffer_between_appointments INTEGER DEFAULT 10,       -- Minutes between appointments
    max_daily_appointments INTEGER,                       -- NULL = unlimited
    advance_booking_days INTEGER DEFAULT 60,              -- How far ahead can book
    min_notice_hours INTEGER DEFAULT 2,                   -- Minimum hours notice for booking
    
    -- Contact
    professional_phone VARCHAR(20),
    professional_email VARCHAR(100),
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_accepting_new_patients BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(tenant_id, professional_slug),
    UNIQUE(tenant_id, google_calendar_id),
    CONSTRAINT valid_working_hours CHECK (working_hours_start < working_hours_end),
    CONSTRAINT valid_slot_interval CHECK (slot_interval_minutes BETWEEN 5 AND 120)
);

COMMENT ON TABLE professionals IS 'Clinic professionals - each has their own Google Calendar';
COMMENT ON COLUMN professionals.google_calendar_id IS 'Individual calendar ID - CRITICAL for correct booking';
COMMENT ON COLUMN professionals.slot_interval_minutes IS 'Base slot granularity for availability calculation';

-- ============================================================================
-- 3. CREATE PROFESSIONAL_SERVICES JUNCTION TABLE (Custom Pricing & Duration)
-- ============================================================================
-- This is the CRITICAL table that links professionals to services with
-- CUSTOM duration and pricing per professional.

CREATE TABLE IF NOT EXISTS professional_services (
    -- Primary Key
    ps_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    professional_id UUID NOT NULL REFERENCES professionals(professional_id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES services_catalog(service_id) ON DELETE CASCADE,
    
    -- ═══════════════════════════════════════════════════════════════════════
    -- CRITICAL: These override the catalog defaults for THIS professional
    -- ═══════════════════════════════════════════════════════════════════════
    
    -- Custom Duration (REQUIRED - no default to force explicit setting)
    custom_duration_minutes INTEGER NOT NULL,
    -- Example: Dr. José's Implant = 120 min, Dr. Maria's Implant = 90 min
    
    -- Custom Price (REQUIRED - no default to force explicit setting)
    custom_price_cents INTEGER NOT NULL,
    -- Example: Dr. José's Implant = R$ 5.000 (500000 cents)
    
    -- Pricing Display
    price_display VARCHAR(50),                       -- Formatted: 'R$ 5.000,00'
    price_notes TEXT,                                -- "Inclui 2 sessões de acompanhamento"
    
    -- Availability Constraints (per professional/service)
    available_days JSONB,                            -- Override: ["1","3","5"] = Mon/Wed/Fri only
    available_hours_start TIME,                      -- This service only after 14:00
    available_hours_end TIME,                        -- This service only until 17:00
    max_per_day INTEGER,                             -- Max 2 implants per day
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    UNIQUE(professional_id, service_id),
    CONSTRAINT valid_duration CHECK (custom_duration_minutes BETWEEN 5 AND 480),
    CONSTRAINT valid_price CHECK (custom_price_cents >= 0)
);

COMMENT ON TABLE professional_services IS 'Junction table with CUSTOM duration and price per professional';
COMMENT ON COLUMN professional_services.custom_duration_minutes IS 'CRITICAL: This duration is used for slot calculation and calendar booking';
COMMENT ON COLUMN professional_services.custom_price_cents IS 'Price in cents - must be presented to patient before booking';

-- ============================================================================
-- 4. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Services Catalog indexes
CREATE INDEX idx_services_catalog_category ON services_catalog(service_category) WHERE is_active = true;
CREATE INDEX idx_services_catalog_keywords ON services_catalog USING gin(service_keywords);
CREATE INDEX idx_services_catalog_code ON services_catalog(service_code);

-- Professionals indexes
CREATE INDEX idx_professionals_tenant ON professionals(tenant_id) WHERE is_active = true;
CREATE INDEX idx_professionals_specialty ON professionals(tenant_id, specialty) WHERE is_active = true;
CREATE INDEX idx_professionals_keywords ON professionals USING gin(specialty_keywords);
CREATE INDEX idx_professionals_slug ON professionals(tenant_id, professional_slug);

-- Professional Services indexes (CRITICAL for service lookup)
CREATE INDEX idx_ps_professional ON professional_services(professional_id) WHERE is_active = true;
CREATE INDEX idx_ps_service ON professional_services(service_id) WHERE is_active = true;
CREATE INDEX idx_ps_professional_service ON professional_services(professional_id, service_id);

-- ============================================================================
-- 5. CREATE UPDATE TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS services_catalog_updated_at ON services_catalog;
CREATE TRIGGER services_catalog_updated_at
    BEFORE UPDATE ON services_catalog
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS professionals_updated_at ON professionals;
CREATE TRIGGER professionals_updated_at
    BEFORE UPDATE ON professionals
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS professional_services_updated_at ON professional_services;
CREATE TRIGGER professional_services_updated_at
    BEFORE UPDATE ON professional_services
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- 6. SERVICE RESOLVER FUNCTIONS (CRITICAL FOR AI ROUTING)
-- ============================================================================

-- Function: Find professionals who offer a specific service (by keyword match)
CREATE OR REPLACE FUNCTION find_professionals_for_service(
    p_tenant_id UUID,
    p_search_text TEXT
)
RETURNS TABLE (
    professional_id UUID,
    professional_name VARCHAR,
    specialty VARCHAR,
    google_calendar_id VARCHAR,
    service_id UUID,
    service_name VARCHAR,
    service_code VARCHAR,
    duration_minutes INTEGER,          -- CRITICAL: Custom duration for this professional
    price_cents INTEGER,               -- CRITICAL: Custom price for this professional
    price_display VARCHAR,
    match_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.professional_id,
        p.professional_name,
        p.specialty,
        p.google_calendar_id,
        sc.service_id,
        sc.service_name,
        sc.service_code,
        ps.custom_duration_minutes as duration_minutes,   -- USE CUSTOM DURATION
        ps.custom_price_cents as price_cents,             -- USE CUSTOM PRICE
        ps.price_display,
        CASE
            WHEN LOWER(sc.service_name) = LOWER(p_search_text) THEN 1.0
            WHEN LOWER(sc.service_code) = UPPER(p_search_text) THEN 0.95
            WHEN LOWER(sc.service_name) ILIKE '%' || LOWER(p_search_text) || '%' THEN 0.8
            WHEN EXISTS (
                SELECT 1 FROM unnest(sc.service_keywords) kw 
                WHERE LOWER(p_search_text) ILIKE '%' || LOWER(kw) || '%'
            ) THEN 0.7
            ELSE 0.5
        END::NUMERIC as match_score
    FROM professional_services ps
    JOIN professionals p ON ps.professional_id = p.professional_id
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    WHERE p.tenant_id = p_tenant_id
    AND p.is_active = true
    AND ps.is_active = true
    AND sc.is_active = true
    AND (
        LOWER(sc.service_name) ILIKE '%' || LOWER(p_search_text) || '%'
        OR LOWER(sc.service_code) ILIKE '%' || LOWER(p_search_text) || '%'
        OR EXISTS (
            SELECT 1 FROM unnest(sc.service_keywords) kw 
            WHERE LOWER(p_search_text) ILIKE '%' || LOWER(kw) || '%'
        )
    )
    ORDER BY match_score DESC, p.display_order;
END;
$$ LANGUAGE plpgsql;

-- Function: Get service details for a specific professional
CREATE OR REPLACE FUNCTION get_professional_service_details(
    p_professional_id UUID,
    p_service_id UUID
)
RETURNS TABLE (
    professional_id UUID,
    professional_name VARCHAR,
    google_calendar_id VARCHAR,
    slot_interval_minutes INTEGER,
    buffer_minutes INTEGER,
    service_id UUID,
    service_name VARCHAR,
    service_code VARCHAR,
    duration_minutes INTEGER,
    price_cents INTEGER,
    price_display VARCHAR,
    requires_preparation BOOLEAN,
    preparation_instructions TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.professional_id,
        p.professional_name,
        p.google_calendar_id,
        p.slot_interval_minutes,
        p.buffer_between_appointments,
        sc.service_id,
        sc.service_name,
        sc.service_code,
        ps.custom_duration_minutes,
        ps.custom_price_cents,
        ps.price_display,
        sc.requires_preparation,
        sc.preparation_instructions
    FROM professional_services ps
    JOIN professionals p ON ps.professional_id = p.professional_id
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND p.is_active = true
    AND ps.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Function: Calculate end time based on service duration (CRITICAL)
CREATE OR REPLACE FUNCTION calculate_appointment_end_time(
    p_start_time TIMESTAMPTZ,
    p_professional_id UUID,
    p_service_id UUID
)
RETURNS TIMESTAMPTZ AS $$
DECLARE
    v_duration_minutes INTEGER;
BEGIN
    -- Get the CUSTOM duration for this professional/service combination
    SELECT ps.custom_duration_minutes INTO v_duration_minutes
    FROM professional_services ps
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND ps.is_active = true;
    
    IF v_duration_minutes IS NULL THEN
        RAISE EXCEPTION 'Service not found for this professional';
    END IF;
    
    -- Return start_time + duration
    RETURN p_start_time + (v_duration_minutes || ' minutes')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- Function: Validate slot availability (CRITICAL - checks if slot >= duration)
CREATE OR REPLACE FUNCTION validate_slot_for_service(
    p_slot_start TIMESTAMPTZ,
    p_slot_end TIMESTAMPTZ,
    p_professional_id UUID,
    p_service_id UUID
)
RETURNS TABLE (
    is_valid BOOLEAN,
    slot_duration_minutes INTEGER,
    required_duration_minutes INTEGER,
    calculated_end_time TIMESTAMPTZ,
    error_message TEXT
) AS $$
DECLARE
    v_required_duration INTEGER;
    v_slot_duration INTEGER;
    v_calculated_end TIMESTAMPTZ;
BEGIN
    -- Get required duration for this service
    SELECT ps.custom_duration_minutes INTO v_required_duration
    FROM professional_services ps
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND ps.is_active = true;
    
    IF v_required_duration IS NULL THEN
        RETURN QUERY SELECT 
            false::BOOLEAN,
            NULL::INTEGER,
            NULL::INTEGER,
            NULL::TIMESTAMPTZ,
            'Service not found for this professional'::TEXT;
        RETURN;
    END IF;
    
    -- Calculate slot duration in minutes
    v_slot_duration := EXTRACT(EPOCH FROM (p_slot_end - p_slot_start)) / 60;
    
    -- Calculate what the end time would be
    v_calculated_end := p_slot_start + (v_required_duration || ' minutes')::INTERVAL;
    
    -- Validate: slot must be >= required duration
    IF v_slot_duration >= v_required_duration THEN
        RETURN QUERY SELECT 
            true::BOOLEAN,
            v_slot_duration,
            v_required_duration,
            v_calculated_end,
            NULL::TEXT;
    ELSE
        RETURN QUERY SELECT 
            false::BOOLEAN,
            v_slot_duration,
            v_required_duration,
            v_calculated_end,
            format('Slot too short: available %s min, required %s min', v_slot_duration, v_required_duration)::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Get all services for a professional (for listing)
CREATE OR REPLACE FUNCTION get_professional_services_list(p_professional_id UUID)
RETURNS TABLE (
    service_id UUID,
    service_code VARCHAR,
    service_name VARCHAR,
    service_category VARCHAR,
    duration_minutes INTEGER,
    price_cents INTEGER,
    price_display VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.service_id,
        sc.service_code,
        sc.service_name,
        sc.service_category,
        ps.custom_duration_minutes,
        ps.custom_price_cents,
        ps.price_display
    FROM professional_services ps
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    WHERE ps.professional_id = p_professional_id
    AND ps.is_active = true
    AND sc.is_active = true
    ORDER BY sc.service_category, sc.display_order, sc.service_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. CREATE VIEWS FOR AI CONTEXT
-- ============================================================================

-- View: Complete service catalog with professional customizations
CREATE OR REPLACE VIEW v_service_offerings AS
SELECT 
    tc.tenant_id,
    tc.tenant_name,
    tc.clinic_name,
    p.professional_id,
    p.professional_name,
    p.professional_title,
    p.specialty,
    p.google_calendar_id,
    sc.service_id,
    sc.service_code,
    sc.service_name,
    sc.service_category,
    sc.service_keywords,
    ps.custom_duration_minutes as duration_minutes,
    ps.custom_price_cents as price_cents,
    ps.price_display,
    ps.is_active
FROM tenant_config tc
JOIN professionals p ON tc.tenant_id = p.tenant_id
JOIN professional_services ps ON p.professional_id = ps.professional_id
JOIN services_catalog sc ON ps.service_id = sc.service_id
WHERE tc.is_active = true
AND p.is_active = true
AND ps.is_active = true
AND sc.is_active = true;

-- View: AI-friendly professional + services context for system prompts
CREATE OR REPLACE VIEW v_professionals_services_prompt AS
SELECT 
    p.tenant_id,
    p.professional_id,
    p.professional_name,
    p.specialty,
    string_agg(
        format('%s: %s min, %s', 
            sc.service_name, 
            ps.custom_duration_minutes,
            COALESCE(ps.price_display, 'Consultar')
        ),
        ' | '
        ORDER BY sc.service_name
    ) as services_summary
FROM professionals p
JOIN professional_services ps ON p.professional_id = ps.professional_id
JOIN services_catalog sc ON ps.service_id = sc.service_id
WHERE p.is_active = true AND ps.is_active = true AND sc.is_active = true
GROUP BY p.tenant_id, p.professional_id, p.professional_name, p.specialty;

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================

DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT SELECT, INSERT, UPDATE ON services_catalog TO n8n_user;
        GRANT SELECT, INSERT, UPDATE ON professionals TO n8n_user;
        GRANT SELECT, INSERT, UPDATE ON professional_services TO n8n_user;
        GRANT SELECT ON v_service_offerings TO n8n_user;
        GRANT SELECT ON v_professionals_services_prompt TO n8n_user;
        GRANT EXECUTE ON FUNCTION find_professionals_for_service(UUID, TEXT) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_professional_service_details(UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION calculate_appointment_end_time(TIMESTAMPTZ, UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION validate_slot_for_service(TIMESTAMPTZ, TIMESTAMPTZ, UUID, UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_professional_services_list(UUID) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_services_catalog_for_prompt(UUID) TO n8n_user;
    END IF;
END $$;

-- ============================================================================
-- 9. SERVICE CATALOG PROMPT FORMATTING FUNCTION
-- ============================================================================
-- Function to format services catalog for AI prompts (token-efficient)

CREATE OR REPLACE FUNCTION get_services_catalog_for_prompt(p_tenant_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_catalog TEXT := '';
    v_current_category TEXT := '';
    v_category_emoji TEXT;
    rec RECORD;
BEGIN
    -- Build catalog grouped by category and professional
    FOR rec IN 
        SELECT 
            sc.service_category,
            p.professional_name,
            p.professional_title,
            p.specialty,
            string_agg(
                format('• %s: %s | %s',
                    sc.service_name,
                    CASE 
                        WHEN ps.custom_duration_minutes < 60 THEN format('%smin', ps.custom_duration_minutes::TEXT)
                        WHEN ps.custom_duration_minutes = 60 THEN '1h'
                        ELSE format('%sh%smin', 
                            (ps.custom_duration_minutes / 60)::TEXT,
                            (ps.custom_duration_minutes % 60)::TEXT
                        )
                    END,
                    COALESCE(ps.price_display, format('R$ %s', to_char(ps.custom_price_cents / 100.0, 'FM999999990.00')))
                ),
                E'\n' ORDER BY sc.display_order, sc.service_name
            ) as services_list
        FROM professionals p
        JOIN professional_services ps ON p.professional_id = ps.professional_id
        JOIN services_catalog sc ON ps.service_id = sc.service_id
        WHERE p.tenant_id = p_tenant_id
        AND p.is_active = true
        AND ps.is_active = true
        AND sc.is_active = true
        GROUP BY sc.service_category, p.professional_name, p.professional_title, p.specialty, p.display_order
        ORDER BY p.display_order, sc.service_category
    LOOP
        -- Add category header if changed
        IF v_current_category IS DISTINCT FROM rec.service_category THEN
            -- Map category to emoji
            v_category_emoji := CASE rec.service_category
                WHEN 'Odontologia' THEN '🦷'
                WHEN 'Estética' THEN '💆'
                WHEN 'Cardiologia' THEN '❤️'
                WHEN 'Clínico Geral' THEN '👨‍⚕️'
                ELSE '📋'
            END;
            
            IF v_catalog != '' THEN
                v_catalog := v_catalog || E'\n';
            END IF;
            
            v_catalog := v_catalog || format('%s *%s* - %s %s (%s)',
                v_category_emoji,
                UPPER(rec.service_category),
                COALESCE(rec.professional_title, ''),
                rec.professional_name,
                rec.specialty
            );
            v_current_category := rec.service_category;
        END IF;
        
        -- Add services for this professional
        v_catalog := v_catalog || E'\n' || rec.services_list;
    END LOOP;
    
    RETURN COALESCE(v_catalog, 'Nenhum serviço cadastrado.');
END;
$$ LANGUAGE plpgsql;

-- Grant permissions for the new function
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT EXECUTE ON FUNCTION get_services_catalog_for_prompt(UUID) TO n8n_user;
    END IF;
END $$;

-- ============================================================================
-- 10. MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ MULTI-PROVIDER & MULTI-SERVICE ARCHITECTURE v2.0';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Tables created:';
    RAISE NOTICE '  • services_catalog (Global service definitions)';
    RAISE NOTICE '  • professionals (Clinic staff with calendars)';
    RAISE NOTICE '  • professional_services (Junction with custom duration/price)';
    RAISE NOTICE '';
    RAISE NOTICE 'Critical functions:';
    RAISE NOTICE '  • find_professionals_for_service() - AI routing';
    RAISE NOTICE '  • calculate_appointment_end_time() - Dynamic end time';
    RAISE NOTICE '  • validate_slot_for_service() - Slot >= Duration check';
    RAISE NOTICE '  • get_services_catalog_for_prompt() - Format catalog for AI';
    RAISE NOTICE '';
    RAISE NOTICE 'Next step: Run 005_seed_service_catalog_data.sql';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;

