# EA_CORE_ST03_LOOP_PLAN — ปิด framework loop ด้วย ST03 edge (แผนรัน Sonnet)

> **decision 2026-06-29 (ทางเลือก 2):** เอา edge ที่พิสูจน์แล้ว (ST_EA03, live OOS PF 2.47/2.62) มาเป็น
> เคสปิด loop ของ EA_CORE_V1 → พิสูจน์ว่า framework สร้าง EA grade พอร์ตได้.
>
> ⚠️ **อ่านก่อนทำ — สถานะจริง (ตรวจ 2026-06-29):** โค้ดไปไกลกว่าเอกสารเก่ามาก. **executor เขียนเสร็จแล้ว**
> แต่ **ผล validate ปัจจุบัน = overfit รุนแรง (FAIL)**. งานจริง = **diagnose overfit + หา durable set**
> ไม่ใช่เขียน executor ใหม่. รายละเอียดด้านล่าง.

**สำหรับ session ที่รัน:** ใช้ model Sonnet ได้. ทำตาม STEP 1→5 ตามลำดับ. กฎเหล็ก EA_LAB ทั้งหมด apply
(อย่าเชื่อ report เก่า — rerun ด้วย locked .set; ปิด MT5 GUI ก่อน automation; Model 4 บังคับ).

---

## A. สถานะโค้ดจริง (verified by file inspection 2026-06-29)

| ขา | สถานะจริง | หลักฐาน |
|---|---|---|
| **1 ENTRY** (v4 edge-trigger) | ✅ เขียน+wired+compile | `StrategySignal_v4.mqh` · A/B: PF 1.06→1.47, trades 571→120 |
| **2 EXECUTOR** (limit-order pyramid) | ✅ **เขียนเสร็จแล้ว** (ไม่ใช่ v1 market อีกต่อไป) | `CORE/ScaleExecutor_v2.mqh` — leg0 market + legs1..N pending (LIMIT/STOP) ระยะ Nearby, per-leg TP, OCO. compile 0/0 (`compile_se2_test.log`) |
| **wiring** | ✅ runner include v2 แล้ว | `TEMPLATE/EA_RUNNER_ST03.mq5:123` `#include "../CORE/ScaleExecutor_v2.mqh"` + ใช้ `ScaleExec2_Init/Refresh/Open/CloseAll/HasFilled/OpenSide` ครบ |
| **3 VALIDATE** | 🔴 **FAIL — overfit** | ดูตาราง B |
| **4 DEPLOY** | ⏳ block จนกว่า 3 ผ่าน | — |

**Runner inputs (levers ที่ปรับได้, ค่า default ปัจจุบัน):**
`InpLotRepeat=1` (จำนวน leg; 3=ST_EA03-style) · `InpTp3Pts=50` (leg ปิดแรก, points) ·
`InpNearbyPip=100` (ladder spacing points = ST_EA03 Nearby_PIP 10pip) · `InpPendingMode=2` (2=LIMIT scale-in / 3=STOP pyramid) ·
`InpEdgeTrigger=true` · `InpMagic` · `InpAllowLiveOrders` · `InpLotSizerMode=0`.

---

## B. ผล validate ปัจจุบัน = overfit (ทำไม loop ยังไม่ปิด)

variant pyramid (`EA_RUNNER_ST03B` "TG" = tiered-grid, ผล `_mt5_auto/reports/ST03B_TG_*.htm`):

| window | PF | Net | Trades | อ่านว่า |
|---|---|---|---|---|
| IS2024 (in-sample) | **7.08** | +27.0 | 98 | สวยเกินจริง |
| WF6_2025 (walk-fwd) | **0.32** | −93.8 | 118 | พังนอก sample |
| COVID2020 (stress) | 0.19 | −65.6 | 48 | พัง |
| GILT2022 (stress) | 0.30 | −89.0 | 107 | พัง |

