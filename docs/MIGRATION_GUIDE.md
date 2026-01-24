# Guia de Migração - Estrutura Atual

## 🎯 Quando Usar Cada Abordagem

### ✅ Migração Incremental (Recomendado)

**Use quando:**
- Você já tem dados importantes no banco
- Quer preservar configurações existentes
- Está em ambiente de produção ou staging
- Quer atualizar migrations sem reset

**Vantagens:**
- ✅ Preserva dados existentes
- ✅ Mais seguro
- ✅ Permite rollback

**Como usar:**
```bash
./scripts/apply-migrations.sh
```

### 🔄 Reset Completo (Para Testes)

**Use quando:**
- Ambiente de desenvolvimento/teste
- Quer começar do zero
- Dados de teste podem ser perdidos
- Quer validar instalação completa

**⚠️ ATENÇÃO:**
- ❌ **APAGA TODOS OS DADOS**
- ❌ Não use em produção
- ❌ Faça backup antes se necessário

**Como usar:**
```bash
./scripts/reset-db.sh
```

## 📋 Comparação

| Aspecto | Migração Incremental | Reset Completo |
|---------|---------------------|----------------|
| **Preserva dados** | ✅ Sim | ❌ Não |
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
docker exec -t clinic_postgres pg_dump -U n8n_clinic -d n8n_clinic_db > backup_$(date +%Y%m%d).sql
```

### Passo 3: Executar Migração

```bash
./scripts/apply-migrations.sh
```

### Passo 4: Atualizar Workflows

```bash
./scripts/reimport-all-workflows.sh
```

## 🔄 Processo de Reset Completo

### Passo 1: Confirmar Reset

```bash
./scripts/reset-db.sh
```

O script irá:
1. ⚠️ Pedir confirmação (digite "RESET")
2. Recriar o banco do zero
3. Executar todas as migrations
4. Mostrar resumo final

### Passo 2: Configurar Credenciais

Após reset, configure:
1. Google Calendar OAuth2 (ver `docs/SETUP_GOOGLE_CALENDAR_API.md`)
2. Google Gemini API
3. Evolution API
4. PostgreSQL (se necessário)

### Passo 3: Importar Workflows

```bash
./scripts/reimport-all-workflows.sh
```

## 🧪 Estratégia de Teste Recomendada

### Para Desenvolvimento/Teste

```bash
# 1. Reset completo (ambiente limpo)
./scripts/reset-db.sh

# 2. Configurar credenciais no n8n

# 3. Importar workflows
./scripts/reimport-all-workflows.sh

# 4. Testar fluxo completo
```

### Para Produção/Staging

```bash
# 1. Backup obrigatório
docker exec -t clinic_postgres pg_dump -U n8n_clinic -d n8n_clinic_db > backup_prod_$(date +%Y%m%d).sql

# 2. Migração incremental
./scripts/apply-migrations.sh

# 3. Importar workflows
./scripts/reimport-all-workflows.sh
```

## ⚠️ Troubleshooting

### Erro: "container not running"

**Solução:**
```bash
docker compose up -d postgres
sleep 30
./scripts/apply-migrations.sh
```

### Erro: "permission denied"

**Solução:**
```bash
chmod +x scripts/apply-migrations.sh
chmod +x scripts/reset-db.sh
```

### Dados não aparecem após migração

**Solução:**
```bash
docker exec -it clinic_postgres psql -U n8n_clinic -d n8n_clinic_db -c "SELECT COUNT(*) FROM services_catalog;"
```

## 📊 Checklist Pós-Migração

- [ ] Migrations aplicadas com sucesso
- [ ] Workflows importados
- [ ] Credenciais configuradas no n8n
- [ ] Teste de fluxo completo funcionando

## 🔙 Rollback

```bash
# 1. Parar containers
docker compose down

# 2. Restaurar backup
docker compose up -d postgres
sleep 30
docker exec -i clinic_postgres psql -U n8n_clinic -d n8n_clinic_db < backup_YYYYMMDD.sql
```

## 📚 Referências

- `scripts/apply-migrations.sh` - Migração incremental
- `scripts/reset-db.sh` - Reset completo
- `scripts/init-db.sh` - Inicialização automática do banco
- `docs/SETUP_GOOGLE_CALENDAR_API.md` - Setup Google Calendar

---
*Última atualização: 2026-01-24*