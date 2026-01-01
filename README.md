# 🏥 n8n Clinic Multi-Agent System

> **Professional multi-agent automation system for clinic management with WhatsApp, Telegram, and AI-powered assistants**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![n8n](https://img.shields.io/badge/n8n-latest-orange)](https://n8n.io)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Agents & Tools](#agents--tools)
- [Workflows](#workflows)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

The **n8n Clinic Multi-Agent System** is a production-ready automation platform designed for healthcare clinics. It provides intelligent, AI-powered patient interaction through WhatsApp, internal staff management via Telegram, and automated appointment confirmations.

### Key Capabilities

- 🤖 **AI-Powered Patient Assistant** - Handles appointment scheduling, rescheduling, and clinic inquiries
- 📱 **WhatsApp Integration** - Seamless patient communication via Evolution API
- 💬 **Internal Telegram Bot** - Staff tool for administrative tasks
- 📅 **Google Calendar Integration** - Automated schedule management
- 🔔 **Daily Appointment Confirmations** - Proactive patient engagement
- 🎤 **Multimedia Support** - Process text, images (OCR), and audio (transcription)
- 🚨 **Smart Escalation** - Routes urgent cases to human operators
- 🧠 **Contextual Memory** - Maintains conversation history per patient

---

## ✨ Features

### Patient-Facing Features
- ✅ Schedule appointments with natural language
- ✅ Reschedule or cancel existing appointments
- ✅ Check appointment availability
- ✅ Receive appointment confirmations and reminders
- ✅ Send images (prescriptions, exams) for analysis
- ✅ Send voice messages for transcription
- ✅ Automatic escalation for urgent situations

### Staff-Facing Features
- ✅ Manage patient schedules via Telegram
- ✅ Bulk rescheduling capabilities
- ✅ Shopping list management (Google Tasks)
- ✅ Cancellation notifications
- ✅ Real-time alerts for escalated cases

### Technical Features
- ✅ Modular workflow architecture
- ✅ Production-ready Docker setup
- ✅ Health checks and logging
- ✅ PostgreSQL with Redis caching
- ✅ Encrypted credentials storage
- ✅ Environment-based configuration
- ✅ Containerized deployment

---

## 🏗️ Architecture

The system follows a **modular, multi-agent architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                     External Interfaces                      │
├──────────────┬──────────────┬──────────────┬────────────────┤
│   WhatsApp   │   Telegram   │    Google    │      AI/LLM    │
│  (Patients)  │    (Staff)   │   Calendar   │   (Gemini)     │
└──────┬───────┴──────┬───────┴──────┬───────┴────────┬───────┘
       │              │              │                │
┌──────▼──────────────▼──────────────▼────────────────▼───────┐
│                      n8n Workflows                           │
├──────────────────────────────────────────────────────────────┤
│  Main Workflows:                                             │
│  • 01-whatsapp-patient-handler.json                          │
│  • 02-telegram-internal-assistant.json                       │
│  • 03-appointment-confirmation-scheduler.json                │
│                                                              │
│  Tool Workflows:                                             │
│  • Calendar Tools (MCP integration)                          │
│  • Communication Tools (WhatsApp, Telegram)                  │
│  • AI Processing (OCR, Transcription)                        │
│  • Escalation Tools (Human handoff)                          │
└──────┬───────────────────┬───────────────────┬──────────────┘
       │                   │                   │
┌──────▼───────┐  ┌────────▼────────┐  ┌──────▼──────────┐
│  PostgreSQL  │  │      Redis      │  │  Evolution API  │
│  (Database)  │  │     (Cache)     │  │   (WhatsApp)    │
└──────────────┘  └─────────────────┘  └─────────────────┘
```

### Core Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **n8n** | Workflow Automation | Orchestrates all automation logic |
| **Evolution API** | WhatsApp Gateway | Handles WhatsApp communication |
| **PostgreSQL** | Database | Stores workflows, executions, chat history |
| **Redis** | Cache | Improves performance and session management |
| **Google Gemini** | AI/LLM | Powers intelligent agents |
| **MCP Protocol** | Model Context Protocol | Calendar and email integrations |

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 📦 Prerequisites

### Required

- **Docker** (20.10+) and **Docker Compose** (v2.0+)
- **Google Account** with:
  - Calendar API enabled
  - Tasks API enabled
  - Gemini API key
- **Telegram Bot** (create via [@BotFather](https://t.me/botfather))
- **Evolution API** instance or self-hosted setup

### Recommended

- **Domain name** with SSL certificate (for production)
- **Minimum server specs**:
  - 2 CPU cores
  - 4GB RAM
  - 20GB storage
  - Ubuntu 22.04 LTS or similar

### Knowledge Requirements

- Basic Docker and Docker Compose
- Familiarity with environment variables
- Understanding of webhook concepts
- Basic n8n workflow knowledge

---

## 🚀 Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/n8n-clinic-multiagent.git
cd n8n-clinic-multiagent
```

### Step 2: Configure Environment Variables

Copy the example environment file and fill in your values:

```bash
cp env.example .env
```

**Critical: Generate secure keys**

```bash
# Generate encryption key for n8n
openssl rand -base64 32

# Generate JWT secret
openssl rand -base64 32

# Generate database password
openssl rand -base64 32

# Generate Redis password
openssl rand -hex 32

# Generate Evolution API key
openssl rand -hex 32
```

Edit `.env` and fill in all `<REQUIRED>` fields. See [Configuration](#configuration) section for details.

### Step 3: Start the Services

```bash
docker-compose up -d
```

This will start:
- PostgreSQL (port 5432)
- Redis (port 6379)
- Evolution API (port 8080)
- n8n (port 5678)

### Step 4: Verify Installation

Check that all services are healthy:

```bash
docker-compose ps
```

All services should show `healthy` status.

### Step 5: Access n8n

Open your browser and navigate to:

```
http://localhost:5678
```

Create your n8n admin account on first access.

### Step 6: Import Workflows

1. In n8n UI, go to **Workflows** → **Import from File**
2. Import workflows in this order:
   - Tool workflows first (from `workflows/tools/`)
   - Main workflows second (from `workflows/main/`)

### Step 7: Configure Credentials

Set up the following credentials in n8n:

1. **Evolution API** - Add your Evolution API URL and key
2. **Google Calendar OAuth2** - Connect your Google account
3. **Google Tasks OAuth2** - Connect your Google account
4. **Telegram Bot** - Add your bot token
5. **Google Gemini API** - Add your API key
6. **PostgreSQL** - Connection is auto-configured

### Step 8: Activate Workflows

Enable the main workflows:
- ✅ `01-whatsapp-patient-handler`
- ✅ `02-telegram-internal-assistant`
- ✅ `03-appointment-confirmation-scheduler`

---

## ⚙️ Configuration

### Essential Environment Variables

#### Database Configuration

```env
POSTGRES_USER=n8n_clinic
POSTGRES_PASSWORD=<generate_strong_password>
POSTGRES_DB=n8n_clinic_db
```

#### n8n Configuration

```env
N8N_ENCRYPTION_KEY=<generate_with_openssl>
N8N_JWT_SECRET=<generate_with_openssl>
N8N_WEBHOOK_URL=https://your-domain.com/
```

#### Evolution API Configuration

```env
EVOLUTION_BASE_URL=http://your-domain.com:8080
EVOLUTION_API_KEY=<generate_api_key>
```

#### Google Services

```env
GOOGLE_CALENDAR_ID=your-calendar-id@group.calendar.google.com
GOOGLE_GEMINI_API_KEY=<your_gemini_api_key>
```

Get your Gemini API key from: [Google AI Studio](https://makersuite.google.com/app/apikey)

#### Telegram Bot

```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_INTERNAL_CHAT_ID=<your_chat_id>
```

Get your chat ID by messaging [@userinfobot](https://t.me/userinfobot)

#### Clinic Business Info

```env
CLINIC_NAME=Your Clinic Name
CLINIC_ADDRESS=Your Full Address
CLINIC_PHONE=+5511999999999
CLINIC_HOURS_START=08:00
CLINIC_HOURS_END=19:00
```

For complete configuration options, see `env.example`.

---

## 🎮 Usage

### For Patients (WhatsApp)

Patients can interact naturally via WhatsApp:

**Schedule an appointment:**
```
Patient: "Hi, I'd like to schedule a consultation"
Bot: "Hello! I'd be happy to help. Could you provide your full name?"
Patient: "Maria Silva"
Bot: "Great, Maria. What is your date of birth?"
...
```

**Reschedule:**
```
Patient: "I need to reschedule my appointment"
Bot: "No problem! Let me look up your appointment..."
```

**Check availability:**
```
Patient: "Do you have openings next week?"
Bot: "Let me check the schedule for next week..."
```

### For Staff (Telegram)

Staff can manage operations via Telegram:

**Reschedule a patient:**
```
Staff: "Reschedule João Silva from tomorrow to next Monday"
Bot: "I'll check João's appointment and available slots..."
```

**Add to shopping list:**
```
Staff: "Add 5 boxes of gloves to the shopping list"
Bot: "Added to Google Tasks: 5 boxes of gloves"
```

### Appointment Confirmations

The system automatically sends confirmation requests daily at 8 AM for next-day appointments:

```
Bot: "Hi Maria! You have an appointment tomorrow at 10:00 AM. 
Please reply 'Confirm' to confirm or 'Reschedule' to change."
```

---

## 🤖 Agents & Tools

### Main Agents

#### 1. **Patient Assistant** (`Assistente Clínica`)
- **Role**: Patient-facing WhatsApp assistant
- **Capabilities**:
  - Schedule/reschedule/cancel appointments
  - Check availability
  - Answer clinic questions
  - Process images and audio
  - Escalate urgent situations
- **Memory**: Maintains conversation context per patient
- **Language Model**: Google Gemini 2.0 Flash

#### 2. **Internal Assistant** (`Assistente Clínica Interno`)
- **Role**: Staff-facing Telegram bot
- **Capabilities**:
  - Manage patient schedules
  - Send rescheduling notifications
  - Manage shopping lists
  - Administrative tasks
- **Memory**: Maintains staff conversation context
- **Language Model**: Google Gemini 2.0 Flash

#### 3. **Confirmation Assistant** (`Assistente de Confirmação`)
- **Role**: Automated appointment confirmation
- **Capabilities**:
  - Fetch next-day appointments
  - Send confirmation requests
  - Log confirmation status
- **Trigger**: Daily at 8 AM (Mon-Fri)
- **Language Model**: Google Gemini 2.0 Flash

### Tool Workflows

| Tool | Purpose | Used By |
|------|---------|---------|
| **MCP Calendar** | Google Calendar operations | All agents |
| **WhatsApp Send** | Send WhatsApp messages | All workflows |
| **Telegram Notify** | Send Telegram notifications | Patient assistant |
| **Message Formatter** | Format for WhatsApp markdown | All workflows |
| **Image OCR** | Extract text from images | Patient assistant |
| **Audio Transcription** | Transcribe voice messages | Patient assistant |
| **Call to Human** | Escalate to human operator | Patient assistant |

---

## 📂 Workflows

### Main Workflows

#### `01-whatsapp-patient-handler.json`
**Trigger**: Webhook from Evolution API  
**Purpose**: Handle all patient WhatsApp interactions  
**Flow**: Receive → Parse → Process (text/image/audio) → Agent Response → Format → Send

#### `02-telegram-internal-assistant.json`
**Trigger**: Telegram message from staff  
**Purpose**: Internal staff assistant  
**Flow**: Receive → Agent Process → Execute Tools → Respond

#### `03-appointment-confirmation-scheduler.json`
**Trigger**: Cron schedule (daily 8 AM)  
**Purpose**: Send next-day appointment confirmations  
**Flow**: Fetch Appointments → Loop → Extract Contact → Send Confirmation

### Tool Workflows

Located in `workflows/tools/` subdirectories. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

---

## 🔧 Maintenance

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f n8n
docker-compose logs -f evolution_api
docker-compose logs -f postgres
```

### Database Backup

```bash
# Manual backup
docker-compose exec postgres pg_dump -U n8n_clinic n8n_clinic_db > backup_$(date +%Y%m%d).sql

# Restore
docker-compose exec -T postgres psql -U n8n_clinic n8n_clinic_db < backup_20260101.sql
```

### Update Services

```bash
# Pull latest images
docker-compose pull

# Restart services
docker-compose up -d
```

### Clean Up Old Data

n8n automatically prunes execution data older than `N8N_DATA_MAX_AGE` (default: 7 days).

### Health Checks

```bash
# Check service health
docker-compose ps

# Test n8n API
curl http://localhost:5678/healthz

# Test Evolution API
curl http://localhost:8080/health
```

---

## 🐛 Troubleshooting

### Common Issues

#### Services Won't Start

```bash
# Check logs
docker-compose logs

# Verify .env file
cat .env | grep REQUIRED

# Check port conflicts
sudo lsof -i :5678
sudo lsof -i :8080
```

#### Evolution API Connection Issues

1. Check DNS settings in docker-compose.yaml
2. Verify `EVOLUTION_API_KEY` matches in both services
3. Check firewall rules

#### n8n Webhook Not Receiving Data

1. Verify `N8N_WEBHOOK_URL` is publicly accessible
2. Check Evolution API webhook configuration
3. Test webhook manually with curl

#### Database Connection Errors

```bash
# Test PostgreSQL connection
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT 1;"

# Check credentials
echo $POSTGRES_PASSWORD
```

#### Agent Not Responding

1. Check if workflow is active
2. Verify Google Gemini API key is valid
3. Check rate limits on AI API
4. Review execution logs in n8n UI

### Getting Help

1. Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for system design
2. Review workflow execution logs in n8n UI
3. Check Docker logs for service errors
4. Open an issue on GitHub with:
   - Error messages
   - Relevant logs
   - Steps to reproduce

---

## 🔒 Security

### Best Practices

✅ **DO**:
- Use strong passwords (32+ characters)
- Enable HTTPS with SSL certificate
- Restrict access with firewall rules
- Regularly update Docker images
- Backup encryption keys offline
- Use environment variables for secrets
- Enable rate limiting

❌ **DON'T**:
- Commit `.env` to version control
- Expose ports directly to internet
- Use default passwords
- Share API keys
- Disable security features

### Production Checklist

- [ ] SSL certificate configured
- [ ] Firewall rules in place
- [ ] Strong passwords set
- [ ] Backup strategy implemented
- [ ] Monitoring alerts configured
- [ ] Rate limiting enabled
- [ ] Docker images updated
- [ ] Encryption keys backed up
- [ ] Access logs reviewed regularly

### Encrypting Sensitive Data

n8n encrypts credentials using `N8N_ENCRYPTION_KEY`. **Never lose this key** or you'll lose access to all stored credentials.

Store a backup copy:
```bash
# Save to secure location
echo $N8N_ENCRYPTION_KEY > /secure/backup/n8n-encryption-key.txt
chmod 400 /secure/backup/n8n-encryption-key.txt
```

---

## 📊 Monitoring

### Key Metrics to Monitor

- Workflow execution success rate
- WhatsApp message delivery rate
- Database size and performance
- Redis memory usage
- Evolution API uptime
- Agent response time

### Recommended Tools

- **Prometheus + Grafana** for metrics visualization
- **Sentry** for error tracking
- **UptimeRobot** for service availability
- **Docker stats** for resource monitoring

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for local development instructions.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [n8n](https://n8n.io) - Workflow automation platform
- [Evolution API](https://evolution-api.com) - WhatsApp API
- [Google Gemini](https://ai.google.dev) - AI/LLM capabilities
- PostgreSQL, Redis, Docker communities

---

## 📧 Support

For questions and support:

- 📖 Documentation: [docs/](docs/)
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/n8n-clinic-multiagent/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/n8n-clinic-multiagent/discussions)

---

**Made with ❤️ for modern healthcare clinics**

*Last updated: 2026-01-01*
