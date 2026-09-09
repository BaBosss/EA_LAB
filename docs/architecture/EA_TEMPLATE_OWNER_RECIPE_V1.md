# EA Template Owner Recipe V1

Status: `ADDITIVE / NON_AUTHORITATIVE_SIDECAR / REPOSITORY-ONLY`

Purpose: provide the owner-facing read model requested by `ea_template/PRODUCT_CONCEPT.md` without creating a second configuration truth. This layer joins already-owned Factory identity/config/package facts and makes uncertainty visible.

## Authority

This document and `_triage/factory_vnext/owner_recipe.py` do **not** change EA source, defaults, risk, runtime, MT5, deployment, strategy verdicts, Candidate/Grade/KINT, or LIVE authority. `cfgfp-v1` remains the declared input-surface + locked-constant fingerprint; it is not renamed or reinterpreted as a resolved-effective hash.

A recipe requires a valid, already-resolved Identity P0 projection. An unresolved legacy H01 alias cannot become a recipe merely because a package/config exists.

## Inputs

1. `IdentityProjection` from `identity_model.py` with explicit `LogicalVariantID`.
2. Factory `ParameterSet`, whose snapshot SHA-256 and `ParameterSetID` are recomputed.
3. Factory `VariantBuildPackage`, validated by the existing package validator.
4. Explicit resolution rows for tunable applicability. Their reasons are uppercase machine reason codes, not free-form labels. Resolution rows are canonical input and must arrive sorted by `(parameter_pid, parameter)`; P1 refuses out-of-order rows rather than silently normalizing them.

The join is fail-closed on Family, HypothesisRevision, ParameterSet and Package references. A package cannot be joined when the IdentityProjection has no matching `PackageID`. If `LegacyAliasIDs` is non-empty, the caller must supply the exact repository root; P1 loads `factory/vnext/identity_aliases.json` from that checkout through Identity P0 validation and requires every referenced alias to be `RESOLVED`, family/logical-variant/hypothesis/package consistent, and source-valid. An unresolved or absent alias refuses before recipe construction. Home/build/run references remain owned by Identity P0 and are carried into the owner recipe; this layer does not redefine Home policy. Input and output records use exact schemas: unknown fields, duplicate PID/name identities, non-canonical row ordering, unsupported role/projection pairs, and tampered IDs/hashes are refused.

## Requested -> Effective contract

Every package `ParameterProjection` row becomes one control row:

| State | Meaning | Effective value source |
| --- | --- | --- |
| `EFFECTIVE` | an explicit resolution says the requested parameter participates | exact ParameterSet value |
| `LOCKED` | Factory package freezes the control | package `locked_value` |
| `IGNORED` | an explicit applicability resolution says the request does not participate | `null`; reason is mandatory |
| `SEMANTICS_REQUIRED` | source bytes cannot prove an effective value/applicability | `null`; visible blocker |

`ACTIVE_TUNABLE` identifies Factory/optimizer exposure; it does not prove runtime precedence or applicability. Therefore every tunable row without an explicit resolution emits `SEMANTICS_REQUIRED / EXPLICIT_RESOLUTION_REQUIRED`. This includes B14 `P72000 / UseMiddlePathVeto`, whose absence from `BaselineCoverage.projection_parameter` is already quarantined by project state. A consumer may not turn that quarantineΓÇöor any other unresolved tunableΓÇöinto `EFFECTIVE` merely because the ParameterSet contains a value.

`IGNORED` and `SEMANTICS_REQUIRED` are never inferred from performance. An explicit resolution cannot override a package `LOCKED` row, and cannot invent `LOCKED` for a tunable row; that state is package-derived only. An `EFFECTIVE` resolution cannot substitute a value different from the exact requested ParameterSet value.

If a non-locked projected parameter is absent from the ParameterSet, the projection emits `SEMANTICS_REQUIRED / REQUEST_VALUE_MISSING` rather than guessing a default. If a LOCKED row lacks its package locked value, it emits `SEMANTICS_REQUIRED / PACKAGE_LOCKED_VALUE_MISSING`.

## Identity behavior

`ResolvedEffectiveConfigID` plus the full `ResolvedEffectiveConfigSHA256` are a separate deterministic identity/hash over IdentityProjection, ParameterSet profile/snapshot, Package, reason-coded Controls, blockers, and the preserved lot-progression semantics. They are deliberately not `cfgfp-v1`. The full ParameterSet profile is included because the current Factory `ParameterSetID` hashes the parameter snapshot while retaining `ProfileID` as a separate source field.

