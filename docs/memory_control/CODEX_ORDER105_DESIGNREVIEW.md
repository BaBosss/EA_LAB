# ORDER-105 Contract D pre-build design review (rework0)

## Review outcome

ORDER-105 has the correct bounded objective: add a structured experiment timeline without moving verdict, decision, deployment, order-result, or reviewed-history ownership. The smallest robust MVP is a Git-tracked monthly JSONL log, a Git-tracked evidence-only manifest, one PowerShell 5.1 write utility, and a staged-snapshot validator analogous to Contract C. An external durable store, a database, and narrative fields are unnecessary for MVP-1-lite.

The order is not buildable as written. It leaves core on-disk, identity, locking, recovery, and ownership rules to the builder, and several acceptance tests can pass without proving the claimed property.

## Summary of findings

| ID | Severity | Finding | One-line fix |
|---|---|---|---|
| F01 | BLOCKER | The event vocabulary has two conflicting result/review/decision families and treats pre-§20 text as binding even though §20 says it is non-authoritative. | Pin one v1 event enum in the order: use the §20.7 `*_LINKED` family, reject the three narrative-looking legacy names, and add the §20.8 tombstone type explicitly. |
| F02 | BLOCKER | The order omits the §20.2 requirement that monthly JSONL is in Git and does not add analogous staged enforcement; the current hook ignores any new event file. | Pin tracked paths/names/LF encoding and require a dynamic staged-snapshot event-log guard in the production hook. |
| F03 | BLOCKER | “Occurrence metadata + hashes + references only” is prose, not an enforceable schema rule; free-form `reason` and underspecified event payloads can become a second result/verdict owner. | Use per-event field whitelists, `additionalProperties=false`, bounded reason codes, immutable owner references, and explicit forbidden narrative/disposition fields. |
| F04 | BLOCKER | Corrupt-line acceptance deadlocks: normal appends are refused until an amendment/tombstone is appended, but that correction is itself an append; tombstone is not in the declared schema. | Separate logical correction from physical recovery, define `TOMBSTONE_ADDED`, and provide a locked rebuild/recovery path that restores a clean prefix before recording recovery. |
| F05 | BLOCKER | The durable-evidence manifest has no path, format, writer, transaction order, ID semantics, or durable-store definition, and “file exists” does not prove recoverability. | Restrict v1 to committed Git artifacts and define an append-only manifest whose entries resolve and hash-match at an exact commit/blob. |
| F06 | MAJOR | Windows PowerShell 5.1 lock, retry, atomicity, durability, and crash behavior are not pinned. | Use one repo-scoped exclusive `FileStream` lock, bounded retry, prebuilt bytes, durable flush, and same-volume atomic replace under the same lock. |
| F07 | MAJOR | Event/experiment uniqueness, prior-link meaning, lifecycle/fork rules, and idempotency conflict behavior are unspecified. | Pin global UUID identities, per-experiment linear chains linked by prior ID plus prior-line SHA-256, a transition table, and exact same-ID retry/conflict rules. |
| F08 | MAJOR | Hash inputs, text encoding, timestamp authority, actor/role vocabulary, nullability, canonical serialization, and schema versioning are unspecified. | Pin strict v1 primitive formats and a versioned JSON Schema consumed as the utility’s validation source. |
| F09 | MAJOR | Acceptance 1 can serialize all writers before the first lock attempt and still pass; clean JSON does not prove the lock was used. | Use separate processes behind a start barrier plus a deliberately held lock and assert observed wait/retry telemetry and overlapping attempts. |
| F10 | MAJOR | Acceptance 2–4 do not isolate byte-identity assertions and omit important malformed, conflicting, and referential-invalid inputs. | Hash every affected file before/after in an isolated fixture and expand fail-closed cases, including same-ID/different-payload and invalid UTF-8/unknown fields. |
| F11 | MAJOR | Acceptance 5’s “trace back to canonical owner” is not version-pinned and can pass with mutable paths, fabricated fixture owners, or incomplete event coverage. | Require path + full commit OID + blob OID + raw SHA-256 + stable anchor, and verify each link by reading the referenced Git object. |
| F12 | MAJOR | Monthly rotation has no UTC boundary, closed-month, cross-file chain, late-write, clock-skew, or Git-history semantics. | Rotate on utility-assigned UTC time inside the lock, make prior months immutable, reject clock rollback/backdating, and validate chains/IDs across all months. |
| F13 | MAJOR | Rollback is not executable and cannot promise an exact rebuild of occurrence metadata; in-flight behavior and disable authority are undefined. | Define an exclusive-lock disable operation, queued/in-flight behavior, recovery source/RPO, deterministic rebuild validation, and re-enable authority. |
| F14 | MINOR | Acceptance 7 checks TEMP cleanup but not shared-repo non-mutation, child timeout behavior, or concurrent-suite collisions. | Use GUID scratch roots, bounded child self-timeouts, `finally` cleanup, and before/after HEAD/index/worktree assertions. |

BLOCKER + MAJOR count: **13**.

## Detailed findings

### F01 — BLOCKER: event types have conflicting authority and semantics

