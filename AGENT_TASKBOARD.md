# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(Claude)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = Claude/user เท่านั้น
>
> 🏁 **track merge EA_CORE → Boss V2: ปิดแล้ว (เปิด+จบ 2026-07-06)** — อะไหล่เข้าแม่พิมพ์ครบ
> (pyramid 93 · acct-DD gate · Persist · tests\) + EA_Project = read-only archive · บันทึกเต็ม →
> `AGENT_TASKBOARD_MERGE.md` (เหลือ MERGE-07 Entry_ST03 = HOLD ถึง judge — เงื่อนไขอยู่ในบอร์ดนั้น)

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

## ORDER-017 — Model-4 confirm cohort-2 (3 ตัว) + สร้าง DEMO sets — `REVIEWED(Claude, 2026-07-06 — เก็บตกสถานะ: ผลถูก review+ใช้จริงตั้งแต่ 07-04 (cohort-2 เข้า DEMO bench, verdict อยู่ PROJECT_STATE HANDOFF 07-04 + DEMO_DEPLOYMENT_PLAN) แต่แถวนี้ไม่เคยถูก flip — dashboard STATUS.html จับได้)` (role: oc-btest)

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

## ORDER-030 — XAU: fresh-start OOS + full-window + year-split — `REVIEWED(Claude/Opus, 2026-07-05 — ✅ ผ่าน OOS gate (CONDITIONAL) → ORDER-031 Model-4)` · ทำได้: ZCode/Codex/oc-btest

**VERDICT (Claude/Opus): ✅ XAU GridLog ผ่านด่าน OOS — CONDITIONAL PASS (candidate non-FX ตัวแรกที่รอด OOS)**
OOS 2025.07-26.07 = 196t/PF 1.15/+$897 (ผ่าน gate ≥0.9, เทรดเยอะพอ) · **ทุกปีบวก 1.20/2.31/1.31/1.37 =
ไม่มีปีเน่า** (ผ่าน year-split ที่ฆ่า NZDUSD/GBPAUD) · full 1.42/426t. **⚠️ 2 เงื่อนไขก่อนเชื่อ:** (1) **DD สูงมาก
27% @0.25x** → cap-breach = de-scale ไม่ reject, ต้องลด lot ~ครึ่ง FX cohort ให้เข้า budget 10-15% (2) **Model-1
หลอกได้กับ grid (บทเรียน Recovery) → Model-4 = ด่านชี้ขาด** → **ORDER-031 (unblocked)** · edge จริงแต่ modest (1.15 vs FX 2-3)

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

## ORDER-031 — XAU: Monte Carlo + Model-4 every-tick (ทอง+grid บังคับ) — `REVIEWED(Claude/Opus, 2026-07-05 — 🎉 XAU ผ่านครบ = candidate #7 non-FX; de-scaled DEMO set สร้างแล้ว)` · ทำได้: ZCode

