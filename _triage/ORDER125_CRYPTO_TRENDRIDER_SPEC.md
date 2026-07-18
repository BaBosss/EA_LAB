# ORDER-125 (DRAFT) — BTC TrendRider: SuperTrend + Pyramid + Snowball บน BTCUSD

**Date:** 2026-07-18 · **Author:** Claude (Fable seat) · **Status:** ✅ SMOKE PASSED (Model-1 both-window, 2026-07-18) — พร้อมเข้าเฟส optimize

## ผล SMOKE (Model 1 · flat default lot · ThinkMarkets BTCUSD · History Quality 100%/85%)

| EA | TF | 2023-2026 | BWD 2020-2022 | verdict ขั้นนี้ |
|---|---|---|---|---|
| EA_SUPERTREND | H4 | **PF 1.27** (79t, DD 3.1%) | **PF 2.35** (69t, DD 1.4%) | ✅ both-window pulse ที่ default — ตัวหลัก |
| EA_DONCHIAN (Turtle) | H4 | **PF 1.20** (76t, DD 6.4%) | **PF 2.07** (50t) | ✅ both-window pulse — ตัวรอง |
| EA_SUPERTREND | D1 | 2.04 (13t) | — | thin, เก็บเป็น lever TF |
| EA_DONCHIAN | D1 | 3.78 (12t) | 5.40 (9t) | thin สวยผิดปกติ — inconclusive อย่าเชื่อจน n พอ |
| EA_SUPERTREND | H1 | ~1.0 (M2 kill-direction) | — | ไม่ไปต่อ |
| EA_BREAKOUT_XAU | H4 | 0 trades | — | param scale ติด XAU — ต้อง rescale ก่อนตัดสิน ไม่ใช่ตาย |

หมายเหตุ: ทั้งสอง window มีเทรนด์ใหญ่ (2021 bull / 2022 bear / 2024 bull) — **missing regime = chop ยาวๆ**
ต้องดู per-year split ตอน optimize · DD จิ๋วเพราะ default lot จิ๋ว = under-leveraged screen (PF lot-invariant, ตามกติกา)

## ผล MULTI-SYMBOL SCAN (2026-07-18 รอบสอง — Model 1, default, flat lot)

| Symbol | ST H4 recent | ST H4 BWD | DON H4 recent | DON H4 BWD | สถานะ |
|---|---|---|---|---|---|
| BTCUSD | 1.27 (79t) | 2.35 (69t) | 1.20 (76t) | 2.07 (50t) | ✅ ทั้งคู่ both-window |
| ETHUSD | 1.41 (85t) | 1.05 (68t) | **2.16** (67t) | **1.84** (54t) | ✅ **DON เด่นสุดในสแกน** · ST = recent-fit |
| SOLUSD | 1.34 (78t) | 2.14 (25t)⚠ | 0.93 (91t) | — | ST pulse · ⚠ history เริ่มช้า (~ปลาย 2021) BWD จริงๆ = ปีหมี 2022 |
| XRPUSD / DOGEUSD | 0 trades | | | | data มีครบ (เริ่ม ธ.ค. 2021) แต่ราคา <$3 = param scale ไม่ยิง → แก้ด้วย ATR-scaled set เฟส optimize |
| LTCUSD / ADAUSD / BCHUSD | — | | | | ❌ history download error ซ้ำ 2 รอบ (server feed) — ลองเปิดกราฟใน GUI ให้ terminal ดึงเอง หรือข้าม |

**pattern ที่เห็น: mechanism×symbol matching จริง** — SuperTrend=บ้าน BTC · Donchian=บ้าน ETH · SOL เข้ากับ ST ไม่เข้ากับ DON.
⚠ portfolio note: crypto majors corr กันเองสูง (BTC-ETH มัก >0.8) — ตอน portfolio phase ใช้ gate pairwise <0.8 ของ same-EA-cross-symbol แล้วอาจต้องเลือก/ลด lot ไม่ใช่เอาหมด.

## ✅ ผล OPTIMIZE รอบ 1 + VALIDATE (2026-07-18 รอบสาม — Model 1)

**Windows:** sweep = 2023.01–2026.01 · BWD = 2020–2022 · **holdout 2026.01–2026.07 = สงวนไว้ ไม่เคยใช้เลือกอะไร**