**Referenced text.** ORDER-105 says the schema contains `RESULT_ATTACHED · REVIEW_RECORDED · DECISION_SIGNED` **and** `RESULT_LINKED / REVIEW_LINKED / DECISION_LINKED` (`AGENT_TASKBOARD.md:1350`). The older event list at `4eb839d:_triage/EA_LAB_EVOLUTION_PLAN_DRAFT.md:274-300` contains only the first family. The authoritative §20 ownership table says structured experiment timelines **use** `RESULT_LINKED`, `REVIEW_LINKED`, and `DECISION_LINKED` and must not copy result/verdict text (`4eb839d:...:883-884`). Section 20.1 says §1–19 is design/review history without implementation authority (`4eb839d:...:775-781`), and §20.9 says implementation orders should reference only §20 (`4eb839d:...:929-930`).

**Why it matters.** A builder must either invent a distinction between “attached/recorded/signed” and “linked,” accept two aliases for the same occurrence, or put result/review/decision content into the first family. Each choice yields a different schema and ownership model. Accepting aliases also permits duplicate lifecycle events that disagree while both validate.

**Required change.** ORDER-105 should approve a v1 enum as an implementation decision under §20.5 rather than claiming the pre-§20 list is independently binding:

`IDEA_CREATED`, `HYPOTHESIS_REGISTERED`, `BAR_PREREGISTERED`, `RUN_STARTED`, `RESULT_LINKED`, `AMENDMENT_ADDED`, `REVIEW_LINKED`, `DECISION_LINKED`, `TOMBSTONE_ADDED`.

`RESULT_ATTACHED`, `REVIEW_RECORDED`, and `DECISION_SIGNED` should be rejected in schema v1. `RESULT_LINKED` may reference one or more durable evidence IDs and the canonical taskboard result; it still carries no result text. `REVIEW_LINKED` and `DECISION_LINKED` point only to their exact canonical owners. `TOMBSTONE_ADDED` is needed because §20.8 rollback explicitly mentions tombstones (`4eb839d:...:921`).

### F02 — BLOCKER: Git location and tamper enforcement are missing

**Referenced text.** The authoritative sequence specifies “JSONL รายเดือนใน git” (`4eb839d:...:794`). ORDER-105 says only “monthly rotation” and does not give a tracked location/name (`AGENT_TASKBOARD.md:1349-1351`). The current staged checker enumerates exactly five protected files (`scripts/check_precommit_staged.ps1:8-14`) and exits immediately when none is staged (`scripts/check_precommit_staged.ps1:82`). The production hook invokes `check_state.ps1 -Strict` and that checker scans deployment/doc invariants, not event JSONL; its only generic Markdown scan is root-only (`scripts/check_state.ps1:87-88`).

**Why it matters.** A runtime-only or untracked implementation would silently drop a locked §20 requirement and would not gain Git’s audit trail. A tracked implementation without a new guard can still have old lines edited, files deleted/renamed, IDs duplicated across months, or manifest links broken while the existing pre-commit hook passes. The statement that all writes go through the utility is not technically enforceable by the current hook; at most, the hook can enforce that the staged result satisfies the utility’s invariants.

**Required change.** Pin `docs/memory_control/experiment_events/events-YYYY-MM.jsonl` as tracked, with a scoped `.gitattributes` rule enforcing UTF-8-compatible LF text. Add a separate event staged-snapshot checker called by `.githooks/pre-commit` whenever a monthly log, the evidence manifest, or either schema is staged. It must block delete/rename, non-prefix modification of an established log, edits to closed months, stale schema/manifest references, invalid lines, and cross-month ID/chain failures. It should read the index candidate, not mix HEAD and working-tree state. The existing archive `-Generate` artifacts must remain separate; the evidence manifest must not be regenerated or overwritten by `check_taskboard_archive.ps1 -Generate`.

### F03 — BLOCKER: the ownership boundary is not schema-enforced

**Referenced text.** ORDER-105 correctly says the log stores only occurrence metadata, hashes, and references and must not copy result/verdict text (`AGENT_TASKBOARD.md:1353`). It also requires a generic `reason` field for every event (`AGENT_TASKBOARD.md:1350`). §20.7 assigns raw result narrative to `AGENT_TASKBOARD.md` and verdict/decision/deployment to the existing owners (`4eb839d:...:881-885`).

**Why it matters.** A schema with `reason: string` can validly store “REJECT because PF …”, a review disposition, deployment status, or the whole result narrative. Generic object fields or `additionalProperties=true` allow the same duplication under another name. Path/hash alone is also not a stable canonical reference if it points to mutable working-tree content.

**Required change.** Each event type needs its own whitelist with `additionalProperties=false`. Replace free-form reason text with a small per-event `reason_code` enum and a `reason_ref`; do not permit prose. All canonical links should use an object containing repo-relative path, full commit OID, Git blob OID, raw-byte SHA-256, and stable anchor/key. Prohibit fields such as `result`, `verdict`, `decision`, `disposition`, `status`, performance metrics, excerpts, notes, summaries, and arbitrary metadata maps. Add maximum lengths and path normalization rules. The only decision information in `DECISION_LINKED` should be that a decision occurrence exists and where its canonical bytes are recoverable—not what the decision was.

