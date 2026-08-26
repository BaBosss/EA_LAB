from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.architecture import (
    make_master_mold,
    make_strategy_family,
    make_strategy_variant,
)
from _triage.factory_vnext.parameter_surface import make_variant_parameter_surface
from _triage.factory_vnext.variant_generator import make_variant_build_package
from _triage.factory_vnext.mt5_set_compat import (
    MT5SetCompatError,
    build_mt5_set_compat,
    render_proposed_set,
    serialize_compat_manifest,
)
from _triage.factory_vnext.contracts import stable_id


class FactoryVNextMT5SetCompatTests(unittest.TestCase):
    _IDENTITY_KEYS = (
        "source_commit", "TemplateID", "MasterMoldID", "MasterMoldVersion",
        "MasterMoldSnapshotID", "FamilyID", "VariantID", "VariantSnapshotID",
        "StrategyVersion", "ParameterSurfaceID", "hypothesis_revision", "build_tag",
        "ActiveCapabilities", "EnabledComponents", "ParameterProjection",
    )

    def _package(self):
        master = make_master_mold("MOLD1", "1", ["CAP_ENTRY"])
        family = make_strategy_family(master, "B14", "Boss14", ["CAP_ENTRY"], "14")
        variant = make_strategy_variant(family, "B14-V01", "1.0", [], [], "14-01")
        bindings = [
            {
                "hypothesis_revision": "B14-H01-r1", "build_tag": "LAB_ENTRY_14",
                "parameter_pid": 100, "parameter": "AtrPeriod", "role": "TUNABLE",
                "surface": "OPERATOR", "optimize_stage": "SIGNAL",
                "safe_range": [10, 14, 20], "locked_value": None,
            },
            {
                "hypothesis_revision": "B14-H01-r1", "build_tag": "LAB_ENTRY_14",
                "parameter_pid": 200, "parameter": "FixedLot", "role": "LOCKED",
                "surface": "HIDDEN", "optimize_stage": "FREEZE",
                "safe_range": None, "locked_value": 0.01,
            },
        ]
        display = [
            {"parameter_pid": 100, "parameter": "AtrPeriod", "display_label": "ATR",
             "portability": "PORTABLE", "unit_true": "bars", "relation_hint": "none", "relations": []},
            {"parameter_pid": 200, "parameter": "FixedLot", "display_label": "Lot",
             "portability": "PORTABLE", "unit_true": "lot", "relation_hint": "none", "relations": []},
        ]
        surface = make_variant_parameter_surface(variant, bindings, display, "B14-H01-r1", "LAB_ENTRY_14")
        return make_variant_build_package(
            master=master, family=family, variant=variant, parameter_surface=surface,
            source_commit="a" * 40, template_id="EA_TEMPLATE_V2",
        )

    def _reidentified(self, package, projection):
        changed = {**package, "ParameterProjection": projection}
        identity = {key: changed[key] for key in self._IDENTITY_KEYS}
        changed["PackageID"] = stable_id("VPKG", identity, hex_chars=24)
        return changed

    def test_projection_drives_deterministic_dry_run_and_disables_snapshot_optimizer(self):
        package = self._package()
        baseline = "; keep this comment\nFixedLot=0.02||0.01||0.01||0.10||Y\nAtrPeriod=14||10||1||20||Y\n"

        result = build_mt5_set_compat(package, baseline)

        self.assertEqual([row["parameter"] for row in result["operator_rows"]], ["AtrPeriod", "FixedLot"])
        self.assertEqual(result["operator_rows"][0]["disposition"], "MATCH")
        self.assertEqual(result["operator_rows"][1]["projection"], "SNAPSHOT_ONLY")
        self.assertTrue(result["operator_rows"][1]["optimizer_disabled"])
        proposed = render_proposed_set(result)
        self.assertIn("; keep this comment", proposed)
        self.assertIn("AtrPeriod=14||10||1||20||Y", proposed)
        self.assertIn("FixedLot=0.02||0.01||0.01||0.10||N", proposed)
        self.assertEqual(proposed, render_proposed_set(build_mt5_set_compat(package, baseline)))
        self.assertEqual(serialize_compat_manifest(result), serialize_compat_manifest(build_mt5_set_compat(package, baseline)))

    def test_tampered_package_duplicate_baseline_and_ambiguous_projection_refuse(self):
        package = self._package()
        with self.assertRaisesRegex(MT5SetCompatError, "PackageID"):
            build_mt5_set_compat({**package, "PackageID": "VPKG-bad"}, "AtrPeriod=14\nFixedLot=0.01\n")
        with self.assertRaisesRegex(MT5SetCompatError, "sets 'AtrPeriod' twice"):
            build_mt5_set_compat(package, "AtrPeriod=14\nAtrPeriod=15\nFixedLot=0.01\n")
        duplicate_name = self._reidentified(package, package["ParameterProjection"] + [dict(package["ParameterProjection"][0])])
        with self.assertRaisesRegex(MT5SetCompatError, "duplicate ParameterProjection parameter AtrPeriod"):
            build_mt5_set_compat(duplicate_name, "AtrPeriod=14\nFixedLot=0.01\n")
        duplicate_pid_row = {**package["ParameterProjection"][1], "parameter": "OtherLocked", "parameter_pid": 100}
        duplicate_pid = self._reidentified(package, [package["ParameterProjection"][0], duplicate_pid_row])
        with self.assertRaisesRegex(MT5SetCompatError, "duplicate ParameterProjection parameter_pid 100"):
            build_mt5_set_compat(duplicate_pid, "AtrPeriod=14\nOtherLocked=0.01\n")

    def test_unknown_key_and_semantics_required_refuse_without_mutating_baseline(self):
        package = self._package()
        baseline = "AtrPeriod=14\nFixedLot=0.01\nRemovedThing=7\n"
        result = build_mt5_set_compat(package, baseline, {"AtrPeriod": "UNKNOWN"})
        self.assertEqual(result["baseline_text"], baseline)
        self.assertEqual(result["operator_rows"][0]["semantic_state"], "UNKNOWN")
        self.assertEqual(result["refusal_rows"], [{"parameter": "RemovedThing", "disposition": "REFUSE", "reason": "UNKNOWN_OR_REMOVED_BASELINE_KEY"}])
        with self.assertRaisesRegex(MT5SetCompatError, "RemovedThing"):
            render_proposed_set(result)
        required = build_mt5_set_compat(package, "AtrPeriod=14\nFixedLot=0.01\n", {"AtrPeriod": "SEMANTICS_REQUIRED"})
        self.assertEqual(required["operator_rows"][0]["disposition"], "REFUSE")
        with self.assertRaisesRegex(MT5SetCompatError, "AtrPeriod"):
            render_proposed_set(required)

    def test_missing_projection_key_is_only_added_when_locked_value_is_renderable(self):
        package = self._package()
        added = build_mt5_set_compat(package, "AtrPeriod=14\n")
        locked = added["operator_rows"][1]
        self.assertEqual((locked["disposition"], locked["proposed_value"]), ("ADD", "0.01"))
        self.assertIn("FixedLot=0.01", render_proposed_set(added))
        unmapped = build_mt5_set_compat(package, "FixedLot=0.01\n")
        active = unmapped["operator_rows"][0]
        self.assertEqual(active["disposition"], "UNMAPPED")
        with self.assertRaisesRegex(MT5SetCompatError, "AtrPeriod"):
            render_proposed_set(unmapped)


if __name__ == "__main__":
    unittest.main(verbosity=2)
