# Parameter Linkage Map

> **GENERATED FILE - do not hand-edit.** Produced by `scripts/gen_param_linkage.ps1`
> from `docs/PARAM_REGISTRY.csv` (one row per MQL5 input declared in
> `ea_template/core/Inputs.mqh`). Any manual edit to this file will be silently
> overwritten the next time the generator runs.
>
> **Regenerate whenever `docs/PARAM_REGISTRY.csv` changes** - i.e. any time an
> `Inputs.mqh` edit is followed by a registry sync. Run:
> `powershell -File scripts\gen_param_linkage.ps1`, then re-run
> `powershell -File scripts\param_registry_check.ps1` to confirm the registry itself
> is still in sync with the code before trusting this doc.

Rows in source registry: 184.

## Override pairs

Every case in the registry where one input silently supersedes another under some
condition - discovered by scanning `coupled_parameters` and `classification_note` for
*supersedes / overrides-this / this-overrides / OVERRIDDEN / overridden-by / superseded-by*
phrasing. **SILENT** means the losing input's own row carries no note warning the
reader that it can be overridden - the reader would only discover this by reading the
*winner's* row. See `_triage/PARAM_INACTIVE_AUDIT.md` for why each silent case matters.

- **`_17_UseStructLevels`** beats **`ExitMode`** **[SILENT]** -- supersedes SLMode and ExitMode's per-order SL/TP output for build 17 when true and a valid structural SL exists
- **`_17_UseStructLevels`** beats **`SLMode`** -- overridden per-order by _17_UseStructLevels on build17 when a valid structural SL is published
- **`_2_BasketTP_ATRmult`** beats **`_2_BasketTP_Money`** **[SILENT]** -- supersedes _2_BasketTP_Money whenever this is set >0 (Exit_BasketTargetMoney checks this first)
- **`_2_BasketTP_BalPct`** beats **`_2_BasketTP_ATRmult`** **[SILENT]** -- _2_BasketTP_ATRmult and _2_BasketTP_Money(both OVERRIDDEN when this is >0)
- **`_2_BasketTP_BalPct`** beats **`_2_BasketTP_Money`** **[SILENT]** -- _2_BasketTP_ATRmult and _2_BasketTP_Money(both OVERRIDDEN when this is >0)
- **`_2_SuppressLegTP`** beats **`ExitMode`** **[SILENT]** -- when true, supersedes/blanks whatever ExitMode(21/22) would have set as the per-leg broker TP
- **`_32_SL_BalPct`** beats **`_32_SL_Money`** **[SILENT]** -- _32_SL_Money(OVERRIDDEN when this is >0)
- **`_33_SL_MaxATRmult`** beats **`_33_SL_MaxPips`** -- superseded by _33_SL_MaxATRmult whenever that is set >0
- **`_57_DynCloseBalPct`** beats **`_57_DynCloseBase`** **[SILENT]** -- _57_DynCloseBase(OVERRIDDEN when this is >0)
- **`_8_DDRefBalPct`** beats **`_8_DDRefMoney`** **[SILENT]** -- _8_DDRefMoney(OVERRIDDEN when this is >0)
- **`RC_MaxLevelsOverride`** beats **`ProtectLevel`** **[SILENT]** -- implicitly gates the default effective values of KillDD/DepositLoad/MaxRecSteps unless RC_MaxLevelsOverride overrides the steps component

## Parameters by context

