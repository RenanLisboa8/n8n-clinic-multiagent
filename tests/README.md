# Testing Guide

## Overview
This directory contains test workflows and sample payloads for validating the Multi-Agent Clinic Management System.

## Contents

### Test Workflows
- **`mock-test-workflow.json`** - Automated test suite that simulates patient interactions

### Sample Payloads
- **`text-message.json`** - Sample text message from WhatsApp
- **`audio-message.json`** - Sample audio message payload
- **`image-message.json`** - Sample image message with caption

## Running Tests

### Method 1: Using the Mock Test Workflow

1. Import `mock-test-workflow.json` into n8n
2. Ensure all main workflows are active
3. Click "Execute Workflow" in the n8n interface
4. Check Telegram for test results summary

### Method 2: Using cURL with Sample Payloads

Test individual message types:

```bash
# Test text message
curl -X POST http://localhost:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/text-message.json

# Test audio message
curl -X POST http://localhost:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/audio-message.json

# Test image message
curl -X POST http://localhost:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/image-message.json
```

### Method 3: Docker Compose Test Environment

Run tests in isolated environment:

```bash
# Start all services
docker-compose up -d

# Wait for services to be healthy
docker-compose ps

# Run test suite
docker-compose exec n8n n8n execute --id=<mock-test-workflow-id>
```

## Test Scenarios Covered

The mock test workflow includes:

1. ✅ **Text Message - Schedule Appointment** - Patient requests new appointment
2. ✅ **Text Message - Reschedule** - Patient wants to change existing appointment
3. ✅ **Text Message - Cancel** - Patient cancels appointment
4. ✅ **Text Message - Check Availability** - Patient asks about available slots
5. ✅ **Audio Message - Voice Booking** - Patient sends voice message
6. ✅ **Image Message - Prescription OCR** - Patient sends image of prescription
7. ✅ **Emergency - Escalation Trigger** - Urgent message triggers human escalation

## Expected Behaviors

### Successful Test Results
- All webhooks return HTTP 200
- Agent responses are formatted correctly
- Calendar operations execute without errors
- Escalations trigger Telegram alerts
- No ghost nodes or disconnected flows

### Common Issues

**Webhook Not Found (404)**
- Ensure WhatsApp Patient Handler workflow is active
- Check webhook path matches configuration

**Timeout Errors**
- Increase `N8N_EXECUTIONS_TIMEOUT` in .env
- Check external API connectivity (Google, Evolution)

**Credential Errors**
- Verify all credentials are configured in n8n
- Check credential IDs match in workflow JSONs

## Validation Checklist

Before deploying to production:

- [ ] All test scenarios pass (100% success rate)
- [ ] Response times < 5 seconds average
- [ ] Error handler triggers correctly
- [ ] Telegram notifications arrive
- [ ] WhatsApp messages are sent
- [ ] Calendar events created properly
- [ ] Memory/context maintained across messages
- [ ] No duplicate agent responses
- [ ] Escalations work as expected

## Continuous Integration

### GitHub Actions Example

```yaml
name: n8n Workflow Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Start n8n stack
        run: docker-compose up -d
      - name: Wait for health
        run: sleep 30
      - name: Run tests
        run: |
          curl -f http://localhost:5678/healthz
          # Import and execute test workflow
      - name: Cleanup
        run: docker-compose down
```

## Monitoring Test Results

Test execution logs can be found in:
- n8n UI: **Executions** tab
- Telegram: Summary messages
- Docker logs: `docker-compose logs n8n`

## Adding New Tests

To add a new test scenario:

1. Create sample payload in `sample-payloads/`
2. Add scenario to `mock-test-workflow.json` test array
3. Document expected behavior
4. Run and validate

## Performance Benchmarks

Target metrics:
- Webhook response: < 200ms
- Agent processing: < 3s
- End-to-end flow: < 5s
- Success rate: > 99%

## Support

If tests fail unexpectedly:
1. Check service health: `docker-compose ps`
2. Review logs: `docker-compose logs`
3. Verify credentials in n8n UI
4. Check external API status
5. Consult main README.md troubleshooting section

