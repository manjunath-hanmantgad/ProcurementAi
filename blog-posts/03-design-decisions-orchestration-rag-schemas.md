# Three Design Decisions That Shaped the ProcureAI Agent Architecture

*ProcureAI — A practitioner's build log | Post 3 of 6*

---

Multi-agent systems accumulate design decisions faster than single-service systems because every agent boundary, every inter-agent communication pattern, and every tool interface is a decision point. This post documents three that had the most influence on ProcureAI's architecture: the orchestration model, the policy retrieval approach, and the schema discipline applied to every agent input and output.

---

## Decision 1: Sequential orchestration over parallel agent execution

The orchestrator runs specialist agents in a defined sequence. It does not fan out to all five agents simultaneously and wait for all results before assembling the decision.

**The constraint:** Two of the five checks can short-circuit the workflow. A blacklisted vendor eliminates any value in running budget checks, risk analysis, or assembling an approval packet — the outcome is rejection regardless of those findings. Similarly, an insufficient budget triggers rejection before approval routing needs to be computed. Running agents in parallel forces all of them to complete before the short-circuit condition can be evaluated. Sequential execution lets the orchestrator stop as soon as a deterministic rejection condition is met.

The operational benefit is latency reduction on the rejection path. A request with a blacklisted vendor resolves in the time it takes to run the vendor agent — not in the time it takes to run all five agents in parallel. Given that blacklisted vendor rejections are among the highest-confidence decisions in the workflow, this is the path where speed most directly reduces processing time.

**The accepted cost:** Compliant requests — where no short-circuit condition is triggered — take longer in sequential mode than they would in parallel. All five agents run in sequence, and the total workflow time is the sum of individual agent times rather than the maximum. For a local rule-based mode, individual agent times are sub-second. For an LLM-backed mode with OpenAI or Azure OpenAI, each agent call adds round-trip latency that stacks.

Parallel execution for the non-short-circuit path is a documented roadmap item. The sequential default was the correct starting point: it is easier to reason about, easier to test, and easier to add parallel execution incrementally than to debug a parallel implementation that has race conditions or partial-result handling.

---

## Decision 2: Keyword RAG before semantic search for policy validation

The Policy Agent retrieves relevant policy clauses using keyword-based search over the ingested policy document. It does not use embedding-based semantic retrieval. `LLM_PROVIDER=rule-based` mode means the entire policy check is deterministic: the same request always retrieves the same policy clauses and produces the same compliance status.

**The constraint:** Policy decisions need to be reproducible. If a procurement policy compliance check for a software subscription above 100,000 INR returns `requires_manager_approval` today and `compliant` tomorrow — because embedding similarity retrieved different chunks — the system cannot be trusted as an authoritative policy source. Keyword retrieval on well-structured policy documents is deterministic: the same query terms retrieve the same clauses.

The second constraint is the test suite. 30 tests verify agent decision logic, including policy threshold behavior at 25,000, 100,000, and 500,000 INR boundaries. Deterministic retrieval means those tests are stable regression tests, not probabilistic checks that occasionally fail when retrieval returns edge-case chunks.

Semantic search for policy retrieval — using Azure AI Search with embedding-based ranking — is the right production path for policy documents with complex language, cross-references, or exceptions that keyword overlap cannot capture reliably. That upgrade is a short-term roadmap item (`v1.1.0`). The keyword baseline ensures the system is testable and trustworthy before adding semantic retrieval complexity.

**The accepted cost:** Keyword retrieval misses policy clauses that are semantically related to the query but do not share vocabulary. A request involving "workforce technology tools" may not retrieve a policy clause that uses the phrase "productivity software" if there is no token overlap. The review threshold that routes these ambiguous cases to manager approval acts as a safety valve — when policy retrieval is uncertain, the system escalates rather than auto-approves.

---

## Decision 3: Typed Pydantic schemas for every agent input and output

Every agent in ProcureAI has explicit Pydantic schemas for its inputs and its outputs. The Policy Agent's output is a `PolicyFinding` schema with typed fields: `policy_status`, `confidence`, `source_clause`, `requires_additional_approval`, and `justification`. The Vendor Agent returns a `VendorFinding` schema. The Budget Agent returns a `BudgetFinding`. These are not dictionaries — they are typed contracts.

**The constraint:** In a multi-agent system, the Approval Agent depends on the outputs of four specialist agents. If those outputs are untyped dictionaries, a change to one agent's output structure breaks the Approval Agent silently — no type error at definition time, only a runtime failure when the Approval Agent tries to access a field that was renamed or removed. At five agents, that coordination surface is manageable. At ten or twenty agents, untyped inter-agent communication becomes the primary source of integration failures.

Typed schemas enforce the contract at definition time. When the Risk Agent's output schema changes, every component that depends on it — the Approval Agent, the MCP tool registry, the A2A task response format — must be updated to match. The type system surfaces those dependencies explicitly.

The secondary benefit is the MCP tool registry. Each tool in `GET /mcp/tools` exposes its input and output schemas as JSON Schema objects derived directly from the Pydantic models. An external agent client inspecting the MCP tool registry sees the exact input structure required and the exact output structure guaranteed — without reading the source code.

![ProcureAI MCP tool registry — seven typed tools with explicit input and output schemas](procureai-mcp-tools.png)

**The accepted cost:** Schema discipline requires upfront investment. Defining explicit Pydantic models for every agent boundary before any agent logic is written adds development time compared to starting with dictionaries and adding types later. In practice, the investment pays back within the first integration test that catches a contract mismatch before it reaches a runtime failure.

---

## One decision I made explicitly not to make yet

The approval matrix is a static YAML file (`data/approval_matrix.yaml`). Changes to approval thresholds, required approvers, or category rules require editing the file and restarting the service.

A dynamic approval matrix — configurable through an admin API at runtime — is the correct design for a production system where procurement policies change quarterly. But building the admin API before the core workflow was validated would have added interface complexity before the underlying logic was stable. The static YAML is sufficient for local validation, demonstration, and the initial production deployment scope. The admin API follows once the approval logic is confirmed correct.

---

## Current limits

- Sequential orchestration adds latency on the compliant path compared to parallel execution. Parallel agent execution is a planned optimization for production deployments with LLM-backed agents.
- Keyword RAG does not handle semantic policy interpretation. Ambiguous requests may retrieve incomplete policy context.
- The approval matrix requires a service restart to update. A runtime admin configuration API is a roadmap item.
- The `rule-based` LLM provider mode handles well-structured requests correctly. Highly ambiguous or unusual requests may not be handled with the same quality as an LLM-backed mode.

---

## Next engineering step

Inspect the output of `GET /mcp/tools` and find the `validate_policy_compliance` tool. Submit a request at the exact threshold boundary (100,000 INR for a software subscription) through the tool endpoint and inspect the `source_clause` in the response. Then submit the same request at 99,999 INR and compare. Verify the threshold behavior matches the policy document.

---

## One question for you

In your agent or microservice architecture, are inter-service contracts defined as typed schemas or as informal conventions? How do you detect when a producer changes its output format before a consumer breaks in production?

---

*Next post: The evidence-backed decision and how ProcureAI's audit trail makes every approval decision reconstructable — the metrics and validation approach that confirm the system is deciding correctly.*
