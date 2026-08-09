# Codex Audit 5 — Orders S2a/S3a and the three self-found fixes

Date: 2026-07-30  
Mode: independent, adversarial, read-only except for this report  
Audited HEAD: `0a9a71ef`

## Measurements

- `gen_design_contracts.py --check`: **GREEN**, 27 generated blocks.
- `run_contract_binding_tests.py`: **GREEN**, 15/15 declared cases; all 7 historical regressions caught.
- `run_schema_fixtures.py`: **GREEN**, 17/17 declared cases; the real v3 snapshot still fails as expected and is not counted.
- `scripts/_test/run_fast_cages.ps1`: **GREEN**, 11/11 suites, **14.0 s** measured.
- Independent line-ending matrix: LF, CRLF, and alternating mixed LF/CRLF were GREEN in both Python entry points.
- Independent depth mutation: `walk_fields` raised `DepthExceeded` at
  `depth_probe.child.child.child`; the generator path maps that to exit 1, and the binding process exited 1.
- Current schema: 24 `$defs`, 2 non-entity meta contracts, 27 generated blocks including `__STORAGE__`.
- `MASTER_BACKLOG.md` §2: 7 EA data rows but **8 bold LIVE cells**; attempted/rejected symbol cells are
  additional facts not normalized into independently countable rows.

## Q1 — Verdict: **Both Orders can be reported DONE without completing their intended work; amend both before dispatch.**

### ORDER-600, item by item

