# -*- coding: utf-8 -*-
import copy
import csv
import io
import os
import subprocess
from contextlib import contextmanager
import hashlib
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))

from _triage.factory_vnext.contracts import make_parameter_set, stable_id
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


    @contextmanager
    def _owner_fixture(self, rows=None, raw=None, use_tree=False):
        """Real disposable Git objects; these are synthetic ownership fixtures."""
        from _triage.factory_os.registry import PARAM_REGISTRY_REQUIRED_HEADERS
        if rows is None:
            rows = self._owner_rows()
        if raw is None:
            buffer = io.StringIO(newline="")
            writer = csv.DictWriter(buffer, fieldnames=PARAM_REGISTRY_REQUIRED_HEADERS)
            writer.writeheader()
            writer.writerows(rows)
            raw = buffer.getvalue().encode("utf-8")
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            fixture_env = dict(
                os.environ, GIT_AUTHOR_NAME="Owner Fixture",
                GIT_AUTHOR_EMAIL="fixture@example.invalid",
                GIT_COMMITTER_NAME="Owner Fixture",
                GIT_COMMITTER_EMAIL="fixture@example.invalid",
                GIT_AUTHOR_DATE="2020-01-01T00:00:00+00:00",
                GIT_COMMITTER_DATE="2020-01-01T00:00:00+00:00",
            )

            def git(*args, data=None):
                return subprocess.run(
                    ["git", "-C", str(root), *args], input=data,
                    capture_output=True, check=True, env=fixture_env, timeout=10,
                ).stdout.strip().decode("ascii")

            git("init", "-q")
            blob = git("hash-object", "-w", "--stdin", data=raw)
            docs = git("mktree", data=("100644 blob %s\tPARAM_REGISTRY.csv\n" % blob).encode())
            tree = git("mktree", data=("040000 tree %s\tdocs\n" % docs).encode())
            commit = git("-c", "commit.gpgsign=false", "commit-tree", tree, data=b"synthetic owner fixture\n")
            reference = {
                "commit": tree if use_tree else commit,
                "path": "docs/PARAM_REGISTRY.csv",
                "sha256": hashlib.sha256(raw).hexdigest(),
            }
            package = copy.deepcopy(self.package)
            package["source_commit"] = reference["commit"]
            package["PackageID"] = stable_id(
                "VPKG", {k: v for k, v in package.items()
                         if k not in {"schema_version", "authority", "PackageID"}},
                hex_chars=24,
            )
            yield root, self._source_bundle(package=package), reference

    def _owner_rows(self):
        from _triage.factory_os.registry import PARAM_REGISTRY_REQUIRED_HEADERS
        rows = []
        for parameter in self.package["ParameterProjection"]:
            row = {key: "SYNTHETIC_FIXTURE" for key in PARAM_REGISTRY_REQUIRED_HEADERS}
            row.update(
                name=parameter["parameter"], parameter_pid=parameter["parameter_pid"],
                owner="FixtureOwner.mqh", classification="ACTIVE",
            )
            rows.append(row)
        return rows

    def _owner_view(self, root, source, reference):
        return make_owner_recipe_presentation(
            [source], repo_root=str(root), source_owner_source=reference,
        )

    @staticmethod
    def _rehash_owner_view(record):
        payload = {key: record[key] for key in ("authority", "scope", "Recipes", "SourceOwnerSource")}
        raw = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
        record["OwnerRecipePresentationSHA256"] = hashlib.sha256(raw).hexdigest()
        record["OwnerRecipePresentationID"] = stable_id("ORVIEW", payload, hex_chars=24)

    def test_default_output_retains_frozen_prechange_bytes(self):
        source = self._source_bundle()
        raw = serialize_owner_recipe_presentation(
            make_owner_recipe_presentation([source]), sources=[source],
        )
        self.assertEqual(
            hashlib.sha256(raw).hexdigest(),
            "a1356596ad971d2e83d6d9292a428b3f5b35a1c91a84968bc45b4978f7073623",
        )

    def test_source_owner_enrichment_is_deterministic_and_roundtrips(self):
        with self._owner_fixture() as (root, source, reference):
            plain = make_owner_recipe_presentation([source])
            view = self._owner_view(root, source, reference)
            self.assertEqual(view, self._owner_view(root, source, reference))
            self.assertEqual(view["SourceOwnerSource"], reference)
            self.assertEqual(view["Recipes"][0]["ExactReferences"], plain["Recipes"][0]["ExactReferences"])
            for control in view["Recipes"][0]["Controls"]:
                owner = control["SourceOwner"]
                self.assertEqual(owner["State"], "DECLARED")
                self.assertEqual(owner["Owner"], "FixtureOwner.mqh")
                self.assertEqual(owner["Source"], reference)
                self.assertGreaterEqual(owner["RegistryLine"], 2)
            raw = serialize_owner_recipe_presentation(
                view, sources=[source], repo_root=str(root), source_owner_source=reference,
            )
            self.assertEqual(json.loads(raw), view)
            self.assertTrue(raw.endswith(b"\n"))
            with self.assertRaises(OwnerRecipePresentationError):
                validate_owner_recipe_presentation(view, sources=[source])

    def test_source_owner_build_specific_row_wins_without_cross_build_guessing(self):
        rows = self._owner_rows()
        override = copy.deepcopy(rows[0])
        override["name"] += "[" + self.package["build_tag"] + "]"
        override["owner"] = "BuildSpecificFixture.mqh"
        rows.append(override)
        with self._owner_fixture(rows=rows) as (root, source, reference):
            owner = self._owner_view(root, source, reference)["Recipes"][0]["Controls"][0]["SourceOwner"]
            self.assertEqual(owner["Owner"], "BuildSpecificFixture.mqh")
            self.assertEqual(owner["RegistryName"], override["name"])

    def test_missing_source_owner_stays_unknown_and_preserves_config_state(self):
        rows = self._owner_rows()[1:]
        with self._owner_fixture(rows=rows) as (root, source, reference):
            plain = make_owner_recipe_presentation([source])
            control = self._owner_view(root, source, reference)["Recipes"][0]["Controls"][0]
            self.assertEqual(control["State"], plain["Recipes"][0]["Controls"][0]["State"])
            self.assertEqual(control["SourceOwner"]["State"], "UNKNOWN")
            self.assertIsNone(control["SourceOwner"]["Owner"])
            self.assertIsNone(control["SourceOwner"]["RegistryLine"])
            self.assertEqual(control["SourceOwner"]["Reason"], "REGISTRY_PARAMETER_MISSING")

    def test_unknown_registry_owner_cannot_become_declared(self):
        for owner in ("", "UNKNOWN"):
            rows = self._owner_rows()
            rows[0]["owner"] = owner
            with self.subTest(owner=owner), self._owner_fixture(rows=rows) as (root, source, reference):
                control = self._owner_view(root, source, reference)["Recipes"][0]["Controls"][0]
                self.assertEqual(control["SourceOwner"]["State"], "UNKNOWN")
                self.assertIsNone(control["SourceOwner"]["Owner"])
                self.assertEqual(control["SourceOwner"]["Reason"], "REGISTRY_OWNER_UNKNOWN")

    def test_provenance_does_not_resolve_blocked_semantics_or_fill_missing_evidence(self):
        with self._owner_fixture() as (root, source, reference):
            source["Resolutions"] = []
            identity = source["IdentityProjection"]
            source["IdentityProjection"] = make_identity_projection(
                family_id=identity["FamilyID"], logical_variant_id=identity["LogicalVariantID"],
                hypothesis_revision=identity["HypothesisRevision"], home_contract_id=identity["HomeContractID"],
                parameter_set_id=identity["ParameterSetID"], package_id=identity["PackageID"],
            )
            row = self._owner_view(root, source, reference)["Recipes"][0]
            self.assertEqual(row["Status"], "BLOCKED_SEMANTICS_REQUIRED")
            self.assertIsNone(row["ExactReferences"]["BuildReceipt"])
            self.assertIsNone(row["ExactReferences"]["RunID"])
            blocked = [c for c in row["Controls"] if c["State"] == SEMANTICS_REQUIRED]
            self.assertTrue(blocked)
            self.assertTrue(all(c["Effective"] is None for c in blocked))
            self.assertTrue(all(c["SourceOwner"]["State"] == "DECLARED" for c in blocked))

    def test_source_owner_context_rejects_stale_hash_commit_path_and_extra_fields(self):
        with self._owner_fixture() as (root, source, reference):
            bad_refs = [
                dict(reference, sha256="0" * 64),
                dict(reference, commit="0" * 40),
                dict(reference, commit="HEAD"),
                dict(reference, path="../docs/PARAM_REGISTRY.csv"),
                dict(reference, path="ea_template/core/Inputs.mqh"),
                dict(reference, path="C:/outside.csv"),
                dict(reference, Owner="CallerSuppliedOwner"),
            ]
            for bad in bad_refs:
                with self.subTest(bad=bad), self.assertRaises(OwnerRecipePresentationError):
                    self._owner_view(root, source, bad)
            with self.assertRaises(OwnerRecipePresentationError):
                make_owner_recipe_presentation([source], source_owner_source=reference)

    def test_source_owner_rejects_noncommit_and_unavailable_git_root(self):
        with self._owner_fixture(use_tree=True) as (root, source, reference):
            with self.assertRaisesRegex(OwnerRecipePresentationError, "Git commit"):
                self._owner_view(root, source, reference)
        with self._owner_fixture() as (_, source, reference), tempfile.TemporaryDirectory() as empty:
            with self.assertRaisesRegex(OwnerRecipePresentationError, "Git reference is unavailable"):
                self._owner_view(pathlib.Path(empty), source, reference)

    def test_registry_pid_mismatch_duplicate_and_malformed_csv_are_refused(self):
        wrong_pid = self._owner_rows()
        wrong_pid[0]["parameter_pid"] += 1
        duplicate = self._owner_rows()
        duplicate.append(copy.deepcopy(duplicate[0]))
        for rows in (wrong_pid, duplicate):
            with self.subTest(rows=rows), self._owner_fixture(rows=rows) as (root, source, reference):
                with self.assertRaises(OwnerRecipePresentationError):
                    self._owner_view(root, source, reference)
        with self._owner_fixture(raw=b"name,owner\nbroken,row\n") as (root, source, reference):
            with self.assertRaisesRegex(OwnerRecipePresentationError, "registry is invalid"):
                self._owner_view(root, source, reference)

    def test_committed_registry_identity_is_used_instead_of_uncommitted_file(self):
        with self._owner_fixture() as (root, source, reference):
            path = root / "docs/PARAM_REGISTRY.csv"
            path.parent.mkdir()
            path.write_text("uncommitted caller owner", encoding="utf-8")
            control = self._owner_view(root, source, reference)["Recipes"][0]["Controls"][0]
            self.assertEqual(control["SourceOwner"]["Owner"], "FixtureOwner.mqh")

    def test_rehashed_owner_forgery_and_unknown_fields_are_refused(self):
        with self._owner_fixture() as (root, source, reference):
            view = self._owner_view(root, source, reference)
            for field, value in (("Owner", "FORGED"), ("RegistryName", "WRONG"), ("RegistryLine", 999)):
                forged = copy.deepcopy(view)
                forged["Recipes"][0]["Controls"][0]["SourceOwner"][field] = value
                self._rehash_owner_view(forged)
                with self.subTest(field=field), self.assertRaises(OwnerRecipePresentationError):
                    validate_owner_recipe_presentation(
                        forged, sources=[source], repo_root=str(root), source_owner_source=reference,
                    )
            forged = copy.deepcopy(view)
            forged["Recipes"][0]["Controls"][0]["SourceOwner"]["RuntimeAuthority"] = True
            with self.assertRaisesRegex(OwnerRecipePresentationError, "SourceOwner fields"):
                validate_owner_recipe_presentation(
                    forged, sources=[source], repo_root=str(root), source_owner_source=reference,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
