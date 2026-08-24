import copy
import hashlib
import json
import unittest

from harness import (
    HarnessValidationError,
    build_assurance_packet,
    route_execution,
    validate_assurance_packet,
    validate_runtime_identity,
    validate_tdd_evidence,
)


def _sealed(record, field):
    body = copy.deepcopy(record)
    encoded = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    body[field] = hashlib.sha256(encoded).hexdigest()
    return body


def _tdd(applicable=True, red=True):
    if not applicable:
        return _sealed({"schema_version": "1.0", "applicable": False, "reason": "docs-only"}, "evidence_sha256")
    red_record = {
        "observed": red,
        "exit_code": 1 if red else 0,
        "command": "python -m unittest",
        "observation": "expected failure" if red else "unexpected success",
        "sequence": 1,
    }
    return _sealed(
        {
            "schema_version": "1.0",
            "applicable": True,
            "red": red_record,
            "green": {
                "success": True,
                "exit_code": 0,
                "command": "python -m unittest",
                "observation": "all focused tests passed",
                "sequence": 2,
            },
        },
        "evidence_sha256",
    )


def _identity(model="Codex Luna", effort="high", verified=True):
    return _sealed(
        {"role": "worker", "model": model, "effort": effort, "verified": verified},
        "identity_sha256",
    )


def _result(evidence, success=True):
    return {
        "success": success,
        "evidence": evidence,
        "evidence_sha256": hashlib.sha256(evidence.encode("utf-8")).hexdigest(),
    }


def _contract(**overrides):
    contract = {
        "contract_id": "HARNESS-001",
        "task_id": "TASK-001",
        "base_sha": "a" * 40,
        "candidate_sha": "b" * 40,
        "lane_id": "ea-lab-harness-v1-20260824",
        "allowed_paths": ["tools/ea_lab_harness/"],
        "author_id": "codex-worker-1",
        "author_family": "openai",
        "change_kind": "code",
        "tdd_applicable": True,
        "identity_required": True,
        "expected_runtime_identity": {"role": "worker", "model": "Codex Luna", "effort": "high"},
    }
    contract.update(overrides)
    return contract


def _packet(**overrides):
    contract = overrides.pop("contract", _contract())
    candidate = contract["candidate_sha"]
    review = {
        "reviewer_id": "claude-reviewer-1",
        "reviewer_family": "anthropic",
        "reviewer_model": "Claude Sonnet",
        "reviewed_head": candidate,
        "candidate_sha": candidate,
        "independent_required": True,
        "different_family_required": True,
        "attempt": 1,
        "max_attempts": 2,
        "approved": True,
    }
    review.update(overrides.pop("review", {}))
    defaults = {
        "contract": contract,
        "results": {
            "tests": _result("focused tests"),
            "negative": _result("adversarial tests"),
            "regression": _result("repo guard"),
        },
        "artifacts": [{"path": "tools/ea_lab_harness/harness.py", "sha256": "d" * 64}],
        "artifact_hashes": {"tools/ea_lab_harness/harness.py": "d" * 64},
        "runtime_identities": [_identity()],
        "tdd_evidence": _tdd(),
        "hard_stop": {"requested_actions": [], "approved_actions": []},
        "review": review,
    }
    defaults.update({key: value for key, value in overrides.items() if key != "artifact_hashes"})
    hashes = defaults.pop("artifact_hashes")
    return build_assurance_packet(**defaults), hashes


class ExecutionModeTests(unittest.TestCase):
    def test_plain_contract_routes_to_quick_deterministically(self):
        contract = {"contract_id": "trace-quick", "requested_mode": "QUICK"}
        first = route_execution(contract)
        second = route_execution(contract)
        self.assertEqual(first, second)
        self.assertEqual(first["mode"], "QUICK")
        self.assertTrue(first["allowed"])

    def test_all_modes_and_safety_overrides_are_deterministic(self):
        self.assertEqual(route_execution({"contract_id": "b", "requested_mode": "BOUNDED"})["mode"], "BOUNDED")
        team = route_execution(
            {
                "contract_id": "t",
                "requested_mode": "TEAM",
                "ready_lanes": [
                    {"lane_id": "a", "ready": True, "independent": True, "allowed_paths": ["a/"]},
                    {"lane_id": "b", "ready": True, "independent": True, "allowed_paths": ["b/"]},
                ],
            }
        )
        self.assertEqual(team["mode"], "TEAM")
        self.assertEqual(route_execution({"contract_id": "t2", "requested_mode": "TEAM"})["mode"], "BOUNDED")
        self.assertEqual(
            route_execution({"contract_id": "s", "requested_mode": "QUICK", "high_risk": True})["mode"],
            "STRICT",
        )
        runtime = route_execution({"contract_id": "r", "task_kind": "runtime", "requested_mode": "QUICK"})
        self.assertEqual(runtime["mode"], "RUNTIME")
        blocked = route_execution(
            {"contract_id": "r2", "task_kind": "runtime", "owner_hard_stop_requested": ["deploy"]}
        )
        self.assertEqual(blocked["mode"], "RUNTIME")
        self.assertFalse(blocked["allowed"])


