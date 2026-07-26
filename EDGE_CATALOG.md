# EDGE CATALOG — why each EA makes money (and what that teaches)

Companion to `EA_SCORECARD_AND_REGISTRY.md`. The registry says *whether* an EA is good;
this catalog says *why* it has edge, *when* it fails, and what new ideas the pattern seeds.
Confidence: ✅ = mechanism read from code/spec · 🟨 = hypothesis from type/behaviour (verify before trusting).

Created 2026-06-26.

---

## CORE THESIS OF THIS PORTFOLIO
**Edge predictor = instrument character: momentum vs reversion.**
- **Trenders (XAU/gold)** reward **momentum / breakout** — price continues.
- **FX majors (GBP/EUR/CHF crosses)** reward **short-horizon mean-reversion** — price oscillates back.
- Pick the signal to match the instrument. Mismatch = the dead pile below.

What has NEVER worked here (anti-edges):
- **Naked indicator crossovers** (MACD/BB+RSI) on FX majors → structural ceiling ~PF 1.1.
- **Uncapped martingale / grid** → the "edge" is just deferred losses; remove the doubling and the naked signal is breakeven ("martingale WAS the edge").
- **Tight-TP < spread (Model-2)** → PF is open-price fill fiction; collapses when TP×10.

---

## LIVE / CANDIDATE EAs — edge mechanism

### ST_EA03 MACD — GBPUSD/USDCAD H1 (CORE) · replica = EA_RUNNER_ST03 ✅
> ⚠️ **ENTRY-SIGNAL VERDICT (ORDER-119, 2026-07-19): flat-lot MACD-state entry = NO robust both-window edge.** chassis Boss_15 lever-C sweep (MACD Fast/Slow/Signal × CountBars, 18 combo × GBPUSD/EURUSD/EURGBP × H1/H4 × MAIN+BWD) = **0/6 cells flat-lot PF≥1.0 both-window** (best EURUSD H4 MAIN 1.15 / BWD 0.98 same combo). The historical "edge" lives in the **no-SL averaging engine (escalation), not the MACD entry** — so escalation on this entry = martingale-is-the-edge (DEAD-STRUCTURAL). MACD-state-run as a naked reversal trigger on rangers = dead. Reusable only as a *state gate* feeding a different entry, never as the edge itself. **ENGINE ALSO DEAD (ORDER-135, 2026-07-19, under new ENGINE-EDGE cage): capped-basket DCA (MaxLevels×LotProg × 2 best cells × 2 window) = 0/9 both-window. DCA engaged (n +2.2×) but escalation only LEVERAGES regime-dependence — winner-window net +88→+140, loser-window −111→−177; it does not manufacture edge. the GENERIC chassis MM can't rescue the MACD signal. **⚠️ chassis-cell dead ≠ concept dead: chassis MM ≠ standalone's tuned LOT_Repeat/tp3/near/spacing/vol-gate machine (signal parity, MM not) → standalone = PARKED-VERIFY(user).** Lesson for the dead pile: a *generic* averaging engine amplifies a regime-dependent signal's asymmetry, it cannot create a symmetric edge from a signal that has none — but a purpose-tuned engine on the same signal is a separate empirical question.**

**Mechanism:** enter once per MACD-state run (2-bar count) → market leg + LIMIT leg 5pip below
(scale into dip) → **NO stop-loss** → close the whole OCO group when combined P/L hits +5pip →
80-bar time-stop backstop. Tiny lots.
**Why edge:** a **mean-reversion harvester**. FX majors retrace small moves on H1; a 5pip target
hits ~80% of the time. The no-SL + averaging leg is the *engine* — it waits out temporary adverse
excursions until they revert, converting would-be losers into small wins.
**Really it is:** selling mean-reversion insurance — steady 5pip premiums in calm, paid back in a
lump when price trends hard without reverting.
**Failure mode:** every real crisis PF<1 (Brexit/COVID/gilt) — the "steamroller". Negative skew
(MC PF-range 20.5). Regime-dependent (2025H1 weak). Hard SL kills it (realises the temp excursions
before they revert). **Tail CANNOT be filtered reactively** (tested 2026-06-26): vol-gate
(ATR>1.5×ATR_MA(300)) only catches GAP spikes (Brexit −218→+94) but misses sustained-trend crises;
ADX trend-gate is COUNTERPRODUCTIVE (ADX lags → cuts the good reversion trades, keeps early-trend
losers). **So you cannot size this up safely.**
**Idea seeds:** more profit comes from DIVERSIFICATION not leverage — run the engine small on other
liquid rangers (EURUSD/EURGBP) per-symbol tuned, and combine uncorrelated legs in a portfolio.

### MG_v1 MatchaGrid — CHFJPY M15 (PARKED-VERIFY(user) since 2026-07-25) 🟥
> ⚠️ **This entry said `CORE` until 2026-07-26 — it was stale by a day against the scorecard and
> EA_MASTER_INDEX, which both moved to `PARKED-VERIFY(user)` in ORDER-215 part 1.** Corrected here
> rather than banner-patched, per the ORDER-214 lesson: if the row still reads CORE, people read CORE.
**Mechanism (hypothesis — and note how much of it is still hypothesis):** bounded grid with hard SL
on a range-bound cross.
**Why edge:** CHFJPY oscillates in a range; the grid harvests the back-and-forth, the **bounded
steps + SL cap the breakout tail** (this is why it passed deep-val where naked grids DQ).
**🔴 The load-bearing part of that claim is unverified (ORDER-215 recon, 2026-07-26):** MatchaGrid is
**closed source** — `.ex5` only, no `.mq5` anywhere. The "bounded + SL" property that keeps it out of
the uncapped-ruin bin rests entirely on `InpCutLossMode=0`, an input found only by reading rendered
report headers, **whose meaning is documented nowhere in this repo**. Every archived run also sits at
`Model=1`; there has never been a Model-4 run of this EA, and doctrine treats a grid measured below
Model-4 as not evidence at all. So the safety claim is a hypothesis wearing a verdict's clothes.
**Failure mode:** a sustained CHFJPY trend that blows past the grid bounds (SL caps it, *if* the SL
is what we think it is — see above).
**Idea seeds:** "bounded + SL" is the safe way to run a range harvester — the template for taming
any grid/martingale that screened well but DQ'd on uncapped tail.

### NuiIndy RSI+ADX — EURUSD H1 (CORE, edge=escalation ⚠️) 🟥
**Mechanism (VERIFIED 2026-07-17, source recovered):** RSI(24) new-low → BuyNow, gated ADX(14)>30 + DI
= trend-aligned *pullback-continuation* (sells rallies in downtrend / buys dips in uptrend). Scale-in grid
(spacing 10p) with **geometric lot `MathPow(Multiple3=1.2, order_count)`** = martingale.
**Why "edge" (NOT transferable):** the profit is the escalation, not the signal — lever isolation on home:
single-order PF **0.90**, flat-lot grid PF **0.72**, only escalated PF **2.20**. Entry has no standalone
directional edge. As-shipped `MAX_Order=99999`/`CutLoss=100` = uncapped-ruin.
**Do NOT mold-expand** (ORDER-095 rejected — no entry edge to replicate; expanding a no-edge geometric
martingale multiplies correlated tail-risk).
**🔴 LIVE guardrail (magic 1524) — "free tail-insurance / DD bounded ~15%" WITHDRAWN 2026-07-26 (ORDER-222).**
The switch was tested at a drawdown that actually reaches it, and it cuts **30% of the balance it has at
that moment**, then re-arms against the reduced balance. Measured ladder over one year at 4× live sizing:
`10,521 → 7,363 → 5,214 → 4,025 → 3,125 → 2,735 → 2,145 → 1,599 → 1,326` (8 cuts, each −30.0..−30.6%,
first one proven to the decimal at −30.02% on 2022.01.27). **A percentage cut against a shrinking balance
is a ratchet, not a floor** — the same year ended **+51% with the cut off and −86% with it on**, and
equity DD reached **87%** while a "30" threshold was active. The old "DD bounded ~15%" was an artefact of
the switch **never engaging** at live sizing, not evidence of a bound.
**Reusable lesson (the transferable part):** a %-of-current-equity kill cannot bound an account — only an
**absolute equity floor that fires once and stays off** can. Cost is non-linear and inverted: nearly free
where DD grazes the line (×2: −12% of profit, DD unchanged), catastrophic where it fires repeatedly. A
guardrail is cheapest exactly where it is useless. Do NOT remove the mechanism (nothing at all is worse on
an uncapped martingale) — replace the *shape*. Verdict: `_triage/ORDER222_NUIINDY_CUTLOSS_VERDICT.md`
(+ ORDER-095: `_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md`).

