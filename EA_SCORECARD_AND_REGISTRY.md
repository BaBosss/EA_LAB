# EA SCORECARD & REGISTRY — canonical scoring + audit trail

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · ไฟล์นี้ owns: **ทะเบียน EA · scoring rubric · kill-reason** เท่านั้น
**Created 2026-06-23.** Purpose: make every keep/kill decision **transparent and reproducible**.
No EA is "dead" without a recorded reason AND a confidence tag saying how thoroughly it was tested.
A kill made on a smoke test (★) is LOW confidence and must be re-examined before it is final.

---

## PART 1 — THE SCORING RUBRIC

### Step 0 — HARD GATES (any one fails → DISQUALIFIED, do not score further)
**Revised 2026-07-03 (user-corrected — supersedes the original all-mechanism version below).**
Mechanism risk (uncapped martingale/grid) is no longer an instant pre-measurement kill — it wasted
opportunities on EAs that might have scored fine on realized numbers. It now feeds the score instead
(see Step 0b below). Only genuine **deployability facts** stay as true hard gates — things no amount
of good performance can fix, because the EA literally cannot run live:
| Gate | Fail condition | Why it's a true hard gate (not a risk judgment) |
|---|---|---|
| **Expired / locked .ex** | license/time-expired, won't trade live | un-deployable — validation effort wasted (KRAPOOK lesson) |
| **Structural non-function** | NO_DATA on every symbol tried, init fails every time, etc. | there is nothing to score |

> ⚠️ **Model-2-only artifact is now a SUSPECT flag, not an instant gate** (see the fidelity-floor rule
> below) — a PF collapse on TP×10 seen only at Model 2 must be re-confirmed at Model 1 (control points)
> before it can finalize a DISQUALIFIED/REJECT verdict. Model 2 alone proves the concept fires, nothing more.

### Step 0b — MECHANISM RISK PENALTY (score-based, replaces the old hard gate)
Uncapped martingale / uncapped grid-no-hard-SL are still real structural risk — they just no longer
skip straight to DISQUALIFIED before the EA is even measured. Apply directly to the Step 1 total:
| Condition | Penalty |
|---|---|
| Uncapped martingale (lot scales on losses, no step cap, or cap so high a plausible streak still ruins) | **−25 pts off Step 1 total** |
| Uncapped grid / no hard SL (adds positions with no binding cap AND no per-position SL) | **−25 pts off Step 1 total** (both present → −25 total, not stacked twice for the same mechanism) |

Flag the registry row **⚠️ MECHANISM RISK** whenever this penalty applies, and require the
sizing-normalized DD procedure below to be run before ANY deploy consideration, regardless of the
resulting score band — a high raw score with this flag still needs the DD-budget re-test, not a
straight deploy.

### ⏱️ TEST FIDELITY FLOOR (added 2026-07-03, strengthened same day — user-corrected)
**Model 2 (open prices) is proof-of-concept only — it can confirm an EA fires and its logic runs, and
nothing more.** Its PF/DD numbers must NEVER be reported, ranked, or compared as if they mean anything
— not just "don't use it to REJECT," don't use it to judge good OR bad, don't screen/rank multiple
symbols by their Model-2 PF either. **Any number put in front of the user requires at least Model 1
(control points) first.** If Model 2 is used at all, it's only to filter out zero-trade/broken configs
before spending Model-1 time — the moment a PF number gets reported or a symbol gets ranked, it must be
Model 1+. Confirmed twice in one day on the same EA: AUDCAD screened PF 1.80 at Model 2 → PF 0.89 at
Model 1; AUDNZD screened PF 1.96 at Model 2 → PF 1.06 at Model 1. Both would have looked like real
candidates off Model 2 alone. Model 2's fixed/open-price fills
routinely overstate both edge (tight-TP artifacts) and risk (grid/martingale DD) — in this project's
own Zeus Gold Hedge test (2026-07-03), the SAME parameters showed DD 102% at Model 2 vs DD 79% at
Model 0 (every tick) — same direction, but Model 2 alone would have been a worse, unconfirmed number
driving the verdict. Model 0/every-tick remains required only for the final go/no-go on an actual
deploy candidate (unchanged from the existing Model ladder in `backtest-optimize-rigor`).

