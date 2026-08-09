# Review brief — round 2: the response to your first audit

Code-quality and data-conformance review of validation scripts and the data files they validate, all
inside this repository. No external system, no third party, no security dimension. The recurring
question is: **can a file satisfy every check while still being wrong in the way the check exists to
prevent?**

Your first audit produced 11 findings. This brief covers what changed in response, plus new work.
**Treat "your findings are fixed" as a claim, not a premise** — that instruction is here because last
time the two findings that mattered most sat outside the questions the brief asked.

No verdict from the author is included. Commit messages are not evidence; read the code.

---

## 1. Scope

| | |
|---|---|
| previously audited | `d4e5716c..33292571` |
| **new range** | **`33292571..HEAD`** (12 commits) |
| full session | `d4e5716c..HEAD` (19 commits), branch `master`, no push/rebase/amend/force |
| orders | ORDER-610 (re-closed) · ORDER-611 · ORDER-612 (spec) · **ORDER-613 (new, landed)** · **ORDER-614 (new, spec only)** |

### Changed paths in the new range

```
M  _triage/factory_os/check_s2a_attestation.py    D1/D2 + the two-pass eligibility restructure
M  _triage/factory_os/run_s2a_attestation_tests.py  9 new cases
M  _triage/factory_os/run_s2a_gate.py             advisory branch deleted
M  _triage/factory_os/check_coverage_transfer.py  S1/S3/P1/S5 fixes; A8 downgrade deleted; A4 deleted
M  _triage/factory_os/gen_coverage.py             S2 pin-by-blob; shared renderer; temp dir
M  _triage/factory_os/run_coverage_transfer_tests.py  new fixtures; A8 fixtures removed
M  _triage/factory_os/run_schema_fixtures.py      spec_is_discriminating
M  _triage/factory_os/s2a_attestations.jsonl      lines 4 and 5 appended
M  _triage/factory_os/CODEX_FINAL_..._BRIEF_2026-07-31.md  P5 correction appended
M  AGENT_TASKBOARD.md · docs/SESSION_LEDGER.md · _triage/USER_TASKS_2026-07-31.md
```

---

## 2. Commands and expected exits

```
tools\python312\python.exe _triage\factory_os\run_s2a_gate.py                  -> 0  (7/7, no advisories)
tools\python312\python.exe _triage\factory_os\check_s2a_attestation.py         -> 0
tools\python312\python.exe _triage\factory_os\run_s2a_attestation_tests.py     -> 0
tools\python312\python.exe _triage\factory_os\check_coverage_transfer.py       -> 0
tools\python312\python.exe _triage\factory_os\run_coverage_transfer_tests.py   -> 0
tools\python312\python.exe _triage\factory_os\run_schema_fixtures.py           -> 0
powershell -File scripts\_test\run_fast_cages.ps1                              -> 0  (12 suites, 26.0s)
powershell -File scripts\check_state.ps1                                       -> 0  (CLEAN)
```

---

## 3. Gaps the author already knows about — confirm, refute, or find worse

Stated up front so the audit is not spent rediscovering them.

- **A8 now has NO negative fixture.** The six cases that tested the downgrade were deleted with the
  downgrade. `run_coverage_transfer_tests.py` passes `skip_a8=True` everywhere, so nothing proves A8
  can fail. Is that acceptable given it is a one-line subprocess exit check, or is it the "a criterion
  nothing exercises" pattern in new clothes?
- **`expected_post_state` is OPTIONAL.** A record that omits it gets no post-state binding at all, so
  D2's guarantee applies only to records that opt in. Does that make it decorative?
- **A2 now requires full-dict equality on imported cells.** Does that over-constrain — is there a
  legitimate future edit to a cell that this makes impossible without a new owner decision?
- **`strip_invisible` only removes HTML comments.** Enumerate the other ways the required notice could
  be present in the source and absent from the rendered page.

---

## 4. The questions

### Q1 — the two-pass eligibility restructure

`check_s2a_attestation.py::check()` now runs pass 1 (intrinsic: A1, A4) to build `eligible`, derives
`latest` from it, then applies the in-force checks (A2, A6, D2) in pass 2.

- Can any row still displace the decision in force? Try: duplicate `_line`, non-dict rows, an owner
  string differing only by case or whitespace, a row that is eligible but whose `current_owner`
  differs from the D1 owner it is meant to decide.
- The stated rule is *"checks on the record itself apply to every row; checks on its relationship to
  current external state apply only to the row in force."* Walk every criterion and say whether it is
  on the correct side. A5 (`REFUSED` needs a reason) is in pass 2 — is that right?
- `current[owner]` is only assigned for rows that survive pass 2. If the in-force row fails A2, is the
  reported "current decision" then absent, stale, or wrong?

### Q2 — D2, and whether it binds anything

- Construct a record with an `expected_post_state` that passes while the repository is in a state the
  owner did not approve.
