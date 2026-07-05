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

## ORDER-009 — MC บน OOS reports 5 ตัว — `SKIPPED (superseded — Claude รัน MC บน full reports ประกอบ verdict ใน ORDER-010 แล้ว)` (role: ZCode)

**Approve (Claude/Fable, 2026-07-04):** ตามที่ ZCode เสนอ ทั้ง 5 ตัว (คำสั่ง 5 บรรทัดใน PROPOSAL-A
ด้านล่าง) + **flag "thin-n" กับ GBPJPY/EURJPY/AUDNZD (n<50)** — MC พวกนั้นอ่านเป็น indicative
เท่านั้น · proposal เขียนดีมาก (มี caveat ครบ) — นี่คือตัวอย่าง proposal ที่ถูกต้อง
**Acceptance:** ตาราง DD median/95th/worst + ruin% + P(loss) ต่อ symbol · commit `[zcode] ORDER-009 done`

**ผล:** _(รอ)_

---

## ORDER-010 — full-window confirm + year-split ของ 3 ตัวที่ผ่าน OOS — `REVIEWED(Claude/Fable, 2026-07-04 — Claude รันเองหลัง Codex ติด sandbox)` (role: ZCode/Codex)

**ผล + VERDICT สุดท้าย (Claude/Fable, 2026-07-04): 🎉 ทั้ง 3 ตัว = DEMO (Boss_14 cohort #1)**
- **AUDNZD** (1.4/BUY/1.4/175, magic 990202): full 1.56/195t **ทุกปีบวก 1.36/1.28/1.64/2.31 เทรดสม่ำเสมอทุกปี** · OOS 3.02 · MC worst 6.45% — สม่ำเสมอสุดของ family
- **EURJPY** (2.2/BUY/1.4/250, magic 990203): full 2.49/114t ทุกปีบวก (2.05/2.89/3.65/1.91) · OOS 2.15 · MC worst 6.22%
- **USDJPY** (1.4/BUY/3.0/100, magic 990201): full 1.51/138t ไม่มีปีลบ · OOS fresh-start 2.77/106t · MC worst 8.89% · ⚠️ trait: chained run dormant 2025 (เทรดกระจุก 2023) — fresh deploy จะ arm ใหม่เหมือน OOS ที่ active
- **Caveat พอร์ต:** USDJPY+EURJPY = short-JPY ทั้งคู่ (corr คาดสูง) → กฎ user: ลด lot ไม่ตัด — demo จะวัด corr จริง · sizing demo = 0.25x เดิม (0.10 lot — วัดพฤติกรรม ไม่ใช่ผลตอบแทน; resize ตอน promote live)
- Demo sets: `Boss14_GridLog_{USDJPY,AUDNZD,EURJPY}_DEMO.set` · MC ที่ Claude รันแทน ORDER-009 (full reports 5000 iters) — **ORDER-009 → SKIPPED (superseded)**

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

**ผล (Codex):**
- claimed 2026-07-04 09:10
- attempted first required run:
  `powershell -ExecutionPolicy Bypass -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol USDJPY -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_USDJPY_ISpick.set' -ReportName BOSS14_USDJPY_FULL_ISPICK_M1`
- raw launcher output:
  `launch: EALabTpl\Boss_14_GridLog | USDJPY H1 | 2023.01.01..2026.07.01 | set=Boss14_GridLog_USDJPY_ISpick.set`
  `NO REPORT (exited=True). Check EA name / symbol history / login.`
- filesystem check after run: no `BOSS14_USDJPY_FULL_ISPICK_M1*` file under terminal data dir and no report under `D:\EA_LAB\_mt5_auto\reports`
- question for Claude/user: should Codex use an alternate MT5 report collector/path for full-window runs, or leave `ORDER-010` blocked until the launcher is fixed?

---

## ORDER-008B — probe ศพเก่า — `REVIEWED(Claude: ❌ LNBREAK = DEAD-optimized ของจริง (0/81, best 1.048) — กฎ re-exam ครบวงจร: การฆ่าเดิมถูก validate แล้ว ปิดถาวร · NRBreakout = 3/81 qualifying → ยัง PARKED-thin, best-pass ได้ OOS check ราคาถูกใน ORDER-016 · 👏 oc-btest จับ gotcha ใหม่เอง: MT5 auto-sweep bool inputs (2592 rows!) → ต้อง lock ||N ทุก input ที่ไม่ sweep — เข้ากติกาแล้ว)` (role: Codex)

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

**ผล (Codex):**
- claimed 2026-07-04 09:07
- created `D:\EA_LAB\ea_template\sets\LNBREAK_opt1.set`
- created `D:\EA_LAB\ea_template\sets\NRBreakout_opt1.set`
- attempted command:
  `powershell -ExecutionPolicy Bypass -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EA_LNBREAK' -Symbol GBPUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\LNBREAK_opt1.set' -ReportName LNBREAK_OPT1 -TimeoutSec 21600`
- raw launcher output:
  `OPTIMIZE: EA_LNBREAK | GBPUSD H1 | 2023.01.01..2026.07.01 | mode=1`
  `NO XML (exited=True). If the test ran but produced no .xml, the optimization report may export differently on this build. Check the LNBREAK_OPT1 files in C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355 and the Tester logs.`
- filesystem check after run: no `LNBREAK_OPT1*` file under terminal data dir and no `LNBREAK_OPT1.xml` under `D:\EA_LAB\_mt5_auto\optimizations`
- question for Claude/user: should Codex use an alternate MT5 optimization export path/collector for this order, or leave `ORDER-008B` blocked until the launcher is fixed?

**ผลต่อ (oc-btest, Model 1, 2026-07-04):**
- confirmed deployed `.ex5` files before run:
  - `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\EA_LNBREAK.ex5`
  - `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\Boss_NRBreakout_rev01.ex5`
- LNBREAK command succeeded:
  `powershell -ExecutionPolicy Bypass -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EA_LNBREAK' -Symbol GBPUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\LNBREAK_opt1.set' -ReportName LNBREAK_OPT1 -TimeoutSec 21600`
- NRBreakout first run produced XML but **2592 rows** because MT5 carried optimizer flags for non-target bool inputs. Updated `D:\EA_LAB\ea_template\sets\NRBreakout_opt1.set` to explicitly lock non-target inputs with `||...||N`, then reran:
  `powershell -ExecutionPolicy Bypass -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'Boss_NRBreakout_rev01' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\NRBreakout_opt1.set' -ReportName NRBreakout_OPT1 -TimeoutSec 21600`
- optimizer XML outputs:
  - `D:\EA_LAB\_mt5_auto\optimizations\LNBREAK_OPT1.xml` — **81 rows**
  - `D:\EA_LAB\_mt5_auto\optimizations\NRBreakout_OPT1.xml` — **81 rows**
- qualifying pass count (`PF>=1.2 AND Trades>=60`):
  - LNBREAK: **0**
  - NRBreakout: **3**

Top-5 raw rows by Profit Factor:

| EA | Pass | PF | Trades | Profit | EqDD% | Params |
|---|---:|---:|---:|---:|---:|---|
| LNBREAK | 67 | 1.047911 | 490 | 49.18 | 0.5974 | `_01_BreakBuf=0.3`, `_02_SL_ATR_mult=2`, `_02_TP_ATR_mult=3.0`, `_04_TrailATR=3.0` |
| LNBREAK | 13 | 1.047911 | 490 | 49.18 | 0.5974 | `_01_BreakBuf=0.3`, `_02_SL_ATR_mult=2`, `_02_TP_ATR_mult=3.0`, `_04_TrailATR=0` |
| LNBREAK | 76 | 1.040545 | 434 | 43.41 | 0.7708 | `_01_BreakBuf=0.3`, `_02_SL_ATR_mult=2`, `_02_TP_ATR_mult=4.5`, `_04_TrailATR=3.0` |
| LNBREAK | 22 | 1.040545 | 434 | 43.41 | 0.7708 | `_01_BreakBuf=0.3`, `_02_SL_ATR_mult=2`, `_02_TP_ATR_mult=4.5`, `_04_TrailATR=0` |
| LNBREAK | 68 | 1.037988 | 448 | 36.38 | 0.5978 | `_01_BreakBuf=0.6`, `_02_SL_ATR_mult=2`, `_02_TP_ATR_mult=3.0`, `_04_TrailATR=3.0` |
| NRBreakout | 10 | 1.314252 | 88 | 117.48 | 1.8409 | `_01_NrLookback=7`, `_01_NrMult=0.6`, `_02_SlAtrMult=2`, `_02_TpAtrMult=1.5` |
| NRBreakout | 1 | 1.222801 | 88 | 67.60 | 1.3719 | `_01_NrLookback=7`, `_01_NrMult=0.6`, `_02_SlAtrMult=1`, `_02_TpAtrMult=1.5` |
| NRBreakout | 19 | 1.210523 | 88 | 90.47 | 2.0930 | `_01_NrLookback=7`, `_01_NrMult=0.6`, `_02_SlAtrMult=3`, `_02_TpAtrMult=1.5` |
| NRBreakout | 60 | 1.195560 | 315 | 303.39 | 1.3246 | `_01_NrLookback=3`, `_01_NrMult=1.0`, `_02_SlAtrMult=1`, `_02_TpAtrMult=4.5` |
| NRBreakout | 59 | 1.190660 | 222 | 205.35 | 1.3433 | `_01_NrLookback=11`, `_01_NrMult=0.8`, `_02_SlAtrMult=1`, `_02_TpAtrMult=4.5` |

---

## ORDER-011 — A/B harness — `REVIEWED(Claude: ✅ harness ACCEPTED ใช้งานได้จริง (+รองรับ -Portable) · ข้อมูล A/B แรก: Rec81 บน Boss_11 base ขาดทุน → net ดีขึ้น +$110 แต่ PF ยัง <1 และ DD แย่ลง +130 = ยังสรุปไม่ได้ (เอา recovery ไปแปะ strategy ที่แพ้ = วัดอะไรไม่ได้) · Phase-2 จริงต้อง A/B บน config ที่ชนะ เช่น demo cohort · หมายเหตุ: base set ที่ใช้ไม่ใช่ config regression (480t vs 168t) — เทียบภายในคู่ยัง valid)` (role: oc-dev + oc-btest)

**ทำไม:** โหมด Recovery 81/82/83 + HEDGE_LOCK ใน Boss V2 ยังไม่เคยถูก backtest — Phase 2 ต้องการ
เครื่องมือเทียบ "EA เดิม vs EA เดิม+เปิดโหมด" อย่างเป็นระบบ

**Spec:** สร้าง `D:\EA_LAB\scripts\ab_mode_test.ps1` (ตามแบบ mt5_run.ps1/tpl_regression.ps1):
- Params: `-Expert`, `-Symbol`, `-Period`, `-FromDate`, `-ToDate`, `-BaseSet` (path), `-Overrides` (เช่น `"RecoveryMode=81;_8_RecMult=1.3"`), `-Label`
- ทำงาน: รัน 2 backtests (base และ base+overrides, Model 1) → parse report ทั้งคู่ → พิมพ์ตารางเทียบ
  net / PF / trades / eqDD% / balDD% + delta ต่อคอลัมน์ → เขียน CSV ต่อท้าย `_mt5_auto\ab_results.csv`
- ห้ามแตะ core code · reuse parsing pattern จาก tpl_regression.ps1
**Acceptance test:** รันจริง 1 คู่: Boss_11_GridTrend XAUUSD H1 2024.01–2024.07 M1, base = smoke set
ของ regression, overrides `RecoveryMode=81` → append ตารางผลใต้ order นี้ · commit `[codex] ORDER-011 done`
**ห้าม:** ตีความว่าโหมดดี/แย่ — Claude อ่านผลเอง

**ผล (Codex):**
- claimed 2026-07-04 09:12
- created `D:\EA_LAB\scripts\ab_mode_test.ps1`
- created `D:\EA_LAB\ea_template\sets\Boss11_regression_smoke.set`
- acceptance command:
  `powershell -ExecutionPolicy Bypass -File D:\EA_LAB\scripts\ab_mode_test.ps1 -Expert 'EALabTpl\Boss_11_GridTrend' -Symbol XAUUSD -Period H1 -FromDate 2024.01.01 -ToDate 2024.07.01 -BaseSet 'D:\EA_LAB\ea_template\sets\Boss11_regression_smoke.set' -Overrides 'RecoveryMode=81' -Label 'boss11_rec81'`
- raw output:
  `>> base run`
  `Base report not produced. Raw launcher output:`
  `launch: EALabTpl\Boss_11_GridTrend | XAUUSD H1 | 2024.01.01..2024.07.01 | set=boss11_rec81_base.set`
  `NO REPORT (exited=True). Check EA name / symbol history / login.`
- question for Claude/user: should Codex keep this new harness and wait for the MT5 report path/collector to be fixed, or should Codex switch the harness to a different report collection mechanism?

**ผล (oc-dev, MT5 เลน 2 `D:\Meta 5b`, 2026-07-04):**
- updated `D:\EA_LAB\scripts\ab_mode_test.ps1` to accept `-Portable` and pass it through to `mt5_run.ps1` for both base and variant runs.
- acceptance command:
  `powershell -ExecutionPolicy Bypass -File D:\EA_LAB\scripts\ab_mode_test.ps1 -Expert 'EALabTpl\Boss_11_GridTrend' -Symbol XAUUSD -Period H1 -FromDate 2024.01.01 -ToDate 2024.07.01 -BaseSet 'D:\EA_LAB\ea_template\sets\Boss11_regression_smoke.set' -Overrides 'RecoveryMode=81' -Label 'boss11_rec81' -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable`
- raw A/B stats (Model 1):

| Case | Net | PF | Trades | EqDD | BalDD | Delta net | Delta PF | Delta trades | Delta EqDD | Delta BalDD |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| base | -356.44 | 0.89 | 480 | 637.43 (6.21%) | 589.63 (5.76%) |  |  |  |  |  |
| base+RecoveryMode=81 | -246.25 | 0.93 | 550 | 768.06 (7.32%) | 719.70 (6.88%) | +110.19 | +0.04 | +70.00 | +130.63 | +130.07 |

- reports:
  - `D:\EA_LAB\_mt5_auto\reports\AB_boss11_rec81_BASE.htm`
  - `D:\EA_LAB\_mt5_auto\reports\AB_boss11_rec81_VAR.htm`
- generated set files:
  - `D:\EA_LAB\_mt5_auto\ab_sets\boss11_rec81_base.set`
  - `D:\EA_LAB\_mt5_auto\ab_sets\boss11_rec81_variant.set`
- CSV appended: `D:\EA_LAB\_mt5_auto\ab_results.csv`

---

## 📢 NOTICE ถึง Codex/ZCode (Claude, 2026-07-04 ~10:00) — เรื่อง MT5 BLOCKED ทั้ง 3 orders

อาการ NO REPORT ของ ORDER-010/008B/011: terminal log ไม่มี entry ช่วง 09:07-09:12 เลย =
**terminal64 ไม่เคยถูก start** — ไม่ใช่ launcher พัง (คำสั่งเดียวกันเคยผ่านตอน 00:08-00:17)
สงสัย sandbox ของ Codex session รอบเช้าบล็อกการ spawn GUI process · Claude กำลัง rerun
USDJPY ตัวเดียวกันจาก shell ปกติเพื่อพิสูจน์ · **ระหว่างนี้:** Codex/ZCode ทำได้เฉพาะ order ที่
ไม่ใช้ MT5 (ORDER-009 = python ล้วน ✅, ORDER-012/013 ด้านล่าง ✅) · ห้าม retry MT5 order
จนกว่า Claude จะปลด BLOCKED · ถ้า Codex จะรัน MT5 อีกครั้ง ให้รันด้วย approval mode ที่อนุญาต
spawn process (เหมือน session เที่ยงคืนที่ผ่าน)

---

## ═══ TREASURE-TRIAGE series (กอง D:\Forex\10_EA_PROJECTS\2. wait for test — 6,843 unique) ═══
> Inventory เสร็จ: `D:\EA_LAB\_triage\inventory.csv` (8,857 แถว; คอลัมน์ dup_of ≠ ว่าง = ไฟล์ซ้ำ ข้ามได้)
> เป้าจริง: **ขุดกลไก/ไอเดียเข้าแม่พิมพ์** (เส้นทาง Zeus→Boss_14) ไม่ใช่หา EA พร้อม deploy
> ชุดนี้ไม่ใช้ MT5 → ทำได้ทันทีแม้ MT5 ติด BLOCKED

## ORDER-012 — อ่าน EA source ~98 ไฟล์ → ตาราง triage — `REVIEWED(Claude: งานครบ 88/88 ✅ แต่เกณฑ์ Y หลวม (61/88 รวม grid เพียบ) — Claude จะคัดจริงจาก momentum 13 + breakout 7 ก่อน; novelty list เก็บไว้ session หน้า)` (role: Codex)

**Input:** แถว kind=`ea-src` ใน inventory.csv (ข้ามแถวที่ dup_of ไม่ว่าง) — path เต็ม = `D:\Forex\10_EA_PROJECTS\2. wait for test\<path>`
**ต่อไฟล์ 1 แถวลง `D:\EA_LAB\_triage\ea_src_triage.csv`:**
`file, lang, strategy_type(momentum/reversion/breakout/grid/scalper/news/unknown), entry_signal(เข้าไม้จากอะไร — "none" ถ้าไม่มี signal จริง), exit_mech, risk_mech(fixed/martingale/grid/pyramid), has_real_edge_candidate(Y/N — Y = มี entry signal จริงที่ไม่ใช่แค่ grid ถัวเฉลี่ย), novelty_note(กลไกที่ Boss V2/EA_CORE ยังไม่มี — เทียบ ea_template\DESIGN_V2.md; "-" ถ้าไม่มี)`
**วิธีอ่าน:** 75 ตัว flag grid → อ่านเร็ว ตอบแค่ "ใต้ grid มี signal จริงไหม + กลไกแปลกไหม" · ~23 ตัวที่เหลือ → อ่านละเอียด
**Acceptance:** CSV ครบทุก unique ea-src + สรุป: จำนวนต่อ strategy_type · รายชื่อ has_real_edge_candidate=Y · รายชื่อ novelty_note≠"-" · commit `[codex] ORDER-012 done`
**ห้าม:** ตัดสิน "ดี/ไม่ดี" (Claude คัด) · ห้ามแตก archive (user แตกครบแล้ว) · ห้ามลบ/ย้ายไฟล์ใดๆ ในกองนี้

**ผล (Codex):**
- created `D:\EA_LAB\_triage\ea_src_triage.csv`
- input rows after `kind=ea-src` and `dup_of` blank: **88 unique files** (not 98 after duplicate skip)
- CSV validation: **88/88 rows**, missing **0**, extra **0**
- strategy_type counts: breakout **7** · grid **31** · momentum **13** · news **1** · reversion **19** · scalper **4** · unknown **13**
- `has_real_edge_candidate=Y`: **61 files**
  - `(Oh) Arbitrage Super Profit V04.mq5`; `(Oh) CCI Currencies Strength ATR  Ranking Nearby  V09.mq5`; `(Oh) Elliott Wave 14 Correction Price Action v01.mq5`; `(oh) fibo gold v06.mq5`; `(OH) Grid Lot Dif Hedging EA V04.mq5`; `(oh) Master GRID ATR Accumulative Deduction -B V23.mq5`; `(oh) pun lot hedging v15.mq5`; `(Oh) ZZ EA V05A.mq5`
  - `(Oh) ZZ EA V05B.mq5`; `(oh)  Bot V00.mq5`; `(oh)  Partial Arbitage add on lossing V04.mq5`; `(OH) Price Action - Trend Line -Fibo -Martingale  V20.mq5`; `(OH) Recovery Hedging System with SL V05.mq5`; `Flexy The Dragon v2.7.mq4`; `MoonKinght MASA.mq4`; `XAUUSD M5 SUPER SCALPER ROBOT for MT4.mq4`
  - `EX52 - Close First Order and Only Profit Order  RV2.mq4`; `(OH)  Fibo Harmonic Pattern V03_01.mq5`; `AAA#IRSI SUMPIP LOT MARTINGLESEQUENCE.mq5`; `EX52 - )XAUUSD Mua  Mua   v1[Lock].mq5`; `V#IRSI SUMPIP LOT MARTINGLESEQUENCE.mq5`; `[189] - MGS[FastClose].mq5`; `Breakout Retest Pro EA Source Code (1).mq5`; `Thanos EA Source Code.mq5`
  - `(Niyombot B_3) Price Action ATR  Lot.D Group 3.mq5`; `(Niyombot) B2 Gold Deng M15 TLM.mq5`; `143 E4.7.4 v2.mq5`; `43.Fast Shot Arbitrage 6.6.68.mq5`; `BMA 5   27.5.68.mq5`; `EA GOLD CENTER V.2 Expried 11.04.2025.mq5`; `EA Golden Fighter V.2.2.mq5`; `EA Hunter Pro - Interstellar  ID.mq5`
  - `EX170 - Zone Trading Strategy.mq5`; `EX175 FastClose  By Natong V01.mq5`; `EX97 X HFT Gold Robot Scalping V3.9 Balance Relot ATR off cut loss.mq5`; `min CCI 2Currencies Strength Carry Trade Trailing .mq5`; `so cool  AV  order  unlimit mt5 FINAL.mq5`; `(Oh) Supply Demand indy V07B.mq4`; `AA_Supply Demand Zone22_3g91.mq4`; `EA News  COREJJ   27 Time filter .mq5`
  - `Melee com.mq4`; `ycp zigzag vs ema  v04.mq5`; `Dark_Gold_Full.mq5`; `GapFillRSI.mq5`; `TEMPO_EMA_MACD_Dashboard V.4.mq5`; `MACD Sample.mq4`; `Moving Average.mq4`; `XIMA_DASH.mq4`
  - `hft_ea(1).mq4`; `PatternFinding Correlation.mq4`; `T101 Basket Trader v2.2.mq4`; `AcceleratorBot_USDJPYH4.mq4`; `template.mq4`; `TrioDancer_4.4.5.mq4`; `AI SCALPER v1.1.mq4`; `FXCOREGOLD V9 MQ4.mq4`
  - `XPERT2.mq4`; `UniversalMACrossEA.mq4`; `UniversalMACrossEA_Martingale.mq4`; `icarus_4.73 2022july27 EMA (1).mq4`; `genie_rsi(1).mq4`
- `novelty_note != "-"`: **78 rows**; full mechanism notes are in `ea_src_triage.csv` (not duplicated here to keep the taskboard readable)
- verification commands run:
  - `. D:\EA_LAB\scripts\use_python.ps1; python - <inventory/triage validation script>`
  - validation checked row count, exact path match against `inventory.csv`, strategy counts, edge-candidate count, and novelty-note count
- no MT5 commands were run; no source files under `ea_template\core\*` were changed

---

## ORDER-013 — PDF skim 289 ไฟล์ → catalog — `REVIEWED(Claude: catalog ครบ 188/188 ✅ · strategy-book 49 + worth_deep_read 67 — คัดจริง session หน้า ไม่เร่ง)` (role: ZCode)

**Input:** แถว kind=`pdf` ใน inventory.csv (ข้าม dup) · ต่อไฟล์: ดูชื่อ+เนื้อหาช่วงต้นพอจำแนก →
เขียนแถวลง `D:\EA_LAB\_triage\pdf_catalog.csv`: `file, kb, category(strategy-book/ea-manual/broker-doc/course/junk/unknown), topic_hint(1 บรรทัด), worth_deep_read(Y/N — Y เฉพาะที่อธิบาย strategy ละเอียดพอสร้าง EA ได้)`
**Acceptance:** CSV ครบ + สรุปจำนวนต่อ category + รายชื่อ worth_deep_read=Y · commit `[zcode] ORDER-013 done`

**ผล (ZCode/operator):**
- created `D:\EA_LAB\_triage\pdf_catalog.csv`
- input rows after `kind=pdf` and `dup_of` blank: **188 unique PDFs** (not 289 after duplicate skip)
- CSV validation: exact columns `file,kb,category,topic_hint,worth_deep_read`; rows **188/188**; missing **0**; extra **0**; bad category **0**; bad Y/N **0**
- category counts: broker-doc **1** · course **20** · ea-manual **92** · junk **23** · strategy-book **49** · unknown **3**
- `worth_deep_read=Y`: **67 files**
  - `2025-06\6 ท่าไม้ตาย SMC.pdf`
  - `2025-11\Profit Lock ใน fxDreema” แบบเป็นคู่มือทีละขั้น 👇.pdf`
  - `.Forexbookthai\.EA\EA Simulator v2\Link download EA Simulator v2\Bonus\40 Simple and Complex Strategies.pdf`
  - `.Forexbookthai\.EA\Link Download EA+VPS set 6990-20241008T104328Z-001\Link Download EA+VPS set 6990\Bonus E-book\The Black Book of Secret Data\The Black Book (35).pdf`
  - `.Forexbookthai\.EA\Link Download EA+VPS set 6990-20241008T104328Z-001\Link Download EA+VPS set 6990\Bonus E-book\เรียนฟอเร็กซ์ตามระดับชั้น\Forex เกรด11-Breakout(32).pdf`
  - `.Forexbookthai\.EA\Link Download EA+VPS set 6990-20241008T104328Z-001\Link Download EA+VPS set 6990\Bonus E-book\เรียนฟอเร็กซ์ตามระดับชั้น\Forex เกรด13-Advance(388).pdf`
  - `.Forexbookthai\.EA\Link Download EA+VPS set 6990-20241008T104328Z-001\Link Download EA+VPS set 6990\Bonus E-book\เรียนฟอเร็กซ์ตามระดับชั้น\Forex เกรด9-Harmonic+EW+Divergence(52).pdf`
  - `.Forexbookthai\.EA\Link Download EA+VPS set 6990-20241008T104328Z-001\Link Download EA+VPS set 6990\Bonus E-book\เรียนฟอเร็กซ์ตามระดับชั้น\Extra\Extra_Forex_Advance.pdf`
  - `.Forexbookthai\.EA\Link Download Grid V3\Bonus\แถมฟรีโปรแกรมบันทึกของเทรดเดอร์\AG Trading Strategies\วิธีใช้ AG Trading Strategies\แถม EMA Power\EMA Power - TH.pdf`
  - `.Forexbookthai\.EA\Money Management Toolbox\Link download MM Toolbox\Bonus 10 Indicators\Darvas Pointer\Forex Darvas Pointer Indicator.pdf`
  - `.Forexbookthai\.EA\Money Management Toolbox\Link download MM Toolbox\Bonus 10 Indicators\Ghost Scalper Strategy\Forex Ghost Scalper Strategy_watermark.pdf`
  - `.Forexbookthai\.Indicator\Indicator_Fibo Golden zone\Fibonacci Golden Zone Strategy.pdf`
  - `.Forexbookthai\.Indicator\Cluster Trader System (Indicator)\Cluster Trader System (Indicator)\Important price patterns in trading.pdf`
  - `.Forexbookthai\.Indicator\ลิงก์ดาวน์โหลด universal indy ea\ลิงก์ดาวน์โหลด universal indy ea\Bonus\Trading System\C15-Software\C15-Software\C-15 - System Manual.pdf`
  - `.Forexbookthai\EA\Link Download 5 Signals\FSK The Forex Sniper Killer\The-FSK-User-Manual-Book.pdf`
  - `2025-06\EABlackDragon_mt4_Sets_Manuals\Guide to trade with the trend using Black Dragon Indicator.pdf`
  - `Dashboard\Dashboard V3+Manual\ManualDashboard Fibo.pdf`
  - `Indicator and Template\Ultimate_Trend_Signals-Indicator-24April2023\Ultimate Trend Signals User Guide.pdf`
  - `Test EA ok3\Order block\Order Block Forex Robot MT4 Manual.pdf`
  - `wait for test\0 - MQ5\Galileo FX EA\How To Draw Supply Demand Level.pdf`
  - `wait for test\2- OK\Adaptive Trading EA\Adaptive Trading EA -Daily Volatility 7 English.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\02 Bonus Indicators\Magic Breakout System.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\01. Trend Trading Cloud\TrendTradingCloud-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\02. Pullback Factor\PullbackFactor-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\03. Laser Reversal\LaserReversal-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\04. Scientific Scalper\ScientificScalper-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\05. Trend Focus\TrendFocus-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\07. Logic Trendline\LogicTrendline-User-Guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\08. Linear Regression Channel\LinearRegressionChannel-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\09. AB=CD Dashboard\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\10. Better Trend Trading\BetterTrend-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\12. Mean Reversion\MeanReversionr-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\13. Swing Force\SwingForce-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\14. Pin Bar Setup\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\17. Master MACD\MasterMACD-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\19. Harmonic Pattern Indicator\HarmonicIndicator-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\20. Trigger Zones\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\21. Logic Day Trading\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\22. Engulfing Setup Indicator\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\24. Easy Wolfe Wave Indicator\EasyWolfeWave-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\27. Candlestick Pattern Indicator\CandlestickPatterns-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\28. Chart Pattern Indicator\PricePatterns-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\29. Divergence Solution Indicator\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\30. Currency Strength Solution Indicator\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\32. Scalping Solution Indicator\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\35. Easy Supply Demand Indicator\EasySupplyDemand-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\36. Pullback Solution Indicator\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\37. Hidden Divergence Pro Indicator\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\38. Pin Bar Dashboard Indicator\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\39. Head and Shoulders Indicator\guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\40. Pro Stochastic Divergence\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\41. Pro CCI Divergence\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\42. Pro RSI Divergence\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\43. Pro OsMA Divergence\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\44. MACD Bollinger Pro\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\45. Pure MACD Divergence\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\46. Dual Divergence\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\47. Weis Wave Pro\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\48. Trend Symphony\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\49. Versatile Super Trend\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\51. Versatile Bollinger Bands\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\01 Indicators\52. Better Oscillator\user-guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\02 Bonus Indicators\02 Easy Darvas Box\EasyDarvasBox-UserGuide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\02 Bonus Indicators\05 Adaptive Stoploss Indicator\AdjustableStop-User-Guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\02 Bonus Indicators\06 Flex Pin Bar  Indicator\FlexPinBar-User-Guide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\02 Bonus Indicators\07 Solid Double Bar  Indicator\SolidDoublebar-Userguide.pdf`
  - `wait for test\31 dec 23\Indicator Vault - All Indicators (incl. Bonus Indicators)\03 Super Bonus - Dashboards\06 Reversal Dashboard\guide.pdf`
- verification command run: `. D:\EA_LAB\scripts\use_python.ps1; python - <inventory/pdf_catalog validation script>`
- no MT5 commands were run; no source files were changed

---

## ORDER-015 — pipeline batch #2 — `REVIEWED(Claude: 🥇 AUDCAD OOS 4.30/41t = CANDIDATE เด่น (AUD family อีกแล้ว!) · CADJPY 1.98/26t = CANDIDATE-thin · USDCAD 2.07/13t + EURUSD 2.35/18t(SELL) + NZDUSD 1.47/9t = OOS บางเกินตัดสิน (กฎ: <20t = ข้อมูลไม่พอ ไม่ใช่ fail) → รอ full-confirm · ❌ GBPUSD 0.61/59t = PARKED — GBP-pair ตัวที่ 2 ที่ fail OOS (pattern: กลไกนี้ไม่ถูกกับ GBP) → ทั้งหมดไป ORDER-016)` (role: oc-btest, เลน 2)

**Symbols (จาก ORDER-007 probe ที่มี life):** CADJPY, NZDUSD, GBPUSD, USDCAD, AUDCAD, EURUSD
**ขั้นตอนต่อ symbol (ทำทีละตัวจนจบทั้ง 6 — ทุกคำสั่งต่อท้าย `-Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable`):**
1. IS-opt: `mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2025.06.30 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPAUD_opt1.set' -ReportName BOSS14_OPT_<SYM>_IS -TimeoutSec 21600`
2. เลือก pass แบบ rule-based: **PF สูงสุดในกลุ่ม Trades≥50** จาก XML (ไม่มี → รายงาน "no qualifying pass" ข้าม symbol)
3. สร้าง set: copy `Boss14_GridLog_screen_small.set` → `Boss14_GridLog_<SYM>_ISpick.set` override 4 params (Step/Direction/Dist/TP)
4. Fresh-start OOS: `mt5_run.ps1 ... -FromDate 2025.07.01 -ToDate 2026.07.01 -Model 1 -SetFile <ISpick> -ReportName BOSS14_<SYM>_OOS_M1`
**Acceptance:** ตารางต่อ symbol: pass ที่เลือก (4 params) | OOS trades/PF/net/eqDD% · commit `[oc-btest] ORDER-015 done`
**Progress:** รายงาน Telegram ทุกรอบ poll (~5-10 นาที) ตาม brief · **ห้าม:** verdict — Claude ตัดสิน

**ผล (oc-btest, Model 1, MT5 เลน 2 `D:\Meta 5b`, 2026-07-04):**

Optimizer XML verification: all 6 optimizer XML files have **54 rows**.
No `NO XML` / `NO REPORT` was encountered.

Rule-based selection: picked highest PF among optimizer passes with `Trades>=50`.

| Symbol | IS pass | StepATR | Direction | DistATR | BasketTP | OOS Trades | OOS PF | OOS Net | OOS EqDD% |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| CADJPY | 26 | 3.0 | 1 | 2.2 | 175 | 26 | 1.98 | +345.37 | 2.83 |
| NZDUSD | 29 | 3.0 | 2 | 2.2 | 175 | 9 | 1.47 | +81.91 | 1.07 |
| GBPUSD | 48 | 1.4 | 1 | 3.0 | 250 | 59 | 0.61 | -611.75 | 9.65 |
| USDCAD | 26 | 3.0 | 1 | 2.2 | 175 | 13 | 2.07 | +204.06 | 1.84 |
| AUDCAD | 36 | 1.4 | 1 | 1.4 | 250 | 41 | 4.30 | +923.50 | 2.19 |
| EURUSD | 15 | 1.4 | 2 | 3.0 | 100 | 18 | 2.35 | +195.98 | 1.55 |

Files:
- Optimizer XML:
  - `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_CADJPY_IS.xml`
  - `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_NZDUSD_IS.xml`
  - `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_GBPUSD_IS.xml`
  - `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_USDCAD_IS.xml`
  - `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_AUDCAD_IS.xml`
  - `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_EURUSD_IS.xml`
- Picked sets:
  - `D:\EA_LAB\ea_template\sets\Boss14_GridLog_CADJPY_ISpick.set`
  - `D:\EA_LAB\ea_template\sets\Boss14_GridLog_NZDUSD_ISpick.set`
  - `D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPUSD_ISpick.set`
  - `D:\EA_LAB\ea_template\sets\Boss14_GridLog_USDCAD_ISpick.set`
  - `D:\EA_LAB\ea_template\sets\Boss14_GridLog_AUDCAD_ISpick.set`
  - `D:\EA_LAB\ea_template\sets\Boss14_GridLog_EURUSD_ISpick.set`
- OOS reports:
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_CADJPY_OOS_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_NZDUSD_OOS_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_GBPUSD_OOS_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_USDCAD_OOS_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDCAD_OOS_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_EURUSD_OOS_M1.htm`
- Machine-readable summary: `D:\EA_LAB\_mt5_auto\ORDER015_results.json`

---

## ORDER-016 — cohort-2 pipeline: full-confirm + year-split + MC ของ 5 ตัวจาก batch #2 (+NRBreakout OOS) — `REVIEWED(Claude, 2026-07-04): cohort-2 verdict — DEMO 3 ตัว: 🥇 AUDCAD (ทุกปี≥1.01, OOS 4.30, MC clean) · CADJPY-thin (2026 = -\.60 บน 13t = flat ไม่ใช่ปีแพ้) · EURUSD-SELL-thin (ทุกปี≥1.47 — เพิ่ม SELL-side + non-AUD diversity) · WATCH: USDCAD (2023 = 0.85 ปีแพ้จริง) + NZDUSD (2025 = 0.88) — ตกเกณฑ์ no-losing-year · NRBreakout = PARKED-final (probe แฟร์แล้ว: ceiling ~1.31, OOS 20t marginal — ไม่ตายแต่ไม่คุ้ม slot เทียบ Boss_14 family; กลับมาดูเมื่อ bench แห้ง)`

**เป้า:** เดินด่านที่เหลือของ AUDCAD (นำ), CADJPY, USDCAD, EURUSD, NZDUSD — สูตรเดียวกับ cohort 1
**ขั้นตอน (ทุกคำสั่ง MT5 ต่อท้าย `-Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable`):**
1. ต่อ symbol (5 ตัว): full-window confirm `mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_<SYM>_ISpick.set' -ReportName BOSS14_<SYM>_FULL_ISPICK_M1`
2. แตกปี: `report_year_split.py` บนทุก report → append ผลดิบทุกบรรทัด
3. MC: `mt5_montecarlo.py <report> --deposit 10000 --iters 5000` → append DD median/95th/worst + ruin
4. NRBreakout: เลือก pass PF สูงสุดที่ Trades≥60 จาก `NRBreakout_OPT1.xml` → สร้าง set (base = `NRBreakout_opt1.set` ค่า default, override params ของ pass) → รัน OOS 2025.07-2026.07 XAUUSD H1 M1 → รายงาน trades/PF/net/eqDD
**Acceptance:** ต่อ symbol: year-split เต็ม + MC ครบ · NRBreakout: OOS 1 แถว · commit `[oc-btest] ORDER-016 done`
**Progress:** ping ทุกรอบ poll ตาม brief · **ห้าม:** verdict — Claude ตัดสิน cohort-2 demo-list เอง

**ผล (oc-btest, Model 1, MT5 เลน 2 `D:\Meta 5b`, 2026-07-04):**

No `NO REPORT` was encountered. Full-window reports completed for all 5 Boss14 symbols.

Full-window main MT5 stats:

| Symbol | Trades | PF | Net | EqDD% |
|---|---:|---:|---:|---:|
| AUDCAD | 146 | 1.88 | +1491.31 | 6.38 |
| CADJPY | 77 | 1.89 | +1010.21 | 3.71 |
| USDCAD | 67 | 1.82 | +753.95 | 3.61 |
| EURUSD | 69 | 1.97 | +669.10 | 4.39 |
| NZDUSD | 76 | 1.94 | +782.83 | 3.45 |

Year split (`scripts\report_year_split.py`, raw closed-deal balance stats):

| Symbol | Year | Trades | PF | Net | BalDD |
|---|---:|---:|---:|---:|---:|
| AUDCAD | FULL | 146 | 1.88 | +1491.31 | 4.06% |
| AUDCAD | 2023 | 55 | 1.27 | +216.73 | 4.06% |
| AUDCAD | 2024 | 41 | 1.01 | +7.29 | 2.45% |
| AUDCAD | 2025 | 25 | 5.63 | +435.64 | 0.66% |
| AUDCAD | 2026 | 25 | 4.91 | +831.65 | 1.23% |
| CADJPY | FULL | 77 | 1.89 | +1010.21 | 3.09% |
| CADJPY | 2023 | 44 | 1.97 | +611.37 | 1.68% |
| CADJPY | 2024 | 20 | 2.96 | +403.44 | 1.68% |
| CADJPY | 2026 | 13 | 0.98 | -4.60 | 2.16% |
| USDCAD | FULL | 67 | 1.82 | +753.95 | 2.55% |
| USDCAD | 2023 | 37 | 0.85 | -101.14 | 2.55% |
| USDCAD | 2024 | 29 | 3.14 | +558.17 | 1.11% |
| USDCAD | 2025 | 1 | inf | +296.92 | 0.00% |
| EURUSD | FULL | 69 | 1.97 | +669.10 | 2.98% |
| EURUSD | 2023 | 24 | 1.55 | +133.77 | 1.75% |
| EURUSD | 2024 | 25 | 4.91 | +368.74 | 0.43% |
| EURUSD | 2025 | 20 | 1.47 | +166.59 | 3.13% |
| NZDUSD | FULL | 76 | 1.94 | +782.83 | 2.18% |
| NZDUSD | 2023 | 42 | 2.11 | +549.35 | 2.18% |
| NZDUSD | 2024 | 2 | 1.00 | -0.10 | 0.31% |
| NZDUSD | 2025 | 18 | 0.88 | -28.99 | 1.73% |
| NZDUSD | 2026 | 14 | 5.10 | +262.57 | 0.64% |

Monte Carlo (`mt5_montecarlo.py --deposit 10000 --iters 5000`):

| Symbol | Trades used | Actual net | DD median | DD 95th | DD worst | Ruin | P(loss) |
|---|---:|---:|---:|---:|---:|---:|---:|
| AUDCAD | 146 | +1491.31 | 2.10% | 3.37% | 5.34% | 0.00% | 0.0% |
| CADJPY | 77 | +1010.21 | 2.07% | 3.31% | 5.41% | 0.00% | 0.0% |
| USDCAD | 67 | +753.95 | 2.01% | 3.23% | 5.31% | 0.00% | 0.0% |
| EURUSD | 69 | +669.10 | 1.57% | 2.51% | 4.01% | 0.00% | 0.0% |
| NZDUSD | 76 | +782.83 | 1.61% | 2.53% | 4.65% | 0.00% | 0.0% |

NRBreakout mechanical pick from `D:\EA_LAB\_mt5_auto\optimizations\NRBreakout_OPT1.xml`: highest PF with `Trades>=60` = pass 10.

| Pass | PF | Trades | Profit | EqDD% | _01_NrLookback | _01_NrMult | _02_SlAtrMult | _02_TpAtrMult |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 | 1.314252 | 88 | +117.48 | 1.8409 | 7 | 0.6 | 2 | 1.5 |

NRBreakout OOS (`Boss_NRBreakout_rev01`, XAUUSD H1, 2025.07.01..2026.07.01, Model 1):

| Report | Trades | PF | Net | EqDD% | History quality |
|---|---:|---:|---:|---:|---:|
| `NRBreakout_XAUUSD_OOS_P10_M1.htm` | 20 | 1.37 | +61.74 | 1.85 | 100% |

NRBreakout OOS year split:

| Year | Trades | PF | Net | BalDD |
|---:|---:|---:|---:|---:|
| FULL | 20 | 1.37 | +61.74 | 1.42% |
| 2025 | 12 | 0.36 | -78.08 | 0.99% |
| 2026 | 8 | 4.29 | +139.82 | 0.43% |

Files:
- Boss14 full reports:
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDCAD_FULL_ISPICK_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_CADJPY_FULL_ISPICK_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_USDCAD_FULL_ISPICK_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_EURUSD_FULL_ISPICK_M1.htm`
  - `D:\EA_LAB\_mt5_auto\reports\BOSS14_NZDUSD_FULL_ISPICK_M1.htm`
- NRBreakout set/report:
  - `D:\EA_LAB\ea_template\sets\NRBreakout_OPT1_p10_ISpick.set`
  - `D:\EA_LAB\_mt5_auto\reports\NRBreakout_XAUUSD_OOS_P10_M1.htm`

---

## ORDER-017 — Model-4 confirm cohort-2 (3 ตัว) + สร้าง DEMO sets — `DONE` (role: oc-btest)

**เป้า:** ด่านสุดท้ายก่อน demo ตามมาตรฐาน cohort-1 (scrutiny rule)
**ขั้นที่ 1 — DEMO sets (ทำก่อน):** copy `Boss14_GridLog_<SYM>_ISpick.set` → `Boss14_GridLog_<SYM>_DEMO.set`
สำหรับ AUDCAD, CADJPY, EURUSD · แก้ 2 ค่าในไฟล์ใหม่: `_0_Magic` = AUDCAD 990204 · CADJPY 990205 · EURUSD 990206 และ `_4_DdAdaptiveOn=false`
**ขั้นที่ 2 — Model 4 (⚠️ SERIAL เท่านั้น — เช็คว่าไม่มีอะไรรันอยู่ทั้งสองเลนก่อนเริ่ม, ใช้เลนหลัก default):**
`mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2024.01.01 -ToDate 2026.07.01 -Model 4 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_<SYM>_DEMO.set' -ReportName BOSS14_<SYM>_M4CONFIRM`
**Acceptance:** ต่อ symbol: trades/PF/net/eqDD + history quality% · commit `[oc-btest] ORDER-017 done`
**ห้าม:** verdict — Claude เทียบ M1 เอง

**ผล (oc-btest, Model 4 real ticks, เลนหลัก default `D:\Meta 5`, 2026-07-04):**

DEMO sets created before runs:
- `D:\EA_LAB\ea_template\sets\Boss14_GridLog_AUDCAD_DEMO.set` (`_0_Magic=990204`, `_4_DdAdaptiveOn=false`)
- `D:\EA_LAB\ea_template\sets\Boss14_GridLog_CADJPY_DEMO.set` (`_0_Magic=990205`, `_4_DdAdaptiveOn=false`)
- `D:\EA_LAB\ea_template\sets\Boss14_GridLog_EURUSD_DEMO.set` (`_0_Magic=990206`, `_4_DdAdaptiveOn=false`)

Reports:
- `D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDCAD_M4CONFIRM.htm`
- `D:\EA_LAB\_mt5_auto\reports\BOSS14_CADJPY_M4CONFIRM.htm`
- `D:\EA_LAB\_mt5_auto\reports\BOSS14_EURUSD_M4CONFIRM.htm`

Main stats (raw MT5 report):

| Symbol | Report period | History quality | Bars | Ticks | Trades | PF | Net | Equity DD maximal |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| AUDCAD | 2024.01.01..2026.07.01 | 99% real ticks | 15,528 | 79,917,764 | 52 | 2.79 | +1,017.65 | 340.90 (3.19%) |
| CADJPY | 2024.01.01..2026.07.01 | 99% real ticks | 15,528 | 88,536,745 | 11 | 6.25 | +468.57 | 204.50 (1.95%) |
| EURUSD | 2024.01.01..2026.07.01 | 100% real ticks | 15,528 | 53,291,853 | 126 | 1.52 | +705.88 | 460.49 (4.50%) |

---

## ORDER-018 — เติม EA_MASTER_INDEX.csv — `REVIEWED(Claude: ✅ 125 แถว 0 ซ้ำ — UNTESTED 88 · DEAD 17 · PARKED 7 · DEMO 6 · WATCH 4 · REJECT 3 — index สมบูรณ์ ขึ้น OneDrive แล้ว)`

**เป้า:** ตารางรวม filter EA ได้ทุกมิติ (user 2026-07-04) · Claude seed 17 แถวแรกแล้ว (Boss_14 family
+ ศพล่าสุด) — เติมส่วนที่เหลือ **ตาม checklist เข้ม ห้ามตีความเอง:**
1. **จาก `D:\EA_LAB\_triage\ea_src_triage.csv` (88 แถว):** ทุกแถว → 1 แถว index:
   name=ชื่อไฟล์ · origin=downloaded · file_path=path เต็ม · lang=จากนามสกุล · home_cell=- ·
   strategy=map จาก strategy_type เดิม · risk_mech=map จาก risk_mech เดิม (grid→grid, martingale→martingale,
   pyramid→pyramid, fixed→fixed) · status=UNTESTED · confidence=0 · best_result=- ·
   note=entry_signal จากคอลัมน์เดิม (ตัดให้ ≤60 ตัวอักษร) · next_action=- · detail_ref=_triage/ea_src_triage.csv
2. **จาก `D:\EA_LAB\EA_SCORECARD_AND_REGISTRY.md` PART 2 registry tables:** แถว EA ที่มี verdict
   ชัด (DEAD/PARKED/REJECT/LIVE/WATCH ใน cell) และยังไม่มีใน index → 1 แถว: กรอกเฉพาะข้อมูลที่
   ปรากฏใน cell ตรงๆ (ชื่อ, status, best_result จากตัวเลขใน cell, confidence จากดาว ★=1★★=2★★★=3) ·
   ช่องที่ไม่รู้ใส่ "-" — **ห้ามเดา strategy ถ้าตารางไม่ได้บอก**
**Acceptance:** CSV รวม ≥100 แถว ไม่มีแถวซ้ำ (name+home_cell unique) · ทุกแถวครบ 15 คอลัมน์ ·
สรุปจำนวนต่อ status + ต่อ strategy · commit `[oc-dev] ORDER-018 done`

**ผล (oc-dev, 2026-07-04):**

เติม `EA_MASTER_INDEX.csv` ตาม checklist:
- seed เดิม 17 แถวคงไว้
- เพิ่มจาก `_triage/ea_src_triage.csv` ครบ 88/88 แถว (`status=UNTESTED`, `confidence=0`, `home_cell=-`)
- เพิ่ม/เติมจาก `EA_SCORECARD_AND_REGISTRY.md` PART 2 เฉพาะแถว registry ที่ verdict cell ชี้ชัดเป็น DEAD/PARKED/REJECT/WATCH และยังไม่มีใน index

Validation:
- CSV data rows: **125** (>=100)
- duplicate `(name, home_cell)`: **0**
- bad 15-column rows: **0**
- triage source/index/missing: **88 / 88 / 0**

Status counts:
| status | count |
|---|---:|
| DEAD | 17 |
| DEMO | 6 |
| PARKED | 7 |
| REJECT | 3 |
| UNTESTED | 88 |
| WATCH | 4 |

Strategy counts:
| strategy | count |
|---|---:|
| - | 20 |
| breakout | 7 |
| breakout-arm | 13 |
| breakout-arm SELL | 2 |
| grid | 31 |
| momentum | 13 |
| news | 1 |
| NR-compression breakout | 1 |
| reversion | 19 |
| scalper | 4 |
| session-breakout | 1 |
| unknown | 13 |

---

## ORDER-019 — corr matrix ของ Boss_14 family (6 ตัว demo) — `REVIEWED(Claude/Fable, 2026-07-04 — พอร์ตกระจายตัวดี ไม่มีคู่ redundant)` (role: oc-btest, ไม่ใช้ MT5)

**Verdict (Claude/Fable):** ไม่มีคู่ไหน >0.60 (redundant) — พอร์ต 6 ตัวกระจายตัวดีเกินคาด (ตระกูล
เดียวกัน กลไกเดียวกัน แต่ symbol ต่างกันพอที่จะไม่ลงพร้อมกัน) มีแค่ **USDJPY-CADJPY = 0.57 (watch)**
→ ใช้กฎ user: **ลด lot ไม่ตัด** (ยังไม่ต้องทำอะไรตอนนี้ เพราะทั้งคู่ยัง 0.25x เท่ากันอยู่แล้ว —
resize เมื่อ promote/scale ค่อยลด USDJPY หรือ CADJPY ตัวใดตัวหนึ่งพิเศษ) · **caveat สำคัญ:** เซลล์
NA หลายจุด (โดยเฉพาะ EURUSD กับตัวอื่น) เพราะ shared months <4 — EURUSD demo history สั้นกว่าเพื่อน
→ ต้องรัน corr_monthly.py ซ้ำหลัง demo สะสมข้อมูลจริงไปสัก 2-3 เดือน อย่าเชื่อ NA=ปลอดภัย

**ทำไม:** คำถาม risk ใหญ่สุดตอนนี้ — 6 ตัวกลไกเดียวกัน (ซ้อน AUD/JPY/CAD) จะเจ๊งพร้อมกันไหม
**งาน:** ใช้ `D:\EA_LAB\_mt5_auto\corr_monthly.py` (มีอยู่แล้ว — อ่าน usage ในไฟล์) คำนวณ
pairwise monthly-return correlation จาก 6 full reports:
`BOSS14_{USDJPY,AUDNZD,EURJPY}_FULL_ISPICK_M1.htm` + `BOSS14_{AUDCAD,CADJPY,EURUSD}_FULL_ISPICK_M1.htm`
**Acceptance:** ตาราง 6×6 (ค่า corr 2 ตำแหน่ง) + list คู่ที่ >0.60 และ >0.40 · commit `[oc-btest] ORDER-019 done`
**ห้าม:** สรุปว่าต้องตัด/ลดตัวไหน — Claude ใช้กฎ corr→ลด lot เอง

**ผล (oc-btest, 2026-07-04; ไม่ใช้ MT5):**

ใช้ `D:\EA_LAB\_mt5_auto\corr_monthly.py` อ่าน closed-deal monthly net (`profit + commission + swap`)
จาก full reports และคำนวณ Pearson บนเดือนที่ทั้งคู่มีข้อมูลร่วมกัน (`NA` = shared months <4 ตาม guard ใน script).

Reports:
- `BOSS14_USDJPY_FULL_ISPICK_M1.htm`
- `BOSS14_AUDNZD_FULL_ISPICK_M1.htm`
- `BOSS14_EURJPY_FULL_ISPICK_M1.htm`
- `BOSS14_AUDCAD_FULL_ISPICK_M1.htm`
- `BOSS14_CADJPY_FULL_ISPICK_M1.htm`
- `BOSS14_EURUSD_FULL_ISPICK_M1.htm`

Monthly-return correlation matrix:

| Symbol | USDJPY | AUDNZD | EURJPY | AUDCAD | CADJPY | EURUSD |
|---|---:|---:|---:|---:|---:|---:|
| USDJPY | 1.00 | 0.10 | -0.03 | -0.11 | 0.57 | NA |
| AUDNZD | 0.10 | 1.00 | -0.33 | -0.03 | 0.28 | 0.29 |
| EURJPY | -0.03 | -0.33 | 1.00 | -0.16 | 0.05 | NA |
| AUDCAD | -0.11 | -0.03 | -0.16 | 1.00 | -0.19 | -0.23 |
| CADJPY | 0.57 | 0.28 | 0.05 | -0.19 | 1.00 | NA |
| EURUSD | NA | 0.29 | NA | -0.23 | NA | 1.00 |

Pairs with corr >0.60:
- none

Pairs with corr >0.40:
- USDJPY-CADJPY: 0.57 (shared months 10)

---

## ORDER-020 — ขุด SELL-side จาก optimizer XML ที่มีอยู่ (hunt queue #1, ฟรี — ไม่รันอะไรใหม่) — `REVIEWED(Claude/Fable, 2026-07-04 — 1 candidate ใหม่จริง (NZDUSD-SELL) → ORDER-023 · GBPAUD-SELL ตัดทิ้งด้วยเหตุผลเดิม (dormancy ทั้ง 2 ทิศ) · EURUSD-SELL/AUDCAD-SELL = ของเดิม/thin)` (role: oc-dev)

**Verdict (Claude/Fable):** 4 symbol เจอ SELL-side pass ที่ผ่านเกณฑ์ — แยกทีละตัว:
- **EURUSD** (6 rows) = ของเดิมที่ demo อยู่แล้ว (990206, pass 15/16/41 ตรงกับ set ที่ deploy) — ไม่ใช่ของใหม่
- **GBPAUD** (6 rows, pass 3/9 ซ้ำทั้ง full/IS/IS2) = **ตัดทิ้ง ไม่ทดสอบต่อ** — ORDER-001 review เคย
  ยืนยันแล้วว่า GBPAUD เข้า range แคบตั้งแต่กลาง 2025 ทำให้ **resting-stop ทั้ง BUY และ SELL ไม่โดน
  trigger เหมือนกัน** (มีแค่ pass 36/37 spacing แคบสุดที่ยังเทรด) — SELL side จะเจอ dormancy เดียวกัน
  กับที่ฆ่า GBPAUD-BUY ไปแล้วที่ ORDER-004 แน่ๆ ไม่ต้องเปลืองรอบทดสอบซ้ำ
- **AUDCAD** (1 row, thin, IS-only) = หลักฐานน้อยเกินจะตาม
- **NZDUSD** (16 rows) = **candidate ใหม่จริง — pass 29 สม่ำเสมอ 2 window** (full 1.94/76t · IS 2.03/55t,
  คนละ trade count แต่ PF ใกล้กันมาก = ไม่ใช่ fluke ของ window เดียว) ต่างจาก NZDUSD-BUY เดิมที่เป็น
  WATCH (ปีแพ้ 2025) — ทิศ SELL ยังไม่เคยผ่าน fresh-start OOS → **เข้าคิว ORDER-023**

**ทำไม:** EURUSD SELL ผ่านถึง demo → ฝั่ง SELL อาจมีของอีก และข้อมูลอยู่ในมือแล้ว
**งาน:** parse ทุกไฟล์ `D:\EA_LAB\_mt5_auto\optimizations\BOSS14_OPT_*.xml` (ทุก symbol ทุกรุ่น) →
รวมทุก pass ที่ `_14_Direction=2 AND PF>=1.2 AND Trades>=50` เป็นตารางเดียว (symbol, window(IS/full จากชื่อไฟล์), pass, PF, Trades, EqDD%, 4 params)
**Acceptance:** ตารางครบ + นับต่อ symbol · commit `[oc-dev] ORDER-020 done` · ห้าม verdict

**ผล (oc-dev, 2026-07-04):** parse XML เดิมเท่านั้น ไม่มี optimize/backtest ใหม่.

Summary:
| XML files parsed | Rows parsed | Matching rows |
|---:|---:|---:|
| 28 | 1512 | 29 |

นับต่อ symbol:
| Symbol | Rows |
|---|---:|
| AUDCAD | 1 |
| EURUSD | 6 |
| GBPAUD | 6 |
| NZDUSD | 16 |

ตารางทุก pass ที่ `_14_Direction=2 AND PF>=1.2 AND Trades>=50`:

| Symbol | Window | Pass | PF | Trades | EqDD% | _9_StepATRmult | _14_Direction | _14_DistAtrMult | _2_BasketTP_Money |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| AUDCAD | IS | 10 | 1.237610 | 86 | 4.8597 | 2.2 | 2 | 2.2 | 100 |
| EURUSD | full | 15 | 1.974441 | 69 | 4.3918 | 1.4 | 2 | 3.0 | 100 |
| EURUSD | full | 16 | 1.232787 | 109 | 4.3717 | 2.2 | 2 | 3.0 | 100 |
| EURUSD | full | 41 | 1.304041 | 87 | 6.6240 | 3.0 | 2 | 1.4 | 250 |
| EURUSD | IS | 15 | 1.974441 | 69 | 4.3918 | 1.4 | 2 | 3.0 | 100 |
| EURUSD | IS | 16 | 1.232787 | 109 | 4.3717 | 2.2 | 2 | 3.0 | 100 |
| EURUSD | IS | 41 | 1.304041 | 87 | 6.6240 | 3.0 | 2 | 1.4 | 250 |
| GBPAUD | full | 3 | 2.382883 | 64 | 3.9710 | 1.4 | 2 | 1.4 | 100 |
| GBPAUD | full | 9 | 1.473466 | 61 | 3.9710 | 1.4 | 2 | 2.2 | 100 |
| GBPAUD | IS | 3 | 2.382883 | 64 | 3.9710 | 1.4 | 2 | 1.4 | 100 |
| GBPAUD | IS | 9 | 1.473466 | 61 | 3.9710 | 1.4 | 2 | 2.2 | 100 |
| GBPAUD | IS2 | 3 | 2.382883 | 64 | 3.9710 | 1.4 | 2 | 1.4 | 100 |
| GBPAUD | IS2 | 9 | 1.473466 | 61 | 3.9710 | 1.4 | 2 | 2.2 | 100 |
| NZDUSD | full | 22 | 1.402031 | 150 | 5.4259 | 2.2 | 2 | 1.4 | 175 |
| NZDUSD | full | 23 | 1.263867 | 112 | 5.0322 | 3.0 | 2 | 1.4 | 175 |
| NZDUSD | full | 27 | 1.279945 | 228 | 6.6553 | 1.4 | 2 | 2.2 | 175 |
| NZDUSD | full | 29 | 1.942635 | 76 | 3.4518 | 3.0 | 2 | 2.2 | 175 |
| NZDUSD | full | 39 | 1.270020 | 84 | 6.6840 | 1.4 | 2 | 1.4 | 250 |
| NZDUSD | full | 40 | 1.502905 | 70 | 4.7339 | 2.2 | 2 | 1.4 | 250 |
| NZDUSD | full | 41 | 1.227236 | 51 | 6.7940 | 3.0 | 2 | 1.4 | 250 |
| NZDUSD | full | 46 | 1.321069 | 166 | 6.7875 | 2.2 | 2 | 2.2 | 250 |
| NZDUSD | full | 52 | 1.536490 | 85 | 3.8178 | 2.2 | 2 | 3.0 | 250 |
| NZDUSD | IS | 22 | 1.475627 | 147 | 5.4259 | 2.2 | 2 | 1.4 | 175 |
| NZDUSD | IS | 27 | 1.231826 | 179 | 6.6553 | 1.4 | 2 | 2.2 | 175 |
| NZDUSD | IS | 29 | 2.029472 | 55 | 3.5881 | 3.0 | 2 | 2.2 | 175 |
| NZDUSD | IS | 40 | 1.551114 | 53 | 4.7339 | 2.2 | 2 | 1.4 | 250 |
| NZDUSD | IS | 45 | 1.264449 | 117 | 7.0419 | 1.4 | 2 | 2.2 | 250 |
| NZDUSD | IS | 46 | 1.218865 | 135 | 6.7875 | 2.2 | 2 | 2.2 | 250 |
| NZDUSD | IS | 52 | 1.384072 | 62 | 3.8178 | 2.2 | 2 | 3.0 | 250 |

---

## ORDER-023 — NZDUSD-SELL: fresh-start OOS ของ pass 29 (จาก ORDER-020 hunt) — `REVIEWED(Claude/Fable, 2026-07-04 — ทำเองแทน Codex/ZCode ที่ token หมด — ❌ PARKED regime-dependent)` (role: ZCode/Codex → done by Claude)

**ทำไม:** ORDER-020 เจอ NZDUSD `_14_Direction=2` (SELL) pass 29 สม่ำเสมอ 2 window (full 1.94/76t ·
IS 2.03/55t) — GBPAUD/EURUSD/AUDCAD SELL candidates อื่นถูกตัดทิ้งหรือเป็นของเดิมแล้ว เหลือตัวนี้
ตัวเดียวที่ยังไม่รู้ว่ารอด out-of-sample จริงไหม (กฎ: ห้ามเชื่อ in-sample opt เป็น verdict)

**พารามิเตอร์ pass 29 (จาก XML เดิม, ไม่ต้อง optimize ซ้ำ):** `_9_StepATRmult=3.0`,
`_14_Direction=2`, `_14_DistAtrMult=2.2`, `_2_BasketTP_Money=175`

**ขั้นตอน:**
1. สร้าง set: copy `D:\EA_LAB\ea_template\sets\Boss14_GridLog_screen_small.set` →
   `Boss14_GridLog_NZDUSD_ISpick.set` แล้ว override 4 ค่าด้านบน
2. รัน fresh-start OOS:
```powershell
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol NZDUSD -Period H1 -FromDate 2025.07.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_NZDUSD_ISpick.set' -ReportName BOSS14_NZDUSD_SELL_OOS_M1
```
3. ถ้า OOS PF≥0.9 (หรือเทรด <5 = ข้อมูลไม่พอ ไม่ใช่ fail — ดูกฎเดียวกับ ORDER-004): รัน full-window
   confirm + year-split ต่อทันที (รูปแบบเดียวกับ ORDER-010):
```powershell
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol NZDUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_NZDUSD_ISpick.set' -ReportName BOSS14_NZDUSD_SELL_FULL_ISPICK_M1
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\report_year_split.py D:\EA_LAB\_mt5_auto\reports\BOSS14_NZDUSD_SELL_FULL_ISPICK_M1.htm
```
**Acceptance:** OOS report (trades/PF/net/eqDD) + ถ้าเข้าเงื่อนไขข้อ 3 ให้ full+year-split ต่อด้วย ·
commit `[tag] ORDER-023 done`
**ห้าม:** verdict/promote เป็น candidate — Claude ตัดสิน demo เอง (เกณฑ์เดียวกับ ORDER-006/010)

**ผล + VERDICT (Claude/Fable, 2026-07-04 — รันเองแทน Codex/ZCode ที่ token หมด):**

OOS fresh-start (2025.07–2026.07): 9 trades, PF 1.47, net +$81.91, eqDD 1.07% — ผ่านเกณฑ์ (PF≥0.9)
→ รัน full-window confirm ต่อ:

Full (2023.01–2026.07): 76 trades, PF 1.94, net +$782.83, balDD 2.18% — ตรงกับตัวเลข "full" ที่เจอใน
ORDER-020 XML เป๊ะ (1.94/76t) ยืนยันว่าไม่ใช่ fluke ของการ parse

**Year-split (`report_year_split.py`):**
| Year | Trades | PF | Net | BalDD |
|---|---:|---:|---:|---:|
| FULL | 76 | 1.94 | +782.83 | 2.18% |
| 2023 | 42 | 2.11 | +549.35 | 2.18% |
| 2024 | 2 | 1.00 | -0.10 | 0.31% ⚠️ เกือบตาย |
| 2025 | 18 | 0.88 | -28.99 | 1.73% ⚠️ ปีแพ้ |
| 2026 | 14 | 5.10 | +262.57 | 0.64% |

**❌ VERDICT: NZDUSD-SELL = PARKED (regime-dependent — ไม่ผ่านเกณฑ์ demo cohort)** — เหตุผล: fresh-start
OOS ดูดีเพราะ window (2025.07–26.07) บังเอิญคาบเกี่ยวเข้าไปในช่วง 2026 ที่แข็งมาก แต่ full-window
year-split เผยว่า **2024 แทบไม่เทรด (2t) + 2025 แพ้จริง (PF 0.88, -$29)** — กำไรทั้งหมดกระจุกอยู่แค่
2023 กับ 2026 เท่านั้น (2/4 ปีบวก) ต่างจาก AUDNZD/USDJPY/EURJPY ในคอฮอร์ตปัจจุบันที่ **ทุกปีบวก** —
แพทเทิร์นเดียวกับที่ทำให้ GBPAUD/EURCAD ถูก PARKED ไปแล้ว (chained-window ดูดีแต่ปีจริงมีปีตาย/ปีแพ้ซ่อนอยู่)
· ไม่เข้า demo · ปิดการล่า SELL-side รอบนี้ (เหลือ EURUSD-SELL ที่ demo อยู่แล้วเป็นตัวแทนฝั่ง SELL เดียว)

---

## ORDER-021 — สรุป 20 treasure sources (momentum 13 + breakout 7) ให้ Claude อ่าน — `REVIEWED(Claude/Fable, 2026-07-04 — ทำเองแทน Codex ที่ token หมด, ใช้ Explore subagent อ่าน source แทนตัวเอง)` (role: oc-dev → done by Claude)

**งาน:** จาก `_triage/ea_src_triage.csv` เอาแถว strategy_type ∈ {momentum, breakout} (ข้าม dup) →
ต่อไฟล์เขียนสรุป ≤10 บรรทัดลง `D:\EA_LAB\_triage\shortlist_briefs.md`: (1) entry rule เป๊ะๆ
(indicator+เงื่อนไข+ค่า default) (2) exit/SL/TP (3) sizing (4) สิ่งที่ Boss V2 ยังไม่มี (เทียบ DESIGN_V2
§4 axes ตรงๆ — ถ้าไม่มีของใหม่เขียน "nothing new") (5) คำเตือน (lock/expiry/broker-specific ถ้าเจอ)
**Acceptance:** ครบ 20 ไฟล์ · commit `[oc-dev] ORDER-021 done` · ห้ามให้คะแนน/จัดอันดับ

**ผล (Claude/Fable, 2026-07-04):** ครบ 20 ไฟล์ (momentum 13 + breakout 7) → `_triage/shortlist_briefs.md`
· base dir ยืนยันแล้ว = `D:\Forex\10_EA_PROJECTS\2. wait for test\` (แก้ปัญหา path เดิมที่เคย mis-join
ใน ORDER-018 ก่อนหน้า — คราวนี้ verify ด้วย `find` ก่อนอ่านไฟล์จริง)

**สรุปสั้น (factual, ไม่ใช่ verdict — รายละเอียดเต็มในไฟล์):**
- **momentum 7/13 = "nothing new"** (MA-cross ธรรมดา ตรง GridTrendMA axis อยู่แล้ว รวม 2 ไฟล์เป็น stock
  MetaQuotes sample ตรงๆ) — ไม่ต้องพิจารณาต่อ
- **momentum ที่มีของใหม่จริง:** multi-symbol CCI currency-strength ranking (2 ไฟล์, ไม่มี axis
  รองรับ multi-symbol basket เลย) · ZigZag-vs-EMA comparator · ADX+DI trend-strength filter stacked
  บน MACD (Boss V2 ยังไม่มี ADX module) · two-tier/dual-lot basket-per-symbol (XIMA_DASH) · multi-pair
  14-symbol basket+hedge (T101)
- **breakout ที่มีของใหม่จริง:** retest-zone + reversal-exit state machine (Breakout Retest Pro —
  ต่อยอด Entry_Breakout เดิมได้ตรงๆ) · PA candle-pattern gate (Doji/Engulfing/Star/Tower, 2 ไฟล์ —
  ไม่มี axis ไหนใช้ candle-pattern recognition) · auto-detected S/R + multi-level pyramid (Dark_Gold_Full)
- **ตัดทิ้งจากการพิจารณาต่อทันที:** EX170 Zone Trading (entry เป็น manual chart-line ไม่ใช่ระบบอัตโนมัติ),
  XPERT2 (kernel32.dll file I/O + obfuscated — ความเสี่ยง code ไม่ทราบที่มา), MoonKinght MASA
  (obfuscated/decompiled + wininet auth code เหลืออยู่ในซอร์ส)
- **ห้ามให้ verdict ที่นี่ตามกฎ** — ตัวไหนน่า build ต่อเป็น decision รอบ hunt ถัดไปของ Claude/user

---

## ORDER-022 — Plateau-sensitivity test ของ 6 DEMO configs (ปิดจุดอ่อน optimize จาก self-review) — `REVIEWED(Claude/Fable, 2026-07-04 — รันเองแทน oc-btest ที่ token หมด, เลน 1 ไม่ใช่เลน 2 เพราะ Claude รันตรง)` (role: oc-btest → done by Claude)

**ทำไม (user ถาม 2026-07-04: 'รู้ได้ไงว่า optimize ดีจริง'):** grid เดิมหยาบ (3 ค่า/แกน) + SL/MaxLevels
ไม่เคยทดสอบ — ต้องรู้ว่า config บน demo นั่งบน 'ที่ราบ' หรือ 'สันเขาแคบ'
**งาน — ต่อ symbol (6 ตัว จาก `Boss14_GridLog_<SYM>_DEMO.set`): รัน 8 variants บน full window**
(2023.01–2026.07, Model 1, เลน 2) โดยแก้ทีละค่าเดียวจาก DEMO set:
1. `_9_StepATRmult` ×0.8   2. `_9_StepATRmult` ×1.2
3. `_14_DistAtrMult` ×0.8  4. `_14_DistAtrMult` ×1.2
5. `_2_BasketTP_Money` ×0.8  6. `_2_BasketTP_Money` ×1.2
7. `_33_SL_ATRmult` 3.0    8. `_33_SL_ATRmult` 5.0
(สร้าง set ชั่วคราวใน `_mt5_auto\ab_sets\` · ReportName `SENS_<SYM>_V<n>` · 48 runs รวม — ~2-3 ชม.)
**Acceptance:** ตารางต่อ symbol: variant | PF | trades | eqDD% + แถว baseline จาก full-confirm เดิม ·
commit `[oc-btest] ORDER-022 done`
**ห้าม:** verdict — เกณฑ์ของ Claude: variant ส่วนใหญ่ PF ยัง ≥70% ของ baseline = ที่ราบ (ผ่าน),
มี variant ไหนพลิกเป็นขาดทุน = สันเขา (ตัวนั้นต้องทบทวนก่อน promote — demo ต่อได้แต่ติดธง)

**ผล (Claude/Fable, 2026-07-04 — 48/48 runs สำเร็จ, ไม่มี NO_REPORT):** raw CSV เต็ม →
`_mt5_auto/ORDER022_SENSITIVITY.csv`. Baseline (จาก `BOSS14_<SYM>_FULL_ISPICK_M1.htm` เดิม):

| Symbol | baseline PF | trades | eqDD% | 70%-of-baseline threshold |
|---|---:|---:|---:|---:|
| USDJPY | 1.51 | 138 | 6.15 | 1.057 |
| AUDNZD | 1.56 | 195 | 4.26 | 1.092 |
| EURJPY | 2.49 | 114 | 6.00 | 1.743 |
| AUDCAD | 1.88 | 146 | 6.38 | 1.316 |
| CADJPY | 1.89 | 77 | 3.71 | 1.323 |
| EURUSD | 1.97 | 69 | 4.39 | 1.379 |

**8-variant results ต่อ symbol** (V1/V2=StepATRmult ∓20% · V3/V4=DistAtrMult ∓20% ·
V5/V6=BasketTP ∓20% · V7/V8=SL_ATRmult fixed 3.0/5.0):

| Symbol | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| USDJPY | 0.88❌ | 1.40 | 2.04 | 1.28 | 0.97❌ | 1.14 | 1.09 | 2.04 |
| AUDNZD | 1.66 | 1.71 | 1.59 | 1.52 | 1.40 | 1.37 | 1.97 | 1.50 |
| EURJPY | 1.17▽ | 4.41 | 1.36▽ | 1.20▽ | 0.93❌ | 1.36▽ | 1.70▽ | 1.28▽ |
| AUDCAD | 1.83 | 1.53 | 1.11▽ | 1.57 | 1.22▽ | 1.57 | 2.13 | 1.29▽ |
| CADJPY | 0.83❌ | 1.30▽ | 1.04▽ | 1.30▽ | 1.18▽ | 1.54 | 1.21▽ | 1.33 |
| EURUSD | 1.02▽ | 1.42 | 1.01▽ | 2.24 | 2.16 | 1.05▽ | 2.46 | 1.65 |

(❌ = พลิกขาดทุนสุทธิ (net<0) · ▽ = PF ต่ำกว่า 70%-of-baseline แต่ยังกำไร · ค่าไม่มีเครื่องหมาย = ผ่าน ≥70%)

**VERDICT ต่อ symbol (เกณฑ์: ส่วนใหญ่ ≥70% = ที่ราบผ่าน · มี ❌ = สันเขา ติดธง):**
- 🏆 **AUDNZD = ที่ราบสมบูรณ์ (8/8 ผ่าน, ไม่มี ❌ เลย)** — ยืนยันแชมป์อีกครั้ง (ตรงกับ Model-4 confirm
  ที่เคยเจอว่าแข็งสุด) sensitivity ต่ำสุดในคอฮอร์ต ไม่ต้องติดธงอะไรเพิ่ม
- ✅ **AUDCAD = ที่ราบ (5/8 ผ่าน, ไม่มี ❌)** — นิ่มลงบ้างที่ DistAtrmult ตึงขึ้น/TP ตึงขึ้น/SL กว้างขึ้น
  แต่ไม่มีทิศไหนพลิกขาดทุน ยังถือว่าแข็งพอ
- ⚠️ **USDJPY = ที่ราบมีรอยร้าว (6/8 ผ่าน แต่ 2 ตัวพลิกขาดทุน)** — **step แคบลง (×0.8) และ TP แคบลง (×0.8)
  ทำให้ขาดทุนสุทธิ** ทั้งคู่คือทิศ "ตึงกว่าเดิม" (aggressive) พลิกลบ ส่วนทิศ "หลวมกว่าเดิม" ทุกทิศยังกำไร
  → ธง: **อย่าลด step/TP ของ USDJPY ต่ำกว่าค่าเดิม** เวลาจะ tune ต่อ
- ⚠️ **EURUSD = ที่ราบปานกลาง (5/8 ผ่าน, ไม่มี ❌)** — มี 3 ทิศที่เกือบ breakeven (PF~1.0-1.05: step แคบ,
  dist แคบ, TP กว้างขึ้น) แต่ไม่มีทิศไหนพลิกลบจริง ยังพอไว้ใจได้
- 🔴 **CADJPY = สันเขา (2/8 ผ่านเท่านั้น, 1 พลิกขาดทุน ที่ step แคบลง)** — ยืนยันธง "thin" เดิมด้วยหลักฐาน
  ใหม่: ไม่ใช่แค่เทรดน้อย (77t) แต่ตัว mechanism ไวต่อ param มาก — ห้าม promote/เพิ่ม lot จนกว่าจะมี
  หลักฐานมากกว่านี้
- 🔴 **EURJPY = สันเขาชัดเจนสุดในคอฮอร์ต (1/8 ผ่าน ≥70% จริง, 1 พลิกขาดทุนที่ TP แคบลง)** — baseline
  PF 2.49 คือ**จุดพีค ไม่ใช่ที่ราบ** — 6/8 ทิศตกมาเหลือ 1.17-1.70 (ยังบวกแต่ไกลจาก baseline มาก) ยืนยันธง
  "fill-sensitive" ที่เคยเจอจาก Model-4 confirm (eqDD 10.02%) ด้วยหลักฐานอิสระคนละมิติ — **สอง
  หลักฐานชี้ทางเดียวกัน: EURJPY ต้อง size เบากว่าเพื่อนตอน promote จริง เป็นข้อสรุปที่มั่นใจแล้ว**

**สรุปจัดอันดับความแข็ง (มากไปน้อย):** AUDNZD > AUDCAD > EURUSD ≈ USDJPY (มีจุดอ่อนคนละทิศ) >>
CADJPY > EURJPY (สันเขาทั้งคู่)

---

## ORDER-024 — Recovery-mode A/B บน config ที่ชนะ (AUDNZD champion) — `REVIEWED(Claude/Opus, 2026-07-05 — 81 REJECT · 82 PROMISING แต่ยังไม่ adopt → ORDER-025 ตรวจ floating DD)` (role: oc-btest/ZCode → run by oc-dev)

**VERDICT (Claude/Opus, 2026-07-05):**
- **Mode 81 (Light Recovery) = ❌ REJECT ปิดถาวร** — แย่ลงทุกมิติ: PF 1.56→1.33, eqDD 4.26→5.13%,
  net -$505, 2024 พลิกเป็นปีลบ (-$154). Light Recovery ไม่มีค่าบน config ที่ดีอยู่แล้ว
- **Mode 82 (Adaptive Recovery) = 🟡 PROMISING แต่ยังไม่ adopt** — ผ่าน mechanical gate (PF 1.56→1.73 ↑,
  eqDD 4.63% < baseline+50%=6.39% ✓, net +$121) **แต่ year-split เผย regime-amplification:** กำไรกระจุก
  2025-26 (PF 3.34/5.85) โดย **2024 พลิกจากปีบวก 1.28 → ปีลบ 0.78** = พฤติกรรม recovery แท้ (ปีดีเร่ง,
  ปีร้ายขุดลึก). eqDD 4.63% = closed-trade @0.25x → **ไม่จับ floating DD ตอน recovery legs ค้างขาดทุน**
  ที่ live 3-4x ปีร้ายแบบ 2024 อาจลึกกว่านี้มาก (บทเรียน Zeus: MC worst 18% vs ปี hostile จริง 36%)
- **ยังไม่แตะ demo cohort (คง Recovery OFF)** — 6 EA กำลัง attach/รันเป็นการทดลอง ห้ามเปลี่ยนกลางคัน
- **คำถาม Recovery ยังไม่ปิด** — 82 น่าสนใจพอจะตรวจต่อ (floating DD จริง + generalize ข้าม symbol) →
  ORDER-025. ถ้าผ่าน = mold-wide upgrade candidate; ถ้า floating DD บวมที่ live sizing = ปิดถาวร

**ทำไม (hunt queue mine #1 = แกนกลไกในแม่พิมพ์ที่ยังไม่ sweep):** โหมด Recovery 81/82/83 + HEDGE_LOCK
สร้างไว้ตั้งแต่ 2026-07-03 แต่ **ไม่เคยผ่าน backtest ใดๆ** (PROJECT_STATE: "เปิดใช้ครั้งแรก = validate
เหมือน mechanism ใหม่"). คำถามที่ตอบได้ถูกสุด + info มากสุด: **เปิด Recovery บน config ที่ชนะแล้ว
(AUDNZD = แชมป์ ที่ราบสมบูรณ์) ช่วยหรือพัง?** ถ้าช่วยโดย DD ไม่บวม = mold-wide upgrade · ถ้าพัง = ปิด
คำถามนี้ถาวร. ทำ AUDNZD ตัวเดียวก่อน (แชมป์ = สัญญาณชัดสุด) — ไม่ต้องรัน 6 ตัว

**งาน — 3 variants บน full window** (2023.01–2026.07, Model 1, เลน 2) จาก `Boss14_GridLog_AUDNZD_DEMO.set`
แก้ **ค่าเดียว** `RecoveryMode`:
1. `RecoveryMode=80` (OFF = baseline, ยืนยันตรงกับ full-confirm เดิม 1.56/195t)
2. `RecoveryMode=81` (Light)
3. `RecoveryMode=82` (Adaptive)
(สร้าง set ใน `_mt5_auto\ab_sets\` ชื่อ `AUDNZD_REC<80/81/82>.set` · ReportName `REC_AUDNZD_V<mode>` ·
`_8_` recovery params ปล่อย compiled default — นี่คือ first-look ยังไม่ tune)

**Acceptance:** ตาราง 3 แถว: mode | PF | trades | eqDD% | net · + note ว่า variant 80 ตรง baseline เดิมไหม
(ถ้าไม่ตรง = set/ค่าเพี้ยน หยุดรายงาน) · commit `[tag] ORDER-024 done`
**ห้าม:** verdict — เกณฑ์ Claude: Recovery ผ่านต่อเมื่อ PF ขึ้น **และ** eqDD ไม่เกิน baseline +50% ·
DD บวมโดย PF ไม่ขึ้น = ปิดคำถาม Recovery ถาวร (mechanism ไม่คุ้ม) · ⚠️ Recovery = เติมไม้แก้ →
ต้องดู eqDD ทุก variant อย่าดูแค่ PF (กฎ grid/martingale: floating DD ซ่อน)

**ผล ([oc-dev], 2026-07-05):** ทำต่อแม้ order role ระบุ oc-btest/ZCode เพราะ user สั่งตรงให้ ea_developer ทำ; ใช้เลน 2 ตาม order (`D:\Meta 5b`, portable), Model 1, full window 2023.01.01-2026.07.01. สร้าง set ใน `_mt5_auto\ab_sets\`:
`AUDNZD_REC80.set`, `AUDNZD_REC81.set`, `AUDNZD_REC82.set` โดยแก้เฉพาะ `RecoveryMode`; ไม่มี `_8_` recovery params ใน set (ปล่อย compiled/default ตาม order).

Reports:
- `D:\EA_LAB\_mt5_auto\reports\REC_AUDNZD_V80.htm`
- `D:\EA_LAB\_mt5_auto\reports\REC_AUDNZD_V81.htm`
- `D:\EA_LAB\_mt5_auto\reports\REC_AUDNZD_V82.htm`

| mode | PF | trades | eqDD% | net |
|---:|---:|---:|---:|---:|
| 80 | 1.56 | 195 | 4.26 | +1242.36 |
| 81 | 1.33 | 193 | 5.13 | +737.51 |
| 82 | 1.73 | 193 | 4.63 | +1363.57 |

Baseline note: mode 80 ตรง baseline เดิม **1.56 / 195 trades**.

Year split (`scripts\report_year_split.py`, closed-deal balance stats):

| mode | year | trades | PF | net | balDD% |
|---:|---:|---:|---:|---:|---:|
| 80 | FULL | 195 | 1.56 | +1242.36 | 3.08 |
| 80 | 2023 | 83 | 1.36 | +323.03 | 2.33 |
| 80 | 2024 | 33 | 1.28 | +125.58 | 2.96 |
| 80 | 2025 | 48 | 1.64 | +330.77 | 2.57 |
| 80 | 2026 | 31 | 2.31 | +462.98 | 1.33 |
| 81 | FULL | 193 | 1.33 | +737.51 | 4.14 |
| 81 | 2023 | 87 | 1.00 | +3.92 | 3.59 |
| 81 | 2024 | 34 | 0.70 | -154.04 | 4.15 |
| 81 | 2025 | 55 | 2.67 | +682.24 | 1.91 |
| 81 | 2026 | 17 | 2.03 | +205.39 | 1.29 |
| 82 | FULL | 193 | 1.73 | +1363.57 | 3.68 |
| 82 | 2023 | 94 | 1.29 | +294.40 | 2.63 |
| 82 | 2024 | 29 | 0.78 | -105.08 | 3.79 |
| 82 | 2025 | 50 | 3.34 | +667.86 | 0.82 |
| 82 | 2026 | 20 | 5.85 | +506.39 | 1.00 |

---

## ORDER-025 — Adaptive Recovery (mode 82): ตรวจ floating DD จริง + generalize ข้าม symbol — `REVIEWED(Claude/Opus, 2026-07-05 — ❌ Recovery REJECT ปิดถาวรทั้ง 81+82; Model-4 เผย Model-1 lift = artifact)` · 👉 แนะรัน: ZCode (batch ล้วน ฟรี) (role: ZCode/oc-btest, เลน 2)

**VERDICT (Claude/Opus, 2026-07-05): ❌ Recovery mode 82 = REJECT → ปิดคำถาม Recovery ถาวร (ทั้ง 81+82) สำหรับ Boss_14 family**

**หลักฐานชี้ขาด = Model-4 บน AUDNZD (apples-to-apples 2024-2026 real ticks):** mode 80 = PF 3.37/44t
→ mode 82 = **PF 1.50/118t** — บน real ticks PF ร่วงกว่าครึ่ง + เทรดพุ่ง 3× = recovery legs churn
คุณภาพต่ำ, fill ไม่สวยเหมือน Model 1. **นี่คือ fill-artifact ชั้นที่ลึกกว่า Model-2 ban** — Model-1 รอบ
024 โชว์ 82 ดีกว่า (1.73 vs 1.56) เพราะ control-point fills recovery legs สวยเกินจริง; every-tick =
ความจริง (ตรงกฎ "grid/martingale ต้อง every-tick ไม่ใช่ MC/M1 อย่างเดียว")

**Generalize ก็ไม่ผ่าน (Model 1):** USDJPY PF 1.51→1.65 (ขึ้น **แต่** กระจุกที่ 2023 + 2025 dormant 0 เทรด
= regime-concentrated เหมือนเดิม) · **AUDCAD PF 1.88→1.78 (ลด!)** net ขึ้นเพราะเทรด 146→207 (churn มาก
ขึ้น ไม่ใช่ quality) → PF-lift ไม่ generalize (1 ขึ้น 1 ลง) + ตัวที่ Model-4 วัดจริงคือร่วง

**สรุป:** Recovery (81 Light + 82 Adaptive) = ไม่มีค่าบน config ที่ดีอยู่แล้ว — เพิ่ม churn/floating DD
โดยไม่ยก quality จริง. **HedgeMode/HEDGE_LOCK ยังไม่เคยเทส (แยกจาก Recovery)** — prior อ่อนลงหลัง
Recovery ล่ม แต่ยังเปิดทดสอบได้ถ้าว่าง. **demo cohort = Recovery OFF ถูกต้องแล้ว ไม่ต้องเปลี่ยน** ·
บทเรียน routing: Model-4 บังคับก่อนเชื่อ mechanism ตระกูล grid/recovery ทุกครั้ง (Model-1 หลอกได้)

**ทำไม:** ORDER-024 พบ mode 82 ยก PF บน AUDNZD แต่มี 2 คำถามที่ยังตอบไม่ได้ ก่อนจะเชื่อว่าเป็น mold
upgrade: (1) closed-trade eqDD 4.63% ไม่จับ floating DD ของ recovery legs — ต้อง **Model 4 every-tick**
ถึงเห็นจริง (กฎ grid/martingale: floating DD ซ่อน) (2) PF-lift เป็นของ AUDNZD ตัวเดียวหรือ generalize?

**งาน 2 ส่วน:**

**ส่วน A — floating DD จริงของ mode 82 (Model 4, ⚠️ รันเดี่ยว ห้ามคู่ขนานอะไรทั้งนั้น — freeze guard):**
```powershell
# เลน 2, Model 4 real ticks, ใช้ set เดิมที่ oc-dev สร้าง
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol AUDNZD -Period H1 -FromDate 2024.01.01 -ToDate 2026.07.01 -Model 4 -SetFile 'D:\EA_LAB\_mt5_auto\ab_sets\AUDNZD_REC82.set' -ReportName REC_AUDNZD_V82_M4 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
```
เทียบกับ mode 80 M4 เดิม (มีแล้วจาก ORDER-014: AUDNZD M4 = 3.37/44t/eqDD 2.26%) — ดูว่า Recovery ทำ
**equity DD maximal** (floating) พุ่งแค่ไหน

**ส่วน B — generalize: mode 82 บน 2nd/3rd winner (Model 1, รันคู่ขนานได้):**
```powershell
# แทน <SYM> = USDJPY, AUDCAD (2 ตัวที่ plateau แข็ง). สร้าง set จาก DEMO เดิมแก้ RecoveryMode=82
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\_mt5_auto\ab_sets\<SYM>_REC82.set' -ReportName REC_<SYM>_V82 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
# แล้ว year-split ทุกไฟล์
```
**Acceptance:** (A) ตาราง AUDNZD mode 80 vs 82 บน M4: PF / trades / **equity DD maximal %** (floating) ·
(B) ต่อ symbol: mode 80 baseline vs 82 — PF/trades/eqDD/net + year-split · commit `[tag] ORDER-025 done`
**ห้าม:** verdict — เกณฑ์ Claude: 82 = mold upgrade ต่อเมื่อ (1) M4 floating DD ไม่พุ่งเกิน ~2x ของ closed-trade
**และ** (2) PF-lift เกิดซ้ำอย่างน้อย 1/2 symbol โดยไม่สร้างปีลบใหม่ · ไม่งั้น = Recovery ปิดถาวร (เฉพาะ mode 82 บน AUDNZD เก็บเป็น note ไม่ deploy)

**ผล (ZCode, Model 4 + Model 1; ไม่มี verdict):**

**Sets ใหม่ที่สร้าง:** `USDJPY_REC82.set` (DEMO base + RecoveryMode=82, magic 990201) ·
`AUDCAD_REC82.set` (DEMO base + RecoveryMode=82, magic 990204) — ทั้งคู่ override แค่ RecoveryMode 80→82
magic/DdAdaptive/everything else คง DEMO เดิม (เทียบเท่า AUDNZD_REC82 pattern)

**ส่วน A — AUDNZD floating DD จริง (Model 4 real ticks, เลน 2, 99% history):**

| Config | PF | Trades | Net | **Equity DD maximal % (floating)** | balDD% |
|---|---:|---:|---:|---:|---:|
| mode 80 baseline (ORDER-014 M4) | 3.37 | 44 | — | 2.26% | — |
| **mode 82 (REC_AUDNZD_V82_M4)** | **1.50** | **118** | **+639.50** | **4.04%** | 3.19% |

floating DD = 4.04% = ~1.8× ของ baseline 2.26% (ใต้เกณฑ์ ~2× borderline; trades เพิ่ม 3×).

**ส่วน B — Generalize (Model 1 full-window 2023-2026 + year-split):**

| Symbol | Config | PF | Trades | Net | EqDD% | balDD% |
|---|---|---:|---:|---:|---:|---:|
| USDJPY | mode 80 baseline (FULL_ISPICK_M1) | 1.51 | 138 | +841.72 | 6.15% | 4.38% |
| USDJPY | **mode 82 (REC_USDJPY_V82)** | **1.65** | **141** | **+1044.73** | 6.44% | 4.29% |
| AUDCAD | mode 80 baseline (FULL_ISPICK_M1) | 1.88 | 146 | +1491.31 | 6.38% | 4.06% |
| AUDCAD | **mode 82 (REC_AUDCAD_V82)** | **1.78** | **207** | **+2040.62** | 4.80% | 2.89% |

**Year-split (raw — ไม่ interpret):**

| Symbol | Config | 2023 | 2024 | 2025 | 2026 |
|---|---|---|---|---|---|
| USDJPY | mode 80 | 1.51/122t/+476 | 6.82/14t/+361 | (missing) | 1.21/2t/+4 |
| USDJPY | mode 82 | 1.44/125t/+679 | 6.82/14t/+361 | (missing) | 1.21/2t/+4 |
| AUDCAD | mode 80 | 1.27/55t/+217 | 1.01/41t/+7 (thin) | 5.63/25t/+436 | 4.91/25t/+832 |
| AUDCAD | mode 82 | 1.86/120t/+964 | 1.30/32t/+122 | 2.82/19t/+525 | 1.54/36t/+430 |

**หมายเหตุดิบ (ไม่ใช่ verdict):**
- USDJPY year-split baseline กับ V82 ตรงกันเกือบหมด — recovery เพิ่มเทรดนิดที่ 2023
  (122→125t, PF 1.51→1.44) และยก net ปีนั้น (+476→+679) → net full +24% (841→1045)
- USDJPY 2025 = 0 เทรดทั้งคู่ (baseline กับ V82) — config นี้ dormant ในช่วง 2025
- AUDCAD mode 82 เพิ่ม trades เยอะ (146→207) แต่ PF ลด (1.88→1.78) — net สูงขึ้นเพราะเทรดมากขึ้น
  ไม่ใช่ quality ดีขึ้น · DD ลดลง (6.38→4.80)
- AUDCAD 2024 baseline = 1.01/41t = borderline-flat; V82 = 1.30/32t = ดีขึ้น
- AUDCAD ทุกปีบวกทั้งสอง config

**Files:** `REC_AUDNZD_V82_M4.htm` · `REC_USDJPY_V82.htm` · `REC_AUDCAD_V82.htm`
+ `_mt5_auto\ab_sets\USDJPY_REC82.set` · `_mt5_auto\ab_sets\AUDCAD_REC82.set`

---

## ORDER-026 — HedgeMode (HEDGE_LOCK) A/B บน AUDNZD — `REVIEWED(Claude/Opus, 2026-07-05 — รันเอง เพราะ ZCode โควต้าหมดวัน + งานเบา 1 run; ❌ Hedge = dormant no-op)` · 👉 แนะรัน: Claude/qwen (เบามาก) (role: batch)

**ทำไม:** ปิดคำถาม loss-management layer ให้ครบ — Recovery ถูก reject ไปแล้ว (ORDER-024/025) เหลือ
HEDGE_LOCK (mode 1) ที่ยังไม่เคยเทส (กลไกต่าง: ล็อกไม้สวนตอน DD ลอยสูง ไม่ใช่เติมไม้ทิศเดิม)

**ผล (Claude/Opus, Model 1, AUDNZD full-window):** สร้าง `_mt5_auto\ab_sets\AUDNZD_HEDGE1.set`
(DEMO base + HedgeMode=1, RecoveryMode คง 80) → รัน:

| Config | PF | Trades | eqDD% | Net |
|---|---:|---:|---:|---:|
| HedgeMode=0 (baseline DEMO) | 1.56 | 195 | 4.26 | +1242.36 |
| **HedgeMode=1 (HEDGE_LOCK)** | **1.56** | **195** | **4.26** | **+1242.36** |

**VERDICT: ❌ HEDGE_LOCK = dormant no-op บน config ที่ดีอยู่แล้ว** — ตัวเลข**เหมือน baseline เป๊ะทุกหลัก**
= hedge ไม่เคยยิงเลย. เหตุ: `_H_TriggerDDPct=8.0%` แต่ AUDNZD floating DD แตะแค่ ~4% (M1) / 2.26% (M4)
ไม่ถึงเกณฑ์ → กลไกหลับตลอด. Model-4 ไม่ต้องรัน (DD ยิ่งต่ำ ยิ่งไม่ยิง).

**สรุป loss-management layer ทั้งหมด (Recovery 81/82/83 + HEDGE_LOCK) = ไม่เพิ่มค่าบน Boss_14 cohort
ปัจจุบัน ปิด branch นี้** — Recovery churn เสียคุณภาพ (M4), Hedge หลับเพราะ DD ต่ำเกินจะ trigger.
demo config (ทั้ง 2 layer OFF) = ถูกต้องแล้ว · **re-examine trigger เดียว: ถ้าอนาคตมี config DD สูง (>8%)
Hedge อาจมีบทบาท — ตอนนั้นค่อยลด `_H_TriggerDDPct` มาเทสจริง** (ไม่ใช่ตอนนี้)

---

## ORDER-027 — mold upgrade: `_2_BasketTP_ATRmult` (basket TP แบบ ATR-scaled, additive) — `REVIEWED(Claude/Opus, 2026-07-05 — ✅ ACCEPT, verified tpl_regression CLEAN เอง; scan ต่อเจอ XAU GridLog มีชีวิต + bug ตัวที่ 2)` · ทำได้: Codex/Claude/oc-dev · 👉 Codex-direct

**VERDICT (Claude/Opus): ✅ ORDER-027 ACCEPT.** verify เอง 3 ชั้น: (1) code inspection — `Exit_BasketTargetMoney()`
คืน `_2_BasketTP_Money` เดิม literally เมื่อ mult=0 (default) = inert พิสูจน์ได้ (2) trades baseline เท่าเดิม
เป๊ะ 168/164/107 = ถ้า logic เพี้ยนจะปิด basket เร็ว trades ต้องเปลี่ยน (3) **รัน tpl_regression เอง = CLEAN
ทั้ง 3**. baseline ขยับ (net นิดเดียว) = data refill ระหว่าง 07-03→07-05 ไม่ใช่ bug (Codex ทำ pristine-rerun
ยืนยันแล้ว, ผม verify ซ้ำ). A/B: ATR-TP ทำงานได้จริง บน FX แย่กว่า fixed-$ (คาดไว้ — fixed-$ จูนมาสำหรับ FX).

**🔬 CONTINUE (Claude รัน XAU scan เอง เพื่อ scope ORDER-028): 2 การค้นพบใหญ่**
- **🐛 bug ตัวที่ 2 = `_33_SL_MaxPips` ไม่ portable:** ใช้ `pip=(digits==3||5?10:1)×Point`. XAU=2 digits →
  pip=Point=0.01 → cap 150×0.01 = **SL cap $1.50 บนทอง (ทองวิ่ง $1.50 ในวินาที)** → ไม้โดน stop รัวๆ.
  รอบแรกทดสอบ XAU ได้ PF 0.29 = artifact ของ SL cap พัง ไม่ใช่กลยุทธ์. → **ORDER-029 (แก้ mold ให้ portable)**
- **🥇 XAU GridLog มีชีวิตจริง (ปิด SL cap → ATR-SL คุม):** `_2_BasketTP_ATRmult=1` = **PF 1.76 / 508t /
  net +$5,569 / eqDD 18.73%** (@0.25x lot, full-window in-sample) · mult ต่ำดีกว่า (2=1.65, 3.5=1.54, 5=0.96) ·
  **= non-FX diversifier ตัวแรกที่เป็นไปได้** (ทอง vs พอร์ต FX grid เดิม). ⚠️ IN-SAMPLE + DD สูง (ต้อง de-scale
  ตอน promote — edge=PF scale-invariant, DD=resize) + **ทอง+grid = ต้อง Model-4 + สงสัยสูงสุด** → ORDER-028 validate เต็ม

**ทำไม (ปลดล็อก hunt ที่ EV สูงสุดของ mine #1):** GridLog = กลไกเดียวที่มี edge จริง (6 demo EA) →
ต่อยอดที่คุ้มสุด = **ขยายไป non-FX (metals/index)** เพื่อกระจาย instrument class. **แต่ติดบล็อก:**
`_2_BasketTP_Money` เป็น $ คงที่ ไม่ scale ข้าม instrument class (self-review 2026-07-04: XAU ราคาคนละ
scale กับ FX → $TP เดิมใช้ไม่ได้). ต้องเพิ่มโหมด TP แบบ ATR-scaled ก่อน sweep non-FX ครั้งแรก. **Boss_12/13
entries ถูก deprioritize** (FX breakout/reversion = optimize-killed แล้วใน LabTpl, XAU ซ้ำ live EA — ดู reassess ใน PROJECT_STATE)

**สเปคโค้ด (additive, default = พฤติกรรมเดิมเป๊ะ):**
1. `core\Inputs.mqh` (~บรรทัด 197 ใกล้ `_2_BasketTP_Money`): เพิ่ม `input double _2_BasketTP_ATRmult = 0;`
   `// close basket at +(ATR×mult ต่อ lot รวม) เป็น $ (0=ใช้ _2_BasketTP_Money แบบเดิม)`
2. `core\ExitManager.mqh` `Exit_ManageBasket()` (~บรรทัด 189-196): คำนวณ **effective target $** —
   ถ้า `_2_BasketTP_ATRmult > 0`: `targetMoney = ATR(price) × _2_BasketTP_ATRmult × (มูลค่า $ ต่อ 1 price-unit
   ต่อ lot) × Exec_TotalLots()` (ใช้ `SymbolInfoDouble(TICK_VALUE/TICK_SIZE)` แปลง price→$ ให้ถูกต่อ instrument) ·
   ถ้า `=0`: ใช้ `_2_BasketTP_Money` เดิม. ต้องแก้ **ทั้ง** จุด TP (บรรทัด ~196) **และ** จุด partial-close
   % base (บรรทัด ~174 `pctOfTarget = profit/_2_BasketTP_Money`) ให้อ้าง effective target ตัวเดียวกัน (helper 1 ตัว)
3. ATR ที่ใช้ = `_3_RiskATR_Period`/`_3_RiskATR_TF` (risk-ATR ตัวเดียวกับ SL) เพื่อ consistency

**Acceptance:**
- compile 0/0 ทั้ง 3 Boss EA (Boss_11/12/13/14 — ทุกตัวที่ include ExitManager)
- **`powershell -File scripts\tpl_regression.ps1` = CLEAN** (default 0 = ไม่มี behavior drift — พิสูจน์ additive จริง)
- A/B 1 ตัว (`ab_mode_test` หรือรันมือ): AUDNZD `_2_BasketTP_ATRmult=X` (จูนให้ ~เท่า $175 เดิม) เทียบ
  `_2_BasketTP_Money=175` — trades ใกล้กัน = แปลง $↔ATR ถูก · report ค่าที่จูนได้
- commit `[tag] ORDER-027 done`
**ห้าม:** เปลี่ยน default `_2_BasketTP_Money` · แตะ logic อื่นนอก basket-TP/partial-close · ตีความว่าโหมดไหนดีกว่า (Claude ตัดสิน)

**ผล (Codex, Model 1; ไม่มี verdict):**
- เพิ่ม `_2_BasketTP_ATRmult=0` และ helper effective target: `Risk-ATR × mult × (tick value / tick size) × total lots`;
  fixed `_2_BasketTP_Money` ยังเป็น fallback/default เดิม และ partial-close กับ full basket TP ใช้ target helper เดียวกัน.
- compile: Boss_11/12/13/14 = **0 errors / 0 warnings** ทุกตัว.
- regression: รอบแรก drift เล็กน้อยทั้ง 3 baseline โดย trades เท่าเดิม; controlled rerun ด้วย source pristine
  ให้ตัวเลขเดียวกันเป๊ะ จึง re-capture baseline จาก pristine tester-data ปัจจุบัน แล้วใส่ feature กลับ →
  `powershell -File scripts\tpl_regression.ps1` = **REGRESSION CLEAN** ทั้ง 3 ตัว.
- A/B AUDNZD H1 full-window 2023.01.01–2026.07.01: fixed `$175` = **195 trades, PF 1.56,
  net 1242.36, EqDD 4.26%**; ค่าจูน `_2_BasketTP_ATRmult=32.0` = **188 trades, PF 1.14,
  net 431.50, EqDD 11.17%** (ต่าง **−7 trades / −3.6%**). Reports:
  `AB_order027_audnzd_atrtp32_BASE.htm` + `AB_order027_audnzd_atrtp32_VAR.htm`.
- coarse tuning raw ก่อนถึงค่า 32: mult 5→510 trades, 25→244, 35→169 (เก็บใน `ab_results.csv`).

---

## ORDER-028 — XAU GridLog: IS-optimize (axis tuning สำหรับทอง) — `REVIEWED(Claude/Opus, 2026-07-05 — plateau-center = Pass 20 → pipeline ORDER-030/031)` · ทำได้: ZCode/oc-btest · 👉 ZCode

**REVIEW (Claude/Opus):** plateau ชัด+แข็ง — **Step=3.0/BUY/Dist=1.4** โดย BasketTP_ATRmult {0.5→PF1.49,
1.0→1.48, 1.5→1.37} ทั้งกลุ่มผ่านที่ DD 9.3-10.3% (optimizer หา Step กว้าง → DD ลดจาก 18% เหลือ 9%). →
**plateau-center = Pass 20 (Step3.0/BUY/Dist1.4/BasketTP_ATRmult=1.0, PF 1.48/277t/DD 9.34%)** (เลือก
mult=1.0 กลาง plateau robust กว่าขอบ). set สร้างแล้ว `Boss14_GridLog_XAU_ISpick.set` (SL cap=0). ทุกเลข
IN-SAMPLE → ต้อง OOS/MC/Model-4 (ORDER-030/031)

**ทำไม:** scan (ORDER-027) พบ XAU GridLog มีชีวิต (PF 1.76 in-sample @ mult=1) หลังปิด SL-cap ที่พัง —
แต่นั่นใช้ axes ของ AUD (StepATR=1.4/DistATR=1.4) transplant มา ต้อง IS-optimize สำหรับทองเองก่อนเชื่อ
(กฎ pipeline เดียวกับ Boss_14: IS-opt → fresh OOS → MC → Model-4)

**สร้าง opt set** `Boss14_GridLog_XAU_opt1.set` — base = `Boss14_GridLog_AUDNZD_DEMO.set` แก้:
`_2_BasketTP_Money=0` · **`_33_SL_MaxPips=0`** (ปิด cap ที่พังบนทอง — สำคัญ!) · `_0_Magic=990301` ·
แล้วใส่บรรทัด optimize (`||start||step||stop||Y`):
- `_9_StepATRmult` = 1.4, 2.2, 3.0
- `_14_DistAtrMult` = 1.4, 2.2, 3.0
- `_2_BasketTP_ATRmult` = **0.5, 1.0, 2.0** (scan ชี้ว่า mult ต่ำดีกว่าบนทอง — โฟกัสช่วงต่ำ)
- `_14_Direction` = 1, 2 (ทั้ง BUY/SELL)
- lock input อื่นทุกตัวด้วย `||N` (บทเรียน ORDER-008B: MT5 auto-sweep bool → row ระเบิด)
```powershell
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2025.06.30 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_XAU_opt1.set' -ReportName BOSS14_OPT_XAU_IS -TimeoutSec 21600 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
```
**Acceptance:** XML ครบทุก row · จำนวน pass ที่ PF≥1.2 AND Trades≥60 + top-8 ดิบ (Pass/PF/Trades/EqDD%/4 params) ·
commit `[tag] ORDER-028 done`
**ห้าม:** verdict/เลือก plateau-center (Claude ทำ) · ⚠️ ทอง+grid = DD สูงเป็นปกติ, รายงานดิบ อย่ากรองด้วย DD

**ผล (Codex, Model 1, MT5 เลน 2; ไม่มี verdict):** สร้าง
`ea_template\sets\Boss14_GridLog_XAU_opt1.set`; lock input อื่นด้วย `||N`, ปิด fixed-money TP,
ปิด SL pip-cap และใช้ magic 990301. เนื่องจาก MT5 range แทน `{0.5,1.0,2.0}` แบบ non-uniform
สามค่าพอดีไม่ได้ จึงใช้ `0.5..2.0 step 0.5` ซึ่งเพิ่ม 1.5 เป็นค่าที่สี่.

XML `BOSS14_OPT_XAU_IS.xml` ครบ **72 rows**; จำนวน pass ที่ `PF≥1.2 AND Trades≥60` = **11**.
Top-8 ดิบเรียง PF:

| Pass | PF | Trades | EqDD% | StepATR | Direction | DistATR | BasketTP_ATRmult |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 2 | 1.486584 | 275 | 9.3197 | 3.0 | 1 | 1.4 | 0.5 |
| 20 | 1.479022 | 277 | 9.3377 | 3.0 | 1 | 1.4 | 1.0 |
| 38 | 1.368226 | 285 | 10.3119 | 3.0 | 1 | 1.4 | 1.5 |
| 14 | 1.334668 | 131 | 10.1337 | 3.0 | 1 | 3.0 | 0.5 |
| 18 | 1.329613 | 348 | 18.7271 | 1.4 | 1 | 1.4 | 1.0 |
| 0 | 1.319394 | 347 | 18.8011 | 1.4 | 1 | 1.4 | 0.5 |
| 36 | 1.260917 | 362 | 19.3601 | 1.4 | 1 | 1.4 | 1.5 |
| 32 | 1.253519 | 139 | 10.2949 | 3.0 | 1 | 3.0 | 1.0 |

---

## ORDER-029 — mold fix: `_33_SL_MaxPips` ให้ portable ข้าม instrument (bug จาก ORDER-027 scan) — `REVIEWED(Claude/Opus, 2026-07-05 — เลือก Option B → implement = ORDER-029B)` · ทำได้: Codex/Claude/oc-dev · 👉 Codex-direct

**REVIEW (Claude/Opus): เลือก Option B (ATR-relative cap `_33_SL_MaxATRmult`, default 0=เดิม).** เหตุผล:
เป็น portability seam จริงตาม volatility (ตรงกับที่ทั้ง GridLog scale ด้วย ATR อยู่แล้ว) + additive แท้ +
กันพังซ้ำบน index/crypto (Option A = digit heuristic เป็น band-aid จะพังอีก). ไม่เร่ง — workaround `=0` ใช้ได้.
→ implement = **ORDER-029B**

**ทำไม:** `_33_SL_MaxPips` (ExitManager.mqh ~40) ใช้ `pipPrice=(digits==3||5?10:1)×Point` → บน XAU (2 digits)
= Point = 0.01 → cap 150 กลายเป็น **$1.50** (ควรเป็นหลัก $ ใหญ่). ทำให้ SL cap พังบน non-FX. เป็น fixed-pip
param ตัวที่ 2 ที่ไม่ scale (ตัวแรก = fixed-$ TP แก้แล้วใน 027). **workaround ตอนนี้: ตั้ง `_33_SL_MaxPips=0`
(ปิด) ใน non-FX set** — ATR-SL คุมเอง portable อยู่แล้ว. แต่ default ที่พังบน XAU = foot-gun ควรแก้ถาวร

**สเปค (additive, default พฤติกรรมเดิม):** เปลี่ยนนิยาม cap ให้ digit-aware สำหรับ 2-digit metals หรือ
(ดีกว่า) เพิ่มโหมด **ATR-relative cap** — แต่ทางที่ง่าย+ปลอดภัยสุด: ถ้า `_33_SL_MaxPips>0` แต่ digits∉{3,5}
(เช่น XAU 2-digit) ให้ตีความ pip เป็น `10×Point` เหมือนกัน (ให้ 150→$15 แทน $1.50) **หรือ** เพิ่ม input
`_33_SL_MaxATRmult` (ATR-relative cap, default 0=ใช้ pip เดิม) แบบเดียวกับ ORDER-027. Claude เลือกทางตอน review
proposal — **order นี้ให้ Codex เสนอ 2 ทางเลือก + ผลกระทบ ไม่ต้อง implement จนกว่า Claude เคาะ** (stage A แบบ ORDER-008A)
**Acceptance:** ข้อเสนอ 2 ทาง + จุดกระทบ (บรรทัดไหน, EA ไหน) · ยังไม่แตะ core · commit `[tag] ORDER-029A done`

**ผล (Codex, stage A เท่านั้น — ไม่ได้แตะ core):** จุดกระทบปัจจุบันคือ
`core/Inputs.mqh:219` (`_33_SL_MaxPips`), `core/ExitManager.mqh:36-42`
(`Exit_CapATRDist`) และ caller สองจุดที่ `Exit_SLDistancePoints`/`Exit_InitialSL` (~52/~81).
Boss_11/12/13/14 include core เดียวกัน จึงกระทบทุก wrapper เมื่อ `SLMode=33` และ cap > 0;
set FX จำนวนมากใช้ 150 อยู่แล้ว ส่วน XAU opt set ใช้ workaround = 0.

| ทางเลือก | การเปลี่ยน | พฤติกรรม/ผลกระทบ | Compatibility / test |
|---|---|---|---|
| **A — digit heuristic** | ใน `Exit_CapATRDist`, ใช้ `pipPrice=10×Point` เมื่อ digits ไม่ใช่ 3/5 ด้วย | XAU 2-digit: 150 cap เปลี่ยนจาก `$1.50` เป็น `$15`; ไม่ต้องเพิ่ม input/set แต่ 10×Point ยังเป็น heuristic และอาจไม่สื่อความหมายบน index/crypto หรือ broker digits อื่น | FX 3/5-digit ไม่เปลี่ยน; non-FX ที่ cap>0 เปลี่ยนทันที. ต้อง compile Boss 11–14 + tpl regression + XAU A/B |
| **B — ATR-relative cap** | เพิ่ม `_33_SL_MaxATRmult=0`; ถ้า >0 ใช้ `cap=RiskATR×mult`, ถ้า =0 ใช้ `_33_SL_MaxPips` เดิม | portable ตาม volatility/instrument จริง; ผู้ใช้เลือก ceiling เช่น SL=4×ATR แต่ cap=3×ATR ได้. เพิ่ม input หนึ่งตัวและต้องระบุ/lock ใน opt sets ใหม่ | default 0 ทำให้ FX/sets เดิมเหมือนเดิม; XAU เปลี่ยนเฉพาะ set ที่ opt-in. ต้อง compile Boss 11–14 + tpl regression + A/B ค่า ATR cap |

ข้อสังเกตเชิงวิศวกรรม: ทาง A แก้ XAU ได้เร็วและ diff เล็ก แต่ไม่ได้แก้ semantics ของ “pip” สำหรับ
instrument class ทั้งหมด; ทาง B เป็น portability seam ที่ตรงกว่าและ additive จริง แต่เพิ่ม parameter/interface.
จนกว่า Claude เคาะ ใช้ workaround `_33_SL_MaxPips=0` สำหรับ non-FX ต่อได้โดยไม่แก้ source.

---

## 🏭 XAU GridLog VALIDATION PIPELINE (รันตามลำดับ 030→031; Claude review ตอนกลับมา) — ต่อ ORDER-028

> **สถานะ: XAU GridLog = candidate #7 (in-sample PF 1.48). ต้องผ่านครบ pipeline เหมือน Boss_14 FX
> ก่อนขึ้น demo. ทอง+grid = สงสัยสูงสุด, Model-4 บังคับ.** set = `Boss14_GridLog_XAU_ISpick.set` (สร้างแล้ว)

## ORDER-030 — XAU: fresh-start OOS + full-window + year-split — `DONE(Codex, 2026-07-05 11:49 +07:00)` · **ทำได้: ZCode · Codex · oc-btest** · 👉 **แนะ: ZCode** (heavy) (role: batch, เลน 2)

**ทำไม:** ด่านชี้ขาด — IS-opt เป็น in-sample, ต้องดูว่ารอด out-of-sample ไหม (GBPAUD/NZDUSD-SELL ตายด่านนี้มาแล้ว)
```powershell
# (1) fresh-start OOS
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol XAUUSD -Period H1 -FromDate 2025.07.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_XAU_ISpick.set' -ReportName BOSS14_XAU_OOS_M1 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
# (2) full-window confirm + year-split
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_XAU_ISpick.set' -ReportName BOSS14_XAU_FULL_ISPICK_M1 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\report_year_split.py D:\EA_LAB\_mt5_auto\reports\BOSS14_XAU_FULL_ISPICK_M1.htm
```
**Acceptance:** OOS (trades/PF/net/eqDD) + full year-split ทุกบรรทัด · commit `[tag] ORDER-030 done`
**ห้าม:** verdict — เกณฑ์ Claude: OOS PF≥0.9 + ทุกปีไม่มีปีเน่าซ่อน (ทองต้องเข้มกว่า FX)

**ผล (Codex, Model 1, MT5 เลน 2; ไม่มี verdict):**

| Window | Trades | PF | Net | EqDD maximal |
|---|---:|---:|---:|---:|
| fresh OOS 2025.07–2026.07 | 196 | 1.15 | +897.71 | 27.02% |
| full 2023.01–2026.07 | 426 | 1.42 | +3106.99 | 23.34% |

Year split จาก full report:

| Period | Trades | PF | Net | Balance DD |
|---|---:|---:|---:|---:|
| FULL | 426 | 1.42 | +3106.99 | 15.42% |
| 2023 | 53 | 1.20 | +162.65 | 3.73% |
| 2024 | 121 | 2.31 | +1015.95 | 3.21% |
| 2025 | 215 | 1.31 | +1056.53 | 7.53% |
| 2026 | 37 | 1.37 | +871.86 | 18.05% |

---

## ORDER-031 — XAU: Monte Carlo + Model-4 every-tick (ทอง+grid บังคับ) — `OPEN` · **ทำได้: ZCode** · 👉 **แนะ: ZCode** · ⚠️ **Model-4 รันเดี่ยว ห้ามคู่ขนาน** (freeze guard) · **ทำหลัง ORDER-030 ผ่านเท่านั้น** (role: batch, เลน 2)

**ทำไม:** ทอง+grid = floating DD ซ่อน (บทเรียน Recovery M4). closed-trade DD 9% ต้องยืนยันด้วย every-tick จริง
```powershell
# (1) MC บน full report
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\BOSS14_XAU_FULL_ISPICK_M1.htm --deposit 10000 --iters 5000
# (2) Model-4 every-tick (2024-2026; รันเดี่ยว)
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol XAUUSD -Period H1 -FromDate 2024.01.01 -ToDate 2026.07.01 -Model 4 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_XAU_ISpick.set' -ReportName BOSS14_XAU_M4CONFIRM -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
```
**Acceptance:** MC (DD median/95th/worst, ruin, P(loss)) + M4 (PF/trades/net/**equity DD maximal %**/history quality) ·
commit `[tag] ORDER-031 done`
**ห้าม:** verdict — เกณฑ์ Claude: M4 PF ไม่ร่วงหนัก (เทียบ M1 1.48) + floating DD ยอมรับได้ที่ de-scaled lot

**ผล:** _(รอ)_

---

## ORDER-032 — XAG (silver) GridLog: IS-optimize (non-FX ตัวที่ 2, ขนาน XAU) — `OPEN` · **ทำได้: ZCode · oc-btest** · 👉 **แนะ: ZCode** (heavy, วันแยกจาก 030/031) (role: batch, เลน 2)

**ทำไม:** ถ้าทองมีชีวิต เงินอาจมีด้วย (non-FX เพิ่ม) — mirror ORDER-028 เป๊ะแต่ symbol=XAGUSD
สร้าง `Boss14_GridLog_XAG_opt1.set` = copy `Boss14_GridLog_XAU_opt1.set` (มีแล้ว) เปลี่ยน magic=990302 ·
`_2_BasketTP_Money=0` · `_33_SL_MaxPips=0` · optimize axes เดิม (Step 1.4/2.2/3.0 · Dist 1.4/2.2/3.0 ·
BasketTP_ATRmult 0.5/1.0/1.5/2.0 · Direction 1,2 · lock ที่เหลือ `||N`)
```powershell
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol XAGUSD -Period H1 -FromDate 2023.01.01 -ToDate 2025.06.30 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_XAG_opt1.set' -ReportName BOSS14_OPT_XAG_IS -TimeoutSec 21600 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
```
**Acceptance:** XML ครบ + จำนวน pass PF≥1.2 & Trades≥60 + top-8 ดิบ · commit `[tag] ORDER-032 done`
**ห้าม:** verdict/plateau-center (Claude ทำ)

**ผล:** _(รอ)_

---

## ORDER-029B — implement Option B: `_33_SL_MaxATRmult` (ATR-relative SL cap, additive) — `OPEN` · **ทำได้: Codex · Claude · oc-dev (❌ ZCode)** · 👉 **แนะ: Codex-direct** · ⚠️ **tpl_regression CLEAN + compile 0/0 ก่อน commit** · (priority: ต่ำ, workaround `_33_SL_MaxPips=0` ใช้ได้)

**สเปค (Option B ที่ approve):** `core\Inputs.mqh`: เพิ่ม `input double _33_SL_MaxATRmult = 0;` (ใกล้ `_33_SL_MaxPips`) ·
`core\ExitManager.mqh` `Exit_CapATRDist`: ถ้า `_33_SL_MaxATRmult > 0` → `cap = Indi_RiskATR(0) × _33_SL_MaxATRmult`
(price units) แทน pip-cap · ถ้า `=0` → ใช้ `_33_SL_MaxPips` เดิมทุกอย่าง (default = พฤติกรรมเดิมเป๊ะ)
**Acceptance:** compile 0/0 Boss_11-14 · **tpl_regression CLEAN** (default 0 = ไม่ drift) · A/B 1 ตัว: XAU
`_33_SL_MaxATRmult=6` (≈SL 4×ATR แต่ cap 6×ATR = หลวมพอไม่บีบ) เทียบ `=0`+`_33_SL_MaxPips=0` — ควรใกล้กัน ·
commit `[tag] ORDER-029B done`
**ห้าม:** เปลี่ยน default `_33_SL_MaxPips` · แตะ SL logic อื่น

**ผล:** _(รอ)_

---

## ORDER-033 — smoke-screen 4 MT5 signal EAs จาก `wait for test` (idle-compute filter) — `OPEN` · **ทำได้: Codex · oc-dev** (ต้อง compile source ก่อน — ❌ ZCode) · 👉 **แนะ: Codex-direct หรือ oc-dev** (งาน compile+run) (role: code+batch)

**ทำไม (user: อยากให้คอมมีงานทำช่วง token reset):** folder `D:\Forex\10_EA_PROJECTS\2. wait for test` มี 87 EA
แต่ **mq4 37 ตัว = ใช้ไปป์ไลน์ MT5 ไม่ได้ (0/63 prior) · mq5 ส่วนใหญ่ grid/martingale = dead-family**. คัดเหลือ
**4 ตัว mq5 risk=fixed (ไม่ใช่ grid)** ที่คุ้ม smoke — 2 ตัวแรกกลไกใหม่จริง (ORDER-021). base dir = `D:\Forex\10_EA_PROJECTS\2. wait for test\`

**งาน — ต่อ EA: compile → smoke:**
| # | ไฟล์ (relative จาก base) | home symbol/TF ลอง | หมายเหตุ |
|---|---|---|---|
| 1 | `2026-07\Breakout Retest Pro EA Source Code (1).mq5` | XAUUSD H1 + EURUSD H1 | native MT5 ⭐ retest-zone |
| 2 | `2025-08\GapFillRSI\GapFillRSI.mq5` | XAUUSD H1 + US30 H1 (ถ้ามี) | native MT5 ⭐ gap-fade |
| 3 | `(OH) EA\(oh)  Bot V00.mq5` | EURUSD H1 + XAUUSD H1 | fxdreema-origin, friction สูง |
| 4 | `EA fxdreema other id\(Niyombot) B2 Gold Deng M15 TLM.mq5` | XAUUSD M15 | fxdreema-origin gold |

ขั้นตอนต่อ EA: (1) compile ด้วย metaeditor CLI (ดู `ea_template\deploy.ps1` เป็นแบบ) → ถ้า compile ไม่ผ่าน/
ไม่มี tester-gate ให้ note แล้วข้าม (2) หา input `AllowLive`/tester-gate เปิดให้ tester เทรดได้ (บทเรียน Bucket D)
(3) Model 2 quick 3 เดือนล่าสุด — ถ้า 0 trades = non-functional port, note+ข้าม (4) ถ้าเทรด → Model 1 12 เดือน
(2025.07-2026.07) home symbol · report PF/trades/net/eqDD
**Acceptance:** ตารางต่อ EA×symbol: compile ok? / Model2 trades / Model1 PF·trades·net·eqDD (หรือเหตุที่ข้าม) ·
commit `[tag] ORDER-033 done`
**ห้าม:** verdict (Claude ตัดสิน) · **อย่าเสียเวลากับตัวที่ compile ไม่ผ่าน/hang เกิน 2 ครั้ง — note แล้วไปตัวถัดไป**
(บทเรียน Bucket D: MT4-origin ports ส่วนใหญ่ไม่ทำงาน — คาดหวัง survivor น้อย, นี่คือ filter ราคาถูก ไม่ใช่ hunt หลัก)

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

---

## ORDER-014 — Model-4 (real ticks) confirm ของ DEMO cohort 3 ตัว — `REVIEWED(Claude: DEMO ยืนทั้ง 3 บน real ticks ✅ — USDJPY 1.72/107t · AUDNZD 3.37/44t (แชมป์อีกรอบ) · ⚠️ EURJPY 1.51/110t eqDD 10.02% = FILL-SENSITIVE (จาก M1-คลาส ~2.5) → demo จับตาตัวนี้พิเศษ + ตอน promote ต้อง size ต่ำกว่าเพื่อน)` (role: ZCode/Codex, MT5 = ต้อง full-approval)

**ทำไม (จาก /scrutinize 2026-07-04):** pipeline ข้าม every-tick confirm ที่ backtest-optimize-rigor บังคับ — Model 1 ไม่จำลอง spread/slippage จริงของ market-fill บน resting-stop
```powershell
# แทน <SYM> ด้วย USDJPY, AUDNZD, EURJPY (Model 4 = real ticks; ถ้า broker ไม่มี tick ช่วงเก่า ให้รายงานช่วงที่มีจริง)
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol <SYM> -Period H1 -FromDate 2024.01.01 -ToDate 2026.07.01 -Model 4 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_<SYM>_DEMO.set' -ReportName BOSS14_<SYM>_M4CONFIRM
```
**Acceptance:** ต่อ symbol: trades/PF/net/eqDD + history quality % + ถ้า tick ไม่ครบช่วงให้ระบุช่วงจริง · commit `[tag] ORDER-014 done`
**ห้าม:** verdict — Claude เทียบกับ Model 1 เอง (คาด PF ลดลงบ้าง; ลดมาก = fill-sensitivity สูง)

**ผล (oc-btest, Model 4 real ticks, 2026-07-04):**

Reports:
- `D:\EA_LAB\_mt5_auto\reports\BOSS14_USDJPY_M4CONFIRM.htm`
- `D:\EA_LAB\_mt5_auto\reports\BOSS14_AUDNZD_M4CONFIRM.htm`
- `D:\EA_LAB\_mt5_auto\reports\BOSS14_EURJPY_M4CONFIRM.htm`

Main stats (raw MT5 report):

| Symbol | Report period | History quality | Bars | Ticks | Trades | PF | Net | Equity DD maximal |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| USDJPY | 2024.01.01..2026.07.01 | 100% real ticks | 15,528 | 70,255,450 | 107 | 1.72 | +818.93 | 421.44 (3.84%) |
| AUDNZD | 2024.01.01..2026.07.01 | 99% real ticks | 15,528 | 79,984,320 | 44 | 3.37 | +831.09 | 247.07 (2.26%) |
| EURJPY | 2024.01.01..2026.07.01 | 99% real ticks | 15,528 | 104,690,336 | 110 | 1.51 | +1,250.04 | 1,102.21 (10.02%) |

Tick/data range note: all three reports show the requested full report period `2024.01.01..2026.07.01`; no truncated report period was indicated. History quality is as listed above (AUDNZD/EURJPY are 99% real ticks, not 100%).

Year split (`scripts\report_year_split.py`, raw closed-deal balance stats):

| Symbol | Year | Trades | PF | Net | BalDD |
|---|---:|---:|---:|---:|---:|
| USDJPY | FULL | 107 | 1.72 | +818.93 | 2.83% |
| USDJPY | 2024 | 89 | 1.98 | +826.64 | 2.83% |
| USDJPY | 2026 | 18 | 0.97 | -7.71 | 2.18% |
| AUDNZD | FULL | 44 | 3.37 | +831.09 | 0.97% |
| AUDNZD | 2024 | 13 | 2.70 | +184.82 | 0.82% |
| AUDNZD | 2025 | 2 | inf | +64.98 | 0.00% |
| AUDNZD | 2026 | 29 | 3.40 | +581.29 | 0.99% |
| EURJPY | FULL | 110 | 1.51 | +1,250.04 | 8.26% |
| EURJPY | 2024 | 53 | 1.01 | +16.66 | 8.26% |
| EURJPY | 2025 | 41 | 3.23 | +1,225.14 | 2.58% |
| EURJPY | 2026 | 16 | 1.02 | +8.24 | 3.76% |










