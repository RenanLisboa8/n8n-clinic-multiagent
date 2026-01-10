# Configuração de Tipo de Clínica

O sistema suporta configuração explícita do tipo de clínica (médica ou estética) através do campo `clinic_type` na tabela `tenant_config`.

## 🏥 Tipos de Clínica Suportados

### `medical` - Clínicas Médicas
Para clínicas que oferecem consultas médicas, exames e tratamentos de saúde.

**Exemplos de Serviços:**
- Consultas médicas (clínico geral, especialidades)
- Exames (ECG, laboratoriais, imagem)
- Check-ups
- Tratamentos médicos

**Configuração:**
```sql
UPDATE tenant_config 
SET clinic_type = 'medical' 
WHERE tenant_slug = 'clinica-medica';
```

### `aesthetic` - Clínicas de Estética
Para clínicas que oferecem procedimentos estéticos e cosméticos.

**Exemplos de Serviços:**
- Aplicação de Botox
- Preenchimento facial
- Peeling químico
- Tratamentos estéticos faciais e corporais

**Configuração:**
```sql
UPDATE tenant_config 
SET clinic_type = 'aesthetic' 
WHERE tenant_slug = 'clinica-estetica';
```

### `mixed` - Clínicas Mistas
Para clínicas que oferecem tanto serviços médicos quanto estéticos.

**Exemplos:**
- Clínicas que fazem consultas médicas E procedimentos estéticos
- Clínicas multidisciplinares

**Configuração:**
```sql
UPDATE tenant_config 
SET clinic_type = 'mixed' 
WHERE tenant_slug = 'clinica-mista';
```

### `dental` - Clínicas Odontológicas
Para clínicas especializadas em odontologia.

**Exemplos de Serviços:**
- Implantes dentários
- Tratamento de canal
- Limpeza dentária
- Clareamento dental

**Configuração:**
```sql
UPDATE tenant_config 
SET clinic_type = 'dental' 
WHERE tenant_slug = 'clinica-dental';
```

### `other` - Outros Tipos
Para tipos de clínica não listados acima.

**Configuração:**
```sql
UPDATE tenant_config 
SET clinic_type = 'other' 
WHERE tenant_slug = 'clinica-custom';
```

---

## ⚙️ Como Configurar

### 1. Durante a Criação do Tenant

Ao criar um novo tenant no arquivo `002_seed_tenant_data.sql`:

```sql
INSERT INTO tenant_config (
    tenant_name,
    tenant_slug,
    evolution_instance_name,
    clinic_name,
    clinic_type,  -- Adicione este campo
    ...
) VALUES (
    'Minha Clínica de Estética',
    'clinica-estetica',
    'clinica_estetica_instance',
    'Minha Clínica de Estética',
    'aesthetic',  -- Defina o tipo aqui
    ...
);
```

### 2. Atualizar Tenant Existente

```sql
-- Para clínica médica
UPDATE tenant_config 
SET clinic_type = 'medical' 
WHERE tenant_slug = 'clinica-medica';

-- Para clínica de estética
UPDATE tenant_config 
SET clinic_type = 'aesthetic' 
WHERE tenant_slug = 'clinica-estetica';

-- Para clínica mista
UPDATE tenant_config 
SET clinic_type = 'mixed' 
WHERE tenant_slug = 'clinica-mista';
```

### 3. Verificar Configuração Atual

```sql
SELECT 
    tenant_name,
    clinic_name,
    clinic_type,
    COUNT(DISTINCT p.professional_id) as total_profissionais,
    COUNT(DISTINCT sc.service_category) as categorias_servicos
FROM tenant_config tc
LEFT JOIN professionals p ON tc.tenant_id = p.tenant_id AND p.is_active = true
LEFT JOIN professional_services ps ON p.professional_id = ps.professional_id AND ps.is_active = true
LEFT JOIN services_catalog sc ON ps.service_id = sc.service_id AND sc.is_active = true
WHERE tc.is_active = true
GROUP BY tc.tenant_id, tc.tenant_name, tc.clinic_name, tc.clinic_type
ORDER BY tc.clinic_type, tc.clinic_name;
```

---

## 📋 Impacto no Sistema

### Prompts do Sistema
Os prompts do sistema são **genéricos** e funcionam para ambos os tipos de clínica:
- Usam termos neutros: "pacientes/clientes", "consultas/procedimentos"
- Não assumem tipo específico de clínica
- Adaptam-se automaticamente baseado no catálogo de serviços