**VERDICT (Claude/Opus): 🎉 XAU GridLog = PASS ครบ pipeline → CANDIDATE #7 (non-FX diversifier ตัวแรก)**
**Model-4 real ticks = edge รอด!** net +$5,078 / DD 19.95% (2024-26) — **ไม่ร่วงแบบ Recovery** (ทอง+grid ยืนบน
every-tick ได้จริง = ต่างจาก mechanism ที่ Model-1 หลอก). MC: ruin 0% · P(loss) 0% · DD 95th 29.6%/worst 42.9%
(@0.25x). **เงื่อนไขเดียว = DD สูง → de-scale:** สร้าง `Boss14_GridLog_XAU_DEMO.set` แล้ว (lot 0.10→**0.05**,
magic **990207**=#7, ATR-TP auto-scale + ATR-SL → de-scale สะอาด). ที่ 0.05 คาด DD ~10-15% เข้า budget · **candidate
#7 พร้อมเข้า demo cohort เมื่อ user attach** (รอ user "ยังไม่ว่าง" — ดู DEMO_DEPLOYMENT_PLAN §Boss_14 cohort).
⚠️ ก่อน demo: (1) corr check vs 6 FX (ทองน่าจะ low-corr = diversifier ดี) (2) จับตา DD พิเศษ (leg เสี่ยงสุดในพอร์ต)

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

**ผล (Codex; ไม่มี verdict):**

Monte Carlo บน `D:\EA_LAB\_mt5_auto\reports\BOSS14_XAU_FULL_ISPICK_M1.htm`
- trades used: **426** | deposit **10000** | iterations **5000**
- actual net: **3106.99**
- max drawdown %: **median 21.09 | 95th 29.62 | worst 42.94**
- ruin risk (net <= -deposit): **0.00%**
- P(net profit < 0): **0.0%**

Model-4 every-tick บน `D:\EA_LAB\_mt5_auto\reports\BOSS14_XAU_M4CONFIRM.htm`
- report period: **2024.01.01..2026.07.01**
- history quality: **100% real ticks**
- bars/ticks: **14,760 / 125,670,341**
- trades: **364**
- profit factor: **1.97**
- net profit: **5078.12**
- equity drawdown maximal: **589.10 (19.95%)**

---

## ORDER-032 — XAG (silver) GridLog: IS-optimize (non-FX ตัวที่ 2, ขนาน XAU) — `REVIEWED(Claude/Opus, 2026-07-05 — 🅿️ PARK-thin, ทองแข็งกว่า)` · ทำได้: ZCode/oc-btest

**VERDICT (Claude/Opus): 🅿️ XAG = PARK (thin/weak)** — qualifying แค่ 4 pass ที่ PF≥1.2&≥60t (XAU มี 11) ·
top-PF (8.87) เป็น **27 trades = thin artifact** ไม่ใช่ edge จริง · เงินบางกว่าทองชัด → **ไม่คุ้ม full pipeline
ตอนนี้** โฟกัสทอง (XAU) ก่อน · re-examine XAG เฉพาะถ้า XAU ผ่านครบแล้วอยากได้ non-FX ตัวที่ 2

**ทำไม:** ถ้าทองมีชีวิต เงินอาจมีด้วย (non-FX เพิ่ม) — mirror ORDER-028 เป๊ะแต่ symbol=XAGUSD
สร้าง `Boss14_GridLog_XAG_opt1.set` = copy `Boss14_GridLog_XAU_opt1.set` (มีแล้ว) เปลี่ยน magic=990302 ·
`_2_BasketTP_Money=0` · `_33_SL_MaxPips=0` · optimize axes เดิม (Step 1.4/2.2/3.0 · Dist 1.4/2.2/3.0 ·
BasketTP_ATRmult 0.5/1.0/1.5/2.0 · Direction 1,2 · lock ที่เหลือ `||N`)
```powershell
powershell -File D:\EA_LAB\scripts\mt5_optimize.ps1 -Expert 'EALabTpl\Boss_14_GridLog' -Symbol XAGUSD -Period H1 -FromDate 2023.01.01 -ToDate 2025.06.30 -Model 1 -Optimization 1 -SetFile 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_XAG_opt1.set' -ReportName BOSS14_OPT_XAG_IS -TimeoutSec 21600 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
```
**Acceptance:** XML ครบ + จำนวน pass PF≥1.2 & Trades≥60 + top-8 ดิบ · commit `[tag] ORDER-032 done`
**ห้าม:** verdict/plateau-center (Claude ทำ)

**ผล (Codex, Model 1, MT5 เลน 2; ไม่มี verdict):** สร้าง
`ea_template\sets\Boss14_GridLog_XAG_opt1.set` จาก XAU set, magic=990302 และ lock input ใหม่
`_33_SL_MaxATRmult=0`. XML `BOSS14_OPT_XAG_IS.xml` ครบ **72 rows**; จำนวน pass ที่
`PF≥1.2 AND Trades≥60` = **4**. Top-8 ดิบเรียง PF:

| Pass | PF | Trades | EqDD% | StepATR | Direction | DistATR | BasketTP_ATRmult |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 27 | 8.873273 | 27 | 2.0831 | 1.4 | 2 | 2.2 | 1.0 |
| 28 | 8.873273 | 27 | 2.0831 | 2.2 | 2 | 2.2 | 1.0 |
| 29 | 8.873273 | 27 | 2.0831 | 3.0 | 2 | 2.2 | 1.0 |
| 9 | 8.873273 | 27 | 2.0831 | 1.4 | 2 | 2.2 | 0.5 |
| 10 | 8.873273 | 27 | 2.0831 | 2.2 | 2 | 2.2 | 0.5 |
| 11 | 8.873273 | 27 | 2.0831 | 3.0 | 2 | 2.2 | 0.5 |
| 63 | 8.873273 | 27 | 2.0831 | 1.4 | 2 | 2.2 | 2.0 |
| 64 | 8.873273 | 27 | 2.0831 | 2.2 | 2 | 2.2 | 2.0 |

---

## ORDER-029B — implement Option B: `_33_SL_MaxATRmult` (ATR-relative SL cap, additive) — `REVIEWED(Claude/Opus, 2026-07-05 — ✅ ACCEPT, verify tpl_regression CLEAN เอง)` · ทำได้: Codex/Claude/oc-dev

**VERDICT: ✅ ACCEPT** — verify tpl_regression เอง = CLEAN ทั้ง 3 (additive default-off inert). mold portable
สำหรับ non-FX แล้ว (ATR-relative SL cap). ต่อไป non-FX set ใช้ `_33_SL_MaxATRmult` ได้แทน workaround `_33_SL_MaxPips=0`

**สเปค (Option B ที่ approve):** `core\Inputs.mqh`: เพิ่ม `input double _33_SL_MaxATRmult = 0;` (ใกล้ `_33_SL_MaxPips`) ·
`core\ExitManager.mqh` `Exit_CapATRDist`: ถ้า `_33_SL_MaxATRmult > 0` → `cap = Indi_RiskATR(0) × _33_SL_MaxATRmult`
(price units) แทน pip-cap · ถ้า `=0` → ใช้ `_33_SL_MaxPips` เดิมทุกอย่าง (default = พฤติกรรมเดิมเป๊ะ)
**Acceptance:** compile 0/0 Boss_11-14 · **tpl_regression CLEAN** (default 0 = ไม่ drift) · A/B 1 ตัว: XAU
`_33_SL_MaxATRmult=6` (≈SL 4×ATR แต่ cap 6×ATR = หลวมพอไม่บีบ) เทียบ `=0`+`_33_SL_MaxPips=0` — ควรใกล้กัน ·
commit `[tag] ORDER-029B done`
**ห้าม:** เปลี่ยน default `_33_SL_MaxPips` · แตะ SL logic อื่น

**ผล (Codex, Model 1; ไม่มี verdict):** เพิ่ม `_33_SL_MaxATRmult=0` ใน `Inputs.mqh`; เมื่อ >0
`Exit_CapATRDist()` ใช้ `Indi_RiskATR(0) × mult` เป็น ceiling และเมื่อ =0 ยังใช้ pip-cap เดิม.
- compile Boss_11/12/13/14: **0 errors / 0 warnings**
- `scripts\tpl_regression.ps1`: **REGRESSION CLEAN**
- A/B XAU H1 full 2023.01–2026.07: baseline (`MaxPips=0`, ATR cap=0) เทียบ ATR cap=6.0 ให้ผลตรงกัน:
  **426 trades, PF 1.42, net 3106.99, EqDD 23.34%, BalanceDD 15.42%** ทั้งคู่; delta ทุก metric = 0.

---

## ORDER-033 — smoke-screen 4 MT5 signal EAs จาก `wait for test` (idle-compute filter) — `REVIEWED(Claude/Opus, 2026-07-05 — ❌ ไม่มี survivor; ตอกย้ำต้อง mass-smoke เต็ม)` · ทำได้: Codex/oc-dev

**VERDICT: ❌ ไม่มี survivor** — Breakout Retest Pro (EUR PF 0.76 / XAU เจ๊ง -$4950) · GapFillRSI (0 trades =
non-functional as-is) · Bot V00 (EUR PF 1.37 **แต่ DD 42.9%** = grid churn ไม่ใช่ edge). 2 "กลไกใหม่" ที่หวัง
(Retest/GapFill) ไม่ติด — ตรง Bucket D lesson (MT4-origin ports ไม่ทำงาน). **แต่ user มี signal ว่ามี treasure
→ ยังคุ้ม mass-smoke เต็ม (034-036, 2,623 ตัว) ไม่ใช่แค่ 4 ตัวนี้**

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

**ผล (Codex; ไม่มี verdict):** compile ด้วย MetaEditor แล้ว deploy EX5 ชื่อ sanitized เข้า MT5 เลน 2.
M2 = 2026.04–2026.07; M1 = 2025.07–2026.07. ไม่พบ AllowLive gate ที่ต้อง override.

| EA | Symbol/TF | Compile | M2 trades | M1 PF | M1 trades | M1 net | M1 EqDD% / เหตุข้าม |
|---|---|---|---:|---:|---:|---:|---|
| Breakout Retest Pro | XAUUSD H1 | 0 errors / 0 warnings | 1 | 0.00 | 1 | -4950.75 | 67.19% |
| Breakout Retest Pro | EURUSD H1 | 0 errors / 0 warnings | 18 | 0.76 | 53 | -965.49 | 15.71% |
| GapFillRSI | XAUUSD H1 | 0 errors / 0 warnings | 0 | — | — | — | ข้าม M1: M2 zero-trade |
| GapFillRSI | US30 H1 | 0 errors / 0 warnings | 0 | — | — | — | ข้าม M1: M2 zero-trade |
| (oh) Bot V00 | EURUSD H1 | 0 errors / 2 deprecated warnings | 24 | 1.37 | 122 | +2307.69 | 42.90% |
| (oh) Bot V00 | XAUUSD H1 | 0 errors / 2 deprecated warnings | 53 | 0.69 | 111 | -7916.33 | 89.50% |
| Niyombot B2 Gold | XAUUSD M15 | 0 errors / 0 warnings | 1 | 0.16 | 16 | -9157.90 | 94.26% |

Compile logs: `_mt5_auto\compile_waittest\`. OH warnings คือ deprecated
`ACCOUNT_FREEMARGIN` และ `POSITION_COMMISSION`; ไม่ได้แก้ source ตาม scope smoke-only.

---

## 🗺️ MASS-SMOKE `wait for test` (user 2026-07-05: เคยเห็นตัวรันดีในนั้น — เทสทั้ง ex4+ex5, autonomous ช่วง token reset)

> **ขนาดจริง: 337 unique .ex5 + 2,286 unique .ex4 = 2,623 ตัว** (dump ใหญ่ ปน indicator/utility/dashboard).
> tooling ครบ: MT5 `mt5_run.ps1`+`smoke_all.ps1` · MT4 `mt4_run.ps1`+`parse_mt4_report.py` (`D:\Meta4`).
> **funnel: 034 catalog → 035 MT5 smoke → 036 MT4 smoke.** ORDER-033 (4-EA) = subset ของ 035, ทำก่อนได้เป็น warm-up

## ORDER-034 — catalog + dedup + กรอง tradeable-EA จาก `wait for test` — `REVIEWED(Claude/Opus, 2026-07-05 — worklist พร้อม: 1,521 candidates → 035/036 unblocked)` · ทำได้: Codex/Claude/oc-dev

**REVIEW:** filter สะอาด — 3,161 ดิบ → 2,625 unique → **1,521 tradeable** (ตัด indicator/dashboard ~1,100) ·
**ex5 203 + ex4 1,318** · `_triage/mass_smoke_worklist.csv` พร้อม → **ORDER-035 (MT5 203) + 036 (MT4 1,318 stage) unblocked**

**ทำไม:** ห้าม smoke 2,623 ดิบ (ครึ่งเป็น indicator/dashboard/ตัวซ้ำ = เผา compute เปล่า) ต้องได้ worklist สะอาดก่อน
**งาน (ต่อ `ea_inventory.py`):** (1) hash ทุก .ex4/.ex5 ใน `D:\Forex\10_EA_PROJECTS\2. wait for test` เก็บ 1 path/hash
(dedup) (2) กรองออกที่ไม่ใช่ EA เทรด (ชื่อมี indicator/dashboard/scanner/copier/trailing/template/tool/panel/
scheduler) (3) mark platform ex4/ex5 (4) เดา home symbol จากชื่อ (gold/XAU→XAUUSD, ไม่มี→basket) →
`_triage/mass_smoke_worklist.csv` (platform, hash, path, guess_symbol, guess_type)
**Acceptance:** CSV + นับ unique tradeable EA ต่อ platform · commit `[tag] ORDER-034 done` · **ห้าม:** smoke จริง/verdict

**ผล (Codex; catalog เท่านั้น ไม่มี smoke/verdict):** เพิ่มโหมด
`ea_inventory.py --worklist <root> <csv>` และสร้าง `_triage/mass_smoke_worklist.csv`.

- compiled files ดิบ: **3,161** · unique hashes ทั้งหมด: **2,625**
- หลังกรองชื่อ non-tradeable + dedup: **1,521 unique candidates**
- platform: **EX4 1,318** · **EX5 203**
- guess symbol: **XAUUSD 92** · **basket 1,429**
- guess type: unknown-ea 1,253 · trend 107 · grid-recovery 94 · scalper 48 · breakout 19
- validation: 1,521 rows = 1,521 unique hashes, ไม่มี blacklist-name leak, platform มีเฉพาะ ex4/ex5,
  และ `guess_symbol` ตรงกฎ gold/XAU→XAUUSD ทุกแถว.

## ORDER-035 — MT5 mass-smoke driver (loop worklist ex5) — `REVIEWED(Claude/Opus, 2026-07-05 — 39 survivor, ส่วนใหญ่กับดัก Model-1; คัด 3 → ORDER-037 artifact-check)` · ทำได้: Codex/oc-dev (ดู REVIEW note ใต้ตาราง survivor)

**งาน (reuse `smoke_all.ps1`):** ต่อ ex5: copy → `<Meta5b>\MQL5\Experts\_smoke\` → Model 2 quick 3 เดือน
(2026.04-2026.07) basket **XAUUSD, EURUSD, USDJPY, AUDNZD** H1 (user 2026-07-05: ครบ character ทอง/EUR/เยน/AUD-cross)
→ **0 trades ทุก symbol = skip+note** · เทรด ≥1 → **Model 1 12 เดือน (2025.07-2026.07) ทุก symbol ที่ M2 เทรด ≥10 ไม้**
(ไม่ใช่แค่ตัวดีสุด — user ต้องการตรวจให้ครบข้าม symbol) → `_mt5_auto/mass_smoke_mt5.csv` (ea,symbol,m2_trades,m1_pf,m1_trades,m1_net,m1_eqdd)
**guard autonomous:** timeout 180s/run + skip hang · try/catch ต่อ EA · log ทุก 25 ตัว · หมายเหตุ: รัน compiled
default TF=H1 (EA ที่ design มาสำหรับ TF อื่นอาจเทรดน้อย — filter 0-trade จับ, ยอมรับได้สำหรับ mass-smoke)
**Acceptance:** CSV ครบ + จัด tier ต่อ survivor (user 2026-07-05: PF>1 ผ่านไป optimize, กฎ "ห้าม DEAD ก่อน optimize"):
**Tier A** = PF>1.0 AND trades≥20 AND eqDD<40% (optimize candidate) · **Tier B** = PF>1.0 แต่ eqDD≥40% (grid-trap watch,
priority ต่ำ) · **Reject** = PF≤1.0 หรือ trades<20 (noise/ไม่มี edge — ไม่ใช่ DEAD) · list Tier A+B ให้ Claude ·
commit `[tag] ORDER-035 done` · **ห้าม:** verdict/แก้ source

**ผล (Codex; ไม่มี verdict):** เพิ่ม driver `scripts\mass_smoke_mt5.ps1` และรันครบ worklist ex5 ทั้งก้อนจาก
`_triage\mass_smoke_worklist.csv` บน MT5 เลน 2 (`D:\Meta 5b`) ตาม basket `XAUUSD/EURUSD/USDJPY/AUDNZD`.
ผลเต็มอยู่ที่ `D:\EA_LAB\_mt5_auto\mass_smoke_mt5.csv`

- ex5 ที่รันครบ: **203/203**
- CSV rows: **812** (= 203 EA × 4 symbols)
- EA ที่ M2 ทุก symbol = 0 trades: **157**
- EA ที่มีอย่างน้อย 1 symbol ได้ไปต่อ M1: **36**
- survivor rows: **Tier A = 36** · **Tier B = 3**

**Tier A / Tier B list ส่งให้ Claude:**

| EA | Symbol | M2 trades | M1 PF | M1 trades | M1 net | M1 eqDD% | Tier |
|---|---:|---:|---:|---:|---:|---:|---|
| (Oh) Arbitrage Super Profit V04 | EURUSD | 36 | 1.46 | 1170 | 4300.18 | 2.39 | Tier A |
| (oh) continue v06 | EURUSD | 120 | 2.35 | 705 | 8958.24 | 17.17 | Tier A |
| (oh) continue v06 | USDJPY | 85 | 2.16 | 771 | 12002.82 | 36.55 | Tier A |
| (oh) fibo gold v06 | USDJPY | 18 | 1.07 | 380 | 28.91 | 0.75 | Tier A |
| (Oh) Grid Upper lower V23 | EURUSD | 139 | 1.65 | 561 | 1176.07 | 6.85 | Tier A |
| (oh) grid v05 | EURUSD | 368 | 1.13 | 2981 | 518.88 | 7.70 | Tier A |
| (oh) Master GRID ATR Accumulative Deduction -B V23 | EURUSD | 714 | 1.44 | 5551 | 2666.37 | 21.17 | Tier A |
| (oh) Master GRID ATR Accumulative Deduction -B V23 | USDJPY | 630 | 1.38 | 5388 | 2501.33 | 9.36 | Tier A |
| (oh) pun fix lot v05 | XAUUSD | 485 | 1.60 | 1840 | 632.06 | 3.41 | Tier A |
| (oh) pun fix lot v05 | EURUSD | 500 | 1.63 | 1913 | 675.15 | 3.19 | Tier A |
| (oh) pun fix lot v05 | USDJPY | 496 | 1.63 | 1913 | 681.33 | 3.18 | Tier A |
| (oh) pun fix lot v05 | AUDNZD | 491 | 1.47 | 1913 | 559.52 | 3.29 | Tier A |
| (oh) pun lot hedging v15 | EURUSD | 384 | 1.05 | 1280 | 1024.09 | 23.85 | Tier A |
| (oh) pun lot hedging v15 | USDJPY | 221 | 1.17 | 1382 | 1878.87 | 27.06 | Tier A |
| North East Way MT5 v1.309_fix | XAUUSD | 14 | 1.35 | 172 | 494.14 | 38.12 | Tier A |
| North East Way MT5 v1.309_fix | EURUSD | 23 | 2.03 | 202 | 1482.66 | 30.22 | Tier A |
| North East Way MT5 v1.309_fix | USDJPY | 15 | 2.07 | 199 | 1505.18 | 30.12 | Tier A |
| North East Way MT5 v1.309_fix | AUDNZD | 23 | 1.98 | 203 | 1475.47 | 30.10 | Tier A |
| PumLot V.1.1 exp mt5 | EURUSD | 51 | 1.03 | 163 | 56.21 | 3.70 | Tier A |
| Scalping-EA-AsReMix | USDJPY | 24 | 1.23 | 155 | 971.49 | 14.66 | Tier A |
| BOO - EA Gold Mean Reversion _ Fibo Scalping V4.2 | EURUSD | 11 | 1.18 | 33 | 149.63 | 9.29 | Tier A |
| EX39.PU-test | XAUUSD | 14 | 3.46 | 130 | 500.82 | 9.96 | Tier A |
| EX39.PU-test | EURUSD | 13 | 2.75 | 69 | 160.91 | 0.93 | Tier A |
| AAA#IRSI SUMPIP LOT MARTINGLESEQUENCE | AUDNZD | 211 | 1.13 | 33212 | 326.15 | 30.12 | Tier A |
| Breakout Retest Pro EA Source Code (1) | USDJPY | 16 | 1.03 | 63 | 147.86 | 18.15 | Tier A |
| IR Whale Track Expiry | XAUUSD | 42 | 3.94 | 206 | 612.92 | 0.75 | Tier A |
| IR Whale Track Expiry | EURUSD | 13 | 1.19 | 101 | 83.63 | 3.96 | Tier A |
| IR Whale Track Expiry | USDJPY | 23 | 1.21 | 135 | 109.53 | 2.73 | Tier A |
| IR Whale Track Expiry | AUDNZD | 16 | 1.95 | 57 | 74.47 | 0.93 | Tier A |
| EA_GapinFX_MT5 | EURUSD | 26 | 2.34 | 160 | 728.37 | 3.66 | Tier A |
| EA_GapinFX_MT5 | USDJPY | 47 | 2.74 | 394 | 1745.65 | 8.74 | Tier A |
| SL=2GRIDE MQL5 | EURUSD | 103 | 1.69 | 700 | 645.70 | 4.03 | Tier A |
| The One 1.0.3 EA V1.0 MT5@YoForexPremium | XAUUSD | 70 | 2.32 | 2941 | 1011468.07 | 3.70 | Tier A |
| EA GOLD CENTER V.2 Expried 11.04.2025 | EURUSD | 210 | 1.44 | 931 | 815.16 | 22.13 | Tier A |
| EA GOLD CENTER V.2 Expried 11.04.2025 | AUDNZD | 262 | 1.52 | 946 | 720.90 | 18.67 | Tier A |
| PROFIT PLANET CURRENCY MT5 | XAUUSD | 21 | 1.14 | 84 | 461.49 | 13.57 | Tier A |
| EA Black Dragon MT5 V13 @SoftechFX_Robot | EURUSD | 147 | 3.02 | 1216 | 10792.94 | 45.62 | Tier B |
| SL=2GRIDE MQL5 | XAUUSD | 1859 | 1.11 | 130056 | 35624.15 | 52.75 | Tier B |
| JMAR EXPERTS for CRASH AND BOOM trailstop strategy | XAUUSD | 296 | 1.10 | 1222 | 10822.93 | 60.86 | Tier B |

## ORDER-036 — MT4 mass-smoke (1,318 ex4) — `OPEN → แยกเป็น BATCH BOARD ไฟล์ตัวเอง (user 2026-07-06)` · **ทำได้: Codex · oc-dev**

**👉 spec + สถานะ + วิธีสั่งทั้งหมด = `ORDER-036_MT4_MASS_SMOKE.md`** (แยกไฟล์เพราะ 27 batches ×50 —
กัน taskboard บวม). batch assignment deterministic = `_triage/mass_smoke_mt4_batches.csv` (คอลัมน์ batch 01-27).
user สั่งเป็นก้อน เช่น "ทำ 036 batch 04-08" · batch จบ+review แล้ว archive ไป `_archive/ORDER-036_ARCHIVE.md` ·
order แม่แถวนี้**คงอยู่จนครบ 27 batch** (กันหลุดจาก board) — Claude สรุป verdict รวมที่นี่ตอนจบ

**ผล:** _(ดูตารางสถานะในไฟล์ board — สรุปรวมจะมาเขียนที่นี่เมื่อครบ)_

---

## ORDER-035-REVIEW note (Claude/Opus 2026-07-05): 39 survivor — ส่วนใหญ่กับดักคุ้นเคย, คัด 3 ตัวเข้า ORDER-037

**สรุป:** 36 Tier A + 3 Tier B. **อ่านด้วยความสงสัยสูง — Model-1 หลอก grid/tight-TP** (บทเรียนหลักของแล็บ):
- **tight-TP artifact suspects** (PF สูง+DD ต่ำมาก+เทรดถี่): IR Whale 3.94/0.75%/206t · The One 2.32/3.7%/2941t ·
  Arbitrage 1.46/2.4%/1170t · EX39 3.46/9.96% — ต้อง Model-4 + widen-TP ก่อนเชื่อ
- **grid DD สูง (30-60%):** North East Way · continue v06 · Black Dragon · IRSI martingale — grid family
- **หมดอายุ/deploy ไม่ได้:** EA GOLD CENTER "Expried 11.04.2025" · IR Whale "Expiry" → เช็คก่อนเสียแรง
- **คัดเข้า ORDER-037 (top robust, ไม่ใช่ grid ชัด):** (oh) pun fix lot v05 (4 sym fixed-lot) · EA_GapinFX (gap, 2 sym PF2+) · North East Way (4 sym PF2+ แต่ DD30%)

## ORDER-037 — artifact-check top survivors จาก mass-smoke — `REVIEWED(Claude, 2026-07-06 — ❌ ตายครบทั้ง 3: pun fix lot REJECT (eqDD 83% ปี 2022) · GapinFX REJECT (balDD 112% ปี 2022!) · North East Way DQ (cracked "_fix/_nodll"))` · CLOSED

**สรุปปิด order (Claude, 2026-07-06): top-3 ของ mass-smoke MT5 = ศูนย์ survivor**
- **pun fix lot v05** → ORDER-038 BWD-OOS: 2022 eqDD 83% → REJECT (no-SL harvester)
- **EA_GapinFX** → BWD-OOS: 2021 PF 22.56 หรูหรา → **2022 PF 0.02 / balDD 111.87% ล้างพอร์ต** → REJECT
  (gap-fade = mean-reversion harvester ตระกูลเดียวกัน) · compiled-only ไม่มี source · M4 ไม่จำเป็นแล้ว
- **North East Way** → DQ ไม่ต้องเทส: ไฟล์ทุกตัว "_fix"/"_nodll" = cracked commercial (hard-gate locked-ex,
  precedent KRAPOOK) · เทคนิค multi-pair grid มีใน mold แล้ว
**Pattern ยืนยัน:** Tier A จาก smoke 2023-26 ที่เลขสวย = ส่วนใหญ่ **regime harvester** (เก็บกำไรเล็กใน
mean-reversion regime, ระเบิดปีเทรนด์) → **backward-OOS 2020-22 = ด่านบังคับอันดับแรกของทุก Tier A ต่อไป
(ถูกกว่า M4 และฆ่าได้เด็ดขาดกว่า)** — กติกานี้เข้า ORDER-036 board แล้ว

**🔄 (oh) pun fix lot v05 — VERDICT แก้หลังอ่าน source (Claude, 2026-07-06): จาก "แข็งสุดที่เคยเจอ" → CONDITIONAL-tail-risk**
ตัวเลขผ่านทุกด่านจริง (M4 PF 1.51/1913t/eqDD 3.42% ไม่ collapse · ทุกปีบวก 1.80/1.45/1.29/1.34 · MC ruin 0%) **แต่
source (fxdreema, 12k บรรทัด, subagent แกะ block graph) เผยกลไกจริง:**
- **เทรดแค่ 3 คู่ hardcode ของตัวเอง (EURUSD/GBPUSD/EURGBP) ไม่สน chart symbol** → ผล 4 ชาร์ตที่เกือบเหมือนกัน
  (1913/1913/1913/1840) = **พอร์ตเดียวกันรัน 4 รอบ ไม่ใช่ cross-symbol robustness** (แก้ verdict เดิมที่เครดิตผิด)
- **Entry:** candle body > 2× แท่งก่อน (สัญญาณตื้น) · **Exit: TP 10 pips เท่านั้น — ไม่มี SL ทุกชนิด**
  (StopLossMode="none", virtual/emergency/basket/equity = ปิดหมด — subagent อ้าง line ครบ)
- **= "no-SL harvester":** ไม้แพ้ไม่เคย realize ค้างจนราคาย้อนแตะ TP → PF สูงเพราะเก็บแต่ไม้ชนะใน regime ที่ย้อน
  (EUR/GBP 2023-26 range) — "ทุกปีบวก" สะท้อน regime ไม่ใช่ signal edge
- **ที่กันไม่ให้เป็นระเบิด:** LoopLimit=1/symbol/ทิศ + fixed 0.01 = exposure cap 6 ไม้เล็ก → eqDD 3.42% (รวม floating
  ใน tester แล้ว) จริง ณ lot นี้ — **Step 0b penalty (no-SL) ไม่ auto-DQ ตามกฎ user แต่ risk = tail ไม่ใช่ variance**
- **ด่านชี้ชะตาที่เหลือ = backward-OOS 2020-2022** (EURUSD dive 0.95 ปี 2022 = เทรนด์แรงไม่ย้อน = นรกของ no-SL
  hold-forever): ถ้ารอด = harvester ทนเทรนด์จริง พิจารณา demo เป็น experiment · ถ้าตาย = ปิด (regime-only) →
  **ORDER-038** · reports: `ART_punfixlot_USDJPY_*`
- **ยังค้าง: GapinFX M4 (กำลังรัน) + North East Way M4** (Codex/oc-dev ทำต่อได้)

**ทำไม:** survivor เป็น Model-1 บน EA ที่ส่วนใหญ่ grid/tight-TP → Model-1 หลอกได้ (Elephant PF 85→1.41).
ด่านแรกก่อนลงแรง intake funnel = **Model-4 every-tick** (จับ tight-TP collapse) + เช็คหมดอายุ

**ทำไม:** survivor เป็น Model-1 บน EA ที่ส่วนใหญ่ grid/tight-TP → Model-1 หลอกได้ (Elephant PF 85→1.41).
ด่านแรกก่อนลงแรง intake funnel = **Model-4 every-tick** (จับ tight-TP collapse) + เช็คหมดอายุ
**งาน — ต่อ EA (3 ตัว, ใช้ .ex5 ที่ deploy จาก 035 ใน `_smoke\`):**
| EA | symbol ที่ดีสุด (M1) | เช็ค |
|---|---|---|
| (oh) pun fix lot v05 | USDJPY (1.63) + EURUSD (1.63) | Model-4 12mo — PF ร่วงไหม (tight-TP?) |
| EA_GapinFX_MT5 | USDJPY (2.74) | Model-4 12mo + หา source เช็ค gap logic |
| North East Way v1.309 | EURUSD (2.03) | Model-4 12mo + เช็ค "fix" = หมดอายุไหม + DD จริง |
ขั้นตอน: (1) เช็คชื่อ/journal ว่าหมดอายุ/locked ไหม — ถ้าใช่ note+ข้าม (2) Model-4 every-tick 2025.07-2026.07
บน symbol นั้น เทียบ M1 · (3) full-window 2023-2026 Model-1 + year-split (edge ยืนยาว+ทุกปีไหม)
**Acceptance:** ต่อ EA: M1 vs M4 (PF/trades/DD) + full year-split + สถานะ expiry · commit `[tag] ORDER-037 done`
**ห้าม:** verdict (Claude ตัดสิน: M4 PF ไม่ร่วง + ทุกปีบวก = เข้า intake funnel เต็ม; ร่วง = artifact ปิด)

**ผล:** _(รอ)_

---

## ORDER-038 — pun fix lot v05: backward-OOS 2020-2022 — `REVIEWED(Claude, 2026-07-06 — ❌ REJECT ปิดถาวร: eqDD 83% ปี 2022, no-SL harvester ตายตามทฤษฎีเป๊ะ)` (run by Claude)

**VERDICT: ❌ (oh) pun fix lot v05 = REJECT ปิดถาวร (regime-only, tail risk เกิดจริง — DO-NOT-RE-EXAMINE)**
| ปี | PF | net | balDD |
|---|---|---|---|
| 2020 | 1.62 | +714.55 | 1.14% |
| 2021 | 1.19 | +306.77 | 1.59% |
| **2022** (EURUSD ดิ่ง 1.15→0.95 ไม่ย้อน) | **0.36** | **-3,352.02** | **36.92%** |
| FULL 2020-22 | 0.71 | -2,330.70 | 33.65% · **eqDD maximal 83.08%** 💀 |

floating DD 83% = เกือบล้างพอร์ต — ตรงทฤษฎี no-SL hold-forever เป๊ะ. "ทุกปีบวก 2023-26" = regime ย้อนกลับ
ล้วนๆ ไม่ใช่ edge. **วงจรสมบูรณ์: อ่าน source → ทำนาย failure mode → ทดสอบปี hostile → ยืนยันใน 1 รัน.**
mechanism-fatal ไม่ใช่ param-fixable (resize ไม่ช่วย — risk มาจากโครงสร้าง no-SL ไม่ใช่ lot) ·
report: `ART_punfixlot_BWDOOS.htm`

**ทำไม:** source เผย pun fix lot = no-SL + TP10pips harvester บน EURUSD/GBPUSD/EURGBP — ตัวเลข 2023-26 สวย
เพราะ regime ย้อนกลับ. **2020-2022 = COVID + EURUSD dive 1.15→0.95 (เทรนด์แรงไม่ย้อน) = stress จริงของ
no-SL hold-forever.** ถ้ารอด (PF≥1 + eqDD ไม่ระเบิด) = ทนเทรนด์จริง · ถ้าตาย = regime-only ปิดถาวร
```powershell
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert '_smoke\(oh) pun fix lot v05' -Symbol EURUSD -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -ReportName ART_punfixlot_BWDOOS -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\report_year_split.py D:\EA_LAB\_mt5_auto\reports\ART_punfixlot_BWDOOS.htm
```
(chart symbol ไม่สำคัญ — EA เทรด 3 คู่ hardcode ของมันเอง · ⚠️ ถ้า broker ไม่มี H1 data ย้อน 2020 ให้รายงานช่วงที่มีจริง)
**Acceptance:** FULL + year-split ทุกปี (PF/trades/net/**eqDD**) — eqDD สำคัญสุด (จับ floating ค้าง) · commit `[tag] ORDER-038 done`
**ห้าม:** verdict — เกณฑ์ Claude: 2022 (EUR เทรนด์เดียว) ต้อง PF≥0.9 + eqDD<15% ถึงรอด

**ผล:** _(รอ)_

---

## ORDER-039 — Scalping-EA-AsReMix: Model-4 + MC — `REVIEWED(Claude, 2026-07-06 — 🅿️ PARKED trend-specialist edge-decay; ZCode รัน M4, Claude ปิด FULL6Y+MC เอง)` · CLOSED

**VERDICT: 🅿️ PARKED — momentum edge จริง (ตัวเดียวจาก 203 ที่ไม่ใช่ harvester/artifact) แต่ edge จางแล้ว**
- M4 (ZCode): 2025-26 = **1.09**/154t/eqDD 15.28% (จาก M1 1.23 → บวกบาง) · **2022 = 2.71/151t/eqDD 8.91%
  (100% real ticks!)** — edge ปีเทรนด์รอด fill จริง = ของแท้
- FULL 6.5yr (Claude): 2020-23 = 1.05/1.56/**2.99**/2.10 (ยุคทอง) → **2024-26 = 1.04/1.06/0.98(ลบ) +
  balDD บวม 22→31→33%** = edge decay ชัด · MC worst DD 106%
- **สรุป: trend-regime specialist ที่ regime หมดไป 3 ปีแล้ว — deploy วันนี้ = ซื้อของที่แพ้อยู่** → PARKED
  reserve ตัวเดียวของ mass-smoke MT5 · re-examine เมื่อ JPY/USD trend/vol ใหญ่กลับมา ·
  **treasure hunt MT5 ปิดสมบูรณ์: 203 → 39 (เลขสวย) → 1 edge จริง → 0 deployable วันนี้**

**ทำไม:** BWD-OOS sweep 19 ตัว → รอดตัวเดียว: AsReMix (USDJPY) **2022 ปีเทรนด์แรงกลับ PF 2.99** (momentum-
profile ตรงข้าม harvester) · full 20-22 = 1.88/+$8,697/eqDD 8.89% · 25-26 M1 = 1.23/DD 14.66. compiled-only
(zip ไม่มี source) → behavioral. **ชื่อ "Scalping" = fill-sensitivity risk สูงสุด → M4 คือด่านชี้ขาด**
```powershell
# (1) M4 every-tick 12 เดือนล่าสุด (รันเดี่ยว!)
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert '_smoke\Scalping-EA-AsReMix' -Symbol USDJPY -Period H1 -FromDate 2025.07.01 -ToDate 2026.07.01 -Model 4 -ReportName ART_AsReMix_M4 -TimeoutSec 3600 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
# (2) M4 บนปีเทรนด์ 2022 ด้วย (ถ้า broker มี tick) — ยืนยัน 2.99 บน real ticks
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert '_smoke\Scalping-EA-AsReMix' -Symbol USDJPY -Period H1 -FromDate 2022.01.01 -ToDate 2023.01.01 -Model 4 -ReportName ART_AsReMix_M4_2022 -TimeoutSec 3600 -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
# (3) MC บน full 2020-2026 (ต่อ M1 2020-2026 ก่อน 1 รัน แล้ว montecarlo)
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert '_smoke\Scalping-EA-AsReMix' -Symbol USDJPY -Period H1 -FromDate 2020.01.01 -ToDate 2026.07.01 -Model 1 -ReportName ART_AsReMix_FULL6Y -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
. D:\EA_LAB\scripts\use_python.ps1
python D:\EA_LAB\scripts\mt5_montecarlo.py D:\EA_LAB\_mt5_auto\reports\ART_AsReMix_FULL6Y.htm --deposit 10000 --iters 5000
python D:\EA_LAB\scripts\report_year_split.py D:\EA_LAB\_mt5_auto\reports\ART_AsReMix_FULL6Y.htm
```
**Acceptance:** M4 25-26 + M4 2022 (PF/trades/eqDD/quality) เทียบ M1 · FULL6Y year-split ทุกปี · MC (DD/ruin) ·
commit `[tag] ORDER-039 done` · **ห้าม:** verdict — เกณฑ์ Claude: M4 PF ไม่ร่วง >30% จาก M1 + ไม่มีปีเน่าใน 6.5 ปี

**ผล:** _(รอ)_

---

## ORDER-040 — BWD-OOS sweep ของ 036 batch-01 Tier A — `REVIEWED(Claude, 2026-07-06 — ZCode token หมดก่อนเริ่ม → Claude รันเอง · 19 ตัว → 🟡 2 CONDITIONAL ผ่าน durability!)` · CLOSED

**VERDICT (Claude, 2026-07-06) — 19 ตัว (20 Tier A − CITY-GOLD_fix DQ-by-name PF259.99!):**
- **💀 ZERO-TRADE 2020-22 = 8** (Broker Killer, Fxcore100_BUY, Mood, Elise, AW Recovery_NEW, Alpha Striker,
  Forexthai4pip, Hedgingprofit) — เทรด 2026 แต่ไม่เทรดอดีต = สงสัย time-lock/expiry ในตัว → **REJECT-unverifiable**
- **❌ ระเบิด 5:** Forex Hacked DD108% · DanceT DD103% · FLy_HiGhEr 0.03/DD91 · forexthaipop 0.03/DD87 · Happy thaipop DD73
- **❌ PF>1 แต่ DD 57-74% = 4:** MoneyTree Buy+Sell (ผลเหมือนเป๊ะ = binary เดียว 2 ชื่อ!) · Miracle · CommunityPower
- **🟡 CONDITIONAL 2 — ทุกปีบวกจริง (2020/21/22 + 2026):**
  ClevrFX_EA (EURUSD): 1.76→1.51→2.37 · 2026=2.04 · DD/ปี 20-40% ·
  Fxcore100_SELL (EURUSD): 1.72→2.21→1.89 · 2026=2.06 · DD/ปี 9-26% — **ไม่ใช่ harvester** (ปีเทรนด์
  ดีสุด/สม่ำเสมอ) · DD สูง = resize-first · compiled-only ทั้งคู่ → **ORDER-041 (spread-stress + lock-check)**
- **จุดต้องรู้:** ClevrFX preset = "eurusd-m5" (เรารัน H1 ยังกำไร) · Fxcore100_SELL = **HFT ~13 ไม้/วัน =
  spread-sensitive สุด + MT4 fixed-spread blind spot (Zeus lesson)** · Fxcore100_BUY 0-trade อดีตแต่ SELL ปกติ =
  แปลก · **❓user: FXCore100 v5.1 ซื้อจริงหรือแชร์มา?** (สิทธิ์ deploy)
- driver v2 `_mt5_auto/ab_sets/bwdoos_mt4_sweep.ps1` (v1 fail — batch driver ไม่ทิ้งไฟล์ deploy; v2 copy จาก
  source เอง) · ผล `BWDOOS_MT4.csv` + `BWDY_*`

**ทำไม (เดิม):** batch-01 ให้ 24 Tier A แต่กติกาใหม่ = **เลขสวย 2026 ยังเชื่อไม่ได้ — BWD-OOS 2020-2022 เป็นด่านแรก**
(MT5 sweep พิสูจน์แล้ว: 19 → รอด 1). ทำก่อนเริ่ม batch 02+ เพื่อรู้ว่า MT4 pool มีของจริงไหม
**งาน:**
1. **แก้ CSV quoting bug ก่อน:** EA ชื่อมี comma (เช่น "nzdcad 15 min)") ทำ column เพี้ยนใน
   `mass_smoke_mt4.csv` — แก้ driver ให้ quote ทุก field + ซ่อมแถวเสีย 2 แถว
2. เขียน BWD sweep (แบบ `bwdoos_sweep.ps1` ฝั่ง MT5): ต่อ Tier A EA (24) รัน `mt4_run.ps1` **M1
   2020.01.01-2023.01.01** บน symbol ที่ M1 ดีสุดของมัน · year-split + eqDD ลง `_mt5_auto/BWDOOS_MT4.csv`
3. **⚠️ เช็คก่อนรันจริง:** Meta4 มี M1-bar history ย้อนถึง 2020 ไหม (memory บอกแค่ tick <2026-03 ไม่มี —
   bar อาจมี) — ตัวแรกที่รัน ถ้า report ช่วงสั้นกว่าที่ขอ = data ไม่ถึง → **หยุด รายงาน ช่วงที่มีจริง**
   (Claude จะเคาะ window ทางเลือก) อย่าฝืนรันทั้ง 24 บน data สั้น
**Acceptance:** CSV ครบ 24 (หรือรายงาน data-limit) + list ตัวที่ 2022 PF≥0.9 & eqDD<20% · commit `[tag] ORDER-040 done`
**ห้าม:** verdict — Claude ตัดสิน (เกณฑ์เดียวกับ MT5 sweep)

**ผล:** _(รอ)_

---

## ORDER-041 — ClevrFX + Fxcore100_SELL: spread-stress + SL/lock check — `REVIEWED(Claude รันเอง, 2026-07-06 — ✅ ผ่านทั้งคู่ = MT4 candidates จริง 2 ตัวแรกของแล็บ; รอ user เคาะ 2 เรื่องก่อน demo)` · CLOSED

**VERDICT (Claude, 2026-07-06): ✅ ทั้งคู่ผ่านทุกด่านที่ backtest ตอบได้ — เหลือแค่ live-condition proof + สิทธิ์**
- **Spread-stress (window 2026.03-07, M1, `-Spread` param ใหม่ใน mt4_run.ps1):**
  ClevrFX: base 2.04 → sp30 **2.04** → sp45 **1.93** (ไม่สะเทือน) · Fxcore100_SELL: 2.06 → **1.86** → **1.83**
  (HFT 13 ไม้/วันยังยืนบน 3x spread!) — เกณฑ์ 2x>1.3 ผ่านห่าง · MT4 fixed-spread blind spot = ปิดข้อสงสัยแล้ว
- **SL-check (trade list BWDY_*):** **ทั้งคู่ no hard SL/TP ทุกไม้ (0.00000)** — ปิดด้วย internal logic ล้วน ·
  **แต่ต่างจาก pun fix lot:** ผ่านปี 2022 ทุกปีบวก + DD ไม่ระเบิด = internal cut-loss ทำงานจริง (ไม่ใช่
  hold-forever) · ความเสี่ยงคงเหลือ = **disconnect/crash = ไม้เปลือยไม่มี SL บน server** → ต้องรันบน VPS
  เสถียร + จับตา demo
- **Lock:** ตัว SELL เทรดครบ 2020-26 = ไม่มี time-lock ในตัวที่ใช้ (BUY twin มี 0-trade อดีต — ไม่ใช้ตัว BUY)
- **สรุป: 2 ตัวแรกจาก treasure ทั้งหมด (222 EA ทดสอบแล้ว) ที่ผ่านครบ: BWD-OOS ทุกปีบวก + spread 3x + ไม่
  ระเบิด + consistent 2026** — ⚠️ ยังเป็น compiled กลไกดำ (no-SL internal management) → เข้าได้แค่สถานะ
  **demo-experiment เท่านั้น ห้ามคิดถึง live จนพิสูจน์บน demo ≥3 เดือน**
- **user เคาะแล้ว (2026-07-06):** (1) **Fxcore = ก็อปมา → DQ** (precedent North East Way — เลขเก็บเป็น prior
  ถ้าซื้อ official ในอนาคต) (2) **MT4 demo มีอยู่ → ClevrFX เข้า demo-experiment** — deploy plan ครบใน
  `DEMO_DEPLOYMENT_PLAN.md` §ClevrFX (EURUSD H1 **defaults ห้ามโหลด set** · ตัวเดียว/บัญชี · kill-DD 40% ·
  no-SL → ออนไลน์ตลอด) — รอ user attach + แจ้งวันเริ่ม

**ทำไม:** 2 ตัวรอด BWD-OOS ทุกปีบวก (ORDER-040) แต่เป็น compiled MT4 → จุดตายที่เหลือ: (1) **MT4 fixed-spread
backtest หลอก** — โดยเฉพาะ Fxcore100 HFT ~13 ไม้/วัน spread จริง Exness กิน edge ได้หมด (2) time-lock/expiry
ซ่อน (8 ตัวใน pool นี้มี!) (3) กลไกยังไม่รู้ (no-SL?)
**งาน:**
1. **Spread stress:** MT4 tester ตั้ง spread คงที่ได้ (Spread= ใน ini — เช็ค `mt4_run.ps1` รองรับไหม ถ้าไม่มี
   เพิ่ม param `-Spread` ใส่ `[Tester] TestSpread=N`) → รันซ้ำ 2026.03-07 M1 ที่ **spread 2x และ 3x ของ default**
   ต่อ EA · Fxcore ถ้า PF ร่วงแรงตาม spread = spread-arbitrage illusion ปิดเลย
2. **Lock/expiry check:** เปิด Strategy Tester Journal ของ run ปกติ — หา error/warning/หมายเหตุ account/expiry ·
   + behavior แปลก Fxcore100_BUY (0-trade อดีต แต่ SELL ปกติ) — รัน BUY บนปี 2024-25 ดูว่าจุดตัดเวลาอยู่ไหน
3. **Journal param recovery** (locked-ea-analyzer style): log input params จาก tester journal → เดา mechanism
   (มี SL จริงไหม สำคัญสุด — ดู order/SL ใน trade list ของ report ที่มีอยู่แล้วก็ได้: `BWD4_*`/`BWDY_*`)
**Acceptance:** ต่อ EA: ตาราง spread 1x/2x/3x (PF/trades/net) + expiry findings + "มี SL ต่อไม้ไหม" จาก trade list ·
commit `[tag] ORDER-041 done` · **ห้าม:** verdict — เกณฑ์ Claude: spread 2x แล้ว PF ยัง >1.3 + มี SL จริง + ไม่มี lock = คุยเรื่อง demo-experiment ต่อ
**❓รอ user ตอบด้วย: FXCore100 v5.1 ซื้อจริงหรือแชร์มา** (ถ้าแชร์/pirated = สิทธิ์ deploy มีปัญหาแบบ North East Way)

**ผล:** _(รอ)_

---

## ORDER-045 — MT4 demo experiment #2: UnNomGuai + RSI from pips (คู่, บัญชีใหม่) — `WAITING-USER (attach) → แล้วค่อยเป็น monitoring loop` · **เจ้าของ: user (attach) + Claude (judge)** _(ออก 2026-07-07 หลัง user อนุมัติ)_

**สถานะ:** ORDER-036 ปิดสมบูรณ์ (1,318 → 2 survivor: **UnNomGuaiV1.132 + RSI from pips_EA** ผ่านครบถึง
Model-0 bwd+fwd) · user อนุมัติ demo คู่บนบัญชีเดียว (2026-07-07) · **bundle พร้อม: `_demo_deploy\`**
(ex4 ×2 + `README_DEPLOY.md` มี MD5 lock, kill-switch, ค่าคาดหวัง) · แผนเต็ม: `DEMO_DEPLOYMENT_PLAN.md`
§MT4 demo experiment #2
**รอ user:** เปิดบัญชี demo ใหม่ ($10k, แนะ ThinkMarkets) → ลง MT4 portable `D:\Meta4demo` (ห้ามใช้เลนเทส)
→ attach ตาม checklist → **แจ้งวันที่ attach = demo-clock เริ่ม (judge +3 เดือน)**
**งาน agent หลัง attach (ทุก ~2 สัปดาห์ รอบเดียวกับ ClevrFX):** อ่าน statement ที่ user export → แยก P&L
ตาม magic (1/2 = UnNom · 5888 = RSI) → เทียบตารางคาดหวังใน README → เช็ค kill-switch (UnNom >12 ไม้ ·
RSI >0.06 lot · DD alert 20/25% kill 30/35%) → รายงาน · **ห้าม:** แก้ input EA · เพิ่ม EA อื่นในบัญชีนี้

**ผล:** _(รอ attach)_

---

## ORDER-055 — [NEXT SESSION START HERE] demo cohort 8 ตัว: attach + monitor — `🚀 ATTACHED 2026-07-09 คืนนี้ (โครงจริงต่างจากแผน — ทั้งหมดบน VPS, cohort MT5 ขึ้น REAL cent!) · judge ชุดนี้ = 2026-10-09 · รายละเอียด = section "DEPLOYMENT REALITY 2026-07-09" ใน DEMO_DEPLOYMENT_PLAN.md · เหลือ: user attach exporter ×5 บน VPS + เลือกท่อ CSV (OneDrive บน VPS หรือ RDP-copy รายสัปดาห์) + จับตา Boss-TrendSwing/Woodfire (มี EA ที่แล็บ REJECT ปน — Gold Reaper, LondonConso)`

**สรุป session 2026-07-08/09 (Opus): EA hunt รอบใหญ่จบ → 7 clean + 1 experimental candidate พร้อม attach.**
รายละเอียดเต็ม = `PROJECT_STATE.md` §7 "SESSION 2026-07-08" block · handoff doc = `handoff/SESSION_2026-07-09_HANDOFF.md`
bundle = `_demo_deploy\README_DEPLOY.md` (2 บัญชี MT4+MT5 · WILL-IT-TRADE checklist + kill-switch + corr + portfolio-sim ครบ).

**8 candidates (magic distinct):**
- MT4: UnNomGuai(EURUSD/1-2) · RSI-orig(EURUSD/5888) · swb(AUDCAD/990) — grid, validated
- MT5: RSI-MR(EURUSD/990103,**ROBUST**) · Zeus(XAU/990101,MARGINAL) · BRK-XAU(XAU/991001,MARGINAL) · SqueezeBRK(XAU/991004,**ROBUST**) · **Trendline(XAU/991002,EXPERIMENTAL PF-5th 0.986)**

**Claude-doable งานเสร็จหมดแล้ว (session นี้):** corr matrix 8-EA (ไม่มีคู่ >0.60, gold 3 ตัว uncorrelated) · portfolio-sim (รวม DD 1.2%, gold-pair 3.8%) · bundle verify + **AllowLive=true fix ทั้ง MT5 set (critical silent-stop catch)** · WILL-IT-TRADE checklist · tools ใหม่: corr_matrix/portfolio_sim/mt4_deals_to_csv/max_recovery_days.py

**แผนวันนี้ 2026-07-09 (user รวม session แล้ว — session นี้เป็น lead เดียว · เรียงตาม EV):**
1. **[user, ~20 นาที] attach 8 ตัว** (MT4 3 + MT5 5 ตาม `_demo_deploy\README_DEPLOY.md` WILL-IT-TRADE checklist) **+ attach DealsExporter.ex5 1 chart** (ค้างจาก ORDER-042) → บอกวันเริ่มให้ Claude · **EV สูงสุด — ทุกอย่างรอด่านนี้**

> **📋 USER CHECKLIST เย็นนี้ (2026-07-09) — ทำทีเดียวจบ:**
> ☐ 1. attach demo cohort 8 ตัว ตาม `_demo_deploy\README_DEPLOY.md` (เช็ค WILL-IT-TRADE ทุกข้อ: AllowLive=true, RSI-MR ต้องบัญชี Hedging, AutoTrading เปิด, magic ตรง)
> ☐ 2. attach `tools\DealsExporter\DealsExporter.ex5` 1 chart บน terminal demo MT5
> ☐ 3. **บัญชี VPS → ไม่ต้องแตะ VPS เลย:** เปิด MT5 instance สำรองบนเครื่องนี้ (D:\Meta 5b) → login บัญชี VPS ด้วย **investor password** (read-only) → แปะ DealsExporter 1 chart · ทำซ้ำต่อบัญชีที่อยาก track (รวม Boss-TrendSwing 159475669 ถ้าจะให้ track)
> ☐ 4. บอก Claude: วันที่ attach + รายชื่อบัญชี → Claude ลงทะเบียน DEMO_DEPLOYMENT_PLAN + ตั้ง judge date + scheduled task (collector + dashboard อัตโนมัติทุกเช้า)
> · ~~หมายเหตุ: บัญชี MT4 ใช้ DealsExporter ไม่ได้~~ **อัปเดตบ่าย: MT4 exporter มีแล้ว (ORDER-060)** —
> ☐ 5. attach `tools\DealsExporter\OrdersExporterMT4.ex4` 1 chart บน terminal demo MT4 ด้วย
> (**สำคัญ: คลิกขวา tab Account History → เลือก "All History" ก่อน** ไม่งั้น export ไม่ครบ)
2. **[Claude ทันทีที่รู้วัน attach]** บันทึก DEMO_DEPLOYMENT_PLAN + judge +3 เดือน + ตั้งรอบ /ea-monitor
3. **[Codex] ORDER-057 Stage A** — `Regime.mqh` (ADX trend/sideway + ATR storm, default OFF) → Claude review + `tpl_regression.ps1` ต้อง CLEAN → ค่อยปล่อย Stage B (ZCode, A/B both-windows)
4. **[qwen/Sonnet] ORDER-058** — live dashboard HTML per-magic (ต่อยอด DealsExporter · มีข้อมูลจริงหลัง user ทำข้อ 1)
5. [optional ถ้า quota เหลือ] COT/CME regime-data pull (ไอเดียจากโพส FB 07-09 — ยังไม่เป็น order, รอ user เคาะ) · ORDER-043 US30 probe (ZCode วันว่าง)
**หลัง attach:** statement ทุก ~2 สัปดาห์ → แยก P&L ตาม magic → เทียบค่าคาดหวัง README · จับตา (a) MT4 grid no-SL tail (b) combined gold exposure (Zeus+BRK+Squeeze+Trendline ทั้ง 4 = XAU) (c) Trendline #8 borderline → drop ถ้าไม่เข้าเป้า
**ปิดไปแล้ว:** hunt space สำรวจหมด (instrument/TF/กลไก/lot-law/re-opt/FX-travel = ตัน) — กลไกใหม่จริง (flag/pennant/order-flow) ค่อยว่ากัน · Boss V2 robustness track = parked
**ห้าม:** แก้ config ที่ validate แล้ว · เชื่อ hunt ว่า EV สูง (พิสูจน์แล้วว่าตัน)

**ผล:** bundle deploy-ready (8 EA, safety-checked). รอ user attach.

---

## ORDER-047 — RSI from pips_EA: symbol/TF breadth → BWD confirm → optimize (user สั่ง 2026-07-07: "ตัวนี้ดี ลอง optimize + หลาย symbol + ปรับ TF") · swb reserve ขนาน — `REVIEWED/CLOSED (Claude, 2026-07-07 ค่ำ — RSI=EURUSD-only ไม่ optimize · swb ฟื้นเป็น candidate #3 บน AUDCAD)`

**🏁 VERDICT (Claude, 2026-07-07 — 3 เฟสจบ):**
- **RSI from pips = EURUSD-specific · ไม่ optimize** (เหตุผลใต้ตาราง phase 2) — ใช้ default บน EURUSD เป็น demo ตามเดิม · ต่อยอดจริง = สร้าง original ใน Boss V2 (`RSI_FROM_PIPS_REVERSE_ENGINEERING.md`)
- **🟢 swb flat-lot @ AUDCAD = DEMO-EXPERIMENT CANDIDATE #3** (ผลการท้วง "เทสตัวสำรองขนาน" ของ user ได้ candidate จริง!): BWD 2.40/DD8.6 → SPR30 2.23 → M0 1.80/DD20.4 · ladder ×3-4 · no-SL caveat · base 0.2 de-scale + magic=1 ชน UnNomGuai (คนละบัญชี/แก้ magic) — scorecard §ORDER-036 survivors
- swb @ AUDUSD = 🟡 CONDITIONAL secondary (M0 1.66/DD32) · swb @ EURUSD/XAUUSD = ❌ REJECT (symbol-specific)
- **บทเรียน:** (1) forward DD ต่ำหลอกได้เสมอ — RSI AUD คู่ DD<1% forward กลายเป็น 50%+ ที่ 3 ปี (ladder ×11-19) · (2) grid บางตัว symbol-specific — swb ตาย EURUSD แต่รอด AUDCAD (ต้องหาคู่ที่ ladder ตื้น) · (3) การเทสตัวสำรองขนานคุ้ม — ได้ candidate ที่ไม่คาด

**⚠️ ข้อจำกัดสำคัญ: RSI from pips = .ex4 ล้วน ไม่มี source** (zip มีแต่ ex4) → optimize ได้แค่ input MT4
optimizer บนกล่องดำ + มี recovery ladder (Lots_plus ×6) ข้างใน = **เสี่ยง overfit สูง** → ทำ breadth
(ค่าจริง เสี่ยงต่ำ) ก่อน optimize (เสี่ยงสูง คุม IS/OOS เข้ม) · broker เลนเทส ThinkMarkets มี M1 10 คู่
**แผน 3 เฟส:**
1. **Breadth (RUNNING):** RSI (เลน1, `rsi_breadth_lane1.ps1`→`RSI_BREADTH.csv`) + swb flat (เลนMT4b,
   `swb_breadth_mt4b.ps1`→`SWB_BREADTH.csv`) · default params · 10 symbol @ H1 + EURUSD TF sweep
   M15/M30/H4 · forward 2026.03-07 (ข้อมูลแน่นอนทุกคู่) → หา symbol/TF ที่เทรด+กำไร
2. **BWD confirm:** top symbol จากเฟส 1 → BWD 2020-22 (เฉพาะคู่ที่ data ถึง) ฆ่า regime-luck ก่อนเสีย
   compute optimizer
3. **Optimize:** เฉพาะตัวรอด → MT4 optimizer จูน signal params (RSI_period/over_s/over_b/TP_pips/
   Distance_pips) IS 2020-2023 → OOS 2023-2026 + Model-0 · **ทุกเลข optimizer = in-sample ห้ามเชื่อจน
   ผ่าน OOS+M0** (กฎ repo) · default (Period_5/TP15/Dist30/RSI14/30-70) = prior ที่ผ่านมาแล้ว
**Acceptance:** ตาราง breadth/BWD/opt ต่อเฟส · verdict = Claude · **ห้าม:** เชื่อ in-sample · แก้ window นอก 3 ปี

**ผล phase 1 breadth (forward 2026.03-07 M1, default — ยังเชื่อไม่ได้จนผ่าน BWD):**
- **RSI (`RSI_BREADTH.csv`):** เด่น = **AUDUSD (3.75/171trd/DD0.73) · AUDCAD (4.45/191/DD0.92)** (คู่ใหม่ นอกเหนือ EURUSD ที่ validate แล้ว, sample เยอะ DD ต่ำ) · EURUSD 2.59/149 · GBPUSD 3.09/71 · XAUUSD 40.78/724 (สูงผิดปกติ = gold forward เทรนด์ ต้อง BWD) · **TF sweep EURUSD เสถียรทุก TF (M15 2.65/M30 2.48/H1 2.59/H4 2.83) = edge ไม่ใช่ TF-artifact** · ตาย: USDJPY 0.08/USDCAD 0.26 · thin: CHFJPY/EURGBP/EURCHF (<60 ไม้ net<$65)
- **swb flat (`SWB_BREADTH.csv`):** กำไรแทบทุกคู่ — AUDUSD 3.3 · AUDCAD 3.25 · CHFJPY 2.98 · GBPUSD 2.82 · XAUUSD **23.1/net$100k** (gold grid เทรนด์) · TF: H4 3.35 ดีสุด
**ผล phase 2 BWD 2020-22 (`ORDER047_BWD.csv` + lot-check — 3 ปีเผยความจริงที่ forward ซ่อน):**
- **RSI = EURUSD-specific เท่านั้น** (คู่อื่นตายหมด): EURUSD DD 7.6%/×6 ✅ · **AUDUSD DD 50.5%/×11** ·
  AUDCAD DD 51.9%/×11 · **XAUUSD DD 57.7%/×19** — forward DD <1% คือ regime trap เป๊ะ (ปีเทรนด์ grid
  ลงลึก 11-19 ชั้น vs EURUSD 6) · GBPUSD 0 เทรด window → **สรุป: อย่า deploy RSI คู่อื่น**
- **swb กลับน่าสนใจข้ามคู่:** AUDCAD DD 8.63%/×3 · AUDUSD DD 25.5%/×5 · XAUUSD DD 17.1%/×5 —
  **ดีกว่า swb-EURUSD (M0 DD 42%) ชัด** → phase 3 spread+M0 กำลังรัน (`order047_phase3_swb.ps1`)
- **RSI ไม่ optimize (ตัดสิน):** EURUSD ผ่านครบทุกด่านที่ default อยู่แล้ว + เป็น .ex4 ไม่มี source →
  จูน black-box = overfit risk >> gain เล็กน้อย · TF ก็เสถียรทุก TF อยู่แล้ว = ไม่มีอะไรให้ปรับ · **คำตอบ
  "หลาย symbol/ปรับ TF" = symbol เจาะจง EURUSD, TF ไหนก็ได้** · ต่อยอดจริง = สร้าง original RSI-MR ใน
  Boss V2 (source ครบ optimize ได้เต็ม) ดู `RSI_FROM_PIPS_REVERSE_ENGINEERING.md`

---

## ORDER-046 — Revival probes: กฎ "ห้าม DEAD ก่อนลอง optimize" กับ ORDER-036 dead pool — `REVIEWED/CLOSED (Claude, 2026-07-07 ค่ำ — 1 win ฟรี + 1 marginal-revive + 2 ยืนยันตายถาวร)` _(user ท้วง 2026-07-07: "จะไม่ optimize เลยเหรอ" — คำตอบ: probe เฉพาะตัวที่ input โครงสร้างเดียวปิดจุดตายได้ ไม่ใช่ tune หา PF สวย)_

**🏁 VERDICT (Claude, 2026-07-07 ค่ำ — `BWDOOS_MT4_REVIVAL.csv` + `_REVIVAL2.csv`):**
- ✅ **WIN ฟรี: UnNomGuai cap 99→20** = ผลย้อนหลังเหมือน default ทุกเซ็นต์ → demo ใช้ `UnNomGuai_cap20.set` (ปิด tail-risk 99 ชั้น โดย validation เดิมยังใช้ได้)
- 🅿️ **swb grid flat-lot = PARKED-marginal (ฟื้นจริงแต่ไม่พอ demo):** BWD 2.40 → SPR30 **2.09 (ทน spread สวย!)** → Model-0 1.54/**DD 42.06%** — เกิน gate 40% แค่ 2 จุด · resize ไม่ช่วย DD% ของ grid · ladder ชั้นสอง (lot_multiplier_2=1.5) ยังเหลือ ×5 · **เก็บเป็น candidate สำรอง** ถ้าอยากได้ demo slot ที่ 3 อนาคต ค่อยลองปิด multiplier ชั้นสองอีก (แต่เริ่มเป็น tuning หลาย param = ระวัง overfit) — priority ต่ำกว่า 2 ตัวสะอาด
- ❌ **Yetti3 no-boost = REJECT ถาวร:** SPR30 0.97 (ตายที่ spread เท่าเดิม) → จุดตายคือ scalper spread-sensitivity ไม่ใช่ boost · ปิด boost ไม่แก้อะไร
- ❌ **FZ2 mult=0 = REJECT ถาวร:** BWD 0.36/DD99% — ใต้ martingale ไม่มี edge เลย (พิสูจน์เชิงประจักษ์ว่า structural gate ไม่ได้ฆ่าผิด)

**บทเรียนปิด order:** กฎ "ห้าม DEAD ก่อน optimize" ให้ค่าจริง — แต่ค่าที่ได้ = **1 safety-win + ความรู้ว่ากลไกไหนตายเพราะอะไร** ไม่ใช่ candidate ใหม่ทะลัก · การ probe แบบ "แก้ 1 input โครงสร้าง → ด่านเดิมครบชุด" แยก luck จาก logic ได้จริง (ต่างจาก sweep หา PF สวย) · ✅ ยืนยัน 2 survivor สะอาด (UnNomGuai+RSI) ยังเป็นคำตอบหลัก swb เป็นตัวสำรอง

**หลักการ (Claude ตัดสิน):** แก้ **หนึ่ง input โครงสร้าง** ที่ตรงกับ kill-cause แล้วส่งเข้า**ด่านเดิมครบชุดจากศูนย์**
(BWD→lot-check→spread→M0) — ไม่ sweep หลาย param บน black box (= โรงงาน overfit, แยก luck จาก logic ไม่ได้)
**Probes (script `lane1_revival_070707.ps1` → `BWDOOS_MT4_REVIVAL.csv` + lot-check ใน log):**
1. **FZ2 + multiplier=0,MM=0** — เหตุผลแรงสุด: **engine เดียวกับ UnNomGuai เป๊ะ** ต่างแค่ multiplier=1.5 vs 0
   → probe = แปลงเป็น config คลาสที่ผ่านครบทุกด่านแล้ว · เป็น canary ของกลไก -SetFile ด้วย (ladder ต้องหาย)
2. **UnNomGuai + space3Orders=20 (จาก 99)** — cap probe ก่อน demo: ประวัติไม่เคยเกิน 9 ไม้ → ผลต้อง**เหมือน
   baseline เป๊ะ** (1.89/3640/+8527) = ปิด tail-risk 99 ชั้นฟรี ถ้าเลขต่าง = cap bind ที่ไหนสักจุด → Claude ดู
3. **swb grid + lot_multiplier=0** — ปิด ladder boolean เดียว เหลือ flat 0.1 BB+Stoch+RSI grid (PF 2.1 ทั้งที่มี ladder)
4. Yetti3+NewsSherry + Boost=1.0 — อ่อนสุด (ตายที่ spread margin) ท้ายคิว
**ไม่ probe:** Dark Venus (multiplier ฝังใน GridManagement ไม่มี input เดี่ยว + ตาย 2 เด้ง) · ตัวที่ BWD PF<1
(ขาดทุนย้อนหลังด้วย logic ตัวเอง — fit ให้เขียว = artifact) · ตัว worthless/thin
**Acceptance:** ต่อ probe: BWD PF/DD + lot-ratio ใหม่ · ตัวที่ผ่าน → spread+M0 chain ต่อ · verdict = Claude
**หมายเหตุ magic:** swb/Oracle/FZ2 ใช้ magic=1 ชนกับ UnNomGuai (magicbuy=1) — ถ้าตัวไหนถึงขั้น demo ต้องแยกบัญชี

**ผล probes รอบแรก (2026-07-07 ค่ำ — `BWDOOS_MT4_REVIVAL.csv`):**

| Probe | ผล BWD 2020-22 | Verdict |
|---|---|---|
| FZ2 mult=0/MM=0 | **PF 0.36 / -9,884 / DD 99.1%** (ladder หายจริง ×2.3 = .set ทำงาน ✓) | ❌ **REJECT ถาวร — พิสูจน์แล้วว่า PF 3.05 คือ recovery mechanics ล้วน ไม่มี edge ใต้ martingale เลย** (หลักฐานเชิงประจักษ์ยืนยัน structural gate 2026-06-23) |
| UnNomGuai space3Orders=20 | **เหมือน baseline ทุกเซ็นต์** (1.89/3,640/+8,527.06/DD18.74) | ✅ **cap ไม่เคย bind ย้อนหลัง → demo ใช้ `UnNomGuai_cap20.set`** (เพิ่มเข้า `_demo_deploy\` + README แก้แล้ว) — ปิด tail-risk 99 ชั้นฟรี |
| swb grid lot_multiplier=0 | **PF 2.40 (จาก 2.10) / DD 30.2% (จาก 51.8) / ladder ×5** | ✅ **ฟื้นที่ด่าน BWD** → SPR30+M0 กำลังรัน (stage 2) |
| Yetti3 Boost=1.0 | **PF 1.44 (จาก 1.25) / DD 6.6% / lot แบน ×1** | ⏳ ฟื้นที่ BWD แต่จุดตายเดิมคือ spread → SPR30+M0 กำลังรัน (stage 2) |

---

## ORDER-043 — US30 GridLog: IS-optimize probe (optional, EV ต่ำ) — `REVIEWED/CLOSED (Claude รันเอง, 2026-07-09 — ❌ US30 = DEAD-optimized ปิดทะเบียนถาวรแบบ USDCHF)` _(renumbered 042→043: ชนกับ DealsExporter ของ session คู่ขนาน)_

**ผล + verdict (Claude, 2026-07-09):** IS optimize 72 rows (เลน 2) → 13 pass ผ่านเกณฑ์ PF≥1.2&n≥60,
BUY ล้วน, ดูเป็น plateau (Dist2.2×TP0.5 ยืน 3 Step: 1.62/1.53/1.49) → plateau-center Pass 7 (2.2/1/2.2/0.5,
IS PF 1.53/218) → **fresh-start OOS 2025.07-2026.07 = PF 1.03 (flat) · BWD 2020-22 = PF 0.86 (ลบ)** —
IS-plateau คือ selection-fit ของช่วง US30 ไต่ขึ้น 2023-25 ตรงกับ signature เดิมใน MASTER_BACKLOG
("US30 IS 3.31/OOS 0.13 = pure regime artifact") · probe ครบตามกฎ no-DEAD-before-optimize: sweep แล้ว
เห็น surface แล้ว ทดทั้งสอง regime แล้ว → **DEAD-optimized ถาวร** · set/XML: `Boss14_GridLog_US30_opt1.set`,
`BOSS14_OPT_US30_IS.xml`, `US30_P7_OOS/BWD.htm`

**ทำไม:** recon 4 variants (Claude 2026-07-06) ทั้งหมด PF 0.78-0.96 — ไม่มี life แบบทอง แต่กฎ no-DEAD-
before-optimize ให้ 1 probe ก่อนปิดทะเบียน. **อย่าลัดคิวงานอื่น — นี่ optional**
**งาน:** copy `Boss14_GridLog_XAU_opt1.set` → `Boss14_GridLog_US30_opt1.set` (แก้ magic=990303) รัน optimizer
เหมือน ORDER-028 แต่ Symbol=US30 (IS 2023.01-2025.06, Model 1, เลน 2) → `BOSS14_OPT_US30_IS`
**Acceptance:** XML + จำนวน pass PF≥1.2&n≥60 + top-5 ดิบ · commit `[tag] ORDER-043 done`
**ห้าม:** verdict — 0 qualifying = Claude จะปิด DEAD-optimized (ปิดทะเบียนถาวรแบบ USDCHF)

**ผล:** _(รอ)_

---

## ORDER-044 — EURUSD Trading Forex Robot: full chain re-test — `REVIEWED(Claude, 2026-07-07 — ❌ REJECT ปิดถาวรที่ด่านแรก: BWD 2020-22 PF 0.39 / -$5,840)` · CLOSED

**VERDICT: ❌ REJECT — DO-NOT-RE-EXAMINE.** BWD-OOS 2020-2022 = PF 0.39, net -$5,840 (จาก 10k) —
"WATCH/PARKED-thin 48t" จากปี 63-EA screen จบเคสในรันเดียว: เลขสวย 2026 (3.89) = regime เท่านั้น.
chain หยุดที่ด่านแรกตามออกแบบ (ไม่เสีย compute กับ trade-list/spread/year-split ของศพ) ·
**re-exam queue จาก 63-EA screen เดิม = เคลียร์หมดแล้ว** (R3 คือตัวสุดท้าย) · report `BWD4_EURUSDForexRobot.htm`

**ทำไม (คำตอบ "MT4 demo ว่าง เทสอะไรต่อ" ของ user 2026-07-06):** ตัวเดียวจาก 63-EA MT4 screen เดิมที่ได้
verdict "WATCH/PARKED — **NOT martingale** (scrutinize เคลียร์), ตกแค่ thin sample 48t, needs deep re-test"
— ตอนนี้ filter chain ครบแล้ว. ถ้าผ่าน = MT4 demo slot ตัวที่ 2 อย่างถูกต้อง (คู่กับ ClevrFX)
**สถานะ:** `.ex4` copy จาก `D:\Forex\01_INBOX_NEW\2.1 review EA\MT4 good\EURUSD Trading Forex Robot.ex4`
→ data-dir Experts แล้ว
**Chain (ตามกฎใหม่ + trade-list-first rule ของ session คู่ขนาน):**
```powershell
# (1) BWD-OOS 2020-2022 — ด่านแรก
powershell -File D:\EA_LAB\scripts\mt4_run.ps1 -Expert 'EURUSD Trading Forex Robot' -Symbol EURUSD -Period H1 -FromDate 2020.01.01 -ToDate 2023.01.01 -Model 1 -ReportName BWD4_EURUSDForexRobot -TimeoutSec 600
# (2) ถ้า PF>1 + DD<40%: อ่าน trade list ทันที (SL มีไหม + lot progression) — ก่อนเสีย compute ต่อ
# (3) รอด → year-split 2020/21/22 แยกปี + spread-stress -Spread 30/45 บน 2026.03-07
```
**Acceptance:** BWD full + trade-list findings (SL/lot ladder) + year-split + spread 30/45 · commit `[tag] ORDER-044 done`
**ห้าม:** verdict — เกณฑ์ Claude ชุดเดียวกับ ClevrFX (ทุกปีบวก + spread 2x PF>1.3 + ไม่มี martingale ladder)

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

---

## ORDER-042 — DealsExporter: nightly deals snapshot สำหรับ /ea-monitor — `REVIEWED(Claude, 2026-07-06 — ✅ ทำเอง สร้าง+พิสูจน์ครบ · เหลือ user attach 1 chart)` (role: code)

> ⚠️ renumbered จาก ORDER-039 (2026-07-06 ค่ำ) — เลขชนกับ AsReMix ของ session คู่ขนาน ·
> **บทเรียน: สอง session ออก order พร้อมกันได้ → ตั้งเลขใหม่ต้องอ่าน git log/บอร์ดล่าสุดก่อนเสมอ**

**ทำไม:** monitoring ชั้นตัดสิน (keep/kill ต่อ EA) ต้องใช้ deals history แตกตาม magic — เดิม export
มือ พึ่งความขยันคน · Myfxbook ใช้เป็นแค่ชั้นดูสุขภาพ account (มองไม่เห็น magic)

**ของที่ได้:**
- `tools\DealsExporter\DealsExporter.mq5` + `.ex5` — EA read-only (ไม่มี trade function ทั้งไฟล์)
  แปะ 1 chart บน account ที่จะ monitor → เขียน deals ทั้งหมดเป็น CSV ลง
  `Common\Files\EA_LAB_deals_<login>.csv` ตอน attach + ทุกวันเวลา `InpExportHour` (default 23)
  · full-snapshot overwrite = idempotent
- `scripts\collect_live_deals.ps1` — เก็บ CSV จาก Common\Files → `portfolio\live_deals\<ชื่อ>_<วันที่>.csv`
  (เข้า git = audit trail) — รันก่อน `/ea-monitor` ทุกครั้ง
- **พิสูจน์แล้ว:** compile 0/0 · รันใน tester → CSV โผล่ที่ Common\Files จริง (header ถูกต้อง) ·
  collector เก็บเข้า repo สำเร็จ
**งานที่เหลือ (user, 2 นาที):** copy `tools\DealsExporter\DealsExporter.ex5` เข้า `MQL5\Experts`
ของ terminal demo (Exness) → ลาก EA ใส่ chart ไหนก็ได้ 1 chart → เปิด AlgoTrading →
เช็ค journal เห็น `[EXPORT] N deal rows`
- USER-ACTION: attach DealsExporter.ex5 บน terminal demo 1 chart (วิธีอยู่ใน ORDER-039 — 2 นาที)
- USER-ACTION: สมัคร Myfxbook ฟรี + เชื่อมบัญชี demo ด้วย investor password (ดูสุขภาพ account จากมือถือ — 5 นาที)

---

## ORDER-057 — mold upgrade: `Regime.mqh` (market-state filter, additive) — `Stage A REVIEWED(Claude, 2026-07-09 — ✅ ACCEPT · Stage B OPEN สำหรับ ZCode/oc-btest)` · **ทำได้: Codex/Claude/oc-dev** · 👉 **Codex-direct** _(ออก 2026-07-09, user สั่ง: "อยากได้ตัวระบุสภาวะตลาด trend/sideway เป็น direction ให้ EA + ปิดได้")_

**Stage A review (Claude, 2026-07-09):** โค้ด Codex ผ่านทุกข้อ — closed-bar classify (shift 1, no repaint) +
cache ต่อแท่ง regime-TF · gate เฉพาะ first-entry ทั้ง 2 path (resting-stop + market) ไม่แตะ exit/basket ·
direction convention 1=BUY/2=SELL ตรง Entry_ST03 · handle init/release ตามแบบ Indicators.mqh · mode 0 no-op
จริง (พิสูจน์: run มี module = run ไม่มี module ตรงกันทุกหลักทศนิยม) · **เหตุการณ์ระหว่าง review: cage ขึ้น
DRIFT 4 ตัว → สอบสวนด้วย control run บน HEAD สะอาด = เลขเพี้ยนเหมือนกันเป๊ะ → root cause คือ XAUUSD history
refresh (trade count เท่าเดิมทุกตัว กำไรขยับ ~1-4%) ไม่ใช่โค้ด → re-baseline บน HEAD แล้วรันซ้ำกับ module =
CLEAN 4/4 · บทเรียน: DRIFT ที่ trade count เท่าเดิม + กำไรขยับเล็กน้อย = สงสัย data-side ก่อน code-side,
พิสูจน์ด้วย control run เสมอ** · sanity A/B ของ Codex: mode 1 (block RANGE) 426→378 ไม้ = gate กัดจริง

**เก็บตกหลักฐาน (Claude, 2026-07-09 บ่าย):** เจอช่องว่าง — `mt5_run.ps1` ไม่ compile ดังนั้น control run
แรกเทียบ binary เดียวกัน (พิสูจน์แค่ history ไม่ใช่ source) → ปิดช่องด้วยการ compile เอง 2 รอบ:
source มี module (compile 0/0) vs source ก่อน module (checkout `36a6819`, compile 0/0) → regression
เลขเท่ากันเป๊ะทุกหลักทั้งคู่ = **mode-0 no-op พิสูจน์ end-to-end ระดับ source ด้วยมือ lead แล้ว** ไม่พึ่งคำ Codex

**Stage B — reassign เป็น Claude รันเอง (2026-07-09: user cancel Codex — quota หมด กลับ 2026-07-11 · ZCode n/a):**
matrix 32 runs เสร็จแล้ว → `_mt5_auto\REGIME_AB.csv` · runner = `_mt5_auto\ab_sets\regime_sets\run_regime_ab.ps1`

**Stage B VERDICT (Claude, 2026-07-09):**
- **XAU (Boss_14 chassis, ISpick): trend-only gate = ของจริงระดับ in-sample** — m1 (block RANGE):
  BWD PF 1.07→**1.88/1.88/1.82** (thr 20/25/30 = plateau ไม่ใช่ spike) net 121→799 · FWD เสียนิดเดียว
  1.42→1.39 (thr20) n 426→405 · eqDD ลดทั้งสอง window (23.35→20.05% / 8.30→7.30%) · **shape ที่ต้องการ
  เป๊ะ: เฉือนกำไรปีกระทิงนิดหน่อย แลก window อ่อนพลิกจากแทบเจ๊าเป็น 1.88**
- **AUDNZD (DEMO champion): ไม่เอา** — ทุก config ที่ช่วย BWD ทำร้าย FWD สลับกัน (m1t20: FWD 1.53↑ แต่
  BWD 0.74↓ · m1t25: BWD 1.76↑ แต่ FWD 1.27↓) ยกเว้น thr30 ที่ต้องจ่ายไม้หาย ~75% = thin · no plateau
- mode 2 (direction-lock) ≤ mode 1 ทุก cell ที่เทียบได้ → mode 1 คือตัวจริงของ lever นี้
- m1 range-only: FWD 2.05 บน n=38 / BWD 0.60 = thin+flip ทิ้ง
- **Stage C (สมมติฐาน user "COT+trend filter ใช้คู่กัน"): ทดสอบแล้ว — COT ไม่เพิ่มค่าบน ADX** — ใน
  trade ที่ผ่าน ADX gate แล้ว (n=512) ทุก COT bucket กำไรหมด (LOW 1.22 / MID 1.25 / HIGH 1.54) ตัด LOW
  = ตัดกำไร ไม่ใช่ตัดขาดทุน + year-split ยังไม่เสถียร (2024 LOW 1.93) → COT จบที่ dashboard light ตามเดิม
- **ข้อจำกัด verdict:** เลือก config จาก 2 window ที่เห็นทั้งคู่ = in-sample selection · **ห้าม retrofit
  เข้า demo cohort ที่ validate แล้ว** (กฎเดิม) · adoption ที่ถูก = `_50_` เป็น axis ใหม่ใน optimize funnel
  ของ EA ตัวถัดไป + Boss V2 track (ตอน unpark) แล้วต้องผ่าน holdout+MC ของ funnel นั้นเอง
- MC PF-5th base vs m1t20 (XAU, bootstrap-w/-replacement 5000 iters บน deals จริง — caveat grid-MC เดิม):
  FWD 0.825→0.797 (จ่ายเบี้ยปีกระทิง) · BWD 0.572→**0.849** (window อ่อนดีขึ้นชัด) · ALL 0.829→0.852 —
  สอดคล้อง story ประกันภัย, ไม่เปลี่ยน verdict (lever เข้า funnel ใหม่ ไม่ retrofit)

**ทำไม:** cohort มี EA ที่ตายเพราะ regime เปลี่ยน (NZDUSD-SELL = PARKED regime-dependent ·
Scalping-AsReMix = PARKED trend-specialist edge-decay) — ถ้ามี regime filter ในแม่พิมพ์ จะได้
lever ใหม่ให้ sweep ทั้ง family และเป็นตัว "ปิดเครื่องเมื่อสภาวะไม่ใช่" ที่ demo cohort ยังไม่มี

**Stage A — implement (Codex-direct, additive เท่านั้น):**
- ไฟล์ใหม่ `ea_template\core\Regime.mqh` — enum `REGIME_TREND_UP / REGIME_TREND_DOWN / REGIME_RANGE / REGIME_STORM`
- ตัวจับ (built-in handles เท่านั้น ตามธรรมเนียม Indicators.mqh):
  - trend/range: **iADX** บน `_50_Regime_TF` — ADX ≥ `_50_ADX_TrendMin` = trend (ทิศจาก +DI/-DI), ต่ำกว่า = RANGE
  - storm: ATR ปัจจุบัน > `_50_StormATRmult` × SMA(ATR, `_50_StormLookback`) = STORM (ทับทุกสถานะ, 0 = ปิดเช็คนี้)
- inputs ใหม่ใน `Inputs.mqh` (prefix `_50_`):
  `_50_RegimeMode` **0=OFF (default)** · 1=FILTER (เทรดเฉพาะ regime ที่อนุญาตผ่าน `_50_AllowTrendUp/_AllowTrendDown/_AllowRange`; STORM = block เสมอ) · 2=DIRECTION (อนุญาตเฉพาะฝั่งตาม trend; RANGE = block ทั้งคู่)
  · `_50_Regime_TF` (default H4) · `_50_ADX_Period` (14) · `_50_ADX_TrendMin` (25.0) · `_50_StormATRmult` (2.0) · `_50_StormLookback` (100)
- จุดเสียบ: gate **การเปิดไม้ใหม่เท่านั้น** (ก่อน entry signal ใน LabCore) — ห้ามแตะ exit/basket/recovery/ไม้ที่เปิดอยู่ · ประเมินที่ bar-open ของ `_50_Regime_TF` (bar-open gate)
**Acceptance (Stage A):** compile 0/0 · **`tpl_regression.ps1` CLEAN ที่ mode 0** (default off = พฤติกรรมเดิมทุก byte) · sanity run 1 ครั้ง: XAU GridLog p20 set + mode 1 (AllowRange=false) → trade count ต้องเปลี่ยนจาก baseline · commit `[codex] ORDER-057A done`
**ห้าม (Stage A):** แตะ ExitManager/RiskControl/Recovery logic · เปลี่ยน default พฤติกรรมใดๆ · ตัดสินว่า filter "ช่วย"

**Stage B — A/B sweep (ZCode/oc-btest, หลัง A ผ่าน review):**
- EA ทดสอบ 2 ตัว: XAU GridLog (Pass 20 set) + AUDNZD champion — รัน baseline (mode 0) vs mode 1 (3 ชุด allow) vs mode 2, บน**ทั้ง 2 window: 2023-2026 + BWD 2020-2022** (กฎ both-regimes)
- sweep `_50_ADX_TrendMin` ∈ {20, 25, 30} — รายงานดิบ PF/Trades/DD ต่อ cell, append ใต้ order นี้
**ห้าม (Stage B):** เลือก config "ดีสุด" — verdict = Claude ตาม VERDICT GATE (surface ไม่ใช่จุดเดียว)

**ผล (Codex, Stage A only; ไม่มี verdict):**
- touched: `ea_template\core\Regime.mqh` (new) · `ea_template\core\Inputs.mqh` · `ea_template\core\LabCore.mqh`
- compile: Boss_11/12/13/14/15 workspace builds = **0 errors / 0 warnings**
- regression: `powershell -File D:\EA_LAB\scripts\tpl_regression.ps1` = **CLEAN**
- sanity A/B (XAU GridLog Pass-20 full window 2023.01.01-2026.07.01, Model 1):
  baseline `_50_RegimeMode=0` = **426 trades**
  filtered `_50_RegimeMode=1`, `_50_AllowRange=false` = **378 trades**
- note: MT5 expert folders were ACL-blocked from this session, so the proof run used a temporary portable sandbox under `D:\EA_LAB\_mt5_portable_order057` with the workspace-built `.ex5` + copied XAU history; raw reports:
  `D:\EA_LAB\_mt5_auto\reports\ORDER057_XAU_BASE_SB.htm`
  `D:\EA_LAB\_mt5_auto\reports\ORDER057_XAU_FILTER_SB.htm`

---

## ORDER-058 — live-monitor dashboard: ตาราง per-EA แบบเข้าใจใน 5 วิ (ต่อยอด DealsExporter) — `REVIEWED(Claude, 2026-07-09 — ✅ Sonnet ทำ, Claude ตรวจ+แก้ 1 จุด: ระดับ 🟡 ต้องใช้เตือนที่ README ประกาศ (MT4 25%/MT5 15%) ไม่ใช่สูตร 80% ล้วน · verify: synthetic CSV ผ่าน (breach/PF/unmapped/deterministic) + real CSV header-only → 8 แถว ⚪ ตามคาด · เหลือรอข้อมูลจริงหลัง user attach)` _(ออก 2026-07-09, user เห็นตัวอย่างจากโพส FB Claude Thailand แล้วอยากได้แบบนั้น)_

**ทำไม:** ORDER-042 ให้ deals CSV per-magic แล้ว แต่การอ่านยังเป็น manual/ea-live-monitor text —
user อยากได้หน้าเดียวแบบโพส FB: แถวละ EA เห็น P&L / PF / DD / สถานะ kill-switch เป็นสีทันที

**สั่งทำ:**
- script `scripts\live_dashboard.ps1` (หรือ .py ใช้ portable python ของ repo): อ่าน CSV ล่าสุดจาก
  `portfolio\live_deals\` → group ตาม magic → join ชื่อ EA + expectation จาก DEMO_DEPLOYMENT_PLAN
- output `portfolio\LIVE_DASHBOARD.html` self-contained (ไม่มี external CDN): ตาราง 1 แถว/EA —
  ชื่อ · magic · trades · net P&L · PF · maxDD% · วันเงียบล่าสุด (days-since-last-trade) ·
  คอลัมน์สถานะสี: 🟢 ปกติ / 🟡 ใกล้เกณฑ์ kill-switch / 🔴 เข้าเกณฑ์ (เกณฑ์ = ตาราง kill-switch ใน README demo bundle)
- sort: แดงขึ้นก่อน · มี timestamp ข้อมูล + ชื่อไฟล์ CSV ที่ใช้
**Acceptance:** รันกับ CSV ตัวอย่างที่มีอยู่แล้วได้ HTML เปิดใน browser ได้จริง · ค่า P&L รวมตรงกับ
ea-live-monitor ที่เคยรัน (ต่างได้ ≤ rounding) · commit `[tag] ORDER-058 done`
**ห้าม:** ตัดสิน keep/kill ใน HTML (สีเป็นแค่ flag ตามเกณฑ์ที่ประกาศแล้ว — verdict = Claude/user) ·
ห้ามแตะ scripts อื่น

---

## ORDER-059 — COT regime filter สำหรับ EA ทอง: exploratory ผ่าน → ต้อง validate เต็ม — `REVIEWED/CLOSED (Claude, 2026-07-09 — ❌ REJECT เป็น gating filter · เก็บไว้เป็นไฟบอกสถานะบน dashboard ได้เท่านั้น)` _(ออก 2026-07-09 — ไอเดียจากโพส FB Claude Thailand, user เคาะ "ทำทั้งหมด")_

**VERDICT (Claude, 2026-07-09 — validation ครบใน session เดียวกับที่ตั้ง order):**
- **Year-split ฆ่า pattern:** aggregate "HIGH ดีสุด" มาจากขาขึ้นทอง 2024-25 เกือบล้วน — รายปีพลิกไปมา
  (Trendline 2023: LOW 1.46 > HIGH 0.85 · 2021: LOW 1.24 > HIGH 1.09 · SqueezeBRK 2021-22 LOW กำไรดี 4.88/2.03)
- **Threshold sweep {33,50,67} ทั้ง BWD+FWD:** surface หยาบ ไม่มี plateau — ดีบาง cell แย่บาง cell
- **MC ตัวชี้ขาด (bootstrap-with-replacement บน P&L จริงต่อไม้ 5000 iters):**
  Trendline UNGATED PF-5th **1.011** vs GATED(≥33) **0.978** + n 351→213 = gate ทำให้ tail **แย่ลง** และทำลาย
  จุดแข็งเดียวของ Trendline (sample ใหญ่) → เส้นทาง promote #8 ผ่าน COT = ตาย ·
  BRK gated แย่ลง (1.529→1.355) · SqueezeBRK gated ดีขึ้น (1.241→2.078) แต่มัน ROBUST อยู่แล้ว ไม่คุ้มตัดไม้ 40%
- **สรุป:** REJECT แบบ PARAMETRIC-มีหลักฐานครบ (ไม่ใช่ ban ข้อมูล external ทั้งชั้น — factor นี้ตัวเดียวที่ไม่รอด) ·
  ของที่เหลือใช้: `cot_pull.ps1` + แสดง COT pct เป็น**ไฟ context บน LIVE_DASHBOARD เท่านั้น ห้ามเป็นเงื่อนไข on/off** ·
  meta-lesson: exploratory เดียวที่ดูสวย = ยังไม่ใช่อะไรเลย — year-split + MC ฆ่าได้ในชั่วโมงเดียว (process ทำงาน)

---

## ORDER-060 — MT4 OrdersExporter + ท่อ monitoring MT4 ครบวงจร — `DONE+REVIEWED (Claude ทำเอง+ตรวจเอง, 2026-07-09)` _(ปิดช่องว่างจาก ORDER-042 ที่ครอบแค่ MT5)_

**ของที่ได้:**
- `tools\DealsExporter\OrdersExporterMT4.mq4` + `.ex4` (compile 0/0) — twin ของ DealsExporter.mq5:
  read-only ไม่มี trade function, full-snapshot overwrite, export ตอน attach + ทุกวันชั่วโมง `InpExportHour`
  → `Common\Files\EA_LAB_mt4_orders_<login>.csv` (order-based: 1 แถว = 1 ไม้ปิดแล้ว)
- `collect_live_deals.ps1` — เก็บ pattern ใหม่ด้วย
- `live_dashboard.ps1` — รองรับ **หลายบัญชี + สองรูปแบบพร้อมกัน** (MT5 deals + MT4 orders, เลือกไฟล์ใหม่สุด
  ต่อบัญชี, ข้าม balance/pending rows, ข้ามแถว type เสีย)
**Verify:** synthetic MT4 CSV (มี balance row + แถวคอลัมน์ตก) → ยอดตรง independent sum เป๊ะ (12.85),
balance ถูกข้าม, แถวเสียถูกข้าม (เจอ+อุด bug TryParse-fail-เขียน-0 ระหว่างทดสอบ) · ลบไฟล์ test แล้ว
**การใช้:** user attach `.ex4` บน MT4 demo 1 chart + **ต้องตั้ง Account History tab = "All History"** (MT4
export ได้เท่าที่ tab โชว์ — journal ปริ๊นท์จำนวนแถวให้เช็คได้)

---

## ORDER-061 — hunt ใหม่: (BRK)_FlagPennant @ XAUUSD H1 (กลไก next-EV จาก handoff) — `REVIEWED/CLOSED (Claude, 2026-07-09 — ❌ NO EDGE, ปิดพร้อม mechanism insight)` _(user สั่ง "hunt ใหม่เลย" — flag/pennant คือกลไกเดียวที่ handoff 07-09 ระบุว่า EV เหลือ)_

**VERDICT (levers swept 5/7: pole-strength · flag-length · flag-width · SL · TP — symbol/TF = home ที่พิสูจน์แล้ว):**
- coarse 12 cells × 2 windows: **ไม่มี cell PF>1.2 ทั้งคู่** + lever พลิกขั้วข้าม window (BWD ชอบ flagBars 4 /
  HOLDOUT ชอบ 6) = ลายเซ็น no-edge ตาม gate ข้อ 3
- RR sweep (SL{1.0,1.5}×TP{3..8}) บน cell ที่ดีสุด (pole2.0/bars4/range2.5): BWD ดีสุด 1.19 · HOLDOUT ดีสุด 1.00
  และ **TP กว้างขึ้น = แย่ลง monotone ทั้งสอง window** (TP8: 0.77-0.98 / 0.33-0.85)
- **Mechanism insight (ของจริงที่ได้จาก order นี้):** flag-continuation ตรงข้าม squeeze — squeeze เข้า "ตอนเริ่ม"
  vol expansion (TP กว้าง = ดี, กู้ด้วย RR ได้) แต่ flag เข้า "หลัง" impulse ใช้โมเมนตัมไปแล้ว → move ไม่วิ่งต่อ
  (TP กว้าง = ตาย) · **ทอง H1: โมเมนตัมถูกกินหมดใน pole — continuation-after-pause ไม่ใช่ edge ของสนามนี้**
- สรุป hunt space: flag/pennant = ลองแล้ว ❌ → กลไกใหม่ที่เหลือใน list เดิม = order-flow (ไม่มีข้อมูล) เท่านั้น ·
  ทางที่ EV เหลือจริง: **regime-axis (_50_) re-funnel ของ Boss_14 family** (lever ใหม่บน infra เดิม — Stage B
  พิสูจน์แล้วว่า lever มีชีวิตบน XAU) — user เคาะแล้ว 2026-07-09 บ่าย → ORDER-062

---

## ORDER-062 — regime-axis re-funnel ทั้ง Boss_14 family — `REVIEWED/CLOSED (Claude, 2026-07-09 — 🎯 1 hit ชัด: USDJPY · 1 borderline: EURJPY · 6 ไม่เอา)`

8 symbols (GBPAUD_p26 · CADJPY/EURJPY/EURUSD/USDJPY/AUDCAD DEMO · NZDUSD/GBPJPY ISpick) ×
{base, m1t20, m1t25} × {FWD 2023-26, BWD 2020-22} = 48 runs บนเลน 2 → `_mt5_auto\REGIME_FAMILY.csv` ·
runner = `_mt5_auto\ab_sets\regime_sets\run_regime_family.ps1` · mode2 ตัดทิ้ง (Stage B: แพ้ mode1 ทุก cell)
**เกณฑ์อ่านผล (ประกาศก่อนเห็นผล):** สนใจตัวที่ base อ่อน window นึงแล้ว m1 กู้โดยไม่ทำร้ายอีก window แบบ
plateau (ทั้ง t20+t25 ไปทางเดียวกัน) — pattern เดียวกับ XAU Stage B · ห้าม cherry-pick cell เดี่ยว

**VERDICT (ตามเกณฑ์ที่ประกาศ):**
- ✅ **USDJPY = hit เต็มเกณฑ์ตัวเดียว** — BWD (window อ่อน) 1.07/306/DD14.9% → t20 **1.54**/203/DD4.4% ·
  t25 **1.65**/184/DD4.4% (สอง threshold ไปทางเดียวกัน = plateau) · FWD ไม่เสีย (1.52→1.52/1.44) · net BWD
  352→1350 — **shape เดียวกับ XAU Stage B เป๊ะ**
- 🟡 EURJPY borderline — t25 ดีขึ้นทั้งคู่ (FWD 2.51→2.79 · BWD 1.18→1.23 + DD 11.9→5.9% ครึ่งเดียว!) แต่
  t20 ทำ BWD พัง (0.96) = threshold เดี่ยวไม่ใช่ plateau → เก็บเป็น reserve ห้าม adopt จาก cell เดียว
- ❌ GBPAUD (BWD n บางเกิน + FWD เสีย) · CADJPY (ไม่กู้) · **EURUSD (gate ทำ grid dynamics พัง — trades ระเบิด
  189→425, DD 11→20-24%: บทเรียน gate ไม้แรกกับ grid ที่พึ่ง entry ถี่ = อันตราย)** · AUDCAD (base ดีอยู่แล้ว)
  · NZDUSD (FWD พัง) · GBPJPY (t20/t25 พลิกขั้ว)
- **ข้อจำกัด:** ทั้ง 2 window ถูกใช้ select = in-sample · **ทางต่อของ USDJPY:** year-split + MC บน trade list
  m1t25 → ถ้ารอด เข้า Boss V2 bench (track ที่ park อยู่) — ไม่แตะ demo cohort ปัจจุบัน · สรุป lever _50_:
  ของจริงแบบ**เลือกบ้าน** (XAU ✅ USDJPY ✅ อีก 6 ❌) ไม่ใช่ universal — ตรง each-edge-one-home อีกครั้ง

**Validation ต่อ (Claude, 2026-07-09 เย็น): ✅ USDJPY m1t25 = CANDIDATE เข้า Boss V2 bench**
- year-split: การกู้กระจายทุกปีไม่ใช่ปีเดียว — 2020 (ปีเน่าของ base): −1,151/PF 0.58/n119 → gated −46/n18
  (หน้าที่ filter เป๊ะ: เลิกเทรด chop) · 2021-2026 บวกทุกปีหลัง gate · 2022: 1.46→1.95
- MC bootstrap 5000: base PF-5th **0.946** (<1) → gated **1.203** (ข้ามเกณฑ์) · med 1.18→1.57
- สถานะ: CANDIDATE (in-sample-selected แต่ evidence tier เท่า demo candidates เดิม) → รอ Boss V2 track
  unpark แล้วเข้า demo bench ตามคิว · set = `FAM_USDJPY_m1t25.set`

**Recheck รอบดึก (user สั่ง "ทำ 1-4", 2026-07-09):**
- ✅ **EURJPY m1t25 = CANDIDATE ตัวที่ 2** — fine-sweep t{23,25,27}: BWD 1.17/1.23/1.27 (ทุกจุด ≥ base
  1.18 + DD 11.9→~6%) FWD 2.42/2.79/2.03 = **plateau จริง 3 จุด — t20 เมื่อวานคือขอบหน้าผา ไม่ใช่ตัวแทนโซน**
  · year-split gated บวกทุกปี 2020-2026 · MC PF-5th base 1.202 → gated **1.346** · gate ทำหน้าที่ลด DD
  มากกว่าสร้าง edge (base แข็งอยู่แล้ว) · set = `FAM_EURJPY_m1t25.set`
- ❌ **AsReMix (PARKED) — ADX conditioning ไม่กู้**: aggregate ดูดี (TREND 1.45/RANGE 0.64) แต่ year-split
  พลิก 2 ใน 7 ปี (2020 RANGE 3.65 > TREND 1.01 · 2024 RANGE 6.14 > TREND 0.98) + MC gated 1.14 < 1.2 +
  **edge-decay ปีหลังยังอยู่ใน TREND bucket เอง** (2024-26: 0.98/1.17/1.18) — gate แก้ regime ได้ แก้ decay
  ไม่ได้ · ยัง PARKED · trade list เก็บที่ `ASREMIX_trades.csv`

---

## ORDER-067 — Trendline rev02 + ADX-regime gate: เส้นทาง promote #8 ที่ COT ทำไม่ได้ — `BUILT+CLOSED (Claude, 2026-07-09 ดึก — ❌ gate จริงแย่กว่า offline: artifact class ใหม่เข้าตำรา)`

**VERDICT (rev02 build + A/B จริง, binary เดียวกัน):** UNGATED 1.26/1.40/1.23 MC 0.973 · GATED(ADX≥20 H4
ณ ตอนเข้า) 1.25/1.60/**0.99** MC **0.861 = แย่ลง** — ตรงข้าม offline conditioning (1.208) สิ้นเชิง
**Root cause = artifact class ใหม่: "close-time regime conditioning = survivorship"** — trendline
breakout ที่กำไรสุดเข้า*ก่อน* ADX ยืนยัน (ADX lag) พอไม้วิ่งจนปิด ADX ขึ้นเกินเกณฑ์เอง → offline ที่ใช้
ADX ณ เวลาปิดเลยนับไม้ชนะเข้า bucket TREND โดยอัตโนมัติ ไม่ใช่เพราะ gate ตอนเข้าใช้ได้จริง · gate จริง
ฆ่าไม้ early-entry ที่เป็นหัวใจของ edge (กลไกเดียวกับ STF×Donchian ที่ล้มก่อนหน้า: lagging signal ×
event ที่มาก่อน) · **#8 คงสถานะ EXPERIMENTAL + kill เข้มตามเดิม — ไม่มีทาง promote ผ่าน regime gate** ·
บทเรียน bank เข้า backtest-optimize-rigor แล้ว: conditioning ต้องใช้ระดับตัวแปร ณ เวลา*เข้า*ไม้เท่านั้น
และของ lagging indicator ต้อง confirm ด้วย in-EA run เสมอ · หมายเหตุ: USDJPY/EURJPY (ORDER-062) ไม่โดน
artifact นี้ — สองตัวนั้นคือ in-EA run จริงตั้งแต่ต้น ✅

**หลักฐาน offline conditioning (Claude, 2026-07-09 ดึก — ผลสวยสุดของการ conditioning ที่เคยทำ):**
TLR_trades 351 ไม้ × H4 ADX (dump ผ่าน `tools\ADXDumper\ADXDumper.mq5` ตัวใหม่):
- **RANGE (ADX<20): PF 0.17** (thr25: 0.26) — ขาดทุนทั้งหมดของ Trendline กระจุกใน range regime
- **TREND: PF 1.64** (thr20) / 2.05 (thr25) · **year-split บวกทุกปี 2020-2026** (1.38-2.17) — ไม่มีปีพลิก
  (ต่างจาก COT ที่ตายตรงนี้) · RANGE ลบ 6/7 ปี
- **MC: ungated PF-5th 1.011 → gated(ADX≥20) 1.208** โดยเก็บ sample 79% (278/351 = ไม่ thin)
- threshold 20 กับ 25 ไปทางเดียวกัน = ไม่ใช่ spike
**งาน:** เพิ่ม ADX-gate inputs ใน (BRK)_TrendlineBreakout → rev02 (default OFF ตามธรรมเนียม) → รัน funnel
เต็ม 3-window + MC ยืนยัน (offline conditioning = approximation; single-position ทำให้ approx แม่น แต่ต้อง
confirm ด้วย run จริง) → ถ้าผ่าน: เข้า bench เป็น rev02 (**ห้ามแตะ #8 ตัวที่ demo อยู่** — kill เข้มของมันคุมอยู่แล้ว)
**caveat ที่ต้องจำ:** conditioning ใช้ ADX ณ เวลา*ปิด*ไม้ (list มีแค่ close time) — ไม้ถือเป็นชั่วโมง H4 ADX
แทบไม่ต่าง แต่ run จริงจะ gate ที่*เปิด*ไม้ = ตัวเลขจะขยับ อย่ายึดเลข offline เป็น verdict

---

## ORDER-063 — smoke เทส EA จาก Downloads 3 ตัว — `REVIEWED/CLOSED (Claude, 2026-07-09 — ❌ ตายครบ 3: GOD4+HedgingGrid untestable-locked · Degold REJECT ที่ martingale-recheck)`

`wait for test\downloads_20260709\`: **Degold_hunter.mq5** (มี source → compile+อ่านกลไก) ·
**V2_15_SEMI_ORI_FINAL_GOD4.ex5** (locked) · **Hedging Grid Pending Auto Lote v.1.ex5/.ex4** (locked, ชื่อบอก
hedge-grid = เข้าเกณฑ์ martingale-recheck ก่อน reject) · smoke W1 2024-2026 → รอด (PF>1.1, n≥30) ได้ W2
BWD 2020-22 · main tester (เลน 1)

**ผล smoke (ea-screener agent, Claude review):**
- ❌ **V2_15_SEMI_ORI_FINAL_GOD4.ex5 = REJECT (untestable)** — locked, init fail ทันทีทั้ง XAU/EURUSD
- ❌ **Hedging Grid Pending Auto Lote v.1 = REJECT (untestable)** — locked, hang headless (น่าจะ dialog license)
  ทั้งสอง symbol · ไม่มี source = no verdict possible ตามนิยาม (แบบเดียว North East Way ORDER-037)
- 🚨 **Family2.2.ex5 (zip โหลด 07-09 เช้า, user ถามบ่าย) = DQ-SECURITY ห้ามรันห้าม attach ทุกกรณี** —
  วิธีใช้สั่งเปิด **DLL imports** + whitelist WebRequest ไป **http://ea.sytes.net/** (dynamic-DNS ฟรี, HTTP
  ไม่เข้ารหัส) + no source = โปรไฟล์ phone-home/exfil ตำราเป๊ะ · ไม่เทสแม้ใน tester (เปิด DLL ให้ binary
  แปลกหน้า = ให้กุญแจเครื่อง) · แฟ้มกักไว้ที่ `wait for test\downloads_20260709\EA_Family22\` — **ห้าม copy
  เข้า Experts folder ใดๆ** · ถ้าใครในกลุ่มเปิด DLL+URL ไปแล้วบนเครื่องบัญชีจริง: ถอด EA, ปิด DLL, ลบ URL,
  เปลี่ยนรหัสเทรดทันที · user เคาะ "ไว้ก่อน" 2026-07-09
- ❌ **Degold_hunter = REJECT ถาวร (optimize-complete + artifact-proven)** — ไล่ครบทุกชั้นตามที่ user ทัก:
  1. smoke W1 สวย (PF 1.79 / n 9,896 / DD 14%) แต่ **flat-lot: PF 0.83 / DD 81.94%** = escalation ล้วน
  2. **probe optimize** (user สั่ง): spacing {30,165,300} × target {10,80,150} × RSI-gate {off,on} × 2 windows
     = 36 cells → M1 โชว์เลขมหัศจรรย์ (PF 3-8, n สูงถึง 464k!) = โปรไฟล์กับดัก Model-1
  3. **artifact check ชี้ขาด**: cell ดีสุด (RSI-on d30) window เดียวกัน 2026H1 —
     **Model 1: +$343,880 PF 13.12 / Model 4 tick จริง: −$4,284 PF 0.56 DD 47.6%** = edge ทั้งหมดคือ
     fantasy fill ของแท่งสังเคราะห์ (rolling straddle ระยะจิ๋วเลือดไหลค่า spread ตลอดเวลาบน tick จริง)
  · levers swept 4 แกน + both windows + M1/M4 = REJECT สมบูรณ์ตาม gate ทุกข้อ ไม่มีชั้นค้าง
  · reports: `DG_XAU_W1*.htm` / `DEGOLD_PROBE_*.xml` / `DG_ARTCHECK_M1/M4.htm`

**หลักการที่สกัดจาก source (user ขอ "อ่าน logic เอาหลักการมาต่อ"):**
- ✅ **น่าทดลองต่อ 1 ชิ้น: basket-trailing จาก volume-weighted average** — Degold trail SL ทั้ง basket
  อ้างอิงราคาเฉลี่ยถ่วง lot (โหมด candles/fractals/points, ต้องกำไรขั้นต่ำก่อน trail) — ExitManager ของ
  Boss chassis ยังไม่มีโหมดนี้ (มีแต่ basket TP money/ATR) → ลง backlog เป็น mold-lever candidate
  (additive + cage มีอยู่แล้ว — งานสไตล์ ORDER-027)
- 🟡 พอจด: auto-TP scale ตาม lots×tickvalue (เรามี ATR-scaled แล้ว ใกล้กัน) · direction-lock รายฝั่ง
  (คล้าย RiskControl เราแบบ per-side)
- ❌ อย่าเอา: rolling straddle chase (แกนกลางของมัน = ตัวที่ M4 ฆ่า — จ่าย spread ทุกการขยับ) ·
  RSI gate เฉพาะไม้แรกแล้วปล่อย grid ดื้อ (blueprint RSI-MR เราทำถูกกว่า: signal คุมทุกไม้)

---

## ORDER-064 — ขุดไอเดียจาก Open WebUI export 93MB (คุยกับ OpenAI ของบริษัท) — `IN-PROGRESS (Claude + 4 Sonnet agents, 2026-07-09)`

- **Stage 1 ✅:** `scripts\chatgpt_export_inventory.py` (รองรับทั้ง OpenAI export และ Open WebUI format) →
  45 บทสนทนา, จัดอันดับตาม MQL-keyword density → `_triage\chatgpt_inventory.csv` + top-12 แตกเป็น .txt ใน
  `_triage\chatgpt_convs\` (⚠️ ข้อมูลบริษัท — .txt/.csv **ไม่เข้า git**, เก็บ local เท่านั้น)
- **Stage 2 (กำลังรัน):** 4 Sonnet agents skim 12 ไฟล์ → catalog กลไก/โค้ด/ความใหม่เทียบ cohort
- **Stage 3 (Claude):** judge catalog → เลือก build candidates (เกณฑ์: กลไกใหม่จริง + กติกาชัด — VWAP-based
  น่าสนใจสุดเพราะ cohort ยังไม่มี) · ที่เหลืออีก 33 บทสนทนา = อ่านเฉพาะถ้า top-12 ให้ของดี

**VERDICT Stage 3 (Claude, 2026-07-09 — catalog ครบ 12/12):**
- **ขยะ/ซ้ำของที่เรามี-REJECT แล้ว (7 ไฟล์):** 024 scaffold framework · 015 recovery-hedge spec (ตระกูล REJECT
  81/82) · 041 AW-Recover clone (**ไม่มี SL ต่อไม้ทั้ง 5 เวอร์ชัน**) · 030 prompt-eng session · 036 triage PDF
  ซ้ำ STRATEGY_200_ANALYSIS · 022+009 = 11-EA ตาม**โหราศาสตร์** (โค้ดครบแต่ allocation ไม่ใช่ market logic)
- **ของจริงที่สกัดได้ — จัดอันดับ build EV:**
  1. 🥇 **SuperTrend/HalfTrend/Chandelier "ATR-band flip"** — โผล่อิสระ **5 แหล่ง** (025 HalfTrend MTF ·
     043 Smart Trail · 009 P10 · 022 P10 · STRATEGY_200 #68 top-pick) · กลไก: trailing extreme ∓ ATR×mult
     พลิกทิศ = trend-follow ที่ exit ด้วยเส้นวิ่งตาม ไม่ใช่ fixed TP · บ้านที่ควรเทส: XAU H1 (edge class
     momentum ที่พิสูจน์แล้ว) · build ถูกสุด (indicator เดียว + โครง L1 มีแล้ว) → **ORDER-065**
  2. 🥈 **VWAP Wave (010 — สเปคเต็ม 4 setup)** — VWAP+SD band แยก Balance/Discovery + Initial Balance ·
     กลไกใหม่แท้ต่อ cohort (ไม่มีตัวไหนใช้ fair-value anchor) · ต้องกลั่นเหลือ setup เดียวก่อน (S1 continuation
     หรือ S4 VWAP-bounce) — ห้าม build ตามสเปค 30 ไฟล์ (บวม+ML+Wyckoff = overfit trap) → **ORDER-066**
  3. 🥉 **Z-score pairs stat-arb EURUSD/USDCHF** (009 P5 + 022 P5 สองแหล่ง) — market-neutral = return stream
     คนละจักรวาลกับ cohort ทั้งกอง · ติดเรื่อง infra (multi-symbol tester + ไม่มี price SL ในดีไซน์เดิม = ต้อง
     ใส่ hard SL เอง) → วิจัยความเป็นไปได้ก่อน build → backlog
  4. **Graft ideas ใส่ของที่มีอยู่ (ถูกมาก):** ATR>1.2×ATR_MA เป็น squeeze-proxy ราคาถูก (032) · vote N-of-M
     gate (043/032) · asymmetric-lot MTF confluence (025 — เห็นต่างเข้าครึ่งไซส์) · time-stop 48 แท่ง (032)
  5. **Anti-pattern เก็บเข้าคลัง:** virtual SL (043) · recovery-multiplier ซ้อน martingale (043) · equity-based
     kill แทน price SL (041) · "AI/Neural" = ป้ายการตลาดของ EA ขายตลาด 90% (035 audit ชี้ Quantum Emperor
     เจ้าของเติมเงินเข้า signal ปิด DD!)
- Boring-Pips-style cross-pair reversion (035) + session-gate (022 P11) = MED เก็บ backlog ไม่เร่ง

---

## ORDER-065 — build: (TRD)_SuperTrendFlip @ XAUUSD H1 — `BUILT+FUNNELED (Claude, 2026-07-09 — 🅿️ RESERVE: ผ่าน 3 windows แต่ MC PF-5th 0.865 <1 = naked-signal floor เดิม)`

กลไก: trailing extreme ∓ ATR(p)×mult พลิกทิศ (SuperTrend-style) · เข้าเมื่อ flip ตามทิศ + EMA200 filter ·
exit = เส้น SuperTrend วิ่งตาม (ไม่มี fixed TP) + hard SL = เส้น ST เสมอ · L1 โครง SqueezeBRK · magic 991006
· source: `ea_projects\(TRD)_SuperTrendFlip\` compile 0/0 (ST คำนวณ recompute-from-lookback กัน recompile-reset)

**ผล funnel (2026-07-09 ค่ำ):**
- default smoke: มี life (n 264/183/119) · coarse sweep ATR{10,16,22}×mult{2,3,4} สอง window เลือก:
  คอลัมน์ mult=4 เท่านั้นที่บวกทั้งคู่ · **atr22/m4 = config เดียวที่บวกครบ 3 windows: 1.02 / 1.11 / 1.32**
  (FWD confirm ไม่ได้ใช้เลือก) · RR-exit (fixed TP 4/6/8) ไม่กู้ (TP6: 1.07/1.25 — ดีขึ้นจิ๋ว)
- **MC 5000 บน 349 ไม้รวม: PF-5th 0.865 / med 1.185 → NOT_ROBUST** — พื้นเดียวกับ plain-squeeze 0.837 /
  plain-trendline 0.867 = ยืนยัน meta-pattern "สัญญาณเปลือยบนทองตันที่ ~0.85"
- **สถานะ: RESERVE (research)** — เส้นทางกู้ที่มีบทพิสูจน์ (SqueezeBRK 0.837→0.966→1.25): เติม confluence
  (Donchian-60 break + squeeze state) + re-opt tight-SL/wide-TP → คิว session หน้า ถ้ากู้ได้ค่อย corr-check
  เทียบ Zeus/BRK/SqueezeBRK (family เดียวกัน — corr สูง = ไม่เพิ่มค่าแม้ผ่าน)

**Rescue #1 (Claude, 2026-07-09 ดึก — user สั่ง "ทำ 1-4"): ❌ ล้มเหลว พร้อมเหตุผลเชิงกลไก** —
Donchian-60 AND-condition ทำ sample พัง 159/108 → **27/21 ไม้** และ PF ไม่เสถียร (line-trail BWD 0.39 ·
RR cells บน n=27 = noise) · สาเหตุ: **ST flip เป็นสัญญาณตามหลัง — จังหวะ flip มาถึง Donchian break ผ่านไป
นานแล้ว** เงื่อนไข AND แทบไม่ intersect (ต่างจาก squeeze-release ที่คือวินาทีเดียวกับ break = ทำไมสูตรกู้
work ที่นั่นแต่ไม่ transfer มาที่นี่) · rescue ทางอื่นต้องเป็น confluence แบบ concurrent-state (ไม่ใช่ event)
เช่น squeeze-state/ADX-state — เก็บไว้พิจารณา ไม่เร่ง · RESERVE คงเดิม ความหวังลดลง

## ORDER-066 — build: (VWAP)_WaveS1 distilled @ XAUUSD — `BUILT+FUNNELED (Claude, 2026-07-09 ค่ำ — ❌ NO EDGE ปิดพร้อม mechanism insight)`

กลั่นจาก conv 010 เหลือ **setup เดียว**: VWAP daily-anchor + SD band 1.0/1.5 → Price-Discovery continuation
(break 1.0SD + acceptance ≥3 แท่ง → เข้า pullback แตะ band) · ห้ามยก ML/Wyckoff/Volume-Profile มา (ตัดให้เหลือ
VWAP+SD+ATR ล้วน) · ของใหม่แท้ต่อ cohort — ค่า EV อยู่ที่ความ uncorrelated · magic 991007
- source: `ea_projects\(VWAP)_WaveS1\` compile 0/0 รอบแรก · intraday จริง (flat ก่อนวันใหม่ + one-shot/day)

**VERDICT (levers swept 4: BandMult{1,1.5,2} × AcceptBars{2,3,4} × TF{M15,H1} × SL/TP{1-1.5×2-6} · both regimes):**
- defaults M15: 0.78/1.03/1.08 (n 775/515/385 — ไม้สุขภาพดี กลไกทำงานตามออกแบบ) · H1 แย่กว่า (0.83)
- coarse sweep 18 cells: **ลบทุก cell ใน BWD** (ดีสุด 0.96) · HOLDOUT ไม่มีอะไรเกิน 1.03 — surface เรียบตาย
- RR sweep 12 cells: BWD ยังลบหมด (ดีสุด 0.88) — ไม่มีปาฏิหาริย์
- **Mechanism insight (ของที่ได้จริง): VWAP บน XAU spot-CFD ใช้ tick volume ซึ่งไม่ใช่ volume จริง →
  "fair-value anchor" ที่เป็นหัวใจของกลยุทธ์ตระกูล VWAP เป็นของปลอมบน instrument เรา** — VWAP มีความหมาย
  ที่ตลาดที่ VWAP เป็น benchmark สถาบันจริง (ES/NQ futures มี real volume) ซึ่งเราไม่มี data →
  **ปิดทั้ง family VWAP บน MT5 FX/CFD** ไม่ใช่แค่ EA ตัวนี้ (จนกว่าจะมี futures data จริง) · conv 010 ให้
  เกรด "gold เหมาะกับ S1" = LLM เดา ไม่ใช่ข้อมูล — ยืนยันกฎเดิม: expected results จาก AI = ศูนย์หลักฐาน

**กลไก:** pole (impulse ≥ PoleAtrMult×ATR ใน PoleBars แท่ง) → flag (พักตัวแคบ ≤ FlagRangeAtrMult×ATR,
retrace ≤ MaxRetrace ของ pole) → break ขอบ flag ตามทิศ pole · L1 single-position จริง SL/TP ATR-based,
EMA200 filter, bar-open, magic **991005**, AllowLive=false · แตกต่างทุกกลไกใน cohort (ต้องมี impulse ก่อน)
- source: `ea_projects\(BRK)_FlagPennant\(BRK)_FlagPennant_rev01.mq5` · compile 0/0
- smoke default (pole 3.0×ATR): บางเกิน — 9/6/2 ไม้ 3 window → ห้ามตัดสิน, sweep ก่อนตามกฎ
- coarse sweep 1 (pole {1.5,2.0,2.5} × flagRange {2.0,2.5} × flagBars {4,6}, 12 pass) บน BWD 2020-22 +
  HOLDOUT 2023-24 (FWD 2025-26 เก็บไว้ confirm ห้ามใช้เลือก) — กำลังรัน
**เกณฑ์ไปต่อ:** มี cell ที่ n≥60/window และ PF>1.2 ทั้งสอง window → fine sweep + FWD confirm + MC · ไม่มี = ปิดแบบ
เดียวกับ plain-squeeze (บันทึกแล้วเลิก)

**ทำไม:** สมมติฐาน (ตั้งก่อนดูข้อมูล — จากคอมเมนต์ CME/Spotgamma ในโพส FB): EA momentum/breakout
บนทองควรทำงานดีเมื่อ speculator net-long สูง (= regime เทรนด์). ทดสอบครั้งเดียว ไม่ได้ sweep หา factor

**ของที่มีแล้ว (Claude, 2026-07-09):**
- `scripts\cot_pull.ps1` → `_mt5_auto\cot_gold.csv` — CFTC legacy COT gold (088691) รายสัปดาห์
  2019→ปัจจุบัน 391 แถว + `net_pct_3y` (percentile ของ noncomm-net ใน trailing 156 รายงาน) ·
  Socrata API ฟรี ไม่ต้องมี key · **join ต้อง lag +3 วัน** (รายงานข้อมูลวันอังคาร เผยแพร่ศุกร์ — ไม่งั้น lookahead)
- **Exploratory (lag แล้ว, trade list จาก backtest funnel 07-08, bucket LOW<33 / MID 33-67 / HIGH>67):**

| EA | LOW n/PF | MID n/PF | HIGH n/PF |
|---|---|---|---|
| SqueezeBRK | 37 / **0.72** | 25 / 2.98 | 33 / **3.96** |
| Trendline (#8 exp) | 138 / 1.20 | 96 / 1.00 | 117 / **1.91** |
| BRK-XAU | 26 / 2.63 | 28 / 1.81 | 32 / 2.80 |

  อ่านดิบ: ทุกตัว HIGH ดีสุด · SqueezeBRK monotone ชัด (LOW ขาดทุนจริง) · BRK เกือบไม่แคร์ regime
  (สอดคล้องที่มันผ่านทุกด่านอยู่แล้ว) · **use case ที่หอมสุด: Trendline #8** — ถ้า gate แล้ว PF-5th
  ข้าม 1.0 ได้ = promote จาก EXPERIMENTAL

**งาน validate (ก่อนใช้จริง — VERDICT GATE เต็ม):**
1. per-year split 2020-2026 ทุก bucket (กัน pattern มาจากปีเดียว) + ทั้ง 2 window BWD/recent
2. sweep threshold {50, 67, 75} — ดู surface ไม่ใช่จุดเดียว · นับ trade ที่หายไป (BRK ~13/yr บางอยู่แล้ว)
3. ถ้ารอด: รัน MC บน trade list ที่ gate แล้วของ Trendline — PF-5th ต้อง >1.0 ถึง promote
4. operational: filter นี้เป็น weekly on/off ที่มือคนทำได้ (ไม่ต้องแก้ EA) — ถ้าผ่าน ให้โชว์ COT pct
   ปัจจุบันใน LIVE_DASHBOARD (ORDER-058) เป็นไฟบอกสถานะ
**ห้าม:** เอา bucket ไป gate EA จริงตอนนี้ · ประกาศ "validated" จากตารางบนนี้ (single-factor,
funnel-era trade lists, ยังไม่ split ปี)












---

## ORDER-068 — ST03 family: flat-lot probe ของ config แล็บ (9397 GBP / 9398 CAD) — `DONE(Claude-agent, 2026-07-10)` (role: agent/qwen)

**ทำไม:** 2026-07-10 แกะ source (ST) EA03 Count MACD v1 พบ (a) entry ไม่มี edge ใน config user 939721
(flat-lot PF 0.68 = ล้างพอร์ต, กำไรทั้งหมดมาจาก uncapped recovery escalation) (b) ratchet defect —
LOTB reset เฉพาะตอนพอร์ตแบนสนิท → ตะกร้าซ้อน = ทบ 2 เท่า (ที่มาไม้ 33.73 lots บนบัญชีจริง) ·
หลักฐาน `_mt5_auto\reports\ST03LIVE_*` · **คำถามที่ order นี้ต้องตอบ: config ของแล็บเอง (live 9397/9398)
โดนโรคเดียวกันไหม?** ถ้า flat-lot ของ config แล็บ PF<1 ทั้งคู่ = กำไร ST03 ทั้ง family มาจาก escalation
→ กระทบ judge 2026-09-22 + แผน Boss_15/Entry_ST03 ทั้งหมด

**คำสั่ง:** หา .set/input จริงของ 9397 (GBPUSD) + 9398 (USDCAD) จาก _demo_deploy / DEMO_DEPLOYMENT_PLAN
→ รัน 2 คู่ backtest H1 2023.01.01-2026.07.01 Model 1 deposit 10000 leverage 1:2000: (1) config ตรง
(2) ปิด escalation (LOT_Repeat=999999 — ระวัง: =1 คือ "ทบทุกไม้" ไม่ใช่ปิด) · report prefix ST03LAB_

**Acceptance:** ตาราง 4 แถว (symbol × esc on/off): PF · net · balDD% · eqDD% (floating) · max single lot ·
append ใต้ order นี้ · commit `[tag] ORDER-068 done`
**ห้าม:** verdict/ตัดสิน family · ห้ามแตะ .set ใน _demo_deploy (ก๊อปมาแก้ใน _mt5_auto\ab_sets เท่านั้น)

### RESULT (Claude-agent 2026-07-10) — raw numbers only, no verdict

Config provenance: ไม่มี .set ใน `_demo_deploy\MT5` สำหรับ ST03 — ใช้ `_mt5_auto\MACD_GBPUSD_locked.set` /
`MACD_USDCAD_locked.set` (MACD_Count=2 · TP 20/10/5 (EA defaults) · LOT_Repeat=3 · Nearby_PIP=10 ·
Magic 9397/9398) + deployed lot fix `Lots_divided=100000` (DEMO_DEPLOYMENT_PLAN.md 2026-06-22 line 146,
locked.set เดิมเขียน 10000000 ก่อน fix). หมายเหตุ: ค่า config แล็บ GBP จึง **เท่ากับ config user 939721 ทุกตัว
ยกเว้น magic** — แถว GBP esc-on ตรงกับ ST03LIVE_FULL (PF 2.51) เป๊ะ ตามคาด (deterministic).
Runs: H1 · 2023.01.01–2026.07.01 · Model 1 · deposit 10000 · leverage 1:2000 · ini/set copies ใน
`_mt5_auto\ini\ST03LAB_*.ini` + `_mt5_auto\ab_sets\st03lab_sets\` · reports `_mt5_auto\reports\ST03LAB_*.htm`

| symbol | escalation | PF | net | balDD% | eqDD% (float) | max single lot | trades |
|---|---|---|---|---|---|---|---|
| GBPUSD (9397) | ON (LOT_Repeat=3) | 2.51 | +88,219.21 | 14.16% | 61.19% | 3.06 | 1002 |
| GBPUSD (9397) | OFF (LOT_Repeat=999999) | 0.68 | −10,054.49 | 100.24% | 100.31% | 0.23 | 561 |
| USDCAD (9398) | ON (LOT_Repeat=3) | 1.67 | +18,197.30 | 16.85% | 57.09% | 1.45 | 802 |
| USDCAD (9398) | OFF (LOT_Repeat=999999) | 0.40 | −9,941.62 | 99.59% | 99.69% | 0.13 | 350 |

(flat-lot ทั้งสอง symbol: บัญชีล้าง — margin level จบที่ 3.84% GBP / 17.94% CAD)

---

## ORDER-069 — (Boss)_ZeusInspired_GridLog_rev01 บน EURUSD: coarse optimize — `DONE(Claude-agent, 2026-07-10)` (role: agent/qwen)

**ทำไม:** user directive 2026-07-10 — Zeus MT4 ตัว locked บน EURUSD H1 = เซลล์เดียวที่รอด 3.5 ปี
(PF 1.61 แต่ DD ลอย 47.8% ไม่มี SL = แก้ไม่ได้เพราะ locked) · แต่เรามี **ZeusInspired rev01 ที่เขียนเอง**
(ATR spacing + LOG lot + SL จริง + partial close) ซึ่งยังไม่เคย optimize บน EURUSD (screen 27 symbol
รอบ 2026-07-03 EURUSD ไม่ติด top แต่ยังไม่เคยโดน sweep จริง — กฎ "ห้ามตายก่อน optimize")

**คำสั่ง:** ใช้ `scripts\mt5_optimize.ps1` + EA `(Boss)_ZeusInspired_GridLog_rev01` (อยู่ ea_projects\...,
ติดตั้งใน tester ตาม pattern เดิมของ 27-symbol screen) · EURUSD H1 · 2023.01.01-2026.07.01 · Model 1 ·
Optimization=1 · base set = `ZeusInspired_V1_Medium.set` · sweep levers หลักที่มีใน set: ATR-spacing mult ·
first-lot/DD-adaptive · SL mult · partial-close (อย่างน้อย 3 lever, grid หยาบ 3-4 ค่า/lever) ·
report ZEUSINS_OPT_EURUSD_1

**Acceptance:** XML ครบทุก pass · append: จำนวน pass ที่ PF≥1.3 AND Trades≥60 AND eqDD≤15% + ตาราง top-10
ดิบ (คอลัมน์ param ครบ) · commit `[tag] ORDER-069 done`
**ห้าม:** เลือก "ตัวดีสุด"/plateau-center (งาน Claude) · ห้ามรันทับ lane ขณะ ORDER-068 ยังไม่จบ (MT5 ตัวเดียวกัน — ทำ 068 ให้จบก่อน)

### RESULT (Claude-agent 2026-07-10) — raw numbers only, no verdict/no pick

Run: EURUSD H1 · 2023.01.01–2026.07.01 · Model 1 · Optimization=1 (complete) · Criterion=0 · deposit 10000 ·
leverage 1:2000 · base = copy of `ZeusInspired_V1_Medium.set` → `_mt5_auto\ab_sets\zeusins_opt\ZEUSINS_OPT_EURUSD_1.set`
Levers (5 มิติ 216 combos ครบทุก pass): `_03_DistAtrMult` 1.0/1.5/2.0/2.5 · `_02_SlAtrMult` 2/4/6 ·
`_05_BaseLot` 0.01/0.02/0.03 · `_05_DdAdaptive` false/true · `_04_PartialFrac1` 0.0/0.3/0.6
XML: `_mt5_auto\optimizations\ZEUSINS_OPT_EURUSD_1.xml` (216/216 pass rows) + CSV แปลงแล้ว `..._passes.csv`

**Gate count (PF≥1.3 AND Trades≥60 AND eqDD≤15%): 0 / 216**
(แยกเงื่อนไข: PF≥1.3 = 0 ตัว · Trades≥60 = 182 · eqDD≤15% = 216/216 — eqDD max ทั้ง sweep 11.8%)
Distribution ดิบ: PF max 1.138 · PF≥1.0 = 26/216 · Profit max +210.35 / min −1,045.67 (บน 10k)

Top-10 by Profit (ดิบ, คอลัมน์ param ครบ):

| Pass | Profit | PF | RF | Sharpe | eqDD% | Trades | SlAtrMult | DistAtrMult | PartialFrac1 | BaseLot | DdAdaptive |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 97 | 210.35 | 1.138 | 0.465 | 0.616 | 4.48 | 357 | 4 | 1.0 | 0.6 | 0.03 | false |
| 205 | 210.35 | 1.138 | 0.465 | 0.616 | 4.48 | 357 | 4 | 1.0 | 0.6 | 0.03 | true |
| 104 | 151.23 | 1.113 | 0.397 | 0.394 | 3.76 | 319 | 6 | 2.0 | 0.6 | 0.03 | false |
| 212 | 151.23 | 1.113 | 0.397 | 0.394 | 3.76 | 319 | 6 | 2.0 | 0.6 | 0.03 | true |
| 98 | 80.40 | 1.033 | 0.127 | 0.133 | 6.04 | 508 | 6 | 1.0 | 0.6 | 0.03 | false |
| 206 | 80.40 | 1.033 | 0.127 | 0.133 | 6.04 | 508 | 6 | 1.0 | 0.6 | 0.03 | true |
| 56 | 70.47 | 1.108 | 0.234 | 0.404 | 2.93 | 99 | 6 | 2.0 | 0.3 | 0.02 | false |
| 44 | 70.47 | 1.108 | 0.234 | 0.404 | 2.93 | 99 | 6 | 2.0 | 0.0 | 0.02 | false |
| 164 | 70.47 | 1.108 | 0.234 | 0.404 | 2.93 | 99 | 6 | 2.0 | 0.3 | 0.02 | true |
| 152 | 70.47 | 1.108 | 0.234 | 0.404 | 2.93 | 99 | 6 | 2.0 | 0.0 | 0.02 | true |

หมายเหตุดิบ (observation ไม่ใช่ verdict): DdAdaptive true/false ให้ผลเหมือนกันทุกคู่ (eqDD ทั้ง sweep ไม่เคยแตะ
tier1 10% ตอนเปิด basket) และหลายคู่ PartialFrac1 0 vs 0.3 เหมือนกัน (tier1 50% ของ target ไม่ถูก trigger
ที่ setting เหล่านั้น) — มิติที่ขยับผลจริงใน sweep นี้คือ DistAtrMult / SlAtrMult / BaseLot / PartialFrac1=0.6

---

## ORDER-070 — Gold_Kangaroo: แกะ logic + หาข้อมูลเน็ต → spec "KangarooInspired" เข้าแม่พิมพ์ Boss V2 — `DONE(Claude-agent, 2026-07-10)` (role: agent)

### RESULT (Claude-agent 2026-07-10) — facts only, no verdict

**ผลลัพธ์:** `_triage\KANGAROO_LOGIC_NOTES.md` ครบ 4 หัวข้อ + spec card draft rev00 (L4 — รอ user accept ก่อน implement)
**Findings ที่แก้สมมุติฐานเดิม:** (1) fxDreema-built (builder signature ใน binary + Journal block line) — ตระกูลเดียวกับ
"Silver Kangaroo EA" ($199, 2021, param list ตรง 100%) แจกซ้ำ/crack หลายเว็บ → ไม่ exclusive (2) "cap 10 ไม้/ฝั่ง"
**หักล้าง** — นับจาก Journal เจอ concurrent 14/ฝั่ง ทั้ง buy และ sell (3) "basket TP 160 pips" = unweighted pip-sum
→ ปิดทั้งฝั่งขาดทุนเงินจริงสุทธิได้ (2024-11-06 19:23 net ≈ −$379) = de-facto DD-release (4) equity stop 80%
ไม่เคย trigger ทั้ง 2 run = unverified (5) ยืนยัน "overlap" pair-close ไม้ใหม่สุด+เก่าสุด = กลไกกด DD ตัวจริง
(6) `Multiplier_Martingale` เป็น input → flat-lot test (=1) กับตัว original ทำได้เลย — แนะนำทำก่อนตัดสิน build

### ADDENDUM (Claude-agent 2026-07-10) — flat-lot test (Multiplier_Martingale=1.0, อื่นๆ default, Model 1, 10k, 2023.01.01–2026.07.01) — raw numbers only

| Run | PF | Net $ | maxDD% | Trades | Win% | (เทียบ ×1.5 เดิม: PF / DD%) |
|---|---|---|---|---|---|---|
| H1 FLAT (`KANGAROO_XAU_H1_FLAT.htm`) | 5.71 | +15,216.87 | 11.53% | 6,166 | 86.41% | 4.86 / 11.04% |
| M15 FLAT (`KANGAROO_XAU_M15_FLAT.htm`) | 2.17 | +17,714.56 | 19.91% | 15,477 | 82.01% | 2.30 / 22.54% |

Inputs ยืนยันจาก Journal inputs line (Multiplier_Martingale=1) · set = `_mt4_auto\KANGAROO_flat.set` · Model 1 (Control points) = smoke-grade เท่าเดิม

**ทำไม:** user directive 2026-07-10 — smoke 3.5ปี XAU H1 PF 4.86/DD 11% (6,242 ไม้) โครงสร้างดี:
bidirectional hedged grid · martingale ×1.5 **มี cap** (1.0 lot, 10 ไม้/ฝั่ง) · SL จริง $90 ทุกไม้ ·
equity stop 80% · ผ่านเช็คลิสต์ capped-martingale ของแล็บเกือบครบ → คุ้มแกะเป็นของเรา (VISION:
EA ใหม่ทุกตัวออกจากแม่พิมพ์ Boss V2)

**คำสั่ง:** (1) web research ชื่อ "Gold Kangaroo EA" + variants — vendor/myfxbook/forum/param docs
บันทึก URL+ข้อค้นพบ (2) ดึง input list เต็มจาก tester (F7 dialog หรือ .set save) + Journal behaviors
ตาม skill locked-ea-analyzer (3) confirm กลไกที่เหลือ: spacing 200/350 pips fix หรือ dynamic? ·
TP 80/160 นับจากอะไร (breakeven?) · ×1.5 ladder เริ่ม reset เมื่อไหร่ · equity stop ทำงานยังไง
(4) ร่าง spec card (strategy-and-risk format) ของ "KangarooInspired" เป็น entry+basket module บน
Boss V2 chassis: เก็บโครง capped-ladder+SL, เปลี่ยน fix-pips → ATR-mult (มาตรฐานแม่พิมพ์) ·
เขียนผลทั้งหมดเป็นไฟล์ `KANGAROO_LOGIC_NOTES.md` ใน _triage\

**Acceptance:** ไฟล์ notes ครบ 4 หัวข้อ + spec card draft · commit `[tag] ORDER-070 done`
**ห้าม:** เขียน .mq5 จริง (รอ user คุย logic + Claude ตัดสิน spec ก่อน) · ห้าม decompile .ex4


---

## REVIEW ORDER-068 + ORDER-069 — `REVIEWED(Claude, 2026-07-10)`

**068 verdict:** ตัวเลข agent ตรง report ✅ · config แล็บ GBP = identical กับ 939721 ของ user (ต่างแค่ magic)
→ **ST03 family = no-edge entry, STRUCTURAL** (flat-lot 0.68/0.40 ล้างพอร์ตทั้งคู่ · no SL/no cap/ratchet
defect) → ห้าม promote สู่เงินจริงทุกกรณี · demo (9397/9398/990010) เก็บ data ถึง judge ได้ · บัญชีจริง
159475669 แนะนำถอดทั้งตระกูล · บันทึกแล้วที่ PROJECT_STATE §2 + Decision log + DEMO_DEPLOYMENT_PLAN

**069 verdict:** sweep ครอบ 5 levers ครบตามสั่ง (216 pass) · gate 0/216, PF ceiling 1.14, ครึ่งหนึ่งขาดทุน →
**ZeusInspired × EURUSD = dead cell (PARAMETRIC-swept — ตายหลัง sweep จริง ไม่ใช่ตายก่อน optimize)** ·
AUDUSD/AUDJPY ยังเป็น candidate เดิม · lesson ยืนยัน: Zeus MT4 locked ที่ "รอด" EURUSD H1 = ไม่ใช่ edge
ที่ transfer ได้ — พอสร้างเวอร์ชันมีเบรก (SL จริง) edge หายเกลี้ยง = กำไรตัว locked มาจาก no-SL recovery
อย่างเดียว เหมือน ST03 เป๊ะ · หมายเหตุ observation ของ agent (DdAdaptive inert, PartialFrac ต่ำไม่ trigger)
= ข้อมูลออกแบบ ไม่ใช่ปัญหา sweep


---

## REVIEW ORDER-070 (+flat-lot addendum) — `REVIEWED(Claude, 2026-07-10)`

**Verdict:** flat-lot H1 **PF 5.71 (สูงกว่ามี martingale 4.86) ที่ DD เท่าเดิม** = **entry/basket logic มี edge
ของตัวเองจริง — martingale ไม่ใช่แหล่งกำไร (ตรงข้าม ST03 family เป๊ะ)** → **GREEN-LIGHT build
"KangarooInspired" บน Boss V2** ตาม spec rev00 ใน `_triage\KANGAROO_LOGIC_NOTES.md` §4 (รอ user เคาะ) ·
design notes จาก review: (1) ตัด martingale ทิ้งได้เลย — flat lot ดีกว่า (2) เก็บ "overlap pair-close"
(กลไกกด DD ตัวจริง) + pip-sum DD-release แต่แปลงเป็น dollar-based (3) equity stop ต้องเป็นของเราเอง
เพราะของเดิม unverified (4) fix 200/350 pips → ATR-mult ตามมาตรฐานแม่พิมพ์ · caveat คงเดิม: ทุกเลข
= Model 1 smoke-grade บน symbol เดียว — build เสร็จต้องเข้า funnel เต็ม (M1→M0 confirm · year-split ·
spread stress · MC) ก่อนคิดเรื่อง deploy · หมายเหตุ: ตัว original = Silver Kangaroo family (crack เกลื่อน)
— ตัวที่ user รันจริงบน 141049900 ให้เช็คที่มา ถ้า crack = ถอดตามนโยบาย security (KangarooInspired
ของเราคือทางแทนอยู่แล้ว)


---

## ORDER-071 — ST03 entry rescue: HTF trend-gate A/B บน flat-lot — `OPEN` (role: Claude+Sonnet build → agent runs)

**ทำไม (user directive 2026-07-10):** user เสนอเอา higher-TF มาคุมทิศ entry ของ ST03 (filter ด้วย MACD /
trend / ADX+DI) — สมมุติฐานถูกหลัก: ST03 คือ reversion-grid การบังคับให้ grid กางเฉพาะฝั่งเทรนด์ใหญ่
อาจเปลี่ยน no-edge เป็น edge ได้ · **baseline ที่ต้องชนะ: flat-lot GBP PF 0.68 / CAD 0.40 (ORDER-068)**

**เกณฑ์ตัดสินล่วงหน้า (ตั้งก่อนเห็นผล — กัน selection):** gate ตัวใดตัวหนึ่งต้องยก flat-lot PF ข้าม **1.0**
บนทั้ง GBP และ CAD (สองตลาดพร้อมกัน) จึงนับว่า "entry รอด" → ค่อยต่อ capped-recovery (โครง Kangaroo)
· ถ้าไม่มี gate ไหนข้าม = entry ตายจริง เลิกที่ signal นี้ ห้ามขุดต่อ

**วิธี (in-EA A/B เท่านั้น — ห้าม offline bucketing):** บทเรียนจ่ายจริง ORDER-067: close-time regime
conditioning = survivorship artifact (offline ADX gate สวย → in-EA จริง MC แย่ลง 0.973→0.861) ·
และ STF: AND-filter ที่ lagging สับ sample 159→27 จนไร้ความหมาย — ระวังทั้งคู่
1. build บน **Boss V2 + Entry_ST03.mqh** (ห้ามแตะไฟล์ fxDreema): เพิ่ม input gate mode =
   0 none · 1 H4 MACD direction · 2 H4 ADX>th + DI-direction · 3 H4 EMA50-slope — gate คุมทิศที่
   "อนุญาตให้เปิดตะกร้า" เท่านั้น (ไม่ปิดไม้ที่เปิดแล้ว)
2. compile 0/0 + `tpl_regression.ps1` CLEAN ก่อนรัน (แก้ core = ต้องผ่าน cage)
3. รัน flat-lot (no escalation) GBPUSD + USDCAD H1 · 2023.01.01-2026.07.01 · Model 1 · gate 0/1/2/3
   = 8 runs · report ST03GATE_*
**Acceptance:** ตาราง 8 แถว PF/net/DD/trades + แถว baseline 068 เทียบ · commit `[tag] ORDER-071 done`
**ห้าม:** ตัดสิน rescue สำเร็จ/ล้มเหลว (เกณฑ์ตายตัวด้านบน — Claude อ่านผลเอง) · ห้ามแตะ .set live ·
ห้าม optimize param อื่นไปพร้อมกัน (isolate ตัวแปรเดียว: gate)


---

## ORDER-071 rev02 — ST03 entry rescue แบบขั้นบันได (supersede rev01 ด้านบน — user เพิ่มแกน exit 2026-07-10) — `STAGE2-DONE(Claude-agent, 2026-07-10)` — Stage 3 = รอ main session ตัดสินตามเกณฑ์ล่วงหน้า (build: Claude+Sonnet · runs: agent)

**ทำไม rev02:** user ชี้ถูก — flat-lot 0.68 (ORDER-068) วัดด้วย exit เดิมของ EA (ปิด 5-20 pips เหนือ
breakeven = scalp) ซึ่งขัดธรรมชาติ MACD "win rate ต่ำ/รันเทรนได้" → verdict "entry ไม่มี edge" ยัง
สรุปไม่ได้จนกว่าจะ sweep แกน exit (VERDICT GATE ข้อ 1: <3 levers = INVALID) · แกนที่ user สั่งครบ:
ATR spacing · spacing ถ่างตามไม้ · TP กว้างขึ้น · TP+trailing · Donchian-break exit · HTF gate (rev01)

**Stage 1 — naked signal × trend exits (ตัดสินก่อนว่าสัญญาณมี edge ไหม):** ไม่มี grid ไม่มีทบ —
1 ไม้ต่อ 1 สัญญาณ MACD-count(2) บน Boss V2 chassis (Entry_ST03) + ATR SL · exit 3 แบบ:
(a) fixed RR (TP = 2×ATR / 3×ATR) (b) ATR trailing (c) opposite Donchian-20 break
× GBPUSD + USDCAD H1 · 2023.01-2026.07 · Model 1 · flat 0.1 · ~8 runs
**เกณฑ์ตั้งล่วงหน้า:** exit ตัวใดตัวหนึ่ง PF ≥1.0 ทั้ง 2 symbol → signal มีชีวิต ไป Stage 2 ·
ทุกตัว <0.85 (naked floor) ทั้งคู่ → entry ตายจริง ปิดเคส ห้ามขุดต่อ · ระหว่าง 0.85-1.0 = ไป Stage 2 แบบ WATCH

**Stage 2 (เฉพาะถ้า Stage 1 รอด) — โครงสร้างรอบสัญญาณ:** แกน HTF gate (rev01: H4 MACD/ADX+DI/EMA-slope)
× spacing (fixed 20p / 1.5×ATR / progressive ถ่างตามลำดับไม้ 1×,1.5×,2×ATR ตามที่ user เสนอ)
บน exit ผู้ชนะจาก Stage 1 · ยัง flat-lot

**Stage 3 (เฉพาะถ้า Stage 2 ผ่าน):** ต่อ capped-recovery โครง KangarooInspired (cap lot · cap ไม้ ·
SL จริง · dollar-based release) แล้วเข้า funnel เต็มตามปกติ

**Build ก่อนรัน (Claude/Sonnet, session หน้า):** exit modes + gate inputs + spacing modes บน Boss V2
(one-exit-owner ตามกติกา chassis) · compile 0/0 · `tpl_regression.ps1` CLEAN · ห้ามแตะไฟล์ fxDreema เดิม
**ห้าม:** ข้าม stage · optimize หลายแกนพร้อมกันใน stage เดียว · ตัดสินผลก่อนครบทั้ง 2 symbol

### RESULT Stage 1 (Claude-agent 2026-07-10) — raw numbers only, NO verdict (judge = main session)

**เกณฑ์ pre-registered (quoted verbatim จาก order ด้านบน):**
> **เกณฑ์ตั้งล่วงหน้า:** exit ตัวใดตัวหนึ่ง PF ≥1.0 ทั้ง 2 symbol → signal มีชีวิต ไป Stage 2 ·
> ทุกตัว <0.85 (naked floor) ทั้งคู่ → entry ตายจริง ปิดเคส ห้ามขุดต่อ · ระหว่าง 0.85-1.0 = ไป Stage 2 แบบ WATCH

Build: `ea_projects\(EXP)_ST03_Naked\(EXP)_ST03_Naked_rev00.mq5` (compile 0 err / 0 warn, MetaEditor headless) —
EXPERIMENT EA แยกสัญญาณ Entry_ST03 เพียว: 1 ไม้/สัญญาณ flat 0.10 · ไม่มี grid/ทบ · ATR(14) SL 2.0×ATR ทุกไม้ ·
bar-open gate · Entry_Evaluate() ทุก bar แม้ถือไม้อยู่ (LabCore parity — counter/latch เดินเหมือน Boss_15) ·
magic 999071. ไฟล์ build: `(EXP)_ST03_Naked_rev00.mq5` + `entries\Entry_ST03.mqh` (**VERBATIM copy** ของ
`ea_template\core\entries\Entry_ST03.mqh` + header provenance เท่านั้น — เหตุผล: include ข้าม directory ลาก
core Inputs.mqh มาชนชื่อ enum `ExitMode`) + `entries\IEntry.mqh` (verbatim copy) + `Indicators.mqh`
(shim ขั้นต่ำ: enum/inputs/_15_*/Indi_MACD ค่า verbatim จาก core) + `set_files\ST03NKD_*.set` (4 ชุด) ·
**ไม่แตะ ea_template\ เลย** → regression cage ไม่ต้องรัน
Runs: GBPUSD + USDCAD H1 · 2023.01.01–2026.07.01 · Model 1 · deposit 10000 · leverage 1:2000 · flat 0.10 ·
ExitMode 1=fixed TP (TpAtrMult×ATR) / 2=ATR-trail 2.0×ATR / 3=opposite Donchian(20,H1)-break ·
reports `_mt5_auto\reports\ST03NKD_*.htm` (gitignored) · ini `_mt5_auto\ini\ST03NKD_*.ini`

| symbol | exit | PF | net | maxDD% (bal) | eqDD% | trades | win% |
|---|---|---|---|---|---|---|---|
| GBPUSD | 1 fixed TP 2.0×ATR | 0.88 | −2,376.44 | 28.02 | 28.16 | 1049 | 46.8 |
| GBPUSD | 1 fixed TP 3.0×ATR | 0.84 | −3,268.85 | 33.43 | 33.85 | 891 | 36.0 |
| GBPUSD | 2 ATR trail 2.0×ATR | 0.89 | −1,711.49 | 21.22 | 21.80 | 1300 | 34.8 |
| GBPUSD | 3 Donchian(20,H1) break | 0.84 | −2,172.59 | 25.88 | 26.67 | 606 | 23.9 |
| USDCAD | 1 fixed TP 2.0×ATR | 0.83 | −1,901.89 | 24.89 | 25.12 | 1027 | 46.1 |
| USDCAD | 1 fixed TP 3.0×ATR | 0.80 | −2,279.02 | 26.70 | 26.82 | 864 | 35.2 |
| USDCAD | 2 ATR trail 2.0×ATR | 0.77 | −2,117.77 | 24.39 | 24.57 | 1283 | 35.0 |
| USDCAD | 3 Donchian(20,H1) break | 0.80 | −1,512.98 | 16.68 | 17.67 | 575 | 24.4 |
| *baseline ORDER-068* GBPUSD | EA-เดิม scalp-exit, esc OFF | 0.68 | −10,054.49 | 100.24 | 100.31 | 561 | n/a |
| *baseline ORDER-068* USDCAD | EA-เดิม scalp-exit, esc OFF | 0.40 | −9,941.62 | 99.59 | 99.69 | 350 | n/a |

### RESULT Stage 2 (Claude-agent 2026-07-10) — raw numbers only, NO verdict (judge = main session)

**Scope ruling (lead, ตามเกณฑ์ band ที่ pre-registered ใน Stage 1):** USDCAD = dead — ทุก exit <0.85
(naked floor) → ปิดฝั่ง CAD ตามเกณฑ์ "ทุกตัว <0.85 ... → entry ตายจริง ปิดเคส" · GBPUSD = WATCH band
(trail 0.89 อยู่ใน 0.85-1.0) → Stage 2 รันเฉพาะ GBPUSD บน exit ผู้ชนะ Stage 1 (ExitMode 2 = ATR trail 2.0×ATR)
**เกณฑ์ pre-registered ของ lead สำหรับ Stage 2 (ตั้งก่อนเห็นผล):** gate ต้องถึง **PF ≥ 1.05 พร้อม
trades ≥ 300** จึงเก็บเคสไว้ต่อ

Build เพิ่ม (rev00 เดิม, additive): `input GateMode` 0=none · 1=H4 MACD(12,26,9) direction ·
2=H4 ADX(14)>20 + DI direction · 3=H4 EMA50 slope (EMA[1] vs EMA[5]) — gate บล็อกเฉพาะ NEW entry
ไม่ปิดไม้ที่เปิดอยู่ · อ่าน closed H4 bar (shift 1) bar-open convention เดิม · fail-closed ถ้า H4 data
ไม่พร้อม · compile 0/0 · sets `set_files\ST03NKD_G1/G2/G3.set` · ไม่แตะ ea_template\ เช่นเดิม
Runs: GBPUSD H1 · 2023.01.01–2026.07.01 · Model 1 · deposit 10000 · leverage 1:2000 · flat 0.10 ·
ExitMode=2 ทุกตัว · reports `_mt5_auto\reports\ST03NKD_GBP_G*.htm` (gitignored) · ini `_mt5_auto\ini\ST03NKD_GBP_G*.ini`

| gate (บน ExitMode 2 trail) | PF | net | maxDD% (bal) | eqDD% | trades | win% |
|---|---|---|---|---|---|---|
| 0 none (Stage-1 baseline) | 0.89 | −1,711.49 | 21.22 | 21.80 | 1300 | 34.8 |
| 1 H4 MACD direction | 0.99 | −57.70 | 5.45 | 5.69 | 623 | 37.1 |
| 2 H4 ADX(14)>20 + DI | 0.82 | −956.28 | 10.88 | 11.49 | 443 | 33.2 |
| 3 H4 EMA50 slope | 0.94 | −479.19 | 10.04 | 10.38 | 706 | 37.0 |


---

## ORDER-072 — build "(Boss)_Kangaroo" = Boss_16 บนแม่พิมพ์ V2 — `CLAIMED(Claude-agent, 2026-07-10)` (role: agent build ภายใต้ spec ที่ Claude เคาะ)

**Spec decisions (Claude lead เคาะ 2026-07-10 — ปิดประเด็นเปิดทั้ง 5 ของ KANGAROO_LOGIC_NOTES §4):**
1. **Lot law: FLAT default** (ทุกไม้ = base_lot) — flat-lot probe พิสูจน์แล้วว่าดีกว่ามี ladder
   (H1 5.71 vs 4.86) · ×1.5 capped ladder ใส่เป็น input `LadderMult` default 1.0 (=ปิด) ไว้ A/B
2. **Bidirectional = 2 instance ผ่าน Direction input** (ตาม pattern Boss_14) — ไม่ทำ dual-engine
   ในตัวเดียว, magic แยกฝั่ง · ไม่ทำ multi-magic stream ของ original (artifact ไม่ใช่ feature)
3. **Entry v0 = RSI fade** (RSI(14) H1: BUY เมื่อ <th_low, SELL เมื่อ >th_high, default 30/70) —
   ใกล้เคียง counter-trend ของ original ที่สุดในคลังเรา (RSI-MR = survivor mechanism ที่ validate แล้ว)
4. **เก็บ 3 กลไก exit ตาม original แต่คิดเงินจริง:** TP เดี่ยว (ATR-mult) · basket close แบบ net-$ ·
   **overlap pair-close** (คู่ใหม่สุด+เก่าสุด ปิดเมื่อรวม ≥ $X, default 5, sweepable) — โมดูลใหม่
5. **ladder_flatten (controlled-loss release):** มีเป็น input default OFF — A/B แยกใน funnel
6. Spacing ATR (0.8/1.4 mult + floor 150p) · SL ต่อไม้ ATR-mult (ceiling $90-equiv) · HARD cap
   10 ไม้/ฝั่ง (ของจริง ไม่ใช่โฆษณาแบบ original) · emergency DD 70%

**คำสั่ง:** สร้าง `ea_template\Boss_16_KangarooGrid.mq5` + โมดูลใหม่ที่จำเป็นใน `core\` (additive,
default-off สำหรับ EA เดิม) ตาม pattern Boss_14_GridLog · compile 0/0 · **`tpl_regression.ps1` ต้อง CLEAN**
(กติกาแก้ core) · smoke XAUUSD H1 2023-2026 Model 1 บน lane "D:\Meta 5b" (กันชนกับ ORDER-071) ·
เทียบตาราง: Boss_16 flat vs original flat (PF 5.71/DD 11.5% = เป้าไล่)
**Acceptance:** compile 0/0 · regression CLEAN · ตาราง smoke เทียบ original + set ไฟล์ · commit `[tag] ORDER-072 done`
**ห้าม:** deploy/verdict · แก้ Boss_14/15 behavior · martingale default-on · แตะ .set live

### ORDER-072 result — `DONE(Claude-agent, 2026-07-10)` — build ครบ + gates ผ่านทั้ง 3 + smoke raw numbers (NO verdict)

**Build file list:**
- NEW `ea_template\Boss_16_KangarooGrid.mq5` (wrapper: `LAB_ENTRY_16` + tag)
- NEW `ea_template\core\Kangaroo.mqh` — basket engine ของ entry 16 ทั้งก้อน: adverse-only ATR grid
  (0.8/1.4 mult + floor 150p digit-aware) · FLAT lot (LadderMult>1.0 = capped ladder, first-4 = BaseLot,
  cap/order 1.0) · HARD cap 10 ไม้/ฝั่ง (refuse จริง) · per-order broker SL (18×ATR, ceiling 9000p) ·
  exit 4 กลไก **คิดเงินจริงทั้งหมด**: (1) single TP 0.35×ATR (managed close) (2) basket net-$ ≥ 16×(lots/0.01)
  (3) overlap pair-close newest+oldest ≥ $5 เมื่อ ≥4 ไม้ (4) ladder_flatten default OFF (≥6 ไม้, net ≥ -$400) ·
  emergency DD close-all 70% · **one exit owner:** LabCore short-circuit เข้า `Kangaroo_OnTick()` — ExitManager/
  Stack/Recovery/Hedge ไม่รันเลยสำหรับ build นี้; ไม่มี broker TP ต่อไม้ (precedent mode 93); cage ยังเป็นใหญ่
  (RiskControl hard-kill/deposit-load/RC_MaxLot รันก่อน/คุมทับ)
- NEW `ea_template\core\entries\Entry_KangarooRSI.mqh` — entry v0: RSI(14) fade บน chart TF, closed-bar read,
  `_16_Direction` 1=BUY(<RsiLow 30)/2=SELL(>RsiHigh 70) ตาม pattern Boss_14, เข้าที่ bar open
- EDIT (additive, `#ifdef LAB_ENTRY_16` ทั้งหมด — compile out จาก Boss_11..15): `core\Inputs.mqh` (กลุ่ม `_16_*`
  + StackMode/fallback guard) · `core\Indicators.mqh` (handle `g_hRSI16`) · `core\LabCore.mqh`
  (include + init + OnTick short-circuit) · `core\Execution.mqh` (`Exec_CloseTicket()` — build อื่นไม่เรียก)
