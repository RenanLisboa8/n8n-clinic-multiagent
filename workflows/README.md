# Workflows - Sistema Multi-Profissional e Multi-Serviço

**Versão**: 3.0 - Refatorado com base no Material Secretária v3

Este diretório contém os workflows do sistema de agendamento multi-tenant, suportando múltiplos profissionais e múltiplos serviços por clínica.

## 🆕 Melhorias da Versão 3.0

- ✅ **Documentação Aprimorada**: Sticky notes informativas em todos os workflows
- ✅ **Notas Detalhadas**: Cada node possui notas explicativas sobre sua função
- ✅ **Estrutura Organizada**: Melhor organização seguindo padrões do Material Secretária v3
- ✅ **Manutenção Facilitada**: Documentação inline facilita manutenção futura
- ✅ **Funcionalidades Preservadas**: Todas as funcionalidades multi-tenant e multi-profissional mantidas

## 📁 Estrutura de Diretórios

```
workflows/
├── main/              # Workflows principais (orquestradores)
├── sub/               # Sub-workflows (utilidades reutilizáveis)
└── tools/             # Ferramentas para agentes de IA (LangChain tools)
```

## 🎯 Workflows Principais (`main/`)

### 01 - WhatsApp Patient Handler (AI Optimized)
**Arquivo**: `main/01-whatsapp-patient-handler-optimized.json`

**Função**: Gerencia atendimento de pacientes via WhatsApp com suporte completo a multi-profissional e multi-serviço.

**Funcionalidades**:
- ✅ Recebe mensagens do WhatsApp via webhook
- ✅ Carrega configuração do tenant automaticamente
- ✅ Cache de FAQs para reduzir chamadas de IA (~75% de redução)
- ✅ Processamento inteligente de mensagens (texto, áudio, imagem)
- ✅ Agendamento com seleção de profissional e serviço
- ✅ Suporte a múltiplos profissionais para o mesmo serviço
- ✅ Uso automático do `calendar_id` correto de cada profissional
- ✅ Consideração da duração específica de cada serviço por profissional

**Fluxo de Agendamento Multi-Profissional**:
1. Cliente escolhe serviço → `FindProfessionals` busca profissionais
2. Se múltiplos profissionais → Apresenta opções numeradas
3. Cliente escolhe profissional → Usa `calendar_id` específico
4. Consulta disponibilidade → `CheckCalendarAvailability` com `duration_minutes` correto
5. Apresenta 10 horários disponíveis → Cliente escolhe
6. Cria evento → `CreateCalendarEvent` no `calendar_id` do profissional escolhido

**Ferramentas Utilizadas**:
- `FindProfessionals` - Busca profissionais por serviço
- `CheckCalendarAvailability` - Consulta horários disponíveis (usa calendar_id do profissional)
- `CreateCalendarEvent` - Cria agendamento (usa calendar_id do profissional)
- `CallToHuman` - Escalação para atendimento humano

---

### 02 - Telegram Internal Assistant (Multi-Tenant)
**Arquivo**: `main/02-telegram-internal-assistant-multitenant.json`

**Função**: Assistente interno para equipe via Telegram, permitindo reagendamentos e consultas de agenda.

**Funcionalidades**:
- ✅ Identifica tenant por chat ID do Telegram
- ✅ Permite reagendamentos via Telegram
- ✅ Consulta agenda de profissionais
- ✅ Notifica pacientes via WhatsApp após reagendamento

**Suporte Multi-Profissional**:
- Consulta agenda de qualquer profissional da clínica
- Identifica profissional pelo nome na mensagem
- Usa `calendar_id` correto para cada operação

---

### 03 - Appointment Confirmation Scheduler
**Arquivo**: `main/03-appointment-confirmation-scheduler.json`

**Função**: Envia lembretes de confirmação para agendamentos do dia seguinte.

**Funcionalidades**:
- ✅ Executa diariamente às 8h (seg-sex)
- ✅ **Suporte completo a múltiplos profissionais**
- ✅ Busca agendamentos de todos os calendários de profissionais
- ✅ Extrai informações do paciente (nome, telefone) da descrição do evento
- ✅ Envia mensagem de confirmação personalizada com nome do profissional

