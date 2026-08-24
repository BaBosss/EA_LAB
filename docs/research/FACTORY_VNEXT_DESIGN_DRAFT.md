# Factory / Template vNext Design Draft

> **STATUS: NON-CANONICAL DESIGN NOTE.** Consolidates the owner-approved design direction discussed on 2026-08-24. It does not replace current verdict/optimization/risk/deployment rules until a later explicit policy migration is accepted and reviewed.
> No LIVE/deployment/trading action, risk/default numeric change, or owner attestation is created by this document.

## 1. Core design principles

1. A concept is not limited to one EA file or one `.set`; it can have multiple home cells and multiple legitimate configuration profiles.
2. Separate **edge evidence**, **quality/robustness**, **lifecycle**, **deployment binding**, and **portfolio allocation** instead of compressing them into one verdict.
3. Prefer deterministic measurement and staged experiments over broad genetic search or post-hoc storytelling.
4. `FAIL` must mean negative evidence or fatal structure; missing/inadequate evidence is `INVALID/RETEST` or `PARK`, not a fake failure.
5. BWD, Monte Carlo, holdout and execution realism characterize confidence/risk; they do not automatically erase a valid current-regime edge.
6. The template is a **capability library**, not an EA monster. A candidate activates only the capabilities it needs.
7. There is no hard maximum number of modules. Add a module only for a diagnosed reason and require contribution evidence after adding it.
8. ThinkMarkets is the primary rich-history research environment; Exness Cent is the intended deployment environment. Strategy semantics must not depend on broker naming conventions.

## 2. Outcome model

Use separate axes:
- `VERDICT = INVALID | FAIL | PARK | PASS`
- `LIFECYCLE = SCREEN | HOME_DISCOVERY | OPTIMIZE | ROBUSTNESS | CANDIDATE | DEMO | LIVE`
- `GRADE = A | B | C | D` for quality/confidence after valid evidence exists.
- `BUILD_POTENTIAL = HIGH | MEDIUM | LOW | EXHAUSTED` for whether a weak/currently marginal concept is worth further bounded development.

### Grade dimensions

Assess at least: Edge Strength, Parameter Robustness, Regime Robustness (BWD), Tail/MC, Execution Robustness, Recovery Risk when applicable, Context/Protection contribution when applicable, Broker Portability, and Portfolio/Diversification Value.

Critical-floor direction:
- invalid evidence => no grade yet;
- fatal unbounded/unknowable structural exposure => FAIL/D;
- realistic execution proving a fill artifact/no executable edge => FAIL/D;
- weak BWD => downgrade/regime-specialist label, not automatic kill;
- weak MC => lower risk capacity if resizing works; fail only when minimum practical exposure is still structurally unacceptable;
- an optional module that performs badly should normally be disabled/reworked rather than killing the base edge.

`BUILD_POTENTIAL` must be evidence-backed. Useful signals include a plausible mechanism, near-edge cells/sides/regimes, low drawdown/risk efficiency, non-spike surface structure, and meaningful unexplored levers. A fully explored uniformly poor surface can become `EXHAUSTED`.

## 3. Home discovery: Symbol, TF and MTF

After a concept sanity check, run a broad but cheap **Home Discovery** across eligible symbols and strategy-appropriate timeframes using one neutral/central parameter set. Do not optimize every symbol/TF immediately.

A home cell is `Concept x LogicalInstrument x ExecutionTF x Architecture`.

- Treat TF as a discrete architecture experiment, not an integer optimizer input.
- Screen TF families appropriate to strategy class; do not blindly test every TF.
- A concept may have multiple valid homes and home-specific parameters.
- A multi-symbol sparse strategy is legitimate if each home instance is independently attributable and risk-capped.
- Multi-TF begins with a single-TF baseline, then bounded relationship tests (for example execution TF plus a slower confirmation/regime TF), then parameter optimization only after the architecture is locked.
- Full multi-TF signal-fusion architectures are separate strategy components, not a hidden toggle inside the original component.

## 4. Configuration and deployment profiles

One home can retain more than one legitimate plateau/profile when behavior differs materially. Examples: `MAX_EDGE`, `BALANCED`, `SAFE`, or home-specific names such as `FAST` / `RUNNER`.

Do not confuse strategy parameters with deployment sizing. `InitialLot`, account, port, magic and broker symbol are deployment/risk bindings unless changing them alters strategy dynamics (for example grid progression, basket-dollar targets, margin or kill behavior).

