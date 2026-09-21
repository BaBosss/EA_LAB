# News / Macro Lab V1 — integration and unbiased replay preparation

**Scope: LOCAL SOURCE PREPARATION, independent review pending. No MT5, performance or runtime acceptance.**

Owner requested on 2026-09-21: combine existing NewsGuard/MacroGate, global and regional macro context, the existing Monitor, optional Jev/Laya text interpretation and bias-controlled backtests. Codex is temporarily unavailable by owner report. This stage makes deterministic progress without any provider invocation.

Base observed through isolated fetch + ls-remote: `24b463395356f422d6ae6885e9cf148b63e27b69`.
Lane `ct-news-macro-lab-v1-20260921` is a scoped author, **not** a replacement Main Control Tower. Source paths: `tools/news_macro_lab/` and this document. No existing source or runtime surface is modified.

## 1. Reuse and non-overlap

`tools/knowledge_validation/offline_replay_validator.py` remains the revision/available-at selector. This library byte-pins and calls it; it does not create a second selector. CC02 `tools/control_center/guard_adapters/feeds.py` remains the existing historical guard-feed projection. `EA_REGIME_FRAMEWORK.md` owns regime vocabulary and research rules. The historical macro source and broker clock contracts remain controlling.

The existing Monitor stays the only product: `D:\OneDrive\Monitor\OPEN_MONITOR.cmd`, `News & Macro`. Fresh Registry observations found `ct-monitor-liveperf-v1-20260921` writing `tools/mobile_report_hub/owner_webapp`; this lane does not write there or into the installed app. A later accepted data/UI increment goes through that owner (refresh ownership before action). Writing this handoff does not notify or stop another chat.

Do not repair DailyMonitor runtime drift, change its scheduler, mutate NewsGuard REAL policies, activate RegimeOnly transport or reinstall Monitor as a side effect. Upstream generation, local staging, VPS delivery, watchdog liveness and EA effectiveness are distinct evidence stages.

## 2. What is implemented in this stage

The Python library has an explicit-UTC, raw-snapshot-hash checked bridge to the canonical selector. It produces calendar-window contacts from the latest schedule revision known at each decision; revised/cancelled future events cannot rewrite earlier decisions. Tentative/missing coverage is UNKNOWN. A contact interval is left-closed/right-open and its pre/post lengths and relevant currencies are mandatory inputs: **not current NewsGuard policy/parity**.

The macro reader accepts only caller-supplied immutable MRIS states in a fixed classifier lineage. It withholds future, stale and expired states and does not turn missing data into NEUTRAL. It never calculates a new global regime or presents MRIS agreement as a probability.

The price feature function computes relative-to-mean price, trailing return and unannualized log-return sample deviation on visible completed closes. Instrument, currency, price-vs-total-return convention, sample count and freshness contract are explicit. These descriptive features are **not** a newly approved risk model. Negative/zero prices are unsupported and refused (important for some futures histories); a separate transform contract is necessary for those series.

The global source inventory maps proposed and existing sources to regions and factor axes, with dependency groups to expose overlap. It emits an UNKNOWN readiness map, not fictional country regimes. Source presence, source-data truth and historical data qualification remain different.

The experiment preflight detects missing receipts, overlapping MAIN/BWD, unfrozen placebo seeds, multiple logical changes, attempted BWD tuning/optimization or HOLDOUT leakage. Even fully filled hash fields are only declarations: **receipt hashes are not signatures or independent acceptance**. It cannot launch a run.

The provider-neutral text annotation validator byte-binds input/model/prompt/label specification and checks explicit abstention and typed label scores. There is no Jev/Laya API adapter, installation, inference, cost, calibration or historical predictive-OOS claim.

## 3. Full dependency plan

`WORKPLAN.json` contains the dependency graph. Finish local tooling and deterministic checks -> exact frozen source -> separate independent review -> eligible normal integration. In parallel, prepare the first finite historical data contract and the Monitor owner handoff, without activating either. Native guard parity depends on source qualification, exact broker clocks, a registered core owner and tester reservation. Only then freeze and execute performance A/B. Data failure blocks the dependent stage, not unrelated documentary work.

No guessed percentage-complete figure is used. Scope closure is not pipeline completion.

