# GUARD SHAPES — the four ways a check in this repo goes wrong

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the pre-flight checklist for
> writing or closing a guard** · the mechanical half is `_triage/factory_os/run_guard_shape_lint.py`

Two blind audits produced **24 findings across three slices**. They are not 24 different mistakes.
Sorted by shape they were **four**, each repeated four or more times, by the same author, often
inside the file written to prevent the previous instance. A **fifth** was named on 2026-07-31 after
two more audit rounds -- and its instances are not in the code under review, they are in the
repairs. See shape 5.

Read this before writing a guard, and again before closing the Order that contains it.

---

## Shape 1 — the check reads the wrong bytes

| instance | what happened |
|---|---|
| `A7` append-only | judged the **working tree**. Stage a deletion, restore the working copy ⇒ 0 problems. A commit could rewrite append-only history with the gate green. |
| `read_input` | accepted a **mixed** index/worktree pair. Fixed. Then still accepted **worktree/worktree** — the same defect, doubled. |
| `A2` baseline | joined a **pinned blob** to a **working-tree** reconciliation and called the result immutable. |
| the drift guard | regenerated against `HEAD` while its data pinned generation-time `HEAD` ⇒ red on every later commit. |

**Mechanical half: `L1`.** Every read in a checker must carry `# snapshot: index|HEAD|blob|worktree|not-a-judged-input`. It does **not** stop you reading the wrong bytes; it stops you reading bytes without saying which — the step that was skipped every single time.

**Ask:** *which snapshot is this? · is it the one a commit would contain? · do all inputs to one verdict come from the same moment?*

---

## Shape 2 — the check tests names, not values · blacklists instead of allowlisting

| instance | what happened |
|---|---|
| `A3` closed shape | checked key **names**, never **values** ⇒ `"status": "DEAD-STRUCTURAL"` carried a verdict into the store whose entire acceptance forbids one. |
| `FORBIDDEN_KEYS` | a **blacklist**. Codex walked through it with a root field named `outcome` — a name I had not thought of. |
| `unowned_evidence` | accepted any tracked file that **mentioned** the entity. `schemas.json` defines all 27, so one citation covered the whole schema. |
| `source_token` (C8) | proved a substring existed, never that the label was **derived** from it. |

**No lint.** Deciding whether a vocabulary should be closed is judgement.

**Ask:** *am I checking a name where a value is what matters? · is this a blacklist? if so, what is the allowlist? · does "X is present" actually establish the claim, or only fail to contradict it?*

---

## Shape 3 — the check cannot fail

| instance | what happened |
|---|---|
| `a4_deterministic` | rendered the same objects twice through the same function and asserted equality. A pure function of unchanged inputs. |
| `A1` second half | required a notice the **renderer always emits** ⇒ the branch was unreachable. |
| `says=[{}]` | matched the first error of any failing instance. Fixed. Then `says=[{"bogus": null}]` walked through the fix. |
| `C6` | could not fail against any file the generator produced. |
| `A8` | had **no fixture at all** after its six cases were deleted with the thing they tested. |

**Mechanical half: `L2`.** Every criterion a checker can emit must be **named** in a string literal of its suite (parsed, so a comment does not count). It does **not** prove the criterion is exercised — it proves somebody named it. A criterion nobody names is a criterion nobody tested.

**Ask:** *have I seen this red, for this reason? · what input makes it fire? · if I delete the rule, does any test notice?*

---

## Shape 4 — a claim stated without measuring it in the same breath

| instance | what was written | what was true |
|---|---|---|
| suite size | "18 mutations" | 14 |
| entity coverage | "12 entities have a negative" | 11 — the list under it had 11 names |
| a negative over a range | "No Live path touched" | an `[auto] daily monitor` commit landed **mid-session** and touched six `live_deals/*.csv` |
| rollback | "every commit revertible in isolation" | `git merge-tree` says both conflict |

**No lint** — but the rule is mechanical enough to follow without one.

