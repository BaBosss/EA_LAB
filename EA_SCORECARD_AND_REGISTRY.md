# EA SCORECARD & REGISTRY — canonical scoring + audit trail

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · ไฟล์นี้ owns: **ทะเบียน EA · scoring rubric · kill-reason** เท่านั้น
**Created 2026-06-23.** Purpose: make every keep/kill decision **transparent and reproducible**.
No EA is "dead" without a recorded reason AND a confidence tag saying how thoroughly it was tested.
A kill made on a smoke test (★) is LOW confidence and must be re-examined before it is final.

---

## PART 0 — CANONICAL VERDICT VOCABULARY (adopted 2026-07-18, framework Part 4)

**Every NEW verdict uses ONE of these 7 terms** (owner = `CLAUDE.md` VERDICT GATE tree + bar table):
`DEAD-STRUCTURAL · DEAD-OPTIMIZED · PARKED-VERIFY(user) · BUILD-ON · CANDIDATE · DEMO · LIVE`

Legacy verdicts below are **kept verbatim in historical rows** (audit trail — do not rewrite them) but
read them through this one-time map. The retired vocabulary (PASS/CONDITIONAL/ROBUST/MARGINAL/Mode-B) came
from the now-demoted robustness-validator + backtest-report-analyzer calculators and no longer decides anything.

| Legacy term | Canonical reading | Note |
|---|---|---|
| DISQUALIFIED (hard gate) / REJECT-structural | **DEAD-STRUCTURAL** | uncapped-ruin · cracked · expired · flat-lot PF<1 · fill-artifact |
| DEAD / REJECT-after-optimize | **DEAD-OPTIMIZED** | earned terminal after full ladder + last-optimize on right home |
| PASS / ROBUST (Mode A) | **CANDIDATE** (→ DEMO if deploy funnel cleared) | passed screening/robustness ≠ deployed |
| CONDITIONAL / MARGINAL / Mode-B / CANDIDATE_WEAK | **BUILD-ON** or **PARKED-VERIFY(user)** | PF>1 under deploy bars → buildable, never a silent kill |
| WATCH | (interim) **BUILD-ON** band | smoke 1.0–1.2, not yet optimized |

New verdicts must NOT introduce PASS/CONDITIONAL/ROBUST/etc. — write the canonical term, tag confidence, record kill-reason.

---

> ⚠️ **HISTORICAL RUBRIC (frozen 2026-07-18)** — คะแนน/แถบคะแนนด้านล่างใช้เป็น intake evidence เท่านั้น **ห้ามใช้ตัดสิน deploy** — verdict authority เดียว = VERDICT GATE ใน CLAUDE.md (vocabulary: DEAD-STRUCTURAL/DEAD-OPTIMIZED/PARKED-VERIFY/BUILD-ON/CANDIDATE/DEMO/LIVE)

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

