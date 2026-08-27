import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.boss14_first_green import (
    Boss14FirstGreenError,
    PILOT_RELATIVE_PATH,
    _baseline_coverage,
    _h01_bindings,
    _jsonl,
    _registry_rows,
    build_boss14_first_green,
    write_boss14_first_green,
)
from _triage.factory_os import setfile
from _triage.factory_vnext.variant_generator import validate_variant_build_package


class Boss14FirstGreenTests(unittest.TestCase):
    def test_real_inputs_build_expected_identity_bound_package(self):
        build = build_boss14_first_green(str(ROOT))
        self.assertEqual(build["all_binding_count"], 142)
        self.assertEqual(build["projection_binding_count"], 31)
        self.assertEqual(build["physical_baseline_key_count"], 116)
        self.assertEqual(len(build["baseline_coverage"]), 116)
        self.assertEqual(
            [(row["parameter_pid"], row["parameter"]) for row in build["projected_not_in_baseline"]],
            [(72000, "UseMiddlePathVeto")],
        )
        self.assertEqual(build["variant_build_package"]["authority"], "NON_AUTHORITATIVE_SIDECAR")
        validate_variant_build_package(build["variant_build_package"])
        self.assertEqual(build["mt5_set_compat_manifest"]["refusal_rows"], [])
        baseline = (ROOT / "factory/runs/pilot/effective_B14_H01_r1_baseline.set").read_text(encoding="utf-8")
        proposed_lines = setfile.parse_set(build["proposed_set"])[0]
        baseline_lines = setfile.parse_set(baseline)[0]
        self.assertEqual([line.name for line in proposed_lines], [line.name for line in baseline_lines])
        for original, proposed in zip(baseline_lines, proposed_lines):
            self.assertEqual(proposed.value, original.value)
            allowed_tail = original.optimize_tail
            if allowed_tail and allowed_tail.endswith("Y"):
                allowed_tail = allowed_tail[:-1] + "N"
            self.assertIn(proposed.optimize_tail, (original.optimize_tail, allowed_tail))

    def test_writes_byte_identical_artifacts_on_repeated_runs(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            write_boss14_first_green(str(ROOT), first)
            write_boss14_first_green(str(ROOT), second)
            one = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in pathlib.Path(first).iterdir()}
            two = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in pathlib.Path(second).iterdir()}
            self.assertEqual(one, two)
            index = json.loads((pathlib.Path(first) / "artifact_index.json").read_text(encoding="utf-8"))
            self.assertEqual(set(index["files"]), set(one) - {"artifact_index.json"})
            for name, entry in index["files"].items():
                self.assertEqual(entry["sha256"], one[name])
            checked_in = ROOT / PILOT_RELATIVE_PATH
            self.assertEqual(
                {path.name: path.read_bytes() for path in pathlib.Path(first).iterdir()},
                {path.name: path.read_bytes() for path in checked_in.iterdir()},
            )

    def test_ambiguous_registry_mapping_refuses(self):
        baseline = (ROOT / "factory/runs/pilot/effective_B14_H01_r1_baseline.set").read_text(encoding="utf-8")
        registry = _registry_rows(ROOT / "docs/PARAM_REGISTRY.csv")
        registry.extend([
            {"name": "ExitMode [LAB_ENTRY_14]", "parameter_pid": "999001"},
            {"name": "ExitMode [LAB_ENTRY_14]", "parameter_pid": "999002"},
        ])
        bindings = _h01_bindings(_jsonl(ROOT / "factory/parameter_bindings.jsonl"))
        with self.assertRaisesRegex(Boss14FirstGreenError, "not unique"):
            _baseline_coverage(baseline, registry, bindings)

    def test_registry_pid_binding_name_mismatch_refuses(self):
        baseline = (ROOT / "factory/runs/pilot/effective_B14_H01_r1_baseline.set").read_text(encoding="utf-8")
        registry = _registry_rows(ROOT / "docs/PARAM_REGISTRY.csv")
        for row in registry:
            if row["name"] == "ExitMode":
                row["parameter_pid"] = "72000"
                break
        bindings = _h01_bindings(_jsonl(ROOT / "factory/parameter_bindings.jsonl"))
        with self.assertRaisesRegex(Boss14FirstGreenError, "binding name does not match"):
            _baseline_coverage(baseline, registry, bindings)

    def test_incomplete_baseline_coverage_refuses(self):
        registry = [{"name": "Only", "parameter_pid": "1"}]
        with self.assertRaisesRegex(Boss14FirstGreenError, "116 unique"):
            _baseline_coverage("Only=1\n", registry, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