### entry

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_12_Bars` | build 12 only | _12_ConfirmBars(channel anchor offset) | Donchian channel lookback length for the breakout entry. |
| `_12_ConfirmBars` | build 12 only | _12_Bars | Number of consecutive closed-bar closes required beyond the channel before firing (0 = tick-level breakout, no confirmation). |
| `_12_HourFrom` | build 12 only, AND only when _12_HourFrom != _12_HourTo (equal values = filter disabled) | _12_HourTo | Session-window start hour (UTC) that gates new breakout entries; wraps past midnight if From>To. |
| `_12_HourTo` | build 12 only, AND only when _12_HourFrom != _12_HourTo | _12_HourFrom | Session-window end hour (UTC). |
| `_13_BB_Dev` | build 13 only, AND _13_RequireBB=true (else BB is never queried) | _13_BB_Period; _13_RequireBB | Bollinger Band deviation width. |
| `_13_BB_Period` | build 13 only | _13_BB_Dev; _13_RequireBB(gates whether BB is consulted at all) | Bollinger Band period for the mean-reversion entry. |
| `_13_RequireBB` | build 13 only | _13_BB_Period; _13_BB_Dev; _13_RSI_OB; _13_RSI_OS | When true, requires price to also touch the BB outer band (not RSI-extreme alone) to fire. |
| `_13_RSI_OB` | build 13 only | _13_RSI_Period; _13_RequireBB(also gates whether at_upper requires BB touch) | RSI overbought threshold that arms a short entry. |
| `_13_RSI_OS` | build 13 only | _13_RSI_Period; _13_RequireBB | RSI oversold threshold that arms a long entry. |
| `_13_RSI_Period` | build 13 only | _13_RSI_OB; _13_RSI_OS | RSI period for the mean-reversion entry. |
| `_14_Direction` | build 14 only | none - fixed-direction instance, mirrors _16_Direction/_18_Direction pattern | Fixes this GridLog instance to BUY-only or SELL-only (bidirectional = two chart instances with separate magics). |
| `_14_DistAtrMult` | build 14 only | _14_MinDistPips(floor, whichever distance is larger wins) | Multiplier on Signal-ATR (shift 1) used for both the arm-trigger distance and the implicit grid step for this entry. |
| `_14_MinDistPips` | build 14 only | _14_DistAtrMult | Pip floor under the ATR-derived arm distance. |
| `_15_CountBars` | build 15 only | _15_EdgeTrigger; _15_RearmBars | Number of consecutive closed bars the MACD main/signal relationship must hold in one direction before the signal fires. |
| `_15_EdgeTrigger` | build 15 only | _15_CountBars; _15_RearmBars(only relevant when EdgeTrigger=true) | true=fire once per MACD-state run (edge latch); false=fire every bar the count condition holds (level mode, documented to over-trade 571 vs 36 trades in the source port). |
| `_15_MacdFast` | build 15 only | _15_MacdSlow; _15_MacdSignal | MACD fast EMA period for the ST03 consecutive-count signal. |
| `_15_MacdSignal` | build 15 only | _15_MacdFast; _15_MacdSlow | MACD signal-line SMA period. |
| `_15_MacdSlow` | build 15 only | _15_MacdFast; _15_MacdSignal | MACD slow EMA period. |
| `_15_RearmBars` | build 15 only, AND _15_EdgeTrigger=true (else this is never consulted) | _15_EdgeTrigger | Re-fire cadence (in bars) within an already-latched MACD-state run; 0 = never re-fire until the state flips. |
| `_16_Direction` | build 16 only | none - fixed-direction instance | Fixes this Kangaroo instance to BUY-only or SELL-only. |
| `_16_RsiHigh` | build 16 only, direction 2 instance | _16_RsiPeriod | SELL-instance arms when last-closed-bar RSI is above this. |
| `_16_RsiLow` | build 16 only, direction 1 instance | _16_RsiPeriod | BUY-instance arms when last-closed-bar RSI is below this. |
| `_16_RsiPeriod` | build 16 only | _16_RsiLow; _16_RsiHigh | RSI period for the Kangaroo fade entry (own handle, chart TF). |
| `_17_EntryFib` | build 17 only | _17_SLbufferATR(SL placement is independent, anchored on wave1, not this fib level) | Wave-4 retrace zone arm level, as % retrace of the full wave-3 length. |
| `_17_FractalDepth` | build 17 only | _17_MaxSwings | Confirmed-fractal bars required on each side of a pivot before it counts as a swing (repaint guard: newest usable pivot is always this many bars back). |
| `_17_MaxSwings` | build 17 only | _17_FractalDepth | Maximum confirmed pivots collected per evaluation call (needs >=4 for a valid 1-2-3 structure). |
| `_17_Wave3MinMult` | build 17 only | implicit: wave1 length itself, derived from the swing data | Minimum multiple of \|wave1\| that wave3 must break beyond wave1's end for the 1-2-3 structure to confirm. |
| `_18_Direction` | build 18 only | none - fixed-direction instance | Fixes this JumStoch instance to BUY-only or SELL-only. |
| `_18_DirMode` | build 18 only | _18_LoLevel; _18_UpLevel(same thresholds, mirrored role) | Selects between two exact BUY/SELL mirror readings of the same LWMA+Stoch signal: 1=momentum-join (validated source mapping, EURUSD-H1 PF1.18 baseline), 2=reversion (Lane-A brief as written) - the lab has not settled which is correct, both are A/B'd. |
| `_18_DPeriod` | build 18 only | _18_KPeriod; _18_Slowing | Stochastic %D period. |
| `_18_KPeriod` | build 18 only | _18_DPeriod; _18_Slowing | Stochastic %K period. |
| `_18_LoLevel` | build 18 only | _18_DirMode(role flips between modes) | Lower Stochastic band used by both DirMode readings (role differs: oversold-confirm in mode1, oversold-reject in mode2). |
| `_18_MaPeriod` | build 18 only | none | LWMA period for the displacement reference line. |
| `_18_Slowing` | build 18 only | _18_KPeriod; _18_DPeriod | Stochastic slowing period. |
| `_18_UpLevel` | build 18 only | _18_DirMode | Upper Stochastic band used by both DirMode readings. |
| `TradeDir` | builds 11/12/13/15 only (checked explicitly in those 4 Entry_Evaluate() functions); builds 14/16/18 use their own fixed-direction input instead and never read this; build17 is bidirectional by design and never reads this | per-entry: none direct, but functionally overlaps with _14_Direction/_16_Direction/_18_Direction on builds that ignore it | Restricts a symmetric entry signal to long-only, short-only, or both; has zero effect on builds 14/16/17/18. |
| `TrendFilter` | builds 11/12/13 only; no effect on 14/15/16/17/18 | _71_ATRMA+_71_ATRRatio(71); _72_SlopeBar(72) | Adds a confirming filter (ATR-expansion or MA-slope) before the entry signal is allowed to fire; only wired into 3 of the 8 entry modules. |

### entry filter

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_71_ATRMA` | builds 11/12/13 only, AND TrendFilter==TFILTER_ATR_EXPAND(71) | _71_ATRRatio | Smoothing period for the ATR moving average the expansion filter compares against. |
| `_71_ATRRatio` | builds 11/12/13 only, AND TrendFilter==71 | _71_ATRMA | Minimum ratio of current ATR to its moving average required to consider volatility 'expanding'. |
| `_72_SlopeBar` | builds 11/12/13 only, AND TrendFilter==TFILTER_MA_SLOPE(72) | _0_FastMA | Bars back the fast-MA slope is measured over. |

### entry filter (regime)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_50_ADX_Period` | _50_RegimeMode != 0 | _50_Regime_TF; _50_ADX_TrendMin; _50_StormATRmult/_50_StormLookback(storm ATR handle shares this period too) | ADX period for trend/range classification - also silently reused as the ATR handle's period for the storm-detector (there is no separate regime-ATR-period input). |
| `_50_ADX_TrendMin` | _50_RegimeMode != 0 | _50_ADX_Period | Minimum ADX value for the bar to be classified trending (else RANGE). |
| `_50_AllowRange` | _50_RegimeMode==1 only | _50_RegimeMode | In filter mode, whether a RANGE regime is allowed to take a new first-entry. |
| `_50_AllowTrendDown` | _50_RegimeMode==1 only | _50_RegimeMode | In filter mode, whether a TREND_DOWN regime is allowed to take a new first-entry. |
| `_50_AllowTrendUp` | _50_RegimeMode==1 only (mode 2 ignores this) | _50_RegimeMode | In filter mode, whether a TREND_UP regime is allowed to take a new first-entry. |
| `_50_Regime_TF` | _50_RegimeMode != 0 | _50_ADX_Period | Timeframe the ADX/ATR regime classification runs on (cached per bar on this TF). |
| `_50_RegimeMode` | always checked (0 = off, fully inert) | _50_AllowTrendUp/Down/Range(mode1 only); everything else in this section | 0=off, 1=filter mode (block disallowed states from taking any new first-entry), 2=direction mode (force entry direction to match the regime, block range entirely). |
| `_50_StormATRmult` | _50_RegimeMode != 0, AND this value >0 (0 disables the storm overlay) | _50_StormLookback | ATR spike multiple (vs its own lookback SMA) that classifies the bar as STORM (blocks all new entries), overriding the trend/range read for that bar. |
| `_50_StormLookback` | _50_RegimeMode != 0, AND _50_StormATRmult >0 | _50_StormATRmult | Lookback window for the ATR SMA the storm spike is measured against. |

### entry/exit (shared)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_0_MA_TF` | always computed | _0_FastMA; _0_SlowMA | Timeframe the shared trend MA is computed on (PERIOD_CURRENT = chart TF). |
| `_0_MAMethod` | always computed, wherever _0_FastMA/_0_SlowMA matter | _0_FastMA; _0_SlowMA | MA smoothing method (SMA/EMA/SMMA/LWMA) shared by both the fast and slow trend MA handles. |
| `_0_SlowMA` | always computed; used by build 11's entry signal and ExitMode==EXIT_RUN_TREND(24) on any build | _0_FastMA; _0_MAMethod; _0_MA_TF | Slow MA period, shared across the GridTrendMA entry signal and the RunTrend exit. |

### entry/exit/filter (shared)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_0_FastMA` | always computed; functionally used by: build 11's entry signal (Entry_GridTrendMA.mqh), ExitMode==EXIT_RUN_TREND(24) on any build, TrendFilter==TFILTER_MA_SLOPE(72) on builds 11/12/13 (via Indi_MA_IsSloping which reads Indi_FastMA) | _0_SlowMA; _0_MAMethod; _0_MA_TF | Fast MA period, shared across the GridTrendMA entry signal, the RunTrend exit, and the MA-slope filter. |

