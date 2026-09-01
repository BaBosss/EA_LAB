# Boss19 P4B Source-Bound Unit Export Repair 02 Contract

Status: `PREREGISTERED / RESEARCH_ONLY / ONE-CELL ONLY / BROAD_RERUN_LOCKED`
Base: `af499a0d4dc031bbf2140a21b87efd1918105831`
Direct consumer: `ORDER-RND-P4` source-bound unit-attribution prerequisite.

## Accepted parent evidence

- Accepted pilot blocker commit: `62e1927264ba90589467e16a40690a19a2d1adaa`.
- Pilot cell: `H3-C03-MAIN` / XAUUSD H4 / MAIN 2023.01.01..2025.12.31 / Model 1.
- Strategy parity is already accepted on comparable fields: PF 4.39 / net +4445.51 / 113 trades / EqDD 13.34%.
- Pilot source snapshot: 113 IN / 110 OUT / 113 source positions; tester report trades = 113.
- A PRODUCT_DEFECT: three tester-forced end-of-test closes are excluded by the current final-snapshot exact-magic predicate.
- B HARNESS_TEST: runner compares local `$started=Get-Date` against `LastWriteTimeUtc`.
- These are instrumentation/harness defects only. They are not Boss19 strategy or regime evidence.

## Objective

Close only the two accepted pilot defects without changing Boss19 strategy/core/set/risk behavior, P4A, the frozen classifier timeline, H3 windows/configuration, or any authority boundary. Re-run only H3-C03-MAIN after review. Broad 36-cell execution remains locked until that one-cell gate passes.

## Frozen strategy identity

The diagnostic sibling must still compile the same `LAB_ENTRY_19` / unchanged `LabCore.mqh` strategy path and the accepted fixed set SHA-256 `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`. Parent wrapper, core mechanics, entry/exit logic, sizing, protection, magic, Model 1, deposit 10000, leverage 1:100, and MAIN dates remain unchanged. HOLDOUT remains UNSPENT; optimization remains NONE.

## Repair A -- exact source-owned position closure admission

The streaming `OnTradeTransaction` observation path remains strict-magic and non-authoritative. The final `OnTester()` history snapshot remains the authoritative source artifact.

The final snapshot must use a deterministic two-pass exact-identity rule:
1. scan terminal history and build a unique set of `owned_position_ids` only from trading deals whose source `DEAL_SYMBOL == _Symbol`, source `DEAL_MAGIC == _0_Magic`, source `DEAL_TYPE` is BUY/SELL, and source `DEAL_POSITION_ID > 0`;
2. emit a trading deal only when `DEAL_SYMBOL == _Symbol`, BUY/SELL, `DEAL_POSITION_ID > 0`, and that exact `DEAL_POSITION_ID` is in the frozen owned-position set;
3. therefore a tester-forced closing deal whose close-deal magic is not the EA magic may be admitted only because its exact source-emitted `DEAL_POSITION_ID` was already proven owned by a strict-magic source deal in the same terminal history.

Forbidden: FIFO, time proximity, volume similarity, order sequence, comment, P&L, ticket proximity, end-of-test timestamp heuristics, or any rule that admits an unowned position ID. No basket ID is inferred.

This rule changes evidence selection only. It does not create or modify a trade.

## Repair B -- one time basis per freshness comparison

Preserve local wall-clock start for `Test-ReportIsFresh`, because that helper compares against report `LastWriteTime`.
Add a separate UTC run-start value before MT5 launch and compare Common-Files source `LastWriteTimeUtc` only against that UTC value. The run manifest must record that UTC start directly. No freshness gate may compare local time with UTC file time.

## Deterministic acceptance before runtime

- `git diff --check` clean.
- existing P4B unit-export deterministic tests pass;
- tests explicitly prove the final snapshot is position-ownership based rather than time/volume/order/P&L based, and that source freshness uses UTC-to-UTC while report freshness remains local-to-local;
- diagnostic source compiles 0 errors / 0 warnings;
- original Boss19 parent/core/set bytes remain unchanged;
- exact frozen repair HEAD receives independent different-family review PASS before MT5 launch.

## One-cell runtime gate

Run only `H3-C03-MAIN` on the already-approved local Strategy Tester path after review. PASS requires all of:
1. exact strategy parity on the preregistered comparable fields (PF 4.39 / net +4445.51 / 113 trades / EqDD 13.34%, plus existing full-window/mechanical identity checks);
2. source final snapshot = exactly 113 IN and 113 OUT/OUT_BY with 113 distinct source-owned positions for this accepted cell;
3. deterministic unit builder = exactly 113 realized units, 0 open positions, using `EXACT_DEAL_POSITION_ID_ONE_IN_ONE_OUT` only;
4. source OUT count and realized-unit count each reconcile to tester report trades = 113;
5. no forbidden inference and no HOLDOUT/optimization/config drift.

Any failure is fail-closed and must be classified A/B/C/D separately from strategy evidence. At most this one bounded repair is authorized by this follow-up.

## Broad execution boundary

Only a reviewed one-cell PASS may make the broad 36-cell source-bound export READY. This contract does not itself run or authorize that broad batch. A broad batch still uses the frozen H3 matrix, serial MT5 lane ownership, Model 1, MAIN/BWD only, and no HOLDOUT.

No P4 regime join, optimization, Candidate/DEMO/LIVE, deployment/runtime attachment, trading, risk/default, Grade, KINT, or owner-attestation authority is created here.
