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

## ⏳ SMOKE STAGE A — กำลังรันอยู่ (launched 2026-07-13 ~18:2x, background)
batch `scripts\order104_smokeA.ps1` ปล่อยแล้ว 32 runs (Model 2) — verify run แรกผ่าน (base XAU H1 REC =
**PF 1.24, 587 trades**). ผลรวม → `_mt5_auto\reports\P104_summary.csv`. **session หน้า: อ่าน CSV → judge ตาม
acceptance ORDER-104** (ด้านล่าง). ถ้า batch ยังไม่จบ/ล่ม → rerun คำสั่งใน "NEXT STEP" ด้านล่าง.

> 🔴 **GOTCHA ที่เพิ่งเสียเวลาไป (2026-07-13):** tester install `D:\Meta 5` เป็น **non-portable** → หา EA จาก
> **roaming** `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\`
> **ไม่ใช่** install folder `D:\Meta 5\MQL5\Experts`. compile ใน ea_projects แล้วต้อง **copy .ex5 ไป roaming Experts**
> ถึงจะเทสได้ (ไม่งั้น "tester EX5 not found", report เงียบ). bash `cp` พังกับชื่อมี `()` — ใช้ PowerShell
> `Copy-Item -LiteralPath ... -Force`. (EA อื่นที่เทสได้ทั้งหมดอยู่ roaming นั้น).

## 🚀 rerun Smoke Stage A (ถ้าต้องปล่อยใหม่)
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

## ✅ STAGE A+B DONE (2026-07-13) — verdict + build-on ที่ผ่าน
ผลเต็ม = `_triage/_archive/verdicts/order104-126/ORDER104_EXPERIMENT_SUMMARY.md`. สรุป:
- **HP@λ1600 บน XAU ผ่าน both-regime** (XAU H4 1.35/1.68) = **candidate build-on** (Stage A ที่ตี HP ตกเป็น λ14400 artifact)
- IBS naked ตก (park, ต้อง filter) · tanh inert (calib bug R/κ horizon)
- **NEXT BUILD (priority):** build-on XAU-H4-HP-λ1600 → sweep MA-period/SL รอบ plateau + Model-4 confirm + holdout/MC
- **IDEA-1 (user 2026-07-13, จดใน summary):** HP = direction filter (ไม่ใช่ trigger) + PA entry engine แยก + scale-in
  capped → แก้ปัญหา thin. probe `Probe_HPdir_PAentry`. flat-lot ก่อน · capped+SL (กัน martingale) · both-regime.

## 📋 คิวถัดไป (SSRN W2-W5 + intake actions — ยังไม่เป็น ORDER, รอ user เคาะ)
- **W2 IBS mean-reversion** (4.4) · **W3 Pivot(3.14)+Donchian(3.15)** · **W4 OU-model(9.6)** · **W5 KNN(3.17)**
  — spec ย่อใน `_triage/SSRN_151strategies_PBX_ebook_2026-07-13.md`.
- **IC-screen** (จาก YouTube "Idea to Algorithm") → เสริม `signal-scanner`: rank entry ด้วย signal strength
  วัด Spearman-corr กับ N-bar-forward return *ก่อน* optimize. คุ้ม กัน spike ตั้งแต่ต้นทาง.
- reusable: min-var allocator(8.4) · dual-momentum regime gate(4.1.2) · vol-target sizing(6.5).
- แหล่งขุดต่อ: QuantCorner Discord/quant-corner.com · Hudson&Thame mlfinlab (López de Prado, ตรง overfit-control).

## ห้าม (คงเดิม)
promote เงินจริงจาก probe · ตัดสิน concept ตายจาก cell เดียว · HP two-sided · แก้ EA production/validate แล้ว.
