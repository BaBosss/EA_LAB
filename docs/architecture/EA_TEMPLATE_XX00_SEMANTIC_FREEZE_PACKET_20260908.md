# EA Template `xx-00` Semantic Freeze Packet — 2026-09-08

Status: `PARTIAL_OWNER_RATIFICATION / SEMANTICS_REQUIRED / NO IMPLEMENTATION AUTHORITY`

Purpose: present only the four unresolved owner decisions required before an `xx-00` entry-family reference can be specified. This packet records no decision, creates no logical-child mapping, and authorizes no implementation.
## Owner partial ratification — 2026-09-09

The owner ratifies the following as `xx-00` **research/reference defaults only**, not universal runtime defaults and not implementation authority:

- `StackMode = STACK_GRID_AGAINST` as the generic reference starting mode. A family may use another mode when its strategy hypothesis requires it; that family-specific choice must be explicit.
- Stack distance uses ATR and reference multiplier `2.0`. ATR timeframe/period/source remain explicit per-family fields because the owner states they depend on timeframe and strategy; no family value is inferred here.
- `StackConfirm = CONF_DISTANCE` as the generic reference starting confirmation. A later prospective experiment may compare stronger confirmation modes only under a preregistered direct consumer; DD observed after the fact is not itself tuning authority.
- Reference Exit starts `ATR_BASED`. A family-native exit may override it when changing the exit would change the strategy hypothesis; the exception must be explicit.
- Proposed `SL = 10%` is ratified as `BASKET_BALANCE_STOP` concept: an EA-owned basket is protected by a 10%-of-account-balance money stop and the basket is closed on breach. The existing shared implementation computes the percent from current `ACCOUNT_BALANCE` and naturally resets basket-cycle state when flat; whether `xx-00` should bind exactly that current-balance timing or a frozen basket-start balance remains explicit until owner-ratified, and no runtime/default change follows from this packet.
- Native-mechanic rule is ratified: a mechanic may be part of a family's `xx-00` only when removing it changes what the entry/strategy hypothesis means. Exact Bxx -> mechanic mappings remain to be source-mapped and ratified; current code is not authority to auto-grant an exception.

Status after this ratification remains `PARTIAL_OWNER_RATIFICATION / SEMANTICS_REQUIRED / NO IMPLEMENTATION AUTHORITY` until the per-family ATR binding, exact native-mechanic map, and the remaining SL timing detail are explicit.

## Canonical grounding and current boundary

This packet is grounded in:

- `ea_template/PRODUCT_CONCEPT.md`, especially §§5-7, 10-11, 13-14;
- `ea_template/IMPLEMENTATION_COVERAGE_MAP.md`, especially the `xx-00`, Stack, Exit, SL, native-mechanic, runtime-hierarchy, and pyramid ownership rows;
- `docs/architecture/EA_TEMPLATE_IDENTITY_MODEL_V1.md`;
- `docs/architecture/EA_TEMPLATE_OWNER_RECIPE_V1.md`;
- `docs/architecture/EA_TEMPLATE_OWNER_RECIPE_PRESENTATION_V1.md`.

The P2 owner presentation is a repository-only `NON_AUTHORITATIVE_SIDECAR` showing `Requested -> Effective -> State -> Reason`. It does not decide semantics. Current B11-B18 H01 aliases remain `LogicalVariantID=null / ResolutionStatus=SEMANTICS_REQUIRED`; no `factory/vnext/owner_recipe_catalog.json` exists, and H01, a fixed config, Home, ParameterSet, Package, Run, build, symbol, timeframe, broker, account, result, or filename must not be interpreted as `xx-00`.

An owner answer to this packet is semantic direction only. A separate bounded downstream contract must encode any ratified answer and pass its applicable gates. Ratification does not itself prove E2E behavior and does not unlock Model 1, optimization, BWD retuning, HOLDOUT, Candidate/Grade/KINT, runtime, deployment, trading, LIVE, or risk/default changes.

## Decision 1 — `xx-00` StackConfirm baseline

Canonical question: should the reference use `SignalValid`, one exact Price Action confirmation, or an explicit family-specific rule?

Source-supported choices:

1. `SIGNAL_VALID` — an add requires the original entry signal to remain valid.
2. `PRICE_ACTION(<exact mode>)` — the owner must name the exact confirmation. Current implemented specific modes documented by the coverage map include `CLOSE_BEYOND_LEVEL` and `ENGULFING`; the generic words “Price Action” alone are not a complete freeze.
3. `FAMILY_SPECIFIC(<explicit family -> rule mapping>)` — the owner must supply every intended family mapping; choosing only the label `FAMILY_SPECIFIC` leaves the item unresolved.

`DISTANCE_ONLY`, `RETRIGGER`, or another confirmation may exist in the product/library, but the canonical unresolved `xx-00` list does not nominate it as the reference answer. For this packet those choices are `UNSUPPORTED / DO NOT INFER` unless the owner explicitly introduces and defines that direction.

