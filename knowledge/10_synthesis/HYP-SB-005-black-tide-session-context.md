---
object_type: TESTABLE_HYPOTHESIS_CANDIDATE
hypothesis_id: HYP-SB-005
status: FALSIFIED_STOP_EXPANSION_PARK
authority: RESEARCH_ONLY
source_bundle: SRC-BLACK-TIDE-MAP-20260903
canonical_base_sha: 1266795fc49ac88a18c6b93b0fab478718102648
---

# Black Tide transfer — session context for Boss19 P5 gate

## R0 identity

- Family: `SECOND_BRAIN_SESSION_CONTEXT`
- Variant: `HYP-SB-005`
- Parent research card: `knowledge/02_research_cards/RC-2026-BLACK-TIDE-MAP-001.md`
- Current state: `COMPLETE / FALSIFIED / STOP_EXPANSION_PARK`
- One logical change: add deterministic **entry-session context attribution** to frozen Boss19 outcome evidence; do not change entries, exits, sizing, risk, or classifier labels.
- Direct consumer: Boss19 P5 gate after `NO_P5_READY_LEVER_FROM_CURRENT_P4_LABELS`.
- HOLDOUT: `UNSPENT / NOT AUTHORIZED HERE`
- Optimization: `NONE / NOT AUTHORIZED HERE`
- Trading signal: `NONE`

## Why this is admissible after P4 STOP_EXPANSION

The accepted P4 diagnostic parked expansion because the existing P4 labels did not yield a stable prospective lever. That report explicitly allows a future independently motivated one-change mechanism that is not mined from the same adverse episodes.

Black Tide Map supplies that independent motivation by treating Asia, London, New York, and London/New York overlap as explicit market-context geometry. The source does **not** claim that any one session is superior, so EA_LAB must not preselect London or any other session as the answer.

## Frozen hypothesis

Once exact session/timezone semantics are prospectively fixed, Boss19 realized outcomes may contain repeatable information by entry-session state that is not explained by the existing P4 classifier labels alone.

This is a **context-attribution hypothesis**, not a session filter and not a strategy change.
## Semantics resolution â€” 2026-09-03

The semantics contract and deterministic classifier are frozen pending independent different-family exact-head review. The Black Tide public metadata pins `UTC`, Asia `0000-0800`, London `0700-1600`, and New York `1200-2100`; the contract prospectively freezes a mutually exclusive later-open-wins partition with dedicated London/New York overlap and fixed UTC source windows across civil DST. Accepted Boss19 `entry_utc` is reused exactly, so no new broker-time inference is introduced.

## Semantics required before any experiment

Freeze all of the following before reading the session result:

1. exact source-bound Boss19 unit package and immutable receipt;
2. exact timestamp field used for session assignment;
3. timezone basis of that timestamp;
4. Asia, London, New York open/close definitions;
5. daylight-saving treatment for London and New York;
6. explicit overlap category precedence;
7. treatment of entries outside named sessions;
8. treatment of session boundaries and exact-open/exact-close timestamps;
9. one deterministic classifier implementation and fixture tests;
10. fixed outcome metrics and aggregation views;
11. fixed MAIN/BWD/year/symbol-TF reporting cuts used only for robustness interpretation, not adaptive retuning;
12. participation reporting so a good sign with collapsed activity is not silently promoted;
13. anti-lookahead rule: session assignment uses entry time only;
14. falsifier and stop rule;
15. statement that no HOLDOUT, optimization, parameter search, or strategy modification is permitted in the attribution pass.

Unknown timezone/DST semantics -> `SEMANTICS_REQUIRED / BLOCKED`; do not guess.

## Preregistered analysis order

1. Session attribution only: Asia / London / London-New York overlap / New York-only / outside-defined-session.
2. Reconcile all accepted units exactly once; unknown or double-assigned units fail closed.
3. Compare sign, participation, and concentration across the already accepted chronological windows and Symbol×TF homes.
4. Check whether an apparent session effect is merely one-year, one-symbol, or one-episode concentration.
5. Stop after the session decision. Do **not** add BOS/CHoCH, OB, FVG, VWAP, opening balance, or other Black Tide layers to rescue an ambiguous result.

A later structure/location hypothesis may be opened only as a new prospective one-change candidate after this session branch closes.

## Falsifier

Fail / park `HYP-SB-005` if, after exact semantics and deterministic reconciliation:

- no session state provides directionally stable information across the preregistered robustness cuts; or
- the apparent effect is materially concentrated in one historical year, symbol, Symbol×TF home, or adverse episode; or
- participation collapses such that the apparent improvement is not an informative transfer; or
- timezone/session identity cannot be established from source-bound timestamps without guessing.

No universal numeric threshold is introduced here.
## Evidence basis

Supporting motivation: `RC-2026-BLACK-TIDE-MAP-001` records Black Tide Map's published use of Asia/London/New York session context and explicit London/New York overlap as reference geometry.

Current EA_LAB boundary: `docs/research/BOSS19_P4_2022_CONFOUND_DIAGNOSTIC_20260903.md` found no stable P5 lever from the existing P4 classifier labels and closed that branch with `STOP_EXPANSION / PARK`, while allowing genuinely new independently motivated mechanisms.

The Black Tide publication supplies mechanism motivation only. It supplies no Boss19 performance evidence and no preferred session.

## Admissible result — 2026-09-04

The exact-head semantics gate at `a30ca052ca7aa503e00992a18693a7e6e9a792c6` received independent Claude/Anthropic `PASS / HIGH` with `ATTRIBUTION_EXECUTION_AUTHORIZED: YES`. The first admissible attribution then reconciled all 1,549 accepted source-bound units with zero unknown session states, zero HOLDOUT rows, and exact net `+17,718.78`; two deterministic builds were byte-identical.

No named session survived the preregistered robustness falsifier. ASIA and LONDON were positive in MAIN and BWD aggregates, but each failed the BWD YEAR leave-one-out check: excluding 2022 makes ASIA BWD `-66.22`, while excluding 2020 makes LONDON BWD `-228.35`. LONDON_NY_OVERLAP and NEW_YORK_ONLY reverse direction between MAIN and BWD and also show leave-one-out instability. `OUTSIDE_DEFINED_SESSION` remains control-only and cannot become a candidate.

Evidence owner: `docs/research/BOSS19_P5_SESSION_CONTEXT_RESULTS.md` and `factory/runs/boss19_p5_session_20260903/`. Any earlier pre-review execution remains quarantined and was not reused.

## Decision

`P5_SESSION_CONTEXT_FALSIFIED_STOP_EXPANSION_PARK`

Do not implement a session filter from this branch and do not rescue it by changing session hours, DST semantics, overlap precedence, exclusions, or by adding another Black Tide layer. A future continuation requires a genuinely new independently motivated prospective one-change hypothesis with a direct consumer and new preregistration.

HOLDOUT remains `UNSPENT`; optimization remains `NONE`.

## Authority boundary

This file creates no strategy filter, no London-only/NY-only rule, no MT5 run, no optimizer authority, no HOLDOUT access, no Candidate/Grade/KINT change, no risk/default change, no runtime attachment, no deployment action, and no trading authority.
