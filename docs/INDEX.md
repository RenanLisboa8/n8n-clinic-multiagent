# 📚 Documentation Index

Welcome to the n8n Clinic Multi-Agent System documentation. This index will help you find what you need quickly.

---

## 🎯 I Want To...

### Get Started Quickly
→ **[QUICK_START.md](QUICK_START.md)** - 15-minute setup guide

### Understand the System
→ **[../README.md](../README.md)** - Complete system overview  
→ **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture

### Deploy to Production
→ **[DEPLOYMENT.md](DEPLOYMENT.md)** - Step-by-step deployment guide

### Refactor the Workflow
→ **[REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)** - Detailed refactoring strategy  
→ **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** - What was done

### Develop Tools
→ **[../workflows/tools/README.md](../workflows/tools/README.md)** - Tool development guide

---

## 📖 Documentation Files

| Document | Purpose | Audience | Time to Read |
|----------|---------|----------|--------------|
| **[QUICK_START.md](QUICK_START.md)** | Get running in 15 minutes | Everyone | 5 min |
| **[README.md](../README.md)** | Complete system overview | Everyone | 20 min |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System design & structure | Developers | 15 min |
| **[DEPLOYMENT.md](DEPLOYMENT.md)** | Production deployment | DevOps | 25 min |
| **[REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)** | How to refactor workflows | Developers | 20 min |
| **[REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md)** | What was refactored | Project Managers | 10 min |
| **[tools/README.md](../workflows/tools/README.md)** | Tool development guide | Developers | 10 min |

---

## 🎭 By Role

### 👨‍💼 Project Manager / Stakeholder
1. [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md) - Understand what was done
2. [README.md](../README.md) - See features and capabilities
3. [ARCHITECTURE.md](ARCHITECTURE.md) - Understand technical approach

### 👨‍💻 Developer
1. [QUICK_START.md](QUICK_START.md) - Set up development environment
2. [ARCHITECTURE.md](ARCHITECTURE.md) - Understand system design
3. [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md) - Learn refactoring strategy
4. [tools/README.md](../workflows/tools/README.md) - Develop workflow tools

