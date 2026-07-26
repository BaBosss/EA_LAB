# ORDER-104 Experiment Summary — SSRN-151 W1/W2 probes

> รวมผลการทดลองทั้งหมดจากการนำไอเดียใน Kakushadze&Serur "151 Trading Strategies" มาทดสอบบน MT5.
> chassis ทดสอบ = single-instrument probe EAs. matrix มาตรฐาน: {XAUUSD,EURUSD}×{H1,H4}×{BWD 2020-22,
> REC 2023-26}, Model 2 (control points). เกณฑ์ตัดสิน = ORDER-104 acceptance (VERDICT GATE).
> raw: `_mt5_auto/reports/P104_summary.csv` (Stage A), `P104b_summary.csv` (Stage B).

## ภาพรวมสิ่งที่ทดสอบ
| เทคนิค (ที่มา) | chassis | สถานะ | ผลสรุป |
|---|---|---|---|
| HP-filter denoise (§8.1) | 2-MA crossover | Stage A + λ-sweep | ตกเกณฑ์ (regime-invert) — ดูล่าง |
| tanh vol-scale (§10.4) | 2-MA crossover | Stage A | INERT (calibration bug) |
| IBS mean-reversion (§4.4) | standalone | Stage B | _(รอผล)_ |

---

## Stage A — HP-denoise + tanh vol-scale บน 2-MA crossover (32 runs, DONE 2026-07-13)

### base 2-MA crossover (chassis เปล่า)
| cell | BWD PF (trades) | REC PF (trades) |
|---|---|---|
| XAU H1 | 0.89 (507) | 1.24 (587) |
| XAU H4 | 0.80 (131) | 1.40 (133) |
| EUR H1 | 0.90 (588) | 1.06 (624) |
| EUR H4 | 1.28 (128) | 0.90 (173) |
**เทรนด์ base:** แต่ละ cell ดีแค่ window เดียว (XAU ดี REC, EUR H4 ดี BWD) — ไม่มี cell ไหนผ่านทั้ง 2 regime.
2-MA เปล่า = ไม่ใช่ keeper, เป็นแค่ chassis ทดสอบ bolt-on.

### HP-denoise @ λ=14400 (base → hp)
| cell | base→hp PF | trades | Δ |
|---|---|---|---|
| XAU H1 BWD | 0.89→1.01 | 507→126 | ↑ (cell อ่อน) |
| XAU H1 REC | 1.24→0.98 | 587→142 | ↓ พังจาก >1 |
| XAU H4 BWD | 0.80→1.39 | 131→30 | ↑ (n บาง) |
| XAU H4 REC | 1.40→0.32 | 133→28 | ↓↓ ยับ |
| EUR H1 BWD | 0.90→0.94 | 588→123 | ~ ยัง<1 |
| EUR H1 REC | 1.06→1.06 | 624→138 | = |
| EUR H4 BWD | 1.28→1.23 | 128→38 | ↓ นิด |
| EUR H4 REC | 0.90→0.75 | 173→39 | ↓ |

**เทรนด์ HP (สำคัญ):**
1. **ตัด trade ~75% ทุก cell** — denoise ลด false cross ได้จริง (whipsaw ลงมหาศาล)
2. **แต่ PF ไม่ได้ดีขึ้นสม่ำเสมอ — กลับหัวตาม regime:** ช่วยเฉพาะ cell *อ่อน* (BWD ที่ base<1) แต่**ทำลาย cell
   *แข็ง* (REC ที่ base>1)** อย่างรุนแรง (XAU H4 REC 1.40→0.32). = **regime inversion** classic
3. **กลไกที่อธิบาย:** HP smoothing = เพิ่ม lag → ใน REC ที่เป็น trend/momentum การ lag ทำให้เข้าช้า/ออกช้า →
   กำไรเทรนด์หาย. ใน BWD sideway การ smooth ช่วยกรอง noise. **HP ขัดกับ trend-following โดยโครงสร้าง.**
