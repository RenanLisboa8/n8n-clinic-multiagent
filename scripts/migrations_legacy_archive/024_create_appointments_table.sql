-- ============================================================================
-- APPOINTMENTS TABLE MIGRATION
-- Version: 1.0.0
-- Date: 2026-02-01
-- Description: Creates appointments table for audit, tracking, and scheduling
--              Implements soft delete and sync with Google Calendar
-- ============================================================================
-- 
-- PURPOSE:
-- 
-- The appointments table provides:
-- 1. Audit trail for all bookings (who, what, when)
-- 2. Soft delete support (deleted_at) for history preservation
-- 3. Sync status tracking with Google Calendar
-- 4. Support for reschedule/cancel flows
-- 5. Patient contact storage for reminders
-- 6. Status tracking (scheduled, cancelled, completed, no_show)
--
-- ============================================================================

-- ============================================================================
-- 1. CREATE APPOINTMENTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS appointments (
    -- Primary Key
    appointment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign Keys
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(professional_id) ON DELETE RESTRICT,
    service_id UUID NOT NULL REFERENCES services_catalog(service_id) ON DELETE RESTRICT,
    calendar_id UUID REFERENCES calendars(calendar_id) ON DELETE SET NULL,
    
    -- Google Calendar Reference
    google_event_id VARCHAR(255),                    -- Google Calendar event ID for sync
    google_event_link TEXT,                          -- Direct link to the event
    
    -- Scheduling Information
    start_at TIMESTAMPTZ NOT NULL,                   -- Appointment start time
    end_at TIMESTAMPTZ NOT NULL,                     -- Appointment end time (calculated from service duration)
    duration_minutes INTEGER NOT NULL,               -- Stored for reference even if service changes
    
    -- Patient Information
    patient_contact VARCHAR(50) NOT NULL,            -- WhatsApp/phone number (remote_jid)
    patient_name VARCHAR(200),                       -- Patient name if provided
    patient_email VARCHAR(100),                      -- Patient email if provided
    patient_notes TEXT,                              -- Notes from the patient
    
    -- Appointment Details
    service_name VARCHAR(200) NOT NULL,              -- Stored for reference even if service changes
    professional_name VARCHAR(200) NOT NULL,         -- Stored for reference even if professional changes
    price_cents INTEGER,                             -- Price at time of booking
    price_display VARCHAR(50),                       -- Formatted price at time of booking
    
    -- Status Management
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
    status_reason TEXT,                              -- Reason for cancellation, no-show, etc.
    status_changed_at TIMESTAMPTZ,                   -- When status last changed
    status_changed_by VARCHAR(100),                  -- Who changed the status (system, patient, staff)
    
    -- Confirmation & Reminders
    confirmation_sent_at TIMESTAMPTZ,                -- When confirmation message was sent
    reminder_24h_sent_at TIMESTAMPTZ,                -- When 24h reminder was sent
    reminder_1h_sent_at TIMESTAMPTZ,                 -- When 1h reminder was sent
    patient_confirmed_at TIMESTAMPTZ,                -- When patient confirmed attendance
    
    -- Reschedule Tracking
    rescheduled_from_id UUID REFERENCES appointments(appointment_id),  -- Original appointment if rescheduled
    reschedule_count INTEGER DEFAULT 0,              -- Number of times rescheduled
    
    -- Soft Delete
    deleted_at TIMESTAMPTZ,                          -- Soft delete timestamp (NULL = active)
    deleted_by VARCHAR(100),                         -- Who deleted (system, patient, staff)
    deleted_reason TEXT,                             -- Reason for deletion
    
    -- Sync Status
    sync_status VARCHAR(50) DEFAULT 'pending',       -- 'pending', 'synced', 'error', 'deleted'
    sync_error TEXT,                                 -- Last sync error if any
    last_synced_at TIMESTAMPTZ,                      -- Last successful sync with Google Calendar
    
    -- Source Tracking
    created_via VARCHAR(50) DEFAULT 'whatsapp',      -- 'whatsapp', 'telegram', 'web', 'api', 'manual'
    conversation_id UUID,                            -- Reference to conversation_state if available
    
    -- Audit
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by VARCHAR(100),
    updated_by VARCHAR(100),
    
    -- Constraints
    CONSTRAINT valid_appointment_times CHECK (start_at < end_at),
    CONSTRAINT valid_status CHECK (status IN ('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show', 'rescheduled')),
    CONSTRAINT valid_sync_status CHECK (sync_status IN ('pending', 'synced', 'error', 'deleted')),
    CONSTRAINT valid_created_via CHECK (created_via IN ('whatsapp', 'telegram', 'web', 'api', 'manual', 'migration')),
    CONSTRAINT valid_duration CHECK (duration_minutes BETWEEN 5 AND 480)
);

