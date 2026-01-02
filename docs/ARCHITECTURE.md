# System Architecture

> **Proprietary Documentation**  
> Copyright © 2026. All Rights Reserved.  
> This document is confidential and intended for authorized clients only.

---

## Overview

The **Clinic Management Multi-Agent System** is a containerized, AI-powered automation platform designed for healthcare clinics. It provides intelligent patient communication via WhatsApp, internal staff tools via Telegram, and automated appointment management—all orchestrated through n8n workflows.

---

## Technology Stack

### Core Components

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Orchestration Engine** | n8n | latest | Workflow automation and AI agent orchestration |
| **Database** | PostgreSQL | 14+ | Persistent storage for configurations, chat history, FAQ cache |
| **Cache Layer** | Redis | 7+ | Session management and performance optimization |
| **WhatsApp Gateway** | Evolution API | latest | WhatsApp message sending/receiving |
| **AI/LLM** | Google Gemini 2.0 Flash | latest | Natural language understanding and generation |
| **Calendar** | Google Calendar + MCP | - | Appointment scheduling and availability |
| **Containerization** | Docker Compose | - | Multi-container orchestration |

---

## C4 Context Diagram

The following diagram illustrates how the system interacts with external actors and services:

```mermaid
C4Context
    title System Context Diagram - Clinic Management Multi-Agent System

    Person(patient, "Patient", "Clinic patient using WhatsApp")
    Person(staff, "Clinic Staff", "Internal team using Telegram")
    Person(manager, "Clinic Manager", "System administrator")

    System_Boundary(clinic_system, "Clinic Management System") {
        System(n8n, "n8n Workflow Engine", "Orchestrates all automation logic, AI agents, and integrations")
    }

    System_Ext(whatsapp, "WhatsApp", "Patient communication channel")
    System_Ext(telegram, "Telegram", "Internal staff communication")
    System_Ext(evolution, "Evolution API", "WhatsApp gateway service")
    System_Ext(gemini, "Google Gemini AI", "Natural language processing and generation")
    System_Ext(gcal, "Google Calendar", "Appointment scheduling")
    System_Ext(gtasks, "Google Tasks", "Task management")

    Rel(patient, whatsapp, "Sends messages via", "WhatsApp")
    Rel(whatsapp, evolution, "Messages forwarded to")
    Rel(evolution, n8n, "Webhook triggers", "HTTPS")
    
    Rel(n8n, gemini, "AI processing", "API")
    Rel(n8n, gcal, "Manages appointments", "API")
    Rel(n8n, gtasks, "Manages tasks", "API")
    Rel(n8n, evolution, "Sends responses", "API")
    Rel(evolution, whatsapp, "Delivers to")
    
    Rel(staff, telegram, "Interacts via")
    Rel(telegram, n8n, "Bot triggers", "Webhook")
    Rel(n8n, telegram, "Sends notifications", "Bot API")
    
    Rel(manager, n8n, "Configures system", "Web UI")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Container Architecture

```mermaid
graph TB
    subgraph "Docker Network: clinic_network"
        subgraph "Application Layer"
            N8N[n8n Container<br/>Port 5678<br/>Workflow Engine]
        end
        
        subgraph "Data Layer"
            PG[(PostgreSQL<br/>Port 5432<br/>Primary Database)]
            REDIS[(Redis<br/>Port 6379<br/>Cache & Sessions)]
        end
        
        subgraph "Gateway Layer"
            EVO[Evolution API<br/>Port 8080<br/>WhatsApp Gateway]
        end
    end
    
    subgraph "External Services"
        WA[WhatsApp<br/>Cloud]
        TG[Telegram<br/>Cloud]
        GM[Google Gemini<br/>AI API]
        GC[Google Calendar<br/>API]
    end
    
    N8N --> PG
    N8N --> REDIS
    N8N --> EVO
    EVO --> WA
    N8N --> TG
    N8N --> GM
    N8N --> GC
    
    style N8N fill:#ff6b6b
    style PG fill:#4ecdc4
    style REDIS fill:#ffe66d
    style EVO fill:#95e1d3
