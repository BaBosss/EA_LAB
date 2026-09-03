# Boss19 P5 — Black Tide Session Context Attribution Contract

Status: `OWNER-AUTHORIZED / PROSPECTIVE / RESEARCH_ONLY / NO STRATEGY CHANGE`

Canonical preregistration base: `f08ee2c4de615b01c95f599068d3b74c94fe6fad`
Hypothesis: `HYP-SB-005`
Family / parent: `Boss19 / 19-0 AdaptiveTrendGrid V0`
Direct consumer: Boss19 P5 gate after `NO_P5_READY_LEVER_FROM_CURRENT_P4_LABELS`.

Owner authorization: on 2026-09-03, after the Control Tower stated that the next action was the Boss19 P5 session-semantics/preregistration followed by deterministic attribution, the owner explicitly instructed it to continue. This authorization is bounded to this research-only one-change session-context attribution; it does not authorize strategy mutation, optimization, HOLDOUT, risk/default, runtime attachment, deployment, or trading.

## 1. One logical change

Add one deterministic **entry-session context label** to the already accepted Boss19 source-bound P4 DEAL evidence. Freeze every strategy mechanic, entry, exit, position engine, sizing, protection, risk, and existing P4 classifier label. No MT5 rerun is required or authorized.

The source motivation is independent of the mined P4 adverse episodes: the current Black Tide Map publication exposes Asia, London, New York, and a dedicated London/New York overlap as market-context geometry. The source does not claim any session is superior.

`bars:` N-A for strategy performance. Mechanical PASS requires exact input identity, exact 1,549-unit reconciliation, zero duplicate/unassigned units, zero HOLDOUT rows, deterministic output, and exact P&L reconciliation. Context candidacy uses only the preregistered sign/leave-one-group-out rule below.
`flat-lot probe:` N-A — strategy mechanics and sizing are unchanged.
## 2. Frozen evidence identity

Primary accepted input:
- `_mt5_auto/p4b_boss19_regime/regime_attribution_detail.csv`
- SHA-256: `e54f1cfaf58df97acb8fb39c1e6e8bf4614f1ff3a7c9bcbc1b5acff762665dd6`
- accepted population: 1,549 DEAL units; 1,549 classified; 0 unknown;
- accepted total realized net: `+17718.78`;
- accepted entry timestamp field: `entry_utc`;
- broad source-bound unit aggregate SHA-256: `325b6d00709c48982a5981d2d7750a6a18e99f2d77ad52b89fa8d67b50c0b699`.

`entry_utc` is reused exactly. It was normalized prospectively from ThinkMarkets server timestamps by the accepted P4B rule: GMT+2 standard / GMT+3 during US DST, with transition server dates quarantined rather than guessed. This P5 experiment does not reinterpret server timestamps or create another timezone conversion.

HOLDOUT boundary remains `2026H1 UNSPENT`; every eligible input entry must remain within 2020-2025.
Optimization remains `NONE`.

## 3. Black Tide source semantics pin

Public source: `https://www.tradingview.com/script/5L9vbNRJ-Black-Tide-Map/`, retrieved 2026-09-03.
Transient public-page capture SHA-256: `c85efca3dc3645c03d0f9f6ab2163ce2bc37104711eee789a9857a20e7191f06`.

The current published input metadata exposes these defaults:
- Session timezone = `UTC`;
- Asia = `0000-0800`;
- London = `0700-1600`;
- New York = `1200-2100`.

The publication also states that Session Clock reuses the Session Key Levels hours/timezone and gives London/New York overlap its own segment. These are source design claims, not performance evidence.
## 4. Exclusive analysis segments

Source windows overlap from 07:00-08:00 (Asia/London) and 12:00-16:00 (London/New York). The P5 analysis must assign every accepted entry exactly once, so the following **EA_LAB_INFERENCE / preregistered tie-break** is frozen before results are read:

1. `ASIA` = `[00:00,07:00)` UTC;
2. `LONDON` = `[07:00,12:00)` UTC;
3. `LONDON_NY_OVERLAP` = `[12:00,16:00)` UTC;
4. `NEW_YORK_ONLY` = `[16:00,21:00)` UTC;
5. `OUTSIDE_DEFINED_SESSION` = `[21:00,24:00)` UTC.

