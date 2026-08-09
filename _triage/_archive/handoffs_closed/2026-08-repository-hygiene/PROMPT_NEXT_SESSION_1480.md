# OPENING PROMPT — one owner signature is blocking the fast tier; everything else on this page is optional

> Written 2026-08-06 by lane `S-2026-08-06-HANDOFF` (block `1480-1489`), closing out three lanes:
> `CLEARALL` (1440-1449) · `CLEARALL2` (1460-1469) · `SCRUT` (1470-1479).
> ⚠️ **Read `docs/SESSION_LEDGER.md` first.** At this writing **no lane row carries `ACTIVE`**
> (verified: zero) — but see §0 before you trust that sentence.
> ⛔ **Supersedes `_triage/PROMPT_NEXT_SESSION_CLEARALL.md`**, whose §5 was already amended once.

---

## §0 — 🔴 READ FIRST: "no ACTIVE lane" is not the same as "nobody is writing"

Earlier today this repo was branch-switched over `master` and had **2,838 files staged** by a writer
that **never took a ledger row**, while the ledger read `0 ACTIVE` throughout. Everything downstream
inherits that hole: `check_order_collision.ps1` **skips its reserved-block and owned-path rules
entirely** when nothing parses as ACTIVE, and says so in a `NOTE` that reads like a quiet day.

**It cost two measurements.** `ORDER-501`'s suite asserts the shared repo's HEAD, index and worktree
are unchanged; it was voided once by that writer and once by a job the measuring lane started itself.
The third attempt held only because HEAD was checked at both ends by hand.

⇒ **Before any measurement that assumes the repo is still: record HEAD at the start and at the end,
in the measurement's own output.** `BACKLOG-D29` is about these lines going stale; this is a
different and worse hole — a lane that is simply absent — and no amount of deriving from the tables
detects it.

---

## §1 — 👤 FOUR DECISIONS. The first one is blocking other people; the rest are not urgent.

| # | decision | why it is yours |
|---|---|---|
| **1** 🔴 | **`ORDER-1462` — re-make the s2a attestation.** Review `511d0f76`'s change to `check_s2a_migration.py`, then re-make the line-10 record against bundle **`2ce1ea874449`**. `run_s2a_gate.py --template` gives the record shape. | **An attestation is a signature** — it asserts an owner read the new bytes. No agent may produce one. **Until it lands, anyone who stages an s2a-guarded path hits a red tier they did not cause.** |
| 2 | **Deploy the instrumented `(EXP)_IchiADX_Naked_rev00` to the four VPS charts?** Built and proven on dev; **not shipped**, per your dev-compile-only ruling. | `ORDER-1000`'s A2/A3 cannot be answered until the build is on those charts, and shipping an `.ex5` to a live fleet is yours (`live-fleet-runs-pre-132-binaries`). |
| 3 | **Re-run `ORDER-430` / `ORDER-1420` on the current chassis?** 🚫 **I do not recommend it.** | 16 Model-4 runs to re-confirm a negative the ≥100 floor already reached. The staleness changes how far the individual numbers can be leaned on, not the conclusion. **And the effect size is unmeasured** — the cheap version is **one** cell on both binaries, same day, same `.set`. |
| 4 | **Does an `ORDER-236` lever-park take a scorecard row?** | It is a lever verdict on an existing chassis, not a new EA. The Row-X checklist's EA-shaped rows are marked **owed, not skipped**. |

---

## §2 — What landed (13 commits, `d3151575` … `4c42986b`)

| order | outcome |
|---|---|
| `ORDER-430` | re-read under the ratified ≥100 floor ⇒ **0 of 7 hosts qualify**; both prior qualifications void |
| `ORDER-1420` | **CLOSED** — owner refused the `core/` parity break; short screen was 7/7 nothing |
| `ORDER-236` | STAGE 3, 12/12 Model 4, **no cell passes** ⇒ **`PARKED-VERIFY(user)`**, ladder complete |
| `ORDER-1050` | refusal shipped red-before-green; **the reproduction REFUTES the row's own diagnosis** |
| `ORDER-1330` | item 2 done; item 1 **partial** — versioning + refusal in, content blocked on `ORDER-1350` |
| `ORDER-1000` | instrumented, dev-compiled, counters proved non-zero with the invariant closing |
| `ORDER-501` | STEP 1 done ⇒ **hypothesis 2 REFUTED**, not a Contract D defect |
| 🆕 `ORDER-1460` · `1461` · `1462` | opened from findings the work produced |

---

## §3 — 🎯 The four findings worth more than the orders they came from

1. **`ORDER-1050`'s diagnosis is wrong.** The corrected call reproduces `d1335d39…`/`1de384c8…`
   **identically** — the scope label was a real defect and **not this defect**. Ruled out: preimage
   lines 1-2 and the 116/116 shape. Blocked on pinning the running binary's vintage, then on the EA
   emitting `CFG_SurfacePreimage()` — it prints only the digest.
2. **`_9_RegimeGateAdds` is a rider, not a lever.** Its only call site sits behind another input's
   enable-check. Predicted from source, then measured (`C1 ≡ C0`, every digit including net).
   ⇒ **an axis probed one-at-a-time from a base where its enabler is off reports INERT and hides that
   it is load-bearing when the enabler is on.** In `EDGE_CATALOG`.
3. **`ORDER-501`'s discriminator:** `events<150` ⟺ `childOk=False` on **all nine** runs. The log
   never lost a write it accepted; the writer exhausts a 3-attempt budget and reports it. **Load is
   not the driver** (mean lost 7.67 / 1.67 / 15.33 at 0/10/20 busy cores) — **wall-clock is**, with an
   empty gap between 687s and 861s.
