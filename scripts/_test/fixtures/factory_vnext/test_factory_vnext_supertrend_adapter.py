from __future__ import annotations

import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.contracts import make_home_contract, make_parameter_set
from _triage.factory_vnext.supertrend_adapter import (
    CONCEPT_ID,
    EXECUTION_TF,
    LOGICAL_SYMBOL,
    PRESET_REL_PATH,
    SOURCE_REL_PATH,
    STRATEGY_VERSION,
    SuperTrendAdapterError,
    load_supertrend_pilot,
    validate_supertrend_pilot,
)

_VALID_PRESET_TEXT = (
    "; fixture preset\n"
    "_00_OptimizeMode=false\n"
    "_01_AtrPeriod=14\n"
    "_01_Mult=2.5\n"
)
_SOURCE_STUB_TEXT = "// stub source for adapter fixture tests\n"


def _write_fixture_repo(base: pathlib.Path, *, preset_text: str, source_text: str = _SOURCE_STUB_TEXT) -> str:
    source_path = base.joinpath(*SOURCE_REL_PATH.split("/"))
    preset_path = base.joinpath(*PRESET_REL_PATH.split("/"))
    source_path.parent.mkdir(parents=True, exist_ok=True)
    preset_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text(source_text, encoding="utf-8")
    preset_path.write_text(preset_text, encoding="utf-8")
    return str(base)


class SuperTrendAdapterRealRepoTests(unittest.TestCase):
    """Exercises the adapter against the real accepted rev05 source/preset in this repo."""

    def test_deterministic_rerun(self):
        first = load_supertrend_pilot(str(ROOT))
        second = load_supertrend_pilot(str(ROOT))
        self.assertEqual(first, second)

    def test_exact_btcusd_h4_home(self):
        record = load_supertrend_pilot(str(ROOT))
        self.assertEqual(record["LogicalSymbol"], "BTCUSD")
        self.assertEqual(record["ExecutionTF"], "H4")
        self.assertEqual(record["ConceptID"], CONCEPT_ID)
        self.assertEqual(record["StrategyVersion"], STRATEGY_VERSION)
        self.assertEqual(record["authority"], "NON_AUTHORITATIVE_SIDECAR")
        self.assertEqual(record["HomeContract"]["LogicalSymbol"], "BTCUSD")
        self.assertEqual(record["HomeContract"]["ExecutionTF"], "H4")

    def test_preset_values_preserved_verbatim_no_new_keys(self):
        record = load_supertrend_pilot(str(ROOT))
        preset_path = ROOT.joinpath(*PRESET_REL_PATH.split("/"))
        expected: dict[str, str] = {}
        for raw_line in preset_path.read_text(encoding="utf-8-sig").splitlines():
            stripped = raw_line.strip()
            if not stripped or stripped.startswith(";"):
                continue
            key, _, value = stripped.partition("=")
            expected[key.strip()] = value.strip()
        actual = record["ParameterSet"]["parameters"]
        self.assertEqual(actual, expected)
        self.assertEqual(set(actual.keys()), set(expected.keys()))

    def test_profile_id_derived_from_existing_preset_identity(self):
        record = load_supertrend_pilot(str(ROOT))
        self.assertEqual(record["ProfileID"], "STF_BTC_H4_rev05_off")
        self.assertEqual(record["ParameterSet"]["ProfileID"], "STF_BTC_H4_rev05_off")

    def test_record_validates(self):
        record = load_supertrend_pilot(str(ROOT))
        validate_supertrend_pilot(record)  # must not raise


