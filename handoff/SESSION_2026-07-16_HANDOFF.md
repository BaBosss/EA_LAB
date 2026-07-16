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

## 👉 คิวถัดไป (เรียง EV — pace 1-2/รอบ)

1. **🔼 ORDER-091C-D1d JUMSTOCH pending-limit** — **user reaffirm 2026-07-16 แรง** ("EA ตายเพราะ spread ตั้ง
   pending + ขยาย TP"). vehicle แรกของ pending-limit rescue. **นี่เป็น build (code) ไม่ใช่ batch** — user อยากลุย
   แต่ผมถามว่าเอา JUMSTOCH เป็นตัวแรกไหม ยังไม่ตอบ (ถามตอน probe รันอยู่). **เริ่ม session ถัดไปได้เลยถ้า user ยืนยัน.**
   spec อัปเดตครบใน taskboard: market-vs-pending × TP{+0,+2,+5} วัด fill-rate + EV/ไม้ (ไม่ใช่ PF เดี่ยว).
   ⚠️ pending-limit ช่วยเฉพาะ reversion — ห้ามแปะ breakout.
2. **ORDER-098-B ด่าน demo** — user attach MacdDiv XAU H4 bundle (+ 4 bundle เดิม Wave5×2/Breakout×2)
3. **ORDER-106 GBPJPY** — finer sweep dist{1.5,2,2.5} + corr<0.8 vs Boss_14 cohort → เสนอ leg-8
4. **ORDER-107 SMC×STO** Stage-0 smoke · **ORDER-084 rescue #3** ZSCORE (ranger pairs)

## รอ user (mobile-answerable)
- ยืนยัน vehicle pending-limit ตัวแรก (JUMSTOCH?) · attach 5 bundle (บอกวัน → ลง DEPLOYMENTS.csv + judge)
- โหลด MT4 history (ปลด PARKED-VERIFY กอง ค: Phoenix/GBPJPY1H90PCWR)

## Gotcha ยืนยันซ้ำ session นี้
- **ex5 ใน ea_projects/ หายได้** (ไม่ tracked) — FVGFill + MacdDiv หายทั้งคู่ → recompile `MetaEditor64.exe
  /compile:<path> /log:<log>` (~0.4s, 0/0) แล้วไปต่อ
- Meta5 (primary, hedging 146237) + Meta5b (portable) รัน Model-1 คู่ขนานทั้ง session ไม่ freeze · Model-4 เดี่ยว
- protected-set commit: stage `docs/memory_control/RECONCILE_EXCEPTIONS.md` (working, regen หลัง clean filter) คู่กับ
  AGENT_TASKBOARD.md เสมอ ไม่งั้น hook BLOCK
- corr gate reuse: `_mt5_auto/corr_*_cohort.py` (monthly-P&L จาก report "Out" rows) — ก็อปแก้ subject/cohort report ได้เลย
