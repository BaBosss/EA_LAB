# HANDOFF — lane `S-2026-08-03-S13PILOT` (2026-08-03)

> Second lane of the day. The first (`TIERROOM`) closed `ORDER-1130` and bought the tier 13s of
> hook-mode headroom; this one spent 1.8s of it on slice **S13**'s foundation and ran the three
> `/scrutinize` rounds the owner asked for.

---

## What closed

**`ORDER-1210` — DONE.** Design §8.6 — *"the pass/fail for the whole Stage-4 pilot"* — was fourteen
markdown tickboxes that nothing could read. It is now a machine verdict:
`_triage/factory_os/check_pilot_acceptance.py`.

**The real state of the pilot, stated honestly for the first time:**

```
14 item(s): 3 PASS · 1 FAIL · 10 BLOCKED (0 awaiting evidence, 10 checker-not-implemented)
⚠ EVIDENCE_COMPLETE is currently UNREACHABLE: 10 of the 14 items are stub checkers
```

The design is the source of truth: the checklist is **parsed out of §8.6**, and every item must bind
to exactly one handler and every handler to exactly one item — otherwise the module **REFUSES and
evaluates nothing** (exit 2, explicitly *not* a statement about the pilot). Add a tickbox with no
handler, delete one a handler implements, or reword one past its anchor, and it says so by name.

**Suite: 45 cases, 0 failed.** Tier at HEAD: **27 suites, 0 failed, 108.9s of 120.0s**.

## 🔴 The finding that is NOT in this slice, and needs a decision

`factory/hypotheses.jsonl` pins both pilot hypotheses to `preregistration_ref.anchor` values —
`B14-H01-PREREGISTRATION`, `B14-H02-PREREGISTRATION` — that **occur ZERO times in the 824 KB blob
they pin**. `schemas.json` states the constraint verbatim: *"must occur EXACTLY once in the blob and
contain no spaces"*. It carries **no `x-enforcement-status`**, and **no checker enforced it**, so
both references have been undereferenceable since they were written.

§8.6 item 1 requires the pinned order to carry the **causal claim** *and* the **falsifier**. Today
neither can be shown, because the reference does not resolve. **This lane declared `factory/*.jsonl`
read-only and did not touch it** — see the decision needed below.

## The three `/scrutinize` rounds, and each found something real

**Round 1 — the prohibition guard was watching the one surface nobody reads.** Design §10 forbids
this slice's automation from issuing a verdict. `check_no_verdict_vocab`'s docstring said it scanned
*"the rendered detail strings"*; its body scanned `handler.__doc__`. A handler returning
`'B14-H01 is a VALIDATED CANDIDATE, promote it'` was invisible to it — reproduced before it was
touched. Item 12's own printed output meanwhile **claimed** the check was *"asserted over its own
rendered output, not merely intended"*. The cage had missed it because the attack case planted the
token in the mutant's **docstring**, so it proved the docstring path and left the printed path
unguarded, green throughout. Now `evaluate` scans every rendered detail and **REFUSES** on a leak —
a checker that violates its own prohibition is a broken checker, not a failed pilot, and reporting
it through the channel it just corrupted would be asking the liar to grade the lie.

<sub>The replacement case then needed fixing twice: its first version left the other real handlers
in place, so `evaluate` refused because `check_wrapper_gen` could not read a synthetic source, and
`refuses()` was satisfied by a refusal with nothing to do with verdicts — green for the wrong
reason, the same defect the round was fixing, reproduced inside its own fix.</sub>

**Round 2 — `EVIDENCE_COMPLETE` was unreachable by construction, and the report hid it.** The round
asked which handlers can *ever* return PASS. **Ten of fourteen could not**: hardcoded stubs that read
nothing. So exit code 0 was dead code. The reporting defect is what would have cost real time —
*"BLOCKED because the pilot has not run"* and *"BLOCKED because nobody wrote this check"* are
different work items with different owners, printed as the same word. The concrete failure: the
pilot runs, evidence lands, those ten still say BLOCKED because they never look at anything, and the
reader concludes the checklist is broken. Now `UNIMPLEMENTED` declares each stub **with what it
needs**, `bind()` refuses a stale declaration, the roll-up splits the two counts, and the report
says outright that EVIDENCE_COMPLETE is unreachable. Implementing a stub means **deleting its
entry** — that is the forcing function.

