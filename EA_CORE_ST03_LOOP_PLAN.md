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
- [x] อ่าน: `TEMPLATE/EA_RUNNER_ST03.mq5` (+ `EA_RUNNER_ST03B.mq5`), `CORE/ScaleExecutor_v2.mqh`,
      `DOCS/ST_EA03_REVERSE_ENGINEER_AND_V4_PLAN.md` (Part B §88-109).
- [x] ตอบให้ชัด: **variant ไหนคือเป้า** (ST03 vs ST03B), ใช้ executor v2 จริงไหม, `.set` ปัจจุบันคืออะไร,
      ผล B มาจาก param ชุดไหน. เขียนสรุป 5 บรรทัดก่อนรันอะไร.
- accept: รู้แน่ว่าจะ validate binary+`.set` ตัวไหน.

> **STEP 1 summary (Claude Fable, 2026-07-02 — file inspection):**
> 1. **เป้าของ loop = `EA_RUNNER_ST03B.mq5` "TG"** — ต่างจาก ST03 ตรงเพิ่ม TrendGate (ADX block:
>    `InpTrendGateOn=true, InpAdxMax=30`, บรรทัด 89–91). ตัวที่ deploy demo (990010) = `EA_RUNNER_ST03` + LR2 set — คนละตัว.
> 2. **executor v2 จริง** — ทั้งสอง runner include `ScaleExecutor_v2.mqh` (ST03:123, ST03B:129).
> 3. **.set ปัจจุบัน:** ST03B locked = `_mt5_auto\ST03B_trendgate_v1.set` (LotRepeat=2, Tp3=50, **Nearby=50**, Mode=2 LIMIT,
>    TrendGate on, magic 990010) · replica deployed = `_mt5_auto\ST03_lr2_sized_v1.set` (LR2, Tp3=50, Nearby=50, base lot 0.12, magic 990010).
> 4. **ผลตาราง B** มาจาก ST03B TG (`_mt5_auto\reports\ST03B_TG_*.htm`) — param ตาม trendgate set (LR2/50/50) **ไม่ใช่** LR3/Nearby=100 ที่ STEP 2 เขียนไว้ → STEP 2 ฝั่ง B ต้องใช้ค่าจาก locked set จริง.
> 5. ⚠️ magic 990010 ซ้ำกันระหว่าง ST03B set กับ replica ที่ deploy — **ห้ามเอา ST03B ขึ้น demo account เดียวกันโดยไม่เปลี่ยน magic**.

### STEP 2 — reproduce A/B baseline (entry-only vs entry+pyramid)
- [x] compile runner (headless — 0 errors 2 warnings, 2026-07-02, `TEMPLATE/compile_st03b_step2.log`;
      .ex5 copy เข้า terminal Experts แล้ว). GBPUSD H1, **Model 4**, window 2024.01–03.
- [x] **B (pyramid, locked TG set) = reproduce สำเร็จเป๊ะ:** PF **7.08** · net +26.99 · 61 open events ·
      100% real ticks (`_mt5_auto/reports/ST03B_STEP2_B_repro.htm`) → **ตัวเลข overfit ตาราง B = ของจริง
      ไม่ใช่ parse ผิด**. หมายเหตุ: 1 run ≈ 20 นาที (6.2M ticks) — ตั้ง TimeoutSec ≥ 2400.
- [x] **A (entry-only LR1) = PF 0.67 · net −15.58 · 13 trades** (`ST03B_STEP2_A_entry_v2.htm`;
      รอบแรกโมฆะเพราะ tester-gate — ดู hazard ด้านล่าง, ใช้ `ST03B_TG_A_entryonly_v2.set` ที่ตั้ง
      `InpAllowLiveOrders=true` แทน).
      ⚠️ **hazard ต้องจำ:** path single (`InpLotRepeat<=1`) ผ่าน ExecutionEngine ที่
      `Engine_SetLiveEnabled(InpAllowLiveOrders)` → ถ้า false = dry-run **0-trade เงียบๆ ใน tester**
      (ScaleExec2 path ยิง CTrade ตรง ไม่โดน). ทุก config LR1 ต้องตั้ง `InpAllowLiveOrders=true`.

> **STEP 2 CONCLUSION (2026-07-02):** signal v4 เพียวๆ **ไม่มี edge** บน GBPUSD window นี้ (PF 0.67 ขาดทุน)
> — กำไร IS ทั้งหมดมาจากโครง exit ของ executor (tight Tp3 group-OCO + no-SL + HoldBars) ที่ tune เข้า IS.
> สอดคล้อง (1) WF/stress พัง 0.19–0.32 (2) replica OOS PF 0.86 (verified ini ตรง locked set).
> **นัยต่อ STEP 3:** โอกาสเจอ durable set ต่ำ — ถ้า coarse grid (rank ด้วย min(IS,OOS)) ไม่เจอ combo ที่
> OOS≥1.40 & retention≥0.6 ให้ไป STEP 5 fallback ทันที อย่าฝืน tune ต่อ.
- accept: B trade-count ≈ ST_EA03 (~36 entry events), reproduce ผลเดิมได้ (sanity ว่า harness ถูก). ✅ B ผ่านแล้ว
  ⚠️ per-tick OCO เคยค้าง — ใช้ freeze-guard (memory: mt5-backtest-freeze-guard), window สั้นตอน iterate.

