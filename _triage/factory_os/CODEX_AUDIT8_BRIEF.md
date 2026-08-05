# Blind audit brief #8 — the new sign-off boundary, and whether splitting `UNOWNED` tightened it or just moved it

**This is a narrow follow-up to audit 7, not a repeat of it.** Audit 7 covered the whole S2a slice and
returned NOT DONE; its blocker and all its findings are fixed. Three things it could not review are new
since, and one of them is a **trust boundary written and self-reviewed by the same seat**. That is the
whole reason this brief exists.

**Scope of write permission, stated once so it cannot contradict itself:** you may create or overwrite
**exactly one file**, `_triage/factory_os/CODEX_AUDIT8_2026-07-30.md`, your report. **Everything else is
read-only** — do not modify, stage, or commit any other path, and do not apply any fix you recommend.

⚠️ **The working tree has unrelated modified and untracked files** (MT5 output, `.obsidian/`, YouTube
corpora). **Do not `git add -A`, do not `git stash`, do not `git checkout --` anything.** Stage nothing.
`AGENT_TASKBOARD.md` and `docs/SESSION_LEDGER.md` are declared by the live lane `S-2026-07-30-S2AD1D2`;
read them, write neither.

Repo root: `D:\EA_LAB`. Interpreter: `tools\python312\python.exe` (no system Python).

**On wording, so it is not mistaken for something it is not.** This is quality review of data-validation
scripts and the data files they validate, all inside this one repository. No security dimension, no
external system, no third party. Where the brief asks you to construct an input and run a validator on
it, that is negative testing: does a conformance checker accept inputs that satisfy its letter while
failing the specification's intent?

**On anchoring.** The commit messages for `caf9f18c`, `ea44077e` and `a20476b8` are long and argue their
own case; you will hit them immediately. **Treat every sentence as a claim to falsify.** Two of the three
exist only because the previous commit's self-review missed something. Every judgement in this slice —
the work, three rounds of acceptance amendment, and the verdicts — came from one seat.

---

## 1. What changed since audit 7

Your BLOCKER 1 was reproduced unchanged before anything was touched, then fixed. Your other findings
were accepted; `ORDER-600` was returned to `OPEN` and `ORDER-602` opened for the remainder.

| commit | what it claims |
|---|---|
| `caf9f18c` | audit 7's blocker fixed: C3 eligibility became a **closed declaration**; C7 puts the decision on the Coverage row itself; C8 requires typed, unique, `source_token`-traceable cells; C6 renamed to what it actually checks. Plus 2 data corrections you found by opening citations. |
| `ea44077e` | **ORDER-602 A–E** — the subject of this brief. See §2. |
| `a20476b8` | board + ledger updated to match |

**Deliberately NOT done, so you do not report them as omissions:** the three stale `all_clear` lines in
the design and the seven false `x-enforced-by` names (your MAJOR 6 / MAJOR 7) are accepted and routed to
`ORDER-601` / `BACKLOG-D31`; they are mechanical and need no outside judgement.

## 2. What to review

| file | what it is |
|---|---|
| `_triage/factory_os/check_s2a_signoff.py` | **primary subject** — the new sign-off validator (S1–S6) |
| `_triage/factory_os/s2a_signoff.jsonl` | the append-only decision log the OWNER writes (currently header-only) |
| `_triage/factory_os/run_s2a_signoff_tests.py` | its suite |
| `_triage/factory_os/check_s2a_migration.py` | `OWNER_STATES` / `UNOWNABLE` / C3 / C7 / C8 / `pin_vintage_notes` |
| `_triage/factory_os/s2a_migration.jsonl` | D1, 27 rows |
| `_triage/factory_os/run_s2a_migration_tests.py` | 32 mutations + loader, advisory and drift-guard parts |
| `_triage/factory_os/CODEX_AUDIT7_2026-07-30.md` | your previous report, for what was promised |
| `AGENT_TASKBOARD.md` `ORDER-602` | the acceptance A–E is measured against |

All green, all expected to stay green:
```
tools\python312\python.exe _triage\factory_os\run_s2a_gate.py
tools\python312\python.exe _triage\factory_os\run_s2a_signoff_tests.py
tools\python312\python.exe _triage\factory_os\check_s2a_signoff.py --template
```

## 3. Question 1 (primary) — is the sign-off log a real boundary or a new surface?

`ORDER-602 A` moved the decision out of the proposal so an owner can record `APPROVED` **without editing
any guard, generator or proposal byte**, while `check_s2a_migration.py` C2 keeps refusing `APPROVED`
inside D1. The claimed protections: a decision is bound to `sha256` of D1's bytes; exactly one current
decision per owner; `REFUSED` needs a reason; a stale pin blocks signing.

