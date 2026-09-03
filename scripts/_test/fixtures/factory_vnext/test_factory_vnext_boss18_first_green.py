import hashlib
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_os import setfile
from _triage.factory_vnext.boss18_first_green import (
    Boss18FirstGreenError,
    PILOT_RELATIVE_PATH,
    _assert_locked_values,
    _baseline_coverage,
    _h01_bindings,
    _jsonl,
    _parameter_surface,
    _registry_rows,
    build_boss18_first_green,
    write_boss18_first_green,
)
from _triage.factory_vnext.variant_generator import validate_variant_build_package


class Boss18FirstGreenTests(unittest.TestCase):
    def test_real_inputs_build_frozen_identity_bound_package(self):
        build = build_boss18_first_green(str(ROOT))
        self.assertEqual(build["all_binding_count"], 147)
        self.assertEqual(build["projection_binding_count"], 35)
        self.assertEqual(build["physical_baseline_key_count"], 159)
        self.assertEqual(build["projected_not_in_baseline"], [])
        projection = build["variant_build_package"]["ParameterProjection"]
        self.assertEqual({row["role"] for row in projection}, {"LOCKED"})
        self.assertEqual({row["projection"] for row in projection}, {"SNAPSHOT_ONLY"})
        coverage = build["baseline_coverage"]
        self.assertEqual(sum(row["disposition"] == "PROJECT" for row in coverage), 35)
        self.assertEqual(sum(row["disposition"] == "PRESERVE_SNAPSHOT" for row in coverage), 124)
        compat_pids = set(range(73000, 73012))
        compat = [row for row in coverage if row["parameter_pid"] in compat_pids]
        self.assertEqual(len(compat), 12)
        self.assertTrue(all(row["disposition"] == "PRESERVE_SNAPSHOT" for row in compat))
        validate_variant_build_package(build["variant_build_package"])
        self.assertEqual(build["mt5_set_compat_manifest"]["refusal_rows"], [])

    def test_proposed_set_preserves_physical_key_order(self):
        build = build_boss18_first_green(str(ROOT))
        baseline = (ROOT / "ea_template/sets/regression/Boss_18_JumStoch_defaults.set").read_text(encoding="utf-8-sig")
        baseline_lines = setfile.parse_set(baseline)[0]
        proposed_lines = setfile.parse_set(build["proposed_set"])[0]
        self.assertEqual([x.name for x in proposed_lines], [x.name for x in baseline_lines])
        self.assertEqual([x.value for x in proposed_lines], [x.value for x in baseline_lines])
        for line in proposed_lines:
            if line.optimize_tail is not None:
                self.assertTrue(line.optimize_tail.endswith("N"))

    def test_locked_value_drift_refuses(self):
        bindings = _h01_bindings(_jsonl(ROOT / "factory/parameter_bindings.jsonl"))
        baseline = (ROOT / "ea_template/sets/regression/Boss_18_JumStoch_defaults.set").read_text(encoding="utf-8-sig")
        mutated = baseline.replace("_18_DirMode=1", "_18_DirMode=2", 1)
        with self.assertRaisesRegex(Boss18FirstGreenError, "frozen LOCKED values differ"):
            _assert_locked_values(ROOT, mutated, bindings)

    def test_frozen_revision_refuses_tunable_projection(self):
        bindings = _h01_bindings(_jsonl(ROOT / "factory/parameter_bindings.jsonl"))
        mutated = [dict(row) for row in bindings]
        first_locked = next(row for row in mutated if row["role"] == "LOCKED")
        first_locked["role"] = "TUNABLE"
        metadata = _jsonl(ROOT / "factory/parameter_display_metadata.jsonl")
        variant = build_boss18_first_green(str(ROOT))["strategy_variant"]
        with self.assertRaisesRegex(Boss18FirstGreenError, "must not expose TUNABLE"):
            _parameter_surface(variant, mutated, metadata)

    def test_writes_byte_identical_artifacts(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            write_boss18_first_green(str(ROOT), first)
            write_boss18_first_green(str(ROOT), second)
            one = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(first).iterdir()}
            two = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(second).iterdir()}
            self.assertEqual(one, two)

    def test_incomplete_baseline_coverage_refuses(self):
        registry = [{"name": "Only", "parameter_pid": "1"}]
        with self.assertRaisesRegex(Boss18FirstGreenError, "159 unique"):
            _baseline_coverage("Only=1\n", registry, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
