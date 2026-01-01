# Guia de Início Rápido

Coloque o Sistema Multi-Agente n8n para Clínicas funcionando em 15 minutos!

---

## Verificação de Pré-requisitos

```bash
# Verificar Docker instalado
docker --version  # Deve mostrar 20.10+

# Verificar Docker Compose instalado
docker-compose --version  # Deve mostrar v2.0+
```

Se não estiver instalado, veja [DEPLOYMENT.md](DEPLOYMENT.md) Passo 1.

---

## Passo 1: Clonar e Navegar (1 minuto)

```bash
cd /opt  # ou seu diretório preferido
git clone https://github.com/seuusuario/n8n-clinic-multiagent.git
cd n8n-clinic-multiagent
```

---

## Passo 2: Gerar Segredos (2 minutos)

```bash
# Copiar template de ambiente
cp env.example .env

# Gerar todos os segredos de uma vez
cat >> .env << EOF
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_JWT_SECRET=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -hex 32)
EVOLUTION_API_KEY=$(openssl rand -hex 32)
EOF

echo "✅ Segredos gerados!"
```

---

## Passo 3: Configurar Essenciais (5 minutos)

Editar `.env` e preencher estes valores OBRIGATÓRIOS:

```bash
nano .env  # ou seu editor preferido
```

**Configuração mínima:**

```env
# Seu domínio ou IP
N8N_WEBHOOK_URL=http://SEU_IP:5678/
EVOLUTION_BASE_URL=http://SEU_IP:8080

# Serviços Google (obter de console.cloud.google.com)
GOOGLE_CALENDAR_ID=seu-calendar-id@group.calendar.google.com
GOOGLE_GEMINI_API_KEY=sua-chave-api-de-ai-google-dev

# Telegram (obter de @BotFather)
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHI...
TELEGRAM_INTERNAL_CHAT_ID=seu-chat-id

# Informações da clínica
CLINIC_NAME=Nome da Sua Clínica
CLINIC_PHONE=+5511999999999
CLINIC_EMAIL=contato@clinica.com
CLINIC_ADDRESS=Seu Endereço
CLINIC_CALENDAR_PUBLIC_LINK=seu-link-google-calendar

# Endpoint MCP (se usar)
MCP_CALENDAR_ENDPOINT=sua-url-endpoint-mcp
```

**Onde obter estes:**
- API Gemini: https://makersuite.google.com/app/apikey
- Bot Telegram: Falar com @BotFather no Telegram
- ID do Chat: Enviar /start para @userinfobot no Telegram
- ID do Calendar: Configurações do Google Calendar → Integrar Calendário

Salvar e sair (Ctrl+X, Y, Enter no nano).

---

## Passo 4: Iniciar Serviços (2 minutos)

```bash
# Iniciar todos os serviços
docker-compose up -d

# Aguardar ~30 segundos para serviços inicializarem

# Verificar status (todos devem estar "healthy")
docker-compose ps
```

Saída esperada:
```
NOME                  STATUS
clinic_postgres       Up (healthy)
clinic_redis          Up (healthy)
clinic_evolution_api  Up (healthy)
clinic_n8n            Up (healthy)
```

Se não estiver saudável, aguarde mais 30 segundos e verifique novamente.

---

## Passo 5: Acessar n8n (1 minuto)

Abrir navegador: `http://SEU_IP:5678`

**Configuração inicial:**
1. Criar conta de administrador (salvar credenciais!)
2. Completar assistente de configuração
3. Pular seleção de templates

---

## Passo 6: Adicionar Credenciais (3 minutos)

No n8n: **Configurações** → **Credenciais** → **Adicionar Credencial**

Adicionar estas (mínimo):

### 1. Evolution API
- Tipo: Evolution API
- URL: `http://evolution_api:8080`
- Chave API: (do seu arquivo .env)

### 2. Google Gemini
- Tipo: Google PaLM
- Chave API: (do seu arquivo .env)

### 3. Telegram
- Tipo: Telegram
- Token de Acesso: (do seu arquivo .env)

### 4. PostgreSQL
- Tipo: Postgres
- Host: `postgres`
- Porta: `5432`
- Banco de Dados: `n8n_clinic_db`
- Usuário: `n8n_clinic`
- Senha: (do seu arquivo .env)

---

## Passo 7: Importar Ferramenta de Exemplo (1 minuto)

**Para testar a configuração:**

1. No n8n: **Workflows** → **Importar de Arquivo**
2. Selecionar: `workflows/tools/communication/whatsapp-send-tool.json`
3. Clicar em **Importar**
4. Atualizar referências de credenciais se necessário
5. Clicar em **Salvar**

---

## Passo 8: Testar! (Opcional)

### Testar Ferramenta WhatsApp

1. Abrir o workflow `WhatsApp Send Tool` importado
2. Clicar no botão **Executar Workflow**
3. Nos dados de teste, inserir:
```json
{
  "remote_jid": "5511999999999@s.whatsapp.net",
  "message_text": "Mensagem de teste do n8n!"
}
```
4. Clicar em **Executar**
5. Verificar WhatsApp para mensagem

---

## Próximos Passos

### Para Desenvolvimento

Continuar com configuração completa:
1. Importar workflows de ferramentas restantes
2. Importar workflows principais
3. Configurar webhooks
4. Testar fluxos completos

Ver: [DEPLOYMENT.md](DEPLOYMENT.md) para guia completo

### Para Produção

Antes de entrar ao vivo:
1. Configurar SSL (HTTPS)
2. Configurar firewall
3. Configurar backups
4. Configurar monitoramento

Ver: [DEPLOYMENT.md](DEPLOYMENT.md) Passo 3 em diante

---

## Problemas Comuns

### "Serviço Não Saudável"

**Solução:**
```bash
# Verificar logs
docker-compose logs [nome_servico]

# Causas comuns:
# - Senha errada no .env
# - Porta já em uso
# - Memória insuficiente
```

### "Não Pode Conectar ao Banco de Dados"

**Solução:**
```bash
# Verificar se PostgreSQL está rodando
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT 1;"

# Se falhar, verificar se POSTGRES_PASSWORD no .env corresponde em todos os lugares
```

### "Evolution API Não Responde"

**Solução:**
```bash
# Verificar se serviço está ativo
curl http://localhost:8080/health

# Reiniciar se necessário
docker-compose restart evolution_api
```

---

## Referência Rápida de Comandos

```bash
# Ver logs
docker-compose logs -f

# Reiniciar serviço
docker-compose restart [nome_servico]

# Parar todos
docker-compose down

# Iniciar todos
docker-compose up -d

# Verificar status
docker-compose ps

# Ver uso de recursos
docker stats
```

---

## Obtendo Ajuda

- 📖 **Documentação Completa**: Ver [README.md](../README.md)
- 🏗️ **Arquitetura**: Ver [docs/ARCHITECTURE.md](ARCHITECTURE.md)
- 🚀 **Implantação**: Ver [docs/DEPLOYMENT.md](DEPLOYMENT.md)
- 🔧 **Refatoração**: Ver [docs/REFACTORING_GUIDE.md](REFACTORING_GUIDE.md)

---

## Lembrete de Segurança ⚠️

**Antes da produção:**
- [ ] Alterar todas as senhas padrão
- [ ] Configurar HTTPS/SSL
- [ ] Configurar regras de firewall
- [ ] Fazer backup de chaves de criptografia
- [ ] Habilitar monitoramento

---

**Tudo pronto!** 🎉

Seu Sistema Multi-Agente n8n para Clínicas está rodando e pronto para configuração.

---

*Guia de Início Rápido v1.0 - Atualizado: 2026-01-01*
