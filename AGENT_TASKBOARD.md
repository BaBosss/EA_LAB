# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(Claude)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = Claude/user เท่านั้น

---

## ORDER-001 — GBPAUD: re-optimize บน IS window (กัน in-sample bias) — `REVIEWED(Claude/Fable, 2026-07-04 — ผ่านการสอบสวน 2 ชั้น)` (role: ZCode/Codex)

**Final review (Claude/Fable, 2026-07-04):** ผล IS เหมือน full-window เป๊ะ 47/54 passes → สงสัย
cache pollution → controlled rerun หลัง clear `Tester\cache` (`BOSS14_OPT_GBPAUD_IS2`) ได้ผล
เหมือนเดิม = **ข้อมูลจริง ไม่ใช่ cache** · คำอธิบาย: **GBPAUD เข้า range แคบตั้งแต่ ~กลาง 2025** —
resting-stop ทั้ง BUY (เหนือ range) และ SELL (ใต้ range) ไม่โดน trigger 13 เดือนสุดท้าย มีแค่
pass 36/37 (spacing แคบสุด) ที่ยังเทรด · **Pass 26 RE-CONFIRMED เป็น plateau-center** — และแข็ง
กว่าเดิม: เทรดทั้ง 88 อยู่ก่อน 2025.06 แม้ใน full-window opt = การเลือก params นี้ไม่มี look-ahead
ตั้งแต่แรก · set `Boss14_GridLog_GBPAUD_IS_p26.set` ใช้ต่อได้ · mt5_optimize.ps1 เพิ่ม cache-clear
เป็น hygiene ถาวร · **บทเรียน:** เลขเหมือนเดิมเป๊ะข้าม window ≠ cache เสมอไป — dormancy ของ
resting-stop mechanism ก็ให้ผลแบบนี้ได้ ต้องแยกด้วย controlled rerun + ดู pass ความถี่สูง

**ทำไม:** plateau PF 1.71 ปัจจุบันมาจาก optimize บน window เต็ม = in-sample. ต้อง re-optimize บน
IS เท่านั้น แล้วเอา plateau-center ไปทดสอบ OOS ที่ไม่เคยเห็น (ORDER-002)

**คำสั่ง (รันตามลำดับ, ปิด MT5 GUI ก่อน):**
```powershell
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol GBPAUD -Period H1 -FromDate 2023.01.01 -ToDate 2025.06.30 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPAUD_opt1.set' -ReportName BOSS14_OPT_GBPAUD_IS -TimeoutSec 21600
```
**Acceptance:** ไฟล์ `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_GBPAUD_IS.xml` มีครบ 54 rows ·
append ตาราง top-10 pass (PF, Trades, EqDD%, params ทั้ง 4 คอลัมน์) ใต้ order นี้ · commit `[tag] ORDER-001 done`
**ห้าม:** ตัดสินว่า pass ไหน "ดีสุด" — รายงานดิบพอ (plateau-center = งาน Claude)

**ผล (Codex, Model 1):** XML `BOSS14_OPT_GBPAUD_IS.xml` ครบ **54 rows**. ตารางดิบด้านล่าง
เรียง `Profit Factor` จากมากไปน้อยเพื่อแสดง top-10 เท่านั้น (ไม่ได้เลือก plateau-center/verdict):

**Review & Plateau-center verdict (Claude, 2026-07-03):** Pass 26 (PF 1.71 / Trades 88 / DD 4.42%)
selected for OOS-confirm. Reason: PF = stable (matched p26 full-window 1.71, not overfit-peaking like
Pass 3 PF 2.38), Trades wide (88 = cushion), DD low (4.42% = margin for OOS volatility). Set saved
as `Boss14_GridLog_GBPAUD_IS_p26.set` (params: Step 3.0×Dist 2.2×TP 175×BUY). Next order: OOS
confirm (ORDER-004).

| Pass | PF | Trades | EqDD% | _9_StepATRmult | _14_Direction | _14_DistAtrMult | _2_BasketTP_Money |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 3 | 2.382883 | 64 | 3.9710 | 1.4 | 2 | 1.4 | 100 |
| 33 | 2.371173 | 33 | 4.9115 | 1.4 | 2 | 3.0 | 175 |
| 52 | 1.903453 | 10 | 4.0263 | 2.2 | 2 | 3.0 | 250 |
| 26 | 1.706119 | 88 | 4.4203 | 3.0 | 1 | 2.2 | 175 |
| 9 | 1.473466 | 61 | 3.9710 | 1.4 | 2 | 2.2 | 100 |
| 50 | 1.447075 | 70 | 6.1250 | 3.0 | 1 | 3.0 | 250 |
| 32 | 1.407810 | 74 | 5.8881 | 3.0 | 1 | 3.0 | 175 |
| 19 | 1.326168 | 233 | 7.6547 | 2.2 | 1 | 1.4 | 175 |
| 43 | 1.311771 | 146 | 10.0078 | 2.2 | 1 | 2.2 | 250 |
| 48 | 1.285409 | 214 | 13.7788 | 1.4 | 1 | 3.0 | 250 |

---

## ORDER-002 — probe 3 symbol ที่ยังไม่เคย probe: AUDNZD / GBPJPY / NZDJPY — `REVIEWED(Claude, 2026-07-04)` (role: ZCode/Codex)

