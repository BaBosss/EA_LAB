# Boss19 Evolution Ledger

Status: CANONICAL BOSS19 FAMILY EXPERIMENTAL-HISTORY OWNER
Current lineage: `19-0` only; child ideas are backlog hypotheses, not implemented variants.

## 19-0 — Boss19 Adaptive Grid

Parent: `NONE`
Role: base/reference concept.
Working verdict: `PARKED-VERIFY(user)` for the current always-on XAUUSD H1 reference configuration.
Tested home so far: **XAUUSD H1 only** for the accepted bounded validation. No full Symbol x TF concept verdict exists.

Primary evidence:
- strategy/spec: `docs/concepts/BOSS19_ADAPTIVE_TREND_GRID_SPEC.md`;
- accepted validation evidence: `docs/concepts/BOSS19_ADAPTIVE_TREND_GRID_ACCEPTANCE.md`;
- locked set: `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set`;
- set config fingerprint: `2010efefccfb4bf742df3adf9f1522dbaa061384a2f6e519348d11ede9eee7df`;
- set SHA256: `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`.

## Reference center — not a global optimum

Current STOP reference center from the old MAIN search surface:
- `StepATR = 0.30`;
- `FastMA = 20`;
- `SlowMA = 50`;
- `TP_ATR = 1.50`.

This is an **interior reference center on the searched surface**, not proof that 0.30 ATR is globally optimal or that the historical search domain was wide enough. The LIMIT branch later pressed the lower spacing boundary twice and triggered its bounded-search loop breaker.## Locked configuration facts

Extracted from the exact locked set and Boss19 source; not guessed:
- ATR period: `_0_ATR_Period=30`, D1 ATR is read from the last closed D1 bar;
- Step: `_9_StepUseATR=true`, `_9_StepATRmult=0.30`;
- Fast/Slow MA: `20 / 50`;
- TP: `_22_TP_ATRmult=1.50`;
- base lot: `_41_FixedLot=0.01`;
- UP progression factor: `_51_ProgFactor=0.50`;
- DOWN degression multiplier: `_52_ProgMult=1.30`;
- max levels: `_9_MaxLevels=5` subject to `RiskControl_MaxLevels()`;
- pending mode: `_9_PendingMode=3`;
- hard per-order lot ceiling: `RC_MaxLot=0.20`;
- `ProtectLevel=2`, `RC_PersistHalt=true`;
- `SLMode=30` (`SL_NONE` requirement enforced by Boss19);
- `StackMode=90` (`STACK_SINGLE` requirement enforced by Boss19).

### Entry / pending mechanism

Trend direction is `FastMA > SlowMA => UP`, `FastMA < SlowMA => DOWN` subject to TradeDir. Boss19 uses D1 ATR spacing.

With pending mode 3:
- UP arms BUY STOP levels **above** the current ask;
- DOWN arms SELL LIMIT levels **above** the current bid/reference;
- level `k` target is `reference +/- k * (D1_ATR * StepATR)` according to side/mode;
- current max reference-to-farthest level = `5 * 0.30 = 1.50 ATR`;
- span from L1 to L5 = `4 * 0.30 = 1.20 ATR`.

Boss19 resets an empty failed arm for a fresh reference and refuses duplicate placement through ambiguous broker state.### Lot ladder / exposure

Boss19 owns an asymmetric lot formula independent of a generic narrative:
- UP raw lot at level `k`: `0.01 * (1 + 0.50 * (k-1))`;
- DOWN raw lot at level `k`: `0.01 / 1.30^(k-1)`;
- DOWN values below broker minimum are floored to `SYMBOL_VOLUME_MIN`;
- all values then pass `RiskControl_ClampLot()` and `Exec_NormalizeLot()` using broker min/max/step.

Raw pre-broker-normalization ladder:

| Level | UP raw lot | DOWN raw lot |
|---:|---:|---:|
| L1 | 0.01000000 | 0.01000000 |
| L2 | 0.01500000 | 0.00769231 |
| L3 | 0.02000000 | 0.00591716 |
| L4 | 0.02500000 | 0.00455166 |
| L5 | 0.03000000 | 0.00350128 |

