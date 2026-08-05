# HANDOFF — lane `S-2026-08-01-PINFIX` (2026-08-01, after `S-2026-08-01-CFGFP`), block 760-769, no MT5 lane

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item below has a home — the routing table at
> the bottom says which. Opening prompt for the next session =
> **`_triage/PROMPT_NEXT_SESSION_PINFIX.md`**.

## What this lane was asked to do

`_triage/PROMPT_NEXT_SESSION_CFGFP.md` said the **first thing to do** was get the owner's decision
on `ORDER-731`, because `HEAD` was red and every commit selecting `run_contract_binding_tests.ps1`
was refused. That was done first, before touching anything.

## The one-line state

**The gate is green, the commit that broke it twice is now refused BEFORE it lands, and the commit
that repairs it still lands.** Read it from `.githooks/pre-commit`'s own output, not from this file.

## The owner decision, and why it was the first act

`MASTER_BACKLOG.md` was at `0740c0ea` against the pinned `02c1d0ed`. Three options were put to the
owner with their costs; the owner chose **revert the `D33` row and pay one `--no-verify`**.

* `b0637b8a` restores the file to `02c1d0ed` — verified by quoting `git rev-parse :MASTER_BACKLOG.md`
  in the commit message, and byte-identical to `8d5bb2ed:MASTER_BACKLOG.md`.
* `check_coverage_transfer` and `check_s2a_attestation` both returned **exit 0** straight after.
* **`D33` is not lost and is not duplicated anywhere:** `git show 78a93129:MASTER_BACKLOG.md | grep '^| D33 |'`.
* **Debt this leaves:** lane `S-2026-08-01-OPERATE`'s handoff routing table points at a row that is
  not on the board. That is documentation debt, **not a red gate** — `check_handoff_contract` judges
  only a handoff that is *staged*, and theirs is already committed. It becomes a red gate the moment
  anyone re-stages that file.

## `ORDER-731` item 1 — what landed, and the half that is easy to get wrong

New front guard `_triage/factory_os/check_attested_pin_staged.py`, wired into `.githooks/pre-commit`.
It reads the **index** and asks whether the paths an in-force attestation record pins will still hold
the pinned blob after this commit.

**Proved end-to-end through the REAL hook, not a fixture.** A real `git commit` appending a row to
`MASTER_BACKLOG.md` printed
`P1 … would land at blob abd339ba793e, but the attestation record in force pins it at 02c1d0edfa91`
and was refused; `HEAD` unchanged. The marker line records
`git_index=…/next-index-28508.lock` — it judged the **partial commit's own temporary index**, which
is precisely the snapshot that was invisible to the front-guard suite and cost `ORDER-710` a refused
commit.

**And the half a naive guard gets wrong:** the REPAIR commit still lands. A guard that refused any
touch of the pinned path would have rebuilt the exact trap. That is a `CONTROL` case in the cage, and
mutation 3 proves the case can fail.

**Nothing in the attestation bundle was touched.** `F5`/`F11` keep their `HEAD` semantics on purpose:
`S2A_ATTESTATION_POLICY.md` states them and is a bundle member, so moving them there voids the
owner's record and costs a signature for a repair that changes no rule — the loop `ORDER-614` rev 2
exists to end. `run_s2a_conformance.py` reproduces **every canonical vector** afterwards, which is
what proves no signature is owed.

## The part worth reading: three findings, two of them about my own work

1. **`C1`'s answer is BOTH, and only half of it was mine to land.** Reading the pin at the index is
   right and is done. The pin is **also the wrong instrument**: `MASTER_BACKLOG.md` took **30 commits
   in 14 days** (45 in 60). At ~2.1 writes/day a whole-file blob pin means ~2 owner signatures a day
   — the guard changes *when* the author finds out, not *how often*. Narrowing the pin is a **policy**
   change and the policy is inside `bundle_sha256`, so it is the owner's → `_triage/USER_DECISIONS_PENDING.md`
   **item 5**, with three costed options.
2. **My own ledger row disarmed my own lane's guard rails, twice, in two different ways.** →
   `ORDER-760`. Read that row before writing yours; details in "live traps" below.
   **And a third self-inflicted one, found by `/scrutinize`:** nothing in the cage proved the guard
   reads the INDEX — mutating `_index_source` to a worktree source left all eleven cases green.
   Shape 1 inside the guard written to close a shape-1 defect. Closed with an index-vs-worktree
   DIFFERENTIAL (a mode-string assertion would have been shape 2). Detail in the `ORDER-731` row.
3. **`ORDER-732` was closed by measuring it rather than by doing it.** 64 new declarations, and a
   **35.8×** selection-cost increase on the most common commit shape in this repo (and the widened
   `DEPLOYMENTS`/`PARAM_REGISTRY` commits land at 42-45s against a **65s per-path budget**). More decisive than
   the cost: the sweep is a text scan and **cannot tell a path a module READS from one it MENTIONS**.
   → `DEAD-OPTIMIZED` under its own `C3`, with `ORDER-761` opened for the mechanism that converges.

## Live traps confirmed this session

