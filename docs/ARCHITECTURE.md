# Sistema Multi-Agente n8n para Clínicas - Arquitetura de Workflows

## Visão Geral
Este documento descreve a arquitetura modular de workflows para o Sistema Multi-Agente n8n para Clínicas, refatorado de um design monolítico para uma estrutura sustentável e escalável seguindo o Princípio da Responsabilidade Única.

---

## Princípios Arquiteturais

### 1. **Separação de Responsabilidades**
- **Workflows Principais**: Lidam com orquestração, roteamento e lógica de alto nível
- **Workflows de Ferramentas**: Implementam funcionalidades específicas e reutilizáveis
- **Especialização de Agentes**: Cada agente tem uma responsabilidade clara e definida

### 2. **Reutilização**
- Ferramentas são autocontidas e podem ser chamadas de múltiplos workflows
- Operações comuns (formatação, tratamento de erros) são centralizadas

### 3. **Manutenibilidade**
- Cada arquivo de workflow foca em um único domínio
- Fácil localizar e corrigir bugs
- Mudanças em uma área não afetam outras

---

## Estrutura de Workflows Proposta

```
workflows/
├── main/
│   ├── 01-whatsapp-patient-handler.json          # Fluxo principal de interação com paciente
│   ├── 02-telegram-internal-assistant.json       # Assistente interno da equipe
│   └── 03-appointment-confirmation-scheduler.json # Automação de confirmação diária
│
└── tools/
    ├── calendar/
    │   ├── mcp-calendar-tool.json                # Operações do Google Calendar
    │   └── appointment-reminder-tool.json         # Enviar lembretes de consulta
    │
    ├── communication/
    │   ├── whatsapp-send-tool.json               # Envio WhatsApp via Evolution API
    │   ├── telegram-notify-tool.json             # Notificações Telegram
    │   └── message-formatter-tool.json           # Formatar mensagens para WhatsApp
    │
    ├── ai-processing/
    │   ├── image-ocr-tool.json                   # Processar imagens com OCR
    │   ├── audio-transcription-tool.json         # Transcrever mensagens de áudio
    │   └── text-analysis-tool.json               # Analisar e interpretar texto
    │
    └── escalation/
        └── call-to-human-tool.json               # Escalonar para operador humano
```

---

## Descrições dos Workflows

### **Workflows Principais**

#### 1. `01-whatsapp-patient-handler.json`
**Propósito**: Lidar com todas as mensagens WhatsApp recebidas de pacientes

**Responsabilidades**:
- Receber webhook da Evolution API
- Analisar tipo de mensagem (texto, imagem, áudio, documento)
- Rotear para ferramenta de processamento apropriada
- Interagir com assistente de IA para respostas
- Enviar respostas formatadas de volta via WhatsApp

**Nós Principais**:
- Gatilho Webhook (Evolution API)
- Switch de Tipo de Mensagem
- Agente Assistente de Paciente
- Ferramentas: OCR de Imagem, Transcrição de Áudio, Calendário, Escalonamento

**Agente**: `Assistente Clínica` (Assistente voltado para pacientes)
- Lida com agendamentos, reagendamentos, cancelamentos
- Responde perguntas sobre clínica
- Escalona situações urgentes

---

#### 2. `02-telegram-internal-assistant.json`
**Propósito**: Ferramenta interna para equipe da clínica gerenciar operações via Telegram

**Responsabilidades**:
- Receber comandos da equipe via Telegram
- Gerenciar reagendamento de pacientes
- Adicionar itens à lista de compras da clínica (Google Tasks)
- Enviar notificações de reagendamento aos pacientes

**Nós Principais**:
- Gatilho Telegram
- Agente Assistente Interno
- Ferramentas: Calendário, Google Tasks, Envio WhatsApp

**Agente**: `Assistente Clínica Interno` (Assistente interno)
- Acessível apenas por equipe autorizada
- Realiza tarefas administrativas
- Coordena com workflows voltados para pacientes

---

#### 3. `03-appointment-confirmation-scheduler.json`
**Propósito**: Confirmação diária automatizada de consultas do dia seguinte

