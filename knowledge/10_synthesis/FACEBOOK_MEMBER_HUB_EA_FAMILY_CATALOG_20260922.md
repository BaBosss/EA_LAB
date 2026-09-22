# Facebook Member Hub — EA Family Master Catalog / Qualification — 2026-09-22

Status: `RESEARCH_ONLY / DOCUMENTARY_QUALIFICATION / NO_MT5_STARTED`

This catalog consumes the completed Facebook Hub intake without recollecting Facebook data. It records selected file identity, lineage, source-context coverage, evidence-supported role, and pre-test qualification. It does **not** turn Facebook performance/safety claims into EA_LAB tested results, Grade, Candidate, risk default, or deployment authority.

## Evidence discipline

- `SOURCE_CLAIM`: exact Facebook post/file metadata and author-provided descriptions.
- `EA_LAB_INFERENCE`: role/readiness/dedup conclusions only where the bounded evidence supports them.
- `TESTED_EVIDENCE`: download/file/hash integrity only for this intake; strategy performance remains `NONE`.
- Opaque EX5 filenames/static strings are not sufficient to infer semantics. Similar names are not auto-deduped.

## Counts

- 48 selected latest families from 124 file rows; 48/48 selected artifacts have SHA-256.
- Role classification: **10 EA**, **4 indicator**, **5 utility/scanner**, **6 SET/config**, **3 research artifacts**, **20 UNKNOWN EX5**.
- Context: **19/48** exact selected-version context available; **29/48** `SOURCE_CONTEXT_UNKNOWN`.
- Backtest gate: **1 `READY_FOR_SETTINGS_FREEZE`**, **0 `READY_FOR_TEST`**, **9 confirmed-EA pre-test blocked**, **20 unknown/context-required**, **18 `NOT_AN_EA` for EA tester mainline**.

## 48-family catalog

