# QRESET-10 — research preflight capability and seam audit

Date: 2026-09-12. Device: BaBoss (`bbb88aa0-1598-43f6-b56c-a7db22af086a`). BASE: `728dbcb215e10c4be799ed1c4f6443bd7bdf0727`. Origin: `https://github.com/BaBosss/EA_LAB.git`. Isolated lane: `QRESET-10-RESEARCH-PREFLIGHT`. This is the user-supplied bounded task, not a Control Tower contract, owner attestation or new experiment registration.

**A real gap exists in comparing a frozen contract, actual prepared INI, full config, and post-run evidence as one immutable per-cell package.** Existing components already perform most local checks. One additive, opt-in offline seam is implemented in `tools/research_preflight/`; no runner, gate, source, governance or default was modified. The seam has no authority to launch MT5 or accept a research result.

## Existing capability before implementation

| Required fact | Existing exact source / coverage | Missing seam and additive check |
|---|---|---|
| Exact source SHA, EA path | `scripts/execution_reliability/bootstrap_worktree.ps1`, source manifests and harness exact-candidate binding | Compare contract HEAD before/after; verify every declared manifest Git blob at exact source SHA. Does not discover omitted includes. |
| EX5 hash/build receipt | `scripts/lib/build_receipt.ps1`; runner calls Get-BuildReceiptStatus | Bind exact receipt row, EX5 and declared wrapper source hash. Existing receipt registry and compiler provenance remain required. |
| Full set/config SHA | `_triage/factory_os/preset.py`, `scripts/lib/setfile_surface.ps1` | Hash preserved SET and INI; compare exact full contract surface and values. Unknown parameter means not declared by contract; compiler still establishes the actual source input surface. |
| Requested/effective config | Existing runner config identity and Hermes manifest checks | Bound explicit requested/effective expectations and receipt equality. No invented translation from defaults; absent proof UNKNOWN. |
| Full tester INI path/hash | `scripts/mt5_run.ps1` preserves `_mt5_auto/ini/ReportName.ini` | Preserve raw bytes/hash; distinguish actual package resolved path from claimed original launch path. No inference of historical launch paths. |
| Symbol/TF/model/leverage | Runner INI generation; leverage asserted against report, mismatch exit3; Hermes guarded identity | Compare frozen expected fields to INI and available report fields. Missing report facts UNKNOWN. Report parser cannot independently prove model. |
| Account/install/lineage | Hermes manifest identity; Lane Registry scoped runtime claims | Compare bound asserted identity. No API login or current ownership proof from a copied snapshot; live lane eligibility always UNKNOWN. |
| MAIN/BWD and HOLDOUT | Protocol, optimizer guard and explicit contracts | Inclusive interval overlap refusal; MAIN/BWD pair install+lineage identity; no numeric cross-install comparison. |
| Optimization/forward flag | `scripts/mt5_optimize.ps1` guard; `mt5_run.ps1` writes non-optimization mode | Compare exact frozen flag, refuse BWD optimization, refuse unsupported forward mode. Does not accept optimizer XML. |
| Lane ownership/runtime legality | `scripts/lane_registry.ps1`, runtime guards, Hermes safe executor | Check declared snapshot state and known static M4 lane restriction; cannot establish real-time no-concurrency. Existing dynamic guards mandatory. |
| Expected graph/report paths | Runner collects `ReportName*.png`; `mt5_report_assets.py` validates references/signatures | Contract declares launch Report name, original tester destination, collected per-cell paths and native graph paths before spend. Compare post bindings and image closure. |
| Per-cell output identity | Hermes Boss19-specific manifest and batch executor; package integrity tool | Generic declared cell IDs, exact observation population, unique output paths, hash-bound roles. Omitted intended cells cannot be detected without reviewed complete contract. |
| Truncation/end condition | `scripts/lib/truncation_evidence.ps1` schemaV2 and existing checker | Consume typed outcome; REFUSE truncated, UNKNOWN failed/unproven check. Does not infer completion from headline metrics. |
| Hypothesis revision/parent | Protocol, `mt5_optimize.ps1 -HypothesisRevision`, source-bound research docs | Require immutable nonempty contract identity and envelope SHA; legal parent/preregistration authority remains external. |
| Report exists/source binding | `tools/reporting/report_package_integrity.py` manifests | Hash report against separately pinned observations bound to frozen contract. A hash is integrity, not proof of truthful origin. |
| Native graph exact/missing/refused | `tools/reporting/mt5_report_assets.py` | Reuse safe local path/signature closure; bind each actual graph hash. Missing mandatory graph REFUSE, optional missing UNKNOWN, unsafe always REFUSE. No native recreation. |
| Log/year split/parsed metrics | `scripts/parse_mt5_report.py`, `scripts/report_year_split.py`, report authoring fastpath | Bound nonempty log/year split; metrics exactly equal parser output; full ladder/year arithmetic/unit provenance stays with existing consumers. |
| No post-run HOLDOUT leak / cross-install pair | Contracts and protocol | Recheck frozen dates plus available report dates; pair comparison never spans installation/lineage. No claim about unobserved extra experiments. |

