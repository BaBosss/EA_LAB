# DF03 B21 integration R2 - bounded repair 1/1 result

Status: **BLOCKED_OUTSIDE_ALLOWLIST_TEST_FIXTURE / AUTHOR ACCEPTANCE INCOMPLETE**.
Repair budget: **EXHAUSTED**. Stop fail-closed; leave all work uncommitted for Tower audit.
Date: 2026-09-16. Role: Codex Primary bounded author, not final reviewer.
HEAD remains `c02523e930f072a686c69b3cc5326d87c50a3ede`.
Worktree: `D:\EA_LAB_CONTROL\worktrees\ct-df03-b21-integration-r2-20260916`.
Exact contract: `D:\EA_LAB_CONTROL\evidence\df03-parent-freeze-20260916\B21_INTEGRATION_CONTRACT.txt`.
Exact lane allowlist: `D:\EA_LAB_CONTROL\lanes\registry-v1\ct-df03-b21-integration-r2-20260916.json`.
This result supersedes the original incomplete-draft report retained verbatim below.

## Required stop and direct consumer

The required existing `_triage/factory_os/run_input_surface_tests.py` fails with
`evidence.ToolFailure: ea_template/compat/df03/DF03_TemplateEngine.mqh is not in the fixture source`.
Its `_real_closure()` at lines 401-414 enumerates root wrappers and recursively collects
only `ea_template/core/*.mqh`. B21 correctly reaches the source-bound engine under
`ea_template/compat/df03/`, which that fixture does not collect. The real working-tree
checker passes; the suite aborts in G1 specificity after its first G1 attack passes.
This is a concrete fixture dependency-closure defect, not a Python environment failure,
not a strategy failure, and not an acceptance waiver.

A proper fixture repair requires the unlisted canonical path
`_triage/factory_os/run_input_surface_tests.py`. It was NOT edited. Do not bypass the
fixture reader, hide B21 from wrapper ownership, or move/duplicate the generated engine
into core to make this test pass. Implementation stopped when the outside-allowlist
requirement was confirmed. Remaining read-only verification and this report were completed.
Tower must resolve that exact scope separately; this lane has no repair budget left.
Qualified different-model-family review also remains mandatory and unsatisfied.

## Bounded changes completed

- Replaced the fragile CRLF send substring with token/brace selection of the unique
  `OrderCreate` function and unique qualified `EEFD::OrderSend` call. Exact `BuyNow`
  and `SellNow` forwarding and every send argument are checked. Ambiguous/missing
  functions/sends and argument or forwarding drift refuse generation.
- Parent SHA is verified before structural selection. The hook is inserted immediately
  before the native open send, and only its lot argument changes. A fresh local copy of
  native lots on each retry prevents repeated MacroGate multiplication. Native modify,
  close and dispatcher sends are untouched.
- Retained all draft source-native lifecycle, safety, range ownership, central inputs,
  wrapper registration and event forwarding. No source semantic warning was repaired.
- Finished the input mapping: the four direct global `MagicStart` reads also bind to
  `_21_DF03_MagicStart`; native `c::MagicStart` and declarations remain intact. Every
  integration patch is reversible, with 34 recorded patches total.
- Emitted TemplateEngine/template manifest and regenerated LockedConstants/InputSurface.
  Added the focused deterministic test suite and required PowerShell runner, plus a
  serial compile-only helper using unique temporary copies.
- Corrected the compile-only expert's ChartEvent test argument to a `long` local for
  the `const long&` signature. This does not change production lifecycle semantics.

## Frozen identities and unchanged controls

| Artifact | SHA256 |
|---|---|
| Exact parent | `2aba9437319e214c82b63313a049f73da364052eddfa24f7f1661279593ffd89` |
| Raw compatibility control | `564099a9e48abffcfbeceb43b3558f9212ece603309eaf15e6947834aa957115` |
| Final TemplateEngine | `7863b8f4ccb3c7cfd2021dbf2adedee2fa4b96b7fbdba4b462efadd0e3c35235` |
| Unchanged carried 33-test suite | `158ad445b3ee0eaf6ebfc415584ca8f59937f6019ce9615236974e7c94f5119a` |
| Unchanged raw compatibility generator | `0f5f502eac501f10257f2a2196dbe77a0be01adf67e3b96df38272f01dc01e2e` |

Both carried Python files were compared byte-for-byte with adapter commit
`f087b45819fc5f667185fee22fa6e298c81c9be9` and are unchanged. The exact inverse is
TemplateEngine -> raw control -> parent; full-byte equality is tested at both boundaries.
No raw control/parent bytes changed during this repair. Source graph evidence retains
126 blocks, 15 tick roots, 2 trade roots, the source D1/CurrentTimeframe distinction,
10 native hedge gates and source stop/target assignments. These are source evidence,
not runtime parity or a chart/Home timeframe decision.