| Location | Criterion | Cheapest letter-compliant output that defeats the purpose | Defect and rewrite |
|---|---|---|---|
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:25-29`, `:36-38` | Every storage fact; every `$defs` entity exactly once; count = 24 | Emit 24 entity names exactly once and put `TBD`, a repeated owner, or fabricated hashes in every other column. | **Defect:** the acceptance checks entity-name cardinality, not the deliverable's facts or fields. `__STORAGE__` is one row per entity, while “every fact” is not defined as a countable set. **Failing case:** 24 rows named from `$defs`, all with `current_owner=schemas.json`, pass the count while documenting no real ownership. **Rewrite:** define a machine-readable table schema; require exact set equality with generated `__STORAGE__` rows and non-empty, vocabulary-checked current owner, proposed owner, canonical/derived, break-if-moved, break-if-not-moved, and OwnerRef columns. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:29`, `:35-43` | Exact `OwnerRef` | Put syntactically plausible `a…a` commit, `b…b` blob and `c…c` SHA values in every row. | **Defect:** no acceptance item recomputes any ref. **Failing case:** the same all-`a`/`b`/`c` OwnerRef for all 24 entities satisfies presence and shape. **Rewrite:** a checker must resolve the path at `commit_oid`, compare `blob_oid` to Git, and recompute `raw_sha256`; zero unresolved or mismatched refs. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:30-31`, `:39` | Zero `APPROVED` rows | Mark every row `PROPOSED`, including rows with no viable migration or signer. | **Defect:** numeric and checkable, but it proves only that approval was not forged. It does not prove a sign-off request is actionable. **Failing case:** 24 `PROPOSED` rows with `signoff_owner=""` pass this item. **Rewrite:** keep zero APPROVED, but additionally require exactly one sign-off row per distinct current owner, a named signer, scope, and `PROPOSED` or `REFUSED`; no unknown state. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:40-41` | Named owner only when proposed owner differs | Set every proposed owner equal to its current owner. | **Defect:** the conditional is vacuous and allows the document to avoid proposing the Coverage transfer that ORDER-600 exists to prepare. **Failing case:** `MASTER_BACKLOG.md -> MASTER_BACKLOG.md` for Coverage needs no named migration owner and passes. **Rewrite:** explicitly require the Coverage edge `MASTER_BACKLOG.md §2 -> factory/coverage.jsonl` to be represented as `PROPOSED` or `REFUSED`; either state requires a named decision owner and rationale. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:42-43`; `MASTER_BACKLOG.md:29-37` | “coverage cells” count equals §2 real row count | State `coverage_cells=7`. | **Defect:** this equates cells with rows. There are seven EA rows, but the LIVE column alone contains eight cells because `ST_EA03` has GBPUSD H1 and USDCAD H1 (`MASTER_BACKLOG.md:33`). The final column contains many more attempted cells. **Failing case:** `7 == 7 rows` passes while losing one LIVE cell and all rejected/unsmoked cells. **Rewrite:** count source EA rows consumed separately from normalized CoverageCells emitted; require a source-token-to-cell mapping and reconciliation: every source row consumed once, every parsed symbol/TF/status token emitted once or marked `UNVERIFIED_IMPORT` with source coordinates. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:28`, `:32-33` | “what breaks” and reverse-migration paragraph per moved fact | Repeat generic prose such as “dashboard may break; revert the commit” for every row. | **Defect:** human prose only; no executable acceptance criterion distinguishes analysis from boilerplate. **Failing case:** 24 copied paragraphs pass the stated form. **Rewrite:** label these explicitly **human review**, with a reviewer checklist requiring named readers/writers, command or file affected, reversible steps, evidence lost, and retention window. Do not call this portion “numeric, checkable.” |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:45-49` | Prohibitions | Avoid the named files while silently proposing no transfer. | **Defect:** the prohibitions are individually checkable by a path diff, but they do not establish completion. **Failing case:** a one-file 24-name document with no meaningful migration obeys all prohibitions. **Rewrite:** retain them as scope guards, not acceptance evidence. |

### ORDER-601, item by item

The common cheap implementation is:

1. return `all_clear=false` for every input except one fixture whose `build_id` is hard-coded to return true;
2. make every negative fixture invalid for an unrelated reason; and
3. report AJV/validator rejection without asserting the error path or computed reason.

The single positive case blocks only a literal constant-false implementation. It does not block the fixture-name/build-id
special case or prove that any named predicate caused a failure.

| Location | Criterion | Failing case that slips through | Required rewrite |
|---|---|---|---|
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:75-76`, `:104`; `_triage/factory_os/run_schema_fixtures.py:149-159` | One fixture per bullet, observed fail-before/pass-after | Add named cases but make each invalid because `entity` is absent. AJV returns nonzero, so each expected-fail case is reported OK even though the named rule was never reached. `run()` reduces every nonzero result—including tool/schema errors—to `False`. | Every negative must be a **one-field delta from a known-valid positive**, assert a stable validator reason code/error path, and have a paired control that becomes valid when only that delta is repaired. Preflight AJV/schema readability separately; tool failure is ERROR, never “instance rejected.” Record a mutation table showing each predicate disabled and only its named fixture turning red. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:79` | Missing mandatory source ⇒ false | `mandatory_sources=["A"]`, `sources=[]`, but the fixture also omits `system_health`; rejection/false can be credited to “missing source.” | Require valid whole-root baseline, mutate only removal of source A, and assert output reason `MANDATORY_SOURCE_MISSING:A`. Also test registry/list set reconciliation. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:80-82` | Unreadable is false and distinct from missing | Emit `all_clear=false` for both with no state or with two different free-text messages that no consumer checks. | Require distinct closed output states/reason codes, e.g. `MISSING` and `UNREADABLE`, and assert their exact paths. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:83`, `:102-103`; `scripts/control_room_snapshot.ps1:383-389` | Stale ⇒ false using existing threshold | Trust a caller-supplied `fresh=false` fixture, never read `stale_bar_hours`, and still pass. The current schema does not carry the real v4 `stale_bar_hours`, `decision_bar_trades`, or `counting_method` fields (`_triage/factory_os/schemas.json:623-646`). | Fixture must vary `age_hours` across the supplied `stale_bar_hours` boundary and prove the validator derives or verifies freshness. Builder input must carry the existing threshold and compatibility meta fields; no hard-coded threshold. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:84-85` | `sources=[]` with `all_clear=true` rejected | Put this object through the **builder-input** schema. It is rejected merely because `all_clear` is forbidden, so the empty-source invariant is never tested. Alternatively submit a persisted document: its required `all_clear=true` remains schema-valid unless computation is rechecked. | Split into two attacks: (a) builder input with `sources=[]` and no `all_clear` must emit false with `MANDATORY_SOURCE_MISSING`; (b) a complete persisted output with `sources=[]`, `all_clear=true` must be rejected by output recomputation, naming the mismatch. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:86` | Builder input carrying `all_clear` rejected by schema | Include `all_clear` and also omit another required field; any rejection is counted. | Use a minimal pair: the fixture without `all_clear` passes the input schema; adding only `all_clear` fails, and the AJV error path/keyword names that property. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:87-90` | Reconciliation predicates ⇒ false | A validator can special-case the supplied cases or reject them for malformed surrounding data. It can also return true for `actionable=1`, because ORDER-601 omits the “no actionable item” predicate stated in `_triage/factory_os/schemas.json:677`. | Use one valid healthy seed and one-field mutations for every predicate. Add the omitted `categories.actionable > 0 ⇒ false` case. Assert exact reason codes and recomputation of the final persisted output. |
| `_triage/factory_os/schemas.json:652-676`; `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:87-90` | Count arithmetic | Balanced negative values pass the schema because category, coverage, duplicate, conflict and unclassified integers lack `minimum: 0`. | **Failing case:** `discovered=0`, `categorized=0`, categories `{actionable:-1,running:1,...}`, coverage `{cells_in_universe:0,tested:-1,untested:1,not_applicable:0}`, conflicts=0, unclassified=0. All equations balance. Add nonnegative constraints and fixtures. |
| `_triage/factory_os/schemas.json:631-645`; `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:79-85` | Mandatory-source identity | `mandatory_sources=["A"]` with source `{name:"A", mandatory:false, read_ok:true, fresh:true}` can be accepted by an implementation that filters on the row's `mandatory` flag rather than the registry. Duplicate names are also currently allowed. | Require unique registry and source names, exact registry/list membership checks, and a fixture for a contradictory row flag. Prefer removing the redundant per-row `mandatory` boolean or prove it agrees with the registry. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:91-93` | One healthy positive ⇒ true | Return true only when `build_id=="fixture-healthy"`; false otherwise. All declared cases pass. | Use at least two independently constructed healthy inputs (non-zero counts and reordered sources), then mutation-test each computation predicate. Do not let test-only IDs reach validator logic. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:94-95`; `_triage/factory_os/schemas.json:598-616` | Validator reads whole persisted shape | Read one top-level property, then validate/emit only `meta`; prose can claim the whole document was read. `ControlRoomSnapshotV5` is also open to arbitrary top-level fields. | Assert output against the root discriminator and whole `ControlRoomSnapshotV5`; use a valid whole document, then independently remove `entity`, `system_health`, and `summary` and require root-path failures. Assert seeded compatibility fields survive input→output. |
| `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:96-97`; `_triage/factory_os/run_schema_fixtures.py:177-188` | Real v4 snapshot need not pass | The runner can print FAIL because the file is unreadable or the tool failed and still exit 0 if all counted fixtures pass. | This is a valid S3a scope exclusion, not acceptance evidence. Still distinguish expected schema incompatibility from read/tool error before printing the diagnostic. |

