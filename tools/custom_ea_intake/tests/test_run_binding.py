"""Native file identity join boundary: integrity is not performance acceptance."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

MODULE = Path(__file__).resolve().parents[1] / "run_binding.py"
spec = importlib.util.spec_from_file_location("run_binding", MODULE)
binder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(binder)


class RunBindingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.artifacts = {}
        for kind, extension in [
            ("source", ".mq5"), ("compiled_ea", ".ex5"), ("preset", ".set"),
            ("native_report", ".htm"), ("native_graph", ".png"),
        ]:
            file = self.root / (kind + extension)
            content = ("native-fixture-" + kind).encode()
            file.write_bytes(content)
            self.artifacts[kind] = {
                "path": str(file), "sha256": hashlib.sha256(content).hexdigest()}
        self.manifest = {
            "schema": "EA_LAB_RUN_EVIDENCE_INPUT_V1",
            "strategy_id": "STRAT-123", "variant_id": "VAR-1",
            "build_id": "BUILD-1", "run_id": "RUN-123",
            "symbol": "XAUUSD", "timeframe": "H1",
            "tester_model": "MODEL1", "window_start": "2023-01-01",
            "window_end": "2025-12-31", "stage": "MODEL1",
            "artifacts": self.artifacts,
        }
        self.input = self.root / "manifest.json"
        self.dump()

    def dump(self):
        self.input.write_text(json.dumps(self.manifest), encoding="utf-8")

    def test_good_receipt_is_hash_bound_but_unreviewed(self):
        res = binder.bind_manifest(self.input, self.root / "checked.json")
        self.assertEqual(res["identity"]["run_id"], "RUN-123")
        self.assertEqual(len(res["artifacts"]), 5)
        self.assertEqual(res["report_acceptance"], "NOT_REVIEWED")
        self.assertIsNone(res["run_result"])
        self.assertFalse(res["can_execute"])
        self.assertFalse(res["candidate_accepted"])

    def test_hash_tampering_fails_before_publication(self):
        (self.root / "native_graph.png").write_bytes(b"tampered")
        out = self.root / "rejected.json"
        with self.assertRaisesRegex(ValueError, "SHA256_MISMATCH"):
            binder.bind_manifest(self.input, out)
        self.assertFalse(out.exists())

    def test_missing_graph_is_not_accepted(self):
        self.manifest["artifacts"].pop("native_graph")
        self.dump()
        with self.assertRaisesRegex(ValueError, "proof missing"):
            binder.bind_manifest(self.input, self.root / "rejected.json")

    def test_unknown_artifact_field_is_refused(self):
        self.manifest["artifacts"]["claimed_pf"] = 4.88
        self.dump()
        with self.assertRaisesRegex(ValueError, "Unexpected artifact"):
            binder.bind_manifest(self.input, self.root / "rejected.json")

    def test_holdout_authorization_cannot_be_self_granted(self):
        self.manifest["stage"] = "OOS"
        self.manifest["holdout_authorized"] = True
        self.dump()
        with self.assertRaisesRegex(ValueError, "Cannot authorize"):
            binder.bind_manifest(self.input, self.root / "rejected.json")

    def test_holdout_stage_is_refused_even_without_a_claim(self):
        self.manifest["stage"] = "HOLDOUT"
        self.dump()
        with self.assertRaisesRegex(ValueError, "HOLDOUT stage refused"):
            binder.bind_manifest(self.input, self.root / "rejected.json")
        self.assertFalse((self.root / "rejected.json").exists())

    def test_window_overlapping_protected_holdout_or_reversed_is_refused(self):
        for start, end, message in [
            ("2023-01-01", "2026-03-31", "overlaps the protected holdout"),
            ("2026.01.01", "2026.06.30", "overlaps the protected holdout"),
            ("2026-06-30", "2026-09-30", "overlaps the protected holdout"),
            ("2025-12-31", "2023-01-01", "after window_end"),
            ("last year", "2025-12-31", "expected YYYY-MM-DD"),
        ]:
            with self.subTest(start=start, end=end):
                self.manifest["window_start"], self.manifest["window_end"] = start, end
                self.dump()
                with self.assertRaisesRegex(ValueError, message):
                    binder.bind_manifest(self.input, self.root / "w.json")
        self.assertFalse((self.root / "w.json").exists())

    def test_windows_wholly_before_or_after_the_holdout_are_accepted(self):
        for index, (start, end) in enumerate([("2023-01-01", "2025-12-31"), ("2026-07-01", "2026-10-31"),
                                              ("2026.07.01", "2027.01.31")]):
            with self.subTest(start=start, end=end):
                self.manifest["window_start"], self.manifest["window_end"] = start, end
                self.dump()
                res = binder.bind_manifest(self.input, self.root / f"ok{index}.json")
                self.assertEqual(res["identity"]["window_start"], start)

    def test_duplicate_json_key_and_nonfinite_constant_refused(self):
        good = json.dumps(self.manifest)
        self.input.write_text(good.replace('"run_id": "RUN-123"', '"run_id": "RUN-123", "run_id": "RUN-OTHER"'), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            binder.bind_manifest(self.input, self.root / "d.json")
        nested = good.replace('"sha256": "', '"sha256": "' + "0" * 64 + '", "sha256": "', 1)
        self.input.write_text(nested, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            binder.bind_manifest(self.input, self.root / "nested.json")
        for constant in ("NaN", "Infinity", "-Infinity"):
            with self.subTest(constant=constant):
                self.input.write_text(good.replace('"timeframe": "H1"', '"timeframe": "H1", "x": ' + constant), encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Non-finite"):
                    binder.bind_manifest(self.input, self.root / "n.json")

    def test_dangling_link_at_output_path_is_not_followed(self):
        target = self.root / "elsewhere.json"
        link = self.root / "out_link.json"
        try:
            os.symlink(target, link)
        except (OSError, NotImplementedError):
            self.skipTest("no symlink privilege on this host")
        with self.assertRaises(OSError):
            binder.bind_manifest(self.input, link)
        self.assertFalse(target.exists())

    def test_artifact_behind_a_link_or_junction_directory_is_refused(self):
        real = self.root / "real"
        real.mkdir()
        (real / "x.bin").write_bytes(b"x")
        link = self.root / "link"
        made = subprocess.run(["cmd", "/c", "mklink", "/J", str(link), str(real)],
                              capture_output=True).returncode == 0 if os.name == "nt" else False
        if not made:
            try:
                os.symlink(real, link, target_is_directory=True)
            except (OSError, NotImplementedError):
                self.skipTest("no junction or symlink privilege on this host")
        self.artifacts["source"] = {"path": str(link / "x.bin"), "sha256": hashlib.sha256(b"x").hexdigest()}
        self.manifest["artifacts"] = self.artifacts
        self.dump()
        with self.assertRaisesRegex(ValueError, "symlink or junction"):
            binder.bind_manifest(self.input, self.root / "j.json")
        # Python < 3.12 has no os.path.isjunction: the fallback must still refuse (fail closed, not skip the check).
        with mock.patch.object(os.path, "isjunction", None):
            with self.assertRaisesRegex(ValueError, "symlink or junction"):
                binder.bind_manifest(self.input, self.root / "j2.json")
        # ...and the fallback must not refuse an ordinary directory.
        with mock.patch.object(os.path, "isjunction", None):
            self.assertFalse(binder.is_link_or_junction(real / "x.bin"))

    def test_replacing_output_fails(self):
        binder.bind_manifest(self.input, self.root / "one.json")
        with self.assertRaises(ValueError):
            binder.bind_manifest(self.input, self.root / "one.json")


if __name__ == "__main__":
    unittest.main(verbosity=2)