**Review (Claude/Fable):** ตัวเลข Codex verify จาก XML แล้ว**ถูกต้องทุกค่า** ✅ · verdict:
**AUDNZD = CANDIDATE (in-sample)** — 13/54 passes ผ่านเกณฑ์, best n≥60: PF 1.72/64t/dd 7.4% (1.4/BUY/3.0/250) ·
**GBPJPY = CANDIDATE (in-sample)** — 6/54, best 1.54/82t (3.0/BUY/3.0/250) ·
**NZDJPY = WATCH-thin** — 3/54, best 1.88/75t (1.4/BUY/1.4/250) แต่ plateau แคบ ·
ทั้งสามเป็น full-window in-sample → ต้องผ่าน IS-opt (cache-cleared!) → OOS → MC เหมือน GBPAUD
ก่อนเชื่อ · หมายเหตุ: probe เหล่านี้รันก่อน fix cache — แต่เป็น first-run ของแต่ละ symbol จึงไม่โดน
cache pollution (cache ปนได้เฉพาะ symbol ที่เคย optimize ด้วย set เดียวกันมาก่อน = GBPAUD ตัวเดียว)

**ทำไม:** กฎ "ห้ามตายก่อน optimize" — 3 ตัวนี้ default PF 1.30/1.13/1.11 ยังไม่เคยได้ probe

**คำสั่ง (ทีละตัว, ต่อจาก ORDER-001):**
```powershell
# แทน <SYM> ด้วย AUDNZD, GBPJPY, NZDJPY ทีละรอบ
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPAUD_opt1.set' -ReportName BOSS14_OPT_<SYM>_1 -TimeoutSec 21600
```
**Acceptance:** XML 3 ไฟล์ครบ 54 rows · ต่อ symbol: append จำนวน pass ที่ PF≥1.2 AND Trades≥60 +
top-5 ดิบ · commit `[tag] ORDER-002 done`

**ผล (Codex, Model 1):** XML ครบ **54 rows ต่อ symbol**. จำนวนแถวที่ `PF≥1.2 AND Trades≥60`:
AUDNZD **13**, GBPJPY **6**, NZDJPY **3**. ตาราง top-5 ดิบด้านล่างเรียง PF จากมากไปน้อย
(ไม่ได้กรอง Trades และไม่ได้ให้ verdict):

| Symbol | Pass | PF | Trades | EqDD% | _9_StepATRmult | _14_Direction | _14_DistAtrMult | _2_BasketTP_Money |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| AUDNZD | 37 | 4.115534 | 24 | 2.4008 | 2.2 | 1 | 1.4 | 250 |
| AUDNZD | 43 | 2.297015 | 46 | 3.4125 | 2.2 | 1 | 2.2 | 250 |
| AUDNZD | 44 | 2.221916 | 39 | 4.2505 | 3.0 | 1 | 2.2 | 250 |
| AUDNZD | 38 | 2.207582 | 45 | 4.7775 | 3.0 | 1 | 1.4 | 250 |
| AUDNZD | 49 | 1.805034 | 55 | 4.5148 | 2.2 | 1 | 3.0 | 250 |
| GBPJPY | 50 | 1.541452 | 82 | 5.2678 | 3.0 | 1 | 3.0 | 250 |
| GBPJPY | 44 | 1.373134 | 90 | 9.2308 | 3.0 | 1 | 2.2 | 250 |
| GBPJPY | 24 | 1.352491 | 322 | 12.7050 | 1.4 | 1 | 2.2 | 175 |
| GBPJPY | 25 | 1.264653 | 218 | 6.3469 | 2.2 | 1 | 2.2 | 175 |
| GBPJPY | 8 | 1.244923 | 158 | 7.2839 | 3.0 | 1 | 2.2 | 100 |
| NZDJPY | 36 | 1.884767 | 75 | 5.3052 | 1.4 | 1 | 1.4 | 250 |
| NZDJPY | 42 | 1.845102 | 78 | 6.2764 | 1.4 | 1 | 2.2 | 250 |
| NZDJPY | 49 | 1.837053 | 36 | 4.0013 | 2.2 | 1 | 3.0 | 250 |
| NZDJPY | 7 | 1.778842 | 49 | 2.9200 | 2.2 | 1 | 2.2 | 100 |
| NZDJPY | 26 | 1.454119 | 51 | 4.6280 | 3.0 | 1 | 2.2 | 175 |

---

## ORDER-004 — GBPAUD p26: OOS-confirm (2025.07-2026.07) + MC — `REVIEWED(Claude, 2026-07-04)` (role: ZCode)

**ผล + Verdict (Claude/Fable):** MC บน full report ผ่านสวย (DD 95th 4.94% / worst 7.97% / ruin 0%)
แต่ **OOS ตก: 23 เทรด PF 0.49 net -$329** (เทรดทั้งหมด H2-2025 แล้ว dormant) → **GBPAUD = PARKED
(regime-dependent)** — config ทำเงินเฉพาะ trend 2023–H1'25, fresh-start ใน range แพ้จริง และ
passes ที่เทรด range (36/37) ก็แพ้ (1.08→0.86) = กลไกนี้ไม่มีทางชนะ range GBPAUD · ไม่ผ่านไป demo ·
แพทเทิร์นเดียวกับ Zeus AUDJPY (chained run สวยเพราะหลับผ่านช่วงร้าย — fresh-start OOS คือภาพ
จริงของการ deploy) → ย้ำกฎ: **fresh-start OOS บังคับก่อน demo ทุก candidate ของ mechanism ตระกูลนี้**

