"""B11 corrected-parser example -> existing Monitor adapter tests."""
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/mobile_report_hub"))
import build_index as b

B11_ROOT = "factory/runs/b11_default_example_rerun_20260920"
B11_MANIFEST = f"{B11_ROOT}/package_manifest.json"
B11_SUMMARY = f"{B11_ROOT}/evidence_summary.json"


def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args], text=True).strip()


class B11ExampleMonitorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sha = git("rev-parse", "HEAD")
        cls.manifest_raw = b.regular_blob(ROOT, cls.sha, B11_MANIFEST)
        cls.summary_raw = b.regular_blob(ROOT, cls.sha, B11_SUMMARY)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="b11-monitor-")
        self.out = Path(self.temp.name) / "site"

    def tearDown(self):
        self.temp.cleanup()

    def project(self):
        return b.b11_example_record(ROOT, self.sha, self.out)

    def test_real_package_projects_truthful_example_record(self):
        item = self.project()
        self.assertEqual("b11-default-example-rerun", item["id"])
        self.assertEqual("B11", item["family_id"])
        self.assertEqual("DEFAULT_EXAMPLE_RERUN_CORRECTED_PARSER", item["variant_id"])
        self.assertEqual("DONE", item["status"])
        self.assertEqual("EXAMPLE_ONLY_NO_FAMILY_OR_HOME_VERDICT", item["verdict"])
        self.assertEqual("UNRATIFIED", item["quality_grade"])
        self.assertFalse(item["candidate"])
        self.assertFalse(item["home_authority"])
        self.assertFalse(item["runtime_authority"])
        self.assertFalse(item["trading_authority"])
        self.assertIn("EXAMPLE_ONLY_NOT_HOME", item["home"]["symbol"])
        self.assertIn("EXAMPLE_ONLY_NOT_HOME", item["home"]["timeframe"])
        self.assertEqual("MODEL_1", item["evidence"]["model"])
        self.assertEqual("UNSPENT", item["evidence"]["holdout_state"])
        self.assertEqual(
            {"pf": "1.03", "net": "696.95", "eqdd_pct": "18.63", "dd_pct": "18.63", "trades": "2822", "cycles": "614"},
            item["evidence"]["main"],
        )
        self.assertEqual(
            {"pf": "0.89", "net": "-1878.63", "eqdd_pct": "21.67", "dd_pct": "21.67", "trades": "2657", "cycles": "634"},
            item["evidence"]["bwd"],
        )
        self.assertEqual("REVIEWED_CANONICAL_EXAMPLE_ONLY", item["package_status"])
        self.assertNotRegex(json.dumps(item), r"[A-Za-z]:[\\/]|https?://|file://")

    def test_real_package_materializes_bound_native_graphs_and_report(self):
        item = self.project()
        for role, expected in (
            ("main", "5acaa9e688d96cd6e92f0c73304c9b75eba757dc6e6eab6ca6d2fe1eb52559bf"),
            ("bwd", "5609e72b96c0abdd98b49ef995e696ef8cc3842637713673d8c993a583a4e291"),
        ):
            graph = item["native_graphs"][role]
            self.assertEqual("AVAILABLE", graph["state"])
            self.assertEqual(expected, graph["asset_sha256"])
            self.assertEqual(expected, hashlib.sha256((self.out / graph["href"]).read_bytes()).hexdigest())
            self.assertEqual(self.sha, graph["canonical_sha"])
            self.assertEqual(item["id"], graph["ea_id"])
            self.assertEqual(item["evidence"]["basis_id"], graph["basis_id"])
        self.assertNotEqual(item["native_graphs"]["main"]["href"], item["native_graphs"]["bwd"]["href"])
        report_href = item["links"]["full_report"]
        self.assertTrue((self.out / report_href).is_file())
        self.assertNotRegex((self.out / report_href).read_text(encoding="utf-8"), r"[A-Za-z]:\\")

    def test_build_includes_exactly_one_b11_record(self):
        with tempfile.TemporaryDirectory(prefix="b11-index-") as td:
            index = b.build(ROOT, self.sha, Path(td), "2026-09-20T10:00:00Z", self.sha, None)
        rows = [item for item in index["eas"] if item["id"] == "b11-default-example-rerun"]
        self.assertEqual(1, len(rows))
        self.assertEqual("REVIEWED_CANONICAL_EXAMPLE_ONLY", rows[0]["package_status"])

    def test_manifest_tamper_fails_closed(self):
        original = b.regular_blob
        data = json.loads(self.manifest_raw)
        data["files"][0]["sha256"] = "0" * 64
        tampered = json.dumps(data).encode()

        def fake(repo, sha, path):
            return tampered if path == B11_MANIFEST else original(repo, sha, path)

        with patch.object(b, "regular_blob", side_effect=fake):
            with self.assertRaises(b.BuildError):
                self.project()

    def test_manifest_unsafe_or_duplicate_path_fails_closed(self):
        original = b.regular_blob
        for mutation in ("unsafe", "duplicate"):
            with self.subTest(mutation=mutation):
                data = json.loads(self.manifest_raw)
                if mutation == "unsafe":
                    data["files"][0]["path"] = "../escape.bin"
                else:
                    data["files"][1]["path"] = data["files"][0]["path"]
                raw = json.dumps(data).encode()

                def fake(repo, sha, path, raw=raw):
                    return raw if path == B11_MANIFEST else original(repo, sha, path)

                with patch.object(b, "regular_blob", side_effect=fake):
                    with self.assertRaises(b.BuildError):
                        self.project()

    def test_authority_drift_fails_closed(self):
        original = b.regular_blob
        base = json.loads(self.summary_raw)
        for key, value in (
            ("family", "B99"),
            ("candidate", True),
            ("home_ratified", True),
            ("runtime_authority", True),
            ("trading_authority", True),
            ("optimization", 1),
            ("holdout", "SPENT"),
        ):
            with self.subTest(key=key):
                summary = copy.deepcopy(base)
                summary[key] = value
                summary_raw = json.dumps(summary).encode()
                manifest = json.loads(self.manifest_raw)
                entry = next(row for row in manifest["files"] if row["path"] == "evidence_summary.json")
                entry["bytes"] = len(summary_raw)
                entry["sha256"] = hashlib.sha256(summary_raw).hexdigest()
                manifest_raw = json.dumps(manifest).encode()

                def fake(repo, sha, path, sr=summary_raw, mr=manifest_raw):
                    if path == B11_SUMMARY:
                        return sr
                    if path == B11_MANIFEST:
                        return mr
                    return original(repo, sha, path)

                with patch.object(b, "regular_blob", side_effect=fake):
                    with self.assertRaises(b.BuildError):
                        self.project()

    def test_graph_hash_drift_fails_closed(self):
        original = b.regular_blob
        data = json.loads(self.manifest_raw)
        graph = next(row for row in data["files"] if row["path"] == "visuals/MAIN.png")
        graph["sha256"] = "f" * 64
        raw = json.dumps(data).encode()

        def fake(repo, sha, path):
            return raw if path == B11_MANIFEST else original(repo, sha, path)

        with patch.object(b, "regular_blob", side_effect=fake):
            with self.assertRaises(b.BuildError):
                self.project()


if __name__ == "__main__":
    unittest.main()