- EDIT `ea_template\deploy.ps1` (+Boss_16 target) · `scripts\mt5_run.ps1` (+`-Leverage` param, default 100 = พฤติกรรมเดิม)
- NEW `ea_template\sets\Boss16_Kangaroo_XAU_smoke.set` (defaults ทั้งชุด เขียน explicit)

**Gate evidence:**
1. compile: `Boss_16_KangarooGrid.mq5 → Result: 0 errors, 0 warnings` (และทั้ง 7 targets 0/0)
2. `tpl_regression.ps1` = **CLEAN 4/4** — หมายเหตุ: เจอ DRIFT 4/4 ก่อน แต่ control run บน clean HEAD (stash)
   reproduce เลขเพี้ยน **bit-identical** (trades เท่าเดิมเป๊ะ 168/164/107/56, profit ±1-4%) = data-side
   XAU history refresh ตาม incident เดิม commit 6a21f040 → re-baseline บน verified clean HEAD แล้วรันกับ
   module = CLEAN (ทำตาม procedure ที่บันทึกไว้เป๊ะ) · `tests\run_tests.ps1` = **ALL TESTS PASS 3/3**
   (AcctGate/Persist/StackStep)
3. smoke lane "D:\Meta 5b" (portable): XAUUSD H1 2023.01.01–2026.07.01 Model 1 (history quality 98%),
   deposit 10000, leverage 1:2000, defaults flat-lot

