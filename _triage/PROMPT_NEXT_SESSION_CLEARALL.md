# OPENING PROMPT — the session sent to clear six owed items, which cleared four and refuted two of its own claims

> Written 2026-08-06 by lane `S-2026-08-06-CLEARALL` (block `1440-1449`). Opened on
> *"เคลียร์งานทั้งหมดเลย นายทำเลย มีอะไรผมต้องเคาะไหม"* against `_triage/PROMPT_NEXT_SESSION_OWNERQ.md` §5.
> ⚠️ **Read `docs/SESSION_LEDGER.md` first.** At this writing **`S-2026-08-06-MAPFIX` is ACTIVE**
> (block `1450-1459`) and declares `AGENT_TASKBOARD.md` — coordinate before writing that file.

---

## §0 — 🔴 READ FIRST: a lane that does not take a ledger row is invisible to every check built on it

This session lost **30 minutes** to a writer that checked out `claude/mongodb-model-editor-viz-0fn25k`
over `master` at 06:49 and staged **2,838 files** at 06:56 — while `docs/SESSION_LEDGER.md` read
**0 ACTIVE lanes** throughout, because **that lane never took a row.**

Everything downstream of the ledger inherits that hole: `check_order_collision.ps1`'s reserved-block
and owned-path rules **skip entirely** when no lane parses as ACTIVE, and it says so in a `NOTE` that
looks like a quiet day. **`BACKLOG-D29` is about these lines going stale; this is worse and different
— a lane that is simply absent.** Deriving the block from the tables cannot fix it.

**What it cost, concretely:** the first `ORDER-501` measurement is **VOID** — that suite's final case
asserts the shared repo's HEAD, index and worktree are unchanged, and all three moved mid-run.

<sub>The same lane later reopened as `S-2026-08-06-MAPFIX` **with** a row, which is the behaviour the
ledger needs. Its row currently carries a malformed block token (`49-06`, high &lt; low) that the
collision guard correctly refuses to swap — worth a fix on that row, not this one.</sub>

---

## §1 — 👤 THREE OWNER RULINGS, all in `PROJECT_STATE.md` §3

| ruling | reach |
|---|---|
| **No `ea_template/core/` parity break for a two-sided `Boss_14`** | closed `ORDER-1420`. The change touches the chassis of all eight `Boss_11..18` and makes every historical baseline non-comparable, bought for a result already known absent (mirror screen 7/7, nothing) |
| **`data_fingerprint` gains the symbol spec; existing rows re-stamped, not deleted or re-run** | `ORDER-1330` item 1 — **partially executed, and the migration turned out to be unnecessary**, see §3 |
| **`ORDER-1000` instrumentation compiles on DEV only, no VPS deploy** | **not started** — see §5 |

---

## §2 — What was cleared

| item | outcome |
|---|---|
| **`ORDER-430` re-read** | **0 of 7 hosts qualify** under the ratified ≥100 floor. AUDCAD (62) and XAUUSD (52) void; the three with real participation (343/473/363) were always short of the 1.20 bar |
| **`ORDER-1420`** | **CLOSED** on the owner's ruling |
| **`ORDER-236` STAGE 3** | 12/12 Model 4. **No cell passes.** Ladder complete ⇒ **`PARKED-VERIFY(user)`**, not `DEAD-OPTIMIZED` |
| **`ORDER-1050`** | item 1 (the refusal) DONE red-before-green; item 2 (the reproduction) DONE **and it refutes the row's own diagnosis** |
| **`ORDER-1330` item 2** | DONE — `§ITEM-2`, a block meant to be copied verbatim |
| **`ORDER-1330` item 1** | **PARTIAL** — mechanism in and caged 13/13, content blocked |

---

## §3 — 🔴 The three findings that matter more than the items they came from

### 1. `ORDER-1050`'s diagnosis is wrong, and the corrected call proves it

Both `415573666` `.set` files were located and driven through the constants-supplying path. Result:
**`d1335d39…` / `1de384c8…` — identical to what the BROKEN call produced on 08-02.** The scope label
was a real defect (now fixed) and **not this defect**.
Ruled out: preimage line 1 (`scope`), line 2 (`build=LAB_ENTRY_14`), and the shape (`.set` maps
**116/116** onto the surface, matching the live `keys=116`). ⇒ the disagreement is in **values or
constants**. **Blocked on pinning the running binary's vintage**, and after that on the EA being able
to emit `CFG_SurfacePreimage()` — it prints only the digest. Same gap as `ORDER-1000`.

### 2. The lane has been running a binary 10 days stale, and nobody noticed because there are two

```
D:\Meta 5b\MQL5\Experts\Boss_14_GridLog.ex5           2026-07-27  152,178   <- what -Expert resolves to
D:\Meta 5b\MQL5\Experts\EALabTpl\Boss_14_GridLog.ex5  2026-08-02  178,300   <- current, never copied to root
```
**Seven commits touched `ea_template/core/` between them, including `Execution.mqh` and
`RiskControl.mqh`** — behaviour, not plumbing. ⇒ **`ORDER-236` STAGE 2 (2026-08-05) ran on the stale
one.** STAGE 3 targeted the fresh one by path and renamed nothing.
🔴 **Everything else that used `-Expert "Boss_14_GridLog"` since 07-27 is on the stale chassis too** —
that includes `ORDER-430` and `ORDER-1420`'s screens. Not audited here.

