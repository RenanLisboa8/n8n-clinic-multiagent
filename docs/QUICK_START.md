# Quick Start Guide

Get the n8n Clinic Multi-Agent System running in 15 minutes!

---

## Prerequisites Check

```bash
# Verify Docker installed
docker --version  # Should show 20.10+

# Verify Docker Compose installed
docker-compose --version  # Should show v2.0+
```

If not installed, see [DEPLOYMENT.md](DEPLOYMENT.md) Step 1.

---

## Step 1: Clone & Navigate (1 minute)

```bash
cd /opt  # or your preferred directory
git clone https://github.com/yourusername/n8n-clinic-multiagent.git
cd n8n-clinic-multiagent
```

---

## Step 2: Generate Secrets (2 minutes)

```bash
# Copy environment template
cp env.example .env

# Generate all secrets at once
cat >> .env << EOF
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_JWT_SECRET=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -hex 32)
EVOLUTION_API_KEY=$(openssl rand -hex 32)
EOF

echo "✅ Secrets generated!"
```

---

## Step 3: Configure Essentials (5 minutes)

Edit `.env` and fill in these REQUIRED values:

```bash
nano .env  # or your preferred editor
```

**Minimum configuration:**

```env
# Your domain or IP
N8N_WEBHOOK_URL=http://YOUR_IP:5678/
EVOLUTION_BASE_URL=http://YOUR_IP:8080

# Google services (get from console.cloud.google.com)
GOOGLE_CALENDAR_ID=your-calendar-id@group.calendar.google.com
GOOGLE_GEMINI_API_KEY=your-api-key-from-ai-google-dev

# Telegram (get from @BotFather)
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHI...
TELEGRAM_INTERNAL_CHAT_ID=your-chat-id

# Clinic info
CLINIC_NAME=Your Clinic Name
CLINIC_PHONE=+5511999999999
CLINIC_EMAIL=contact@clinic.com
CLINIC_ADDRESS=Your Address
CLINIC_CALENDAR_PUBLIC_LINK=your-google-calendar-link

# MCP endpoint (if using)
MCP_CALENDAR_ENDPOINT=your-mcp-endpoint-url
```

**Where to get these:**
- Gemini API: https://makersuite.google.com/app/apikey
- Telegram Bot: Talk to @BotFather on Telegram
- Chat ID: Send /start to @userinfobot on Telegram
- Calendar ID: Google Calendar Settings → Integrate Calendar

Save and exit (Ctrl+X, Y, Enter in nano).

---

## Step 4: Start Services (2 minutes)

```bash
# Start all services
docker-compose up -d

# Wait ~30 seconds for services to initialize

# Check status (all should be "healthy")
docker-compose ps
```

Expected output:
```
NAME                  STATUS
clinic_postgres       Up (healthy)
clinic_redis          Up (healthy)
clinic_evolution_api  Up (healthy)
clinic_n8n            Up (healthy)
```

If not healthy, wait 30 more seconds and check again.

---

## Step 5: Access n8n (1 minute)

Open browser: `http://YOUR_IP:5678`

**First-time setup:**
1. Create admin account (save credentials!)
2. Complete setup wizard
3. Skip template selection

---

## Step 6: Add Credentials (3 minutes)

In n8n: **Settings** → **Credentials** → **Add Credential**

Add these (minimum):

### 1. Evolution API
- Type: Evolution API
- URL: `http://evolution_api:8080`
- API Key: (from your .env file)

### 2. Google Gemini
- Type: Google PaLM
- API Key: (from your .env file)

### 3. Telegram
- Type: Telegram
- Access Token: (from your .env file)

### 4. PostgreSQL
- Type: Postgres
- Host: `postgres`
- Port: `5432`
- Database: `n8n_clinic_db`
- User: `n8n_clinic`
- Password: (from your .env file)

---

## Step 7: Import Sample Tool (1 minute)

**For testing the setup:**

1. In n8n: **Workflows** → **Import from File**
2. Select: `workflows/tools/communication/whatsapp-send-tool.json`
3. Click **Import**
4. Update credential references if needed
5. Click **Save**

---

## Step 8: Test! (Optional)

### Test WhatsApp Tool

1. Open the imported `WhatsApp Send Tool` workflow
2. Click **Execute Workflow** button
3. In test data, enter:
```json
{
  "remote_jid": "5511999999999@s.whatsapp.net",
  "message_text": "Test message from n8n!"
}
```
4. Click **Execute**
5. Check WhatsApp for message

---

## Next Steps

### For Development

Continue with full setup:
1. Import remaining tool workflows
2. Import main workflows
3. Configure webhooks
4. Test full flows

See: [DEPLOYMENT.md](DEPLOYMENT.md) for complete guide

### For Production

Before going live:
1. Set up SSL (HTTPS)
2. Configure firewall
3. Set up backups
4. Configure monitoring

See: [DEPLOYMENT.md](DEPLOYMENT.md) Step 3 onwards

---

## Common Issues

### "Service Unhealthy"

**Solution:**
```bash
# Check logs
docker-compose logs [service_name]

# Common causes:
# - Wrong password in .env
# - Port already in use
# - Insufficient memory
```

### "Cannot Connect to Database"

**Solution:**
```bash
# Verify PostgreSQL is running
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT 1;"

# If fails, check POSTGRES_PASSWORD in .env matches everywhere
```

### "Evolution API Not Responding"

**Solution:**
```bash
# Check if service is up
curl http://localhost:8080/health

# Restart if needed
docker-compose restart evolution_api
```

---

## Quick Commands Reference

```bash
# View logs
docker-compose logs -f

# Restart service
docker-compose restart [service_name]

# Stop all
docker-compose down

# Start all
docker-compose up -d

# Check status
docker-compose ps

# View resource usage
docker stats
```

---

## Getting Help

- 📖 **Full Documentation**: See [README.md](../README.md)
- 🏗️ **Architecture**: See [docs/ARCHITECTURE.md](ARCHITECTURE.md)
- 🚀 **Deployment**: See [docs/DEPLOYMENT.md](DEPLOYMENT.md)
- 🔧 **Refactoring**: See [docs/REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)

---

## Security Reminder ⚠️

**Before production:**
- [ ] Change all default passwords
- [ ] Set up HTTPS/SSL
- [ ] Configure firewall rules
- [ ] Backup encryption keys
- [ ] Enable monitoring

---

**You're all set!** 🎉

Your n8n Clinic Multi-Agent System is running and ready for configuration.

---

*Quick Start Guide v1.0 - Updated: 2026-01-01*