> **Known backtest blind spot — fixed spread.** MT4's Strategy Tester holds spread at a single
> constant value ("Spread: Current (N)") for the ENTIRE backtest at every model level, including
> Model 0. It does not simulate real spread widening during volatile/news moves. Any EA whose live
> risk control depends partly on a `MaxSpread` filter (blocking new entries when spread blows out)
> will show WORSE backtest DD than live, because the filter never actually trips in simulation —
> confirmed on Zeus (MaxSpread=25 input, but every generated report shows a flat single-digit-to-25
> "Current" spread throughout, meaning the filter had nothing to block). Note this explicitly on any
> verdict for an EA with a meaningful spread filter; don't let a backtest DD number alone override
> demonstrated live survival without accounting for this gap.

> ### ⚠️ DD% is NOT a hard gate (revised 2026-06-23, user-corrected)
> Raw max-DD% conflates **two different things**: (1) *position sizing & grid spacing* — fully
> tunable (halve the lot → ~halve the DD; widen spacing → fewer concurrent positions → lower DD),
> and (2) *structural ruin risk* — the loss MECHANISM, which sizing can't remove.
> **Therefore a high-DD EA is NOT auto-killed.** Before any DD verdict, RE-TEST it at adjusted
> sizing/spacing that targets a DD budget (e.g. 10–15%), then judge whether it still makes money
> there. Only the *mechanism* gates above are structural. A grid that doubles uncapped fails the
> gate regardless of DD; a bounded grid showing 40% DD at 0.1 lot may show 8% at 0.02 lot and is
> a legitimate CANDIDATE — evaluate it, don't reflex-kill it.
>
> **Sizing-normalized DD procedure:** (a) find the lot/spacing that brings historical DD to the
> budget; (b) re-run IS+OOS at that sizing; (c) check MAR (return ÷ DD) is still ≥0.5 and net is
> meaningful; (d) **then** stress it — MC + a trend-stress regime — because closed-trade DD still
> understates a grid's floating DD and historical worst-streak ≠ worst-possible. Pass all → CANDIDATE.

A DISQUALIFIED EA can still have a *recorded technique* worth reusing (e.g. KRAPOOK's
distance-scaling insight) — note it, but the EA itself is out.

### Step 1 — SCORE (0–100) for EAs that pass all gates

**A. Edge — 35 pts** (does it actually make money out-of-sample?)
- OOS PF (Model 4 preferred): ≥2.0→15 · 1.5–2.0→11 · 1.2–1.5→7 · 1.0–1.2→3 · <1.0→0
- IS→OOS retention = OOS_PF / IS_PF: ≥0.8→10 · 0.6–0.8→7 · 0.4–0.6→4 · <0.4→0  *(overfit detector)*
- Sample size (min trades/window): ≥100→10 · 50–100→6 · 30–50→3 · <30→1

**B. Robustness — 30 pts** (does the edge survive stress?)
- OOS windows passed (PF≥1.2): 3/3→12 · 2/2→9 · 1→4 · 0→0
- Monte Carlo PF 5th-pctile: ≥1.4→10 · 1.2–1.4→7 · 1.0–1.2→4 · <1.0 or not-run→0
- Parameter plateau: broad flat region→8 · moderate→5 · lone spike / unknown→0

**C. Risk Control — 20 pts**  *(evaluate at TARGET sizing, not raw default lot)*
- Max DD% **at sizing that targets a 10–15% DD budget**: <5→8 · 5–15→5 · 15–25→2 · >25→0
  *(if raw DD>budget, first re-test at lower lot/wider spacing — see DD note above — then score this)*
- Real hard SL present: yes→6 · no→0
- MAR (annual return ÷ maxDD) at that sizing: ≥1→6 · 0.5–1→3 · <0.5→1

**D. Strategic Fit — 15 pts**
- Thesis-aligned (momentum/breakout on trending instrument, OR otherwise-confirmed edge): yes→6 · no→0
- Portfolio diversification (new instrument/session, low correlation to current 8): high→5 · med→3 · dup/high-corr→1
- Live-tradeable now (not expired, cent-lot OK, sensible min-lot): yes→4 · no→0

### Step 2 — CONFIDENCE TAG (how much to trust the score/verdict)
★☆☆ **Smoke** — default params, 1 window. Verdict is a *guess*; a kill here is PROVISIONAL.
★★☆ **Optimized** — grid sweep + ≥1 genuine OOS window.
★★★ **Exhaustive** — sweep + forward OOS + Monte Carlo (+ every-tick where possible).

