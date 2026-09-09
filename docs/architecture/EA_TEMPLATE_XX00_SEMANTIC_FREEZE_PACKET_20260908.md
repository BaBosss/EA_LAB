# EA Template `xx-00` Semantic Freeze Packet — 2026-09-08

Status: `OWNER_RATIFIED_BASELINE / FAMILY_NATIVE_MAP_PENDING / NO IMPLEMENTATION AUTHORITY`

Purpose: preserve the owner-ratified generic `xx-00` research/reference baseline, keep per-family applicability/native exceptions explicit, create no logical-child mapping, and authorize no runtime/default implementation.
## Owner baseline ratification — 2026-09-09

The owner ratifies the following as `xx-00` **research/reference defaults only**, not universal runtime defaults and not implementation authority:

- `StackMode = STACK_GRID_AGAINST` as the generic reference starting mode. A family may use another mode when its strategy hypothesis requires it; that family-specific choice must be explicit.
- Stack distance uses ATR and reference multiplier `2.0`. Initial reference timeframe is `PERIOD_CURRENT`, meaning the timeframe of the test/run under evaluation. Cross-timeframe expansion is separate later research. ATR period/source remain explicit contract fields; this decision does not silently freeze one universal period for all families.
- `StackConfirm = CONF_DISTANCE` as the generic reference starting confirmation. A later prospective experiment may compare stronger confirmation modes only under a preregistered direct consumer; DD observed after the fact is not itself tuning authority.
- Reference Exit starts `ATR_BASED`. A family-native exit may override it when changing the exit would change the strategy hypothesis; the exception must be explicit.
- Proposed `SL = 10%` is ratified as `BASKET_BALANCE_STOP`: use `10%` of the **current** account balance as the reference loss/drawdown amount for the EA-owned basket; when that basket reaches the reference loss/drawdown amount, close the EA-owned basket. This is a research/reference semantic decision only and does not change any runtime/default value by itself.
- Native-mechanic rule is ratified: a mechanic may be part of a family's `xx-00` only when removing it changes what the entry/strategy hypothesis means. Exact Bxx -> mechanic mappings remain to be source-mapped and ratified; current code is not authority to auto-grant an exception.

Status after this ratification is `OWNER_RATIFIED_BASELINE / FAMILY_NATIVE_MAP_PENDING / NO IMPLEMENTATION AUTHORITY`. The generic baseline is resolved enough to define a repo-only schema. Per-family native-mechanic applicability and any family-specific ATR-period/native-exit override must still be explicit before instantiating that family reference.

## Canonical grounding and current boundary

This packet is grounded in:

- `ea_template/PRODUCT_CONCEPT.md`, especially §§5-7, 10-11, 13-14;
- `ea_template/IMPLEMENTATION_COVERAGE_MAP.md`, especially the `xx-00`, Stack, Exit, SL, native-mechanic, runtime-hierarchy, and pyramid ownership rows;
- `docs/architecture/EA_TEMPLATE_IDENTITY_MODEL_V1.md`;
- `docs/architecture/EA_TEMPLATE_OWNER_RECIPE_V1.md`;
- `docs/architecture/EA_TEMPLATE_OWNER_RECIPE_PRESENTATION_V1.md`.

The P2 owner presentation is a repository-only `NON_AUTHORITATIVE_SIDECAR` showing `Requested -> Effective -> State -> Reason`. It does not decide semantics. Current B11-B18 H01 aliases remain `LogicalVariantID=null / ResolutionStatus=SEMANTICS_REQUIRED`; no `factory/vnext/owner_recipe_catalog.json` exists, and H01, a fixed config, Home, ParameterSet, Package, Run, build, symbol, timeframe, broker, account, result, or filename must not be interpreted as `xx-00`.

An owner answer to this packet is semantic direction only. A separate bounded downstream contract must encode any ratified answer and pass its applicable gates. Ratification does not itself prove E2E behavior and does not unlock Model 1, optimization, BWD retuning, HOLDOUT, Candidate/Grade/KINT, runtime, deployment, trading, LIVE, or risk/default changes.

