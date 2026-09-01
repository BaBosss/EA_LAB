---
object_type: RESEARCH_SYNTHESIS
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
source_catalog: SRC-EALAB-QUANTCORNER-20260901
external_repo_commit: 47bf86ada661e7d016280250138ce99ebf5c40ee
ea_lab_base_sha: e9a3816775e1e2810ca99c55f349cdabc70d5348
---

# QuantCorner Paper Intake and EA_LAB Gap Matrix â€” 2026-09-01

## Purpose

Convert the owner-supplied QuantCorner paper library into a traceable EA_LAB research supply chain without treating a large PDF collection as evidence by itself.

The pinned catalog has 276 tracked files. Most remain `CATALOG_ONLY`. This synthesis deep-reviews only papers with a direct current or near-term consumer and reuses accepted EA_LAB cards where they already exist.

## Evidence tiers in this intake

| Tier | Count | Meaning |
|---|---:|---|
| `DEEP_REVIEWED_THIS_INTAKE` | 11 | primary/publication source checked and a research card or direct synthesis exists |
| `REUSE_EXISTING_EALAB_FULLTEXT` | 3 | accepted Second Brain evidence already exists; no rediscovery |
| `CATALOG_ONLY` | 262 | filename/tree metadata only; no substantive claim accepted |

Exact per-file status is in `knowledge/01_sources/quantcorner_quant_investment_papers_inventory_20260901.csv`. Counts above are catalog-row counts, not unique-paper counts. The 11 deep-reviewed rows cover 10 unique works because Good Volatility / Bad Volatility has two upstream paths. DNN-ForwardTesting has a primary-source card but no proven exact pinned-tree path mapping in this intake, so it is outside the inventory deep-review count.

## Direct-consumer research map

| Topic | Source basis | Existing EA_LAB overlap | Gap / opportunity | Decision |
|---|---|---|---|---|
| AlgoXpert IS/WFA/OOS | arXiv:2603.09219 | plateau selection, parameter lock, BWD/HOLDOUT discipline, fail-closed evidence | formal purged rolling WFA, state-reset semantics, standardized degradation diagnostics, systematic execution stress / safeguard ablation | `P0 METHOD DELTA` |
| 101 Formulaic Alphas | existing `RC-SSRN2701346-001` | formulaic-alpha component note already exists | make operator/observable primitives easier to query without copying formulas | `P1 ENRICH EXISTING` |
| Pairs / Stat-Arb | existing `RC-SSRN2147012-001` + Tadi/Witzany + KalmanNet paper | cointegration mechanism note exists | deterministic cost-aware baseline, relationship-break handling, later advanced children | `P1 NEW FAMILY CANDIDATE` |
| Signed volatility / jumps | Patton & Sheppard, DOI 10.1162/REST_a_00503 | regime framework exists | asymmetric realized-volatility context not yet represented as a reusable component | `P1 FUTURE REGIME HYPOTHESIS` |
| Cross-sectional Learning-to-Rank | arXiv:2012.07149 + existing `HYP-SB-002` | relative-strength hypothesis already source-traceable | ranking model is a future child of a frozen cross-sectional simulator, not a new duplicate family | `P2 ENRICH HYP-SB-002` |
| Multi-agent alpha communication | arXiv:2511.13614 | Control Tower / workers / independent evidence already stronger than prose | empirical reminder that communication topology is context-dependent and discussion quality != returns | `P2 ARCHITECTURE LESSON` |
| DNN-ForwardTesting | arXiv:2210.11532 | chronological OOS/HOLDOUT already canonical | model-generated future adds forecast-model risk to selection risk | `P3 SCENARIO RESEARCH ONLY` |
| HFT / microstructure | catalog + existing execution research | broker execution, Model-4, implementability cards exist | some papers may inform stress assumptions | `P3 PULL ON DEMAND` |
| Earnings/news/fundamental equity signals | Facebook-highlighted catalog | little direct FX/XAU/BTC consumer now | transfer gap is large; data stack not current priority | `PARK` |
| Options/derivatives | catalog | not current EA family focus | no direct consumer | `PARK` |
| WorldQuant BRAIN/templates | catalog | alpha-primitive concept overlaps | useful ideation grammar but content not yet verified | `PARK / REFERENCE` |
| Textbooks / education | catalog | broad methodological reference | copying/redistribution unnecessary and copyright-sensitive | `REFERENCE ONLY` |