**The concern is that a signature artifact is a new place for a claim to be manufactured, and it was
designed, built and reviewed by the seat whose work it signs off.** Specifically:

1. **Can a decision be made to appear legitimate without the owner acting?** The log is a tracked file
   anyone with commit access can append to; the "signer" is a free-text string. What does the digest
   actually protect, and what does it not?
2. **Is `proposal_sha256` binding in the direction claimed?** It is computed over D1 only. Consider what
   is *not* covered — D2, the coverage reconciliation, the checker's own rules. If the acceptance rules
   change after a signature, does the signature still read as current, and should it?
3. **Is "append-only" meaningful here?** Nothing enforces it; the last line for an owner wins. What
   happens to an earlier decision that is edited or removed rather than superseded?
4. **S6 blocks signing when a pin is stale.** Is that the right boundary, and is the
   `stale_pin_acknowledged` escape hatch adequately constrained, or is it C4's `owner_ref_absent_reason`
   problem again — a free-text field that grants an exemption rather than explaining one?

## 4. Question 2 — did splitting `UNOWNED` tighten the escape or relocate it?

Audit 7's BLOCKER used one broad `UNOWNED` state. `ORDER-602 B` replaced it with four —
`NO_CURRENT_OWNER`, `NOT_YET_BUILT`, `DERIVED_NOT_PERSISTED`, `TRANSIENT` — each with its own allowed
disposition, and eligibility remains a closed declaration (`UNOWNABLE`, 4 entities).

**Repeat your exercise against the current rules: produce a D1 that passes all nine criteria and would be
useless to its reader.** If you can, the acceptance is still too weak and that is the headline finding.
Angles, not exhaustive:

- the four states plus `EMBEDDED:*` plus the pinning exemptions — is there a combination that empties the
  table while staying legal?
- `UNOWNABLE` maps each entity to a claim sentence verified verbatim in a cited file. Is verifying a
  **sentence** materially stronger than verifying a name, or is it the same weakness at a longer length?
- C7 now requires the Coverage row's own state to carry the decision. Is there still a shape where the
  Coverage row is technically compliant and proposes nothing?
- C8 requires `source_token` re-found in section 2. Can a cell be traceable and still meaningless?

## 5. Question 3 — composition across A, B and D

Audit 7's finding was that **every individual mutation was green while a coordinated one passed.** The
same risk now spans two artifacts instead of one.

**Can a proposal be weakened and then signed, such that the pair reads as a legitimately approved
migration?** Include the checker's own rules in scope: C2 refusing `APPROVED` in D1 is protection only if
nothing else can express approval.

## 6. Also worth your attention (self-reported, verify rather than trust)

A `/scrutinize` pass after `ea44077e` found three defects in that same commit. **Verify these are fixed
and look for what the pattern implies rather than accepting the list:**

- C8's traceability applied only to non-LIVE cells, so a fabricated label wearing `status: LIVE` passed
  untraced — **the same shape as your BLOCKER 1, in the fix for it**: one path closed, its twin left open.
- the sign-off stale-pin gate matched `owner in note` over note **prose**, so a note about
  `docs/MASTER_BACKLOG.md.bak` would have blocked signing `MASTER_BACKLOG.md`.
- a decision for an `EMBEDDED:` pseudo-owner was accepted and counted as "signed".

Also self-reported: `ORDER-602 E`'s first version fingerprinted `.git/index` by **mtime**, which git
rewrites during an ordinary commit — inside the pre-commit tier that would have aborted for a reason
unrelated to the data. It now hashes `git ls-files -s`. **Three times in this session a fix produced a
false alarm one layer up.** If that pattern is still present anywhere, it is worth more than any single
defect.

## 7. Report format

Write `_triage/factory_os/CODEX_AUDIT8_2026-07-30.md`:

1. **Verdict on `ORDER-602`: DONE / NOT DONE**, per item A–E.
2. **Is `ORDER-600` now closable** apart from the owner's decision? It cannot go `REVIEWED` on this
   seat's word.
3. **Findings, severity-ordered** — what is wrong, the evidence (path/line/command output), the
   consequence, the minimal fix. **Separate "I reproduced this" from "I suspect this."**
4. **If you produced a passing-but-useless D1, or a signature that should not have been accepted, include
   the input.** It is worth more than the prose.
5. **What you checked and found sound**, so the coverage of this audit is legible.
6. **Anything this brief steered you away from.** Audits 6 and 7 both found their headline outside the
   questions asked — #6's was a naming problem, #7's was a composition nobody had tested.

Do not soften. Audit 7's NOT DONE was correct and is the reason this slice is in a defensible state.
