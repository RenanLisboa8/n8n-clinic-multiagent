# Guia de Testes

## Visão Geral
Este diretório contém workflows de teste e payloads de exemplo para validar o Sistema Multi-Agente de Gestão de Clínicas.

## Conteúdo

### Workflows de Teste
- **`mock-test-workflow.json`** - Suíte de testes automatizada que simula interações com pacientes

### Payloads de Exemplo
- **`text-message.json`** - Mensagem de texto de exemplo do WhatsApp
- **`audio-message.json`** - Payload de mensagem de áudio de exemplo
- **`image-message.json`** - Mensagem de imagem de exemplo com legenda

## Executando Testes

### Método 1: Usando o Workflow de Teste Mock

1. Importar `mock-test-workflow.json` para o n8n
2. Garantir que todos os workflows principais estejam ativos
3. Clicar em "Executar Workflow" na interface do n8n
4. Verificar Telegram para resumo dos resultados dos testes

### Método 2: Usando cURL com Payloads de Exemplo

Testar tipos individuais de mensagem:

```bash
# Testar mensagem de texto
curl -X POST http://localhost:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/text-message.json

# Testar mensagem de áudio
curl -X POST http://localhost:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/audio-message.json

# Testar mensagem de imagem
curl -X POST http://localhost:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/image-message.json
```

### Método 3: Ambiente de Teste Docker Compose

Executar testes em ambiente isolado:

```bash
# Iniciar todos os serviços
docker-compose up -d

# Aguardar serviços ficarem saudáveis
docker-compose ps

# Executar suíte de testes
docker-compose exec n8n n8n execute --id=<id-workflow-teste-mock>
```

## Cenários de Teste Cobertos

O workflow de teste mock inclui:

1. ✅ **Mensagem de Texto - Agendar Consulta** - Paciente solicita nova consulta
2. ✅ **Mensagem de Texto - Reagendar** - Paciente quer alterar consulta existente
3. ✅ **Mensagem de Texto - Cancelar** - Paciente cancela consulta
4. ✅ **Mensagem de Texto - Verificar Disponibilidade** - Paciente pergunta sobre horários disponíveis
5. ✅ **Mensagem de Áudio - Agendamento por Voz** - Paciente envia mensagem de voz
6. ✅ **Mensagem de Imagem - OCR de Receita** - Paciente envia imagem de receita
7. ✅ **Emergência - Gatilho de Escalonamento** - Mensagem urgente dispara escalonamento humano

## Comportamentos Esperados

### Resultados de Teste Bem-Sucedidos
- Todos os webhooks retornam HTTP 200
- Respostas do agente estão formatadas corretamente
- Operações de calendário executam sem erros
- Escalonamentos disparam alertas do Telegram
- Sem nós fantasma ou fluxos desconectados

### Problemas Comuns

**Webhook Não Encontrado (404)**
- Garantir que workflow Manipulador de Paciente WhatsApp está ativo
- Verificar se caminho do webhook corresponde à configuração

**Erros de Timeout**
- Aumentar `N8N_EXECUTIONS_TIMEOUT` no .env
- Verificar conectividade de API externa (Google, Evolution)

**Erros de Credencial**
- Verificar se todas as credenciais estão configuradas no n8n
- Verificar se IDs de credencial correspondem nos JSONs de workflow

## Checklist de Validação

Antes de implantar em produção:

- [ ] Todos os cenários de teste passam (taxa de sucesso de 100%)
- [ ] Tempos de resposta < 5 segundos em média
- [ ] Manipulador de erros dispara corretamente
- [ ] Notificações do Telegram chegam
- [ ] Mensagens WhatsApp são enviadas
- [ ] Eventos de calendário criados adequadamente
- [ ] Memória/contexto mantido entre mensagens
- [ ] Sem respostas duplicadas do agente
- [ ] Escalonamentos funcionam como esperado

## Integração Contínua

### Exemplo de GitHub Actions

```yaml
name: Testes de Workflow n8n

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Iniciar stack n8n
        run: docker-compose up -d
      - name: Aguardar saúde
        run: sleep 30
      - name: Executar testes
        run: |
          curl -f http://localhost:5678/healthz
          # Importar e executar workflow de teste
      - name: Limpeza
        run: docker-compose down
```

## Monitoramento de Resultados de Teste

Logs de execução de teste podem ser encontrados em:
- Interface do n8n: aba **Execuções**
- Telegram: Mensagens de resumo
- Logs do Docker: `docker-compose logs n8n`

## Adicionando Novos Testes

Para adicionar um novo cenário de teste:

1. Criar payload de exemplo em `sample-payloads/`
2. Adicionar cenário ao array de teste do `mock-test-workflow.json`
3. Documentar comportamento esperado
4. Executar e validar

## Benchmarks de Performance

Métricas alvo:
- Resposta do webhook: < 200ms
- Processamento do agente: < 3s
- Fluxo end-to-end: < 5s
- Taxa de sucesso: > 99%

## Suporte

Se os testes falharem inesperadamente:
1. Verificar saúde do serviço: `docker-compose ps`
2. Revisar logs: `docker-compose logs`
3. Verificar credenciais na interface do n8n
4. Verificar status de API externa
5. Consultar seção de solução de problemas do README.md principal