### 3. `_9_RegimeGateAdds` is not a lever, it is a rider — and the shape generalises

Its only call site is behind `Regime_AllowsEntryDirection`, whose first line is
`if(!Regime_Enabled()) return true;`. Predicted from source, then measured: `C1 ≡ C0` on PF, trades,
drawdown **and net**, both windows. **An input whose only call site sits behind another input's
enable-check reports INERT when probed one-axis-at-a-time from a base where the enabler is off** —
and is load-bearing when it is on. `inert-axis-fake-plateau`, one level down. In `EDGE_CATALOG`.

---

## §4 — 🎯 Two mistakes this lane made and caught, both worth more than the work they interrupted

1. **I asserted a negative from a commit timestamp** (*"the bundle's `.ex5` cannot be the binary that
   ran"*), inside a write-up about a digest trusted without checking. **A commit timestamp is not a
   build timestamp.** One `Length` check settled it: 178,182 bytes = post-rollout size class, so the
   claim was probably false. Retracted in `7b82d4ff` rather than softened.
2. **I truncated `AGENT_TASKBOARD.md` to 0 bytes** with `io.open(path, 'w')` — which truncates on
   *open*, before the encode error that then aborted the write. Recovered from HEAD; the STAGE 3
   write-up had to be retyped. 🚫 **Never use `open(p,'w')` for an in-place edit of a tracked file.**
   Use the Edit tool (atomic), or write a temp file and move it. The only reason this cost minutes
   rather than the session is that the numbers lived in reports on disk, not in the prose.

---

## §5 — What is OWED

- **`ORDER-501` — still not measured, blocked by the same cause twice today.** It measures behaviour
  under controlled load and its suite asserts the shared repo is unchanged. **It needs a machine with
  exactly one lane on it.** The driver is written and works:
  `scratchpad/o501_driver.ps1` (3 reps × 3 load levels, ~6.6 min per suite run).
  <sub>⚠️ A single idle run reported **`CASE COUNT: 15`** where `ORDER-421` recorded **105**, and did
  not print `ALL CASES PASSED`. Unexplained — possibly the same contamination, possibly not. Check it
  before trusting any count from this suite.</sub>
- **`ORDER-1000`** — not started. Owner has ruled dev-compile-only, so it is unblocked.
- **`ORDER-1330` item 1** — the cage is **not wired into the fast tier** (needs `fast_tier_pathspec`
  + `$SUITE_GUARDS` + `run_guard_trigger_tests.ps1` to move together), and the `schemas.json` pattern
  was **attempted and reverted**: `^(v[0-9]+:)?[0-9a-f]{64}$` reddens **11 fixtures using filler
  values**. Fixing the fixtures is the work; relaxing the pattern is the mistake.
- **`ORDER-236` Row-X** — the EA-shaped rows (scorecard / `EA_MASTER_INDEX` / `B1_DATASET`) are
  **owed, not skipped**: this is a lever park on an existing chassis and whether that takes a
  scorecard row is 👤 the owner's call.
- **Audit what else ran on the stale `Boss_14` binary** (§3.2) — `ORDER-430` and `ORDER-1420` at minimum.

---

## §6 — Standing rules that did not change

- 🚫 No EA verdict from automation · 🚫 `$FullTierBudgetSeconds` pinned at 120.0s · 🚫 `AGENTS.md` ·
  `MASTER_BACKLOG.md` §2 · `s2a_attestations.jsonl` · any `.set` migration · any magic
  allocate/renumber/retire · any history rewrite.
- 🚫 **`ea_template/core/` is now owner-refused for the two-sided change** — do not reopen without them.
- 🚫 **No `.ex5` to the VPS** without an explicit ruling (`live-fleet-runs-pre-132-binaries`).
- **Stage in one call, read the diff in another, commit in a third.** It caught the BOM and the
  quote-stripping last session; this session it caught nothing, which is not evidence it is unneeded.
- **Derive your block yourself immediately before staging.** Highest `## ORDER-<n>` = **1420**;
  highest block held by a lane row = **`1450-1459`** (`MAPFIX`); next free = **`1460-1469`**.
  🔴 **Do not trust that sentence** — a lane took a block *and never appeared in the ledger at all*
  earlier today, which no derivation can detect.

---

<!-- HANDOFF-ROUTING -->

| item | goes to |
|---|---|
| zero qualified hosts under the ratified floor | `ORDER-430` |
| the two-sided refusal, and the closed short question | `ORDER-1420` |
| STAGE 3, the verdict, and the two falsifiers | `ORDER-236` |
| the rider shape, and StackConfirm confirmed on a second symbol | `EDGE_CATALOG` |
| the refusal, the reproduction, and the diagnosis it refutes | `ORDER-1050` |
| the version tag, the refusal, and the two blockers | `ORDER-1330` |
| a per-run swap capture, which item 1 is waiting on | `ORDER-1350` |
| the stale-binary audit | new order |
| a lane that took no ledger row | 👤 the owner + `BACKLOG-D29` |

---

Open with: **"`_triage/PROMPT_NEXT_SESSION_CLEARALL.md` — จองบล็อกใหม่ก่อน (derive เอง · MAPFIX ถือ 1450-1459) · §5 มีของค้าง 5 ข้อ · เริ่มที่ ORDER-1000 (owner เคาะแล้ว dev-compile only) แล้ว ORDER-501 ต้องรอเครื่องเลนเดียว"**
