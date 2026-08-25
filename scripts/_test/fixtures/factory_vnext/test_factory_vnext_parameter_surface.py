from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.architecture import make_master_mold, make_strategy_family, make_strategy_variant
from _triage.factory_vnext.parameter_surface import (
    ParameterSurfaceError,
    make_variant_parameter_surface,
    surface_machine_rows,
)


class FactoryVNextParameterSurfaceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.master = make_master_mold("MOLD1", "1", ["CAP_ENTRY", "CAP_RECOVERY"])
        self.family = make_strategy_family(self.master, "B14", "Boss14", ["CAP_ENTRY"], "14")
        self.variant = make_strategy_variant(self.family, "B14-V01", "1.0", [], [])

    def _binding_rows(self):
        return [
            {
                "entity": "ParameterBinding",
                "hypothesis_revision": "B14-H01-r1",
                "build_tag": "LAB_ENTRY_14",
                "parameter_pid": 40000,
                "parameter": "FirstLotMode",
                "role": "LOCKED",
                "surface": "HIDDEN",
                "optimize_stage": "FREEZE",
                "safe_range": None,
                "locked_value": "FIRSTLOT_FIXED",
            },
            {
                "entity": "ParameterBinding",
                "hypothesis_revision": "B14-H01-r1",
                "build_tag": "LAB_ENTRY_14",
                "parameter_pid": 50210,
                "parameter": "_9_StepUseATR",
                "role": "TUNABLE",
                "surface": "OPERATOR",
                "optimize_stage": "SIGNAL",
                "safe_range": None,
                "locked_value": None,
            },
        ]

    def _display_rows(self):
        return [
            {
                "display_label": "First Lot Mode",
                "parameter": "FirstLotMode",
                "parameter_pid": 40000,
                "portability": "PORTABLE",
                "relation_hint": "with P40031",
                "relations": [],
                "unit_true": "enum (41/42/43)",
            },
            {
                "display_label": "Step Use ATR",
                "parameter": "_9_StepUseATR",
                "parameter_pid": 50210,
                "portability": "PORTABLE",
                "relation_hint": "with P50211",
                "relations": [],
                "unit_true": "bool",
            },
        ]

    def test_reorder_invariance_and_display_projection_only(self):
        surface_a = make_variant_parameter_surface(
            self.variant, self._binding_rows(), self._display_rows(), "B14-H01-r1", "LAB_ENTRY_14"
        )
        surface_b = make_variant_parameter_surface(
            self.variant,
            list(reversed(self._binding_rows())),
            list(reversed(self._display_rows())),
            "B14-H01-r1",
            "LAB_ENTRY_14",
        )
        self.assertEqual(surface_a["SurfaceID"], surface_b["SurfaceID"])
        self.assertEqual(surface_a["SurfaceRows"][0]["display_label"], "First Lot Mode")
        self.assertEqual(surface_a["SurfaceRows"][1]["display_label"], "Step Use ATR")

    def test_display_label_change_does_not_change_surface_id(self):
        surface_a = make_variant_parameter_surface(
            self.variant, self._binding_rows(), self._display_rows(), "B14-H01-r1", "LAB_ENTRY_14"
        )
        altered = self._display_rows()
        altered[0] = {**altered[0], "display_label": "First Lot Mode X"}
        surface_b = make_variant_parameter_surface(
            self.variant, self._binding_rows(), altered, "B14-H01-r1", "LAB_ENTRY_14"
        )
        self.assertEqual(surface_a["SurfaceID"], surface_b["SurfaceID"])
        self.assertNotEqual(surface_a["SurfaceRows"][0]["display_label"], surface_b["SurfaceRows"][0]["display_label"])

    def test_duplicate_parameter_pid_is_refused(self):
        bad = self._binding_rows() + [dict(self._binding_rows()[0])]
        with self.assertRaisesRegex(ParameterSurfaceError, "duplicate binding parameter_pid"):
            make_variant_parameter_surface(self.variant, bad, self._display_rows(), "B14-H01-r1", "LAB_ENTRY_14")

    def test_pid_name_mismatch_is_refused(self):
        bad_display = self._display_rows()
        bad_display[0] = {**bad_display[0], "parameter": "FirstLotModeX"}
        with self.assertRaisesRegex(ParameterSurfaceError, "parameter name mismatch"):
            make_variant_parameter_surface(self.variant, self._binding_rows(), bad_display, "B14-H01-r1", "LAB_ENTRY_14")

    def test_wrong_hypothesis_or_build_cannot_borrow_rows(self):
        with self.assertRaisesRegex(ParameterSurfaceError, "no binding rows matched"):
            make_variant_parameter_surface(self.variant, self._binding_rows(), self._display_rows(), "B14-H99-r1", "LAB_ENTRY_14")
        with self.assertRaisesRegex(ParameterSurfaceError, "no binding rows matched"):
            make_variant_parameter_surface(self.variant, self._binding_rows(), self._display_rows(), "B14-H01-r1", "LAB_ENTRY_99")

    def test_same_parameter_can_change_role_across_hypotheses(self):
        locked = make_variant_parameter_surface(
            self.variant, self._binding_rows(), self._display_rows(), "B14-H01-r1", "LAB_ENTRY_14"
        )
        tunable_rows = [
            {**self._binding_rows()[0], "hypothesis_revision": "B14-H02-r1", "role": "TUNABLE", "surface": "OPERATOR"},
            {**self._binding_rows()[1], "hypothesis_revision": "B14-H02-r1"},
        ]
        tunable = make_variant_parameter_surface(
            self.variant, tunable_rows, self._display_rows(), "B14-H02-r1", "LAB_ENTRY_14"
        )
        self.assertEqual(locked["SurfaceRows"][0]["role"], "LOCKED")
        self.assertEqual(tunable["SurfaceRows"][0]["role"], "TUNABLE")

    def test_surface_machine_rows_is_ordered_and_machine_only(self):
        surface = make_variant_parameter_surface(
            self.variant, self._binding_rows(), self._display_rows(), "B14-H01-r1", "LAB_ENTRY_14"
        )
        rows = surface_machine_rows(surface)
        self.assertEqual([row["parameter_pid"] for row in rows], [40000, 50210])
        self.assertNotIn("display_label", rows[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
