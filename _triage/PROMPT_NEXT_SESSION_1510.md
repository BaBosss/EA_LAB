# OPENING PROMPT — one signature still blocks seven files, and two orders are now decided but unwritable

> Written 2026-08-06 by lane `S-2026-08-06-S1500` (block `1510-1519`), which worked `ORDER-1500` to
> the end of what its blockers allow, then measured `ORDER-1461` item 2.
> ⛔ **Supersedes `_triage/PROMPT_NEXT_SESSION_1500.md`.** Its §0 and §6 are carried forward here.

---

## §0 — 🔴 READ FIRST: still SEVEN files of finished work, uncommitted, unchanged

```
_triage/factory_os/schemas.json              _triage/factory_os/run_schema_fixtures.py
_triage/factory_os/CONTRACTS.md              scripts/_test/run_fast_cages.ps1
.githooks/fast_tier_pathspec
```

<sub>Five paths, two of which carry both `ORDER-1330`'s and `ORDER-1461`'s work. They land together
in one commit or not at all. `STATUS.html` and `portfolio/daily_monitor.log` are also dirty and were
already dirty before this lane opened — they are **not** part of the pile.</sub>

⚠️ **Do not `git checkout` / `git restore` anything before reading that list.** A patch copy lives in
an older lane's scratchpad, and **a scratchpad is not storage.**

🔴 **This lane makes the pile more expensive, and that is the news.** `ORDER-1500`'s fix is now fully
specified and *proven* — and it lands in `run_schema_fixtures.py` and `schemas.json`, which are two
of the five. **One signature now gates three orders' finished thinking**, not two.

---

## §1 — 👤 DECISIONS. #1 is unchanged and now blocks more. #5 is unchanged. #6 and #7 are new.

| # | decision | why it is yours |
|---|---|---|
| **1** 🔴 | **`ORDER-1462` — re-make the s2a attestation.** The exact line to append is in the `ORDER-1462` row; fill `decided_at` and `reason`. | Verified RED again today: `F1 line 10 attests bundle e28c5c9d68bb, current bundle is 2ce1ea874449`. 📌 The template flag is `check_s2a_attestation.py --template`, **not** `run_s2a_gate.py`. |
| **5** | **The fast tier has 6.2s of headroom inside a recorded 6.3s load spread.** Unchanged — displace a suite, raise the pin, or accept that a busy afternoon refuses commits. 🚫 This lane registered nothing and moved nothing. | The pin is `$FullTierBudgetSeconds`; moving it is a deliberate two-file act the cage enforces. |
| **6** 🆕 | **`factory/runs/`: the S2a retention window says PRUNE these, and pruning them breaks a reader.** The migration row's own text says the checkpoint *"MUST be pruned or it becomes a second, stale copy of the timeline"* — these three are four days past that. But `check_pilot_acceptance` 8.6.11 returns a **named** `BLOCKED` off them and returns an **unnamed** one without them. | A retention policy against the only three run manifests the repo has. Both options lose something real. |
| **7** 🆕 | **`ORDER-1461` item 2 — what are the Experts-root copies?** Now answerable over the right objects (§3.2). My recommendation: **make the root a build output** (the only option that also disposes of `_OLD`/`_OLD2`), fix the banner's `NO_SOURCE` wording first, and repoint the **3 tracked board templates** rather than the 53 gitignored artifacts. | A run-path/ops decision, and `_OLD` disposal touches binaries. |
| 2 | **Deploy the instrumented `(EXP)_IchiADX_Naked_rev00` to the four VPS charts?** Unchanged. | `ORDER-1000` A2/A3 needs it there; shipping an `.ex5` to a live fleet is yours. |
| 3 | **Re-run `ORDER-430` / `ORDER-1420`?** 🚫 Still not recommended. | 16 Model-4 runs to re-confirm a negative. |
| 4 | **Does an `ORDER-236` lever-park take a scorecard row?** Still untouched by any lane. | A lever verdict on an existing chassis. |

---

## §2 — What landed (6 commits, `7670e680` … `db018443`)