### F04 — BLOCKER: corrupt-line handling is internally deadlocked

**Referenced text.** Acceptance 4 says a corrupt line causes append refusal “จนกว่า correction ผ่าน amendment/tombstone event” (`AGENT_TASKBOARD.md:1359`). Rollback says correction uses amendment/tombstone only and old lines cannot be edited/deleted (`AGENT_TASKBOARD.md:1372`). The declared event list contains `AMENDMENT_ADDED` but no tombstone (`AGENT_TASKBOARD.md:1350`).

**Why it matters.** If the only writer refuses to append while any line is corrupt, it cannot append the event required to unblock itself. Appending after invalid bytes would not make the monthly file valid JSONL anyway. An amendment can correct the meaning of a valid event, but it cannot turn garbage or a truncated physical line into JSON.

**Required change.** Define two separate paths:

- Logical correction: append `AMENDMENT_ADDED` or `TOMBSTONE_ADDED` to a structurally valid log. It targets an existing valid event by ID and line hash; the target remains present and readers derive its superseded/tombstoned state.
- Physical recovery: normal append remains fail-closed. A privileged recovery command takes the same exclusive lock, quarantines the corrupt bytes as evidence, reconstructs the last verified valid prefix from Git plus any validated tail, atomically installs that clean file, then appends a recovery amendment/tombstone to the clean log. Physical repair is a rebuild exception, not a semantic amendment to garbage.

The order must state who may invoke recovery and how the staged checker recognizes the one allowed rebuild transaction. Without that exception, a strict prefix-only Git guard would also reject the repaired file.

### F05 — BLOCKER: the evidence manifest does not establish durability

**Referenced text.** ORDER-105 requires “evidence ID → tracked artifact / durable store + existence check” and rejects ignored/transient paths (`AGENT_TASKBOARD.md:1351,1361`). Section 20.5 permits `path + git SHA + file hash` only when a Git artifact is recoverable (`4eb839d:...:855`). Section 20.7 likewise requires tracked evidence or a defined durable store/backup (`4eb839d:...:885`).

**Why it matters.** `Test-Path` only proves a working-tree file exists at one instant. It does not prove it was committed, is recoverable at the referenced revision, matches the recorded hash, is inside the repo, or is not a symlink/path traversal into transient storage. “Durable store” has no configured backend, identity, credentials, or recovery test. The order also does not say whether the manifest is canonical, generated, append-only, or written by the event utility; concurrent event and manifest writes can therefore create dangling references.

**Required change.** Keep MVP-1-lite to the already sanctioned, simpler branch: committed Git artifacts only. Use a tracked append-only `evidence-manifest.jsonl`, written under the same lock before any event that references a new evidence ID. A crash after manifest append but before event append may leave an allowed orphan manifest entry; the reverse ordering is forbidden. Each entry must include a content-addressed evidence ID, repo-relative path, full commit OID, blob OID, raw SHA-256, byte length, and media/type token. Validation must read `<commit>:<path>` from Git, compare blob OID, SHA-256, and size, and reject untracked, merely staged, ignored-only, missing-object, outside-repo, or hash-mismatched evidence. An external store can be added only in a later schema version with a real backend contract.

### F06 — MAJOR: lock and atomic append are not implementable from the order without guessing

**Referenced text.** The only mechanical requirement is “file lock · atomic append” (`AGENT_TASKBOARD.md:1349`; `4eb839d:...:888-889`). Acceptance 1 checks non-interleaving but not crash durability (`AGENT_TASKBOARD.md:1356`).

**Why it matters.** `Add-Content`, `Out-File -Append`, and separate “check then append” calls do not make validation plus append atomic. A lock file’s mere existence is not a lock and can strand the log after a crash. An exclusive append stream prevents writer interleaving but can still leave a truncated final line if the process stops during the write. Locking each month separately also permits cross-month duplicate IDs and stale prior links.

**Required change.** Pin one repository-wide lock obtained with `[System.IO.File]::Open(..., OpenOrCreate, ReadWrite, FileShare.None)` at a path returned by `git rev-parse --git-path ea-lab-experiment-events.lock`. Hold the handle across disable check, all-month integrity scan, schema/reference validation, manifest registration, and event installation. Retry at 50 ms with bounded jitter for at most 30 seconds; lock timeout is a distinct non-zero status. A stale lock pathname without an open handle must not block.

For crash-safe installation, construct the complete candidate bytes in a same-volume temporary file, flush with `Flush(true)`, and atomically replace the target; use atomic move for first creation. Canonical bytes must be prebuilt before touching the target. Manifest is installed before the referencing event, so cross-file failure can create only a harmless orphan manifest entry. On startup, the utility should remove only its own known orphan temp files after validating their names and location.

### F07 — MAJOR: identity, chain, idempotency, and lifecycle semantics are open

**Referenced text.** ORDER-105 requests unique event ID, idempotency, experiment ID, and “prior event (chain link)” but supplies none of their formats or scopes (`AGENT_TASKBOARD.md:1349-1350,1357-1358`).

