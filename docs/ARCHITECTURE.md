# Arquitetura do Sistema

> **Documentação Proprietária**  
> Copyright © 2026. Todos os Direitos Reservados.  
> Este documento é confidencial e destinado apenas a clientes autorizados.

---

## Visão Geral

O **Sistema Multi-Agente de Gestão de Clínicas** é uma plataforma de automação containerizada e alimentada por IA, projetada para clínicas de saúde. Ele fornece comunicação inteligente com pacientes via WhatsApp, ferramentas internas para a equipe via Telegram e gerenciamento automatizado de agendamentos—tudo orquestrado através de workflows n8n.

---

## Stack Tecnológico

### Componentes Principais

| Componente | Tecnologia | Versão | Propósito |
|------------|------------|--------|-----------|
| **Motor de Orquestração** | n8n | latest | Automação de workflows e orquestração de agentes IA |
| **Banco de Dados** | PostgreSQL | 14+ | Armazenamento persistente para configurações, histórico de chat, cache de FAQ |
| **Camada de Cache** | Redis | 7+ | Gerenciamento de sessões e otimização de performance |
| **Gateway WhatsApp** | Evolution API | latest | Envio/recebimento de mensagens WhatsApp |
| **IA/LLM** | Google Gemini 2.0 Flash | latest | Compreensão e geração de linguagem natural |
| **Calendário** | Google Calendar + MCP | - | Agendamento e disponibilidade de consultas |
| **Containerização** | Docker Compose | - | Orquestração multi-container |

---

## Diagrama de Contexto C4

O diagrama a seguir ilustra como o sistema interage com atores externos e serviços:

```mermaid
C4Context
    title Diagrama de Contexto - Sistema Multi-Agente de Gestão de Clínicas

    Person(patient, "Paciente", "Paciente da clínica usando WhatsApp")
    Person(staff, "Equipe da Clínica", "Equipe interna usando Telegram")
    Person(manager, "Gerente da Clínica", "Administrador do sistema")

    System_Boundary(clinic_system, "Sistema de Gestão da Clínica") {
        System(n8n, "Motor de Workflow n8n", "Orquestra toda lógica de automação, agentes IA e integrações")
    }

    System_Ext(whatsapp, "WhatsApp", "Canal de comunicação com pacientes")
    System_Ext(telegram, "Telegram", "Comunicação interna da equipe")
    System_Ext(evolution, "Evolution API", "Serviço gateway WhatsApp")
    System_Ext(gemini, "Google Gemini AI", "Processamento e geração de linguagem natural")
    System_Ext(gcal, "Google Calendar", "Agendamento de consultas")
    System_Ext(gtasks, "Google Tasks", "Gerenciamento de tarefas")

    Rel(patient, whatsapp, "Envia mensagens via", "WhatsApp")
    Rel(whatsapp, evolution, "Mensagens encaminhadas para")
    Rel(evolution, n8n, "Dispara webhook", "HTTPS")
    
    Rel(n8n, gemini, "Processamento IA", "API")
    Rel(n8n, gcal, "Gerencia agendamentos", "API")
    Rel(n8n, gtasks, "Gerencia tarefas", "API")
    Rel(n8n, evolution, "Envia respostas", "API")
    Rel(evolution, whatsapp, "Entrega para")
    
    Rel(staff, telegram, "Interage via")
    Rel(telegram, n8n, "Dispara bot", "Webhook")
    Rel(n8n, telegram, "Envia notificações", "Bot API")
    
    Rel(manager, n8n, "Configura sistema", "Web UI")

    UpdateLayoutConfig($c4ShapeInRow="3", $c4BoundaryInRow="1")
```

---

## Arquitetura de Containers