4. H4 + HP → trade เหลือ 28-39 = ต่ำกว่า floor 30 บาง cell → PF noisy เชื่อไม่ได้

**คำตัดสิน Stage A:** HP@λ14400 **ตกเกณฑ์ → ปิด cell** (ไม่ใช่ concept ตายสากล). tanh = **INERT** (bug: R 20-บาร์ /
κ 1-บาร์ → tanh อิ่มตัว ±1 → lot คงที่; `tanh`==`base` เป๊ะ, `both`==`hp` เป๊ะ). ต้อง rescale ก่อน judge ได้.

---

## Stage B — HP λ-sweep {1600, 129600} + IBS mean-reversion (24 runs, DONE 2026-07-13)

### 🎯 HP λ-sweep = พลิกข้อสรุป Stage A: **λ ต่ำ (1600) ใช้ได้จริงบน XAU ทั้ง 2 regime**
เทียบ PF ตาม λ (base → λ1600 → λ14400 → λ129600):
| cell | base | **λ1600** | λ14400 | λ129600 | trades λ1600 |
|---|---|---|---|---|---|
| XAU H1 BWD | 0.89 | **1.15** | 1.01 | 1.23(47) | 260 |
| XAU H1 REC | 1.24 | **1.26** | 0.98 | 1.00(42) | 312 |
| XAU H4 BWD | 0.80 | **1.35** | 1.39 | 3.16(10!) | 72 |
| XAU H4 REC | 1.40 | **1.68** | 0.32 | 1.10(12) | 64 |
| EUR H1 BWD | 0.90 | 0.75 | 0.94 | 1.23(38) | 294 |
| EUR H1 REC | 1.06 | 1.12 | 1.06 | 0.99 | 339 |
| EUR H4 BWD | 1.28 | 1.10 | 1.23 | 0.70 | 67 |
| EUR H4 REC | 0.90 | 0.83 | 0.75 | 0.28 | 88 |

**เทรนด์ HP (ชัดเจนมาก) — PF เป็นฟังก์ชันของ λ, พีคที่ λ ต่ำ:**
1. **λ=1600 (smooth เบา) บน XAU = ผ่านทั้ง 2 regime!** XAU H1 (1.15/1.26) + **XAU H4 (1.35/1.68)** ทั้งคู่ >1
   ทั้ง BWD+REC, n เพียงพอ (64-312). = **plateau ข้าม regime จริง** — ต่างจาก λ14400 ที่ regime-invert.
2. **ยิ่ง λ สูง ยิ่งแย่:** λ1600 (ดี) → λ14400 (regime-invert, REC พัง) → λ129600 (trade 10-50 = thin/noise,
   PF เลขสวยแต่ n=10-12 เชื่อไม่ได้, REC collapse). **ยืนยันสมมติฐาน: over-smoothing คือตัวปัญหา.**
3. **HP ช่วยเฉพาะ XAU ไม่ช่วย EUR** (EUR λ1600 mixed/ลง) → เป็น edge เฉพาะ instrument (XAU mean-revert-friendly).
4. **best cell = XAU H4 @ λ1600: BWD 1.35 / REC 1.68, n=72/64** — ผ่าน both-regime gate → **candidate build-on.**

### IBS mean-reversion (naked, threshold 0.2/0.8)
| cell | XAU PF (trades) | EUR PF (trades) |
|---|---|---|
| H1 BWD | 0.99 (4217) | 0.88 (4767) |
| H1 REC | 0.96 (4660) | 0.80 (5430) |
| H4 BWD | **1.07** (967) | 0.98 (1150) |
| H4 REC | 0.89 (1095) | 0.81 (1291) |
**เทรนด์ IBS:** trade มหาศาล (4000-5400 บน H1) PF เกือบทั้งหมด <1 (0.80-1.07) → **naked IBS = ไม่มี edge**,
churn จ่าย cost. เฉพาะ XAU H4 BWD แตะ 1.07. **park** — ต้อง filter (band กว้างขึ้น / trend-gate / session)
ถึงจะมีลุ้น. IBS ดิบ = ตกเกณฑ์.

