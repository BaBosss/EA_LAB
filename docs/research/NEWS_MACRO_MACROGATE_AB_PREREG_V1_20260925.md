# News/Macro — MacroGate BASE / REAL_GUARD / PLACEBO Preregistration V1 — 2026-09-25

Status: PROSPECTIVE_R1 / PRE-OUTCOME SEMANTICS CORRECTED AND REFROZEN / NO PERFORMANCE EXECUTED.

Lane: `ct-news-macro-mg-ab-prereg-v1-20260925`.

Authority ceiling: research experiment preparation only until this exact preregistration/tooling package passes deterministic checks and independent exact-head GPT Scrutiny. No optimization, BWD retuning, HOLDOUT, Candidate/Grade/KINT, runtime/deployment, DEMO/LIVE, risk/default or trading authority follows.

## 1. Accepted upstream prerequisites

Current canonical base at lane claim: `6c62d87abb4dede2d7cc930ae0cfe06fc2ec7166`.

Accepted MacroGate lineage consumed without rerun:
- causal replay head `5cff69e3d91f313a43c5ca6dae04fe06139fc50e`, timeline SHA256 `44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f`, manifest SHA256 `436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1`;
- explicit-UNKNOWN core seam accepted head `5d6713cdc6b81191dc199f269bbc78789155c388`;
- native exporter/quarantine canonical `6c62d87abb4dede2d7cc930ae0cfe06fc2ec7166`, acceptance-reviewed source head `50a6c19e4a2c223efe4117ddef6ae8a5d930d029`;
- current `MacroGate_Core.mqh` SHA256 `afb74e22f75af3053d56ef6e8a485987fdc951f0995e44e91af91e6142778a0a`;
- current `LabCore.mqh` SHA256 `92625d564f3eb461bd7d603c33633b0932e873d15267fb01cb94a98f4377039d`;
- ThinkMarkets broker-clock contract SHA256 `ce472070a96b970ea280aa672988bc8c05207b9ded9234c86b08e49703737a37`.

Historical MacroGate performance/A-B outcomes are negative/history evidence only and are not selection evidence for this experiment.
## 2. Parent selection — pre-existing Home, no outcome cherry-pick

Parent family: `B15 / Boss_15_ST03`.
Home: `GBPUSD / H4`.

Selection rationale is fixed before this experiment's outcomes:
- owner-ratified B15 Home = `GBPUSD/H4` in `docs/architecture/EA_TEMPLATE_XX00_WAVEA_FASTSTART_RATIFICATION_20260909.md`;
- use the current canonical family full-surface default snapshot rather than selecting or tuning a historical winning child;
- do not use CountBars=3, edge-latch ablations, BWD results, or any MacroGate historical result to choose parameters;
- the previously closed CountBars and edge-latch hypotheses remain closed. This is a distinct one-change MacroGate timing hypothesis on a frozen parent.

Current parent source identity at preregistration:
- wrapper `ea_template/Boss_15_ST03.mq5` SHA256 `e235105deac8c975093a920b34b84565d2d6e355fa64a7802b05dd6592c1d88f`;
- full-surface parent set `ea_template/sets/regression/Boss_15_ST03_defaults.set` SHA256 `ca1415f1f7d855faa51a39e79631b0ad1914ce3ee4d0b0508802d251de239c3c`;
- current-source EX5/build receipt: NOT YET FROZEN. A fresh deterministic compile/build binding is mandatory before any tester run.

The parent set remains unchanged except tester-only identity/location fields explicitly listed below. No strategy parameter is tuned.

### Parent viability gate

Before any REAL_GUARD or PLACEBO arm, run a fresh current-source BASE on fixed Model1 MAIN and BWD. Both must be mechanically full-window eligible and each must have `PF > 1.0` and `net > 0`. This is a host-eligibility gate, not a Candidate/Grade threshold. No trade-count floor is invented because KINT/sample-floor policy remains unresolved; counts and concentration must be reported.

If either BASE window fails that gate, stop as `PARENT_NOT_POSITIVE_EXPECTANCY` and do not execute guard/placebo arms under this contract.

## 3. Frozen windows and evaluation unit

- MAIN: `2023-01-01T00:00:00Z .. 2026-01-01T00:00:00Z` (calendar years 2023-2025).
- BWD: `2020-01-01T00:00:00Z .. 2023-01-01T00:00:00Z` (calendar years 2020-2022).
- HOLDOUT: `LOCKED_UNSPENT`; no 2026 data may be used for selection, placebo construction, tuning or rescue.
- BWD role: validation only; no BWD parameter or methodology retuning.
- Evaluation unit: `BASKET_EPISODE` because generic Stack/position-engine path remains present even though the experimental dimension is only MacroGate timing.