**Responsabilidades**:
- Disparar diariamente às 8h (Seg-Sex)
- Buscar consultas do dia seguinte do Google Calendar
- Extrair informações de contato do paciente
- Enviar solicitação de confirmação via WhatsApp
- Registrar status de confirmação

**Nós Principais**:
- Gatilho de Agendamento (Cron: 0 8 * * 1-5)
- Busca Google Calendar
- Loop através de consultas
- Agente Assistente de Confirmação
- Ferramentas: Calendário, Envio WhatsApp

**Agente**: `Assistente de Confirmação`
- Lista consultas próximas
- Envia solicitações de confirmação
- Não lida com respostas (tratadas pelo fluxo principal de paciente)

---

### **Workflows de Ferramentas**

#### **Ferramentas de Calendário**

##### `mcp-calendar-tool.json`
**Propósito**: Interface unificada para Google Calendar via MCP

**Entradas**:
- `action`: get_all, get_availability, create, update, delete
- `date_start`, `date_end`
- `event_id` (para update/delete)
- `description`, `title` (para create)

**Saídas**:
- Dados do evento ou mensagem de confirmação

---

##### `appointment-reminder-tool.json`
**Propósito**: Enviar lembrete de consulta via WhatsApp

**Entradas**:
- `phone_number`: Número WhatsApp do paciente
- `patient_name`
- `appointment_date`
- `appointment_time`

**Saídas**:
- Confirmação de envio de mensagem

---

#### **Ferramentas de Comunicação**

##### `whatsapp-send-tool.json`
**Propósito**: Enviar mensagem WhatsApp via Evolution API

**Entradas**:
- `instance_name`
- `remote_jid` (número de telefone)
- `message_text`

**Saídas**:
- Status de entrega

---

##### `telegram-notify-tool.json`
**Propósito**: Enviar notificação para equipe via Telegram

**Entradas**:
- `chat_id`
- `message`
- `notification_type` (info, warning, error)

**Saídas**:
- Confirmação de envio de mensagem

---

##### `message-formatter-tool.json`
**Propósito**: Formatar mensagens para markdown do WhatsApp

**Entradas**:
- `raw_text` (do agente de IA)