**ST-BTC** (sweep 45 combos complete-mode, ทุก combo กำไร = plateau แท้) → lock **`ST_BTC_c1.set`** (ATR 14 · Mult 2.5 · SL 2.25×ATR, plateau-center ไม่ใช่ peak):
sweep PF 1.91 (76t) · BWD **1.55** (84t) · holdout **2.16** (15t) · MC(BWD) PF_5th 1.04 Ruin 0%

**DON-ETH** (15 combos, ทุก combo กำไร) → lock **`DON_ETH_c1.set`** (Donch 35 · SL 2.25×ATR):
sweep PF 2.06 (68t) · BWD **1.91** (58t) · holdout **1.94** (13t)

**PYRAMID A/B (DON-ETH, `_04_MaxPyramid` 0→3, `DON_ETH_c1_pyr3.set`):**
| | naked | pyramid 3 |
|---|---|---|
| IS net/DD | 461 / 1.9% | **1,109 / 5.8%** (PF 1.90, 161t) |
| BWD net/DD | 374 / 2.1% | **1,100 / 5.2%** (PF 2.13, 135t) |
| MC pyramid | — | PF_5th **1.37** · DD_95th 2.5% · Ruin 0% |

→ **pyramid บน crypto = ขยาย edge จริง** (net ×2.4–2.9, PF ยืน, ต่างจาก XAU/GBP ที่ PF พังเหลือ ~1.0) — thesis "BTC/ETH คือบ้าน trend+pyramid" ยืนยันแล้วชั้นแรก

## NEXT — ORDER-125b: STO/PA pullback add-entry (user idea 2026-07-18, design พร้อม รอ build)

**Concept:** ตอนนี้ pyramid เพิ่มไม้แบบ breakout-STOP (ไล่ราคา) — user เสนอเพิ่มไม้แบบ **pullback-in-trend**:
เทรนด์ยืนอยู่ (SuperTrend/Donchian direction) + **Stochastic ลง oversold แล้ว cross กลับตามเทรนด์** (หรือ PA: pin bar/engulfing ที่ pullback) = add ไม้ตามเทรนด์ราคาถูกกว่า
- **Vehicle:** เพิ่ม input `_04_AddMode` ใน EA_DONCHIAN (0=STOP-pyramid เดิม · 1=STO-pullback · 2=PA-pullback) — A/B ตรงๆ กับ pyramid เดิมบน set เดียวกัน
- **Prior เตือน:** StoK default noise (บทเรียน SMC×STO: K 5→17 พลิกผล) → sweep StoK {9,14,21} ก่อนตัดสิน · candle = confirm filter ไม่ใช่ naked (doctrine PA-module)
- **บาร์:** add-mode ใหม่ต้องชนะ pyramid เดิมทั้ง net-per-DD และ PF ทั้งสอง window ถึงจะแทน — ไม่งั้นเก็บ STOP-pyramid
- ⚠️ ก่อน build: รัน `mql-code-reviewer` + tpl regression ตามปกติ · commit code เอง (Claude เขียน, Codex audit)

## ✅ ผลรอบสี่ (2026-07-18) — Model-4 confirm + per-year + ORDER-125b A/B จบ

**Model-4 real ticks (History Quality 99%, ThinkMarkets tick ลึกพอทั้งคู่):**
- ST-BTC c1 (2023–2026.07): **PF 1.88 · 91t · DD 1.9% · RF 3.56** — ยืนยันจาก M1 1.91 ✅
- DON-ETH c1 pyr3 (2023–2026.07): **PF 1.99 · 186t · DD 5.8%** ✅

**Per-year split:** แพ้ 1 ปีจาก 6 = ETH 2023 (chop, PF 0.73, −59 เล็กเทียบปีเทรนด์ +346/+822) · BWD ไม่มีปีแพ้เลย
(2022 ปีหมียังบวกทั้งคู่ — ฝั่ง short ทำงาน) · **missing regime = chop ยาว, แผลจำกัดด้วย SL+ADX gate**

