# 🏥 Cenários de Negócio

> **Documentação Proprietária**  
> Copyright © 2026. Todos os Direitos Reservados.  
> Casos de uso detalhados para diferentes perfis de clínicas.

---

## 📋 Índice de Cenários

1. [Consultório Individual](#cenário-1-consultório-individual)
2. [Clínica Multi-Profissional](#cenário-2-clínica-multi-profissional)
3. [Clínica Odontológica](#cenário-3-clínica-odontológica)
4. [Clínica Estética](#cenário-4-clínica-estética)
5. [Rede de Clínicas](#cenário-5-rede-de-clínicas)
6. [Hospital/Centro Médico](#cenário-6-hospitalcentro-médico)

---

## Cenário 1: Consultório Individual

### 👤 Perfil

```mermaid
graph TB
    subgraph PERFIL["Consultório Dra. Ana - Dermatologista"]
        P1[1 Médica]
        P2[1 Secretária Part-time]
        P3[200 pacientes/mês]
        P4[WhatsApp pessoal<br/>para atendimento]
    end
    
    subgraph DORES["❌ Dores Atuais"]
        D1[Mensagens à noite<br/>e fim de semana]
        D2[Tempo gasto<br/>respondendo FAQs]
        D3[Agenda manual<br/>no papel]
        D4[Perda de pacientes<br/>por demora]
    end
    
    style PERFIL fill:#dbeafe
    style DORES fill:#fee2e2
```

### 🎯 Implementação

```mermaid
flowchart TB
    subgraph CONFIG["⚙️ Configuração"]
        C1[1 Tenant]
        C2[1 Profissional]
        C3[1 Calendário Google]
        C4[WhatsApp Business]
    end
    
    subgraph AUTOMACOES["🤖 Automações"]
        A1[Resposta automática<br/>horário e localização]
        A2[Agendamento via IA]
        A3[Confirmação 24h antes]
        A4[Lista de espera<br/>automática]
    end
    
    subgraph RESULTADOS["📈 Resultados"]
        R1["-80% tempo<br/>respondendo msgs"]
        R2["+25% agendamentos"]
        R3["100% disponível<br/>24/7"]
        R4["R$ 0/mês adicional<br/>em pessoal"]
    end
    
    CONFIG --> AUTOMACOES --> RESULTADOS
    
    style CONFIG fill:#dbeafe
    style AUTOMACOES fill:#fef3c7
    style RESULTADOS fill:#d1fae5
```

### 💬 Exemplo de Conversa

```
PACIENTE (22:30): Oi, gostaria de marcar uma consulta
BOT: Olá! 😊 Seja bem-vindo(a) ao consultório da Dra. Ana.

Para agendar sua consulta, preciso de algumas informações:
- Qual seu nome completo?
- É sua primeira consulta conosco?

PACIENTE: Maria Silva, primeira vez

BOT: Prazer, Maria! 

📅 Horários disponíveis esta semana:
• Terça 10h
• Quarta 14h  
• Quinta 9h ou 16h

Qual horário você prefere?

PACIENTE: Quarta 14h

BOT: ✅ Perfeito! Sua consulta está agendada:

📋 Confirmação:
• Dra. Ana Souza - Dermatologista
• Data: Quarta, 08/01/2026 às 14h
• Duração: 30 minutos
• Valor: R$ 350,00
• Local: Rua das Flores, 123 - Sala 45

⚠️ Importante:
• Traga exames recentes se tiver
• Chegue 10 min antes para cadastro

Até quarta! 💜
```

### 📊 ROI Calculado

| Métrica | Antes | Depois | Economia |
|---------|-------|--------|----------|
| **Horas respondendo/mês** | 40h | 5h | 35h |
| **Custo hora secretária** | R$ 25 | R$ 25 | - |
| **Economia mensal** | - | - | R$ 875 |
| **Custo sistema** | - | R$ 297 | - |
| **ROI Líquido** | - | - | **R$ 578/mês** |

---

## Cenário 2: Clínica Multi-Profissional

### 👤 Perfil

```mermaid
graph TB
    subgraph PERFIL["Clínica Saúde Total"]
        P1["5 Médicos<br/>(diferentes especialidades)"]
        P2[2 Secretárias]
        P3[800 pacientes/mês]
        P4[1 WhatsApp para todos]
    end
    
    subgraph PROFISSIONAIS["👨‍⚕️ Equipe"]
        PR1[Dr. João - Cardiologia]
        PR2[Dra. Maria - Dermatologia]
        PR3[Dr. Pedro - Ortopedia]
        PR4[Dra. Ana - Ginecologia]
        PR5[Dr. Carlos - Clínico Geral]
    end
    
    style PERFIL fill:#dbeafe
    style PROFISSIONAIS fill:#c7d2fe
```

### 🎯 Fluxo de Roteamento

```mermaid
flowchart TD
    START([Paciente envia msg]) --> PARSE[Processar mensagem]
    
    PARSE --> DETECT{Detectar<br/>Profissional}
    
    DETECT -->|"Cardiologista"| DR_JOAO[Dr. João<br/>Calendário A]
    DETECT -->|"Pele/Dermatologista"| DRA_MARIA[Dra. Maria<br/>Calendário B]
    DETECT -->|"Ortopedia/Ossos"| DR_PEDRO[Dr. Pedro<br/>Calendário C]
    DETECT -->|"Ginecologia"| DRA_ANA[Dra. Ana<br/>Calendário D]
    DETECT -->|Ambíguo/Geral| ASK[Perguntar ao paciente]
    
    ASK --> LIST["Com qual especialidade<br/>você gostaria de agendar?<br/><br/>1. Cardiologia<br/>2. Dermatologia<br/>3. Ortopedia<br/>4. Ginecologia<br/>5. Clínico Geral"]
    
    DR_JOAO & DRA_MARIA & DR_PEDRO & DRA_ANA --> CHECK[Verificar disponibilidade<br/>no calendário específico]
    LIST --> |Paciente escolhe| CHECK
    
    CHECK --> BOOK[Agendar no<br/>calendário correto]
    
    style ASK fill:#fef3c7
    style CHECK fill:#d1fae5
```

### 💬 Exemplo de Conversa Multi-Profissional

```
PACIENTE: Oi, preciso marcar uma consulta

BOT: Olá! 😊 Bem-vindo à Clínica Saúde Total.

Temos várias especialidades disponíveis:
• 🫀 Cardiologia - Dr. João Silva
• 🧴 Dermatologia - Dra. Maria Costa  
• 🦴 Ortopedia - Dr. Pedro Santos
• 👩 Ginecologia - Dra. Ana Oliveira
• 🩺 Clínico Geral - Dr. Carlos Lima

Com qual especialidade você gostaria de agendar?

PACIENTE: Preciso de um cardiologista

BOT: Perfeito! O Dr. João Silva é nosso Cardiologista.

📋 Informações da consulta:
• Duração: 40 minutos
• Valor: R$ 400,00

📅 Próximos horários disponíveis:
• Segunda 09:00
• Terça 14:00
• Quinta 10:30

Qual prefere?

PACIENTE: Segunda 9h

BOT: ✅ Agendado com sucesso!

📋 Sua consulta:
• Dr. João Silva - Cardiologia
• Segunda, 06/01/2026 às 09:00
• Valor: R$ 400,00

⚠️ Importante para consulta cardiológica:
• Traga exames anteriores
• Evite café no dia
• Jejum de 4h se for fazer ECG

Até segunda! 🫀
```

### 📊 Configuração de Banco de Dados

```sql
-- Profissionais da Clínica Saúde Total
INSERT INTO professionals (tenant_id, professional_name, specialty, google_calendar_id) VALUES
('saude-total-uuid', 'Dr. João Silva', 'Cardiologia', 'joao@calendar.google.com'),
('saude-total-uuid', 'Dra. Maria Costa', 'Dermatologia', 'maria@calendar.google.com'),
('saude-total-uuid', 'Dr. Pedro Santos', 'Ortopedia', 'pedro@calendar.google.com'),
('saude-total-uuid', 'Dra. Ana Oliveira', 'Ginecologia', 'ana@calendar.google.com'),
('saude-total-uuid', 'Dr. Carlos Lima', 'Clínico Geral', 'carlos@calendar.google.com');

-- Serviços por profissional (preços e durações diferentes)
INSERT INTO professional_services (professional_id, service_id, custom_duration_minutes, custom_price_cents) VALUES
-- Dr. João - Cardiologia
('joao-uuid', 'consulta-uuid', 40, 40000),
('joao-uuid', 'ecg-uuid', 30, 15000),
('joao-uuid', 'holter-uuid', 60, 50000),
-- Dra. Maria - Dermatologia  
('maria-uuid', 'consulta-uuid', 30, 35000),
('maria-uuid', 'botox-uuid', 60, 120000),
('maria-uuid', 'peeling-uuid', 45, 80000);
```

---

## Cenário 3: Clínica Odontológica

### 👤 Perfil

```mermaid
graph TB
    subgraph PERFIL["Odonto Smile"]
        P1["3 Dentistas"]
        P2["1 Ortodontista"]
        P3["600 pacientes/mês"]
        P4["Procedimentos diversos"]
    end
    
    subgraph SERVICOS["🦷 Serviços"]
        S1["Limpeza - 30min - R$ 150"]
        S2["Restauração - 1h - R$ 250"]
        S3["Canal - 2h - R$ 800"]
        S4["Implante - 3h - R$ 5.000"]
        S5["Ortodontia - 45min - R$ 500"]
    end
    
    style PERFIL fill:#dbeafe
    style SERVICOS fill:#fef3c7
```

### 🎯 Fluxo com Validação de Duração

```mermaid
flowchart TD
    START([Paciente quer implante]) --> LOOKUP[Buscar serviço<br/>'implante']
    
    LOOKUP --> INFO["Implante Dentário<br/>Duração: 3 horas<br/>Valor: R$ 5.000<br/>Profissional: Dr. Ricardo"]
    
    INFO --> PRESENT[Apresentar ao paciente]
    
    PRESENT --> PATIENT[Paciente: "Pode ser<br/>amanhã às 14h?"]
    
    PATIENT --> CHECK{Verificar slot<br/>14h-17h livre?}
    
    CHECK -->|"Sim (3h disponíveis)"| BOOK[✅ Agendar<br/>14:00 - 17:00]
    CHECK -->|"Não (só até 16h)"| REJECT["❌ Slot insuficiente<br/>Preciso de 3h livres"]
    
    REJECT --> SUGGEST["Horários com 3h disponíveis:<br/>• Seg 08:00-11:00<br/>• Qua 14:00-17:00"]
    
    BOOK --> CONFIRM["✅ Agendado!<br/>Dr. Ricardo<br/>14:00 às 17:00<br/>R$ 5.000"]
    
    style CHECK fill:#fef3c7
    style BOOK fill:#d1fae5
    style REJECT fill:#fee2e2
```

### 💬 Exemplo de Conversa

```
PACIENTE: Quero fazer um implante

BOT: Olá! O procedimento de Implante Dentário é realizado pelo Dr. Ricardo.

📋 Detalhes do procedimento:
• Duração: 3 horas
• Valor: R$ 5.000,00
• Anestesia: Local
• Recuperação: 7-10 dias

⚠️ Pré-requisitos:
• Exame panorâmico recente
• Avaliação prévia (se primeira vez)

Gostaria de agendar?

PACIENTE: Sim, pode ser quinta às 15h?

BOT: Deixa eu verificar... 🔍

O procedimento precisa de 3 horas, mas quinta às 15h só temos disponibilidade até 17h (2 horas).

📅 Horários com 3h disponíveis:
• Quinta 08:00-11:00 ✅
• Sexta 14:00-17:00 ✅

Qual prefere?

PACIENTE: Sexta 14h

BOT: ✅ Perfeito! Agendamento confirmado:

📋 Implante Dentário
• Dr. Ricardo Almeida
• Sexta, 10/01/2026
• Horário: 14:00 às 17:00 (3h)
• Valor: R$ 5.000,00

⚠️ Instruções importantes:
• Traga exame panorâmico
• Evite anti-inflamatórios 3 dias antes
• Alimente-se normalmente
• Traga acompanhante

Até sexta! 🦷
```

---

## Cenário 4: Clínica Estética

### 👤 Perfil

```mermaid
graph TB
    subgraph PERFIL["Beleza Clinic"]
        P1["2 Dermatologistas"]
        P2["1 Cirurgião Plástico"]
        P3["400 procedimentos/mês"]
        P4["Alto ticket médio"]
    end
    
    subgraph SERVICOS["💄 Catálogo"]
        S1["Botox - R$ 1.200"]
        S2["Preenchimento - R$ 2.500"]
        S3["Harmonização - R$ 5.000"]
        S4["Lipoaspiração - R$ 15.000"]
        S5["Peeling - R$ 800"]
    end
    
    style PERFIL fill:#fce7f3
    style SERVICOS fill:#fbcfe8
```

### 🎯 Fluxo de Upsell Inteligente

```mermaid
flowchart TD
    START([Paciente: "Quero Botox"]) --> BOOK[Agendar Botox<br/>R$ 1.200]
    
    BOOK --> DETECT[IA detecta<br/>interesse em estética]
    
    DETECT --> UPSELL["💡 Sugestão Complementar:<br/>'Muitos pacientes combinam<br/>Botox + Preenchimento para<br/>resultado completo.<br/>Combo: R$ 3.200 (economia R$ 500)'"]
    
    UPSELL --> ACCEPT{Paciente<br/>aceita?}
    
    ACCEPT -->|Sim| COMBO[Agendar Combo<br/>2h - R$ 3.200]
    ACCEPT -->|Não| SINGLE[Manter só Botox<br/>1h - R$ 1.200]
    
    COMBO & SINGLE --> CONFIRM[Enviar confirmação]
    
    CONFIRM --> FOLLOWUP["📅 Lembrete automático<br/>em 4 meses:<br/>'Hora de renovar seu Botox!'"]
    
    style UPSELL fill:#fef3c7
    style COMBO fill:#d1fae5
```

### 📊 Automação de Retorno

```mermaid
sequenceDiagram
    participant P as Paciente
    participant S as Sistema
    participant C as Calendário
    
    Note over P,C: Procedimento realizado
    
    S->>C: Criar lembrete<br/>+4 meses
    
    Note over P,C: 4 meses depois...
    
    C->>S: Trigger: Lembrete
    S->>P: "Oi Maria! 💜<br/>Já faz 4 meses do seu Botox.<br/>Que tal agendar sua manutenção?<br/><br/>📅 Horários disponíveis:<br/>• Terça 14h<br/>• Quinta 10h"
    
    P->>S: "Terça 14h"
    S->>C: Criar agendamento
    S->>P: "✅ Agendado! Até terça!"
```

---

## Cenário 5: Rede de Clínicas

### 👤 Perfil

```mermaid
graph TB
    subgraph REDE["Rede Vida Saúde"]
        direction TB
        HQ[Matriz - São Paulo]
        
        subgraph UNIDADES["10 Unidades"]
            U1[Paulista]
            U2[Moema]
            U3[Pinheiros]
            U4[Campinas]
            U5[Santos]
            U6[Mais 5...]
        end
        
        HQ --> UNIDADES
    end
    
    subgraph METRICAS["📊 Volume"]
        M1[5.000 pacientes/mês]
        M2[50 profissionais]
        M3[10 WhatsApps]
        M4[1 Sistema centralizado]
    end
    
    style REDE fill:#dbeafe
    style METRICAS fill:#d1fae5
```

### 🎯 Arquitetura Multi-Tenant

```mermaid
flowchart TB
    subgraph ENTRADA["📱 Múltiplos Canais"]
        WA1[WhatsApp<br/>Paulista]
        WA2[WhatsApp<br/>Moema]
        WA3[WhatsApp<br/>Pinheiros]
        WAN[...]
    end
    
    subgraph SISTEMA["🧠 Sistema Centralizado"]
        EVO[Evolution API<br/>Multi-instância]
        N8N[n8n<br/>Processamento]
        ROUTER[Tenant Router<br/>Identifica clínica]
    end
    
    subgraph TENANTS["🏥 Configurações por Tenant"]
        T1["Paulista<br/>• Calendário próprio<br/>• FAQs próprios<br/>• Preços próprios"]
        T2["Moema<br/>• Calendário próprio<br/>• FAQs próprios<br/>• Preços próprios"]
        T3["Pinheiros<br/>• ..."]
    end
    
    subgraph DASHBOARD["📊 Dashboard Centralizado"]
        D1[Métricas consolidadas]
        D2[Comparativo unidades]
        D3[Alertas gerenciais]
    end
    
    ENTRADA --> SISTEMA
    SISTEMA --> TENANTS
    TENANTS --> DASHBOARD
    
    style SISTEMA fill:#8b5cf6,color:#fff
```

### 📊 Dashboard Gerencial

```mermaid
xychart-beta
    title "Performance by Unit - January 2026"
    x-axis ["Paulista", "Moema", "Pinheiros", "Campinas", "Santos"]
    y-axis "Appointments" 0 --> 1000
    bar "Appointments" [850, 720, 680, 540, 490]
    line "Target" [700, 700, 700, 500, 500]
```

> **Performance por Unidade**: Agendamentos realizados vs Meta por filial.

| Unidade | Mensagens | Agendamentos | Conversão | Custo IA |
|---------|-----------|--------------|-----------|----------|
| **Paulista** | 2.100 | 850 | 40% | R$ 126 |
| **Moema** | 1.800 | 720 | 40% | R$ 108 |
| **Pinheiros** | 1.600 | 680 | 43% | R$ 96 |
| **Campinas** | 1.200 | 540 | 45% | R$ 72 |
| **Santos** | 1.100 | 490 | 45% | R$ 66 |
| **TOTAL** | 7.800 | 3.280 | 42% | R$ 468 |

### 💰 ROI Rede de Clínicas

| Métrica | Sem Sistema | Com Sistema | Diferença |
|---------|-------------|-------------|-----------|
| **Secretárias** | 20 (2/unidade) | 12 | -8 pessoas |
| **Custo Mensal Pessoal** | R$ 60.000 | R$ 36.000 | -R$ 24.000 |
| **Sistema** | R$ 0 | R$ 15.000 | +R$ 15.000 |
| **Economia Líquida** | - | - | **R$ 9.000/mês** |
| **Economia Anual** | - | - | **R$ 108.000** |

---

## Cenário 6: Hospital/Centro Médico

### 👤 Perfil

```mermaid
graph TB
    subgraph HOSPITAL["Hospital Santa Clara"]
        H1[200 leitos]
        H2[80 médicos]
        H3[20 especialidades]
        H4[3.000 atendimentos/mês]
    end
    
    subgraph DEPARTAMENTOS["🏥 Departamentos"]
        D1[Pronto Socorro]
        D2[Ambulatório]
        D3[Centro Cirúrgico]
        D4[Internação]
        D5[Exames/Diagnóstico]
    end
    
    style HOSPITAL fill:#dbeafe
    style DEPARTAMENTOS fill:#c7d2fe
```

### 🎯 Fluxo de Triagem Inteligente

```mermaid
flowchart TD
    START([Paciente entra em contato]) --> TRIAGE{Triagem<br/>Automática}
    
    TRIAGE -->|"Urgência/Emergência"| URGENTE["🚨 URGENTE<br/>Direcionar para PS<br/>Telefone: 0800..."]
    
    TRIAGE -->|"Agendamento"| TIPO{Tipo de<br/>Agendamento}
    
    TIPO -->|Consulta| SPECIALTY[Selecionar<br/>Especialidade]
    TIPO -->|Exame| EXAME[Catálogo de<br/>Exames]
    TIPO -->|Retorno| RETORNO[Buscar médico<br/>anterior]
    
    SPECIALTY --> CALENDAR[Verificar<br/>Disponibilidade]
    EXAME --> PREP[Mostrar preparo<br/>necessário]
    RETORNO --> CALENDAR
    
    PREP --> CALENDAR
    CALENDAR --> BOOK[Agendar]
    
    URGENTE --> NOTIFY[Notificar<br/>Equipe PS]
    
    style URGENTE fill:#fee2e2
    style BOOK fill:#d1fae5
```

### 💬 Fluxo de Exames com Preparo

```
PACIENTE: Preciso fazer um exame de sangue

BOT: Olá! 😊 Para exames laboratoriais, preciso de algumas informações:

Qual exame você precisa realizar?
1. Hemograma Completo
2. Glicemia
3. Colesterol/Triglicerídeos
4. Função Renal
5. Função Hepática
6. Outro (descreva)

PACIENTE: Glicemia e Colesterol

BOT: Perfeito! Selecionados:
• Glicemia em Jejum
• Perfil Lipídico (Colesterol + Triglicerídeos)

⚠️ PREPARO NECESSÁRIO:
━━━━━━━━━━━━━━━━━━
• Jejum de 12 horas
• Água pode beber normalmente
• Evitar exercícios intensos 24h antes
• Não consumir álcool 72h antes

📅 Horários disponíveis (manhã para jejum):
• Segunda 07:00
• Terça 07:30
• Quarta 08:00

Qual prefere?

PACIENTE: Segunda 7h

BOT: ✅ Exames agendados!

📋 Confirmação:
• Hospital Santa Clara - Laboratório
• Segunda, 06/01/2026 às 07:00
• Exames: Glicemia + Perfil Lipídico
• Valor: R$ 120,00

📍 Local: Térreo, Ala B - Coleta

⏰ Lembrete: Jejum de 12h!
Último horário para alimentação: Domingo 19h

Até segunda! 🩺
```

---

## 📊 Comparativo de Cenários

```mermaid
xychart-beta
    title "Complexity vs Volume by Scenario"
    x-axis ["Individual", "Multi-Prof", "Dental", "Aesthetic", "Network", "Hospital"]
    y-axis "Score 1-10" 0 --> 10
    bar "Volume" [2, 5, 4, 3, 8, 10]
    bar "Config Complexity" [2, 5, 6, 4, 7, 9]
    line "Potential ROI" [3, 6, 5, 7, 9, 8]
```

> **Complexidade vs Volume**: Individual, Multi-Profissional, Odonto, Estética, Rede, Hospital

| Cenário | Mensalidade Sugerida | Setup | ROI Típico |
|---------|---------------------|-------|------------|
| **Individual** | R$ 297 | R$ 500 | 2-3x |
| **Multi-Prof** | R$ 697 | R$ 2.000 | 3-4x |
| **Odontológica** | R$ 697 | R$ 2.500 | 3-4x |
| **Estética** | R$ 997 | R$ 3.000 | 4-5x |
| **Rede** | R$ 5.000+ | R$ 15.000 | 5-8x |
| **Hospital** | Sob consulta | R$ 50.000+ | 3-5x |

---

## 🎯 Próximos Passos por Cenário

### Consultório Individual
1. Criar trial 14 dias
2. Configurar WhatsApp Business
3. Importar FAQs básicos
4. Go-live em 3 dias

### Clínica Multi-Profissional
1. Mapear todos profissionais e serviços
2. Configurar calendários individuais
3. Definir regras de roteamento
4. Treinamento equipe (4h)
5. Go-live em 7 dias

### Rede de Clínicas
1. Workshop de discovery (1 dia)
2. Documentar processos por unidade
3. Configurar multi-tenant
4. Piloto em 1 unidade
5. Rollout gradual
6. Go-live total em 30-60 dias

---

**Versão do Documento**: 1.0  
**Última Atualização**: 03-01-2026  
**Classificação**: Proprietário e Confidencial

