# Arquitetura do Sistema

> **Documentacao Proprietaria**
> Copyright 2026. Todos os Direitos Reservados.
> Este documento e confidencial e destinado apenas a clientes autorizados.

---

## Visao Geral

O **Sistema Multi-Agente de Gestao de Clinicas** e uma plataforma de automacao via **n8n**, com atendimento a pacientes por **WhatsApp** e operacoes internas via **Telegram**. O sistema e **multi-tenant**, **multi-profissional** e **multi-servico**, com agendamentos por **Google Calendar**.

---

## Stack Tecnologico

| Componente | Tecnologia | Proposito |
|------------|------------|-----------|
| Orquestracao | n8n | Workflows e agentes |
| Banco | PostgreSQL 16 | Configuracoes, catalogos, FAQs, estado |
| Cache | Redis 7 | Sessoes e otimizacoes |
| WhatsApp Gateway | Evolution API v2.2.3 | Mensagens e webhooks |
| IA | Google Gemini (via OpenRouter) | Processamento de linguagem |
| Calendario | Google Calendar (OAuth custom) | Agendamentos |
| Container | Docker Compose | Execucao local/servidor |

---

## Diagrama de Contexto

```
    Paciente ──► WhatsApp ──► Evolution API ──► n8n
    Equipe   ──► Telegram ─────────────────────► n8n
                                                  │
                              ┌────────────────────┼────────────────────┐
                              ▼                    ▼                    ▼
                        Google Gemini        Google Calendar       PostgreSQL
                        (OpenRouter)         (OAuth custom)          Redis
```

---

## Arquitetura de Containers

```
┌─────────────────── Docker Compose ───────────────────┐
│                                                       │
│   n8n ──────────► PostgreSQL                         │
│    │                                                  │
│    ├──────────► Redis                                │
│    │                                                  │
│    └──────────► Evolution API                        │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## Arquitetura de Workflows

```
Webhook WhatsApp ──► 01-whatsapp-main
Webhook Telegram ──► 02-telegram-internal-assistant-multitenant
Cron 8AM         ──► 03-appointment-confirmation-scheduler

01, 02, 03 ─── erro ──► 04-error-handler

