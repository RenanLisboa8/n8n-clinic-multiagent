# Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the n8n Clinic Multi-Agent System to production.

---

## Pre-Deployment Checklist

### Infrastructure Requirements

- [ ] Server with minimum 2 CPU cores, 4GB RAM, 20GB storage
- [ ] Docker 20.10+ and Docker Compose v2.0+ installed
- [ ] Domain name configured with DNS
- [ ] SSL certificate obtained (Let's Encrypt recommended)
- [ ] Firewall rules configured
- [ ] Backup storage configured

### Service Accounts & Credentials

- [ ] Google Account with Calendar API enabled
- [ ] Google Tasks API enabled
- [ ] Google Gemini API key obtained
- [ ] Telegram Bot created via @BotFather
- [ ] Telegram Chat ID obtained
- [ ] Evolution API instance configured
- [ ] Database passwords generated

### Documentation Review

- [ ] Read README.md
- [ ] Review ARCHITECTURE.md
- [ ] Understand REFACTORING_GUIDE.md
- [ ] Review env.example

---

## Deployment Steps

### Step 1: Server Preparation

#### 1.1 Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ufw
```

#### 1.2 Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installation
docker --version
docker-compose --version
```

#### 1.3 Configure Firewall

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS (if using reverse proxy)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow n8n (or use reverse proxy instead)
sudo ufw allow 5678/tcp

# Allow Evolution API (or use reverse proxy)
sudo ufw allow 8080/tcp

# Enable firewall
sudo ufw enable
sudo ufw status
```

---

### Step 2: Application Setup

#### 2.1 Clone Repository

```bash
cd /opt
sudo git clone https://github.com/yourusername/n8n-clinic-multiagent.git
cd n8n-clinic-multiagent
sudo chown -R $USER:$USER .
```

#### 2.2 Configure Environment

```bash
# Copy environment template
cp env.example .env

# Generate secure keys
echo "N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env
echo "N8N_JWT_SECRET=$(openssl rand -base64 32)" >> .env
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
echo "REDIS_PASSWORD=$(openssl rand -hex 32)" >> .env
echo "EVOLUTION_API_KEY=$(openssl rand -hex 32)" >> .env

# Edit .env and fill in remaining values
nano .env
```

**Critical values to set:**
- `N8N_WEBHOOK_URL`: Your domain (https://your-domain.com/)
- `EVOLUTION_BASE_URL`: Your Evolution API URL
- `GOOGLE_CALENDAR_ID`: Your Google Calendar ID
- `GOOGLE_GEMINI_API_KEY`: Your Gemini API key
- `TELEGRAM_BOT_TOKEN`: Your bot token
- `TELEGRAM_INTERNAL_CHAT_ID`: Your chat ID
- `CLINIC_*`: Your clinic information

#### 2.3 Secure Credentials

```bash
# Set proper permissions
chmod 600 .env

# Backup encryption key (store offline!)
echo "$N8N_ENCRYPTION_KEY" > ~/n8n-encryption-key.backup
chmod 400 ~/n8n-encryption-key.backup

# Move backup to secure location
# mv ~/n8n-encryption-key.backup /secure/offline/location/
```

---

### Step 3: SSL Configuration (Production)

#### Option A: Let's Encrypt with Certbot

```bash
# Install Certbot
sudo apt install -y certbot

# Generate certificate
sudo certbot certonly --standalone -d your-domain.com

# Certificates will be at:
# /etc/letsencrypt/live/your-domain.com/fullchain.pem
# /etc/letsencrypt/live/your-domain.com/privkey.pem
```

#### Option B: Reverse Proxy (Recommended)

Create `nginx.conf`:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;

    # n8n
    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Evolution API
    location /evolution/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

### Step 4: Start Services

#### 4.1 Initial Startup

```bash
cd /opt/n8n-clinic-multiagent

# Start services in background
docker-compose up -d

# Watch logs
docker-compose logs -f
```

#### 4.2 Verify Health

```bash
# Check all services are healthy
docker-compose ps

# Should show:
# clinic_postgres    healthy
# clinic_redis       healthy
# clinic_evolution_api   healthy
# clinic_n8n         healthy

# Test endpoints
curl http://localhost:5678/healthz
curl http://localhost:8080/health
```

---

### Step 5: n8n Configuration

#### 5.1 First-Time Setup

1. Open browser: `https://your-domain.com`
2. Create admin account (save credentials securely!)
3. Complete initial setup wizard

#### 5.2 Configure Credentials

In n8n Settings → Credentials, add:

**Evolution API:**
- URL: `http://evolution_api:8080` (internal Docker network)
- API Key: (from .env `EVOLUTION_API_KEY`)

**Google Calendar OAuth2:**
- Follow Google OAuth setup
- Authorize calendar access

**Google Tasks OAuth2:**
- Follow Google OAuth setup
- Authorize tasks access

**Telegram:**
- Bot Token: (from .env `TELEGRAM_BOT_TOKEN`)

**Google Gemini:**
- API Key: (from .env `GOOGLE_GEMINI_API_KEY`)

**PostgreSQL:**
- Host: `postgres`
- Port: `5432`
- Database: (from .env `POSTGRES_DB`)
- User: (from .env `POSTGRES_USER`)
- Password: (from .env `POSTGRES_PASSWORD`)

#### 5.3 Import Workflows

**Order of import:**

1. **Tools first** (dependencies):
   ```
   workflows/tools/communication/message-formatter-tool.json
   workflows/tools/communication/whatsapp-send-tool.json
   workflows/tools/communication/telegram-notify-tool.json
   workflows/tools/ai-processing/image-ocr-tool.json
   workflows/tools/ai-processing/audio-transcription-tool.json
   workflows/tools/escalation/call-to-human-tool.json
   ```

2. **Main workflows** (after tools):
   ```
   workflows/main/01-whatsapp-patient-handler.json
   workflows/main/02-telegram-internal-assistant.json
   workflows/main/03-appointment-confirmation-scheduler.json
   ```

**Import steps:**
1. In n8n: Workflows → Import from File
2. Select JSON file
3. Click "Import"
4. Update credential references if needed
5. Save workflow

---

### Step 6: Webhook Configuration

#### 6.1 n8n Webhooks

For each webhook node, get the webhook URL:
1. Open workflow
2. Click webhook node
3. Copy "Production URL"

#### 6.2 Evolution API Webhook

Configure Evolution API to send events to n8n:

```bash
# Example webhook configuration
curl -X POST http://localhost:8080/webhook/set \
  -H "apikey: YOUR_EVOLUTION_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "webhook": {
      "url": "https://your-domain.com/webhook/evolutionAPIKORE",
      "events": [
        "MESSAGES_UPSERT",
        "MESSAGES_UPDATE"
      ],
      "webhookByEvents": false
    }
  }'
```

#### 6.3 Telegram Webhook

Set Telegram webhook (if not using polling):

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -d "url=https://your-domain.com/webhook-test/telegram"
```

---

### Step 7: Activate Workflows

In n8n UI, activate workflows in order:

1. ✅ All tool workflows (set to active)
2. ✅ `01-whatsapp-patient-handler`
3. ✅ `02-telegram-internal-assistant`
4. ✅ `03-appointment-confirmation-scheduler`

---

### Step 8: Testing

#### 8.1 Test Patient Flow

1. Send WhatsApp message to clinic number
2. Verify message received in n8n execution log
3. Check agent response
4. Verify response sent back to WhatsApp

#### 8.2 Test Internal Assistant

1. Send message to Telegram bot
2. Verify command processed
3. Check tool execution
4. Verify response in Telegram

#### 8.3 Test Appointment Confirmation

1. Create test appointment for tomorrow
2. Wait for cron trigger (or manually execute)
3. Verify confirmation sent
4. Check WhatsApp delivery

---

### Step 9: Monitoring Setup

#### 9.1 Log Monitoring

```bash
# View all logs
docker-compose logs -f

# View specific service
docker-compose logs -f n8n

# Save logs to file
docker-compose logs > system-logs-$(date +%Y%m%d).log
```

#### 9.2 Resource Monitoring

```bash
# Monitor Docker stats
docker stats

# Check disk usage
df -h
docker system df
```

#### 9.3 Database Monitoring

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db

# Check database size
SELECT pg_size_pretty(pg_database_size('n8n_clinic_db'));

# Check table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

### Step 10: Backup Configuration

#### 10.1 Automated Database Backup

Create backup script `/opt/n8n-clinic-multiagent/scripts/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_clinic_backup_$DATE.sql"

mkdir -p $BACKUP_DIR

docker-compose exec -T postgres pg_dump -U n8n_clinic n8n_clinic_db > $BACKUP_FILE

gzip $BACKUP_FILE

# Keep only last 30 days
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE.gz"
```

```bash
chmod +x scripts/backup.sh
```

#### 10.2 Schedule with Cron

```bash
# Edit crontab
crontab -e

# Add daily backup at 3 AM
0 3 * * * /opt/n8n-clinic-multiagent/scripts/backup.sh >> /var/log/n8n-backup.log 2>&1
```

---

## Post-Deployment

### Security Hardening

```bash
# Restrict Docker network access
sudo iptables -A DOCKER-USER -i eth0 ! -s 10.0.0.0/8 -j DROP

# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### Performance Tuning

Edit `docker-compose.yaml` for production:

```yaml
n8n:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
```

### Monitoring Alerts

Set up alerts for:
- Service downtime
- High error rates
- Database size limits
- Disk space warnings
- Memory usage spikes

---

## Troubleshooting

### Services Won't Start

```bash
# Check Docker logs
docker-compose logs

# Check .env configuration
cat .env | grep -v "^#" | grep .

# Verify ports are available
sudo netstat -tulpn | grep -E ':(5678|8080|5432|6379)'
```

### Database Connection Issues

```bash
# Test PostgreSQL
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT 1;"

# Check database logs
docker-compose logs postgres
```

### Evolution API Not Responding

```bash
# Check Evolution API health
curl http://localhost:8080/health

# Check DNS resolution
docker-compose exec evolution_api nslookup google.com

# Restart service
docker-compose restart evolution_api
```

---

## Rollback Procedure

If deployment fails:

```bash
# Stop services
docker-compose down

# Restore from backup
docker-compose exec -T postgres psql -U n8n_clinic n8n_clinic_db < /backups/postgres/latest_backup.sql

# Revert to previous version
git checkout <previous-commit>

# Restart services
docker-compose up -d
```

---

## Maintenance Schedule

### Daily
- Monitor error logs
- Check service health
- Verify backups completed

### Weekly
- Review execution metrics
- Check disk space
- Update Docker images

### Monthly
- Security updates
- Performance review
- Backup verification
- Credential rotation

---

## Support

For deployment issues:
- Review logs: `docker-compose logs`
- Check documentation: `docs/`
- Open issue: GitHub Issues

---

**Deployment Guide Version:** 1.0  
**Last Updated:** 2026-01-01

