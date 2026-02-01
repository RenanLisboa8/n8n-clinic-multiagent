-- ============================================================================
-- SEED: STATE DEFINITIONS
-- Description: Conversation state machine definitions
-- ============================================================================

INSERT INTO state_definitions (state_name, description, valid_inputs, next_states, template_key, requires_ai) VALUES
('initial', 'Initial state - show main menu', 
  '{"1": "schedule", "2": "reschedule", "3": "cancel", "4": "services_info", "5": "hours_location", "agendar": "schedule", "reagendar": "reschedule", "cancelar": "cancel"}',
  '{"schedule": "awaiting_service", "reschedule": "awaiting_appointment_id", "cancel": "awaiting_cancel_confirm", "services_info": "show_services", "hours_location": "show_location"}',
  'greeting_new', false),

('awaiting_service', 'Waiting for service selection',
  '{"number": "select_service", "voltar": "initial", "0": "initial"}',
  '{"select_service": "awaiting_professional", "initial": "initial"}',
  'service_catalog', false),

('awaiting_professional', 'Waiting for professional selection',
  '{"number": "select_professional", "voltar": "awaiting_service", "0": "awaiting_service"}',
  '{"select_professional": "awaiting_date", "awaiting_service": "awaiting_service"}',
  'professional_list', false),

('awaiting_date', 'Waiting for date/time selection',
  '{"number": "select_slot", "voltar": "awaiting_professional", "0": "awaiting_professional"}',
  '{"select_slot": "awaiting_confirmation", "awaiting_professional": "awaiting_professional"}',
  'professional_details', false),

('awaiting_confirmation', 'Waiting for appointment confirmation',
  '{"sim": "confirmed", "não": "cancelled", "nao": "cancelled", "voltar": "awaiting_date", "1": "confirmed", "2": "cancelled"}',
  '{"confirmed": "completed", "cancelled": "initial", "awaiting_date": "awaiting_date"}',
  'appointment_confirm_request', false),

('completed', 'Appointment completed successfully',
  '{}',
  '{"any": "initial"}',
  'appointment_confirmed', false),

('awaiting_reschedule', 'Waiting for appointment to reschedule',
  '{"number": "select_appointment", "voltar": "initial"}',
  '{"select_appointment": "awaiting_new_date", "initial": "initial"}',
  NULL, false),

('awaiting_cancel_confirm', 'Confirming cancellation',
  '{"sim": "cancel_confirmed", "não": "initial", "1": "cancel_confirmed", "2": "initial"}',
  '{"cancel_confirmed": "initial", "initial": "initial"}',
  NULL, false),

('show_services', 'Displaying services info',
  '{"number": "service_details", "voltar": "initial"}',
  '{"service_details": "show_service_detail", "initial": "initial"}',
  'service_catalog', false),

('show_location', 'Displaying location and hours',
  '{"voltar": "initial", "0": "initial"}',
  '{"initial": "initial"}',
  'hours_location', false),

('escalated', 'Conversation escalated to human',
  '{}',
  '{}',
  'escalate_human', false),

('complex_query', 'Requires AI processing',
  '{}',
  '{"resolved": "initial"}',
  NULL, true)
ON CONFLICT (state_name) DO UPDATE SET
  description = EXCLUDED.description,
  valid_inputs = EXCLUDED.valid_inputs,
  next_states = EXCLUDED.next_states,
  template_key = EXCLUDED.template_key,
  requires_ai = EXCLUDED.requires_ai;

DO $$
BEGIN
    RAISE NOTICE '✅ State definitions seeded successfully';
END $$;