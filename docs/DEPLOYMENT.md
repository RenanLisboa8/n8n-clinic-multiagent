# Guia de Implantação

## Visão Geral

Este guia fornece instruções passo a passo para implantar o Sistema Multi-Agente n8n para Clínicas em produção.

---

## Checklist Pré-Implantação

### Requisitos de Infraestrutura

- [ ] Servidor com mínimo de 2 núcleos de CPU, 4GB RAM, 20GB armazenamento
- [ ] Docker 20.10+ e Docker Compose v2.0+ instalados
- [ ] Nome de domínio configurado com DNS
- [ ] Certificado SSL obtido (Let's Encrypt recomendado)
- [ ] Regras de firewall configuradas
- [ ] Armazenamento de backup configurado

### Contas de Serviço e Credenciais

- [ ] Conta Google com API do Calendar habilitada
- [ ] API do Google Tasks habilitada
- [ ] Chave API do Google Gemini obtida
- [ ] Bot do Telegram criado via @BotFather
- [ ] ID do Chat do Telegram obtido
- [ ] Instância da Evolution API configurada
- [ ] Senhas do banco de dados geradas

### Revisão de Documentação

- [ ] Ler README.md
- [ ] Revisar ARCHITECTURE.md
- [ ] Entender REFACTORING_GUIDE.md
- [ ] Revisar env.example

---

## Passos de Implantação

### Passo 1: Preparação do Servidor

#### 1.1 Atualizar Sistema

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git ufw
```

#### 1.2 Instalar Docker

```bash
# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verificar instalação
docker --version
docker-compose --version
```

#### 1.3 Configurar Firewall

```bash
# Permitir SSH
sudo ufw allow 22/tcp

# Permitir HTTP/HTTPS (se usar proxy reverso)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Permitir n8n (ou usar proxy reverso)
sudo ufw allow 5678/tcp

# Permitir Evolution API (ou usar proxy reverso)
sudo ufw allow 8080/tcp

# Habilitar firewall
sudo ufw enable
sudo ufw status
```

---

### Passo 2: Configuração da Aplicação

#### 2.1 Clonar Repositório

```bash
cd /opt
sudo git clone https://github.com/seuusuario/n8n-clinic-multiagent.git
cd n8n-clinic-multiagent
sudo chown -R $USER:$USER .
```

#### 2.2 Configurar Ambiente

```bash
# Copiar template de ambiente
cp env.example .env

# Gerar chaves seguras
echo "N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)" >> .env
echo "N8N_JWT_SECRET=$(openssl rand -base64 32)" >> .env
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32)" >> .env
echo "REDIS_PASSWORD=$(openssl rand -hex 32)" >> .env
echo "EVOLUTION_API_KEY=$(openssl rand -hex 32)" >> .env

# Editar .env e preencher valores restantes
nano .env
```

**Valores críticos a definir:**
- `N8N_WEBHOOK_URL`: Seu domínio (https://seu-dominio.com/)
- `EVOLUTION_BASE_URL`: Sua URL da Evolution API
- `GOOGLE_CALENDAR_ID`: Seu ID do Google Calendar
- `GOOGLE_GEMINI_API_KEY`: Sua chave API Gemini
- `TELEGRAM_BOT_TOKEN`: Seu token do bot
- `TELEGRAM_INTERNAL_CHAT_ID`: Seu ID do chat
- `CLINIC_*`: Informações da sua clínica

#### 2.3 Proteger Credenciais

```bash
# Definir permissões apropriadas
chmod 600 .env

# Fazer backup da chave de criptografia (armazenar offline!)
echo "$N8N_ENCRYPTION_KEY" > ~/n8n-encryption-key.backup
chmod 400 ~/n8n-encryption-key.backup

# Mover backup para local seguro
# mv ~/n8n-encryption-key.backup /local/offline/seguro/
```

---

### Passo 3: Configuração SSL (Produção)

#### Opção A: Let's Encrypt com Certbot

```bash
# Instalar Certbot
sudo apt install -y certbot

# Gerar certificado
sudo certbot certonly --standalone -d seu-dominio.com