Preferred first-pass tester: Model1 / 1 Minute OHLC on one reserved MT5 installation lineage. `D:\Meta 5c` is eligible for Model1 only and may be used only if Lane Registry/runtime ownership is free at dispatch. Model4 is not part of this contract; any later fidelity confirmation is a separate prospective consumer on the authorized Model4 lane.
## 4. Exact experimental arms

All arms use the same parent source/build, symbol, timeframe, full parent settings, tester install/account/build, leverage, deposit, model and window. The only behavioral experimental dimension is MacroGate state timing.

### BASE_OFF
- `_MG_SelfGate=false`.
- MacroGate feed file is not consumed.
- All other parent inputs unchanged.

### REAL_GUARD
- `_MG_SelfGate=true`.
- native feed = accepted MacroGate causal/native exporter output for the exact window;
- `_MG_OffsetHours=0`;
- `_MG_LotMult=0.5`;
- `_MG_BlockNew=true`;
- `_MG_TriggerRiskOff=true`;
- trigger states = `RISK_OFF` and `STRESS` under current accepted core semantics;
- transition server dates remain explicit tester-only `UNKNOWN`, which clears MacroGate-owned BLOCK/LOTMULT and remains selected until the next stable recognized row.

### PLACEBO
Five frozen seeds: `2026092501`, `2026092502`, `2026092503`, `2026092504`, `2026092505`.

Each seed produces one synthetic MacroGate schedule independently for MAIN and BWD. All five seeds must be executed and reported; no favorable seed selection is permitted.

Macro-specific placebo method:
1. Use only accepted causal timeline rows inside that exact evaluation window. Never draw donor states across MAIN/BWD or from HOLDOUT.
2. Candidate shifts are signed whole weeks `-52..-8` and `+8..+52`, inclusive. This preserves weekday and UTC clock while excluding near-zero shifts.
3. For each seed, deterministically order candidate shifts by SHA256 of `"<seed>:<shift>"`; choose the first shift not already assigned to another frozen seed and non-identity for every weekday stratum. Resolve/freeze all five shift values before any tester outcome.
4. Partition each window's target rows by UTC weekday (Monday through Sunday), preserving chronological order within each stratum. For each weekday stratum independently, map target local index `j` to donor local index `(j - shift_weeks) mod n_weekday` using the same seed shift across all seven strata. Target timestamps stay fixed. This is a full-window bijection: every target has exactly one donor, every donor is used exactly once, donor and target always share weekday, and no donor leaves its MAIN/BWD window or touches HOLDOUT. Each row records donor identity and is explicitly `SYNTHETIC_PLACEBO_ONLY / causal_state_qualified=false`.
5. At weekday-stratum wrap seams the donor displacement is not claimed to be one uniform calendar shift; exact regime run-length preservation is therefore not guaranteed at those synthetic seams. Report seam/displacement evidence explicitly. The placebo preserves target coverage, weekday, UTC clock, marginal source-state counts and within-window donor uniqueness—not historical causality.
6. Render target timestamps through the same accepted ThinkMarkets clock mapping as REAL_GUARD. Transition **target server dates** remain explicit `UNKNOWN` at server 00:00 regardless of the rotated donor state; next stable target row resumes at its actual mapped server time.
7. Preserve and report donor state/RI/flags/provenance separately; no shifted donor availability timestamp is relabeled as a real causal observation.
8. Generated native rows must be strictly ascending/unique, cover every target interval exactly once, use `_MG_OffsetHours=0`, and carry `probability=null`, `performance=NOT_RUN` until tester results exist.

Weekday-stratified circular placebo schedules are deliberately synthetic controls, not historical causal macro reconstructions. A placebo PASS never qualifies a data source or global regime.

Tester-only harness identity may use the default tester magic because `LabCore` rejects compiled-default magic only outside `MQL_TESTER`. Feed location/name may differ mechanically per arm to avoid collision, but those filenames are harness identity, not strategy parameters. No live/global runtime file may be overwritten.
## 5. Primary question, metric and falsifiers

Question: on a prospectively requalified positive-expectancy B15 GBPUSD/H4 parent, does the accepted causal MacroGate timing reduce equity drawdown beyond what can be explained by comparably timed synthetic guard schedules?

Primary metric: **native maximal equity drawdown percentage**, reported exactly from the accepted parser/native report definition. For every guard arm also report `DD_reduction_vs_BASE = BASE EqDD% - arm EqDD%`.

Mandatory mechanism prerequisites per window:
- REAL_GUARD has at least one guard firing and at least one blocked/affected new-entry attempt;
- every placebo arm has at least one firing and reports blocked/affected attempts;
- no truncation, hard harness failure, source/hash mismatch or feed/parser mismatch;
- full-engine rerun only; never delete blocked trades from an existing ledger.

