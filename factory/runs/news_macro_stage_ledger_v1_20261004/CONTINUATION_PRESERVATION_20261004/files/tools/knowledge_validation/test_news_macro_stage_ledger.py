"""Twelve preregistered FIXTURE_ONLY cases; no producer or runtime invocation."""
from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import typing
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("news_macro_stage_ledger", Path(__file__).with_name("news_macro_stage_ledger.py"))
ledger = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ledger)

RUN_DIR = Path(__file__).resolve().parents[2] / "factory/runs/news_macro_stage_ledger_v1_20261004"
PLAN = json.loads((RUN_DIR / "CASES_FROZEN.json").read_text(encoding="utf-8"))
EXPECTED = {case["case_id"]: case for case in PLAN["cases"]}
CAPTURED = {}


def fixture() -> dict:
    manifest = {
        "schema_version": ledger.SCHEMA, "authority": "OFFLINE_ONLY", "label": "FIXTURE_ONLY",
        "run_id": "FIXTURE-RUN-001", "source": {"source_id": "FIXTURE-FEED", "artifact_sha256": "a" * 64},
        "as_of_utc": "2026-10-04T12:00:00Z",
        "clocks": {"observation_time_utc": "2026-10-03T16:00:00Z", "release_time_utc": "2026-10-03T17:00:00Z",
                   "available_at_utc": "2026-10-04T09:00:00Z", "fetch_time_utc": "2026-10-04T10:01:00Z"},
        "stages": [], "evidence": [], "last_good": None, "known_failures": [],
    }
    for index, stage in enumerate(ledger.STAGES, 1):
        record = {"stage": stage, "run_id": manifest["run_id"], **manifest["source"],
                  "at_utc": f"2026-10-04T10:{index:02d}:00Z", "status": "PASS",
                  "reason": "FIXTURE_EXPLICIT_ATTESTATION", "evidence_id": stage.lower()}
        payload = {key: record[key] for key in ledger.BINDING}
        payload.update(kind=ledger.KINDS[stage], basis="EXPLICIT_STAGE_ATTESTATION")
        if stage == "TRANSFER_REQUESTED":
            payload.update(receiver_id="FIXTURE-VPS", destination="FIXTURE-Common/Files/feed.csv")
        if stage == "TRANSFERRED":
            payload.update(receiver_id="FIXTURE-VPS", destination="FIXTURE-Common/Files/feed.csv",
                           request_evidence_id="transfer_requested", received_sha256="a" * 64)
        if stage == "CONSUMER_OBSERVED":
            payload.update(consumer_id="FIXTURE-EA", observed_sha256="a" * 64)
        if stage == "EFFECTIVE":
            payload.update(consumer_id="FIXTURE-EA", observation_evidence_id="consumer_observed",
                           effective_sha256="a" * 64)
        manifest["stages"].append(record)
        manifest["evidence"].append({"evidence_id": stage.lower(), "payload": payload,
                                    "sha256": ledger.payload_sha256(payload)})
    return manifest


def rehash(manifest: dict) -> None:
    for evidence in manifest["evidence"]:
        evidence["sha256"] = ledger.payload_sha256(evidence["payload"])


def remove_stage(manifest: dict, stage: str) -> None:
    manifest["stages"] = [row for row in manifest["stages"] if row["stage"] != stage]
    manifest["evidence"] = [row for row in manifest["evidence"] if row["evidence_id"] != stage.lower()]