**ปลด hold + แก้ spec (Claude, 2026-07-04):** IS2 ยืนยัน Pass 26 → set เดิมใช้ได้ · **คาดว่า OOS
จะเทรดบาง** (ช่วงนั้น GBPAUD range-dormant — fresh start จะ arm ใหม่ที่ราคาปัจจุบันจึงเทรดได้บ้าง
ต่างจาก chained run) → เกณฑ์อ่านผล: OOS ต้องไม่*ขาดทุนหนัก* (PF≥0.9 หรือเทรด <5 = ข้อมูลไม่พอ
ไม่ใช่ fail) · MC ให้รันบน **full report (BOSS14_GBPAUD_P26_M1.htm, 88 เทรด)** แทน OOS report
(เทรดน้อยเกิน MC ไม่มีความหมาย)

**คำสั่ง:**
```powershell
# (1) OOS confirm run
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol GBPAUD -Period H1 -FromDate 2025.07.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPAUD_IS_p26.set' -ReportName BOSS14_GBPAUD_OOS_P26_M1

# (2) MC on OOS report
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPAUD_OOS_P26_M1.htm --deposit 10000 --iters 5000
```
**Acceptance:** 2 reports + MC ผล (DD median/95th/worst, ruin, P(loss)) append ใต้ order นี้ · commit `[tag] ORDER-004 done`

**ผล:** _(รอ)_

---

## ORDER-003 — Monte Carlo บน GBPAUD p26 report — `SKIPPED` (subsumed into ORDER-004)

**คำสั่ง:**
```powershell
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPAUD_P26_M1.htm --deposit 10000 --iters 5000
```
**Acceptance:** append ผลเต็ม (DD median/95th/worst, ruin, P(loss)) ใต้ order นี้ · commit `[tag] ORDER-003 done`
**หมายเหตุ:** ห้ามตีความ — MC แบบ reshuffle เป็น optimistic bound (กฎอยู่ใน backtest-optimize-rigor)

**ผล:** _(รอ)_

---

## ORDER-005 — IS-optimize 5 candidates: AUDNZD / GBPJPY / EURJPY / EURCAD / USDJPY — `REVIEWED(Claude/Fable, 2026-07-04 — verdict รวมอยู่ที่ ORDER-006)` (role: ZCode/Codex)

**ทำไม:** ตามรอย GBPAUD pipeline — probe เดิมเป็น full-window in-sample ต้อง IS-opt ก่อนเลือก
params · GBPAUD ตก OOS ไปแล้ว เหลือ 5 ตัวนี้ (AUDNZD prior ดีสุด: ชนะ regime ล่าสุด 1.52/2.21)

**คำสั่ง (ทีละตัว ตามลำดับนี้, ปิด MT5 GUI ก่อน):**
```powershell
# แทน <SYM> ด้วย AUDNZD, GBPJPY, EURJPY, EURCAD, USDJPY ทีละรอบ
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2025.06.30 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPAUD_opt1.set' -ReportName BOSS14_OPT_<SYM>_IS -TimeoutSec 21600
```
**Acceptance:** XML 5 ไฟล์ (`BOSS14_OPT_<SYM>_IS.xml`) ครบ 54 rows ต่อไฟล์ · ต่อ symbol: append
top-8 ดิบ (Pass, PF, Trades, EqDD%, params 4 คอลัมน์) + จำนวน pass ที่ PF≥1.2 AND Trades≥50 ·
commit `[tag] ORDER-005 done`
**ห้าม:** เลือก "ตัวดีสุด"/ให้ verdict — Claude เลือก plateau-center แล้วจะออก order OOS ต่อเอง

**ผล (Codex, Model 1):** XML ครบ **54 rows ต่อ symbol**. จำนวน pass ที่ `PF≥1.2 AND Trades≥50`:
AUDNZD **1**, GBPJPY **7**, EURJPY **11**, EURCAD **9**, USDJPY **6**. Top-8 ดิบเรียง PF:

