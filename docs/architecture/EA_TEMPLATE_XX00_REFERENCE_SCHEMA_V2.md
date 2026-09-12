# EA Template xx-00 Reference Schema V2

Status: `IMPLEMENTED_LOCAL / REPOSITORY_ONLY / NON_AUTHORITATIVE_SIDECAR`
Contract: `ORDER-XX00-SCHEMA-V2`
Canonical semantic input: `EA_TEMPLATE_XX00_FAMILY_RATIFICATION_V1.md`

## Purpose

V2 records an owner-ratified B11-B18 `xx-00` research/reference identity as deterministic repository metadata. It does not create an EA, parameter preset, MT5 input surface, runtime binding, deployment artifact, Candidate, or trading authority.

V2 is a fresh implementation. It does not repair, import, or promote the failed V1 implementation.

## Closed caller input

The constructor accepts exactly three arguments:

- `family_id`: one of `B11` through `B18`.
- `logical_variant_id`: exactly `<FamilyID>-00`.
- `atr_period`: a positive non-boolean integer.

There is no caller field for ATR source/timeframe, StackConfirm, native mechanics, native Exit, H01/config/Home/Package identity, executable state, runtime state, or risk/default authority.

## Frozen generic baseline

Every V2 record contains the same generic research control:

- Stack mode: `GRID_AGAINST`.
- Stack distance: `ATR x 2.0`.
- ATR timeframe: `PERIOD_CURRENT`.
- Stack confirmation: `DISTANCE`.
- generic Exit reference: `ATR_BASED`.
- basket protection: `BASKET_BALANCE_STOP`, `10.0` percent of current account balance, EA-owned basket scope.

The ATR period is intentionally not inherited from H01 or current defaults. It remains an explicit prospective input to each future family reference.

## Owner-ratified native semantics

- B11, B12, B13, B15, B18: no native override.
- B14: `GRID_STACK`, `LOG_POWER_PROGRESSION`, `BASKET_TARGET_OWNERSHIP`.
- B16: `ADVERSE_ATR_GRID`, `KANGAROO_LOT_LAW`, `OWNED_BASKET_OVERLAP_EXITS`.
- B17: `WAVE1_STRUCTURAL_INVALIDATION_SL`, `SINGLE_WHEN_STRUCTURAL`; structural target/Exit is not native-ratified.

The V2 module owns this fixed mapping. Callers cannot supply or rewrite native mechanic text.

## Fail-closed behavior

Validation requires exact top-level and nested field sets, exact authority/scope/reference-role constants, exact family/logical-ID pairing, canonical baseline values, owner-ratified native semantics, and a deterministic `FamilyReferenceID`.

V1's free-text ATR-source failure is removed structurally. V2 has no source string field. `DEFAULTATR`, `RUNTIMEATR`, `OVERRIDE`, custom timeframe values, or any extra source field are rejected as schema violations rather than interpreted.

Records also refuse caller-supplied H01/Home/Package/config/runtime/default fields, native-mechanic mutations, native-Exit mutations, executable/runtime binding, stronger StackConfirm, and deterministic-ID tampering.

## Output authority

Every record is fixed to:

- `authority = NON_AUTHORITATIVE_SIDECAR`
- `scope = REPOSITORY_ONLY`
- `reference_role = RESEARCH_CONTROL_ONLY`
- `ExecutableBinding = false`
- `RuntimeBinding = false`

No tracked B11-B18 executable `-00` instance or owner-recipe catalog is created by V2.

## Acceptance

Acceptance requires focused positive/adversarial V2 tests, the full Factory vNext focused suite, `py_compile`, `git diff --check`, clean exact HEAD, and independent docs/tooling review. Any future executable family instantiation, MT5 backtest, optimization, HOLDOUT, runtime/default change, or deployment requires a separate downstream contract.
