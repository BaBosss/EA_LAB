from __future__ import annotations

import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.contracts import make_home_contract, make_parameter_set
from _triage.factory_vnext.identity_model import (
    EXPLICIT_MAPPING_REASON,
    H01_SEMANTICS_REQUIRED_REASON,
    IdentityModelError,
    load_alias_catalog,
    make_alias_catalog,
    make_legacy_alias,
    make_identity_projection,
    serialize_alias_catalog,
    source_artifact_ref,
    validate_alias_catalog,
    validate_identity_projection,
    validate_legacy_alias,
)


class FactoryVNextIdentityProjectionTests(unittest.TestCase):
    def _identity_inputs(self):
        home = make_home_contract("B24-00", "B24-H02-r1", "XAUUSD", "H1")
        parameter_set = make_parameter_set({"AtrPeriod": 14, "AtrMultiplier": 1.0}, "PROFILE-B24-A")
        return {
            "family_id": "B24",
            "logical_variant_id": "B24-00",
            "hypothesis_revision": "B24-H02-r1",
            "home_contract_id": home["HomeContractID"],
            "parameter_set_id": parameter_set["ParameterSetID"],
            "build_receipt": "br-0123456789abcdef0123456789abcdef",
            "run_id": "RUN-0123456789abcdef01234567",
            "package_id": "VPKG-0123456789abcdef01234567",
        }

    def test_resolved_identity_is_deterministic_and_keeps_layers_separate(self):
        inputs = self._identity_inputs()

        left = make_identity_projection(**inputs)
        right = make_identity_projection(**inputs)

        self.assertEqual(left, right)
        self.assertEqual(left["FamilyID"], "B24")
        self.assertEqual(left["LogicalVariantID"], "B24-00")
        self.assertEqual(left["HypothesisRevision"], "B24-H02-r1")
        self.assertEqual(left["HomeContractID"], inputs["home_contract_id"])
        self.assertEqual(left["ParameterSetID"], inputs["parameter_set_id"])
        self.assertEqual(left["authority"], "NON_AUTHORITATIVE_SIDECAR")

    def test_resolved_identity_never_derives_logical_variant_from_other_layers(self):
        inputs = self._identity_inputs()
        inputs["logical_variant_id"] = None

        with self.assertRaisesRegex(IdentityModelError, "LogicalVariantID is required"):
            make_identity_projection(**inputs)

    def test_resolved_identity_requires_family_consistency(self):
        inputs = self._identity_inputs()
        inputs["logical_variant_id"] = "B25-00"

        with self.assertRaisesRegex(IdentityModelError, "must belong to FamilyID B24"):
            make_identity_projection(**inputs)

    def test_home_and_parameter_set_are_required_identity_layers(self):
        for field, message in (
            ("home_contract_id", "HomeContractID is required"),
            ("parameter_set_id", "ParameterSetID is required"),
        ):
            with self.subTest(field=field):
                inputs = self._identity_inputs()
                inputs[field] = None
                with self.assertRaisesRegex(IdentityModelError, message):
                    make_identity_projection(**inputs)

    def test_config_change_does_not_change_explicit_logical_identity(self):
        first = self._identity_inputs()
        second = dict(first)
        second["parameter_set_id"] = make_parameter_set(
            {"AtrPeriod": 21, "AtrMultiplier": 1.5}, "PROFILE-B24-B"
        )["ParameterSetID"]

        left = make_identity_projection(**first)
        right = make_identity_projection(**second)

        self.assertEqual(left["LogicalVariantID"], right["LogicalVariantID"])
        self.assertNotEqual(left["ParameterSetID"], right["ParameterSetID"])
        self.assertNotEqual(left["IdentityProjectionID"], right["IdentityProjectionID"])

    def test_tampered_or_expanded_projection_refuses(self):
        valid = make_identity_projection(**self._identity_inputs())
        with self.assertRaisesRegex(IdentityModelError, "fields do not match schema"):
            validate_identity_projection({**valid, "PhysicalSymbol": "XAUUSDm"})
        with self.assertRaisesRegex(IdentityModelError, "IdentityProjectionID"):
            validate_identity_projection({**valid, "IdentityProjectionID": "EAID-bad"})


