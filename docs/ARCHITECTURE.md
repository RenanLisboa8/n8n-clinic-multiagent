# Arquitetura do Sistema

> **Documentação Proprietária**  
> Copyright © 2026. Todos os Direitos Reservados.  
> Este documento é confidencial e destinado apenas a clientes autorizados.

---

## Visão Geral

O **Sistema Multi-Agente de Gestão de Clínicas** é uma plataforma de automação via **n8n**, com atendimento a pacientes por **WhatsApp** e operações internas via **Telegram**. O sistema é **multi-tenant**, **multi-profissional** e **multi-serviço**, com agendamentos por **Google Calendar**.

---

## Stack Tecnológico

| Componente | Tecnologia | Propósito |
|------------|------------|-----------|
| Orquestração | n8n | Workflows e agentes |
| Banco | PostgreSQL | Configurações, catálogos, FAQs |
| Cache | Redis | Sessões e otimizações |
| WhatsApp Gateway | Evolution API | Mensagens e webhooks |
| IA | Google Gemini | Processamento de linguagem |
| Calendário | Google Calendar | Agendamentos |
| Contêiner | Docker Compose | Execução local/servidor |

---

## Diagrama de Contexto

```mermaid
graph TB
    PAT[👤 Paciente] --> WAPP[WhatsApp]
    STAFF[👥 Equipe] --> TG[Telegram]
    WAPP --> EVO[Evolution API]
    TG --> N8N[n8n]
    EVO --> N8N
    N8N --> GEMINI[Google Gemini]
    N8N --> GCAL[Google Calendar]
    N8N --> GTASKS[Google Tasks]
    N8N --> PG[(PostgreSQL)]
    N8N --> REDIS[(Redis)]
```

---

## Arquitetura de Containers

```mermaid
graph TB
    subgraph DOCKER["Docker Compose"]
        N8N[n8n]
        PG[(PostgreSQL)]
        REDIS[(Redis)]
        EVO[Evolution API]
    end
    N8N --> PG
    N8N --> REDIS
    N8N --> EVO
```

---

## Arquitetura de Workflows

```mermaid
graph LR
    WH[Webhook WhatsApp] --> WF1[01-whatsapp-patient-handler-optimized]
    TH[Webhook Telegram] --> WF2[02-telegram-internal-assistant-multitenant]
    CRON[Trigger] --> WF3[03-appointment-confirmation-scheduler]
    WF1 -.erro.-> WF4[04-error-handler]
    WF2 -.erro.-> WF4
    WF3 -.erro.-> WF4

    WF1 --> SUB[tenant-config-loader]
    WF2 --> SUB
    WF3 --> SUB

    WF1 --> TOOL_CAL[tools/calendar/*]
    WF1 --> TOOL_COMM[tools/communication/*]
    WF1 --> TOOL_AI[tools/ai-processing/*]
    WF1 --> TOOL_ESC[tools/escalation/*]
    WF1 --> TOOL_SVC[tools/service/*]

    WF2 --> TOOL_CAL
    WF2 --> TOOL_COMM
```

---

## Modelo de Dados (alto nível)

```mermaid
erDiagram
    TENANT_CONFIG ||--o{ TENANT_FAQ : possui
    TENANT_CONFIG ||--o{ PROFESSIONALS : possui
    SERVICES_CATALOG ||--o{ PROFESSIONAL_SERVICES : inclui
    PROFESSIONALS ||--o{ PROFESSIONAL_SERVICES : oferece
    TENANT_CONFIG ||--o{ CHAT_MEMORY : registra

    TENANT_CONFIG {
        uuid tenant_id PK
        varchar tenant_name
        varchar evolution_instance_name
        text system_prompt_patient
        text system_prompt_internal
    }

    TENANT_FAQ {
        uuid faq_id PK
        uuid tenant_id FK
        text question_normalized
        text answer
    }

    PROFESSIONALS {
        uuid professional_id PK
        uuid tenant_id FK
        varchar professional_name
        varchar google_calendar_id
    }

    SERVICES_CATALOG {
        uuid service_id PK
        varchar service_name
        varchar service_category
    }

    PROFESSIONAL_SERVICES {
        uuid ps_id PK
        uuid professional_id FK
        uuid service_id FK
        int custom_duration_minutes
        int custom_price_cents
    }

    CHAT_MEMORY {
        uuid id PK
        uuid tenant_id FK
        text message
        varchar role
    }
```

---

## Fluxo de Agendamento (multi-profissional)

```mermaid
sequenceDiagram
    participant Cliente
    participant WF as WhatsApp Handler
    participant Svc as FindProfessionals
    participant Cal as Google Calendar
    Cliente->>WF: "Quero agendar um serviço"
    WF->>Svc: Buscar profissionais por serviço
    Svc-->>WF: Profissionais + calendar_id + duration
    WF->>Cal: Verificar disponibilidade
    Cal-->>WF: Slots disponíveis
    WF->>Cal: Criar evento no calendar_id correto
```

---

## Componentes de Ferramentas

- **Calendário**: disponibilidade, criação e listagem de eventos.
- **Comunicação**: envio WhatsApp/Telegram e formatação de mensagens.
- **IA e Mídia**: transcrição de áudio e OCR de imagem.
- **Escalonamento**: encaminhamento ao atendimento humano.
- **Serviços**: busca de profissionais por serviço.

---

## Segurança e Isolamento

- Isolamento por **tenant_id** em banco e workflows.
- Credenciais centralizadas e criptografadas no n8n.
- Calendários isolados por profissional (`google_calendar_id`).

---

**Última Atualização**: 2026-01-24  
**Versão**: 3.0