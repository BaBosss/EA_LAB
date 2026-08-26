import copy
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
from _triage.factory_vnext.mt5_set_consumer_pilot import (
    MT5SetConsumerPilotError,
    build_supertrend_mt5_set_consumer_pilot,
    serialize_consumer_pilot,
    validate_mt5_set_consumer_pilot,
)


class MT5SetConsumerPilotTests(unittest.TestCase):
    def test_real_canonical_inputs_refuse_before_adapter(self):
        record = build_supertrend_mt5_set_consumer_pilot(str(ROOT))
        self.assertEqual(record["status"], "REFUSED")
        self.assertEqual(record["consumer_stage"], "PRE_ADAPTER_GATE")
        self.assertFalse(record["adapter_invoked"])
        self.assertFalse(record["mt5_terminal_touched"])
        self.assertFalse(record["strategy_tester_invoked"])
        codes = {row.get("code") for row in record["refusal_reasons"]}
        self.assertIn("NO_CANONICAL_VARIANT_BUILD_PACKAGE", codes)
        self.assertIn("KINT_001_OPEN", codes)
        self.assertIn("SEMANTICS_REQUIRED", codes)
        self.assertIsNone(record["PackageID"])
        self.assertIsNone(record["compat_manifest"])
        self.assertIsNone(record["proposed_set_text"])

        preset = ROOT / "_mt5_auto" / "ab_sets" / "genstanding_stf" / "STF_BTC_H4_rev05_off.set"
        expected_sha = hashlib.sha256(preset.read_bytes()).hexdigest()
        self.assertEqual(record["BaselinePresetRef"]["sha256"], expected_sha)
        self.assertEqual(record["KINT_001"], {"state": "OPEN"})

    def test_rerun_bytes_are_stable_and_tamper_refuses(self):
        first = build_supertrend_mt5_set_consumer_pilot(str(ROOT))
        second = build_supertrend_mt5_set_consumer_pilot(str(ROOT))
        self.assertEqual(first["ConsumerPilotID"], second["ConsumerPilotID"])
        self.assertEqual(serialize_consumer_pilot(first), serialize_consumer_pilot(second))
        tampered = copy.deepcopy(first)
        tampered["mt5_terminal_touched"] = True
        with self.assertRaisesRegex(MT5SetConsumerPilotError, "must not touch MT5 terminal"):
            validate_mt5_set_consumer_pilot(tampered)

    def _minimal_supertrend_package(self):
        master = make_master_mold("LEGACY-STF-MOLD", "pilot-v1", ["CAP_ENTRY"])
        family = make_strategy_family(master, "LEGACY-STF", "(TRD)_SuperTrendFlip", ["CAP_ENTRY"])
        variant = make_strategy_variant(family, "LEGACY-STF-REV05", "rev05", [], [])
        bindings = [{
            "hypothesis_revision": "STF-CONSUMER-r1", "build_tag": "STF_REV05",
            "parameter_pid": 1, "parameter": "_01_AtrPeriod", "role": "TUNABLE",
            "surface": "OPERATOR", "optimize_stage": "SIGNAL",
            "safe_range": None, "locked_value": None,
        }]
        displays = [{
            "parameter_pid": 1, "parameter": "_01_AtrPeriod", "display_label": "ATR Period",
            "portability": "PORTABLE", "unit_true": "bars", "relation_hint": "none", "relations": [],
        }]
        surface = make_variant_parameter_surface(
            variant, bindings, displays, "STF-CONSUMER-r1", "STF_REV05"
        )
        return make_variant_build_package(
            master=master, family=family, variant=variant, parameter_surface=surface,
            source_commit="c" * 40, template_id="EA_TEMPLATE_V2",
        )

    def test_valid_package_reaches_adapter_but_current_semantics_still_refuse(self):
        package = self._minimal_supertrend_package()
        record = build_supertrend_mt5_set_consumer_pilot(str(ROOT), package=package)
        self.assertEqual(record["status"], "REFUSED")
        self.assertEqual(record["consumer_stage"], "ADAPTER_GATE")
        self.assertTrue(record["adapter_invoked"])
        self.assertEqual(record["PackageID"], package["PackageID"])
        self.assertIsInstance(record["compat_manifest"], dict)
        self.assertIsNone(record["proposed_set_text"])
        reasons = record["refusal_reasons"]
        self.assertTrue(any(row.get("reason") == "SEMANTICS_REQUIRED" for row in reasons))
        self.assertFalse(record["mt5_terminal_touched"])
        self.assertFalse(record["strategy_tester_invoked"])


if __name__ == "__main__":
    unittest.main()
