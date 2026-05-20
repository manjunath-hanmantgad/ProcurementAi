# Demo Script — ProcureAI

**Duration:** 15–20 minutes  
**Audience:** Procurement leaders, compliance teams, engineering managers  
**What you need open:** `http://localhost:8004/docs`, terminal, optional dashboard

## Pre-demo setup (do this 10 minutes before)
- [ ] Run: `make up`
- [ ] Seed data:
  - `make seed`
- [ ] Verify API: `curl http://localhost:8004/health`
- [ ] Optional dashboard: `streamlit run dashboard/app.py --server.port 8501`

## The problem you're solving (2 minutes)
> Say: "Procurement decisions are often manual and inconsistent. ProcureAI applies the same policy, budget, vendor, and risk checks on every request and emits an auditable decision packet."

## The solution overview (3 minutes)
> Show `docs/architecture.md` and highlight specialist agents plus orchestrator, MCP tooling, and audit trail.

## Live demo walkthrough (10 minutes)

### Step 1 — Submit a normal request
Call `POST /purchase-requests/analyze` with an IT software subscription example.

Expected output: `decision`, `required_approvers`, `agent_findings`, and `audit_id`.

### Step 2 — Show request tracking
Call `GET /purchase-requests/{request_id}`.

Expected output: stored request state plus approval packet details.

### Step 3 — Show audit evidence
Call `GET /audit/{request_id}`.

Expected output: ordered audit actions by agent and timestamp.

### Step 4 — Show MCP tools
Call `GET /mcp/tools` and explain how external agents can call point checks.

Expected output: list of procurement MCP-compatible tools.

### Step 5 — Show A2A agent cards
Call `GET /agents` and `GET /agents/policy/card`.

Expected output: structured agent card metadata/capabilities.

## Business value close (2 minutes)
> Say: "Every request gets consistent multi-domain validation and a replayable evidence trail, reducing approval risk and audit friction."

## Fallback plan
If live API fails:
- Show screenshots in `demo/`.
- Walk through `docs/api.md` request/response examples.
- Use seeded sample request payloads from `data/sample_requests.json`.

## Common demo gotchas
- Skipping seed/ingestion makes policy and budget checks look incomplete.
- Using wrong port (`8004` is API host port in Compose).
- Forgetting to ingest policy after modifying `data/procurement_policy.md`.