```mermaid
graph TB
    subgraph "Rede Docker: clinic_network"
        subgraph "Camada de Aplicação"
            N8N[Container n8n<br/>Porta 5678<br/>Motor de Workflow]
        end
        
        subgraph "Camada de Dados"
            PG[(PostgreSQL<br/>Porta 5432<br/>Banco Principal)]
            REDIS[(Redis<br/>Porta 6379<br/>Cache & Sessões)]
        end
        
        subgraph "Camada de Gateway"
            EVO[Evolution API<br/>Porta 8080<br/>Gateway WhatsApp]
        end
    end
    
    subgraph "Serviços Externos"
        WA[WhatsApp<br/>Cloud]
        TG[Telegram<br/>Cloud]
        GM[Google Gemini<br/>API IA]
        GC[Google Calendar<br/>API]
    end
    
    N8N --> PG
    N8N --> REDIS
    N8N --> EVO
    EVO --> WA
    N8N --> TG
    N8N --> GM
    N8N --> GC
    
    style N8N fill:#ff6b6b
    style PG fill:#4ecdc4
    style REDIS fill:#ffe66d
    style EVO fill:#95e1d3
```

---

## Arquitetura de Dados

### Visão Geral do Schema do Banco

```mermaid
erDiagram
    TENANT_CONFIG ||--o{ TENANT_FAQ : possui
    TENANT_CONFIG ||--o{ TENANT_SECRETS : possui
    TENANT_CONFIG ||--o{ TENANT_ACTIVITY_LOG : possui
    TENANT_CONFIG ||--o{ CHAT_MEMORY : possui
    
    TENANT_CONFIG {
        uuid tenant_id PK
        varchar tenant_name
        varchar evolution_instance_name UK
        boolean is_active
        varchar clinic_name
        text clinic_address
        varchar google_calendar_id
        varchar google_tasks_list_id
        text system_prompt_patient
        text system_prompt_internal
        jsonb features
        int monthly_message_limit
    }
    
    TENANT_FAQ {
        uuid faq_id PK
        uuid tenant_id FK
        text question_normalized
        text answer
        text[] keywords
        varchar intent
        int view_count
        timestamp last_used_at
    }
    
    TENANT_SECRETS {
        uuid secret_id PK
        uuid tenant_id FK
        varchar secret_key
        text secret_value_encrypted
        varchar secret_type
    }
    
    CHAT_MEMORY {
        uuid id PK
        varchar session_id
        text message
        varchar role
        timestamp created_at
        uuid tenant_id FK
    }
```

### Estratégia de Isolamento Multi-Tenant

1. **Isolamento de Configuração**: Cada tenant possui um `tenant_id` e `evolution_instance_name` únicos
2. **Isolamento de Dados**: Todas as consultas filtradas por `tenant_id` via sub-workflow tenant-config-loader
3. **Isolamento de Memória**: Sessões de chat prefixadas com `{tenant_id}_{telefone_usuario}`
4. **Isolamento de FAQ**: Cache de FAQ com escopo por tenant com índices dedicados
5. **Opcional**: Políticas Row-Level Security (RLS) para isolamento adicional em nível de banco

---

## Arquitetura de Workflows

### Workflows Principais

```mermaid
graph LR
    subgraph "Pontos de Entrada"
        WH[Webhook<br/>WhatsApp]
        TH[Webhook<br/>Telegram]
        CRON[Trigger<br/>Agendado]
    end
    
    subgraph "Workflows Principais"
        WF1[01-whatsapp-patient<br/>-handler-optimized]
        WF2[02-telegram-internal<br/>-assistant]
        WF3[03-appointment<br/>-confirmation]
        WF4[04-error<br/>-handler]
    end
    
    subgraph "Sub-Workflows"
        SUB[tenant-config<br/>-loader]
    end
    
    subgraph "Workflows de Ferramentas"
        T1[Ferramentas de Calendário]
        T2[Ferramentas de Comunicação]
        T3[Ferramentas de Processamento IA]
        T4[Ferramentas de Escalonamento]
    end
    
    WH --> WF1
    TH --> WF2
    CRON --> WF3
    
    WF1 --> SUB
    WF2 --> SUB
    WF3 --> SUB
    
    WF1 --> T1
    WF1 --> T2
    WF1 --> T3
    WF1 --> T4
    
    WF2 --> T1
    WF2 --> T2
    
    WF1 -.erro.-> WF4
    WF2 -.erro.-> WF4
    WF3 -.erro.-> WF4
    
    style WF1 fill:#ff6b6b
    style WF2 fill:#4ecdc4
    style WF3 fill:#95e1d3
    style WF4 fill:#ffd93d
```