**Ask:** *did I compute this number in the same command that printed it? · is this negative asserted over MY commits or over a RANGE? (a range includes writers that are not you — this repo has a scheduled committer with no ledger row) · can I paste the command that produced it?*

---

## Shape 5 — the repair is graded by the finding it closes

Named 2026-07-31 by an independent review, from three instances **in this repo's own repairs**
rather than in the code being repaired. Shapes 1–4 describe how a CHECK reads its subject wrong.
This one describes how a REPAIR gets accepted wrong.

A repair ships because the counter-example that demanded it stops firing. But the repair was
written *staring at* that counter-example, so it is the one test it can hardly fail — and a
counter-example is a **point** while the invariant it violated is a **region**. Meanwhile the
repair is NEW CODE: new reads, new branches, new parsers, entering production carrying the trust
of the finding instead of evidence of its own.

| instance | sub-form |
|---|---|
| the reader repair hashed the file, then RE-OPENED it to parse | **carries the class forward.** The counter-example pinned a timing; the invariant was "the bytes handed back are the bytes verified". A two-read fix for a two-read defect. |
| the UNBOUND note fired on every legacy call site | **collateral outside the example's slice.** The counter-example exercised one input shape; the repair changed behaviour for all of them. Caught only because a specificity assertion already existed. |
| a header-driven parser of a headerless CSV returned 0 rows | **the mechanism never engages, and the acceptance test cannot tell.** Zero rows ⇒ everything unknown ⇒ unknown is not optimizable ⇒ the attack goes green *because* the repair is broken. Fail-closed and broken point the same way. |
| `MANDATORY_SOURCE_PATHS` pinned name→path and not the name SET | pinned the counter-example's AXIS, not the invariant. A builder could still delete two of three sensors and build `reconciliation_clear: true`. |
| the LOCKED repair tested `'locked_value' not in rec` | its own refusal text is about the VALUE; `locked_value: null` walked through the check written to stop it. Shape 2, recreated inside the repair for shape 2. |

**Why the checklist missed it:** the pre-flight triggers on *"writing or closing a guard"*. A repair
does not feel like writing a guard — it feels like closing a finding — so repairs skipped the
discipline the findings had just paid for.

**Ask:** *is the acceptance test one the repair was written staring at? · restate the INVARIANT —
does any assertion check the region, or only replay the point? · what does the repair do to inputs
the counter-example never touches? · has the new mechanism been seen green FOR ITS OWN REASON — is
there an assertion that fails if the new code is inert? · **a repair to a guard IS writing a guard:
run this pre-flight on it.***

**Mechanical half, if one is wanted:** a fix commit adds TWO assertions — one that fails on the
pre-fix code for the defect's own reason (the attack), and one that fails if the repair's new
mechanism is inert or its untouched surface moved (the engagement/specificity pair).
`run_registry_tests.ps1`'s A + A2 pair is exactly this, written after the fact.

---

## Before closing any Order that contains a guard

- [ ] every read declares its snapshot (`run_guard_shape_lint.py` proves it)
- [ ] every criterion is named by its suite (same lint)
- [ ] every criterion has been **observed red for its own reason**, not merely red
- [ ] every closed vocabulary is closed at **both** ends — the key set *and* the values
- [ ] every number in the write-up came from a command in the same session
- [ ] every negative names its scope: *my commits*, not *the range*
- [ ] the guard's own limits are stated **in the guard**, not implied
- [ ] **if this is a REPAIR:** the new mechanism has an assertion that fails when it is inert, and
      the untouched surface has one that fails when it moves (shape 5)

<sub>**Why the checklist is here and not in a doc nobody opens:** `strip_invisible` was repaired against the seven hiding techniques an auditor named, and **two were still open** afterwards — found by probing all seven rather than trusting the repair. **Fixing what an audit names is not the same as fixing what it found.** The same applies to this list: it is the shapes seen so far, not the shapes that exist.</sub>
