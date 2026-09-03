# Boss19 P5 — Black Tide Session Context Attribution Contract

Status: `SEMANTICS_FROZEN / REVIEW_REQUIRED / RESEARCH_ONLY / NO STRATEGY CHANGE`

Preregistration base: `f08ee2c4de615b01c95f599068d3b74c94fe6fad`
Hypothesis: `HYP-SB-005`
Family / parent: `Boss19 / 19-0 AdaptiveTrendGrid V0`
Direct consumer: Boss19 P5 gate after `NO_P5_READY_LEVER_FROM_CURRENT_P4_LABELS`.

## 1. Scope and one logical change

Add exactly one deterministic **entry-session context label** to the accepted Boss19 source-bound P4 DEAL evidence. Freeze every strategy mechanic, entry, exit, position engine, sizing, protection, risk, and existing P4 classifier label. This is context attribution only: no MT5 rerun, strategy filter, parameter search, optimization, HOLDOUT, Candidate/Grade/KINT, runtime, deployment, or trading action is authorized.

The source motivation is independent of the mined P4 adverse episodes: Black Tide Map publishes Asia, London, New York, and London/New York overlap as market-context geometry. The source does not claim any session is superior; EA_LAB must not preselect London, New York, or any other session from historical P&L.

## 2. Frozen source-bound evidence identity

Primary accepted input is `_mt5_auto/p4b_boss19_regime/regime_attribution_detail.csv`, SHA-256 `e54f1cfaf58df97acb8fb39c1e6e8bf4614f1ff3a7c9bcbc1b5acff762665dd6`.

It contains exactly 1,549 accepted DEAL units from the frozen broad36 package SHA-256 `1330a822ed66149ba07d693d8732ced5b9e9ce66d15f34ce8d21ef70894b760c`; the underlying aggregate source-bound unit SHA-256 is `325b6d00709c48982a5981d2d7750a6a18e99f2d77ad52b89fa8d67b50c0b699`. The accepted total realized net is `+17718.78`; HOLDOUT remains `2026H1 UNSPENT`; optimization remains `NONE`.

The assignment timestamp is exactly `entry_utc`. Raw tester/server time remains provenance only. `entry_utc` was already normalized by the accepted P4B rule from source MT5 timestamps; P5 does not reinterpret broker time, use exit time, or infer a new timezone mapping.
## 3. Source session clock and DST semantics

Source bundle: `SRC-BLACK-TIDE-MAP-20260903`. The current public metadata captured on 2026-09-03 records `Session timezone = UTC`, Asia `0000-0800`, London `0700-1600`, and New York `1200-2100`; Session Clock reuses those Session Key Levels hours/timezone and exposes London/New York overlap.

P5 freezes those **UTC source defaults**. `DST_MODE = FIXED_UTC_SOURCE_WINDOWS`: London and New York labels do not shift with UK or US civil DST because the selected Black Tide source clock is UTC. This is an explicit deterministic source-clock choice, not a claim that these labels equal each market's civil-local open/close throughout the year. No seasonal offset inference is permitted after outcomes are viewed.

## 4. Exclusive deterministic partition

The source windows overlap at Asia/London 07:00-08:00 and London/New York 12:00-16:00. P5 must assign every accepted entry exactly once. The prospective EA_LAB tie-break is later-open-wins, except the source's explicit London/New York overlap remains its own state:

- `ASIA` = `[00:00,07:00)` UTC;
- `LONDON` = `[07:00,12:00)` UTC;
- `LONDON_NY_OVERLAP` = `[12:00,16:00)` UTC;
- `NEW_YORK_ONLY` = `[16:00,21:00)` UTC;
- `OUTSIDE_DEFINED_SESSION` = `[21:00,24:00)` UTC.

All intervals are half-open. Exact 07:00, 12:00, 16:00, and 21:00 timestamps belong to the segment beginning at that instant. Exact 00:00 begins `ASIA`. Assignment uses `entry_utc` only; exit time, realized P&L, future state, and existing P4 regime labels cannot alter the session label.

`OUTSIDE_DEFINED_SESSION` is retained as a control partition and cannot be auto-selected as a session candidate.
## 5. Anti-lookahead and execution order

The causal order is mandatory:

`freeze contract + classifier + fixtures -> independent different-family semantics review -> review receipt + bound review output -> open outcome-bearing input -> classify -> aggregate -> interpret`.

Before the review receipt and its external review output validate, the canonical runner must fail closed **before opening the real input file**. Any outcome-bearing session output produced before a valid review receipt is `INADMISSIBLE_PRE_REVIEW_EXECUTION`; it must be quarantined without interpretation and cannot be reused as evidence even if later bytes happen to match.

Session settings, timezone/DST mode, overlap precedence, boundaries, aggregation views, and falsifier cannot be changed after any session outcome is seen. A semantic change after review creates a new reviewed-head requirement and invalidates the prior receipt.

## 6. Fixed machine outputs and aggregation views

Emit one deterministic package containing:

- `session_attribution_detail.csv`: one accepted DEAL row, exactly one session label;
- `session_affinity.csv`: fixed `ALL`, `WINDOW`, `YEAR`, `ENTRY_MONTH`, `SYMBOL`, and `SYMBOL_TF` views;
- `session_leave_one_out.csv`: fixed leave-one-`YEAR`, `ENTRY_MONTH`, `SYMBOL`, and `SYMBOL_TF` checks within each MAIN/BWD session;
- `reconciliation.json`: exact identity/count/net/HOLDOUT/session-assignment checks plus review-receipt identity;
- `package.json`: input/output hashes, review binding, decision, and authority ceiling.

