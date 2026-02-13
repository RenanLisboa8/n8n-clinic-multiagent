# Sistema Multi-Agente para Gestao de Clinicas (v4.0)

> **Automacao multi-tenant e multi-profissional com n8n**
> Workflows validados em `workflows/` | Documentacao em `docs/`

---

## Visao Geral

Plataforma de automacao para clinicas com fluxos de atendimento, agendamento e operacoes internas via n8n. Suporta **multi-tenant**, **multi-profissional** e **multi-servico**, com integracao a **WhatsApp**, **Telegram** e **Google Calendar**.

---

## Stack Tecnologico

| Componente | Tecnologia |
|---|---|
| Orquestracao | n8n (Docker) |
| Banco | PostgreSQL 16 |
| Cache | Redis 7 |
| WhatsApp | Evolution API v2.2.3 |
| IA | Google Gemini (via OpenRouter) |
| Calendario | Google Calendar (OAuth custom) |
| Deploy | Docker Compose |

---

## Estrutura do Projeto

```
.
├── workflows/
│   ├── main/                    # Orquestradores principais
│   │   ├── 01-whatsapp-main.json
│   │   ├── 02-telegram-internal-assistant-multitenant.json
│   │   ├── 03-appointment-confirmation-scheduler.json
│   │   └── 04-error-handler.json
│   ├── sub/                     # Sub-workflows reutilizaveis
│   │   └── tenant-config-loader.json
│   └── tools/                   # Ferramentas para agentes
│       ├── calendar/            # Google Calendar (OAuth custom)
│       ├── communication/       # Mensageria (Evolution/Chatwoot)
│       ├── ai-processing/       # Audio transcription + Image OCR
│       ├── escalation/          # Encaminhamento humano
│       └── service/             # Busca de profissionais
├── scripts/
│   ├── db/schema/schema.sql     # Schema consolidado
│   ├── db/seeds/                # Seeds (01-07)
│   ├── db/migrations/           # Migracoes incrementais
│   ├── cli/cli.py               # CLI para gestao de tenants
│   ├── import-workflows.py      # Importador automatico de workflows
│   └── import-workflows.sh      # Wrapper shell
├── tests/
│   ├── validate-workflows.py    # Validacao de workflows
│   ├── run-integration-tests.sh # Testes de integracao
│   └── sample-payloads/         # Payloads de teste
├── docs/                        # Documentacao (9 arquivos)
├── docker-compose.yml
├── env.example
├── QUICK_START.md
└── README.md
```

---

## Workflows Principais

### 01 - WhatsApp Main Handler
- **Arquivo**: `workflows/main/01-whatsapp-main.json`
- **Funcao**: Atendimento e agendamento via WhatsApp
- **Arquitetura**: State machine (DB-driven) + 3-layer AI defense (FAQ -> Template -> AI)
- **Features**: Deduplicacao, conversation locks, audio transcription, image OCR

### 02 - Telegram Internal Assistant
- **Arquivo**: `workflows/main/02-telegram-internal-assistant-multitenant.json`
- **Funcao**: Assistente interno para equipe via Telegram
- **Features**: Google Calendar, Google Tasks, mensageria

### 03 - Appointment Confirmation Scheduler
- **Arquivo**: `workflows/main/03-appointment-confirmation-scheduler.json`
- **Funcao**: Lembretes diarios de confirmacao (Cron 8AM)
- **Dados**: `get_appointments_for_reminders()` stored function (DB-based)

### 04 - Error Handler
- **Arquivo**: `workflows/main/04-error-handler.json`
- **Funcao**: Captura erros, resolve tenant, notifica via Telegram
- **Fallback**: `$env.FALLBACK_TELEGRAM_CHAT_ID` quando tenant desconhecido

---

## Ferramentas (`workflows/tools/`)

| Grupo | Workflows |
|---|---|
| calendar/ | availability, create, update, delete, list, client (OAuth) |
| communication/ | messaging-send (router), whatsapp-send, chatwoot-send, telegram-client, telegram-notify |
| ai-processing/ | audio-transcription, image-ocr |
| service/ | find-professionals |
| escalation/ | call-to-human |

---

## Regras Criticas

1. **NO native n8n Google Calendar nodes** - usar custom OAuth via sub-workflows
2. **Sempre usar `google_calendar_id`** retornado por `FindProfessionals` (nunca hardcodar)
3. **Sempre usar `duration_minutes`** de `professional_services` (varia por profissional)
4. **Todo SQL deve filtrar por `tenant_id`** - isolamento multi-tenant estrito
5. **Usar camada de mensageria** - `messaging-send-tool.json`, nao `whatsapp-send-tool.json` direto

---

## Instalacao Rapida

```bash
# 1. Configurar ambiente
cp env.example .env
# Editar .env com valores reais

# 2. Iniciar servicos
docker compose up -d

# 3. Inicializar banco
./scripts/init-db.sh

# 4. Importar workflows
python scripts/import-workflows.py

# 5. Configurar credentials no n8n UI
# Ver QUICK_START.md para detalhes
```

Para o guia completo, consulte [QUICK_START.md](QUICK_START.md).

---

## Google OAuth (novos clientes)

Para cada novo tenant, gerar e armazenar credenciais OAuth no banco:

1. Criar projeto no [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Ativar Google Calendar API
3. Criar OAuth 2.0 credentials (Web application)
4. Obter refresh token via [OAuth Playground](https://developers.google.com/oauthplayground)
5. Armazenar em `tenant_secrets` ou `calendars` table

Guia detalhado: [docs/SETUP_GOOGLE_CALENDAR_API.md](docs/SETUP_GOOGLE_CALENDAR_API.md)

---

## Documentacao

| Documento | Descricao |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura completa do sistema |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Guia de deploy em producao |
| [MONITORING.md](docs/MONITORING.md) | Monitoramento e alertas |
| [BACKUP.md](docs/BACKUP.md) | Estrategia de backup e recovery |
| [SETUP_GOOGLE_CALENDAR_API.md](docs/SETUP_GOOGLE_CALENDAR_API.md) | Setup Google Calendar OAuth |
| [USER_GUIDE.md](docs/USER_GUIDE.md) | Guia do usuario |
| [MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md) | Guia de migracoes |
| [DATABASE_ERD.md](docs/DATABASE_ERD.md) | Diagrama ER do banco |
| [CLINIC_TYPE_CONFIGURATION.md](docs/CLINIC_TYPE_CONFIGURATION.md) | Configuracao de tipos de clinica |

---

## Troubleshooting

```bash
# Verificar servicos
docker compose ps

# Logs do n8n
docker compose logs -f n8n

# Validar workflows
python tests/validate-workflows.py

# Health check
curl http://localhost:5678/healthz
```

---

**Versao**: 4.0
**Ultima Atualizacao**: 2026-02-13