### Step 3 — VERDICT BANDS
| Score | Confidence | Verdict | Action |
|---|---|---|---|
| 75–100 | ★★/★★★ | **CORE** | deploy at full risk |
| 55–74 | ★★/★★★ | **CANDIDATE** | deploy small / monitor first 30 trades |
| 40–54 | any | **REBUILD** | real edge-kernel, re-optimize before deploy |
| <40 | ★★★ | **DEAD** | thoroughly tested — do NOT revisit |
| <40 | ★☆☆ / ★★☆ | **PARKED** | kill is LOW-confidence → RE-EXAMINE before final |
| (gate fail) | — | **DISQUALIFIED** | record reason + any reusable technique |

---

## PART 2 — REGISTRY (every EA with data, scored)

### MT5 — LIVE PORTFOLIO (deployed 2026-06-22)
| EA | Sym/TF | OOS PF | DD% | Conf | Verdict | Notes |
|---|---|---|---|---|---|---|
| MG_v1 MatchaGrid | CHFJPY M15 | 2.08 | — | ★★★ | **CORE** | grid but bounded+SL; passed deep-val |
| NuiIndy RSI+ADX | EURUSD H1 | 2.00 | — | ★★★ | **CORE** | |
| ST_EA03 MACD | GBPUSD H1 | 2.47 | — | ★★★ | **CORE** | count+tiered-TP scalp |
| ST_EA03 MACD | USDCAD H1 | 2.62 | — | ★★★ | **CORE** | |
| Gold Reaper 4.3 | XAUUSD H1 | 2.07 | — | ★★★ | **CORE** ⚠️ | ruin 1.9% — watch. **Live set unchanged 2026-07-02** — see plateau-check note below (optimize attempt was a null result, not a real check) |
| EA_BREAKOUT_XAU | XAUUSD H1 | 1.77 (M4) | 0.65 | ★★★ | **CANDIDATE** | BUY-only regime risk; thin OOS 33t |
| LondonConsoBreakout | GBPUSD H1 | 2.08 | 0.10 | ★★★ | **CANDIDATE** | 3/3 OOS; GBP concentration |
| LondonConsoBreakout | EURUSD H1 | 1.25 | 0.13 | ★★★ | **DROP (was #8)** | Q2 rescue sweep (48 combo×3 win) DONE — NO combo passes all 3 at PF≥1.2; best min-PF 0.92, both OOS <1.0. No durable edge → remove from portfolio |

> **Gold Reaper opt review (2026-07-02, Claude Fable):** qwen's `QWEN_GR_opt.xml` (2026-06-29, 5 passes
> sweeping `StartLots` 0.01→0.05, GBPUSD... XAUUSD H1, combined window 2023.01–2026.06, `Optimization=2`
> genetic) is a **null result, not a real plateau-check** — all 5 passes are bit-identical
> (Profit=267741.38, PF=2.349244, Trades=2548, DD=13.8505% — every digit the same regardless of lot).
> Root cause: the ini also carries `Risk=1234` + `UseWeightedLots=true` + `AdjustLotsizeToVariableValues=true`.
> Per the comment already in the live set (`_mt5_auto/GoldReaper_cent_v1.set`): **"Risk=1234 = internal
> variable mode"** — Gold Reaper is a closed-source multi-strategy EA (9 sub-strategies, `RunStrat1..9`)
> whose own risk engine computes lot size in this mode, so the `StartLots` input the optimizer swept had
> **zero effect on any output**. The optimizer wasn't testing robustness; it re-ran the identical backtest
> 5 times. **No new evidence, good or bad — live set stands unchanged** (`GoldReaper_cent_v1.set`,
> `StartLots=0.01`, unchanged since deploy). If Gold Reaper needs real tuning later, sweep
> `MaxRiskPerStrategy_` or `RunStrat1..9` toggles instead — do NOT re-sweep `StartLots` under
> `Risk=1234` mode, it's a wasted pass.

