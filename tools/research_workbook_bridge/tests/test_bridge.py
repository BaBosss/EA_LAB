import copy
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "tools/research_workbook_bridge"
REF = "018ed2f7379ebaf404444f0d203711379e8f2f22"
WORKBOOK = TOOL / "fixtures/workbook_plan_b11_fixture.json"
UNIVERSE = TOOL / "fixtures/test_universe_fixture.json"
PILOT = "factory/vnext/pilots/boss11_h01_first_green"

spec = importlib.util.spec_from_file_location("bridge", TOOL / "bridge.py")
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class BridgeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = WORKBOOK.read_bytes()
        cls.validation = bridge.validate_workbook_payload_with_canonical_js(ROOT, REF, cls.payload)
        cls.book = bridge.parse_validated_workbook(cls.payload, cls.validation)
        cls.plan = bridge.build_plan_export(cls.book, REF)
        cls.plan["planning_schema_validation"] = cls.validation
        cls.proposal = bridge.build_execution_proposal(ROOT, REF, cls.book, cls.plan, PILOT)
        cls.result = bridge.result_binding_template(REF, cls.proposal)

    def test_canonical_workbook_validator_reused(self):
        self.assertEqual("PASS", self.validation["status"])
        self.assertEqual(f"git:{REF}:mobile_report_hub/research_workbook.js", self.validation["validator"])
        self.assertEqual(REF, self.validation["validator_ref"])
        expected = bridge.sha256_bytes(bridge.git_blob(ROOT, REF, "mobile_report_hub/research_workbook.js"))
        self.assertEqual(expected, self.validation["validator_sha256"])
        self.assertEqual(bridge.sha256_bytes(self.payload), self.validation["workbook_sha256"])
        self.assertEqual("STRUCTURAL_VALIDATION_ONLY_NO_EXECUTION_AUTHORITY", self.validation["authority"])

    def test_exact_source_identity_retained(self):
        src = self.proposal["source_identity"]
        self.assertEqual("ea_template/Boss_11_GridTrend.mq5", src["source_ref"])
        self.assertEqual("59c51ad12ecc0450c19bffa373f836a95c0c3fe6808a2029fcc946f28c29f672", src["source_sha256"])
        self.assertEqual("EXACT_GIT_BLOB_MATCH", src["status"])
        self.assertEqual(src["source_sha256"], self.proposal["factory"]["factory_source_sha256"])

    def test_owner_and_unknown_parameter_states_preserved(self):
        rows = {row["name"]: row for row in self.proposal["parameters"]}
        self.assertEqual("LOCKED", rows["_0_ATR_Period"]["workbook_classification"])
        self.assertEqual("OWNER_REQUIRED", rows["_0_FastMA"]["workbook_classification"])
        self.assertEqual("UNKNOWN", rows["_0_SlowMA"]["workbook_classification"])
        self.assertIsNone(rows["_0_FastMA"]["execution_value"])
        self.assertIsNone(rows["_0_FastMA"]["execution_range"])
        self.assertFalse(rows["_0_FastMA"]["workbook_range_proposal"]["complete"])

    def test_execution_is_blocked_not_inferred(self):
        self.assertFalse(self.proposal["can_execute"])
        blockers = set(self.proposal["blockers"])
        for expected in [
            "BUILD_IDENTITY_OWNER_OR_BUILD_GATE_REQUIRED",
            "CANONICAL_TEST_UNIVERSE_UNAVAILABLE",
            "HOME_SYMBOL_CANONICAL_FREEZE_REQUIRED",
            "HOME_TIMEFRAME_CANONICAL_FREEZE_REQUIRED",
            "OPTIMIZATION_AUTHORITY_NOT_GRANTED",
            "PARAMETER_OWNER_REQUIRED:_0_FastMA",
            "PARAMETER_UNKNOWN:_0_SlowMA",
        ]:
            self.assertIn(expected, blockers)
        self.assertEqual([], self.proposal["home"]["logical_symbol_proposals"])
        self.assertEqual([], self.proposal["home"]["timeframe_proposals"])

    def test_no_workbook_set_generation(self):
        so = self.proposal["set_output"]
        self.assertFalse(so["generated_from_workbook"])
        self.assertEqual("REFERENCE_ONLY", so["authority"])
        self.assertTrue(so["factory_compat_reference"].endswith(".set"))
        self.assertRegex(so["factory_compat_sha256"], r"^[0-9a-f]{64}$")

    def test_holdout_unspent_and_result_binding_empty(self):
        self.assertEqual("LOCKED_UNSPENT", self.proposal["holdout"]["state"])
        self.assertFalse(self.proposal["holdout"]["spend_authorized"])
        self.assertEqual("UNAVAILABLE_NO_ACCEPTED_RUN", self.result["verification_status"])
        self.assertIsNone(self.result["metrics"]["profit_factor"])
        self.assertIsNone(self.result["interpretation"])
        self.assertIsNone(self.result["decision"])

    def test_canonical_test_universe_absence_is_fail_visible(self):
        fixture = json.loads(UNIVERSE.read_text(encoding="utf-8"))
        check = bridge.validate_test_universe_fixture(ROOT, REF, fixture)
        self.assertEqual("PASS_SCHEMA_REQUIRED_ENUM_SUBSET", check["status"])
        self.assertEqual("SYNTHETIC_FIXTURE_ONLY", check["authority"])
        self.assertEqual("factory/universe.jsonl", check["canonical_owner_path"])
        self.assertFalse(check["canonical_owner_path_exists"])

    def test_source_hash_mismatch_blocks(self):
        book = copy.deepcopy(self.book)
        book["identity"]["source_sha256"] = "0" * 64
        plan = bridge.build_plan_export(book, REF)
        p = bridge.build_execution_proposal(ROOT, REF, book, plan, PILOT)
        self.assertFalse(p["can_execute"])
        self.assertIn("SOURCE_SHA256_MISMATCH", p["blockers"])

    def test_searchable_without_range_blocks_and_never_invents(self):
        book = copy.deepcopy(self.book)
        book["parameters"][1]["search_state"] = "SEARCHABLE"
        plan = bridge.build_plan_export(book, REF)
        p = bridge.build_execution_proposal(ROOT, REF, book, plan, PILOT)
        self.assertIn("SEARCHABLE_RANGE_INCOMPLETE:_0_FastMA", p["blockers"])
        row = next(x for x in p["parameters"] if x["name"] == "_0_FastMA")
        self.assertIsNone(row["execution_range"])

    def test_holdout_forgery_refused_by_canonical_planning_validator(self):
        book = copy.deepcopy(self.book)
        book["windows"][2]["state"] = "READY"
        payload = json.dumps(book).encode("utf-8")
        with self.assertRaises(bridge.BridgeRefusal):
            bridge.validate_workbook_payload_with_canonical_js(ROOT, REF, payload)

    def test_validated_receipt_rejects_mutated_payload_bytes(self):
        receipt = bridge.validate_workbook_payload_with_canonical_js(ROOT, REF, self.payload)
        mutated = self.payload.replace(b"BRIDGE-FIXTURE-B11", b"BRIDGE-FIXTURE-X11", 1)
        self.assertNotEqual(bridge.sha256_bytes(self.payload), bridge.sha256_bytes(mutated))
        with self.assertRaises(bridge.BridgeRefusal):
            bridge.parse_validated_workbook(mutated, receipt)

    def test_typed_artifact_contract_required_fields(self):
        schema = json.loads((TOOL / "artifact_schemas.json").read_text(encoding="utf-8"))
        pairs = [
            ("WORKBOOK_PLAN_EXPORT", self.plan, bridge.PLAN_SCHEMA),
            ("EXECUTION_PROPOSAL", self.proposal, bridge.PROPOSAL_SCHEMA),
            ("RESULT_BINDING", self.result, bridge.RESULT_SCHEMA),
        ]
        for name, obj, version in pairs:
            definition = schema["$defs"][name]
            self.assertEqual(version, obj["schema_version"])
            self.assertFalse(set(definition["required"]) - set(obj))

    def test_deterministic_package_bytes(self):
        with tempfile.TemporaryDirectory(prefix="bridge-det-") as td:
            a, b = Path(td) / "a", Path(td) / "b"
            cmd = [
                sys.executable, "-B", str(TOOL / "bridge.py"),
                "--repo", str(ROOT), "--ref", REF,
                "--workbook", str(WORKBOOK),
                "--factory-pilot-dir", PILOT,
                "--test-universe-fixture", str(UNIVERSE),
            ]
            ra = subprocess.run(cmd + ["--output-root", str(a)], capture_output=True, text=True, check=True)
            rb = subprocess.run(cmd + ["--output-root", str(b)], capture_output=True, text=True, check=True)
            self.assertEqual(json.loads(ra.stdout)["manifest_sha256"], json.loads(rb.stdout)["manifest_sha256"])
            self.assertEqual({p.name:p.read_bytes() for p in a.iterdir()},
                             {p.name:p.read_bytes() for p in b.iterdir()})

if __name__ == "__main__":
    unittest.main()
