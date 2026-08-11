# WOBR Platform Discovery Ledger

> Discovery-only ledger for the ongoing WOBR / external quant-platform study.
> This document records supplied observations and bounded EA_LAB possibilities; it does not accept an architecture, change a milestone, or grant execution/trading authority.

## 1. Purpose and scope

This ledger is the durable, append-friendly record of concepts observed while reviewing external quant platforms. It separates source observations from EA_LAB inferences and future candidates so later website reviews can extend the record without turning discovery into implementation authority.

Scope in this revision:

- supplied findings for Quant Research and StrategyVerse;
- cross-site relationships that can be tested against the existing controlled validation pipeline;
- placeholders for the remaining sites;
- no code, configuration, risk-default, deployment, or governance change.

Labels used throughout:

- **OBSERVED** â€” directly observed from the external product/source.
- **INFERRED** â€” EA_LAB inference derived from an observed concept.
- **CANDIDATE** â€” possible future EA_LAB capability, not accepted architecture.
- **DEFERRED** â€” intentionally outside current implementation scope.
- **REJECTED** â€” intentionally not worth pursuing or not authorized by this discovery record.

## 2. Reviewed-site status

| Site | Status | Basis |
|---|---|---|
| Quant Research | **OBSERVED â€” reviewed in supplied findings** | Research-oriented practitioner-facing feed and examples supplied by the user. |
| StrategyVerse | **OBSERVED â€” reviewed in supplied findings** | Structured strategy-blueprint and indicator-encyclopedia concepts supplied by the user. |
| WOBR Macro | **OBSERVED â€” reviewed in supplied checkpoint** | Macro / World Intelligence concepts supplied by the user. |
| WOBR Macro Time Machine | **OBSERVED â€” URL supplied; functionality not verified** | The dedicated path was supplied; detailed page functionality remains non-observed. |
| WOBR AI Portfolio | **OBSERVED â€” reviewed in supplied checkpoint** | AI manager/strategy population, portfolio construction, and risk-view concepts supplied by the user. |
| QuantMogul | **OBSERVED â€” supplied manual URL; detailed contents not verified** | `quantmogul.ai/manual` was not retrievable through the supplied research crawler; adjacent WOBR ecosystem concepts are recorded separately. |
| WOBR Marketplace | **OBSERVED â€” supplied concept; direct page not verified** | Marketplace, explorer-preview, ranking, and navigation concepts supplied by the user; detailed page functionality remains uncertain. |

## 3. Quant Research findings

### OBSERVED

- Research-oriented feed translating quantitative and academic research toward practitioner use.
- Coverage includes ML/AI, strategy and portfolio construction, market microstructure, regime detection, momentum, mean reversion, position sizing, risk management, order flow, and volatility.
- Relevant examples include forward-gated model replacement, LLM execution research, and outcome-noise / effective-sample-size research.

### INFERRED

- Research concepts could be represented before they enter EA_LAB experimentation.
- Research provenance is useful as a traceable input to later experiment evidence.
- Research discovery should have **zero production/trading authority**.

### CANDIDATE

- **EA_LAB Research Intelligence Layer** as a future discovery and translation capability.
- A staged path: `Research -> Research Card -> Applicability -> Testable Hypothesis -> Experiment Candidate -> existing controlled validation pipeline`.
- Keep research provenance attached throughout the experiment lifecycle.
- Challenger/incumbent promotion concepts may later inform forward-test promotion gates.
- Strategy Evidence Score may later incorporate outcome-noise and sample-quality considerations.

### DEFERRED

- Autonomous paper ingestion.
- Automatic EA creation from papers.
- Automatic promotion or deployment.
- Execution changes derived directly from research.

## 4. StrategyVerse findings

### OBSERVED

- Structured strategy blueprints.
- Blueprint concepts include thesis, components/indicators, reasons/roles, market regime, complexity, asset class, timeframe, and known failure conditions.
- Indicator-encyclopedia concepts include formulas, inputs/defaults, output semantics, and relationships to strategies.
- Strategy organization spans families such as trend, mean reversion, breakout, momentum, volatility, and multi-factor.

### INFERRED

- Strategy structure can be recorded separately from performance results.
- A strategy's expected operating conditions and failure conditions are useful evidence context.
- Structural similarity may provide information beyond return correlation.
- Failed, rejected, and inconclusive experiments can form negative knowledge that prevents repeated research and compute.

### CANDIDATE

