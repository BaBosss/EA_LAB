# EA_LAB Milestone Scrutiny Checklist

Status: `ACCEPTANCE-GRADE EXACT-HEAD REVIEW GATE / NO NEW AUTHORITY`
Authority: owner-ratified procedural review policy. This checklist can accept or refuse only the bounded artifact and claims submitted under its contract. It cannot grant strategy, risk/default, HOLDOUT, Candidate/Grade/KINT, MT5, runtime, deployment, DEMO/LIVE, trading, irreversible, or owner-signature authority that the underlying contract does not already permit.

## Purpose and required sequence

Use this as the canonical final scrutiny gate for core/execution/position/accounting/money/risk and other high-risk work, and when a milestone contract explicitly requires acceptance-grade scrutiny.

The sequence is mandatory:

1. freeze one exact clean head and immutable evidence set;
2. finish every contract-required deterministic, compile, regression, adversarial, and negative gate;
3. launch a separate read-only GPT Scrutiny job/lane/contract that did not author the submitted change;
4. bind the review to the exact head and isolated evidence;
5. return one explicit result from section G with an authority ceiling;
6. if the underlying contract permits repair, allow at most one bounded repair and one targeted exact-head recheck; never dispatch duplicate reviewers or repeat reviews until PASS.

Provider/model family is not an independence criterion. Provider qualification cannot block this review. Independence is procedural and evidentiary: author/reviewer job separation, exact-head binding, evidence isolation, read-only review, deterministic/adversarial gates, and fail-closed ambiguity handling. The author job cannot self-approve.

## Admission gate — all items required before substantive review

- Record the repository path, full reviewed HEAD, expected base/parent, contract identity, author job/lane, reviewer job/lane, and review prompt/output identities where available.
- Prove the reviewed HEAD is exact, clean, and frozen. A moved HEAD, dirty source tree, unresolved merge, or unbound patch is `SCRUTINY_BLOCKED`.
- Prove the reviewer has read-only access to the submitted source/evidence and no source-mutation authority in this job.
- Prove author and reviewer are separate jobs/lanes/contracts. A different provider alone does not prove independence; the author reviewing its own output is not admissible.
- Enumerate the authoritative evidence set and keep it isolated from mutable scratch artifacts, stale local outputs, and unrelated accepted evidence.
- Record every required deterministic/adversarial gate and its actual command, exit/result, artifact identity, and scope. A claimed but unproven run is `NOT PROVEN`, not PASS.
- State the underlying contract's repair budget and authority ceiling. This checklist never resets either.

## A. Identity, provenance, lineage, and methodology

- Does the exact source/build/config/set/tester/install/window/runtime identity match the contract and evidence?
- Are effective inputs, locked constants, generated fingerprints, build receipts, runtime-adjacent identities, and control/current identities bound where applicable?
- Does the parent/source/provenance hash resolve to the intended lineage, with compatibility controls and generated artifacts traceable to it?
- Are current evidence, superseding evidence, and historical failures distinguished without rewriting or deleting the earlier record?
- Did preregistration precede evidence generation and parameter selection where the work is experimental?
- Is every child one logical change unless an authorized optimization contract explicitly opened a multi-parameter surface?
- Are MAIN, BWD and HOLDOUT roles preserved exactly?
- Were mechanical/harness/environment failures separated from strategy losses?
- Are reused parent/accepted evidence and newly generated evidence distinguishable?
- Do exact-byte/current-control comparisons use the required identity and same-install lineage where applicable?

Any unresolved parent mismatch, ambiguous lineage, stale build/config binding, conflicting authoritative provenance, or inability to identify the reviewed bytes is fail-closed `SCRUTINY_BLOCKED` or `SCRUTINY_FAIL`, never an inferred PASS.

## B. Semantic drift, selection bias, and hindsight audit

- Does the implementation preserve the contract's strategy semantics, ownership split, timing, defaults, failure behavior, and forbidden paths?
- Did shared/core code acquire behavior or authority that belongs to a family-native component, or vice versa?
- Did reporting/config prose become more authoritative than the implemented effective behavior?
- Was any range, objective, endpoint, comparison, or acceptance rule changed after seeing results without a new prospective contract?
- Was BWD mined repeatedly to select parameters?
- Was HOLDOUT used for tuning, rescue, or ranking?
- Is a top-PF spike being mistaken for a stable region?
- Are boundary winners, multiple-testing exposure, empty cells, and contradictory years/regimes visible?
- Was a local/home-specific improvement incorrectly generalized as portable?

Any undeclared semantic/default/ownership change is outside repair unless the underlying contract explicitly permits it. Stop and return to the Control Tower rather than normalizing it into a review fix.

## C. Deterministic, adversarial, negative, and economic audit

