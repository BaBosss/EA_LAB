//+------------------------------------------------------------------+
//| Inputs.mqh (V2) - numbered dropdown surface for Boss Lab chassis. |
//| enum VALUE = code (MT5 report shows raw int -> scannable).        |
//| param names = _NN_  (NN = category code) so optimize/.set ไล่ง่าย.|
//| MUST be included first. LAB_ENTRY (11/12/13) set by the wrapper.  |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_INPUTS_MQH
#define BOSS_LAB_INPUTS_MQH

// wrapper defines ONE of: LAB_ENTRY_11 / _12 / _13 / _14 / _15 / _16 / _17 / _18 (+ LAB_ENTRY_TAG)
// MQL5 preprocessor has no '#if EXPR==n' / '#elif' -> use token #ifdef only.
#ifndef LAB_ENTRY_11
#ifndef LAB_ENTRY_12
#ifndef LAB_ENTRY_13
#ifndef LAB_ENTRY_14
#ifndef LAB_ENTRY_15
#ifndef LAB_ENTRY_16
#ifndef LAB_ENTRY_17
#ifndef LAB_ENTRY_18
#define LAB_ENTRY_11          // fallback build
#endif
#endif
#endif
#endif
#endif
#endif
#endif
#endif

//==================== ENUMS (value = code) =========================
enum ENUM_EXIT_MODE
{
   EXIT_FIXED_TP  = 21,   // 21 Fixed TP (pip)
   EXIT_ATR_TP    = 22,   // 22 ATR TP (Risk-ATR x mult)
   EXIT_TRAIL     = 23,   // 23 Trailing stop
   EXIT_RUN_TREND = 24    // 24 Run trend (close basket on MA reverse)
};

enum ENUM_SL_MODE
{
   SL_NONE            = 30,  // 30 None
   SL_FIXED_POINTS    = 31,  // 31 Fixed pip
   SL_MONEY           = 32,  // 32 Basket money stop
   SL_ATR             = 33,  // 33 Risk-ATR x mult (opt adaptive)
   SL_STRUCT_DONCHIAN = 34,  // 34 Donchian break
   SL_STRUCT_SR       = 35,  // 35 Swing S/R break
   SL_SD              = 36   // 36 StdDev band (n x SD)
};

enum ENUM_FIRST_LOT_MODE
{
   FIRSTLOT_FIXED = 41,   // 41 Fixed lot
   FIRSTLOT_RISK  = 42    // 42 Risk% / SL distance (ATR-sized)
};

enum ENUM_LOT_PROGRESSION
{
   PROG_NONE       = 50,  // 50 None (same lot)
   PROG_LINEAR     = 51,  // 51 Linear  lot*(1+f*lv)
   PROG_MULTIPLIER = 52,  // 52 Multiplier lot*m^lv (martingale)
   PROG_PLUS       = 53,  // 53 Plus  lot+plus*lv
   PROG_LOG        = 54,  // 54 Log  lot*(1+f*ln(lv+1))
   PROG_LOG_POWER  = 55,  // 55 LogPower  lot*factor^(ln(orderN)) - Zeus GridLog port (14)
   PROG_FIBONACCI  = 56   // 56 Fibonacci  lot*fib(lv), capped at _56_FibMaxStep (corpus EX191)
};

enum ENUM_TRADE_DIR
{
   TRADEDIR_BOTH       = 60,  // 60 Both
   TRADEDIR_LONG_ONLY  = 61,  // 61 Long only
   TRADEDIR_SHORT_ONLY = 62   // 62 Short only
};

enum ENUM_TREND_FILTER
{
   TFILTER_NONE       = 70,  // 70 None
   TFILTER_ATR_EXPAND = 71,  // 71 ATR expanding (vol gate)
   TFILTER_MA_SLOPE   = 72   // 72 MA slope confirms
};

enum ENUM_RECOVERY_MODE
{
   REC_NONE       = 80,  // 80 None
   REC_LIGHT      = 81,  // 81 Light (capped by cage)
   REC_ADAPTIVE   = 82,  // 82 Adaptive (stub)
   REC_AGGRESSIVE = 83   // 83 Aggressive (stub, gated)
};