- **Strategy Blueprint / Strategy DNA** representation.
- **EA Component Registry** covering indicators, entries, exits, filters, position sizing, stop logic, take profit, sessions, volatility filters, and regime filters.
- **Strategy Operating Envelope** describing where a strategy is expected to work, fail, or remain unknown.
- **Strategy Genome** representation.
- Structural strategy similarity in addition to return correlation.
- Future diversification dimensions: return correlation, drawdown correlation, regime correlation, and strategy-DNA similarity.
- Strategy lineage / family tree.
- Strategy lifecycle: `IDEA -> BLUEPRINT -> EXPERIMENT -> IMPLEMENTATION -> BACKTEST -> OPTIMIZATION -> ROBUSTNESS -> FORWARD TEST -> ACCEPT/REJECT`.

### DEFERRED

- Implementing a new blueprint, DNA, genome, registry, or lineage system based on this discovery ledger alone.
- Replacing the existing EA_LAB validation or evidence pipeline with an external platform's organization model.

## 5. Cross-site emerging relationships

### INFERRED

The supplied findings suggest a possible relationship between research discovery, structured strategy knowledge, market context, and historical analogs:

`Quant Research -> research knowledge / evidence quality`

`StrategyVerse -> Strategy Blueprint -> Strategy Genome -> Strategy Operating Envelope`

`Macro -> Current Market State -> regime/context attribution`

`Time Machine -> Historical Regime Library -> regime similarity -> regime coverage -> historical stress evidence -> OOD awareness`

`AI Portfolio -> Portfolio Eligibility -> structural diversification -> exposure analysis -> risk budgeting concepts -> portfolio stress -> shadow portfolio evidence -> Portfolio Health`

`Quant Workflow Layer -> Experiment Contract -> Experiment Registry -> Workflow Recipes -> Robustness Pack -> Evidence Matrix -> Evidence Gap Engine -> Strategy Evidence Graph -> Optimization Memory`

`Marketplace -> Internal Strategy Catalog -> Strategy Package / Evidence Passport -> search / compare / reuse`

Then:

`Experiment Candidate -> existing EA_LAB implementation -> Controlled Backtest -> Controlled Optimization -> evidence -> Forward Test`

This is an EA_LAB inference about information flow, not an accepted architecture or implementation plan.

### CANDIDATE

- A future research-to-strategy trace could connect a research card, strategy blueprint, experiment candidate, and resulting evidence while preserving provenance.
- A future analytical view could relate `Performance x Regime x Time`.
- A future analytical view could relate `Portfolio Performance x Regime x Strategy Structure`.
- The existing controlled validation pipeline remains the possible destination for testable candidates; external claims do not substitute for EA_LAB evidence.

The synthesis remains **INCOMPLETE** because WOBR Marketplace has not yet been synthesized.

## 6. Candidate EA_LAB concepts

The following are recorded for future evaluation only:

| Candidate | Potential purpose | Current standing |
|---|---|---|
| Research Card | Normalize a research finding, applicability, provenance, and testable hypothesis. | **CANDIDATE**, not accepted. |
| Strategy Blueprint / DNA | Describe thesis, components, roles, regimes, complexity, and failure conditions. | **CANDIDATE**, not accepted. |
| Component Registry | Reuse consistent names and relationships for strategy parts. | **CANDIDATE**, not accepted. |
| Operating Envelope | Record expected work/fail/unknown conditions. | **CANDIDATE**, not accepted. |
| Strategy lineage | Preserve family relationships and negative knowledge across experiments. | **CANDIDATE**, not accepted. |
| Evidence-quality dimensions | Add noise/sample-quality context to future evidence scoring. | **CANDIDATE**, not accepted. |

## 7. Deferred / not-authorized implementation

### DEFERRED

- Remaining-site reviews until their source material is supplied or separately authorized for review.
- Autonomous ingestion, EA generation, promotion, deployment, and direct execution changes from external research.
- Any new schema, registry, lifecycle engine, or architecture change arising from these candidates.

### REJECTED

- Treating any **CANDIDATE** in this ledger as an accepted EA_LAB architecture.
- Treating external research, blueprints, rankings, or platform claims as production/trading authority.
- Changing current milestones, execution code, trading code, risk defaults, deployment configuration, or accepted governance from this discovery record.

## 8. Source URLs

