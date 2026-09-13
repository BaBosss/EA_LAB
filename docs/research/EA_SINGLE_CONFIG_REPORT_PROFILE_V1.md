# EA_LAB Single-Config Report Profile V1

Status: `CANONICAL REPORT PROFILE / SINGLE FROZEN CONFIG / NO NEW AUTHORITY`
Authority: presentation/reporting profile only. `EA_REPORT_SCHEMA.md`, `EA_REPORT_LADDER.md`, the exact experiment contract, and accepted evidence remain authoritative.

## Purpose

Use this profile when the report answers a question about **one frozen configuration**: fixed-config MAIN/BWD, execution-fidelity, robustness diagnostics, one-change comparison after selection, or an owner-facing dossier for a single accepted reference.

Do **not** use this as the optimization search report. Optimization has its own profile in `EA_OPTIMIZATION_REPORT_PROFILE_V1.md`.

## Required reading order

The report should be understandable in two passes:

1. **Owner scan:** front / executive summary / strategy card / decision.
2. **Evidence audit:** identity / workflow / parameters / performance / robustness / traceability.

Recommended section order:

`Front -> Executive Summary -> Strategy Card -> Requested/Effective -> Hypothesis -> D1 Workflow -> D2-C Risk Engine (if applicable) -> Key/Full Parameters -> MAIN/BWD Evidence -> Morphology/DD -> Robustness Diagnostics -> Evidence/Interpretation/Decision -> Known Unknowns -> Traceability -> Appendices`.
## Front / executive summary

The first page must not be a dense parameter dump. It should expose:
- exact EA / family / symbol / TF / direction / hypothesis revision;
- three status layers: execution, research conclusion, package/review;
- four to six key metrics or findings;
- one bounded owner decision / next action;
- explicit authority ceiling.

Use a native document layout or dimension-safe graphic. Never stretch a screenshot or dashboard card outside the target page aspect ratio.

The executive summary should fit on one page where practical and answer:
- What was tested?
- What passed/failed?
- What is the curve/risk shape?
- What is the most important caveat?
- What is authorized next?

## Strategy / mechanism card

Include plain-language mechanics before evidence tables:
- market/context assumption;
- entry logic and side asymmetry;
- indicators / timeframes;
- add/grid/recovery mechanism;
- lot/exposure law;
- exit ownership and priority;
- safety / halt / hard-kill behavior;
- expected operating envelope and known structural failure modes.
## Visual evidence rules

For each visual, state whether it is:
- `NATIVE_ACCEPTED_EVIDENCE`;
- `RECONSTRUCTED_ACCEPTED_EVIDENCE`;
- `DERIVED_DIAGNOSTIC`;
- `CURRENT_REPLAY_VISUAL_ONLY`;
- `MISSING / UNAVAILABLE`.

Never relabel a current replay graph as accepted evidence merely because set/EX5 identity matches. If historical tester data/economics have drifted, quarantine the replay as `VISUAL_ONLY / NOT_ACCEPTANCE_EQUIVALENT` and show the metric mismatch.

If native accepted equity time-series is unavailable, report native accepted EqDD summary fields when source-bound, then use realized balance/DD reconstruction only with an explicit label. Do not fabricate an equity curve.

Wide workflow diagrams, heatmaps, or multi-column evidence tables may use landscape pages. Normal narrative pages should remain portrait. A visual must be readable at normal A4/Letter zoom without requiring horizontal scrolling.

## Multi-position / grid minimums

In addition to the canonical Report Schema, surface these near the performance evidence:
- `L1...Ln` lot ladder;
- max concurrent positions / realized depth;
- max aggregate lots;
- max observed grid span in native units and normalized units where source-bound;
- basket/episode count;
- concentration / multi-entry contribution when available;
- drawdown episode count and underwater duration when deterministically reconstructable.

A smooth-looking balance line is not sufficient evidence for a grid/multi-position EA; floating-equity risk remains separately visible or explicitly unavailable.
## Decision / traceability

Keep `Evidence -> Interpretation -> Decision` visibly separated. The decision must answer the preregistered direct consumer and may not silently open optimization, HOLDOUT, Candidate, runtime or risk changes.

Known unknowns belong in the main report, not hidden in an appendix. Use the canonical explicit states `UNKNOWN`, `UNAVAILABLE`, or `NOT RUN`.

The final package should identify:
- canonical project/ref state used for authoring;
- exact accepted experiment/result refs;
- source report hashes or package manifest;
- derived visual source JSON/CSV;
- report generation/version identity;
- external educational references separately from EA_LAB evidence.

## Reuse rule

The report binary (`DOCX`/`PDF`) is an output, not the reusable source of truth. Future reports should reuse this profile plus deterministic evidence/visual generators. If a visual or section becomes common across two or more EAs, prefer a reusable reporting helper rather than copying hand-authored layout logic.

Before calling a Single-Config report final, run `EA_REPORT_VISUAL_QA_CHECKLIST_V1.md`.