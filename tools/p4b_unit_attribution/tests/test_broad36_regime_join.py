#!/usr/bin/env python3
from __future__ import annotations

import csv
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[1]))
import join_broad36_regimes as joiner


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


class RegimeJoinTests(unittest.TestCase):
    CREATED = "2026-09-02T14:00:00Z"

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.package = self.root / "package.json"
        self.units = self.root / "units.csv"
        self.timeline = self.root / "timeline.csv"
        self.manifest = self.root / "timeline_manifest.json"
        self.prejoin = self.root / "prejoin.json"
        self.review_receipt = self.root / "package_review_receipt.md"
        self.out = self.root / "out"

    def tearDown(self) -> None:
        self.tmp.cleanup()

    @staticmethod
    def unit_fields() -> list[str]:
        return [
            "schema_version", "h3_run_id", "symbol", "period_name", "configured_run_magic",
            "source_open_deal_magic", "source_close_deal_magic", "source_position_id",
            "source_open_deal_id", "source_deal_id", "entry_time_msc", "exit_time_msc", "entry_utc", "exit_utc", "time_status",
            "entry_volume", "exit_volume", "source_net_realized",
        ]

    @staticmethod
    def timeline_fields() -> list[str]:
        return [
            "valid_from_utc", "valid_to_utc", "symbol", "tf", "macro_state", "macro_as_of_utc",
            "macro_ri", "macro_confidence", "macro_coverage", "macro_missing_inputs", "macro_partial",
            "local_state", "local_bar_close_utc", "local_d", "local_qtrend", "vol_state",
            "vol_bar_close_utc", "vol_natr_pct", "vol_q20", "vol_q80", "vol_q95",
            "local_unknown_reason", "classification_status", "classifier_id", "classifier_version",
        ]

    def unit(self, deal: str, entry: str, exit_at: str, net: str) -> dict[str, str]:
        return {
            "schema_version": joiner.UNIT_SCHEMA, "h3_run_id": "H3-C01-MAIN", "symbol": "XAUUSD",
            "period_name": "PERIOD_M15", "configured_run_magic": "990001",
            "source_open_deal_magic": "990001", "source_close_deal_magic": "990001",
            "source_position_id": deal, "source_open_deal_id": "O" + deal, "source_deal_id": deal,
            "entry_time_msc": str(int(joiner.parse_z(entry, "test entry").timestamp() * 1000)),
            "exit_time_msc": str(int(joiner.parse_z(exit_at, "test exit").timestamp() * 1000)),
            "entry_utc": entry, "exit_utc": exit_at, "time_status": "COMPLETE",
            "entry_volume": "0.01", "exit_volume": "0.01", "source_net_realized": net,
        }

    def timeline_row(self, start: str, end: str, *, status: str = "CLASSIFIED",
                     macro: str = "NEUTRAL", local: str = "RANGE", vol: str = "NORMAL",
                     macro_asof: str | None = None, partial: str = "false") -> dict[str, str]:
        if macro_asof is None:
            macro_asof = start
        return {
            "valid_from_utc": start, "valid_to_utc": end, "symbol": "XAUUSD", "tf": "M15",
            "macro_state": macro, "macro_as_of_utc": macro_asof, "macro_ri": "0.1",
            "macro_confidence": "HIGH", "macro_coverage": "8/8", "macro_missing_inputs": "",
            "macro_partial": partial, "local_state": local, "local_bar_close_utc": start,
            "local_d": "0.1", "local_qtrend": "0.2", "vol_state": vol,
            "vol_bar_close_utc": start, "vol_natr_pct": "1.0", "vol_q20": "0.5",
            "vol_q80": "1.5", "vol_q95": "2.0", "local_unknown_reason": "",
            "classification_status": status, "classifier_id": joiner.EXPECTED["classifier_id"],
            "classifier_version": joiner.EXPECTED["classifier_version"],
        }

    def make_fixture(self, units: list[dict[str, str]] | None = None,
                     timeline_rows: list[dict[str, str]] | None = None) -> dict:
        if units is None:
            units = [
                self.unit("D1", "2023-01-01T00:30:00Z", "2023-01-01T02:00:00Z", "10"),
                self.unit("D2", "2023-01-01T01:30:00Z", "2023-01-01T02:30:00Z", "-4"),
            ]
        if timeline_rows is None:
            timeline_rows = [
                self.timeline_row("2023-01-01T00:00:00Z", "2023-01-01T01:00:00Z", local="RANGE"),
                self.timeline_row("2023-01-01T01:00:00Z", "2023-01-01T03:00:00Z", local="TREND_UP"),
            ]
        write_csv(self.units, self.unit_fields(), units)
        write_csv(self.timeline, self.timeline_fields(), timeline_rows)
        package = {
            "schema_version": joiner.PACKAGE_SCHEMA, "status": joiner.PACKAGE_STATUS,
            "authority": joiner.AUTHORITY, "holdout": "UNSPENT", "optimization": "NONE",
            "cell_count": 1, "realized_unit_count": len(units),
            "cells": [{"cell_id": "H3-C01-MAIN", "symbol": "XAUUSD", "tf": "M15",
                       "window": "MAIN", "realized_unit_count": len(units)}],
        }
        write_json(self.package, package)
        manifest = {
            "timeline_sha256": sha256(self.timeline), "classifier_id": joiner.EXPECTED["classifier_id"],
            "classifier_version": joiner.EXPECTED["classifier_version"], "holdout_included": False,
            "h3_outcome_content_opened": False, "row_count": len(timeline_rows),
            "serialization": {"format": "CSV"},
            "cell_coverage": [{"symbol": "XAUUSD", "tf": "M15", "rows": len(timeline_rows),
                               "full": len(timeline_rows), "partial": 0, "unknown": 0}],
        }
        write_json(self.manifest, manifest)
        expected = dict(joiner.EXPECTED)
        reviewed_head = "f" * 40
        receipt_text = (
            "VERDICT PASS\n\nCONFIDENCE: HIGH\n\n"
            "RECOMMENDED ACTION: Accept the package as reviewed/accepted; this package may serve as the evidence input to deterministic P4B regime attribution.\n\n"
            f"EXACT REVIEWED HEAD: `{reviewed_head}`\n"
        )
        self.review_receipt.write_text(receipt_text, encoding="utf-8", newline="\n")
        expected.update({
            "package_sha256": sha256(self.package), "aggregate_units_sha256": sha256(self.units),
            "timeline_sha256": sha256(self.timeline), "timeline_manifest_sha256": sha256(self.manifest),
            "package_review_receipt_sha256": sha256(self.review_receipt), "package_reviewed_head": reviewed_head,
            "cell_count": 1, "unit_count": len(units),
        })
        prejoin = {
            "status": joiner.PREJOIN_STATUS, "package_sha256": expected["package_sha256"],
            "aggregate_units_sha256": expected["aggregate_units_sha256"], "observed_cell_count": 1,
            "total_realized_units": len(units), "unique_deal_join_key_count": len(units),
            "holdout": "UNSPENT", "optimization": "NONE", "prejoin_schema_ready": True,
            "package_review_required_before_regime_join": True,
        }
        write_json(self.prejoin, prejoin)
        return expected

    def run_join(self, expected: dict, out: Path | None = None) -> dict:
        return joiner.execute(
            self.package, self.units, self.timeline, self.manifest, self.prejoin, self.review_receipt,
            self.out if out is None else out, self.CREATED, expected,
        )

    @staticmethod
    def read_csv(path: Path) -> list[dict[str, str]]:
        with path.open("r", encoding="utf-8-sig", newline="") as fh:
            return list(csv.DictReader(fh))

    def test_default_canonical_review_receipt_is_pinned(self) -> None:
        self.assertTrue(joiner.DEFAULT_PACKAGE_REVIEW_RECEIPT.is_file())
        self.assertEqual(sha256(joiner.DEFAULT_PACKAGE_REVIEW_RECEIPT), joiner.EXPECTED["package_review_receipt_sha256"])
        text = joiner.DEFAULT_PACKAGE_REVIEW_RECEIPT.read_text(encoding="utf-8-sig", errors="replace")
        self.assertIn(f"EXACT REVIEWED HEAD: `{joiner.EXPECTED["package_reviewed_head"]}`", text)

    def test_valid_asof_join_reconciles(self) -> None:
        expected = self.make_fixture()
        result = self.run_join(expected)
        self.assertEqual(result["detail_unit_count"], 2)
        self.assertEqual(result["classified_unit_count"], 2)
        self.assertEqual(result["unknown_unit_count"], 0)
        self.assertEqual(result["package_review_verdict"], "PASS")
        self.assertEqual(result["package_reviewed_head"], expected["package_reviewed_head"])
        detail = self.read_csv(self.out / "regime_attribution_detail.csv")
        self.assertEqual([r["local_state"] for r in detail], ["RANGE", "TREND_UP"])
        recon = json.loads((self.out / "regime_attribution_reconciliation.json").read_text())
        self.assertEqual(recon["status"], "PASS_ATTRIBUTION_RECONCILIATION")
        self.assertEqual(recon["source_net_realized"], "6.00000000")
        self.assertEqual(recon["detail_net_realized"], "6.00000000")

    def test_missing_asof_match_stays_unknown(self) -> None:
        units = [self.unit("D1", "2022-12-31T23:00:00Z", "2023-01-01T02:00:00Z", "2")]
        rows = [self.timeline_row("2023-01-01T00:00:00Z", "2023-01-01T03:00:00Z")]
        expected = self.make_fixture(units, rows)
        result = self.run_join(expected)
        self.assertEqual(result["unknown_unit_count"], 1)
        detail = self.read_csv(self.out / "regime_attribution_detail.csv")[0]
        self.assertEqual(detail["classification_status"], "UNKNOWN")
        self.assertEqual(detail["unknown_reason"], "NO_TIMELINE_ASOF_MATCH")

    def test_duplicate_join_key_refuses(self) -> None:
        rows = [
            self.unit("D1", "2023-01-01T00:30:00Z", "2023-01-01T02:00:00Z", "1"),
            self.unit("D1", "2023-01-01T01:30:00Z", "2023-01-01T02:30:00Z", "1"),
        ]
        expected = self.make_fixture(rows)
        with self.assertRaisesRegex(joiner.Refusal, "duplicate deal join key"):
            self.run_join(expected)

    def test_forward_looking_timeline_refuses(self) -> None:
        rows = [self.timeline_row(
            "2023-01-01T00:00:00Z", "2023-01-01T03:00:00Z",
            macro_asof="2023-01-01T00:01:00Z",
        )]
        expected = self.make_fixture(timeline_rows=rows)
        with self.assertRaisesRegex(joiner.Refusal, "forward-looking"):
            self.run_join(expected)

    def test_overlapping_timeline_refuses(self) -> None:
        rows = [
            self.timeline_row("2023-01-01T00:00:00Z", "2023-01-01T02:00:00Z"),
            self.timeline_row("2023-01-01T01:00:00Z", "2023-01-01T03:00:00Z"),
        ]
        expected = self.make_fixture(timeline_rows=rows)
        with self.assertRaisesRegex(joiner.Refusal, "gap/overlap/out-of-order"):
            self.run_join(expected)

    def test_identity_hash_tamper_refuses(self) -> None:
        expected = self.make_fixture()
        expected["timeline_sha256"] = "0" * 64
        with self.assertRaisesRegex(joiner.Refusal, "frozen timeline SHA drift"):
            self.run_join(expected)

    def test_prejoin_authority_drift_refuses(self) -> None:
        expected = self.make_fixture()
        p = json.loads(self.prejoin.read_text())
        p["holdout"] = "RUN"
        write_json(self.prejoin, p)
        with self.assertRaisesRegex(joiner.Refusal, "prejoin HOLDOUT drift"):
            self.run_join(expected)

    def test_package_review_gate_refuses_tamper_or_missing_boundary(self) -> None:
        expected = self.make_fixture()
        self.review_receipt.write_text(self.review_receipt.read_text() + "tamper\n", encoding="utf-8")
        with self.assertRaisesRegex(joiner.Refusal, "package review receipt SHA drift"):
            self.run_join(expected)
        expected = self.make_fixture()
        prejoin = json.loads(self.prejoin.read_text())
        prejoin["package_review_required_before_regime_join"] = False
        write_json(self.prejoin, prejoin)
        with self.assertRaisesRegex(joiner.Refusal, "package-review boundary flag missing"):
            self.run_join(expected)

    def test_same_inputs_are_byte_deterministic(self) -> None:
        expected = self.make_fixture()
        out_a = self.root / "a"
        out_b = self.root / "b"
        self.run_join(expected, out_a)
        self.run_join(expected, out_b)
        names = [
            "regime_attribution_detail.csv", "regime_affinity.csv",
            "regime_attribution_coverage.csv", "regime_attribution_reconciliation.json",
            "regime_attribution_package.json",
        ]
        self.assertEqual({n: sha256(out_a / n) for n in names}, {n: sha256(out_b / n) for n in names})

    def test_refuses_to_overwrite_existing_output(self) -> None:
        expected = self.make_fixture()
        self.run_join(expected)
        with self.assertRaisesRegex(joiner.Refusal, "refusing to overwrite existing output"):
            self.run_join(expected)

    def test_partition_dd_and_pf_are_recomputed(self) -> None:
        expected = self.make_fixture()
        self.run_join(expected)
        affinity = self.read_csv(self.out / "regime_affinity.csv")
        by_local = {r["local_state"]: r for r in affinity}
        self.assertEqual(by_local["RANGE"]["profit_factor"], "")
        self.assertEqual(by_local["TREND_UP"]["gross_loss"], "-4.00000000")
        self.assertEqual(by_local["TREND_UP"]["partition_realized_equity_dd"], "4.00000000")
        self.assertEqual(by_local["TREND_UP"]["dd_basis"], joiner.DD_BASIS)


if __name__ == "__main__":
    unittest.main()
