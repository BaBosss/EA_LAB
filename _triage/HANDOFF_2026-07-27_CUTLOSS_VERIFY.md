# HANDOFF 2026-07-27 — cut-loss campaign, verified (session `S-2026-07-27-CUTLOSS-VERIFY`)

**Start here if you are picking up the guardrail work.** One-line summary: **two real-money EAs were
found to be carrying safety claims that do not hold, both claims are now withdrawn in writing, no
live change was forced — and verifying my own detector found the one directory it never looked at.**

Covers 5 orders closed 2026-07-26 (`219` · `220` · `221` · `222` · `215`) plus this session's
verification pass. 4 orders raised (`370`–`373`). No live account touched. No holdout spent.
No tester lane used by this session.

---

## 1. The two things only the user can decide → **ORDER-373**

Both live on **REAL_CENT 159475669**, both user-mix (`ATTESTATION_MAP` confidence `none`), and for
both the honest statement is the same: **nothing is damaged today, and the belief that something
would catch it is what turned out to be false.**

| EA | what was claimed | what was measured |
|---|---|---|
| **NuiIndy** (magic 1524) | `CutLoss=30` = "free tail-insurance, DD bounded ~15%" | It **does** fire — proven to the decimal at **−30.02%** (14 positions closed together, balance 10,521.99 → 7,363.31). But it takes 30% of the balance it has *at that moment* and re-arms against the smaller one: 8 fires in one year at 4× sizing walked the account `10,521 → 7,363 → 5,214 → 4,025 → 3,125 → 2,735 → 2,145 → 1,599 → 1,326`. **eqDD 87% while a "30" threshold was active.** Same year: **+51% with it off, −86% with it on.** A ratchet, not a floor. |
| **MatchaGrid** (magic 20240001) | "bounded grid + hard SL" — the reason it was never filed as uncapped-ruin | `InpCutLossMode=0` **does not respond to its own thresholds at all**. Held stress fixed at 63.94% DD / 66 simultaneous positions and moved the trigger from `10%/$50` to `1%/$1` — the two runs are **identical to the decimal** (2,961 trades, same net, same DD, same four clusters at the same timestamps). Changing it 50× changed nothing. |

**Why neither is an emergency:** at live sizing NuiIndy's switch has never fired in 3 years, and
MatchaGrid has never approached that drawdown in 3.4 years. **The exposure is unchanged from
yesterday — only our description of it is.**

**The one shape both findings point at:** a percentage-of-current-equity kill cannot bound an
account. Only an **absolute equity floor that fires once and stays off** can. Neither EA exposes one.

## 2. What I got wrong, found by verifying my own work → **ORDER-370**

