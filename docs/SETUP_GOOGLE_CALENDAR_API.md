# Setup Google Calendar API - Guia Completo

## 🎯 Objetivo

Configurar Google Calendar API diretamente no n8n, **sem depender de MCP pago**, para gerenciar múltiplos calendários de profissionais.

## ✅ Vantagens

- ✅ **100% Gratuito** (dentro dos limites do Google)
- ✅ **Sem dependência de serviços externos**
- ✅ **Suporte nativo a múltiplos calendários**
- ✅ **Controle total**

## 📋 Passo a Passo

### 1. Criar Projeto no Google Cloud

1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Clique em **"Select a project"** → **"New Project"**
3. Nome: `Clinic Calendar API` (ou similar)
4. Clique em **"Create"**

### 2. Habilitar Google Calendar API

1. No menu lateral, vá em **"APIs & Services"** → **"Library"**
2. Busque por **"Google Calendar API"**
3. Clique em **"Enable"**

### 3. Criar Credenciais OAuth 2.0

1. Vá em **"APIs & Services"** → **"Credentials"**
2. Clique em **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
3. Se pedir, configure **OAuth consent screen**:
   - User Type: **External**
   - App name: `Clinic Calendar`
   - User support email: Seu email
   - Developer contact: Seu email
   - Clique em **"Save and Continue"**
   - Scopes: Adicione `.../auth/calendar`
   - Clique em **"Save and Continue"**
   - Test users: Adicione seu email
   - Clique em **"Save and Continue"** → **"Back to Dashboard"**

4. Volte em **"Credentials"** → **"+ CREATE CREDENTIALS"** → **"OAuth client ID"**
5. Application type: **Web application**
6. Name: `n8n Calendar Integration`
7. Authorized redirect URIs:
   ```
   http://localhost:5678/rest/oauth2-credential/callback
   ```
   (Se n8n estiver em outro host, ajuste)
8. Clique em **"Create"**
9. **Copie o Client ID e Client Secret** (você precisará deles)

### 4. Configurar no n8n

1. Acesse seu n8n
2. Vá em **Settings** → **Credentials**
3. Clique em **"+ Add Credential"**
4. Busque por **"Google Calendar OAuth2 API"**
5. Preencha:
   - **Client ID**: Cole o Client ID copiado
   - **Client Secret**: Cole o Client Secret copiado
   - **Scope**: `https://www.googleapis.com/auth/calendar`
6. Clique em **"Connect my account"**
7. Autorize o acesso na tela do Google
8. Salve a credencial com nome: `Google Calendar OAuth2`

### 5. Testar Conexão

1. Crie um workflow de teste
2. Adicione nó **"Google Calendar"**
3. Selecione a credencial criada
4. Operation: **"Get All"**
5. Execute e verifique se lista seus calendários

## 🔧 Configurar Múltiplos Calendários

### Para Cada Profissional

1. No Google Calendar, crie um calendário separado para cada profissional
2. Compartilhe o calendário com a conta OAuth configurada no n8n
3. Dê permissão de **"Make changes to events"**
4. Copie o **Calendar ID** (formato: `email@group.calendar.google.com` ou similar)
5. Adicione no banco de dados na tabela `professionals` → campo `google_calendar_id`

### Calendar ID

O Calendar ID pode ser:
- Email do calendário: `profissional@group.calendar.google.com`
- ID do calendário primário: `primary`
- ID customizado: `c_xxxxxxxxxxxxx@group.calendar.google.com`

**Como encontrar o Calendar ID**:
1. Abra Google Calendar
2. Clique nos **3 pontos** ao lado do calendário
3. Vá em **"Settings and sharing"**
4. Role até **"Integrate calendar"**
5. Copie o **"Calendar ID"**

## 📝 Usar nos Workflows

### Exemplo: Consultar Disponibilidade

```json
{
  "operation": "freebusy",
  "calendar": "={{ $json.google_calendar_id }}",
  "options": {
    "timeMin": "2026-01-03T08:00:00-03:00",
    "timeMax": "2026-01-03T20:00:00-03:00"
  }
}
```

### Exemplo: Criar Evento

```json
{
  "operation": "create",
  "calendar": "={{ $json.google_calendar_id }}",
  "summary": "Consulta - João Silva",
  "start": "2026-01-03T14:00:00-03:00",
  "end": "2026-01-03T15:00:00-03:00",
  "description": "Paciente: João Silva\nTelefone: +5516999999999"
}
```

## ⚠️ Limites e Quotas

### Quotas Gratuitas do Google

- **Requests por dia**: 1.000.000
- **Requests por 100 segundos por usuário**: 100
- **Mais que suficiente** para uma clínica

### Monitoramento

1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Vá em **"APIs & Services"** → **"Dashboard"**
3. Veja uso da Google Calendar API

## 🔄 Migração do MCP

### Remover Dependência MCP

1. Remover variável `MCP_CALENDAR_ENDPOINT` do `.env`
2. Atualizar workflows para usar Google Calendar API direto
3. Substituir ferramentas MCP por workflows usando nó Google Calendar

### Workflows Criados

- ✅ `google-calendar-availability-tool.json` - Consultar disponibilidade
- ✅ `google-calendar-create-event-tool.json` - Criar eventos
- ⏳ `google-calendar-list-events-tool.json` - Listar eventos (a criar)
- ⏳ `google-calendar-delete-event-tool.json` - Deletar eventos (a criar)

## 🐛 Troubleshooting

### Erro: "Access denied"

- Verifique se o calendário está compartilhado com a conta OAuth
- Verifique permissões do calendário

### Erro: "Calendar not found"

- Verifique se o Calendar ID está correto
- Use formato completo: `email@group.calendar.google.com`

### Erro: "Quota exceeded"

- Muito raro, mas verifique uso no Google Cloud Console
- Aguarde alguns minutos e tente novamente

## 📚 Referências

- [Google Calendar API Documentation](https://developers.google.com/calendar/api/v3/reference)
- [n8n Google Calendar Node](https://docs.n8n.io/integrations/builtin/app-nodes/n8n-nodes-base.googlecalendar/)
- [OAuth 2.0 Setup](https://developers.google.com/identity/protocols/oauth2)

---
*Última atualização: 2026-01-03*