Rationale: segments follow the later session opening as the active label, while preserving the source's explicit London/New York overlap as its own state. This is not claimed as Black Tide source semantics for the Asia/London overlap; it is the deterministic EA_LAB partition needed to avoid double counting.

All intervals are half-open. Exact 07:00, 12:00, 16:00, and 21:00 entries belong to the segment beginning at that instant. `entry_utc` only is used; exit time cannot change the label. Because the source default session timezone is UTC, there is no additional London/New York DST adjustment in this experiment.

## 5. Frozen outputs and metrics

Emit machine-readable:
- `session_attribution_detail.csv` — one row per accepted DEAL with exactly one session label;
- `session_affinity.csv` — ALL, WINDOW, YEAR, and SYMBOL_TF aggregate views;
- `session_leave_one_out.csv` — preregistered year, entry-month, and Symbol×TF leave-one-out checks per window/session;
- `reconciliation.json` — exact identity/count/P&L/HOLDOUT checks;
- `package.json` — input/output hashes, decision fields, and authority boundary.

For every aggregate report: eligible units, participation share, gross profit, gross loss, net realized, PF (`NULL` when gross loss is zero), winning/losing units, and partition realized-equity DD ordered by `exit_utc` then `source_deal_id`. No original whole-run DD is reconstructed from partition data.
## 6. Preregistered candidacy and falsifier

For each named session segment (`ASIA`, `LONDON`, `LONDON_NY_OVERLAP`, `NEW_YORK_ONLY`), determine a direction only from aggregate realized net:
- `POSITIVE` only when MAIN net > 0 and BWD net > 0;
- `NEGATIVE` only when MAIN net < 0 and BWD net < 0;
- otherwise `MIXED_OR_ZERO`.

A named segment becomes a **research context candidate** only when its direction is non-mixed and, separately within MAIN and BWD, all three checks hold:
1. leave each participating UTC calendar year out in turn -> remaining units > 0 and remaining net keeps the same direction;
2. leave each participating UTC entry month (`YYYY-MM`) out in turn -> remaining units > 0 and remaining net keeps the same direction;
3. leave each participating `Symbol x TF` home out in turn -> remaining units > 0 and remaining net keeps the same direction.

This operationalizes the predeclared one-year / one-episode / one-home concentration falsifier without inventing a universal sample-size or PF threshold. Exact participation counts/shares remain visible; `KINT-001` is not resolved here.

`OUTSIDE_DEFINED_SESSION` is a control partition and cannot be auto-selected as a P5 session candidate.

Decision tree:
- zero named candidates -> `P5_SESSION_CONTEXT_FALSIFIED / STOP_EXPANSION_PARK`;
- exactly one named candidate -> `P5_SESSION_CONTEXT_CANDIDATE_FOUND_SINGLE`; this authorizes only a future separately preregistered one-change strategy hypothesis, not implementation;
- multiple named candidates -> `P5_SESSION_CONTEXT_INFORMATION_FOUND_MULTIPLE / NO_PERFORMANCE_SELECTION`; do not choose highest PF/net after seeing results.

Any identity, duplicate assignment, missing assignment, HOLDOUT crossing, or P&L reconciliation failure -> `BLOCKED(ATTRIBUTION_RECONCILIATION_FAIL)` and no strategy interpretation.

## 7. Forbidden actions / authority ceiling

No MT5 run; no parameter/range search; no BWD retuning; no HOLDOUT; no BOS/CHoCH, OB, FVG, VWAP, opening-balance, TPO, K2, or other Black Tide layer may be added to rescue the result. No strategy filter is implemented by this contract. No Candidate/Grade/KINT, risk/default, runtime attachment, deployment, DEMO/LIVE, or trading authority is created.

Acceptance: deterministic fixtures PASS, exact real-input reconciliation PASS, outputs reproduce byte-identically for fixed creation identity, research result is independently reviewed on one frozen exact HEAD, canonical is reconciled, then normal fast-forward push may proceed.