| what | outcome |
|---|---|
| `ORDER-1500` | **ALL THREE OWED ITEMS DECIDED AND MEASURED** — and the measurement moved two of the three answers. Code specified, blocked. |
| `ORDER-1461` item 2 | **MEASURED** — the counts hold, the question's objects do not. A second live permanent-UNKNOWN found. |
| `docs/SESSION_LEDGER.md` | rule 6.2 fixed **on the third attempt** — see §4.2, it is the best mistake in this lane |

---

## §3 — 🎯 What the measurements found

### 3.1 `ORDER-1500` — the store is *declared*, the caller is missing, and the rows break the contract **twice**

- 🔴 **A correction to the order's own framing.** It said the store sits in a *"third state — not
  validated and not declared unvalidated"*. **The second half is false:** `RunTransition` carries
  `x-enforcement-status: "PLANNED"` and `check_schema_structure.py:321` already reads it. The store
  **is** declared unvalidated, and `x-owner-file` has named `factory/runs/<run_id>.jsonl` all along.
  **What is missing is a caller.** The substance stands; "undeclared" was one word wider than the
  evidence — *the identical error the previous lane had just retracted while opening this order.*
- 🔴 **A second break nobody had seen:** `execution_key.ini_hash` is an unevaluated property **at
  HEAD today**, unrelated to the fingerprint. The owner moved `ini_hash` to `RunAttempt` on
  2026-08-02; `scheduler.py` got a migration, `schemas.json` got none.
- ⚠️ **Seeing it needed a control.** Against the schema's real root — a `oneOf` over 19 entities —
  all three rows report a missing `owner_type`, a property `RunTransition` does not have. That is
  `ajv` naming a *branch*, not the instance. **Pinning the root to `#/$defs/RunTransition` is the
  only reason the real defect was legible.**
- 🎯 **The direction is fail-OPEN, measured.** `find_cached` returns `hit=None` for any writer that
  actually hashes ⇒ the store joins to nothing and the cost is a **re-run**, never a false cache
  hit. Both readers were driven; **neither took a wrong decision off the bad field.**

### 3.2 `ORDER-1461` item 2 — the counts are right, the objects are not

**`53` / `657` reproduce exactly.** But: **five** spellings of one EA, not two, all five resolving to
a real binary with a distinct sha256 (mtimes 2026-07-18 → 2026-08-02) · the 53 configs are
**gitignored** (`git ls-files '*.ini'` = **2** of **10,777** on disk), so the durable objects are the
**11 writer scripts** and the **3 tracked board templates** · and 🔴 **a second live
permanent-UNKNOWN**: both `_OLD` names return *"produced no record"* because
`check_stale_binaries.ps1:396-400` files a binary with no `.mq5` as a third party's. **Right for the
report, wrong at the banner** — *"I could not see this file"* vs *"I saw it and decided it was not
mine to judge."* Reachable, and already reached by one ini config each.

---

## §4 — ⚠️ Mistakes. All three are mine and all three were caught by an instrument, not by reading.

1. **My proposed design was half inert, and only check 4 found it.** `ORDER-1500`'s fix originally
   had two mechanisms; turning one off changed nothing, because `execution_key` is written **once**,
   on the `QUEUED` line, so the rows it would have migrated are exactly the rows the exemption
   already covers. **It would have shipped as a mechanism nobody could ever watch fire.** Dropped —
   and not for being harmless: *a validator that silently migrates its input is lying about the
   corpus.*
2. 🔴 **The note explaining the defect re-created the defect.** My ledger order-block cell named a
   neighbouring lane's block beside its own, so the guard reported this lane enforcing a range it
   does not hold. My *fix* added a sentence **quoting the guard's output verbatim** — putting three
   more range tokens back into the parsed cell and taking the enforced list from three to four.
   **Three attempts.** The cell is prose to a reader and parser input in the same bytes.
   ⇒ **Neither bad version was catchable by reading. Both were caught because
   `check_order_collision.ps1` prints the list it enforced, not just its verdict.** A guard that had
   printed `PASS` alone would have been silent through all three.
