---
card_type: RESEARCH_CARD
card_id: RC-2026-FACEBOOK-HUB-001
source_id: SRC-FACEBOOK-MEMBER-HUB-20260922
evidence_depth: SOURCE_CONTEXT_PLUS_OPAQUE_FILE_IDENTITY
status: RESEARCH_ONLY
authority: RESEARCH_ONLY
---

# Facebook Member Hub — file-family and backtest qualification intake

## SOURCE_CLAIM

The bounded Facebook intake contains 124 file rows and selects 48 latest file families. Exact selected-version context was found for 19/48; 29/48 remain source-context unknown. Source-confirmed roles cover 10 trading/automated families, 4 indicators, and 5 utility/scanner families. Six SET/config files and three non-EA research artifacts are also selected.

One exact high-value source claim is `ZABgoldpending.ex5`: its source post describes a **Gold M5 breakout bot** and says the user chooses **lot or risk-percent** while other settings are prepared; demo is recommended first. This is a source statement, not a tested safety/profitability result.

## Method / context

- Input: completed `facebook-member-hub-intake-ro-20260922` evidence only; no new collection.
- Identity: 48/48 selected artifacts have SHA-256 and byte size.
- Lineage: 48 selected families reconcile against the 124-row Files inventory; ambiguous similar-name pairs remain separate.
- Cross-reference: exact selected family/file names were checked against current tracked `docs/`, `ea_template/`, `portfolio/`, `taskboards/`, and Registry names; no exact-name ownership match was found. This does not prove semantic non-equivalence.
- Performance sample: none. MT5 was not started by this intake.

## Result

Documentary qualification completed for the 48 selected latest families: `1 READY_FOR_SETTINGS_FREEZE`, `0 READY_FOR_TEST`, `9` other source-confirmed EA families remain pre-test blocked, `20` opaque EX5 families remain context-required/unknown, and `18` selected artifacts are not EA backtest candidates. This is an intake/catalog result only; no strategy performance result was produced.

## EA_LAB_INFERENCE

Backtest qualification is intentionally conservative: `1 READY_FOR_SETTINGS_FREEZE`, `0 READY_FOR_TEST`, `9` other source-confirmed EA families blocked on semantics/context/version compatibility, `20` opaque EX5 families still context-required/unknown, and `18` selected artifacts classified as not-EA for the EA tester mainline.

The first prospective family is `ZABgoldpending`, but its exact broker symbol, owner risk mode/value, exact input surface/default values, tester/build/account identity, MAIN/BWD windows, and data/cost assumptions are not frozen. Internal entry/exit/MM details beyond the source-level breakout + lot/risk claim remain unknown.

## Confirmed EA queue

- `DynamicGrid`: `SEMANTICS_REQUIRED` — v12 exact post plus family post describes Grid + Martingale bot
- `PairsTradeEA_MultiAuto`: `SEMANTICS_REQUIRED` — exact post says automatic selection of advantageous pair
- `RiskPerTradeสอบกองทุน`: `SEMANTICS_REQUIRED` — exact post says one-position EA with configurable risk for prop-style use
- `CloseSystem`: `VERSION_COMPATIBILITY_REQUIRED` — family post describes user-defined zone/count/distance/TP without Martingale; older V10 Gold HFT and Oil set posts exist
- `ZoneRecovery3`: `SEMANTICS_REQUIRED` — exact post identifies Zone Recovery bot
- `HybridHedgingGold`: `CONTEXT_REQUIRED` — family post describes hybrid Grid + Hedge + Close System
- `GoldRushBreakout`: `CONTEXT_REQUIRED` — family post describes precision single-trade bot; separate group post references Gold Rush 3.2 settings video
- `ZABStochGoldRecoveryEA`: `SEMANTICS_REQUIRED_HIGH_RISK_MM` — exact V4 post names trend filter and recovery lot and warns doubling after loss
- `lootv3`: `SEMANTICS_REQUIRED` — exact post identifies lot-building bot; buy emphasis in rising product; 0.0075 distance example
- `ZABgoldpending`: `READY_FOR_SETTINGS_FREEZE` — source post says breakout bot for Gold M5; lot or risk-percent configurable; defaults otherwise prepared

## Limitations / contradictions

- Facebook claims can include performance, risk, or setup language; none becomes EA_LAB tested evidence without a separately frozen contract.
- EX5 is opaque; filename and static strings cannot prove exact behavior or absence of grid/martingale/hedge logic.
- Four possible family relationships remain unresolved and are not deduped automatically.
- Old SET files cannot be attached to selected newest EX5 builds without lineage + input-surface proof.
- Same-method Facebook name/context search is saturated; repeated identical collection is negative-value work unless a new source method or explicit new post is supplied.
- Full historical completeness of the Facebook group remains unknown.

## Backtest readiness

`ZABgoldpending`: `READY_FOR_SETTINGS_FREEZE` only. All other confirmed EAs remain pre-test blocked. No selected family is `READY_FOR_TEST` yet.

The first lawful test, after settings/identity/window/data freeze, must be fixed-config qualification. Optimization is not opened by this card; HOLDOUT remains protected and undiscovered.

## Links

- Source note: `knowledge/01_sources/FACEBOOK_MEMBER_HUB_SOURCE_NOTE_20260922.md`
- Human catalog: `knowledge/10_synthesis/FACEBOOK_MEMBER_HUB_EA_FAMILY_CATALOG_20260922.md`
- Machine-readable qualification: `knowledge/10_synthesis/FACEBOOK_MEMBER_HUB_BACKTEST_QUALIFICATION_20260922.json`

This card creates no EA implementation, ExperimentContract, MT5 run, optimizer, Grade/KINT/Candidate, risk/default, runtime, deployment, DEMO/LIVE, or trading authority.
