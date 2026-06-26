# EA SCORECARD & REGISTRY — canonical scoring + audit trail
**Created 2026-06-23.** Purpose: make every keep/kill decision **transparent and reproducible**.
No EA is "dead" without a recorded reason AND a confidence tag saying how thoroughly it was tested.
A kill made on a smoke test (★) is LOW confidence and must be re-examined before it is final.

---

## PART 1 — THE SCORING RUBRIC

### Step 0 — HARD GATES (any one fails → DISQUALIFIED, do not score further)
These are *structural* gates — failure modes that **cannot be tuned away** by sizing or spacing.
| Gate | Fail condition | Why it's structural (not sizing) |
|---|---|---|
| **Uncapped martingale** | lot scales on losses with **no step cap** (or cap so high a plausible streak still ruins) | doubling outruns any deposit; not fixable by lot — only by capping steps |
| **Uncapped grid / no hard SL** | keeps adding positions with no binding cap AND no per-position SL | floating DD is unbounded + invisible to closed-trade stats |
| **Expired / locked .ex** | license/time-expired, won't trade live | un-deployable — validation effort wasted (KRAPOOK lesson) |
| **Model-2 tight-TP artifact** | TP < spread; PF collapses when TP×10 | "edge" is open-price fill fiction, not real |

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
| Gold Reaper 4.3 | XAUUSD H1 | 2.07 | — | ★★★ | **CORE** ⚠️ | ruin 1.9% — watch |
| EA_BREAKOUT_XAU | XAUUSD H1 | 1.77 (M4) | 0.65 | ★★★ | **CANDIDATE** | BUY-only regime risk; thin OOS 33t |
| LondonConsoBreakout | GBPUSD H1 | 2.08 | 0.10 | ★★★ | **CANDIDATE** | 3/3 OOS; GBP concentration |
| LondonConsoBreakout | EURUSD H1 | 1.25 | 0.13 | ★★★ | **DROP (was #8)** | Q2 rescue sweep (48 combo×3 win) DONE — NO combo passes all 3 at PF≥1.2; best min-PF 0.92, both OOS <1.0. No durable edge → remove from portfolio |

### MT5 — FRAMEWORK / IN-PROGRESS
| EA | Sym/TF | Result | Conf | Verdict | Notes |
|---|---|---|---|---|---|
| EA_RUNNER_ST03 (ST_EA03 replica) | GBPUSD H1 | **LR2: M4 IS 8.31 / OOS 3.93** | ★★☆ | **CANDIDATE — robustness MARGINAL** | 2026-06-26: NEW WINNER **LotRepeat=2** (tp3=50/near=50) beats v1 LR3 on all windows with ~half the crisis tail → `ST03_optimized_v2.set`. **MC** (229 calm trades): PF5th 2.92, ruin 0%, but **PF-range 20.5** (edge magnitude unstable). **OOS:** no degradation (IS 8.31→OOS 3.93). **Crisis pass (KEY):** every real crisis PF<1 → edge is **calm-only**. Worst **Brexit2016 EqDD 3.51%@1× (M1 floor, real worse)** → **~42%@12× ⇒ 12× REJECTED**; 2022 14.04%@12× (margin 3155%, no stop-out). **Deploy ≤3× (really 1×), GBPUSD-only.** **hard SL = DEAD END** (proven: any SL kills calm edge 4.69→~1.2, still PF<1 in crisis — supersedes old "add SL" note). **WFA 6-window (fixed params, M1 2020-25): 4/6 profitable, PF 0.24-3.81 — but LOST 2021H2 (0.24) AND most-recent 2025H1 (0.43)** → edge is regime-dependent and currently WEAK; 2024's 8.31 was a good regime, not permanent. NEXT high-value = **crisis/volatility regime filter** (sit out high-vol → removes tail → unlocks safe sizing AND may recover the WF3/WF6 losing regimes). Deploy = small + LIVE-MONITOR first 30 trades. ST_EA03 already live (CORE). |

### MT5 — FRESH TEMPLATE EAs (built 2026-06-22)
| EA | best smoke | Conf | Verdict | Kill reason / re-exam |
|---|---|---|---|---|
| (Boss)_SessionBreakout_rev01 | XAU M15 PF 1.04 | ★★★ | **DEAD** | 1,200-pass EXHAUSTIVE sweep ceiling 1.20 + forward 0.91. Thoroughly killed — do NOT revisit |
| (Boss)_RSI_Swing_BB_rev01 | EUR H1 PF 1.03 | ★★☆ | **DEAD (confirmed 2026-06-23)** | RE-EXAMINED: 27-combo sweep EURUSD IS+OOS, best min-PF **0.99** (breakeven), nothing ≥1.2. "Martingale was the edge" CONFIRMED — naked signal has none. Kill upgraded smoke→optimized |
| (Boss)_TrendRegression_rev01 | XAU H1 0.81 | ★★☆ | **DEAD (confirmed 2026-06-23)** | RE-EXAMINED: 27-combo sweep XAUUSD IS+OOS, best min-PF **0.91**, all losing. Reversion-on-trend has no gold edge (matches momentum>reversion thesis). Kill upgraded smoke→optimized |
| (Boss)_NRBreakout_rev01 | 0.82–1.03 | ★★☆ | **PARKED→lean DEAD** | partial sweep, all sub-gate; low prior. RE-EXAMINE only if idle |

### MT5 — SIGNAL/FILTER RESEARCH (EA_RUNNER family)
| Signal | Sym | IS PF | Conf | Verdict | Reason |
|---|---|---|---|---|---|
| MACD crossover | GBPUSD H1 | 1.11 | ★★★ | **DEAD (ceiling)** | structural ceiling; ALL filters (RSI/EMA/ZLF/count) top ~1.0–1.11 |
| MACD crossover | EURUSD/USDJPY/AUD/NZD/USDCAD/EURGBP/+JPY crosses | ≤1.16 | ★★★ | **DEAD** | exhaustive multi-symbol sweep, all fail OOS |
| BB+RSI mean-reversion | EURUSD/XAUUSD | ≤1.11 | ★★☆ | **DEAD** | same ~1.1 ceiling as MACD |
| BREAKOUT (LabTpl) | EURUSD/GBPJPY | ≤1.03 | ★★★ | **DEAD** | optimizer 0/180 & 0/175 survivors — edge is XAU-specific |

### MT4 — SCREENED (63 EAs, 0 deployed)
| EA | screen PF | Conf | Verdict | Reason |
|---|---|---|---|---|
| EA_Golden_Elephant/Mammoth | XAU 4.08 | ★★★ | **DISQUALIFIED→DEAD** | grid; TP200→2000 collapsed PF 7.77→0.06 = tight-TP artifact |
| KRAPOOK BLUE ANT | XAU 2.65 | ★★★ | **DISQUALIFIED** | EA EXPIRED (best profile of pool but un-deployable). Technique (distance-scaling) saved for reuse |
| BuRengNong207 | XAU 1.76 | ★★★ | **DISQUALIFIED** | martingale-only (mult=1.0 → 0/9 pass); no signal under it |
| EURUSD Forex Robot | EUR 3.89 | ★★☆ | **WATCH/PARKED** | NOT martingale (scrutinize cleared it); disqualifier = THIN sample (48t). Needs deep-data re-test |
| Espresso_Gold/Fx Setka/Little Birds/KRAPOOK Yellow | — | ★★☆ | **DISQUALIFIED** | catastrophic DD 60–125% (grid/martingale) |
| EA Game Changer/GMGS PRO | XAU high | ★★★ | **DEAD** | Model-2 tight-TP/hedge-grid artifact (TP×10 confirmed) |
| ~45 others | — | ★★☆ | **DEAD/REJECT** | structural (NO_DATA/init-fail), commercial-locked, or grid. See [[mt4-screening]] |

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