## Checks actually run in this repair

Python authority for all direct calls: dot-source this worktree's `scripts/use_python.ps1`,
then `Assert-PortablePython -Root (Get-Location).Path -Provision`; version **3.12.10**.
No `D:\EA_LAB` interpreter was used as execution authority in this repair.
Logs are under `tools/df03_compat/evidence/`, with a `b21_` prefix. Historical logs without
that prefix remain carried evidence and were not substituted for new results.

| Check | Exact result |
|---|---|
| Existing `test_generate.py` | PASS 33/33; unchanged suite; 18.990s |
| New `run_grid_fibo_b21_tests.ps1` / `test_b21.py` | PASS 46/46; 20.557s |
| Template generator and `--check` | PASS; exact artifacts/inverse and pins |
| InputSurface + LockedConstants generators | PASS; 1,727 and 437 emitted lines |
| `check_input_surface_gen.py --worktree` | PASS, including both generated enumerations |
| `run_input_surface_tests.py --worktree` | FAIL/exit 1: fixture closure omits TemplateEngine; no suite PASS |
| `run_locked_constants_metadata_tests.py` | PASS 31/31 |
| `run_wrapper_owner_tests.py` | PASS 25/25; 21 adversarial mutations |
| `check_wrapper_gen.py --worktree` | PASS existing thin-wrapper artifacts |
| `run_wrapper_gen_tests.py` | PASS all reported attack/specificity/property checks |
| `run_template_entry_wrapper_registration_tests.ps1` | PASS 6/6 |
| `run_new_template_entry_tests.ps1` | PASS 84/84 |
| `check_param_surface.py --worktree` | PASS |
| `param_registry_check.ps1` | CLEAN, including worktree surface checker |
| `run_param_registry_fix_lines_tests.ps1` | PASS; ordering/non-citation preservation |
| `gen_param_linkage.ps1 -OutPath <unique temp>` | Exact byte equality; 236 rows, 24 contexts, 15 override pairs |
| Impacted fast cages, working-tree evidence | PASS 9/9 selected of 35; 35.3s; ceiling 110s |
| `git diff --check` and temporary-index `git diff --cached --check` | PASS, tracked plus all untracked paths; real index unchanged |
| `tpl_regression.ps1 -ValidateOnly` | Exit 0, BASELINE CONTRACT CLEAN, Build 6090/source HEAD c02523e9 |
| Changed-path allowlist check | 0 outside-allowlist tracked/untracked changes |

The 46-test suite covers input/default/PID mapping (P12100..P12113), inverse tampering,
LF/CRLF/mixed-trivia selection, missing/duplicate/wrong send seams, direct magic reads,
same-symbol base+1..+5 ownership, native and wrapper event forwarding, init-refusal truth
tables, hard-kill position close/pending delete/flat-proof call chains, shared-engine
inactivity, no bar gate and retained global attach guards. Negative fixtures remove or
mutate ownership bounds, close/delete coverage, risk/AcctGate/news/macro/spread/heat/lot
checks, DryRun/magic/self-gate refusals, kill-before-tick order and shared engine/bar gates.
Range/config truth tables evaluate extracted pure expressions; close/hard-kill coverage
is source-call-chain evidence, not executed broker or MQL runtime behavior.

Fast cages selected: report freshness, optimize guard (fixtures only), registry, preset,
setfile, activation, param surface, wrapper generation and S13. The separate failing
input-surface suite is NOT masked by the fast-tier PASS. The ValidateOnly result checks
structural/baseline lineage and wrapper registration; it does not prove the uncommitted
core change has runtime regression parity. Full tpl_regression was not run because tester
execution is forbidden in this task.

## Serial compilation and exact warnings

MetaEditor: `D:\Meta 5\metaeditor64.exe`, version **5.0.0.6182**,
SHA256 `197ca3dd8d1971831366f54cb57bf3f120b420700e573135509d406e4e23709e`.
All source copies and compiled products were confined to unique temporary directories.
Final receipt: `tools/df03_compat/evidence/b21_compile_receipt.json`.
Final temporary root: `C:\Users\patip\AppData\Local\Temp\df03-b21-compile-7977cbc9a87e4ffd93bbef7b6c15ed5c`.

| Compile target | Errors | Warnings | EX5 produced |
|---|---:|---:|---|
| Boss_21_GridFibo | 0 | 24 | yes, temporary copy only |
| GridFibo_B21_Test | 0 | 24 | yes, temporary copy only |
| GridFibo_AdapterCompile | 0 | 24 | yes, temporary copy only |

