# HANDOFF — 2026-07-24C (session close)

## ขอบเขต session นี้ (commits `f5c093fe` → `6eeed414`, ~16 ก้อนของผม — interleaved กับ 2 commit ของ session คู่ขนานอื่น ดูหัวข้อ "งานคู่ขนาน" ท้ายไฟล์)

user ส่ง Codex review ของ EA Template (`FirstLotMode=43` balance-scaled ที่เพิ่งเพิ่ม) มาให้รีวิวซ้ำ + วางแผน → กลายเป็น
full hardening cycle ทั้งวัน ปิดท้ายด้วยการเช็ค judge-readiness ของพอร์ต demo/live ทั้งหมด

## 1. Money/safety hardening (ORDER-187→190, 194, 194b, 194c)

**ORDER-187 — เลิก silent lot-mode fallback:** `MM_ConfigValid()` ที่ OnInit — config ที่ใช้โหมด 42/43 ไม่ได้
(SLMode ไม่ให้ระยะ, anchor≤0 ฯลฯ) = **INIT_FAILED ทันที** แทนที่จะถอยไป `_41_FixedLot` เงียบๆ · runtime ที่อ่าน
ข้อมูลไม่ได้ = ข้ามไม้นั้น (`MM_SizingUnavailable`) · Wave5 structural SL ที่ re-validate ไม่ผ่านตอน order-open =
skip ไม่เปิด naked (`Exit_StructSLMissing`) · guard G4 (Wave5 = naked-probe only) บังคับจริงที่ OnInit แล้ว
(เดิมเป็นแค่คอมเมนต์) — **หลักฐาน: ไม่มี .set ไหนใน 1,331 ไฟล์ใช้ mode 42/43 ตอนเริ่ม, cage CLEAN 8/8 ไม่ต้อง re-pin**

**ORDER-188 — `scripts/mm_lotmode_test.ps1`:** positive-path test ที่ `tpl_regression.ps1` ทำไม่ได้ (มันพิสูจน์
ว่า "ของใหม่ปิดอยู่ไม่กระทบของเก่า" ไม่ใช่ "ของใหม่เปิดแล้วทำงานถูก"). 11 เคสผ่านหมด (ratio scaling, unit-independence
cent/USD, RC_MaxLot clamp, 2 fail-closed cases, Boss_16 lever 3 เคส). **finding แถม:** fixed-lot ตายที่ DD 25.09%
ไม้ 115/164 ส่วน balance-scaled หด lot เองไม่เคยแตะเพดาน จบครบ 164/164 ที่ 22.66% — วัดได้จริงไม่ใช่ทฤษฎี

**ORDER-189 — PARAM_REGISTRY 183/183 + guide §3.6:** ตาราง Mode 41/42/43 + Account Profile USD vs CENT (anchor
ผูกกับบัญชี ไม่ใช่กลยุทธ์) + linkage diagram สาย lot ทั้งเส้น

**ORDER-190 — `_16_BaseLotMode`:** Boss_16/Kangaroo scale ตาม balance ได้แบบ opt-in (default=0=flat, byte-identical)
ยืม anchor pair เดียวกับ chassis mode 43. **⚠️ acceptance bar เดิมที่เขียนไว้ผิด** — "A/B flat vs scaled ต้องชนะ PF"
วัด compounding ไม่ใช่ edge (ขัดกฎ optimize-ด้วย-mode-41 ของ repo เอง) → bar ที่ถูกคือ deposit-invariance +
self-attenuation ใน DD ซึ่งวัดแล้วใน ORDER-188 ยังไม่ได้ตัดสินใจว่าจะเปิดใช้กับ Boss_16 จริงไหม (โค้ดพร้อม default ปิด)