**Why it matters.** Per-file uniqueness allows duplicates after rotation. An ID-only prior link detects missing targets but not target mutation. Payload-hash idempotency can collapse two legitimate occurrences, while event-ID-only idempotency without collision handling can silently accept different content. Two concurrent writers for the same experiment can both point to the same prior event and create a fork even though every line parses.

**Required change.** Use global `evt_<lowercase UUIDv4>` and `exp_<lowercase UUIDv4>` identifiers across all monthly files. `IDEA_CREATED` is the only event allowed to have null prior fields and is the only event that creates an experiment ID. Every other event must point to the latest non-invalid event in the same experiment with both `prior_event_id` and `prior_event_sha256`. Define the hash as SHA-256 of the exact UTF-8 JSON payload bytes excluding the LF terminator. Reject stale-prior forks under the lock.

Idempotency keys on event ID: the same ID plus byte-identical canonical payload returns exit 0 with machine-readable status `already_appended` and changes no file; the same ID with any different payload is a non-zero `event_id_conflict`. A different event ID is a distinct occurrence even if its payload is otherwise equal. Pin a v1 transition table and cardinality; the smallest MVP is one core event of each type per experiment, optional amendments/tombstones, and one run whose `trial_count` may represent a batch. A second preregistered run should use a new experiment ID in v1 rather than inventing branching semantics.

### F08 — MAJOR: primitive formats and schema version are unpinned

**Referenced text.** The legacy field list names timestamp, actor/role, five classes of hashes, trial family/count, evidence IDs, and reason (`4eb839d:...:289-298`), but ORDER-105 does not define their JSON representation (`AGENT_TASKBOARD.md:1350`). Section 20.5 delegates field naming, schema version, IDs, and rotation to Claude/Codex under an order (`4eb839d:...:852-855`); delegation is not a reason to leave the build order ambiguous after this review.

**Why it matters.** Builders can reasonably choose SHA-1, Git blob SHA, SHA-256 over decoded text, local time, arbitrary role strings, omitted keys, empty strings, or nulls. These choices are not interoperable and change validation results. PowerShell property order and `ConvertTo-Json` behavior are also not a cross-version canonicalization contract unless explicitly constrained.

**Required change.** Pin the following v1 primitives:

- `schema_version`: integer `1`, required on every line. Unknown versions fail closed.
- Encoding: UTF-8 without BOM, exactly one compact JSON object per LF-terminated line, fixed property order emitted and enforced by the utility; no CR or embedded raw newline.
- Timestamp: utility-assigned UTC RFC 3339 with fixed milliseconds (`yyyy-MM-ddTHH:mm:ss.fffZ`) after lock acquisition. Equal timestamps are allowed; timestamps do not establish chain order.
- Actor IDs: `user`, `claude`, `codex`, `zcode`, `oc-mgr`, `oc-dev`, `oc-btest`, `system`.
- Roles: `owner`, `lead_judge`, `peer_engineer`, `batch_runner`, `manager`, `system`, with an explicit actor→role compatibility table. A new actor/role requires a schema version change.
- Artifact hashes: a required `artifact_hashes` object with keys `ea`, `source`, `set`, `data`, `tester`; each is null or lowercase 64-hex SHA-256 over raw bytes of a durable evidence artifact or deterministic bundle manifest. No decoded-text normalization and no ad hoc directory traversal hash.
- `trial_family`: bounded ASCII token; `trial_count`: integer ≥1 only from `RUN_STARTED` onward, otherwise null under per-type rules.
- Evidence IDs: unique array, bounded count, values matching the manifest ID format.

Store strict versioned schemas at `docs/memory_control/experiment_events/schema/event-v1.schema.json` and `evidence-v1.schema.json`. The utility must consume the schema definitions or share one declarative rule table with the schema generator; two independently maintained rule sets are not acceptable.

### F09 — MAJOR: the concurrent-write test does not prove contention or lock use

**Referenced text.** Acceptance 1 requests at least three writers with at least 50 events each and says contention must be real (`AGENT_TASKBOARD.md:1356`).

**Why it matters.** `Start-Job`/process startup can serialize writers enough that no two attempt the lock concurrently. A utility with no lock but one whole-line write can also produce 150 parseable lines in a favorable run. Counting lines does not prove the critical section covered validation, uniqueness checks, and installation.

**Required change.** Run at least three independent `powershell.exe` processes. Each announces ready, waits on a common gate, then begins. Before opening the gate, a fixture process holds the exact production lock for a known interval. Require every writer to start its attempt before release and require at least one machine-readable `lock_wait_count > 0` (preferably all three). Assert attempt intervals overlap, all processes self-terminate within a bounded time, 150 unique IDs are present, all lines validate, no stale-prior fork exists, and the staged checker accepts the final candidate. Add separate contention cases for the same experiment, evidence-manifest registration, and a simulated month boundary.

### F10 — MAJOR: rejection and corruption acceptance is incomplete and can race

**Referenced text.** Acceptance 2 checks repeated ID, acceptance 3 checks five schema errors and raw byte identity, and acceptance 4 checks one damaged line (`AGENT_TASKBOARD.md:1357-1359`).