### Camada de Otimização de IA

O sistema inclui um mecanismo de roteamento inteligente que reduz custos de API de IA em 70-75%:

```mermaid
flowchart TD
    START([Mensagem do Usuário]) --> PARSE[Processar Webhook]
    PARSE --> LOAD[Carregar Config Tenant]
    LOAD --> INTENT[Classificador de Intenção<br/>Pattern Matching]
    
    INTENT --> CACHE{Verificação de<br/>Cache FAQ}
    
    CACHE -->|Acerto 65-80%| CACHED[Usar Resposta em Cache<br/>Custo: $0.001<br/>Tempo: 50ms]
    CACHE -->|Erro 20-35%| AI[Processamento Agente IA<br/>Custo: $0.012<br/>Tempo: 1.5s]
    
    AI --> LEARN[Cachear Resposta<br/>para Uso Futuro]
    LEARN --> FORMAT[Formatar Mensagem]
    CACHED --> FORMAT
    
    FORMAT --> SEND[Enviar Resposta WhatsApp]
    SEND --> END([Completo])
    
    style INTENT fill:#ffe66d
    style CACHE fill:#4ecdc4
    style CACHED fill:#95e1d3
    style AI fill:#ff6b6b
    style LEARN fill:#a8e6cf
```

**Impacto nos Custos**:
- **Antes da Otimização**: $0.015 por mensagem (2 chamadas IA)
- **Após Otimização**: $0.004 por mensagem em média (0.3 chamadas IA)
- **Economia**: Redução de 70-75% nos custos de IA

---

## Fluxo de Mensagens

### Fluxo de Comunicação com Paciente

```mermaid
sequenceDiagram
    autonumber
    
    participant P as Paciente
    participant W as WhatsApp
    participant E as Evolution API
    participant N as Motor n8n
    participant DB as PostgreSQL
    participant AI as Gemini AI
    participant GC as Google Calendar
    
    P->>W: Envia mensagem
    W->>E: Encaminha mensagem
    E->>N: Dispara webhook
    
    N->>DB: Carrega config tenant
    DB-->>N: Configurações tenant
    
    N->>N: Classificação de intenção
    N->>DB: Verifica cache FAQ
    
    alt Acerto no Cache (65-80%)
        DB-->>N: Resposta em cache
    else Erro no Cache (20-35%)
        N->>AI: Processa com LLM
        AI-->>N: Resposta gerada
        
        opt Se relacionado a agendamento
            N->>GC: Verifica disponibilidade
            GC-->>N: Horários disponíveis
        end
        
        N->>DB: Cacheia resposta
    end
    
    N->>N: Formata para WhatsApp
    N->>E: Envia resposta
    E->>W: Entrega mensagem
    W->>P: Recebe resposta
```

### Fluxo da Equipe Interna

```mermaid
sequenceDiagram
    autonumber
    
    participant S as Membro da Equipe
    participant T as Telegram
    participant N as Motor n8n
    participant AI as Gemini AI
    participant GC as Google Calendar
    participant GT as Google Tasks
    participant E as Evolution API
    participant P as Paciente
    
    S->>T: Envia comando<br/>(ex: "Remarcar João para 14h")
    T->>N: Webhook do bot
    
    N->>AI: Extrai intenção + dados
    AI-->>N: Ação: Remarcar + Paciente: João + Horário: 14h
    
    N->>GC: Atualiza agendamento
    GC-->>N: Confirmação
    
    N->>E: Envia WhatsApp para paciente
    E->>P: "Sua consulta foi remarcada para 14h"
    
    N->>T: Confirma para equipe
    T->>S: "✅ Remarcado com sucesso"
```

---

## Arquitetura de Segurança

### Autenticação e Autorização

