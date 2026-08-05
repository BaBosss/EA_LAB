# SESSION HANDOFF — AdaptiveGrid_Oil build + add-gating + PA-confirm (2026-07-18)

## What this session did (chronological)
1. **Built an EA from a Facebook idea** ("Adaptive Grid Trading System", WTI oil mean-reversion
   grid). `ea_projects/(Boss)_AdaptiveGrid_Oil/` rev01→rev03, compiles 0/0, all levers as inputs, L3.
2. **~60 backtests → PARKED-VERIFY** (no portable edge). Evidence: fixed-direction = window
   drift-capture; trend filter seed-only = inert; spacing×TP = spike/hole; no config portable across
   symbol+TF; **AUDNZD looked like a real Model-2 both-window plateau (PF 3-4) but Model-4 real ticks
   demolished it (PF 0.61/0.75)**. Marketed PF 5x not reproducible. Verdict: `.../VERDICT.md`.
3. **Extracted 2 reusable chassis levers** (both validated: compile 0/0, run_tests PASS, neutrality
   byte-identical, Model-4 A/B):
   - `_9_RegimeGateAdds` (Stack_DecideAdd) — gate grid ADDS by ADX Regime (was seed-only). AUDNZD M4 DD 12.3%→5.4%.
   - `StackConfirm=CONF_PA_ENGULF` (+ `core/PriceAction.mqh`) — gate adds by engulfing. AUDNZD M4 both-window net −286→+98, DD 9.6%→4.7%.
4. **PA probe** (`ea_projects/(TRD)_PA_Probe/`, FINDINGS.md): naked-PA entry filter FAILS both-window
   (window-fit); PA-confirm on adds of an existing basket WORKS defensively (risk-trimmer, not profit engine).

## Commits (branch master)
- f1ecafe / 9e225ff — AdaptiveGrid build + cross-market + PARKED verdict
- 5c8217f — per-symbol optimize + Model-4 kill of AUDNZD
- 1aeafc0 — add-gating `_9_RegimeGateAdds` chassis lever
- f65bf2c — PA-confirm `CONF_PA_ENGULF` chassis lever + probe findings

## Doctrine paid for this session (fold into the rules)
- **Model 2 (1-min OHLC) manufactures fake PF 3-4 both-window plateaus on GRID EAs.** Always confirm
  grids on Model 4 real ticks. Tell-tale = largest-loss jumps hard on model switch.
- **A confirm/MM layer multiplies or protects an existing edge — it does NOT create one.** Naked-PA/naked-
  signal has no edge (Step 1); PA-confirm only helped when bolted onto a basket that already had one.
- **Judge PA/filters by expectancy-per-trade, not net/PF** — a filter can cut trades so net/DD "improve"
  while win% and expectancy get worse (looks good, is worse).
- Gating only the SEED is inert for a grid (a grid is never flat) — gate the ADDS.

## Open threads (NOT built — decision pending, thin base edge so temper EV)
- Step 3: `PA_LotMult by tier` (Bulkowski pattern-performance tier → lot) = the MM layer. Only meaningful
  where PA raises expectancy. Combine with Fixed-Fractional / Optimal-f (dev-plan Phase 2).
- Step 4: SMC / support-resistance as confluence layers (repo: naked FVG dead, SMC×STO candidate — use as
  confluence, not naked). Same both-window + Model-4 gate applies.
- Higher-EV alternative recommended: apply the 2 new levers to an EXISTING validated CORE EA (multiply a
  real edge) rather than build the full MM/SMC stack on a thin base.
- ⚠️ tpl_regression baseline still stale (pre-existing, benign) — user to refresh when ticks settle.

## Next-session entry points
- Memory: `adaptive-grid-oil-parked.md` (full findings + both levers + Model-2 lesson).
- Dev plan for PA/MM/SMC: `_triage/KNOWLEDGE_SYNTHESIS_EA_DEVPLAN.md`.
- User is taking `_triage/FABLE_REVIEW_PROMPT.md` to a fresh Fable session to re-settle template +
  workflow + optimize + pass/reject/parked + stage-routing.
