-- ============================================================================
-- MIGRATION 017: ADD SERVICES FAQ ENTRY
-- Version: 1.0.0
-- Date: 2026-01-11
-- Description: Adds FAQ entry for services/catalog questions to avoid AI calls
-- ============================================================================

-- Add FAQ entry for services/catalog questions
-- This FAQ entry will be matched by intent "services" from Intent Classifier
-- The answer uses {{ $json.services_catalog }} placeholder which will be replaced
-- by the Build Prompt with Catalog node in the workflow

INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Quais serviços vocês oferecem?',
    'quais serviços vocês oferecem?',
    'Aqui está a lista completa dos serviços disponíveis:

{{ $json.services_catalog }}

Qual serviço você gostaria de agendar? (Responda com o número)',
    ARRAY['quais serviços', 'quais procedimentos', 'o que oferece', 'o que vocês oferecem', 'o que voces oferecem', 'serviços disponíveis', 'serviços disponiveis', 'catálogo', 'catalogo', 'o que vocês fazem', 'o que voces fazem', 'procedimentos', 'tratamentos', 'especialidades', 'serviços', 'servicos'],
    'services',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO UPDATE SET
    answer = EXCLUDED.answer,
    keywords = EXCLUDED.keywords,
    intent = EXCLUDED.intent;

-- Also add variations of the question
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'Quais serviços tem?',
    'quais serviços tem?',
    'Aqui está a lista completa dos serviços disponíveis:

{{ $json.services_catalog }}

Qual serviço você gostaria de agendar? (Responda com o número)',
    ARRAY['quais serviços', 'quais procedimentos', 'o que oferece', 'serviços disponíveis', 'catálogo', 'procedimentos'],
    'services',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent,
    view_count
) 
SELECT 
    tenant_id,
    'O que vocês fazem?',
    'o que vocês fazem?',
    'Aqui está a lista completa dos serviços disponíveis:

{{ $json.services_catalog }}

Qual serviço você gostaria de agendar? (Responda com o número)',
    ARRAY['o que vocês fazem', 'o que voces fazem', 'o que oferecem', 'o que fazem'],
    'services',
    0
FROM tenant_config
WHERE is_active = true
ON CONFLICT (tenant_id, question_normalized) DO NOTHING;

-- Show summary
SELECT 
    tenant_name,
    COUNT(*) as services_faq_count
FROM tenant_faq f
JOIN tenant_config t ON f.tenant_id = t.tenant_id
WHERE f.intent = 'services'
AND f.is_active = true
AND t.is_active = true
GROUP BY tenant_name;
