# HANDOFF — 2026-07-23D (session close)

## จบแล้ววันนี้ (commits `738c490` → `20503f4`, 8 ก้อน)

**เรื่องใหญ่: MT5 tester nondeterminism root-caused + fixed (ORDER-162/165)** — ไม่ใช่ engine drift
อย่างที่สรุปไว้รอบแรก (แก้แล้ว) แต่คือ 2 silent no-op ในเครื่องมือของเราเอง:
1. `[TesterInputs]` override เฉพาะ input ที่ระบุ — ที่เหลือมาจาก per-terminal cache
   `MQL5\Profiles\Tester\<EA>.set` ที่ session ไหนก็ตามรันทับไว้ล่าสุด
2. `Leverage=100` (เลขเปล่า) = no-op เงียบ ต้องใช้ format `1:N`

แก้แล้ว: `mt5_run.ps1` เขียน leverage แบบ `1:N` + assert กลับจาก report (exit 3 ถ้าไม่ตรง) + WARN ถ้ารันไม่มี
`-SetFile`. capture full compiled-default set ครบ 8 Boss EA (`ea_template/sets/regression/`) + re-pin
`regression_baseline.csv` + **พิสูจน์ reproducible 8/8 byte-exact** (รันซ้ำทันทีหลัง pin ได้เลขเดียวกันเป๊ะ)

**Memory ข้ามเซสชัน:** `mt5-tester-cache-nondeterminism.md` — อ่านก่อนเชื่อเลข backtest เก่าตัวไหนที่ "ดูแปลกๆ"

## ผล re-validate (ORDER-166→169, user อนุมัติ re-validate ทั้งหมด)

| EA | เดิม | จริงบน pinned config | สถานะ |
|---|---|---|---|
| Boss_14 XAU (990207) | net+5078 | **1.91**/533t | ✅ แข็งสุดจริง |
| Boss_14 EURUSD (990206) | — | **1.73**/80t | ✅ |
| Boss_14 GBPJPY (990208) | all-years+ | **1.70**/79t | ✅ |
| Boss_14 EURJPY (990203) | — | **1.57**/128t | ✅ |
| Boss_14 CADJPY (990205) | — | **1.29**/45t | ✅ n บาง |
| Boss_14 USDJPY (990201) | 1.72 | **1.19**/252t | ⚠️ หวุดหวิด |
| Boss_14 AUDNZD (990202) | **"champion" 3.37** | **1.09**/138t | ❌ อ่อนสุดจริง |
| Boss_14 AUDCAD (990204) | — | **1.09**/93t | ❌ |
| RSI-MR (990103, ยังไม่ attach) | WFA ER1.25 score89 | 3/3 OOS: 1.30/**1.08**/2.51 | 🟡 PARKED, มั่นใจน้อยลง |
| MacdDiv D1-majors | "PASS" 1.86 | holdout 0.15-0.82 | ❌ ตระกูลปิด (บ้าน XAU H4 999094 ไม่กระทบ) |
| TrendRider XAG/UJ/EJ | BUILD-ON x3 | holdout: 1.37/0.38/0.32 | XAG=BUILD-ON เท่านั้น (BWD 0.97), UJ/EJ ตาย |
| SS4 SweepReversal EURUSD | pulse 1.08 | coarse grid ceiling 1.06-1.21 | PARKED (RoundStep×AdxMax ไม่ปลดล็อก) |

**ไม่มี kill ใดๆ** — Boss_14 ×8 และ S1 TrendRider XAU (992004) ยัง ACTIVE ถึง judge date เดิม
(2026-10-09 / 2026-10-23) demo-forward P&L คือกรรมการตัวจริง ไม่ใช่ backtest ใหม่นี้

## บทเรียนที่ควรจำ

- **verdict ต้องผูกกับ config ไม่ใช่แค่ symbol×TF** — MacdDiv GBPUSD D1 มี 2 config ให้ผล PF ต่างกันเยอะ
  (defaults 1.23 vs demo-tuned 1.82) และ ORDER-117/149 เทสคนละตัวโดยไม่รู้ตัว
- **both-window ผ่าน ≠ edge จริง** — holdout ฆ่า 4/5 cell ที่เคยดูดีวันนี้ (TrendRider expansion + MacdDiv)
- ผมแก้คำตัดสินตัวเอง 3 ครั้งวันนี้ (ORDER-149/147/166) — ทุกครั้งเพราะทดลองจริงก่อนเชื่อการไล่ตัดตัวแปร

## ค้าง (ไม่เร่งด่วน — ลำดับ EV โดยประมาณ)

1. **RSI-MR full re-optimize** ถ้าจะดัน CANDIDATE (ตอนนี้แค่ verify, ยังไม่ optimize ใหม่)
2. **XAGUSD optimize-for-silver** ถ้าจะดัน TrendRider BUILD-ON→CANDIDATE (ทุกเลขที่มียืม center ของ XAU)
3. **SS4 SweepAtr/TpAtr lever** ยังไม่แตะ (RoundStep×AdxMax ตอบแล้วว่าไม่พอ)
4. **CR-002 lock bundle** — ต้องได้ `.set` จริงจาก VPS (990101/991004/991002 + Boss_14 bench ×7) ค้างจากต้นเซสชัน
5. **ORDER-091B / ORDER-142(สอง = intake sub-order)** BLOCKED รอ user เติมไฟล์/ข้อมูล
6. งานเชิงระบบ (ROADMAP §3 backlog ที่เหลือ) — ส่งให้ session แยกไปแล้วต้นเซสชัน, เช็คสถานะที่ AGENT_TASKBOARD
   ORDER-152..160 ก่อนเริ่มใหม่

## Gotcha สำหรับ session ถัดไป

- **ทุกการทดสอบ backtest ต่อจากนี้ต้องใช้ full pinned .set** — อย่ารัน `mt5_run.ps1` โดยไม่มี `-SetFile`
  (จะมี WARN เตือนอัตโนมัติแล้ว แต่ควรใส่จริงเสมอ)
- lane1 (`D:\Meta 5`) = terminal ส่วนตัวของ user (บัญชี 146237) — เช็ค `Get-Process terminal64` ก่อนรันเสมอ
  อย่า kill โดยไม่ถาม
- lane2 (`D:\Meta 5b`, portable) ใช้ทดสอบคู่ขนานได้โดยไม่ชนกับ user — ต้องมี compiled `.ex5` มิเรอร์ไปก่อน
  และ wipe tester-cache ก่อน capture defaults ทุกครั้ง