### entry/stack

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_0_ATR_TF` | same as _0_ATR_Period | _0_ATR_Period | Timeframe the Signal-ATR is computed on. |

### entry/stack (signal ATR)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_0_ATR_Period` | handle always built; functionally consumed wherever Indi_ATR()/Indi_ATR_Points() is read: Stack_StepPrice, Entry_GridLog's arm distance, Kangaroo's grid step, the TrendFilter=71 ATR-expand check | _0_ATR_TF | Period for the 'Signal-ATR' context (entry/stack timing), distinct from the separate Risk-ATR context used for SL/TP/sizing. |

### execution

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_0_BarOpenOnly` | always | none direct - gates the whole management/entry/stack/recovery/hedge cadence to bar-open only; hard-kill(RiskControl_CheckDD)/halt-check/Exit_SafetyMoneyStop remain intrabar regardless of this flag | When true, evaluates the signal/management/stack/recovery/hedge pipeline once per bar-open instead of every tick (Zeus-style cadence); safety kill and the basket money-stop always stay intrabar. |
| `_0_MaxSpread` | this value >0 (0=ignore/off, the historical no-op default) | none direct | Blocks NEW market/pending order placement (not management/exits) when the current spread exceeds this many points; an already-accepted GTC pending can still fill later at a wider spread. |
| `_0_Slippage` | always - applied to every live order via CTrade | none direct | Maximum allowed slippage in points for every order sent through CTrade. |

### execution (macro gate)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_MG_BlockNew` | _MG_SelfGate=true | _MG_LotMult; _MG_TriggerRiskOff | When true, also vetoes new orders outright while gated (not just shrinking lot size). |
| `_MG_InCommon` | _MG_SelfGate=true | _MG_RegimeFile | Whether the regime CSV is read from the shared Common\\Files folder vs this terminal's MQL5\\Files. |
| `_MG_LotMult` | _MG_SelfGate=true, AND the macro regime is currently gated (RISK_OFF/STRESS) | _MG_TriggerRiskOff(whether RISK_OFF counts); _MG_BlockNew | New-order lot multiplier applied while the macro gate is active (reduce-lot doctrine: only values strictly between 0 and 1 take effect). |
| `_MG_OffsetHours` | _MG_SelfGate=true | none direct | Hour offset applied to the CSV timeline timestamps to align with server time (daily granularity: usually 0). |
| `_MG_RegimeFile` | _MG_SelfGate=true | _MG_InCommon(which folder this is read from) | Filename of the MRIS regime timeline CSV the self-gate reads. |
| `_MG_TriggerRiskOff` | _MG_SelfGate=true | _MG_BlockNew; _MG_LotMult | Whether the RISK_OFF regime state (not just STRESS) triggers the gate. |

### execution (macro gate, backtest A/B only)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_MG_SelfGate` | always checked in LabCore; when false the whole macro self-gate is fully inert for this EA instance | _MG_RegimeFile; _MG_InCommon; _MG_LotMult; _MG_BlockNew; _MG_TriggerRiskOff; _MG_OffsetHours (all only matter when this is true) | Enables an in-EA macro regime self-gate (reads the MRIS timeline CSV directly and sets its own MACROGATE_* GVs) for single-EA backtest A/B testing; in live, the standalone (Boss)_MacroGate watchdog is used instead and this should stay off. |

