# DF03 Grid Horizontal Line / Fibonacci — B21 Prospective Implementation Contract — 2026-09-18

Status: `PROSPECTIVE / IDENTITY_ALLOCATED / SOURCE_BOUND / EXISTING_IMPLEMENTATION_REVIEW_PENDING / NO_MT5 / B21_SOURCE_NOT_CANONICAL`.

Contract base: `bc2e4afe09ca3309b091a032c020140ea1c5a858`.

Can do: `Codex Primary` bounded source author/re-anchor worker under this exact contract; deterministic compile/test tooling; Control Tower acceptance/integration only after all gates pass. Suggested: `Codex Primary` for the one bounded exact-byte re-anchor/repair lane. Required final reviewer: a qualified different-model-family reviewer; ChatGPT, Codex, GPT-backed Hermes, and GPT `/scrutinize` cannot fill that seat.

## Authority reconciliation

The canonical compatibility contract, `DF03_GRID_FIBO_COMPILER_COMPATIBILITY_CONTRACT_20260916.md`, correctly carried `NO IMPLEMENTATION AUTHORITY` and allocated no FamilyID or build token. That historical boundary is not rewritten. The owner's 2026-09-18 direction now prospectively authorizes only the bounded continuation, current-canonical re-anchor, impacted verification, eligible repair, and review of the already-created source-native implementation scope described here.

This contract allocates exactly:

- recovered family: `DF03`;
- prospective FamilyID: `B21`;
- prospective build token: `LAB_ENTRY_21`;
- prospective wrapper: `Boss_21_GridFibo`;
- exact frozen parent SHA256: `2aba9437319e214c82b63313a049f73da364052eddfa24f7f1661279593ffd89`.

The allocation describes only this DF03 implementation. It does not create Strategy Catalog `E021`, make B21 source canonical, or authorize Home symbol, chart timeframe, settings, MT5, performance evidence, risk/default changes, Candidate/Grade/KINT, HOLDOUT, deployment, runtime attachment, DEMO/LIVE, or trading.

## Frozen source-native scope

The admissible implementation is the source-native adapter lineage frozen at exact local head `16d737080a6ff668bb1b2b98df42f622595d867a`. It must retain the immutable parent and compatibility control, the reversible TemplateEngine mapping, B21 wrapper/registration, source-bound inputs and permanent parameter identities, generated input/locked-constant fingerprints, B21-specific execution ownership, LabCore dispatch, focused compile/static tests, compatibility tooling, and evidence already present in that lineage.

The strategy engine remains sole owner of all 126 source blocks, 15 OnTick roots, 2 OnTrade roots, internal `PERIOD_D1` plus `CurrentTimeframe()` dual semantics, ten `Hedging_mode_1_on_0_off == 1.0` gates, native group topology, native order/modify/close behavior, and source SL/TP assignments. The source magic range remains `_21_DF03_MagicStart+1 .. +5`, with `_0_Magic == _21_DF03_MagicStart` required for Template identity. Existing shared safety gates may only veto or clamp a new native order at the already-defined hook; they may not replace or duplicate native Stack/Grid/Hedge/Exit lifecycle semantics. Shared Stack/Recovery/Hedge/Exit remain inactive for B21. No semantic normalization into generic chassis behavior is allowed.

The existing 14 B21 source inputs remain `_21_DF03_*` with PIDs `P12100..P12113`, exact source types/defaults, and no invented optimization ranges or unit claims. Any change outside these frozen mechanics or the exact current-canonical reconciliation needed to carry them is a new strategy-semantic contract, not a repair under this order.

The exact existing implementation allowlist is the 59-path delta owned by `16d737080a6ff668bb1b2b98df42f622595d867a`:

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

Current-canonical re-anchor work may change only these paths. The fixture repair is already an ancestor of the frozen candidate and is not reopened here. Any newly required repository path is an explicit stop-and-return condition; do not widen the allowlist silently.

## Preserved negative and supplied evidence

The candidate's `docs/research/DF03_B21_TEMPLATE_INTEGRATION_20260916.md` status and `tools/df03_compat/evidence/b21_run_input_surface_tests.py.log` remain stale blocked evidence. They must remain visible and must not be edited into a historical PASS. They recorded that the then-current fixture closure omitted `ea_template/compat/df03/DF03_TemplateEngine.mqh`.

The previously missing post-fix input-surface evidence is now supplied externally, not retroactively embedded into that stale report:

- receipt: `D:\EA_LAB_CONTROL\evidence\ct-core-scrutiny-ro-20260918\B21_POSTFIX_INPUT_SURFACE_RECEIPT.json`;
- exact candidate head: `16d737080a6ff668bb1b2b98df42f622595d867a`;
- prerequisite fixture repair: `f720884673829bca358608f8ee3e37c71087dbc4`, verified ancestor of the candidate;
- result: exit `0`, input-surface attack/specificity suite PASS, clean worktree, no MT5 or accepted campaign rerun;
- log SHA256: `652e3b6eb4b8efa7539895572b59f54a610378b9748c85e0ef932a87992770ba`.

This closes the identified missing-evidence item only. It is not canonical source acceptance or the mandatory independent review.

## Exact validation and review boundary

Before integration consideration, one bounded lane must:

1. reverify the exact parent hash and exact source/compatibility control identities;
2. re-check that `B21`, `LAB_ENTRY_21`, `Boss_21_GridFibo`, and `P12100..P12113` remain collision-free on the current canonical base;
3. re-anchor the exact tested B21 bytes onto current canonical without rebase, force push, history rewrite, semantic rewrite, or loss of canonical changes;
4. prove the declared reversible parent -> compatibility control -> TemplateEngine mapping, all 126 blocks, 15 tick roots, 2 trade roots, ten hedge gates, D1/current-TF separation, native group/magic ownership, new-order-only safety hook, untouched native close/modify paths, magic/DryRun/self-gate refusal, and wrapper event forwarding;
5. run the existing 33 compatibility tests, B21 focused positive/adversarial tests, input-surface and locked-constant generators/checkers, wrapper ownership/registration/generation checks, parameter registry/linkage checks, impacted fast cages, required B21/raw-probe compile checks with zero errors and warnings reported truthfully, `tpl_regression.ps1 -ValidateOnly` plus every current mandatory impacted non-tester cage, normal hooks, exact changed-path audit, and `git diff --check`;
6. freeze one clean exact head and obtain qualified different-model-family exact-head review of the execution/position/money integration;
7. only after review PASS may the Control Tower accept and integrate the source.

GPT `/scrutinize` is analytical/process QA and may surface defects or routing gaps; it is not the mandatory review. Gemini qualification V2 timed out without a response or grade, so its competence result is `NO_CONCLUSION`, not PASS or failure. Until a reviewer is positively qualified and reviews the exact frozen head, status remains `BLOCKED_REQUIRED_DIFFERENT_FAMILY_REVIEWER`.

One bounded repair is allowed only for a concrete current-canonical re-anchor or review finding inside this frozen scope. No MT5/terminal/Strategy Tester run is authorized. After reviewed canonical source integration, Home/TF/settings and any fixed MAIN+BWD screen still require separate prospective contracts.