Identity layers:
1. Concept
2. Home Configuration
3. Strategy Component
4. Bundle / Meta-EA
5. Deployment Binding

Multiple profiles from the same concept/home are not automatically diversification. Correlation and shared-signal exposure must be recognized by the portfolio layer.

## 5. Parameter roles and optimization doctrine

Classify inputs before optimization:
- `EDGE`: entry/signal mechanics;
- `EXIT`: profit/loss realization;
- `FILTER`: conditional participation such as ADX/ER/session;
- `RECOVERY/STRUCTURE`: spacing, max levels, progression law, stack/recovery mechanics;
- `RISK_SCALE`: lot/risk sizing/allocation;
- `SAFETY`: DD kill, account protection, hard exposure ceiling;
- `IDENTITY/OPS`: magic, comments, AllowLive, runtime binding.

Optimize EDGE/EXIT/FILTER/RECOVERY only when the parameter has a causal question. RISK_SCALE, SAFETY and IDENTITY/OPS must not be used to manufacture edge.

Default staged search: concept sanity -> home discovery -> EDGE -> EXIT -> FILTER if diagnosis supports it -> RECOVERY/STRUCTURE if part of the mechanism -> limited interaction confirmation -> robustness.

Do not use BWD, MC or holdout as iterative parameter search surfaces after MAIN selection. They are quality/generalization/risk evidence. Re-tuning on them burns their independence.

## 6. Range Generator direction

Settled principles:
- range comes from domain constraints + strategy hypothesis + normalized market scale, not from whichever number won a prior optimizer;
- coarse search is intentionally sparse (typically 3-7 values per parameter) to discover zones, not decimal precision;
- default active dimensions per stage stay small (normally <=4) unless a coupled parameter family requires otherwise;
- coarse -> refinement -> sensitivity are distinct phases;
- paired/coupled parameters must enforce semantic constraints (for example Fast < Slow, TrailStep < TrailStart);
- normalized distance (ATR, price %, tick-size-aware distance) is preferred to broker-specific raw points when portable semantics are intended;
- MaxLevels and similar recovery dimensions may be explored only within a pre-approved hard safety ceiling;
- News/Macro/Shock policies are bounded A/B policy comparisons, not wide continuous genetic dimensions.

**OPEN:** exact deterministic range-generation rule table for period/lookback, threshold, ATR multiple, spacing, progression factor, enum/mechanism families, MTF ratios and refinement step selection.

## 7. Recovery / martingale doctrine

Recovery or martingale is not a structural failure by name. Failure is **unbounded or unknowable exposure**.

Legitimate bounded engine families include flat add, additive/linear, log/log-power and bounded geometric progression. Required cages include hard max depth, spacing geometry, total exposure ceiling, exit/damage mechanism and continuous-period stress evidence.

A flat-lot PF below 1 does not automatically invalidate a recovery strategy when the interaction between entry and bounded recovery geometry is the actual mechanism. The question becomes whether the added expectancy is bought with acceptable tail/gross-exposure risk.

Measure `Exposure Acceleration / Convexity`: how gross exposure changes as adverse move/depth increases. Recovery profiles must be compared on PF/expectancy **and** DD, worst basket, time underwater, gross exposure, MC/tail and execution cost.

Prefer geometry comparison before fine-tuning progression factors: Single -> Flat -> Linear/Additive -> Log -> bounded Geometric under comparable entry/exit/spacing assumptions.

## 8. Context capabilities: S/R, PA, MTF, News, Macro, Shock

Treat these as optional capabilities behind shared interfaces rather than bespoke copies inside every EA.

### Market Structure / S&R
A shared structure service should expose confirmed support/resistance, source TF, age/touches/strength, break/retest state and normalized distance. Recovery can support `DISTANCE`, `STRUCTURE`, or `HYBRID` adds; hybrid means minimum geometric spacing plus a structural location rather than blind ATR adds.

### Price Action
PA is primarily a confirmation/risk-trimming layer, not assumed to be a naked edge generator. Support optional entry confirmation and add/recovery confirmation. Add new pattern families only with isolated A/B contribution evidence.

### MTF Context
Higher-TF trend/structure may confirm, veto or reduce confidence without turning every TF into an optimizer dimension. Safety MTF (for example M1/M5 shock sensing for an H1/H4 EA) is separate from strategy MTF.

