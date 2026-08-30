# B16 H03 Confirmation Contract

`FACTORY-B16-H03-CONFIRMATION-PREREGISTRATION`

Status: **PROSPECTIVE / FIXED-CONFIG / RESEARCH-ONLY / NON-PROMOTIONAL**
Canonical base: `b7c0d624e1e1cd999628b3f70e987933fc7f55e7`
Direct consumer: a deterministic B16 H03 evidence/analysis lane.
Potential later consumer: a separately preregistered H04 mechanism-ablation or local
plateau/sensitivity design, and only if this contract produces a confirmed, reusable
signal.

## 1. Question and boundary

H02's accepted literal-portability screen found three B16 dual-window PF-positive
pulses, with the primary pulse at `XAUUSD/H4`:

| Context | MAIN 2023-01-01..2025-12-31 | BWD 2020-01-01..2022-12-31 |
|---|---:|---:|
| **Primary: XAUUSD/H4** | PF 4.08; 79 trades; EqDD 6.27% | PF 1.44; 148 trades; EqDD 8.29% |
| Supporting: USDJPY/H1 | PF 1.53; 275 trades; EqDD 3.85% | PF 1.11; 267 trades; EqDD 2.40% |
| Supporting: XAUUSD/M15 | PF 1.25; 1,577 trades; EqDD 11.88% | PF 1.10; 1,463 trades; EqDD 14.86% |

H03 asks a narrower question: **does the already-observed primary B16/XAUUSD/H4
pulse remain positive and materially distributed through time when the exact accepted
H02 evidence is decomposed, rather than being explained by a small number of periods,
cycles, or uninspectable position-engine events?**

This is confirmation/attribution of a fixed observation, not winner selection. The
79 MAIN trades are evidence-confidence context, not an automatic strategy-quality
failure and not a reason to invent a universal trade floor. Strategy quality and
evidence confidence must be reported separately.

## 2. Frozen identity and non-negotiable exclusions

The configuration is exactly `B16-H01-r1`: the accepted B16 FULL 173/173 tester
materialization used in H02, including its 135/135 matched H01 overlay assignments.
The source/build lineage is `cf32ba8d32a8292e8f7b5ad2ef766e3442b20125` and the
H02 preregistration is `40b38ffafc5be5e34abc5070a57fa6049ed5b3b4`. The H02 pair
matrix is `docs/factory/BOSS11_16_H02_PAIR_MATRIX.csv` (SHA256
`d938d9d7b154226387cde12ef4571d179df00ee1c1a2dace2f626f873c944c47`).

Every H03 input must bind its report/deal bytes to the same effective configuration
fingerprint/materialization, source/build identity, symbol, timeframe, date range,
Model 1, USD 10,000 deposit, and 1:100 leverage. The diagnostic consumer must record
the input-byte SHA256s. A missing identity field is not silently filled from a default.

H03 may not:

- optimize, rescale, normalize, tune, or alter a parameter, lot/risk default, source,
  set, or B16 semantic;
- spend HOLDOUT 2026H1;
- rank/select a candidate, promote, deploy/attach, trade, or change DEMO/LIVE state;
- create B18 semantics, a Candidate dossier, or a full Candidate graph pack.

`USDJPY/H1` and `XAUUSD/M15` are supporting context only. They may be parsed under
the same rules to compare home/timeframe participation or engine signatures, but they
cannot replace a primary failure, rescue the primary, or create a new selection rule.

## 3. Evidence cells and source-first execution

### 3.1 Required primary cells

| ID | Cell | Window | Required use |
|---|---|---|---|
| H03-P1 | B16 / XAUUSD / H4 | MAIN 2023-01-01..2025-12-31 | primary decomposition |
| H03-P2 | B16 / XAUUSD / H4 | BWD 2020-01-01..2022-12-31 | primary decomposition |

The preferred execution is **no new tester run**: deterministically parse the accepted
H02 report/deal bytes for H03-P1 and H03-P2. The accepted H02 results document and
pair matrix are the reconciliation authority; raw accepted report/deal bytes are the
diagnostic authority when available.