Only URLs explicitly supplied in the authoritative checkpoints are recorded here. To comply with the instruction not to browse independently, other URLs are intentionally not invented. Add an exact source URL beside each future site observation when the corresponding source is supplied or reviewed under an authorized research task.

| Source / site | URL |
|---|---|
| Quant Research | `TBD â€” not included in supplied findings` |
| StrategyVerse | `TBD â€” not included in supplied findings` |
| WOBR Macro | `TBD â€” exact URL not included in supplied checkpoint` |
| WOBR Macro Time Machine | `/macro/time-machine` (supplied path; detailed functionality not independently verified) |
| WOBR AI Portfolio | `TBD â€” exact URL not included in supplied checkpoint` |
| QuantMogul | `https://quantmogul.ai/manual` (supplied URL; detailed contents not independently verified) |
| WOBR Marketplace | `https://wobr.ai/marketplace` (supplied URL; detailed functionality not directly retrievable) |

## 9. Site findings and remaining-site placeholders

Use the following compact structure when each site is reviewed. Keep observations separate from EA_LAB inferences and candidates.

### WOBR Macro

#### OBSERVED

- WOBR exposes a Macro / World Intelligence capability.
- Observed macro-oriented concepts include global capital flow, global liquidity, global risk, market/macro context, Alpha Survival / strategy-survival context, and forward-versus-backtest performance-gap concepts.
- The product concept combines multiple market/macro dimensions rather than treating market state as a single indicator.

#### INFERRED

- EA_LAB could derive a future Market Context Layer from this concept.
- A possible Market State Vector could include `trend_state`, `volatility_state`, `liquidity_state`, `risk_state`, `momentum_state`, `cross_asset_state`, `session_state`, and `event_state`.
- Market state may eventually need `STATE + TRANSITION + DURATION + CONFIDENCE`.
- Strategy regime metadata from StrategyVerse could later connect to market context through `Current Market State -> Strategy Operating Envelope -> Compatibility analysis`.
- Initially, regime/context should be an analytical dimension, not an automatic strategy-enable/disable mechanism.
- A future backtest or forward-test trade could be attributable to a `market_context_id` for performance-by-regime analysis.
- A possible decomposition is `observed degradation -> adjust for regime-distribution change -> residual degradation`, helping distinguish market regime change from strategy / alpha degradation.

Example conceptual context only; labels and algorithms are not frozen:

```text
Trend = STRONG_UP
Volatility = HIGH
Liquidity = NEUTRAL
Risk = RISK_OFF_TRANSITION
Momentum = POSITIVE
Confidence = 0.81
```

#### CANDIDATE

- Market Context Layer.
- Market State Vector.
- Market Context Snapshot.
- Regime attribution, regime confidence, and regime transition detection.
- Performance-by-Regime analytics.
- Strategy x Regime compatibility.
- Strategy Population Health, including health by strategy family.
- Backtest-vs-Forward Gap analysis.
- Forward Degradation analysis.
- Regime-normalized Forward Degradation.
- Possible future degradation dimensions: return gap, profit-factor gap, drawdown gap, win-rate gap, trade-frequency gap, slippage gap, and regime-normalized gap.

Do not define a final degradation-score formula yet.

#### DEFERRED

- Automatic EA switching based on macro state.
- Automatic strategy enable/disable.
- Macro-driven trade decisions.
- Automatic risk changes.
- Automatic deployment/promotion.
- Live macro-data ingestion.
- Fixed proprietary regime formulas.

Research/context intelligence has **zero trading or production authority**.

### WOBR Macro Time Machine

#### OBSERVED

- The supplied WOBR source set contains the dedicated URL path `/macro/time-machine`.
- Detailed page functionality could not be independently verified from the supplied discovery context.

The inferred EA_LAB concepts below must not be attributed to WOBR as observed product facts. They are EA_LAB-derived concepts inspired by the existence/context of the Time Machine surface.

#### INFERRED

Possible EA_LAB Market Time Machine flow:

`Current Market State -> Historical Similarity Search -> Similar Historical Regimes -> Historical Strategy Evidence -> Historical Analog Report`

Core research question:

> When has the market previously resembled the current state, and how did our strategies behave?

