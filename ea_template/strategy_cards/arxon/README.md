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
| [W01](components/W01.md) | VWAP / AVWAP / bands | SOURCE_PARTIAL |
| [W02](components/W02.md) | K2 Ribbon, context EMAs, MTF and A2 | SEMANTIC_FREEZE |
| [W03](components/W03.md) | Initial Balance / session IB / extensions | SOURCE_PARTIAL |
| [W04](components/W04.md) | TPO / value area / naked levels / single prints | SOURCE_PARTIAL |
| [W05](components/W05.md) | Degrees of Power | SOURCE_PARTIAL |
| [W06](components/W06.md) | Alerts | INFRA_ONLY |
| [W07](components/W07.md) | Embedded OBV read | SOURCE_PARTIAL |
| [W08](components/W08.md) | Embedded MFI read | SOURCE_PARTIAL |
| [M01](components/M01.md) | Trend Path / exhaustion zigzag | SOURCE_PARTIAL |
| [M02](components/M02.md) | Order Blocks / breakers / HTF slot | SOURCE_PARTIAL |
| [M03](components/M03.md) | Market Structure / BOS / CHoCH | SOURCE_PARTIAL |
| [M04](components/M04.md) | FVG / IFVG / HTF slot | SOURCE_PARTIAL |
| [M05](components/M05.md) | Naked Key Levels | SOURCE_PARTIAL |
| [M06](components/M06.md) | Session Key Levels | SOURCE_PARTIAL |
| [M07](components/M07.md) | Daily / weekly / monthly Key Levels | SOURCE_PARTIAL |
| [M08](components/M08.md) | Daily Zones | SOURCE_PARTIAL |
| [M09](components/M09.md) | Anchor Candles | SOURCE_PARTIAL |
| [M10](components/M10.md) | Session Clock | INFRA_ONLY |
| [M11](components/M11.md) | Consolidation / confirmed and failed breaks | SOURCE_PARTIAL |
| [O01](components/O01.md) | Arxon OBV+ | SEMANTIC_FREEZE |
| [O02](components/O02.md) | Arxon MFI+ | IMPLEMENTED_ORDER_FREE |
| [O03](components/O03.md) | Stochastic + Dual Zone Entry | SEMANTIC_FREEZE |
| [O04](components/O04.md) | RSI Cross Alert | BLOCKED_VERSION_CONFLICT |

## Route to implementation
[EA integration plan](../../../docs/research/ARXON_TEMPLATE_INTEGRATION_PLAN_20260916.md) → source/semantic freeze → pure provider → V2 adapter / PARAM_REGISTRY → compilation and regression → qualified different-family core review → executable merge → separately authorized research. Two contract routes are possible: a qualified-parent one-change child or a separately approved new family. No contract is silently selected.

[Machine catalog](catalog.json), [source receipts](source_receipts.json), [provenance](PROVENANCE.json), [bounded contract](CONTRACT.md).

[Readiness registry](readiness.json), [B5 remaining-component source freeze](../../../docs/research/ARXON_BLACK_TIDE_B5_SOURCE_FREEZE_20260916.md), [component readiness closeout](../../../docs/research/ARXON_COMPONENT_READINESS_CLOSEOUT_20260916.md).

The README is a navigation consumer only; no EA reads these JSON cards at runtime. O02/MFI is the only implemented order-free Arxon component in this milestone; every trading adapter remains separately gated. Stochastic remains the first existing research-planning lead, still SEMANTICS_REQUIRED / NO_QUALIFIED_PARENT. Closed Black Tide session research stays closed.

Validation: `python ea_template/strategy_cards/arxon/validate_cards.py --repo-root .` (use repository portable Python). Add `--self-test` for adversarial documentary checks. Validation is not compile/backtest/parity evidence.
