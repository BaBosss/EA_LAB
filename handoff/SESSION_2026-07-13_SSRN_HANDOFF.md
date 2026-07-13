# SESSION 2026-07-13 HANDOFF — SSRN-151 intake + ORDER-104 build (Opus)

> เริ่ม session หน้าที่นี่. งาน session นี้ = user แชร์เปเปอร์/เพจ/คลิป quant จากคอมมูนิตี้ **QuantCorner**
> → intake ความรู้ + build probe EA ตัวแรกจากไอเดียนั้น. **quota หมดกลาง build-verify** (commit แล้ว).

## ✅ ทำเสร็จ + commit แล้ว (commit 0fa491f)
1. **แกะ SSRN "151 Trading Strategies" (Kakushadze&Serur)** — `docs\ssrn_id3453295_code2224789.pdf`.
   catalog กลไก in-scope ครบทุก subsection = `_triage/SSRN_151_catalog_mechanisms.md` ·
   แผน W1-W5 + tier = `_triage/SSRN_151strategies_PBX_ebook_2026-07-13.md`.
2. **Intake QuantCorner ecosystem** (3 FB + 3 YouTube) = `_triage/QUANTCORNER_ecosystem_2026-07-13.md`.
   key: IC/Alphalens pre-backtest screen · quant fund taxonomy · workflow ยืนยัน loop-engine เรา.
3. **PBX eBook 2 เล่ม** (mindset + คู่มือการเทรด scan) — 2025 อ่านครบ, 2026 = classic TA (Dow/Wyckoff/
   Elliott/EMA) park ไว้. **poppler ลงแล้ว** (`C:\Users\patip\tools\poppler`, ใน PATH) → OCR scan-PDF ได้แล้ว
   (`pdftoppm -png ... ` แล้ว Read ภาพ).
4. **BUILD ORDER-104** = `ea_projects\(TRD)_Probe_MAHP_TanhVol\(TRD)_Probe_MAHP_TanhVol_rev01.mq5` (+.ex5).
   2-MA crossover + 2 toggle: HP-filter denoise (causal, banded-Cholesky, **ยืนยันไม่ look-ahead**) + tanh
   vol-scale. **compile 0/0 + mql-review PASS.** ex5 copy เข้า `D:\Meta 5\MQL5\Experts\` แล้ว.

## 🚀 NEXT STEP ทันที — รัน Smoke Stage A (launcher พร้อม, ยังไม่ได้รัน)
**user รันเองได้ยาวๆ** (quota ไม่เกี่ยว): **ปิด MT5 GUI ก่อน** แล้ว:
```
cd D:\EA_LAB ; powershell -ExecutionPolicy Bypass -File scripts\order104_smokeA.ps1
```
= 32 run (4 combo × XAU+EURUSD × H1+H4 × 2 window, Model 2 control-points). ออก
`_mt5_auto\reports\P104_summary.csv` (PF+trades ต่อ cell) + report htm.

**Claude session หน้า judge:** อ่าน P104_summary.csv → เทียบ combo (hp/tanh/both) vs base ต่อ cell ตาม
**acceptance ORDER-104**: PF ยก ≥10% *หรือ* whipsaw ลด ≥20% (PF ไม่ตก) บน ≥ครึ่ง cell ทั้ง 2 window (plateau
ไม่ spike). ผ่าน → build-on + Model 4 real-tick confirm + lambda sweep {1600,129600} (Stage A2, แก้ $combos
ใน launcher). ไม่ผ่าน → verdict "no-edge บน MA-cross" ปิด cell (ห้ามเขียน concept ตายสากล). ⚠️ ระวัง HP
**endpoint instability** — ถ้า HP แย่ลง เช็คว่าเป็น endpoint noise ไม่ใช่ denoise ล้มเหลว.

## 📋 คิวถัดไป (SSRN W2-W5 + intake actions — ยังไม่เป็น ORDER, รอ user เคาะ)
- **W2 IBS mean-reversion** (4.4) · **W3 Pivot(3.14)+Donchian(3.15)** · **W4 OU-model(9.6)** · **W5 KNN(3.17)**
  — spec ย่อใน `_triage/SSRN_151strategies_PBX_ebook_2026-07-13.md`.
- **IC-screen** (จาก YouTube "Idea to Algorithm") → เสริม `signal-scanner`: rank entry ด้วย signal strength
  วัด Spearman-corr กับ N-bar-forward return *ก่อน* optimize. คุ้ม กัน spike ตั้งแต่ต้นทาง.
- reusable: min-var allocator(8.4) · dual-momentum regime gate(4.1.2) · vol-target sizing(6.5).
- แหล่งขุดต่อ: QuantCorner Discord/quant-corner.com · Hudson&Thame mlfinlab (López de Prado, ตรง overfit-control).

## ห้าม (คงเดิม)
promote เงินจริงจาก probe · ตัดสิน concept ตายจาก cell เดียว · HP two-sided · แก้ EA production/validate แล้ว.
