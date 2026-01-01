# 🚀 Checklist de Implantação em Produção

## Fase Pré-Implantação

### 1. Configuração do Ambiente
- [ ] Servidor provisionado (mín 2 CPUs, 4GB RAM, 20GB armazenamento)
- [ ] Domínio configurado com certificado SSL
- [ ] Regras de firewall configuradas (portas 80, 443, 5678, 8080)
- [ ] Docker e Docker Compose instalados (v20.10+, v2.0+)
- [ ] Repositório clonado no servidor

### 2. Configuração de Variáveis de Ambiente
- [ ] Copiar `env.production.example` para `.env`
- [ ] Gerar todos os segredos usando `openssl rand -base64 32`
- [ ] Preencher todos os campos `<REQUIRED>` no `.env`
- [ ] **CRÍTICO**: Fazer backup da `N8N_ENCRYPTION_KEY` em local offline seguro
- [ ] Verificar se as credenciais do banco de dados são fortes
- [ ] Definir `N8N_WEBHOOK_URL` correto com domínio público
- [ ] Configurar informações comerciais da clínica
- [ ] Definir endpoints MCP
- [ ] Testar se todas as variáveis de ambiente estão exportadas corretamente

### 3. Configuração de Serviços Externos

#### Serviços Google
- [ ] API do Google Calendar habilitada
- [ ] ID do Calendar obtido e adicionado ao `.env`
- [ ] API do Google Tasks habilitada
- [ ] ID da lista de Tasks obtido e adicionado ao `.env`
- [ ] Chave API do Google Gemini gerada
- [ ] Testar cota e limites da API Gemini

#### Bot do Telegram
- [ ] Bot criado via @BotFather
- [ ] Token do bot salvo no `.env`
- [ ] ID do chat interno obtido via @userinfobot
- [ ] Testar se o bot responde a mensagens

#### Evolution API (WhatsApp)
- [ ] Instância da Evolution API implantada ou serviço contratado
- [ ] Chave API gerada
- [ ] URL base configurada no `.env`
- [ ] Nome da instância definido

### 4. Inicialização do Banco de Dados
- [ ] Revisar `scripts/init-db.sh` para customizações
- [ ] Garantir que o script de inicialização do PostgreSQL seja executável
- [ ] Planejar estratégia de backup

## Fase de Implantação

### 5. Serviços Docker
```bash
# Iniciar todos os serviços
docker-compose up -d

# Verificar se todos os serviços estão saudáveis
docker-compose ps

# Verificar logs em busca de erros
docker-compose logs -f
```

- [ ] PostgreSQL iniciado e saudável
- [ ] Redis iniciado e saudável
- [ ] Evolution API iniciada e saudável
- [ ] n8n iniciado e saudável
- [ ] Sem erros nos logs

### 6. Configuração do n8n

#### Configuração Inicial
- [ ] Acessar interface do n8n em `https://seudominio.com:5678`
- [ ] Criar conta de administrador (senha forte!)
- [ ] Configurar preferências do usuário

#### Configuração de Credenciais
Importar e configurar estas credenciais no n8n:

- [ ] **Evolution API**
  - Nome: "Evolution API"
  - URL: `${EVOLUTION_BASE_URL}`
  - Chave API: `${EVOLUTION_API_KEY}`
  - Testar conexão

- [ ] **Google Calendar OAuth2**
  - Nome: "Google Calendar"
  - Configurar app OAuth2
  - Autorizar e testar

- [ ] **Google Tasks OAuth2**
  - Nome: "Google Tasks account"
  - Configurar app OAuth2
  - Autorizar e testar

- [ ] **Google Gemini API**
  - Nome: "Google Gemini API"
  - Chave API: `${GOOGLE_GEMINI_API_KEY}`
  - Testar com requisição de exemplo

- [ ] **Bot do Telegram**
  - Nome: "Telegram Bot"
  - Token do Bot: `${TELEGRAM_BOT_TOKEN}`
  - Testar enviando mensagem

