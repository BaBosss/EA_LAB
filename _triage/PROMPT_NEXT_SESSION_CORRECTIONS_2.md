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

**Three orders were opened, and one of them is cited from code:**

- **`ORDER-1280`** — the **12** contracts still carrying no enforcement declaration.
  `check_schema_structure.py` names this order in a comment *and* prints `UNDECLARED=12` in its own
  report, so leaving it unopened would have been a dangling citation. It is deliberately **not** a
  batch job: at least five of the twelve demonstrably carry an extra-schema constraint, and writing
  twelve comfortable labels in one sitting is the original defect (audit 7 MAJOR 7).
- **`ORDER-1281`** — nothing on the commit path resolves a **live** pin. `OwnerRef` is `BUILT`, not
  `WIRED`, and that gap is the honest reason. Cost is already measured: **0.30s for 234 refs**.
- **`ORDER-1282`** — the tier budget. See §3; do not start work assuming a quiet machine.

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

1. **The trigger map earns its keep, twice per session.** PART 4b of `run_guard_trigger_tests`
   demanded a dependency declaration on the first run after *each* change that created one — the new
   suite entry in `run_schema_cages.ps1`, then `evidence.py` becoming reachable from `run_s10_tests`
   through `candidate.py`'s new import. Neither was remembered; both were caught. Expect the same
   and budget a `scripts/gen_fast_tier_pathspec.ps1` run after any import you add.
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
  tests. As of this lane's close the highest in use is **`ORDER-1282`** and blocks through **1289**
  are taken — **derive it yourself rather than trusting that sentence.**
- **A criterion is committed in its own commit, before the run that resolves it.**
- ⚠️ **`S-2026-08-03-S13D` may still be ACTIVE.** Check the ledger. It holds
  `factory/coverage.jsonl`, `factory/runs/pilot/**`, `factory/optimize_decisions.jsonl`,
  `_mt5_auto/**` and the `D:\Meta 5` lane. `AGENT_TASKBOARD.md` is shared — stage hunk-by-hunk into
  the **index**, because `git commit -- <path>` commits the working tree of that path.

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_2.md` ทำต่อเลย"**
