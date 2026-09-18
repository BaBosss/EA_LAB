import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "mobile_report_hub"))

import owner_operations
import build_index


CANONICAL_SHA = "f9a9906f45418303e43345141cf8c6f81f15007a"
AS_OF = "2026-09-18T12:00:00Z"


class OwnerOperationsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / "observations.json"

    def tearDown(self):
        self.temp.cleanup()

    def payload(self, **changes):
        payload = {
            "schema_version": "EA_LAB_JOB_OBSERVATIONS_V1",
            "source_kind": "LOCAL_DURABLE_JOB_STATUS",
            "observed_at_utc": "2026-09-18T11:59:00Z",
            "canonical_observed_sha": CANONICAL_SHA,
            "observations": [{
                "lane_id": "ORDER-OWNER-CONTROL-V0",
                "job_id": "owner-control-v0-author",
                "checked_utc": "2026-09-18T11:58:30Z",
                "observed_state": "COMPLETE",
                "durable_state": "COMPLETE",
                "runner_alive": False,
                "child_alive": False,
                "postcondition_alive": False,
                "heartbeat_age_sec": 12.5,
                "retry_decision": "REFUSE_RETRY",
                "result": {
                    "state": "COMPLETE",
                    "exit": 0,
                    "postcondition": "PASSED",
                    "ended": "2026-09-18T11:58:20Z",
                },
                "local_head": CANONICAL_SHA,
            }],
        }
        payload.update(changes)
        return payload

    def project(self, payload=None, *, path=True):
        if not path:
            return owner_operations.project(None, CANONICAL_SHA, AS_OF)
        raw = json.dumps(self.payload() if payload is None else payload, separators=(",", ":")).encode()
        self.path.write_bytes(raw)
        return owner_operations.project(self.path, CANONICAL_SHA, AS_OF)

    def test_absent_input_is_explicitly_unavailable(self):
        result = self.project(path=False)
        self.assertEqual(result["status"], "UNAVAILABLE")
        self.assertEqual(result["reason"], "NOT_PROVIDED")
        self.assertEqual(result["observations"], [])
        self.assertEqual(result["source_sha256"], "UNKNOWN")

    def test_valid_terminal_snapshot_is_safe_and_scope_separated(self):
        raw = json.dumps(self.payload(), separators=(",", ":")).encode()
        self.path.write_bytes(raw)
        result = owner_operations.project(self.path, CANONICAL_SHA, AS_OF)
        self.assertEqual(result["status"], "AVAILABLE")
        self.assertEqual(result["freshness"], "CURRENT")
        self.assertEqual(result["binding_state"], "MATCHES_CANONICAL_SHA")
        self.assertEqual(result["source_sha256"], hashlib.sha256(raw).hexdigest())
        row = result["observations"][0]
        self.assertEqual(row["result"]["exit"], 0)
        self.assertEqual(row["result"]["postcondition"], "PASSED")
        self.assertEqual(row["deliverable_status"], "UNKNOWN")
        self.assertEqual(row["review_status"], "UNKNOWN")
        self.assertEqual(row["canonical_status"], "UNKNOWN")

    def test_valid_active_snapshot_keeps_checked_time_observations_only(self):
        payload = self.payload()
        row = payload["observations"][0]
        row.update({
            "observed_state": "RUNNING",
            "durable_state": "RUNNING",
            "runner_alive": True,
            "child_alive": True,
            "postcondition_alive": False,
            "retry_decision": "REFUSE_RETRY",
            "result": {"state": "UNKNOWN", "exit": None, "postcondition": "UNKNOWN", "ended": None},
        })
        del row["local_head"]
        result = self.project(payload)
        projected = result["observations"][0]
        self.assertEqual(result["status"], "AVAILABLE")
        self.assertIs(projected["runner_alive"], True)
        self.assertIs(projected["child_alive"], True)
        self.assertEqual(projected["local_head"], "UNKNOWN")
        self.assertEqual(projected["result"], {
            "state": "UNKNOWN", "exit": "UNKNOWN", "postcondition": "UNKNOWN", "ended": "UNKNOWN"
        })

    def test_malformed_schema_time_head_and_types_are_unavailable(self):
        cases = {}
        extra = self.payload(extra="not allowed")
        cases["schema"] = extra
        bad_time = self.payload(observed_at_utc="2026-09-18 11:59:00")
        cases["time"] = bad_time
        bad_checked = self.payload()
        bad_checked["observations"][0]["checked_utc"] = "2026-09-18T12:00:00+00:00"
        cases["checked_time"] = bad_checked
        bad_head = self.payload()
        bad_head["observations"][0]["local_head"] = r"D:\private\head"
        cases["head"] = bad_head
        bad_bool = self.payload()
        bad_bool["observations"][0]["runner_alive"] = "false"
        cases["boolean"] = bad_bool
        bad_age = self.payload()
        bad_age["observations"][0]["heartbeat_age_sec"] = -1
        cases["numeric"] = bad_age
        huge_age = self.payload()
        huge_age["observations"][0]["heartbeat_age_sec"] = 10 ** 400
        cases["numeric_overflow"] = huge_age
        bad_exit = self.payload()
        bad_exit["observations"][0]["result"]["exit"] = "0"
        cases["exit_type"] = bad_exit
        for name, payload in cases.items():
            with self.subTest(name=name):
                result = self.project(payload)
                self.assertEqual(result["status"], "UNAVAILABLE")
                self.assertEqual(result["reason"], "INVALID_INPUT")
                self.assertEqual(result["observations"], [])

    def test_duplicate_and_conflicting_lane_job_identities_are_unavailable(self):
        for changes in (
            {},
            {"job_id": "another-job"},
            {"lane_id": "ANOTHER-LANE"},
        ):
            payload = self.payload()
            second = copy.deepcopy(payload["observations"][0])
            second.update(changes)
            payload["observations"].append(second)
            with self.subTest(changes=changes):
                result = self.project(payload)
                self.assertEqual((result["status"], result["reason"]), ("UNAVAILABLE", "INVALID_INPUT"))

    def test_stale_future_and_canonical_mismatch_remain_fail_visible(self):
        stale = self.payload(observed_at_utc="2026-09-17T10:00:00Z")
        stale["observations"][0]["checked_utc"] = "2026-09-17T09:59:00Z"
        stale["observations"][0]["result"]["ended"] = "2026-09-17T09:58:20Z"
        stale_result = self.project(stale)
        self.assertEqual((stale_result["status"], stale_result["freshness"], stale_result["reason"]),
                         ("UNAVAILABLE", "STALE", "STALE_OBSERVATION"))
        self.assertEqual(stale_result["observations"][0]["freshness"], "STALE")

        future = self.payload(observed_at_utc="2026-09-18T12:06:00Z")
        future["observations"][0]["checked_utc"] = "2026-09-18T12:05:30Z"
        future["observations"][0]["result"]["ended"] = "2026-09-18T12:05:20Z"
        future_result = self.project(future)
        self.assertEqual((future_result["status"], future_result["freshness"], future_result["reason"]),
                         ("UNAVAILABLE", "FUTURE", "FUTURE_OBSERVATION"))

        mismatch = self.payload(canonical_observed_sha="0" * 40)
        mismatch_result = self.project(mismatch)
        self.assertEqual(mismatch_result["binding_state"], "DIFFERENT_CANONICAL_SHA")
        self.assertEqual(mismatch_result["reason"], "CANONICAL_BINDING_MISMATCH")

    def test_hostile_paths_credentials_and_worker_prose_are_not_projected(self):
        hostile_values = (
            r"D:\EA_LAB_CONTROL\jobs\secret",
            "../../private",
            "https://example.invalid/token=secret",
            "account-463666728",
            "password=do-not-copy",
            "token-secret-abc",
            "api_key-private",
            "worker says type continue",
        )
        for hostile in hostile_values:
            payload = self.payload()
            payload["observations"][0]["job_id"] = hostile
            with self.subTest(hostile=hostile):
                result = self.project(payload)
                blob = json.dumps(result)
                self.assertEqual(result["reason"], "INVALID_INPUT")
                self.assertNotIn(hostile, blob)
                self.assertNotIn("private", blob.lower())
                self.assertNotIn("continue", blob.lower())

    def test_terminal_result_mismatch_is_rejected_without_promoting_scope(self):
        bad_rows = []
        complete_nonzero = self.payload()
        complete_nonzero["observations"][0]["result"]["exit"] = 1
        bad_rows.append(complete_nonzero)
        active_terminal = self.payload()
        active_terminal["observations"][0]["durable_state"] = "RUNNING"
        active_terminal["observations"][0]["observed_state"] = "RUNNING"
        active_terminal["observations"][0]["runner_alive"] = True
        bad_rows.append(active_terminal)
        wrong_state = self.payload()
        wrong_state["observations"][0]["result"]["state"] = "FAILED"
        bad_rows.append(wrong_state)
        observed_mismatch = self.payload()
        observed_mismatch["observations"][0]["observed_state"] = "RUNNING"
        bad_rows.append(observed_mismatch)
        for payload in bad_rows:
            self.assertEqual(self.project(payload)["reason"], "INVALID_INPUT")

        valid = self.project()
        row = valid["observations"][0]
        self.assertEqual((row["durable_state"], row["result"]["exit"]), ("COMPLETE", 0))
        self.assertEqual(
            (row["deliverable_status"], row["review_status"], row["canonical_status"]),
            ("UNKNOWN", "UNKNOWN", "UNKNOWN"),
        )

    def test_projection_is_deterministic_and_sorts_safe_identities(self):
        payload = self.payload()
        second = copy.deepcopy(payload["observations"][0])
        second.update({"lane_id": "A-LANE", "job_id": "a-job"})
        payload["observations"] = [payload["observations"][0], second]
        first = self.project(payload)
        second_result = self.project(payload)
        self.assertEqual(first, second_result)
        self.assertEqual([row["lane_id"] for row in first["observations"]], ["A-LANE", "ORDER-OWNER-CONTROL-V0"])

    def test_builder_optional_input_preserves_absent_and_valid_contracts(self):
        absent_out = Path(self.temp.name) / "absent"
        absent = build_index.build(ROOT, CANONICAL_SHA, absent_out, AS_OF, CANONICAL_SHA, None)
        self.assertEqual(absent["owner_operations"]["reason"], "NOT_PROVIDED")

        self.path.write_text(json.dumps(self.payload()), encoding="utf-8")
        valid_out = Path(self.temp.name) / "valid"
        valid = build_index.build(
            ROOT, CANONICAL_SHA, valid_out, AS_OF, CANONICAL_SHA, None,
            None, None, self.path,
        )
        self.assertEqual(valid["owner_operations"]["status"], "AVAILABLE")
        generated = json.loads((valid_out / "report_index.json").read_text(encoding="utf-8"))
        self.assertEqual(generated["owner_operations"], valid["owner_operations"])

    def test_cli_exposes_only_optional_job_observations_input(self):
        help_text = subprocess.check_output(
            [sys.executable, str(ROOT / "tools" / "mobile_report_hub" / "build_index.py"), "--help"],
            text=True,
        )
        self.assertIn("--job-observations", help_text)


if __name__ == "__main__":
    unittest.main()
