# HANDOFF — 2026-07-28 `S-2026-07-28-DECISIONS` — the four ratified calls, and what the screenshots changed

> ⚠️ canonical entry = `PROJECT_STATE.md` · this file owns: **the shift note for the lane that landed the four
> decisions the user ratified on 2026-07-28, and the live-fleet finding that came out of checking them.**
> Not a queue — every item below has a row on the board (routing table at the end).

**Lane:** `S-2026-07-28-DECISIONS`, block **510-519** (opened **510** and **511**). No MT5 lane, no compile,
nothing copied to the VPS. One parallel lane (`S-2026-07-27-SLBUFFER`) was ACTIVE throughout; no row overlap,
and every commit's diff was checked for its content before staging.

---

## 1. The four decisions, and where each one now lives

| order | ratified | landed in |
|---|---|---|
| **235** thin-EA judge bar | replace the 30-trade count, don't slide the date | `CLAUDE.md` VERDICT GATE bar table + `DEMO_DEPLOYMENT_PLAN.md` (`aa2cb4f6`) |
| **371** cross-install comparison | ban permanently, don't re-sync `Bases` | `AGENTS.md` §3 iron rules (`aa2cb4f6`) |
| **232** MacroGate 990120 | keep as an advisory sensor | board row, with the competing advice recorded as refuted (`0e7fea51`) |
| **500** B1 repair path | option B — audited hatch, not a workaround | `scripts/lib/b1_guard.ps1` + both hooks + a 23-case cage + the data repair |

**ORDER-235's shape matters more than its numbers.** At 0.2–0.3 closed trades/week, four EAs — one on real
money — reach 30 trades in 2028-2029. Moving the judge date leaves them three years with no decision
criterion, which is not a bar but the absence of one. The count is *replaced* for EAs under 0.5 trades/week
(12 months · net positive · no kill tripped · both-window evidence already clear), and the weaker statistic is
paid for in size: permanently small lot, never sized up on PF.

**One thing was deliberately NOT written as a number.** ORDER-430 measured that *"an n appropriate to the
type"* does no work for grids — the hosts that cleared BWD took **52 and 62 trades at under 2% drawdown**
while every host that failed took **343–473**. A participation floor would close it, but inventing that
threshold myself is exactly the silent bar drift ORDER-235 exists to stop, so the gate carries a
`PENDING-RATIFY(user)` note instead of a made-up figure.

---

## 2. Two user tasks closed without the user doing them

### ORDER-230 — the question had been answered four hours before the order was written

`ACCOUNTS.csv` has carried *"RESOLVED 2026-07-26: user confirmed directly = DEMO, currency USD (not cent)"*
since commit **`89ba5f89` (17:17)**, recording three VPS screenshots. The board row asking it was created at
**13:20 the same day** (`74b47463`). Nobody walked back to flip it, so it sat open for two days and was ranked
**second** in a paste-ready user brief, described as the field every risk figure for ~13 October-judge EAs
rests on.

**Second time in three days a user was nearly sent to redo finished work** — ORDER-233 was the first, caught
by `S-2026-07-27-USERQUEUE`. Both have the same shape: **the answer was recorded in the correct destination
file while the board row stayed open.** ⇒ **grep the destination file for an answer before handing any task
to the user; do not trust the status on the board.**

### ORDER-410 — the inventory answered a different question than the one asked