```

---

## Data Architecture

### Database Schema Overview

```mermaid
erDiagram
    TENANT_CONFIG ||--o{ TENANT_FAQ : has
    TENANT_CONFIG ||--o{ TENANT_SECRETS : has
    TENANT_CONFIG ||--o{ TENANT_ACTIVITY_LOG : has
    TENANT_CONFIG ||--o{ CHAT_MEMORY : has
    
    TENANT_CONFIG {
        uuid tenant_id PK
        varchar tenant_name
        varchar evolution_instance_name UK
        boolean is_active
        varchar clinic_name
        text clinic_address
        varchar google_calendar_id
        varchar google_tasks_list_id
        text system_prompt_patient
        text system_prompt_internal
        jsonb features
        int monthly_message_limit
    }
    
    TENANT_FAQ {
        uuid faq_id PK
        uuid tenant_id FK
        text question_normalized
        text answer
        text[] keywords
        varchar intent
        int view_count
        timestamp last_used_at
    }
    
    TENANT_SECRETS {
        uuid secret_id PK
        uuid tenant_id FK
        varchar secret_key
        text secret_value_encrypted
        varchar secret_type
    }
    
    CHAT_MEMORY {
        uuid id PK
        varchar session_id
        text message
        varchar role
        timestamp created_at
        uuid tenant_id FK
    }
```

### Multi-Tenant Isolation Strategy

1. **Configuration Isolation**: Each tenant has a unique `tenant_id` and `evolution_instance_name`
2. **Data Isolation**: All queries filtered by `tenant_id` via tenant-config-loader sub-workflow
3. **Memory Isolation**: Chat sessions prefixed with `{tenant_id}_{user_phone}`
4. **FAQ Isolation**: FAQ cache scoped per tenant with dedicated indexes
5. **Optional**: Row-Level Security (RLS) policies for additional database-level isolation

---

## Workflow Architecture

### Main Workflows

```mermaid
graph LR
    subgraph "Entry Points"
        WH[WhatsApp<br/>Webhook]
        TH[Telegram<br/>Webhook]
        CRON[Schedule<br/>Trigger]
    end
    
    subgraph "Main Workflows"
        WF1[01-whatsapp-patient<br/>-handler-optimized]
        WF2[02-telegram-internal<br/>-assistant]
        WF3[03-appointment<br/>-confirmation]
        WF4[04-error<br/>-handler]
    end
    
    subgraph "Sub-Workflows"
        SUB[tenant-config<br/>-loader]
    end
    
    subgraph "Tool Workflows"
        T1[Calendar Tools]
        T2[Communication Tools]
        T3[AI Processing Tools]
        T4[Escalation Tools]
    end
    
    WH --> WF1
    TH --> WF2
    CRON --> WF3
    
    WF1 --> SUB
    WF2 --> SUB
    WF3 --> SUB
    
    WF1 --> T1
    WF1 --> T2
    WF1 --> T3
    WF1 --> T4
    
    WF2 --> T1
    WF2 --> T2
    
    WF1 -.error.-> WF4
    WF2 -.error.-> WF4
    WF3 -.error.-> WF4
    
    style WF1 fill:#ff6b6b
    style WF2 fill:#4ecdc4
    style WF3 fill:#95e1d3
    style WF4 fill:#ffd93d
```

### AI Optimization Layer

The system includes an intelligent routing mechanism that reduces AI API costs by 70-75%:

```mermaid
flowchart TD
    START([User Message]) --> PARSE[Parse Webhook]
    PARSE --> LOAD[Load Tenant Config]
    LOAD --> INTENT[Intent Classifier<br/>Pattern Matching]
    
    INTENT --> CACHE{FAQ Cache<br/>Check}
    
    CACHE -->|Hit 65-80%| CACHED[Use Cached Answer<br/>Cost: $0.001<br/>Time: 50ms]
    CACHE -->|Miss 20-35%| AI[AI Agent Processing<br/>Cost: $0.012<br/>Time: 1.5s]
    
    AI --> LEARN[Cache Answer<br/>for Future Use]
    LEARN --> FORMAT[Format Message]
    CACHED --> FORMAT
    
    FORMAT --> SEND[Send WhatsApp Response]
    SEND --> END([Complete])
    
    style INTENT fill:#ffe66d
    style CACHE fill:#4ecdc4
    style CACHED fill:#95e1d3
    style AI fill:#ff6b6b
    style LEARN fill:#a8e6cf
```

**Cost Impact**:
- **Before Optimization**: $0.015 per message (2 AI calls)
- **After Optimization**: $0.004 per message average (0.3 AI calls)
- **Savings**: 70-75% reduction in AI costs

---

## Message Flow

### Patient Communication Flow

```mermaid
sequenceDiagram
    autonumber
    
    participant P as Patient
    participant W as WhatsApp
    participant E as Evolution API
    participant N as n8n Engine
    participant DB as PostgreSQL
    participant AI as Gemini AI
    participant GC as Google Calendar
    
    P->>W: Sends message
    W->>E: Forwards message
    E->>N: Webhook trigger
    
    N->>DB: Load tenant config
    DB-->>N: Tenant settings
    
    N->>N: Intent classification
    N->>DB: Check FAQ cache
    
    alt Cache Hit (65-80%)
        DB-->>N: Cached answer
    else Cache Miss (20-35%)
        N->>AI: Process with LLM
        AI-->>N: Generated response
        
        opt If appointment-related
            N->>GC: Check availability
            GC-->>N: Available slots
        end
        
        N->>DB: Cache answer
    end
    
    N->>N: Format for WhatsApp
    N->>E: Send response
    E->>W: Deliver message
    W->>P: Receives response
```

### Internal Staff Flow

```mermaid
sequenceDiagram
    autonumber
    
    participant S as Staff Member
    participant T as Telegram
    participant N as n8n Engine
    participant AI as Gemini AI
    participant GC as Google Calendar
    participant GT as Google Tasks
    participant E as Evolution API
    participant P as Patient
    
    S->>T: Sends command<br/>(e.g., "Remarcar João para 14h")
    T->>N: Bot webhook
    
    N->>AI: Parse intent + extract data
    AI-->>N: Action: Reschedule + Patient: João + Time: 14h
    
    N->>GC: Update appointment
    GC-->>N: Confirmation
    
    N->>E: Send WhatsApp to patient
    E->>P: "Sua consulta foi remarcada para 14h"
    
    N->>T: Confirm to staff
    T->>S: "✅ Remarcado com sucesso"
```

---

## Security Architecture

### Authentication & Authorization

```mermaid
graph TD
    subgraph "External Access"
        WH[WhatsApp Webhook<br/>Evolution API Key]
        TH[Telegram Webhook<br/>Bot Token]
        UI[n8n Web UI<br/>Basic Auth]
    end
    
    subgraph "Service Access"
        N8N[n8n Engine]
    end
    
    subgraph "Credential Management"
        CRED[n8n Credentials Store<br/>Encrypted at Rest]
    end
    
    subgraph "External APIs"
        GEMINI[Google Gemini<br/>API Key]
        GCAL[Google Calendar<br/>OAuth2]
        EVO[Evolution API<br/>API Key]
    end
    
    WH --> N8N
    TH --> N8N
    UI --> N8N
    
    N8N --> CRED
    CRED --> GEMINI
    CRED --> GCAL
    CRED --> EVO
    
    style CRED fill:#ff6b6b
    style N8N fill:#4ecdc4
```

### Data Protection

1. **Encryption at Rest**: PostgreSQL with encrypted volumes
2. **Encryption in Transit**: HTTPS/TLS for all external API calls
3. **Credential Storage**: n8n encrypted credentials vault
4. **Secret Management**: Optional `tenant_secrets` table with encrypted values
5. **Network Isolation**: Docker internal network, only necessary ports exposed
6. **Access Control**: Evolution API instance name acts as tenant identifier

---

## Scalability Considerations

### Current Architecture

- **Single-Server Deployment**: All containers on one host
- **Vertical Scaling**: Increase CPU/RAM for n8n container
- **Database**: Single PostgreSQL instance with connection pooling

### Scale-Out Strategy (Future)

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[NGINX/Traefik]
    end
    
    subgraph "n8n Cluster"
        N1[n8n Instance 1]
        N2[n8n Instance 2]
        N3[n8n Instance 3]
    end
    
    subgraph "Data Layer"
        PG_PRIMARY[(PostgreSQL<br/>Primary)]
        PG_REPLICA[(PostgreSQL<br/>Read Replica)]
        REDIS_CLUSTER[(Redis Cluster)]
    end
    
    LB --> N1
    LB --> N2
    LB --> N3
    
    N1 --> PG_PRIMARY
    N2 --> PG_PRIMARY
    N3 --> PG_PRIMARY
    
    N1 --> PG_REPLICA
    N2 --> PG_REPLICA
    N3 --> PG_REPLICA
    
    N1 --> REDIS_CLUSTER
    N2 --> REDIS_CLUSTER
    N3 --> REDIS_CLUSTER
```

**Current Capacity** (Single Server - 4 vCPU, 8GB RAM):
- ~10-20 tenants
- ~50,000 messages/month total
- ~100 concurrent conversations

**Recommended Scaling Triggers**:
- CPU usage > 70% sustained
- Database connections > 80% of pool
- Response time > 3s P95
- More than 20 active tenants

---

## Monitoring & Observability

### Key Metrics

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| Response Time (P95) | < 2s | > 5s |
| Error Rate | < 1% | > 5% |
| FAQ Cache Hit Rate | > 60% | < 40% |
| AI API Cost/Message | < $0.005 | > $0.015 |
| Database Connection Pool | < 80% | > 90% |
| Disk Usage | < 70% | > 85% |

### Logging Strategy

```mermaid
graph LR
    N8N[n8n Executions] --> JSON[JSON Logs]
    PG[PostgreSQL] --> PGLOG[Query Logs]
    REDIS[Redis] --> REDISLOG[Slow Log]
    EVO[Evolution API] --> EVOLOG[Access Logs]
    
    JSON --> AGENT[Log Aggregator<br/>Optional: Loki/ELK]
    PGLOG --> AGENT
    REDISLOG --> AGENT
    EVOLOG --> AGENT
    
    AGENT --> DASH[Grafana Dashboard]
    
    style DASH fill:#4ecdc4
```

---

## Disaster Recovery

### Backup Strategy

1. **Database**: Automated daily backups via `pg_dump`
2. **n8n Data**: Volume snapshots of `/home/node/.n8n`
3. **Environment Configs**: `.env` file backup
4. **Retention**: 7 daily, 4 weekly, 12 monthly

### Recovery Procedure

```bash
# 1. Restore database
psql $DATABASE_URL < backup_YYYYMMDD.sql

# 2. Restore n8n data
docker cp backup_n8n_data.tar n8n:/home/node/.n8n

# 3. Restart services
docker-compose restart

# 4. Verify health
curl http://localhost:5678/healthz
```

**Recovery Time Objective (RTO)**: < 1 hour  
**Recovery Point Objective (RPO)**: < 24 hours

---

## Performance Optimization

### Database Indexes

All critical query paths are indexed:
- `tenant_config.evolution_instance_name` (unique)
- `tenant_faq.tenant_id, question_normalized` (composite)
- `tenant_faq.keywords` (GIN index for array matching)
- `langchain_pg_memory.tenant_id, session_id` (composite)

### Caching Strategy

1. **FAQ Cache**: PostgreSQL-backed (persistent)
2. **Session Data**: Redis (ephemeral)
3. **Tenant Config**: Loaded per workflow execution (minimal overhead)

### Query Optimization

- Tenant config: Single query with all fields (1 DB hit)
- FAQ lookup: Indexed query with ILIKE (< 5ms)
- Chat memory: Window-based retrieval (last 5 messages)

---

## Technology Choices - Rationale

| Decision | Rationale |
|----------|-----------|
| **n8n vs Zapier** | Self-hosted, no per-execution cost, full workflow control, AI agent support |
| **PostgreSQL vs MongoDB** | ACID compliance critical for appointments, strong indexing, jsonb for flexibility |
| **Redis vs Memcached** | Richer data structures, persistence options, pub/sub capabilities |
| **Evolution API vs Twilio** | WhatsApp Cloud API support, self-hosted option, Brazil-friendly |
| **Gemini vs OpenAI** | Lower cost, faster responses, multimodal support (vision + audio) |
| **Docker Compose vs Kubernetes** | Simpler operations, sufficient for 10-20 tenant scale, lower overhead |

---

## Compliance & Data Privacy

### LGPD/GDPR Considerations

1. **Data Minimization**: Only essential patient data stored
2. **Right to Erasure**: Cascade delete on tenant removal
3. **Data Portability**: PostgreSQL dump per tenant
4. **Consent Management**: Tracked via WhatsApp opt-in
5. **Audit Trail**: `tenant_activity_log` table

### PHI/PII Handling

- **Patient Names**: Stored in chat memory (encrypted at rest)
- **Phone Numbers**: Hashed for session keys
- **Medical Data**: NOT stored (appointment metadata only)
- **Location**: Clinic address only (no patient addresses)

---

## Support & Maintenance

### Update Strategy

1. **n8n Updates**: Monthly review, staging test, production deploy
2. **Workflow Updates**: Versioned via git, deployed via import
3. **Database Migrations**: Incremental scripts in `scripts/migrations/`
4. **Dependency Updates**: Quarterly security patches

### Health Checks

```bash
# n8n health
curl http://localhost:5678/healthz

# PostgreSQL
docker exec clinic_postgres pg_isready

# Redis
docker exec clinic_redis redis-cli ping

# Evolution API
curl http://localhost:8080/instance/connectionState/clinic_instance
```

---

**Document Version**: 1.0  
**Last Updated**: 2026-01-01  
**Classification**: Proprietary & Confidential