| Symbol | Pass | PF | Trades | EqDD% | StepATR | Direction | DistATR | BasketTP |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| AUDNZD | 37 | 2.807103 | 15 | 2.4008 | 2.2 | 1 | 1.4 | 250 |
| AUDNZD | 43 | 1.667403 | 38 | 3.4125 | 2.2 | 1 | 2.2 | 250 |
| AUDNZD | 20 | 1.586363 | 32 | 3.0101 | 3.0 | 1 | 1.4 | 175 |
| AUDNZD | 38 | 1.342324 | 32 | 4.7775 | 3.0 | 1 | 1.4 | 250 |
| AUDNZD | 44 | 1.257928 | 32 | 4.2505 | 3.0 | 1 | 2.2 | 250 |
| AUDNZD | 49 | 1.229125 | 49 | 4.5148 | 2.2 | 1 | 3.0 | 250 |
| AUDNZD | 18 | 1.228801 | 152 | 4.2620 | 1.4 | 1 | 1.4 | 175 |
| AUDNZD | 24 | 1.168098 | 133 | 4.4684 | 1.4 | 1 | 2.2 | 175 |
| GBPJPY | 50 | 1.708622 | 55 | 5.2678 | 3.0 | 1 | 3.0 | 250 |
| GBPJPY | 8 | 1.468166 | 128 | 5.0055 | 3.0 | 1 | 2.2 | 100 |
| GBPJPY | 24 | 1.361537 | 240 | 12.7050 | 1.4 | 1 | 2.2 | 175 |
| GBPJPY | 44 | 1.303121 | 64 | 9.2308 | 3.0 | 1 | 2.2 | 250 |
| GBPJPY | 48 | 1.253233 | 155 | 12.5323 | 1.4 | 1 | 3.0 | 250 |
| GBPJPY | 26 | 1.227407 | 81 | 8.7539 | 3.0 | 1 | 2.2 | 175 |
| GBPJPY | 25 | 1.203113 | 163 | 5.8702 | 2.2 | 1 | 2.2 | 175 |
| GBPJPY | 49 | 1.178734 | 83 | 11.0753 | 2.2 | 1 | 3.0 | 250 |
| EURJPY | 37 | 2.408822 | 75 | 6.0035 | 2.2 | 1 | 1.4 | 250 |
| EURJPY | 8 | 2.273917 | 105 | 3.0533 | 3.0 | 1 | 2.2 | 100 |
| EURJPY | 38 | 2.042048 | 63 | 4.8243 | 3.0 | 1 | 1.4 | 250 |
| EURJPY | 36 | 1.655633 | 126 | 10.7401 | 1.4 | 1 | 1.4 | 250 |
| EURJPY | 49 | 1.630224 | 69 | 6.3250 | 2.2 | 1 | 3.0 | 250 |
| EURJPY | 12 | 1.410824 | 222 | 9.3698 | 1.4 | 1 | 3.0 | 100 |
| EURJPY | 21 | 1.409411 | 25 | 6.9510 | 1.4 | 2 | 1.4 | 175 |
| EURJPY | 2 | 1.364178 | 130 | 5.0782 | 3.0 | 1 | 1.4 | 100 |
| EURCAD | 38 | 2.288116 | 29 | 3.3369 | 3.0 | 1 | 1.4 | 250 |
| EURCAD | 12 | 1.846445 | 130 | 4.0748 | 1.4 | 1 | 3.0 | 100 |
| EURCAD | 11 | 1.841992 | 26 | 2.0467 | 3.0 | 2 | 2.2 | 100 |
| EURCAD | 42 | 1.654548 | 146 | 8.5488 | 1.4 | 1 | 2.2 | 250 |
| EURCAD | 13 | 1.432975 | 129 | 3.8812 | 2.2 | 1 | 3.0 | 100 |
| EURCAD | 0 | 1.415957 | 255 | 5.3647 | 1.4 | 1 | 1.4 | 100 |
| EURCAD | 31 | 1.364625 | 57 | 4.1657 | 2.2 | 1 | 3.0 | 175 |
| EURCAD | 1 | 1.355875 | 107 | 3.9197 | 2.2 | 1 | 1.4 | 100 |
| USDJPY | 21 | 1.847322 | 30 | 7.4504 | 1.4 | 2 | 1.4 | 175 |
| USDJPY | 12 | 1.510960 | 136 | 6.1457 | 1.4 | 1 | 3.0 | 100 |
| USDJPY | 9 | 1.313944 | 30 | 5.8405 | 1.4 | 2 | 2.2 | 100 |
| USDJPY | 24 | 1.261130 | 114 | 8.2258 | 1.4 | 1 | 2.2 | 175 |
| USDJPY | 31 | 1.248596 | 90 | 6.9543 | 2.2 | 1 | 3.0 | 175 |
| USDJPY | 50 | 1.224317 | 47 | 6.6684 | 3.0 | 1 | 3.0 | 250 |
| USDJPY | 8 | 1.216410 | 100 | 4.7520 | 3.0 | 1 | 2.2 | 100 |
| USDJPY | 25 | 1.204775 | 97 | 7.2988 | 2.2 | 1 | 2.2 | 175 |

---

## ORDER-006 — fresh-start OOS ของ 5 ตัวจาก ORDER-005 (rule-based, ทำต่อจาก 005 ได้เลย) — `REVIEWED(Claude/Fable, 2026-07-04)` (role: Codex)

**Verdict (Claude/Fable, 2026-07-04):**
- 🥇 **USDJPY = OOS PASS แข็งสุด** — 106t PF 2.77 +$1,115 DD 3.6% (IS 1.51 → OOS ดีกว่า IS!) · plateau รองรับ (6 passes ≥1.2&≥50) → เข้า ORDER-010
- 🥈 **AUDNZD = OOS PASS (มีเงื่อนไข)** — 42t PF 3.02 +$756 แต่ **plateau บาง (pass 18 เป็นตัวเดียวที่ qualify)** — ระวัง single-point fit → เข้า ORDER-010 พร้อม flag
- 🥉 **EURJPY = OOS PASS-thin** — 23t PF 2.15 → เข้า ORDER-010
- **GBPJPY = WATCH** — 23t PF 1.12 เสมอตัว ไม่ตกไม่ผ่าน → รอ MC/full-confirm ก่อนตัด
- ❌ **EURCAD = PARKED (regime-dependent)** — 140t PF 0.67 -$788 DD 12.7% — แพ้แบบ GBPAUD (เทรดเยอะแต่แพ้ regime ปัจจุบัน)
- หมายเหตุ: การเลือกแบบ mechanical (top-PF≥50t) ใช้ได้ครั้งนี้ — Claude spot-check แล้วไม่มีตัวไหนที่ plateau-center ต่างจาก pick อย่างมีนัยยะ ยกเว้น AUDNZD ที่ไม่มีทางเลือก