- Historical market states should be comparable, but no similarity algorithm is accepted.
- Possible future methods include normalized distance, cosine similarity, clustering, nearest neighbors, or learned representations. These remain implementation choices; do not freeze an algorithm.
- A Historical Regime Library could represent market history as regime episodes rather than only independent bar-level labels.
- Potential episode metadata includes `start_time`, `end_time`, `trend_state`, `volatility_state`, `liquidity_state`, `risk_state`, `cross_asset_state`, `transition_in`, `transition_out`, `duration`, market events, and strategy-performance evidence.
- Duration matters: a short high-volatility spike and a multi-week high-volatility regime are not equivalent environments.

#### CANDIDATE

- Strategy Time Machine: inspect a strategy's historical behavior under environments such as high volatility, liquidity contraction, trend transition, or a risk-off shock. The output should be evidence, not predictions.
- Historical Stress Library combining named historical events with quantitatively detected episodes. Illustrative categories such as volatility shock, liquidity contraction, rate shock, low-volatility compression, breakout episode, abrupt reversal, and trend exhaustion must not become hard-coded acceptance categories.
- Regime Coverage Report showing evidence such as `GOOD`, `LOW SAMPLE`, `NO EVIDENCE`, or `WEAK` by regime dimension.
- Coverage Gap -> Experiment Candidate, so missing evidence can generate a controlled experiment candidate rather than an arbitrary experiment.
- Time-aware Strategy Decay: `Raw Strategy Decay -> Regime Normalize -> Residual Alpha Decay`.
- Out-of-Distribution detection when the current market state has no sufficiently similar historical analog; fail toward uncertainty rather than force an analogy.
- Historical Analog provenance covering market-context schema/version, feature definitions, source-data snapshot, similarity-method version, candidate historical episodes, similarity scores, and linked EA evidence IDs.

These concepts should connect to the sample-quality / effective-sample-size ideas already recorded from Quant Research.

An AI-generated analogy without provenance should not be treated as quantitative evidence.

#### DEFERRED

- Automatic trading from historical analogs.
- Automatic strategy enable/disable.
- Automatic risk modification.
- Prediction that historical patterns will repeat.
- Automatic production promotion.
- Fixed similarity algorithm.
- Treating historical analogs as deterministic forecasts.

### WOBR AI Portfolio

#### OBSERVED

- Product concepts include a population of AI manager / strategy profiles with different strategy and risk profiles.
- Observed portfolio concepts include risk-adjusted manager ranking using metrics such as Sharpe, drawdown, and consistency; diversified portfolio construction; and a meta-portfolio concept.
- Portfolio profiles include conservative, balanced, and aggressive examples.
- Observed portfolio tooling concepts include Portfolio Balancer using correlation plus allocation, Farm Diversify, and portfolio risk views involving VaR, Expected Shortfall, Max Drawdown, and Correlation Risk.

Bot Farm displayed performance data was presented as sample/demo/development data. Those displayed numbers are **not validated real-performance evidence** and must not be recorded as such.

#### INFERRED

- A portfolio could become a versioned research object rather than merely a list of EAs.
- A possible `PORTFOLIO_BLUEPRINT` could contain `portfolio_id`, `portfolio_version`, objective, risk class, member strategies, allocation policy, risk budget, diversification constraints, symbol exposure, strategy-family exposure, regime exposure, linked evidence, and lifecycle status. No schema is accepted.
- Portfolio selection should occur only after strategy eligibility: `ALL STRATEGIES -> VALIDATED? -> ENOUGH EVIDENCE? -> FORWARD ELIGIBLE? -> NOT DEGRADED? -> PORTFOLIO ELIGIBLE`.
- Portfolio optimization should not consume every experimental EA by default.
- Diversification should extend beyond return correlation to drawdown correlation, Strategy DNA similarity, regime dependence, symbol exposure, currency/asset exposure, direction exposure, session exposure, entry-mechanism similarity, and risk-mechanism similarity.
- Capital allocation and risk allocation are different concepts: `Capital Allocation != Risk Allocation`.
- Raw backtest performance alone should not determine portfolio selection.
- A strategy may have modest standalone return but high diversification value.
- Macro / Market Context now has a possible portfolio analytical consumer through `Portfolio Performance x Market Regime`.

#### CANDIDATE