### 🚀 DevOps / SysAdmin
1. [DEPLOYMENT.md](DEPLOYMENT.md) - Deploy to production
2. [README.md](../README.md#maintenance) - Maintenance procedures
3. [DEPLOYMENT.md#monitoring](DEPLOYMENT.md#step-9-monitoring-setup) - Set up monitoring

### 👥 End User (Clinic Staff)
1. [README.md#usage](../README.md#usage) - How to use the system
2. [README.md#for-staff-telegram](../README.md#for-staff-telegram) - Telegram bot commands

---

## 📋 By Task

### Installation & Setup

| Task | Document | Section |
|------|----------|---------|
| Quick local setup | [QUICK_START.md](QUICK_START.md) | Entire guide |
| Production deployment | [DEPLOYMENT.md](DEPLOYMENT.md) | Steps 1-10 |
| Configure environment | [README.md](../README.md#configuration) | Configuration |
| Set up SSL | [DEPLOYMENT.md](DEPLOYMENT.md#step-3-ssl-configuration-production) | Step 3 |
| Configure webhooks | [DEPLOYMENT.md](DEPLOYMENT.md#step-6-webhook-configuration) | Step 6 |

### Development

| Task | Document | Section |
|------|----------|---------|
| Understand architecture | [ARCHITECTURE.md](ARCHITECTURE.md) | Entire guide |
| Create workflow tools | [tools/README.md](../workflows/tools/README.md) | Tool Development |
| Refactor workflows | [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md) | Implementation Steps |
| Test workflows | [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md#testing-strategy) | Testing Strategy |

### Operations

| Task | Document | Section |
|------|----------|---------|
| Monitor system | [DEPLOYMENT.md](DEPLOYMENT.md#step-9-monitoring-setup) | Step 9 |
| Backup database | [DEPLOYMENT.md](DEPLOYMENT.md#step-10-backup-configuration) | Step 10 |
| Troubleshoot issues | [README.md](../README.md#troubleshooting) | Troubleshooting |
| View logs | [DEPLOYMENT.md](DEPLOYMENT.md#91-log-monitoring) | 9.1 Log Monitoring |
| Scale services | [DEPLOYMENT.md](DEPLOYMENT.md#performance-tuning) | Performance Tuning |

### Maintenance

| Task | Document | Section |
|------|----------|---------|
| Update services | [README.md](../README.md#update-services) | Update Services |
| Security hardening | [DEPLOYMENT.md](DEPLOYMENT.md#security-hardening) | Post-Deployment |
| Performance tuning | [DEPLOYMENT.md](DEPLOYMENT.md#performance-tuning) | Post-Deployment |
| Maintenance schedule | [REFACTORING_GUIDE.md](REFACTORING_GUIDE.md#maintenance-schedule) | Maintenance Schedule |

---

## 🗂️ Project Structure Reference

```
n8n-clinic-multiagent/
│
├── 📄 README.md                          ← Start here!
├── 📄 docker-compose.yaml                ← Docker orchestration
├── 📄 env.example                        ← Environment template
├── 📄 .gitignore                         ← Git ignore rules
│
├── 📁 docs/                              ← All documentation
│   ├── 📄 INDEX.md                       ← This file
│   ├── 📄 QUICK_START.md                 ← 15-min setup
│   ├── 📄 ARCHITECTURE.md                ← System design
│   ├── 📄 DEPLOYMENT.md                  ← Production guide
│   ├── 📄 REFACTORING_GUIDE.md          ← Refactoring strategy
│   └── 📄 REFACTORING_SUMMARY.md        ← What was done
│
├── 📁 scripts/                           ← Utility scripts
│   ├── 📄 init-db.sh                     ← DB initialization
│   └── 📄 backup.sh                      ← Backup script (doc'd)
│
└── 📁 workflows/                         ← n8n workflows
    ├── 📄 original-monolithic-workflow.json  ← Original backup
    │
    ├── 📁 main/                          ← Main workflows
    │   ├── 01-whatsapp-patient-handler.json
    │   ├── 02-telegram-internal-assistant.json
    │   └── 03-appointment-confirmation-scheduler.json
    │
    └── 📁 tools/                         ← Reusable tools
        ├── 📄 README.md                  ← Tool documentation
        ├── 📁 communication/
        │   ├── whatsapp-send-tool.json
        │   ├── message-formatter-tool.json
        │   └── telegram-notify-tool.json
        ├── 📁 ai-processing/
        │   ├── image-ocr-tool.json
        │   └── audio-transcription-tool.json
        ├── 📁 calendar/
        │   └── mcp-calendar-tool.json
        └── 📁 escalation/
            └── call-to-human-tool.json
```

---

## 🔗 External Resources

### APIs & Services
- **n8n Documentation**: https://docs.n8n.io
- **Evolution API**: https://doc.evolution-api.com
- **Google Gemini**: https://ai.google.dev/docs
- **Google Calendar API**: https://developers.google.com/calendar
- **Telegram Bot API**: https://core.telegram.org/bots/api

### Getting Credentials
- **Gemini API Key**: https://makersuite.google.com/app/apikey
- **Create Telegram Bot**: Talk to @BotFather on Telegram
- **Get Telegram Chat ID**: Send /start to @userinfobot

### Tools
- **Docker**: https://docs.docker.com
- **Docker Compose**: https://docs.docker.com/compose
- **PostgreSQL**: https://www.postgresql.org/docs

---

## 🆘 Getting Help

### First Steps
1. Check the [README.md](../README.md#troubleshooting) troubleshooting section
2. Review relevant documentation above
3. Check Docker logs: `docker-compose logs`

### Common Issues Quick Links
- [Services won't start](../README.md#services-wont-start)
- [Database connection errors](../README.md#database-connection-errors)
- [Evolution API issues](../README.md#evolution-api-connection-issues)
- [Webhook not receiving data](../README.md#n8n-webhook-not-receiving-data)

### Still Need Help?
- 📖 Review all documentation thoroughly
- 🐛 Open GitHub Issue with logs and steps to reproduce
- 💬 Join community discussions

---

## 📊 Documentation Statistics

- **Total Documents**: 7 files
- **Total Words**: ~20,000+
- **Code Examples**: 50+
- **Workflow Templates**: 4
- **Configuration Files**: 3

---

## 🔄 Documentation Updates

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-01 | Initial complete documentation set |

---

## ✅ Documentation Checklist

Use this to verify you have everything:

- [ ] Read QUICK_START.md (for initial setup)
- [ ] Read README.md (for system overview)
- [ ] Read ARCHITECTURE.md (for understanding design)
- [ ] Read DEPLOYMENT.md (before deploying)
- [ ] Read REFACTORING_GUIDE.md (before refactoring)
- [ ] Read tools/README.md (before developing tools)
- [ ] Configure .env from env.example
- [ ] Review docker-compose.yaml settings
- [ ] Test locally before production

---

## 📝 Contributing to Documentation

If you find issues or want to improve documentation:

1. Check if issue already documented
2. Update relevant document
3. Follow existing style and format
4. Update this INDEX.md if adding new docs
5. Submit pull request

---

**Need something not listed here?**  
Start with [README.md](../README.md) and follow the links!

---

*Documentation Index v1.0*  
*Last Updated: 2026-01-01*  
*Maintained by: n8n Automation Team*