**Saídas**:
- `formatted_text` (** → *, remover #)

---

#### **Ferramentas de Processamento de IA**

##### `image-ocr-tool.json`
**Propósito**: Extrair texto de imagens usando Google Gemini Vision

**Entradas**:
- `image_url`

**Saídas**:
- `transcribed_text`
- `image_description`

**Casos de Uso**:
- Receitas médicas
- Resultados de exames
- Notas manuscritas

---

##### `audio-transcription-tool.json`
**Propósito**: Transcrever mensagens de áudio

**Entradas**:
- `audio_binary` (da Evolution API)

**Saídas**:
- `transcribed_text`

**Fluxo**:
1. Baixar áudio da Evolution API
2. Converter para binário
3. Transcrever com Google Gemini Audio
4. Retornar texto

---

##### `text-analysis-tool.json`
**Propósito**: Analisar e interpretar texto para contexto

**Entradas**:
- `text` (de OCR ou transcrição)

**Saídas**:
- `interpretation`
- `suggested_response`

---

#### **Ferramentas de Escalonamento**

##### `call-to-human-tool.json`
**Propósito**: Escalonar conversa para operador humano

**Entradas**:
- `patient_name`
- `phone_number`
- `last_message`
- `reason` (urgência, insatisfação, fora do escopo)

**Saídas**:
- Notificação enviada à equipe
- Paciente informado do escalonamento

**Gatilhos**:
- Palavras-chave de urgência médica
- Paciente solicita contato humano
- Insatisfação extrema detectada
- Tópicos fora do escopo

---

## Configuração de Agentes

### Variáveis de Ambiente nas Mensagens do Sistema
Todos os valores hardcoded devem ser substituídos por expressões referenciando variáveis de ambiente:

**Exemplos**:
```javascript
// Substituir números de telefone hardcoded
"5511111111111@s.whatsapp.net" 
→ 
"{{ $env.CLINIC_PHONE }}@s.whatsapp.net"

// Substituir links de calendário
"https://calendar.google.com/calendar/embed?src=..."
→
"{{ $env.CLINIC_CALENDAR_PUBLIC_LINK }}"

// Substituir horário comercial
"Seg–Sáb: 08h–19h"
→
"{{ $env.CLINIC_DAYS_OPEN }}: {{ $env.CLINIC_HOURS_START }}–{{ $env.CLINIC_HOURS_END }}"

// Substituir endereço da clínica
"Rua Rio Casca, 417 – Belo Horizonte, MG"
→
"{{ $env.CLINIC_ADDRESS }}"
```

---

## Exemplos de Fluxo de Dados

### Exemplo 1: Paciente Agenda Consulta via WhatsApp

```
1. Paciente → WhatsApp → Evolution API → Webhook n8n
2. Webhook → Analisar Mensagem → Switch (tipo texto)
3. Texto → Agente Assistente de Paciente
4. Agente usa Ferramenta Calendário MCP → Verificar disponibilidade
5. Paciente escolhe horário → Agente usa Ferramenta Calendário MCP → Criar evento
6. Agente → Ferramenta Formatador de Mensagem → Formatar resposta
7. Mensagem formatada → Ferramenta Envio WhatsApp → Paciente
```

---

### Exemplo 2: Equipe Reagenda Paciente via Telegram

```
1. Equipe → Telegram → Gatilho Telegram n8n
2. Agente Assistente Interno recebe comando
3. Agente usa Ferramenta Calendário MCP → Localizar consulta do paciente
4. Agente usa Ferramenta Calendário MCP → Atualizar evento
5. Agente usa Ferramenta Envio WhatsApp → Notificar paciente
6. Agente → Telegram → Confirmar para equipe
```

---

### Exemplo 3: Confirmações Diárias de Consultas

```
1. Gatilho Cron → 8h diariamente
2. Agente Assistente de Confirmação ativa
3. Agente usa Ferramenta Calendário MCP → Obter consultas de amanhã
4. Loop através de consultas:
   a. Extrair telefone do paciente da descrição
   b. Agente usa Ferramenta Envio WhatsApp → Enviar solicitação de confirmação
5. Completar e registrar resultados
```

---

## Benefícios da Arquitetura Modular

### 1. **Manutenibilidade**
- Cada workflow tem propósito claro
- Fácil localizar e corrigir bugs
- Mudanças em uma área não afetam outras

### 2. **Escalabilidade**
- Adicionar novas ferramentas sem modificar workflows principais
- Fácil estender funcionalidade
- Pode ser balanceado em carga ou distribuído

### 3. **Testabilidade**
- Ferramentas podem ser testadas independentemente
- Simular entradas/saídas para depuração
- Mais fácil validar comportamento

### 4. **Reutilização**
- Ferramenta de Envio WhatsApp usada por múltiplos workflows
- Operações de calendário centralizadas
- Comportamento consistente em todo o sistema

### 5. **Colaboração em Equipe**
- Múltiplos desenvolvedores podem trabalhar em ferramentas diferentes
- Interfaces claras entre componentes
- Revisões de código mais fáceis

---

## Estratégia de Migração

### Fase 1: Extrair Ferramentas
1. Criar workflows de ferramentas dos nós existentes
2. Testar cada ferramenta independentemente
3. Documentar entradas/saídas

### Fase 2: Refatorar Workflows Principais
1. Substituir lógica inline por chamadas de ferramentas
2. Simplificar estrutura de workflow principal
3. Adicionar tratamento de erros

### Fase 3: Parametrizar Configuração
1. Substituir valores hardcoded por variáveis de ambiente
2. Atualizar mensagens do sistema
3. Centralizar configuração

### Fase 4: Testes e Validação
1. Testes end-to-end de cada fluxo
2. Testes de performance
3. Testes de aceitação do usuário

---

## Próximos Passos

1. ✅ Arquitetura documentada
2. ⏳ Criar arquivos JSON de workflow de ferramentas
3. ⏳ Refatorar arquivos JSON de workflows principais
4. ⏳ Atualizar mensagens do sistema com variáveis de ambiente
5. ⏳ Testar e validar todos os fluxos

---

**Versão do Documento**: 1.0  
**Última Atualização**: 2026-01-01  
**Autor**: Equipe de Automação n8n