- [ ] **PostgreSQL** (se usar para memória de workflows)
  - Host: `postgres`
  - Porta: `5432`
  - Banco de dados, usuário, senha do `.env`
  - Testar conexão

#### Importação de Workflows

**Ordem de Importação (IMPORTANTE!):**

1. **Workflows de Ferramentas Primeiro** (workflows/tools/):
   - [ ] `communication/whatsapp-send-tool.json`
   - [ ] `communication/telegram-notify-tool.json`
   - [ ] `communication/message-formatter-tool.json`
   - [ ] `ai-processing/audio-transcription-tool.json`
   - [ ] `ai-processing/image-ocr-tool.json`
   - [ ] `calendar/mcp-calendar-tool.json`
   - [ ] `escalation/call-to-human-tool.json`

2. **Manipulador de Erros** (workflows/main/):
   - [ ] `04-error-handler.json`
   - [ ] Copiar ID do workflow e adicionar ao `.env` como `ERROR_WORKFLOW_ID`
   - [ ] Ativar workflow

3. **Workflows Principais** (workflows/main/):
   - [ ] `01-whatsapp-patient-handler.json`
   - [ ] `02-telegram-internal-assistant.json`
   - [ ] `03-appointment-confirmation-scheduler.json`

4. **Workflow de Teste** (opcional - tests/):
   - [ ] `mock-test-workflow.json`

#### Configurar Workflows

Para cada workflow:
- [ ] Revisar todos os nós em busca de IDs de credenciais temporários
- [ ] Substituir `{{CREDENTIAL_ID}}` pelos IDs reais de credenciais do n8n
- [ ] Atualizar mensagens do sistema com variáveis de ambiente corretas
- [ ] Verificar se todos os nós "Execute Workflow" apontam para workflows corretos
- [ ] Verificar se workflow de erro está configurado nas definições

### 7. Conexão WhatsApp da Evolution API
- [ ] Acessar interface da Evolution API
- [ ] Criar instância com nome do `.env`
- [ ] Escanear código QR com WhatsApp
- [ ] Verificar se status da conexão está "open"
- [ ] Configurar webhook para apontar ao n8n:
  ```
  Webhook URL: https://seudominio.com:5678/webhook/whatsapp-webhook
  Eventos: messages.upsert
  ```
- [ ] Testar enviando mensagem para o número WhatsApp conectado

## Fase de Testes

### 8. Testes Manuais

#### Teste 1: Mensagem de Texto WhatsApp
```bash
curl -X POST https://seudominio.com:5678/webhook/whatsapp-webhook \
  -H "Content-Type: application/json" \
  -d @tests/sample-payloads/text-message.json
```
- [ ] Webhook recebe mensagem
- [ ] Agente processa e responde
- [ ] Mensagem enviada de volta via WhatsApp
- [ ] Sem erros no log de execução

#### Teste 2: Assistente Interno Telegram
- [ ] Enviar mensagem para o bot do Telegram
- [ ] Bot responde apropriadamente
- [ ] Pode acessar calendário
- [ ] Pode adicionar à lista de compras

#### Teste 3: Confirmação de Consulta (Gatilho Manual)
- [ ] Disparar manualmente workflow de confirmação
- [ ] Verifica consultas de amanhã
- [ ] Envia mensagens de confirmação
- [ ] Registra resultados corretamente

#### Teste 4: Manipulador de Erros
- [ ] Causar erro intencional em um workflow
- [ ] Verificar se alerta do Telegram é recebido
- [ ] Verificar se detalhes do erro estão completos
- [ ] Confirmar mensagem de fallback enviada ao paciente (se aplicável)

### 9. Suíte de Testes Automatizada
- [ ] Importar `tests/mock-test-workflow.json`
- [ ] Executar workflow de teste
- [ ] Verificar se todos os cenários passam
- [ ] Verificar se taxa de sucesso é 100%
- [ ] Revisar resumo de resultados do teste no Telegram

