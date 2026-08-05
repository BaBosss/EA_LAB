# OPENING PROMPT — the corrections lane, part 3. Three of the nine are repaired; `ORDER-1267` has never been touched.

> Written 2026-08-03/04 by lane `S-2026-08-03-CORRECT2`, which repaired **`ORDER-1268` in full** and
> **`ORDER-1266` two defects of seven**. This is the third seat in the same chain — `_triage/PROMPT_NEXT_SESSION_CORRECTIONS.md`
> is still the map and `_triage/PROMPT_NEXT_SESSION_CORRECTIONS_2.md` is still worth reading for §2
> (the cage trap) and §3 (the budget). This file records what moved and the two things it learned
> that change how you should approach the rest.

---

## §0 — 🔴 READ THIS FIRST: A SECOND LANE IS LIVE, AND IT IS NOT THE ONE THE LAST PROMPT WARNED YOU ABOUT

`S-2026-08-03-S13D` is **CLOSED** (2026-08-03 23:10). Its successor **`S-2026-08-04-S13E` is `ACTIVE`**
and holds a different set of paths. Verify in `docs/SESSION_LEDGER.md` rather than trusting this line
— but plan for concurrency either way.

| | |
|---|---|
| 🚫 **`S13E` holds** | the MT5 lane `D:\Meta 5` · `factory/**` selection output and `factory/coverage.jsonl` (via `gen_pilot_cells.py --apply` only) · `scripts/pilot_probe_*` · **`scripts/_test/**` for `ORDER-1272`'s control cage** · **`.githooks/**` + `$FAST_SUITES` registration** · `_triage/factory_os/**` *only* where `ORDER-1272` forces the `EvidenceSource` read migration · `AGENT_TASKBOARD.md` rows `1272` `1273` `1274` `1254` `130x` |
| ✅ **it explicitly does NOT hold** | **`ORDER-1257`/`ORDER-1269` #1 — its own row says the corrections lane owns the pin instrument.** No routing question to settle; it is already settled in writing |

**Three real collision points, and none of them is the work itself:**

1. **`scripts/_test/run_fast_cages.ps1` and `.githooks/fast_tier_pathspec`.** Both lanes edit
   `$SUITE_GUARDS`, and the pathspec is **generated** — two lanes regenerating it produce conflicting
   bytes. Touch it in a **path-limited commit of its own**, immediately after
   `scripts/gen_fast_tier_pathspec.ps1`, and re-run `run_guard_trigger_tests.ps1` before staging.
