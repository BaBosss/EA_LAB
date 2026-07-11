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

## ORDER-078 — Boss_16 BUY 21/30: validation funnel เต็ม — `DONE(Claude-agent, 2026-07-11)` (role: agent, งานถัดไปอันดับ 1)

**Pre-registered bars (Claude lead เขียนก่อนเห็นข้อมูล, 2026-07-11 เช้า — กัน goalpost ขยับ):**
- ขั้น 1 ตก = มี neighbor cell ใดใน 27 ที่ net < 0 (plateau requirement ตาม spec)
- ขั้น 2 ตก = ปีลบ >2 จาก 7 ปี (2020-2026)
- ขั้น 3 ตก = Model 0 PF < 1.25 (คือ M1 1.57 ละลายเกิน ~20%) หรือ net ≤ 0
- ขั้น 4 อ่านตาม robustness-validator convention: PF 5th pct <1.0 หรือ ruin >1% = แดง
- ตกด่านไหน = agent หยุดที่ด่านนั้น รายงานดิบ — คำตัดสินทั้งหมดเป็นของ Claude lead

**คำสั่ง (ทีละขั้น หยุดเมื่อตกด่าน):**
1. **Lever sanity sweep** (กัน knife-edge ไม่ใช่ล่า peak): spacing (AtrMultFirst4 0.6/0.8/1.0 ×
   AtrMultAfter 1.2/1.4/1.6) × BasketTpUsdPer01 (12/16/20) บน 21/30 H1 IS window — ต้องเห็น
   neighbor ไม่มีตัวขาดทุน (plateau requirement) ไม่ต้องหาตัวดีกว่า
2. Year-split 2020/21/22/23/24/25/26 ของ config กลาง — นับปีลบ
3. Model 0 (every tick) confirm 1 รัน IS window — เลข Model 1 ต้องไม่ละลาย (บทเรียน M2-optimism)
4. MC bootstrap (robustness-validator convention) — PF 5th percentile + ruin
**Acceptance:** ตารางครบ 4 ขั้น · commit `[tag] ORDER-078 done` · **ห้าม:** เปลี่ยน entry/lot ·
เลือก config ใหม่จาก sweep ขั้น 1 (มันคือ sanity check ไม่ใช่ optimization) · verdict (Claude)

### ORDER-078 result — `DONE(Claude-agent, 2026-07-11)` — ครบ 4 ขั้น ไม่ตกด่านไหน (raw data, NO verdict)

**Setup ที่รันจริง:** `mt5_run.ps1`/`mt5_optimize.ps1` · Expert `EALabTpl\Boss_16_KangarooGrid` ·
XAUUSD H1 · deposit 10000 · leverage 1:2000 · BUY instance (`_16_Direction=1`) · center config =
21/30 (`_16_RsiPeriod=21`, `_16_RsiLow=30.0`, ทุกแกนอื่นตาม `Boss16_Kangaroo_XAU_smoke.set`,
`_16_LadderMult=1.0`) · NEW set files: `ea_template\sets\Boss16_Kangaroo_XAU_21_30.set` (fixed
center, ใช้กับ mt5_run.ps1 ทุกรันเดี่ยว) + `ea_template\sets\Boss16_Kangaroo_XAU_val078.set`
(center + 3 optimize-range สำหรับ Step 1) · Steps 0/3/4 + IS-window ของ 2 รันปี รันบน lane หลัก
(`D:\Meta 5`) · ปี BWD 2020-2022 รันบน lane 2 portable (`D:\Meta 5b`, ตามที่ ORDER-077 ยืนยัน
history ครบ) · lane MT4 ไม่แตะ

**Step 0 — wiring sanity:** รัน 21/30, Model 1, IS 2023.01.01-2026.07.01 → PF 1.57 / net
+1,174.45 / 285 trades / eqDD 7.08% — **ตรงเป๊ะกับ ORDER-075 pass 5** (PF 1.570/+1,174.45/285/7.08%)
ทุกหลัก. Report: `B16VAL_STEP0_REPRO.htm`.

**Step 1 — Lever sanity sweep (27 combo, optimize complete mode, Model 1, IS window, RSI 21/30
คงที่):** ตารางเรียงตาม PF (ครบ 27 แถว):

| AtrMultFirst4 | AtrMultAfter | BasketTpUsdPer01 | PF | Net USD | ExpPayoff | RecovF | Sharpe | eqDD% | Trades |
|---|---|---|---|---|---|---|---|---|---|
| 1.0 | 1.2 | 12 | 1.854 | +1249.61 | 4.84 | 1.59 | 3.70 | 7.65 | 258 |
| 1.0 | 1.4 | 12 | 1.812 | +1191.32 | 4.69 | 1.57 | 3.63 | 7.39 | 254 |
| 0.6 | 1.4 | 20 | 1.807 | +1901.40 | 5.46 | 2.47 | 2.92 | 7.29 | 348 |
| 0.6 | 1.4 | 16 | 1.804 | +1636.51 | 5.23 | 2.13 | 3.23 | 7.36 | 313 |
| 0.6 | 1.2 | 20 | 1.786 | +1886.17 | 5.36 | 2.49 | 2.87 | 7.21 | 352 |
| 0.6 | 1.2 | 16 | 1.768 | +1606.15 | 5.02 | 2.12 | 3.17 | 7.28 | 320 |
| 0.8 | 1.2 | 20 | 1.730 | +1578.78 | 5.00 | 2.12 | 2.77 | 7.07 | 316 |
| 1.0 | 1.6 | 12 | 1.712 | +1091.31 | 4.35 | 1.50 | 3.29 | 7.09 | 251 |
| 1.0 | 1.2 | 16 | 1.709 | +1285.06 | 4.64 | 1.64 | 2.45 | 7.57 | 277 |
| 0.8 | 1.4 | 20 | 1.703 | +1474.61 | 5.03 | 2.01 | 2.25 | 7.04 | 293 |
| 0.8 | 1.6 | 20 | 1.698 | +1486.43 | 5.11 | 2.06 | 2.45 | 6.92 | 291 |
| 0.6 | 1.4 | 12 | 1.659 | +1319.44 | 4.24 | 1.72 | 3.06 | 7.43 | 311 |
| 1.0 | 1.4 | 16 | 1.653 | +1170.89 | 4.50 | 1.54 | 1.98 | 7.36 | 260 |
| 0.6 | 1.6 | 20 | 1.643 | +1618.38 | 4.86 | 2.20 | 2.53 | 7.00 | 333 |
| 0.6 | 1.2 | 12 | 1.634 | +1306.52 | 4.12 | 1.72 | 2.99 | 7.34 | 317 |
| 0.6 | 1.6 | 16 | 1.608 | +1401.21 | 4.35 | 1.90 | 2.47 | 7.03 | 322 |
| 0.8 | 1.2 | 16 | 1.596 | +1269.41 | 4.09 | 1.71 | 2.39 | 7.11 | 310 |
| 1.0 | 1.6 | 16 | 1.574 | +1066.07 | 4.21 | 1.46 | 1.79 | 7.06 | 253 |
| 0.8 | 1.6 | 16 | 1.571 | +1205.54 | 4.20 | 1.67 | 2.13 | 6.95 | 287 |
| 0.8 | 1.4 | 16 (=center) | 1.570 | +1174.45 | 4.12 | 1.60 | 1.89 | 7.08 | 285 |
| 1.0 | 1.2 | 20 | 1.510 | +1106.11 | 3.96 | 1.41 | 1.97 | 7.54 | 279 |
| 0.6 | 1.6 | 12 | 1.477 | +1039.02 | 3.44 | 1.41 | 2.47 | 7.12 | 302 |
| 0.8 | 1.4 | 12 | 1.463 | +918.91 | 3.31 | 1.25 | 2.28 | 7.11 | 278 |
| 1.0 | 1.4 | 20 | 1.453 | +974.23 | 3.72 | 1.28 | 1.56 | 7.34 | 262 |
| 0.8 | 1.6 | 12 | 1.444 | +876.34 | 3.21 | 1.21 | 2.21 | 7.01 | 273 |
| 0.8 | 1.2 | 12 | 1.442 | +891.47 | 3.15 | 1.20 | 2.16 | 7.22 | 283 |
| 1.0 | 1.6 | 20 | 1.371 | +821.12 | 3.23 | 1.13 | 1.31 | 7.05 | 254 |

**0 ของ 27 cell มี net < 0.** Range PF 1.371-1.854 ทั้งหมด. แถว AtrMultFirst4=0.8/AtrMultAfter=1.4/
BasketTp=16 (center cell) ตรงกับ Step 0 ทุกหลัก (PF 1.570/+1174.45/285/7.08%) = ยืนยัน sweep คนละ
ช่องทางแต่เลขตรงกัน. **หมายเหตุ anomaly:** optimizer XML คืนมา 324 passes (ไม่ใช่ 27) — MT5
เก็บ optimize-checkbox state ของ `_16_RsiPeriod`/`_16_RsiLow` ค้างจาก session ORDER-075
(`optRSI.set`) แม้ set ไฟล์ใหม่จะใส่ค่าคงที่ (ไม่มี `||...||Y`) ก็ตาม → ได้ full cartesian
27×12=324 แถวจริง (RsiPeriod {7,14,21} × RsiLow {25,30,35,40} คูณเข้ากับ 27 combo ที่ตั้งใจสวีป)
ตารางด้านบน = filter เฉพาะแถวที่ RsiPeriod=21 & RsiLow=30 (27 แถวตรงตามสเปค) จาก XML ดิบ
`_mt5_auto\optimizations\B16VAL_SWEEP_XAU_H1.xml` — ข้อมูลไม่เสีย แค่เปลืองรอบคำนวณ

**Step 2 — Year-split ของ center config (21/30, 0.8/1.4/16), Model 1, single run ต่อปี:**

| ปี | Window | PF | Net USD | eqDD% | Trades | History Quality | Lane |
|---|---|---|---|---|---|---|---|
| 2020 | 2020.01.01-2021.01.01 | 1.27 | +152.00 | 6.14 | 74 | 100% | Meta 5b (portable) |
| 2021 | 2021.01.01-2022.01.01 | **0.78** | **-256.56** | 9.73 | 97 | 99% | Meta 5b (portable) |
| 2022 | 2022.01.01-2023.01.01 | 4.81 | +700.98 | 2.27 | 105 | 99% | Meta 5b (portable) |
| 2023 | 2023.01.01-2024.01.01 | 1.19 | +139.94 | 7.08 | 96 | 99% | Meta 5 (main) |
| 2024 | 2024.01.01-2025.01.01 | 1.83 | +275.69 | 5.92 | 70 | 100% | Meta 5 (main) |
| 2025 | 2025.01.01-2026.01.01 | 1.86 | +166.60 | 2.61 | 34 | 100% | Meta 5 (main) |
| 2026H1 | 2026.01.01-2026.07.01 | 1.75 | +592.22 | 4.17 | 85 | 100% | Meta 5 (main) |

**1 ของ 7 ปีติดลบ (2021, PF 0.78, net -256.56).** Reports: `B16VAL_YR2020.htm` ... `B16VAL_YR2026H1.htm`.

**Step 3 — Model 0 (every tick) confirm, center config, IS 2023.01.01-2026.07.01:**

| Model | PF | Net USD | eqDD% | Trades | History Quality |
|---|---|---|---|---|---|
| Model 0 (every tick) | 1.41 | +947.55 | 7.15 | 318 | 98% |
| Model 1 (reference, Step 0) | 1.57 | +1,174.45 | 7.08 | 285 | — |

Report: `B16VAL_M0_CONFIRM.htm` (20,654 bars).

**Step 4 — Monte Carlo bootstrap** (`mt5_montecarlo.py --deposit 10000 --iters 5000`, input =
trade list จากรัน Step 3 Model 0 — 318 trades, seed default 42):

| metric | 5th pct | median | 95th pct | worst |
|---|---|---|---|---|
| Net profit | 947.55 | 947.55 | 947.55 | 947.55 |
| Max drawdown % | 1.95 | 2.90 | 4.60 | 7.30 |
| Profit factor | 1.41 | 1.41 | 1.41 | 1.41 |

ruin risk (net ≤ -deposit): 0.00% · P(net profit < 0): 0.0%. หมายเหตุกลไก: script รีชัฟเฟิล
"ลำดับ" trade ไม่ใช่ resample-with-replacement — net/PF เป็นค่าคงที่ทุก percentile เพราะผลรวมไม่
ขึ้นกับลำดับ (invariant ตามกลไกของสูตร), มีแค่ max-DD ที่กระจายตามลำดับสุ่ม (ตามที่ script
docstring ระบุไว้ว่าเป็น optimistic lower-bound เพราะ trade ไม่ independent จริง)

**ไม่ตกด่านไหนใน 4 ขั้น** (0/27 net<0 · 1/7 ปีลบ · Model0 PF 1.41≥1.25 net>0 · MC PF 5th pct
1.41≥1.0 ruin 0%). ไม่มี anomaly อื่นนอกจาก optimizer-cache 324-pass ที่ระบุไว้ข้างบน.

## REVIEW ORDER-078 — `REVIEWED(Claude, 2026-07-11)` — **Boss_16 BUY 21/30 = PASS-TO-BENCH (demo) — ยังไม่ใช่ PASS เงินจริง**

**VERDICT GATE (ครบก่อนตัดสิน):**
1. **Levers swept:** entry-threshold ✓(075: RsiPeriod 7-21 × RsiLow 25-40) · TF ✓(075: H1+M30) ·
   spacing ✓(078: First4 0.6-1.0 × After 1.2-1.6) · TP/basket ✓(078: 12/16/20) · lot-law = FLAT
   **held by design** (072 flat-lot probe ชนะ ladder — decision ไม่ใช่ unswept) · SL-width held
   (18×ATR) · exit-mode held (Kangaroo engine = exit owner เดียว) · symbol held XAU
   (mechanism-matched: spike-fade บ้าน XAU) — swept 4 แกน เกินขั้นต่ำ
2. **Surface:** 27-cell plateau แท้ — 0 ตัวขาดทุน, PF 1.371-1.854, eqDD สม่ำเสมอ ~7%, center
   อันดับ 20/27 ตาม PF = ไม่ได้นั่งบน peak · entry axis peaky (075) แต่ BWD ยันแล้ว (077)
3. **Both regimes:** ✓ BWD aggregate PF 1.31 (077) + year-split 6/7 ปีบวก · ปีลบเดียว 2021
   (PF 0.78, -256.56, eqDD 9.73 — ขาดทุนมีเพดาน ไม่ blowup)
4. n/a (ไม่ใช่ REJECT)
5. n/a (FLAT lot + hard cap 10 ไม้ + per-order SL — ไม่ใช่ martingale)
6. **Holdout+MC สำหรับ PASS:** ⚠️ BWD 2020-22 ถูกใช้เลือก 21/30 เหนือ 14/30 ใน 077 (mild 2-way
   selection) → **ยังไม่มี holdout สะอาด** · MC = permutation (DD-only): ruin 0%, DD95 4.6%,
   **แกน PF ไม่ได้ถูกทดสอบ** (invariant by construction — บาร์ "PF 5th pct" ที่ pre-register ไว้
   กลายเป็น vacuous, บันทึกตรง ๆ ไม่นับเป็นหลักฐาน) · plateau-center ✓

**คำตัดสิน: PASS-TO-BENCH** — เสนอ deploy บน **demo bench** (experiment ถัดไปตามแบบ ORDER-086)
ด้วย locked set `ea_template\sets\Boss16_Kangaroo_XAU_21_30.set` · **demo forward = holdout
สะอาดตัวจริง** · ห้ามพูด real-money จนกว่าผ่าน judge ตาม hard-prerequisite gate #6 (scorecard)
**เงื่อนไขก่อน attach (user เป็นคน attach):** (1) corr check vs พอร์ต live (corr_monthly.py,
≤0.40 = additive) โดยเฉพาะกลุ่ม XAU (BRK Bars55/8) — corr สูง = ลด lot ไม่ใช่ตัด (user rule)
(2) magic ใหม่ไม่ชน map ใน DEMO_DEPLOYMENT_PLAN (3) จด bias: BUY-only = long ทองข้างเดียว
**Pre-registered judge criteria (เขียนก่อน attach):** คาดหวังจาก M0: PF ~1.4, ~90 ไม้/ปี (~22
ไม้/3 เดือน) · kill = eqDD >12% เมื่อไหร่ก็ได้ (cage KillDD 25% เป็นชั้นสอง) · judge 3 เดือน:
PF <0.8 ที่ ≥15 ไม้ = ถอด · งานคู่ขนานที่อนุญาต: SELL side / symbol สอง = order แยกภายหลัง
**ของแถมจาก sweep (จดไว้ ห้าม act):** โซน 0.6/1.4/16-20 ดีกว่า center ทั้งแถบ — สลับตอนนี้ =
select หลังเห็นข้อมูล · เก็บเป็น hypothesis รอบ re-opt 6 เดือนตามกฎ window

### เงื่อนไข (1) corr check — `DONE(Claude, 2026-07-11)` (ตอน ORDER-085B รันก่อนหน้า ข้ามไปเพราะ
ORDER-078 ยังไม่ปิด/ไม่มี monthly data — เพิ่งปิดช่องว่างนี้)

Monthly P&L Pearson (`B16VAL_STEP0_REPRO.htm` IS 2023-2026 vs `BRK_FULLSPAN.htm`, สคริปต์เดียวกับ
`_mt5_auto\corr_monthly.py` แต่ปรับ path): **25 เดือนร่วม**

| Baseline | corr (monthly P&L) | DD-overlap (เดือนลบตรงกัน/เดือนลบรวม) | Verdict |
|---|---|---|---|
| BRK_FULLSPAN (Bars40 buy-only H1) | **0.077** | 3/14 = 0.21 | **LOW — additive** (ต่ำกว่า SuperTrend 0.42-0.73 มาก) |

**สรุป: corr ผ่านเกณฑ์สบาย ๆ ไม่ต้อง reduce-lot ตามสูตร** (ต่างจาก SuperTrend ที่ติด WATCH/HIGH) ·
เงื่อนไข (2) magic ใหม่ + (3) BUY-only bias ยังเป็นของ user ตอน attach จริง · **Boss_16 21/30 พร้อม
เข้าคิว demo-attach เต็มขั้นแล้ว** (funnel 078 + corr นี้ = ครบทุกเงื่อนไขก่อน attach ที่ REVIEW ระบุไว้)

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


---

## ORDER-080 — วัดมูลค่า "limit-entry แทน market" บน EA เรา (แรงบันดาลใจ: บอท maker-only ของโพสต์ FB ที่ user เอามาแกะ 2026-07-10) — `OPEN` (role: agent build+run)