**ORDER-125b (EA_DONCHIAN_ADD, compile clean, บั๊ก short-side else-if จับได้ตอน self-review แก้แล้ว):**
| adds mode | IS PF/net/DD | BWD PF/net/DD |
|---|---|---|
| breakout-STOP (AddMode0) | 1.68 / 886 / 5.7% | **2.18 / 1,100 / 5.2%** |
| STO K9 | 1.81 / 854 / 5.3% | 2.11 / 952 / 5.0% |
| STO K14 | 1.71 / 726 / 4.8% | 2.10 / 903 / 5.0% |
| STO K21 | 1.40 / 383 / 3.5% | — |

**VERDICT 125b: STO-pullback adds ไม่ชนะ breakout adds เด็ดขาดสักด้าน** (K9 ชนะ net-per-DD เฉพาะ IS แพ้ BWD ·
StoK surface เป็น slope 9>14>21 ไม่ใช่ plateau = กลิ่น noise-fit) → **เก็บ breakout-STOP pyramid เป็นทางหลัก** ·
STO add-mode = PARKED (โค้ดเก็บใน `ea_projects/CRYPTO_TRENDRIDER/` เป็น lever ธนาคาร — อาจกลับมาลองบน TF อื่น/symbol อื่น)
หมายเหตุ: ADD0 ≠ v1 เป๊ะ (โค้ดใหม่แยก ADX gate ออกจาก exit path — v1 ข้าม reverse-exit ตอน ADX ต่ำ) — deploy ใช้ **v1 EA_DONCHIAN + pyr3** ที่ M4-confirmed แล้ว

## ✅ ORDER-125b รอบขยาย (user 2026-07-18): H1-STO + PA — จบ ปิดคำถาม add-trigger

EA_DONCHIAN_ADD v2: แยก `_01_SignalTF` (เทรนด์ H4) ออกจาก chart TF (จังหวะ add) + AddMode 2 = PA engulf/pin ·
compile clean · **regression check ผ่านเป๊ะ** (ADD0 หลัง refactor = 1.68/885.81 ตรงเดิมทุกหลัก)

| add trigger (ETH, trend H4) | IS PF/net/DD | BWD PF/net/DD | vs breakout adds |
|---|---|---|---|
| breakout-STOP (แชมป์เดิม) | 1.68 / 886 / 5.7% | 2.18 / 1,100 / 5.2% | — |
| STO H4 (K9 ดีสุด) | 1.81 / 854 / 5.3% | 2.11 / 952 / 5.0% | แพ้ BWD |
| **STO H1 (LTF)** | 1.46 / 696 / 7.0% | 2.32 / ~1,100 / 5.3% | ชนะ BWD แพ้ IS หนัก |
| **PA H4 (engulf/pin)** | 1.68 / 924 / 5.9% | 1.75 / 903 / 5.8% | เสมอ IS แพ้ BWD |

**VERDICT สุดท้าย 125b: ลอง 3 ตระกูล trigger (oscillator H4 · oscillator H1 · price action) — ไม่มีตัวไหนชนะ
breakout-STOP ทั้งสอง window** → คำถาม add-trigger ปิดอย่างมีหลักฐาน ไม่ใช่ปัดตกเร็ว. **finding เข้าคลัง:
บน crypto trend EA, การ add ตอน "ราคายืนยันต่อ (breakout)" ชนะการ add ตอน "ราคาย่อ (pullback)" อย่างสม่ำเสมอ**
— pullback-add เพิ่มไม้ที่ราคาดีกว่าแต่แลกกับการเก็บไม้ในจังหวะที่เทรนด์อาจกำลังจบ. deploy path = **EA_DONCHIAN v1 + pyr3** เดิม.

## ✅ 125b รอบสุดท้าย (user 2026-07-18): PA-H1 + ขยาย PA เป็น 4 pattern — จบจริง

v3: PA detector = engulfing · pin · **inside-bar breakout · morning/evening star** (compile clean)
| | IS PF/net/DD | BWD PF/net/DD | vs breakout adds |
|---|---|---|---|
| PA 4-pattern H1 | 1.45 / 780 / 6.2% | 1.82 / ~1,000 / 5.5% | แพ้ทั้งคู่ |
| PA 4-pattern H4 | **1.72 / 976 / 5.3%** | 1.81 / 978 / 6.1% | **ชนะ IS ชัด (net/DD 183 vs 155)** แต่แพ้ BWD (161 vs 211) |
| breakout-STOP | 1.68 / 886 / 5.7% | 2.18 / 1,100 / 5.2% | แชมป์ |