**สรุป:** classic overfit (IS เป๊ะ → OOS/stress พังหมด). levers (Tp3/Nearby/LotRepeat) ถูก tune เข้า IS2024.
**loop ยังไม่ปิด.** การ deploy ST03 วันนี้ (#9, OOS 3.93) = **EA_RUNNER_ST03 LR2 replica คนละตัว** กับ
ST03B "TG" pyramid ที่ overfit — Sonnet ต้องยืนยันว่ากำลัง validate ไฟล์/variant/.set ตัวไหนก่อนเริ่ม.

---

## C. งานจริง — STEP 1→5 (Sonnet ทำตามลำดับ)

### STEP 1 — orient + ยืนยัน target (อย่าข้าม)
- [ ] อ่าน: `TEMPLATE/EA_RUNNER_ST03.mq5` (+ `EA_RUNNER_ST03B.mq5`), `CORE/ScaleExecutor_v2.mqh`,
      `DOCS/ST_EA03_REVERSE_ENGINEER_AND_V4_PLAN.md` (Part B §88-109).
- [ ] ตอบให้ชัด: **variant ไหนคือเป้า** (ST03 vs ST03B), ใช้ executor v2 จริงไหม, `.set` ปัจจุบันคืออะไร,
      ผล B มาจาก param ชุดไหน. เขียนสรุป 5 บรรทัดก่อนรันอะไร.
- accept: รู้แน่ว่าจะ validate binary+`.set` ตัวไหน.

### STEP 2 — reproduce A/B baseline (entry-only vs entry+pyramid)
- [ ] compile runner (headless, `vps-deploy-ops`/`mt5_run.ps1`). GBPUSD H1, **Model 4**, window สั้น
      (เช่น 2024.01–03) เพื่อ iterate เร็ว.
- [ ] A = `InpLotRepeat=1` (entry-only) · B = `InpLotRepeat=3, Tp3=50, Nearby=100, Mode=2`.
- accept: B trade-count ≈ ST_EA03 (~36 entry events), reproduce ผลเดิมได้ (sanity ว่า harness ถูก).
  ⚠️ per-tick OCO เคยค้าง — ใช้ freeze-guard (memory: mt5-backtest-freeze-guard), window สั้นตอน iterate.

### STEP 3 — diagnose overfit + หา durable set (หัวใจ)
- [ ] coarse grid **Model 2** (เร็ว, trade-count เป๊ะ, PF relative) บน levers:
      `InpTp3Pts∈{30,50,80,120} × InpNearbyPip∈{50,100,150} × InpLotRepeat∈{2,3} × InpPendingMode∈{2,3}`.
- [ ] รัน **IS 2023–2025 + OOS 2025–2026 พร้อมกัน** ทุก combo → rank ด้วย **min(IS_PF, OOS_PF)** (ไม่ใช่ IS อย่างเดียว — นี่คือกับดักที่ทำให้ PF 7.08 หลุดมา).
- [ ] top 3 combo → confirm **Model 4** (บังคับ — TP 5pip < 20pip ต้องใช้ real tick).
- accept: เจอ combo ที่ **OOS PF ≥1.40 และ retention OOS/IS ≥0.6** หรือสรุปได้ว่าไม่มี (→ STEP 5 fallback).
  ถ้าทุก combo OOS<1.0 = executor/edge ไม่ทนนอก sample → บันทึกแล้วไป STEP 5.

### STEP 4 — full robustness (เฉพาะถ้า STEP 3 เจอ durable set)
- [ ] IS/OOS เต็มบน **GBPUSD + USDCAD** H1 (คู่ที่ ST_EA03 proven) → เทียบ PF 2.47 / 2.62.
- [ ] Monte Carlo (PF 5th-pctile ≥1.4, ruin 0%) + walk-forward (WF3/5/6 ต้องไม่พังแบบ B).
- [ ] plateau check (broad flat ไม่ใช่ spike — ป้องกัน overfit ซ้ำ). ใช้ agent `ea-validator`.
- accept: verdict CANDIDATE+ ตาม `EA_SCORECARD` rubric.

### STEP 5 — decide + บันทึก
- **ถ้าผ่าน STEP 4:** loop ปิด ✅. build .ex5 + locked .set + bundle (`vps-deploy-ops`), magic ใหม่
  (ไม่ชน 990010/9397/9398). corr vs live ST_EA03 (คาดสูง = ไม่ใช่ leg ใหม่ แต่พิสูจน์ framework สำเร็จ).
- **ถ้าไม่ผ่าน:** ใช้ **fallback ที่ doc ระบุ** — ship ST_EA03 `.ex5` ที่ validated แล้ว (deploy อยู่),
  ลด EA_CORE เป็น R&D track. **ไม่เสียของ** เพราะ edge ยัง trade อยู่ผ่าน standalone.
- [ ] อัปเดต `PROJECT_STATE.md` (EA_CORE %, Decision log) + `EA_SCORECARD` + ตาราง B ในไฟล์นี้.

---

## D. นิยาม "ปิด loop สำเร็จ" + guardrails
- **DoD:** EA_RUNNER_ST03(/B) ผ่าน smoke→IS/OOS→MC→plateau gate เดียวกับ EA ที่ deploy แล้ว → ได้
  `.set`+`.ex5` เทรดได้. ไม่ต้อง corr ต่ำ (เป้า = พิสูจน์ capability ไม่ใช่หา leg ใหม่).
- **guardrails:** tight-TP + no-SL + multi-leg = **martingale-adjacent** → คง hard caps (max-lot/max-legs/
  deposit-load) เสมอ · Model 4 บังคับ · อย่า tune เข้า IS อย่างเดียว (rank min(IS,OOS)) · freeze-guard.
- **ทำไมคุ้ม:** ปิด loop ครั้งเดียว → ขา 1–2 reuse กับ signal อื่นได้ (graft entry ใหม่เข้า chassis เดิม) =
  value proposition ที่ยังไม่เคยได้. ความเสี่ยงต่ำเพราะใช้ edge ที่พิสูจน์แล้ว → ถ้าพังคือ executor ไม่ใช่ edge.

> อัปเดต checkbox + ตาราง B ที่นี่ + bump `PROJECT_STATE.md` ทุกครั้งที่ขยับ STEP.