### Gold Reaper 4.3 — XAUUSD H1 (CORE ⚠️ ruin 1.9%) 🟨
**Why edge:** gold = trender → momentum/continuation edge. Watch flag = thin ruin margin.
**Idea seeds:** XAU is the momentum sandbox; reversion ideas die here (see TrendRegression).

### EA_BREAKOUT_XAU — XAUUSD H1 (CANDIDATE) ✅(type)
**Mechanism:** Donchian channel breakout + ATR-expand filter, BUY-only.
**Why edge:** gold's upward-biased volatility-expansion; breakouts follow through.
**Failure mode:** BUY-only = regime risk if gold reverses secularly; thin OOS (33t).

### LondonConsoBreakout — GBPUSD H1 (CANDIDATE) 🟨
**Why edge:** Asian-session consolidation → **London-open volatility expansion** breaks the range
directionally. Session-timing edge, not indicator edge.
**Failure mode:** GBP concentration; EURUSD variant had no durable edge (dropped).

### EA_SUPERTREND — XAUUSD H4 (CANDIDATE, reduced lot) ✅
**Mechanism:** ATR-based SuperTrend bands; direction flips when close crosses the opposite band.
EMA200 + ADX≥20 filter removes ranging periods. Both directions (no BuyOnly).
**Why edge:** XAU's trending nature rewards trend-following; EMA200+ADX gate ensures entries only
in confirmed momentum conditions. OOS > IS (PF 4.49 vs 1.54) — no overfit signal.
**Failure mode:** Both-direction = vulnerable when gold trends down (shorts lose); ADX filter
doesn't fully protect against slow-grinding adverse trends. High corr with BRK_XAU (0.724).
**Correlation:** 0.724 vs EA_BREAKOUT_XAU. Both directional XAU legs → reduce lot, do NOT cut.
**IS/OOS:** IS PF=1.54 / 37t / DD 2.23% | OOS PF=4.49 / 18t / DD 4.94%
Set: `_mt5_auto/sweeps/_sets/ST_v1_naked_default.set`, Magic=990020, Deploy: XAUUSD H4

### EA_KAUFMAN_ER BuyOnly — XAUUSD H4 (CANDIDATE, reduced lot) ✅
**Mechanism:** Kaufman Efficiency Ratio gate (ER > 0.30 = trending regime) → allow SuperTrend
signal. ER = |net price change| / sum(|bar-to-bar changes|). BuyOnly captures XAU bullish bias.
**Why edge:** ER gate keeps EA dormant in choppy/ranging periods, firing only when price makes
clean directional progress — filters out bad SuperTrend entries that fire in sideways markets.
**Failure mode:** BuyOnly = secular gold downtrend risk (same as EA_BREAKOUT_XAU). Low OOS trade
count (17t — OOS PF=5.19 is reliable signal but small sample; watch live).
**Correlation:** 0.752 vs EA_BREAKOUT_XAU. Reduce lot to 0.005-0.01. Include.
**IS/OOS:** IS PF=2.34 / 50t | OOS PF=5.19 / 17t (OOS >> IS = confirmed no overfit)
Set: `_mt5_auto/sweeps/_sets/KAUERMAN_buyonly.set`, Magic=990127, Deploy: XAUUSD H4

---

## DEAD PILE — what the failures teach (anti-edges worth remembering)
| Pattern | Tested | Lesson |
|---|---|---|
| Naked MACD crossover | GBP+7 majors/crosses | structural ceiling ~1.1 — crossovers carry no edge on FX |
| BB+RSI naked reversion | EUR/XAU | same ~1.1 ceiling — reversion needs an *engine* (no-SL wait, or bounds), not a bare signal |
| RSI-momentum naked (RSI/SMA cross · RSI-50 break · RSI breakout) | XAU+GBP (both momentum homes) | 2026-07-18: no plateau both-window anywhere, all 3 modes entry-swept ×2 TF — flat ~1.0 breakeven, lone winners are isolated spikes. RSI carries no standalone momentum edge; usable only as a confirm-FILTER, never a primary signal |
| TrendRegression (reversion) | XAU | reversion-on-a-trender = no edge (confirms momentum>reversion for gold) |
| Multi-tap count at S/R (Stoch OB/OS "รอบ" before entry) on a TRENDER (XAU) | XAU M15 + EURUSD/EURGBP/AUDNZD | 2026-07-19 ORDER-135 = **PARKED-VERIFY, MAIN-only (NOT dead, NOT redundant).** Multi-tap DOES lift XAU-M15 (K17: 0.91/1039t → 1.45/27t; ZoneTol-tuned zt40 = MAIN 1.51/64t = real structure). But BWD-fails every variant (best zt60 0.90) → MAIN edge is XAU 2023-25 chop-regime; fade dies in 2020-22 gold-trend. **Lesson: reversion-fade on a trender = regime-bound, not both-window robust.** ⚠️ correction: an earlier pass mislabeled the lever "dead" — that was frequency-starvation from MTF+ADX filters (tap2 → 0-3 trades), NOT no-edge; and it is NOT redundant with SMCxSTO 991070 (measured monthly corr −0.10). Prove frequency-adequacy + measure corr before killing a filter-lever |
| DCA overlay (StackMode 92) on a validated single-position EA whose BWD is marginal (~1.0) | Boss_17 Wave5 XAU H4 (ORDER-136 W1) + Boss_15 ST03 (ORDER-135) | 2026-07-19: escalation-MM overlay = **regime-dependence amplifier, not an edge source** — confirmed on TWO hosts. Wave5: base MAIN 1.60/BWD 1.00 → overlay MAIN lifts (1.82-1.85, payoff +14-29%) but BWD drops 0.94→0.91 monotonically with lot-curve aggressiveness (NONE→LINEAR) + eqDD 3.6-4.4×base; depth axis INERT (L6=L4 identical — adds never reach 5+). Rule of thumb: **BWD≈1.0 base = DCA overlay auto-fails the both-window bar; don't burn the full grid — 3 cells + axis-inertness proof = earned close** |
| SessionBreakout | XAU | 1,200-pass ceiling 1.20, forward 0.91 — breakout needs a real range to break |
| Grid/martingale (Golden Elephant, BuRengNong, Setka…) | XAU mostly | "martingale WAS the edge" — strip the doubling, signal is breakeven; DD 60–125% |
| Tight-TP (Game Changer/GMGS) | XAU | Model-2 open-price artifact; TP×10 collapses PF |
| Static (one-time, never re-based) MC-derived price zone as grid bounds | BTC/ETH CFD, AdaptGridMC (ORDER-142, 2026-07-23) | MAIN-window PF 500-1200+ looked like a huge edge — was a **realized-path artifact**: zone computed once from pre-2023 data, BTC's 2023-25 rally exited it permanently after one pass, proven by a 2026H1 holdout on the same zone producing **zero trades**. Not a fill artifact (M4 confirmed M1) — a *dormancy* artifact: the strategy silently stops trading once price leaves its one-time-computed range, and a great-looking backtest hides that it already "died" partway through the window. Lesson: any zone/band/level computed once from historical data (P10/P90, support/resistance, volatility bands) needs a walk-forward re-basing cadence before it can be trusted on trending instruments — check trade-count-over-time within the window, not just aggregate PF, for exactly this signature (front-loaded trades, then nothing) |

---

