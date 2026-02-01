# Guia de Implantação

> **Documentação Proprietária**  
> Copyright © 2026. Todos os Direitos Reservados.  
> Este documento é confidencial e destinado apenas a clientes autorizados.

---

## Visão Geral

Este guia fornece um procedimento completo "Do Zero ao Herói" para implantação do **Sistema Multi-Agente de Gestão de Clínicas**. Siga estes passos para implantar o sistema em um servidor de produção.

**Tempo Estimado de Implantação**: 45-60 minutos (equipe de TI experiente)

---

## Pré-requisitos

### Requisitos de Servidor

| Recurso | Mínimo | Recomendado | Observações |
|---------|--------|-------------|-------------|
| **CPU** | 2 vCPU | 4 vCPU | Maior para >10 tenants |
| **RAM** | 4 GB | 8 GB | n8n + PostgreSQL + Redis |
| **Disco** | 20 GB SSD | 50 GB SSD | Crescimento do banco ao longo do tempo |
| **SO** | Ubuntu 20.04+ | Ubuntu 22.04 LTS | Ou Debian 11+ |
| **Rede** | IP Estático | IP Estático + Domínio | SSL recomendado |

### Pré-requisitos de Software

```bash
# 1. Docker Engine
docker --version  # Mínimo: 20.10+

# 2. Docker Compose
docker-compose --version  # Mínimo: 2.0+

# 3. Git (para acesso ao repositório)
git --version  # Qualquer versão recente

# 4. Cliente PostgreSQL (para acesso manual)
psql --version  # Opcional mas recomendado
```

### Serviços Externos Necessários

| Serviço | Propósito | Configuração Necessária |
|---------|-----------|-------------------------|
| **Projeto Google Cloud** | APIs Gemini AI, Calendar, Tasks | Habilitar APIs, criar service account |
| **Instância Evolution API** | Gateway WhatsApp | Hospedado ou self-hosted |
| **Bot Telegram** | Notificações internas da equipe | Criar bot via @BotFather |
| **Domínio/SSL** (opcional) | Acesso HTTPS à UI n8n | DNS + Let's Encrypt |

---

## Passo 1: Preparação do Servidor

### 1.1 Criar Usuário de Implantação

```bash
# No servidor (como root ou usuário sudo)
sudo adduser clinic-admin
sudo usermod -aG docker clinic-admin
sudo usermod -aG sudo clinic-admin

# Alternar para usuário de implantação
su - clinic-admin
```

### 1.2 Instalar Docker e Docker Compose

```bash
# Atualizar índice de pacotes
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Adicionar repositório Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verificar instalação
docker --version
docker compose version

# Testar Docker (sem sudo)
docker run hello-world
```

### 1.3 Configurar Firewall

```bash
# Permitir SSH
sudo ufw allow 22/tcp

# Permitir n8n (se expondo diretamente - não recomendado)
# sudo ufw allow 5678/tcp

# Permitir HTTPS (para proxy reverso)
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp

# Habilitar firewall
sudo ufw enable
sudo ufw status
```

---

## Passo 2: Configuração do Repositório

### 2.1 Clonar Repositório

```bash
# Criar diretório de implantação
mkdir -p ~/clinic-system
cd ~/clinic-system

# Clonar repositório (substitua com sua URL real do repositório)
git clone https://github.com/sua-empresa/clinic-multi-agent.git .

# Verificar estrutura
ls -la
# Esperado: docker-compose.yaml, env.example, workflows/, scripts/
```

### 2.2 Criar Arquivo de Ambiente

```bash
# Copiar template
cp env.example .env

# Editar com suas credenciais
nano .env
```

---

## Passo 3: Configuração de Ambiente

### 3.1 Configurações Principais

Edite o arquivo `.env` com seus valores de produção:

