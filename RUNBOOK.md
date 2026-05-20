# Runbook — ProcureAI

## Service overview
ProcureAI orchestrates policy, vendor, budget, risk, and approval checks for procurement requests, with audit logging and MCP/A2A interfaces. If unavailable, purchase request analysis and evidence-backed approval packets cannot be produced.

## Health checks
| Endpoint | Expected | What it means |
|---|---|---|
| `GET /health` | `200` with `{"status":"healthy"}` | API process is alive |
| `GET /metrics` | `200` Prometheus payload | Runtime metrics endpoint is available |
| `GET /mcp/tools` | `200` with tool list | MCP registry and backing DB reads are functioning |
| `GET /agents` | `200` with agent list | A2A card registry is reachable |

## Common failure scenarios

### Database or seed data missing
**Symptom:** errors such as `no such table` or empty analysis context.
**Action:**
1. Initialize tables: `python -c "from app.db.database import init_db; init_db()"`
2. Seed base data: `python -c "from app.db.seed import seed_all; seed_all()"`
3. Re-ingest policy: `python -c "from app.rag.ingest_policy import ingest_policy_document; ingest_policy_document()"`

### Policy retrieval returns weak/no matches
**Symptom:** policy findings are generic or missing clauses.
**Action:**
1. Check policy ingestion completed successfully.
2. Validate policy chunks via MCP tools endpoint.
3. Re-run policy ingestion and retry analysis.

### Budget checks appear incorrect
**Symptom:** remaining budget values do not match expected department baseline.
**Action:**
1. Confirm `data/department_budget.csv` is current.
2. Reseed budgets: `python -c "from app.db.seed import seed_budgets; seed_budgets()"`
3. Retry `/purchase-requests/analyze`.

### API unavailable after deployment
**Symptom:** health checks fail or time out.
**Action:**
1. `docker compose ps` and `docker compose logs procureai` (local)
2. Verify container env vars (`PROCUREAI_DB_PATH`, `PROCUREAI_POLICY_PATH`, `APPROVAL_MATRIX_PATH`).
3. Re-test `curl http://localhost:8004/health`.

## Rollback procedure
```bash
az containerapp revision list \
  --name <PROCUREAI_CONTAINER_APP> \
  --resource-group <RESOURCE_GROUP>

az containerapp revision activate \
  --name <PROCUREAI_CONTAINER_APP> \
  --resource-group <RESOURCE_GROUP> \
  --revision <PREVIOUS_REVISION_NAME>
```

## Log access
```bash
# Local logs
docker compose logs -f procureai

# Azure logs
az containerapp logs show \
  --name <PROCUREAI_CONTAINER_APP> \
  --resource-group <RESOURCE_GROUP> \
  --follow
```

## Contacts / escalation
- Primary owner: [fill in]
- Secondary owner: [fill in]
- Escalation SLA: [fill in]
