# Boss19 P4B Source-Bound Unit Export Pilot Result

Status: **BLOCKED / RESEARCH_ONLY / BROAD RERUN LOCKED**

Canonical runtime head: `691428cb0ee97f2faabff7be88d5d27927785ee3`.
Pilot cell: `H3-C03-MAIN` — XAUUSD H4, MAIN `2023.01.01..2025.12.31`, Model 1.
HOLDOUT: `UNSPENT`. Optimization: `NONE`.

Machine-readable owner: `_mt5_auto/p4b_boss19_regime/p4b_unit_export_pilot_result.json`.
Result SHA-256: `076999b2ebcae813d4a6dc7142104341462bdede5ed09b4907bb7fcaf27d5a74`.

## Evidence

The repaired diagnostic build compiled `0 errors / 0 warnings` with source SHA `cbf15bcb8d539329cb5a4b58b4b14be0013bf23987d0489c12c6d66dbe1d7b34`, EX5 SHA `4e13ce88fdc17bd00ef55e7f66d3c5e40c8c7e7a096b5279f147c7b2fd58ae35`, and stamped receipt `br-c46767414fe5491994ad05ef9fd8dd44`.

Strategy parity remained exact on the preregistered comparable fields: PF `4.39`, net profit `4445.51`, `113` trades, equity DD `13.34%`, `4637` bars, `4238991` ticks, history quality `98`, leverage `1:100`, full-window eligible. Parent report SHA is `e98bd8a8d795f553ad686fa6e45eba3c27278bef7080c4156d5c3e4529510ba9`; repaired child report SHA is `1584f43442203e8aa868e119e674a61b6a457d649e3e27b8ce8ca4e05337ac11`.

The tester finalizer ran successfully and logged `final snapshot rows=223 history_deals=227`, followed by `OnTester result 0`. The source snapshot contains `113 IN`, `110 OUT/OUT_BY`, and `113` distinct position IDs.The tester log records three additional trading closes at `2025.12.30 23:59:59`: deal `225` sell `0.02` via order `571`, deal `226` sell `0.01` via order `572`, and deal `227` sell `0.01` via order `573`; each is explicitly marked `position closed due end of test`.

The current MQL finalizer admits rows only when symbol matches, exact EA magic matches, and deal type is BUY/SELL. The tester log proves symbol and trading type for deals 225–227, but these deals are absent from the selected rows. Therefore the magic predicate is the only remaining current predicate consistent with their exclusion. The direct magic values were not exported, so this result does **not** claim a numeric magic value for those three deals.

A separate harness defect is also proven: `run_unit_export_cell.ps1` captures `$started=Get-Date` in local time but compares it with `LastWriteTimeUtc`, causing a false `source export is stale` refusal in UTC+07. The source was actually rewritten at local `2026-09-01T18:56:33+07:00` after the run began.

## Interpretation

The strategy did not drift. The blocker is confined to evidence instrumentation/finalization plus one runner time-basis bug.

The first bounded repair solved the callback end-of-test timing problem by adding a final history snapshot, but it did not establish a source-bound rule for tester-forced closes whose current metadata does not pass the exact EA-magic filter. Treating those closes as owned merely because they are late, similar volume, or close in order sequence would violate the attribution contract.

This milestone therefore does not authorize a second implicit repair or any broad evidence run.## Decision

`PILOT_BLOCKED_FAIL_CLOSED_NO_BROAD_RERUN`.

The 36-cell source-bound rerun remains `LOCKED`. P4A and the accepted classifier timeline remain unchanged. No HOLDOUT, optimization, risk/default, candidate, DEMO/LIVE, deployment, Grade, or KINT authority is created by this result.

## Next safe action

Open a **new preregistered instrumentation follow-up** with one direct consumer: close both proven evidence defects without changing Boss19 strategy behavior. It must:

1. fix source freshness to compare timestamps on one time basis;
2. define prospectively whether tester end-of-test closes can be admitted solely through exact MT5 `DEAL_POSITION_ID` ownership derived from already source-owned opening positions, with no FIFO/time/volume/order/P&L inference;
3. repeat only `H3-C03-MAIN` first;
4. require exact strategy parity and `113 IN / 113 OUT / 113 realized units` before broad rerun can be reconsidered.

Until that separate contract passes review and its one-cell pilot passes, P4B unit attribution remains blocked.