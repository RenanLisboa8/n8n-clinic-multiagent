# Workflow Refactoring Guide

## Overview

This document provides a detailed strategy for refactoring the monolithic workflow into modular, production-ready components.

---

## Current State Analysis

### Monolithic Workflow Issues

The original `Multi-Agent AI Clinic Management v3 (FIXED).json` contains:
- **104 nodes** in a single workflow
- **3 main agent instances** (duplicated logic)
- **Multiple hardcoded values** (phone numbers, URLs, credentials)
- **Mixed responsibilities** (patient handling, staff tools, confirmations)
- **Duplicated components** (same nodes repeated in different sections)

### Problems Identified

1. **Maintainability**: Difficult to locate and fix issues
2. **Scalability**: Cannot independently scale different functions
3. **Testability**: Hard to test individual components
4. **Reusability**: Same logic implemented multiple times
5. **Security**: Credentials and sensitive data mixed with logic
6. **Collaboration**: Multiple developers cannot work simultaneously

---

## Refactoring Strategy

### Phase 1: Tool Extraction (Priority: HIGH)

Extract reusable components into tool workflows:

#### 1.1 Communication Tools

**whatsapp-send-tool.json**
- **Extracts from**: Nodes `Evolution API2`, `Evolution API3`, `REMINDER`, `REMINDER1`
- **Purpose**: Centralize WhatsApp message sending
- **Interface**:
  ```json
  {
    "inputs": {
      "instance_name": "string",
      "remote_jid": "string",
      "message_text": "string"
    },
    "outputs": {
      "success": "boolean",
      "message_id": "string"
    }
  }
  ```

**telegram-notify-tool.json**
- **Extracts from**: Nodes `Telegram`, `Telegram1`, `Enviar alerta de cancelamento`
- **Purpose**: Send Telegram notifications to staff
- **Interface**:
  ```json
  {
    "inputs": {
      "chat_id": "string",
      "message": "string",
      "notification_type": "info|warning|error"
    }
  }
  ```

**message-formatter-tool.json**
- **Extracts from**: Nodes `AI Agent`, `AI Agent1`
- **Purpose**: Format messages for WhatsApp markdown
- **Logic**: Replace `**` with `*`, remove `#`

#### 1.2 AI Processing Tools

**image-ocr-tool.json**
- **Extracts from**: Nodes `Analyze an image`, `Analyze an image1`, `AI Agent2`, `AI Agent3`
- **Purpose**: Extract text from images
- **Flow**: Image URL → Gemini Vision → Transcribed Text + Description

**audio-transcription-tool.json**
- **Extracts from**: Nodes `Evolution API`, `Evolution API1`, `Convert to File`, `Convert to File1`, `Analyze audio`, `Analyze audio1`
- **Purpose**: Transcribe audio messages
- **Flow**: Audio URL → Download → Convert → Gemini Audio → Text

#### 1.3 Calendar Tools

**mcp-calendar-tool.json**
- **Extracts from**: Nodes `MCP Google Calendar`, `MCP Google Calendar1`, `MCP Google Calendar2`, `MCP CALENDAR`
- **Purpose**: Unified Google Calendar interface
- **Actions**: get_all, get_availability, create, update, delete

#### 1.4 Escalation Tools

**call-to-human-tool.json**
- **Extracts from**: Nodes `CallToHuman`, `CallToHuman1`
- **Purpose**: Escalate to human operator
- **Triggers**: Urgency, dissatisfaction, out-of-scope

---

### Phase 2: Main Workflow Creation (Priority: HIGH)

#### 2.1 WhatsApp Patient Handler

**Source nodes to extract**:
- Webhook1 → Edit Fields1 → Switch
- Assistente Clínica + connected tools
- Evolution API2 (output)

**New structure**:
```
Webhook → Parse Message → Switch (text/image/audio) 
→ [Tool: Image OCR / Audio Transcription] 
→ Patient Assistant Agent 
→ [Tool: Message Formatter] 
→ [Tool: WhatsApp Send]
```

**Agents to include**:
- Assistente Clínica (main patient agent)

**Tools to connect**:
- MCP Calendar Tool
- Image OCR Tool
- Audio Transcription Tool
- Message Formatter Tool
- WhatsApp Send Tool
- Call to Human Tool

#### 2.2 Telegram Internal Assistant

**Source nodes to extract**:
- Receber Mensagem Telegram → Assistente clinica interno → Telegram

**New structure**:
```
Telegram Trigger 
→ Internal Assistant Agent 
→ [Tool: MCP Calendar / Google Tasks / WhatsApp Send] 
→ Telegram Response
```

**Agents to include**:
- Assistente Clínica Interno

