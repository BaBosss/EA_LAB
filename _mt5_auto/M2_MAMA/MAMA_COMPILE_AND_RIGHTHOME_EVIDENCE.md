# ExpertMAMA — compile + canonical right-home naked smoke (next candidate after ExpertMAPSAR)

Candidate: ExpertMAMA · source `D:\Forex\20_Selected EA\Advisors\ExpertMAMA.mq5` · SHA-256
`9D99ED8320D56651EC8B75C41A07C336B58AC265F04598AD5DD2824BCD670E51` (re-verified via
`Get-FileHash -Algorithm SHA256` immediately before this task's runs — matches the value handed
down in the task brief; no expected-hash was pre-registered for this candidate, so this run is
what establishes the on-record value).

Catalog provenance: `_triage/ORDER111_mq5_source_catalog.csv` row
`"expertmama","1","D:\Forex\20_Selected EA\Advisors\ExpertMAMA.mq5","6.3","","n","other","n"`.

Architecture (from source read, `CSignalMA` + `CTrailingMA` + `CMoneyNone`, standard Library
wizard chassis): single-position, no grid/martingale/recovery, no owner-gated risk ambiguity.
Family = trend/momentum, same class as ExpertMAPSAR — hence the same XAU/GBP right-home smoke.
`origin/master` at task start: `4db22b4ebe3a1eb09b6e05ca95af78a599a879c8` (matches task brief).

## Phase 1 — full input contract

All 9 declared `input` variables read directly from the source (`Inp_Expert_Title`,
`Inp_Signal_MA_Period/Shift/Method/Applied`, `Inp_Trailing_MA_Period/Shift/Method/Applied`) —
`Expert_MagicNumber` and `Expert_EveryTick` are plain globals, not `input`, so they are not part
of the tester-configurable surface. No value invented — every line below is the source's own
compiled-in default (`Inp_Signal_MA_Period=12`, `Inp_Signal_MA_Shift=6`,
`Inp_Signal_MA_Method=MODE_SMA(0)`, `Inp_Signal_MA_Applied=PRICE_CLOSE(1)`,
`Inp_Trailing_MA_Period=12`, `Inp_Trailing_MA_Shift=0`, `Inp_Trailing_MA_Method=MODE_SMA(0)`,
`Inp_Trailing_MA_Applied=PRICE_CLOSE(1)`), mirroring the enum-ordinal convention already accepted
for ExpertMAPSAR's set (`Inp_Signal_MA_Method=0`, `Inp_Signal_MA_Applied=1`).

Set file: `sets\ExpertMAMA_defaults.set` (9 lines, one plain value per line, no `||...||Y`
optimize-range suffixes):

```
Inp_Expert_Title=ExpertMAMA
Inp_Signal_MA_Period=12
Inp_Signal_MA_Shift=6
Inp_Signal_MA_Method=0
Inp_Signal_MA_Applied=1
Inp_Trailing_MA_Period=12
Inp_Trailing_MA_Shift=0
Inp_Trailing_MA_Method=0
Inp_Trailing_MA_Applied=1
```

