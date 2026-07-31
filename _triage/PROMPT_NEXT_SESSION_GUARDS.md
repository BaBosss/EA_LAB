# Next-session prompt — the ORDER-670/ORDER-674 batch is closed; what's left

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for the
> next session**. Written 2026-08-01, end of lane `S-2026-07-31-FRONTDECL`. The batch this file
> used to open (migrations 1-9, the five front guards, T5) is DONE — read PROJECT_STATE.md §2 top
> entry for what it found, not this file, which would only repeat it. Paste the block below as the
> first message of the new session.

---

```
Batch closed 2026-08-01: ORDER-670 (all 9 migrations, T7 = 5/5 bound, 0 suspended) ·
ORDER-674 (all six front guards declare `# snapshot:`, checked by a new L3 lint) · T5 collapsed.
HEAD = <run git log --oneline -1> · tier = 16 suites, 78.9s of 90.0s full-tier budget.

Read in this order:
  PROJECT_STATE.md  §2 top entry (what the batch found) + §3 (decision log, unchanged this batch)
  docs/GUARD_SHAPES.md  (still the pre-flight for writing OR REPAIRING any guard)
  AGENT_TASKBOARD.md — grep '## ORDER-670' and '## ORDER-674' for the full evidence

What's actually open (checked before writing this, not assumed):
  1. ORDER-701 — [CFG] fingerprint emission. Parked until an MT5 lane is reserved: needs a
     generated enumeration in ea_template/core/ + tpl_regression CLEAN on a pinned lane.
     Nothing else in the S6/S5 tranche is open.
  2. Five NON-front-guard PowerShell checkers still print in L3's suspension list every run
     (`check_block_staleness · check_stale_binaries · check_taskboard_archive ·
     check_template_dependencies · check_truncated_run`) — read the live line, don't trust this
     one: `tools/python312/python.exe _triage/factory_os/run_guard_shape_lint.py` prints
     "L3 PowerShell snapshots : N of 11 declared; K still suspended". These are NOT run by the
     hook before the tier, so they were out of ORDER-674's scope — migrating them (if ever) is a
     new order, not a continuation of this one.
  3. The 4 items in _triage/USER_DECISIONS_PENDING.md (Core Universe v1 membership ·
     AGENTS.md §2 writer surface · the account|magic §0.5-vs-global contradiction ·
     the ~10,000-combination budget) — owed to the owner, untouched by this batch, still pending.

Rules that still hold (unchanged from before, restated because they are still true):
  - Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before anything.
    Parse `## ORDER-<n>` from all four board files yourself — do not trust the ledger's
    foot-of-file summary bullets (stale for the ninth time as of this writing, BACKLOG-D29).
  - Budgets are enforced: 65s per-path / 90s full tier. Over budget = the commit is REFUSED.
    If a new cage tips it, displace or make faster — raising the number needs its own measured
    justification in the same commit. (This batch hit the budget twice — a PowerShell
    declaration widening what a fixture selects, and a per-call digest cost — and fixed the
    cause both times rather than raising the number.)
  - A repair is writing a guard: run docs/GUARD_SHAPES.md's pre-flight on it too (shape 5).
    Every fix in this batch that touched a test file added BOTH the attack (red before the fix)
    and the specificity/engagement half (green afterwards, and the suspension line moves).
  - Never git add -A. Commit path-limited. Dirty/untracked files outside this batch's scope
    must stay untouched.
  - Never use git stash to compare revisions: `git show HEAD:path > scratchpad/` instead.
  - `"a" + "b" -f $x` formats only the LAST fragment — parenthesise the whole string. (Recurred
    THIS batch, in a test assertion written to prevent a cost regression — caught only because
    the case was driven red rather than reasoned red.)
  - Codex quota is out. Fable = /fable-advisor only, never batch labour.
  - factory/universe.jsonl must not be created until the owner re-attests D1.

Owed to the owner, do not decide these (unchanged, none block anything currently open):
  the 3 items in _triage/USER_DECISIONS_PENDING.md listed above (item 4, the ~10,000-combination
  budget, may already be folded into one of the other three — re-check the file, don't assume).
```

---

## What this batch proved that the next session should not re-derive

| fact | evidence |
|---|---|
| a bare `open()` declaring a snapshot is not the same as reading the right one | `check_order_collision`/`check_handoff_contract` both read git already and both had a mixed-vintage defect anyway — declaring is necessary, not sufficient |
| a single invariant can have two guards, dead for unrelated reasons | `check_state` (A7, working tree) and `check_precommit_staged` (`^d+$`, matches nothing) both guard `account\|magic` uniqueness; fixing one did not reveal the other |
| "collapse the split" in a design doc can be stale the moment nobody builds the missing wiring | T5 said "collapse the split ⇒ the monitor suite goes RED"; `observe()` had no caller at all, so there was no split to collapse until the duplicate was found and routed through it |
| a migration that changes *behaviour* (not just *location*) needs its own before/after, not a refactor's | ORDER-670 9/9 and the s2a attestation digest migration both required driving the pre-migration code on the same fixture to prove the change was real |
| a lint built to check a class of defect should be built before the fixes it will check, not after | L3 landed as its own commit before any of the five guards were annotated |

## The failure shapes this batch actually produced (watch for them again)

1. **A fixture's cheapness is an undeclared assumption about someone else's table.** PART 6 of
   `run_guard_trigger_tests.ps1` staged a "cheap" file for its nested tier runs; a later
   declaration elsewhere made that file select an 18s suite, and PART 6 went 7s → 113s. The
   fixture never claimed to be cheap in a checkable way — it just was, until it wasn't.
2. **A caching layer keyed on the wrong thing recreates the bug it exists to prevent.** A digest
   cache keyed on nothing (or on the wrong argument) is a guard caching the value it watches —
   this repo already has the ORDER-670 4/9 instance of this and nearly repeated it in the s2a
   digest cache; keying on the source *object* rather than a derived key kept the ATTACK and
   SPECIFICITY cases discriminating.
3. **A source-string match is not a behavioural test.** Both `_stat_evidence` audit cases (S3,
   P0) had checked for `'os.fstat(fh.fileno())' in source` since they were written — never once
   driving a real mid-read mutation. Neither was wrong, but neither had ever been *seen red for
   its own reason* (GUARD_SHAPES: "have I seen this red, for this reason?"). Added this batch.