**Smoke table (raw — ห้าม verdict ที่นี่):**
| Run | PF | Net $ | maxDD% (eq) | Trades | Win% |
|---|---|---|---|---|---|
| Boss_16 BUY (defaults) | 1.49 | +2,242.42 | 10.85% | 588 | 76.4% |
| Boss_16 SELL (_16_Direction=2) | 0.46 | −2,261.00 | 25.12% ← cage HARD KILL @25% วันสุดท้าย 2026.06.30 | 293 | 54.3% |
| Original Gold_Kangaroo FLAT (MT4 H1, สองฝั่งในตัวเดียว) | 5.71 | +15,216.87 | 11.53% | 6,166 | 86.4% |

Reports: `_mt5_auto\reports\BOSS16_KANG_XAU_H1_BUY.htm` / `BOSS16_KANG_XAU_H1_SELL.htm` · mechanics ยืนยันใน
journal lane2: overlap pair-close ยิงจริง 168 ครั้ง (SELL run), grid adds เดินตาม spacing, cage kill ทำงาน

**Deviations from spec (พร้อมเหตุผล):**
1. smoke = 2 runs (BUY+SELL อย่างละ 1 ครั้ง ไม่มี tuning) — EA เป็น fixed-direction ต่อ instance ตาม spec
   decision 2 แต่แถวเทียบ original เป็นสองฝั่ง → รันฝั่งละครั้งเพื่อให้ตารางเทียบได้
