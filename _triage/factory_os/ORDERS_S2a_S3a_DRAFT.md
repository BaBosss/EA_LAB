# ORDER-600 / ORDER-601 — ready to paste into `AGENT_TASKBOARD.md`

**Revision 2, amended 2026-07-30 after Codex audit 5** (`CODEX_AUDIT5_2026-07-30.md`, verdict
**GO WITH AMENDMENTS**). Rev 1's acceptance could be satisfied without doing the work: audit 5 constructed,
for every criterion, the cheapest output that met the letter and defeated the purpose. Every amendment below
traces to one of those constructions. The two headline ones, because they set the shape of everything else:

- **ORDER-600 rev 1** could be closed with 24 rows named from `$defs`, `current_owner=schemas.json` in every
  one, `aaa…`/`bbb…`/`ccc…` in every OwnerRef, and **no migration proposed at all** — including not proposing
  the Coverage transfer the order exists to prepare.
- **ORDER-601 rev 1** could be closed by returning `all_clear=false` for everything except one fixture matched
  on `build_id`, with every negative fixture invalid for an unrelated reason. The single positive case blocks a
  literal constant-false implementation and nothing else.

**Why they are here and not on the board:** `S-2026-07-30-SENSFAN` holds 46 uncommitted lines in
`AGENT_TASKBOARD.md`. Ledger rule 4 is one writer per shared file per period. Numbers **600** and **601** come
from this lane's reserved block 600-609, so pasting consumes no new number.

**Neither order unblocks S2, S3, S4, S10 or S14.**

---

## ORDER-600 — S2a: Coverage ownership proposal + migration table

**Status:** OPEN · **Owner:** Claude (lead) · **Blocks:** S2 (canonical Coverage transfer)

### What this is
`MASTER_BACKLOG.md` §2 owns the coverage matrix today and says so. The design proposes that
`factory/coverage.jsonl` becomes the machine source and §2 is regenerated from it. **This order does not
perform that transfer.** It produces the proposal and the migration table its owner signs — or refuses.

### Deliverables

**D1 — `factory_os/s2a_migration.jsonl`, machine-readable, one object per line.** Not a prose table: audit 5
showed the rev-1 acceptance counted entity names and could not see whether any column held a real fact. Each
line carries `entity · current_owner · proposed_owner · disposition · canonical_or_derived · owner_ref ·
breaks_if_moved · breaks_if_not_moved · signoff_owner · signoff_state · reverse_steps · evidence_lost ·
retention_window`.
- `disposition` ∈ `TRANSFER · KEEP · RETIRE` — and `KEEP` requires a one-line reason. Setting every row to
  `KEEP` is the null migration audit 5 built; it is now a visible choice with a name on it, not a default.
- `signoff_state` ∈ `PROPOSED · REFUSED` only. `APPROVED` is not a value this order may write.

**D2 — `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md`**, generated from D1, plus the human-judgement prose
that D1 cannot hold.

**D3 — `_triage/factory_os/check_s2a_migration.py`**, the checker. Acceptance below is what it asserts. A
criterion with no line in this file is not acceptance; it is a wish.

### Acceptance — MACHINE (the checker must assert each; `exit 1` on any)
- [ ] The set of `entity` values equals **exactly** the set of rows in the generated `__STORAGE__` block —
      set equality, not count equality. Read it from `gen_design_contracts.py`; do not hardcode 24.
