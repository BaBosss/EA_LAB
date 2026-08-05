# PROMPTS — 2026-07-28, paste-ready

> ⚠️ canonical entry = `PROJECT_STATE.md` · this file owns: **two copy-paste prompts produced at the end of
> `S-2026-07-28-QUEUERUN`** — one to open the next Claude session, one to hand to Codex by hand.
> Written as files because the lane that produced them could not edit `AGENT_TASKBOARD.md`: a parallel lane
> (`SLBUFFER`, ORDER-352) had uncommitted work in that same file, and a path-limited commit would have swept it.

---

## PROMPT 1 — open the next Claude Code session

### ===== PASTE FROM HERE =====

You are picking up the EA_LAB repo at `D:\EA_LAB` after session `S-2026-07-28-QUEUERUN`. Reply to me in Thai.

Read in this order before touching anything: `PROJECT_STATE.md` → `_triage/HANDOFF_2026-07-28_QUEUERUN.md` →
`docs/SESSION_LEDGER.md` (check which lanes are ACTIVE **right now** — as of 2026-07-28 10:35 the `SLBUFFER`
lane was reopened and actively writing `AGENT_TASKBOARD.md`, `EDGE_CATALOG.md` and `B1_DATASET.csv` for
ORDER-352).

**Lane rules that bind you:**
- Reserve your own row in `docs/SESSION_LEDGER.md` and commit it path-limited **before** touching anything.
  Next free order block is **510-519** (highest number in use = 501).
- **Flip your row back to `ACTIVE` if you resume after writing a handoff.** The previous lane left its row
  reading `CLOSED` while it kept working for two hours, and `check_order_collision.ps1` printed
  *"no ACTIVE lane — reserved-block and owned-path rules skipped"* on every commit in that window. Another
  lane then acted on that false reading. `CLOSED` means "the guard may stop watching", not "handoff written".
- Commit path-limited only. Never `git add -A`, never `git stash` — this working tree is shared.
- **Before staging `AGENT_TASKBOARD.md` / `EDGE_CATALOG.md` / `B1_DATASET.csv`, run `git diff <file>` and
  confirm nothing in the diff belongs to another lane.** Path-limiting protects across files, not across
  lines in one file.
- **Do not regenerate `TASKBOARD_DIGEST.md` while another lane has uncommitted board edits** — it bakes their
  in-flight work into a generated file and commits it under your name.

### Job 1 — ORDER-236 STEP 2 (the main piece of work waiting)

ORDER-236 was un-parked on 2026-07-28. The caged lever pair `_9_RegimeGateAdds` + `CONF_PA_ENGULF` is built,
byte-identical when off, and now has a qualified host: **`Boss_14_GridLog` @ XAUUSD H1** (ORDER-430 measured
BWD PF **2.29** at 52 trades — highest of seven hosts, qualified under the pre-registered bar).

**The order row does not yet carry a command template. Writing one is the first task** — do it when the board
is free of other lanes' uncommitted edits, and follow the shape ORDER-430 uses.

Facts you need, all verified 2026-07-28:
- Lane: **`D:\Meta 5b`** (portable), **Model 4 real ticks, mandatory** — Model 1/2 are not evidence for a grid
  on this chassis. `D:\Meta 5c` has no tick cache and cannot run Model 4.
- Binary `D:\Meta 5b\MQL5\Experts\Boss_14_GridLog.ex5`, mtime 2026-07-27 08:55 — newer than its include graph.
  **Still confirm on the first report's Inputs page** that `_9_RegimeGateAdds`, `_50_RegimeMode`,
  `StackConfirm` appear *with the pinned values*. A name appearing is not enough; ORDER-236 already lost a
  cycle to exactly that.
- Sets on disk: `ea_template/sets/B14_AB_off.set` · `B14_AB_on.set` · `B14_PAon.set` ·
  `_mt5_auto/ab_sets/b14_lever/AB_both.set` · and ORDER-430's pinned control at
  `_mt5_auto/ab_sets/order430/CTRL.set`.
- 🔴 **Pre-flight that is not written in the order yet:** ORDER-430's CTRL pins four lines
  (`_9_RegimeGateAdds=false`, `_50_RegimeMode=0`, `StackConfirm=0`, `_9_PA_MinBodyRatio=1.0`). **Verify with
  `Compare-Object` that each A/B arm differs from that CTRL only on the lever it is meant to change.** If an
  arm is missing a pin, MT5 fills it from the per-terminal cache and the two sides of the A/B silently become
  the same run reporting a clean null.
- Bar = **delta vs the control in the same lane**, not an absolute PF. The old absolute bar was withdrawn
  because it measured the host, not the lever.
- 🔴 **Caveats to write onto every delta:** the host's MAIN is **0.95 (<1.0)** and its BWD has only **52
  trades**. So a positive delta says the lever does something to this base; it does **not** say the
  combination is deployable. Report trade counts on every row and do not over-read a delta smaller than the
  noise of a 52-trade sample. AUDCAD H1 (BWD 2.20, 62 trades) is available as a replication host.