**Criteria checkable only by human prose:** ORDER-600 breakage analysis and reverse migration; ORDER-601's
claim that a case was observed failing “before,” unless a mutation artifact is generated; “real thing, not a stub”;
and “reads the whole persisted document” without a whole-root mutation test.

**Criteria satisfiable by a fixture never shown to fail for the named reason:** every ORDER-601 negative in
its present form, because no item requires a minimal pair plus reason/path assertion.

**“Tool clean” equivalent to “tool read nothing”:** `_triage/factory_os/run_schema_fixtures.py:149-159`
collapses all AJV nonzero exits into an expected rejection for negative cases. The suite's positive cases keep a
total tool outage from making the whole current runner green, but an individual negative criterion can still pass
for tool/schema failure rather than the named rule. ORDER-600 has no specified checker at all.

## Q2 — Verdict: **The input/output split is directionally right, but it makes supply rejection checkable—not truthful persistence—unless output is recomputed at the trust boundary.**

### Attack against the proposed split

1. A closed `SnapshotBuilderInput` with an extra `all_clear=true` should be rejected. That original attack dies,
   provided the fixture proves `all_clear` is the only invalid delta.
2. Submit a complete `SnapshotBuilderInput` with `mandatory_sources=["A"]` and `sources=[]`. The schema can accept
   this input because emptiness is an observation, not itself malformed. The validator must compute false.
