# Five Agents, One Orchestrator: How ProcureAI Decomposes Procurement Approval

*ProcureAI — A practitioner's build log | Post 2 of 6*

---

The architecture of a multi-agent system is determined by one question: where do you draw the agent boundaries?

Draw them too broadly and you have one large agent that handles everything — effectively a monolithic rule engine with an LLM wrapper. Draw them too narrowly and you have dozens of micro-agents with coordination overhead that exceeds the value of the decomposition. The right boundary is where the concerns are genuinely distinct: different data sources, different evaluation criteria, different failure modes.

In procurement approval, five concerns are genuinely distinct. Policy compliance, vendor status, budget availability, risk analysis, and approval routing each require different data, different logic, and different evidence. That is where I drew the agent boundaries in ProcureAI.

---

## The five agents and what each is responsible for

**Policy Agent.** Validates the purchase request against the procurement policy document. Uses keyword-based RAG to retrieve relevant policy clauses, evaluates the request against those clauses, and returns a compliance status (`compliant` or `requires_manager_approval`) with the specific `source_clause` that applies. The policy agent's finding is evidence — not a pass/fail flag, but a reference to the actual policy text that justifies the decision.

**Vendor Agent.** Looks up the vendor in the vendor master database and returns status (`approved`, `pending`, `blacklisted`, `banned`) and risk level (`low`, `medium`, `high`). A blacklisted or banned vendor status from this agent ends the workflow with automatic rejection regardless of what other agents find. The vendor agent's finding records the vendor status at the time of the request — which matters when a vendor's status changes later.

**Budget Agent.** Checks department budget availability against the request amount. Returns `budget_status` (`available`, `insufficient`, `unknown`) and the `remaining_budget_after_purchase` if the request were approved. An insufficient budget status triggers rejection with the remaining budget figure as evidence. This gives the requester an actionable response rather than a bare rejection.

**Risk Agent.** Applies three checks: duplicate detection (same vendor, similar amount within 30 days), high-risk category classification, and PII masking of the justification text before it is stored in the audit log. A duplicate flag does not automatically reject the request — it surfaces a flag for the approval agent to factor into the decision and required approver routing.

**Approval Agent.** Receives the findings from all four specialist agents and assembles the final decision. Applies the approval matrix — a YAML configuration that specifies required approvers by amount range and category — to determine who must approve. Stores the complete decision packet with all agent findings as evidence. The approval agent does not re-evaluate policy, vendors, or budgets; it synthesizes what the specialist agents already determined.

---

## How the orchestrator coordinates them

```
POST /purchase-requests/analyze
           ↓
    Orchestrator Agent
           ↓
    Policy Agent   →  compliance status + source clause
    Vendor Agent   →  vendor status + risk level
    Budget Agent   →  budget status + remaining budget
    Risk Agent     →  risk flags + duplicate check + masked justification
           ↓
    Approval Agent (receives all four findings)
           ↓
    Decision + required approvers + evidence packet
           ↓
    Audit log entries (~10 per workflow)
           ↓
    Response to caller
```

The orchestrator runs the specialist agents sequentially. If the vendor agent returns `blacklisted`, the orchestrator does not wait for budget and risk findings — the workflow short-circuits to the approval agent with rejection evidence. This is a deliberate design choice: spending compute on budget checks for a blacklisted vendor adds latency with no operational value.

---

## MCP and A2A: what they add to the architecture

**MCP tool registry (`GET /mcp/tools`).** The seven procurement tools — policy search, policy compliance validation, vendor lookup, budget check, duplicate detection, PII masking, and approval packet creation — are exposed as typed MCP-compatible endpoints. Each tool has an explicit JSON schema for inputs and outputs. An external agent client or orchestration framework can discover and invoke these tools programmatically without hardcoding the procurement logic.

**A2A agent cards (`GET /agents/{name}/card`).** Each specialist agent publishes an agent card: name, description, capabilities, input and output schemas, and endpoint. An external system that wants to invoke only the budget check or only the vendor lookup can do so through the A2A task interface (`POST /agents/{name}/tasks`) without going through the full procurement workflow.

![ProcureAI agent cards — capabilities, input/output schemas, and endpoints for each specialist agent](procureai-agent-cards.png)

These two interfaces serve different integration patterns. MCP is for tool-level invocation by an agent framework. A2A is for agent-to-agent task delegation in a larger multi-agent system where ProcureAI's specialist agents are components rather than the top-level service.

---

## Why not a single LLM call or a single rule engine

A single LLM call given the policy document, vendor list, budget data, and approval matrix as context would produce a procurement decision. The problem is verifiability: the decision emerges from the LLM's synthesis of all that context, and the reasoning cannot be cleanly attributed to specific policy clauses, specific vendor records, or specific budget figures.

A single rule engine would produce attributable decisions, but procurement policy is not fully expressible as deterministic rules. The policy document contains qualitative guidance — categories that "typically require" additional review, vendor risk factors that "should be considered" — that benefits from language model interpretation rather than exact pattern matching.

The five-agent decomposition gets the benefits of both: specialist agents handle deterministic lookups (vendor status, budget check) where attributability requires exact data, while the policy agent uses RAG to handle the qualitative policy interpretation where language model reasoning adds value. The evidence from each agent is kept separate rather than blended into a single generative response.

---

## Current limits

- Agent coordination is synchronous and sequential. Parallel agent execution would reduce end-to-end workflow latency, particularly when vendor, budget, and risk checks could run concurrently rather than sequentially.
- The orchestrator is a single point of coordination. There is no fallback behavior if a specialist agent fails mid-workflow. Error handling surfaces failures to the caller rather than retrying with a degraded mode.
- The approval matrix is a YAML file. Changes to approval thresholds or required approvers require a file update and service restart rather than a runtime configuration change.
- LLM provider is `rule-based` by default, meaning the policy agent uses deterministic keyword matching. Switching to `openai` or `azure` enables LLM-backed reasoning but requires a live API key.

---

## Next engineering step

List the available agents at `GET /agents`, then retrieve the budget agent card at `GET /agents/budget_agent/card`. Inspect the input schema and submit a direct task to `POST /agents/budget_agent/tasks` with a department and amount. Verify the budget agent returns the same structured finding it would produce inside the full orchestrated workflow.

---

## One question for you

When you design a workflow that requires multiple types of validation — policy, vendor, budget, risk — do you handle them in a single service or decompose them? What drove that architectural choice, and how do you attribute which check produced a rejection?

---

*Next post: Three design decisions that shaped ProcureAI — why sequential orchestration over parallel, why keyword RAG over semantic for local policy validation, and why typed Pydantic schemas for every agent input and output.*
