# HANDOFF 2026-07-27 — เคลียร์กองเขียว+เหลืองทั้งหมด (lane GREENYELLOW)

> อ่าน `PROJECT_STATE.md` → ไฟล์นี้ · กติกาการทำงาน = `docs/WORK_LIFECYCLE.md` · เลนที่เปิดอยู่ = `docs/SESSION_LEDGER.md`
> **อย่าเชื่อไฟล์นี้เหนือ repo** — ขัดกันเมื่อไร เชื่อ repo แล้วแก้ไฟล์นี้

## บริบท

user ถามว่ามีงานอะไรค้างที่ไม่ชน session อื่น แล้วสั่งว่า "ทำเขียวกับเหลืองทั้งหมดเลย"
เหลือง (231/236/205/206) ต้องใช้เลน MT5 ที่ `S-2026-07-26-REV04` จองไว้ ⇒ **ปิดเลน REV04 ตามคำสั่ง user**
(commit สุดท้ายของมัน `862513fe` 07-26 19:40 เงียบมา ~11 ชม. · ORDER-280 ยัง `CLAIMED` ค้างที่ STEP 0 ไม่มีตัวเลขใดๆ)

**ปิดไป 7 ใบ · เหลือ 1 ใบครึ่ง** (236 = STEP 1 ปิด STEP 2 รอ runner)

## เส้นเรื่องของรอบนี้: 4 ใน 8 ใบสั่ง เขียนอะไรบางอย่างไว้ผิด

นี่ไม่ใช่การบ่น — มันคือ pattern ที่ควรจำ **ใบสั่งที่เขียนตอนยังไม่ลงมือ มักประเมิน scope ต่ำและวางบาร์ผิดจุด**

| ใบ | ใบสั่งเขียนว่า | ของจริง |
|---|---|---|
| **238** | 5 สคริปต์ | **16** — และตัวอันตรายสุดไม่อยู่ในลิสต์: `run_backtest.ps1` มี `-ToDate=2026.05.29` เป็น **ค่า default** เรียกเปล่าๆ ก็กิน holdout 5 เดือนเงียบๆ |
| **270** | แก้ด้วย path-filter | path-filter **เปิดรู BLOCKER 6 กลับมา** — ใช้วิธีอื่น (blob-OID) ที่ยังเดินครบทุก commit |
| **251** | mirror เข้า repo | commit แรก**ไม่ได้ mirror อะไรเลย** (gitlink) แต่รายงานว่าสำเร็จ 131 ไฟล์ |
| **236** | บาร์ MAIN≥1.2 AND BWD≥1.0 | บาร์นั้น**วัด host ไม่ได้วัด lever** — host ผ่านอยู่แล้วก่อนใส่ lever |
| **206** | fan `_02_SlAtrMult` {1.5,2.0,2.5} | base อยู่ที่**ขอบล่างสุดของช่วง** ⇒ แยกไม่ออกว่า plateau หรือหน้าผา |

## ปิดไปแล้ว

- **ORDER-270** `3a2cee7e` — 254s → **7.6s**. ไม่ใช้ path-filter ที่ใบสั่งเสนอ (เปลี่ยน "commit ไหนถูกเดิน" = เปิดรู BLOCKER 6);
  ใช้ `cat-file --batch-check` map commit→blob OID (content address ⇒ OID เท่ากันคือ byte เท่ากัน) + batched `rev-list --parents`.
  **กรงมาก่อนโค้ดตามข้อห้ามของใบสั่งเอง** — `run_chainwalk_tests.ps1` 11 เคส พิสูจน์ว่า fail ได้ก่อน (perf 18.39s→0.35s).
  ซ่อมชุด 103 ที่ fixture เน่าตาม hook ด้วย (ตอนนี้อ่านรายชื่อจาก hook เอง). ยืนยัน 11/11 + **41/41** + `-Audit` ผลไม่เปลี่ยนสักหลัก
- **ORDER-238** `805a443a` — แบนเนอร์ 12 ไฟล์ · §9 ขยาย 3 ไฟล์ (พิสูจน์ว่ายิงได้) · `qwen_batch_runner` **ปฏิเสธการรัน** เว้นแต่ `-SpendHoldout2026H1`
- **ORDER-252** `6f2d9c47` — `check_block_staleness.ps1` warn-only · จับ ORDER-073 ได้เอง · STALE 11 / dangling 4 / unresolved 96
- **ORDER-251** `6aa19f62`→`e56c357f` — mirror 33 ไฟล์ + hash cage + `check_state` §10 · **commit แรกผิด เก็บไว้ในประวัติ**
- **ORDER-231 + 250** `7cd82d9a` `2e18a7e3` — MC TsMom + **ของจริงคือ corr**: วัด corr ของ 992001 ทำให้บัญชี 415573666 ลดจาก 40.10% → **33.91%**
  (DD ตัวมันเอง = 0.72 จุด · การไม่เคยวัด corr = 6.19 จุด) · corr 992003 ปิดครบ 13/13 max |r| 0.543 < 0.8