3. Bypass the builder and create a complete persisted `ControlRoomSnapshotV5` with the same empty sources and
   `all_clear=true`. JSON Schema can establish that the boolean exists and has the right type; it cannot establish
   authorship or derivation. Unless every reader invokes the recomputation check, this persisted attack survives.

Locations and concrete failure:

- `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md:59-74` — **defect:** “written only by the validator” is a
  provenance statement, not a schema property. **Failing case:** a hand-authored output with a structurally valid
  true boolean bypasses the input schema.
- `_triage/factory_os/schemas.json:647-677` — **defect:** the output schema encodes fields but not the arithmetic
  or source-set invariant. **Failing case:** the balanced-negative instance in Q1, or empty sources plus true,
  remains structurally valid.
- `_triage/factory_os/schemas.json:598-616` — **defect:** the output root permits arbitrary top-level properties
  and only four roots are required. **Failing case:** a validator that constructs `{entity,meta,system_health,summary}`
  and drops the seeded `floating_risk`, deployments and compatibility fields still validates.

### Simpler surviving shape

**Recommendation (design opinion):** keep two public interfaces but only one shared closed evidence shape:

- `SnapshotBuilderInput`: the whole current snapshot facts plus a closed `ReconciliationEvidence` with no
  `all_clear`;
- `ControlRoomSnapshotV5`: the same preserved facts plus validator-owned `all_clear` and a closed list of
  reason codes;
- one output verification function recomputes the result from persisted evidence and rejects a mismatched boolean.

This avoids copying the entire reconciliation contract twice while preserving the useful property that supplied
`all_clear` is impossible at the builder boundary. It cannot prove who typed a file, but it makes a lie detectable.
S4 readers must accept the snapshot only through that output verifier.

### Compatibility impact

- `scripts/control_room_snapshot.ps1:372-409` writes the real whole v4 document directly. ORDER-601 prohibits
  writing the live output, so it does not break that file during S3a; integration remains S4 work.
- `portfolio/control_room_snapshot.json:4-9` is currently v3 on disk. Its expected schema failure is already a
  non-gating diagnostic in `_triage/factory_os/run_schema_fixtures.py:177-188`.
- `scripts/daily_monitor.ps1:89-94` reads the whole snapshot through `Get-MonitorCoverage`; the reader uses
  `system_health` and `floating_risk` and does not inspect `all_clear`
  (`scripts/lib/monitor_coverage.ps1:91-124`). An additive v5 root does not immediately break it, but it also means
  ORDER-601 alone does not put the new invariant on this trust path.
- Measured search found no `control_room_snapshot` read in `make_status.ps1` or
  `make_taskboard_digest.ps1`; design S4 explicitly owns that future integration
  (`_triage/EA_LAB_FACTORY_OS_DESIGN.md:1509-1511`). Therefore there is no current reader break there.
- The material compatibility risk is loss of current v4 fields: `stale_bar_hours`, `decision_bar_trades`,
  `counting_method`, and the real source-row metadata are written at
  `scripts/control_room_snapshot.ps1:383-389` but absent/closed in current `SnapshotMeta`
  (`_triage/factory_os/schemas.json:619-646`). The input/output boundary must preserve them rather than silently
  projecting them away.

## Q3 — Verdict: **CRLF/LF and loud depth failure are real; the trigger widening is real for the two newly named paths but still incomplete.**