### MT5 — FRAMEWORK / IN-PROGRESS
| EA | Sym/TF | Result | Conf | Verdict | Notes |
|---|---|---|---|---|---|
| EA_RUNNER_ST03 (ST_EA03 replica) | GBPUSD H1 | **LR2: M4 IS 8.31 / OOS 3.93** ⚠️ **superseded 2026-07-02: full-window OOS 2025.01–2026.06 M4 = PF 0.86 (585t) + STEP3 grid 48/48 combos OOS<1.0 → LOOP CLOSED, fallback (ดู `EA_CORE_ST03_LOOP_PLAN.md` STEP 5). demo 990010 = WATCH เก็บ data.** | ★★☆ | **CANDIDATE — robustness MARGINAL** | 2026-06-26: NEW WINNER **LotRepeat=2** (tp3=50/near=50) beats v1 LR3 on all windows with ~half the crisis tail → `ST03_optimized_v2.set`. **MC** (229 calm trades): PF5th 2.92, ruin 0%, but **PF-range 20.5** (edge magnitude unstable). **OOS:** no degradation (IS 8.31→OOS 3.93). **Crisis pass (KEY):** every real crisis PF<1 → edge is **calm-only**. Worst **Brexit2016 EqDD 3.51%@1× (M1 floor, real worse)** → **~42%@12× ⇒ 12× REJECTED**; 2022 14.04%@12× (margin 3155%, no stop-out). **Deploy ≤3× (really 1×), GBPUSD-only.** **hard SL = DEAD END** (proven: any SL kills calm edge 4.69→~1.2, still PF<1 in crisis — supersedes old "add SL" note). **WFA 6-window (fixed params, M1 2020-25): 4/6 profitable, PF 0.24-3.81 — but LOST 2021H2 (0.24) AND most-recent 2025H1 (0.43)** → edge is regime-dependent and currently WEAK; 2024's 8.31 was a good regime, not permanent. **VOL-GATE BUILT + TESTED (ATR>1.5×ATR_MA(300), `InpVolGateOn`, `ST03_volgate_v1.set`): PARTIAL.** Saves SPIKE/gap events (Brexit2016 −218→+94, cut 2 tail trades) at ~0 calm cost (OOS 3.93→3.70). But does NOT fix sustained-TREND crises (COVID/gilt/2025/2021 unchanged — they bleed across many trades, not ATR spikes). **TREND/ADX GATE (ST03B `EA_RUNNER_ST03B`, ADX>30): FALSIFIED — counterproductive.** Made every crisis WORSE (Brexit −218→−281, COVID −49→−66) AND cut calm −21%. Reason: ADX LAGS — by ADX>30 the trend is mature/reverting (exactly when this strategy should harvest), so the gate removes the GOOD reversion trades and keeps the early-trend losers. **CONCLUSION: the crisis tail cannot be filtered out reactively** (vol=gap-only, trend=counterproductive) → **cannot size up safely.** Real "more profit" path = **diversify across symbols + portfolio** (small uncorrelated legs), NOT leverage. **TF: H1 optimal** (M30 1.86 / M15 1.48 vs H1 8.83 — spread eats the 5pip target on lower TF). **PER-SYMBOL re-attempt (LR2 params + grid, IS+OOS held-out): GBPUSD-only re-confirmed at M4.** EURGBP no edge (IS<1); USDCAD OOS<1.2; EURUSD looked viable at M2 (OOS 1.28-1.85) but **COLLAPSED at M4 (OOS 0.54-0.74)** — classic Model-2 optimism for a no-SL tight-target (spread eats the 3-5pip target at real ticks). Deploy = small + LIVE-MONITOR first 30 trades; vol-gate optional gap-insurance. **PORTFOLIO CORRELATION (data-driven, 36mo 2020-22, portfolio_analysis.py):** corr vs live ST_EA03 GBPUSD (MACD_GBPUSD) = **−0.24 (LOW, NOT redundant — earlier assumption corrected).** The v4 replica behaves differently from the fxDreema full ST_EA03 (replica bleeds in 2022; the live one's recorded monthly series doesn't). corr vs all live legs is LOW (MG −0.47, Nui −0.01, USDCAD −0.35, Gold +0.41) — but the negative corr is mostly because the replica LOSES when others win (net −262 over 2020-22), i.e. it's the weaker leg, not a prized diversifier. ⚠️ DATA CONFIDENCE PARTIAL: the live EAs' monthly series are all-positive (max-DD 0% over 3yr = likely optimistic/in-sample) → DD-overlap math degenerate. Verdict: low-corr so it CAN sit in a separate portfolio, but small weight only (MARGINAL + crisis-bleed). Value = framework-controlled PoC + diversification *if* live-monitored. ST_EA03 already live (CORE). |

