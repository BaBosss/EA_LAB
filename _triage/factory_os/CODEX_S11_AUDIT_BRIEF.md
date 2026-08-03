# Codex blind audit brief — Factory OS slice **S11** (Control Center shell + `SafeProjection`)

> Written 2026-08-03 by lane `S-2026-08-03-AUDITCOV`. **You are the independent brain.**
>
> This slice's built code has **never been independently audited**. Nothing here tells you what any
> previous session concluded, deliberately. Attack the claims; do not restate them.

---

## 0. Read at a PINNED commit · READ-ONLY

```bash
git show a87f7448:<path>
```

Do not edit, create, stage or commit anything. Do not write to `ops/`, `factory/` or `.git/`.
**Do not print or reconstruct any account number, balance, credential or other real value you find
in a snapshot.** If a path would expose one, describe the path and the `file:line`, never the value.
Your deliverable is a report on stdout.

## 1. What you are auditing, in one sentence

The **allowlist-only DTO** that is the only document an online or Telegram surface is permitted to
read, plus the recursive scanner that is supposed to prove it carries nothing it must not, plus the
one reader function that is supposed to be the sender's only door.

**The stake, and its history.** The design once said the online projection was *"safe by
construction"*. A blind audit measured that **no construction existed** — the phrase was a promise,
while the real snapshot carried `account`, `balance`, `equity`, `floating_pl`, `margin_level`,
per-magic `open_lots` and EA names, two fields away from the sentence saying it did not. This slice
is the answer to that. It is therefore the one place in the repo where *"a sentence is not a
boundary"* has already been proven the expensive way, and the natural question is whether the
replacement is a boundary or a better-worded sentence.

## 2. Read these, in this order

| | |
|---|---|
| `_triage/EA_LAB_FACTORY_OS_DESIGN.md` | **§7.1** (operations domain, read-only, and the safe-by-construction sentence) · **§7.2** · **§7.4** · **§10** the **S11** row |
| `_triage/factory_os/CONTRACTS.md` | `SafeProjection` · `ControlRoomSnapshotV5` · `SnapshotMeta` · `SystemFinding` |
| `AGENT_TASKBOARD.md` | row **`ORDER-1131`** and the S11 handoff acceptance scenarios it references |

## 3. The artifacts

| file | what it decides |
|---|---|
| `_triage/factory_os/safe_projection.py` | the allowlist, `scan_forbidden()`, `read_for_sender()`, the refusal set |
| `_triage/factory_os/control_center.py` | the shell — TODAY / WORK / LIVE / SYSTEM in shadow mode, and `fold_finding` |
| `_triage/factory_os/run_s11_tests.py` | the cage, including synthetic secret and account fixtures |
| `_triage/factory_os/snapshot_validator.py` · `snapshot_build.py` | what produces the snapshot the projection is derived from |

## 4. The claims — refute these

| # | claim | where |
|---|---|---|
| C1 | the DTO is **allowlist-only**, so a new field cannot leak by being added upstream | the allowlist |
| C2 | `scan_forbidden()` is **recursive over keys AND values at any depth** — because an allowlist stops a new *field* but not an account number typed into a field that is allowed, and the two leaks need different mechanisms | `scan_forbidden()` |
| C3 | `read_for_sender()` **refuses every path except the pinned one**, refuses a document that is not `entity=SafeProjection`, and **re-scans what it is about to hand back** | `read_for_sender()` |
| C4 | the claim is **honestly scoped**: it does not mean the OS cannot open the snapshot — no python module can claim that — it means the only reader offered refuses, and the cage hands `read_for_sender()` the real snapshot path and requires a refusal | the docstring's own limit statement |
| C5 | **an unrecognised input REFUSES and never becomes a benign default** — an unknown `floating_risk.state` is a `ProjectionRefusal`, not `UNKNOWN`, because mapping the unrecognised onto the safe-looking value is how a future state meaning BREACH renders as OK | the state handling |
| C6 | **an exemption is a closed declaration, never a rule** — there is no "skip fields that look like timestamps" | the exemption handling |
| C7 | this module **computes no threshold**; a drawdown band is passed through from a detector or it is `UNKNOWN` | the band handling |
| C8 | **no dispatch, claim, or closure from the UI**, and **Telegram cannot read the full snapshot** (design §10's two prohibitions) | `control_center.py` |

## 5. Where to aim

1. **C2 is where the whole slice lives or dies. Attack the scanner's *recognisers*.** An account
   number scan that matches a digit-run misses a formatted one; one that matches a format misses a
   raw one. Try: an account id inside a longer string, split across a list, as a dict **key**, as an
   integer rather than a string, inside a nested list-of-lists, inside a JSON string embedded in a
   value, unicode digits, and a value that is only forbidden *in combination*.
2. **The scanner's input is the thing that can be taken away.** This project has already been burned
   by a check that went quiet because the prohibition removed its input. If `scan_forbidden()`'s
   KNOWN-SECRET layer needs a secret list, what does it do when the list is empty — scan less, or
   report clean? Distinguish *"scanned and found nothing"* from *"had nothing to scan with"*, and
   check whether the code and its output distinguish them.
3. **C1's allowlist vs C3's `entity` check.** If a document declares `entity=SafeProjection` but
   carries extra keys, which mechanism rejects it — and does either fire if `unevaluatedProperties`
   is absent for that entity in `schemas.json`? Cross-check against the schema rather than assuming.
4. **C3's "re-scan what it is about to hand back".** Is the re-scan on the *returned object* or on
   the *bytes read*? A projection that is mutated after the scan and before the return would defeat
   the first; a lazily-evaluated field would defeat both.
5. **C4 is a well-scoped honesty claim — verify the scope is actually what is driven.** Does the
   cage really hand the *real* snapshot path, or a fixture that resembles it? A refusal proved
   against a fixture proves the fixture is refused.
6. **C5's refusal-on-unknown.** Enumerate every enum-like field the projection carries. For each,
   find whether an unknown member refuses or falls through. One `else: return 'UNKNOWN'` is the
   whole finding.
7. **C7's `UNKNOWN` band.** If no detector publishes a band today, then the pass-through path has
   never been exercised with a real value. Is that stated as `UNTESTED`, or reported as working?
8. **C8's "shadow mode".** What enforces it — a flag, a missing code path, or a convention? A
   prohibition enforced by a flag can be flipped; one enforced by the absence of the code cannot.
   Which is this?
9. **The snapshot→projection derivation.** C1 protects the projection. Who builds it? If the builder
   copies a whole sub-object and then prunes, there is a window; if it constructs field by field,
   there is not. Read `snapshot_build.py` for which shape it is.

## 6. How to reproduce

```bash
tools/python312/python.exe _triage/factory_os/run_s11_tests.py
```
```bash
tools/python312/python.exe _triage/factory_os/run_s11_tests.py --list
```

⚠️ Two suites unrelated to S11 (`run_s2a_gate` F2, `check_coverage_transfer` A8) are **known red at
this pin** for a reason already recorded elsewhere. Not your finding.

## 7. What a finding must contain

`file:line` · the input, field or document that exposes it · the consequence stated as *what value
reaches a surface that must not carry it* — **named as a field, never quoted as a value** · and a
reproducing command where you can produce one.

Rank by severity, and keep **"this leaks"** separate from **"this cannot detect a leak"** — the
second reports clean forever and is the more expensive kind.