**ทำต่อจาก ORDER-005 โดยไม่ต้องรอ Claude** — ใช้กติกาเลือกแบบ mechanical (Claude จะ re-check ทีหลัง):
1. ต่อ symbol: เปิด `BOSS14_OPT_<SYM>_IS.xml` เลือก pass ที่ **PF สูงสุดในกลุ่ม Trades≥50** (ถ้าไม่มี pass ไหน Trades≥50 → ข้าม symbol นั้น รายงาน "no qualifying pass")
2. สร้าง set: copy `D:\EA_LAB\ea_template\sets\Boss14_GridLog_screen_small.set` → `Boss14_GridLog_<SYM>_ISpick.set` แล้ว override 4 ค่าตาม pass ที่เลือก: `_9_StepATRmult`, `_14_Direction`, `_14_DistAtrMult`, `_2_BasketTP_Money`
3. รัน fresh-start OOS:
```powershell
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2025.07.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_<SYM>_ISpick.set' -ReportName BOSS14_<SYM>_OOS_M1
```
**Acceptance:** ต่อ symbol: append แถว "pass ที่เลือก (เลข pass + 4 params) | OOS: trades / PF / net / eqDD%" · commit `[codex] ORDER-006 done`
**ห้าม:** ให้ verdict ผ่าน/ตก — Claude ตัดสิน (เกณฑ์อยู่ที่ Claude: OOS PF≥0.9 + regime-read)

**ผล (Codex, Model 1; ไม่มี verdict):** เลือกแบบ mechanical ตามกฎ `PF สูงสุดใน Trades≥50` และรัน
fresh-start OOS ครบ 5 symbol:

| Symbol | IS pass | StepATR | Direction | DistATR | BasketTP | OOS Trades | OOS PF | OOS Net | OOS EqDD% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| AUDNZD | 18 | 1.4 | 1 | 1.4 | 175 | 42 | 3.02 | 756.41 | 2.37 |
| GBPJPY | 50 | 3.0 | 1 | 3.0 | 250 | 23 | 1.12 | 97.79 | 4.79 |
| EURJPY | 37 | 2.2 | 1 | 1.4 | 250 | 23 | 2.15 | 473.31 | 4.25 |
| EURCAD | 12 | 1.4 | 1 | 3.0 | 100 | 140 | 0.67 | -788.44 | 12.70 |
| USDJPY | 12 | 1.4 | 1 | 3.0 | 100 | 106 | 2.77 | 1115.31 | 3.63 |

---

## ORDER-007 — probe Boss_14 อีก 7 symbol ที่ค้างทะเบียน (กฎ: ห้ามตายก่อน optimize) — `REVIEWED(Claude/Fable, 2026-07-04)` (role: ZCode/Codex)

**Verdict (Claude/Fable):** ❌ **USDCHF = DEAD-optimized** (0/54 — ปิดทะเบียนถาวร ตัวที่ 2 ต่อจาก
EURCHF) · ที่เหลือ 6 ตัวมี life ระดับ probe: CADJPY 8 · NZDUSD 8 (**ฝั่ง SELL — น่าสนใจ แกนใหม่**) ·
GBPUSD 5 · USDCAD 5 · AUDCAD 4 · EURUSD 3 (SELL) → เข้าคิว IS→OOS pipeline รอบถัดไป (หลัง
ORDER-009/010 จบ — อย่ารันพร้อมกัน MT5 ชนกัน) · ยังไม่ขึ้น candidate จนกว่าจะผ่าน fresh-start OOS

**คำสั่ง (ทีละตัว):** GBPUSD, CADJPY, USDCAD, USDCHF, AUDCAD, EURUSD, NZDUSD
```powershell
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPAUD_opt1.set' -ReportName BOSS14_OPT_<SYM>_1 -TimeoutSec 21600
```
**Acceptance:** ต่อ symbol: จำนวน pass ที่ PF≥1.2 AND Trades≥60 + top-3 ดิบ · commit `[tag] ORDER-007 done`
**หมายเหตุ:** ตัวไหนได้ 0 pass = Claude จะขึ้นทะเบียน DEAD-optimized ได้เลย (ปิดทะเบียนถาวร)

**ผล (Codex, Model 1; ไม่มี verdict):** XML ครบ **54 rows ต่อ symbol**. จำนวน pass ที่
`PF≥1.2 AND Trades≥60`: GBPUSD **5**, CADJPY **8**, USDCAD **5**, USDCHF **0**, AUDCAD **4**,
EURUSD **3**, NZDUSD **8**. Top-3 ดิบเรียง PF:

