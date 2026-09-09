# EA Template Identity Model V1

Status: `ADDITIVE / NON_AUTHORITATIVE_SIDECAR / NO RUNTIME OR RISK AUTHORITY`

This model separates product identity from research, configuration, build, and evidence identity. It does not rename, rewrite, reinterpret, or supersede any accepted Factory artifact.

## Identity layers and ownership

| Field | Meaning and owner | Must never be inferred from |
| --- | --- | --- |
| `FamilyID` | Stable causal family, normally the entry hypothesis. Existing Factory vNext `strategy_family.json` owns current family values such as `B11`. | Symbol, timeframe, parameter values, broker, account, evidence, or performance. |
| `LogicalVariantID` | Product-level child inside one family. It is assigned only by an explicit semantic decision. One logical child means one causal mechanism change. | `LegacyVariantID`, H01/HypothesisRevision, Home, ParameterSet, Package, Run, symbol, timeframe, broker, account, or performance. |
| `HypothesisRevision` | Research revision that states what was frozen or changed for an experiment. | It does not create or select a logical child. Multiple revisions may belong to one explicit logical variant. |
| `HomeContractID` | Existing Factory vNext Home reference. The Home contract owns logical symbol and execution timeframe around a concept/strategy. | A new family or logical child. |
| `ParameterSetID` | Exact numeric/configuration snapshot and profile reference from `contracts.make_parameter_set`. | A new family or logical child. A different optimized center is still configuration. |
| `BuildReceipt` | Exact compiled/source receipt reference when one exists. | Product identity. |
| `RunID` | Exact run/evidence identity from a Factory vNext run manifest when one exists. It may include physical symbol, broker-data environment, tester model, window, Home, and ParameterSet. | Product identity. |
| `PackageID` | Exact immutable Factory vNext variant-build package reference when one exists. | `LogicalVariantID`. Package identity includes source/build/package content and is not product identity. |
| `LegacyAliasIDs` | References to explicit bridge rows for accepted historical identities. | Semantic equivalence. An alias is a pointer with a resolution state, not an automatic mapping. |

Symbol, timeframe, config, broker, account, build, and evidence may all change while `LogicalVariantID` remains unchanged. Conversely, a logical child requires a causal mechanism change even if every numeric parameter remains identical.

## Normalized resolved projection

`_triage/factory_vnext/identity_model.py::make_identity_projection` accepts every identity layer explicitly and emits `factory-vnext-identity-projection-v1`:

```json
{
  "schema_version": "factory-vnext-identity-projection-v1",
  "authority": "NON_AUTHORITATIVE_SIDECAR",
  "IdentityProjectionID": "EAID-<24 lowercase hex>",
  "FamilyID": "B24",
  "LogicalVariantID": "B24-01",
  "HypothesisRevision": "B24-H02-r1",
  "HomeContractID": "HOME-<20 lowercase hex>",
  "ParameterSetID": "PARAM-<20 lowercase hex>",
  "BuildReceipt": "br-<32 lowercase hex or null>",
  "RunID": "RUN-<24 lowercase hex or null>",
  "PackageID": "VPKG-<24 lowercase hex or null>",
  "LegacyAliasIDs": []
}
```

`IdentityProjectionID` is a deterministic `stable_id` over the explicit layers and references above. It is an assembled read-model identity, not a replacement for any component ID. Changing Home, ParameterSet, hypothesis revision, build, run, package, or alias references changes the projection ID but does not mutate or derive `LogicalVariantID`.

Validation is fail-closed: the exact schema is required; Home and ParameterSet are required; optional build/evidence references must be either `null` or a valid canonical reference; IDs must be canonical; and `LogicalVariantID` must begin with its exact `FamilyID` plus `-`. Missing `LogicalVariantID` is a refusal even when H01, Home, ParameterSet, Package, or other legacy material is present.

## Conceptual `24-00` / `24-01` example

The following is vocabulary only. It declares no actual family mapping and does not instantiate `xx-00`.

- Hypothetical `FamilyID=B24` represents one entry/causal family.
- Display concept `24-00` (machine form `B24-00`) would represent that family's reference architecture only after its unresolved reference semantics are decided.
- Display concept `24-01` (machine form `B24-01`) could represent exactly one explicit causal change, such as adding one MACD filter.
- Changing `AtrPeriod=14` to `21`, changing XAUUSD/H1 to another Home, changing a broker/account profile, or producing another Package/Run does not create `24-02`. Those changes receive their own Home, ParameterSet, build, and evidence references around the explicitly held logical identity.

No existing B11-B18 H01 identifier is declared to mean `xx-00`, `xx-01`, or any other logical child by this model.

## Legacy migration and no-rewrite rule

