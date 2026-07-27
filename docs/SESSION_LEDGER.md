# SESSION_LEDGER — ใครกำลังทำอะไรอยู่ตอนนี้

> ⚠️ canonical entry = `PROJECT_STATE.md` · ไฟล์นี้ owns: **การจองเลน (order number + ไฟล์ + เลน MT5) ของ session ที่ยังเปิดอยู่ เท่านั้น**
>
> **ทุก session / agent lane ต้อง append แถวของตัวเองที่นี่ก่อนแตะไฟล์ใดๆ** แล้ว commit แถวนั้นเป็น commit แรก
> (path-limited: `git commit -- docs/SESSION_LEDGER.md`). ไม่จอง = `scripts/check_order_collision.ps1` จะเตือน
> และถ้าเลข order ชนของคนอื่น = **บล็อก commit**.
>
> ที่มา: 2026-07-26 — เกิด collision จริง 3 ครั้ง (`fd5264f8` renumber 205-208→210-213 · `30598b55` renumber 203→204 ·
> `ORDER-098-C` ถูกใช้ซ้ำโดย 2 order คนละเรื่อง) + รอบกวาด archive ครั้งแรกล้มทั้งชุดเพราะ session คู่ขนาน
> commit `AGENT_TASKBOARD.md` ทับกลางทาง (memory `shared-worktree-concurrent-writers`).

## กติกา 5 ข้อ

1. **จองก่อนแตะ** — เปิด session → append แถว → commit แถวนั้นก่อน แล้วค่อยเริ่มงาน
2. **เลข order = จองเป็นบล็อกละ 10** — เอา `max(เลขที่ใช้แล้วทั้ง 2 บอร์ด)` ปัดขึ้นสิบถัดไป แล้วเว้น 1 บล็อกเป็นกันชน
   ห้ามหยิบเลขนอกบล็อกที่ตัวเองจอง (hook บล็อก)
3. **commit path-limited เสมอ** — `git commit -- <path> <path>` ห้าม `git add -A` / `git add .`
   (working tree นี้แชร์กันจริง — `git add -A` กวาดงานของ session อื่นไปด้วย)
   > ⚠️ **แก้ 2026-07-26 — ข้อ 3 กันได้แค่ครึ่งเดียว ผมเขียนกฎนี้เกินจริงไปเอง.**
   > `git commit -- <path>` commit **เนื้อ working tree ของ path นั้น** ⇒ ถ้า session อื่นแก้**ไฟล์เดียวกัน**
   > ระหว่างนั้น การแก้ของเขา**ติดไปกับ commit ของเรา** (เกิดจริง: `eda48dd8` ของผมพา ORDER-215 ของอีก
   > session ไปด้วย — งานเขาไม่หาย แต่ provenance เพี้ยน) · **path-limit กันข้าม*ไฟล์* ไม่กันข้าม*บรรทัด*ในไฟล์เดียวกัน**
   > ⇒ กันของจริงคือข้อ 4 เท่านั้น: **หนึ่งไฟล์รวม หนึ่งคนเขียน ต่อหนึ่งช่วงเวลา**
4. **ไฟล์รวม = หนึ่งคนเขียนต่อครั้ง** — ถ้าจะแตะ `AGENT_TASKBOARD.md` / `EA_SCORECARD_AND_REGISTRY.md` /
   `EA_MASTER_INDEX.csv` / `ARCHIVE_TASKBOARD_2026-07A.md` ให้ประกาศในคอลัมน์ `owns paths`
   (ระบุแถว/ส่วนที่จะแตะถ้าทำได้) และ**รวบให้เหลือการเขียนครั้งเดียวตอนจบงาน**
   · ก่อน stage เช็ค `git log -1` ว่า HEAD ไม่ขยับตั้งแต่ตอนอ่าน — ขยับ = **อ่านใหม่แล้วทำใหม่**
   · ก่อน commit เช็ค `git diff --cached` / `git diff <file>` ว่ามีของคนอื่นติดมาไหม — มี = หยุด คุยก่อน
   · เห็นเลนอื่นประกาศไฟล์เดียวกันใน ledger = **รอ หรือคุย** ไม่ใช่เขียนทับแล้วหวังว่าจะรอด
