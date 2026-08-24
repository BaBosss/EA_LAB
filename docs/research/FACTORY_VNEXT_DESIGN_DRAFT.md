# Factory / Template vNext Design Draft

> **STATUS: DESIGN-FROZEN FOR MVP PILOT IMPLEMENTATION — NON-CANONICAL FOR CURRENT FACTORY POLICY.** Owner-approved design direction consolidated on 2026-08-24. This file is the durable implementation design source for the vNext sidecar pilot, but it does not replace current verdict/optimization/risk/deployment rules until a later explicit policy migration is accepted and reviewed.
> No LIVE/deployment/trading action, runtime attachment, risk/default numeric change, or owner attestation is created by this document. Later sections marked `SETTLED` supersede earlier `OPEN` wording where they cover the same design question.

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

## 21. DESIGN FREEZE ADDENDUM — accepted 2026-08-24

This section freezes the post-draft discussion for the MVP pilot. Labels mean:
- `SETTLED`: implementation design is fixed unless a real pilot defect proves the assumption wrong.
- `PROVISIONAL`: architecture is fixed but numeric thresholds/defaults require calibration from pilot evidence.
- `OWNER-RESERVED`: no implementation may choose the value without explicit owner approval.
- `FUTURE`: intentionally outside the MVP pilot and not a blocker.

### 21.1 Identity and authority — SETTLED

Do not state that an EA is simply “good”. Primary research quality/verdict is home-specific.

`HomeContract = Concept/Strategy x LogicalSymbol x ExecutionTF`, with locked MTF/context architecture recorded in the contract. Auxiliary/safety TFs do not redefine the ExecutionTF anchor.

Identity layers are distinct:
1. Concept / strategy family;
2. HomeContract;
3. Profile (`BALANCED`, `SAFE`, `MAX_EDGE`, or a home-specific equivalent);
4. Broker / execution environment;
5. Deployment binding.

A home report is the primary evidence unit. Concept roll-ups are portfolio/research summaries only and never substitute for home-specific evidence. Broker suffixes map through `LogicalSymbol`; for example broker-specific `XAUUSDm` can map to logical `XAUUSD` without creating a new concept.
All run/report/profile artifacts must trace to `HomeContractID`, `LogicalSymbol`, `PhysicalSymbol`, `ExecutionTF`, `ProfileID`, `ParameterSetID`, and `RunID`. Missing Symbol/TF/Home identity makes the evidence invalid for grading.

If runtime/test identity does not match the validated Home, display `OUTSIDE_VALIDATED_CONTRACT`; do not inherit the validated Grade/PASS label. Parameter sets are home/profile-bound unless a separate portability experiment proves otherwise.

Every owner-facing report page keeps a visible identity header such as:
`Strategy | LogicalSymbol | ExecutionTF | Profile | Broker/Data | WindowContractID`.

### 21.2 Test-window doctrine — SETTLED architecture / PROVISIONAL numbers

Use three separate evidence dimensions rather than pretending time, bars, or trade count are interchangeable:
- calendar time = regime/history coverage;
- execution bars/signals = opportunity/information coverage;
- closed trades or baskets = outcome coverage.

Use the **ExecutionTF** as the bar-count anchor. Context/MTF/shock TFs do not change the anchor.

Window classes:
1. `DISCOVERY`: compute-normalized, fast enough for Home/architecture screening;
2. `COMMON_VALIDATION`: calendar-normalized, same start/end dates for finalist comparisons;
3. `EXTENDED_VALIDATION`: strategy/TF-appropriate longer history for final confidence/regime coverage.

Different `WindowContractID`s are not directly comparable for ranking unless the comparison contract explicitly normalizes them. MAIN/BWD/Holdout remain calendar blocks; BWD/holdout must not become iterative tuning surfaces.
Provisional discovery/extended targets for calibration, not canonical kill thresholds:

