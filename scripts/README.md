# 🛠️ Scripts de Gerenciamento

Este diretório contém scripts utilitários para gerenciar o Sistema Multi-Agente para Clínicas.

---

## 📦 Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `init-db.sh` | Inicializa o banco de dados PostgreSQL |
| `manage-tenants.sh` | Gerencia tenants (clínicas) no sistema |
| `import-workflows.sh` | **Importa todos os workflows de uma vez** |
| `add-copyright-headers.sh` | Adiciona headers de copyright aos arquivos |

---

## 📥 import-workflows.sh

### Descrição

Importa todos os workflows do projeto para uma instância n8n de uma só vez, eliminando a necessidade de importar manualmente cada arquivo JSON.

### Uso Básico

```bash
# Método padrão: via CLI Docker
./scripts/import-workflows.sh

# Especificar container personalizado
./scripts/import-workflows.sh --container meu_n8n

# Via API REST (alternativo)
./scripts/import-workflows.sh --api http://localhost:5678 --api-key SUA_CHAVE_API
```

### Opções

| Opção | Descrição | Padrão |
|-------|-----------|--------|
| `-c, --container NAME` | Nome do container Docker do n8n | `clinic_n8n` |
| `-u, --api URL` | URL da API do n8n | - |
| `-k, --api-key KEY` | Chave da API do n8n | - |
| `-d, --dir PATH` | Diretório dos workflows | `./workflows` |
| `-m, --method METHOD` | Método: `cli` ou `api` | `cli` |
| `-h, --help` | Mostra ajuda | - |

### Exemplos

```bash
# 1. Importação padrão (usa Docker CLI)
./scripts/import-workflows.sh

# 2. Container com nome diferente
./scripts/import-workflows.sh -c n8n_production

# 3. Via API REST
./scripts/import-workflows.sh \
  --api http://localhost:5678 \
  --api-key n8n_api_abc123xyz

# 4. Diretório customizado
./scripts/import-workflows.sh --dir /caminho/para/workflows
```

### O que é importado

O script importa automaticamente:

```
workflows/
├── main/                          ← Workflows principais
│   ├── 01-whatsapp-patient-handler-*.json
│   ├── 02-telegram-internal-assistant-*.json
│   ├── 03-appointment-confirmation-scheduler.json
│   └── 04-error-handler.json
├── sub/                           ← Sub-workflows
│   └── tenant-config-loader.json
└── tools/                         ← Ferramentas
    ├── calendar/
    ├── communication/
    ├── ai-processing/
    └── escalation/
```

### Saída Esperada

```
========================================
🔄 Importação em Massa de Workflows n8n
   Sistema Multi-Agente para Clínicas
========================================

ℹ️  Método: CLI via Docker
ℹ️  Workflows encontrados: 15

Iniciando importação...

── 📋 Main Workflows (Workflows Principais) ──
   ✅ 01-whatsapp-patient-handler-multitenant.json
   ✅ 01-whatsapp-patient-handler-optimized.json
   ✅ 02-telegram-internal-assistant-multitenant.json
   ✅ 03-appointment-confirmation-scheduler.json
   ✅ 04-error-handler.json

── 🔄 Sub-Workflows ──
   ✅ tenant-config-loader.json

── 📅 Calendar Tools ──
   ✅ mcp-calendar-tool.json

...

========================================
📊 Relatório de Importação
========================================

   Total processado:  15
   Sucesso:           15
   Já existentes:     0
   Falhas:            0

✅ Importação concluída!

📋 Próximos passos:
   1. Acesse o n8n: http://localhost:5678
   2. Vá em 'Workflows'
   3. Configure as credenciais em cada workflow
   4. Ative os workflows principais
```

### Pré-requisitos

**Para método CLI (padrão):**
- Docker instalado
- Container n8n rodando (`docker compose up -d`)

**Para método API:**
- n8n rodando e acessível
- API Key configurada em: Settings > API > Create API Key

### Solução de Problemas

#### Container não encontrado

```
❌ Container 'clinic_n8n' não está rodando!
```

**Solução:**
```bash
docker compose up -d
# Aguardar inicialização
sleep 30
./scripts/import-workflows.sh
```

#### Workflow já existe

```
⚠️  01-whatsapp-patient-handler.json (já existe)
```