### MT5 — VALIDATED RESERVE (ผ่าน gate แต่ยังไม่ deploy — ตรวจ 2026-07-02)
| EA | Sym/TF | IS PF | OOS PF | Conf | Verdict | Notes |
|---|---|---|---|---|---|---|
| EA_KAUFMAN_ER (BuyOnly) | XAUUSD H4 | 2.34 (50t) | 5.19 (17t) | ★★☆ | **CANDIDATE — reserve (user decision 2026-07-02: เก็บก่อน ไม่ deploy)** | re-confirm 2026-07-02 (`KER_RECONF_*`, M2) ตรงตัวเลข 06-28 เป๊ะ. DD 5.1%. จุดอ่อน: OOS บาง 17t (H4 → ~2 ปีกว่าจะครบ 30 live trades) · **corr 0.946 vs EA_SUPERTREND** (sibling — ห้าม deploy คู่) · corr 0.75 vs BRK8 live → ถ้า deploy = 0.01 lot · เป็น XAU-long bet ซ้อน BRK55/BRK8/GR ที่ live อยู่. **เงื่อนไขก่อน deploy จริง: (1) M4 confirm 1 รอบ (บทเรียน M2-optimism จาก ST03 EURUSD) (2) แก้ invariant 9→10 EA + DEMO plan + check_state.ps1.** 💡 **idea จาก user (2026-07-02): เอา Kaufman ER (Efficiency Ratio) ไปใช้เป็น "ตัวบอกทิศ/regime filter" ให้ EA อื่น** — เข้าทาง vol-gate/regime line ใน EDGE_CATALOG; ถ้าจะลอง → เพิ่มเงื่อนไข ER เข้า EA ที่มี edge อยู่แล้วแล้ววัด A/B, ไม่ใช่สร้าง EA ใหม่. set พร้อม: `_vps_deploy/KAUERMAN_buyonly_live.set` (magic 990127) |
| EA_SUPERTREND v1 naked | XAUUSD H4 | 1.92 (33t) | 5.09 (17t) | ★★☆ | **PARKED — แพ้ KER** | rerun 2026-07-02 (`STV1_XAU_RECONF_*`) ผ่าน gate แต่ corr 0.946 กับ KER ที่ดีกว่าทุกด้าน → เก็บเป็น fallback ของ KER. (SuperTrend "DEAD" ใน signal hunt = คู่เงินอื่น; XAU H4 ตัวนี้รอด) |

