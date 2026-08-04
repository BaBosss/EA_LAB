# Codex blind audit 7 — S2a migration table and ORDER-601 re-check

Audit executed 2026-08-04. I treated commit prose as claims, not evidence. To keep later work from changing the question, I audited ORDER-600 at `59a27f97` and ORDER-601's stated closure at `54e82c81`. Current-HEAD runs are reported separately and are not substituted for those fixed revisions.

## 1. Verdicts

### ORDER-600: **NOT DONE**

The authored D1 passes all nine machine criteria, and its 14 pins are real. That is not enough. I wrote a second 27-row D1 whose content is plainly false and useless, then ran the `59a27f97` checker against the exact `59a27f97` schema, coverage companion, and `MASTER_BACKLOG.md`. It exited 0 with **all nine criteria green**.

The two rev-5 exemptions weakened the checker enough to recreate rev 1's failure in a different spelling:

- 26 of 27 rows can claim `UNOWNED` merely because `schemas.json` contains their entity names.
- The one remaining row is the mechanically required Coverage edge.
- Every entity can be proposed into `factory/coverage.jsonl`.
- Every judgement field can be `"x"`.

There is also an independent C4 failure: a row can hash a real blob belonging to the wrong owner file. All nine criteria still pass.

### ORDER-601 re-check: **NOT REVIEWED-able**

The important audit-6 repairs are real: `reconciliation_clear` is honestly narrow, internal consistency is not described as authenticity, lack of reader wiring is disclosed, and the real snapshot still does not meet V5. But the closure is not reviewable yet:

1. the public validator path crashes with an uncaught `AttributeError` on valid JSON whose root is an array, rather than refusing it;
2. the required BACKLOG-D32 automatic schema-fixture coverage was not delivered; the triggered computation suite explicitly runs with `NO_SCHEMA_CHECK`;
3. the new enforcement inventory immediately labels global MagicAllocation uniqueness `WIRED` through a checker that enforces only `account|magic` uniqueness.

## 2. ORDER-600 criterion-by-criterion

| Criterion | Authored D1 | Does the checker establish the criterion's intent? | Audit result |
|---|---:|---|---|
| C1 exact entity set | PASS, 27/27 | Yes, narrowly. | PASS |
| C2 no `APPROVED` | PASS | It enforces the build-phase prohibition, but creates an approval deadlock because no separate approval artifact exists. | FAIL as workflow design |
| C3 owner vocabulary/existence | PASS | No. `UNOWNED` proves only name occurrence; `EMBEDDED` proves future-schema composition, not current storage; planned file paths use prefix matching. | **FAIL** |
| C4 recomputed `owner_ref` | PASS, 14/14 | No. It proves the cited blob is real but never binds `owner_ref.path` to `current_owner`. | **FAIL** |
| C5 distinct refs | PASS | Yes for duplicate blob OIDs, subject to C4 binding the right file first. | PASS, dependent |
| C6 one signer per owner | PASS | It catches manual mutations, but generated D1 assigns signers from a dictionary keyed by owner, and `gen --check` already rejects hand edits. It adds almost no independent assurance in the gate. | PASS, low value |
| C7 Coverage edge / not all KEEP | PASS | The minimum is exactly one non-`KEEP` row. I tested 26 `KEEP` + one Coverage `TRANSFER`; all nine criteria passed. | PASS, weak |
| C8 coverage reconciliation | PASS | Yes for the stated source rows/LIVE subset/mapping. | PASS |
| C9 non-empty reversal fields | PASS | Only presence and the exact strings `revert`/`revert the commit` are checked. `"x"` passes. Human quality remains unproved. | PASS mechanically; human FAIL |

The human-review acceptance fails independently of the machine weaknesses. Several TRANSFER rows do not cite evidence that supports the proposed ownership move, and four rows cannot satisfy the reader/writer checklist because they describe creation, not migration.

## 3. Findings, severity ordered

### CRITICAL — a written passing-but-useless D1 is accepted

**Reproduced.** `check_s2a_migration.py:257-280` accepts `UNOWNED` when a tracked file contains the entity name. It does not prove absence of an owner, absence of a current artifact, or absence from the `$ref` parent graph. `_triage/factory_os/schemas.json` contains every entity name, so it is accepted as `unowned_evidence` for every entity.