**Isso é normal!** Se o workflow já foi importado antes, ele é apenas pulado.

#### Falha na API

```
❌ Não foi possível conectar à API do n8n!
```

**Soluções:**
1. Verifique se o n8n está rodando
2. Confirme a URL correta
3. Verifique se a API Key é válida
4. Verifique se a API está habilitada em Settings

---

## 👤 manage-tenants.sh

### Descrição

Gerencia tenants (clínicas) no banco de dados do sistema.

### Comandos

```bash
# Listar todos os tenants
./scripts/manage-tenants.sh list

# Ver configuração de um tenant
./scripts/manage-tenants.sh get clinic_example_instance

# Adicionar novo tenant (interativo)
./scripts/manage-tenants.sh add

# Atualizar campo de um tenant
./scripts/manage-tenants.sh update clinic_example clinic_phone "+5511999998888"

# Ativar/desativar tenant
./scripts/manage-tenants.sh activate clinic_example
./scripts/manage-tenants.sh deactivate clinic_example

# Deletar tenant
./scripts/manage-tenants.sh delete clinic_example

# Resetar cota de mensagens
./scripts/manage-tenants.sh reset-quota clinic_example

# Ajuda
./scripts/manage-tenants.sh help
```

---

## 🗄️ init-db.sh

### Descrição

Inicializa o banco de dados executando todas as migrations SQL.

### Uso

```bash
./scripts/init-db.sh
```

### O que faz

1. Conecta ao PostgreSQL
2. Executa `001_create_tenant_tables.sql`
3. Executa `002_seed_tenant_data.sql`
4. Executa `003_create_faq_table.sql`

---

## 🔒 add-copyright-headers.sh

### Descrição

Adiciona headers de copyright a todos os arquivos de código fonte.

### Uso

```bash
./scripts/add-copyright-headers.sh
```

### Arquivos Processados

- Arquivos SQL em `scripts/migrations/`
- Arquivos JSON em `workflows/`
- Scripts Shell em `scripts/`
- Documentação Markdown em `docs/`

---

## 📁 migrations/

Contém scripts SQL para inicialização do banco de dados:

| Arquivo | Descrição |
|---------|-----------|
| `001_create_tenant_tables.sql` | Cria tabelas de tenant e configuração |
| `002_seed_tenant_data.sql` | Dados de exemplo para tenants |
| `003_create_faq_table.sql` | Tabela de cache FAQ para otimização de IA |

### Executar migrations manualmente

```bash
# Conectar ao banco
docker exec -it clinic_postgres psql -U clinic_admin -d clinic_db

# Ou executar um arquivo específico
docker exec -i clinic_postgres psql -U clinic_admin -d clinic_db < scripts/migrations/001_create_tenant_tables.sql
```

---

## 🔧 Variáveis de Ambiente

Alguns scripts usam variáveis de ambiente do arquivo `.env`:

```bash
# Database
POSTGRES_USER=clinic_admin
POSTGRES_PASSWORD=sua_senha
POSTGRES_DB=clinic_db
POSTGRES_PORT=5432

# n8n
N8N_CONTAINER=clinic_n8n
N8N_API_URL=http://localhost:5678
N8N_API_KEY=sua_api_key
```

---

## ❓ Perguntas Frequentes

### Como resetar tudo e reimportar?

```bash
# 1. Parar containers
docker compose down

# 2. Remover volumes (CUIDADO: apaga dados!)
docker volume rm n8n-clinic-multiagent_n8n_data

# 3. Reiniciar
docker compose up -d

# 4. Aguardar inicialização
sleep 60

# 5. Inicializar DB
./scripts/init-db.sh

# 6. Importar workflows
./scripts/import-workflows.sh
```

### Posso rodar os scripts no Windows?

Os scripts são para Linux/macOS. No Windows, use:
- WSL2 (Windows Subsystem for Linux)
- Git Bash
- PowerShell (alguns scripts podem precisar de adaptação)

### Como adicionar um novo workflow ao script?

Basta colocar o arquivo `.json` no diretório apropriado:
- `workflows/main/` - Para workflows principais
- `workflows/sub/` - Para sub-workflows
- `workflows/tools/[categoria]/` - Para tools

O script `import-workflows.sh` detectará automaticamente.

---

**Última atualização**: Janeiro 2026  
**Versão**: 1.0

