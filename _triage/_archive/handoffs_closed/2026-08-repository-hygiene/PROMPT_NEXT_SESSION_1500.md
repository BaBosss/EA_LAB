# OPENING PROMPT — one signature still blocks seven files, and the tier has 6.2s of headroom left

> Written 2026-08-06 by lane `S-2026-08-06-SCRUT2` (block `1500-1509`), which ran `/scrutinize` over
> `S-2026-08-06-OWED`'s six commits and repaired what it found.
> ⛔ **Supersedes `_triage/PROMPT_NEXT_SESSION_1490.md`.** Its §0 and §4 are carried forward here.

---

## §0 — 🔴 READ FIRST: SEVEN files of finished work are uncommitted, and the count went UP

`ORDER-1330`'s two items plus this lane's fast-tier registration are done, verified, and refused at
the commit gate by `ORDER-1462`:

```
_triage/factory_os/schemas.json              _triage/factory_os/run_schema_fixtures.py
_triage/factory_os/CONTRACTS.md              scripts/_test/run_fast_cages.ps1
.githooks/fast_tier_pathspec
```

<sub>Five files, and two of them now carry BOTH orders' work: `run_fast_cages.ps1` and the generated
pathspec register `ORDER-1461`'s new cage as well. They land together in one commit or not at all.</sub>

A patch copy of the earlier five is in the previous lane's scratchpad; **a scratchpad is not
storage.** ⚠️ **Do not `git checkout` / `git restore` anything before reading that list.**

<sub>`1490` §0's warning still stands: `0 ACTIVE` in the ledger is not "nobody is writing", and any
measurement assuming the repo held still must record HEAD at both ends. This lane recorded `51f8e4e6`
at open.</sub>

---

## §1 — 👤 DECISIONS. The first is unchanged and now blocks more; the fifth is new.

| # | decision | why it is yours |
|---|---|---|
| **1** 🔴 | **`ORDER-1462` — re-make the s2a attestation.** The exact line to append is written into the `ORDER-1462` row; fill `decided_at` and `reason`. | Now blocks seven files across two orders. The change being attested is one line (`text=True` → `encoding='utf-8'`), reviewed and found sound by the previous lane. 📌 `run_s2a_gate.py --template` **does not exist** — it is `check_s2a_attestation.py --template`. |
| **5** 🆕 | **The fast tier has 6.2s of headroom and I spent 4.7s of it today.** 109.1 → 110.1 → **113.8s** of the pinned **120.0s**, three `-Hook` samples each. The file's own record says the same commit has measured a **6.3s** spread across two days. ⇒ **remaining headroom is inside ordinary load variation.** Options: displace a suite, raise the pin, or accept that a busy afternoon refuses commits. 🚫 I did not move the pin — §6 forbids it. | The pin is `$FullTierBudgetSeconds` and moving it is a deliberate two-file act the guard cage enforces. |
| 2 | **Deploy the instrumented `(EXP)_IchiADX_Naked_rev00` to the four VPS charts?** Unchanged. | `ORDER-1000` A2/A3 needs it on those charts; shipping an `.ex5` to a live fleet is yours. |
| 3 | **Re-run `ORDER-430` / `ORDER-1420`?** 🚫 Still not recommended — and today's staleness signal is mostly a checkout artifact (§3.2), so a re-run motivated by "the binary was stale" chases a git timestamp. | 16 Model-4 runs to re-confirm a negative. |
| 4 | **Does an `ORDER-236` lever-park take a scorecard row?** Still untouched — no lane has reached it. | A lever verdict on an existing chassis, not a new EA. |

---

## §2 — What landed (3 commits, `000e5c3a` … `0f2e2344`)

| what | outcome |
|---|---|
| `ORDER-1461` | **CORRECTED AND COMPLETED** — the banner was on **1 of 3** tester entry points; now shared and on all three, 17/17 caged, registered in the tier |
| `check_order_collision.ps1` | the restoration rule now **prints the commit** that entitles it, and states the narrowing it introduced |
| `ORDER-1330` | one claim of mine **retracted** — see §3.1 |
| 🆕 `ORDER-1500` | the run-journal store nothing validates, and the three rows that prove it |

---

## §3 — 🎯 What the review found

1. **🔴 A claim of mine was false, and the truth was better evidence than the claim.** I wrote that
   `ORDER-1330`'s schema pattern proved *"the real corpus already conformed; only the test corpus did
   not"*. What was measured is that the **five stores `registry.STORES` names** conformed.
   `factory/runs/*.jsonl` is not one of them, and **three committed rows carry the unhashed
   preimage** — `"D:\Meta 5|XAUUSD|H1|2024.01.02|2024.01.16|M1"`, 45 characters with an absolute
   machine path — against 132 values of 64 hex elsewhere. **The strongest evidence for that item's
   own thesis was in committed evidence the whole time.** The error was generalising *"the validated
   corpus passed"* to *"the corpus passed"*. → `ORDER-1500`.
