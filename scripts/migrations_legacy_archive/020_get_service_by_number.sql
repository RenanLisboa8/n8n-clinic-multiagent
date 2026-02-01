-- ============================================================================
-- MIGRATION 020: GET SERVICE BY NUMBER FUNCTION
-- Version: 1.0.0
-- Date: 2026-01-13
-- Description: Creates function to get service details by its number in catalog
--              This allows processing service selection without AI
-- ============================================================================

-- Function: Get service by its number in the catalog
-- This matches the numbering from get_services_catalog_for_prompt()
CREATE OR REPLACE FUNCTION get_service_by_number(
    p_tenant_id UUID,
    p_service_number INTEGER
)
RETURNS TABLE (
    service_id UUID,
    service_name VARCHAR,
    service_code VARCHAR,
    service_category VARCHAR,
    service_number INTEGER
) AS $$
DECLARE
    v_service_counter INTEGER := 0;
    rec RECORD;
BEGIN
    -- Build catalog with same logic as get_services_catalog_for_prompt()
    -- and return the service at the specified number
    FOR rec IN 
        SELECT DISTINCT
            sc.service_id,
            sc.service_name,
            sc.service_code,
            sc.service_category,
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
        v_service_counter := v_service_counter + 1;
        
        -- If this is the service number we're looking for, return it
        IF v_service_counter = p_service_number THEN
            RETURN QUERY SELECT 
                rec.service_id,
                rec.service_name,
                rec.service_code,
                rec.service_category,
                v_service_counter;
            RETURN;
        END IF;
    END LOOP;
    
    -- If number not found, return empty result
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT EXECUTE ON FUNCTION get_service_by_number(UUID, INTEGER) TO n8n_user;
    END IF;
END $$;

COMMENT ON FUNCTION get_service_by_number(UUID, INTEGER) IS 'Returns service details by its number in the catalog (matches numbering from get_services_catalog_for_prompt)';