1. **🔴 A ledger cell is PROSE and the guard's INPUT, with nothing marking where one ends.** Two
   instances, both in this lane's own reservation row, both found by probing the guard rather than
   by review:
   * a literal `|` inside backticks (`` `| D33 |` ``) split the row into **12 cells instead of 8**,
     so the status column was read from the wrong cell. The guard printed *"NOTE: no ACTIVE lane …
     reserved-block and owned-path rules skipped"* and **passed**. Two commits were made with RULE 2
     and RULE 3 unarmed. Nothing was breached — that is luck, not the guard working.
   * naming another lane's block **in prose, to say it was being declined**, reserved it: *enforcing
     reserved block(s): 760-769, 750-759, 760-769*. Then the first repair — a warning sentence quoting
     those numbers — added a fourth. **The text explaining the trap re-triggered the trap.**
   * **Rule, stated as a rule rather than as a symptom:** that cell is parsed; **every number-looking
     token in it is data.** Do not cite a block number there, not even to say you are not taking it.
     `ORDER-675`'s warning was about a *character class*, which is why reading it did not save me.
2. **The collision guard reads the ledger at `HEAD`, deliberately** (Decision log 2026-07-26, so one
   commit cannot reserve and spend a block). Consequence when you repair the ledger: **your repair
   commit still prints the pre-repair diagnosis**, because HEAD is the previous commit. Verify the fix
   with the guard's own offline entry points (`-LedgerContent`, `-StagedActiveContent`,
   `-StagedFileList`) instead of reading the next hook run and believing it.
3. **`git add` before `git commit -- <paths>` — again.** A new file is *untracked* until added, and
   `run_guard_trigger_tests` PART 4/5 check declared inputs with `git ls-files`. Declaring
   `check_attested_pin_staged.py` before adding it produced 4 failures that were about git, not code.
4. **A guard-shape lint that catches its author is the system working.** `L0` demanded the new checker
   on its first run — the **fifth** consecutive time it has named an addition the author had not
   declared — and then `T7` demanded a `CATEGORY` entry. Both were 30-second fixes *because* they
   fired at write time.

## Numbers, all measured this session

| | |
|---|---|
| `ORDER-731` cage | **13 cases** — ATTACK 6, CONTROL 1, ENGAGEMENT 2, SPECIFICITY 4 (counted from the run) |
| mutation probes | **4 of 4 DETECTED**, each by the case written for it |
| front guard cost | **197–198 ms** per commit, 3 runs · the CAGE went 197 → **232–237 ms** once it began spawning git |
| full tier | **16/16**, four samples spanning **74.2–77.8s** of 90.0s. Reported as a RANGE: the spread is run-to-run variance, and the `/scrutinize` additions cost ~40 ms, which does not account for it |
| conformance corpus | **every canonical vector reproduced** after the refactor ⇒ no owner signature owed |
| lint | `T7` **7 of 7 bound** (was 6 of 6) · `L3` **6 of 11**, 5 suspended, unchanged |
| `ORDER-732` widening | **64** new declarations · **35.8×** on the most common commit shape — first reported as 66, corrected by `/scrutinize`: the first pass measured with a **wider regex than the sweep it was measuring** (shape 4, in the number used to close an order) |
| `MASTER_BACKLOG.md` write rate | **30 commits / 14 days** (45 / 60) |

## Do not do these

- ❌ Do not append to `MASTER_BACKLOG.md`. It is still pinned; the difference now is that you find out
  at the hook instead of afterwards. Restoring `D33` needs the owner's item-5 decision first.
- ❌ Do not edit any attestation **bundle** member to make something pass — that costs a signature
  (`ORDER-614` rev 2). The implementation `check_s2a_attestation.py` is **out** of the bundle; the
  POLICY and the VECTORS are **in**.
- ❌ Do not cite a block number in the ledger's order-block cell. See trap 1.
- ❌ Do not reintroduce `ORDER-732`'s text scan as a "fallback" inside `ORDER-761`. It would make the
  declaration optional, which is the same as not having one.

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| the S2a pin is a WHOLE-FILE blob on a board every lane appends to; narrowing it is a policy change and therefore the owner's (`_triage/USER_DECISIONS_PENDING.md` item 5) · plus restoring the `D33` row, which waits on that decision | ORDER-731 |
| the tier abort that fired in 2 of 8 manual full-tier runs, one instance explained and one not — it did NOT fire in either of this lane's two runs, which is evidence of nothing at n=2 | ORDER-731 |
| a ledger cell is prose AND the guard's input: a literal `\|` shifts every column after it, and citing any block number reserves it | ORDER-760 |
| a module should DECLARE the paths it reads, instead of a regex guessing them — the mechanism `ORDER-732` measured its way out of | ORDER-761 |
| `ORDER-731` item 1 itself (the front guard · its cage · the in-force predicate extraction · the wiring · the end-to-end proof through the real hook) | DONE |
| `ORDER-732` (the C1 measurement, and the decision it forced) | DONE |
| `ORDER-730` — the locked-constant half of design §5.6 — untouched by this lane and unchanged | ORDER-730 |
| the five non-front-guard PowerShell checkers still suspended in `L3`, and items 1-4 of `_triage/USER_DECISIONS_PENDING.md` | DONE |

<sub>The last row is `DONE` in the routing sense only: it carries no work *this lane* owes. The five
suspended checkers are printed by the lint on every run (a countable list, not a silence) and
migrating them would be a new order; items 1-4 of the owner-decisions file live in the file that
owns them, and none of them blocked this work.</sub>

## Other lanes

None were `ACTIVE`. Every ledger row read `CLOSED` when this lane opened, which is why
`run_front_guard_evidence_tests`' B0 probe took its no-ACTIVE-lane branch — the regime
`S-2026-08-01-CFGFP` repaired at the end of its own run.