`tools/ea_lab_harness/harness.py` supplies evidence and review binding, not a generic tester-INI identity parser. `tools/hermes_ea_lab_pilot/scripts/safe_tester_executor_mcp.py` supplies a strong scoped Boss19 example, not authority for every family. Its `batch_executor.py` is fixture-constrained; treating it as a generic live launcher would exceed its current qualification. `report_package_integrity.py` explicitly says that integrity is not Report Ladder completeness. The additive tool composes existing file/image/parser primitives and does not duplicate these systems.

## Failure evidence and successful reuse

- `docs/research/XX00_B13_B15_MODEL1_SCREEN_CONTRACT_20260909.md` and current state/readiness records establish that preserved B13/B15 runs have exhausted old repair authority. Result head `a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2` has actual INIs, but prior identity omission is not cured by reporting PF. B13 MAIN remains a mechanical hard-kill/truncation record, not a full-window strategy failure.
- `docs/research/B14_GRIDLOG_FIXED_CONFIG_MODEL1_CONTRACT_20260910.md`, result head `c8368ea5a38978780f7a8a7be5f30d3bb0821ef0`: fixed154-field config/control exists. Package-facing missing fields include visible verified basket denominators. Source/config binding and report readability are separate checks.
- Independent QRESET-06 forensic artifact at commit `d9e7c213cad0101401a98389dc1c47972f86456b` reports51/51 preserved primary package files bound,6 set/INI surfaces matched, and24 missing native references across6 reports. These are attributed forensic findings, not a second execution or new package acceptance by this task. No historical graph is reconstructed.
- Accepted `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md` and Boss19 P4/P5 source-bound package/join/session reports show that same-install evidence, typed outcome, units, years and source binding already have successful consumers. Reuse their discipline; do not invent a second verdict/report ladder.

## Exact existing invocation chain and preparation gap

1. From an isolated pinned worktree, dot-source `scripts/use_python.ps1`; run `Assert-PortablePython -Root <worktree> -Provision` if its approved portable stdlib is missing. Claim/check the Lane Registry through `scripts/lane_registry.ps1` under the actual contract.
2. Freeze the approved full source-derived preset, compile through the existing template flow, retain exact build receipt/EX5/source manifest and use existing full-surface/config guards. Preset/compiler and `scripts/lib/*.ps1` are modules/functions, not invented independent CLI subcommands.
3. Materialize the approved tester INI, requested/effective identity and per-cell output plan before launching. **The generic `mt5_run.ps1` currently writes INI just before launching and has no generic prepare-only mode.** A future scoped adapter must expose that handoff. This task did not invoke the runner to obtain a file or add a launcher.
4. Invoke the additive pre-run checker with externally frozen envelope SHA and exact source checkout (full commands/schema in `tools/research_preflight/README.md`). It reads only local evidence/Git. Continue existing live lane/runtime/build checks after any PASS and immediately before any separately authorized launch.
5. Only a future authorized executor may call `scripts/mt5_run.ps1` with explicit Expert, Symbol, Period, FromDate, ToDate, Model, Deposit, Leverage, SetFile, ReportName, terminal/data-dir/lane arguments. Optimizer uses `scripts/mt5_optimize.ps1` and the actual frozen `-HypothesisRevision`. No such invocation occurred here.
6. Preserve raw report/native references/log/INI/receipt/source manifest and typed truncation evidence. `python scripts/parse_mt5_report.py <report.htm> --json` supplies metrics; `python scripts/report_year_split.py <report.htm>` supplies year text. The latter is text, so the seam intentionally checks bound presence rather than imposing a fabricated JSON schema.
7. `python tools/reporting/mt5_report_assets.py <report.htm>` checks native closure. `python tools/reporting/report_package_integrity.py build --spec <spec.json> --out <manifest.json>` then `validate --manifest <manifest.json>` binds the existing package. These tools do not create a missing native graph or accept a strategy verdict.
8. Pin the post-run observation envelope to the original contract SHA, run the new post-run checker, then apply existing Report Ladder/authoring fastpath and assigned review. A PASS is an input-consistency finding only. Optimizer XML post-run acceptance remains unsupported by the new seam.