### Event / Macro / Shock
- NewsGuard: scheduled-event protection; default research focus is block new/add or cooldown rather than forced close.
- MacroGate: slower regime/risk state; may block or reduce new exposure while preserving management/exit.
- ShockGuard: unscheduled abnormality detector using robust return/range, realized-vol and spread expansion evidence; output states such as `NORMAL/ELEVATED/SHOCK/COOLDOWN`.
- Directional news flipping is **future/high-overfit-risk**; V1 protection should block/reduce/cooldown or direction-veto only when evidence supports it.

Context modules must record fire counts and A/B contribution. Zero fires means `UNTESTED`, not proof of benefit.

## 9. Hedging architecture

Hedge is a **Risk Response Engine**, not automatically an edge generator and not the same thing as an independently profitable opposite-direction strategy.

Research priorities: partial basket hedge and progressive hedge before full lock. Hedge triggers may use basket DD, structural break, MTF reversal, Macro stress or Shock state. Recovery and Hedge require explicit state/priority rules so they do not expand opposing gross exposure blindly.

Mandatory hedge measurements include net exposure, gross exposure, margin/cost, hedge-cycle count, time locked, release quality and worst combined basket. Require gross-exposure caps, no hedge-of-hedge spiral and bounded release logic. Opening the hedge and releasing it are equally important design problems.

EA-level hedge protects one component/basket. Portfolio hedge protects aggregate factor exposure; do not silently mix the two layers.

## 10. Exit architecture

Exit style is home-specific and evidence-driven. Do not predeclare that every trend must run forever or every reversal must exit quickly.

Compare bounded exit families after entry/home are sufficiently stable: fixed/RR, ATR, structural S/R, trailing, partial+runner, time exit, signal/HTF exit, basket/recovery exit and context-sensitive management.

Use MFE/MAE, time-to-MFE, profit giveback, holding-time distribution and regime behavior to decide which exit family deserves deeper search. Multiple legitimate exit profiles can coexist when they represent distinct, stable behavior.

## 11. Risk and capital allocation

Architecture: `Signal -> Risk Request -> Portfolio Approval -> Broker Lot Translation -> Execution`.

Risk layers: Trade -> Strategy -> Symbol -> Bundle -> Correlation/Factor Cluster -> Portfolio, plus margin/gross-exposure constraints.

Grade sets a **risk-capacity ceiling**, not a fixed lot. Exact numeric risk defaults are intentionally not settled in this draft and remain owner-reserved.

Recovery reserves capacity against its bounded basket envelope, not only the initial lot. Hedge consumes capacity even when net directional exposure falls because gross exposure/cost/margin remain.

## 12. Broker / instrument portability

Strategy semantics must not hard-code broker symbol names, digits, point/pip conventions, account, port or magic.

Use a logical instrument plus Broker/Deployment Profile. Example: logical `XAUUSD` may map to ThinkMarkets 2-digit gold or Exness `XAUUSDm` / `XAUUSDc` with 3 digits. Distance logic should use tick-size-aware, price, ATR or percentage semantics where possible.

Broker profiles should carry symbol mapping, digits, tick size/value, contract size, volume min/step/max, commission, swap, stop/freeze levels and spread distribution. Spread filters should prefer transaction-cost-relative measures (for example spread/ATR or spread/expected move) plus an emergency absolute ceiling rather than one raw-point threshold for every broker.

ThinkMarkets research evidence does not automatically prove Exness execution behavior. Candidate transfer requires a broker compatibility/cost/liquidity check without re-optimizing the candidate merely to make the target broker look good.

## 13. Multi-strategy / Bundle / Meta-EA

Build and prove strategy components individually first; combine frozen components later.

A Bundle may contain opposite-horizon strategies (for example long trend-following plus short reversal), multiple sparse strategies, or one concept across multiple symbol homes. Every order must retain StrategyID/Intent ownership so an independent reversal position is not mislabeled as a hedge.

Component baskets/positions/exits remain isolated. Bundle-level conflict policies (`COEXIST`, `VETO`, `REDUCE`, priority) are later composition experiments, not hidden component optimization.

Do **not** optimize all component parameter spaces jointly. Optimize components, then validate composition using correlation, co-drawdown, tail/shock overlap, factor exposure and simple bounded allocation profiles.

## 14. Measurement and evidence architecture

Use four layers:
1. Run Identity / provenance;
2. immutable event-driven raw telemetry;
3. deterministic derived metrics;
4. generated owner-facing cards/graphs.

