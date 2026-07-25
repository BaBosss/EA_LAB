# HANDOFF 2026-07-25 — genetic optimizer policy session (Fable seat)

**Session shape:** one grill session, no EA verdicts issued. Output = a written policy plus three
repo fixes and one open order. Started from `scratchpad/GENETIC_POLICY_PROMPT.md`.

## What was decided (canonical text lives in the skill, NOT here)

`backtest-optimize-rigor` **LADDER Step 2** is the owner. Summary of the ratified rules:

| question | answer |
|---|---|
| genetic allowed? | **MT5 yes** (ban repealed — its stated reason was false) · **MT4 no** (genuinely no per-pass params → `mt4_grid_sweep.ps1`) |
| when genetic vs complete | combo count (product of `Y` dims): **≤~1,000 → complete** · **>1,000 → genetic coarse → fine complete grid ≤1,000 around the zone** |
| criterion | **7 = Complex** (default now in `mt5_optimize.ps1`) · engine-edge class → `1` (PF) + trade floor ×2 |
| trade floor before reading a surface | H4/D1 ≥60 · H1/M30 ≥100 · ≤M15 ≥250 per 36-mo MAIN |
| two-window | search **MAIN only**; BWD is never a search surface; center fails BWD → **one logged re-pick** from the same plateau, then diagnosis |
| window length | **never shortened to save wall-clock** (user withdrew this idea during the grill). >~2 h → overnight/batch |
| point-test | may only confirm a locked .set, run a 1-dim A/B, or diagnose — **never select params while ≥2 dims are unexplored** |
| cores | tester local agents **18 of 20** (2 left for Claude/Codex/Chrome) |

**Why the ban existed and why it fell:** the skill said "never MT genetic for selection — it can't
export per-pass params to lock a .set". True for MT4, false for MT5: `OPT_MDX_GBP_coarse.xml`
carries all 8 swept dimensions as per-pass columns across 2,295 rows. Sessions after 2026-07-19
were *obeying a rule whose rationale was wrong* — so this was not plain drift. **Lesson worth
keeping: audit whether a rule's stated reason is still true, not just whether people follow it.**

## Repo changes (commits `b9ba8c84` · `30598b55` · `304695a0`)

1. `scripts/mt5_optimize.ps1` — `-Criterion` default **0 → 7**; `Leverage` now written as **`1:N`**.
   The bare `Leverage=100` form was a **silent no-op**: every past optimize actually ran at the
   server default **1:2000** (visible in the XML DocumentProperties of the old runs).
2. `scripts/optimize_guard.ps1` — an EA the registry has never catalogued (non-Boss, zero name
   matches) now yields **warn-only** on UNKNOWN instead of REFUSE. Refusing whole unregistered EAs
   was training every operator to pass `-SkipOptimizeGuard`, which would have disabled the checks
   that DO have evidence. Safety names (`RC_*`, `ProtectLevel`, `_9_MaxLevels`) still REFUSE
   unconditionally — verified.
3. `.claude/agents/ea-validator.md` — mode-by-combo-count, trade floor, no window shortening, one
   BWD re-pick. (Replaces the old "judge optimize by elapsed time, cap ~1hr" instruction.)
   `ea-screener.md` needed no change (it carries no optimize doctrine).
4. Skill edit is in `C:\Users\patip\.claude\skills\` — **that directory is its own git repo**; the
   Step 2 rewrite is committed there separately from EA_LAB.

## Assert run — both one-time checks PASSED, plus an unplanned finding

`ASSERT204_MDX_GBP_H4` (MacdDiv GBPUSD H4, MAIN, complete, 12 passes) run on the **portable
`D:\Meta 5b`** instance because the live terminal (146237, real money attached) was open — **never
kill a terminal with live accounts attached to free the tester; use the portable instance.**

- Leverage tag in XML = **100** (was 2000) → the `1:N` fix works
- Result column = **25.81–33.77** → Complex scale confirmed, so `Criterion=7` maps correctly on
  build 5836. Balance-max would have printed profit-sized numbers.
- **Unplanned:** `_01_LookbackBars` is **inert** on this EA — 80/100/120 all return Result 33.77,
  PF 1.229813, 235 trades identically; only `_01_SwingRadius` moves anything. So the pre-policy
  `OPT_MDX_GBP` sweeps paid for a dead dimension, and its flat surface reads as a "robust plateau".
  This is exactly the failure mode `optimize_guard` was built for but cannot catch on an
  unregistered EA.

## Open work

- **ORDER-204 (OPEN, qwen/ZCode lane)** — retro-audit the 66 pre-policy genetic runs: which
  verdicts rest on a genetic result with no fine-grid + fan behind it (`DEBT`), plus the new
  `inert-dim-suspect` column (`INERT:<dim>` when a dimension's values all return identical
  metrics). Report only; no verdict edits; the lead decides what gets re-verified.
- **User action left:** confirm MT5 local agents = 18 (Core 02/03 disabled in the Agents tab is
  exactly this — nothing else to press).
- Not done in this session by design: no EA was optimized, screened, or judged.

## Collision note (third time this week)

The parallel session took **ORDER-203** (MRIS classifier bug) minutes before this session's order
was pasted, and the user's `git commit -- AGENT_TASKBOARD.md` did not land. Renumbered to
**ORDER-204** and reformatted (the pasted text had lost its markdown and had no `## ORDER-nnn`
header, which the taskboard validator would have flagged). Commits here stayed path-limited
throughout.