2. single TP = managed close ไม่ใช่ broker TP — กติกา one-exit-owner (ไม้ห้ามมี broker TP, precedent 93);
   fill = tick แรกที่เลย level ซึ่งเทียบเท่า overshoot behavior ที่เห็นใน original
3. grid-add reference = ราคา extreme ของฝั่ง (ต่ำสุด BUY / สูงสุด SELL) ไม่ใช่ไม้ล่าสุดตามเวลา — กัน
   oscillation refill หลัง overlap pair-close ตัดไม้ newest ออก; ตรง observation ว่า original เติมไม้ที่
   new low เท่านั้นช่วง crash 2024-11-06
4. emergency 70% อยู่ในโค้ดตาม spec แต่ cage KillDD (ProtectLevel 2 = 25%) ยิงก่อนเสมอที่ default —
   70% = backstop สำหรับ config ที่คลาย cage (SELL run คือหลักฐาน cage ทำงานจริงและ halt)
5. `mt5_run.ps1` เพิ่ม `-Leverage` (additive, default 100 ไม่เปลี่ยนพฤติกรรมเดิม) เพราะ order สั่ง 1:2000
   แต่ script hardcode 100
6. `regression_baseline.csv` ถูก re-capture บน clean HEAD (ดู gate 2) — ไม่ใช่การกลบ drift ของ module;
   พิสูจน์ด้วย control run ก่อนแล้ว

