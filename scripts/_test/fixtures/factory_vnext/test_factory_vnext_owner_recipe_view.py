# -*- coding: utf-8 -*-
import copy
import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.contracts import make_parameter_set
from _triage.factory_vnext.identity_model import make_identity_projection
from _triage.factory_vnext.owner_recipe import EFFECTIVE, SEMANTICS_REQUIRED
from _triage.factory_vnext.owner_recipe_view import (
    OwnerRecipePresentationError,
    make_owner_recipe_presentation,
    serialize_owner_recipe_presentation,
    validate_owner_recipe_presentation,
)


class FactoryVNextOwnerRecipeViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        package_path = (
            ROOT
            / "factory/vnext/pilots/boss14_h01_first_green/variant_build_package.json"
        )
        cls.package = json.loads(package_path.read_text(encoding="utf-8"))

    def _source_bundle(
        self,
        *,
        package=None,
        family_id="B14",
        logical_variant_id=None,
        home_fill="a",
        profile_id=None,
        parameter_overrides=None,
        resolutions=True,
    ):
        package = package or self.package
        parameters = {
            row["parameter"]: "REQ:%s" % row["parameter"]
            for row in package["ParameterProjection"]
        }
        parameters.update(parameter_overrides or {})
        parameter_set = make_parameter_set(
            parameters, profile_id or "PROFILE-%s-PRESENTATION" % family_id
        )
        identity = make_identity_projection(
            family_id=family_id,
            logical_variant_id=logical_variant_id or "%s-TESTFIXTURE" % family_id,
            hypothesis_revision=package["hypothesis_revision"],
            home_contract_id="HOME-" + home_fill * 20,
            parameter_set_id=parameter_set["ParameterSetID"],
            build_receipt="br-" + "b" * 32,
            run_id="RUN-" + "c" * 24,
            package_id=package["PackageID"],
        )
        resolution_rows = []
        if resolutions:
            resolution_rows = [
                {
                    "parameter_pid": row["parameter_pid"],
                    "parameter": row["parameter"],
                    "state": EFFECTIVE,
                    "effective_value": parameter_set["parameters"][row["parameter"]],
                    "reason": "EXPLICIT_TEST_APPLICABILITY",
                }
                for row in package["ParameterProjection"]
                if row["role"] == "TUNABLE"
            ]
        return {
            "IdentityProjection": identity,
            "ParameterSet": parameter_set,
            "VariantBuildPackage": package,
            "Resolutions": resolution_rows,
        }

    def test_render_is_deterministic_source_bound_and_owner_ordered(self):
        source = self._source_bundle()

        first = make_owner_recipe_presentation([source])
        second = make_owner_recipe_presentation([source])

        self.assertEqual(first, second)
        self.assertEqual(first["authority"], "NON_AUTHORITATIVE_SIDECAR")
        self.assertEqual(first["scope"], "REPOSITORY_ONLY")
        self.assertRegex(first["OwnerRecipePresentationID"], r"^ORVIEW-[0-9a-f]{24}$")
        self.assertRegex(first["OwnerRecipePresentationSHA256"], r"^[0-9a-f]{64}$")
        row = first["Recipes"][0]
        self.assertEqual(
            list(row),
            [
                "FamilyID",
                "LogicalVariantID",
                "Modules",
                "Home",
                "Controls",
                "ExactReferences",
                "Blockers",
                "Status",
                "NextAction",
            ],
        )
        self.assertEqual(row["FamilyID"], "B14")
        self.assertEqual(row["LogicalVariantID"], "B14-TESTFIXTURE")
        self.assertEqual(row["Home"], {"HomeContractID": "HOME-" + "a" * 20})
        self.assertEqual(row["Status"], "READY")
        self.assertEqual(row["NextAction"], "CONSUME_OWNER_RECIPE")
        self.assertEqual(
            row["Modules"]["LotProgressionSemantics"],
            {
                "PROG_PLUS": "ADDITIVE: firstLot + plus * level",
                "PROG_LINEAR": "PROPORTIONAL: firstLot * (1 + factor * level)",
            },
        )
        self.assertEqual(
            serialize_owner_recipe_presentation(first, sources=[source]),
            serialize_owner_recipe_presentation(second, sources=[source]),
        )
        validate_owner_recipe_presentation(first, sources=[source])

    def test_unresolved_controls_remain_visible_without_friendly_defaults(self):
        source = self._source_bundle(resolutions=False)

        presentation = make_owner_recipe_presentation([source])

        row = presentation["Recipes"][0]
        self.assertEqual(row["Status"], "BLOCKED_SEMANTICS_REQUIRED")
        self.assertEqual(row["NextAction"], "RESOLVE_SEMANTICS_REQUIRED")
        blocked = [
            control
            for control in row["Controls"]
            if control["State"] == SEMANTICS_REQUIRED
        ]
        self.assertTrue(blocked)
        self.assertTrue(all(control["Effective"] is None for control in blocked))
        self.assertTrue(
            all(control["Reason"] == "EXPLICIT_RESOLUTION_REQUIRED" for control in blocked)
        )
        self.assertEqual(
            [(item["parameter_pid"], item["parameter"]) for item in row["Blockers"]],
            [(item["ParameterPID"], item["Parameter"]) for item in blocked],
        )

    def test_projection_carries_exact_refs_without_semantic_or_quality_inference(self):
        source = self._source_bundle(resolutions=False)

        row = make_owner_recipe_presentation([source])["Recipes"][0]

        refs = row["ExactReferences"]
        identity = source["IdentityProjection"]
        parameter_set = source["ParameterSet"]
        self.assertEqual(refs["IdentityProjectionID"], identity["IdentityProjectionID"])
        self.assertEqual(refs["ParameterSetID"], parameter_set["ParameterSetID"])
        self.assertEqual(
            refs["ParameterSnapshotSHA256"],
            parameter_set["parameter_snapshot_sha256"],
        )
        self.assertEqual(refs["BuildReceipt"], identity["BuildReceipt"])
        self.assertEqual(refs["RunID"], identity["RunID"])
        self.assertEqual(refs["PackageID"], identity["PackageID"])
        self.assertEqual(
            set(row["Controls"][0]),
            {"ParameterPID", "Parameter", "Requested", "Effective", "State", "Reason"},
        )
        forbidden_fields = {
            "Candidate",
            "Grade",
            "KINT",
            "HOLDOUT",
            "OptimizationAuthority",
            "RuntimeAuthority",
            "DeploymentAuthority",
            "TradingAuthority",
            "StrategyQuality",
            "FriendlyDefault",
        }

        def keys(value):
            if isinstance(value, dict):
                return set(value).union(*(keys(item) for item in value.values()))
            if isinstance(value, list):
                return set().union(*(keys(item) for item in value), set())
            return set()

        self.assertTrue(forbidden_fields.isdisjoint(keys(row)))

    def test_tampered_source_and_prebuilt_recipe_are_refused(self):
        source = self._source_bundle()
        tampered = copy.deepcopy(source)
        first_parameter = next(iter(tampered["ParameterSet"]["parameters"]))
        tampered["ParameterSet"]["parameters"][first_parameter] = "INVENTED_DEFAULT"

        with self.assertRaisesRegex(
            OwnerRecipePresentationError, "P1 source bundle validation/build failed"
        ):
            make_owner_recipe_presentation([tampered])

        presentation = make_owner_recipe_presentation([source])
        prebuilt_recipe = presentation["Recipes"][0]
        with self.assertRaisesRegex(
            OwnerRecipePresentationError, "P1 source bundle validation/build failed"
        ):
            make_owner_recipe_presentation([prebuilt_recipe])

    def test_validation_rebuilds_from_sources_even_after_presentation_rehash(self):
        source = self._source_bundle()
        presentation = make_owner_recipe_presentation([source])
        forged = copy.deepcopy(presentation)
        forged["Recipes"][0]["Controls"][0]["Requested"] = "FORGED"
        payload = {
            "authority": forged["authority"],
            "scope": forged["scope"],
            "Recipes": forged["Recipes"],
        }
        raw = json.dumps(
            payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
        forged["OwnerRecipePresentationSHA256"] = hashlib.sha256(raw).hexdigest()
        from _triage.factory_vnext.contracts import stable_id

        forged["OwnerRecipePresentationID"] = stable_id(
            "ORVIEW", payload, hex_chars=24
        )

        with self.assertRaisesRegex(
            OwnerRecipePresentationError, "does not match supplied P1 source bundles"
        ):
            validate_owner_recipe_presentation(forged, sources=[source])

    def test_hierarchy_order_and_duplicate_identities_are_fail_closed(self):
        boss13_path = (
            ROOT
            / "factory/vnext/pilots/boss13_h01_first_green/variant_build_package.json"
        )
        boss13 = json.loads(boss13_path.read_text(encoding="utf-8"))
        source14 = self._source_bundle()
        source13 = self._source_bundle(
            package=boss13,
            family_id="B13",
            home_fill="d",
        )

        left = make_owner_recipe_presentation([source14, source13])
        right = make_owner_recipe_presentation([source13, source14])
        self.assertEqual(left, right)
        self.assertEqual(
            [row["FamilyID"] for row in left["Recipes"]], ["B13", "B14"]
        )
        with self.assertRaisesRegex(
            OwnerRecipePresentationError, "P1 source bundle validation/build failed"
        ):
            make_owner_recipe_presentation([source14, source14])

        out_of_order = copy.deepcopy(left)
        out_of_order["Recipes"].reverse()
        with self.assertRaisesRegex(
            OwnerRecipePresentationError, "hierarchy-sorted"
        ):
            validate_owner_recipe_presentation(
                out_of_order, sources=[source13, source14]
            )

    def test_unknown_fields_states_reasons_and_resolution_order_are_refused(self):
        source = self._source_bundle()
        unknown = copy.deepcopy(source)
        unknown["OwnerDefault"] = "INVENTED"
        unsupported_state = copy.deepcopy(source)
        unsupported_state["Resolutions"][0]["state"] = "DEFAULTED"
        unsupported_reason = copy.deepcopy(source)
        unsupported_reason["Resolutions"][0]["reason"] = "friendly default"
        reversed_resolutions = copy.deepcopy(source)
        reversed_resolutions["Resolutions"].reverse()

        for bad in (
            unknown,
            unsupported_state,
            unsupported_reason,
            reversed_resolutions,
        ):
            with self.subTest(bad=bad):
                with self.assertRaisesRegex(
                    OwnerRecipePresentationError,
                    "P1 source bundle validation/build failed",
                ):
                    make_owner_recipe_presentation([bad])

    def test_repository_source_path_binding_refuses_mismatch_and_noncanonical_path(self):
        source = self._source_bundle()
        with tempfile.TemporaryDirectory(dir=ROOT) as temp_dir:
            path = pathlib.Path(temp_dir) / "owner_recipe_source.json"
            path.write_text(
                json.dumps(source, ensure_ascii=False, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            relative = path.relative_to(ROOT).as_posix()
            expected = make_owner_recipe_presentation(
                [source], repo_root=str(ROOT), source_paths=[relative]
            )
            self.assertEqual(expected, make_owner_recipe_presentation([source]))

            other = self._source_bundle(
                parameter_overrides={"_0_ATR_Period": "REQ:OTHER"}
            )
            with self.assertRaisesRegex(
                OwnerRecipePresentationError, "source/path mismatch"
            ):
                make_owner_recipe_presentation(
                    [other], repo_root=str(ROOT), source_paths=[relative]
                )
            with self.assertRaisesRegex(
                OwnerRecipePresentationError, "canonical and repository-relative"
            ):
                make_owner_recipe_presentation(
                    [source], repo_root=str(ROOT), source_paths=["../escape.json"]
                )

    def test_authority_ceiling_is_immutable(self):
        source = self._source_bundle()
        presentation = make_owner_recipe_presentation([source])
        presentation["authority"] = "AUTHORITATIVE"

        with self.assertRaisesRegex(
            OwnerRecipePresentationError, "authority/scope/schema mismatch"
        ):
            validate_owner_recipe_presentation(presentation, sources=[source])


if __name__ == "__main__":
    unittest.main(verbosity=2)