2. **`AGENT_TASKBOARD.md`.** Shared. Stage **hunk-by-hunk into the INDEX** — `git commit -- <path>`
   commits that path's *working tree*, so a concurrent writer's in-progress edit rides along. This has
   now happened twice in this chain (`99c73bd9` carried a block of another lane's).
3. 🔴 **The tier budget, and this one will bite on your first commit.** `ORDER-1254` is BWD 2020–22 on
   the MT5 lane. When that batch runs, **18 `metatester64` agents hold every core** and the same tier
   that measures 86–95s idle measured **141.8s / 132.2s** loaded, with a per-path commit refused
   **twice** at 98.2s and 91.9s before landing at 89.4s. **Check `Get-Process metatester64` before
   reading any tier timing as a regression, and if a commit is refused, wait for the machine.**
   `--no-verify` is a standing prohibition and there is no version of this that justifies it.

---

## §1 — What is DONE, so you do not re-derive it

| order | state | one line |
|---|---|---|
| **`ORDER-1264`** | ✅ DONE `14276944` | a lost `x-enforced-by` reddens instead of vanishing |
| **`ORDER-1263`** | ✅ DONE `007e9f65` | `OwnerRef` resolves — R1 blob · R2 identity · R3 sha256 · R4 anchor |
| **`ORDER-1268`** | ✅ DONE `e5d81804` + `b14c7b84` | a partial surface is refused on the evidence path and refused-or-recorded on the run path |
| **`ORDER-1266`** | ⏳ **2 of 7** `26746f04` | the magic-number collision and the undeclared-exception escapes are fixed; **#1 is analysed, not done — read §3** |

### 🎯 The one finding from `ORDER-1268` that should change how you open `ORDER-1267`

The order's title said *"nothing refuses a partial `.set`"*. **That was half right, and the wrong half
cost nothing only because it was checked first.** The refusal already existed, fully written and
mutation-caged — `setfile.read_set(text, surface, require_full_surface=True)` refuses a partial file
and names every missing key. **Its only caller in the entire repository was its own test suite**,
while the map that actually reaches the evidence store was judged by a *non-emptiness test in a
different file*. The defect was a **wiring** defect wearing a **missing-feature** defect's clothes,
and the repair is smaller, and better, for having found that out before writing anything.

> **Apply this to `ORDER-1267` before you write a line of it.** `grep` the repo for the rule first:
> a secret scanner that refuses a formatted account may already exist somewhere and simply not be on
> `read_for_sender`'s path. Memory: `correct-check-exists-only-its-cage-calls-it`.

---

## §2 — 🔴 THE §0.1 TRAP: one cage is still armed, and the other one is NOT the flip you were told

`run_s11_tests.py:802` — **untouched, exactly as the first prompt describes it.**

```
assert 'balance' in str(exc) and PLANTED_ACCOUNT in str(exc), exc
```

Repairing `ORDER-1267` #1 correctly turns this red. **Change it in the same commit as the fix and
assert the opposite** — value **absent**, rule name **present**. A session that meets a red test and
"repairs" it by reverting has used the cage to reinstate the bug.

`run_preset_tests.py:296-300` — **still untouched, but do not flip it. See §3.**

### What `ORDER-1267` looks like from outside — offered as groundwork, NOT as measurement

Carried from the previous prompt because it is still the best starting point, and still **unverified**:

- `scan_forbidden(doc, known_secrets=())` returns `[]` for *"clean"* and `[]` for *"I had no
  recognizers"*. That is the repo's `unreadable-input-must-refuse-not-skip` shape.
- `read_for_sender()` — **the sender's one door** — calls `assert_safe(doc)` with **no**
  `known_secrets`, so the KNOWN_SECRET layer is structurally inert on the only path that matters.
  ⚠️ **Know the hard part before you start:** that function reads a projection *file* and has no
  snapshot, so it has nothing to build a recognizer list *from*. Either it is given one, or the honest
  repair is to state that the layer cannot run there and make VALUE_SHAPE carry the weight.
- `_walk` yields dict keys but only tests them against `FORBIDDEN_KEYS`, so a secret used **as a key**
  is never scanned as text.
- Part 2 of that audit file adds: `build_id` and `generated_at` are **unconstrained strings**, so a
  formatted account placed in `build_id` passes the schema, passes the scan, passes `assert_sendable`
  and reaches `AlertEvent.text`. **The mechanism is #1 and is measured; the end-to-end path is not.**

🚫 **Measure every one of these at HEAD before repairing it.** The rule that a Part-2 claim is not
promoted by fixing it applies to a predecessor's notes exactly as much as to Codex's — and in
`ORDER-1268` it is what turned a rewrite into a two-line rewire.

---

## §3 — 🔴 `ORDER-1266` #1 IS NOT THE CAGE-FLIP THE LAST PROMPT DESCRIBED. Read this before touching it.

The handoff said: make `run_preset_tests.py:296-300` assert the account unit is **inside** the
fingerprint. **Look at what that case actually compares first.** `base` holds `_4_TpUsd = 50 usd`,
`cent` holds `_4_TpUsd = 50 cent`, and they hash the same **because the rendered bytes are the same**
— MT5's `.set` format has no unit. So the disagreement is not about a bug, it is about **what the hash
is for**, and `_fingerprint`'s own docstring contains both answers pulling opposite ways: *"sha256 over
the CONFIG"* and *"the question this hash exists to answer is 'is the .set on this chart the .set we
validated'"*.

**The blocker is structural, not reluctance.** `ORDER-710` made that preimage a **cross-language
contract**: `ea_template/core/InputSurface_gen.mqh` is generated from the same parse and the EA emits
the same string from its live inputs at `OnInit`. Adding `account_unit` needs the EA half to produce
it — and an EA at `OnInit` **cannot reliably derive** whether it is on a cent account (broker
convention, not a platform fact), so it needs a new declared input, a compile, and a terminal.

**Do the half that carries the money harm first, and it is a different file.** *Cached USD evidence
satisfying a cent request* is decided by `scheduler.EXECUTION_KEY_FIELDS`, which is pure Python and
**measured as not containing `account_unit`**. ⚠️ **It is pure Python but it is not free:**
`ExecutionKey` is a **closed** schema with a required-field list, and `factory/runs/*.jsonl` already
holds live folded `RunJournal` rows carrying one (`RUN-20260802-001` · `-002` · `-004`, measured). A
new required field invalidates every one of them, so **that repair arrives with a store migration** —
and `factory/**` is a path `S13E` holds. Coordinate or wait.

Then decide the preimage question deliberately. **If the answer is that the surface fingerprint stays
unit-free, the cage case must be NARROWED, not flipped:** keep the comparison, delete its stated
reason. The comment *"the account unit is not visible to the EA at OnInit, so it is not config
either"* is the false sentence — not the assertion under it.

**Still open on `ORDER-1266`, with what is measured and what is not — the row has the table:**
`#3` LATENT (confirmed: **0** `sinput` declarations in the real `Inputs.mqh` today) · `#5` mechanism
confirmed **by reading** `_ordered()`, reproducer **not run** · `#4` and `#6` **not measured**.

---

## §4 — `ORDER-1269` — the blocker named in the last prompt IS GONE, and the reason it was there is worth keeping

The previous prompt said: do not start it, because its #1 re-pins `factory/coverage.jsonl` and that
file *"will move once more"*. **That write has happened** — `ec47f37d`, 16 cells at `PROBE_RUN`, and
`S13D` closed afterwards. Verify, do not trust this line:

```bash
git log --oneline -3 -- factory/coverage.jsonl
```

⚠️ **But do not read that as "the file has stopped moving forever."** `S13E`'s `ORDER-1273` re-runs
the selected configuration once before it reaches `ORDER-1254`, and any cell state change goes through
`gen_pilot_cells.py --apply`. **Check what `S13E` still intends to write before you design against
it.**

🎯 **And then notice that the ratified fix makes the question moot, which is the whole point of
option (b).** *"Wait for the store to stop moving"* is the remedy for a **naive re-pin** — options (a)
and (c), both declined. Option **(b) is "change the instrument"**: pin the **migration** and the
**generated section**, which are stable, rather than a whole store that is *designed to grow*. The S2
audit's reframing is the useful one — this is a **granularity mismatch**, not merely a
self-invalidating pin. So `ORDER-1269` #1 can be designed now, and doing it properly is what ends the
waiting.

**It also unblocks the other lane, which is the argument for doing it first.** `run_s2a_gate` and
`check_coverage_transfer` are **hand-run and RED at HEAD** until this lands, and they must **return to
the tier in the same commit as the fix** — added while red they block every commit in the repo.

🚫 **Do not** re-pin with `gen_s2a_migration.py` (D1 is inside its own bundle: a signature to repair a
signature) · **do not** append an acknowledgement (option (a) was declined) · **do not** revert the
cells. `ORDER-1269` #3 is separable and cheap: a failed pin must print `UNVERIFIED`, not `APPROVED`.

---

## §5 — Four traps this lane paid for

1. 🔴 **A wiring guard was satisfied by a COMMENT.** The check that `mt5_optimize.ps1` dot-sources the
   new library was `-notmatch 'setfile_surface\.ps1'`. Deleting the dot-source left it **GREEN**,
   because the comment two lines above the deleted statement names the library. It was found by
   **running the mutation probe**, not by reading the check. **If you write a cage asserting "file A
   uses file B", always mutate away the real use and watch it go red** — this repo's comment density
   makes a substring match green almost always. Memory: `text-scan-cannot-tell-read-from-mention`.
2. 🔴 **Fixing one escaping exception revealed a different one.** After `ORDER-1266` #2 stopped routing
   integers through `float`, `1e9999` stopped raising `OverflowError` and started raising Python
   3.12's *4300-digit int-to-string* `ValueError` — still outside the declared refusal set. **Chasing
   exception types finds the next one forever; bound the DECLARED TYPE instead** (`int` is 32-bit,
   `long` is 64-bit) and every spelling is answered at once.
3. ⚠️ **`open(p,'wb')` truncates before your encode can fail.** A `UnicodeEncodeError` while building
   the bytes left `docs/SESSION_LEDGER.md` at **0 bytes**. Build the blob first, open second — and
   surrogate escapes (`\ud83d\udd34`) are not emoji in Python source; use `\U0001F534`.
4. ⚠️ **PART 4b's import sweep will demand declarations twice per session** and it is right both
   times. `ORDER-1268` added three (`preset.py`, `setfile.py`, `registry.py` reached through
   `candidate.py`) and then two more once the new library existed and was untracked. Budget a
   `scripts/gen_fast_tier_pathspec.ps1` run after **any** import you add — and see `ORDER-1284`: PART 4
   reads only the `.ps1` and cannot match a repo-root path, so a green there is narrower than it reads.

---

## §6 — Suggested order, and the reason is a dependency rather than a preference

1. **`ORDER-1269`** — because the other live lane is **blocked on it** (two checkers hand-run and red
   until it lands), and because §4's option-(b) reasoning means it no longer has to wait for anything.
   #3 (`UNVERIFIED` instead of `APPROVED`) is separable and can land first, on its own.
2. **`ORDER-1267`** — the last untouched 🔴, and the one carrying an armed cage. Open it with §1's
   `grep`-first rule and §2's measure-before-repairing rule.
3. **`ORDER-1266` #1** — only the `EXECUTION_KEY_FIELDS` half, only after checking whether `S13E` has
   released `factory/**`, and only with the store migration planned rather than discovered.
4. **`ORDER-1260`** (five defects on the money path) and **`ORDER-1261`** (a reopened incident silenced
   forever) are still untouched from the original nine. **`ORDER-1265`** likewise.

---

## Standing rules that did not change

- 🚫 No EA verdict from automation — design §10 stops S13 at `EVIDENCE_COMPLETE`.
- 🚫 Do not raise `$FullTierBudgetSeconds` (pinned 120.0s). See §0.3.
- 🚫 Do not edit a cage to make its own FAIL go away. **`run_s11_tests.py:802` is still armed.**
- 🚫 Do not re-add `run_enforcement_status_tests.py` to the tier before it mutates a **copy**
  (`ORDER-1283`) — the argument for adding it is genuinely good, which is exactly why it is dangerous.
- 🚫 `MASTER_BACKLOG.md` §2 outside an owner-approved `gen_coverage --apply` · `AGENTS.md` ·
  `PROJECT_STATE.md` · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite (`ORDER-1262` is RATIFIED as option **B**).
- **Reserve your order block and commit the reservation before using a number. Re-derive from BOTH
  tests** — every `## ORDER-<n>` across all four board files **and** every reserved block in the
  ledger. At this file's writing the highest in use is **`ORDER-1291`** and **`1300-1309` is held by
  the ACTIVE `S13E` lane**, so the next free block is **`1310-1319`** — **derive it yourself rather
  than trusting that sentence.** It has been hand-repaired nine times and was stale by twenty-one
  blocks once.
- **A criterion is committed in its own commit, before the run that resolves it.**

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CORRECTIONS_3.md` ทำต่อเลย — จองบล็อกใหม่ก่อน (S13E ถือ 1300-1309 อยู่) · เริ่มที่ ORDER-1269 แล้ว 1267"**