Raw telemetry families: `TRADE_EVENTS`, `SIGNAL_EVENTS`, `BASKET_EVENTS`, `CONTEXT_EVENTS`, plus optimize surfaces and exact broker/test identity. Record blocked signals and decision reasons, not only executed trades.
Derived measurements include performance, MFE/MAE, holding/recovery time, drawdown, basket depth, gross/net exposure, exposure acceleration, realized-vol regime, skew/kurtosis/tails, signal quantile monotonicity, parameter plateau/persistence, BWD, execution robustness, MC variants and bundle correlations.

Evidence-quality labels: `MEASURED | DERIVED | SIMULATED | INFERRED | UNTESTED`. Never present a simulated broker stress result as measured live evidence.

Use progressive measurement manifests by capability/lifecycle so a simple trend screen does not pay the cost of every grid/hedge/news/bundle metric.

### Monte Carlo / stress direction
Beyond simple trade shuffle, add block/bootstrap clustering, tail amplification, cost/spread/slippage stress and regime chaining where appropriate, especially for recovery systems.

## 15. Graph-first owner reporting

The owner-facing surface is graph-first; raw numbers remain available but are not the primary decision interface.

Minimum visual set under discussion:
- Equity curve and underwater/drawdown curve;
- trade timeline with wins/losses/SL/TP and clusters;
- monthly/weekly heatmap and stop-loss cluster view;
- win/loss streak and holding/recovery duration distributions;
- MFE/MAE scatter and profit-giveback view;
- performance by volatility/trend/news/shock regime;
- optimization heatmap/surface, selected plateau and neighbour stability;
- year/window parameter persistence;
- for recovery/hedge: basket-depth timeline, gross-vs-net exposure, recovery duration and exposure-acceleration plot.

**OPEN / NEXT DISCUSSION:** exact Visual Report Spec: page-1 layout, diagnostic pages, optimize pages, recovery/bundle pages and owner interaction/drill-down behavior.

## 16. Volatility / quantitative research additions

Adopt as shared diagnostic/context ideas, not as automatic options strategies:
- realized-volatility context beyond ATR alone (OHLC/range-aware estimators where appropriate);
- robust shock detection using percentiles/robust Z, realized-vol expansion and spread state;
- fat-tail/skew/kurtosis awareness in risk/MC;
- `VOL_CHARACTER = LONG_VOL_LIKE | SHORT_VOL_LIKE | MIXED` and exposure-convexity characterization;
- persistence/quantile tests for signal strength;
- Pearson + Spearman + co-DD/tail/shock correlation for bundle selection;
- broker cost/liquidity transfer stress.

Options IV/smile/skew, rates/swap/basis and true market-neutral relative-value feeds remain future external-data capabilities, not Template V1 dependencies.

## 17. Migration strategy

Do not big-bang rewrite the repository. Build vNext sidecar capabilities and migrate proven components gradually.

Suggested sequence:
1. Visual/evidence MVP around one existing strategy without changing strategy semantics;
2. telemetry schema + deterministic derived metrics;
3. optional context/diagnostic modules;
4. migrate high-value legacy/backlog candidates by rerunning under the new evidence contract;
5. only then build Bundle/Meta-EA orchestration and portfolio allocation layers.

Historical evidence is preserved. Old reports may remain historical references, but a candidate that needs a new Grade/telemetry dimension should be rerun rather than having missing evidence invented retroactively.

## 18. Known knowledge-integrity contradiction

`KINT-001 — OPEN`: current canonical selection guidance contains conflicting sample-floor language: one active rule surface still uses a flat participation floor around 100 closed trades per window, while the optimization skill also states that strategy/TF-relative trade-count expectations replace a flat >=100 rule and separately gives TF-specific floors. Do not silently pick one. Resolve in the later Factory vNext policy migration and add deterministic enforcement only after the owner ratifies the final sample-adequacy doctrine.

## 19. Open decisions before canonical policy migration

- Exact Range Generator rule table and candidate-specific range-contract format.
- Exact Visual Report Spec and graph layout.
- Exact numeric Grade thresholds / sample-adequacy rules where numbers are needed.
- Exact overall-grade critical-floor algorithm beyond the qualitative direction above.
- Exact risk-capacity envelopes and any deployment risk multipliers (owner hard stop; intentionally unset).
- Directional news logic / live options-rates external-data capabilities remain future unless separately scoped.

## 20. Promotion rule

This draft becomes canonical only through a later explicit policy-migration milestone that reconciles at minimum the verdict gate, optimization skill, parameter registry/contract, enforcement scripts, evidence/report schemas and tests. Accepted historical evidence must not be rewritten merely to make it fit the new vocabulary.