No Stack distance, timeframe, period, multiplier, or numeric value is decided here.

## Decision 2 — `xx-00` Exit baseline

Canonical question: should the reference Exit be fixed-distance or ATR-based?

Source-supported choices:

1. `FIXED_DISTANCE` — use the shared fixed-target mechanism as the reference architecture.
2. `ATR_BASED` — use the shared ATR-target mechanism as the reference architecture.

The canonical sources do not freeze a TP distance, ATR timeframe/period/multiplier, or other numeric Exit value for this decision. In particular, the discussed `1.0 ATR` grid multiplier is not an Exit value and must not be transferred. `TRAIL`, `RUN_TREND`, `STRUCTURAL_TARGET`, or another implemented Exit mode is `UNSUPPORTED / DO NOT INFER` as the `xx-00` baseline in this packet unless the owner explicitly introduces a new direction.

## Decision 3 — meaning of the proposed `SL = 10%`

Canonical fact: `10%` is an unresolved owner phrase, not a ratified runtime risk/default. The sources explicitly distinguish account, basket, and per-trade meanings.

Source-named interpretations requiring owner selection and exact definition:

1. `BASKET_BALANCE_STOP` — basket-level money/percentage stop semantics. The sources do not establish the balance/equity base, reset point, included positions, or exact close action.
2. `PER_TRADE_RISK` — per-trade risk-percent sizing with a valid SL distance and instrument economics. This is not by itself a price-stop placement formula.
3. `ACCOUNT_DD_CAGE` — account-level drawdown/risk authority. If selected, implementation remains a consequential risk contract outside this packet.
4. `OTHER_OWNER_CONCEPT(<exact definition>)` — `UNSUPPORTED / DO NOT INFER` until the owner supplies the calculation base, scope, trigger, and action.

To freeze this item, the owner must state whether `10%` itself is ratified as an `xx-00` research-reference value or rejected, plus its exact meaning, calculation base, scope, trigger, and action. Any omitted field stays `SEMANTICS_REQUIRED`. Even a complete research-reference answer does not change a runtime/default value.

## Decision 4 — native-mechanic exceptions

Canonical rule: a Grid, Stack, or other mechanic may be part of a family's `xx-00` only when removing it changes what that entry hypothesis means. Each exception must be explicit; it is not a blanket permission to preserve every current owned pipeline.

The repository identifies B16 and the B19 probe as requiring a conscious exception-versus-architectural-debt decision because their owned `OnTick` paths may return before the shared orchestration. It does not prove that either qualifies. B19 is a probe, not a current B11-B18 Boss/reference alias.

The owner may answer:

- `NONE` — no family is granted an exception; or
- an explicit mapping `Bxx -> <mechanic(s)> -> <why removal changes the entry hypothesis>` for each exception.

Current sources do not supply a complete exception list or a mechanic mapping for any family. A blanket `ALL CURRENT MECHANICS`, automatic B16/B19 inclusion, or an exception inferred from current code is `UNSUPPORTED / DO NOT INFER`. If the owner chooses family-specific exceptions without a complete mapping, the item remains `SEMANTICS_REQUIRED`.

## Explicitly outside this packet

The product hierarchy remains `Risk > Hedge > Recovery > Signal/Entry`, but current shared runtime calls Recovery before Hedge and the same-tick block/cancel/unwind semantics are unresolved. Pyramid exit ownership also remains unresolved. Both stay outside this packet as separate consequential core/risk work requiring an owner-approved contract, adversarial tests, full template regression, and qualified different-family review. This packet supplies no implementation or review authority for either issue.

## Concise owner response template

Copy, complete, and ratify all four lines. Placeholders or generic labels keep that item unresolved.

```text
EA Template xx-00 semantic decisions — owner ratification

1. STACK_CONFIRM = SIGNAL_VALID | PRICE_ACTION(CLOSE_BEYOND_LEVEL|ENGULFING) | FAMILY_SPECIFIC(<complete Bxx->rule mapping>)
2. EXIT = FIXED_DISTANCE | ATR_BASED
3. SL_10_PERCENT = RATIFY_RESEARCH_REFERENCE | REJECT_PHRASE; MEANING = BASKET_BALANCE_STOP | PER_TRADE_RISK | ACCOUNT_DD_CAGE | OTHER(<exact definition>); BASE = <exact>; SCOPE = <exact>; TRIGGER = <exact>; ACTION = <exact>
4. NATIVE_MECHANIC_EXCEPTIONS = NONE | <complete Bxx->mechanics->hypothesis-necessity mapping>

I ratify these as xx-00 research/reference semantics only. They do not authorize implementation, runtime/risk/default changes, Model 1, optimization, HOLDOUT, Candidate, deployment, trading, or LIVE: YES
```

Until every applicable field is explicit and owner-ratified, status remains `OWNER_DECISION_REQUIRED / SEMANTICS_REQUIRED / NO IMPLEMENTATION AUTHORITY`.
