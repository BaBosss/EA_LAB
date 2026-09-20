from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from tools.orderflow_proxy.research_presentation import projection
from tools.orderflow_proxy.research_presentation.cli import main


HISTORICAL_PINNED_REF = "d5e23b5d91421c98e069d5db5b089c3203c8f02c"
ACCEPTED_SOURCE_STATUS_COMMIT = "5436833f3791049655f3ab44b90582c73d222e1d"


def valid_observation(manifest_sha: str) -> dict:
    return {
        "schema": projection.OBSERVATION_SCHEMA,
        "source_ref": HISTORICAL_PINNED_REF,
        "source_artifact_path": projection.MANIFEST_PATH,
        "source_artifact_sha256": manifest_sha,
        "observed_at_utc": "2026-09-20T01:00:00Z",
        "valid_until_utc": "2026-09-20T03:00:00Z",
        "observation_kind": "PREPARATION_STATUS_ONLY",
        "execution_status": "NOT_RUN",
        "executed_cells": 0,
        "performance_metrics": None,
        "claims": {
            "true_orderflow": False,
            "executed_volume_delta_qualified": False,
            "order_execution_authorized": False,
        },
        "monitor": {"wired": False, "deployed": False, "live_refresh_asserted": False},
    }


class ProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repo_root = ROOT
        cls.current_head = projection._git(cls.repo_root, "rev-parse", "HEAD").decode().strip()
        cls.manifest, cls.bindings, cls.source_set_sha = projection.bind_repository(cls.repo_root, cls.current_head)
        cls.bound = projection.build_projection(cls.manifest, cls.bindings, cls.source_set_sha, cls.current_head)

    def test_positive_actual_canonical_source_renders(self) -> None:
        html_bytes = projection.render_html(self.bound)
        self.assertIn(b"PREPARATION REPORT / NOT A BACKTEST REPORT", html_bytes)
        self.assertIn(b"WAITING_GATE", html_bytes)
        self.assertIn(self.current_head.encode(), html_bytes)
        self.assertIn(ACCEPTED_SOURCE_STATUS_COMMIT.encode(), html_bytes)
        self.assertNotIn(b"<script", html_bytes.lower())

    def test_requested_historical_ref_stays_distinct_from_current_head(self) -> None:
        historical = projection.build_projection(
            self.manifest,
            self.bindings,
            self.source_set_sha,
            HISTORICAL_PINNED_REF,
        )
        self.assertEqual(self.bound["source_binding"]["projection_source_ref"], self.current_head)
        self.assertEqual(historical["source_binding"]["projection_source_ref"], HISTORICAL_PINNED_REF)
        self.assertNotEqual(self.current_head, HISTORICAL_PINNED_REF)
        self.assertEqual(
            self.bound["source_binding"]["accepted_source_status_commit"],
            ACCEPTED_SOURCE_STATUS_COMMIT,
        )
        self.assertEqual(
            historical["source_binding"]["accepted_source_status_commit"],
            ACCEPTED_SOURCE_STATUS_COMMIT,
        )

    def test_rendered_css_contains_mobile_overflow_guards(self) -> None:
        html_text = projection.render_html(self.bound).decode("utf-8")
        self.assertIn("main{max-width:1120px;margin:auto;padding:24px;min-width:0}", html_text)
        self.assertIn(".grid>*{min-width:0}", html_text)
        self.assertIn("code,footer{overflow-wrap:anywhere;word-break:break-word}", html_text)
        self.assertIn(".scroll{max-width:100%;min-width:0;overflow-x:auto}", html_text)

    def test_golden_projection_is_reproducible(self) -> None:
        first = projection.serialize_projection(self.bound)
        second = projection.serialize_projection(
            projection.build_projection(self.manifest, self.bindings, self.source_set_sha, self.current_head)
        )
        self.assertEqual(first, second)
        historical_base = projection.build_projection(
            self.manifest,
            self.bindings,
            self.source_set_sha,
            HISTORICAL_PINNED_REF,
        )
        self.assertEqual(
            hashlib.sha256(projection.serialize_projection(historical_base)).hexdigest(),
            "dd108c2219bc1dfc1586d27b34aaa729f76a4474b83a664771ad8c28cc3f5f51",
        )

    def test_planned_or_negated_model4_prose_never_becomes_execution(self) -> None:
        for prose in ("Plan says RUN Model4 later", "Model4 NOT RUN", "RUN and Model4 appear in prose"):
            manifest = copy.deepcopy(self.manifest)
            manifest["next_gate"] = prose
            result = projection.build_projection(manifest, self.bindings, self.source_set_sha, self.current_head)
            self.assertEqual(result["performance"]["status"], "NOT_RUN")
            self.assertEqual(result["experiment_plan"]["total_executed_cells"], 0)

    def test_missing_locked_source_refuses(self) -> None:
        with mock.patch.object(projection, "SOURCE_LOCK", {"missing/source.json": "0" * 64}):
            with self.assertRaisesRegex(projection.ProjectionError, "GIT_READ_FAILED"):
                projection.bind_repository(self.repo_root, self.current_head)

    def test_dirty_input_bytes_refuse(self) -> None:
        expected = projection.SOURCE_LOCK[projection.MANIFEST_PATH]
        with tempfile.TemporaryDirectory() as tmp:
            dirty = Path(tmp) / "manifest.json"
            dirty.write_bytes(b"{}\n")
            with mock.patch.object(projection, "SOURCE_LOCK", {projection.MANIFEST_PATH: expected}), mock.patch.object(
                projection, "_safe_relative_path", return_value=dirty
            ):
                with self.assertRaisesRegex(projection.ProjectionError, "DIRTY_INPUT_BYTES"):
                    projection.bind_repository(self.repo_root, self.current_head)

    def test_source_hash_mismatch_refuses(self) -> None:
        with mock.patch.object(projection, "SOURCE_LOCK", {projection.MANIFEST_PATH: "0" * 64}):
            with self.assertRaisesRegex(projection.ProjectionError, "SOURCE_LOCK_MISMATCH"):
                projection.bind_repository(self.repo_root, self.current_head)

    def test_path_escape_and_output_traversal_refuse(self) -> None:
        with self.assertRaisesRegex(projection.ProjectionError, "PATH_ESCAPE"):
            projection._safe_relative_path(self.repo_root, "../outside.json")
        for name in ("../report.json", "sub/report.json", "report..json"):
            with self.assertRaises(projection.ProjectionError):
                projection.safe_output_name(name, ".json")

    def test_resolved_outside_symlink_target_refuses(self) -> None:
        root = Path("C:/declared-root")
        outside = Path("C:/outside/target.json")
        with mock.patch.object(Path, "resolve", side_effect=[root, outside]):
            with self.assertRaisesRegex(projection.ProjectionError, "SYMLINK_OR_PATH_ESCAPE"):
                projection._safe_relative_path(root, "link.json")

    def test_stale_and_unbound_observations_refuse(self) -> None:
        manifest_sha = projection.SOURCE_LOCK[projection.MANIFEST_PATH]
        stale = valid_observation(manifest_sha)
        with self.assertRaisesRegex(projection.ProjectionError, "STALE_OR_FUTURE_OBSERVATION"):
            projection.validate_observation(stale, HISTORICAL_PINNED_REF, manifest_sha, "2026-09-20T04:00:00Z")
        unbound = valid_observation(manifest_sha)
        unbound["source_ref"] = "0" * 40
        with self.assertRaisesRegex(projection.ProjectionError, "UNBOUND_OBSERVATION_REF"):
            projection.validate_observation(unbound, HISTORICAL_PINNED_REF, manifest_sha, "2026-09-20T02:00:00Z")

    def test_unknown_and_malformed_fields_refuse(self) -> None:
        unknown = copy.deepcopy(self.manifest)
        unknown["invented"] = True
        with self.assertRaisesRegex(projection.ProjectionError, "UNKNOWN_OR_MISSING_FIELDS"):
            projection._validate_manifest(unknown)
        malformed = copy.deepcopy(self.manifest)
        malformed["provider_qualification"]["terminal_build"] = 6182.0
        with self.assertRaisesRegex(projection.ProjectionError, "TERMINAL_BUILD_MISMATCH"):
            projection._validate_manifest(malformed)
        obs = valid_observation(projection.SOURCE_LOCK[projection.MANIFEST_PATH])
        obs["note"] = "RUN Model4"
        with self.assertRaisesRegex(projection.ProjectionError, "UNKNOWN_OR_MISSING_FIELDS"):
            projection.validate_observation(obs, HISTORICAL_PINNED_REF, projection.SOURCE_LOCK[projection.MANIFEST_PATH], "2026-09-20T02:00:00Z")

    def test_html_escapes_all_dynamic_text(self) -> None:
        value = copy.deepcopy(self.bound)
        value["experiment_plan"]["variants"][0]["hypothesis"] = '<img src=x onerror="alert(1)">'
        rendered = projection.render_html(value).decode("utf-8")
        self.assertNotIn('<img src=x onerror="alert(1)">', rendered)
        self.assertIn("&lt;img src=x onerror=&quot;alert(1)&quot;&gt;", rendered)

    def test_no_source_promotion_and_btc_eth_have_no_fallback(self) -> None:
        self.assertEqual(self.bound["report"]["status"], "WAITING_GATES_NOT_RUN")
        self.assertEqual(
            {item["symbol"]: item["source_status"] for item in self.bound["scope"]["exact_window_only_symbols"]},
            {symbol: "EXACT_WINDOW_ONLY" for symbol in projection.SYMBOLS},
        )
        self.assertEqual(
            self.bound["scope"]["parked_symbols"],
            [
                {"symbol": "BTCUSD", "status": "PARKED", "reason": "RATE_SNAPSHOT_CHANGED", "fallback": None},
                {"symbol": "ETHUSD", "status": "PARKED", "reason": "RATE_SNAPSHOT_CHANGED", "fallback": None},
            ],
        )

    def test_invented_performance_and_authority_refuse(self) -> None:
        promoted = copy.deepcopy(self.bound)
        promoted["performance"]["metrics"]["profit_factor"] = 0
        with self.assertRaisesRegex(projection.ProjectionError, "INVENTED_PERFORMANCE_REFUSED"):
            projection.validate_projection(promoted)
        obs = valid_observation(projection.SOURCE_LOCK[projection.MANIFEST_PATH])
        obs["performance_metrics"] = {"profit_factor": 2.0}
        with self.assertRaisesRegex(projection.ProjectionError, "INVENTED_PERFORMANCE_REFUSED"):
            projection.validate_observation(obs, HISTORICAL_PINNED_REF, projection.SOURCE_LOCK[projection.MANIFEST_PATH], "2026-09-20T02:00:00Z")

    def test_bound_observation_stays_metadata_only(self) -> None:
        observation = valid_observation(projection.SOURCE_LOCK[projection.MANIFEST_PATH])
        result = projection.build_projection(
            self.manifest,
            self.bindings,
            self.source_set_sha,
            HISTORICAL_PINNED_REF,
            observation,
            "2026-09-20T02:00:00Z",
        )
        self.assertEqual(result["observation"]["status"], "BOUND_METADATA_ONLY")
        self.assertEqual(result["observation"]["freshness"], "NOT_ASSERTED")
        self.assertEqual(result["performance"]["status"], "NOT_RUN")

    def test_cli_generates_useful_json_and_html(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            rc = main(
                [
                    "--repo-root", str(self.repo_root),
                    "--repo-ref", self.current_head,
                    "--output-dir", tmp,
                ]
            )
            self.assertEqual(rc, 0)
            result = json.loads((Path(tmp) / "orderflow_preparation_projection.json").read_text(encoding="utf-8"))
            self.assertEqual(result["performance"]["status"], "NOT_RUN")
            self.assertEqual(result["experiment_plan"]["total_planned_cells"], 72)
            self.assertTrue((Path(tmp) / "orderflow_preparation_report.html").is_file())


if __name__ == "__main__":
    unittest.main()
