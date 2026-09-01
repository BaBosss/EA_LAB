# EA_LAB Milestone Scrutiny Checklist

Status: `VALIDATION CHECKLIST / NO NEW AUTHORITY`
Authority: analytical/process QA only. It does not replace independent review or any canonical verdict/approval owner.

## Purpose

Run this after deterministic QA and before accepting a material research milestone, or as the final focused pass after an independent review. The question is not only “are the numbers correct?” but also “did the workflow earn the decision without hindsight, selection bias or avoidable waste?”

## A. Identity and methodology

- Is the exact source/build/set/tester/install/window identity pinned?
- Did preregistration precede evidence generation and parameter selection?
- Is every child one logical change unless an authorized optimization contract explicitly opened a multi-parameter surface?
- Are MAIN, BWD and HOLDOUT roles preserved exactly?
- Were mechanical/harness/environment failures separated from strategy losses?
- Are reused parent/accepted evidence and newly generated evidence distinguishable?

## B. Selection-bias and hindsight audit

- Was any range, objective, endpoint or comparison changed after seeing target results without a new prospective contract?
- Was BWD mined repeatedly to select parameters?
- Was HOLDOUT used for tuning, rescue or ranking?
- Is a top-PF spike being mistaken for a stable region?
- Are boundary winners, multiple-testing exposure, empty cells and contradictory years/regimes visible?
- Was a local/home-specific improvement incorrectly generalized as portable?

## C. Economic and participation audit

- Does improvement survive participation/trade/cycle context rather than PF alone?
- Is profit concentrated in one trade, cycle, month or very long-lived episode?
- Did DD improve only because activity/exposure collapsed?
- For grid/multi-position EAs, are depth, total lots, grid span, duration and concentration visible?
- Are parent-child economic deltas explicit enough to justify adoption rather than merely positivity?

## D. Report and claim audit

- Can every headline number be recomputed from durable machine evidence/raw reports?
- Are native MT5 data and reconstructed proxies labeled separately?
- Are missing fields explicitly `UNKNOWN`, `UNAVAILABLE` or `NOT RUN` rather than inferred?
- Are Evidence, Interpretation and Decision visibly separated?
- Does the report meet the current Report Ladder stage without unnecessary dossier overhead?
- Are conclusions causal only where the experiment design supports causality?

## E. Authority audit

- Does the result stay inside the contract’s authority ceiling?
- Are HOLDOUT, Model-4, MC, Candidate, DEMO, LIVE, risk/default, KINT and Grade states explicit where relevant?
- Did a research PASS accidentally become strategy-default or deployment authority?
- Does any owner hard stop require action before the proposed next transition?

## F. Workflow-efficiency audit

Record process defects separately from strategy evidence:
- repeated shell quoting/interpolation failures;
- repeated fresh-worktree Python/runtime hydration;
- duplicate reviewer/model launches;
- unnecessary accepted-evidence reruns;
- origin re-anchor count and whether state sync was deferred until the end;
- report boilerplate that should become a deterministic generator;
- model calls lacking unique output, downstream skip or direct consumer;
- experiments that could not have changed the routing decision.

If the same mechanical friction appears twice, create or reuse a bounded deterministic helper instead of solving it manually again.

## G. Scrutiny result

Return one of:
- `SCRUTINY_PASS` — no material decision defect;
- `SCRUTINY_PASS_WITH_PROCESS_IMPROVEMENTS` — decision stands, but bounded workflow hardening is worth doing;
- `SCRUTINY_REPAIR_REQUIRED` — a material report/methodology defect can be repaired without a new experiment;
- `SCRUTINY_BLOCKED_NEW_WORK` — resolving the issue requires new evidence/semantics/authority and must become a new prospective task.

Required output:
- decision-critical findings;
- required repair, if any;
- process lessons worth making durable;
- evidence/authority boundary;
- single highest-value next consumer.

Do not turn optional polish into a blocker. Do not turn a genuine new experiment into a “repair.”

This checklist creates no new numeric thresholds, Grade mapping, candidate bar, risk policy, HOLDOUT authority or deployment authority.