- Portfolio Eligibility Layer, with possible exclusion reasons including insufficient evidence, forward degradation, excessive structural similarity, inadequate regime coverage, failed robustness, or lifecycle state not eligible. No final eligibility score or formula is accepted.
- Hidden Concentration analysis by symbol, currency, asset class, strategy family, regime dependency, session, direction, entry mechanism, and risk model.
- Strategy Similarity Graph: `Candidate Pool -> Strategy Genome / DNA representation -> Similarity Graph -> Cluster Detection -> Diversified Candidate Selection`. No graph or clustering algorithm is accepted.
- Risk Budget Layer. Do not define live sizing or risk formulas during this discovery phase.
- Evidence-weighted portfolio selection using possible dimensions of raw performance, robustness, forward evidence, regime coverage, sample quality, degradation, and diversification value. Do not freeze formula, weights, thresholds, or ranking procedure.
- Portfolio contribution attribution for return, drawdown, tail risk, and diversification.
- Regime Diversification across preferred trend, range, and transition environments.
- Portfolio Stress Test: `Portfolio Candidate -> Historical Stress Library -> Portfolio-level Backtest/Simulation -> simultaneous strategy behavior -> Portfolio Stress Report`.
- Shadow Portfolio lifecycle: `BACKTEST -> PORTFOLIO SIMULATION -> HISTORICAL STRESS -> SHADOW FORWARD -> OBSERVED DIVERSIFICATION -> PORTFOLIO ACCEPTANCE`.
- Portfolio Drift detection comparing intended exposure with observed risk contribution. No automatic rebalance is authorized.
- Portfolio Orchestrator supporting `OBSERVE`, `ANALYZE`, `PROPOSE`, and `SIMULATE` only.

#### DEFERRED

- Automatic trading from portfolio analysis.
- Automatic strategy enable/disable.
- Automatic risk changes or live rebalancing.
- Automatic deployment or promotion.
- Production promotion from portfolio research alone.
- Any live sizing or risk-default change.

The Portfolio Orchestrator concept has zero implied authority to trade, change risk, deploy, promote, or rebalance live capital. Any future execution capability would require separate accepted governance and owner authorization.

### QuantMogul

#### OBSERVED

- The supplied manual URL is `https://quantmogul.ai/manual`.
- The URL was not retrievable through the supplied research crawler, and reliable indexed documentation for the current domain was not found during this discovery pass.
- Search results referring to an older or different QuantMogul domain are not evidence about the supplied `quantmogul.ai` product and must not be conflated with it.

Adjacent WOBR public evidence supplied during the research pass verifies these **WOBR ecosystem concepts**:

- Strategy Vault.
- Backtest Cloud.
- Alpha & Monte Carlo Simulation.
- Portfolio Balancer.
- Farm Diversify.
- n8n MT5 Bridge.
- AI Workflow Builder.
- EA Generator.
- AI Queue.
- Trading Agents.
- Workflow Studio / MogulX concepts including visual workflows, deep-learning models, Monte Carlo, and correlation analytics.

These are observed WOBR ecosystem concepts, not verified QuantMogul-manual features.

#### INFERRED

- EA_LAB could consider an Experiment Operating Layer above the already accepted controlled execution lanes.
- A possible flow is `Research Idea -> Strategy Blueprint -> Experiment Contract -> Implementation Candidate -> Controlled Backtest -> Controlled Optimization -> Robustness Pack -> Evidence Package -> Forward Candidate`.
- Existing Controlled Backtest and Controlled Optimization should be reused; no competing backtest or optimization executor is implied.
- Workflow orchestration should not duplicate the existing Router, Executor, or Authorization Kernel.
- Conceptual separation: `WORKFLOW = what research step should occur next`; `AUTHORIZATION = whether an exact primitive action may actually execute`.
- Deterministic/local computation should be preferred where possible for compilation, hashing, schema validation, metric calculation, Monte Carlo computation, and run comparison. Model reasoning is better reserved for ambiguous diagnosis, interpretation, architecture decisions, and consequential review.
- Parameter optimization and structural strategy changes are different experiment classes; possible taxonomy values include `PARAMETER`, `STRUCTURAL`, `ROBUSTNESS`, `REGIME`, `STRESS`, `PORTFOLIO`, and `RCA`. These are not frozen.

#### CANDIDATE

**Experiment Contract**

- Possible fields: `experiment_id`, hypothesis, experiment type, strategy ID/version, symbol, timeframe, test period, parameter scope, primary metrics, guardrail metrics, required robustness, acceptance conditions, research provenance, market-context scope, expected artifacts, and authority.
- Default conceptual authority: `RESEARCH_ONLY`.
- Purpose: preregister what is being tested, why, and what evidence constitutes success or failure before results are observed. No schema is accepted.

**Experiment Registry**

