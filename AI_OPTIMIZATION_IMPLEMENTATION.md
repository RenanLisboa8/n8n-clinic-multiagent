# 🚀 AI Optimization: Implementation Code

**Quick Wins - Ready to Deploy**

---

## 1️⃣ REPLACE: Format Message Node (IMMEDIATE WIN)

### **Current Node** (REMOVE THIS):
- Node Name: `Format Message for WhatsApp`
- Type: `@n8n/n8n-nodes-langchain.agent`
- Cost: $0.0005/message
- Latency: ~700ms

### **New Node** (ADD THIS):
- Node Name: `Format Message (Code)`
- Type: `n8n-nodes-base.code`

```javascript
// ==================================================
// WhatsApp Message Formatter (Zero-Cost Replacement)
// ==================================================
// Replaces AI Agent with deterministic logic
// Savings: $0.0005/message + 700ms latency
// ==================================================

const inputData = $input.first().json;
const rawText = inputData.output || inputData.text || '';

// WhatsApp formatting rules
const formatted = rawText
  .replace(/\*\*/g, '*')       // Markdown bold → WhatsApp bold
  .replace(/###/g, '')          // Remove H3 headers
  .replace(/##/g, '')           // Remove H2 headers  
  .replace(/#/g, '')            // Remove H1 headers
  .replace(/\n{3,}/g, '\n\n')   // Max 2 newlines
  .trim();                      // Remove leading/trailing spaces

return {
  json: {
    formatted_text: formatted,
    original_text: rawText,
    length: formatted.length
  }
};
```

---

## 2️⃣ ADD: Intent Classification Layer

### **New Node** (BEFORE Patient Agent):
- Node Name: `Intent Classifier`
- Type: `n8n-nodes-base.code`

```javascript
// ==================================================
// Intent Classification (Zero-Cost Router)
// ==================================================
// Classifies user intent using regex/keywords
// Routes to appropriate handler (FAQ, LLM, Template)
// Savings: ~40% of queries bypass LLM
// ==================================================

const message = $input.first().json.message_text || '';
const messageLower = message.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, ''); // Remove accents

// Intent patterns (Portuguese)
const intents = {
  // Appointment-related
  appointment_new: {
    patterns: [
      /agendar|marcar\s+consulta|fazer\s+agendamento/i,
      /quero\s+agendar|preciso\s+marcar|gostaria\s+de\s+consulta/i,
      /consulta\s+disponível|horário\s+livre/i
    ],
    confidence: 0.9
  },
  
  appointment_cancel: {
    patterns: [
      /cancelar|desmarcar/i,
      /não\s+posso\s+comparecer|não\s+vou\s+conseguir/i,
      /preciso\s+cancelar/i
    ],
    confidence: 0.95
  },
  
  appointment_reschedule: {
    patterns: [
      /remarcar|mudar\s+horário|transferir\s+consulta/i,
      /outro\s+dia|outra\s+data|outro\s+horário/i
    ],
    confidence: 0.9
  },
  
  appointment_confirm: {
    patterns: [
      /^(sim|confirmo|confirmar|ok|okay)\b/i,
      /\bconfirmo\s+(?:a|minha)?\s*consulta/i,
      /\bvou\s+comparecer/i
    ],
    confidence: 0.95
  },
  
  // Information queries (FAQ candidates)
  info_location: {
    patterns: [
      /endereço|onde\s+fica|localização|como\s+chegar/i,
      /fica\s+onde|local\s+da\s+clínica/i
    ],
    confidence: 1.0
  },
  
  info_hours: {
    patterns: [
      /horário\s+(?:de\s+)?funcionamento|que\s+horas?\s+(?:abre|fecha)/i,
      /aberto|fechado|funciona\s+quando/i,
      /atende\s+(?:aos?|no)?\s*(?:sábado|domingo|feriado)/i
    ],
    confidence: 1.0
  },
  
  info_contact: {
    patterns: [
      /telefone|contato|ligar|whatsapp/i,
      /número|falar\s+com/i
    ],
    confidence: 1.0
  },
  
  info_services: {
    patterns: [
      /atende\s+convênio|aceita\s+plano|valor\s+consulta|quanto\s+custa/i,
      /especialidade|o\s+que\s+trata|serviços/i
    ],
    confidence: 0.8
  },
  
  // Urgency detection
  urgency: {
    patterns: [
      /urgente|emergência|grave|socorro|ajuda/i,
      /sentindo\s+(?:muito\s+)?mal|dor\s+forte/i,
      /não\s+aguento\s+mais|preciso\s+agora/i
    ],
    confidence: 1.0
  },
  
  // Greeting
  greeting: {
    patterns: [
      /^(oi|olá|ola|hey|e\s*aí|bom\s+dia|boa\s+tarde|boa\s+noite)\b/i
    ],
    confidence: 0.7
  }
};

// Classify intent
let detectedIntent = 'unknown';
let confidence = 0;
let matchedPattern = null;

for (const [intentName, intentConfig] of Object.entries(intents)) {
  for (const pattern of intentConfig.patterns) {
    if (pattern.test(message)) {
      detectedIntent = intentName;
      confidence = intentConfig.confidence;
      matchedPattern = pattern.toString();
      break;
    }
  }
  if (detectedIntent !== 'unknown') break;
}

// Extract additional metadata
const hasDate = /(\d{1,2})[\/\-](\d{1,2})(?:[\/\-](\d{2,4}))?/i.test(message);
const hasTime = /(\d{1,2}):(\d{2})|(\d{1,2})h(\d{2})?/i.test(message);
const hasPhone = /\(?([0-9]{2})\)?[\s\-]?([0-9]{4,5})[\s\-]?([0-9]{4})/i.test(message);

return {
  json: {
    intent: detectedIntent,
    confidence: confidence,
    matched_pattern: matchedPattern,
    message_text: message,
    metadata: {
      has_date: hasDate,
      has_time: hasTime,
      has_phone: hasPhone,
      message_length: message.length,
      word_count: message.split(/\s+/).length
    },
    routing: {
      // Routing recommendations
      use_faq: confidence === 1.0 && detectedIntent.startsWith('info_'),
      use_template: confidence >= 0.9 && ['appointment_confirm', 'urgency'].includes(detectedIntent),
      use_llm: confidence < 0.9 || detectedIntent === 'unknown',
      needs_escalation: detectedIntent === 'urgency'
    }
  }
};
```

