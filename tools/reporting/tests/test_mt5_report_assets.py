import json
import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

HERE = Path(__file__).resolve()
TOOL_DIR = HERE.parents[1]
REPO_ROOT = HERE.parents[3]
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import mt5_report_assets as mra

PNG = b"\x89PNG\r\n\x1a\nfixture"
GIF = b"GIF89afixture"
JPEG = b"\xff\xd8\xfffixture"


class Mt5ReportAssetsTests(unittest.TestCase):
    def write_report(self, root: Path, body: str, *, encoding: str = "utf-8") -> Path:
        report = root / "report.htm"
        report.write_bytes(body.encode(encoding))
        return report

    def image(self, root: Path, name: str, payload: bytes = PNG) -> Path:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        return target

    def test_pass_with_local_png_and_deterministic_order(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "z.png")
            self.image(root, "a.png")
            report = self.write_report(root, '<img src="z.png"><img src="a.png">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("PASS", result["status"])
            self.assertEqual(["a.png", "z.png"], [x["path"] for x in result["assets"]])
            self.assertEqual(2, result["image_references_found"])
            self.assertEqual(2, result["unique_local_images"])

    def test_missing_image_is_incomplete(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            report = self.write_report(root, '<img src="missing.png">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("INCOMPLETE", result["status"])
            self.assertEqual(["missing.png"], result["missing"])

    def test_no_image_refs_always_fail_visible(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            report = self.write_report(root, "<html><body>none</body></html>")
            self.assertEqual("NO_IMAGE_REFERENCES", mra.inspect_report(report)["status"])
            self.assertEqual("NO_IMAGE_REFERENCES", mra.inspect_report(report, require_images=False)["status"])
            self.assertEqual("NO_IMAGE_REFERENCES", mra.inspect_report(report, require_images=True)["status"])

    def test_duplicate_refs_are_deduplicated_after_counting_source_refs(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png"><IMG SRC="graph.png">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("PASS", result["status"])
            self.assertEqual(2, result["image_references_found"])
            self.assertEqual(1, result["unique_local_images"])

    def test_safe_nested_asset_is_allowed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "assets/graph.png")
            report = self.write_report(root, '<img src="assets/graph.png">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("PASS", result["status"])
            self.assertEqual("assets/graph.png", result["assets"][0]["path"])

    def test_supported_gif_and_jpeg_signatures(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "a.gif", GIF)
            self.image(root, "b.jpg", JPEG)
            report = self.write_report(root, '<img src="a.gif"><img src="b.jpg">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual(["image/gif", "image/jpeg"], [x["media_type"] for x in result["assets"]])

    def test_remote_absolute_and_traversal_refs_are_refused(self):
        bad_refs = [
            "https://example.test/a.png", "http://example.test/a.png", "//example.test/a.png",
            "data:image/png;base64,AA==", "file:///C:/tmp/a.png", "javascript:alert(1)",
            "C:/tmp/a.png", "/tmp/a.png", "../a.png", "assets/../../a.png",
            "%2e%2e/a.png", "assets/%252e%252e/a.png", "ftp://example.test/a.png",
            "assets/.. /a.png", "assets/./a.png", "assets//a.png", "./a.png",
            "assets\\..\\a.png", "a.png:stream", "CON.png", "NUL.png",
            "a\x00.png", "a\t.png", "a%20b.png",
        ]
        for ref in bad_refs:
            with self.subTest(ref=ref), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                report = self.write_report(root, f'<img src="{ref}">')
                result = mra.inspect_report(report, require_images=True)
                self.assertEqual("REFUSED", result["status"])
                self.assertEqual(ref, result["refused"][0]["reference"])

    def test_query_fragment_and_unsupported_extension_are_refused(self):
        for ref in ("a.png?x=1", "a.png#frag", "a.svg", "a.txt"):
            with self.subTest(ref=ref), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                report = self.write_report(root, f'<img src="{ref}">')
                self.assertEqual("REFUSED", mra.inspect_report(report, require_images=True)["status"])

    def test_wrong_signature_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png", b"not-a-png")
            report = self.write_report(root, '<img src="graph.png">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("REFUSED", result["status"])
            self.assertIn("signature", result["refused"][0]["reason"])

    def test_directory_with_image_suffix_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "graph.png").mkdir()
            report = self.write_report(root, '<img src="graph.png">')
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("REFUSED", result["status"])
            self.assertIn("regular file", result["refused"][0]["reason"])

    def test_utf16le_bom_mt5_report_is_parsed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = root / "report.htm"
            report.write_bytes('<html><img src="graph.png"></html>'.encode("utf-16"))
            result = mra.inspect_report(report, require_images=True)
            self.assertEqual("PASS", result["status"])
            self.assertEqual(1, result["image_references_found"])

    def test_result_does_not_expose_absolute_report_path(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png">')
            rendered = json.dumps(mra.inspect_report(report, require_images=True))
            self.assertNotIn(str(root), rendered)
            self.assertIn('"report": "report.htm"', rendered)

    def test_cli_exit_codes_and_output_file(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png">')
            out = root / "closure.json"
            proc = subprocess.run(
                [sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report), "--require-images", "--out", str(out)],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(0, proc.returncode, proc.stderr)
            self.assertEqual("PASS", json.loads(out.read_text(encoding="utf-8"))["status"])
            self.assertTrue(out.read_bytes().endswith(b"\n"))

            report.write_text('<img src="missing.png">', encoding="utf-8")
            proc = subprocess.run(
                [sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report), "--require-images"],
                capture_output=True, text=True, check=False,
            )
            self.assertEqual(2, proc.returncode)
            self.assertEqual("INCOMPLETE", json.loads(proc.stdout)["status"])

    def test_missing_report_cli_refuses_without_traceback(self):
        proc = subprocess.run(
            [sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), "definitely-missing.htm", "--require-images"],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(2, proc.returncode)
        self.assertEqual("REFUSED", json.loads(proc.stdout)["status"])
        self.assertNotIn("Traceback", proc.stderr)

    def test_b16_h08_tracked_report_exposes_missing_native_graphs(self):
        main_report = REPO_ROOT / "factory" / "runs" / "b16_h08_20260831" / "usdjpy_buy_h1" / "validation" / "MAIN" / "report.htm"
        bwd_report = REPO_ROOT / "factory" / "runs" / "b16_h08_20260831" / "usdjpy_buy_h1" / "validation" / "BWD" / "report.htm"
        for report in (main_report, bwd_report):
            with self.subTest(report=report.parent.name):
                result = mra.inspect_report(report, require_images=True)
                self.assertEqual("INCOMPLETE", result["status"])
                self.assertEqual(4, result["image_references_found"])
                self.assertEqual(0, result["unique_local_images"])
                self.assertEqual(4, len(result["missing"]))
                self.assertEqual([], result["refused"])

    def test_output_is_deterministic_for_same_bytes(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png"><img src="graph.png">')
            first = json.dumps(mra.inspect_report(report, require_images=True), sort_keys=True)
            second = json.dumps(mra.inspect_report(report, require_images=True), sort_keys=True)
            self.assertEqual(first, second)

    def test_utf16_variants_and_utf8_bom(self):
        for encoding in ("utf-16-le", "utf-16-be", "utf-8-sig"):
            with self.subTest(encoding=encoding), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                self.image(root, "graph.png")
                report = self.write_report(root, '<img src="graph.png">', encoding=encoding)
                self.assertEqual("PASS", mra.inspect_report(report)["status"])

    def test_bomless_utf16_with_leading_html_whitespace(self):
        for encoding in ("utf-16-le", "utf-16-be"):
            with self.subTest(encoding=encoding), tempfile.TemporaryDirectory() as td:
                root = Path(td)
                self.image(root, "graph.png")
                report = self.write_report(root, ' \r\n\t<img src="graph.png">', encoding=encoding)
                result = mra.inspect_report(report)
                self.assertEqual("PASS", result["status"])
                self.assertEqual(1, result["image_references_found"])

    def test_whitespace_cannot_alias_a_different_filename(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            for ref in ("\u00a0graph.png", "graph.png\u00a0", "\u2003graph.png", " graph.png "):
                with self.subTest(ref=ref):
                    report = self.write_report(root, f'<img src="{ref}">')
                    result = mra.inspect_report(report)
                    self.assertEqual("REFUSED", result["status"])
                    self.assertEqual([], result["assets"])

    def test_cli_unicode_json_with_legacy_stdout_encoding(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            name = "กราฟ.png"
            self.image(root, name)
            for ref, status in ((name, "PASS"), ("不存在.png", "INCOMPLETE"), ("\u00a0graph.png", "REFUSED")):
                with self.subTest(ref=ref):
                    report = self.write_report(root, f'<img src="{ref}">')
                    proc = subprocess.run([sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report)],
                                          capture_output=True, env={**os.environ, "PYTHONIOENCODING": "cp1252"})
                    self.assertEqual(0 if status == "PASS" else 2, proc.returncode, proc.stderr)
                    result = json.loads(proc.stdout)
                    self.assertEqual(status, result["status"])
                    self.assertIn(ref, json.dumps(result, ensure_ascii=False))

    def test_hashes_bind_report_and_image_bytes(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            asset = self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png">')
            first = mra.inspect_report(report)
            self.assertEqual(hashlib.sha256(report.read_bytes()).hexdigest(), first["report_sha256"])
            self.assertEqual(hashlib.sha256(PNG).hexdigest(), first["assets"][0]["sha256"])
            self.assertEqual(len(PNG), first["assets"][0]["size_bytes"])
            asset.write_bytes(PNG + b"changed")
            second = mra.inspect_report(report)
            self.assertNotEqual(first["assets"][0]["sha256"], second["assets"][0]["sha256"])
            self.assertEqual(first["report_sha256"], second["report_sha256"])

    def test_cli_rejects_malformed_html_and_encoding(self):
        bodies = [b'\xff\xfe\x00', b'\x80<img src="a.png">',
                  b'<img>', b'<img src>', b'<img src="a.png" src="b.png">',
                  b'<base href="https://example.test/"><img src="a.png">',
                  b'<img src="a.png" srcset="https://example.test/a.png 2x">']
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            for body in bodies:
                with self.subTest(body=body):
                    report = root / "report.htm"
                    report.write_bytes(body)
                    proc = subprocess.run([sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report)],
                                          capture_output=True, text=True)
                    self.assertEqual(2, proc.returncode, proc.stderr)
                    self.assertEqual("REFUSED", json.loads(proc.stdout)["status"])
                    self.assertNotIn("Traceback", proc.stderr)

    def test_case_alias_is_refused_not_silently_deduplicated(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png"><img src="GRAPH.PNG">')
            self.assertEqual("REFUSED", mra.inspect_report(report)["status"])

    def test_reparse_component_is_refused_before_reading_asset(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "assets/graph.png")
            report = self.write_report(root, '<img src="assets/graph.png">')
            with patch.object(mra, "_is_reparse_component", side_effect=lambda p: p.name == "assets"):
                result = mra.inspect_report(report)
            self.assertEqual("REFUSED", result["status"])
            self.assertEqual([], result["assets"])
            self.assertIn("reparse", result["refused"][0]["reason"])

    def test_cli_bytes_identical_on_repeated_run(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png">')
            command = [sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report)]
            first = subprocess.run(command, capture_output=True)
            second = subprocess.run(command, capture_output=True)
            self.assertEqual(0, first.returncode)
            self.assertEqual(0, second.returncode)
            self.assertEqual(first.stdout, second.stdout)

    def test_cli_no_images_fails_without_optional_flag(self):
        with tempfile.TemporaryDirectory() as td:
            report = self.write_report(Path(td), '<html>no graphs</html>')
            proc = subprocess.run([sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report)],
                                  capture_output=True, text=True)
            self.assertEqual(2, proc.returncode)
            self.assertEqual("GRAPH ASSET MISSING", json.loads(proc.stdout)["graph_asset_state"])

    def test_cli_never_overwrites_inputs_or_existing_output(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            asset = self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png">')
            output = root / "closure.json"
            output.write_bytes(b"existing evidence")
            for target in (report, asset, output):
                before = target.read_bytes()
                proc = subprocess.run([sys.executable, str(TOOL_DIR / "mt5_report_assets.py"), str(report),
                                       "--out", str(target)], capture_output=True, text=True)
                self.assertEqual(2, proc.returncode)
                self.assertEqual("REFUSED", json.loads(proc.stdout)["status"])
                self.assertEqual(before, target.read_bytes())

    def test_closure_can_feed_existing_package_integrity_authority(self):
        import report_package_integrity as integrity
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.image(root, "graph.png")
            report = self.write_report(root, '<img src="graph.png">')
            closure = mra.inspect_report(report)
            spec = root / "spec.json"
            spec.write_text(json.dumps({"package_id": "fixture", "direct_consumer": "Monitor",
                "authority": "READ_ONLY_PRESENTATION", "artifacts": [
                    {"path": report.name, "role": "source_report"},
                    *[{"path": a["path"], "role": "native_image"} for a in closure["assets"]]]}), encoding="utf-8")
            manifest_path = root / "manifest.json"
            manifest = integrity.build_manifest(spec, manifest_path)
            integrity.write_manifest(manifest, manifest_path)
            by_path = {a["path"]: a for a in manifest["artifacts"]}
            self.assertEqual(closure["report_sha256"], by_path[report.name]["sha256"])
            self.assertEqual(closure["assets"][0]["sha256"], by_path["graph.png"]["sha256"])
            self.assertEqual("PASS", integrity.validate_manifest(manifest_path)["status"])


if __name__ == "__main__":
    unittest.main()