## Implementation and safeguards

One tool: `preflight.py`, with pre-run/post-run modes, closed JSON envelopes, duplicate/nonfinite JSON refusal, strict INI/SET comparison, EX5/receipt/source bindings, interval/pair checks, typed truncation and reused native-asset integrity. Outputs PASS/REFUSE/UNKNOWN and machine-readable reason codes; exit0/2/3. No subprocess except read-only Git. No network, shell invocation, process kill, runtime lifecycle action, write, threshold or default.

`effective_config` and installation/lane identity are compared as declared evidence, not authenticated. Missing core evidence is not silently synthesized. Native graph signatures cannot establish Balance/Equity meaning. Logs/year split are presence checks. This is deliberately an opt-in inspection seam, not a claim that every required research acceptance condition has become automated.

## Validation and performance

40 unittest cases PASS, including real CLI parsing/hash/exit/no-write checks and all18 minimum adversarial fixtures: missing INI path, INI hash mismatch, wrong symbol, TF, leverage, model, install, HOLDOUT overlap, accidental optimization, moved HEAD, SET hash mismatch, missing/unsafe graph, missing report, truncated run, cross-install MAIN/BWD, duplicate cell and unknown parameter. Additional tests cover graph hash/base injection, EX5/source mismatches, effective-config mismatch, external SET override, INI DEFAULT inheritance, metrics tampering, missing config, unsafe path, duplicate output, malformed JSON, and UNKNOWN handling. The fixtures are synthetic, not EA evidence.

Measured on BaBoss using portable Python,2 tiny synthetic cells, no MT5. In-process100 iterations: pre median6.286ms, p957.585ms, max8.016ms; post median14.845ms, p9516.450ms, max17.035ms. Full CLI5 invocations each, including Python process and Git lookup of one source file per cell: pre median220.775ms/max227.863ms; post median232.286ms/max240.838ms. These are local small-fixture timings, not a prediction for large binary/source graphs or MT5 speedup. Reproduce with `python tools/research_preflight/test_preflight.py --benchmark`.

Integration: suitable for scoped tooling review and optional offline use after normal checks. **Not qualified as a mandatory live launch gate**, not wired into hooks/runners and not a substitute for an independent core review or owner freeze. Direct consumer: future Model1/optimization/Model4 contract preparation and accepted-package handoff, with the optimizer post-run limitation above. No MT5, no strategy authority, no old-contract repair, no canonical edit or push.

## Frozen source inventory

The following inventory is generated from raw Git blobs at the BASE above, not normalized working-tree bytes. The isolated commit identifies the new implementation and this audit; no circular self-hash is required.