รวมทั้ง campaign: **6 variant** (STO-H4 ×3K · STO-H1 · PA-H1 · PA-H4 ×2รุ่น) — ไม่มีตัวไหนชนะ breakout adds
ทั้งสอง window. PA-H4 4-pattern = ตัวเดียวที่ชนะ IS → เก็บเป็น **WATCH-lever**: ถ้า forward/demo ของ breakout adds
อ่อนกว่า backtest ค่อยหยิบ PA-H4 มา revisit (มัน "เกือบ" — ไม่ใช่ตาย). **การตัดสินย้ายไปที่ demo แล้ว — หยุด
sweep add-trigger เพิ่ม (diminishing returns ชัดเจน 6/6).**

## ✅ EXIT-MODE CAMPAIGN (user ask 2026-07-18): "ควร TP แบบไหน" — คำตอบ: ห้าม TP, flip-exit ชนะขาด

v4: เพิ่ม `_02_TrailATR_mult` (ratchet trailing) + `_04_AddTP_ATR` (TP เฉพาะไม้ add, scale = ATR chart-TF) · compile clean
· รันบน **Meta 5b portable** (terminal หลักถูก session คู่ขนานใช้รัน MacdDiv GBPUSD — จับได้จาก tester log)

| exit style (DON-ETH, IS 2023–26) | PF / net / trades | vs flip-exit 1.68/886 |
|---|---|---|
| **flip-exit + SL 2.25ATR (ปัจจุบัน)** | **1.68 / 886** | แชมป์ |
| fixed TP 4×ATR ทุกไม้ | 1.07 / 178 (313t) | 💀 ตัดหางกำไร = ฆ่า edge |
| fixed TP 8×ATR ทุกไม้ | 1.12 / 261 | 💀 |
| trailing 2×ATR | 1.29 / 377 | แย่ลงชัด (ออกก่อน flip ทุกเทรนด์ใหญ่) |
| STO-H1 adds + scalp TP 1.5×ATR(H1) | 1.15 / 317 (630t) | winrate 68% แต่ expectancy จิ๋ว — churn กิน |
| PA-H1 adds + scalp TP 1.5×ATR(H1) | **0.96 / −173 (1,305t)** | 💀 ขาดทุนจริง — scalp adds จ่าย cost มากกว่า edge |
| trailing 3×ATR | ยังไม่ได้รัน (Meta5b launch fail ซ้ำ 3 รอบ — infra ไม่ใช่ verdict-blocking: trail หลวมกว่า = converge เข้า flip-exit) |

**หลักฐานเชิงตัวเลขของ doctrine "trend EA winrate ต่ำ-หางยาว":** ทุกรูปแบบ TP ยก winrate ขึ้น (38-68%)
แต่ PF/net พังหมด เพราะกำไรทั้งระบบอยู่ที่ไม้หางยาวไม่กี่ไม้ (avg win 58.5 vs avg loss 10.2 = 5.7:1) —
**ตัด tail = ตัด edge. Exit ownership ล็อกเป็น flip-exit + hard SL — คำถาม exit ปิด.**
(จุดอ่อน chop-year แก้ด้วย TP ไม่ได้โดยไม่ฆ่าปีเทรนด์ — ทางแก้ที่เหลือคือ regime-gate ซึ่งเป็นงาน future ไม่ block demo)

## ✅ LAST-OPTIMIZE audit (user push 2026-07-18 "confirm optimize ก่อน park ครบไหม") — สำคัญ

**สารภาพ:** รอบก่อนๆ park STO/PA จาก A/B จุดเดียว (swept แค่ StoK, ถือ StoLevel+MinAddGap ที่ default ตลอด) =
**ยังไม่ครบตาม LAST-OPTIMIZE rule.** รอบนี้ optimize lever ที่ยังไม่แตะบนตัวที่มีชีพจรสุด:

