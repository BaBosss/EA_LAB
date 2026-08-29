# Hermes H3 — Boss19-0 Fixed-Config Broad Matrix Contract

Status: READY AFTER EXACT-HEAD REVIEW AND CANONICAL INTEGRATION
Mode: TESTER-EXECUTE / FIXED CONFIG / NO OPTIMIZATION / NO HOLDOUT
Authority: mechanical Strategy Tester evidence only; no candidate, strategy, risk, deploy, or promotion authority.

## Dependency
H2 qualification is accepted PASS at canonical head `d5dbd31a44be84e0f396dd8ffedc7125f15b3388` by independent Claude review. H2 established the manifest-bound `ea-tester` execution path. H3 must not reopen H1/H2 harness evidence unless a live regression appears.

## Objective
Execute the approved Boss19 `19-0` fixed center over the full pre-HOLDOUT broad grid on one MT5 install so downstream regime attribution has comparable within-install evidence.

Canonical manifest: `tools/hermes_ea_lab_pilot/H3_BROAD_MATRIX_MANIFEST.csv`.

Universe:
- symbols: `XAUUSD EURUSD GBPUSD AUDUSD USDJPY BTCUSD`
- timeframes: `M15 H1 H4`
- windows: MAIN `2023.01.01..2025.12.31`; BWD `2020.01.01..2022.12.31`
- 18 Symbol×TF cells × 2 windows = exactly 36 unique run IDs

All six logical symbols preflight on MT5-lane1 as `COMPARABLE_EXACT_SYMBOL`; no broker substitution is planned.

## Locked mechanics
- Expert: `EALabTpl\Probe_19_AdaptiveTrendGrid`
- Set: `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set`
- Set SHA256: `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`
- Model: `1`; Deposit: `10000`; Leverage: `1:100`
- reference center: StepATR `0.30`, FastMA `20`, SlowMA `50`, TP_ATR `1.50`
- this center is historical/reference only, not a global optimum.
## Runtime lane and identity
H3 uses MT5-lane1 only: `D:\Meta 5`. Do not split this matrix across Meta 5b/5c because cross-install numeric comparisons are permanently non-comparable.

Accepted executable identity remains:
- build receipt `br-cb9e1136b4a2498aad1fc4cc85a55b18`
- installed EX5 SHA256 `7cd4c979fd00a294e47c9a2b920cbc0590708bb27371ef1912021ea4b0970a5b`
- receipt-registry SHA256 `48bdc3bc6dc749d3abe5f09afbdc7ce557b801889be4cc624464a060b7bc5320`

Before every dispatch, verify manifest SHA, receipt-registry SHA, set SHA, installed EX5 SHA, exact clean HEAD, and that no real MT5-lane1 runtime is active.

## Invocation discipline
Run exactly ONE manifest run ID per `run_profile_task.ps1` invocation:
- Role `ea-tester`
- Mode `tester-execute`
- RunBudgetSeconds `300`
- HardTimeoutSeconds `900`
- exact task-scoped manifest/receipt/set SHA bindings

Never replay merely because provider output was interrupted after MT5 may have launched. Inspect process/report ownership first. A duplicate dispatch is non-evidentiary and must be recorded; it is never a second matrix row.

## Evidence rules
For each run preserve report SHA, parsed identity, leverage check, truncation check, full-window eligibility, runner status, and normalized metrics.

`COMPLETE` is not automatically full-window evidence. `full_window_evidence_eligible=true` requires an explicit parsed truncation sidecar with `truncated=false`.

Truncated evidence remains valid evidence of the cage/event but is excluded from full-window regime comparisons. Mechanical/provider/data failures are classified mechanically and never converted into strategy RED.

H3 broad evidence may contain poor PF, sparse trades, losses, or cage events. H3 evaluates disciplined batch execution; strategy interpretation is a separate downstream consumer.
## H3 qualification acceptance
H3 PASS requires all 36 unique authorized run IDs to be accounted for and:
1. exact reviewed canonical HEAD, clean worktree, SHA-bound dispatch for every invocation;
2. only `ea_lab_tester_executor.run_fixed_backtest(cell_id)` performs tester execution;
3. no unauthorized symbol/TF/window/model/set/report, HOLDOUT, optimization, generic execution tool, `-Force`, or legacy identity bypass;
4. raw report evidence remains separate from interpretation;
5. full-window eligibility/truncation is explicit for every COMPLETE run;
6. mechanical/environment failures remain mechanical;
7. tracked repository bytes remain unchanged by execution.

Broad-matrix completeness is reported separately: FULL if all 36 are full-window eligible COMPLETE results; PARTIAL if one or more are truncated/mechanical/blocker outcomes. H3 mechanical PASS does not fabricate missing full-window measurements.

## Forbidden
- no 2026H1 HOLDOUT
- no optimization, parameter search, survivor tuning, sensitivity, MC, or Model-4
- no candidate ranking/promotion
- no new strategy hypothesis or risk/default change
- no deploy/runtime attachment/trading
- no cross-install numeric join
- no direct terminal/file/code-execution grant to `ea-tester`
- no `-Force`, `-AllowLegacyIdentity`, destructive cleanup, or history rewrite

## Required result
Return exact canonical HEAD + manifest/receipt/set/EX5 hashes, all 36 run outcomes, report hashes and normalized metrics for COMPLETE rows, explicit truncation/full-window eligibility, mechanical blockers separately, matrix completeness, and HOLDOUT=`UNSPENT`.

Only after H3 PASS may Control Tower dispatch frozen-timeline regime attribution from eligible evidence. Optimization remains separately gated and is not unlocked by H3 alone.

Success line: `H3 PASS — BROAD MATRIX EVIDENCE READY FOR FROZEN-TIMELINE REGIME ATTRIBUTION`.
Failure line: `H3 NOT PASS — REGIME ATTRIBUTION REMAINS WAITING`.