### MT5 — FRESH TEMPLATE EAs (built 2026-06-22, +1 built 2026-07-03)
| EA | best smoke | Conf | Verdict | Kill reason / re-exam |
|---|---|---|---|---|
| (Boss)_ZeusInspired_GridLog_rev01 | AUDUSD H1 IS 1.63→OOS 1.78 (retention 1.09) | ★★☆ | **CANDIDATE — AUDUSD + AUDJPY confirmed via IS/OOS, portfolio not yet deployed** | Original design (L3 redesign of Zeus Gold Hedge behavior — `ZEUS_GOLD_HEDGE_ANALYSIS.md` §5.9-5.11). Screened 27 FX symbols total (no gold — user call), Model 1 minimum for every reported number after 2 same-day Model-2 false positives (AUDCAD 1.80→0.89, AUDNZD 1.96→1.06). **Survivors after IS/OOS split (IS=2025 H1-H2, OOS=2026 H1-mid):** AUDUSD retention 1.09 (OOS beats IS — strongest), AUDJPY retention 0.87 (passes ≥0.8 gate). **EURCAD DROPPED** — looked fine full-window (PF 1.23 @ DD 13.39%) but failed OOS outright (retention 0.53, net negative) — reinforces IS/OOS over single-window trust. DD-scaled to 10-20% band (base_lot + `_04_TpUsd` must scale together — fixed-$ TP breaks proportionally otherwise, found the hard way): AUDJPY 20x → PF 1.91/DD 14.73%/net $2,780/18mo/Sharpe 2.02; AUDUSD 20x → PF 1.22/DD 12.92%/net $1,043/Sharpe 0.32. Monte Carlo (order-resample, DD-only distribution — net/PF are order-invariant sums) flags AUDUSD's observed DD as possibly favorable-luck (95th pctile 16.55%, worst 26.04% vs observed 12.92%); AUDJPY/EURCAD more stable under reshuffle. **Correlation:** AUDUSD/AUDJPY 0.554 (WATCH — run both, reduced lot); AUDUSD/EURCAD 0.708 (HIGH — don't combine, moot now EURCAD is dropped); EURJPY near-zero corr with all three (-0.003 to -0.093) despite weak own edge (PF~1.04-1.09) — diversifier-only role, small lot. GBPAUD/USDJPY/EURCHF hold up at Model 1 but too thin (12-18 trades) to trust yet. **✅ MC on DD-scaled configs + portfolio combine DONE 2026-07-03 (รอบ 2):** MC 5000-iter on lot20x reports — AUDUSD DD med 10.62%/95th 16.55%/worst 26.04%, AUDJPY DD med 6.80%/95th 11.22%/worst 18.18%, ruin 0%, P(loss) 0% both. **Combined portfolio (closed-trade merge, 17mo):** full-lot net +$3,824 PF 1.48 balDD 10.85% but MC-95th 16.92% (over 15% budget) → **0.7x both = recommended: MC-95th 12.44%, net +$2,677, fits 10–15% DD budget** (scale `_05_BaseLot`+`_04_TpUsd`+`_06_MaxTotalLot` together). DD overlap minimal — both-negative months 1/17, but that month is **2026-06 (most recent)** → watch on demo. Caveat: balance-curve analysis; combined FLOATING DD not measurable from closed trades (per-leg equity DD 12.92%/14.73% — real combined floating DD = demo's job). Analysis script: scratchpad `zigl_portfolio_combine.py` (session 2026-07-03). **Remaining before deploy: walk-forward via robustness-validator + port into Boss V2 as Entry_GridLog (per VISION workflow) + magic 990101/990102 + deploy bundle.** Compiled .ex5 + all .set variants at `D:\EA_Project\CURRENT_BUILD\TEMPLATE\`. |
| (Boss)_SessionBreakout_rev01 | XAU M15 PF 1.04 | ★★★ | **DEAD** | 1,200-pass EXHAUSTIVE sweep ceiling 1.20 + forward 0.91. Thoroughly killed — do NOT revisit |
| (Boss)_RSI_Swing_BB_rev01 | EUR H1 PF 1.03 | ★★☆ | **DEAD (confirmed 2026-06-23)** | RE-EXAMINED: 27-combo sweep EURUSD IS+OOS, best min-PF **0.99** (breakeven), nothing ≥1.2. "Martingale was the edge" CONFIRMED — naked signal has none. Kill upgraded smoke→optimized |
| (Boss)_TrendRegression_rev01 | XAU H1 0.81 | ★★☆ | **DEAD (confirmed 2026-06-23)** | RE-EXAMINED: 27-combo sweep XAUUSD IS+OOS, best min-PF **0.91**, all losing. Reversion-on-trend has no gold edge (matches momentum>reversion thesis). Kill upgraded smoke→optimized |
| (Boss)_NRBreakout_rev01 | 0.82–1.03 | ★★☆ | **PARKED→lean DEAD** | partial sweep, all sub-gate; low prior. RE-EXAMINE only if idle |
| EA_GoldenEmber_Pivot (Boss 6 MTF Range Pivot) | NZDUSD H1 PF 1.01 | ★★★ | **DEAD (2026-06-28)** | IS 2023-2026 PF=1.01, DD=24.66%, 116t / OOS 2021-2023 PF=1.05, DD=25.79% — flat + massive DD. Robust pass (best optimizer result) still gives no IS edge. GEP DQ — do NOT revisit |
| EA_LNBREAK (London NY breakout) | GBPUSD H1 PF 1.09 | ★★★ | **DEAD (2026-06-28)** | Multi-symbol smoke 2023-2026 M2: GBPUSD 1.09 / EURUSD 1.02 / XAUUSD 1.07 / GBPJPY 0.78 / USDJPY 0.87. Best PF=1.09 after tp_mult=4 tweak — below gate 1.20. London breakout has no durable H1 edge on these symbols |

### MT5 — SIGNAL/FILTER RESEARCH (EA_RUNNER family)
| Signal | Sym | IS PF | Conf | Verdict | Reason |
|---|---|---|---|---|---|
| MACD crossover | GBPUSD H1 | 1.11 | ★★★ | **DEAD (ceiling)** | structural ceiling; ALL filters (RSI/EMA/ZLF/count) top ~1.0–1.11 |
| MACD crossover | EURUSD/USDJPY/AUD/NZD/USDCAD/EURGBP/+JPY crosses | ≤1.16 | ★★★ | **DEAD** | exhaustive multi-symbol sweep, all fail OOS |
| BB+RSI mean-reversion | EURUSD/XAUUSD | ≤1.11 | ★★☆ | **DEAD** | same ~1.1 ceiling as MACD |
| BREAKOUT (LabTpl) | EURUSD/GBPJPY | ≤1.03 | ★★★ | **DEAD** | optimizer 0/180 & 0/175 survivors — edge is XAU-specific |
| BREAKOUT (EA_BREAKOUT_XAU, both-dir) | US30/WTI/BRENT/XAGUSD/GBPJPY | <1.0 | ★★☆ | **DEAD (2026-06-26)** | new-instrument momentum smoke (M2, 2023-26, default params); oil/index thin trades (XAU-tuned bars). No naked edge |
| BREAKOUT (EA_BREAKOUT_XAU, **buy-only**) | **XAGUSD H1** | smoke 1.45 → IS 1.47 → OOS 0.78 | ★★★ | **REJECT (2026-06-28)** | Smoke PF=1.45 ✅ / IS PF=1.47 ✅ / OOS PF=0.78 ❌ structural. 2020-2023 Silver hostile to buy-only: COVID crash (-30%), Feb-2021 Reddit spike+collapse, 2022 bear trend. Plateau shallow (12/72 coarse), not param-dependent (best-IS params give OOS 0.65). Silver ≠ Gold for buy-only breakout. Do NOT re-test buy-only BRK on XAGUSD. |
| BREAKOUT (EA_BREAKOUT_XAU, both-dir) | **USDJPY H1** | smoke 1.16 → opt | ★★★ | **REJECT (2026-06-26)** | WATCH→optimized→dead. 12-combo (Bars×TpAtr) IS/OOS: 0 clear OOS≥1.40; high-TP curve-fit yen 2023-24 (IS 2.5/OOS 0.7), low-TP caps ~1.18. See [[signal-landscape]] |
| Vol-gate / Trend-gate on ST03 | GBPUSD | — | ★★★ | **filters DEAD (2026-06-26)** | no-SL tail not reactively filterable: vol-gate=gap-only, ADX trend-gate counterproductive (lags). See ST03 row + EDGE_CATALOG |

### MT4 — SCREENED (63 EAs, 0 deployed)
| EA | screen PF | Conf | Verdict | Reason |
|---|---|---|---|---|
| EA_Golden_Elephant/Mammoth | XAU 4.08 | ★★★ | **DISQUALIFIED→DEAD (re-confirmed 2026-07-02)** | grid; TP200→2000 collapsed PF 7.77→0.06 = tight-TP artifact. **Phase 2 re-test** (`MT4_GOLDGRID_RETEST_PLAN.md`, XAUUSDMINI H1, Model 1 control-points 1yr 2025.06-2026.06 — Model 0 unavailable, no tick history cached): PF collapsed **85.14 (Model 2) → 1.41 (Model 1)**, DD **53.65%/yr** at MaxOrder=4 (already capped). Artifact confirmed at every model tested; the thin residual edge isn't deployable at this DD. Mammoth = identical binary (MD5 match), same verdict, not re-tested. |
| Gold Stuff EA V7.0 | XAU 5.09/39%DD | ★★★ | **DISQUALIFIED (re-confirmed 2026-07-02)** | Phase 1 mechanism gate: `iMO=100` (max orders, practically uncapped) + `SL=0` (no per-position stop) + `MM=1.5` martingale multiplier = uncapped grid/martingale, DQ stands structurally. Phase 2 empirical: Model 1, 1yr 2025.06-2026.06, XAUUSDMINI H1 → PF=2.20 (935 trades, high-frequency churn) but **DD=77.11% in ONE YEAR** — ruin risk confirmed, no sizing fix possible per Step-0 gate. |
| KRAPOOK BLUE ANT | XAU 2.65 | ★★★ | **DISQUALIFIED** | EA EXPIRED (best profile of pool but un-deployable). Technique (distance-scaling) saved for reuse |
| BuRengNong207 | XAU 1.76 | ★★★ | **DISQUALIFIED** | martingale-only (mult=1.0 → 0/9 pass); no signal under it |
| EURUSD Forex Robot | EUR 3.89 | ★★☆ | **WATCH/PARKED** | NOT martingale (scrutinize cleared it); disqualifier = THIN sample (48t). Needs deep-data re-test |
| Espresso_Gold/Fx Setka/Little Birds/KRAPOOK Yellow | — | ★★☆ | **DISQUALIFIED** | catastrophic DD 60–125% (grid/martingale) |
| EA Game Changer/GMGS PRO | XAU high | ★★★ | **DEAD** | Model-2 tight-TP/hedge-grid artifact (TP×10 confirmed) |
| **Zeus Gold Hedge V1.2** | EU PF 0.87 (M0) / XAU PF 1.01 (M0) | ★★★ | **REJECT — low score, not a hard gate (re-scored 2026-07-03)** | Not locked after all — earlier SKIP/NO_REPORT (2026-06-21) was a broker/account license mismatch on Exness, runs fine on ThinkMarkets-Live 4. **Step 0b mechanism penalty applies** (uncapped grid, `StopLoss=0` every order, `MaxLoss=100000`/`Maxlot=100` far larger than account = not real caps) → −25pts, but NOT auto-disqualified — both symbols were run the full Model 2→1→0 ladder before any verdict. XAU compiled-default: Model 2 said REJECT (DD 102%), Model 1 showed a **false PASS artifact** (PF 1.89, +$801K, 6.5 trades/bar — physically implausible, caught before reporting), Model 0 (final authority) = PF 1.01/DD 85.59% — statistically breakeven with catastrophic DD, score fails on Risk Control regardless of the softened gate. EU: user's exact live config (lot=0.06,K_Lot=1.4,CloseAll=20,PlusLot=0.08) PF 0.87/DD 79% under Model 0 despite 3mo live survival — stress concentrates ~2mo into the 18mo window, likely outside the live sample seen so far, not evidence the config is safe going forward. Full analysis + full ladder table: `ZEUS_GOLD_HEDGE_ANALYSIS.md`. Also surfaced a real MT4 tester blind spot (fixed spread never widens → `MaxSpread` filter can't be credited in backtest) now documented in `backtest-optimize-rigor`. Technique reused (not the code — behavioral principle only): inspired an original L3-redesign EA `(Boss)_ZeusInspired_GridLog_rev01.mq5` (ATR spacing, LOG lot, real SL, partial-close, DD-adaptive first lot) — compiled clean, backtest in progress. |
| ~44 others | — | ★★☆ | **DEAD/REJECT** | structural (NO_DATA/init-fail), commercial-locked, or grid. See [[mt4-screening]] |