class TddEvidenceTests(unittest.TestCase):
    def test_valid_red_then_green_passes(self):
        self.assertTrue(validate_tdd_evidence(_contract(), _tdd())["valid"])

    def test_missing_red_and_full_suite_substitution_fail_closed(self):
        evidence = _tdd()
        evidence["red"] = None
        with self.assertRaises(HarnessValidationError):
            validate_tdd_evidence(_contract(), evidence)
        evidence = _tdd()
        evidence["green"]["sequence"] = 1
        with self.assertRaises(HarnessValidationError):
            validate_tdd_evidence(_contract(), evidence)

    def test_docs_only_requires_non_empty_reason(self):
        contract = _contract(change_kind="docs", tdd_applicable=False)
        self.assertTrue(validate_tdd_evidence(contract, _tdd(applicable=False))["valid"])
        bad = _sealed({"schema_version": "1.0", "applicable": False, "reason": ""}, "evidence_sha256")
        with self.assertRaises(HarnessValidationError):
            validate_tdd_evidence(contract, bad)


class RuntimeIdentityTests(unittest.TestCase):
    def test_expected_identity_passes_without_granting_authority(self):
        result = validate_runtime_identity(_contract(), [_identity()])
        self.assertTrue(result["valid"])
        self.assertFalse(result["authority_granted"])

    def test_missing_unverified_model_and_effort_mismatch_fail_closed(self):
        for records in ([], [_identity(verified=False)], [_identity(model="Other")], [_identity(effort="low")]):
            with self.assertRaises(HarnessValidationError):
                validate_runtime_identity(_contract(), records)


class AssurancePacketTests(unittest.TestCase):
    def test_positive_packet_is_hash_bound_and_valid(self):
        packet, hashes = _packet()
        result = validate_assurance_packet(packet, current_candidate_sha="b" * 40, artifact_hashes=hashes)
        self.assertTrue(result["valid"])

    def test_packet_tamper_candidate_review_and_packet_hash_fail(self):
        packet, hashes = _packet()
        packet["review"]["reviewed_head"] = "c" * 40
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, artifact_hashes=hashes)
        packet, hashes = _packet()
        packet["packet_id"] = "0" * 64
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, artifact_hashes=hashes)
        packet, hashes = _packet()
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, current_candidate_sha="e" * 40, artifact_hashes=hashes)

    def test_self_review_same_family_and_review_budget_fail(self):
        for review in (
            {"reviewer_id": "codex-worker-1"},
            {"reviewer_family": "openai"},
            {"attempt": 3},
        ):
            packet, hashes = _packet(review=review)
            with self.assertRaises(HarnessValidationError):
                validate_assurance_packet(packet, artifact_hashes=hashes)

    def test_hard_stop_and_artifact_mismatch_fail(self):
        packet, hashes = _packet(hard_stop={"requested_actions": ["deploy"], "approved_actions": []})
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, artifact_hashes=hashes)
        packet, hashes = _packet()
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, artifact_hashes={"tools/ea_lab_harness/harness.py": "e" * 64})

    def test_failed_required_result_and_tampered_evidence_fail(self):
        packet, hashes = _packet(
            results={
                "tests": _result("failed", success=False),
                "negative": _result("negative"),
                "regression": _result("regression"),
            }
        )
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, artifact_hashes=hashes)
        packet, hashes = _packet()
        packet["tdd_evidence"]["green"]["observation"] = "tampered"
        with self.assertRaises(HarnessValidationError):
            validate_assurance_packet(packet, artifact_hashes=hashes)


if __name__ == "__main__":
    unittest.main()