class FactoryVNextLegacyAliasTests(unittest.TestCase):
    def _b11_alias(self):
        source_path = "factory/vnext/pilots/boss11_h01_first_green/variant_build_package.json"
        return make_legacy_alias(
            family_id="B11",
            legacy_variant_id="B11-H01-R1",
            variant_snapshot_id="VAR-e07c154fb8e28708ae820d97",
            hypothesis_revision="B11-H01-r1",
            strategy_version="B11-H01-r1",
            package_id="VPKG-3324eb0713e6b7855b694c01",
            source_artifact=source_artifact_ref(str(ROOT), source_path),
        )

    def _b12_alias(self):
        source_path = "factory/vnext/pilots/boss12_h01_first_green/variant_build_package.json"
        return make_legacy_alias(
            family_id="B12",
            legacy_variant_id="B12-H01-R1",
            variant_snapshot_id="VAR-07eee9a4de1aa180ab794993",
            hypothesis_revision="B12-H01-r1",
            strategy_version="B12-H01-r1",
            package_id="VPKG-d742e70993a76bfb1c5abc4b",
            source_artifact=source_artifact_ref(str(ROOT), source_path),
        )

    def test_unresolved_h01_alias_is_deterministic_and_never_promotes_legacy_id(self):
        source_path = "factory/vnext/pilots/boss11_h01_first_green/variant_build_package.json"
        source = source_artifact_ref(str(ROOT), source_path)
        inputs = {
            "family_id": "B11",
            "legacy_variant_id": "B11-H01-R1",
            "variant_snapshot_id": "VAR-e07c154fb8e28708ae820d97",
            "hypothesis_revision": "B11-H01-r1",
            "strategy_version": "B11-H01-r1",
            "package_id": "VPKG-3324eb0713e6b7855b694c01",
            "source_artifact": source,
        }

        left = make_legacy_alias(**inputs)
        right = make_legacy_alias(**inputs)

        self.assertEqual(left, right)
        self.assertEqual(
            source["sha256"],
            "500ee899d9fb927c1d47cc54fb4b8bd8661b535779352afd54e88c3516d73a9a",
        )
        self.assertIsNone(left["LogicalVariantID"])
        self.assertEqual(left["ResolutionStatus"], "SEMANTICS_REQUIRED")
        self.assertEqual(left["ReasonCode"], H01_SEMANTICS_REQUIRED_REASON)
        self.assertEqual(left["authority"], "NON_AUTHORITATIVE_SIDECAR")

    def test_resolved_alias_requires_explicit_logical_variant_and_family_consistency(self):
        unresolved = self._b11_alias()
        valid = {
            **unresolved,
            "LogicalVariantID": "B11-00",
            "ResolutionStatus": "RESOLVED",
            "ReasonCode": EXPLICIT_MAPPING_REASON,
        }
        validate_legacy_alias(valid, repo_root=str(ROOT))

        with self.assertRaisesRegex(IdentityModelError, "LogicalVariantID is required"):
            validate_legacy_alias({**valid, "LogicalVariantID": None})
        with self.assertRaisesRegex(IdentityModelError, "must belong to FamilyID B11"):
            validate_legacy_alias({**valid, "LogicalVariantID": "B12-00"})

    def test_unresolved_alias_refuses_any_logical_variant_promotion(self):
        unresolved = self._b11_alias()
        with self.assertRaisesRegex(IdentityModelError, "must keep LogicalVariantID null"):
            validate_legacy_alias({**unresolved, "LogicalVariantID": "B11-H01-R1"})

    def test_source_hash_and_source_identity_mismatches_refuse(self):
        valid = self._b11_alias()
        bad_hash = make_legacy_alias(
            family_id=valid["FamilyID"],
            legacy_variant_id=valid["LegacyVariantID"],
            variant_snapshot_id=valid["VariantSnapshotID"],
            hypothesis_revision=valid["HypothesisRevision"],
            strategy_version=valid["StrategyVersion"],
            package_id=valid["PackageID"],
            source_artifact={**valid["SourceArtifact"], "sha256": "0" * 64},
        )
        with self.assertRaisesRegex(IdentityModelError, "SourceArtifact sha256 mismatch"):
            validate_legacy_alias(bad_hash, repo_root=str(ROOT))

        wrong_source_identity = make_legacy_alias(
            family_id="B99",
            legacy_variant_id=valid["LegacyVariantID"],
            variant_snapshot_id=valid["VariantSnapshotID"],
            hypothesis_revision=valid["HypothesisRevision"],
            strategy_version=valid["StrategyVersion"],
            package_id=valid["PackageID"],
            source_artifact=valid["SourceArtifact"],
        )
        with self.assertRaisesRegex(IdentityModelError, "SourceArtifact field FamilyID"):
            validate_legacy_alias(wrong_source_identity, repo_root=str(ROOT))

    def test_source_reference_refuses_escape_from_repository(self):
        with self.assertRaisesRegex(IdentityModelError, "repository-relative"):
            source_artifact_ref(str(ROOT), "../outside.json")

    def test_alias_catalog_is_deterministic_and_sorted(self):
        b11 = self._b11_alias()
        b12 = self._b12_alias()

        left = make_alias_catalog([b12, b11])
        right = make_alias_catalog([b11, b12])

        self.assertEqual(left, right)
        self.assertEqual(serialize_alias_catalog(left), serialize_alias_catalog(right))
        self.assertEqual(
            [row["FamilyID"] for row in left["Aliases"]], ["B11", "B12"]
        )
        validate_alias_catalog(left, repo_root=str(ROOT))

    def test_duplicate_legacy_alias_refuses(self):
        b11 = self._b11_alias()
        with self.assertRaisesRegex(IdentityModelError, "duplicate legacy alias"):
            make_alias_catalog([b11, dict(b11)])

    def test_tracked_b11_b18_bridge_is_source_valid_and_unresolved(self):
        catalog_path = ROOT / "factory/vnext/identity_aliases.json"
        catalog = load_alias_catalog(str(catalog_path), repo_root=str(ROOT))

        self.assertEqual(len(catalog["Aliases"]), 8)
        self.assertEqual(
            [row["FamilyID"] for row in catalog["Aliases"]],
            ["B11", "B12", "B13", "B14", "B15", "B16", "B17", "B18"],
        )
        self.assertTrue(
            all(row["LogicalVariantID"] is None for row in catalog["Aliases"])
        )
        self.assertEqual(
            {row["ResolutionStatus"] for row in catalog["Aliases"]},
            {"SEMANTICS_REQUIRED"},
        )
        self.assertEqual(
            {row["ReasonCode"] for row in catalog["Aliases"]},
            {H01_SEMANTICS_REQUIRED_REASON},
        )
        self.assertEqual(catalog_path.read_bytes(), serialize_alias_catalog(catalog))


if __name__ == "__main__":
    unittest.main(verbosity=2)
