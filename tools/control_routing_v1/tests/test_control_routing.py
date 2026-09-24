from __future__ import annotations

import json
from itertools import product
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))

from tools.control_routing_v1.decision import DecisionError, decide
from tools.control_routing_v1.integrity import IntegrityError, RUNTIME_FILES, verify_manifest
from tools.control_routing_v1.jev_shadow import JevShadowError, build_shadow_envelope
from tools.control_routing_v1.routing import RoutingError, route_task


def route_input(**overrides):
    value = {
        "schema_version": "ea_lab_control_routing_task/1",
        "task_id": "TASK-1",
        "work_type": "BOUNDED",
        "risk_flags": [],
        "owner_hard_stop_flags": [],
        "prior_failed_attempts": 0,
        "software_can_prove": False,
    }
    value.update(overrides)
    return value


def decision_input(**overrides):
    value = {
        "schema_version": "ea_lab_control_decision_input/1",
        "task_id": "TASK-1",
        "dependency_state": "READY",
        "writer_conflict": False,
        "process_state": "COMPLETE",
        "deterministic_gates": [{"gate_id": "tests", "state": "PASS", "required": True}],
        "failure_kind": "NONE",
        "attempt_count": 1,
        "route_lane": "LUNA_MEDIUM",
        "repair_limit": 1,
        "repair_used": 0,
        "review_required": False,
        "review_state": "NOT_REQUIRED",
        "owner_hard_stop": False,
    }
    value.update(overrides)
    return value


class CliTests(unittest.TestCase):
    def run_cli(self, raw, command="decide"):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "input.json"
            path.write_text(raw, encoding="utf-8")
            return subprocess.run(
                [sys.executable, "-B", str(REPO_ROOT / "tools/control_routing_v1/cli.py"),
                 command, "--input", str(path)],
                capture_output=True, text=True,
            )

    def test_duplicate_json_keys_refuse_at_every_object_level(self):
        raw = json.dumps(decision_input())
        cases = [
            raw.replace('"owner_hard_stop": false', '"owner_hard_stop": true, "owner_hard_stop": false'),
            raw.replace('"owner_hard_stop": false', '"owner_hard_stop": false, "owner_hard_stop": false'),
            raw.replace('"owner_hard_stop": false', '"owner_hard_stop": true, "owner_hard_\\u0073top": false'),
            raw.replace('"state": "PASS"', '"state": "FAIL", "state": "PASS"'),
            raw[:-1] + ', "extra": {"deep": [{"stop": true, "stop": false}]}}',
        ]
        for payload in cases:
            with self.subTest(payload=payload):
                result = self.run_cli(payload)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertIn("REFUSED: duplicate JSON key", result.stderr)

    def test_decision_cli_refusals_and_required_unknown(self):
        invalid = [
            decision_input(process_state="FAILED"),
            decision_input(route_lane="OWNER_DECISION_REQUIRED"),
            decision_input(deterministic_gates=[]),
            decision_input(deterministic_gates=[{"gate_id": "optional", "state": "PASS", "required": False}]),
        ]
        missing = decision_input()
        del missing["deterministic_gates"]
        invalid.append(missing)
        for value in invalid:
            with self.subTest(value=value):
                result = self.run_cli(json.dumps(value))
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertIn("REFUSED:", result.stderr)
        for value, expected in (
            (decision_input(), "COMPLETE"),
            (decision_input(owner_hard_stop=True), "OWNER_DECISION_REQUIRED"),
            (decision_input(failure_kind="CODE", deterministic_gates=[
                {"gate_id": "tests", "state": "FAIL", "required": True},
                {"gate_id": "compile", "state": "UNKNOWN", "required": True},
            ]), "VERIFY_MORE"),
        ):
            with self.subTest(expected=expected):
                result = self.run_cli(json.dumps(value))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, "")
                self.assertEqual(json.loads(result.stdout)["decision"], expected)

    def test_duplicate_keys_refuse_for_route_and_shadow(self):
        shadow = {
            "schema_version": "ea_lab_jev_shadow_input/1", "task_id": "TASK-1",
            "question": "Is source evidence complete?", "options": ["BLOCK", "COMPLETE"],
            "evidence_summary": ["fixture only"],
        }
        for command, value in (("route", route_input()), ("jev-shadow", shadow)):
            with self.subTest(command=command):
                raw = json.dumps(value)[:-1] + ', "task_id": "TASK-1"}'
                result = self.run_cli(raw, command)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(result.stdout, "")
                self.assertIn("REFUSED: duplicate JSON key", result.stderr)