If an H02 byte source does not contain a mandatory diagnostic field, or cannot be
unambiguously bound to the frozen identity, a same-config diagnostic rerun is
preregistered for that cell only. All such reruns must use **MT5 lane 1 only**
(`D:\Meta 5`), be Model 1, and run the MAIN/BWD pair end-to-end in that lane. The
rerun is permitted solely to emit the missing diagnostic history; it must retain the
frozen materialization and the stated tester/deposit/leverage/windows. It must not
consume HOLDOUT or produce an optimization surface. A rerun whose primary totals do
not reconcile is a mechanical result, not an opportunity to tune.

Supporting parses, if available, are four fixed cells: B16/USDJPY/H1 MAIN+BWD and
B16/XAUUSD/M15 MAIN+BWD. They are optional context, never a prerequisite for a
primary H03 outcome.

## 4. Deterministic diagnostic plan

Use normalized closed-deal history plus open/close records where present. Sort by
server timestamp then immutable deal/ticket identifier. Do not merge independently
closed raw tickets into a synthetic trade count. Where position identifiers and
open/close events permit it, a **cycle/basket** begins at the transition from no own
open position to at least one, and ends at the next own-flat transition; all legs
within that interval are one cycle. If that reconstruction is unavailable, report
`CYCLE_RECONSTRUCTION = UNKNOWN`, not an inferred substitute.

For each primary cell, produce the following, from the same accepted/rerun byte set:

1. **Exact reconciliation.** Report period bounds, trade/deal count, gross profit,
   gross loss, net profit, PF, and the named equity-DD field. Reconstructed totals must
   equal the source totals, and H03's displayed PF and EqDD must match the H02 pair
   matrix to its displayed precision (PF within 0.01; trade count exact). Any material
   mismatch is `MECHANICAL_FAIL` until explained by a byte-bound report convention;
   it is never repaired by a parameter change.
2. **Temporal distribution.** Split each three-year window into calendar years
   (BWD: 2020, 2021, 2022; MAIN: 2023, 2024, 2025) and two contiguous 18-month folds.
   For each bin show cycle count where derivable, closed-ticket count, net, PF,
   positive-profit contribution, loss contribution, DD peak, and active-time share.
   No later boundary may be moved after results are seen.
3. **Participation and concentration.** Report date of first/last cycle, cycles or
   tickets per calendar year/fold, time in market (sum of cycle active durations and
   union-active duration where reconstructable), and active-time share of the full
   window. Show the top profitable and losing cycles, their shares of gross profit and
   gross loss, and calendar-year/fold contributions. Raw tickets alone are secondary
   when cycles are derivable.
4. **Direction.** Report BUY and SELL counts/cycles, net, PF, gross profit/loss, and
   contribution to aggregate profit/loss. A one-sided result is a visible mechanism
   finding, not automatically a strategy failure.
5. **Position engine/exposure.** For every reconstructed cycle report or aggregate:
   maximum simultaneous positions, maximum basket depth, maximum aggregate lots,
   maximum observed reference-to-farthest entry-price span (also ATR-normalized only
   if the report contains the required contemporaneous ATR), duration, and exit type
   where identifiable. Also state observed contact with the configured 10-orders-per-
   side cap and whether flat lots/optional ladder use can be established from the
   effective configuration and history. Do not claim a grid span, exposure, or exit
   classification when the necessary source field is absent.
6. **Tail/DD shape.** Provide equity and underwater/equity-DD series when supplied,
   maximum DD and its time interval, the cycle(s) overlapping its maximum, largest
   realized loss, cumulative-loss concentration, and hard-kill/emergency-close events.
   If an equity series is absent, report the source's named EqDD metric and mark the
   tail-shape series `UNKNOWN`; do not fabricate intratrade equity.

The source-bound workflow pointer for interpretation is:
`ea_template/Boss_16_KangarooGrid.mq5` -> `ea_template/core/LabCore.mqh` ->
`ea_template/core/entries/Entry_KangarooRSI.mqh` and
`ea_template/core/entries/Kangaroo.mqh`. It describes RSI-fade first entry,
ATR-spaced adverse-only grid adds, Kangaroo-owned flat/optional-ladder lot law,
per-order ATR SL, and single/basket/overlap exits under the hard 10-order cap. This
pointer is explanatory only; no workflow diagram or source change is part of H03.

