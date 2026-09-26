# NEWS_MACRO MacroGate Tester Transfer Qualification V1 — 2026-09-26

Status: **READY_FOR_PROSPECTIVE_IMPLEMENTATION**
Lane: `ct-news-macro-mg-tester-transfer-qual-v1-20260926`
Control canonical: `152b2849d6bb8759b65aa91273248cd068343ddf`
Authority: planning/qualification only. **No MT5 performance execution, REAL_GUARD, PLACEBO, BASE rerun, HOLDOUT, Model4, optimization, BWD retune, parent switch, deployment or LIVE.**

## 1. Recovery / consumed blocker

The existing qualification lane was recovered in place. Registry said RUNNING, but there was no durable job, runner, child, postcondition or lane-specific process; the worktree was clean and had no Phase-1 artifact. Classification: `LOST_PROCESS_RECOVERY_REQUIRED`, recovered on the **same lane**.

The old execution lane `ct-news-macro-mg-ab-exec-v1-20260925` remains a consumed reviewed blocker, not a continuation lane. Its accepted closeout at `73a46848937e637bb4e025b8e8985a7d714462dc` established:

- BASE MAIN: PF 1.10, net +81.25, 214 trades, native EqDD 0.97%, full-window.
- BASE BWD: PF 1.07, net +73.31, 218 trades, native EqDD 1.83%, full-window.
- valid guarded outcomes = 0.
- BWD BASE new-entry-attempt denominator = `null / UNAVAILABLE_NOT_CERTIFIED`; two failed new-entry attempts are preserved. Do not substitute 218 or invent 220.
- recovery3 unauthorized; HOLDOUT `LOCKED_UNSPENT`.

Historical guarded reports with an inactive/missing MacroGate feed remain mechanically invalid and are not strategy evidence.

## 2. Current canonical loader semantics

Current source identities are frozen in `SOURCE_BINDING.json`.

`_MG_RegimeFile` is a runtime string input. `_MG_InCommon` is a runtime boolean input. In `MG_LoadRegime(fname, common)`:

- `common=false` means no `FILE_COMMON` flag: reads resolve through the tester/terminal `MQL5\Files` sandbox.
- missing/open-failed/zero-valid/unsorted data returns false and leaves the guard inactive.
- the current `LabCore.mqh` calls `MG_LoadRegime(...)` but ignores that return value, then continues initialization.

Therefore the current frozen build does **not** fail closed for a missing tester input file. A guarded tester run can continue as effectively unguarded, which is why the old guarded attempts are non-interpretable.

## 3. Transfer mechanisms assessed

### A. Compile-bound `#property tester_file` bundle — **SELECTED**

MetaQuotes documents `tester_file` as a constant-string file declaration that passes an input file to the Strategy Tester. Official MQL5 material also documents multiple `tester_file` directives and tester-agent `MQL5\Files` sandbox use.

Selected prospective design:

1. Add **11 constant-string `#property tester_file` directives** to the main `Boss_15_ST03.mq5` wrapper: one REAL feed plus five MAIN and five BWD placebo feeds already frozen by the accepted preregistration.
2. Before compile, put those exact bytes into the compiler terminal `MQL5\Files` and SHA256-verify every file against `SOURCE_BINDING.json`.
3. Compile **one** Boss_15_ST03 EX5 containing all frozen feed dependencies.
4. Keep `_MG_InCommon=false`.
5. Each prospective cell selects one bundled basename through `_MG_RegimeFile`; do not recompile per outcome/cell.

This is the smallest deterministic MT5-native mechanism found that addresses the exact old failure class without shared mutable Common Files or manual Agent injection.

Official technical references are frozen in `MQL5_REFERENCE_BINDING.json`.

### B. `FILE_COMMON` — technically readable, **NOT SELECTED**

Historical repo evidence (`ORDER171_MACROGATE_GATE_INVESTIGATION.md`) proved that portable terminals still shared the machine-wide Common Files area. That path is mutable and cross-terminal, and using it here would also require changing `_MG_InCommon` from the frozen false value. It is not the preferred deterministic qualification transport.

### C. Manual pre-stage into Tester Agent `MQL5\Files` — **NOT QUALIFIED**

Old recovery1/recovery2 did not produce a durable, deterministic input-transfer binding. Tester-agent sandbox lifecycle makes mutable pre-stage unsuitable as acceptance proof. No recovery3/manual retry is authorized from the old experiment.

## 4. Q1–Q8 answers

### Q1 — exact viable transfer mechanism
**Compile-bound multi-`tester_file` bundle**, one EX5 containing all 11 frozen feeds; runtime cell chooses an exact bundled basename.

### Q2 — source change required?
**YES.** Prospective exact source paths:
- `ea_template/Boss_15_ST03.mq5`
- `ea_template/core/LabCore.mqh`
- `ea_template/core/MacroGate_Core.mqh`
- `ea_template/core/Execution.mqh`

`Inputs.mqh` and `ConfigFingerprint.mqh` remain unchanged.

### Q3 — config/default change required?
**YES, per experiment cell only.**
- `_MG_RegimeFile` becomes the exact compile-bundled feed basename for that cell.
- `_MG_InCommon=false` remains unchanged.
- MacroGate policy, risk/default and strategy inputs remain unchanged.

Because `_MG_RegimeFile` is part of the input surface, the effective config fingerprint must be frozen separately for each cell.

### Q4 — can EA/runtime verify exact CSV SHA256?
**Not with the current MacroGate source.**

Current repo has SHA256 helpers for strings/structured payloads, but no proven MacroGate utility that hashes the exact arbitrary CSV file bytes. Phase 1 does not invent one.

