import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_os import setfile
from _triage.factory_os.evidence import EvidenceSource, ToolFailure
from _triage.factory_vnext import boss17_first_green as first_green
from _triage.factory_vnext.boss17_first_green import (
    Boss17FirstGreenError,
    PILOT_RELATIVE_PATH,
    SOURCE_COMMIT,
    FROZEN_INPUT_PATHS,
    _frozen_bytes,
    _assert_locked_values,
    _baseline_coverage,
    _h01_bindings,
    _jsonl,
    _parameter_surface,
    _registry_rows,
    build_boss17_first_green,
    write_boss17_first_green,
)
from _triage.factory_vnext.variant_generator import validate_variant_build_package


def frozen_jsonl(relative_path):
    return _jsonl(ROOT / relative_path, raw=_frozen_bytes(ROOT, relative_path))


def frozen_baseline():
    return _frozen_bytes(ROOT, "ea_template/sets/Boss17_Wave5_XAU_990301_M2M3_full.set").decode("utf-8-sig")


class Boss17FirstGreenTests(unittest.TestCase):
    def test_real_inputs_build_frozen_identity_bound_package(self):
        build = build_boss17_first_green(str(ROOT))
        self.assertEqual(build["all_binding_count"], 147)
        self.assertEqual(build["projection_binding_count"], 31)
        self.assertEqual(build["physical_baseline_key_count"], 159)
        self.assertEqual(build["projected_not_in_baseline"], [])
        projection = build["variant_build_package"]["ParameterProjection"]
        self.assertEqual({row["role"] for row in projection}, {"LOCKED"})
        self.assertEqual({row["projection"] for row in projection}, {"SNAPSHOT_ONLY"})
        coverage = build["baseline_coverage"]
        self.assertEqual(sum(row["disposition"] == "PROJECT" for row in coverage), 31)
        self.assertEqual(sum(row["disposition"] == "PRESERVE_SNAPSHOT" for row in coverage), 128)
        compat_pids = set(range(73000, 73012))
        compat = [row for row in coverage if row["parameter_pid"] in compat_pids]
        self.assertEqual(len(compat), 12)
        self.assertTrue(all(row["disposition"] == "PRESERVE_SNAPSHOT" for row in compat))
        validate_variant_build_package(build["variant_build_package"])
        self.assertEqual(build["mt5_set_compat_manifest"]["refusal_rows"], [])

    def test_proposed_set_preserves_physical_key_order(self):
        build = build_boss17_first_green(str(ROOT))
        baseline = frozen_baseline()
        baseline_lines = setfile.parse_set(baseline)[0]
        proposed_lines = setfile.parse_set(build["proposed_set"])[0]
        self.assertEqual([x.name for x in proposed_lines], [x.name for x in baseline_lines])
        self.assertEqual([x.value for x in proposed_lines], [x.value for x in baseline_lines])
        for line in proposed_lines:
            if line.optimize_tail is not None:
                self.assertTrue(line.optimize_tail.endswith("N"))

    def test_locked_value_drift_refuses(self):
        bindings = _h01_bindings(frozen_jsonl("factory/parameter_bindings.jsonl"))
        baseline = frozen_baseline()
        mutated = baseline.replace("ExitMode=23", "ExitMode=22", 1)
        with self.assertRaisesRegex(Boss17FirstGreenError, "frozen LOCKED values differ"):
            _assert_locked_values(ROOT, mutated, bindings)

    def test_frozen_revision_refuses_tunable_projection(self):
        bindings = _h01_bindings(frozen_jsonl("factory/parameter_bindings.jsonl"))
        mutated = [dict(row) for row in bindings]
        first_locked = next(row for row in mutated if row["role"] == "LOCKED")
        first_locked["role"] = "TUNABLE"
        metadata = frozen_jsonl("factory/parameter_display_metadata.jsonl")
        variant = build_boss17_first_green(str(ROOT))["strategy_variant"]
        with self.assertRaisesRegex(Boss17FirstGreenError, "must not expose TUNABLE"):
            _parameter_surface(variant, mutated, metadata)

    def test_writes_byte_identical_artifacts(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            write_boss17_first_green(str(ROOT), first)
            write_boss17_first_green(str(ROOT), second)
            one = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(first).iterdir()}
            two = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in pathlib.Path(second).iterdir()}
            self.assertEqual(one, two)

    def test_incomplete_baseline_coverage_refuses(self):
        registry = [{"name": "Only", "parameter_pid": "1"}]
        with self.assertRaisesRegex(Boss17FirstGreenError, "159 unique"):
            _baseline_coverage("Only=1\n", registry, [])


    def test_all_nine_artifacts_match_accepted_historical_bytes(self):
        with tempfile.TemporaryDirectory() as output:
            build = write_boss17_first_green(str(ROOT), output)
            generated = pathlib.Path(output)
            index = json.loads((generated / "artifact_index.json").read_text(encoding="utf-8"))
            self.assertEqual(len(index["files"]), 9)
            self.assertEqual(build["variant_build_package"]["PackageID"], "VPKG-e1c33fa67926cf7292282065")
            for name, ref in index["files"].items():
                with self.subTest(artifact=name):
                    raw = (generated / name).read_bytes()
                    self.assertEqual(raw, (ROOT / PILOT_RELATIVE_PATH / name).read_bytes())
                    self.assertEqual(hashlib.sha256(raw).hexdigest(), ref["sha256"])

    def test_input_refs_hash_the_pinned_bytes_including_inputs_mqh(self):
        with tempfile.TemporaryDirectory() as output:
            write_boss17_first_green(str(ROOT), output)
            index = json.loads((pathlib.Path(output) / "artifact_index.json").read_text(encoding="utf-8"))
            refs = {ref["path"]: ref for ref in index["source_refs"]}
            self.assertEqual({p for p, ref in refs.items() if "source_commit" in ref}, set(FROZEN_INPUT_PATHS))
            for relative_path in FROZEN_INPUT_PATHS:
                with self.subTest(path=relative_path):
                    expected = subprocess.check_output(
                        ["git", "-C", str(ROOT), "cat-file", "blob", SOURCE_COMMIT + ":" + relative_path]
                    )
                    self.assertEqual(refs[relative_path]["source_commit"], SOURCE_COMMIT)
                    self.assertEqual(refs[relative_path]["sha256"], hashlib.sha256(expected).hexdigest())
                    self.assertEqual(refs[relative_path]["bytes"], len(expected))

    def test_current_input_tampering_cannot_affect_frozen_outputs(self):
        # Poison the filesystem read boundary without modifying the real checkout.
        original_bytes = pathlib.Path.read_bytes
        original_text = pathlib.Path.read_text
        blocked = {(ROOT / relative_path).resolve() for relative_path in FROZEN_INPUT_PATHS}

        def poisoned_bytes(path):
            if path.resolve() in blocked:
                return b"adversarial current worktree input"
            return original_bytes(path)

        def poisoned_text(path, *args, **kwargs):
            if path.resolve() in blocked:
                return "adversarial current worktree input"
            return original_text(path, *args, **kwargs)

        with tempfile.TemporaryDirectory() as output:
            with mock.patch.object(pathlib.Path, "read_bytes", poisoned_bytes), mock.patch.object(
                pathlib.Path, "read_text", poisoned_text
            ):
                build = write_boss17_first_green(str(ROOT), output)
            index = json.loads((pathlib.Path(output) / "artifact_index.json").read_text(encoding="utf-8"))
            self.assertEqual(build["all_binding_count"], 147)
            for name in index["files"]:
                self.assertEqual((pathlib.Path(output) / name).read_bytes(), (ROOT / PILOT_RELATIVE_PATH / name).read_bytes())

    def test_absent_source_commit_refuses_without_worktree_fallback(self):
        with mock.patch.object(first_green, "SOURCE_COMMIT", "0" * 40):
            with self.assertRaisesRegex(Boss17FirstGreenError, "required frozen source is unavailable"):
                build_boss17_first_green(str(ROOT))

    def test_each_missing_required_pin_refuses_before_writing_artifacts(self):
        resolve_pin = EvidenceSource.resolve_pin
        for missing_path in FROZEN_INPUT_PATHS:
            with self.subTest(path=missing_path), tempfile.TemporaryDirectory() as output:
                def missing(source, commit, relative_path, why):
                    return None if relative_path == missing_path else resolve_pin(source, commit, relative_path, why)

                with mock.patch.object(EvidenceSource, "resolve_pin", missing):
                    with self.assertRaisesRegex(Boss17FirstGreenError, "required frozen source is unavailable"):
                        write_boss17_first_green(str(ROOT), output)
                self.assertEqual(list(pathlib.Path(output).iterdir()), [])

    def test_unreadable_blob_refuses_without_worktree_fallback(self):
        with mock.patch.object(EvidenceSource, "read_blob", side_effect=ToolFailure("unreadable pinned blob")):
            with self.assertRaisesRegex(Boss17FirstGreenError, "cannot read frozen source.*unreadable pinned blob"):
                build_boss17_first_green(str(ROOT))

    def test_current_vintage_refuses_instead_of_relaxing_historical_counts(self):
        current = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
        with mock.patch.object(first_green, "SOURCE_COMMIT", current):
            with self.assertRaisesRegex(Boss17FirstGreenError, "expected 147 B17-H01 bindings, got 161"):
                build_boss17_first_green(str(ROOT))

    def test_truncated_and_malformed_frozen_bindings_refuse(self):
        relative_path = "factory/parameter_bindings.jsonl"
        rows = frozen_jsonl(relative_path)
        removed = next(row for row in rows if row.get("hypothesis_revision") == "B17-H01-r1"
                       and row.get("build_tag") == "LAB_ENTRY_17")
        truncated = "\n".join(json.dumps(row) for row in rows if row is not removed).encode("utf-8")
        for raw, message in (
            (truncated, "expected 147 B17-H01 bindings, got 146"),
            (b'{"hypothesis_revision":', "parameter_bindings.jsonl:1 is malformed JSON"),
        ):
            with self.subTest(message=message):
                def corrupted(root, path):
                    return raw if path == relative_path else _frozen_bytes(root, path)

                with mock.patch.object(first_green, "_frozen_bytes", corrupted):
                    with self.assertRaisesRegex(Boss17FirstGreenError, message):
                        build_boss17_first_green(str(ROOT))


if __name__ == "__main__":
    unittest.main(verbosity=2)