enum ENUM_STACK_MODE
{
   STACK_SINGLE       = 90,  // 90 Single (one order per signal)
   STACK_GRID_TREND   = 91,  // 91 Grid trend (add as trend extends)
   STACK_GRID_AGAINST = 92,  // 92 Grid against (DCA / average down)
   STACK_PYRAMID      = 93   // 93 Pending ladder (ScaleExecutor_v2 port, MERGE-03)
};

enum ENUM_STACK_CONFIRM
{
   CONF_DISTANCE   = 0,  // 0 Distance only (blind)
   CONF_SIG_VALID  = 1,  // 1 Distance + signal still valid (= V1)
   CONF_RETRIGGER  = 2,  // 2 Distance + signal re-trigger
   CONF_PRICE_ACT  = 3,  // 3 Distance + bar CLOSE beyond level (PA)
   CONF_PA_ENGULF  = 4   // 4 Distance + engulfing candle in the ADD direction (PriceAction.mqh)
};

enum ENUM_PROTECT_PROFILE
{
   PROTECT_TIGHT  = 1,  // 01 Tight  (KillDD15 Load20 Steps2)
   PROTECT_NORMAL = 2,  // 02 Normal (KillDD25 Load30 Steps3)
   PROTECT_LOOSE  = 3   // 03 Loose  (KillDD40 Load50 Steps5) grid only
};

enum ENUM_HEDGE_MODE
{
   HEDGE_OFF  = 0,  // 0 off (default)
   HEDGE_LOCK = 1   // 1 opposite-direction lock on basket DD breach
};

//==================== Mode selectors ===============================
input group "=== Mode selectors (code = value) ==="
input ENUM_EXIT_MODE       ExitMode      = EXIT_ATR_TP;     // Exit 2x
input ENUM_SL_MODE         SLMode        = SL_ATR;          // SL 3x
input ENUM_FIRST_LOT_MODE  FirstLotMode  = FIRSTLOT_FIXED;  // FirstLot 4x
input ENUM_LOT_PROGRESSION LotProg       = PROG_NONE;       // Progression 5x
input ENUM_TRADE_DIR       TradeDir      = TRADEDIR_BOTH;   // Direction 6x
input ENUM_TREND_FILTER    TrendFilter   = TFILTER_NONE;    // Filter 7x
input ENUM_RECOVERY_MODE   RecoveryMode  = REC_NONE;        // Recovery 8x
input ENUM_HEDGE_MODE      HedgeMode     = HEDGE_OFF;
input bool                 DryRun        = false;           // log intents, no orders
input bool                 _0_BarOpenOnly = false;          // evaluate whole OnTick pipeline once per bar (Zeus-style; false = every tick, unchanged)

//==================== Stack (9x) - per-build defaults ==============
input group "=== 9x Stack (how orders stack) ==="
#ifdef LAB_ENTRY_11
input ENUM_STACK_MODE    StackMode    = STACK_GRID_TREND;   // 91 default for Grid
input ENUM_STACK_CONFIRM StackConfirm = CONF_SIG_VALID;     // 1
#endif
#ifdef LAB_ENTRY_12
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // 90 default for Breakout
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a for single
#endif
#ifdef LAB_ENTRY_13
input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST; // 92 default for MR (DCA)
input ENUM_STACK_CONFIRM StackConfirm = CONF_PRICE_ACT;     // 3 (DCA needs strong confirm)
#endif
#ifdef LAB_ENTRY_14
input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST; // 92 default for GridLog (adds vs adverse move)
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // 0 (Zeus grid add = distance only, blind)
#endif
#ifdef LAB_ENTRY_15
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // 90 default for ST03 (one order per edge signal)
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a for single
#endif
#ifdef LAB_ENTRY_16
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // informational only - Kangaroo.mqh owns its own grid pipeline (LabCore short-circuits)
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a (Kangaroo adds are distance-only by design)
#endif
#ifdef LAB_ENTRY_17
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // 90 naked probe (Wave5): single order per signal, no grid/recovery/martingale
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a for single
#endif
#ifdef LAB_ENTRY_18
input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST; // 92 DCA for JumStoch (adds vs adverse move - matches standalone Range grid)
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // 0 distance-only base (A/B flips to CONF_PA_ENGULF)
#endif
input bool   _9_StepUseATR  = true;     // grid step from Signal-ATR (else points)
input double _9_StepATRmult = 1.0;      // step = mult x Signal-ATR
input double _9_StepPoints  = 300;      // step when not ATR
input double _9_StepMinPips = 0;        // additive: pips floor under the ATR step (0=off). Zeus GridLog _03_MinDistPips.
input int    _9_StepATRShift = 0;       // additive: Signal-ATR shift for the step calc (0=current/forming bar,
                                         // matches Boss_11/12/13 unchanged default; 1=last CLOSED bar, matches
                                         // standalone Zeus GetATR(1) - GridLog(14) parity .set uses 1).
