You are advising on **EA_LAB** (D:\EA_LAB) — a one-person systematic lab that designs, backtests,
and deploys MT5 Expert Advisors, run by an experienced discretionary trader who now builds automated
strategies with an AI engineering team (Claude Code as lead engineer + Codex as blind auditor).

I want you to help me **re-settle and clarify, from scratch, 5 parts of how this lab operates.** Treat
the current docs as a starting point that may have drift, redundancy, or gaps — question them, don't
just summarize. Give me a crisp, decision-ready framework for each part, and flag every place the
current setup contradicts itself or is unclear.

## Read these first (authoritative sources)
- `CLAUDE.md` — the VERDICT GATE + operating rules (paid for with real mistakes; do not casually override).
- `PROJECT_STATE.md`, `VISION.md`, `AGENTS.md` — direction, dual-track, multi-agent protocol.
- `ea_template/` — the "Boss V2" chassis: `core/` modules (Inputs, Entry via entries/, Stack, Regime,
  PriceAction, MoneyManagement, ExitManager, RiskControl, Hedge, Persist, LabCore) + `Boss_11..17_*.mq5`
  builds + `tests/run_tests.ps1` + `sets/`.
- `EDGE_CATALOG.md` — what has/hasn't worked and why (edge mechanisms + anti-edges).
- Skills in `C:\Users\patip\.claude\skills\` (strategy-and-risk, mql-code-generator, backtest-optimize-rigor,
  robustness-validator, portfolio-selector, live-deployment-controller, signal-scanner, vps-deploy-ops).
- Fresh evidence from the last session: `_triage/SESSION_HANDOFF_2026-07-18_ADAPTGRID_PA.md`.

## Hard-won lessons from the latest session (bake these into your framework)
1. **Model 2 (1-min OHLC) manufactures fake PF 3-4 both-window "plateaus" on grid EAs.** A grid that looked
   validated (AUDNZD both-window PF 3-4, low DD) lost outright on Model 4 real ticks (PF 0.6). Tell-tale =
   largest-loss jumps hard on model switch.
2. **A confirm/filter/MM layer multiplies or protects an existing edge — it never creates one.** Naked
   price-action / naked signal failed both-window; the same PA only added value bolted onto a basket that
   already had an edge.
3. **Judge filters by expectancy-per-trade, not net/PF** — a filter can cut trades so net & DD "improve"
   while win% and expectancy actually get worse.
4. **For a grid, gating only the first (flat) entry is inert — you must gate the ADDS.**

## The 5 parts I want you to re-settle (give me a clear spec + open-question resolutions for each)

**1. Template EA architecture.** Is the LabCore module set the right decomposition? Where are the seams
weak or redundant (e.g. we just found the Regime gate only covered the seed, not adds — a gap we patched)?
What belongs in the chassis vs a per-EA module? How should new confirm layers (PriceAction, and future SMC /
support-resistance) plug in without bloating the core? Give a target module map + rules for adding to it.

**2. Dev workflow (idea → shippable EA).** Lay out the canonical pipeline and who/what runs each stage
(the skills, the cage: compile 0/0 → tpl_regression CLEAN → run_tests PASS, the delegation cost-tiers,
Codex as blind auditor). Where does it currently get ambiguous or skipped? Give a single clear flowchart.

**3. Optimize strategy.** Consolidate the VERDICT GATE optimize procedure into a crisp, ordered method:
which levers, coarse→surface (plateau vs spike), both-window, plateau-center selection, holdout, Monte
Carlo, and **when Model 4 is mandatory (grids!) vs Model 2 acceptable**. Include the anti-overfit rules and
how many runs/levers are "enough". Flag anything in the current skill that's vague.

**4. Pass / Reject / Parked decision framework.** Give me one decision tree that cleanly separates:
STRUCTURAL death (kill outright) vs PARAMETRIC weakness (must optimize first) vs PARKED-VERIFY (PF>1 but
not deploy-ready = buildable) vs DEPLOY (both-window + holdout + MC + Model-4 passed). Define the exact
numeric/qualitative bars for each transition, and where "build-on ≠ deploy" applies.

**5. Handoff / routing between stages.** For each stage boundary (design→code, code→backtest,
backtest→optimize, optimize→robustness, robustness→portfolio, portfolio→deploy, and any REJECT/PARK exit),
specify: what artifact is handed over, what gate must be green to pass, who does it, and what gets written
where (scorecard, EDGE_CATALOG, memory, PROJECT_STATE). I want no stage where "what happens next" is unclear.

## Deliverable
For each of the 5 parts: (a) a short "current state + problems" diagnosis, (b) the re-settled spec/tree/
flow, (c) the specific doc(s) I should update to lock it in. Be opinionated and concrete — recommend one
answer per open question, not a menu. Keep it tight; I will take your output and have Claude Code implement
the doc/code changes.