**ข้อสังเกต (ข้อมูล ไม่ใช่ verdict):** trades 588+293 vs original 6,166 — entry v0 RSI fade คัดเข้มกว่า entry
เข้ารหัสของ original มาก (ตัว original ยิงหลาย magic stream แทบตลอดเวลา) · ฝั่ง SELL แพ้บน XAU 2023-26
ซึ่งเป็นเทรนด์ขึ้นยักษ์ · การอ่านผล/ทางไปต่อ (entry sweep? both-instance portfolio?) = งาน Claude lead


---

## REVIEW ORDER-071 (Stage 1+2) — `REVIEWED(Claude, 2026-07-10)` — **เคส entry ST03 ปิดถาวร**

**ตัดสินตามเกณฑ์ pre-registered ทุกชั้น ไม่มีข้อยกเว้น:**
- Stage 1: USDCAD ตาย (ทุก exit <0.85) · GBPUSD โซน WATCH (trail 0.89) → ไปขั้น 2 GBP-only ✓ ตามกติกา
- Stage 2: gate ดีสุด = H4 MACD direction **PF 0.99 / net −58 / DD 5.5% / 623 ไม้** — ต่ำกว่าบาร์
  (≥1.05 & ≥300 ไม้) → **ไม่ผ่าน · ปิดเคส**
