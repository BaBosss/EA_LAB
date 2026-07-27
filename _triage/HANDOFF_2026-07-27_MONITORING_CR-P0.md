# HANDOFF — Monitoring / Control Room track (CR-P0 + CR-TRACK Phase-1)

> **Track scope:** monitoring sensors + Control Room snapshot ONLY. NOT the EA-verdict track
> (ORDER-350/373/390, cutloss campaign, LEVERFAN, BasketGuard, greenyellow — that is a separate
> concurrent session; do not touch its rows). Owner of this track = Claude lead (ops/evidence, no
> verdict authority). Author: Opus-seat, 2026-07-27.

## What shipped (done + verified)

**CR-TRACK Phase-1 (commits `fb24adf` orders · `2539d11` code · `2875d0b` CR-005-lite-b · taskboard DONE):**
- CR-003a false-green fix: `daily_monitor.ps1` exits 1 when any `governance_scope=LAB_MANAGED`
  account is not FRESH (per-account coverage on top of the old all-accounts stale guard).
- CR-003b `portfolio\ACCOUNTS.csv` new owner file (6 accts LAB_MANAGED) + snapshot reads account
  universe from it + stamps `governance_scope` on every `system_health` entry. Registered in
  PROJECT_STATE §0.5. NOTE: user later added `base_equity=100000` to 463666728 (raised from 10000
  on 2026-07-25; DD-as-%-of-equity falls ~10x → 25% portfolio budget stops binding on that acct).
- CR-002c `floating_risk` section (wires AccountSnapshotExporter output).
- CR-002d unknown_magics split ACTIVE/HISTORICAL by 14d last_seen.
- CR-TOOL-01 pathspec commit in daily_monitor (shared-worktree index-race guard).
- CR-005-lite-b expected-vs-actual `rate_flag` (UNDER_RATE detector) from expectations.csv.
- Snapshot schema v2→v3 (additive). Regression cage held: 13 summary numbers byte-identical.

**CR-P0 exporter merge (commit `eda4733`):**
- DealsExporter.mq5 + OrdersExporterMT4.mq4 now ALSO emit the floating snapshot (one EA covers
  deals + floating). MT5 includes tested `AccountSnapshot_Core.mqh`; MT4 uses new
  `AccountSnapshot_CoreMT4.mqh` (extracted verbatim). Deals path byte-identical. Compiled 0/0,
  deployed to all 6 monitor terminals. Same EA names → rotation needed no logic change.
- **PROVEN LIVE 2026-07-27:** after the morning rotation reloaded the new binary, MT5 accounts that
  were BLIND now emit floating. Current state: **6/6 health FRESH, 4/6 floating FRESH.**

**CR-P0 user-manual (done by user):** 69424711 login (was never logged in) + 463666728 login
(had dropped) both fixed 2026-07-26. Key lesson confirmed: a new demo account would NOT have fixed
69424711 — the problem was terminal↔server reach + investor password, not the account. Account kept,
its 5 unique deployments preserved.

## OPEN — what's left (this track)

1. **[P1] 2 accounts still floating-BLIND** — reopen/rotate with the new binary:
   - **463666728**: rotation loads the EA then dies with `EURUSDm symbol synchronization timeout`
     (~5 min) and gets removed BEFORE a stable snapshot — recurring since 07-21. Root cause = the
     rotation chart symbol `EURUSDm` won't sync on this crypto/multi-asset demo (its real positions
     are BTCJPYm/XAGUSDm/XAUUSDm per the account). **Fix: change 463666728's `symbol` in
     `scripts\monitor_rotation.ps1` (line ~23) from `EURUSDm` to one it reliably carries — likely
     `XAUUSDm` or `BTCUSDm` (verify against its Market Watch first).** The snapshot EA reads
     account-level data so the chart symbol only needs to *exist + sync*.
   - **415573666**: authorized + synced clean this morning (7 positions) but produced no snapshot
     and no "DealsExporter loaded" line — investigate why the EA didn't attach/run on this one
     terminal (rotation entry vs profile). Deals health still FRESH from a prior run.