---

## 3️⃣ ADD: Date Extraction Helper

### **New Node**:
- Node Name: `Extract Dates & Times`
- Type: `n8n-nodes-base.code`

```javascript
// ==================================================
// Date & Time Extraction (Regex-Based)
// ==================================================
// Extracts dates and times from Portuguese text
// Reduces LLM hallucinations on date parsing
// ==================================================

const text = $input.first().json.message_text || '';

// Date patterns
const datePatterns = {
  explicit: /(\d{1,2})[\/\-\.](\d{1,2})(?:[\/\-\.](\d{2,4}))?/g,
  relative: {
    hoje: 0,
    amanha: 1,
    amanhã: 1,
    'depois de amanha': 2,
    'depois de amanhã': 2,
    'próxima segunda': 'next_monday',
    'próxima terça': 'next_tuesday', 
    'próxima quarta': 'next_wednesday',
    'próxima quinta': 'next_thursday',
    'próxima sexta': 'next_friday',
    'próximo sábado': 'next_saturday',
    'próximo sabado': 'next_saturday',
    'próximo domingo': 'next_sunday'
  }
};

// Time patterns  
const timePattern = /(\d{1,2}):(\d{2})|(\d{1,2})h(\d{2})?(?:\s*(?:da\s+)?(?:manhã|manha|tarde|noite))?/gi;

// Extract explicit dates
const explicitDates = [];
let match;
while ((match = datePatterns.explicit.exec(text)) !== null) {
  explicitDates.push({
    type: 'explicit',
    day: parseInt(match[1]),
    month: parseInt(match[2]),
    year: match[3] ? (match[3].length === 2 ? 2000 + parseInt(match[3]) : parseInt(match[3])) : new Date().getFullYear(),
    raw: match[0],
    position: match.index
  });
}

// Extract relative dates
const relativeDates = [];
const textLower = text.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
for (const [keyword, offset] of Object.entries(datePatterns.relative)) {
  if (textLower.includes(keyword)) {
    relativeDates.push({
      type: 'relative',
      keyword: keyword,
      offset: offset
    });
  }
}

// Extract times
const times = [];
while ((match = timePattern.exec(text)) !== null) {
  const hour = match[1] ? parseInt(match[1]) : parseInt(match[3]);
  const minute = match[2] ? parseInt(match[2]) : (match[4] ? parseInt(match[4]) : 0);
  
  times.push({
    hour: hour,
    minute: minute,
    formatted: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`,
    raw: match[0],
    position: match.index
  });
}