### STEP 3 — diagnose overfit + หา durable set (หัวใจ)
> ✅ **python blocker ปลดแล้ว (2026-07-02):** portable Python 3.12.10 อยู่ `D:\EA_LAB\tools\python312\`
> (embeddable, ไม่แตะ system PATH). ก่อนรัน script ที่เรียก `python` ให้ dot-source
> `. D:\EA_LAB\scripts\use_python.ps1` ก่อน (ตั้ง PATH เฉพาะ process). ทดสอบ `set_from_robust.py --help` ผ่านแล้ว.
> ⚠️ ยังเหลือ sub-blocker: รอบ 06-29 optimize ST03GRID ได้ **0 passes ทุก Model** — ต้อง diagnose config/ini ก่อนยิง grid ใหม่.
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
- [x] อัปเดต `PROJECT_STATE.md` (EA_CORE %, Decision log) + `EA_SCORECARD` + ตาราง B ในไฟล์นี้.

---

## ✅ LOOP CLOSED — STEP 5 DECISION (2026-07-02, Claude Fable): **FALLBACK INVOKED**

**STEP 3 ผล (หลักฐานปิดเคส):** coarse grid **complete enumeration 48 combos**
(Tp3{30,60,90,120} × Nearby{50,100,150} × LotRepeat{2,3} × PendingMode{2,3}),
IS 2023.01–2025.01 + OOS 2025.01–2026.06, Model 2, GBPUSD H1
(`_mt5_auto/optimizations/OPT_ST3G_IS.xml` + `OPT_ST3G_OOS.xml`):
- **OOS PF < 1.0 ทั้ง 48/48 combos** (ดีสุด 0.87 ที่ tp3=120/nb=50/LR2/pm2) · IS เองก็เพดานแค่ ~1.14
- Model 2 คือฝั่ง "มองโลกแง่ดี" ของ family นี้ (พิสูจน์แล้วใน per-symbol: M2 1.28–1.85 → M4 0.54–0.74)
  → M4 มีแต่แย่กว่า ไม่ต้อง confirm top-3
- สอดคล้อง (1) STEP 2: signal เพียวๆ PF 0.67 (2) qwen M4 rerun combo ที่ deploy (50/50/LR2/pm2): OOS 0.86
- หมายเหตุ optimizer: "0 passes" ของรอบ 06-29 = ปัญหาที่ **genetic mode (Optimization=2)** —
  Optimization=1 (complete) ทำงานปกติ (probe 4 passes + grid 96 passes สำเร็จ)

**คำตัดสิน:** ไม่มี durable set ในตระกูล param นี้ — edge ปี 2024 คือ regime ไม่ใช่โครงสร้าง.
- **EA_CORE = R&D track** (framework สมบูรณ์เชิงวิศวกรรม: signal v2–v5, ScaleExecutor_v2, risk stack,
  regression 1417 PASS — พร้อม reuse เมื่อเจอ signal ที่มี edge จริง)
- **production = ST_EA03 standalone** (live อยู่, magic 9397/9398)
- **ST03 replica (990010) บน demo:** คงไว้เก็บ data ถึง judge — คาดหวังใกล้ศูนย์/ลบ, เป็นตัวเก็ง kill แรก
- ห้ามกลับมา tune ตระกูล Tp3/Nearby/LotRepeat/PendingMode บน GBPUSD อีกโดยไม่มี signal ใหม่ (48 combos ปิดแล้ว)

---

## D. นิยาม "ปิด loop สำเร็จ" + guardrails
- **DoD:** EA_RUNNER_ST03(/B) ผ่าน smoke→IS/OOS→MC→plateau gate เดียวกับ EA ที่ deploy แล้ว → ได้
  `.set`+`.ex5` เทรดได้. ไม่ต้อง corr ต่ำ (เป้า = พิสูจน์ capability ไม่ใช่หา leg ใหม่).
- **guardrails:** tight-TP + no-SL + multi-leg = **martingale-adjacent** → คง hard caps (max-lot/max-legs/
  deposit-load) เสมอ · Model 4 บังคับ · อย่า tune เข้า IS อย่างเดียว (rank min(IS,OOS)) · freeze-guard.
- **ทำไมคุ้ม:** ปิด loop ครั้งเดียว → ขา 1–2 reuse กับ signal อื่นได้ (graft entry ใหม่เข้า chassis เดิม) =
  value proposition ที่ยังไม่เคยได้. ความเสี่ยงต่ำเพราะใช้ edge ที่พิสูจน์แล้ว → ถ้าพังคือ executor ไม่ใช่ edge.

> อัปเดต checkbox + ตาราง B ที่นี่ + bump `PROJECT_STATE.md` ทุกครั้งที่ขยับ STEP.
