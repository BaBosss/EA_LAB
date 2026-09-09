#!/usr/bin/env python3
"""Focused deterministic checks for the frozen GBP/H4 exit diagnostic."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path


RUN = Path(__file__).resolve().parent


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


diagnostic = json.loads((RUN / "diagnostic.json").read_text(encoding="utf-8"))
acceptance = json.loads((RUN / "diagnostic_acceptance.json").read_text(encoding="utf-8"))
sources = json.loads((RUN / "source_manifest.json").read_text(encoding="utf-8"))

assert diagnostic["control_gate"]["status"] == "PASS_EXACT_CANONICAL_HEADLINE"
assert all(item["pass"] for item in diagnostic["control_gate"]["checks"])
assert len(diagnostic["child_eligibility"]) == 4
assert all(item["mechanically_eligible"] for item in diagnostic["child_eligibility"])
descriptive = diagnostic["descriptive_evidence"]
assert descriptive["eligible_windows"] == 4
assert descriptive["concentration_shift_windows"] == sum(
    item["frozen_rule_calculation"] == "CONCENTRATION_SHIFT"
    for item in diagnostic["descriptive_window_calculations"]
)
assert all(
    item["evidence_scope"] == "DESCRIPTIVE_NON_CAUSAL"
    for item in diagnostic["descriptive_window_calculations"]
)
assert descriptive == acceptance["descriptive_evidence"]
assert descriptive["c_over_e"] == "4/4"
assert descriptive["frozen_rule_result"] == "DESCRIPTIVE_NON_CAUSAL_4_OF_4_CONCENTRATION_SHIFT"
assert descriptive["scope"] == "DESCRIPTIVE_NON_CAUSAL"
assert descriptive["causal_sell_exit_only_attribution"] is False
assert acceptance["decision_classification"] == diagnostic["overall"]
assert diagnostic["overall"] == "BLOCKED_CONFIGURATION_CONFOUND"
assert acceptance["overall"] == "BLOCKED_CONFIGURATION_CONFOUND"
assert acceptance["mt5_rerun"] is False and diagnostic["new_strategy_test_runs"] == 0
assert acceptance["holdout"] == "UNSPENT" and acceptance["optimization"] == "NONE"
assert acceptance["causal_sell_exit_only_attribution"] is False
assert acceptance["preregistered_causal_question_answered"] is False
assert diagnostic["design_limitation"]["status"] == "CONFIGURATION_CONFOUNDED_DIRECTION_PLUS_EXIT"
assert diagnostic["design_limitation"]["preregistered_causal_question_answered"] is False
assert len(diagnostic["config_comparisons"]) == 4
assert all(not item["direction_matches_sell_control"] for item in diagnostic["config_comparisons"])
assert all(not item["one_logical_change_from_sell_control"] for item in diagnostic["config_comparisons"])
expected_differences = {
    "SINGLETP_OFF": {
        ("_16_Direction", "2", "1"),
        ("_16_TpSingleAtrMult", "0.35", "0.0"),
    },
    "BASKETTP_OFF": {
        ("_16_Direction", "2", "1"),
        ("_16_BasketTpUsdPer01", "16.0", "0.0"),
    },
}
for item in diagnostic["config_comparisons"]:
    observed = {(diff["key"], diff["control"], diff["child"]) for diff in item["differences"]}
    assert observed == expected_differences[item["variant"]]
assert len(sources["cells"]) == 6
assert sources["tester_lineage"] == "MT5 lane2 / D:\\Meta 5b / Model 1"
assert diagnostic["tester_lineage"] == sources["tester_lineage"]
assert all(item["tester_lineage"] == sources["tester_lineage"] for item in sources["cells"])
assert not (RUN / "__pycache__").exists()

serialized_results = json.dumps({"diagnostic": diagnostic, "acceptance": acceptance})
assert "PASS_READ_ONLY" not in serialized_results
assert "EXIT_CONCENTRATION_REPLICATED" not in serialized_results

with (RUN / "diagnostic_summary.csv").open(encoding="utf-8", newline="") as handle:
    summary = list(csv.DictReader(handle))
with (RUN / "year_participation.csv").open(encoding="utf-8", newline="") as handle:
    years = list(csv.DictReader(handle))
assert len(summary) == 6
assert len(years) == 18

manifest = {}
for line in (RUN / "artifacts.sha256").read_text(encoding="utf-8").splitlines():
    digest, name = line.split("  ", 1)
    manifest[name] = digest
assert set(manifest) == {
    "analyze_exitdiag.py", "verify_package.py", "diagnostic.json", "diagnostic_acceptance.json",
    "diagnostic_summary.csv", "source_manifest.json", "source_reconciliation.txt", "year_participation.csv",
}
for name, expected in manifest.items():
    assert sha256(RUN / name) == expected, name

print("FOCUSED_CHECKS=PASS")
print(f"CONTROL_GATE={diagnostic['control_gate']['status']}")
print(f"DESCRIPTIVE_C_OVER_E={descriptive['c_over_e']}")
print(f"OVERALL={diagnostic['overall']}")
print("DESIGN_LIMITATION=CONFIGURATION_CONFOUNDED_DIRECTION_PLUS_EXIT")
print("CAUSAL_SELL_EXIT_ONLY_ATTRIBUTION=false")
print("MT5_RERUN=false HOLDOUT=UNSPENT OPTIMIZATION=NONE")