```mermaid
graph TD
    subgraph "Acesso Externo"
        WH[Webhook WhatsApp<br/>Chave Evolution API]
        TH[Webhook Telegram<br/>Token do Bot]
        UI[Interface Web n8n<br/>Autenticação Básica]
    end
    
    subgraph "Acesso a Serviços"
        N8N[Motor n8n]
    end
    
    subgraph "Gerenciamento de Credenciais"
        CRED[Armazenamento de Credenciais n8n<br/>Criptografado em Repouso]
    end
    
    subgraph "APIs Externas"
        GEMINI[Google Gemini<br/>Chave API]
        GCAL[Google Calendar<br/>OAuth2]
        EVO[Evolution API<br/>Chave API]
    end
    
    WH --> N8N
    TH --> N8N
    UI --> N8N
    
    N8N --> CRED
    CRED --> GEMINI
    CRED --> GCAL
    CRED --> EVO
    
    style CRED fill:#ff6b6b
    style N8N fill:#4ecdc4
```

### Proteção de Dados

1. **Criptografia em Repouso**: PostgreSQL com volumes criptografados
2. **Criptografia em Trânsito**: HTTPS/TLS para todas as chamadas de API externas
3. **Armazenamento de Credenciais**: Cofre de credenciais criptografadas do n8n
4. **Gerenciamento de Secrets**: Tabela `tenant_secrets` opcional com valores criptografados
5. **Isolamento de Rede**: Rede interna Docker, apenas portas necessárias expostas
6. **Controle de Acesso**: Nome da instância Evolution API atua como identificador do tenant

---

## Considerações de Escalabilidade

### Arquitetura Atual

- **Implantação em Servidor Único**: Todos os containers em um host
- **Escalamento Vertical**: Aumentar CPU/RAM para container n8n
- **Banco de Dados**: Instância única PostgreSQL com connection pooling

### Estratégia de Scale-Out (Futuro)

```mermaid
graph TB
    subgraph "Balanceador de Carga"
        LB[NGINX/Traefik]
    end
    
    subgraph "Cluster n8n"
        N1[Instância n8n 1]
        N2[Instância n8n 2]
        N3[Instância n8n 3]
    end
    
    subgraph "Camada de Dados"
        PG_PRIMARY[(PostgreSQL<br/>Primário)]
        PG_REPLICA[(PostgreSQL<br/>Réplica de Leitura)]
        REDIS_CLUSTER[(Cluster Redis)]
    end
    
    LB --> N1
    LB --> N2
    LB --> N3
    
    N1 --> PG_PRIMARY
    N2 --> PG_PRIMARY
    N3 --> PG_PRIMARY
    
    N1 --> PG_REPLICA
    N2 --> PG_REPLICA
    N3 --> PG_REPLICA
    
    N1 --> REDIS_CLUSTER
    N2 --> REDIS_CLUSTER
    N3 --> REDIS_CLUSTER
```

**Capacidade Atual** (Servidor Único - 4 vCPU, 8GB RAM):
- ~10-20 tenants
- ~50.000 mensagens/mês total
- ~100 conversas simultâneas

**Gatilhos de Escalamento Recomendados**:
- Uso de CPU > 70% sustentado
- Conexões de banco > 80% do pool
- Tempo de resposta > 3s P95
- Mais de 20 tenants ativos

---

## Monitoramento e Observabilidade

### Métricas Principais

| Métrica | Meta | Limiar de Alerta |
|---------|------|------------------|
| Tempo de Resposta (P95) | < 2s | > 5s |
| Taxa de Erro | < 1% | > 5% |
| Taxa de Acerto Cache FAQ | > 60% | < 40% |
| Custo API IA/Mensagem | < $0.005 | > $0.015 |
| Pool de Conexões do Banco | < 80% | > 90% |
| Uso de Disco | < 70% | > 85% |

### Estratégia de Logs

```mermaid
graph LR
    N8N[Execuções n8n] --> JSON[Logs JSON]
    PG[PostgreSQL] --> PGLOG[Logs de Query]
    REDIS[Redis] --> REDISLOG[Slow Log]
    EVO[Evolution API] --> EVOLOG[Logs de Acesso]
    
    JSON --> AGENT[Agregador de Logs<br/>Opcional: Loki/ELK]
    PGLOG --> AGENT
    REDISLOG --> AGENT
    EVOLOG --> AGENT
    
    AGENT --> DASH[Dashboard Grafana]
    
    style DASH fill:#4ecdc4
```

---

## Recuperação de Desastres

### Estratégia de Backup