**ORDER-194/194b/194c — hard-kill re-fire bug (เจอเอง ไม่ใช่จาก Codex):** `RiskControl_CheckDD` เช็ค
`g_rc_kill_pending` แต่ไม่เคยเช็ค `g_rc_halted` → halt แล้ว tick ถัดไป DD ยังเกินเพดานเหมือนเดิม (peak equity ไม่ reset)
= **ยิง kill ซ้ำทุก tick จนจบ run** (log จริง: 14.4M/11.8M/3.5M บรรทัด "[RISK] HARD KILL" ต่อไฟล์, ไฟล์ log 777MB)
+ `GlobalVariablesFlush()` (disk write) ทุก tick บน live ตลอดไป. แก้ครั้งแรกไม่ครบ — **Codex 2 รอบจับได้**:
- รอบ 1 (SEV-1 ของตัวเอง): `KillReconcile` ตั้ง halted=true ก่อนยืนยันว่า persist สำเร็จ → แก้ด้วย `g_rc_persist_dirty` flag
- รอบ 2: retry เป็น `else if` ต่อจาก sweep → ถ้ามีไม้โผล่ซ้ำๆ retry ไม่มีวันได้รัน (สถานการณ์ที่ crash เสี่ยงสุดพอดี) แก้เป็น `if` แยก
- รอบ 2: `g_rc_persist_dirty` ไม่ reset ใน `RiskControl_InitEx` (global อยู่ข้าม OnInit cycle ตอนเปลี่ยน symbol/TF)
- รอบ 2: daily keep-alive write พลาดยังเงียบ (TTL 4 สัปดาห์ของ MT5 เสี่ยงเสีย halt state)
- รอบ 2: **บั๊กใหม่ที่ผมสร้างเอง** — SLMode param check ที่เพิ่มไปยิงแม้ Wave5 struct SL เป็นแหล่งระยะจริง (false alarm) แก้แล้ว
- per-reason log throttle ที่แก้ครั้งแรกยังไม่ถูก (log ทุกครั้งที่เหตุผลสลับ ไม่ใช่ per-reason จริง) แก้เป็น timestamp array แยกต่อ reason
**ทุกรอบ compile 0/0 + cage CLEAN 8/8 ก่อน commit เสมอ**

## 2. Tooling ใหม่ (ORDER-191, 192, 193, 195, 196)

- **ORDER-191:** `scripts/param_registry_fix_lines.ps1` (ซ่อม line-number citation อัตโนมัติ — มีบั๊กตัวเอง: `-match`
  ซ้อนทับ `$Matches` ทำ build-tag หาย แก้แล้ว negative-tested) + `docs/PARAM_LINKAGE.md` (generated, 11 override
  pairs, 9 silent) + `_triage/PARAM_INACTIVE_AUDIT.md`
- **ORDER-192:** `[CFG]` effective-config summary ที่ OnInit (บอกว่า input ไหนชนะจริง) + `scripts/optimize_guard.ps1`
  (ปฏิเสธ optimize dimension ที่ตาย/inert/override/safety — 19/184 rows never-optimizable). **ทดลองยิงกับคลัง .ini
  จริงทั้งหมดแล้ว (user "ลองดู"): 67 ไฟล์ optimize จริงบน Boss build → ALLOW 48 / REFUSE 19 — 16 ไฟล์เป็นแคมเปญ O133
  ที่กวาด `_9_MaxLevels` (ชนกฎ ENGINE-EDGE ตรงๆ: depth cap ต้อง cage ไม่ใช่ optimize) ไม่มี deploy .set ตัวไหนโดน
  flag (เป็น research sweep ทั้งหมด)**
- **ORDER-193:** `scripts/check_truncated_run.ps1` + `truncation_retro_scan.ps1` — cage hard-kill ไม่ถูก
  tester-gate เลย ตัด backtest กลางคันได้โดยรายงานไม่บอก. retro-scan 4,233 รายงาน → SUSPECT 141 → กรอง eqDD≥45%
  (บัญชีระเบิด ไม่ใช่ cage) ออก เหลือ 65 จริง → **7 ถูกอ้างใน verdict doc จริง (หลัง exclude งานเขียนตัวเองในวันเดียวกัน
  — รอบแรกนับผิดเป็น 10) → 3 นั่งที่เพดาน kill พอดี → ตรวจครบทั้ง 3 = กระทบ verdict 0 ใบ**. ที่สำคัญสุด: BOSS14_XAU_OOS_M1
  (PF 1.15 บันทึกไว้) rerun เต็ม window (deposit ×10, sizing ไม่พึ่ง balance) = PF 1.13/269t → **verdict เดิมยืน**
  แถมพบว่าไม่เคยถูก kill จริงด้วยซ้ำ (ไม้สุดท้ายตรงกันทั้งสอง run)
