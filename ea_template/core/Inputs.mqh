//+------------------------------------------------------------------+
//| Inputs.mqh (V2) - numbered dropdown surface for Boss Lab chassis. |
//| enum VALUE = code (MT5 report shows raw int -> scannable).        |
//| param names = _NN_  (NN = category code) so optimize/.set ไล่ง่าย.|
//| MUST be included first. LAB_ENTRY (11/12/13) set by the wrapper.  |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_INPUTS_MQH
#define BOSS_LAB_INPUTS_MQH

// wrapper defines ONE of: LAB_ENTRY_11 / LAB_ENTRY_12 / LAB_ENTRY_13 / LAB_ENTRY_14 (+ LAB_ENTRY_TAG)
// MQL5 preprocessor has no '#if EXPR==n' / '#elif' -> use token #ifdef only.
#ifndef LAB_ENTRY_11
#ifndef LAB_ENTRY_12
#ifndef LAB_ENTRY_13
#ifndef LAB_ENTRY_14
#define LAB_ENTRY_11          // fallback build
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
   PROG_LOG_POWER  = 55   // 55 LogPower  lot*factor^(ln(orderN)) - Zeus GridLog port (14)
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
   STACK_GRID_AGAINST = 92   // 92 Grid against (DCA / average down)
};

enum ENUM_STACK_CONFIRM
{
   CONF_DISTANCE   = 0,  // 0 Distance only (blind)
   CONF_SIG_VALID  = 1,  // 1 Distance + signal still valid (= V1)
   CONF_RETRIGGER  = 2,  // 2 Distance + signal re-trigger
   CONF_PRICE_ACT  = 3   // 3 Distance + bar CLOSE beyond level (PA)
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
input bool   _9_StepUseATR  = true;     // grid step from Signal-ATR (else points)
input double _9_StepATRmult = 1.0;      // step = mult x Signal-ATR
input double _9_StepPoints  = 300;      // step when not ATR
input double _9_StepMinPips = 0;        // additive: pips floor under the ATR step (0=off). Zeus GridLog _03_MinDistPips.
input int    _9_StepATRShift = 0;       // additive: Signal-ATR shift for the step calc (0=current/forming bar,
                                         // matches Boss_11/12/13 unchanged default; 1=last CLOSED bar, matches
                                         // standalone Zeus GetATR(1) - GridLog(14) parity .set uses 1).
input int    _9_MaxLevels   = 5;        // max stacked orders

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

//==================== Stop loss (3x) ===============================
input group "=== 3x Stop loss params ==="
input double _31_SL_Pip        = 1000; // 31 fixed pip
input double _33_SL_ATRmult    = 2.0;  // 33 ATR x mult (x Risk-ATR)
input double _33_SL_MaxPips    = 0.0;  // 33 hard ceiling on ATR SL distance, in pips (0=off; pip=10*point on 3/5-digit)
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

//==================== General ======================================
input group "=== General ==="
input long _0_Magic     = 990001;
input int  _0_Slippage  = 20;
input int  _0_MaxSpread = 0;         // 0 = ignore

#endif // BOSS_LAB_INPUTS_MQH