5. **ปิด session = แก้ status เป็น `CLOSED`** พร้อมเวลา · แถวที่ `ACTIVE` เกิน 12 ชม. โดยไม่มี commit = `ABANDONED`
   (ใครก็ตามที่เห็น มีสิทธิ์ mark ให้)

## เลนที่เปิดอยู่

| session id | เริ่ม | order block | owns paths | เลน MT5 | status |
|---|---|---|---|---|---|
<!-- VERIFY270 แก้ owns paths 1 ครั้ง: ตอนแรกประกาศ ORDER-280 ไว้ด้วย เพื่อจะปล่อย CLAIMED ที่ค้าง
     แต่ `S-2026-07-27-SLBUFFER` (ACTIVE, 08:40) ประกาศแถวนั้นไว้ก่อนแล้ว ⇒ ถอนออกตามกฎข้อ 4
     (เห็นเลนอื่นประกาศไฟล์/แถวเดียวกัน = รอหรือคุย ไม่ใช่เขียนทับ) · สถานะ 280 ถูกบันทึกไว้ครบแล้ว
     ในแถวปิดของ REV04 อยู่แล้ว ไม่มีอะไรตกหล่น -->
| `S-2026-07-27-CUTLOSS-VERIFY` | 2026-07-27 09:05–09:25 **แล้วเปิดต่อ ~10:30-11:00** (user สั่งงานต่อหลังปิด — แก้แถวให้ตรงความจริงตามกฎข้อ 5 แทนที่จะเปิดแถวใหม่) | **370-379** (ใช้จริง 370-373) | `_triage/HANDOFF_2026-07-27_CUTLOSS_VERIFY.md` · `AGENT_TASKBOARD.md` (แถว ORDER-370..373 เท่านั้น) · `PROJECT_STATE.md` (บล็อก 🆕 ใหม่บนสุด — ไม่มีเลนไหนประกาศไฟล์นี้) · `docs/SESSION_LEDGER.md` (แถวตัวเอง) | **ไม่ใช้เลน MT5 เลย** | `CLOSED` (2026-07-27 11:00 — commit สุดท้าย `68c0c500` + PROJECT_STATE) |
| `S-2026-07-27-SLBUFFER` | 2026-07-27 08:40 | **350-359** | `ea_projects/(TRD)_SuperTrendFlip/**` · `_mt5_auto/ab_sets/genstanding_stf/**` · `AGENT_TASKBOARD.md` (แถว **ORDER-280 · ORDER-350 เท่านั้น**) | **`D:\Meta 5`** (roaming/main — เลนเดียวที่ไม่มีใครจอง และมี tick BTC ครบ 2020+ · 5b/5c = LEVERFAN) | `ACTIVE` |
| `S-2026-07-27-LEVERFAN` | 2026-07-27 08:05 | **340-349** | `AGENT_TASKBOARD.md` (แถว ORDER-236 · ORDER-340 · ORDER-341 เท่านั้น) · `scripts/check_stale_binaries.ps1` (ORDER-341) · `_mt5_auto/ab_sets/order340/**` · `_mt5_auto/ab_sets/b14_lever/**` · `_mt5_auto/**` (รันเทส) · `docs/memory_control/B1_DATASET.csv` | `D:\Meta 5c` (ORDER-340 fan) + `D:\Meta 5b` (ORDER-236 A/B) — คนละ install รันพร้อมกันได้ process-guard แยกตาม exe path | `CLOSED` (2026-07-27 09:40 — ORDER-340 ปิด · ORDER-341 ปิด · **ORDER-236 = BLOCKED ที่ประตู BWD ของตัวเอง** รอ host search เป็นใบใหม่) · <sub>เปิดสั้นๆ 11:10-11:20 เขียน handoff `_triage/HANDOFF_2026-07-27_LEVERFAN.md` (`fb6a2635`) แล้วปิดอีกครั้ง — ไม่แตะแถวบอร์ดของใคร</sub> |
| `S-2026-07-27-GREENYELLOW` | 2026-07-27 06:35 | **320-329** (ไม่ได้ใช้ — ปิดใบเก่าทั้งหมด ไม่เปิดเลขใหม่) | `scripts/**` + `scripts/_test/**` (270 · 238 · 252) · `AGENT_TASKBOARD.md` (แถว ORDER-205 · 206 · 231 · 236 · 238 · 250 · 251 · 252 · 270 เท่านั้น) · `EA_SCORECARD_AND_REGISTRY.md`/`EA_MASTER_INDEX.csv` (แถว TsMom 992001 · SS1 LondonORB 992003 · MacdDiv · PivotBreakout) · `docs/memory_control/B1_DATASET.csv` · `_mt5_auto/**` (รันเทส 205/206/231/236) | `D:\Meta 5b` (portable) — **รับช่วงจาก REV04 ที่ปิดแล้ว** · 5c ใช้โดย worker (205/206) | `CLOSED` (2026-07-27 07:50) |
| `S-2026-07-26-REV04` | 2026-07-26 20:30 | **280-289** | `ea_projects/(TRD)_SuperTrendFlip/**` · `_mt5_auto/ab_sets/genstanding_stf/**` · `_mt5_auto/**` (รันเทส) · `AGENT_TASKBOARD.md` (แถว ORDER-280) | `D:\Meta 5b` (portable — BTC ต้องเลนเดียวกับ campaign เดิม) | `CLOSED` (2026-07-27 06:35 — **ปิดโดย session ถัดไปตามคำสั่ง user**; commit สุดท้ายของเลน = `862513fe` 07-26 19:40 ⇒ เงียบ ~11 ชม. · ORDER-280 ยัง `CLAIMED` ค้างที่ STEP 0 ไม่มีตัวเลขใดๆ — ใครมารับต่อต้องเริ่มที่ STEP 0 parity ใหม่) |
| `S-2026-07-26-CUTLOSS` (เขียนย้อนหลัง — เปิดก่อน ledger นี้จะถูกใช้จริงในวันนี้ ไม่ใช่การละเมิด) | 2026-07-26 ~18:00–20:30 | ไม่จองเลข (แก้ order เดิม ORDER-215/219/220/221/222 ไม่เปิดใหม่) | `AGENT_TASKBOARD.md` (แถว ORDER-215/219/220/221/222 เท่านั้น) · `EA_SCORECARD_AND_REGISTRY.md`/`EA_MASTER_INDEX.csv` (แถว NuiIndy/MatchaGrid) · `_mt5_auto/ab_sets/order215/**`, `order222/**` · `scripts/order21{5,2}*_cutloss_probe.ps1`, `check_stale_binaries.ps1`, `detector_digest.ps1` | **`D:\Meta 5b` (portable) ช่วงสั้นๆ 20:10-20:30** — ชนกับเลนที่ REV04 ประกาศไว้; `mt5_run.ps1`'s process-guard กันไม่ให้รันซ้อนกันจริง (คนละ launch คนละเวลา) แต่ไม่ได้เช็ค ledger ก่อนใช้ — แจ้งไว้ให้ REV04 เห็นว่าเลนถูกยืมใช้ช่วงสั้นๆ | `CLOSED` (2026-07-26 20:35) |

