from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.range_generator import (
    RangeGeneratorError,
    plan_dimension_set,
    plan_parameter_range,
)


class FactoryVNextRangeGeneratorTests(unittest.TestCase):
    def test_unknown_semantics_blocked(self):
        spec = {
            "name": "MysteryParam",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "unknown_semantics",
            "domain": {"kind": "numeric", "min": 1, "max": 10},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertEqual(result["status"], "SEMANTICS_REQUIRED:semantics required")
        self.assertEqual(result["candidates"], [])

    def test_non_tunable_refused(self):
        spec = {
            "name": "LockedParam",
            "role": "LOCKED",
            "surface": "HIDDEN",
            "semantic_type": "threshold",
            "domain": {"kind": "numeric", "min": 1, "max": 10},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertEqual(result["status"], "REFUSED:non-tunable refused")
        self.assertEqual(result["candidates"], [])

    def test_reordered_input_is_deterministic(self):
        spec_a = {
            "name": "StepATRmult",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "normalized_multiplier",
            "domain": {"kind": "numeric", "min": 0.5, "max": 3.0},
            "unit": "ATR-multiple",
            "historical_observed": True,
        }
        spec_b = {
            "historical_observed": True,
            "unit": "ATR-multiple",
            "domain": {"max": 3.0, "min": 0.5, "kind": "numeric"},
            "semantic_type": "normalized_multiplier",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "name": "StepATRmult",
        }
        self.assertEqual(plan_parameter_range(spec_a, "COARSE"), plan_parameter_range(spec_b, "COARSE"))

    def test_coarse_points_are_sparse(self):
        spec = {
            "name": "AtrPeriod",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "period_lookback",
            "domain": {"kind": "integer", "min": 7, "max": 28},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertEqual(result["status"], "COARSE")
        self.assertGreaterEqual(len(result["candidates"]), 3)
        self.assertLessEqual(len(result["candidates"]), 7)
        self.assertEqual(result["candidates"], sorted(result["candidates"]))

    def test_integer_and_enum_handling(self):
        int_spec = {
            "name": "MaxLevels",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "count_depth",
            "domain": {"kind": "integer", "min": 1, "max": 5},
        }
        enum_spec = {
            "name": "ExitMode",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "enum_mechanism",
            "domain": {"kind": "enum", "allowed": ["A", "B", "C"]},
        }
        int_result = plan_parameter_range(int_spec, "COARSE")
        enum_result = plan_parameter_range(enum_spec, "COARSE")
        self.assertTrue(all(isinstance(item, int) for item in int_result["candidates"]))
        self.assertEqual(enum_result["candidates"], ["A", "B", "C"])

    def test_boundary_clipping_without_expansion(self):
        spec = {
            "name": "StepPoints",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "distance_spacing",
            "domain": {"kind": "numeric", "min": 0.5, "max": 3.0},
        }
        result = plan_parameter_range(spec, "COARSE", safe_ceiling=1.0)
        self.assertEqual(result["status"], "SAFETY_LIMITED")
        self.assertTrue(all(candidate <= 1.0 for candidate in result["candidates"]))

    def test_safety_ceiling_stop(self):
        spec = {
            "name": "TriggerDDPct",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "threshold",
            "domain": {"kind": "numeric", "min": 5.0, "max": 20.0},
        }
        result = plan_parameter_range(spec, "SENSITIVITY", safe_ceiling=0.1)
        self.assertEqual(result["status"], "STOP_AUTO_EXPANSION")
        self.assertEqual(result["candidates"], [])

    def test_more_than_four_active_dimensions_refused(self):
        dims = [
            {"name": "A", "role": "TUNABLE", "surface": "RESEARCH", "semantic_type": "threshold", "domain": {"kind": "numeric", "min": 1, "max": 2}},
            {"name": "B", "role": "TUNABLE", "semantic_type": "threshold", "domain": {"kind": "numeric", "min": 1, "max": 2}, "surface": "RESEARCH"},
            {"name": "C", "role": "TUNABLE", "semantic_type": "threshold", "domain": {"kind": "numeric", "min": 1, "max": 2}, "surface": "RESEARCH"},
            {"name": "D", "role": "TUNABLE", "semantic_type": "threshold", "domain": {"kind": "numeric", "min": 1, "max": 2}, "surface": "RESEARCH"},
            {"name": "E", "role": "TUNABLE", "semantic_type": "threshold", "domain": {"kind": "numeric", "min": 1, "max": 2}, "surface": "RESEARCH"},
        ]
        result = plan_dimension_set(dims, stage="COARSE")
        self.assertEqual(result["status"], "REFUSED")

    def test_coupled_group_kept_explicit(self):
        dims = [
            {"name": "StepUseATR", "role": "TUNABLE", "surface": "RESEARCH", "semantic_type": "boolean_policy", "domain": {"kind": "enum", "allowed": [0, 1]}, "coupling_group": "step-family"},
            {"name": "StepATRmult", "role": "TUNABLE", "surface": "RESEARCH", "semantic_type": "normalized_multiplier", "domain": {"kind": "numeric", "min": 0.5, "max": 3.0}, "coupling_group": "step-family"},
            {"name": "StepPoints", "role": "INACTIVE", "surface": "RESEARCH", "semantic_type": "distance_spacing", "domain": {"kind": "numeric", "min": 1, "max": 10}, "coupling_group": "step-family"},
        ]
        result = plan_dimension_set(dims, stage="REGION_SELECT")
        self.assertEqual(result["coupling_groups"], [["step-family"]])
        self.assertEqual(result["active_dimensions"], ["StepUseATR", "StepATRmult"])

    def test_tunable_operator_refuses(self):
        spec = {
            "name": "StepATRmult",
            "role": "TUNABLE",
            "surface": "OPERATOR",
            "semantic_type": "normalized_multiplier",
            "domain": {"kind": "numeric", "min": 0.5, "max": 3.0},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertEqual(result["status"], "REFUSED:non-research refused")
        self.assertEqual(result["candidates"], [])

    def test_tunable_hidden_refuses(self):
        spec = {
            "name": "StepATRmult",
            "role": "TUNABLE",
            "surface": "HIDDEN",
            "semantic_type": "normalized_multiplier",
            "domain": {"kind": "numeric", "min": 0.5, "max": 3.0},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertEqual(result["status"], "REFUSED:non-research refused")
        self.assertEqual(result["candidates"], [])

    def test_tunable_research_still_plans(self):
        spec = {
            "name": "StepATRmult",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "normalized_multiplier",
            "domain": {"kind": "numeric", "min": 0.5, "max": 3.0},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertEqual(result["status"], "COARSE")
        self.assertTrue(result["candidates"])

    def test_no_universal_atr_constant_or_hidden_widening(self):
        spec = {
            "name": "StepATRmult",
            "role": "TUNABLE",
            "surface": "RESEARCH",
            "semantic_type": "normalized_multiplier",
            "domain": {"kind": "numeric", "min": 2.0, "max": 8.0},
        }
        result = plan_parameter_range(spec, "COARSE")
        self.assertNotIn(0.25, result["candidates"])
        self.assertEqual(min(result["candidates"]), 2.0)
        self.assertEqual(max(result["candidates"]), 8.0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
