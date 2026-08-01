# HANDOFF — lane `S-2026-08-01-PINFIX2` (2026-08-01, after `S-2026-08-01-PINFIX`), block 770-779, no MT5 lane

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this is a **shift-change note, not a queue**
> (Decision log 2026-07-26). Every forward-looking item has a home — the routing table at the
> bottom says which. Opening prompt for the next session =
> **`_triage/PROMPT_NEXT_SESSION_PINFIX.md`**, still current except where this file corrects it.

## What this lane was asked to do

The owner ratified `_triage/USER_DECISIONS_PENDING.md` **item 5 as option A** (narrow the S2a pin
to the section the approval was actually about) and the order of work proposed with it:
**`ORDER-760` first because it costs no signature, then `ORDER-731` option A.**

> ✅ **SUPERSEDED — `ORDER-731` option A was started and landed the next lane** (`212c0555`), and option 2
> after it (`c66d5e57`). Both are owner-signed; the S2a gate is green at HEAD. Read
> `_triage/HANDOFF_2026-08-01_SESSION_END.md` for the state; this file is kept for why option A was
> deliberately NOT started *here*, which is still the right call for the reason it gives.

## The one-line state

**`ORDER-760` is DONE. `ORDER-731` option A is specified, ratified in direction, and NOT started
— deliberately, and the reason is in "Why option A was not started" below.**

## `ORDER-760` — and the measurement changed the design

**C1 first, before writing a rule.** Of the **56** lane rows in `docs/SESSION_LEDGER.md`, **2**
disagreed with the 6-cell header — and **one of them was already correct**:
`S-2026-08-01-CODEXBRIEF` had written `\|`, the markdown escape, and `Split-MarkdownRow` was
splitting on it anyway. **The parser was the defect in half the live instances.** The splitter is
escape-aware now (`(?<!\\)\|` + unescape), which repairs that row without editing it.

That left **one** genuinely malformed row (`S-2026-07-27-QUEUE`, a duplicated trailing status
cell), repaired in the same commit ⇒ **steady-state cost of the new BLOCK is 0 rows**, which is
what makes BLOCK rather than WARN payable. And a WARN is exactly what already existed and already
failed: the guard printed `NOTE: no ACTIVE lane … rules skipped` and **passed**, so two commits
were made with `RULE 2` and `RULE 3` unarmed.

## 🔴 The part worth reading: RULE 4 blocked its own repair, on its first real run

RULE 4 originally read the ledger from `HEAD`, like RULE 2 does. The commit that **repaired** the
malformed row was then **refused** — because `HEAD` still held it. That is `ORDER-731`'s defect
class (*the gate blocks its own repair*) **recreated inside the fix for a different one**, i.e.
GUARD_SHAPES **shape 5**, one working day after that shape was written up.

It was caught by reality — the commit simply would not go — not by review, and not by the tests,
which had no way to express two ledger vintages until a `-StagedLedgerContent` override was added
for exactly that case.

**The fix, and why it weakens nothing:** RULE 4 judges the **staged** ledger; RULE 2 and RULE 3
keep their **ratified** HEAD read (Decision log 2026-07-26), so one commit still cannot reserve a
block and spend it. Only the *shape* question moved, to the snapshot the question is about —
"is this table readable" is a claim about the bytes the commit will contain.

**Stated limit, written into the guard rather than left to be discovered:** when the ledger is
*not* staged, the shape is judged at HEAD, so a malformed row that somehow reaches HEAD blocks
**every** commit until it is fixed. That is deliberate, the only way in is `--no-verify`, and the
message names the row and its line number.

## Numbers, all measured this session

| | |
|---|---|
| lane rows checked | **56**, of which **2** malformed — **1** of those was the parser's fault |
| steady-state rows tripping the new BLOCK | **0** (the one real row repaired in the same commit) |
| `run_order_collision_tests.ps1` | **31/31**, 6 new — incl. HEAD-bad + staged-good ⇒ **PASS**, HEAD-good + staged-bad ⇒ **BLOCK** |
| full tier | **16/16 at 75.1s** of 90.0s |

## Why `ORDER-731` option A was NOT started

It is not a small edit and it must not be half-landed:

* it edits **`S2A_ATTESTATION_POLICY.md`** and the frozen **`S2A_ATTESTATION_VECTORS.jsonl`** —
  **both bundle members**, so the current record is void the moment either moves;
* plus `check_s2a_attestation.py` (`F6`–`F11`), `check_attested_pin_staged.py`, and three cages;
* and it **ends at an owner signature it cannot proceed past** (the new `bundle_sha256` must be
  shown to the owner and confirmed in chat — `ORDER-731`'s ห้าม forbids writing that line
  unprompted, and `ORDER-614` rev 2 exists so it costs exactly one).

Starting it and stopping midway leaves **a void record with nothing to replace it** — the S2a gate
red, and every commit touching `_triage/factory_os/**` or `MASTER_BACKLOG.md` refused, which is the
state this whole batch was cleaning up. Not starting is the cheaper of the two failure modes, and
the direction is already ratified so nothing is lost by starting it fresh.

**What a fresh lane needs, in order:** the three costed options and the ratified choice are in
`_triage/USER_DECISIONS_PENDING.md` item 5; the constraint that makes it cost a signature is in the
`ORDER-731` row; `check_s2a_attestation.py` lines 375-415 are the `F6`–`F11` block that changes.

## Do not do these

- ❌ Do not append to `_triage/factory_os/s2a_attestations.jsonl` without showing the owner the
  exact new `bundle_sha256` in chat and getting an explicit confirmation. Ratifying a *direction*
  is not the same as signing a *digest*.
- ❌ Do not land option A partially. Policy, vectors, checker and the front guard move in **one**
  commit with the owner's line, or none of them do.
- ❌ Do not append to `MASTER_BACKLOG.md` — still pinned; you now find out at the hook.
- ❌ Do not put a raw `|` or a second block number in a ledger cell. `RULE 4` refuses the first;
  the second silently reserves a block you did not mean to take (`ORDER-760`, กติกาข้อ 6).

## Routing — every forward-looking item has a home

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| `ORDER-731` option A — narrow the S2a pin to the section the approval was about; direction ratified by the owner, costs exactly one signature, not started | ORDER-731 |
| the tier abort that fired in 2 of 8 manual full-tier runs, one instance explained and one not | ORDER-731 |
| `ORDER-760` (escape-aware splitter · RULE 4 · the staged-snapshot fix · rule 6 in the ledger) | DONE |
| a module should DECLARE the paths it reads, instead of a regex guessing them | ORDER-761 |
| the locked-constant half of design §5.6, untouched by this lane | ORDER-730 |
| the five non-front-guard PowerShell checkers still suspended in `L3`, and items 1-4 of `_triage/USER_DECISIONS_PENDING.md` | DONE |

<sub>The last row is `DONE` in the routing sense only: it carries no work *this lane* owes.</sub>

## Other lanes

None were `ACTIVE`. `S-2026-08-01-PINFIX` closed immediately before this one.