**Tools to connect**:
- MCP Calendar Tool
- Google Tasks Tool
- WhatsApp Send Tool

#### 2.3 Appointment Confirmation Scheduler

**Source nodes to extract**:
- Gatilho diário1 → Google Calendar → Loop → Gerar Msg Confirmacao → Wait → REMINDER1

**New structure**:
```
Schedule Trigger (Cron) 
→ Google Calendar Fetch 
→ Loop Through Events 
→ Confirmation Agent 
→ [Tool: WhatsApp Send]
```

**Agents to include**:
- Assistente de Confirmação

**Tools to connect**:
- MCP Calendar Tool
- WhatsApp Send Tool

---

### Phase 3: Parameterization (Priority: MEDIUM)

Replace all hardcoded values with environment variables:

#### 3.1 System Message Updates

**Current issues**:
```javascript
// Hardcoded calendar link
"https://calendar.google.com/calendar/embed?src=a57a3781407f42b1ad7fe24ce76f558dc6c86fea5f349b7fd39747a2294c1654%40group.calendar.google.com..."

// Hardcoded phone numbers
"5511111111111@s.whatsapp.net"

// Hardcoded addresses
"Rua Rio Casca, 417 – Belo Horizonte, MG"

// Hardcoded task IDs
"bDQ5ZlNVV2lPQ3pYT3NsNA"
```

**Refactored**:
```javascript
// Use environment variables
"{{ $env.CLINIC_CALENDAR_PUBLIC_LINK }}"
"{{ $env.CLINIC_PHONE }}@s.whatsapp.net"
"{{ $env.CLINIC_ADDRESS }}"
"{{ $env.GOOGLE_TASKS_LIST_ID }}"
```

#### 3.2 Credential References

**Current issues**:
- Hardcoded credential IDs in nodes
- MCP endpoints with full URLs

**Refactored**:
- Use credential manager references
- Store MCP endpoints in environment variables

---

### Phase 4: Node Mapping Guide

This section maps original nodes to new workflows:

#### Patient Handler Workflow

| Original Node | New Location | Notes |
|--------------|--------------|-------|
| Webhook1 | Main: whatsapp-patient-handler | Keep as-is |
| Edit Fields1 | Main: whatsapp-patient-handler | Keep as-is |
| Switch | Main: whatsapp-patient-handler | Keep as-is |
| Assistente Clínica | Main: whatsapp-patient-handler | Update system message |
| Analyze an image | Tool: image-ocr-tool | Extract to tool |
| Analyze audio | Tool: audio-transcription-tool | Extract to tool |
| AI Agent (formatter) | Tool: message-formatter-tool | Extract to tool |
| Evolution API2 | Tool: whatsapp-send-tool | Extract to tool |
| CallToHuman | Tool: call-to-human-tool | Extract to tool |
| MCP Google Calendar2 | Tool: mcp-calendar-tool | Extract to tool |
| Postgres Chat Memory1 | Main: whatsapp-patient-handler | Keep, but simplify |
| Google Gemini Chat Model | Main: whatsapp-patient-handler | Keep as-is |

#### Internal Assistant Workflow

| Original Node | New Location | Notes |
|--------------|--------------|-------|
| Receber Mensagem Telegram | Main: telegram-internal-assistant | Keep as-is |
| Assistente clinica interno | Main: telegram-internal-assistant | Update system message |
| MCP Google Calendar | Tool: mcp-calendar-tool | Reuse from patient handler |
| Google Tasks | Main: telegram-internal-assistant | Keep as tool node |
| Telegram | Main: telegram-internal-assistant | Keep as-is |
| Postgres Chat Memory | Main: telegram-internal-assistant | Keep, but simplify |

#### Confirmation Scheduler Workflow

| Original Node | New Location | Notes |
|--------------|--------------|-------|
| Gatilho diário1 | Main: appointment-confirmation-scheduler | Keep as-is |
| Google Calendar | Main: appointment-confirmation-scheduler | Keep as-is |
| Loop | Main: appointment-confirmation-scheduler | Keep as-is |
| Gerar Msg Confirmacao | Main: appointment-confirmation-scheduler | Simplify |
| Wait | Main: appointment-confirmation-scheduler | Keep as-is |
| REMINDER1 | Tool: whatsapp-send-tool | Reuse tool |
| Assistente de confirmação | Main: appointment-confirmation-scheduler | Update system message |

#### Nodes to Remove (Duplicates)

These nodes are duplicates and should be removed:

