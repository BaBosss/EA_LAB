# EA_LAB Quant Intelligence Architecture Plan

> Canonical entry: `PROJECT_STATE.md`. This document owns future Quant Intelligence architecture planning only; it does not change project state, milestones, governance, or implementation authority.

## Purpose and boundary

This is a concise future-architecture plan derived from the discovery and provenance recorded in [WOBR_PLATFORM_DISCOVERY.md](WOBR_PLATFORM_DISCOVERY.md). It does not reproduce that ledger, clone WOBR, create implementation orders, or accept any candidate architecture.

Current project priority remains **VPS DEMO Deployment / Forward-Test**. Quant Intelligence is a prepared future architecture track only.

The target shape is:

```text
KNOWLEDGE GRAPH
+
EVIDENCE PIPELINE
+
EXISTING CONTROLLED EXECUTION LANES
```

Existing accepted infrastructure is reused as-is: Router, Authorization Kernel, Executor, Controlled Backtest, Controlled Optimization, and existing proof/receipt architecture. This plan proposes no replacements or redesigns for them.

## Candidate architecture layers

1. **Knowledge** — research provenance, Strategy Identity, Strategy Blueprint, Strategy Genome, component relationships, operating envelope, and failure conditions.
2. **Experiment** — Experiment Contract, Experiment Registry, lifecycle, Negative Experiment Memory, and Evidence Gap concepts.
3. **Existing Controlled Execution** — reference only to accepted Controlled Backtest, Controlled Optimization, authorization, and evidence infrastructure.
4. **Evidence Intelligence** — Evidence Matrix, Evidence Passport, Strategy Evidence Graph, robustness evidence, comparison validity, and Optimization Memory.
5. **Market / Historical Context** — Market Context, regime, transition, duration, confidence, Historical Regime Library, stress episodes, regime coverage, and OOD/analog uncertainty.
6. **Forward / Health** — backtest-vs-forward gap, regime-attributed performance, degradation analysis, and strategy population health.
7. **Portfolio / Discovery** — Portfolio Eligibility, structural diversification, Strategy DNA similarity, exposure analysis, portfolio health/drift, and Internal Strategy Catalog.

## Candidate future milestones

### QI-1 — Quant Intelligence Foundation MVP

Candidate scope: Strategy Record / Identity, Experiment Contract, Experiment Registry, Experiment Result, lifecycle state, Negative Experiment Memory, and evidence references.

No AI, macro, portfolio, execution, or trading change is implied. Purpose: establish reusable identity, provenance, and experiment memory.

### QI-2 — Evidence Intelligence

Candidate scope: Evidence Matrix, Evidence Passport, Strategy Evidence Graph, comparison validity, Optimization Memory, and a bounded Robustness Pack representation.

Purpose: make evidence explicit, comparable, and reusable.

### QI-3 — Market Context

Start with deterministic, market-native dimensions: trend, volatility, momentum, session, and market structure. Defer larger macro/external ingestion until the internal state model is validated.

Potential later dimensions include cross-asset state, liquidity proxies, risk, macro, and event context.

### QI-4 — Historical Context / Time Machine

Candidate scope: Historical Regime Episodes, Regime Coverage, Historical Stress Library, historical-state similarity, OOD awareness, and evidence-gap-driven historical experiments.

### QI-5 — Forward Intelligence

Consume accepted Forward-Test evidence when available. Candidate analyses include backtest-versus-forward, regime-adjusted forward gap, trade-frequency drift, drawdown drift, cost/slippage drift, strategy decay, and market-change versus alpha-degradation decomposition.

### QI-6 — Portfolio Intelligence

Consume only strategies satisfying future Portfolio Eligibility. Candidate diversification dimensions include return correlation, drawdown correlation, Strategy DNA similarity, regime dependency, symbol exposure, currency/asset exposure, session exposure, direction exposure, and risk-mechanism similarity.

Candidate outputs include hidden concentration, portfolio stress, contribution attribution, portfolio health, and portfolio drift.

### QI-7 — Internal Strategy Catalog / UI

Build only after the underlying knowledge and evidence systems exist. Potential search dimensions include strategy family, symbol, timeframe, lifecycle, preferred/failure regime, evidence state, forward status, structural similarity, and portfolio eligibility.

The catalog is a discovery surface with no production authority.

## Dependency order

```text
QI-1 Identity / Experiment
  -> QI-2 Evidence
       |\
       | +--> QI-3 Market Context -> QI-4 Historical Context
       |
       +----> accepted Forward-Test evidence
                    |
QI-4 ----------------+--> QI-5 Forward Intelligence
                              -> QI-6 Portfolio Intelligence
                                   -> QI-7 Catalog / UI
```

This is a dependency model, not accepted implementation scheduling.

## Foundational objects — candidate only

### Strategy Record

Possible fields: `strategy_id`, `strategy_version`, family, implementation identity, source identity/SHA, symbols, timeframes, thesis, components, preferred regimes, failure conditions, parent strategy, and lifecycle status.

### Experiment Contract

Possible fields: `experiment_id`, experiment type, hypothesis, strategy ID/version, test scope, parameter scope, primary metrics, guardrails, acceptance conditions, required evidence, source/reason, and lifecycle status.

### Experiment Result

Possible fields: experiment ID, run/evidence references, verdict, and verdict reason. Candidate verdict concepts: `ACCEPTED`, `REJECTED`, `INCONCLUSIVE`, `INVALID`, and `SUPERSEDED`.

These are conceptual fields only. No schema or vocabulary is frozen.

## Key design principles

1. Evidence is version-specific.
2. Summary objects never replace underlying receipts or evidence.
3. Negative and failure evidence is durable knowledge.
4. Backtest duration is not equivalent to evidence coverage.
5. A good backtest is not equivalent to a robust strategy.
6. Workflow sequencing grants no execution authority.
7. Regime intelligence begins as analytics, not automatic control.
8. Portfolio diversification must go beyond return correlation.
9. Market and strategy uncertainty must be represented explicitly.
10. Deterministic/local computation should precede model reasoning where possible.
11. Future model calls should reuse Strategy, Experiment, and Evidence records rather than rediscovering history.

## Explicitly deferred

- Autonomous trading agents.
- Automatic strategy enable/disable.
- Automatic risk changes.
- Automatic capital allocation or portfolio rebalancing.
- Automatic DEMO/LIVE promotion.
- Automatic production deployment.
- Commercial marketplace.
- Uncontrolled EA generation.
- Autonomous macro-driven trading.

Any future authority-bearing capability requires separate governance and owner authorization.

## Current priority and authority

```text
CURRENT PROJECT PRIORITY:
VPS DEMO Deployment / Forward-Test

QUANT INTELLIGENCE:
PREPARED FUTURE ARCHITECTURE TRACK

IMPLEMENTATION AUTHORITY FROM THIS DOCUMENT:
NONE
```

The current queue and milestone are unchanged. This document creates no implementation order.

## Source and composition rule

Detailed discovery provenance belongs in [WOBR_PLATFORM_DISCOVERY.md](WOBR_PLATFORM_DISCOVERY.md). Future candidate layers must compose with accepted EA_LAB infrastructure and must not replace the Router, Executor, Authorization Kernel, Controlled Backtest, Controlled Optimization, accepted governance, or accepted proof/receipt architecture.

Allowed future behavior for separately accepted discovery features is limited to: **OBSERVE, ANALYZE, INDEX, COMPARE, PROPOSE, and SIMULATE**. No authority is gained from appearing in this plan.
