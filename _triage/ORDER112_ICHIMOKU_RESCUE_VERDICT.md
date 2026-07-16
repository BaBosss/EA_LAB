# ORDER-112 — ICHIMOKU (#66) rescue verdict (2026-07-16B, Opus)

**EA:** `(EXP)_IchiADX_Naked_rev00` — Ichimoku TK-cross + Kumo-align + ADX>min, ATR-trail, single-position flat-lot (momentum/trend-follower). Magic 990066 for this sweep.
**Prior verdict:** "DEAD 2026-06-27" (XAU H4 default periods, PF 1.13, DD 9.96, "cloud lags").
**Rescue mandate (ORDER-084 กอง ข #4):** claimed STRUCTURAL แต่หลักฐาน = default 1-2 cell = overclaim → sweep Kumo period × TF บนบ้านถูก.

## สิ่งที่พบ: rescue ทำไปครึ่งทางแล้ว (probe 2026-07-11)
Probe เก่า sweep **ADX + exit + symbol** บน **Model-2 + recent-only(2023-25)** → USDJPY = cell เดียวที่รอด (smoke 1.25 / IS 1.13 / OOS 2.66@31t) · GBPJPY/AUDJPY/GBPUSD/EURUSD ตายหมด. **3 ช่องโหว่ตรง VERDICT GATE: Model-2 ไม่ใช่ 4 · ไม่มี BWD · Kumo-period ไม่เคยแตะ.**

## ORDER-112 = เติม lever แกน (Kumo periods) × TF × both-window Model-4
บ้าน = USDJPY (momentum บน JPY-trender). Isolate: hold ExitMode2/AdxMin20/Sl2.0/Trail2.5. 16 runs → `_mt5_auto/ICHI_KUMO_BOTHWIN.csv`

| preset (T/K/S) | H1 MAIN/BWD | H4 MAIN/BWD |
|---|---|---|
| fast 6/17/34 | 0.96 / 1.19 | 1.12 / 1.43 |
| def 9/26/52 | 1.11 / 1.28 | 1.79 / 1.16 |
| **med 12/34/68** | 1.19 / 1.31 | **1.48 / 1.39** ✅≥1.2 both |
| slow 20/60/120 | **1.31 / 1.22** ✅ | 1.45 / 0.64 |

**6/8 cell both-window บวก >1.1 = plateau กว้างจริง** (ตกแค่ 2 ขอบสุด). 2 cell ผ่านบาร์ momentum ≥1.2 both-window: **med-H4** + **slow-H1**.

## Year-split holdout (กัน 2022-bull artifact) → `_mt5_auto/ICHI_YEARSPLIT.csv`
| year | medH4 PF | slowH1 PF |
|---|---|---|
| 2020 | **0.57** | 1.13 |
| 2021 | 2.46 | **0.53** |
| 2022 | 1.51 | 2.04 |
| 2023 | **0.60** | 1.80 |
| 2024 | 6.70 (10t) | 2.21 |
| 2025 | 1.96 | **0.67** |

**ทั้งคู่มี 2 ปีขาดทุน** → aggregate both-window PF โดนปีเทรนด์แรงกลบ. **ไม่ผ่าน all-years-positive** (บาร์ที่ GBPJPY leg-8 ผ่านสะอาด, PF 1.28-2.36 ทุกปี).

## VERDICT: 🟡 REVIVED (คว่ำ "DEAD") → PARKED-BUILD-ON (ยังไม่ demo)
1. **"DEAD 2026-06-27" = ผิด** — under-swept: เทสผิด symbol (XAU capped) + ไม่เคยแตะ period lever. USDJPY med/slow periods = both-window Model-4 บวก + plateau. Concept มี momentum edge จริงบน JPY-trender. **แก้ backlog: DEAD → REVIVED-PARKED.**
2. **ไม่ demo-ready** — 2 ปีขาดทุน/candidate = below GBPJPY bar. VERDICT GATE #6 (holdout) ไม่ผ่าน.
3. **BUILD-ON leads (PF>1 both-window = buildable doctrine):**
   - **🔑 diversified basket (ยืนยันเลข 2026-07-16B):** 2 config ขาดทุน**คนละปี** (medH4→2020/2023 · slowH1→2021/2025).
     **basket (สอง magic รันพร้อมกัน, arithmetic combine): 5/6 ปีบวก** (เหลือแค่ 2020 ลบ -167 เล็ก) · **full-period PF = 1.448**
     (2020 0.82 · 2021 1.45 · 2022 1.70 · 2023 1.04 · 2024 3.19 · 2025 1.32) · vs standalone 4/6 ปีบวกแต่ละตัว = diversification จริง.
     ⚠️ same-signal/same-symbol (decorrelation อาจเป็น period-luck ไม่ structural) → forward-test บน demo จะเช็คให้.

## ORDER-112B — merged-equity + MC (2026-07-16B, ทำต่อทันที)
รัน 2 config full-window continuous Model-4 (USDJPY 2020-2026) → merge deal list ตามเวลา (ไม่ต้อง build wrapper — deploy = 2 instance):
- **standalone:** med-H4 PF 1.44/127t/DD 6.83% · slow-H1 PF 1.28/230t/DD 5.26%
- **MERGED (both @0.10, chronological): PF 1.339 · 357t · net +$1,955 · TRUE max-DD 6.09%** (ต่ำกว่าผลรวม = DD time-separated จริง)
- **MC (2000 resample, N=357): PF_5th = 1.036 · DD_95th 10.77% · Ruin(DD≥30%) = 0%**

## ORDER-112C/D — multi-home extension (2026-07-16B, "หางานทำต่อ") — 🥇 XAU ฟื้นด้วย period lever!
เอา config ที่ชนะ USDJPY (med-H4 12/34/68 · slow-H1 20/60/120) ไปลอง 6 trenders อื่น × both-window Model-4 (`_mt5_auto/ICHI_MULTIHOME.csv`):
- GBPJPY/EURJPY/AUDJPY/GBPUSD = ตาย หรือ single-window (window-inverted) · CADJPY = 1.16/1.15 both แต่ใต้บาร์ 1.2 (near-miss)
- **🥇 XAUUSD = both-window ผ่าน! medH4 3.94/1.25 · slowH1 1.66/1.39** (ทั้งคู่ ≥1.2) → **คว่ำ backlog "XAU Ichimoku ceiling 1.13"**
  (นั่นวัด default-period 9/26/52 เท่านั้น — เหมือน USDJPY เป๊ะ; period lever ปลดล็อก XAU ด้วย)
- **year-split XAU** (`_mt5_auto/ICHI_XAU_YEARSPLIT.csv`): **medH4 6/6 ปี ≥0.99 (ไม่มีปีขาดทุนจริง!)** thin 8-20t/yr ·
  slowH1 5/6 ปีบวก (2021 0.84 ลบ) sample ดีกว่า 32-41t/yr. edge จริง both-window + near-all-years — **แข็งกว่า USDJPY basket.**
- **⚠️ gate ชี้ขาด = CORRELATION vs XAU portfolio เดิม** (BRK Bars8/55 · KAUFMAN_ER · SuperTrend · Wave5 XAU · MacdDiv XAU).
  XAU trend-follower มัก corr สูง (SuperTrend เคยโดน 0.724 block). ถ้า corr <0.6 = additive leg ใหม่จริง · >0.8 = redundant small-lot.
  **→ ORDER-112E (stocked): corr_monthly.py Ichimoku-XAU(slowH1) vs XAU legs → ตัดสิน additive/redundant.**

### ORDER-112E — corr verdict (2026-07-16B) = 🎯 ADDITIVE LEG (reduced-lot)
full-window XAU passes 2020-2026 Model-4 → monthly Pearson (`_mt5_auto/ichi_xau_corr.ps1`):
- Ichimoku-XAU slowH1 full: **PF 1.57 · 236t · Sharpe 3.0** (77 months, net +$7,038)
- **vs BRK_XAU 0.263 (LOW=additive) · vs KAUFMAN 0.574 (<0.6) · vs SuperTrend 0.646 (reduce-lot)**
- max corr 0.646 → **ADDITIVE leg ที่ reduced lot** (user rule: high-corr = ลด lot ไม่ตัด). ต่ำกว่า SuperTrend-0.724-block ชัด.
**VERDICT: XAU Ichimoku slowH1 = candidate จริง, additive ต่อ portfolio.** แข็งกว่า USDJPY basket (Sharpe 3.0 + additive).
(corr = live-decision gate ไม่ใช่ demo gate — user 2026-07-16B: demo เอาขึ้นเทส normal lot คอนเฟิร์มก่อน, corr sizing ตอนเงินจริง.)

### ORDER-112F — XAU 2-leg basket (2026-07-16B) = 🏆 find แข็งสุด session
เพิ่ม medH4 (12/34/68 H4) เป็น leg B (medH4 full PF 2.85/97t/Sharpe 2.76, year-split 6/6 ≥0.99). merge deal list กับ slowH1
(`_mt5_auto/xau_basket_merge_mc.ps1`):
- **COMBINED: PF 2.143 · 333t · net +$22,407 · true max-DD 10.5% · ALL 6 ปีบวก** (2 leg อ่อนคนละปี → กลบกัน)
- **MC (2000): PF_5th = 1.544 · DD_95th 22.19% · Ruin 1.2%** — robust จริง (เทียบ USDJPY basket PF_5th 1.036 บาง)
**VERDICT: XAU IchiADX basket (H1 slow 990068 + H4 med 990069) = candidate แข็งสุดของ session** — 6/6 ปี + PF_5th 1.544.
Bundle `_vps_deploy/ICHIADX_XAU/` (2 leg). caveat: DD ลึกกว่า (MC 95th 22%), ride gold-bull บาง MAIN, ruin 1.2%.

## ORDER-112B — merged-equity + MC (USDJPY basket)
**สรุป build-on: DEMO-ELIGIBLE small-lot (thin edge).** edge บวกจริง both-window + MC-survive + ruin 0% แต่ PF_5th 1.036 = บาง (แข็งๆ ~1.3-1.7)
→ demo cohort เก็บ forward data ไม่ใช่ live leg แข็ง. **Bundle #9 พร้อม attach: `_vps_deploy/ICHIADX_USDJPY_BASKET/`** (2 leg: H4 med magic 990066 + H1 slow magic 990067,
ex5 MD5 68b349fa..., README + silent-stop checklist ครบ). merge+MC script `_mt5_auto/ichi_basket_merge_mc.ps1`.
   - trend-regime filter: ปีขาดทุน = USDJPY choppy/pullback (2020 pre-breakout · 2023 pullback). ADX20→30 เคยลอง (probe p2 = 0.87 แย่ลง) → ต้องเป็น higher-TF trend-align ไม่ใช่ raise ADX เปล่า.
4. thin sample: H4 ~19t/yr, H1 ~35t/yr.

**ปิด ORDER-112 = REVIVED→PARKED-BUILD-ON.** next queue: KELTNER (#62) · หรือ ICHIMOKU basket build-on (ถ้า user สนใจต่อ).
