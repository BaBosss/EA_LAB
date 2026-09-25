# EA Monitor Source Adapter Integration V1 — 2026-09-24

## Scope and source identity

- Bounded author lane: `ct-monitor-source-adapter-integration-v1-20260924`.
- Exact author base: `4219785c6f4cc6c0f38ec3cdf92869160eb522ca`.
- Main CT mechanically reanchored the validated six-path candidate onto fresh canonical parent `6c62d87abb4dede2d7cc930ae0cfe06fc2ec7166` after verifying zero canonical overlap from the original author base across the candidate paths. The earlier `1ff86cb8fd8fca6eae747ea7a9457dfde4653624` reanchor was superseded by this later orthogonal canonical advance; no source-adapter bytes were changed by either reanchor.
- Accepted adapter lineage: `ea-observation-adapters-v1-20260923 = DONE`.
- Accepted adapter source head: `16ab10ec2af1c19adbdcbbc351d357fc4376a1b1`.
- Adapter closeout remains `SCRUTINY_PASS / HIGH` for OA001, OA002, and OA003, with `REAL_DATA_STILL_PARTIAL_UNQUALIFIED` unchanged.
- The accepted adapter package under `tools/mobile_report_hub/source_adapters/` was consumed but not modified. Existing owner Monitor truth and Work-triage semantics were not changed.

This change adds a bounded `source_observations` projection to the existing owner Monitor snapshot and displays that projection on the existing Runtime page. It does not create a collector, writer, task, scheduler, service, deployment, or second monitoring product.

## Integration and trust design

`Model.snapshot` treats the adapter as optional read-only evidence. The installed delivery requires a versioned adapter bundle containing exactly the fixed eight-file import allowlist: the adapter package plus its two project-local dependency modules. Before every execution, the Monitor reads those eight paths from its configured read-only `adapter_root`, verifies them as regular, non-linked, non-reparse files within that root, and compares every local byte sequence with the exact Git blob at `self.sha` from the separate configured Git repository.

The adapter runs in a fresh isolated portable-Python subprocess using `sys.executable`, `-I`, and `-B`. Repair1 also supplies `-X pycache_prefix=<unique non-existent path>` and fails closed if that path unexpectedly exists after execution, so a pre-existing `__pycache__` beside the installed bundle cannot override the verified `.py` bytes. A short launcher prepends only the verified `adapter_root` to `sys.path`, imports `BuildRequest` and `build_observations`, and separately passes the configured Git repository as `BuildRequest.repo` together with the exact canonical ref, snapshot/ledger root, and runtime root. The process emits compact JSON only, has a 40-second timeout, and the launcher and parent both enforce a 4,000,000-byte stdout ceiling before JSON parsing. No shell, network source, collector, MT5 action, or write endpoint is involved.

After the subprocess ends, the same bundle allowlist is re-read and re-bound to the exact current canonical Git blobs. This byte binding means unrelated canonical advancement remains usable when the eight accepted blobs are unchanged, while any adapter or dependency source drift fails closed until a matching versioned bundle is republished and reviewed. Any pre-read mismatch, missing file, link/reparse/unsafe file, unreadable file, post-read drift, timeout, nonzero exit, oversized output, malformed JSON, or invalid schema/ref/authority/integration shape makes only `source_observations` `UNAVAILABLE`; the rest of the Monitor snapshot remains usable.

The configured Git repository and the installed adapter bundle are deliberately distinct. `D:\EA_LAB` remains the repository used for exact Git blobs, canonical metadata, and `BuildRequest.repo`; its dirty working tree does not need to contain the eight import files. This source-integration change does not itself install or copy the bundle. During the Main Control Tower delivery phase, Main CT will copy the exact reviewed/canonical bytes into the versioned Owner Monitor application and launch it with `--adapter-root` pointing at that bundle.

The projection excludes raw paths, source IDs, account/deployment/stream IDs, ticket IDs, monetary fields, and arbitrary producer prose. It retains only bounded counts, fixed codes, opaque finding IDs, fixed next actions, section qualifications, producer binding/identity state, and explicit clock/effectiveness limitations. It does not aggregate P/L across currencies, infer trade cycles from deal events, replace missing ledgers with zero, convert broker timestamps to UTC, or turn matching fields into identity PASS.

## Real-source smoke

One read-only smoke was run from the exact author worktree against:

