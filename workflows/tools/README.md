# Ferramentas de Workflow

Este diretório contém workflows de ferramentas reutilizáveis que podem ser chamados dos workflows principais.

## Categorias de Ferramentas

### 📞 Ferramentas de Comunicação (`communication/`)

#### `whatsapp-send-tool.json`
Enviar mensagens WhatsApp via Evolution API.

**Entradas:**
- `instance_name` (string, opcional): Nome da instância da Evolution API (padrão para variável de ambiente)
- `remote_jid` (string, obrigatório): Número de telefone no formato `5511999999999@s.whatsapp.net`
- `message_text` (string, obrigatório): Conteúdo da mensagem

**Saídas:**
- `success` (boolean): Se a mensagem foi enviada
- `message_id` (string): ID da mensagem WhatsApp
- `status` (string): "sent"
- `timestamp` (string): Timestamp ISO 8601

**Exemplo de Uso:**
```json
{
  "remote_jid": "5511999999999@s.whatsapp.net",
  "message_text": "Sua consulta foi confirmada!"
}
```

---

#### `message-formatter-tool.json`
Formatar mensagens para compatibilidade com markdown do WhatsApp.

**Entradas:**
- `raw_text` (string, obrigatório): Texto não formatado do agente de IA

**Saídas:**
- `formatted_text` (string): Markdown compatível com WhatsApp

**Transformações:**
- `**negrito**` → `*negrito*`
- `# Cabeçalho` → `Cabeçalho`
- Preserva quebras de linha e emojis

---

#### `telegram-notify-tool.json`
Enviar notificações para equipe via Telegram.

**Entradas:**
- `chat_id` (string, obrigatório): ID do chat Telegram
- `message` (string, obrigatório): Mensagem de notificação
- `notification_type` (string, opcional): "info", "warning" ou "error"

**Saídas:**
- `success` (boolean): Se a notificação foi enviada
- `message_id` (string): ID da mensagem Telegram

---

### 🤖 Ferramentas de Processamento de IA (`ai-processing/`)

#### `image-ocr-tool.json`
Extrair texto de imagens usando Google Gemini Vision.

**Entradas:**
- `image_url` (string, obrigatório): URL pública da imagem

**Saídas:**
- `transcribed_text` (string): Conteúdo de texto extraído
- `image_description` (string): Descrição do contexto da imagem
- `success` (boolean): Status do processamento
- `timestamp` (string): Tempo de processamento

**Casos de Uso:**
- Receitas médicas
- Resultados de exames
- Notas manuscritas
- Documentos de identificação

---

#### `audio-transcription-tool.json`
Transcrever mensagens de áudio usando Google Gemini Audio.

**Entradas:**
- `instance_name` (string, opcional): Instância da Evolution API
- `message_id` (string, obrigatório): ID da mensagem de áudio

**Saídas:**
- `transcribed_text` (string): Transcrição do áudio
- `success` (boolean): Status do processamento
- `timestamp` (string): Tempo de processamento

**Fluxo:**
1. Baixar áudio da Evolution API
2. Converter base64 para binário
3. Transcrever com Gemini Audio
4. Retornar texto

---

### 📅 Ferramentas de Calendário (`calendar/`)

#### `mcp-calendar-tool.json`
Interface unificada do Google Calendar via protocolo MCP.

**Ações:**
- `get_all`: Listar eventos em intervalo de datas
- `get_availability`: Verificar horários disponíveis
- `create`: Criar novo evento
- `update`: Atualizar evento existente
- `delete`: Deletar evento
- `get`: Obter detalhes de evento único

**Entradas (variam por ação):**
- `action` (string, obrigatório): Ação a realizar
- `date_start`, `date_end` (datetime): Para get_all, get_availability
- `event_id` (string): Para update, delete, get
- `title`, `description` (string): Para create, update

**Saídas:**
- Dados do evento ou mensagem de confirmação

---

### 🚨 Ferramentas de Escalonamento (`escalation/`)

#### `call-to-human-tool.json`
Escalonar conversa para operador humano.

**Entradas:**
- `patient_name` (string, obrigatório): Nome do paciente
- `phone_number` (string, obrigatório): Número WhatsApp do paciente
- `last_message` (string, obrigatório): Mensagem mais recente
- `reason` (string, obrigatório): Motivo do escalonamento

**Gatilhos de Escalonamento:**
- Palavras-chave de urgência médica
- Insatisfação do paciente
- Solicitação para falar com humano
- Tópicos fora do escopo

**Saídas:**
- Notificação enviada à equipe via Telegram
- Mensagem de confirmação ao paciente

