from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.architecture import (
    make_component,
    make_master_mold,
    make_position_group,
    make_strategy_family,
    make_strategy_variant,
)
from _triage.factory_vnext.parameter_surface import make_variant_parameter_surface
from _triage.factory_vnext.variant_generator import (
    VariantGeneratorError,
    make_variant_build_package,
    serialize_variant_build_package,
    validate_variant_build_package,
)


class FactoryVNextVariantGeneratorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.master = make_master_mold(
            "MOLD1", "1", ["CAP_ENTRY", "CAP_FILTER", "CAP_RECOVERY"]
        )
        self.family = make_strategy_family(
            self.master, "B14", "Boss14", ["CAP_ENTRY", "CAP_FILTER"], "14"
        )
        groups = [make_position_group("PG_MAIN", "MAIN")]
        components = [
            make_component("CMP_ENTRY", "ENTRY", "PG_MAIN", capabilities=["CAP_ENTRY"]),
            make_component(
                "CMP_FILTER", "FILTER", "PG_MAIN",
                capabilities=["CAP_FILTER"], enabled=False,
            ),
        ]
        self.variant = make_strategy_variant(
            self.family, "B14-V01", "1.0", groups, components, "14-01"
        )

    def _binding_rows(self):
        return [
            {
                "hypothesis_revision": "B14-H01-r1",
                "build_tag": "LAB_ENTRY_14",
                "parameter_pid": 100,
                "parameter": "AtrPeriod",
                "role": "TUNABLE",
                "surface": "OPERATOR",
                "optimize_stage": "SIGNAL",
                "safe_range": [10, 14, 20],
                "locked_value": None,
            },            {
                "hypothesis_revision": "B14-H01-r1",
                "build_tag": "LAB_ENTRY_14",
                "parameter_pid": 200,
                "parameter": "FixedLot",
                "role": "LOCKED",
                "surface": "HIDDEN",
                "optimize_stage": "FREEZE",
                "safe_range": None,
                "locked_value": 0.01,
            },
        ]

    def _display_rows(self):
        return [
            {
                "display_label": "ATR Period",
                "parameter": "AtrPeriod",
                "parameter_pid": 100,
                "portability": "PORTABLE",
                "relation_hint": "none",
                "relations": [],
                "unit_true": "bars",
            },
            {
                "display_label": "Fixed Lot",
                "parameter": "FixedLot",
                "parameter_pid": 200,                "portability": "PORTABLE",
                "relation_hint": "none",
                "relations": [],
                "unit_true": "lot",
            },
        ]

    def _surface(self):
        return make_variant_parameter_surface(
            self.variant,
            self._binding_rows(),
            self._display_rows(),
            "B14-H01-r1",
            "LAB_ENTRY_14",
        )

    def _package(self, **overrides):
        args = dict(
            master=self.master,
            family=self.family,
            variant=self.variant,
            parameter_surface=self._surface(),
            source_commit="a" * 40,
            template_id="EA_TEMPLATE_V2",
        )
        args.update(overrides)
        return make_variant_build_package(**args)

    def test_package_is_deterministic_and_non_authoritative(self):
        left = self._package()
        right = self._package()
        self.assertEqual(left["PackageID"], right["PackageID"])
        self.assertEqual(
            serialize_variant_build_package(left),
            serialize_variant_build_package(right),
        )
        self.assertEqual(left["authority"], "NON_AUTHORITATIVE_SIDECAR")

    def test_only_enabled_component_capabilities_are_activated(self):
        package = self._package()
        self.assertEqual(package["ActiveCapabilities"], ["CAP_ENTRY"])
        self.assertEqual(
            [row["ComponentID"] for row in package["EnabledComponents"]],
            ["CMP_ENTRY"],
        )

    def test_parameter_projection_separates_active_and_snapshot_only(self):
        package = self._package()
        projections = {row["parameter"]: row for row in package["ParameterProjection"]}
        self.assertEqual(projections["AtrPeriod"]["projection"], "ACTIVE_TUNABLE")
        self.assertEqual(projections["FixedLot"]["projection"], "SNAPSHOT_ONLY")
        self.assertEqual(projections["FixedLot"]["locked_value"], 0.01)
        self.assertNotIn("display_label", projections["AtrPeriod"])

    def test_source_commit_changes_package_identity(self):
        left = self._package(source_commit="a" * 40)
        right = self._package(source_commit="b" * 40)
        self.assertNotEqual(left["PackageID"], right["PackageID"])

    def test_surface_variant_mismatch_is_refused(self):
        bad_surface = {**self._surface(), "VariantID": "B14-V99"}
        with self.assertRaisesRegex(VariantGeneratorError, "VariantID mismatch"):
            self._package(parameter_surface=bad_surface)

    def test_surface_snapshot_mismatch_is_refused(self):
        bad_surface = {**self._surface(), "VariantSnapshotID": "VAR-bad"}
        with self.assertRaisesRegex(VariantGeneratorError, "VariantSnapshotID mismatch"):
            self._package(parameter_surface=bad_surface)

    def test_family_master_mismatch_is_refused(self):
        bad_family = {**self.family, "MasterMoldID": "OTHER"}
        with self.assertRaisesRegex(VariantGeneratorError, "MasterMoldID mismatch"):
            self._package(family=bad_family)

    def test_unknown_parameter_role_is_refused(self):
        surface = self._surface()
        rows = [dict(row) for row in surface["SurfaceRows"]]
        rows[0]["role"] = "MYSTERY"
        bad_surface = {**surface, "SurfaceRows": rows}
        with self.assertRaisesRegex(VariantGeneratorError, "unsupported parameter role"):
            self._package(parameter_surface=bad_surface)

    def test_invalid_source_commit_is_refused(self):
        with self.assertRaisesRegex(VariantGeneratorError, "source_commit"):
            self._package(source_commit="abc")

    def test_tampered_package_id_is_refused(self):
        package = self._package()
        bad = {**package, "PackageID": "VPKG-bad"}
        with self.assertRaisesRegex(VariantGeneratorError, "PackageID"):
            validate_variant_build_package(bad)
    def test_display_only_change_does_not_change_machine_package(self):
        surface = self._surface()
        rows = [dict(row) for row in surface["SurfaceRows"]]
        rows[0]["display_label"] = "ATR Period Changed"
        display_only = {**surface, "SurfaceRows": rows}
        left = self._package(parameter_surface=surface)
        right = self._package(parameter_surface=display_only)
        self.assertEqual(left["PackageID"], right["PackageID"])
        self.assertEqual(
            serialize_variant_build_package(left),
            serialize_variant_build_package(right),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
