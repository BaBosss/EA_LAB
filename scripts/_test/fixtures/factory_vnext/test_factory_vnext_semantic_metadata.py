# -*- coding: utf-8 -*-
import copy
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from _triage.factory_vnext.semantic_metadata import (
    SemanticMetadataError,
    build_supertrend_semantic_metadata,
    canonical_semantic_metadata_bytes,
    range_readiness,
    validate_semantic_metadata,
    write_supertrend_semantic_metadata,
    _semantic_identity,
)
from _triage.factory_vnext.range_generator import plan_parameter_range_from_metadata
from _triage.factory_vnext.contracts import stable_id


class SemanticMetadataTests(unittest.TestCase):
    def setUp(self):
        self.meta = build_supertrend_semantic_metadata(str(REPO_ROOT))

    def _param(self, name):
        rows = {row["parameter"]: row for row in self.meta["parameters"]}
        return rows[name]
    def test_extracts_exact_pilot_inputs_and_provenance(self):
        self.assertEqual(self.meta["schema_version"], "factory-vnext-semantic-metadata-v1")
        self.assertEqual(self.meta["authority"], "NON_AUTHORITATIVE_SIDECAR")
        self.assertEqual(self.meta["ConceptID"], "(TRD)_SuperTrendFlip")
        self.assertEqual(self.meta["StrategyVersion"], "rev05")
        self.assertEqual(self.meta["LogicalSymbol"], "BTCUSD")
        self.assertEqual(self.meta["ExecutionTF"], "H4")
        self.assertEqual(self.meta["KINT_001"]["state"], "OPEN")
        self.assertEqual(len(self.meta["parameters"]), 37)
        self.assertEqual(self.meta["source"]["path"], "ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev05.mq5")
        self.assertEqual(self.meta["preset"]["path"], "_mt5_auto/ab_sets/genstanding_stf/STF_BTC_H4_rev05_off.set")
        self.assertEqual(self.meta["source"]["sha256"], "93a86af1d8c36391a59c7cf1379bca0c664f38940be5fb8db1072d3a7d0f7640")
        self.assertEqual(self.meta["preset"]["sha256"], "5de0a383523948ad4b5a9ca5960c1459b12de5dd44d361b03d6bb32be0365a99")

    def test_source_type_default_and_preset_are_proven(self):
        atr = self._param("_01_AtrPeriod")
        self.assertEqual(atr["source_type"], {"status": "PROVEN", "value": "int"})
        self.assertEqual(atr["default_value"], {"status": "PROVEN", "value": 10})
        self.assertEqual(atr["preset_value"], {"status": "PROVEN", "value": 14})
        self.assertEqual(atr["value_behavior"], {"status": "PROVEN", "value": "INTEGER"})
        self.assertEqual(atr["semantic_type"]["status"], "UNKNOWN")
        self.assertEqual(atr["overall_status"], "PARTIAL")

    def test_bool_domain_is_proven_but_optimization_semantics_remain_unknown(self):
        allow_live = self._param("_06_AllowLive")
        self.assertEqual(allow_live["allowed_values"], {"status": "PROVEN", "value": [False, True]})
        self.assertEqual(allow_live["boundedness"], {"status": "PROVEN", "value": "BOUNDED"})
        self.assertEqual(allow_live["unit"], {"status": "PROVEN", "value": "UNITLESS"})
        self.assertEqual(allow_live["semantic_type"], {"status": "UNKNOWN", "value": None})
        self.assertEqual(allow_live["optimization_eligibility"]["status"], "UNKNOWN")
    def test_rerun_identity_and_bytes_are_stable(self):
        second = build_supertrend_semantic_metadata(str(REPO_ROOT))
        self.assertEqual(self.meta["SemanticMetadataID"], second["SemanticMetadataID"])
        self.assertEqual(canonical_semantic_metadata_bytes(self.meta), canonical_semantic_metadata_bytes(second))

    def test_no_absolute_host_path_leaks(self):
        payload = canonical_semantic_metadata_bytes(self.meta).decode("utf-8")
        self.assertNotIn(str(REPO_ROOT), payload)
        self.assertNotIn("D:\\", payload)
        self.assertNotIn("C:\\", payload)

    def test_range_readiness_is_fail_visible(self):
        ready = range_readiness(self.meta, "_06_AllowLive")
        self.assertEqual(ready["status"], "SEMANTICS_REQUIRED")
        self.assertIn("optimization_eligibility", ready["missing"])
        plan = plan_parameter_range_from_metadata(self.meta, "_06_AllowLive", "COARSE")
        self.assertEqual(plan["status"], "SEMANTICS_REQUIRED:semantics required")
        self.assertEqual(plan["candidates"], [])

    def test_unknown_name_cannot_manufacture_semantics(self):
        with tempfile.TemporaryDirectory(dir=str(REPO_ROOT / "scripts" / "_test" / "fixtures" / "factory_vnext")) as td:
            root = Path(td)
            src = root / "(TRD)_SuperTrendFlip_rev05.mq5"
            preset = root / "STF_BTC_H4_rev05_off.set"
            src.write_text("input double TotallyLooksLikeAtr = 1.0;\n", encoding="utf-8")
            preset.write_text("TotallyLooksLikeAtr=2.0\n", encoding="utf-8")
            meta = build_supertrend_semantic_metadata(str(REPO_ROOT), source_path=str(src), preset_path=str(preset))
            row = meta["parameters"][0]
            self.assertEqual(row["semantic_type"]["status"], "UNKNOWN")
            self.assertEqual(row["unit"]["status"], "UNKNOWN")
    def test_missing_and_conflicting_evidence_fail_visibly(self):
        with tempfile.TemporaryDirectory(dir=str(REPO_ROOT / "scripts" / "_test" / "fixtures" / "factory_vnext")) as td:
            root = Path(td)
            src = root / "(TRD)_SuperTrendFlip_rev05.mq5"
            preset = root / "STF_BTC_H4_rev05_off.set"
            preset.write_text("Flag=true\n", encoding="utf-8")
            with self.assertRaisesRegex(SemanticMetadataError, "source not found"):
                build_supertrend_semantic_metadata(str(REPO_ROOT), source_path=str(src), preset_path=str(preset))
            src.write_text("input bool Flag = false;\n", encoding="utf-8")
            preset.write_text("Flag=maybe\n", encoding="utf-8")
            with self.assertRaisesRegex(SemanticMetadataError, "invalid bool"):
                build_supertrend_semantic_metadata(str(REPO_ROOT), source_path=str(src), preset_path=str(preset))

    def test_wrong_identity_and_malformed_metadata_fail(self):
        wrong = copy.deepcopy(self.meta)
        wrong["ConceptID"] = "OtherStrategy"
        with self.assertRaisesRegex(SemanticMetadataError, "identity"):
            validate_semantic_metadata(wrong)
        malformed = copy.deepcopy(self.meta)
        del malformed["parameters"][0]["source_type"]
        with self.assertRaisesRegex(SemanticMetadataError, "source_type"):
            validate_semantic_metadata(malformed)

    def test_range_becomes_usable_only_when_required_semantics_are_proven(self):
        ready = copy.deepcopy(self.meta)
        row = next(item for item in ready["parameters"] if item["parameter"] == "_01_AtrPeriod")
        row["semantic_type"] = {"status": "PROVEN", "value": "period_lookback"}
        row["unit"] = {"status": "PROVEN", "value": "bars"}
        row["optimization_eligibility"] = {"status": "PROVEN", "value": True}
        row["optimization_domain"] = {"status": "PROVEN", "value": {"kind": "INTEGER", "min": 5, "max": 30}}
        ready["SemanticMetadataID"] = stable_id("SMETA", _semantic_identity(ready), hex_chars=24)
        plan = plan_parameter_range_from_metadata(ready, "_01_AtrPeriod", "COARSE")
        self.assertEqual(plan["status"], "COARSE")
        self.assertEqual(plan["candidates"], [5, 6, 7, 9, 13, 30])
    def test_checked_in_sidecar_matches_generator_bytes(self):
        target = REPO_ROOT / "factory" / "vnext" / "semantic_metadata" / "supertrend_rev05_btcusd_h4.json"
        self.assertTrue(target.is_file(), str(target))
        self.assertEqual(target.read_bytes(), canonical_semantic_metadata_bytes(self.meta))
        with tempfile.TemporaryDirectory(dir=str(REPO_ROOT / "scripts" / "_test" / "fixtures" / "factory_vnext")) as td:
            out = Path(td) / "semantic.json"
            written = write_supertrend_semantic_metadata(str(REPO_ROOT), str(out))
            self.assertEqual(Path(written).read_bytes(), target.read_bytes())


if __name__ == "__main__":
    unittest.main()
