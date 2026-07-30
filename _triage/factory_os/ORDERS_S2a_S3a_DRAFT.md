# ORDER-600 / ORDER-601 — ready to paste into `AGENT_TASKBOARD.md`

**Why they are here and not on the board:** `S-2026-07-30-SENSFAN` holds 46 uncommitted lines in
`AGENT_TASKBOARD.md` (the ORDER-542 sensitivity fan, held at the user's own instruction). Ledger rule 4
is *one writer per shared file per period*, so appending here would carry that lane's work into this
lane's commit. Numbers **600** and **601** are drawn from this lane's reserved block 600-609 and are
therefore already spoken for — pasting these blocks verbatim consumes no new number.

Both are cleared by the audit-3 verdict and re-confirmed by audit 4 (`CODEX_AUDIT4_2026-07-30.md`, Q5:
GO on both, independently). **Neither unblocks S2, S3, S4, S10 or S14.**

---

## ORDER-600 — S2a: Coverage ownership proposal + migration table

**Status:** OPEN · **Owner:** Claude (lead) · **Blocks:** S2 (canonical Coverage transfer)

### What this is
`MASTER_BACKLOG.md` §2 owns the coverage matrix today and says so. The Factory OS design proposes that
`factory/coverage.jsonl` becomes the machine source and §2 is *regenerated* from it. **This order does
not perform that transfer.** It produces the proposal and the migration table that the owner of
`MASTER_BACKLOG.md` signs — or refuses.

### Deliverables
1. `_triage/factory_os/S2A_OWNERSHIP_MIGRATION.md` containing, for **every** fact the design's
   `__STORAGE__` table names:
   - current owner file · proposed owner file · **canonical or derived** after the move
   - what breaks if the move happens · what breaks if it does not
   - the exact `OwnerRef` (path + commit_oid + blob_oid + raw_sha256) that would replace each copy
2. A row per owner with an explicit **sign-off state**: `PROPOSED · APPROVED · REFUSED`. Initial state
   is `PROPOSED` for all. No row may start as `APPROVED`.
3. A **reverse migration** paragraph per moved fact: how to put it back, and what evidence is lost if
   the move is reverted after N days.

### Acceptance (numeric, checkable)
- [ ] Every entity in `schemas.json` `$defs` appears in the table exactly once — count must equal the
      `$defs` count reported by `gen_design_contracts.py` (**24** at the time of writing; read it, do
      not copy this number).
- [ ] Zero rows in state `APPROVED`.
- [ ] For every fact whose proposed owner differs from its current owner, a named human/agent owner is
      recorded. A row with no owner is a defect, not a TODO.
- [ ] Cross-checked against `MASTER_BACKLOG.md` §2's actual current contents — the count of coverage
      cells stated in the migration table must match §2's real row count, measured, not asserted.

### Prohibited
- ❌ Editing `MASTER_BACKLOG.md` §2 in any way. This order writes a **proposal about** it.
- ❌ Creating `factory/coverage.jsonl` or any file under `factory/`.
- ❌ Marking any sign-off `APPROVED` — that is the owner's act, in a separate commit.
- ❌ Demoting any current owner listed in design §1.1.

---

## ORDER-601 — S3a: pin the all-clear validator, and write the fixtures it is owed

**Status:** OPEN · **Owner:** Claude writes the boundary decision · Codex/Sonnet may write fixtures
**Blocks:** S3, and through it S4

### The actual blocker this order exists to remove
`ControlRoomSnapshotV5.reconciliation.all_clear` is **required** in the persisted document *and* the
schema says a writer-supplied value **must be rejected**. Both cannot be checked against one document:
the builder has to write it, so no validator inspecting the persisted file alone can tell "the builder
computed this" from "somebody typed it". This is the *builder-input vs persisted-output boundary*, and
it is the reason S3 is blocked.

**Recommended resolution — decide it in this order, do not defer it again:** two entities, not one.
- `SnapshotBuilderInput` — **closed**, and `all_clear` is **not among its properties**, so an input
  carrying it is rejected by the schema itself, with no special-case code.
- `ControlRoomSnapshotV5` — the persisted document, `all_clear` **required**, written only by the
  validator that computed it.

### Deliverables
1. The boundary written into `schemas.json` as the two entities above (or a better shape, argued).
2. `snapshot_validator` — the real thing, not a stub. It reads a `SnapshotBuilderInput`, computes
   `all_clear`, and emits a `ControlRoomSnapshotV5`.
3. Negative fixtures in `run_schema_fixtures.py`, **one per bullet below**, each naming the rule it
   guards, each demonstrated failing before the rule exists and passing after.

### Acceptance (every one of these is a fixture, both directions)
- [ ] A mandatory source that is **missing** ⇒ `all_clear=false`. Not an exception, not a skip.
- [ ] A mandatory source that is present but **unreadable** ⇒ `all_clear=false`, and distinguishable in
      the output from *missing* (memory `prove-the-instrument-can-see-the-file`: "cannot read" and
      "nothing to report" must never collapse into one state).
- [ ] A mandatory source that is readable but **stale** ⇒ `all_clear=false`.
- [ ] `sources=[]` with `all_clear=true` ⇒ **rejected**. (Codex built this exact instance during audit 4
      and ajv passed it. It is the single most important case here.)
- [ ] A builder input **carrying** `all_clear` ⇒ rejected by schema, without validator code.
- [ ] `discovered != categorized` ⇒ `all_clear=false`.
- [ ] category sum ≠ `categorized` ⇒ `all_clear=false`.
- [ ] coverage sum mismatch ⇒ `all_clear=false`.
- [ ] `conflicts > 0` or `unclassified > 0` ⇒ `all_clear=false`.
- [ ] **The positive case:** a fully healthy input ⇒ `all_clear=true`. Without it the validator could
      return `false` unconditionally and every case above would still pass — the inert-guard failure
      this repo has hit five times.
- [ ] The validator reads the **whole persisted document shape**, not a detached `meta` object
      (audit-4 Q5).
- [ ] `run_schema_fixtures.py` final line — the real `portfolio/control_room_snapshot.json` — is **not
      required to pass in this order.** That is S4's acceptance criterion and must stay S4's.

### Prohibited
- ❌ Writing `portfolio/control_room_snapshot.json`, or changing the live snapshot's version.
- ❌ Touching `make_status.ps1`, `live_dashboard.ps1`, `daily_monitor.ps1` — those are S4.
- ❌ Inventing a freshness threshold. `stale_bar_hours` already exists in the real snapshot `meta`;
      read it. A guard firing on an invented number is worse than no guard because it looks like one.
- ❌ Declaring any bullet above satisfied on a fixture that has never been observed failing.

---

## Note for whoever pastes these

Both blocks are self-contained. After pasting, the only board edits owed are the two `## ORDER-600` /
`## ORDER-601` headers and their bodies — nothing else on the board changes. Re-read `git log -1`
before staging: `AGENT_TASKBOARD.md` is a shared file and rule 4 says HEAD moving means read again.