I wrote the input in section 4 to the one permitted path and ran the fixed-revision checker. Result:

```text
27 row(s) loaded, 0 structural problem(s)
[OK] C1 ... [OK] C9
=== ALL NINE MACHINE CRITERIA HOLD ===
exit 0
```

The Coverage row is the only row that cannot become `UNOWNED`, because C7 separately demands `current_owner` starting with `MASTER_BACKLOG.md`. Therefore the measured maximum is **26 false UNOWNED rows**, not four.

**Consequence:** green no longer means the table identifies present ownership. It means only that one real edge remains and every other entity name appears somewhere in a tracked text file.

**Minimal fix:** keep ownership gaps in scope, but derive eligibility. An `UNOWNED` row must be absent from an authoritative current-owner inventory, have no current artifact, and have no qualifying current parent. A mention is a citation, not proof of non-ownership. Add a negative fixture using `schemas.json` for a known-owned entity.

### CRITICAL — C4 accepts a valid hash for the wrong owner file

**Reproduced.** `check_s2a_migration.py:300-341` resolves `owner_ref.path` at `commit_oid` and hashes that blob, but never checks `owner_ref.path == current_owner`.

I changed only Hypothesis's pin:

```text
Hypothesis current_owner = AGENT_TASKBOARD.md
Hypothesis owner_ref.path = MASTER_BACKLOG.md
same_blob_reason = "x"
C1 OK ... C9 OK; problems=[]
```

This is the third owner-ref route that survived the two earlier repairs: the hashes are genuine, but they authenticate an unrelated file.

**Consequence:** the strongest criterion can certify the wrong evidence.

**Minimal fix:** for path-owned rows, require exact normalized equality between `current_owner` and `owner_ref.path`. Keep null refs only for explicitly derived owner kinds. Add a swap-two-real-pins mutation.

### HIGH — `EMBEDDED` proves schema composition, not present ownership

**Reproduced from the implementation and target data.** `ref_parents()` (`check_s2a_migration.py:161-183`) walks `$ref`s in the future design schema. C3 then treats any parent edge as evidence that the child fact lives in that parent today. For example, `MetricRef -> CoverageCell` is a valid schema edge even though `factory/coverage.jsonl` does not exist at this revision and today's coverage is a Markdown table. A `$ref` can also represent reuse rather than storage ownership.

**Consequence:** a row can receive both the current-owner and pinning exemptions from a relationship that describes the proposed schema rather than current storage.

**Minimal fix:** separate `schema_parent` from `current_owner`. An embedded current owner must identify and pin the current parent artifact, or the row must be classified as an ownership gap.

### HIGH — four judgement rationales cite the wrong mechanism

**Reproduced by opening the cited evidence.** These are not prose-style objections; the citations do not support the causal claims.

1. `s2a_migration.jsonl:20`, LogicalSymbol, calls `symbol synchronization timeout` a symbol-identity failure. `AGENT_TASKBOARD.md:3077-3088` says explicitly that diagnosis was wrong: the portable terminal had no credentials, and symbol timeout was an effect of no login. A symbol alias registry cannot prevent that incident.
2. `s2a_migration.jsonl:19`, TestUniverse, cites 52/62-trade BWD passes as skipped mandatory cells. `CLAUDE.md:84` says those cells did trade, but too sparsely to interpret, and proposes a trades-per-window participation floor. A universe registry does not enforce participation.
3. `s2a_migration.jsonl:15`, RunTransition, cites a stopped wrapper whose child kept running. A recovery checkpoint neither terminates nor detects an orphan child. The row also says a half-run leaves no trace, while `event-v1.schema.json:31,104,111` defines `RUN_STARTED` and `events-2026-07.jsonl:4` contains a real one.
4. `s2a_migration.jsonl:11`, Hypothesis, uses missing return correlations to justify architecture/module metadata. Architecture identity does not produce return correlations, and the cited count was stale: `_triage/ORDER154_RISK_ADMISSION_CURRENT_STATE.md:11` says 1,025 defaulted pairs, not 1,088.

