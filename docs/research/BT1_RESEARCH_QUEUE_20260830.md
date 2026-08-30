# BT1 - Ranked Research Queue - 2026-08-30

Status: `RESEARCH_ONLY / EXECUTED / CLOSED`
Canonical base SHA: `b26af204faf7907fe7e78a2b5f90a5dfa8c6bc02`
HOLDOUT: `UNSPENT`
Optimization: `NONE`

## Inputs reused - no rediscovery

- accepted H02 literal-portability matrix and six dual-window PF>1 screening pulses;
- accepted B16 H03 `POSITION_ENGINE_DEPENDENT_OR_UNKNOWN` decomposition;
- canonical Second Brain mechanism/synthesis/negative-knowledge cards;
- exact current source semantics for B16 KangarooGrid and B13 MeanRev.

Second Brain is provenance only. Every item below remains `TESTABLE_HYPOTHESIS`; none is an accepted strategy, optimizer seed, Candidate, DEMO, LIVE, or risk/default decision.

## Ranking rule

Rank by information gain, direct consumer, semantic precision, ability to isolate one logical change, and reuse of accepted evidence. No HOLDOUT and no optimizer sweep. B16 items are mechanism/position-engine/recovery ablations only, consistent with H03.

## Rank 1 - HYP-B16-PE-ABL-01

**Mechanism:** test whether the B16 XAUUSD/H4 pulse contains an independently positive single-entry RSI-fade component when adverse grid adds are removed.

- EA/family: `B16 / Boss_16_KangarooGrid`
- Symbol/TF: `XAUUSD / H4`
- One logical change: `_16_MaxOrdersPerSide: 10 -> 1`
- Everything else: exact B16-H01-r1/H02 configuration unchanged.
- Execution model when dispatched: Model 1 first, on the same Meta5b lineage as the accepted H02 pair; MAIN and BWD remain on one install.

**Supporting evidence:** H03 reconstructed 42 MAIN and 70 BWD flat-to-flat cycles and found multi-entry cycles contributed 79.80% MAIN and 87.89% BWD gross profit. Source shows the first entry is RSI-fade while grid adds are a separate adverse-move path and do not re-consult RSI.

**Contradicting evidence:** the same H03 result suggests the pulse may collapse without multi-entry behavior; this makes the ablation high-information rather than a likely winner.

**Why new:** H03 decomposed accepted baseline outcomes but did not run an entry-only counterfactual.

**Expected regime:** the same revertive/oscillatory envelope assumed by the parent. No new regime filter is introduced.

**Falsification:** the hypothesis that the entry-only component remains positive in both windows is falsified if full-window net profit is non-positive in either MAIN or BWD, provided mechanical acceptance passes.

**Known consequence:** with maximum depth 1, the existing source reaches its single-position exit path rather than multi-position basket/overlap exits. That is a structural consequence of disabling adds, not an additional parameter change, and must be reported explicitly.

**Test plan:** MAIN `2023.01.01..2025.12.31` + BWD `2020.01.01..2022.12.31`; deposit 10000 USD; leverage 1:100; Model 1; optimization 0; HOLDOUT no; compare net, PF, EqDD, trades/cycles, yearly participation and direction with accepted baseline.

**Direct consumer:** decide whether future B16 research should investigate entry semantics at all or remain focused on the position engine/recovery path.

**Authority ceiling:** research-only; no H04 naming/unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, or risk/default authority.

## Rank 2 - HYP-B16-REC-ABL-01

**Mechanism:** isolate whether B16's overlap pair-close recovery behavior contributes to the accepted XAUUSD/H4 pulse after positions have accumulated.

- EA/family: `B16 / Boss_16_KangarooGrid`
- Symbol/TF: `XAUUSD / H4`
- One logical change: `_16_OverlapMinUsd: 5.0 -> 0.0`, which disables the source-gated overlap pair-close path while leaving entry, add spacing, max depth, flat lot and basket TP parameters unchanged.

**Supporting evidence:** H03 establishes that B16 profitability is position-engine dependent/unknown, while source inspection shows overlap pair-close is a distinct recovery-management branch activated only when `_16_OverlapMinUsd > 0` and position count reaches the overlap minimum.

**Contradicting evidence:** H03 did not quantify how much profit or drawdown came specifically from overlap closes versus ordinary basket TP/add behavior; contribution is currently unknown.

**Why new:** this is a prospective recovery-behavior ablation, not a rerun of H03 and not an optimizer sweep.

**Expected regime:** adverse excursions followed by sufficient reversion for accumulated positions to interact with the overlap-close path.

**Falsification:** the hypothesis that overlap pair-close is beneficial is falsified if the disabled variant has non-lower net profit and non-higher EqDD% than baseline in both MAIN and BWD, with mechanical acceptance passing.

**Test plan:** same fixed B16 XAUUSD/H4 MAIN+BWD identity as Rank 1 except the single preregistered overlap change; Model 1; 10000 USD; 1:100; optimization 0; HOLDOUT no. Reconstruct cycles and count/attribute overlap-close events if source-supported.

**Direct consumer:** determine whether a later B16 recovery study should preserve, redesign, or deprioritize the overlap-close mechanism.

