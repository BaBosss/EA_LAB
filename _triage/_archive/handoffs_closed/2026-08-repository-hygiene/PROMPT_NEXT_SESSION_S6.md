# Next-session prompt — S6 preset compiler

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for the
> session that builds S6**. Written 2026-07-31 at the end of lane `S-2026-07-31-VECTORS`.
> Paste the block below as the first message of the new session.

---

```
Batch: ORDER-614 rev 2 LANDED (ddc8350c) · ORDER-670 core + migrations 3/8 · ORDER-675 closed
HEAD = 01adfc65 · lane S-2026-07-31-HANDOFF closed · check_state CLEAN · all suites green

Read in this order:
  PROJECT_STATE.md  (§3 decision log has three rules ratified 2026-07-31)
  docs/GUARD_SHAPES.md  (five shapes; shape 5 = a repair graded by the finding it closes)
  _triage/factory_os/TIER_SNAPSHOT_DESIGN.md  §2 and §6 only  (the builder/checker rule)
  AGENT_TASKBOARD.md — ORDER-670 and ORDER-614 rows only (grep '## ORDER-6')
  _triage/USER_DECISIONS_PENDING.md  (4 owner decisions; none block S6)

Task, in priority order:
  1. S6 — the preset compiler. It has NO order yet; write it as ORDER-680 first, with
     acceptance criteria that each carry a negative, then build. The slice list and S6's
     acceptance are in _triage/EA_LAB_FACTORY_OS_DESIGN.md §10.
  2. ORDER-670 T7 — the guard-shape lint still accepts a `# snapshot:` COMMENT for a
     category-A read; bind it to the read_committed CALL. Stated as owed on the board.
  3. ORDER-670 migrations, one commit each, each with its own T1 attack: registry.py's own
     resolve path · gen_coverage · snapshot_validator · run_guard_shape_lint ·
     check_coverage_transfer's enumerations. NOT snapshot_build — it is a BUILDER
     (category B) and its disk reads are correct.

Rules that must hold:
  - Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before using an
    order number. Block 690-699 is spent; parse `## ORDER-<n>` out of all four board files
    yourself and take the next free block. Do not trust the summary bullets at the foot of
    the ledger — they have been stale seven times.
  - The order-block cell must contain exactly ONE `NNN-NNN` token and no pipe characters.
    Prose in that cell becomes a reservation: a filename with a year-month in it was read
    as the range 7-2026 and permitted every order number in the repo (ORDER-675).
  - Shape 5: a fix commit carries TWO assertions — the attack, and one that fails if the
    new mechanism is inert or an untouched surface moved.
  - Never `git add -A`. Commit path-limited. ~270 dirty/untracked files must stay.
  - A guard's green means nothing until you have seen it red for its own reason.
  - Codex quota is out. Fable is the only independent brain — /fable-advisor, and never as
    batch labour.
  - factory/universe.jsonl must not be created until the owner re-attests D1.

Owed to the owner, do not decide these:
  the 4 items in _triage/USER_DECISIONS_PENDING.md (Core Universe v1 membership · AGENTS.md
  §2 writer surface · the account|magic invariant · the ~10,000-combination budget).
```

---

## Why S6 is next, and what it inherits

S2/S2a/S3/S3a/S4/S5 are built and audited; S6 is the next slice in the design's own order. It
inherits three things that did not exist when the earlier slices were written, and using them is
cheaper than rediscovering them:

| inherited | what it means for S6 |
|---|---|
| `evidence.py` | any checker S6 adds must decide **builder or checker** and use `read_committed` / `list_committed` / `observe` accordingly. Do not write a fresh `io.open` on a judged input. |
| the policy+vectors pattern (`ORDER-614`) | if S6 produces an artifact an owner must approve, bind **meaning and behaviour**, never the implementation — otherwise every repair costs a signature, which is the loop that order just closed. |
| `run_guard_shape_lint` L0/L1/L2 | a new `check_*.py` on disk is **demanded** by L0 automatically; every criterion it emits must be named by its suite. Expect the lint to refuse the first commit, and treat that as the lint working. |

## The three things most likely to go wrong, from this batch's evidence

1. **A number quoted without reading its members.** "31 declared reads" was 28. Compute every
   count in the same command that prints it.
2. **A test label naming a criterion its input cannot reach.** Two cases labelled F9/F10 passed on
   F11 for a structural reason. If a case cannot fail for the reason its name claims, the name is
   the bug.
3. **A fixture that mutates a real repo file.** `run_enforcement_status_tests` edits the real
   `schemas.json` and restores it; an interrupted run left the mutation stranded and turned two
   unrelated gates red. A background task is filed for it. Do not add a second one.
