# OPENING PROMPT — the corrections lane, part 2. Two of the nine are repaired; seven are not.

> Written 2026-08-03 by lane `S-2026-08-03-CORRECT`, which repaired **`ORDER-1264` then `ORDER-1263`**
> and nothing else. This is the same seat as `_triage/PROMPT_NEXT_SESSION_CORRECTIONS.md` — **read
> that file too, it is still the map.** This one only records what moved, what it cost, and the two
> things it learned that change how you should approach the rest.

---

## §0 — What is DONE, so you do not re-derive it

| order | state | one line |
|---|---|---|
| **`ORDER-1264`** | ✅ DONE `14276944` | a lost `x-enforced-by` reddens instead of vanishing; the header counts have a harness |
| **`ORDER-1263`** | ✅ DONE `007e9f65` | `OwnerRef` resolves — R1 blob · R2 identity · R3 sha256 · R4 anchor, each with a control |

Both board rows carry the full outcome. **The controls are the part to trust:** every new case was
run against `git show HEAD:` of the file it guards, so "this was broken before" is a measurement in
each order rather than a claim.

> 🔴 **REVISED after `/scrutinize`, and the revision is the most important line in this file.**
> `ORDER-1264` also moved `run_enforcement_status_tests.py` onto the **commit path**. That was
> **wrong and is reverted** — the cage mutates the live, tracked `schemas.json`, so on a repo where
> two lanes commit concurrently it is a data-loss path. **Observed within twenty minutes** (a hand
> run collided with another lane's hook; one died with `OSError 22`, the other restored *its* idea
> of the original, leaving a synthetic `x-enforcement-status` in the working tree). The repo had
> **already recorded this exact failure by name on 2026-07-31** and flagged the mutate-a-copy fix as
> its own task; I did not read it first. Now `ORDER-1283`, with the pattern already proven by
> `run_preset_tests.py --mutate`. **Do not re-add that suite to the tier before it mutates a copy** —
> the argument for adding it is genuinely good, which is exactly why it is dangerous.

**Five orders were opened, and one of them is cited from code:**

- **`ORDER-1280`** — the **12** contracts still carrying no enforcement declaration.
  `check_schema_structure.py` names this order in a comment *and* prints `UNDECLARED=12` in its own
  report, so leaving it unopened would have been a dangling citation. It is deliberately **not** a
  batch job: at least five of the twelve demonstrably carry an extra-schema constraint, and writing
  twelve comfortable labels in one sitting is the original defect (audit 7 MAJOR 7).
- **`ORDER-1281`** — nothing on the commit path resolves a **live** pin. `OwnerRef` is `BUILT`, not
  `WIRED`, and that gap is the honest reason. Cost is already measured: **0.30s for 234 refs**.
- **`ORDER-1282`** — the tier budget. See §3; do not start work assuming a quiet machine.
- **`ORDER-1283`** — make the enforcement cage mutate a **copy**, then put it back in the tier. The
  design is not open: copy `run_preset_tests.py --mutate` (temp copy, anchor must match exactly
  once, 9/9 detected). Acceptance includes killing it mid-loop and finding the tree unchanged —
  **but not via `git status`**: the suite restores with LF into a CRLF checkout, so a perfectly
  clean run already shows the file as modified while `git diff` is empty. Use `git diff --quiet`.
- **`ORDER-1284`** — PART 4's undeclared-reference sweep reads **only** `scripts/_test/<suite>.ps1`,
  never the Python file it runs, **and** its regex cannot match a repo-root path. Two structural
  blind spots, measured. Widening it will redden suites that are fine — absorb them one at a time
  with reasons, never a bulk exemption list.

---

## §1 — The sequencing rule proved itself, and it generalises to the rest of the list

`ORDER-1264` first was not a preference. Its #1 (13 of 29 entities **skipped** by the enforcement
check) is *why* `ORDER-1263` was invisible, so repairing 1263 first would have produced a fix with
nothing watching it. The payoff was concrete and immediate:

> the completeness check **fired on its own author, on its first run**, naming `OwnerRef` — which I
> had left in neither set while writing the very inventory whose point is that no entity may be in
> neither set.

**Apply the same test to what you pick up next.** `ORDER-1268` (nothing refuses a partial `.set`
*entering* a run, and the check that claims to is a non-emptiness test) has the same shape: the
weak check is the reason the hole survives, so fix the check first and the hole becomes visible.

---

## §2 — 🔴 The §0.1 trap is STILL ARMED. Neither cage was touched.

The two cages that **assert the defects** are exactly as the first prompt describes them:

```
run_s11_tests.py:802          assert 'balance' in str(exc) and PLANTED_ACCOUNT in str(exc), exc
run_preset_tests.py:296-300   asserts account unit is EXCLUDED from the fingerprint
```

Nothing in this lane went near them, so **the warning has lost none of its force** — and the
temptation is real, because both go red the moment their order is repaired correctly. Change each
cage in the **same commit** as its fix, asserting the **opposite**: value **absent** and rule name
**present**; account unit **inside** the fingerprint.

### What I read of `ORDER-1267` before stopping — free groundwork, verify it yourself

I opened `safe_projection.py` intending to take this one and stopped rather than half-finish a
**secret scanner**. What I saw, offered as a starting point and **not** as a measured finding:

- `scan_forbidden(doc, known_secrets=())` returns `[]` for "clean" and `[]` for "I had no
  recognizers". That is the repo's `unreadable-input-must-refuse-not-skip` shape, and the fix is an
  explicit refusal rather than a third return value nobody checks.
