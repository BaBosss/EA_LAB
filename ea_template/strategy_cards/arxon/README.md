# Arxon strategy-design library for EA Template V2

**6 family cards · 23 component cards · NON_EXECUTABLE**

This library answers the owner's request to prepare every tool before building EAs. It is integrated documentation, not installed trading modules, a Factory StrategyRecord, or performance acceptance. Source descriptions, design proposals and unresolved semantics are separate. No FamilyID/LAB_ENTRY, input/risk defaults or runtime settings are changed.

## Family cards
| Card | Tool | Component coverage | Current development gate |
|---|---|---|---|
| [ARX-01](families/ARX-01.md) | Black Tide Wave | W01, W02, W03, W04, W05, W06, W07, W08 | source/version + semantics + selected consumer; executable EA not implemented |
| [ARX-02](families/ARX-02.md) | Black Tide Map | M01, M02, M03, M04, M05, M06, M07, M08, M09, M10, M11 | source/version + semantics + selected consumer; executable EA not implemented |
| [ARX-03](families/ARX-03.md) | Arxon OBV+ | O01 | source/version + semantics + selected consumer; executable EA not implemented |
| [ARX-04](families/ARX-04.md) | Arxon MFI+ | O02 | source/version + semantics + selected consumer; executable EA not implemented |
| [ARX-05](families/ARX-05.md) | Stochastic + Dual Zone Entry | O03 | source/version + semantics + selected consumer; executable EA not implemented |
| [ARX-06](families/ARX-06.md) | RSI Cross Alert | O04 | source/version + semantics + selected consumer; executable EA not implemented |

## Module cards — all carried slots
The 23-slot count follows the previous supplied inventory: 8 Wave + 11 Map + 4 standalone. It is not 23 independent EAs, and does not resolve changing headings/module counts across publication versions. Alert transport and Session Clock are infrastructure. Embedded OBV/MFI and standalone variants are not silently deduplicated as the same formula/configuration.

| Card | Module | Gate |
|---|---|---|
| [W01](components/W01.md) | VWAP / AVWAP / bands | PRICE_VOLUME_SESSION_PARITY_REQUIRED |
| [W02](components/W02.md) | K2 Ribbon, context EMAs, MTF and A2 | K2_BASE_PARTIAL; A2_TIMING_REQUIRED |
| [W03](components/W03.md) | Initial Balance / session IB / extensions | SESSION_CLOCK_REQUIRED; CLOSED_BRANCH_DEDUP |
| [W04](components/W04.md) | TPO / value area / naked levels / single prints | EXACT_PROFILE_ENGINE_REQUIRED |
| [W05](components/W05.md) | Degrees of Power | CAUSAL_HISTORY_AND_MISSING_STATE_REQUIRED |
| [W06](components/W06.md) | Alerts | EVENT_IDEMPOTENCY_REQUIRED |
| [W07](components/W07.md) | Embedded OBV read | NOT_ASSUMED_IDENTICAL_TO_STANDALONE |
| [W08](components/W08.md) | Embedded MFI read | SEPARATE_CONFIG_FROM_STANDALONE |
| [M01](components/M01.md) | Trend Path / exhaustion zigzag | PROVISIONAL_PIVOT_FINALITY_REQUIRED |
| [M02](components/M02.md) | Order Blocks / breakers / HTF slot | LIFECYCLE_AND_ALERT_COVERAGE_REQUIRED |
| [M03](components/M03.md) | Market Structure / BOS / CHoCH | SWING_AND_BIAS_CONTRACT_REQUIRED |
| [M04](components/M04.md) | FVG / IFVG / HTF slot | FILL_VS_INVERSION_PRIORITY_REQUIRED |
| [M05](components/M05.md) | Naked Key Levels | LEVEL_AGE_AND_TEST_RULE_REQUIRED |
| [M06](components/M06.md) | Session Key Levels | SESSION_CLOCK_AND_DEDUP_REQUIRED |
| [M07](components/M07.md) | Daily / weekly / monthly Key Levels | CALENDAR_ROLLOVER_REQUIRED |
| [M08](components/M08.md) | Daily Zones | BOUNDS_AND_AVAILABILITY_REQUIRED |
| [M09](components/M09.md) | Anchor Candles | DETECTOR_THRESHOLDS_REQUIRED |
| [M10](components/M10.md) | Session Clock | TIMEZONE_DST_REQUIRED; NOT_STANDALONE_EA |
| [M11](components/M11.md) | Consolidation / confirmed and failed breaks | PROVISIONAL_FREEZE_AND_GRACE_REQUIRED |
| [O01](components/O01.md) | Arxon OBV+ | SOURCE_CARD_ONLY_NOT_EXECUTABLE |
| [O02](components/O02.md) | Arxon MFI+ | SOURCE_CARD_ONLY_NOT_EXECUTABLE |
| [O03](components/O03.md) | Stochastic + Dual Zone Entry | SOURCE_CARD_ONLY_NOT_EXECUTABLE |
| [O04](components/O04.md) | RSI Cross Alert | SOURCE_CARD_ONLY_NOT_EXECUTABLE |

## Route to implementation
[EA integration plan](../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md) → source/semantic freeze → pure provider → V2 adapter / PARAM_REGISTRY → compilation and regression → qualified different-family core review → executable merge → separately authorized research. Two contract routes are possible: a qualified-parent one-change child or a separately approved new family. No contract is silently selected.

[Machine catalog](catalog.json), [source receipts](source_receipts.json), [provenance](PROVENANCE.json), [bounded contract](CONTRACT.md).

The README is a navigation consumer only; no EA reads these JSON cards at runtime. The first non-trading preparation work package is MFI computation semantics; Stochastic remains the first existing research-planning lead. Closed Black Tide session research stays closed.

Validation: `python ea_template/strategy_cards/arxon/validate_cards.py --repo-root .` (use repository portable Python). Add `--self-test` for adversarial documentary checks. Validation is not compile/backtest/parity evidence.