### (a) Pre-commit trigger

- `.githooks/pre-commit:122-133` — **real fix:** `_triage/factory_os/schemas.json`,
  `_triage/factory_os/gen_design_contracts.py`, the binding harness, and
  `_triage/EA_LAB_FACTORY_OS_DESIGN.md` now match the trigger and run the fast tier.
- `.githooks/pre-commit:122` — **defect:** the hook itself is not matched. **Failing case:** stage a change that
  deletes or narrows `cage_staged`; no fast-cage trigger is produced by that file.
- `scripts/_test/run_optimize_guard_tests.ps1:38`; `scripts/optimize_guard.ps1:98-100` — **defect:** a fast suite
  executes the real optimize guard, which reads `docs/PARAM_REGISTRY.csv`, `docs/PARAM_LINKAGE.md`, and
  `_triage/PARAM_INACTIVE_AUDIT.md`; none matches the pathspec at `.githooks/pre-commit:122`.
  **Failing case:** stage a malformed override pair in `docs/PARAM_LINKAGE.md`; the guarded behavior changes but
  the fast tier does not run.
- `scripts/_test/run_contract_binding_tests.ps1:39-50` — **defect:** the suite also depends on
  `tools/python312/python.exe`, which does not match. **Failing case:** stage an incompatible/missing interpreter
  while no matched path is staged; the suite does not run.

Independent pathspec measurement:

| Path | Tracked | Matches current trigger |
|---|---:|---:|
| `_triage/factory_os/schemas.json` | yes | yes |
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | yes | yes |
| `scripts/optimize_guard.ps1` | yes | yes |
| `.githooks/pre-commit` | yes | **no** |
| `docs/PARAM_REGISTRY.csv` | yes | **no** |
| `docs/PARAM_LINKAGE.md` | yes | **no** |
| `_triage/PARAM_INACTIVE_AUDIT.md` | yes | **no** |
| `tools/python312/python.exe` | yes | **no** |

The complete fix remains D32's declared dependency manifest, not another widening.

### (b) CRLF/LF normalization

- `_triage/factory_os/gen_design_contracts.py:459-490` and
  `_triage/factory_os/run_contract_binding_tests.py:143-163` normalize CRLF to LF before semantic comparison.
- Independent in-memory runs over the committed design produced:

| Bytes presented | Generator | Binding | Agree |
|---|---|---|---|
| LF | GREEN | GREEN | yes |
| CRLF | GREEN | GREEN | yes |
| alternating LF/CRLF | GREEN | GREEN | yes |

No remaining LF/CRLF byte path was found where the two entry points disagree. The generator preserves the working
file's convention when it must write (`gen_design_contracts.py:516-518`). **Opinion:** add these three variants as
a permanent fixture; the code is correct now, but the self-fix is otherwise protected only by review.

### (c) Depth overflow

- `_triage/factory_os/gen_design_contracts.py:154-174` now raises after `MAX_NEST_DEPTH`; it no longer silently
  emits no nested rows.
- `_triage/factory_os/gen_design_contracts.py:475-482` catches the exception and returns 1.
- `_triage/factory_os/run_contract_binding_tests.py:175-180` catches `KeyError` only. With an independently
  injected depth-4 object, it raised an unhandled `DepthExceeded` and the Python process exited **1**. This is loud,
  although the traceback is less controlled than the generator's message.
- `scripts/_test/run_contract_binding_tests.ps1:61-69` converts any child nonzero into suite exit 1, so the
  PowerShell wrapper propagates the failure.
- **Completeness defect:** no committed binding case creates a too-deep schema
  (`run_contract_binding_tests.py:56-138`). **Failing case:** a future edit changes the cap branch back to
  `return []`; all 15 current cases can stay green because none crosses the cap. Add a depth mutation expecting
  controlled RED, and preferably catch `DepthExceeded` beside `KeyError` for a named result.

## Q4 — Verdict: **Generate one separate `CONTRACTS.md`; keep the design as rationale plus stable links.**

**Design recommendation/opinion.** The generated contract is a different reading product from the architecture
narrative:

