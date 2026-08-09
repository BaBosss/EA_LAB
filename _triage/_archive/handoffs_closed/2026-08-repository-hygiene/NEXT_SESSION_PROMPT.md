# Prompt เปิด session ใหม่ (EA_LAB continuation)

> คัดลอกบล็อกด้านล่างวางใน Claude Code session ใหม่ (repo D:\EA_LAB)

---

กลับมาต่องาน EA_LAB — รัน on-return protocol ก่อน: `git log --oneline -20` (หา [codex]/[zcode] + commit ของอีก
session), อ่าน handoff ล่าสุด `handoff/HANDOFF_2026-07-17C.md` + `PROJECT_STATE.md`, เช็ค AGENT_TASKBOARD
DONE/BLOCKED, รัน `scripts/check_state.ps1`.

⚠️ **shared worktree:** อีก session ทำ ORDER-073 (MRIS MacroGate Phase-2.5/#4) อยู่ — เช็ค HEAD ก่อน stage,
commit **path-limited**, HEAD ขยับ=หยุด ([[shared-worktree-concurrent-writers]]).

⚠️ อ่านก่อนตัดสิน EA: CLAUDE.md VERDICT GATE + memory [[signal-landscape]] (วันนี้เพิ่ม fib-pullback/harmonic/
divergence-reversion = DEAD) [[feedback-buildon-pf-gt-1]] [[feedback-pacing-batch-small]].

## สถานะเข้า session (session ก่อน = ORDER-098 corpus ปิดครบ)
- **ORDER-098 signal-hunt CLOSED** — stat-arb G/H validated+optimized (ExitZ0.3, both-window 1.14/1.15,
  holdout 1.23) → demo staged; concepts I/J/M DEAD; K maker + L OB-gate no-lift. **finding: cheap signal-hunt หมดแล้ว.**
- verdict = `_triage/_archive/verdicts/order076-098/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md` · handoff = `handoff/HANDOFF_2026-07-17C.md`

## งาน session นี้ (เรียง EV):

1. **⭐ ORDER-095 symbol-expansion batch 2** (งานหลัก — EV สูงสุดที่เหลือ, mold-mode บน EA proven)
   pace **1 EA/batch** (rule: ห้าม burst). breakout EXHAUSTED (XAG/GBP/EUR ตก BWD; USDJPY/US30 done).
   candidate ถัดไป: (a) **NuiIndy** (Dynamic RSI+ADX, live reversion survivor, `D:\Meta 5\MQL5\Experts\(NuiIndy)...(4).ex5`)
   = **compiled-only → ต้อง locked-ea-analyzer ก่อน** (แกะ escalation/symbol ปัจจุบัน + flat-lot check ว่า entry มี edge
   จริงก่อนขยาย — ห้ามขยายตัว martingale ที่ entry ไม่มี edge) แล้ว smoke rangers อื่น. หรือ (b) **Boss_14_GridLog**
   (demo flagship, เช็ค coverage 7 symbol เดิมก่อนเลือก symbol ใหม่). methodology = ORDER-095 order (flat-lot smoke →
   IS/OOS → corr<0.8 → demo). verdict = Claude.

2. **ORDER-098-C** — reusable MM-parts library (dynamic close_money + Fibonacci-capped lot) — code/doc extraction, ไม่ใช่ batch

3. **ORDER-091** — intake คลัง Forex 9 โฟลเดอร์ (แผนแม่บท, paced)

## ⚠️ รอ user (แจ้งเตือนทุก session จนกว่าจะ attach) — 8 bundle staged
`_vps_deploy/`: PAIRSPREAD_STATARB (990984, hedging+GBPUSD) · MACDDIV_XAU (990094) · ICHIADX_XAU (990068) ·
ICHIADX_USDJPY_BASKET · SMCSTO_EURUSD (991070) · WAVE5_XAU/XAG/USDJPY. attach → บอกวัน → Claude ลง DEPLOYMENTS.csv + judge +3 เดือน

Gotchas: compile `D:\Meta 5\MetaEditor64.exe /compile:` (exit 1 ปกติ เช็ค log "0 errors") · copy ex5 → roaming
9CA16B\MQL5\Experts · stat-arb/hex = HEDGING login · multi-symbol EA basket history ต้องมี · ห้าม burst pace ·
ห้าม -ExecutionPolicy Bypass ใน agent brief · เก็บ main context ไว้ judge · python เรียกผ่าน `. scripts/use_python.ps1` (bash ไม่มี python).
