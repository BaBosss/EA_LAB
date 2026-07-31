# Next-session prompt — five undeclared front guards + migration 9/9

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the opening prompt for the
> session that finishes the evidence migrations**. Written 2026-08-01 at the end of lane
> `S-2026-07-31-FRONTGUARDS`. Paste the block below as the first message of the new session.

---

```
Batch: ORDER-671/672/673/674/700/702 DONE · ORDER-670 migrations 8.5/9 · tier = 16 suites,
budgets ENFORCED (65s per-path / 90s full) · HEAD = <run git log --oneline -1>
check_state now judges the COMMIT (proven: a staged duplicate account|magic behind a clean
worktree was CLEAN before, is RED now) and exits 2 when it cannot read its own inputs.

Read in this order:
  PROJECT_STATE.md  §2 top entry + §3 (three rules ratified 2026-07-31)
  docs/GUARD_SHAPES.md  (five shapes; shape 5 = a repair graded by the finding it closes)
  AGENT_TASKBOARD.md — ORDER-674 and ORDER-670 rows (grep '## ORDER-67')
  scripts/lib/evidence.ps1  (the PowerShell reader — read its header, it carries the contract)
  _triage/factory_os/evidence.py  (the python reader, same contract)

Task, in priority order:
  1. The five front guards that read git but DECLARE NOTHING: check_precommit_staged ·
     check_order_collision · check_handoff_contract · check_experiment_events ·
     check_verdict_kill. Per guard, one commit: annotate every read with `# snapshot:`
     checked against what the code actually does (five of them already read index/HEAD —
     the work is making deliberate-vs-accident distinguishable, not rewriting). Where a
     read is WRONG (worktree where the commit is judged), fix it through
     scripts/lib/evidence.ps1 with ORDER-674's attack shape: stage the corruption via a
     TEMP INDEX (GIT_INDEX_FILE on a copy — never .git/index, T6 refuses that), restore,
     assert byte-identical. run_front_guard_evidence_tests.ps1 is the template.
  2. ORDER-670 migration 9/9: check_coverage_transfer.read_input → evidence.EvidenceSource.
     It is a BEHAVIOUR change (evidence.py refuses untracked-in-hook-mode rather than
     falling back — the Spec4 lesson), so it is its own commit with its own attack.
     Clearing its line from A_BINDING_PENDING in run_guard_shape_lint.py is the
     engagement half: the lint's T7 count must go "2 still suspended" → "1".
  3. check_s2a_attestation migration — CAREFUL: it sits in the attestation bundle's blast
     radius; run run_s2a_gate.py before AND after, and do not spend an owner signature.
  4. T5's collapse-the-split red half (belongs to the snapshot_build migration; small).

Rules that must hold:
  - Reserve a lane in docs/SESSION_LEDGER.md and COMMIT the reservation before anything.
    Block 700-709 was reserved three times by closed lanes and ORDER-700/702 are spent
    from it; parse `## ORDER-<n>` from all four board files yourself. Do not trust the
    ledger's foot-of-file summary bullets (stale eight times).
  - The lint's derived line is the truth about migration status — read
    `T7 category-A binding: N of M bound; K suspended` from run_guard_shape_lint.py's
    output, not from any board paragraph (a board paragraph was wrong within two commits).
  - A guard's green means nothing until seen red for its own reason. Every fix commit
    carries the attack AND the specificity/engagement half (GUARD_SHAPES shape 5).
  - Budgets are enforced: 65s per-path / 90s full tier. Over budget = the commit is
    REFUSED. If a new cage tips it, displace or make faster — raising the number needs
    its own measured justification in the same commit.
  - Never git add -A. Commit path-limited. ~267 dirty/untracked files must stay.
  - Never use git stash to compare revisions (memory never-stash-to-compare-revisions):
    `git show HEAD:path > scratchpad/` instead.
  - `& git` under $ErrorActionPreference='Stop' turns git WARNINGS into terminating
    errors (the CRLF warning fires on every add of DEPLOYMENTS.csv). Use
    Invoke-EvidenceGitBytes from scripts/lib/evidence.ps1.
  - `"a" + "b" -f $x` formats only the LAST fragment — parenthesise the whole string.
  - Codex quota is out. Fable = /fable-advisor only, never batch labour.
  - factory/universe.jsonl must not be created until the owner re-attests D1.

Owed to the owner, do not decide these (unchanged, none block this work):
  the 4 items in _triage/USER_DECISIONS_PENDING.md (Core Universe v1 membership ·
  AGENTS.md §2 writer surface · the account|magic §0.5-vs-global contradiction ·
  the ~10,000-combination budget).

Parked until an MT5 lane is reserved: ORDER-701 ([CFG] fingerprint — needs a generated
enumeration in ea_template/core/ + tpl_regression CLEAN on a pinned lane).
```

---

## What this batch proved that the next session should not re-derive

| fact | evidence |
|---|---|
| `check_state` judged the worktree over the live-money inventory | staged duplicate `account|magic` ⇒ `CLEAN` pre-fix, RED post-fix (`cf6453ad`) |
| the design's grep = zero *declarations*, not zero *problems* | `TIER_SNAPSHOT_DESIGN.md` §1 W2 table |
| T6 refuses a suite that writes `.git/index` — correctly | the front-guard cage was refused by its own tier until it moved to a temp index |
| a budget corrected by firing is working, not broken | 75→90 (growth itemised), 30→65 (multi-file selection), both in `7e88c028` |
| a board paragraph about migration status rots in ~2 commits | "three migrations remain" named three that had landed; the lint's derived line replaced it |

## The three failure shapes this batch actually produced (watch for them again)

1. **A counter nobody reads.** `$toolFail` existed, incremented, and reached no exit path —
   found only by breaking a read and watching the run stay CLEAN.
2. **A migration narrower than its own claim.** "check_state migrated" while two of its
   sections still enumerated from disk. State the partial half or finish it.
3. **A test that dies inside its own restore window.** `& git` + `$ErrorActionPreference
   ='Stop'` + a warning git always emits = the suite killed between staging the attack and
   restoring the inventory. Anything that mutates real state must prove its restore ran.