input int    _9_MaxLevels   = 5;        // max stacked orders
// additive (AdaptiveGrid_Oil finding 2026-07-17): gate grid ADDS by the 5x Regime
// module too, not just the flat seed. The Regime gate in LabCore only blocks the
// FIRST (flat) entry; a grid is almost never flat, so adds sail through unfiltered.
// When true, Stack_DecideAdd refuses to extend a basket whose direction the Regime
// disallows (reuses the ADX Regime; needs _50_RegimeMode!=0 to have any effect).
// Default false = behaviour byte-identical to before. See EDGE_CATALOG "add-gating".
input bool   _9_RegimeGateAdds = false;
// additive (PriceAction Phase 0, 2026-07-18): body-size ratio for the engulfing
// used by StackConfirm=CONF_PA_ENGULF(4). 1.0 = classic (signal body >= prior body).
// Only read when StackConfirm=4; inert otherwise. Default keeps all EAs unchanged.
input double _9_PA_MinBodyRatio = 1.0;
// additive (MERGE-03, ScaleExecutor_v2 port): STACK_PYRAMID(93) pending ladder.
// Active ONLY when StackMode=93 - all other modes ignore these two inputs.
// Leg0 = normal market entry; legs 1..N = resting pendings at Stack_StepPrice()
// spacing, placed once per basket. Basket close (TP/SL/kill) cancels leftovers.
// One exit owner: basket TP/SL only - pendings carry per-leg SL, NEVER per-leg
// TP. Mode 93 also disables Recovery/Hedge/partial-close/market-adds (see board
// MERGE-02 synthesis: "one mode, one exit owner").
input int _9_PendingMode = 0;   // 93 only: 0=none (warn) / 2=LIMIT scale-in / 3=STOP pyramid
input int _9_PendingLegs = 0;   // 93 only: pendings after leg0 (capped by RiskControl_MaxLevels-1)

//==================== ENTRY params (compile-time guarded) ==========
#ifdef LAB_ENTRY_11
input group "=== 11 Entry: Grid Trend MA ==="
// NOTE: trend MA (FastMA/SlowMA) is shared - also used by 72 filter + 24 RunTrend.
//       defined in shared block below (_0_FastMA / _0_SlowMA).
#endif

#ifdef LAB_ENTRY_12
input group "=== 12 Entry: Breakout (Donchian) ==="
input int  _12_Bars        = 20;   // channel lookback
input int  _12_ConfirmBars = 1;    // closes beyond channel (0=tick)
input int  _12_HourFrom    = 0;    // session start UTC (0=no filter)
input int  _12_HourTo      = 0;    // session end UTC (wraps if From>To)
#endif

#ifdef LAB_ENTRY_13
input group "=== 13 Entry: Mean Reversion (BB+RSI) ==="
input int    _13_BB_Period  = 20;
input double _13_BB_Dev     = 2.0;
input int    _13_RSI_Period = 14;
input int    _13_RSI_OB     = 70;
input int    _13_RSI_OS     = 30;
input bool   _13_RequireBB  = true;
#endif

#ifdef LAB_ENTRY_14
input group "=== 14 Entry: GridLog (Zeus-inspired breakout-arm) ==="
input int    _14_Direction   = 1;      // 1=BUY only, 2=SELL only (fixed, never both - matches standalone)
input double _14_DistAtrMult = 1.5;    // arm/grid-step distance = mult x Signal-ATR
input double _14_MinDistPips = 20.0;   // floor under the ATR distance (pips; 3/5-digit symbols = 10xpoint)
#endif

