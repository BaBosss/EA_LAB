from __future__ import annotations

import copy
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.xx00_reference_v2 import (
    XX00ReferenceV2Error,
    make_xx00_reference_v2,
    serialize_xx00_reference_v2,
    validate_xx00_reference_v2,
)


class XX00ReferenceV2PositiveTests(unittest.TestCase):
    def test_none_family_is_deterministic_and_closed(self):
        left = make_xx00_reference_v2(
            family_id="B11", logical_variant_id="B11-00", atr_period=14
        )
        right = make_xx00_reference_v2(
            family_id="B11", logical_variant_id="B11-00", atr_period=14
        )
        self.assertEqual(left, right)
        self.assertEqual(left["ATR"], {"timeframe": "PERIOD_CURRENT", "period": 14})
        self.assertEqual(left["NativeSemantics"]["mechanics"], [])
        self.assertFalse(left["ExecutableBinding"])
        self.assertFalse(left["RuntimeBinding"])

    def test_owner_native_families_match_ratified_map(self):
        b14 = make_xx00_reference_v2(
            family_id="B14", logical_variant_id="B14-00", atr_period=14
        )
        b16 = make_xx00_reference_v2(
            family_id="B16", logical_variant_id="B16-00", atr_period=21
        )
        b17 = make_xx00_reference_v2(
            family_id="B17", logical_variant_id="B17-00", atr_period=10
        )
        self.assertEqual(
            b14["NativeSemantics"]["mechanics"],
            ["GRID_STACK", "LOG_POWER_PROGRESSION", "BASKET_TARGET_OWNERSHIP"],
        )
        self.assertEqual(b14["NativeSemantics"]["exit_concept"], "BASKET_TARGET_OWNERSHIP")
        self.assertIn("ADVERSE_ATR_GRID", b16["NativeSemantics"]["mechanics"])
        self.assertEqual(b16["NativeSemantics"]["exit_concept"], "OWNED_BASKET_OVERLAP_EXITS")
        self.assertEqual(
            b17["NativeSemantics"]["mechanics"],
            ["WAVE1_STRUCTURAL_INVALIDATION_SL", "SINGLE_WHEN_STRUCTURAL"],
        )
        self.assertIsNone(b17["NativeSemantics"]["exit_concept"])

    def test_serialization_is_canonical_and_repeatable(self):
        record = make_xx00_reference_v2(
            family_id="B18", logical_variant_id="B18-00", atr_period=14
        )
        self.assertEqual(serialize_xx00_reference_v2(record), serialize_xx00_reference_v2(record))
        self.assertTrue(serialize_xx00_reference_v2(record).endswith("\n"))


class XX00ReferenceV2NegativeTests(unittest.TestCase):
    def _valid(self):
        return make_xx00_reference_v2(
            family_id="B14", logical_variant_id="B14-00", atr_period=14
        )

    def test_family_and_logical_id_fail_closed(self):
        with self.assertRaises(XX00ReferenceV2Error):
            make_xx00_reference_v2(
                family_id="B19", logical_variant_id="B19-00", atr_period=14
            )
        with self.assertRaisesRegex(XX00ReferenceV2Error, "LogicalVariantID"):
            make_xx00_reference_v2(
                family_id="B14", logical_variant_id="B14-H01", atr_period=14
            )

    def test_atr_period_requires_positive_non_bool_integer(self):
        for value in (None, True, False, 0, -1, 14.0, "14"):
            with self.subTest(value=value):
                with self.assertRaisesRegex(XX00ReferenceV2Error, "positive integer"):
                    make_xx00_reference_v2(
                        family_id="B14", logical_variant_id="B14-00", atr_period=value
                    )

    def test_atr_timeframe_and_source_are_structurally_closed(self):
        valid = self._valid()
        for bad in ("H1", "DEFAULTATR", "RUNTIMEATR", "OVERRIDE"):
            mutated = copy.deepcopy(valid)
            mutated["ATR"]["timeframe"] = bad
            with self.subTest(bad=bad):
                with self.assertRaisesRegex(XX00ReferenceV2Error, "PERIOD_CURRENT"):
                    validate_xx00_reference_v2(mutated)

        mutated = copy.deepcopy(valid)
        mutated["ATR"]["source"] = "DEFAULTATR"
        with self.assertRaisesRegex(XX00ReferenceV2Error, "ATR fields"):
            validate_xx00_reference_v2(mutated)

        for key, value in (
            ("ATRSource", "DEFAULTATR"),
            ("RuntimeATR", "RUNTIMEATR"),
            ("Override", "OVERRIDE"),
        ):
            mutated = copy.deepcopy(valid)
            mutated[key] = value
            with self.subTest(key=key):
                with self.assertRaisesRegex(XX00ReferenceV2Error, "fields do not match schema"):
                    validate_xx00_reference_v2(mutated)

    def test_caller_cannot_override_native_or_exit_semantics(self):
        valid = self._valid()
        mutated = copy.deepcopy(valid)
        mutated["NativeSemantics"]["mechanics"] = ["NONE"]
        with self.assertRaisesRegex(XX00ReferenceV2Error, "owner-ratified family map"):
            validate_xx00_reference_v2(mutated)

        mutated = copy.deepcopy(valid)
        mutated["NativeSemantics"]["exit_concept"] = "ATR_BASED"
        with self.assertRaisesRegex(XX00ReferenceV2Error, "owner-ratified family map"):
            validate_xx00_reference_v2(mutated)

    def test_runtime_and_executable_authority_fail_closed(self):
        for key in ("ExecutableBinding", "RuntimeBinding"):
            mutated = copy.deepcopy(self._valid())
            mutated[key] = True
            with self.subTest(key=key):
                with self.assertRaises(XX00ReferenceV2Error):
                    validate_xx00_reference_v2(mutated)

    def test_h01_config_and_unknown_fields_fail_closed(self):
        for key, value in (
            ("LegacyVariantID", "B14-H01"),
            ("HomeContractID", "HOME-bad"),
            ("PackageID", "VPKG-bad"),
            ("ConfigFingerprint", "cfgfp-v1:bad"),
            ("RuntimeDefault", True),
        ):
            mutated = copy.deepcopy(self._valid())
            mutated[key] = value
            with self.subTest(key=key):
                with self.assertRaisesRegex(XX00ReferenceV2Error, "fields do not match schema"):
                    validate_xx00_reference_v2(mutated)

    def test_baseline_and_deterministic_id_cannot_be_mutated(self):
        mutated = copy.deepcopy(self._valid())
        mutated["GenericBaseline"]["stack_confirm"] = "SIGNAL_VALID"
        with self.assertRaisesRegex(XX00ReferenceV2Error, "DISTANCE"):
            validate_xx00_reference_v2(mutated)

        mutated = copy.deepcopy(self._valid())
        mutated["GenericBaseline"]["basket_protection"]["pct_current_balance"] = 5.0
        with self.assertRaisesRegex(XX00ReferenceV2Error, "10.0"):
            validate_xx00_reference_v2(mutated)

        mutated = copy.deepcopy(self._valid())
        mutated["FamilyReferenceID"] = "XX00REF-deadbeef"
        with self.assertRaisesRegex(XX00ReferenceV2Error, "FamilyReferenceID"):
            validate_xx00_reference_v2(mutated)


if __name__ == "__main__":
    unittest.main()
