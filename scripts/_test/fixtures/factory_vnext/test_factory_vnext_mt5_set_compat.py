from __future__ import annotations

import hashlib
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
        "ActiveCapabilities", "EnabledComponents", "ParameterProjection", "BaselineCoverage",
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
        identity = {key: changed[key] for key in self._IDENTITY_KEYS if key in changed}
        changed["PackageID"] = stable_id("VPKG", identity, hex_chars=24)
        return changed

    def _coverage_package(self, coverage):
        package = self._package()
        package["BaselineCoverage"] = sorted(coverage, key=lambda row: row["baseline_parameter"])
        identity = {key: package[key] for key in self._IDENTITY_KEYS if key in package}
        package["PackageID"] = stable_id("VPKG", identity, hex_chars=24)
        return package

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

    def test_existing_layout_is_preserved_and_manifest_hashes_exact_rendered_bytes(self):
        package = self._package()
        baseline = (
            "; header stays first\n"
            "FixedLot = 0.02||0.01||0.01||0.10||Y\n"
            "\n"
            "; ATR remains after the blank line\n"
            "AtrPeriod=14||10||1||20||Y\n"
        )
        expected = (
            "; header stays first\n"
            "FixedLot = 0.02||0.01||0.01||0.10||N\n"
            "\n"
            "; ATR remains after the blank line\n"
            "AtrPeriod=14||10||1||20||Y\n"
        )

        result = build_mt5_set_compat(package, baseline)

        self.assertEqual(render_proposed_set(result), expected)
        self.assertEqual(result["manifest"]["baseline_sha256"], hashlib.sha256(baseline.encode("utf-8")).hexdigest())
        self.assertEqual(result["manifest"]["proposed_output_sha256"], hashlib.sha256(expected.encode("utf-8")).hexdigest())

    def test_snapshot_optimizer_tail_must_be_complete_and_unambiguous(self):
        package = self._package()
        for tail in ("0.01||0.01||0.10", "0.01||||0.10||Y", "0.01||0.01||0.10||MAYBE"):
            with self.subTest(tail=tail):
                result = build_mt5_set_compat(package, "AtrPeriod=14\nFixedLot=0.02||%s\n" % tail)
                self.assertEqual(result["operator_rows"][1]["disposition"], "REFUSE")
                with self.assertRaisesRegex(MT5SetCompatError, "FixedLot"):
                    render_proposed_set(result)

    def test_conflicting_semantic_state_and_status_refuse(self):
        with self.assertRaisesRegex(MT5SetCompatError, "conflicting semantic state/status for AtrPeriod"):
            build_mt5_set_compat(
                self._package(), "AtrPeriod=14\nFixedLot=0.01\n",
                {"AtrPeriod": {"state": "READY", "status": "SEMANTICS_REQUIRED"}},
            )

    def test_projection_rows_require_canonical_fields_and_coherent_role_projection(self):
        package = self._package()
        missing_safe_range = dict(package["ParameterProjection"][0])
        del missing_safe_range["safe_range"]
        with self.assertRaisesRegex(MT5SetCompatError, "safe_range is required for AtrPeriod"):
            build_mt5_set_compat(
                self._reidentified(package, [missing_safe_range, package["ParameterProjection"][1]]),
                "AtrPeriod=14\nFixedLot=0.01\n",
            )
        mismatched = {**package["ParameterProjection"][0], "projection": "SNAPSHOT_ONLY"}
        with self.assertRaisesRegex(MT5SetCompatError, "role/projection mismatch for AtrPeriod"):
            build_mt5_set_compat(
                self._reidentified(package, [mismatched, package["ParameterProjection"][1]]),
                "AtrPeriod=14\nFixedLot=0.01\n",
            )

    def test_identity_bound_coverage_maps_scoped_project_and_preserves_known_snapshot(self):
        coverage = [
            {
                "baseline_parameter": "LegacyAtr",
                "parameter_pid": 100,
                "projection_parameter": "AtrPeriod",
                "disposition": "PROJECT",
            },
            {
                "baseline_parameter": "FixedLot",
                "parameter_pid": 200,
                "projection_parameter": "FixedLot",
                "disposition": "PROJECT",
            },
            {
                "baseline_parameter": "LegacyMode",
                "parameter_pid": 999,
                "projection_parameter": None,
                "disposition": "PRESERVE_SNAPSHOT",
            },
        ]
        baseline = (
            "LegacyAtr=14||10||1||20||Y\n"
            "FixedLot=0.02||0.01||0.01||0.10||Y\n"
            "LegacyMode=7||1||1||10||Y\n"
        )

        result = build_mt5_set_compat(self._coverage_package(coverage), baseline)

        self.assertEqual(result["refusal_rows"], [])
        rows = {row["parameter"]: row for row in result["operator_rows"]}
        self.assertEqual(rows["LegacyAtr"]["projection_parameter"], "AtrPeriod")
        self.assertEqual(rows["LegacyAtr"]["disposition"], "MATCH")
        self.assertEqual(rows["LegacyMode"]["disposition"], "PRESERVE_SNAPSHOT")
        self.assertTrue(rows["LegacyMode"]["optimizer_disabled"])
        proposed = render_proposed_set(result)
        self.assertIn("LegacyAtr=14||10||1||20||Y", proposed)
        self.assertIn("FixedLot=0.02||0.01||0.01||0.10||N", proposed)
        self.assertIn("LegacyMode=7||1||1||10||N", proposed)

    def test_coverage_refuses_unknown_or_case_mismatched_physical_baseline_keys(self):
        coverage = [
            {
                "baseline_parameter": "legacyatr",
                "parameter_pid": 100,
                "projection_parameter": "AtrPeriod",
                "disposition": "PROJECT",
            },
        ]
        package = self._coverage_package(coverage)
        result = build_mt5_set_compat(package, "LegacyAtr=14\nUnknownThing=7\n")

        self.assertEqual(
            result["refusal_rows"],
            [
                {"parameter": "LegacyAtr", "disposition": "REFUSE", "reason": "BASELINE_COVERAGE_CASE_MISMATCH"},
                {"parameter": "UnknownThing", "disposition": "REFUSE", "reason": "UNKNOWN_OR_REMOVED_BASELINE_KEY"},
            ],
        )
        with self.assertRaisesRegex(MT5SetCompatError, "LegacyAtr, UnknownThing"):
            render_proposed_set(result)

    def test_missing_covered_snapshot_project_adds_its_physical_baseline_alias(self):
        coverage = [{
            "baseline_parameter": "LegacyFixedLot",
            "parameter_pid": 200,
            "projection_parameter": "FixedLot",
            "disposition": "PROJECT",
        }]

        result = build_mt5_set_compat(self._coverage_package(coverage), "")

        self.assertEqual(result["refusal_rows"], [])
        self.assertEqual(
            result["operator_rows"],
            [
                {
                    **self._package()["ParameterProjection"][1],
                    "parameter": "LegacyFixedLot",
                    "baseline_parameter": "LegacyFixedLot",
                    "projection_parameter": "FixedLot",
                    "coverage_disposition": "PROJECT",
                    "baseline_present": False,
                    "baseline_value": None,
                    "baseline_tail": None,
                    "semantic_state": None,
                    "optimizer_disabled": False,
                    "disposition": "ADD",
                    "proposed_value": "0.01",
                    "proposed_tail": None,
                },
            ],
        )
        self.assertEqual(render_proposed_set(result), "LegacyFixedLot=0.01\n")

    def test_missing_covered_active_project_refuses_without_output(self):
        coverage = [{
            "baseline_parameter": "LegacyAtr",
            "parameter_pid": 100,
            "projection_parameter": "AtrPeriod",
            "disposition": "PROJECT",
        }]

        result = build_mt5_set_compat(self._coverage_package(coverage), "")

        self.assertEqual(result["refusal_rows"], [])
        self.assertEqual(
            [(row["parameter"], row["disposition"], row["reason"])
            for row in result["operator_rows"]],
            [("LegacyAtr", "UNMAPPED", "MISSING_ACTIVE_TUNABLE")],
        )
        self.assertIsNone(result["proposed_set_text"])
        with self.assertRaisesRegex(MT5SetCompatError, "LegacyAtr"):
            render_proposed_set(result)

    def test_missing_covered_snapshot_project_refuses_when_locked_value_is_not_renderable(self):
        coverage = [{
            "baseline_parameter": "LegacyFixedLot",
            "parameter_pid": 200,
            "projection_parameter": "FixedLot",
            "disposition": "PROJECT",
        }]
        package = self._coverage_package(coverage)
        invalid_locked = {**package["ParameterProjection"][1], "locked_value": [0.01]}
        package = self._reidentified(package, [package["ParameterProjection"][0], invalid_locked])

        result = build_mt5_set_compat(package, "")

        self.assertEqual(
            [(row["parameter"], row["disposition"], row["reason"])
            for row in result["operator_rows"]],
            [("LegacyFixedLot", "UNMAPPED", "NO_RENDERABLE_LOCKED_VALUE")],
        )
        self.assertIsNone(result["proposed_set_text"])
        with self.assertRaisesRegex(MT5SetCompatError, "LegacyFixedLot"):
            render_proposed_set(result)

    def test_missing_preserve_snapshot_coverage_is_ignored_without_addition(self):
        coverage = [{
            "baseline_parameter": "LegacyMode",
            "parameter_pid": 999,
            "projection_parameter": None,
            "disposition": "PRESERVE_SNAPSHOT",
        }]

        result = build_mt5_set_compat(self._coverage_package(coverage), "")

        self.assertEqual(result["operator_rows"], [])
        self.assertEqual(render_proposed_set(result), "")

    def test_legacy_package_without_coverage_retains_projection_only_behavior(self):
        package = self._package()
        baseline = "AtrPeriod=14\nFixedLot=0.01\nRemovedThing=7\n"

        result = build_mt5_set_compat(package, baseline)

        self.assertEqual(
            result["refusal_rows"],
            [{"parameter": "RemovedThing", "disposition": "REFUSE", "reason": "UNKNOWN_OR_REMOVED_BASELINE_KEY"}],
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
