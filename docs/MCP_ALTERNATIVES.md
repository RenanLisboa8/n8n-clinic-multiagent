# Alternativas ao MCP Calendar

## ❌ Problema: MCP Calendar não é gratuito

O MCP Calendar **não é um serviço público e gratuito**. As opções disponíveis são:

1. **Serviços pagos** (ex: RShare.io, Práxis Agênc.IA) - A partir de R$ 199/mês
2. **Criar seu próprio servidor MCP** - Requer desenvolvimento e hospedagem
3. **Usar Google Calendar API diretamente** - ✅ **GRATUITO e RECOMENDADO**

## ✅ Solução Recomendada: Google Calendar API Direto

Em vez de usar MCP, podemos usar **diretamente a Google Calendar API** através de nós n8n, que é:
- ✅ **100% Gratuito** (dentro dos limites da API do Google)
- ✅ **Sem dependência de serviços externos**
- ✅ **Suporta múltiplos calendários** nativamente
- ✅ **Mais controle e flexibilidade**

## 🔧 Implementação: Google Calendar API Direto

### Opção 1: Nó Google Calendar do n8n (Recomendado)

O n8n tem um nó nativo `Google Calendar` que se conecta diretamente à API do Google.

**Vantagens**:
- Integração nativa
- Suporte a múltiplos calendários
- Operações: criar, listar, atualizar, deletar eventos
- Consulta de disponibilidade

**Configuração necessária**:
1. Criar credenciais OAuth 2.0 no Google Cloud Console
2. Configurar no n8n como credencial
3. Usar o nó `Google Calendar` nos workflows

### Opção 2: HTTP Request para Google Calendar API

Usar nó `HTTP Request` para chamar diretamente a API REST do Google Calendar.

**Endpoint base**: `https://www.googleapis.com/calendar/v3`

**Operações principais**:
- `GET /calendars/{calendarId}/events` - Listar eventos
- `POST /calendars/{calendarId}/events` - Criar evento
- `GET /calendars/{calendarId}/freebusy` - Consultar disponibilidade
- `DELETE /calendars/{calendarId}/events/{eventId}` - Deletar evento

## 📋 Comparação: MCP vs Google Calendar API Direto

| Aspecto | MCP Calendar | Google Calendar API Direto |
|---------|-------------|---------------------------|
| **Custo** | Pago (R$ 199+/mês) | Gratuito |
| **Dependência** | Serviço externo | Nenhuma |
| **Múltiplos Calendários** | Depende do serviço | ✅ Nativo |
| **Controle** | Limitado | ✅ Total |
| **Manutenção** | Terceiros | Você |
| **Limites** | Do provedor | Google (muito generoso) |

## 🚀 Próximos Passos

### 1. Criar Credenciais Google

1. Acesse [Google Cloud Console](https://console.cloud.google.com/)
2. Crie um projeto (ou use existente)
3. Habilite **Google Calendar API**
4. Crie credenciais **OAuth 2.0 Client ID**
5. Configure redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`

### 2. Configurar no n8n

1. Vá em **Credentials** → **Add Credential**
2. Selecione **Google Calendar OAuth2 API**
3. Cole Client ID e Client Secret
4. Autorize o acesso

### 3. Criar Ferramentas de Calendário

Substituir o MCP Calendar Tool por workflows que usam o nó Google Calendar diretamente.

## 📝 Workflows Necessários

### 1. Check Availability Tool
- **Input**: `calendar_id`, `start_time`, `end_time`
- **Usa**: Nó Google Calendar → Freebusy Query
- **Retorna**: Horários disponíveis

### 2. Create Calendar Event Tool
- **Input**: `calendar_id`, `start`, `end`, `summary`, `description`
- **Usa**: Nó Google Calendar → Create Event
- **Retorna**: Event ID criado

### 3. List Calendar Events Tool
- **Input**: `calendar_id`, `timeMin`, `timeMax`
- **Usa**: Nó Google Calendar → List Events
- **Retorna**: Lista de eventos

### 4. Delete Calendar Event Tool
- **Input**: `calendar_id`, `event_id`
- **Usa**: Nó Google Calendar → Delete Event
- **Retorna**: Confirmação

## ⚠️ Limites da Google Calendar API

- **Quota gratuita**: 1.000.000 requests/dia
- **Rate limit**: 100 requests/100 segundos por usuário
- **Mais que suficiente** para uma clínica

## 🔄 Migração do MCP para Google Calendar API

1. ✅ Remover dependência de `MCP_CALENDAR_ENDPOINT`
2. ✅ Criar workflows de ferramentas usando Google Calendar API
3. ✅ Atualizar agente para usar novas ferramentas
4. ✅ Testar fluxo completo

---
*Última atualização: 2026-01-03*