class RoutingTests(unittest.TestCase):
    def test_software_provable_is_local(self):
        result = route_task(route_input(software_can_prove=True, work_type="HARD"))
        self.assertEqual(result["route_lane"], "LOCAL_DETERMINISTIC")
        self.assertIsNone(result["model"])

    def test_default_luna_ladder(self):
        cases = {
            "MECHANICAL": ("LUNA_LOW", "low"),
            "BOUNDED": ("LUNA_MEDIUM", "medium"),
            "COMPLEX": ("LUNA_HIGH", "high"),
        }
        for work_type, expected in cases.items():
            with self.subTest(work_type=work_type):
                result = route_task(route_input(work_type=work_type))
                self.assertEqual((result["route_lane"], result["reasoning_effort"]), expected)
                self.assertEqual(result["model"], "gpt-6-luna")

    def test_hard_and_risk_escalate_to_sol(self):
        hard = route_task(route_input(work_type="HARD"))
        risk = route_task(route_input(work_type="BOUNDED", risk_flags=["SECURITY"]))
        self.assertEqual(hard["route_lane"], "SOL_HIGH")
        self.assertEqual(risk["route_lane"], "SOL_HIGH")
        self.assertEqual(risk["model"], "gpt-6-sol")

    def test_failure_and_owner_routing(self):
        repeated = route_task(route_input(prior_failed_attempts=2))
        owner = route_task(route_input(owner_hard_stop_flags=["LIVE"]))
        self.assertEqual(repeated["route_lane"], "SOL_HIGH")
        self.assertEqual(owner["route_lane"], "OWNER_DECISION_REQUIRED")
        self.assertIsNone(owner["model"])

    def test_unknown_task_field_refuses(self):
        value = route_input()
        value["surprise"] = True
        with self.assertRaises(RoutingError):
            route_task(value)


