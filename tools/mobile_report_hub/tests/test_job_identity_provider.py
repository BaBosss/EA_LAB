import copy
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "mobile_report_hub"))

from job_identity_provider import ProviderError, adapt_bundle  # noqa: E402
import owner_operations  # noqa: E402


HEAD = "a" * 40
BASE = "b" * 40
LANE = "lane-one"
JOB = "job-one"
CAPTURED = "2026-09-18T12:00:00.0000000Z"


def canonical_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")


class BundleFixture:
    def __init__(self, root: Path):
        self.root = root
        self.bundle = root / "bundle"
        self.bundle.mkdir(parents=True)
        self.repo = root / "repo"
        self.leases = root / "leases"
        self.jobs = root / "jobs"
        for path in (self.repo, self.leases, self.jobs):
            path.mkdir()
        self.lease = {
            "schema_version": "EA_LAB_JOB_IDENTITY_LEASE_V1",
            "lane_id": LANE,
            "job_id": JOB,
            "base_sha": BASE,
        }
        self.job = {
            "job_id": JOB,
            "file_path": "C:\\private\\worker.exe",
            "arg_count": 0,
            "arg_hash": "private",
            "timeout_sec": 3600,
            "heartbeat_sec": 5,
            "worktree": "C:\\private\\worktree",
            "base_sha": BASE,
            "stage": "fixture",
            "postcondition_file_path": "",
            "postcondition_arg_count": 0,
            "postcondition_arg_hash": "private",
            "created_utc": "2026-09-18T11:00:00.0000000Z",
        }
        self.state = {
            "job_id": JOB,
            "state": "COMPLETE",
            "runner_pid": 101,
            "runner_start_utc": "2026-09-18T11:00:00.0000001Z",
            "child_pid": 102,
            "child_start_utc": "2026-09-18T11:00:01.0000001Z",
            "started_utc": "2026-09-18T11:00:00.0000000Z",
            "ended_utc": "2026-09-18T11:10:00.0000001Z",
            "exit_code": 0,
            "postcondition_exit_code": None,
        }
        self.result = {
            "job_id": JOB,
            "state": "COMPLETE",
            "exit_code": 0,
            "runner_pid": 101,
            "child_pid": 102,
            "ended_utc": "2026-09-18T11:10:00.0000001Z",
            "reason": "",
            "postcondition_exit_code": None,
        }
        self.checks = [
            self.check("runner", 101, self.state["runner_start_utc"], "RECORDED_PROCESS_NOT_PRESENT"),
            self.check("child", 102, self.state["child_start_utc"], "RECORDED_PROCESS_NOT_PRESENT"),
            self.check("postcondition", None, None, "RECORDED_PROCESS_NOT_PRESENT", "NOT_CONFIGURED"),
        ]

    @staticmethod
    def check(role, pid, expected, identity, query="NOT_PRESENT"):
        return {
            "lane_id": LANE,
            "job_id": JOB,
            "role": role,
            "pid": pid,
            "expected_creation_utc": expected,
            "current_creation_utc": expected if identity == "MATCHING_RECORDED_PROCESS" else None,
            "identity": identity,
            "query_status": query,
            "checked_utc": CAPTURED,
        }

    def write(self, mutate_manifest=None):
        source_values = {
            "helper": b"function Get-LjrProcessSnapshot {}\n",
            "lease": canonical_bytes(self.lease),
            "job": canonical_bytes(self.job),
            "state": canonical_bytes(self.state),
            "heartbeat": None,
            "result": None if self.result is None else canonical_bytes(self.result),
        }
        sources = []
        for kind, data in source_values.items():
            lane_id = None if kind == "helper" else LANE
            sentinel = "ABSENT" if data is None else hashlib.sha256(data).hexdigest()
            fingerprint = {
                "presence": "ABSENT" if data is None else "PRESENT",
                "sha256": sentinel,
                "length": 0 if data is None else len(data),
                "last_write_utc": None if data is None else "2026-09-18T11:59:00.0000000Z",
            }
            relative = None
            if data is not None:
                relative = "sources/shared/helper.ps1" if kind == "helper" else f"sources/{LANE}/{kind}.json"
                target = self.bundle / Path(relative)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            sources.append({
                "lane_id": lane_id,
                "kind": kind,
                "presence": fingerprint["presence"],
                "relative_path": relative,
                "sha256": sentinel,
                "length": fingerprint["length"],
                "last_write_utc": fingerprint["last_write_utc"],
                "before": copy.deepcopy(fingerprint),
                "after": copy.deepcopy(fingerprint),
            })
        manifest = {
            "schema_version": "EA_LAB_JOB_IDENTITY_CAPTURE_V1",
            "status": "AVAILABLE",
            "captured_at_utc": CAPTURED,
            "repo_root": str(self.repo.resolve()),
            "expected_head": HEAD,
            "lease_root": str(self.leases.resolve()),
            "jobs_root": str(self.jobs.resolve()),
            "requested_lane_ids": [LANE],
            "sources": sources,
            "process_checks": copy.deepcopy(self.checks),
        }
        if mutate_manifest:
            mutate_manifest(manifest)
        path = self.bundle / "manifest.json"
        path.write_bytes(canonical_bytes(manifest))
        return path


class JobIdentityProviderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.fixture = BundleFixture(self.root)

    def tearDown(self):
        self.temp.cleanup()

    def adapt(self, manifest=None, name="publication"):
        manifest = manifest or self.fixture.write()
        return adapt_bundle(manifest, self.root / name)

    def test_terminal_complete_absent_processes_preserves_history(self):
        dto, receipt = self.adapt()
        row = dto["observations"][0]
        self.assertEqual("COMPLETE", row["durable_state"])
        self.assertEqual("COMPLETE", row["result"]["state"])
        self.assertEqual(False, row["runner_alive"])
        self.assertEqual(False, row["postcondition_alive"])
        self.assertEqual("REFUSE_RETRY", row["retry_decision"])
        self.assertEqual(receipt["public_output_sha256"], hashlib.sha256((self.root / "publication" / "job_observations.json").read_bytes()).hexdigest())

    def test_matching_active_processes(self):
        self.fixture.state.update({"state": "RUNNING"})
        self.fixture.state.pop("ended_utc")
        self.fixture.state.pop("exit_code")
        self.fixture.result = None
        self.fixture.checks[0] = self.fixture.check("runner", 101, self.fixture.state["runner_start_utc"], "MATCHING_RECORDED_PROCESS", "PRESENT")
        self.fixture.checks[1] = self.fixture.check("child", 102, self.fixture.state["child_start_utc"], "MATCHING_RECORDED_PROCESS", "PRESENT")
        dto, _ = self.adapt()
        row = dto["observations"][0]
        self.assertEqual("RUNNING", row["observed_state"])
        self.assertTrue(row["runner_alive"])
        self.assertTrue(row["child_alive"])
        self.assertEqual("UNKNOWN", row["retry_decision"])

    def test_active_missing_process_maps_lost_process(self):
        self.fixture.state.update({"state": "RUNNING"})
        self.fixture.state.pop("ended_utc")
        self.fixture.state.pop("exit_code")
        self.fixture.result = None
        dto, _ = self.adapt()
        self.assertEqual("LOST_PROCESS", dto["observations"][0]["observed_state"])

    def test_reused_pid_is_not_old_job_liveness(self):
        self.fixture.checks[2] = self.fixture.check(
            "postcondition", 20008, "2026-09-18T11:09:59.1831533Z", "DIFFERENT_CREATION_IDENTITY", "PRESENT"
        )
        self.fixture.checks[2]["current_creation_utc"] = "2026-09-18T11:10:01.0812905Z"
        self.fixture.state.update({
            "postcondition_pid": 20008,
            "postcondition_start_utc": "2026-09-18T11:09:59.1831533Z",
            "postcondition_exit_code": 0,
        })
        self.fixture.job["postcondition_file_path"] = "C:\\private\\check.exe"
        self.fixture.result["postcondition_exit_code"] = 0
        self.fixture.state["postcondition_exit_code"] = 0
        dto, receipt = self.adapt()
        self.assertFalse(dto["observations"][0]["postcondition_alive"])
        self.assertEqual("COMPLETE", dto["observations"][0]["result"]["state"])
        private = receipt["process_identity_evidence"][0]["roles"][2]
        self.assertEqual("DIFFERENT_CREATION_IDENTITY", private["identity"])

    def test_same_pid_different_100ns_is_mismatch(self):
        expected = "2026-09-18T11:00:00.0000001Z"
        check = self.fixture.check("runner", 101, expected, "DIFFERENT_CREATION_IDENTITY", "PRESENT")
        check["current_creation_utc"] = "2026-09-18T11:00:00.0000002Z"
        self.fixture.checks[0] = check
        dto, _ = self.adapt()
        self.assertFalse(dto["observations"][0]["runner_alive"])

    def test_timezone_equivalent_creation_times_match(self):
        check = self.fixture.check("runner", 101, "2026-09-18T18:00:00.0000001+07:00", "MATCHING_RECORDED_PROCESS", "PRESENT")
        check["current_creation_utc"] = "2026-09-18T11:00:00.0000001Z"
        self.fixture.checks[0] = check
        self.fixture.state["runner_start_utc"] = check["expected_creation_utc"]
        dto, _ = self.adapt()
        self.assertTrue(dto["observations"][0]["runner_alive"])

    def test_unknown_or_inaccessible_identity_refuses_whole_snapshot(self):
        self.fixture.checks[0] = self.fixture.check("runner", 101, self.fixture.state["runner_start_utc"], "UNKNOWN", "INACCESSIBLE")
        with self.assertRaisesRegex(ProviderError, "unknown process identity"):
            self.adapt()

    def test_terminal_live_child_or_postcondition_refuses(self):
        self.fixture.checks[1] = self.fixture.check("child", 102, self.fixture.state["child_start_utc"], "MATCHING_RECORDED_PROCESS", "PRESENT")
        with self.assertRaisesRegex(ProviderError, "terminal child or postcondition"):
            self.adapt()

    def test_postcondition_running_requires_matching_postcondition(self):
        self.fixture.state.update({
            "state": "POSTCONDITION_RUNNING",
            "postcondition_pid": 103,
            "postcondition_start_utc": "2026-09-18T11:09:00.0000001Z",
        })
        self.fixture.state.pop("ended_utc")
        self.fixture.state.pop("exit_code")
        self.fixture.result = None
        self.fixture.job["postcondition_file_path"] = "C:\\private\\check.exe"
        self.fixture.checks[2] = self.fixture.check("postcondition", 103, self.fixture.state["postcondition_start_utc"], "MATCHING_RECORDED_PROCESS", "PRESENT")
        dto, _ = self.adapt()
        self.assertEqual("POSTCONDITION_RUNNING", dto["observations"][0]["observed_state"])

    def test_null_postcondition_is_absent_only_when_not_configured(self):
        self.fixture.job["postcondition_file_path"] = "C:\\private\\check.exe"
        self.fixture.result["postcondition_exit_code"] = 0
        self.fixture.state["postcondition_exit_code"] = 0
        with self.assertRaisesRegex(ProviderError, "postcondition metadata"):
            self.adapt()

    def test_result_chronology_conflict_refuses(self):
        self.fixture.result["ended_utc"] = "2026-09-18T12:01:00.0000000Z"
        with self.assertRaisesRegex(ProviderError, "future|chronology"):
            self.adapt()

    def test_forged_future_process_start_refuses(self):
        self.fixture.checks[0]["current_creation_utc"] = "2026-09-19T11:00:00.0000001Z"
        self.fixture.checks[0]["identity"] = "DIFFERENT_CREATION_IDENTITY"
        self.fixture.checks[0]["query_status"] = "PRESENT"
        with self.assertRaisesRegex(ProviderError, "future"):
            self.adapt()

    def test_source_mutation_hash_mismatch_refuses(self):
        manifest = self.fixture.write()
        (self.fixture.bundle / f"sources/{LANE}/state.json").write_bytes(b"{}\n")
        with self.assertRaisesRegex(ProviderError, "hash|length"):
            self.adapt(manifest)

    def test_changed_or_absent_present_sentinel_refuses(self):
        def changed(manifest):
            source = next(item for item in manifest["sources"] if item["kind"] == "heartbeat")
            source["after"]["presence"] = "PRESENT"
        with self.assertRaisesRegex(ProviderError, "changed during capture|hash"):
            self.adapt(self.fixture.write(changed))

    def test_duplicate_json_key_refuses(self):
        manifest = self.fixture.write()
        manifest.write_text('{"schema_version":"EA_LAB_JOB_IDENTITY_CAPTURE_V1","schema_version":"x"}', encoding="utf-8")
        with self.assertRaisesRegex(ProviderError, "duplicate JSON key"):
            self.adapt(manifest)

    def test_duplicate_lane_or_source_refuses(self):
        def duplicate(manifest):
            manifest["requested_lane_ids"].append(LANE)
        with self.assertRaisesRegex(ProviderError, "duplicate"):
            self.adapt(self.fixture.write(duplicate))

    def test_extra_keys_and_bad_types_refuse(self):
        self.fixture.state["surprise"] = True
        with self.assertRaisesRegex(ProviderError, "keys"):
            self.adapt()

    def test_nonfinite_or_invalid_json_refuses(self):
        manifest = self.fixture.write()
        data = manifest.read_text(encoding="utf-8").replace('"status": "AVAILABLE"', '"status": NaN')
        manifest.write_text(data, encoding="utf-8")
        with self.assertRaises(ProviderError):
            self.adapt(manifest)

    def test_unsafe_ids_and_mismatched_binding_refuse(self):
        self.fixture.lease["lane_id"] = "../escape"
        with self.assertRaises(ProviderError):
            self.adapt()
        self.fixture = BundleFixture(self.root / "second")
        self.fixture.lease["base_sha"] = "c" * 40
        with self.assertRaisesRegex(ProviderError, "base"):
            self.adapt(name="publication-two")

    def test_manifest_path_escape_refuses(self):
        outside = self.root / "outside.json"
        outside.write_text("{}", encoding="utf-8")
        def escape(manifest):
            source = next(item for item in manifest["sources"] if item["kind"] == "state")
            source["relative_path"] = "../outside.json"
        with self.assertRaisesRegex(ProviderError, "path"):
            self.adapt(self.fixture.write(escape))

    @unittest.skipUnless(hasattr(os, "symlink"), "symlink unsupported")
    def test_symlink_source_refuses(self):
        manifest = self.fixture.write()
        target = self.fixture.bundle / f"sources/{LANE}/state.json"
        original = target.read_bytes()
        target.unlink()
        try:
            os.symlink(self.root / "outside-state.json", target)
            (self.root / "outside-state.json").write_bytes(original)
        except OSError as error:
            self.skipTest(f"symlink unavailable: {error}")
        with self.assertRaisesRegex(ProviderError, "reparse|symlink"):
            self.adapt(manifest)

    def test_output_collision_and_overlap_refuse_without_overwrite(self):
        manifest = self.fixture.write()
        output = self.root / "publication"
        output.mkdir()
        marker = output / "keep.txt"
        marker.write_text("keep", encoding="utf-8")
        with self.assertRaisesRegex(ProviderError, "fresh"):
            adapt_bundle(manifest, output)
        self.assertEqual("keep", marker.read_text(encoding="utf-8"))
        with self.assertRaisesRegex(ProviderError, "overlap"):
            adapt_bundle(manifest, self.fixture.bundle / "nested")

    def test_relative_manifest_or_output_path_refuses(self):
        manifest = self.fixture.write()
        with self.assertRaisesRegex(ProviderError, "absolute"):
            adapt_bundle(Path("manifest.json"), self.root / "absolute-output")
        with self.assertRaisesRegex(ProviderError, "absolute"):
            adapt_bundle(manifest, Path("relative-output"))

    def test_empty_valid_snapshot_and_refused_snapshot_are_distinct(self):
        def empty(manifest):
            manifest["requested_lane_ids"] = []
            manifest["sources"] = [item for item in manifest["sources"] if item["kind"] == "helper"]
            manifest["process_checks"] = []
        manifest = self.fixture.write(empty)
        shutil.rmtree(self.fixture.bundle / "sources" / LANE)
        dto, _ = self.adapt(manifest)
        self.assertEqual([], dto["observations"])
        self.assertTrue((self.root / "publication" / "publication_receipt.json").exists())

        self.fixture = BundleFixture(self.root / "refused")
        manifest = self.fixture.write(lambda value: value.update(status="UNAVAILABLE"))
        with self.assertRaisesRegex(ProviderError, "unavailable"):
            self.adapt(manifest, "refused-publication")
        refused = self.root / "refused-publication"
        self.assertFalse((refused / "job_observations.json").exists())
        self.assertTrue((refused / "INCOMPLETE.json").exists())

    def test_deterministic_byte_reproduction(self):
        manifest = self.fixture.write()
        self.adapt(manifest, "one")
        self.adapt(manifest, "two")
        self.assertEqual(
            (self.root / "one" / "job_observations.json").read_bytes(),
            (self.root / "two" / "job_observations.json").read_bytes(),
        )

    def test_v0_positive_compatibility(self):
        dto, _ = self.adapt()
        self.assertEqual(
            {"schema_version", "source_kind", "observed_at_utc", "canonical_observed_sha", "observations"},
            set(dto),
        )
        self.assertEqual(
            {
                "lane_id", "job_id", "checked_utc", "observed_state", "durable_state",
                "runner_alive", "child_alive", "postcondition_alive", "heartbeat_age_sec",
                "retry_decision", "result",
            },
            set(dto["observations"][0]),
        )
        projected = owner_operations.project(
            self.root / "publication" / "job_observations.json", HEAD, "2026-09-18T12:01:00Z"
        )
        self.assertEqual("AVAILABLE", projected["status"])
        self.assertEqual("EA_LAB_JOB_OBSERVATIONS_V1", dto["schema_version"])

    def test_v0_existing_freshness_policy_marks_stale(self):
        self.adapt()
        projected = owner_operations.project(
            self.root / "publication" / "job_observations.json", HEAD, "2026-09-20T12:00:00Z"
        )
        self.assertEqual("UNAVAILABLE", projected["status"])
        self.assertEqual("STALE_OBSERVATION", projected["reason"])

    def test_v0_refusal_compatibility_for_unsupported_state(self):
        self.fixture.state["state"] = "CANCEL_REQUESTED"
        self.fixture.result = None
        with self.assertRaisesRegex(ProviderError, "unsupported|ambiguous"):
            self.adapt()
        self.assertFalse((self.root / "publication" / "job_observations.json").exists())


if __name__ == "__main__":
    unittest.main()