## IDEA SEEDS (for new strategies)
1. **Vol-gated reversion harvester on EURUSD** — ST03 engine + per-symbol TP/Nearby + the 1.5×ATR_MA(300)
   gate. EURUSD is more liquid/mean-reverting than GBPUSD in theory; failed naked, may pass gated.
2. **Bounded range harvester template** — generalise MatchaGrid's "bounded+SL" to other rangers
   (EURGBP, EURCHF) — low-vol crosses that mean-revert.
3. **London-open expansion** — extend LondonConsoBreakout's session edge to other session opens
   (NY, Tokyo) and to XAU (which trends → breakout-friendly).
4. **Momentum-only on trenders** — keep reversion OFF gold; build a clean XAU momentum/continuation
   EA (Gold Reaper-style) rather than fighting it with reversion.
5. **Tail-filter caution (tested, mostly negative)** — for a no-SL reversion harvester the crisis
   tail resists reactive filters: ATR vol-gate catches only gap spikes; ADX trend-gate is
   counterproductive (lags). Don't expect a TA filter to unlock sizing — diversify instead. A
   *leading* regime signal (macro calendar / cross-asset stress), not a lagging indicator, is the
   only untested angle.
6. **Pairs trading / stat-arb spread reversion** (source: quant-corner.com + Blockdit sweep,
   2026-07-18) — trade the spread between 2 correlated instruments (EURUSD-GBPUSD, Gold-Silver)
   instead of price directly. Whole new signal class — fills the "correlation-as-strategy" gap
   already flagged in `_triage/FXDREEMA_IDEA_CATALOG.md`. Full writeup:
   `_triage/QUANTCORNER_FINDYOUR8_IDEA_CATALOG.md` #1.
7. **ATR-adaptive SL + round-number avoidance** (same source) — pre-placed SL at round-number
   levels gets stop-hunted; use ATR-width SL with a small offset off round numbers. Directly
   addresses the SL-fragility diagnosis from Lane C SMCxSTO (2026-07-18). Catalog #3.
8. **Vertical-barrier exit / max-holding force-close** (Triple Barrier Method, Lopez de Prado —
   same source) — most EAs here only have TP/SL (horizontal barriers), none has a pure
   time-based force-close. Untested exit-mode lever, applicable to existing grid/DCA EAs without
   a rebuild. Catalog #2.

Full idea sweep (15 items ranked, incl. Granger-causality indicator pre-filter, risk-parity
portfolio weighting, multi-EMA stacked entry filter) → `_triage/QUANTCORNER_FINDYOUR8_IDEA_CATALOG.md`.