#ifdef LAB_ENTRY_15
input group "=== 15 Entry: ST03 (MACD consecutive-count, StrategySignal_v4 port) ==="
input int  _15_MacdFast    = 12;    // MACD fast EMA (matches EA_RUNNER_ST03 defaults)
input int  _15_MacdSlow    = 26;    // MACD slow EMA
input int  _15_MacdSignal  = 9;     // MACD signal SMA
input int  _15_CountBars   = 2;     // consecutive closed bars in one MACD state before firing
input bool _15_EdgeTrigger = true;  // true=fire once per state-run (ST_EA03) / false=level (over-trades)
input int  _15_RearmBars   = 0;     // re-fire every K bars within a run (0=pure edge, 1~=level)
#endif

#ifdef LAB_ENTRY_16
// ORDER-072: KangarooInspired (Gold_Kangaroo behavioral rebuild, KANGAROO_LOGIC_NOTES.md).
// Entry 16 bypasses the standard LabCore pipeline entirely - Kangaroo.mqh is the single
// exit owner AND the single add owner (see that file's header). Only the cage
// (RiskControl hard-kill / deposit load / RC_MaxLot) stays supreme above it.
input group "=== 16 Entry: KangarooGrid (RSI fade, fixed direction) ==="
input int    _16_Direction   = 1;      // 1=BUY instance, 2=SELL instance (fixed, never both - bidirectional = 2 instances w/ own magic, Boss_14 pattern)
input int    _16_RsiPeriod   = 14;     // RSI period on chart TF
input double _16_RsiLow      = 30.0;   // BUY instance arms when RSI(closed bar) < this
input double _16_RsiHigh     = 70.0;   // SELL instance arms when RSI(closed bar) > this
input group "=== 16 Grid (ATR spacing, ADVERSE adds only, hard cap) ==="
input double _16_AtrMultFirst4    = 0.8;    // spacing = mult x Signal-ATR while side has < 4 orders (original: 200 fixed pips)
input double _16_AtrMultAfter     = 1.4;    // spacing mult from order 5 on (original: 350 fixed pips)
input double _16_MinDistPips      = 150.0;  // spacing floor in pips (digit-aware; XAU 2-digit: pip=point=$0.01)
input int    _16_MaxOrdersPerSide = 10;     // HARD cap - adds refused beyond this (original advertised 10 but leaked to 14)
input group "=== 16 Lots (FLAT default; capped ladder OFF at 1.0) ==="
input double _16_BaseLot        = 0.01;  // every order when LadderMult <= 1.0 (flat-lot probe beat the x1.5 ladder: PF 5.71 vs 4.86)
input double _16_LadderMult     = 1.0;   // >1.0 enables ladder: order N = max open lot x this; first 4 orders always BaseLot
input double _16_MaxLotPerOrder = 1.0;   // per-order ceiling for the ladder (= original Max_Lot_Martingale; RC_MaxLot still clamps after)
input group "=== 16 SL / Exits (Kangaroo engine = single exit owner) ==="
input double _16_SlAtrMult        = 18.0;   // per-order broker SL = mult x Risk-ATR (~$90 at gold-1800-era ATR)
input double _16_MaxSlPips        = 9000.0; // SL distance ceiling in pips, digit-aware (= original 9000 = $90 on XAU; 0=off)
input double _16_TpSingleAtrMult  = 0.35;   // exit 1: single open order closes at mult x Risk-ATR profit (~80 gold pips at ATR ~$2.3)
input double _16_BasketTpUsdPer01 = 16.0;   // exit 2: close whole side at net$ >= this x (total lots / 0.01) - dollar-true version of pip-sum 160
input double _16_OverlapMinUsd    = 5.0;    // exit 3: overlap pair-close (newest+oldest) when combined net$ >= this
input int    _16_OverlapMinOrders = 4;      // exit 3 active only from this many open orders
input bool   _16_FlattenOn            = false; // exit 4 (ladder_flatten, A/B module): default OFF per ORDER-072 decision 5
input int    _16_FlattenMinOrders     = 6;     // exit 4: allowed from this many open orders
input double _16_MaxControlledLossUsd = 400.0; // exit 4: close-all side once net$ >= -this (controlled-loss DD release)
input double _16_EmergencyDDPct       = 70.0;  // emergency close-all at equity DD% from peak (tighter than original's unverified 80; cage KillDD fires first at default profile)
#endif

