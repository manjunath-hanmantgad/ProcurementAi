#!/usr/bin/env python3
"""Eval runner for ProcureAI."""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.agents.budget_agent import BudgetAgent
from app.agents.policy_agent import PolicyAgent
from app.agents.risk_agent import RiskAgent
from app.db.database import init_db
from app.db.seed import seed_budgets
from app.schemas.purchase_request import PurchaseRequest


def run_budget(case: dict, budget_agent: BudgetAgent) -> tuple[bool, str]:
    payload = case["input"]
    expected = case["expected"]
    decision = budget_agent.check_budget_availability(payload["department"], float(payload["amount"]))

    passed = (
        decision.budget_status == expected["budget_status"]
        and abs(decision.current_remaining - float(expected["current_remaining"])) <= 1e-9
        and abs(decision.remaining_budget_after_purchase - float(expected["remaining_after"])) <= 1e-9
    )
    detail = (
        f"status={decision.budget_status} current_remaining={decision.current_remaining} "
        f"remaining_after={decision.remaining_budget_after_purchase}"
    )
    return passed, detail


def run_policy(case: dict, policy_agent: PolicyAgent) -> tuple[bool, str]:
    payload = case["input"]["request"]
    expected = case["expected"]
    request = PurchaseRequest(**payload)
    decision = policy_agent.validate_policy_compliance(request)

    expected_approvers = set(expected.get("required_approvers", []))
    actual_approvers = set(decision.required_approvers)

    passed = decision.policy_status == expected["policy_status"] and expected_approvers.issubset(actual_approvers)
    detail = f"status={decision.policy_status} approvers={sorted(actual_approvers)}"
    return passed, detail


def run_risk(case: dict, risk_agent: RiskAgent) -> tuple[bool, str]:
    payload = case["input"]
    expected = case["expected"]
    decision = risk_agent.check_high_risk_category(payload["category"])

    required_flags = set(expected.get("required_flags", []))
    actual_flags = set(decision.flags)
    passed = decision.risk_level == expected["risk_level"] and required_flags.issubset(actual_flags)
    detail = f"risk_level={decision.risk_level} flags={sorted(actual_flags)}"
    return passed, detail


def main() -> int:
    dataset_path = Path(__file__).with_name("golden_dataset.json")
    dataset = json.loads(dataset_path.read_text(encoding="utf-8"))

    init_db()
    seed_budgets()

    budget_agent = BudgetAgent()
    policy_agent = PolicyAgent()
    risk_agent = RiskAgent()

    executed = 0
    passed = 0
    skipped = 0
    failures: list[tuple[str, str]] = []

    for case in dataset["cases"]:
        case_id = case["id"]
        if case.get("requires_live_llm", False):
            skipped += 1
            print(f"[SKIP] {case_id} requires live LLM")
            continue

        category = case["category"]
        if category == "budget":
            ok, detail = run_budget(case, budget_agent)
        elif category == "policy":
            ok, detail = run_policy(case, policy_agent)
        elif category == "risk":
            ok, detail = run_risk(case, risk_agent)
        else:
            ok, detail = False, f"unsupported category: {category}"

        executed += 1
        if ok:
            passed += 1
            print(f"[PASS] {case_id} {detail}")
        else:
            failures.append((case_id, detail))
            print(f"[FAIL] {case_id} {detail}")

    print("\nSummary")
    print(f"Executed: {executed}")
    print(f"Passed:   {passed}")
    print(f"Skipped:  {skipped}")
    print(f"Failed:   {len(failures)}")

    if failures:
        print("\nFailed cases:")
        for case_id, detail in failures:
            print(f"- {case_id}: {detail}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
