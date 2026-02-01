-- Migration 022: Conversation State Machine
-- Replaces AI memory with database-driven state tracking for reduced AI calls

-- Create conversation_state table
CREATE TABLE IF NOT EXISTS conversation_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
  remote_jid VARCHAR(50) NOT NULL,
  current_state VARCHAR(50) DEFAULT 'initial',
  state_data JSONB DEFAULT '{}',
  selected_service_id UUID,
  selected_professional_id UUID,
  selected_slot JSONB,
  last_interaction TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP DEFAULT (NOW() + INTERVAL '24 hours'),
  UNIQUE(tenant_id, remote_jid)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_conversation_state_lookup 
ON conversation_state(tenant_id, remote_jid);

CREATE INDEX IF NOT EXISTS idx_conversation_state_expires
ON conversation_state(expires_at) WHERE current_state != 'completed';

-- State definitions table
CREATE TABLE IF NOT EXISTS state_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  state_name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  valid_inputs JSONB DEFAULT '{}',
  next_states JSONB DEFAULT '{}',
  template_key VARCHAR(100),
  requires_ai BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insert state definitions
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

-- Function to get or create conversation state
CREATE OR REPLACE FUNCTION get_or_create_conversation_state(
  p_tenant_id UUID,
  p_remote_jid VARCHAR(50)
)
RETURNS conversation_state AS $$
DECLARE
  v_state conversation_state;
BEGIN
  -- Try to get existing state
  SELECT * INTO v_state
  FROM conversation_state
  WHERE tenant_id = p_tenant_id 
    AND remote_jid = p_remote_jid
    AND expires_at > NOW();
  
  -- If not found or expired, create new
  IF v_state.id IS NULL THEN
    INSERT INTO conversation_state (tenant_id, remote_jid, current_state, state_data)
    VALUES (p_tenant_id, p_remote_jid, 'initial', '{}')
    ON CONFLICT (tenant_id, remote_jid) 
    DO UPDATE SET 
      current_state = 'initial',
      state_data = '{}',
      selected_service_id = NULL,
      selected_professional_id = NULL,
      selected_slot = NULL,
      last_interaction = NOW(),
      expires_at = NOW() + INTERVAL '24 hours'
    RETURNING * INTO v_state;
  END IF;
  
  RETURN v_state;
END;
$$ LANGUAGE plpgsql;

-- Function to transition state
CREATE OR REPLACE FUNCTION transition_conversation_state(
  p_tenant_id UUID,
  p_remote_jid VARCHAR(50),
  p_input TEXT,
  p_additional_data JSONB DEFAULT '{}'
)
RETURNS TABLE(
  new_state VARCHAR(50),
  template_key VARCHAR(100),
  requires_ai BOOLEAN,
  state_data JSONB
) AS $$
DECLARE
  v_current_state conversation_state;
  v_state_def state_definitions;
  v_normalized_input TEXT;
  v_next_state TEXT;
  v_action TEXT;