`scripts/check_stale_binaries.ps1` (ORDER-221, mine) scans four roots: `ea_template/`,
`ea_projects/`, `D:\Meta 5b\MQL5\Experts\`, roaming Experts. **Those are where binaries are built and
tested. The place a binary is actually shipped to a chart — `_vps_deploy/**` — has zero records in
it.** Confirmed by filtering the sidecar: 0 rows.

That is the most expensive of the three possible gaps. A stale `ea_template` copy gives someone a
wrong test number; a stale `_vps_deploy` copy means **the wrong EA is trading**, and `.ex5` is
gitignored so nothing else would show it.

**Checked the live case by hand rather than assuming:** the bundle attached yesterday,
`_vps_deploy/BOSS16_KANGAROO_XAU/Boss_16_KangarooGrid.ex5`, is dated **2026-07-24 20:13:33** against
a newest source of **2026-07-24 10:39:46** → **newer than all source, not stale, genuinely fine.** ✅
But the detector cannot tell you that, because it does not look there. We know it only because I
checked manually — which is precisely the state ORDER-219 existed to end.

## 3. Someone else found a worse bug in the same script — and it is instructive

**ORDER-341** (LEVERFAN lane — was uncommitted when I started this pass, **landed as `bb4e1858` while
I was writing it**, now `DONE + REVIEWED`). My script assigned
`HASH_DIFFERS` into a single first-wins `$status` slot *before* the staleness check, which read
`if ($status -eq "OK") { $status = "STALE" }`.

Since MQL5 compilation is not byte-reproducible — **my own ORDER-221 finding** — every EA with more
than one copy mismatches by hash. So `$status` was never `"OK"` by the time staleness was tested, and
**`STALE` could never fire for any multi-copy EA, which is all of them.** Measured on the real tree:
8 labelled STALE while **48 more were genuinely older than their source and wore the advisory
`HASH_DIFFERS` label instead** — the whole `Boss_11..18` chassis family masked, including the copy in
a lane a live A/B was about to run on. The staleness text was still appended to `detail`, so the
information was present and invisible; **the failing label is what makes a human look.**

**The lesson is sharper than the bug:** I introduced a severity split (advisory vs HIGH) specifically
to stop a detector from being ignored — and the advisory label then swallowed the signal it was
supposed to protect. *A first-wins status slot plus a deliberate downgrade means the downgrade can
outrank the thing you actually care about. Rank the statuses, do not race them.*

Post-fix the two pieces compose correctly: `detector_digest` now reports **55 STALE / 85 HASH_DIFFERS
/ 78 OK**, and STALE escalates to HIGH as designed. Verified by running it.

## 4. The five orders, verified

| order | outcome | verified how |
|---|---|---|
| **219** | Empty `detail:""` in all 182 sidecars was a stream bug, not a missing feature: `Write-Host` goes to stream 6, `mt5_run.ps1` captured only `2>&1`. New `detector_digest.ps1` wired into the daily chain, HIGH vs advisory split. `check_state` §7 rewritten to match the *shape* of an entry-point claim. | `grep` confirms `2>&1 6>&1` at `mt5_run.ps1:166`; digest runs and reports; `check_state` = **CLEAN, no drift** |
| **220** | The cage's unit-independence PASS rested on a 6-trade truncated run. Added a full-window leg (E2). Also found **entry 16 had the same debt and it was the one queued for a demo chart** — `K1_scaled_1x`/`2x` were *both* killed; added `K1_scaled_hi` (71 trades, full window). | 13/13 cases pass; `E2_unit_indep_hi` + `K1_scaled_hi` present in source |
| **221** | Stale-binary detector built. En route, **measured that MQL5 compilation is not byte-reproducible** (5 compiles → 5 hashes, 5 sizes), so hash mismatch is not evidence of code difference — downgraded to advisory. Scoped roots from 27 terminal folders to 4, turning 530 findings into a readable 28. | script present; **two defects since found — §2 and §3 above** |
| **222** | NuiIndy `CutLoss=30` tested for the first time. Fires exactly; ratchets. "Free tail-insurance" withdrawn from scorecard, `EA_MASTER_INDEX` (first-ever row for this EA), EDGE_CATALOG, and the ORDER-095 verdict — struck at the offending line, not banner-patched. Blind Codex review taken as doctrine requires. | archived `REVIEWED`; verdict doc present |
| **215** | MatchaGrid: 2 of 5 cited reports are degenerate-tick artefacts (3.9 ticks/bar vs 58–59) — **discarded both, including the flattering one**. Then proved the switch unresponsive (§1). Claim withdrawn everywhere. | still on board (funnel outstanding); verdict doc present |

**Row-X checklist paid for both money findings:** scorecard ✅ · `EA_MASTER_INDEX` ✅ · EDGE_CATALOG ✅ ·
`B1_DATASET` ✅ (5 rows) · user brief ✅ (this file + ORDER-373).

## 5. Three gotchas worth carrying forward

- **The tester is deterministic; the compiler is not.** Same inputs reproduced byte-identical reports
  twice (ORDER-222's ×4 and ×2 pairs). Same source compiled five times gave five different binaries.
  Do not build an identity check on a compiled artifact; do build one on a tester run.
- **A negative close-cluster is not a cut.** At raised risk, ordinary grid churn produces bigger
  dollar losses that *look* like a stop firing. My first ORDER-215 pass stopped on exactly that and
  was wrong; the balance ratio settled it (−0.63% of balance, not 30%). **Judge a cut by its fraction
  of the balance immediately before it, never by its dollar size.**
- **A control arm can be decided by the calendar.** In ORDER-222 the no-cut arm's only loss event was
  the tester's forced end-of-test liquidation, so its net depended on where the window happened to
  end. Good enough to prove the switch fires; **not** good enough to rank settings long-horizon —
  hence ORDER-372.

## 6. Notes for whoever picks this up

- **`scripts/check_stale_binaries.ps1` is free to edit again** — the ORDER-341 fix landed as
  `bb4e1858` mid-session (it was uncommitted when I began, which is why ORDER-370 was written to wait
  on it). ORDER-370 can proceed now; rebase onto the fixed ranking logic rather than the version I
  wrote.
- **Do not compare numbers across MT5 installs.** `Meta 5b`'s CHFJPY history is measurably divergent
  from the primary's (14× tick-count difference on an identical window). ORDER-280 independently hit
  the same thing on BTC and rewrote its bars to be lane-relative. → ORDER-371.
- **I did not follow the session-ledger rule yesterday** (it was created mid-session by a parallel
  lane). Backfilled retroactively in `21985fc8`; registered properly this time before touching
  anything. Two of my commits also got swept into other sessions' commits (`47319bef`, `6df2d6b5`) —
  content intact, provenance wrong, which is the known limit of path-limited commits on a shared
  worktree.
- **Four of my five orders are already archived and REVIEWED** by the GREENYELLOW lane. Only ORDER-215
  remains on the board, and only its *funnel* half — the cut-loss half is closed.

<!-- HANDOFF-ROUTING -->

| item | destination |
|---|---|
| `_vps_deploy/**` invisible to the stale-binary detector | ORDER-370 |
| `Meta 5b` tick history divergent from primary; decide sync-vs-ban-cross-install | ORDER-371 |
| NuiIndy 30-vs-100 long-horizon ranking (extend window past the forced close) | ORDER-372 |
| User decision: what to do about two withdrawn guardrail claims on real money | ORDER-373 |
| MatchaGrid: what other `InpCutLossMode` values do; clean-MAIN + fan + flat-lot + Model-4 funnel | ORDER-215 |
| ORDER-341 fix to my status-ranking bug (LEVERFAN lane, in flight) | ORDER-341 |
| Boss_16 attached bundle verified not stale by hand | DONE |
| ORDER-219 / 220 / 221 / 222 closed, reviewed, archived | DONE |
| Both safety claims withdrawn across scorecard, index, catalog, ORDER-095 verdict | DONE |