**Round 3 — item 1 was passing on a neighbouring order's homework.** The claim/falsifier check used
`text[index(anchor):][:8000]`, a magic window that does not stop at the end of the pinned section.
An order whose own text states **no method at all** returned **PASS**, because the window ran into
the next `## ORDER-` heading and matched *that* order's claim and falsifier. Item 1 is one of only
four implemented checks and the only one currently reporting FAIL, so a false PASS there is most of
what the report is worth. The window is now bounded, with a CONTROL asserting the correct shape
still passes. Same handler, second finding: the anchor was tested for **presence** while the schema
says **exactly once** — a duplicated anchor is an *ambiguous* reference, now reported as such.

## Three defects the build found in its own author, each a repo-wide pattern

1. `check_pilot_acceptance` **died on its first run** with `UnicodeEncodeError` on §8.6's own `§`/`≤`
   glyphs — the `thai-output-kills-a-suite-inside-the-hook` shape, which inside the tier surfaces as
   `exit -1 SUITE THREW` with the cause swallowed. Both module and wrapper now force utf-8, and the
   suite is **driven under `chcp 1252`** to prove it.
2. The wrapper's summary line used `(... | Where-Object {...})[0]`, which for a **single** match
   indexes into the *string* and returns a `[char]` with no `.Trim()`. Memory
   `powershell-pipeline-count-null-on-single-result` — and here it would have thrown **every** time.
3. A negative case asserted `FAIL` and got `BLOCKED` because its fixture omitted a row the handler
   checks first — memory `discriminating-test-must-be-able-to-discriminate`.

## Two of this repo's own guards demanded work, and both were right

`run_guard_trigger_tests` PART 4b named **12 transitive imports** reached through
`check_wrapper_gen`/`check_param_surface` that the new suite had to declare — the price of *calling*
the existing checkers instead of re-implementing their rules, which is the right trade.
`run_guard_shape_lint`'s L0 refused until the new checker was registered in `L1_FILES` **and**
classified in `CATEGORY` — the **eighth** consecutive time that rule has caught its own author.

## What was NOT done

- **The pilot itself has not been run.** No MT5 lane was declared and no cell was executed. 0 of 16
  cells have Baseline + probe. That is the bulk of S13 and it is untouched.
- **The 10 stub checkers are stubs on purpose**, each declared with what it needs. They are not
  hidden and the report refuses to look complete while they exist.
- `factory/hypotheses.jsonl` was **not** repaired — read-only in this lane by declaration.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| §8.6 parsed from the design and bound to handlers in both directions | DONE |
| PASS / FAIL / BLOCKED, with BLOCKED unable to satisfy the roll-up | DONE |
| design §10 prohibition enforced on the RENDERED output, with an attack + control | DONE |
| the 10 stub checkers declared, split in the roll-up, EVIDENCE_COMPLETE marked unreachable | DONE |
| claim/falsifier window bounded to the pinned order; anchor counted, not merely present | DONE |
| suite registered in the fast tier (1.8s hook-mode) after measuring with `-Hook` | DONE |
| 🔴 **`factory/hypotheses.jsonl` anchors resolve to nothing — needs the owner's call** | ORDER-1210 (owed) |
| **the 10 stub checkers** — each needs its evidence store to exist first | S13 (next lane) |
| **run the 16 pilot cells** (Baseline + probe), MT5 lane declared FIRST | S13 (next lane) |
| BTCUSD pinned to the primary install for life; crypto financing deducted post-hoc | S13 (next lane) |
| owner creates the `EA LAB Control Room` bot + fills the two config keys | ORDER-1180 (owed) |
| front-guard costs ~21s when the board is staged — mechanism still unknown | ORDER-1130 (owed) |