| variant (ETH H4) | IS PF/net | BWD PF/net | vs champion (brk 1.68/2.18) |
|---|---|---|---|
| **breakout-STOP (champion)** | 1.68 / 886 | **2.18 / 1,100** | — |
| STO K9 **lv20** (lever ใหม่) | **1.94 / 924** ⬆ชนะ IS | 1.68 / 602 | แพ้ BWD ชัด (602 vs 1,100) |
| STO K9 lv25 | 1.87 / 904 | — | |
| PA **gap0.8** (lever ใหม่) | 1.79 / 991 ⬆ชนะ IS | 1.96 / ~1,000 | แพ้ BWD เฉียด (1.96 vs 2.18) |

**ผลหลัง optimize จริง:** ทั้ง STO(lv20) และ PA(gap0.8) **ดีขึ้นจริงจาก lever ใหม่ — ชนะ champion บน IS ทั้งคู่** แต่
**ยังแพ้ champion บน BWD (out-of-sample) ทั้งคู่** → champion ชนะเพราะ**robust กว่าบนหน้าต่างที่ไม่เคยเห็น** ไม่ใช่เพราะคู่แข่งถูกเทสน้อย. verdict เดิม (breakout-STOP = deploy) **ยืนหลัง fair fight แล้ว**
- **PA gap0.8 = ยกจาก WATCH → STRONG-ALT** (BWD 1.96 เฉียด 2.18, IS ชนะ) — candidate co-deploy leg ที่ 2 ของ ETH ถ้าอยากได้ diversification ภายใน ETH (แต่ corr กับ champion สูงเพราะ base เดียวกัน — เลือกอันเดียว)
- **Exit-mode TP/trail = ยกเว้น last-optimize โดยชอบ** (STRUCTURAL: ตัด tail = ตัด edge, กลไกพิสูจน์แล้วด้วยตัวเลข winrate↑/PF↓ ทุกค่า — ไม่ใช่ under-test)
- ST-BTC champion (SuperTrend) = optimize แล้ว 45-combo + M4 · DON-ETH champion = 15-combo + pyramid A/B + M4

## ✅ SNOWBALL + CORRELATION (ปิด 2 ใน 3 ขั้นสุดท้าย, 2026-07-18)

เพิ่ม `_05_RiskPct` (risk%/equity ต่อ SL — snowball แท้) ทั้ง 2 EA · regression ผ่าน (fixed = 1.91 ตรงเดิม):
| | fixed 0.01 | snowball (deploy risk%) | equity DD |
|---|---|---|---|
| ST-BTC (RiskPct 1.0%) | net 731 / DD 1.9% | **net 5,935 / PF 2.22 / RF 6.68** | **5.6%** ✅ |
| DON-ETH pyr3 (RiskPct 1.0%) | net 1,378 / DD 5.8% | net ~33k | 35.5% ❌ เกิน cap |
| DON-ETH pyr3 (RiskPct 0.5%) | | net 11,733 | 20.5% ❌ เฉียด |
| **DON-ETH pyr3 (RiskPct 0.35%)** | | **net 7,576 / PF 2.52** | **14.3%** ✅ lock |

cap-breach → resize (ไม่ reject) ตามกติกา · **snowball ให้ผลมหาศาลจาก compounding ในปีเทรนด์ แต่ตัดสินที่ DD band ไม่ใช่ net**

**CORRELATION BTC-leg vs ETH-leg = 0.030** (30 เดือน monthly-return) = **แทบไม่สัมพันธ์เลย → additive เต็มที่**
(ต่ำกว่า cross-EA gate 0.4 มาก) — คนละสัญญาณ+คนละ symbol → กำไรมาคนละจังหวะ. **ทั้ง 2 leg เข้าพอร์ตได้เต็มไซส์**
= crypto lane เพิ่ม diversification จริงให้พอร์ต (เดิมไม่มี crypto exposure เลย)

## ✅ DEMO BUNDLE พร้อม attach — `_vps_deploy/CRYPTO_TRENDRIDER/`
- `EA_SUPERTREND.ex5` + `ST_BTC_deploy.set` (BTCUSD H4, RiskPct 1.0%, Magic 990020)
- `EA_DONCHIAN.ex5` + `DON_ETH_deploy.set` (ETHUSD H4, pyr3, RiskPct 0.35%, Magic 990030)
- account: HEDGING, crypto-enabled (ThinkMarkets/Exness) · leverage สูงพอ (margin level >2000% ที่เทส) · **24/7 → ต้อง VPS**
- ⚠️ ก่อน live จริง: RCA swap (trend-ride ถือยาว) + mql-code-reviewer pass + Codex blind audit (มี risk logic ใหม่ = RiskLot sizing)