Nominal UP aggregate before broker-step rounding = **0.10 lots = 10.0x base-lot exposure**. Nominal DOWN raw sum = **0.03166241 lots = 3.166x base**, but the executable floors sub-minimum DOWN legs to broker minimum before normalization; the exact realized DOWN aggregate therefore depends on the symbol's durably observed volume min/step and must not be invented here. `RC_MaxLot=0.20` is a per-order ceiling and is above every nominal UP leg in this configuration.

### Exit asymmetry

- BUY basket: volume-weighted average entry plus `D1_ATR * 1.50`, then close all BUY positions.
- SELL positions: each leg closes individually when ask reaches `open_price - current Boss19 step`.
- Boss19 owns the pipeline and requires shared `SLMode=SL_NONE`; generic strategy exit/stack paths are not silently layered on top.
- account/risk safety gates run before new placement, and the accepted BWD flat-lot evidence records the hard DD cage firing around 25% under the existing profile.## Measured evidence

### STOP locked center — MAIN 2023-2025
- PF `4.64`;
- 100 closed trades;
- net `+4486.59`;
- equity relative DD `7.58%` (the report's maximal equity DD line is `6.62%`).

### Same locked center — BWD 2020-2022
- PF `0.34`;
- 49 closed trades;
- net `-2095.59`;
- equity relative DD `25.02%`.

The unchanged center fails both the existing BWD PF gate and current >=100-trades/window participation floor. This closes the old candidate funnel but does not prove the concept structurally dead.

### Flat-lot falsifier

The control changes only `_51_ProgFactor=0.0` and `_52_ProgMult=1.0`:
- MAIN: PF `5.78`, 97 trades, net `+3477.35`;
- BWD: PF `0.30`, 37 trades, net `-1873.43`, equity DD `25.04%`;
- existing hard DD cage fired in BWD.

Interpretation: the recent MAIN pulse is **not solely created by lot progression**, but flat sizing does not repair older-window behavior.

### LIMIT bounded-search loop breaker

The first LIMIT surface selected a lower StepATR boundary and TP upper boundary. One allowed lattice expansion moved StepATR lower bound `0.20 -> 0.15` and TP upper bound `1.75 -> 2.00`; the selected StepATR remained `0.15` on the new lower boundary. Automatic widening stopped. No global spacing optimum was established.## Current interpretation and evidence boundary

- `19-0` is **PARKED-VERIFY(user)** as an always-on XAUUSD H1 reference configuration.
- There is a strong recent-window pulse and a materially poor older BWD window.
- The flat-lot control suggests the MAIN pulse is not just progression leverage.
- Broad Symbol x TF home search has **not** been run.
- Regime affinity has **not** been established with a frozen classifier timeline.
- `StepATR=0.30` is a reference center from the historical surface, not sacred/global truth.
- HOLDOUT `2026H1` remains **UNSPENT**.
- No sensitivity, Model-4 campaign, MC, candidate packaging, DEMO attach, LIVE action, or risk/default change is implied by this ledger.

## Next research

Next: **19-0 Broad Matrix -> Regime Affinity**, using fixed configuration and MAIN+BWD only, after Hermes H1 qualification.

Backlog child hypotheses (not implemented, not pre-approved ranges):
- pullback qualification;
- breakout entry/mode;
- shorter/scalping TP;
- MACD alignment;
- Kaufman ER;
- ADX/trend strength;
- volatility regime gate;
- HTF confirmation;
- MA slope;
- distance-from-MA.

Any child must follow `docs/research/EA_RND_PROTOCOL.md`: explicit parent, one logical change, preregistered hypothesis, frozen mechanics, exact evidence contract. A child may branch from `19-0` rather than inherit a rejected sibling.

## Grade state

Recovered Factory vNext architecture defines separate `VERDICT`, `QUALITY_GRADE`, `EVIDENCE_CONFIDENCE`, and `BUILD_POTENTIAL` axes, but the threshold/mapping layer is still provisional. The legacy Boss19 `★★★` display is not an authoritative `QUALITY_GRADE` mapping. Until a ratified mapping exists, record Boss19 `QUALITY_GRADE = UNRATIFIED`.