9. **Volatility/statistics-scaled grid zone+spacing+sizing** (source: FINDYOUR8 free-book PDFs,
   Wongsakon, 2026-07-19 — logged-in deep dive of 9 strategy decks). The recurring edge across all
   his systems = derive grid geometry from volatility + statistics instead of fixed naive steps.
   Reusable levers (each = build-on candidate, ALL crypto-spot homes → mind swap when porting to CFD):
   - **⭐ Monte-Carlo block-bootstrap grid zone** — 10k paths × 60d, 24d blocks → P10/P90 = grid
     bounds; spacing = 0.3·ATR(RMA30); flat lot + capped band + hard −20% kill (SAFE, not martingale).
     THIS is the "MC+bootstrap+ATR grid zone" flagged "ยังไม่แตะ" in the 07-18 sweep — now fully spec'd.
   - **geometric constant-% spacing** `ratio=(hi/lo)^(1/N)` (replaces fixed-step grids)
   - **inverse-ATR anti-martingale lot** `lot = base×baseATR/curATR`
   - **Lower-BB(EMA30−1σ)-as-trailing-VolStop** + **vol-normalized sizing `size% = RPT%/band-dist%`**
     — directly addresses the Lane C SMCxSTO SL-fragility (seed #7 sibling)
   - **KAMA continuous adaptive-MA block** (ER→SC²→recursive MA) — a continuous adaptive filter ≠ our
     discrete `_50_Regime.mqh` on/off gate
   - **fee/swap cost-model as first-class backtest input** (notional taker + crypto funding drag)
   Full writeup + red flags + per-deck spec → `_triage/FINDYOUR8_STRATEGY_PDF_CATALOG.md`.
   Recommended first probe = Adaptive Grid MC-zone on BTC/ETH CFD (crypto lane, TrendRider precedent).

---

## IDEA: JUMSTOCH mean-reversion grid → build-on vehicle (user directive 2026-07-11)

**แกะ entry logic (จาก JUMSTOCH_FIXEDLOT.mq4, ORDER-091C-D1):**
- `ima = iMA(LWMA, maPereode, Close)` current TF · `stoch = iStochastic(k=32, d=12, slowing=12, MAIN)`
- **BUY** เมื่อ `Close[1] < LWMA` (ราคาต่ำกว่า MA) **AND** `stoch > lo_level(25)` → คาดเด้งกลับขึ้น
- **SELL** เมื่อ `Close[1] > LWMA` (ราคาเหนือ MA) **AND** `stoch < up_level(75)` → คาดย่อลง
- = **mean-reversion เข้าหา LWMA + Stochastic filter** · averaging grid ≤12 legs spacing Range=21 · SL=253/leg · fixed-lot

**ผล funnel (ORDER-091C-D1):** plateau สะอาด 9/9 ทั้ง EURUSD H1 + AUDUSD H1 · OOS +1.06~1.12 · MC ruin 0% ·
= edge จริงแต่บาง (PF>1 = ต่อยอดได้ ตาม doctrine build-on)

**ทางต่อยอด (เรียงตามคุณค่า):**
1. **Pending-limit entry** (user idea + tie ORDER-080): mean-reversion วาง buy-limit ใต้ราคา/sell-limit เหนือ
   ที่ระดับ grid = fill maker ไม่จ่าย spread → แก้ concern spread โดยตรง (grid 5-7k ไม้ ประหยัด spread = อาจดัน PF 1.12→1.3+)
2. **ขยาย symbol×TF เต็ม** — D1 ลองแค่ 4 คู่ × 3 TF · เหลือ majors/crosses อีก 10+ คู่ × ทุก TF (home อาจดีกว่ามาก)
3. **แกะ entry → Boss V2 chassis** (build-on #1): LWMA-displacement+Stoch = signal reusable บนโครง MM ที่ cap+SL พิสูจน์แล้ว

**mechanism class:** reversion-to-MA (มีใน landscape แล้วแต่ variant นี้ = LWMA + Stoch dual-filter + capped SL'd grid = โครงสะอาดกว่า naked reversion ที่ตายในปีเทรนด์)

---

## IDEA: MACD-gate + MTF Demand/Supply reversion + volume-confirm (external concept, 2026-07-11) 🟨

**Source:** FB reel "Trading by sen" — ระบบชื่อ **MACD Trend Filter + MTF Demand/Supply Cloud**
(https://www.facebook.com/share/v/1RRNjBc3Qm/). โพสต์ขายอินดิเคเตอร์ → **ตัวเลข threshold จริงไม่เปิด**
(นั่นคือของที่เขาขาย). แกะได้จาก caption + ชื่อองค์ประกอบ = **concept-level เท่านั้น ยังไม่เห็นตัวเลข/ผลจริง.**

**กลไกที่ประกอบออกมา (inferred, ยังไม่ verify):** "เทรนด์กรองทิศ → รอย่อเข้าโซน → volume ยืนยัน" —
1. **MACD Trend Filter** = ประตูทิศทาง (ไม่ยิงสัญญาณเอง): MACD>0 อนุญาต Buy เท่านั้น / <0 Sell เท่านั้น
2. **MTF Demand/Supply Cloud** = โซน S/D จาก TF ใหญ่ วาดลง TF เล็ก → รอราคาย่อกลับมา *แตะ* โซน (buy ที่ demand, sell ที่ supply) ที่ align หลาย TF
3. **Pivot Volume Strength** = ยืนยันแรงฝั่งเดียวกับที่จะเข้า (pivot กลับตัว + volume สูงในโซน) = กรอง breakout ไร้แรง
4. **Exit** = โซนตรงข้ามถัดไป หรือ MACD พลิกทิศ

**แปลเป็น edge thesis เรา:** momentum-regime gate (MACD) + **reversion-entry** (แตะโซน S/D) + volume filter —
ตรงกับ core thesis (momentum ทำนายทิศ, การแตะโซน = จุดเข้า reversion). class ซ้ำกับ NuiIndy (RSI+ADX filtered-reversion)
และ ST03 harvester แต่ **entry ใช้ S/D zone แทน oscillator** = angle ใหม่ที่ยังไม่มีใน landscape.

**gap ที่ต้องได้ก่อน build (ทั้งหมดยังไม่รู้ = ตัวชี้ขาด edge vs กราฟสวย):**
① MACD params + line-cross vs histogram-zero · ② อัลกอวาดโซน S/D (swing-pivot? consolidation-before-impulse?) + TF mapping ·
③ นิยาม "volume strength" (เทียบ MA กี่แท่ง? threshold?) · ④ กติกา exit จริง

**สถานะ:** PARKED-CONCEPT — รอ (ก) user ดูวิดีโอ/ส่ง screenshot เติมตัวเลข **หรือ** (ข) ตัดสินใจ build เวอร์ชันเราเอง
ตั้ง default params สมเหตุผลผ่าน `strategy-and-risk` → smoke-test. ยังไม่คุ้มเปิด build campaign จนกว่าจะเห็นตัวเลข/ผลจริงเพิ่ม.

---

## EDGE: MACD-divergence reversion @ XAUUSD H4 (ORDER-098-B, 2026-07-16) 🟩 BUILD-ON CANDIDATE

**กลไก:** price LL แต่ MACD main HL (bullish, mirror bearish) · naked flat-lot 0.01 · SL = 3-bar extremum ·
TP = 200% SL · EA = `ea_projects/(EXP)_MacdDiv_Naked/` (magic 999094) · set = `_mt5_auto/ab_sets/order098b/MacdDiv_Naked_XAUUSD_H4_optPF.set`
**หลักฐาน (Model 1):** MAIN 23-26 PF 1.91/280t **plateau จริง** (9 neighbor 1.33-1.90 ไม่มีตัวขาดทุน) ·
BWD 20-22 = 1.04 (เอาตัวรอด regime ตรงข้าม) · **HOLDOUT 2026H1 = 1.30/39t** (window ไม่เคยใช้ select) ·
MC reshuffle ruin 0%, DD worst 4.76%. **เหลือ:** Model-4 real-tick ×3 windows + corr vs gold cohort → demo.
**บทเรียนคู่กัน:** EUR H4 สวยทั้ง MAIN 1.71 + BWD 1.15 แต่ **holdout 0.35 = selection-fit** — ยืนยันคุณค่า
holdout ที่ไม่เคยใช้ select (gate #6) ว่าจับของปลอมที่ 2-window gate จับไม่ได้.

## LEVER: break-and-retest split entry (market + pending-limit) on breakout EAs (ORDER-108, user idea 2026-07-16) 🟩 VALIDATED-LEVER

**กลไก:** breakout ยิง → **market leg** ที่ราคาทันที (จับ runner ที่ไม่ retest) + **pending buy-limit** ที่แนวที่ทะลุ
(retest, maker ไม่จ่าย spread, SL แคบชิดแนว). EA testbed = `(EXP)_BRK_SplitRetest` (`_07_UseSplitEntry` + market/pending lot).
**หลักฐาน (Model-4 XAU H1, EA_BREAKOUT_XAU base):** retest fill-rate **~90%** (แตะบ่อยมาก) · adverse-selection จริง
(pending-only แพ้ market ในเทรนด์ 1.76<2.07 = พลาด runner → ต้องมีขา market) · **split = robust ทั้ง 2 regime**
(1.93/1.97 ไม่มี window อ่อน ต่างจาก market-only 2.07/1.75 และ pending-only 1.76/2.55). live ได้ maker-fill ฟรี
spread เพิ่มบน ~90% ของไม้ retest = edge ที่ tester ประเมินต่ำ. **ใช้ได้กับ breakout EA ที่มี edge เท่านั้น**
(ห้ามแปะ EA ที่ปัญหาคือ regime เช่น XAU_NY). **config-conditional:** ช่วยเฉพาะเมื่อขา retest มี edge ในหน้าต่างที่ market
อ่อน — Bars40/TP5 ช่วย (regime-robust) แต่ **live Bars55/TP8 ไม่ช่วย** (retest อ่อน BWD, TP กว้างต้องการ move ใหญ่)
→ **ห้าม retrofit ตัว live**, ใช้กับ build ใหม่ที่ config สมดุล. verdict = `_triage/_archive/verdicts/order104-126/ORDER108_SPLIT_RETEST_VERDICT.md`.

## SMC × STO multi-TF reversion (user idea, 2026-07-16) 🟩 BUILD-ON candidate (optimized, ranger-home)

`(EXP)_EmaStoRev` (HTF EMA-gate + STO reversion). **default-smoke หลอก** (0.63-0.89 — STO 5,3,3 noise เยอะ).
**optimize จริงพลิกผล:** XAU (trender) = regime-fit (MAIN 2.30 / BWD ล่ม) · **EURUSD (ranger = บ้านถูก) = 2/3 top
pass ยืน both-window** (1.30/1.13 · 1.22/1.02). survivor = **StoK17** (ไม่ใช่ 5) · OS10-15 · SL3.0 · TP1 · EMA50.
= edge **เฉพาะ EURUSD H1** (ไม่ travel: AUDNZD/EURGBP/XAU ล่ม BWD). **ADX filter (user idea) ยกดีขึ้น:** best =
StoK13/OS30/AdxMax30/EMA50/SL3/TP1 = **MAIN 1.50 / BWD 1.24, 130 ไม้** (จาก no-filter 1.30/1.13). filter ต่อยอด
edge ที่มี ไม่สร้าง edge (AUDNZD กู้ไม่ได้). = **EURUSD-specific candidate** (plateau+Model-4 ก่อน demo). verdict =
`_triage/_archive/verdicts/order104-126/ORDER107_SMCxSTO_STAGE0_VERDICT.md`.
**บทเรียนถาวร: default-smoke ≠ concept-kill — optimize + right-home + filter ก่อนตีตาย reversion (user push ถูก 2 เรื่อง).**

## LEVER: HP-denoise (Hodrick-Prescott causal) @ λ1600 on trend-cross (ORDER-104C, 2026-07-16) 🟩 REUSABLE

**Source:** user-shared class system. Rules: M15 EMA100 = direction bias (buy-only above / sell-only below) →
M5 fresh untouched Order Block / POI zone (wait for price to re-enter) → M1 Stochastic cross out of OS/OB
*inside the zone* = trigger → exit: SL→BE at STO50, close on STO opposite-extreme reverse.
**Class = momentum-GATED REVERSION** (EMA gate = trend, STO-cross-at-zone entry = reversion). Same family as
NuiIndy (the one reversion survivor) — not a new class. Against the standing momentum>reversion prior + M1 scalp
= spread-exposed = double headwind. BUT: SMC Order-Block entry is genuinely untested here (FVG≠OB; flagged
present-but-untested in ORDER-079 corpus) and the exit is fully mechanical (testable).
**Cheap 2-stage smoke plan (build when a lane frees):** Stage 0 = strip the SMC/OB (expensive) → naked
EMA100-gated STO-cross reversion probe on M15 (skip M1 for triage), EURUSD/GBPUSD/XAU, Model 1 — if core PF<1
everywhere, OB won't save it → DEAD. Stage 1 (only if pulse) = add M5 OB-zone gate (ring-buffer state like
ORDER-098-A) → should raise win%. Full plan + hard-parts = `_triage/_archive/one_off_analyses/SMCxSTO_SIGNAL_TRIAGE.md`.
**Verdict: worth a cheap Stage-0 smoke (~1-2h), NOT a build campaign on hope.** Sibling of the MACD-gate S/D
concept above (both = untested reversion-at-zone).

## LEVER: HP-denoise (Hodrick-Prescott causal) @ λ1600 on trend-cross (ORDER-104C, 2026-07-16) 🟩 REUSABLE

**ไม่ใช่ EA — เป็น bolt-on lever:** กรอง noise ความถี่สูงด้วย causal HP filter *ก่อน* คำนวณ MA → ลด false cross.
EA testbed = `(TRD)_Probe_MAHP_TanhVol_rev01` (`_02_UseHPFilter`/`_02_HP_Lambda`). **ยืนยัน both-regime plateau
บน XAU H4:** fast16/slow32/λ1600 = MAIN 1.59 / BWD 1.33 · เพื่อนบ้าน MA 4 ทิศผ่าน · SL {1.5,2.0,3.0} ผ่านทั้งหมด ·
λ1600 = center (λ800 MAIN พัง, λ3200 เสื่อม). **HP ช่วยเฉพาะ XAU ไม่ช่วย EUR** (Stage A/B). chassis 2-MA เปล่า
ไม่ใช่ keeper — คุณค่า = lever ไปแปะ production trend chassis (BREAKOUT/SuperTrend) เป็น axis ใหม่ใน funnel.
verdict = `_triage/_archive/verdicts/order104-126/ORDER104C_HP_PLATEAU_VERDICT.md` · gate ที่ทำให้ valid = HP one-sided causal (reviewer ยืนยันไม่มี look-ahead).

## LEVER: vertical-barrier time exit `_2_MaxHoldBars` (ORDER-125, 2026-07-19) 🟨 BUILT — DEAD-ON-GRID, untested elsewhere

- **What:** basket-level force-close after N chart-TF bars from basket inception (QuantCorner Triple Barrier time leg). In chassis, default 0=off byte-identical, Codex-hardened (inception latch กัน clock-reset เมื่อ leg ปิดเอง · iBarShift −1 guard · Boss_16 no-op warn · partial-milestone leak fix).
- **A/B host Boss_14 GBPJPY H4 (locked leg8 set): DEAD ทุกค่าที่ M4** — MH130 ตาย M1 (BWD 0.73; MAIN lift 2.16 = regime-fit ห้ามไล่) · MH390 ผ่าน M1 แต่ **M4 พลิก** (BWD 1.11→0.85, net +210→−368). verdict `_triage/_archive/verdicts/order104-126/ORDER125_VERTBARRIER_VERDICT.md`.
- **Mechanism lesson (จ่ายแล้ว):** (1) **recovery tail ของ grid คือเครื่องยนต์** — basket 203 วันใน BWD สุดท้าย recover; time-cut = realize tail loss = ตัด edge ตัวเอง. ห้าม enable lever นี้บน grid/DCA family. (2) **M1→M4 flip บน exit lever** — M1 มองไม่เห็น path ใต้น้ำ; exit/time lever บน grid = M4-deciding เสมอ (ยืนยันซ้ำ precedent ORDER-126 SL-fan).
- **Open home (ยังไม่ทดสอบ):** single-position trend-following (SuperTrend/TrendRider) ที่ time-stop เป็น convention — ถ้าจะใช้ ต้อง A/B บน host นั้นก่อน.

## DEAD CELL: naked FVG-fill entry @ EUR/XAU H1+H4 (ORDER-098-A, 2026-07-16) ⬛

EX009 geometry (3-bar gap retrace + engulfing confirm) **ไม่มี edge ที่ exit geometry ใดๆ**: 22 runs,
RR sweep TP{15→60}@SL20, both regimes — PF peak 0.98 แล้วหักลง (cost-dilution ไม่ใช่ edge), ไม่เคย >1
ใน 26 cells. **ปิดเฉพาะ naked-entry** — FVG-as-confluence-filter ให้ entry อื่นยังไม่เคยเทส (เปิดอยู่).
verdict = `_triage/_archive/verdicts/order076-098/ORDER098A_FVGFILL_SMOKE_VERDICT.md`

## LEVER: add-gating a grid (gate the ADDS, not just the seed) — from AdaptiveGrid_Oil (2026-07-17) 🟩 REUSABLE

**Facebook "Adaptive Grid Oil" build → the EA has no portable edge (PARKED-VERIFY, see
`ea_projects/(Boss)_AdaptiveGrid_Oil/VERDICT.md`), but one lever is worth keeping.** A trend filter that
gates only the FIRST seed is **inert on a grid** — a grid is almost never flat, so it spends its life
managing an open basket and adding legs, none of which the seed-gate touches (proven: SlopeThresh 0.01→0.15
had ~0 effect, counter-trend still bled ~−4150). **Fix = gate the grid-ADDS**: stop adding legs once the
trend has turned against the basket (FilterMode=AGREE + GateAdds). Structural improvement on the
with-trend direction: DD 40%→11–20%, largest-loss −312→−92, PF 1.2→2.0. Bolt-on for any averaging/grid EA
that bleeds counter-trend. Caveats that sank *this* EA (do not repeat): (a) fixed-direction grid P&L = pure
window drift-capture (inverts up↔down years); (b) dynamic single-instance direction **whipsaws** on
counter-trend pullbacks; (c) slower LinReg/EMA filter made it WORSE not smoother; (d) spacing×TP surface
was spike/hole, and no config was portable across symbol (WTI↔BRENT) + TF (H1↔H4). Slope-on-EMA as a
regime detector = too weak/noisy — try ADX or Donchian if reusing the add-gate idea elsewhere.
**⚠️ METHODOLOGY LESSON (paid 2026-07-17): Model 2 (1-min OHLC) manufactures fake grid plateaus.**
Per-symbol optimize found AUDNZD d1.0/t1.2 with a textbook Model-2 both-window plateau (PF 3.96 up /
3.19 down, DD 7–14%, win 86%, flat in spacing) — looked like a validated ranger edge. On **Model 4
(99% real ticks) it lost: PF 0.61 / 0.75, maxLoss −138→−631.** The 1-min-OHLC fill path flatters a
grid's intra-bar entries/exits; real tick sequencing kills it. **Never trust a Model-2 grid result —
confirm on Model 4. Tell-tale = largest-loss jumps hard when you switch models.**
**✅ NOW IN THE CHASSIS (2026-07-18): `_9_RegimeGateAdds` (default false, additive).** Wired into
`Stack_DecideAdd` — when on, refuses a grid ADD whose direction the 5x ADX Regime disallows (the LabCore
Regime gate only blocked the flat seed; a grid is never flat, so adds sailed through). Validated on
Boss_14 GridLog: neutrality byte-identical OLD-vs-NEW when off (PF 1.67/net 833.96 exact); **Model-4 A/B
on AUDNZD full 2019-26: gate ON cut eqDD 12.3%→5.4%, maxLoss −70→−58, PF 0.91→1.04** (defensive — trims
the DCA tail, doesn't chase PF). Cage green (run_tests ALL PASS; tpl_regression drift = pre-existing
stale-baseline, trade-counts identical). Opt-in per EA (esp. useful for GRID_AGAINST/DCA on trend-prone
symbols); needs `_50_RegimeMode!=0`. Best config found: mode 1 + AllowTrendDown=false for a long DCA
(add in range+uptrend, stop adding into a downtrend).

## LEVER: PA-confirm on grid ADDS (engulfing) — StackConfirm=CONF_PA_ENGULF (2026-07-18) 🟩 REUSABLE (defensive)

Sibling of add-gating: gate the grid ADD on a **candle pattern** instead of blind distance. `Stack_ConfirmOK`
mode 4 (`CONF_PA_ENGULF`, additive) requires an engulfing in the add direction — a long add needs a bullish
engulfing (real bounce), a short add a bearish one. Detector = `core/PriceAction.mqh` (`PA_Bull/BearEngulf`,
`_9_PA_MinBodyRatio`). Validated on Boss_14 GridLog AUDNZD **Model-4 real ticks, both-window**: distance-only
DCA was net −286 / worst-DD 9.6% (bleeds the 2019-22 window −711); PA-confirm adds → net **+98 / worst-DD 4.7%**
(UP −711→+4, DN +425→+94), trades cut ~60%. **It is a RISK-TRIMMER / bleed-stopper, not a profit-maximiser** —
it sacrifices upside in the good window to kill the bleed in the bad one, netting both-window-positive + half DD.
Cage green (run_tests ALL PASS; neutrality byte-identical OLD-vs-NEW when StackConfirm≠4).
**⚠️ Context split (Phase 0 + Step 1):** PA as a NAKED entry filter FAILED both-window (window-fit; XAU-H1-cont
PA-on +8.7 exp in 23-26 but −1.8 in 19-22; EURGBP-rev negative both) — PA does NOT create a standalone edge.
Its value is as a CONFIRM on an existing basket's adds. Matches the session lesson: confirm/MM layers multiply
or protect an existing edge, they don't manufacture one. Probe + evidence: `ea_projects/(TRD)_PA_Probe/`.

## DEAD CELL: JumStoch Trend-seed (LWMA-displacement + Stoch) on Boss V2 DCA chassis (Boss_18, 2026-07-18) ⬛

Ported the JUMSTOCH "Trend" block (LWMA(25) displacement + Stoch(32,12,12) filter) as a chassis SEED signal
(grid/DCA = StackMode 92). **28 Model-4 runs, uniformly sub-1.0 both-window** (base fixed-TP 0.58–0.71 →
faithful basket-ATR-TP exit 0.82–0.94 → H4 0.85–0.92). Swept DirMode(faithful momentum-join / reversion) ×
symbol(EUR/AUD) × direction(BUY/SELL) × exit-mode × TF(H1/H4) × window. **Both direction mappings score equal
and both lose** → the seed is directionless; the brief-vs-source direction discrepancy was moot. **The JUMSTOCH
edge lives in the standalone's combined 4-basket (Trend+Counter) + BEP-shift + trailing engine, NOT the seed
signal** — stripping the seed onto a generic DCA chassis removes the edge source. Matches the standing lesson:
MM/exit layers multiply an existing edge, they don't manufacture one. Standalone `(EXP)_JUMSTOCH_MT5` untouched.
Boss_18 code kept + caged (documented dead-seed, not deploy). verdict = `_triage/_archive/verdicts/ORDER_LANEA_JUMSTOCH_VERDICT.md`.

## LEVER: basket-close beats per-leg-TP on flat-lot DCA (JumStoch exit sweep, 2026-07-18) 🟩 REUSABLE

On a flat-lot DCA grid, a crude **fixed per-leg TP(30pip) + big SL(253pip)** bleeds (PF 0.65) — small wins can't
pay for the occasional multi-leg SL. Swapping to a **basket-level ATR-TP** (`_2_SuppressLegTP=true` +
`_2_BasketTP_ATRmult`, the proven Boss_14 pattern) lifted the SAME entry ~0.30 PF (0.65→0.94) across every cell.
Basket-close (all legs exit together near basket-BEP+) is structurally right for DCA; per-leg TP fragments the
basket. Confirms the Boss_14 GridLog exit design; use basket-TP (not per-leg fixed-TP) as the default DCA exit.

## EDGE: XAU H4 trend pullback-continuation (TrendRider, ORDER-139, 2026-07-20) 🟩 VALIDATED CANDIDATE
Entry = established trend (EMA50>200 + ADX≥20 + EMA separation ≥0.5×ATR) + pullback ที่แตะ EMA21 แล้วปิดกลับ
ทิศ trend · SL 2×ATR · **Chandelier trail (HH10 − 2.5×ATR) ไม่มี fixed TP**. Funnel เต็มผ่านหมด (plateau 6-cell /
holdout 1.33 / M4 retained / MC ruin 0 / corr ≤0.32). **Insight สำคัญ: AdxMin 20 (หลวม) ชนะ 25/30 ทั้ง BWD —
EMA-separation ทำหน้าที่กรองแทน; ADX floor สูง = ตัด early-trend entries ที่เป็นกำไร BWD.** และ ChAtr กว้าง (3.0)
ช่วย BWD เสมอ (trail แน่น = โดน whipsaw เขย่าออก). Reusable levers: Chandelier-trail exit + separation-gate.
⚠️ BWD ~1.0 borderline → ห้ามใช้เป็น host DCA overlay (กฎ ORDER-136: BWD~1.0 base = overlay auto-fail).

## DEAD-CELL: XAU M15 sweep-and-reject reversion (SweepReversal, ORDER-139, 2026-07-20) 🟨 PARKED-VERIFY(user)
Sweep prior-day H/L + $25 grid ≥0.3ATR แล้วปิดกลับ + RSI confirm + ADX(H4) stand-down = **MAIN 1.31–1.85 จริง
แต่ BWD <1 ทุก cell ที่ n สุขภาพดี** (2020-22 trend years: sweep ไม่ reject มัน continue) · ladder ครบ 4 lever × 2 TF.
กลไก sweep-detect (wick beyond structural level + close-back) = อะไหล่ reversion ที่ reusable บน ranger home
(EURUSD/EURGBP/AUDNZD ยังไม่เทส — ถ้าจะฟื้นให้ไปบ้านนั้น ไม่ใช่ tune XAU ต่อ).

## NULL: LondonORB symbol expansion (ORDER-140, 2026-07-20)
ORB plateau XAU M15 (1.17/1.07) ขยาย: GBP MAIN 0.79 ตาย · EUR ตายทั้งคู่ · USDJPY M15 1.14/1.10 + XAU M30
1.13/1.08 @n~700 = **edge จริงแต่บางใต้ bar ทุกบ้าน** — ORB-with-ATR-band เป็น broad thin edge ไม่ใช่ deploy edge.

## LEVER: PROG_FIBONACCI lot-cap vs PROG_LOG_POWER on Boss_14 GridLog XAU (ORDER-197, 2026-07-24) ⬛ NOT ADOPTED

fxDreema-corpus MM-part (`PROG_FIBONACCI`, corpus EX191, built off-by-default in ORDER-098-C) tested as a
drop-in swap for the live XAU leg's (990207) existing `PROG_LOG_POWER` progression — isolate ONE variable
(`LotProg` 55→56 + `_56_FibMaxStep=5`), everything else byte-identical. **Result: mixed, and the pre-registered
bar (must beat-or-tie on BOTH windows) fails.** MAIN 2023-2025: 1.91→1.83 (worse, −0.08 PF) with eqDD
4.06%→5.27% (~+30% relative, real not noise). BWD 2020-2022: 1.19→1.23 (better, +0.04 PF), but that window's
last 80% of days traded zero for both configs (quiet tail, not a hard-kill truncation — verified via
`check_truncated_run.ps1`), so the BWD comparison itself is thin/low-power even though it's apples-to-apples.
**Reading:** PROG_LOG_POWER's smoother, more continuous curve fits this basket's actual DD dynamics on the
window that matters most (MAIN, the pinned re-opt window) better than Fibonacci's step-function jumps —
losing on the harder/larger/more-recent window rules it out per doctrine even though it won the smaller one.
Boss_14 XAU leg's live `.set` (`Boss14_GridLog_XAU_DEMO.set`) untouched, still `LotProg=55`. Raw reports:
`_mt5_auto/reports/ORDER197_{BASELINE,FIB}_{MAIN,BWD}.htm`. **Do not re-test this exact swap on Boss_14 XAU
again without new evidence** — `_56_FibMaxStep` sweep or a different chassis/leg would be new evidence,
re-running the same two configs would not.

## LEVER: LOG-power escalation beats flat-lot on a grid in the STRESS regime (Boss_14 GBPJPY, ORDER-136 Wave 2, 2026-07-24) 🟩 CONFIRMED (regime-conditional)

First positive result of the escalation-MM overlay campaign (ORDER-136) after Wave 1 lost. On Boss_14 GridLog
GBPJPY H4 (live leg-8, magic 990208, the ORDER-166-revalidated `dist=2.0` config), **LOG13 escalation
(`LotProg=55`, LogPower factor 1.3) beats flat lot (`LotProg=50`) on the BWD stress window under real-tick
Model-4: PF 1.32 vs 1.07, ~4× net profit, AND lower eqDD (8.08% vs 10.71%) despite the escalating lot size.**
On MAIN (calmer 2023-2025 regime) the two are effectively tied — the grid rarely stacks past level 1 there, so
the lever never engages (Model-1 identical 1.57/40t; proxy 2.7yr Model-4 near-identical 3.51 vs 3.57). Reading:
a bounded log-power lot ramp adds real edge specifically where the grid actually deepens (volatile/trending
stress years pull price through more grid levels), and costs nothing where it doesn't — the opposite failure
mode from Wave 1, where a DCA overlay on a BWD≈1.0 host amplified regime-dependence and lost. **The
differentiator is the host's BWD strength: escalation overlay is worth it on a host whose BWD is comfortably
>1.0 (GBPJPY leg-8 = 1.32 flat-ish base), harmful on a host teetering at ~1.0.** Practical: keep the live
GBPJPY leg-8 on `LotProg=55`, do not revert to flat. Contrast with ORDER-197 (Fibonacci step-function lot on
Boss_14 XAU) which LOST — bounded ≠ automatically good; the progression *shape* and the host regime both matter.
Raw: `_mt5_auto/reports/O136_W2RETEST_*`. ⚠️ paid-for tooling gotcha from this order: MT5's error
`"no disk space in ticks generating function"` is a generic allocation-failure message — it fired here from a
memory/pagefile commit ceiling (RAM ~4GB free of 32, pagefile+TEMP on the tight C: drive) while both disks had
ample free space; do not chase it as a literal disk problem. Model-4 pre-generates the whole window's tick
array upfront, so a big window can hit the commit ceiling and abort ~10s in with zero trades.

## LEVER: MACD-vs-signal-line cross as a timing confirm on a divergence entry (MacdDiv, ORDER-217, 2026-07-25) 🟨 BUILT — REGIME-CONDITIONAL, NOT DEPLOYED

**Where it came from.** ORDER-216 found `_02_MacdSignal` was fed to `iMACD()` but buffer 1 (the
signal line) was never read anywhere in `(EXP)_MacdDiv_Naked` — the entry was pure divergence with
no timing confirmation at all. Rather than delete the dead input, wire the mechanism it implies.

**The lever.** `_08_UseMacdCross` (default false) + `_08_CrossWithinBars`: take the divergence
entry only if MACD has crossed its own signal line in the same direction within the last N closed
bars. Additive, default-OFF, proven byte-identical when off (MAIN 1.82 / 280 / 1506.02 before and
after, same binary path). N=1 is the best setting; longer windows monotonically decay
(MAIN PF 2.98 → 2.83 → 2.73 → 2.48 at N = 1, 2, 3, 5).

**What it does — the honest version.** It removes roughly **88% of trades** and lifts MAIN PF at
every SwingRadius. At the deployed `_01_SwingRadius=3` it takes MAIN 1.82 → 2.98 (280 → 34
trades) but takes **BWD 0.98 → 0.81**. At SR2 and SR4 it clears both windows (2.52/1.42 and
2.30/1.13) — which the ungated EA cannot do at any SwingRadius.

**Why it is not deployed.** Three reasons, and the third is the one that matters:

1. **n collapses to 16–34 trades per window over three years.** PF 1.42 on 16 trades is not a
   measurement. Any filter that keeps 12% of trades will raise PF on the survivors; that is
   arithmetic before it is edge.
2. **The knife-edge did not flatten — it inverted.** Gate OFF, MAIN peaks at SR3 and BWD at SR4.
   Gate ON, MAIN still peaks at SR3 but BWD now peaks at SR2. Still regime-split, just differently.
3. **In the stress regime the filter selects WORSE trades.** If the 88% it discards were dropped
   at random, PF would hold near baseline. On MAIN it rises (selection value); on BWD at the same
   setting it falls, 0.98 → 0.81. So the filter's ability to pick is itself regime-dependent —
   the same disease as the host it was meant to cure.

**Reusable claim (narrow, on purpose):** an independent timing confirm CAN lift a divergence
entry's in-sample PF hard, and can move a both-window failure into a both-window pass at some
parameter settings. It does **not** buy regime-robustness, and the trade-count cost is severe
enough that thin-sample EAs cannot afford it. Try it where the host already has trades to spare
and a *symmetric* weakness — not where the host is already regime-split.

Source: `ea_projects/(EXP)_MacdDiv_Naked/MacdDiv_Naked.mq5` (`[08]` block) · sets
`_mt5_auto/ab_sets/order217/` · reports `_mt5_auto/reports/O217_*`.

## LEVER: Kaufman ER regime gate ported onto SuperTrendFlip (rev02, 2026-07-26) 🟩 CONFIRMED both-window (XAU H4)

**Where it came from.** Cells #13/#14/#15 of ORDER-GEN-STANDING all showed the same failure shape —
the SuperTrend flip fires in chop (BTC H1 has *no* plateau without a trend filter; XAU BWD is
break-even). This catalog already recorded the fix for this exact family: `EA_KAUFMAN_ER` (ER>0.30
gate + SuperTrend signal) scored PF 2.34/50t on XAUUSD H4 where naked `EA_SUPERTREND` scored
1.92/33t at corr 0.946 — same edge, ER version dormant in ranging periods. So: port the gate as a
lever instead of keeping two EAs.

**The lever.** `_03_UseER` (default false) + `_03_ErPeriod` + `_03_ErMin` in
`(TRD)_SuperTrendFlip_rev02`. ER = |close[1]−close[1+N]| / Σ|close[i]−close[i+1]| over closed bars,
in [0..1]: 1 = straight move, ~0 = chop. Blocks **entry only**; open-position management untouched.
Unmeasurable ER (data hole / zero path length) = gate closed, never "pass". `OnInit` refuses
`ErMin>=1.0` or `ErPeriod<2` loudly — a gate that can never open would otherwise emit 0-trade
passes that read as "no signal" instead of "impossible setting".

**Regression cage passed byte-exact:** rev02 with the gate off = rev01 on XAUUSD H4 MAIN M4
(PF 1.51 / 211t / +1372.94 / eqDD 2.96 / bars 4637), confirmed across two different terminal lanes.

**Result — Model-4, XAUUSD H4, ErPeriod=8 / ErMin=0.20:**

| window | baseline (rev01) | ER 8/0.20 |
|---|---|---|
| MAIN 2023.01–2025.12 | 1.51 / 211t / +1372.94 / DD 2.96% | **1.62 / 156t / +1142.32 / DD 2.11%** |
| BWD 2020.01–2022.12 | 1.03 / 206t / +58.91 / DD 4.60% | **1.09 / 163t / +134.18 / DD 4.50%** |

PF up on both windows, MAIN drawdown down a third, BWD net 2.3×. Per-trade edge: MAIN 6.51 → 7.32,
BWD 0.29 → 0.82. **Cost: 26% of trades and 17% of MAIN absolute net.** The gate buys quality, not
more money — on a fixed lot it is a *risk-adjusted* win, and its value is realized only if the freed
capacity is spent elsewhere (or the lot is raised, which is a separate decision with its own gate).

**The finding that matters more than the numbers — how the sweep tried to fool us.** Over 20 combos
(ErPeriod 8/12/16/20 × ErMin 0.20–0.40) the pattern is monotone and it is a trap:
- **Long ER window (12–20) fits MAIN and kills BWD.** Best MAIN of the whole sweep is
  ErPeriod=12/ErMin=0.20 at **PF 2.405 / 105t / +1488.66** — better MAIN than baseline on half the
  trades. Its **BWD is 0.838, net −165.61**. Selecting on MAIN alone adopts a losing config.
- **Short ER window (8) improves both windows modestly.** That is the only both-window family.
- Every row showing PF 2.5–3.8 has **n = 6–30 trades**. Arithmetic, not edge.

**Rule this earns:** a chop filter must be judged on the window it was *not* tuned on, and its
window-length parameter is the axis that decides whether it is a filter or a curve-fit. Pre-register
"must improve both windows" *before* reading the sweep — the same trap caught the Donchian lever on
XAU the same afternoon (below).

Source: `ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev02.mq5` (`[03b]` block) ·
sets `_mt5_auto/ab_sets/genstanding_stf/STF_XAU_H4_er*.set` · reports `ER8_XAU_H4_*_M4`,
optimizations `ER_XAU_H4_{MAIN,BWD}.xml`.

## LEVER: Donchian-break confluence on a SuperTrend flip (2026-07-26) 🟨 SYMBOL-SPECIFIC — adopt on BTC H4, reject on XAU H4

**The lever** (already coded in rev01, never tested until now): `_01_UseDonchian` + `_01_DonBars` —
the flip only counts as an entry if the signal bar also breaks the prior N-bar Donchian range.

**It splits by symbol, in opposite directions, on the same afternoon and the same EA:**

| | MAIN | BWD | read |
|---|---|---|---|
| XAUUSD H4 baseline | 1.51 / 211t | 1.03 / 206t | — |
| XAUUSD H4 + Don(20) | **2.37 / 30t** (M1) | **0.48 / −230.53** (M1) | ⬛ **reject** — every DonBars value 20/40/60/80/100 is net-negative on BWD (PF 0.31–0.67) |
| BTCUSD H4 baseline | 1.591 / 100t | 1.35 / 91t | — |
| BTCUSD H4 + Don(20) | 1.510 / 34t | **3.510 / 40t / +451.74** | 🟩 **adopt (build-on)** — BWD PF 2.6×, net 2×, on 44% of the trades |

BTC per-trade net over both windows: **4.1 → 9.1**. DonBars 40–100 keep only 6–10 trades per window
on both symbols — discard the whole tail, it is noise wearing a PF of 5–8.

**Why the split is believable rather than luck.** Requiring a range break demands *expansion*
confirming the flip. Crypto's trends start with expansion, so the filter keeps the real ones; gold's
H4 flips more often begin inside the prior range and expand later, so the same filter cuts the
entries that would have worked and keeps the late ones — which is exactly what a BWD collapse from
1.03 to 0.48 looks like.

**Caveat carried with the BTC number:** n = 34/40 · MAIN's two 2025 half-years are **0.24 and 0.36**
(the aggregate 1.51 hides a hostile recent regime) · `swap-unadjusted` (BTC long −14.67%/yr real vs
0 in the tester, and ExitMode=0 holds for long stretches). BUILD-ON, not deploy-ready.

Source: sets `_mt5_auto/ab_sets/genstanding_stf/STF_{XAU,BTC}_H4_don*.set` · reports
`DON20_BTC_H4_*` · optimizations `DON_{XAU,BTC}_H4_{MAIN,BWD}.xml`.

## LEVER: capped pyramid into winners on a Donchian-gated SuperTrend (rev03, BTCUSD H4, 2026-07-26) 🟩 BUILD-ON — best both-window result of the campaign, with a hostile-recent-regime caveat

**The lever.** `(TRD)_SuperTrendFlip_rev03` `[07]` block, default-off. Adds a leg only while the basket
is **in profit** and only after price advances `_07_AddAtAtr`×ATR beyond the **last fill** (not the
first — one large candle cannot collapse the spacing and stack several legs at once). Every leg
trails the same SuperTrend line; a flip or a floating-loss breach closes the **whole** basket.
Not martingale — adds require profit, never a loss.

**Bounded by construction, not by hope:** legs ≤ 1+`_07_MaxAdds` (init-refused above 10) · lot per leg
flat or **decreasing** (`_07_AddLotFactor>1` refused at init) · basket floating loss ≥
`_07_BasketMaxLossPct` of balance → flat · `_07_BasketMaxLossPct` must be ≤ `_05_EmergencyDdPct` ·
leg count derived from live positions every bar (state-free: a restart mid-basket cannot desync it) ·
pyramid + `ExitMode=2` refused at init (mode 2 never trails, so adds would be unmanaged).

**Regression cage: rev01 = rev02 = rev03-with-pyramid-off, identical to the cent** on the same lane
and window (PF 0.96 / 13t / net −1.83 / gross 49.71/−51.54 / 14,498,245 ticks).

**Result — Model-4, BTCUSD H4, all three variants on the SAME terminal lane** (see the gotcha below
for why that sentence is load-bearing), MAIN chunked into 6 half-years:

| variant | MAIN | BWD |
|---|---|---|
| baseline (plateau centre) | 1.644 / 100 legs / +607.59 / DD 1.83% | 1.348 / 91 / +219.78 / DD 2.31% |
| + Donchian(20) gate | 1.510 / 34 / +218.74 / DD 2.16% | 3.510 / 40 / +451.74 / DD 1.55% |
| **+ Donchian(20) + pyramid MaxAdds=1 / AddAtAtr=1.0** | **2.379 / 50 / +700.28 / DD 2.16%** | **4.044 / 66 / +773.55 / DD 2.43%** |

Beats the baseline on **both** windows and beats the Donchian-only host on both, at essentially
unchanged drawdown. M1 predicted 2.400 / 4.363 and M4 delivered 2.379 / 4.044 — close enough that
the M1 surface can be trusted for *this* config family (contrast with the ER gate, where M1 was
optimistic on crypto BWD: 1.443 → 1.295).

**Config choice was pre-registered, and deliberately not the best number.** The 12-combo surface is
monotone — more adds → more profit → more DD (MaxAdds=3 reaches MAIN PF 3.103 / +1363 at DD 5.15%).
A monotone surface in the depth axis is the signature of **measuring leverage, not edge**, so the
confirmed config is the *least*-leveraged point that clears both windows.

**What must be said next to those numbers:**
1. **Legs are not independent samples.** ~34 MAIN and ~40 BWD *signals* produce 50 and 66 *legs*.
   Never quote n=50 as a sample size; the statistical width is still ~34.
2. **The recent regime is hostile and pyramiding does not fix it — it amplifies whatever the regime
   gives.** Per-half-year MAIN: 2.56 / 4.55 / 2.95 / 11.75 / **0.40 / 0.44** — both halves of 2025
   lose, exactly as the ungated baseline did (0.24 / 0.36). The aggregate is carried by a few large
   winners (an 11.75 on six legs; BWD has an 11.34 and a 7.18).
3. **`swap-unadjusted`, and the gap is now WORSE than for a single-leg EA.** BTC long costs ~−14.67%/yr
   in reality and 0 in the tester; holding two legs doubles that bill while `ExitMode=0` holds for
   long stretches. This is the largest unmodelled cost in the table above.
4. **Cage items still owed before this can be called a candidate:** Monte-Carlo (ruin ≤2%, PF-5th
   ≥1.0) at the real sizing, a written worst-case-single-loss figure, sensitivity fan, and
   correlation against the live cohort.

Source: `ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev03.mq5` (`[07]`) · sets
`_mt5_auto/ab_sets/genstanding_stf/STF_BTC_H4_{pyr,pyr1,don20,rev03_off}.set` · reports
`{BASE5B,DON5B,PYR1}_BTC_H4_*` · optimizations `PYR_BTC_H4_{MAIN,BWD}.xml`.

## GOTCHA: BTCUSD tick history differs between MT5 installs — crypto A/B across lanes is invalid (2026-07-26)

Same EA, same .set, same window, same broker login, **different terminal install** → same 13 entries
but different exits: `D:\Meta 5` gave PF 0.92 / net −4.26, `D:\Meta 5b` gave PF 0.96 / net −1.83.
XAUUSD matched to the cent across the same two lanes, so this is not a general lane problem — it is
per-symbol downloaded tick history, and crypto is where it bites.

**Rule:** every variant in a crypto A/B must run on ONE lane, and the lane belongs in the note beside
the numbers. This caught a real error mid-session: the first "BWD 1.35 → 3.51" claim compared a
main-terminal baseline against a 5b Donchian run. Re-running the baseline on 5b (1.348) happened to
preserve the conclusion — that was luck, not method.
