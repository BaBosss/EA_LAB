# HANDOFF — lane `S-2026-08-01-PINFIX3` (2026-08-01, after `S-2026-08-01-PINFIX2`), block 780-789, no MT5 lane

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item has a home — the routing table at the
> bottom says which.

## What this lane was asked to do

Execute `_triage/HANDOFF_2026-08-01_PINFIX2.md`: **`ORDER-731` option A** (narrow the S2a pin to
§2 of `MASTER_BACKLOG.md`), direction already ratified as item 5 of
`_triage/USER_DECISIONS_PENDING.md`, up to the one owner signature it costs — with mechanical
reading, drafting and implementation distributed to Opus subagents (the user asked for this
explicitly, and it is the seat's cost rule anyway).

> 🔴 **CORRECTED SAME DAY by lane `S-2026-08-01-PINFIX3B` (`/scrutinize`). Read this box before
> anything below it.** This handoff calls `7baadb18` "the payoff, demonstrated". **That is false.**
> That commit turned the S2a gate RED (`F5 line 8 acknowledges current_blob '02c1d0ed…' but HEAD has
> '0740c0ea…'`), because **`stale_pin_acknowledgement.current_blob` is a SECOND whole-file pin on the
> same file** and option A narrowed only `expected_post_state`. The front guard did not predict it
> (`check_attested_pin_staged.py:165` adds the ack pin only `if path not in pins`, and the section pin
> now takes that slot), so `ORDER-731`'s own C2 was violated by `ORDER-731`'s own fix. **HEAD is red;
> `_triage/factory_os/**` and `MASTER_BACKLOG.md` are uncommittable** (a revert of `7baadb18` was
> attempted and REFUSED). Full trace + the measured recommendation (option 2, `factory/coverage.jsonl`
> = 1 commit/14d vs `MASTER_BACKLOG.md` = 31) are on the `ORDER-731` row and in
> `_triage/USER_DECISIONS_PENDING.md` item 5. Everything below is left unedited on purpose — a
> handoff that is quietly rewritten is not a record.

## The one-line state

**`ORDER-731` option A is LANDED and owner-signed (`212c0555`), proven both ways on the real
hook (`7baadb18` = the payoff commit). Item 2 (the tier abort) got a real investigation, a
corrected wake condition, and stays OPEN. `USER_DECISIONS_PENDING` item 5 is resolved.**

## What landed, in order

1. **Option A, one atomic commit (`212c0555`)** carrying the owner's attestation line 8
   (bundle `e3f83efa`, section pin `8f5aa2e6c115` over `## 2. COVERAGE MATRIX`, both digests
   computed at the INDEX and confirmed verbatim in chat, 13:32). Policy §4.3.1 states the
   fail-closed extraction rule; F12/F13/F14/P4 added, nothing renumbered, no existing vector
   changed (old corpus bytes are a byte-prefix of the new). Full numbers on the `ORDER-731`
   RESULT block: conformance 62/0 · mutation 33 probed 0 INERT · pin cage 21 cases ·
   real-repo suite 46 OK / 0 BAD · lint green.
2. **Both probes:** a tampered §2 in a TEMP index refused with `P1` naming both digests; then
   `7baadb18` restored the `D33` dormant row — byte-identical to the commit the whole-file pin
   refused that same morning — through the REAL hook, guard reporting the section pin held.
3. **Tier-abort investigation (Opus):** the "something inside the tier writes the index"
   hypothesis is contradicted by the tier's own A6 assertion; the better-supported candidate for
   the "unexplained" instance is the OPERATE lane committing 45 minutes after its ledger row was
   CLOSED. The row's wake condition was DEAD (satisfied at the moment it was written) and was
   replaced with one that discriminates. Instrumentation ladder recorded on the row.
4. **This lane's own ORDER-760-class defect, caught by the guard it was landed with:** the ledger
   amendment declaring the D33 restore wrote a raw `|` pair into its own row cell; RULE 4 refused
   the next taskboard commit and **let the repair land** (`a4bf1407`) — the staged-snapshot
   semantics doing exactly what they were built for, one day after they were built.

## Do not do these

- ❌ Do not edit inside §2 of `MASTER_BACKLOG.md` (or run `gen_coverage.py --apply`) without an
  owner signature — that is now the ONLY part of the file that costs one. Appends to other
  sections land normally.
- ❌ Do not rename the §2 heading. The anchor is exact-equality by design; a rename voids the
  section pin and costs a signature.
- ❌ Do not edit any S2a bundle member (policy · vectors · D1 · D2 · reconciliation ·
  `check_s2a_migration.py`) without budgeting the signature — unchanged rule, new digest
  (`e3f83efa`).
- ❌ Do not write a raw `|` in a ledger cell. This lane read the write-up of that exact rule and
  did it anyway; the guard is the thing that catches it, not care.

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| `ORDER-731` option A (policy §4.3.1 · F12/F13/F14/P4 · owner signature · both probes) | DONE |
| `ORDER-731` item 2 — tier abort: corrected wake condition + instrumentation ladder, fires next when a run aborts with no commit inside its own recorded window | ORDER-731 |
| `USER_DECISIONS_PENDING` item 5 — resolved as option A; option 2 (`factory/coverage.jsonl` owner move) noted as the complement if the remaining §2 toll measures too high | DONE |
| the `BACKLOG-D33` number collision (two meanings in one day; pre-`febb11e8` pointers resolve wrong) — recorded on the `ORDER-731` row, no work owed unless a reader trips on it | ORDER-731 |
| a module should DECLARE the paths it reads (unchanged by this lane) | ORDER-761 |
| the locked-constant half of design §5.6 (unchanged by this lane) | ORDER-730 |

## Other lanes

None were `ACTIVE`. `S-2026-08-01-PINFIX2` closed immediately before this one.