- แกนที่ sweep ครบก่อนปิด (VERDICT GATE): escalation on/off · exit ×4 (scalp เดิม/TP 2-3×ATR/trail/
  Donchian) · symbol ×2 · HTF gate ×3 — 18 configurations, ไม่มีตัวใด PF ≥1.0 ยกเว้น 0.99 หนึ่งจุด
- **insight ที่ได้จริง (เครดิต user):** HTF MACD gate ช่วยแรง (0.89→0.99, DD 21%→5.5%) — ทิศคิดถูก
  แต่สัญญาณฐานไม่มี expectancy บวกให้กู้ · pattern นี้ = "gate ดีบนสัญญาณตาย ≠ ระบบมีชีวิต"
  (สอดคล้อง lesson ORDER-067) · แนวคิด H4-MACD-direction gate เก็บเป็นอะไหล่ให้สัญญาณอื่นได้
- **มรดกที่ปิดพร้อมกัน:** ST03 family ทั้งหมด = no-edge สมบูรณ์ทุกแกนแล้ว (068+071) — คำแนะนำถอด
  จากบัญชีจริงคงเดิม · demo 990010 เก็บ data ถึง judge แล้วปลด · Boss_15/Entry_ST03 = เก็บเป็น
  reference module ไม่มี deploy path · ทางเดินต่อของ "แก้ไม้แบบมีเบรก" = Boss_16 (ORDER-072)


---

## ORDER-073 — News-aware risk system (user directive 2026-07-10) — Phase 1 `DONE(Claude)` · Phase 2 `OPEN`

**เป้า user:** เห็นข่าวแรงที่เกี่ยวกับพอร์ตทุกวัน + มีตัวคุมเหนือ EA ทั้งหมด (ลด lot / ปิดไม้ / block entry
ช่วงข่าวแรง ตาม policy ต่อ strategy)

**Phase 1 (เสร็จ 2026-07-10):** `scripts\news_calendar.ps1` — ดึง ForexFactory weekly feed → filter
High-impact 8 สกุลพอร์ต → (a) `portfolio\news_today.html` ฝังใน LIVE_DASHBOARD (มือถือเห็นทุกเช้า
ผ่าน gist) (b) `portfolio\news_week.csv` = machine-readable ให้ Phase 2 · cache กัน 429 · อยู่ใน
daily 07:30 chain แล้ว · **ข้อจำกัดที่ต้องรู้: กันได้เฉพาะข่าวตามนัด — Brexit/SNB-type (gap ไม่มีนัด)
กันด้วยปฏิทินไม่ได้ = เหตุผลที่ SL/cap ต้องมีเสมอ**

**Phase 2 — NewsGuard watchdog EA (OPEN, ต้องคุย design กับ user ก่อน build):**
- EA ตัวเดียว attach 1 chart/บัญชี อ่าน `news_week.csv` (คัดลอกไป Common\Files หรือ WebRequest ดึงเอง
  บน VPS — ต้อง whitelist URL ครั้งเดียว) · นาฬิกา event เทียบ server time
- policy ต่อ magic list (input): `BLOCK_NEW` (กันไม้ใหม่ N นาทีก่อน/หลัง event — ทำได้กับ EA เราเท่านั้น
  ผ่าน GlobalVariable flag ที่ chassis อ่าน) · `CLOSE_ALL` (ปิดไม้ magic นั้นก่อน event — ทำได้กับทุก EA
  รวม locked เพราะ watchdog มีสิทธิ์ระดับบัญชี) · `NONE`
- ค่าเริ่มแนะนำ: CLOSE_ALL เฉพาะ strategy ไร้ SL/recovery (Zeus 7777, gold grids) ก่อนข่าว USD แรง
  30 นาที · BLOCK_NEW สำหรับ breakout family (ข่าวคือ noise ไม่ใช่ signal ของมัน) · Boss_14 bench
  demo = NONE (เก็บ data ให้ judge เห็นพฤติกรรมจริง)
- **ห้าม build จนกว่า user เคาะ policy ต่อบัญชี/ต่อ magic** (มันจะไปปิดไม้เงินจริง — ต้อง explicit)

## ORDER-074 — fxDreema X-ray: อ่าน EA คลังเรียนของ user แบบไม่เปลือง token — `DONE(Claude-agent, 2026-07-10)`

