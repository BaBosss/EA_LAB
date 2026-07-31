# GUARD SHAPES — the four ways a check in this repo goes wrong

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the pre-flight checklist for
> writing or closing a guard** · the mechanical half is `_triage/factory_os/run_guard_shape_lint.py`

Two blind audits produced **24 findings across three slices**. They are not 24 different mistakes.
Sorted by shape they are **four**, each repeated four or more times, by the same author, often
inside the file written to prevent the previous instance.

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

## Before closing any Order that contains a guard

- [ ] every read declares its snapshot (`run_guard_shape_lint.py` proves it)
- [ ] every criterion is named by its suite (same lint)
- [ ] every criterion has been **observed red for its own reason**, not merely red
- [ ] every closed vocabulary is closed at **both** ends — the key set *and* the values
- [ ] every number in the write-up came from a command in the same session
- [ ] every negative names its scope: *my commits*, not *the range*
- [ ] the guard's own limits are stated **in the guard**, not implied

<sub>**Why the checklist is here and not in a doc nobody opens:** `strip_invisible` was repaired against the seven hiding techniques an auditor named, and **two were still open** afterwards — found by probing all seven rather than trusting the repair. **Fixing what an audit names is not the same as fixing what it found.** The same applies to this list: it is the shapes seen so far, not the shapes that exist.</sub>