2. **The banner shipped on one third of the run path.** Three scripts write `Expert=` into a tester
   `.ini`: `mt5_run.ps1`, **`mt5_optimize.ps1`**, `run_backtest.ps1`. It landed in the first only —
   the same defect `ORDER-1461` is *about*, one layer over, and the optimizer is the worse omission
   because a stale binary there **selects the parameters** everything downstream is built on.
3. **A cage that did not exist found three defects in ten minutes.** Writing
   `run_binary_staleness_tests.ps1` surfaced: a hardcoded `D:\EA_LAB` RepoRoot inherited from the
   detector (the worktree hazard already in memory), `X.ex5.ex5` from the one caller that passes an
   extension (**a permanent UNKNOWN wearing the shape of an honest answer**), and the detector's
   `exit 2` leaking into callers. **None was reachable by reading the code; all three fell out of
   driving it against a fixture.**
4. **Two of my own assertions were the bug.** `-like '*STALE*'` is **case-insensitive** and the line
   starts with `stale-check:`, so that test is TRUE for every line the function can return — *including
   OK*. And a fresh binary with a sibling copy reads **`HASH_DIFFERS`, not `OK`**; on this machine
   that is the **common** reading of a **healthy** binary. ⚠️ **Never read `HASH_DIFFERS` as stale.**

---

## §4 — ⚠️ Mistakes. `1490` §4's two still apply; these are new.

1. **Generalising past the measurement** — §3.1. The sentence was one word wider than the evidence
   ("the corpus" for "the validated corpus") and that word hid three bad rows.
2. **Shipping a check with no cage of its own.** The banner's only verification was a human slicing
   the block out of the file and running it by hand. It had three defects. **A check whose only
   caller is a person who remembers is the shape this repo keeps paying for.**
3. **A `#>` left mid-comment turned a guard into a parse error** — caught immediately by its cage
   (34 cases went red at once), which is the system working, but it is why the cage runs before the
   commit and not after.

---

## §5 — What is OWED, in the order I would do it

1. 🔴 **Land the seven files** — §0. One `git add` + commit the moment `ORDER-1462` is signed.
2. **`ORDER-1500`** — decide whether `factory/runs/*.jsonl` gets an entity contract and joins
   `STORES`, or is **declared** out of scope. 🚫 Do not leave the third state (*not validated and not
   declared unvalidated*), which is what let this sit. Then judge the three rows — 🚫 not a silent
   rewrite; a fingerprint never computed cannot be reconstructed afterwards.
3. **§1 decision 5** — the tier budget. Nothing more should be registered until it is answered.
4. **`ORDER-1461` item 2** — what are the Experts-**root** copies? 53 ini configs resolve there and
   nothing refreshes them. 🚫 Do not make the banner refuse until this is decided — §3.2 of `1490`.
5. **`ORDER-236` Row-X** — pending §1 decision 4. Still untouched by any lane.
6. **`ORDER-501`, the honest remainder** — STEP 2 is verified on two FAST runs; the failure mode
   lives above ~861s of wall-clock and was not reproduced. 🚫 Do not close it by re-running until one
   is slow.

---

## §6 — Standing rules that did not change

- 🚫 No EA verdict from automation · 🚫 `$FullTierBudgetSeconds` pinned at **120.0s** (see §1.5 — the
  pin is now the live constraint, and moving it is the owner's).
- 🚫 `AGENTS.md` · `VISION.md` · `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set`
  migration · any magic allocate/renumber/retire · any history rewrite.
- 🚫 **`ea_template/core/` is owner-refused** for the two-sided `Boss_14` change.
- 🚫 **No `.ex5` to the VPS** without an explicit ruling.
- **Stage in one call, read the diff in another, commit in a third.**
- **Derive your block yourself immediately before staging.** Highest `## ORDER-<n>` = **1500**;
  highest block held by a lane row = **`1500-1509`** (this lane); next free = **`1510-1519`**.
  🔴 **Do not trust that sentence** — and note the reason this lane added: the derivation reads a
  board whose headers can be silently destroyed, which happened this week.
- ⚙️ **Machine state at handoff:** 0 MT5 processes, HEAD `0f2e2344`, working tree carries the five
  §0 files plus `STATUS.html` and `portfolio/daily_monitor.log` (both pre-existing).
  `EA_LAB_DailyMonitor` next fires **2026-08-07 07:30** and commits by itself — do not start a
  repo-stability measurement across it.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| the s2a attestation, now blocking seven files | `ORDER-1462` · 👤 the owner |
| the uncommitted schema + tier-registration work | `ORDER-1330` · `ORDER-1461` |
| the run-journal store nothing validates | `ORDER-1500` |
| the three unhashed fingerprints | `ORDER-1500` |
| the fast-tier budget, now inside load variation | 👤 the owner |
| the Experts-root copies nobody refreshes | `ORDER-1461` |
| the slow-run status the concurrency case will name | `ORDER-501` |
| the fingerprint plumbing and its blocker | `ORDER-1330` · `ORDER-1350` |
| the lever park | `ORDER-236` |
| deploying the instrumented IchiADX build | 👤 the owner |
