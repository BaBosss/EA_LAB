# ORDER-036 — MT4 MASS-SMOKE BOARD (แยกไฟล์เพราะ 27 batches — กัน AGENT_TASKBOARD บวม)

> ⚠️ canonical entry = PROJECT_STATE.md · ไฟล์นี้ owns: **สถานะ batch 036-01..036-27 เท่านั้น** ·
> กติกาเต็ม + verdict = `AGENT_TASKBOARD.md` ORDER-036 (ยังเป็น order แม่ ชี้มาที่นี่) + `AGENTS.md`
> **batch เสร็จ + Claude review แล้ว → ย้ายแถวผลดิบไป `_archive/ORDER-036_ARCHIVE.md`** (ไฟล์นี้เก็บแค่
> ตารางสถานะ + batch ที่ยังไม่จบ — ไม่งั้นไฟล์ระเบิด)

## วิธีสั่ง (user)
- สั่งทีละก้อน: **"ทำ 036 batch 04"** หรือยาวๆ: **"ทำ 036 batch 04-08"** (agent ไล่ทีละ batch, commit ต่อ batch)
- ใครทำได้: **Codex · oc-dev** (ต้องคุม driver + MT4) · 👉 แนะ: ตัวที่ว่าง — งาน mechanical มี spec ตายตัว

## Spec ต่อ batch (เหมือนกันทุก batch — อย่าตีความใหม่)
1. worklist ของ batch = `_triage/mass_smoke_mt4_batches.csv` filter คอลัมน์ `batch` (01..27, 50 ตัว/batch, ท้าย 18)
2. ต่อ EA: copy .ex4 → `D:\Meta4\MQL4\Experts\_smoke\` → **M2 quick 2026.04-2026.07** บน basket
   **XAUUSD, EURUSD, USDJPY, AUDNZD** H1 (⚠️ match suffix broker Meta4 จริง เช่น XAUUSDm — ไม่มี = ข้าม+note)
3. **0 trades ทุก symbol = skip+note** · เทรด ≥1 → **M1 2026.03-2026.07** ทุก symbol ที่ M2 เทรด ≥10 ไม้
   (MT4 ไม่มี tick <2026-03 — memory) · ใช้ `mt4_run.ps1` + `parse_mt4_report.py`
4. ผลลง `_mt5_auto/mass_smoke_mt4.csv` (append; คอลัมน์เดียวกับ mt5 version + คอลัมน์ batch)
5. **Tier gate (กฎ user PF>1):** Tier A = PF>1 AND trades≥20 AND eqDD<40% · Tier B = PF>1 แต่ eqDD≥40%
   (grid-trap) · Reject = PF≤1 หรือ trades<20
6. guard: timeout 180s/run · skip hang · try/catch ต่อ EA · log ทุก 10 ตัว
7. จบ batch: อัปเดตตารางข้างล่าง (สถานะ + นับ A/B/reject/skip) · commit `[tag] ORDER-036 batch NN done`
8. **ห้าม:** verdict · แก้ source · รันเกิน batch ที่สั่ง

## ⚠️ บทเรียนบังคับใช้ (จาก ORDER-037: top-3 MT5 ตายครบ, 2026-07-06)
Tier A ห้ามเชื่อจากเลข — **ด่านแรกหลัง smoke = backward-OOS 2020-2022** (ถูกกว่า M4 + ฆ่า regime-harvester
ได้เด็ดขาด: pun fix lot eqDD 83% ปี 22 · GapinFX balDD 112% ปี 22 ทั้งที่ 2021 PF 22.56) → รอดค่อย
source read (ถ้ามี .mq4) + Model-4. เลขสวย 2023-26 = mean-reversion regime ไม่ใช่ edge จนพิสูจน์ปีเทรนด์
· ชื่อไฟล์มี "_fix"/"_nodll"/"crack" = DQ ทันที (cracked commercial, hard-gate)

## ตารางสถานะ (agent อัปเดตแถวตัวเองตอนจบ batch)

| Batch | EAs | สถานะ | Tier A | Tier B | Reject | Skip/0-trade | หมายเหตุ |
|---|---|---|---|---|---|---|---|
| 036-01 | 50 | DONE (Codex, 2026-07-06 09:39 ICT) | 24 | 2 | 10 | 164 | CSV=`_mt5_auto/mass_smoke_mt4.csv` · exact-history symbols only: EURUSD, USDJPY |
| 036-02 | 50 | OPEN | | | | | |
| 036-03 | 50 | OPEN | | | | | |
| 036-04 | 50 | OPEN | | | | | |
| 036-05 | 50 | OPEN | | | | | |
| 036-06 | 50 | OPEN | | | | | |
| 036-07 | 50 | OPEN | | | | | |
| 036-08 | 50 | OPEN | | | | | |
| 036-09 | 50 | OPEN | | | | | |
| 036-10 | 50 | OPEN | | | | | |
| 036-11 | 50 | OPEN | | | | | |
| 036-12 | 50 | OPEN | | | | | |
| 036-13 | 50 | OPEN | | | | | |
| 036-14 | 50 | OPEN | | | | | |
| 036-15 | 50 | OPEN | | | | | |
| 036-16 | 50 | OPEN | | | | | |
| 036-17 | 50 | OPEN | | | | | |
| 036-18 | 50 | OPEN | | | | | |
| 036-19 | 50 | OPEN | | | | | |
| 036-20 | 50 | OPEN | | | | | |
| 036-21 | 50 | OPEN | | | | | |
| 036-22 | 50 | OPEN | | | | | |
| 036-23 | 50 | OPEN | | | | | |
| 036-24 | 50 | OPEN | | | | | |
| 036-25 | 50 | OPEN | | | | | |
| 036-26 | 50 | OPEN | | | | | |
| 036-27 | 18 | OPEN | | | | | |

## Archive protocol
batch ที่ Claude review แล้ว: (1) แถวตารางข้างบนเปลี่ยนเป็น `ARCHIVED` (2) ผลดิบ/รายละเอียดย้ายไป
`_archive/ORDER-036_ARCHIVE.md` (3) survivor Tier A/B เข้า scorecard §MT5 MASS-SMOKE ตาม funnel ปกติ