**Consequence:** the owner is being asked to approve transfers on failures the proposed entity would not prevent.

**Minimal fix:** replace each rationale with a concrete failure the proposed owner can actually prevent. If no such failure exists, change the disposition or scope instead of stretching the citation.

### HIGH — the human checklist is unsatisfiable for creation rows

**Reproduced.** The rev-5 acceptance requires every TRANSFER `breaks_if_moved` to name a specific reader or writer. `TestUniverse`, `LogicalSymbol`, and `SafeProjection` are `UNOWNED -> new path`; their own text says there is no artifact or reader to break. `InstrumentProfile` likewise says no script parses the current document. These are creations or extensions, not migrations.

**Consequence:** either the honest rows fail human acceptance or they invent a reader. Calling them TRANSFER made the amended order satisfiable mechanically while leaving the human contract contradictory.

**Minimal fix:** add `CREATE` (or `ESTABLISH_OWNER`) with a creation-specific checklist, or narrow the table to facts that actually migrate and track ownership gaps separately. I prefer keeping all 27 visible and adding an explicit owner kind/disposition; silently dropping the four gaps would hide useful design debt.

### HIGH — approval is deadlocked

**Reproduced from C2 and the gate.** `SIGNOFF_STATES` contains only `PROPOSED` and `REFUSED` (`check_s2a_migration.py:62-64`), C2 rejects `APPROVED` (`:203-219`), and the gate always runs C2. The prose says approval is the owner's act in the owner's commit, but there is no artifact/checker shape that accepts that act. Approval therefore requires changing the checker in the same commit that records the decision.

**Consequence:** policy and decision must change together; the approval commit partially authorizes itself.

**Minimal fix:** keep D1 immutable and add a separate append-only signoff record such as `{proposal_digest, owner, decision, reason, decided_at_commit}`. The proposal checker continues to forbid embedded approval; a signoff checker validates the exact D1/D2 digest and required owners. No code edit is needed for an owner's decision.

### HIGH — ORDER-601's public boundary crashes on a non-object JSON root

**Reproduced at `54e82c81`.** `ajv_schema_validator()` calls `instance.get` before checking the type (`snapshot_validator.py:655-658`). `build_snapshot()` and `verify_snapshot()` invoke that gate before their own object guards (`:475-486`, `:505-516`). Results:

```text
ajv_schema_validator([]) raised AttributeError: 'list' object has no attribute 'get'
build_snapshot([], ajv_schema_validator) raised AttributeError
verify_snapshot([], ajv_schema_validator) raised AttributeError
```

`load_verified()` parses arbitrary valid JSON and the CLI catches `SnapshotRefusal`, not `AttributeError`, so a file containing `[]` produces a traceback rather than a refusal.

**Consequence:** the validator's public trust boundary has a valid-JSON crash shape outside its fixture matrix.

**Minimal fix:** type-check before `.get`, refuse with `SnapshotRefusal`, and add list-root minimal pairs for builder, verifier, `load_verified()`, and CLI.

### HIGH — ORDER-601 did not deliver the required automatic schema-fixture trigger

**Reproduced.** The order explicitly requires BACKLOG-D32 before or with ORDER-601. At `54e82c81`, `scripts/_test/run_contract_binding_tests.ps1:33-39` says `run_schema_fixtures.py` is deliberately absent. Its `$scripts` list (`:108-127`) runs `run_snapshot_validator_tests.py`, whose computation cases use `NO_SCHEMA_CHECK`; schema edits can trigger the tier without exercising AJV's closed-object and nonnegative rules.

**Consequence:** a schema semantic regression can pass the automatically triggered ORDER-601 cage.

**Minimal fix:** select `run_schema_fixtures.py` for the schema/validator paths, or make one batched schema-validation suite part of the triggered path. Budget pressure explains the gap; it does not satisfy the stated condition.

### HIGH — the enforcement-status repair immediately contains a false `WIRED`

**Reproduced.** `schemas.json:1441-1442,1546-1547` labels MagicAllocation global uniqueness `WIRED` through `scripts/check_state.ps1`. At that revision `check_state.ps1:60-62` groups only `account|magic`; it does not enforce global uniqueness, and the allocator named in `x-enforced-by` does not exist.