BEGIN
  -- Get current state
  SELECT * INTO v_current_state
  FROM get_or_create_conversation_state(p_tenant_id, p_remote_jid);
  
  -- Get state definition
  SELECT * INTO v_state_def
  FROM state_definitions
  WHERE state_name = v_current_state.current_state;
  
  -- Normalize input (lowercase, trim)
  v_normalized_input := LOWER(TRIM(p_input));
  
  -- Check if input is a number
  IF v_normalized_input ~ '^\d+$' THEN
    -- Check if state accepts numbers
    IF v_state_def.valid_inputs ? 'number' THEN
      v_action := v_state_def.valid_inputs->>'number';
    ELSIF v_state_def.valid_inputs ? v_normalized_input THEN
      v_action := v_state_def.valid_inputs->>v_normalized_input;
    END IF;
  ELSE
    -- Check for text input
    IF v_state_def.valid_inputs ? v_normalized_input THEN
      v_action := v_state_def.valid_inputs->>v_normalized_input;
    END IF;
  END IF;
  
  -- If no valid action found, might need AI or show error
  IF v_action IS NULL THEN
    -- Check if this is a complex query that needs AI
    IF LENGTH(p_input) > 20 OR p_input LIKE '%?%' THEN
      v_next_state := 'complex_query';
    ELSE
      -- Stay in current state, return error template
      RETURN QUERY SELECT 
        v_current_state.current_state,
        'invalid_option'::VARCHAR(100),
        false,
        v_current_state.state_data;
      RETURN;
    END IF;
  ELSE
    -- Get next state from action
    v_next_state := v_state_def.next_states->>v_action;
  END IF;
  
  -- Update conversation state
  UPDATE conversation_state
  SET 
    current_state = COALESCE(v_next_state, v_current_state.current_state),
    state_data = v_current_state.state_data || p_additional_data,
    last_interaction = NOW(),
    expires_at = NOW() + INTERVAL '24 hours'
  WHERE tenant_id = p_tenant_id AND remote_jid = p_remote_jid;
  
  -- Get new state definition
  SELECT * INTO v_state_def
  FROM state_definitions
  WHERE state_name = COALESCE(v_next_state, v_current_state.current_state);
  
  -- Return result
  RETURN QUERY SELECT 
    COALESCE(v_next_state, v_current_state.current_state)::VARCHAR(50),
    v_state_def.template_key,
    v_state_def.requires_ai,
    v_current_state.state_data || p_additional_data;
END;
$$ LANGUAGE plpgsql;

-- Function to update state data (for storing selections)
CREATE OR REPLACE FUNCTION update_conversation_state_data(
  p_tenant_id UUID,
  p_remote_jid VARCHAR(50),
  p_service_id UUID DEFAULT NULL,
  p_professional_id UUID DEFAULT NULL,
  p_slot JSONB DEFAULT NULL,
  p_additional_data JSONB DEFAULT '{}'
)
RETURNS VOID AS $$
BEGIN
  UPDATE conversation_state
  SET 
    selected_service_id = COALESCE(p_service_id, selected_service_id),
    selected_professional_id = COALESCE(p_professional_id, selected_professional_id),
    selected_slot = COALESCE(p_slot, selected_slot),
    state_data = state_data || p_additional_data,
    last_interaction = NOW()
  WHERE tenant_id = p_tenant_id AND remote_jid = p_remote_jid;
END;
$$ LANGUAGE plpgsql;

-- Function to reset conversation state
CREATE OR REPLACE FUNCTION reset_conversation_state(
  p_tenant_id UUID,
  p_remote_jid VARCHAR(50)
)
RETURNS VOID AS $$
BEGIN
  UPDATE conversation_state
  SET 
    current_state = 'initial',
    state_data = '{}',
    selected_service_id = NULL,
    selected_professional_id = NULL,
    selected_slot = NULL,
    last_interaction = NOW(),
    expires_at = NOW() + INTERVAL '24 hours'
  WHERE tenant_id = p_tenant_id AND remote_jid = p_remote_jid;
END;
$$ LANGUAGE plpgsql;

-- Cleanup function for expired states
CREATE OR REPLACE FUNCTION cleanup_expired_conversation_states()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM conversation_state
  WHERE expires_at < NOW()
  RETURNING COUNT(*) INTO v_count;
  
  RETURN COALESCE(v_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON conversation_state TO PUBLIC;
GRANT SELECT ON state_definitions TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_or_create_conversation_state TO PUBLIC;
GRANT EXECUTE ON FUNCTION transition_conversation_state TO PUBLIC;
GRANT EXECUTE ON FUNCTION update_conversation_state_data TO PUBLIC;
GRANT EXECUTE ON FUNCTION reset_conversation_state TO PUBLIC;
GRANT EXECUTE ON FUNCTION cleanup_expired_conversation_states TO PUBLIC;

COMMENT ON TABLE conversation_state IS 'Tracks conversation state for each user, replacing AI memory';
COMMENT ON TABLE state_definitions IS 'Defines valid states and transitions for the conversation state machine';
COMMENT ON FUNCTION transition_conversation_state IS 'Processes user input and returns next state and template';