`OwnerRecipeID` plus `OwnerRecipeSHA256` bind the owner-facing Identity references, the resolved-effective identity/hash, and visible status/next action. Serializers emit canonical sorted JSON plus one terminal newline. Public validation and serialization require the IdentityProjection, ParameterSet, VariantBuildPackage, and resolution rows; they rebuild both projections and reject a rehashed output that no longer matches those sources. Structural-only validators are private and cannot produce or catalog trusted output.

Changing a numeric/config ParameterSet changes the applicable ParameterSet / resolved-config / recipe identities, but does not derive or mutate `LogicalVariantID`. Product identity still follows Identity P0: one logical child requires an explicit causal-mechanism decision.

The recipe carries:

`FamilyID / LogicalVariantID / HypothesisRevision / HomeContractID / ParameterSetID / BuildReceipt / RunID / PackageID / LegacyAliasIDs`

plus `Requested -> Effective -> State -> Reason`, blockers, status and next action.

## Lot progression naming

Owner-facing output preserves the current source semantics rather than relabeling code:

- `PROG_PLUS` = additive: `firstLot + plus * level`.
- `PROG_LINEAR` = proportional: `firstLot * (1 + factor * level)`.

This P1 does not select either mode as the `xx-00` reference.

## `xx-00` semantic input and remaining residuals

P1 does not make owner semantic decisions. The generic `xx-00` baseline is now an external canonical input owned by `EA_TEMPLATE_XX00_SEMANTIC_FREEZE_PACKET_20260908.md`: `GRID_AGAINST`, signal ATR × `2.0` on `PERIOD_CURRENT`, `DISTANCE` confirmation, `ATR_BASED` Exit, and a `BASKET_BALANCE_STOP` using `10%` of current account balance for the EA-owned basket. These remain research/reference semantics only.

P1 must still surface `SEMANTICS_REQUIRED` when a family has not explicitly resolved:

- its ATR period/source;
- its native-mechanic exception mapping and causal necessity;
- any native Stack mode/confirmation or Exit override;
- its `LogicalVariantID` / accepted legacy alias mapping.

P1 also does not decide Hedge/Recovery same-tick precedence or unwind/cancellation behavior, pyramid exit ownership, KINT, Candidate, Grade, risk/default, or runtime policy. Those remain separately contracted core/risk/governance work. A recipe projection consumes explicit resolution; it is never authority to invent one.
## Catalog contract and artifact status

No `factory/vnext/owner_recipe_catalog.json` is instantiated by P1. Current tracked B11-B18 H01 aliases remain unresolved in Identity P0, so populating a real owner catalog would require inventing logical-child semantics. The test suite uses an explicitly labelled in-memory fixture identity only; it creates no canonical family mapping.

The module nevertheless exposes deterministic `make_owner_recipe_catalog`, `validate_owner_recipe_catalog`, and `serialize_owner_recipe_catalog` seams for the direct consumer. Catalog construction accepts only exact source bundles containing `IdentityProjection`, `ParameterSet`, `VariantBuildPackage`, and `Resolutions`; it rebuilds each resolved config and recipe instead of accepting recipes on trust. Catalog validation and serialization require those same source bundles. A catalog is sorted by `OwnerRecipeID`, rejects duplicate recipe, IdentityProjection, or resolved-config identities, and carries its own `OwnerRecipeCatalogID` plus full SHA-256. Catalog assembly does not infer family, variant, configuration, quality, or promotion semantics.

A future tracked catalog may contain only validated owner recipes whose IdentityProjection is explicitly resolved and whose source references pass this contract.

## Owner UX consumer

Presentation layers may render this order:

`Family -> Logical Variant -> Effective modules/controls -> Home -> Requested/Effective/Reason -> exact config/build/evidence refs -> blockers -> next action`

They must display `BLOCKED_SEMANTICS_REQUIRED` when blockers exist and must not hide them behind a friendly default.

`READY / CONSUME_OWNER_RECIPE` means only that this read model has no unresolved control row. It is an owner-UX routing state, not a strategy-quality, Candidate, Grade, promotion, deployment, or trading verdict.
