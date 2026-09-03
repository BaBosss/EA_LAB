# MT5 AUTOMATION — headless backtest (2026-06-14)

> ORDER-1350 correction: a non-zero tester `Swap` aggregate is already part of the tester-native
> report metrics. `scripts/swap_adjust_crypto.py --tester-swap-only` records that aggregate for
> provenance; its rate-based estimator is diagnostic only and must never be applied on top of it.

> ตอบคำถาม "ให้ MT5 รันอัตโนมัติได้ไหม" = **ได้** ผ่าน headless config (.ini)
> แต่มีเงื่อนไขจริง (ด้านล่าง) — อ่านก่อนรัน

## สิ่งที่ทำได้ตอนนี้ (v1) — single-test อัตโนมัติ ✅
`scripts/mt5_run.ps1` สั่ง `terminal64.exe /config:<ini>` ให้:
- โหลด EA + symbol + ช่วงวันที่ + inputs จาก .set
- รัน single backtest ตาม tester Model ที่ระบุใน config แบบไม่มีหน้าจอ → เขียน HTML report → ปิด terminal เอง. Strategy-performance evidence ต้องเป็น Model 1 / 1 Minute OHLC หรือดีกว่า; Model 2/Open Prices เป็น diagnostic-only; Candidate ทุก EA ต้องผ่าน frozen-config Model 4 MAIN+BWD ก่อน
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
3. ~~step 3, the legacy scoring pipeline~~ — **REMOVED. That pipeline is QUARANTINED** (archived
   BacktestScore v1; it refuses by default with exit 3 / `REFUSED (LEGACY / NON_FACTORY)`). Do not
   run it and do not pass `--allow-legacy-selection` to get past the refusal. There is no generic
   replacement: read the parsed report numbers against CLAUDE.md's VERDICT GATE bar table.
4. สั่ง Claude "วิ่ง analyst+reviewer" → robustness + รีวิว

→ นายไม่ต้องนั่งคลิกทีละ test เอง แค่ปิด MT5 แล้วสั่ง 1 บรรทัด (หรือให้ผมสั่งให้ตอน GUI ปิด)

## วงจรเต็มที่นายอยากได้ (optimize → select → single-test)
```
[Model-1 qualified survivor] -> [CONTRACT-DRIVEN optimize/region map] -> [freeze finalist .set] -> [Model-1 BWD] -> [mandatory Model-4 MAIN+BWD] -> [direct-question robustness / late HOLDOUT as applicable] -> [Candidate decision]
```
ขั้น single-test เป็นต้นไป **อัตโนมัติครบแล้ว** — แต่ **ขั้น select ไม่ใช่ script generic อีกแล้ว**: the two
legacy selection scripts and the legacy scoring pipeline that used to fill those boxes are quarantined
(see the QUARANTINE NOTICE below). A tick mark next to them in an older revision of this table meant
"the file runs", never "this is the sanctioned path".

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
**contract-driven selection** → freeze a finalist → `mt5_run.ps1` mandatory Model-4 MAIN+BWD pre-Candidate confirm on one acceptance-critical installation lineage.
optimize range เก็บใน .set เป็น `value||start||step||stop||Y`. ตัวอย่างใช้งานจริง = `ORDER-GEN-STANDING`
MATRIX ชุดที่ 2 ใน `AGENT_TASKBOARD.md`.

**QUARANTINE NOTICE — the selection step of that chain changed.** The two legacy scripts that used
to sit between the parse and the Model-4 confirm implement the archived BacktestScore v1 gate, were
never re-verified against the current VERDICT GATE, and are now quarantined: they refuse by default
(exit 3, `REFUSED (LEGACY / NON_FACTORY)`) and their `--allow-legacy-selection` output is
NON-AUTHORITATIVE. **Do not run them and do not pass that flag.** Submit the pass with
`-HypothesisRevision <rev>` instead and follow the launcher's own printed `next:` line; with no
contract bound it prints `SELECTION BLOCKED`, which is the answer rather than something to work
around. Contract source of truth = `_triage/factory_os/registry.py` + `_triage/factory_os/candidate.py`.
**⚠️ ผล optimize รันบน Model 1 / 1 Minute OHLC = research/search evidence for mapping a stable region and freezing a finalist; it does not create Candidate eligibility by itself.** The frozen finalist must pass Model-4 MAIN+BWD before Candidate. Model-2/Open-Prices and Math Calculations are diagnostic-only and their PF/net/DD/trades cannot support strategy selection.

## ~~ข้อจำกัด — headless OPTIMIZATION (v2, ยังไม่ทำ)~~ (superseded 2026-07-25 — ดูข้างบน)
- MT5 **รัน** optimization headless ได้ (`Optimization=2` ใน ini) แต่ผลออกมาเป็น **.opt cache (binary)** ไม่ใช่ XML
- MT5 ไม่มีคำสั่ง export opt → XML แบบ headless สะอาดๆ (ปกติต้อง export มือใน GUI)
- ทางออก v2: เขียน `OnTester()` hook ใน EA ให้เขียนผลทุก pass ลงไฟล์ หรือ parser อ่าน .opt — เป็นงานเพิ่ม
- **ตอนนี้:** ใช้ optimization XML ที่นายมีอยู่แล้ว (22 batch ในคลัง) → select_robust → .set → auto single-test ก็ได้ candidate ครบโดยไม่ต้อง optimize ใหม่

## ไฟล์ที่เกี่ยวข้อง
- `scripts/mt5_run.ps1` — launcher 1 job (มี safety guard GUI)
- `scripts/mt5_batch_shortlist.ps1` — batch IS+OOS ให้ shortlist
- output → `_mt5_auto/reports/` + `_mt5_auto/ini/`
