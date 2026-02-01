-- ============================================================================
-- SEED: SERVICES CATALOG
-- Description: Global service definitions (professionals customize via junction)
-- ============================================================================

INSERT INTO services_catalog (
    service_code, service_name, service_category, service_keywords,
    service_description, default_duration_minutes, default_price_cents,
    requires_preparation, preparation_instructions, display_order
) VALUES
    -- Odontologia
    ('IMPLANT_DENTAL', 'Implante Dentário', 'Odontologia',
     ARRAY['implante', 'dente', 'prótese', 'dental', 'titânio'],
     'Procedimento cirúrgico para substituição de raiz dentária',
     120, 500000, true, 'Jejum de 8 horas. Não tomar anti-inflamatórios 48h antes.', 1),
    
    ('CANAL_ROOT', 'Tratamento de Canal', 'Odontologia',
     ARRAY['canal', 'endodontia', 'raiz', 'dor de dente'],
     'Tratamento endodôntico para remoção de polpa infectada',
     90, 150000, false, NULL, 2),
    
    ('CLEANING_DENTAL', 'Limpeza Dentária', 'Odontologia',
     ARRAY['limpeza', 'profilaxia', 'tártaro', 'placa'],
     'Limpeza profissional e remoção de tártaro',
     45, 25000, false, NULL, 3),
    
    ('WHITENING', 'Clareamento Dental', 'Odontologia',
     ARRAY['clareamento', 'branqueamento', 'dente branco'],
     'Clareamento dental a laser ou com moldeira',
     60, 80000, false, NULL, 4),

    -- Estética
    ('BOTOX_FACIAL', 'Aplicação de Botox', 'Estética',
     ARRAY['botox', 'toxina botulínica', 'rugas', 'expressão'],
     'Aplicação de toxina botulínica para redução de rugas',
     60, 80000, false, NULL, 10),
    
    ('FILLER_FACIAL', 'Preenchimento Facial', 'Estética',
     ARRAY['preenchimento', 'ácido hialurônico', 'volume', 'lábios'],
     'Preenchimento com ácido hialurônico para volumização',
     90, 150000, false, NULL, 11),
    
    ('PEELING', 'Peeling Químico', 'Estética',
     ARRAY['peeling', 'manchas', 'melasma', 'acne'],
     'Tratamento químico para renovação da pele',
     45, 35000, false, NULL, 12),

    -- Cardiologia
    ('CONSULT_CARDIO', 'Consulta Cardiológica', 'Cardiologia',
     ARRAY['consulta', 'cardiologia', 'coração', 'pressão'],
     'Consulta de avaliação cardiovascular completa',
     45, 35000, false, NULL, 20),
    
    ('ECG', 'Eletrocardiograma', 'Cardiologia',
     ARRAY['ecg', 'eletro', 'eletrocardiograma', 'exame cardíaco'],
     'Exame de atividade elétrica do coração',
     30, 15000, false, NULL, 21),
    
    ('STRESS_TEST', 'Teste Ergométrico', 'Cardiologia',
     ARRAY['teste ergométrico', 'esteira', 'esforço', 'coração'],
     'Teste de esforço cardiovascular na esteira',
     60, 40000, true, 'Trazer roupa confortável e tênis.', 22),

    -- Clínico Geral
    ('CONSULT_GENERAL', 'Consulta Clínica Geral', 'Clínico Geral',
     ARRAY['consulta', 'clínico', 'geral', 'médico'],
     'Consulta médica de clínica geral',
     30, 20000, false, NULL, 30),
    
    ('CHECKUP', 'Check-up Completo', 'Clínico Geral',
     ARRAY['checkup', 'check-up', 'exames', 'rotina'],
     'Avaliação completa de saúde com solicitação de exames',
     60, 45000, false, NULL, 31)

ON CONFLICT (service_code) DO UPDATE SET
    service_name = EXCLUDED.service_name,
    service_keywords = EXCLUDED.service_keywords,
    updated_at = NOW();

DO $$
DECLARE
    service_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO service_count FROM services_catalog WHERE is_active = true;
    RAISE NOTICE '✅ Services catalog seeded. Total services: %', service_count;
END $$;