Every aggregate reports eligible-unit count, participation share against its stated parent partition, gross profit, gross loss, net realized, PF (`NULL`/empty only when gross loss is zero), winning/losing/zero unit counts, and partition realized-equity DD ordered by `exit_utc` then `source_deal_id`. Partition DD is descriptive only and is not the original whole-run equity DD.
## 7. Preregistered candidacy, concentration checks, and falsifier

For each named session (`ASIA`, `LONDON`, `LONDON_NY_OVERLAP`, `NEW_YORK_ONLY`), derive direction only from realized net:

- `POSITIVE` iff MAIN net > 0 and BWD net > 0;
- `NEGATIVE` iff MAIN net < 0 and BWD net < 0;
- otherwise `MIXED_OR_ZERO`.

A named session is a research context candidate only when direction is non-mixed and, separately within MAIN and BWD, **every** leave-one-group-out cut for `YEAR`, `ENTRY_MONTH`, `SYMBOL`, and `SYMBOL_TF` leaves at least one unit and preserves that same direction. Empty remainder is an automatic failure; it is never skipped. This prospectively catches one-year, one-month/episode-proxy, one-symbol, and one-home concentration without naming XAU or any historical winner/loser in advance.

Participation counts/shares are always reported. No universal sample floor, PF threshold, grade mapping, or KINT rule is invented here. `KINT-001` remains unresolved.

Decision tree:

- zero named candidates -> `P5_SESSION_CONTEXT_FALSIFIED_STOP_EXPANSION_PARK`;
- exactly one named candidate -> `P5_SESSION_CONTEXT_CANDIDATE_FOUND_SINGLE`;
- multiple named candidates -> `P5_SESSION_CONTEXT_INFORMATION_FOUND_MULTIPLE_NO_PERFORMANCE_SELECTION`.

Do not rank multiple candidates by PF, net, DD, participation, or any post-result score. A single context candidate authorizes only formulation of a separate prospective one-change child hypothesis; this contract does not choose or implement a session filter.

Any identity mismatch, duplicate/missing assignment, malformed timestamp, HOLDOUT crossing, review-receipt mismatch, or P&L reconciliation failure is mechanical `BLOCKED(...)`, not strategy evidence. Do not rescue a falsified/ambiguous result by changing hours, timezone, DST mode, overlap precedence, exit-time labels, session combinations, exclusions, or other Black Tide modules.
## 8. Semantics review receipt and mechanical acceptance

The real-input runner requires a machine-readable `BOSS19_P5_SESSION_SEMANTICS_REVIEW_RECEIPT_V1` produced only after an independent different-family review returns `PASS` on one frozen semantic HEAD, plus the exact external review output file. The receipt binds `reviewed_head`, `reviewer_family`, `reviewed_utc`, exact SHA-256 of this contract, classifier source, classifier tests, and that review output. Before opening the outcome-bearing CSV, the runner verifies the Git-bound semantic blobs, hashes the supplied review output against the receipt, and requires that output to state `VERDICT: PASS`, the same `REVIEWED_HEAD`, and `ATTRIBUTION_EXECUTION_AUTHORIZED: YES`.

Mechanical acceptance requires all of the following:

- semantics receipt `PASS`, different-family reviewer, and exact reviewed-blob binding PASS;
- exact accepted input SHA-256, package SHA-256, 1,549 unique DEAL keys, and `+17718.78` net reconciliation;
- zero HOLDOUT/2026 rows, malformed required timestamps, duplicate DEAL keys, missing assignments, or unknown session states;
- fixture tests covering every exact boundary, malformed timestamps, fixed-UTC/DST invariance, single-year and single-symbol concentration, outside-session non-candidacy, review-receipt fail-closed behavior, and review-output hash/authorization mismatch;
- two builds from identical input, review receipt, and fixed `created_utc` reproduce all machine outputs byte-identically.

Any failure above is `BLOCKED(A_PRODUCT_DEFECT|B_HARNESS_TEST|C_ENVIRONMENT_DEPENDENCY|D_EXECUTION_INCOMPLETE)` as applicable and carries no session/strategy interpretation.

## 9. Pre-review quarantine and repair provenance

The first frozen executable preregistration at `30a41eabc24d6fc41e2cbe116a57337f2820ab67` was not admissible for real-input execution because its prose contained duplicated/overlapping decision sections and it did not mechanically enforce the required independent semantics review before opening outcome-bearing input. Any output produced from that pre-review runner is `INADMISSIBLE_PRE_REVIEW_EXECUTION`: quarantine it, do not interpret it, and do not reuse its numbers or selection outcome.

This repair is constrained only by pre-result requirements already present in `HYP-SB-005` and the frozen source semantics: one-year, one-entry-month/episode-proxy, one-symbol and one-SymbolÃ—TF concentration checks; `OUTSIDE_DEFINED_SESSION` as control-only; fixed UTC source windows; entry-time-only attribution; zero HOLDOUT/search authority. No repair choice may be justified by the quarantined output.
## 10. Authority ceiling and stop rule

This contract ends after deterministic session attribution, its fixed decision tree, and one independent review of the complete evidence/result package. A surviving session is only a research context candidate for a separately preregistered future one-change child; it is not an adopted strategy filter.

No MT5 run, strategy mutation, parameter/range search, optimization, HOLDOUT spend, BWD retuning, Candidate/Grade/KINT change, risk/default change, runtime attachment, deployment, DEMO/LIVE action, or trading is authorized. State/taskboard synchronization must serialize behind any live canonical owner of those files. Normal reviewed fast-forward integration/push remains allowed by project governance.