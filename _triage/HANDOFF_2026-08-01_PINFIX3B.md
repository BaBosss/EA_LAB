# HANDOFF — lane `S-2026-08-01-PINFIX3B` (2026-08-01, `/scrutinize` of `PINFIX3`), block 790-799, no MT5 lane

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item has a home — the routing table at the
> bottom says which.

> ✅ **SUPERSEDED THE SAME DAY — the repository is NOT blocked. Do not act on the section below.**
> Everything under this box was true when written and is now history. `ORDER-731` **option 2** landed
> (`c66d5e57`, owner-signed, bundle `d88f795b`) and removed the second whole-file pin this lane discovered;
> all three gates exit **0** at HEAD, and an append to `MASTER_BACKLOG.md` outside §2 passes the front guard
> while an edit inside §2 is refused — both probed. **Forward pointer this file lacked:**
> `_triage/HANDOFF_2026-08-01_OPT2.md` is the lane that resolved it, and
> `_triage/HANDOFF_2026-08-01_SESSION_END.md` is the consolidated state.
> The value that survives here is the DIAGNOSIS — two pins, not one — not the status.

## 🔴 READ FIRST — the repository is in a BLOCKED state and only the owner can clear it

`check_s2a_attestation.py` **exit 1** · `check_coverage_transfer.py` **exit 1** ·
`scripts/_test/run_contract_binding_tests.ps1` **exit 1**. One problem:
`F5 line 8 acknowledges current_blob '02c1d0ed…' but HEAD has '0740c0ea…'`.

**41 of the 62 files in `_triage/factory_os/` are declared in `SUITE_GUARDS` and cannot be
committed, and neither can `MASTER_BACKLOG.md`.** Every file the repair needs is in that 41.
`AGENT_TASKBOARD.md` and `docs/SESSION_LEDGER.md` select other suites and still commit — which is
the only reason this lane could record anything. **A `git revert` of `7baadb18` was attempted and
REFUSED, HEAD unmoved** — the gate blocks its own repair, sixth instance of that family and the
first one to occur *inside the fix for the fifth*.

## What this lane was asked to do, and what it found

`/scrutinize` of `S-2026-08-01-PINFIX3` (ORDER-731 option A), two rounds, fix, handoff, two more.

**The finding, in one sentence: option A narrowed one of TWO whole-file pins on
`MASTER_BACKLOG.md`, so it removed none of the toll it was bought to remove, and the commit written
to demonstrate the payoff is what turned the gate red.**

The second pin is `stale_pin_acknowledgement.current_blob`, enforced by **F5** against HEAD's
whole-file blob and demanded by **F2** because D1 pins the file at `ca909b69` while HEAD is
elsewhere, so **N2 derives a permanent STALE note**. The front guard stopped predicting it the
moment the section pin took the `pins[path]` slot (`check_attested_pin_staged.py:166`,
`if path not in pins` — a precedence that was harmless only while both pins held the same value).

Reached independently twice: by the seat tracing the gate after the fact, and by an adversarial
subagent that started from "defeat the pin" and arrived at the same line.

## What is genuinely sound, so nobody re-litigates it

The extraction rule. Eight attack classes were driven with actual region bytes printed —
boundary truncation, boundary deletion, CRLF, trailing whitespace, six fence variants, indented and
leading-whitespace anchors — and **no digest-preserving change to the approved region was found**.
`extract_section`/F13/F14/P4 behave as documented; the tampered-§2 probe is refused with `P1`.
All five cages are green. **The defect is scope and seams, not the rule.**

## The queue, in the order it must happen

1. **OWNER: unblock HEAD.** Options costed on the `ORDER-731` row and in
   `_triage/USER_DECISIONS_PENDING.md` item 5. Recommended: **do option 2 now** (move the Coverage
   owner from `MASTER_BACKLOG.md` to `factory/coverage.jsonl`) — one signature that both clears the
   red and removes *both* pins, because the file stops being an owner at all. Measured basis:
   `factory/coverage.jsonl` = **1** commit/14d vs `MASTER_BACKLOG.md` = **31**. Fallback if that is
   too large for one session: revert `7baadb18` behind one `--no-verify` (zero signatures, returns
   to the 13:30 state; `D33`'s text stays recoverable at `git show 78a93129:MASTER_BACKLOG.md`).
2. **Then, no signature owed, but unlandable until (1):** five implementation defects, all recorded
   with file:line on the `ORDER-731` row — the front-guard ack/section precedence · the EOF trailing
   newline (**fix the code so the SIGNED policy §4.3.1 step 6 becomes true**, do not amend the
   document) · the BOTH-forms fall-through · the escaping `ToolFailure` · and
   `run_s2a_conformance.py`'s `assert len(saved) == 7`, which fires on the CORRECT extension.
3. **Then the cage gap that let all of this ship green:** no case in
   `run_attested_pin_staged_tests.py` carries a section `expected_post_state` **and** a
   `stale_pin_acknowledgement` together — the shape of the record actually in force. That case is
   red today, which is exactly why it must exist.

## Do not do these

- ❌ Do not append to `_triage/factory_os/s2a_attestations.jsonl` without the owner confirming the
  exact line in chat. Unchanged, and the reason is now demonstrated rather than argued.
- ❌ Do not "fix" the EOF-newline mismatch by editing `S2A_ATTESTATION_POLICY.md`. It is a bundle
  member; changing it costs a signature and would make a signed document follow the code instead of
  the other way round.
- ❌ Do not quote `7baadb18` as evidence that the narrowed pin works. It is evidence that it does
  not.
- ❌ Do not re-run the "is the extraction rule attackable" question. It was driven eight ways with
  printed bytes; spend the effort on the seams instead.

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| unblock HEAD, then choose option 2 or accept the toll — the owner's, with the costing corrected | ORDER-731 |
| the five implementation defects (front-guard precedence · EOF newline · both-forms · ToolFailure · assert arity), each with file:line | ORDER-731 |
| the cage gap: no case combines a section pin with an acknowledgement | ORDER-731 |
| `ORDER-731` item 2 — the tier abort, wake condition replaced by `PINFIX3`, untouched here | ORDER-731 |
| a module should DECLARE the paths it reads | ORDER-761 |
| the locked-constant half of design §5.6 | ORDER-730 |
| the section-extraction rule itself — attacked eight ways, no digest-preserving edit found | DONE |

## Other lanes

`S-2026-08-01-PINFIX3` closed immediately before this one; its handoff carries a correction box
rather than a rewrite, on purpose — a handoff that is quietly edited is not a record.
