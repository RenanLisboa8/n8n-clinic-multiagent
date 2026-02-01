-- ============================================================================
-- ADD CLINIC_TYPE FIELD
-- Version: 1.0.0
-- Date: 2026-01-09
-- Description: Adds clinic_type field to tenant_config for configuring
--              clinic type (medical, aesthetic, mixed, dental, other)
-- ============================================================================

-- Add clinic_type column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'tenant_config' 
        AND column_name = 'clinic_type'
    ) THEN
        ALTER TABLE tenant_config 
        ADD COLUMN clinic_type VARCHAR(50) DEFAULT 'mixed';
        
        -- Add check constraint
        ALTER TABLE tenant_config
        ADD CONSTRAINT valid_clinic_type 
        CHECK (clinic_type IN ('medical', 'aesthetic', 'mixed', 'dental', 'other'));
        
        -- Add comment
        COMMENT ON COLUMN tenant_config.clinic_type IS 
        'Type of clinic: medical (medical clinics), aesthetic (aesthetic clinics), mixed (both), dental (dentistry), other (custom)';
        
        RAISE NOTICE '✅ Campo clinic_type adicionado à tabela tenant_config';
    ELSE
        RAISE NOTICE '⚠️ Campo clinic_type já existe na tabela tenant_config';
    END IF;
END $$;

-- Update existing tenants to 'mixed' if clinic_type is NULL
UPDATE tenant_config
SET clinic_type = 'mixed'
WHERE clinic_type IS NULL;

-- Set clinic_type based on services if possible (optional - apenas sugestão)
DO $$
DECLARE
    tenant_record RECORD;
    has_medical BOOLEAN;
    has_aesthetic BOOLEAN;
    suggested_type VARCHAR(50);
BEGIN
    FOR tenant_record IN SELECT tenant_id, clinic_name FROM tenant_config WHERE clinic_type = 'mixed' OR clinic_type IS NULL
    LOOP
        -- Check if tenant has medical services (Cardiologia, Clínico Geral)
        SELECT EXISTS (
            SELECT 1 
            FROM professional_services ps
            JOIN services_catalog sc ON ps.service_id = sc.service_id
            JOIN professionals p ON ps.professional_id = p.professional_id
            WHERE p.tenant_id = tenant_record.tenant_id
            AND sc.service_category IN ('Cardiologia', 'Clínico Geral')
            AND ps.is_active = true
            AND p.is_active = true
        ) INTO has_medical;
        
        -- Check if tenant has aesthetic services
        SELECT EXISTS (
            SELECT 1 
            FROM professional_services ps
            JOIN services_catalog sc ON ps.service_id = sc.service_id
            JOIN professionals p ON ps.professional_id = p.professional_id
            WHERE p.tenant_id = tenant_record.tenant_id
            AND sc.service_category = 'Estética'
            AND ps.is_active = true
            AND p.is_active = true
        ) INTO has_aesthetic;
        
        -- Suggest type based on services
        IF has_medical AND has_aesthetic THEN
            suggested_type := 'mixed';
        ELSIF has_aesthetic THEN
            suggested_type := 'aesthetic';
        ELSIF has_medical THEN
            suggested_type := 'medical';
        ELSE
            suggested_type := 'mixed'; -- Default
        END IF;
        
        -- Update if different (comentado para não sobrescrever manualmente configurado)
        -- UPDATE tenant_config 
        -- SET clinic_type = suggested_type
        -- WHERE tenant_id = tenant_record.tenant_id
        -- AND (clinic_type IS NULL OR clinic_type = 'mixed');
        
        RAISE NOTICE 'Tenant: % - Sugestão: % (médico: %, estética: %)', 
            tenant_record.clinic_name, suggested_type, has_medical, has_aesthetic;
    END LOOP;
END $$;

-- Display summary
SELECT 
    clinic_type,
    COUNT(*) as total_tenants,
    STRING_AGG(clinic_name, ', ' ORDER BY clinic_name) as clinics
FROM tenant_config
WHERE is_active = true
GROUP BY clinic_type
ORDER BY clinic_type;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CAMPO CLINIC_TYPE ADICIONADO';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Tipos disponíveis:';
    RAISE NOTICE '  • medical - Clínicas médicas (consultas, exames)';
    RAISE NOTICE '  • aesthetic - Clínicas de estética (botox, preenchimento)';
    RAISE NOTICE '  • mixed - Clínicas que oferecem ambos os tipos';
    RAISE NOTICE '  • dental - Clínicas odontológicas';
    RAISE NOTICE '  • other - Outros tipos de clínica';
    RAISE NOTICE '';
    RAISE NOTICE 'Para atualizar manualmente:';
    RAISE NOTICE '  UPDATE tenant_config SET clinic_type = ''aesthetic'' WHERE tenant_slug = ''clinica-estetica'';';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;
