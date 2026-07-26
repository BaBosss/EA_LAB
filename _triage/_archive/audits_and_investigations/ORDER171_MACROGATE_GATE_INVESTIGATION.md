# ORDER-167 — MacroGate gate investigation: why 990120 rerun reproduced the gate-OFF trade count

**Status: DATA + finding, no verdict, no keep/kill/promote/demote language, no EA_SCORECARD /
DEPLOYMENTS.csv / EA_MASTER_INDEX edits.** All test runs used lane 2 only
(`D:\Meta 5b\terminal64.exe`, `-DataDir "D:\Meta 5b" -Portable`). Lane 1 was never touched.

## Bottom line

**(b) — the gate is not broken. It fails open exactly as designed when its regime CSV has no
row covering the backtest date range, and the file sitting at the path it reads today only
covers 2026-07-17 → 2026-07-23. The original 235-trade validation used a *different, temporary*
2024-covering CSV placed at the same filename, which was later overwritten by the live
rolling-snapshot file. The ORDER-166 rerun innocently pointed at today's live file and got the
honest "no data for this era → don't veto" answer.** Reconstructing the original 2024 timeline
CSV and rerunning the identical config reproduced the original result almost exactly: **235
trades, PF 1.02, net +7.44, eqDD 0.65%** (original: 235 trades, PF 1.01, net +2.80, eqDD 0.58%).
The fail-open behavior on missing/out-of-range data is a documented design choice
(`ea_template/core/MacroGate_Core.mqh` header, "Fail-safe (same doctrine as NewsGuard)"), but it
is worth the user's attention as a live-safety-relevant property — see "Design flaw?" below.

## 1. Gate implementation — fail-open confirmed, file:line evidence

`ea_template/core/MacroGate_Core.mqh` (read-only, not edited).

- **Loading**: `MG_LoadRegime(fname, common)` (lines 163–231) opens the CSV once, at `OnInit`
  (called from `ea_template/core/LabCore.mqh:102`, `MG_LoadRegime(_MG_RegimeFile, _MG_InCommon)`).
  It is **not reloaded per bar** in the tester — `MG_Tick`'s per-pass freshness re-check is
  explicitly skipped for the tester (`MacroGate_Core.mqh:277`, `if(mg_ok &&
  !MQLInfoInteger(MQL_TESTER) ...)`), so whatever the file contained at `OnInit` is what the
  entire backtest runs against.
- **The critical branch — no row on-or-before "now"** (`MacroGate_Core.mqh:296–303`):
  ```
  int r = MG_RowAsOf(nowServer);
  if(r < 0)
  {
     // now is before the first regime row - nothing known yet, stay inert (no gate)
     MG_ClearAll("no regime row on-or-before now");
     return;
  }
  ```
  `MG_RowAsOf` (lines 236–245) returns the index of the most recent CSV row with
  `time <= nowServer`, or **-1** if every row is *later* than `nowServer`. During a 2024
  backtest, if the loaded CSV's earliest row is 2026-07-17 (all rows later than any 2024 bar),
  `r` is -1 on **every single bar of the run** → `MG_ClearAll` clears/never-sets the block and
  lot-mult GlobalVariables for the whole test → **zero vetoes for the entire backtest**, while
  the EA still honestly logs `_MG_SelfGate=true` was applied (the input flag and the file-load
  succeeding are both true; it's the row-lookup that comes up empty).
- Other fail-safe branches (file missing, stale by `mg_staleMaxHours`, zero valid rows,
  non-ascending rows, or a row-gap vs `mg_rowStaleMaxHours`) all funnel to the same
  `MG_ClearAll("fail-safe: ...")` at lines 287–296 or 306–315 — this is a deliberate,
  documented **fail-open** design (header comment, lines 18–22: *"Fail-safe (same doctrine as
  NewsGuard): regime file missing / unparsable / file older than StaleMaxHours / newest usable
  row older than RowStaleMaxHours -> guard INACTIVE: every GV we own is CLEARED (never leave an
  EA throttled)... The guard NEVER acts on stale/absent data."*). The "no row before now" branch
  at line 298 is the same doctrine applied to the case where the file loaded fine but doesn't
  cover the queried era — it is not a separate bug, it is the same fail-safe philosophy hitting a
  case the original design probably didn't anticipate would matter (backtesting an old year
  against a live-only rolling file).
- Wiring confirmed in `ea_template/core/LabCore.mqh:97–103`: `MG_Setup(..., 8760, 168)` — 365-day
  file-staleness ceiling, 7-day row-gap ceiling — neither of which trips here, because the file
  itself was fresh (modified today) and the "no row before now" branch is checked *before* the
  row-gap-staleness branch and returns first.

## 2. The actual CSV files — confirmed, they don't cover 2024