### MT5 — LIVE PORTFOLIO (deployed 2026-06-22) — ⛔ HISTORICAL, SUPERSEDED 2026-07-09
> **อย่าใช้ตารางนี้เป็นสถานะ deploy ปัจจุบัน** (CODEX-AUDIT 2026-07-11: ตารางนี้เคยถูกอ่านเป็น authority ทั้งที่ค้าง)
> สถานะจริง = `DEMO_DEPLOYMENT_PLAN.md` §"DEPLOYMENT REALITY 2026-07-09" เท่านั้น · verdict ที่ทับแถวในนี้:
> **ST_EA03 (ทั้ง GBP/USDCAD) = STRUCTURAL no-edge (ORDER-068/071, flat-lot PF 0.68/0.40) — ไม่ใช่ CORE แล้ว, แล็บแนะนำถอดจากบัญชีจริง** ·
> **Gold Reaper + LondonConso = แล็บ REJECT** (ยังรันอยู่บน 159475669 เป็นการทดลองของ user เท่านั้น แล็บไม่รับรอง)
| EA | Sym/TF | OOS PF | DD% | Conf | Verdict | Notes |
|---|---|---|---|---|---|---|
| MG_v1 MatchaGrid | CHFJPY M15 | 2.08 | — | ★★☆ | **PARKED-VERIFY(user)** — เดิม CORE (ORDER-215) | ตรวจ ini จริง 2026-07-25: **พารามิเตอร์ถูกเลือกบน `OPT_MG_CHF_lowDD.ini` = genetic, Criterion 0 (เข็มทิศชี้ spike), window `2023.01–2026.06` ที่กิน holdout, ไม่มี fine-grid ไม่มี fan** · ตัวเลข OOS 2.08 มาจาก `MG_CHFJPY_OOS.ini` window `2020.01–2023.01` ซึ่ง**สะอาดจริงและเป็น OOS จริง** → นี่คือเหตุผลที่ยังไม่ตีตก แต่ CORE ยืนบนขาเดียวไม่ได้. grid bounded+SL. **ACTIVE บนเงินจริง REAL_CENT 159475669 magic 20240001** (user mix) → owed: clean-MAIN re-measure + fan + flat-lot probe + Model-4 (grid ⇒ M4 บังคับ) ก่อนจะเรียก CORE ได้อีกครั้ง |
| NuiIndy RSI+ADX | EURUSD H1 | 2.00 | — | ★★☆ | **CORE (edge=escalation ⚠️)** | 2026-07-17: PF2.0=geometric martingale, NOT signal edge (single-order 0.90/flat-lot 0.72). As-shipped uncapped-ruin (MAX_Order 99999/CutLoss 100). **Expansion REJECTED.** 🔴 **2026-07-26 (ORDER-222): "CutLoss=30 = free tail-insurance" WITHDRAWN.** Tested at a DD that reaches it: cuts 30% of *current* balance then re-arms against the smaller balance = ratchet, not floor (8 cuts/yr at 4× sizing, 10,521→1,326, eqDD **87%** with the 30 threshold ON; same year +51% off vs −86% on). The old "DD bounded ~15%" was the switch **never firing**. Keep the mechanism, drop the claim; an account bound needs an absolute equity floor that fires once. At live sizing it still never fires → no forced live change, owner's call. `_triage/ORDER222_NUIINDY_CUTLOSS_VERDICT.md` · `_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md` |
| ST_EA03 MACD | GBPUSD H1 | 2.47 | — | ★★★ | **CORE** | count+tiered-TP scalp |
| ST_EA03 MACD | USDCAD H1 | 2.62 | — | ★★★ | **CORE** | |
| Gold Reaper 4.3 | XAUUSD H1 | 2.07 | — | ★☆☆ | **REJECT — user-mix, lab ไม่รับรอง** (ORDER-214) | แถวนี้เคยเขียน `CORE ★★★` **ซึ่งขัดกับ banner ของหัวข้อตัวเองที่บอกว่าแล็บ REJECT** — แก้ให้ตรงกัน 2026-07-25. หลักฐานที่หนุน "2.07" **ไม่เคยผ่าน plateau-check เลย**: ยืนยันเองแล้วจาก `QWEN_GR_opt.xml` — 5 pass ให้ค่าเท่ากันทุกหลัก (Profit 267741.38 · PF 2.349244 · Trades 2548 · DD 13.8505 ซ้ำ ×5) = **null result** เพราะ `Risk=1234` internal-lot mode ทำให้ `StartLots` ที่ optimizer กวาดไม่มีผล + window `2023.01–2026.06` ยังกิน holdout อีก. รันอยู่จริงบน REAL_CENT 159475669 8 leg (magic 8001..8015) = **การทดลองของ user ไม่ใช่ของแล็บ** |
| EA_BREAKOUT_XAU | XAUUSD H1 | **1.98 MAIN / 1.66 BWD (M4, clean)** | 0.65 | ★★★ | **CANDIDATE** | ⚠️ เลขเดิม `1.77 (M4)` มาจากหน้าต่างที่กิน 2026H1 — แทนที่ด้วยเลขสะอาด ORDER-202/210 (v2 = Bars40). v3 (Bars55) ชนะเฉพาะหน้าต่างที่ไหม้, BWD 1.01 → **ห้ามใช้**. re-optimize สะอาดหา config ที่ชนะ v2 ทั้งสองหน้าต่างไม่เจอ (ORDER-210). BUY-only regime risk; thin 30-50t/3yr = ข้อจำกัดถาวร; 2026H1 spent → forward = holdout |
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
| EA | สถานะ | Conf | Verdict | Reason |
|---|---|---|---|---|
| **(Boss)_RSI_MR_GridLog_rev01** (EURUSD H1, magic 990103) | full pipeline จบ 2026-07-08: holdout + MC + **WFA ครบ** (~74 backtest) + ORDER-182→186 continuous-span funnel (2026-07-23) | ★★★★ | 🟢 **ACTIVE demo (attached 2026-07-24, user confirmed) — 463666728 EURUSDm, judge 2026-10-24** | ORDER-182: WFA เดิม (ORDER-168) ใช้ 3 window แยกกัน (equity reset ทุกรอบ) ซึ่ง**เป็น methodology ที่ผิดสำหรับ basket EA ตัวนี้** (dual-side, MaxPositions=8, LOG escalation — skill เตือนไว้ว่า stitched windows หลอกได้ ~10x). รัน continuous single-span ใหม่บน full-pinned config เดียว (atr9): **both-window PF เท่ากันเป๊ะ 1.37(MAIN,280t)/1.37(BWD,267t)** = plateau จริงไม่ใช่ spike, ดีกว่า WFA เดิมมาก (fold2 OOS 1.08 = artifact ของการ chop window). flat-lot: MAIN 1.33 (entry มี edge จริง) แต่ BWD 0.82 (ต้องพึ่ง escalation ในโหมด trend) — **ไม่ใช่ ENGINE-EDGE เต็มรูปแบบ**. MC PF-5th 1.116 ruin 0%. **holdout 2026H1 ล้ม (0.73/n=26)** แต่ n บางเข้าข่าย inconclusive → LADDER Step 6: PF>1 ที่อื่น ⇒ BUILD-ON ไม่ใช่กลับ diagnosis. lever coverage ยังแค่ 1/3 (spacing เท่านั้นบน pinned data) → ยังไม่ CANDIDATE. **🔴 basket-duration tail พบเพิ่ม (`max_recovery_days.py`): max recovery MAIN 159 วัน / BWD 292 วัน (เกือบ 10 เดือน!)** — DD 8.07%/5.35% ไม่เห็น time-underwater นี้, ต้องตอบก่อน CANDIDATE ว่า capital ล็อก 5-10 เดือนรับได้ในบริบทพอร์ตจริงไหม. raw `_mt5_auto/RSIMR_CONTINUITY_CHECK.csv` + sets `_mt5_auto/ab_sets/rsimr_continuity_check/`. **ORDER-183 (2026-07-23) lever 2/3 done:** RSI band × SL-width coarse grid — พบ plateau ที่ **RSI25/75+SL25 ดีกว่าทุกมิติ**: both-window **MAIN 1.96/BWD 1.56** (สูงกว่า baseline 1.37/1.37 ทั้งคู่, DD ต่ำกว่า), basket-duration สั้นลง (max MAIN 98.4d/BWD 182.1d เทียบเดิม 159/292d). **holdout ยังล้มเท่าเดิม (0.76/n=21)** — พิสูจน์ว่า 2026H1 อ่อนจริงในตัวเอง ไม่ใช่ config artifact (คนละ config ได้ผลเดียวกัน). **lever coverage ครบ 3/3 แล้ว** (spacing+entry-threshold+SL) แต่ VERDICT GATE ยังไม่ให้ CANDIDATE จนกว่า holdout จะผ่าน → คง **BUILD-ON**, เสนอ lock RSI25/75+SL25 แทน baseline ถ้าเดินหน้าต่อ. raw `_mt5_auto/RSIMR_LEVER2_SWEEP.csv` + sets `_mt5_auto/ab_sets/rsimr_lever2/`. **ORDER-185 (2026-07-23) sensitivity fan done (LADDER Step 5):** ±20% fan รอบ RSI25/75+SL25 (รวม frozen DistAtrMult axis) — **ทุก 1 ใน 8 variant ยัง PF>1 ทั้ง MAIN/BWD ไม่มี flip ลบเลยสักตัว** = plateau ที่แข็งแรงที่สุดในบรรดา EA ที่เทสวันนี้ทั้งหมด. **lever ครบ 3/3 + fan ผ่านสมบูรณ์ = เหลือแค่ holdout เป็นด่านเดียว** (เหมือน pattern XAGUSD/LondonORB วันนี้). คง BUILD-ON. raw `_mt5_auto/RSIMR_SENS_FAN.csv` + sets `_mt5_auto/ab_sets/rsimr_fan/`. **ORDER-186 (2026-07-23) full MC on new center — funnel closed for today:** PF-5th **MAIN 1.544 / BWD 1.209** (both clear comfortable ≥1.2, up from baseline's 1.116), DD95 1.38%/2.40%, ruin 0%. **Funnel complete except holdout** (0.76/n=21, same regime-fail as baseline, confirmed not fixable by tuning) — same pattern as XAGUSD and LondonORB today (both just attached to demo despite thin holdout). **Recommended config = `_mt5_auto/ab_sets/rsimr_fan/RSIMR_CENTER.set` (RSI25/75+SL25+Dist9)**, replacing the old atr9/RSI30-70 baseline. **User 2026-07-23: queued for demo-isolate; ATTACHED 2026-07-24 (user confirmed)** — DEPLOYMENTS.csv row live (463666728 "Demo bundle 10", EURUSDm, ACTIVE, DD15%, judge 2026-10-24), bundle `_vps_deploy/RSI_MR_EURUSD/`. Successful attach implicitly confirms 463666728 is Hedging-mode (the pre-attach open question). **Hand off to `ea-live-monitor` for ongoing tracking** — remember this EA's holdout genuinely failed (0.76, not just thin) going in; don't misread the first losing stretch as new information, that's already priced into the accepted-exception decision. |

| EA | Sym/TF | Result | Conf | Verdict | Notes |
|---|---|---|---|---|---|
| EA_RUNNER_ST03 (ST_EA03 replica) | GBPUSD H1 | **LR2: M4 IS 8.31 / OOS 3.93** ⚠️ **superseded 2026-07-02: full-window OOS 2025.01–2026.06 M4 = PF 0.86 (585t) + STEP3 grid 48/48 combos OOS<1.0 → LOOP CLOSED, fallback (ดู `EA_CORE_ST03_LOOP_PLAN.md` STEP 5). demo 990010 = WATCH เก็บ data.** | ★★☆ | **CANDIDATE — robustness MARGINAL** | 2026-06-26: NEW WINNER **LotRepeat=2** (tp3=50/near=50) beats v1 LR3 on all windows with ~half the crisis tail → `ST03_optimized_v2.set`. **MC** (229 calm trades): PF5th 2.92, ruin 0%, but **PF-range 20.5** (edge magnitude unstable). **OOS:** no degradation (IS 8.31→OOS 3.93). **Crisis pass (KEY):** every real crisis PF<1 → edge is **calm-only**. Worst **Brexit2016 EqDD 3.51%@1× (M1 floor, real worse)** → **~42%@12× ⇒ 12× REJECTED**; 2022 14.04%@12× (margin 3155%, no stop-out). **Deploy ≤3× (really 1×), GBPUSD-only.** **hard SL = DEAD END** (proven: any SL kills calm edge 4.69→~1.2, still PF<1 in crisis — supersedes old "add SL" note). **WFA 6-window (fixed params, M1 2020-25): 4/6 profitable, PF 0.24-3.81 — but LOST 2021H2 (0.24) AND most-recent 2025H1 (0.43)** → edge is regime-dependent and currently WEAK; 2024's 8.31 was a good regime, not permanent. **VOL-GATE BUILT + TESTED (ATR>1.5×ATR_MA(300), `InpVolGateOn`, `ST03_volgate_v1.set`): PARTIAL.** Saves SPIKE/gap events (Brexit2016 −218→+94, cut 2 tail trades) at ~0 calm cost (OOS 3.93→3.70). But does NOT fix sustained-TREND crises (COVID/gilt/2025/2021 unchanged — they bleed across many trades, not ATR spikes). **TREND/ADX GATE (ST03B `EA_RUNNER_ST03B`, ADX>30): FALSIFIED — counterproductive.** Made every crisis WORSE (Brexit −218→−281, COVID −49→−66) AND cut calm −21%. Reason: ADX LAGS — by ADX>30 the trend is mature/reverting (exactly when this strategy should harvest), so the gate removes the GOOD reversion trades and keeps the early-trend losers. **CONCLUSION: the crisis tail cannot be filtered out reactively** (vol=gap-only, trend=counterproductive) → **cannot size up safely.** Real "more profit" path = **diversify across symbols + portfolio** (small uncorrelated legs), NOT leverage. **TF: H1 optimal** (M30 1.86 / M15 1.48 vs H1 8.83 — spread eats the 5pip target on lower TF). **PER-SYMBOL re-attempt (LR2 params + grid, IS+OOS held-out): GBPUSD-only re-confirmed at M4.** EURGBP no edge (IS<1); USDCAD OOS<1.2; EURUSD looked viable at M2 (OOS 1.28-1.85) but **COLLAPSED at M4 (OOS 0.54-0.74)** — classic Model-2 optimism for a no-SL tight-target (spread eats the 3-5pip target at real ticks). Deploy = small + LIVE-MONITOR first 30 trades; vol-gate optional gap-insurance. **PORTFOLIO CORRELATION (data-driven, 36mo 2020-22, portfolio_analysis.py):** corr vs live ST_EA03 GBPUSD (MACD_GBPUSD) = **−0.24 (LOW, NOT redundant — earlier assumption corrected).** The v4 replica behaves differently from the fxDreema full ST_EA03 (replica bleeds in 2022; the live one's recorded monthly series doesn't). corr vs all live legs is LOW (MG −0.47, Nui −0.01, USDCAD −0.35, Gold +0.41) — but the negative corr is mostly because the replica LOSES when others win (net −262 over 2020-22), i.e. it's the weaker leg, not a prized diversifier. ⚠️ DATA CONFIDENCE PARTIAL: the live EAs' monthly series are all-positive (max-DD 0% over 3yr = likely optimistic/in-sample) → DD-overlap math degenerate. Verdict: low-corr so it CAN sit in a separate portfolio, but small weight only (MARGINAL + crisis-bleed). Value = framework-controlled PoC + diversification *if* live-monitored. ST_EA03 already live (CORE). **⚠️ UPDATE 2026-07-19 (ORDER-119, owner-override rescue round): removed from all live accounts (ORDER-118 obsolete). Chassis Boss_15 lever-C flat-lot sweep (MACD Fast/Slow/Signal × CountBars, 18 combo × GBPUSD/EURUSD/EURGBP × H1/H4 × MAIN+BWD, 216 runs) = 0/6 cells PF≥1.0 both-window (best EURUSD H4 MAIN 1.15 / BWD 0.98) → DEAD-OPTIMIZED entry. Levers A (capped basket) + B (regime gate) NOT run: escalation on a no-edge flat-lot entry = martingale-is-the-edge (DEAD-STRUCTURAL). **ORDER-135 (lever A, ENGINE-EDGE cage): engine ALSO dead** — capped-basket DCA (MaxLevels{4,6,8}×LotProg{NONE,LIN,LOG} × GBPUSD-H1 + EURUSD-H4 × 2 window) = 0/9 both-window. DCA engaged (n +2.2×) but only leverages regime-dependence (winner-window +88→+140, loser −111→−177), worst-case eqDD 2.93% (cage-1 pass, but cage-2 BWD-hard fail). the generic chassis MM can't rescue the MACD signal (both flat-lot + generic-DCA). **⚠️ SCOPE (user 2026-07-19): this is CHASSIS-CELL dead, NOT concept-permanent. Boss_15 has signal parity 133/133 but MM is NOT parity — standalone EA_RUNNER_ST03 has tuned LOT_Repeat/tp3/near/spacing/vol-gate (30+ sets in worktree) = a different, historically-better machine, untested this round. STANDALONE ST03 = PARKED-VERIFY(user): user optimizes manually; a both-window winner reopens the funnel. Open levers: spacing UNSWEPT, per-symbol TP×exit, LR-depth×vol-gate.** handoff `_triage/_archive/handoffs_closed/HANDOFF_ST03_OPTIMIZE_2026-07-19.md`. evidence `_triage/_archive/verdicts/order104-126/ORDER119_LEVERC_RESULTS.md` + `_triage/_archive/verdicts/order135-149_results/ORDER135_ENGINE_RESULTS.md`.** |

### MT5 — VALIDATED RESERVE (ผ่าน gate แต่ยังไม่ deploy — ตรวจ 2026-07-02)
| EA | Sym/TF | IS PF | OOS PF | Conf | Verdict | Notes |
|---|---|---|---|---|---|---|
| EA_KAUFMAN_ER (BuyOnly) | XAUUSD H4 | 2.34 (50t) | 5.19 (17t) | ★★☆ | **CANDIDATE — reserve (user decision 2026-07-02: เก็บก่อน ไม่ deploy)** | re-confirm 2026-07-02 (`KER_RECONF_*`, M2) ตรงตัวเลข 06-28 เป๊ะ. DD 5.1%. จุดอ่อน: OOS บาง 17t (H4 → ~2 ปีกว่าจะครบ 30 live trades) · **corr 0.946 vs EA_SUPERTREND** (sibling — ห้าม deploy คู่) · corr 0.75 vs BRK8 live → ถ้า deploy = 0.01 lot · เป็น XAU-long bet ซ้อน BRK55/BRK8/GR ที่ live อยู่. **เงื่อนไขก่อน deploy จริง: (1) M4 confirm 1 รอบ (บทเรียน M2-optimism จาก ST03 EURUSD) (2) แก้ invariant 9→10 EA + DEMO plan + check_state.ps1.** 💡 **idea จาก user (2026-07-02): เอา Kaufman ER (Efficiency Ratio) ไปใช้เป็น "ตัวบอกทิศ/regime filter" ให้ EA อื่น** — เข้าทาง vol-gate/regime line ใน EDGE_CATALOG; ถ้าจะลอง → เพิ่มเงื่อนไข ER เข้า EA ที่มี edge อยู่แล้วแล้ววัด A/B, ไม่ใช่สร้าง EA ใหม่. set พร้อม: `_vps_deploy/KAUERMAN_buyonly_live.set` (magic 990127) |
| Boss_16_KangarooGrid | XAUUSD **H1** | MAIN 1.46 (205t) | BWD 1.30 (278t) | ★★★ | **CANDIDATE — PENDING_ATTACH (demo)** | เพิ่มแถว 2026-07-25 (ORDER-213) — เดิมไม่มีใน scorecard ทั้งที่รอ attach อยู่. เลขข้างซ้าย = **หน้าต่างสะอาด** (ORDER-202 re-run); **ห้ามใช้ 1.57/285t เดิม** (funnel ORDER-078 รันถึง `2026.07.01` มีแถว year-split `2026H1 PF 1.75/85t`). ผ่านทั้ง hard bar 1.2 และ soft bar 1.0 สบาย = edge จริง. **2026H1 ไหม้ ⇒ demo-forward = holdout** (นี่คือ precedent "Boss_16" ที่ CLAUDE.md อ้าง). **judge = attach + 5.5 เดือน ไม่ใช่ 3** (5.7 เทรด/เดือน ⇒ 30 เทรดใช้ ~5.3 เดือน; บาร์ 3 เดือนผ่านไม่ได้ไม่ว่าผลจะดีแค่ไหน). bundle + SHA256 ที่ต้อง verify = `_vps_deploy/BOSS16_KANGAROO_XAU/README_ATTACH.md` — **`.ex5` ใน `ea_template/` เก่าค้าง ไม่มี `_16_BaseLotMode` ห้ามใช้** |
| EA_SUPERTREND v1 naked | XAUUSD H4 | 1.92 (33t) | 5.09 (17t) | ★★☆ | **PARKED — แพ้ KER** | rerun 2026-07-02 (`STV1_XAU_RECONF_*`) ผ่าน gate แต่ corr 0.946 กับ KER ที่ดีกว่าทุกด้าน → เก็บเป็น fallback ของ KER. (SuperTrend "DEAD" ใน signal hunt = คู่เงินอื่น; XAU H4 ตัวนี้รอด) |

### MT5 — FRESH TEMPLATE EAs (built 2026-06-22, +1 built 2026-07-03)
| EA | best smoke | Conf | Verdict | Kill reason / re-exam |
|---|---|---|---|---|
| (Boss)_ZeusInspired_GridLog_rev01 | AUDUSD H1 IS 1.63→OOS 1.78 (retention 1.09) | ★★☆ | **CANDIDATE — AUDUSD + AUDJPY confirmed via IS/OOS, portfolio not yet deployed** | Original design (L3 redesign of Zeus Gold Hedge behavior — `ZEUS_GOLD_HEDGE_ANALYSIS.md` §5.9-5.11). Screened 27 FX symbols total (no gold — user call), Model 1 minimum for every reported number after 2 same-day Model-2 false positives (AUDCAD 1.80→0.89, AUDNZD 1.96→1.06). **Survivors after IS/OOS split (IS=2025 H1-H2, OOS=2026 H1-mid):** AUDUSD retention 1.09 (OOS beats IS — strongest), AUDJPY retention 0.87 (passes ≥0.8 gate). **EURCAD DROPPED** — looked fine full-window (PF 1.23 @ DD 13.39%) but failed OOS outright (retention 0.53, net negative) — reinforces IS/OOS over single-window trust. DD-scaled to 10-20% band (base_lot + `_04_TpUsd` must scale together — fixed-$ TP breaks proportionally otherwise, found the hard way): AUDJPY 20x → PF 1.91/DD 14.73%/net $2,780/18mo/Sharpe 2.02; AUDUSD 20x → PF 1.22/DD 12.92%/net $1,043/Sharpe 0.32. Monte Carlo (order-resample, DD-only distribution — net/PF are order-invariant sums) flags AUDUSD's observed DD as possibly favorable-luck (95th pctile 16.55%, worst 26.04% vs observed 12.92%); AUDJPY/EURCAD more stable under reshuffle. **Correlation:** AUDUSD/AUDJPY 0.554 (WATCH — run both, reduced lot); AUDUSD/EURCAD 0.708 (HIGH — don't combine, moot now EURCAD is dropped); EURJPY near-zero corr with all three (-0.003 to -0.093) despite weak own edge (PF~1.04-1.09) — diversifier-only role, small lot. GBPAUD/USDJPY/EURCHF hold up at Model 1 but too thin (12-18 trades) to trust yet. **✅ MC on DD-scaled configs + portfolio combine DONE 2026-07-03 (รอบ 2):** MC 5000-iter on lot20x reports — AUDUSD DD med 10.62%/95th 16.55%/worst 26.04%, AUDJPY DD med 6.80%/95th 11.22%/worst 18.18%, ruin 0%, P(loss) 0% both. **Combined portfolio (closed-trade merge, 17mo):** full-lot net +$3,824 PF 1.48 balDD 10.85% but MC-95th 16.92% (over 15% budget) → **0.7x both = recommended: MC-95th 12.44%, net +$2,677, fits 10–15% DD budget** (scale `_05_BaseLot`+`_04_TpUsd`+`_06_MaxTotalLot` together). DD overlap minimal — both-negative months 1/17, but that month is **2026-06 (most recent)** → watch on demo. Caveat: balance-curve analysis; combined FLOATING DD not measurable from closed trades (per-leg equity DD 12.92%/14.73% — real combined floating DD = demo's job). Analysis script: scratchpad `zigl_portfolio_combine.py` (session 2026-07-03). **🔴 BACKWARD-OOS 2023–2024 (2026-07-03 รอบ 3 — unseen data, Model 1, lot20x sets, qwen-run, data quality 100% all): VERDICT เปลี่ยน.** ตัวเลขเต็ม → `_mt5_auto/ZIGL_BWD_OOS.csv`. **AUDUSD = REJECT for deploy:** แทบไม่เทรดก่อน 2025 (2023: 4 เทรด, 2024: 8 เทรด vs 86 ใน 18mo ของ 2025-26) และปีที่เทรดจริง (2024) ขาดทุน PF 0.41 — OOS 1.78 ที่เคยผ่านคือ same-regime 2025-26 ไม่ใช่ durable edge. **AUDJPY = CONDITIONAL:** กำไรทั้ง 3 ปี (PF 1.17 / 3.80 / 1.91) เทรดสม่ำเสมอ (69/41/54) **แต่ 2023 eqDD 36.07% ที่ 20x = ทะลุ budget** — พิสูจน์ caveat MC-optimism ของจริง (MC worst จาก 2025-26 trades = 18.18% แต่ปี hostile จริงคือ 36%). Re-size ตาม 3-year worst DD: 15%/36% ≈ 0.4× → **lot8x** (BaseLot 0.16/TpUsd 160/MaxTotalLot 4.8 — set สร้างแล้ว `ZeusInspired_AUDJPY_lot8x.set`), คาด net ~$1.1k/18mo ที่ 2025-26 pace. Full-window 2023–2026 confirm run ที่ 8x กำลังรัน (`ZIGL_AUDJPY_lot8x_FULL3Y_M1`). แผนพอร์ตรวม 2 symbol @0.7x = **ยกเลิก** (AUDUSD ตก) → AUDJPY solo. **🏁 FINAL (2026-07-03 รอบ 4): 8x full-window 2023–2026 confirm = eqDD 12.17% ✅ เข้า budget แต่ PF 1.12 (186t, Sharpe 0.35, net +$656/3.5yr) ❌ ต่ำกว่า gate 1.20 → ตระกูล ZeusInspired ไม่มี config ที่ deploy ได้ภายใต้กฎเต็ม (3-year window + DD budget): AUDUSD = REJECT (regime-only) · AUDJPY = PARKED regime-dependent** (edge จริงกระจุก 2024–26; ปีเต็มที่ size ปลอดภัย = เหลือบาง). Report: `ZIGL_AUDJPY_lot8x_FULL3Y_M1.htm`. **มูลค่าที่เหลือ = mechanism ไม่ใช่ EA:** grid+LOG lot+ATR spacing แสดงชีวิตชัดใน 2024–26 → port เข้า Boss V2 เป็น Entry/GridLog module เพื่อเข้า sweep กลไก×symbol ตาม VISION (ไม่ใช่ deploy pilot แล้ว). Re-examine trigger: ถ้า AUD regime 2025-26 ดำเนินต่อจน history ยาวพอ หรือ sweep เจอ symbol ที่กลไกนี้ durable จริง. |
| **Boss_14_GridLog (mold entry, Zeus mechanism)** | 3 ตัว = demo-grade evidence → DEMO | ★★☆ | **DEMO cohort #1 (2026-07-04, scrutinized): AUDNZD** (990202) · **EURJPY** (990203) · **USDJPY** (990201) — sets `*_DEMO.set` (0.25x, `_4_DdAdaptiveOn=false` — ปิดเพราะอ่าน account-wide DD จะปนกับ EA อื่นบนบัญชีแชร์; ใน validation ไม่เคย trigger จึง neutral) · **ระดับหลักฐานตามจริง (อย่าอ่านเกิน):** หลักฐานอิสระ = fresh-OOS 12 เดือนก้อนเดียว/ตัว (USDJPY 2.77/106t แน่นสุด · AUDNZD 3.02/42t · EURJPY 2.15/23t บาง+confirm วนตัวเอง) — full-confirm/MC ทับ IS · ค้น ~700 configs แล้วใช้ OOS เดียวกรอง (multiple-comparison ไม่ได้แก้) · **ยังไม่ผ่าน Model-4 every-tick** (คิวเปิด) · MC worst 6-9% = ที่ 0.25x เท่านั้น (live 3-4x → ~25-35%) · **demo 3 เดือน = ด่านตัดสินจริง** · แนะนำ attach บน demo account แยก (kill-DD account-wide) · ⚠️ USDJPY+EURJPY short-JPY คู่ · GBPJPY WATCH · PARKED: GBPAUD/EURCAD · DEAD-opt: EURCHF/USDCHF · **cohort-2 verdict (2026-07-04): DEMOรอ M4 = AUDCAD 990204 (OOS 4.30, ทุกปีบวก) + CADJPY 990205 (thin) + EURUSD-SELL 990206 (diversity) · WATCH = USDCAD (ปีแพ้ 2023) + NZDUSD (ปีแพ้ 2025)** · LNBREAK DEAD-optimized (0/81) · NRBreakout PARKED-final (ceiling 1.31) · **corr matrix 6-EA demo
(2026-07-04, ORDER-019): ไม่มีคู่ >0.60 — พอร์ตกระจายตัวดี, มีแค่ USDJPY-CADJPY=0.57 (watch, ลด lot
ไม่ตัด, ยัง 0.25x เท่ากันจึงยังไม่ต้องทำอะไร) · หลายเซลล์ NA (EURUSD สั้นกว่าเพื่อน) ต้องวัดซ้ำหลัง demo
สะสมเดือนมากขึ้น** · **SELL-side hunt จาก XML เดิม (ORDER-020): NZDUSD pass 29 สม่ำเสมอ 2 window
(full 1.94/76t · IS 2.03/55t) = candidate ใหม่ → fresh-start OOS คิวที่ ORDER-023 · GBPAUD-SELL
ตัดทิ้ง (dormancy ทั้ง 2 ทิศเหมือน BUY ที่ตายไปแล้ว) · EURUSD-SELL=ของเดิม (990206) · AUDCAD-SELL=thin**
· **NZDUSD-SELL fresh-start OOS (ORDER-023, 2026-07-04): ❌ PARKED (regime-dependent)** — OOS
2025.07-26.07 ดูดี (9t/PF1.47) เพราะคาบเกี่ยว 2026 ที่แข็ง แต่ full-window year-split เผย **2024 แทบ
ไม่เทรด (2t) + 2025 แพ้จริง (PF 0.88, -$29)** กำไรกระจุกแค่ 2023/2026 (2/4 ปีบวก) — ไม่ผ่านเกณฑ์
"ทุกปีบวก" ที่ AUDNZD/USDJPY/EURJPY ผ่านมาแล้ว → ปิดการล่า SELL-side รอบนี้** · **plateau-sensitivity
48-run (ORDER-022, 2026-07-04, ±20% ต่อแกน + SL 3.0/5.0 fixed): จัดอันดับความแข็ง AUDNZD (8/8 ผ่าน,
ที่ราบสมบูรณ์) > AUDCAD (5/8, ไม่มีพลิกลบ) > USDJPY/EURUSD (ปานกลาง, USDJPY มีรอยร้าวที่ step/TP แคบลง
พลิกขาดทุน) >> CADJPY (2/8, สันเขา — ยืนยัน "thin" เดิมด้วยหลักฐานใหม่) > **EURJPY (1/8, สันเขาชัดสุด —
baseline PF 2.49 คือจุดพีค ไม่ใช่ที่ราบ, ยืนยัน "fill-sensitive" เดิมด้วยหลักฐานอิสระคนละมิติ)** →
ก่อน promote จริง: EURJPY/CADJPY ต้อง size เบากว่าเพื่อน, USDJPY ห้ามลด step/TP ต่ำกว่าค่า DEMO เดิม**
· **Recovery-mode A/B บน AUDNZD champion (ORDER-024, 2026-07-05, first backtest ของ Recovery 81/82 ที่
สร้างไว้แต่ไม่เคยเทส): Mode 81 (Light) = ❌ REJECT ปิดถาวร** (PF 1.56→1.33, DD ขึ้น, 2024 พลิกลบ) ·
**Mode 82 (Adaptive) = ❌ REJECT ปิดถาวร (ORDER-025, 2026-07-05):** Model-1 รอบ 024 โชว์ 82 ดีกว่า (1.73>1.56)
= **artifact** — Model-4 real ticks บน AUDNZD เผยจริง: mode 80 PF 3.37/44t → **mode 82 PF 1.50/118t** (PF
ร่วงกว่าครึ่ง + เทรด 3× = recovery legs churn fill ไม่สวย). generalize ไม่ผ่าน (USDJPY PF ขึ้นแต่กระจุก
2023; AUDCAD PF **ลด** 1.88→1.78 net ขึ้นเพราะ churn). **สรุป Recovery ทั้ง 81+82 = ไม่มีค่าบน Boss_14,
ปิดคำถามถาวร** · **HEDGE_LOCK (ORDER-026) = dormant no-op** (HedgeMode=1 บน AUDNZD ได้ตัวเลขเหมือน baseline
เป๊ะ 1.56/195t — trigger 8% แต่ DD แตะแค่ ~4% ไม่เคยยิง) → **loss-management layer ทั้งหมด (Recovery+Hedge)
= ปิด branch, demo config 2-layer-OFF ถูกแล้ว** (re-examine Hedge เดียว: ถ้าอนาคตมี config DD>8%) ·
**บทเรียน: Model-4 บังคับก่อนเชื่อ mechanism ตระกูล grid/recovery — Model-1 หลอกได้ (fill-artifact ชั้นลึกกว่า Model-2)**
· **🆕 mold upgrade `_2_BasketTP_ATRmult` (ORDER-027, ATR-scaled basket TP, additive/default-off, tpl_regression
CLEAN verified) → ปลดล็อก non-FX** · **🥇 XAU GridLog = candidate #7 ใหม่ (in-sample, ORDER-027 scan):**
`_2_BasketTP_ATRmult=1` + `_33_SL_MaxPips=0` → **PF 1.76 / 508t / +$5,569 / eqDD 18.73% @0.25x** full-window —
non-FX diversifier ตัวแรก (ทอง vs พอร์ต FX grid) · ⚠️ IN-SAMPLE เท่านั้น, DD สูง (de-scale ตอน promote),
**ทอง+grid = ต้องผ่าน IS-opt→OOS→MC→Model-4 ก่อนเชื่อ (ORDER-028) + สงสัยสูงสุด (gold-grid graveyard prior)**
· **🐛 พบ portability bug: `_33_SL_MaxPips` (fixed-pip) เพี้ยนบน XAU 2-digit เป็น $1.50 → workaround =0, fix ถาวร ORDER-029B (ATR-relative SL cap, accepted CLEAN)**
· **XAU GridLog update (ORDER-030): ✅ ผ่านด่าน OOS — CONDITIONAL PASS** (OOS PF 1.15/196t, full 1.42/426t,
**ทุกปีบวก** 1.20/2.31/1.31/1.37) = candidate non-FX ตัวแรกที่รอด OOS · ⚠️ DD 27%@0.25x (de-scale ~ครึ่ง FX
ให้เข้า budget) + **Model-4 = ด่านชี้ขาด (ORDER-031) ก่อนขึ้น candidate จริง** · **XAG (ORDER-032) = PARK-thin**
(4 qualifying pass, high-PF เป็น 27t artifact — ทองแข็งกว่า) · **🎉 XAU GridLog = CANDIDATE #7 non-FX (ORDER-031,
ผ่านครบ pipeline): Model-4 real ticks net +$5,078/DD 19.95% (edge รอด ไม่ร่วงแบบ Recovery) · MC ruin 0%/P(loss) 0% ·
DEMO set `Boss14_GridLog_XAU_DEMO.set` (lot 0.05 de-scaled, magic 990207)** = non-FX diversifier ตัวแรกของพอร์ต ·
ต้องแก้ 2 portability bug ก่อน (basket-TP ATR-scale + SL cap ATR-relative) · leg เสี่ยงสุด (DD สูงสุด) จับตาพิเศษบน demo | **Sweep รอบ 1+2 (15 symbol, full-window 2023–2026 M1, per-year split) + optimizer probe 54-pass (complete, ranges ATR-relative ใช้ร่วมทุก symbol: `Boss14_GridLog_GBPAUD_opt1.set`):** ผล default params ตายเกือบหมด (มีแต่ GBPAUD 1.23 / AUDNZD 1.30 ที่รอด) **แต่ optimizer probe กู้กลับ 3 ตัว — พิสูจน์ user rule "ห้าม DEAD ก่อน optimize" ในวันเดียวกับที่ตั้งกฎ:** **GBPAUD = PARKED (2026-07-04, pipeline เต็มจบรอบแรก):** IS-opt (no-look-ahead ยืนยันด้วย controlled rerun) PF 1.71/88t + MC ผ่าน (DD worst 7.97%, ruin 0%) **แต่ตก fresh-start OOS 2025.07–26.07: 23t, PF 0.49, -$329** — ชนะเฉพาะ trend 2023–H1'25; ใน range แพ้ทุก config = regime-dependent แบบ Zeus · chained run ดูสวยเพราะ dormancy หลับข้ามช่วงร้าย → **กฎใหม่: fresh-start OOS บังคับก่อน demo ทุก candidate ตระกูลนี้** (sets: `GBPAUD_p26/IS_p26`) · 🥈 **EURJPY** 13/54 passes ≥1.2&n≥60, best PF 2.49 (114t, +$2,586, dd 6.0%) — default ได้แค่ 0.83 · 🥉 **EURCAD** 8/54 passes, best 1.82 (66t) — เคยถูกเรียก DEAD ผิดๆ · **USDJPY** 6/54, best 1.51 (138t) · **EURCHF = DEAD-optimized ของจริง** (0/54 ผ่าน, best-n≥60 = 1.04) · **AUDNZD = WATCH** (default 1.30, ปีแย่สุด 0.95, ยังไม่ probe) · GBPJPY/NZDJPY/GBPUSD/CADJPY/USDCAD/USDCHF/AUDCAD/EURUSD/NZDUSD = PARKED-pending-probe (default 0.68–1.13). **⚠️ ทุกเลข optimizer = IN-SAMPLE (optimize บน full window) — ก่อนเชื่อ/deploy ต้อง: plateau-center IS/OOS split → MC → robustness-validator ตาม pipeline.** Trait กลไกที่ยืนยันแล้ว: BUY-stop arm ค้าง → หลับยาวเมื่อราคาหนี (dormancy = จริง ไม่ใช่ bug, ตรง Zeus ต้นฉบับ). XML ทั้งหมด: `_mt5_auto/optimizations/BOSS14_OPT_*.xml` |
| (Boss)_SessionBreakout_rev01 | XAU M15 PF 1.04 | ★★★ | **DEAD** | 1,200-pass EXHAUSTIVE sweep ceiling 1.20 + forward 0.91. Thoroughly killed — do NOT revisit |
| (Boss)_RSI_Swing_BB_rev01 | EUR H1 PF 1.03 | ★★☆ | **DEAD (confirmed 2026-06-23)** | RE-EXAMINED: 27-combo sweep EURUSD IS+OOS, best min-PF **0.99** (breakeven), nothing ≥1.2. "Martingale was the edge" CONFIRMED — naked signal has none. Kill upgraded smoke→optimized |
| (Boss)_TrendRegression_rev01 | XAU H1 0.81 | ★★☆ | **DEAD (confirmed 2026-06-23)** | RE-EXAMINED: 27-combo sweep XAUUSD IS+OOS, best min-PF **0.91**, all losing. Reversion-on-trend has no gold edge (matches momentum>reversion thesis). Kill upgraded smoke→optimized |
| (Boss)_NRBreakout_rev01 | 0.82–1.03 | ★★☆ | **PARKED→lean DEAD** | partial sweep, all sub-gate; low prior. ⚠️ **ORDER-202 (2026-07-25): the "ceiling ~1.31 / OOS 1.37" hook that made this look revivable was HOLDOUT-CONTAMINATED** — it came from an optimize ending 2026.07.01 and an "OOS" window of 2025.07–2026.07 that sits inside 2026H1. Re-ran BOTH saved `.set` on clean windows: `p10_ISpick` MAIN **0.93**/80t (net −22) · BWD 0.96/99t · `opt1` MAIN **0.82**/192t (net −198) · BWD 1.02/192t. Every clean MAIN number is a LOSS. Do NOT revive on the 1.31 figure. (If a third config produced 1.31 it was never saved as a `.set` — only the optimize XML would have it.) |
| EA_GoldenEmber_Pivot (Boss 6 MTF Range Pivot) | NZDUSD H1 PF 1.01 | ★★★ | **DEAD (2026-06-28)** | IS 2023-2026 PF=1.01, DD=24.66%, 116t / OOS 2021-2023 PF=1.05, DD=25.79% — flat + massive DD. Robust pass (best optimizer result) still gives no IS edge. GEP DQ — do NOT revisit |
| EA_LNBREAK (London NY breakout) | GBPUSD H1 PF 1.09 | ★★★ | **DEAD (2026-06-28)** | Multi-symbol smoke 2023-2026 M2: GBPUSD 1.09 / EURUSD 1.02 / XAUUSD 1.07 / GBPJPY 0.78 / USDJPY 0.87. Best PF=1.09 after tp_mult=4 tweak — below gate 1.20. London breakout has no durable H1 edge on these symbols |