Blocked-entry share is `affected_new_entry_attempts / BASE_new_entry_attempts` using one frozen attempt definition across arms. It is a confound diagnostic, not an optimization target.

Decision labels are fixed before outcomes:
- `MECHANISM_UNTESTED`: REAL_GUARD has zero firing or zero affected new-entry attempts.
- `EXPOSURE_CONFOUND`: REAL_GUARD blocked-entry share is outside the min-max envelope of the five placebo arms in either MAIN or BWD. Report metrics but do not claim timing value.
- `TIMING_VALUE_NOT_SEPARATED_FROM_PLACEBO`: after mechanism/exposure gates pass, REAL_GUARD `DD_reduction_vs_BASE` is less than or equal to the best placebo DD reduction in either MAIN or BWD.
- `TIMING_VALUE_NOT_FALSIFIED`: mechanism/exposure gates pass and REAL_GUARD DD reduction is strictly greater than every frozen placebo seed in **both** MAIN and BWD.

This is a bounded research classification, not statistical significance, strategy promotion or a universal MacroGate threshold. Net, PF, trades, episode count, time-in-market, max exposure, hard kills and tail losses remain mandatory secondary outcomes and may show practical trade-offs even if the timing classification is not falsified. No parameter or threshold may be changed after those outcomes are seen.

## 6. Required measurements and evidence

Every BASE/REAL/PLACEBO cell must bind:
- parent wrapper/source SHA256, current-source EX5 SHA256 and build receipt;
- full-surface effective set SHA256 plus exact tester-only MacroGate/feed deltas;
- logical/actual symbol, H4 timeframe, tester install/build/account/leverage/deposit/model;
- exact UTC/server window and accepted broker-clock receipt;
- feed/schedule SHA256, real-vs-synthetic classification and seed/shift for placebo;
- report SHA256, native receipt SHA256, truncation/full-window status and history quality;
- net, PF with undefined/no-loss status preserved, native EqDD amount/percent, closed trades;
- basket/episode count, guard firings, affected new-entry attempts, contact/gated time, time in market;
- max positions/depth/aggregate lots/exposure definition, hard kills, tail-loss definition/value;
- year split, source/state coverage and transaction economics (spread/commission/swap; slippage assumptions explicitly labeled).

Results are descriptive and source-bound. `probability` remains null. No missing number is replaced by zero.

## 7. Gates before any performance run

1. This preregistration and macro-placebo implementation pass focused positive/negative tests, full existing `tools/news_macro_lab/tests`, py_compile/diff/hooks and one exact-head read-only GPT Scrutiny.
2. Materialize all five seed->shift mappings and MAIN/BWD synthetic schedules before any strategy outcome; hash every schedule/native feed.
3. Fresh-compile current canonical `Boss_15_ST03` and bind EX5/build receipt to this exact source/core/set identity. Compile/tester environment failure is mechanical, not strategy evidence.
4. Reserve one Model1 tester lane through Lane Registry; one job at a time; no force/kill/eviction.
5. Run BASE MAIN+BWD first. If the parent viability gate fails, STOP before REAL/PLACEBO.
6. If BASE qualifies, freeze the exact arm manifest and execute REAL_GUARD plus all five placebo seeds on MAIN and BWD with no retuning between arms/windows.
7. Parse/report mechanically, preserve all attempts and failures, then obtain the review required by the eventual performance contract before any project-level interpretation.

No current step authorizes Model4, optimization, HOLDOUT, runtime activation, attaching/detaching any chart, changing the live 990120 sensor, deployment, risk/default changes or trading.

## 8. Historical exclusions

- Do not reuse the withdrawn ORDER-211 MacroGate performance result as acceptance evidence.
- Do not move or modify the live Boss_12 `990120` plumbing sensor; it remains separate and unsuitable as the performance host.
- Do not reopen B15 CountBars/BT9 parameter searches. Current B15 entry parameters remain exactly the canonical default snapshot.
- Do not import B16, Boss19, Black Tide or other closed experiment settings into this parent.
- Do not use BWD or HOLDOUT to choose seeds, shifts, state triggers, lot multiplier, block policy or parent parameters.
## 9. Pre-outcome semantics correction R1

The original prospective contract commit `685538d8b12d764896464cdf8bbeaad79a3fdfb5` is preserved as R0 history but its row-index circular formula is superseded **before any tester/performance outcome**.

