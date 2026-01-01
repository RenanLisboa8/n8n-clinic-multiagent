# 🏥 Sistema Multi-Agente n8n para Clínicas

> **Sistema profissional de automação multi-agente para gestão de clínicas com WhatsApp, Telegram e assistentes com IA**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![n8n](https://img.shields.io/badge/n8n-latest-orange)](https://n8n.io)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue)](https://docs.docker.com/compose/)

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Funcionalidades](#funcionalidades)
- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Utilização](#utilização)
- [Agentes e Ferramentas](#agentes-e-ferramentas)
- [Workflows](#workflows)
- [Manutenção](#manutenção)
- [Resolução de Problemas](#resolução-de-problemas)
- [Segurança](#segurança)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

---

## 🎯 Visão Geral

O **Sistema Multi-Agente n8n para Clínicas** é uma plataforma de automação pronta para produção, projetada para clínicas de saúde. Oferece interação inteligente com pacientes através de IA pelo WhatsApp, gestão interna da equipe via Telegram e confirmações automáticas de consultas.

### Principais Capacidades

- 🤖 **Assistente de Pacientes com IA** - Gerencia agendamentos, reagendamentos e consultas sobre a clínica
- 📱 **Integração com WhatsApp** - Comunicação perfeita com pacientes via Evolution API
- 💬 **Bot Telegram Interno** - Ferramenta para equipe realizar tarefas administrativas
- 📅 **Integração com Google Calendar** - Gestão automatizada de agendas
- 🔔 **Confirmações Diárias de Consultas** - Engajamento proativo com pacientes
- 🎤 **Suporte Multimídia** - Processa texto, imagens (OCR) e áudio (transcrição)
- 🚨 **Escalonamento Inteligente** - Encaminha casos urgentes para operadores humanos
- 🧠 **Memória Contextual** - Mantém histórico de conversas por paciente

---

## ✨ Funcionalidades

### Funcionalidades para Pacientes
- ✅ Agendar consultas com linguagem natural
- ✅ Reagendar ou cancelar consultas existentes
- ✅ Verificar disponibilidade de horários
- ✅ Receber confirmações e lembretes de consultas
- ✅ Enviar imagens (receitas, exames) para análise
- ✅ Enviar mensagens de voz para transcrição
- ✅ Escalonamento automático para situações urgentes

### Funcionalidades para Equipe
- ✅ Gerenciar agenda de pacientes via Telegram
- ✅ Capacidade de reagendamento em massa
- ✅ Gestão de lista de compras (Google Tasks)
- ✅ Notificações de cancelamentos
- ✅ Alertas em tempo real para casos escalonados

### Funcionalidades Técnicas
- ✅ Arquitetura modular de workflows
- ✅ Configuração Docker pronta para produção
- ✅ Health checks e logging
- ✅ PostgreSQL com cache Redis
- ✅ Armazenamento criptografado de credenciais
- ✅ Configuração baseada em variáveis de ambiente
- ✅ Implantação containerizada

---

## 🏗️ Arquitetura

O sistema segue uma **arquitetura modular multi-agente** com clara separação de responsabilidades:

```
┌─────────────────────────────────────────────────────────────┐
│                   Interfaces Externas                        │
├──────────────┬──────────────┬──────────────┬────────────────┤
│   WhatsApp   │   Telegram   │    Google    │      IA/LLM    │
│  (Pacientes) │   (Equipe)   │   Calendar   │   (Gemini)     │
└──────┬───────┴──────┬───────┴──────┬───────┴────────┬───────┘
       │              │              │                │
┌──────▼──────────────▼──────────────▼────────────────▼───────┐
│                     Workflows n8n                            │
├──────────────────────────────────────────────────────────────┤
│  Workflows Principais:                                       │
│  • 01-whatsapp-patient-handler.json                          │
│  • 02-telegram-internal-assistant.json                       │
│  • 03-appointment-confirmation-scheduler.json                │
│                                                              │
│  Workflows de Ferramentas:                                   │
│  • Ferramentas de Calendário (integração MCP)                │
│  • Ferramentas de Comunicação (WhatsApp, Telegram)           │
│  • Processamento IA (OCR, Transcrição)                       │
│  • Ferramentas de Escalonamento (Repasse humano)             │
└──────┬───────────────────┬───────────────────┬──────────────┘
       │                   │                   │
┌──────▼───────┐  ┌────────▼────────┐  ┌──────▼──────────┐
│  PostgreSQL  │  │      Redis      │  │  Evolution API  │
│ (Banco Dados)│  │     (Cache)     │  │   (WhatsApp)    │
└──────────────┘  └─────────────────┘  └─────────────────┘
```

### Componentes Principais

| Componente | Tecnologia | Propósito |
|-----------|-----------|---------|
| **n8n** | Automação de Workflow | Orquestra toda a lógica de automação |
| **Evolution API** | Gateway WhatsApp | Gerencia comunicação via WhatsApp |
| **PostgreSQL** | Banco de Dados | Armazena workflows, execuções, histórico de chat |
| **Redis** | Cache | Melhora performance e gestão de sessões |
| **Google Gemini** | IA/LLM | Alimenta os agentes inteligentes |
| **Protocolo MCP** | Model Context Protocol | Integrações de calendário e email |

Para documentação detalhada da arquitetura, veja [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 📦 Pré-requisitos

### Obrigatório

- **Docker** (20.10+) e **Docker Compose** (v2.0+)
- **Conta Google** com:
  - API do Calendar habilitada
  - API do Tasks habilitada
  - Chave API do Gemini
- **Bot do Telegram** (crie via [@BotFather](https://t.me/botfather))
- **Instância Evolution API** ou configuração self-hosted

### Recomendado

- **Nome de domínio** com certificado SSL (para produção)
- **Especificações mínimas do servidor**:
  - 2 núcleos de CPU
  - 4GB RAM
  - 20GB armazenamento
  - Ubuntu 22.04 LTS ou similar

### Conhecimentos Necessários

- Docker e Docker Compose básico
- Familiaridade com variáveis de ambiente
- Entendimento de conceitos de webhook
- Conhecimento básico de workflows n8n

---

## 🚀 Instalação

### Passo 1: Clonar o Repositório

```bash
git clone https://github.com/seuusuario/n8n-clinic-multiagent.git
cd n8n-clinic-multiagent
```

### Passo 2: Configurar Variáveis de Ambiente

Copie o arquivo de exemplo e preencha seus valores:

```bash
cp env.example .env
```

**Crítico: Gere chaves seguras**

```bash
# Gere chave de criptografia para n8n
openssl rand -base64 32

# Gere segredo JWT
openssl rand -base64 32

# Gere senha do banco de dados
openssl rand -base64 32

# Gere senha do Redis
openssl rand -hex 32

# Gere chave API do Evolution
openssl rand -hex 32
```

Edite `.env` e preencha todos os campos `<REQUIRED>`. Veja a seção [Configuração](#configuração) para detalhes.

### Passo 3: Iniciar os Serviços

```bash
docker-compose up -d
```

Isso iniciará:
- PostgreSQL (porta 5432)
- Redis (porta 6379)
- Evolution API (porta 8080)
- n8n (porta 5678)

### Passo 4: Verificar Instalação

Verifique se todos os serviços estão saudáveis:

```bash
docker-compose ps
```

Todos os serviços devem mostrar status `healthy`.

### Passo 5: Acessar n8n

Abra seu navegador e navegue para:

```
http://localhost:5678
```

Crie sua conta de administrador do n8n no primeiro acesso.

### Passo 6: Importar Workflows

1. Na interface do n8n, vá em **Workflows** → **Import from File**
2. Importe workflows nesta ordem:
   - Workflows de ferramentas primeiro (de `workflows/tools/`)
   - Workflows principais depois (de `workflows/main/`)

### Passo 7: Configurar Credenciais

Configure as seguintes credenciais no n8n:

1. **Evolution API** - Adicione sua URL e chave da Evolution API
2. **Google Calendar OAuth2** - Conecte sua conta Google
3. **Google Tasks OAuth2** - Conecte sua conta Google
4. **Bot Telegram** - Adicione seu token do bot
5. **API Google Gemini** - Adicione sua chave API
6. **PostgreSQL** - Conexão é auto-configurada

### Passo 8: Ativar Workflows

Habilite os workflows principais:
- ✅ `01-whatsapp-patient-handler`
- ✅ `02-telegram-internal-assistant`
- ✅ `03-appointment-confirmation-scheduler`

---

## ⚙️ Configuração

### Variáveis de Ambiente Essenciais

#### Configuração do Banco de Dados

```env
POSTGRES_USER=n8n_clinic
POSTGRES_PASSWORD=<gere_senha_forte>
POSTGRES_DB=n8n_clinic_db
```

#### Configuração do n8n

```env
N8N_ENCRYPTION_KEY=<gere_com_openssl>
N8N_JWT_SECRET=<gere_com_openssl>
N8N_WEBHOOK_URL=https://seu-dominio.com/
```

#### Configuração da Evolution API

```env
EVOLUTION_BASE_URL=http://seu-dominio.com:8080
EVOLUTION_API_KEY=<gere_chave_api>
```

#### Serviços Google

```env
GOOGLE_CALENDAR_ID=seu-calendar-id@group.calendar.google.com
GOOGLE_GEMINI_API_KEY=<sua_chave_api_gemini>
```

Obtenha sua chave API do Gemini em: [Google AI Studio](https://makersuite.google.com/app/apikey)

#### Bot do Telegram

```env
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
TELEGRAM_INTERNAL_CHAT_ID=<seu_chat_id>
```

Obtenha seu chat ID enviando mensagem para [@userinfobot](https://t.me/userinfobot)

#### Informações da Clínica

```env
CLINIC_NAME=Nome da Sua Clínica
CLINIC_ADDRESS=Seu Endereço Completo
CLINIC_PHONE=+5511999999999
CLINIC_HOURS_START=08:00
CLINIC_HOURS_END=19:00
```

Para opções completas de configuração, veja `env.example`.

---

## 🎮 Utilização

### Para Pacientes (WhatsApp)

Os pacientes podem interagir naturalmente via WhatsApp:

**Agendar uma consulta:**
```
Paciente: "Oi, gostaria de agendar uma consulta"
Bot: "Olá! Ficarei feliz em ajudar. Poderia me informar seu nome completo?"
Paciente: "Maria Silva"
Bot: "Ótimo, Maria. Qual sua data de nascimento?"
...
```

**Reagendar:**
```
Paciente: "Preciso reagendar minha consulta"
Bot: "Sem problema! Deixe-me localizar sua consulta..."
```

**Verificar disponibilidade:**
```
Paciente: "Vocês têm horários disponíveis na próxima semana?"
Bot: "Deixe-me verificar a agenda para a próxima semana..."
```

### Para Equipe (Telegram)

A equipe pode gerenciar operações via Telegram:

**Reagendar um paciente:**
```
Equipe: "Reagendar João Silva de amanhã para segunda-feira que vem"
Bot: "Vou verificar a consulta do João e horários disponíveis..."
```

**Adicionar à lista de compras:**
```
Equipe: "Adicionar 5 caixas de luvas à lista de compras"
Bot: "Adicionado ao Google Tasks: 5 caixas de luvas"
```

### Confirmações de Consultas

O sistema envia automaticamente solicitações de confirmação diariamente às 8h para consultas do dia seguinte:

```
Bot: "Oi Maria! Você tem uma consulta amanhã às 10:00. 
Por favor, responda 'Confirmar' para confirmar ou 'Reagendar' para alterar."
```

---

## 🤖 Agentes e Ferramentas

### Agentes Principais

#### 1. **Assistente de Pacientes** (`Assistente Clínica`)
- **Função**: Assistente WhatsApp voltado para pacientes
- **Capacidades**:
  - Agendar/reagendar/cancelar consultas
  - Verificar disponibilidade
  - Responder perguntas sobre a clínica
  - Processar imagens e áudio
  - Escalonar situações urgentes
- **Memória**: Mantém contexto de conversação por paciente
- **Modelo de Linguagem**: Google Gemini 2.0 Flash

#### 2. **Assistente Interno** (`Assistente Clínica Interno`)
- **Função**: Bot Telegram voltado para equipe
- **Capacidades**:
  - Gerenciar agendas de pacientes
  - Enviar notificações de reagendamento
  - Gerenciar listas de compras
  - Tarefas administrativas
- **Memória**: Mantém contexto de conversação da equipe
- **Modelo de Linguagem**: Google Gemini 2.0 Flash

#### 3. **Assistente de Confirmação** (`Assistente de Confirmação`)
- **Função**: Confirmação automática de consultas
- **Capacidades**:
  - Buscar consultas do dia seguinte
  - Enviar solicitações de confirmação
  - Registrar status de confirmação
- **Gatilho**: Diariamente às 8h (Seg-Sex)
- **Modelo de Linguagem**: Google Gemini 2.0 Flash

### Workflows de Ferramentas

| Ferramenta | Propósito | Usado Por |
|------|---------|---------|
| **MCP Calendar** | Operações do Google Calendar | Todos os agentes |
| **WhatsApp Send** | Enviar mensagens WhatsApp | Todos os workflows |
| **Telegram Notify** | Enviar notificações Telegram | Assistente de pacientes |
| **Message Formatter** | Formatar para markdown WhatsApp | Todos os workflows |
| **Image OCR** | Extrair texto de imagens | Assistente de pacientes |
| **Audio Transcription** | Transcrever mensagens de voz | Assistente de pacientes |
| **Call to Human** | Escalonar para operador humano | Assistente de pacientes |

---

## 📂 Workflows

### Workflows Principais

#### `01-whatsapp-patient-handler.json`
**Gatilho**: Webhook da Evolution API  
**Propósito**: Gerenciar todas as interações WhatsApp com pacientes  
**Fluxo**: Receber → Analisar → Processar (texto/imagem/áudio) → Resposta do Agente → Formatar → Enviar

#### `02-telegram-internal-assistant.json`
**Gatilho**: Mensagem Telegram da equipe  
**Propósito**: Assistente interno da equipe  
**Fluxo**: Receber → Processar Agente → Executar Ferramentas → Responder

#### `03-appointment-confirmation-scheduler.json`
**Gatilho**: Agendamento Cron (diário 8h)  
**Propósito**: Enviar confirmações de consultas do dia seguinte  
**Fluxo**: Buscar Consultas → Loop → Extrair Contato → Enviar Confirmação

### Workflows de Ferramentas

Localizados em subdiretórios de `workflows/tools/`. Veja [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) para detalhes.

---

## 🔧 Manutenção

### Visualizar Logs

```bash
# Todos os serviços
docker-compose logs -f

# Serviço específico
docker-compose logs -f n8n
docker-compose logs -f evolution_api
docker-compose logs -f postgres
```

### Backup do Banco de Dados

```bash
# Backup manual
docker-compose exec postgres pg_dump -U n8n_clinic n8n_clinic_db > backup_$(date +%Y%m%d).sql

# Restaurar
docker-compose exec -T postgres psql -U n8n_clinic n8n_clinic_db < backup_20260101.sql
```

### Atualizar Serviços

```bash
# Baixar imagens mais recentes
docker-compose pull

# Reiniciar serviços
docker-compose up -d
```

### Limpar Dados Antigos

O n8n remove automaticamente dados de execução mais antigos que `N8N_DATA_MAX_AGE` (padrão: 7 dias).

### Health Checks

```bash
# Verificar saúde dos serviços
docker-compose ps

# Testar API do n8n
curl http://localhost:5678/healthz

# Testar Evolution API
curl http://localhost:8080/health
```

---

## 🐛 Resolução de Problemas

### Problemas Comuns

#### Serviços Não Iniciam

```bash
# Verificar logs
docker-compose logs

# Verificar arquivo .env
cat .env | grep REQUIRED

# Verificar conflitos de porta
sudo lsof -i :5678
sudo lsof -i :8080
```

#### Problemas de Conexão com Evolution API

1. Verificar configurações de DNS no docker-compose.yaml
2. Verificar se `EVOLUTION_API_KEY` corresponde em ambos serviços
3. Verificar regras de firewall

#### n8n Webhook Não Recebe Dados

1. Verificar se `N8N_WEBHOOK_URL` está publicamente acessível
2. Verificar configuração de webhook da Evolution API
3. Testar webhook manualmente com curl

#### Erros de Conexão com Banco de Dados

```bash
# Testar conexão PostgreSQL
docker-compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT 1;"

# Verificar credenciais
echo $POSTGRES_PASSWORD
```

#### Agente Não Responde

1. Verificar se o workflow está ativo
2. Verificar se a chave API do Google Gemini é válida
3. Verificar limites de taxa na API de IA
4. Revisar logs de execução na interface do n8n

### Obtendo Ajuda

1. Consulte [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) para o design do sistema
2. Revise os logs de execução de workflow na interface do n8n
3. Verifique logs do Docker para erros de serviço
4. Abra uma issue no GitHub com:
   - Mensagens de erro
   - Logs relevantes
   - Passos para reproduzir

---

## 🔒 Segurança

### Melhores Práticas

✅ **FAÇA**:
- Use senhas fortes (32+ caracteres)
- Habilite HTTPS com certificado SSL
- Restrinja acesso com regras de firewall
- Atualize imagens Docker regularmente
- Faça backup de chaves de criptografia offline
- Use variáveis de ambiente para segredos
- Habilite limitação de taxa

❌ **NÃO FAÇA**:
- Commitar `.env` para controle de versão
- Expor portas diretamente para internet
- Usar senhas padrão
- Compartilhar chaves API
- Desabilitar funcionalidades de segurança

### Checklist de Produção

- [ ] Certificado SSL configurado
- [ ] Regras de firewall implementadas
- [ ] Senhas fortes definidas
- [ ] Estratégia de backup implementada
- [ ] Alertas de monitoramento configurados
- [ ] Limitação de taxa habilitada
- [ ] Imagens Docker atualizadas
- [ ] Chaves de criptografia com backup
- [ ] Logs de acesso revisados regularmente

### Criptografando Dados Sensíveis

O n8n criptografa credenciais usando `N8N_ENCRYPTION_KEY`. **Nunca perca esta chave** ou você perderá acesso a todas as credenciais armazenadas.

Armazene uma cópia de backup:
```bash
# Salvar em local seguro
echo $N8N_ENCRYPTION_KEY > /backup/seguro/n8n-encryption-key.txt
chmod 400 /backup/seguro/n8n-encryption-key.txt
```

---

## 📊 Monitoramento

### Métricas Principais para Monitorar

- Taxa de sucesso de execução de workflows
- Taxa de entrega de mensagens WhatsApp
- Tamanho e performance do banco de dados
- Uso de memória do Redis
- Uptime da Evolution API
- Tempo de resposta dos agentes

### Ferramentas Recomendadas

- **Prometheus + Grafana** para visualização de métricas
- **Sentry** para rastreamento de erros
- **UptimeRobot** para disponibilidade de serviços
- **Docker stats** para monitoramento de recursos

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor, siga estas diretrizes:

1. Faça fork do repositório
2. Crie uma branch de feature (`git checkout -b feature/recurso-incrivel`)
3. Commit suas mudanças (`git commit -m 'Adiciona recurso incrível'`)
4. Push para a branch (`git push origin feature/recurso-incrivel`)
5. Abra um Pull Request

### Configuração para Desenvolvimento

Veja [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) para instruções de desenvolvimento local.

---

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

## 🙏 Agradecimentos

- [n8n](https://n8n.io) - Plataforma de automação de workflow
- [Evolution API](https://evolution-api.com) - API do WhatsApp
- [Google Gemini](https://ai.google.dev) - Capacidades de IA/LLM
- Comunidades PostgreSQL, Redis e Docker

---

## 📧 Suporte

Para perguntas e suporte:

- 📖 Documentação: [docs/](docs/)
- 🐛 Issues: [GitHub Issues](https://github.com/seuusuario/n8n-clinic-multiagent/issues)
- 💬 Discussões: [GitHub Discussions](https://github.com/seuusuario/n8n-clinic-multiagent/discussions)

---

**Feito com ❤️ para clínicas modernas de saúde**

*Última atualização: 2026-01-01*
