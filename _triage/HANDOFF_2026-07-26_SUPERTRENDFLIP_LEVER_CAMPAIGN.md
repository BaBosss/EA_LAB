# HANDOFF 2026-07-26 — SuperTrendFlip lever campaign (ORDER-GEN-STANDING ชุด 2)

**seat:** Claude Code / Opus · **สั่งงานโดย user:** merge PR #5 → เดิน matrix → "ทำทั้งคู่" → "ทำทั้งหมดเลย" → "แก้ swap ก่อนแล้วค่อยยิง holdout"
**commits ของ session นี้:** `d0dcd3da` `09f8b173` `ca922653` `09a6fb7b` `47319bef` `ea09e969` `6df2d6b5` `6fb05454` `3a1144ae` `39e6bfe9`
**เลนที่ใช้:** `D:\Meta 5b` (portable) เกือบทั้งหมด — terminal หลักถูก session คู่ขนานใช้ (ORDER-222)

---

## 1. ผลลัพธ์ที่ต้องรู้ก่อนทำอะไรต่อ

### 🟢 VALIDATED CANDIDATE (ตัวเดียวของ campaign) — รอ user เคาะ demo attach

**BTCUSD H4 · `(TRD)_SuperTrendFlip_rev03` · Donchian(20) + pyramid MaxAdds=1/AddAtAtr=1.0**
`.set` = `_mt5_auto/ab_sets/genstanding_stf/STF_BTC_H4_pyr1.set` (`AllowLive=false`)

| | PF (หัก swap แล้ว) | ไม้ | net | eqDD |
|---|---|---|---|---|
| MAIN 2023.01–2025.12 | 2.257 | 50 | +648.49 | 2.16% |
| BWD 2020.01–2022.12 | 3.949 | 66 | +757.43 | 2.43% |
| **HOLDOUT 2026H1 (ไหม้แล้ว)** | **4.274** | 9 | +248.74 | 2.52% |

กรงครบ: MC ruin **0%** · PF-5th **1.052** · fan **69/81** ผ่าน both-window (BWD ต่ำสุด 1.71) · worst leg −$69.50 = **0.70%** ของทุน · corr **+0.167** vs BRK_XAU เงินจริง
**ห้ามลืมพูดคู่กับเลขนี้:** legs ≠ sample (34 สัญญาณ → 50 ไม้) · holdout n=9 ยืนยันขนาด edge ไม่ได้ · **2025 ทั้งสองครึ่งปีขาดทุน (0.40/0.44)** เหมือน baseline (0.24/0.36) = overlay ขยาย regime ไม่ได้แก้ · residual: gap สุดสัปดาห์ทะลุ trail ทั้งสองไม้ (tester ไม่จำลอง)
**2026H1 ไหม้แล้วสำหรับ EA ตัวนี้** → forward record จากวัน attach = holdout ตัวใหม่ (precedent Boss_16)

### 🟩 lever ที่ผ่านและใช้ต่อได้
- **Kaufman ER gate** (`rev02` `[03b]`, default-off) — XAU H4: MAIN 1.51→**1.62** (DD 2.96→2.11) · BWD 1.03→**1.09** ที่ `ErPeriod=8/ErMin=0.20`
- **Donchian confluence** — ได้เฉพาะ BTC (BWD 1.348→3.510) · **ฆ่า XAU** (BWD 1.03→0.48 ติดลบทุกค่า)
- **capped pyramid** (`rev03` `[07]`, default-off) — ดูตารางข้างบน

### 🟨 BUILD-ON / ⬛ ตกรอบ
| cell/lever | ผล |
|---|---|
| **ETHUSD H4** | `BUILD-ON` — center เอง 1.310/1.099 แต่ **MC PF-5th 0.857/0.657 ตก** · portable stack ของ BTC ตก BWD 0.858 · overlay ฆ่า MAIN (1.010) |
| BTCUSD H1 | 1.229/1.039 เฉียดทั้งสองฝั่ง · ER ทำ BWD แย่ลง |
| XAUUSD H4 | 1.51/1.03 (ER ยกเป็น 1.62/1.09) — BWD ยังบาง |
| US30 H4 | plateau แข็งอันดับสอง (survivors 22%) แต่ **BWD 1.01 net +2.91/3 ปี** |
| WTI H4 | **no-pulse** — coarse survivors **0/778** |
| XAGUSD H4 | บาง 0.6% — ยังไม่ยืนยัน M4 |
| ER บน BTC H4/H1 | ตกเกณฑ์ "ดีขึ้นทั้งสองหน้าต่าง" |

