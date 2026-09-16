# Arxon component readiness closeout — EA Template V2

Date: 2026-09-16
Parent at authoring: `eed2c48455cb14cb0fd16ad0f687148f332fc3cf`
Milestone scope: **STRATEGY_CARDS + SOURCE_SEMANTICS + ORDER_FREE_COMPONENT_PREP**

This is the durable answer to “prepare all Arxon tools as Strategy Cards and plan them into EA Template”. It is not a claim that 23 trading EAs exist.
All 23 component cards are already in `ea_template/strategy_cards/arxon/`. The only executable source added in this milestone is an **order-free MFI provider**; no Arxon component is wired into `LabCore` or order execution.

Readiness meanings:
- `IMPLEMENTED_ORDER_FREE`: deterministic component source exists, compile-reviewed, not a trading adapter.
- `SEMANTIC_FREEZE`: source event/mechanism is bounded, but exact provider parity still has gaps.
- `SOURCE_PARTIAL`: public mechanism is known but computation/calendar details still block exact provider parity.
- `INFRA_ONLY`: shared infrastructure, not a standalone EA family.
- `BLOCKED_VERSION_CONFLICT`: publisher versions disagree; do not choose silently.

## 1. 23-component readiness matrix
| ID | Component | Readiness | Exact next gate |
|---|---|---|---|
| W01 | VWAP / AVWAP / bands | `SOURCE_PARTIAL` | target version/source binding + variance/volume/reset parity |
| W02 | K2 ribbon / base cross | `SEMANTIC_FREEZE` | EMA source/seed/warmup/equality parity |
| W03 | Initial Balance | `SOURCE_PARTIAL` | qualified home/session clock mapping |
| W04 | TPO / Market Profile | `SOURCE_PARTIAL` | bin/POC/VA/calendar parity |
| W05 | Degrees of Power | `SOURCE_PARTIAL` | exact ordered predicates + direct consumer |
| W06 | Alerts | `INFRA_ONLY` | event namespace/restart/dedup contract |
| W07 | embedded OBV | `SOURCE_PARTIAL` | embedded config + parity to O01 if shared |
| W08 | embedded MFI | `SOURCE_PARTIAL` | embedded config + parity to O02 if shared |
| M01 | Trend Path | `SOURCE_PARTIAL` | pivot/finality + oscillator parity |
| M02 | Order Blocks / breakers | `SOURCE_PARTIAL` | bounds/lifecycle/HTF parity |
| M03 | Market Structure | `SOURCE_PARTIAL` | tie/bias/break predicate freeze |
| M04 | FVG / IFVG | `SOURCE_PARTIAL` | filter thresholds + lifecycle parity |
| M05 | Naked Key Levels | `SOURCE_PARTIAL` | period/calendar/history contract |
| M06 | Session Key Levels | `SOURCE_PARTIAL` | timezone/DST/home clock |
| M07 | D/W/M Key Levels + Fib | `SOURCE_PARTIAL` | calendar + fib recipe |
| M08 | Daily Zones | `SOURCE_PARTIAL` | daily calendar + boundary lifecycle |
| M09 | Anchor Candles | `SOURCE_PARTIAL` | exact pattern thresholds/priority |
| M10 | Session Clock | `INFRA_ONLY` | reuse qualified M06 clock contract |
| M11 | Consolidation | `SOURCE_PARTIAL` | range/ATR/grace/reconfirm parameters |
| O01 | Arxon OBV+ | `SEMANTIC_FREEZE` | slope/smoothing/divergence exact semantics |
| O02 | Arxon MFI+ | `IMPLEMENTED_ORDER_FREE` | same-feed parity; trading role still separate |
| O03 | Stochastic Dual Zone | `SEMANTIC_FREEZE` | K/D computation, equality and finality parity |
| O04 | RSI Cross Alert | `BLOCKED_VERSION_CONFLICT` | authoritative timing/version selection |

## 2. What is complete
- Six family cards and all 23 component cards are integrated into the EA Template library.
- B1 freezes standalone MFI computation semantics; Work Package C implements and compiles its order-free provider.
- B2 freezes the source-supported Stochastic same-bar dual-cross event without choosing reversal/continuation or BUY/SELL.
- B3 freezes K2 base cross as the first fast/slow EMA cross confirmed on close; EMA55/200/MTF/A2 remain separate context/features. Current canonical notes also distinguish the removed historical HTF ribbon overlay from the retained independent context surfaces.
- B4 freezes OBV high-level decomposition and preserves RSI timing as an explicit version conflict.
- B5 completes the source-bound mechanism/readiness pass for the remaining Black Tide Wave/Map components.
## 3. What is intentionally not complete
- No Arxon trading adapter, `LAB_ENTRY`, FamilyID, Factory StrategyRecord or new Template input/default is allocated by this milestone.
- No unresolved component is implemented by guessing hidden Pine details.
- No parent/home/direction/role is inferred from colors, arrows, overbought/oversold labels, trend gauges or geometry.
- No MT5 performance run, optimization, BWD retune, HOLDOUT use, Candidate, deployment or LIVE action is authorized.

## 4. EA implementation route after this closeout
1. Pick one component with its semantic gate actually resolved and one direct consumer.
2. Build a pure order-free provider first; prove deterministic fixtures and lawful same-input parity where required.
3. Only a separately approved adapter contract may map provider output to ENTRY/FILTER/EXIT and allocate identity/inputs.
4. Any `LabCore`/Inputs/PARAM_REGISTRY/core change requires applicable compile/regression cages and qualified different-family core review.
5. Research then opens prospectively with one fixed causal question, frozen home/build/config, MAIN then untouched BWD. HOLDOUT remains separate.

The existing Stochastic research lead remains `SEMANTICS_REQUIRED / NO_QUALIFIED_PARENT`; B5 does not bypass it. Closed Black Tide session research remains closed.

## 5. Milestone verdict
**ARXON STRATEGY-CARD / TEMPLATE-PREPARATION MILESTONE = COMPLETE.**
“Complete” here means the library is inventoried, source-bounded, readiness-classified and Template-reachable. It does **not** mean the whole Arxon suite is executable trading code.
Next executable work is allowed only component-by-component when its readiness gate resolves; today O02/MFI is the sole `IMPLEMENTED_ORDER_FREE` component in this Arxon package.
