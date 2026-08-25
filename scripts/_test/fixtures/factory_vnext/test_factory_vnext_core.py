from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.architecture import (
    ArchitectureError,
    make_component,
    make_master_mold,
    make_position_group,
    make_strategy_family,
    make_strategy_variant,
    variant_context,
)
from _triage.factory_vnext.contracts import (
    make_home_contract,
    make_parameter_set,
    make_run_manifest,
    make_window_contract,
    home_match_status,
    windows_rank_comparable,
)


class FactoryVNextCoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.master = make_master_mold(
            "MOLD1", "1", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE", "CAP_FILTER"]
        )
        self.family = make_strategy_family(
            self.master, "B11", "Boss11", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE"], "11"
        )

    def _groups(self):
        return [
            make_position_group("PG_MAIN", "MAIN"),
            make_position_group("PG_REVERSAL", "REVERSAL"),
            make_position_group("PG_HEDGE", "HEDGE", "PG_MAIN"),
        ]

    def _components(self):
        return [
            make_component("CMP_MAIN", "ENTRY", "PG_MAIN", capabilities=["CAP_ENTRY"]),
            make_component("CMP_REV", "REVERSAL", "PG_REVERSAL", capabilities=["CAP_ENTRY"]),
            make_component(
                "CMP_REC_REV", "RECOVERY", "PG_REVERSAL",
                capabilities=["CAP_RECOVERY"],
                recovery_scope_position_group_id="PG_REVERSAL",
            ),
            make_component(
                "CMP_HEDGE", "HEDGE", "PG_HEDGE", capabilities=["CAP_HEDGE"],
                parent_position_group_id="PG_MAIN",
            ),
        ]

    def test_variant_snapshot_is_deterministic_and_display_is_projection_only(self):
        v1 = make_strategy_variant(self.family, "B11-V01", "1.0", self._groups(), self._components(), "11-01")
        v2 = make_strategy_variant(
            {**self.family, "DisplayID": "ELEVEN"}, "B11-V01", "1.0",
            list(reversed(self._groups())), list(reversed(self._components())), "DISPLAY-X",
        )
        self.assertEqual(v1["VariantSnapshotID"], v2["VariantSnapshotID"])

    def test_master_capability_addition_does_not_activate_existing_variant(self):
        v1 = make_strategy_variant(self.family, "B11-V01", "1.0", self._groups(), self._components())
        expanded_master = make_master_mold(
            "MOLD1", "2", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE", "CAP_FILTER", "CAP_NEW"]
        )
        same_family = make_strategy_family(
            expanded_master, "B11", "Boss11", ["CAP_ENTRY", "CAP_RECOVERY", "CAP_HEDGE"], "11"
        )
        v2 = make_strategy_variant(same_family, "B11-V01", "1.0", self._groups(), self._components())
        self.assertEqual(v1["VariantSnapshotID"], v2["VariantSnapshotID"])
        self.assertNotIn("CAP_NEW", {cap for c in v2["Components"] for cap in c["Capabilities"]})

    def test_recovery_is_group_local(self):
        bad = [
            make_component(
                "CMP_REC_BAD", "RECOVERY", "PG_REVERSAL", capabilities=["CAP_RECOVERY"],
                recovery_scope_position_group_id="PG_MAIN",
            )
        ]
        with self.assertRaisesRegex(ArchitectureError, "group-local"):
            make_strategy_variant(self.family, "B11-V02", "1.0", self._groups(), bad)

    def test_hedge_requires_explicit_parent_group(self):
        bad = [make_component("CMP_H", "HEDGE", "PG_HEDGE", capabilities=["CAP_HEDGE"])]
        with self.assertRaisesRegex(ArchitectureError, "requires ParentPositionGroupID"):
            make_strategy_variant(self.family, "B11-V03", "1.0", self._groups(), bad)

    def test_family_cannot_select_capability_outside_master(self):
        with self.assertRaisesRegex(ArchitectureError, "outside Master Mold"):
            make_strategy_family(self.master, "B12", "Boss12", ["CAP_UNKNOWN"])

    def test_variant_home_contract_uses_variant_id_without_alternate_key(self):
        variant = make_strategy_variant(self.family, "B11-V01", "1.0", self._groups(), self._components())
        home = make_home_contract(
            variant["VariantID"], variant["StrategyVersion"], "BTCUSD", "H4",
            variant_context(self.master, self.family, variant),
        )
        self.assertEqual(home["ConceptID"], "B11-V01")
        self.assertEqual(home["ContextArchitecture"]["FamilyID"], "B11")
        self.assertEqual(home_match_status(home, "BTCUSD", "H4"), "INSIDE_VALIDATED_CONTRACT")
        self.assertEqual(home_match_status(home, "XAUUSD", "H4"), "OUTSIDE_VALIDATED_CONTRACT")
        self.assertEqual(home_match_status(home, "BTCUSD", "H1"), "OUTSIDE_VALIDATED_CONTRACT")

    def test_run_manifest_preserves_architecture_context(self):
        variant = make_strategy_variant(self.family, "B11-V01", "1.0", self._groups(), self._components())
        context = variant_context(self.master, self.family, variant)
        home = make_home_contract("B11-V01", "1.0", "BTCUSD", "H4", context)
        window = make_window_contract("DISCOVERY", "2026-01-01", "2026-02-01", "H4", bars=100)
        params = make_parameter_set({"AtrPeriod": 14, "Mult": 2.5}, "PROFILE-STF")
        run = make_run_manifest(
            source_commit="a" * 40, home=home, window=window, profile_id="PROFILE-STF",
            parameter_set=params, physical_symbol="BTCUSDm", broker_data="fixture",
            tester_model="fixture-model", runtime_seconds=1.0, bars=100,
        )
        self.assertEqual(run["ContextArchitecture"], context)

    def test_run_id_binds_execution_environment(self):
        home = make_home_contract("B11-V01", "1.0", "BTCUSD", "H4")
        window = make_window_contract("COMMON_VALIDATION", "2026-01-01", "2026-06-30", "H4")
        params = make_parameter_set({"AtrPeriod": 14}, "PROFILE-STF")
        common = dict(source_commit="a" * 40, home=home, window=window, profile_id="PROFILE-STF", parameter_set=params, runtime_seconds=1.0, bars=100)
        base = make_run_manifest(physical_symbol="BTCUSD", broker_data="BROKER-A", tester_model="MODEL-A", **common)
        broker = make_run_manifest(physical_symbol="BTCUSD", broker_data="BROKER-B", tester_model="MODEL-A", **common)
        model = make_run_manifest(physical_symbol="BTCUSD", broker_data="BROKER-A", tester_model="MODEL-B", **common)
        physical = make_run_manifest(physical_symbol="BTCUSDm", broker_data="BROKER-A", tester_model="MODEL-A", **common)
        self.assertNotEqual(base["RunID"], broker["RunID"])
        self.assertNotEqual(base["RunID"], model["RunID"])
        self.assertNotEqual(base["RunID"], physical["RunID"])

    def test_different_windows_are_not_rank_comparable(self):
        w1 = make_window_contract("DISCOVERY", "2026-01-01", "2026-02-01", "H4")
        w2 = make_window_contract("COMMON_VALIDATION", "2026-01-01", "2026-02-01", "H4")
        self.assertFalse(windows_rank_comparable(w1, w2))
        self.assertTrue(windows_rank_comparable(w1, dict(w1)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
