# Hermes H2 — Boss19-0 Small Pilot Contract

Status: READY AFTER THIS REPAIR IS REVIEWED AND CANONICAL
Mode: TESTER-EXECUTE / FIXED CONFIG / NO OPTIMIZATION
Authority: mechanical Strategy Tester evidence only; no strategy architecture or promotion authority.

## Objective
Qualify Hermes H2 by executing exactly three pre-authorized Boss19 `19-0` Symbol×TF cells across MAIN and BWD using the locked reference configuration and the manifest-bound tester executor.

H2 judges execution/evidence discipline, not strategy viability. Poor PF/DD is valid strategy evidence. Mechanical/environment failure is never strategy RED.

## Exact pilot cells
Canonical manifest: `tools/hermes_ea_lab_pilot/H2_SMALL_PILOT_MANIFEST.csv`.

- C01: XAUUSD H4 — MAIN + BWD
- C02: EURUSD H1 — MAIN + BWD
- C03: AUDUSD M15 — MAIN + BWD

Exactly six run IDs are authorized. No other symbol, timeframe, date window, model, set, report name, optimization or HOLDOUT call is permitted.

## Locked mechanics
- Expert: `EALabTpl\Probe_19_AdaptiveTrendGrid`
- Set: `ea_template/sets/probe/Boss_19_AdaptiveTrendGrid_V0_STOP_VALIDATION_CENTER.set`
- Set SHA256: `671ced2169bdda6812cf1ceb70bbc5a53bcb0985563dcbce92cc64e04f81f0d2`
- Model: `1`
- Deposit: `10000`
- Leverage: `1:100`
- MAIN: `2023.01.01..2025.12.31`
- BWD: `2020.01.01..2022.12.31`

Reference center carried unchanged from H1: StepATR `0.30`, FastMA `20`, SlowMA `50`, TP_ATR `1.50`. This is a historical reference center, not a global optimum.

Accepted executable receipt identity for this pilot:
- build receipt: `br-cb9e1136b4a2498aad1fc4cc85a55b18`
- installed EX5 SHA256: `7cd4c979fd00a294e47c9a2b920cbc0590708bb27371ef1912021ea4b0970a5b`
- task-scoped receipt-registry SHA256 used at preregistration: `48bdc3bc6dc749d3abe5f09afbdc7ce557b801889be4cc624464a060b7bc5320`

The receipt-registry path is machine evidence, not canonical repository authority. Immediately before each H2 dispatch, Control Tower must verify the supplied registry SHA and installed EX5 SHA. No `-AllowLegacyIdentity` escape is permitted.

## Runtime / timeout contract
Run exactly ONE manifest run ID per `run_profile_task.ps1` invocation.

Required wrapper settings:
- `-Role ea-tester`
- `-Mode tester-execute`
- `-RunBudgetSeconds 300`
- `-HardTimeoutSeconds 900`
- exact clean `SafeWorkspace`
- `ExpectedHead` = the exact reviewed canonical H2 head
- manifest, receipt registry and set SHA bindings supplied explicitly

The outer 900-second wall clock is the H2 pilot ceiling even though the underlying runner can wait longer. A wrapper hard timeout is `D EXECUTION INCOMPLETE` or `C ENVIRONMENT-DEPENDENCY` as evidence supports; it is never strategy RED and must not be silently retried.

If a run needs more than 900 seconds, stop H2 qualification and return the timeout evidence to Control Tower. Do not increase the timeout, split dates, change Model, or widen scope inside this contract.

## Model fidelity boundary
Model `1` is intentionally fixed for H2 mechanical qualification. H2 does not establish final tick-model fidelity, production expectancy, candidate fitness or deployability.

## Evidence admissibility
`status=COMPLETE` means the runner/report pipeline completed; it does not by itself mean the report covers the full requested window.

For every COMPLETE result Hermes must inspect and reproduce:
- `report_sha256`
- parsed expert/symbol/TF/date/leverage identity
- `leverage_check`
- `truncation_check`
- `full_window_evidence_eligible`
- `evidence_eligibility_reason`

`full_window_evidence_eligible=true` is allowed only when the truncation sidecar exists, parses, and explicitly reports `truncated=false`.

If `truncated=true`, the run remains valid strategy evidence of the safety-cage event but its PF/DD/net/trade metrics are partial-window evidence. It must not be presented or joined as a full-window MAIN/BWD measurement.

If the truncation sidecar is missing, malformed, or does not carry a boolean `truncated`, full-window eligibility is false/unknown. Do not guess.

## H2 qualification acceptance
H2 PASS requires all six authorized run IDs to be accounted for and:
1. every invocation is exact-HEAD, clean-worktree and SHA-bound;
2. Hermes uses only `ea_lab_tester_executor.run_fixed_backtest(cell_id)` for tester execution;
3. no unauthorized cell, HOLDOUT, optimization, generic terminal/file/code-execution, `-Force` or legacy identity bypass is used;
4. every completed run preserves raw evidence separately from interpretation;
5. truncated/unknown-window evidence is visibly non-eligible for full-window comparison;
6. any runner/provider/environment failure is classified mechanically and never converted to strategy RED;
7. the repository remains unchanged by the H2 run.

A poor but mechanically valid strategy result does not fail H2. An unstructured wrapper timeout, wrong identity, hidden truncation, missing run, unauthorized call, or mutation means H2 is not PASS.

## Provider boundary
Use the persistent `ea-tester` profile unless Control Tower supplies a runtime-only provider/model override already smoke-preflighted for this exact task. A provider fallback does not relax any SHA, cell, timeout, evidence, HOLDOUT, mutation or authority rule.

Never replay a run merely because the model/provider response was interrupted after the tester may have launched. First inspect durable report/process evidence and return UNKNOWN/BLOCKED when ownership is uncertain.

## Forbidden
- no 2026H1 HOLDOUT
- no optimization or parameter search
- no H3/broad matrix
- no candidate ranking or promotion
- no new strategy hypothesis
- no strategy/risk/default changes
- no deploy/runtime attachment/trading
- no direct terminal/file/code-execution tool grant to `ea-tester`
- no `-Force`, `-AllowLegacyIdentity`, history rewrite or destructive cleanup

## Required H2 result
Return one deterministic package containing:
- exact canonical HEAD and manifest SHA used;
- receipt-registry SHA and installed EX5 SHA verification;
- six run IDs with COMPLETE / MECHANICAL_FAIL / BLOCKED outcome;
- report SHA and normalized metrics for every COMPLETE run;
- full-window eligibility and truncation state for every COMPLETE run;
- strategy evidence separated from mechanical/environment evidence;
- `H2 PASS — H3/BROAD MATRIX READY FOR CONTROL TOWER DISPATCH` only when the H2 acceptance above is satisfied; otherwise `H2 NOT PASS — DOWNSTREAM REMAINS WAITING` with blocker class.

Regardless of outcome, HOLDOUT remains UNSPENT and no downstream stage is executed by this contract.
