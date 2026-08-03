# OPENING PROMPT — after `ORDER-1210`: one decision is owed, then run the pilot

> Written 2026-08-03 by lane `S-2026-08-03-S13PILOT`, after building the §8.6 acceptance checker
> and running three `/scrutinize` rounds over it. **Read BOX 1 before planning** — it is the only
> thing in this chain that needs a human answer.

---

## 🔴 BOX 1 — THE PILOT'S PRE-REGISTRATION DOES NOT RESOLVE, AND THAT IS A DECISION, NOT A BUG FIX

`factory/hypotheses.jsonl` pins both pilot hypotheses to anchors that **occur ZERO times in the
824 KB blob they pin**:

| hypothesis | anchor | occurrences in the pinned blob |
|---|---|---|
| `B14-H01` | `B14-H01-PREREGISTRATION` | **0** |
| `B14-H02` | `B14-H02-PREREGISTRATION` | **0** |

`schemas.json` states the constraint verbatim — *"must occur EXACTLY once in the blob and contain no
spaces"* — carries **no `x-enforcement-status`**, and **nothing enforced it** until
`check_pilot_acceptance` was written. Both references have been undereferenceable since they were
written.

**Why it is a decision and not a repair.** §8.6 item 1 requires the pinned order to carry the
**causal claim** and the **falsifier**. If nobody ever wrote them, adding an anchor points at
nothing — the anchor is not the missing thing, *the pre-registration is*. Writing a hypothesis's
causal claim and its falsifier is the act that makes the pilot's evidence mean anything, and it
belongs to the lead/owner, not to a repair script. The three options:

1. **Write the pre-registration** into a taskboard order (claim + falsifier per hypothesis), then
   re-pin `preregistration_ref` at that commit. This is the only option that makes item 1 passable.
2. **Re-pin to an existing order** that already carries both — if one exists. Verify by reading it,
   not by grepping for the words.
3. **Accept the FAIL** for now and run the pilot anyway, knowing item 1 can never pass and
   `EVIDENCE_COMPLETE` is therefore unreachable for a second reason.

Whichever is chosen, `factory/*.jsonl` is a canonical store — **declare it in the ledger row first.**

---

## Where things stand — verify, do not assume

```bash
tools/python312/python.exe _triage/factory_os/check_pilot_acceptance.py
```

Today that prints **`14 item(s): 3 PASS · 1 FAIL · 10 BLOCKED (0 awaiting evidence, 10
checker-not-implemented)`** and says outright that `EVIDENCE_COMPLETE` is **UNREACHABLE**, because
ten of the fourteen handlers are declared stubs. **That is not a defect to fix by hand** — each stub
is listed in `UNIMPLEMENTED` with what it needs, and implementing one means deleting its entry. Most
need an evidence store that does not exist yet, so the order of work is: **run the pilot, then teach
the checker to read what the pilot produced.**

- **Baseline green first:** `run_fast_cages.ps1` (27 suites, ~109s of 120.0s under `-Hook`) ·
  `run_s13_tests.ps1` (45 cases) · `run_s2a_gate.py` · `run_schema_fixtures.py` ·
  `check_schema_structure.py` · `gen_design_contracts.py --check` · `check_state.ps1`.
- **Delete `_triage/factory_os/__pycache__`** before the first generator run.
- **Re-derive your order block from BOTH tests** — parse `## ORDER-<n>` out of all four board files
  **and** check every reserved block in `docs/SESSION_LEDGER.md`. As of this writing the highest in
  use is **1210** and the highest reserved block is **1210-1219**, so **1220-1229** is next — **but
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

Open with: **"อ่านไฟล์นี้ แล้วเริ่ม — ตอบ BOX 1 ก่อน แล้วค่อยลงมือรัน pilot S13"**
