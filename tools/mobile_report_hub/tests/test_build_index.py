import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "mobile_report_hub"))
import build_index


SHA = "b7ac57ce5e1a74dc7d8a0ed5717c4853786fd4fa"
FIXED_TIME = "2026-08-30T00:00:00Z"


class MobileReportHubDataTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.out = Path(self.temp.name) / "out"

    def tearDown(self):
        self.temp.cleanup()

    def build(self):
        return build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, None)

    def by_id(self, index, identity):
        return next(item for item in index["eas"] if item["id"] == identity)

    def test_exact_ref_repeatable_b16_h03_and_safe_artifacts(self):
        first = self.build()
        one = (self.out / "report_index.json").read_bytes()
        second_out = Path(self.temp.name) / "out2"
        build_index.build(ROOT, SHA, second_out, FIXED_TIME, SHA, None)
        self.assertEqual(one, (second_out / "report_index.json").read_bytes())
        self.assertEqual(first["project"]["canonical_sha"], SHA)
        b16 = self.by_id(first, "b16-h03-xauusd-h4")
        self.assertEqual(b16["verdict"], "POSITION_ENGINE_DEPENDENT_OR_UNKNOWN")
        self.assertEqual(b16["evidence"]["main"], {"pf": "4.08", "dd_pct": "6.27%", "trades": "79", "cycles": "42"})
        self.assertEqual(b16["evidence"]["bwd"], {"pf": "1.44", "dd_pct": "8.29%", "trades": "148", "cycles": "70"})
        self.assertIn("79.80%", b16["evidence"]["key_findings"][0])
        self.assertIn("H04 is NOT unlocked.", b16["evidence"]["key_findings"])
        self.assertTrue((self.out / b16["links"]["full_report"]).is_file())
        self.assertEqual(len(b16["provenance"][0]["sha256"]), 64)

    def test_boss19_is_environment_blocker_not_strategy_failure(self):
        boss19 = self.by_id(self.build(), "boss19-regime-attribution")
        self.assertEqual(boss19["verdict"], "BLOCKED(C DATA / environment prerequisite)")
        self.assertEqual(boss19["research_state"], "BLOCKED")
        self.assertIn("not a strategy finding", boss19["evidence"]["known_weaknesses"][0])
        self.assertEqual(boss19["evidence"]["main"]["pf"], "UNAVAILABLE")
        self.assertTrue((self.out / boss19["links"]["full_report"]).is_file())
        self.assertFalse(boss19["links"]["full_report"].startswith(("file:", "D:")))
        boss19_copy = (self.out / boss19["links"]["full_report"]).read_text(encoding="utf-8")
        self.assertIn("[LOCAL_PATH_REDACTED]", boss19_copy)
        self.assertNotRegex(boss19_copy, r"[A-Za-z]:\\")

    def test_h02_pair_is_compatible_and_unknown_not_zero(self):
        index = self.build()
        h03 = self.by_id(index, "b16-h03-xauusd-h4")
        h02_xau = self.by_id(index, "b16-h02-xauusd-h4")
        h02_jpy = self.by_id(index, "b16-h02-usdjpy-h1")
        self.assertNotEqual(h03["evidence"]["basis_id"], h02_xau["evidence"]["basis_id"])
        self.assertEqual(h02_xau["evidence"]["basis_id"], h02_jpy["evidence"]["basis_id"])
        self.assertEqual(h02_xau["evidence"]["main"]["pf"], "4.08")
        self.assertEqual(h02_jpy["evidence"]["bwd"]["dd_pct"], "2.40%")
        self.assertEqual(h02_jpy["evidence"]["main"]["cycles"], "UNKNOWN")
        self.assertNotEqual(h02_jpy["evidence"]["main"]["cycles"], "0")
        self.assertIn("basis_id is identical", index["compare"]["compatibility_rule"])

    def test_inventory_stale_and_secret_hygiene(self):
        index = self.build()
        self.assertTrue(any(x["status"] == "INVENTORY_ONLY" for x in index["eas"]))
        self.assertEqual(build_index.classify_current(index, SHA), "CURRENT")
        self.assertEqual(build_index.classify_current(index, "0" * 40), "STALE")
        blob = b"".join(path.read_bytes() for path in self.out.rglob("*") if path.is_file()).lower()
        for forbidden in (b"file:///", b"d:\\", b"463666728", b"146237", b'"password":', b'"api_key":', b'"secret":', b'"token":'):
            self.assertNotIn(forbidden, blob)

    def test_queue_source_kind_distinguishes_canonical_and_lane_registry(self):
        registry = Path(self.temp.name) / "lanes.json"
        registry.write_text(json.dumps({"lanes": [{
            "lane_id": "fixture-dynamic-lane", "state": "RUNNING", "blocker_class": "C",
            "objective": r"export exact fixture from D:\Meta 5",
            "direct_consumer": "fixture dynamic observation"
        }]}), encoding="utf-8")
        index = build_index.build(ROOT, SHA, self.out, FIXED_TIME, SHA, registry)
        canonical = next(item for item in index["queue"] if item["id"] == "BOSS19-P4-REGIME-ATTRIBUTION")
        dynamic = next(item for item in index["queue"] if item["id"] == "fixture-dynamic-lane")
        self.assertEqual(canonical["source_kind"], "GIT_CANONICAL")
        self.assertEqual(dynamic["source_kind"], "LANE_REGISTRY_NONCANONICAL")
        self.assertEqual(dynamic["blocker_type"], "ENVIRONMENT")
        self.assertEqual(dynamic["summary"], "fixture dynamic observation")
        self.assertNotRegex(dynamic["summary"], r"[A-Za-z]:\\")

    def test_lane_summary_rejects_common_windows_path_shapes(self):
        unsafe = [
            r"path:D:\Meta 5", r"[D:\Meta 5]", r"see=D:\Meta 5",
            r"objective=D:\Meta 5,direct=ok", r"net:\\server\share",
            "C:/forward/slash/path exported",
        ]
        for text in unsafe:
            self.assertEqual(build_index.lane_summary({"objective": text}), "[LOCAL_PATH_REDACTED]", text)
        self.assertEqual(build_index.lane_summary({"objective": unsafe[0], "direct_consumer": "safe consumer"}), "safe consumer")
        self.assertEqual(build_index.lane_summary({"objective": "https://example.com/report"}), "https://example.com/report")
    def test_expected_sha_mismatch_and_missing_source_fail_closed(self):
        with self.assertRaisesRegex(build_index.BuildError, "expected SHA mismatch"):
            build_index.build(ROOT, SHA, self.out, FIXED_TIME, "0" * 40, None)
        with self.assertRaises(build_index.BuildError):
            build_index.text_source(ROOT, SHA, "docs/factory/NOT_PRESENT.md")


if __name__ == "__main__":
    unittest.main(verbosity=2)
