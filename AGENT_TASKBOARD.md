# AGENT_TASKBOARD — คิวงานกลางของทุก agent

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **คิวงาน + ผลดิบระหว่างรอ review เท่านั้น** ·
> กติกาเต็ม → `AGENTS.md` (อ่านก่อน claim) · verdict สุดท้ายไม่อยู่ที่นี่ — อยู่ที่ EA_SCORECARD/PROJECT_STATE
>
> สถานะ: `OPEN` → `CLAIMED(agent, เวลา)` → `DONE` / `BLOCKED(คำถาม)` → `REVIEWED(Claude)`
> agent อื่นแก้ได้เฉพาะแถว order ที่ตัว claim · เพิ่ม order ใหม่ = Claude/user เท่านั้น

---

## ORDER-001 — GBPAUD: re-optimize บน IS window (กัน in-sample bias) — `REVIEWED(Claude, 2026-07-03 23:45 +07:00)` (role: ZCode/Codex)

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

## ORDER-002 — probe 3 symbol ที่ยังไม่เคย probe: AUDNZD / GBPJPY / NZDJPY — `DONE(Codex, 2026-07-03 23:34 +07:00)` (role: ZCode/Codex)

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

## ORDER-004 — GBPAUD p26: OOS-confirm (2025.07-2026.07) + MC — `OPEN` (role: ZCode)

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

## เสนอ order ใหม่ (agent อื่นเขียนข้อเสนอได้ที่นี่ — Claude เป็นคนยกเป็น order จริง)

_(ว่าง)_