- A strategy may link to multiple experiments.
- Possible lifecycle: `PLANNED -> RUNNING -> COMPLETE`.
- Possible verdicts: `ACCEPTED`, `REJECTED`, `INCONCLUSIVE`, `INVALID`, and `SUPERSEDED`.
- A record could retain hypothesis, inputs, strategy/source version, parameter and dataset scope, run IDs, results, verdict, verdict reason, and evidence references.
- Purpose: maintain durable experiment history and prevent unnecessary repeated investigation.

**Negative Experiment Memory**

- Rejected, inconclusive, and invalid experiments should remain searchable evidence.
- Before proposing a new experiment: `Candidate Experiment -> Existing Experiment Search -> Equivalent/near-equivalent prior evidence? -> reuse / extend / rerun only when justified`.
- Purpose: reduce duplicate research, MT5 compute, and model quota.

**Robustness and evidence**

- Monte Carlo and related methods should contribute robustness evidence rather than production authority.
- A possible Robustness Pack may contain trade-sequence robustness, transaction-cost sensitivity, spread sensitivity, slippage sensitivity, parameter perturbation, start-period sensitivity, regime coverage, historical stress, and backtest-versus-forward gap tests.
- A possible Evidence Matrix could expose dimensions such as backtest, optimization, OOS, parameter stability, Monte Carlo, historical stress, regime coverage, and forward evidence.
- A possible Evidence Gap Engine could map `Evidence Matrix -> Missing / Weak Evidence -> Required Evidence -> Experiment Candidate`.
- Potential consumers include Quant Research, Time Machine / Historical Stress, forward validation, and portfolio eligibility.
- `GOOD BACKTEST != ROBUST STRATEGY`.
- No test method, formula, threshold, required count, or final evidence vocabulary is accepted.

**Workflow concepts**

- A Research Workflow DAG could connect `Research -> Blueprint -> Experiment -> Build -> Backtest -> Optimization -> Robustness -> Review -> Forward`.
- Illustrative reusable recipes: `NEW_STRATEGY_VALIDATION_V1`, `PARAMETER_REPAIR_V1`, `REGIME_STRESS_V1`, `FORWARD_DEGRADATION_RCA_V1`, and `PORTFOLIO_CANDIDATE_V1`.
- A research-only Experiment Queue could use statuses such as `QUEUED`, `READY_FOR_AUTHORIZATION`, `RUNNING`, `WAITING_EVIDENCE`, `COMPLETE`, and `BLOCKED`.
- The queue organizes research work only and provides zero execution authority.

**Evidence lineage and comparison**

- A Strategy Evidence Graph could trace `Research Card -> Strategy Blueprint -> Experiment Contract -> Source Version / SHA -> Build Artifact -> Backtest Receipt -> Optimization Receipt -> Robustness Evidence -> Forward Evidence`.
- Desired property: evidence is attributable to a run, strategy version, experiment, and source research item.
- A Comparison Engine could compare strategy versions, experiments, parameter sets, backtest versus forward, regimes, or portfolios only after validating symbol, period, cost assumptions, data source/version, metric definition, and strategy identity.
- If material comparability dimensions are incompatible, the comparison should be `COMPARISON INVALID` rather than silently summarized.
- Optimization Memory could record strategy version, parameter domain, search coverage, market/test period, objective, results, stability evidence, and linked receipts before future searches are launched.

**EA Generator boundary**

- EA Generator is an observed WOBR ecosystem concept.
- A possible EA_LAB boundary is `Research / Blueprint -> Implementation Contract -> bounded implementation -> deterministic tests -> controlled validation -> evidence`.
- Generated source remains a candidate and gains no production authority merely by being generated.

#### DEFERRED

- Implementing an Experiment Operating Layer, Contract, Registry, Queue, DAG, Evidence Matrix, Evidence Gap Engine, Evidence Graph, Comparison Engine, or Optimization Memory from this checkpoint alone.
- Replacing accepted EA_LAB execution or authorization infrastructure.
- Automatic execution, promotion, deployment, risk changes, or production authority from workflow state, generated source, Monte Carlo output, or AI reasoning.

#### REJECTED

- Treating inferred workflow concepts as verified QuantMogul manual features.
- Replacing the Router, Executor, Authorization Kernel, Controlled Backtest, or Controlled Optimization with competing versions.
- Treating `AI Idea -> generated EA -> trade` as an authorized pipeline.
- Allowing an AI summary to silently compare incompatible evidence.