| Execution TF | Discovery target | Extended validation target |
|---|---:|---:|
| M1 | ~3 months | ~1–2 years |
| M5 | ~6 months | ~2–3 years |
| M15 | ~1 year | ~3 years |
| M30 | ~1–2 years | ~3–4 years |
| H1 | ~2–3 years | ~4–5 years |
| H4 | ~3–5 years | ~5–8 years |
| D1 | ~5 years | ~8–10+ years |

Runtime/compute cost is first-class evidence. Record tester model, bars, runtime, pass count and empirical seconds-per-work-unit so future range contracts can forecast cost. Do not weaken tick/execution realism merely to make a tick-sensitive strategy faster.

### 21.3 Sample adequacy and KINT-001 resolution direction — SETTLED direction / PROVISIONAL thresholds

Replace the design assumption of one universal trade-count kill rule with a profile-relative **Sample Adequacy Contract** built from:
- Time Coverage;
- Opportunity Coverage (bars/signals);
- Independent Outcome Coverage (trades for single-position systems, baskets for recovery/grid);
- Regime Coverage;
- Evidence Quality / telemetry completeness.

Strategy sampling class and ExecutionTF both matter. A slow H4 trend system with long multi-regime history can have stronger confidence than a two-month M1 system with many correlated trades.
`KINT-001` remains operationally OPEN until the later canonical policy-migration milestone removes/reconciles the conflicting active rule surfaces. The MVP sidecar may calculate the new confidence model, but it must not silently override current canonical verdict policy.

Profit/outcome concentration and clustering may reduce confidence even when raw trade count is large. Missing evidence lowers confidence/completeness; it is not automatically negative strategy evidence.

### 21.4 Grade/status model — SETTLED architecture / PROVISIONAL thresholds

Keep four top-level axes separate:
- `VERDICT = INVALID | FAIL | PARK | PASS`;
- `QUALITY_GRADE = A | B | C | D`;
- `EVIDENCE_CONFIDENCE = A | B | C | D`;
- `BUILD_POTENTIAL = HIGH | MEDIUM | LOW | EXHAUSTED`.

Metric status vocabulary:
`STRONG | GOOD | WATCH | WEAK | FAIL | UNTESTED | N/A`.

Core quality categories are Edge, Parameter Stability, Regime Robustness, Risk/Tail, Execution Robustness and Broker Portability. Recovery/Hedge Safety is mandatory only when that capability is active. Portfolio/Diversification Value is a later composition dimension and must not rewrite standalone strategy quality.

Use **critical-floor/cap logic**, not a simple average. A severe tail/execution failure cannot be hidden by high Edge/Stability scores. Optional module weakness normally disables/reworks the module rather than killing the base strategy.

A 0–100 score may be derived for visualization/ranking, but **Grade + Critical Floors + Evidence Confidence** control decisions. A one-point score boundary must never by itself promote or kill a strategy.

Every weak category must emit `STATUS -> WHY -> ACTION`, with an optional `DO NOT` instruction to prevent unrelated re-optimization.
### 21.5 Range Generator — SETTLED algorithm / PROVISIONAL numeric defaults

Range generation is semantic and stage-adaptive. **Step size is not an intrinsic property of the parameter; it is a property of the current search stage.** There is no universal `0.25 ATR` step or universal min/max that applies to every strategy.

Required inputs include ParameterName, Role, SemanticType, Unit, StrategyFamily, ExecutionTF, LogicalSymbol, Stage, current hypothesis, allowed domain, safety ceiling, activation condition and coupling group. Unknown semantics => `BLOCKED / SEMANTICS_REQUIRED`; do not guess a range.

Semantic types include at least: period/lookback, threshold, normalized multiplier, distance/spacing, count/depth, progression factor, enum/mechanism, time/session, MTF relation, boolean/policy, ordered pair and percentage/ratio.