**Fluxo Multi-Profissional**:
1. Busca todos os profissionais ativos no banco
2. Para cada profissional:
   - Busca agendamentos do calendário dele
   - Extrai informações do paciente
   - Envia confirmação com nome do profissional

**Características**:
- Processa todos os tenants automaticamente
- Respeita timezone de cada clínica
- Inclui nome do profissional na mensagem de confirmação

---

### 04 - Error Handler
**Arquivo**: `main/04-error-handler.json`

**Função**: Captura e registra erros de todos os workflows.

**Funcionalidades**:
- ✅ Log de erros estruturado
- ✅ Notificação via Telegram em caso de falhas críticas
- ✅ Contexto completo do erro (tenant, workflow, dados)

---

## 🔧 Sub-Workflows (`sub/`)

### Tenant Config Loader
**Arquivo**: `sub/tenant-config-loader.json`

**Função**: Carrega configuração do tenant baseado no `instance_name` do webhook.

**Entrada**: Webhook payload com `body.instance` ou `instance_name`

**Saída**:
- `tenant_config` - Configuração completa do tenant
- `tenant_id` - UUID do tenant
- `services_catalog` - Catálogo formatado de serviços

**Uso**: Chamado automaticamente pelo workflow principal antes de processar mensagens.

---

## 🛠️ Ferramentas para IA (`tools/`)

Ferramentas utilizadas pelos agentes de LangChain para executar ações.

### 📅 Calendário (`tools/calendar/`)

#### Google Calendar Availability Tool
**Função**: Consulta horários disponíveis em um calendário específico.

**Entradas**:
- `calendar_id` (obrigatório) - ID do calendário do Google Calendar
- `start_time` (obrigatório) - Data/hora inicial (ISO 8601)
- `end_time` (obrigatório) - Data/hora final (ISO 8601)
- `duration_minutes` (obrigatório) - Duração do procedimento em minutos

**Saídas**:
- `available_slots` (array) - Até 10 opções de horários disponíveis
- Cada slot contém: `start`, `end`, `start_formatted`, `date_formatted`, `duration_minutes`

**Características**:
- Considera duração do procedimento ao buscar slots
- Respeita horário de funcionamento (06:00 - 20:00)
- Retorna apenas slots que têm tempo suficiente
- Formata datas em português brasileiro

#### Google Calendar Create Event Tool
**Função**: Cria evento no calendário do profissional.

**Entradas**:
- `calendar_id` (obrigatório) - **DEVE ser o calendar_id do profissional escolhido**
- `summary` (obrigatório) - Título do evento
- `start` (obrigatório) - Data/hora de início (ISO 8601)
- `end` (obrigatório) - Data/hora de fim (ISO 8601)
- `description` (opcional) - Descrição com dados do paciente

**Saídas**:
- `event_id` - ID do evento criado
- `event_link` - Link HTML para o evento
- `calendar_id` - ID do calendário usado

**IMPORTANTE**: 
- Sempre use o `calendar_id` retornado por `FindProfessionals`
- Nunca use um `calendar_id` genérico ou de outro profissional

---

### 🔍 Serviços (`tools/service/`)

#### Find Professionals Tool
**Função**: Busca profissionais que oferecem um serviço específico.

**Entradas**:
- `tenant_id` (obrigatório) - UUID do tenant
- `service_name` (obrigatório) - Nome ou código do serviço

**Saídas**:
- `professionals` (array) - Lista de profissionais encontrados
- Cada profissional contém:
  - `professional_id` - UUID do profissional
  - `professional_name` - Nome do profissional
  - `specialty` - Especialidade
  - `google_calendar_id` - **ID do calendário deste profissional** (CRÍTICO)
  - `services` - Array com serviços oferecidos
    - `service_id`, `service_name`, `service_code`
    - `duration_minutes` - **Duração específica deste profissional para este serviço**
    - `price_cents`, `price_display`

