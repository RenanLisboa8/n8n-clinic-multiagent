# Monitoring & Alerting

## Overview

The system uses Telegram alerts for real-time error notifications and PostgreSQL for structured logging.

---

## Error Handler (`04-error-handler.json`)

### How It Works

1. Any workflow with `errorWorkflow` configured routes failures to the error handler
2. Error handler extracts `tenant_id` from the failed execution data
3. Queries `tenant_config` to find the tenant's Telegram chat ID
4. Sends formatted alert via `telegram-client.json` sub-workflow
5. If tenant cannot be identified, sends to `$env.FALLBACK_TELEGRAM_CHAT_ID` (system admin)

### Telegram Alert Format

```
🚨 WORKFLOW ERROR

Workflow: 01 - WhatsApp Main Handler
Error: TypeError: Cannot read property 'tenant_id' of undefined
Node: Parse Webhook Data
Time: 2026-02-13T10:30:00.000Z

Execution: https://n8n.example.com/execution/12345
```

### Fallback Alerts

When `tenant_id` cannot be resolved:
```
⚠️ UNRESOLVED ERROR (No Tenant)

Workflow: [workflow name]
Error: [error message]
Time: [timestamp]
```

---

## Activity Logging

### `tenant_activity_log` Table

All significant events are logged:

```sql
SELECT * FROM tenant_activity_log
WHERE tenant_id = '<uuid>'
ORDER BY created_at DESC
LIMIT 50;
```

Fields: `tenant_id`, `activity_type`, `activity_data` (JSONB), `created_at`

---

## Message Queue Monitoring

### Check Queue Health

```sql
-- Pending messages (should be near 0 in healthy system)
SELECT status, COUNT(*) FROM message_queue
GROUP BY status;

-- Stuck messages (processing for >5 minutes)
SELECT * FROM message_queue
WHERE status = 'processing'
  AND created_at < NOW() - INTERVAL '5 minutes';
```

### Check Conversation Locks

```sql
-- Active locks
SELECT * FROM conversation_locks
WHERE expires_at > NOW();

-- Expired locks (should be cleaned by scheduler)
SELECT COUNT(*) FROM conversation_locks
WHERE expires_at < NOW();
```

### Cleanup Expired Locks

Run periodically (or add to n8n scheduler):

```sql
SELECT cleanup_expired_locks();
```

---

## Key Metrics to Monitor

| Metric | Query | Healthy Value |
|---|---|---|
| Queue backlog | `SELECT COUNT(*) FROM message_queue WHERE status = 'pending'` | < 10 |
| Duplicate rate | `SELECT COUNT(*) FROM message_queue WHERE status = 'duplicate'` | Informational |
| Failed messages | `SELECT COUNT(*) FROM message_queue WHERE status = 'failed'` | 0 |
| Active locks | `SELECT COUNT(*) FROM conversation_locks WHERE expires_at > NOW()` | < 50 |
| Error rate (24h) | `SELECT COUNT(*) FROM tenant_activity_log WHERE activity_type = 'error' AND created_at > NOW() - INTERVAL '24h'` | < 5 |

---

## n8n Execution Monitoring

### Via n8n UI
- Navigate to **Executions** tab to see all workflow runs
- Filter by workflow, status (success/error), and date range

### Via PostgreSQL
n8n stores execution data in its own tables. For custom monitoring:

```sql
-- Recent failed executions (n8n internal table)
SELECT id, "workflowId", finished, "stoppedAt", status
FROM execution_entity
WHERE status = 'error'
  AND "stoppedAt" > NOW() - INTERVAL '24h'
ORDER BY "stoppedAt" DESC;
```

---

## Recommended Monitoring Stack

For production deployments, consider adding:

1. **Uptime monitoring**: Ping n8n health endpoint (`/healthz`)
2. **Database monitoring**: pg_stat_activity for connection pool health
3. **Disk usage alerts**: PostgreSQL WAL and data directory growth
4. **Memory alerts**: n8n worker memory consumption