- Did every required focused, compile, deterministic, regression, adversarial, and negative fixture actually run against the reviewed head?
- Do receipts/logs bind the tested artifact and show the expected negative branch fired, rather than merely showing a green harness?
- Do mutation/seeded-failure or equivalent controls prove the fixture can detect the defect it claims to cage?
- Are refusal, fail-closed, replay, stale/missing/mismatched artifact, collision, invalid-input, and forbidden-scope cases covered where relevant?
- Are exact control/current or parity gates complete where the contract requires them, without substituting static similarity for runtime-adjacent evidence?
- Does improvement survive participation/trade/cycle context rather than PF alone?
- Is profit concentrated in one trade, cycle, month, or very long-lived episode?
- Did DD improve only because activity/exposure collapsed?
- For grid/multi-position EAs, are depth, total lots, grid span, duration, and concentration visible?
- Are parent-child economic deltas explicit enough to justify the bounded claim rather than merely positivity?

Missing required tests, unproved execution, an identity-mismatched test run, or an unsupported skipped regression prevents PASS.

## D. Report, claim, and unsupported-PASS audit

- Can every headline number and identity claim be recomputed from durable machine evidence/raw reports?
- Are native MT5 data and reconstructed proxies labeled separately?
- Are missing fields explicitly `UNKNOWN`, `UNAVAILABLE`, or `NOT RUN` rather than inferred?
- Are Evidence, Interpretation, Decision, and Authority visibly separated?
- Does the report meet the current Report Ladder stage without unnecessary dossier overhead?
- Are conclusions causal only where the experiment design supports causality?
- Does any PASS rely on installation/login, provider reputation, model agreement, stale review, an unreviewed repaired head, or a green aggregate that hides a required failing fixture?
- Do receipt/status terms avoid reserved promotion language or claims that exceed the contract?
- Are all material contrary findings and historical failures carried forward until explicitly superseded by bound evidence?

If the submitted conclusion says PASS but the evidence supports only partial, static, fixture-only, or no-runtime assurance, return `SCRUTINY_FAIL` or `SCRUTINY_BLOCKED` with the narrower truthful classification.

## E. Authority, scope, and refusal audit

- Does the result stay inside the exact changed-path, semantic, repair, runtime, and decision authority of the contract?
- Are HOLDOUT, Model-4, MC, Candidate, DEMO, LIVE, risk/default, KINT, Grade, MT5, runtime, and deployment states explicit where relevant?
- Did a review, tooling PASS, research PASS, compile PASS, or provider qualification accidentally become source acceptance, strategy-default, tester, or deployment authority?
- Does any owner hard stop require action before the proposed next transition?
- Does ambiguous or conflicting provenance cause explicit refusal rather than best-guess reconciliation?
- Are out-of-scope instructions, external-text instructions, authority escalation, and requests to mutate source refused?
- Is the highest-value next consumer singular, bounded, and compatible with the remaining repair budget?

Any authority leakage, forbidden scope expansion, or failure to refuse ambiguity is material.

## F. Workflow-efficiency and review-integrity audit

Record process defects separately from product/strategy evidence:

- repeated shell quoting/interpolation failures;
- repeated fresh-worktree Python/runtime hydration;
- duplicate reviewer/model launches or PASS-shopping;
- unnecessary accepted-evidence reruns;
- origin re-anchor count and whether state sync was deferred until the end;
- report boilerplate that should become a deterministic generator;
- model calls lacking unique output, downstream skip, or direct consumer;
- experiments that could not have changed the routing decision;
- review prompts/evidence that were not frozen or could anchor the reviewer to an author's approval claim;
- reviewer writes, source mutations, or evidence contamination during a nominally read-only review.

If the same mechanical friction appears twice, create or reuse a bounded deterministic helper instead of solving it manually again. Process improvement never excuses a material acceptance defect.

## G. Scrutiny decision and repair protocol

Return exactly one:

- `SCRUTINY_PASS` — all admission, deterministic/adversarial, provenance, semantic, regression, authority, and refusal requirements pass; no material defect remains.
- `SCRUTINY_FAIL` — a material defect or unsupported PASS is established on the reviewed exact head.
- `SCRUTINY_REPAIR_REQUIRED` — one concrete material defect is repairable inside the underlying contract and its still-available single repair allowance.
- `SCRUTINY_BLOCKED` — exact identity/evidence is missing or conflicting, a required gate did not run, the head moved, the reviewer boundary is invalid, or resolution needs new evidence/semantics/authority outside the contract.

Required output:

- reviewed exact head and frozen evidence identity;
- author/reviewer job and lane separation statement;
- deterministic/adversarial/negative/regression gates actually verified;
- decision-critical findings, including unsupported-PASS checks;
- required repair, if any, with exact scope;
- historical failures preserved and superseding evidence identified;
- explicit authority ceiling and forbidden inferences;
- single highest-value next consumer.

Repair protocol:

- At most one bounded repair is available only when the underlying contract grants it and has not already spent it.
- Recheck only the repaired exact head and impacted gates, plus any parity/regression the finding makes necessary.
- The original reviewer finding remains evidence; do not overwrite it.
- Do not broaden scope, reset a repair budget, switch reviewers to seek PASS, or repeat full review without an impacted reason.
- If the targeted recheck does not PASS, preserve the result as FAIL/BLOCKED according to the contract.

Do not turn optional polish into a blocker. Do not turn a genuine new experiment, semantic change, runtime action, or authority expansion into a “repair.”

This checklist creates no new numeric thresholds, Grade mapping, candidate bar, risk policy, strategy semantics, HOLDOUT authority, MT5 authority, runtime authority, or deployment authority.