### Catálogo de Serviços
O sistema já suporta múltiplas categorias de serviços:
- **Estética**: Botox, Preenchimento, Peeling
- **Odontologia**: Implante, Canal, Limpeza
- **Cardiologia**: Consulta, ECG, Teste Ergométrico
- **Clínico Geral**: Consulta, Check-up

### Funcionalidades
Todas as funcionalidades funcionam igualmente para ambos os tipos:
- ✅ Agendamento de consultas/procedimentos
- ✅ Seleção de profissional e serviço
- ✅ Confirmação de agendamentos
- ✅ Reagendamento e cancelamento
- ✅ FAQs personalizadas

---

## 🎯 Recomendações por Tipo

### Clínicas Médicas (`medical`)
**Foco:** Consultas, exames, tratamentos médicos

**Prompts Recomendados:**
- Usar termos: "consulta médica", "exame", "tratamento"
- Enfatizar: horários, preparo para exames, documentação necessária

**Serviços Típicos:**
- Consultas especializadas
- Exames diagnósticos
- Check-ups preventivos
- Tratamentos médicos

### Clínicas de Estética (`aesthetic`)
**Foco:** Procedimentos estéticos e cosméticos

**Prompts Recomendados:**
- Usar termos: "procedimento estético", "tratamento estético", "sessão"
- Enfatizar: resultados esperados, cuidados pós-procedimento, contraindicações

**Serviços Típicos:**
- Aplicação de Botox
- Preenchimento facial
- Peeling químico
- Tratamentos faciais e corporais

### Clínicas Mistas (`mixed`)
**Foco:** Oferece ambos os tipos de serviços

**Prompts Recomendados:**
- Usar termos neutros: "consulta/procedimento", "atendimento"
- Permitir que cliente escolha entre serviços médicos ou estéticos

**Estratégia:**
- Usar catálogo completo de serviços
- Permitir que cliente escolha tipo de serviço desejado
- Apresentar profissionais conforme tipo de serviço

---

## 🔄 Migração de Clínicas Existentes

Se você já tem clínicas cadastradas e quer adicionar o tipo:

1. **Execute a migration:**
```bash
# A migration 015_add_clinic_type_field.sql adiciona o campo automaticamente
psql -U n8n_clinic -d n8n_clinic_db < scripts/migrations/015_add_clinic_type_field.sql
```

2. **Configure manualmente ou use sugestão automática:**
A migration tenta sugerir o tipo baseado nos serviços cadastrados, mas você pode configurar manualmente:

```sql
-- Exemplo: Clínica que só tem serviços estéticos
UPDATE tenant_config 
SET clinic_type = 'aesthetic'
WHERE tenant_id = (
    SELECT tenant_id 
    FROM tenant_config 
    WHERE tenant_slug = 'clinica-estetica'
);
```

---

## 📊 Verificação de Configuração

Para verificar se a configuração está correta:

```sql
-- Ver todos os tenants e seus tipos
SELECT 
    tenant_name,
    clinic_name,
    clinic_type,
    CASE clinic_type
        WHEN 'medical' THEN '🏥 Médica'
        WHEN 'aesthetic' THEN '💆 Estética'
        WHEN 'mixed' THEN '🔄 Mista'
        WHEN 'dental' THEN '🦷 Odontológica'
        ELSE '📋 Outro'
    END as tipo_formatado,
    is_active
FROM tenant_config
ORDER BY clinic_type, tenant_name;
```

---

## ❓ FAQ

### Preciso configurar o tipo se já tenho serviços cadastrados?
**Não é obrigatório**, mas é recomendado. O sistema funciona sem o campo, mas configurá-lo permite:
- Melhor organização
- Possíveis melhorias futuras baseadas no tipo
- Relatórios e métricas mais precisos

### Posso mudar o tipo depois?
**Sim**, você pode atualizar o tipo a qualquer momento:

```sql
UPDATE tenant_config 
SET clinic_type = 'mixed' 
WHERE tenant_slug = 'clinica-exemplo';
```

### O tipo afeta o comportamento do sistema?
**Atualmente não**, os prompts são genéricos. Mas ter o campo configurado permite futuras personalizações e melhorias.

### E se minha clínica oferece mais de um tipo?
Use `'mixed'` para clínicas que oferecem ambos os tipos de serviços.

---

**Última Atualização:** 2026-01-09  
**Versão:** 1.0