2. **[P2] Re-log the CR-P0 taskboard note** — my earlier AGENT_TASKBOARD.md note was lost to a
   concurrent session's `checkout` (shared worktree). The exporter merge is permanently recorded in
   commit `eda4733`; only the board pointer is missing. Re-add under the CR-TRACK Phase-1 tranche
   when the board is quiet (concurrent session was very active on it 07-27).

3. **[P2] rate_flag caveat (CR-005-lite-b)** — Gold_Kangaroo L1-4 on 141049900 flag UNDER_RATE
   (obs 2.6-6.9/wk vs expWk 34.3). Likely an expectation-basis mismatch (backtest trade-count basis
   ≠ live MT4 closed-order counting), not a silent EA. Reconcile `trades_per_month_expected` for
   those 4 magics in expectations.csv, or confirm the EA really is under-trading. Advisory only —
   does not touch the promotion bar.

4. **[P3] Optional Codex blind-audit of the exporter merge** — read-only monitor code (no trade
   function), deals path byte-identical, snapshot is the tested core → doctrine does NOT mandate it
   (not money/live-trade logic). Run only if extra assurance wanted.

## NOT started (later CR phases — roadmap, not this session)
CR-003 full health engine (NORMAL/WATCH/PROBATION/QUARANTINE states + action queue + replay test) ·
CR-004 TODAY screen + AI advisor V1 (FACT/INTERPRET/ACTION/EVIDENCE format) · CR-005 full drift
engine (locked expected profile per EA, PF-band + MAE/MFE + slippage) · CR-006 portfolio control ·
CR-007 semi-autonomous ops (fast Common\Files reader every 1-5 min = the REAL floating-risk watch;
the daily rotation snapshot is once/day and near-useless for live position risk).

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| floating BLIND 463666728 — **สาเหตุที่เดาไว้ (symbol) ผิด**; จริง = ไม่มี saved login ในโฟลเดอร์ portable | ORDER-400 (OPEN, รอ user login `/portable` ครั้งเดียว) |
| floating BLIND 415573666 — **สาเหตุที่เดาไว้ (EA ไม่ attach) ผิด**; จริง = update-day `/config` path ถูกตัดที่ช่องว่าง + rotation ปล่อย orphan | DONE (`c297295d`, verified 4/6→5/6) |
| rate_flag Gold_Kangaroo L1-4 reconcile (expectation-basis) | DONE (`c297295d`, basket-vs-leg unit mismatch) |
| CR-P0 exporter merge (built · compiled · deployed · proven live 4/6) | DONE |
| CR-P0 user logins 69424711 + 463666728 | DONE |
| CR-TRACK Phase-1 (CR-003a/b · CR-002c/d · CR-TOOL-01 · CR-005-lite-b) | DONE |
| Codex blind-audit ของ merge (ตัดสิน: ไม่บังคับ — read-only ไม่ใช่ money code) | DONE |

<sub>later CR-003..007 full phases = roadmap (`ROADMAP.md` Phase 4.5) ไม่ใช่ forward work ของ session นี้ จึงไม่อยู่ในตารางนี้.</sub>

## Gotchas carried
- Shared worktree: 2+ Claude sessions share HEAD/index. Always pathspec-commit; a bare commit or the
  other session's broad `git add`/`checkout` will sweep/lose your work. My taskboard note proved it.
- pre-commit hook inspects the WHOLE staged index — another session's half-staged protected file
  (ARCHIVE_INDEX.md) blocked my pathspec commit. Wait for their work to settle, don't --no-verify.
- git commit can exceed 2 min on the append-chain hook — allow >=5 min, killing mid-hook risks a lock.
- Monitor exporters write ONLY while the terminal is open; the morning rotation opens each ~7 min to
  capture. AccountSnapshot/DealsExporter both write on OnInit (immediately) but skip when login=0.