- `_triage/EA_LAB_FACTORY_OS_DESIGN.md:1354-1360` explicitly requires compact context and drill-down on demand,
  while 27 full generated blocks made the default document 916 lines larger.
- `_triage/factory_os/gen_design_contracts.py:47-51`, `:393-451` now needs an in-document marker parser,
  duplicate detection, missing-block coverage, and unmatched-marker handling merely to host generated output
  inside prose. **Failing case motivating separation:** a stray or duplicated marker changes which prose is
  treated as generated even though the schema is unchanged.
- A standalone deterministic file can be replaced in full from `schemas.json`; no marker discovery or
  partial replacement is needed. The binding becomes byte/content equality of the whole generated artifact plus
  an exact `$defs`/meta coverage check.

What is lost:

1. exact field tables are no longer physically adjacent to the rationale that discusses them;
2. a reader opening only the design can miss a changed contract;
3. existing section anchors/backlinks may move.

Mitigation: leave a short per-section contract index in the design with stable links into
`_triage/factory_os/CONTRACTS.md`; give the generated file a prominent normative/source header; make pre-commit
bind schema, generated file, generator and design links through the D32 dependency manifest. Do not split into
24 per-entity files—the one generated drill-down artifact is the context-efficient unit.

## Q5 — Verdict: **Amend the Orders first, fix D32 next, then build S3a; do not start ORDER-601 as written.**

Ranked next work:

1. **Amend ORDER-600 and ORDER-601 before putting them on the taskboard.** The present acceptance can certify
   wrong-reason fixtures and a non-migration.
2. **Build D32's dependency-declared trigger and its own negative cage.** D32 is still explicitly open
   (`MASTER_BACKLOG.md:405`), and ORDER-601 is about to add another validator/cage surface. Adding it before D32
   repeats the known “suite exists but guarded inputs do not trigger it” failure.
3. **Execute amended ORDER-601/S3a.** It is the next semantic dependency for S3 and S4: closed builder input,
   output recomputation, whole-root preservation, reason-coded minimal-pair fixtures, nonnegative counts, and
   the omitted actionable case.
4. **Execute amended ORDER-600/S2a** as a proposal only. It can proceed in parallel after amendment, but no
   canonical transfer may occur until the owner signs.
5. Only after S2/S3 approval and evidence, perform **S4** compatibility integration: the real writer and all
   readers accept only a verified v5 snapshot and preserve the existing v4 fields.

Do **not** build the canonical `factory/coverage.jsonl`, change `MASTER_BACKLOG.md` ownership, write the live
snapshot, or start downstream S5+ work from the current draft. D30 permits preparatory S2a/S3a only
(`MASTER_BACKLOG.md:403`), while D31 and D32 explicitly retain open limits (`MASTER_BACKLOG.md:404-405`).

What makes ORDER-601 unsafe **as written** is not the two-entity direction; it is that:

- its negative fixtures can pass for unrelated rejection;
- its persisted-output lie survives unless recomputed;
- it omits `actionable > 0`, nonnegative counts, source identity/uniqueness, and real v4-field preservation; and
- the trigger system is still incomplete.

These are bounded amendments, not a reason to abandon S3a.

## Final disposition

# **GO WITH AMENDMENTS**

Required before execution:

1. ORDER-600: machine-readable migration-table schema; exact generated-row set; recomputed OwnerRefs; explicit
   Coverage proposal/refusal edge; separate source-row count from normalized cell reconciliation; human-review
   label and checklist for prose.
2. ORDER-601: one-field minimal-pair fixtures with exact reason/error paths; observed mutation table;
   output recomputation; whole-root preservation; two healthy controls; distinct missing/unreadable states;
   stale-threshold boundary; nonnegative counts; actionable, source-identity and uniqueness cases.
3. D32: declared suite dependencies plus a cage proving every guarded dependency—including the hook—triggers
   the intended suite.
4. Add permanent CRLF/LF/mixed-EOL and depth-overflow regression cases.
