# n8n Clinic Multi-Agent System - Workflow Architecture

## Overview
This document describes the modular workflow architecture for the n8n Clinic Multi-Agent System, refactored from a monolithic design into a maintainable, scalable structure following the Single Responsibility Principle.

---

## Architectural Principles

### 1. **Separation of Concerns**
- **Main Workflows**: Handle orchestration, routing, and high-level logic
- **Tool Workflows**: Implement specific, reusable functionalities
- **Agent Specialization**: Each agent has a clear, defined responsibility

### 2. **Reusability**
- Tools are self-contained and can be called from multiple workflows
- Common operations (formatting, error handling) are centralized

### 3. **Maintainability**
- Each workflow file focuses on a single domain
- Easy to locate, update, and debug specific functionality

---

## Proposed Workflow Structure

```
workflows/
├── main/
│   ├── 01-whatsapp-patient-handler.json          # Main patient interaction flow
│   ├── 02-telegram-internal-assistant.json       # Internal staff assistant
│   └── 03-appointment-confirmation-scheduler.json # Daily confirmation automation
│
└── tools/
    ├── calendar/
    │   ├── mcp-calendar-tool.json                # Google Calendar operations
    │   └── appointment-reminder-tool.json         # Send appointment reminders
    │
    ├── communication/
    │   ├── whatsapp-send-tool.json               # Evolution API WhatsApp sender
    │   ├── telegram-notify-tool.json             # Telegram notifications
    │   └── message-formatter-tool.json           # Format messages for WhatsApp
    │
    ├── ai-processing/
    │   ├── image-ocr-tool.json                   # Process images with OCR
    │   ├── audio-transcription-tool.json         # Transcribe audio messages
    │   └── text-analysis-tool.json               # Analyze and interpret text
    │
    └── escalation/
        └── call-to-human-tool.json               # Escalate to human operator
```

---

## Workflow Descriptions

### **Main Workflows**

#### 1. `01-whatsapp-patient-handler.json`
**Purpose**: Handle all incoming WhatsApp messages from patients

**Responsibilities**:
- Receive webhook from Evolution API
- Parse message type (text, image, audio, document)
- Route to appropriate processing tool
- Interact with AI assistant for responses
- Send formatted responses back via WhatsApp

**Key Nodes**:
- Webhook Trigger (Evolution API)
- Message Type Switch
- Patient Assistant Agent
- Tools: Image OCR, Audio Transcription, Calendar, Escalation

**Agent**: `Assistente Clínica` (Patient-facing assistant)
- Handles scheduling, rescheduling, cancellations
- Answers clinic questions
- Escalates urgent situations

---

#### 2. `02-telegram-internal-assistant.json`
**Purpose**: Internal tool for clinic staff to manage operations via Telegram

**Responsibilities**:
- Receive commands from staff via Telegram
- Manage patient rescheduling
- Add items to clinic shopping list (Google Tasks)
- Send rescheduling notifications to patients

**Key Nodes**:
- Telegram Trigger
- Internal Assistant Agent
- Tools: Calendar, Google Tasks, WhatsApp Send

**Agent**: `Assistente Clínica Interno` (Internal assistant)
- Only accessible by authorized staff
- Performs administrative tasks
- Coordinates with patient-facing workflows

---

#### 3. `03-appointment-confirmation-scheduler.json`
**Purpose**: Automated daily confirmation of next-day appointments

**Responsibilities**:
- Trigger daily at 8 AM (Mon-Fri)
- Fetch next day's appointments from Google Calendar
- Extract patient contact information
- Send confirmation request via WhatsApp
- Log confirmation status

**Key Nodes**:
- Schedule Trigger (Cron: 0 8 * * 1-5)
- Google Calendar Fetch
- Loop through appointments
- Confirmation Assistant Agent
- Tools: Calendar, WhatsApp Send

**Agent**: `Assistente de Confirmação`
- Lists upcoming appointments
- Sends confirmation requests
- Does not handle responses (handled by main patient flow)

---

### **Tool Workflows**

#### **Calendar Tools**

##### `mcp-calendar-tool.json`
**Purpose**: Unified interface to Google Calendar via MCP

**Inputs**:
- `action`: get_all, get_availability, create, update, delete
- `date_start`, `date_end`
- `event_id` (for update/delete)
- `description`, `title` (for create)

**Outputs**:
- Event data or confirmation message

---

##### `appointment-reminder-tool.json`
**Purpose**: Send appointment reminder via WhatsApp

**Inputs**:
- `phone_number`: Patient's WhatsApp number
- `patient_name`
- `appointment_date`
- `appointment_time`

**Outputs**:
- Message sent confirmation

---

#### **Communication Tools**

##### `whatsapp-send-tool.json`
**Purpose**: Send WhatsApp message via Evolution API

**Inputs**:
- `instance_name`
- `remote_jid` (phone number)
- `message_text`

**Outputs**:
- Delivery status

---

##### `telegram-notify-tool.json`
**Purpose**: Send notification to staff via Telegram

**Inputs**:
- `chat_id`
- `message`
- `notification_type` (info, warning, error)

**Outputs**:
- Message sent confirmation

---

##### `message-formatter-tool.json`
**Purpose**: Format messages for WhatsApp markdown

