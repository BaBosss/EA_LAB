---
artifact_type: SECOND_BRAIN_MILESTONE
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
canonical_base_sha: 2d333d367a93fa93c2e01c5055edbcca805463b2
direct_consumers:
  - future B16 research routing
  - closed-path deduplication
  - owner milestone closeout
---

# Second Brain Milestone — B16 R4 execution fidelity

This milestone records reusable decision support from accepted canonical evidence. It does not replace the canonical R4 result owner and grants no Factory, runtime, HOLDOUT, Candidate, risk, deployment, trading, KINT, or Grade authority.

## Evidence

Canonical result owner: `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md`.

The preregistered `B16-R4-r1` no-search contract tested only Strategy Tester model fidelity on one same-install `D:\Meta 5` lineage with the USDJPY/H1 BUY 14/30 parent fully frozen.

- Model1 MAIN: PF 1.54, net +255.30, 275 trades, EqDD 3.85%.
- Model1 BWD: PF 1.13, net +50.22, 267 trades, EqDD 2.38%.
- Model4 MAIN: PF 1.38, net +187.32, 273 trades, EqDD 3.91%.
- Model4 BWD: PF 1.20, net +74.73, 262 trades, EqDD 2.29%.
- All four cells passed the prospectively frozen full-window bars and mechanical identity gates.
- No model-switch sign flip or depth/exposure cliff appeared.
- HOLDOUT remained UNSPENT; optimization remained NONE.
## Interpretation

The accepted classification is `R4_EXECUTION_FIDELITY_NOT_FALSIFIED`: execution-fidelity evidence does not require PARKing the frozen 14/30 parent. Model4 weakens MAIN economics but does not create a model-switch cliff; BWD improves modestly.

The important limitation is unchanged by the aggregate pass: 2020 BWD is losing under both tester models. Model1 2020 PF is 0.7574 with net -40.91; Model4 2020 PF is 0.7921 with net -35.06. R4 therefore does not establish all-year or regime-wide robustness.

## Decision support

- Retain USDJPY/H1 BUY 14/30 as the B16 research reference.
- Do not reopen H05/H07/H08 or use BWD/2020 as a retuning surface.
- Do not rerun the same Model1-to-Model4 fidelity question without a new direct consumer.
- Do not convert `R4_EXECUTION_FIDELITY_NOT_FALSIFIED` into Candidate, HOLDOUT, Grade, DEMO/LIVE, risk/default, deployment, or trading authority.
- No automatic next experiment is created. Monte Carlo, broader broker/install portability, or HOLDOUT require separate prospective contracts if a direct consumer later exists.

## Negative evidence preserved

The rejected H08 14/35 center remains rejected by BWD. The R4 result applies to the accepted 14/30 parent only. The persistent 2020 weakness is retained explicitly rather than hidden by aggregate full-window PASS.

## Current unknowns

Monte Carlo was not run. Broker/install portability beyond the same-install lineage was not run. HOLDOUT is unspent. `KINT-001` remains open and numeric A/B/C/D or Grade/Confidence mapping remains unratified.

## Milestone scrutiny

The work is necessary because canonical R4 evidence materially changes the prior Second Brain state from prospective/UNKNOWN to accepted execution-fidelity evidence. No accepted experiment was replayed, no source corpus was reread, no new parameter hypothesis was created, and no post-result range expansion was introduced. Selection/hindsight risk is bounded by preserving the frozen 14/30 parent, the preregistered bars, the losing 2020 subperiod, and the closed H05/H07/H08 paths.