## 🔴 SWAP RCA (2026-07-18 — ตัวที่ backtest ประเมินไม่ครบ, ยืนยันแล้ว)

**หลักฐาน:** สรุป swap column ของ M4 report ทั้งสองตัว = **0.00 บาท** (BTC 182 deals · ETH 372 deals) →
tester ThinkMarkets ตั้ง historical swap = 0. **แต่ symbol จริงตอนนี้ (dump ผ่าน SYMBOL_SWAP_LONG/SHORT, mode=5=INTEREST_CURRENT = % ต่อปี):**
| symbol | swap LONG | swap SHORT |
|---|---|---|
| BTCUSD | **−14.67%/ปี** | −0.49%/ปี |
| ETHUSD | **−9.86%/ปี** | −3.95%/ปี |

**ผลกระทบ (ประเมิน analytic):** EA เป็น trend-follower → ถือ **long เป็นหลักในปีเทรนด์** (บ้านที่ทำเงิน) = โดน swap แพงสุดพอดีตอนเทรดหนักสุด.
notional ≈ 0.29× equity (จาก risk 1% ÷ SL ~3.4% ของราคา) · ถ้าถือ long ~50% ของเวลา → drag ≈ 14.67% × 0.29 × 0.5 ≈ **~2.1%/ปี ของ equity** (BTC) · ~1.4%/ปี (ETH).
รวม 3.5 ปี ≈ **7–10% drag** — **ลดกำไรแต่ไม่ฆ่า** (backtest net +76% ETH / +59× BTC-compound เหลือ margin เยอะ) แต่ **demo จะเดินเบากว่า backtest เสมอ**.

**Action ก่อน live:** (1) demo วัด swap จริง 1 เดือนแล้วเทียบ analytic (2) พิจารณา bias long-hold ให้สั้นลงถ้า drag เกินคาด (3) short legs เกือบฟรี = ไม่ต้องกังวล.
**ห้าม promote live จนกว่า demo ยืนยัน swap-adjusted PF ยัง >1.3.**

## 🔍 CODE REVIEW — RiskLot snowball sizing (risk logic ใหม่ = ต้อง review)
ตรวจแล้ว (manual, checklist mql-code-reviewer): division-by-zero guarded ครบ (RiskPct/slDist/tickVal/tickSize/lossPerLot ทุกตัวมี early-return) · NormalizeLot floor→min-lot ok · digit-aware ผ่าน tickValue/tickSize (ไม่ hardcode pip).
**⚠️ 1 ข้อสังเกต (by-design ไม่ใช่บั๊ก):** `ACCOUNT_EQUITY` รวม floating P&L → ไม้ pyramid ไม้หลังๆ size จาก equity ที่มีกำไรลอยของไม้แรก = compound เร็วขึ้นตอนกำไร (นี่คือ snowball ที่ต้องการ แต่ขยาย DD — เป็นเหตุผลที่ DON-ETH ต้องลดเหลือ 0.35%). **ยังต้อง Codex blind audit ก่อน live** (iron rule: risk logic ใหม่ไม่มี cage).

## ค้างในคิว validate ก่อน demo
1. per-year split (กัน PF รวมซ่อนปีขาดทุน) — ยังไม่ได้ทำ
2. **Model-4 real-tick confirm** ทั้ง 2 set (เช็ค tick depth ThinkMarkets BTC/ETH — ถ้าตื้นต้องแจ้งตรงๆ)
3. snowball A/B (FIRSTLOT_RISK) ตัดสินด้วย MC ruin
4. corr BTC-leg vs ETH-leg (คาดสูง — อาจต้องลด lot ฝั่งนึง) + corr vs live portfolio
5. demo bundle
**Origin:** user ขอ EA crypto run-trend + snowball + pyramid (มองว่า bull run ใกล้มา)

## หลักคิด (สำคัญ — อ่านก่อน dispatch)

