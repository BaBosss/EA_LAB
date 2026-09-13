---
object_type: RESEARCH_BACKTEST_BACKLOG
plan_id: PLAN-SB-ARXON-20260913
status: WAITING_FOR_PREREGISTRATION
authority: RESEARCH_ONLY
source_bundle: SRC-ARXON-TRADE-20260913
---

# Arxon Trade — future backtest plan

## Purpose

Convert the Arxon indicator descriptions into a source-traceable queue of **possible one-change experiments** without starting MT5, optimization, HOLDOUT, Candidate work, or a new strategy family today.

Direct consumer: a future Control Tower selection of one already qualified EA parent/home whose unresolved causal question is specifically addressed by one Arxon-derived component.

Current execution state: `DO_NOT_RUN_YET / WAITING_FOR_PARENT_AND_SEMANTICS`.

## Dedup first

Black Tide session context is not a new experiment. EA_LAB already completed `HYP-SB-005` and parked it as `FALSIFIED_STOP_EXPANSION_PARK`. This plan must not rerun or rescue that branch. Black Tide's other modules may only return as separately motivated one-change hypotheses with new direct consumers.

## Priority A — Stochastic Dual Zone event

Why first: the public source rule is comparatively explicit — both `%K` and `%D` enter the same adjustable extreme zone together, producing a one-shot event; published defaults are 80/20.

Still required before preregistration:

1. Select one exact canonical parent EA + symbol + timeframe + frozen set/build.
2. Declare one role only: `ENTRY`, `ENTRY_FILTER`, `EXIT`, or `CONTEXT_LABEL`.
3. Freeze direction semantics. The source does not establish whether overbought means short/reversal, long/continuation, exit-long, or only context.
4. Freeze bar timing and closed-bar/next-bar execution to avoid lookahead.
5. Freeze `%K` length, `%K` smoothing, `%D` smoothing, upper/lower levels, timeframe, and price basis.
6. Pre-register participation reporting and the falsifier before seeing outcome data.
First test shape after those gates: parent vs exactly one fixed-config Stochastic child, Model-1 research evidence on one MT5 installation lineage, MAIN then BWD under the canonical experiment contract. No parameter sweep in the first attribution test.

## Priority B — RSI extreme-confirmation event

Potential question: does a prospectively frozen RSI extreme-confirmation event add useful information to a qualified parent without collapsing participation or relying on one historical episode?

Gate: `SEMANTICS_REQUIRED`. The public page conflicts on marker timing (`zone exit` versus `one-bar reversal confirmation while inside the zone`). EA_LAB must choose and label one explicit reproducible interpretation before testing; until the source conflict is resolved, the child must be described as **Arxon-inspired**, not exact Arxon parity.

Freeze at minimum: RSI period, upper/lower bands, timeframe, smoothing mode, whether divergence is disabled/enabled, event confirmation timing, and the event's role in the parent. Keep optional divergence OFF for the first timing test unless divergence itself is the single preregistered change.

## Priority C — MFI+ three-state context

Gate: `SEMANTICS_REQUIRED`.

Before any run, obtain or define source-bound values for MFI period, upper/lower bands, timeframe, smoothing/price-volume semantics, and exactly how `BULLISH / UNDECIDED / BEARISH` changes one parent decision. Do not assume standard 80/20 thresholds or convert display colouring into a trading rule without preregistration.

## Priority D — OBV+ confirmation/divergence

Gate: `SEMANTICS_REQUIRED`.

Before any run, freeze standard OBV base calculation plus the Arxon-inspired additions separately: slope window/definition, divergence pivot definition, confirmation delay, minimum pivot separation, and event role. Do not test slope + divergence together in the first causal experiment.

## Priority E — Black Tide follow-ons

The session branch stays closed. A future new hypothesis may select exactly one independent module such as anchored VWAP/opening balance, structure, consolidation, OB/FVG, or another documented context feature only when a direct consumer exists and exact semantics are source-traceable. It must not be framed as a rescue of `HYP-SB-005`.
## Canonical future execution sequence

1. Re-fetch current `origin/master`, read the selected parent/family contract, and reconcile Lane Registry.
2. Select one direct consumer from canonical evidence; do not mine Arxon components merely to rescue a weak or already closed path.
3. Freeze exact source semantics and exact EA mapping prospectively.
4. Register one hypothesis revision with one logical change, exact build/set/home/window identity, participation metrics, falsifier, and stop rule.
5. Run the parent/control and child in one accepted MT5 installation lineage using Model 1 / 1 Minute OHLC or better. Model 2/Open Prices may diagnose mechanics only and cannot support the research verdict.
6. Evaluate MAIN and BWD without retuning on BWD; include year/participation/concentration cuts required by the exact family contract.
7. If falsified, preserve the negative result and stop that branch. Do not add a second Arxon component as an adaptive rescue inside the same experiment.
8. If not falsified, any portability replication or parameter search is a separate prospective contract. Optimization opens only for a qualified survivor and must map a stable region rather than select a top-PF spike.
9. HOLDOUT remains protected and late. Model 4 MAIN+BWD on one frozen installation/config lineage is mandatory before any new Candidate eligibility; no M1-to-M4 retuning.

## Backtest queue state

| Priority | Component | State now | Next unlock |
|---|---|---|---|
| A | Stochastic Dual Zone | `WAITING_PARENT_AND_PREREGISTRATION` | qualified parent/home + frozen event role/timing |
| B | RSI extreme confirmation | `SEMANTICS_REQUIRED` | resolve/freeze one reproducible marker-timing interpretation |
| C | MFI+ three-state context | `SEMANTICS_REQUIRED` | exact period/bands/role semantics |
| D | OBV+ slope or divergence | `SEMANTICS_REQUIRED` | choose exactly one addition + exact detector semantics |
| E | Black Tide non-session module | `WAITING_DIRECT_CONSUMER` | independent mechanism motivation + source-traceable one-change contract |
| Closed | Black Tide session context | `FALSIFIED_STOP_EXPANSION_PARK` | do not reopen from this source intake |

## Authority / stop boundary

This plan is a backlog, not an ExperimentContract. It performs no MT5 run, creates no `.set`, changes no EA code/default/risk rule, spends no HOLDOUT, grants no optimizer authority, and creates no Candidate/Grade/KINT/runtime/deployment/trading authority.

The next permissible action is **preregistration of one selected component only after its parent and semantics are known**.