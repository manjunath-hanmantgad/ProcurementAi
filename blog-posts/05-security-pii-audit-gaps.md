# Security in ProcureAI: What Is in Place, What Is Not, and What That Means Before Production

*ProcureAI — A practitioner's build log | Post 5 of 6*

---

A procurement approval system handles purchase request data that includes vendor relationships, department budget figures, requester identities, and justification text that may contain sensitive business context. Before this system processes real enterprise procurement data, the security posture needs to be understood precisely — not optimistically.

This post documents what ProcureAI implements today, the significant gap that exists in the current local implementation, and what the production security path looks like.

---

## What is implemented: PII masking in the risk pipeline

Purchase request justification text is written by requesters and may contain names, email addresses, or phone numbers. Before justification text enters the audit log, the Risk Agent applies PII masking:

- Names detected by pattern matching are replaced with `[NAME_REDACTED]`
- Email addresses are replaced with `[EMAIL_REDACTED]`
- Phone numbers are replaced with `[PHONE_REDACTED]`

The masked justification is what gets stored in the audit log and the approval packet — not the raw text. This reduces the PII surface of the audit trail without removing the operational context that makes the justification useful for reviewers.

The current implementation uses regex-based detection. It handles common patterns reliably. It does not handle all PII variants — unusual name formats, non-standard phone number formats, or implicit identifiers that do not match a simple pattern. A production deployment handling sensitive HR or legal procurement requests should layer a dedicated PII detection service over this baseline.

---

## What is implemented: vendor risk enforcement

Vendor risk management is deterministic and enforced before any approval logic runs:

- **Approved vendors** proceed through the full workflow
- **Pending vendors** proceed but generate a compliance review flag in the risk finding
- **Blacklisted vendors** trigger immediate rejection — the workflow short-circuits at the Vendor Agent
- **Banned vendors** are treated identically to blacklisted — immediate rejection

The vendor status at the time of the request is recorded in the audit log. If a vendor's status changes after a request was approved, the historical record shows what status was in effect when the approval was granted. That temporal record is relevant for compliance reviews.

---

## What is implemented: the audit trail as an immutable operational record

Every agent action is logged to SQLite with a timestamp. The audit log is append-only at the application level — nothing in the current implementation provides an update or delete endpoint for audit records. Queryable through `GET /audit/{request_id}`, it gives a complete timeline of every action taken on a request.

The audit trail does not have cryptographic immutability in the current implementation. A direct database write could modify a record. For a local single-instance deployment where database access is controlled, this is acceptable. For a multi-user production environment, audit log immutability requires either a write-once storage mechanism or a managed audit logging service — both of which are documented production considerations.

---

## The significant gap: no API authentication in the current implementation

This is the most important security fact about ProcureAI's current state, and I want to be direct about it.

The current implementation is open-access for local development. There is no API key check, no bearer token validation, no authentication mechanism on any endpoint. Any client that can reach `http://127.0.0.1:8004` can submit purchase requests, read audit logs, invoke MCP tools, and query agent cards.

This is a documented and accepted limitation for local development. It is not acceptable for any deployment that is accessible beyond a single developer's local machine.

The production path for authentication is documented:

- **Short-term:** API key authentication via `X-API-Key` header on all endpoints
- **Medium-term:** Role-based access control distinguishing requester, approver, admin, and auditor roles
- **Long-term:** Microsoft Entra ID / OIDC integration for enterprise SSO

None of these are implemented today. The `docs/production-readiness.md` lists API key authentication as the first item in the production gaps section. It is the highest-priority security item before any shared or hosted deployment.

---

## What else is not yet implemented

**CORS is open by default.** `CORS_ORIGINS` defaults to `*` — all origins — in the local configuration. A production deployment must restrict this to the specific origins that need API access.

**No rate limiting.** There is no per-client request rate limiting. A misconfigured or malicious client can submit unlimited requests to the analysis endpoint.

**No structured JSON logging by default.** `JSON_LOGS=false` in the default configuration. A production deployment that feeds logs to an aggregation system (Application Insights, Datadog, Splunk) needs structured logging enabled.

**No secrets rotation.** Azure Key Vault integration for secrets rotation is a long-term roadmap item. Local deployments use environment variables loaded from `.env`. For cloud deployment, secrets must be managed through the hosting platform's secret store — not hardcoded in environment files.

**PII data retention policy is undefined.** Purchase request justifications — even in masked form — are stored in the audit log. There is no automated retention policy that purges records after a defined period. For a production system handling finance and procurement data, a data retention policy is a compliance requirement, not an optional feature.

---

## The security posture in plain terms

ProcureAI implements the security controls that are relevant to its local-first, single-developer scope: PII masking in the risk pipeline, vendor blacklist enforcement, credential-free local operation, and an append-only audit trail at the application layer.

It does not implement the controls required for a shared or enterprise deployment: API authentication, RBAC, rate limiting, audit log immutability, or data retention policy.

That gap is documented, not hidden. The system is appropriate for local validation, demonstration, and architectural evaluation. It requires the production security backlog to be completed before it handles real enterprise procurement data.

---

## Next engineering step

Review `docs/production-readiness.md` and identify the three security items that are prerequisites for your specific deployment context. For most teams, API key authentication, CORS restriction, and structured logging are the minimum before the system is accessible to anyone other than the developer running it locally.

---

## One question for you

For internal automation tools that handle procurement or finance data, what is the minimum authentication mechanism your organization requires before a system is accessible to more than one person? API key, SSO, or full RBAC?

---

*Final post in this series: Deployment readiness — what is fully operational today, the Azure migration path, and an honest accounting of the production backlog.*
