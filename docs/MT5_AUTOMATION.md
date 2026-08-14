# MT5 AUTOMATION — headless backtest (2026-06-14)

> ORDER-1350 correction: a non-zero tester `Swap` aggregate is already part of the tester-native
> report metrics. `scripts/swap_adjust_crypto.py --tester-swap-only` records that aggregate for
> provenance; its rate-based estimator is diagnostic only and must never be applied on top of it.

> ตอบคำถาม "ให้ MT5 รันอัตโนมัติได้ไหม" = **ได้** ผ่าน headless config (.ini)
> แต่มีเงื่อนไขจริง (ด้านล่าง) — อ่านก่อนรัน

## สิ่งที่ทำได้ตอนนี้ (v1) — single-test อัตโนมัติ ✅
`scripts/mt5_run.ps1` สั่ง `terminal64.exe /config:<ini>` ให้:
- โหลด EA + symbol + ช่วงวันที่ + inputs จาก .set
- รัน single backtest (real ticks) แบบไม่มีหน้าจอ → เขียน HTML report → ปิด terminal เอง
- คืน path ของ report → ป้อนเข้า pipeline ที่มี (parse → score → MC) ได้เลย

`scripts/mt5_batch_shortlist.ps1` = วน IS+OOS ให้ shortlist .set ทั้ง 4 ตัวอัตโนมัติ

## ⚠️ เงื่อนไขที่ต้องมี (ไม่งั้นรันแล้วได้ report ว่าง)
| เงื่อนไข | สถานะ |
|---|---|
| **ปิด MT5 GUI ก่อน** (headless ชนกับ GUI ที่เปิดบน data folder เดียวกัน) | ตอนนี้ GUI เปิดอยู่ → script จะ abort ให้อัตโนมัติ |
| EA ต้อง compile อยู่ใน `MQL5\Experts` | ✅ ครบ (Boss-2 Adaptive Smart Grid, Boss-6 Pivot, MatchaGrid, Gold_SMC...) |
| Symbol ต้องมี history โหลดแล้ว | ต้องเช็ค (EURCAD/AUDCAD/AUDNZD/NZDUSD) |
| Terminal login broker ค้างไว้ (ดึง history ได้) | ใช้ login ที่เซฟใน terminal |

## วิธีใช้ (ตอนสะดวก)
1. ปิด MT5 GUI
2. `powershell -File D:\EA_LAB\scripts\mt5_batch_shortlist.ps1`  ← รัน IS+OOS ให้ 4 ตัว
3. `python D:\EA_LAB\scripts\run_pipeline.py D:\EA_LAB\ea_projects D:\EA_LAB\_mt5_auto\reports`  ← score
4. สั่ง Claude "วิ่ง analyst+reviewer" → robustness + รีวิว

→ นายไม่ต้องนั่งคลิกทีละ test เอง แค่ปิด MT5 แล้วสั่ง 1 บรรทัด (หรือให้ผมสั่งให้ตอน GUI ปิด)

## วงจรเต็มที่นายอยากได้ (optimize → select → single-test)
```
[optimize EA]  → [select robust pass] → [gen .set] → [single-test IS+OOS] → [score+MC] → [registry]
   v2 (ดูล่าง)        select_robust ✅      set_from_robust ✅   mt5_run ✅        pipeline ✅
```
ขั้น single-test เป็นต้นไป **อัตโนมัติครบแล้ว**

## ⚠️ UPDATE 2026-07-26 — swap: tester คิดโหมด POINTS แต่ **ไม่คิด** โหมด INTEREST_CURRENT