Search stages:
1. `COARSE`: normally 3–7 sparse values per parameter; coverage first, not decimal precision;
2. `REGION_SELECT`: plateau, neighbors, boundary, unsafe region and sample checks;
3. `REFINE`: denser values only inside an accepted region;
4. `SENSITIVITY`: perturb selected region/point to test fragility.

Example only: a wide GridSpacingATR hypothesis may legitimately span `2–8 ATR`; a coarse pass can sample `2,3,4,5,6,8`, then refine only the region supported by the surface. A `0.25 ATR` increment belongs only to a later fine/sensitivity stage when justified.

Prefer normalized distance semantics (ATR, price %, tick-size-aware scale) to raw broker points. Range width must follow strategy hypothesis/home behavior; tight mean-reversion and wide recovery grids need not share the same spacing domain.
Recovery parameters are coupled. GridSpacing, MaxLevels, progression geometry/factor, basket exit and exposure envelope must not be optimized as unrelated knobs. Geometry family is tested before fine factor tuning. Hard safety ceilings are never auto-expanded; a boundary hit at a safety ceiling returns `SAFETY_LIMITED / STOP_AUTO_EXPANSION`.

Default optimization width is small (normally <=4 active parameters) unless an explicitly coupled family justifies more. Ordered/coupled constraints are enforced before dispatch so invalid combinations never consume tester time.

Boundary actions are deterministic: `CENTERED -> FREEZE/ACCEPT`, `UPPER_BOUNDARY -> EXPAND_UP_ONCE`, `LOWER_BOUNDARY -> EXPAND_DOWN_ONCE`, `SAFETY_BOUNDARY -> STOP_AUTO_EXPANSION`. Repeated same-boundary expansion, no plateau after bounded searches, sample collapse, or immaterial improvement trips a loop breaker rather than widening forever.

The generator must estimate passes and runtime before launch from empirical run telemetry. It may split a search phase when projected runtime is excessive. Numeric time budgets remain provisional until calibrated.

### 21.6 Visual Report Spec — SETTLED architecture

The owner-facing report is graph-first and home-specific. The intended reading goal is to understand strategy character, drawdown behavior, loss clustering, robustness and next action in roughly 20–30 seconds before drilling into numbers.

Five pages are frozen for MVP design:
1. **Overview** — identity, quality/confidence/verdict/build-potential, equity/balance, underwater DD, trade/SL timeline, calendar heatmap, compact optimize plateau view, regime strip, evidence-coverage card and concise diagnosis/action;
2. **Trade Diagnostic** — MFE/MAE, giveback, SL clusters, streaks, holding time, long/short split, entry timing, context contribution and conditional basket/hedge diagnostics;
3. **Optimization** — heatmap/surface, selected plateau center, neighbor stability, boundary pressure, parameter persistence, sensitivity and sample/runtime overlays;
4. **Risk / Recovery / Hedge** — gross/net exposure, basket depth, exposure acceleration/convexity, recovery duration/tails, level contribution and hedge lifecycle;
5. **Context / Regime / Broker** — regime matrix/timeline, News/Macro/Shock/SR/MTF/PA contribution, broker specification/cost/spread/slippage transfer evidence.

Every displayed metric carries raw value where available plus `Status`, optional Grade, evidence label, WHY and ACTION. Scores/Radar charts are navigation/ranking aids only; they do not replace critical-floor logic.

Concept overview, Home report, Cross-Home comparison, Profile comparison and Broker-transfer views are separate. Cross-Home ranking requires a comparable WindowContract. Aggregating equity across homes is a Bundle/Portfolio act and is forbidden unless an explicit allocation/composition contract exists.

Evidence coverage is visible: calendar span, ExecutionTF/bars, signals, trades/baskets, regimes, tester model/data source and runtime. Missing legacy dimensions display `UNAVAILABLE/UNTESTED`, never an invented neutral score.

### 21.7 Telemetry / Evidence Schema — SETTLED V1 direction

