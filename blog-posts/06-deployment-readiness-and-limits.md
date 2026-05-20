# What ProcureAI Is Ready For Today and What Enterprise Deployment Actually Requires

*ProcureAI — A practitioner's build log | Post 6 of 6*

---

This series has made a case for a specific architecture: five specialist agents that each produce distinct, attributable evidence, coordinated by an orchestrator that assembles those findings into a decision packet with a queryable audit trail. That architecture is correct and it is implemented.

This final post answers the question that matters for teams considering this as a foundation: what is fully operational today, what the Azure path requires, and what the production backlog looks like in specific terms.

---

## What is fully operational today

Every item below runs locally without external provider credentials or cloud services.

**Core procurement workflow:**
- Multi-agent analysis pipeline with five specialist agents (`POST /purchase-requests/analyze`)
- Policy Agent with keyword-based RAG over the procurement policy document
- Vendor Agent with lookup and blacklist enforcement against the vendor master database
- Budget Agent with department budget verification and remaining-budget reporting
- Risk Agent with duplicate detection (30-day window), category risk flagging, and PII masking
- Approval Agent with evidence-backed decision assembly and approval matrix routing
- Structured decision response: decision, required approvers, and full per-agent findings

**Audit and traceability:**
- Approximately 10 audit log entries per workflow, each with agent name, action, and timestamp
- Full audit trail queryable by request ID (`GET /audit/{request_id}`)
- Decisions persisted with complete agent findings as evidence
- Request status retrievable at any point (`GET /purchase-requests/{id}`)

**MCP and A2A interfaces:**
- Seven typed MCP tools with explicit JSON schema contracts (`GET /mcp/tools`)
- MCP resources and prompt templates exposed for external agent integration
- A2A agent cards for all five specialist agents (`GET /agents/{name}/card`)
- Structured task submission and response for direct agent-to-agent invocation (`POST /agents/{name}/tasks`)

**Validation and testing:**
- 30-test suite covering policy thresholds, vendor status handling, budget overflow, duplicate detection, and MCP/A2A contract conformance — all passing
- Live integration verification script (`scripts/verify_live_integrations.py`) — expected: 14 checks, all PASS
- Reference seed data: vendors, budgets, approval matrix, and sample purchase requests
- Deterministic `rule-based` LLM provider mode requiring no API key

**Infrastructure:**
- FastAPI service with OpenAPI documentation at `http://127.0.0.1:8004/docs`
- Streamlit dashboard for no-code workflow submission and agent inspection
- Docker and Docker Compose support
- GitHub Actions CI/CD (lint, test, Docker build)
- SQLite persistence for all requests, decisions, audit logs, vendor data, and policy chunks
- OpenAI and Azure OpenAI provider adapters configuration-selectable

---

## The Azure deployment path

```
Client → Azure Front Door
              ↓
    Azure Container Apps: Agent Service
              ↓
    Azure OpenAI (GPT-4o — policy reasoning, risk analysis)
    Azure AI Search (semantic policy RAG)
    Azure PostgreSQL (requests, decisions, audit logs)
    Azure Blob Storage (policy documents, vendor data)
              ↓
    Azure Key Vault (secrets)
    Application Insights (request tracing, performance metrics)
    Microsoft Entra ID (authentication, authorization)
```

The local-to-Azure switch is environment configuration:

| Variable | Local | Azure |
|---|---|---|
| `LLM_PROVIDER` | `rule-based` | `azure` |
| Database | SQLite (`data/procureai.db`) | Azure PostgreSQL |
| Policy retrieval | Keyword RAG | Azure AI Search with semantic ranking |
| Secrets | `.env` | Azure Key Vault |
| Logs | Console | Application Insights |
| Auth | None | Entra ID / OIDC |

No code changes are required to switch providers. The application reads configuration from environment variables and selects the appropriate adapter at startup.

---

## The production backlog in specific terms

