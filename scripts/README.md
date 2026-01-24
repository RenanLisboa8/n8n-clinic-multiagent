# Scripts de Banco de Dados

## 📋 Visão Geral

Este diretório contém scripts para gerenciamento do banco de dados PostgreSQL do sistema n8n Clinic Multi-Agent.

## 🚀 Scripts Principais

### `reset-db.sh` - Reset Completo do Banco

**Uso**: `./scripts/reset-db.sh`

Limpa completamente o banco de dados e recria tudo do zero.

**⚠️ ATENÇÃO**: Este script **DELETA TODOS OS DADOS**!

**Quando usar**:
- Ambiente de desenvolvimento/teste
- Reset completo após mudanças estruturais
- Validação de instalação completa

**O que faz**:
1. Drop e recria o banco de dados
2. Executa todas as migrations na ordem correta
3. Verifica estrutura criada
4. Mostra resumo final

### `apply-migrations.sh` - Aplicar Migrations Pendentes

**Uso**: `./scripts/apply-migrations.sh`

Aplica apenas migrations mais recentes em um banco existente (preserva dados).

**Quando usar**:
- Atualizar banco existente sem perder dados
- Aplicar novas migrations após deploy

### `init-db.sh` - Inicialização Automática

**Uso**: Executado automaticamente pelo Docker quando o container PostgreSQL é criado pela primeira vez.

Este script é montado no container e executa automaticamente quando o diretório de dados está vazio.

## 📁 Estrutura de Migrations

As migrations estão em `scripts/migrations/` e devem ser executadas nesta ordem:

1. **001_create_tenant_tables.sql** - Tabelas base (tenant_config, etc)
2. **002_seed_tenant_data.sql** - Dados iniciais e system prompts
3. **003_create_faq_table.sql** - Tabela FAQ e dados iniciais
4. **004_create_service_catalog_architecture.sql** - Arquitetura de serviços
5. **005_seed_service_catalog_data.sql** - Dados de serviços de exemplo
6. **015_add_clinic_type_field.sql** - Campo clinic_type
7. **017_add_services_faq.sql** - FAQ para perguntas sobre serviços
8. **018_unique_services_catalog.sql** - Função de catálogo único
9. **019_update_appointment_faq_show_catalog.sql** - Ajustes no FAQ de agendamentos
10. **020_get_service_by_number.sql** - Buscar serviço por número

### Migrations Obsoletas

- **016_numbered_services_catalog.sql** - ⚠️ OBSOLETA (substituída por 018)

## 🔧 Fluxo Recomendado

### Para Desenvolvimento/Teste

```bash
# Reset completo (limpa tudo)
./scripts/reset-db.sh

# Ou usar Docker Compose (recomendado para primeira vez)
docker compose down -v  # Remove volumes
docker compose up -d postgres  # Recria e executa init-db.sh automaticamente
```

### Para Atualizar Banco Existente

```bash
# Aplicar apenas migrations pendentes
./scripts/apply-migrations.sh
```

### Para Produção

```bash
# 1. Backup primeiro (OBRIGATÓRIO)
docker compose exec -T postgres pg_dump -U n8n_clinic -d n8n_clinic_db > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Aplicar migrations
./scripts/apply-migrations.sh

# 3. Verificar funcionamento
docker compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT COUNT(*) FROM tenant_config;"
```

## 📊 Verificações Úteis

### Verificar Estrutura do Banco

```bash
docker compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "\dt"
```

### Verificar Catálogo de Serviços

```bash
docker compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT get_services_catalog_for_prompt((SELECT tenant_id FROM tenant_config WHERE is_active = true LIMIT 1));"
```

### Verificar FAQ de Serviços

```bash
docker compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT question_original, intent FROM tenant_faq WHERE intent = 'services' LIMIT 5;"
```

### Listar Tenants

```bash
docker compose exec postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT tenant_name, clinic_name, is_active FROM tenant_config;"
```

## 🔒 Segurança

- ⚠️ Nunca execute `reset-db.sh` em produção sem backup
- ✅ Sempre faça backup antes de aplicar migrations em produção
- ✅ Teste migrations em ambiente de staging primeiro

## 📝 Notas Técnicas

- Todas as migrations usam `CREATE OR REPLACE` quando possível (idempotência)
- Migrations de dados usam `ON CONFLICT DO UPDATE` para evitar duplicatas
- Scripts verificam se containers estão rodando antes de executar
- Erros críticos param a execução (`set -e`)