```bash
# ========================================
# CONFIGURAÇÃO PRINCIPAL
# ========================================
NODE_ENV=production
TIMEZONE=America/Sao_Paulo  # Seu fuso horário

# ========================================
# CONFIGURAÇÃO DO BANCO DE DADOS
# ========================================
POSTGRES_USER=clinic_admin
POSTGRES_PASSWORD=<GERAR_SENHA_FORTE>  # Use: openssl rand -base64 32
POSTGRES_DB=clinic_db
POSTGRES_PORT=5432

# String de conexão (usada pelo n8n)
DATABASE_URL=postgresql://clinic_admin:<SENHA>@postgres:5432/clinic_db

# ========================================
# CONFIGURAÇÃO DO REDIS
# ========================================
REDIS_PASSWORD=<GERAR_SENHA_FORTE>
REDIS_PORT=6379

# ========================================
# CONFIGURAÇÃO DO N8N
# ========================================
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=<GERAR_SENHA_FORTE>

N8N_HOST=seu-dominio.com  # Seu domínio ou IP
N8N_PORT=5678
N8N_PROTOCOL=https  # Use https em produção

# Chave de criptografia (CRÍTICO - faça backup desta!)
N8N_ENCRYPTION_KEY=<GERAR_CHAVE_32_CHAR>  # Use: openssl rand -hex 32

# ========================================
# CONFIGURAÇÃO EVOLUTION API
# ========================================
EVOLUTION_API_URL=https://sua-evolution-api.com
EVOLUTION_API_KEY=<SUA_CHAVE_EVOLUTION_API>

# ========================================
# CREDENCIAIS GOOGLE API
# ========================================
GOOGLE_GEMINI_API_KEY=<SUA_CHAVE_GEMINI_API>
GOOGLE_OAUTH_CLIENT_ID=<SEU_CLIENT_ID>
GOOGLE_OAUTH_CLIENT_SECRET=<SEU_CLIENT_SECRET>

# ========================================
# BOT TELEGRAM
# ========================================
TELEGRAM_BOT_TOKEN=<SEU_TOKEN_BOT>  # Obtenha do @BotFather
```

### 3.2 Referência de Variáveis de Ambiente

| Variável | Obrigatório | Descrição | Exemplo |
|----------|-------------|-----------|---------|
| `POSTGRES_PASSWORD` | ✅ | Senha root PostgreSQL | `d7k2m9fj3l8n...` |
| `REDIS_PASSWORD` | ✅ | Senha de autenticação Redis | `a8s9d7f6g5h4...` |
| `N8N_ENCRYPTION_KEY` | ✅ | Chave de criptografia de credenciais n8n | `3f7a9b2c8d1e...` |
| `N8N_BASIC_AUTH_PASSWORD` | ✅ | Senha da UI web n8n | Sua senha segura |
| `EVOLUTION_API_KEY` | ✅ | Autenticação Evolution API | Do seu dashboard Evolution |
| `GOOGLE_GEMINI_API_KEY` | ✅ | Chave API Google AI | Do Google Cloud Console |
| `TELEGRAM_BOT_TOKEN` | ✅ | Token do bot Telegram | Do @BotFather |
| `N8N_HOST` | ❌ | Domínio público para webhooks | `clinica.exemplo.com` |
| `N8N_PROTOCOL` | ❌ | Protocolo HTTP (http/https) | `https` (recomendado) |
| `TIMEZONE` | ❌ | Fuso horário do servidor | `America/Sao_Paulo` |

### 3.3 Estratégia de Credenciais Multi-Tenant

O sistema suporta múltiplos tenants (clínicas) com isolamento completo. A estratégia de credenciais segue o princípio de "configuração via banco de dados":

#### Tipos de Credenciais

| Tipo | Onde Armazenar | Exemplo |
|------|----------------|---------|
| **Globais** | `.env` / Variáveis de ambiente | DB URL, Redis, N8N_ENCRYPTION_KEY |
| **Por Tenant** | Tabela `tenant_config` | Evolution instance, Telegram chat ID |
| **Google Calendar** | Tabela `calendars` + n8n Credentials | Um OAuth credential por clínica |

#### Configuração de Credenciais Google Calendar

**Opção 1: Uma Credencial por Tenant (Recomendado)**

1. No Google Cloud Console, crie um projeto OAuth por clínica
2. No n8n, crie uma credencial `Google OAuth2 API` para cada clínica
3. Anote o ID da credencial n8n (visível na URL ao editar)
4. Insira na tabela `calendars`:

```sql
INSERT INTO calendars (
    tenant_id,
    professional_id,
    google_calendar_id,
    credential_ref,
    credential_type,
    is_primary
) VALUES (
    'uuid-do-tenant',
    'uuid-do-profissional',
    'email-do-profissional@gmail.com',
    'ID_DA_CREDENCIAL_N8N',  -- ex: 'J2K8L9M0N1P2Q3R4'
    'n8n_credential',
    true
);
```