01-whatsapp-main:
  ├── sub/tenant-config-loader
  ├── tools/calendar/* (availability, create, update, delete, list)
  ├── tools/communication/messaging-send-tool (► whatsapp-send / chatwoot-send)
  ├── tools/ai-processing/* (audio-transcription, image-ocr)
  ├── tools/escalation/call-to-human-tool
  └── tools/service/find-professionals-tool

02-telegram:
  ├── sub/tenant-config-loader
  ├── tools/calendar/*
  └── tools/communication/messaging-send-tool

03-scheduler:
  └── tools/communication/messaging-send-tool

04-error-handler:
  └── tools/communication/telegram-client
```

---

## Modelo de Dados

```
tenant_config (1) ──── (N) professionals
tenant_config (1) ──── (N) tenant_faq
tenant_config (1) ──── (N) tenant_secrets
tenant_config (1) ──── (N) calendars
tenant_config (1) ──── (N) appointments
tenant_config (1) ──── (N) conversation_state
tenant_config (1) ──── (N) message_queue

services_catalog (1) ──── (N) professional_services (N) ──── (1) professionals

Tabelas principais:
  tenant_config          - configuracao por tenant
  tenant_secrets         - credenciais criptografadas
  professionals          - profissionais com google_calendar_id individual
  services_catalog       - catalogo global de servicos
  professional_services  - juncao N:M com duracao/preco customizados
  appointments           - agendamentos com sync Google Calendar
  conversation_state     - estado da maquina de estados (DB-driven)
  state_definitions      - definicoes de estados e transicoes
  message_queue          - fila de deduplicacao de mensagens
  conversation_locks     - locks de conversa (expiraveis)
  tenant_faq             - cache de FAQ (3-layer defense)
  response_templates     - templates de resposta
  tenant_activity_log    - log de auditoria
  calendars              - configuracao de calendarios por profissional
```

---

## Catalogo Dinamico de Servicos

O catalogo de servicos e carregado dinamicamente do banco, nao hardcoded no prompt:

```
Webhook ──► Tenant Config Loader ──► Load Services Catalog ──► Build Prompt

Funcao SQL: get_services_catalog_for_prompt(p_tenant_id)
  Retorna texto formatado com profissionais + servicos + precos

Dados construidos a partir de:
  1. services_catalog       - definicoes globais
  2. professionals          - profissionais da clinica
  3. professional_services  - juncao com duracao/preco customizados
```

### Gerenciamento

```sql
-- Adicionar servico
INSERT INTO services_catalog (service_code, service_name, service_category, ...)
VALUES ('NEW_SERVICE', 'Novo Servico', 'Categoria', ...);

-- Associar a profissional
INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, price_display)
VALUES ($prof_id, $svc_id, 60, 100000, 'R$ 1.000,00');

-- Atualizar preco
UPDATE professional_services SET custom_price_cents = 120000, price_display = 'R$ 1.200,00'
WHERE professional_id = $1 AND service_id = $2;
```

---

## Arquitetura Multi-Profissional

### Modelo

```
Uma clinica = um WhatsApp = uma instancia Evolution API
Uma conta Google = uma credencial OAuth (nivel tenant)
Multiplos profissionais = multiplos Google Calendars
```

### Roteamento

```
Mensagem do usuario
  │
  ├── Nome mencionado ("Dr. Silva")    ──► Buscar por nome
  ├── Especialidade ("cardiologista")  ──► Buscar por keywords
  ├── Servico ("botox")               ──► find_professionals_for_service()
  └── Ambiguo ("quero consulta")       ──► IA pergunta ao usuario
        │
        ▼
  Profissional selecionado
  ├── google_calendar_id  ──► verificar disponibilidade
  ├── duration_minutes    ──► calcular hora_fim
  └── price_cents         ──► apresentar ao paciente
```

### Regras Criticas

1. **Nunca hardcodar calendar_id** - usar `professionals.google_calendar_id`
2. **Sempre usar duration do banco** - `professional_services.custom_duration_minutes`
3. **Sempre propagar tenant_id** - isolamento em todos os sub-workflows
4. **Soft delete para appointments** - usar `cancel_appointment()`, nunca DELETE

---

## Service Resolver

### Fluxo Completo

```
Usuario: "Quero fazer implante"
  │
  ▼
1. Extrair intencao (IA) ──► "implante"
  │
  ▼
2. Buscar no banco: find_professionals_for_service(tenant_id, 'implante')
  │ Retorna: professional_name, service_name, duration_minutes, price_cents, google_calendar_id
  │
  ▼
3. Apresentar ao paciente (com preco e duracao)
  │
  ▼
4. Validar slot >= duracao do servico
  │
  ▼
5. Calcular hora_fim = hora_inicio + duration_minutes
  │
  ▼
6. Criar evento no calendar_id do profissional
  │
  ▼
7. Criar registro em appointments + sync Google Calendar
```

### Servicos com Multiplos Profissionais

Quando o mesmo servico e oferecido por mais de um profissional (ex: Botox), a IA lista as opcoes com duracao e preco de cada um, permitindo ao paciente escolher.

---

## Fluxo de Agendamento

```
Cliente ──► WhatsApp Handler ──► FindProfessionals (servico)
                                      │
                                      ▼
                                Profissionais + calendar_id + duration
                                      │
                                      ▼
                                Google Calendar (verificar disponibilidade)
                                      │
                                      ▼
                                Slots disponiveis ──► Paciente escolhe
                                      │
                                      ▼
                                Validar slot >= duracao
                                      │
                                      ▼
                                Criar evento + appointment no banco
                                      │
                                      ▼
                                Confirmar ao paciente
```

---

## Camada de Mensageria

```
messaging-send-tool (router)
  │
  ├── provider = 'evolution'  ──► whatsapp-send-tool ──► Evolution API
  └── provider = 'chatwoot'   ──► chatwoot-send-tool ──► Chatwoot API

Configurado por tenant: tenant_config.messaging_provider
```

---

## Deduplicacao e Locks

```
Webhook ──► enqueue_message() ──► Duplicado? ──► [Sim] Return 200 (skip)
                                       │
                                       ▼ [Nao]
                                  acquire_conversation_lock()
                                       │
                                       ▼
                                  Processar mensagem
                                       │
                                       ▼
                                  release_conversation_lock()
```

- `message_queue`: UNIQUE constraint em `(tenant_id, message_id)`
- `conversation_locks`: expira em 5 minutos, cleanup automatico

---

## 3-Layer AI Defense

```
Mensagem do paciente
  │
  ▼
1. FAQ Cache (tenant_faq) ──► Hit? ──► Responder direto
  │                              │
  │ Miss                         │
  ▼                              │
2. Response Templates ──► Match? ──► Responder com template
  │                           │
  │ No match                  │
  ▼                           │
3. AI Agent (Gemini) ──► Gerar resposta ──► Salvar no FAQ cache
```

---

## Componentes de Ferramentas

| Grupo | Workflows | Funcao |
|-------|-----------|--------|
| calendar/ | availability, create, update, delete, list, client | Operacoes Google Calendar via OAuth custom |
| communication/ | messaging-send, whatsapp-send, chatwoot-send, telegram-client, telegram-notify | Envio de mensagens multi-provider |
| ai-processing/ | audio-transcription, image-ocr | Processamento de midia |
| escalation/ | call-to-human | Encaminhamento a atendimento humano |
| service/ | find-professionals | Busca de profissionais por servico |

---

## Seguranca e Isolamento

- Isolamento por **tenant_id** em todas as queries SQL
- Role `n8n_app` com permissoes restritas (SELECT, INSERT, UPDATE, DELETE apenas)
- Credenciais OAuth em `tenant_secrets` (criptografadas)
- Calendarios isolados por profissional (`google_calendar_id`)
- NO native n8n Google Calendar nodes - custom OAuth via sub-workflows
- Message deduplication via UNIQUE constraint
- Conversation locks com expiracao automatica

---

**Ultima Atualizacao**: 2026-02-13
**Versao**: 4.0