- `read_for_sender()` — **the sender's one door** — calls `assert_safe(doc)` with **no**
  `known_secrets`, so the KNOWN_SECRET layer is structurally inert on the only path that matters.
  Note the hard part before you start: that function reads a projection **file** and has no
  snapshot, so it has nothing to build a recognizer list *from*. Either it is given one, or the
  honest repair is to state that the layer cannot run there and make VALUE_SHAPE carry the weight.
- `_walk` yields dict keys but only tests them against `FORBIDDEN_KEYS` — a secret used **as a key**
  is never scanned as text. That half looks cheap.

**Do not promote any of the above by fixing it. Measure it first** — the first prompt's rule about
Part 2 claims applies just as much to a predecessor's notes as to Codex's.

---

## §3 — 🔴 Budget: the tier is over its pinned number, and you will meet it on your first commit

| | measured 2026-08-03 | budget |
|---|---|---|
| full tier | **141.8s**, then **132.2s** — 27 suites, **0 failed** | 120.0s |
| per-path, a real commit | **98.2s** → **91.9s** → **89.4s** (landed on the third, 0.6s headroom) | 90.0s |

**The budget was not raised and the hook was never bypassed.** The cause is measured, not assumed:
**18 `metatester64` agents** — the concurrent `S13D` optimize batch — held every core for all of it,
and the same tier measured **95.1s** on an idle machine earlier the same day.

**What this means for you, practically:** check `Get-Process metatester64` before you plan around
tier timings, and if a commit is refused by the budget on a loaded machine, **wait for the machine**.
`--no-verify` is a standing prohibition and there is no version of this that justifies it. Filed as
`ORDER-1282`, which asks for three samples on an **idle** box before anyone touches the number.

---

## §4 — Two smaller things worth inheriting

1. **The trigger map earns its keep, twice per session — and misses more than it catches.** PART 4b
   demanded a dependency declaration on the first run after *each* change that created one, and
   neither was remembered. Budget a `scripts/gen_fast_tier_pathspec.ps1` run after any import you
   add. **But see `ORDER-1284`: PART 4 reads only the `.ps1` and cannot match a repo-root path**, so
   a green there is narrower evidence than it reads.
1b. **Search the board before you "fix" something.** `ORDER-1283` existed as a known, named,
   deliberately-deferred task on this board since 2026-07-31, and I re-created its failure by
   improving something adjacent to it. `grep` the taskboard for the file you are about to change —
   it is cheaper than the incident.
2. **A measurement table with no harness rots at about 2x per quarter.** `run_schema_cages.ps1`
   claimed 4.47s for three entries that now measure 8.8/7.1/7.9s. It was not re-derived on suspicion
   — adding a fourth entry required it. That is the argument for `-Timing` living on the wrapper, and
   the fourth instance of this failure in the repo's record.

---

## Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s). See §3.
- 🚫 Do not edit a cage to make its own FAIL go away. **§2 — the trap is still armed.**
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite (`ORDER-1262` is RATIFIED as option **B**).
- **Reserve your order block and commit the reservation before using a number.** Re-derive from BOTH
  tests. As of this lane's close the highest in use is **`ORDER-1284`** and blocks through **1289**
  are taken — **derive it yourself rather than trusting that sentence.**
- **A criterion is committed in its own commit, before the run that resolves it.**
- ⚠️ **`S-2026-08-03-S13D` may still be ACTIVE.** Check the ledger. It holds
  `factory/coverage.jsonl`, `factory/runs/pilot/**`, `factory/optimize_decisions.jsonl`,
  `_mt5_auto/**` and the `D:\Meta 5` lane. `AGENT_TASKBOARD.md` is shared — stage hunk-by-hunk into
  the **index**, because `git commit -- <path>` commits the working tree of that path.

---

## §5 — 🔴 ONE order is BLOCKED by the live lane, and the other six are not

Measured at this file's close (2026-08-03 21:2x), not assumed: `S-2026-08-03-S13D` is still `ACTIVE`,
18 `metatester64` agents are running, and its matrix stands at **12 of 16 cells**.

| | |
|---|---|
| 🚫 **`ORDER-1269` — DO NOT START IT** | its #1 is the ratified `ORDER-1257` option (b) **re-pin**, and the thing it re-pins is `factory/coverage.jsonl`. That file is **still held by S13D and will move once more** (`gen_pilot_cells.py --apply` when the matrix completes). Re-pinning now means the write invalidates the pin within the hour — which is `approval-pinning-self-invalidates`, the seventh occurrence, and the exact defect `ORDER-1269` exists to end. **Wait for that row to close.** |
| ✅ **the other six are clear** | `1260` `candidate.py`/`attestation.py`/`magic.py` · `1261` `notifier.py` · `1265` `scheduler.py` · `1266` `preset.py` · `1267` `safe_projection.py` · `1268` preset/setfile/wrapper-gen. **None is a path S13D holds**, and it released `scripts/_test/**` early (its row says so), which is where every cage fix lands |

**Suggested order, and the reason is in §1 rather than preference:** `ORDER-1268` first — the check
that claims to refuse a partial `.set` is a non-emptiness test, so the weak check is *why* the hole
survives, the same shape as `1264`→`1263`. Then `1266` and `1267`, the two carrying cages that assert
their own defects (§2). `1269` last, or in the session after this one.

**Two taxes, neither a blocker:** the tier will refuse commits while the batch runs (§3 — retry, or
stage fewer `scripts/_test/**` paths per commit; **never `--no-verify`**), and `AGENT_TASKBOARD.md` is
shared with S13D, so stage it hunk-by-hunk into the **index**.

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_2.md` ทำต่อเลย — จองบล็อก 1290-1299 ก่อน · ข้าม ORDER-1269 ไว้ก่อน (S13D ยังถือ `factory/coverage.jsonl`) · เริ่มที่ ORDER-1268"**