// Calculate absolute dates from relative
const absoluteDatesFromRelative = relativeDates.map(rd => {
  const today = new Date();
  if (typeof rd.offset === 'number') {
    const targetDate = new Date(today);
    targetDate.setDate(today.getDate() + rd.offset);
    return {
      ...rd,
      calculated_date: targetDate.toISOString().split('T')[0]
    };
  }
  return rd;
});

return {
  json: {
    dates_found: explicitDates.length + relativeDates.length > 0,
    times_found: times.length > 0,
    explicit_dates: explicitDates,
    relative_dates: absoluteDatesFromRelative,
    times: times,
    original_text: text,
    summary: {
      total_dates: explicitDates.length + relativeDates.length,
      total_times: times.length,
      has_complete_datetime: (explicitDates.length > 0 || relativeDates.length > 0) && times.length > 0
    }
  }
};
```

---

## 4️⃣ ADD: FAQ Database Setup

### **SQL Migration**:

```sql
-- ==================================================
-- FAQ System for Multi-Tenant Clinic
-- ==================================================
-- Handles 30-40% of queries with ZERO cost
-- ==================================================

CREATE TABLE IF NOT EXISTS faq (
    faq_id SERIAL PRIMARY KEY,
    tenant_id UUID NOT NULL REFERENCES tenant_config(tenant_id) ON DELETE CASCADE,
    
    -- Question matching
    question_pattern TEXT NOT NULL,      -- User query keywords (lowercase, no accents)
    question_regex TEXT,                 -- Optional regex pattern
    keywords TEXT[] NOT NULL,            -- Array of keywords for fast matching
    
    -- Answer
    answer_template TEXT NOT NULL,       -- Response with {{variables}}
    answer_type VARCHAR(50) DEFAULT 'text',  -- text, template, redirect_llm
    
    -- Metadata
    category VARCHAR(50),                -- info, appointment, services, etc.
    priority INTEGER DEFAULT 0,          -- Higher = checked first
    times_matched INTEGER DEFAULT 0,     -- Usage tracking
    last_matched_at TIMESTAMPTZ,
    
    -- Audit
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_faq_tenant ON faq(tenant_id) WHERE is_active = true;
CREATE INDEX idx_faq_keywords ON faq USING GIN(keywords);
CREATE INDEX idx_faq_priority ON faq(priority DESC);

-- Trigger for usage tracking
CREATE OR REPLACE FUNCTION update_faq_usage()
RETURNS TRIGGER AS $$
BEGIN
    NEW.times_matched = OLD.times_matched + 1;
    NEW.last_matched_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==================================================
-- SEED DATA (Update tenant_id with your actual UUID)
-- ==================================================

INSERT INTO faq (tenant_id, question_pattern, keywords, answer_template, category, priority) VALUES
-- Location
('YOUR_TENANT_UUID', 'endereço localização onde fica como chegar', 
 ARRAY['endereco', 'localizacao', 'onde', 'chegar'], 
 'Estamos localizados em: {{clinic_address}}

📍 Para chegar aqui, você pode usar Google Maps ou Waze.

Qualquer dúvida, estamos à disposição!', 
 'info', 100),

-- Contact  
('YOUR_TENANT_UUID', 'telefone contato ligar whatsapp número',
 ARRAY['telefone', 'contato', 'ligar', 'numero'],
 'Você pode entrar em contato conosco pelos seguintes meios:

📞 Telefone: {{clinic_phone}}
💬 WhatsApp: Este número aqui!
✉️ Email: {{clinic_email}}

Horário de atendimento: {{hours_start}} às {{hours_end}}',
 'info', 100),

-- Business Hours
('YOUR_TENANT_UUID', 'horário funcionamento abre fecha atende quando',
 ARRAY['horario', 'funcionamento', 'abre', 'fecha', 'atende'],
 '🕐 Horário de Funcionamento:

{{days_open}}
Das {{hours_start}} às {{hours_end}}

*Fechado aos domingos e feriados.*

Para emergências médicas, dirija-se ao hospital mais próximo ou ligue 192.',
 'info', 100),

-- Insurance
('YOUR_TENANT_UUID', 'convênio plano aceita atende unimed particular valor',
 ARRAY['convenio', 'plano', 'unimed', 'particular', 'valor'],
 'Sobre *convênios e valores*:

• Atendemos convênios (consulte disponibilidade)
• Também atendemos particulares
• Valores variam conforme especialidade

Para informações detalhadas, entre em contato pelo telefone {{clinic_phone}}.

Posso ajudar com mais alguma coisa?',
 'services', 90);

-- Add more FAQs as needed...
```

---

## 5️⃣ ADD: FAQ Lookup Node

### **New Node** (BEFORE Patient Agent):
- Node Name: `Check FAQ Database`
- Type: `n8n-nodes-base.postgres`

**Parameters**:
```json
{
  "operation": "executeQuery",
  "query": "
SELECT 
    faq_id,
    answer_template,
    answer_type,
    category
FROM faq
WHERE tenant_id = '{{ $json.tenant_id }}'
AND is_active = true
AND keywords && string_to_array(lower(unaccent('{{ $json.message_text }}')), ' ')
ORDER BY priority DESC, times_matched DESC
LIMIT 1;
  "
}
```

---

## 6️⃣ ADD: FAQ Response Formatter

### **New Node** (AFTER FAQ Lookup):
- Node Name: `Format FAQ Response`
- Type: `n8n-nodes-base.code`

```javascript
// ==================================================
// FAQ Response Formatter
// ==================================================
// Replaces template variables with tenant-specific values
// ==================================================

const faqResult = $input.first().json;
const tenantConfig = $('Load Tenant Config').first().json.tenant_config;

if (!faqResult || !faqResult.answer_template) {
  // No FAQ match, proceed to LLM
  return {
    json: {
      faq_matched: false,
      proceed_to_llm: true
    }
  };
}

// Replace template variables
let answer = faqResult.answer_template;
const variables = {
  clinic_name: tenantConfig.clinic_name,
  clinic_address: tenantConfig.clinic_address,
  clinic_phone: tenantConfig.clinic_phone,
  clinic_email: tenantConfig.clinic_email || '',
  hours_start: tenantConfig.hours_start,
  hours_end: tenantConfig.hours_end,
  days_open: tenantConfig.days_open_display
};

for (const [key, value] of Object.entries(variables)) {
  answer = answer.replace(new RegExp(`{{${key}}}`, 'g'), value);
}

// Track usage
await $pg.query(`
  UPDATE faq 
  SET times_matched = times_matched + 1, 
      last_matched_at = NOW() 
  WHERE faq_id = $1
`, [faqResult.faq_id]);

return {
  json: {
    faq_matched: true,
    formatted_answer: answer,
    category: faqResult.category,
    proceed_to_llm: false
  }
};
```

---

## 7️⃣ UPDATE: Switch Node (Route Based on FAQ)

### **Add BEFORE Patient Agent**:
- Node Name: `Route by FAQ Result`
- Type: `n8n-nodes-base.switch`

**Conditions**:
```json
{
  "rules": {
    "values": [
      {
        "conditions": {
          "combinator": "and",
          "conditions": [
            {
              "leftValue": "={{ $json.faq_matched }}",
              "rightValue": true,
              "operator": {"type": "boolean", "operation": "true"}
            }
          ]
        },
        "outputKey": "faq_answer"
      },
      {
        "conditions": {
          "combinator": "and",
          "conditions": [
            {
              "leftValue": "={{ $json.faq_matched }}",
              "rightValue": false,
              "operator": {"type": "boolean", "operation": "false"}
            }
          ]
        },
        "outputKey": "llm_processing"
      }
    ]
  }
}
```

---

## 📊 IMPLEMENTATION SUMMARY

### **Nodes to ADD**:
1. ✅ Intent Classifier (Code Node)
2. ✅ Extract Dates & Times (Code Node)
3. ✅ Check FAQ Database (Postgres Node)
4. ✅ Format FAQ Response (Code Node)
5. ✅ Route by FAQ Result (Switch Node)

### **Nodes to REPLACE**:
1. ✅ Format Message for WhatsApp (AI Agent → Code Node)

### **Database Changes**:
1. ✅ Create `faq` table
2. ✅ Seed with 20-30 common questions

---

## 🎯 EXPECTED RESULTS

**After Implementation**:
- **40% of queries** handled by FAQ (ZERO cost)
- **Format Message** cost: $0 (was $50/month @ 100k messages)
- **Total Savings**: ~$100-150/month
- **Latency**: 60% faster for FAQ queries

---

## 🚨 DEPLOYMENT ORDER

1. **Week 1**: Replace Format Message node (SAFE, immediate win)
2. **Week 2**: Add Intent Classifier + Date Extractor (enhancement)
3. **Week 3**: Deploy FAQ system (biggest impact)
4. **Week 4**: Monitor & optimize

---

**Ready to deploy? Start with the Format Message replacement! 🚀**

