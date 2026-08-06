# OPENING PROMPT — the same owner signature is still blocking, and it has now stopped a finished change

> Written 2026-08-06 by lane `S-2026-08-06-OWED` (block `1490-1499`), which worked
> `_triage/PROMPT_NEXT_SESSION_1480.md` §5 items 1-4.
> ⛔ **Supersedes `_triage/PROMPT_NEXT_SESSION_1480.md`.** Its §0 and §4 are still true and are
> carried forward below rather than restated in full — go and read them once.

---

## §0 — 🔴 READ FIRST: five files of finished work are sitting UNCOMMITTED in the working tree

`ORDER-1330`'s two owed items are **done, verified, and refused at the commit gate.** They exist only
in the working tree:

```
_triage/factory_os/schemas.json
_triage/factory_os/run_schema_fixtures.py
_triage/factory_os/CONTRACTS.md
scripts/_test/run_fast_cages.ps1
.githooks/fast_tier_pathspec
```

A patch copy is at
`C:\Users\patip\AppData\Local\Temp\claude\D--EA-LAB\eb87bd0e-8e64-4e17-b31d-3755594fbd18\scratchpad\ORDER-1330_blocked_by_1462.patch`
in case the tree is swept — **but a scratchpad is not storage. Landing this is the first thing to do
after the attestation.** `git add` those five and commit; nothing else is needed.

⚠️ **Do not `git checkout` or `git restore` anything in this repo before reading that list.**

<sub>The `1480` §0 warning still stands and is unchanged: `0 ACTIVE` in the ledger is not the same as
"nobody is writing", `check_order_collision.ps1` skips its reserved-block and owned-path rules
entirely when nothing parses as ACTIVE, and any measurement that assumes the repo held still must
record HEAD at both ends. This lane recorded `7f567c37` at open in its own ledger row.</sub>

---

## §1 — 👤 THE SAME FOUR DECISIONS. Number 1 has gone from blocking other people to blocking work.

| # | decision | why it is yours |
|---|---|---|
| **1** 🔴 | **`ORDER-1462` — re-make the s2a attestation.** Review `511d0f76`, then append **one line** to `_triage/factory_os/s2a_attestations.jsonl`. **The exact line is now written into the `ORDER-1462` row** — fill `decided_at` and `reason`, nothing else. | **An attestation is a signature.** It now blocks a finished change (§0), not just a hypothetical one. Two corrections found by trying to follow the old instructions: **`run_s2a_gate.py --template` does not exist** (no such flag; it is `check_s2a_attestation.py --template`), and the change being attested is **one line** — `text=True` → `encoding='utf-8'` in a git helper that threw `UnicodeDecodeError` on any non-ASCII path. **Reviewed and found sound by this lane; the signature is still not ours.** |
| 2 | **Deploy the instrumented `(EXP)_IchiADX_Naked_rev00` to the four VPS charts?** Unchanged — built and proven on dev, not shipped. | `ORDER-1000` A2/A3 cannot be answered until it is on those charts, and shipping an `.ex5` to a live fleet is yours. |
| 3 | **Re-run `ORDER-430` / `ORDER-1420`?** 🚫 Still not recommended, and there is now **one more reason**: see §3.3 — today's staleness signal is mostly a checkout artifact, so a re-run motivated by "the binary was stale" would be chasing a git timestamp. The cheap version remains **one** cell on both binaries, same day, same `.set`. | 16 Model-4 runs to re-confirm a negative the ≥100 floor already reached. |
| 4 | **Does an `ORDER-236` lever-park take a scorecard row?** Untouched — this lane did not reach §5 item 5, which waits on this. | It is a lever verdict on an existing chassis, not a new EA. |

---

## §2 — What landed (6 commits, `3f720276` … `db4bf7f6`)

| order | outcome |
|---|---|
| `ORDER-1460` | **DONE** — the suite runs **108/108**, up from an abort at 15. Ninety cases had not run since 2026-08-01 |
| `ORDER-501` | **STEP 2 DONE** — the writer waits on a lock instead of counting to three |
| `ORDER-1461` | **item 1 DONE** — `stale-check:` is in `mt5_run.ps1`'s launch banner, 18/18 caged |
| `ORDER-1330` | **both owed items DONE, and UNCOMMITTED** — §0 |
| 🆕 `check_order_collision.ps1` | RULE 2 could not tell a repair from an introduction; fixed and caged 34/34 |
| 🔴 `AGENT_TASKBOARD.md` | a **destroyed order header** recovered from `70c00840` |

---

## §3 — 🎯 The four findings worth more than the orders they came from

1. **A row was invisible to every sweep, including the one every lane runs before reserving a block.**
   `## ORDER-1460`'s header line had been **consumed** by the edit that inserted `ORDER-1462`: the
   body survived from `**bars:**` down, the header's first half was gone, and its tail was glued to
   the end of `ORDER-1462`'s prohibition paragraph. `grep "^## ORDER-1460"` returned nothing for two
   commits. **The block-derivation test both of today's lanes ran read a board with a hole in it** —
   harmlessly, because 1462 > 1460, but only by luck. Restored **verbatim from `70c00840`**; the
   header set now differs from that commit by exactly the one row `ORDER-1462` legitimately added.
