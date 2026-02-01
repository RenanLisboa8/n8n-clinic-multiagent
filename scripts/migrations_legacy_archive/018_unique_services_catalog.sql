-- ============================================================================
-- MIGRATION 018: UNIQUE SERVICES CATALOG (Service-First Approach)
-- Version: 1.0.0
-- Date: 2026-01-11
-- Description: Modifies get_services_catalog_for_prompt() to show unique services
--              grouped by category (without professionals). After service selection,
--              system will show available professionals for that service.
-- ============================================================================

-- ============================================================================
-- MODIFY: get_services_catalog_for_prompt() - Show unique services only
-- ============================================================================

CREATE OR REPLACE FUNCTION get_services_catalog_for_prompt(p_tenant_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_catalog TEXT := '';
    v_current_category TEXT := '';
    v_category_emoji TEXT;
    v_service_counter INTEGER := 0;
    rec RECORD;
BEGIN
    -- Build catalog with unique services grouped by category only
    -- Services are listed once per category, regardless of how many professionals offer them
    FOR rec IN 
        SELECT DISTINCT
            sc.service_category,
            sc.service_name,
            sc.service_id,
            sc.display_order
        FROM services_catalog sc
        WHERE sc.service_id IN (
            SELECT DISTINCT ps.service_id
            FROM professionals p
            JOIN professional_services ps ON p.professional_id = ps.professional_id
            WHERE p.tenant_id = p_tenant_id
            AND p.is_active = true
            AND ps.is_active = true
        )
        AND sc.is_active = true
        ORDER BY sc.service_category, sc.display_order, sc.service_name
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
            
            v_catalog := v_catalog || format('%s *%s*',
                v_category_emoji,
                UPPER(rec.service_category)
            );
            v_current_category := rec.service_category;
        END IF;
        
        -- Add service with sequential numbering
        v_service_counter := v_service_counter + 1;
        
        v_catalog := v_catalog || E'\n' || format('%s. %s',
            v_service_counter::TEXT,
            rec.service_name
        );
    END LOOP;
    
    RETURN COALESCE(v_catalog, 'Nenhum serviço cadastrado.');
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (if role exists)
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT EXECUTE ON FUNCTION get_services_catalog_for_prompt(UUID) TO n8n_user;
    END IF;
END $$;

COMMENT ON FUNCTION get_services_catalog_for_prompt(UUID) IS 'Returns formatted unique services catalog grouped by category. After service selection, use FindProfessionals to show available professionals.';
