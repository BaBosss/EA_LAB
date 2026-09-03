# Black Tide Map / Wave source note — 2026-09-03

Status: `RESEARCH_ONLY`

Purpose: pin the external material used for the EA_LAB Second Brain transfer. This note records source-supported design claims only; it is not performance evidence and creates no strategy, optimization, HOLDOUT, risk, runtime, deployment, or promotion authority.

## Primary sources

1. TradingView — **Black Tide Map**, by `peeradetm` / Peeradet Meecharoen: `https://www.tradingview.com/script/5L9vbNRJ-Black-Tide-Map/`
2. Black Tide Wave site — **Black Tide Map v1.0.0** release note: `https://blacktidewave.com/`
3. TradingView — **Black Tide Wave System**, by `charoensuk9517`: `https://www.tradingview.com/script/GaIVjUah/`

Retrieved: `2026-09-03`.

## SOURCE_CLAIM — current Black Tide Map

The current TradingView description explicitly defines Black Tide Map as a **reference layer**, not a trade system, strategy, or signal generator. It describes the companion split as: Black Tide Wave reads flow moving now, while Map reads structure, blocks, levels, and zones left by past flow.

Current Map design claims include:

- Market Structure: BOS / CHoCH from confirmed pivots; the description states confirmed pivots are final and do not repaint.
- Session Key Levels: Asia / London / New York session highs and lows; a later Session Clock release adds explicit London/New York overlap segments.
- Order Blocks: block-candle origin plus volume-related measurements and lifecycle states including fresh, mitigated, invalidated, and breaker behavior.
- Fair Value Gaps: confirmed three-bar imbalance logic, ATR/displacement filtering, separate filled versus inverted behavior, and optional higher-timeframe context.
- Trend Path: an exhaustion-oriented path using MFI and stochastic saturation, explicitly allowed to disagree with price-pivot Market Structure.
- Period/location context: naked levels, previous-day/week/month levels, premium/discount daily zones, and anchor-candle marks.
## SOURCE_CLAIM — important source caveats

- The Map page says its buy/sell split is a **proxy, not delta**. It is derived from candle location/range because Pine does not have true per-side tick data.
- Revisit volume is described as a measurement, not a finding; whether a heavily revisited zone is more or less likely to hold requires separate forward testing.
- The current TradingView script is protected/closed-source. EA_LAB can inspect the published behavior description, not the implementation code.
- The older Black Tide Wave site v1.0.0 note lists modules that changed later. Current TradingView release notes show Liquidity was removed and Trend Path, FVG, breaker blocks, and Session Clock were added. For current module identity, the current TradingView page has precedence over the older v1.0.0 summary.

## SOURCE_CLAIM — Black Tide Wave companion description

The current Black Tide Map page describes Black Tide Wave as the companion that reads current flow using `VWAP`, the `K2 ribbon`, `opening balance`, the `TPO profile`, and a `Degrees of Power` meter. The separate Black Tide Wave System TradingView page is protected/closed-source and provides little additional methodological detail in its public description.

## SOURCE_CLAIM â€” current default session inputs

The current TradingView public page metadata, captured on 2026-09-03 (transient HTML SHA-256 `c85efca3dc3645c03d0f9f6ab2163ce2bc37104711eee789a9857a20e7191f06`), exposes these Session Key Levels defaults:

- `Session timezone = UTC`;
- `Asia = 0000-0800`;
- `London = 0700-1600`;
- `New York = 1200-2100`.

The Session Clock release note says it has no independent session windows and reads the hours/timezone from Session Key Levels; London/New York overlap is rendered as its own segment. The source does not define a separate Asia/London-overlap output, so any mutually exclusive tie-break for research attribution is an EA_LAB inference and must be preregistered rather than presented as a source claim.

## Evidence boundary

These sources describe indicator architecture and intended visual interpretation. They do **not** provide controlled evidence that any module improves profitability, robustness, drawdown, or transfer across assets/timeframes.

EA_LAB must therefore preserve the distinction:

`published design description -> research mechanism candidate -> controlled EA_LAB attribution/experiment -> evidence -> interpretation -> decision`.

No module is adopted as a production rule from these sources alone.