**Opção 2: Credencial Padrão por Tenant**

1. Configure uma credencial OAuth no n8n
2. Armazene o ID na tabela `tenant_config`:

```sql
UPDATE tenant_config
SET default_google_credential_id = 'ID_DA_CREDENCIAL_N8N'
WHERE tenant_id = 'uuid-do-tenant';
```

3. Calendars sem `credential_ref` usarão a credencial padrão do tenant

**Opção 3: Variável de Ambiente (Desenvolvimento)**

1. No `.env`: `GOOGLE_CALENDAR_CREDENTIAL_CLINIC_A=seu_id`
2. Na tabela `calendars`:

```sql
UPDATE calendars
SET credential_ref = 'GOOGLE_CALENDAR_CREDENTIAL_CLINIC_A',
    credential_type = 'env_key'
WHERE calendar_id = 'uuid-do-calendario';
```

#### Fluxo de Resolução de Credenciais

```
Workflow precisa de Google Calendar
        │
        ▼
┌───────────────────────────────┐
│ Busca calendar por            │
│ professional_id + tenant_id   │
└───────────────────────────────┘
        │
        ▼
┌───────────────────────────────┐
│ calendars.credential_ref      │
│ tem valor?                    │
└───────────────────────────────┘
     │           │
    SIM         NÃO
     │           │
     ▼           ▼
┌──────────┐ ┌──────────────────────┐
│ Usa      │ │ Usa                  │
│ credential│ │ tenant_config.       │
│ _ref     │ │ default_google_      │
│          │ │ credential_id        │
└──────────┘ └──────────────────────┘
```

#### Onboarding de Nova Clínica (Apenas DB)

Adicionar um novo tenant requer apenas inserções no banco:

```sql
-- 1. Criar tenant
INSERT INTO tenant_config (tenant_name, evolution_instance_name, clinic_name, ...)
VALUES ('Nova Clínica', 'nova_clinica_instance', 'Nova Clínica Ltda', ...);

-- 2. Criar profissionais
INSERT INTO professionals (tenant_id, professional_name, google_calendar_id, ...)
VALUES ((SELECT tenant_id FROM tenant_config WHERE tenant_name = 'Nova Clínica'), 
        'Dr. João', 'dr.joao@gmail.com', ...);

-- 3. Registrar calendários (se usando credenciais por profissional)
SELECT register_professional_calendar(
    (SELECT tenant_id FROM tenant_config WHERE tenant_name = 'Nova Clínica'),
    (SELECT professional_id FROM professionals WHERE professional_name = 'Dr. João'),
    'dr.joao@gmail.com',
    'ID_CREDENCIAL_N8N',
    true
);

-- 4. Configurar serviços do profissional
INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents, ...)
VALUES (...);
```

**Nenhuma edição de workflow é necessária para adicionar novos tenants!**

### 3.3 Melhores Práticas de Segurança

```bash
# Gerar senhas fortes
openssl rand -base64 32  # Para senhas
openssl rand -hex 32     # Para chaves de criptografia

# Restringir permissões do .env
chmod 600 .env
chown clinic-admin:clinic-admin .env

# Verificar se não há secrets no git
cat .gitignore | grep ".env"  # Deve estar listado
```

---

## Passo 4: Inicialização do Banco de Dados

### 4.1 Iniciar Container do Banco de Dados

```bash
# Iniciar apenas o PostgreSQL primeiro
docker compose up -d postgres

# Aguardar banco ficar pronto (30 segundos)
sleep 30

# Verificar se PostgreSQL está saudável
docker compose ps postgres
# Deve mostrar status "healthy"
```

### 4.2 Executar Migrações

> O `init-db.sh` roda automaticamente apenas na primeira inicialização do container com volume vazio.  
> Para ambientes existentes, aplique migrations com o script abaixo.

```bash
# Método 1: Aplicar migrations (recomendado para ambientes existentes)
chmod +x scripts/apply-migrations.sh
./scripts/apply-migrations.sh

# Método 2: Migração manual
docker compose exec -T postgres psql -U clinic_admin -d clinic_db < scripts/migrations/001_create_tenant_tables.sql
docker compose exec -T postgres psql -U clinic_admin -d clinic_db < scripts/migrations/002_seed_tenant_data.sql
docker compose exec -T postgres psql -U clinic_admin -d clinic_db < scripts/migrations/003_create_faq_table.sql
```