## 4. Global economy vs financial market conditions

Use distinct axes for growth, inflation, policy, liquidity, credit, equities and carry. Keep countries and regions distinct. Regional equity prices are market evidence, not GDP, and US/global/sector indexes overlap. An index price in local currency differs from its USD or total-return version. Euro-area coverage differs from Europe; a broad global market-cap basket is not an equal-country or GDP-weighted economy.

AUDJPY is one candidate input, not the world state. Existing US10Y-only proxy must not be relabelled a measured US-minus-Japan yield spread. Credit-proxy ratios can embed rate duration. No new weights, thresholds, percentile lookbacks, growth labels or region-to-global aggregation are silently assigned here.

Source catalog candidates must first freeze series/instrument identity, geography, observation convention, provider/licence, release/first-available clock, revisions, holidays, currency and completeness. Correlated sources are not independent votes. Price feature denominators include only eligible visible observations, and a missing region stays missing. Global equity breadth, macro growth and news tone must not share one unexplained confidence number.

## 5. Point-in-time contract and known-source boundaries

Reuse the canonical ALFRED value/vintage + originating-agency release-clock contract. The existing PAYEMS receipt covers a bounded two-decision selector exercise only; it does not qualify all US data, other countries, Exness server clocks or EA replay. A current calendar CSV with upcoming times does not prove when each schedule, cancellation, importance, forecast or revision was historically known.

Preserve raw source bytes, request identity, fetch time (separate from availability), release clock evidence, versioned timezone/DST mapping, revisions, normalization derivation and coverage. This library checks supplied bytes and structural time ordering, **not** whether a vendor's declared coverage is factually complete or whether transformed values accurately derive from the raw response. Those are independent dataset-acceptance gates.

At each decision use only data available then, plus the latency defined for that route. Do not backfill current revisions, midnight-stamp daily closes or mix Japanese and US closes merely because the calendar date matches. A planned after-release action cannot occur before the actual source availability and processing latency. Revised/withdrawn schedules need event identity and revision lineage. COMPLETE_NO_EVENTS is different from failure/unknown/tentative.

## 6. Native backtest path (NOT EXECUTED)

Reuse the existing `_MG_SelfGate` and NewsGuard core where applicable; do not create parallel decision logic and call it parity. The native owner must freeze new-market entries, add-ons, pending placement, pre-existing pending fills/cancellation, hedge/recovery, closes, TTL/fail-open behavior, restart and persisted-halt semantics. BLOCK_NEW is not equivalent to canceling pending orders or closing risk. Unsupported/locked EAs cannot be assumed to consume the bridge.

Stage 1: mechanics-only native fixtures with contact and action counts, exact tester build/install, EA/EX5/set/source hashes and broker-clock mapping. Stage 2: freeze an eligible exact parent/Home/config and one-change comparison. Stage 3: fixed MAIN and BWD using the same source/data/install and no tuning between arms. Model1 is only the minimum research model; high-impact news microstructure may need Model4 real ticks plus source-qualified spread/fill/slippage assumptions. Model4 does not by itself reproduce every real fill. Primary M4 installation remains `D:\Meta 5`; never infer another installation is qualified.

No existing B11, Boss19, B16 or other closed/exhausted experiment is reopened by this plan. No parent is selected from attractive prior results. No hypothesis-specific evaluation threshold is invented to obtain a pass.

## 7. Bias controls and comparison design

Freeze the eligible EA cohort, change, data windows, classifier definition, calibration slice, sources, placebo design/seeds, primary metric, meaningful-effect/falsifier rule and reporting set **before** observing the new experiment outcomes. Preserve all attempts and reasons for exclusion. Historically inspected windows are not magically new holdouts.

Start with base vs fixed NewsGuard; separately base vs current-rule MacroGate. Enhanced global rules and text interpretation are later one-change hypotheses. A combined filter is a later declared interaction study, not evidence that either individual mechanism works.

Use a preregistered placebo construction that preserves relevant session/weekday/event-duration clustering while disrupting the proposed timing relationship. Report all fixed seeds, not a favorable one. Equal scheduled contact time is **not** equal achieved exposure, entry opportunity, turnover or tail risk. Describe those differences and uncertainty explicitly. No automatic significance verdict follows from one real arm beating one placebo arm.

