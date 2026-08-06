# OPENING PROMPT — the signature still blocks seven files; two small fixes landed clean around it

> Written 2026-08-06 by lane `S-2026-08-06-S1510` (block `1520-1529`), which picked up the two owed
> items from the 1510 handoff that were NOT behind `ORDER-1462` and landed both.
> ⛔ **Supersedes `_triage/PROMPT_NEXT_SESSION_1510.md`.** Its §0 and §6 are carried forward here.

---

## §0 — 🔴 READ FIRST: still SEVEN files of finished work, uncommitted, unchanged

```
_triage/factory_os/schemas.json              _triage/factory_os/run_schema_fixtures.py
_triage/factory_os/CONTRACTS.md              scripts/_test/run_fast_cages.ps1
.githooks/fast_tier_pathspec
```

<sub>Five paths, two of which carry both `ORDER-1330`'s and `ORDER-1461`'s work. They land together
in one commit or not at all. `STATUS.html` and `portfolio/daily_monitor.log` are also dirty and were
already dirty before this lane opened — they are **not** part of the pile. This lane did not touch
any of the five.</sub>

⚠️ **Do not `git checkout` / `git restore` anything before reading that list.** A patch copy lives in
an older lane's scratchpad, and **a scratchpad is not storage.**

`ORDER-1500`'s fix (the run-journal caller) is fully specified and proven and lands in two of these
five — see the previous handoff §3.1/§5 item 2 for the exact shape. **Unchanged this lane.**

---

## §1 — 👤 DECISIONS. #1, #6 unchanged. #7 narrowed — the wording half is done, the disposition isn't.

| # | decision | why it is yours |
|---|---|---|
| **1** 🔴 | **`ORDER-1462` — re-make the s2a attestation.** | Unchanged. Still verified RED. |
| **6** | **`factory/runs/`: retention window vs. the only three manifests the repo has.** | Unchanged — both options lose something real. |
| **7** | **`ORDER-1461` item 2 — the Experts-root copies.** The *wording* half is done (this lane). The *disposition* — build-output vs. repoint — is still yours. My recommendation stands: build output, disposes of `_OLD`/`_OLD2` too. | A run-path/ops decision touching binaries. |
| 2 | Deploy the instrumented `(EXP)_IchiADX_Naked_rev00`? Unchanged. | Yours. |
| 3 | Re-run `ORDER-430` / `ORDER-1420`? 🚫 Still not recommended. | 16 Model-4 runs to re-confirm a negative. |
| 4 | Does an `ORDER-236` lever-park take a scorecard row? Untouched. | Yours. |

---

## §2 — What landed (7 commits, `93189f53` … `0ad806ea`)

| what | outcome |
|---|---|
| `ORDER-1461` item 1, honest-naming half | **FIXED.** `Get-StaleCheckLine` now calls the detector with `-IncludeForeign`; a binary with no matching `.mq5` reads `NO_SOURCE` with the real reason instead of a bare `UNKNOWN "produced no record"`. Verified on the real `_OLD`/`_OLD2` binaries. Cage 19/19. |
| Handoff-contract guard | **WIDENED**, measured first. `check_handoff_contract.ps1` now also triggers on `_triage/PROMPT_NEXT_SESSION_*.md` — the family every recent lane writes, which it had silently never read. 28/28 cage. |
| This lane's own ledger row | **broke rule 6.2 twice, caught both times by the guard** — see §4. |

---

## §3 — 🎯 What the measurements found

### 3.1 The `NO_SOURCE` wording fix, confirmed live

`check_stale_binaries.ps1`'s own suppression rule (*"709 foreign binaries would bury the 10 that
matter"*) is right for a full sweep and was wrong at this banner, which already narrows to **one**
name via `-OnlyName` — so `-IncludeForeign` can only ever surface that one record, and the "bury"
concern it exists for cannot fire here. On the real machine:

```
Boss_14_GridLog_OLD   : NO_SOURCE -- ...mtime=2026-07-18T09:25:14 :: no .mq5 named
                         'Boss_14_GridLog_OLD.mq5' found anywhere under D:\EA_LAB - cannot verify staleness
Boss_14_GridLog_OLD2  : NO_SOURCE -- ...mtime=2026-07-18T11:14:39 :: (same shape)
```

(previously: `UNKNOWN -- check_stale_binaries.ps1 produced no record for '...'`)

### 3.2 The handoff-guard widen: measured 19, not the 20 the previous handoff opened with

The loose `grep -l "HANDOFF-ROUTING"` used to size the previous finding **overcounted by one** —
`PROMPT_NEXT_SESSION_OPERATOR.md` mentions the marker in prose without carrying one, which is the
exact citation-vs-mention defect memory `citation-guard-satisfied-by-a-universal-file` already names.
Recounted against the guard's own `$MarkerRegex` (the literal line, not a substring): **19**.