#ifdef LAB_ENTRY_17
// ORDER-082: Wave5 - Elliott wave-4 retrace entry, arms to catch wave-5.
// Naked probe only (guard G4): StackMode=90 single, no grid/recovery/martingale.
// Swings come from in-code confirmed fractals (Wave5Swings.mqh) - built-in only,
// no iCustom/ZigZag (repaint ban). Structural SL/TP anchors published into the
// globals below (guard G1: declared here so ExitManager, included before
// entries in LabCore, can compile against them).
input group "=== 17 Entry: Wave5 (Elliott wave-4 retrace arm, both directions) ==="
input int    _17_FractalDepth   = 3;      // confirmed-fractal bars each side (repaint guard: newest usable pivot is always >= this many bars back)
input double _17_Wave3MinMult   = 0.618;  // wave-3 confirm: must run >= this x |wave1| beyond the wave-1 break (permissive default - Fable D2, our addition)
input double _17_EntryFib       = 38.2;   // wave-4 zone arm level, % retrace of wave3 (sweep {23.6,38.2,50,61.8})
input double _17_SLbufferATR    = 0.5;    // SL = wave-1 top/bottom +/- this x Risk-ATR buffer (absorbs spread/wick)
input bool   _17_UseStructLevels = true;  // ExitManager: use g_wave5_sl_price/g_wave5_tp_price instead of SLMode/ExitMode switch
input bool   _17_DivergTrail    = true;   // tighten trail on RSI divergence once price reaches the target zone
input int    _17_MaxSwings      = 8;      // pivots to collect per Wave5_CollectSwings call
input int    _17_RSI_Period     = 14;     // RSI period for divergence check (own handle g_hRSI17)
#endif

#ifdef LAB_ENTRY_18
input group "=== Entry 18: JumStoch (LWMA displacement + Stoch filter) ==="
input int    _18_Direction = 1;    // 1=BUY instance, 2=SELL instance (fixed; bidirectional = 2 instances w/ own magic)
input int    _18_DirMode   = 1;    // 1=FAITHFUL momentum-join (validated source mapping) · 2=REVERSION (Lane-A brief) - A/B this
input int    _18_MaPeriod  = 25;   // LWMA period (source maPereode=25)
input int    _18_KPeriod   = 32;   // Stoch %K (source kperiod=32)
input int    _18_DPeriod   = 12;   // Stoch %D (source dperiod=12)
input int    _18_Slowing   = 12;   // Stoch slowing (source slowing=12)
input double _18_LoLevel   = 25.0; // lower stoch band (source lo_level=25)
input double _18_UpLevel   = 75.0; // upper stoch band (source up_level=75)
#endif

//==================== Trend MA (shared: entry11 + filter + runtrend) =
input group "=== Trend MA (shared) ==="
input int             _0_FastMA   = 20;
input int             _0_SlowMA   = 50;
input ENUM_MA_METHOD  _0_MAMethod = MODE_EMA;
input ENUM_TIMEFRAMES _0_MA_TF    = PERIOD_CURRENT;

//==================== Filter (7x) ==================================
input group "=== 7x Filter params ==="
input int    _71_ATRMA    = 20;    // ATR_EXPAND smoothing period
input double _71_ATRRatio = 1.0;   // trade when ATR > ratio*ATR_MA
input int    _72_SlopeBar = 3;     // MA_SLOPE bars back

//==================== Regime (50x) =================================
input group "=== 50x Regime (market-state gate) ==="
input int             _50_RegimeMode      = 0;          // 0=off 1=filter 2=direction
input bool            _50_AllowTrendUp    = true;       // mode 1 only
input bool            _50_AllowTrendDown  = true;       // mode 1 only
input bool            _50_AllowRange      = true;       // mode 1 only
input ENUM_TIMEFRAMES _50_Regime_TF       = PERIOD_H4;
input int             _50_ADX_Period      = 14;
input double          _50_ADX_TrendMin    = 25.0;
input double          _50_StormATRmult    = 2.0;        // 0=storm disabled
input int             _50_StormLookback   = 100;

//==================== Exit / TP (2x) ===============================
input group "=== 2x Exit / TP params ==="
input double _21_TP_Pip       = 500;   // 21 Fixed TP
input double _22_TP_ATRmult   = 3.0;   // 22 ATR TP (x Risk-ATR)
input double _2_BasketTP_Money = 0;    // close basket at +money (0=off)
input double _2_BasketTP_ATRmult = 0;  // close basket at +(Risk-ATR x mult x total lots) in money (0=use fixed money)
input double _23_TrailStart   = 300;   // 23 trail start (pip gain)
input double _23_TrailStep    = 100;   // 23 trail distance