**API authentication — highest priority.** The current implementation is open-access. Before any shared or hosted deployment, API key authentication (`X-API-Key` header) must be added to all endpoints. Without this, anyone with network access to the service can submit purchase requests, read audit logs, and invoke MCP tools.

**Role-based access control.** A production procurement system needs four roles at minimum: requester (submit requests), approver (review conditional approvals), admin (manage vendor and budget data), and auditor (read-only audit log access). The authorization layer that enforces these roles is not yet implemented.

**PostgreSQL migration.** SQLite is appropriate for single-instance local deployments. Horizontal scaling, concurrent write throughput, and managed backup and encryption at rest require PostgreSQL. The migration path is documented (`docs/deployment.md`) and involves switching `LLM_PROVIDER` to `azure` alongside the database configuration.

**Prometheus metrics endpoint.** The system currently has no operational metrics endpoint. Request processing time, decision distribution, agent error rates, and workflow completion rate are observable through the audit log but are not exposed in a Prometheus-scrapable format. This is a `v1.1.0` roadmap item.

**Embedding-based semantic RAG.** Keyword policy retrieval handles well-structured requests against a straightforward policy document. Real enterprise procurement policies — with exceptions, cross-references, category hierarchies, and qualitative guidance — require embedding-based retrieval to handle queries that do not share vocabulary with the relevant policy clauses.

**Async task processing.** The workflow is synchronous. A single `POST /purchase-requests/analyze` call blocks until all five agents complete. At LLM-backed latency with OpenAI or Azure OpenAI, that may be several seconds per request. High-volume deployments (hundreds of requests per hour) need an async processing queue that returns a job ID immediately and delivers the result when the workflow completes.

**Data retention policy.** Purchase request data — including masked justifications, vendor relationships, and budget figures — is stored indefinitely in the current implementation. A production deployment requires an explicit retention policy with automated purging after the defined period.

---

## An honest assessment

ProcureAI demonstrates the multi-agent procurement architecture that matters: specialist agents producing attributable evidence, an orchestrator that short-circuits on deterministic rejections, typed schemas enforcing inter-agent contracts, and an audit trail that makes every decision reconstructable. That architecture is correct and is implemented with 30 passing tests confirming the decision logic.

The production backlog is real and substantial. API authentication, RBAC, PostgreSQL, Prometheus metrics, semantic RAG, and async processing are not minor hardening items — they are the difference between a local demonstration and an enterprise deployment. None of them require rethinking the agent architecture. The agent boundaries, the evidence model, and the audit design remain intact across all of them.

For a team evaluating this as the foundation for an internal procurement automation system: the architecture is worth building on. The production backlog above is the engineering roadmap that comes with it.

---

## What I would implement first

API key authentication is the prerequisite for everything else. Until it exists, none of the other production items can be safely deployed in a shared environment — RBAC requires an authenticated identity to enforce roles against, and the audit log is only trustworthy as a record of authenticated actions.

The concrete step: add `X-API-Key` header validation as FastAPI middleware, define a key store (initially environment-variable-based, later database-backed), and apply it to every endpoint. That single change makes the system deployable to a shared internal environment and makes every subsequent hardening item buildable on a secure foundation.

---

## One question for you

If you were to automate procurement approval for 300 requests per month across your organization, what would be the first capability you would need beyond what exists today — authentication, semantic policy reasoning, notification routing, or async processing?

---

*This concludes the ProcureAI build log series.*

---

## Full series index

1. The Real Problem with Procurement Approval Is Not the Rules — It Is Applying Them Consistently
2. Five Agents, One Orchestrator: How ProcureAI Decomposes Procurement Approval
3. Three Design Decisions That Shaped the ProcureAI Agent Architecture
4. How ProcureAI Validates That Every Decision Is Grounded in Evidence
5. Security in ProcureAI: What Is in Place, What Is Not, and What That Means Before Production
6. What ProcureAI Is Ready For Today and What Enterprise Deployment Actually Requires *(this post)*

*Add Medium post URLs to each title above after publishing.*
