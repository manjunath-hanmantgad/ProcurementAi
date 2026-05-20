from prometheus_client import Counter, Histogram

_NS = "procureai"

approval_requests_total = Counter(
    f"{_NS}_approval_requests_total",
    "Total approval requests",
    ["status"],
)
workflow_latency = Histogram(
    f"{_NS}_workflow_latency_seconds",
    "Workflow execution latency",
)
llm_calls_total = Counter(
    f"{_NS}_llm_calls_total",
    "Total LLM agent calls",
    ["agent", "status"],
)