<sub>แถว `S-2026-07-26-GENSTANDING` เขียนย้อนหลังโดย session TRIAGE จากหลักฐาน git (commit `6df2d6b5`, `47319bef`,
`09a6fb7b`, `ca922653` + ไฟล์ที่ค้างใน working tree) — session นั้นเปิดก่อนที่ ledger นี้จะมีอยู่ ไม่ใช่การละเมิดกติกา.
มันทำงานบน ORDER-GEN-STANDING ซึ่งเป็น standing order ไม่กินเลขใหม่ **แต่จอง 240-249 ให้ล่วงหน้า** เพราะ
`check_order_collision.ps1` RULE 2 บล็อกเลขที่อยู่นอกบล็อกของทุกเลนที่ ACTIVE — ถ้าไม่จองให้ เลนนั้นจะโดนบล็อก
กลางคันทั้งที่ไม่ได้ทำอะไรผิด. การจองล่วงหน้า = **ผ่อนให้เท่านั้น ไม่ปิดกั้นอะไรเพิ่ม** จึงปลอดภัยที่จะเดาแทน.</sub>

## ประวัติเลนที่ปิดแล้ว

| session id | ช่วง | order block | สรุป 1 บรรทัด |
|---|---|---|---|
| `S-2026-07-27-VERIFY270` | 2026-07-27 ~08:00–10:00 | 390-399 (ใช้จริง 390) | **ตรวจ ORDER-270 ของ session อื่นเองก่อน review** — ยืนยันได้ทุกข้อ: `-Audit` 254s→**9.7s** · ผล bit-identical · chainwalk **11/11** · ชุด 103 **41/0** · ชุด 101 **25/1** (1 = pre-existing) · **วิธีเขาดีกว่าที่ใบสั่งเสนอ** (ปฏิเสธ path-filter เพราะมันเปลี่ยน "commit ไหนถูกเดินผ่าน" แล้ว history simplification อาจตัด merge ที่สำคัญ) · **แล้วเจอของจริง → ORDER-390:** inline code ใน status span ทำให้ `Get-StatusClass` มองไม่เห็น `REVIEWED` ⇒ **6 ใบนั่งบอร์ดเงียบๆ ทั้งที่ review แล้ว** (คลาสเดียวกับ ORDER-260) · แก้แบบแคบ + **กรงมาก่อนแก้** (statusclass 23/23, 2 เคสแดงก่อนแก้) ⇒ archivable 6→12 · **ย้าย 12 ใบ บอร์ด 51→39 · archive 274** · backlog **D24** = 2 negative suite รันต่อกันใน process เดียวไม่ได้ (false FAIL) · **ไม่แตะ ORDER-280** เพราะ SLBUFFER ที่ ACTIVE ประกาศแถวนั้นไว้ (กฎข้อ 4) |
| `S-2026-07-27-CUTLOSS-VERIFY` | 2026-07-27 09:05–09:25 | 370-379 (ใช้ 370-373) | ตรวจงาน 5 ใบเมื่อวาน (219/220/221/222/215) + handoff · **เจอช่องโหว่ในสคริปต์ตัวเอง: `check_stale_binaries` ไม่ส่อง `_vps_deploy/**` = ที่เดียวที่ binary ถูกส่งขึ้นชาร์ตจริง (0 record)** → ORDER-370 · เช็คมือแล้ว bundle Boss_16 ที่ attach ไป **ไม่ stale จริง** (ex5 07-24 20:13 > source 07-24 10:39) · บันทึกบั๊กที่ ORDER-341 เจอในสคริปต์เดียวกัน (first-wins status slot ⇒ advisory กลืน STALE 48 ตัว) · 371 = tick history `Meta 5b` เพี้ยน 14 เท่า · 372 = ขายืดหน้าต่างที่ 222 ค้างไว้ · 373 = user เคาะ 2 EA เงินจริง · handoff = `_triage/HANDOFF_2026-07-27_CUTLOSS_VERIFY.md` |
| `S-2026-07-26-GENSTANDING` | 2026-07-26 ~10:00–20:00 | 240-249 (ไม่ได้ใช้ — standing order) | ORDER-GEN-STANDING ชุด 2: matrix 19 cell → **VALIDATED CANDIDATE ตัวเดียว = BTCUSD H4 `rev03` pyramid** (MAIN 2.257 · BWD 3.949 · holdout 4.274 · MC ruin 0%) · lever ใหม่ 2 ตัวเข้า rev02/rev03 (ER gate · capped pyramid) · วัด swap ได้ว่า tester คิด POINTS แต่ไม่คิด INTEREST ⇒ `scripts/swap_adjust_crypto.py` · handoff = `_triage/HANDOFF_2026-07-26_SUPERTRENDFLIP_LEVER_CAMPAIGN.md` |
| `S-2026-07-26-CAGE` | 2026-07-26 20:50–21:40 | 300-309 (ไม่ได้ใช้) | **ORDER-270 root cause ปิดแล้ว** — suite ไม่ได้ค้าง มัน**ช้าจริง** (ผมวินิจฉัยผิดครั้งแรกเพราะดู CPU ของ process แม่) · ต้นเหตุ = chain-integrity walk ยิง git subprocess **3 ครั้ง/commit** × 502 commit = **~1,506 spawn** ต่อการเรียก 1 ครั้ง แต่มีแค่ **5 commit ที่แตะ archive** ⇒ ~1,491 ครั้งเป็นงานเปล่า · **ไม่แก้ walk** เพราะ path-filter อาจเปิดรู BLOCKER 6 (merge laundering) กลับมา → ต้องเขียน targeted test ก่อน · แก้ `B1_COHORT.md` เป็น running log (user เคาะ) · **แก้กฎข้อ 3 ของ ledger ที่ผมเขียนเกินจริงเอง** (path-limit ไม่กัน co-edit ในไฟล์เดียวกัน) · ⚠️ B1_DATASET rows 260/261 **ยังค้าง** (ไฟล์มีแถวของ REV04 ที่ยัง uncommitted) |
| `S-2026-07-26-TRIAGE-B` | 2026-07-26 18:45–20:15 | 270-279 (ไม่ได้ใช้ — ปิดใบเก่า) | **ORDER-260** แก้บั๊ก `Get-StatusClass` (substring `HOLD`/`OPEN`) → ปลด 17 ใบ + กรงใหม่ `run_statusclass_tests.ps1` (พิสูจน์แล้วว่า fail ได้) · **ORDER-261** เขียน review 28 ใบ + แก้ข้อความ 9 ใบ → ย้ายเข้าคลัง 51+3 ใบ **บอร์ด 96→42** · เปิด **ORDER-270** (negative suite 2 ชุดค้าง = validator ไม่มีกรง) · ⚠️ **B1_DATASET.csv rows ยังค้าง** (ไฟล์อยู่ในมือ session คู่ขนาน) |
| `S-2026-07-26-TRIAGE` | 2026-07-26 13:00–18:30 | 230-239 · 250-252 · 260-269 (ใช้จริง 230-239, 250-252, 260-261) | วางวงจรชีวิตงาน (`docs/WORK_LIFECYCLE.md`) + เกราะกัน session ชน 3 ชั้น · บอร์ด 102→95 order (ย้ายเข้าคลัง 22) · `_triage/` 198→51 ไฟล์ (ย้าย 153 + rewrite citation 138 จุด) · เปิด order ใหม่ 15 ใบจาก 27 รายการที่ handoff ทิ้งไว้ · handoff = `_triage/HANDOFF_2026-07-26_WORK_LIFECYCLE_AND_TRIAGE_SWEEP.md` |

## เลขที่ใช้ไปแล้ว (อัปเดตเมื่อจองบล็อกใหม่)

- สูงสุดที่ใช้จริง ณ 2026-07-27 = **280**
- ว่างและ**ห้ามใช้** (เว้นเป็นกันชน/รอยแผลเดิม): 207 · 208 · 209 · 223-229
- บล็อกถัดไปที่จองได้ = **400-409** (290-299 · 310-319 · 330-339 · 360-369 · 380-389 เว้นกันชน · 280-289 = REV04 (ปิดแล้ว แต่ ORDER-280 ยังค้าง ห้ามใช้เลขซ้ำ) · 300-309 = CAGE · 320-329 = GREENYELLOW · 340-349 = LEVERFAN · 350-359 = SLBUFFER · 370-379 = CUTLOSS-VERIFY)