**Inputs**:
- `raw_text` (from AI agent)

**Outputs**:
- `formatted_text` (** → *, remove #)

---

#### **AI Processing Tools**

##### `image-ocr-tool.json`
**Purpose**: Extract text from images using Google Gemini Vision

**Inputs**:
- `image_url`

**Outputs**:
- `transcribed_text`
- `image_description`

**Use Cases**:
- Medical prescriptions
- Lab results
- Handwritten notes

---

##### `audio-transcription-tool.json`
**Purpose**: Transcribe audio messages

**Inputs**:
- `audio_binary` (from Evolution API)

**Outputs**:
- `transcribed_text`

**Flow**:
1. Download audio from Evolution API
2. Convert to binary
3. Transcribe with Google Gemini Audio
4. Return text

---

##### `text-analysis-tool.json`
**Purpose**: Analyze and interpret text for context

**Inputs**:
- `text` (from OCR or transcription)

**Outputs**:
- `interpretation`
- `suggested_response`

---

#### **Escalation Tools**

##### `call-to-human-tool.json`
**Purpose**: Escalate conversation to human operator

**Inputs**:
- `patient_name`
- `phone_number`
- `last_message`
- `reason` (urgency, dissatisfaction, out-of-scope)

**Outputs**:
- Notification sent to staff
- Patient informed of escalation

**Triggers**:
- Medical urgency keywords
- Patient requests human contact
- Extreme dissatisfaction detected
- Out-of-scope topics

---

## Agent Configuration

### Environment Variables in System Messages
All hardcoded values should be replaced with expressions referencing environment variables:

**Examples**:
```javascript
// Replace hardcoded phone numbers
"5511111111111@s.whatsapp.net" 
→ 
"{{ $env.CLINIC_PHONE }}@s.whatsapp.net"

// Replace calendar links
"https://calendar.google.com/calendar/embed?src=..."
→
"{{ $env.CLINIC_CALENDAR_PUBLIC_LINK }}"

// Replace business hours
"Seg–Sáb: 08h–19h"
→
"{{ $env.CLINIC_DAYS_OPEN }}: {{ $env.CLINIC_HOURS_START }}–{{ $env.CLINIC_HOURS_END }}"

// Replace clinic address
"Rua Rio Casca, 417 – Belo Horizonte, MG"
→
"{{ $env.CLINIC_ADDRESS }}"
```

---

## Data Flow Examples

### Example 1: Patient Schedules Appointment via WhatsApp

```
1. Patient → WhatsApp → Evolution API → n8n Webhook
2. Webhook → Parse Message → Switch (text type)
3. Text → Patient Assistant Agent
4. Agent uses MCP Calendar Tool → Check availability
5. Patient chooses time → Agent uses MCP Calendar Tool → Create event
6. Agent → Message Formatter Tool → Format response
7. Formatted message → WhatsApp Send Tool → Patient
```

---

### Example 2: Staff Reschedules Patient via Telegram

```
1. Staff → Telegram → n8n Telegram Trigger
2. Internal Assistant Agent receives command
3. Agent uses MCP Calendar Tool → Find patient appointment
4. Agent uses MCP Calendar Tool → Update event
5. Agent uses WhatsApp Send Tool → Notify patient
6. Agent → Telegram → Confirm to staff
```

---

### Example 3: Daily Appointment Confirmations

```
1. Cron Trigger → 8 AM daily
2. Confirmation Assistant Agent activates
3. Agent uses MCP Calendar Tool → Get tomorrow's appointments
4. Loop through appointments:
   a. Extract patient phone from description
   b. Agent uses WhatsApp Send Tool → Send confirmation request
5. Complete and log results
```

---

## Benefits of Modular Architecture

### 1. **Maintainability**
- Each workflow has a clear purpose
- Easy to locate and fix bugs
- Changes in one area don't affect others

### 2. **Scalability**
- Add new tools without modifying main workflows
- Easy to extend functionality
- Can be load-balanced or distributed

### 3. **Testability**
- Tools can be tested independently
- Mock inputs/outputs for debugging
- Easier to validate behavior

### 4. **Reusability**
- WhatsApp Send Tool used by multiple workflows
- Calendar operations centralized
- Consistent behavior across system

### 5. **Team Collaboration**
- Multiple developers can work on different tools
- Clear interfaces between components
- Easier code reviews

---

## Migration Strategy

### Phase 1: Extract Tools
1. Create tool workflows from existing nodes
2. Test each tool independently
3. Document inputs/outputs

### Phase 2: Refactor Main Workflows
1. Replace inline logic with tool calls
2. Simplify main workflow structure
3. Add error handling

### Phase 3: Parameterize Configuration
1. Replace hardcoded values with env vars
2. Update system messages
3. Centralize configuration

### Phase 4: Testing & Validation
1. End-to-end testing of each flow
2. Performance testing
3. User acceptance testing

---

## Next Steps

1. ✅ Architecture documented
2. ⏳ Create tool workflow JSON files
3. ⏳ Refactor main workflow JSON files
4. ⏳ Update system messages with env vars
5. ⏳ Test and validate all flows

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-01  
**Author**: n8n Automation Team