**Características**:
- Busca por correspondência de palavras-chave
- Retorna profissionais ordenados por relevância
- Cada profissional pode ter preços e durações diferentes para o mesmo serviço
- **CRÍTICO**: `google_calendar_id` e `duration_minutes` são específicos do profissional

**Exemplo de Uso**:
```
Input: { tenant_id: "uuid", service_name: "implante" }
Output: {
  success: true,
  count: 2,
  professionals: [
    {
      professional_name: "Dr. José Silva",
      google_calendar_id: "dr-jose-calendar@group.calendar.google.com",
      services: [{
        service_name: "Implante Dentário",
        duration_minutes: 120,  // 2 horas para Dr. José
        price_display: "R$ 5.000,00"
      }]
    },
    {
      professional_name: "Dra. Maria Costa",
      google_calendar_id: "dra-maria-calendar@group.calendar.google.com",
      services: [{
        service_name: "Implante Dentário",
        duration_minutes: 90,  // 1.5 horas para Dra. Maria
        price_display: "R$ 4.500,00"
      }]
    }
  ]
}
```

---

## 🔄 Fluxo de Agendamento Completo

### 1. Cliente Escolhe Serviço
```
Cliente: "Quero agendar um implante"
→ AI chama FindProfessionals(service_name: "implante")
```

### 2. Sistema Encontra Profissionais
```
FindProfessionals retorna:
- Dr. José (2h, R$ 5.000)
- Dra. Maria (1.5h, R$ 4.500)
```

### 3. Apresenta Opções ao Cliente
```
AI: "Temos 2 opções:
1. Dr. José - R$ 5.000,00 (duração: 2h)
2. Dra. Maria - R$ 4.500,00 (duração: 1h30min)

Qual você prefere?"
```

### 4. Cliente Escolhe Profissional
```
Cliente: "1" (Dr. José)
→ AI usa calendar_id: "dr-jose-calendar@group.calendar.google.com"
→ AI usa duration_minutes: 120
```

### 5. Consulta Disponibilidade
```
AI chama CheckCalendarAvailability(
  calendar_id: "dr-jose-calendar@group.calendar.google.com",
  duration_minutes: 120,
  start_time: agora,
  end_time: 7 dias no futuro
)
```

### 6. Apresenta Horários
```
AI: "Horários disponíveis para Implante Dentário com Dr. José:
1. Segunda-feira, 13 de janeiro de 2025 às 08:00 (duração: 120min)
2. Terça-feira, 14 de janeiro de 2025 às 10:00 (duração: 120min)
...
Qual horário você prefere?"
```

### 7. Cliente Escolhe Horário
```
Cliente: "1"
→ AI chama CreateCalendarEvent(
  calendar_id: "dr-jose-calendar@group.calendar.google.com",
  start: "2025-01-13T08:00:00-03:00",
  end: "2025-01-13T10:00:00-03:00",  // start + 120min
  description: "Nome: João Silva\nData Nasc: 01/01/1990\nTel: 5516999999999\nServiço: Implante Dentário"
)
```

### 8. Confirmação
```
AI: "Agendamento confirmado com Dr. José!
📅 Segunda-feira, 13 de janeiro às 08:00
⏱️ Duração: 2 horas
💰 Valor: R$ 5.000,00"
```

---

## ⚙️ Configuração

### Credenciais Necessárias

1. **PostgreSQL** (`POSTGRES_CREDENTIAL_ID`)
   - Acesso ao banco de dados para carregar tenants, profissionais, serviços

2. **Google Calendar OAuth2** (`GOOGLE_CALENDAR_CREDENTIAL_ID`)
   - Acesso aos calendários dos profissionais

3. **Evolution API** (`EVOLUTION_API_CREDENTIAL_ID`)
   - Envio de mensagens WhatsApp

4. **Google Gemini API** (`GOOGLE_GEMINI_CREDENTIAL_ID`)
   - Processamento de IA

### Variáveis de Ambiente

Nenhuma variável de ambiente obrigatória - tudo é carregado do banco de dados por tenant.

**Opcionais** (para compatibilidade com workflows antigos):
- `EVOLUTION_INSTANCE_NAME` - Instância padrão
- `CLINIC_NAME` - Nome da clínica
- `CLINIC_ADDRESS` - Endereço da clínica