Separate identity layers:
- **PRELAUNCH_HOST_HASH: REQUIRED.** Every compiler input file must SHA256-match the accepted frozen feed before compile.
- **IN_EA_RUNTIME_SHA256: UNAVAILABLE_IN_CURRENT_SOURCE.**
- Exact-byte acceptance therefore binds accepted feed SHA256 -> compiler-input bundle receipt -> source/EX5/build receipt -> `tester_file` transfer contract -> runtime selected filename.

### Q5 — runtime proof
Prospective success marker must expose only supported values:
- requested filename,
- source class `TESTER_SANDBOX_NONCOMMON`,
- file size bytes,
- valid row count,
- skipped row count,
- first accepted timestamp,
- last accepted timestamp,
- load status PASS.

Existing `[MACROGATE] regime loaded` remains evidence of load, but is insufficient alone because it lacks filename/size/first-last identity.

### Q6 — stale/wrong/missing fail closed
Prospectively:
- missing/wrong SHA at compiler input -> build qualification fails before compile acceptance;
- in Strategy Tester with `_MG_SelfGate=true`, `MG_LoadRegime=false` -> `INIT_FAILED`, before strategy execution;
- missing/open-failed/zero-valid/unsorted -> no interpretable test outcome;
- runtime filename/size/row-count/first-last mismatch -> mechanical invalid, no performance interpretation;
- live/non-tester load behavior stays unchanged.

### Q7 — BASE attempt denominator
Historical BWD denominator stays permanently unavailable.

Prospective denominator instrumentation belongs at the **new-order execution choke point**, not at final trades:

For `Exec_Open` and `Exec_PlacePending`, emit a unique `ATTEMPT_BEGIN` before NewsGuard/MacroGate/spread/volume rejection and before any broker request. Each attempt receives exactly one terminal disposition:

- `BLOCK_NEWS`
- `BLOCK_MACRO`
- `BLOCK_SPREAD`
- `REFUSE_VOLUME`
- `DRYRUN_ONLY` / `NO_SUBMIT_EXISTING_PATH` only where the current path already terminates without a broker request
- or `SUBMIT`, followed by `SUCCESS` / `FAILURE` with transport flag and retcode.

Required invariants:

`attempt_total = all pre-submit terminal statuses + submit_total`

`submit_total = success_total + failure_total`

`blocked_by_macrogate = count(BLOCK_MACRO)`

Trade/deal count is never substituted for `attempt_total`.

The existing once-per-minute MacroGate block log is throttled and cannot be used as a numerator.

Attempt telemetry is prospective evidence-only and must be emitted only under `MQL_TESTER && _MG_SelfGate`. It records existing branches/results and must not introduce any new order rejection or direction-validation behavior. Because `LabCore.mqh`, `MacroGate_Core.mqh` and `Execution.mqh` are shared core, the implementation milestone must run impacted deterministic/adversarial core regressions and prove non-tester/live behavior unchanged.

Boss_15 current standard order path is `Lab_OpenOrder -> Exec_Open`. Pending execution is included because `Exec_PlacePending` is also a shared new-order gate. The unrelated prepared-open seam is not added to the Boss15 denominator unless a future exact call-graph proof shows Boss15 reaches it.

### Q8 — identities to refreeze
Prospective implementation must refreeze:
- source SHA(s),
- EX5 SHA256,
- build receipt,
- compiler-input tester-file bundle receipt,
- guard set SHA,
- effective config fingerprint for every feed filename/cell.

Must remain unchanged:
- all accepted feed bytes/hashes,
- B15 parent semantics,
- `_MG_InCommon=false`,
- MacroGate trigger states / lot multiplier / block-new behavior,
- GBPUSD/H4 carrier,
- MAIN/BWD windows,
- risk/default inputs unrelated to feed filename.

## 5. Prospective implementation contract

Machine contract: `factory/runs/news_macro_macrogate_tester_transfer_qual_v1_20260926/PROSPECTIVE_IMPLEMENTATION_CONTRACT.json`.

One-change objective:

> Make MacroGate Strategy Tester input transfer and new-entry attempt accounting deterministic for prospective qualification, without changing MacroGate trading semantics or historical evidence.

Required future gates before any performance execution:
1. static check for exactly the accepted tester-file bundle;
2. precompile SHA256 of all compiler input files;
3. clean Boss_15_ST03 compile on the accepted `D:\Meta 5` lineage;
4. freeze source/EX5/build receipt;
5. freeze per-cell config fingerprints;
6. tester-only load-failure -> INIT_FAILED tests, with live semantics unchanged;
7. attempt telemetry/invariant adversarial tests including Macro block and rejected request;
8. **non-performance** tester-transfer probe with a known fixture;
9. exact-head independent GPT Scrutiny;
10. a separate performance execution contract/lane after qualification.

Phase 1 itself authorizes none of those source/runtime steps automatically.

## 6. Disposition

**READY_FOR_PROSPECTIVE_IMPLEMENTATION**

Reason: a documented MT5-native transfer path exists and fits the current non-Common loader semantics; the remaining work is a prospective source/build/config identity change with deterministic qualification, not an unresolved strategy semantic decision.

This result does **not** authorize MacroGate A/B execution.

- MT5 performance: **NOT RUN**
- REAL_GUARD / PLACEBO: **NOT RUN**
- BASE rerun: **NOT RUN**
- HOLDOUT: **LOCKED_UNSPENT**
- optimizer / Model4 / retuning / parent switch / deployment / LIVE: **NOT AUTHORIZED**

Direct consumer: one separately authorized prospective implementation milestone, followed by independent exact-head review before any performance execution lane can exist.