class DecisionTests(unittest.TestCase):
    def test_exhausted_repair_negative_matrix(self):
        cases = product(
            ("IDLE", "RUNNING", "COMPLETE", "FAILED", "UNKNOWN"),
            ("READY", "WAITING", "BLOCKED"), (False, True), (False, True),
            ("CODE", "ENVIRONMENT", "CONTRACT", "UNKNOWN"),
            ("LUNA_MEDIUM", "SOL_HIGH"), (0, 1, 2, 3), (False, True),
        )
        count = 0
        for process, dependency, writer, owner, kind, lane, attempts, unknown in cases:
            gates = [{"gate_id": "tests", "state": "FAIL", "required": True}]
            if unknown:
                gates.append({"gate_id": "compile", "state": "UNKNOWN", "required": True})
            value = decision_input(
                process_state=process, dependency_state=dependency, writer_conflict=writer,
                owner_hard_stop=owner, failure_kind=kind, route_lane=lane,
                attempt_count=attempts, deterministic_gates=gates, repair_used=1,
            )
            with self.subTest(value=value):
                self.assertIn(decide(value)["decision"], {"BLOCK", "WAIT", "OWNER_DECISION_REQUIRED"})
            count += 1
        self.assertEqual(count, 3840)

    def test_optional_unknown_does_not_prevent_required_code_retry(self):
        result = decide(decision_input(failure_kind="CODE", deterministic_gates=[
            {"gate_id": "tests", "state": "FAIL", "required": True},
            {"gate_id": "optional", "state": "UNKNOWN", "required": False},
        ]))
        self.assertEqual(result["decision"], "RETRY")

    def test_empty_required_gate_evidence_refuses(self):
        cases = [[], *[
            [{"gate_id": "optional", "state": state, "required": False}]
            for state in ("PASS", "FAIL", "UNKNOWN")
        ]]
        for gates in cases:
            for review_required, review_state in ((False, "NOT_REQUIRED"), (True, "PASS")):
                with self.subTest(gates=gates, review_state=review_state):
                    with self.assertRaisesRegex(DecisionError, "at least one required gate"):
                        decide(decision_input(
                            deterministic_gates=gates, review_required=review_required,
                            review_state=review_state,
                        ))

    def test_missing_gate_evidence_refuses(self):
        value = decision_input()
        del value["deterministic_gates"]
        with self.assertRaises(DecisionError):
            decide(value)

    def test_required_unknown_precedes_code_retry_and_escalation(self):
        gates = [
            {"gate_id": "tests", "state": "FAIL", "required": True},
            {"gate_id": "compile", "state": "UNKNOWN", "required": True},
        ]
        for attempt_count in (0, 1, 2, 3):
            for route_lane in ("LUNA_MEDIUM", "SOL_HIGH"):
                for ordered_gates in (gates, list(reversed(gates))):
                    with self.subTest(attempt_count=attempt_count, route_lane=route_lane, gates=ordered_gates):
                        result = decide(decision_input(
                            deterministic_gates=ordered_gates, failure_kind="CODE",
                            attempt_count=attempt_count, route_lane=route_lane,
                        ))
                        self.assertEqual(result["decision"], "VERIFY_MORE")
                        self.assertEqual(result["reason_codes"], ["REQUIRED_GATE_UNKNOWN"])

    def test_blocking_failure_precedes_unknown_truth(self):
        gates = [
            {"gate_id": "tests", "state": "FAIL", "required": True},
            {"gate_id": "compile", "state": "UNKNOWN", "required": True},
        ]
        cases = [(kind, 0, kind + "_FAILURE") for kind in ("ENVIRONMENT", "CONTRACT", "UNKNOWN")]
        cases.append(("CODE", 1, "REPAIR_BUDGET_EXHAUSTED"))
        for kind, used, reason in cases:
            for process in ("COMPLETE", "UNKNOWN"):
                with self.subTest(kind=kind, process=process):
                    result = decide(decision_input(
                        deterministic_gates=gates, failure_kind=kind,
                        repair_used=used, process_state=process,
                    ))
                    self.assertEqual(result["decision"], "BLOCK")
                    self.assertEqual(result["reason_codes"], [reason])

    def test_failed_process_without_required_failure_refuses(self):
        for gate_state in ("PASS", "UNKNOWN"):
            with self.subTest(gate_state=gate_state):
                with self.assertRaisesRegex(DecisionError, "FAILED process requires a required gate failure"):
                    decide(decision_input(
                        process_state="FAILED",
                        deterministic_gates=[{"gate_id": "tests", "state": gate_state, "required": True}],
                    ))

    def test_owner_route_without_owner_stop_refuses(self):
        with self.assertRaisesRegex(DecisionError, "owner route requires owner_hard_stop"):
            decide(decision_input(route_lane="OWNER_DECISION_REQUIRED"))

    def test_consistent_failed_process_and_owner_route_remain_bounded(self):
        result = decide(decision_input(
            process_state="FAILED", failure_kind="CODE",
            deterministic_gates=[{"gate_id": "tests", "state": "FAIL", "required": True}],
        ))
        self.assertEqual(result["decision"], "RETRY")
        owner = decide(decision_input(route_lane="OWNER_DECISION_REQUIRED", owner_hard_stop=True))
        self.assertEqual(owner["decision"], "OWNER_DECISION_REQUIRED")

    def test_precedence_wait_and_block(self):
        self.assertEqual(decide(decision_input(owner_hard_stop=True))["decision"], "OWNER_DECISION_REQUIRED")
        self.assertEqual(decide(decision_input(writer_conflict=True))["decision"], "WAIT")
        self.assertEqual(decide(decision_input(dependency_state="BLOCKED"))["decision"], "BLOCK")
        self.assertEqual(decide(decision_input(dependency_state="WAITING"))["decision"], "WAIT")
        self.assertEqual(decide(decision_input(process_state="RUNNING"))["decision"], "WAIT")
        self.assertEqual(decide(decision_input(process_state="UNKNOWN"))["decision"], "VERIFY_MORE")

    def test_code_failure_retry_escalate_and_exhaustion(self):
        fail_gate = [{"gate_id": "tests", "state": "FAIL", "required": True}]
        retry = decide(decision_input(deterministic_gates=fail_gate, failure_kind="CODE"))
        escalate = decide(decision_input(
            deterministic_gates=fail_gate,
            failure_kind="CODE",
            attempt_count=2,
            route_lane="LUNA_HIGH",
        ))
        blocked = decide(decision_input(
            deterministic_gates=fail_gate,
            failure_kind="CODE",
            repair_used=1,
        ))
        self.assertEqual(retry["decision"], "RETRY")
        self.assertEqual(escalate["decision"], "ESCALATE")
        self.assertEqual(blocked["decision"], "BLOCK")

    def test_environment_and_unknown_gate_fail_closed(self):
        fail_gate = [{"gate_id": "tests", "state": "FAIL", "required": True}]
        unknown_gate = [{"gate_id": "tests", "state": "UNKNOWN", "required": True}]
        blocked = decide(decision_input(deterministic_gates=fail_gate, failure_kind="ENVIRONMENT"))
        verify = decide(decision_input(deterministic_gates=unknown_gate))
        self.assertEqual(blocked["decision"], "BLOCK")
        self.assertEqual(verify["decision"], "VERIFY_MORE")

    def test_required_review_and_completion_scope(self):
        pending = decide(decision_input(review_required=True, review_state="NOT_RUN"))
        passed = decide(decision_input(review_required=True, review_state="PASS"))
        failed = decide(decision_input(review_required=True, review_state="FAIL"))
        exhausted = decide(decision_input(
            review_required=True,
            review_state="FAIL",
            repair_used=1,
        ))
        complete = decide(decision_input())
        self.assertEqual(pending["decision"], "REVIEW")
        self.assertEqual(passed["decision"], "COMPLETE")
        self.assertEqual(failed["decision"], "RETRY")
        self.assertEqual(exhausted["decision"], "BLOCK")
        self.assertFalse(complete["canonical"])
        self.assertEqual(complete["completion_scope"], "SOURCE_SCOPE_CANDIDATE_NOT_CANONICAL")

    def test_contradictory_decision_state_refuses(self):
        with self.assertRaises(DecisionError):
            decide(decision_input(failure_kind="CODE"))
        with self.assertRaises(DecisionError):
            decide(decision_input(review_required=True, review_state="NOT_REQUIRED"))
        with self.assertRaises(DecisionError):
            decide(decision_input(review_required=False, review_state="PASS"))
    def test_unknown_decision_field_refuses(self):
        value = decision_input()
        value["surprise"] = True
        with self.assertRaises(DecisionError):
            decide(value)