COMMENT ON TABLE appointments IS 'Appointment records with audit trail, soft delete, and Google Calendar sync';
COMMENT ON COLUMN appointments.deleted_at IS 'Soft delete - NULL means active, timestamp means deleted';
COMMENT ON COLUMN appointments.google_event_id IS 'Google Calendar event ID for sync operations';
COMMENT ON COLUMN appointments.status IS 'Current status: scheduled, confirmed, in_progress, completed, cancelled, no_show, rescheduled';

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================

-- Primary query: find appointments by tenant and date range (exclude soft deleted)
CREATE INDEX idx_appointments_tenant_date 
ON appointments(tenant_id, start_at) 
WHERE deleted_at IS NULL;

-- Find appointments by professional
CREATE INDEX idx_appointments_professional 
ON appointments(professional_id, start_at) 
WHERE deleted_at IS NULL;

-- Find appointments by patient contact
CREATE INDEX idx_appointments_patient 
ON appointments(tenant_id, patient_contact, start_at) 
WHERE deleted_at IS NULL;

-- Find appointments by status (for reminders, follow-ups)
CREATE INDEX idx_appointments_status 
ON appointments(tenant_id, status, start_at) 
WHERE deleted_at IS NULL;

-- Find pending sync appointments
CREATE INDEX idx_appointments_sync 
ON appointments(sync_status, created_at) 
WHERE deleted_at IS NULL AND sync_status != 'synced';

-- Google event lookup (for webhook updates from Google)
CREATE INDEX idx_appointments_google_event 
ON appointments(google_event_id) 
WHERE google_event_id IS NOT NULL;

-- Reminder queries (find appointments needing reminders)
CREATE INDEX idx_appointments_reminders 
ON appointments(start_at, reminder_24h_sent_at, reminder_1h_sent_at) 
WHERE deleted_at IS NULL AND status IN ('scheduled', 'confirmed');

-- Soft deleted appointments (for audit queries)
CREATE INDEX idx_appointments_deleted 
ON appointments(tenant_id, deleted_at) 
WHERE deleted_at IS NOT NULL;

-- ============================================================================
-- 3. CREATE UPDATE TRIGGER
-- ============================================================================

DROP TRIGGER IF EXISTS appointments_updated_at ON appointments;
CREATE TRIGGER appointments_updated_at
    BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- 4. APPOINTMENT MANAGEMENT FUNCTIONS
-- ============================================================================

-- Function: Create a new appointment
CREATE OR REPLACE FUNCTION create_appointment(
    p_tenant_id UUID,
    p_professional_id UUID,
    p_service_id UUID,
    p_start_at TIMESTAMPTZ,
    p_patient_contact VARCHAR(50),
    p_patient_name VARCHAR(200) DEFAULT NULL,
    p_created_via VARCHAR(50) DEFAULT 'whatsapp'
)
RETURNS TABLE (
    appointment_id UUID,
    end_at TIMESTAMPTZ,
    duration_minutes INTEGER,
    service_name VARCHAR,
    professional_name VARCHAR,
    price_display VARCHAR,
    google_calendar_id VARCHAR,
    calendar_id UUID
) AS $$
DECLARE
    v_appointment_id UUID;
    v_end_at TIMESTAMPTZ;
    v_duration INTEGER;
    v_service_name VARCHAR;
    v_professional_name VARCHAR;
    v_price_cents INTEGER;
    v_price_display VARCHAR;
    v_google_calendar_id VARCHAR;
    v_calendar_id UUID;
