# HANDOFF 2026-07-30 — Stage 0A/0B repairs, and a Factory OS design that failed three audits

**Lanes:** `S-2026-07-30-TPLREPAIR` (closed) · `S-2026-07-30-MONITOR0B` (closed) · `S-2026-07-30-DESIGN1` (closing with this file)
**Driver:** the master sequence in `C:\Users\patip\Downloads\Codex grill me\0. START HERE - EA LAB CLAUDE MASTER.md`
**Not done, on purpose:** no taskboard Order was written. The master file forbids it until the design passes review, and it has not.

---

## 1. What is finished and verified

**Stage 0A — EA Template confirmed defects: CLEAN.** `optimize_guard.ps1` read `classification=OVERRIDE`
as "dead" when it means *member of a precedence chain*, so three working dials were refused and the only
way past was `-SkipOptimizeGuard`, which also disables the checks that have evidence. Precedence is now
decided per run from sibling values; unknown classifications still fail closed. `tpl_regression.ps1` was
compiling lane 1 and measuring lane 5c — it now pins its lane and asserts the freshly built `.ex5` is in
the lane it is about to measure, and that guard was **observed firing** (`-DataDir 'D:\Meta 5c'` ⇒ exit 1
before any tester run). Evidence on lane `D:\Meta 5`: compile 0/0 on 9 targets · `param_registry_check`
CLEAN · `tpl_regression` CLEAN 8/8 · new cage `run_optimize_guard_tests.ps1` **red 11/14 first, then 14/14**.

**Stage 0B — monitoring integrity: 7 defects, all fixed.** A dead floating sensor could not turn the chain
red; an unreadable snapshot was logged and swallowed; one base equity of 10,000 was applied to all six
accounts; `146237` rendered as a lab account; an unparseable timestamp was filed as `HISTORICAL`. New
suite `run_monitor_integrity_tests.ps1` **85/85**, in the pre-commit fast tier. **I mutation-tested both
guards myself rather than trusting the worker:** reverting the float rule ⇒ 7 red / 78 pass; reverting
`Get-AcctBase` to a flat 10000 ⇒ 11 red / 74 pass.

**Real schema validation now exists.** `ajv-cli` installed (user-approved), and
`_triage/factory_os/run_schema_fixtures.py` runs **17 cases, one per audit finding, both directions**,
all behaving as declared. Its final line validates the **real** `control_room_snapshot.json` — it FAILS
today, deliberately, and that line is the acceptance criterion for slice S4.

## 2. The state of the design — read this before touching it

Three blind Codex audits, three NO-GOs. Audit 1: 22 findings, and the load-bearing claim of §1.3 ("eleven
facts have no owner") was false — most are owned. Audit 2: 3 CLOSED, 6 MOVED-honest, 1 MOVED-evasive,
5 RESTATED, **7 REGRESSED**. Audit 3: both P0s still not closed.

**The seven regressions had one cause, and it is a working-method defect, not a design defect.** I fixed
the schema and left the design prose stating the old contract, then added a note underneath saying the old
contract was wrong. A note is not a contract. I then built a checker to bind design to schema and called
it the cure — audit 3 measured it against those same seven findings and it would have caught **0 of 7**,
because it compares storage paths and greps banned sentences while every one of those defects was
semantic. The proof was already in the commit that installed it: §4.5 still described `attempts[]`, a
lease with `pid`, and `launched_at` while the schema said the opposite, and the checker printed
`STRUCTURE OK`.

**Do not hand-revise the design again without fixing that first — see `BACKLOG-D31`.**

## 3. What blocks what

| Blocked thing | Blocked on | Kind |
|---|---|---|
| S2 canonical Coverage transfer | the owner of `MASTER_BACKLOG.md` approving the ownership move | **decision** |
| S3 all-clear validator | the builder-input vs persisted-output boundary being defined | defect |
| S4 snapshot v5 | `ControlRoomSnapshotV5` does not carry the meta/source fields the real v4 file has | defect |
| S10 magic allocator | user amending the `account|magic` invariant in `PROJECT_STATE.md` §3 | **decision** |
| S14 Work Receipts | user amending the `AGENTS.md` §2 permission table | **decision** |
| optimize-round policy | user defining "~10,000 combinations per round" executably (zones, minimum search, stop rule) | **decision** |

`S2a` (ownership proposal + migration table) and `S3a` (pin the validator, write regression fixtures) are
the **only** things audit 3 cleared to become orders.

## 4. Traps this session paid for

- **I collided on a session-ledger block.** `SENSFAN` reserved 580-589 at 06:14; I reserved the same block
  at 06:18 because I read the ledger at 05:55 and staged 20 minutes later **without re-checking HEAD**,
  which is rule 4 of that file. No damage — neither lane opened an order number — but the near-miss is
  recorded rather than renumbered away.
- **`AGENTS.md` §3.2 states a reason that is no longer true:** it says lane `5c` has no tick cache. It has
  **21.0 GB / 2,319 files**. The rule may still be right; its stated rationale is stale, and a concurrent
  session was running Model 4 on that lane.
- **`DEPLOYMENTS.csv` has one row with a blank magic**, and the unknown-magic detector joins on
  `magic -match '^\d+$'`, so that row can never match and is reported as an unknown magic forever.
- **`[datetime]::TryParse` is lenient enough that `"2026.07."` parses as `2026-07-01`** — so
  `UNCLASSIFIED` catches *unreadable* input, not *wrong* input.
- **I let the surfaces the user reads go 8 commits stale** before noticing. `AGENTS.md` rule 7 says run
  `make_status.ps1` after every commit; running it once and then landing eight more is how the phone copy
  ends up describing a state that no longer exists.

## 5. Decisions recorded this session

`PROJECT_STATE.md` §3 gained three rows: a guard that refuses valid work is the failure that gets guards
switched off; a cage must prove it measured what it compiled; and the user's decision to move magic
uniqueness to **global** scope. That last one **deliberately does not flip the `account|magic` invariant**
— the invariant is still true of the running fleet (`990103`, `991001`, `991002` each on two accounts,
`991001` on real money), so rewriting it now would make the document lie about the fleet to match a design
that has not been built.

<!-- HANDOFF-ROUTING -->

| item | routes to |
|---|---|
| Stage 0A repair — optimize_guard semantics, cage, lane pin | DONE |
| Stage 0B repair — 7 monitoring defects, 85/85 suite, both guards mutation-tested | DONE |
| Real JSON Schema validation via ajv + 17 fixtures | DONE |
| Session-ledger collision recorded, lanes closed | DONE |
| Factory OS design: preparatory orders S2a/S3a, blocked items, S4 acceptance | BACKLOG-D30 |
| Design↔schema binding is unsolved; stop hand-revising until it is | BACKLOG-D31 |
| `AGENTS.md` §3.2 lane-5c rationale is stale (cache exists, 21 GB) | BACKLOG-D30 |
| `DEPLOYMENTS.csv` blank-magic row can never join the unknown-magic detector | BACKLOG-D30 |
| `TryParse` leniency: UNCLASSIFIED catches unreadable, not wrong | BACKLOG-D30 |
| Three user decisions (magic invariant · AGENTS.md §2 · ~10k round budget) | BACKLOG-D30 |
