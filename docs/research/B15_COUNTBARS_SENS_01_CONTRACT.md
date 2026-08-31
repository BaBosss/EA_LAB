# B15 CountBars Timing Sensitivity 01 Contract

Status: PREREGISTERED / RESEARCH_ONLY / PRE-RESULT
Hypothesis ID: `HYP-B15-COUNTBARS-SENS-01`
Canonical base: `d302a9c0ea343a5d633c96facf76c782905b79a1`
Family/build: Boss15 / `LAB_ENTRY_15` / `Boss_15_ST03`
Conveyor stage: mechanism/local-sensitivity consumer before any Step-6 optimization contract

## Direct consumer

Determine whether the source-defined ST03 confirmation-timing dial `_15_CountBars` has portable research value across the three already-evidenced H4 homes, or whether this timing path should be PARKED without opening genetic MACD/CountBars search.

This contract grants no optimization, HOLDOUT, Candidate, DEMO, LIVE, deployment, risk/default, KINT, or Grade authority.

## Known accepted evidence - do not rediscover

- H02 fixed-config parent uses `_15_CountBars=2`, `_15_EdgeTrigger=true`, `_15_RearmBars=0`, MACD `12/26/9`.
- GBPUSD/H4 parent is the only H02 B15 dual-window PF>1 pulse: MAIN PF 1.10 / 214 trades; BWD PF 1.07 / 218 trades.
- USDJPY/H4 parent: MAIN PF 1.24 / 199 trades; BWD PF 0.97 / 204 trades.
- EURUSD/H4 parent: MAIN PF 0.96 / 206 trades; BWD PF 1.25 / 217 trades.
- BT3 + BT6 established portable mechanism value for `_15_EdgeTrigger=true`: removing the latch worsened PF on all six tested GBPUSD/USDJPY/EURUSD H4 MAIN/BWD windows and broadly increased participation/DD.
- Adjacent-timeframe B15 H02 cells are already measured and do not justify replay here.
## Source-bound intervention

Source owner: `ea_template/core/entries/Entry_ST03.mqh`.

`_15_CountBars` is the number of consecutive closed bars for which MACD main must remain above/below signal before ST03 emits the directional signal. The accepted parent is `2`.

Two prospective child variants are authorized, each as one logical parameter change from the same parent:

- `COUNT1`: `_15_CountBars: 2 -> 1`
- `COUNT3`: `_15_CountBars: 2 -> 3`

Frozen mechanics for both children:
- `_15_MacdFast=12`, `_15_MacdSlow=26`, `_15_MacdSignal=9`;
- `_15_EdgeTrigger=true`;
- `_15_RearmBars=0`;
- all exits, sizing, risk/cage, runtime selectors, and every other input byte/value remain the accepted Boss15 regression baseline.

Expected benefit: lower or higher confirmation delay may improve cross-window consistency without destroying the proven one-fire-per-state-run selectivity.
Expected cost: `COUNT1` may admit short-lived false states; `COUNT3` may reduce participation and enter later.

## New evidence matrix

Exactly 12 new Model-1 child cells on Meta5c / MT5-lane3:
| Variant | Symbol | TF | Window | Dates |
|---|---|---|---|---|
| COUNT1 | GBPUSD | H4 | MAIN | 2023-01-01..2025-12-31 |
| COUNT1 | GBPUSD | H4 | BWD | 2020-01-01..2022-12-31 |
| COUNT1 | USDJPY | H4 | MAIN | 2023-01-01..2025-12-31 |
| COUNT1 | USDJPY | H4 | BWD | 2020-01-01..2022-12-31 |
| COUNT1 | EURUSD | H4 | MAIN | 2023-01-01..2025-12-31 |
| COUNT1 | EURUSD | H4 | BWD | 2020-01-01..2022-12-31 |
| COUNT3 | GBPUSD | H4 | MAIN | 2023-01-01..2025-12-31 |
| COUNT3 | GBPUSD | H4 | BWD | 2020-01-01..2022-12-31 |
| COUNT3 | USDJPY | H4 | MAIN | 2023-01-01..2025-12-31 |
| COUNT3 | USDJPY | H4 | BWD | 2020-01-01..2022-12-31 |
| COUNT3 | EURUSD | H4 | MAIN | 2023-01-01..2025-12-31 |
| COUNT3 | EURUSD | H4 | BWD | 2020-01-01..2022-12-31 |

Tester contract: Model 1, USD 10,000, leverage 1:100, `Optimization=0`, exact accepted Boss15 EX5 identity, portable `D:\Meta 5c`. Parent cells are reused from accepted H02/BT6 evidence unless a mechanical identity check specifically requires a same-install control; no parent strategy rerun is owed merely for convenience.

HOLDOUT `2026H1` remains `UNSPENT`.

## Mechanical acceptance

Every new cell must have a fresh full-window report, expected set identity, accepted EX5/build identity, matching leverage, no truncation, and successful runner exit. A mechanical/harness/environment failure is a B/C/D blocker, not a strategy loss. All 12 authorized cells must resolve before the strategy hypothesis is classified.
## Preregistered hypothesis and falsifier

Primary statement: a one-step change in ST03 confirmation timing around the accepted parent can improve B15 H4 cross-home consistency while preserving the already-supported edge-latch mechanism.

For this experiment only, reuse the H02 **screening-pulse** definition: a home is `DUAL_POSITIVE` when its mechanically accepted MAIN PF > 1 and BWD PF > 1. This is a research-screen label only; it is not a Candidate, Grade, sample-floor, risk, or deployment bar.

Accepted parent CountBars=2 has `1/3` DUAL_POSITIVE H4 homes (GBPUSD only).

Classification after all 12 new cells resolve:
- `TIMING_PORTABILITY_IMPROVED`: either COUNT1 or COUNT3 has at least `2/3` DUAL_POSITIVE H4 homes.
- `HOME_ROTATION_ONLY`: neither child exceeds `1/3`, but a child has `1/3` on a different home than the parent.
- `TIMING_NOT_IMPROVED`: neither child exceeds parent `1/3` and no meaningful cross-home consistency gain is demonstrated.
- `UNKNOWN_MECHANICAL`: any required cell remains mechanically ineligible after the bounded execution contract.

Direct routing:
- only `TIMING_PORTABILITY_IMPROVED` may justify a **separate prospective Step-6 timing optimization/range contract**;
- `HOME_ROTATION_ONLY` or `TIMING_NOT_IMPROVED` PARKS this CountBars timing path; do not respond by widening CountBars, changing MACD periods, enabling RearmBars, disabling EdgeTrigger, or mining BWD;
- any new parameter family requires a new prospective hypothesis with its own direct consumer.

## Required evidence/report

Record each child cell PF, net, exact equity-DD field, trades, full-window/mechanical state and calendar-year split. Report parent-versus-child deltas using accepted parent evidence, keep Evidence/Interpretation/Decision separate, state `QUALITY_GRADE=UNRATIFIED`, `HOLDOUT=UNSPENT`, and leave Model4/MC as `NOT RUN` unless a later gate separately authorizes them.