2. **The guard refused the commit that repaired the state it was complaining about.** RULE 2 compares
   staged headers against HEAD's and calls anything absent from HEAD *new*, so a restored id looks
   like a fresh number outside the lane's block — and it can never be inside it, since the number
   belongs to a lane that closed. Same FALSE BLOCK shape `check_order_collision.ps1`'s own
   un-archiving note describes one case over. Now asks the **log**, only for an id that would
   otherwise be refused, and prints `RESTORATION` — observed firing on the real commit.
3. **Today's `STALE` verdicts are mostly a git artifact, and that is measured.** Fourteen
   `ea_template/core/*.mqh` files carry the identical mtime `2026-08-06 06:49:53` while the last
   commit touching `LabCore.mqh` is `ec085d69` (**2026-08-02**) — a checkout stamp from the branch
   switch `1480` §0 describes, not edits. ⇒ nearly every Boss binary reads STALE today for a reason
   that is not staleness. **That is the argument for visible-before-refusing**: a refusal wired to
   this signal today would have blocked the whole fleet on its first morning.
4. **The obvious reading of `ORDER-501` STEP 2 was a regression.** *"Delete the artificial 3-attempt
   loop"* — but three attempts each passing `LockTimeoutSeconds=30` is **90 seconds** of waiting and
   one bare call is **30**, so the naive fix cuts the wait to a third on exactly the slow runs the
   shortfalls came from. The retry is now unbounded in tries and bounded by **what the write says**:
   wait on `lock_timeout`, stop at once on a refusal. No new number — the outer bound is the parent's
   existing `WaitForExit(600000)`.

---

## §4 — ⚠️ Mistakes. The four from `1480` still apply; these two are new.

1. **Wiring four of seven call sites and believing the list.** The ORDER-105 fix wired the four clone
   HELPERS; the suite still failed on one case, with the identical error, because three more clones
   are written **inline**. The repair is not "add three more" — a case now **enumerates** every
   repository under the scratch root whose `core.hooksPath` is `.githooks`. The seed's stub list was
   made derived for this exact reason, one layer in, and I re-made the mistake one layer out.
2. **A fixture cost 1,101 MB of `TEMP` before it was measured.** Copying a 22 MB interpreter per
   fixture is invisible at one fixture and 1.1 GB at fifty — on a suite that gets interrupted often
   and never reaches its cleanup when it does. Hard links from one copy: same wall-clock, 22 MB.
   **Measure the fixture, not just the assertion.**

---

## §5 — What is OWED, in the order I would do it

1. 🔴 **Land `ORDER-1330`** — §0. One `git add` + commit, the moment `ORDER-1462` is signed.
2. **`ORDER-1461` item 2** — decide what the Experts-**root** copies are. 53 ini configs resolve
   `-Expert` to the root and nothing refreshes it. Either repoint them at `EALabTpl\` or make the
   root a build output. 🚫 Do not make the banner refuse until this is decided — §3.3.
3. **`ORDER-236` Row-X** — the EA-shaped rows, pending §1 decision 4. Untouched by this lane.
4. **`ORDER-1330` `§ITEM-1` owed item 3** — the `$Ctx`/`$Metrics` plumbing. Still blocked on
   Blocker A: no `v2` fingerprint can be produced until `ORDER-1350` wires a per-run swap probe.
5. **`ORDER-501`, the honest remainder** — STEP 2 is verified on **two fast runs**. The failure mode
   lives above ~861s of wall-clock and was **not** reproduced. The new
   `concurrent-write-no-writer-abandoned-a-request` case will name its own status on the next slow
   run; 🚫 do not close this by re-running until one is slow — that is waiting, not measuring.

---

## §6 — Standing rules that did not change

- 🚫 No EA verdict from automation · 🚫 `$FullTierBudgetSeconds` pinned at **120.0s**.
- 🚫 `AGENTS.md` · `VISION.md` · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set`
  migration · any magic allocate/renumber/retire · any history rewrite.
- 🚫 **`ea_template/core/` is owner-refused** for the two-sided `Boss_14` change.
- 🚫 **No `.ex5` to the VPS** without an explicit ruling.
- **Stage in one call, read the diff in another, commit in a third.**
- **Derive your block yourself immediately before staging.** Highest `## ORDER-<n>` = **1462**;
  highest block held by a lane row = **`1490-1499`** (this lane); next free = **`1500-1509`**.
  🔴 **Do not trust that sentence** — and note what §3.1 adds to the reason: the derivation reads a
  file whose headers can be silently destroyed.
- ⚙️ **Machine state at handoff:** 0 MT5 processes, HEAD `db4bf7f6`, working tree carries the five
  `ORDER-1330` files (§0) plus `STATUS.html` and `portfolio/daily_monitor.log` (both pre-existing).
  `EA_LAB_DailyMonitor` next fires **2026-08-07 07:30** and commits by itself — do not start a
  repo-stability measurement across it.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the s2a attestation, now blocking finished work | `ORDER-1462` · 👤 the owner |
| the five uncommitted files | `ORDER-1330` |
| the fingerprint plumbing and its blocker | `ORDER-1330` · `ORDER-1350` |
| the Experts-root copies nobody refreshes | `ORDER-1461` |
| the slow-run status the concurrency case will now name | `ORDER-501` |
| the truncated suite, and the floor that ends it | `ORDER-1460` · DONE |
| the destroyed header, and the guard that refused its repair | DONE |
| the lever park | `ORDER-236` |
| deploying the instrumented IchiADX build | 👤 the owner |
