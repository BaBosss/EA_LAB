# B15 xx-00 self-contained provenance contract — 2026-09-13

Status: FROZEN / NEW PACKAGING-ONLY CONTRACT / NO MT5 / NO STRATEGY AUTHORITY.
Owner authorization: current Control Tower continuation after the 2026-09-12 salvage milestone stopped at its repair/review limits.

## Objective and direct consumer

Produce one canonical, reusable B15 preserved-evidence package that can validate from a genuinely fresh clone of only its accepted Git lineage. The package must not require the unpushed rejected object `a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2`, any local-only salvage branch, or the current contents of `D:\Meta 5c`.

Direct consumer: future reports / Second Brain / research review that need source-bound B15 MAIN+BWD evidence without replaying MT5. This contract does not reopen `ORDER-XX00-MODEL1-SCREEN-V1` and does not change its blocked acceptance status.

## Frozen sources

- Start implementation only from the pushed canonical commit that contains this contract; re-anchor if `origin/master` moves before implementation.
- Original execution contract: `docs/research/XX00_B13_B15_MODEL1_SCREEN_CONTRACT_20260909.md`.
- Historical local execution locator: `a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2`, B15 subset only. It is an acquisition locator, not a runtime validation dependency.
- Historical B15 salvage author lineage: `e14b9c65b10abd3e79af84cdafc6899b545388fa` -> `a1d26ce78f1d78b1dd0e73e5d54a4ba0c51736b8`. These are read-only evidence locators, not accepted canonical parents.
- Final 2026-09-12 milestone review finding: package validation still depended on the unreachable rejected Git object and on current `D:\Meta 5c` EX5 availability. The new package exists solely to remove those two dependencies.
- Preserve B15 identity: GBPUSD/H4, Model1, leverage 1:100, Deposit 10000 USD, Optimization=0, ForwardMode=0, MAIN 2023-2025, BWD 2020-2022, full input surface 157/157/157.
- Preserve report observations: MAIN PF 0.28 / net -357.84 / 13 trades / native maximal EqDD 5.83%; BWD PF 2.12 / net +137.96 / 24 trades / native maximal EqDD 6.37%.

## Output boundary

Write only:
- `docs/research/B15_XX00_SELF_CONTAINED_PROVENANCE_RESULT_20260913.md`
- `factory/runs/b15_selfcontained_provenance_20260913/**`

The package must contain every byte needed to validate its preserved evidence: raw reports, INIs, set, sidecars, required log/identity/receipt extracts, source/provenance manifest, machine-readable cells, derived summaries, presentation views, integrity manifest, validator, and tests.

If retained EX5 bytes are acquired and their SHA256 matches the recorded build receipt, copy those bytes into the package once and label them `PACKAGING_TIME_RETAINED_ARTIFACT_MATCH`. That observation is not historical loaded-memory proof. Later validation must use only the packaged copy; absence or mutation of `D:\Meta 5c` must not affect validation.

Historical Git SHAs and absolute runtime paths may appear only as provenance strings. The validator must not call `git show`, `git cat-file`, or otherwise require an object that is not reachable from the accepted package lineage. It must not open evidence from an absolute path outside the package.

Native MT5 images remain 8 x `MISSING`; native graph closure remains `INCOMPLETE`. Do not manufacture, reconstruct, or relabel native images. Independent basket/episode semantics remain `UNKNOWN` unless proven from bytes already included in this package; raw L0 tags are not automatically independent baskets.

## Required deterministic checks

1. Two unique B15 cells; explicit tester identity and original launch INI path stays `UNKNOWN` unless a source-bound launch receipt exists.
2. Set / tester INI / report input maps are exactly 157/157/157 with duplicate/key/value refusal.
3. Raw package bytes and declared SHA256/size inventory reconcile; report/sidecar/log identities remain unchanged.
4. Canonical parser-equivalent report metrics, year splits and participation outputs reconcile from packaged bytes; any parser discrepancy is explicit, never silently normalized.
5. Four R1 presentation roles remain source-bound and state that native graph closure is incomplete.
6. Integrity manifest covers every package artifact except its own self-hash by the canonical manifest rule.
7. Validator resolves all evidence paths under the package root and refuses path traversal / absolute evidence paths.
8. No MT5/tester/compile/optimization/HOLDOUT invocation occurs.

## Fresh-clone acceptance

After the candidate package commit is frozen, create a bundle/clone containing only the candidate lineage (no shared object database and no local salvage refs). In that clone:
- `git cat-file -e a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2` must fail;
- the package validator and its negative tests must still PASS;
- current `D:\Meta 5c` availability must be irrelevant to validation;
- mutation/deletion of a packaged raw artifact must fail closed;
- an injected absolute evidence path or traversal path must fail closed.

Acceptance is package-only. A PASS does not create a new strategy verdict, fix B13 MAIN, change B14 `NO_USEFUL_CONTROL_PULSE`, ratify sample adequacy, or unlock optimization/Model4/HOLDOUT/Candidate/Grade/KINT/risk/default/runtime/deployment/trading authority.

## Budget and stop rule

Deterministic/local work first. One packaging implementation pass, one independent exact-head docs/tooling review, at most one bounded repair, then one targeted recheck. A repeated unresolved question or failure after that repair is BLOCKED; do not open another salvage loop merely to obtain PASS.

No MT5/tester run, no compile, no rerun/retune, no BWD mining, no new Home, no strategy/core/config/risk/default mutation, no HOLDOUT, no deployment or trading. Preserve the failed 2026-09-12 salvage attempts as negative evidence; do not rewrite their history.
