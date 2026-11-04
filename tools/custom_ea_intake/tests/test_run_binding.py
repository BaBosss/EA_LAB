"""Native file identity join boundary: integrity is not performance acceptance."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

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
        self.manifest["stage"] = "HOLDOUT"
        self.manifest["holdout_authorized"] = True
        self.dump()
        with self.assertRaisesRegex(ValueError, "Cannot authorize"):
            binder.bind_manifest(self.input, self.root / "rejected.json")

    def test_replacing_output_fails(self):
        binder.bind_manifest(self.input, self.root / "one.json")
        with self.assertRaises(ValueError):
            binder.bind_manifest(self.input, self.root / "one.json")


if __name__ == "__main__":
    unittest.main(verbosity=2)
