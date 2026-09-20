from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tools.orderflow_proxy.historical_pipeline import pipeline


PREREGISTRATION = (
    ROOT / "factory" / "runs" / "ofp_historical_v1_20260920" / "preregistration.json"
)


def _write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture_manifest(root: Path) -> tuple[Path, dict[str, object]]:
    prereg = pipeline.read_json(PREREGISTRATION)
    plan = pipeline.build_plan(prereg)
    identity = {
        "broker": "FIXTURE_BROKER",
        "server": "FIXTURE_SERVER",
        "terminal_build": 1,
    }
    artifacts: list[dict[str, object]] = []
    for cell_window in plan["windows"]:
        window_id = cell_window["window_id"]
        interval = cell_window["requested_interval"]
        sample_time = interval["start_broker_time"][:-2] + "01"
        for symbol in plan["universe"]:
            for role in pipeline.REQUIRED_ARTIFACT_ROLES:
                relative = f"payload/{symbol}/{window_id}/{role.lower()}.jsonl"
                path = root / relative
                common = {
                    "broker": identity["broker"],
                    "server": identity["server"],
                    "terminal_build": identity["terminal_build"],
                    "logical_symbol": symbol,
                    "broker_symbol": symbol,
                    "historical_market_time_broker": sample_time,
                    "synthetic_fixture": True,
                }
                if role == "RAW_QUOTE_ROWS":
                    row = {**common, "bid": 100.0, "ask": 100.1, "flags": 3}
                else:
                    timeframe = {
                        "D1_RATE_ROWS": "D1",
                        "M15_RATE_ROWS": "M15",
                        "M5_RATE_ROWS": "M5",
                    }[role]
                    row = {
                        **common,
                        "timeframe": timeframe,
                        "open": 100.0,
                        "high": 101.0,
                        "low": 99.0,
                        "close": 100.5,
                        "tick_volume": 10,
                    }
                _write_json(path, row)
                artifacts.append(
                    {
                        "path": relative,
                        "sha256": _sha256(path),
                        "size_bytes": path.stat().st_size,
                        "role": role,
                        "logical_symbol": symbol,
                        "broker_symbol": symbol,
                        "window_id": window_id,
                        "requested_interval": interval,
                        "record_count": 1,
                    }
                )
    manifest: dict[str, object] = {
        "schema": pipeline.RAW_MANIFEST_SCHEMA,
        "manifest_id": "ofp-fixture-integrity-v1",
        "classification": "SYNTHETIC_FIXTURE",
        "fixture_id": "unit-test-fixture",
        "source_identity": {
            **identity,
            "symbol_mappings": [
                {"logical_symbol": symbol, "broker_symbol": symbol}
                for symbol in plan["universe"]
            ],
        },
        "source_graph": {
            "graph_id": "OFP_RAW_HISTORY_EXPORT_V1",
            "nodes": list(pipeline.SOURCE_GRAPH_NODES),
            "edges": list(pipeline.SOURCE_GRAPH_EDGES),
        },
        "dataset_scope": {
            "universe": plan["universe"],
            "requested_windows": plan["windows"],
            "acquisition_time_utc": "2026-09-20T15:00:00Z",
            "historical_market_time_basis": "BROKER_SERVER_CLOCK",
            "replay_assumed_availability": "UNKNOWN_NOT_PROVEN",
            "historical_as_of_availability": "UNKNOWN_NOT_PROVEN",
            "causal_partitioning": "NOT_IMPLEMENTED",
        },
        "clock_contract": {
            "clock_contract_id": "FIXTURE_BROKER_CLOCK_V1",
            "status": "FIXTURE_ONLY",
            "timezone_conversion": "NONE_INFERRED",
        },
        "repeatability_claim": "REVISED_HISTORY_REPEATABLE",
        "artifacts": artifacts,
    }
    path = root / "raw_manifest.json"
    _write_json(path, manifest)
    return path, manifest


class PlanTests(unittest.TestCase):
    def test_plan_is_deterministic_and_freezes_exact_72_not_run_cells(self) -> None:
        prereg = pipeline.read_json(PREREGISTRATION)
        first = pipeline.canonical_json_bytes(pipeline.build_plan(prereg))
        second = pipeline.canonical_json_bytes(pipeline.build_plan(prereg))
        self.assertEqual(first, second)
        plan = json.loads(first)
        self.assertEqual(plan["planned_cells"], 72)
        self.assertEqual(plan["executed_cells"], 0)
        self.assertEqual(len({cell["cell_id"] for cell in plan["cells"]}), 72)
        self.assertEqual({cell["execution_state"] for cell in plan["cells"]}, {"NOT_RUN"})
        self.assertTrue(all(value is None for cell in plan["cells"] for value in cell["performance"].values()))
        self.assertEqual(
            {cell["variant_id"]: cell["parent_variant"] for cell in plan["cells"]},
            {
                "OFPR-00": None,
                "OFPR-01": "OFPR-00",
                "OFPR-02": "OFPR-01",
                "OFPC-00": None,
                "OFPC-01": "OFPC-00",
                "OFPC-02": "OFPC-01",
            },
        )

    def test_request_is_inert_and_requests_four_payload_types_per_symbol_window(self) -> None:
        plan = pipeline.build_plan(pipeline.read_json(PREREGISTRATION))
        request = pipeline.build_acquisition_request(
            plan,
            broker="ThinkMarkets",
            server="ThinkMarkets-Live",
            terminal_build=6182,
        )
        self.assertEqual(request["request_count"], 48)
        self.assertEqual(request["network_action"], "NONE")
        self.assertEqual(request["execution_authorized"], False)
        self.assertEqual(
            {item["artifact_role"] for item in request["requests"]},
            set(pipeline.REQUIRED_ARTIFACT_ROLES),
        )


