> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **shift-change note for lane
> `S-2026-08-02-FACTORY78B`** — the continuation lane that finished slice **S7** and built the
> generator half of **S8**. A note, not a queue: every forward item below already has a row on
> `AGENT_TASKBOARD.md`.

# Session end — 2026-08-02, `S-2026-08-02-FACTORY78B`

**Slice S7 is CLOSED. Slice S8's generator is built, caged and compiling; its parity harness is
not.** The lane was opened on the previous handoff's own recommendation — that the remainder of S7
and the whole of S8 be done together, because the two are entangled — and that turned out to be
right for a reason nobody had written down: **every defect found today was invisible while the
registry stores were empty.**

## S7 — CLOSED, all three acceptance criteria measured

| criterion | result |
|---|---|
| `param_registry_check` CLEAN | ✅ — and it now runs the design §5.4 **state table** too, so the one command covers both halves. It used to be a *name* check only. |
| zero `UNKNOWN` on Boss_14's Operator surface | ✅ **0**, on real rows, enforced by criterion **P3** |
| an old `.set` migrates or fails loudly | ✅ **42 real fires** on 50 template `.set` files (closed in the previous lane) |

**The numbers.** `factory/parameter_bindings.jsonl` carries **232 rows** (116 per hypothesis) and
`factory/hypotheses.jsonl` its first **2 Hypothesis rows** — B14-H01 and B14-H02, design §8.1.

| revision | rows | OPERATOR | RESEARCH | HIDDEN | visible |
|---|---|---|---|---|---|
| `B14-H01-r1` | 116 | **18** | 13 | 85 | 31 |
| `B14-H02-r1` | 116 | **21** | 13 | 82 | 34 |

Design §5.3's target is `Operator ≤ 40` per Boss. **18** and **21**, from **116 visible inputs** —
and the number is *derived* (can this input change anything under this config?) rather than a list
of dials someone judged important.

`check_param_surface.py` holds six criteria; **P5 is the one the other five need** — five checks
that a store is internally *coherent* are all equally happy with a store that has quietly stopped
matching its source, so P5 regenerates the 232 rows and compares. Its attack is therefore the only
**coherent** one in the suite (it moves a `safe_range` bound, which no other criterion has an
opinion about), so P5 has to carry that case alone. **8/8 attacks caught.**

## S8 — the generator is built and its output COMPILES; parity is not started

`gen_wrapper.py` emits a **16-line** wrapper (`#define` and `#include` only) plus an allowlist
header of `#define LAB_CAP_*` tokens. `check_wrapper_gen.py` holds **W1** byte-identical, **W2**
zero logic, **W3** allowlist == the Hypothesis row's `module_set`, **W4** wired. **7/7 attacks
caught.**

**Measured on lane 1 (`D:\Meta 5`):** `B14_H01_r1` **0 errors / 0 warnings**, `.ex5` written ·
`B14_H02_r1` same · **`tpl_regression` CLEAN 8/8** on the same lane after the `ea_template/**`
additions.

🔴 **The first real compile found a defect all four source-level criteria had passed.** Design
§5.2's snippet shows `#include "generated/<REV>_allowlist.mqh"` **and**
`#include "../core/LabCore.mqh"` in one wrapper, which cannot both be right. MetaEditor:
`error 106: ...\generated\generated\B14_H01_r1_allowlist.mqh not found`. The file was
byte-identical to what the generator produced, contained zero logic, was fully wired and named the
right tokens. **Only the compiler knew.**