- **EA นี้ห้าม design โดย "เชื่อว่า bull run มาแน่"** — trend-following ที่ดี = เข้าเมื่อเทรนด์ยืนยันแล้ว,
  ถ้าเทรนด์ไม่มา = แพ้เล็กจำกัด (SL ทุกไม้), ถ้ามา = pyramid+snowball ขยายกำไร. คำทำนายตลาดไม่ใช่ input ของ spec.
- **Route = MT5 broker CFD (ThinkMarkets/Exness BTCUSD) — ไม่ใช่ exchange API lane.**
  ORDER-081 (`CRYPTO_LANE_FEASIBILITY.md`) ประเมิน lane ตรง exchange = 92-168 ชม. engineering ก่อนตัดสินใจเงิน → PARK ไว้เหมือนเดิม.
  MT5 CFD route ใช้ pipeline เดิมได้ 100% (Model-2/4, both-window, MC, demo bundle).
- **ชิ้นส่วนทั้ง 3 มีอยู่แล้ว ไม่ต้อง build ใหม่:**
  1. **Entry:** `EA_SUPERTREND` / `EA_SUPERTREND_MTF` (D:\EA_Project\CURRENT_BUILD\TEMPLATE\) —
     FULLY VALIDATED บน XAU H4 (IS 1.54 / OOS 4.49 / MC pass; Mode2 pyramid PF 1.72, MC PF_5th 1.35, Ruin 0%).
     โดนบล็อกจาก portfolio เพราะ **corr 0.724 กับ XAU breakout เท่านั้น** — ไม่ใช่คุณภาพ. BTC = home ใหม่ที่แก้ block นี้พอดี.
  2. **Pyramid:** chassis Boss V2 `STACK_PYRAMID(93)` pending-STOP ladder (MERGE-03, regression CLEAN).
  3. **Snowball:** chassis `FIRSTLOT_RISK(42)` = lot จาก Risk%/SL-distance → โตตาม equity อัตโนมัติ = compounding.

## ⚠️ Prior ที่ต้องเคารพ (จากคลังเรา)

| หลักฐาน | ผล | บทเรียนที่บังคับใช้ |
|---|---|---|
| #20 Trend+Pyramid XAU/GBP H4 (2026-07-02) | DEAD — naked 0.87-1.02, pyramid 0.99-1.00 | **pyramid ขยาย edge ที่มีอยู่ ไม่สร้าง edge** → ต้องผ่าน flat-lot naked ก่อนเปิด pyramid |
| #94 Turtle+pyramid | DEAD (0 additive legs) | เหมือนกัน |
| EA_SUPERTREND multi-symbol smoke | ตายเกือบทุก FX (GBPJPY 0.55, EUR 0.67) ผ่านเฉพาะ XAU/XAG/US30 | SuperTrend เป็น **trender-home-specific** — BTC เป็น trender แรงสุดในบรรดา instrument = ตรง home ที่สุด แต่ต้องพิสูจน์ ไม่ใช่สมมติ |
| BTCUSD CFD swap | ยังไม่มีข้อมูลในเครื่อง | trend-ride ถือไม้เป็นสัปดาห์ → **swap คือ killer อันดับ 1** ต้องเทส Model-4 spec จริง + จด swap rate ตอนโหลด data |

## Spec Card (chassis-abbreviated ตาม CHASSIS-FIRST rule)

```yaml
spec_card_version: "3.0"
chain_id: "EA_BTCTREND_20260718_001"
chassis: "standalone-first-then-BossV2"   # phase 1-2 ใช้ EA_SUPERTREND_MTF ที่มีอยู่ (เร็วสุด, validate แล้ว)
                                          # ถ้าเป็น candidate จริง → port entry เข้า Boss V2 (ได้ cage/Persist ฟรี)
identity:
  ea_name: "BTC_TRENDRIDER (SuperTrend DNA)"
  symbol: "BTCUSD (ETHUSD = expansion เฟสหลัง)"
  timeframe: "H4 หลัก · D1/H1 = lever sweep"
strategy:
  entry: "SuperTrend flip ตามเทรนด์ (ATR period × multiplier = lever แรกที่ sweep — บทเรียน StoK: default อาจ noise)"
  pyramid: "STACK_PYRAMID(93) STOP-ladder ≤4 legs, spacing = ATR-based (ห้าม fixed pips — BTC vol ใหญ่)"
  lot_sizing: "Phase A = FLAT LOT (บังคับ) → Phase C = FIRSTLOT_RISK 0.5-1.0%/trade (snowball)"
  stop_loss: "ATR-based ทุกไม้ รวมไม้ pyramid · exit ownership = SuperTrend flip + trailing (basket-close > per-leg-TP ตาม lever ที่เก็บจาก Boss_18)"
risk:
  risk_level: "L2 (multi-position ทิศเดียว + SL ทุกไม้ = anti-martingale ไม่ใช่ recovery)"
  risk_per_trade_pct: 1.0
  max_positions: 4          # Turtle-style cap
  max_total_lot: "จาก margin calc ตอนรู้ contract spec จริง"
  emergency_exit_dd_pct: 70.0
  daily_loss_limit_pct: 5.0
  หมายเหตุ: "weekend: broker crypto ส่วนใหญ่เทรด 24/7 แต่ต้อง verify — ถ้า broker ปิดเสาร์อาทิตย์ = gap ข้าม SL ได้ ต้องลด cap"
```