- **ORDER-195/196:** `[CFG]` ครอบ override pair ที่เหลือทั้งหมด (11/11) + registry เติม note ให้แถวที่แพ้ · V1 chassis
  (`EA_LabTemplate.mq5`+`modules/`) **ประกาศเลิกใช้ ไม่เสริม** (ตรวจแล้วตายจริง: 0 deployment/report/.set, ไม่ถูกแตะ
  5 สัปดาห์) — banner comment-only เท่านั้น ไม่ลบ ไม่แก้ logic

ทั้งสองใบหลังมอบให้ Sonnet ทำ (คู่ขนาน โดยแบ่งว่าใครแตะ MT5 ได้ตัวเดียว) แล้ว Claude verify เองก่อนรับทุกอัน
(diff log-only จริงไหม, guard refuse ถูกจริงไหม ฯลฯ)

## 3. Control Room judge-readiness re-run (read-only, ท้าย session)

**แทนที่เลขเก่า "3/38" จาก 2026-07-19E** ด้วยเลขจริงวันนี้: fleet 56 ACTIVE · 6 decision-capable วันนี้ · 24 ตัว
forecast ได้ (6 projected-capable / **18 projected-shortfall**) · 21 เร็วเกินจะ forecast (11 ไม่มี judge_date เลย) ·
**4 ตัว (account 69424711) ไม่มี sensor เลย**. **account 463666728 sensor STALE (30.2h)** และถือ EA กลุ่ม shortfall
เยอะสุด (~13 ตัว) — ถ้า sensor หลุดถาวรจะเสียการมองเห็นพร้อมกันเยอะ. **unknown magic 6 ตัวเทรดจริงไม่มีแถวใน
DEPLOYMENTS.csv** (governance gap แยกเรื่อง). attestation 16/56 hash ยืนยันตรง bundle ที่เหลือ 40 มีช่อง. บันทึกเป็น
baseline ใน `PROJECT_STATE.md` §3 + memory `control-room-judge-readiness-2026-07-24` — **ยังไม่ได้ตัดสินใจอะไรต่อ**

## บทเรียนกระบวนการ (สำคัญพอๆ กับงาน)

- **`codex:codex-rescue` subagent รายงานผิดว่า "Codex CLI ไม่ได้ติดตั้ง"** ทั้งที่ติดตั้งอยู่จริง (0.144.2) —
  เรียกตรงผ่าน `& codex exec --sandbox read-only -` (prompt ทาง stdin) ได้ผลจริง ใช้เวลา ~15 นาที/รอบ รันแบบ
  background แล้วทำงานอื่นคู่ขนาน. **ก่อนเชื่อ "tool X ไม่มี" จาก subagent ให้เช็คด้วย `Get-Command` เอง**
- **retro-audit ต้อง exclude งานเขียนของตัวเอง** — ค้น citation รอบแรกบน working tree ได้ 10 ใบ แต่ 5 ใบคือ entry
  ที่เพิ่งเขียนเองชั่วโมงก่อน (self-reference) ต้องค้นบน `git show <session-first-commit>~1:<doc>` ถึงได้เลขจริง 7
- **heuristic ที่เพิ่งเขียนเองต้องยืนยันด้วยการทดลอง ไม่ใช่เชื่อทันที** — detector "SUSPECT" ที่เพิ่งสร้างเตือนผิดในเคส
  เดียวที่ทดสอบจนจบได้ (eqDD วัดจากรายงานทั้ง run ≠ EA วัดจาก peak ตัวเองที่ reset ตอน OnInit) ยืนยันด้วยการ rerun
  แล้วดูว่าไม้สุดท้ายขยับไหม ถูกกว่าเถียงกับตัวเลข
