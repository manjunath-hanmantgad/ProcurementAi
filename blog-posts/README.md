# ProcureAI — Blog Post Series

6-post series for Medium / Substack. Each post is standalone. Together they form a complete practitioner case study.

**Tone:** First-person engineering retrospective. Not a tutorial. Not a product pitch.
**Target:** Mixed — Procurement leaders, operations managers, CTOs, engineering managers, AI/ML engineers building multi-agent systems.

---

## Series Arc

| File | Post title | Pillar |
|---|---|---|
| `01-the-procurement-approval-problem.md` | The Real Problem with Procurement Approval Is Not the Rules — It Is Applying Them Consistently | Problem and failure mode |
| `02-architecture-five-agents-one-orchestrator.md` | Five Agents, One Orchestrator: How ProcureAI Decomposes Procurement Approval | Architecture and boundaries |
| `03-design-decisions-orchestration-rag-schemas.md` | Three Design Decisions That Shaped the ProcureAI Agent Architecture | Design decisions (why A over B) |
| `04-evidence-audit-trail-validation.md` | How ProcureAI Validates That Every Decision Is Grounded in Evidence | Validation and measured outputs |
| `05-security-pii-audit-gaps.md` | Security in ProcureAI: What Is in Place, What Is Not, and What That Means Before Production | Security and controls |
| `06-deployment-readiness-and-limits.md` | What ProcureAI Is Ready For Today and What Enterprise Deployment Actually Requires | Deployment readiness and limits |

---

## Screenshots for Medium upload

Source files are in `../demo/`. Upload each PNG directly via Medium's inline image button.
Use the alt text in each post as the Medium caption.

| Screenshot | Used in post |
|---|---|
| `procureai-dashboard.png` | 1 |
| `procureai-agent-cards.png` | 2 |
| `procureai-mcp-tools.png` | 3 |
| `procureai-workflow-result.png` | 4 |

All 4 screenshots are used across the series — this series has the best screenshot coverage of all four series.

---

## Medium publishing checklist

Before hitting Publish on each post:
- [ ] Upload referenced screenshots inline at the correct position
- [ ] Replace the `*Post N of 6*` series line with a Medium series tag if applicable
- [ ] In post 6, fill in the series index with actual Medium post URLs after earlier posts are published
- [ ] Add Medium tags: `multi-agent`, `ai-agents`, `procurement`, `enterprise-ai`, `software-engineering`
- [ ] Set subtitle from the first sentence of each post's opening paragraph

---

## QA checklist status

All 6 posts verified against the playbook QA checklist:
- Every claim maps to a verified file, endpoint, test count, or screenshot
- No unverifiable metrics — "30 tests, all passing" and "~10 audit entries per workflow" are both verifiable
- "Production" wording is scoped precisely throughout
- Security gap is stated directly: "open-access for local development — no API authentication"
- At least one limitation disclosed per post
- One technical anchor per post (API path, schema field, test count, or architecture component)
- No full code blocks or replication walkthroughs
- No hype terms used
