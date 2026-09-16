# DF03 Grid Horizontal Line / Fibonacci — Parent Freeze — 2026-09-16

Status: `OWNER-DIRECTED / EXACT PARENT FROZEN / SOURCE_BOUND / NO_MT5`.

## Exact parent

- family: `DF03 — Grid Horizontal Line / Fibonacci`
- file: `(Boss) Grid Horizontal Line Trailing by Fibo rev 4(Config lot ,TF , Hedging).mq5`
- SHA256: `2aba9437319e214c82b63313a049f73da364052eddfa24f7f1661279593ffd89`
- recovered MQ4 sibling SHA256: `af2e739b990a0ca85fd98fc3fe098c15b8a311aa434b2b9442ac80e681a3c035`
- deterministic external receipt: `D:\EA_LAB_CONTROL\evidence\df03-parent-freeze-20260916\DF03_PARENT_FREEZE_RECEIPT_20260916.json`
- receipt SHA256: `e49ebd1aca26329f68b9dfcb9bfc4281c2cef03c349cce9cf02c94343c7c55ea`

The older rev4/rev4.2/rev4.3 and Jobot files remain alternate lineage evidence. Their values or mechanics are not merged into this parent.

## Why this parent

The frozen top-level Boss MQ5 has 14 inputs and 126 fxDreema blocks; its MQ4 sibling has the same observed input and block counts (14 / 126). Counts alone do not establish graph or runtime equivalence. Old rev4.2/rev4.3 have 13 inputs and 116 blocks. The ten added condition blocks gate hedge-order legs with `Hedging_mode_1_on_0_off == 1.0`; they are causal mechanics, not generated-library noise.

The current-toolchain compile status does not override source lineage. Old rev4/rev4.3 compile on the current MetaEditor with `0 errors / 19 warnings`, while the frozen parent produces `15 errors / 24 warnings`; selecting the older revision only because it compiles would silently remove the later hedge-enable behavior.
## Frozen source mechanics

- 15 OnTick root blocks and 2 OnTrade event roots; this is a family-native pipeline, not an entry-only signal.
- source inputs: `Lot1..Lot5`, `Pull_Back`, `Nearby_PIP`, `Close_All_Percent`, `Timeframe`, `Hedging_mode_1_on_0_off`, `TP_pip`, `SL_pip`, `MagicStart`, plus the generated candle-find selector.
- default internal strategy timeframe input is `PERIOD_D1` and is consumed by multiple candle/pivot/object-price branches.
- some source branches also use `CurrentTimeframe()`. Therefore internal D1 semantics and chart/current-TF semantics coexist and must not be collapsed into one timeframe assumption.
- the ten explicit hedge conditions compare `Hedging_mode_1_on_0_off` to numeric `1.0` before hedge buy/sell legs.
- raw source sizing-input defaults (units remain source-owned, not asserted as literal lots) are `0.05 / 0.10 / 0.15 / 0.20 / 0.30`; `MagicStart=4023`.

## Compiler-compatibility finding

The frozen parent is not current-compiler clean. Current MetaEditor reports identifier collisions for generated `Bars`, `Digits`, and `Point`, plus downstream `::Bars`-style compatibility errors. This is `SOURCE_COMPILER_INCOMPATIBILITY_CANDIDATE_SPECIFIC`, not strategy-performance evidence and not authority to mutate the recovered source in place.

The next code-bearing work must reproduce frozen causal behavior in a separately reviewed implementation/adapter; it must not patch the evidence parent and then call the patched bytes the source.

## Home / tester identity

Home symbol and chart timeframe remain `UNRESOLVED`. Historical same-filename tester profiles use multiple symbols (`EURUSD/EURUSDc`, `XAUUSD`, `CADJPY`) on H1, while an older optimization report is explicitly multi-symbol/Daily. More importantly, the same-filename historical profile exposes a different parameter surface (`Lot_Leverage_X`, `TP_Percent`, `Retrace_*`, `Break_Even_*`, `MagicStart=3651`) than this frozen source. That is `IDENTITY_SURFACE_MISMATCH`; those profiles cannot bind this parent's Home, settings, build, or performance.

## Authority ceiling

No FamilyID/LAB_ENTRY is allocated by this freeze. No implementation, MT5 run, backtest, optimization, HOLDOUT, risk/default change, Candidate, deployment, runtime attachment or trading authority follows.

Direct consumer: `DF03_GRID_FIBO_COMPILER_COMPATIBILITY_CONTRACT_20260916.md`.