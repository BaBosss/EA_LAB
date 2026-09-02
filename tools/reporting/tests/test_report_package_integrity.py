import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
TOOL_DIR = HERE.parents[1]
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import report_package_integrity as rpi


class ReportPackageIntegrityTests(unittest.TestCase):
    def make_package(self, root: Path) -> tuple[Path, Path]:
        (root / "machine").mkdir()
        (root / "visuals").mkdir()
        (root / "machine" / "summary.json").write_text('{"pf": 1.23}\n', encoding="utf-8")
        (root / "report.md").write_text("# Result\n\nEvidence only.\n", encoding="utf-8")
        (root / "visuals" / "pf.csv").write_text("cell,pf\nA,1.23\n", encoding="utf-8")
        spec = {
            "package_id": "PKG-TEST-001",
            "direct_consumer": "Main Control Tower test intake",
            "authority": "RESEARCH_ONLY / NO_RUNTIME_AUTHORITY",
            "metadata": {"experiment_id": "EXP-001", "holdout": "UNSPENT"},
            "artifacts": [                {"path": "visuals/pf.csv", "role": "visual_source"},
                {"path": "report.md", "role": "report"},
                {"path": "machine/summary.json", "role": "machine_summary", "note": "source-bound summary"},
            ],
        }
        spec_path = root / "package_spec.json"
        manifest_path = root / "report_package_manifest.json"
        spec_path.write_text(json.dumps(spec, indent=2), encoding="utf-8")
        return spec_path, manifest_path

    def test_build_validate_and_deterministic_bytes(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            manifest = rpi.build_manifest(spec_path, manifest_path)
            rpi.write_manifest(manifest, manifest_path)
            first = manifest_path.read_bytes()
            result = rpi.validate_manifest(manifest_path)
            self.assertEqual("PASS", result["status"])
            self.assertEqual(3, result["artifact_count"])
            self.assertEqual(
                ["machine/summary.json", "report.md", "visuals/pf.csv"],
                [row["path"] for row in manifest["artifacts"]],
            )
            expected = hashlib.sha256((root / "machine" / "summary.json").read_bytes()).hexdigest()
            summary = next(row for row in manifest["artifacts"] if row["path"] == "machine/summary.json")
            self.assertEqual(expected, summary["sha256"])
            second_path = root / "manifest_second.json"
            rpi.write_manifest(rpi.build_manifest(spec_path, second_path), second_path)
            self.assertEqual(first, second_path.read_bytes())

    def test_tamper_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            rpi.write_manifest(rpi.build_manifest(spec_path, manifest_path), manifest_path)
            (root / "report.md").write_text("tampered\n", encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "mismatch"):
                rpi.validate_manifest(manifest_path)

    def test_missing_artifact_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"].append({"path": "missing.csv", "role": "raw"})
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "artifact missing"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_parent_traversal_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            root = base / "pkg"
            root.mkdir()
            outside = base / "outside.txt"
            outside.write_text("outside", encoding="utf-8")
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": "../outside.txt", "role": "raw"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "unsafe segment"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_absolute_paths_are_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            for bad in ("C:\\temp\\raw.csv", "/tmp/raw.csv"):
                spec = json.loads(spec_path.read_text(encoding="utf-8"))
                spec["artifacts"] = [{"path": bad, "role": "raw"}]
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.subTest(path=bad), self.assertRaisesRegex(rpi.Refusal, "must be relative"):
                    rpi.build_manifest(spec_path, manifest_path)

    def test_duplicate_normalized_paths_are_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [
                {"path": "machine/summary.json", "role": "machine_summary"},
                {"path": "machine\\summary.json", "role": "duplicate"},
            ]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "duplicate artifact path"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_output_must_stay_with_package(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            root = base / "pkg"
            root.mkdir()
            other = base / "other"
            other.mkdir()
            spec_path, _ = self.make_package(root)
            with self.assertRaisesRegex(rpi.Refusal, "same directory"):
                rpi.build_manifest(spec_path, other / "manifest.json")

    def test_manifest_self_reference_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            manifest_path.write_text("placeholder", encoding="utf-8")
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": manifest_path.name, "role": "manifest"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "cannot hash itself"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_required_contract_fields_are_fail_closed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            original = json.loads(spec_path.read_text(encoding="utf-8"))
            for key in ("package_id", "direct_consumer", "authority"):
                spec = dict(original)
                spec.pop(key)
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.subTest(key=key), self.assertRaisesRegex(rpi.Refusal, key):
                    rpi.build_manifest(spec_path, manifest_path)

    def test_directory_artifact_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": "machine", "role": "directory"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "not a regular file"):
                rpi.build_manifest(spec_path, manifest_path)


if __name__ == "__main__":
    unittest.main()