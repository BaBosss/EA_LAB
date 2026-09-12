import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
from tools.control_center.research_catalog import catalog as c
from tools.mobile_report_hub.tests import test_native_graphs as native

BASE = "b0df07ee776acd8450c1d06deba37cb63fbeb02f"


class ShelfTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        native.NativeGraphsTests.setUpClass()

    def setUp(self):
        self.fixture = native.NativeGraphsTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.tearDown)
        self.fixture.fixture()

    def index(self):
        f = self.fixture
        item = copy.deepcopy(f.item)
        item["provenance"] = [{"path": "fixture.json", "sha256": "a" * 64, "canonical_sha": f.sha}]
        c.reports.add_native_reports(f.repo, f.sha, f.out, [item])
        return {"schema_version": 1, "project": {"canonical_sha": f.sha}, "eas": [item]}

    def project(self, index=None):
        return c.project_index(index or self.index(), self.fixture.sha)

    def test_bound_graphs(self):
        row = self.project()["records"][0]
        self.assertEqual("AVAILABLE", row["windows"]["main"]["graph"]["state"])
        self.assertEqual("NOT_DERIVED_BY_SHELF", row["acceptance"])
        self.assertIn("source_build_id", row["ref"]["missing"])

    def test_swapped_main_bwd(self):
        index = self.index()
        graphs = index["eas"][0]["native_graphs"]
        graphs["main"], graphs["bwd"] = graphs["bwd"], graphs["main"]
        self.assertEqual(1, len(self.project(index)["refused"]))

    def test_stale_async_selection(self):
        shelf = self.project()
        ref = shelf["records"][0]["ref"]
        token = {k: ref[k] for k in ("ea_id", "basis_id", "canonical_sha", "record_sha256")}
        self.assertEqual(shelf["records"][0], c.select(shelf, **token))
        for key in token:
            with self.subTest(key=key), self.assertRaises(c.ProjectionError):
                c.select(shelf, **{**token, key: "different"})

    def test_wrong_package(self):
        index = self.index()
        index["eas"][0]["tested_setup"] = {"package_id": "wrong"}
        self.assertEqual(1, len(self.project(index)["refused"]))

    def test_hash_mismatch_reuses_integrity(self):
        self.fixture.manifest["artifacts"][0]["sha256"] = "b" * 64
        self.fixture.save_manifest()
        row = self.project()["records"][0]
        self.assertEqual("REFUSED", row["quality"])
        self.assertEqual({}, row["windows"]["main"]["metrics"])

    def test_graph_missing(self):
        self.fixture.manifest["metadata"]["native_graphs"]["main"].pop("asset_ref")
        self.fixture.save_manifest()
        row = self.project()["records"][0]
        self.assertNotEqual("AVAILABLE", row["windows"]["main"]["graph"]["state"])

    def test_conflicting_duplicate(self):
        index = self.index()
        index["eas"].append(copy.deepcopy(index["eas"][0]))
        self.assertEqual(2, len(self.project(index)["refused"]))
        self.assertEqual([], self.project(index)["records"])

    def test_diagnostic_models(self):
        for model in ("MODEL_2", "MODEL_0", "UNKNOWN", "DIAGNOSTIC"):
            with self.subTest(model=model):
                index = self.index()
                index["eas"][0]["evidence"].update(model=model, main={"pf": "999"})
                row = self.project(index)["records"][0]
                self.assertEqual({}, row["windows"]["main"]["metrics"])

    def test_missing_identity(self):
        index = self.index()
        index["eas"][0]["provenance"] = []
        row = self.project(index)["records"][0]
        self.assertIn("source_provenance", row["ref"]["missing"])
        self.assertEqual({}, row["windows"]["main"]["metrics"])

    def test_wrong_index_sha(self):
        with self.assertRaises(c.ProjectionError): c.project_index(self.index(), "a" * 40)

    def test_sensitive_parameter_not_echoed(self):
        index = self.index()
        index["eas"][0]["display_name"] = "password=private-value"
        self.assertNotIn("private-value", json.dumps(self.project(index)))

    def test_cross_install_comparison_refused(self):
        row = self.project()["records"][0]
        self.assertEqual("UNKNOWN_LINEAGE", c.comparison(row, row))
        a = {**row, "installation_lineage": "MT5-lane1", "source_build_id": "build-1"}
        b = {**a, "installation_lineage": "MT5-lane2"}
        self.assertEqual("INCOMPATIBLE_LINEAGE", c.comparison(a, b))


class CanonicalShelfTests(unittest.TestCase):
    def test_canonical_h08_and_inventory(self):
        with tempfile.TemporaryDirectory() as temp:
            shelf = c.build_catalog(ROOT, BASE, Path(temp) / "preview", "2026-09-12T12:00:00Z")
            self.assertEqual([], shelf["refused"])
            self.assertEqual(22, len(shelf["records"]))
            h08 = next(r for r in shelf["records"] if r["ref"]["ea_id"] == "b16-h08-usdjpy-h1")
            self.assertEqual("INTEGRITY_VALIDATED_REVIEW_UNKNOWN", h08["ref"]["package_status"])
            self.assertEqual("MT5-lane3", h08["installation_lineage"])
            self.assertEqual("MISSING", h08["windows"]["main"]["graph"]["state"])
            self.assertEqual("MISSING", h08["windows"]["bwd"]["graph"]["state"])
            self.assertEqual("35.0", next(p for p in h08["parameters"]["changed"] if p["name"] == "_16_RsiLow")["value"])
            self.assertIn("eqdd_pct", h08["windows"]["main"]["metrics"])
            with self.assertRaises(c.ProjectionError):
                c.build_catalog(ROOT, BASE, Path(temp) / "preview", "2026-09-12T12:00:00Z")


if __name__ == "__main__": unittest.main()
