# HANDOFF — `S-2026-08-01-OPERATE` (the operate track, run in parallel with the Factory OS lane)

> ⚠️ canonical entry = **`PROJECT_STATE.md`** · this file owns: **the shift-change note for lane
> `S-2026-08-01-OPERATE` only** — one handoff per lane, not per repo (Decision log 2026-07-26).
> It is **not a queue**: every forward item below has a home on a board, listed in the routing
> table at the end. Lane closed 2026-08-01. Block `740-749`, no MT5 lane reserved.

## What this lane was asked to do, and why almost none of it survived contact

The opener was [`_triage/PROMPT_PARALLEL_OPERATE.md`](PROMPT_PARALLEL_OPERATE.md), written the same
day by the previous session. It listed four tasks, ranked them, and — this is the part worth carrying
forward — **it was itself written as a correction of `PROJECT_STATE` §7 drift, and closed with the
lesson "check a claim against the boards before acting on it, including claims made by a previous
session, including mine."**

**Three of its four load-bearing claims were wrong, each by the same mechanism it warned about.**
Not one was wrong because the underlying facts were unavailable — every correction below came from
files that were sitting in the repo the whole time.

### 1. The priority number: two true counts joined into a false sentence

The opener closed with *"18 judge decisions land within 90 days … and 11 ACTIVE rows have no
pre-registered kill criterion … a judge date arriving with no criterion is not a weak judgement, it
is the absence of one."*

Both counts are **correct**. The sets are **disjoint**:

- all **18** ACTIVE rows with a judge date inside 90 days already carry a `kill_rule`
- all **11** rows with an empty `kill_rule` have **no judge date at all**, and every one sits on
  account `159475669`, whose every row is annotated *"user mix - lab does not certify this account"*

⇒ **the number of rows that reach a judge date with no criterion is ZERO.** Nobody checked the
conjunction; the conjunction was what set the priority.

