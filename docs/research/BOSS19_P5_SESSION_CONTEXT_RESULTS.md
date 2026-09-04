# Boss19 P5 Session-Context Attribution Results

Status: **COMPLETE / RESEARCH_ONLY / `P5_SESSION_CONTEXT_FALSIFIED_STOP_EXPANSION_PARK`**

## Scope and authority

This result closes the preregistered `HYP-SB-005` Black Tide session-context attribution branch for frozen Boss19 evidence. It attributes already accepted realized units by entry-session context only; it does not modify the strategy, select a trading session, or create a session filter.

HOLDOUT remains **UNSPENT**. Optimization remains **NONE**. This result grants no Candidate, Grade, KINT, risk/default, runtime, deployment, or trading authority.

## Exact admissible evidence identity

- Semantics/integration head reviewed: `a30ca052ca7aa503e00992a18693a7e6e9a792c6`.
- Independent semantics review: Claude/Anthropic `PASS / HIGH`, `ATTRIBUTION_EXECUTION_AUTHORIZED: YES`.
- Review output SHA-256: `cc6af19243ca653cad3ce0573141fbf4b75ad996770f236825ea61d85cf6560a`.
- Review receipt SHA-256: `1a5a1adb002af841c04227bc27b0c0c12a5cca61a22f54e0b128aed1e6b72429`.
- Accepted input SHA-256: `e54f1cfaf58df97acb8fb39c1e6e8bf4614f1ff3a7c9bcbc1b5acff762665dd6`.
- Input: 1,549 source-bound realized units; net reconciliation `+17,718.78`.
- Admissible package SHA-256: `7d87dcfcca7c9968c5aacd5ffe3d46d64457731587e2ed249a472e86c311d332`.
- Two deterministic builds were byte-identical for all five acceptance outputs.
- Any exploratory execution that occurred before the matching exact-head independent review remains `INADMISSIBLE_PRE_REVIEW_EXECUTION` and was not reused.

## Reconciliation

`reconciliation.json` reports `PASS_ATTRIBUTION_RECONCILIATION`: 1,549 input units, 1,549 unique DEAL keys, 1,549 assigned units, zero unknown session states, zero HOLDOUT rows, and exact net reconciliation to `17,718.78`.

## Evidence

| Session state | MAIN units | MAIN net | MAIN PF | BWD units | BWD net | BWD PF | Preregistered robustness outcome |
|---|---:|---:|---:|---:|---:|---:|---|
| ASIA | 241 | +5,748.65 | 4.452580 | 134 | +899.73 | 1.721556 | FAIL — BWD year LOO |
| LONDON | 162 | +2,454.02 | 3.275739 | 170 | +1,617.26 | 2.450457 | FAIL — BWD year LOO |
| LONDON_NY_OVERLAP | 221 | +4,146.82 | 3.938860 | 208 | -3,461.82 | 0.418561 | FAIL — cross-window direction differs and LOO instability |
| NEW_YORK_ONLY | 169 | +4,012.34 | 5.961162 | 82 | -807.47 | 0.554659 | FAIL — cross-window direction differs and LOO instability |
| OUTSIDE_DEFINED_SESSION | 89 | +2,457.84 | 4.210219 | 73 | +651.41 | 2.994519 | CONTROL ONLY — never candidate |

The session assignment counts are ASIA 375, LONDON 332, LONDON_NY_OVERLAP 429, NEW_YORK_ONLY 251, and OUTSIDE_DEFINED_SESSION 162.

The preregistered leave-one-out falsifier is decisive for the two named sessions that are positive in both windows. ASIA BWD becomes `-66.22` when 2022 is excluded. LONDON BWD becomes `-228.35` when 2020 is excluded. Therefore neither survives the fixed YEAR robustness cut.

The remaining named sessions are not directionally stable across MAIN and BWD. LONDON_NY_OVERLAP is `+4,146.82` MAIN versus `-3,461.82` BWD; removing BWD-2022 leaves `+30.62`, showing additional year sensitivity. NEW_YORK_ONLY is `+4,012.34` MAIN versus `-807.47` BWD; removing BWD-2022 leaves `+52.93`, and excluding XAUUSD leaves BWD `+539.66`.

## Interpretation

Session context contains descriptive differences in the accepted Boss19 history, but no named session satisfies the prospectively frozen robustness requirements. The attractive aggregate numbers in ASIA and LONDON cannot be promoted because their BWD sign depends on a single historical year. The overlap and New-York-only states reverse direction between MAIN and BWD and also show concentration sensitivity.

`OUTSIDE_DEFINED_SESSION` remains a participation/control category by contract. Its positive aggregate values cannot create a candidate.

## Decision

`P5_SESSION_CONTEXT_FALSIFIED_STOP_EXPANSION_PARK`

No named session candidate survives the preregistered falsifier. Do not implement a London-only, Asia-only, overlap, New-York-only, or outside-session strategy rule from this evidence. Do not rescue the branch by changing UTC hours, DST treatment, overlap precedence, boundaries, exclusions, or by selecting the highest historical PF.

This session branch is closed at this scope. BOS/CHoCH, order blocks, FVG, VWAP, opening balance, or other Black Tide layers are not automatically unlocked by this negative result. Any continuation requires a genuinely new, independently motivated prospective one-change hypothesis with a direct consumer and a new preregistration.

## Durable evidence

Machine-readable evidence is under `factory/runs/boss19_p5_session_20260903/`:

- `package.json`
- `reconciliation.json`
- `session_attribution_detail.csv`
- `session_affinity.csv`
- `session_leave_one_out.csv`
- `semantics_review_claude.txt`
- `semantics_review_receipt.json`
- `execution_provenance.json`

Negative evidence is retained deliberately so future workers do not repeat the same session-selection experiment or reinterpret aggregate PF as promotion authority.
