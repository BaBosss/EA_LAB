import hashlib
import json
import os
import subprocess
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
    def make_dir_link(self, target: Path, link: Path) -> None:
        if os.name == "nt":
            result = subprocess.run(
                ["cmd", "/d", "/c", "mklink", "/J", str(link), str(target)],
                capture_output=True, text=True, check=False,
            )
            if result.returncode != 0:
                self.skipTest(f"cannot create Windows junction: {result.stderr or result.stdout}")
        else:
            link.symlink_to(target, target_is_directory=True)

    def remove_dir_link(self, link: Path) -> None:
        if not link.exists() and not link.is_symlink():
            return
        if os.name == "nt":
            subprocess.run(["cmd", "/d", "/c", "rmdir", str(link)], check=True)
        else:
            link.unlink()

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


    def test_leaf_symlink_branch_is_fail_closed_when_os_cannot_create_symlinks(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": "machine/summary.json", "role": "alias"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            original = rpi._is_reparse_component
            rpi._is_reparse_component = lambda path: path.name == "summary.json"
            try:
                with self.assertRaisesRegex(rpi.Refusal, "reparse component"):
                    rpi.build_manifest(spec_path, manifest_path)
            finally:
                rpi._is_reparse_component = original

    def test_intermediate_directory_link_alias_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            link = root / "machine-alias"
            self.make_dir_link(root / "machine", link)
            try:
                spec = json.loads(spec_path.read_text(encoding="utf-8"))
                spec["artifacts"] = [{"path": "machine-alias/summary.json", "role": "alias"}]
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.assertRaisesRegex(rpi.Refusal, "reparse component"):
                    rpi.build_manifest(spec_path, manifest_path)
            finally:
                self.remove_dir_link(link)

    def test_intermediate_directory_link_escape_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            root = base / "pkg"
            root.mkdir()
            outside = base / "outside"
            outside.mkdir()
            (outside / "secret.txt").write_text("outside", encoding="utf-8")
            spec_path, manifest_path = self.make_package(root)
            link = root / "escape"
            self.make_dir_link(outside, link)
            try:
                spec = json.loads(spec_path.read_text(encoding="utf-8"))
                spec["artifacts"] = [{"path": "escape/secret.txt", "role": "raw"}]
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.assertRaisesRegex(rpi.Refusal, "reparse component"):
                    rpi.build_manifest(spec_path, manifest_path)
            finally:
                self.remove_dir_link(link)

if __name__ == "__main__":
    unittest.main()