### execution/safety

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_0_Magic` | always | every position/order-ownership check and every persisted GlobalVariable key in the codebase | Identifies which positions/orders/persisted state belong to this EA instance; the compiled default is deliberately refused on any live/demo attach (ORDER-129 magic-collision guard). |
| `DryRun` | always | effectively every order-placing and state-persisting function in the codebase checks this | When true, every order becomes a logged intent only (no real broker call) and no terminal GlobalVariable is ever written or deleted - an observation-only instance. |

### exit

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_16_BasketTpUsdPer01` | build 16 only, AND have>=2 AND this value >0 | Exec_TotalLots() | Dollar-true basket TP: close the whole side once net$ >= this x (total lots / 0.01) - replaces the original's unweighted pip-sum-160 defect. |
| `_16_FlattenMinOrders` | build 16 only, AND _16_FlattenOn=true | _16_FlattenOn; _16_MaxControlledLossUsd | Minimum open-order count before ladder_flatten can fire. |
| `_16_FlattenOn` | build 16 only | _16_FlattenMinOrders; _16_MaxControlledLossUsd | Enables the 'ladder_flatten' controlled-loss release exit (A/B module, default OFF per ORDER-072 decision 5). |
| `_16_MaxControlledLossUsd` | build 16 only, AND _16_FlattenOn=true AND have>=_16_FlattenMinOrders | _16_FlattenOn; _16_FlattenMinOrders | Close-all-side threshold: fires once net$ >= -this (a bounded, accepted loss release rather than letting the ladder run unbounded). |
| `_16_MaxSlPips` | build 16 only, AND this value >0 | _16_SlAtrMult | Hard pip ceiling on the per-order SL distance regardless of ATR. |
| `_16_OverlapMinOrders` | build 16 only | _16_OverlapMinUsd | Minimum open-order count before the overlap pair-close exit becomes active at all. |
| `_16_OverlapMinUsd` | build 16 only, AND have >= _16_OverlapMinOrders | _16_OverlapMinOrders | Minimum combined net-$ of the newest+oldest position pair required to trigger an overlap pair-close. |
| `_16_SlAtrMult` | build 16 only | _16_MaxSlPips(hard ceiling) | Per-order broker SL distance as a multiple of Risk-ATR (~$90 at gold-1800-era ATR per the inline comment). |
| `_16_TpSingleAtrMult` | build 16 only, AND exactly 1 order open on the side | none direct | Managed (not broker) TP distance for a lone open order, as a multiple of Risk-ATR (~80 gold pips at ATR~$2.3). |
| `_17_DivergTrail` | build 17 only, AND ExitMode==EXIT_TRAIL (only call site is inside 'if(ExitMode==EXIT_TRAIL) Wave5_DivergenceTightenHook();') | _23_TrailStep(tighten distance is a fraction of this); ExitMode | Tightens the trail on RSI divergence once price reaches the wave5 target zone; inert unless ExitMode is set to trailing. |
| `_17_RSI_Period` | build 17 only, AND _17_DivergTrail=true AND ExitMode==EXIT_TRAIL | _17_DivergTrail | RSI period used only for the divergence check (own handle, independent of the shared/BB/16 RSI handles). |
| `_17_SLbufferATR` | build 17 only | _17_UseStructLevels(must be true for this SL to actually be applied) | Buffer beyond the wave-1 top/bottom (in Risk-ATR multiples) added to the structural SL to absorb spread/wick. |
| `_17_UseStructLevels` | build 17 only | g_wave5_sl_price/g_wave5_tp_price/g_wave5_entry_ref (published by Entry_Wave5.mqh); when false, ExitManager falls back to the normal SLMode/ExitMode switch | When true, ExitManager uses the published structural SL/TP anchors from the wave signal instead of the generic SLMode/ExitMode switch. |
| `_2_BasketTP_ATRmult` | this value >0 | _2_BasketTP_Money(the input it supersedes) | When >0, the basket TP target scales with current Risk-ATR and total open lots instead of a fixed number - portable across instruments with different price/tick-value scales. |
| `_2_BasketTP_BalPct` | this value >0. HIGHEST precedence of the three basket-TP inputs: _2_BasketTP_BalPct > _2_BasketTP_ATRmult > _2_BasketTP_Money (ExitManager.mqh:506) | _2_BasketTP_ATRmult and _2_BasketTP_Money(both OVERRIDDEN when this is >0); _2_PartialPct1/_2_PartialPct2(partial-close stages measure against the resolved target) | Closes the whole basket once floating profit reaches this % of current balance. Portable across cent/USD accounts (a bare 25 means $25 on USD and $0.25 on cent) and auto-scales as the account grows. |
| `_2_BasketTP_Money` | always the primary basket-TP target UNLESS _2_BasketTP_ATRmult>0 (which overrides it) | _2_BasketTP_ATRmult | Fixed money target that closes the whole basket once floating profit reaches it. |
| `_2_MaxHoldBars` | this value >0, AND NOT build 16 (LabCore.mqh explicitly WARNs that this input has NO EFFECT on Boss_16/Kangaroo, which owns its own exits and never calls Exit_ManageBasket) | StackMode(93 is unaffected - basket-level, not per-leg, so it still fires under a pyramid basket) | Force-closes the whole basket once its oldest leg has been open >= N closed chart-TF bars (vertical-barrier / time-stop, ORDER-125). |
| `_2_PartialFrac1` | same gating as _2_PartialPct1, plus _2_PartialPct1 itself must be >0 | _2_PartialPct1 | Fraction of total basket volume closed at the first partial-close milestone. |
| `_2_PartialFrac2` | same gating as _2_PartialPct2 | _2_PartialPct2 | Fraction of total basket volume closed at the second partial-close milestone. |
| `_2_PartialPct1` | StackMode != STACK_PYRAMID(93) AND a basket target(_2_BasketTP_Money/ATRmult) is set >0 AND this value >0 | _2_PartialFrac1; _2_BasketTP_Money/_2_BasketTP_ATRmult(needs a target to measure % against) | % of the basket-TP target at which the first partial-close milestone fires. |
| `_2_PartialPct2` | same gating pattern as _2_PartialPct1, independently gated on its own >0 value | _2_PartialFrac2 | % of the basket-TP target at which the second partial-close milestone fires. |
| `_2_SuppressLegTP` | always checked; effect is real whenever true | ExitMode(21/22 leg TP is the thing being suppressed); _2_BasketTP_Money/_2_BasketTP_ATRmult(the basket-level exit that becomes the only TP mechanism when this is true) | When true, forces every leg to carry NO per-order broker TP, relying solely on the basket-money exit to close the whole basket together (needed for GridLog(14) parity with the standalone, which used TP=0 per leg). |
| `_21_TP_Pip` | ExitMode==EXIT_FIXED_TP(21) | none direct | Fixed take-profit distance in raw points for a single order. |
| `_22_TP_ATRmult` | ExitMode==EXIT_ATR_TP(22) | _33_AdaptiveON/_33_AdaptiveN(both scale the underlying Risk-ATR this multiplies) | Take-profit distance as a multiple of (optionally regime-adaptive) Risk-ATR. |
| `_23_TrailStart` | ExitMode==EXIT_TRAIL(23) | _23_TrailStep | Minimum point gain before the trailing stop starts moving. |
| `_23_TrailStep` | ExitMode==EXIT_TRAIL(23); on build17, also read by the divergence-tighten hook whenever ExitMode==EXIT_TRAIL and _17_DivergTrail=true | _23_TrailStart; _17_DivergTrail(build17 only) | Trailing-stop distance behind price once trailing has started; also the base unit (x0.25) for build17's divergence tighten. |
| `_31_SL_Pip` | SLMode==SL_FIXED_POINTS(31) | none direct | Fixed per-order stop-loss distance in raw points. |
| `_33_AdaptiveN` | _33_AdaptiveON=true | _33_AdaptiveON | Lookback period for the Risk-ATR SMA the adaptive scale factor is measured against. |
| `_33_AdaptiveON` | matters whenever SLMode==SL_ATR(33) OR ExitMode==EXIT_ATR_TP(22) - it is not SL-only despite living in the '3x Stop loss' input group | _33_AdaptiveN; _22_TP_ATRmult(also scaled by this, not just _33_SL_ATRmult) | When true, scales the effective Risk-ATR by clamp(ATR/SMA(ATR,N), 0.7, 1.5) before it feeds SL AND TP ATR-multiple calcs - a regime-adaptive stretch/compress on both. |
| `_33_SL_ATRmult` | SLMode==SL_ATR(33) | _33_SL_MaxPips/_33_SL_MaxATRmult(caps); _33_AdaptiveON/_33_AdaptiveN(scales the underlying ATR) | Per-order SL distance as a multiple of (optionally adaptive) Risk-ATR. |
| `_33_SL_MaxATRmult` | SLMode==SL_ATR(33), AND this value >0 | _33_SL_MaxPips(the input this overrides) | Portable ATR-relative ceiling on the ATR-derived SL distance, checked before the legacy pip cap. |
| `_33_SL_MaxPips` | SLMode==SL_ATR(33), AND this value >0, AND _33_SL_MaxATRmult<=0 (else the ATR-relative cap wins first) | _33_SL_ATRmult; _33_SL_MaxATRmult(the input that overrides this when set) | Legacy hard pip ceiling on the ATR-derived SL distance. |
| `_34_DonchianBars` | SLMode==SL_STRUCT_DONCHIAN(34) | none direct | Donchian channel lookback used to place a structural SL at the channel extreme. |
| `_35_SRBars` | SLMode==SL_STRUCT_SR(35) | none direct | Swing S/R lookback used to place a structural SL at the nearest swing extreme. |
| `_36_SD_Mult` | SLMode==SL_SD(36) | _36_SD_Period | Standard-deviation band width for the SD-based SL. |
| `_36_SD_Period` | the indicator handle is always built; functionally matters only when SLMode==SL_SD(36) | _36_SD_Mult | StdDev period; the handle is created on every build regardless of SLMode, but only consumed when SLMode=36. |
| `_57_DynCloseBalPct` | _57_DynCloseOn=true AND this value >0. Resolves the BASE only; the per-order growth term (_57_DynCloseDivisor) is already unitless and untouched | _57_DynCloseBase(OVERRIDDEN when this is >0); _57_DynCloseOn(master switch); _57_DynCloseDivisor | Base of the dynamic basket-close target as % of balance instead of absolute money: target = base + (openCount/divisor) x base. Makes the growing-target exit portable across cent/USD accounts. |
| `_57_DynCloseBase` | _57_DynCloseOn=true | _57_DynCloseDivisor | Base dollar target for the dynamic close-money formula. |
| `_57_DynCloseDivisor` | _57_DynCloseOn=true | _57_DynCloseBase | Divisor controlling how fast the dynamic close target grows per additional open order. |
| `_57_DynCloseOn` | always checked; StackMode != 93 also applies since Exit_ManagePartialClose/Exit_ManageBasket gate the same way for basket exits generally, but this specific check has no StackMode gate of its own | _57_DynCloseBase; _57_DynCloseDivisor; evaluated ALONGSIDE (not replacing) _2_BasketTP_Money/_2_BasketTP_ATRmult per the code comment - whichever target the basket profit reaches first closes it | Enables a dynamic basket-close target that grows with the number of open orders (close_target = base + (openCount/divisor)*base), evaluated as an additional/alternative check next to the fixed/ATR basket TP. |
| `ExitMode` | always - selects the exit sub-mode for every build | _21_TP_Pip(21); _22_TP_ATRmult(22); _23_TrailStart+_23_TrailStep(23, and Wave5_TightenTrail on build17); _0_FastMA/_0_SlowMA(24, RunTrend uses shared trend MA) | Selects which mechanism decides when to close a leg/basket: fixed pip(points) TP, ATR-multiple TP, trailing stop, or MA-cross run-trend close. |
| `SLMode` | always, EXCEPT build17 which overrides the whole switch when _17_UseStructLevels+g_wave5_sl_price are set (guard G2) | _31_SL_Pip(31); _33_SL_ATRmult+_33_SL_MaxPips+_33_SL_MaxATRmult+_33_AdaptiveON+_33_AdaptiveN(33); _34_DonchianBars(34); _35_SRBars(35); _36_SD_Mult+_36_SD_Period(36); note SLMode=32(SL_MONEY) falls into the switch's default branch and returns 0 - it produces NO per-order price SL by itself, the basket-level stop actually comes from _32_SL_Money independently of this enum | Selects the per-order stop-loss calculation: none, fixed pip(points), basket-money(no-op here), ATR-multiple(+adaptive), Donchian break, swing S/R break, or StdDev band. |