**Prohibitions:** write a verdict (that is the lead's job) · report Model 1 or 2 numbers as evidence · touch
the 2026 window · compare against a number from another MT5 install (ORDER-371 is still open) · modify
anything under `_vps_deploy/` · touch `.mq5` or `ea_template/core/`.

### Job 2 — ask me to decide ORDER-500

`docs/memory_control/B1_DATASET.csv` is append-only and enforced by the ORDER-144 guard, and it currently
holds **two** rows that cannot be repaired: `ORDER-412`'s row swallowed `ORDER-280`'s row through a missing
newline, and `ORDER-430`'s row asserts a claim that was retracted the same day. Three options with their costs
are written into ORDER-500. **Do not pick one for me** — present them and take my answer. The
lane that opened it recommends an **appendable retraction record** (a `retracts` column, or a `CORRECTION`
row type) because that stays compatible with append-only rather than opening the file to edits.

### Job 3 — carry these forward if there is time

- **ORDER-490** — a two-arm test is written and ready: force guard G4 via a custom symbol with a large
  `SYMBOL_TRADE_STOPS_LEVEL` and `_17_SLbufferATR=0` (must fire), plus a specificity control at
  `STOPS_LEVEL=0` (must stay silent). There is also an unowned finding on that row: `Wave5_SLValid()` ignores
  tick size and freeze level and validates before digit normalization.
- **ORDER-501** — the event-log cage fails two concurrency cases *only under machine load*
  (`events=144 expected=150`). Discriminating first step is written on the row. Do not file it as flaky
  without measuring.
- **ORDER-432 finding 2** still lacks a test that fails without its fix, which is what blocks that order.

### ===== PASTE TO HERE =====

---

## PROMPT 2 — hand to Codex yourself

<sub>Why by hand: the same audit was dispatched through the plugin on 2026-07-28 and **hung**. It tried to run
the 105-case suite itself, hit its own 10-minute command ceiling at 82/105 (all passing), started a background
`-DevFast` run and waited for a notification that never came. Its process died; the job still reads `running`.
This version **forbids running the suite**, which is the whole cause. It salvaged one real finding before
dying — that the hook has seven `-File` calls, not six — and that gap is already fixed, so do not re-report it
as news.</sub>

### ===== PASTE FROM HERE =====

REPO: `D:\EA_LAB` (Windows, **PowerShell 5.1**). Review a change made on 2026-07-28, committed as `45ed70d7`.

**Read-only, static analysis only. Do NOT run the test suite — it takes ~9 minutes and a previous attempt at
this exact review hung on it. Do NOT commit, do NOT edit files, do NOT use `git stash`, do NOT run MT5.**

Target: `scripts/_test/run_order105_negative_tests.ps1`, a 105-case negative-test suite guarding
`scripts/check_experiment_events.ps1`, which `.githooks/pre-commit` enforces on every commit. Three edits:

1. `Invoke-TestGit`: `.TrimEnd("`r","`n"," ")` became `.Trim()`, plus a fallback message when a git child
   exits non-zero with empty stdout and stderr.
2. `Initialize-Seed`: a hardcoded list of pass-stub scripts was replaced by one **derived at runtime** from
   `.githooks/pre-commit` via `[regex]::Matches($hookText,'-File\s+(scripts/[A-Za-z0-9_/]+)\.ps1')`, excluding
   `scripts/check_experiment_events` (the guard under test), with a `throw` if fewer than 2 are parsed.
3. Two assertions reading `-cnotmatch 'cannot find the file.*check_verdict_kill'` became
   `-cnotmatch 'cannot find the file'`.

Answer these, in order, from the source:

1. **Can the regex miss an invocation form the hook uses or could plausibly use?** A variable holding the
   script path, `&` call operator, backslash separators, `.\scripts\...`, a quoted path, a heredoc, a
   conditional branch. **A miss silently re-creates the bug this change exists to prevent**, and it would
   surface as an unrelated red case.
2. **Is excluding `check_experiment_events` correct and robust?** What if the hook invokes it by a different
   path, or twice?
3. **`Trim()` vs `TrimEnd()`** — enumerate every consumer of the returned `.Text` and say whether trimming the
   *front* can change behavior for any. Pay attention to results fed into git plumbing (`update-index
   --cacheinfo`, `rev-parse` output used as a SHA). Neutral, safer, or riskier — and which call site decides
   it.
4. **Did generalizing those two assertions weaken or strengthen them?** Is there legitimate output on those
   cases that would now trip the assertion?
5. **Is `throw` at fewer-than-2 the right failure mode and threshold?** Would a partial parse — say 3 of 7 —
   pass silently and cause a confusing downstream failure?
6. **Is this over-engineered?** Would a simpler fix have been better? This is the question I most want
   answered; argue it rather than being polite about it.

Cite `file:line` for every claim. Say what you traced. "This is fine" is only useful if you name what you
checked.

### ===== PASTE TO HERE =====