### WOBR Marketplace

#### OBSERVED

- WOBR exposes an EA Marketplace concept.
- Explorer-tier users are described as able to browse EA Marketplace previews.
- WOBR navigation is organized around `Research -> Build -> Test -> Run -> Compete -> Marketplace`.
- WOBR separately exposes EA Ranking / leaderboard concepts.
- A supplied public EA ranking page showed concepts including EA identity/token, symbol, performance, trade count, price, and a buy/action surface.
- The ranking page explicitly identified displayed data as sample/demo/development data.
- The supplied page URL is `https://wobr.ai/marketplace`; detailed page functionality was not directly retrievable during the research pass.

Displayed returns, rankings, trade counts, success rates, prices, and EA quality are not validated real-world evidence and must not be used as architecture justification.

#### INFERRED

- Marketplace inspiration does not require EA_LAB to create a commercial marketplace.
- The useful internal concept is an **Internal Strategy Catalog / Strategy Discovery Layer** for discovering, inspecting, comparing, understanding provenance, and reusing existing evidence.
- A catalog would grant zero trading, deployment, promotion, or risk-change authority.

#### CANDIDATE

**Strategy Package**

- A version-bound package could contain identity, version, Strategy Blueprint, Strategy Genome, implementation identity, Evidence Passport, Operating Envelope, regime coverage, forward status, portfolio eligibility, dependencies, provenance, and lifecycle status.
- Do not freeze a schema. Strategy evidence is version-specific: evidence for Strategy X v1 must not automatically establish evidence for Strategy X v2.
- Potential binding: `Strategy + Version + Source Identity + Evidence`.

**Evidence Passport**

- A compact summary could include strategy/version, source identity, family, symbol, timeframe, baseline, optimization, OOS, robustness, historical stress, regime coverage, forward evidence, known weaknesses, provenance, and lifecycle status.
- The passport is an index into underlying evidence, not a replacement for it: `small durable summary + traceable drill-down to exact evidence`.

**Catalog admission and search**

- Candidate lifecycle: `IDEA -> EXPERIMENTAL -> VALIDATED -> FORWARD_CANDIDATE -> FORWARD_ACTIVE -> PORTFOLIO_ELIGIBLE -> ACCEPTED`.
- Possible non-active states: `REJECTED`, `DEGRADED`, `SUPERSEDED`, and `INVALID`.
- Catalog admission means discoverable as an evidence-bearing research object; it does not mean deploy, trade, promote, allocate capital, or enable LIVE.
- Capability search could use strategy family, symbol, timeframe, preferred/failure regime, forward status, regime coverage, robustness state, structural similarity, portfolio compatibility, and lifecycle state.

**Evidence-based comparison and reproducibility**

- Compare performance, robustness, forward evidence, sample quality, regime coverage, drawdown, degradation, structural uniqueness, and diversification contribution rather than raw profit alone.
- Preserve individual evidence dimensions rather than compressing prematurely into one opaque score. No ranking algorithm is accepted.
- A future package could expose reproducibility status such as source bound, implementation identity known, backtest receipt available, optimization receipt available, robustness evidence available, forward evidence available, regime coverage state, and provenance complete.
- Prefer evidence status over popularity-based trust. No badge vocabulary is accepted.

**Failure and negative knowledge**

- Preserve accepted, rejected, degraded, superseded, and invalid strategies/experiments as searchable knowledge.
- Possible flow: `New Idea -> Strategy / Experiment similarity lookup -> prior equivalent evidence found -> reuse / extend rather than blindly repeat`.
- This connects to Negative Experiment Memory, Experiment Registry, model-call ROI policy, and Optimization Memory.

#### DEFERRED

- Building a commercial marketplace.
- Implementing an Internal Strategy Catalog, Strategy Package, Evidence Passport, or ranking system from this discovery record alone.
- Automatic strategy deployment, promotion, trading, capital allocation, live enablement, portfolio rebalancing, or risk changes.

#### REJECTED

- Treating Marketplace sample/demo/development numbers as validated evidence.
- Treating popularity, price, leaderboard position, or raw return as sufficient strategy-quality evidence.

## 11. Cross-Platform Synthesis

### OBSERVED coverage boundary

The first supplied discovery pass covers all seven surfaces:

1. Quant Research
2. StrategyVerse
3. WOBR Macro
4. WOBR Macro Time Machine
5. WOBR AI Portfolio
6. QuantMogul manual / adjacent verified WOBR quant-workflow evidence
7. WOBR Marketplace

Source limitations remain explicit:

- detailed Macro Time Machine page functionality was not independently verified;
- `https://quantmogul.ai/manual` was supplied but its detailed contents were not independently verified;
- `https://wobr.ai/marketplace` was supplied but detailed direct-page functionality was not independently retrievable.

Therefore:

`DISCOVERY PASS = COMPLETE WITH DOCUMENTED SOURCE LIMITATIONS`

This does not mean architecture is accepted, and inferred capabilities from limited or unavailable pages remain non-observed.

### INFERRED emerging EA_LAB knowledge architecture

The supplied findings suggest this conceptual composition:

```text
Quant Research
  -> Research Intelligence / Research Cards / Evidence Quality / Hypotheses

StrategyVerse
  -> Strategy Blueprint / Strategy Genome / Component Registry / Operating Envelope

Experiment Operating Layer
  -> Experiment Contract / Experiment Registry / Negative Experiment Memory
  -> Evidence Gap Engine / Workflow Recipes

Existing accepted EA_LAB validation
  -> Controlled Backtest / Controlled Optimization
  -> existing receipts, evidence, and authorization infrastructure

Robustness and evidence
  -> Robustness Pack / Evidence Matrix / Strategy Evidence Graph
  -> Comparison Engine / Optimization Memory

Market and historical context
  -> Market State Vector / Regime / Transition / Duration / Confidence
  -> Historical Regime Library / Historical Stress / Regime Coverage
  -> Historical Analog / OOD concepts

Forward evidence
  -> Forward-vs-backtest gap / Regime-attributed performance
  -> Strategy degradation analysis / Population health

Portfolio intelligence
  -> Portfolio Eligibility / Structural Diversification / Strategy Similarity
  -> Risk Budget concepts / Portfolio Stress / Portfolio Health and Drift

Internal Strategy Catalog
  -> Strategy Package / Evidence Passport / Search / Comparison / Provenance / Lifecycle
```

This should be understood as a knowledge graph plus an evidence pipeline plus existing controlled execution lanes, not as one strictly linear pipeline.

Important non-linear relationships include:

- Quant Research -> experiment ideas.
- Time Machine -> evidence-gap experiments.
- Macro -> strategy and portfolio regime attribution.
- Strategy Genome -> portfolio structural diversification.
- Experiment Registry -> negative knowledge.
- Evidence Graph -> Strategy Package / Evidence Passport.
- Portfolio evidence -> strategy contribution evaluation.
- Internal Strategy Catalog -> future research reuse.

### CANDIDATE opportunity prioritization

This is a candidate-only research priority, not a roadmap or milestone change.

**Foundation candidates**

1. Strategy Blueprint.
2. Experiment Contract.
3. Experiment Registry.
4. Evidence Passport / Strategy Evidence Graph.

Rationale: these provide reusable identity, provenance, and experimental memory required by many later capabilities.

**Second-layer candidates**

- Evidence Matrix.
- Robustness Pack.
- Comparison Engine.
- Optimization Memory.
- Market Context / Regime.
- Historical Regime / Stress evidence.

**Later candidates**

- Portfolio Intelligence.
- Internal Strategy Catalog UI.
- Research automation.
- Workflow visualization.
- Advanced regime similarity.
- Portfolio orchestration.

### DEFERRED

- Automatic strategy deployment.
- Automatic DEMO/LIVE promotion.
- Automatic trading.
- Automatic capital allocation.
- Automatic portfolio rebalancing.
- Automatic risk changes.
- Autonomous production decisions.

Future candidate layers may observe, analyze, index, compare, propose, or simulate only within separately accepted lanes. They do not gain authority merely by being part of this research architecture.

## 12. Discovery status

```text
WOBR / EXTERNAL QUANT PLATFORM DISCOVERY
FIRST PASS = COMPLETE

SOURCE COVERAGE:
COMPLETE WITH DOCUMENTED LIMITATIONS

CROSS-PLATFORM SYNTHESIS:
COMPLETE FOR FIRST DISCOVERY PASS

EA_LAB ARCHITECTURE STATUS:
CANDIDATE / NOT ACCEPTED

IMPLEMENTATION AUTHORITY:
NONE FROM THIS DOCUMENT

CURRENT PROJECT MILESTONE:
UNCHANGED
```