## Test ladder (ตาม VERDICT GATE — ห้ามข้ามขั้น)

1. **DATA (ทำก่อน ไม่มีทางไปต่อถ้าไม่ผ่าน):** เปิด MT5 ThinkMarkets → ดู Market Watch ว่ามี BTCUSD ไหม → โหลด history H1/H4/D1
   → verify ความลึก (ต้องได้ ≥2023-01 ตาม 3-year rule; ได้ 2021-22 bear ด้วย = ดีมาก ใช้เป็น BWD window)
   → จด spec: contract size · spread ปกติ · **swap long/short** · margin % · เทรดเสาร์อาทิตย์ไหม.
   ถ้า ThinkMarkets ไม่มี → Exness demo (146237) มี BTCUSD.
2. **SMOKE (Model-2, flat-lot, naked ไม่มี pyramid):** EA_SUPERTREND บน BTCUSD H4/D1/H1 × both-window.
   จากนั้น optimize entry params (ATR period/mult) ก่อนตัดสิน — default-smoke ตาย ≠ concept ตาย (กติกา anti-rationalization).
   บาร์: PF≥1.2 หลัง optimize (momentum prior) + surface ไม่ใช่ spike.
3. **A/B PYRAMID:** config ผ่านขั้น 2 → เปิด Mode2/STACK_PYRAMID เทียบ naked. pyramid ต้องชนะทั้ง PF และไม่พอง DD เกิน.
   ถ้า pyramid ไม่ช่วย (ซ้ำรอย #20) → เก็บ naked ไว้ ไม่ฝืน.
4. **SNOWBALL:** เปิด FIRSTLOT_RISK เทียบ flat — ตัดสินด้วย **MC ruin + DD_95th** ไม่ใช่ net profit
   (compounding ทำ net สวยเสมอ แต่เพิ่ม ruin — ต้องดูหาง distribution).
5. **VALIDATE เต็ม:** Model-4 spec จริง (รวม swap!) · ≥3 levers swept · plateau-center · holdout ที่ไม่เคย select · MC.
6. **PORTFOLIO:** corr vs ทุก live leg (บาร์ ≤0.4 additive — คาดว่าผ่านเพราะไม่มี crypto exposure เลย) → demo bundle 3 เดือนตามระบบ.

**Effort ขั้น 1-2 ≈ ครึ่งวัน (batch ผ่าน qwen lane ตาม pacing rule 1-2 order/รอบ) — ตายก็ตายถูก.**

## ห้าม (สำหรับ agent ที่รับ order)

- ห้ามเปิด pyramid/snowball ก่อน naked flat-lot ผ่าน both-window (ลำดับ 2→3→4 ตายตัว)
- ห้ามใช้ fixed-pip spacing/SL บน BTC — ATR เท่านั้น
- ห้าม verdict จาก window เดียว / ห้ามข้าม swap ใน Model-4
- ห้ามแตะบัญชีจริง — จบที่ demo bundle เหมือนทุกตัว

NEXT STEP:
Forward this Spec Card to the mql-code-generator skill.
(เฉพาะเมื่อถึงเฟส port เข้า Boss V2 — phase 1-2 ใช้ EA_SUPERTREND_MTF ที่คอมไพล์แล้ว ไม่ต้อง gen code)