- [ ] Zero rows with `signoff_state = APPROVED`.
- [ ] ~~Every `current_owner` and `proposed_owner` is drawn from a declared vocabulary of real paths, and
      **every path exists in the repo at HEAD**.~~ **AMENDED 2026-07-30 (rev 4) — as written this clause made
      the order UNSATISFIABLE, and it is amended before any work rather than quietly reinterpreted while
      building.** MEASURED: **11 of the 27 entities** have an `x-owner-file` that does not exist at HEAD
      (`factory/` does not exist at all — `hypotheses.jsonl` · `parameter_bindings.jsonl` · `universe.jsonl`
      ×2 · `instrument_profiles.jsonl` · `coverage.jsonl` · `runs/<run_id>.jsonl` ·
      `candidates/<candidate_id>.json` · `magic_allocations.jsonl` · plus `ops/findings.jsonl` and
      `build/safe_projection.json`), while the Coverage-edge criterion below **requires** a row whose
      `proposed_owner` is `factory/coverage.jsonl` and the Prohibited list **forbids creating** it. Three
      clauses that cannot all hold. The rule is now:
      - **`current_owner` MUST exist at HEAD.** This is where the anti-gaming bite belongs: it is a claim
        about today, and `schemas.json` is not a valid `current_owner` for a fact it only describes.
      - **`proposed_owner` may be a path that does not exist yet**, but must appear in a `PLANNED_PATHS`
        vocabulary declared in `check_s2a_migration.py`, so a typo is still caught while a future file stays
        expressible. A proposal about future storage that may only name present storage is not a proposal.
      - **`EMBEDDED:<ParentEntity>` is a legal owner value**, because **12 of the 27** entities are embedded
        in a parent and own no file (`OwnerRef` · `ModuleUse` · `MetricRef` · `ExecutionKey` · `RunAttempt` ·
        `RunJournal` · `CandidatePayload` · `WorkReceipt` and others). Such a row MUST carry
        `disposition = KEEP` with its reason, and is exempt from `owner_ref` pinning — there is no blob to pin.
- [ ] Every `owner_ref` is **recomputed, not merely shaped**: resolve `path` at `commit_oid`, compare
      `blob_oid` against `git rev-parse`, recompute `raw_sha256` from the blob bytes. **Zero unresolved,
      zero mismatched.** A plausible-looking constant is the rev-1 failing case. **rev 4 scope:** this
      applies to every row that CLAIMS an `owner_ref`, and a row may only decline one when its
      `current_owner` is `EMBEDDED:*` or names a fact that lives in no file today — in which case
      `owner_ref` is `null` and `owner_ref_absent_reason` is required and non-empty. The recomputation is
      the whole point of the criterion and is not weakened for any row that has a blob to pin.
- [ ] `owner_ref` values are **distinct across rows** unless two rows genuinely pin the same blob, and any
      repeat carries `same_blob_reason`.
- [ ] Exactly one sign-off row per **distinct `current_owner`**, each with a non-empty named `signoff_owner`.
      No row may carry an empty signer.
- [ ] The Coverage edge is present and explicit: a row whose `current_owner` is `MASTER_BACKLOG.md` (§2) and
      whose `proposed_owner` is `factory/coverage.jsonl`, with `disposition` ∈ `TRANSFER · KEEP` and a named
      `signoff_owner`. **Its absence fails the order** — rev 1 could omit the entire point.
- [ ] **Coverage counting is reconciled, not asserted.** Report two separate numbers with a mapping between
      them: `source_rows_consumed` (EA rows in §2) and `cells_emitted` (normalized symbol×TF cells). They are
      **not equal and must not be equated** — measured 2026-07-30: §2 has **7 EA rows** but the LIVE column
      alone holds **8 cells**, because `ST_EA03` carries GBPUSD H1 *and* USDCAD H1, and the rejected/attempted
      column holds many more. Every source row consumed exactly once; every parsed symbol/TF/status token
      emitted once or marked `UNVERIFIED_IMPORT` **with its source coordinates**.
- [ ] Every row has non-empty `reverse_steps`, `evidence_lost`, `retention_window`.

### Acceptance — HUMAN REVIEW (labelled as such; the checker cannot judge these)
Rev 1 called the breakage analysis "numeric, checkable". It is not — 24 copies of "dashboard may break;
revert the commit" satisfies any mechanical form of it. Reviewer checklist, per `TRANSFER` row:
- [ ] `breaks_if_moved` names a **specific reader or writer** (file + what it reads), not a category.
- [ ] `breaks_if_not_moved` states a concrete failure that is happening or will happen, with a date or trigger.
- [ ] `reverse_steps` are executable steps, not "revert the commit".
- [ ] `evidence_lost` names what cannot be reconstructed after `retention_window`.