| path | rows | date range | notes |
|---|---|---|---|
| `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files\EA_LAB_mris_regime.csv` (global Common — what lane-1 **and** lane-2-portable both actually read, see §finding-during-repro) | 4 | 2026.07.17 09:20 → 2026.07.23 00:37 | live rolling snapshot, refreshed by `scripts/mris/mris_export_regime.ps1` via the daily chain |
| `D:\EA_LAB\portfolio\EA_LAB_mris_regime.csv` (repo copy) | 4 | identical to above | same file, same mtime, same md5 — repo copy is a straight mirror of the live one, not a separate artifact |

Both are byte-identical today (verified by direct read + md5). **Neither has ever contained 2024
data** — confirmed by full git history below.

## 3. Git history — confirms the hypothesis directly

```
git log --follow -- portfolio/EA_LAB_mris_regime.csv
5ef41b98 2026-07-19  [auto] daily monitor snapshot 2026-07-19
75ee3eb2 2026-07-19  [auto] daily monitor snapshot 2026-07-19
e321eee9 2026-07-18  [auto] daily monitor snapshot 2026-07-18
01ae94d8 2026-07-18  [claude] MacroGate Part A pipeline + bundles (demo-attached 2026-07-18)
```

`portfolio/EA_LAB_mris_regime.csv` was **created** at `01ae94d8` (2026-07-18 17:28) and from birth
only ever held the live rolling snapshot starting `2026.07.17 09:20` — `git show
01ae94d8:portfolio/EA_LAB_mris_regime.csv` shows exactly one row, same content shape as today.
This file was never the source of the original full-year-2024 validation.

