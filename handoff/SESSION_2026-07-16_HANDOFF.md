# HANDOFF → next session (2026-07-16, Opus, EA-lane) — big clearing session

> อ่าน `VISION.md` → `PROJECT_STATE.md` → this file. ขัดกันเชื่อ repo + `check_state.ps1`.
> ⚠️ **session คู่ขนาน (Contract D):** Codex gpt-5.6-sol build ORDER-105 event-log อยู่ (hook `[experiment-events]
> ORDER-105` เห็นทุก commit). เลนนั้น owns `docs/memory_control/` + block ORDER-105. commit path-limited เสมอ.

## HEAD chain ของ session นี้: `7e0825d0` (codex) → `01aed69`+ (14 commits, ทุกอันผ่าน production hook)

## ✅ ปิดใน session นี้

1. **บอร์ด reconcile** — header ค้าง 10 ใบ sync (036/057/064/076/079/082/095-b1/097/102 + 065/066 ยืนยันปิดใน archive)
2. **ORDER-084 retro-audit judge + CLOSED** — กอง ก ~95 ฆ่าถูกกติกา · rescue queue 5 ตัว · PARKED-VERIFY(user) 2
3. **🥇 ORDER-098-B MacdDiv XAU H4 = DEMO-ELIGIBLE** — ผ่านครบ funnel (Model-1 plateau → Model-4 1.89/0.97/1.28
   → holdout → MC ruin 0% → corr 0.555<0.8) · bundle `_vps_deploy/MACDDIV_XAU` magic 999094 · **รอ user attach**
4. **ORDER-098-A FVGFill = REJECT** (no edge ทุก exit geometry, 22 runs)
5. **ORDER-104C HP λ1600 = plateau confirmed** → HP-denoise = reusable lever (EDGE_CATALOG)
6. **ORDER-106 GBPJPY rescue = ✅ REVIVE** (Model-4 confirm MAIN 1.56/BWD 1.11/holdout 1.50) → candidate leg-8
   ของ Boss_14 cohort (เหลือ finer sweep + corr<0.8 vs 7 legs)
7. **ORDER-084 rescue #2 XAU_NY = 🟡 regime-dependent** (H4 MAIN 2.0-2.43 แต่ BWD fail; ชอร์ตไม่ช่วย; 3 lever
   swept) → build-on = จับคู่ ORDER-057 regime-gate ไม่ใช่ deploy
8. **DEMO_DEPLOYMENT_PLAN.md restructure** — current-state บนสุด + archive เก่า (user บ่นอ่านยาก)
9. **SMC×STO idea (user) triaged** → ORDER-107 staged (cheap 2-stage smoke plan)
11. **⬛ ORDER-107 SMC×STO (user idea) = DEAD SKELETON** — build `(EXP)_EmaStoRev` (EMA-gate + STO reversion,
   no OB) + smoke 6 cell = ทุกตัว PF<1.0 (0.63-0.89, win% 58-67% = mean-reversion trap). แกนไม่มี edge → OB
   ไม่ช่วย → concept parked. cheap-death สำเร็จ. verdict = `_triage/_archive/verdicts/order104-126/ORDER107_SMCxSTO_STAGE0_VERDICT.md`
10. **🟩 ORDER-108 break-retest split (user idea) = BUILT + VALIDATED** — `(EXP)_BRK_SplitRetest` (market leg +
   pending buy-limit at retest). A/B Model-4: fill-rate ~90%, adverse-selection real, split regime-robust on
   Bars40 (1.93/1.97). **BUT retrofit on LIVE Bars55/TP8 = ไม่ยก** (config-conditional) → ห้าม retrofit ตัว live.
   lever banked (EDGE_CATALOG). verdict = `_triage/_archive/verdicts/order104-126/ORDER108_SPLIT_RETEST_VERDICT.md`

## รอบ 2 (afternoon, user เคาะ 4 ทิศ + ทำต่อ)
12. **MacdDiv Exness XAUUSDc set** = `_vps_deploy/MACDDIV_XAU/MacdDiv_XAUc_exness3d_v1.set` (Deviation 300 สำหรับ
   3-digit cent · digit-safe · README มี caveat feed-validation) — user จะทดลองบน cent port 10000 คืนนี้
13. **ORDER-106 GBPJPY finer sweep** → plateau ยกไป d1.5 (tp150 = 1.40/1.32, trades 93/51 = แก้ปม thin) =
   candidate leg-8 แข็งขึ้น · d1.5 Model-4 confirm ยังค้าง (ห้ามรันคู่ Model-4 อื่น)
14. **🟩 ORDER-091C-D1d pending-limit MT5 (Thread A) = BUILT + tested** `(EXP)_LwmaRev_Pending` · pending +0.05 PF/ไม้
   แต่ base reversion no-edge · **สรุปรวม pending 2 ฝั่ง = `_triage/_archive/one_off_analyses/PENDING_LIMIT_SYNTHESIS.md`** (pending = refinement
   ไม่ใช่ resurrector; split = form ที่ adoptable; spread-death revival คุ้มเฉพาะ post-spread PF≥0.95)

## 👉 คิวถัดไป (เรียง EV — pace 1-2/รอบ)