### Prohibited
- ❌ Editing `MASTER_BACKLOG.md` §2 in any way — this order writes a proposal **about** it.
- ❌ Creating `factory/coverage.jsonl` or anything under `factory/`.
- ❌ Writing `signoff_state = APPROVED`. That is the owner's act, in their own commit.
- ❌ Demoting any owner listed in design §1.1.
- ❌ Reporting DONE while the Coverage edge row is absent or every `disposition` is `KEEP`.

---

## ORDER-601 — S3a: pin the all-clear validator, and write the fixtures it is owed

**Status:** OPEN · **Owner:** Claude decides the boundary · Codex/Sonnet may write fixtures
**Blocks:** S3, and through it S4

### The blocker this order removes
`all_clear` is **required** in the persisted document *and* a writer-supplied value **must be rejected**.
Both cannot be checked against one document: the builder has to write it, so no validator inspecting the
persisted file alone can tell "computed" from "typed". That is the builder-input/persisted-output boundary.

**Shape to build — audit 5's refinement of the two-entity split, adopted:**
- `SnapshotBuilderInput` — closed; carries the snapshot facts and a closed `ReconciliationEvidence` that
  **has no `all_clear`**, so a supplied value is refused by the schema with no special-case code.
- `ControlRoomSnapshotV5` — the persisted document: the same preserved facts, plus validator-owned
  `all_clear` and a **closed list of reason codes**.
- **One output verification function** recomputes `all_clear` from the persisted evidence and rejects a
  mismatched boolean. This is the part rev 1 was missing. JSON Schema can prove the boolean is well-typed;
  it cannot prove authorship. Audit 5's surviving attack was a hand-authored output with `sources=[]` and
  `all_clear=true` — structurally valid, and only recomputation catches it.
- Readers accept a snapshot **only through that verifier** (wiring the readers is S4, not this order).

### Fixture discipline — applies to every case below, no exceptions
1. **One-field minimal pair.** Every negative is a known-valid positive with **exactly one** field changed.
   Rev 1 allowed a negative that was also missing `entity`; ajv returns nonzero and the case is credited to
   the rule it names while never reaching it.
2. **Assert the reason.** Each negative asserts a stable reason code / error path — not merely "rejected".
3. **Paired repair.** Repairing only that delta makes the instance valid again.
4. **Tool failure is ERROR, never rejection.** Already implemented in `run_schema_fixtures.py` as of
   `3812d72c` — `run()` returns `pass`/`fail`/`ERROR` and ERROR satisfies no expectation. Measured: with the
   schema file absent, the old code reported **14 of 17 cases OK**. Reuse this; do not reintroduce a boolean.
5. **Mutation table required.** Disable each predicate in turn; **only that predicate's named fixture may go
   red.** A predicate whose removal turns nothing red is not tested. This artifact is a deliverable.
6. **No test-only identifiers in validator logic.** `build_id == "fixture-healthy"` returning true is the
   cheapest way to pass everything below.

### Acceptance — every line is a fixture, both directions
- [ ] Mandatory source **missing** ⇒ `all_clear=false`, reason `MANDATORY_SOURCE_MISSING:<name>`.
- [ ] Mandatory source **unreadable** ⇒ `all_clear=false`, reason distinct from missing. Two closed states,
      `MISSING` and `UNREADABLE`, asserted by exact path — not two free-text messages nobody checks.
      ("cannot read" and "nothing to report" must never collapse: memory `prove-the-instrument-can-see-the-file`.)
- [ ] Mandatory source **stale** ⇒ `all_clear=false`. `age_hours` must be varied **across the
      `stale_bar_hours` boundary supplied in the input** — the validator must derive freshness, not accept a
      caller-supplied `fresh=false`. No threshold may be hardcoded.
- [ ] **`sources=[]` — two separate attacks, both required.**
      (a) builder input with `sources=[]` and no `all_clear` ⇒ computed false with `MANDATORY_SOURCE_MISSING`;
      (b) a complete **persisted** document with `sources=[]` and `all_clear=true` ⇒ **rejected by output
      recomputation**, naming the mismatch. Rev 1 had only a form of (a), and audit 4 built an instance ajv
      accepted.