## Decision 1 — `xx-00` Stack / distance / confirmation baseline

**Owner resolution — 2026-09-09:**

- Generic reference `StackMode = STACK_GRID_AGAINST`.
- Generic reference spacing = signal ATR × `2.0`.
- Initial ATR timeframe = `PERIOD_CURRENT`, i.e. the timeframe of the test/run being evaluated. Cross-timeframe expansion is a later research axis, not part of this baseline.
- ATR period/source remains an explicit family/reference field; no universal period is inferred by this decision.
- Generic reference `StackConfirm = CONF_DISTANCE`.
- `SIGNAL_VALID`, `RETRIGGER`, `CLOSE_BEYOND_LEVEL`, `ENGULFING`, or future confirmations remain library alternatives. Comparing them requires a separate prospective hypothesis/range contract; observed DD after the fact is not retuning authority.
- A family may replace the generic Stack mode/distance/confirmation when that mechanic is native to the strategy hypothesis, but the family mapping must be explicit.

## Decision 2 — `xx-00` Exit baseline

**Owner resolution — 2026-09-09:** generic reference Exit = `ATR_BASED`.

This is a research/reference starting architecture, not a universal runtime default. A family-native Exit may replace it when changing the exit would change the strategy hypothesis. `FIXED_DISTANCE`, `TRAIL`, `RUN_TREND`, `STRUCTURAL_TARGET`, and other reviewed library modes remain valid alternatives, but no family override is inferred from existing defaults or historical results.

## Decision 3 — meaning of `SL = 10%`

**Owner resolution — 2026-09-09:** `SL_10_PERCENT = BASKET_BALANCE_STOP` with these semantics:

- `BASE = current ACCOUNT_BALANCE`;
- `SCOPE = the EA-owned basket`, not the whole account;
- `TRIGGER = the EA-owned basket reaches a loss/drawdown amount equal to 10% of current account balance`;
- `ACTION = close the EA-owned basket`.

This is only an `xx-00` research/reference decision. It does not define an account-wide DD action, change a deployed/default risk value, or authorize runtime implementation.

## Decision 4 — native-mechanic exceptions

**Owner rule ratified — 2026-09-09:** a Grid, Stack, structural stop, owned basket/exit path, or other mechanic may be part of a family's `xx-00` only when removing it changes what that strategy hypothesis means. Each exception must be explicit; this is not permission to preserve every current owned pipeline.

The exact `Bxx -> mechanic(s) -> why hypothesis changes if removed` mapping remains pending source-map + owner ratification. Current code may support a recommendation but cannot auto-grant an exception. B19 remains a probe, not a current B11-B18 reference family.
## Explicitly outside this packet

The product hierarchy remains `Risk > Hedge > Recovery > Signal/Entry`, but current shared runtime calls Recovery before Hedge and the same-tick block/cancel/unwind semantics are unresolved. Pyramid exit ownership also remains unresolved. Both stay outside this packet as separate consequential core/risk work requiring an owner-approved contract, adversarial tests, full template regression, and qualified different-family review. This packet supplies no implementation or review authority for either issue.

## Remaining family-resolution template

The generic baseline is ratified. Before instantiating a specific family `Bxx-00`, record only the family-specific residuals that differ from or complete the baseline:

```text
FAMILY = Bxx
ATR_PERIOD_OR_SOURCE = <explicit family reference value/source>
NATIVE_MECHANIC_EXCEPTION = NONE | <mechanic(s) + why removal changes the strategy hypothesis>
NATIVE_EXIT_OVERRIDE = NONE | <explicit mode + why ATR_BASED would change the hypothesis>
OTHER_BASELINE_OVERRIDE = NONE | <explicit StackMode/Distance/Confirm override + causal reason>

Authority = RESEARCH_REFERENCE_ONLY / NO RUNTIME_DEFAULT / NO OPTIMIZATION / NO HOLDOUT / NO CANDIDATE / NO DEPLOYMENT / NO TRADING / NO LIVE
```

Until those residuals are explicit for a family, the generic schema may be defined but that family reference must stay `SEMANTICS_REQUIRED` rather than inheriting hidden defaults.