The original validation (`MG_HARD_USDJPY_ON.htm`, `_mt5_auto/ini/MG_HARD_USDJPY_ON.ini`,
`FromDate=2024.01.01 ToDate=2024.12.31`, `_MG_RegimeFile=EA_LAB_mris_regime.csv`,
`_MG_InCommon=true`) ran **earlier the same day**, at commit `e219db8e` ("ORDER-073 #4: MacroGate
UN-PARKED"), which added `portfolio/mris/backtest/regime_full_2024.csv` — **263 lines, dated
2024.01.01 00:00 → 2024.12.31, states NEUTRAL/RISK_OFF/STRESS across the year (142 calm + 82
risk-off days, matching the AB_VERDICT prose exactly)**. That file was generated by
`scripts/mris/mris_backtest_timeline.ps1` (its own header: *"emit a dated regime timeline CSV the
MacroGate EA reads in the strategy tester"*) and — per the commit's own workflow at the time —
was placed under the literal filename `EA_LAB_mris_regime.csv` inside `Common\Files` for the
duration of that validation run. Ten hours later, the "Part A pipeline" work (`01ae94d8`)
overwrote whatever sat at that path with the live rolling-snapshot generator, and the daily
chain has kept refreshing it with recent-only dates ever since. **The historical 2024 file was
never committed under the live path — it only exists, uncorrupted, at
`portfolio/mris/backtest/regime_full_2024.csv`.**

So: the original 235-trade number and today's 333-trade rerun both honestly read a file named
`EA_LAB_mris_regime.csv` in `Common\Files` — they just weren't the *same* file. Nothing was
corrupted or silently changed; two different generations of pipeline work happened to reuse one
filename for two different purposes (one-off historical backtest fuel vs. live daily monitoring
feed), and nothing recorded that collision anywhere an operator would see it before rerunning.

## 4. End-to-end reproduction (lane 2 only)

**First attempt (informative negative result):** placed `regime_full_2024.csv` at
`D:\Meta 5b\Common\Files\EA_LAB_mris_regime.csv` and `D:\Meta 5b\MQL5\Files\EA_LAB_mris_regime.csv`
(guessing portable mode redirects `FILE_COMMON` locally) and reran
(`_mt5_auto/reports/ORDER167_990120_MacroGate_CSVFIX.htm`). Result: **still 333 trades, PF 0.90,
net -66.89** — unchanged. Tester log (`D:\Meta 5b\Tester\Agent-127.0.0.1-3000\logs\20260723.log`)
proved why: `[MACROGATE] regime loaded: 4 row(s)...` — it read the **global** Common\Files (the
live 4-row file), not either local copy. **Finding: `-Portable` does NOT redirect `FILE_COMMON` to
a local folder for this terminal build — `_MG_InCommon=true` resolves to the single
machine-wide `%APPDATA%\...\Terminal\Common\Files\` shared by every terminal instance on this
Windows user, portable or not.** This is useful information beyond the immediate finding: lane 1
and lane 2 are **not** isolated with respect to `FILE_COMMON` reads/writes, only `MQL5\Files`
(non-common) is.

**Second attempt (the real test):** backed up the live global file
(`C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files\EA_LAB_mris_regime.csv`, md5
`1f8d38d96b7182ff49a3542f314ce3e6`) to the scratchpad, overwrote it in place with
`portfolio/mris/backtest/regime_full_2024.csv`, reran the identical `.set`/window on lane 2
(`_mt5_auto/reports/ORDER167_990120_MacroGate_GLOBALFIX.htm`), then **immediately restored the
original file and verified the restored md5 matches exactly** (`1f8d38d9...` before and after).
Total window the doctored file sat at the live path: under 4 minutes (one tester run).

| | Trades | PF | Net | eqDD |
|---|---|---|---|---|
| **Original validation** (`MG_HARD_USDJPY_ON.htm`, 2026-07-18) | 235 | 1.01 | +2.80 | 57.73 (0.58%*) |
| **ORDER-166 rerun** (today, live-only CSV) | 333 | 0.90 | -66.89 | 1.32% |
| **ORDER-167 reproduction** (today, 2024-covering CSV restored) | **235** | **1.02** | **+7.44** | **0.65%** |

(*original eqDD cited as 57.73 money / 0.58% in the AB_VERDICT doc, consistent scale with the
0.65% reproduction.)

Tester log confirms the mechanism fired, not just the trade count:
`D:\Meta 5b\Tester\Agent-127.0.0.1-3001\logs\20260723.log`:
```
[MACROGATE] regime loaded: 262 row(s), 0 skipped, file age -22431.7 h, server = CSV +0 h
...
[EXEC] MACROGATE block active (MACROGATE_BLOCK_990120) - new order skipped   (×13,733 tick-checks)
...
[MACROGATE] gate CLEARED magic=990120 (deinit reconcile)
```
Gate toggled ON/CLEARED **11 times** across the year (matches "142 calm + 82 risk-off days" —
several distinct risk-off stretches), and vetoed new-order attempts throughout each ON window.
This is the actual veto mechanism operating exactly as the original validation described it —
not an artifact of a different bug.

## 5. State restored / cleanup

- `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\Common\Files\EA_LAB_mris_regime.csv` —
  restored to its exact original bytes (md5-verified `1f8d38d96b7182ff49a3542f314ce3e6`, matching
  pre-test). This is the file the live dashboard/daily chain reads — it is back to the live
  4-row rolling snapshot, unmodified from before this investigation.
- `D:\Meta 5b\Common\Files\EA_LAB_mris_regime.csv` and `D:\Meta 5b\MQL5\Files\EA_LAB_mris_regime.csv`
  — deleted (were test-only artifacts from the first, ineffective attempt; the empty `Common`
  folder under `D:\Meta 5b` was also removed).
- `D:\EA_LAB\portfolio\EA_LAB_mris_regime.csv` (repo copy) — never touched.
- No file under `ea_template/core/*`, `ea_template/sets/regression/*`, `portfolio/DEPLOYMENTS.csv`,
  `EA_SCORECARD_AND_REGISTRY.md`, or `EA_MASTER_INDEX.csv` was modified. No `git add`/`git commit`
  was run. New files this investigation added (uncommitted, left for review):
  `_mt5_auto/reports/ORDER167_990120_MacroGate_CSVFIX.htm(+.png)`,
  `_mt5_auto/reports/ORDER167_990120_MacroGate_GLOBALFIX.htm(+.png)`,
  `_mt5_auto/ini/ORDER167_990120_MacroGate_CSVFIX.ini`,
  `_mt5_auto/ini/ORDER167_990120_MacroGate_GLOBALFIX.ini`, this file.

## Design flaw worth fixing? (not fixed here, per task constraints)

Yes — flagging for the orchestrator's judgment, not fixing:

The fail-open doctrine itself (never leave a *live* EA throttled on bad data — verified sound and
intentional, matches NewsGuard precedent, was Codex-hardened 2026-07-18 for 7 findings) is
reasonable **for live trading**. But the same code path has a second, unintended consequence in
the **backtest/validation** context that nothing currently guards against: **a regime-gated EA
backtested over any date range the loaded CSV doesn't cover silently runs completely ungated,
while still truthfully reporting `_MG_SelfGate=true` in its own Inputs section.** There is no log
line, warning, or report annotation that says "this backtest ran 0% gated" versus "this backtest
ran fully gated" — an operator has to notice the trade count matches a known gate-OFF baseline (as
this investigation did) or read the tester Journal for `[MACROGATE] regime loaded` / "no regime
row on-or-before now" lines to find out. For a mechanism whose entire selling point is "it changes
the trade count and P&L," a silent, indistinguishable-from-success no-op is a real footgun for
future re-validations — not just this one. It is also filename-fragile: the historical backtest
CSV and the live monitoring CSV happened to share the exact name `EA_LAB_mris_regime.csv` in
`Common\Files`, with nothing preventing that collision from recurring (e.g. `regime_full_2024.csv`
could be renamed/reused under the live name by a future session without realizing it overwrites
the live monitoring feed, or vice versa as happened here). Two independent, cheap mitigations
exist if the user wants them later: (a) have `MG_Tick`'s "no row on-or-before now" branch print a
distinct, loud one-time Journal line (not just the quiet `MG_ClearAll` reason string) so it shows
up in a report's Journal tab; (b) keep historical backtest-fuel CSVs under a name that can never
collide with the live path (e.g. always require an explicit `_MG_RegimeFile` override in any
backtest `.set`/`.ini`, never rely on the chassis default matching the live filename). Not
implemented — this file is investigation only, per task constraints.