- [ ] Builder input carrying `all_clear` ⇒ rejected, with the ajv error path/keyword **naming that property**;
      the same instance without it passes the input schema.
- [ ] `discovered != categorized` ⇒ false. Category sum ≠ `categorized` ⇒ false. Coverage sum mismatch ⇒ false.
- [ ] `conflicts > 0` ⇒ false. `unclassified > 0` ⇒ false.
- [ ] **`categories.actionable > 0` ⇒ false.** Omitted from rev 1 although `schemas.json` states it.
- [ ] **Nonnegative counts.** Measured 2026-07-30: `discovered` and `categorized` carry `minimum: 0`, but
      every nested `categories.*` and `coverage.*` integer, and `duplicates`/`conflicts`/`unclassified`, carry
      **none**. Audit 5's failing instance — `categories.actionable = -1`, `running = 1` — balances every
      equation and validates. Add `minimum: 0` to all of them, with a fixture per group.
- [ ] **Source identity.** Registry and source names unique; ~~exact membership both ways between
      `mandatory_sources` and `sources`~~ **AMENDED 2026-07-30 (rev 3, after Codex audit 6 flagged the
      deviation rather than letting it be called DONE): membership both ways for MANDATORY rows only** —
      every registry name must have a row, and every row claiming `mandatory:true` must be in the
      registry — because a genuinely optional source outside the registry is legitimate (the real v4
      writer emits three sources and the registry need not name all of them). Exact set equality would
      forbid that, and the implementation chose the weaker rule silently; this line now says which rule
      is meant. Plus a fixture where a row's own `mandatory:false` contradicts the registry.
      Prefer removing the redundant per-row flag over reconciling it — **deferred to S4**: the real v4
      consumers read the flag, so until they migrate, a contradiction that cannot be reported is one
      that ships.
- [ ] **Two independently constructed healthy positives** ⇒ `all_clear=true` — different non-zero counts and
      reordered sources. One positive only blocks a constant-false implementation.
- [ ] **Whole-root, not a detached `meta`.** Note `reconciliation` currently lives under `SnapshotMeta`, and
      `ControlRoomSnapshotV5` is declared `additionalProperties: true` — an arbitrary top-level shape
      validates today. Close the root, then assert independently that removing `entity`, `system_health` and
      `summary` each produces a root-path failure.
- [ ] **Compatibility fields survive input → output.** `stale_bar_hours`, `decision_bar_trades`,
      `counting_method` and the real source-row metadata exist in the live v4 file
      (`scripts/control_room_snapshot.ps1:383-389`) and are absent from the closed `SnapshotMeta`. The
      boundary must preserve them, with a fixture seeding them and asserting they are present in the output.
- [ ] The real `portfolio/control_room_snapshot.json` is **not required to pass** — that is S4's criterion and
      stays S4's. But its diagnostic line must distinguish expected schema incompatibility from a read/tool
      error (implemented in `3812d72c`; keep it).

### Prohibited
- ❌ Writing `portfolio/control_room_snapshot.json` or changing the live snapshot's version.
- ❌ Touching `make_status.ps1`, `live_dashboard.ps1`, `daily_monitor.ps1`, `control_room_snapshot.ps1` — S4.
- ❌ Inventing a freshness threshold. `stale_bar_hours` exists in the real snapshot `meta`; read it.
- ❌ Declaring any bullet satisfied by a fixture that has never been observed failing **for the reason it names**.
- ❌ Reporting DONE without the mutation table from discipline rule 5.

---

## What audit 5 says must happen alongside these

**BACKLOG-D32 before, or at latest with, ORDER-601.** ORDER-601 adds another validator and another cage
surface; adding it while the trigger is still a hand-enumerated glob repeats the known "suite exists but its
guarded inputs do not trigger it" failure. Five widenings so far, the last two on the same day.

## Note for whoever pastes these

Both blocks are self-contained. After pasting, the only board edits owed are the two `## ORDER-600` /
`## ORDER-601` headers and their bodies. Re-read `git log -1` before staging — `AGENT_TASKBOARD.md` is shared
and rule 4 says a moved HEAD means read again.