### 4.3 Verificar Configuração do Banco

```bash
# Conectar ao banco de dados
docker compose exec postgres psql -U clinic_admin -d clinic_db

# Dentro do psql:
\dt  # Listar tabelas - deve mostrar tenant_config, tenant_faq, etc.
\q   # Sair
```

---

## Passo 5: Implantação dos Serviços

### 5.1 Iniciar Todos os Serviços

```bash
# Puxar imagens mais recentes
docker compose pull

# Iniciar todos os containers
docker compose up -d

# Verificar status
docker compose ps
# Todos os serviços devem estar "healthy" ou "running"
```

### 5.2 Verificar Serviços

```bash
# Verificar logs
docker compose logs -f n8n  # Pressione Ctrl+C para sair

# Verificações de saúde
curl http://localhost:5678/healthz  # n8n
docker compose exec postgres pg_isready  # PostgreSQL
docker compose exec redis redis-cli ping  # Redis (pedirá senha)
```

---

## Passo 6: Configuração do n8n

### 6.1 Acessar UI do n8n

1. Abra o navegador: `http://ip-do-seu-servidor:5678`
2. Faça login com as credenciais do `.env`:
   - **Usuário**: `admin` (ou seu `N8N_BASIC_AUTH_USER`)
   - **Senha**: Seu `N8N_BASIC_AUTH_PASSWORD`

### 6.2 Configurar Credenciais

Navegue até **Settings** → **Credentials** e crie:

#### 1. Google Gemini API

- Tipo: `HTTP Request`
- Nome: `Google Gemini Shared`
- Autenticação: `Generic Credential Type`
- Adicionar header: `x-goog-api-key` = Seu `GOOGLE_GEMINI_API_KEY`

#### 2. PostgreSQL

- Tipo: `Postgres`
- Nome: `Postgres account`
- Host: `postgres`
- Porta: `5432`
- Banco: `clinic_db`
- Usuário: Seu `POSTGRES_USER`
- Senha: Seu `POSTGRES_PASSWORD`
- SSL: Desabilitado (rede interna)

#### 3. Evolution API

- Tipo: `HTTP Request`
- Nome: `Evolution API Master`
- Autenticação: `Generic Credential Type`
- URL Base: Sua `EVOLUTION_API_URL`
- Adicionar header: `apikey` = Sua `EVOLUTION_API_KEY`

#### 4. Bot Telegram

- Tipo: `Telegram`
- Nome: `Telegram Bot Shared`
- Access Token: Seu `TELEGRAM_BOT_TOKEN`

#### 5. Google OAuth (Calendar + Tasks)

- Tipo: `Google OAuth2 API`
- Nome: `Google OAuth Shared`
- Client ID: Seu `GOOGLE_OAUTH_CLIENT_ID`
- Client Secret: Seu `GOOGLE_OAUTH_CLIENT_SECRET`
- Siga o fluxo OAuth para autorizar

### 6.3 Importar Workflows

1. **Importar Workflows Principais**:
   - Vá para **Workflows** → **Import from File**
   - Importe cada arquivo de `workflows/main/`:
     - `01-whatsapp-patient-handler-optimized.json` ⭐
     - `02-telegram-internal-assistant-multitenant.json`
     - `03-appointment-confirmation-scheduler.json`
     - `04-error-handler.json`

2. **Importar Sub-Workflows**:
   - Importe `workflows/sub/tenant-config-loader.json`

3. **Importar Workflows de Ferramentas**:
   - Importe todos os arquivos de `workflows/tools/*/`

4. **Atualizar IDs de Credenciais**:
   - Abra cada workflow
   - Clique nos nós com credenciais
   - Selecione a credencial correspondente que você criou
   - Salve o workflow

5. **Ativar Workflows**:
   - Alterne o switch "Active" para workflows principais
   - Sub-workflows e ferramentas permanecem inativos (chamados pelos workflows principais)

---

## Passo 7: Configuração de Tenant

### 7.1 Adicionar Seu Primeiro Tenant

