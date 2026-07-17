# Prompt เปิด session ใหม่ (EA_LAB continuation)

> คัดลอกบล็อกด้านล่างวางใน Claude Code session ใหม่ (repo D:\EA_LAB)

---

กลับมาต่องาน EA_LAB — รัน on-return protocol ก่อน: `git log --oneline -20` (หา [codex]/[zcode] +
commit ของ MRIS session), อ่าน handoff ล่าสุด (scratchpad `HANDOFF_2026-07-17B.md`) + `PROJECT_STATE.md`,
เช็ค AGENT_TASKBOARD DONE/BLOCKED, รัน `scripts/check_state.ps1`. HEAD ล่าสุด = `dafa8dc1`.

⚠️ **shared worktree:** อีก session ทำ MRIS (ORDER-073 Phase-2.5) อยู่ — เช็ค HEAD ก่อน stage, commit
**path-limited**, HEAD ขยับ=หยุด ([[shared-worktree-concurrent-writers]]).

⚠️ อ่านก่อนตัดสิน EA: CLAUDE.md VERDICT GATE + memory [[feedback-course-files-extract-idea]] (ใหม่:
Jobot/course no-SL = extract idea ไม่ skip) [[feedback-buildon-pf-gt-1]] [[signal-landscape]].

## งาน session นี้ (เรียง EV):

1. **⭐ ORDER-098-G = validate stat-arb candidate** (งานหลัก — ผลเด่นสุด session ก่อน)
   `PairSpread_StatArb` H4 EURUSD/GBPUSD EntryZ 2.5 = both-window PF 1.07/1.04 (candidate, ยัง selection-fit).
   ใช้ skill `robustness-validator`: (1) plateau map รอบ z2.5 (EntryZ 2.0/2.25/2.75 · ExitZ 0.3/0.5/0.7 ·
   ZWindow 80/100/120) both-window — ต้อง plateau ไม่ใช่ spike (z3.0 BWD dip 0.94 = ridge แคบ) (2) holdout
   (3) Monte Carlo (4) cross-pair (GBPUSD/EURUSD, EURCHF/USDCHF H4 z2.5). ผ่านครบ → demo candidate (corr-check).
   spec เต็ม = taskboard row ORDER-098-G · verdict = `_triage/ORDER098F_PAIRSPREAD_STATARB_VERDICT.md`

2. **#098 corpus ต่อ** (ถ้า 098-G เสร็จ) — concept ถัดจาก IDEA_CATALOG. currency-strength + FVG = สำรวจจบแล้ว
   (parked/reject). เหลือน่าลอง: News-entry (ต่อ infra 073), Divergence, harmonic/fib (ท้ายคิว).

3. **#4 crosses ที่เหลือ** — ปลดล็อกเมื่อ user โหลด history 2020-22 (GBPCHF/NZDCAD/AUDNZD/AUDCHF).

## EAs ใหม่ session ก่อน (review PASS + compile 0/0):
- `(EXP)_PairSpreadArb/PairSpread_StatArb.mq5` ← candidate (098-F/G)
- `(EXP)_CurrencyStrength/` + `(EXP)_CurrStrengthRanked/` (currency-strength, parked, meter core reusable)
- `(EXP)_FVGFill_RSIgate/` (reject)

## รอ user: attach Wave5 UJ 990303 · โหลด history #4 crosses (ทำวันหลัง) · git push = ใช้ได้แล้ว (verified)

Gotchas: compile `D:\Meta 5\MetaEditor64.exe /compile:` (exit 1 ปกติ เช็ค log "0 errors") · copy ex5 →
roaming 9CA16B\MQL5\Experts · tester = HEDGING login (stat-arb ต้องการ) · multi-symbol EA เทสได้ (basket
history ต้องมี) · ห้าม burst pace · ห้าม -ExecutionPolicy Bypass ใน agent brief · เก็บ main context ไว้ judge.