**ผลลัพธ์:** corpus ใหญ่กว่าที่คิดมาก — **3,513 ไฟล์ / 1,050 unique EA (dedup by content-hash) / 1.22 GB**
(mq4 583 · mq5 467; แหล่งหลัก `D:\Forex` 546 + `D:\EA_LAB\_intake_drop` ~500 + OneDrive `.Final EA`).
`scripts\fxdreema_xray.py` (portable python) → `_triage\FXDREEMA_XRAY.md` (การ์ด/EA, 2.7MB) +
`_triage\FXDREEMA_XRAY.csv`. Parser อ่านโครง fxDreema จริง: block labels (`// Block N (label)`),
per-block overrides (StopLossMode/VolumeSize — template default มี cast, override ไม่มี),
`v::var = formula()` mapping → lot law อ่านได้เป็นสมการ, `MDLIC_indicators_iX` = indicator ที่ wired จริง.
**Spot-check ST03 ผ่านครบ:** iMACD ✓ · StopLossMode="none" ทั้ง 4 open blocks → NO_SL ✓ ·
`v::LOTB = openLots.min + openLots.max` (min+max pattern) + LOT_Repeat → LOT_ESCALATION ✓ ·
inputs Lots_divided/TP1/TP2/TP3/LOT_Repeat/Nearby_PIP ครบ ✓.
**ภาพรวม flag (raw data ไม่ใช่ verdict):** NO_SL+LOT_ESCALATION+NO_CAP = 448 ตัว (combo ใหญ่สุด) ·
has_sl=yes เพียง 76 · SL+no-escalation (โครงดี หายาก) = 41 · TIMELOCK 7 · DLL_IMPORT 4 · WEBREQUEST 15.

**ทำไม:** user มีไฟล์ fxDreema export จากคอร์สจำนวนมาก อยากต่อยอด แต่ code generate บวมมาก
(ST03 = 11k บรรทัด) อ่านตรง ๆ เปลือง token/quota มหาศาล · fxDreema เป็น template → โครงซ้ำ →
parser เดียวถอดสาระได้ทุกไฟล์

**คำสั่ง:** (1) หาไฟล์: กวาด D:\ + OneDrive Desktop Metatrader หา .mq4/.mq5 ที่มี signature fxDreema
(2) เขียน `scripts\fxdreema_xray.py` (portable python `tools\python312`): ต่อไฟล์ → สกัด **การ์ดสรุป
~40 บรรทัด**: ชื่อ/แพลตฟอร์ม · input ทั้งหมด+default · indicator ที่เรียก (iRSI/iMACD/iATR/...) ·
โครง entry (block ไหนเรียก trade) · lot law (หา pattern multiply/divide/balance) · SL/TP มี-ไม่มี ·
**danger flags**: no-SL / lot-multiplication / no-cap / DLL / WebRequest (3) รันทั้งคลัง → การ์ดรวมไฟล์กลาง
`_triage\FXDREEMA_XRAY.md` + CSV summary (ชื่อ, #inputs, indicators, hasSL, hasMartingale, flags)
**Acceptance:** X-ray ครบทุกไฟล์ที่เจอ · spot-check 2 ไฟล์ที่รู้คำตอบแล้ว (ST03: no-SL+escalation ✓,
Count-MACD entry ✓) ต้องตรงกับที่แกะมือไว้ · commit `[tag] ORDER-074 done`
**ห้าม:** verdict ต่อ EA (การ์ด = ข้อมูลดิบ) · แก้ไฟล์ต้นฉบับ user


---

## REVIEW ORDER-072 — `REVIEWED(Claude, 2026-07-10)` + เปิด ORDER-075

**Verdict สถาปัตยกรรม: ผ่าน** — chassis engine ทำงานจริงครบ (overlap pair-close ยิง 168 ครั้ง ·
grid spacing ATR ถูก · cage HARD KILL ตัด SELL ที่ 25% = ระบบเบรกที่ต้นฉบับไม่มี ทำงานให้เห็นแล้ว) ·
compile 0/0 · regression CLEAN (DRIFT แรก = history refresh ยืนยันด้วย clean-HEAD control ไม่ใช่ code) ·
**Verdict ตัวเลข v0: BUY PF 1.49/DD 10.9%/588t = มีชีวิตชัดเจน · SELL 0.46 = ตายใส่ gold mega-uptrend
(คาดได้ — fade ขาขึ้นยักษ์) · ยังห่างต้นฉบับ 5.71 เพราะ entry v0 ยิงน้อยกว่า 7 เท่า + คนละ model/lane**
· อ่านเชิงกลยุทธ์: ทิศทางเดียวกับ BRK-XAU family = gold มี BUY bias เชิงโครงสร้าง — BUY-only อาจเป็น
ตัว deploy จริงเหมือน XAGUSD BuyOnly precedent

## ORDER-075 — Boss_16 entry sweep v1 (BUY-first) — `DONE(Claude-agent, 2026-07-10)` (role: agent, MT5 lane ว่างตอนกลางคืน)

**คำสั่ง:** sweep entry lever บน Boss_16 BUY instance เท่านั้น (SELL พักไว้จน entry ชนะบน BUY):
RSI period {7,14,21} × RsiLow {25,30,35,40} × TF {H1,M30} = 24 pass optimize (complete mode,
`mt5_optimize.ps1`, XAUUSD 2023.01.01-2026.07.01 Model 1, lane ไหนว่างก็ได้) · แกนอื่นล็อคตาม
default ORDER-072 ทั้งหมด
**Acceptance:** XML ครบ + ตาราง pass ที่ PF≥1.5 & Trades≥400 & eqDD≤12% + top-10 ดิบ · commit
`[tag] ORDER-075 done` · **ห้าม:** แตะแกน grid/exit (isolate entry) · เลือก winner (งาน Claude) ·
ห้ามรันชนกับ order อื่นบน lane เดียวกัน

### ORDER-075 result — `DONE(Claude-agent, 2026-07-10)` — 24/24 pass ครบ · **gate = 0 passers ทั้งสอง TF** (raw data, NO verdict)

**Setup ที่รันจริง:** `mt5_optimize.ps1` complete mode (Optimization=1, Criterion=0) · XAUUSD
2023.01.01–2026.07.01 Model 1 · deposit 10000 · **leverage 1:2000** · BUY instance
(_16_Direction=1) · แกน grid/exit/lot ล็อคตาม ORDER-072 default ทุกตัว · H1 รัน lane หลัก
(D:\Meta 5) + M30 รัน lane2 (D:\Meta 5b /portable) พร้อมกัน — ทั้งคู่ว่างตอนรัน
- NEW `ea_template\sets\Boss16_Kangaroo_XAU_optRSI.set` = smoke set + optimize ranges เฉพาะ
  `_16_RsiPeriod=14||7||7||21||Y` × `_16_RsiLow=30||25||5||40||Y` (12 combo/TF)
- EDIT `scripts\mt5_optimize.ps1` (+`-Leverage` param additive, default 100 = พฤติกรรมเดิม —
  ตาม pattern เดียวกับที่ ORDER-072 เพิ่มใน mt5_run.ps1; order อนุญาตไว้แล้ว)
- XML: `_mt5_auto\optimizations\ZKANG_OPT_XAU_H1.xml` + `ZKANG_OPT_XAU_M30.xml` (13 แถว =
  header+12 pass ครบทั้งคู่)
- **Sanity ผ่าน:** H1 pass RSI 14/30 reproduce baseline ORDER-072 **เป๊ะทุกหลัก** (PF 1.4917 /
  eqDD 10.85% / 588 trades / net +2,242.42) = ยืนยัน leverage/model/lane ต่อถูก

**Gate (PF≥1.5 & Trades≥400 & eqDD≤12%): H1 = 0/12 · M30 = 0/12.** ตัวที่ PF ถึง 1.5 มี 2 ตัว
แต่ตกที่ Trades: H1 21/30 (285 ไม้) · M30 21/25 (196 ไม้) — จดเป็นข้อมูล ไม่ใช่ข้อแก้ตัว

**H1 ทั้ง 12 pass (เรียง PF; ครบทุก param column):**
| Pass | RsiPeriod | RsiLow | PF | Net $ | ExpPayoff | RecovF | Sharpe | eqDD% | Trades |
|---|---|---|---|---|---|---|---|---|---|
| 5 | 21 | 30 | 1.570 | +1,174.45 | 4.12 | 1.60 | 1.89 | 7.08 | 285 |
| 4 | 14 | 30 | 1.492 | +2,242.42 | 3.81 | 1.82 | 1.51 | 10.85 | 588 |
| 1 | 14 | 25 | 1.243 | +632.22 | 2.03 | 0.52 | 0.92 | 11.40 | 311 |
| 0 | 7 | 25 | 1.224 | +1,838.84 | 1.98 | 1.31 | 0.89 | 12.43 | 931 |
| 7 | 14 | 35 | 1.195 | +1,773.83 | 1.87 | 1.15 | 0.85 | 11.98 | 949 |
| 3 | 7 | 30 | 1.170 | +2,061.21 | 1.61 | 1.14 | 0.75 | 15.15 | 1,283 |
| 9 | 7 | 40 | 1.093 | +1,792.21 | 0.95 | 0.82 | 0.46 | 16.10 | 1,888 |
| 8 | 21 | 35 | 1.092 | +581.44 | 0.96 | 0.38 | 0.39 | 13.11 | 605 |
| 11 | 21 | 40 | 1.092 | +996.16 | 0.98 | 0.58 | 0.43 | 13.78 | 1,017 |
| 6 | 7 | 35 | 1.080 | +1,300.16 | 0.82 | 0.52 | 0.41 | 18.63 | 1,578 |
| 10 | 14 | 40 | 1.067 | +964.90 | 0.71 | 0.53 | 0.35 | 15.50 | 1,364 |
| 2 | 21 | 25 | 1.039 | +36.63 | 0.43 | 0.05 | 0.24 | 7.55 | 86 |

**M30 ทั้ง 12 pass (เรียง PF; ครบทุก param column):**
| Pass | RsiPeriod | RsiLow | PF | Net $ | ExpPayoff | RecovF | Sharpe | eqDD% | Trades |
|---|---|---|---|---|---|---|---|---|---|
| 2 | 21 | 25 | 1.517 | +721.37 | 3.68 | 1.24 | 2.59 | 5.64 | 196 |
| 3 | 7 | 30 | 1.339 | +5,701.16 | 2.57 | 3.03 | 1.50 | 10.95 | 2,222 |
| 7 | 14 | 35 | 1.256 | +3,683.50 | 2.11 | 1.68 | 1.30 | 14.17 | 1,743 |
| 9 | 7 | 40 | 1.251 | +6,809.66 | 2.07 | 3.24 | 1.35 | 16.14 | 3,283 |
| 5 | 21 | 30 | 1.249 | +1,389.20 | 2.17 | 0.96 | 1.11 | 12.00 | 639 |
| 1 | 14 | 25 | 1.233 | +1,245.30 | 1.92 | 0.98 | 1.03 | 10.67 | 650 |
| 6 | 7 | 35 | 1.232 | +5,244.26 | 1.91 | 2.59 | 1.18 | 11.99 | 2,746 |
| 0 | 7 | 25 | 1.212 | +3,052.81 | 1.73 | 1.02 | 1.08 | 18.95 | 1,768 |
| 11 | 21 | 40 | 1.198 | +3,272.29 | 1.76 | 1.46 | 1.11 | 14.82 | 1,863 |
| 10 | 14 | 40 | 1.184 | +3,875.16 | 1.67 | 1.49 | 0.99 | 16.28 | 2,326 |
| 8 | 21 | 35 | 1.155 | +1,564.56 | 1.40 | 0.96 | 0.75 | 12.90 | 1,116 |
| 4 | 14 | 30 | 1.113 | +1,192.32 | 1.05 | 0.63 | 0.60 | 15.00 | 1,137 |

**ข้อสังเกต (ข้อมูลดิบ ไม่ใช่ verdict — plateau/ทางไปต่อ = งาน Claude lead):**
- H1: PF เรียงตาม "เลือกเข้มขึ้น" ชัด (RsiLow ต่ำ + period ยาว → PF ขึ้น แต่ Trades ร่วง) —
  trade-off เดียวตลอดแกน; ไม่มีจุดที่ได้ทั้ง PF≥1.5 และ ≥400 ไม้พร้อมกัน
- M30 กลับด้านจาก H1 หลายจุด: 14/30 (แชมป์ H1 โซน) ตกไปท้ายตารางบน M30 (PF 1.113/DD 15%) ·
  net $ โตกว่า H1 มากที่ combo ยิงถี่ (7/40 = +6.8k แต่ DD 16%) — RSI+ATR คนละ TF = คนละบริบท
- eqDD ของหลาย combo ทะลุ 12–19% = โซนที่ cage ProtectLevel 2 (KillDD 25%) ยังไม่ตัด
  แต่เกิน gate order นี้


---

## REVIEW ORDER-074 — `REVIEWED(Claude, 2026-07-10)` + เปิด ORDER-076

**Verdict เครื่องมือ: ผ่าน** — spot-check ST03 ตรงทุกจุดที่แกะมือไว้ (MACD ✓ no-SL ✓ min+max escalation ✓
inputs ✓) · การ์ดอ้าง block number = ตรวจกลับได้ · corpus 1,050 unique / 1.22GB อ่านจบใน 1 order
**ภาพรวมคลังคอร์ส user (ข้อมูล ไม่ใช่คำด่า):** 43% = NO_SL+ESCALATION+NO_CAP (โครง uncapped-ruin
แบบเดียวกับ ST03/Zeus ที่เพิ่งปิดไป) · มี SL จริงแค่ 7% · **หัวกะทิธรรมชาติ = 41 ตัว (has_sl=yes +
lot_escalation=no)** · ธงแดงพิเศษ: DragonFX 3.0 (NO_SL+ESCAL+WEBREQUEST+TIMELOCK ครบสแต็ค) ·
`Hedging Rebalance [XauM1...]` ใน .Final EA ของ user มี TIMELOCK · DLL ×4 + WebRequest ×15 =
ห้าม attach ก่อนตรวจ

## ORDER-076 — smoke-screen หัวกะทิ 41 ตัวจาก X-ray — `OPEN` (role: agent/qwen lane)

**คำสั่ง:** (1) cross-ref 41 ตัว (CSV filter has_sl=yes & lot_escalation=no) กับ EA_SCORECARD +
ผล ORDER-036 (MT4 1,318 sweep) — ตัวที่เคย screen แล้วห้ามรันซ้ำ ใช้ผลเดิม (2) ตัวใหม่จริง:
smoke ตาม filter chain มาตรฐาน (name-DQ → smoke PF>1 → BWD-OOS 2020-22 → spread-stress)
platform ตามไฟล์ · **compiled .ex4/.ex5 เท่านั้นถ้ามี — .mq4/.mq5 คอมไพล์ก่อน** (3) ตาราง verdict-ดิบ
ต่อ EA ต่อด่าน **Acceptance:** ตารางครบ 41 แถว (screened-before / smoked / DQ) + top-5 ตาม
BWD-OOS PF · commit `[tag] ORDER-076 done` **ห้าม:** verdict PASS/REJECT (Claude ตัดสิน) ·
แตะไฟล์ต้นฉบับ · แตะ 297 ตัว SL-unknown (รอ verification pass แยก ถ้าคุ้ม)


---

## REVIEW ORDER-075 — `REVIEWED(Claude, 2026-07-10)` + เปิด ORDER-077

**Verdict:** gate ทางการ 0/24 · **surface = peaky ไม่ใช่ plateau** — H1 แกน period แกว่งแรง
(7→21 ที่ RsiLow30: 1.17→1.49→1.57) และ 21/25 เป็นหลุม (86 ไม้) · M30 กลับลำดับ H1 (14/30 จากแชมป์
กลายเป็นบ๊วย 1.11) = สัญญาณ fragility ข้าม TF ชัด · เพดาน RSI-fade v0 ≈ PF 1.5-1.6 ที่ DD 7-11%
— **ห่างต้นฉบับ (5.71) มาก แต่ระดับนี้ถ้ารอด funnel ก็มีค่า** (เทียบมาตรฐาน judge PF≥1.40)
**ตัดสินทางเดิน:** (1) ห้าม fine-grid RsiLow ต่อ (= ล่า peak) (2) ก่อนลงแรง entry v1 ใหม่ ให้ตอบคำถาม
ถูกสุดก่อน: concept รอดคนละ regime ไหม → ORDER-077 (3) candidate ชั่วคราวถ้า 077 ผ่าน = โซน
14/30 + 21/30 (ทดสอบคู่ ห้ามเลือกตัวเดียวจาก in-sample)

## ORDER-077 — Boss_16 BUY: BWD-OOS 2020-2022 probe (กฎ both-regimes ก่อนทุ่มต่อ) — `DONE(agent, 2026-07-10)` (role: agent)

**คำสั่ง:** รัน Boss_16 BUY 2 config (RSI 14/30 และ 21/30, อื่นๆ default ORDER-072) บน XAUUSD H1
window **2020.01.01-2022.12.31** (ปีเทรนด์ลง+ขึ้น+COVID = regime ตรงข้าม in-sample 2023-26)
Model 1 · 10k · 1:2000 · report ZKANG_BWD_*
**Acceptance:** ตาราง 2 แถว PF/net/eqDD/trades เทียบแถว in-sample · commit `[tag] ORDER-077 done`
**ห้าม:** tune อะไรทั้งนั้น · verdict (Claude อ่าน — เกณฑ์ล่วงหน้า: BWD PF <0.9 ทั้งคู่ = entry v0 เป็น
regime artifact → หยุดสาย RSI-fade แล้วออกแบบ entry v1 ใหม่ก่อนค่อยกลับมา)

**ผลรัน (agent, 2026-07-10):** lane D:\Meta 5b (portable) · XAUUSD H1 history ครบถึง 2020 จริง
(.hcc 2015-2026 · report: 17,761 bars / 4.24M ticks / history quality 99% ทั้งสองรัน — ไม่ใช่ 0-bar)

| Config | Window | PF | Net | eqDD% | Trades | Win% | Report |
|---|---|---|---|---|---|---|---|
| 14/30 | BWD 2020-2022 | **1.04** | +197.21 | 17.33 | 512 | 69.9 | ZKANG_BWD_14_30.htm |
| 21/30 | BWD 2020-2022 | **1.31** | +596.42 | 9.58 | 276 | 72.8 | ZKANG_BWD_21_30.htm |
| 14/30 (ref) | IS 2023-2026 | 1.49 | +2242.42 | 10.85 | 588 | 76.4 | BOSS16_KANG_XAU_H1_BUY.htm |
| 21/30 (ref) | IS 2023-2026 | 1.57 | — | — | 285 | — | (ORDER-075) |

หมายเหตุกลไก: config 2 = smoke set เดิมเปลี่ยนบรรทัดเดียว `_16_RsiPeriod=21` · ini Leverage=2000
(report แสดง 1:100 เหมือนรัน in-sample เดิม — convention เดียวกัน; margin level ต่ำสุด >4200%
ทั้งสองรัน = leverage ไม่เป็นข้อจำกัด) · ไม่มี tune · ไม่มี verdict — Claude อ่านตามเกณฑ์ล่วงหน้า


---

## REVIEW ORDER-077 — `REVIEWED(Claude, 2026-07-10)` — **Boss_16 21/30 = CANDIDATE (ผ่าน both-regimes)** + เปิด ORDER-078

**Verdict:** เกณฑ์ kill (ทั้งคู่ <0.9) ไม่โดน — RSI-fade v0 **ไม่ใช่ regime artifact** ·
**21/30: IS 1.57/DD 7.1 + BWD 2020-22 1.31/DD 9.6 = บวกทั้งสองโลก** cadence ใกล้กัน (~90 ไม้/ปี)
— ข้อกังวล peaky จาก 075 ถูกหักล้างบางส่วน (peak ฟลุคปกติพัง BWD แต่ตัวนี้ไม่พัง) · 14/30 อ่อนกว่า
ข้าม regime (1.04, DD 17.3) = sibling เก็บไว้เทียบ ไม่ใช่ตัวนำ · หมายเหตุ: report โชว์ leverage 1:100
ตาม convention ini เดิม แต่ margin ไม่เคย binding (>4200%) = ไม่กระทบเลข
**สถานะ VERDICT GATE ของ 21/30:** levers — entry ✓(075) escalation ✓(flat by design) spacing/TP ✗ยัง ·
surface — entry peaky แต่ BWD ยัน · both regimes ✓(077) · holdout+MC ✗ยัง → ยังห้ามพูดคำว่า deploy

## ORDER-078 — Boss_16 BUY 21/30: validation funnel เต็ม — `OPEN` (role: agent, งานถัดไปอันดับ 1)

**คำสั่ง (ทีละขั้น หยุดเมื่อตกด่าน):**
1. **Lever sanity sweep** (กัน knife-edge ไม่ใช่ล่า peak): spacing (AtrMultFirst4 0.6/0.8/1.0 ×
   AtrMultAfter 1.2/1.4/1.6) × BasketTpUsdPer01 (12/16/20) บน 21/30 H1 IS window — ต้องเห็น
   neighbor ไม่มีตัวขาดทุน (plateau requirement) ไม่ต้องหาตัวดีกว่า
2. Year-split 2020/21/22/23/24/25/26 ของ config กลาง — นับปีลบ
3. Model 0 (every tick) confirm 1 รัน IS window — เลข Model 1 ต้องไม่ละลาย (บทเรียน M2-optimism)
4. MC bootstrap (robustness-validator convention) — PF 5th percentile + ruin
**Acceptance:** ตารางครบ 4 ขั้น · commit `[tag] ORDER-078 done` · **ห้าม:** เปลี่ยน entry/lot ·
เลือก config ใหม่จาก sweep ขั้น 1 (มันคือ sanity check ไม่ใช่ optimization) · verdict (Claude)


---

## ORDER-079 — Idea mining คลังคอร์ส: concept catalog (reframe จาก user 2026-07-10) — `CLAIMED(Claude-agent, 2026-07-10)`

**ทำไม (user directive):** คลัง 1,050 EA = สื่อการเรียน ไม่ใช่สินค้า — ห้ามตัดสินด้วยเกณฑ์ risk structure
(43% no-SL คือ scaffold ของแบบฝึก ไม่ใช่ความผิด) · เป้า = **สกัดไอเดีย/แนวคิด** ที่ user เรียนมา
ให้เห็นเป็นแคตตาล็อกต่อยอดได้ · user ยืนยันในคลังมี Elliott Wave (รวมแบบเฉพาะ wave 5) + SMC —
ห้ามปัดตก แนวพวกนี้แล็บมี precedent ด้วย (Gold SMC = OOS_VALIDATED ใน EA_Project)

**คำสั่ง:** สร้าง concept-mining pass ต่อยอด xray (แหล่งข้อมูลต่อไฟล์: ชื่อไฟล์/โฟลเดอร์ · **fxDreema
block labels** (คนเขียนเอง สื่อความหมายตรง) · indicator signature · comment strings) →
จัด taxonomy แนวคิด เช่น: Elliott/wave-count · SMC/order-block/liquidity/BOS · session-time ·
breakout (แบบไหน) · reversion (RSI/CCI/Stoch/BB) · trend-follow (MA/ST/SAR) · currency-strength
meter · correlation/pair · news · scalping · grid/basket variants · dashboard/tool (ไม่ใช่ EA) ·
money-management exercises → output `_triage\FXDREEMA_IDEA_CATALOG.md`:
ต่อ concept: จำนวนไฟล์ · ตัวแทน 2-3 ไฟล์ (ตัวที่ block labels สื่อสุด) · mechanism sketch จาก labels ·
**cross-ref สถานะแล็บ**: เคยทดสอบ/ตาย/validated/ยังไม่เคยแตะ (เทียบ EDGE_CATALOG.md + memory
signal-landscape ผ่านไฟล์ repo) + CSV คอลัมน์ concept เพิ่มใน FXDREEMA_XRAY.csv
**เจาะพิเศษ:** ไฟล์ Elliott/wave ทั้งหมด (grep wave/elliot/impulse/zigzag ใน name+labels) และ
SMC (order block/liquidity/FVG/BOS/CHOCH/SMC) — ลิสต์แยกครบทุกไฟล์ พร้อมสรุป logic จาก labels ต่อไฟล์
**Acceptance:** catalog ครบ + ลิสต์ Elliott/SMC เต็ม + นับ concept ใหม่ที่แล็บไม่เคยทดสอบ ·
commit `[tag] ORDER-079 done` · **ห้าม:** ตัดสินดี/ไม่ดี ต่อ concept (Claude+user คุยกัน) · risk flags
ห้ามโผล่ใน catalog (คนละเอกสารกับ XRAY)

**สถานะ:** CLAIMED -> DONE(Claude-inline, 2026-07-10) — agent ตายที่ session limit, Claude เขียน/รันสคริปต์เองต่อ (fxdreema_concepts.py + boilerplate fix รอบสอง: doji-string เคย inflate candle_pattern 224->16) · ผลเต็ม = _triage\FXDREEMA_IDEA_CATALOG.md + concept column ใน XRAY.csv + _concept_summary.json