---

## 2. ข้อสรุประดับกลยุทธ์ (สำคัญกว่าเลขของ cell ไหน)

1. **SuperTrend flip = edge ของระบอบ 2023-2025** — ทุก cell กิน MAIN เสมอตัว BWD **ยกเว้น BTC H4**
2. **BTC H4 เป็นเคสพิเศษ ไม่ใช่หัวขบวนกอง crypto** — เป็น cell เดียวใน 3 crypto ที่สัญญาณดิบเดินได้เอง (ชอบ `UseEma=false`) ขณะ BTC H1 / ETH H4 ปิด EMA แล้ว neighbours=0 ทั้งคู่ · และเป็น cell เดียวที่ BWD แข็ง — สองข้อนี้น่าจะเป็นเรื่องเดียวกัน
3. สมมติฐาน user แคบลงจาก "non-FX เหมาะ" เป็น **"crypto เหมาะ"** (น้ำมันไม่มีชีพจร · เงินบาง · ดัชนีเหมือนทอง)
4. **แผน "ผูก 20 symbol" = 20 funnel แยกกัน** ไม่ใช่การผูกเพิ่ม (2 symbol วันนี้ = ครึ่งวัน ผ่าน 1)

---

## 3. 🔴 gotcha ที่จะกัด session ถัดไปถ้าไม่รู้

1. **BTCUSD tick data ต่างกันระหว่าง MT5 install** — EA/set/window/บัญชีเดียวกัน: `Meta 5` = PF 0.92/−4.26 · `Meta 5b` = 0.96/−1.83 (13 ไม้เท่ากัน) ขณะ **XAU ตรงกันเป๊ะ** ⇒ **A/B ของ crypto ต้องรันเลนเดียวกัน + เขียนกำกับว่าเลนไหน** (memory `btc-tick-data-differs-per-mt5-install`)
2. **swap: tester คิดโหมด POINTS แต่ไม่คิดโหมด INTEREST_CURRENT** — วัดด้วย probe: XAUUSD (POINTS) ถูกคิดจริง −29.25 ⇒ **backtest XAU ทั้งคลังหัก financing แล้ว** · BTCUSD/ETHUSD (INTEREST) **ไม่ถูกคิดเลย** ⇒ crypto ต้องหัก post-hoc = `notional × rate/100/360 × วันถือ` · probe อยู่ที่ `ea_projects/(TST)_SymbolSwapProbe/` (2 ตัว: อ่านสเปก + วัดว่าคิดจริงไหม) · สคริปต์หัก = **`scripts/swap_adjust_crypto.py`** (ย้ายเข้า repo แล้ว + verify ว่าให้เลขเดิมเป๊ะ · วิธีใช้ใน `docs/MT5_AUTOMATION.md`)
3. **`ETHUSD min_lot = 0.1` ไม่ใช่ 0.01** — `.set` ที่ใช้ 0.01 ทำให้ guard ใน EA ปฏิเสธทุกออเดอร์ → **รายงาน 0 ไม้ที่หน้าตาเหมือน "ไม่มีสัญญาณ"** ⇒ probe สเปก symbol ใหม่ก่อนเชื่อผลใดๆ และแก้ lot ใน `.set` ของ optimize ด้วย
4. **`select_robust_pass.py` รายงาน fan ของ EA แบบ basket/pyramid ผิด** — บอก `survivors=0 plateau=NONE` ขณะแถวดิบกำไรเกือบทั้งกระดาน (PF 1.59-2.79 ที่ 68-81 ไม้) ⇒ **อ่าน XML ดิบเสมอสำหรับ EA หลายไม้**
5. **crypto Model-4 หน้าต่าง 3 ปีชน memory ceiling** — terminal คืน `"no disk space in ticks generating function"` (อยู่ใน journal ของ terminal ไม่ใช่ tester log) แล้วออกรายงาน `bars=0 / PF 0.0` = **artifact ห้ามกรอกลงตาราง** ⇒ ซอยเป็นครึ่งปี 6 ช่วง (cross-check: M1 เต็มหน้าต่างให้จำนวนไม้เท่ากันเป๊ะ)
6. **matrix template ที่ merge มาจาก PR #5 กิน holdout** (`ToDate 2026.07.01`) — แก้เป็น `2025.12.31` แล้วใน `09f8b173` ถ้าเห็นใครแก้กลับ = ผิด

---