class FrozenCases(unittest.TestCase):
    def check_case(self, case_id: str, manifest: dict) -> dict:
        result = ledger.validate_manifest(manifest)
        expected = EXPECTED[case_id]
        self.assertEqual(result["validation_status"], expected["expected_validation"], result["errors"])
        if expected["expected_stages"] is not None:
            self.assertEqual([row["status"] for row in result["stages"]], expected["expected_stages"])
        self.assertEqual(result["actual_run_green"], "UNKNOWN")
        self.assertFalse(result["runtime_effectiveness_certified"])
        CAPTURED[case_id] = (copy.deepcopy(manifest), copy.deepcopy(result))
        return result

    def test_positive_chain(self):
        result = self.check_case("positive_chain", fixture())
        self.assertEqual([row["stage"] for row in result["stages"]], list(ledger.STAGES))
        for row in result["stages"]:
            self.assertEqual(row["artifact_sha256"], "a" * 64)
            self.assertEqual(len(row["evidence_sha256"]), 64)

    def test_no_stages(self):
        manifest = fixture()
        manifest.update(stages=[], evidence=[])
        self.check_case("no_stages", manifest)

    def test_missing_classification(self):
        manifest = fixture()
        remove_stage(manifest, "CLASSIFIED")
        self.check_case("missing_classification", manifest)

    def test_wrong_hash(self):
        manifest = fixture()
        manifest["stages"][1]["artifact_sha256"] = "b" * 64
        self.check_case("wrong_hash", manifest)

    def test_wrong_run(self):
        manifest = fixture()
        manifest["evidence"][5]["payload"]["run_id"] = "FIXTURE-OTHER-RUN"
        rehash(manifest)
        self.check_case("wrong_run", manifest)

    def test_malformed_or_future_time(self):
        manifest = fixture()
        manifest["stages"][1]["at_utc"] = "yesterday"
        self.check_case("malformed_or_future_time", manifest)
        for future in ("2026-10-05T10:02:00Z", "2026-13-04T10:02:00Z"):
            with self.subTest(time=future):
                changed = fixture()
                changed["stages"][1]["at_utc"] = future
                self.assertEqual(ledger.validate_manifest(changed)["validation_status"], "REFUSED")

    def test_last_good(self):
        manifest = fixture()
        manifest.update(stages=[], evidence=[], last_good={
            "run_id": "FIXTURE-PRIOR-RUN", "source_id": "FIXTURE-FEED",
            "artifact_sha256": "b" * 64, "at_utc": "2026-10-03T10:00:00Z",
        })
        result = self.check_case("last_good", manifest)
        self.assertEqual(result["last_good"], manifest["last_good"])
        self.assertFalse(result["last_good_used_for_current_run"])

    def test_transfer_without_receipt(self):
        manifest = fixture()
        manifest["evidence"] = [row for row in manifest["evidence"] if row["evidence_id"] != "transferred"]
        result = self.check_case("transfer_without_receipt", manifest)
        self.assertEqual(result["stages"][5]["reason"], "MISSING_EXPLICIT_RECEIPT")
        for basis in ("RCLONE_EXIT_0", "FILE_EXISTS", "MTIME_FRESH", "ABSENT_FAILURE_TOKEN"):
            with self.subTest(basis=basis):
                changed = fixture()
                changed["evidence"][5]["payload"]["basis"] = basis
                rehash(changed)
                self.assertEqual(ledger.validate_manifest(changed)["validation_status"], "REFUSED")

    def test_observed_without_effect(self):
        manifest = fixture()
        remove_stage(manifest, "EFFECTIVE")
        self.check_case("observed_without_effect", manifest)

    def test_known_failures(self):
        manifest = fixture()
        contract = json.loads((RUN_DIR / "CONTRACT.json").read_text(encoding="utf-8"))
        manifest["known_failures"] = contract["acceptance_tokens"]
        for row in (manifest["stages"][1], manifest["evidence"][1]["payload"]):
            row.update(status="FAIL", reason="FIXTURE_VALIDATION_FAILURE_LAST_GOOD_RETAINED")
        rehash(manifest)
        result = self.check_case("known_failures", manifest)
        self.assertEqual(result["known_failures"], contract["acceptance_tokens"])
        self.assertEqual(result["stages"][1]["reason"], manifest["stages"][1]["reason"])

    def test_clock_distinction(self):
        manifest = fixture()
        result = self.check_case("clock_distinction", manifest)
        self.assertEqual(result["clocks"], manifest["clocks"])
        self.assertEqual(len(set(result["clocks"].values())), 4)
        manifest["clocks"]["release_time_utc"] = None
        result = ledger.validate_manifest(manifest)
        self.assertEqual(result["validation_status"], "PASS")
        self.assertIsNone(result["clocks"]["release_time_utc"])
        manifest["stages"][2]["at_utc"] = "2026-10-04T09:00:00Z"
        self.assertEqual(ledger.validate_manifest(manifest)["validation_status"], "REFUSED")

    def test_deterministic_bytes_and_schema(self):
        manifest = fixture()
        result = self.check_case("deterministic_bytes_and_schema", manifest)
        encoded = ledger.canonical_bytes(result)
        self.assertEqual(encoded, ledger.canonical_bytes(ledger.validate_manifest(copy.deepcopy(manifest))))
        reordered = dict(reversed(list(manifest.items())))
        self.assertEqual(encoded, ledger.canonical_bytes(ledger.validate_manifest(reordered)))
        mutations = [
            lambda m: m.update(schema_version="unknown"),
            lambda m: m.update(authority="LIVE"),
            lambda m: m.update(stages={}),
            lambda m: m.update(evidence="not-a-list"),
            lambda m: m.update(known_failures=[False]),
            lambda m: m["stages"].append(copy.deepcopy(m["stages"][0])),
            lambda m: m["evidence"][0].update(sha256="b" * 64),
            lambda m: m["stages"][0].update(status=[]),
            lambda m: m["clocks"].update(fetch_time_utc="2026-10-05T00:00:00Z"),
            lambda m: m["evidence"][5]["payload"].update(receiver_id="OTHER"),
            lambda m: m["evidence"][5]["payload"].update(request_evidence_id="OTHER"),
            lambda m: m["evidence"][5]["payload"].update(received_sha256="b" * 64),
            lambda m: m["evidence"][7]["payload"].update(consumer_id="OTHER"),
            lambda m: m["evidence"][7]["payload"].update(observation_evidence_id="OTHER"),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(schema_mutation=index):
                changed = fixture()
                mutate(changed)
                if index != 6 and isinstance(changed["evidence"], list):
                    rehash(changed)
                self.assertEqual(ledger.validate_manifest(changed)["validation_status"], "REFUSED")
        self.assertEqual(ledger.validate_manifest(None)["validation_status"], "REFUSED")
        tree = ast.parse(Path(ledger.__file__).read_text(encoding="utf-8"))
        imported = {item.name.split(".")[0] for node in ast.walk(tree)
                    if isinstance(node, ast.Import) for item in node.names}
        self.assertFalse(imported & {"socket", "urllib", "requests", "subprocess", "os"})
        for name in ("canonical_bytes", "payload_sha256", "validate_manifest", "main"):
            self.assertTrue(typing.get_type_hints(getattr(ledger, name)))
        with tempfile.TemporaryDirectory(dir=RUN_DIR) as directory:
            path = Path(directory) / "fixture.json"
            path.write_bytes(ledger.canonical_bytes(manifest))
            command = [sys.executable, "-B", str(Path(ledger.__file__)), "--input", str(path)]
            one = subprocess.run(command, capture_output=True, check=False)
            two = subprocess.run(command, capture_output=True, check=False)
            self.assertEqual((one.returncode, two.returncode), (0, 0))
            self.assertEqual(one.stdout, two.stdout)
            self.assertEqual(one.stdout, encoded)
            path.write_text('{"schema_version":"one","schema_version":"two"}', encoding="utf-8")
            duplicate = subprocess.run(command, capture_output=True, check=False)
            self.assertEqual(duplicate.returncode, 2)
            self.assertIn(b"duplicate JSON key", duplicate.stdout)
            path.write_text('{"run_id":1e999}', encoding="utf-8")
            numeric = subprocess.run(command, capture_output=True, check=False)
            self.assertEqual(numeric.returncode, 2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-evidence", action="store_true")
    args = parser.parse_args()
    suite = unittest.defaultTestLoader.loadTestsFromTestCase(FrozenCases)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if args.write_evidence:
        for case_id, (manifest, outcome) in sorted(CAPTURED.items()):
            (RUN_DIR / f"FIXTURE_{case_id}.json").write_bytes(ledger.canonical_bytes(manifest))
            (RUN_DIR / f"OUTCOME_{case_id}.json").write_bytes(ledger.canonical_bytes(outcome))
        summary = {"label": "FIXTURE_ONLY", "cases_frozen": len(EXPECTED), "tests_run": result.testsRun,
                   "failure_count": len(result.failures), "error_count": len(result.errors),
                   "passed": result.wasSuccessful(), "case_ids": sorted(CAPTURED),
                   "actual_run_green": "UNKNOWN",
                   "plan_sha256": hashlib.sha256((RUN_DIR / "CASES_FROZEN.json").read_bytes()).hexdigest()}
        (RUN_DIR / "RESULTS.json").write_bytes(ledger.canonical_bytes(summary))
    return 0 if result.wasSuccessful() and result.testsRun == len(EXPECTED) == 12 else 1


if __name__ == "__main__":
    raise SystemExit(main())