**Authority ceiling:** research-only; no recovery default change, H04 unlock, optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, or risk authority.

## Rank 3 - HYP-B13-BB-ABL-01

**Mechanism:** test whether the Bollinger outer-band gate is actually contributing useful selectivity to the B13 XAUUSD/M15 mean-reversion pulse, versus RSI-extreme alone.

- EA/family: `B13 / Boss_13_MeanRev`
- Symbol/TF: `XAUUSD / M15`
- One logical change: `_13_RequireBB: true -> false`
- Source semantics: `Entry_MeanReversion.mqh` explicitly defines `RequireBB=false` as RSI-only; all RSI thresholds, exits, sizing, stack/risk settings and execution assumptions remain frozen.

**Supporting evidence:** accepted H02 shows XAUUSD/M15 PF 1.06 MAIN and 1.02 BWD with 3929/3300 trades; Second Brain says mean-reversion variants require exact reference semantics and recommends component ablation rather than indicator accumulation.

**Contradicting evidence:** the B13 pulse is weak at the aggregate PF level and B13 did not show broad literal portability; removing the BB gate may simply increase low-quality participation.

**Why new:** H02 only tested the frozen BB+RSI parent. It did not isolate the BB condition.

**Expected regime:** range/reversion behavior where temporary excursions beyond a statistical band and RSI extremes are more informative than persistent structural trend.

**Falsification:** the hypothesis that the BB gate is necessary for useful selectivity is falsified if the RSI-only variant has non-lower net profit and non-higher EqDD% than the accepted parent in both MAIN and BWD, with mechanical acceptance passing.

**Test plan:** XAUUSD/M15 MAIN+BWD using exact `B13-H01-r1` set identity except `RequireBB=false`; Model 1; 10000 USD; 1:100; optimization 0; HOLDOUT no. Compare net, PF, EqDD, participation/year structure and direction with the parent.

**Direct consumer:** decide whether B13's next research should retain the two-factor BB+RSI entry thesis or whether BB is redundant before any parameter-range work is considered.

**Authority ceiling:** research-only; no optimization, HOLDOUT, Candidate, DEMO/LIVE, deployment, or risk/default authority.

## Waiting / not promoted into READY queue

- Second Brain `HYP-SB-001` adaptive volatility-aware bounded grid remains source-traceable research provenance, but its published seed bundles multiple candidate changes (zone, spacing, sizing/exposure). A one-change parent and exact semantics must be selected prospectively before it can become an EA_LAB experiment. Current status: `SEMANTICS_REQUIRED`.
- Boss19 next strategy hypothesis remains blocked behind canonical P4 interpretation/data prerequisites; do not bypass P4 with a new optimizer or HOLDOUT spend.
- B16 H04 remains locked. None of the B16 ablations above is named H04.

## Dispatch order

BT0 runtime-policy conflict is independent of this queue's research synthesis. When a tester experiment is separately dispatched, preserve one acceptance-critical lineage per install and preregister exact override bytes before launch. Run Rank 1 before Rank 2 so the highest-information entry-vs-position-engine question is answered first. Rank 3 is independent and may use a separate legal Model-1 runtime if Lane Registry ownership is clear.

## Execution closeout — post-result, 2026-08-30

The three preregistered BT1 hypotheses above were executed exactly once per authorized MAIN/BWD cell under their prospective contracts. This closeout does not alter the preregistered questions or falsification rules.

- `HYP-B16-PE-ABL-01`: `PASS / HYPOTHESIS_FALSIFIED`; `_16_MaxOrdersPerSide 10 -> 1`; MAIN PF 2.41 / net +149.08 / EqDD 1.18%; BWD PF 0.90 / net -32.09 / EqDD 2.42%; `MECHANISM_VALUE=WEAK`. Evidence: `docs/research/BT1_B16_PE_ABL_01_RESULTS.md`.
- `HYP-B16-REC-ABL-01`: `PASS / HYPOTHESIS_NOT_FALSIFIED`; `_16_OverlapMinUsd 5.0 -> 0.0`; MAIN PF 0.51 / net -924.01 / EqDD 22.28%; BWD PF 1.94 / net +890.51 / EqDD 7.70%; `MECHANISM_VALUE=UNCLEAR` because the material effect reverses sign across windows. Evidence: `docs/research/BT1_B16_REC_ABL_01_RESULTS.md`.
- `HYP-B13-BB-ABL-01`: `PASS / HYPOTHESIS_NOT_FALSIFIED`; `_13_RequireBB true -> false`; MAIN PF 1.06 / net +1056.60 / EqDD 6.27%; BWD PF 1.03 / net +296.67 / EqDD 3.53%; `MECHANISM_VALUE=UNCLEAR`. Evidence: `docs/research/BT1_B13_BB_ABL_01_RESULTS.md`.

All parent/child comparisons stayed within one MT5 install per lineage, Model 1, optimization 0, and HOLDOUT unspent. No result unlocks H04, optimization, Candidate, DEMO/LIVE, deployment, trading, risk/default, KINT, or Grade authority. No further B16/B13 experiment is auto-opened from this queue.