### exit/mm

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_3_RiskATR_TF` | same as _3_RiskATR_Period | _3_RiskATR_Period | Timeframe the Risk-ATR is computed on. |

### exit/mm (risk ATR)

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_3_RiskATR_Period` | handle always built; functionally consumed wherever Indi_RiskATR()/Exit_RiskATR_Scaled() is read: SL_ATR/EXIT_ATR_TP calcs, Recovery.mqh trigger/step distances, Kangaroo SL/TP dollar calcs | _3_RiskATR_TF | Period for the 'Risk-ATR' context (SL/TP/sizing), distinct from the Signal-ATR context used for entry/stack timing. |

### exit/safety

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_32_SL_BalPct` | this value >0; independent of SLMode (basket-level stop, checked unconditionally). Wins over _32_SL_Money when set (ExitManager.mqh:526) | _32_SL_Money(OVERRIDDEN when this is >0); SLMode(unrelated - see the _32_SL_Money row); RC_KillDDPct(the cage hard-kill still fires independently and usually first) | Basket-level money STOP expressed as % of current balance: force-closes the whole basket once floating loss reaches it. Portable across cent/USD and scales with the account. |
| `_32_SL_Money` | this value >0 - independent of SLMode (this is a basket-level stop, checked unconditionally in Exit_SafetyMoneyStop/Exit_ManageBasket regardless of which SLMode is selected) | SLMode(indirect note: SLMode==SL_MONEY(32) itself produces NO per-order price SL - Exit_SLDistancePoints/Exit_InitialSL both hit the 'default: return 0' branch for that enum value - the real protection when SLMode=32 is chosen comes entirely from this input, which the code checks independently of the enum) | Basket-level money stop-loss: force-closes the whole basket once floating loss reaches this; runs both intrabar (safety) and per-tick (management). |

### hedge

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_H_MaxLot` | HedgeMode != HEDGE_OFF(0), AND this value >0 | _H_Ratio; RC_MaxLot(applies regardless, via Exec_Open) | Explicit hedge-lot ceiling beyond the generic RC_MaxLot cage clamp. |
| `_H_Ratio` | HedgeMode != HEDGE_OFF(0), AND the trigger has fired | _H_MaxLot(cap on the result); RC_MaxLot(final cage clamp via Exec_Open) | Hedge lot size as a ratio of net directional exposure (excluding existing hedge legs). |
| `_H_ReleaseDDPct` | HedgeMode != HEDGE_OFF(0), AND a hedge leg is currently open | _H_TriggerDDPct | Basket floating DD% the position must recover to before the hedge is released (closed). |
| `_H_TriggerDDPct` | HedgeMode != HEDGE_OFF(0) | _H_ReleaseDDPct(hysteresis pair) | Basket floating DD% (of balance) that opens the defensive hedge leg. |
| `HedgeMode` | HedgeMode != HEDGE_OFF(0) AND StackMode != STACK_PYRAMID(93, LabCore.mqh skips Hedge_OnTick under mode 93) | _H_TriggerDDPct; _H_ReleaseDDPct; _H_Ratio; _H_MaxLot; RC_MaxLot(final clamp via Exec_Open) | Enables an opposite-direction defensive hedge leg once basket floating DD% breaches the trigger; releases on DD recovery. |

