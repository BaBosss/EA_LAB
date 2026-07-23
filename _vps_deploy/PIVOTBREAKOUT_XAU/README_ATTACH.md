# PivotBreakout XAU — attach guide (magic 992017)

**Verdict: VALIDATED CANDIDATE → demo-isolate.** Full funnel passed on real ticks: both-window,
holdout, MC all clear. Corr vs cohort **unmeasured** (ORDER-174 unblocked but not yet done) —
size small until that's checked. **No auto-live.**

## Attach
| field | value |
|---|---|
| EA | `PivotBreakout_XAU.ex5` |
| set | `PivotBreakout_XAU_deploy.set` (FULL 15-input merge — do NOT attach with a partial set) |
| symbol / TF | **XAUUSD / H4** |
| magic | **992017** (unique in the cohort) |
| lot | 0.01 fixed |
| server time | `_03_ServerGmtOffset=3` for Exness; adjust for other brokers |

## What it does
Classic floor-trader daily pivot: `Pivot=(H+L+C)/3`, `R1=2*Pivot-L`, `S1=2*Pivot-H` from the prior
closed D1 bar, recomputed once per new D1 session. Enters when an H4 close breaks above R1 (or
below S1) with a confirming bullish/bearish close — one trade per direction per D1 session.
SL = 1.5×ATR(14,H4), TP = 3×risk.

## Evidence (locked center: SlAtrMult=1.5, TpRR=3.0)
| window | Model 1 | Model 4 (real ticks) | n |
|---|---|---|---|
| MAIN 2023.01–2025.12 | 1.18 | **1.16** | 231 |
| BWD 2020–2022 | 1.26 | **1.22** | 200 |
| HOLDOUT 2026H1 | — | **1.33** | 35 |

- Sensitivity fan (TpRR 1.5→3.5, Model 1): **every cell stayed >1.0 on BOTH windows** — a genuine
  plateau, not a lucky single cell. Tighter SL (1.5×ATR) consistently beat wider (2.5×ATR).
- Model-4 degradation was small and graceful (−0.02 to −0.04 PF vs Model 1) — contrast the
  cent-scalp MomentumBurst EA from this same session, whose tight 40-point SL collapsed −0.3 to
  −0.5 PF under real ticks. PivotBreakout's wider ATR-relative stop appears to survive real fills.
- MC (Model-4 MAIN trade series, 5000 iters): **ruin 0.00%**, PF-5th 1.16, DD95 8.24%, worst
  12.41%, P(net<0) 0%.

## Known weaknesses — read before sizing up
1. **Correlation vs the live cohort is UNMEASURED** (ORDER-174 tool was blocked by ORDER-170, now
   unblocked but not yet run). Could be redundant with other XAU/breakout legs — keep size small.
2. DD95 (8.24%) is noticeably higher than some other candidates this session (e.g. SS1's 3.61%) —
   still within the lab's comfortable band but worth sizing conservatively.
3. Holdout n=35 is on the thinner side (6 months of H4, one trade per direction per day) — real but
   not a large sample; treat early demo months as confirming, not yet conclusive.
4. GapContinuation (a sibling idea tested the same session) failed hard on BWD despite a flashy
   MAIN headline — a reminder that this cohort's "MAIN looks great" pattern is common and BWD/M4
   is where most ideas actually die. PivotBreakout is the exception, not the rule, this session.

## Pre-registered judge criteria
- **Judge date:** 3 months after attach.
- **Promote to live:** PF ≥ **1.40** at ≥ **30 trades**, no kill trip.
- **Kill:** equity DD > **12%**, or 3-month PF < **0.8** at ≥ **15 trades**.