`check_schema_structure.py:250-255` checks only that the enforcer path exists and that its basename appears in an executed tier. It does not establish that the file enforces the stated constraint or has its claimed negative fixtures. `BUILT` has the same weakness: existence alone is accepted.

**Consequence:** the new vocabulary is better than the old field, but a green structural check can still promote an unimplemented constraint to WIRED.

**Minimal fix:** mark global uniqueness PLANNED at this revision, split the account-scoped backstop into its own constraint, and make each status cite a tracked test suite plus an exact executed entry. Status belongs to a specific constraint, not to an entity containing several constraints.

### MEDIUM — planned file paths are checked by prefix

**Reproduced.** C3 uses `any(prop.startswith(p) for p in PLANNED_PATHS)` at `check_s2a_migration.py:295`. `factory/coverage.jsonl.bak` produced `problems=[]`.

**Minimal fix:** exact equality for file entries; prefix matching only for vocabulary entries explicitly ending in `/`, followed by normalized containment checks.

### MEDIUM — mutable state is memoized as though every key were content-addressed

**Confirmed from source; concurrency race not forced because the audit may not move HEAD/index.** Blob OIDs and `commit:path` are immutable and safe. But `_REVPARSE_MEMO` also caches `HEAD:path` for vintage checks, `_TRACKED_MEMO` caches `git ls-files` (the mutable index), and `_ENTITIES_MEMO`/`_PARENTS_MEMO` cache the working-tree schema (`check_s2a_migration.py:102-183`). This is a shared worktree where another lane can commit while the one-process gate runs.

There is also a direct semantic mismatch: C3 says "exists at HEAD" but `tracked_paths()` calls `git ls-files`, which answers the index, not HEAD.

**Consequence:** later steps can answer an earlier HEAD/index/schema state, and staged additions may count as current owners before they exist at HEAD.

**Minimal fix:** resolve one immutable commit OID at gate start, read the owner vocabulary/schema from that snapshot, and key caches to that OID. If staged state is intended, say so and hash the index snapshot instead of calling it HEAD.

### MEDIUM — vintage should be advisory during editing and mandatory at signoff

The advisory severity is sound for ordinary commits: a historical proposal remains internally valid, and forcing re-pin on every unrelated board edit would create noise. It is not sound at approval time, because the judgement prose carries line-level citations and an owner could sign superseded evidence while every gate stays green.

**Minimal fix:** retain the advisory in the normal checker, but make zero stale/deleted pins a hard condition in the separate signoff checker proposed above.

### MEDIUM — the recorded timing evidence is internally inconsistent

I could not reproduce the 2026-07-30 full fast-tier samples without running historical suites that overwrite and restore repository files, which this audit's write boundary forbids. The durable prose is itself inconsistent at `59a27f97`:

- `run_contract_binding_tests.ps1:62` says standalone **17.3s**;
- `:69` calls **16.5s** the cold standalone cost;
- `:67-70` says in-hook **15.1-15.2s**, while the brief/board claim **15.7s**.

Current HEAD, measured 2026-08-04, is not comparable but was recorded: `run_s2a_gate.py` 5.873s; checker 1.216s; self-test 0.137s; mutation suite 3.507s, all exit 0.

**Minimal fix:** store timing samples as a small artifact containing command, commit, warm/cold context, individual samples, and median. Do not make prose the only evidence.

## 4. Passing-but-useless D1

This is the exact file written and accepted by all nine criteria at the fixed ORDER-600 revision. The real coverage reconciliation companion was left unchanged.