// additive: 2-stage partial close as the basket approaches _2_BasketTP_Money.
// OFF by default (both pct thresholds 0 = never fires). Zeus GridLog port (14):
// _04_PartialPct1/_04_PartialFrac1 + _04_PartialPct2/_04_PartialFrac2.
input double _2_PartialPct1  = 0;      // close frac1 of basket volume at this % of TP target (0=off)
input double _2_PartialFrac1 = 0.30;
input double _2_PartialPct2  = 0;      // close frac2 of basket volume at this % of TP target (0=off)
input double _2_PartialFrac2 = 0.30;

// additive: suppress per-leg broker TP entirely (default false = unchanged).
// GridLog(14) parity set turns this on - standalone Zeus legs carry TP=0.0,
// exit is basket-money-TP only (+ per-leg SL). See Exit_InitialTP for detail.
input bool _2_SuppressLegTP = false;

// additive ORDER-125: vertical-barrier exit (QuantCorner Triple Barrier, time
// leg). Force-closes the WHOLE basket once its oldest leg has been open for N
// closed bars on the chart TF - the time-based force-close the grid/DCA family
// lacked (recovery-days tail that the equity curve hides). 0 = off (default,
// byte-identical). Basket-level close, so it does not fragment mode-93 ladders.
input int _2_MaxHoldBars = 0;          // force-close basket after N bars from first leg (0=off)

// additive: dynamic basket close-money target that grows with the number of
// open orders in the basket (corpus EX183/EX078). close_target = base +
// (open_order_count / C) * base. Evaluated as an ADDITIONAL/alternative
// basket-TP check alongside the existing _2_BasketTP_Money/_2_BasketTP_ATRmult
// target (Exit_ManageBasket fires on whichever target is reached first) - it
// does not replace or alter them. OFF by default (_57_DynCloseOn=false ->
// no-op, identical to current behavior).
input bool   _57_DynCloseOn      = false; // 57 dynamic close-money target on/off
input double _57_DynCloseBase    = 10.0;  // 57 base $ target
input double _57_DynCloseDivisor = 4.0;   // 57 C: divisor controlling growth per open order

//==================== Stop loss (3x) ===============================
input group "=== 3x Stop loss params ==="
input double _31_SL_Pip        = 1000; // 31 fixed pip
input double _33_SL_ATRmult    = 2.0;  // 33 ATR x mult (x Risk-ATR)
input double _33_SL_MaxPips    = 0.0;  // 33 hard ceiling on ATR SL distance, in pips (0=off; pip=10*point on 3/5-digit)
input double _33_SL_MaxATRmult = 0.0;  // 33 portable ATR-relative ceiling (0=use legacy pip cap)
input bool   _33_AdaptiveON    = false;// 33 regime-scale: SL*=clamp(ATR/SMA(ATR,N),.7,1.5)
input int    _33_AdaptiveN     = 50;   // 33 adaptive SMA period
input double _32_SL_Money      = 0;    // 32 basket money stop (0=off)
input int    _34_DonchianBars  = 50;   // 34 Donchian lookback
input int    _35_SRBars        = 20;   // 35 swing S/R lookback
input double _36_SD_Mult       = 2.0;  // 36 n x SD
input int    _36_SD_Period     = 20;   // 36 SD lookback

//==================== ATR (signal + risk) ==========================
input group "=== ATR (2 contexts) ==="
input int             _0_ATR_Period     = 14;            // signal ATR (entry/stack)
input ENUM_TIMEFRAMES _0_ATR_TF         = PERIOD_CURRENT;
input int             _3_RiskATR_Period = 14;            // risk ATR (SL/TP/sizing)
input ENUM_TIMEFRAMES _3_RiskATR_TF     = PERIOD_CURRENT;// raise 1-2 steps for stable stops

//==================== Money management (4x/5x) =====================
input group "=== 4x/5x Money management ==="
input double _41_FixedLot   = 0.01;  // 41 fixed first lot
input double _42_RiskPct    = 1.0;   // 42 risk% balance per first order
input double _51_ProgFactor = 0.5;   // 51/54 coefficient
input double _52_ProgMult   = 1.3;   // 52 multiplier
input double _53_PlusLot    = 0.01;  // 53 additive step
input double _55_LogPowerFactor  = 1.3;   // 55 PROG_LOG_POWER: lot = firstLot * factor^(ln(orderN))
input bool   _55_UseLnNotLog10   = true;  // 55: true=ln, false=log10 (Zeus GridLog _05_UseLnNotLog10)