**Why it matters.** A before/after byte comparison is invalid if another legitimate writer can append during the observation. Checking only the monthly JSONL can miss a temp file, manifest mutation, or lock-side effect. The five cases omit malformed JSON/UTF-8, unknown fields, hash/timestamp/role errors, unresolved owner/evidence references, and the critical same-ID/different-payload conflict. “Good events remain readable” also needs a specified diagnostic reader mode; the normal validator should still fail the file.

**Required change.** Run rejection tests in isolated temp repos with no other writer, record raw SHA-256 and length for every log and manifest before the call, and assert all are identical afterward. Also assert no temp file remains. Require distinct exit/status classes for schema invalid, reference invalid, ID conflict, integrity corrupt, and lock timeout. Corruption tests should cover first/middle/final lines, truncated UTF-8, garbage, missing LF, and valid JSON with invalid schema; diagnostic scan may report all good line IDs and exact bad line numbers, while normal append remains fail-closed until the physical recovery procedure completes.

### F11 — MAJOR: the canary can pass without a durable canonical trace

**Referenced text.** Acceptance 5 says one real experiment must trace every link to the canonical owner with matching path and hash (`AGENT_TASKBOARD.md:1360`). Ownership requires links rather than copied text (`4eb839d:...:881-885`).

**Why it matters.** A mutable path plus current-file hash does not identify the historical bytes. A test can fabricate an arbitrary `scorecard.md` fixture and call it canonical, or check only that a string anchor exists. It can also omit idea/hypothesis events and still satisfy the stated abbreviated “prereg→run→result→review→decision” chain. If an owner is dirty but uncommitted, there is no recoverable version to reference.

**Required change.** The canary must use the exact canonical owner classes from §20.7 in a temp Git repo that mirrors those paths and permissions, commit each owner before linking, and resolve every link with `git cat-file`/`git show` at the full commit OID. It must verify blob OID, raw SHA-256, and a unique stable anchor/key in those bytes. It should exercise all core v1 event types; amendment and tombstone can be separate negative/behavior tests. The linked event must contain no owner excerpt, verdict, review disposition, result number, or deployment value. Role rules must prevent Codex/ZCode actors from emitting `DECISION_LINKED` as the signer.

### F12 — MAJOR: monthly rotation and Git history are unspecified

**Referenced text.** ORDER-105 requires monthly rotation (`AGENT_TASKBOARD.md:1349`) and §20.2 requires monthly JSONL in Git (`4eb839d:...:794`), but neither the order nor acceptance covers the boundary.

**Why it matters.** An experiment can start in one month and finish in another. Per-file validators can reject its prior link or miss duplicates in the old file. Local-time rotation differs among agents. Clock rollback can reopen a closed month. `core.autocrlf=true` can produce mixed line endings unless JSONL paths are pinned to LF. A hook that protects only the current filename will not stop edits to old months.

**Required change.** The utility assigns UTC time inside the global lock and selects `events-YYYY-MM.jsonl` from that value. The latest existing month may accept prefix appends; every earlier month is immutable. A clock value earlier than the latest recorded month/time fails closed with a clock-skew status rather than reopening an old file. Same timestamps are valid and ordered only by chain links. Global ID/prior/reference validation scans every month. The first event in a new file may and commonly will point to an event in the previous file. Git staged validation must compare established files to HEAD, allow only a new valid month file or a prefix extension of the current month, and reject deletion, rename, reorder, CRLF drift, or backdated old-month append.

### F13 — MAJOR: rollback and in-flight semantics are not executable

**Referenced text.** The rollback is only “disable append utility · rebuild from canonical refs · correction uses amendment/tombstone” (`AGENT_TASKBOARD.md:1372`; `4eb839d:...:921`).

**Why it matters.** There is no disable control or authority, and a writer may already hold or be waiting for the lock. The structured occurrence time and actor may exist only in the event log, so canonical result/verdict references cannot reproduce the original bytes. A rebuild also conflicts with strict Git prefix enforcement unless a reviewed recovery transaction is defined. “Rebuild” therefore cannot currently be tested or executed.

**Required change.** Define a disable operation that acquires the production lock and creates a repo-local disabled sentinel under the Git private directory. A writer that already holds the lock may finish; queued writers must recheck the sentinel after acquisition and fail without mutation. Only Claude/user may disable, authorize recovery, or re-enable. Define the recovery source in order: last valid committed event-log blob, then a validated working-tree tail, then exact canonical owner refs. State the recovery objective honestly: preserve all verified event bytes; reconstruct missing link occurrences with new IDs/timestamps and explicit recovery references rather than pretending byte-identical restoration. Add a staged-checker recovery mode requiring a reviewed recovery authorization reference and quarantined-byte evidence. Define what happens to experiments with no terminal decision: canonical work continues, new logging remains blocked until re-enabled, and no verdict/deployment owner changes.

### F14 — MINOR: suite hygiene should also protect the shared repository