class PreflightTests(unittest.TestCase):
    def test_valid_fixture_proves_integrity_only_and_cannot_unlock_execution(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            manifest_path, _ = _fixture_manifest(Path(temp))
            result = pipeline.preflight(
                manifest_path,
                expected_manifest_sha256=_sha256(manifest_path),
                preregistration_path=PREREGISTRATION,
            )
        self.assertEqual(result["status"], "VALIDATED_FIXTURE_INPUT")
        self.assertFalse(result["real_data_qualified"])
        self.assertFalse(result["execution_allowed"])
        self.assertIn("HISTORICAL_SEAM_CONSUMER_NOT_IMPLEMENTED", result["unresolved_gates"])
        self.assertIn("SIGNAL_INPUT_FIDELITY_UNQUALIFIED", result["unresolved_gates"])

    def test_a2_receipt_role_cannot_substitute_for_raw_quotes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path, manifest = _fixture_manifest(root)
            manifest["artifacts"][0]["role"] = "A2_COUNT_HASH_RECEIPT"
            _write_json(path, manifest)
            with self.assertRaisesRegex(pipeline.Refusal, "artifact identity set"):
                pipeline.preflight(path, _sha256(path), PREREGISTRATION)

    def test_tamper_forged_manifest_prefix_identity_and_unknown_clock_are_refused(self) -> None:
        mutations = ("artifact_tamper", "manifest_prefix", "identity_mix", "unknown_clock")
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                path, manifest = _fixture_manifest(root)
                frozen_manifest_hash = _sha256(path)
                first_artifact = root / manifest["artifacts"][0]["path"]
                if mutation == "artifact_tamper":
                    first_artifact.write_bytes(first_artifact.read_bytes() + b"{}\n")
                    expected = "size mismatch"
                elif mutation == "manifest_prefix":
                    first_artifact.write_bytes(first_artifact.read_bytes() + b"{}\n")
                    manifest["artifacts"][0]["sha256"] = _sha256(first_artifact)
                    manifest["artifacts"][0]["size_bytes"] = first_artifact.stat().st_size
                    manifest["artifacts"][0]["record_count"] = 2
                    _write_json(path, manifest)
                    expected = "manifest sha256 mismatch"
                elif mutation == "identity_mix":
                    row = json.loads(first_artifact.read_text(encoding="utf-8"))
                    row["logical_symbol"] = "WRONG"
                    _write_json(first_artifact, row)
                    manifest["artifacts"][0]["sha256"] = _sha256(first_artifact)
                    manifest["artifacts"][0]["size_bytes"] = first_artifact.stat().st_size
                    _write_json(path, manifest)
                    frozen_manifest_hash = _sha256(path)
                    expected = "row identity mismatch"
                else:
                    manifest["clock_contract"]["status"] = "UNKNOWN"
                    _write_json(path, manifest)
                    frozen_manifest_hash = _sha256(path)
                    expected = "clock contract"
                with self.assertRaisesRegex(pipeline.Refusal, expected):
                    pipeline.preflight(path, frozen_manifest_hash, PREREGISTRATION)

    def test_bool_count_future_record_duplicate_identity_and_fixture_substitution_are_refused(self) -> None:
        mutations = (
            "bool_count",
            "future_record",
            "post_decision",
            "duplicate",
            "fixture_substitution",
        )
        for mutation in mutations:
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                path, manifest = _fixture_manifest(root)
                if mutation == "duplicate":
                    manifest["artifacts"].append(copy.deepcopy(manifest["artifacts"][0]))
                    expected = "duplicate artifact identity"
                else:
                    artifact = next(
                        item for item in manifest["artifacts"]
                        if item["role"] == ("D1_RATE_ROWS" if mutation == "bool_count" else "RAW_QUOTE_ROWS")
                    )
                    artifact_path = root / artifact["path"]
                    row = json.loads(artifact_path.read_text(encoding="utf-8"))
                    if mutation == "bool_count":
                        row["tick_volume"] = True
                        expected = "tick_volume"
                    elif mutation == "future_record":
                        row["historical_market_time_broker"] = artifact["requested_interval"]["end_broker_time"]
                        expected = "outside requested half-open interval"
                    elif mutation == "post_decision":
                        row["decision_time_broker"] = row["historical_market_time_broker"]
                        expected = "post-decision data"
                    else:
                        manifest["classification"] = "BROKER_HISTORY_EXPORT"
                        manifest.pop("fixture_id")
                        manifest["clock_contract"]["status"] = "SOURCE_NAMED"
                        expected = "fixture substitution"
                    _write_json(artifact_path, row)
                    artifact["sha256"] = _sha256(artifact_path)
                    artifact["size_bytes"] = artifact_path.stat().st_size
                _write_json(path, manifest)
                with self.assertRaisesRegex(pipeline.Refusal, expected):
                    pipeline.preflight(path, _sha256(path), PREREGISTRATION)


if __name__ == "__main__":
    unittest.main()
