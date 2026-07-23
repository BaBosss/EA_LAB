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

### MG_v1 MatchaGrid — CHFJPY M15 (CORE) 🟨
**Mechanism (hypothesis):** bounded grid with hard SL on a range-bound cross.
**Why edge:** CHFJPY oscillates in a range; the grid harvests the back-and-forth, the **bounded
steps + SL cap the breakout tail** (this is why it passed deep-val where naked grids DQ).
**Failure mode:** a sustained CHFJPY trend that blows past the grid bounds (SL caps it, not ruin).
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
martingale multiplies correlated tail-risk). **LIVE guardrail (magic 1524):** `CutLoss_Percent=30` = free
tail-insurance (both-window profitable 1.19/2.20, DD bounded ~15%). Verdict: `_triage/ORDER095_NUIINDY_EXPAND_VERDICT.md`.

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
→ **ห้าม retrofit ตัว live**, ใช้กับ build ใหม่ที่ config สมดุล. verdict = `_triage/ORDER108_SPLIT_RETEST_VERDICT.md`.

## SMC × STO multi-TF reversion (user idea, 2026-07-16) 🟩 BUILD-ON candidate (optimized, ranger-home)

`(EXP)_EmaStoRev` (HTF EMA-gate + STO reversion). **default-smoke หลอก** (0.63-0.89 — STO 5,3,3 noise เยอะ).
**optimize จริงพลิกผล:** XAU (trender) = regime-fit (MAIN 2.30 / BWD ล่ม) · **EURUSD (ranger = บ้านถูก) = 2/3 top
pass ยืน both-window** (1.30/1.13 · 1.22/1.02). survivor = **StoK17** (ไม่ใช่ 5) · OS10-15 · SL3.0 · TP1 · EMA50.
= edge **เฉพาะ EURUSD H1** (ไม่ travel: AUDNZD/EURGBP/XAU ล่ม BWD). **ADX filter (user idea) ยกดีขึ้น:** best =
StoK13/OS30/AdxMax30/EMA50/SL3/TP1 = **MAIN 1.50 / BWD 1.24, 130 ไม้** (จาก no-filter 1.30/1.13). filter ต่อยอด
edge ที่มี ไม่สร้าง edge (AUDNZD กู้ไม่ได้). = **EURUSD-specific candidate** (plateau+Model-4 ก่อน demo). verdict =
`_triage/ORDER107_SMCxSTO_STAGE0_VERDICT.md`.
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
ORDER-098-A) → should raise win%. Full plan + hard-parts = `_triage/SMCxSTO_SIGNAL_TRIAGE.md`.
**Verdict: worth a cheap Stage-0 smoke (~1-2h), NOT a build campaign on hope.** Sibling of the MACD-gate S/D
concept above (both = untested reversion-at-zone).

## LEVER: HP-denoise (Hodrick-Prescott causal) @ λ1600 on trend-cross (ORDER-104C, 2026-07-16) 🟩 REUSABLE

**ไม่ใช่ EA — เป็น bolt-on lever:** กรอง noise ความถี่สูงด้วย causal HP filter *ก่อน* คำนวณ MA → ลด false cross.
EA testbed = `(TRD)_Probe_MAHP_TanhVol_rev01` (`_02_UseHPFilter`/`_02_HP_Lambda`). **ยืนยัน both-regime plateau
บน XAU H4:** fast16/slow32/λ1600 = MAIN 1.59 / BWD 1.33 · เพื่อนบ้าน MA 4 ทิศผ่าน · SL {1.5,2.0,3.0} ผ่านทั้งหมด ·
λ1600 = center (λ800 MAIN พัง, λ3200 เสื่อม). **HP ช่วยเฉพาะ XAU ไม่ช่วย EUR** (Stage A/B). chassis 2-MA เปล่า
ไม่ใช่ keeper — คุณค่า = lever ไปแปะ production trend chassis (BREAKOUT/SuperTrend) เป็น axis ใหม่ใน funnel.
verdict = `_triage/ORDER104C_HP_PLATEAU_VERDICT.md` · gate ที่ทำให้ valid = HP one-sided causal (reviewer ยืนยันไม่มี look-ahead).

## LEVER: vertical-barrier time exit `_2_MaxHoldBars` (ORDER-125, 2026-07-19) 🟨 BUILT — DEAD-ON-GRID, untested elsewhere

- **What:** basket-level force-close after N chart-TF bars from basket inception (QuantCorner Triple Barrier time leg). In chassis, default 0=off byte-identical, Codex-hardened (inception latch กัน clock-reset เมื่อ leg ปิดเอง · iBarShift −1 guard · Boss_16 no-op warn · partial-milestone leak fix).
- **A/B host Boss_14 GBPJPY H4 (locked leg8 set): DEAD ทุกค่าที่ M4** — MH130 ตาย M1 (BWD 0.73; MAIN lift 2.16 = regime-fit ห้ามไล่) · MH390 ผ่าน M1 แต่ **M4 พลิก** (BWD 1.11→0.85, net +210→−368). verdict `_triage/ORDER125_VERTBARRIER_VERDICT.md`.
- **Mechanism lesson (จ่ายแล้ว):** (1) **recovery tail ของ grid คือเครื่องยนต์** — basket 203 วันใน BWD สุดท้าย recover; time-cut = realize tail loss = ตัด edge ตัวเอง. ห้าม enable lever นี้บน grid/DCA family. (2) **M1→M4 flip บน exit lever** — M1 มองไม่เห็น path ใต้น้ำ; exit/time lever บน grid = M4-deciding เสมอ (ยืนยันซ้ำ precedent ORDER-126 SL-fan).
- **Open home (ยังไม่ทดสอบ):** single-position trend-following (SuperTrend/TrendRider) ที่ time-stop เป็น convention — ถ้าจะใช้ ต้อง A/B บน host นั้นก่อน.

## DEAD CELL: naked FVG-fill entry @ EUR/XAU H1+H4 (ORDER-098-A, 2026-07-16) ⬛

EX009 geometry (3-bar gap retrace + engulfing confirm) **ไม่มี edge ที่ exit geometry ใดๆ**: 22 runs,
RR sweep TP{15→60}@SL20, both regimes — PF peak 0.98 แล้วหักลง (cost-dilution ไม่ใช่ edge), ไม่เคย >1
ใน 26 cells. **ปิดเฉพาะ naked-entry** — FVG-as-confluence-filter ให้ entry อื่นยังไม่เคยเทส (เปิดอยู่).
verdict = `_triage/ORDER098A_FVGFILL_SMOKE_VERDICT.md`

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
Boss_18 code kept + caged (documented dead-seed, not deploy). verdict = `_triage/ORDER_LANEA_JUMSTOCH_VERDICT.md`.

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
