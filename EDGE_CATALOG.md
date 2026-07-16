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

### NuiIndy RSI+ADX — EURUSD H1 (CORE) 🟨
**Mechanism (hypothesis):** RSI signal gated by ADX (trend-strength filter).
**Why edge:** ADX gate keeps RSI entries out of dead chop / aligns them with a real move — a
*filtered* reversion or pullback-continuation on the most liquid pair.
**Verify:** read the actual entry rule before extending — direction (fade vs follow) unconfirmed.

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
| TrendRegression (reversion) | XAU | reversion-on-a-trender = no edge (confirms momentum>reversion for gold) |
| SessionBreakout | XAU | 1,200-pass ceiling 1.20, forward 0.91 — breakout needs a real range to break |
| Grid/martingale (Golden Elephant, BuRengNong, Setka…) | XAU mostly | "martingale WAS the edge" — strip the doubling, signal is breakeven; DD 60–125% |
| Tight-TP (Game Changer/GMGS) | XAU | Model-2 open-price artifact; TP×10 collapses PF |

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

## LEVER: HP-denoise (Hodrick-Prescott causal) @ λ1600 on trend-cross (ORDER-104C, 2026-07-16) 🟩 REUSABLE

**ไม่ใช่ EA — เป็น bolt-on lever:** กรอง noise ความถี่สูงด้วย causal HP filter *ก่อน* คำนวณ MA → ลด false cross.
EA testbed = `(TRD)_Probe_MAHP_TanhVol_rev01` (`_02_UseHPFilter`/`_02_HP_Lambda`). **ยืนยัน both-regime plateau
บน XAU H4:** fast16/slow32/λ1600 = MAIN 1.59 / BWD 1.33 · เพื่อนบ้าน MA 4 ทิศผ่าน · SL {1.5,2.0,3.0} ผ่านทั้งหมด ·
λ1600 = center (λ800 MAIN พัง, λ3200 เสื่อม). **HP ช่วยเฉพาะ XAU ไม่ช่วย EUR** (Stage A/B). chassis 2-MA เปล่า
ไม่ใช่ keeper — คุณค่า = lever ไปแปะ production trend chassis (BREAKOUT/SuperTrend) เป็น axis ใหม่ใน funnel.
verdict = `_triage/ORDER104C_HP_PLATEAU_VERDICT.md` · gate ที่ทำให้ valid = HP one-sided causal (reviewer ยืนยันไม่มี look-ahead).

## DEAD CELL: naked FVG-fill entry @ EUR/XAU H1+H4 (ORDER-098-A, 2026-07-16) ⬛

EX009 geometry (3-bar gap retrace + engulfing confirm) **ไม่มี edge ที่ exit geometry ใดๆ**: 22 runs,
RR sweep TP{15→60}@SL20, both regimes — PF peak 0.98 แล้วหักลง (cost-dilution ไม่ใช่ edge), ไม่เคย >1
ใน 26 cells. **ปิดเฉพาะ naked-entry** — FVG-as-confluence-filter ให้ entry อื่นยังไม่เคยเทส (เปิดอยู่).
verdict = `_triage/ORDER098A_FVGFILL_SMOKE_VERDICT.md`