**Closed** (`734681b6`): the 11 cells now read `n/a - lab does not certify this account
(retro-noted 2026-08-01)` rather than the CLAUDE.md default bar the opener specified. Writing a lab
bar onto a row the lab does not judge states a criterion nobody owns — worse than a blank, because a
blank reads *"not yet decided"* and a number reads *"decided"*. **Owner ratified** (*"เติม n/a
ไปก่อน"*).
🔴 **Say this out loud whenever the number is quoted:** `control_room_snapshot.ps1:129` counts ACTIVE
rows with a blank `kill_rule`, so its gap counter went **11 → 0 without one new kill criterion coming
into existence.** The rows are now honestly labelled, not now protected.

### 2. The MM-parts order: it exists, it was built, it was measured, it lost

The opener said the owner's *"MM-parts library (cap + linear/log)"* directive **"has NO ORDER NUMBER
and never did — write it an order first, then build"**, and ranked it the highest-EV build work.

`ORDER-098-C` **carries two different orders.** `ARCHIVE_TASKBOARD_2026-07A.md:7476` is the FVG-fill +
RSI gate (REJECT) — the block the opener found and stopped at. **`:7806` is the MM-parts library
itself, `DONE + REVIEWED 2026-07-26`.** That id reuse is one of the three collisions
`docs/SESSION_LEDGER.md` names as the reason lane reservation exists, so the failure mode was already
documented — it simply was not applied while reading. **A grep that stops at the first hit is not a
check.**

It was built: `PROG_FIBONACCI` (`core/MoneyManagement.mqh`, capped by `_56_FibMaxStep`) and
`Exit_DynCloseTargetMoney()` (`core/ExitManager.mqh`), both off-by-default and regression-clean. The
linear/log half shipped earlier still — `PROG_LINEAR`(51) · `PROG_LOG`(54) · `PROG_LOG_POWER`(55) are
in the enum and **LOG_POWER is Boss_14's live default**, itself a bounded progression. Then
**`ORDER-197`** (`REVIEWED 2026-07-24`) A/B'd the Fibonacci cap against it on Boss_14 XAU `990207`:
MAIN **1.91 → 1.83** (eqDD +30% relative), BWD 1.19 → 1.23, against a bar registered before the runs
⇒ **NOT ADOPTED**.

⇒ **writing the requested order would have commissioned work that is built, measured and closed.**

### 3. `ORDER-197`'s one open thread — reading the code inverted it again

`ORDER-197` signed off naming one survivor: *"DynClose-on-Kangaroo … remains the one open thread"*,
deferred because *"`_57_DynCloseOn` **does** run through the shared exit path so it could apply to
Kangaroo"*.

**It does not.** `Exit_DynCloseTargetMoney()` is called only from inside `Exit_ManageBasket()`
(`ExitManager.mqh:620`/`:639`), and **Boss_16 never reaches `Exit_ManageBasket()`** — `Kangaroo_OnTick`
returns first, which `LabCore.mqh:310-313` records as standing fact from `ORDER-125`'s Codex MAJOR-3
finding. The input is **inert on that chassis by construction** — structurally the same finding
`ORDER-197` *did* make about `PROG_FIBONACCI` there. **One of the two parts `ORDER-098-C` built was
checked against Kangaroo's dispatch; the other was not.**

**`ORDER-740` opened** (`ad2e125c`) for the finding that is actually there: `LabCore.mqh:314` prints
`[INIT] WARN: _2_MaxHoldBars has NO EFFECT on Boss_16`, and `_57_DynCloseOn` is inert **through the
identical mechanism** and prints nothing — so the mold teaches that inert shared inputs announce
themselves while one of them does not.

### 4. The lane map was stale within hours

The opener's collision rule 4 said the Factory OS lane *"reserves NONE, so any lane number is free"*.
The ACTIVE `S-2026-08-01-CFGFP` **held MT5 lane 1**. Consequence, since it is not obvious and it
bounded this whole lane: any `ea_template/core/**` change owes `tpl_regression` (Decision log
2026-07-06) and that cage pins lane 1 (Decision log 2026-07-30) ⇒ **this track could write core work
but not build it.**

Its collision rules 1-3 were **correct and were verified**, not assumed —
`run_front_guard_evidence_tests.ps1:106-112` really does refuse to run while `DEPLOYMENTS.csv` is
dirty, so that file was edited and committed inside one working session and never left dirty.

## `ORDER-510` STEP 1 — delivered, and it found a free rehearsal

Deliverable: [`ORDER510_ADOPT_ONCE_PROCEDURE.md`](ORDER510_ADOPT_ONCE_PROCEDURE.md) (`164e8753`).
**Written only — no VPS action, no binary copied, no GlobalVariable read or written.** The order
stays `OPEN`; STEP 2 and STEP 3 need the terminals and the owner.

Four things reading the source added that the order row did not have:

1. **🎁 A no-write rehearsal already exists in the code.** The gate is evaluated *before* migration and
   consults only `RC_AdoptLegacyHalt`, while `Persist_MigrateLegacy` honours `DryRun` ⇒
   **`RC_AdoptLegacyHalt=true` + `DryRun=true`** passes the gate, prints exactly which legacy key
   would migrate and **at what value**, and writes nothing. The value that would be adopted is named
   *before* anyone consents to adopting it.
   ⛔ **FLAT only.** `DryRun` suppresses **closes** as well as opens (`Execution.mqh:315` + six sibling
   sites) — an EA in DryRun will not exit its basket. Same condition `ORDER-511` set for a re-pin.
2. **🔴 The order's blanket "never delete a `Boss_<magic>_*` GV" contradicts the EA's own FATAL
   message**, which prescribes deletion for the foreign-account case (`RiskControl.mqh:149-153`).
   Resolved: **the prohibition's target is triggers 1-2 (`rc_kill_pending`/`rc_halted` = live safety
   state), not trigger 3 (`rc_peak_eq` = a measurement baseline).** The branch is still kept shut,
   because *establish the state is foreign* **cannot be read off the key** — the pre-132 format
   carries no login, which is the entire reason `ORDER-132` scoped it.