BEGIN
    -- Get service and professional details
    SELECT 
        ps.custom_duration_minutes,
        sc.service_name,
        p.professional_name,
        ps.custom_price_cents,
        ps.price_display,
        p.google_calendar_id,
        p.default_calendar_id
    INTO 
        v_duration,
        v_service_name,
        v_professional_name,
        v_price_cents,
        v_price_display,
        v_google_calendar_id,
        v_calendar_id
    FROM professional_services ps
    JOIN services_catalog sc ON ps.service_id = sc.service_id
    JOIN professionals p ON ps.professional_id = p.professional_id
    WHERE ps.professional_id = p_professional_id
    AND ps.service_id = p_service_id
    AND ps.is_active = true
    AND p.is_active = true;
    
    IF v_duration IS NULL THEN
        RAISE EXCEPTION 'Service not found for this professional';
    END IF;
    
    -- Calculate end time
    v_end_at := p_start_at + (v_duration || ' minutes')::INTERVAL;
    
    -- Insert appointment
    INSERT INTO appointments (
        tenant_id,
        professional_id,
        service_id,
        calendar_id,
        start_at,
        end_at,
        duration_minutes,
        patient_contact,
        patient_name,
        service_name,
        professional_name,
        price_cents,
        price_display,
        created_via,
        status,
        sync_status
    ) VALUES (
        p_tenant_id,
        p_professional_id,
        p_service_id,
        v_calendar_id,
        p_start_at,
        v_end_at,
        v_duration,
        p_patient_contact,
        p_patient_name,
        v_service_name,
        v_professional_name,
        v_price_cents,
        v_price_display,
        p_created_via,
        'scheduled',
        'pending'
    )
    RETURNING appointments.appointment_id INTO v_appointment_id;
    
    -- Return the created appointment details
    RETURN QUERY SELECT 
        v_appointment_id,
        v_end_at,
        v_duration,
        v_service_name,
        v_professional_name,
        v_price_display,
        v_google_calendar_id,
        v_calendar_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Cancel an appointment (soft delete)
