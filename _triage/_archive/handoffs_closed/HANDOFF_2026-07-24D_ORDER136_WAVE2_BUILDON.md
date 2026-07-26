# HANDOFF 2026-07-24D — ORDER-136 Wave 2 → BUILD-ON + session housekeeping

**Session model:** Opus-seat (single controlling session per user directive 2026-07-19).
**Scope:** started as an on-return triage ("มีงานอะไรต้องทำต่อ"), landed two committed verdicts (ORDER-197, ORDER-136 Wave 2) plus a NewsGuard status update, and produced 3 lesson memories. No live/demo `.set` touched. No EA promoted to real money.

---

## What got done (commits, newest first)

- `29e3e0a1` — **ORDER-136 Wave 2 CLOSED = BUILD-ON.** LOG13 escalation beats flat lot on Boss_14 GridLog GBPJPY leg-8 (magic 990208, the live-equivalent `dist=2.0` config).
- `3917c6f0` / `13dc7f43` / `86f4111c` / `d375099e` — the debugging trail that got there (data-gap → disk → RAM/pagefile root cause).
- `32f32402` — **ORDER-197 REVIEWED = NOT ADOPTED.** Fibonacci lot lever (`LotProg=56`) loses to the live PROG_LOG_POWER on Boss_14 XAU MAIN. (Closed the fxDreema campaign's B1/B3 MM-parts retrofit for that leg.)
- (earlier, ORDER-073) NewsGuard filename-mismatch marked RESOLVED(user) on all 3 real accounts.

## The headline result — ORDER-136 Wave 2 (BUILD-ON)

| Config | Window | Model | PF | Trades | eqDD% | Net |
|---|---|---|---|---|---|---|
| LOG13 (LotProg=55, live) | BWD 2020-2022 | 4 real-tick | **1.32** | 49 | **8.08** | 563.01 |
| FLAT (LotProg=50) | BWD 2020-2022 | 4 real-tick | 1.07 | 47 | 10.71 | 143.72 |
| both configs | MAIN 2023-2025 | 1 (fallback) | 1.57 (tie) | 40 | 5.29 | 818.25 |

- **On the stress window (BWD), the escalation lever clearly wins** — higher PF, ~4× net, AND lower eqDD despite bigger lots. Clears Wave 1's overlay-win bar.
- **On MAIN the lever is inert** (grid never stacks past level 1 in the calmer regime) → tie under Model-1, near-tie on a 2.7yr Model-4 proxy.
- **Practical takeaway: keep the live GBPJPY leg-8 on `LotProg=55`. Do not revert to flat.**
- Campaign's first positive result after Wave 1 lost → the reusable lever is in `EDGE_CATALOG.md`.

## The two user challenges that changed the outcome (both correct)

1. **"BWD<1 อย่าเพิ่งฆ่า, optimize อีกที"** → checking the flagged provenance discrepancy revealed Wave 2's original run used `_14_DistAtrMult=3.0`, but the ORDER-166-revalidated live config is `dist=2.0`. Re-run on the correct baseline flipped a "loss" (BWD 0.92) into a clear win (1.32). → memory `feedback-verify-set-matches-live-before-verdict`.
2. **"พื้นที่มันอยู่ที่ Drive D, ลบ cache ก็ไม่ช่วย, เช็คอีกที"** → traced the junction chain: the terminal's real data (bases 28.5GB, Tester, the EA) is on **D:** (`D:\MetaTraderData\...\9CA16B\`, 112GB free); `C:\...\9CA16B` is an empty stub. The MT5 error `"no disk space in ticks generating function"` was never a disk problem — it's a **memory/pagefile commit ceiling** (RAM ~4GB free of 32, pagefile+TEMP on the tight C:). → memory `mt5-no-disk-space-is-memory-ceiling`.

## Still OPEN / next steps

- **ORDER-136 campaign stays OPEN.** Wave3+ hosts (MacdDiv XAU / EmaStoRev / PivotBreakout_XAU) each need their entry **ported into the chassis first** (a build task, not a lever-flip) before an overlay can be tested. No cheap next cell — user's call when/if to queue one. DynClose-on-Kangaroo (from ORDER-197's deferral) also still open, needs an exit-owner conflict review first.
- **MAIN Model-4 for GBPJPY leg-8 is unmeasured** (non-load-bearing). If ever wanted: free RAM (close ChatGPT's 8 procs + spare Claude windows — closing Codex alone was NOT enough) OR add a pagefile on D:, then rerun `O136_W2RETEST_{BASE,FLAT}_MAIN_M4` from the sets in `_mt5_auto/ab_sets/order136_w2_retest/`. The BUILD-ON verdict does **not** depend on this number.
- **Provenance cleanup (flagged, not done):** three magics (990101/990208/990218) and two spacings (d2.0 vs d3.0) float around labeled "GBPJPY leg-8 config." DEPLOYMENTS.csv says the live magic is 990208; ORDER-166 revalidated `dist=2.0`. Worth a VPS-side confirmation of what's actually attached, then retiring the stale `.set` variants. Not urgent.

## Untouched / carried-over from the on-return triage (still waiting on user, unchanged)

- PERSIST_MIGRATION_ORDER132 checklist (set flag=true once on upgrade, then revert) — code blocker long cleared.
- ORDER-137 StoMultiTap fork (demo-isolate 991075 + ADX-gate, or shelve).
- portfolio_risk_admission coverage 338/946 pairs, portfolio still OVER the 25% budget with a ceiling bias — interpretation is a user decision.
- ⚠️ **A concurrent Sonnet-lane session was active earlier today** (ORDER-192b/195/196 — optimizer guard, [CFG] override coverage, V1 chassis deprecation) and also a CR-track session. Several of this session's commits rode along in / were sequenced against theirs on the shared taskboard (content preserved, attribution mixed — the documented shared-worktree pattern). Check `git log` before building on any of those.

## Gotchas reconfirmed this session

- Pre-commit hook on `AGENT_TASKBOARD.md` genuinely takes 3-7 min (not a hang) — commit in background, wait on the index.lock rather than force it.
- Shared working tree + parallel sessions = real index-lock contention; every commit here was path-limited to its own files and verified after the lock cleared.
- MT5 tester error strings lie (see the two memories); trace the physical data drive via the junction chain before deleting anything.