All three compiler process exit codes were 1; acceptance here uses the fresh compiler
summary (0 errors) plus a newly produced EX5, not a claim of process exit 0. No compiled
file was run. Full diagnostic lines, coordinates, source/log SHA256 and start times
are retained in the receipt and three logs.

Each compile emitted exactly:

- **20 x warning 43**: `possible loss of data due to type conversion from 'double' to 'int'`.
  Coordinates: `(1838,9) (1873,9) (1908,9) (1943,9) (1978,9) (2013,9) (2048,9)
  (2083,9) (2488,9) (2523,9) (7031,9) (7032,9) (7033,9) (7034,9) (7035,9)
  (7070,9) (7071,9) (7072,9) (7073,9) (7074,9)`.
- **3 x warning 43**: `possible loss of data due to type conversion from 'long' to 'int'`.
  Coordinates: `(11083,16) (11627,28) (13756,14)` in TemplateEngine; the raw control's
  last coordinate is `(13753,14)` because it has no three-line hook insertion.
- **1 x warning 94**: `implicit conversion from 'ENUM_TIMEFRAMES' to 'string'` at `(4570,35)`.

The first wrapper attempt had 6 compiler diagnostics for four unmapped global MagicStart
references (24 warnings); the subsequent focused expert attempt had 1 error for an int
literal passed to `const long&` (24 warnings). Both were fixed within listed paths in
this single repair. Failure receipts/logs remain retained. Initial new-test harness
failures concerned fixture parsing (registry preamble/column name, lexer spacing and
CountAll's CountDir delegation); the final 46/46 run uses the corrected test harness.
No extra implementation attempt is authorized by those successful checks.

## Limits and authority

Native grid/hedge/exit remains the sole lifecycle owner. Shared Stack/Recovery/Hedge/Exit
and generic entry/regime/MM management are HIDDEN_INACTIVE on B21; shared Basket is used
only for its pre-order heat check. `_0_Magic == _21_DF03_MagicStart` is required at init;
DryRun=true and _MG_SelfGate=true refuse init. The source group range is symbol-scoped
base+1..+5, with shared risk evaluated before the native tick. External shared gate GVs
remain keyed to base _0_Magic and retain existing missing/stale-data semantics.
Shared defaults were not changed. No Home/chart TF, E021, B20, Strategy Catalog record,
terminal64 launch, Strategy Tester, backtest, optimization campaign, HOLDOUT, deployment,
runtime attach, trading, commit or push was performed. This is not different-family
acceptance, runtime parity, Candidate evidence, or approval to integrate to canonical.

## Exact changed paths versus HEAD (including carried untracked draft)

All paths below match the frozen lane allowlist. Carried files remain part of the draft;
listing a carried file does not imply its bytes were edited by this repair.

```text
_triage/factory_os/wrapper_owners.csv
docs/PARAM_LINKAGE.md
docs/PARAM_REGISTRY.csv
docs/research/DF03_B21_TEMPLATE_INTEGRATION_20260916.md
docs/research/DF03_GRID_FIBO_ADAPTER_IMPLEMENTATION_20260916.md
ea_template/Boss_21_GridFibo.mq5
ea_template/compat/df03/.gitattributes
ea_template/compat/df03/DF03_Generated.mqh
ea_template/compat/df03/DF03_TemplateEngine.mqh
ea_template/compat/df03/README.md
ea_template/compat/df03/manifest.json
ea_template/compat/df03/parent.mq5
ea_template/compat/df03/template_manifest.json
ea_template/core/Execution.mqh
ea_template/core/InputSurface_gen.mqh
ea_template/core/Inputs.mqh
ea_template/core/LabCore.mqh
ea_template/core/LockedConstants_gen.mqh
ea_template/core/entries/Entry_GridFibo.mqh
ea_template/tests/GridFibo_AdapterCompile.mq5
ea_template/tests/GridFibo_B21_Test.mq5
scripts/_test/run_grid_fibo_b21_tests.ps1
tools/df03_compat/.gitattributes
tools/df03_compat/compile.ps1
tools/df03_compat/compile_b21.ps1
tools/df03_compat/dependency_graph.md
tools/df03_compat/evidence/adapter.log
tools/df03_compat/evidence/b21_check_input_surface_gen.py.log
tools/df03_compat/evidence/b21_check_param_surface.py.log
tools/df03_compat/evidence/b21_check_wrapper_gen.py.log
tools/df03_compat/evidence/b21_compatibility_tests.log
tools/df03_compat/evidence/b21_compile_receipt.json
tools/df03_compat/evidence/b21_fast_cages.log
tools/df03_compat/evidence/b21_focused_initial_failure.log
tools/df03_compat/evidence/b21_focused_tests.log
tools/df03_compat/evidence/b21_harness_compile_failure.json
tools/df03_compat/evidence/b21_initial_compile_failure.json
tools/df03_compat/evidence/b21_param_registry_check.log
tools/df03_compat/evidence/b21_raw_probe.log
tools/df03_compat/evidence/b21_run_input_surface_tests.py.log
tools/df03_compat/evidence/b21_run_locked_constants_metadata_tests.py.log
tools/df03_compat/evidence/b21_run_new_template_entry_tests.log
tools/df03_compat/evidence/b21_run_param_registry_fix_lines_tests.log
tools/df03_compat/evidence/b21_run_template_entry_wrapper_registration_tests.log
tools/df03_compat/evidence/b21_run_wrapper_gen_tests.py.log
tools/df03_compat/evidence/b21_run_wrapper_owner_tests.py.log
tools/df03_compat/evidence/b21_test.log
tools/df03_compat/evidence/b21_test_initial_failure.log
tools/df03_compat/evidence/b21_tpl_regression.log
tools/df03_compat/evidence/b21_wrapper.log
tools/df03_compat/evidence/b21_wrapper_initial_failure.log
tools/df03_compat/evidence/compile_receipt.json
tools/df03_compat/evidence/parent.log
tools/df03_compat/evidence/tests.log
tools/df03_compat/generate.py
tools/df03_compat/prepare_compile.py
tools/df03_compat/template_engine.py
tools/df03_compat/test_b21.py
tools/df03_compat/test_generate.py
```

## Historical pre-repair report (superseded; preserved)

The following was the starting draft, before the owner resolved Python and authorized
this repair. Its blocked-generation and not-run statements are historical only.

# DF03 B21 integration R2 — incomplete author draft

Status: **BLOCKED / OUTSIDE_ALLOWLIST_RUNTIME_DEPENDENCY / NOT COMPILE READY**.
Base and unchanged HEAD: `c02523e930f072a686c69b3cc5326d87c50a3ede`.
Worktree: `D:\EA_LAB_CONTROL\worktrees\ct-df03-b21-integration-r2-20260916`.
Contract: `D:\EA_LAB_CONTROL\evidence\df03-parent-freeze-20260916\B21_INTEGRATION_CONTRACT.txt`.
The R2 lane registry's exact allowlist was read before writes. No commit, push,
terminal, tester, deployment, or runtime attachment was performed.

## Stop condition

Required missing path (not in the lane allowlist):
`D:\EA_LAB_CONTROL\worktrees\ct-df03-b21-integration-r2-20260916\tools\python312\python312.zip`.
The local portable interpreter fails before execution with
`ModuleNotFoundError: No module named 'encodings'`.
Using `D:\EA_LAB\tools\python312\python.exe` read-only allows direct Python tools,
but `scripts/param_registry_check.ps1` hardcodes the worktree interpreter for its
required surface check (lines 250–251). That invocation failed. The existing
PowerShell cage wrappers also name the worktree interpreter.
No archive, interpreter configuration, checker, or out-of-allowlist file was changed.
The owner's instruction to STOP at a new required outside-allowlist path controls.

There is also an unresolved draft implementation finding: the pinned parent is
mixed-newline source. The new `template_engine.py` send anchor expects CRLF;
the actual `ticket = EEFD::OrderSend(...)` seam is LF. Generation refuses with
`ValueError: native send seam drift`. The TemplateEngine and template manifest
were therefore never emitted. This finding is preserved, not called PASS or
reclassified as an environment failure. The draft must not be integrated.
No repair was applied to this finding after the stop. Earlier authoring attempts
also exposed a manifest input-shape assumption and isolated-Python import-path
issue, which were adjusted before this generation attempt; no claim is made
that these attempts constitute a completed acceptance/repair cycle.

## Implemented draft scope

- B21 wrapper and event forwarding; B21 conditional LabCore init/tick/deinit.
- Central source-default inputs P12100–P12113 and wrapper ownership registration.
- Same-symbol, MagicStart+1 through +5 execution ownership for positions/pending.
- Native new-order hook draft with shared gates, account gate only while flat,
  reduce-only macro lot multiplier, risk clamp, broker validation and heat check.
- Reversible TemplateEngine generator draft; raw compatibility control retained.
- Compile-only focused expert draft, not compiled or executed.

No E021/B20 record or strategy catalog modification was made. Shared defaults
were not intentionally changed. Source graph/behavior and other builds have
not yet passed the required acceptance checks for these draft changes.

## Unsupported/inactive shared controls

`_MG_SelfGate=true`, `DryRun=true`, or base magic mismatch refuse B21 init in
the draft. The external GV bridge is keyed by `_0_Magic` (the base identity),
not individual source groups. Existing NewsGuard/MacroGate missing/stale-GV
semantics are inherited; this is not historical-news replay qualification.
Shared Stack/Recovery/Hedge/Exit/Basket management and generic entry, indicator,
regime and MM controls are reported HIDDEN_INACTIVE; source-native owners remain
intended sole lifecycle owners. Basket heat reads account positions and existing
correlation helpers without separate initialization. None of this is runtime-verified.

## Checks actually performed

| Check | This run |
|---|---|
| Base HEAD | Exact match |
| Carried patch SHA256 | `ef856ebf4b5a529c398fb4da3a575ee479e3b130026e2d9c10857a13daacbe5d` |
| Parent SHA256, before and after edits | `2aba9437319e214c82b63313a049f73da364052eddfa24f7f1661279593ffd89` |
| Raw generated SHA256, before and after edits | `564099a9e48abffcfbeceb43b3558f9212ece603309eaf15e6947834aa957115` |
| TemplateEngine generation | FAIL: native send seam drift; no outputs |
| InputSurface generation | Emitted 1,727 lines; not independently checked |
| LockedConstants generation | REFUSED: TemplateEngine missing; output unchanged |
| Registry citation refresh | Applied 221 mechanical citation updates |
| PARAM_LINKAGE generation | 236 rows, 24 contexts, 15 override pairs |
| Registry checker | Identifier coverage/citations passed; full checker failed on local Python |
| Direct check_param_surface invocation | Reported PASS against **index**, not draft; no draft acceptance credit |
| git diff --check | PASS for tracked working diff; untracked authored files not covered |
| Existing compatibility tests | 0 of required 33 run this session |
| New B21 deterministic tests | 0 run; suite/runner not authored |
| Wrapper registration, generation checkers, impacted fast cages | Not run |
| tpl_regression.ps1 -ValidateOnly | Not run |
| Boss_21 wrapper compile | Not run; errors/warnings unknown |
| Focused B21 expert compile | Not run; errors/warnings unknown |
| Raw compatibility probe compile | Not run; errors/warnings unknown |

Carried historical logs are previous adapter evidence, not new compile/test
results. In particular the historical 24 warnings cannot be asserted as this
draft wrapper's warning count.

## Exact changed-path inventory

Modified tracked paths:

```text
_triage/factory_os/wrapper_owners.csv
docs/PARAM_LINKAGE.md
docs/PARAM_REGISTRY.csv
ea_template/core/Execution.mqh
ea_template/core/InputSurface_gen.mqh
ea_template/core/Inputs.mqh
ea_template/core/LabCore.mqh
```

New B21 paths and existing carried paths altered during this session:

```text
docs/research/DF03_B21_TEMPLATE_INTEGRATION_20260916.md
ea_template/Boss_21_GridFibo.mq5
ea_template/compat/df03/.gitattributes
ea_template/core/entries/Entry_GridFibo.mqh
ea_template/tests/GridFibo_B21_Test.mq5
tools/df03_compat/template_engine.py
```

Other carried untracked adapter paths preserved:

```text
docs/research/DF03_GRID_FIBO_ADAPTER_IMPLEMENTATION_20260916.md
ea_template/compat/df03/DF03_Generated.mqh
ea_template/compat/df03/README.md
ea_template/compat/df03/manifest.json
ea_template/compat/df03/parent.mq5
ea_template/tests/GridFibo_AdapterCompile.mq5
tools/df03_compat/.gitattributes
tools/df03_compat/compile.ps1
tools/df03_compat/dependency_graph.md
tools/df03_compat/evidence/adapter.log
tools/df03_compat/evidence/compile_receipt.json
tools/df03_compat/evidence/parent.log
tools/df03_compat/evidence/tests.log
tools/df03_compat/generate.py
tools/df03_compat/prepare_compile.py
tools/df03_compat/test_generate.py
```

## Acceptance ceiling

This is an incomplete author draft, not author-side PASS. After authorized
environment resolution and bounded implementation repair, every requested
source/negative/regression check and all three serial MetaEditor compiles remain
required. Qualified different-model-family core review remains mandatory;
ChatGPT/Codex/GPT-Hermes cannot satisfy it. Gemini qualification remains a
separate limitation; no independent acceptance or canonical integration is claimed.
