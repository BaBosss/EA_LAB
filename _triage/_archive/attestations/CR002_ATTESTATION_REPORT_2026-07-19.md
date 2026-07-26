# CR-002 ATTESTATION — first full pass (2026-07-19)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: ผลรอบแรก CR-002 attestation + รายการรอ user ตัดสิน เท่านั้น
> เครื่องมือ = `scripts/control_room_snapshot.ps1` v2 (sections: attestation / unknown_magics / judge_cohorts)
> + owner ใหม่ `portfolio/ATTESTATION_MAP.csv` (deployment → approved bundle artifacts).
> ตัวเลขสด regenerate ได้ทุกวันจาก daily chain — ไฟล์นี้คือ snapshot การตัดสิน ไม่ใช่ live data.

## 1. Attestation state (40 ACTIVE/PENDING_ATTACH magics)

| state | count | ความหมาย |
|---|---|---|
| **HASHED (high-conf)** | 18 | มี bundle ใน `_vps_deploy` + sha256 ของ .ex5 และ locked .set ครบ (ทั้ง 17 ตัวของ 463666728 + 990110/990208/990005) |
| **PARTIAL** | 2 | `991001` BRK-XAU จริง: set lineage กำกวม (README บอก v2 / มี v3 / CSV note บอก compiled-defaults) · `990120` MacroGate leg: bundle ไม่มี .set (ตั้ง input มือตาม README) |
| **NO_BUNDLE** | 20 | ไม่มี bundle ใน repo เลย: Boss_14 bench ×7 (attach ก่อนยุค bundle discipline) · เงินจริง 990101 Zeus XAU / 991004 Squeeze / 991002 Trendline · user EAs (1524, 7777, 1112–1115) · MT4 treasure-hunt ×4 |

**ขีดจำกัดรอบนี้ (ตรงไปตรงมา):** นี่คือ **LOCAL attestation** — พิสูจน์ว่า "ของที่ approve ใน repo คืออะไร hash อะไร"
ยังไม่ได้เทียบกับไฟล์บน VPS จริง. ขั้น VPS-side (hash .ex5/.set บน terminal จริงเทียบ snapshot) ต้องมี user/rclone step แยก.

### งานปิด gap ที่แนะนำ (เรียงผลกระทบ)
1. **เงินจริง 159503454:** lock bundle ให้ 990101/991004/991002 + เคลียร์ set lineage 991001 (user ยืนยันว่า VPS รันชุดไหน → lock เป็น bundle folder)
2. **Boss_14 bench ×7:** สร้าง bundle folder จาก locked .set ปัจจุบัน (ต้องดึงจาก terminal/user เพราะ repo ไม่มี)
3. **990120:** lock .set จริงของ demo leg เข้า `MACROGATE_DEMOLEG/`

## 2. UNVERIFIED 3 แถว — ผล enumeration

| แถว | ผล | รายละเอียด |
|---|---|---|
| **159475669** unenumerated user EAs | ✅ **ENUMERATED (9 magics)** | จาก collector สด 2026-07-19: **20240001** CHFJPYc 36 trades (ถึง 07-14) · ตระกูล **8001/8002/8005/8008/8009/8012/8014/8015** XAUUSDc (หลายตัว active ถึง 07-16). **นี่คือบัญชีเงินจริงที่มี 9 magic เทรดอยู่โดยไม่มีแถว registry** — ชื่อ EA ต่อ magic ต้องให้ user จับคู่ (คาดว่า = LondonConso/GoldReaper/MatchaGrid/BRK-XAU ตาม note เดิม) แล้วเพิ่มแถว DEPLOYMENTS.csv |
| **69424711** ClevrFX magic unknown | ⛔ BLOCKED | ไม่มี collector file เลย (rotation ยิงแต่ไฟล์ไม่ลง — .srv/server-config issue ฝั่ง user + Trial8 investor login fail) |
| **146237** user pool ~10 EAs | ⛔ BLOCKED (ใหม่: ไฟล์ว่าง) | มีไฟล์ `EA_LAB_deals_146237_*.csv` ถึง 07-10 แต่**มีแค่ header 0 แถว** — sensor ต่อได้แต่ export ว่าง (ต้องเช็ค DealsExporter บน terminal นั้น / history sync) |