1. **Banco de Dados**: Backups diários automatizados via `pg_dump`
2. **Dados n8n**: Snapshots de volume de `/home/node/.n8n`
3. **Configurações de Ambiente**: Backup do arquivo `.env`
4. **Retenção**: 7 diários, 4 semanais, 12 mensais

### Procedimento de Recuperação

```bash
# 1. Restaurar banco de dados
psql $DATABASE_URL < backup_YYYYMMDD.sql

# 2. Restaurar dados n8n
docker cp backup_n8n_data.tar n8n:/home/node/.n8n

# 3. Reiniciar serviços
docker-compose restart

# 4. Verificar saúde
curl http://localhost:5678/healthz
```

**Objetivo de Tempo de Recuperação (RTO)**: < 1 hora  
**Objetivo de Ponto de Recuperação (RPO)**: < 24 horas

---

## Otimização de Performance

### Índices do Banco de Dados

Todos os caminhos críticos de consulta são indexados:
- `tenant_config.evolution_instance_name` (único)
- `tenant_faq.tenant_id, question_normalized` (composto)
- `tenant_faq.keywords` (índice GIN para correspondência de array)
- `langchain_pg_memory.tenant_id, session_id` (composto)

### Estratégia de Cache

1. **Cache FAQ**: Baseado em PostgreSQL (persistente)
2. **Dados de Sessão**: Redis (efêmero)
3. **Config Tenant**: Carregada por execução de workflow (overhead mínimo)

### Otimização de Queries

- Config tenant: Query única com todos os campos (1 acesso ao banco)
- Busca FAQ: Query indexada com ILIKE (< 5ms)
- Memória de chat: Recuperação baseada em janela (últimas 5 mensagens)

---

## Escolhas Tecnológicas - Justificativas

| Decisão | Justificativa |
|---------|---------------|
| **n8n vs Zapier** | Self-hosted, sem custo por execução, controle total de workflow, suporte a agente IA |
| **PostgreSQL vs MongoDB** | Conformidade ACID crítica para agendamentos, indexação forte, jsonb para flexibilidade |
| **Redis vs Memcached** | Estruturas de dados mais ricas, opções de persistência, capacidades pub/sub |
| **Evolution API vs Twilio** | Suporte a WhatsApp Cloud API, opção self-hosted, compatível com Brasil |
| **Gemini vs OpenAI** | Menor custo, respostas mais rápidas, suporte multimodal (visão + áudio) |
| **Docker Compose vs Kubernetes** | Operações mais simples, suficiente para escala de 10-20 tenants, menor overhead |

---

## Conformidade e Privacidade de Dados

### Considerações LGPD/GDPR

1. **Minimização de Dados**: Apenas dados essenciais de pacientes armazenados
2. **Direito ao Esquecimento**: Delete em cascata na remoção de tenant
3. **Portabilidade de Dados**: Dump PostgreSQL por tenant
4. **Gerenciamento de Consentimento**: Rastreado via opt-in WhatsApp
5. **Trilha de Auditoria**: Tabela `tenant_activity_log`

### Tratamento de PHI/PII

- **Nomes de Pacientes**: Armazenados na memória de chat (criptografados em repouso)
- **Números de Telefone**: Hash para chaves de sessão
- **Dados Médicos**: NÃO armazenados (apenas metadados de agendamento)
- **Localização**: Apenas endereço da clínica (sem endereços de pacientes)

---

## Suporte e Manutenção

### Estratégia de Atualizações

1. **Atualizações n8n**: Revisão mensal, teste em staging, deploy em produção
2. **Atualizações de Workflows**: Versionados via git, implantados via importação
3. **Migrações de Banco**: Scripts incrementais em `scripts/migrations/`
4. **Atualizações de Dependências**: Patches de segurança trimestrais

### Verificações de Saúde

```bash
# Saúde n8n
curl http://localhost:5678/healthz

# PostgreSQL
docker exec clinic_postgres pg_isready

# Redis
docker exec clinic_redis redis-cli ping

# Evolution API
curl http://localhost:8080/instance/connectionState/clinic_instance
```

---

**Versão do Documento**: 1.0  
**Última Atualização**: 01-01-2026  
**Classificação**: Proprietário e Confidencial