3. **My own recount instrument was broken and produced a confident, wrong table.**
   `grep -oE "^Expert=[^\r]*"` — GNU grep reads `\r` in a bracket expression as *backslash or `r`*,
   so every value truncated at its first `r` (`Expert=PivotB`, `Expert=(Boss)_LondonConsoB`). It
   looked like a frequency table of EA names. Same family as
   `prove-the-instrument-can-see-the-file`, one layer up: **the file was readable; the pattern was
   not.**

---

## §5 — What is OWED, in the order I would do it

1. 🔴 **Land the seven files** — §0. One `git add` + commit the moment `ORDER-1462` is signed.
2. 🔴 **Then immediately write `ORDER-1500`'s caller**, because it lands in two of those same files
   and is fully specified: a live pass beside the existing registry-store pass in
   `run_schema_fixtures.py` validating every committed `factory/runs/*.jsonl` line against
   `RunTransition`, with a **closed 3-row exemption** and `x-enforcement-status` `PLANNED` → `WIRED`
   **in the same commit**. ~30 lines. 🚫 Do **not** add the `LEGACY_DROPPED_KEY_FIELDS` strip — it is
   measured inert (§4.1). 🚫 Do **not** add the store to `STORES`.
3. **The `ini_hash` half of §3.1** — the schema still has no counterpart to the scheduler's
   migration. Decide it explicitly; it is currently a live disagreement between a writer and its
   contract, not a legacy footnote.
4. **§1 decision 5** — the tier budget. Nothing more should be registered until it is answered.
5. **`ORDER-1461` item 2** — §1 decision 7. The banner wording fix is small, is **not** in the
   blocked pile, and is the honest-naming half of item 1 rather than new work.
6. **`ORDER-236` Row-X** — pending §1 decision 4. Still untouched by any lane.
7. **`ORDER-501`, the honest remainder** — STEP 2 verified on two FAST runs; the failure mode lives
   above ~861s of wall-clock and was not reproduced. 🚫 Do not close it by re-running until one is
   slow.

---

## §6 — Standing rules that did not change

- 🚫 No EA verdict from automation · 🚫 `$FullTierBudgetSeconds` pinned at **120.0s**.
- 🚫 `AGENTS.md` · `VISION.md` · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set`
  migration · any magic allocate/renumber/retire · any history rewrite.
- 🚫 **`ea_template/core/` is owner-refused** for the two-sided `Boss_14` change.
- 🚫 **No `.ex5` to the VPS** without an explicit ruling.
- 🚫 **Do not relax `^(v[0-9]+:)?[0-9a-f]{64}$`** and do not rewrite the three `factory/runs/` rows.
- **Stage in one call, read the diff in another, commit in a third.**
- **Derive your block yourself immediately before staging**, and re-check `git log -1` against the
  read in the same minute. Highest `## ORDER-<n>` = **1500**; highest block held by a lane row =
  **`1510-1519`** (this lane); next free = **`1520-1529`**. 🔴 **Do not trust that sentence** — and
  note §4.2: getting the *cell* right is a separate act from getting the *number* right.
- ⚙️ **Machine state at handoff:** 0 MT5 processes started by this lane, HEAD `db018443`, working
  tree carries the five §0 files plus `STATUS.html` and `portfolio/daily_monitor.log` (both
  pre-existing). `EA_LAB_DailyMonitor` next fires **2026-08-07 07:30** and commits by itself — do not
  start a repo-stability measurement across it.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the s2a attestation, now blocking three orders' work | `ORDER-1462` · 👤 the owner |
| the uncommitted schema + tier-registration pile | `ORDER-1330` · `ORDER-1461` |
| the run-journal caller, specified and proven | `ORDER-1500` |
| the `ini_hash` disagreement between writer and contract | `ORDER-1500` · `ORDER-1330` |
| the retention window vs. the only three manifests | 👤 the owner |
| the fast-tier budget, inside load variation | 👤 the owner |
| the Experts-root copies, now five not two | `ORDER-1461` · 👤 the owner |
| the banner's `NO_SOURCE` wording | `ORDER-1461` |
| the slow-run status the concurrency case will name | `ORDER-501` |
| the lever park | `ORDER-236` |
| deploying the instrumented IchiADX build | 👤 the owner |