class JevShadowTests(unittest.TestCase):
    def _input(self):
        return {
            "schema_version": "ea_lab_jev_shadow_input/1",
            "task_id": "TASK-1",
            "question": "Does the bounded evidence support another implementation pass?",
            "options": ["RETRY", "ESCALATE", "COMPLETE"],
            "evidence_summary": ["tests=PASS", "diff_scope=PASS"],
        }

    def test_shadow_is_disabled_without_live_adapter(self):
        result = build_shadow_envelope(self._input(), environ={})
        self.assertEqual(result["transport_status"], "DISABLED_NO_LIVE_ADAPTER")
        self.assertFalse(result["auth_present"])
        self.assertFalse(result["activation"])
        self.assertEqual(result["authority_ceiling"], "SHADOW_ONLY_NO_CONTROL_AUTHORITY")

    def test_shadow_unknown_field_refuses(self):
        value = self._input()
        value["raw_provider_payload"] = {}
        with self.assertRaises(JevShadowError):
            build_shadow_envelope(value, environ={})


class IntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = Path(__file__).resolve().parents[3]

    def test_current_manifest_passes(self):
        result = verify_manifest(self.repo_root)
        self.assertEqual(result["status"], "PASS")
        self.assertGreater(result["runtime_file_count"], 0)

    def _copy_package(self):
        temp = tempfile.TemporaryDirectory()
        root = Path(temp.name)
        dst = root / "tools" / "control_routing_v1"
        dst.parent.mkdir(parents=True)
        shutil.copytree(self.repo_root / "tools" / "control_routing_v1", dst)
        return temp, root

    def test_manifest_omission_fails(self):
        for rel in RUNTIME_FILES:
            with self.subTest(path=rel):
                temp, root = self._copy_package()
                try:
                    path = root / "tools" / "control_routing_v1" / "implementation_manifest.json"
                    data = json.loads(path.read_text(encoding="utf-8"))
                    data["runtime_files"].pop(rel)
                    path.write_text(json.dumps(data), encoding="utf-8")
                    with self.assertRaises(IntegrityError):
                        verify_manifest(root)
                finally:
                    temp.cleanup()

    def test_runtime_tamper_fails(self):
        for rel in RUNTIME_FILES:
            with self.subTest(path=rel):
                temp, root = self._copy_package()
                try:
                    path = root / rel
                    path.write_bytes(path.read_bytes() + b"\n# tamper\n")
                    with self.assertRaises(IntegrityError):
                        verify_manifest(root)
                finally:
                    temp.cleanup()


if __name__ == "__main__":
    unittest.main()
