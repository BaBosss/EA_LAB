# HANDOFF 2026-07-30B — the design↔schema binding, two blind audits, and S3a half-built

**Lane:** `S-2026-07-30-CONTRACTGEN` (block 600-609) · **Commits:** `657af404` → `c8d03d4b`
**Predecessor:** `_triage/HANDOFF_2026-07-30_FACTORY_OS_AND_STAGE0.md`

---

## 1. Where to start

**Run these three first. If any is red, stop and read it — do not build on top of it.**

```
tools\python312\python.exe _triage\factory_os\gen_design_contracts.py --check
tools\python312\python.exe _triage\factory_os\run_contract_binding_tests.py
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py
```

Expected: 30 blocks match · 18/18 binding cases · 28/28 ajv cases. Then read
`_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` — **ORDER-601's acceptance list is the spec for the next
piece of work**, and it is written to be un-gameable on purpose.

**Neither Order is on the board yet** — a concurrent lane held `AGENT_TASKBOARD.md` for this entire
session, so both are drafted in `_triage/factory_os/ORDERS_S2a_S3a_DRAFT.md` and tracked by
`BACKLOG-D30`. **First action of the next session: check whether the board is free, and if it is,
paste both blocks verbatim** — numbers 600/601 are already reserved to lane `S-2026-07-30-CONTRACTGEN`
and consume nothing new.

**The next task is ORDER-601 part 2** (part 1 landed in `c8d03d4b`): build `snapshot_validator`, its
computation suite, and the mutation table. Details in §4.

## 2. What was finished

**BACKLOG-D31 — the design's normative tables are generated.** `_triage/factory_os/schemas.json` is the
manifest (deliberately not a new file — a separate one would be a third hand-maintained copy).
`gen_design_contracts.py` writes 30 blocks into the design; `--check` exits 1 on drift and **refuses if
any `$defs` entity has no block anywhere**, because an entity the design never states cannot be caught
contradicting the schema. `run_contract_binding_tests.py` re-applies all 7 historical regressions as
schema mutations: **7/7 caught, previously 0/7**.

**BACKLOG-D32 — the cage trigger is derived, not enumerated.** The pre-commit hook chose whether to run
the fast tier by matching a hand-listed set of directories; five times in four days a new suite guarded
a file no entry matched. `$SUITE_GUARDS` in `run_fast_cages.ps1` now declares each suite's inputs,
`scripts/gen_fast_tier_pathspec.ps1` generates `.githooks/fast_tier_pathspec`, and
`run_guard_trigger_tests.ps1` is its cage (key-set equality · declared paths tracked · pathspec current
and every input **measured with git** to be selected · undeclared-reference sweep).

**Two blind Codex audits, both acted on.** Reports committed verbatim:
`_triage/factory_os/CODEX_AUDIT4_2026-07-30.md` and `CODEX_AUDIT5_2026-07-30.md`. Audit 5's verdict was
**GO WITH AMENDMENTS**; both Orders were rewritten to rev 2 against its findings.

**ORDER-601 part 1 — the boundary that was blocking S3.** `all_clear` was required in the persisted
document *and* a supplied value had to be rejected, which no validator can check against one document.
Now three entities: `ReconciliationEvidence` (closed, no `all_clear` property, so a supplied one is
refused by the schema and the error names the property) · `SnapshotVerdict` (`all_clear` + a closed
reason-code enum) · `SnapshotBuilderInput` (closed root). Fixtures 17 → 28.

## 3. Traps this session paid for — read before trusting any green run here

- **A green suite that counted tool failure as rejection.** `run_schema_fixtures.py`'s `run()` returned
  `p.returncode == 0`, so ajv missing / schema unreadable / an unresolvable `$ref` all read as "instance
  rejected" — which is what every negative case wants. **Measured: delete `schemas.json` entirely and it
  reported 14 of 17 cases OK.** Fixed in `3812d72c`; ERROR is now a third state that satisfies nothing.
- **The cage was never wired to the files it guards.** Staging a design-only edit produced **zero**
  fast-cage lines. It looked enforced for four commits. Found by staging one file and counting output,
  not by reading code.
- **Red on a clean checkout with an empty diff.** Working tree is CRLF, the generator emits LF, and the
  diff printer normalised before diffing — so `--check` failed and printed nothing, and the harness
  ABORTED with every case unrun. Both entry points now normalise; there are permanent EOL fixtures.
