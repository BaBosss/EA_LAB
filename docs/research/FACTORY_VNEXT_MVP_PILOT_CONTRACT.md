# Factory vNext MVP Pilot Contract

> **STATUS: FROZEN IMPLEMENTATION CONTRACT — NON-CANONICAL SIDECAR.**
> This contract implements the design frozen in `docs/research/FACTORY_VNEXT_DESIGN_DRAFT.md` without replacing current Factory verdict, optimization, risk or deployment authority.

## 1. Objective

Build one deterministic offline Factory vNext sidecar pilot that proves Home/Window identity, telemetry provenance, adaptive range contracts, derived Grade/Confidence evidence and graph-first reporting on one existing EA without changing strategy semantics.

Direct consumer: next EA_LAB Control Tower milestone and later canonical Factory-policy migration.

## 2. Pilot target

Use the existing `(TRD)_SuperTrendFlip` family as the first pilot because accepted infrastructure/evidence already exists around it.

Pilot research identity:
- `ConceptID`: SuperTrendFlip family;
- `LogicalSymbol`: BTCUSD;
- `ExecutionTF`: H4;
- `HomeContractID`: deterministic ID for SuperTrendFlip/BTCUSD/H4;
- `Profile`: existing offline baseline/profile material only; do not invent new risk defaults;
- broker/physical symbol is recorded from the chosen offline Strategy Tester data source and mapped to logical BTCUSD.

This pilot is **offline Strategy Tester / artifact processing only**. It must not attach/rebind any running DEMO instance and must not deploy, trade, change LIVE state or alter current runtime identity.

## 3. MVP scope

Required sidecar capabilities:
1. HomeContract schema + validation;
2. WindowContract schema + validation;
3. immutable Run Manifest + parameter snapshot/hash;
4. Telemetry V1 schemas for signal, trade, context and optimization-pass evidence; basket/hedge schema may exist as conditional placeholders but need not be exercised by pilot #1;
5. deterministic derived metric layer sufficient for Overview, Trade Diagnostic and Optimization pages;
6. Range Generator V1 with semantic parameter metadata, staged sparse search, constraints, runtime estimate and loop breakers;
7. Grade/Confidence sidecar with explicit `NON-AUTHORITATIVE` boundary and critical-floor placeholders where numeric thresholds remain provisional;
8. graph-first HTML report with Home/Window identity visible on every page/section;
9. artifact manifest/hash references and evidence labels;
10. deterministic tests for identity mismatch, missing evidence, range safety, reproducibility and report provenance.

Not required in pilot #1:
- production runtime attachment;
- DEMO/LIVE deployment or rebind;
- risk/default changes;
- canonical verdict replacement;
- full recovery/hedge implementation validation;
- Bundle/Meta-EA or portfolio allocation;
- directional news trading or external options/rates feeds;
- mass migration/rerun of legacy EAs.

## 4. Authority boundary

Current pushed canonical Factory remains authoritative. vNext outputs are advisory sidecar evidence only until a separate owner-approved policy-migration milestone changes authority.

## 5. Deterministic implementation rules

- Every artifact traces to source commit, `HomeContractID`, `WindowContractID`, `ProfileID`, `ParameterSetID` and `RunID`.
- Home mismatch (`LogicalSymbol` or `ExecutionTF`) => `OUTSIDE_VALIDATED_CONTRACT`; do not inherit Grade/PASS.
- Different WindowContracts are not directly rank-comparable unless an explicit common-validation contract says so.
- Range Generator never guesses unknown semantics: unknown type => `SEMANTICS_REQUIRED`.
- No universal fixed ATR step. COARSE favors sparse coverage; REFINE/SENSITIVITY increase resolution only in accepted regions.
- Recovery hard ceilings are fail-closed and never auto-expanded.
- AI may explain deterministic evidence but cannot override raw telemetry, Grade inputs, verdict or deployment state.

## 6. Evidence/report acceptance

The pilot must prove deterministic reruns, Grade-to-evidence traceability, fail-visible missing fields, visible Home/Window identity, non-authoritative sidecar labeling, and report coverage for Overview, Trade Diagnostic and Optimization evidence.

Wrong Symbol/TF, missing identity, unsafe range expansion and ineligible cross-window comparison must fail visibly.

## 7. Test/review gate

Before integration: focused schema/identity/range/report tests, wrong-Symbol/TF negative tests, impacted Factory regression, `git diff --check`, strict repo state check, then one independent frozen-HEAD review.

A review HEAD move permits at most one bounded repair followed by targeted recheck. No broad redesign during implementation unless a real contract contradiction/defect is proven.

## 8. Hard stops / forbidden scope

Owner approval remains required for deployment/runtime attachment, LIVE/DEMO->LIVE, trading/real-money action, risk/default changes, consequential new strategy/risk semantics, owner attestation, force/history rewrite, or raising hard exposure/recovery ceilings.

The pilot may use local Strategy Tester/backtest/optimization only inside the accepted offline contract. No current DEMO process may be mutated.

## 9. Completion definition

MVP pilot is complete only when implementation + focused/negative/impacted tests + independent review pass on a frozen exact HEAD, sidecar outputs remain non-authoritative, and accepted artifacts are integrated/pushed normally without changing current Factory authority.

After this contract is canonical, the next Control Tower should implement from the exact pushed design SHA rather than reconstructing requirements from conversation history.
