# BT9 — B15 Edge-Latch Portability 02 — AUDUSD/H4

Status: `PREREGISTERED / READY_FOR_EXECUTION`
Hypothesis ID: `HYP-B15-EDGE-PORT-02`
Authority: `RESEARCH_ONLY`
Canonical base SHA: `ff8b8200f8f789c46bc6f852a8985fc9594127da`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Direct consumer

Test the mechanism-first workflow prospectively on one new B15 home: does the already-supported one-fire-per-MACD-run edge latch retain useful selectivity on AUDUSD/H4, a home not used in BT3/BT6 and not present in the accepted H02 pair matrix?

One logical change only:
`_15_EdgeTrigger=true -> false`.

All MACD periods, `_15_CountBars=2`, `_15_RearmBars=0`, exits, sizing, risk and all other tester inputs remain frozen.

Known accepted evidence — DO NOT REDISCOVER: BT3 GBPUSD/H4 and BT6 USDJPY/H4 + EURUSD/H4 all showed that disabling the edge latch increased participation while degrading economics and/or drawdown. BT6 concluded `PORTABLE_MECHANISM_SUPPORTED`, but the parent strategy remained home/window dependent.

## Frozen identity

- Expert: `EALabTpl\Boss_15_ST03`
- Source SHA256: `e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f`
- EX5 SHA256 on Meta5c: `f3dd7c5f2e2c1eb5a9f30a95a120e8977aa071e86f5ea4d9929e84f74940803a`
- Build receipt: `br-58971201f0774c47bf5e6f423c47e1bc`
- Receipt registry SHA256: `6c5d70ba538123b24984ba9a62f547c66da7ea6353af738b4ebcc374fd28fef8`
- Parent set SHA256: `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`
- Child set SHA256: `df109ecc42016bf318f7f3de1bc936b00d9abe258ec58086f9db2152e5a295f8`
- Relevant source/core/runner/default-set bytes: no changes from accepted build lineage `cf32ba8d..ff8b8200`.

## Frozen execution

Runtime: `MT5-lane3 / D:\Meta 5c`; Model 1 only; one job at a time.

Run exactly four cells on AUDUSD/H4:
1. PARENT MAIN `2023.01.01..2025.12.31`
2. PARENT BWD `2020.01.01..2022.12.31`
3. CHILD MAIN `2023.01.01..2025.12.31`
4. CHILD BWD `2020.01.01..2022.12.31`

Tester controls: USD 10000, leverage 1:100, Optimization 0, Forward 0. HOLDOUT is not accessed.

## Falsifier and workflow decision

Mechanism contribution is falsified on this home only if the level-mode CHILD has non-lower net profit AND non-higher EqDD% than PARENT in BOTH MAIN and BWD. Mixed evidence remains `UNCLEAR`; failure to falsify is not universal proof.

After mechanical PASS, inspect parent/child aggregate plus calendar-year distribution before any next-work decision. Do not tune using BWD or adverse years/months.

Workflow outcome:
- mechanism falsified -> update portability boundary and STOP; no optimization;
- mechanism not falsified but parent home remains cross-window weak -> `PORTABLE_MECHANISM / HOME_NOT_QUALIFIED`, STOP; no optimization;
- mechanism not falsified and parent is genuinely dual-window/participation-qualified under current canonical selection bars -> only a future separately preregistered optimization proposal may be considered; this experiment itself does not unlock it.

Mechanical PASS requires exact expert/EX5/build receipt, full input surface, exact set hashes, AUDUSD/H4, exact windows, Model 1, Optimization 0, Forward 0, USD 10000, leverage 1:100, fresh full-window reports and no HOLDOUT date.

Runtime forecast: `QUICK/NORMAL`; bottleneck is four sequential Model-1 H4 runs on Meta5c. Loop breaker: at most one bounded harness repair; same unresolved question twice -> STOP/BLOCKED.

Authority ceiling: research evidence only; no optimization, HOLDOUT, Candidate, Grade/KINT, risk/default, deployment, runtime attachment, trading or LIVE authority.
