# Next-session prompt — the gate is green, `ORDER-731` item 1 is closed, four orders are open behind it

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for the next
> session on the Factory OS track**. Written 2026-08-01, end of lane `S-2026-08-01-PINFIX`. The
> previous opener (`_triage/PROMPT_NEXT_SESSION_CFGFP.md`) is spent — its item 1 was the owner
> decision, which the owner gave, and its item 3 (`ORDER-732`) is closed.
> Paste the block below as the first message of the new session.

---

```
Batch closed 2026-08-01: ORDER-731 item 1 + ORDER-732. THE GATE IS GREEN AT HEAD -- the red that
blocked the previous session is cleared. A commit that would move an owner-attested blob is now
REFUSED AT THE HOOK instead of turning the gate red after it lands, and the repair commit still
lands. HEAD = <run git log --oneline -1> · full tier 16/16 at 74.2-74.3s of the 90.0s budget.

Read in this order:
  PROJECT_STATE.md  §2 top entry + §3 (decision log)
  _triage/HANDOFF_2026-08-01_PINFIX.md  (the shift note -- the owner decision and what it left
      owed, and the "live traps" section, which is the part that saves time)
  docs/GUARD_SHAPES.md  (still the pre-flight for writing OR REPAIRING any guard)
  AGENT_TASKBOARD.md -- grep '## ORDER-731' for the evidence, then 730 / 760 / 761

What is actually open (checked before writing this, not assumed):
  1. ORDER-731 item 2 -- the tier abort. Fired in 2 of 8 manual full-tier runs on 2026-08-01; one
     instance explained (a concurrent lane committed), one NOT (it recurred with no lane open).
     It did not fire in either of this lane's two runs, which is evidence of nothing at n=2.
     Wake condition unchanged: a third instance, or one inside a real `git commit`.
  2. ORDER-760 -- a ledger cell is PROSE and the collision guard's INPUT, with nothing marking
     where one ends. TWO instances, both in the last lane's own reservation row: a literal | inside
     backticks shifted every column after it (guard printed "no ACTIVE lane" and PASSED, with RULE
     2 and RULE 3 unarmed for two commits), and citing another lane's block number IN PROSE, to say
     it was being declined, reserved it. The first repair -- a sentence quoting those numbers --
     added a fourth range. READ THAT ORDER BEFORE YOU WRITE YOUR LEDGER ROW.
  3. ORDER-761 -- a module should DECLARE the paths it reads (GUARDED_INPUTS) instead of a regex
     guessing them. Opened because ORDER-732 measured the alternative and it was not payable.
  4. ORDER-730 -- the LOCKED CONSTANTS half of design 5.6, untouched and unchanged. Needs an MT5
     lane if ea_template/core/ changes.
  5. Five NON-front-guard PowerShell checkers still print in L3's suspension list every run --
     read the live line, don't trust this one:
     `tools/python312/python.exe _triage/factory_os/run_guard_shape_lint.py`. Migrating them is a
     new order, not a continuation.
  6. FIVE items now in _triage/USER_DECISIONS_PENDING.md -- item 5 is new and is the one that
     charges a toll every day it is undecided (below).

Owed to the owner, do not decide these:
  the 5 items in _triage/USER_DECISIONS_PENDING.md. Item 5 is new: MASTER_BACKLOG.md is pinned by
  a WHOLE-FILE blob and takes 30 commits per 14 days, so the pin costs ~2 owner signatures a day.
  Three costed options are written out. Restoring the | D33 | row that lane S-2026-08-01-OPERATE
  needs for its handoff routing waits on that decision.

Rules that still hold (restated because they are still true):
  - Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before anything. Parse
    `## ORDER-<n>` from all four board files yourself -- the foot-of-file summary is stale
    (BACKLOG-D29). ⚠️ THE ORDER-BLOCK CELL IS PARSED: every number-looking token in it is data.
    Write ONE range token and cite NO other block number, not even to say you are declining it,
    and put no literal | anywhere in the row. That cell disarmed the last lane's guard rails twice.
  - VERIFY a ledger repair with the guard's OFFLINE entry points (-LedgerContent,
    -StagedActiveContent, -StagedFileList). The hook reads the ledger at HEAD by ratified rule, so
    your repair commit still prints the pre-repair diagnosis and believing it wastes a round.
  - CLOSE THE LANE ROW IN YOUR LAST COMMIT, NOT BEFORE.
  - `git add` the paths BEFORE `git commit -- <paths>`. A new file is untracked until added, and
    the trigger suites check declared inputs with `git ls-files`.
  - DO NOT APPEND TO MASTER_BACKLOG.md. Still pinned; the difference now is you find out at the
    hook (P1, by name) instead of afterwards. Open an ORDER instead.
  - Do NOT edit an attestation BUNDLE member to make something pass -- that costs an owner
    signature (ORDER-614 rev 2). check_s2a_attestation.py is OUT of the bundle; the POLICY and the
    VECTORS are IN.
  - Budgets are ENFORCED: 65s per-path / 90s full tier. ~15s of full-tier headroom at 74.2s.
    A new cage DISPLACES something. Measure the tier in the same commit.
  - Anything GENERATED must be regenerated in the same commit as its source:
    `powershell -File scripts/gen_fast_tier_pathspec.ps1` after touching $SUITE_GUARDS, and
    `tools\python312\python.exe _triage/factory_os/gen_input_surface.py --write` for the EA surface.
  - core.autocrlf is true here: the blob is LF, the worktree CRLF. Fold newlines and SAY you did.
  - Do NOT read a shared doc with utf-8-sig and write it back without the BOM. docs/SESSION_LEDGER.md
    is Thai and PS 5.1 reads a BOM-less file as ANSI.
  - MT5 tester logs are UTF-16LE, under ...\Roaming\MetaQuotes\Tester\<id>\Agent-127.0.0.1-30NN\logs\.
  - Never git add -A. Commit path-limited. Never git stash to compare revisions --
    `git show HEAD:path > scratchpad/` instead.
  - Codex quota is out. Fable = /fable-advisor only, never batch labour.
  - factory/universe.jsonl must not be created until the owner re-attests D1.
```

---

## What this batch proved that the next session should not re-derive

| fact | evidence |
|---|---|
| a gate that reads `HEAD` can neither refuse the commit that breaks it nor accept the one that repairs it | measured twice in one afternoon; the repair needed an owner-approved `--no-verify`. The fix is a SECOND question at a DIFFERENT snapshot, not moving the first one — moving it would have edited a bundle member and cost a signature |
| the hard half of a "refuse the bad commit" guard is letting the GOOD one through | a guard refusing every touch of the pinned path passes every attack test and rebuilds the trap. Mutation 3 exists to fail exactly there |
| a guard that finds nothing passes everything, and looks identical to a guard that works | `pinned_expectations -> {}` broke only the ENGAGEMENT case; every "no problems" assertion stayed green (GUARD_SHAPES shape 5) |
| a warning about a SYMPTOM does not protect against the RULE | `ORDER-675` warned about a character class in the order-block cell. The author read it and then hit the same parser twice by other means — a literal pipe, and a block number in prose |
| a repair is not verified by the run that lands it | the collision guard reads the ledger at HEAD by ratified rule, so the repair commit printed the pre-repair diagnosis. Only the offline entry points could answer |
| measuring a widening can kill it more cleanly than building it | `ORDER-732`: 66 declarations, 36× on the commonest commit — and the decisive part was that a text scan cannot tell a path a module READS from one it MENTIONS |