- **ORDER-205 / 206** — worker (Sonnet) รัน 5 symbol ครบ · **BUILD-ON ทั้งคู่ ไม่มีตัวไหนตาย**

## 3 อย่างที่ user ควรรู้ (ไม่ต้องทำอะไรวันนี้ แต่มันเปลี่ยนวิธีอ่านตัวเลข)

1. **บาร์ `PF-5th ≥ 1.0` ตกไม่ได้เลยกับ MC ที่เราใช้อยู่** — order-resampling รักษา multiset ของไม้ ⇒ net และ PF **invariant**
   มีแต่คอลัมน์ DD ที่มีข้อมูล · **ทุก verdict ที่เคยอ้าง "PF-5th ผ่าน" เป็นหลักฐาน = อ้างเลขที่ขยับไม่ได้** (เข้าเกณฑ์เดียวกับกฎ guard-evidence)
2. **1088 คู่ correlation ทั้งพอร์ตยังอยู่บน default 1.0** = ประเมินความเสี่ยงสูงเกินจริงอย่างเป็นระบบตรงที่ไม่มีข้อมูล
   เคส 992001 แสดงราคาไว้ชัด: **6.19 จุด จากการไม่เคยวัด** เทียบกับ 0.72 จุดจากความเสี่ยงจริง
3. **`TsMom 992001` MAIN re-run ได้ PF 2.75 ไม่ใช่ 3.72 ที่ทะเบียนเขียน** — จำนวนไม้เท่ากันเป๊ะ (26) ⇒ สัญญาณเดียวกัน fill ต่างกัน
   บันทึกไว้แล้ว **ยังไม่ reconcile** — เป็นญาติกับ gotcha `btc-tick-data-differs-per-mt5-install`

## งานถัดไปที่ชัดที่สุด

- **ORDER-236 STEP 2** — 4 cell พร้อมรัน บาร์ pre-register แล้ว (delta vs control ในเลนเดียวกัน) · runner หยิบไปได้เลย
- **ORDER-206 fan ลงล่าง** `_02_SlAtrMult` {0.75, 1.0, 1.25} — ตัวเดียวที่ตัดสินว่า GBPJPY 1.37 คือ plateau หรือหน้าผา
- **ORDER-205 optimize USDJPY H4** — บ้านที่ผ่าน both-window แล้วแต่ยังไม่เคย optimize สักครั้ง (`_01_LookbackBars` inert อย่าเสียเวลา)
- **ORDER-280** ยัง `CLAIMED` ค้างที่ STEP 0 ไม่มีตัวเลข — ใครรับต่อต้องเริ่ม parity ใหม่

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| กรง validator ช้า 1,506 git spawn | ORDER-270 |
| `2026.06.01` ค้างในสคริปต์ที่ guard มองไม่เห็น | ORDER-238 |
| staleness linter | ORDER-252 |
| คลัง skill อยู่นอก repo ไม่มี version control | ORDER-251 |
| 992001 TsMom ไม่เคยมี Monte Carlo | ORDER-231 |
| SS1 LondonORB 992003 ไม่มี order-of-record + corr | ORDER-250 |
| MacdDiv_Naked H4 symbol expand | ORDER-205 |
| PivotBreakout H4 symbol expand | ORDER-206 |
| lever 2 ตัวไม่เคยรันสักเซลล์ — STEP 2 (4 cell) ยังไม่รัน | ORDER-236 |
| GBPJPY SL fan ฝั่งต่ำกว่า 1.5 (plateau หรือหน้าผา) | ORDER-206 |
| optimize MacdDiv บน USDJPY H4 (บ้านที่ผ่าน both-window) | ORDER-205 |
| ORDER-280 rev04 ค้างที่ STEP 0 ไม่มีตัวเลข | ORDER-280 |
| บัญชี 463666728 currency cent vs USD | ORDER-230 |
| MacroGate 990120 disposition | ORDER-232 |
| flag `--resolve-single-leg-baskets` รอ Codex audit | ORDER-233 |
| PERSIST_MIGRATION checklist | ORDER-234 |
| บาร์ 30 ไม้ไม่พอดีกับ 4 EA | ORDER-235 |
| RSI-MR หาง basket ยาวกว่าวัน judge | ORDER-239 |
| 4 commit hash ที่ resolve ไม่ได้ (102/103/128) | BACKLOG-D23 |
| 1088 คู่ correlation ที่ยังอยู่บน default 1.0 | BACKLOG-D8 |
| PF-5th เป็นบาร์ที่ตกไม่ได้ภายใต้ MC ปัจจุบัน | BACKLOG-D11 |
| TsMom PF 3.72 vs 2.75 reconcile | ORDER-231 |
