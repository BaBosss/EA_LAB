# Triage — SSRN "151 Trading Strategies" + PBX eBooks (2026-07-13)

แหล่งที่มา: user แชร์จากเพจ FB **Kittinu Muayteng (PolarBearX / PBX)** — PhD Financial Innovation,
Founder/Chief AI Investment Officer, 168 Capital Management (HK). ไฟล์ 3 ตัว:

| ไฟล์ | คืออะไร | สถานะ |
|---|---|---|
| PBX eBook 2025 (46p) | *"Becoming the Top 1% Trader"* — framework/mindset ล้วน ไม่มี edge เชิงกล | อ่านครบ = validation ทิศเรา + เก็บ 3 ของเล็ก |
| PBX eBook 2026 (54p) | scan รูปภาพ (text ได้แค่หน้า CV/cert) | ⛔ OCR ติด: เครื่องไม่มี tesseract/pdftoppm/gs/imagemagick, pip พังเพราะ TLS proxy |
| **SSRN id3453295** | **Kakushadze & Serur "151 Trading Strategies" (2018)** — 550+ สูตร, source code OOS backtest, ~2000 refs | 💎 ขุมทรัพย์จริง — text ครบ 13,392 บรรทัด |
| ต้นฉบับ PDF | `D:\EA_LAB\docs\ssrn_id3453295_code2224789.pdf` | เก็บถาวรใน repo แล้ว |

## PBX eBook 2025 — 3 ของที่หยิบใช้ได้
1. **Expectancy floor** `E = (Winrate × R) − ((1−Winrate) × 1)` + ตาราง winrate ขั้นต่ำต่อ RRR
   (RR 1.5:1 → WR ≥ 40%). เพิ่มเป็น 1 คอลัมน์ใน screener (คู่กับ PF ที่มีอยู่).
2. **Daily Mindset Checklist** (pre/mid/post) → map เข้าลูป operate/monitor (`ea-live-monitor`).
3. **6 trader archetypes** → ยืนยัน thesis `signal-landscape`: พอร์ตควรกิน momentum×reversion โดยตั้งใจ.

## SSRN 151 Strategies — SHORTLIST ที่ตรงกับ MT5 (FX/XAU/indices) ของเรา

### A. Build ได้ทันที (single-instrument, ไม่ต้อง data feed ใหม่) — ลำดับความคุ้ม
1. **8.1 MA + Hodrick-Prescott filter** ⭐ ของใหม่คุ้มสุด/ถูกสุด: กรอง noise ความถี่สูงด้วย HP filter
   *ก่อน* คำนวณ MA → ลด false MA-cross. เป็น bolt-on กับ EA MA/trend ที่เรามีอยู่. λ≈100×n².
2. **10.4 Trend following** vol-scaled: `w = sign(R)/σ`, กัน signal flip แถว 0 ด้วย `η = tanh(R/κ)`.
   tanh-smoothing = anti-whipsaw trick เอาไปใส่ trend EA ได้เลย. คู่กับ vol-gate ใน `portfolio-edge-thesis`.
3. **10.3 Contrarian MR**: buy losers/sell winners vs market-index, rebalance รายสัปดาห์, suppress ด้วย
   1/σ + ฟิลเตอร์ volume/open-interest. (cross-sectional — ต้อง basket หลายคู่). map กับ ST03 harvester.

### B. Cross-sectional / portfolio (ต้อง basket หรือ carry data)
4. **8.4 Momentum & carry combo** — รวม 2 edge ด้วย min-variance weight (สูตร σ/ρ, Eq.451-452).
   = allocator ที่คมกว่าเดิม, ใส่ใน `portfolio-selector` ได้.
5. **8.2/8.2.1 Carry (high-minus-low)** — rank คู่เงินด้วย forward discount (≈ rate diff / swap),
   long top / short bottom. ประมาณด้วย swap rate ของโบรก.
6. **8.3 Dollar carry** — long/short ทั้ง basket ตาม avg forward discount = macro regime signal.
7. **9.2 Hedging pressure (COT)** — ใช้ positioning จาก CFTC COT report เป็นสัญญาณ (data source ใหม่ที่เรายังไม่ใช้).

### C. เทคนิค reusable (ไม่ใช่ทั้ง strategy)
- min-variance 2-strategy combo weights (8.4) → allocator
- 1/σ vol-scaling ของ position (10.3/10.4) → sizing
- `tanh(R/κ)` signal smoothing (10.4) → anti-whipsaw
- HP-filter denoise (8.1) → signal cleanup
- Appendix A มี **source code (R)** สาธิต OOS backtest — reference ไม่ใช่ MQL

