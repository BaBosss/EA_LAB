"""Source-bound graph integration tests. No tester execution or research verdicts."""
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

CANONICAL = "346175b42e68405aea0bc099a67009090bfedc0e"
NATIVE = "factory/runs/b15_countbars_sens01_20260831/visuals/native/B15_COUNTBARS_SENS01_COUNT3_GBPUSD_H4_MAIN_M1.png"


class NativeGraphsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.native = b.regular_blob(ROOT, CANONICAL, NATIVE)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ea-graph-test-")
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.out = self.root / "out"
        self.run_git("init", "-q")
        self.item = b.record(identity="graph-fixture", family="FIXTURE", variant="TEST", name="Native graph fixture", symbol="FIXTURE", timeframe="H1")
        self.item["evidence"].update(basis_id="fixture-basis", model="MODEL_1")
        self.manifest = None

    def tearDown(self):
        self.temp.cleanup()

    def run_git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], stderr=subprocess.STDOUT)

    def fixture(self, missing=(), ref="graph.png", invalid=False):
        package = self.repo / "factory/runs/fixture"
        bindings = {"ea_id": self.item["id"], "basis_id": "fixture-basis"}
        artifacts = []
        for role, start, end in [("main", "2023.01.01", "2025.12.31"), ("bwd", "2020.01.01", "2022.12.31")]:
            directory = package / role
            directory.mkdir(parents=True)
            (directory / "report.htm").write_text(f'<html><p>{role}: {start} to {end}</p><img src="{ref}"></html>', encoding="utf-8")
            artifacts.append({"path": f"{role}/report.htm", "role": f"{role}_report"})
            if role not in missing:
                (directory / "graph.png").write_bytes(b"invalid" if invalid else self.native)
                artifacts.append({"path": f"{role}/graph.png", "role": f"{role}_native"})
            bindings[role] = {"role": role.upper(), "from": start, "to": end, "report": f"{role}/report.htm", "report_sha256": hashlib.sha256((directory / "report.htm").read_bytes()).hexdigest(), "asset_ref": ref}
        spec = {"package_id": "TEST_NATIVE_MT5", "direct_consumer": "Deterministic fixture only", "authority": "READ_ONLY_PRESENTATION", "metadata": {"native_graphs": bindings}, "artifacts": artifacts}
        spec_path = package / "spec.json"
        spec_path.write_text(json.dumps(spec), encoding="utf-8")
        manifest_path = package / "report_package_manifest.json"
        self.manifest = b.integrity.build_manifest(spec_path, manifest_path)
        self.save_manifest()

    def save_manifest(self):
        path = self.repo / "factory/runs/fixture/report_package_manifest.json"
        b.integrity.write_manifest(self.manifest, path)
        self.run_git("add", ".")
        # Disposable fixture repo has no EA_LAB hooks or inherited identity config.
        self.run_git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture", "--allow-empty")
        self.sha = self.run_git("rev-parse", "HEAD").decode().strip()
        self.manifest_hash = hashlib.sha256(path.read_bytes()).hexdigest()

    def project(self):
        return b.project_native_graphs(self.repo, self.sha, self.item, "factory/runs/fixture", self.manifest, self.manifest_hash, self.out)

    def test_valid_both_and_reproducible_copy(self):
        self.fixture()
        original = copy.deepcopy(self.item)
        first = self.project()
        self.assertEqual(first, self.project())
        self.assertEqual(original, self.item)
        for role, graph in first.items():
            self.assertEqual("AVAILABLE", graph["state"])
            self.assertEqual(self.native, (self.out / graph["href"]).read_bytes())
            self.assertIn(f"/{role}/", graph["href"])
        self.assertNotEqual(first["main"]["href"], first["bwd"]["href"])

    def test_main_valid_bwd_missing(self):
        self.fixture(missing=("bwd",))
        graphs = self.project()
        self.assertEqual(["AVAILABLE", "MISSING"], [graphs[r]["state"] for r in ("main", "bwd")])

    def test_main_missing_bwd_valid(self):
        self.fixture(missing=("main",))
        graphs = self.project()
        self.assertEqual(["MISSING", "AVAILABLE"], [graphs[r]["state"] for r in ("main", "bwd")])

    def test_both_missing_preserves_metrics_verdict(self):
        self.fixture(missing=("main", "bwd"))
        original = copy.deepcopy(self.item)
        self.assertEqual({"MISSING"}, {g["state"] for g in self.project().values()})
        self.assertEqual(original, self.item)

    def test_unsafe_traversal(self):
        self.fixture(ref="../graph.png")
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_absolute_external_and_hostile_refs(self):
        self.fixture()
        for ref in ["C:/private.png", "/private.png", "https://host/image.png", "data:image/png;base64,abc", "x%2e.png", "x' onerror='alert(1).png"]:
            with self.subTest(ref=ref):
                self.manifest["metadata"]["native_graphs"]["main"]["asset_ref"] = ref
                graphs = self.project()
                self.assertNotEqual("AVAILABLE", graphs["main"]["state"])

    def test_wrong_package_identity(self):
        self.fixture()
        self.manifest["metadata"]["native_graphs"]["ea_id"] = "different-ea"
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_wrong_window_and_cross_binding(self):
        self.fixture()
        binding = self.manifest["metadata"]["native_graphs"]
        binding["bwd"]["role"] = "MAIN"
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})
        binding["bwd"]["role"] = "BWD"
        binding["bwd"]["report"] = "main/report.htm"
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_swapped_reports_cannot_keep_other_window_hash(self):
        self.fixture()
        binding = self.manifest["metadata"]["native_graphs"]
        binding["main"]["report"], binding["bwd"]["report"] = binding["bwd"]["report"], binding["main"]["report"]
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_duplicate_filenames_different_package_namespace(self):
        self.fixture()
        first = self.project()
        self.manifest["package_id"] = "SECOND_PACKAGE"
        self.save_manifest()
        second = self.project()
        self.assertNotEqual(first["main"]["href"], second["main"]["href"])

    def test_malformed_asset(self):
        self.fixture(invalid=True)
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_integrity_tamper(self):
        self.fixture()
        self.manifest["artifacts"][0]["sha256"] = "0" * 64
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_declared_missing_file_is_integrity_refusal(self):
        self.fixture()
        (self.repo / "factory/runs/fixture/main/graph.png").unlink()
        self.save_manifest()
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_git_symlink_refused(self):
        self.fixture()
        blob = self.run_git("rev-parse", f"{self.sha}:factory/runs/fixture/main/graph.png").decode().strip()
        self.run_git("update-index", "--cacheinfo", f"120000,{blob},factory/runs/fixture/main/graph.png")
        self.run_git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "link fixture")
        self.sha = self.run_git("rev-parse", "HEAD").decode().strip()
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_static_output_reparse_refused(self):
        self.fixture()
        original = b.integrity._is_reparse_component
        with patch.object(b.integrity, "_is_reparse_component", side_effect=lambda p: p == self.out / "artifacts" or original(p)):
            self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_content_address_collision_refused(self):
        self.fixture()
        graph = self.project()["main"]
        (self.out / graph["href"]).write_bytes(b"wrong cached package")
        self.assertEqual({"REFUSED"}, {g["state"] for g in self.project().values()})

    def test_old_record_without_graph_metadata(self):
        self.fixture()
        self.manifest["metadata"] = {}
        self.save_manifest()
        items = [self.item]
        b.add_native_reports(self.repo, self.sha, self.out, items)
        self.assertEqual({"MISSING"}, {g["state"] for g in items[0]["native_graphs"].values()})

    def test_existing_index_manifest_discovery(self):
        self.fixture()
        items = [self.item]
        b.add_native_reports(self.repo, self.sha, self.out, items)
        self.assertEqual({"AVAILABLE"}, {g["state"] for g in items[0]["native_graphs"].values()})

    def test_real_b16_h08_missing_source_bound(self):
        item = b.b16_h08_record(ROOT, CANONICAL, self.out)
        for graph in item["native_graphs"].values():
            self.assertEqual(("MISSING", 4, 0), (graph["state"], graph["references"], graph["available_assets"]))
            self.assertNotIn("href", graph)
        self.assertEqual("DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE", item["verdict"])
        self.assertEqual(("1.68", "415.62", "4.78", "420", "372"), tuple(item["evidence"]["main"][k] for k in ("pf", "net", "eqdd_pct", "trades", "cycles")))
        self.assertEqual("0.66", item["evidence"]["bwd"]["pf"])
        self.assertEqual([{"name": "_16_RsiLow", "parent": "30.0", "value": "35.0"}], item["parameters"]["changed"])
        self.assertGreater(len(item["parameters"]["all"]), 150)
        self.assertNotRegex(json.dumps(item), r"[A-Za-z]:[\\/]")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--export-browser-fixture":
        destination = Path(sys.argv[2])
        NativeGraphsTests.setUpClass()
        case = NativeGraphsTests()
        case.setUp()
        try:
            case.fixture()
            case.out = destination
            case.item["native_graphs"] = case.project()
            case.item["display_name"] = "FIXTURE ONLY — native B15 image in both explicit test roles"
            case.item["package_status"] = "FIXTURE_ONLY_INTEGRITY_VALIDATED"
            for role in ("main", "bwd"):
                case.item["evidence"][role] = {"pf": "1.23", "net": "45.67", "eqdd_pct": "2.34", "trades": "56", "cycles": "34"}
            case.item["parameters"] = {"parent": "fixture-parent.set", "parent_sha256": "1" * 64, "source_sha256": "2" * 64,
                "changed": [{"name": "FixtureParameter", "parent": "1", "value": "2"}], "key": [{"name": "FixtureParameter", "value": "2"}], "all": [{"name": "FixtureParameter", "value": "2"}, {"name": "AnotherParameter", "value": "3"}]}
            (destination / "native-fixture.json").write_text(json.dumps({"sha": case.sha, "item": case.item}), encoding="utf-8")
        finally:
            case.tearDown()
    else:
        unittest.main()
