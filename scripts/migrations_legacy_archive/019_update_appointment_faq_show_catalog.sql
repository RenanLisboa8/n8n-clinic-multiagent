-- ============================================================================
-- MIGRATION 019: UPDATE APPOINTMENT FAQ TO SHOW SERVICE CATALOG
-- Version: 1.0.0
-- Date: 2026-01-13
-- Description: Updates the appointment FAQ (option 1) to show service catalog
--              instead of asking for patient details first
-- ============================================================================

-- Update FAQ for option "1" (appointment) to show service catalog first
UPDATE tenant_faq
SET answer = 'Ótimo! Vamos agendar sua consulta.

Aqui está nossa lista de serviços disponíveis:

{{ $json.services_catalog }}

*Qual serviço você gostaria de agendar? (Responda com o número do serviço)*',
    updated_at = NOW()
WHERE question_normalized = '1'
  AND intent = 'appointment'
  AND is_active = true;

-- Show summary
SELECT 
    COUNT(*) as updated_count,
    'Appointment FAQ updated to show service catalog' as description
FROM tenant_faq
WHERE question_normalized = '1'
  AND intent = 'appointment'
  AND answer LIKE '%services_catalog%'
  AND is_active = true;