- **git `index.lock` ค้าง 20 นาที ต้องเช็ค process ก่อนลบเสมอ** — เจอ `hash-object` ของ **Codex Desktop
  (ChatGPT.exe)** อยู่จริง แต่มันไม่ถือ lock (แค่ index อ่านอย่างเดียว, age=0s ตายเร็ว) ไม่มี add/commit/merge writer
  จริงเลย → ปลอดภัยที่จะลบ. หลักการ: `Get-CimInstance Win32_Process -Filter git.exe` แล้วดู commandline ว่ามี
  `add|commit|merge|rebase|reset` จริงไหม ก่อนแตะ lock ทุกครั้ง (memory เดิมเตือนไว้แล้ว วันนี้ใช้จริง)

## งานคู่ขนาน (เห็นใน git log แต่ยังไม่ได้ตรวจเอง — อ่านก่อนอ้างอิง)

session อื่น (แชร์ working tree เดียวกัน) commit เข้ามาระหว่างวัน 2 ก้อน คนละสายกับงานวันนี้ทั้งหมด:
- `32f32402` — ORDER-197: PROG_FIBONACCI lot lever NOT ADOPTED บน Boss_14 XAU (4-run A/B)
- `d375099e` — ORDER-136 Wave 2 verdict **RETRACTED** (baseline .set ผิด, retest กำลังรัน ตอนจบ session นี้ terminal64
  ไม่ได้รันอยู่แล้ว)

## ค้าง (ไม่เร่งด่วน — ไม่มีอะไรเป็นไฟไหม้)

1. **ตัดสินใจว่าจะบังคับ `optimize_guard.ps1` ใน optimize pipeline จริงไหม** (ตอนนี้เป็นเครื่องมือ opt-in ที่พิสูจน์
   คุณค่าแล้วบนข้อมูลจริง — 16 ไฟล์ campaign O133 ที่ active อยู่กำลังกวาด safety param)
2. **18 EA ที่ projected-shortfall** ก่อน judge — ตัดสินใจ: ยอมรับ demo window สั้นแบบ RSI-MR precedent / ขยาย
   judge date / ปล่อยตก
3. **account 463666728 sensor STALE** ควรเช็คว่าทำไม (ก่อนจะหลุดถาวรแล้วเสียการมองเห็น ~13 EA)
4. **unknown magic 6 ตัว** ควรไล่ว่าเป็น EA ที่ลืมลงทะเบียนหรือ manual trade
5. **`EA_LabTemplate.mq5`/`modules/` deprecated แล้ว** — ถ้ามีใครเสนอใช้ V1 อีกในอนาคต ให้ชี้ banner + memory นี้
   ก่อนแก้อะไรในนั้น (defect 2 จุดที่ยังไม่แก้เพราะตายแล้ว: silent fallback + normalizer ปัด lot ต่ำกว่า min ขึ้น)
6. **ORDER-136/197 ของ session คู่ขนาน** — ยังไม่ได้อ่านรายละเอียด/verdict เอง อ่านก่อนอ้างอิงในงานถัดไป

## Gotcha สำหรับ session ถัดไป

- Cage มาตรฐานตอนนี้ = `tpl_regression.ps1` (behavior) **+ `mm_lotmode_test.ps1`** (Mode 42/43/Boss_16 lever
  positive-path) **+ `param_registry_check.ps1`** (registry sync) — รันทั้งสามเมื่อแตะ `core/` หรือ `Inputs.mqh`
- `[CFG]` block ใน tester log อ่านด้วย `Get-Content <log> -Tail N -Encoding unicode | Select-String '\[CFG\]'`
  (log เป็น UTF-16, ห้ามอ่านทั้งไฟล์ — ไฟล์ log วันนี้โต 777MB)
- Registry มี guard แล้ว (`param_registry_check.ps1`) — ถ้าเพิ่ม input ใหม่ใน `Inputs.mqh` ต้องรัน guard ก่อน commit
  เสมอ ไม่งั้นจะซ้ำ regression ที่เจอวันนี้ (เพิ่ม `_16_BaseLotMode` แล้วลืม sync)
