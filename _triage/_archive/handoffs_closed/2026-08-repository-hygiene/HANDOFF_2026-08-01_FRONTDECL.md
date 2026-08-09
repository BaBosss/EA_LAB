# HANDOFF — lane `S-2026-07-31-FRONTDECL` (2026-07-31 22:2x → 2026-08-01), block 710-719

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item below has a home on the board or in
> `_triage/USER_DECISIONS_PENDING.md` — the routing table at the bottom says which.
> Opening prompt for the next session = **`_triage/PROMPT_NEXT_SESSION_GUARDS.md`**.

## What this lane was asked to do

Finish `_triage/PROMPT_NEXT_SESSION_GUARDS.md`'s four owed items from the previous batch:
the five front guards that read git but declared nothing · `ORDER-670` migration 9/9 ·
`check_s2a_attestation` · T5's collapse-the-split half. All four are done, plus three rounds of
`/scrutinize` over the result.

## The one-line state

**`T7 category-A binding: 5 of 5 checker(s) bound to read_committed; 0 still suspended`** — read
that from `run_guard_shape_lint.py`'s own output, not from this file. `ORDER-670`'s migration set
is complete; `ORDER-674`'s owed half is complete for all six guards the hook runs before the tier.

## What was found (not what was built — the build is in the commits)

Six real defects, each proven by driving the pre-fix code, not by reading it:

| # | where | the defect | how it was proven |
|---|---|---|---|
| 1 | `check_order_collision` | RULE 1 read the active board at the **index** and the archive at **HEAD** — one verdict, two moments (A2). A commit adding `## ORDER-X` to *both* boards created the duplicate the rule exists to refuse, invisibly. | staged `ORDER-711` into both boards in one commit: pre-fix `exit 0`, post-fix `exit 1` naming it |
| 2 | `check_handoff_contract` | Identical mixed pair, **opposite symptom**: it REFUSED the same-commit archive move `WORK_LIFECYCLE` mandates (`REVIEWED* = archive it immediately, same commit`). A guard refusing the workflow it enforces. | pre-fix `exit 1`, post-fix `exit 0`; an unresolvable id still blocks in both |
| 3 | `check_precommit_staged` | `$_.magic -match '^d+$'` — a lost backslash. **0 of 64 rows** ever matched, so the ORDER-144 duplicate-`account\|magic` rule over the live-money inventory has been dead since `baa1b6f5`. A **second** guard on that invariant, dead for a *different* reason than `check_state`'s A7 — which is why fixing the first revealed nothing about it. | measured against the real CSV; attack + specificity cased |
| 4 | `check_s2a_attestation` | `bundle_digest()` read the disk unconditionally. Stage a bundle-member change behind a clean worktree copy and the digest recomputes to the OLD value, so the owner's approval still validates against a bundle the commit is changing. | `df385139…` + `LOG VALID` exit 0 pre-fix vs `855a647c…` + F1 refusal exit 1 post-fix |
| 5 | same | The untracked-log fallback was labelled *"nothing staged to judge"*. Control only reaches it when `committed` is non-empty — i.e. **HEAD has the log and the index does not**: the commit is *deleting* append-only history, and it read the disk instead. | staged content of an absent path is empty ⇒ the existing G5 prefix rule refuses it; no new criterion invented |
| 6 | `evidence.observe()` | **Zero production callers.** `snapshot_build._stat_evidence` had reimplemented its exact one-handle/two-fstat mechanism under another name — so T5's prescribed red half ("collapse the split") could not fire: there was no split, only a duplicate. | routed through `observe()`; first-ever *behavioural* drive of the race (patched `os.fstat`), where only a source-string match existed |

## What `/scrutinize` then found in my own work (3 rounds)

**This is the part worth reading.** One blocker, shipped and then caught:

- **BLOCKER — the T5 collapse changed behaviour for an input it never looked at.** `observe()`
  raises for *two* things ("it moved under me" / "I could not open it") and `ToolFailure` is not
  an `OSError`, so `_stat_evidence`'s outer `except (IOError, OSError)` silently stopped covering
  the second. An **unreadable** mandatory source went from `read_ok: False` →
  `MANDATORY_SOURCE_UNREADABLE` to **refusing the whole build**, with a message blaming a mid-read
  mutation. It broke that function's own docstring (*"Never raises for a bad path"*). Fixed with
  `evidence.ObservationUnstable(ToolFailure)` — a subclass, because message matching is not a
  contract — and both directions are now cased.
- **MAJOR — the cage mutated the two shared boards on disk.** B/C staged by writing
  `AGENT_TASKBOARD.md` / the archive and restoring in `finally`: fine for exceptions, useless
  against a hard kill, on the files every lane writes. Now staged through the object database
  (`hash-object -w` + `update-index --cacheinfo`) — no window, no restore. Both attacks re-proven
  red under the new mechanism, because staging that quietly stages *nothing* leaves both cases
  green for the wrong reason.