## 5. Bounded outcome vocabulary

The analysis lane assigns exactly one H03 outcome to the primary pair. These labels
are research findings, not a canonical candidate/verdict vocabulary.

| Outcome | Objective check |
|---|---|
| `CONFIRMED_DISTRIBUTED_PULSE` | Both primary reports are complete, exact-identity and exact-total reconciled; PF remains >1 in each full window; each of the six calendar-year bins has at least one completed cycle (or, if cycles cannot be formed but ticket history is complete, at least one closed ticket); each of the four 18-month folds has participation; no single completed cycle supplies >=50% of a window's gross profit; no calendar year supplies >=75% of a window's gross profit; mandatory position/exposure and DD diagnostics are available and no `MECHANICAL_FAIL` occurred. This confirms distribution only, not safety, candidate status, or parameter portability. |
| `TIME_OR_REGIME_CONCENTRATED_PULSE` | Identity and full-window reconciliation hold and both full-window PF values remain >1, but a required calendar year/fold has no participation, or any cycle/year exceeds the concentration bounds above. A regime-qualified suffix may be used only when a pre-existing, source-bound regime label is present; H03 may not introduce a regime classifier. |
| `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN` | Identity and full-window reconciliation hold and both full-window PF values remain >1, but either (a) cycles/exposure/active-time cannot be reconstructed after the allowed same-config diagnostic attempt, or (b) cycles with more than one entry account for >=50% of a window's gross profit, or a configured-cap-depth cycle accounts for >=50% of gross profit or overlaps the maximum DD. State which condition applies. This is not an automatic failure. |
| `INSUFFICIENT_EVIDENCE` | No mechanical failure is established, but one or more mandatory primary diagnostic fields remain unavailable or ambiguously bound after source-first parsing and, where needed, the allowed same-config diagnostic rerun. Do not replace the missing field with an estimate. |
| `MECHANICAL_FAIL` | A required primary run/report is incomplete, fails frozen-identity binding, or cannot reconcile its raw totals/H02 totals under a documented report convention. This is harness/evidence failure, not strategy failure. |

Precedence is: `MECHANICAL_FAIL`, then `INSUFFICIENT_EVIDENCE`, then
`POSITION_ENGINE_DEPENDENT_OR_UNKNOWN`, then `TIME_OR_REGIME_CONCENTRATED_PULSE`,
then `CONFIRMED_DISTRIBUTED_PULSE`. This prevents a positive headline PF from hiding
missing diagnostics or an engine-dependent result.

## 6. Compact R2-style reporting contract

The evidence lane emits one compact H03 confirmation report, not a Candidate pack. It
must contain: frozen identity and source byte hashes; the primary MAIN/BWD
reconciliation table; yearly and fixed-fold table; BUY/SELL table; cycle/basket and
exposure table; DD/tail and concentration table; optional supporting-context table;
the single H03 outcome; separate `STRATEGY_QUALITY = NOT_REASSESSED_BY_H03` and
`EVIDENCE_CONFIDENCE` narrative; known unknowns; and the workflow pointer above.

R2-style visuals, when the source supports them, are limited to primary equity,
underwater/equity-DD, and year/fold distribution. No candidate graph, optimization
surface, plateau plot, or new mechanism diagram is authorized.

## 7. Downstream gate

Only `CONFIRMED_DISTRIBUTED_PULSE` with a reusable, explicitly described signal may
unlock a separately preregistered H04: either a mechanism ablation or a local
plateau/sensitivity design. H03 itself unlocks neither optimization nor a candidate,
HOLDOUT, risk/default change, deployment, DEMO, or LIVE action. Every other outcome
closes H03 at its measured evidence and requires a new contract before further work.

## 8. Known unknowns and loop breaker

The accepted H02 aggregate artefacts do not by themselves prove availability of
deal-level cycle, exposure, active-time, ATR-at-entry, or intratrade equity fields.
Their availability is therefore `UNKNOWN` until byte-bound parsing is performed. If
the same unresolved semantic question recurs a second time, record it as `UNKNOWN` in
the H03 report and stop that branch; do not silently infer a basket rule, grid span,
or exit classification from aggregate PF/DD.