The first bounded tooling author stopped with `SEMANTICS_CONFLICT_CIRCULAR_ROTATION_VS_WEEKDAY_PRESERVATION`: MAIN and BWD each contain 1,096 daily intervals, and `1096 mod 7 = 4`. Therefore a whole-series circular index rotation by a nonzero multiple of seven days necessarily changes weekday on wrapped rows. That job made zero Git changes, ran zero MT5 cells, generated no performance artifact, and left source Repair1 `UNUSED`.

R1 keeps the frozen parent, windows, seeds, shift candidate pool, primary metric, falsifiers and all authority boundaries unchanged. Only the inconsistent donor-mapping rule is replaced by the weekday-stratified circular permutation in Section 4.

A pre-outcome calendar-only validation resolved the same seed mapping:
- `2026092501 -> +38 weeks`
- `2026092502 -> -23 weeks`
- `2026092503 -> -8 weeks`
- `2026092504 -> -32 weeks`
- `2026092505 -> +36 weeks`

For every seed in both 1,096-day windows the corrected mapping covers 1,096/1,096 targets, uses 1,096 unique in-window donors, has zero donor/target weekday mismatch, zero cross-window donor, and zero HOLDOUT contact. These are methodology checks only, not EA outcomes.
Canonical moved during the stopped author job to `069e2f34f543456a00da9b2f6ba775f111aceafc` through Monitor/state-sync commits only. B15 wrapper/set, `LabCore.mqh`, `MacroGate_Core.mqh`, accepted `macrogate_native.py`, and the accepted native-exporter contract blobs are byte-identical across that movement. The isolated lane was merged normally (no rebase/reset) at `ded5efef9b792be7ecaab6ecf46d2c8e1c2b108a` before this R1 refreeze.

R1 does not consume the source/tooling Repair1 budget and does not authorize implementation or performance until committed, tested and independently reviewed.

## Implementation evidence — pre-outcome R1

The bounded R1 author implementation materialized the weekday-stratified method without changing the frozen parent, windows, arms, primary metric, falsifiers, authority ceiling, or Repair1 status.

Implemented source identities before the author commit:
- `tools/news_macro_lab/macro_placebo.py` SHA256 `f045f59f2032d2e65a4b2d0e8d376ce5b73ef083bff44554af7d0053f6cfa5ca`;
- `tools/news_macro_lab/tests/test_macro_placebo.py` SHA256 `9d98894a2fcd5d56c5fe334da6cee86020159f4ae93aaa2e43c2801c5ed21ca1`;
- `tools/news_macro_lab/macrogate_ab_prereg_v1_20260925.json` SHA256 `57594c5c21b5f7330490740d0a746afd86a6c39a54c1f54477ce2fea020b1042`;
- accepted unchanged `tools/news_macro_lab/macrogate_native.py` SHA256 `ec22220fb7995518fd71c694dca43008638bd8692386cba54283002c9a9163d1`.

Deterministic checks completed before any performance outcome:
- focused R1 tests: 11/11 PASS;
- complete existing-plus-R1 `tools/news_macro_lab/tests` suite: 207/207 PASS, zero failures/errors/skips;
- portable-Python `py_compile`: PASS;
- JSON parse and `git diff --check`: PASS;
- exact seed map: `2026092501 -> +38`, `2026092502 -> -23`, `2026092503 -> -8`, `2026092504 -> -32`, `2026092505 -> +36` weeks.

Actual final generation used the accepted causal timeline and manifest hashes from Section 1. Two fresh output directories each contained the same 21 filenames (ten native CSVs, ten provenance CSVs, and one source-bound manifest), with zero byte/hash mismatches. The common generated manifest SHA256 is `95caa20a890e2ad0561a5ccf41b0ac83bce7795f9cf22c3577e3e547197e4dea`.

For every MAIN/BWD × seed cell, evidence records 1,096/1,096 targets, 1,096 unique in-window donors, zero weekday mismatch, zero cross-window donor, zero HOLDOUT contact, preserved marginal donor-state counts, strictly ascending/unique native timestamps, and explicit weekday-stratum wrap/displacement counts. The artifacts explicitly decline a uniform-calendar-shift claim and exact run-length preservation at synthetic seams. Target transition server dates remain `UNKNOWN` at server `00:00`; the required 2024-11-03 marker is explicit and the next stable target resumes at its actual `2024-11-04 02:00` server time. Donor availability fields remain provenance-only and are never promoted to causal truth.

No MT5/compiler/tester/optimization/HOLDOUT/Model4/runtime/deployment/trading action was performed. `can_execute=false`, `performance=NOT_RUN`, `holdout_used=false`, `probability=null`, `selection_performed=false`, `all_seeds_retained=true`, and source/tooling Repair1=`UNUSED` remain controlling. The only eligible next gate after author commit and evidence closeout is separate exact-head read-only GPT Scrutiny.