| Node | Reason |
|------|--------|
| Assistente Clínica1 | Duplicate of Assistente Clínica |
| Assistente clinica interno1 | Duplicate of Assistente clinica interno |
| Webhook (duplicate) | Same as Webhook1 |
| Edit Fields | Duplicate of Edit Fields1 |
| Switch1 | Duplicate of Switch |
| Evolution API1 | Duplicate of Evolution API |
| Convert to File1 | Duplicate of Convert to File |
| Analyze an image1 | Duplicate of Analyze an image |
| Analyze audio1 | Duplicate of Analyze audio |
| AI Agent1 | Duplicate of AI Agent |
| AI Agent3 | Duplicate of AI Agent2 |
| CallToHuman1 | Duplicate of CallToHuman |
| REMINDER | Duplicate of REMINDER1 |
| Postgres Chat Memory2 | Duplicate of Postgres Chat Memory |
| Postgres Chat Memory3 | Duplicate of Postgres Chat Memory1 |
| Google Gemini Chat Model1-9 | Consolidate to 3 instances |

---

## Implementation Steps

### Step 1: Backup Original Workflow

```bash
cp workflows/original-monolithic-workflow.json workflows/original-monolithic-workflow.backup.json
```

### Step 2: Create Tool Workflows (Start with these)

1. **whatsapp-send-tool.json** (Critical dependency)
2. **message-formatter-tool.json** (Critical dependency)
3. **mcp-calendar-tool.json** (Critical dependency)
4. **call-to-human-tool.json** (Important)
5. **image-ocr-tool.json** (Important)
6. **audio-transcription-tool.json** (Important)

### Step 3: Create Main Workflows

1. **01-whatsapp-patient-handler.json**
2. **02-telegram-internal-assistant.json**
3. **03-appointment-confirmation-scheduler.json**

### Step 4: Update System Messages

Replace hardcoded values in all agent system messages with environment variable references.

### Step 5: Test Each Workflow

Test workflows individually before integration:

1. Test tool workflows with sample data
2. Test main workflows with tools disabled
3. Enable tools one by one and test
4. Perform end-to-end testing

### Step 6: Deploy and Monitor

1. Import workflows to production n8n
2. Activate workflows one at a time
3. Monitor execution logs
4. Gather user feedback
5. Iterate and improve

---

## Testing Strategy

### Unit Testing (Tool Workflows)

For each tool workflow:

1. Create test data
2. Execute workflow manually
3. Verify outputs match expected format
4. Test error handling

**Example: Test whatsapp-send-tool**

```json
{
  "instance_name": "test_instance",
  "remote_jid": "5511999999999@s.whatsapp.net",
  "message_text": "Test message"
}
```

Expected result: Message sent successfully

### Integration Testing (Main Workflows)

For each main workflow:

1. Test with real webhook data
2. Verify agent responses
3. Check tool integrations
4. Monitor execution time

**Example: Test whatsapp-patient-handler**

1. Send test WhatsApp message
2. Verify webhook received
3. Check agent processing
4. Confirm response sent

### End-to-End Testing

Test complete user journeys:

1. **Patient schedules appointment**
   - Send WhatsApp message
   - Verify calendar event created
   - Check confirmation message

2. **Staff reschedules patient**
   - Send Telegram command
   - Verify calendar updated
   - Check patient notified

3. **Daily confirmation**
   - Wait for cron trigger
   - Verify confirmations sent
   - Check message delivery

---

## Rollback Plan

If issues occur during deployment:

### Immediate Rollback

1. Deactivate new workflows
2. Reactivate original monolithic workflow
3. Monitor for stability

### Partial Rollback

1. Identify problematic workflow
2. Deactivate only that workflow
3. Keep working workflows active

### Data Recovery

1. Database backups available (automated daily)
2. Execution logs preserved for debugging
3. Redis cache can be cleared and rebuilt

---

## Success Metrics

Track these KPIs after refactoring:

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Workflow execution time | < 5s average | n8n execution logs |
| Error rate | < 1% | Execution failures / total |
| Message delivery rate | > 99% | Evolution API logs |
| Code duplication | 0% | Manual review |
| Maintainability score | A | Code review checklist |
| Response time | < 3s | User feedback |

---

## Maintenance Schedule

### Daily
- Monitor execution logs
- Check error notifications
- Verify message delivery

### Weekly
- Review performance metrics
- Check database size
- Update documentation

### Monthly
- Update Docker images
- Review security settings
- Backup encryption keys
- Performance optimization

---

## Next Steps After Refactoring

1. **Add automated testing**
   - Integration test suite
   - Regression testing
   - Performance benchmarks

2. **Implement monitoring**
   - Grafana dashboards
   - Sentry error tracking
   - Uptime monitoring

3. **Enhance features**
   - Multi-language support
   - Payment integration
   - Patient portal
   - Analytics dashboard

4. **Scale infrastructure**
   - Load balancing
   - Database replication
   - Redis clustering
   - CDN for assets

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-01  
**Author**: n8n Automation Team

