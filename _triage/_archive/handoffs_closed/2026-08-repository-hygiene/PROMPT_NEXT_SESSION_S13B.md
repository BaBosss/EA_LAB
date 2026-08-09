# OPENING PROMPT — the pilot is pre-registered; now RUN it

> Written 2026-08-03 by lane `S-2026-08-03-S13PILOT`, after building the §8.6 acceptance checker
> and running three `/scrutinize` rounds over it; extended the same day by lane
> `S-2026-08-03-PREREG`, which closed BOX 1. **Nothing in this chain now needs a human answer** —
> the next lane runs the pilot.

---

## ✅ BOX 1 — ANSWERED AND DONE (2026-08-03). Read it once, then move on.

The pilot's pre-registration **did not resolve**: both `preregistration_ref` pins named anchors that
occurred **zero times** in the blob they pinned, while `schemas.json` requires *exactly once*. It had
no `x-enforcement-status` and nothing enforced it until `ORDER-1210` built the checker.

**The owner chose option 1, and it is closed.** `ORDER-1220` now carries the pre-registration for
both hypotheses — causal claim and falsifier **copied verbatim from design §8.1**, which owns them —
and both rows are re-pinned at that commit. All three git-derived fields recompute, each anchor
occurs exactly once, and the registry copies neither the claim nor the falsifier.

**The ordering was the whole point and it held: this was written with 0 of the 16 cells run.** H01's
falsifier IS the flat-lot probe — the test that decides whether the edge lives in the escalation
engine or in the signal — so writing it after the runs would have been choosing the criterion having
seen the result. **If you re-open this, you cannot restore that property.**

<sub>Writing the first real pre-registration immediately exposed a matcher defect worth remembering:
the claim/falsifier test was case-sensitive, so it did not match `**Causal claim.**` — and the
falsifier half missed its heading too yet still reported PRESENT, because the word appears lowercase
in a footnote further down the section. One half strict, the other accidentally lenient, identical
from outside. Both are now case-insensitive with a control proving a section carrying neither word
still fails.</sub>

**Nothing here needs a decision now.** The next lane runs the pilot.

---

## Where things stand — verify, do not assume

```bash
tools/python312/python.exe _triage/factory_os/check_pilot_acceptance.py
```

Today that prints **`14 item(s): 4 PASS · 0 FAIL · 10 BLOCKED (0 awaiting evidence, 10
checker-not-implemented)`** and says outright that `EVIDENCE_COMPLETE` is **UNREACHABLE**, because
ten of the fourteen handlers are declared stubs. **That is not a defect to fix by hand** — each stub
is listed in `UNIMPLEMENTED` with what it needs, and implementing one means deleting its entry. Most
need an evidence store that does not exist yet, so the order of work is: **run the pilot, then teach
the checker to read what the pilot produced.**

- **Baseline green first:** `run_fast_cages.ps1` (27 suites, ~109s of 120.0s under `-Hook`) ·
  `run_s13_tests.ps1` (47 cases) · `run_s2a_gate.py` · `run_schema_fixtures.py` ·
  `check_schema_structure.py` · `gen_design_contracts.py --check` · `check_state.ps1`.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run.
- **Re-derive your order block from BOTH tests** — parse `## ORDER-<n>` out of all four board files
  **and** check every reserved block in `docs/SESSION_LEDGER.md`. As of this writing the highest in
  use is **1220** and the highest reserved block is **1220-1229**, so **1230-1239** is next — **but
  check, and commit the reservation before using a number.** Note `1190-1199` was reserved and never
  used; leave it as buffer.
- `git log --oneline -15`.

## The actual S13 work, in the order the design forces

1. **Declare the MT5 lane in the ledger before running anything.** `BTCUSD` is pinned to the primary
   install **for its whole life** — tick history differs **14×** across installs (design §8.3), so a
   cell run on the wrong lane is a wrong number, not a noisy one.
2. **Parity first (§8.4), because no cell's evidence counts until it passes.** All seven points of
   §5.5, on one lane, lane named in the output — **and the must-trade case must actually have
   traded and the refusal case must actually have refused.** A parity run where nothing traded and
   nothing refused is **not** a pass; `parity.verdict_for_case` already enforces that, so drive it
   rather than re-implementing.
