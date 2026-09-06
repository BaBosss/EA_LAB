from __future__ import annotations

from typing import Any


def legacy_case_to_production_package(case: dict[str, Any]) -> dict[str, Any]:
    """Translate the accepted legacy fixture shape into the production package schema.

    This adapter is test-only. All qualification and selection behavior remains in
    offline_replay_validator.qualify_replay_package.
    """

    data = case["input"]
    case_type = case["case_type"]
    package: dict[str, Any] = {
        "schema_version": "ea_lab_offline_replay_package/1",
        "classification": "SYNTHETIC_CONTRACT_TEST_ONLY",
        "dataset_id": f"LEGACY-{case['case_id']}",
        "dataset_version": "accepted-20260906",
        "source_snapshot_sha256": "7eeb2d51423573be2d4c37bcd9621631c6baace0096943c8bde57c0319c27d01",
        "decision_at_utc": data.get("decision_at_utc", "2026-03-02T12:00:00Z"),
        "coverage": {
            "state": data["coverage_state"],
            "start_utc": "2026-03-01T00:00:00Z",
            "end_utc": "2026-03-03T00:00:00Z",
        },
        "clock_mapping": {
            "version": data["clock_mapping_version"],
            "source_timezone": "UTC",
            "broker_timezone": "SYNTHETIC",
            "mapping_basis": "ACCEPTED_LEGACY_FIXTURE_ADAPTER",
        },
        "records": [],
    }

    if case_type == "VALUE_TIMELINE":
        package["records"] = [
            {
                "record_id": "LEGACY-VALUE",
                "revision_id": row["version"],
                "record_type": "NEWS_VALUE",
                "state": "PUBLISHED" if index == 0 else "REVISED",
                "available_at_utc": row["available_at_utc"],
                "payload": {key: value for key, value in row.items() if key not in {"version", "available_at_utc"}},
            }
            for index, row in enumerate(data["values"])
        ]
    elif case_type == "DAILY_CLOSE":
        package["records"] = [
            {
                "record_id": "LEGACY-DAILY-CLOSE",
                "revision_id": "v1",
                "record_type": "DAILY_CLOSE",
                "state": "FINAL",
                "effective_at_utc": data["effective_at_utc"],
                "available_at_utc": data["available_at_utc"],
            }
        ]
    elif case_type == "EVENT_STATE":
        package["records"] = [
            {
                "record_id": "LEGACY-EVENT",
                "revision_id": f"v{index}",
                "record_type": "NEWS_EVENT",
                **row,
            }
            for index, row in enumerate(data["state_history"], start=1)
        ]
    elif case_type == "DUPLICATE_SET":
        package["records"] = [
            {
                "record_id": row["event_id"],
                "revision_id": row["revision_id"],
                "record_type": "NEWS_EVENT",
                **{key: value for key, value in row.items() if key not in {"event_id", "revision_id"}},
            }
            for row in data["records"]
        ]
    return package


def assert_legacy_expectation(test: Any, case: dict[str, Any], result: dict[str, Any]) -> None:
    """Assert each legacy expectation against the production qualifier result."""

    expected = case["expected"]
    disposition = expected["disposition"]
    if disposition == "VISIBLE_AS_OF_DECISION":
        test.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        test.assertEqual(expected["visible_value_version"], result["selected_records"][0]["revision_id"])
    elif disposition == "WITHHOLD_FUTURE_VALUES":
        test.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        test.assertEqual([], result["selected_records"])
        test.assertGreater(result["future_record_count"], 0)
    elif disposition == "REFUSE_SAME_DAY_CLOSE_AT_MIDNIGHT":
        test.assertIn(disposition, result["reason_codes"])
    elif disposition == "QUALIFIED_EMPTY_NO_EVENTS":
        test.assertEqual(disposition, result["status"])
    elif disposition in {"REFUSE_PARTIAL_COVERAGE", "REFUSE_MISSING_COVERAGE", "REFUSE_UNKNOWN_COVERAGE", "REFUSE_CLOCK_MAPPING_UNVERSIONED"}:
        test.assertIn(disposition, result["reason_codes"])
    elif disposition == "EXCLUDE_CANCELLED_EVENT":
        test.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        test.assertEqual("CANCELLED", expected["visible_state"])
        test.assertEqual(1, result["cancelled_record_count"])
        test.assertEqual([], result["selected_records"])
    elif disposition == "WITHHOLD_TENTATIVE_EVENT":
        test.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        test.assertEqual("TENTATIVE", expected["visible_state"])
        test.assertEqual(1, result["tentative_record_count"])
        test.assertEqual([], result["selected_records"])
    elif disposition == "VISIBLE_SCHEDULED_EVENT":
        test.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        test.assertEqual(expected["visible_state"], result["selected_records"][0]["state"])
    elif disposition == "DEDUPLICATE_EXACT_RECORD":
        test.assertEqual("QUALIFIED_AS_OF_DECISION", result["status"])
        test.assertEqual(expected["deduplicated_count"], result["exact_duplicate_count"])
    elif disposition == "REFUSE_CONFLICTING_DUPLICATE":
        test.assertIn(disposition, result["reason_codes"])
    else:
        raise AssertionError(f"unmapped legacy expectation: {disposition}")
