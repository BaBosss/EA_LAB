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
| 036-01 | 50 | REVIEWED(Claude 07-06) | 24 | 2 | 10 | 164 | Tier A 24 → **ORDER-040 BWD-OOS ก่อนเชื่อ** (กติกาใหม่) · ⚠️ CSV comma-bug 2 แถว (แก้ใน 040) · exact-history: EURUSD, USDJPY เท่านั้น (XAU/AUDNZD ไม่มี) |
| 036-02 | 50 | REVIEWED(Claude 07-06 ค่ำ — Codex ผ่านตรวจเข้ม 4b: CSV 200 แถว ✓ · report 8/8 มีจริง ✓ · spot-check PF ตรง ✓) | 5 | 0 | 4 | 191 | Tier A triage ด้านล่างตาราง · ❌ CITY-GOLD "_fix" = **DQ ทันที (cracked, precedent North East Way)** |
| 036-03 | 50 | REVIEWED(Claude 07-06 ค่ำ — ตรวจชุดเดียวกับ 02) | 3 | 0 | 3 | 194 | Tier A triage ด้านล่างตาราง |
| 036-04 | 50 | CLAIMED(Claude, 2026-07-06 20:3x — **เลน MT4b**; user ปลด claim Codex ที่ค้าง: 0 แถว + terminal ติดหล่ม missing-indicator spam) | | | | | driver อัปเกรดแล้ว: timeout-kill + indicator precheck (ดู spec ล่าง) |
| 036-05 | 50 | OPEN (ปลด claim Codex เดิม — ถ้า Codex กลับมาให้เริ่มที่ 05+ บน**เลน 1** และห้าม commit CSV พร้อมกับงาน batch อื่นที่กำลังวิ่ง — เช็ค git status ก่อน) | | | | | |
| 036-06 | 50 | OPEN (เหตุเดียวกับ 05) | | | | | |
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

## Triage + BWD-OOS batch 02-03 (Claude, 2026-07-06 — ย้ายลงมาจากกลางตาราง)

- ❌ **CITY-GOLD HUNTER PROx2_fix = DQ** — "_fix" cracked (hard-gate) + PF 259.99 = absurd artifact สองเด้ง
- **BWD-OOS 2020-22 (สูตร ORDER-040 · script `_mt5_auto\ab_sets\bwdoos_mt4_sweep_b0203.ps1` · ผลดิบ `_mt5_auto\BWDOOS_MT4_B0203.csv`):**

| EA | Sym | 2020-22: PF / trades / net / DD | VERDICT (Claude) |
|---|---|---|---|
| DanceT | EURUSD | 0.09 / 486 / -10,293 / **DD 102.8%** 💀 | ❌ **REJECT ถาวร** — ล้างพอร์ตจริง (1.53 ใน 2023-26 = regime ล้วน) |
| Flexy The Dragon v2.8 | EURUSD | 0.46 / 1448 / -8,748 / **DD 89.2%** | ❌ **REJECT ถาวร** |
| 12431_Happy Fast Money | EURUSD | 0.24 / 485 / -9,890 / **DD 99.1%** | ❌ **REJECT ถาวร** — ยืนยัน tight-TP suspect |
| Happy thaipop | EURUSD | 1.25 / 430 / +2,470 / **DD 73.2%** | 🅿️ **PARKED-resize-first** (PF>1 สองระบอบแต่ edge บาง + DD ทะลุ — กฎ cap-breach ห้าม reject ตรง · priority ต่ำ · unpark ต้องเช็ค trade list ก่อน) |
| CommunityPower 2.58.3 | EURUSD | 1.91 / 1212 / +40,573 / DD 74.1% | ❌ **REJECT-as-configured** — trade list: **martingale ×1.5 ไร้ cap ลึก ~16 ชั้น (0.10→48.6 lots) + SL 0.00000 ทุกไม้** → PF 1.9 สองระบอบ = recovery mechanics ไม่ใช่ edge · DD 74% ปี 20-22 = tail เกิดจริง · precedent GoldStuffV7 · ต่างจาก ClevrFX (internal cut-loss ทำงานจริง) · config capped = EA ใหม่ validate จากศูนย์ได้อนาคต แต่ priority ต่ำ (Boss V2 มี grid มี cage แล้ว) |
| 1 MINUTE SCALPER | USDJPY | 0 trades ใน window | 🅿️ PARKED-no-data (อาจ time-gated — ไม่คุ้มไล่ต่อ) |