- snapshots/ledgers: the supplied `daily-monitor-aec3dd24-20260914/portfolio/live_deals` root;
- runtime: the supplied `daily-monitor-aec3dd24-20260914` root;
- repository/ref: this worktree at `4219785c6f4cc6c0f38ec3cdf92869160eb522ca`.

Observed projection at `2026-09-24T16:27:24Z`:

- source status `AVAILABLE`; overall `PARTIAL`; schema `ea_observation_adapters/1`;
- budget: 334 files, 39,765,892 bytes, 429,067 rows;
- accounts: `PARTIAL`, 6 accounts, 144 samples, 0 conflicts, 0 qualified series;
- ledger: `PARTIAL`, 6 accounts, 4 with ledger, 2 missing ledgers, 11,152 deal events, 69 streams, 0 quarantined, all-cost completeness false;
- ledger latest coordinate `2026-09-24T12:56:19`, explicitly `BROKER_TIME_UNQUALIFIED`;
- deployments: `PARTIAL`, 64 declarations, 1 expected identity present, 0 `FIELDS_MATCH_ONLY`;
- producer: `DIFFERENT_REPO_HEAD`, identity `FAIL`, generated `2026-09-24T13:35:13Z`;
- guards: `PARTIAL`; News calendar and MRIS are context only; effective state remains `null` / `UNKNOWN`;
- access provenance: `UNAVAILABLE`;
- fixed adapter findings: 3;
- projection checks: no private local path and no raw account ID present.

No collector was triggered by this smoke.

Main CT also performed an installed-delivery simulation after the installability correction: `repo=D:\\EA_LAB` (whose dirty working tree intentionally lacks the eight adapter import files) plus a separate versioned adapter bundle materialized from exact canonical Git blobs. At canonical `1ff86cb8fd8fca6eae747ea7a9457dfde4653624`, the projection remained `AVAILABLE / PARTIAL` with the same 334-file / 39,765,892-byte / 429,067-row input budget, and the bounded projection contained no raw account IDs or private local paths. This proves the installed Monitor does not depend on resetting or updating the dirty primary checkout.

## Verification performed

- portable Python provision/assertion through `scripts/use_python.ps1`;
- `python tools/mobile_report_hub/owner_webapp/test_owner_webapp.py` — 44 tests passed after Repair1, including command-contract coverage for an isolated non-existent Python bytecode-cache prefix;
- bounded adversarial proof for `MONSRC-001`: `python -I -B` loaded a forged same-size/same-mtime cached `evil` bytecode over verified `safe` source, while the repaired `-I -B -X pycache_prefix=<non-existent>` execution loaded `safe` and did not create the isolated prefix;
- `node --check tools/mobile_report_hub/owner_webapp/owner_webapp.js` — passed;
- `node tools/mobile_report_hub/owner_webapp/test_work_ui.cjs` — original 18 Work UI assertions plus 12 source-observation Runtime assertions passed;
- `node tools/mobile_report_hub/owner_webapp/truth.test.cjs` — passed;
- `node tools/mobile_report_hub/owner_webapp/browser_truth.cjs` — 15 real snapshot/serialization/truth/DOM scenarios passed using the installed local `playwright-core` via process-local `NODE_PATH`;
- `powershell -File scripts/_test/run_mobile_report_hub_data_tests.ps1` — 154 tests ran successfully: 153 passed and one existing privilege-dependent symlink case was skipped;
- `powershell -File scripts/_test/run_mobile_report_hub_ui_tests.ps1` — passed;
- `git diff --check` — passed.

## Limitations and authority ceiling

- `PARTIAL` and unqualified observations are not verified runtime state, freshness, profitability, acceptance, or deployment evidence.
- Deal-event counts are not trade counts or reconstructed cycles.
- Missing ledgers remain explicit gaps; fee/all-cost incompleteness remains visible.
- Broker-time coordinates remain timezone-unqualified.
- News and MRIS observations are context only and do not prove an effective EA guard.
- Producer identity `FAIL` and `DIFFERENT_REPO_HEAD` remain visible and are not softened by field matches.
- Browser refresh only rereads and derives existing local evidence.
- This work grants no runtime, deployment, MT5, trading, risk/default, DEMO/LIVE, or acceptance authority.

The reanchored source is committed only as a clean exact-head candidate for Main Control Tower freeze and independent acceptance-grade GPT Scrutiny. Commit presence is not acceptance or integration; no runtime delivery follows until that review passes.
