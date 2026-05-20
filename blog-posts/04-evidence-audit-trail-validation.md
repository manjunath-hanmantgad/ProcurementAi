# How ProcureAI Validates That Every Decision Is Grounded in Evidence

*ProcureAI — A practitioner's build log | Post 4 of 6*

---

Automation in approval workflows introduces a specific accountability requirement: every automated decision must be reconstructable after the fact. Not just the outcome — approved, rejected, conditional — but the evidence that produced it. Which policy clause applied. What the vendor risk level was. How much budget remained. Who was required to approve and why.

ProcureAI is designed around this requirement. The evidence is not summarized into a decision; it is preserved in full alongside the decision, in an audit trail that is queryable by request ID.

---

## What a complete decision looks like

A purchase request submitted through `POST /purchase-requests/analyze` returns a structured response containing:

- `decision`: `approved`, `conditional_approval`, or `rejected`
- `required_approvers`: list of approvers determined by the approval matrix
- `policy_finding`: compliance status and the specific `source_clause` from the policy document
- `vendor_finding`: vendor status, risk level, and vendor metadata
- `budget_finding`: budget status and remaining budget after purchase
- `risk_finding`: risk level, category flags, duplicate detection result, and masked justification

This is not a summary. It is the complete structured output of each specialist agent, preserved in the approval packet. A reviewer reading the decision three months later sees exactly what each agent determined — not an LLM-synthesized explanation of what happened.

![ProcureAI workflow result — decision, required approvers, and full evidence from each specialist agent](procureai-workflow-result.png)

The `source_clause` field in the policy finding is particularly important: it references the specific section of the procurement policy that determined the compliance status. "Requires manager approval per Section 4.2: Software subscriptions above INR 100,000 require IT head approval" is auditable evidence. "Policy check passed" is not.

---

## The audit trail: ten entries per workflow

Every agent action during a workflow run writes an entry to the audit log. A complete procurement workflow produces approximately 10 audit entries:

| Entry | Agent | Action |
|---|---|---|
| 1 | Orchestrator | Workflow initiated |
| 2 | Policy Agent | Policy RAG retrieval started |
| 3 | Policy Agent | Compliance status determined |
| 4 | Vendor Agent | Vendor lookup started |
| 5 | Vendor Agent | Vendor status returned |
| 6 | Budget Agent | Budget check started |
| 7 | Budget Agent | Budget availability returned |
| 8 | Risk Agent | Risk analysis started |
| 9 | Risk Agent | Risk assessment + duplicate check returned |
| 10 | Approval Agent | Decision packet stored |

All 10 entries are queryable through `GET /audit/{request_id}`. Each entry includes: agent name, action description, timestamp, and the relevant finding at that step. The full workflow timeline — from submission to decision — is reconstructable from the audit log alone.

This is what distinguishes an automated procurement system from a procurement helper: the audit log is the authoritative record, not a side effect.

---

## Validation: 30 tests covering the decision boundaries that matter

The test suite covers the decision logic that must be correct for the system to be trustworthy:

**Policy threshold tests.** Requests at the 25,000, 100,000, and 500,000 INR thresholds produce the expected compliance status and required approvers. The boundaries are where edge cases occur — a request at exactly 100,000 INR should trigger manager approval, not auto-approval.

**Vendor status handling.** Approved, pending, blacklisted, and unknown vendor statuses each produce the correct downstream decision. A blacklisted vendor produces an immediate rejection regardless of policy status or budget availability.

**Budget overflow.** A request that exceeds the department budget produces an `insufficient` budget status and a rejection. The remaining budget figure is included in the finding.

**Duplicate detection.** A request for the same vendor and similar amount within a 30-day window is flagged. The duplicate flag is visible in the risk finding and surfaced to the approval agent.

**MCP tool contract tests.** Each of the seven MCP tools is tested against its declared input and output schema. A tool that returns a response that does not match its declared schema fails the test — enforcing that the MCP tool registry is a trustworthy contract, not documentation that drifts from the implementation.

**A2A message contract tests.** Task message and task response structures for each specialist agent are tested against their schemas. An agent card that declares an output schema that the agent does not actually produce fails the test.

Running `python -m pytest tests/ -v` against the seeded database produces 30 passing tests. That is the repeatable baseline that confirms the decision logic is correct before any deployment.

---

## The metrics that matter operationally

Beyond test coverage, the system exposes workflow-level metrics observable through the audit log and the decision endpoint:

- **Decision distribution** — the split between approved, conditional approval, and rejected across all processed requests. A significant shift in rejection rate is a signal worth investigating — either request quality changed or policy configuration changed.
- **Policy compliance rate** — the percentage of requests that pass all policy checks without triggering additional approver requirements. A declining compliance rate across a department may indicate budget misalignment with procurement policy thresholds.
- **Vendor risk distribution** — the breakdown of vendor statuses across requests. A rising proportion of pending-status vendors indicates the vendor master needs updating.
- **Audit log completeness** — the expected entry count per workflow is approximately 10. A request with fewer entries indicates a workflow that did not complete all agent stages, which is a processing error.

---

## Current limits

- The evaluation approach is test-suite-based for decision logic and live workflow verification for integration. There is no automated regression report comparing decision distributions across time windows.
- The `rule-based` LLM provider mode handles threshold-based decisions deterministically. Qualitative policy interpretation for edge cases — requests that fall near but not at defined thresholds — depends on LLM mode with a live provider.
- Duplicate detection uses a 30-day window and exact vendor name matching. Fuzzy vendor matching (variants of the same vendor name) is not implemented.
- The audit log records agent actions but does not yet provide a time-series view of decision distribution trends across all requests.

---

## Next engineering step

Submit the three reference requests from `demo/README.md` — standard approval, blacklisted vendor rejection, and budget overflow rejection — and verify the decision and evidence in each response. Then call `GET /audit/{request_id}` for each and count the audit entries. Confirm each workflow produced the expected entry count and that the rejection evidence references the correct agent finding.

---

## One question for you

For automated decisions in your systems — approvals, rejections, routing — how long after the fact can you reconstruct the specific evidence that produced a specific outcome? Is that reconstruction possible from the audit log alone, or does it require reading application logs?

---

*Next post: Security in ProcureAI — what PII masking, vendor blacklist enforcement, and the audit trail provide today, and what the significant gaps are before this handles real enterprise procurement data.*