```bash
# Opção única: SQL direto
docker compose exec postgres psql -U clinic_admin -d clinic_db

# Dentro do psql:
INSERT INTO tenant_config (
    tenant_name,
    evolution_instance_name,
    clinic_name,
    clinic_address,
    clinic_phone,
    google_calendar_id,
    google_tasks_list_id,
    telegram_internal_chat_id,
    system_prompt_patient,
    system_prompt_internal,
    system_prompt_confirmation
) VALUES (
    'Clínica Exemplo',
    'clinic_example_instance',  -- Deve corresponder ao nome da instância Evolution API
    'Clínica Exemplo Ltda',
    'Rua Exemplo, 123 - São Paulo, SP',
    '+55 11 98765-4321',
    'seu-calendar-id@group.calendar.google.com',
    'seu-tasks-list-id',
    'seu-telegram-chat-id',
    'Você é o assistente da Clínica Exemplo...',
    'Você é o assistente interno da Clínica Exemplo...',
    'Você é o agente de confirmação da Clínica Exemplo...'
);
```

### 7.2 Configurar Instância Evolution API

No seu dashboard Evolution API:

1. Crie a instância com nome: `clinic_example_instance` (deve corresponder a `evolution_instance_name` no banco)
2. Configure URL de webhook: `http://ip-do-seu-servidor:5678/webhook/whatsapp-webhook`
3. Habilite eventos: `messages.upsert`
4. Conecte o WhatsApp via QR code

### 7.3 Configurar Bot Telegram

1. Obtenha o chat ID:
   - Envie mensagem para seu bot: `/start`
   - Verifique logs do n8n ou use: `https://api.telegram.org/bot<TOKEN>/getUpdates`
2. Atualize `telegram_internal_chat_id` no banco de dados com seu chat ID

---

## Passo 8: Testes

### 8.1 Testar Fluxo WhatsApp

1. Envie mensagem WhatsApp para seu número conectado: `Oi`
2. Verifique logs de execução do n8n (painel Executions)
3. Deve receber resposta do bot: "Olá! Seja bem-vindo..."

### 8.2 Testar Fluxo Telegram

1. Envie mensagem Telegram para o bot: `Qual a próxima consulta?`
2. Verifique logs de execução do n8n
3. Deve receber resposta do bot

### 8.3 Testar Cache FAQ

```sql
-- Verificar entradas FAQ
SELECT question_original, view_count 
FROM tenant_faq 
WHERE tenant_id = 'seu-tenant-id';

-- Envie a mesma pergunta duas vezes via WhatsApp
-- View count deve incrementar
```

---

## Passo 9: Hardening de Produção

### 9.1 Configurar Proxy Reverso (NGINX)

```bash
# Instalar NGINX
sudo apt install nginx

# Criar configuração
sudo nano /etc/nginx/sites-available/clinic-n8n

# Adicionar configuração:
server {
    listen 80;
    server_name seu-dominio.com;
    
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# Habilitar site
sudo ln -s /etc/nginx/sites-available/clinic-n8n /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 9.2 Configurar SSL com Let's Encrypt

```bash
# Instalar certbot
sudo apt install certbot python3-certbot-nginx

# Obter certificado
sudo certbot --nginx -d seu-dominio.com

# Auto-renovação é configurada automaticamente
sudo certbot renew --dry-run
```

### 9.3 Configurar Backups Automatizados

```bash
# Criar script de backup
sudo nano /usr/local/bin/clinic-backup.sh

#!/bin/bash
BACKUP_DIR="/backup/clinic-system"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup do banco de dados
docker compose exec -T postgres pg_dump -U clinic_admin clinic_db > $BACKUP_DIR/db_$DATE.sql

# Backup dos dados n8n
docker compose exec -T n8n tar czf - /home/node/.n8n > $BACKUP_DIR/n8n_$DATE.tar.gz

# Backup do .env
cp .env $BACKUP_DIR/env_$DATE

# Manter últimos 7 dias
find $BACKUP_DIR -name "db_*" -mtime +7 -delete
find $BACKUP_DIR -name "n8n_*" -mtime +7 -delete

# Tornar executável
sudo chmod +x /usr/local/bin/clinic-backup.sh

# Adicionar ao crontab (diariamente às 2h)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/clinic-backup.sh") | crontab -
```

### 9.4 Configurar Monitoramento

```bash
# Criar script de verificação de saúde
nano ~/check-health.sh