### 10. Testes End-to-End

Cenários do mundo real:
- [ ] **Cenário 1**: Paciente real agenda consulta via WhatsApp
  - Enviar mensagem real
  - Verificar evento criado no calendário
  - Verificar confirmação enviada

- [ ] **Cenário 2**: Equipe reagenda via Telegram
  - Enviar comando de reagendamento
  - Verificar calendário atualizado
  - Verificar paciente notificado

- [ ] **Cenário 3**: Confirmação diária executa
  - Aguardar gatilho das 8h ou disparar manualmente
  - Verificar confirmações enviadas a todos os pacientes
  - Verificar que não há duplicatas

- [ ] **Cenário 4**: Processamento de mensagem de áudio
  - Enviar mensagem de voz
  - Verificar se transcrição funciona
  - Verificar se agente responde apropriadamente

- [ ] **Cenário 5**: OCR de Imagem
  - Enviar imagem de receita
  - Verificar se OCR extrai texto
  - Verificar se agente interpreta corretamente

- [ ] **Cenário 6**: Escalonamento
  - Enviar mensagem urgente
  - Verificar equipe alertada via Telegram
  - Verificar paciente recebe confirmação

## Endurecimento de Produção

### 11. Endurecimento de Segurança
- [ ] Alterar todas as senhas padrão
- [ ] Verificar se regras de firewall são restritivas
- [ ] Habilitar SSL/TLS para todos os serviços
- [ ] Desabilitar portas desnecessárias
- [ ] Configurar fail2ban ou similar
- [ ] Configurar acesso VPN para interfaces admin
- [ ] Revisar e restringir exposição da rede Docker
- [ ] Habilitar varredura de segurança do Docker
- [ ] Revisar logs em busca de atividade suspeita

### 12. Configuração de Monitoramento
- [ ] Configurar monitoramento de health check (UptimeRobot, Pingdom, etc.)
- [ ] Configurar agregação de logs (se usar ELK, Loki, etc.)
- [ ] Configurar alertas do Telegram para erros críticos
- [ ] Configurar monitoramento de espaço em disco
- [ ] Configurar alertas de memória/CPU
- [ ] Habilitar monitoramento de endpoint de métricas do n8n
- [ ] Configurar monitoramento de performance do banco de dados

### 13. Configuração de Backup
- [ ] Backups automatizados do banco de dados configurados
- [ ] Política de retenção de backup definida (30 dias recomendado)
- [ ] Testar procedimento de restauração do banco de dados
- [ ] Fazer backup de workflows n8n para repositório git
- [ ] **CRÍTICO**: Backup offline da `N8N_ENCRYPTION_KEY`
- [ ] Documentar localizações de backup
- [ ] Agendar testes de backup (mensal)

### 14. Otimização de Performance
- [ ] Revisar tempos de execução no n8n
- [ ] Otimizar workflows lentos
- [ ] Configurar cache Redis apropriadamente
- [ ] Definir valores de timeout apropriados
- [ ] Monitorar limites de taxa da Evolution API
- [ ] Revisar e ajustar limites de recursos
- [ ] Habilitar CDN para assets estáticos (se aplicável)

## Pós-Implantação

### 15. Documentação
- [ ] Documentar todas as credenciais e suas localizações
- [ ] Criar runbook para operações comuns
- [ ] Documentar procedimentos de emergência
- [ ] Criar lista de contatos para escalonamentos
- [ ] Atualizar README com URLs de produção
- [ ] Documentar quaisquer configurações customizadas

### 16. Treinamento
- [ ] Treinar equipe no uso do bot do Telegram
- [ ] Documentar fluxos de interação com pacientes
- [ ] Criar guia de solução de problemas para equipe
- [ ] Conduzir simulação com equipe