- **MAJOR — the lint's own reason strings rotted inside one session.** All eleven read
  *"(L3 covers it once PS_PENDING releases it)"*; six were released the same day. Removed — the
  status is derived and printed every run. `BACKLOG-D29`, produced and caught in one batch.
- **NIT** — L3 mis-parsed PowerShell's backtick escape (latent: 0 instances today).
- **NIT** — the D0 fixture indexed the magic column by position; derived from the header now.

## Numbers, all measured this session

| | |
|---|---|
| lint self-test | **57/57** (was 24 before this lane) |
| `T7` binding | **5 of 5 bound, 0 suspended** |
| `L3` PowerShell | **6 of 11 declared, 5 suspended** — the 5 are *not* front guards |
| full tier | **16/16, 81.3s / 81.8s** of the 90.0s budget (two clean runs), was 78.9s |
| S2a gate | 7/7 · conformance 54/54 canonical · snapshot_s4 69/69 · registry 118/118 · monitor 85/85 |
| owner signatures spent | **0** — verified: bundle digest byte-identical before/after |

## Live traps confirmed this session (do not re-learn these)

1. **The tier budget fires, twice.** Once when a one-line glob declaration made a *fixture* select
   an 18s suite (PART 6 went 7s → 113s); once when six `git show` spawns per digest × ~30 calls
   added 14s. Both fixed at the cause; the number was never raised.
2. **`"a" + "b" -f $x` formats only the LAST fragment.** Recurred *this batch*, inside an assertion
   written to prevent a cost regression — caught only because the case was driven red, not reasoned
   red. Parenthesise the whole string.
3. **A fixture's cheapness is an undeclared assumption about someone else's table.** PART 6's
   "cheap" staged path stopped being cheap when an unrelated declaration changed. It is asserted now.
4. **A cache keyed on the wrong thing recreates the bug it prevents.** The s2a digest cache is keyed
   on the *source object*, so the ATTACK (tampered index ⇒ different digest) and SPECIFICITY
   (index==worktree ⇒ same digest) cases still discriminate.
5. **A source-string match is not a behavioural test.** Both `_stat_evidence` audit cases had
   checked `'os.fstat(fh.fileno())' in source` since they were written and had never once driven
   the race.
6. **🔴 Closing your own ledger row before your last commit makes `check_order_collision` RULE 2
   VACUOUS.** This lane marked itself `CLOSED`, then kept committing. RULE 2 reads the ledger from
   **HEAD** and enforces reserved blocks only for rows whose status is `ACTIVE` — with none, it
   prints `NOTE: no ACTIVE lane ... reserved-block and owned-path rules skipped` and passes.
   `ORDER-710` was opened under exactly that condition. The number is legitimate (this lane
   reserved 710-719 in `4ecc07bf`), so the *outcome* is right — but the guard did not verify it,
   and a PASS that skipped its rule must not be quoted as one that ran it. **Close the lane row in
   the LAST commit, not before.** Not filed as an order: it is a sequencing rule, and it is
   written here and in the opener rather than turned into a code change nobody asked for.

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| `[CFG]` fingerprint emission (needs a generated enumeration in `ea_template/core/` + `tpl_regression` CLEAN on a pinned MT5 lane) | ORDER-710 |
| Five non-front-guard PowerShell checkers still suspended in L3 (`check_block_staleness` · `check_stale_binaries` · `check_taskboard_archive` · `check_template_dependencies` · `check_truncated_run`) — out of ORDER-674's scope, would be a NEW order, not a continuation | DONE |
| Everything else this lane opened (five front guards, migrations 9/9 + s2a, T5) | DONE |
| Core Universe v1 membership · `AGENTS.md` §2 writer surface · the `account\|magic` §0.5-vs-global contradiction · the ~10,000-combination budget | DONE |

<sub>The last two rows are `DONE` in the routing sense — they carry no work *this lane* owes. The
five suspended checkers are named in the lint's printed output on every run, so they are a
countable list, not a silence; and the four owner decisions live in
`_triage/USER_DECISIONS_PENDING.md`, which is their owner. Neither is a forward-looking item this
lane is handing to anyone — recording them here so the next reader does not re-derive that.</sub>

## Do not do these

- ❌ Do not "tidy" the remaining `HEAD:` reads in `check_order_collision` to `:`. Two are
  deliberate and both would break: the *baseline* that defines "what this commit ADDS" (RULE 2
  would see zero new orders and could never fire again), and the **ratified** ledger read
  (Decision log 2026-07-26 — at the index, one commit could reserve a block and spend it).
- ❌ Do not add a cage without measuring the tier. 8.2–8.7s of headroom remain on the full tier.
- ❌ Do not touch the six S2a bundle files to "fix" a lint finding — that costs an owner signature.
  `check_s2a_attestation.py` itself is OUT of its bundle (ORDER-614 rev 2), which is why this
  lane's migration was free.