# Certificados estarão em:
# /etc/letsencrypt/live/seu-dominio.com/fullchain.pem
# /etc/letsencrypt/live/seu-dominio.com/privkey.pem
```

#### Opção B: Proxy Reverso (Recomendado)

Criar `nginx.conf`:

```nginx
server {
    listen 80;
    server_name seu-dominio.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name seu-dominio.com;

    ssl_certificate /etc/letsencrypt/live/seu-dominio.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/seu-dominio.com/privkey.pem;

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

### Passo 4: Iniciar Serviços

#### 4.1 Inicialização Inicial

```bash
cd /opt/n8n-clinic-multiagent

# Iniciar serviços em segundo plano
docker-compose up -d

# Observar logs
docker-compose logs -f
```

#### 4.2 Verificar Saúde

```bash
# Verificar se todos os serviços estão saudáveis
docker-compose ps

# Deve mostrar:
# clinic_postgres    healthy
# clinic_redis       healthy
# clinic_evolution_api   healthy
# clinic_n8n         healthy

# Testar endpoints
curl http://localhost:5678/healthz
curl http://localhost:8080/health
```

---

### Passo 5: Configuração do n8n

#### 5.1 Configuração Inicial

1. Abrir navegador: `https://seu-dominio.com`
2. Criar conta de administrador (salvar credenciais com segurança!)
3. Completar assistente de configuração inicial

#### 5.2 Configurar Credenciais

Em n8n Configurações → Credenciais, adicionar:

**Evolution API:**
- URL: `http://evolution_api:8080` (rede interna Docker)
- Chave API: (do .env `EVOLUTION_API_KEY`)

**Google Calendar OAuth2:**
- Seguir configuração OAuth do Google
- Autorizar acesso ao calendário

**Google Tasks OAuth2:**
- Seguir configuração OAuth do Google
- Autorizar acesso às tarefas

**Telegram:**
- Token do Bot: (do .env `TELEGRAM_BOT_TOKEN`)

**Google Gemini:**
- Chave API: (do .env `GOOGLE_GEMINI_API_KEY`)

**PostgreSQL:**
- Host: `postgres`
- Porta: `5432`
- Banco de Dados: (do .env `POSTGRES_DB`)
- Usuário: (do .env `POSTGRES_USER`)
- Senha: (do .env `POSTGRES_PASSWORD`)

#### 5.3 Importar Workflows

**Ordem de importação:**

1. **Ferramentas primeiro** (dependências):
   ```
   workflows/tools/communication/message-formatter-tool.json
   workflows/tools/communication/whatsapp-send-tool.json
   workflows/tools/communication/telegram-notify-tool.json
   workflows/tools/ai-processing/image-ocr-tool.json
   workflows/tools/ai-processing/audio-transcription-tool.json
   workflows/tools/escalation/call-to-human-tool.json
   ```

2. **Workflows principais** (após ferramentas):
   ```
   workflows/main/01-whatsapp-patient-handler.json
   workflows/main/02-telegram-internal-assistant.json
   workflows/main/03-appointment-confirmation-scheduler.json
   ```

**Passos de importação:**
1. No n8n: Workflows → Importar de Arquivo
2. Selecionar arquivo JSON
3. Clicar em "Importar"
4. Atualizar referências de credenciais se necessário
5. Salvar workflow

---

### Passo 6: Configuração de Webhook

#### 6.1 Webhooks n8n

Para cada nó de webhook, obter a URL do webhook:
1. Abrir workflow
2. Clicar no nó de webhook
3. Copiar "URL de Produção"

#### 6.2 Webhook da Evolution API

Configurar Evolution API para enviar eventos ao n8n:

```bash
# Exemplo de configuração de webhook
curl -X POST http://localhost:8080/webhook/set \
  -H "apikey: SUA_CHAVE_API_EVOLUTION" \
  -H "Content-Type: application/json" \
  -d '{
    "webhook": {
      "url": "https://seu-dominio.com/webhook/evolutionAPIKORE",
      "events": [
        "MESSAGES_UPSERT",
        "MESSAGES_UPDATE"
      ],
      "webhookByEvents": false
    }
  }'
```

#### 6.3 Webhook do Telegram

Definir webhook do Telegram (se não usar polling):

```bash
curl -X POST "https://api.telegram.org/bot<SEU_TOKEN_BOT>/setWebhook" \
  -d "url=https://seu-dominio.com/webhook-test/telegram"
```

---

### Passo 7: Ativar Workflows

Na interface do n8n, ativar workflows na ordem:

1. ✅ Todos os workflows de ferramentas (definir como ativo)
2. ✅ `01-whatsapp-patient-handler`
3. ✅ `02-telegram-internal-assistant`
4. ✅ `03-appointment-confirmation-scheduler`

---

### Passo 8: Testes

#### 8.1 Testar Fluxo de Paciente

1. Enviar mensagem WhatsApp para número da clínica
2. Verificar mensagem recebida no log de execução do n8n
3. Verificar resposta do agente
4. Verificar resposta enviada de volta ao WhatsApp

#### 8.2 Testar Assistente Interno

1. Enviar mensagem ao bot do Telegram
2. Verificar comando processado
3. Verificar execução da ferramenta
4. Verificar resposta no Telegram

#### 8.3 Testar Confirmação de Consulta

1. Criar consulta de teste para amanhã
2. Aguardar gatilho cron (ou executar manualmente)
3. Verificar confirmação enviada
4. Verificar entrega no WhatsApp

---

### Passo 9: Configuração de Monitoramento

#### 9.1 Monitoramento de Logs

```bash
# Ver todos os logs
docker-compose logs -f

# Ver serviço específico
docker-compose logs -f n8n

# Salvar logs em arquivo
docker-compose logs > logs-sistema-$(date +%Y%m%d).log
```

#### 9.2 Monitoramento de Recursos

```bash
# Monitorar estatísticas Docker
docker stats

# Verificar uso de disco
df -h
docker system df
```

#### 9.3 Monitoramento de Banco de Dados

```bash
# Conectar ao PostgreSQL
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db

# Verificar tamanho do banco de dados
SELECT pg_size_pretty(pg_database_size('n8n_clinic_db'));

# Verificar tamanhos das tabelas
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

### Passo 10: Configuração de Backup

#### 10.1 Backup Automatizado de Banco de Dados

Criar script de backup `/opt/n8n-clinic-multiagent/scripts/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/n8n_clinic_backup_$DATE.sql"

mkdir -p $BACKUP_DIR

docker-compose exec -T postgres pg_dump -U n8n_clinic n8n_clinic_db > $BACKUP_FILE

gzip $BACKUP_FILE

# Manter apenas últimos 30 dias
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup concluído: $BACKUP_FILE.gz"
```

```bash
chmod +x scripts/backup.sh
```

#### 10.2 Agendar com Cron

```bash
# Editar crontab
crontab -e

# Adicionar backup diário às 3h
0 3 * * * /opt/n8n-clinic-multiagent/scripts/backup.sh >> /var/log/n8n-backup.log 2>&1
```

---

## Pós-Implantação

### Endurecimento de Segurança

```bash
# Restringir acesso à rede Docker
sudo iptables -A DOCKER-USER -i eth0 ! -s 10.0.0.0/8 -j DROP

# Habilitar atualizações automáticas de segurança
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### Ajuste de Performance

Editar `docker-compose.yaml` para produção:

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

### Alertas de Monitoramento

Configurar alertas para:
- Inatividade de serviço
- Altas taxas de erro
- Limites de tamanho do banco de dados
- Avisos de espaço em disco
- Picos de uso de memória

---

## Solução de Problemas

### Serviços Não Iniciam

```bash
# Verificar logs do Docker
docker-compose logs

# Verificar configuração .env
cat .env | grep -v "^#" | grep .

# Verificar se portas estão disponíveis
sudo netstat -tulpn | grep -E ':(5678|8080|5432|6379)'
```

### Problemas de Conexão com Banco de Dados

```bash
# Testar PostgreSQL
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT 1;"

# Verificar logs do banco de dados
docker-compose logs postgres
```

### Evolution API Não Responde

```bash
# Verificar saúde da Evolution API
curl http://localhost:8080/health

# Verificar resolução DNS
docker-compose exec evolution_api nslookup google.com

# Reiniciar serviço
docker-compose restart evolution_api
```

---

## Procedimento de Rollback

Se a implantação falhar:

```bash
# Parar serviços
docker-compose down

# Restaurar do backup
docker-compose exec -T postgres psql -U n8n_clinic n8n_clinic_db < /backups/postgres/ultimo_backup.sql

# Reverter para versão anterior
git checkout <commit-anterior>

# Reiniciar serviços
docker-compose up -d
```

---

## Cronograma de Manutenção

### Diariamente
- Monitorar logs de erro
- Verificar saúde do serviço
- Verificar se backups foram concluídos

### Semanalmente
- Revisar métricas de execução
- Verificar espaço em disco
- Atualizar imagens Docker

### Mensalmente
- Atualizações de segurança
- Revisão de performance
- Verificação de backup
- Rotação de credenciais

---

## Suporte

Para problemas de implantação:
- Revisar logs: `docker-compose logs`
- Verificar documentação: `docs/`
- Abrir issue: GitHub Issues

---

**Versão do Guia de Implantação:** 1.0  
**Última Atualização:** 2026-01-01
