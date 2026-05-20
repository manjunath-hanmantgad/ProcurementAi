# The Real Problem with Procurement Approval Is Not the Rules — It Is Applying Them Consistently

*ProcureAI — A practitioner's build log | Post 1 of 6*

---

Every mid-to-large enterprise already has procurement rules. There is a policy document. There is an approval matrix that specifies who must sign off based on amount and category. There is a vendor list with approved suppliers and flagged ones. There is a budget allocation per department.

The problem is not that the rules do not exist. The problem is that applying all of them consistently, on every purchase request, at the speed operations teams actually need, is not achievable at human scale.

A procurement manager reviewing 50 requests per month might catch the edge cases where a vendor is flagged and the budget is borderline simultaneously. At 300 requests per month, across multiple departments and categories, the edge cases multiply faster than review capacity does. Decisions become inconsistent. Evidence is not documented. Audit trails are email threads.

I built ProcureAI to automate the consistent application of the rules that already exist — not to replace human judgment on borderline cases, but to handle the policy checks, vendor validation, budget verification, and risk analysis that should be deterministic, and to route the cases that genuinely need human review with full evidence already assembled.

---

## What breaks down at procurement volume

**Inconsistent policy application.** The same request type — a software subscription above a certain threshold — should always require a security review flag and a manager approval. When that determination is made manually, it is applied consistently for the first 20 requests and then unevenly as volume increases and reviewers rely on memory rather than the policy document.

**Missing evidence in approval records.** An approval decision in a spreadsheet or email thread says "approved by manager" but does not record which policy clause justified the approval, what the vendor risk level was at the time, or how much department budget remained afterward. When an auditor asks three months later, that evidence cannot be reconstructed.

**Slow routing to the right approver.** The approval matrix specifies different approvers for different amount ranges and categories. Manually determining who must approve a given request and notifying them adds days to a process that should take hours. Requests wait in queues because the routing decision itself is manual.

**No duplicate detection.** A department submitting a request for the same vendor and similar amount that was already submitted 18 days ago should trigger a review. Without systematic detection, the duplicate moves through the approval process independently, potentially consuming budget twice.

---

## What ProcureAI does differently

Rather than building a monolithic rule engine, I decomposed the approval workflow into five specialist agents, each responsible for a distinct type of evidence:

- **Policy Agent** — checks the request against the procurement policy document using keyword-based RAG, returns a compliance status and cites the specific policy clause that applies
- **Vendor Agent** — looks up the vendor in the master database, returns status (approved, pending, blacklisted, banned) and risk level
- **Budget Agent** — checks department budget availability against the request amount, returns remaining budget after purchase
- **Risk Agent** — checks for duplicate submissions within a 30-day window, flags high-risk categories, applies PII masking to justification text
- **Approval Agent** — assembles all four findings into a structured decision packet with required approvers derived from the approval matrix

The orchestrator coordinates these five agents and returns a single structured response: decision, required approvers, and the complete evidence set from each agent.

![ProcureAI dashboard — purchase request submission and multi-agent workflow](procureai-dashboard.png)

A blacklisted vendor triggers automatic rejection regardless of amount or justification. A request that exceeds department budget is rejected with the remaining budget figure as evidence. A compliant request with an approved vendor and available budget is approved, with required approvers determined by the approval matrix. Every decision includes the full agent findings — not a summary, the actual evidence.

---

## Why this matters for auditability

The audit trail for every request is queryable through `GET /audit/{request_id}`. Each entry records: which agent acted, what action was taken, and when. A full workflow produces approximately 10 audit entries — one per agent action — with the final entry containing the complete approval packet.

Three months after an approval, the evidence is still there. Which policy clause applied, what the vendor risk level was, how much budget remained, who was required to approve, and why. That is not achievable with an email-based or spreadsheet-based approval workflow.

---

## Current limits

- The current implementation is a local-first system. It is not running as a live enterprise procurement integration today.
- Policy RAG uses keyword-based search over the policy document. Semantic retrieval for nuanced policy interpretation is a planned extension.
- The approval workflow is synchronous. High-volume processing (hundreds of requests per minute) would require async task processing.
- The current implementation has no API authentication — it is open-access for local development. Authentication is a documented production requirement.
- Human approver notification (email, Slack) is not implemented. The system determines who must approve; the notification routing is a roadmap item.

---

## Next engineering step

Submit a purchase request with a blacklisted vendor through `POST /purchase-requests/analyze` and inspect the decision in the response. Then call `GET /audit/{request_id}` and count the audit entries. Verify the rejection includes the vendor status from the Vendor Agent as evidence, not just a rejection flag.

---

## One question for you

In your current procurement process, if an auditor asked why a specific request was approved six months ago — which policy clause applied, what the vendor risk level was, how much budget remained — could you reconstruct that evidence from your current records?

---

*Next post: The agent architecture that separates five distinct types of procurement evidence into five specialist agents — and why a single rule engine or a single LLM call would not have produced the same auditability.*