- The check resolves `HEAD:path`. What happens when the path was deleted, renamed, or is a directory?
- Does anything require an *acknowledgement* to carry an `expected_post_state`? If not, is the
  distinction D2 was built for ("bytes changed" vs "bytes changed INTO the approved state") actually
  enforced anywhere?

### Q3 — the attestation log as it now stands (5 lines)

Lines 2 and 3 are bound to bundles that no longer exist; line 4 to a superseded one; line 5 is in
force. Four different `bundle_sha256` values in one file.

- Is A7 (committed bytes must remain a byte prefix) still satisfied? Verify against HEAD.
- Line 4 was **edited before it was committed** (its `bundle_sha256` was rebound from `1bd4d268` to
  `fa6bab35`) and line 5 supersedes it. Does that sequence leave any inconsistency a reader could be
  misled by?
- The log now contains three `recorded_by` values saying a Claude seat transcribed an owner decision.
  Is anything in this file capable of distinguishing that from a seat inventing one? If not — the
  author asserts it is not — is the file's own header still an honest description of it?

### Q4 — the deletions

D3 deleted the A8 downgrade, `--explain-attestation`, and the gate's advisory branch. A4
(`a4_deterministic`) was deleted outright rather than repaired.

- Are there dead references, unreachable branches, or stale docstrings left behind?
- Is anything the deleted A4 covered now covered by nothing? The claim is that A1's body comparison
  subsumes it — verify or refute by finding a state A4 would have caught and A1 does not.
- `run_s2a_gate.py` prints `all N steps green`. Confirm it cannot print that while a step was skipped.

### Q5 — the fixes to your first-round findings

For each, find a variant that still gets through:

| your finding | the fix |
|---|---|
| S1 read_input atomicity | a mixed index/worktree pair is now a `ToolFailure` |
| S2 mixed-vintage baseline | reconciliation pinned by blob `1fff12ce` (it did **not exist** at `BASELINE_COMMIT` — verify) |
| S3 HTML comment | `strip_invisible()` before the notice search |
| S4 `says=[{}]` | `spec_is_discriminating()` requires a spec to name where or what |
| S5 tautological A4 | deleted |
| P1 unguarded store facts | A2 full-cell equality + A3 closed shape |
| P5 revertibility claim | corrected by appending to the original brief |

### Q6 — ORDER-614, which is a SPEC not an implementation

Four owner signatures were spent in one session (`aaa5998d`→`1bd4d268`→`fa6bab35`→`6ec25ca5`), three
for repairs that changed no rule, because `check_s2a_attestation.py` is a member of its own bundle.
ORDER-614 proposes binding a machine-readable **contract declaration** instead of the file bytes.

- Is that design gameable? Specifically: can behaviour change materially while every declared
  criterion stays identical and no new problem class is emitted?
- The order forbids "Claude decides which edits are substantive". Does the proposed design
  reintroduce that judgement anywhere?
- Is there a simpler design that achieves the same goal?

---

## 5. Confirm the negatives

> 🔴 **CORRECTED 2026-07-31 after the round-2 audit returned this, appended rather than rewritten
> so the document the auditor actually read stays legible.**
>
> **The scope line and one negative below were both wrong, and the reason is worth more than the
> correction.** This brief said the new range was 12 commits and the session 19. It is **14 and 21**:
> the brief's own commit lands inside the range it describes, and `f2cc7ca1` **`[auto] daily monitor
> snapshot`** committed at 07:37 **while this session was running**.
>
> That automated commit touched `portfolio/LIVE_DASHBOARD.html`, `portfolio/control_room_snapshot.json`
> and six `portfolio/live_deals/*.csv` files. So *"No Live path touched"* is **false for the range**,
> though it remains true for every commit authored by this work. The honest form is:
> **no live path was touched by the commits of this change; the range also contains a scheduled
> monitor snapshot that this session neither made nor reviewed.**
>
> **The lesson is not the wording.** A negative asserted over a *commit range* is a claim about
> everything that lands in it, including writers that are not you. This repository has a scheduled
> job that commits to it, and nothing in the session ledger records that lane.

- No `.set`, `.mq5`, `.mqh` or `.ex5` touched in the whole 19-commit range.
- No Demo / Live / VPS / `_vps_deploy` path touched. No Telegram message. No token.
- No MT5 tester lane used; **no backtest run**, so no reported number depends on a lane.
- `VISION.md`, `AGENTS.md`, the Decision log: unedited.
- No order marked `REVIEWED`.
- ~268 pre-existing dirty/untracked files preserved; nothing swept into a commit.

## 6. Out of scope

The staleness of the coverage data itself (the transfer moved ownership, not content, by the owner's
own condition) · whether the Factory OS design is right (audits 1–8) · the 15.0s tier budget, breached
before this work · slices S4–S15, which are unimplemented.