### mm

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_16_BaseLot` | build 16 only | _16_LadderMult(gates whether this stays flat); _16_MaxLotPerOrder; RC_MaxLot(final cage clamp) | Flat lot used for every order while _16_LadderMult<=1.0 (probe finding cited in the inline comment: flat-lot beat the x1.5 ladder, PF 5.71 vs 4.86). |
| `_16_BaseLotMode` | build 16 only - Kangaroo owns the entry-16 lot law and LabCore short-circuits before MM_FirstLot, so the chassis FirstLotMode never applies here | _16_BaseLot(mode 0); _43_LotPerAnchor + _43_BalanceAnchor(mode 1, shared with chassis FirstLotMode=43); _16_LadderMult and _16_MaxLotPerOrder(applied AFTER this); RC_MaxLot(final clamp) | Chooses the entry-16 BASE order size: 0 = flat _16_BaseLot (default, unchanged), 1 = balance-scaled via the mode-43 anchor pair so the base order tracks account size. The ladder and the cage still apply on top either way. |
| `_16_LadderMult` | build 16 only, AND have>=4 | _16_BaseLot; _16_MaxLotPerOrder | >1.0 enables a capped ladder: order N = current max open lot x this multiplier; the first 4 orders on a side are always _16_BaseLot. |
| `_16_MaxLotPerOrder` | build 16 only, AND _16_LadderMult>1.0 | _16_LadderMult; RC_MaxLot(clamps after this) | Per-order lot ceiling for the ladder (original 'Max_Lot_Martingale'); RC_MaxLot still clamps after this. |
| `_4_DdAdaptiveOn` | always checked; no-op (multiplier stays 1.0) when false | _4_DdTier1Pct/_4_DdTier1Mult; _4_DdTier2Pct/_4_DdTier2Mult; _4_DdHardCapMult | Enables a DD-tiered first-lot multiplier applied only to a NEW basket's level-0 order (Zeus GridLog _05_DdAdaptive port). |
| `_4_DdHardCapMult` | _4_DdAdaptiveOn=true | _4_DdTier1Mult; _4_DdTier2Mult | Hard ceiling the DD-adaptive multiplier can never exceed, regardless of DD depth. |
| `_4_DdTier1Mult` | _4_DdAdaptiveOn=true, AND DD >= _4_DdTier1Pct (and < _4_DdTier2Pct) | _4_DdTier1Pct; _4_DdHardCapMult(final clamp) | Level-0 lot multiplier applied at the first DD tier. |
| `_4_DdTier1Pct` | _4_DdAdaptiveOn=true | _4_DdTier1Mult; _4_DdTier2Pct(the two tiers are compared in sequence, tier2 checked first) | First DD% threshold; once account DD is at least this deep at the moment a new basket opens, the level-0 lot is scaled by _4_DdTier1Mult. |
| `_4_DdTier2Mult` | _4_DdAdaptiveOn=true, AND DD >= _4_DdTier2Pct | _4_DdTier2Pct; _4_DdHardCapMult | Level-0 lot multiplier applied at the second, deeper DD tier. |
| `_4_DdTier2Pct` | _4_DdAdaptiveOn=true | _4_DdTier2Mult | Second, deeper DD% threshold at which _4_DdTier2Mult applies instead of tier1. |
| `_41_FixedLot` | FirstLotMode==FIRSTLOT_FIXED(41) ONLY. It stopped being the cross-mode fallback in MM-SAFETY-001 (2026-07-24): modes 42/43 that cannot size now skip the order instead of borrowing this value | FirstLotMode; _4_DdAdaptive*(multiplier applied after); RC_MaxLot(final clamp) | Fixed first-order lot size. Must be > 0 when mode 41 is selected - MM_ConfigValid fails the attach otherwise. |
| `_42_RiskPct` | FirstLotMode==FIRSTLOT_RISK(42). The SLMode pairing is checked ONCE at OnInit (SLMode 30 NONE / 32 MONEY yield no distance -> INIT_FAILED); at runtime a tick that cannot produce a distance skips the order | FirstLotMode; SLMode(must be 31/33/34/35/36, or build17 _17_UseStructLevels); _4_DdAdaptive*(multiplier applied after); RC_MaxLot(final clamp) | First-order risk % of balance, converted to a lot size via the current SL distance. This is the only mode that is genuinely 'risk X% per order' - and only when the order really carries that SL. |
| `_43_BalanceAnchor` | FirstLotMode==FIRSTLOT_BALANCE(43) only - inert under 41/42, and inert on build 16 (Kangaroo lot law) | _43_LotPerAnchor(the pair is meaningless alone); FirstLotMode; RC_MaxLot(final clamp) | Denominator of the balance-scaled first lot. ACCOUNT-SPECIFIC: a cent account showing a $1000 deposit as 100000 needs anchor=100000. The RATIO is portable, this number is NOT - one .set cannot serve USD and cent accounts without changing it (see the Account Profile table in EA_CORE_AND_TEMPLATE_GUIDE.md). |
| `_43_LotPerAnchor` | FirstLotMode==FIRSTLOT_BALANCE(43) only - inert under 41/42, and inert on build 16 (Kangaroo lot law) | _43_BalanceAnchor(the pair is meaningless alone); FirstLotMode; _4_DdAdaptive*(multiplier applied after); RC_MaxLot(final clamp); LotProg 5x + RecoveryMode 8x both compound off the result | Numerator of the balance-scaled first lot: lot = _43_LotPerAnchor x (balance / _43_BalanceAnchor). Doubling it doubles every first order at the same balance. |
| `_51_ProgFactor` | LotProg is PROG_LINEAR(51) or PROG_LOG(54) | LotProg | Growth coefficient shared by the linear and log lot-progression modes. |
| `_52_ProgMult` | LotProg==PROG_MULTIPLIER(52) | LotProg; RC_RecMultMax(clamps this before it is applied - MM_NextLot clamps m to RC_RecMultMax before MathPow) | Per-level multiplier for the martingale-style progression (lot = firstLot * mult^level); clamped by RC_RecMultMax before use. |
| `_53_PlusLot` | LotProg==PROG_PLUS(53) | LotProg | Additive lot increment per stack level (lot = firstLot + plus*level). |
| `_55_LogPowerFactor` | LotProg==PROG_LOG_POWER(55) | _55_UseLnNotLog10; LotProg | Power-law base for the log-power progression (Zeus GridLog port): lot = firstLot * factor^(ln or log10 of orderN). |
| `_55_UseLnNotLog10` | LotProg==PROG_LOG_POWER(55) | _55_LogPowerFactor | Selects natural log vs log10 for the log-power progression exponent. |
| `_56_FibMaxStep` | LotProg==PROG_FIBONACCI(56) | LotProg | Caps the Fibonacci lot-progression multiplier at the value reached by this step index, so growth stops instead of continuing unbounded. |
| `FirstLotMode` | always - decides first-order sizing. Build 16 EXCEPTED: Kangaroo owns its lot law (_16_BaseLot) and LabCore short-circuits before MM_FirstLot, so every mode is inert there (MM_ConfigValid prints an INIT WARN) | _41_FixedLot(41); _42_RiskPct + SLMode(42 - SLMode must yield a distance; the combination is validated at OnInit, not at order time); _43_LotPerAnchor + _43_BalanceAnchor(43); _4_DdAdaptiveOn+tiers(multiplies the result of ALL three modes); RC_MaxLot(final clamp) | Switches level-0 lot sizing between a fixed lot, risk%-of-balance sized off the SL distance, and balance-anchored linear scaling. Since MM-SAFETY-001 (2026-07-24) an unusable config FAILS the attach (INIT_FAILED) and a runtime data failure SKIPS the order - it no longer degrades to _41_FixedLot silently. |
| `LotProg` | have>0 (stacked/added orders only - level-0 lot is untouched by this) | _51_ProgFactor(51,54); _52_ProgMult(52, clamped by RC_RecMultMax); _53_PlusLot(53); _55_LogPowerFactor+_55_UseLnNotLog10(55); _56_FibMaxStep(56) | Chooses how lot size grows across stacked orders: flat, linear, multiplier(martingale, cage-clamped), additive-plus, log, log-power, or capped Fibonacci. |

### recovery

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_8_DDRefBalPct` | RecoveryMode==REC_ADAPTIVE(82) AND this value >0. Wins over _8_DDRefMoney (Recovery.mqh:54-55) | _8_DDRefMoney(OVERRIDDEN when this is >0); RC_RecMultMax(clamps the resulting multiplier) | Reference basket loss - as % of balance - that maps to a +1.0x add-lot multiplier for the ENGINE-EDGE mode-82 escalation: mult = 1 + basketDD/ref. Keeps the escalation curve from silently steepening after a deposit, which a fixed $100 reference does. |
| `_8_DDRefMoney` | RecoveryMode==REC_ADAPTIVE(82) | RC_RecMultMax(final clamp on the resulting multiplier) | Reference $ of current basket loss that maps to +1.0x add-lot multiplier for RecoveryMode 82 (ENGINE-EDGE class): mult = 1 + basketDD/this, clamped by RC_RecMultMax. |
| `_8_RecMult` | RecoveryMode==REC_AGGRESSIVE(83) | RC_RecMultMax(clamps this before MathPow is applied) | Per-step multiplier for the geometric MathPow(m,rstep) escalation used by RecoveryMode 83 (ENGINE-EDGE class); clamped by RC_RecMultMax before use. |
| `_8_StepATR` | RecoveryMode != REC_NONE(80) | _8_TriggerATR | Further adverse distance (in Risk-ATR multiples) per additional recovery add once triggered. |
| `_8_TriggerATR` | RecoveryMode != REC_NONE(80) | RecoveryMode; _3_RiskATR_Period/_3_RiskATR_TF(the ATR this multiplies) | Adverse excursion (in Risk-ATR multiples) beyond the worst entry required before Recovery starts adding. |
| `RecoveryMode` | RecoveryMode != REC_NONE(80) AND basket exists+losing AND StackMode != STACK_PYRAMID(93, LabCore.mqh skips Recovery_OnTick under mode 93) | _8_TriggerATR; _8_StepATR; _8_RecMult(83 only); _8_DDRefMoney(82 only); RC_RecMultMax(cage clamp on both 82 and 83); RC_MaxLevelsOverride/_9_MaxLevels(depth cap shared with Stack) | Enables offensive add-into-loss escalation: 81=flat add (no escalation), 82=DD-scaled multiplier add, 83=geometric MathPow(mult,step) escalation. |