| Symbol | Pass | PF | Trades | EqDD% | StepATR | Direction | DistATR | BasketTP |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| GBPUSD | 51 | 3.836631 | 10 | 3.7881 | 1.4 | 2 | 3.0 | 250 |
| GBPUSD | 48 | 1.556006 | 154 | 7.1904 | 1.4 | 1 | 3.0 | 250 |
| GBPUSD | 39 | 1.408247 | 24 | 7.8940 | 1.4 | 2 | 1.4 | 250 |
| CADJPY | 48 | 1.917910 | 111 | 6.1713 | 1.4 | 1 | 3.0 | 250 |
| CADJPY | 26 | 1.893090 | 77 | 3.7082 | 3.0 | 1 | 2.2 | 175 |
| CADJPY | 49 | 1.884789 | 89 | 4.9573 | 2.2 | 1 | 3.0 | 250 |
| USDCAD | 26 | 1.816617 | 67 | 3.6116 | 3.0 | 1 | 2.2 | 175 |
| USDCAD | 49 | 1.464543 | 58 | 7.7194 | 2.2 | 1 | 3.0 | 250 |
| USDCAD | 43 | 1.436047 | 63 | 7.2109 | 2.2 | 1 | 2.2 | 250 |
| USDCHF | 6 | 6.538944 | 17 | 1.5329 | 1.4 | 1 | 2.2 | 100 |
| USDCHF | 12 | 1.382475 | 18 | 2.6136 | 1.4 | 1 | 3.0 | 100 |
| USDCHF | 33 | 1.190101 | 217 | 8.9766 | 1.4 | 2 | 3.0 | 175 |
| AUDCAD | 49 | 3.585464 | 22 | 2.1369 | 2.2 | 1 | 3.0 | 250 |
| AUDCAD | 44 | 2.729776 | 13 | 1.6359 | 3.0 | 1 | 2.2 | 250 |
| AUDCAD | 25 | 2.139272 | 23 | 1.9222 | 2.2 | 1 | 2.2 | 175 |
| EURUSD | 15 | 1.974441 | 69 | 4.3918 | 1.4 | 2 | 3.0 | 100 |
| EURUSD | 41 | 1.304041 | 87 | 6.6240 | 3.0 | 2 | 1.4 | 250 |
| EURUSD | 16 | 1.232787 | 109 | 4.3717 | 2.2 | 2 | 3.0 | 100 |
| NZDUSD | 29 | 1.942635 | 76 | 3.4518 | 3.0 | 2 | 2.2 | 175 |
| NZDUSD | 52 | 1.536490 | 85 | 3.8178 | 2.2 | 2 | 3.0 | 250 |
| NZDUSD | 40 | 1.502905 | 70 | 4.7339 | 2.2 | 2 | 1.4 | 250 |

---

## ORDER-008 — Re-exam ศพเก่าที่ตายโดยไม่เคย optimize: EA_LNBREAK + NRBreakout (stage A: เตรียมข้อมูล) — `REVIEWED(Claude/Fable, 2026-07-04 — ranges APPROVED → ORDER-008B)` (role: Codex)

**Review (Claude/Fable):** ตาราง inputs ครบ ข้อเสนอ ranges สมเหตุสมผล (ATR-relative, freeze
execution/lot, เหตุผล causal ชัด) — **APPROVED ตามที่เสนอทุกค่า** · ไปต่อที่ ORDER-008B

**ทำไม (user rule 2026-07-03):** LNBREAK ถูกฆ่าจาก **M2 smoke + default params** (ผิดกฎ Model-2 ด้วย) ·
NRBreakout ตายจาก partial sweep — ทั้งคู่ไม่เคยได้ 54-pass probe ตามกติกาใหม่
**Stage A (order นี้ — ห้ามรัน backtest):**
1. หาไฟล์ source: `Glob D:\EA_Project\CURRENT_BUILD\TEMPLATE\*LNBREAK*` และ `*NRBreakout*` (ถ้าไม่เจอ ขยายไป `D:\EA_Project\**`)
2. ต่อ EA: extract รายชื่อ `input` ทั้งหมด (ชื่อ, ชนิด, default) → append เป็นตารางใต้ order นี้
3. เสนอ (เป็นข้อเสนอ ไม่ใช่ verdict): 3-4 params ที่น่า sweep ที่สุด + ช่วงค่า 3 ค่าต่อตัว ตามแบบ `Boss14_GridLog_GBPAUD_opt1.set` (ATR-relative ก่อน pip เสมอ)
**Acceptance:** ตาราง inputs ครบทั้ง 2 EA + ข้อเสนอ ranges · commit `[codex] ORDER-008A done` ·
Claude จะ approve ranges แล้วออก stage B (รัน probe) รอบหน้า

**ผล (Codex; stage A เท่านั้น ไม่ได้รัน backtest):** พบ source ทั้งสองไฟล์ที่
`D:\EA_Project\CURRENT_BUILD\TEMPLATE\EA_LNBREAK.mq5` และ
`D:\EA_Project\CURRENT_BUILD\TEMPLATE\(Boss)_NRBreakout_rev01.mq5`.

**EA_LNBREAK — inputs ครบ 23 รายการ**

| ชื่อ | ชนิด | default |
|---|---|---|
| `_g00_` | string | `-- [00] OPTIMIZER ----------------------` |
| `_00_OptimizeMode` | bool | `false` |
| `_g01_` | string | `-- [01] SESSION TIMES (server hrs) ----` |
| `_01_LondonStartHr` | int | `11` |
| `_01_LondonEndHr` | int | `15` |
| `_01_NyEndHr` | int | `23` |
| `_01_BreakBuf` | double | `0.3` |
| `_g03_` | string | `-- [03] FILTERS ------------------------` |
| `_03_UseEmaFilter` | bool | `true` |
| `_03_EmaPeriod` | int | `200` |
| `_03_ATRPeriod` | int | `14` |
| `_g02_` | string | `-- [02] SL / TP ------------------------` |
| `_02_SL_ATR_mult` | double | `2.0` |
| `_02_TP_ATR_mult` | double | `3.0` |
| `_g04_` | string | `-- [04] TRAIL --------------------------` |
| `_04_TrailATR` | double | `2.0` |
| `_g05_` | string | `-- [05] TRADE MGMT ---------------------` |
| `_05_FixedLot` | double | `0.01` |
| `_05_MaxSpreadPts` | int | `0` |
| `_05_OnlyOncePerDay` | bool | `true` |
| `_g06_` | string | `-- [06] SYSTEM -------------------------` |
| `_06_AllowLive` | bool | `false` |
| `_06_Magic` | int | `990110` |

