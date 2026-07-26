# CODEX ORDER-145 — AdaptGridMC independent audit

Date: 2026-07-20  
Scope: audit-only; no source changes and no backtest run.  
Files reviewed:

- `ea_projects/(EXP)_AdaptGridMC/(EXP)_AdaptGridMC_rev01.mq5`
- `_mt5_auto/adaptgrid_mc_zone.py`

## Findings

### SEV-1 — hard-kill is not evaluated on every price/equity update

`ea_projects/(EXP)_AdaptGridMC/(EXP)_AdaptGridMC_rev01.mq5:129-136` returns immediately when the current bar is unchanged. The −20% equity test at lines 137-142 therefore runs only once per bar, not on every tick. An intrabar equity drawdown can cross the kill threshold and recover before the next bar without the kill firing. That does not satisfy a hard-kill expectation for every path and leaves the account exposed to an intrabar loss beyond the configured threshold.

### SEV-2 — persisted halt/cycle writes are unchecked

`ea_projects/(EXP)_AdaptGridMC/(EXP)_AdaptGridMC_rev01.mq5:141` and `:167` call `GlobalVariableSet()` without checking its boolean return value. The EA sets the in-memory halt/cycle state even if the terminal cannot persist the global variable. After a restart, the halt may be absent and trading may resume. The same persistence assumption exists for cycle-start equity, so a restart can lose the risk baseline. The `GlobalVariableCheck()` reads at lines 111-112 fail closed for an existing halt GV, but they cannot compensate for a failed write.

### SEV-2 — zone parser accepts non-finite prices and can emit invalid zones

`_mt5_auto/adaptgrid_mc_zone.py:34-38` accepts `nan`/`inf` because `float()` succeeds for those strings and there is no `math.isfinite()` validation. Those values can contaminate log returns, ATR, sorting, and the emitted P10/P90 snippet. The EA refuses only when comparisons with zero/order are false; NaN comparisons are false, so this is not a reliable fail-closed boundary for malformed external CSV input.

### MINOR — generated N does not match the EA's arithmetic level count

`_mt5_auto/adaptgrid_mc_zone.py:85` emits `floor((ZoneHi-ZoneLo)/spacing)`, while the EA computes `floor(...)+1` at `ea_projects/(EXP)_AdaptGridMC/(EXP)_AdaptGridMC_rev01.mq5:88`. The set-file `_01_MaxLevels` can therefore be one lower than the number of levels the EA actually builds (subject to the hard cap). This is a configuration/accounting mismatch, not an uncapped-level escape because the EA still clamps to 40.

### MINOR — zone generator does not enforce the campaign's 1000-bar input requirement

`_mt5_auto/adaptgrid_mc_zone.py:56-59` truncates to `--hist` but only rejects history shorter than `block + 2`. The order requires exporting at least 1000 D1 bars; the generator itself permits substantially shorter data and does not report/guard that condition. The upstream export procedure can enforce it, but the script is not self-protecting.

## Checklist passes

- Invalid/empty zone values: normal zero or reversed bounds cause `BuildLevels()` to return false and no order is sent (`:90-91`, `:115-116`, `:146`).
- MaxLevels and MaxTotalLot: checks occur before `CTrade.Buy()` (`:151-156`); lot normalization uses symbol min/max/step (`:65-67`).
- Bar-open gate exists (`:131`) and tester/live gate exists (`:148`).
- Zone bootstrap uses seeded block resampling with 24-day default blocks and 60-day paths (`adaptgrid_mc_zone.py:72-80`); the seed is explicit and reproducible for identical input bytes.
- Halt state is fail-closed when the halt GV exists (`:111`); reset is explicit via `_05_ResetHalt` (`:110`).

## Audit boundary

No verdict, scorecard update, EA edit, or backtest evidence was produced. ORDER-142 remains the separate backtest campaign.