---

## PART 3 — RE-EXAMINATION QUEUE (PARKED ★ kills — the user's concern)
These were killed on **smoke tests only** — the verdict is provisional. Run a proper optimize
pass (grid sweep + OOS) before declaring them dead. Delegate to qwen (mechanical).

| # | EA | What to test | Expected effort |
|---|---|---|---|
| R1 | (Boss)_RSI_Swing_BB_rev01 | sweep RSI period/OB-OS levels/BB mult on EUR+XAU H1, IS+OOS — does a non-martingale config clear PF 1.2? | ~1 qwen session |
| R2 | (Boss)_TrendRegression_rev01 | sweep regression length/entry-band/SL-TP on XAU+EUR — confirm reversion truly has no edge | ~1 qwen session |
| R3 | EURUSD Forex Robot (MT4) | ThinkMarkets deep 30-mo IS/OOS multi-symbol — is the edge real beyond the thin sample? | needs MT4 + deep data |
| R4 | (Boss)_NRBreakout_rev01 | only if R1–R3 idle; widen NR-period/breakout-mult grid | low priority |

### DD RE-TEST batch (added 2026-06-23 — DD hard-cap was too crude)
EAs previously killed/DQ'd on **raw DD%** get a sizing/spacing re-test before final verdict.
Step: confirm the loss mechanism is BOUNDED (capped steps + SL). If bounded → re-run IS+OOS at
lot/spacing targeting 10–15% DD, then MC + trend-stress. If uncapped martingale/grid → DQ stands.
| EA | prev verdict | raw DD | re-test action |
|---|---|---|---|
| (pending user's list — which dead/DQ EAs did you optimize to good values?) | — | — | confirm mechanism → sizing re-test |
| candidates to consider: high-PF grids killed on DD (e.g. Gold Stuff V7 5.09/39%, EURUSD Forex Robot DD-borderline, others) | DQ/DEAD | >25% | check cap → re-test |

**DO-NOT-RE-EXAMINE (★★★ exhaustively killed — re-testing wastes tokens):**
SessionBreakout (1200-pass + forward fail), MACD all-symbols (exhaustive), BREAKOUT LabTpl EUR/GBPJPY
(optimizer 0 survivors), Elephant/BRN207/GameChanger (artifact/martingale proven by sweep).

---

## HOW TO USE
1. New or revisited EA → run Step-0 gates first. Any fail = DISQUALIFIED, stop.
2. Passes gates → score A–D, attach confidence tag = how it was tested.
3. Band the score → verdict. A <40 score with ★ confidence is PARKED, not DEAD.
4. Record the row here. Never kill silently.
Canonical scoring reference: `D:\EA_LAB\docs\RECOVERED_PLATFORM_DESIGN_20260614.md` (BacktestScore v1).
