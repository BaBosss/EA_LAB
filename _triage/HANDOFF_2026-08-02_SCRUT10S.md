# HANDOFF — lane `S-2026-08-02-SCRUT10S` · four `/scrutinize` rounds over slice S10

> ⚠️ canonical entry = [`PROJECT_STATE.md`](../PROJECT_STATE.md) · this file owns: **what four
> adversarial rounds over `ORDER-1100` found, what changed, and the one question that is the
> owner's — nothing else.**
>
> **Numbers policy:** where a suite prints a count, this file names the suite. Round 4 exists
> partly because that rule was broken by the session that wrote it down.

## What was audited

Slice S10 as it stood at `8f43e0a3` — `candidate.py` · `attestation.py` · `magic.py` ·
`gen_magic_allocations.py` · `scripts/lib/magic_guard.ps1` · `check_state.ps1`'s global-magic flip —
plus `scheduler.py`, because ORDER-1100's step 0 changed the `ExecutionKey` shape and stored data
was already written in the old one.

**Six defects across four rounds. Every one reproduced and printed before it was touched, with a
read-only probe. No manifest was edited: the store is append-only and round 1 is about reading it.**

## The rounds

| round | commit | the defect |
|---|---|---|
| 1 | `1dea1201` | **criterion 3 had failed OPEN on the real store** — and the silent skip that did it was argued for in a comment |
| 2 | `7f6e695e` | the **first** candidate assignment needed no authorization, while *moving* one did; and a `FROZEN` event did nothing at all |
| 3 | `1f245d2b` | `C9` turned "I cannot check this pin" into "checked, fine"; `read_manifest`'s default could never succeed |
| 4 | `cb711d09` | `gen_magic_allocations.py` was a declared trigger nothing ran; its number was restated in four places instead |

The `ORDER-1100` board row carries each one in full, with the measurements. What follows is only
what generalises.

## The three lessons

- 🔴 **An unreadable input rendered indistinguishable from a satisfied rule — three times, in one
  slice.** `find_cached`'s `continue` (round 1), `C9`'s `if f in key` (round 3), and
  `[AllowNull()][string]` coercing `$null` to `''` (found during the S10 build itself). **Two of
  the three were in code written to close that exact family.** When a guard cannot read its input,
  the only safe answer is a refusal; "skip and carry on" is the shape, whatever the mechanism.
- 🔴 **A comment that argues a skip is safe deserves more suspicion than one that says nothing.**
  Round 1's `continue` carried *"safe in the blocking direction: an uncomparable run never licenses
  a re-run, it just fails to block one"* — a sentence that is correct in isolation and backwards
  for the gate it lives in, because criterion 3's entire job **is** to block. The reasoning was the
  defect; the code was doing what it said.
- 🔴 **A migration must be a closed declaration, not a rule.** `LEGACY_DROPPED_KEY_FIELDS =
  ('ini_hash',)` is safe precisely because it is a tuple tied to a recorded owner decision. "Drop
  fields you do not recognise" would let every future key-shape drift launder itself as a
  migration; an unknown field outside the tuple, and a missing required field, both still refuse —
  and both are driven.

## ✅ The one question — ANSWERED 2026-08-02: option (a), `FROZEN` is a marker and forbids nothing

<sub>Recorded as `_triage/USER_DECISIONS_PENDING.md` item 8. What shipped already **was** (a), so no
code changed; the reasoning below is kept because it is what the decision was made against, and
because (c) is the honest upgrade path if it is ever revisited.</sub>

**What should a `FROZEN` attestation event forbid?** Today: nothing. `fold` computed a `frozen`
flag and `validate_event` never read it, so a `CANDIDATE_REASSIGNED` appended directly after a
`FROZEN` was allowed. The flag was **removed rather than enforced**, deliberately:

- The design states no semantics for `FROZEN` beyond it being an authorized event type.
- The obvious guess — refuse every later candidate change — **has no way back out**: there is no
  unfreeze event type, so a single `FROZEN` would make a pair permanently unmovable. That is worse
  than not having the rule.
- Leaving a `frozen` flag nothing reads is a read-model describing enforcement nobody performs,
  which the next caller will read as a rule.

Three options, if you want one: (a) leave it descriptive, as now — `FROZEN` is a marker in the
history and nothing more; (b) `FROZEN` blocks a candidate change by `claude`, and only `user` may
move it afterwards; (c) add an `UNFROZEN` event type and make `FROZEN` block everything until it
arrives. **(a) is what is shipped**; (b) and (c) both add rules the design has not asked for.

## What did NOT change

- No manifest under `factory/runs/` was edited. The round-1 fix reads the old shape; it does not
  rewrite it.
- No `CandidateManifest` issued, no attestation event appended to a real deployment, no magic
  allocated, renumbered or retired, no deployment auto-updated.
- No new order opened — findings landed on the `ORDER-1100` and `ORDER-1080` rows.
- No EA verdict, no MT5 lane, no `.set` touched.

## Baseline at close — re-run after the last commit

`run_scheduler_tests.py` · `run_parity_tests.py` · `run_wrapper_gen_tests.py` ·
`run_guard_shape_lint.py` · `run_s10_tests.py` · `run_schema_fixtures.py` ·
`check_param_surface.py --worktree` · `check_wrapper_gen.py --worktree` ·
`check_schema_structure.py` — **all exit 0**. `check_state.ps1` **CLEAN**. Full fast tier
**24 suites, 0 failed, 106.9s of the 120.0s budget**.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| round 1: criterion 3 fail-open on the real store, the closed legacy migration, `UNCOMPARABLE_PRIOR` | ORDER-1080 (DONE — the defect was in S9's `find_cached`, exposed by ORDER-1100 step 0) |
| round 2: the inverted `A6` first-assignment rule | ORDER-1100 (DONE) |
| round 2: what `FROZEN` should forbid | **DECIDED 2026-08-02 — option (a), a marker that forbids nothing** (`USER_DECISIONS_PENDING.md` item 8; what shipped already was (a), so nothing further is owed) |
| round 3: `C9`'s vacuous pin check, `read_manifest`'s impossible default | ORDER-1100 (DONE) |
| round 4: `gen_magic_allocations.py --check` now driven, and can fail | ORDER-1100 (DONE) |
| round 4: the restated allocation count, removed from four documents | ORDER-1100 (DONE) |
| speed or displace `run_contract_binding_tests` · `run_front_guard_evidence_tests` · `run_guard_trigger_tests` — 65% of the full tier | **ORDER-1130** (opened 2026-08-02 with the owner's ratification of the raise — the raise and this row were decided together) |
| the raised tier budgets (per-path 90.0 · full 120.0) | **RATIFIED 2026-08-02** — `USER_DECISIONS_PENDING.md` item 9 |
| S11 Control Center shell | **ORDER-1131**, assigned to Codex/Sonnet per design §10; brief = `_triage/PROMPT_NEXT_SESSION_S11.md` |
