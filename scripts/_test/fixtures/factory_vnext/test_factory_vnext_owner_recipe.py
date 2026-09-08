# -*- coding: utf-8 -*-
import copy
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.contracts import make_parameter_set, stable_id
from _triage.factory_vnext.identity_model import make_identity_projection
from _triage.factory_vnext.owner_recipe import (
    EFFECTIVE, IGNORED, LOCKED, SEMANTICS_REQUIRED,
    LOT_PROGRESSION_SEMANTICS, OwnerRecipeError,
    make_owner_recipe, make_owner_recipe_catalog, make_resolved_effective_config,
    serialize_owner_recipe, serialize_owner_recipe_catalog,
    serialize_resolved_effective_config, validate_owner_recipe,
    validate_owner_recipe_catalog, validate_resolved_effective_config,
)


class FactoryVNextOwnerRecipeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = ROOT / "factory/vnext/pilots/boss14_h01_first_green/variant_build_package.json"
        cls.package = json.loads(path.read_text(encoding="utf-8"))

    def _parameter_set(self, mutate=None):
        params = {
            row["parameter"]: "REQ:%s" % row["parameter"]
            for row in self.package["ParameterProjection"]
        }
        if mutate:
            mutate(params)
        return make_parameter_set(params, "PROFILE-B14-OWNER-RECIPE")

    def _identity(self, parameter_set, **overrides):
        values = dict(
            family_id="B14",
            logical_variant_id="B14-TESTFIXTURE",
            hypothesis_revision=self.package["hypothesis_revision"],
            home_contract_id="HOME-" + "a" * 20,
            parameter_set_id=parameter_set["ParameterSetID"],
            build_receipt="br-" + "b" * 32,
            run_id="RUN-" + "c" * 24,
            package_id=self.package["PackageID"],
        )
        values.update(overrides)
        return make_identity_projection(**values)

    def _quarantine_resolution(self, parameter_set):
        target = next(
            row for row in self.package["ParameterProjection"]
            if row["parameter"] == "UseMiddlePathVeto"
        )
        return {
            "parameter_pid": target["parameter_pid"],
            "parameter": target["parameter"],
            "state": EFFECTIVE,
            "effective_value": parameter_set["parameters"][target["parameter"]],
            "reason": "EXPLICIT_TEST_APPLICABILITY",
        }

    def _effective_resolutions(self, parameter_set):
        return [
            {
                "parameter_pid": row["parameter_pid"],
                "parameter": row["parameter"],
                "state": EFFECTIVE,
                "effective_value": parameter_set["parameters"][row["parameter"]],
                "reason": "EXPLICIT_TEST_APPLICABILITY",
            }
            for row in self.package["ParameterProjection"]
            if row["role"] == "TUNABLE"
        ]

    def _source_bundle(self, parameter_set, resolutions):
        return {
            "IdentityProjection": self._identity(parameter_set),
            "ParameterSet": parameter_set,
            "VariantBuildPackage": self.package,
            "Resolutions": list(resolutions),
        }

    def _reidentify_package(self, package):
        keys = (
            "source_commit", "TemplateID", "MasterMoldID", "MasterMoldVersion",
            "MasterMoldSnapshotID", "FamilyID", "VariantID", "VariantSnapshotID",
            "StrategyVersion", "ParameterSurfaceID", "hypothesis_revision", "build_tag",
            "ActiveCapabilities", "EnabledComponents", "ParameterProjection",
        )
        payload = {key: package[key] for key in keys}
        if "BaselineCoverage" in package:
            payload["BaselineCoverage"] = package["BaselineCoverage"]
        package["PackageID"] = stable_id("VPKG", payload, hex_chars=24)
        return package

    def _reidentify_effective(self, effective):
        keys = (
            "IdentityProjectionID", "FamilyID", "LogicalVariantID",
            "HypothesisRevision", "ProfileID", "ParameterSetID",
            "ParameterSnapshotSHA256", "PackageID", "Controls", "Blockers",
            "LotProgressionSemantics",
        )
        payload = {key: effective[key] for key in keys}
        effective["ResolvedEffectiveConfigSHA256"] = __import__("hashlib").sha256(
            json.dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        effective["ResolvedEffectiveConfigID"] = stable_id(
            "RECFG", payload, hex_chars=24
        )
        return effective

    def _reidentify_recipe(self, recipe):
        keys = (
            "Identity", "ResolvedEffectiveConfigID",
            "ResolvedEffectiveConfigSHA256", "Controls", "Blockers", "Status",
            "NextAction", "LotProgressionSemantics",
        )
        payload = {key: recipe[key] for key in keys}
        recipe["OwnerRecipeSHA256"] = __import__("hashlib").sha256(
            json.dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        recipe["OwnerRecipeID"] = stable_id("ORECIPE", payload, hex_chars=24)
        return recipe

    def _reidentify_catalog(self, catalog):
        payload = {"Recipes": catalog["Recipes"]}
        catalog["OwnerRecipeCatalogSHA256"] = __import__("hashlib").sha256(
            json.dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        catalog["OwnerRecipeCatalogID"] = stable_id(
            "ORCAT", payload, hex_chars=24
        )
        return catalog

    def _build(self, parameter_set=None, resolutions=None):
        parameter_set = parameter_set or self._parameter_set()
        if resolutions is None:
            resolutions = self._effective_resolutions(parameter_set)
        identity = self._identity(parameter_set)
        effective = make_resolved_effective_config(
            identity, parameter_set, self.package, resolutions=resolutions
        )
        recipe = make_owner_recipe(
            identity,
            effective,
            parameter_set=parameter_set,
            package=self.package,
            resolutions=resolutions,
        )
        return identity, parameter_set, effective, recipe

    def test_ready_recipe_is_deterministic_and_reason_coded(self):
        identity, _, effective1, recipe1 = self._build()
        _, _, effective2, recipe2 = self._build()
        self.assertEqual(effective1, effective2)
        self.assertEqual(recipe1, recipe2)
        self.assertEqual(recipe1["Status"], "READY")
        self.assertEqual(recipe1["NextAction"], "CONSUME_OWNER_RECIPE")
        self.assertEqual(recipe1["Identity"]["LogicalVariantID"], identity["LogicalVariantID"])
        self.assertEqual(recipe1["Identity"]["HomeContractID"], identity["HomeContractID"])
        self.assertEqual(recipe1["Identity"]["BuildReceipt"], identity["BuildReceipt"])
        self.assertEqual(recipe1["Identity"]["RunID"], identity["RunID"])
        self.assertEqual(recipe1["Identity"]["PackageID"], identity["PackageID"])
        self.assertEqual(recipe1["Blockers"], [])
        self.assertEqual(recipe1["LotProgressionSemantics"], LOT_PROGRESSION_SEMANTICS)
        self.assertEqual(
            recipe1["LotProgressionSemantics"],
            {
                "PROG_PLUS": "ADDITIVE: firstLot + plus * level",
                "PROG_LINEAR": "PROPORTIONAL: firstLot * (1 + factor * level)",
            },
        )
        self.assertRegex(effective1["ResolvedEffectiveConfigSHA256"], r"^[0-9a-f]{64}$")
        self.assertRegex(recipe1["OwnerRecipeSHA256"], r"^[0-9a-f]{64}$")
        effective_sources = {
            "identity": identity,
            "parameter_set": self._parameter_set(),
            "package": self.package,
            "resolutions": self._effective_resolutions(self._parameter_set()),
        }
        self.assertEqual(
            serialize_resolved_effective_config(effective1, **effective_sources),
            serialize_resolved_effective_config(
                effective2, **effective_sources
            ),
        )
        self.assertEqual(
            serialize_owner_recipe(
                recipe1, effective_config=effective1, **effective_sources
            ),
            serialize_owner_recipe(
                recipe2, effective_config=effective2, **effective_sources
            ),
        )
        states = {row["state"] for row in recipe1["Controls"]}
        self.assertIn(EFFECTIVE, states)
        self.assertIn(LOCKED, states)
        validate_resolved_effective_config(
            effective1,
            identity=identity,
            parameter_set=self._parameter_set(),
            package=self.package,
            resolutions=self._effective_resolutions(self._parameter_set()),
        )
        validate_owner_recipe(
            recipe1,
            identity=identity,
            effective_config=effective1,
            parameter_set=self._parameter_set(),
            package=self.package,
            resolutions=self._effective_resolutions(self._parameter_set()),
        )
        validate_owner_recipe(
            recipe1,
            identity=identity,
            effective_config=effective1,
            parameter_set=self._parameter_set(),
            package=self.package,
            resolutions=(
                row for row in self._effective_resolutions(self._parameter_set())
            ),
        )

    def test_recipe_carries_all_explicit_identity_references_without_quality_claims(self):
        ps = self._parameter_set()
        identity = self._identity(
            ps,
            build_receipt="br-0123456789abcdef0123456789abcdef",
            run_id="RUN-0123456789abcdef01234567",
        )
        effective = make_resolved_effective_config(identity, ps, self.package)
        recipe = make_owner_recipe(
            identity, effective, parameter_set=ps, package=self.package
        )

        self.assertEqual(recipe["Identity"]["FamilyID"], "B14")
        self.assertEqual(recipe["Identity"]["LogicalVariantID"], "B14-TESTFIXTURE")
        self.assertEqual(recipe["Identity"]["HypothesisRevision"], self.package["hypothesis_revision"])
        self.assertEqual(recipe["Identity"]["HomeContractID"], identity["HomeContractID"])
        self.assertEqual(recipe["Identity"]["ParameterSetID"], ps["ParameterSetID"])
        self.assertEqual(recipe["Identity"]["BuildReceipt"], identity["BuildReceipt"])
        self.assertEqual(recipe["Identity"]["RunID"], identity["RunID"])
        self.assertEqual(recipe["Identity"]["PackageID"], self.package["PackageID"])
        self.assertNotIn("performance", recipe)
        self.assertNotIn("promotion", recipe)

    def test_parameter_change_changes_config_and_recipe_not_logical_variant(self):
        id1, _, eff1, rec1 = self._build()
        ps2 = self._parameter_set(lambda p: p.__setitem__("_0_ATR_Period", "REQ:changed"))
        id2 = self._identity(ps2)
        eff2 = make_resolved_effective_config(id2, ps2, self.package)
        rec2 = make_owner_recipe(
            id2, eff2, parameter_set=ps2, package=self.package
        )
        self.assertEqual(id1["LogicalVariantID"], id2["LogicalVariantID"])
        self.assertNotEqual(id1["ParameterSetID"], id2["ParameterSetID"])
        self.assertNotEqual(eff1["ResolvedEffectiveConfigID"], eff2["ResolvedEffectiveConfigID"])
        self.assertNotEqual(rec1["OwnerRecipeID"], rec2["OwnerRecipeID"])

    def test_profile_change_changes_resolved_config_and_recipe_identity(self):
        identity1, ps1, effective1, recipe1 = self._build()
        ps2 = make_parameter_set(ps1["parameters"], "PROFILE-B14-OTHER")
        identity2 = self._identity(ps2)
        effective2 = make_resolved_effective_config(identity2, ps2, self.package)
        recipe2 = make_owner_recipe(
            identity2, effective2, parameter_set=ps2, package=self.package
        )

        self.assertEqual(ps1["ParameterSetID"], ps2["ParameterSetID"])
        self.assertEqual(identity1["LogicalVariantID"], identity2["LogicalVariantID"])
        self.assertNotEqual(effective1["ResolvedEffectiveConfigID"], effective2["ResolvedEffectiveConfigID"])
        self.assertNotEqual(recipe1["OwnerRecipeID"], recipe2["OwnerRecipeID"])

    def test_catalog_is_deterministic_sorted_exact_and_duplicate_safe(self):
        _, first_ps, _, first = self._build()
        changed = self._parameter_set(
            lambda params: params.__setitem__("_0_ATR_Period", "REQ:changed")
        )
        _, _, _, second = self._build(changed)
        first_source = self._source_bundle(
            first_ps, self._effective_resolutions(first_ps)
        )
        second_source = self._source_bundle(
            changed, self._effective_resolutions(changed)
        )

        left = make_owner_recipe_catalog([second_source, first_source])
        right = make_owner_recipe_catalog([first_source, second_source])
        self.assertEqual(left, right)
        self.assertEqual(
            serialize_owner_recipe_catalog(
                left, sources=[first_source, second_source]
            ),
            serialize_owner_recipe_catalog(
                right, sources=[second_source, first_source]
            ),
        )
        self.assertEqual(
            [row["OwnerRecipeID"] for row in left["Recipes"]],
            sorted(row["OwnerRecipeID"] for row in (first, second)),
        )
        validate_owner_recipe_catalog(
            left, sources=[second_source, first_source]
        )

        with self.assertRaisesRegex(OwnerRecipeError, "duplicate OwnerRecipeID"):
            make_owner_recipe_catalog([first_source, first_source])
        ps = self._parameter_set()
        identity = self._identity(ps)
        target = next(
            row for row in self.package["ParameterProjection"]
            if row["role"] == "TUNABLE"
        )
        alternate_effective = make_resolved_effective_config(
            identity,
            ps,
            self.package,
            resolutions=[{
                "parameter_pid": target["parameter_pid"],
                "parameter": target["parameter"],
                "state": IGNORED,
                "effective_value": None,
                "reason": "EXPLICIT_FIXTURE_INACTIVE",
            }],
        )
        alternate_source = {
            "IdentityProjection": identity,
            "ParameterSet": ps,
            "VariantBuildPackage": self.package,
            "Resolutions": [{
                "parameter_pid": target["parameter_pid"],
                "parameter": target["parameter"],
                "state": IGNORED,
                "effective_value": None,
                "reason": "EXPLICIT_FIXTURE_INACTIVE",
            }],
        }
        with self.assertRaisesRegex(OwnerRecipeError, "duplicate IdentityProjectionID"):
            make_owner_recipe_catalog([first_source, alternate_source])
        with self.assertRaisesRegex(OwnerRecipeError, "catalog fields"):
            validate_owner_recipe_catalog(
                {**left, "OwnerDefault": "INVENTED"},
                sources=[first_source, second_source],
            )
        with self.assertRaisesRegex(OwnerRecipeError, "catalog source fields"):
            make_owner_recipe_catalog(
                [{**first_source, "OwnerDefault": "INVENTED"}]
            )

        forged_catalog = make_owner_recipe_catalog([first_source])
        forged_catalog["Recipes"][0]["ResolvedEffectiveConfigID"] = "NOT-A-CONFIG"
        self._reidentify_recipe(forged_catalog["Recipes"][0])
        self._reidentify_catalog(forged_catalog)
        with self.assertRaisesRegex(OwnerRecipeError, "ResolvedEffectiveConfigID"):
            validate_owner_recipe_catalog(
                forged_catalog, sources=[first_source]
            )

    def test_missing_request_surfaces_semantics_required_instead_of_guess(self):
        ps = self._parameter_set(lambda p: p.pop("_0_ATR_Period"))
        identity = self._identity(ps)
        effective = make_resolved_effective_config(identity, ps, self.package)
        recipe = make_owner_recipe(
            identity, effective, parameter_set=ps, package=self.package
        )
        row = next(r for r in recipe["Controls"] if r["parameter"] == "_0_ATR_Period")
        self.assertEqual(row["state"], SEMANTICS_REQUIRED)
        self.assertEqual(row["reason"], "REQUEST_VALUE_MISSING")
        self.assertIsNone(row["effective_value"])
        self.assertEqual(recipe["Status"], "BLOCKED_SEMANTICS_REQUIRED")
        self.assertEqual(recipe["NextAction"], "RESOLVE_SEMANTICS_REQUIRED")

        locked_ps = self._parameter_set(lambda p: p.pop("FirstLotMode"))
        locked_identity = self._identity(locked_ps)
        locked_effective = make_resolved_effective_config(
            locked_identity, locked_ps, self.package
        )
        locked_row = next(
            row for row in locked_effective["Controls"]
            if row["parameter"] == "FirstLotMode"
        )
        self.assertEqual(locked_row["state"], SEMANTICS_REQUIRED)
        self.assertEqual(locked_row["reason"], "REQUEST_VALUE_MISSING")

    def test_uncovered_projection_blocks_until_explicitly_resolved(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        unresolved = make_resolved_effective_config(identity, ps, self.package)
        row = next(
            control for control in unresolved["Controls"]
            if control["parameter"] == "UseMiddlePathVeto"
        )
        self.assertEqual(row["state"], SEMANTICS_REQUIRED)
        self.assertEqual(row["reason"], "EXPLICIT_RESOLUTION_REQUIRED")
        self.assertIsNone(row["effective_value"])

        resolution = self._quarantine_resolution(ps)
        resolved = make_resolved_effective_config(
            identity, ps, self.package, resolutions=[resolution]
        )
        resolved_row = next(
            control for control in resolved["Controls"]
            if control["parameter"] == "UseMiddlePathVeto"
        )
        self.assertEqual(resolved_row["state"], EFFECTIVE)
        self.assertEqual(resolved_row["reason"], "EXPLICIT_TEST_APPLICABILITY")

    def test_explicit_ignored_resolution_requires_reason_and_null_effective(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        target = next(r for r in self.package["ParameterProjection"] if r["parameter"] == "_0_ATR_Period")
        resolution = {
            "parameter_pid": target["parameter_pid"], "parameter": target["parameter"],
            "state": IGNORED, "effective_value": None, "reason": "EXPLICIT_FIXTURE_INACTIVE",
        }
        effective = make_resolved_effective_config(identity, ps, self.package, resolutions=[resolution])
        row = next(r for r in effective["Controls"] if r["parameter"] == target["parameter"])
        self.assertEqual((row["state"], row["reason"]), (IGNORED, "EXPLICIT_FIXTURE_INACTIVE"))
        bad = dict(resolution, reason="")
        with self.assertRaisesRegex(OwnerRecipeError, "reason"):
            make_resolved_effective_config(identity, ps, self.package, resolutions=[bad])

    def test_locked_row_cannot_be_overridden_or_faked(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        target = next(r for r in self.package["ParameterProjection"] if r["parameter"] == "FirstLotMode")
        resolution = {
            "parameter_pid": target["parameter_pid"], "parameter": target["parameter"],
            "state": EFFECTIVE, "effective_value": "FAKE", "reason": "TRY_OVERRIDE",
        }
        with self.assertRaisesRegex(OwnerRecipeError, "LOCKED"):
            make_resolved_effective_config(identity, ps, self.package, resolutions=[resolution])

        active = next(r for r in self.package["ParameterProjection"] if r["role"] == "TUNABLE")
        invented_lock = {
            "parameter_pid": active["parameter_pid"], "parameter": active["parameter"],
            "state": LOCKED, "effective_value": "INVENTED_DEFAULT", "reason": "OWNER_DEFAULT",
        }
        with self.assertRaisesRegex(OwnerRecipeError, "package-derived"):
            make_resolved_effective_config(identity, ps, self.package, resolutions=[invented_lock])

    def test_package_locked_row_without_a_value_blocks_closed(self):
        ps = self._parameter_set()
        package = copy.deepcopy(self.package)
        locked = next(
            row for row in package["ParameterProjection"]
            if row["parameter"] == "FirstLotMode"
        )
        locked["locked_value"] = None
        self._reidentify_package(package)
        identity = self._identity(ps, package_id=package["PackageID"])

        effective = make_resolved_effective_config(identity, ps, package)
        recipe = make_owner_recipe(
            identity, effective, parameter_set=ps, package=package
        )
        control = next(
            row for row in effective["Controls"]
            if row["parameter"] == "FirstLotMode"
        )
        self.assertEqual(control["state"], SEMANTICS_REQUIRED)
        self.assertEqual(control["reason"], "PACKAGE_LOCKED_VALUE_MISSING")
        self.assertIsNone(control["effective_value"])
        self.assertEqual(recipe["Status"], "BLOCKED_SEMANTICS_REQUIRED")

    def test_parameter_set_tamper_and_identity_join_mismatch_refuse(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        tampered = copy.deepcopy(ps)
        tampered["parameters"]["_0_ATR_Period"] = "tampered"
        with self.assertRaisesRegex(OwnerRecipeError, "snapshot hash mismatch"):
            make_resolved_effective_config(identity, tampered, self.package)
        other = self._parameter_set(lambda p: p.__setitem__("_0_ATR_Period", "other"))
        with self.assertRaisesRegex(OwnerRecipeError, "ParameterSetID mismatch"):
            make_resolved_effective_config(identity, other, self.package)

    def test_package_identity_mismatch_refuses(self):
        ps = self._parameter_set()
        identity = self._identity(ps, package_id=None)
        bad_identity = dict(identity)
        bad_identity["FamilyID"] = "B13"
        with self.assertRaisesRegex(OwnerRecipeError, "IdentityProjection validation failed"):
            make_resolved_effective_config(bad_identity, ps, self.package)

        missing_ref = self._identity(ps, package_id=None)
        with self.assertRaisesRegex(OwnerRecipeError, "PackageID.*required"):
            make_resolved_effective_config(missing_ref, ps, self.package)

        wrong_ref = self._identity(ps, package_id="VPKG-" + "b" * 24)
        with self.assertRaisesRegex(OwnerRecipeError, "PackageID mismatch"):
            make_resolved_effective_config(wrong_ref, ps, self.package)

        wrong_hypothesis = self._identity(ps, hypothesis_revision="B14-H99-r1")
        with self.assertRaisesRegex(OwnerRecipeError, "HypothesisRevision mismatch"):
            make_resolved_effective_config(wrong_hypothesis, ps, self.package)

    def test_family_and_resolution_reference_mismatch_refuse(self):
        ps = self._parameter_set()
        identity = make_identity_projection(
            family_id="B13", logical_variant_id="B13-TESTFIXTURE",
            hypothesis_revision=self.package["hypothesis_revision"],
            home_contract_id="HOME-" + "b" * 20,
            parameter_set_id=ps["ParameterSetID"], package_id=None,
        )
        with self.assertRaisesRegex(OwnerRecipeError, "FamilyID mismatch"):
            make_resolved_effective_config(identity, ps, self.package)
        good_identity = self._identity(ps)
        resolution = {
            "parameter_pid": 999999, "parameter": "NoSuchParameter",
            "state": IGNORED, "effective_value": None, "reason": "EXPLICIT_FIXTURE",
        }
        with self.assertRaisesRegex(OwnerRecipeError, "does not match"):
            make_resolved_effective_config(good_identity, ps, self.package, resolutions=[resolution])

    def test_recipe_and_control_schema_tamper_refuse(self):
        identity, ps, effective, recipe = self._build()
        resolutions = self._effective_resolutions(ps)
        bad_recipe = copy.deepcopy(recipe)
        bad_recipe["Identity"]["extra"] = "nope"
        with self.assertRaisesRegex(OwnerRecipeError, "Identity fields"):
            validate_owner_recipe(
                bad_recipe,
                identity=identity,
                effective_config=effective,
                parameter_set=ps,
                package=self.package,
                resolutions=resolutions,
            )
        bad_effective = copy.deepcopy(effective)
        bad_effective["Controls"][0]["extra"] = "nope"
        with self.assertRaisesRegex(OwnerRecipeError, "control fields"):
            validate_resolved_effective_config(
                bad_effective,
                identity=identity,
                parameter_set=ps,
                package=self.package,
                resolutions=resolutions,
            )
    def test_effective_override_must_equal_requested_value(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        target = next(r for r in self.package["ParameterProjection"] if r["parameter"] == "_0_ATR_Period")
        resolution = {
            "parameter_pid": target["parameter_pid"], "parameter": target["parameter"],
            "state": EFFECTIVE, "effective_value": "FAKE", "reason": "EXPLICIT_EFFECTIVE",
        }
        with self.assertRaisesRegex(OwnerRecipeError, "cannot fake"):
            make_resolved_effective_config(identity, ps, self.package, resolutions=[resolution])

        numeric_ps = self._parameter_set(
            lambda params: params.__setitem__("_0_ATR_Period", 1)
        )
        numeric_identity = self._identity(numeric_ps)
        type_confused = {
            **resolution,
            "effective_value": True,
        }
        with self.assertRaisesRegex(OwnerRecipeError, "cannot fake"):
            make_resolved_effective_config(
                numeric_identity,
                numeric_ps,
                self.package,
                resolutions=[type_confused],
            )

    def test_unresolved_alias_cannot_produce_recipe(self):
        alias_catalog = json.loads(
            (ROOT / "factory/vnext/identity_aliases.json").read_text(encoding="utf-8")
        )
        alias = next(row for row in alias_catalog["Aliases"] if row["FamilyID"] == "B14")
        self.assertEqual(alias["ResolutionStatus"], "SEMANTICS_REQUIRED")
        ps = self._parameter_set()
        identity = self._identity(ps, legacy_alias_ids=[alias["AliasID"]])
        with self.assertRaisesRegex(OwnerRecipeError, "SEMANTICS_REQUIRED / unresolved"):
            make_resolved_effective_config(
                identity, ps, self.package, repo_root=str(ROOT)
            )
        with self.assertRaisesRegex(OwnerRecipeError, "require repo_root"):
            make_resolved_effective_config(identity, ps, self.package)

    def test_exact_input_schemas_and_duplicate_projection_identity_refuse(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        with self.assertRaisesRegex(OwnerRecipeError, "VariantBuildPackage fields"):
            make_resolved_effective_config(
                identity, ps, {**self.package, "FriendlyName": "not identity"}
            )
        with self.assertRaisesRegex(OwnerRecipeError, "ParameterSet fields"):
            make_resolved_effective_config(
                identity, {**ps, "FriendlyName": "not identity"}, self.package
            )

        duplicate_pid = copy.deepcopy(self.package)
        duplicate_pid["ParameterProjection"].append(
            {**duplicate_pid["ParameterProjection"][0], "parameter": "DuplicatePid"}
        )
        with self.assertRaisesRegex(OwnerRecipeError, "duplicate ParameterProjection parameter_pid"):
            make_resolved_effective_config(identity, ps, duplicate_pid)

        duplicate_name = copy.deepcopy(self.package)
        duplicate_name["ParameterProjection"].append(
            {**duplicate_name["ParameterProjection"][0], "parameter_pid": 999999}
        )
        with self.assertRaisesRegex(OwnerRecipeError, "duplicate ParameterProjection parameter"):
            make_resolved_effective_config(identity, ps, duplicate_name)

        unknown_projection_field = copy.deepcopy(self.package)
        unknown_projection_field["ParameterProjection"][0]["OwnerDefault"] = 14
        with self.assertRaisesRegex(OwnerRecipeError, "ParameterProjection row fields"):
            make_resolved_effective_config(identity, ps, unknown_projection_field)

        unsupported_projection = copy.deepcopy(self.package)
        unsupported_projection["ParameterProjection"][0]["role"] = "UNKNOWN"
        with self.assertRaisesRegex(OwnerRecipeError, "role/projection"):
            make_resolved_effective_config(identity, ps, unsupported_projection)

    def test_resolution_rows_must_be_deterministically_sorted(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        resolutions = self._effective_resolutions(ps)
        self.assertGreaterEqual(len(resolutions), 2)
        reversed_rows = list(reversed(resolutions))
        with self.assertRaisesRegex(OwnerRecipeError, "deterministically sorted"):
            make_resolved_effective_config(
                identity, ps, self.package, resolutions=reversed_rows
            )

    def test_resolution_reasons_are_machine_codes(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        target = next(
            row for row in self.package["ParameterProjection"]
            if row["role"] == "TUNABLE"
        )
        resolution = {
            "parameter_pid": target["parameter_pid"],
            "parameter": target["parameter"],
            "state": IGNORED,
            "effective_value": None,
            "reason": "free form reason",
        }
        with self.assertRaisesRegex(OwnerRecipeError, "machine reason code"):
            make_resolved_effective_config(
                identity, ps, self.package, resolutions=[resolution]
            )

    def test_source_bound_validation_rejects_tampering_even_with_rehashed_outputs(self):
        identity, ps, effective, recipe = self._build()
        fake_effective = copy.deepcopy(effective)
        locked = next(
            row for row in fake_effective["Controls"]
            if row["state"] == LOCKED
        )
        locked["effective_value"] = "INVENTED_OWNER_DEFAULT"
        self._reidentify_effective(fake_effective)
        with self.assertRaisesRegex(OwnerRecipeError, "source facts"):
            validate_resolved_effective_config(
                fake_effective,
                identity=identity,
                parameter_set=ps,
                package=self.package,
                resolutions=self._effective_resolutions(ps),
            )

        paired_forgery = copy.deepcopy(effective)
        tunable = next(
            row for row in paired_forgery["Controls"]
            if row["state"] == EFFECTIVE
        )
        tunable["requested_value"] = "FORGED_PAIR"
        tunable["effective_value"] = "FORGED_PAIR"
        self._reidentify_effective(paired_forgery)
        with self.assertRaisesRegex(OwnerRecipeError, "source facts"):
            validate_resolved_effective_config(
                paired_forgery,
                identity=identity,
                parameter_set=ps,
                package=self.package,
                resolutions=self._effective_resolutions(ps),
            )

        expanded_recipe = copy.deepcopy(recipe)
        expanded_recipe["Identity"]["FriendlyName"] = "not identity"
        with self.assertRaisesRegex(OwnerRecipeError, "Identity fields"):
            validate_owner_recipe(
                expanded_recipe,
                identity=identity,
                effective_config=effective,
                parameter_set=ps,
                package=self.package,
                resolutions=self._effective_resolutions(ps),
            )

        recipe["Controls"][0]["reason"] = "MUTATED_RECIPE_COPY"
        self.assertNotEqual(
            recipe["Controls"][0]["reason"], effective["Controls"][0]["reason"]
        )

    def test_tunable_without_explicit_resolution_stays_semantics_required(self):
        ps = self._parameter_set()
        identity = self._identity(ps)

        effective = make_resolved_effective_config(identity, ps, self.package)

        tunable = next(
            row for row in effective["Controls"] if row["role"] == "TUNABLE"
        )
        self.assertEqual(tunable["state"], SEMANTICS_REQUIRED)
        self.assertEqual(tunable["reason"], "EXPLICIT_RESOLUTION_REQUIRED")
        self.assertIsNone(tunable["effective_value"])
        self.assertEqual(effective["Blockers"][0]["reason"], "EXPLICIT_RESOLUTION_REQUIRED")

    def test_owner_recipe_constructor_rejects_rehashed_fake_effective_facts(self):
        identity, ps, effective, _ = self._build()
        fake = copy.deepcopy(effective)
        target = next(row for row in fake["Controls"] if row["state"] == EFFECTIVE)
        target["state"] = IGNORED
        target["effective_value"] = None
        target["reason"] = "FORGED_INACTIVE"
        fake["Blockers"] = []
        payload = {
            key: fake[key]
            for key in (
                "IdentityProjectionID", "FamilyID", "LogicalVariantID",
                "HypothesisRevision", "ProfileID", "ParameterSetID",
                "ParameterSnapshotSHA256", "PackageID", "Controls", "Blockers",
                "LotProgressionSemantics",
            )
        }
        fake["ResolvedEffectiveConfigSHA256"] = __import__("hashlib").sha256(
            __import__("json").dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        fake["ResolvedEffectiveConfigID"] = stable_id(
            "RECFG", payload, hex_chars=24
        )

        with self.assertRaisesRegex(OwnerRecipeError, "source facts"):
            make_owner_recipe(
                identity,
                fake,
                parameter_set=ps,
                package=self.package,
                resolutions=self._effective_resolutions(ps),
            )

    def test_unknown_variant_package_fields_refuse_at_owner_recipe_seam(self):
        ps = self._parameter_set()
        identity = self._identity(ps)
        expanded = {**self.package, "OwnerDefault": "INVENTED"}

        with self.assertRaisesRegex(OwnerRecipeError, "VariantBuildPackage fields"):
            make_resolved_effective_config(identity, ps, expanded)

    def test_package_and_hypothesis_references_must_match_resolved_identity(self):
        ps = self._parameter_set()
        missing_package_ref = self._identity(ps, package_id=None)
        with self.assertRaisesRegex(OwnerRecipeError, "PackageID.*(?:required|mismatch)"):
            make_resolved_effective_config(missing_package_ref, ps, self.package)

        wrong_package_ref = self._identity(
            ps, package_id="VPKG-" + "0" * 24
        )
        with self.assertRaisesRegex(OwnerRecipeError, "PackageID mismatch"):
            make_resolved_effective_config(wrong_package_ref, ps, self.package)

        wrong_hypothesis = self._identity(
            ps, hypothesis_revision="B14-H99-r1"
        )
        with self.assertRaisesRegex(OwnerRecipeError, "HypothesisRevision mismatch"):
            make_resolved_effective_config(wrong_hypothesis, ps, self.package)


if __name__ == "__main__":
    unittest.main(verbosity=2)
