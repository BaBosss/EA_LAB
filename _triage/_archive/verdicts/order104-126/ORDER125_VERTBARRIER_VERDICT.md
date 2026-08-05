# ORDER-125 — vertical-barrier exit `_2_MaxHoldBars` — VERDICT (Opus 2026-07-19)

**VERDICT: lever BUILT+HARDENED (default OFF, byte-identical) · A/B on host Boss_14 GBPJPY H4 = NO LIFT — DEAD-ON-HOST at Model-4 (the deciding model) ทุกค่าที่ทดสอบ.** Lever คงอยู่ในแม่พิมพ์เป็น opt-in dial สำหรับ host อนาคตที่ไม่ใช่ grid — ห้าม enable บน grid/DCA family.

## A/B evidence (host = locked BOSS14_GBPJPY H4 leg8 set · MAIN 2023-25 / BWD 2020-22)

| Run | Model | net | PF | trades | eqDD | max basket |
|---|---|---|---|---|---|---|
| base | M1 MAIN | 803.78 | 1.55 | 40 | 5.33% | 82.9d |
| MH130 | M1 MAIN | 1432.91 | 2.16 | 47 | 5.33% | 31.6d |
| MH390 | M1 MAIN | =base | 1.55 | 40 | 5.33% | 82.9d |
| base | M1 BWD | 271.87 | 1.23 | 31 | 8.20% | 168.7d |
| MH130 | M1 BWD | −637.02 | **0.73 ❌** | 42 | 12.38% | 31.6d |
| MH390 | M1 BWD | 388.17 | 1.23 ✓ | 49 | 9.43% | 90.9d |
| base | **M4** MAIN | 1057.99 | 1.56 | 55 | 9.23% | 65.2d |
| MH390 | **M4** MAIN | =base | 1.56 | 55 | 9.23% | 65.2d (ไม่เคย fire) |
| base | **M4** BWD | 209.77 | 1.11 | 50 | 9.40% | 203.4d |
| MH390 | **M4** BWD | **−368.02** | **0.85 ❌** | 51 | **11.08%** | 117.4d |

- **MH130 (~1 เดือน):** dead ที่ M1 — BWD 0.73. MAIN lift แรง (1.55→2.16) = **regime-fit ห้ามไล่** (การตัดที่ช่วยใน MAIN คือการตัดที่ฆ่าใน BWD).
- **MH390 (~3 เดือน): M1 หลอกว่าผ่าน → M4 พลิกเป็นตาย** (BWD PF 1.11→0.85 · net +210→−368 · eqDD แย่ลง). ไม่เข้าแม้ middle case (DD ก็แย่ลง net ก็แย่ลง).
- Fix รอบ Codex (inception latch) ทำให้ barrier fire **เร็วขึ้นเท่านั้น** → มีแต่แย่ลงสำหรับ MH390 — ไม่ต้อง re-run เพื่อ verdict.

## กลไกที่เรียนรู้ (จ่ายแล้ว — เข้า EDGE_CATALOG)

1. **Recovery tail ของ grid คือเครื่องยนต์ ไม่ใช่ waste:** basket 203 วันของ BWD สุดท้าย recover จริง — time-cut = realize tail loss ที่ไม่จำเป็น. ตรงข้ามสัญชาตญาณ ops ("basket ค้างนาน = ปัญหา") — บน Boss_14 มันคือแหล่งกำไรครึ่งหนึ่งของ BWD.
2. **M1→M4 flip บน exit lever:** M1 (control points) ประเมิน path ของ basket ใต้น้ำหยาบเกิน — เห็น MH390 BWD "เท่าเดิม" ทั้งที่ M4 จริงขาดทุน. ยืนยันซ้ำ: **exit/time lever บน grid ต้องตัดสินที่ M4 เท่านั้น** (เพิ่มจาก precedent ORDER-126 ที่ SL lever ก็ M4-deciding).
3. Vertical barrier เหมาะกับ **single-position / momentum EA** (holding-time exit เป็นเรื่องปกติของ trend-following) — ยังไม่ทดสอบ; ถ้าจะใช้ ให้เปิด A/B บน host เช่น SuperTrend/TrendRider ก่อนเสมอ.

## Codex blind review (commit `b6ca0f6e`) → 3 MAJOR + 3 MINOR — แก้ 5 / accept-documented 1

| Finding | Fix |
|---|---|
| MAJOR-1 clock reset เมื่อ leg เก่าสุดปิดเอง | `g_exit_basket_inception` latch ที่ flat→non-flat, เคลียร์เมื่อ broker-flat เท่านั้น (in-memory; restart = re-derive จาก oldest open leg — fire ช้าลงได้ ไม่มีทาง fire เร็วขึ้น, documented) |
| MAJOR-2 iBarShift −1 ไม่เช็ค | guard: −1 → log น้อยครั้ง + retry tick ถัดไป (ห้าม fallback wall-clock — over-count ข้าม weekend = fire เร็วผิด) |
| MAJOR-3 Boss_16 silent no-op | OnInit WARN ชัดเจน (Kangaroo owns exits) |
| MINOR-4 discretionary vs safety policy | คง discretionary — inception latch ทำให้ predicate monotonic ตลอดอายุ basket (rationale in-code) |
| MINOR-5 partial-milestone leak (pre-existing, ทางใหม่เปิดให้ถึง) | `Exit_ResetBasketCycleState()` เรียกจากทุก flat path (CloseBasket success + natural flat ×2 + Init) |
| MINOR-6 `_Period` mutability | accept-by-design (dial เป็น bars-on-chart-TF), documented in-code |

## Cage

- pre-fix: compile 0/0 ×9 · tests 7/7 · tpl_regression 8/8 CLEAN (commit `b6ca0f6e`)
- post-fix: compile 0/0 ×9 · tests 7/7 · tpl_regression 6/8 OK + 2 drift ที่ปิดครบ:
  - **Boss_18 n=0** = 0-trade artifact ที่รู้จัก (gotcha 2026-07-19) → solo rerun = **6020 / −2498.85 ตรง baseline เป๊ะ** = CLEAN
  - **Boss_14 n 56→84, net/PF/eqDD เหมือนเดิมทุกสตางค์** = ผลตรงของ MINOR-5 bugfix (regression set เปิด partial 50/75 — baseline เก่า encode พฤติกรรม leak ที่ basket ใหม่สืบทอด done-flag แล้วข้าม partial) → **baseline re-pin n=84** หลัง solo rerun reproduce เป๊ะ ×2 (589.34/16.64/84/1.50%)

evidence: `_mt5_auto/reports/ORDER125_B14_*.htm` (10 runs) · sets `_mt5_auto/ab_sets/order125/`