```jsonl
{"entity":"CandidatePayload","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"ExecutionKey","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"MetricRef","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"ModuleUse","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"RunAttempt","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"ReconciliationEvidence","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"SnapshotMeta","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"SnapshotVerdict","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"OwnerRef","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"CoverageCell","current_owner":"MASTER_BACKLOG.md","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":{"blob_oid":"ca909b693a4c747dc1347d48fa8b2507f6a4243f","commit_oid":"cfdcc264217b4b10b589e27e5e9f4513de43071c","path":"MASTER_BACKLOG.md","raw_sha256":"37b87b6e1a3524c7d2048035adff4cc37257e5f91a280215c5b482e6140893ca"},"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x"}
{"entity":"Hypothesis","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"CandidateManifest","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"MagicAllocation","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"ParameterBinding","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"RunTransition","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"InstrumentProfile","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"SystemFinding","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"WorkReceipt","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"TestUniverse","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"LogicalSymbol","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"SafeProjection","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"RunJournal","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"ControlRoomSnapshotV5","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"SnapshotBuilderInput","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"EvidenceRef","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"DeploymentAttestationEvent","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
{"entity":"IdeaRef","current_owner":"UNOWNED","proposed_owner":"factory/coverage.jsonl","disposition":"TRANSFER","canonical_or_derived":"canonical","owner_ref":null,"breaks_if_moved":"x","breaks_if_not_moved":"x","signoff_owner":"same","signoff_state":"PROPOSED","reverse_steps":"x","evidence_lost":"x","retention_window":"x","unowned_evidence":"_triage/factory_os/schemas.json","owner_ref_absent_reason":"x"}
```

A second in-memory variant changed those 26 rows to `KEEP`, `derived`, `proposed_owner=UNOWNED`, with `keep_reason="x"`. It also passed all nine. Therefore C7's measured minimum is **one** non-KEEP row.

## 5. Measurements and checks found sound

- Exact `$defs` count at `59a27f97`: **27**.
- Direct `$ref` traversal: **9** entities have at least one parent.
- D1 has **14** non-null owner refs and **4** `UNOWNED` rows. Caveat: calling these "14 real artifacts holding the fact" is judgement, not a pure measurement. `SnapshotBuilderInput` says `x-owner-file = NONE - transient` but D1 calls `snapshot_validator.py` its current owner; RunTransition similarly calls its writer script the owner.
- Independent pin check: **14 OK, 0 bad**. Each `commit:path` resolves, blob OID matches, and SHA-256 over `git cat-file blob` matches.
- Coverage: **7 source rows**, **8 LIVE entries**, **32 non-LIVE tokens**, **40 mapping entries total**. The hand-maintained `OTHER` dictionary completely enumerates the final-column symbol/status tokens. The 32 unresolved entries are honestly marked `UNVERIFIED_IMPORT` with source coordinates; they are not normalized symbol-by-TF cells.
- Repository search found no machine consumer of the semantics of `MASTER_BACKLOG.md` section 2 at the target revision. `check_state.ps1:124-126` checks only the owner banner; `check_block_staleness.ps1:53-58` only lists the file as self-referential. `check_handoff_contract.ps1` scans Markdown rows for backlog IDs, not coverage cells.
- The authored D1 produces all nine green criteria at the fixed revision.
- Current HEAD control runs were all green: S2a aggregate exit 0, checker exit 0, self-test exit 0, mutation suite exit 0. This does not invalidate the fixed-revision negative inputs.
- `run_s2a_gate.py` is a reasonable aggregator: it retains per-step labels/output, runs later steps after nonzero returns, and summarizes the failed labels. A single aggregate exit code does not itself lose actionable information. The concern is shared mutable caches, not aggregation.
- ORDER-601's rename is honest at `54e82c81`. Design `:1115`, schema `SnapshotVerdict`, contracts, and module documentation explicitly exclude fleet health, floating risk, deployment gaps, unknown magics, attestation, and judge readiness.
- Authenticity remains deliberately unproved and is disclosed. No production reader calls `load_verified()`; the only executable call is the validator CLI.
- The real snapshot at `54e82c81` has `meta.version = 3` and lacks the V5-required top-level `entity` and `verdict`; it still fails the V5 shape as stated.

## 6. Outside the brief's suggested angles

The strongest material outside the prompted exemption questions was not another hash trick. It was the causal layer:

- several owner-facing rationales cite incidents their proposed entity would not have prevented;
- the snapshot validator has a non-object-root crash despite extensive minimal-pair discipline;
- the enforcement-status repair can certify a file's presence as enforcement of the wrong constraint.

Those three defects share one mechanism: **evidence is adjacent to the claim but not bound to the exact claim**. C4 has the same problem mechanically. The next repair should make that binding explicit instead of adding more prose around the existing fields.