Driven through a **scratchpad-only copy** of the script (real file untouched during measurement),
offline, with real current `AGENT_TASKBOARD.md`/`MASTER_BACKLOG.md` content: **18/19 pass clean**, and
the **1** failure was this same handoff's own routing table — `` `ORDER-1461`-adjacent `` reads as one
compound id under the contract's own hyphen-joining rule for ids (`IdPattern`), which exists on
purpose for real ids like `ORDER-098-C`. Fixed (reworded, not the regex) and reverified before the
real widen landed.

⇒ Widened for real, in its own commit, with two new cage cases (trigger + specificity: an unrelated
`PROMPT_*.md` that is not this family still no-ops) and the docstring's `TRIGGER` section kept in
sync.

---

## §4 — ⚠️ Mistakes — and the sharpest one is a repeat, in the same file, minutes after reading the lesson

1. **My own ledger order-block cell broke rule 6.2 — twice, in the same edit sequence.** v1 named
   the *previous* lane's block (`1510-1519`) beside my own (`1520-1529`) inside the derivation prose
   of the SAME cell, so `check_order_collision.ps1` enforced both as if this lane held two ranges.
   **v2 "fixed" it by quoting the guard's own output verbatim** — `` `enforcing reserved block(s):
   1520-1529, 1510-1519` `` — to explain what happened, which put `1510-1519` right back into the
   parsed cell. 🔴 **This is not a similar mistake to the one recorded in memory
   `guard-must-print-its-scope-not-just-its-verdict` two commits ago in this same session — it is
   the identical mistake**, made by the same session, after having just written the lesson down.
   Fixed on the third pass by moving the entire narrative to the status cell, where nothing parses,
   and confirmed by re-running the debug driver until the enforced list held exactly one token.
   **Neither bad version was catchable by reading; both were caught by the guard's own debug output**
   — the same argument the memory already makes, now with a second, more embarrassing data point.
2. **The first background-job driver I wrote for the handoff-contract measurement silently returned
   nothing usable**, because `Receive-Job -Wait` does not capture `Write-Host` output (the
   Information stream, 6) into its return collection by default — it only mirrors it live to the
   host. Every result read `EXIT=2` until the job's scriptblock was changed to `*>&1` (merge every
   stream into the pipeline before it leaves the child process). Same family as memory
   `writehost-stream6-swallows-detail`, one layer deeper: that memory is about a script's own
   stdout; this is about a **caller** losing a **child job's** Write-Host, which is a different
   plumbing hazard with the same symptom (silent, not an error).

---

## §5 — What is OWED, in the order I would do it

1. 🔴 **Land the seven files** — §0. One `git add` + commit the moment `ORDER-1462` is signed.
2. 🔴 **Then immediately write `ORDER-1500`'s caller** — fully specified, ~30 lines, lands in two of
   those same five files. See the `1510` handoff §3.1/§5 item 2 for the exact design (closed 3-row
   exemption, no `LEGACY_DROPPED_KEY_FIELDS` strip — measured inert).
3. **The `ini_hash` disagreement** between `scheduler.py`'s migration and `schemas.json`'s contract
   — still live at HEAD, still undecided.
4. **§1 decision 6** — the `factory/runs/` retention window vs. the only three manifests.
5. **§1 decision 7's disposition half** — build-output vs. repoint, now answerable over the right
   objects (five spellings, gitignored configs, eleven writers, three tracked templates — see the
   `1510` handoff §ITEM-2-FACTS on the board for the full table).
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
  **`1520-1529`** (this lane); next free = **`1530-1539`**. 🔴 **Do not trust that sentence** — and
  🔴 **the sharper warning this lane adds: getting the number right does not mean the CELL is
  right.** Put derivation reasoning that mentions ANY range-shaped substring — including a
  neighbour's block, including a quote of the guard's own output — in the **status** cell, never
  the **order-block** cell. Verify with a debug driver before trusting your own row, not after.
- ⚙️ **Machine state at handoff:** 0 MT5 processes started by this lane, HEAD `0ad806ea`, working
  tree carries the five §0 files plus `STATUS.html` and `portfolio/daily_monitor.log` (both
  pre-existing). `EA_LAB_DailyMonitor` next fires **2026-08-07 07:30** and commits by itself — do not
  start a repo-stability measurement across it.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the s2a attestation, blocking three orders' work | `ORDER-1462` · 👤 the owner |
| the uncommitted schema + tier-registration pile | `ORDER-1330` · `ORDER-1461` |
| the run-journal caller, specified and proven | `ORDER-1500` |
| the `ini_hash` disagreement between writer and contract | `ORDER-1500` · `ORDER-1330` |
| the retention window vs. the only three manifests | 👤 the owner |
| the fast-tier budget, inside load variation | 👤 the owner |
| the Experts-root disposition (wording half done) | `ORDER-1461` · 👤 the owner |
| the slow-run status the concurrency case will name | `ORDER-501` |
| the lever park | `ORDER-236` |
| deploying the instrumented IchiADX build | 👤 the owner |