---

## 🔐 Segurança e Multi-Tenancy

### Isolamento por Tenant
- Cada tenant tem seus próprios profissionais e serviços
- Configurações (prompts, modelos, limites) são isoladas por tenant
- Calendários são isolados por profissional (cada profissional tem seu próprio)

### Validações
- `FindProfessionals` valida que `tenant_id` é um UUID válido
- `CheckCalendarAvailability` valida que `calendar_id` existe
- `CreateCalendarEvent` valida que `calendar_id` pertence ao profissional correto

---

## 📊 Performance e Otimizações

### Cache de FAQs
- ~75% de redução em chamadas de IA
- Respostas instantâneas para perguntas frequentes
- Aprendizado automático (FAQ cache se atualiza com interações)

### Redução de Tokens
- Catálogo de serviços carregado dinamicamente
- Memória de chat reduzida (5 mensagens vs 10)
- Formatação de mensagens sem IA (código puro)

### Rate Limiting
- Espera de 2 segundos entre confirmações de agendamento
- Modelo `gemini-2.0-flash-lite` para maior limite de quota

---

## 🐛 Troubleshooting

### Erro: "Nenhum profissional encontrado"
**Causa**: Serviço não cadastrado ou nenhum profissional oferece este serviço.

**Solução**:
1. Verificar se serviço existe em `services_catalog`
2. Verificar se há profissionais cadastrados em `professionals`
3. Verificar se há ligação em `professional_services`

### Erro: "calendar_id inválido"
**Causa**: `calendar_id` não corresponde a nenhum profissional.

**Solução**:
1. Verificar se `FindProfessionals` retornou `google_calendar_id` correto
2. Verificar se profissional está ativo (`is_active = true`)
3. Verificar se `calendar_id` está correto na tabela `professionals`

### Erro: "Horários não disponíveis"
**Causa**: Calendário do profissional está cheio ou horário de funcionamento não permite.

**Solução**:
1. Verificar horários de funcionamento do profissional
2. Verificar se há períodos livres no calendário
3. Verificar se `duration_minutes` não é muito grande para os slots disponíveis

---

## 📝 Notas Importantes

1. **SEMPRE use o `calendar_id` retornado por `FindProfessionals`**
   - Nunca use um `calendar_id` hardcoded
   - Cada profissional tem seu próprio calendário
   - O sistema é multi-profissional por design

2. **SEMPRE use o `duration_minutes` retornado por `FindProfessionals`**
   - Duração pode variar entre profissionais
   - Mesmo serviço pode ter durações diferentes
   - É usado para calcular slots disponíveis corretamente

3. **Confirmações de agendamento são multi-profissional**
   - O workflow de confirmação busca todos os profissionais
   - Processa cada calendário separadamente
   - Inclui nome do profissional na mensagem

4. **Catálogo de serviços é dinâmico**
   - Carregado do banco por tenant
   - Atualizado automaticamente quando profissionais/serviços mudam
   - Inclui preços e durações específicas de cada profissional

---

**Última Atualização**: 2026-01-10  
**Versão**: 3.0 - Refatorado com base no Material Secretária v3  
**Autor**: Sistema de Clínica Multi-Agent

## 📝 Notas de Refatoração

Esta versão foi refatorada aplicando melhorias do Material Secretária v3, mantendo toda a arquitetura multi-tenant e multi-profissional existente:

### Melhorias Aplicadas
1. **Documentação**: Sticky notes informativas em todos os workflows principais
2. **Notas de Nodes**: Cada node possui notas explicativas detalhadas
3. **Estrutura**: Melhor organização seguindo padrões estabelecidos
4. **Manutenibilidade**: Documentação inline facilita manutenção e onboarding

### Funcionalidades Preservadas
- ✅ Arquitetura multi-tenant completa
- ✅ Suporte a múltiplos profissionais e serviços
- ✅ Cache de FAQs (~75% redução em chamadas de IA)
- ✅ Otimizações de performance
- ✅ Sistema de agendamento completo
- ✅ Tratamento de erros robusto