`factory/vnext/identity_aliases.json` is the forward bridge for the currently tracked Boss B11-B18 H01 first-green variant-build packages. Each row preserves:

- source `FamilyID`;
- source `VariantID` as `LegacyVariantID`;
- `VariantSnapshotID`;
- `hypothesis_revision` as `HypothesisRevision` and `StrategyVersion` separately;
- `PackageID`;
- `BuildReceipt` and `RunID` when present (both are explicitly `null` for these package-only sources);
- repository-relative source artifact path and SHA-256.

Every current row has:

```text
LogicalVariantID = null
ResolutionStatus = SEMANTICS_REQUIRED
ReasonCode = LEGACY_H01_FIXED_CONFIG_LOGICAL_VARIANT_SEMANTICS_REQUIRED
```

The validator recomputes each source hash, validates the source variant-build package, and requires its Family, legacy Variant, snapshot, hypothesis revision, strategy version, Package, and authority fields to match the alias row. It refuses duplicate alias IDs, duplicate `(FamilyID, LegacyVariantID)` keys, duplicate source paths, unsupported fields, non-canonical ordering, and any source/hash mismatch.

`AliasID` is stable over the accepted legacy source identity and references. Resolution fields are deliberately excluded, so a later approved semantic mapping can retain the same alias identity. That later change must set `ResolutionStatus=RESOLVED`, supply an explicit family-consistent `LogicalVariantID`, use `ReasonCode=EXPLICIT_SEMANTIC_MAPPING`, regenerate `AliasCatalogID`, and leave every accepted source artifact and existing H01/VariantID/VariantSnapshotID/PackageID unchanged.

No migration may:

- rename or rewrite an accepted artifact in `factory/vnext/pilots/**`;
- copy `LegacyVariantID` into `LogicalVariantID`;
- treat H01 as `00`;
- derive a logical child from a HypothesisRevision, fixed config, Home, Package, Run, build, symbol, timeframe, broker, account, or result;
- reinterpret a historical filename as a semantic mapping.

## Consumer flow

```text
accepted legacy package
  -> validate source bytes + immutable package fields
  -> read explicit alias row
  -> SEMANTICS_REQUIRED: stop logical-variant assembly
     or
     approved explicit mapping: resolve LogicalVariantID
  -> join explicit Family + LogicalVariant + HypothesisRevision
  -> join HomeContractID + ParameterSetID
  -> attach BuildReceipt / RunID / PackageID where present
  -> validate normalized identity projection
  -> render the owner recipe/catalog read model
```

A consumer must surface the blocker rather than fill it. An unresolved alias may still be displayed as accepted legacy evidence, but it cannot be promoted to a resolved recipe identity.

## `xx-00` semantic status

This P0 still does not instantiate `xx-00`; identity assembly remains separate from product-reference semantics. The generic research/reference baseline is now owner-ratified in `docs/architecture/EA_TEMPLATE_XX00_SEMANTIC_FREEZE_PACKET_20260908.md`:

- generic Stack mode `GRID_AGAINST`;
- stack spacing = signal ATR × `2.0`, initial timeframe `PERIOD_CURRENT`; ATR period/source stays explicit rather than becoming a universal inferred value;
- generic StackConfirm `DISTANCE`;
- generic Exit `ATR_BASED`, with an explicit family-native override permitted only when changing Exit would change the strategy hypothesis;
- `SL = 10%` means `BASKET_BALANCE_STOP`: `10%` of current account balance is the EA-owned basket reference loss/drawdown amount, and breach closes that EA-owned basket rather than the whole account;
- native-mechanic rule: include a mechanic only when removing it changes the family strategy hypothesis.

What remains `SEMANTICS_REQUIRED` is family-specific applicability: exact `Bxx -> native mechanic(s) -> causal necessity`, any family ATR period/source, and any native Stack/confirmation/Exit override. Current B11-B18 H01 aliases also remain unresolved for `LogicalVariantID`; the new generic `xx-00` baseline does not turn H01 into `00` and does not resolve legacy alias semantics.

Recovery/Hedge runtime ordering is also out of scope. This identity sidecar does not infer same-tick suppression, cancellation, or unwind semantics and does not touch `ea_template/core/**`.
## Authority ceiling

All records emitted or accepted here must say `authority=NON_AUTHORITATIVE_SIDECAR`. They are deterministic identity/read-model artifacts only. They do not change current Factory policy, verdicts, optimization authority, risk/defaults, EA source, tester evidence, runtime attachment, deployment, trading, DEMO/LIVE state, Candidate/Grade/KINT status, or owner approval boundaries.

The current Factory and accepted artifacts remain authoritative in their existing scopes. A valid identity projection proves only that identity layers and source references are internally consistent; it never proves strategy quality, semantic equivalence, runtime correctness, or promotion eligibility.