### MT5 — WAVE-1/2 XAU STRATEGY EAs (15-strategy design 2026-07-19; verdicts 2026-07-19/20 · ORDER-139/140/141)
| EA (magic) | Home | Conf | Verdict | Reason / evidence |
|---|---|---|---|---|
| (TRND)_TrendRider_XAU (992004) | XAU H4 | ★★★ | **ACTIVE demo** (attached 415573666, 2026-07-23) | full funnel 2026-07-20: 27-cell ladder → 6-cell plateau AdxMin20×Sep{.3,.5}×Ch{2..3} all-pass; center a20/s0.5/c2.5 MAIN 1.63/112t eqDD 2.64 · BWD 1.03/139t · holdout 2026H1 **1.33**/23t (burned; n thin) · M4 1.61/1.01 retained · MC ruin 0% DD95 4.15 PF-5th 1.61 · corr cohort ≤0.32 LOW. ⚠️ BWD borderline → demo isolate, no auto-live. Bundle `_vps_deploy/W2_S1_TRENDRIDER_XAU` · **attached on 415573666 (Boss_14-bench acct) not the planned 463666728 bundle acct, per user 2026-07-23 — magic 992004 unique, no collision** · judge 2026-10-23. ORDER-147→**167 (2026-07-23) expansion CLOSED บน full-pinned config:** USDJPY H4 holdout **0.38** · EURJPY H4 holdout **0.32** = **DEAD-OPTIMIZED ทั้งคู่** (both-window 1.34/1.31 และ 1.32/1.02 สวยแต่ holdout พัง = selection-fit) · XAGUSD H4 holdout **1.37 ผ่าน** แต่ re-confirm pinned = MAIN 1.53 / **BWD 0.97** soft-gate fail → BUILD-ON เท่านั้น ห้าม attach (lever ค้าง: optimize ให้ XAG เองจริงๆ). **ORDER-174 (2026-07-23) ปิด lever นั้น:** AdxMin×SepAtr coarse grid บน XAG เจอ plateau จริงที่ **AdxMin=25** (BWD ผ่านทั้ง 3 SepAtr พร้อมกัน 1.10/1.14/1.06 — ตรงข้าม AdxMin20 ที่ยืมมาจาก XAU ที่ตกทุกจุด) เช็คทิศทางต่อจนเจอจุดที่ดีที่สุดก่อน thin: **lock AdxMin=30/Sep=0.5/Ch=2.5** → both-window **MAIN 2.10/42t · BWD 1.49/46t** · M4 confirm ตรงเป๊ะไม่มี fill-cliff (2.09/1.49) · holdout 2026H1 **1.01/n=7 บางมาก** (ไม่ล้มแต่ไม่มั่นใจ) · MC **PF-5th 1.266 ruin 0%** (ผ่าน comfortable bar). **BUILD-ON แข็งแรงขึ้นมาก**. **ORDER-181 ปิดของค้างที่เหลือ:** sensitivity fan ±20% — SepAtr แบนราบ (0.4/0.6 ทั้งคู่ ≥baseline) ChAtr เป็น**เทรนด์ทางเดียวไม่ใช่ plateau** (2.0=1.20 ต่ำกว่า baseline 43% แต่ไม่ flip ลบ, 3.0=3.50 ดีขึ้นอีก — กลไก Chandelier-trail ยิ่งหลวมยิ่งได้กำไรมาก ไม่ใช่ artifact) · **corr vs cohort ต่ำทั้งคู่:** vs XAU sibling 992004 = **-0.244**, vs Boss_14 XAU leg 990207 = **0.236** (ทั้งคู่ LOW-additive แม้เป็นโลหะเหมือนกัน — pullback-continuation จับจังหวะคนละเวลากับ trend/breakout). **funnel ครบเกือบทุกด่านของ VERDICT GATE 2c** เหลือจุดอ่อนเดียว = holdout n=7 บาง. verdict คง BUILD-ON (ไม่ยกเป็น CANDIDATE เพราะ holdout thin เท่านั้น) แต่**แข็งแรงที่สุดในบรรดา expansion cell ที่ทดสอบวันนี้** — เหมาะให้ user พิจารณา demo-isolate ได้ (precedent StoMultiTap/ORDER-137). บ้าน XAU เดิม (992004, attached) ไม่ถูกแตะ |
| (MR)_SweepReversal_XAU (992006) | XAU M15 | ★★★ | **PARKED-VERIFY(user) — no new home (ORDER-150)** | ladder complete 4 lever (AdxMax/SweepAtr/TpAtr/RSI band) × 2 TF, 26 both-window cells: MAIN real pulse 1.31–1.85 แต่ BWD <1 ทุก cell ที่ n สุขภาพดี (0.65–0.97); last-opt RSI75/30 "pass" 1.43/1.01 ที่ n=27/33 = spike ไม่ใช่ plateau. Regime-dependent reversion (S2-class). ORDER-150 (2026-07-23): ranger homes EURUSD/EURGBP/AUDNZD M15 on the XAU-locked config (+ mechanical RoundStep rescale $25→0.0030) = EURGBP 0.80 / AUDNZD 0.44 both net-negative = dead, but **EURUSD 1.08/40t = positive pulse with ZERO optimize rounds on that home** → stays PARKED-VERIFY, EURUSD is the live thread. ⚠️ first written as DEAD-OPTIMIZED — user corrected same day: deploy-gate (1.2) ≠ discard-gate. ORDER-169 (2026-07-23): 16-cell coarse grid RoundStep×AdxMax on EURUSD MAIN — spikes at PF 5.40/2.46 are n=6-7 noise (skill catalog: spiky-surface artifact); real plateau at RoundStep=0.0030 (ax25/28/35 = 1.06/1.08/0.99, n31-65, matches this cell's own default result exactly) and a thinner one at RoundStep=0.0080 (ax25/28/35 = 1.50/1.25/1.15, n17-40). **Ceiling on both plateaus ~1.06-1.21, does not clear deploy bar at healthy n** — stays PARKED-VERIFY. Untouched levers: SweepAtr/TpAtr (RoundStep×AdxMax now answered: doesn't unlock it alone) |
| (BRK)_LondonORB_XAU (992003) | XAU M15 | ★★★★ | **VALIDATED CANDIDATE → bundle built, PENDING_ATTACH (2026-07-23)** | ORDER-140 history: plateau set (MinOr.5/TpRR3) บน GBP 0.79/1.10 · EUR 0.88/0.89 · USDJPY M15 1.14/1.10 · XAU M30 1.13/1.08. **ORDER-143 unblocked เดียวกันวัน:** เพิ่ม input trend-filter+partial-TP (default-off, regression-confirmed lot02_ctrl MAIN 1.17/732==baseline เป๊ะ). **trend filter (EMA200 direction-align) = ตัวปลดล็อกจริง:** MAIN 1.17→1.22 ข้าม hard bar 1.2 · partial-TP ทำร้าย (50%→MAIN 1.14/BWD 1.01) ตัดทิ้ง. Plateau ยืนยันเป็นผืน (EMA100/200/300 ไล่นุ่ม 1.24→1.22→1.17, ไม่มี cliff; แต่ fragile ที่ MinOr=0.5 เท่านั้น, 0.8→1.09). Lock center **EMA200/MinOr0.5/TpRR3.5** (เลือกด้วย MAIN+BWD ล้วนๆ กันปนเปื้อน holdout) → fan TpRR **แบน 1.20-1.23 ตลอด 2.5-5.0** · **holdout 2026H1 M1 1.24/M4 1.21 @n=86** (ผ่าน, ไม่บาง) · **Model-4 (real ticks) MAIN 1.16/BWD 1.06/HOLD 1.21** — เสื่อมนุ่มทุก window (~0.03-0.10 PF) ไม่ใช่ fill-cliff (ต่างจาก grid precedent M1 1.23→M4 0.61) · **MC ruin 0.00%, PF-5th 1.16, DD95 3.61%**. จุดอ่อน: real-tick MAIN 1.16 ต่ำกว่า selection-bar 1.2 · holdout ถูกใช้แล้วบางส่วนโดย TrendRider · **corr vs cohort วัดไม่ได้ (ORDER-174 blocker)** → demo-isolate ขนาดเล็ก ห้าม auto-live. Bundle `_vps_deploy/SS1_LONDONORB_XAU/` |
| (TRND)_TsMom_XAU (992001) | XAU D1 | ★★★ | **PARKED-VERIFY(user) → bundle built, PENDING_ATTACH** | 2026-07-19: MAIN 2.8–4.9 ทุก cell, BWD 0.52–0.77 ทุก cell + ADX last-opt ไม่ช่วย (V-reversal ≠ ADX-filterable). Real bull-only momentum edge. ORDER-151 (2026-07-23, user: demo-isolate directly): locked plateau-center lb60/dm2 (MAIN 3.72/26t, BWD 0.70/27t) → bundle `_vps_deploy/S2_TSMOM_XAU/` with judge criteria + BWD-known-bad caveat pre-registered. ⚠️ funnel not complete (no holdout/MC/fan) — demo forward IS the missing evidence, not a normal candidate attach |
| (BRK)_AsianRange_XAU (992002) | XAU M30 | ★★★ | **DEAD-OPTIMIZED (cell)** | 2026-07-19: ladder ครบ (MaxRange×SellOk×TpRR last-opt); healthy-n ceiling MAIN 0.81/BWD~0.9; PF>1.2 cells = n 5–18 spikes. Breakout concept alive ที่ XAU H4 NY (คนละ cell) |
| (MOM)_NyIgnition_XAU (992005) | XAU M15 | ★★☆ | **WATCH (smoke 1.02/639t)** | thin naked; ยังไม่ optimize — คิว Wave-3 |
| (MR)_VwapSnapback_EUR (992010) | EUR M15 | ★☆☆ | **DEAD-OPTIMIZED (cell)** | 2026-07-23 signal-scanner idea: VWAP-extreme-distance snapback (reversion, distinct from continuation EA WaveS1) on ranger home per right-home rule. ExtendSigma{2,3}×SigmaLookback{40,90} both-window: ceiling 0.63-0.76 MAIN / 0.56-0.91 BWD ทุก cell — tighter=ทิศถูกแต่ไกลจาก 1.0 มาก. Reversion class ต้องพิสูจน์แรงกว่าปกติ ไม่ได้ตามที่ต้องการ. ⚠️ magic เดิม 992007 ชนกับ AdaptGridMC ของ parallel session — เปลี่ยนเป็น 992010 ก่อน commit |
| (TRND)_AsianDriftCarry_XAU (992008) | XAU M15 | ★★★ | **PARKED-VERIFY(user)** | 2026-07-23 signal-scanner idea: trades London-open in the direction of the Asian session's net drift (session-carry continuation, distinct from S5 breakout-of-Asian-compression and SS1 breakout-of-London's-own-range). MinDriftAtr{0.3,0.8}×TpRR{1.5,2,3,4,5} both-window: best cell md0.8/tp1.5 MAIN **1.22**/n516 clears the smoke-triage bar; BWD peaks at tp3.0 (**0.94**) then DEGRADES at tp4/5 (opposite of the SS1 pattern) — true plateau ~tp3.0, BWD never crosses 1.0. Real MAIN edge, same bull-flattered/regime-capped class as S1/S2/SS4 this session |
| (BRK)_VolRegimeBreakout_XAU (992009) | XAU H1 | ★★★ | **BUILD-ON** | 2026-07-23 signal-scanner idea: plain N-bar Donchian breakout gated by ATR(14) expanding above its rolling SMA (distinct from SqueezeBreakout's prior-compression precondition and MacroGate's macro-regime gate). DonchianN{10,30,40,55}×ExpandMult{1.0,1.3}: **the vol-expansion gate HURTS at every N (disable it, ExpandMult=1.0)** — real lever is Donchian length, MAIN still climbing (1.01→1.02→1.10 as N=30→40→55, not yet plateaued, n=305 net+316 at N55) while BWD stays flat 0.83-0.88 regardless of N (regime-capped, same class as B). Room to extend N further before verdict finalizes |
| (MR)_EmaScalp_XAUc (992011) | XAU cent M1/M5/M15 | ★☆☆ | **DEAD (no naked edge on any TF)** | 2026-07-23, user's 5-strategy cent-scalp brief (spread 20-30pt XAU cent account). M1 EMA(8)-distance fade, real ticks Model-4: TP60/SL90 gave PF0.61/n19640/DD38.93 (severe overtrading — 1.5xATR threshold too loose at M1). Fixed TP:SL to 60/60 (50% WR breakeven) then multi-TF (Model 1): M1 0.64/M5 0.55/M15 0.52 — weak on EVERY TF, confirms the entry trigger itself has no edge, not just the RR. |
| (MR)_RangeFade_XAUc (992012) | XAU cent M5 | ★★☆ | **DEAD-OPTIMIZED (regime-capped)** | 20-bar M5 Hi/Lo range fade + ADX(M15)>25 kill-switch. Naked default (rb20/mr1500) MAIN **1.26/n190** looked like a real hit — but clean full-.set BWD on the SAME cell = **0.38/n71, collapses completely**. Optimize direction (tighten MinRangePts 1000→3000) inflated MAIN further (1.06→1.46→2.10→1.70) while n shrank (418→90→57→33) = classic overfit-to-noise pattern, not a plateau. Same regime-split class as everything else tested this session (2023-25 MAIN artificially favorable, 2020-22 BWD hostile to nearly every XAU signal design tried). Added a D1 ADX+slope-persistence regime overlay (`_08_UseRegimeGate`, default off) hoping to rescue BWD by rejecting persistent-trend days — **result: over-constrained, n crashed to 6/8, pure noise (MAIN 6.11, BWD 0.02), not a real fix**. Regime-capped, closed. |
| (TRND)_MomentumBurst_XAUc (992013) | XAU cent H1 | ★★★ | **BUILD-ON — genuine portfolio-diversifier find** | Trend-following hedge leg (N-bar breakout + impulse filter + post-profit trail). ⭐ **The only strategy in this ENTIRE session where BWD beats MAIN**: naked default H1 = MAIN 0.86/n502, **BWD 1.24/n500** — momentum-burst captures large directional impulses, and 2020-22 (COVID crash/recovery, 2022 selloff) had more of those than 2023-25's steadier grind. D1 regime overlay (ADX+slope-persistence, `_07_UseRegimeGate`, default off) tested and does NOT help here (cuts BWD 1.24→1.18, filters good trades) — stays off for this EA. Optimize BodyAtrMult×SlPoints both-window H1 confirmed a real plateau, not a spike: bd1.5/sl30 (1.03/1.25,n502/494), **bd2.0/sl40 (1.05/1.36,n237/230 — best balance)**, bd2.5/sl30 (1.06/1.98,n105/115), bd2.5/sl50 (0.97/2.07,n105/116) — BWD robustly >1.2 across every cell, MAIN hovers at breakeven 0.90-1.06 regardless of param. Reads as a genuinely different animal: **breakeven-ish in calm/bull regimes, real edge in volatile/whipsaw regimes** — exactly the portfolio-hedge role the brief asked S3 to play. Not yet CANDIDATE (MAIN never clears 1.2) but the strongest, most robust finding of the whole cent-scalp effort. Locked center: BodyAtrMult=2.0/SlPoints=40. **Holdout 2026H1 (Model 1) = PF 2.45/n33 — strong, third pillar pointing the same direction.** **⚠️ Model-4 (real ticks) reveals the fill-sensitivity flagged in the design note is real and material, not graceful:** MAIN 1.05→**0.74**, BWD 1.36→**0.89 (crosses BELOW 1.0)**, HOLD 2.45→**1.15** (still positive but far thinner). This is a much bigger M1→M4 gap (−0.3 to −0.5 PF) than SS1's graceful ~0.05 degradation — closer to the lab's grid-collapse precedent (M1 1.23→M4 0.61) than to a real, fill-survivable edge. **Verdict downgraded BUILD-ON → WATCH pending a slippage-tolerant redesign** (wider SL/trail-distance, or limit-style entry instead of chasing the breakout at market) — the "hedge leg that wins in volatile regimes" thesis is not dead (HOLD still clears 1.0 on real ticks) but is weaker than the Model-1 numbers suggested, and BWD no longer clears the bar at all under real fills. |
| (MR)_AsianPingPong_XAUc (992014) | XAU cent M5/M15 | ★☆☆ | **WEAK (naked, not optimized)** | Bollinger(20,2) M5 fade to mid during 22:00-06:00 GMT (Asian session), SL tied to 2.5x current spread. Naked default M5 0.43/n4744, M15 0.53/n1058 — weak both TFs but not yet optimize-confirmed dead (BB deviation/session bounds untested). |
| (MR)_PostNewsReversion_XAUc (992015) | XAU cent M5/M15 | ★★☆ | **WATCH (bug fixed, naked not optimized)** | ⚠️ rev01 shipped with a **silent-order-rejection bug**: default LotSize=0.005 (brief's "half lot") is below XAU's broker min-lot (0.01) — every CTrade::Buy/Sell was rejected with zero logging, producing "0 trades" at ANY parameter setting (looked like "no signal", was actually "no order accepted"). Root-caused via isolation (ExtendPts=0 → still 0; SpikeBarAtrMult=0.3 → still 0; same + LotSize=0.01 → 44,808 trades appear instantly). Fixed: LotSize→0.01 (smallest valid size; "half of cohort's 0.01" isn't achievable here) + min-lot guard + ResultRetcode() logging on failure. Signal is a mechanical vol-spike proxy for "news" (MT5 tester has no offline calendar feed — documented substitution in the file header, NOT validated as a real post-news-event edge). Clean naked default: **M5 PF 0.81/n578** (closest-to-viable in this whole cohort), M15 0.60/n438. Not yet optimized. |
| (TRND)_GapContinuation_XAU (992016) | XAU H1/H4 | ★☆☆ | **DEAD-OPTIMIZED (regime-capped)** | 2026-07-23: trades the D1 overnight close-to-open gap direction when \|gap\|≥MinGapAtrMult×ATR(D1). Naked default (0.3×) gave a flashy MAIN PF 17-9.8 but n=11 (too thin to trust). Loosened to 0.15/0.2×: MAIN PF still 10-20 but **BWD=0.52 at BOTH thresholds** — collapses, same regime-split as most of this session. The huge MAIN number is almost certainly 1-2 outlier gap-and-run days during the 2023-25 rally, not a repeatable edge. Closed, no further investment. |
| (TRND)_PivotBreakout_XAU (992017) | XAU H4 | ★★★★ | **VALIDATED CANDIDATE → ACTIVE demo, attached 2026-07-24 on 463666728** | Classic floor-trader daily pivot (Pivot/R1/S1 from the prior closed D1 bar), H4 close-break with confirming bar, one trade/direction/day. Distinct from every Donchian/session-OR breakout in the cohort — fixed institutional reference levels not a rolling range. Checked `ea_projects/EA_GoldenEmber_Pivot/` first (no source, imported NZDUSD idea-bank results, flagged STALE in signal-landscape memory) — this is a fresh XAU build. **Optimize fan (SlAtrMult×TpRR, Model 1) never dipped below 1.0 on EITHER window across TpRR 1.5→3.5** — genuine plateau. Locked center SlAtrMult=1.5/TpRR=3.0 → **Model-4 (real ticks) MAIN 1.16/n231, BWD 1.22/n200, HOLDOUT 2026H1 1.33/n35** — degradation from Model 1 (1.18/1.26) was tiny (−0.02 to −0.04), a sharp contrast to the same session's MomentumBurst collapse (−0.3 to −0.5) — wider ATR-relative SL survives real fills far better than a tight point-based stop. **MC: ruin 0.00%, PF-5th 1.16, DD95 8.24%, worst 12.41%.** Full funnel passed on real ticks. Weakness: **corr vs cohort unmeasured** (ORDER-174 unblocked by ORDER-170 closure but not yet run) → demo-isolate, small size until corr checked. Bundle `_vps_deploy/PIVOTBREAKOUT_XAU/`. |
| (EXP)_AdaptGridMC (992007) | BTC/ETH CFD | ★☆☆ | **DEAD-STRUCTURAL (static-zone design) — PARKED pending redesign** | ORDER-142 (2026-07-23): MAIN PF 523(BTC)/1182(ETH, M4) looked spectacular but is a **realized-path artifact, proven not suspected** — static one-time P10/P90 zone from pre-2023 data; BTC's 2023-2025 rally left the zone permanently, **2026H1 holdout confirmed ZERO BTC trades** (zone is dead). ETH holdout more modest/believable (PF1.27/24t) since it ranged back near zone. Root cause = no periodic zone re-basing, not a fill artifact (M4 confirmed M1) or martingale. Fix = walk-forward zone regeneration (real path forward, not a dead end). BWD 2020-22 untestable (CSV starts exactly at BWD start, 0 bars of runway — user accepted 2026-07-23, proceeded without it). Found + fixed a `parse_htm.ps1` bug along the way (space-thousands-separator silently truncated fields ≥1000). |

### MT5 — fxDreema-lineage demo cohort (ORDER-098 corpus)
> เดิมไม่มีแถวใน scorecard เลยทั้งที่ attach อยู่บน demo — ช่องว่างนี้ถูกเปิดโดย ORDER-204/216 (2026-07-25)
| EA (magic) | Home | Conf | Verdict | Reason / evidence |
|---|---|---|---|---|
| MacdDiv_Naked (999094) | XAU H4 | ★★☆ (ลดจาก ★★★) | **PARKED-VERIFY(user) — คง demo, ล็อก config, ห้าม size-up, ห้ามขึ้นเงินจริง** | ORDER-216 2026-07-25: plateau เดิมเป็นของปลอม. **3 ใน 8 input ไม่มีผลที่ค่าที่ deploy** และ `_02_MacdSignal` **ตายเชิงโครงสร้าง** (ส่งเข้า `iMACD()` แต่ `MacdAt()` อ่าน buffer 0 อย่างเดียว → เส้น signal ไม่เคยถูกอ่านที่ไหนในทั้ง EA) · `_01_LookbackBars` inert ทุกค่า ≥48 (deploy 60) · `_01_MinBarsApart` inert ที่ 1-4 (deploy 2) ⇒ คำอ้าง ORDER-098-B ว่า *"plateau 9 neighbour ไม่มีตัวขาดทุน"* นับบนแกนที่ตาย ซึ่งผลเท่ากันเป๊ะโดยอัตโนมัติ. บนแกนที่ทำงานจริง cell นี้เป็น **knife-edge**: `_01_SwingRadius` 2/3/4 → MAIN 0.96/**1.82**/1.04 · BWD 0.87/0.98/**1.44** และใน complete grid 405 cell ที่ผ่าน 146 cell **มี 135 ที่เป็น SwingRadius=3 ล้วน**. **ไม่มีค่าไหนผ่านทั้งสองหน้าต่าง** (MAIN ชอบ 3, BWD ชอบ 4 = regime-fit บนแกนนั้น). ที่ยังคง demo ไว้เพราะต้นทุนศูนย์ + forward record คือ holdout ที่ยังไม่ถูกใช้ตัวเดียวที่เหลือ — และมีค่ามากขึ้นเมื่อรู้แล้วว่า backtest บาง. BWD 0.97 (M4) เป็นสิ่งที่ user อนุมัติ attach ทั้งที่รู้อยู่แล้ว ไม่ใช่ข้อมูลใหม่. lever ที่แตกออกไป = ORDER-217 (เส้น signal ที่ไม่เคยถูกใช้) |

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

### MT5 — MASS-SMOKE `wait for test` (2026-07-05+, ORDER-034..038; worklist 1,521 · ex5 203 smoked)
| EA | best smoke | Conf | Verdict | Reason |
|---|---|---|---|---|
| (oh) pun fix lot v05 | M1 1.63/M4 1.51, ทุกปีบวก 2023-26, MC ruin 0% — **ทุกด่านเลขผ่าน** | ★★★ | **REJECT (2026-07-06) — DO-NOT-RE-EXAMINE** | source read เผย **no-SL ทุกชนิด + TP 10 pips = harvester** (เทรด EURUSD/GBPUSD/EURGBP hardcode ไม่สนชาร์ต — "4-symbol robust" คือพอร์ตเดียวรัน 4 รอบ) → backward-OOS 2020-22: **2022 PF 0.36 / eqDD 83.08%** เกือบล้างพอร์ต. mechanism-fatal, resize ไม่ช่วย. **บทเรียนสำคัญสุดของ mass-smoke: เลขผ่านทุกด่านยังหลอกได้ — อ่าน source ก่อนเชื่อ compiled EA เสมอ** |
| EA_GapinFX_MT5 | M1 USDJPY 2.74/EURUSD 2.34 DD<9% | ★★★ | **REJECT (2026-07-06) — DO-NOT-RE-EXAMINE** | backward-OOS 2020-22: 2020 PF 2.54 / 2021 PF 22.56 สวยหรู → **2022 PF 0.02 / -$11,212 / balDD 111.87% (ล้างพอร์ตจริง, eqDD 95.7%)** — gap-fade = mean-reversion harvester, gap ไม่ fill ตอนเทรนด์แรง = ระเบิดปีเดียว. ตระกูลเดียวกับ pun fix lot. compiled-only ไม่มี source · M4 ไม่ต้องรันแล้ว |
| North East Way v1.309_fix | M1 4 คู่ PF 2+ แต่ DD 30% | ★★☆ | **DISQUALIFIED (2026-07-06) — cracked commercial, ไม่ต้องเทสต่อ** | ทุกไฟล์ในเครื่อง = "_fix"/"_nodll" (แกะ DLL protection) = locked-ex class ตรง hard-gate เดิม (precedent: KRAPOOK DQ ทั้งที่ profile ดีสุดของ pool) — deploy จริงไม่ได้/binary ไม่น่าเชื่อถือ · เทคนิคเบื้องหลัง (multi-pair mean-reversion grid) รู้จักอยู่แล้วใน mold axes ไม่มีของใหม่ให้สกัด |
| **Scalping-EA-AsReMix** | M4 2022 = **2.71 (100% real ticks)** · FULL 6.5yr: 20-23 ดี (1.05/1.56/2.99/2.10) → **24-26 จาง (1.04/1.06/0.98 ลบ) + balDD บวม 22→31→33%** · MC worst DD 106% | ★★★ | **PARKED — trend-regime specialist, edge decay (ORDER-039 closed 2026-07-06)** | momentum edge จริง (รอด real ticks ปีเทรนด์ — ตัวเดียวจาก 203 ที่ไม่ใช่ harvester/artifact) แต่ 3 ปีหลัง regime ไม่มีให้กิน = breakeven-ลบ → deploy วันนี้ = ซื้อของที่แพ้อยู่. **Re-examine trigger: JPY/USD trend regime กลับมา (vol ใหญ่)** — เก็บเป็น reserve ตัวเดียวของ mass-smoke MT5 · reports `ART_AsReMix_*` |
| (Oh) Arbitrage Super Profit V04 | BWD full 1.64 **+$99,074 จาก 10k / eqDD 1.47%** | ★★★ | **REJECT — tester-artifact (too-good)** | 3-symbol arbitrage บน tester = exploit sim tick-sync ที่ไม่มีจริงบน live — ตัวเลขระดับนี้ = โครงสร้าง artifact ไม่ใช่ edge |
| EX39.PU-test | BWD ทุกปี 1.86-2.00 แต่ **balDD 2.65% vs eqDD 69.54%** | ★★★ | **REJECT — floating ซ่อน** | balance สวยแต่ equity จมลึก 70% = no-SL hold ค้าง ยังไม่ realize = harvester ตัวจริง |
| SL=2GRIDE · The One 1.0.3 | BWD 1.13/eqDD 11% · 1.14/DD 31% | ★★☆ | WATCH-thin (ไม่ลงแรงต่อ) | edge บางเกิน/DD สูง — เก็บชื่อไว้ ไม่เข้า funnel |
| อีก 12 ตัว (IR Whale eqDD 106%! · BOO 91% · JMAR 99% · Grid UL 85% · pun hedging 79% · Master GRID 72% · Black Dragon 52% · IRSI 51% · grid v05 eqDD 94% · GOLD CENTER expired · continue · fibo gold flat) | BWD-OOS sweep `BWDOOS_SWEEP.csv` | ★★★ | **REJECT ยกแผง (2026-07-06)** | ตระกูล regime-harvester ครบทุกตัว — ตายปี 2020-22 ตามทฤษฎี · PumLot+PROFIT PLANET = NO_REPORT (non-functional BWD window) |

### MT5 — GridLog × instrument class (mine #1)
| Cell | best recon | Conf | Verdict | Reason |
|---|---|---|---|---|
| GridLog × US30 (index) | 4-variant recon (xau-axes/tp0.5/aud-axes/sell) ทั้งหมด **PF 0.78-0.96 ลบ** | ★☆☆ | **PARKED-pending-probe (2026-07-06) — EV ต่ำ ไม่เร่ง** | ต่างจากทองที่ life โผล่ตั้งแต่ scan แรก (1.76) — index ไม่ตอบ mechanism นี้ที่ default · ตามกฎ no-DEAD-before-optimize เหลือ ORDER-043 probe (optional, ZCode วันว่าง) · **mine #1 = จบ backbone แล้ว: FX 6 ✓ ทอง ✓ เงิน parked · index parked** |

### MT4 — MASS-SMOKE batch-01 BWD-OOS (ORDER-040, 2026-07-06)
| EA | best smoke | Conf | Verdict | Reason |
|---|---|---|---|---|
| **ClevrFX_EA** | BWD ทุกปีบวก 1.76/1.51/**2.37** + 2026=2.04 · **spread-stress: sp30=2.04, sp45=1.93 (ไม่สะเทือน)** | ★★★ | **🟢 DEMO-EXPERIMENT CANDIDATE (ORDER-041 ผ่านครบ 2026-07-06)** | ผ่านทุกด่านที่ backtest ตอบได้ · ⚠️ **no hard SL ทุกไม้** (internal cut-loss ทำงานจริง — ผ่าน 2022 ได้ แต่ disconnect = ไม้เปลือย → VPS+จับตา) · compiled กลไกดำ → demo ≥3 เดือนเท่านั้นก่อนคิดต่อ · **รอ user เคาะ: เปิด MT4 demo?** |
| **Fxcore100_SELL** | ผ่านครบทุกด่านเชิงเลข (BWD ทุกปีบวก + spread 3x ยืน) | ★★★ | **DISQUALIFIED (2026-07-06) — pirated copy (user ยืนยัน "ก็อปมา")** | precedent North East Way: copy ที่ไม่มีสิทธิ์ = deploy ไม่ได้ + binary ไม่น่าเชื่อถือ ต่อให้เลขสวยที่สุดใน pool · **บันทึกไว้: ถ้าอนาคต user ซื้อ official = ตัวเลขชุดนี้ใช้เป็น prior ได้เลย** (ผ่านทุกด่านแล้ว) |
| CITY-GOLD HUNTER PROx2_fix | smoke PF 259.99(!) | ★★★ | **DQ-by-name** | "_fix" = cracked + PF อสุรกาย = artifact ซ้อน artifact |
| 8 ตัว ZERO-TRADE 2020-22 (Broker Killer, Fxcore100_BUY, Mood, Elise, AW Recovery_NEW, Alpha Striker, Forexthai4pip, Hedgingprofit) | เทรดแค่ 2026 | ★★☆ | **REJECT-unverifiable** | ไม่เทรดอดีต = สงสัย time-lock/expiry ในตัว → วัด durability ไม่ได้ = เชื่อไม่ได้ |
| 9 ตัวที่เหลือ (Forex Hacked DD108% · DanceT DD103% · FLy_HiGhEr · forexthaipop · Happy thaipop DD73 · MoneyTree×2 (binary เดียว!) · Miracle DD57 · CommunityPower DD74) | BWD ระเบิด/DD 57-108% | ★★★ | **REJECT** | harvester/grid ตระกูลเดิม — ตายปี hostile ตามทฤษฎี · ผลเต็ม `BWDOOS_MT4.csv` |

### MT4 — MASS-SMOKE ORDER-036 survivors (2026-07-07 — จาก 1,318 ex4; funnel: smoke → lot-check(Size-col) → BWD 2020-22 → spread 30pts → Model-0)
| EA | best smoke | Conf | Verdict | Reason |
|---|---|---|---|---|
| **UnNomGuaiV1.132** (EURUSD H1) | **BWD 2020-22: M1 1.89/DD18.7 → SPR30 1.83/DD19.0 → Model-0 1.63/DD19.3 · fwd 4mo: M1 2.06 → Model-0 1.77/DD4.8** — เสถียรทุกด่าน ครบทั้ง backward+forward | ★★★ | **🟢 DEMO-EXPERIMENT CANDIDATE (2026-07-07 — ผ่านครบทุกด่านรวม fwd Model-0 · survivor เต็มตัวรายที่ 2 ของ MT4 pool ต่อจาก ClevrFX) · รอ user เคาะ: เปิด MT4 demo?** | grid ตะกร้า ladder ตื้น 0.01→0.07 (×2.3 จริงบน 3 ปี) · เปิดพร้อมกันสูงสุด 9 ไม้ · ปิดยกตะกร้า +$8 · ⚠️ **SL=0 ทุกไม้ + config เปิดได้ถึง 99 ไม้ (spaceOrders) = tail-risk เชิงทฤษฎีที่ 3 ปี backward ไม่เคย trigger** → เหมือน ClevrFX: VPS + lot เล็ก + demo ≥3 เดือนเท่านั้น · compiled กลไกดำ (no source) |
| **RSI from pips_EA** (EURUSD H1, b27) | **BWD 2020-22: M1 2.32/DD7.6 → SPR30 2.25/DD7.7 (spread แทบไม่กัด!) → Model-0 2.07/DD25.0 · fwd Model-0: 2.39/DD2.2** | ★★★ | **🟢 DEMO-EXPERIMENT CANDIDATE (2026-07-07 — survivor เต็มตัวรายที่ 3 · โปรไฟล์สะอาดที่สุดของ 1,318 ตัว)** · รอ user เคาะ: เปิด MT4 demo? | lot ladder ตื้น 0.01→0.06 (×6, 429 entries — ไม่ใช่ grid หนา) · PF ยืน >2 ทุกด่าน · ⚠️ SL=0 ทุกไม้ (เงื่อนไขเดิม: VPS + lot เล็ก + demo ≥3 เดือน) · DD บน every-tick 25% สูงกว่า M1 (7.6%) = intrabar exposure จริงลึกกว่าที่ M1 เห็น · compiled กลไกดำ (no source) |
| Oracle EA (EURUSD) | BWD M1 1.90/DD36 → SPR30 1.69/DD26.7 → **Model-0 1.43/+5,776/DD39.0** | ★★☆ | **🟡 CONDITIONAL อันดับ 3** — ผ่านทุกด่านแต่เสื่อมเป็นลำดับ (1.90→1.69→1.43) + DD 39% หวุดหวิดใต้ gate 40% | ก่อนคิดต่อ**ต้องอ่าน trade list** (54 entries/1,276 trades = pending/partial แปลก) · ถ้า demo ให้ lot เล็กพิเศษ |
| EAForexTH_MultiHedge_1.0 (EURUSD) | BWD M1 1.61/DD20.3 → SPR30 1.61/DD20.5 → **Model-0 1.29/+616/DD20.5** | ★★☆ | **🟡 CONDITIONAL-weak** — DD นิ่ง 20% ทุกด่านแต่ PF เหลือ 1.29 + net เล็กมาก ($616/3ปี) | lot ×1 แบน 0.01 — resize ได้แต่ edge บางลงเรื่อยๆ ตามความสมจริงของโมเดล · priority ต่ำ |
| **swb grid 4.1.0.3_h flat-lot @ AUDCAD** (ORDER-047) | **BWD 2.40/DD8.6 → SPR30 2.23/DD9.0 → Model-0 1.80/DD20.44** · ladder ×3-4 · H1 | ★★★ | **🟢 DEMO-EXPERIMENT CANDIDATE #3 (2026-07-07 — ฟื้นด้วย symbol ที่ใช่)** — grid flat-lot บน AUDCAD ทน spread+every-tick, DD คุมได้ 9-20% ทุกด่าน (ต่างจาก swb-EURUSD ที่ M0 DD 42%) | ⚠️ no hard SL ทุกไม้ (VPS+online เหมือน ClevrFX) · base lot 0.2 → de-scale ผ่าน start_lot ก่อน demo · magic=1 ชนกับ UnNomGuai → **ต้องคนละบัญชี** หรือแก้ magic (ไม่ใช่ validated param, แก้ได้) · ใช้ `swb_flat.set` + AUDCAD |
| swb flat-lot @ AUDUSD (ORDER-047, secondary) | BWD 2.46/DD25.5 → SPR30 2.18/DD27 → Model-0 1.66/DD31.93 · ×5 | ★★☆ | **🟡 CONDITIONAL** — ผ่านทุกด่านแต่อ่อนกว่า AUDCAD (PF ต่ำกว่า DD สูงกว่า) | เก็บเป็น diversification ถ้าอยากได้ swb คู่ที่สอง · caveat เดียวกับ AUDCAD |
| swb flat-lot @ EURUSD / XAUUSD | EURUSD M0 DD42% (เกิน gate) · XAUUSD SPR30 0.35/DD105% 💀 (net$194k forward = gold regime ล้วน) | ★★★ | ❌ **REJECT** — swb เป็น symbol-specific: ดีเฉพาะ AUD, ตายบน EURUSD(DD gate)/XAUUSD(spread) |
| EAForexTH_Scalper_S3_1.0 (EURUSD) | BWD M1 **10.71** → SPR30 **0 trades** → Model-0(spread default) **PF 10.0/+74,586/DD4.4** | ★★★ | ❌ **REJECT — tester-artifact ยืนยัน 2 ทาง** | มี spread filter ในตัว: SPR30 ไม่เทรดเลย ส่วน Model-0 ยัง PF 10 เพราะ **MT4 tester ใช้ fixed spread ที่ไม่มีวันถ่าง** (blind spot เดียวกับที่จดจาก Zeus) — กลไกทั้งหมดพึ่งพา spread แคบตลอดเวลาซึ่งไม่มีจริง · PF 10/3ปี = ไม่มี EA จริงทำได้ |

### MT4 — SCREENED (63 EAs, 0 deployed)
| EA | screen PF | Conf | Verdict | Reason |
|---|---|---|---|---|
| EA_Golden_Elephant/Mammoth | XAU 4.08 | ★★★ | **DISQUALIFIED→DEAD (re-confirmed 2026-07-02)** | grid; TP200→2000 collapsed PF 7.77→0.06 = tight-TP artifact. **Phase 2 re-test** (`MT4_GOLDGRID_RETEST_PLAN.md`, XAUUSDMINI H1, Model 1 control-points 1yr 2025.06-2026.06 — Model 0 unavailable, no tick history cached): PF collapsed **85.14 (Model 2) → 1.41 (Model 1)**, DD **53.65%/yr** at MaxOrder=4 (already capped). Artifact confirmed at every model tested; the thin residual edge isn't deployable at this DD. Mammoth = identical binary (MD5 match), same verdict, not re-tested. |
| Gold Stuff EA V7.0 | XAU 5.09/39%DD | ★★★ | **DISQUALIFIED (re-confirmed 2026-07-02)** | Phase 1 mechanism gate: `iMO=100` (max orders, practically uncapped) + `SL=0` (no per-position stop) + `MM=1.5` martingale multiplier = uncapped grid/martingale, DQ stands structurally. Phase 2 empirical: Model 1, 1yr 2025.06-2026.06, XAUUSDMINI H1 → PF=2.20 (935 trades, high-frequency churn) but **DD=77.11% in ONE YEAR** — ruin risk confirmed, no sizing fix possible per Step-0 gate. |
| KRAPOOK BLUE ANT | XAU 2.65 | ★★★ | **DISQUALIFIED** | EA EXPIRED (best profile of pool but un-deployable). Technique (distance-scaling) saved for reuse |
| BuRengNong207 | XAU 1.76 | ★★★ | **DISQUALIFIED** | martingale-only (mult=1.0 → 0/9 pass); no signal under it |
| EURUSD Forex Robot | EUR 3.89 (2026) → **BWD 2020-22 PF 0.39 / -$5,840** | ★★★ | **REJECT (2026-07-07, ORDER-044) — DO-NOT-RE-EXAMINE** | re-test ที่ค้างจาก R3 จบแล้ว: ตายที่ด่านแรก (BWD-OOS) — 3.89 บน 48t = thin + regime. ปิด re-exam queue ของ 63-EA screen ครบทุกตัว |
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
(optimizer 0 survivors), Elephant/BRN207/GameChanger (artifact/martingale proven by sweep),
**JumStoch Trend-seed on chassis (Boss_18)** — DEAD-OPTIMIZED 2026-07-18, 28 M4 runs uniformly 0.58–0.94
both-window (2 DirMode × 2 sym × 2 dir × 2 exit × 2 TF); edge was the standalone's 4-basket+BEP engine, not
the LWMA+Stoch seed. Standalone JUMSTOCH untouched. verdict = `_triage/_archive/verdicts/ORDER_LANEA_JUMSTOCH_VERDICT.md`.
**StoMultiTap (multi-tap S/R + Stoch cycle fade, (EXP)_StoMultiTap)** — PARKED-VERIFY(user) 2026-07-19 (ORDER-137, renumbered 133→135→137 concurrent-session collisions). ⚠️ **NOT dead** — an earlier premature DEAD-OPTIMIZED call was reversed after user challenge. Idea from FB Miissterkiiss/Bitnefit book. Novel lever `MinTaps` (count Stoch OB/OS "รอบ" at S/R zone, never first-touch) **WORKS on XAU M15:** K17 tap2 lifts PF 0.91(1039t)→1.45(27t); ZoneTol-tuned zt40 = MAIN 1.51/64t (real structure). First "dead" was frequency-starvation from MTF+ADX filters (tap2→0-3 trades), not no-edge. **NOT redundant** with SMCxSTO 991070 (measured monthly corr −0.10). PARKED not CANDIDATE because **BWD-fails every variant** (zt40 1.51→0.58, zt60 1.02→0.90) = XAU 2023-25 chop-regime, reversion-fade-on-trender not both-window robust. User decision: demo-isolate XAU-M15 zt40 (try ADX-gate, holdout not burned) or shelve. EDGE_CATALOG + signal-landscape.

---

> ⚠️ **HISTORICAL RUBRIC (frozen 2026-07-18)** — คะแนน/แถบคะแนนด้านล่างใช้เป็น intake evidence เท่านั้น **ห้ามใช้ตัดสิน deploy** — verdict authority เดียว = VERDICT GATE ใน CLAUDE.md (vocabulary: DEAD-STRUCTURAL/DEAD-OPTIMIZED/PARKED-VERIFY/BUILD-ON/CANDIDATE/DEMO/LIVE)

## HOW TO USE
1. New or revisited EA → run Step-0 gates first. Any fail = DISQUALIFIED, stop.
2. Passes gates → score A–D, attach confidence tag = how it was tested.
3. Band the score → verdict. A <40 score with ★ confidence is PARKED, not DEAD.
4. Record the row here. Never kill silently.
Canonical scoring reference: `D:\EA_LAB\docs\RECOVERED_PLATFORM_DESIGN_20260614.md` (BacktestScore v1).




---

## 🎯 EA-SCORE v1 — คะแนน = สิทธิ์ deploy (จารึก 2026-07-10, ออกแบบร่วม user+Claude)

> ใช้คู่กับ screening score เดิม: score เดิม = คัดตอน intake · **EA-SCORE = ตัดสินสิทธิ์ตอน deploy/ปรับ size**
> ปรัชญาเบื้องหลัง → VISION.md §ปรัชญาโรงงาน · เกณฑ์ rescue ก่อนตาย → CLAUDE.md VERDICT GATE ข้อ 4

| # | เกณฑ์ | คะแนน | หลักฐานที่นับ |
|---|---|---|---|
| 1 | Entry มี edge เปล่า | **2** | flat-lot/naked PF>1 **หลัง spread-stress + Model 0** (ผ่านแค่ Model 1 = 1 คะแนน) |
| 2 | โครง MM ครบ | **2** | SL ทุกไม้ + hard cap (lot+จำนวนไม้) + controlled-loss release (ครบ=2 บางส่วน=1) |
| 3 | สอง regime | 1 | บวกทั้ง 2023-26 และ BWD 2020-22 |
| 4 | Plateau | 1 | เพื่อนบ้าน param ±1 step ไม่มีตัวขาดทุน |
| 5 | Holdout+MC | 1 | window ที่ไม่เคย select + MC PF-5th ผ่าน, ruin 0 |
| 6 | M0+spread confirm | 1 | เลขไม่ละลายบน every-tick + spread จริง |
| 7 | Live tracking | 1 | demo/live ≥2 เดือน วิ่งในกรอบ backtest |
| 8 | Portfolio additive | 1 | corr <0.4 หรือ DD-overlap ต่ำ vs พอร์ตปัจจุบัน |

**กุญแจเพดาน (คะแนนอื่นชดเชยไม่ได้):** ข้อ1=0 → **เพดาน 5 = premium track** (กรง 3 ชั้นตาม VISION) ·
no-SL/no-cap → **เพดาน 3** · crack/DLL/timelock/no-source-phone-home → **เพดาน 2**

**สิทธิ์ตามคะแนน:** 9-10 = เงินจริงเต็ม size แกนพอร์ต · 7-8 = เงินจริง cent size มาตรฐาน (ม้างานหลัก) ·
5-6 = cent ครึ่ง size จับตาเข้ม / demo หนึ่งรอบ judge / premium-track · 3-4 = บัญชีทดลอง user เท่านั้น
(แยก equity) · ≤2 = tester only

**⛔ Hard prerequisite ก่อนใช้สิทธิ์เงินจริงทุกระดับ (inline จาก VERDICT GATE ข้อ 6 — CODEX-AUDIT C2 2026-07-11):**
คะแนนอย่างเดียวไม่พอ — ต้องผ่าน **holdout window ที่ไม่เคยใช้ select + MC + เลือกที่ plateau-center** ก่อนเสมอ
· score สูงแต่ criterion 5/7 ยังโหว่ = สิทธิ์สูงสุดแค่ demo · ข้อเสนอเพิ่ม rubric (รอ user เคาะ): min trade count
ต่อ window (เช่น ≥100) — เคส SuperTrend 56 trades แสดงช่องนี้ชัด

**Calibration ณ วันจารึก (ยืนยันว่า rubric ตรง verdict จริงที่ผ่านมา):** BRK-XAU Bars55 ≈ 8 ·
Boss_16 21/30 ≈ 5 (จะเป็น 7-8 ถ้าผ่าน ORDER-078) · ST03 family = เพดาน 3 (กุญแจ 2 ดอก) ·
Zeus locked = เพดาน 3 · Gold_Kangaroo copy = เพดาน 2 (crack)

**กติกาใช้งาน:** ให้คะแนนตอน (ก) จบ funnel (ข) ทุก judge day (ค) หลัง rescue sweep · คะแนนลด =
สิทธิ์ลดทันที (ไม่มี grandfather) · คะแนนอยู่ในทะเบียน EA แต่ละตัวในไฟล์นี้
