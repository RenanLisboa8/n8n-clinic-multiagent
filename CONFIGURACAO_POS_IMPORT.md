# Configuração Pós-Importação - n8n Workflows

## ✅ Checklist Rápido

Siga este checklist após importar os workflows no n8n:

## 🔍 Verificações Críticas

### 1. Nomes dos Workflows

Os workflows **DEVEM** ter estes nomes EXATOS no n8n:

#### Workflows Principais (ATIVOS):
- ✅ `01 - WhatsApp Patient Handler (AI Optimized)` 
- ✅ `04 - Error Handler`

#### Sub-Workflows (INATIVOS - chamados por outros):
- ⚪ `Tenant Config Loader`

#### Tool Workflows (INATIVOS - chamados por agentes):
- ⚪ `Find Professionals Tool`
- ⚪ `Google Calendar Availability Tool`
- ⚪ `Google Calendar Create Event Tool`
- ⚪ `Google Calendar List Events Tool`
- ⚪ `Image OCR Tool`
- ⚪ `Audio Transcription Tool`
- ⚪ `WhatsApp Send Tool`
- ⚪ `Telegram Notify Tool`
- ⚪ `Call to Human Tool`
- ⚪ `Google Calendar Update Event Tool`
- ⚪ `Google Calendar Delete Event Tool`

> **ℹ️ NOTA:** O `Message Formatter Tool` foi removido. A formatação agora é feita inline no patient-handler.

> **⚠️ IMPORTANTE:** Se os nomes estiverem diferentes após a importação, **renomeie** no n8n para corresponder exatamente aos nomes acima.

### 2. Configuração de Credenciais

Configure estas credenciais no n8n (**Settings → Credentials**):

| Credencial | Nome no n8n | Tipo |
|------------|-------------|------|
| `POSTGRES_CREDENTIAL_ID` | `Postgres account` | Postgres |
| `GOOGLE_GEMINI_CREDENTIAL_ID` | `Google Gemini Shared` | HTTP Request / Generic |
| `EVOLUTION_API_CREDENTIAL_ID` | `Evolution API` | HTTP Request / Generic |
| `TELEGRAM_BOT_CREDENTIAL_ID` | `Telegram Bot Shared` | Telegram |
| `GOOGLE_CALENDAR_CREDENTIAL_ID` | `Google Calendar OAuth2` | Google OAuth2 |
| `GOOGLE_TASKS_CREDENTIAL_ID` | `Google Tasks OAuth2` | Google OAuth2 |

**Como configurar:**

1. Vá em **Settings → Credentials**
2. Clique em **Add Credential**
3. Selecione o tipo apropriado
4. Preencha os dados necessários
5. Salve com o nome exato da tabela acima

**Depois, atualize cada workflow:**

1. Abra o workflow no n8n
2. Clique em cada nó que usa credenciais
3. No campo "Credential to connect with", selecione a credencial que você criou
4. Salve o workflow

### 3. Status dos Workflows

**Workflows que DEVEM estar ATIVOS:**
- ✅ `01 - WhatsApp Patient Handler (AI Optimized)`
- ✅ `04 - Error Handler`

**Todos os outros workflows DEVEM estar INATIVOS** (são chamados automaticamente pelos workflows principais).

### 4. Configurações Específicas por Nó

#### Google Gemini Chat Model
- **Retry On Fail:** DESABILITADO ✅
- **Model:** `gemini-2.0-flash-lite` ✅

#### Image OCR Tool
- **Retry On Fail:** DESABILITADO ✅
- **Model:** `models/gemini-2.0-flash-lite` ✅

#### Audio Transcription Tool
- **Retry On Fail:** DESABILITADO ✅
- **Model:** `models/gemini-2.0-flash-lite` ✅

### 5. Variáveis de Ambiente

Configure estas variáveis no n8n (**Settings → Variables**) ou no arquivo `.env`:

| Variável | Obrigatório | Descrição |
|----------|-------------|-----------|
| `TELEGRAM_INTERNAL_CHAT_ID` | ✅ | Chat ID do Telegram para notificações internas |
| `EVOLUTION_INSTANCE_NAME` | ✅ | Nome da instância Evolution API |
| `N8N_WEBHOOK_URL` | ✅ | URL base do n8n (ex: `http://localhost:5678/`) |
| `CLINIC_PHONE` | ⚪ | Telefone da clínica (usado no Error Handler) |

### 6. Teste Básico

Após configurar tudo, teste:

#### Teste 1: Tenant Config Loader
1. Abra o workflow `Tenant Config Loader`
2. Clique em **Execute Workflow**
3. Forneça este JSON de teste:
   ```json
   {
     "instance_name": "seu_instance_name_aqui"
   }
   ```
4. Deve retornar `tenant_config` completo sem erros

#### Teste 2: Workflow Principal
1. Envie uma mensagem de teste via WhatsApp
2. Verifique se o workflow executa sem erros
3. Verifique se a resposta é formatada corretamente

## 🚨 Erros Comuns e Soluções

### Erro: "Workflow not found: Tenant Config Loader"
**Solução:**
- Verifique se o workflow foi importado
- Verifique se o nome está exatamente `Tenant Config Loader` (sem prefixo "01 -" ou similar)
- Renomeie se necessário no n8n

### Erro: "Invalid credential ID"
**Solução:**
- Abra o workflow que está dando erro
- Clique no nó que mostra o erro
- Selecione a credencial correta no dropdown
- Salve o workflow

### Erro: "429 Too Many Requests" (quota exceeded)
**Solução:**
- Verifique se `retryOnFail` está **DESABILITADO** em todos os nós Gemini
- Verifique se o modelo está configurado como `gemini-2.0-flash-lite`

### Erro: "Find Professionals Tool not found"
**Solução:**
- Importe o arquivo `workflows/tools/service/find-professionals-tool.json`
- Verifique se o nome do workflow é exatamente `Find Professionals Tool`
- Verifique se o workflow está **ATIVO** (tool workflows podem precisar estar ativos)

### Erro: "Error Handler not found"
**Solução:**
- Verifique se o workflow `04 - Error Handler` foi importado
- Nos workflows principais, verifique se o `errorWorkflow` está configurado como `'04 - Error Handler'`

## 📋 Scripts Úteis

```bash
# Importar workflows
./scripts/import-workflows.sh

# Reimportar workflows com fallback automático
./scripts/reimport-all-workflows.sh
```

## ✅ Checklist Final

Antes de considerar tudo configurado, verifique:

- [ ] Todos os workflows foram importados
- [ ] Nomes dos workflows estão corretos
- [ ] Todas as credenciais foram configuradas
- [ ] Credenciais foram selecionadas em cada workflow
- [ ] Workflows principais estão ATIVOS
- [ ] Tool workflows estão INATIVOS (ou ativos, conforme necessário)
- [ ] Retries estão desabilitados em nós Gemini
- [ ] Modelo está configurado como `gemini-2.0-flash-lite`
- [ ] Variáveis de ambiente foram configuradas
- [ ] Teste do Tenant Config Loader passou
- [ ] Teste do workflow principal passou

## 🆘 Ainda com Problemas?

1. Verifique os logs do n8n: `docker-compose logs -f n8n`
2. Revise nomes e credenciais diretamente no n8n
3. Aplique migrations pendentes: `./scripts/apply-migrations.sh`
4. Consulte a documentação: `docs/DEPLOYMENT.md`