**Note on the set-surface warning:** `mt5_run.ps1` printed `surface: UNDECLARED` for all 4 runs —
this `.set` predates the self-declaring-surface convention (`gen_default_preset.py`), same class of
warning already accepted for the ExpertMAPSAR M2/M3 evidence; carried forward per that same
convention. `stale-check` also reported `NO_SOURCE` because no `.mq5` named
`M2_MAMA_CANDIDATE_ExpertMAMA.mq5` exists under `D:\EA_LAB` (the binary is a renamed flat copy in
the terminal's own Experts folder, per the required deploy pattern below) — staleness is instead
confirmed the task-brief way, by hashing the real vendor source directly (see above).

## Phase 2 — fresh compile

Vendor source copied unmodified into `src\ExpertMAMA_original.mq5` (vendor corpus at
`D:\Forex\20_Selected EA\Advisors\` itself untouched). Compiled fresh via
`_mt5_auto\M2_MAMA\compile_mama.ps1` (same house convention as
`M2_WAVE5_C4_MAPSAR\compile_c4.ps1`: UTF-16 MetaEditor log, asserts `0 errors, 0 warnings` AND
that the `.ex5` artifact exists).

- MetaEditor: `D:\Meta 5\MetaEditor64.exe`
- Result: **0 errors, 0 warnings, 1160 ms elapsed, cpu='X64 Regular'**
- Compile log (copied into evidence): `compile\M2_MAMA_CANDIDATE_ExpertMAMA_compile.log`
- Deployed binary (per the ExpertMAPSAR lesson — the tester only resolves flat Experts-root
  names, `-Expert ExpertMAPSAR` did not resolve on lane 1): flat copy at
  `C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\M2_MAMA_CANDIDATE_ExpertMAMA.ex5`
  (132,148 bytes), named `M2_MAMA_CANDIDATE_ExpertMAMA`.

Classification: not applicable — compile succeeded cleanly, no blocker.

## Phase 3 — canonical right-home naked smoke

Lane: `D:\Meta 5` (`terminal64.exe`), DataDir `9CA16B8382AE4CF692710FB36B9DA355` — confirmed idle
(`Get-Process terminal64` returned nothing) before every run, so no lane-contention issue. Model 1,
MAIN window 2023.01.01–2025.12.31, single test via `scripts\mt5_run.ps1` (not the optimizer),
full default `.set` from Phase 1 unmodified, against the deployed
`M2_MAMA_CANDIDATE_ExpertMAMA` binary. Exactly these 4 cells — nothing else run, no optimization,
no BWD, no Model 4.

| Cell | Trades | Deals | PF | Net | Exp. payoff | Bal DD | Eq DD | Sharpe | RF |
|---|---|---|---|---|---|---|---|---|---|
| XAUUSD H1  | 92  | 184 | 0.22 | -1707.32 | -18.56 | 2128.94 (20.43%) | 2346.27 (22.50%) | -1.28 | -0.73 |
| XAUUSD M30 | 22  | 44  | 0.05 | -2081.14 | -94.60 | 2195.63 (21.71%) | 2478.61 (24.34%) | -1.33 | -0.84 |
| GBPUSD H1  | 24  | 48  | 0.55 | -68.32   | -2.85  | 152.65 (1.51%)   | 189.42 (1.88%)   | -0.21 | -0.36 |
| GBPUSD M30 | 134 | 268 | 1.59 | +74.77   | +0.56  | 125.44 (1.23%)   | 157.67 (1.55%)   | 0.26  | 0.47  |

**Execution validity (all 4 cells):**
- `truncation_check`: none truncated — all 4 traded through to the window end (idle tail 0 days),
  last deal 2025.12.30 in every cell.
- `leverage_check`: all 4 `MATCH` at requested/actual 1:100.
- `total_deals` = `2 x total_trades` exactly in every cell (184=2x92, 44=2x22, 48=2x24, 268=2x134)
  — clean open/close pairing, no orphaned or rejected orders visible.
- No init-error artifact visible in any of the 4 `.htm` reports.
- Invalid stops / failed entries / invalid volume / runtime errors: **JOURNAL_COUNTERS_NOT_CAPTURED**
  — `mt5_run.ps1` does not retain the tester Journal for single-test runs, so these counters are
  not directly observable from the `.htm` report alone. This is a clean read on the evidence this
  pipeline produces, not a Journal-level guarantee.
- Conclusion: execution validity is clean on every cell on all directly-evidenced surfaces;
  nothing here should be folded into (or blamed for) the weak performance read on the three
  losing cells.

## Pulse classification

Bars: PROCEED = trades>=100 AND PF>=1.20 · WATCH = trades>=100 AND PF 1.00-1.20 ·
THIN = trades<100 regardless of PF · NO_PULSE = trades>=100 AND PF<1.00.

| Cell | Trades | PF | Classification |
|---|---|---|---|
| XAUUSD H1  | 92  | 0.22 | **THIN** (trades<100) |
| XAUUSD M30 | 22  | 0.05 | **THIN** (trades<100) |
| GBPUSD H1  | 24  | 0.55 | **THIN** (trades<100) |
| GBPUSD M30 | 134 | 1.59 | **PROCEED** (trades>=100 AND PF>=1.20) |

## Right-home result

**CELLS CLEARING PULSE (PROCEED): GBPUSD M30** — the only cell of the four, so it is also the
deterministic PRIMARY (adequate participation, clean execution validity, PF 1.59, no tie to break
against another PROCEED cell).

**PRIMARY RIGHT-HOME CELL: GBPUSD M30** (134 trades, PF 1.59, net +74.77, bal DD 1.23%,
eq DD 1.55%, Sharpe 0.26, RF 0.47).

**FACTORY ROUTING: RIGHT_HOME_READY_FOR_M3.**

This is a naked-default single-cell pulse, not a verdict — per the VERDICT GATE, a default-param
smoke can only ever close/open a cell, never a concept. The other 3 cells (all THIN on trade
count, and 2 of them also badly loss-making — XAUUSD is clearly the wrong home for this
signal/TF combination on defaults) say nothing about whether an optimize ladder would move them;
that question is out of this task's ROI-stop scope. Whether GBPUSD M30's PF 1.59 survives
optimization, BWD, and Model 4 is likewise a question for the Control Tower's next dispatch, not
this task.

## ROI stop

This task ends here. No optimizer, no BWD, no Model 4 was launched regardless of the GBPUSD M30
result — that decision belongs to the Control Tower.

## Files changed

- `_mt5_auto/M2_MAMA/sets/ExpertMAMA_defaults.set` (new)
- `_mt5_auto/M2_MAMA/src/ExpertMAMA_original.mq5` (new — unmodified vendor copy)
- `_mt5_auto/M2_MAMA/compile_mama.ps1` (new — compile harness)
- `_mt5_auto/M2_MAMA/compile/M2_MAMA_CANDIDATE_ExpertMAMA_compile.log` (new)
- `_mt5_auto/M2_MAMA/reports/M3RH_MAMA_XAUUSD_H1.htm` (+ `.leverage_check.json`,
  `.truncation_check.json`, chart PNGs)
- `_mt5_auto/M2_MAMA/reports/M3RH_MAMA_XAUUSD_M30.htm` (+ sidecars)
- `_mt5_auto/M2_MAMA/reports/M3RH_MAMA_GBPUSD_H1.htm` (+ sidecars)
- `_mt5_auto/M2_MAMA/reports/M3RH_MAMA_GBPUSD_M30.htm` (+ sidecars)
- `_mt5_auto/M2_MAMA/MAMA_COMPILE_AND_RIGHTHOME_EVIDENCE.md` (this file)
