# Guia de Migração - Nova Estrutura

## 🎯 Quando Usar Cada Abordagem

### ✅ Migração Incremental (Recomendado)

**Use quando:**
- Você já tem dados importantes no banco
- Quer preservar configurações existentes
- Está em ambiente de produção ou staging
- Quer testar sem perder dados

**Vantagens:**
- ✅ Preserva dados existentes
- ✅ Pode fazer backup antes
- ✅ Mais seguro
- ✅ Permite rollback

**Como usar:**
```bash
chmod +x scripts/migrate-to-new-structure.sh
./scripts/migrate-to-new-structure.sh
```

### 🔄 Reset Completo (Para Testes)

**Use quando:**
- Ambiente de desenvolvimento/teste
- Quer começar do zero
- Dados de teste podem ser perdidos
- Quer validar instalação completa

**Vantagens:**
- ✅ Garante estrutura limpa
- ✅ Remove dados inconsistentes
- ✅ Testa instalação completa
- ✅ Mais rápido para testes

**⚠️ ATENÇÃO:**
- ❌ **APAGA TODOS OS DADOS**
- ❌ Não use em produção
- ❌ Faça backup antes se necessário

**Como usar:**
```bash
chmod +x scripts/reset-complete.sh
./scripts/reset-complete.sh
```

## 📋 Comparação

| Aspecto | Migração Incremental | Reset Completo |
|---------|---------------------|----------------|
| **Preserva dados** | ✅ Sim | ❌ Não |
| **Backup opcional** | ✅ Sim | ❌ Não aplicável |
| **Tempo** | ⏱️ Médio | ⚡ Rápido |
| **Segurança** | ✅ Alta | ⚠️ Média |
| **Uso recomendado** | Produção/Staging | Desenvolvimento/Teste |
| **Rollback** | ✅ Possível | ❌ Não |

## 🔄 Processo de Migração Incremental

### Passo 1: Preparação

```bash
# 1. Verificar se containers estão rodando
docker compose ps

# 2. Se não estiverem, iniciar apenas PostgreSQL
docker compose up -d postgres
sleep 30
```

### Passo 2: Backup (Opcional mas Recomendado)

```bash
# Backup manual
docker exec -t clinic_postgres pg_dump -U n8n_clinic -d n8n_clinic_db > backup_$(date +%Y%m%d).sql

# Ou usar o script que oferece backup automático
./scripts/migrate-to-new-structure.sh
```

### Passo 3: Executar Migração

```bash
chmod +x scripts/migrate-to-new-structure.sh
./scripts/migrate-to-new-structure.sh
```

O script executará as migrations na ordem:
1. `001_create_tenant_tables.sql` - Tabelas base (usa `IF NOT EXISTS`)
2. `003_create_faq_table.sql` - Tabela FAQ
3. `004_create_service_catalog_architecture.sql` - Estrutura de serviços
4. `005_seed_service_catalog_data.sql` - Dados de exemplo
5. `006_seed_clinica_lisboa.sql` - Configuração Clínica Lisboa
6. `007_add_service_catalog_function.sql` - Função de catálogo

### Passo 4: Verificar

```bash
# Conectar ao banco
docker exec -it clinic_postgres psql -U n8n_clinic -d n8n_clinic_db

# Verificar tabelas criadas
\dt

# Verificar profissionais
SELECT professional_name, google_calendar_id FROM professionals;

# Verificar serviços
SELECT service_name, service_category FROM services_catalog;
```

### Passo 5: Atualizar Workflows

```bash
# Importar workflows atualizados
./scripts/import-workflows.sh
```

## 🔄 Processo de Reset Completo

### Passo 1: Confirmar Reset

```bash
chmod +x scripts/reset-complete.sh
./scripts/reset-complete.sh
```

O script irá:
1. ⚠️ Pedir confirmação (digite "RESET")
2. Parar todos os containers
3. Remover volumes (apaga dados)
4. Recriar estrutura do zero
5. Executar todas as migrations
6. Importar workflows

### Passo 2: Configurar Credenciais

Após reset, configure:
1. Google Calendar OAuth2 (ver `docs/SETUP_GOOGLE_CALENDAR_API.md`)
2. Google Gemini API
3. Evolution API
4. PostgreSQL (se necessário)

### Passo 3: Criar Tenant

```bash
# Criar tenant interativamente
./scripts/manage-tenants.sh add

# Ou usar SQL direto (ver 006_seed_clinica_lisboa.sql)
```

## 🧪 Estratégia de Teste Recomendada

### Para Desenvolvimento/Teste

```bash
# 1. Reset completo (ambiente limpo)
./scripts/reset-complete.sh

# 2. Configurar credenciais no n8n

# 3. Testar fluxo completo

# 4. Se precisar testar novamente, reset novamente
```

### Para Produção/Staging

```bash
# 1. Backup obrigatório
docker exec -t clinic_postgres pg_dump -U n8n_clinic -d n8n_clinic_db > backup_prod_$(date +%Y%m%d).sql

# 2. Migração incremental
./scripts/migrate-to-new-structure.sh

# 3. Verificar funcionamento

# 4. Se houver problemas, restaurar backup
docker exec -i clinic_postgres psql -U n8n_clinic -d n8n_clinic_db < backup_prod_YYYYMMDD.sql
```

## ⚠️ Troubleshooting

### Erro: "relation already exists"

**Causa**: Tabela já existe no banco.

**Solução**: Normal em migração incremental. As migrations usam `IF NOT EXISTS`, então são idempotentes.

### Erro: "container not running"

**Causa**: Container PostgreSQL não está rodando.

**Solução**:
```bash
docker compose up -d postgres
sleep 30
./scripts/migrate-to-new-structure.sh
```

### Erro: "permission denied"

**Causa**: Script não tem permissão de execução.

**Solução**:
```bash
chmod +x scripts/migrate-to-new-structure.sh
chmod +x scripts/reset-complete.sh
```

### Dados não aparecem após migração

**Causa**: Migrations de seed podem não ter executado.

**Solução**:
```bash
# Verificar se dados foram inseridos
docker exec -it clinic_postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT COUNT(*) FROM professionals;"

# Se vazio, executar seed manualmente
docker exec -i clinic_postgres psql -U n8n_clinic -d n8n_clinic_db < scripts/migrations/005_seed_service_catalog_data.sql
```

## 📊 Checklist Pós-Migração

- [ ] Tabelas criadas (`\dt` no psql)
- [ ] Profissionais cadastrados
- [ ] Serviços no catálogo
- [ ] Função `get_services_catalog_for_prompt()` existe
- [ ] Função `find_professionals_for_service()` existe
- [ ] Workflows importados
- [ ] Credenciais configuradas no n8n
- [ ] Teste de fluxo completo funcionando

## 🔙 Rollback

### Se algo der errado na migração incremental

```bash
# 1. Parar containers
docker compose down

# 2. Restaurar backup
docker compose up -d postgres
sleep 30
docker exec -i clinic_postgres psql -U n8n_clinic -d n8n_clinic_db < backup_YYYYMMDD.sql

# 3. Verificar
docker exec -it clinic_postgres psql -U n8n_clinic -d n8n_clinic_db
```

## 📚 Referências

- `scripts/migrate-to-new-structure.sh` - Script de migração incremental
- `scripts/reset-complete.sh` - Script de reset completo
- `scripts/init-db.sh` - Inicialização básica do banco
- `docs/SETUP_GOOGLE_CALENDAR_API.md` - Setup Google Calendar

---
*Última atualização: 2026-01-03*
