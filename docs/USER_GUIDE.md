# Guia do Usuário

> **Documentação Proprietária**  
> Copyright © 2026. Todos os Direitos Reservados.  
> Este documento é confidencial e destinado apenas a clientes autorizados.

---

## Visão Geral

Este guia foi elaborado para **Gerentes de Clínicas** e **Equipe Administrativa** que operarão o Sistema Multi-Agente de Gestão de Clínicas no dia a dia. Nenhum conhecimento técnico é necessário.

**O Que Você Pode Fazer**:
- Gerenciar configurações de tenant (clínica)
- Monitorar interações com pacientes
- Revisar logs de conversas
- Atualizar respostas de FAQ
- Lidar com casos escalonados
- Ler relatórios do Telegram
- Integrar novas instâncias de clínicas

---

## Sumário

1. [Começando](#começando)
2. [Gerenciando Configuração da Clínica](#gerenciando-configuração-da-clínica)
3. [Monitorando Interações com Pacientes](#monitorando-interações-com-pacientes)
4. [Gerenciando Respostas de FAQ](#gerenciando-respostas-de-faq)
5. [Usando Relatórios do Telegram](#usando-relatórios-do-telegram)
6. [Integrando uma Nova Clínica](#integrando-uma-nova-clínica)
7. [Resolvendo Problemas Comuns](#resolvendo-problemas-comuns)

---

## Começando

### Acessando o Sistema

Você tem duas interfaces principais:

| Interface | Propósito | Método de Acesso |
|-----------|-----------|------------------|
| **UI Web n8n** | Visualizar workflows, logs, configurações | Navegador: `https://seu-dominio.com` |
| **Bot Telegram** | Comandos internos e notificações | App Telegram: `@SeuBotClinica` |

### Primeiro Login (n8n)

1. Abra o navegador e navegue até sua URL do n8n
2. Entre com as credenciais fornecidas pela equipe de TI:
   - **Usuário**: `admin` (ou personalizado)
   - **Senha**: Fornecida separadamente
3. Você verá o dashboard do n8n com a lista de workflows

### Configuração do Telegram

1. Abra o app Telegram
2. Pesquise por seu bot (ex: `@ClinicaExemploBot`)
3. Envie `/start` para inicializar
4. O bot responderá com mensagem de boas-vindas

---

## Gerenciando Configuração da Clínica

### Visualizando Configuração Atual

**Opção 1: Via SQL (Equipe de TI)**

Peça à sua equipe de TI para executar:
```sql
SELECT tenant_id, tenant_name, evolution_instance_name, is_active
FROM tenant_config
ORDER BY tenant_name;
```

**Opção 2: Via UI do n8n**

1. Vá para **Workflows** → **Tenant Config Loader**
2. Clique em **Execute**
3. Visualize os dados do tenant na saída da execução

### Atualizando Informações da Clínica

Atualizações comuns que você pode precisar:

#### Atualizar Horários da Clínica

```sql
-- Sua equipe de TI executará isso, mas você fornece os valores:
UPDATE tenant_config
SET 
    hours_start = '09:00',
    hours_end = '18:00',
    days_open = 'Segunda-Sexta'
WHERE tenant_name = 'Clínica Exemplo';
```

#### Atualizar Endereço/Telefone da Clínica

```sql
UPDATE tenant_config
SET 
    clinic_address = 'Rua Nova, 456 - São Paulo, SP',
    clinic_phone = '+55 11 99999-8888'
WHERE tenant_name = 'Clínica Exemplo';
```

#### Atualizar System Prompts (Comportamento da IA)

Isso controla como o bot de IA responde aos pacientes:

```sql
UPDATE tenant_config
SET system_prompt_patient = '
Você é o assistente virtual da Clínica Exemplo.
Seja cordial e profissional.
Horário de atendimento: Segunda a Sexta, 9h às 18h.
Endereço: Rua Nova, 456 - São Paulo, SP.
Telefone: (11) 99999-8888.
'
WHERE tenant_name = 'Clínica Exemplo';
```

**Peça à sua equipe de TI para executar esses comandos SQL.**

---

## Monitorando Interações com Pacientes

### Visualizando Logs de Conversa

**Método 1: Painel de Execuções do n8n**

1. Abra a UI do n8n
2. Clique em **Executions** na barra lateral esquerda
3. Filtre por workflow: `01 - WhatsApp Patient Handler`
4. Clique em qualquer execução para ver:
   - Mensagem do paciente
   - Resposta do bot
   - Se IA foi usada ou houve acerto no cache FAQ
   - Tempo de execução
   - Quaisquer erros

**Entendendo Status de Execução**:
- 🟢 **Sucesso**: Mensagem processada e respondida
- 🔴 **Erro**: Algo deu errado (verifique workflow de erros)
- ⏸️ **Executando**: Processando no momento (raro, < 3 segundos)

### Padrões Comuns de Execução

#### Acerto no Cache FAQ (Rápido, Barato)

```
Parse Webhook Data → Load Tenant Config → Intent Classifier → Check FAQ Cache [ACERTO]
→ Use FAQ Answer → Send WhatsApp Response

Tempo de Execução: 50-200ms
Custo: ~$0.001
```

#### Processamento IA (Mais Lento, Mais Caro)

```
Parse Webhook Data → Load Tenant Config → Intent Classifier → Check FAQ Cache [ERRO]
→ Patient Assistant Agent → AI Processing → Calendar Check → Send Response

Tempo de Execução: 1.5-3s
Custo: ~$0.012
```

### Dashboard de Monitoramento (Manual)

Crie uma rotina simples de monitoramento:

**Verificação Diária (5 minutos)**:
1. Abra o painel **Executions**
2. Filtre "Últimas 24 horas"
3. Verifique execuções vermelhas (erro)
4. Note quaisquer padrões (mesmo erro várias vezes)

**Revisão Semanal (15 minutos)**:
1. Conte o total de execuções
2. Calcule a taxa de erro: `(erros / total) * 100`
3. Meta: < 1% taxa de erro
4. Revise a taxa de acerto do cache FAQ (veja seção FAQ)

---

## Gerenciando Respostas de FAQ

### Entendendo o Cache FAQ

O sistema aprende automaticamente com as conversas e cacheia perguntas frequentes para economizar tempo e dinheiro.

**Como funciona**:
1. Paciente pergunta: "Qual o horário?"
2. IA processa e responde
3. Sistema cacheia: Pergunta + Resposta
4. Próximo paciente faz a mesma pergunta → Resposta instantânea do cache!

### Visualizando FAQs Atuais

Peça à sua equipe de TI para executar:

```sql
SELECT 
    question_original,
    answer,
    view_count,
    last_used_at
FROM tenant_faq
WHERE tenant_id = 'seu-tenant-id'
ORDER BY view_count DESC
LIMIT 20;
```

Exemplo de saída:
```
question                          | view_count | last_used_at
----------------------------------|------------|------------------
Qual o horário de funcionamento?  | 45         | 2026-01-15 14:30
Qual o endereço da clínica?       | 32         | 2026-01-15 15:10
Como faço para agendar?           | 28         | 2026-01-15 13:45
```

### Atualizando Respostas de FAQ

Se uma resposta em cache está desatualizada:

```sql
-- Atualizar FAQ específico
UPDATE tenant_faq
SET 
    answer = 'Nosso NOVO horário é: Segunda a Sexta, 9h às 18h.',
    updated_at = NOW()
WHERE 
    tenant_id = 'seu-tenant-id'
    AND question_normalized ILIKE '%horário%';
```

### Adicionando Novas FAQs Manualmente

Para informações importantes que você quer cachear imediatamente:

```sql
INSERT INTO tenant_faq (
    tenant_id,
    question_original,
    question_normalized,
    answer,
    keywords,
    intent
) VALUES (
    'seu-tenant-id',
    'Vocês atendem convênio?',
    'vocês atendem convênio?',
    'Sim! Atendemos os seguintes convênios:\n- Unimed\n- Bradesco Saúde\n- SulAmérica\n\nPor favor, confirme a cobertura antes da consulta.',
    ARRAY['convênio', 'plano', 'aceita'],
    'insurance'
);
```

### Excluindo FAQs Desatualizadas

```sql
-- Excluir FAQ específico
DELETE FROM tenant_faq
WHERE faq_id = 'id-faq-especifico';

-- Ou excluir por pergunta
DELETE FROM tenant_faq
WHERE 
    tenant_id = 'seu-tenant-id'
    AND question_normalized ILIKE '%pergunta antiga%';
```

### Métricas de Performance do FAQ

**Taxa de Acerto do Cache** (Meta: > 60%):

```sql
-- Sua equipe de TI pode criar um dashboard mostrando isso
SELECT 
    COUNT(*) FILTER (WHERE source = 'cache') * 100.0 / COUNT(*) as taxa_acerto_cache_porcento
FROM message_logs
WHERE created_at > NOW() - INTERVAL '7 days';
```

**Top 10 FAQs**:

```sql
SELECT 
    question_original,
    view_count,
    ROUND(view_count * 100.0 / SUM(view_count) OVER(), 2) as porcentagem
FROM tenant_faq
WHERE tenant_id = 'seu-tenant-id'
ORDER BY view_count DESC
LIMIT 10;
```

---

## Usando Relatórios do Telegram

### Comandos Disponíveis

Envie estes comandos para seu bot Telegram:

| Comando | Descrição | Exemplo |
|---------|-----------|---------|
| `Próximas consultas` | Listar agendamentos futuros | "Mostre as consultas de hoje" |
| `Remarcar João para 14h` | Reagendar consulta | Bot atualizará o Google Calendar |
| `Adicionar à lista: algodão` | Adicionar à lista de compras | Cria Google Task |
| `Cancelar consulta de Maria` | Cancelar agendamento | Bot confirmará |

### Entendendo Respostas do Bot

#### Comando Bem-sucedido

```
✅ Consulta remarcada com sucesso!

📋 Detalhes:
Paciente: João Silva
Nova Data: 15/01/2026 às 14:00
Telefone: (11) 98765-4321

🔔 WhatsApp enviado ao paciente confirmando a mudança.
```

#### Resposta de Erro

```
❌ Erro ao processar comando

⚠️ Não encontrei consulta para "Maria" hoje.

💡 Sugestão: Tente especificar a data:
"Cancelar consulta de Maria do dia 20/01"
```

### Notificações de Escalonamento

Quando um caso de paciente é escalonado (urgente/complexo), você receberá:

```
🚨 ESCALONAMENTO DE ATENDIMENTO

👤 Paciente: Ana Souza
📱 Telefone: (11) 99999-8888
📝 Última mensagem: "Estou com muita dor, preciso de consulta urgente!"

⏰ Horário: 15/01/2026 14:35

🔗 Ver conversa completa: [Link para execução n8n]
```

**Ação Necessária**:
1. Contate o paciente diretamente por telefone
2. Agende consulta de emergência
3. Informe o bot: "Atendido - Ana Souza agendada para 16h"

### Relatório Diário de Resumo

Você receberá automaticamente às 8h todos os dias:

```
📊 RELATÓRIO DIÁRIO - 15/01/2026

📅 Consultas Hoje: 12
  ✅ Confirmadas: 10
  ⏳ Pendentes: 2
  ❌ Canceladas: 0

💬 Mensagens Recebidas: 45
  🤖 Respondidas por IA: 12 (27%)
  ⚡ Cache FAQ: 33 (73%)
  🚨 Escalonadas: 0

📈 Performance:
  Tempo médio de resposta: 0.8s
  Taxa de erro: 0%
  Satisfação: 98% (baseado em confirmações)

🔝 Perguntas Mais Frequentes:
1. Horário de funcionamento (15x)
2. Endereço da clínica (12x)
3. Como agendar consulta (10x)
```

---

## Integrando uma Nova Clínica

### Checklist de Pré-requisitos

Antes de integrar uma nova clínica, colete:

- [ ] **Nome da Clínica**: Nome completo legal
- [ ] **Endereço da Clínica**: Endereço completo
- [ ] **Telefone da Clínica**: Número WhatsApp Business
- [ ] **ID do Google Calendar**: Para gerenciamento de agendamentos
- [ ] **ID da Lista Google Tasks**: Para tarefas internas
- [ ] **Bot Telegram**: Chat ID para notificações internas
- [ ] **Instância Evolution API**: Nome da instância (ex: `clinic_nova`)
- [ ] **System Prompts**: Comportamento personalizado da IA (opcional, use templates)

### Integração Passo a Passo

#### Passo 1: Solicitar Configuração de TI

Envie estas informações para sua equipe de TI:

```
Solicitação de Integração de Nova Clínica

Detalhes da Clínica:
- Nome: Clínica Nova Ltda
- Endereço: Rua Nova, 789 - Rio de Janeiro, RJ
- Telefone: +55 21 98765-4321
- Email: contato@clinicanoval.com.br

Horários:
- Segunda-Sexta: 8:00 - 19:00
- Sábado: 8:00 - 13:00
- Domingo: Fechado

Nome da Instância Evolution API: clinic_nova

ID do Google Calendar: clinic.nova@group.calendar.google.com
ID da Lista Google Tasks: [fornecer ID]
Chat ID do Telegram: [fornecer ID]
```

#### Passo 2: Equipe de TI Executa SQL

Sua equipe de TI executará via SQL:

```sql
INSERT INTO tenant_config (
    tenant_name,
    evolution_instance_name,
    clinic_name,
    clinic_address,
    clinic_phone,
    clinic_email,
    google_calendar_id,
    google_tasks_list_id,
    telegram_internal_chat_id,
    hours_start,
    hours_end,
    days_open,
    operating_days,
    system_prompt_patient,
    system_prompt_internal,
    system_prompt_confirmation
) VALUES (
    'Clínica Nova',
    'clinic_nova',
    'Clínica Nova Ltda',
    'Rua Nova, 789 - Rio de Janeiro, RJ',
    '+55 21 98765-4321',
    'contato@clinicanoval.com.br',
    'clinic.nova@group.calendar.google.com',
    'seu-tasks-list-id',
    'seu-telegram-chat-id',
    '08:00',
    '19:00',
    'Segunda-Sábado',
    '["1","2","3","4","5","6"]',
    'Você é o assistente da Clínica Nova. Horário: Seg-Sex 8h-19h, Sáb 8h-13h. Endereço: Rua Nova, 789 - RJ. Telefone: (21) 98765-4321.',
    'Você é o assistente interno da Clínica Nova para gerenciar agenda via Telegram.',
    'Você é o agente de confirmação da Clínica Nova. Envie lembretes 24h antes das consultas.'
);
```

#### Passo 3: Configurar Evolution API

No dashboard da Evolution API:

1. Crie nova instância: `clinic_nova`
2. Configure webhook: `https://seu-dominio.com/webhook/whatsapp-webhook`
3. Conecte o número WhatsApp via QR code
4. Teste: Envie "Oi" para o número

#### Passo 4: Seed de FAQs Iniciais

```sql
-- FAQs comuns para nova clínica
INSERT INTO tenant_faq (tenant_id, question_original, question_normalized, answer, keywords, intent)
VALUES 
    ((SELECT tenant_id FROM tenant_config WHERE evolution_instance_name = 'clinic_nova'),
     'Qual o horário?',
     'qual o horário?',
     'Nosso horário de atendimento:\n*Segunda a Sexta*: 8h às 19h\n*Sábado*: 8h às 13h\n*Domingo*: Fechado',
     ARRAY['horário', 'hora', 'funcionamento'],
     'hours'),
    
    ((SELECT tenant_id FROM tenant_config WHERE evolution_instance_name = 'clinic_nova'),
     'Qual o endereço?',
     'qual o endereço?',
     'Estamos localizados em:\n*Rua Nova, 789 - Rio de Janeiro, RJ*\n\nQualquer dúvida, ligue: (21) 98765-4321',
     ARRAY['endereço', 'localização', 'onde'],
     'location');
```

#### Passo 5: Testar e Verificar

**Checklist de Testes**:

1. **Teste WhatsApp**:
   - [ ] Envie "Oi" → Receba saudação
   - [ ] Pergunte "Qual o horário?" → Receba horários (do cache)
   - [ ] Solicite agendamento → IA processa + verifica calendário

2. **Teste Telegram**:
   - [ ] Envie comando → Bot responde
   - [ ] Verifique relatório diário recebido às 8h

3. **Integração com Calendário**:
   - [ ] Crie agendamento teste no Google Calendar
   - [ ] Verifique se paciente recebe confirmação

4. **Tratamento de Erros**:
   - [ ] Envie input inválido → Mensagem de erro amigável
   - [ ] Verifique se workflow de erros registrou o problema

#### Passo 6: Treinamento e Transição

1. **Treinar Equipe da Clínica**:
   - Mostrar como usar o bot Telegram
   - Explicar processo de escalonamento
   - Revisar relatórios diários

2. **Fornecer Documentação**:
   - Este Guia do Usuário
   - Contato de emergência (sua equipe de TI)
   - Referência rápida de resolução de problemas

3. **Monitorar Primeira Semana**:
   - Verificar execuções diariamente
   - Revisar cache FAQ sendo construído
   - Ajustar prompts se necessário

---

## Resolvendo Problemas Comuns

### Bot Não Responde ao WhatsApp

**Sintomas**: Paciente envia mensagem, sem resposta do bot

**Diagnóstico**:
1. Verifique painel de Execuções do n8n para erros
2. Verifique se instância Evolution API está conectada
3. Verifique configuração do webhook

**Soluções**:
- **Se nenhuma execução registrada**: Webhook não está chegando ao n8n
  - Verifique se URL do webhook na Evolution API está correta
  - Verifique configurações de firewall/rede (equipe de TI)
  
- **Se execução mostra erro**: Verifique a mensagem de erro
  - "Unknown instance": Tenant não configurado corretamente
  - "AI API error": Problema com chave API do Google Gemini (equipe de TI)
  - "Database error": Contate equipe de TI

### Bot Fornecendo Informação Errada

**Sintomas**: Respostas do bot têm info desatualizada (horários, endereço, etc.)

**Solução**:
1. Atualize configuração do tenant (veja [Gerenciando Configuração da Clínica](#gerenciando-configuração-da-clínica))
2. Atualize ou exclua FAQs em cache (veja [Gerenciando Respostas de FAQ](#gerenciando-respostas-de-faq))
3. Verifique se system prompts estão atualizados

### Bot Telegram Não Envia Relatórios

**Sintomas**: Relatório diário não recebido às 8h

**Diagnóstico**:
1. Verifique se workflow `03-appointment-confirmation-scheduler` está **Ativo**
2. Verifique se trigger de agendamento está configurado corretamente

**Solução**:
- Peça à equipe de TI para verificar ativação do workflow
- Verifique se chat ID do Telegram está correto na config do tenant

### Custos de IA Altos

**Sintomas**: Conta mensal maior que o esperado

**Diagnóstico**:
```sql
-- Verificar taxa de acerto do cache FAQ
SELECT 
    COUNT(*) FILTER (WHERE source = 'cache') * 100.0 / COUNT(*) as taxa_acerto_cache
FROM message_logs
WHERE created_at > NOW() - INTERVAL '30 days';
```

**Soluções**:
- Se taxa de acerto do cache < 50%: Adicione mais FAQs manualmente
- Revise perguntas comuns nos logs e pré-cachear respostas
- Atualize system prompts para serem mais concisos

### Escalonamento de Paciente Não Funciona

**Sintomas**: Caso urgente não sinalizado no Telegram

**Diagnóstico**:
1. Verifique se workflow de ferramenta de escalonamento está ativo
2. Verifique se chat ID do Telegram está correto
3. Revise logs de execução para tentativas de escalonamento

**Solução**:
- Atualize `telegram_internal_chat_id` na config do tenant
- Teste manualmente: Envie "Urgente" para o bot
- Verifique se token do bot Telegram é válido (equipe de TI)

---

## Melhores Práticas

### Para Gerentes de Clínica

1. **Revise Relatórios Diários**: Gaste 5 minutos cada manhã revisando o resumo do Telegram
2. **Monitore Cache FAQ**: Verificação semanal das perguntas mais populares
3. **Atualize Informações Prontamente**: Quando horários/endereço mudarem, atualize no mesmo dia
4. **Treine a Equipe**: Garanta que todos saibam como usar comandos do Telegram
5. **Responda a Escalonamentos**: Mire em tempo de resposta < 30 minutos

### Para Gerenciamento de FAQ

1. **Seed de FAQs Importantes**: Não espere a IA aprender - adicione manualmente
2. **Mantenha Respostas Concisas**: Usuários WhatsApp preferem respostas curtas e claras
3. **Use Formatação**: Use `*negrito*` para ênfase, listas para clareza
4. **Teste Antes de Salvar**: Envie mensagem de teste para verificar qualidade da resposta
5. **Revise Mensalmente**: Exclua FAQs não usadas (< 3 visualizações em 90 dias)

### Para Operações Multi-Clínica

1. **Padronize Onde Possível**: Use prompts similares entre clínicas
2. **Compartilhe Aprendizados**: Se FAQ funciona bem para Clínica A, adicione à Clínica B
3. **Monitore Comparativamente**: Compare taxas de acerto de cache, taxas de erro
4. **Documente Variações**: Anote por que Clínica A opera diferentemente
5. **Centralize Atualizações**: Uma pessoa responsável por atualizações multi-clínica

---

## Apêndice: Referência Rápida

### Queries SQL Comuns

```sql
-- Listar todos os tenants
SELECT tenant_name, evolution_instance_name, is_active 
FROM tenant_config;

-- Atualizar horários da clínica
UPDATE tenant_config SET hours_start = 'HH:MM', hours_end = 'HH:MM' 
WHERE tenant_name = 'Sua Clínica';

-- Ver top FAQs
SELECT question_original, view_count 
FROM tenant_faq 
WHERE tenant_id = 'seu-id' 
ORDER BY view_count DESC 
LIMIT 10;

-- Adicionar novo FAQ
INSERT INTO tenant_faq (tenant_id, question_original, question_normalized, answer, keywords)
VALUES ('seu-id', 'Pergunta?', 'pergunta?', 'Resposta aqui', ARRAY['palavra1', 'palavra2']);
```

### Exemplos de Comandos Telegram

```
# Agendamentos
Próximas consultas de hoje
Remarcar João Silva para amanhã 15h
Cancelar consulta de Maria do dia 20

# Tarefas
Adicionar à lista: comprar algodão
Adicionar à lista: imprimir receituários
Mostrar lista de compras

# Relatórios
Relatório de hoje
Consultas da semana
```

### Contatos de Emergência

| Problema | Contato | Método |
|----------|---------|--------|
| Sistema Fora do Ar | Suporte TI | Email: ti@exemplo.com |
| Bug Urgente | Engenheiro de Plantão | Telefone: +XX XX XXXX-XXXX |
| Dúvida de Treinamento | Customer Success | suporte@exemplo.com |
| Faturamento/Licença | Equipe de Vendas | vendas@exemplo.com |

---

**Versão do Documento**: 1.0  
**Última Atualização**: 01-01-2026  
**Classificação**: Proprietário e Confidencial

**Precisa de Ajuda?**  
Entre em contato com suporte@sua-empresa.com com sua chave de licença.