**สมมุติฐาน:** เข้าไม้ด้วย pending limit ที่ราคาดีกว่า signal price เล็กน้อย (แลกกับ fill ไม่ครบ)
ให้ EV ดีกว่า market entry — โลก crypto พิสูจน์ด้วย fee; โลก MT5 = ประหยัด spread/slippage แทน
**คำสั่ง:** เพิ่ม input `EntryMode` (0=market เดิม default · 1=limit offset) + `EntryLimitOffsetPips` +
`EntryExpiryBars` ให้ **Boss_16_KangarooGrid** (additive, default = พฤติกรรมเดิม, ผ่าน regression cage)
→ A/B บน config candidate 21/30 XAU H1: market vs limit offset {3, 6, 10 pips} expiry 1 bar ·
ทั้ง IS 2023-26 และ BWD 2020-22 · Model 1 (+Model 0 confirm คู่ที่ต่างกันสุด)
**Acceptance:** ตาราง market vs 3 offset × 2 window: PF/net/trades/**fill-rate** (นับไม้หาย) ·
commit `[tag] ORDER-080 done` · **ห้าม:** เปลี่ยน lever อื่น · verdict (Claude อ่าน — สนใจ EV ต่อไม้
หลังหัก opportunity cost ของไม้ที่ไม่ fill ไม่ใช่แค่ PF)

## ORDER-081 — Crypto lane feasibility study (maker-fee scalper blueprint) — `DONE(Codex+research-subagent, 2026-07-11 — รอ Claude/user ตัดสิน go/no-go)` (role: research agent, web)

> **Dispatch note:** user อนุมัติให้ Codex เดินคิวต่อระหว่าง Claude quota หมด · งานนี้ทำคู่ขนานกับ 083C เพราะเป็น read-only web/docs ไม่ใช้ tester laneและไม่ชน ORDER-094 · Codex ตรวจ primary-source fee claim ซ้ำแล้ว; ไม่มีการตัดสิน direction แทน Claude

**เป้า:** ตอบ go/no-go การเปิด lane crypto แบบแล็บ (ไม่ใช่ลอกบอทเขา — เอา blueprint engineering-first)
**คำสั่ง (research + เอกสาร ไม่มี code):**
1. Fee reality: Bybit/Binance perpetual maker/taker ปัจจุบัน + เงื่อนไข rebate/VIP + ต่างจากตัวเลขในโพสต์ไหม
2. Data: kline/tick historical ดึงยังไง ฟรีแค่ไหน พอทำ backtest แบบแล็บ (flat-lot probe / BWD-OOS) ได้ไหม
3. Backtest stack: แนวทาง python บนเครื่องนี้ (portable python มีแล้ว) + fee model + maker-fill model
   (จุดยากสุด: จำลอง "ได้เป็น maker จริงไหม" — หาแนว literature/แนวปฏิบัติ)
4. Infra จริงถ้า go: websocket uptime ต้องเท่าไหร่ รันบนเครื่องแล็บ/VPS เดิมได้ไหม · API key security
5. ความเสี่ยงเฉพาะ crypto: funding rate, เหรียญ delist, weekend ไม่ปิด, leverage/liq engine
**Acceptance:** `_triage\CRYPTO_LANE_FEASIBILITY.md` ครบ 5 หัวข้อ + ประเมิน effort (ชม.งาน) +
คำถามเปิดสำหรับ user · commit `[tag] ORDER-081 done` · **ห้าม:** เขียน trading code · เปิดบัญชี/แตะ API จริง

### ORDER-081 RESULT — Codex + research sub-agent, 2026-07-11 (raw research, no verdict)

รายงาน `_triage\CRYPTO_LANE_FEASIBILITY.md` ครบ fee reality / data / maker-fill backtest / live infra /
crypto-specific risk พร้อม primary official sources + research papers, decision matrix, คำถาม user และ effort
**92–168 ชั่วโมง** · ยืนยันซ้ำจาก Bybit official: VIP0 perpetual maker **0.020%**, taker **0.055%**
(maker-maker round trip = 4 bps ก่อน funding/adverse selection) · ไม่พบหลักฐาน retail maker rebate ถาวร;
Binance rebate ที่พบเป็นโปรโมชัน LP แบบมีเงื่อนไข/ชั่วคราว จึงห้ามใส่ rebate เป็น baseline · bar data ใช้หา signal
ได้แต่พิสูจน์ passive fill ไม่ได้ ต้องมี trade/L2 queue model และ shadow calibration

**ข้อห้ามยืนยัน:** ไม่เปิดบัญชี · ไม่สร้าง/ใช้ API key · ไม่เขียน trading/backtest code · ไม่ออก go/no-go
· Claude/user กลับมาอ่าน decision matrix แล้วตัดสิน direction


---

## ORDER-082 — Entry_Wave5: สัญญาณ Elliott ขา 5 ตาม rule ที่ user ถ่ายทอดเอง (2026-07-10) — `OPEN` (role: Claude spec → agent build/probe)

**Rule จากปาก user (บันทึกตรงคำ — นี่คือ ground truth ของ spec):**
- คนส่วนใหญ่พยายามเข้า wave 3 (เทรนด์ยาวสุด) แต่รู้ตัวก็ต่อเมื่อมัน confirm แล้ว (break S/R,
  break trendline) → เข้าไม่ทัน/RR ไม่คุ้ม
- **จุดได้เปรียบ: พอรู้ว่า wave 3 เกิดแล้ว → รอ pullback (wave 4) retrace ~23–38% ของ wave 3
  → เริ่มเข้าได้ เพื่อกิน wave 5**
- **SL = ยอด wave 1** (ตาม EW rule: wave 4 ห้าม overlap โซน wave 1)
- **ออก: break ยอด wave 3 / Fibonacci expansion 100%** — บริเวณนั้นมักเกิด **RSI divergence**
  ร่วม = สัญญาณเตรียมออก/เปิด trailing

**การแปลงเป็นกลไก (draft ให้ user ยืนยันก่อน build):**
1. Swing detection: ZigZag(H1/H4) label โครง 1-2-3: wave1 = impulse แรก, wave2 = retrace ไม่หลุดจุดเริ่ม,
   wave3-confirm = ราคา break ยอด wave1 แล้ววิ่งต่อ ≥ K×|wave1| (เช่น 1.0-1.618) — "รู้หลัง confirm" ตาม user
2. Arm entry เมื่อ: หลัง wave3-peak ราคา retrace เข้าโซน **23.6–38.2% ของ wave 3** (fib จาก zigzag) →
   entry ตามทิศ wave 3 (bar-open + optional confluence: RSI ยังไม่ divergence)
3. SL = ยอด wave 1 (± ATR buffer) — โครงสร้าง ไม่ใช่ระยะสุ่ม · invalid ทันทีถ้า retrace ลึกเกิน 50%
4. TP/exit: ลำดับ (ก) แตะ 100% expansion (wave5 = wave1 length จากจุดเข้า wave4) หรือ break ยอด wave3
   แล้วเปิด ATR trailing (ข) RSI divergence ที่ high ใหม่ = บังคับ trailing แน่น
5. Naked probe ตามมาตรฐาน (1 ไม้/สัญญาณ, no grid): symbol แรก = **XAUUSD H1** (trending home) +
   GBPUSD H1 · window 2023-26 + BWD 2020-22 · บาร์ผ่าน: naked PF ≥ 1.0 ทั้ง 2 window บน symbol ใดหนึ่ง
**หมายเหตุ:** มีไฟล์คอร์ส (Jobot) Elliott Wave 5 Zone v1/AAA ให้เทียบ rule (block labels) — ใช้ตรวจว่า
การตีความข้อ 1-4 ตรงกับที่คอร์สสอนไหม ก่อน build
**ห้าม:** build ก่อน user ยืนยัน draft ข้อ 1-4 · ข้าม naked probe ไป grid/recovery


---

## ORDER-082 — AMENDMENT (user ยืนยัน 2026-07-10 ค่ำ)

- ✅ ZigZag + Fibonacci = แนวที่ user ต้องการ (ตรงกับไฟล์คอร์สด้วย) · ข้อควรระวัง build:
  **ZigZag ขาสุดท้าย repaint — ใช้เฉพาะ pivot ที่ confirm แล้วเท่านั้น** + พิจารณา ATR-adaptive
  deviation แทน fixed (ให้ swing scale ตาม volatility)
- Entry level = **input เลือกได้ {23.6, 38.2, 50, 61.8}** (user: "จุดสำคัญ ... ประมาณนี้") — sweep เป็น lever
- Invalidation = **โครงสร้าง: wave 4 ห้าม overlap โซนยอด wave 1** (แทน fixed 50% เดิม — สอดคล้อง
  SL ที่ยอด wave 1 พอดี ราคาแตะ SL = โครงพังเอง)
- สถานะ: spec ครบ พร้อม build → คิวหลัง ORDER-078/083

## ORDER-075/078 — NOTE เพิ่ม (user observation 2026-07-10 ค่ำ): Boss_16 entry v1 candidate = SPIKE-FADE

user ใช้ Kangaroo จริงมาพักใหญ่ สังเกต: **มันสวนที่ปลายไส้เทียน — ราคา spike ขึ้นแรง ๆ = เปิด sell สวนทันที**
(ไม่ใช่ oscillator threshold) → อธิบายได้ว่าทำไมต้นฉบับยิงถี่กว่า RSI-fade v0 ของเรา 7 เท่า ·
entry v1 ที่ควรลองใน funnel รอบหน้า: **velocity/spike fade** — bar range ≥ k×ATR หรือ move X จุด
ใน Y นาที → เข้าสวน (มี distance + MM ต่อยอดเองตามที่ user ว่า) · ทดสอบเป็น lever แยกหลัง 078 จบ

## ORDER-083 — build "(Boss)_NewsGuard" watchdog EA (user เคาะ policy ครบ 2026-07-10) — `DONE(Claude-agent, 2026-07-10)`

**Design ที่ user ยืนยัน:** generic ใช้ได้ทุกบัญชีตลอดไป — attach 1 chart/บัญชี · **input list ของ
magic + policy ต่อ magic** (configurable, ไม่ hardcode) · window default ก่อนข่าว 30 นาที / หลัง 15 นาที ·
เฉพาะ High impact ของสกุลใน symbol ที่ magic นั้นถือ + USD เสมอ

**Spec:**
1. Input: `GuardConfig` string รูปแบบ `"magic:policy;magic:policy;..."` policy ∈ {C=CLOSE_ALL,
   B=BLOCK_NEW, N=NONE} + `PreNewsMin=30` `PostNewsMin=15` + `NewsFile="EA_LAB_news_week.csv"`
2. แหล่งข่าว: อ่าน CSV จาก Common\Files (โครงจาก scripts\news_calendar.ps1 → daily chain ก๊อปไป
   Common\Files ให้ด้วย — เพิ่มบรรทัดใน daily_monitor.ps1) · แปลง BkkTime → server time ด้วย offset input
3. CLOSE_ALL: ปิดทุก position ของ magic นั้น (ทุก symbol) เมื่อเข้าหน้าต่างข่าวของสกุลที่เกี่ยว ·
   log ทุกครั้ง · ไม่เปิดคืนเอง (EA เจ้าของเปิดใหม่ตาม signal ของมัน)
4. BLOCK_NEW: สื่อสารผ่าน **GlobalVariable** `NEWSGUARD_BLOCK_<magic>` = 1 ในหน้าต่างข่าว —
   Boss V2 chassis เพิ่มเช็ค GV นี้ก่อนเปิดไม้ใหม่ (additive, default ทำงานเฉพาะเมื่อ GV มี) ·
   EA นอก chassis (locked) ใช้ B ไม่ได้ → ตอน validate config ให้เตือน
5. Fail-safe: ไฟล์ข่าวหาย/เก่าเกิน 48 ชม. = ไม่ทำอะไรเลย + Alert (อย่าเดา) · ทุก action พิมพ์ journal
6. Tests (แบบ tests\ pattern): harness เปิด dummy positions หลาย magic ใน tester → จำลองไฟล์ข่าว
   fake → assert: C ปิดถูกตัว/ถูกเวลา · B ตั้ง GV ถูกช่วง · N ไม่แตะ · fail-safe ทำงาน
7. compile 0/0 · ห้ามแตะ behavior EA เดิม (chassis GV check = additive) · tpl_regression CLEAN
**Acceptance:** EA + tests PASS ครบ + ตาราง test result + คู่มือ attach สั้น ๆ (รวม PostNews/timezone) ·
commit `[tag] ORDER-083 done` · **ห้าม:** attach จริง (user ทำเอง) · verdict

### RESULT (Claude-agent 2026-07-10) — built + tested, ยังไม่ attach จริงตามคำสั่ง

**ไฟล์:**
- `ea_projects\(Boss)_NewsGuard\(Boss)_NewsGuard.mq5` + `.ex5` (compile **0 errors, 0 warnings**) — EA wrapper (timer 10s)
- `ea_projects\(Boss)_NewsGuard\NewsGuard_Core.mqh` — logic ทั้งหมด (canonical copy เดียว, test include ตรง)
- `ea_template\core\Execution.mqh` — GV bridge additive: `Exec_NewsBlocked()` เช็ค `NEWSGUARD_BLOCK_<magic>`
  ใน `Exec_Open` + `Exec_PlacePending` (จุดคอขวด OrderSend เดียวของ chassis → คุมทั้ง market/grid/ladder ทุก Boss build
  รวม Kangaroo) · inert เมื่อ GV ไม่มี · จัดการ/ปิด/modify ไม่แตะ
- `ea_template\tests\NewsGuard_Test.mq5` + `run_tests.ps1` (เพิ่มบรรทัด copy core mqh — additive)
- `scripts\news_calendar.ps1` — BkkTime ใน news_week.csv เปลี่ยนเป็น `yyyy.MM.dd HH:mm` (StringToTime อ่านตรง;
  EA มี fallback parser format US เก่าด้วย) · `scripts\daily_monitor.ps1` — เพิ่ม copy → `Common\Files\EA_LAB_news_week.csv`
  (copy รอบแรกทำแล้ว ไฟล์อยู่ใน Common\Files แล้ว)

**Test results (run_tests.ps1, XAUUSD H1 2024.01.02–05 Model 1):**

| test | result | ครอบคลุม |
|---|---|---|
| NewsGuard_Test | **PASS** | C ปิดทุกไม้ใน window (log ยืนยันปิดที่ winStart ตรงนาที) · B: GV set ตอนเข้า window / ลบตอนออก, ไม้ไม่ถูกปิด · N ไม่แตะ · เหตุการณ์ NZD ที่ irrelevant (ถือแต่ XAUUSD) = ไม่ทำอะไร · fail-safe ไฟล์หาย = ไม่ปิดไม้/ไม่ตั้ง GV + Alert 1 ครั้ง · bridge: Exec_Open/Exec_PlacePending โดน veto เมื่อ GV=1, ผ่านเมื่อ GV=0/ไม่มี · unit: parse เวลา 2 format, staleness 49h/1h, ccy↔symbol, ParseConfig ทิ้ง token เสีย 3 ตัวถูก |
| AcctGate_Test | PASS | (เดิม — ไม่กระทบ) |
| Persist_Test | PASS | (เดิม) |
| StackStep_Test | PASS | (เดิม) |

**tpl_regression.ps1 = `REGRESSION CLEAN`** (Boss_11/12/13/14 net/pf/trades ตรง baseline ทุกตัว —
GV bridge inert จริงเมื่อไม่มี NewsGuard)

**คู่มือ attach (สั้น):**
1. Attach `(Boss)_NewsGuard` **1 chart ต่อบัญชี** (symbol/TF ไหนก็ได้ — มันกวาดทุก symbol ตาม magic) · EA นี้ไม่เปิดไม้เอง
2. `GuardConfig` = `"magic:policy;..."` เช่น `"990101:C;990102:B;990103:N"` — C=ปิดทุกไม้ของ magic ช่วงข่าว
   (EA เจ้าของเปิดใหม่เองหลัง window), B=ห้ามเปิดไม้ใหม่ (ไม้เดิม+exit ทำงานปกติ — **ใช้ได้เฉพาะ EA แม่พิมพ์
   Boss V2 ที่ recompile หลัง 2026-07-10**; EA locked ให้ใช้ C), N=ไม่แตะ (บันทึกไว้ว่าตั้งใจ)
3. Window: `PreNewsMin=30` / `PostNewsMin=15` (default ตาม user) · ข่าว = High-impact ของ USD เสมอ + สกุลใน
   symbol ที่ magic นั้นถือไม้อยู่
4. **`ServerToBkkOffsetHours`** (default 4): Bkk = server + N · วิธีเช็ค: ดูนาฬิกา Market Watch เทียบเวลาไทย —
   Exness ปกติ UTC+3 (หน้าร้อน) → 4, UTC+2 (หน้าหนาว) → 5 · **เช็คใหม่หลัง DST เปลี่ยนทุกครั้ง**
5. ไฟล์ข่าว: daily chain 07:30 เขียน `Common\Files\EA_LAB_news_week.csv` ให้อัตโนมัติแล้ว · ไฟล์หาย/เก่า >48h
   → EA เข้า fail-safe: ไม่ทำอะไร + Alert เตือน (ไม่เดา) · ทุก action พิมพ์ journal prefix `[NEWSGUARD]`

**หมายเหตุ implementation (deviation เล็ก):** (1) BkkTime format ใน news_week.csv เปลี่ยนเป็น MQL5-parseable —
consumer เดียวของไฟล์คือ EA นี้ (dashboard ใช้ HTML แยก) (2) test จำลอง "stale 48h" ที่ระดับ decision function
(`NG_IsStaleAge`) เพราะ mtime ในไฟล์ tester เป็นเวลาจริง ปลอมอายุไฟล์ไม่ได้ — path missing-file ทดสอบเต็ม flow จริง
(3) ccy↔symbol match เพิ่ม fallback ชื่อ symbol (broker บางเจ้ารายงาน base ของ XAUUSD ไม่ใช่ "XAU" — เจอจริงใน tester)

---

## REVIEW ORDER-083 — `REVIEWED(Claude, 2026-07-10)`

Verdict: ผ่าน — design ถูกจุด (veto ที่ choke point เดียวใน Execution.mqh = คุมทุก Boss build รวม pending ladder ·
fail-safe ไม่เดา · GV bridge inert เมื่อไม่มี guard) · tests PASS ครบรวม edge cases (ccy ไม่เกี่ยว = ไม่แตะ,
ไฟล์หาย = Alert อย่างเดียว) · deviations ทั้ง 3 สมเหตุผล (CSV format มี consumer เดียว + fallback parser)
**GAP ที่พบระหว่าง review: NewsGuard เป็น MQL5 — คุมได้เฉพาะบัญชี MT5** แต่กอง no-SL ที่ต้องการ
CLOSE_ALL ที่สุดอยู่บน **MT4 141049900** (Zeus 7777 + Kangaroo 1112-1115) → เปิด **ORDER-083B: port
NewsGuard_Core เป็น .mq4** (logic เดิม, OrderClose แทน position API, test บน MT4 lane) — OPEN
**ข้อควรระวังตอน attach (อยู่ในคู่มือแล้ว แต่ย้ำ):** ต้อง attach บน **terminal เทรดจริงบน VPS** —
instance monitor ในเครื่องแล็บเป็น investor password (อ่านอย่างเดียว ปิดไม้ไม่ได้) · ห้ามใส่ magic 0
ใน GuardConfig เด็ดขาด (จะไปปิดไม้มือของ user)

---

## ORDER-084 — Retro-audit: ไล่ verdict DEAD/REJECT/PARKED ทั้งหมดกับกฎใหม่ (user: "ตายเปล่าเยอะ") — `CLAIMED(Claude-agent, 2026-07-10)` ขั้น extract · ขั้น judge = Claude

**ทำไม:** กฎ rescue-ladder (optimize ≥3 รอบ lever ต่างชุด × ≥2 TF ก่อนตาย) + PARKED-VERIFY(user) +
EA-SCORE เพิ่งเกิดวันนี้ — verdict เก่าจำนวนมากตัดสินก่อนกฎนี้ · user เชื่อ (ประสบการณ์ตรง: หลายตัวที่ live
อยู่รอดเพราะมือ user เคยเทส) ว่ามีของดีตายเปล่าค้างอยู่

**ขั้น 1 — extract (mechanical, agent):** กวาดทุก verdict จาก EA_SCORECARD_AND_REGISTRY.md +
MASTER_BACKLOG.md + memory signal-landscape (อ่านผ่านไฟล์ repo ที่อ้างถึง) + AGENT_TASKBOARD
(ORDER ที่ REVIEWED) → ตาราง CSV ต่อ EA/concept: ชื่อ · verdict · วันที่ · **lever ที่ sweep จริง
(นับจากหลักฐาน ไม่ใช่คำอ้าง)** · จำนวน TF ที่ทดสอบ · จำนวน symbol · best PF ที่เคยเห็น · class
(STRUCTURAL/PARAMETRIC/artifact) · หลักฐานชี้ไปไหน
**ขั้น 2 — judge (Claude):** แยก 3 กอง — (ก) STRUCTURAL/artifact ยืนยัน = ตายจริง ไม่แตะ
(ข) **under-swept ตามกฎใหม่** (sweep <3 รอบ หรือ 1 TF) = คิว rescue เรียงตาม EV: best-PF ใกล้เกณฑ์ +
mechanism เข้ากับ symbol ที่รู้จัก (reversion→ranger · breakout/trend→XAU/GBP) (ค) idea ดีแต่เครื่องมือ
ยุคนั้นไม่ถึง = **PARKED-VERIFY(user)** สรุป 3 บรรทัด/ตัวส่ง user
**ขั้น 3 — แผน rescue:** เลือก top 5-10 จากกอง (ข) → order sweep ตามสูตร rescue-ladder
(lever ชุดตามประเภทใน backtest-optimize-rigor) — **ห้ามรันใน order นี้** แค่วางแผน+ประมาณชั่วโมงเครื่อง
**Acceptance ขั้น 1:** `_triage\RETRO_AUDIT_VERDICTS.csv` ครบทุก verdict ที่หาเจอ + สรุปนับต่อกอง ·
commit `[tag] ORDER-084 extract done` · **ห้าม:** ตัดสิน/จัดกองเอง (แค่ extract หลักฐาน) · ห้ามรัน backtest

### ORDER-084 extract SUMMARY (Claude-agent, 2026-07-10 — raw counts, no judging)
1. **Total verdict rows: 154** ใน `_triage\RETRO_AUDIT_VERDICTS.csv` (per-EA/cell/concept; aggregate-pool rows ครอบ ~2,700 EAs ที่ตายเป็นกอง: ORDER-036 1,318 ex4 · ORDER-035 203 ex5 · 63-EA screen · idea_bank 251)
2. Counts by verdict: **REJECT 52 · DEAD 33 · CANDIDATE 13 · CORE/ROBUST/DEMO 12 · NO-EDGE/closed 11 · PARKED 11 · DQ/DISQUALIFIED 10 · CONDITIONAL 3 · WATCH 3 · LEAD 2 · DROP 2 · other 2**
3. **TFs_tested == 1: 141/154 (92%)** — เกือบทั้ง lab ตัดสินจาก TF เดียว (H1 ล้วนเป็นส่วนใหญ่); มีแค่ 13 ราย ที่เห็น ≥2 TF (RSI from pips 4 TF · Boss_16 2 TF · WaveS1 2 TF · NR7/PrevDay/EMATREND/Kangaroo/NuiIndy/ST03/HalfTrend ฯลฯ)
4. **Evidence = default-only/smoke-only (เข้ม): 29 rows · รวมชั้นเดียว (BWD-only/lot-check-only/hard-gate): 44 rows** — กองนี้คือผู้สมัคร rescue-ladder โดยนิยาม (ไม่เคยเห็น lever sweep แม้แต่รอบเดียว)
5. Top-10 best_PF_seen ในกอง DEAD/PARKED/REJECT/DQ (118 rows): CITY-GOLD 259.99 (artifact) · gold-grid concept 85.14 (M2 artifact) · Degold 13.12 (M1-vs-M4 artifact) · Scalper_S3 10.71 (fixed-spread artifact) · GBPJPY1H90PCWR 8.15 (PARKED-no-data, absurd-flag) · Golden Elephant 7.77 (TP-lever artifact) · Gold Stuff V7 5.09 · Dark Mimas 5.0 (regime) · **EA_SUPERTREND XAU H4 4.49 OOS (ตัวจริง — parked เพราะ corr 0.946 กับ KER)** · COT-filter 3.96 (year-split kill)
6. หมายเหตุ: top-PF ส่วนใหญ่ = artifact ที่พิสูจน์แล้ว; PF สูงสุดที่*ไม่ใช่* artifact ในกองตาย = SuperTrend 4.49 · IR Whale 3.94(suspect) · EURUSD Forex Robot 3.89 (BWD 0.39) · FZ2 3.05 (flat-lot 0.36) · 143 E4.7.4 3.0 (BWD 0.85) · AsReMix 2.99 (PARKED regime)
7. รูปแบบที่เห็นซ้ำใน extraction (ข้อมูล ไม่ใช่คำตัดสิน): กอง mass-smoke ตายด้วย 1 symbol-pair × 1 TF × default; กอง concept 200-list ตายด้วย default smoke 1-2 cell แล้วปิด "concept DEAD ถาวร"; กองที่ sweep จริง ≥3 lever มีน้อย (~25 rows: Boss_14 family · ST03 · SessionBreakout 1200-pass · FlagPennant · WaveS1 · SuperTrendFlip · Degold · ZIGL-EURUSD 216-pass ฯลฯ)
8. Sources ที่กวาดครบ: EA_SCORECARD_AND_REGISTRY.md · MASTER_BACKLOG.md · AGENT_TASKBOARD.md (ORDER-001→083) · ORDER-036_MT4_MASS_SMOKE.md · memory signal-landscape.md · STRATEGY_200_ANALYSIS.md · PROJECT_STATE.md §07-08 (อ้างถึงจาก taskboard)
9. STRATEGY_200_ANALYSIS.md = **prior scores ไม่ใช่ verdict** (คะแนน /10 ก่อนเทส) — ไม่ได้สร้าง row ต่อ prompt; ตัวที่ถูกเทสจริง (#9/20/30/62/66/68/70/83/94/100/105/127/135) มี row จากผลเทสใน backlog/signal-landscape แล้ว
10. AGENT_TASKBOARD_MERGE.md = engineering port track ล้วน (MERGE-01..08) ไม่มี EA verdict — ไม่มี row
11. ORDER-064 (ChatGPT export mining) เป็น idea-triage ไม่ใช่ backtest verdict — ไม่ได้สร้าง row (จดไว้กันสับสน)
12. Orders 048-054 ไม่มี header ใน taskboard (เลขข้าม 047→055) — verdict ของ funnel 07-08 (SqueezeBRK ROBUST · Trendline #8 EXPERIMENTAL · ConfluenceMartATR/London/plain-squeeze ตก) สกัดจาก PROJECT_STATE §SESSION 2026-07-08 + การอ้างอิงใน ORDER-059/065/067 แทน
13. Verdict ที่มี supersede-chain ถูกยุบเหลือ row เดียว (verdict ล่าสุด + ประวัติใน evidence): ST03 family (CORE→STRUCTURAL 07-10) · 2020v2 (REJECT→revive→REJECT) · Happy thaipop (PARKED→REJECT ×16.3) · Automated Forex Grail (AUTO-REJECT→revive→REJECT-spread) · LNBREAK/NRBreakout (DEAD→re-exam ORDER-008B)
14. คอลัมน์ class_claimed = คำอ้างของ verdict เดิมเท่านั้น (STRUCTURAL/PARAMETRIC/artifact/unknown) — ยังไม่มีการจัดกอง rescue/dead/verify ตามข้อห้าม
15. ขั้น judge (กอง ก/ข/ค + แผน rescue top 5-10) = รอ Claude lead อ่าน CSV


---

## REVIEW ORDER-084 — `REVIEWED(Claude, 2026-07-10)` — จัด 3 กอง + rescue queue + เปิด ORDER-085

**ภาพรวม:** 154 verdicts · **92% เทสแค่ 1 TF · 29-44 ตายบน default-only** → สมมุติฐาน user ยืนยัน
แต่เมื่อไล่หลักฐานรายตัว ก้อนใหญ่ตายถูกต้อง (BWD-OOS + lot-check ฆ่า regime-harvester family ถูกแล้ว —
IR Whale eqDD 106% BWD, Dark Mimas wipeout, 143 E4.7.4 DD94, SUPERTRENDSURFER lot×416 = STRUCTURAL ยืน)

**กอง ก — ตายจริง ยืน verdict (ห้าม re-hunt):** artifact ทั้งหมด (CITY-GOLD/Degold/Scalper_S3/
Golden Elephant/gold-grid M2) · structural (FZ2, regime-harvester pool, no-SL family) · properly-swept
(EMATREND 10+sym+11yr · Donchian multi-period · AsianRange/LNBREAK multi-cell · COT (ORDER-059
sweep ครบ+MC refute) · SuperTrendFlip (MC 0.865 + rescue แล้วล้ม))

**กอง ข — action queue (เรียง EV):**
1. 🏆 **EA_SUPERTREND XAU H4 — ไม่ใช่ rescue: validated ครบ (IS 1.54/OOS 4.49 M4 + MC PF-5th 1.57
   ruin 0) ถูก PARK ด้วยเหตุผล corr 0.72-0.95 vs BRK ซึ่งขัด user rule ที่จารึกไว้เอง: "corr สูง = ลด lot
   ไม่ใช่ตัด"** → ORDER-085: M0+spread confirm + ข้อเสนอ size เล็กเข้าพอร์ต · EA-SCORE คาด ~7
2. **swb grid flat-lot AUDCAD** (M0 1.80/DD20, ladder ×3-4 แล้ว) — ตรง premium/bench tier 5-6 ของ
   ปรัชญาใหม่พอดี → PARKED-VERIFY(user): ตัดสิน attach demo experiment #3 ไหม
3. **Oracle EA** (M0 1.43/DD39 ที่ขอบ, ค้างเงื่อนไข "อ่าน trade list ก่อน" ที่ไม่เคยทำ) → งานถูก 1 ชม.:
   อ่าน trade list → ให้ EA-SCORE → จบซะที
4. **Keltner / Ichimoku / PrevDay / ZSCORE / IB_OCO / XAU_NY** — concept ปิดจาก 1-2 default cell ·
   ceiling-pattern XAU (1.13-1.19 สามแนวทาง) = หลักฐานระดับ mechanism ห้ามเทสซ้ำ XAU แต่**คลาส
   symbol อื่นยังไม่เคยลอง** → rescue สูตรใหม่: JPY-cross/ranger H4 ละ 1 สายตาม mechanism fit
   (สูตร 3 รอบ × 2 TF) — batch เดียว ~6 smokes ก่อน ค่อยเลือกตัว sweep
5. Phoenix/GBPJPY1H90PCWR pool (PARKED-no-data, PF 8.15 = absurd-flag flat 1 lot) — EV ต่ำ:
   รอ data window ใหม่หรือ user รู้จักที่มา → เข้า VERIFY list

**กอง ค — PARKED-VERIFY(user) รอบแรก (สรุป 3 บรรทัดต่อตัวส่ง user):** swb grid AUDCAD (attach ไหม) ·
Oracle EA (จะให้อ่าน trade list เลยไหม) · GBPJPY1H90PCWR (รู้จักที่มา/เคยใช้ไหม) · MultiHedge (M0 1.29
net จิ๋ว — คุ้มถือไหม)

## ORDER-085 — SuperTrend XAU H4: un-park ตาม corr rule — `DONE(Claude-agent, 2026-07-10)`

**คำสั่ง:** (1) Model 0 + spread-stress confirm บน set validated เดิม (`EA_SUPERTREND.mq5`,
KAUERMAN-era configs — หา set/params จาก signal-landscape entry 2026-06-27) XAU H4 2023-2026
(2) คำนวณ corr/DD-overlap ปัจจุบัน vs BRK-XAU Bars55 + Boss_16 (ถ้ามี data) (3) ตาราง + ข้อเสนอ
size ตามสูตร reduce-lot (เช่น 1/3 ของ BRK) **Acceptance:** ตาราง M0/SPR + corr + ร่าง EA-SCORE
ต่อเกณฑ์ 8 ข้อ · commit `[tag] ORDER-085 done` · **ห้าม:** deploy/verdict (Claude+user ตัดสิน)

**ผล (agent, 2026-07-10 — lane D:\Meta 5b เท่านั้น, main lane ไม่แตะ):**

Config = `_mt5_auto\sweeps\_sets\ST_v1_naked_default.set` (default: ATR10×3, EMA200, ADX14≥20,
SL=ATR×2 ทุกไม้, no TP, flip-exit, fixed 0.01 lot, 1 position) · deposit 10,000 / leverage 1:100 ·
XAUUSD H4 2023.01.01-2026.07.01 · report `_mt5_auto\reports\ST_XAU_H4_M0_FULL.htm`

**1) M0 + spread stress vs old M4 reference:**

| Run | Window | PF | Net $ | Trades | DD | Sharpe |
|---|---|---|---|---|---|---|
| **M0 every-tick (ใหม่, gen-tick 141M, quality 98%)** | 2023.01-2026.07 | **2.93** | **1,690** | 56 | bal 2.85% / eq 4.85% | 1.95 |
| **M0 + spread +30pt (arithmetic, −$0.30/ไม้)** | 2023.01-2026.07 | **2.88** | **1,674** | 56 | closed-trade 2.57% | — |
| M4 ref IS (validated 2026-06-27) | 2023.01-2025.06 | 1.54 | — | 37 | 2.23% | 1.10 |
| M4 ref OOS (validated 2026-06-27) | 2025.06-2026.06 | 4.49 | — | 18 | 4.94% | 1.75 |
| M2 smoke ref (2026-06-27) | 2023-2026 | 3.32 | — | 50 | 4.8% | — |

- ⚠️ **วิธี spread stress:** MT5 (build 5836) **ไม่รับ fixed spread จาก ini เลย** — พิสูจน์แล้ว:
  `Spread=20/300` และ `TestSpread=300` ใน `[Tester]` ให้ผล **เหมือน baseline ทุกตัวเลข**
  (reports `SPRCHK_ST_base/s20/s300/ts300`, M1 2026.01-07: net 256.49 / PF 3.42 / 5t ทั้ง 4 run)
  → MT5 ใช้ spread จาก history/tick จริงเสมอ (ต่างจาก MT4 TestSpread) · stress จึงเป็นเลขคณิตบน
  trade list: XAU point=0.01, 0.01 lot → 30pt = $0.30/ไม้ (แม่นตรงเพราะ flat-lot) · หมายเหตุใส่ไว้ใน
  `scripts/mt5_run.ps1` แล้ว กันคนหลังเข้าใจผิดว่า ini stress ได้
- **Trade profile (เผื่อใช้ตัดสิน):** win 35.7% · top-5 winners = **95.2% ของ net** (ไม้ใหญ่สุด
  $723.9 = 43% ของ net) · yearly net: 2023 **−16.76** (8t) / 2024 +59 (20t) / 2025 +668 (22t) /
  2026H1 +980 (6t) → กำไรกระจุก 2025-26 (gold bull) · **BWD 2020-22 ยังไม่เคยรัน**

**2) Corr / DD-overlap (monthly P&L Pearson, `corr_monthly.py` logic, window 2023.01-2026.07):**

| Baseline | corr (shared months) | DD-overlap (เดือนลบตรงกัน/เดือนลบรวม) | หมายเหตุ |
|---|---|---|---|
| **BRK_FULLSPAN (BRKXAU Bars40 buy-only H1, 2026-07-08 = report BRK-XAU ใหม่สุด)** | **0.421** (23 shared mo) | **4/27 = 0.15** | เกิน gate 0.40 นิดเดียว = WATCH |
| QWEN_BRK55 IS+OOS (Bars55/TP8/EMA150 variant) | 0.217 (9 shared mo) | 4/23 = 0.17 | ⚠️ data บาง (24 ไม้) + เป็น config PF 1.07 ไม่ใช่ Bars55 validated |
| BRKXAUH4_c0 (Bars8 — ref เดิม 2026-06-27) | 0.728 (30 shared mo) | 8/25 = 0.32 | ตรง ref เดิม 0.724 ✅ |

⚠️ report HTML ของ Bars55 validated (TP4/6+EMA200) ไม่เหลือในเครื่อง (ไฟล์ `BRKXAUH4_c4/c5` ถูก sweep
Bars8-20 เขียนทับ — เหลือแต่ตัวเลขใน `sweeps/DONCH_XAU_H4.csv`) → ใช้ BRK_FULLSPAN (Bars40 buy-only,
ใหม่สุด+ไม้เยอะสุด) เป็น baseline หลักแทน · สูตร reduce-lot ตาม rule เดิม (corr>0.4 = ลด lot ไม่ตัด):
ที่ corr 0.42-0.73 ≈ **1/3 ของ BRK leg** (เชิงกลไกตามสูตร — การตัดสิน size จริงเป็นของ Claude+user) ·
Boss_16: ไม่มี monthly data ที่เทียบได้ใน repo ณ วันรัน (ORDER-078 ยังไม่ปิด) — ข้ามตามเงื่อนไข "ถ้ามี data"

**3) ร่าง EA-SCORE v1 (หลักฐานต่อเกณฑ์ — ไม่รวมคะแนน ไม่ verdict ตามห้าม):**

| # | เกณฑ์ | หลักฐาน | สถานะ |
|---|---|---|---|
| 1 | Entry edge เปล่า (หลัง spread+M0) | naked fixed-lot by design · M0 PF 2.93 → +30pt 2.88 | ✅ pass |
| 2 | โครง MM ครบ | source ยืนยัน: hard SL=ATR×2 ทุกไม้ · 1 position · fixed 0.01 lot (ไม่มี grid/martingale) · flip-exit | ✅ pass |
| 3 | สอง regime | 2023-26 บวกรวม **แต่ 2023 = −16.76** · **BWD 2020-22 ไม่เคยรัน** | ❓ unknown (ยังไม่ทดสอบ — จุดโหว่ใหญ่สุด: กำไร 97% มาจาก 2025-26) |
| 4 | Plateau | ไม่เคย sweep รอบ ATR10/mult3/SL2.0 (validate ที่ default จุดเดียว) | ❓ unknown |
| 5 | Holdout+MC | MC bootstrap 2026-06-27: PF-5th 1.57 / DD-95th 3.26% / ruin 0% ✅ · แต่ holdout ที่ไม่เคย select = ไม่มี (OOS 2025.06-2026.06 ถูกใช้ตัดสิน validate ไปแล้ว) | ◐ partial |
| 6 | M0+spread confirm | run นี้: 2.93→2.88 ไม่ละลาย | ✅ pass |
| 7 | Live tracking ≥2 เดือน | PARKED ตั้งแต่ 2026-07-02 ไม่เคย attach demo/live (มี `_vps_deploy\ST_XAU_H4_live_v1.set` เตรียมไว้เฉยๆ) | ❌ no data |
| 8 | Portfolio additive | corr 0.421 vs BRK ปัจจุบัน (เกิน 0.40 นิด) / 0.728 vs Bars8 · DD-overlap ต่ำ 0.15 | ◐ borderline (ตาม rule = reduce-lot ไม่ใช่ตัด) |

_(กุญแจเพดาน: ไม่มีข้อไหนโดน — มี SL+cap, มี source, ไม่มี crack/DLL)_


---

## ORDER-086 — swb grid AUDCAD: เตรียม bundle demo experiment #3 (user อนุมัติ 2026-07-10) — `DONE(Claude-agent, 2026-07-10)`

**คำสั่ง:** ตาม pattern `_demo_deploy\` เดิม (UnNomGuai/ClevrFX experiment): หา .ex4 + flat-lot set
ของ swb grid 4.1.0.3_h ที่ผ่าน chain (ORDER-036 survivors + ORDER-046/047 — lot_multiplier=0,
AUDCAD H1) → สร้าง `_demo_deploy\MT4\swb_experiment3\` = .ex4 + locked .set + README สั้น
(magic 990 · kill: Model-0 อ้างอิง DD 20.4% → kill ที่ DD 30% · เกณฑ์ judge +3 เดือนหลัง attach ·
สถานะ = bench tier 5-6 / premium-track กติกา VISION) + MD5 · **Acceptance:** bundle ครบ 3 ไฟล์ +
แถวใหม่ใน DEMO_DEPLOYMENT_PLAN §experiment (mark: รอ user attach 69424711) · commit
`[tag] ORDER-086 done` · **ห้าม:** แก้ set จาก validated ค่า · attach เอง

**✅ ผลงาน (agent, 2026-07-10):** bundle `_demo_deploy\MT4\swb_experiment3\` ครบ 4 ไฟล์ —
`swb grid 4.1.0.3_h.ex4` (copy unmodified, MD5 `35BFB25E93966DE1A9521A4A59313379` = ตรง lock เดิมใน
`README_DEPLOY.md` ✓) · `swb_AUDCAD_demo.set` (locked copy จากบันเดิล #2 เดิม: lot_multiplier=false +
lot_multiplier_2=1 + magic=990 — ไม่แตะค่า validated; input อื่น = compiled defaults ตามที่ chain รันด้วย
`swb_flat.set`, ชุดเต็มอ้างใน `_mt4_auto\reports\O47P3_swb_AUDCAD_M0.htm` Parameters) · `README.md`
(kill DD 30% vs M0 ref 20.44% · ladder >1.0 lot/ไม้ · judge attach+3mo ≥30t PF≥1.4 · bench tier 5-6 +
กรง premium-track อ้าง VISION.md) · `MD5SUMS.txt` · เพิ่ม section experiment #3 ใน
`DEMO_DEPLOYMENT_PLAN.md` (mark 🟡 รอ user attach บน 69424711) · ไม่ attach เอง

## ORDER-087 — concept rescue batch #1: 6 smokes บน symbol-class ที่ไม่เคยลอง — `DONE(Claude-agent 2026-07-10)`

**ทำไม:** ORDER-084: Keltner/Ichimoku/PrevDay/ZSCORE ปิดจาก XAU/EUR default cell เดียว · ceiling
XAU (1.13-1.19) ห้ามซ้ำ XAU แต่ mechanism-matched class อื่นไม่เคยแตะ
**คำสั่ง (Model 2 smoke ราคาถูก, main MT5 lane, 2023-2026, default params, บาร์ pre-registered:
PF≥1.2 = ผ่านไปคิว rescue-ladder เต็ม · <1.0 ทั้งคู่ cell = ปิด concept ฝั่งนั้น):**
- EA_KELTNER: GBPJPY H4 + USDJPY H4 (trend-follow → JPY movers)
- EA_ICHIMOKU: GBPJPY H4 + AUDJPY H4 (kumo = JPY-native)
- EA_ZSCORE: AUDNZD H4 + AUDCAD H4 (reversion → ranger ที่ Boss_14 พิสูจน์ว่า range จริง)
(PrevDay ตัด — daily-level mechanism พิสูจน์อ่อนข้ามตลาดแล้ว EV ต่ำสุดในสี่ตัว)
**Acceptance:** ตาราง 6 แถว PF/net/DD/trades + บาร์กำกับ · commit `[tag] ORDER-087 done` · **ห้าม:** verdict

### ORDER-087 RESULTS (Claude-agent, 2026-07-10)

บาร์ pre-registered ตามคำสั่ง (quote verbatim): "บาร์ pre-registered:
PF≥1.2 = ผ่านไปคิว rescue-ladder เต็ม · <1.0 ทั้งคู่ cell = ปิด concept ฝั่งนั้น"

Run conditions: main MT5 lane (D:\Meta 5) · Model 2 open-price · H4 · 2023.01.01–2026.07.01 ·
deposit 10000 · default params (sets = `_mt5_auto/ab_sets/rescue1_sets/`) · history quality 100%
ทั้ง 6 run (5430 bars) · reports = `_mt5_auto/reports/RESCUE1_*.htm`

| EA | Symbol | PF | Net ($) | DD% (equity max) | Trades |
|---|---|---|---|---|---|
| EA_KELTNER | GBPJPY H4 | 0.73 | -142.50 | 1.79 | 127 |
| EA_KELTNER | USDJPY H4 | 0.72 | -120.43 | 1.56 | 143 |
| EA_ICHIMOKU | GBPJPY H4 | 0.84 | -167.35 | 2.83 | 267 |
| EA_ICHIMOKU | AUDJPY H4 | 0.78 | -150.82 | 1.74 | 273 |
| EA_ZSCORE | AUDNZD H4 | 0.71 | -96.82 | 1.10 | 278 |
| EA_ZSCORE | AUDCAD H4 | 1.34 | +124.91 | 0.28 | 283 |

(no verdict — บาร์ตัดสินโดย lead ตามคำสั่ง)

## ORDER-088 — Oracle EA: ปิดเงื่อนไขค้าง "อ่าน trade list" — `DONE(Claude-agent, 2026-07-10)`

**คำสั่ง:** ใช้ Model-0 report เดิมของ Oracle (ORDER-036 survivors, EURUSD H1, PF 1.43/DD39) —
ถ้า report ไม่มี trade table ให้รันซ้ำ 1 ครั้งบน MT4 lane · วิเคราะห์ trade list ตามกฎ CommunityPower
(2026-07-06): ลำดับ lot (ladder? cap?) · SL มีจริงไหม · การกระจุกกำไร (top-5 trades = กี่ % ของ net) ·
พฤติกรรม DD 39% เกิดจากตะกร้าเดียวหรือสะสม **Acceptance:** ตาราง 4 คำตอบ + quote ไม้จริง ·
append ใต้ order · commit `[tag] ORDER-088 done` · **ห้าม:** verdict (Claude ให้ EA-SCORE เอง)

### ORDER-088 RESULTS (Claude-agent, 2026-07-10)

Source report: `_mt4_auto/reports/BWD4R3_Oracle_EA_EURUSD_M0.htm` — ตรงกับตัวเลข order ทุกตัว
(PF 1.43 / net +5,775.60 / max DD 5,487.36 = 39.00%) · EURUSD H1 · **window = BWD 2020.01.01–2023.01.01**
· every tick, quality 90%, spread 11 · trade table ครบ (2,666 rows = 1,333 opens + 1,333 closes) →
**ไม่ต้องรันซ้ำ**. Parse แบบ full-row (ทุก `<tr>`, ไม่พึ่ง striping class) —
type counts: buy=700 sell=633 close=1332 close-at-stop=1, ผลรวม close = +5,775.45 ตรง report.

Params ใน report เฉลยโครง: `start_lot=0.1; range=150; level=10; lot_multiplier=true; multiplier=1.5;
use_sl_and_tp=false; tp_in_money=5; stealth_mode=true; use_stoch=true (5,3,3 30/70)` — grid-martingale
สองฝั่งอิสระ (buy grid + sell grid รันพร้อมกันได้) ปิดทั้งตะกร้าด้วย TP-in-money.

| # | คำถาม | คำตอบ (ตัวเลขจริงจาก trade list) |
|---|---|---|
| 1 | Lot sequence | **Geometric ladder ×1.5, step 150 pips**: 0.10 → 0.15 → 0.23 → 0.35 → 0.53 → 0.80. Distribution: 0.10×1257 · 0.15×46 · 0.23×16 · 0.35×8 · 0.53×4 · 0.80×2. Cap ตาม param = level 10 (lot ชั้น 10 จะ ≈ 3.84) แต่ลึกสุดที่แตะจริงในเทส = **ชั้น 6** (2 ครั้ง), ค้างพร้อมกัน 2.16 lots |
| 2 | SL | **ไม่มีเลย** — ทั้ง 1,333 ไม้เปิดด้วย S/L=0.00000, T/P=0.00000 (`use_sl_and_tp=false` + `stealth_mode=true`) · ไม่มี close type `s/l` แม้แต่แถวเดียว · แถว "close at stop" 1 แถวคือ force-close ท้ายเทส: `#1333 2022.12.31 01:42 0.10 @1.07036 −67.10` |
| 3 | Profit concentration | **Top-5 = $5,822.54 = 100.8% ของ net $5,775.45** (top-5 เกิน net ทั้งก้อน; top-10 = 139.3%) — และ 2 ไม้ใหญ่สุดคือไม้ rescue ชั้น 6 ของตะกร้าลึกเอง: `#367 sell 0.80 close 2020.09.08 +1,698.62` · `#862 buy 0.80 close 2022.05.19 +1,636.13`. ไม้ชนะ 1,255 ไม้ที่เหลือเฉลี่ยแค่ $15.28 |
| 4 | DD-39% episode | **ตะกร้าเดียว ไม่ใช่สะสม** — buy grid #857–862: เปิด 2022.03.31 @1.11307 ถัวลงทุก 150 pips ถึง 1.03803 (2022.05.12) · equity peak 14,069.71 (2022.03.31) → 5,487.36/14,069.71 = **39.0% ตรงเป๊ะ** (equity trough ≈ 8,582 ที่ EURUSD low ~1.035, 2022.05.13) · ปิดยกตะกร้า 2022.05.19 @1.05905 **net −383.05** (ไม้ rescue +1,636.13 + #861 +214.71 vs 4 ไม้แพ้ −2,233.88 = สถิติ "4 consecutive losses" ใน report) · ตะกร้าลึกเทียบเท่าอีกลูก = sell grid #362–367 (Jul–Sep 2020, 1.12368→1.19871): equity ≈7,051 ตอนเปิดชั้น 6 ทั้งที่ balance 11,583.80 = ที่มาของ **Relative DD 42.39%** ใน report; ปิดยกตะกร้า 2020.09.08 @1.17769 net +211.44 |

Quote ตะกร้าลึกสุด (sell grid 2020, จาก trade list ตรงๆ):
```
#362 sell 0.10 @1.12368 opened 2020.07.03 20:17
#363 sell 0.15 @1.13868 opened 2020.07.14 17:45
#364 sell 0.23 @1.15369 opened 2020.07.21 21:47
#365 sell 0.35 @1.16869 opened 2020.07.27 04:38
#366 sell 0.53 @1.18370 opened 2020.07.30 22:59
#367 sell 0.80 @1.19871 opened 2020.09.01 06:38
→ ปิดทั้ง 6 ไม้พร้อมกัน 2020.09.08 17:38 @1.17769: +1698.62 +379.76 −269.25 −517.74 −559.61 −520.34 = +211.44
```

หมายเหตุกลไก: balance โตต่อเนื่องระหว่างตะกร้า buy จม Mar–May 2022 (14,069→15,920) เพราะ sell grid
อีกฝั่ง scalp ได้ตลอด — กำไรรายไม้เล็กบังตะกร้าจมจนกว่าจะ mark-to-market. (no verdict — ตามคำสั่ง)


---

## REVIEW ORDER-087 — `REVIEWED(Claude, 2026-07-10)` — ตัดสินตามบาร์ pre-registered

- **EA_KELTNER = ปิดถาวรทั้ง concept** (XAU 1.04 เดิม + GBPJPY 0.73 + USDJPY 0.72 — trend-class
  ทดสอบครบ 2 คลาสตลาดแล้ว) · **EA_ICHIMOKU = ปิดถาวร** (XAU 1.13 + GBPJPY 0.84 + AUDJPY 0.78 —
  kumo บน JPY-native ก็ไม่รอด) — สองตัวนี้ตอนนี้ตายแบบ*ถูกกติกาใหม่*แล้ว ไม่ใช่ตายเปล่า
- **EA_ZSCORE: AUDNZD 0.71 ปิด cell · AUDCAD 1.34/283t/DD0.28% ≥ บาร์ 1.2 → คิว rescue-ladder เต็ม
  (ORDER-089)** — สอดคล้อง landscape: AUDCAD = ranger ที่ Boss_14 validate แล้ว · reversion เข้าบ้านถูก
- เพิ่มลง signal-landscape ตอนปิดวัน: Keltner/Ichimoku closed-all-classes · ZSCORE AUDCAD = LEAD

## ORDER-089 — EA_ZSCORE × AUDCAD: rescue-ladder เต็มตามสูตร (ตัวแรกที่ใช้กฎใหม่ครบวงจร) — `DONE(Claude-agent, 2026-07-10)`

**คำสั่ง (สูตร reversion จาก backtest-optimize-rigor: 3 รอบ × 2 TF บน AUDCAD):**
- รอบ 1 (entry): zscore period × threshold (ค่า default ±2 ระดับต่อแกน) — H4 และ H1
- รอบ 2 (exit): TP/SL structure (fixed RR / revert-to-mean exit / time-stop ตามที่ EA มี input)
- รอบ 3 (filter): session window / ADX-range gate (เทรดเฉพาะ ranging)
- Model 2 → ผู้ชนะ confirm Model 1 · **pre-registered:** มี config PF≥1.4 & trades≥100 & eqDD≤10%
  บน TF ใดหนึ่ง → เข้า funnel เต็ม (BWD/plateau/MC = order ถัดไป) · ไม่มี = ปิด concept อย่างสมบูรณ์
**Acceptance:** ตารางต่อรอบ (top-5 + surface กว้าง) ทั้ง 2 TF · commit `[tag] ORDER-089 done` ·
**ห้าม:** เลือก winner (Claude) · แตะ symbol อื่น · optimize เกิน 3 รอบที่กำหนด

### ORDER-089 RESULTS (Claude-agent, 2026-07-10)

บาร์ pre-registered ตามคำสั่ง (quote verbatim): "**pre-registered:** มี config PF≥1.4 & trades≥100 & eqDD≤10%
บน TF ใดหนึ่ง → เข้า funnel เต็ม (BWD/plateau/MC = order ถัดไป) · ไม่มี = ปิด concept อย่างสมบูรณ์"

Run conditions: main MT5 lane (D:\Meta 5) · EA_ZSCORE.mq5 · AUDCAD · 2023.01.01–2026.07.01 ·
Model 2 open-price · Optimization=1 (complete) · Criterion 0 (max balance) · deposit 10000 · leverage 1:100 ·
fixed lot 0.01 · แต่ละรอบ = optimizer pass แยก, sweep บน **default ของรอบอื่น** (isolation ตามกฎ lab) ·
sets = `_mt5_auto/ab_sets/zscore_sets/Z89_R1_entry.set`, `Z89_R2_exit.set` ·
full surfaces = `_mt5_auto/optimizations/Z89_R1_H4.xml`, `Z89_R1_H1.xml`, `Z89_R2_H4.xml`, `Z89_R2_H1.xml`

EA inputs จริง (อ่าน source ก่อน sweep): `_01_ZPeriod(20)`, `_01_ZThreshold(2.0)`, `_01_ATRPeriod(14)`,
`_02_SL_ATR(2.0)`, `_02_TP_ATR(3.0; 0=ไม่มี TP → exit ที่ Z=0 เท่านั้น)`, `_03_FixedLot`, `_04_Magic`, `_04_AllowLive`

**รอบ 1 (entry): ZPeriod 10–30 step 5 × ZThreshold 1.0–3.0 step 0.5 = 25 combos/TF (default ±2 ระดับต่อแกน)**

H4 top-5 (เรียง PF) — **ผ่านบาร์ 3/25**:

| ZPeriod | ZThr | PF | Net ($) | eqDD% | Trades | ผ่านบาร์? |
|---|---|---|---|---|---|---|
| 25 | 3.0 | 2.00 | +48.10 | 0.25 | 35 | ✗ (trades<100) |
| 20 | 2.5 | 1.61 | +101.21 | 0.28 | 130 | ✓ |
| 15 | 3.0 | 1.60 | +12.52 | 0.14 | 19 | ✗ (trades<100) |
| 30 | 3.0 | 1.48 | +31.15 | 0.23 | 40 | ✗ (trades<100) |
| 25 | 2.5 | 1.45 | +75.54 | 0.29 | 115 | ✓ |

(ผ่านบาร์ตัวที่ 3 = 15/2.5: PF 1.44 / +59.14 / eqDD 0.18% / 122t · surface: threshold 2.5 = แถวที่ผ่านทั้งแถว
ที่ period 15-25; threshold ≤1.5 = PF 1.05-1.17 ทุก period; baseline 20/2.0 reproduce ตรง ORDER-087 = PF 1.34/+124.91/283t ·
cell 10/3.0 = 0 trades)

H1 top-5 (เรียง PF) — **ผ่านบาร์ 0/25**:

| ZPeriod | ZThr | PF | Net ($) | eqDD% | Trades |
|---|---|---|---|---|---|
| 15 | 3.0 | 1.22 | +21.16 | 0.17 | 137 |
| 25 | 3.0 | 1.21 | +39.86 | 0.21 | 228 |
| 25 | 2.5 | 1.12 | +54.37 | 0.32 | 578 |
| 20 | 3.0 | 1.10 | +18.58 | 0.36 | 218 |
| 30 | 2.5 | 1.08 | +35.01 | 0.33 | 536 |

(surface H1: PF สูงสุดทั้งกริด = 1.22 · 16/25 cells ขาดทุน · default 20/2.0 = PF 0.91/-86.56 —
ทั้ง surface ไม่มี cell ใดแตะ 1.4)

**รอบ 2 (exit): SL_ATR 1.0–4.0 step 0.5 × TP_ATR {0, 1.5, 3.0, 4.5, 6.0} = 35 combos/TF
บน round-1 DEFAULTS (ZPeriod=20, ZThr=2.0 held — ไม่ใช่ winner รอบ 1) · TP_ATR=0 = revert-to-mean exit
เท่านั้น (toggle ในตัว EA) · EA ไม่มี time-stop input**

H4 top-5 (เรียง PF) — **ผ่านบาร์ 20/35**:

| SL_ATR | TP_ATR | PF | Net ($) | eqDD% | Trades | ผ่านบาร์? |
|---|---|---|---|---|---|---|
| 4.0 | 1.5 | 1.66 | +161.96 | 0.33 | 242 | ✓ |
| 3.0 | 1.5 | 1.64 | +170.10 | 0.36 | 259 | ✓ |
| 3.5 | 1.5 | 1.60 | +156.55 | 0.41 | 247 | ✓ |
| 3.0 | 3.0 | 1.54 | +157.16 | 0.37 | 250 | ✓ |
| 3.0 | 6.0/0 | 1.54 | +155.86 | 0.37 | 249 | ✓ |

(surface H4: ทุก cell ที่ SL_ATR≥2.5 ผ่านบาร์ทั้งหมด (20 cells, PF 1.46-1.66) · SL_ATR=2.0 = PF 1.33-1.34 ·
SL แคบลง (1.0-1.5) เสื่อมลงเรียบๆ ถึง PF 1.15 · แกน TP แทบไม่ขยับผล (TP 4.5/6.0/0 ให้เลขเกือบเท่ากัน =
TP ไกลไม่เคยถูกชน exit จริงคือ Z=0) · ไม่มี cell ขาดทุนทั้ง 35)

H1 top-5 (เรียง PF) — **ผ่านบาร์ 0/35**:

| SL_ATR | TP_ATR | PF | Net ($) | eqDD% | Trades |
|---|---|---|---|---|---|
| 4.0 | 6.0 | 0.98 | -16.87 | 0.66 | 967 |
| 4.0 | 0 | 0.97 | -22.30 | 0.69 | 966 |
| 4.0 | 4.5 | 0.97 | -26.23 | 0.70 | 970 |
| 4.0 | 3.0 | 0.96 | -29.59 | 0.72 | 974 |
| 4.0 | 1.5 | 0.96 | -29.35 | 0.67 | 1012 |

(surface H1: **ทั้ง 35 cells ขาดทุน** — PF สูงสุด 0.98 · exit lever กู้ H1 ไม่ได้เลย)

**รอบ 3 (filter): N/A พร้อมหลักฐาน** — EA_ZSCORE.mq5 (`D:\Meta 5\MQL5\Experts\EA_ZSCORE.mq5`)
มี input ทั้งหมด 8 ตัวตาม list ข้างบนเท่านั้น — **ไม่มี** session/time-window, day/hour, หรือ ADX/regime-gate
input ใดๆ และ tester ini ไม่มีกลไก period-of-day โดยไม่มี input ใน EA → รอบนี้รันไม่ได้โดยไม่แก้ source
(แก้ source = นอกเหนือคำสั่ง order)

**Model 1 confirm (baseline default บน H1 — TF ที่ยังไม่มีเลข):** report = `_mt5_auto/reports/Z89_DEF_H1_M1.htm`
— PF **0.54** / net **-584.46** / eqDD **6.00%** / **1376 trades** (history quality 100%, 21720 bars).
หมายเหตุ observation (ไม่ใช่ verdict): แย่กว่า Model 2 open-price ของ config เดียวกัน (PF 0.91/-86.56/1243t)
อย่างมีนัย — H1 เทรด intrabar ไวต่อ M1 path.

**สรุปนับบาร์ (PF≥1.4 & trades≥100 & eqDD≤10%):** H4 รอบ1 = 3/25 · H4 รอบ2 = 20/35 ·
H1 รอบ1 = 0/25 · H1 รอบ2 = 0/35 · รอบ3 = N/A ทั้ง 2 TF

(no winner selection, no verdict — ตามห้าม)

---

## REVIEW ORDER-088 — `REVIEWED(Claude, 2026-07-10)` — **Oracle EA: CONDITIONAL → REJECT (EA-SCORE เพดาน 3)**

**เหตุผลตาม rubric (ไม่ใช่ความเห็น):**
- กุญแจเพดาน: **ไม่มี SL สักไม้ใน 1,333 orders** (stealth mode) → เพดาน 3 ทันที · cap level=10 มีจริง
  แต่ non-binding (ladder ×1.5 จาก 0.1 → level10 = 3.84 lot/ไม้ = margin ตายก่อนถึง cap)
- หลักฐาน no-edge โดยไม่ต้องรัน flat-lot: **top-5 trades = 100.8% ของ net** — กำไรทั้งระบบคือ rescue
  trade 2 ไม้ (level-6 ×0.80) ที่เหลือ 1,255 ไม้เฉลี่ย $15 = ศูนย์สุทธิ · near-death 2 ครั้งใน 3 ปี
  (39% + 42.4% relative) รอดเพราะ EURUSD กลับตัวที่ extreme พอดีทั้งคู่
- **บทเรียนใหม่เข้าคลัง: "top-5 concentration > 100% ของ net" = ลายนิ้วมือ recovery-illusion
  ที่อ่านได้จาก trade list โดยไม่ต้องรันอะไรเลย** — เพิ่มเป็นเช็คมาตรฐานคู่กับ flat-lot probe
- สถานะ: ไม่ใช่ตายเปล่า — ตายพร้อมหลักฐานเต็มมือ ปิดเงื่อนไขค้างจาก 2026-07-07 สมบูรณ์ ·
  ถ้า user อยากเลี้ยงเป็น premium-track ส่วนตัว = สิทธิ์ tier 3 (บัญชีทดลอง แยก equity) ตามกติกา


---

## REVIEW ORDER-089 — `REVIEWED(Claude, 2026-07-10)` — H4 ผ่านบาร์ → funnel เต็ม (ORDER-090)

**ตัดสินตาม pre-registration:** H4 ผ่าน (R1 3/25 = แถว threshold 2.5 ทั้งแถว coherent · R2 20/35,
**zero losing cells**, SL_ATR≥2.5 ผ่านหมด, TP axis inert เพราะ exit จริงคือ revert-to-Z=0) ·
H1 = ปิดถาวร (0/60 + M1 confirm 0.54) — single-TF edge ยอมรับได้ (precedent: BRK=H1-only, ST=H4-only)
· ⚠️ ธงที่ต้องแบกไป funnel: M2-vs-M1 divergence บน H1 (0.91→0.54) = concept นี้ fill-sensitive —
**M1/M0 confirm ใน funnel คือด่านชี้ขาดจริง** · R3 N/A มีหลักฐาน (EA ไม่มี filter inputs) — ยอมรับ
เป็น 2 รอบ+โครงสร้าง exit ครบตามเจตนา rescue-ladder (แกน entry+exit sweep แล้วทั้งคู่)

## ORDER-090 — ZSCORE AUDCAD H4: funnel เต็ม (ด่านสุดท้ายก่อน bench) — `DONE-STOPPED-AT-STAGE-2(Claude-agent, 2026-07-10)`

**Config กลาง (plateau-center จาก 089, ประกอบข้ามรอบต้องเทสสด):** ZPeriod 20 · ZThreshold 2.5 ·
SL_ATR 3.0 · TP_ATR 0 (revert-only) · flat lot
**ขั้น (หยุดเมื่อตกด่าน · Model 1 ทุกขั้น):**
1. Combined-config confirm H4 2023-2026 + neighbors ±1 step ทุกแกน (8 เซลล์รอบศูนย์กลาง —
   plateau requirement: ไม่มีเซลล์ขาดทุน)
2. BWD 2020-2022 (บาร์: PF ≥1.1 และ eqDD ≤15%)
3. Year-split 2020-2026 (นับปีลบ — บาร์: ≤1 ปีลบ ตื้น)
4. MC bootstrap (robustness-validator convention — บาร์: PF-5th ≥1.1, ruin 0)
5. Model 0 confirm 1 รัน (ธง fill-sensitive จาก 089 — เลขละลาย >30% = ตก)
**Acceptance:** ตารางทุกขั้น + สถานะผ่าน/ตกต่อด่าน · commit `[tag] ORDER-090 done` · **ห้าม:** tune เพิ่ม ·
verdict (Claude ให้ EA-SCORE เมื่อจบ)

### ORDER-090 RESULTS (Claude-agent, 2026-07-10) — STOPPED AT STAGE 2

Run conditions: main MT5 lane (`D:\Meta 5`) · EA_ZSCORE · AUDCAD H4 · Model 1 (M1 OHLC) ทุกขั้นตามคำสั่ง ·
deposit 10000 · leverage 1:100 · center set = `_mt5_auto/ab_sets/zscore_sets/Z90_p20_t2.5_sl3.0.set`
(ZPeriod 20 · ZThreshold 2.5 · SL_ATR 3.0 · TP_ATR 0 · FixedLot 0.01 ตาม rescue1/ZSCORE_default) ·
neighbor sets = `Z90_p*_t*_sl*.set` ที่โฟลเดอร์เดียวกัน · reports = `_mt5_auto/reports/Z90_*.htm`

**Stage 1 — center + 8 neighbors + SL {2.5,3.5} · 2023.01.01–2026.07.01
(บาร์ verbatim: "plateau requirement: ไม่มีเซลล์ขาดทุน") → ✅ ผ่าน 11/11 ไม่มีเซลล์ขาดทุน**

| ZPeriod | ZThr | SL_ATR | PF | Net ($) | eqDD% | Trades |
|---|---|---|---|---|---|---|
| 15 | 2.0 | 3.0 | 1.07 | +24.01 | 0.57 | 299 |
| 15 | 2.5 | 3.0 | 1.32 | +42.06 | 0.24 | 119 |
| 15 | 3.0 | 3.0 | 2.25 | +19.70 | 0.12 | 18 |
| 20 | 2.0 | 3.0 | 1.23 | +77.19 | 0.42 | 260 |
| **20** | **2.5** | **3.0** | **1.64** | **+93.66** | **0.31** | **120** |
| 20 | 3.0 | 3.0 | 1.15 | +7.73 | 0.24 | 29 |
| 25 | 2.0 | 3.0 | 1.19 | +59.48 | 0.37 | 219 |
| 25 | 2.5 | 3.0 | 1.28 | +46.91 | 0.34 | 106 |
| 25 | 3.0 | 3.0 | 1.39 | +24.53 | 0.25 | 33 |
| 20 | 2.5 | 2.5 | 1.54 | +86.35 | 0.33 | 125 |
| 20 | 2.5 | 3.5 | 1.63 | +89.37 | 0.36 | 118 |

(center Model-1 = PF 1.64/+93.66/120t ตรงแนว Model-2 ของ 089 (1.54-1.61 บริเวณเดียวกัน) —
M2→M1 ไม่ละลายบน H4 · history quality 100% ทุก run, 5430 bars)

**Stage 2 — center BWD 2020.01.01–2022.12.31
(บาร์ verbatim: "PF ≥1.1 และ eqDD ≤15%") → ❌ ตก: PF 0.77 < 1.1**

| Window | PF | Net ($) | eqDD% | Trades | Bars | Quality |
|---|---|---|---|---|---|---|
| 2020.01.01–2022.12.31 | 0.77 | -50.46 | 1.06 | 104 | 4674 | 99% |

(coverage ครบ — 4674 bars H4 / quality 99% → ตกจริง ไม่ใช่ data gap · eqDD 1.06% ผ่านครึ่งหลังของบาร์
แต่ PF ตกครึ่งแรก = ตกด่าน)

**Stage 3-5 — ไม่รันตามกติกา "หยุดเมื่อตกด่าน".** หมายเหตุ: year-split 4 run แรกออกมาก่อนสั่งหยุด batch
(raw evidence เฉยๆ ไม่ใช่การไปต่อ): 2020 PF 0.75/-22.00/35t · 2021 PF 0.66/-21.56/36t ·
2022 PF 1.05/+2.81/31t · 2023 PF 2.89/+64.92/41t — สองปีลบติดกัน 2020-2021 สอดคล้องกับ BWD ที่ตก
(ถ้าด่าน 3 ได้รันจริงก็ตกเช่นกัน: >1 ปีลบ)

(no verdict, no tuning, no config changes — ตามห้าม · Claude ตัดสินเอง)

---

## REVIEW ORDER-085 — `REVIEWED(Claude, 2026-07-10)` — SuperTrend: แข็งกว่าที่คิด แต่ยัง un-park ไม่ได้ · EA-SCORE ปัจจุบัน ≈ 6/10 · เปิด ORDER-085B

**ของดีที่ยืนยัน:** M0 every-tick PF 2.93 / eqDD 4.85% + spread+30pt แทบไม่สะเทือน (2.88 — โครง
single-position + SL ATR×2 ทุกไม้ = spread-immune by design) · **corr กับ BRK ที่ deploy จริงตอนนี้
(Bars40) = 0.421 ไม่ใช่ 0.72** (เลขเก่าวัดกับ Bars8) · DD-overlap 0.15 ต่ำ → ตาม user rule = เข้าได้ที่
~1/3 lot ของ BRK **ถ้า**ผ่านรูที่เหลือ

**รูที่ระบบเก่ามองข้าม (จับได้เพราะ rubric บังคับไล่ 8 ช่อง):**
1. **ปี 2023 ติดลบ + 97% ของกำไรมาจาก gold bull 2025-26 + BWD 2020-22 ไม่เคยรัน** — validated
   เดิมคือ IS/OOS ที่อยู่ใน regime เดียวกันทั้งคู่ (กฎ backward-OOS บังคับของเราเกิดทีหลัง EA นี้)
2. **ไม่เคย sweep รอบ default เลย** (ATR10/mult3/SL2 = จุดเดียว) — plateau ไม่รู้
- top-5 = 95.2% ของ net: สำหรับ single-position trend-follow = โปรไฟล์ธรรมชาติของ class ไม่ใช่
  recovery-illusion (ไม่มี averaging) แต่มันตอกย้ำคำถาม regime ข้อ 1
**คำตัดสิน:** ยังไม่ deploy · EA-SCORE ปัจจุบัน 2+2+0+0+0+1+0+1 = **6/10** (tier bench) · คำถามถูกสุด
ที่ชี้ขาด = ORDER-085B (BWD + plateau ~12 รัน) — ผ่านทั้งคู่ → 8/10 = เงินจริง cent 1/3-lot ทันที

**Method finding สำคัญ (agent พิสูจน์ด้วย A/B 4 รัน):** **MT5 build 5836 เมิน `Spread=`/`TestSpread=`
ใน ini เสมอ** (ใช้ spread ประวัติจริงเท่านั้น ต่างจาก MT4) → spread-stress ฝั่ง MT5 ต้องทำแบบ
arithmetic บน trade list · warning ใส่ใน mt5_run.ps1 แล้ว · ⚠️ audit เบา ๆ ภายหลัง: มี MT5 run ไหน
ในอดีตอ้าง spread-stress ผ่าน ini บ้าง (ส่วนใหญ่ spread-stress เราทำฝั่ง MT4 ซึ่งไม่กระทบ)

## ORDER-085B — SuperTrend XAU H4: อุดรูสองรูสุดท้าย — `DONE(Claude-agent, 2026-07-11)`

**คำสั่ง:** (1) BWD 2020.01.01-2022.12.31 config default, Model 1 (บาร์: PF≥1.0 & eqDD≤10% —
trend-follow ยอมรับ BWD อ่อนกว่า reversion ได้ แต่ห้ามเจ๊ง) (2) plateau sanity 3×3×2: ATRPeriod
{7,10,14} × Mult {2.5,3,3.5} × SL_ATR {1.5,2.0} full window Model 1 (บาร์: ไม่มี cell ขาดทุน + default
ไม่ใช่ peak โดด) · **Acceptance:** 2 ตาราง + บาร์ verbatim · commit `[tag] ORDER-085B done` ·
**ห้าม:** tune/เลือกใหม่ · verdict

### ORDER-085B RESULTS (Claude-agent, 2026-07-11)

Run conditions: portable lane `D:\Meta 5b` only (main `D:\Meta 5` lane ไม่แตะ) · `EA_SUPERTREND` ·
XAUUSD H4 · Model 1 (open-price) · deposit 10000 · leverage 1:100 · base set =
`_mt5_auto/sweeps/_sets/ST_v1_naked_default.set` · 18 plateau variant sets generated at
`_mt5_auto/ab_sets/st085b_sets/ST085B_ATR{7,10,14}_M{2.5,3.0,3.5}_SL{1.5,2.0}.set` (only
`_01_ATRperiod` / `_01_Multiplier` / `_02_SL_ATR_mult` changed per cell, all other inputs held at
default) · reports = `_mt5_auto/reports/ST085B_*.htm` · all 19 runs completed on first attempt, no
retries needed, no 0-trade cells, no FAILED cells.

**1) BWD 2020.01.01–2022.12.31, default config (ATR10 × Mult3.0 × SL_ATR2.0)**

Bar pre-registered (quote verbatim): "PF≥1.0 & eqDD≤10%"

| Window | PF | Net ($) | Trades | Balance DD% | Equity DD% | History Quality | Bars |
|---|---|---|---|---|---|---|---|
| 2020.01.01–2022.12.31 | 0.88 | -91.49 | 64 | 2.71% | 3.27% | 99% | 4645 |

**2) Plateau sanity 3×3×2, full window 2023.01.01–2026.07.01 (all 18 cells, history quality 98%,
5404 bars every cell — no coverage anomalies)**

Bar pre-registered (quote verbatim): "ไม่มี cell ขาดทุน + default ไม่ใช่ peak โดด"

| ATRperiod | Multiplier | SL_ATR | PF | Net ($) | Trades | Balance DD% | Equity DD% | |
|---|---|---|---|---|---|---|---|---|
| 7 | 2.5 | 1.5 | 2.03 | 1,092.06 | 68 | 2.90% | 5.53% | |
| 7 | 2.5 | 2.0 | 1.90 | 1,072.55 | 68 | 2.58% | 5.23% | |
| 7 | 3.0 | 1.5 | 3.06 | 1,472.79 | 50 | 2.09% | 4.19% | |
| 7 | 3.0 | 2.0 | 2.78 | 1,443.64 | 50 | 2.56% | 4.40% | |
| 7 | 3.5 | 1.5 | 2.91 | 1,542.92 | 51 | 2.23% | 4.14% | |
| 7 | 3.5 | 2.0 | 2.74 | 1,581.00 | 51 | 2.59% | 4.17% | |
| 10 | 2.5 | 1.5 | 2.94 | 1,778.56 | 66 | 1.60% | 4.49% | |
| 10 | 2.5 | 2.0 | 2.56 | 1,658.11 | 66 | 2.35% | 4.73% | |
| 10 | 3.0 | 1.5 | 2.90 | 1,593.22 | 56 | 2.38% | 5.02% | |
| **10** | **3.0** | **2.0** | **2.93** | **1,691.23** | **56** | **2.85%** | **4.85%** | **← default** |
| 10 | 3.5 | 1.5 | 2.15 | 955.10 | 51 | 2.63% | 4.26% | |
| 10 | 3.5 | 2.0 | 3.40 | 1,928.42 | 51 | 2.89% | 4.10% | |
| 14 | 2.5 | 1.5 | 2.19 | 1,310.86 | 65 | 3.27% | 5.40% | |
| 14 | 2.5 | 2.0 | 2.18 | 1,414.50 | 65 | 2.48% | 4.97% | |
| 14 | 3.0 | 1.5 | 2.46 | 1,239.80 | 57 | 2.42% | 3.86% | |
| 14 | 3.0 | 2.0 | 3.08 | 1,998.90 | 57 | 2.73% | 4.24% | |
| 14 | 3.5 | 1.5 | 1.98 | 829.52 | 53 | 2.22% | 3.83% | |
| 14 | 3.5 | 2.0 | 1.91 | 886.85 | 53 | 2.40% | 3.85% | |

Range check (raw, no judgment): PF spans 1.90 (ATR7×M2.5×SL2.0, min) to 3.40 (ATR10×M3.5×SL2.0, max)
— all 18 cells PF>1 (no losing cell by the numbers). Default cell (ATR10×M3.0×SL2.0, PF 2.93) sits
between its immediate one-step neighbors on every axis: ATR axis at M3.0/SL2.0 → ATR7=2.78 /
ATR14=3.08 (both bracket 2.93); Mult axis at ATR10/SL2.0 → M2.5=2.56 / M3.5=3.40 (bracket 2.93);
SL axis at ATR10/M3.0 → SL1.5=2.90 (near-identical to 2.93). Default M1-full-window number (PF 2.93 /
net 1,691.23 / eqDD 4.85%) reproduces the ORDER-085 M0 every-tick reference (PF 2.93 / net 1,690 /
eqDD 4.85%) almost exactly — M0→M1 does not decay this config.

**Anomalies:** none. All 19 tester runs returned a report on the first attempt (no timeout, no retry,
no 0-trade cell, no FAILED cell). History quality 99% (BWD window) / 98% (full window) on every run —
no data-gap flags.

(raw numbers only — no pass/fail verdict, per order ห้าม)

---

## REVIEW ORDER-090 — `REVIEWED(Claude, 2026-07-10)` — ZSCORE×AUDCAD: ปิดตาม pre-registration · fragment เก็บเข้าคลัง

**ตัดสิน:** Stage 1 plateau แท้ (11/11 ไม่มี cell ขาดทุน + M1 ไม่ละลายบน H4) แต่ Stage 2 BWD PF 0.77
(2020 0.75 / 2021 0.66 สองปีลบติด) = **regime-dependent reversion** → ปิดตามบาร์ที่ล็อกไว้ ·
rescue-ladder ครบทุกข้อก่อนตาย (entry+exit sweep ✓ · 2 TF ✓ · 2 symbol ✓ · BWD ✓) — **ตายแบบ
สมบูรณ์ตามกติกาใหม่ ไม่ใช่ตายเปล่า**
**Fragment เข้าคลังไอเดีย (หลัก user: mechanism ที่เคยพิมพ์เงินได้ต้องจดไว้):** "AUDCAD 2023+
= range regime ที่ reversion รีดได้จริง (plateau กว้าง) แต่ naked reversion ตายปีเทรนด์ 2020-21 —
ต้องมีโครงช่วย" · ข้อพิสูจน์เทียบ: **Boss_14 AUDCAD (990204) ครองเซลล์เดียวกันอยู่แล้วแบบผ่านทุกปี**
(grid+cage structure ทำสิ่งที่ naked ทำไม่ได้) → เซลล์นี้มีผู้ครองที่ดีกว่า ไม่เสียดาย
**ไม่เข้า PARKED-VERIFY(user):** ไม่มีอะไรให้ user เทสมือเพิ่ม — คำถามทุกข้อถูกตอบด้วยหลักฐานแล้ว


---

## ORDER-091 — MASTER PLAN: intake คลัง Forex 9 โฟลเดอร์ของ user (แผนแม่บท — ลูก 091A-D จ่ายตาม pacing) — `OPEN`

**ที่มา (user 2026-07-10 ค่ำ พร้อม annotation ต่อโฟลเดอร์ — เก็บคำต่อคำใน chat log):** คลังใหญ่กว่า
ที่ X-ray รอบแรกกวาดมาก — coverage เช็คแล้ว: `10_EA_PROJECTS` โดนแค่ 211 path · `04_FxDreema_Learner`
7 path · ขนาดจริง: ~1,100 src + ~9,600 binaries + **~1,100 report/set แนบ** (BOT MOGUL 713 + Final EA 389)

**กฎยืนพื้นทุก wave:** pacing 1-2 order/รอบ · vendor report = claim ไม่ใช่หลักฐาน (memory
wobr-botranking: BotMogul rank = adverse-selected overfit) · ทุกตัวจบ funnel ต้องได้ EA-SCORE ·
mechanism ที่เคยพิมพ์เงิน → จด IDEA_CATALOG เสมอ · DD สูง ≠ ปัดตก → diagnosis→lever (คำ user:
".Final EA อาจ DD เยอะแต่เอาไปทำต่อได้ เชื่อผม")

**Wave 0 — 091A: ขยาย X-ray+concept ให้ครบ 9 โฟลเดอร์ — `DONE(Claude-agent, 2026-07-11)`** (mechanical, dedupe hash vs 1,050 เดิม):
`wait_Fxdreema MT5` (151 src) · `3. ready to use` (38+102) · `review EA\Jobot` (1,556 bin) ·
`BOT MOGUL` (2,905 bin) · `AI_GEN` (168 src) · `Course jobot` (375 src) · `04_FxDreema_Learner`
(221 src) · `.Final EA` (189 src + 4,514 bin) → merged catalog + ตาราง "ใหม่จริง vs ซ้ำของเดิม"

**Wave 1 (ต่อจาก 085B/083B ที่ค้างคิว):**
- **091B — BOT MOGUL report sweep:** parse 713 vendor reports → ตาราง claimed PF/DD/symbol/TF →
  คัด top ตาม claim × โครงผ่าน X-ray → **BWD-OOS spot-kill ทีละ 5** (1 รัน/ตัว ฆ่าถูกสุด) —
  ห้ามเชื่อ report แนบจนกว่า BWD เราเองผ่าน

---

## ORDER-091B — BOT MOGUL report sweep (เฟส 1: parse+rank+shortlist) — `DONE-PHASE1(Claude-agent, 2026-07-11)`

**ที่มา:** ORDER-091A พบ 711 BOT MOGUL html = MT4 Strategy Tester report ของ vendor เอง (`ORDER091A_REPORTS.csv`) ·
spot-check: window แคบ (เช่น 2023 ปีเดียว = cherry-pick) + inputs โชว์ `Multiple=1.6` = martingale · memory
wobr-botranking: BotMogul rank = adverse-selected overfit → **report = claim ห้ามเชื่อจนกว่า BWD เราเองผ่าน**

**คำสั่ง (เฟส 1 mechanical เท่านั้น — ห้ามรัน backtest, ห้าม verdict):**
1. เขียน `scripts\botmogul_parse.py` (portable python `tools\python312`) parse 711 html (path จาก
   `_triage\ORDER091A_REPORTS.csv` type=html scan_folder='BOT MOGUL Bundles') สกัดต่อไฟล์: EA id (parent_ea_folder) ·
   symbol · period/TF · **test window (from-to)** · Total Net Profit · Profit Factor · Balance/Equity DD (%+abs) ·
   Total Trades · Modeling Quality · **Inputs ทั้งบรรทัด** → parse หา danger flag จากชื่อ input:
   `Multiple/Martingale/Mult>1` = MARTINGALE · `Lots_Per_Money/Risk%` = money-based-lot · ไม่มี SL/StopLoss ใน inputs = NO_SL_INPUT (heuristic)
2. Output `_triage\BOTMOGUL_CLAIMS.csv` (1 แถว/report) + join กับ `FXDREEMA_XRAY.csv` ถ้า EA id ตรง
   (ส่วนใหญ่เป็น .ex4 ไม่มี source → ใช้ flag จาก inputs แทน)
3. **Ranked shortlist** `_triage\BOTMOGUL_SHORTLIST.md`: เรียงตาม claimed PF ที่ **window ≥ 2 ปี** (ตัด single-year
   cherry-pick ขึ้นหัว) · แยกคอลัมน์ "structural red flag" (martingale/no-SL/DD>40%) · top-30 + เหตุผลกำกับ ·
   **ตาราง window-distribution** (กี่ report เทสปีเดียว vs หลายปี = วัด cherry-pick ทั้ง bundle)
**Acceptance:** CLAIMS.csv ครบ 711 (หรือรายงาน parse-fail ต่อไฟล์) · SHORTLIST.md + window-dist ·
spot-check 2 report ตัวเลข parse ตรง html จริง · commit `[tag] ORDER-091B done` (เฟส 1)
**ห้าม:** รัน backtest · verdict · เชื่อ claim · แตะไฟล์ D:\Forex
**เฟส 2 (Claude/Opus judge เอง หลัง review shortlist):** คัด top 5 ที่ claim สูง × โครงไม่ตาย → BWD spot-kill
- **091C — .Final EA inventory + funnel queue:** ของ hand-validated โดย user = prior สูงสุดของคลัง ·
  cross-ref กับ verdict เดิม (Kangaroo/Zeus/Hedging-Rebalance-TIMELOCK เจอแล้วจาก copy ฝั่ง OneDrive) ·
  เรียงคิว funnel (MC+OOS ที่ user ไม่เคยทำ) ทีละ 1-2 ตัว/batch ตาม rescue-ladder + diagnosis→lever
  · **PREP DONE(Claude, 2026-07-11):** triage tier + คิว funnel + ปมที่ต้องถาม user =
  `_triage\ORDER091C_FINALEA_PREP.md` — Opus รอบหน้าเริ่มจากไฟล์นั้น (ข้อ 1 = ถาม user แยก keeper vs
  indicator-sample noise ก่อน ประหยัดสุด)

**Wave 2 — 091D: `3. ready to use`** (user optimize แล้ว ไม่เคย MC+OOS): funnel + idea extraction
ทุกตัวแม้ตก (คำ user: "ทดลองไม่ผ่านก็ได้ แต่เอาไอเดียมาต่อยอดที")

**Wave 3:** AI_GEN (concept-mine — user บอกไอเดียดี) · review-EA\Jobot (bin ล้วน → X-ray strings +
smoke เฉพาะโครงสะอาด)

**Wave 4 — ช้า ทำคู่กับ user เท่านั้น (ห้าม agent เดี่ยว):**
- **Course jobot** (375 src จากคอร์สที่ user เรียน) — คำเตือน user ตรง ๆ: "ถ้าทำไว ๆ ตีความพลาดแน่
  ว่างค่อยทำ" → session ละ 1 module คุยกับ user ประกอบ
- **Document** (ตำรา price action: ใช้ performance ABC ของแท่งเทียนเป็นเงื่อนไขเปิดไม้ → เข้า template
  เป็น entry option) — โฟลเดอร์โชว์ 0 ไฟล์ code/pdf = format อื่น (docx/รูป?) ต้องสำรวจก่อน แล้ว
  ตบ spec กับ user ("เดี๋ยวเรามาตบ ๆ กันอีกที")
- FxDreema_Learner = ตัวอย่างเรียน → concept-mine อย่างเดียว
**หมายเหตุ:** FXDREEMA_XRAY.csv ซ่อม duplicate concept column แล้ว (2026-07-10 ค่ำ)

### ORDER-091B RESULT phase-1 (Claude-agent, 2026-07-11)

**Parsed 711/711 (100% ok, 0 parse-fail, 0 partial)** — built `scripts\botmogul_parse.py`
(portable `tools\python312\python.exe`), output `_triage\BOTMOGUL_CLAIMS.csv` (711 rows) +
`_triage\BOTMOGUL_SHORTLIST.md`. Encoding gotcha caught before it silently nuked the whole
run: these reports are **UTF-16 LE** (BOM `FF FE`), not ASCII/UTF-8 — a naive utf-8/cp1252
decode doesn't raise, it just silently returns NUL-interleaved garbage that fails every
regex (first run: parsed=0/711 fail). Fixed with a BOM-sniff in `read_text()`; worth
remembering for any other script that touches this bundle's raw html.

**Window-distribution headline — 100% single-year cherry-pick, confirmed not a bug:**
all 711 reports fall into exactly 4 distinct test windows, all <1yr:
2023.01.01–2023.12.31 (476), 2024.01.01–2024.12.31 (179), 2024.01.01–2024.11.09 (54),
2024.01.01–2024.09.15 (2). **Zero reports span >=2 years** → the "top-30 PF at
window_years>=2" table required by the order is genuinely empty (not a parser miss —
spot-checked). This *is* the finding: the whole 711-report bundle is single-year vendor
cherry-pick, exactly as the ORDER-091A spot-check + memory `wobr-botranking` predicted.

**Top-5 preview (from the single-year table, since >=2yr table is empty — NOT ranked/validated):**
| ea_id | symbol | PF | trades | window | red_flag |
|---|---|---|---|---|---|
| 202.5.3 | TRUE | 761.49 | 1 | 2024 (full yr) | MARTINGALE;NO_SL |
| 202.3.3 | TRUE | 760.33 | 1 | 2024 (full yr) | MARTINGALE;NO_SL |
| 202.4.3 | TRUE | 760.33 | 1 | 2024 (full yr) | NO_SL |
| 202.2.3 | TRUE | 759.15 | 1 | 2024 (full yr) | NO_SL |
| 204.3.3 | TRUE | 752.48 | 1 | 2024 (full yr) | MARTINGALE;NO_SL |

All 15 top single-year rows are **degenerate 1-trade reports** with `Symbol: TRUE`
(literal, confirmed in raw html, not a parse bug — a vendor report anomaly, see below)
and `History Quality: 54%` (vs 100% everywhere else) — textbook broken/non-representative
tester runs, not a real edge. Don't chase these for phase 2.

**X-ray join rate: 2/711** — expected and confirmed: BOT MOGUL ea_id's are numeric/dotted
folder codes (`1-1-1`, `202.5.3`, ...), essentially never matching `FXDREEMA_XRAY.csv`
`name` (real EA filenames) since the bundle is almost entirely .ex4/.ex5 compiled-only.

**Anomalies for the judge:**
1. **Danger flags are near-universal:** MONEY_LOT 711/711 (100%), NO_SL_INPUT(heuristic)
   667/711 (94%), MARTINGALE 317/711 (45%). Median claimed PF across all 711 = 3.79
   (implausibly high for real forex trading — consistent with overfit/cherry-pick).
2. **Symbol field is not always a forex pair:** 532 EURUSD, but 100 `CCET`, 61 `TRUE`
   (literal boolean string — a vendor/generator artifact, not our parser), 7 `DELTA`,
   5 `ITC`, plus `ADVANC`/`TLI`/`INTUCH`/`SCB` — these look like Thai SET-listed stock
   tickers mixed into the "Forex" folder tree. Flagging in case phase 2 accidentally
   treats a stock-market backtest as a forex one.
3. `_triage\BOTMOGUL_CLAIMS.csv` left-joins `xray_concept/xray_flags/xray_has_sl/
   xray_lot_escalation` from `FXDREEMA_XRAY.csv` where matched (2 rows) — everything
   else is blank by design (see join-rate note above).

---

## ORDER-091B เฟส 2 — BWD spot-kill 5 ตัว "least-bad" ของ BOT MOGUL — `DONE(Claude-agent, 2026-07-11)`

**Judge call (Claude lead หลัง review เฟส 1):** ทั้ง bundle = single-year cherry-pick 100% (0 report ข้าม ≥2 ปี) ·
top PF = 1-trade artifact (symbol="TRUE" quality 54%) · 94% no-SL · 45% martingale · median PF 3.79 = ไม่จริง.
**แต่กฎห้ามตีตายจาก vendor-flag อย่างเดียว** → รัน BWD เราเอง 5 ตัวที่ "ดูรอดที่สุด" (real forex + ไม้เยอะ + DD
ต่ำ) เป็นตัวแทน — ถ้าตัวดูดีสุดยังตายนอกปี cherry-pick = ปิด bundle ด้วย run ของเราเอง (ยืนยัน wobr-botranking)

**5 ตัวคัด (EURUSD H1 2023, DD ต่ำ = ลายเซ็น no-SL grid ที่ยังไม่เจอปีร้าย):** `1-18-26` (PF 23.7/DD 1.93%/679t) ·
`1-16-31` (67.2/8.06%/845t) · `1-16-20` (35.0/9.99%/1615t) · `1-16-23` (41.8/10.73%/1436t) · `1-1-23` (64.0/34.87%/337t)

**คำสั่ง (agent, foreground synchronous — ห้าม background แล้วรอ notification):** (1) หา ex5 ของแต่ละ ea_id
ใน `D:\Forex\...\1000+ EA BOT MOGUL Bundles\MT5 (ex5)\` (READ-ONLY — copy ออกมา ห้ามแตะต้นฉบับ) → วางใน
D:\Meta 5b lane (2) แปลง inputs_raw ของ ea_id นั้นจาก `BOTMOGUL_CLAIMS.csv` เป็น .set (3) รัน BWD
**2020.01.01-2022.12.31 EURUSD H1 Model 1 deposit 10000 leverage 1:100** ด้วย vendor inputs · 1 รัน/ตัว ·
report prefix `BM091B_` **บาร์ pre-registered (verbatim): รอด = PF≥1.1 AND eqDD≤25% (ทั้งคู่). ตกข้อใดข้อหนึ่ง = ตาย**
**Acceptance:** ตาราง 5 แถว PF/net/eqDD/trades ที่ BWD + บาร์กำกับ verbatim · ระบุ ex5 ที่หาไม่เจอ/รันไม่ได้ (+เหตุผล) ·
commit `[tag] ORDER-091B phase2 done` · **ห้าม:** verdict สุดท้าย (Claude ตัดสิน) · tune · เชื่อ claim · แตะ D:\Forex

### ORDER-091B phase-2 RESULT (Claude-agent, 2026-07-11)

**Pre-registered bar (verbatim, not judged here):** "รอด = PF≥1.1 AND eqDD≤25% (ทั้งคู่). ตกข้อใดข้อหนึ่ง = ตาย"

Setup: 5 .ex5 copied read-only from `D:\Forex\...\MT5 (ex5)\...` into `D:\Meta 5b\MQL5\Experts\BM091B\`
(originals untouched). One EA (`1-18-26`, TTM7312) failed to load on first attempt —
`cannot open file 'WorldBotAPI.ex5'` / `loading ... failed` / `tester didn't start` — traced to a
missing shared library dependency; found and copied (read-only) from
`D:\Forex\...\BOT MOGUL Bundles\WorldBotAPI Library V10\WorldBotAPI.ex5` into
`D:\Meta 5b\MQL5\Libraries\`, then it loaded fine. Vendor inputs_raw converted verbatim from
`BOTMOGUL_CLAIMS.csv` into `.set` files under `_mt5_auto\ab_sets\bm091b_sets\` (one line per
`Name=Value`; the `TL_Stop_Level=20/5, 30/10, 40/15, 50/20` value kept as one raw string, unchanged).
All runs: EURUSD H1 Model 1, 2020.01.01-2022.12.31, deposit 10000, leverage 1:100, `D:\Meta 5b`
portable lane.

| ea_id | ex5 ran? | PF | net profit | eqDD% | trades | quality | survives bar? |
|---|---|---|---|---|---|---|---|
| 1-18-26 | ran (after lib fix) | 2.32 | +16,606.79 | 28.61% | 2151 | 99% | no (PF ok, eqDD 28.61% > 25%) |
| 1-16-31 | ran | 0.39 | -9,493.37 | 96.00% | 52 | 99% | no |
| 1-16-20 | **NO-RUN** | — | — | — | — | — | no |
| 1-16-23 | ran | 0.98 | -504.27 | 82.40% | 314 | 99% | no |
| 1-1-23 | ran | 0.10 | -5,685.96 | 65.69% | 55 | 99% | no |

**1-16-20 NO-RUN reason:** loaded and started fine (no library error), but the tester never produced
a report inside the script's 1800s (30min) timeout — `mt5_run.ps1`'s freeze-guard killed the
terminal64 process (CPU time was actively climbing throughout, so it was computing, not hung/idle).
Consistent with a no-SL/no-cap grid EA generating a runaway order count once it hits a trending
window outside its cherry-picked 2023 sample. Not re-attempted with a longer timeout per
foreground-synchronous / no-tuning instructions — recorded as-is.

All 4 EAs that produced a report fail the pre-registered bar; the 5th (1-16-20) could not complete
a run at all inside the timeout budget. Raw numbers only — no verdict issued (per order: Claude/lead
judges separately). `D:\Forex` untouched throughout (read-only; only .ex5/.ex5-library copies were
made out to the `D:\Meta 5b` lane).

---

### ORDER-091C batch-1/2 smoke RESULT (Claude-agent, 2026-07-11)

**Raw numbers only — no verdicts (per order, lead judges).** All tester/compile steps run synchronously
in the foreground, one EA at a time, per the four-agents-died-today rule.

**Part A — 091A coverage-gap close (`MT5 good` + `MT4 good`, 7 named source files):**
Reused `scripts/fxdreema_xray.py` `read_text()`/`parse_ea()` conventions in a small one-off script
(dedupe by content-hash vs the existing 1,592/1,598-row catalog, same as `order091a_intake.py`).
Gotcha confirmed: `EX140-...mq5` and `(OH) Recovery...` etc. use a **non-breaking space (U+00A0)**
inside the filename, not a regular space — `os.path.isfile()` on the naive path silently returned
False until located via `glob.glob()`. All 7 files decoded as real text (nul_ratio 0.00 for plain
MQL, 0.50 for BOM-less UTF-16 fxDreema exports — consistent with the 091A NUL-density heuristic,
no garbage).

| file | result |
|---|---|
| Dark_Gold_Full.mq5 | NEW-UNIQUE |
| EX140- Multi Group Scalping EA [Breakout strategy].mq5 | NEW-UNIQUE |
| EX197- Multi Group Scalping EA [Breakout FVG].mq5 | NEW-UNIQUE |
| ZigZag.mq4 (AlgoScalpPro EA\MQL4\Indicators) | DUP-existing (already in catalog — stock indicator sample) |
| Jum+StoCh+v2.5F.mq4 | NEW-UNIQUE |
| JUMSTOCH_FIXEDLOT.mq4 | NEW-UNIQUE |
| Lots ex1+4 1111 P m1.mq4 | NEW-UNIQUE |

**Part A total: 6 new-unique rows appended to `_triage\FXDREEMA_XRAY.csv`** (1,592 → 1,598), 1 dup
(ZigZag.mq4). Catalog concept column left blank for the 6 new rows per existing convention (concept
pass is separate). `.md` cards not appended this round — order only asked for the CSV.

**Part B — smoke-screen 5 candidates.** Copied out of read-only `D:\Forex` (untouched) with clean
ASCII filenames (source names carry the same U+00A0 gotcha) into `D:\Meta 5b\MQL5\Experts\c091c\`
(MT5) and `...\MQL4\Experts\c091c\` under the default MT4 data dir (MT5) and the default MT4 data
dir (MT4, `D:\Meta4` install). All 5 compiled **0 errors** (MetaEditor64 for MT5, metaeditor.exe for
MT4; only benign warnings — deprecated ACCOUNT_FREEMARGIN, double→int narrowing, unchecked return
values). No missing .ex4/.ex5/.dll dependencies — all 5 are single-file, zero `#include`/`#import`.

Symbol/TF: none of the 5 sources/headers name a specific market → **defaulted EURUSD H1** for all
per the FX-named fallback rule, except noted below. Baseline = 2023.01.01–2026.07.01, Model 1,
deposit 10000, leverage 1:100 (MT4 tester has no leverage override key — account-default only),
default compiled inputs. Flat-lot variant run only where the xray catalog already flags
`LOT_ESCALATION` (verified applied by reading the Inputs table back out of each .htm afterward).

**Pre-registered smoke bar (verbatim, not judged here): "baseline PF≥1.2 AND flat-lot PF≥1.0 →
clears to full funnel (ORDER-091C batch). ต่ำกว่านั้น = lead ตัดสิน rescue-ladder หรือ concept-mine."**

| EA | platform | symbol/TF (assumed) | baseline PF / net / DD% / trades | flat-lot PF / net / DD% / trades | clears bar? |
|---|---|---|---|---|---|
| JUMSTOCH_FIXEDLOT.mq4 | MT4 | EURUSD H1 | 1.18 / +1,730.55 / 8.51% / 7,052 | native (Fixed_Lot=0.01, Lot_mode=2 already default — no separate run) | NO (baseline PF 1.18 < 1.2, close) |
| (OH) Recovery Hedging System with SL V05.mq5 | MT5 | EURUSD H1 (XAUUSD tester profile also exists in the bundle, same date range — not run this pass) | 0.84 / -433.13 / 24.57% bal, 15.79% eq / 76 (90.79% losing trades) | not run (xray flag = SL_UNKNOWN only, no LOT_ESCALATION) | NO (PF 0.84, net negative) |
| (NuiIndy) Perfect Tri Arbitrage Any Symbols.mq5 | MT5 | EURUSD/GBPUSD/EURGBP triangle, H1 | 0.81 / -385.57 / 6.07% bal, 7.37% eq / 96 | **1.21 / +65,479.55 / 18.28% bal, 20.2–23.3% eq / 5,469** (Martingale 1.2→1.0) | NO by literal bar (baseline PF 0.81 < 1.2) — **flag for lead: flat-lot trade count jumped 96→5,469 and PF crossed 0.81→1.21, consistent with the default Martingale=1.2 multiplier causing lot sizes to blow through a broker/margin limit and silently choke order flow, not a normal "escalation adds risk" story — worth a second look before concept-mining away** |
| SMC V2.mq4 | MT4 | EURUSD H1 | 1.10 / +113.38 / 2.00% / 122 (81% win) | native (Lots=0.1 fixed, no escalation flag) | NO (baseline PF 1.10 < 1.2, close) |
| EX197- Multi Group Scalping EA [Breakout FVG].mq5 | MT5 | EURUSD H1 | 1.07 / +85.58 / 5.56% bal, 7.37% eq / 352 | 1.08 / +85.08 / 4.05% bal, 4.08% eq / 351 (Lot_plus_B/S 0.01→0) | NO (baseline PF 1.07 < 1.2; flat-lot near-identical to baseline — escalation isn't doing much either way at these small grid caps) |

**NO-RUN / COMPILE-FAIL: none.** All 5 compiled clean and produced a report on the first attempt
(no runaway timeouts, no missing libraries).

**None of the 5 clears the pre-registered smoke bar as written** (all fail on baseline PF < 1.2).
Two are close misses (SMC V2 1.10, JUMSTOCH_FIXEDLOT 1.18). The Tri-Arbitrage flat-lot divergence
(PF 0.81→1.21, trades 96→5,469) is flagged above as the one result worth a closer read before
any concept-mine/park call — raw numbers only, not a verdict.

### ORDER-091A RESULT (Claude-agent, 2026-07-11)

**Headline: catalog 1,050 → 1,592 unique EAs (+542)** · binary inventory 9,693 rows (6,627 unique
hashes) · attached report/set inventory 1,084 rows · full detail = `_triage\ORDER091A_COVERAGE.md`

| folder | files | src | bin | reports | new-unique src | dup-of-existing | unreadable |
|---|---|---|---|---|---|---|---|
| wait_Fxdreema MT5 | 293 | 151 | 142 | 0 | 26 | 124 | 0 |
| 3. ready to use | 182 | 38 | 103 | 0 | 1 | 37 | 0 |
| review EA\Jobot | 1,556 | 0 | 1,556 | 0 | 0 | 0 | 0 |
| BOT MOGUL Bundles | 9,686 | 3 | 2,905 | 711 | 1 | 2 | 0 |
| AI_GEN | 852 | 168 | 336 | 0 | 2 | 164 | 0 |
| Course jobot | 558 | 375 | 130 | 0 | 138 | 231 | 0 |
| 04_FxDreema_Learner | 247 | 221 | 7 | 0 | 213 | 7 | 0 |
| .Final EA | 6,857 | 189 | 4,514 | 373 | 161 | 14 | 0 |
| **TOTAL** | **20,231** | **1,145** | **9,693** | **1,084** | **542** | **579** | **0** |

**Finding สำคัญที่สุด (anomaly #1): encoding bug ไม่ใช่ path-coverage gap.** 374/542 ไฟล์ใหม่เป็น
UTF-16 LE **ไม่มี BOM** — `read_text()` เดิมจับ UTF-16 จาก BOM เท่านั้น → decode เป็นขยะ NUL-interleaved
→ regex ทุกตัว (รวม signature `fxdreema`) match ไม่ติด = **สาเหตุจริงที่ ORDER-074 กวาดทั้ง D:\ แล้ว
มองไม่เห็นไฟล์พวกนี้** · แก้แล้ว (NUL-density heuristic ใน `scripts/fxdreema_xray.py`), rollback pass แรก
แล้วรันใหม่ — หลังแก้ 374 ไฟล์นั้น parse เป็น fxDreema block card เต็มรูปแบบเป๊ะ ๆ (อีก 168 = hand-written/
AI-gen จริง ใช้ SL regex heuristic + flag `SL_HEURISTIC` กำกับ)

**Outputs:**
- `_triage\FXDREEMA_XRAY.csv` + `.md` — 542 rows/cards ใหม่ append (ของเดิม 1,050 ไม่แตะ · concept
  column ครบทุก row · กัน duplicate-concept-column bug ซ้ำใน `fxdreema_concepts.py` แล้ว)
- `_triage\ORDER091A_BINARIES.csv` — hash inventory .ex4/.ex5 (path/size/sha1/dedup/compiled-twin;
  433 ตัวมี source twin ชื่อเดียวกันข้างไฟล์) — feed Wave 3
- `_triage\ORDER091A_REPORTS.csv` — 711 BOT MOGUL .html + (.Final EA: 23 .html + 350 .set) — feed 091B/091C
- `_triage\ORDER091A_COVERAGE.md` — ตารางเต็ม + binary dedup + top-10 clusters + anomalies
- `scripts\order091a_intake.py` ใหม่ (walk เฉพาะ 8 โฟลเดอร์ rerun ได้) · `scripts\fxdreema_xray.py` แก้
  encoding + เพิ่ม SL heuristic สำหรับไฟล์ non-fxDreema (additive — card เดิมไม่เปลี่ยน)

**นับเทียบตัวเลข user: ตรงเกือบเป๊ะทุกโฟลเดอร์** — BOT MOGUL "~713 reports" = 711 html + 2 pdf ·
.Final EA "~389" = 23 html + 350 set + 16 pdf · ที่เหลือตรงตามประกาศ (คลาดมากสุด ±1)
**Top new clusters:** 04_FxDreema_Learner root (204) · .Final EA\. MQL5 (119) · Course jobot\! JOBOT Week (106)
· .Final EA\. MQL4 (31) — elliott deep-list หลัง merge = 154 hits (concept pass รันทับทั้ง 1,592 rows แล้ว)
**Spot-check ผ่าน (2 ไฟล์ fxDreema ใหม่):** `EX113 - Gold Robot Scalping [RSI Divergence].mq4`
(card hasSL=yes/esc=yes/NO_CAP ↔ grep เจอ `StopLossMode="dynamicLevel"` + `VolumeMode="martingale"`, ไม่มี cap) ·
`(CPT) ETA FixMoney NextRound 360s AT Vary TF.mq5` (card NO_SL/esc=yes ↔ grep เจอ `StopLossMode="none"`
ทั้ง 6 open block + lot formula 18 จุด)
**ห้ามที่รักษาไว้:** ไม่แตะ/ย้ายไฟล์ใต้ D:\Forex (read-only ตลอด) · ไม่มี verdict · ไม่มี backtest ·
BOT MOGUL อีก 2 copies ใต้ 50_KNOWLEDGE ไม่ scan (จดจำนวนไฟล์ 9,686 + 9,611 ใน coverage แทน — dedupe
จะยุบเป็นก้อนเดียวกันอยู่แล้ว)

---

## ORDER-083B — port NewsGuard เป็น MQL4 (คุมกอง no-SL บน MT4 141049900) — `DONE(Claude-agent, 2026-07-11)`

**ทำไม:** REVIEW ORDER-083 พบ gap — NewsGuard เป็น MQL5 คุมได้เฉพาะ MT5 แต่กองที่ต้องการ
CLOSE_ALL ที่สุด (Zeus magic 7777 + Kangaroo 1112-1115, ไม่มี SL) อยู่บน **MT4 141049900**

**Spec (logic เดิมจาก `ea_projects\(Boss)_NewsGuard\NewsGuard_Core.mqh` ทุกข้อ — port ไม่ใช่ redesign):**
1. สร้าง `ea_projects\(Boss)_NewsGuard\(Boss)_NewsGuard_MT4.mq4` — logic ports: position API →
   `OrdersTotal()/OrderSelect/OrderClose` loop กรองด้วย `OrderMagicNumber()` · timer 10s เดิม
   (MT4 build เก่าไม่มี OnTimer ใน tester → ใช้ OnTick + throttle เวลาเช็คทุก ≤10s ด้วย)
2. Input ชุดเดิมเป๊ะ: `GuardConfig` `"magic:policy;..."` (C/B/N) · `PreNewsMin=30` `PostNewsMin=15` ·
   `NewsFile="EA_LAB_news_week.csv"` · `ServerToBkkOffsetHours` — อ่านจาก **Common\Files** (MT4/MT5
   แชร์ Common เดียวกัน — ยืนยัน path จริงก่อน)
3. **B (BLOCK_NEW) บน MT4 = ใช้ไม่ได้กับ EA locked** (Zeus/Kangaroo เป็น .ex4 ไม่มี GV check) →
   validate config: เจอ B บนบัญชี MT4 ให้ Print เตือน + treat เป็น N · C กับ N ทำงานเต็ม
4. Fail-safe เดิมเป๊ะ: ไฟล์ข่าวหาย/เก่า >48h = ไม่ทำอะไร + Alert · ทุก action พิมพ์ journal `[NEWSGUARD]`
5. Tests: harness `.mq4` ตาม pattern NewsGuard_Test.mq5 — dummy orders หลาย magic ใน MT4 tester +
   fake news file → assert C ปิดถูก magic/ถูกเวลา · N ไม่แตะ · fail-safe ทำงาน · irrelevant ccy ไม่แตะ
6. Compile 0 errors / 0 warnings (MT4 metaeditor headless) · **ห้ามแตะไฟล์ MT5 เดิมทุกไฟล์**
**Acceptance:** .mq4 + .ex4 + test PASS table + คู่มือ attach diff จากฉบับ MT5 (สั้น) · commit
`[tag] ORDER-083B done` · **ห้าม:** attach จริง (user ทำเอง) · แตะ EA เดิมบนบัญชี · verdict

### ORDER-083B RESULT (Claude-agent, 2026-07-11)

**ไฟล์ (ทั้งหมดใหม่ ใน `ea_projects\(Boss)_NewsGuard\` — ไฟล์ MT5 เดิมไม่แตะแม้ตัวเดียว, mtimes ยัง 07-10):**
- `NewsGuard_Core_MT4.mqh` — logic port ทั้งก้อน (copy อิสระจาก NewsGuard_Core.mqh — sync มือถ้า MT5 เปลี่ยน)
- `(Boss)_NewsGuard_MT4.mq4` + `(Boss)_NewsGuard_MT4.ex4` — EA wrapper (OnTimer live + OnTick throttle)
- `NewsGuard_Test_MT4.mq4` — test harness (pattern เดียวกับ NewsGuard_Test.mq5 + case unlisted magic)
- `run_mt4_tests.ps1` — deploy→compile→tester→journal-grep รันซ้ำได้คำสั่งเดียว (MT4 lane ไม่มี tests dir กลาง
  เลยอยู่ใน project folder; ไม่แตะ ea_template\tests\run_tests.ps1)

**Compile (D:\Meta4\metaeditor.exe headless):** `(Boss)_NewsGuard_MT4.mq4` = **0 errors, 0 warnings** ·
`NewsGuard_Test_MT4.mq4` = **0 errors, 0 warnings**

**Common\Files ยืนยันแล้ว (spec ข้อ 2):** MT4 (`%APPDATA%\MetaQuotes\Terminal\Common`) เป็น junction
ชี้ก้อนเดียวกับที่ MT5 ใช้ (`D:\MetaTraderData\Roaming\MetaQuotes\Terminal\Common`) — พิสูจน์ด้วย probe file
เขียนผ่าน path นึงโผล่อีก path ทันที + `EA_LAB_news_week.csv` จาก daily chain มองเห็นจาก MT4 อยู่แล้ว
→ **ไม่ต้องเพิ่มบรรทัด copy ใน daily_monitor.ps1** (FILE_COMMON อ่าน CSV ก้อนเดียวกันทั้งสอง platform)

**Test results (run_mt4_tests.ps1: XAUUSD M5 Model 0, 2026.04.01, tester journal ยืนยันทุกข้อ):**

| assert | result | หลักฐาน journal |
|---|---|---|
| C ปิดถูก magic ถูกเวลา | **PASS** | window ENTER 03:30 ตรงนาที (event 04:00, pre 30) → ticket ของ magic C ตัวเดียวถูกปิดทันที |
| N + unlisted magic ไม่แตะ | **PASS** | magic N และ magic ที่ไม่อยู่ใน config เปิดค้างครบทั้ง run (นับก่อน/ใน/หลัง window) |
| irrelevant ccy ไม่ทำอะไร | **PASS** | NZD event ขณะถือแต่ XAUUSD → ไม่มี action ใน NZD window |
| fail-safe ไฟล์หาย | **PASS** | ลบ CSV → guard INACTIVE, ไม้ C ที่เปิดใหม่รอด 15 นาที, **Alert 1 ครั้ง** ไม่มีปิดไม้ |
| B → N downgrade + เตือน | **PASS** | parse "B" → `WARNING magic=…: policy B NOT available on MT4 … treating as N` + policy เก็บเป็น NONE + ไม้ B ไม่ถูกปิดใน window |
| unit (ParseTime 2 format · staleness 49h/1h · ccy↔symbol · ParseConfig ทิ้ง junk 3 token) | **PASS** | asserts ใน P0 ผ่านหมด |

**คู่มือ attach — diff จากฉบับ MT5 (ใช้คู่มือ ORDER-083 เป็นหลัก ต่างแค่นี้):**
1. **Policy B ห้ามใช้บน MT4** — EA บนบัญชีนี้เป็น locked .ex4 ไม่มี GV bridge → EA จะเตือน + treat เป็น N เอง
   · กอง no-SL ให้ใช้ **C**: แนะ `GuardConfig = "7777:C;1112:C;1113:C;1114:C;1115:C"`
2. Tester ไม่มี OnTimer → EA เช็คผ่าน OnTick (throttle ≤ TimerSeconds) ด้วย — live ใช้ timer 10s เหมือน MT5
   · ผลข้างเคียง: ช่วงตลาดเงียบไม่มี tick การเช็คอาจห่างกว่า 10s เล็กน้อย (timer ยัง fire ปกติบน live)
3. นาฬิกาใช้ `TimeCurrent()` (MQL4 ไม่มี TimeTradeServer) — ความหมายเดียวกันในทางปฏิบัติ
4. ไฟล์ข่าว: **ไม่ต้องตั้งอะไรเพิ่ม** — Common\Files ก้อนเดียวกับ MT5 (ยืนยันแล้วข้างบน) daily chain 07:30 เขียนให้แล้ว
5. เหมือนเดิมทุกข้อ: attach 1 chart/บัญชี บน terminal เทรดจริง (instance monitor ในแล็บเป็น investor password ปิดไม้ไม่ได้)
   · **ห้ามใส่ magic 0** (ไม้มือ user) · `ServerToBkkOffsetHours` เช็คใหม่หลัง DST · ทุก action มี `[NEWSGUARD]` ใน journal

**หมายเหตุ implementation (deviation เล็ก + เหตุผล):** (1) GV/BLOCK code ตัดออกทั้งก้อนจาก port
(B ถูก downgrade ตั้งแต่ parse → ไม่มีทางมี BLOCK state บน MT4 — ตาม spec ข้อ 3) (2) fake news CSV
ของ test เขียนแบบ non-common (tester sandbox `tester\files`) — จงใจ ไม่ให้ test แตะ
`EA_LAB_news_week.csv` จริงใน Common (3) test จำลอง stale ที่ระดับ `NG_IsStaleAge` เหมือนฉบับ MT5
(mtime ใน tester เป็นเวลาจริง ปลอมไม่ได้) — path ไฟล์หายเทสเต็ม flow จริง (4) CLOSE_ALL ปิดเฉพาะ
market orders (OP_BUY/OP_SELL) — pending ไม่แตะ ตรงพฤติกรรม MT5 (position API ไม่เห็น pending อยู่แล้ว)

---

## REVIEW ORDER-083B — `REVIEWED(Claude, 2026-07-11)` — ผ่าน

compile 0/0 ทั้งคู่ · test ครอบ assert ครบตาม spec รวม B→N downgrade + unlisted magic · deviation ทั้งหมด
สมเหตุผล (ตัด GV ทั้งก้อน = ถูกกว่า port dead code · pending ไม่แตะ = ตรง MT5 โดยเจตนา — ช่องนี้ปิดพร้อมกัน
สองแพลตฟอร์มใน ORDER-083C ข้อ 3) · **finding มีค่า: Common\Files MT4/MT5 บนแล็บ = junction ก้อนเดียว**
(daily chain เขียนครั้งเดียวเห็นทั้งคู่) — แต่ **terminal เทรดจริงอยู่ VPS = คนละเครื่อง ช่อง transport ยังอยู่**
(ORDER-083C ข้อ 7) · NewsGuard ทั้งสอง platform พร้อม attach หลัง 083C ปิด hardening

---

## REVIEW CODEX-AUDIT (`_triage\CODEX_AUDIT_FULL_2026-07-10.md`) — `REVIEWED(Claude, 2026-07-11)` — judge ทีละ finding, spot-check code/CSV จริงก่อนตัดสินทุกข้อที่สั่งแก้

**วิธีตัดสิน:** ยอมรับเมื่อหลักฐานบังคับ (ไล่เช็คไฟล์:บรรทัดที่ Codex อ้างเองทุกข้อสำคัญ) · โต้กลับพร้อมเหตุผลเมื่ออ่านบริบท/doctrine พลาด

### Layer A (live risk) — ยอมรับเกือบทั้งหมด นี่คือส่วนที่แรงและถูกที่สุดของ audit
| # | คำตัดสิน | เหตุผล + action |
|---|---|---|
| A1 dashboard ตาบอด floating | **ACCEPT (P0)** | เช็คแล้ว: `Compute-MagicMetrics` สร้าง DD จาก closed-deal series จริง — no-SL grid ชิด margin call ได้โดยจอเขียว → **ORDER-092** |
| A2 check_state เช็ค string ไม่ใช่ความจริง | **ACCEPT (P0)** | invariant ค้าง judge 2026-09-22/9EA/บัญชีเดียว ทั้งที่ reality = 5 บัญชี/judge 2026-10-09 → รวมใน **ORDER-093** (ห้ามแก้เฉพาะ checker — จะ warn ทุก commit จน doc sync ครบ) |
| A3 daily_monitor fail-open | **ACCEPT — แก้แล้ววันนี้** | เพิ่ม per-step exit-code + ห้าม publish gist เมื่อ dashboard fail + exit 1 ให้ LastTaskResult เห็นจริง |
| A4 relabel ไฟล์ stale เป็นวันนี้ | **ACCEPT — แก้แล้ววันนี้** | collect_live_deals เพิ่มด่านอายุ 30h: stale = SKIP+เตือน (rotation เขียนทุกคืน — เก่ากว่านั้น = exporter ตาย ต้องเห็น ไม่ใช่ซ่อน) |
| A5 magic เสี่ยงสุดไม่มีในแผนที่ | **ACCEPT — แก้แล้ววันนี้** | เพิ่ม 141049900: Zeus 7777 + Kangaroo 1112-1115 ลง cohort map พร้อม annotation no-SL/float-40%-manual |
| A6 concentration ต่อ failure domain | **ACCEPT (P0)** | ไม่มีตัวรวม XAU/USD exposure ข้ามบัญชี/VPS เดียว/broker เดียว → เข้า scope ORDER-092 (aggregate panel) + kill plan เข้า backlog |
| A7 RSI-MR ขัด doctrine บนเงินจริง | **ACCEPT (P0 — ตัดสินใจของ user)** | RSIMR_LOTLAW.csv ยืนยัน flat-lot PF 0.78/−588 → กำไรทั้งหมดมาจาก recovery sizing = ขัดหลัก 3 ชั้นที่จารึกเอง (no grandfathering) · **ข้อเสนอเด็ดขาด: ถอดจาก 159503454 → ย้ายไป demo isolate เป็น premium-track experiment เดี่ยว** (mechanism ยังมีค่า) — รอ user เคาะ |
| A-SUSPECT gist unlisted | ACCEPT (P1) | เลขบัญชี+P&L อยู่หลัง URL เดา-ยาก ไม่ใช่ private จริง → backlog: redact เลขบัญชี หรือย้าย private channel |

### Layer B (verdict integrity) — ครึ่งรับครึ่งโต้
| เคส | คำตัดสิน | เหตุผล |
|---|---|---|
| B1 ST03 "ปิดถาวร" เกินหลักฐาน | **PARTIAL ACCEPT** | จริง: Stage-2 spacing axis ประกาศไว้แต่ไม่ได้รัน (เช็ค taskboard แล้ว — รันแต่ gate) → แก้ record เป็น **"no edge under tested exits/gates; spacing = UNSWEPT"** + backlog probe 3 รันถูกๆ ปิดแกนให้สนิท · **แต่ verdict ถอดจากเงินจริงยืนเดิม** (flat-lot 0.68/0.40 ล้างพอร์ต 2 symbol ไม่ต้องรอ spacing) · บทเรียน process: pre-registered bar ต้อง commit ก่อนรัน ไม่ใช่มากับ result commit |
| B2 Boss 16 | **ACCEPT (สอดคล้องอยู่แล้ว)** | review เดิมก็จัด validation-only, spacing/TP unswept จดไว้แล้ว — ไม่มี action ใหม่ |
| B3 SuperTrend | **ACCEPT บางส่วน** | 56 trades บาง + OOS เคยใช้ select จริง → ห้ามโปรโมทด้วย score อย่างเดียว ต้องมี live/demo tracking (criterion 7) หรือ user เคาะเอง — สอดคล้อง REVIEW 085B ด้านล่าง (BWD ตกบาร์แล้วด้วย — คำถาม promotion ปิดไปเอง) |
| B4 Oracle "no entry edge" แรงเกินหลักฐาน | **ACCEPT (แก้ wording เท่านั้น)** | top-5 = 100.8% ของ net คือ **risk fingerprint ไม่ใช่ proof of no-edge** (static normalization ≠ flat-lot rerun เพราะ exit timing เปลี่ยน) · **verdict REJECT ยืนเดิม** — cap-key no-SL ก็พอฆ่าอยู่แล้ว ไม่พึ่ง claim นั้น |
| B5 Keltner/Ichimoku ปิดจาก Model-2 | **REJECT ส่วนใหญ่** | Codex อ่านทิศ bias ผิด: Model 2 = optimistic → **fail ใต้ Model 2 = ตายจริงยิ่งกว่า** (แพ้ทั้งที่ modeling เข้าข้าง) · ≥3-lever floor ใช้กับ "ตัวที่ผ่านเกณฑ์เบื้องต้น" — สองตัวนี้ไม่เคยผ่าน smoke ไหนเลยทั้ง 4 cell · ตัวที่ผ่าน Model-2 (ZSCORE) ก็ถูกส่ง Model-1 ladder ต่อ (ORDER-089) = process ถูกทิศแล้ว · **รับแค่ wording**: "ปิด = default-cell ของ class ที่เทส" ไม่ใช่ concept ตายสากล |
| B5 ZSCORE "full ladder" ไม่จริง | **REJECT** | R3 = N/A เพราะ EA ไม่มี filter inputs ให้ sweep (จดหลักฐานไว้แล้ว) — ladder ครบเทียบ lever ที่มีจริง ไม่ใช่ข้าม |
| B5 scorecard ค้าง CORE | **ACCEPT — แก้แล้ววันนี้** | ใส่ banner SUPERSEDED + verdict ทับ (ST_EA03 no-edge / Gold Reaper+LondonConso REJECT) เหนือตารางเก่า |

### Layer C (doctrine/docs)
| # | คำตัดสิน | เหตุผล |
|---|---|---|
| C1 ไม่มี single source of deployment truth | **ACCEPT (P0)** | 4 ที่ (PROJECT_STATE 0.5 / DEMO plan / scorecard / dashboard map) แก้มือแยกกัน → **ORDER-093**: inventory เดียว structured แล้ว generate ที่เหลือ |
| C2 EA-SCORE ให้สิทธิ์เงินจริงโดยไม่มี holdout/MC/n-min | **PARTIAL** | VERDICT GATE ข้อ 6 คุมอยู่แล้วแต่ rubric ไม่ได้ inline → เพิ่มบรรทัด hard-prerequisite ใน scorecard (ทำวันนี้) · ส่วน min-trade-count/CI = ข้อเสนอแก้ rubric ให้ user เคาะ (rubric เป็นของ co-design แก้เองไม่ได้) |
| C3 lever rule ไม่ consistent | **PARTIAL** | ตาม B5 — rule scope คือ prelim-passers; แต่ gate #1 เขียนกำกวมจริง → ชี้แจง scope ใน CLAUDE.md (แก้คำ ไม่เปลี่ยนกติกา) |
| C4 PROJECT_STATE mojibake | **ACCEPT (ยืนยันเอง: 16,359 จุด double-encode vs Thai แท้ 725 ตัว)** | ไฟล์เสียบางส่วนจริงระดับอ่านไม่ได้ → ORDER-093 sub-task ซ่อม (reverse cp1252→UTF8 เฉพาะบรรทัดเสีย + human verify ต่อ section ห้าม auto ทั้งไฟล์) |
| C5 backlog เก็บ Model-2 conclusion เก่าเป็นความจริง | **ACCEPT (P1)** | เพิ่ม SUPERSEDED marker — เข้า backlog hygiene |

### Layer D (automation/cages) — ยอมรับหมด ต่างแค่ลำดับ
| # | คำตัดสิน | action |
|---|---|---|
| D1 NewsGuard = zero live protection | **ACCEPT (P0-before-attach)** | จริงโดยโครงสร้าง: ยังไม่ attach + feed อยู่แค่เครื่องแล็บ แต่ terminal เทรดอยู่ VPS (Common junction ที่ 083B พบ = ในแล็บเท่านั้น) → **ORDER-083C** |
| D2 NewsGuard 7 ช่อง | **ACCEPT 5 / PARTIAL 2** | ยืนยันจาก code: restart-stuck GV จริง (clear ผูก `ng_blockSet` memory) · evCount==0 ยัง newsOK=true จริง · pending ไม่ถูก cancel จริง (MT4 port ตรงกันโดยเจตนา) · churn จริง · alert local-only จริง → เข้า 083C · flat-magic = ตาม spec ที่ user เคาะเอง (ไม่ใช่ bug — เพิ่ม option ได้) · DST = จดในคู่มือแล้ว + 083C auto-derive ด้วย TimeGMT() |
| D3 mt5_run stale dest | **ACCEPT (P1)** | ยืนยัน: ลบแต่ source-side + NO REPORT exit 0 → **ORDER-094** (ห้ามแก้ตอนมี batch in-flight) |
| D4 tpl_regression | **ACCEPT (P1)** | ยืนยัน: เช็ค dest existence + ไม่เทียบ eqdd + Boss 15/16 นอก cage + UpdateBaseline ไม่มี guard → ORDER-094 |
| D5 run_tests stale .ex5/journal | **ACCEPT (P1)** | ยืนยัน: `Test-Path .ex5` ผ่านทั้งที่ compile รอบนี้ fail + journal จับ log ใหม่สุด global → ORDER-094 |
| D6 deploy.ps1 ไม่ fail-closed | **ACCEPT (P1-สูง)** | compile fail ไม่หยุด + mirror .ex5 stale ไป lane2 ได้ → ORDER-094 (ต้องเสร็จก่อน deploy ครั้งหน้า) |

### Layer E (missing controls) → P0 = order แล้ว (092/093/083C) · P1+P2 เข้า MASTER_BACKLOG §CODEX-AUDIT ครบทุกข้อวันนี้

**หลักการที่ audit สอนแพงสุด (จดเป็น doctrine):** ทุกชั้นของระบบ fail ไปทาง optimistic ทิศเดียวกันพร้อมกันได้
(dashboard เขียว + checker CLEAN + task success + gist สด = โกหกพร้อมกันทั้งสี่ได้) — **cage ต้อง fail-visible เสมอ ไม่ใช่ fail-open**

---

## REVIEW ORDER-085B — `REVIEWED(Claude, 2026-07-11)` — SuperTrend: BWD ตกบาร์ / plateau ผ่านแท้ → คง PARKED-bench, เส้นทางที่เหลือ = demo tracking

**ตัดสินตามบาร์ pre-registered เป๊ะ:** (1) BWD 2020-22 **FAIL** — PF 0.88 < 1.0 (net −91.49/64t/eqDD 3.27%) ·
(2) plateau **PASS แท้** — 18/18 ไม่มี cell ขาดทุน (PF 1.90-3.40), default 2.93 มีเพื่อนบ้านประกบทุกแกน ไม่ใช่ peak
(peak จริง = ATR10×M3.5×SL2.0 ที่ 3.40 — **ห้าม chase**: default คือ center ที่ validate มา) · sanity เด่น:
Model-1 default reproduce Model-0 เป๊ะ (2.93/1691/4.85 vs 2.93/1690/4.85)
**ความหมาย:** criterion 4 (plateau) ✅ ปิดรูแล้ว · criterion 3 (both regimes) ❌ ตามบาร์ — แต่โปรไฟล์ตก =
"แพ้ตื้น ไม่ใช่ตาย" (−0.9% ใน 3 ปี trend-hostile, DD 3.27%) = regime-dependent แบบรอดข้ามหุบได้
**Verdict: EA-SCORE คง ~6-7/10 = bench ไม่ขึ้นเงินจริง** (เงื่อนไข 085 review บอก "ผ่านทั้งคู่" — ผ่านข้อเดียว) ·
สอดคล้อง CODEX-AUDIT B3 (56 trades บาง + no unused holdout) · **เส้นทางเดียวที่เหลือ = criterion 7:
attach demo (ศูนย์ต้นทุน) เก็บ live tracking ≥2 เดือน** — `_vps_deploy\ST_XAU_H4_live_v1.set` มีอยู่แล้ว
→ **PARKED-VERIFY(user): เสนอ user attach demo lane** · ห้าม re-tune ไปหา 3.40

---

## ORDER-092 — P0: Floating-risk telemetry (ตาบอด floating = รูใหญ่สุดของทั้งระบบ) — `DONE(Claude-agent, 2026-07-11)`

**ทำไม:** CODEX-AUDIT A1+A6 — dashboard เห็นแต่ closed deals · no-SL grid (Zeus/Kangaroo/RSI-MR) ตาย
ด้วย floating loss ที่มองไม่เห็น · ไม่มีตัวรวม exposure ข้ามบัญชี
**Spec:**
1. `AccountSnapshotExporter.mq5` (+`.mq4`): เขียน `EA_LAB_snapshot_<login>.csv` ลง Common\Files ทุก 60s:
   equity/balance/margin/free-margin/margin-level + ต่อ magic: floating P&L, lots รวม, จำนวนไม้,
   อายุไม้เก่าสุด, pending count · read-only (ห้ามมี trade function ใดๆ — pattern เดียว DealsExporter)
2. `collect_live_deals.ps1` เก็บ snapshot ด้วย (stale guard เดียวกัน) · `live_dashboard.ps1` เพิ่ม
   FLOATING RISK panel: ต่อบัญชี (equity vs balance, margin level, ระยะถึง stop-out) + ต่อ magic
   (float P&L, basket depth) + **aggregate แถวรวม: XAU exposure รวมทุกบัญชี / USD-event exposure** ·
   highlight ตาม threshold ของ cohort map · snapshot เก่า >26h = แถวเทา "STALE" (ห้ามโชว์เป็นสด)
3. Test: exporter ใน tester (harness เปิดไม้ dummy หลาย magic → assert คอลัมน์/ค่า) + dashboard unit
   บน CSV ปลอม · compile 0/0 ทั้งสอง platform
**ข้อจำกัดที่ต้องจดใน result:** เครื่องแล็บ rotation กลางคืน = snapshot ได้แค่รอบ rotation · real-time จริง
ต้องติดบน **VPS terminal** (user action — เขียน attach checklist + ทางขนไฟล์ VPS→แล็บใน result ให้ user เคาะ:
OneDrive folder = ทางเดียวกับ NewsGuard feed ขาไปใน 083C ข้อ 7)
**Acceptance:** ไฟล์ครบ + test PASS + dashboard render จาก CSV ตัวอย่าง + คู่มือ attach ·
commit `[tag] ORDER-092 done` · **ห้าม:** attach จริง · แตะ exporter เดิม · trade function

### ORDER-092 RESULT (Claude-agent, 2026-07-11)

**ไฟล์:**
- ใหม่ `tools\AccountSnapshot\AccountSnapshotExporter.mq5` — EA wrapper read-only (OnInit + timer 60s)
- ใหม่ `tools\AccountSnapshot\AccountSnapshot_Core.mqh` — logic ก้อนจริง (แชร์ให้ test harness แบบเดียว NewsGuard_Core)
- ใหม่ `tools\AccountSnapshot\AccountSnapshotExporter.mq4` — MT4 twin (single-file ตาม OrdersExporterMT4)
- ใหม่ `ea_template\tests\AcctSnapshot_Test.mq5` — tester assert harness (pattern NewsGuard_Test)
- แก้ `ea_template\tests\run_tests.ps1` — เพิ่มบรรทัด copy core mqh ไปข้าง deployed tests (additive)
- แก้ `scripts\collect_live_deals.ps1` — เก็บ `EA_LAB_snapshot_*.csv` เพิ่ม (section แยก, stale guard 30h เดิมไม่แตะ,
  exit code เดิมยัง key กับ deals exporter เป๊ะ — daily chain ที่เพิ่ง harden ไม่กระทบ)
- แก้ `scripts\live_dashboard.ps1` — FLOATING RISK panel เหนือ closed-deals sections
- exporter เดิม (DealsExporter.mq5 / OrdersExporterMT4.mq4) + daily_monitor.ps1 **ไม่แตะ** (ตามห้าม)

**CSV format:** `EA_LAB_snapshot_<login>.csv` ใน Common\Files, 18 คอลัมน์ 3 row type —
`ACCOUNT` (login/server_time/currency/equity/balance/margin/free_margin/margin_level%/stopout mode+level) ·
`MAGIC` ต่อ magic รวม magic 0 (float P&L รวม swap, lots รวม, จำนวนไม้, อายุไม้เก่าสุด ชม., pending count, symbols ที่ถือ) ·
`SYMBOL` ต่อ symbol (ให้ dashboard รวม XAU exposure ข้ามบัญชีได้ตรงๆ) ·
atomic: เขียน `.csv.tmp` แล้ว `FileMove(FILE_REWRITE)` — collector ไม่มีวันอ่านไฟล์ครึ่งเดียว; ถ้า move fail
(ปลายทางโดน lock) fallback เป็น rewrite-in-place พร้อม log (self-heal รอบ 60s ถัดไป — จดตาม spec)

**Compile:** `AccountSnapshotExporter.mq5` = **0 errors, 0 warnings** (D:\Meta 5\MetaEditor64.exe) ·
`AccountSnapshotExporter.mq4` = **0 errors, 0 warnings** (D:\Meta4\metaeditor.exe) ·
`AcctSnapshot_Test.mq5` (deployed) = **0 errors, 0 warnings**

**Test results:**

| test | result | หลักฐาน |
|---|---|---|
| MT5 tester harness (XAUUSD H1 Model 1, 2 magic + magic 0 + pending) | **PASS** | journal `[PASS] AcctSnapshot_Test: all asserts OK` — per-magic grouping (A=2 ไม้/0.03 lots, B=1 ไม้+1 pending, magic 0=1 ไม้), float ≠ 0 ขณะไม้เปิด, sum(magic float)==equity−balance, SYMBOL row 4 ไม้/0.05 lots, ACCOUNT row ครบ |
| no-trade-function static grep บน exporter ทั้ง 3 ไฟล์ | **PASS** | hit เดียวคือค่าคงที่ `OP_BUYLIMIT..OP_SELLSTOP` ใช้จำแนก pending (read-only) — ไม่มี OrderSend/CTrade/PositionClose ฯลฯ (trade call อยู่ใน test harness เท่านั้น ซึ่ง gate `MQL_TESTER`) |
| dashboard บน CSV ปลอม (fresh 1 บัญชี + stale 40h 1 บัญชี) | **PASS** | assert 20 ข้อผ่านหมด (รายละเอียดด้านล่าง) |
| dashboard regression: dir จริงไม่มี snapshot | **PASS** | "no snapshot data yet" โผล่, 5 account section เดิมครบ, ไม่มี STALE banner, exit 0 |
| collector: deals+snapshot / snapshot-only / stale / login=0 / TEST / .tmp | **PASS** | fresh snapshot ถูก copy, stale 40h SKIPPED-STALE, `_0`+`_TEST`+`.tmp` ถูกกรอง, snapshot-only case ยังเก็บ snapshot แล้ว exit 1 ตาม deals guard เดิม |

**Dashboard screenshot-in-words (จาก CSV ปลอม):** ใต้ legend เห็น card "⚠️ FLOATING RISK — open baskets / margin
(snapshot exporter, ORDER-092)" → บัญชี 159503454 (fresh): "equity 9,754.40 vs balance 10,062.25 USD · floating
-307.85 (แดง) · margin level 342.4% (เหลือง — เกณฑ์ เขียว>500 / เหลือง 200-500 / แดง<200) · distance to stop-out:
312.4 pp above stop-out (30.0%)" + ตาราง magic เรียงขาดทุนมากขึ้นก่อน: Zeus 990101 float −310.20 / 0.12 lots /
basket depth 6 / oldest 43.7h / pending 2, RSI-MR 990103 +12.35, "manual trades (magic 0)", และ magic 555 =
"⚠️ UNMAPPED — not in cohort map" แถวเทา → บัญชี 141049900 (ไฟล์อายุ 40h): การ์ดทั้งใบจางเป็นเทา + แถบ
"STALE — snapshot from 2026.07.09 23:10:00 server time (40.0 h old > 26 h) — NOT current data" → ตาราง aggregate:
"Total XAU-symbol exposure 0.12 lots · floating −310.20" (XAUUSDc ของบัญชี stale **ไม่ถูกนับ** — นับเฉพาะ fresh)
+ "Total floating P&L (all accounts) −307.85" + แถว Coverage บอกว่าบัญชีไหน fresh/EXCLUDED stale ·
closed-deals sections เดิมอยู่ใต้ panel ครบทุกอย่างเหมือนเดิม

**(a) ข้อจำกัดเครื่องแล็บ:** monitor rotation = login investor-mode สั้นๆ ตอนกลางคืนเท่านั้น → snapshot จากแล็บ
คือ "ภาพนิ่งคืนละครั้ง" ไม่ใช่ near-real-time — floating ตอน 10 โมงเช้ายังมองไม่เห็นจนกว่า exporter จะไปนั่งบน
**VPS trading terminal ที่เปิดตลอด** (user action — lab ห้าม attach เองตามข้อห้าม order นี้)

**(b) Attach checklist (VPS, ต่อ terminal ละ ~3 นาที):**
1. copy `AccountSnapshotExporter.ex5` (MT5) หรือ `.ex4` (MT4) จาก `tools\AccountSnapshot\` ไป
   `MQL5\Experts\` / `MQL4\Experts\` ของ terminal นั้น แล้ว refresh Navigator
2. เปิดชาร์ตใหม่ 1 ใบ symbol ไหนก็ได้ (แนะนำ TF สูงๆ ลด tick noise — EA ใช้ timer ไม่ใช้ tick) —
   **ชาร์ตเดียวต่อ terminal พอ** ห้ามลากทับชาร์ตที่ EA จริงนั่งอยู่
3. ลาก exporter ลงชาร์ต → tab Common: เช็ค "Allow Algo/Auto Trading" **ไม่จำเป็น** (EA read-only ไม่มี trade call)
   แต่ terminal-level AutoTrading ปิดไว้ก็ยังทำงาน (timer + file API ไม่โดน block)
4. ยืนยันใน Experts log: `[SNAP] n magic row(s) ... -> Common\Files\EA_LAB_snapshot_<login>.csv` ทุก 60s
   และไฟล์โผล่ใน `<Common>\Files` ของเครื่องนั้น (login ต้องไม่ใช่ 0)
5. เช็คว่า chart อยู่ใน profile ที่ terminal โหลดตอน restart (กัน VPS reboot แล้ว exporter หาย)

**(c) VPS→lab transport (เสนอให้ user เคาะ — ช่องเดียวกับ NewsGuard feed ขาไปใน ORDER-083C ข้อ 7):**
ติด OneDrive บน VPS แล้วให้ scheduled task เล็กๆ (xcopy ทุก 5 นาที) copy `EA_LAB_snapshot_*.csv` จาก
`<Common>\Files` → โฟลเดอร์ OneDrive ที่ sync ลงเครื่องแล็บ; ฝั่งแล็บชี้ `collect_live_deals.ps1 -CommonFiles
<OneDrive path>` (param มีอยู่แล้ว ไม่ต้องแก้ code) หรือเพิ่ม path ที่สองใน daily chain ทีหลัง — ขาไป (news feed)
ใช้โฟลเดอร์เดียวกันกลับทิศ ตาม 083C · ทางเลือกถ้าไม่อยาก OneDrive เต็ม VPS: `rclone` + cloud drive
เดิมที่ user มี — แต่ OneDrive ชนะเพราะ 083C ต้องใช้ช่องนี้อยู่แล้ว

---

## ORDER-093 — P0: Deployment truth เดียว + ซ่อม PROJECT_STATE encoding — `DONE(Claude, 2026-07-11)` — inventory+checker+0.5 repoint+encoding ครบ 4 ข้อ

**ทำไม:** CODEX-AUDIT A2+C1+C4 — ความจริง deploy กระจาย 4 ที่แก้มือ, checker เช็ค string ค้างยุค 06-22,
PROJECT_STATE double-encode 16k จุด
**Spec:** (1) สร้าง `portfolio\DEPLOYMENTS.csv` (structured: account/type/platform/host/EA/magic/set-hash/
status/kill-rule/judge-date/owner) จาก DEPLOYMENT REALITY 2026-07-09 — นี่คือ inventory เดียว
(2) `live_dashboard.ps1` cohort map + `check_state.ps1` invariants generate/validate จากไฟล์นี้
(checker เปลี่ยนจาก "string มีอยู่" → "ทุก doc ไม่ขัดกับ inventory") (3) PROJECT_STATE §0.5 ชี้มาที่
inventory แทน hardcode (4) ซ่อม mojibake: script reverse cp1252→UTF8 เฉพาะบรรทัดเสีย + human verify
ต่อ section + commit ซ่อม encoding แยกไม่ปนไฟล์อื่นเพื่อ diff สะอาด **Acceptance:** check_state ผ่านกับ reality ใหม่ ·
PROJECT_STATE อ่านออก 100% · commit `[tag] ORDER-093 done`

---

## ORDER-083C — P0-before-attach: NewsGuard hardening (MT5+MT4) + VPS transport — `DONE(Codex, 2026-07-11 — รอ Claude review เมื่อ quota กลับ)` (user เปิด Codex lane กลับมา — สั่งตรง)

> **CODEX CONTINUATION NOTE (2026-07-11):** user สั่งให้ Codex เดินงานนี้ต่อระหว่างที่ Claude quota หมด และให้ใช้ sub-agent ประหยัด token · แบ่ง scope เป็น MT5 / MT4 / transport-doc คนละไฟล์ โดย Codex หลักรวมงาน รัน cage ทำ independent code review และ commit · **Claude กลับมาให้เริ่มจาก REVIEW ORDER-083C commit/result ใต้หัวข้อนี้ ไม่ต้องเริ่ม implementation ซ้ำ** · ระหว่างนี้ Codex จะวาง dependency plan ของ ORDER-076/080/081/082/091 แต่ไม่เปลี่ยน verdict/direction แทน Claude

**ทำไม:** CODEX-AUDIT D1+D2 — ช่องยืนยันจาก code แล้ว 5 ช่อง + feed ยังไปไม่ถึง VPS = attach ตอนนี้คุ้มครองศูนย์
**Spec (ทุกข้อมี test ประกบ, แก้ทั้ง NewsGuard_Core.mqh และ NewsGuard_Core_MT4.mqh ให้ตรงกัน):**
1. **Restart reconcile:** ทุก pass ถ้า GV `NEWSGUARD_BLOCK_<magic>` มีอยู่แต่คำนวณแล้วไม่ควร block → ลบทิ้ง
   (เลิกผูกกับ `ng_blockSet` memory — MT5 เท่านั้น, MT4 ไม่มี GV)
2. **Empty-feed fail-safe:** parse จบแล้ว `ng_evCount==0` → `ng_newsOK=false` + Alert (สัปดาห์ที่ไม่มีข่าว
   high-impact เลยไม่มีจริง — 0 event = feed พัง)
3. **Pending cancel:** policy C ลบ pending orders ของ magic นั้นในหน้าต่างข่าวด้วย (ladder GTC ตั้งก่อนข่าว
   trigger ในหน้าต่างได้) — ทั้งสอง platform
4. **Churn guard:** นับ re-close ต่อ window; เกิน 5 → Alert "owner EA re-entering during news window"
5. **Offset auto-check:** MT5 คำนวณ server-GMT ด้วย `TimeTradeServer()-TimeGMT()` เทียบ input; mismatch →
   Alert + ใช้ค่าคำนวณ (input = override) · MT4 ทำเท่าที่ API ให้ (จด limitation)
6. **Remote alert:** Alert สำคัญยิง `SendNotification` ด้วย — MQID ไม่ตั้ง = Print เตือนตอน init
7. **VPS transport:** เขียนขั้นตอน OneDrive folder VPS↔แล็บ (ขาไป: news CSV → VPS Common\Files ·
   ขากลับ: exporter/snapshot CSV → แล็บ) + attach checklist ต่อ terminal (ห้าม magic 0 ย้ำ) — user ทำมือ
**Acceptance:** tests PASS ครบทั้ง 2 platform + tpl_regression CLEAN + transport doc ·
commit `[tag] ORDER-083C done` · **ห้าม:** attach จริง · เปลี่ยน policy semantics ที่ user เคาะ (flat-magic scope คงเดิม)

### ORDER-083C RESULT — Codex + sub-agents, 2026-07-11 (ช่วง Claude quota หมด; raw evidence, no verdict)

**Implementation:** MT5 แก้ restart reconciliation จาก persistent GV จริง, empty-feed fail-safe, policy C ยกเลิก pending,
churn guard ที่นับเฉพาะการเปิดกลับ **หลังเคย flat แล้ว** (initial basket >5 ไม่ false-alert), `SendNotification`
fallback, auto server/GMT offset ที่ re-check ทุก feed reload + manual override · MT4 ทำ parity เท่าที่ API อนุญาต
(offset เป็น advisory/manual override, B→N เดิม) · operator state แสดง `ARMED/INACTIVE` ตรง feed จริง

**Tests หลัง independent two-axis review แล้วแก้ finding:**
- MT5 `ea_template\tests\run_tests.ps1` = **ALL 5 PASS**; NewsGuard test ครอบ stale-GV restart, zero-event +
  local/remote alert attempt, pending cancel, >5 true re-entry churn, offset valid/fallback
- MT4 `run_mt4_tests.ps1` = **PASS**, compile wrapper+harness **0 errors/0 warnings**, fail-safe alerts 3,
  B→N warning 1, churn alerts 2, pending deletes 1; runner bind journal เฉพาะ current run
- `(Boss)_NewsGuard.mq5` direct compile = **0 errors/0 warnings**
- `scripts\tpl_regression.ps1` = **CLEAN 4/4**

**Transport/user action (ยังไม่ได้ attach ตามข้อห้าม):** คู่มือ `ea_projects\(Boss)_NewsGuard\VPS_TRANSPORT_AND_ATTACH.md`
กำหนด OneDrive สองทิศ, atomic copy/freshness, scheduled tasks, rollback, secrets, attach ต่อ terminal และห้าม magic 0
· production MT5 ใช้ auto-offset default; MT4 ใช้ manual override · user ยังต้องติดตั้ง/attach บน VPS เอง

**Claude-return note:** review commit `[codex] ORDER-083C done`; implementation/test ปิดแล้ว ไม่ต้องทำซ้ำ ·
ผู้ตัดสิน deployment/attach ยังคงเป็น Claude/user

---

## ORDER-094 — P1: Cage hardening (ปิดทาง stale-pass ทั้ง 4 ตัว) — `DONE(Claude-agent, 2026-07-11)`

**ทำไม:** CODEX-AUDIT D3-D6 ยืนยันครบ — cage ที่ pass ได้ทั้งที่หลักฐาน stale = อันตรายกว่าไม่มี cage
**Spec:** (1) `mt5_run.ps1`: ลบ dest report เก่าก่อนรัน + exit 0/1 ตามมี report จริง (2) `tpl_regression.ps1`:
เทียบ eqdd ด้วย + เพิ่ม Boss_15/16 เข้า expert list + `-UpdateBaseline` ต้องพิมพ์ diff เก่า/ใหม่ + confirm flag
(3) `ea_template\tests\run_tests.ps1`: ลบ .ex5 เก่าก่อน compile (compile fail = COMPILE-FAIL จริง) + จับ journal
เฉพาะ run ของ test นั้น (bind กับ ReportName/เวลา start) (4) `ea_template\deploy.ps1`: compile error → exit 1 +
ห้าม mirror lane2 เมื่อ compile fail + ลบ .ex5 เก่าก่อน compile **Acceptance:** ทุก script มี negative-test
พิสูจน์ fail-closed (จำลอง compile พัง/report หาย → ต้องแดง) · re-baseline พร้อม eqdd + Boss15/16 ·
commit `[tag] ORDER-094 done` · **ห้าม:** เปลี่ยน semantics การรันปกติ

### ORDER-094 RESULT (Claude-agent, 2026-07-11)

**Per-script changes (failure-path only — normal-run output text/behavior untouched per ห้าม):**

1. `scripts\mt5_run.ps1` (D3)
   - Pre-launch cleanup now also deletes the DESTINATION report `_mt5_auto\reports\<ReportName>*` (was: source-side DataDir only). A run that produces no fresh report can no longer leave last run's .htm as false evidence for downstream `Test-Path` readers.
   - Explicit exit codes: `OK REPORT:` → exit 0 · `NO REPORT`/timeout → exit 1 (was: always fell through to exit 0). Output text byte-identical; existing exit 2 abort paths untouched; freeze-guard/priority/affinity/timeout-kill untouched.
2. `scripts\tpl_regression.ps1` (D4)
   - Compare now includes `eqdd` (was: net/pf/trades only).
   - Expert list extended with `Boss_15_ST03` + `Boss_16_KangarooGrid` (both compile 0/0). Boss_16 runs a pinned set override (`ea_template\sets\Boss16_Kangaroo_XAU_smoke.set` — the frozen ORDER-072 smoke set) same pattern as Boss_14; Boss_15 compiled defaults trade fine on the window (216 trades) so no override needed.
   - `-UpdateBaseline` alone = DRY RUN: prints old-vs-new diff table, does NOT write, exit 1. Writing requires `-UpdateBaseline -ConfirmBaseline`.
3. `ea_template\tests\run_tests.ps1` (D5)
   - Deletes the target `.ex5` BEFORE each compile → a failed compile is COMPILE-FAIL for real (stale binary can't answer `Test-Path`).
   - Journal verdict bound to THIS run: `$runStart` captured before invoking mt5_run; only journal files with `LastWriteTime -gt $runStart` accepted; no fresh log = new red verdict `NO-FRESH-LOG` (never a stale-log PASS).
4. `ea_template\deploy.ps1` (D6)
   - Deletes old `.ex5` before compiling each target.
   - Parses each compile log's `Result:` line — any errors (or missing Result line / missing log / missing .ex5) → `** COMPILE FAIL **` flagged, and after ALL targets reported: exit 1.
   - Lane-2 mirror skipped entirely when any compile failed (stale/broken binary can't reach oc-btest lane).

**Negative-test evidence (all throwaway files deleted after capture; no real EA touched):**

| # | Script | Simulation | Observed | Exit |
|---|---|---|---|---|
| N1 | mt5_run.ps1 | bogus expert `EALabTpl\NoSuchExpert_ZZ094` | `NO REPORT (exited=True)...` | 1 |
| N2 | mt5_run.ps1 | planted stale dest `NEGTEST_STALE.htm` + bogus expert | stale report deleted (`Test-Path` = False after run), `NO REPORT` | 1 |
| N3 | run_tests.ps1 | throwaway `ZZNegativeCompileTest.mq5` with broken syntax | `ZZNegativeCompileTest COMPILE-FAIL` · `=== TESTS: 1 not passing ===` (real 5 still PASS) | 1 |
| N4 | run_tests.ps1 (stale-.ex5 kill shot) | step 1: valid version compiled → real .ex5 on disk; step 2: broke the source, re-ran | COMPILE-FAIL again + `.ex5` gone after failed recompile (pre-fix this was a stale PASS) | 1 |
| N5 | deploy.ps1 | throwaway `ZZNegativeDeployTest.mq5` (broken) added to targets temporarily | `Result: 14 errors` parsed → `** COMPILE FAIL **` ×2 · `skip lane2 mirror: compile failure(s) this run` · `=== DEPLOY: compile failure(s) ===` | 1 |
| N6 | tpl_regression.ps1 | `-UpdateBaseline` WITHOUT `-ConfirmBaseline` | full diff table printed, `=== BASELINE NOT WRITTEN - re-run with -UpdateBaseline -ConfirmBaseline ===`, baseline file untouched | 1 |

(tpl_regression's missing-report path rides on N1/N2: mt5_run now guarantees no stale dest .htm, so the existing `Test-Path → [FAIL] no report → exit 1` line is fail-closed for real.)

**New regression baseline (XAUUSD H1 2024.01.01-2024.07.01 Model 1, written via `-UpdateBaseline -ConfirmBaseline`):**

| ea | net | pf | trades | eqdd |
|---|---|---|---|---|
| Boss_11_GridTrend | 607.98 | 1.43 | 168 | 305.11(2.86%) |
| Boss_12_Breakout | -140.81 | 0.88 | 164 | 255.19(2.54%) |
| Boss_13_MeanRev | -885.51 | 0.91 | 107 | 3040.40(25.01%) |
| Boss_14_GridLog (pinned set) | 589.82 | 16.72 | 56 | 153.50(1.50%) |
| Boss_15_ST03 (compiled defaults) | -39.62 | 0.86 | 216 | 64.49(0.64%) |
| Boss_16_KangarooGrid (pinned set Boss16_Kangaroo_XAU_smoke) | 507.72 | 3.44 | 73 | 421.04(4.07%) |

Boss_11-14 rows identical to the pre-094 baseline (proof the harness changes altered zero tester behavior). Boss_15 losing on this window is EXPECTED (edge unproven per its header — the baseline pins behavior, not profitability).

**Positive path (final proof, both fresh full runs):**
- `scripts\tpl_regression.ps1` → 6/6 `[OK] ... matches baseline` → `=== REGRESSION CLEAN ===` exit 0
- `ea_template\tests\run_tests.ps1` → 5/5 PASS → `=== ALL TESTS PASS ===` exit 0

**Deviation note:** run_tests journal binding uses run-start timestamp filter (only logs with LastWriteTime after this run started, newest first) rather than parsing a specific agent-folder log path — same guarantee (a verdict can only come from a journal written during/after THIS run), simpler than tracking which Agent-127.0.0.1-300x folder the tester picked.

---

## REVIEW ORDER-092 — `REVIEWED(Claude, 2026-07-11)` — ผ่าน · P0-A1/A6 ฝั่ง build ปิดแล้ว เหลือฝั่ง attach (user)

compile 0/0 ทั้ง 3 ไฟล์ · test PASS ครบ (รวม assert เด็ด: sum(per-magic float) == equity−balance · aggregate
ไม่นับบัญชี stale · no-trade-function grep สะอาด) · lead verify ซ้ำ: รัน live_dashboard.ps1 จริงกับ data 5 บัญชี
= exit 0, render ปกติ, path "no snapshot data yet" ทำงาน · deviation ทั้ง 4 สมเหตุผล (snapshot เก็บก่อน deals
guard = VPS ที่มีแต่ snapshot exporter ก็เก็บได้, exit-code contract เดิมไม่แตะ · SYMBOL row ทำให้ XAU aggregate
แม่นกว่า spec)
**เหลือให้ user (บันทึกใน RESULT block แล้ว):** attach AccountSnapshotExporter บน VPS terminal ทั้ง 5 →
จนกว่าจะ attach dashboard ยังเห็น floating เฉพาะรอบ rotation กลางคืนของเครื่องแล็บ · ทางขน OneDrive
VPS↔แล็บ = อันเดียวกับ ORDER-083C ข้อ 7 เคาะทีเดียวได้สองงาน


---

## REVIEW ORDER-083C — `REVIEWED(Claude, 2026-07-11)` — ผ่าน · NewsGuard พร้อม attach แล้วทั้ง 2 platform (เหลือ user ลงมือ)

**Verify อิสระโดย lead (กัน stale-pass เพราะ cage D5 ยังไม่แก้จนกว่า 094 จบ):** รัน `run_tests.ps1` ใหม่เองทั้งชุด
= **ALL 5 PASS สด** (AcctGate/AcctSnapshot/NewsGuard/Persist/StackStep) + compile 0/0 ทั้ง 7 template EA ·
อ่าน diff จริง: ทั้ง 7 ข้อ implement ถูกจุด — เด่นสุด (1) restart reconcile เปลี่ยนจากเช็ค memory flag เป็นเช็ค
GV จริงทั้ง fail-safe path และ window-exit path = ช่อง stuck-GV ปิดสนิท (2) churn guard มี `ng_seenFlat`
กันนับตะกร้าแรกเป็น re-entry (false alert ที่เจอตอน Codex review ภายใน — แก้ถูกทาง) (3) empty-feed →
INACTIVE + alert ตามสั่ง (4) pending cancel ครอบ 6 ชนิด magic-scoped retry-next-pass
**สถานะ NewsGuard ตอนนี้:** code+test ครบทั้ง MT5/MT4 · เหลือ **user ลงมือตาม
`ea_projects\(Boss)_NewsGuard\VPS_TRANSPORT_AND_ATTACH.md`** (OneDrive สองทิศ + attach ต่อ terminal) —
เป็นชุดเดียวกับ AccountSnapshotExporter (ORDER-092) ทำทีเดียวจบสองงาน · จนกว่าจะ attach = คุ้มครองยังเป็นศูนย์
(ตาม audit D1 — ห้ามเข้าใจว่าเสร็จแล้วปลอดภัยแล้ว)

---

## REVIEW ORDER-081 — `REVIEWED(Claude, 2026-07-11)` — งาน research ผ่าน · คำแนะนำทิศทาง: **PARK crypto lane**

**คุณภาพ:** ครบ scope ทุกข้อ ไม่ล้ำข้อห้าม (ไม่มีบัญชี/API/code) · แหล่ง primary + effort estimate สมจริง
**สาระที่ชี้ขาด (จุดที่ต้องบอกตรง ๆ):** สมมุติฐานตั้งต้นจากโพสต์ FB — "maker rebate scalper" — **ถูกหักล้าง**:
ไม่พบ retail maker rebate ถาวรที่ไหนเลย (Binance ที่เจอ = โปรโมชัน LP 14 วัน symbol เดียว) · Bybit VIP0
maker-maker round trip = **4 bps ก่อน funding/adverse selection** = เกม HFT-lite ที่ต้องพิสูจน์ queue-fill
ด้วย L2 data + engineering 92-168 ชม. ก่อนจะตัดสินใจลงเงินได้เลย
**คำแนะนำเด็ดขาด (scenario จริง):** เวลา 92-168 ชม. = เท่ากับล้างคิว ORDER-091 ทั้งคลัง ~10k ไฟล์ที่ prior
สูงกว่ามาก → **PARK** · เงื่อนไข un-park ข้อเดียว: user มีบัญชีจริง + ส่งหน้า fee page มายืนยัน F1 แล้วอยากลอง
checkpoint แรก 18-32 ชม. (bar probe ใต้ fee โหดสุด — ฆ่าไอเดียถูก ๆ ได้ก่อนสร้างอะไรใหญ่) · ไม่มี rebate
= ไม่มีเหตุให้รีบ


---

## REVIEW ORDER-094 — `REVIEWED(Claude, 2026-07-11)` — ผ่าน · cage ทั้ง 4 fail-closed แล้ว (audit D3-D6 ปิดครบ)

**Verify อิสระโดย lead:** อ่าน diff mt5_run (minimal ตรง spec, output text เดิมทุกตัวอักษร) + รัน negative test
เองซ้ำ: bogus expert + วางไฟล์ stale ปลอมที่ dest → **exit 1 + stale ถูกลบจริง** · หลักฐาน agent ครบ:
negative 6 เคสแดงหมด · baseline ใหม่ Boss_11-14 ตรงของเดิมเป๊ะ (พิสูจน์ว่าแก้ harness ไม่แตะ behavior)
+ Boss_15/16 เข้า cage แล้ว (15 ติดลบบน window = ปกติ, baseline ตรึง behavior ไม่ใช่กำไร — เหตุผลถูก) ·
REGRESSION CLEAN 6/6 + ALL TESTS PASS 5/5 สด · deviation (journal bind ด้วย run-start timestamp แทน
resolve Agent folder) = การันตีเดียวกัน รับได้
**ผลรวมวันนี้: CODEX-AUDIT Layer D ปิดครบทุกข้อ (D1-D6)** — เหลือ Layer A/C ฝั่ง user-action (attach) + ORDER-093


---

### ORDER-093 RESULT (Claude lead, 2026-07-11) — sub-tasks 1-3 DONE → order ปิดครบ

**(1) Inventory เดียว:** `portfolio\DEPLOYMENTS.csv` — 29 แถว / 5 บัญชี / 27 magic + 2 แถว UNVERIFIED
(159475669 user-mix ที่ magic ยังไม่ enumerate + ClevrFX บน 69424711 — จะ enumerate จาก AccountSnapshot
exporter หลัง user attach บน VPS) · สถานะวันนี้ฝังในแถว: PENDING_REMOVE (RSI-MR + ST03 family ตามที่
user เคาะ) · PENDING_ATTACH (SuperTrend 990020)
**(2) Checker rewrite:** `check_state.ps1` เลิกเช็ค string ค้างยุค 06-22 → validate จาก CSV จริง 13 ด่าน:
parse/columns/dup-magic + ทุกบัญชีอยู่ใน DEMO plan + **dashboard map ↔ CSV สองทิศ (27/27)** (แถวไม่มีใน map
= magic ไม่ถูก monitor · map ไม่มีใน CSV = ghost) + judge dates + entry-claim + banners · **negative-test แล้ว:
ghost map row ปลอม → -Strict exit 1 · ถอน → CLEAN** (fail-visible doctrine) · gotcha ที่เจอ: PS ตัวแปร
case-insensitive — `$inv` data ชน `$INV` path ต้องใช้ `$rows`
**(3) §0.5 repoint:** ตาราง fact-owner แยก data (CSV) / narrative (DEMO plan) + INVARIANTS block เก่า
(9 EA·1 account·judge 09-22·magic map มือ) แทนด้วย pointer → CSV — คำอธิบาย hook อัปเดตตามพฤติกรรมใหม่
**(4) encoding:** ปิดไปแล้วเมื่อรอบก่อน (commit 1e86479)
**Anomaly ยกให้ user:** พบไฟล์ `EA_LAB_deals_146237_20260710.csv` ใน live_deals — **บัญชี 146237 ไม่อยู่ใน
DEPLOYMENT REALITY 5 บัญชี** (exporter เคยยิงจาก login นี้เมื่อไหร่? บัญชีอะไร?) — inventory ยังไม่ใส่ รอ user ระบุ


---

## REVIEW ORDER-091A — `REVIEWED(Claude, 2026-07-11)` — ผ่าน · คลังโต 1,050 → 1,592 unique · root-cause coverage gap เจอแล้ว

**Verify โดย lead:** นับจริงตรงทุกไฟล์ — XRAY 1,592 แถว / concept ครบ 1,592 / binaries 9,693 / reports 1,084 ·
spot-check 2 ไฟล์ใหม่ vs grep = ตรง · coverage ตรงตัวเลขที่ user ประกาศแทบเป๊ะ (BOT MOGUL 711+2, Final EA 23+350+16)
**Finding ที่มีค่าที่สุดของ order นี้ = root cause ว่าทำไม ORDER-074 กวาดไม่เจอ:** ไฟล์ 374 ตัวเป็น
**UTF-16 LE ไม่มี BOM** — parser เดิม decode เป็นขยะ NUL-interleaved จน signature match ไม่ได้เลย →
แก้ด้วย NUL-density heuristic ใน `read_text()` แล้ว rollback+rerun (process ถูกต้อง: agent จับ empty-card
เองจาก blocks=0 บนไฟล์ 10k บรรทัด) · บทเรียนเดียวกับ mojibake PROJECT_STATE วันนี้ = **encoding คือ
silent-failure ชั้นใหญ่ของ corpus นี้** — intake ทุก wave ถัดไปต้องสงสัย encoding ก่อนสรุปว่า "ไม่มี/ไม่เจอ"
**พร้อมสำหรับ Wave 1:** 091B มี input ครบแล้ว (`ORDER091A_REPORTS.csv` 711 BOT MOGUL html) ·
091C มี `.Final EA` 161 new-unique + 350 set แนบ · **คิวพรุ่งนี้ตาม pacing: 091B ก่อน** (parse claim →
คัด top → BWD spot-kill ทีละ 5 — ห้ามเชื่อ vendor report ตาม memory wobr-botranking)


---

## REVIEW ORDER-091B — `REVIEWED(Claude, 2026-07-11)` — BOT MOGUL bundle = DEAD as deployment source (ปิดด้วย BWD ของเราเอง ไม่ใช่แค่ vendor-flag)

**Verify โดย lead:** report จริง 4/5 อยู่บน disk (BM091B_*.htm, quality 99% = run จริงไม่ใช่ artifact) ·
1-16-20 ไม่มี report = runaway grid ตามคาด (CPU ไต่ตลอดจน timeout — no-SL/no-cap เจอปี trending นอก sample)

**คำตัดสิน (ชี้ขาด):** ตัวที่ "ดูรอดที่สุด" ทั้ง 5 ตายหมดที่ BWD 2020-2022 นอกปี cherry-pick — เทียบ vendor claim:
| ea_id | vendor claim (2023) | BWD เราเอง (2020-22) | ผล |
|---|---|---|---|
| 1-18-26 | PF 23.7 / DD 1.93% | PF 2.32 / **DD 28.6%** / 2151t | ตก (DD > 25%) — DD บวม 15 เท่า |
| 1-16-31 | PF 67.2 / DD 8.06% | **PF 0.39 / DD 96%** / 52t | ตายยับ |
| 1-16-23 | PF 41.8 / DD 10.7% | PF 0.98 / DD 82% / 314t | ตก |
| 1-1-23 | PF 64.0 / DD 34.9% | **PF 0.10 / DD 66%** / 55t | ตายยับ |
| 1-16-20 | PF 35.0 / DD 9.99% | runaway (ไม่จบใน 30 นาที) | ตาย (order explosion) |

**verdict: ทั้ง bundle 711 report = ตายในฐานะแหล่ง deploy** — PF 67→0.39, DD 8%→96% พิสูจน์ว่า claim ทั้งชุด
คือ overfit ปีเดียว + no-SL grid ที่ยังไม่เจอปีร้าย (ตรง memory wobr-botranking แต่ตอนนี้มี**เลขจริงจาก run
ของเราเอง**ยืนยัน ไม่ใช่แค่ prior). ไม่ต้อง BWD เพิ่ม — ตัวที่ least-bad ตายหมด ตัวที่แย่กว่าไม่ต้องเสียเวลา
**ไอเดียที่แบงก์:** ไม่มีกลไกใหม่ (entry = BB+RSI+ATR+Engulfing reversion = มีใน landscape แล้ว · exit-wrapper
30+ แบบ = การจัดการไม้ ไม่ใช่ edge) · สิ่งที่แบงก์ = **ตัวอย่างเลขจริงของ vendor cherry-pick** (สอน rescue-ladder
+ ยืนยัน "vendor report = claim") → เข้า signal-landscape เป็น dead-cell + memory update
**ไม่เข้า PARKED-VERIFY(user):** ไม่มีอะไรให้ user เทสมือเพิ่ม — คำถามถูกตอบด้วย BWD ครบแล้ว · **091B ปิดสมบูรณ์**


---

## REVIEW ORDER-091C batch-1/2 smoke — `REVIEWED(Claude, 2026-07-11)` — market-mismatch caveat + JUMSTOCH ชนะ → full funnel

**คำตัดสิน (ไม่มีตัวไหนตาย — smoke default EURUSD H1 ผิดตลาดสำหรับหลายตัว):**
- **JUMSTOCH_FIXEDLOT = ผู้ชนะ → promote full funnel:** PF 1.18 fixed-lot / 7,052t / DD 8.5% (พลาดบาร์ 0.02) ·
  fixed-lot = entry มี edge จริง sample ใหญ่ · `iStochastic(NULL,0,..)` ไม่ fix TF = home ที่แท้ = symbol×TF ยังไม่หา
  → **ORDER-091C-D1: optimize (symbol/TF + k/d/level) → plateau → OOS → MC** (dispatched)
- **NuiIndy Tri-Arb: flat-lot 65k = ARTIFACT ไม่ใช่ edge** — triangular arb รันคู่เดียว (EURUSD) ไร้ความหมาย
  (ต้อง 3 คู่พร้อมกัน) · "ดีเกิน=พัง" · PARK จนกว่าจะมี multi-pair harness ถูก (build-on idea #2 ยังคุ้ม—ทำ harness ก่อน)
- **Dark_Gold (มี set XAUUSD M5/M15 ระบุชัด) · EX197/EX140 breakout-scalp · SMC V2 = รันผิดตลาด** →
  re-smoke บนตลาดจริง (Dark_Gold=XAUUSD M15 SAFE/BALANCED · EX197/EX140=XAU · SMC=ลอง H4) = ORDER-091C-D2 (คิว)
- **OH Recovery+SL: PF 0.84 EURUSD H1** — recovery-hedge home ไม่ใช่ EURUSD H1 แน่ · WATCH รอตลาดจริง (ถาม user)
**Coverage gap ปิดแล้ว:** MT5 good+MT4 good x-ray → catalog 1,592→1,598 (ZigZag = dup, indicator sample)

## ORDER-091C-D1 — JUMSTOCH_FIXEDLOT full funnel — `DONE(Claude-agent, 2026-07-11)`
**คำสั่ง:** optimize coarse→fine หา home (symbol {EURUSD,GBPUSD,USDJPY,XAUUSD} × TF {M15,M30,H1} × k_period ×
level) → plateau-center select → IS/OOS split → MC · flat-lot ตลอด (มันเป็น fixed-lot อยู่แล้ว) · pre-registered
bar funnel: OOS PF≥1.2 & MC ruin<5% & plateau ไม่มี cell ขาดทุน → EA-SCORE · **ห้าม:** เปลี่ยนเป็น lot escalation · verdict (lead)

### ORDER-091C-D1 RESULT (Claude-agent, 2026-07-11)
Raw numbers only — no verdict (lead judges). Runner: `scripts\mt4_run.ps1`, MT4 `D:\Meta4`, EA compiled to
`...\MQL4\Experts\c091c\JUMSTOCH_FIXEDLOT.ex4` (0 errors, 10 warnings — all benign unchecked-OrderXxx return
values). Model 1 (control points), deposit 10000, fixed-lot 0.01, window 2023.01.01–2026.07.01 unless noted.
Sets under `_mt4_auto\ab_sets\jumstoch_d1\`, reports prefix `JUM_D1_` in `_mt4_auto\reports\`.

**EA mechanism note (checked before judging):** `DiMarti=1.7` is DECLARED (line 35) + printed in a Comment
(line 311) but is **never used in any OrderSend / lot calc** — every grid leg opens at `Fixed_Lot` (0.01).
So the "1.7 multiplier" is INERT: this is a fixed-lot averaging grid (counter+trend Stochastic, up to
`Level_Max=12` legs at `Range=21`-point spacing, each leg carries `SL=253`), **not** a martingale. Nothing to
disable to satisfy the flat-lot constraint — it is already flat-lot. `iStochastic(NULL,0,..)` uses the chart
TF (no hardcoded TF), so symbol×TF is the real home lever.

**STAGE 1 — home search (symbol × TF, default params, 12 cells, Model 1):**
| symbol | TF | trades | PF | net | maxDD% | win% | note |
|---|---|---|---|---|---|---|---|
| EURUSD | M15 | 8613 | 1.01 | +140 | 11.28 | 71.5 | |
| EURUSD | M30 | 7908 | 1.10 | +1151 | 8.15 | 72.5 | |
| EURUSD | H1  | 7052 | **1.18** | +1731 | 8.51 | 73.0 | ✅ top-2 |
| GBPUSD | M15 | 472  | 1.25 | +135 | 3.21 | 69.9 | ⚠️ DATA GAP — only 3968 bars (~40d M15 hist); PF unreliable, EXCLUDED |
| GBPUSD | M30 | 4496 | 0.95 | −364 | 17.12 | 71.5 | |
| GBPUSD | H1  | 4073 | 1.03 | +193 | 11.61 | 71.8 | |
| USDJPY | M15 | 158  | 0.29 | −227 | 2.61 | 67.1 | JPY dead all TF |
| USDJPY | M30 | 831  | 0.68 | −398 | 7.60 | 68.0 | |
| USDJPY | H1  | 813  | 0.70 | −338 | 7.38 | 71.2 | |
| AUDUSD | M15 | 6424 | 0.97 | −253 | 16.85 | 71.4 | |
| AUDUSD | M30 | 5890 | 1.09 | +773 | 10.60 | 72.2 | |
| AUDUSD | H1  | 5406 | **1.19** | +1354 | 9.81 | 72.4 | ✅ top-2 |
(order used {EURUSD,GBPUSD,USDJPY,XAUUSD}; XAUUSD swapped for AUDUSD per the D1 brief's Stage-1 grid
{EURUSD,GBPUSD,USDJPY,AUDUSD}.) **Home = H1** for the FX majors; both winners (trades≥200, DD<25%, best PF):
**EURUSD H1 (1.18)** and **AUDUSD H1 (1.19)**. USDJPY structurally dead every TF (point-scaled Range/SL/TP
on the 3-digit quote). Carried both winners forward.

**STAGE 2 — param plateau (k-period × O/S level pair, both Stochastics swept uniformly, full window):**
EURUSD H1:
| cell (k / U-L) | trades | PF | net | maxDD% |
|---|---|---|---|---|
| k24 80-20 | 6745 | 1.15 | +1425 | 8.52 |
| k24 75-25 | 6812 | 1.17 | +1532 | 9.07 |
| k24 70-30 | 6735 | 1.14 | +1334 | 9.39 |
| k32 80-20 | 6691 | 1.13 | +1249 | 9.71 |
| **k32 75-25 (CENTER)** | **6681** | **1.15** | **+1380** | **9.09** |
| k32 70-30 | 6677 | 1.17 | +1525 | 8.89 |
| k40 80-20 | 6590 | 1.16 | +1425 | 8.79 |
| k40 75-25 | 6569 | 1.14 | +1265 | 9.44 |
| k40 70-30 | 6524 | 1.16 | +1425 | 8.73 |
→ PEAK 1.17 (k24/75-25 & k32/70-30). **Plateau: all 9 cells positive (PF 1.13–1.17, DD 8.5–9.7%) — NO losing cell.**

AUDUSD H1:
| cell (k / U-L) | trades | PF | net | maxDD% |
|---|---|---|---|---|
| k24 80-20 | 5088 | 1.11 | +756 | 9.88 |
| k24 75-25 | 5247 | 1.17 | +1144 | 9.86 |
| k24 70-30 | 5281 | 1.20 | +1336 | 9.70 |
| k32 80-20 | 5011 | 1.11 | +749 | 9.99 |
| **k32 75-25 (CENTER)** | **5161** | **1.18** | **+1181** | **9.95** |
| k32 70-30 | 5148 | 1.21 | +1372 | 9.82 |
| k40 80-20 | 4969 | 1.12 | +823 | 10.03 |
| k40 75-25 | 4970 | 1.09 | +609 | 10.52 |
| k40 70-30 | 5107 | 1.18 | +1188 | 10.05 |
→ PEAK 1.21 (k32/70-30). **Plateau: all 9 cells positive (PF 1.09–1.21, DD 9.7–10.5%) — NO losing cell.**
(Set-load verified: forcing counter-Stoch levels to the pair moved trade count 7052→6681 vs Stage-1 baseline,
i.e. the `.set` overrides were applied; edge held through the perturbation.) Plateau-center config carried
forward = **k=32, levels 75/25** (`JUM_D1_plateau_center.set`).

**STAGE 3 — OOS split on plateau-center (IS 2023.01.01–2025.03.01 vs OOS 2025.03.01–2026.07.01, Model 1):**
| symbol | split | trades | PF | net | maxDD% | win% |
|---|---|---|---|---|---|---|
| EURUSD H1 | IS  | 3727 | 1.16 | +809 | 6.67 | 73.2 |
| EURUSD H1 | OOS | 2961 | **1.12** | +510 | 8.58 | 72.0 |
| AUDUSD H1 | IS  | 3183 | 1.21 | +842 | 8.00 | 72.4 |
| AUDUSD H1 | OOS | 1994 | **1.06** | +158 | 10.92 | 72.2 |
Both OOS windows stay positive (PF>1.0, net>0) but **below the 1.2 OOS gate** (EURUSD 1.12, AUDUSD 1.06).

**STAGE 4 — Monte Carlo (bootstrap trade-order resample, `scripts\mt4_montecarlo.py`, full-window
plateau-center report, deposit 10000, 5000 iters). METHOD: resample the closed-trade sequence w/ replacement;
report PF 5th-pct, DD 95th-pct, ruin=P(≥50% equity loss). CAVEAT (skill): trade-order MC on a FIXED-LOT
AVERAGING-GRID EA is an OPTIMISTIC lower bound — reshuffling breaks the losing-leg clustering, so MC DD
(95th ~4%) sits far below the single-path historical DD (~8–9%); ruin 0% is on a benign 2023–2026 sample
that contains no sustained adverse trend against a full 12-leg stack.**
| symbol | hist PF / DD% | MC PF median / 5th | MC DD% 95th / 99th / worst | P(net<0) | ruin(≥50%) |
|---|---|---|---|---|---|
| EURUSD H1 | 1.15 / 8.12 | 1.15 / **1.07** | 4.32 / 5.42 / 8.26 | 0.1% | **0.00%** |
| AUDUSD H1 | 1.18 / 9.23 | 1.18 / **1.07** | 3.73 / 4.76 / 6.98 | 0.2% | **0.00%** |

**STATUS vs pre-registered bar (quoted verbatim):**
> "OOS PF>=1.2 AND MC ruin<5% AND plateau มีศูนย์กลางไม่มี cell ขาดทุน -> ผ่านเข้า EA-SCORE (lead ให้คะแนน)"
- **OOS PF≥1.2:** EURUSD 1.12 → NOT MET · AUDUSD 1.06 → NOT MET (both positive but under the gate)
- **MC ruin<5%:** EURUSD 0.00% → MET · AUDUSD 0.00% → MET (see optimistic-lower-bound caveat)
- **plateau center, no losing cell:** EURUSD MET (9/9 positive) · AUDUSD MET (9/9 positive)
Funnel is an AND of the three; the OOS-PF condition is not met for either symbol. Raw evidence recorded;
no verdict issued (lead). Both symbols cleared plateau + MC-ruin, missed only the OOS≥1.2 gate.


---

## REVIEW ORDER-091C-D1 — `REVIEWED(Claude, 2026-07-11)` — JUMSTOCH = real capped-grid edge แต่บาง + spread ยังไม่เทส → WATCH, gate ถัดไป = spread

**โครง (สำคัญ):** fixed-lot averaging grid — 12 legs × 0.01, spacing Range=21, **SL=253 ทุก leg**, DiMarti=1.7
ประกาศแต่ไม่ถูกใช้ใน OrderSend เลย = **ไม่ใช่ martingale, เป็น capped+SL'd grid** (โครง MM ผ่าน VERDICT GATE ข้อ 5)
**หลักฐาน funnel:** home = H1 majors · winner EURUSD H1 (PF 1.18/7052t) + AUDUSD H1 (1.19/5406t) · USDJPY ตายทุก TF ·
GBPUSD M15 = data gap ตัดถูก · **plateau สะอาดทั้ง 2 symbol 9/9 ไม่มี cell ขาดทุน** (center k32/75-25 ไม่ใช่ peak) ·
OOS: EURUSD 1.16→**1.12** / AUDUSD 1.21→**1.06** (บวกทั้งคู่แต่ใต้บาร์ 1.2) · MC ruin 0% แต่ **optimistic** (bootstrap
trade-order ไม่รักษา adverse-sequence ที่ stack 12 legs → MC-DD 4% vs historical 8-9%)
**ตัดสินตามบาร์ pre-registered (AND):** OOS PF≥1.2 = **ไม่ผ่านทั้งคู่** · plateau = ผ่าน · MC-ruin = ผ่าน →
**ไม่ผ่าน funnel bar ตามตัวอักษร แต่เป็น PARAMETRIC (edge จริงบาง) ไม่ใช่ structural death**
**EA-SCORE ≈ 5-6/10** (edge จริงแต่บาง · plateau แข็ง · แต่ OOS ไม่ใช่ holdout สะอาด home-search ใช้ full window ·
MC optimistic · **M0/spread ไม่เคยรัน** · no live · no BWD trend-years · no corr) = **bench/watch ไม่ใช่เงินจริง**
**gate ชี้ขาดถัดไป = spread:** H1 grid 5-7k ไม้ = spread-sensitive สุด · Model 1 ไม่คิด spread · **ถ้า spread จริง
กิน PF < 1.0 = ตาย · ถ้ารอด = demo-bench candidate** → ORDER-091C-D1b (dispatched, MT4 TestSpread ใช้ได้)

## ORDER-091C-D1b — JUMSTOCH spread stress (gate ก่อน demo) — `DONE(Claude-agent, 2026-07-11)`
**คำสั่ง:** plateau-center k32/75-25 บน EURUSD H1 + AUDUSD H1, full window 2023-2026 Model 1 fixed-lot ·
รัน 3 ระดับ spread ต่อ symbol ผ่าน MT4 TestSpread: {ปัจจุบัน/current, 15, 25 points} (EURUSD ~1.5-2.5 pip จริง) ·
ตาราง PF/net/DD/trades ต่อ spread · **บาร์: PF ยัง ≥1.05 ที่ spread 15pt ทั้ง 2 symbol = รอด → demo-bench ·
< 1.0 = ตาย (spread กิน edge)** · **ห้าม:** tune · verdict (lead) · commit `[tag] ORDER-091C-D1b done`

### ORDER-091C-D1b RESULT (Claude-agent, 2026-07-11)
Raw numbers only — no verdict (lead judges). Runner: `scripts\mt4_run.ps1` (same MT4 lane/Expert as D1:
`c091c\JUMSTOCH_FIXEDLOT`, `D:\Meta4`), same plateau-center set `JUM_D1_plateau_center.set` (k_period=32,
up_level=75, lo_level=25, Fixed_Lot=0.01). Model 1, deposit 10000, window 2023.01.01–2026.07.01. Spread
levels via the runner's `-Spread` param, which writes `TestSpread=<N>` into the MT4 tester `.ini` (confirmed
in the generated ini files — MT4 honors it, unlike MT5). Digit convention: both symbols are 5-digit feeds
(prices like `1.07016`), so 1 point = 0.00001 → 15 points = 1.5 pips, 25 points = 2.5 pips, matching the
order's own annotation. Reports: `JUM_D1b_<sym>_sp<NN>.htm` in `_mt4_auto\reports\` (sp00 = current/default
spread, no TestSpread line written).

| symbol | spread | PF | net | DD% | trades |
|---|---|---|---|---|---|
| EURUSD | current (19pt) | 1.15 | +1380.21 | 9.09 | 6681 |
| EURUSD | 15pt | 1.17 | +1529.86 | 8.64 | 6806 |
| EURUSD | 25pt | 1.12 | +1134.34 | 9.44 | 6482 |
| AUDUSD | current (22pt) | 1.18 | +1180.54 | 9.95 | 5161 |
| AUDUSD | 15pt | 1.22 | +1454.43 | 9.76 | 5378 |
| AUDUSD | 25pt | 1.15 | +1036.18 | 10.06 | 5065 |

**Current-spread reproduction check:** EXACT match to the D1 Stage-2 plateau-center CENTER row — EURUSD
(PF 1.15, net +1380, DD 9.09%, trades 6681) and AUDUSD (PF 1.18, net +1181→1180.54, DD 9.95%, trades 5161)
both reproduce D1 to the same numbers → spread plumbing/lane setup confirmed correct, no drift from D1.

**Note (raw observation, not a judgment):** at 15pt fixed spread, PF/net/trades are all HIGHER than the
current/default-spread baseline for both symbols (EURUSD 1.15→1.17, AUDUSD 1.18→1.22), then drop at 25pt
(EURUSD 1.12, AUDUSD 1.15) — i.e. the "current" variable historical spread on this feed evidently costs
more than a flat 15pt on average but less than a flat 25pt for this window, on both symbols.

**Pre-registered bar (quoted verbatim):** "PF ยัง ≥1.05 ที่ spread 15pt ทั้ง 2 symbol = รอด → demo-bench ·
< 1.0 = ตาย (spread กิน edge)"
- EURUSD @ 15pt: PF 1.17
- AUDUSD @ 15pt: PF 1.22
No verdict issued (lead).

---

## 🔄 REFRAME JUMSTOCH ตาม BUILD-ON doctrine (user 2026-07-11) — D1 verdict ไม่ใช่ "bench" แต่เป็น "build-on branch"
REVIEW D1 ด้านบนเขียน "WATCH gate=spread" ก่อน user ให้ doctrine · **แก้ framing:** JUMSTOCH PF>1 บน 2 symbol +
plateau สะอาด = **ของต่อยอด** (deploy-gate ≠ discard-gate) · D1b spread ไม่ใช่ kill-gate แล้ว แต่ **quantify ว่า
spread กินเท่าไหร่ = เหตุผลสนับสนุนการเปลี่ยนเป็น pending entry** · เปิด 2 branch build-on:

## ORDER-091C-D1c — JUMSTOCH ขยาย symbol×TF เต็ม (user: "symbol มีอีกเป็น 10 ให้เทส ทุก TF") — `DONE(Claude-agent, 2026-07-11)`
**คำสั่ง:** plateau-center config (k32/75-25 fixed-lot) · grid **majors+crosses+metal** {EURUSD,GBPUSD,USDJPY,
AUDUSD,USDCAD,NZDUSD,EURJPY,GBPJPY,AUDJPY,EURGBP,XAUUSD} × TF {M15,M30,H1,H4} · full window 2023-2026 Model 1 ·
1 backtest/cell · ตาราง PF/net/DD/trades ทุก cell + mark cell ที่ผ่าน (PF≥1.1 & trades≥200 & DD<25%) ·
เช็ค MT4 history ต่อ symbol ก่อน (data gap = ตัด ระบุ) · **ห้าม:** martingale · verdict · commit `[tag] ORDER-091C-D1c done`

### ORDER-091C-D1c RESULT (Claude-agent, 2026-07-11)
Raw numbers only — no verdict (lead judges). Runner: `scripts\mt4_run.ps1`, same MT4 lane/Expert as D1/D1b
(`c091c\JUMSTOCH_FIXEDLOT`, `D:\Meta4`), same plateau-center set `JUM_D1_plateau_center.set` (k_period=32,
up_level=75, lo_level=25 — EA-compiled defaults already carry d_period=12, slowing=12, Fixed_Lot=0.01,
Range=21 unchanged). Model 1, deposit 10000, window 2023.01.01–2026.07.01. Reports prefix `JUM_D1c_<sym>_<tf>`
in `_mt4_auto\reports\`.

**Anchor reproduction check (plumbing sanity, run before the grid):** EURUSD H1 → PF 1.15 / net +1380.21 /
DD 9.09% / 6681 trades — **exact match** to D1/D1b. AUDUSD H1 → PF 1.18 / net +1180.54 / DD 9.95% / 5161
trades — **exact match**. Both anchors reproduced correctly; grid proceeded.

**History-availability check (done before/observed during the grid, per the order's instruction):** the MT4
terminal's local `.hst` cache only holds full-depth history (M1/M5/M15/M30/H1/H4/D1/W1/MN1) for **EURUSD and
XAUUSD**; every other symbol only had H1 (`c60`) cached, or nothing at all (AUDJPY had zero cached files).
The tester auto-downloads missing history from the live server (ThinkMarkets-Live) when a cell runs, so bar
counts were checked per cell rather than assumed. Reference "full window" bar counts (from EURUSD, confirmed
by AUDUSD matching to within 0.01%): M15≈87720, M30≈44372, H1≈22693, H4≈6615. Any cell measured against that
reference:

| status | rule | symbols/TFs affected |
|---|---|---|
| FULL (history ครบ) | ≥90% of reference (or, for XAUUSD, internally consistent M15/M30/H1/H4 ratios) | EURUSD (all 4 TF) · AUDUSD (all 4 TF) · XAUUSD (all 4 TF) · GBPUSD H4 · USDJPY H4 |
| PARTIAL-GAP | 50–90% of reference | GBPUSD M15 (74%), M30 (82%) · USDJPY M15 (74%), M30 (82%) |
| SEVERE-GAP | 0–50% of reference | GBPUSD H1 (41%) · USDJPY H1 (10%) · NZDUSD M30/H1/H4 (10/9/31%) · EURJPY M30/H1 (10/9%) · GBPJPY M30/H1 (10/9%) · AUDJPY H1 (9%) · EURGBP all 4 (2/10/10/31%) · USDCAD all 4 (2/10/10/32%) |
| NO-DATA (0 trades, 0 bars) | terminal could not get any history for that cell | NZDUSD M15 · EURJPY M15+H4 · GBPJPY M15+H4 · AUDJPY M15+M30+H4 |

Per-symbol note: **EURUSD, AUDUSD, XAUUSD** = clean full-window history, all 4 TFs usable. **GBPUSD, USDJPY**
= only H4 is clean (97% of reference); M15/M30/H1 are gapped to varying degrees. **NZDUSD, EURJPY, GBPJPY,
AUDJPY, EURGBP, USDCAD** = gapped or missing on every TF (this broker/feed evidently only serves ~2–4 months
of history on these 6 symbols to this terminal, vs. the full 3.5-year window requested) — none of their
cells can be treated as full-window results.

**XAUUSD compute note:** M15 (81,011 trades) and H1 (249,517 trades) and H4 (134,305 trades) completed within
the runner's default 900s timeout; **M30 timed out and was terminated at 902s on the first attempt** (437,240
trades — the densest cell in the whole grid) and had to be re-run with `-TimeoutSec 2700`, which completed.
**XAUUSD anomaly (raw observation, not a judgment):** M15 shows DD 99.93% (near-total equity loss) and M30
shows DD 84.40% — both far outside anything seen on FX pairs — while H1/H4 show small DD (11.86%/2.79%) but
an extreme trade-density (11–20 trades per bar, vs. <1/bar on FX majors) and a **net profit pinned at exactly
100000.00–100015.67** on M30/H1/H4. Checked the EA source: `Target_Persen = 1000.0` is a declared input (a
1000%-of-deposit profit target with deposit=10000 → 100,000). This strongly suggests the EA's own profit-cap
logic is firing on XAUUSD (10000 → 100000 net) after the point-scaled `Range=21` grid (designed for 4-5 digit
FX quotes) trades far too densely against gold's price scale — the same "point-scaled Range/SL/TP" mechanism
flagged in D1 for USDJPY, but much more extreme on XAU. Raw numbers reported below as-is; not excluded via
the data-gap rule (XAU history itself is clean) but flagged for the lead as likely an artifact, not edge.

**Full 44-cell table:**

| symbol | TF | PF | net | DD% | trades | bars | history | pass? |
|---|---|---|---|---|---|---|---|---|
| EURUSD | M15 | 1.01 | +105.86 | 10.47 | 8329 | 87727 | FULL | fail (PF) |
| EURUSD | M30 | 1.10 | +1043.01 | 8.24 | 7478 | 44375 | FULL | **PASS** |
| EURUSD | H1 | 1.15 | +1380.21 | 9.09 | 6681 | 22694 | FULL | **PASS** |
| EURUSD | H4 | 1.25 | +1791.95 | 6.55 | 5299 | 6614 | FULL | **PASS** |
| GBPUSD | M15 | 0.98 | -267.98 | 23.04 | 7818 | 65249 | PARTIAL-GAP (74%) | fail (PF+gap) |
| GBPUSD | M30 | 1.00 | -28.07 | 20.91 | 7876 | 36476 | PARTIAL-GAP (82%) | fail (PF+gap) |
| GBPUSD | H1 | 1.01 | +41.19 | 11.38 | 3869 | 9339 | SEVERE-GAP (41%) | fail (PF+gap) |
| GBPUSD | H4 | 1.25 | +2489.81 | 7.15 | 6923 | 6432 | FULL (97%) | **PASS** |
| USDJPY | M15 | 0.88 | -2161.24 | 24.86 | 14209 | 65249 | PARTIAL-GAP (74%) | fail (PF+gap) |
| USDJPY | M30 | 0.85 | -2721.20 | 27.98 | 13793 | 36477 | PARTIAL-GAP (82%) | fail (PF+DD+gap) |
| USDJPY | H1 | 0.66 | -368.13 | 7.40 | 763 | 2217 | SEVERE-GAP (10%) | fail (PF+gap) |
| USDJPY | H4 | 0.93 | -1058.58 | 24.73 | 11108 | 6432 | FULL (97%) | fail (PF) |
| AUDUSD | M15 | 1.04 | +342.95 | 10.31 | 6345 | 87718 | FULL | fail (PF) |
| AUDUSD | M30 | 1.10 | +758.98 | 11.49 | 5629 | 44370 | FULL | **PASS** |
| AUDUSD | H1 | 1.18 | +1180.54 | 9.95 | 5161 | 22692 | FULL | **PASS** |
| AUDUSD | H4 | 1.07 | +434.30 | 10.59 | 4028 | 6617 | FULL | fail (PF) |
| USDCAD | M15 | 0.18 | -367.49 | 4.14 | 129 | 2048 | SEVERE-GAP (2%) | fail (PF+trades+gap) |
| USDCAD | M30 | 0.52 | -461.54 | 6.52 | 507 | 4431 | SEVERE-GAP (10%) | fail (PF+gap) |
| USDCAD | H1 | 0.41 | -590.38 | 7.33 | 420 | 2216 | SEVERE-GAP (10%) | fail (PF+gap) |
| USDCAD | H4 | 0.79 | -469.82 | 10.72 | 1566 | 2091 | SEVERE-GAP (32%) | fail (PF+gap) |
| NZDUSD | M15 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| NZDUSD | M30 | 0.97 | -19.92 | 4.29 | 473 | 4359 | SEVERE-GAP (10%) | fail (PF+gap) |
| NZDUSD | H1 | 0.86 | -75.41 | 4.09 | 343 | 1951 | SEVERE-GAP (9%) | fail (PF+gap) |
| NZDUSD | H4 | 1.90 | +875.24 | 4.48 | 1237 | 2024 | SEVERE-GAP (31%) | fail (gap only — PF/trades/DD all pass) |
| EURJPY | M15 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| EURJPY | M30 | 1.46 | +356.57 | 3.75 | 1153 | 4359 | SEVERE-GAP (10%) | fail (gap only) |
| EURJPY | H1 | 1.16 | +114.81 | 3.58 | 832 | 1951 | SEVERE-GAP (9%) | fail (trades<200 + gap) |
| EURJPY | H4 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| GBPJPY | M15 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| GBPJPY | M30 | 1.29 | +408.67 | 4.51 | 1859 | 4359 | SEVERE-GAP (10%) | fail (gap only) |
| GBPJPY | H1 | 1.19 | +204.35 | 5.00 | 1278 | 1951 | SEVERE-GAP (9%) | fail (gap only) |
| GBPJPY | H4 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| AUDJPY | M15 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| AUDJPY | M30 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| AUDJPY | H1 | 1.76 | +388.32 | 2.18 | 906 | 1951 | SEVERE-GAP (9%) | fail (gap only) |
| AUDJPY | H4 | — | 0 | 0 | 0 | 0 | NO-DATA | fail (no data) |
| EURGBP | M15 | 1.72 | +20.13 | 0.22 | 43 | 2048 | SEVERE-GAP (2%) | fail (trades<200 + gap) |
| EURGBP | M30 | 1.96 | +141.22 | 1.13 | 194 | 4433 | SEVERE-GAP (10%) | fail (trades<200 + gap) |
| EURGBP | H1 | 1.93 | +123.23 | 1.49 | 161 | 2217 | SEVERE-GAP (10%) | fail (trades<200 + gap) |
| EURGBP | H4 | 1.55 | +476.79 | 4.96 | 680 | 2048 | SEVERE-GAP (31%) | fail (gap only) |
| XAUUSD | M15 | 0.68 | -9992.84 | 99.93 | 81011 | 83224 | FULL | fail (PF+DD) |
| XAUUSD | M30 | 1.64 | +100000.00 | 84.40 | 437240 | 42129 | FULL | fail (DD) — see anomaly note |
| XAUUSD | H1 | 2.15 | +100010.23 | 11.86 | 249517 | 21580 | FULL | **PASS — see anomaly note** |
| XAUUSD | H4 | 3.21 | +100015.67 | 2.79 | 134305 | 6530 | FULL | **PASS — see anomaly note** |

**Pre-registered bar (quoted verbatim):** "cell ผ่าน = PF≥1.1 AND trades≥200 AND DD<25% AND history ครบ
(ไม่ data-gap)"

**Cells that pass ALL four conditions (clean history + numeric bar):** EURUSD M30/H1/H4 · AUDUSD M30/H1 ·
GBPUSD H4 · XAUUSD H1/H4 — 8 of 44 cells. Every gapped/no-data cell is excluded from this set regardless of
how good its raw PF looks (several — NZDUSD H4 PF1.90, GBPJPY M30/H1 PF1.29/1.19, AUDJPY H1 PF1.76, EURGBP
PF1.5–2.0 — would otherwise clear the numeric bar but sit on 2–4 months of history, not the requested
3.5-year window, so they are NOT counted as passing here).

**Top 5 passing cells by PF (clean-history only):**
1. XAUUSD H4 — PF 3.21 (anomaly-flagged, see note above)
2. XAUUSD H1 — PF 2.15 (anomaly-flagged, see note above)
3. EURUSD H4 / GBPUSD H4 — PF 1.25 (tie)
4. AUDUSD H1 — PF 1.18
5. EURUSD H1 — PF 1.15

No verdict issued (lead judges).

### 📌 TODO(user action) — MT4 HISTORY GAP: user จะโหลด history เพิ่ม แล้ว ping ให้ re-run (2026-07-11)
MT4 feed มี full-window history ครบแค่ **EURUSD/AUDUSD/XAUUSD** (+GBPUSD/USDJPY H4 ~97%) · **คู่ที่ขาด
ต้องโหลด:** GBPUSD(M15/M30/H1) · USDJPY(M15/M30/H1) · USDCAD · NZDUSD · EURJPY · GBPJPY · AUDJPY · EURGBP
**Priority re-run (โชว์ PF>1.5 บนข้อมูลบางส่วน — น่าได้ leg เพิ่ม):** NZDUSD H4 (~1.90) · AUDJPY H1 (~1.76) ·
GBPJPY M30/H1 · EURGBP (~1.5-2.0) → re-run D1c grid บาร์เดิม + corr<0.8 · **confirmed legs ตอนนี้:** EURUSD
M30/H1/H4 · AUDUSD M30/H1 · GBPUSD H4 · XAUUSD = artifact ตัด (grid pip-scale ผิดบนทอง ชน profit-cap DD 99%)
· ทางเลือกแทนโหลด history = port entry → MT5/Boss V2 (MT5 มี history ครบ) · memory `mt4-history-gap-jumstoch`

## ORDER-091C-D1d — JUMSTOCH pending-limit entry variant (= ORDER-080 vehicle, user idea) — `OPEN` (role: Claude/Sonnet build → run)
**ที่มา:** user + ORDER-080 · mean-reversion เข้าหา LWMA → วาง **buy-limit ใต้ราคา / sell-limit เหนือ** ที่ระดับ
grid แทน market → fill maker ไม่จ่าย spread (grid 5-7k ไม้ = ประหยัด spread เยอะ อาจดัน PF ขึ้นชัด)
**คำสั่ง:** (1) สร้าง variant `(EXP)_JUMSTOCH_pending.mq4` (หรือ port entry เข้า Boss V2) — เปลี่ยน OrderSend market
เป็น pending limit ที่ราคา entry logic เดิม + จัดการ expire/re-place · ห้ามแตะ lot/SL/exit logic (isolate ตัวแปรเดียว)
(2) compile 0/0 (3) รันเทียบ market-vs-pending บน 2 home cell (EURUSD+AUDUSD H1) + spread จริง · ตาราง EV/ไม้
เทียบ (fill-rate ของ pending ด้วย — limit ไม่ fill ทุกไม้) · **บาร์: pending PF > market PF ที่ spread จริง = ยืนยันคุณค่า**
· **ห้าม:** เปลี่ยน lever อื่น · verdict · commit `[tag] ORDER-091C-D1d done`
**หมายเหตุ:** นี่ตอบ ORDER-080 (limit vs market) ด้วย EA จริงตัวแรก → ปิด 080 ไปในตัวถ้าได้ผล


---

## ORDER-091C-D1e — JUMSTOCH MT5 port + smoke — DONE(Claude-agent, 2026-07-11)
**คำสั่ง (user directive):** port JUMSTOCH_FIXEDLOT.mq4 -> MT5 เพื่อใช้ full MT5 history (มีทุก symbol ไม่เหมือน MT4
feed ที่ gap) + optimize ง่าย · VALIDATION GATE: reproduce MT4 EURUSD H1 baseline ก่อน trust symbol ใหม่ ·
แล้ว smoke symbol ที่เคย gap บน MT4 (NZDUSD/AUDJPY/GBPJPY/EURGBP + cross-check AUDUSD/GBPUSD) × {M15,H1,H4} ·
flat-lot · **ห้าม:** verdict (lead) · commit `[tag] ORDER-091C-D1e done`

### ORDER-091C-D1e RESULT (Claude-agent, 2026-07-11)
Raw numbers only — no verdict (lead judges). Port source: `ea_projects\(EXP)_JUMSTOCH_MT5\(EXP)_JUMSTOCH_MT5.mq5`
(compiled `D:\Meta 5\MetaEditor64.exe` -> `.ex5` 47,948 bytes, **0 errors / 0 warnings, first try**). Runner
`scripts\mt5_run.ps1`, MT5 lane-2 `D:\Meta 5b` (portable), Expert `c091c\(EXP)_JUMSTOCH_MT5`. Model 1,
deposit 10000, leverage 1:100, fixed 0.01 lot, window 2023.01.01–2026.07.01, default compiled inputs
(kperiod=32, k_period=32, lo_level=25, up_level=75, lolevel=30, uplevel=70, Range=21, Level_Max=12,
SL=253, TP=30). Reports prefix `JUMT5_` in `_mt5_auto\reports\`. Hedging account (guard in OnInit).

**Port notes (verified line-by-line vs the decompiled MT4 source, not paraphrased):**
- `DiMarti=1.7` DECLARED but NEVER wired into any lot calc (confirmed D1) — kept as an inert input, every
  leg opens at `Fixed_Lot`. `Lot_mode`/`Fix_lot`/`Manage_Lot` compound machinery is ALSO dead in the source
  (every OrderSend uses the plain `Fixed_Lot` extern, never the computed `G_lots_392`) — dropped; the port
  has one lot input used everywhere = exactly what the source does. Flat-lot, not martingale.
- **The "Trend" block is NOT mean-reversion** (despite the LWMA+Stoch-filter look) — the source's call sites
  invert the naive reading: BUY_Trend fires on `Close[1] > LWMA && stoch < up_level` (join uptrend),
  SELL_Trend on `Close[1] < LWMA && stoch > lo_level` (join downtrend). The "Counter" block IS pure-Stoch-band
  mean-reversion. Ported EXACTLY as coded (same f0_1 return codes 2/-2 and same call-site mapping) — this is
  what produced the D1 MT4 baseline, so a faithful port keeps it, does NOT "fix" it to the naive reading.
- Digit-aware pip = tick_size×10 on 3/5-digit (mirrors init()); Range/SL/TP/Trailing/Tp_from_Bep all in PIPS.
- Cosmetic on-chart Comment()/ObjectLabel dashboard dropped (zero trading effect).
- **NO port bugs needed fixing** — compiled clean and passed the gate on the first backtest.

**VALIDATION GATE — MT4 baseline vs MT5 port (EURUSD H1, same window/settings):**
| metric | MT4 baseline (D1 stage-1 default) | MT5 port | pass criterion | verdict |
|---|---|---|---|---|
| PF | 1.18 (D1); brief cites ~1.15 | **1.19** | within ~0.15 (1.0–1.3) | PASS |
| trades | 7052 (default) / 6681 (plateau set) / brief ~6681 | **7486** | within ±30% | PASS (+6% vs 7052) |
| EqDD% | ~8.5% | **8.23%** (balDD 7.04%) | same order of magnitude | PASS |
| net | +1731 (D1) / brief ~+1380 | **+1832** | positive | PASS |
**GATE = PASS on all 4 criteria.** Cross-platform port reproduces the MT4 EURUSD H1 baseline (tick-model
differences give +6% trades and marginally higher PF, well inside ballpark). MT5 port is trustworthy.

**NEW-SYMBOL SMOKE (MT5 full history, Model 1, default inputs, fixed 0.01):**
| symbol | TF | PF | net | balDD% | eqDD% | trades |
|---|---|---|---|---|---|---|
| EURGBP | M15 | **1.46** | +1740.16 | 4.64 | 6.85 | 2940 |
| EURGBP | H1  | **1.48** | +1458.98 | 3.33 | 5.66 | 2368 |
| EURGBP | H4  | **1.28** | +830.92  | 4.33 | 6.78 | 2010 |
| NZDUSD | M15 | 0.99 | −87.02   | 11.99 | 14.05 | 5217 |
| NZDUSD | H1  | 1.12 | +740.31  | 10.54 | 12.34 | 4538 |
| NZDUSD | H4  | **1.37** | +1606.81 | 6.07 | 7.81 | 3879 |
| AUDUSD | M15 | 1.00 | −21.40   | 13.39 | 14.77 | 6423 |
| AUDUSD | H1  | **1.22** | +1588.07 | 8.02 | 9.58 | 5713 |
| AUDUSD | H4  | **1.20** | +1200.81 | 8.89 | 10.31 | 4564 |
| GBPUSD | M15 | 1.13 | +2243.45 | 15.43 | 16.71 | 12096 |
| GBPUSD | H1  | 1.13 | +1778.57 | 17.13 | 18.82 | 10161 |
| GBPUSD | H4  | 1.18 | +2224.00 | 8.15 | 10.39 | 9043 |
| AUDJPY | M15 | 1.06 | +915.19  | 14.49 | 15.05 | 14561 |
| AUDJPY | H1  | 0.96 | −478.57  | 23.53 | 25.10 | 11998 |
| AUDJPY | H4  | 1.02 | +211.39  | 16.83 | 18.30 | 10466 |
| GBPJPY | M15 | 1.02 | +538.84  | 29.15 | 30.23 | 31844 |
| GBPJPY | H1  | 0.98 | −486.86  | 28.43 | 29.01 | 27352 |
| GBPJPY | H4  | 0.93 | −1756.79 | 38.14 | 39.32 | 23049 |

**Cross-check vs MT4 (confirmed cells):** AUDUSD H1 MT5 PF 1.22 vs MT4 D1 1.19 (agrees); GBPUSD H1 MT5 1.13
vs MT4 D1 1.03 (MT5 slightly better; higher trade count on full history). Cross-platform agreement good.
**Raw observations (not a verdict):** EURGBP is the standout new cell (PF 1.46–1.48 M15/H1, 1.28 H4, all
low-DD 5.7–6.9% eq) — a symbol MT4's gapped feed could not evaluate. NZDUSD H4 (1.37/7.8% eq) and the
AUDUSD H1/H4 cluster (1.20–1.22) are the other clean cells. Both JPY crosses (AUDJPY, GBPJPY) are weak-to-
negative with 15–39% DD and 10k–32k trades = point-scaled grid mismatch on 3-digit JPY quotes (mirrors the
D1 USDJPY-dead finding). Lead judges home selection / demo-bench inclusion.


---

## REVIEW ORDER-091C-D1b — `REVIEWED(Claude, 2026-07-11)` — JUMSTOCH ทน spread → เลื่อนขึ้น demo-bench candidate

**ตัดสิน:** spread จริงไม่กิน edge — ที่ spread 15pt (1.5 pip) EURUSD PF **1.17** / AUDUSD **1.22** · แม้ 25pt (2.5 pip
แย่กว่าโบรกทั่วไป) ยัง 1.12/1.15 · **current variable spread (ตัวเลขจริงสุด) = EURUSD 1.15 / AUDUSD 1.18** ·
baseline reproduce D1 เป๊ะ (plumbing ยืนยัน) · **ผ่านบาร์ 1.05 สบาย ทั้ง 2 symbol**
**สรุปสถานะ JUMSTOCH (concern spread คลายแล้ว):** edge จริง spread-robust PF 1.15-1.18 · plateau สะอาด 9/9 ·
OOS บวก · ruin 0% · fixed-lot capped-SL grid = **demo-bench candidate ตัวแรกจากคลัง user** (EA-SCORE ~6)
**รูที่เหลือก่อนเงินจริง (ไม่ใช่ blocker ของ demo):** OOS บาง (1.06-1.12) · MC optimistic-for-grid · no live · no
BWD trend-years · no corr — ทั้งหมด = demo-forward + build-on แก้ได้
**ลำดับที่ถูก (build-on doctrine):** ยังไม่ attach demo ทันที — **D1c หา home ที่ดีที่สุดก่อน** (อาจดีกว่า EURUSD/
AUDUSD H1 มาก) แล้วค่อยเลือก config เข้า demo + D1d pending อาจดันขึ้นอีก → เลือก home จริงก่อนค่อย bench


## ORDER-091C-D1c PROCESSING (lead จะทำเมื่อ D1c เสร็จ — user doctrine 2026-07-11):
1. เอา **ทุก cell ที่ผ่านบาร์** (PF≥1.1 & trades≥200 & DD<25% & ไม่ data-gap) = home set ไม่ใช่เลือกตัวเดียว
2. คำนวณ **pairwise correlation ของ equity curve ระหว่าง symbol ที่ผ่าน** (corr_monthly.py logic) →
   เก็บชุดที่ corr < 0.8 = multi-symbol demo config · คู่ที่ corr > 0.8 = surface ให้ user เลือก (ไม่ auto-drop)
3. cell ที่เฉียด (PF 1.0-1.1) = **candidate build-on** (ใส่ session/vol filter หรือขยาย Range spacing) ไม่ทิ้ง →
   เข้า D1d หรือ tweak-probe แยก
4. ผลลัพธ์ = JUMSTOCH multi-symbol demo-bench set (EA เดียว หลาย symbol) + คิว build-on ต่อ (D1d pending + tweaks)


---

## ORDER-095 — CAMPAIGN: ขยาย symbol ให้ EA ที่ deploy อยู่แล้ว (user 2026-07-11: "ขยายผลไปตัวที่ demo อยู่ ได้อีกเยอะ") — `OPEN` (multi-session, pace 1 EA/batch)

**หลักการ (build-on doctrine + multi-symbol reuse):** EA ที่ deploy แล้ว = validated ที่ home เดียว · ขยายไป
symbol อื่นที่ผ่านเกณฑ์ (corr < 0.8 ระหว่างกัน) = เพิ่มไม้โดยไม่ต้องหา EA ใหม่.

**⛔ CAVEAT ชี้ขาด (lead judgment — ขยายผิดตัว = กระจายทางแพ้):** ขยายได้เฉพาะ EA ที่ **entry มี edge จริง
(flat-lot PF>1)** เท่านั้น. EA ที่ entry ไม่มี edge = ขยาย symbol ยิ่งเพิ่มวิธีเสียเงิน:
- ✅ **ขยายได้ (source + flat-lot edge ยืนยัน):** EA_BREAKOUT_XAU (breakout, real, travels) · Boss_14_GridLog
  (demo flagship, 7 symbol แล้ว) · EA_SUPERTREND (flat-lot PF 2.93 — pending demo) · CB_GBP ConsoBreakout ·
  NuiIndy Dynamic RSI+ADX (source อยู่ .Final EA)
- ❌ **ห้ามขยาย (entry ไม่มี edge — กำลังถอดอยู่แล้ว):** RSI-MR (flat-lot 0.78) · ST_EA03 family (0.68/0.40) ·
  ST03 replica — พวกนี้ถอดเพราะ entry ไม่มี edge → ขยายยิ่งผิดหลัก
- ⚠️ **compiled-only (.ex4 รันได้แก้ไม่ได้):** UnNomGuai/swb/RSI-orig (MT4 demo) = ขยายแบบ run-as-is บน symbol
  อื่น + corr check (flat-lot check = ปิด escalation input ถ้ามี) · Zeus/Kangaroo = martingale locked, Zeus เปราะ
  (stop-out gold) → ไม่ขยาย

**Methodology ต่อ EA (เหมือน JUMSTOCH D1c):** (1) flat-lot smoke บน symbol candidate ที่ยังไม่ deploy → เอาที่
entry PF>1 (2) full-config IS/OOS บนตัวที่ผ่าน (3) corr equity-curve vs leg เดิม → เก็บ corr<0.8, คู่ >0.8 บอก user
(4) เพิ่มเข้า demo config. **pace 1 EA/batch** · Boss_14 = ตัวแรก (D1c-สไตล์)

## ORDER-095-A — Boss_14_GridLog ขยาย symbol (ตัวแรก, demo flagship) — `DONE(Claude-agent, 2026-07-11)`
**คำสั่ง:** Boss_14_GridLog (EALabTpl\Boss_14_GridLog, source ของเรา) · deploy แล้ว 7 symbol
(USDJPY/AUDNZD/EURJPY/AUDCAD/CADJPY/EURUSD/XAU H1) · ขยาย candidate ใหม่: {GBPUSD,AUDUSD,NZDUSD,USDCAD,
GBPJPY,AUDJPY,NZDCAD,EURGBP,CHFJPY,GBPAUD} × TF {M15,H1,H4} · full window 2023-2026 Model 1 ·
**(1) flat-lot edge check ก่อน** (ปิด lot escalation → LotMode fixed) ต่อ symbol: entry PF>1 flat = ผ่านไปข้อ 2 ·
(2) config เต็ม (grid ปกติ) IS/OOS บนตัวที่ผ่าน · ตาราง flat-PF + full-PF/DD/trades ต่อ cell + บาร์:
flat PF>1 & full OOS PF≥1.2 & DD<20% = candidate leg · **ห้าม:** verdict · corr step (lead ทำเอง) · commit `[tag] ORDER-095-A done`

### ORDER-095-A RESULT (Claude-agent, 2026-07-11)

**Run conditions:** portable lane `D:\Meta 5b` only (main `D:\Meta 5` lane not touched) ·
`EALabTpl\Boss_14_GridLog` · Model 1 (open-price) · deposit 10000 · leverage 1:100 · full window
2023.01.01–2026.07.01 · 10 candidate symbols × {M15,H1,H4} · all 61 runs (1 anchor + 30 flat-lot +
20 full-config; 10 cells skipped full-config per flat≤1 rule) completed on first attempt, no
retries, no `NO REPORT`, no 0-trade cells.

**Deployed-config baseline used:** `ea_template\sets\Boss14_GridLog_AUDCAD_DEMO.set` as the
template. Note for the record: the 7 already-deployed legs are each **individually IS-optimized**
per symbol — `_9_StepATRmult`, `_14_DistAtrMult`, `_2_BasketTP_Money`, `_14_Direction` (buy/sell)
and `_41_FixedLot` differ leg-to-leg (e.g. EURUSD_DEMO runs Direction=2/SELL-only + DistAtrMult=3.0,
while AUDCAD_DEMO runs Direction=1/BUY-only + DistAtrMult=1.4) — there is no single literal
parameter set shared by all 7. AUDCAD_DEMO was picked as the single baseline applied unchanged to
every new candidate because it matches the cross-symbol mode on every field except
`_2_BasketTP_Money` (StepATRmult=1.4, DistAtrMult=1.4, Direction=1/BUY-only, FixedLot=0.10 — all
modal values). New-symbol .set files built: `_mt5_auto\ab_sets\o095a_sets\O095A_FULL_baseline.set`
(LotProg=55 PROG_LOG_POWER, `_41_FixedLot=0.10` — grid escalation ON, exactly this baseline) and
`_mt5_auto\ab_sets\o095a_sets\O095A_FLAT_baseline.set` (identical except `LotProg=50` PROG_NONE +
`_41_FixedLot=0.01` — escalation OFF, flat 0.01 lot; grid stacking StackMode=92/6-level stays ON,
only the log-lot multiplier is disabled per order text "ปิด lot escalation → LotMode fixed"). No
symbol-specific re-optimization was done for the new candidates — this is a screening pass on the
untuned baseline, not each symbol's own best config.

**Sanity anchor:** `EURUSD H1` full deployed config (`Boss14_GridLog_EURUSD_DEMO.set` verbatim,
report `O095A_ANCHOR_EURUSD_H1.htm`) → **PF 1.97, Net +668.03, Trades 69, BalDD 2.99%, EqDD 4.39%,
Bars 21720, History Quality 100%.** This reproduces the ORDER-016 cohort-2 EURUSD full-window
result (PF 1.97, Net +669.10, Trades 69) almost exactly → plumbing/set confirmed correct before
trusting new-symbol numbers.

**History check:** all 10 candidate symbols × all 3 TFs returned History Quality 99–100% and bar
counts in the expected range for the window (M15 ≈86,872–86,878 · H1 ≈21,719–21,720 · H4 = 5,430
on every cell, matching the anchor's H1 bar count and each other TF's expected count for a 3.5-year
window) — **no DATA-GAP cells found across the whole grid**, nothing excluded.

**Pre-registered bar (quote verbatim, not judged):** "candidate leg = flat-lot PF>1 AND full-config
PF≥1.2 AND DD<20% AND history ครบ"

**STEP 1 — flat-lot edge check (all 10 symbols × 3 TF, `O095A_FLAT_baseline.set`, fixed 0.01 lot,
escalation OFF):**

| Symbol | TF | Flat PF | Net | Trades | BalDD% | EqDD% | Bars | HistQ% |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| AUDJPY | M15 | 6.20 | +290.37 | 23 | 0.32 | 1.27 | 86878 | 100 |
| AUDJPY | H1  | 2.04 | +220.14 | 38 | 1.68 | 3.03 | 21720 | 100 |
| AUDJPY | H4  | 2.90 | +265.36 | 20 | 1.23 | 1.50 | 5430  | 100 |
| AUDUSD | M15 | 1.06 | +9.32   | 50 | 1.44 | 2.20 | 86872 | 100 |
| AUDUSD | H1  | 1.06 | +15.17  | 47 | 1.71 | 2.10 | 21719 | 100 |
| AUDUSD | H4  | 0.54 | -76.67  | 17 | 1.68 | 2.47 | 5430  | 100 |
| CHFJPY | M15 | 7.64 | +675.48 | 29 | 0.62 | 1.84 | 86875 | 100 |
| CHFJPY | H1  | 13.39| +780.71 | 17 | 0.51 | 1.84 | 21720 | 100 |
| CHFJPY | H4  | 5.36 | +285.24 | 8  | 0.41 | 0.87 | 5430  | 100 |
| EURGBP | M15 | 0.00 | -201.61 | 49 | 2.02 | 2.17 | 86878 | 100 |
| EURGBP | H1  | 0.01 | -246.58 | 48 | 2.47 | 2.82 | 21720 | 100 |
| EURGBP | H4  | 0.00 | -274.18 | 24 | 2.74 | 3.10 | 5430  | 100 |
| GBPAUD | M15 | 1.20 | +15.04  | 15 | 0.76 | 1.79 | 86878 | 100 |
| GBPAUD | H1  | 1.20 | +15.28  | 9  | 0.75 | 1.80 | 21720 | 100 |
| GBPAUD | H4  | 1.58 | +31.05  | 6  | 0.53 | 1.80 | 5430  | 100 |
| GBPJPY | M15 | 2.08 | +614.18 | 114| 2.98 | 3.11 | 86878 | 100 |
| GBPJPY | H1  | 6.98 | +827.31 | 28 | 0.65 | 1.62 | 21720 | 100 |
| GBPJPY | H4  | 4.37 | +348.84 | 15 | 0.74 | 1.98 | 5430  | 100 |
| GBPUSD | M15 | 1.36 | +94.91  | 59 | 2.09 | 2.12 | 86873 | 99  |
| GBPUSD | H1  | 1.55 | +184.72 | 50 | 2.01 | 2.32 | 21719 | 99  |
| GBPUSD | H4  | 1.56 | +194.97 | 33 | 2.09 | 2.30 | 5430  | 99  |
| NZDCAD | M15 | 0.10 | -127.95 | 54 | 1.42 | 1.63 | 86878 | 100 |
| NZDCAD | H1  | 0.26 | -82.92  | 28 | 1.12 | 1.47 | 21720 | 100 |
| NZDCAD | H4  | 0.18 | -94.44  | 16 | 1.15 | 1.67 | 5430  | 100 |
| NZDUSD | M15 | 0.00 | -232.37 | 75 | 2.32 | 3.05 | 86875 | 100 |
| NZDUSD | H1  | 0.02 | -198.90 | 32 | 2.00 | 2.57 | 21720 | 100 |
| NZDUSD | H4  | 0.00 | -239.93 | 21 | 2.40 | 2.72 | 5430  | 100 |
| USDCAD | M15 | 1.74 | +46.45  | 27 | 0.63 | 1.05 | 86872 | 100 |
| USDCAD | H1  | 3.95 | +190.38 | 15 | 0.65 | 1.07 | 21719 | 100 |
| USDCAD | H4  | 4.86 | +199.27 | 8  | 0.52 | 1.05 | 5430  | 100 |

**Symbols with flat PF≤1 on every TF (no entry edge, per-order rule "flat<1, entry no edge here" —
step 2 skipped entirely):** EURGBP (0.00/0.01/0.00), NZDCAD (0.26/0.18/0.10), NZDUSD (0.02/0.00/0.00).
**AUDUSD H4** also flat<1 (0.54) — step 2 skipped for that one cell only (AUDUSD M15/H1 both flat
1.06, marginal but >1.0, so both ran step 2).

**STEP 2 — full deployed config (grid + log-lot escalation ON, `O095A_FULL_baseline.set`, 0.10 lot)
— run only on the 20 cells with flat PF>1:**

| Symbol | TF | Flat PF | Full PF | Net | Trades | BalDD% | EqDD% | Bars | HistQ% | passes-bar? |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| AUDJPY | M15 | 6.20  | 1.40 | +803.06   | 115 | 5.10  | 5.60  | 86878 | 100 | **YES** |
| AUDJPY | H1  | 2.04  | 1.38 | +2447.94  | 326 | 11.38 | 13.48 | 21720 | 100 | **YES** |
| AUDJPY | H4  | 2.90  | 2.25 | +1975.08  | 81  | 3.20  | 4.55  | 5430  | 100 | **YES** |
| AUDUSD | M15 | 1.06  | 0.89 | -273.55   | 133 | 8.44  | 9.03  | 86872 | 100 | no (full PF<1.2, negative net) |
| AUDUSD | H1  | 1.06  | 0.93 | -59.35    | 41  | 3.21  | 5.69  | 21719 | 100 | no (full PF<1.2, negative net) |
| CHFJPY | M15 | 7.64  | 1.30 | +2802.12  | 530 | 11.98 | 13.99 | 86875 | 100 | **YES** |
| CHFJPY | H1  | 13.39 | 1.53 | +2711.85  | 247 | 5.36  | 7.54  | 21720 | 100 | **YES** |
| CHFJPY | H4  | 5.36  | 1.73 | +1212.08  | 53  | 11.98 | 13.84 | 5430  | 100 | **YES** (flat leg only 8 trades — low sample, flag for lead) |
| GBPAUD | M15 | 1.20  | 0.95 | -675.61   | 686 | 15.46 | 16.66 | 86878 | 100 | no (full PF<1.2) |
| GBPAUD | H1  | 1.20  | 0.86 | -1656.66  | 408 | 24.51 | 25.37 | 21720 | 100 | no (full PF<1.2, DD≥20%) |
| GBPAUD | H4  | 1.58  | 1.52 | +1162.65  | 78  | 5.71  | 8.30  | 5430  | 100 | **YES** (flat leg only 6 trades — very low sample, flag for lead) |
| GBPJPY | M15 | 2.08  | 1.02 | +158.93   | 431 | 24.27 | 25.46 | 86878 | 100 | no (full PF<1.2, DD≥20%) |
| GBPJPY | H1  | 6.98  | 1.32 | +3314.41  | 409 | 13.28 | 15.25 | 21720 | 100 | **YES** |
| GBPJPY | H4  | 4.37  | 1.54 | +1695.16  | 102 | 7.75  | 8.36  | 5430  | 100 | **YES** |
| GBPUSD | M15 | 1.36  | 1.01 | +84.79    | 351 | 13.90 | 15.42 | 86873 | 99  | no (full PF<1.2) |
| GBPUSD | H1  | 1.55  | 1.07 | +566.80   | 311 | 17.88 | 18.75 | 21719 | 99  | no (full PF<1.2) |
| GBPUSD | H4  | 1.56  | 0.95 | -423.94   | 272 | 20.54 | 23.84 | 5430  | 99  | no (full PF<1.2, DD≥20%, negative net) |
| USDCAD | M15 | 1.74  | 1.24 | +596.11   | 183 | 5.84  | 7.58  | 86872 | 100 | **YES** |
| USDCAD | H1  | 3.95  | 1.19 | +904.71   | 261 | 9.19  | 9.96  | 21719 | 100 | no (full PF 1.19 — marginal miss on the 1.2 bar) |
| USDCAD | H4  | 4.86  | 1.26 | +818.09   | 147 | 5.56  | 7.55  | 5430  | 100 | **YES** |

**Cells that pass both steps numerically (candidate legs per the pre-registered bar, raw count
only — 11 of 61 runs, 5 symbols):** AUDJPY (all 3 TF: M15/H1/H4) · CHFJPY (all 3 TF: M15/H1/H4,
note H4 flat leg is only 8 trades) · GBPAUD (H4 only, note flat leg is only 6 trades) · GBPJPY
(H1 and H4, not M15) · USDCAD (H4 and M15, not H1 — H1 missed by 0.01 on the full-PF bar).

**Anomalies:** none. All 61 tester launches (1 anchor + 30 flat + 20 full + wait — 10 skipped)
returned a report on the first attempt; no timeout, no retry, no 0-trade cell, no FAILED cell, no
history-quality flag below 99%. Report parsing required a comma→space thousands-separator fix
(MT5 htm reports use a plain-space thousands separator, e.g. "2 447.94", not a comma) — first-pass
regex silently returned NA on Net/DD for the larger-notional cells; re-parsed and reconciled against
raw htm before this table was written.

(raw numbers + mechanical bar-check only — no PASS/FAIL/DEPLOY verdict, no correlation step, per
order ห้าม — lead judges and runs corr)


---

## JUMSTOCH multi-symbol config — `DONE(Claude, 2026-07-11)` (corr จาก MT4 report จริง, ไม่ต้องรอ history)
สร้าง `scripts\lib\mt4_monthly.py` (extract monthly P&L จาก MT4 report + **self-validate: sum profit = Total Net
Profit ก่อนใช้** — parse ผิดคอลัมน์ = reject) · ผ่าน validation ครบ 6 leg (extracted net ตรง reported <0.4%, 42 เดือน)

**corr matrix (monthly P&L Pearson, 42 เดือน):**
- cross-symbol ทุกคู่ **< 0.52** (EURUSD×AUDUSD 0.22-0.40 · ×GBPUSD 0.40-0.52) = additive เต็ม
- within-symbol ซ้ำ: EURUSD M30↔H1 0.84 · AUDUSD M30↔H1 **0.95** → เลือก TF เดียว/symbol

**→ config demo (corr<0.8 ตาม user rule): `EURUSD H1 + AUDUSD H1 + GBPUSD H4`** = 3 ขาไม่ corr (0.25-0.49) ·
4th-leg option = EURUSD H4 (0.66 vs H1, ผ่าน gate แต่กระจุก EURUSD) · **ยังไม่เข้า DEPLOYMENTS.csv** — รอ user
attach + assign magic (candidate demo-bench, spread-robust + plateau + corr ครบ) · เพิ่มขาอีกหลังโหลด MT4 history
(NZDUSD/AUDJPY/GBPJPY/EURGBP priority)


---

## REVIEW ORDER-095-A corr preview — `REVIEWED(Claude, 2026-07-11)` — Boss_14 candidates 5 ตัวไม่ corr กันเลย
`mt4_monthly.py` เพิ่ม `extract_monthly_mt5()` (self-validate เหมือน MT4 — sum profit+comm+swap ของ out-deal =
Total Net Profit) · ผ่าน validation ครบ 5 (extracted = reported เป๊ะทุกตัว)
**corr matrix (Boss_14 new candidates, monthly P&L):** AUDJPY/CHFJPY/GBPJPY/USDCAD/GBPAUD ทุกคู่ **-0.19 ถึง 0.44**
(ไม่มีคู่ไหน >0.8) · หลายคู่ ~0 หรือติดลบ (USDCAD×AUDJPY -0.13, GBPAUD×AUDJPY -0.19 = hedge กัน) →
**ทั้ง 5 additive กันหมด** = Boss_14 ขยายได้อีก 5 symbol ที่กระจายเสี่ยงจริง
**caveat คงเดิม:** เป็น screening (baseline AUDCAD untuned + full-window ยังไม่ split OOS) → corr เชื่อได้
(robust ต่อ config tweak) แต่ **ก่อน deploy ต้อง OOS + per-symbol optimize** · ยังไม่เข้า DEPLOYMENTS.csv
**สรุป "ได้อีกเยอะ" เป็นตัวเลขแล้ว:** JUMSTOCH +3 ขาไม่ corr · Boss_14 +5 ขาไม่ corr = EA 2 ตัว → 8 ไม้กระจายเสี่ยง


---

## 🔧 PROCESS: "MT4-good → MT5 port → smoke → optimize" (user directive 2026-07-11, standard pipeline)
เมื่อ MT4 EA backtest ค่อนข้างดี → แกะ logic → implement MT5 → smoke (MT5 มี history ครบทุก symbol,
optimize ง่ายกว่า). **Gate บังคับ: MT5 port ต้อง reproduce MT4 baseline ballpark ก่อนเชื่อผล symbol ใหม่**
(PF ±0.15, trades ±30%, DD same-order) — port ที่ reproduce ไม่ได้ = มี bug (digit/point · indicator handle ·
grid spacing) เลขไร้ความหมาย · **candidates:** JUMSTOCH (ORDER-091C-D1e, กำลังทำ) → SMC V2 · Lots-ex1+4 ·
"MT4 good" ที่เจอเพิ่ม · memory `feedback-buildon-pf-gt-1` Refinement 3
**reframe D1d:** pending-limit entry ทำบน MT5 port (D1e) แทน MT4 — optimize maker-fill ง่ายกว่า + base เดียวกัน


## Boss_14 new-vs-EXISTING corr — `DONE(Claude, 2026-07-11)` — 5 ขาใหม่ additive กับพอร์ต live ทั้งหมด
5 candidate (AUDJPY/CHFJPY/GBPJPY/USDCAD/GBPAUD) × 7 legs เดิม (AUDCAD/AUDNZD/CADJPY/EURJPY/EURUSD/USDJPY/XAU,
report BOSS14_*_FULL_ISPICK_M1): **cross-corr สูงสุด 0.52 (AUDJPY×XAU) ที่เหลือ <0.5 หลายคู่ ~0/ติดลบ** →
ทั้ง 5 additive กับพอร์ตจริง ไม่ redundant กับ leg ไหน · **Boss_14 ขยาย 7→12 ขา corr-cleared** (เหลือ OOS+optimize
ก่อน deploy — corr ผ่านแต่ PF ยัง screening)


---

## 🔧 PORT-PIPELINE queue + SMC/FVG cluster (lead prep 2026-07-11, ระหว่าง D1e port รัน)
เช็คขนาด/โครง MT4-good candidates เพื่อจัดลำดับ port (จาก x-ray card ไม่ต้องอ่านหมื่นบรรทัด):
- **JUMSTOCH (472 บรรทัด, clean hand-written)** = port ง่าย → กำลังทำ D1e (gate ผ่านแล้ว)
- **SMC V2 (11,096 บรรทัด, fxDreema-gen)** concept=`smc+candle_pattern`, **has_sl=yes, no-esc = โครงสะอาด** →
  port = **concept-rebuild** (FVG/imbalance entry + SL, ใช้การ์ด x-ray ไม่ใช่แปลบรรทัด) · **candidate port ถัดไปที่ดี**
- **Lots ex1+4 (18,730 บรรทัด)** flags=`NO_SL;LOT_ESCALATION` → โครงเสี่ยง (no-SL esc) · **priority ต่ำ** (ต้อง cap analysis ก่อน)
- **🆕 SMC/FVG = mechanism cluster ทั้ง 8 ตัว** (SMC V2 + FVG FollowTrend/RichShield/serie-Plus/... 7 ตัว) —
  landscape ว่างสนิท · ตัวโครงสะอาด (has SL): SMC V2, FVG FollowTrend · **worth ตั้ง exploration แยกถ้า SMC V2 port ได้ผล**
**gotcha เจอ:** `FXDREEMA_XRAY.csv` header มี BOM (`﻿name`) → reader ต้องใช้ `utf-8-sig` (เพิ่มใน robust_text adoption TODO)


---

## REVIEW ORDER-091C-D1e — `REVIEWED(Claude, 2026-07-11)` — port สำเร็จ, JUMSTOCH ขยาย 3→5 ขา (EURGBP=ดาว)
**gate ผ่าน:** MT5 port reproduce MT4 EURUSD H1 (PF 1.19 vs 1.18 · trades +6% · DD 8.23% vs 8.5% · compile 0/0 ไม่มี bug) =
port เชื่อถือได้ · agent จับ 2 จุดถูก: "trend" block = trend-JOIN ไม่ใช่ reversion (แก้ที่ผมเดาไว้ก่อนหน้า), flat-lot ยืนยัน
**symbol ใหม่ที่ MT4 เทสไม่ได้ (ปลดล็อกโดย port):** EURGBP H1 **1.48** (M15 1.46/H4 1.28, DD 5-7% = ดาว) · NZDUSD H4 **1.37** ·
AUDUSD H1 1.22 (ตรง MT4 D1 = cross-platform agreement) · GBPUSD H4 1.18 · JPY crosses ตาย (grid pip-scale ผิด 3-digit, ตรง USDJPY-dead)
**corr matrix 5 ขา (self-validated ทุก report): ไม่มีคู่ไหน >0.8 (max 0.44)** — EURGBP แทบอิสระกับทุกตัว (0.07/0.21/0.02/-0.05)
**→ JUMSTOCH MT5 config = EURUSD H1 + AUDUSD H1 + GBPUSD H4 + EURGBP H1 + NZDUSD H4 = 5-leg uncorrelated mini-portfolio**
(จาก MT4 3 ขา → MT5 5 ขา, ไอเดีย port ของ user จ่ายผลเต็ม) · **EA-SCORE ~6-7** · gate เหลือก่อน deploy: OOS split ของ
2 ขาใหม่ (EURGBP/NZDUSD เพิ่งมี full-window smoke) · EURUSD/AUDUSD/GBPUSD inherit MT4 D1 OOS+D1b spread

## ORDER-091C-D1f — OOS validate JUMSTOCH MT5 ขาใหม่ (EURGBP/NZDUSD) — `DONE(Claude-agent, 2026-07-11)`
**คำสั่ง:** `(EXP)_JUMSTOCH_MT5` config default · IS 2023.01-2025.03 vs OOS 2025.03-2026.07 บน EURGBP H1 + NZDUSD H4
(+ re-confirm EURUSD H1/AUDUSD H1/GBPUSD H4 OOS บน MT5 ให้ครบชุด) · Model 1 fixed-lot · report `JUMT5OOS_*` ·
**บาร์: OOS PF≥1.1 & DD<15% = ยืนยันเข้า 5-leg config · < 1.0 = ถอดขานั้น** · **ห้าม:** tune · verdict (lead) · commit `[tag] ORDER-091C-D1f done`

### ORDER-091C-D1f RESULT (Claude-agent, 2026-07-11)
Raw numbers only — no verdict (lead judges). Runner `scripts\mt5_run.ps1 -Portable`, MT5 lane-2
`D:\Meta 5b`, Expert `c091c\(EXP)_JUMSTOCH_MT5` (.ex5 already compiled/deployed on this lane from
D1e, no recompile needed). Model 1, deposit 10000, leverage 1:100, fixed 0.01 lot, default compiled
inputs (no .set — same as D1e's TesterInputs). IS window 2023.01.01–2025.03.01, OOS window
2025.03.01–2026.07.01. Reports prefix `JUMT5OOS_` in `_mt5_auto\reports\`. All 10 runs (5 legs ×
IS/OOS) completed on first attempt, no retries, no NO REPORT, History Quality 99–100% on every run,
bar counts consistent with window length on each TF (no data-gap cells).

| leg | IS-PF | IS-DD(eq%) | OOS-PF | OOS-DD(eq%) | OOS-trades | holds-bar? |
|---|---:|---:|---:|---:|---:|:---:|
| EURGBP H1 | 1.38 | 4.71 | **1.34** | 6.23 | 869  | YES |
| NZDUSD H4 | 1.20 | 7.81 | **1.75** | 4.55 | 1487 | YES |
| EURUSD H1 | 1.26 | 6.54 | **1.09** | 9.21 | 3272 | no (PF<1.1, but ≥1.0 — gray zone, neither confirms nor removes) |
| AUDUSD H1 | 1.31 | 7.68 | **1.04** | 10.90 | 2183 | no (PF<1.1, but ≥1.0 — gray zone, neither confirms nor removes) |
| GBPUSD H4 | 1.16 | 10.39 | **1.28** | 6.03 | 3520 | YES |

(balance-DD% for the same OOS cells, for reference: EURGBP H1 3.67 · NZDUSD H4 2.54 · EURUSD H1
7.70 · AUDUSD H1 9.13 · GBPUSD H4 3.72 — equity-DD used as the primary DD column above, it is the
more conservative of the two on every cell here.)

**Pre-registered bar (quote verbatim, not judged):** "OOS PF>=1.1 AND OOS DD<15% = ยืนยันขา · OOS
PF<1.0 = ถอดขานั้น"

**Raw observations (not a verdict):** EURGBP H1, NZDUSD H4, and GBPUSD H4 clear the confirm bar on
both PF and DD. EURUSD H1 and AUDUSD H1 land in the unaddressed middle zone the bar text doesn't
cover (OOS PF 1.09 and 1.04 respectively — above the 1.0 removal line but below the 1.1 confirm
line); both still show OOS PF>1.0 (no reversal to negative) with DD well under 15%. No leg triggered
the OOS PF<1.0 removal condition. Lead judges the two gray-zone legs and the 5-leg config decision.


---

## REVIEW ORDER-091C-D1f + JUMSTOCH thread CLOSE — `REVIEWED(Claude, 2026-07-11)` — validated พร้อม demo (3 core + 2 watch)
**OOS:** NZDUSD H4 **1.75** (OOS>IS robust) · EURGBP H1 **1.34** · GBPUSD H4 **1.28** = ผ่านบาร์ · EURUSD H1 1.09 /
AUDUSD H1 1.04 = gray-zone (บวก DD<15% แต่ <1.1) · ไม่มีขาตก <1.0
**Finding สำคัญ (vindicate doctrine):** ขาที่ MT5-port ปลดล็อก (EURGBP/NZDUSD) OOS **แข็งกว่า** ขาเดิม (EURUSD/AUDUSD) —
home ที่ดีที่สุดไม่ใช่ symbol แรก · "อย่า fixate home เดิม" ได้ผลจริงเป็นตัวเลข
**VERDICT JUMSTOCH MT5 (`(EXP)_JUMSTOCH_MT5`):**
- ✅ **core deploy (3 ขา uncorrelated): EURGBP H1 · NZDUSD H4 · GBPUSD H4** (OOS 1.28-1.75, DD 4.5-6.2%)
- ◐ **WATCH (build-on ไม่ทิ้ง): EURUSD H1 · AUDUSD H1** (OOS 1.04-1.09) — allocation เล็ก หรือ filter-tweak (D1d/session filter)
- **EA-SCORE ~7 = demo-bench** · gate ครบ (plateau MT4-D1 · spread MT4-D1b · port-reproduce D1e · OOS D1f) · เหลือ MC + live
- **พร้อม attach demo** (user action + magic) · ยังไม่เข้า DEPLOYMENTS.csv รอ user
**thread JUMSTOCH ปิด (D1→D1f):** EA ตัวแรกจากคลัง user ผ่านครบ funnel → MT5 port → 3-leg demo config · pipeline พิสูจน์แล้ว
**build-on ต่อยอดที่เหลือ (คิว):** D1d pending-entry (บน MT5 port) · optimize/tweak 2 watch legs · ขยาย symbol เพิ่มบน MT5 (optimize ง่ายแล้ว)

---

## ORDER-096 — build "(HEX)_HexaGrid" (user สั่งเขียนจากสเปคเอง 2026-07-11) — build `DONE(Claude, 2026-07-11)` · baseline backtest `OPEN` (role: agent/Claude — ต้องเช็ค hedging-account ก่อน)

**ที่มา:** user ส่งสเปค HexaGrid เต็ม (6 ระบบอิสระ magic-scoped แชร์ grid engine ×1.33 cap 10 + SL จริงทุกไม้,
regime EMA224-slope+ADX, 7 ชั้นจัดการ+global cap) แล้วสั่ง "เขียน EA ตัวนี้ + รอรันเลย" (optimize เองไม่ได้ — คอมเต็ม).
brainstorm → standalone-port (core เดิม single-magic global-state #include ตรงไม่ได้) → user เคาะ standalone.

**สถานะ build (DONE):**
- source: `ea_projects\(HEX)_HexaGrid\(HEX)_HexaGrid_rev01.mq5` · compiled: `(HEX)_HexaGrid_rev01.ex5`
  (อยู่ในโปรเจกต์ + deploy แล้วที่ `D:\Meta 5\MQL5\Experts\HEX_HexaGrid_rev01.ex5`)
- **compile 0 errors / 0 warnings** (MetaEditor64, X64 Regular)
- ผ่าน mql-code-reviewer: ไม่มี BLOCKER · แก้ 2 HIGH (sys4 ADX-only ไม่โดน slope-gate · g_suppress_log optimize)
- **RISK CLASS L4** (capped-martingale+grid, ไม่มี rescue-hedge) — user รับทราบ (เลือก global cap 18% เอง)
- default = conservative UNOPTIMIZED (spacing ATR-adaptive multi-symbol, risk 2%/basket, mult 1.33, maxLevels 10)

**⚠️ GOTCHA ก่อนรัน (บันทึกไว้กันเสียเวลา):**
1. **ต้องบัญชี HEDGING เท่านั้น** — OnInit มี guard: ถ้า `ACCOUNT_MARGIN_MODE != RETAIL_HEDGING` = INIT_FAILED
   (netting จะ merge 6 ตะกร้าทับกัน). **เช็ค log หา `[HEX][FATAL]` ก่อนสรุป 0 trades = code bug** — ต้องมั่นใจ
   server ของ terminal ที่รัน tester เป็น hedging ก่อน
2. `_06_AllowLive=false` default แต่ tester-gate เปิดอัตโนมัติ (รัน Strategy Tester ได้เลย)
3. weekend-cut `_G_CutHourServer=12` เป็น proxy 19:30 ไทย — ปรับตาม GMT offset ของ feed ที่เทสถ้าจะเอาชั้นนี้

**คำสั่ง (baseline ก้อนแรก — both-regime, coarse Model 1 ก่อน, 1 symbol × 2 window ตาม pacing):**
```powershell
# ยืนยัน hedging ก่อน แล้วรัน 2 window (trend BWD + recent). แทน window ทีละรอบ:
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2020.01.01 -ToDate 2022.12.31 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_BWD -Portable -Terminal 'D:\Meta 5\terminal64.exe'
powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert 'HEX_HexaGrid_rev01' -Symbol XAUUSD -Period H1 -FromDate 2023.01.01 -ToDate 2026.07.01 -Model 1 -Deposit 10000 -Leverage 100 -ReportName HEX_BASE_XAU_REC -Portable -Terminal 'D:\Meta 5\terminal64.exe'
```
**Acceptance (raw เท่านั้น — ห้าม verdict, lead ตัดสิน):** 2 report เข้า `_mt5_auto\reports\` · ต่อ window append:
PF · net profit · trades · maxEqDD% · maxBalDD% · + **ยืนยันว่า OnInit ไม่ FATAL (มี trade เกิดจริง)** ·
สังเกตว่าระบบไหน (magic 20260707-13) มี trade บ้างจาก comment/journal · commit `[tag] ORDER-096 baseline done`

**ห้าม:**
- **ห้ามตัดสิน edge จาก Model-1 pass** — grid fill-sensitive, Model-1 optimistic; ผ่าน M1 = แค่ "ผ่านเข้ารอบ Model-4"
  ไม่ใช่ candidate (VERDICT GATE #6 + doctrine grid-EA ต้อง real-tick confirm)
- ห้าม tune ก่อนเห็น baseline both-regime (VERDICT GATE #3)
- ห้ามขยาย symbol×TF เต็มก่อน baseline โชว์ชีพจร (ถ้า XAU both-window PF>1 coarse → ค่อยเปิด funnel: Model-4 real-tick
  → OOS split → MC ตาม robustness-validator · ถ้าติดลบทั้ง 2 window = กลับมาดู logic/default ก่อน ไม่ใช่ tune หนี)
- ถ้า INIT FATAL (ไม่ใช่ hedging) = **หยุด แจ้ง user** ว่าต้องเทสบนบัญชี/เทอร์มินอล hedging ห้ามแก้ guard ออก

---

## CAMPAIGN ORDER-096 — WOBR/BotMogul marketplace intake: ปิด lead มือเปล่าให้ครบ (2026-07-11)

**บริบท (session c9ec73fc, REVIEWED by Claude):** เจาะ marketplace online `wobr.ai/bot-ranking` ถึงระดับ
Supabase (anon key ใน JS bundle) → ดึง 2,532 rankings + 12,481 EA catalog. สรุป: ranking key `new_total_ai`
คัดกรอง overfit ขึ้นบน (median PF 5.95, 59% <30 trades), **ไม่มี forward column ต่อ preset**, ถูกสุด 19,599
credits > เรามี 5,634 = **ซื้อไม่ได้**. Sane 6% slice = กลไก fxDreema ของเราเอง (BB+RSI+LogLot+Pyramid) +
MARTINGATE = anti-edge เดิม. Lead มือเปล่า (build เองไม่ต้องซื้อ) เจอ 2 ตัว: (1) Ichimoku+ADX → **ทำแล้ว
= dead** (EUR 0.99/GBP 0.88/JPY IS 1.13, PARKED-pending-probe) (2) Alligator+AO → **ยังไม่ทำ**. ทั้ง online
marketplace + offline BOT MOGUL bundle (ORDER-091B) = ปิดในฐานะแหล่ง deploy แล้ว. เต็ม:
`_triage/WOBR_BOTRANKING_TRIAGE.md` · memory `wobr-botranking-corpus` + `signal-landscape`.

---

## ORDER-096A — Alligator+AO naked smoke (WOBR lead 2 ตัวสุดท้าย) — `REVIEWED(Claude, 2026-07-11)` — DEAD, thesis holds
**RESULT:** built `(EXP)_AlligatorAO_Naked_rev00` (compile 0/0, magic 999093), smoke M2 2023-2026: GBPUSD
H1 0.67 / H4 0.47 = DEAD · EURUSD H1 1.37/**25t** · XAUUSD H1 1.39/**26t** = small-sample below freq floor
(conjunction fires ~25×/3yr) · EUR-H4 5t / XAU-H4 3t = noise. ไม่ใช่ PROCEED. Both WOBR mano leads closed
DEAD → marketplace intake fully closed. บันทึก signal-landscape. (detail ↓ original order)

**GOAL:** ปิด lead สุดท้ายจาก WOBR — Bill Williams Alligator+AO trend บน FX/metal H1+H4. Prior: น่าจะตาย
แบบเดียวกับ IchiADX (thesis momentum>reversion, FX=reversion) แต่ต้อง smoke ให้ครบเพื่อปิดเป็น dead-concept.

**คำสั่ง:**
1. Build `ea_projects\(EXP)_AlligatorAO_Naked\(EXP)_AlligatorAO_Naked_rev00.mq5` — คัด scaffold จาก
   `ea_projects\(EXP)_IchiADX_Naked\(EXP)_IchiADX_Naked_rev00.mq5` **verbatim** (bar-open gate · closed-bar
   shift-1 reads · NormPrice/NormLot · magic-scoped single position · ATR SL/TP · ExitMode 1 fixed-TP +
   2 ATR-trail · OnTester=PF). Magic **999093**.
   - Signal (naked trend): `iAlligator(_Symbol,_Period,13,8,5,3,3,2,MODE_SMMA,PRICE_MEDIAN)` + `iAO`.
     BUY = lips>teeth>jaw (fanned up, closed bar) AND AO ข้ามขึ้น 0 (AO[2]<=0 && AO[1]>0). SELL สมมาตร.
2. Compile headless: `D:\Meta 5\metaeditor64.exe /compile` → **ต้อง 0 errors 0 warnings**.
3. Smoke M2 2023.01.01-2026.01.01: EURUSD/GBPUSD/XAUUSD × H1+H4 = **6 cells** (`scripts\mt5_run.ps1`,
   ปิด MT5 GUI ก่อน). Parse PF/trades/DD ด้วย PowerShell regex (python ไม่อยู่ใน PATH).
4. เซลล์ไหน full PF ≥ 1.2 & trades sane → split IS(2023.01-2025.06)/OOS(2025.06-2026.01) ก่อนตัดสิน.

**Acceptance:** ตาราง 6-cell (PF/trades/DD) + IS/OOS ของเซลล์ที่ผ่าน 1.2 (ถ้ามี) + append ใต้ order นี้ ·
commit `[tag] ORDER-096A done` · Claude เขียน verdict ลง signal-landscape.
**ห้าม:** ตัดสิน LEAD จาก full-window PF อย่างเดียว (บทเรียน USDJPY IchiADX: full 1.25 แต่ IS 1.13) ·
optimize ถ้า smoke ตายหมด · ใส่ grid/martingale (naked เท่านั้น) · ตัดสิน verdict สุดท้าย (งาน Claude)

---

## ORDER-096B — ปิดเซลล์ USDJPY IchiADX (PARKED→verdict) — `REVIEWED(Claude, 2026-07-11)` — DEAD-optimized (ceiling PF 1.14)
**RESULT:** 5-pass IS probe (2023.01-2025.06 M2) AdxMin{20,25,30}×exit/trail/TP → PF {1.06,1.10,1.11,1.13,1.14},
ceiling **1.14** (AdxMin25+TP4×ATR, 131t), higher ADX WORSE (AdxMin30→0.87). ไม่มี pass แตะ 1.40 → PARKED
resolved to DEAD, ไม่ต้อง OOS/BWD. USDJPY trend ตายครบ 4 ตัว. บันทึก signal-landscape. (detail ↓ original order)

**GOAL:** ปิดเซลล์ USDJPY `(EXP)_IchiADX_Naked` ที่ session tag ไว้ PARKED-pending-probe (IS 1.13/195t ต่ำ
กว่าเกณฑ์). Prior ต่ำมาก (USDJPY trend ตายมาแล้ว 4 ตัว: SuperTrend/Donchian/EMA/IchiADX) — probe นี้แค่
ทำ verdict ให้สมบูรณ์ตาม default-param-cell rule ไม่ใช่คาดว่ารอด.

**คำสั่ง:**
1. Optimize ~54-pass USDJPY H1 IS 2023.01-2025.06 Model 2: AdxMin{15,20,25} × SlAtrMult{1.5,2.0,2.5} ×
   (ExitMode 1 TpAtrMult{2,3} + ExitMode 2 TrailAtrMult{2,2.5,3}). ใช้ `scripts\run_optimization.ps1`.
2. plateau? มี ≥3 pass ข้างเคียง PF≥1.4 (n≥60) ไหม.
3. มี plateau → center ไป OOS 2025.06-2026.01 + BWD 2020-2022. ไม่มี pass แตะ 1.4 → DEAD-optimized.

**Acceptance:** ตาราง pass + คำตัดสิน → Claude อัปเดต signal-landscape (แก้ PARKED เป็น verdict สุดท้าย).
**ห้าม:** promote จาก plateau in-sample เดี่ยว (ต้อง OOS+BWD) · ใช้เวลาเกิน ~20 นาที (prior ต่ำ)

---

## ORDER-096C — commit WOBR intake artifacts — `DONE(Claude, 2026-07-11)`

**GOAL:** commit ผลงาน WOBR triage เข้า git (ยังไม่ commit — รอ user). รันหลัง 096A/B เพื่อรวม artifacts.

**คำสั่ง:**
1. `git add` เฉพาะ: `_triage/WOBR_BOTRANKING_TRIAGE.md` · `_triage/WOBR_botranking_bestperEA.csv` ·
   `_triage/WOBR_botranking_bestperEA.json` · `_triage/WOBR_ea_catalog.json` ·
   `_triage/WOBR_sane_cohort_enriched.csv` · `ea_projects/(EXP)_IchiADX_Naked/` ·
   `ea_projects/(EXP)_AlligatorAO_Naked/` (ถ้า 096A เสร็จ). **อย่า add ทั้ง repo.**
2. commit msg: `[claude] WOBR marketplace intake closed: ranking=adverse-selected overfit (no forward data, unaffordable); IchiADX+Alligator FX-H1 trend probes = thesis-confirms-dead` + Co-Authored-By trailer.
3. ถ้าอยู่ master → branch ก่อนตาม repo rule.

**Acceptance:** commit เดียวสะอาด เฉพาะไฟล์ที่ระบุ + รายงาน hash.
**ห้าม:** add report .htm / CSV ใน `_mt5_auto` (transient) · **push โดยไม่ถาม user** · แก้ไฟล์อื่นระหว่างทาง
