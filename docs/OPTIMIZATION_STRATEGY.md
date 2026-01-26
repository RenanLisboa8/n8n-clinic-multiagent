# AI Cost Optimization Strategy

## Overview

This document describes the optimization strategy implemented to reduce AI/LLM costs by up to 80% while maintaining conversational quality.

## Problem Statement

The original implementation called the AI agent for every single message, including:
- Simple menu selections ("1", "2", "3")
- Confirmations ("sim", "não")
- Navigation commands ("voltar")
- Greetings and FAQ responses

This resulted in unnecessary API costs and slower response times.

## Solution Architecture

### 1. State Machine Approach

Instead of using AI to determine user intent, we use a database-driven state machine:

```
┌─────────────┐
│   initial   │ ─────────────────────────────────────────┐
└─────────────┘                                          │
       │ User selects "1" (schedule)                     │
       ▼                                                 │
┌─────────────────┐                                      │
│ awaiting_service│ ◄──────────────────┐                 │
└─────────────────┘                    │                 │
       │ User selects service number   │ "voltar"        │
       ▼                               │                 │
┌─────────────────────┐                │                 │
│awaiting_professional│ ───────────────┘                 │
└─────────────────────┘                                  │
       │ User selects professional                       │
       ▼                                                 │
┌─────────────────┐                                      │
│  awaiting_date  │                                      │
└─────────────────┘                                      │
       │ User selects time slot                          │
       ▼                                                 │
┌──────────────────────┐                                 │
│awaiting_confirmation │                                 │
└──────────────────────┘                                 │
       │ "sim" / "não"                                   │
       ▼                                                 │
┌─────────────┐                                          │
│  completed  │ ─────────────────────────────────────────┘
└─────────────┘
```

### 2. Database Tables

#### `conversation_state`
Tracks the current state of each conversation:
- `current_state` - Current state in the flow
- `state_data` - JSON with collected information
- `selected_service_id` - Service selected by user
- `selected_professional_id` - Professional selected
- `selected_slot` - Date/time selected
- `expires_at` - Auto-cleanup after 24 hours

#### `state_definitions`
Defines valid states and transitions:
- `state_name` - Unique state identifier
- `valid_inputs` - JSON mapping inputs to actions
- `next_states` - JSON mapping actions to next states
- `template_key` - Response template to use
- `requires_ai` - Whether AI is needed

#### `response_templates`
Pre-defined responses for each scenario:
- Supports variable substitution (`{{variable}}`)
- Multi-tenant (each clinic can customize)
- Categorized by type (greeting, menu, confirmation, etc.)

### 3. Flow Decision Logic

```javascript
// Pseudo-code for message processing
function processMessage(input) {
  // 1. Get current state from database
  const state = getConversationState(tenantId, remoteJid);
  
  // 2. Attempt state transition
  const transition = transitionState(tenantId, remoteJid, input);
  
  // 3. Check if AI is needed
  if (transition.requires_ai) {
    // Only complex queries go to AI
    return callAIAgent(input, context);
  }
  
  // 4. Get template response
  const template = getTemplate(tenantId, transition.template_key);
  
  // 5. Merge with dynamic data if needed
  return mergeTemplateWithData(template, state.state_data);
}
```

## When AI is Used

AI is only called in these scenarios:

1. **Complex Queries** - Questions longer than 20 characters with question marks
2. **Unrecognized Inputs** - When user input doesn't match any valid option
3. **Escalation** - When explicitly triggered
4. **Context-Dependent Responses** - Rare cases needing contextual understanding

## Cost Comparison

### Before Optimization
| Scenario | AI Calls | Estimated Cost/1000 msgs |
|----------|----------|-------------------------|
| Complete booking flow | 8-12 calls | $0.80 - $1.20 |
| FAQ query | 2-3 calls | $0.20 - $0.30 |
| Simple greeting | 1 call | $0.10 |

### After Optimization
| Scenario | AI Calls | Estimated Cost/1000 msgs |
|----------|----------|-------------------------|
| Complete booking flow | 0-1 calls | $0.00 - $0.10 |
| FAQ query | 0-1 calls | $0.00 - $0.10 |
| Simple greeting | 0 calls | $0.00 |

**Estimated Savings: 80-90%**

## Implementation Files

### Migrations
- `scripts/migrations/021_response_templates.sql` - Template system
- `scripts/migrations/022_conversation_state.sql` - State machine

### Workflows
- `workflows/main/01-whatsapp-optimized-state-machine.json` - Optimized flow

## Configuration

### Adding New Templates

```sql
INSERT INTO response_templates (tenant_id, template_key, template_text, category)
VALUES (
  'your-tenant-id',
  'custom_greeting',
  'Olá {{patient_name}}! Bem-vindo à {{clinic_name}}.',
  'greeting'
);
```

### Customizing State Transitions

```sql
UPDATE state_definitions
SET valid_inputs = '{"1": "option_a", "2": "option_b", "custom": "special"}'
WHERE state_name = 'your_state';
```

## Monitoring

### Key Metrics to Track

1. **AI Call Rate** - Percentage of messages requiring AI
2. **Template Hit Rate** - Percentage using templates
3. **State Transition Success** - Valid transitions vs errors
4. **Response Time** - Template vs AI response times

### Useful Queries

```sql
-- AI usage rate
SELECT 
  DATE(created_at) as date,
  COUNT(*) FILTER (WHERE requires_ai) as ai_calls,
  COUNT(*) as total_messages,
  ROUND(100.0 * COUNT(*) FILTER (WHERE requires_ai) / COUNT(*), 2) as ai_percentage
FROM message_log
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- State distribution
SELECT current_state, COUNT(*) as count
FROM conversation_state
WHERE expires_at > NOW()
GROUP BY current_state
ORDER BY count DESC;
```

## Fallback Strategy

If the state machine fails:
1. Log the error for debugging
2. Reset conversation to initial state
3. Fall back to AI agent if critical
4. Send generic "let me help you" message

## Best Practices

1. **Keep templates short** - WhatsApp has character limits
2. **Test all transitions** - Ensure no dead-end states
3. **Monitor AI usage** - Alert if AI rate exceeds 20%
4. **Regular cleanup** - Run `cleanup_expired_conversation_states()` daily
5. **Template versioning** - Update templates without breaking existing flows

## Migration Path

To migrate from the AI-heavy workflow:

1. Apply migrations 021 and 022
2. Test with a small percentage of traffic
3. Monitor AI usage and costs
4. Gradually increase traffic to optimized flow
5. Archive old workflow when confident

## Troubleshooting

### "State not found" errors
- Check tenant_id is valid
- Ensure migrations were applied
- Verify database connectivity

### "Template not found"
- Confirm template_key exists for tenant
- Check fallback to default templates
- Review template category

### Unexpected AI calls
- Review state definitions for missing inputs
- Check input normalization (lowercase, trim)
- Add missing valid_inputs mappings