4. **Two working guards are on nobody's path.** `check_stale_binaries.ps1` flags the Boss_14 staleness
   correctly and `mt5_run.ps1` never calls it (`ORDER-1461`); `scripts/lib/pilot_run.ps1` is in
   neither the pathspec nor any `$SUITE_GUARDS`, so the file computing every pilot fingerprint has
   **never** had a commit-path cage.

---

## §4 — ⚠️ Four mistakes made and caught here. Read these before repeating them.

1. **A version tag that changed the digest it labelled.** `v1:<sha>` folded `fpver=v1` into the
   preimage, so an unchanged run hashed differently — and `data_fingerprint` is in
   `EXECUTION_KEY_FIELDS`, so all 135 committed rows would have stopped matching `find_cached`.
   Caught by `/scrutinize` running the tier I had skipped. **Repaired in `3d1dd46f` with a regression
   guard that recomputes the expected digest independently of the code under test.**
2. **A negative asserted from a commit timestamp.** *"The bundle's `.ex5` cannot be the binary that
   ran"* — a commit timestamp is not a build timestamp. One `Length` check refuted it. Retracted in
   `7b82d4ff`.
3. **`io.open(path, 'w')` truncated `AGENT_TASKBOARD.md` to 0 bytes** — it truncates on *open*, before
   the encode error that then aborted the write. 🚫 **Never use it for an in-place edit of a tracked
   file.** Use the Edit tool, or write a temp file and move it.
4. **A zero exit code from the MQL5 compiler is not evidence that a compile happened.**
   `terminal64.exe /compile` on `D:\Meta 5b` silently stopped compiling after that terminal was
   force-killed — no `.ex5`, **no line in `metaeditor.log` at all** — and `metaeditor64.exe /compile`
   returned **0** while producing nothing. Check the `.ex5` mtime **and** a fresh `metaeditor.log`
   line. Lane 1 (`D:\Meta 5`) built the same source in 5 seconds.

---

## §5 — What is OWED, in the order I would do it

1. **`ORDER-1460`** — the ORDER-105 suite **aborts at case 15** since `fefce8fd`; 90 of 105 cases have
   not run since 2026-08-01. Give the fixtures what the hook needs, **and make a truncated run
   impossible to mistake for a pass** (assert a minimum case count). 🚫 Do not catch the exception and
   continue — that turns a loud abort into a quiet 15-case pass.
2. **`ORDER-1461`** — put `check_stale_binaries.ps1` on the run path: print its verdict in
   `mt5_run.ps1`'s launch banner next to `surface: UNDECLARED`. **Make it visible before making it
   refuse** — refusing outright breaks 53 existing ini configs at once.
3. **`ORDER-1330` item 1** — wire the cage into the fast tier (`fast_tier_pathspec` +
   `$SUITE_GUARDS` + `run_guard_trigger_tests.ps1` must move together), and add the `schemas.json`
   pattern `^(v[0-9]+:)?[0-9a-f]{64}$`, which needs **11 filler-value fixtures** fixed first.
   🎯 That is the finding, not the obstacle: the field has no pattern *because* nothing ever had to
   produce a real one.
4. **`ORDER-501` STEP 2** — make the concurrency test wait until the write is done. 🚫 **Never just
   raise the retry count or timeout** — this row forbids it, and it would only move the threshold.
5. **`ORDER-236` Row-X** — the EA-shaped rows, pending decision 4 above.

---

## §6 — Standing rules that did not change

- 🚫 No EA verdict from automation · 🚫 `$FullTierBudgetSeconds` pinned at **120.0s**.
- 🚫 `AGENTS.md` · `VISION.md` · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set`
  migration · any magic allocate/renumber/retire · any history rewrite.
- 🚫 **`ea_template/core/` is owner-refused** for the two-sided `Boss_14` change — do not reopen it
  without them.
- 🚫 **No `.ex5` to the VPS** without an explicit ruling.
- **Stage in one call, read the diff in another, commit in a third.**
- **Derive your block yourself immediately before staging.** Highest `## ORDER-<n>` = **1462**;
  highest block held by a lane row = **`1480-1489`** (this lane); next free = **`1490-1499`**.
  🔴 **Do not trust that sentence** — §0.
- ⚙️ **Machine state at handoff:** 0 MT5 processes, HEAD `4c42986b`, working tree carries only
  `STATUS.html` and `portfolio/daily_monitor.log` (both pre-existing). `EA_LAB_DailyMonitor` next
  fires **2026-08-07 07:30** and commits by itself — do not start a repo-stability measurement across it.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the s2a attestation, red at HEAD | `ORDER-1462` · 👤 the owner |
| the truncated ORDER-105 suite | `ORDER-1460` |
| the stale-binary detector nobody calls | `ORDER-1461` |
| the fingerprint versioning, and its two blockers | `ORDER-1330` · `ORDER-1350` |
| the concurrency retry budget | `ORDER-501` STEP 2 |
| the refuted scope diagnosis, and the preimage it still cannot emit | `ORDER-1050` · `ORDER-1000` |
| the rider shape, and StackConfirm on a second symbol | `EDGE_CATALOG` |
| zero qualified hosts, and the lever park | `ORDER-430` · `ORDER-236` |
| deploying the instrumented IchiADX build | 👤 the owner |
| a lane that took no ledger row | 👤 the owner + `BACKLOG-D29` |