**Referenced text.** Acceptance 7 requires 100% pass, rerun, and zero TEMP leftovers (`AGENT_TASKBOARD.md:1362`). The ORDER-103 suite demonstrates guarded TEMP deletion and `try/finally` cleanup (`scripts/_test/run_order103_negative_tests.ps1`).

**Why it matters.** A suite can clean TEMP while changing the shared index, HEAD, Git config, or working tree. PID-only scratch names can collide with stale folders, and a deadlocked child can prevent `finally` from running.

**Required change.** Use a GUID scratch directory with a strict TEMP-prefix/name guard. Give every child a finite self-timeout. Capture HEAD, staged diff identity, `git status --porcelain=v1`, and relevant Git config before the suite and assert they are unchanged afterward, accounting for pre-existing dirty files. Run twice and require identical pass-case names/counts and zero matching scratch directories after each run.

## Acceptance-criterion soundness matrix

| Acceptance | Machine-checkable as written? | Sufficiency and missed failure |
|---|---|---|
| 1. Concurrent write | Partly. Counts and JSON parsing are measurable; “real contention” is not defined. | Can pass with serialized startup or whole-line writes without a lock. Misses same-experiment forks, manifest races, lock timeout/stale path, month boundary, and crash during install. Use the barrier/held-lock method in F09. |
| 2. Idempotency | Partly. Duplicate count is measurable after ID semantics are pinned. | Misses same ID with different payload, duplicate across months, concurrent retries, and whether any file changed. Assert exact byte identity and explicit `already_appended` versus conflict behavior. |
| 3. Schema fail-closed | Mostly, only in an isolated fixture. | The five cases are too narrow and byte identity races with legitimate writers. Snapshot all affected files and add malformed encoding/JSON, unknown fields, bad primitives, unresolved refs, and payload collision cases. |
| 4. Corrupt line | Detection and line number are measurable. Recovery is not. | As written it deadlocks and conflates diagnostic reading, semantic correction, and physical repair. It misses first/middle/last corruption and crash-torn UTF-8. Apply F04/F10. |
| 5. Canary trace | No, until “canonical owner,” exact reference, required event set, and trace algorithm are defined. | Mutable path/hash checks can pass without recoverability and can copy owner content into the log. Require exact Git-object resolution and no narrative fields as in F11. |
| 6. Evidence existence | No, “exists” and “durable” are different properties. | Misses uncommitted files, wrong commit/blob/hash, ignored-but-force-tracked files, outside-repo paths, renamed-but-Git-recoverable files, and undefined external stores. Use committed-object verification in F05. |
| 7. Suite PASS/rerun/cleanup | Yes for case results and TEMP enumeration. | Misses hangs, shared repo/index/config mutation, nondeterministic case discovery, and scratch-name collisions. Add F14 assertions. |

## Decisions the builder needs pinned

The following are recommended v1 values for lead approval or override. None should be left to implementation-time inference.

