# EA Template Owner Recipe Presentation V1

Status: `ADDITIVE / NON_AUTHORITATIVE_SIDECAR / REPOSITORY_ONLY`

Purpose: render the P1 OwnerRecipe source bundle as one deterministic owner-facing Factory view without creating configuration, semantic, research, runtime, or deployment truth.

## Source contract

`_triage/factory_vnext/owner_recipe_view.py` accepts only the exact P1 source-bundle shape:

```text
IdentityProjection
ParameterSet
VariantBuildPackage
Resolutions
```

`make_owner_recipe_presentation` passes those bundles to the public P1 `make_owner_recipe_catalog` builder and then the public `validate_owner_recipe_catalog` source-bound validator. P1 therefore revalidates and rebuilds Identity, ParameterSet, package, resolved-effective configuration, recipe, blockers, and every associated ID/hash before this layer reads a field. The presentation API does not accept a prebuilt recipe or catalog as trusted input.

When `source_paths` is supplied, `repo_root` is mandatory. Paths must be unique, sorted, canonical POSIX repository-relative paths. The consumer reads each JSON file with duplicate-key and non-finite-value refusal, confines it to the supplied repository root, and requires the parsed bytes to equal the corresponding source bundle. Paths are provenance checks, not presentation identity; using path binding does not change presentation output or hashes.

Malformed or tampered P1 sources, unknown fields, duplicate recipe/identity/resolved-config IDs, invalid source joins, unresolved legacy aliases, unsupported states/reasons, non-canonical P1 resolution/component/control ordering, and source/path mismatches fail closed.

## Owner projection order

`Recipes` is sorted by:

```text
FamilyID -> LogicalVariantID -> HomeContractID -> ParameterSetID -> OwnerRecipeID
```

Each row is constructed in this owner-reading order:

1. `FamilyID`
2. `LogicalVariantID`
3. `Modules`
4. `Home`
5. `Controls` as `Requested -> Effective -> State -> Reason`
6. `ExactReferences`
7. `Blockers`
8. `Status`
9. `NextAction`

`Modules` preserves the validated package's `ActiveCapabilities` and `EnabledComponents`; it does not derive runtime applicability. `Home` carries only the P0-owned `HomeContractID` because the P1 bundle does not contain a separate Home artifact from which symbol/timeframe details could be validated. `Controls` are a lossless owner-label projection of P1 control values and deliberately omit optimizer-facing metadata.

`ExactReferences` carries the validated identities rather than inventing friendly aliases:

```text
IdentityProjectionID
HypothesisRevision
ProfileID
ParameterSetID
ParameterSnapshotSHA256
ResolvedEffectiveConfigID / ResolvedEffectiveConfigSHA256
OwnerRecipeID / OwnerRecipeSHA256
PackageID
BuildReceipt
RunID
LegacyAliasIDs
```

Null `BuildReceipt` or `RunID` remains null. The presentation does not backfill missing evidence.

## Blocked semantics and lot progression

P1 `SEMANTICS_REQUIRED` controls remain visible with `Effective=null` and their exact reason code. Any such row keeps the recipe at:

```text
Status = BLOCKED_SEMANTICS_REQUIRED
NextAction = RESOLVE_SEMANTICS_REQUIRED
```

The view never substitutes an owner-friendly default. It also preserves the two source formulas verbatim:

- `PROG_PLUS` — `ADDITIVE: firstLot + plus * level`
- `PROG_LINEAR` — `PROPORTIONAL: firstLot * (1 + factor * level)`

No current B11-B18 H01 alias is mapped to a logical child by this layer.

## Presentation identity and serialization

The projection schema is `factory-vnext-owner-recipe-presentation-v1`. Its ceiling is carried explicitly as:

```text
authority = NON_AUTHORITATIVE_SIDECAR
scope = REPOSITORY_ONLY
```

`OwnerRecipePresentationID` (`ORVIEW-<24 lowercase hex>`) and `OwnerRecipePresentationSHA256` are derived from the authority ceiling and complete ordered recipe rows, which contain the source-bound P0/P1 identities and hashes. They identify this presentation only. They do not rename, replace, or reinterpret `cfgfp-v1`, `ParameterSetID`, `ResolvedEffectiveConfigID`, `OwnerRecipeID`, build identity, or evidence identity.

`serialize_owner_recipe_presentation` first validates by rebuilding from the mandatory P1 sources, then emits canonical sorted JSON with exactly one terminal newline. `validate_owner_recipe_presentation` likewise rejects a structurally rehashed presentation if it differs from the rebuilt source projection.

## Authority ceiling and artifact status

This view makes no claim about strategy quality, Candidate, Grade, KINT, HOLDOUT, optimization, runtime correctness, deployment, trading, DEMO/LIVE, risk defaults, or promotion. `READY / CONSUME_OWNER_RECIPE` means only that the repository read model has no unresolved P1 control.

No tracked `factory/vnext/owner_recipe_catalog.json` or presentation catalog is created. Current B11-B18 aliases remain `SEMANTICS_REQUIRED`, so a real populated recipe presentation would still require explicit owner-approved logical-variant semantics and valid P1 source bundles.