| Family | Selected latest | SHA256 | Versions | Context | Role | Qualification |
|---|---|---|---:|---|---|---|
| RealtimeTrend | `RealtimeTrend.ex5` | `56620cd26c5d…` | 2 | EXACT | UTILITY_OR_SCANNER | `NOT_AN_EA` |
| DynamicGrid | `DynamicGrid12.ex5` | `442ad0b021d8…` | 56 | EXACT | EA | `SEMANTICS_REQUIRED` |
| IndicatorLicenseChecker | `IndicatorLicenseChecker.ex5` | `3891a403218a…` | 1 | EXACT | UTILITY_OR_SCANNER | `NOT_AN_EA` |
| PairsTradeEA_MultiAuto | `PairsTradeEA_MultiAuto.ex5` | `b88199c956fc…` | 1 | EXACT | EA | `SEMANTICS_REQUIRED` |
| PairsTradeEA | `PairsTradeEA.ex5` | `c44ce6a4645c…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| EngulfingRSI | `EngulfingRSI.ex5` | `4ee5864e7ead…` | 1 | EXACT | INDICATOR | `NOT_AN_EA` |
| VolumesMTF | `VolumesMTF.ex5` | `83a409883d4e…` | 1 | EXACT | INDICATOR | `NOT_AN_EA` |
| StablePassiveMT5 | `StablePassiveMT5.ex5` | `30be9686c3fa…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| ConfirmedFib | `ConfirmedFib.ex5` | `adc3d75f065a…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| SpreadTradeOil | `SpreadTradeOil.ex5` | `a2562dbaee22…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| CandlestickPatterns | `CandlestickPatterns.ex5` | `fc835bca2623…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| ATR_VolatilityRegime | `ATR_VolatilityRegime.ex5` | `79306fc86126…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| ZABGoldScaling | `ZABGoldScaling.ex5` | `ec17aa25ac41…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| SMC_LuxAlgo | `SMC_LuxAlgo.ex5` | `1b20649b7d31…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| ZABDailyVolumeProfile | `ZABDailyVolumeProfile.ex5` | `5c9443a20c89…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| RiskPerTradeสอบกองทุน | `RiskPerTradeสอบกองทุน.ex5` | `cc7d899b267e…` | 1 | EXACT | EA | `SEMANTICS_REQUIRED` |
| EmaGridRecovery | `EmaGridRecovery3fix.ex5` | `afdaa5460a51…` | 3 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| FVGFinderPro | `FVGFinderPro.ex5` | `3e84716b4d53…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| CloseSystem | `closesystem146fix.ex5` | `dd9c2ba7659a…` | 9 | UNKNOWN | EA | `VERSION_COMPATIBILITY_REQUIRED` |
| SwingHL | `SwingHL.ex5` | `da7f363cef62…` | 2 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| ZABSupplyDemand | `ZABSupplyDemand.ex5` | `416ed6c1690d…` | 2 | EXACT | INDICATOR | `NOT_AN_EA` |
| ZoneRecovery3 | `ZoneRecovery3.ex5` | `2cb13c8b6e88…` | 1 | EXACT | EA | `SEMANTICS_REQUIRED` |
| HybridHedgingGold | `HybridHedgingGold3.2.ex5` | `75a8cdc57fd8…` | 5 | UNKNOWN | EA | `CONTEXT_REQUIRED` |
| SmartTrendPro | `SmartTrend Pro.ex5` | `11745ea7997e…` | 2 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| GoldRushBreakout | `GoldRushBreakout3.2.ex5` | `11bfd1b30dfd…` | 2 | UNKNOWN | EA | `CONTEXT_REQUIRED` |
| DashboardScanner | `DashboardScanner.ex5` | `4be835e46cce…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| 89like61RacingCloseMA | `89like61RacingCloseMA.set` | `39c9ef973739…` | 1 | UNKNOWN | SET_CONFIG | `NOT_AN_EA` |
| 89like61Racing | `89like61Racing.set` | `6f417f97c608…` | 1 | UNKNOWN | SET_CONFIG | `NOT_AN_EA` |
| StochScanner | `StochScanner.ex5` | `e29f01bcae00…` | 1 | EXACT | UTILITY_OR_SCANNER | `NOT_AN_EA` |
| all_lot_modes_comparison | `all_lot_modes_comparison.xlsx` | `505f9b87d0f0…` | 1 | UNKNOWN | RESEARCH_ARTIFACT | `NOT_AN_EA` |
| โปรแกรมคำนวน lot_mode_comparison | `โปรแกรมคำนวน lot_mode_comparison.xlsx` | `f503bb84894b…` | 1 | UNKNOWN | RESEARCH_ARTIFACT | `NOT_AN_EA` |
| SetFileDynamicGridV6bangzeed | `SetFileDynamicGridV6bangzeed.set` | `62c3f9ea5f6e…` | 1 | UNKNOWN | SET_CONFIG | `NOT_AN_EA` |
| TradeAssistant_v2.5Fix | `TradeAssistant_v2.5Fix.ex5` | `f3d9fb820c77…` | 1 | EXACT | UTILITY_OR_SCANNER | `NOT_AN_EA` |
| ZAB_TradeAssistant_v2.5 | `ZAB_TradeAssistant_v2.5.ex5` | `f5cd28c87548…` | 1 | EXACT | UTILITY_OR_SCANNER | `NOT_AN_EA` |
| AutoLot_CentVantageCloseByCombine_3.1 | `AutoLot_CentVantageCloseByCombine_3.1.set` | `f6b685932443…` | 1 | UNKNOWN | SET_CONFIG | `NOT_AN_EA` |
| ZABStochGoldRecoveryEA | `ZABStochGoldRecoveryEAV4.ex5` | `9a872f67ffd9…` | 1 | EXACT | EA | `SEMANTICS_REQUIRED_HIGH_RISK_MM` |
| EAช่วยตั้งSLช่วยเก็บกำไร | `EAช่วยตั้งSLช่วยเก็บกำไร.ex5` | `3991c4a2e02b…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| ZABStochGoldEA | `ZABStochGoldEAV31.ex5` | `edceb572fec7…` | 2 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| hedgegoldmodern | `hedgegoldmodern.ex5` | `723b9f863868…` | 1 | EXACT | UNKNOWN | `CONTEXT_REQUIRED` |
| ZoneRecoverV2.5 | `ZoneRecoverV2.5.ex5` | `53e71cdeec8c…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| setclosesystemoil72-50 | `setclosesystemoil72-50.set` | `16a25074a2d2…` | 1 | EXACT | SET_CONFIG | `NOT_AN_EA` |
| EUStable | `EUStable.ex5` | `ed3c13fa43a4…` | 2 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| EMAREsistance | `EMAREsistance.ex5` | `9decceb8a5c6…` | 1 | EXACT | INDICATOR | `NOT_AN_EA` |
| loter4 | `loter4.ex5` | `c5737dbb429b…` | 1 | UNKNOWN | UNKNOWN | `CONTEXT_REQUIRED` |
| goldhft3500-2800 | `goldhft3500-2800.set` | `983c028a6321…` | 1 | EXACT | SET_CONFIG | `NOT_AN_EA` |
| lootv3 | `lootv3.ex5` | `795578c2e2ae…` | 1 | EXACT | EA | `SEMANTICS_REQUIRED` |
| ZABgoldpending | `ZABgoldpending.ex5` | `f75e6d11f298…` | 1 | EXACT | EA | `READY_FOR_SETTINGS_FREEZE` |
| ลงทุนอย่างเข้าใจ | `ลงทุนอย่างเข้าใจ.pdf` | `73f87d77ff4a…` | 1 | UNKNOWN | RESEARCH_ARTIFACT | `NOT_AN_EA` |

Full 64-hex selected hashes, bytes, permalinks, and version-lineage rows are in `FACEBOOK_MEMBER_HUB_BACKTEST_QUALIFICATION_20260922.json`.

## Confirmed EA pre-test queue

| Family | Current state | Evidence boundary / next gate |
|---|---|---|
| DynamicGrid | `SEMANTICS_REQUIRED` | v12 exact post plus family post describes Grid + Martingale bot |
| PairsTradeEA_MultiAuto | `SEMANTICS_REQUIRED` | exact post says automatic selection of advantageous pair |
| RiskPerTradeสอบกองทุน | `SEMANTICS_REQUIRED` | exact post says one-position EA with configurable risk for prop-style use |
| CloseSystem | `VERSION_COMPATIBILITY_REQUIRED` | family post describes user-defined zone/count/distance/TP without Martingale; older V10 Gold HFT and Oil set posts exist |
| ZoneRecovery3 | `SEMANTICS_REQUIRED` | exact post identifies Zone Recovery bot |
| HybridHedgingGold | `CONTEXT_REQUIRED` | family post describes hybrid Grid + Hedge + Close System |
| GoldRushBreakout | `CONTEXT_REQUIRED` | family post describes precision single-trade bot; separate group post references Gold Rush 3.2 settings video |
| ZABStochGoldRecoveryEA | `SEMANTICS_REQUIRED_HIGH_RISK_MM` | exact V4 post names trend filter and recovery lot and warns doubling after loss |
| lootv3 | `SEMANTICS_REQUIRED` | exact post identifies lot-building bot; buy emphasis in rising product; 0.0075 distance example |
| ZABgoldpending | `READY_FOR_SETTINGS_FREEZE` | source post says breakout bot for Gold M5; lot or risk-percent configurable; defaults otherwise prepared |

## ZABgoldpending — first prospective candidate

- Selected EX5: `ZABgoldpending.ex5` / SHA256 `f75e6d11f298765521d0bbcb7ce37c0e2fdacec3136315dd48047ee2249c9c90` / 53368 bytes.
- Exact source post: `725024260297268`; source post content SHA256 `9b818b646503247d7dda3a653c4d5a2301f95c944ff22d266b029c3acc5f96bb`.
- `SOURCE_CLAIM`: breakout bot, Gold, M5, user chooses lot or risk-percent, settings otherwise prepared, demo recommended first.
- Exact broker symbol remains unresolved: source word **Gold** does not prove `XAUUSD` or a broker suffix.
- Exact internal entry/exit/MM, grid/martingale/hedge absence, and external dependencies remain unknown because the EX5 is opaque.
- Risk/default choice is owner-reserved. No lot/risk mode or value is invented.
- Exact MT5 install/build/account, broker symbol, MAIN/BWD windows, data/model/cost assumptions, and exact input surface are not frozen yet.
- State remains `READY_FOR_SETTINGS_FREEZE`, not `READY_FOR_TEST`; MT5 has not started; optimization is not authorized; HOLDOUT remains unspent.

## SET compatibility

All six selected SET artifacts are `UNQUALIFIED_DO_NOT_ATTACH`. Before use, prove same family, same input surface, compatible version lineage, and role/settings match. In particular, selected `closesystem146fix.ex5` remains `VERSION_COMPATIBILITY_REQUIRED`; older CloseSystem Gold-HFT/Oil SET/post context is not sufficient proof.

## Ambiguous family relationships — unresolved

- `PairsTradeEA` ↔ `PairsTradeEA_MultiAuto`: `POSSIBLE_RELATION_NOT_AUTO_DEDUPED`.
- `TradeAssistant_v2.5Fix` ↔ `ZAB_TradeAssistant_v2.5`: `POSSIBLE_RELATION_NOT_AUTO_DEDUPED`.
- `ZoneRecovery3` ↔ `ZoneRecoverV2.5`: `POSSIBLE_RELATION_NOT_AUTO_DEDUPED`.
- `lootv3` ↔ `loter4`: `POSSIBLE_RELATION_NOT_AUTO_DEDUPED`.

No exact selected Facebook family/file name matched current tracked `docs/`, `ea_template/`, `portfolio/`, `taskboards/`, or an existing Registry owner during this Control Tower reconciliation. That observation does not prove semantic non-equivalence; it only prevents automatic merging.

## Negative knowledge / stop rules

- same-method Facebook filename/context search is saturated; do not rerun it absent a new source method
- 29/48 selected families lack exact selected-version post context
- all 39 EX5 binaries are opaque; static strings are hints, not semantic/security parity
- four similar-name relationships remain unresolved
- SET compatibility is unqualified
- file identity does not imply profitability, safety, Home, TF, or tester eligibility
- Do not rerun the saturated same-method Facebook filename/context search merely because a future chat rotates.
- Do not attach an old SET to a selected EX5 from name similarity alone.
- Do not turn author performance/safety/setup claims into tested evidence without a separately frozen EA_LAB test contract.

## Exact source artifacts consumed

- `FINAL_INTAKE_INVENTORY.json` — 34604 bytes — SHA256 `923c4c7a4e882260c6ecf3689ccbd97e24bf58b0052710b7bcf7be8d1d666eb6`.
- `SELECTED_DOWNLOAD_MANIFEST.json` — 45741 bytes — SHA256 `1fe7844c0f74675456b9fc0fef248690e62e772f2e261712a40346c7f5a6008d`.
- `BACKTEST_CONTRACT_QUEUE.json` — 3875 bytes — SHA256 `b12a126f72d2b7c1ef41cffe31210f24d2bc03575423227d2d1609e8ed123e6e`.
- `FACEBOOK_HUB_CLOSEOUT.md` — 4743 bytes — SHA256 `4e7ad0329a7b8a240888b84490082bd549c0a7cb66d9cf74d6954335d65160e6`.
- `FINAL_LANE_RECEIPT.json` — 988 bytes — SHA256 `199943916df2e942f68a0a26f591289782ebc4b063358a28d69392d7d763c6f8`.
- `COVERAGE_CROSSCHECK.json` — 34209 bytes — SHA256 `1b2b9c9260ff729cce773e8a619c5b48209b4a420384f2c4d188ba68c337e04b`.
- `TARGETED_CONTEXT_RESULT.json` — 3892 bytes — SHA256 `cb9291d99bc44aced9c18294903884ba2f24ece6a5c85d543e01422904ed43ed`.
- `SEARCH_POSTS_ENRICHED.json` — 122910 bytes — SHA256 `b6cd2c6fbaaf90823a2d9e217b532164abb2cd1643e461686c493c63082dae19`.
- `STATIC_BINARY_SCAN.json` — 31558 bytes — SHA256 `f6f4a4340582e42035178bf40be171d427fb8d747cbfa61ed0f2f3075d018b07`.
- `FAMILY_SELECTION_DRAFT.json` — 79102 bytes — SHA256 `73c7778da920d660dfbe726a5530ebc8bb0b5e8891b2d35c7015ec9835f3f5cf`.

Authority ceiling: `RESEARCH_ONLY`. No code implementation, MT5 run, optimizer, HOLDOUT discovery, Candidate/Grade/KINT decision, risk/default change, runtime attachment, deployment, DEMO/LIVE, or trading is created by this catalog.
