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
   - **🔑 diversified basket:** 2 config ขาดทุน**คนละปี** (medH4→2020/2023 · slowH1→2021/2025). รวม net รายปี = มีแค่ 2020 ที่ยังลบ (-167), 5/6 ปีบวก. med-H4 + slow-H1 basket = สมูทกว่ามาก → order ถัดไปคุ้มลอง.
   - trend-regime filter: ปีขาดทุน = USDJPY choppy/pullback (2020 pre-breakout · 2023 pullback). ADX20→30 เคยลอง (probe p2 = 0.87 แย่ลง) → ต้องเป็น higher-TF trend-align ไม่ใช่ raise ADX เปล่า.
4. thin sample: H4 ~19t/yr, H1 ~35t/yr.

**ปิด ORDER-112 = REVIVED→PARKED-BUILD-ON.** next queue: KELTNER (#62) · หรือ ICHIMOKU basket build-on (ถ้า user สนใจต่อ).