**Pattern ยืนยันรอบที่ 3: ฆ่า 5/6 · conditional = 0** (batch-01 เหลือ ClevrFX ตัวเดียวจริงจาก 222 EA)
→ **BWD-OOS 2020-22 + อ่าน trade list (SL + ลำดับ lot) = สอง gate ถูกสุด/เด็ดขาดสุด — ด่านบังคับก่อน
Model-4/spread-stress เสมอ** (spread-stress ทำเฉพาะตัวที่รอดสองด่านแรก)

## 🛡️ Indicator precheck (เพิ่ม 2026-07-06 ดึก — แก้อาการค้างที่ user เจอ: EA เรียก indicator ที่ไม่มี → journal spam "cannot open file ...\indicators\..." ค้างเป็นชั่วโมง)

แก้ 2 ชั้นใน script กลาง (ทุก batch ต่อจากนี้ได้ผลอัตโนมัติ — อย่า workaround เอง):
1. **`mt4_run.ps1`:** timeout → **kill process ทิ้งเสมอ** (เดิมปล่อยค้าง — gotcha ที่จดใน memory ตั้งแต่ 06-30 เพิ่งแก้จริง)
2. **`mass_smoke_mt4.ps1`:**
   - precheck static: path/ชื่อเป็น indicator (`\indicators\`, "indicator", "no repaint arrow") → note `precheck-indicator-file` ข้ามทันที ฟรี
   - precheck dynamic: รันแรกไม่มี report → สแกน tester+terminal journal → เจอ `cannot open file ...\MQL4\indicators\X` → note `missing-indicator: <รายชื่อ>` + **ข้าม symbol ที่เหลือของ EA นั้นทั้งหมด** (ไม่เผา timeout ×4) · เจอ invalid ex4 → `not-an-ea-or-invalid`
   - EA ที่ note = `missing-indicator` ไม่ใช่ REJECT — เป็น **INCOMPLETE-package** (อนาคตถ้าอยากฟื้นตัวไหน หา indicator ในโฟลเดอร์ต้นทางมาลง `MQL4\indicators` แล้วรันใหม่ได้)

## 🆕 Stage-2 spec ต่อ batch (เพิ่ม 2026-07-06 ค่ำ — ให้ agent ทำเองได้ถึงหลักฐานดิบครบ ไม่ต้องรอ Claude คั่นกลาง)

หลังจบ smoke ของ batch ใดๆ ให้ agent ทำต่อทันทีในคำสั่งเดียวกัน (ยังห้าม verdict เหมือนเดิม):
1. **กรอง DQ ชื่อไฟล์:** `_fix|_nodll|crack` → mark DQ ใน CSV (คอลัมน์ note) ไม่ต้องรันต่อ
2. **BWD-OOS 2020-22** ทุก Tier A ที่เหลือ: ใช้ pattern `bwdoos_mt4_sweep_b0203.ps1` (copy → แก้ targets
   จาก CSV ของ batch ตัวเอง, สัญลักษณ์ที่ M1 PF ดีสุด) → append ผลลง `_mt5_auto/BWDOOS_MT4_B<NN>.csv`
3. **Trade-list dump** ทุกตัวที่ BWD PF>0.9: จาก report BWD ให้สรุปเป็นตาราง 3 คอลัมน์ต่อ EA —
   (a) SL เป็น 0.00000 ทุกไม้ไหม (b) ลำดับ lot 15 ค่าแรกของ chain ยาวสุด (จับ martingale) (c) lot สูงสุดที่เห็น
4. append ทั้งหมดใต้แถว batch ในไฟล์นี้ · commit เดียว `[tag] ORDER-036 batch NN + stage2 done`
**Claude เหลือแค่:** อ่านตาราง → verdict — ประหยัดรอบไปกลับ 1 วันต่อ batch

## Archive protocol
batch ที่ Claude review แล้ว: (1) แถวตารางข้างบนเปลี่ยนเป็น `ARCHIVED` (2) ผลดิบ/รายละเอียดย้ายไป
`_archive/ORDER-036_ARCHIVE.md` (3) survivor Tier A/B เข้า scorecard §MT5 MASS-SMOKE ตาม funnel ปกติ
