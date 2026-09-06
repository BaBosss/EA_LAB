from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import unittest
from pathlib import Path

from legacy_guard_fixture_adapter import assert_legacy_expectation, legacy_case_to_production_package

TOOL_ROOT = Path(__file__).resolve().parents[1]
FIXTURE_ROOT = Path(__file__).resolve().parent / "fixtures"
SPEC = importlib.util.spec_from_file_location("offline_replay_validator", TOOL_ROOT / "offline_replay_validator.py")
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def base_package() -> dict:
    return {
        "schema_version": "ea_lab_offline_replay_package/1",
        "classification": "SYNTHETIC_CONTRACT_TEST_ONLY",
        "dataset_id": "SYNTHETIC",
        "dataset_version": "v1",
        "source_snapshot_sha256": "0" * 64,
        "decision_at_utc": "2026-03-02T12:30:00Z",
        "coverage": {"state": "COMPLETE", "start_utc": "2026-03-02T00:00:00Z", "end_utc": "2026-03-02T23:59:59Z"},
        "clock_mapping": {
            "version": "SYNTH-CLOCK-v1",
            "source_timezone": "UTC",
            "broker_timezone": "SYNTHETIC",
            "mapping_basis": "SYNTHETIC_CONTRACT_TEST",
        },
        "records": [
            {
                "record_id": "E1",
                "revision_id": "r1",
                "record_type": "NEWS_EVENT",
                "state": "PUBLISHED",
                "available_at_utc": "2026-03-02T12:00:00Z",
                "payload": {"actual": "ORIGINAL"},
            },
            {
                "record_id": "E1",
                "revision_id": "r2",
                "record_type": "NEWS_EVENT",
                "state": "REVISED",
                "available_at_utc": "2026-03-02T13:00:00Z",
                "payload": {"actual": "REVISION"},
            },
        ],
    }


class OfflineReplayValidatorTests(unittest.TestCase):
    def test_selects_original_and_withholds_future_revision(self) -> None:
        result = MODULE.qualify_replay_package(base_package())
        self.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        self.assertEqual("r1", result["selected_records"][0]["revision_id"])
        self.assertEqual(1, result["future_record_count"])
        self.assertFalse(result["historical_dataset_qualified"])
        self.assertIsNone(result["trade_policy_output"])

    def test_complete_no_events_is_distinct_from_incomplete_coverage(self) -> None:
        empty = base_package()
        empty["coverage"]["state"] = "COMPLETE_NO_EVENTS"
        empty["records"] = []
        self.assertEqual("QUALIFIED_EMPTY_NO_EVENTS", MODULE.qualify_replay_package(empty)["status"])
        for state, reason in MODULE.COVERAGE_REFUSALS.items():
            package = base_package()
            package["coverage"]["state"] = state
            result = MODULE.qualify_replay_package(package)
            self.assertEqual("REFUSED", result["status"])
            self.assertIn(reason, result["reason_codes"])

    def test_same_day_midnight_close_is_refused(self) -> None:
        package = base_package()
        package["decision_at_utc"] = "2026-03-02T00:00:00Z"
        package["records"] = [{
            "record_id": "CLOSE-1", "revision_id": "r1", "record_type": "DAILY_CLOSE", "state": "FINAL",
            "effective_at_utc": "2026-03-02T00:00:00Z", "available_at_utc": "2026-03-02T23:00:00Z", "payload": {"close": "SYNTHETIC"},
        }]
        result = MODULE.qualify_replay_package(package)
        self.assertEqual(["REFUSE_SAME_DAY_CLOSE_AT_MIDNIGHT"], result["reason_codes"])

    def test_conflicting_duplicate_and_policy_fields_refuse(self) -> None:
        package = base_package()
        package["records"].append({**package["records"][0], "state": "CANCELLED"})
        self.assertIn("REFUSE_CONFLICTING_DUPLICATE", MODULE.qualify_replay_package(package)["reason_codes"])
        package = base_package()
        package["policy_action"] = "BLOCK_NEW"
        self.assertIn("REFUSE_TRADING_POLICY_FIELD", MODULE.qualify_replay_package(package)["reason_codes"])

        nested_policy = base_package()
        nested_policy["records"][0]["payload"] = {"policy_action": "BLOCK"}
        self.assertIn("REFUSE_TRADING_POLICY_FIELD", MODULE.qualify_replay_package(nested_policy)["reason_codes"])

        invalid_identity = base_package()
        invalid_identity["records"][0]["record_id"] = None
        self.assertIn("INVALID_RECORD_IDENTITY_OR_TIME", MODULE.qualify_replay_package(invalid_identity)["reason_codes"])

    def test_unknown_clock_refuses(self) -> None:
        package = base_package()
        package["clock_mapping"]["version"] = "UNKNOWN"
        self.assertIn("REFUSE_CLOCK_MAPPING_UNVERSIONED", MODULE.qualify_replay_package(package)["reason_codes"])

    def test_vendored_fixture_matches_accepted_sha256(self) -> None:
        fixture = FIXTURE_ROOT / "guard_replay_synthetic_cases.json"
        provenance = json.loads((FIXTURE_ROOT / "guard_replay_synthetic_cases.provenance.json").read_text(encoding="utf-8"))
        self.assertEqual(provenance["source_sha256"], hashlib.sha256(fixture.read_bytes()).hexdigest())
        self.assertTrue(provenance["copy_is_byte_identical"])

    def test_prior_synthetic_sixteen_cases_use_production_qualifier(self) -> None:
        fixture = FIXTURE_ROOT / "guard_replay_synthetic_cases.json"
        suite = json.loads(fixture.read_text(encoding="utf-8"))
        self.assertEqual(16, len(suite["cases"]))
        for case in suite["cases"]:
            with self.subTest(case=case["case_id"]):
                package = legacy_case_to_production_package(case)
                result = MODULE.qualify_replay_package(package)
                assert_legacy_expectation(self, case, result)

    def test_cancelled_tentative_and_exact_duplicate_accounting(self) -> None:
        package = base_package()
        package["records"] = [
            {"record_id":"E1","revision_id":"r1","record_type":"NEWS_EVENT","state":"CANCELLED","available_at_utc":"2026-03-02T10:00:00Z"},
            {"record_id":"E2","revision_id":"r1","record_type":"NEWS_EVENT","state":"TENTATIVE","available_at_utc":"2026-03-02T10:00:00Z"},
        ]
        package["records"].append(copy.deepcopy(package["records"][1]))
        result = MODULE.qualify_replay_package(package)
        self.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        self.assertEqual(1, result["cancelled_record_count"])
        self.assertEqual(1, result["tentative_record_count"])
        self.assertEqual(1, result["exact_duplicate_count"])
        self.assertEqual([], result["selected_records"])


if __name__ == "__main__":
    unittest.main()
