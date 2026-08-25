from __future__ import annotations

import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.pilot import (
    PilotError,
    build_supertrend_report_pilot,
    validate_pilot_record,
    write_pilot_artifacts,
)


class FactoryVNextPilotTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=r"D:\EA_LAB_CONTROL\temp")
        self.root = pathlib.Path(self.tmp.name)
        self.source = self.root / "(TRD)_SuperTrendFlip_rev05.mq5"
        self.preset = self.root / "STF_BTC_H4_rev05_off.set"
        self.source.write_text("// fixture rev05\n", encoding="utf-8")
        self.preset.write_text("_01_AtrPeriod=14\n_01_Mult=2.5\n", encoding="utf-8")
    def tearDown(self):
        self.tmp.cleanup()

    def _write_report(self, *, symbol="BTCUSD", tf="H4", bars=1074, quality="100% real ticks", net=219.18):
        report = self.root / "HOLDOUT26H1_rev05_off.htm"
        text = f"""Build 6061
Expert:
(TRD)_SuperTrendFlip_rev05
Symbol:
{symbol}
Company:
TF Global Markets (Aust) Pty Ltd
Period:
{tf} (2026.01.01 - 2026.06.30)
History Quality:
{quality}
Bars:
{bars}
Ticks:
29309891
Total Net Profit:
{net}
Profit Factor:
3.74
Equity Drawdown Relative:
2.53%
Total Trades:
9
Total Deals:
18
"""
        report.write_bytes(text.encode("utf-16-le"))
        return report

    def _build(self, report, **overrides):
        kwargs = dict(
            repo_root=str(ROOT),
            report_path=str(report),
            source_commit="a" * 40,
            window_class="COMMON_VALIDATION",
            tester_model="MT5_MODEL_4_REAL_TICKS",
            source_path=str(self.source),
            preset_path=str(self.preset),
            report_root=str(self.root),
        )
        kwargs.update(overrides)
        return build_supertrend_report_pilot(**kwargs)

    def test_end_to_end_pilot_is_deterministic_and_non_authoritative(self):
        report = self._write_report()
        p1 = self._build(report)
        p2 = self._build(report)
        self.assertEqual(p1["PilotID"], p2["PilotID"])
        self.assertEqual(p1["RunManifest"]["RunID"], p2["RunManifest"]["RunID"])
        self.assertEqual(p1["Report"]["ReportID"], p2["Report"]["ReportID"])
        self.assertEqual(p1["authority"], "NON_AUTHORITATIVE_SIDECAR")
        self.assertEqual(p1["HomeContract"]["LogicalSymbol"], "BTCUSD")
        self.assertEqual(p1["HomeContract"]["ExecutionTF"], "H4")
        self.assertEqual(p1["WindowContract"]["WindowClass"], "COMMON_VALIDATION")
        self.assertEqual(p1["WindowContract"]["Coverage"]["execution_bars"], 1074)
        self.assertEqual(p1["RunManifest"]["TesterModel"], "MT5_MODEL_4_REAL_TICKS")
        self.assertEqual(p1["RangeEvidence"]["status"], "SEMANTICS_REQUIRED")
        self.assertEqual(p1["RangeEvidence"]["candidates"], [])
        self.assertTrue(all(v is None for v in p1["GradeEvidence"]["top_level"].values()))
        self.assertEqual(len(p1["Report"]["page_ids"]), 5)
        self.assertEqual(p1["TelemetryEvents"][0]["EvidenceLabel"], "MEASURED")
        validate_pilot_record(p1)

    def test_wrong_symbol_or_tf_is_refused(self):
        with self.assertRaisesRegex(PilotError, "OUTSIDE_VALIDATED_CONTRACT"):
            self._build(self._write_report(symbol="XAUUSD"))
        with self.assertRaisesRegex(PilotError, "OUTSIDE_VALIDATED_CONTRACT"):
            self._build(self._write_report(tf="H1"))

    def test_zero_bar_silent_failure_is_refused(self):
        with self.assertRaisesRegex(PilotError, "bars generated must be > 0"):
            self._build(self._write_report(bars=0))

    def test_real_tick_contract_requires_raw_history_quality(self):
        with self.assertRaisesRegex(PilotError, "100% real ticks"):
            self._build(self._write_report(quality="1 minute OHLC"))
    def test_raw_report_hash_drift_changes_pilot_identity(self):
        report = self._write_report(net=219.18)
        p1 = self._build(report)
        report = self._write_report(net=220.18)
        p2 = self._build(report)
        self.assertNotEqual(p1["RawReportRef"]["sha256"], p2["RawReportRef"]["sha256"])
        self.assertNotEqual(p1["PilotID"], p2["PilotID"])

    def test_artifact_writer_hashes_exact_bytes(self):
        record = self._build(self._write_report())
        out = self.root / "out"
        index = write_pilot_artifacts(record, str(out))
        manifest = out / "pilot_manifest.json"
        html = out / "report.html"
        self.assertTrue(manifest.is_file())
        self.assertTrue(html.is_file())
        manifest_sha = hashlib.sha256(manifest.read_bytes()).hexdigest()
        html_sha = hashlib.sha256(html.read_bytes()).hexdigest()
        self.assertEqual(index["files"]["pilot_manifest.json"]["sha256"], manifest_sha)
        self.assertEqual(index["files"]["report.html"]["sha256"], html_sha)
        manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
        self.assertNotIn("html", manifest_data["Report"])
        self.assertEqual(manifest_data["PilotID"], record["PilotID"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