19 of 20 lab binaries on the VPS match the staged bundle **byte for byte**. `TrendRider_XAU` first read as
missing and is not — it is there under its original filename with an identical hash, so **matching by filename
produced a false alarm and only the hash settled it.** Two genuinely stale spots exist, neither where the
order was looking: a frozen `EALabTpl\` snapshot from 2026-07-05 sitting beside the current binaries, and one
terminal whose seven files all date from 07-08.

**A file on disk is not evidence a chart is attached to it, and the inventory cannot close that gap.**

---

## 3. 🔴 The finding that was not in any order — ORDER-510

Two independent measurements taken hours apart, from opposite directions, say the same thing.

**Disk:** the Boss binaries actually on the VPS are `Boss_14` **07-16** · `Boss_17` **07-17** · `Boss_12`
**07-18**, while persist scoping (`Boss2_` key format) landed **07-19** (`0dcf60e2`).
**Terminal:** F3 on the two accounts that host template EAs shows five keys in the **pre-132 magic-only**
format (`Boss_990208_rc_peak_eq`, `Boss_990001`, `990120`, `990301`, `990302`) and **not one scoped `Boss2_`
key.**

⇒ **the ORDER-132/138 persist hardening has never been on a live chart.** What those orders closed was *"the
code is right"*, not *"what is running is right"*, and no row ever owned that gap.

**The trap:** [`RiskControl.mqh:142`](../ea_template/core/RiskControl.mqh) refuses `OnInit` while a legacy key
exists and `RC_AdoptLegacyHalt=false` (the default). **Deploying the current build to those charts stops five
EAs at once**, leaving only a `[RISK] FATAL` journal line — on screen it reads as *"the EA went quiet"*, not as
a designed refusal. `990208` is Boss_14 GBPJPY, the real-money candidate ORDER-234 was gating.

🔴 **Standing prohibition while ORDER-510 is open: do not copy, rebuild or overwrite any `Boss_*.ex5` on the VPS.**

### I got this wrong once first, and the reason is worth keeping

My first read of the GV data said *"empty — nothing to migrate, ORDER-234 is a no-op."* That was from the
`159503454` terminal, whose EAs (Zeus rev01, Squeeze, Trendline, EA_BREAKOUT_XAU) are **all standalone and do
not use persist at all** — Zeus includes `STANDALONE_RISK_BUNDLE.mqh`, not `core/LabCore.mqh`. **It was empty
because nothing ever wrote there, not because it was clean.** Same class as memory
`guard-disarmed-by-prose-reported-as-note`: *"cannot read the input"* must never be reported as *"nothing to
enforce"*. The correct check was to first ask which EAs even write these keys, then look only at those hosts.

**Not diagnosed, on purpose:** `rc_peak_eq = 10,136` on an account whose equity is **99,944** (a 90,000 deposit
on 07-25 never moved it) looks wrong — but **the running binary is not the current source, so reading the
current source cannot diagnose it.** That needs the EA's own Journal. Filed as ORDER-510 STEP 3.

---

## 4. ORDER-500 — closed, and every interesting part came from running it

The rules now live in `scripts/lib/b1_guard.ps1`, dot-sourced by the pre-commit checker, the commit-msg hook
and the cage: **one implementation, three callers**, so ORDER-421's fixture-drift class cannot recur here.
Append-only moved to `commit-msg` (it must read *this* commit's message; pre-commit structurally cannot, and
blocking there would mean the hatch could never open). Row shape stays in pre-commit and **applies to a
declared repair too**.

**Both directions proven on the real diff:** the identical repair with an ordinary message was **blocked**
(including a message containing the word *"repair"* in prose), and passed only with `B1-REPAIR`.
**Data repaired:** one LF, 108,867 → 108,868 bytes ⇒ 95 rows, ORDER-280 present, ORDER-412 intact, zero rows
with a field count other than 13.

**Three things I did not predict, all found by execution:**
1. **The cage went red on its first run — against a bug in the library I had just written.** The field
   splitter returned a one-element array, PowerShell handed it back as a scalar, `.Count` threw under
   StrictMode. That is memory `powershell-pipeline-count-null-on-single-result` **landing inside the guard
   written to stop silent-pass bugs.**
2. **The row-shape rule blocks every commit touching B1 while a malformed row exists** ⇒ it freezes the
   Contract D append rule repo-wide. This is why the guard and the repair had to ship in one session rather
   than as two tickets — a fact about the design that only appeared when it ran.
3. **`Set-StrictMode` in a dot-sourced library runs in the caller's scope.** It changed the semantics of all
   of `check_precommit_staged.ps1`, and an unrelated chain-integrity check threw on a `.Length` that had been
   fine for weeks. **My commit was rejected by my own regression.** A shared library must be inert to its
   caller beyond the functions it defines.

---

## 5. Things the next session should not trip over

- 🔴 **`_triage/PROMPTS_2026-07-28_HANDOFF.md` (written by the parallel lane at 10:47) is already stale.**
  It tells the next session that *"ORDER-236 STEP 2 is the main piece of work waiting"* — ORDER-430 answered
  that and 236 is **PARKED** for want of a host — and asks the user to *decide ORDER-500*, which is decided
  and closed. **Same failure class as ORDER-230/233 in section 2, one hour old.** Not edited here because the
  file belongs to that lane.
- **ORDER-400 is deliberately still OPEN.** Both logins are done, but no rotation has run since (`logs/` and
  `portfolio/` have nothing written after 07:36), so floating coverage has not been re-measured. The order's
  own acceptance criterion is *"confirmation is not 'I clicked login'"*.
- The fast-cage **trigger glob list is the wrong shape** — it enumerates directories that happen to hold
  guarded files, so each new location is a silent skip. ORDER-434 and ORDER-500 both had to widen it one day
  apart. Fixing it properly needs its own cage.

---

## ปลายทางของทุกรายการ

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| Thin-EA judge bar: 12 months + net positive + permanently small lot, replacing 30 trades | ORDER-235 (REVIEWED) — `CLAUDE.md` + `DEMO_DEPLOYMENT_PLAN.md` |
| Cross-install number comparison banned permanently; every result must name its lane | ORDER-371 (REVIEWED) — `AGENTS.md` §3 |
| MacroGate 990120 stays an advisory sensor; the "move to AUDJPY" advice recorded as refuted | ORDER-232 (DECIDED) |
| B1 audited repair path + row-shape assertion + 23-case cage, both directions proven | ORDER-500 (REVIEWED) |
| ORDER-280's row restored; B1 parses as 95 rows with zero malformed | ORDER-500 (`b97dca42`, first use of `B1-REPAIR`) |
| Account 463666728 is USD — answered 07-26, order written 4 hours earlier and never flipped | ORDER-230 (REVIEWED) |
| VPS runs what the repo staged: 19/20 byte-identical; filename matching gave a false alarm | ORDER-410 (STEP 1 DONE + REVIEWED) |
| Live fleet runs pre-132 binaries; updating them stops 5 EAs silently | **ORDER-510 (OPEN)** |
| `rc_peak_eq` 10,136 vs equity 99,944 — needs the EA's Journal, not the current source | ORDER-510 STEP 3 |
| Template EA running on the default magic 990001, absent from DEPLOYMENTS.csv | **ORDER-511 (OPEN)** |
| PERSIST_MIGRATION checklist — not a no-op after all; waits on ORDER-510's procedure | ORDER-234 (rewritten, still OPEN) |
| Logins done, floating coverage not yet re-measured | ORDER-400 (still OPEN by design) |
| Participation floor for grid BWD passes — measured, deliberately left un-numbered | `CLAUDE.md` `PENDING-RATIFY(user)` |
| Fast-cage trigger glob enumerates directories instead of dependencies | BACKLOG (needs its own cage) |
| `_triage/PROMPTS_2026-07-28_HANDOFF.md` points the next session at settled work | that lane's file — flagged, not edited |