#!/bin/bash
# Verificar n8n
if ! curl -f http://localhost:5678/healthz > /dev/null 2>&1; then
    echo "n8n está FORA DO AR!" | mail -s "ALERTA: Verificação de Saúde n8n Falhou" admin@exemplo.com
    docker compose restart n8n
fi

# Verificar PostgreSQL
if ! docker compose exec postgres pg_isready > /dev/null 2>&1; then
    echo "PostgreSQL está FORA DO AR!" | mail -s "ALERTA: Verificação de Saúde PostgreSQL Falhou" admin@exemplo.com
    docker compose restart postgres
fi

chmod +x ~/check-health.sh

# Executar a cada 5 minutos
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/check-health.sh") | crontab -
```

---

## Passo 10: Verificação Pós-Implantação

### 10.1 Checklist

- [ ] Todos os containers Docker rodando e saudáveis
- [ ] Banco de dados acessível e migrações aplicadas
- [ ] UI do n8n acessível via HTTPS
- [ ] Todas as credenciais configuradas no n8n
- [ ] Todos os workflows importados e ativados
- [ ] Pelo menos um tenant configurado
- [ ] Webhook WhatsApp recebendo mensagens
- [ ] Bot Telegram respondendo
- [ ] Certificado SSL válido
- [ ] Backups automatizados agendados
- [ ] Monitoramento/verificações de saúde ativos

### 10.2 Baseline de Performance

```bash
# Verificar uso de recursos
docker stats

# Esperado (ocioso):
# n8n: 200-400 MB RAM, 5-10% CPU
# postgres: 100-200 MB RAM, 1-5% CPU
# redis: 10-50 MB RAM, 1-2% CPU
```

---

## Manutenção

### Tarefas Diárias

- [ ] Verificar logs de execução para erros
- [ ] Monitorar espaço em disco: `df -h`
- [ ] Revisar execuções do workflow de erros

### Tarefas Semanais

- [ ] Revisar performance do cache FAQ
- [ ] Verificar integridade dos backups
- [ ] Atualizar configurações de tenants se necessário

### Tarefas Mensais

- [ ] Revisar e atualizar workflows
- [ ] Verificar atualizações do n8n
- [ ] Revisar e otimizar banco de dados
- [ ] Atualizações de patches de segurança

---

## Resolução de Problemas

### n8n Não Inicia

```bash
# Verificar logs
docker compose logs n8n

# Problemas comuns:
# 1. Banco não está pronto - aguarde 30s e reinicie
# 2. Chave de criptografia não confere - verifique .env
# 3. Conflito de porta - verifique se 5678 está em uso
```

### Webhook Não Recebe Mensagens

```bash
# 1. Verifique configuração de webhook na Evolution API
# 2. Verifique se firewall permite conexões de entrada
# 3. Verifique logs do n8n para erros de webhook
# 4. Teste webhook manualmente:
curl -X POST http://ip-do-seu-servidor:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Alto Uso de Memória

```bash
# Verificar qual container
docker stats

# Se n8n estiver alto:
# 1. Verifique execuções travadas
# 2. Reduza complexidade dos workflows
# 3. Aumente RAM do servidor

# Se postgres estiver alto:
# 1. Verifique índices faltando
# 2. Execute VACUUM ANALYZE
# 3. Aumente shared_buffers
```

---

## Procedimento de Rollback

```bash
# 1. Parar serviços
docker compose down

# 2. Restaurar banco de dados
docker compose up -d postgres
cat backup_YYYYMMDD.sql | docker compose exec -T postgres psql -U clinic_admin -d clinic_db

# 3. Restaurar dados n8n
docker compose up -d n8n
docker cp backup_n8n_data.tar.gz n8n:/tmp/
docker compose exec n8n tar xzf /tmp/backup_n8n_data.tar.gz -C /

# 4. Reiniciar tudo
docker compose down && docker compose up -d
```

---

## Suporte

Para suporte técnico, entre em contato:
- **Email**: suporte@sua-empresa.com
- **Documentação**: https://docs.sua-empresa.com
- **Chave de Licença**: Necessária para acesso ao suporte

---

**Versão do Documento**: 1.0  
**Última Atualização**: 01-01-2026  
**Classificação**: Proprietário e Confidencial
