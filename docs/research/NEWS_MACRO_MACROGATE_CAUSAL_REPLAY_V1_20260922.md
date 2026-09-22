# News / Macro — MacroGate Causal Research Replay V1 — 2026-09-22

Status: SOURCE-PREPARATION CANDIDATE / NO MT5 / NO PERFORMANCE / NO RUNTIME AUTHORITY

## 1. Purpose and scope

This milestone reuses the already-accepted Boss19 P4 causal macro classifier lineage to create a compact macro-only replay timeline for later MacroGate research. It does not redesign MRIS, activate MacroGate, modify NewsGuard, touch Monitor, run MT5, consume HOLDOUT, or make a strategy verdict.

Author lane: ct-news-macro-mg-replay-v1-20260922.

Allowed source is limited to:
- tools/news_macro_lab/macrogate_replay.py
- tools/news_macro_lab/tests/test_macrogate_replay.py
- this document

The direct consumer, after separate acceptance, is a separately frozen MacroGate native-parity / A-B contract using the existing _MG_SelfGate. No performance run is authorized by this document.

## 2. Why reuse the P4 timeline

The legacy scripts/mris/mris_backtest_timeline.ps1 remains blocked for new causal intraday claims because it can classify calendar day D with D's daily close while labeling the result at D 00:00.

The accepted Boss19 P4 classifier contract already solved that timing problem prospectively: each completed daily source date D becomes eligible only at D+1 00:00:00Z. Its macro semantics bind the same MRIS implementation/config hashes used by the current repository.
Frozen upstream identities used here:

| Artifact | SHA-256 |
|---|---|
| Boss19 P4 classifier timeline | 5f3a0f8d1accd25cb6cc08ad1c6e291aed6d238d620269102151016dbfaf569d |
| Boss19 P4 timeline manifest | 858f4d02d1ae30511dd1f38ffab347c85c06a4a25df4bedf901dc169c2847916 |
| Bound macro package manifest | 7268f3d71c33fd882823570fb35791b5fc956b27fa7829b7cb7ddfc2c803f01a |
| scripts/mris/mris_classify.ps1 | 84a20e03e5babebc95a116fa808d808316c2df3b55d0d9f82e28a44b693a0da0 |
| scripts/mris/barometers.json | 0ea8a658d625e1f1317ea8a2095a55befc84ba5a7bc07da08192f2cc30e49347 |

The current repository still matches both MRIS source/config hashes above. The upstream timeline manifest records h3_outcome_content_opened=false and holdout_included=false.

This milestone does not infer new historical prices from the Boss19 attribution results. It reads only the frozen classifier timeline and manifest, then verifies the macro dimension is identical across every source cell.

## 3. Extraction and causal checks

The extractor is network-free and fail-closed. Before output it requires:

1. exact timeline and manifest SHA-256 identity;
2. the expected macro-package manifest SHA-256;
3. exact classifier ID/version;
4. upstream h3_outcome_content_opened=false and holdout_included=false;
5. all expected Symbol×TF cells present in manifest order;
6. contiguous, positive intervals for each cell;
7. exact macro sequence equality across all cells;
8. MRIS state/confidence vocabulary;
9. macro_as_of_utc <= valid_from_utc;
10. for rows carrying a normal source date, exact macro_as_of_utc = source_date + 1 UTC calendar day at 00:00Z.

An UNKNOWN/stale interval may retain the prior source/as-of lineage but can never move availability earlier.
## 4. Actual source-bound extraction

Actual source path:

D:\EA_LAB_CONTROL\evidence\boss19_p4b_timeline_v1_finalA_0f2cc63d\classifier_timeline.csv

The durable extraction job completed with exit 0 and no stderr. It verified:

- source cells: 18 / 18
- source rows streamed: 1,242,682
- extracted macro intervals: 2,192
- interval range: 2020-01-01T00:00:00Z through 2026-01-01T00:00:00Z
- every extracted interval has macro_coverage = 8/8
- every extracted interval has macro_partial = false
- output probability remains null
- MRIS confidence is explicitly MRIS_AGREEMENT_NOT_CALIBRATED_PROBABILITY

Output identities:

| Artifact | SHA-256 |
|---|---|
| macrogate_causal_timeline.csv | 44ed3c16451bf9d8e9066d1f552939c62d3c0bfcb1c9059613ad4150d963ed5f |
| macrogate_causal_timeline_manifest.json | 436baeeb45d1aba7d5176473dbc462963e43d1b31937e3fcbdf16ad76771d3e1 |
| extraction profile | b1a193bba20d54da69df3fa6dad79e0ee75f326ec8600fdba894ed047c30de05 |

Durable evidence root:
D:\EA_LAB_CONTROL\evidence\news-macro-mg-replay-v1-20260922

The output state counts are descriptive source coverage only, not performance:
- NEUTRAL 1,448 daily intervals
- RISK_OFF 466
- STRESS 208
- RISK_ON 70

The counts sum to 2,192 calendar-day intervals. They do not imply that any state is good/bad for an EA.
## 5. What this does and does not qualify

If independent exact-head scrutiny accepts this milestone, it can qualify one bounded statement:

EA_LAB has a hash-bound, causal, daily MacroGate research-replay timeline for the frozen 2020-2025 MRIS/P4 lineage, derived without using EA outcomes and with D-close unavailable before D+1 00:00Z.

It still does not qualify:
- the legacy mris_backtest_timeline.ps1 as causal
- current/live MRIS or MacroGate runtime effectiveness
- a different classifier/config lineage
- Global Regime V2 or regional macro inputs
- NewsGuard historical schedule coverage
- MacroGate native Strategy Tester parity
- any EA A/B performance result
- any risk/default, Candidate/Grade/KINT, deployment, DEMO/LIVE or trading action

The extracted file is a research data artifact. can_execute=false, performance=NOT_RUN, holdout_used=false, and native_parity_qualified=false remain controlling.

## 6. Anti-bias boundary for the next consumer

The next MacroGate experiment must still freeze before outcomes:
- exact parent EA/source/EX5/set/Home
- MAIN and BWD windows and broker/tester identity
- exact native MacroGate policy and _MG_SelfGate parity
- placebo seeds/schedule
- primary metric and falsifier
- participation, exposure and tail reporting

BWD remains validation only and HOLDOUT remains unspent. No existing historical MacroGate result is relabeled by this timeline.

## 7. Acceptance

Required before canonical integration:
- deterministic unit/adversarial tests for the new extractor
- actual source-bound extraction against the frozen hashes above
- normal hooks/diff checks
- separate read-only exact-head GPT Scrutiny

Only source-preparation acceptance may follow. No automatic MT5 or runtime activation follows.