1. **MVP shape:** Git-only durability in v1: monthly event JSONL plus evidence-manifest JSONL. No SQLite, external store, generated write-back, or narrative payload.
2. **Event directory:** `docs/memory_control/experiment_events/`.
3. **Monthly files:** `events-YYYY-MM.jsonl`, month derived from utility-assigned UTC timestamp after lock acquisition.
4. **Tracking:** monthly files, manifest, and schemas are Git-tracked. Add a scoped LF `.gitattributes` rule. Lock/temp/disabled sentinel live under Git’s private path and are never tracked.
5. **Utility/checker/tests:** `scripts/experiment_event_log.ps1`, `scripts/check_experiment_events.ps1`, and `scripts/_test/run_order105_negative_tests.ps1`.
6. **Event schema location/version:** `docs/memory_control/experiment_events/schema/event-v1.schema.json`; `schema_version` integer `1`; unknown/mixed unsupported versions fail closed.
7. **Evidence schema/location:** `docs/memory_control/experiment_events/schema/evidence-v1.schema.json`; manifest at `docs/memory_control/experiment_events/evidence-manifest.jsonl`.
8. **Event types:** only `IDEA_CREATED`, `HYPOTHESIS_REGISTERED`, `BAR_PREREGISTERED`, `RUN_STARTED`, `RESULT_LINKED`, `AMENDMENT_ADDED`, `REVIEW_LINKED`, `DECISION_LINKED`, `TOMBSTONE_ADDED` in v1.
9. **Legacy event names:** reject `RESULT_ATTACHED`, `REVIEW_RECORDED`, and `DECISION_SIGNED`; their sanctioned v1 behavior is represented by the corresponding `*_LINKED` event.
10. **Experiment ID:** `exp_<lowercase UUIDv4>`, globally unique; duplicate `IDEA_CREATED` for the same ID is rejected.
11. **Event ID:** `evt_<lowercase UUIDv4>`, globally unique across all months. The caller supplies a stable ID for retries; a helper may generate it before the append call.
12. **Evidence ID:** `evd_sha256_<64 lowercase hex>`, derived from raw artifact bytes. One canonical Git locator is recorded per content ID in v1.
13. **Chain semantics:** per-experiment linear chain. First `IDEA_CREATED` has null prior ID/hash; every later event points to the current tail with both ID and SHA-256 of exact prior JSON payload bytes (LF excluded). Stale prior means conflict, never a branch.
14. **Lifecycle:** one core idea→hypothesis→prereg→run→result-link→review-link→decision-link chain per experiment in v1; amendments/tombstones are optional targeted events. A second preregistered run uses a new experiment ID.
15. **Idempotency:** keyed only by event ID. Same ID plus byte-identical canonical payload = exit 0/status `already_appended`/no mutation. Same ID with different payload = non-zero conflict. Different ID = distinct event.
16. **Timestamp:** utility-generated UTC RFC 3339 with fixed milliseconds and `Z`; equal timestamps allowed; timestamp is not used as chain order. Reject clock rollback that would reopen a closed month.
17. **Actors/roles:** actors `user|claude|codex|zcode|oc-mgr|oc-dev|oc-btest|system`; roles `owner|lead_judge|peer_engineer|batch_runner|manager|system`; enforce the actor→role mapping from AGENTS roles.
18. **Authorization:** only `user` or `claude` with owner/lead role may create `DECISION_LINKED`, invoke physical recovery, disable, or re-enable. Other actors may link results/reviews only within their existing AGENTS permissions; no event grants authority.
19. **Serialization:** compact fixed-order JSON, UTF-8 without BOM, LF only, exactly one object and one terminating LF per line. Hash exact raw payload bytes; no text normalization.
20. **Artifact hashes:** SHA-256 over raw bytes, lowercase hex. Mandatory object keys are `ea/source/set/data/tester`; nullability is per event type. Multi-file inputs use a deterministic committed bundle-manifest artifact and hash that manifest, not an unspecified directory walk.
21. **Canonical owner reference:** required typed object with repo-relative path, full commit OID, blob OID, raw SHA-256, and stable anchor/key. No working-tree-only reference and no copied excerpt.
22. **Reason:** per-event `reason_code` enum plus `reason_ref`; no free-form reason string.
23. **Schema strictness:** per-event whitelist, `additionalProperties=false`, type/regex/count/length limits, unique evidence-ID arrays, and forbidden narrative/result/verdict/disposition/metric fields.
24. **Lock:** one repo-wide exclusive `FileStream` lock at `git rev-parse --git-path ea-lab-experiment-events.lock`; 50 ms bounded-jitter retry, 30 s timeout, revalidate all state after acquiring it.
25. **Atomic installation:** prebuild candidate in a same-volume temp file, `Flush(true)`, then atomic replace/move. Register evidence before the referencing event; orphan evidence entries are permitted, dangling event references are not.
26. **Rotation:** latest UTC month accepts prefix appends; older months are immutable. Global ID/chain/reference checks scan all months. Cross-file prior links are required for experiments spanning a boundary.
27. **Git enforcement:** a new staged-snapshot checker triggers on every event-log/manifest/schema path, validates the index candidate, enforces old-byte prefix and closed-month immutability, and is called by the production hook. Existing five-file archive protection remains separate.
28. **Corruption behavior:** diagnostic scan reports every bad line and all independently readable good event IDs; normal append refuses. Logical correction uses amendment/tombstone. Physical corruption uses the separately authorized locked rebuild transaction.
29. **Tombstone:** targets a valid event ID plus line hash, never deletes it, cannot target itself, and has no verdict meaning. Double tombstone and unknown target are rejected. Chain continues from the latest event, not from the target.
30. **Disable/rollback:** disable acquires the same lock and creates a Git-private sentinel. A holder may finish; queued writers fail after rechecking. Rebuild preserves verified bytes and records newly reconstructed occurrences explicitly; it does not claim impossible byte-identical recovery of lost metadata.
31. **Exit/output contract:** machine-readable status distinguishes `appended`, `already_appended`, `schema_invalid`, `reference_invalid`, `event_id_conflict`, `stale_prior`, `integrity_corrupt`, `clock_skew`, `disabled`, and `lock_timeout`; only the first two return zero.
32. **Size limits:** cap line size, evidence count, owner-reference count, and token/string lengths in schema so validation cannot be used to add an unbounded narrative or exhaust memory.

## Missing negTests

### Locking, concurrency, and atomicity

- Separate-process barrier plus deliberately held production lock; assert observed waits/retries.
- Lock timeout returns the pinned non-zero status and changes no file.
- A stale lock pathname with no open handle does not block.
- Two writers for the same experiment and same prior: one succeeds, one fails stale-prior; no fork.
- Concurrent same-ID/same-payload retries: one append, remaining calls report `already_appended`.
- Concurrent same-ID/different-payload calls: one append, remaining calls report conflict.
- Concurrent evidence registration plus event append never creates a dangling event reference.
- Crash/fault injection before temp flush, after temp flush/before replace, after replace, and after manifest install/before event install.
- Orphan temp recovery removes only utility-owned temp names and never an unrelated file.
- Orphan manifest entry is accepted; missing manifest entry referenced by an event is rejected.

### Rotation, time, IDs, and chains

