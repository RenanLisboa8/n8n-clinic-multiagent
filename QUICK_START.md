# 🚀 Quick Start - Teste Rápido

## Para Testar a Nova Estrutura

### Opção 1: Reset Completo (Recomendado para Testes)

**Use quando:** Quer testar do zero, ambiente de desenvolvimento

```bash
# 1. Reset completo (apaga tudo e recria)
./scripts/reset-complete.sh

# 2. Quando pedir confirmação, digite: RESET

# 3. Aguarde o script terminar (2-3 minutos)

# 4. Configure credenciais no n8n (http://localhost:5678)
#    - Google Calendar OAuth2
#    - Google Gemini API
#    - Evolution API
#    - PostgreSQL

# 5. Teste o workflow!
```

### Opção 2: Migração Incremental (Preserva Dados)

**Use quando:** Já tem dados importantes, ambiente de staging/produção

```bash
# 1. Migração incremental (preserva dados)
./scripts/migrate-to-new-structure.sh

# 2. Opcionalmente faça backup quando perguntado

# 3. Aguarde migrations executarem

# 4. Importe workflows atualizados
./scripts/import-workflows.sh

# 5. Teste o workflow!
```

## ⚡ Resposta Rápida

**Para testar:** Use `reset-complete.sh` - é mais rápido e garante estrutura limpa.

**Para produção:** Use `migrate-to-new-structure.sh` - preserva dados.

## 📚 Documentação Completa

- `docs/MIGRATION_GUIDE.md` - Guia completo de migração
- `docs/SETUP_GOOGLE_CALENDAR_API.md` - Setup Google Calendar
- `docs/WORKFLOW_FINAL_VALIDATION.md` - Validação do workflow

---
*Última atualização: 2026-01-03*
