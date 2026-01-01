# Workflow Tools

This directory contains reusable tool workflows that can be called from main workflows.

## Tool Categories

### 📞 Communication Tools (`communication/`)

#### `whatsapp-send-tool.json`
Send WhatsApp messages via Evolution API.

**Inputs:**
- `instance_name` (string, optional): Evolution API instance name (defaults to env var)
- `remote_jid` (string, required): Phone number in format `5511999999999@s.whatsapp.net`
- `message_text` (string, required): Message content

**Outputs:**
- `success` (boolean): Whether message was sent
- `message_id` (string): WhatsApp message ID
- `status` (string): "sent"
- `timestamp` (string): ISO 8601 timestamp

**Usage Example:**
```json
{
  "remote_jid": "5511999999999@s.whatsapp.net",
  "message_text": "Sua consulta foi confirmada!"
}
```

---

#### `message-formatter-tool.json`
Format messages for WhatsApp markdown compatibility.

**Inputs:**
- `raw_text` (string, required): Unformatted text from AI agent

**Outputs:**
- `formatted_text` (string): WhatsApp-compatible markdown

**Transformations:**
- `**bold**` → `*bold*`
- `# Header` → `Header`
- Preserves line breaks and emojis

---

#### `telegram-notify-tool.json`
Send notifications to staff via Telegram.

**Inputs:**
- `chat_id` (string, required): Telegram chat ID
- `message` (string, required): Notification message
- `notification_type` (string, optional): "info", "warning", or "error"

**Outputs:**
- `success` (boolean): Whether notification was sent
- `message_id` (string): Telegram message ID

---

### 🤖 AI Processing Tools (`ai-processing/`)

#### `image-ocr-tool.json`
Extract text from images using Google Gemini Vision.

**Inputs:**
- `image_url` (string, required): Public URL of the image

**Outputs:**
- `transcribed_text` (string): Extracted text content
- `image_description` (string): Description of image context
- `success` (boolean): Processing status
- `timestamp` (string): Processing time

**Use Cases:**
- Medical prescriptions
- Lab results
- Handwritten notes
- ID documents

---

#### `audio-transcription-tool.json`
Transcribe audio messages using Google Gemini Audio.

**Inputs:**
- `instance_name` (string, optional): Evolution API instance
- `message_id` (string, required): Audio message ID

**Outputs:**
- `transcribed_text` (string): Audio transcription
- `success` (boolean): Processing status
- `timestamp` (string): Processing time

**Flow:**
1. Download audio from Evolution API
2. Convert base64 to binary
3. Transcribe with Gemini Audio
4. Return text

---

### 📅 Calendar Tools (`calendar/`)

#### `mcp-calendar-tool.json`
Unified Google Calendar interface via MCP protocol.

**Actions:**
- `get_all`: List events in date range
- `get_availability`: Check free slots
- `create`: Create new event
- `update`: Update existing event
- `delete`: Delete event
- `get`: Get single event details

**Inputs (vary by action):**
- `action` (string, required): Action to perform
- `date_start`, `date_end` (datetime): For get_all, get_availability
- `event_id` (string): For update, delete, get
- `title`, `description` (string): For create, update

**Outputs:**
- Event data or confirmation message

---

### 🚨 Escalation Tools (`escalation/`)

#### `call-to-human-tool.json`
Escalate conversation to human operator.

**Inputs:**
- `patient_name` (string, required): Patient's name
- `phone_number` (string, required): Patient's WhatsApp number
- `last_message` (string, required): Most recent message
- `reason` (string, required): Escalation reason

**Escalation Triggers:**
- Medical urgency keywords
- Patient dissatisfaction
- Request to speak with human
- Out-of-scope topics

**Outputs:**
- Notification sent to staff via Telegram
- Confirmation message to patient

---

## Tool Development Guidelines

### Creating a New Tool

1. **Define Clear Interface**
   - Document required inputs
   - Define expected outputs
   - Specify error cases

2. **Use Execute Workflow Trigger**
   ```json
   {
     "parameters": {},
     "type": "n8n-nodes-base.executeWorkflowTrigger"
   }
   ```

3. **Add Error Handling**
   - Try/Catch nodes for external APIs
   - Default values for optional inputs
   - Clear error messages

4. **Follow Naming Convention**
   - `[function]-tool.json`
   - Lowercase with hyphens
   - Descriptive name

5. **Add Documentation**
   - Update this README
   - Add inline comments in workflow
   - Include usage examples

### Testing Tools

Test each tool individually:

```bash
# In n8n UI:
1. Open tool workflow
2. Click "Execute Workflow" button
3. Provide test inputs
4. Verify outputs match expected format
```

### Tool Best Practices

✅ **DO:**
- Keep tools focused (single responsibility)
- Use environment variables for configuration
- Return consistent output format
- Add retry logic for external APIs
- Log important events

❌ **DON'T:**
- Mix multiple responsibilities in one tool
- Hardcode credentials or sensitive data
- Skip error handling
- Create circular tool dependencies
- Forget to document changes

---

## Tool Dependencies

### Credentials Required

Tools use these n8n credentials:
- **Evolution API**: For WhatsApp operations
- **Google Gemini API**: For AI processing
- **Telegram Bot**: For notifications
- **Google Calendar OAuth2**: For calendar operations
- **PostgreSQL**: For chat memory (main workflows)

### Environment Variables

Tools reference these env vars:
- `EVOLUTION_INSTANCE_NAME`: Default WhatsApp instance
- `TELEGRAM_INTERNAL_CHAT_ID`: Staff notification target
- `MCP_CALENDAR_ENDPOINT`: Calendar API endpoint
- `CLINIC_NAME`, `CLINIC_ADDRESS`: Business info

---

## Tool Import Order

When importing tools, follow this order to satisfy dependencies:

1. **Communication Tools** (no dependencies)
   - message-formatter-tool.json
   - whatsapp-send-tool.json
   - telegram-notify-tool.json

2. **Calendar Tools** (no dependencies)
   - mcp-calendar-tool.json

3. **AI Processing Tools** (depends on communication)
   - image-ocr-tool.json
   - audio-transcription-tool.json

4. **Escalation Tools** (depends on communication)
   - call-to-human-tool.json

---

## Troubleshooting

### Tool Not Found Error

**Problem:** Main workflow cannot find tool workflow

**Solution:**
1. Verify tool workflow is saved and active
2. Check tool workflow ID matches in main workflow
3. Ensure tool has "Execute Workflow Trigger" node

### Credential Errors

**Problem:** Tool fails with authentication error

**Solution:**
1. Update credential IDs in tool JSON
2. Verify credentials are valid in n8n settings
3. Check credential permissions

### Timeout Errors

**Problem:** Tool execution times out

**Solution:**
1. Increase timeout in tool settings
2. Add retry logic for external API calls
3. Check external service health

---

## Contributing

When adding new tools:

1. Follow the structure of existing tools
2. Update this README with tool documentation
3. Add tags: `tool` and category (`communication`, `ai-processing`, etc.)
4. Test thoroughly before committing
5. Update REFACTORING_GUIDE.md if applicable

---

**Last Updated:** 2026-01-01  
**Version:** 1.0