Rerun each arm in the same full strategy engine. Deleting blocked or losing trades from an existing ledger is invalid for path-dependent grid/recovery/basket systems. Evaluate basket/episode units and clustered uncertainty where appropriate, not ticket-level independence. Do not stitch profitable windows into a fictitious continuous strategy.

Report net, PF, precisely defined equity DD/tails, participation, baskets/episodes, time in market, attempted/blocked entries, distinct news/guard firings, pending effects, aggregate exposure, hard kills, year/regime splits, data coverage, transaction economics and lineage. No firings means the event-action mechanism is UNTESTED. Identical results alone do not establish whether code was inert: inspect actual branch/action evidence. Reduced DD with reduced exposure is not automatically timing value.

BWD is fixed validation, not tuning. HOLDOUT is protected by the exact current family/owner contract. Stop on data/mechanical failure as evidence-incomplete, not strategy failure. Preserve the historic MacroGate AUDJPY pin defect and corrected negative result. A change in state counts alone is not a generic bug detector: use causal invariants and source-grounded expectations, never hardcode 82/47 as a universal acceptance test.

## 8. AI shadow and hindsight

Jev/Laya may later annotate texts into a frozen schema. A valid probability simplex is not evidence of calibration, economic correctness or win probability. Establish labels independently of the EA PnL; measure task-specific performance/calibration and abstention on a temporally separated dataset. Keep deterministic baselines and report incremental value, costs and disagreement. No fixed tier/score floor is added here.

A modern pretrained model may already know historical event outcomes. Timestamping a prompt correctly does not remove training contamination. Pin model/checkpoint/training disclosure where available; historical classifications are exploratory when that cannot be excluded. Prospective shadow collection after model freeze is the stronger next check. Do not distill hindsight into a regime used to claim historical prediction. No provider is invoked in this stage.

## 9. Existing Monitor integration contract

The existing `News & Macro` page is the only UI home. Proposed data sections: Calendar/source health; MRIS observation; Global/regional readiness and later qualified factors; NewsGuard A/B; MacroGate A/B; EA x Regime. This document does not install those new tabs.

Always distinguish **requested policy -> effective configuration -> input/feed evidence -> actual EA action**, with source/observation age, hash and authority. Missing runtime evidence remains UNKNOWN even when the calendar is current. Required future runtime evidence includes exact account/magic/build/config/feed binding, effective time/window, policy state, watchdog heartbeat/expiry and observed action journal. A feed hash or running process alone is insufficient.

Synthetic mechanics results must never be displayed as live news, live regime, performance, guard health or an Alpha panel. Source preparation must never auto-populate a financial win-rate/DD graph. Report native equity UNAVAILABLE until supplied by accepted real runs. Screen refresh rereads evidence; it does not assert a new source fetch.

## 10. Review and closure

No external model calls, no paid fallback, no retry loop seeking quota, no review-budget reset. Separate exact-head GPT Scrutiny remains pending while suitable review capacity is unavailable. Author tests are not independent acceptance. Final remote/canonical SHA, local head, tests, manifest and blockers are recorded in the external evidence receipt. Only the normal controller can integrate and then ask the existing Monitor owner to wire an accepted data increment. No automatic runtime activation follows.

### Checked primary references (2026-09-21)

- ALFRED help: https://alfred.stlouisfed.org/help — vintage data and availability limits; not an intraday source-clock waiver.
- MetaQuotes MQL5 Book: https://www.mql5.com/en/book/advanced/calendar/calendar_cache_tester — tester calendar cache and historical timezone handling.
- OECD CLI: https://www.oecd.org/en/data/datasets/oecd-composite-leading-indicators-clis.html — multi-country business-cycle indicators and revisions snapshots, candidate only.
- BIS effective exchange rates: https://data.bis.org/topics/EER — source candidate, no ingest/qualification performed.
- MSCI ACWI: https://www.msci.com/indexes/index/892400 — index identity; no free dataset/redistribution licence inferred.
- TypeSafe Jev: https://typesafe.ai/blog/introducing-system-one-models-and-jev — vendor description of typed outputs; not EA_LAB model qualification.