## Research conclusions

### 1. The catalog is useful as an idea queue, not as a strategy queue

A paper title can nominate a mechanism. It cannot nominate an EA winner, parameter, symbol, timeframe, risk setting, or candidate.

The admissible transition is:
`paper -> mechanism claim -> transfer gap -> falsifiable hypothesis -> prospective experiment`.

### 2. The highest-ROI method improvement is purged WFA for stateful systems

EA_LAB already rejects peak-PF worship and uses late HOLDOUT. AlgoXpert adds the clearest missing methodology around state contamination at rolling train/test boundaries.

This should be an optional R4 method for a qualified stateful survivor, not mandatory extra testing on every weak EA.

### 3. The highest-ROI new strategy family is deterministic statistical arbitrage

The pairs literature spans transaction costs, stochastic control, Kalman/state-space models, copulas and RL. EA_LAB should not jump to the most complex member.

Cross-impact, macro-conditioned mean reversion, and transaction-region control were separately verified as distinct layers. This strengthens the rule that execution realism and predictive context are children of a baseline, not substitutes for proving the pair relationship.

Research ladder:
1. fixed pair/universe semantics;
2. relationship-stability test;
3. deterministic hedge/spread construction;
4. fixed divergence/convergence rule;
5. explicit spread/slippage/swap/funding;
6. structural-break exit/disable rule;
7. broad fixed-config screen;
8. only after a real pulse: dynamic/Kalman/copula/ML children, one logical change at a time.

### 4. Signed volatility is a context feature candidate, not a discovered trading edge

Patton & Sheppard's equity evidence says negative-return variation and signed jumps carry asymmetric information for future volatility. That is a source claim in equities, not proof for XAU/FX/BTC.

EA_LAB may test a future signed-volatility context hypothesis, but current Boss19 P4A remains frozen and must not be retrofitted.

Stock and Watson adds a separate macro-method lesson: current-state estimation and forward-state forecasting should remain distinct, with vintage/as-of timing frozen. That is a regime-system design principle, not permission to add yield-curve or credit-spread features to the frozen classifier.

### 5. Cross-sectional ranking is already represented

`HYP-SB-002` is the correct owner for cross-sectional relative-strength rotation and remains `SEMANTICS_REQUIRED`. Learning-to-Rank is a later model choice only after universe, return normalization, rebalance, cost and benchmark semantics are frozen and a deterministic portfolio simulator exists.

### 6. LLM-agent evidence supports EA_LAB's evidence discipline

The multi-agent paper reports that communication can help but the best organization depends on market characteristics, and conversation quality scores were not correlated with returns in its experiments.

EA_LAB inference: worker prose or apparent sophistication must never substitute for deterministic evidence and independent review. This is an architecture lesson, not authority for autonomous trading agents.

### 7. DNN-ForwardTesting is intentionally late

The paper proposes selecting a trading indicator by testing it on DNN-predicted future paths and reports improvements in its study. EA_LAB should treat this as a possible scenario-generation research path, because:
`forecast-model error -> synthetic-future error -> strategy-selection error`
is an additional failure chain.

It does not replace chronological BWD/OOS/HOLDOUT.

## Candidate outputs created by this intake

- `HYP-SB-003`: cost-aware deterministic cointegration pairs baseline â€” `SEMANTICS_REQUIRED`.
- `HYP-SB-004`: signed-volatility / signed-jump regime context â€” `SEMANTICS_REQUIRED`.
- AlgoXpert gap analysis â€” method proposal only.
- Alpha Primitive Library enrichment â€” no copied alpha formulas.
- Stat-arb mechanism enrichment â€” deterministic baseline before neural/RL children.
- QuantCorner research backlog â€” direct-consumer ordering and parked areas.

## Explicit non-decisions

This intake does not:
- launch Factory;
- run MT5;
- spend HOLDOUT;
- select a pair/symbol/timeframe;
- choose a risk or position-size default;
- close KINT-001;
- assign A/B/C/D grades;
- change Boss19 P4A;
- authorize QI-2+;
- deploy or trade.

## Next consumer

The next legitimate active research consumer is whichever separately preregistered experiment has the highest information value after current EA_LAB lanes are considered. The catalog itself does not create execution urgency.