**วัดแล้วไม่ใช่เดา** (probe ถือ position เดียว 30 วันแล้วอ่านเลขของ tester เอง —
`ea_projects\(TST)_SymbolSwapProbe\` มี 2 ตัว: `_SymbolSwapProbe` อ่านสเปก · `_SwapChargeProbe` วัดว่าคิดจริงไหม):

| symbol | swap mode | tester คิดไหม |
|---|---|---|
| XAUUSD | `POINTS` | **คิด** — วัดได้ −29.25 vs สเปก −29.19 ⇒ **backtest XAU หัก financing แล้ว ห้ามหักซ้ำ** |
| BTCUSD | `INTEREST_CURRENT` (−14.67%/ปี long) | **ไม่คิดเลย** — ถือ 30 วันได้ net = ราคาเปล่าเป๊ะ |
| ETHUSD | `INTEREST_CURRENT` (−9.86%/ปี long) | **ไม่คิดเลย** |

⇒ ผล crypto ต้องหัก swap เองด้วย **`scripts\swap_adjust_crypto.py`** (คำนวณจากเวลาถือจริงต่อไม้ · ใช้ราคาที่แย่กว่าของ
entry/exit เพื่อไม่ให้ต่ำกว่าจริง · เขียน trades CSV ที่หักแล้วให้ `monte_carlo.py` ต่อได้):

```powershell
python D:\EA_LAB\scripts\swap_adjust_crypto.py --rate-long 14.67 --rate-short 0.49 `
  --deals trades.csv --out trades_swapadj.csv D:\EA_LAB\_mt5_auto\reports\RUN_*.htm
```
**ก่อนเชื่อผลของ symbol ที่ยังไม่เคยแตะ ให้รัน probe ก่อนเสมอ** — โหมด swap ต่างกันต่อ symbol และ probe
ยังบอก `min_lot` ด้วย (เคส `ETHUSD min_lot=0.1`: `.set` ที่ใช้ 0.01 ทำให้ EA ปฏิเสธทุกออเดอร์ → รายงาน 0 ไม้
ที่หน้าตาเหมือน "ไม่มีสัญญาณ").

## ✅ UPDATE 2026-07-25 — headless OPTIMIZATION ทำได้แล้ว (หัวข้อ "v2 ยังไม่ทำ" ข้างล่าง = ล้าสมัย)

`scripts/mt5_optimize.ps1` รัน genetic headless แล้ว export XML ได้จริง → `scripts/parse_opt_xml.ps1` →
`scripts/select_robust_pass.py` → `scripts/set_from_robust.py` → `mt5_run.ps1` Model-4 confirm.
optimize range เก็บใน .set เป็น `value||start||step||stop||Y`. ตัวอย่างใช้งานจริง = `ORDER-GEN-STANDING`
MATRIX ชุดที่ 2 ใน `AGENT_TASKBOARD.md`.
**⚠️ ผล optimize รันบน Model 1 (เร็ว) = ใช้หา candidate เท่านั้น ห้ามใช้เป็นหลักฐาน** — ตัวเลขที่ใช้ตัดสิน
ต้องมาจาก Model-4 single-test ของ pass ที่เลือกแล้วเสมอ

## ~~ข้อจำกัด — headless OPTIMIZATION (v2, ยังไม่ทำ)~~ (superseded 2026-07-25 — ดูข้างบน)
- MT5 **รัน** optimization headless ได้ (`Optimization=2` ใน ini) แต่ผลออกมาเป็น **.opt cache (binary)** ไม่ใช่ XML
- MT5 ไม่มีคำสั่ง export opt → XML แบบ headless สะอาดๆ (ปกติต้อง export มือใน GUI)
- ทางออก v2: เขียน `OnTester()` hook ใน EA ให้เขียนผลทุก pass ลงไฟล์ หรือ parser อ่าน .opt — เป็นงานเพิ่ม
- **ตอนนี้:** ใช้ optimization XML ที่นายมีอยู่แล้ว (22 batch ในคลัง) → select_robust → .set → auto single-test ก็ได้ candidate ครบโดยไม่ต้อง optimize ใหม่

## ไฟล์ที่เกี่ยวข้อง
- `scripts/mt5_run.ps1` — launcher 1 job (มี safety guard GUI)
- `scripts/mt5_batch_shortlist.ps1` — batch IS+OOS ให้ shortlist
- output → `_mt5_auto/reports/` + `_mt5_auto/ini/`