1. **🔼 ORDER-091C-D1d JUMSTOCH pending-limit** — **user reaffirm 2026-07-16 แรง** ("EA ตายเพราะ spread ตั้ง
   pending + ขยาย TP"). vehicle แรกของ pending-limit rescue. **นี่เป็น build (code) ไม่ใช่ batch** — user อยากลุย
   แต่ผมถามว่าเอา JUMSTOCH เป็นตัวแรกไหม ยังไม่ตอบ (ถามตอน probe รันอยู่). **เริ่ม session ถัดไปได้เลยถ้า user ยืนยัน.**
   spec อัปเดตครบใน taskboard: market-vs-pending × TP{+0,+2,+5} วัด fill-rate + EV/ไม้ (ไม่ใช่ PF เดี่ยว).
   ⚠️ pending-limit ช่วยเฉพาะ reversion — ห้ามแปะ breakout.
2. **ORDER-098-B ด่าน demo** — user attach MacdDiv XAU H4 bundle (+ 4 bundle เดิม Wave5×2/Breakout×2)
3. **ORDER-106 GBPJPY** — finer sweep dist{1.5,2,2.5} + corr<0.8 vs Boss_14 cohort → เสนอ leg-8
4. **ORDER-107 SMC×STO** Stage-0 smoke · **ORDER-084 rescue #3** ZSCORE (ranger pairs)
5. **ORDER-108 lever ต่อยอด (optional):** sweep offset/expiry บน Bars40 (ที่ split เวิร์ค) · หรือ build split
   variant ของ LondonConso (คนละ codebase — ต้อง build ใหม่) · lever พร้อมใช้กับ breakout build ใหม่ทุกตัว

## รอ user (mobile-answerable)
- ยืนยัน vehicle pending-limit ตัวแรก (JUMSTOCH?) · attach 5 bundle (บอกวัน → ลง DEPLOYMENTS.csv + judge)
- โหลด MT4 history (ปลด PARKED-VERIFY กอง ค: Phoenix/GBPJPY1H90PCWR)

## รอบ 3 (เย็น/ค่ำ — SMC×STO saga + anti-recurrence + death review)
15. **SMC×STO (ORDER-107) พลิกกลับเป็น candidate จริง** — ผมตีตายจาก default-smoke (ผิด gate) → user push →
   optimize (StoK 5→13) + ADX filter → **EURUSD H1 = demo candidate: Model-4 MAIN 1.39/BWD 1.19/HOLDOUT 1.14,
   plateau 6/7 neighbor.** EURUSD-only (ไม่ travel). bundle `_vps_deploy/SMCSTO_EURUSD` magic 991070.
16. **🔴 ANTI-RECURRENCE ระบบ (สำคัญสุด) — แก้ pattern "ตีตายเปล่าจาก default-smoke":** (a) CLAUDE.md GATE #1 +=
   ANTI-RATIONALIZATION block (b) signal-scanner Step 4 ลบ loophole "reversion-at-1.0=dead" (c) **warn-hook
   `scripts/check_verdict_kill.ps1` + `.githooks/pre-commit`** เตือนตอน commit kill-verdict ที่ไม่มี optimize
   evidence (warn-only exit 0) (d) memory `feedback-optimize-before-killing-reversion`.
17. **EA death review** = `_triage/_archive/one_off_analyses/EA_DEATH_TAXONOMY_AND_IMPROVEMENT.md` — 107 dead-pile: ~25 ตายจริง vs ~50+ กู้ได้.

## 🚀 START HERE — คิว session หน้า (เรียง EV, user เคาะให้ทำต่อ)
1. **🥇 ORDER ใหม่: regime-rescue pipeline** — เอา 29 EA regime-parked (`_triage/_archive/audits_and_investigations/RETRO_AUDIT_VERDICTS.csv` class regime)
   รันผ่าน `Regime.mqh` (ORDER-057) both-window. กองใหญ่สุด+เทคนิคพร้อม. user เลือก #1 นี้ให้ทำก่อน. **แตกเป็น
   order + ปล่อย agent (Boss_14 chassis มี _50_ regime lever อยู่แล้ว).**
2. attach 6 bundle (Wave5×2/Breakout×2/MacdDiv/SMCSTO-EUR) + MacdDiv cent-test คืนนี้ (Exness XAUUSDc set พร้อม)
3. GBPJPY d1.5 Model-4 confirm (leg-8) · ORDER-108 offset/expiry sweep · rescue #3 ZSCORE
4. gap อื่นจาก death-review: flat-lot-probe sweep กองมาร์ติงเกล · re-audit killed-correctly · walk-forward re-opt cadence

## Gotcha ยืนยันซ้ำ session นี้
- **ex5 ใน ea_projects/ หายได้** (ไม่ tracked) — FVGFill + MacdDiv หายทั้งคู่ → recompile `MetaEditor64.exe
  /compile:<path> /log:<log>` (~0.4s, 0/0) แล้วไปต่อ
- Meta5 (primary, hedging 146237) + Meta5b (portable) รัน Model-1 คู่ขนานทั้ง session ไม่ freeze · Model-4 เดี่ยว
- protected-set commit: stage `docs/memory_control/RECONCILE_EXCEPTIONS.md` (working, regen หลัง clean filter) คู่กับ
  AGENT_TASKBOARD.md เสมอ ไม่งั้น hook BLOCK
- corr gate reuse: `_mt5_auto/corr_*_cohort.py` (monthly-P&L จาก report "Out" rows) — ก็อปแก้ subject/cohort report ได้เลย