- Experiment starts in one month and result/review/decision occur in the next; every cross-file prior link resolves.
- Boundary concurrency around `23:59:59.999Z`/`00:00:00.000Z` using an injectable test clock.
- Edit/append/delete/rename of a closed month is rejected by staged validation.
- Backdated append and clock rollback cannot reopen an old month.
- Same-timestamp events remain valid and chain order is unambiguous.
- Duplicate event ID in a different monthly file is rejected.
- Duplicate experiment ID via a second `IDEA_CREATED` is rejected.
- Missing prior, prior from another experiment, wrong prior hash, non-tail prior, self-link, cycle, and forward reference are rejected.
- Out-of-order lifecycle transition, duplicate core event, and legacy event names are rejected.
- Amendment/tombstone target unknown ID, wrong target hash, self-target, double tombstone, and unauthorized actor are rejected.

### Schema and serialization

- Missing required field, wrong type, unknown event type, unknown field, and non-object JSON.
- Unsupported/absent/future `schema_version`; mixed v1/future-version file fails closed without rewriting.
- Malformed JSON, invalid UTF-8, BOM, CRLF, embedded newline, blank line, missing final LF, and multiple JSON objects on one line.
- Oversized line/string/array and duplicate evidence IDs are rejected before mutation.
- Uppercase/wrong-length/non-hex hashes and a hash computed from normalized text rather than raw bytes are rejected.
- Timestamp with offset/local time, non-fixed precision, invalid date, future/backward month, and caller-supplied timestamp override are rejected.
- Unknown actor/role and invalid actor-role pair are rejected.
- Per-event nullability rules for all five artifact hashes and trial fields are exercised.
- Forbidden fields and aliases (`result`, `verdict`, `decision`, `disposition`, `status`, `profit`, `PF`, narrative `reason`, arbitrary metadata) are rejected.
- Canonical property order/compact serialization is deterministic across two PowerShell 5.1 processes and under `core.autocrlf=true`.

### Canonical-owner and evidence references

- Absolute path, `..` traversal, outside-repo path, directory path, symlink escape, and case-mismatched Windows path are rejected.
- Owner/evidence commit missing or abbreviated, blob missing, blob OID mismatch, raw SHA-256 mismatch, size mismatch, and anchor missing/non-unique are rejected.
- Dirty/staged-but-uncommitted artifact is not durable and is rejected.
- Ignored/transient untracked artifact is rejected even when it exists and has a hash.
- A force-tracked artifact under an ignored directory is accepted only by resolving it from the referenced commit, not by ignore status alone.
- A file absent from the current worktree but recoverable at the referenced commit remains valid evidence.
- Current path whose bytes changed after the referenced commit still resolves the historical bytes correctly.
- Unsupported external-store locator is rejected in schema v1.
- Canary resolves actual canonical owner classes and contains no copied result/review/verdict/deployment content.
- Non-lead actors cannot sign/link a canonical decision; an event never changes owner-file permissions.

### Corruption, recovery, Git enforcement, and rollback

- Corrupt first, middle, and final line; truncated multibyte UTF-8; garbage line; structurally valid but schema-invalid line.
- Diagnostic scan reports all exact bad line numbers and all readable good IDs; normal append fails without mutation.
- Physical recovery cannot be invoked without authorized recovery reference and quarantined-byte evidence.
- Authorized recovery produces a valid clean prefix, preserves every verified event byte, records recovery, and passes staged validation.
- Normal direct edit, deletion, rename, reorder, CRLF-only drift, or truncation of any monthly file is blocked by the production hook.
- A valid utility-produced prefix append plus consistent manifest/schema passes the real hook in a temp repo.
- Event-only, manifest-only, or schema-only stale/inconsistent staged transactions are blocked; ordinary commits remain fast-pass.
- Disable waits for the holder, then causes queued/new writers to return `disabled` without mutation; re-enable requires authorized action.
- In-flight nonterminal experiments remain traceable during disable/rebuild and no canonical verdict/deployment file is altered.
- Rebuild from last committed prefix plus validated tail is deterministic for preserved events and does not fabricate original IDs/timestamps for missing occurrences.
- Run the complete suite twice; case set/counts are identical, TEMP leftovers are zero, and shared HEAD/index/worktree/Git config match the captured pre-state.

## Scope and §20.9 check

- The intended product remains within Contract D: event utility, linked schema, evidence manifest, acceptance, and rollback. It does not add verdict ownership, backfill, a Context Packet, a generated write-back surface, monitoring thresholds, or a database.
- The order improperly treats the pre-§20 line-274 event list as binding; F01 converts that material into an explicit ORDER-105 implementation decision under §20.5 and resolves it in favor of §20.7.
- The order silently drops “JSONL monthly in Git” from §20.2; F02 restores it.
- The order names tombstone only in rollback but drops it from the schema and executable behavior; F04 restores it.
- The three Contract D outputs are coupled enough to remain one build order after these decisions are pinned, but the staged checker is part of the required acceptance surface and must be named explicitly. If the lead does not want to extend the production hook in the same build, ORDER-105 must be split; accepting an unprotected interval would contradict the existing fail-closed Git philosophy.

DESIGN VERDICT: NEEDS-CHANGES(13)
