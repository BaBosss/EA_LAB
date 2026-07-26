# Codex prompt — full-system audit of EA_LAB + EA Template (2026-07-18)

Dispatch via: `/codex:rescue --background` (task mode). Result file = `_triage/CODEX_SYSTEM_REVIEW_2026-07-18.md` — read that file, not exit code.

---

<task>
You are an independent auditor examining a solo-operator algorithmic-trading research lab at D:\EA_LAB. You have no prior context on this project; form your own judgment from the repository alone.

The system has two layers. Audit both:

1. PROCESS LAYER — the research/validation pipeline that decides which trading EAs live or die:
   - CLAUDE.md (verdict decision tree + numeric bars), PROJECT_STATE.md, AGENTS.md (multi-agent protocol), VISION.md, ROADMAP.md
   - EA_SCORECARD_AND_REGISTRY.md, EA_MASTER_INDEX.csv, EDGE_CATALOG.md, docs/memory_control/ (B1_DATASET.csv, B1_COHORT.md)
   - scripts/check_state.ps1 and any pre-commit hooks

2. CODE LAYER — the MQL5 EA template that all production EAs are built from:
   - ea_template/DESIGN_V2.md, README.md, OPTIMIZE_GUIDE.md
   - ea_template/core/*.mqh (all ~16 modules: MoneyManagement, RiskControl, Recovery, Hedge, Basket, Execution, ExitManager, Regime, Persist, Stack, etc.) and core/entries/
   - ea_template/Boss_11 through Boss_18 .mq5 sources (concrete EAs stamped from the template)
   - ea_template/regression_baseline.csv and the regression script (scripts/tpl_regression.ps1 or similar)

Questions to answer:
- Is the architecture of the template sound for its purpose (one chassis, many EAs, live real-money deployment on MT5)? Where is it fragile, over-coupled, or under-specified?
- In the money/risk code paths (lot sizing, recovery/grid escalation, drawdown caps, persistence across restarts), are there defects or unguarded edge cases that would backtest clean but lose money or silently stop live?
- Does the documented process match what the repo actually shows (registry rows vs verdict rules, baseline freshness, index consistency)? Identify drift.
- What are the top systemic risks of the whole operation — single points of failure, missing safeguards, places where a plausible mistake is expensive and nothing would catch it?
- What would you change first, and why?
</task>

<grounding_rules>
Every finding must cite concrete evidence: file path plus line number or exact quoted text. If a claim is inference rather than observation, label it HYPOTHESIS. Do not report a defect you have not located in the source. If a file referenced by the docs does not exist, report that as a finding rather than assuming its contents.
</grounding_rules>

<structured_output_contract>
Write the full report to _triage/CODEX_SYSTEM_REVIEW_2026-07-18.md with these sections, in order:
1. SYSTEM SUMMARY — your own 10-line description of what this system is and how it works (proves independent understanding).
2. FINDINGS — ranked most-severe first. Each: [SEV-1..4] | layer (process/code) | one-line defect | evidence (file:line) | concrete failure scenario | suggested fix. SEV-1 = can lose real money or halt live trading silently; SEV-4 = hygiene.
3. ARCHITECTURE ASSESSMENT — strengths and weaknesses of the template design, 10 lines max.
4. PROCESS-VS-REALITY DRIFT — where docs and repo state disagree.
5. TOP-3 RECOMMENDATIONS — ordered by expected value, each with a one-line rationale.
Keep the chat reply itself to a 5-line summary pointing at the report file.
</structured_output_contract>

<default_follow_through_policy>
Read-only audit: do not modify, create, or delete any repository file except the single report file above. Do not run backtests, compilers, or trading platforms. When a directory is large, sample representatively and state what you skipped. Proceed without asking questions; note unresolved ambiguities in the report instead.
</default_follow_through_policy>

<dig_deeper_nudge>
Before finishing, re-examine the two highest-risk areas you found and attempt to falsify your own top finding: trace the actual code path or doc chain end-to-end. Upgrade, downgrade, or annotate findings based on that pass.
</dig_deeper_nudge>