**คำตัดสิน Stage B:**
- **HP@λ1600 บน XAU = ผ่าน both-regime → PROMOTE ไป build-on** (แก้ Stage A verdict: HP ไม่ตาย, แค่ λ14400 มากไป).
- **IBS naked = ตกเกณฑ์ → park** (ต้อง filter ก่อน).

---

## 💡 BUILD-ON IDEAS (user directive 2026-07-13 — จดไว้ทดลองต่อ)

### IDEA-1 ⭐ — HP = direction filter, ไม่ใช่ trade trigger (แก้ปัญหา thin)
**ปัญหา:** HP@λ1600 บน XAU H4 ให้ PF ดี (1.35/1.68) แต่ **trade บาง** (n=64-72) เพราะ MA-cross บน HP ยิงน้อย.
**ไอเดีย user:** thin ไม่ใช่จุดอ่อน — ให้ HP **ทำหน้าที่ "บอกทิศ" (direction/regime filter)** แทน แล้ว**แยก entry
engine** มาเปิดไม้ในทิศที่ HP อนุญาต → เพิ่มจำนวนไม้ + เพิ่มไม้ (scale-in) ได้:
- **direction gate:** HP-smoothed line slope (หรือ fast-HP vs slow-HP) = long-only / short-only / flat context.
  (คือใช้ signal คุณภาพสูงของ HP เป็น "อนุญาตทิศ" ไม่ใช่จังหวะเข้า)
- **entry engine (แยก, ยิงถี่กว่า):** เปิดไม้เมื่อเกิด **price-action event ในทิศที่ HP อนุญาต** เช่น
  pullback + bullish engulfing · break ของ minor swing · RSI-dip เข้าหาทิศ. เปิดได้หลายไม้ (add เมื่อมี PA ใหม่
  ในทิศเดิม — capped, มี SL) = แปลง "1 cross = 1 ไม้" เป็น "1 ทิศ = หลายไม้ตาม PA".
- **ทำไมน่าจะ work:** เก็บ edge เชิงทิศของ HP (ที่ทำให้ PF สูง) แต่ไม่ทิ้งโอกาส (thin) — PA เติมความถี่.
- **test plan:** probe ใหม่ `Probe_HPdir_PAentry` — HP direction (λ1600, XAU H4) × entry {engulfing / pullback /
  swing-break} × scale-in {1,2,3 ไม้ capped}. เทียบ vs HP-cross เดิม: trade เพิ่ม + PF คง/ดีขึ้นทั้ง 2 regime ไหม.
  ⚠️ VERDICT GATE: flat-lot ก่อน (edge จริงก่อน scale) · both-regime · holdout. ⚠️ scale-in = ระวัง martingale-fat-tail
  (capped + SL + entry-edge test ตาม gate ข้อ 5).

## บทเรียนรวม (durable)
1. **HP denoise = ดีที่ λ ต่ำเท่านั้น (lever คือ λ, ต้องเล็ก)** — λ1600 บน XAU ผ่าน both-regime;
   λ สูง (14400+) = over-smooth → lag → regime-invert/thin. **บทเรียน: อย่าตีตายจาก λ เดียว** (Stage A ตี HP
   ตกเพราะ λ14400 — พอ sweep λ เจอ λ1600 ดีจริง = ตรงกฎ user "ห้าม DEAD ก่อน optimize ครบ ≥3 lever"). edge เฉพาะ XAU.
2. **calibration ของ vol-scale ต้องระวัง horizon** — R กับ κ ต้อง horizon เดียวกัน ไม่งั้น tanh อิ่มตัว = no-op.
3. **toolchain ครบวงจรใช้ซ้ำได้:** probe EA scaffold (bar-gate/tester-gate/risk-cap/state-free) + launcher +
   roaming-Experts fix ([[mt5-tester-experts-roaming]]) + summary CSV auto-scrape.