---

## Diretrizes para Desenvolvimento de Ferramentas

### Criando uma Nova Ferramenta

1. **Definir Interface Clara**
   - Documentar entradas obrigatórias
   - Definir saídas esperadas
   - Especificar casos de erro

2. **Usar Gatilho Execute Workflow**
   ```json
   {
     "parameters": {},
     "type": "n8n-nodes-base.executeWorkflowTrigger"
   }
   ```

3. **Adicionar Tratamento de Erros**
   - Nós Try/Catch para APIs externas
   - Valores padrão para entradas opcionais
   - Mensagens de erro claras

4. **Seguir Convenção de Nomenclatura**
   - `[funcao]-tool.json`
   - Minúsculas com hífens
   - Nome descritivo

5. **Adicionar Documentação**
   - Atualizar este README
   - Adicionar comentários inline no workflow
   - Incluir exemplos de uso

### Testando Ferramentas

Testar cada ferramenta individualmente:

```bash
# Na interface do n8n:
1. Abrir workflow da ferramenta
2. Clicar no botão "Executar Workflow"
3. Fornecer entradas de teste
4. Verificar se saídas correspondem ao formato esperado
```

### Melhores Práticas para Ferramentas

✅ **FAZER:**
- Manter ferramentas focadas (responsabilidade única)
- Usar variáveis de ambiente para configuração
- Retornar formato de saída consistente
- Adicionar lógica de retry para APIs externas
- Registrar eventos importantes

❌ **NÃO FAZER:**
- Misturar múltiplas responsabilidades em uma ferramenta
- Hardcodar credenciais ou dados sensíveis
- Pular tratamento de erros
- Criar dependências circulares de ferramentas
- Esquecer de documentar mudanças

---

## Dependências de Ferramentas

### Credenciais Necessárias

Ferramentas usam estas credenciais do n8n:
- **Evolution API**: Para operações WhatsApp
- **Google Gemini API**: Para processamento de IA
- **Bot Telegram**: Para notificações
- **Google Calendar OAuth2**: Para operações de calendário
- **PostgreSQL**: Para memória de chat (workflows principais)

### Variáveis de Ambiente

Ferramentas referenciam estas variáveis de ambiente:
- `EVOLUTION_INSTANCE_NAME`: Instância WhatsApp padrão
- `TELEGRAM_INTERNAL_CHAT_ID`: Alvo de notificação da equipe
- `MCP_CALENDAR_ENDPOINT`: Endpoint da API de calendário
- `CLINIC_NAME`, `CLINIC_ADDRESS`: Informações do negócio

---

## Ordem de Importação de Ferramentas

Ao importar ferramentas, siga esta ordem para satisfazer dependências:

1. **Ferramentas de Comunicação** (sem dependências)
   - message-formatter-tool.json
   - whatsapp-send-tool.json
   - telegram-notify-tool.json

2. **Ferramentas de Calendário** (sem dependências)
   - mcp-calendar-tool.json

3. **Ferramentas de Processamento de IA** (depende de comunicação)
   - image-ocr-tool.json
   - audio-transcription-tool.json

4. **Ferramentas de Escalonamento** (depende de comunicação)
   - call-to-human-tool.json

---

## Solução de Problemas

### Erro de Ferramenta Não Encontrada

**Problema:** Workflow principal não consegue encontrar workflow da ferramenta

**Solução:**
1. Verificar se workflow da ferramenta está salvo e ativo
2. Verificar se ID do workflow da ferramenta corresponde no workflow principal
3. Garantir que ferramenta tem nó "Execute Workflow Trigger"

### Erros de Credencial

**Problema:** Ferramenta falha com erro de autenticação

**Solução:**
1. Atualizar IDs de credencial no JSON da ferramenta
2. Verificar se credenciais são válidas nas configurações do n8n
3. Verificar permissões de credencial

### Erros de Timeout

**Problema:** Execução da ferramenta expira

**Solução:**
1. Aumentar timeout nas configurações da ferramenta
2. Adicionar lógica de retry para chamadas de API externa
3. Verificar saúde do serviço externo

---

## Contribuindo

Ao adicionar novas ferramentas:

1. Seguir a estrutura de ferramentas existentes
2. Atualizar este README com documentação da ferramenta
3. Adicionar tags: `tool` e categoria (`communication`, `ai-processing`, etc.)
4. Testar minuciosamente antes de commitar
5. Atualizar REFACTORING_GUIDE.md se aplicável

---

**Última Atualização:** 2026-01-01  
**Versão:** 1.0
