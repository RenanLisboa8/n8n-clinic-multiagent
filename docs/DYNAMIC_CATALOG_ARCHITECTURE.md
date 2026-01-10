# Arquitetura de Catálogo Dinâmico

## 📋 Visão Geral

O catálogo de serviços agora é carregado dinamicamente do banco de dados, em vez de estar hardcoded no prompt. Isso permite:

- ✅ Atualizações em tempo real (sem editar prompts)
- ✅ Suporte multi-tenant (cada clínica tem seu catálogo)
- ✅ Manutenção simplificada (apenas banco de dados)
- ✅ Economia de tokens (formato otimizado)

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│  WhatsApp Webhook                                           │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  Tenant Config Loader                                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 1. Query Tenant Config                              │   │
│  │ 2. Load Services Catalog (get_services_catalog...)  │   │
│  │ 3. Merge: tenant_config + services_catalog         │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  Patient Handler Workflow                                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 1. Build Prompt with Catalog                         │   │
│  │    - Substitui {{ $json.services_catalog }}          │   │
│  │    - Injeta catálogo formatado                       │   │
│  │ 2. Patient Assistant Agent                           │   │
│  │    - Usa prompt com catálogo dinâmico                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🗄️ Banco de Dados

### Função SQL

```sql
CREATE FUNCTION get_services_catalog_for_prompt(p_tenant_id UUID)
RETURNS TEXT
```

**Formato de saída:**
```
🦷 *ODONTOLOGIA* - Dr. José Silva (Dentista - Implantodontista)
• Implante Dentário: 2h | R$ 5.000,00
• Tratamento de Canal: 1h30 | R$ 1.500,00
• Clareamento Dental: 1h | R$ 800,00

💆 *ESTÉTICA* - Dra. Maria Costa (Dermatologista - Estética)
• Botox: 1h | R$ 600,00
• Preenchimento Facial: 1h30 | R$ 1.500,00
```

### Estrutura de Dados

O catálogo é construído a partir de:

1. **`services_catalog`** - Definições globais de serviços
2. **`professionals`** - Profissionais da clínica
3. **`professional_services`** - Relação N:M com duração/preço customizados

## 🔄 Fluxo de Dados

### 1. Tenant Config Loader

```json
{
  "tenant_config": { ... },
  "tenant_id": "uuid",
  "services_catalog": "🦷 *ODONTOLOGIA* - Dr. José...\n..."
}
```

### 2. Build Prompt with Catalog

Substitui placeholder no prompt:
```
CATÁLOGO DE SERVIÇOS:
{{ $json.services_catalog }}
```

Por:
```
CATÁLOGO DE SERVIÇOS:
🦷 *ODONTOLOGIA* - Dr. José Silva...
```

### 3. Patient Assistant Agent

Recebe prompt completo com catálogo já injetado.

## 📝 Como Atualizar o Catálogo

### Adicionar Novo Serviço

```sql
-- 1. Adicionar ao catálogo global (se não existir)
INSERT INTO services_catalog (service_code, service_name, service_category, ...)
VALUES ('NEW_SERVICE', 'Novo Serviço', 'Categoria', ...);

-- 2. Associar a um profissional
INSERT INTO professional_services (
    professional_id, 
    service_id, 
    custom_duration_minutes, 
    custom_price_cents,
    price_display
)
VALUES (
    (SELECT professional_id FROM professionals WHERE professional_slug = 'dr-jose-silva'),
    (SELECT service_id FROM services_catalog WHERE service_code = 'NEW_SERVICE'),
    60,  -- 1 hora
    100000,  -- R$ 1.000,00
    'R$ 1.000,00'
);
```

### Atualizar Preço/Duração

```sql
UPDATE professional_services
SET custom_price_cents = 120000,
    price_display = 'R$ 1.200,00',
    custom_duration_minutes = 90
WHERE professional_id = '...' 
  AND service_id = '...';
```

**Resultado**: O catálogo é atualizado automaticamente no próximo request!

## 🎯 Vantagens vs Hardcoded

| Aspecto | Hardcoded | Dinâmico |
|---------|-----------|----------|
| Atualização | Editar prompt | Atualizar banco |
| Multi-tenant | Duplicar prompt | Automático |
| Manutenção | Complexa | Simples |
| Consistência | Manual | Automática |
| Escalabilidade | Limitada | Ilimitada |

## 🔍 Debugging

### Verificar Catálogo Gerado

```sql
SELECT get_services_catalog_for_prompt(
    (SELECT tenant_id FROM tenant_config WHERE evolution_instance_name = 'clinica_lisboa_tenant')
);
```

### Verificar Dados no Workflow

No nó "Load Services Catalog", verificar output:
```json
{
  "services_catalog": "🦷 *ODONTOLOGIA*..."
}
```

### Verificar Prompt Final

No nó "Build Prompt with Catalog", verificar:
```json
{
  "system_prompt_with_catalog": "PAPEL: ...\nCATÁLOGO: 🦷 *ODONTOLOGIA*..."
}
```

## ⚠️ Notas Importantes

1. **Performance**: A função SQL é executada a cada request. Para alta carga, considere cache.
2. **Formato**: O formato é otimizado para tokens. Não altere sem considerar impacto.
3. **Placeholder**: O prompt DEVE conter `{{ $json.services_catalog }}` para funcionar.
4. **Fallback**: Se não houver serviços, retorna "Nenhum serviço cadastrado."

## 📚 Arquivos Relacionados

- `scripts/migrations/007_add_service_catalog_function.sql` - Função SQL
- `workflows/sub/tenant-config-loader.json` - Carrega catálogo
- `workflows/main/01-whatsapp-patient-handler-optimized.json` - Injeta no prompt
- `scripts/migrations/004_create_service_catalog_architecture.sql` - Estrutura de dados

---
*Última atualização: 2026-01-03*