3. **The rehearsal fixture needs no binary archaeology** — trigger 3 fires on **existence**, so one F3
   variable named `Boss_<magic>_rc_peak_eq` on a demo terminal reproduces the refusal exactly. And the
   row's claim that `PersistMigrate_Test` cannot be the evidence is **confirmed at the line**: it is
   tester-only and refuses chart attach because it calls `GlobalVariablesDeleteAll`.
4. **STEP 3's anomaly does not block STEP 1 or 2**, but its two readings run in **opposite** directions
   and both are dangerous — a foreign *poorer* peak leaves the kill line **too loose**; a foreign
   *richer* peak **kills on the first tick**. Journal only.

## Operational notes the next lane will hit

- **The git index is genuinely shared, not just the worktree.** This lane's first `ORDER-510` commit
  died on `fatal: Unable to create '.git/index.lock'` while the parallel lane held it — and the shared
  index then carried **five of THEIR staged paths**. Committing would have taken their work under this
  lane's message. **Every shared-file commit in this lane was therefore staged through the object
  database** (`git hash-object -w` + `git update-index --cacheinfo`, then commit with no pathspec),
  which commits exactly `HEAD + my change` and leaves the other lane's uncommitted edits untouched.
  `git commit -- <path>` is **not** sufficient: it commits the working-tree content of that path,
  including whatever another lane has in flight there (the `eda48dd8` precedent, ledger rule 4).
  ⚠️ Do **not** reach for `commit-tree`/`GIT_INDEX_FILE` to get around a busy index — that skips the
  pre-commit hook, which is the repo's main cage, and memory `git-index-file-poisons-fixture-repos`
  records what stray `GIT_INDEX_FILE` did last time. Wait for the index instead.
- **Writing a bare `[0-9]` in the ledger's `order block` cell reserves orders 0-9.** The collision
  parser reads any bare `NNN-NNN`, and a regex character class is one. Caught because the parallel
  lane hit it in the same hour; both rows now spell the derivation as prose.
- **Board line references drift.** `ORDER-510` cites the `ORDER-129` default-magic guard at
  `LabCore.mqh:235-239`; at today's SHA it is `:254-257`. Noted in the row rather than silently patched.

## Routing — every forward item, and where it lives

<!-- HANDOFF-ROUTING -->

| item | home | note |
|---|---|---|
| Make `_57_DynCloseOn` announce itself as inert on Boss_16 (part A) | `ORDER-740` | written, **not built** — owes `tpl_regression`, which pins MT5 lane 1 |
| Whether to retrofit DynClose onto Kangaroo at all (part B) | `ORDER-740` | **owner decision** — two profit-target laws on one basket, silently `min()`, on live demo leg `990016` |
| Read-only F3 census of the 4 unchecked accounts (3 real money) | `ORDER-510` | pre-flight, must precede any upgrade |
| Rehearse adopt-once on a demo terminal, then walk the 5 magics | `ORDER-510` | STEP 2; procedure written, closes `ORDER-234` |
| The `rc_peak_eq = 10136.29` anomaly | `ORDER-510` | STEP 3; Journal only, never diagnosed from current source |
| `/ea-monitor` cadence — owner must export `live_deals.csv` | `BACKLOG-D33` | dormant with a checkable wake condition; owner unavailable 2026-08-01 |
| Fill the 11 empty `kill_rule` cells | `DONE` | `734681b6` — 11 → 0, `check_state` CLEAN |
| Correct `PROJECT_STATE` §7 item 6 and the opener | `DONE` | `49637088` |
| Write `ORDER-510`'s adopt-once procedure | `DONE` | `164e8753` |

## Commits

`fc4d8af8` reserve lane · `734681b6` `kill_rule` fill · `aedc2066` widen declaration ·
`ad2e125c` open `ORDER-740` · `49637088` document corrections · `164e8753` `ORDER-510` STEP 1 ·
`71485d89` close lane · `8d5bb2ed` declare handoff paths

**Nothing in this lane touched the VPS, copied a binary, read or wrote a GlobalVariable, or attached
anything to demo or live.** `ORDER-510`'s standing prohibition is in force and untouched.