// additive: PROG_FIBONACCI (corpus EX191). lot(lv) = firstLot * fib(lv), fib =
// 1,2,3,5,8,13,... (fib(0)=1 -> level 0 = firstLot, same 1-indexing convention
// as the other cases). Capped at the multiplier reached at _56_FibMaxStep so
// the sequence stops growing past that step (default step 5 -> 13x cap) -
// this is the whole point vs unbounded martingale (PROG_MULTIPLIER). Inert
// unless LotProg == PROG_FIBONACCI is selected.
input int    _56_FibMaxStep      = 5;     // 56 cap step index (default 5 -> 13x multiplier ceiling)

// additive: DD-adaptive first-lot multiplier (Zeus GridLog _05_DdAdaptive).
// Applied ONLY to the first order of a new basket (level 0), always capped by
// _4_DdHardCapMult, so this cannot itself become a second unbounded martingale.
// OFF by default (_4_DdAdaptiveOn=false -> multiplier always 1.0).
input bool   _4_DdAdaptiveOn    = false;
input double _4_DdTier1Pct      = 10.0;   // floating account DD% at first-order time
input double _4_DdTier1Mult     = 1.2;
input double _4_DdTier2Pct      = 20.0;
input double _4_DdTier2Mult     = 1.5;
input double _4_DdHardCapMult   = 1.5;    // never exceeds this regardless of DD depth

//==================== Protection cage (0x + RC_) ===================
input group "=== 0x Protection (cage - always on) ==="
input ENUM_PROTECT_PROFILE ProtectLevel = PROTECT_NORMAL; // 02 sets KillDD/Load/Steps
input double RC_MaxLot     = 0.20;   // per-order lot ceiling
input double RC_RecMultMax = 1.3;    // cap effective progression multiplier
// additive: explicit stack/recovery depth override, independent of ProtectLevel's
// RC_MaxRecSteps (2/3/5). 0 = OFF (falls back to existing min(RC_MaxRecSteps,_9_MaxLevels)
// behavior - Boss_11/12/13 default is 0, so RiskControl_MaxLevels() is UNCHANGED for them).
// Set > 0 to let a grid-heavy entry (e.g. GridLog/14) reach a deeper basket while
// ProtectLevel still governs KillDD/DepositLoad independently of step-count.
input int RC_MaxLevelsOverride = 0;
// additive: account-level DD gate (PortfolioGuardian_v1 port, MERGE-04). 0 = OFF.
// Blocks NEW first-entries (level 0) while account equity sits more than this %
// below its high-water mark. Open baskets + their stack-adds finish normally
// (resize-not-kill). HWM persists via a scoped GlobalVariable ("Boss2_..._acct_hwm",
// ORDER-132) so a restart cannot forget the peak (tester GVs are sandboxed per pass).
input double RC_AcctDDLimitPct = 0.0;
// additive-EXCEPTION (MERGE-05B, signed off 2026-07-06): persist hard-kill halt
// + equity peak via GlobalVariables so restart/recompile cannot resurrect a
// killed EA (audit MERGE-05A: memory-only halt = CRITICAL live gap). Default ON
// deliberately: tester GVs are per-pass sandboxed -> backtest numbers unchanged
// (regression-proven), live safety is the whole point. Manual un-halt: delete the
// "Boss2_..._rc_state" GV (exact name is printed in the HALT restore log line;
// ORDER-132 scoped key, one enum RUNNING/KILL_PENDING/HALTED) or set this false
// + reattach. Pre-132 "Boss_<magic>_rc_halted" keys migrate automatically.
input bool RC_PersistHalt = true;
// ORDER-138 #1 + 138b (Codex roadmap SEV-1 + audit F1): legacy pre-132
// "Boss_<magic>_*" keys carry NO account identity - a terminal that switched
// logins (magic reused) would migrate ANOTHER account's state into this one:
// an active kill/halt closes the WRONG positions, and even a foreign (higher-
// equity) rc_peak_eq makes KillDD liquidate this account on the first tick.
// Default false = OnInit refuses the attach fail-closed while ANY legacy key
// this init would read exists (active kill/halt · rc_peak_eq · acct_hwm when
// the acct gate is on). In-place upgrade (pre-132 -> post-132, SAME account):
// set true for the upgrade attach, verify the "[RISK]/[PERSIST] migrated ..."
// journal lines, then set back false. Contamination (keys from another
// account): delete the Boss_<magic>_* rows via Tools->Global Variables (F3)
// instead of setting this true.
input bool RC_AdoptLegacyHalt = false;

