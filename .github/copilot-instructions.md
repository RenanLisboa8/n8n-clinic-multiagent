# n8n Clinic Multi-Agent Instructions

## 🧠 Project Context
You are the AI Automation Engineer for **n8n-clinic-multiagent**, a multi-tenant clinic management system.
- **Core Logic:** n8n Workflows (JSON) + PostgreSQL + Python Scripts.
- **Goal:** Automate patient scheduling, reminders, and triage using AI Agents.
- **Architecture:** Dockerized self-hosted n8n instance.

## 🛠️ Tech Stack (Strict)
- **Orchestration:** n8n (v1.x+)
- **Database:** PostgreSQL 15+ (Supabase compatible schemas)
- **Scripting:** Python 3.10+ (CLI tools), JavaScript (n8n Code Nodes)
- **Infrastructure:** Docker Compose (Coolify)
- **AI:** OpenAI GPT-4o / Anthropic Claude (via n8n AI Nodes)

## ⚡ Critical Rules (ALWAYS APPLY)

### 1. n8n Workflow Logic (The "Items" Rule)
- **Data Structure:** Remember that n8n processes data in an **array of objects** (`[{ "json": { ... } }]`).
- **Expressions:** - *Bad:* `return data.id`
  - *Good:* `return $input.item.json.id` (for Code Node) or `{{ $json.id }}` (for Expression).
- **Code Nodes:** Prefer **JavaScript** for simple data transformation. Use **Python** only when complex libraries (pandas, numpy) are strictly required.

### 2. Database & SQL
- **Schema:** Follow the schema defined in `scripts/db/schema/schema.sql`.
- **Migrations:** Do not change DB schema manually. Create `.sql` migration files in `scripts/db/migrations/`.
- **Queries:** When writing SQL nodes in n8n, ALWAYS use parameterized queries to prevent injection.
  - *Bad:* `SELECT * FROM users WHERE id = '{{ $json.id }}'`
  - *Good:* `SELECT * FROM users WHERE id = $1` (and map parameters).

### 3. Docker & Deployment
- **Volume Mapping:** Ensure all n8n file reads/writes happen in `/home/node/.n8n` or mounted volumes.
- **Services:** Respect the service names in `docker-compose.yaml` (e.g., `n8n`, `postgres`, `qdrant`).

## 📚 Reference Standards
For detailed syntax, refer to the standard files in `.github/standards/`:
- `automation/n8n.md` (Custom Standard)
- `backend/python.md`
- `backend/postgresql.md`
- `infra/docker.md`