### safety

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_16_EmergencyDDPct` | build 16 only, AND this value >0 AND at least one order is open | RiskControl_CurrentDDPct(); ProtectLevel's RC_KillDDPct() usually fires first at default profile (25% < 70%) | Emergency close-all-basket threshold on equity DD% from peak; a backstop below the cage's own KillDD for loosened-cage configurations. |
| `ProtectLevel` | always | implicitly gates the default effective values of KillDD/DepositLoad/MaxRecSteps unless RC_MaxLevelsOverride overrides the steps component | Selects the whole safety-cage profile in one dropdown: hard-kill equity-DD threshold, max deposit-load%, and max recovery/stack step depth. |
| `RC_AcctDDLimitPct` | this value >0 | g_rc_acct_hwm(persisted high-water mark) | Account-level DD gate: blocks NEW first-entries (not existing baskets/adds) once equity sits this % below its persisted high-water mark. |
| `RC_AdoptLegacyHalt` | only matters if a legacy pre-132 magic-only GlobalVariable key exists for this scope (active kill/halt, rc_peak_eq, or acct_hwm) - otherwise a pure no-op | RC_PersistHalt(legacy keys are only checked when this is also true) | One-time consent flag to migrate a pre-ORDER-132 magic-only halt/kill/peak-equity state into the new account-scoped keys; without it, OnInit fails closed (INIT_FAILED) rather than risk adopting another account's state. |
| `RC_MaxLevelsOverride` | this value >0 | RC_MaxRecSteps(driven by ProtectLevel - the value this overrides); _9_MaxLevels(still takes the min against this) | When >0, decouples stack/recovery depth from ProtectLevel's implicit step cap (2/3/5), letting a grid-heavy entry go deeper while KillDD/DepositLoad still come from ProtectLevel untouched. |
| `RC_MaxLot` | always - applied as the LAST step on every lot calculation in the codebase, cannot be bypassed by any mode/progression | every lot-sizing input in the file, indirectly (this is the supreme ceiling above all of them) | Absolute per-order lot ceiling; the final clamp applied after every other sizing/progression/adaptive calculation. |
| `RC_PersistHalt` | always - default true means every module attempts durable persistence; false switches those modules to memory-only semantics for NEW intents (existing/legacy intent cleanup is explicitly NOT gated on this per several ORDER-138c comments) | interacts with RC_AdoptLegacyHalt(migration logic) and every persisted safety state in the codebase | When true (default), hard-kill/halt state and in-flight close-all intents survive a restart/recompile via terminal GlobalVariables; false reverts to memory-only semantics for new intents (manual un-halt route). |
| `RC_RecMultMax` | LotProg==PROG_MULTIPLIER(52), OR RecoveryMode is 82 or 83 | LotProg; RecoveryMode | Caps the effective escalation multiplier for BOTH the martingale lot-progression AND the RecoveryMode 82/83 ENGINE-EDGE escalation - the single cage that keeps both from becoming unbounded. |

### stack

| parameter | active when | coupled with | what it does |
|---|---|---|---|
| `_16_AtrMultAfter` | build 16 only, AND have>=4 open on this side | _16_AtrMultFirst4; _16_MinDistPips | Wider grid spacing multiplier from the 5th order on (original: 350 fixed pips). |
| `_16_AtrMultFirst4` | build 16 only, AND have<4 open on this side | _16_AtrMultAfter; _16_MinDistPips(floor) | Grid spacing multiplier on Signal-ATR while fewer than 4 orders are open on the side (original: 200 fixed pips). |
| `_16_MaxOrdersPerSide` | build 16 only | RC_MaxLot/RiskControl_AllowNewOrder(deposit-load cage still applies on top) | Hard cap on grid adds per side (original advertised 10 but reportedly leaked to 14 in the source). |
| `_16_MinDistPips` | build 16 only | _16_AtrMultFirst4; _16_AtrMultAfter | Pip floor under the ATR-derived grid spacing. |
| `_9_MaxLevels` | always | RC_MaxLevelsOverride / RC_MaxRecSteps(ProtectLevel) - effective cap = min(cage cap, this) | Caps the total number of stacked/added orders in a basket (still bounded above by the cage's RC_MaxLevelsOverride/RC_MaxRecSteps). |
| `_9_PA_MinBodyRatio` | StackConfirm == CONF_PA_ENGULF(4) - not a default value on any build; opt-in via .set | StackConfirm(any build's Stack.mqh flow, mode 91/92 only) | Minimum ratio of signal-candle body to prior-candle body required for an engulfing pattern to confirm a grid add. |
| `_9_PendingLegs` | StackMode==93 AND _9_PendingMode is 2 or 3 | _9_PendingMode; capped by RiskControl_MaxLevels()-1 and STACK_MAX_LEGS(63) | Number of resting pending legs placed beyond leg0 in the mode-93 ladder. |
| `_9_PendingMode` | StackMode == STACK_PYRAMID(93) | StackMode; _9_PendingLegs; RiskControl_MaxLevels() | Selects the pending-ladder leg type for mode 93: off, LIMIT scale-in, or STOP pyramid. |
| `_9_RegimeGateAdds` | true AND _50_RegimeMode != 0 (else Regime_AllowsEntryDirection is a permissive no-op) | _50_RegimeMode; _50_AllowTrendUp/Down/Range | When true, extends the Regime market-state gate to also block grid/stack ADDS, not just the flat first entry (closes the AdaptiveGrid_Oil finding gap). |
| `_9_StepATRmult` | _9_StepUseATR=true | _9_StepUseATR; _9_StepMinPips(floor); _9_StepATRShift(which ATR bar) | Multiplier on Signal-ATR that sets the stack/pyramid grid step distance. |
| `_9_StepATRShift` | _9_StepUseATR=true | _9_StepATRmult | Chooses which Signal-ATR bar-shift feeds the step calc: 0=forming bar (Boss_11/12/13 legacy), 1=last closed bar (matches standalone Zeus GetATR(1) parity). |
| `_9_StepMinPips` | _9_StepUseATR=true AND this value >0 (acts as a floor under the computed ATR step) | _9_StepATRmult | Sets a minimum pip floor under the ATR-derived grid step so near-zero-ATR periods cannot produce a degenerate (near-zero) spacing. |
| `_9_StepPoints` | _9_StepUseATR=false, or as the fallback floor when the ATR-derived step computes <=0 | _9_StepUseATR | Fixed-points step size used when ATR-based spacing is off (or as an emergency floor). |
| `_9_StepUseATR` | StackMode is 91/92 (Stack_DecideAdd) or 93 (Stack_ManagePyramid) - i.e. wherever Stack_StepPrice() is called; does NOT affect Entry_GridLog.mqh's own independent arm-distance calc (build 14's first-entry arming uses its own Entry_GridLog_DistPrice, not this) | _9_StepATRmult(true branch); _9_StepPoints(false branch, and as a floor fallback if the ATR step computes <=0) | Chooses whether stack/pyramid grid spacing derives from Signal-ATR or a fixed points value. |
| `StackConfirm[LAB_ENTRY_11]` | build 11 only, AND only functionally consulted when the compiled/.set StackMode value is 91 or 92 (Stack_DecideAdd returns false before this for 90/93) | StackMode[LAB_ENTRY_11]; _9_PA_MinBodyRatio(mode 4 only) | Chooses the extra confirmation gate an add must pass beyond raw distance: none / signal-still-valid / re-trigger / bar-close-beyond-level / engulfing-candle. |
| `StackConfirm[LAB_ENTRY_12]` | build 12 only, only consulted if a .set overrides StackMode to 91/92 (default StackMode=90 never reaches this check) | StackMode[LAB_ENTRY_12] | Confirmation gate for adds, inert at this build's default StackMode. |
| `StackConfirm[LAB_ENTRY_13]` | build 13 only, functionally live at default (StackMode=92) | StackMode[LAB_ENTRY_13] | Confirmation gate for DCA adds (default = require closed-bar close beyond the trigger level, not just a wick). |
| `StackConfirm[LAB_ENTRY_14]` | build 14 only, functionally live at default (StackMode=92) | StackMode[LAB_ENTRY_14] | Confirmation gate for grid adds (default = blind distance-only, matching the standalone Zeus grid). |
| `StackConfirm[LAB_ENTRY_15]` | build 15 only, only consulted if a .set overrides StackMode to 91/92 | StackMode[LAB_ENTRY_15] | Confirmation gate for adds, inert at this build's default StackMode. |
| `StackConfirm[LAB_ENTRY_16]` | NEVER (see StackMode[LAB_ENTRY_16]) | StackMode[LAB_ENTRY_16] | Has no effect on build 16 under any .set value. |
| `StackConfirm[LAB_ENTRY_17]` | build 17 only, only consulted if a .set overrides StackMode to 91/92 (breaks the naked-probe guard if done) | StackMode[LAB_ENTRY_17] | Confirmation gate for adds, inert at this build's default StackMode. |
| `StackConfirm[LAB_ENTRY_18]` | build 18 only, functionally live at default (StackMode=92) | StackMode[LAB_ENTRY_18] | Confirmation gate for DCA adds (default = distance-only base; the A/B plan flips this to engulfing). |
| `StackMode[LAB_ENTRY_11]` | build 11 only - compile-time default STACK_GRID_TREND(91) for this build, overridable via .set | StackConfirm[LAB_ENTRY_11]; _9_MaxLevels; RC_MaxLevelsOverride; if set to 93: also _9_PendingMode/_9_PendingLegs, and disables Recovery/Hedge/partial-close for that basket (LabCore.mqh explicit skip) | Selects how added orders stack for this build: never-add / trend-following grid / against-trend DCA / pending pyramid ladder. |
| `StackMode[LAB_ENTRY_12]` | build 12 only - compile-time default STACK_SINGLE(90) | StackConfirm[LAB_ENTRY_12]; _9_MaxLevels; RC_MaxLevelsOverride | Selects how added orders stack for this build (default = never add, one order per signal). |
| `StackMode[LAB_ENTRY_13]` | build 13 only - compile-time default STACK_GRID_AGAINST(92) | StackConfirm[LAB_ENTRY_13]; _9_MaxLevels; RC_MaxLevelsOverride | Selects how added orders stack for this build (default = DCA/average-down grid). |
| `StackMode[LAB_ENTRY_14]` | build 14 only - compile-time default STACK_GRID_AGAINST(92) | StackConfirm[LAB_ENTRY_14]; _9_MaxLevels; RC_MaxLevelsOverride; note Entry_GridLog.mqh's own arm-and-wait distance logic is independent of Stack_StepPrice()/this mode - only the STACK adds route through Stack.mqh | Selects how added orders stack for GridLog (default = adverse-move grid, matching the standalone Zeus source). |
| `StackMode[LAB_ENTRY_15]` | build 15 only - compile-time default STACK_SINGLE(90) | StackConfirm[LAB_ENTRY_15]; _9_MaxLevels; RC_MaxLevelsOverride | Selects how added orders stack (default = one order per edge signal, no grid). |
| `StackMode[LAB_ENTRY_16]` | NEVER - the source comment on this declaration explicitly says 'informational only - Kangaroo.mqh owns its own grid pipeline (LabCore short-circuits)' | none - no other input changes this | Has no effect on build 16 under any .set value; Kangaroo.mqh's own hand-rolled add/exit pipeline (_16_* inputs) is the real stack engine for this build. |
| `StackMode[LAB_ENTRY_17]` | build 17 only - compile-time default STACK_SINGLE(90), naked probe (no grid/recovery/martingale per ORDER-082 guard G4) | StackConfirm[LAB_ENTRY_17]; _9_MaxLevels; RC_MaxLevelsOverride | Selects how added orders stack (default = single order, structural mode is a naked probe by design). |
| `StackMode[LAB_ENTRY_18]` | build 18 only - compile-time default STACK_GRID_AGAINST(92) | StackConfirm[LAB_ENTRY_18]; _9_MaxLevels; RC_MaxLevelsOverride | Selects how added orders stack for JumStoch (default = DCA grid, matching the standalone Range grid). |

---

Total parameter rows across the context sections above: 184 (must equal the source registry's 184 rows, each appearing exactly once - context is a single-valued column so grouping by it partitions the rows).

Override pairs found: 11.