class SuperTrendAdapterFixtureTests(unittest.TestCase):
    def test_wrong_symbol_is_refused(self):
        bad_home = make_home_contract(CONCEPT_ID, STRATEGY_VERSION, "XAUUSD", EXECUTION_TF)
        params = make_parameter_set({"_01_AtrPeriod": "14"}, "STF_BTC_H4_rev05_off")
        record = {
            "authority": "NON_AUTHORITATIVE_SIDECAR",
            "ConceptID": bad_home["ConceptID"],
            "StrategyVersion": bad_home["StrategyVersion"],
            "LogicalSymbol": bad_home["LogicalSymbol"],
            "ExecutionTF": bad_home["ExecutionTF"],
            "HomeContract": bad_home,
            "ProfileID": params["ProfileID"],
            "ParameterSet": params,
            "SourceRef": {"path": "x", "sha256": "a" * 64, "bytes": 1, "evidence_label": "MEASURED"},
            "PresetRef": {"path": "y", "sha256": "b" * 64, "bytes": 1, "evidence_label": "MEASURED"},
        }
        with self.assertRaisesRegex(SuperTrendAdapterError, "OUTSIDE_VALIDATED_CONTRACT"):
            validate_supertrend_pilot(record)

    def test_wrong_tf_is_refused(self):
        bad_home = make_home_contract(CONCEPT_ID, STRATEGY_VERSION, LOGICAL_SYMBOL, "H1")
        params = make_parameter_set({"_01_AtrPeriod": "14"}, "STF_BTC_H4_rev05_off")
        record = {
            "authority": "NON_AUTHORITATIVE_SIDECAR",
            "ConceptID": bad_home["ConceptID"],
            "StrategyVersion": bad_home["StrategyVersion"],
            "LogicalSymbol": bad_home["LogicalSymbol"],
            "ExecutionTF": bad_home["ExecutionTF"],
            "HomeContract": bad_home,
            "ProfileID": params["ProfileID"],
            "ParameterSet": params,
            "SourceRef": {"path": "x", "sha256": "a" * 64, "bytes": 1, "evidence_label": "MEASURED"},
            "PresetRef": {"path": "y", "sha256": "b" * 64, "bytes": 1, "evidence_label": "MEASURED"},
        }
        with self.assertRaisesRegex(SuperTrendAdapterError, "OUTSIDE_VALIDATED_CONTRACT"):
            validate_supertrend_pilot(record)

    def test_duplicate_preset_key_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            root = _write_fixture_repo(
                base, preset_text="_00_OptimizeMode=false\n_00_OptimizeMode=true\n"
            )
            with self.assertRaisesRegex(SuperTrendAdapterError, "duplicate preset key"):
                load_supertrend_pilot(root)

    def test_malformed_preset_row_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            root = _write_fixture_repo(
                base, preset_text="_00_OptimizeMode=false\nNOT_A_ROW\n"
            )
            with self.assertRaisesRegex(SuperTrendAdapterError, "malformed set row"):
                load_supertrend_pilot(root)

    def test_empty_preset_snapshot_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            root = _write_fixture_repo(base, preset_text="; only a comment\n\n")
            with self.assertRaisesRegex(SuperTrendAdapterError, "preset snapshot is empty"):
                load_supertrend_pilot(root)

    def test_missing_source_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            preset_path = base.joinpath(*PRESET_REL_PATH.split("/"))
            preset_path.parent.mkdir(parents=True, exist_ok=True)
            preset_path.write_text(_VALID_PRESET_TEXT, encoding="utf-8")
            with self.assertRaisesRegex(SuperTrendAdapterError, "source not found"):
                load_supertrend_pilot(str(base))

    def test_missing_preset_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            source_path = base.joinpath(*SOURCE_REL_PATH.split("/"))
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(_SOURCE_STUB_TEXT, encoding="utf-8")
            with self.assertRaisesRegex(SuperTrendAdapterError, "preset not found"):
                load_supertrend_pilot(str(base))

    def test_source_filename_drift_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            root = _write_fixture_repo(base, preset_text=_VALID_PRESET_TEXT)
            drifted_source = base / "(TRD)_SuperTrendFlip_rev06.mq5"
            drifted_source.write_text(_SOURCE_STUB_TEXT, encoding="utf-8")
            with self.assertRaisesRegex(SuperTrendAdapterError, "source filename drift"):
                load_supertrend_pilot(root, source_path=str(drifted_source))

    def test_preset_filename_drift_is_refused(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            root = _write_fixture_repo(base, preset_text=_VALID_PRESET_TEXT)
            drifted_preset = base / "STF_BTC_H1_rev05_off.set"
            drifted_preset.write_text(_VALID_PRESET_TEXT, encoding="utf-8")
            with self.assertRaisesRegex(SuperTrendAdapterError, "preset filename drift"):
                load_supertrend_pilot(root, preset_path=str(drifted_preset))

    def test_source_and_preset_hashes_change_when_fixture_bytes_change(self):
        with tempfile.TemporaryDirectory() as tmp_a, tempfile.TemporaryDirectory() as tmp_b:
            root_a = _write_fixture_repo(
                pathlib.Path(tmp_a),
                preset_text="_01_AtrPeriod=14\n",
                source_text="// version A\n",
            )
            root_b = _write_fixture_repo(
                pathlib.Path(tmp_b),
                preset_text="_01_AtrPeriod=99\n",
                source_text="// version B\n",
            )
            record_a = load_supertrend_pilot(root_a)
            record_b = load_supertrend_pilot(root_b)
            self.assertNotEqual(record_a["SourceRef"]["sha256"], record_b["SourceRef"]["sha256"])
            self.assertNotEqual(record_a["PresetRef"]["sha256"], record_b["PresetRef"]["sha256"])
            self.assertNotEqual(
                record_a["ParameterSet"]["ParameterSetID"], record_b["ParameterSet"]["ParameterSetID"]
            )

    def test_fixture_record_validates(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = pathlib.Path(tmp)
            root = _write_fixture_repo(base, preset_text=_VALID_PRESET_TEXT)
            record = load_supertrend_pilot(root)
            validate_supertrend_pilot(record)  # must not raise


if __name__ == "__main__":
    unittest.main(verbosity=2)
