# Facebook-derived EA strategies V1 — design and execution route

Status: **OWNER-APPROVED STRATEGY DESIGN / NON-EXECUTABLE**
Date: 2026-09-22
Design lane: `ct-fb-derived-strategies-v1-20260922`
Design base: `94cfcaaa5f3344a7b09ca3917af7c9d6749fe8dd`
Source basis: owner-supplied Facebook screenshots only; no external source code was ingested by this lane.

## Objective

Turn the two visible concepts into explicit EA_LAB strategies without pretending that screenshot-level descriptions reveal the original authors' exact implementation.

The two frozen design identities are:

1. `FB-A01` — Adaptive Donchian Trend Flip.
2. `FB-G01` — Persistent Adaptive Donchian Grid.

The design intentionally keeps them separate for the first research cycle so their mechanisms can be measured independently. A hybrid is a later child hypothesis, not V0.

## Source-grounded facts

The screenshots support named mechanisms and architecture labels, including Donchian, SuperTrend, Adaptive ATR percentile, breakout, Stop & Reverse, anti-duplicate/WaitPositionsClosed, Percent Grid, BUY/SELL separation, Zone Clamp, Donchian filter, Anti-Churn, Auto Reset, persistent grid/snapshot state, profit target and adaptive spread handling.

The screenshots do **not** support exact original periods, formulas, thresholds, buffer values, equality rules, reset edge cases or account-adjustment semantics. Those must stay unresolved or be explicitly introduced as EA_LAB design choices in a future executable contract.

## Strategy A — FB-A01

Mechanism chain:

`closed-bar Donchian breakout -> SuperTrend direction confirm -> ATR-percentile regime gate -> single directional position -> trailing/structural exit -> close/flat-verify/reverse`

Key falsifiable questions for later research:

- Does SuperTrend confirmation reduce false Donchian breakouts without collapsing participation?
- Does the ATR-percentile gate reduce adverse entry regimes without simply deleting profitable volatility?
- Does explicit stop-and-reverse improve trend capture after regime transitions versus close-only behavior?

Do not answer these with source-code review or screenshots; they require a frozen Model-1 contract.

## Strategy G — FB-G01

Mechanism chain:

`flat cycle -> freeze anchor/spacing -> physical grid fills -> Donchian regime director -> block countertrend additions in trend state -> bounded zone clamp -> basket exit -> flat verify -> persist terminal state -> reset`

Key falsifiable questions:

- Does regime-directed blocking improve physical-grid tail behavior versus an otherwise identical two-sided grid?
- Does `max(percent spacing, ATR spacing)` improve cross-symbol scaling versus a fixed-distance comparator?
- Does persistence/restart handling preserve cycle identity without duplicate fills or false profit accounting?

## Existing-family separation

`FB-A01` must not be silently treated as `(TRD)_SuperTrendFlip` or `Boss_12_Breakout`; those families have their own historical evidence and semantics. Reuse of a Donchian or SuperTrend component is component reuse, not family identity.

`FB-G01` must not be merged into ZCAG. ZCAG's defining treatment is virtual adverse levels followed by one compressed entry. FB-G01's defining treatment is real sequential grid exposure. The same reason prevents silent mutation of B11/B14 grid semantics.

## Prospective implementation DAG

### I1 — freeze executable semantics for FB-A01

Required fields before source authoring:

- Donchian lookback and breakout equality rule;
- breakout buffer unit/formula;
- SuperTrend formula/period/multiplier/finality;
- ATR-percentile window and regime cutoffs;
- initial stop owner and trailing owner;
- spread rule;
- fixed research lot and max-position invariant;
- reversal retry/refusal behavior.

### I2 — freeze executable semantics for FB-G01

Required fields:

- cycle anchor definition;
- percent-distance formula and ATR-distance formula;
- Donchian regime transition/re-entry rules;
- max rungs/side and aggregate exposure cap;
- basket target unit;
- persistence backend/namespace/restore reconciliation;
- balance/credit discontinuity behavior;
- median-spread sample cadence/multiplier/absolute ceiling;
- anti-churn timing semantics.

### I3 — source implementation

Create **dedicated** wrappers/entry engines only after I1/I2 are frozen and a conflict-free Template-core writer lane exists. Do not allocate a Boss number or `LAB_ENTRY` from this design document alone.

Source work that can send/close orders or alter shared execution/risk/basket behavior requires the normal core-code compile, deterministic/adversarial cages and exact-frozen-head read-only GPT Scrutiny. Existing grid/trend wrappers must remain regression-clean.

Current serialization note: `ct-zcag-boss23-v0-impl-20260922` owns a pending Template-core implementation route. Its preserved ownership/WIP must be reconciled before opening an overlapping core writer for these two strategies.

### I4 — Model-1 fixed-config screen

Only after source acceptance and a separate preregistered research contract:

- use Model 1 / 1 Minute OHLC for numerical strategy judgement;
- freeze MAIN/BWD windows and Home/TF/settings in that contract;
- no optimizer before the fixed-config screen establishes interpretable participation;
- no HOLDOUT use;
- preserve grid-specific exposure/position-count/span evidence for FB-G01;
- separate mechanical failure from strategy evidence.

No performance threshold is invented by this design lane.

### I5 — mechanism children

Each child changes one logical mechanism only. Examples are confirmation ON/OFF, percentile gate ON/OFF, or regime-directed grid blocking ON/OFF. BWD remains a falsification surface, not a second optimizer.

### I6 — Model-4 fidelity

Any later Candidate route requires frozen same-lineage Model-4 MAIN+BWD on the acceptance-critical MT5 installation with exact build/set/source identity and no retuning between selected Model-1 config and Model-4.

## Hybrid — FB-H01 is deferred

The owner approved the conceptual Phase-2 hybrid:

- Trend UP -> block countertrend SELL grid additions;
- Trend DOWN -> block countertrend BUY grid additions;
- no qualified trend -> normal bounded two-sided grid.

Do **not** implement FB-H01 yet. First obtain independent, interpretable evidence for FB-A01 and FB-G01 so the hybrid does not hide which mechanism created any observed change.

## Acceptance for this design milestone

This milestone is complete only if:

- the two cards preserve screenshot-supported facts separately from EA_LAB choices;
- unresolved numeric/original-source semantics remain explicit;
- ZCAG, B11/B14, Boss_12 and SuperTrendFlip identities are not silently merged;
- no runtime/backtest/risk-default/LAB_ENTRY authority is implied;
- direct consumers and next contracts are explicit.

## Next lawful action

After review/integration of this design package, freeze I1 and I2 as separate executable implementation contracts. Source implementation may begin only when overlapping Template-core ownership is conflict-free. The first performance work is a separately frozen Model-1 MAIN+BWD contract, not an optimizer and not HOLDOUT.