## 3. รอ USER ตัดสิน — 11 แถว ACTIVE ไม่มี judge_date (ห้าม backfill โดย AI — judge date เป็นการตัดสินของเจ้าของ)

ทั้งหมดคือ user-mix / user-experiment / treasure-hunt lanes ที่ lab ไม่เคย pre-register judge:

| account | magic | EA | ข้อเสนอ (เลือก/แก้ได้) |
|---|---|---|---|
| 159475669 | 1524 | NuiIndy Dynamic RSI+ADX | live PF~2.0 มี CutLoss=30 cage แล้ว — ถ้าจะให้ lab นับ ต้องตั้ง judge date + kill ที่เป็นทางการ หรือประกาศ "user lane ถาวร ไม่ judge" |
| 159475669 | 990005 | CB_GBP ConsoBreakout | lab-built ตัวเดียวในบัญชี user-mix — ควรตั้ง judge date (เช่น 2026-10-09 ตาม cohort จริง) |
| 141049900 | 7777 | Zeus Gold Hedge MT4 | user experiment no-SL — ประกาศ "user lane ไม่ judge" หรือตั้งวัน review |
| 141049900 | 1112–1115 | Gold_Kangaroo L1–L4 | เดียวกัน — capped-mart not validated |
| 69424711 | 1, 2 | UnNomGuaiV1.132 ×2 | treasure-hunt survivors — monitor ยัง blocked; ตั้ง judge ได้ก็ต่อเมื่อ sensor กลับมา |
| 69424711 | 5888 | RSI from pips_EA | เดียวกัน |
| 69424711 | 990 | swb grid 4.1.0.3_h | เดียวกัน |

**คำแนะนำเดียวแบบเด็ดขาด:** แถวไหนเป็น "user lane" ให้เขียนคำว่า `USER-LANE` ลง judge_date ไม่ได้ (คอลัมน์เป็น date) —
ใส่ใน notes แทน แล้วปล่อย judge_date ว่างอย่างตั้งใจ; แถวที่ lab ควรนับจริงมีตัวเดียวคือ **990005 → เสนอ 2026-10-09**.

## 4. Unknown magics นอก registry (สรุปจาก snapshot v2 — 15 ตัว)

- **actionable (เทรดอยู่เดือนนี้):** 9 ตัวบน 159475669 (ตาราง §2)
- history เก่าก่อน analysis window (ไม่ต้องทำอะไร แต่บันทึกไว้): 159503454 → 1851/7810/4378 (จบ 05-07) ·
  415573666 → 12345 (การทดลองที่ user ยืนยันทิ้งแล้ว), 1114, 2670 (จบ ≤07-03)

## 5. Judge cohorts (vertical slice ใหม่ใน snapshot)

- **judge 2026-10-09 (82 วัน):** 11 EA · capable-now 0 · **projected-capable 3** (Boss_14 990201/990206/990207) ·
  projected-shortfall 8 — รายตัวมี "ต้องการ N trades/สัปดาห์" ใน snapshot (เช่น 990204 obs 2.2/wk needs 2.2/wk = เส้นยาแดง)
- **judge 2026-10-16 (89 วัน):** 16 EA · **no-sensor 14** (ทั้ง 463666728) — **ตัวบล็อกเดียวที่ใหญ่ที่สุดของ judge ต.ค. ยังคือ
  sensor 463666728** (รอ user สร้าง `D:\Monitor\MT5 - 463666728` + login ครั้งเดียว; rotation pre-registered แล้ว)

## 6. Promotion-evidence reconstruction (1 candidate) — 999094 MacdDiv XAU

ทำแยกที่ `_triage/CR002_EVIDENCE_RECONSTRUCTION_999094.md` (artifact hashes + evidence-manifest ids).
