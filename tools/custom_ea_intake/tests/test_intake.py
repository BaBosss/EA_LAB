"""Offline positive/negative public-boundary tests; no MT5 and no production writes."""
import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "intake.py"
spec = importlib.util.spec_from_file_location("custom_intake", MODULE)
intake = importlib.util.module_from_spec(spec)
spec.loader.exec_module(intake)


def csv_records(path):
    with path.open(encoding="utf-8-sig", newline="") as source:
        return list(csv.DictReader(source))


class CatalogTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.tmp = Path(self.temp.name)
        self.root = self.tmp / "my_custom_eas"
        self.root.mkdir()
        self.projects = self.tmp / "ea_projects"
        self.projects.mkdir()
        self.original = self.root / "01_Boss_Custom_fxDreema" / "(Boss) Dynamic RSI"
        self.original.mkdir(parents=True)
        (self.original / "rsi.mq4").write_text("void OnTick() {}\n", encoding="utf-8")
        (self.original / "rsi_copy.mq4").write_text("void OnTick() {}\n", encoding="utf-8")
        ai = self.root / "02_AI_Generated_Bots" / "MT5"
        ai.mkdir(parents=True)
        (ai / "EA03.ex5").write_bytes(b"opaque binary")
        sets = self.root / "05_Optimization_and_Presets"
        sets.mkdir()
        (sets / "a.set").write_text(
            "ATR=14||2||1||28||Y\nMaxRisk=1.0\npassword=NO_EXPORT\n", encoding="utf-8")
        ext = self.projects / "(BRK)_Pattern"
        ext.mkdir()
        (ext / "entry.mq5").write_text("void OnTick(){}\n", encoding="utf-8")
        self.index = self.root / "CUSTOM_EA_INDEX.csv"
        with self.index.open("w", newline="", encoding="utf-8") as target:
            writer = csv.DictWriter(target, fieldnames=[
                "Category", "Name", "FilesCount", "Path", "TargetChassis"])
            writer.writeheader()
            writer.writerow({"Category": "Boss", "Name": "Dynamic RSI",
                "FilesCount": 2,
                "Path": r"01_Boss_Custom_fxDreema\(Boss) Dynamic RSI",
                "TargetChassis": "Boss_13"})
            writer.writerow({"Category": "AI", "Name": "EA03",
                "FilesCount": 1, "Path": "02_AI_Generated_Bots",
                "TargetChassis": "Boss_15"})
            writer.writerow({"Category": "BAD", "Name": "Escape",
                "FilesCount": 1, "Path": r"..\..\secret",
                "TargetChassis": ""})

    def test_scan_exact_artifact_census_and_no_authority(self):
        out = self.tmp / "report"
        result = intake.scan(self.root, out, self.index, self.projects)
        self.assertEqual(result["original_file_count"], 5)
        self.assertEqual(result["source_catalog_rows"], 3)
        self.assertEqual(result["duplicate_extra_copies"], 1)
        self.assertEqual(result["external_project_folders"], 1)
        self.assertFalse(result["live_execution_allowed"])
        self.assertFalse(result["factory_submit_allowed"])
        self.assertEqual(result["mapping_states"]["UNRESOLVED_BROAD_FOLDER"], 1)
        self.assertEqual(result["mapping_states"]["UNRESOLVED_UNSAFE_OR_EMPTY_PATH"], 1)
        rows = csv_records(out / "LEGACY_CROSSWALK.csv")
        self.assertEqual(rows[0]["mapping_state"], "FOLDER_PATH_ONLY_SEMANTICS_UNVERIFIED")
        self.assertEqual(rows[0]["actual_file_count"], "2")
        self.assertEqual(rows[0]["strategy_id"], "")
        self.assertTrue(rows[0]["provisional_candidate_id"].startswith("CAND-"))
        self.assertIsNone(json.loads((out / "RESEARCH_MONITOR_PROJECTION_DRAFT.json").read_text(
            encoding="utf-8"))["records"][0]["result"])
        self.assertEqual(len(csv_records(out / "EXTERNAL_PROJECTS.csv")), 1)
        self.assertFalse((self.original / "links.json").exists())
        with self.assertRaises(ValueError):
            intake.scan(self.root, out, self.index, self.projects)

    def test_preset_value_and_optimizer_lattice_preserved_no_secret(self):
        out = self.tmp / "report"
        intake.scan(self.root, out, self.index, self.projects)
        rows = csv_records(out / "PRESET_PARAMETERS.csv")
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["raw_value"], "14")
        self.assertEqual(rows[0]["optimization_start"], "2")
        self.assertEqual(rows[0]["optimization_enabled"], "Y")
        self.assertEqual(rows[0]["binding"], "UNRESOLVED_NO_EFFECTIVE_CONFIG")
        self.assertNotIn("NO_EXPORT", (out / "PRESET_PARAMETERS.csv").read_text(encoding="utf-8-sig"))

    def test_common_credential_style_keys_are_never_exported(self):
        (self.root / "05_Optimization_and_Presets" / "cred.set").write_text(
            "Passwd=hunter2\nLogin=12345678\nPwd=zzz\nServer=Broker-Live\nInpToken=abc\n"
            "InvestorPassword=q\nTelegramChatId=99\nLots=0.1||0.1||0.1||1.0||N\n", encoding="utf-8")
        out = self.tmp / "report"
        result = intake.scan(self.root, out, self.index, self.projects)
        text = (out / "PRESET_PARAMETERS.csv").read_text(encoding="utf-8-sig")
        for leaked in ("hunter2", "LOGINVALUE", "PWDVALUE", "Broker-Live", "TOKENVALUE", "INVVALUE", "CHATVALUE"):
            self.assertNotIn(leaked, text)
        self.assertIn("Lots", text)
        self.assertGreaterEqual(result["redacted_parameter_rows"], 7)

    def test_utf16_set_decoding(self):
        val = self.root / "05_Optimization_and_Presets" / "utf16.set"
        val.write_bytes("Length=21\r\n".encode("utf-16"))
        out = self.tmp / "report"
        result = intake.scan(self.root, out, self.index, self.projects)
        self.assertEqual(result["preset_files"], 2)
        self.assertEqual(len(result["read_failures"]), 0)
        self.assertIn("Length", [r["parameter"] for r in csv_records(out / "PRESET_PARAMETERS.csv")])

    def test_source_tree_is_not_output_location(self):
        with self.assertRaisesRegex(ValueError, "outside source"):
            intake.scan(self.root, self.root / "not_allowed", self.index, self.projects)
        self.assertFalse((self.root / "not_allowed").exists())
        with self.assertRaises(ValueError):
            intake.scan(self.root, self.projects / "inside", self.index, self.projects)

    def test_invalid_legacy_reference_is_fail_closed(self):
        rows = csv_records(self.index)
        rows[2]["Path"] = r"C:\Windows\System32"
        with self.index.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
        intake.scan(self.root, self.tmp / "out", self.index, self.projects)
        result = csv_records(self.tmp / "out" / "LEGACY_CROSSWALK.csv")
        self.assertEqual(result[2]["mapping_state"], "UNRESOLVED_UNSAFE_OR_EMPTY_PATH")


class DraftTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "my_custom_eas"
        self.root.mkdir()
        self.tmp = Path(self.temp.name)
        self.draft = {
            "schema": "ea-builder-draft-v1",
            "authority": "LOCAL_DRAFT_UNVERIFIED", "revision": "r1",
            "parent_revision": None,
            "entry_mode": "ENTRY_ONLY", "title": "Example EA",
            "intent": "BUILD_ONLY",
            "notes": "This is not a verified strategy",
            "bindings": {k: {"id": "", "revision": ""} for k in
                         ("template_release", "default_profile", "entry_contract", "test_plan")},
            "plans": [{"name": "future", "enabled": False}],
        }
        self.path = self.tmp / "builder.json"
        self.path.write_text(json.dumps(self.draft), encoding="utf-8")

    def test_new_strategy_scaffold_is_draft_only_and_no_overwrite(self):
        result = intake.init_strategy(self.root, "RSI_MR_001")
        self.assertEqual(result["status"], "DRAFT_NOT_ADMITTED")
        card = json.loads((self.root / "06_Template_Converted" / "RSI_MR_001"
                           / "spec" / "strategy_card.json").read_text(encoding="utf-8"))
        self.assertIsNone(card["mechanics"]["entry_buy"])
        self.assertEqual(card["owner_review"], "NOT_APPROVED")
        self.assertEqual(len(list((self.root / "06_Template_Converted" / "RSI_MR_001"
                                  / "runs").iterdir())), 0)
        with self.assertRaises(ValueError):
            intake.init_strategy(self.root, "RSI_MR_001")

    def test_directory_traversal_refused(self):
        for value in ("../../evil", "sample", "CON", "COM1", "LPT9", "S|B", "EA--x\\bad"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    intake.init_strategy(self.root, value)
        self.assertFalse((self.tmp / "evil").exists())

    def test_builder_reference_is_not_submission(self):
        result = intake.import_builder_draft(self.path, self.tmp / "draft_ref.json")
        self.assertFalse(result["can_submit"])
        self.assertFalse(result["can_execute"])
        self.assertIsNone(result["effective_configuration"])
        self.assertEqual(result["authority"], "DRAFT_NOT_SUBMITTED")
        with self.assertRaises(ValueError):
            intake.import_builder_draft(self.path, self.tmp / "draft_ref.json")

    def test_enabled_plan_refused(self):
        self.draft["plans"][0]["enabled"] = True
        self.path.write_text(json.dumps(self.draft), encoding="utf-8")
        with self.assertRaises(ValueError):
            intake.import_builder_draft(self.path, self.tmp / "should_not_create.json")
        self.assertFalse((self.tmp / "should_not_create.json").exists())

    def test_unknown_draft_authority_refused(self):
        self.draft["authority"] = "APPROVED"
        self.path.write_text(json.dumps(self.draft), encoding="utf-8")
        with self.assertRaises(ValueError):
            intake.import_builder_draft(self.path, self.tmp / "should_not_create.json")

    def test_duplicate_json_key_refused(self):
        payload = json.dumps(self.draft).replace(
            "\"authority\": \"LOCAL_DRAFT_UNVERIFIED\"",
            "\"authority\": \"APPROVED\", \"authority\": \"LOCAL_DRAFT_UNVERIFIED\"")
        self.path.write_text(payload, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Duplicate JSON key"):
            intake.import_builder_draft(self.path, self.tmp / "rejected.json")


if __name__ == "__main__":
    unittest.main(verbosity=2)
