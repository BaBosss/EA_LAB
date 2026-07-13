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

## Stage B — HP λ-sweep {1600, 129600} + IBS mean-reversion (24 runs)
_(รอผล batch b6cr02qgg — จะเติมตาราง + เทรนด์เมื่อจบ)_

**สมมติฐานก่อนดูผล:**
- **λ=1600 (smooth น้อย):** ใกล้ raw price มากขึ้น → trade เยอะกว่า λ14400, ผลควรใกล้ base มากขึ้น
  (regime-invert น้อยลง แต่ denoise benefit ก็น้อยลง). ถ้า λ1600 ไม่ทำลาย REC = ยืนยันว่า over-smoothing คือปัญหา.
- **λ=129600 (smooth มาก):** lag มากขึ้น → regime-invert ควรรุนแรงกว่าเดิม (REC ยับหนักกว่า λ14400).
- **IBS mean-reversion:** เป็น signal คนละแบบ (mean-revert แท้ ไม่ lag). สมมติฐาน: น่าจะดีกว่าบน XAU (mean-revert
  home) โดยเฉพาะ range period; H1 อาจ trade เยอะ. ดูว่าผ่านทั้ง 2 regime ไหม (ต่างจาก HP ที่ regime-invert).

_(ตาราง + เทรนด์ + verdict เติมที่นี่)_

---

## บทเรียนรวม (durable)
1. **HP denoise ≠ ดีเสมอ** — บน trend chassis มันแลก whipsaw กับ signal ใน 규 regime ที่ดี (regime-invert).
   ถ้าจะใช้ HP ควรจับคู่ mean-revert chassis ไม่ใช่ trend. → กัน W-tier อื่นพลาดซ้ำ.
2. **calibration ของ vol-scale ต้องระวัง horizon** — R กับ κ ต้อง horizon เดียวกัน ไม่งั้น tanh อิ่มตัว = no-op.
3. **toolchain ครบวงจรใช้ซ้ำได้:** probe EA scaffold (bar-gate/tester-gate/risk-cap/state-free) + launcher +
   roaming-Experts fix ([[mt5-tester-experts-roaming]]) + summary CSV auto-scrape.