## 4. คิวถัดไป (เรียงตามที่หลักฐานหนุน)

1. **user เคาะ: attach demo ของ BTC H4 PYR1 หรือรอ regime 2025 พลิก** — ถ้า attach ต้อง pre-register เกณฑ์ judge ลง `DEPLOYMENTS.csv` (default PF ≥1.40 ที่ ≥30 ไม้ ซึ่งด้วยอัตรา ~11 สัญญาณ/ปีจะใช้เวลา ~1 ปีกว่าจะครบ — ต้องยอมรับล่วงหน้า)
2. **pullback / S-R / STO re-entry บน BTC H4** (= `rev04` lever, default-off + regression cage) — user เสนอเอง, ผมเห็นด้วยว่าเป็นทางที่คุ้มกว่าขยาย symbol เพราะเพิ่มไม้ใน**เทรนด์ที่รู้แล้วว่ามี edge** · **บาร์ที่ต้องใช้: ดีขึ้นทั้งสองหน้าต่าง AND MC PF-5th ไม่ลดลง** (เพิ่มเงื่อนไข MC เพราะ ETH สอนว่า PF หัวตารางมองความบางไม่เห็น)
3. ~~ย้าย swap script เข้า `scripts/`~~ ✅ ทำแล้ว = `scripts/swap_adjust_crypto.py` + `docs/MT5_AUTOMATION.md`
4. cell ที่เหลือของ matrix ชุด 2 (#20 BRENT · #21 NAS100 · #22 DE40 · #23 XAU H1 · #24 US30 H1) — **คาดว่าจะออกแบบ US30** (MAIN ผ่าน BWD เสมอตัว) ทำเมื่อว่างจริง ไม่ใช่คิวหลัก
5. เพดาน 5 symbol + equity kill ระดับพอร์ต = เลเยอร์แยก **ไม่ยัดเข้า EA** และ **ไม่มี "ออกพร้อมกัน"** (การปิดพร้อมกันทำลายการกระจายความเสี่ยงที่หลาย symbol ให้มา — รอยเท้าเดียวกับ ORDER-222)

---

## 5. ไฟล์ที่แตะ

- **EA:** `ea_projects/(TRD)_SuperTrendFlip/(TRD)_SuperTrendFlip_rev02.mq5` (ER gate) · `_rev03.mq5` (pyramid) — rev01 **ไม่ถูกแตะ** หลักฐานเก่ายังใช้ได้ · `ea_projects/(TST)_SymbolSwapProbe/` (2 probe)
- **sets:** `_mt5_auto/ab_sets/genstanding_stf/` (20 ไฟล์ ทุกไฟล์มี header อธิบายที่มา + แกนตายที่ล็อก)
- **docs:** `AGENT_TASKBOARD.md` (ORDER-GEN-STANDING ชุด 1/2 + ผลดิบ + LEVER A/B) · `EDGE_CATALOG.md` (5 entry ใหม่) · `EA_SCORECARD_AND_REGISTRY.md` (1 row) · `EA_MASTER_INDEX.csv` (1 row) · `docs/memory_control/B1_DATASET.csv` (1 row)
- **memory ใหม่ 3 ใบ:** `supertrend-is-a-2023-2025-regime-edge` · `btc-tick-data-differs-per-mt5-install` · `tester-charges-points-swap-not-interest-swap`

---

<!-- HANDOFF-ROUTING -->
_Routing added 2026-08-06 (merge into EA_LAB_MAP branch surfaced this pre-guard handoff; destinations verified against the boards/DEPLOYMENTS.csv as of today)._

| item (from section 4) | destination |
|---|---|
| user decision: attach BTC H4 PYR1 demo vs wait | DONE — user attached rev05 deep-pyr+ER as magic 990026 on 2026-07-28 (ORDER-353, DEPLOYMENTS.csv row) |
| pullback / S-R / STO re-entry lever (rev04) on BTC H4 | ORDER-353 — campaign built rev04/rev05; deployed 990026 binary proven rev04-or-newer |
| move swap script into scripts/ | DONE — `scripts/swap_adjust_crypto.py` (was already marked done in this file) |
| remaining matrix-2 cells (#20-24 BRENT/NAS100/DE40/XAU-H1/US30) | ORDER-GEN-STANDING — standing matrix screening lane (ran 12 cells 2026-08-04) |
| portfolio 5-symbol cap + equity-kill as a separate layer | BACKLOG-D26 — account-structure ceiling (EA-level cage cannot bound the episode) |