- **Two of my own probes were wrong before the code was.** One appended a line *outside* every generated
  block (legal, cage correctly passed) and I nearly read it as a failure; one EOL fixture used
  `split('\n')` and re-joined, appending a newline the original never had. **A probe that cannot fail
  proves nothing.**
- **`walk_fields` skipped nullable nested objects** (`type: ["object","null"]`), so `lease`,
  `process_observed` and `safe_range` lost their required sets from the design while the schema still
  carried them. I had reported these as "survived" after checking description text rather than fields.
- **A stale 0-byte `.git/index.lock`** appeared mid-session; no git process was running, so it was
  removed. Another lane wrote 44 more lines into `AGENT_TASKBOARD.md` while this lane worked — **this
  working tree has live concurrent writers; commit path-limited, always.**

## 4. ORDER-601 part 2 — the next piece, and what makes it hard

Build `snapshot_validator`: read a `SnapshotBuilderInput`, compute `all_clear` + reason codes, emit a
`ControlRoomSnapshotV5`, and **recompute on read** so a hand-authored output with `sources=[]` and
`all_clear=true` is refused. Audit 5 built exactly that instance; JSON Schema cannot prove authorship,
so recomputation at the trust boundary is the only defence.

Every acceptance line is in `ORDERS_S2a_S3a_DRAFT.md`. The four that decide whether it is real work:

1. **One-field minimal pairs with asserted reason codes.** A negative that is also invalid for an
   unrelated reason gets credited to the rule it names while never reaching it.
2. **A mutation table**: disable each predicate in turn; only that predicate's fixture may go red. A
   predicate whose removal turns nothing red is not tested. This artifact is a deliverable.
3. **Two independently constructed healthy positives.** One only blocks a constant-false implementation.
4. **No test-only identifiers in validator logic** — `build_id == "fixture-healthy"` returning true is
   the cheapest way to pass everything.

**Budget warning:** the fast tier is at **14.0s of its 15s budget with 12 suites**. A new PowerShell
suite for the validator will not fit. Decide deliberately — displace `run_optimize_guard_tests.ps1`
(5.8s, the only real candidate), raise the budget with a written reason, or run the validator's tests
inside an existing suite. **Do not quietly exceed it**; the budget is the only reason this tier has not
been `--no-verify`'d.

## 5. Open, and who owns it

**Nothing is waiting on the user right now.** Four items previously listed as user decisions are not
needed until slices that are far away (`§3 account|magic` invariant → S10 · `AGENTS.md` §2 → S14 ·
"~10,000 combinations per round" → optimize policy) or are no longer questions (the SENSFAN taskboard
rows — that lane is still actively writing; just do not touch the board).

**One standing recommendation, not yet done:** generate a separate `_triage/factory_os/CONTRACTS.md`
and leave the design with links and rationale only. The design went 829 → 1745 lines when 27 blocks were
injected, while its own §7.4 is about reading it without exhausting context; and it removes the
in-document marker protocol, where two defects lived. **Both this seat and Codex audit 5 Q4 recommend it
independently.** The user has been told it will happen unless they object.

**Still unbound prose:** §3 state machines, §5.3–5.5, §6, §7 have no schema backing, and `x-enforced-by`
names validators that do not exist. `_why` in `x-ea-lab-meta.contracts` can hold normative text
unrendered. D31 closed the entity/field seam, which is where all seven regressions lived — not the
document.

<!-- HANDOFF-ROUTING -->

| item | routes to |
|---|---|
| BACKLOG-D31 — generated contract tables, 7/7 regressions caught, cage in the fast tier | DONE |
| BACKLOG-D32 — trigger derived from declared guards, 4-part cage | DONE |
| Audit 4 + audit 5 dispatched, committed verbatim, all code findings fixed | DONE |
| Order drafts for S2a/S3a amended to rev 2 against audit 5 | DONE |
| S3a part 1 — evidence/verdict split, 28 ajv fixtures | DONE |
| S3a part 2 — snapshot_validator, computation suite, mutation table (draft order not yet on the board) | BACKLOG-D30 |
| S2a migration table + its checker (draft order not yet on the board) | BACKLOG-D30 |
| Fast tier at 14.0s of 15s; a new suite must displace or raise deliberately | BACKLOG-D32 |
| Separate CONTRACTS.md; design is 1745 lines with 30 blocks inlined | BACKLOG-D31 |
| §3 / §5.3-5.5 / §6 / §7 still unbound prose; x-enforced-by names absent validators | BACKLOG-D31 |
