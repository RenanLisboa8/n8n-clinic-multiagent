# Instruções para Reimportar Workflows no n8n

## Método 1: Usando API Key (Recomendado)

1. **Obter API Key do n8n:**
   - Acesse: http://localhost:5678
   - Vá em: Settings > API
   - Crie uma nova API Key ou use uma existente

2. **Executar importação:**
   ```bash
   export N8N_API_KEY="sua-api-key-aqui"
   export N8N_URL="http://localhost:5678"
   python3 scripts/import-workflows-n8n.py
   ```

## Método 2: Usando Script Automático

```bash
./scripts/reimport-all-workflows.sh
```

O script tentará múltiplos métodos automaticamente.

## Método 3: Importação Manual via UI

1. Acesse: http://localhost:5678
2. Vá em: Workflows > Import from File
3. Importe cada arquivo de:
   - `workflows/main/*.json`
   - `workflows/sub/*.json`
   - `workflows/tools/**/*.json`

## Método 4: Usando n8n CLI (Docker)

Se o n8n estiver rodando em Docker:

```bash
./scripts/import-all-workflows-cli.sh
```

## Notas

- ✅ Erro de JSON no `04-error-handler.json` foi corrigido
- ⚠️ O n8n requer autenticação (API Key ou Basic Auth)
- 📝 Workflows refatorados estão prontos para importação