### 17. Cronograma de Monitoramento e Manutenção

**Diariamente:**
- [ ] Verificar logs de erro
- [ ] Verificar se confirmação diária executou
- [ ] Monitorar taxas de entrega de mensagens

**Semanalmente:**
- [ ] Revisar performance de execução
- [ ] Verificar uso de espaço em disco
- [ ] Revisar logs de segurança
- [ ] Atualizar documentação se necessário

**Mensalmente:**
- [ ] Atualizar imagens Docker
- [ ] Revisar e rotacionar logs
- [ ] Testar restauração de backup
- [ ] Auditoria de segurança
- [ ] Revisão de performance

**Trimestralmente:**
- [ ] Rotacionar segredos e senhas
- [ ] Revisar e atualizar dependências
- [ ] Simulação de recuperação de desastre
- [ ] Revisão de feedback dos usuários

## Entrada em Produção

### 18. Checklist Final Pré-Produção
- [ ] Todos os testes passando
- [ ] Todo monitoramento ativo
- [ ] Todos os backups configurados
- [ ] Toda documentação completa
- [ ] Equipe treinada
- [ ] Contatos de emergência confirmados
- [ ] Plano de rollback documentado

### 19. Execução da Entrada em Produção
- [ ] Anunciar janela de manutenção (se migrando de sistema antigo)
- [ ] Ativar todos os workflows principais
- [ ] Monitorar de perto pelas primeiras 24 horas
- [ ] Ter engenheiro de plantão disponível
- [ ] Documentar quaisquer problemas encontrados

### 20. Pós-Entrada em Produção
- [ ] Enviar mensagens de teste para verificar sistema
- [ ] Monitorar intensivamente por 1 semana
- [ ] Coletar feedback dos usuários
- [ ] Resolver quaisquer problemas prontamente
- [ ] Celebrar implantação bem-sucedida! 🎉

## Procedimento de Rollback

Se problemas críticos ocorrerem:

1. **Ações Imediatas:**
   - [ ] Desativar workflows problemáticos no n8n
   - [ ] Alertar usuários via Telegram/WhatsApp
   - [ ] Mudar para operações manuais

2. **Diagnóstico:**
   - [ ] Revisar logs de erro
   - [ ] Verificar status de serviços externos
   - [ ] Verificar credenciais e configurações

3. **Corrigir ou Reverter:**
   - [ ] Aplicar correção se identificada rapidamente
   - [ ] Caso contrário, restaurar do último backup bom conhecido
   - [ ] Reverter para versão anterior se necessário

4. **Post-Mortem:**
   - [ ] Documentar o que deu errado
   - [ ] Identificar causa raiz
   - [ ] Atualizar checklist de implantação
   - [ ] Planejar medidas preventivas

## Contatos de Emergência

```
Engenheiro DevOps: [NOME] - [TELEFONE] - [EMAIL]
Administrador de Sistemas: [NOME] - [TELEFONE] - [EMAIL]
Administrador de Banco de Dados: [NOME] - [TELEFONE] - [EMAIL]
Gerente da Clínica: [NOME] - [TELEFONE] - [EMAIL]

Suporte Externo:
- Suporte Evolution API: [CONTATO]
- Provedor de Hospedagem: [CONTATO]
- Comunidade n8n: https://community.n8n.io
```

## Notas

- Este checklist deve ser revisado e atualizado após cada implantação
- Mantenha uma cópia deste checklist para cada implantação com datas de conclusão
- Documente quaisquer desvios deste checklist
- Use isto como documento vivo - melhore continuamente

---

**Data de Implantação:** _______________  
**Implantado Por:** _______________  
**Versão:** _______________  
**Ambiente:** Produção  

**Aprovação:**
- Engenheiro DevOps: _______________ Data: _______________
- Administrador de Sistemas: _______________ Data: _______________
- Gerente da Clínica: _______________ Data: _______________