CREATE OR REPLACE FUNCTION cancel_appointment(
    p_appointment_id UUID,
    p_cancelled_by VARCHAR(100) DEFAULT 'patient',
    p_reason TEXT DEFAULT NULL
)
RETURNS TABLE (
    success BOOLEAN,
    google_event_id VARCHAR,
    google_calendar_id VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_appointment appointments;
    v_google_calendar_id VARCHAR;
BEGIN
    -- Get the appointment
    SELECT * INTO v_appointment
    FROM appointments
    WHERE appointment_id = p_appointment_id
    AND deleted_at IS NULL;
    
    IF v_appointment.appointment_id IS NULL THEN
        RETURN QUERY SELECT false::BOOLEAN, NULL::VARCHAR, NULL::VARCHAR, 'Appointment not found'::TEXT;
        RETURN;
    END IF;
    
    -- Get the google calendar id
    SELECT google_calendar_id INTO v_google_calendar_id
    FROM professionals
    WHERE professional_id = v_appointment.professional_id;
    
    -- Soft delete the appointment
    UPDATE appointments
    SET 
        status = 'cancelled',
        status_reason = p_reason,
        status_changed_at = NOW(),
        status_changed_by = p_cancelled_by,
        deleted_at = NOW(),
        deleted_by = p_cancelled_by,
        deleted_reason = p_reason,
        sync_status = 'pending'
    WHERE appointment_id = p_appointment_id;
    
    RETURN QUERY SELECT 
        true::BOOLEAN, 
        v_appointment.google_event_id::VARCHAR,
        v_google_calendar_id::VARCHAR,
        'Appointment cancelled successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function: Reschedule an appointment
CREATE OR REPLACE FUNCTION reschedule_appointment(
    p_appointment_id UUID,
    p_new_start_at TIMESTAMPTZ,
    p_rescheduled_by VARCHAR(100) DEFAULT 'patient'
)
RETURNS TABLE (
    new_appointment_id UUID,
    new_end_at TIMESTAMPTZ,
    old_google_event_id VARCHAR,
    google_calendar_id VARCHAR,
    message TEXT
) AS $$
DECLARE
    v_old_appointment appointments;
    v_new_appointment_id UUID;
    v_new_end_at TIMESTAMPTZ;
    v_google_calendar_id VARCHAR;
BEGIN
    -- Get the original appointment
    SELECT * INTO v_old_appointment
    FROM appointments
    WHERE appointment_id = p_appointment_id
    AND deleted_at IS NULL
    AND status IN ('scheduled', 'confirmed');
    
    IF v_old_appointment.appointment_id IS NULL THEN
        RETURN QUERY SELECT 
            NULL::UUID, 
            NULL::TIMESTAMPTZ, 
            NULL::VARCHAR, 
            NULL::VARCHAR, 
            'Appointment not found or cannot be rescheduled'::TEXT;
        RETURN;
    END IF;
    
    -- Get the google calendar id
    SELECT google_calendar_id INTO v_google_calendar_id
    FROM professionals
    WHERE professional_id = v_old_appointment.professional_id;
    
    -- Calculate new end time
    v_new_end_at := p_new_start_at + (v_old_appointment.duration_minutes || ' minutes')::INTERVAL;
    
    -- Mark old appointment as rescheduled
    UPDATE appointments
    SET 
        status = 'rescheduled',
        status_reason = 'Rescheduled to new date/time',
        status_changed_at = NOW(),
        status_changed_by = p_rescheduled_by,
        deleted_at = NOW(),
        deleted_by = p_rescheduled_by,
        deleted_reason = 'Rescheduled',
        sync_status = 'pending'
    WHERE appointment_id = p_appointment_id;
    
    -- Create new appointment
    INSERT INTO appointments (
        tenant_id,
        professional_id,
        service_id,
        calendar_id,
        start_at,
        end_at,
        duration_minutes,
        patient_contact,
        patient_name,
        patient_email,
        patient_notes,
        service_name,
        professional_name,
        price_cents,
        price_display,
        created_via,
        rescheduled_from_id,
        reschedule_count,
        status,
        sync_status
    ) VALUES (
        v_old_appointment.tenant_id,
        v_old_appointment.professional_id,
        v_old_appointment.service_id,
        v_old_appointment.calendar_id,
        p_new_start_at,
        v_new_end_at,
        v_old_appointment.duration_minutes,
        v_old_appointment.patient_contact,
        v_old_appointment.patient_name,
        v_old_appointment.patient_email,
        v_old_appointment.patient_notes,
        v_old_appointment.service_name,
        v_old_appointment.professional_name,
        v_old_appointment.price_cents,
        v_old_appointment.price_display,
        v_old_appointment.created_via,
        p_appointment_id,
        v_old_appointment.reschedule_count + 1,
        'scheduled',
        'pending'
    )
    RETURNING appointment_id INTO v_new_appointment_id;
    
    RETURN QUERY SELECT 
        v_new_appointment_id,
        v_new_end_at,
        v_old_appointment.google_event_id::VARCHAR,
        v_google_calendar_id::VARCHAR,
        'Appointment rescheduled successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function: Update appointment with Google Event ID after calendar sync
CREATE OR REPLACE FUNCTION update_appointment_google_event(
    p_appointment_id UUID,
    p_google_event_id VARCHAR,
    p_google_event_link TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    UPDATE appointments
    SET 
        google_event_id = p_google_event_id,
        google_event_link = p_google_event_link,
        sync_status = 'synced',
        last_synced_at = NOW()
    WHERE appointment_id = p_appointment_id;
END;
$$ LANGUAGE plpgsql;

-- Function: Get patient's upcoming appointments
CREATE OR REPLACE FUNCTION get_patient_appointments(
    p_tenant_id UUID,
    p_patient_contact VARCHAR(50),
    p_include_past BOOLEAN DEFAULT false
)
RETURNS TABLE (
    appointment_id UUID,
    start_at TIMESTAMPTZ,
    end_at TIMESTAMPTZ,
    service_name VARCHAR,
    professional_name VARCHAR,
    status VARCHAR,
    price_display VARCHAR,
    google_event_link TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.start_at,
        a.end_at,
        a.service_name,
        a.professional_name,
        a.status,
        a.price_display,
        a.google_event_link
    FROM appointments a
    WHERE a.tenant_id = p_tenant_id
    AND a.patient_contact = p_patient_contact
    AND a.deleted_at IS NULL
    AND (p_include_past OR a.start_at >= NOW())
    ORDER BY a.start_at;
END;
$$ LANGUAGE plpgsql;

-- Function: Get appointments needing reminders
CREATE OR REPLACE FUNCTION get_appointments_for_reminders(
    p_reminder_type VARCHAR(10)  -- '24h' or '1h'
)
RETURNS TABLE (
    appointment_id UUID,
    tenant_id UUID,
    patient_contact VARCHAR,
    patient_name VARCHAR,
    start_at TIMESTAMPTZ,
    service_name VARCHAR,
    professional_name VARCHAR,
    clinic_name VARCHAR,
    clinic_phone VARCHAR
) AS $$
DECLARE
    v_start_range TIMESTAMPTZ;
    v_end_range TIMESTAMPTZ;
BEGIN
    -- Calculate time range based on reminder type
    IF p_reminder_type = '24h' THEN
        v_start_range := NOW() + INTERVAL '23 hours';
        v_end_range := NOW() + INTERVAL '25 hours';
    ELSIF p_reminder_type = '1h' THEN
        v_start_range := NOW() + INTERVAL '55 minutes';
        v_end_range := NOW() + INTERVAL '65 minutes';
    ELSE
        RAISE EXCEPTION 'Invalid reminder type: %', p_reminder_type;
    END IF;
    
    RETURN QUERY
    SELECT 
        a.appointment_id,
        a.tenant_id,
        a.patient_contact,
        a.patient_name,
        a.start_at,
        a.service_name,
        a.professional_name,
        tc.clinic_name,
        tc.clinic_phone
    FROM appointments a
    JOIN tenant_config tc ON a.tenant_id = tc.tenant_id
    WHERE a.deleted_at IS NULL
    AND a.status IN ('scheduled', 'confirmed')
    AND a.start_at BETWEEN v_start_range AND v_end_range
    AND (
        (p_reminder_type = '24h' AND a.reminder_24h_sent_at IS NULL)
        OR (p_reminder_type = '1h' AND a.reminder_1h_sent_at IS NULL)
    );
END;
$$ LANGUAGE plpgsql;

-- Function: Mark reminder as sent
CREATE OR REPLACE FUNCTION mark_reminder_sent(
    p_appointment_id UUID,
    p_reminder_type VARCHAR(10)
)
RETURNS VOID AS $$
BEGIN
    IF p_reminder_type = '24h' THEN
        UPDATE appointments
        SET reminder_24h_sent_at = NOW()
        WHERE appointment_id = p_appointment_id;
    ELSIF p_reminder_type = '1h' THEN
        UPDATE appointments
        SET reminder_1h_sent_at = NOW()
        WHERE appointment_id = p_appointment_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function: Get appointment statistics for a tenant
CREATE OR REPLACE FUNCTION get_appointment_stats(
    p_tenant_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    total_appointments BIGINT,
    completed BIGINT,
    cancelled BIGINT,
    no_shows BIGINT,
    scheduled BIGINT,
    total_revenue_cents BIGINT,
    avg_duration_minutes NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_appointments,
        COUNT(*) FILTER (WHERE status = 'completed')::BIGINT as completed,
        COUNT(*) FILTER (WHERE status = 'cancelled')::BIGINT as cancelled,
        COUNT(*) FILTER (WHERE status = 'no_show')::BIGINT as no_shows,
        COUNT(*) FILTER (WHERE status IN ('scheduled', 'confirmed'))::BIGINT as scheduled,
        COALESCE(SUM(price_cents) FILTER (WHERE status = 'completed'), 0)::BIGINT as total_revenue_cents,
        ROUND(AVG(duration_minutes), 1) as avg_duration_minutes
    FROM appointments
    WHERE tenant_id = p_tenant_id
    AND start_at::DATE BETWEEN p_start_date AND p_end_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. CREATE VIEWS
-- ============================================================================

-- View: Active appointments (excluding soft deleted)
CREATE OR REPLACE VIEW v_active_appointments AS
SELECT 
    a.appointment_id,
    a.tenant_id,
    tc.tenant_name,
    tc.clinic_name,
    a.professional_id,
    a.professional_name,
    a.service_id,
    a.service_name,
    a.start_at,
    a.end_at,
    a.duration_minutes,
    a.patient_contact,
    a.patient_name,
    a.status,
    a.price_display,
    a.google_event_id,
    a.google_event_link,
    a.confirmation_sent_at,
    a.patient_confirmed_at,
    a.created_at,
    a.created_via
FROM appointments a
JOIN tenant_config tc ON a.tenant_id = tc.tenant_id
WHERE a.deleted_at IS NULL;

-- View: Today's appointments
CREATE OR REPLACE VIEW v_todays_appointments AS
SELECT *
FROM v_active_appointments
WHERE start_at::DATE = CURRENT_DATE
ORDER BY start_at;

-- View: Appointments pending sync
CREATE OR REPLACE VIEW v_pending_sync_appointments AS
SELECT 
    a.appointment_id,
    a.tenant_id,
    a.professional_id,
    p.google_calendar_id,
    c.credential_ref,
    a.start_at,
    a.end_at,
    a.patient_name,
    a.patient_contact,
    a.service_name,
    a.status,
    a.sync_status,
    a.google_event_id
FROM appointments a
JOIN professionals p ON a.professional_id = p.professional_id
LEFT JOIN calendars c ON a.calendar_id = c.calendar_id
WHERE a.sync_status = 'pending'
ORDER BY a.created_at;

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================

DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON appointments TO n8n_user;
        GRANT SELECT ON v_active_appointments TO n8n_user;
        GRANT SELECT ON v_todays_appointments TO n8n_user;
        GRANT SELECT ON v_pending_sync_appointments TO n8n_user;
        GRANT EXECUTE ON FUNCTION create_appointment(UUID, UUID, UUID, TIMESTAMPTZ, VARCHAR, VARCHAR, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION cancel_appointment(UUID, VARCHAR, TEXT) TO n8n_user;
        GRANT EXECUTE ON FUNCTION reschedule_appointment(UUID, TIMESTAMPTZ, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION update_appointment_google_event(UUID, VARCHAR, TEXT) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_patient_appointments(UUID, VARCHAR, BOOLEAN) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_appointments_for_reminders(VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION mark_reminder_sent(UUID, VARCHAR) TO n8n_user;
        GRANT EXECUTE ON FUNCTION get_appointment_stats(UUID, DATE, DATE) TO n8n_user;
    END IF;
END $$;

-- Public grants for development
GRANT SELECT, INSERT, UPDATE, DELETE ON appointments TO PUBLIC;
GRANT SELECT ON v_active_appointments TO PUBLIC;
GRANT SELECT ON v_todays_appointments TO PUBLIC;
GRANT SELECT ON v_pending_sync_appointments TO PUBLIC;
GRANT EXECUTE ON FUNCTION create_appointment TO PUBLIC;
GRANT EXECUTE ON FUNCTION cancel_appointment TO PUBLIC;
GRANT EXECUTE ON FUNCTION reschedule_appointment TO PUBLIC;
GRANT EXECUTE ON FUNCTION update_appointment_google_event TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_patient_appointments TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_appointments_for_reminders TO PUBLIC;
GRANT EXECUTE ON FUNCTION mark_reminder_sent TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_appointment_stats TO PUBLIC;

-- ============================================================================
-- 7. MIGRATION COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ APPOINTMENTS TABLE MIGRATION COMPLETE';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Table created: appointments';
    RAISE NOTICE '';
    RAISE NOTICE 'Key features:';
    RAISE NOTICE '  • Soft delete via deleted_at column';
    RAISE NOTICE '  • Full audit trail (created_by, status_changed_by, etc.)';
    RAISE NOTICE '  • Google Calendar sync tracking (google_event_id, sync_status)';
    RAISE NOTICE '  • Reschedule tracking (rescheduled_from_id, reschedule_count)';
    RAISE NOTICE '  • Reminder tracking (confirmation_sent_at, reminder_*_sent_at)';
    RAISE NOTICE '';
    RAISE NOTICE 'Functions created:';
    RAISE NOTICE '  • create_appointment() - Create with auto duration/price lookup';
    RAISE NOTICE '  • cancel_appointment() - Soft delete with status update';
    RAISE NOTICE '  • reschedule_appointment() - Create new, soft delete old';
    RAISE NOTICE '  • update_appointment_google_event() - Store Google event ID';
    RAISE NOTICE '  • get_patient_appointments() - List patient appointments';
    RAISE NOTICE '  • get_appointments_for_reminders() - Find appointments for 24h/1h reminders';
    RAISE NOTICE '  • mark_reminder_sent() - Track reminder delivery';
    RAISE NOTICE '  • get_appointment_stats() - Analytics and reporting';
    RAISE NOTICE '';
    RAISE NOTICE 'Views created:';
    RAISE NOTICE '  • v_active_appointments - Excludes soft deleted';
    RAISE NOTICE '  • v_todays_appointments - Today appointments only';
    RAISE NOTICE '  • v_pending_sync_appointments - Need Google sync';
    RAISE NOTICE '';
    RAISE NOTICE 'Database schema refactoring complete!';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
END $$;