| Exact BASE path | Raw Git blob SHA-256 |
|---|---|
| `START_HERE.md` | `8e6d82a6d8d3cef6000cd719bb2be2518c12f49dad6eb34fdda5cf4991d49e78` |
| `PROJECT_STATE.md` | `97effa3233a65527061183e13d142a6208cf2985c85950d898054dd377b2734f` |
| `AGENTS.md` | `ad7fda9114c7c07cbd161b88120ad58d70eee3728264bd1944876d9a7b0bc29f` |
| `AGENT_TASKBOARD.md` | `9cbc4687728ca3795daa27a5e8290ed34dfe8dc6f6038c2cb163e7696319cc89` |
| `docs/research/EA_RND_PROTOCOL.md` | `1cef658a17ac04a0d943b870e55bc704f2c2748eae9a250dc094c940c39a3856` |
| `docs/research/EA_REPORT_SCHEMA.md` | `6feebcc13139dba51df5d403a25ab11b5d0c4b5d41549859091ab9c2cc324c37` |
| `docs/research/EA_REPORT_LADDER.md` | `5902bff8fd6d18d98d153bc654d06e20826254310f8e41f00fc6d3646097c31c` |
| `docs/research/EA_REPORT_AUTHORING_FASTPATH.md` | `8915324a846293256aa65ef1373b8a94c48ff3dd2493783add7be16e74c7cb63` |
| `scripts/execution_reliability/bootstrap_worktree.ps1` | `94b38c17df6bac9dfc3751fe3a41623575cc76c42d65cdef1c3d2c14973bfe28` |
| `scripts/use_python.ps1` | `575f84a6824e50a9b63c23fa8cc604fe20ff6661119daf8f1209bf9bf4bcbccf` |
| `scripts/lib/build_receipt.ps1` | `0e3cd0cc21ffcb0e64ae5cc2cc765912c9b46a18315b803f5318b46d9ffb8ff0` |
| `scripts/lib/setfile_surface.ps1` | `2feb78a0a294e1f828aa40de25f26c4ceea23fb25424534c2afbdb70a12e2aca` |
| `scripts/lib/truncation_evidence.ps1` | `9ebddb18a01ccaae0d2241643f4c31aa2c591660a3639c7f6ee06e79ff56bd70` |
| `scripts/lane_registry.ps1` | `7ddc7fbf09e5f818126c624a1379eb31a93cb3c6a7f681bb82b13f82451c7545` |
| `scripts/mt5_run.ps1` | `b279a548bb5c6cc9a962053116f3ca5eaea5caf83740de9c2574ec45cfe96e42` |
| `scripts/mt5_optimize.ps1` | `9e953165aa8d0a7bc98832be68fc40a0137a6ae2af02c4930939693e2f0415b2` |
| `_triage/factory_os/preset.py` | `06ad1a7c100720788da6ebbac554850688e7415f5b2e3580ece1b862276476ff` |
| `tools/hermes_ea_lab_pilot/scripts/safe_tester_executor_mcp.py` | `3d07747ccf9601d5da503f02b2d30acdeb54f9a5175c4db801d03313ee76ec5f` |
| `tools/hermes_ea_lab_pilot/scripts/batch_executor.py` | `fae8107044470b69d3d44eacb8ffe90dfe54f6c674c05834fcb9785a7e03b606` |
| `tools/reporting/report_package_integrity.py` | `c4d0e4c64eaf923a2621af62b800edbc656cc15847c1db723c8d5f29210fa604` |
| `tools/reporting/mt5_report_assets.py` | `ce0fa598235c1bb6c01a7c75c41239f7dbcb0578d37c761a46d407719870c486` |
| `tools/reporting/post_broad_diagnostic_pack.py` | `32fd33a160c90500947014edd1133268bbe32e9cb19de97ff5cb381abeb7b712` |
| `scripts/parse_mt5_report.py` | `72f120caac4002f3a2df0344387f3cd3de8484b5becfed7eb7c66fe4ec4b00c1` |
| `scripts/report_year_split.py` | `38fbd67afb509a1c998e3d6d804baaf1b47575c32fb77f2d8f19b0b065c73133` |
| `tools/ea_lab_harness/harness.py` | `80cb533f7a7ea4f94dee8c04ea3e3230829067913c7ea663d9f5bf7b91bf000b` |
| `docs/research/XX00_B13_B15_MODEL1_SCREEN_CONTRACT_20260909.md` | `c4d6c4ec69c1ec2959e2687d136539314948811a9833ccec618195cecb904d1d` |
| `docs/research/B14_GRIDLOG_FIXED_CONFIG_MODEL1_CONTRACT_20260910.md` | `dc5b120137a414f926627965a770af39d6fd7e26a2eda08cd55ccaf37b94afb4` |
| `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md` | `eff1ae3630261a8b9cc1c16205ca4c7960c93691aeaf528bd237f356f48f2ef6` |
| `docs/research/BOSS19_P4_BROAD36_PACKAGE_REVIEW_20260902.md` | `bb331765f169503ad878223d54a6f45fd2bb6e289609ae671857e298384463a4` |
| `docs/research/BOSS19_P4_REGIME_ATTRIBUTION_JOIN_RESULT_20260903.md` | `807c2dc102253b967fc9dc3587ce7006ea0c2447556901716ffe7079096b6e58` |
| `docs/research/BOSS19_P5_SESSION_CONTEXT_RESULTS.md` | `276ae46563a1434678ef951ea548663f913d9f37059ca9d57dc81d67dacf92ed` |