## แผนคิวรอทำ (WAITING — ยังไม่ fire เป็น ORDER, รอ user เคาะทีละตัว)

catalog กลไกเต็ม = `SSRN_151_catalog_mechanisms.md`. คัดเฉพาะที่ build บน MT5 rig ปัจจุบันได้ (FX/XAU,
ไม่ต้อง data feed ใหม่) เรียงตาม **คุ้ม/ถูก/เร็วก่อน**:

### W1 ⭐ — bolt-on denoise+anti-whipsaw กับ trend EA เดิม (ถูกสุด คุ้มสุด)
เอา **8.1 HP-filter** (กรอง noise ก่อนคิด MA) + **10.4 tanh(R/κ) vol-scale** (กัน sign-flip) ใส่ MA-cross
EA ที่มีอยู่. accept: PF ยก ≥10% หรือ whipsaw-trade ลด ≥20% บน XAU+3 major FX, 2 TF, ทั้ง BWD+ปีล่าสุด.
single-instrument, เทสได้ทันที.

### W2 — IBS mean-reversion probe (4.4) — signal บรรทัดเดียว
IBS=(C−L)/(H−L); entry เมื่อ IBS<0.2 (buy) / >0.8 (sell), exit ตรงข้าม/บาร์ถัดไป. ถูกมาก เทสเร็ว.
accept: PF>1 บน ≥3 symbol × 2 TF (per VERDICT GATE). map กับ ST03 mean-reversion harvester.

### W3 — Pivot S/R (3.14) + Donchian channel (3.15) — 2 EA classic buildable
pivot C/R/S รายวัน; Donchian breakout+volume confirm. accept: coarse→surface plateau, PF>1 both regimes.

### W4 — OU mean-reversion pricing model (9.6) — MR มีหลักการ
fit dX=κ(a−X)dt+σdW บน log-price XAU/FX, entry เมื่อ price เบี่ยงจาก model >n·σ. เหมาะ XAU range.
ต้อง fit + OOS hold (กัน overfit). ระดับกลาง.

### W5 — KNN single-instrument (3.17) — novel ML, ต้องระวัง overfit หนัก
predict fwd return ด้วย KNN บน normalized MA predictors. accept: OOS + MC ต้องผ่าน (ML = overfit-prone).

### เทคนิค reusable (แทรกได้ทุกเมื่อ ไม่ใช่ EA เดี่ยว)
- **8.4 / 3.18 min-variance & max-Sharpe combo weights** → อัป `portfolio-selector` allocator
- **4.1.2 dual-momentum regime gate** ("long เฉพาะเมื่อ index uptrend ไม่งั้นถือ safe") → regime filter
- **6.5 / 4.6 vol-target sizing** (w=σ*/σ) → position sizing
- **19.5 news-day gate** (สลับ risk-on/off ตามปฏิทินข่าว) → เข้ากับ news filter ที่มี

### ต้อง data feed ใหม่ (park ไว้ก่อน — คุ้มถ้าจะขยาย)
- **9.2 COT hedging pressure** (CFTC weekly) — signal ใหม่ที่เรายังไม่ใช้ สำหรับ XAU/FX/commodity
- carry (8.2/8.3) — ใช้ swap rate โบรกประมาณได้

### cross-sectional basket (ต้องมี multi-symbol engine ก่อน — เฟสหลัง)
3.1 momentum, 3.8/3.9 pairs/MR-cluster, 4.1 sector rotation, 10.3 contrarian, 9.1/9.4/9.5 commodity factors.

### 2026 eBook (คู่มือการเทรด / Trading Mastery Guide) — OCR ได้แล้ว ✅
poppler ลงแล้ว (`C:\Users\patip\tools\poppler`, ใน PATH). เนื้อ = Dow/Wyckoff/Elliott Wave/EMA system
(classic TA, แนว manual). **park** — แกะเต็มเมื่อต้องการ PA/structure ideas (map กับ PA-module devplan).
คำสั่งแปลง: `pdftoppm -png -r 130 ebook_2026.pdf out/p` แล้ว Read ทีละหน้า.

## NOT в scope (ข้ามถาวร — ไม่ใช่ silent drop): Options(2), Fixed income(5), Structured(11),
Convertibles(12), Tax arb(13), Misc(14), Distressed(15), Real estate(16), Cash(17), Infrastructure(20),
+ ภายในบท: 3.19 market-making, 6.2/6.3/6.4 index arb, 7.x volatility(options), 4.5 LETF — ต้อง
options/orderbook/HFT/instrument ที่ MT5 retail เราไม่มี.