Raw evidence precedes interpretation. A grading metric must trace back to immutable run identity and raw/derived evidence; AI text is never raw fact.

Mandatory identity chain: `ConceptID -> StrategyVersion -> HomeContractID -> ProfileID -> ParameterSetID -> RunID`. Run manifests also record source/build hash, logical/physical symbol, ExecutionTF/context TFs, broker/data environment, WindowContract, tester model, start/end, bars, runtime and parameter snapshot hash.

V1 raw families are `SIGNAL_EVENTS`, `TRADE_EVENTS`, `CONTEXT_EVENTS`, `OPTIMIZATION_PASSES`; `BASKET_EVENTS` and `HEDGE_EVENTS` are capability-conditional. Signals blocked by filters must be recorded with standardized reason codes, not discarded. Recovery outcome counts use baskets rather than raw child orders.

Trade evidence supports deterministic MFE/MAE, time-to-extrema, holding time, giveback and exit reason. Context evidence separates raw features from derived regime labels and records classifier/source versions. Broker evidence separates logical instrument from broker symbol and records tick/volume/cost constraints.

Evidence labels are `MEASURED | DERIVED | SIMULATED | INFERRED | UNTESTED | UNAVAILABLE`. Schema/calc versions and artifact SHA256 references are required for accepted evidence bundles. Large raw telemetry stays outside Git where appropriate; Git stores durable manifests/summaries/hashes rather than bloating canonical history.

Progressive evidence manifests apply by lifecycle: SCREEN is lightweight; OPTIMIZE adds surfaces/runtime; ROBUSTNESS adds BWD/MC/holdout/cost stress; CANDIDATE requires fuller telemetry/portability; DEMO adds measured runtime/fill/spread/slippage identity evidence.

### 21.8 Migration architecture — SETTLED

No big-bang rewrite. Build a non-authoritative vNext sidecar beside the existing Factory, prove it, then migrate policy deliberately.

Order of introduction:
1. HomeContract + WindowContract + Run Manifest;
2. Telemetry V1 and deterministic derived metrics;
3. Range Generator V1 and surface diagnostics;
4. Grade/Confidence sidecar and graph-first Visual Report;
5. one offline Strategy Tester pilot;
6. numeric calibration from accepted historical/pilot evidence;
7. canonical KINT-001/policy reconciliation;
8. gradual migration of active candidates/promising PARKED items;
9. Bundle/Meta-EA and portfolio composition later.

During sidecar phases, current canonical Factory verdict/optimization/risk/deployment authority remains unchanged. A sidecar Grade may disagree visibly with the old policy but may not silently override it.

Legacy reports are imported only for fields they actually contain. New evidence dimensions remain `UNAVAILABLE` until an explicitly justified rerun. Failed/archived EAs are not mass-rerun merely for migration completeness.

### 21.9 Numeric calibration / owner-reserved items

`PROVISIONAL`: exact PF/expectancy Grade bands, sample-adequacy thresholds, regime adequacy, meaningful-improvement floor, runtime budgets and strategy-specific Range defaults. Calibrate from accepted EA_LAB history plus pilot measurements before enforcement.

`OWNER-RESERVED`: exact risk-capacity envelopes, deployment multipliers/default risk, any LIVE/DEMO->LIVE promotion semantics, and any change that increases hard recovery/exposure ceilings.

`FUTURE`: directional news trading, options/rates external-data capabilities, Bundle/Meta-EA optimization and portfolio allocation beyond the standalone pilot.

### 21.10 Design-freeze implementation rule — SETTLED

Implementation workers must cite this file and the exact frozen Git SHA as their design source. They must not reconstruct architecture from chat memory. A real pilot defect may generate a bounded design amendment; convenience, model preference or rediscovery is not sufficient reason to drift the frozen contract.

The companion `FACTORY_VNEXT_MVP_PILOT_CONTRACT.md` defines the first executable sidecar milestone. That contract, not this narrative alone, controls MVP implementation acceptance.