🔴 **And the obvious repair was wrong in a way only a THIRD guard could see.** Moving the wrapper up
beside the hand-written `Boss_*.mq5` compiled 0/0 — and gave `LAB_ENTRY_14` a **second translation
unit**, which `gen_locked_constants.py` refuses by design (*"two translation units for one build
means the closure this module walks is one of two the compiler could build, and picking either
makes the fingerprint a coin toss nobody can see"*). `check_input_surface_gen` refused the whole
tree. **Final placement: both artifacts in `generated/`** — the allowlist included from the same
directory, LabCore from `../core/`. So §5.2 was right about the second include line and wrong about
the first. `ea_template/*.mq5` stays at exactly one wrapper per build tag and the nine-target
compile policy is untouched.

<sub>Two cage defects surfaced during that move, and both are worth more than the move. **W4 matched
the allowlist include as a directory-qualified path**, so it went red for a wrapper that was
correct — what it actually asserts is that the wrapper reaches *its own* allowlist, and the
directory relationship is the generator's to decide. And **two fixtures used a bare `str.replace`
against a path that had moved**: `replace` without its needle is a silent no-op, so the "corrupted"
artifact was byte-identical to the real one, `check()` correctly found nothing wrong, and the suite
printed *"NOT CAUGHT BY W2 … nothing at all"* — which reads as *the checker is broken* when the
checker was fine. Every fixture now goes through `_mutate()`, which **refuses when its anchor is
absent**. A fixture that quietly mutates nothing is the same defect class as a guard that quietly
checks nothing, and worse, because it accuses working code. The stub reader also normalises
newlines the way `EvidenceSource` does — git's autocrlf is what made the two fixtures miss.</sub>

## 🔴 Three defects the real rows exposed, all of which had been invisible

**This is the durable lesson of the session, and it generalises past this repo:** an *empty* store
answers `UNBOUND` to every question and spawns no validator, so a broken consumer and a correct one
produced **identical output** for as long as there was nothing to read. Every green case stayed
green while proving nothing.

| | |
|---|---|
| **`ORDER-1030`** | `optimize_guard` passes `--build-tag=14`; every binding spells it `LAB_ENTRY_14`. The literal matched no key, came back `UNBOUND`, and `ORDER-671` turns that into a REFUSAL — so the guard **refused every parameter of every declared revision** and printed `role=''`. **The verdict was right by accident and the reason was wrong**, which is worse than a wrong verdict: a real `LOCKED` binding and a tag typo produced identical output. That is `F1`, the defect `ORDER-672` split `build_tag` out to kill, **reappearing at the consumer seam.** Fixed in `registry.canonical_build_tag()` — the one module allowed to know the encoding — and an unrecognised spelling now **REFUSES by name**. |
| **`ORDER-1031`** | `run_schema_fixtures` validated the live stores with **one `ajv` spawn per row**. **2.3s → 77.2s** at 234 rows: ~**0.32s per row, linear** in a store the design intends to grow 10×. 2,000 rows would be an **eleven-minute pre-commit hook**, which is how a tier earns `--no-verify`. Batched → **3.4s**; `run_contract_binding_tests` **100.9s → 26.8s**. |
| **the cage's own fixture** | `run_registry_tests` used `$rev = 'B14-H01-r1'` — fictional when written, **real** as of today — against a `-BindingsRoot` that **ADDS** rather than replaces. Its three UNBOUND cases were never isolated. Now `B14-H99-r1` **plus a PRE-CHECK that asserts the canonical store binds nothing under it.** |

<sub>Two smaller ones in the same family: `run_registry_tests.py` bound `BUILD_A`/`BUILD_B`, values
`schemas.json` **forbids**, so the whole tag-join section exercised the join over data that cannot
exist; and one assertion required the real store to be **empty**, which was an artifact rather than
an intent and is now a discriminating pair.</sub>

## What remains on S8, in the order it has to be done

1. **`Inputs.mqh` capability-token rollout, Boss_14 only** (the owner's ratified per-Boss shape).
   Until it lands the tokens are defined and `Inputs.mqh` ignores them, so a generated wrapper
   compiles to a binary **identical** to the hand-written one. **That is the safe order** — it
   makes parity case 1 a check on the *generator alone*. Doing both at once gives a parity failure
   two candidate causes and no way to tell them apart.
   <br>**Two conventions coexisting is EXPECTED, not drift.** A guard that reports "partially
   rolled out" as a failure makes rollback the cheapest fix.
2. **The 7-point parity harness** (§5.5, cases in `META_parity_cases`). Shares `tpl_regression`'s
   trigger ⇒ **share its lane pin and its runner**, and it must assert **the binary it measured is
   the binary it built**. The **must-trade** and **deliberate-refusal** cases are not optional.
3. Only then does evidence from a wrapper count — evidence from an unparified wrapper is **void**.

**Already in place:** the token derivation · the const/input split (`activation.classify()`, 78 of
116 unreachable under B14-H01) · the `[CFG]` `effective_config_hash` over surface **and** locked
constants, so **parity point 2 is already emittable and already comparable by a tester run**.

## Still owed to the owner (unchanged, and NOT acted on)

Two disagreements between the **generated contract** and the **shipped `docs/PARAM_REGISTRY.csv`**,
recorded on `ORDER-1020`: the `classification` vocabulary (`OPERATOR/TUNING/OVERRIDE/DEAD` vs the
shipped `ACTIVE/INACTIVE/OVERRIDE/COMPATIBILITY` that `registry.py:136` reads **by name**), and
`unit_true`/`coupled_with` vs `unit`/`coupled_parameters`. **Nothing checks the CSV against that
table**, which is why they could disagree at all. Changing the CSV would silently move what
`optimize_guard` decides.

## Lane hygiene — a SECOND block collision in one day, same shape

`S-2026-08-02-CENSUS` reserved **1030-1039** one commit after this lane did, and read the *closed*
`FACTORY78` row rather than the *active* `FACTORY78B` one. It opened no order, so nothing had to be
renumbered this time. **Both of today's collisions have one cause:** the reservation procedure
everyone follows derives the next block from *the highest ORDER NUMBER IN USE*, not from *the
ACTIVE lanes' reserved blocks* — so a block that is reserved but not yet used is **invisible** to
it. `check_order_collision.ps1` already parses the ACTIVE blocks; a `-SuggestBlock` mode derived
from them would end this. **Not built here** — it is `BACKLOG-D29`'s family and wants its own order.

## Cage state at close

- fast tier **green, 21/21, 0 failed** · per-path **20.5s of 65.0s** on the last commit · **full tier 88.9s of 90.0s — 1.1s of headroom, and `ORDER-820` is open on exactly that number**; the widest commit of the
  session peaked at **160.7s** and was brought to **65.9s** by fixing `ORDER-1031` rather than by
  raising the number
- new suites, each measured before adding per `ORDER-673`: `run_param_surface_tests.ps1` **0.7s** ·
  `run_wrapper_gen_tests.ps1` **0.3s**
- **`tpl_regression` CLEAN 8/8**, lane 1, after every `ea_template/**` change
- compile **0 errors / 0 warnings** on both generated wrappers; the **nine-target** policy is
  untouched by design
- `L0` demanded the checker registration on its first run **twice** today (the sixth and seventh
  consecutive times). Remembering the list is not the same skill as writing the checker.
- **No EA verdict issued.** This session produced machinery.

<!-- HANDOFF-ROUTING -->

| รายการ | ปลายทาง |
|---|---|
| S7: registry rows, Operator surface, state table, `param_registry_check` | ORDER-1020 |
| S8: `Inputs.mqh` token rollout, then the 7-point parity harness | ORDER-1021 |
| the build-tag join defect and the cage fixture that was never isolated | ORDER-1030 |
| the live-row schema guard's per-row `ajv` spawn | ORDER-1031 |
| `classification` vocabulary and `unit_true`/`coupled_with`: contract vs shipped CSV | ORDER-1020 |
| block reservation derived from order numbers instead of ACTIVE blocks | BACKLOG-D29 |