//==================== 8x Recovery (offensive add-into-loss) ========
// OFF unless RecoveryMode != 80. Every add clamped by the cage
// (RiskControl_MaxLevels + RC_RecMultMax + RC_MaxLot + deposit load).
input group "=== 8x Recovery (cage-capped) ==="
input double _8_TriggerATR = 1.5;   // start recovering when adverse >= x * Risk-ATR
input double _8_StepATR    = 1.0;   // add one order per x * Risk-ATR of further adverse
input double _8_RecMult    = 1.3;   // 83 Aggressive per-step multiplier (clamped by RC_RecMultMax)
input double _8_DDRefMoney = 100.0; // 82 Adaptive DD reference ($ of basket loss = +1x size)

//==================== Hedge (defensive opposite lock) ==============
// OFF unless HedgeMode != 0. One hedge leg at a time; released by DD.
input group "=== Hedge (defensive lock) ==="
input double _H_TriggerDDPct = 8.0;  // open hedge when basket floating DD% >= this
input double _H_ReleaseDDPct = 3.0;  // close hedge when basket DD% recovers <= this
input double _H_Ratio        = 1.0;  // hedge lots = ratio * net exposed lots
input double _H_MaxLot       = 0.0;  // hedge lot ceiling (0 = use RC_MaxLot only)

//==================== MacroGate self-gate (ORDER-073 Phase-3) ======
// Moved here from LabCore.mqh (ORDER-124 chore 2 - all inputs live in Inputs.mqh).
// OFF by default = fully inert (the cage and every live EA see no change). When
// ON, THIS EA reads the MRIS regime timeline and sets its own MACROGATE_* GVs,
// which the Execution bridge then honours - this is how a SINGLE-EA
// strategy-tester A/B (gate off vs on) is run, since the tester cannot also run
// the standalone (Boss)_MacroGate watchdog. In LIVE, leave this OFF and use the
// standalone watchdog instead.
input group "=== MacroGate self-gate (backtest A/B only) ==="
input bool   _MG_SelfGate       = false;                     // enable in-EA macro gate (backtest A/B only)
input string _MG_RegimeFile     = "EA_LAB_mris_regime.csv";  // regime timeline CSV
input bool   _MG_InCommon       = true;                      // read from Common\Files
input double _MG_LotMult        = 0.5;                       // new-order lot multiplier while gated
input bool   _MG_BlockNew       = true;                      // also veto new orders while gated
input bool   _MG_TriggerRiskOff = true;                      // gate on RISK_OFF too (false = STRESS only)
input int    _MG_OffsetHours    = 0;                         // server = CSV time + N hours

//==================== General ======================================
input group "=== General ==="
input long _0_Magic     = 990001;
input int  _0_Slippage  = 20;
input int  _0_MaxSpread = 0;         // max spread in POINTS (broker SYMBOL_SPREAD units; 0 = ignore). Blocks NEW market+pending placement only - an accepted GTC pending can still fill later at a wide spread

//==================== 17 Wave5 structural anchors (guard G1) =======
// Published by Entry_Evaluate() (Entry_Wave5.mqh), consumed by ExitManager
// overrides (#ifdef LAB_ENTRY_17). Declared here (not in Entry_Wave5.mqh) so
// ExitManager.mqh, included BEFORE entries/ in LabCore.mqh, compiles against
// them. Reset to 0 in Entry_Wave5_Init() (recompile-safe).
#ifdef LAB_ENTRY_17
double g_wave5_sl_price = 0.0;   // structural SL price (wave-1 top/bottom +/- ATR buffer)
double g_wave5_tp_price = 0.0;   // 100% expansion target (entry_ref +/- |wave1|) - reference zone, not a hard broker TP
double g_wave5_entry_ref = 0.0;  // price at signal time (0 = unset)
#endif

#endif // BOSS_LAB_INPUTS_MQH