**(Boss)_NRBreakout_rev01 — inputs ครบ 22 รายการ**

| ชื่อ | ชนิด | default |
|---|---|---|
| `_g00_` | string | `── [00] TESTER / OPTIMIZER ────────────────` |
| `_00_OptimizeMode` | bool | `false` |
| `_g01_` | string | `── [01] NR FILTER ─────────────────────────` |
| `_01_NrLookback` | int | `7` |
| `_01_NrMult` | double | `0.8` |
| `_01_EntryStartH` | int | `9` |
| `_01_TradeEndH` | int | `18` |
| `_01_CloseEod` | bool | `true` |
| `_01_BuyBreakHigh` | bool | `true` |
| `_01_SellBreakLow` | bool | `true` |
| `_g02_` | string | `── [02] SL / TP ───────────────────────────` |
| `_02_SlAtrMult` | double | `1.5` |
| `_02_TpAtrMult` | double | `3.0` |
| `_g03_` | string | `── [03] ATR ───────────────────────────────` |
| `_03_AtrPeriod` | int | `14` |
| `_g05_` | string | `── [05] TRADE MGMT ────────────────────────` |
| `_05_BuyOnly` | bool | `false` |
| `_05_LotSize` | double | `0.01` |
| `_g06_` | string | `── [06] SYSTEM ────────────────────────────` |
| `_06_Magic` | long | `990006` |
| `_06_Deviation` | ulong | `20` |
| `_06_AllowLive` | bool | `false` |

**ข้อเสนอ coarse sweep สำหรับ Claude approve (4 params × 3 ค่า = 81 passes ต่อ EA):** เลือกเฉพาะ
signal/exit ที่มี causal path; freeze lot, magic, execution และ session defaults. ใช้ ATR-relative ก่อน pip.

| EA | Parameter | ค่าที่เสนอ 3 ค่า | รูปแบบ `.set` | เหตุผล |
|---|---|---|---|---|
| LNBREAK | `_01_BreakBuf` | 0.0, 0.3, 0.6 | `0.3||0.0||0.3||0.6||Y` | ความเข้มของ range breakout แบบ ATR |
| LNBREAK | `_02_SL_ATR_mult` | 1.0, 2.0, 3.0 | `2.0||1.0||1.0||3.0||Y` | stop distance แบบ volatility-relative |
| LNBREAK | `_02_TP_ATR_mult` | 1.5, 3.0, 4.5 | `3.0||1.5||1.5||4.5||Y` | reward distance แบบ ATR |
| LNBREAK | `_04_TrailATR` | 0.0, 1.5, 3.0 | `1.5||0.0||1.5||3.0||Y` | เปรียบเทียบ off/medium/wide trail |
| NRBreakout | `_01_NrLookback` | 3, 7, 11 | `7||3||4||11||Y` | ความยาวฐาน daily compression |
| NRBreakout | `_01_NrMult` | 0.6, 0.8, 1.0 | `0.8||0.6||0.2||1.0||Y` | ความเข้ม narrow-range condition |
| NRBreakout | `_02_SlAtrMult` | 1.0, 2.0, 3.0 | `2.0||1.0||1.0||3.0||Y` | stop distance แบบ ATR |
| NRBreakout | `_02_TpAtrMult` | 1.5, 3.0, 4.5 | `3.0||1.5||1.5||4.5||Y` | reward distance แบบ ATR |

หมายเหตุข้อเสนอ: LNBREAK TP กับ trail มี interaction จึงควรอ่าน plateau เป็นกลุ่ม ไม่เลือก peak เดี่ยว;
NRBreakout freeze `_03_AtrPeriod=14` เพื่อไม่เพิ่ม dimension และ freeze session hours จน signal shape ผ่านก่อน.

---

## ORDER-009 — MC บน OOS reports 5 ตัว (= PROPOSAL-A ของ ZCode, APPROVED แบบ option a) — `OPEN` (role: ZCode)

**Approve (Claude/Fable, 2026-07-04):** ตามที่ ZCode เสนอ ทั้ง 5 ตัว (คำสั่ง 5 บรรทัดใน PROPOSAL-A
ด้านล่าง) + **flag "thin-n" กับ GBPJPY/EURJPY/AUDNZD (n<50)** — MC พวกนั้นอ่านเป็น indicative
เท่านั้น · proposal เขียนดีมาก (มี caveat ครบ) — นี่คือตัวอย่าง proposal ที่ถูกต้อง
**Acceptance:** ตาราง DD median/95th/worst + ruin% + P(loss) ต่อ symbol · commit `[zcode] ORDER-009 done`

**ผล:** _(รอ)_

---

## ORDER-010 — full-window confirm + year-split ของ 3 ตัวที่ผ่าน OOS — `OPEN` (role: ZCode/Codex)

**ทำไม:** USDJPY/AUDNZD/EURJPY ผ่าน fresh-start OOS แล้ว — ขั้นสุดท้ายก่อน Claude ตัดสิน demo:
รัน ISpick set บน window เต็ม (2023.01–2026.07) แล้วแตกปี เพื่อยืนยันไม่มีปีเน่าซ่อนอยู่
```powershell
# แทน <SYM> ด้วย USDJPY, AUDNZD, EURJPY
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_<SYM>_ISpick.set' -ReportName BOSS14_<SYM>_FULL_ISPICK_M1
# แล้วต่อท้ายทุกตัว:
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\report_year_split.py D:\EA_LAB\_mt5_auto\reports\BOSS14_<SYM>_FULL_ISPICK_M1.htm
```
**Acceptance:** ต่อ symbol: ผล year-split ทุกบรรทัด (FULL + รายปี) append ดิบ · commit `[tag] ORDER-010 done`
**ห้าม:** verdict — Claude ตัดสิน demo-list ตอน review