3. **Then the 16 cells** (4 symbols × 2 TF × 2 hypotheses), each Baseline + probe, or a **written**
   `NOT_APPLICABLE` reason.
4. **Crypto financing is deducted post-hoc, and the output must say so.** The tester charges
   `POINTS`-mode swap but **not** `INTEREST_CURRENT` (BTCUSD −14.67 %/yr), so every crypto number is
   optimistic by a known, large amount until deducted.
5. **Every cell's PF is displayed with its trade count AND its drawdown** — not cosmetic: a bar can
   be cleared by *non-participation* (memory `bar-cleared-by-non-participation`).
6. **Teach the stub checkers to read what now exists**, deleting each `UNIMPLEMENTED` entry as you
   go. The report will tell you when it has become reachable.

## Traps this lane paid for, in the exact place you will hit them

- **Your output can kill your own suite.** §8.6's wording carries `§` and `≤`; python takes its
  stdout encoding from the console codepage, and a child of the pre-commit hook gets an ANSI pipe,
  so the first such glyph raises `UnicodeEncodeError` → the tier prints `exit -1 SUITE THREW` with
  the cause swallowed. Every python-invoking wrapper needs `$env:PYTHONIOENCODING = 'utf-8'`.
  **Reproduce with `chcp 1252` — a suite that is green in your shell can be dead in the hook.**
- **`(... | Where-Object {...})[0]` returns a `[char]` when exactly one line matches**, because it
  indexes into the string. Wrap in `@()`. It fails *every* time, not intermittently.
- **A negative case that short-circuits before the rule under test proves nothing.** One here
  asserted `FAIL`, got `BLOCKED` from an earlier guard clause, and looked like a real attack.
- **Adding one `check_*.py` costs two more edits**: `run_guard_shape_lint`'s `L1_FILES` **and**
  `CATEGORY` (it REFUSES until both exist, blocking every lane's commits), and
  `run_guard_trigger_tests` PART 4b will name every **transitive import** you must declare.

## Build guidance these three rounds paid for

- 🔴 **Check the surface the reader actually sees.** Round 1: a prohibition guard scanned handler
  docstrings while its own comment claimed it scanned the rendered output — and the test agreed with
  it, because the attack planted the token in a docstring too.
- 🔴 **Ask what a handler can EVER return.** Round 2: ten of fourteen could only return BLOCKED, so
  the success condition was unsatisfiable and exit 0 was dead code. *"Not run yet"* and *"not
  implemented yet"* must not print as the same word.
- 🔴 **A window is a boundary, not a character count.** Round 3: an 8000-char window ran past the end
  of the pinned order and matched a **different** order's claim and falsifier, turning a false PASS
  into the module's most load-bearing check.
- 🔴 **Every attack needs its control.** Each fix above ships with a case asserting the correct shape
  still passes — otherwise "it now fails" is indistinguishable from "it now always fails".

## Do NOT do in this session

- 🚫 Issue any EA verdict from automation — design §10 stops this slice at `EVIDENCE_COMPLETE`, and
  `check_pilot_acceptance` REFUSES if its own output would carry verdict vocabulary.
- 🚫 Hand-edit §8.6 to make an item pass · 🚫 delete an `UNIMPLEMENTED` entry without implementing it.
- 🚫 Raise `$FullTierBudgetSeconds` — `run_guard_trigger_tests` PART 7 N1 pins the measured 120.0s.
- 🚫 Register a new fast-tier suite without measuring the tier **with `-Hook`** first.
- 🚫 Run a pilot cell before the MT5 lane is declared in `docs/SESSION_LEDGER.md`.
- 🚫 Compare results across MT5 installs · 🚫 quote a crypto number with financing not deducted.
- 🚫 Edit `_triage/EA_LAB_FACTORY_OS_DESIGN.md` §8.6 — it is the spec the checker is judged against.
- 🚫 Touch `MASTER_BACKLOG.md` §2 · `AGENTS.md` · `PROJECT_STATE.md` · any `.set` migration · any
  magic allocate/renumber/retire.

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม — จอง MT5 lane ก่อน แล้วรัน parity ตามด้วย 16 cells ของ S13"**
