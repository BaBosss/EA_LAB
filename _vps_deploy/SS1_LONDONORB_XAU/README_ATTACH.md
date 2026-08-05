# SS1 LondonORB XAU — attach guide (magic 992003)

**Verdict: VALIDATED CANDIDATE → demo-isolate.** Full funnel passed except correlation
(blocked by ORDER-174, the cohort corr tool reads the wrong source). **No auto-live.**

## Attach
| field | value |
|---|---|
| EA | `LondonORB_XAU.ex5` |
| set | `SS1_LondonORB_XAU_deploy.set` (FULL 25-input merge — do NOT attach with a partial set; unlisted inputs come from per-terminal cache) |
| symbol / TF | **XAUUSD / M15** |
| magic | **992003** (unique in the cohort) |
| lot | 0.01 fixed |
| server time | set `_06_ServerGmtOffset` to your broker's GMT offset. **3 = Exness**. Wrong offset silently shifts the whole session window and voids the edge. |

## What it does
Builds the London opening range 07:00–08:00 GMT, requires OR width in [0.5, 2.5]×ATR(H1),
then arms a stop order beyond the OR edge — **only on the side that agrees with EMA200**
(the trend filter; this is the lever that made the EA viable). SL = far OR side capped at
1.5×ATR(H1), TP = 3.5R. Unfilled pendings cancelled 12:00 GMT, force-flat 16:00 GMT.

## Evidence (locked center: EMA200 / MinOr 0.5 / TpRR 3.5)
| window | Model 1 | Model 4 (real ticks) | n |
|---|---|---|---|
| MAIN 2023.01–2025.12 | 1.22 | **1.16** | 499 |
| BWD 2020–2022 | 1.13 | **1.06** | 492 |
| HOLDOUT 2026H1 | 1.24 | **1.21** | 86 |

- Sensitivity fan: TpRR **flat 1.20–1.23 across 2.5→5.0** (robust, not fitted); EMA axis smooth
  1.24→1.22→1.17 (100/200/300).
- MC (on the Model-4 MAIN trade series, 5000 iters): **ruin 0.00%**, PF-5th 1.16,
  DD95 3.61%, worst 5.65%, P(net<0) 0%.
- Model-4 largest loss −28.13 (MAIN) / −23.36 (BWD) / −56.60 (holdout) — no model-switch cliff.

## Known weaknesses — read before sizing up
1. **Real-tick MAIN is 1.16, under the 1.2 deploy bar.** The 1.2 bar was met on Model 1
   (the selection model); Model 4 costs a consistent ~0.06 PF. The edge is real (it degrades
   gracefully, it does not collapse like a fill artifact) but the true margin is thinner than
   the headline 1.22.
2. **Fragile on one axis:** the result needs `_02_MinOrAtrH1 = 0.5`. At 0.8 MAIN falls to 1.09.
   Do not "tidy" that parameter upward.
3. **Holdout 2026H1 is partially burned at cohort level** (TrendRider used it first). It is
   this EA's first use, but it is not a pristine window.
4. **Correlation vs the live cohort is UNMEASURED** (ORDER-174). Until that tool is fixed,
   treat this as possibly-redundant with other XAU legs and keep the size small.

## Pre-registered judge criteria (fix these now, do not move them later)
- **Judge date:** 3 months after attach.
- **Promote to live:** PF ≥ **1.40** at ≥ **30 trades**, no kill trip.
- **Kill:** equity DD > **12%**, or 3-month PF < **0.8** at ≥ **15 trades**.
- **Do not** read a losing month as new information — at PF 1.16–1.22 with ~165 trades/yr,
  losing stretches are expected. Only the pre-registered numbers decide.