**ผล:** _(รอ)_

---

## ORDER-008B — รัน probe 81-pass ของ LNBREAK (GBPUSD H1) + NRBreakout (XAUUSD H1) — `OPEN` (role: Codex)

**ตาม ranges ที่ approve ใน ORDER-008A:** สร้าง opt set 2 ไฟล์ (`sets_opt\LNBREAK_opt1.set`,
`sets_opt\NRBreakout_opt1.set` — วางที่ `D:\EA_LAB\ea_template\sets\`) ใส่ค่า default ทุก input ตามตาราง
008A + บรรทัด optimize `||start||step||stop||Y` ตามที่ approve (4 params × 3 ค่า) · แล้วรัน:
```powershell
# LNBREAK บน GBPUSD H1 (best cell เดิม 1.09) · NRBreakout บน XAUUSD H1 (home cell เดิม)
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert '<EA_NAME>' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Optimization 1 -SetFile '<SET>' -ReportName <EA>_OPT1 -TimeoutSec 21600
```
หมายเหตุ: EA ทั้งสองต้อง compile+deploy อยู่ใน terminal ก่อน (เช็ค `<DataDir>\MQL5\Experts\` — ถ้าไม่มี
.ex5 ให้ compile จาก source ใน D:\EA_Project ด้วย metaeditor CLI ตามแบบ deploy.ps1) · `_00_OptimizeMode=true` ถ้า EA มี tester-gate
**Acceptance:** XML 81 rows × 2 · จำนวน pass PF≥1.2 & Trades≥60 + top-5 ดิบ ต่อ EA · commit `[codex] ORDER-008B done`

**ผล:** _(รอ)_

---

## เสนอ order ใหม่ (agent อื่นเขียนข้อเสนอได้ที่นี่ — Claude เป็นคนยกเป็น order จริง)

### 🟣 PROPOSAL-A (ZCode, 2026-07-04) — ✅ APPROVED → ยกเป็น ORDER-009 แล้ว (เก็บไว้เป็น reference)

**บริบท:** ตอนนี้ ORDER-005 (IS-opt) + ORDER-006 (fresh-start OOS) + ORDER-007 (probe 7) = DONE
ทั้งหมด รอ Claude review. แต่ ORDER-006 ผลิตแค่ผล OOS (PF/Net/EqDD จาก single equity path)
**ยังไม่มี Monte Carlo** — ขณะที่ ORDER-004 (GBPAUD) ใช้ MC เป็นหลักฐานประกอบ verdict
(DD 95th/worst/ruin). pipeline เดียวกันควรมี MC ครบทุก OOS-passing candidate ก่อน Claude
ตัดสิน ไม่งั้น Claude ต้องสั่งซ้ำรอบ review.

**OOS ผลที่ ORDER-006 รายงาน (จาก report ครบบน disk):**
AUDNZD 42t PF 3.02 ✅ · EURJPY 23t PF 2.15 ✅ · USDJPY 106t PF 2.77 ✅ ·
GBPJPY 23t PF 1.12 (borderline) · EURCAD 140t PF 0.67 (fail)

**งานที่ขอทำ (role ZCode แท้ — รัน `mt5_montecarlo.py` ที่มีอยู่ ไม่สร้าง/แก้ source):**
```powershell
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDNZD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURJPY_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_EURCAD_OOS_M1.htm  --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_USDJPY_OOS_M1.htm  --deposit 10000 --iters 5000
```
**Acceptance (ถ้า Claude approve):** ต่อ symbol append ตาราง `trades_used / DD median / 95th /
worst / ruin% / P(loss)` · commit `[zcode] PROPOSAL-A done`
**ข้อห้าม (ตาม role):** ไม่ตีความผล, ไม่ให้ verdict, ไม่เลือก candidate — รายงานดิบเท่านั้น.
**caveat ที่จะรายงานควบ (จาก docstring ตัว script เอง):** trade-reshuffle MC = optimistic
lower bound (grid ขาขาด cluster → real adverse อาจแย่กว่า reshuffle ใดๆ) — treat 95th/worst
เป็น "at least this bad" ไม่ใช่ ceiling.

**⚠️ ข้อควรพิจารณาของ Claude ก่อน approve:**
- OOS report บางตัวมีเทรดน้อย (GBPJPY 23t / EURJPY 23t / AUDNZD 42t) — MC บน n<30 noise มาก
  (ORDER-004 เคยเลี่ยงปัญหานี้โดยรัน MC บน full report 88t แทน OOS 23t). ทางเลือกสำหรับ Claude:
  (a) approve ทั้ง 5 + flag ว่า thin, (b) ขอให้ ZCode รัน MC บน full-window report เพิ่มเทียบ,
  (c) รันเฉพาะ USDJPY(106t)/EURCAD(140t) ที่ n เพียงพอก่อน.
- หาก Claude ตั้งใจ review ORDER-005/006 เองโดยไม่ใช้ MC (ใช้แค่ PF+regime-read) ก็ปฏิเสธ
  proposal นี้ได้เลย — ZCode จะไม่ทำ.
