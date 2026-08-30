import json
import tempfile
import unittest
from pathlib import Path

from pod import REPO_ROOT, advance, consume_fixture, resume, spawn, validate_contract

BASE_SHA = "f3f95d6964c3bdff966697439007b6c0b152aecb"


def contract(task_kind="mechanical"):
    return {
        "canonical_base_sha": BASE_SHA,
        "family": "B16",
        "variant": "PE-ABL-01",
        "parent": "B16-H03",
        "strategy_thesis": "Separate entry edge from position-engine contribution.",
        "current_research_state": "POSITION_ENGINE_DEPENDENT_OR_UNKNOWN",
        "hypothesis_id": "HYP-B16-PE-ABL-01",
        "hypothesis": "Removing one position-engine feature materially changes contribution.",
        "observation": "H03 found multi-entry gross-profit concentration.",
        "expected_benefit_cost": "Clarify mechanism before any optimization.",
        "falsifier": "Ablation preserves contribution within preregistered tolerance.",
        "frozen_mechanics": {"entry": "unchanged", "exit": "unchanged"},
        "changed_mechanics": {"position_engine_feature": "disabled"},
        "accepted_evidence": ["B16_H03_CONFIRMATION_RESULTS.md"],
        "allowed_paths": ["fixture/**"],
        "forbidden_paths": ["deployment/**", "portfolio/**"],
        "deterministic_method": "fixture runner",
        "runtime_estimate": "QUICK",
        "bottleneck": "none",
        "loop_breaker": "one bounded pass",
        "direct_consumer": "Control Tower research routing",
        "acceptance": ["fixture passes", "frozen contract holds"],
        "reviewer_requirement": "independent reviewer",
        "authority_ceiling": "RESEARCH_ONLY",
        "task_kind": task_kind,
        "authority_flags": {
            "holdout": False,
            "trading": False,
            "real_money": False,
            "deployment": False,
            "runtime_attach": False,
            "risk_default_change": False,
        },
    }


class PodTests(unittest.TestCase):
    def test_one_change_rule(self):
        c = contract()
        c["changed_mechanics"]["second_change"] = "forbidden"
        with self.assertRaisesRegex(ValueError, "ONE VARIANT"):
            validate_contract(c)

    def test_protected_authority_rejected(self):
        c = contract()
        c["authority_flags"]["holdout"] = True
        with self.assertRaisesRegex(ValueError, "protected authority"):
            validate_contract(c)

    def test_full_lifecycle_resume_and_review(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            contract_path = root / "input_contract.json"
            evidence_path = root / "fixture_evidence.json"
            workspace = root / "workspace"
            contract_path.write_text(json.dumps(contract()), encoding="utf-8")
            evidence_path.write_text(json.dumps({"outcome": "PASS", "metric": 1}), encoding="utf-8")
            state = spawn(contract_path, workspace)
            self.assertEqual(state["route"], "DETERMINISTIC_TOOL")
            for target in ["LOAD_FAMILY_MEMORY", "IDENTIFY_EVIDENCE_GAP", "PREREGISTER", "EXECUTE", "ANALYZE"]:
                state = advance(workspace, target)
            state = consume_fixture(workspace, evidence_path)
            self.assertEqual(state["recommended_decision"], "ACCEPT")
            state = advance(workspace, "REVIEW")
            state = advance(workspace, "ACCEPT")
            state = advance(workspace, "SYNC_DURABLE_MEMORY")
            state = advance(workspace, "SLEEP")
            _, resumed = resume(workspace)
            self.assertEqual(resumed["lifecycle"], "SLEEP")
            self.assertTrue(resumed["frozen_contract_sha256"])

    def test_frozen_contract_drift_fails_closed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "contract.json"
            workspace = root / "workspace"
            source.write_text(json.dumps(contract()), encoding="utf-8")
            spawn(source, workspace)
            advance(workspace, "LOAD_FAMILY_MEMORY")
            advance(workspace, "IDENTIFY_EVIDENCE_GAP")
            advance(workspace, "PREREGISTER")
            frozen = workspace / "contract.json"
            mutated = json.loads(frozen.read_text(encoding="utf-8"))
            mutated["hypothesis"] = "post-result mutation"
            frozen.write_text(json.dumps(mutated), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "FROZEN_EXPERIMENT_DRIFT"):
                advance(workspace, "EXECUTE")

    def test_transient_workspace_inside_repo_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            source = Path(td) / "contract.json"
            source.write_text(json.dumps(contract()), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "TRANSIENT_WORKSPACE_MUST_BE_OUTSIDE_REPO"):
                spawn(source, REPO_ROOT / "_forbidden_pod_workspace")

    def test_semantic_work_routes_to_model(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            source = root / "contract.json"
            workspace = root / "workspace"
            source.write_text(json.dumps(contract("mechanism")), encoding="utf-8")
            state = spawn(source, workspace)
            self.assertEqual(state["route"], "MODEL_WORKER")


if __name__ == "__main__":
    unittest.main(verbosity=2)
