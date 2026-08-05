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

//==================== CAPABILITY-TOKEN ROLLOUT (ORDER-1021, slice S8) ======
// Every input below is declared TWICE, in a guard pair:
//
//     #ifndef LAB_CONST_<name>
//     input  <type> <name> = <canonical default>;      <- the original line, unchanged
//     #endif
//     #ifdef  LAB_CONST_<name>
//     const  <type> <name> = LAB_CONSTVAL_<name>;
//     #endif
//
// A build that defines NO `LAB_CONST_*` takes the first branch for every input, so its token
// stream is the original one. That is every hand-written `Boss_*.mq5`: the rollout is inert for
// them BY CONSTRUCTION, not by anyone remembering to keep it that way. Per the owner's ratified
// per-Boss decision (2026-08-01), TWO CONVENTIONS COEXISTING IS EXPECTED, NOT DRIFT.
//
// A GENERATED thin wrapper (`ea_template/generated/<REV>.mq5`) includes an allowlist header that
// defines `LAB_CONST_<name>` + `LAB_CONSTVAL_<name>` for every input its revision cannot reach or
// has pinned, so those become compile-time constants at their EFFECTIVE value and leave the
// Inputs page entirely. Design section 5.3 (capability allowlist) + 5.4 (the locked/inactive
// state table). Which inputs those are is DERIVED, never listed here: `activation.classify()`
// answers "can this input change anything under this config", `hypothesis_b14.LOCKED_SELECTORS`
// answers "did the hypothesis pin it", and `gen_wrapper.py` emits the result.
//
// 🔴 WHY THE VALUE COMES FROM A MACRO AND NOT FROM THE LINE ABOVE IT. A LOCKED input is const at
// the value its HYPOTHESIS pinned, which is not its canonical default -- writing the default into
// the const branch would silently compile the wrong number. `LAB_CONSTVAL_<name>` is emitted by
// the generator from the same parsed surface, so there is one source for the value and no second
// transcription to drift.
//
// 🔴 WHY A PAIR OF `#ifndef`/`#ifdef` BLOCKS RATHER THAN `#ifdef`/`#else`. MQL5 does have `#else`
// (`LabCore.mqh:123` uses one), but `preset.parse_surface` -- the ONE parser every generator and
// checker in the Factory OS reads this file through -- refuses it on purpose, because meeting one
// would mean its model of this file is wrong. Two blocks keep a literal
// `input <type> <name> = <default>;` line that the parser matches, inside an `#ifndef` it
// evaluates as active, so the surface it reports is still all 116 names for build 14. That is
// what keeps `[CFG] effective_config_hash` comparable between a wrapper and its parent: the
// preimage reads the SYMBOL, and a const symbol reads the same as an input one.
//
// 🔴 ADDING AN INPUT MEANS ADDING ITS GUARD PAIR. An unguarded input can never be const-ed, so it
// would sit on every generated wrapper's Inputs page no matter what the registry says about it.
// `check_input_surface_gen` / `check_param_surface` compare against this file, so the omission
// shows up as a surface disagreement rather than as silence.

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
   FIRSTLOT_FIXED   = 41,   // 41 Fixed lot
   FIRSTLOT_RISK    = 42,   // 42 Risk% / SL distance (ATR-sized)
   FIRSTLOT_BALANCE = 43    // 43 Balance-scaled: lot grows linearly with account size (no SL needed)
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
   REC_ADAPTIVE   = 82,  // 82 Adaptive (DD-scaled lot, capped by RC_RecMultMax)
   REC_AGGRESSIVE = 83   // 83 Aggressive (geometric MathPow escalation, capped by RC_RecMultMax)
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
#ifndef LAB_CONST_ExitMode
input ENUM_EXIT_MODE       ExitMode      = EXIT_ATR_TP;     // Exit 2x
#endif
#ifdef LAB_CONST_ExitMode
const ENUM_EXIT_MODE ExitMode = LAB_CONSTVAL_ExitMode;
#endif
#ifndef LAB_CONST_SLMode
input ENUM_SL_MODE         SLMode        = SL_ATR;          // SL 3x
#endif
#ifdef LAB_CONST_SLMode
const ENUM_SL_MODE SLMode = LAB_CONSTVAL_SLMode;
#endif
#ifndef LAB_CONST_FirstLotMode
input ENUM_FIRST_LOT_MODE  FirstLotMode  = FIRSTLOT_FIXED;  // FirstLot 4x
#endif
#ifdef LAB_CONST_FirstLotMode
const ENUM_FIRST_LOT_MODE FirstLotMode = LAB_CONSTVAL_FirstLotMode;
#endif
#ifndef LAB_CONST_LotProg
input ENUM_LOT_PROGRESSION LotProg       = PROG_NONE;       // Progression 5x
#endif
#ifdef LAB_CONST_LotProg
const ENUM_LOT_PROGRESSION LotProg = LAB_CONSTVAL_LotProg;
#endif
#ifndef LAB_CONST_TradeDir
input ENUM_TRADE_DIR       TradeDir      = TRADEDIR_BOTH;   // Direction 6x
#endif
#ifdef LAB_CONST_TradeDir
const ENUM_TRADE_DIR TradeDir = LAB_CONSTVAL_TradeDir;
#endif
#ifndef LAB_CONST_TrendFilter
input ENUM_TREND_FILTER    TrendFilter   = TFILTER_NONE;    // Filter 7x
#endif
#ifdef LAB_CONST_TrendFilter
const ENUM_TREND_FILTER TrendFilter = LAB_CONSTVAL_TrendFilter;
#endif
#ifndef LAB_CONST_RecoveryMode
input ENUM_RECOVERY_MODE   RecoveryMode  = REC_NONE;        // Recovery 8x
#endif
#ifdef LAB_CONST_RecoveryMode
const ENUM_RECOVERY_MODE RecoveryMode = LAB_CONSTVAL_RecoveryMode;
#endif
#ifndef LAB_CONST_HedgeMode
input ENUM_HEDGE_MODE      HedgeMode     = HEDGE_OFF;
#endif
#ifdef LAB_CONST_HedgeMode
const ENUM_HEDGE_MODE HedgeMode = LAB_CONSTVAL_HedgeMode;
#endif
#ifndef LAB_CONST_DryRun
input bool                 DryRun        = false;           // log intents, no orders
#endif
#ifdef LAB_CONST_DryRun
const bool DryRun = LAB_CONSTVAL_DryRun;
#endif
#ifndef LAB_CONST__0_BarOpenOnly
input bool                 _0_BarOpenOnly = false;          // evaluate whole OnTick pipeline once per bar (Zeus-style; false = every tick, unchanged)
#endif
#ifdef LAB_CONST__0_BarOpenOnly
const bool _0_BarOpenOnly = LAB_CONSTVAL__0_BarOpenOnly;
#endif

//==================== Stack (9x) - per-build defaults ==============
input group "=== 9x Stack (how orders stack) ==="
#ifdef LAB_ENTRY_11
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_GRID_TREND;   // 91 default for Grid
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_SIG_VALID;     // 1
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_12
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // 90 default for Breakout
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a for single
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_13
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST; // 92 default for MR (DCA)
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_PRICE_ACT;     // 3 (DCA needs strong confirm)
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_14
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST; // 92 default for GridLog (adds vs adverse move)
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // 0 (Zeus grid add = distance only, blind)
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_15
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // 90 default for ST03 (one order per edge signal)
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a for single
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_16
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // informational only - Kangaroo.mqh owns its own grid pipeline (LabCore short-circuits)
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a (Kangaroo adds are distance-only by design)
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_17
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_SINGLE;       // 90 naked probe (Wave5): single order per signal, no grid/recovery/martingale
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // n/a for single
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifdef LAB_ENTRY_18
#ifndef LAB_CONST_StackMode
input ENUM_STACK_MODE    StackMode    = STACK_GRID_AGAINST; // 92 DCA for JumStoch (adds vs adverse move - matches standalone Range grid)
#endif
#ifdef LAB_CONST_StackMode
const ENUM_STACK_MODE StackMode = LAB_CONSTVAL_StackMode;
#endif
#ifndef LAB_CONST_StackConfirm
input ENUM_STACK_CONFIRM StackConfirm = CONF_DISTANCE;      // 0 distance-only base (A/B flips to CONF_PA_ENGULF)
#endif
#ifdef LAB_CONST_StackConfirm
const ENUM_STACK_CONFIRM StackConfirm = LAB_CONSTVAL_StackConfirm;
#endif
#endif
#ifndef LAB_CONST__9_StepUseATR
input bool   _9_StepUseATR  = true;     // grid step from Signal-ATR (else points)
#endif
#ifdef LAB_CONST__9_StepUseATR
const bool _9_StepUseATR = LAB_CONSTVAL__9_StepUseATR;
#endif
#ifndef LAB_CONST__9_StepATRmult
input double _9_StepATRmult = 1.0;      // step = mult x Signal-ATR
#endif
#ifdef LAB_CONST__9_StepATRmult
const double _9_StepATRmult = LAB_CONSTVAL__9_StepATRmult;
#endif
#ifndef LAB_CONST__9_StepPoints
input double _9_StepPoints  = 300;      // step when not ATR
#endif
#ifdef LAB_CONST__9_StepPoints
const double _9_StepPoints = LAB_CONSTVAL__9_StepPoints;
#endif
#ifndef LAB_CONST__9_StepMinPips
input double _9_StepMinPips = 0;        // additive: pips floor under the ATR step (0=off). Zeus GridLog _03_MinDistPips.
#endif
#ifdef LAB_CONST__9_StepMinPips
const double _9_StepMinPips = LAB_CONSTVAL__9_StepMinPips;
#endif
#ifndef LAB_CONST__9_StepATRShift
input int    _9_StepATRShift = 0;       // additive: Signal-ATR shift for the step calc (0=current/forming bar,
                                         // matches Boss_11/12/13 unchanged default; 1=last CLOSED bar, matches
                                         // standalone Zeus GetATR(1) - GridLog(14) parity .set uses 1).
#endif
#ifdef LAB_CONST__9_StepATRShift
const int _9_StepATRShift = LAB_CONSTVAL__9_StepATRShift;
#endif
#ifndef LAB_CONST__9_MaxLevels
input int    _9_MaxLevels   = 5;        // max stacked orders
#endif
#ifdef LAB_CONST__9_MaxLevels
const int _9_MaxLevels = LAB_CONSTVAL__9_MaxLevels;
#endif
// additive (AdaptiveGrid_Oil finding 2026-07-17): gate grid ADDS by the 5x Regime
// module too, not just the flat seed. The Regime gate in LabCore only blocks the
// FIRST (flat) entry; a grid is almost never flat, so adds sail through unfiltered.
// When true, Stack_DecideAdd refuses to extend a basket whose direction the Regime
// disallows (reuses the ADX Regime; needs _50_RegimeMode!=0 to have any effect).
// Default false = behaviour byte-identical to before. See EDGE_CATALOG "add-gating".
#ifndef LAB_CONST__9_RegimeGateAdds
input bool   _9_RegimeGateAdds = false;
#endif
#ifdef LAB_CONST__9_RegimeGateAdds
const bool _9_RegimeGateAdds = LAB_CONSTVAL__9_RegimeGateAdds;
#endif
// additive (PriceAction Phase 0, 2026-07-18): body-size ratio for the engulfing
// used by StackConfirm=CONF_PA_ENGULF(4). 1.0 = classic (signal body >= prior body).
// Only read when StackConfirm=4; inert otherwise. Default keeps all EAs unchanged.
#ifndef LAB_CONST__9_PA_MinBodyRatio
input double _9_PA_MinBodyRatio = 1.0;
#endif
#ifdef LAB_CONST__9_PA_MinBodyRatio
const double _9_PA_MinBodyRatio = LAB_CONSTVAL__9_PA_MinBodyRatio;
#endif
// additive (MERGE-03, ScaleExecutor_v2 port): STACK_PYRAMID(93) pending ladder.
// Active ONLY when StackMode=93 - all other modes ignore these two inputs.
// Leg0 = normal market entry; legs 1..N = resting pendings at Stack_StepPrice()
// spacing, placed once per basket. Basket close (TP/SL/kill) cancels leftovers.
// One exit owner: basket TP/SL only - pendings carry per-leg SL, NEVER per-leg
// TP. Mode 93 also disables Recovery/Hedge/partial-close/market-adds (see board
// MERGE-02 synthesis: "one mode, one exit owner").
#ifndef LAB_CONST__9_PendingMode
input int _9_PendingMode = 0;   // 93 only: 0=none (warn) / 2=LIMIT scale-in / 3=STOP pyramid
#endif
#ifdef LAB_CONST__9_PendingMode
const int _9_PendingMode = LAB_CONSTVAL__9_PendingMode;
#endif
#ifndef LAB_CONST__9_PendingLegs
input int _9_PendingLegs = 0;   // 93 only: pendings after leg0 (capped by RiskControl_MaxLevels-1)
#endif
#ifdef LAB_CONST__9_PendingLegs
const int _9_PendingLegs = LAB_CONSTVAL__9_PendingLegs;
#endif

//==================== ENTRY params (compile-time guarded) ==========
#ifdef LAB_ENTRY_11
input group "=== 11 Entry: Grid Trend MA ==="
// NOTE: trend MA (FastMA/SlowMA) is shared - also used by 72 filter + 24 RunTrend.
//       defined in shared block below (_0_FastMA / _0_SlowMA).
#endif

#ifdef LAB_ENTRY_12
input group "=== 12 Entry: Breakout (Donchian) ==="
#ifndef LAB_CONST__12_Bars
input int  _12_Bars        = 20;   // channel lookback
#endif
#ifdef LAB_CONST__12_Bars
const int _12_Bars = LAB_CONSTVAL__12_Bars;
#endif
#ifndef LAB_CONST__12_ConfirmBars
input int  _12_ConfirmBars = 1;    // closes beyond channel (0=tick)
#endif
#ifdef LAB_CONST__12_ConfirmBars
const int _12_ConfirmBars = LAB_CONSTVAL__12_ConfirmBars;
#endif
#ifndef LAB_CONST__12_HourFrom
input int  _12_HourFrom    = 0;    // session start UTC (0=no filter)
#endif
#ifdef LAB_CONST__12_HourFrom
const int _12_HourFrom = LAB_CONSTVAL__12_HourFrom;
#endif
#ifndef LAB_CONST__12_HourTo
input int  _12_HourTo      = 0;    // session end UTC (wraps if From>To)
#endif
#ifdef LAB_CONST__12_HourTo
const int _12_HourTo = LAB_CONSTVAL__12_HourTo;
#endif
#endif

#ifdef LAB_ENTRY_13
input group "=== 13 Entry: Mean Reversion (BB+RSI) ==="
#ifndef LAB_CONST__13_BB_Period
input int    _13_BB_Period  = 20;
#endif
#ifdef LAB_CONST__13_BB_Period
const int _13_BB_Period = LAB_CONSTVAL__13_BB_Period;
#endif
#ifndef LAB_CONST__13_BB_Dev
input double _13_BB_Dev     = 2.0;
#endif
#ifdef LAB_CONST__13_BB_Dev
const double _13_BB_Dev = LAB_CONSTVAL__13_BB_Dev;
#endif
#ifndef LAB_CONST__13_RSI_Period
input int    _13_RSI_Period = 14;
#endif
#ifdef LAB_CONST__13_RSI_Period
const int _13_RSI_Period = LAB_CONSTVAL__13_RSI_Period;
#endif
#ifndef LAB_CONST__13_RSI_OB
input int    _13_RSI_OB     = 70;
#endif
#ifdef LAB_CONST__13_RSI_OB
const int _13_RSI_OB = LAB_CONSTVAL__13_RSI_OB;
#endif
#ifndef LAB_CONST__13_RSI_OS
input int    _13_RSI_OS     = 30;
#endif
#ifdef LAB_CONST__13_RSI_OS
const int _13_RSI_OS = LAB_CONSTVAL__13_RSI_OS;
#endif
#ifndef LAB_CONST__13_RequireBB
input bool   _13_RequireBB  = true;
#endif
#ifdef LAB_CONST__13_RequireBB
const bool _13_RequireBB = LAB_CONSTVAL__13_RequireBB;
#endif
#endif

#ifdef LAB_ENTRY_14
input group "=== 14 Entry: GridLog (Zeus-inspired breakout-arm) ==="
#ifndef LAB_CONST__14_Direction
input int    _14_Direction   = 1;      // 1=BUY only, 2=SELL only (fixed, never both - matches standalone)
#endif
#ifdef LAB_CONST__14_Direction
const int _14_Direction = LAB_CONSTVAL__14_Direction;
#endif
#ifndef LAB_CONST__14_DistAtrMult
input double _14_DistAtrMult = 1.5;    // arm/grid-step distance = mult x Signal-ATR
#endif
#ifdef LAB_CONST__14_DistAtrMult
const double _14_DistAtrMult = LAB_CONSTVAL__14_DistAtrMult;
#endif
#ifndef LAB_CONST__14_MinDistPips
input double _14_MinDistPips = 20.0;   // floor under the ATR distance (pips; 3/5-digit symbols = 10xpoint)
#endif
#ifdef LAB_CONST__14_MinDistPips
const double _14_MinDistPips = LAB_CONSTVAL__14_MinDistPips;
#endif
#endif

#ifdef LAB_ENTRY_15
input group "=== 15 Entry: ST03 (MACD consecutive-count, StrategySignal_v4 port) ==="
#ifndef LAB_CONST__15_MacdFast
input int  _15_MacdFast    = 12;    // MACD fast EMA (matches EA_RUNNER_ST03 defaults)
#endif
#ifdef LAB_CONST__15_MacdFast
const int _15_MacdFast = LAB_CONSTVAL__15_MacdFast;
#endif
#ifndef LAB_CONST__15_MacdSlow
input int  _15_MacdSlow    = 26;    // MACD slow EMA
#endif
#ifdef LAB_CONST__15_MacdSlow
const int _15_MacdSlow = LAB_CONSTVAL__15_MacdSlow;
#endif
#ifndef LAB_CONST__15_MacdSignal
input int  _15_MacdSignal  = 9;     // MACD signal SMA
#endif
#ifdef LAB_CONST__15_MacdSignal
const int _15_MacdSignal = LAB_CONSTVAL__15_MacdSignal;
#endif
#ifndef LAB_CONST__15_CountBars
input int  _15_CountBars   = 2;     // consecutive closed bars in one MACD state before firing
#endif
#ifdef LAB_CONST__15_CountBars
const int _15_CountBars = LAB_CONSTVAL__15_CountBars;
#endif
#ifndef LAB_CONST__15_EdgeTrigger
input bool _15_EdgeTrigger = true;  // true=fire once per state-run (ST_EA03) / false=level (over-trades)
#endif
#ifdef LAB_CONST__15_EdgeTrigger
const bool _15_EdgeTrigger = LAB_CONSTVAL__15_EdgeTrigger;
#endif
#ifndef LAB_CONST__15_RearmBars
input int  _15_RearmBars   = 0;     // re-fire every K bars within a run (0=pure edge, 1~=level)
#endif
#ifdef LAB_CONST__15_RearmBars
const int _15_RearmBars = LAB_CONSTVAL__15_RearmBars;
#endif
#endif

#ifdef LAB_ENTRY_16
// ORDER-072: KangarooInspired (Gold_Kangaroo behavioral rebuild, KANGAROO_LOGIC_NOTES.md).
// Entry 16 bypasses the standard LabCore pipeline entirely - Kangaroo.mqh is the single
// exit owner AND the single add owner (see that file's header). Only the cage
// (RiskControl hard-kill / deposit load / RC_MaxLot) stays supreme above it.
input group "=== 16 Entry: KangarooGrid (RSI fade, fixed direction) ==="
#ifndef LAB_CONST__16_Direction
input int    _16_Direction   = 1;      // 1=BUY instance, 2=SELL instance (fixed, never both - bidirectional = 2 instances w/ own magic, Boss_14 pattern)
#endif
#ifdef LAB_CONST__16_Direction
const int _16_Direction = LAB_CONSTVAL__16_Direction;
#endif
#ifndef LAB_CONST__16_RsiPeriod
input int    _16_RsiPeriod   = 14;     // RSI period on chart TF
#endif
#ifdef LAB_CONST__16_RsiPeriod
const int _16_RsiPeriod = LAB_CONSTVAL__16_RsiPeriod;
#endif
#ifndef LAB_CONST__16_RsiLow
input double _16_RsiLow      = 30.0;   // BUY instance arms when RSI(closed bar) < this
#endif
#ifdef LAB_CONST__16_RsiLow
const double _16_RsiLow = LAB_CONSTVAL__16_RsiLow;
#endif
#ifndef LAB_CONST__16_RsiHigh
input double _16_RsiHigh     = 70.0;   // SELL instance arms when RSI(closed bar) > this
#endif
#ifdef LAB_CONST__16_RsiHigh
const double _16_RsiHigh = LAB_CONSTVAL__16_RsiHigh;
#endif
input group "=== 16 Grid (ATR spacing, ADVERSE adds only, hard cap) ==="
#ifndef LAB_CONST__16_AtrMultFirst4
input double _16_AtrMultFirst4    = 0.8;    // spacing = mult x Signal-ATR while side has < 4 orders (original: 200 fixed pips)
#endif
#ifdef LAB_CONST__16_AtrMultFirst4
const double _16_AtrMultFirst4 = LAB_CONSTVAL__16_AtrMultFirst4;
#endif
#ifndef LAB_CONST__16_AtrMultAfter
input double _16_AtrMultAfter     = 1.4;    // spacing mult from order 5 on (original: 350 fixed pips)
#endif
#ifdef LAB_CONST__16_AtrMultAfter
const double _16_AtrMultAfter = LAB_CONSTVAL__16_AtrMultAfter;
#endif
#ifndef LAB_CONST__16_MinDistPips
input double _16_MinDistPips      = 150.0;  // spacing floor in pips (digit-aware; XAU 2-digit: pip=point=$0.01)
#endif
#ifdef LAB_CONST__16_MinDistPips
const double _16_MinDistPips = LAB_CONSTVAL__16_MinDistPips;
#endif
#ifndef LAB_CONST__16_MaxOrdersPerSide
input int    _16_MaxOrdersPerSide = 10;     // HARD cap - adds refused beyond this (original advertised 10 but leaked to 14)
#endif
#ifdef LAB_CONST__16_MaxOrdersPerSide
const int _16_MaxOrdersPerSide = LAB_CONSTVAL__16_MaxOrdersPerSide;
#endif
input group "=== 16 Lots (FLAT default; capped ladder OFF at 1.0) ==="
// ORDER-190: Kangaroo owns its own lot law and never calls MM_FirstLot, so the chassis
// FirstLotMode (41/42/43) has no effect here at all - MM_ConfigValid warns about that at
// attach. This input is the opt-in that lets entry 16 scale with the account the same way
// chassis mode 43 does, WITHOUT changing what mode 0 (the default) does by a single tick.
//   0 = FLAT     : every base order = _16_BaseLot          <- default, unchanged behavior
//   1 = SCALED   : base order = _43_LotPerAnchor x (balance / _43_BalanceAnchor)
// Mode 1 reuses the chassis mode-43 pair on purpose: one anchor concept to learn, one
// place to get the cent-vs-USD units right (see EA_CORE_AND_TEMPLATE_GUIDE section 3.6).
// The ladder (_16_LadderMult), the per-order ceiling and the cage all still apply after.
#ifndef LAB_CONST__16_BaseLotMode
input int    _16_BaseLotMode    = 0;     // 0=flat _16_BaseLot (default) / 1=balance-scaled via _43_LotPerAnchor+_43_BalanceAnchor
#endif
#ifdef LAB_CONST__16_BaseLotMode
const int _16_BaseLotMode = LAB_CONSTVAL__16_BaseLotMode;
#endif
#ifndef LAB_CONST__16_BaseLot
input double _16_BaseLot        = 0.01;  // every order when LadderMult <= 1.0 (flat-lot probe beat the x1.5 ladder: PF 5.71 vs 4.86)
#endif
#ifdef LAB_CONST__16_BaseLot
const double _16_BaseLot = LAB_CONSTVAL__16_BaseLot;
#endif
#ifndef LAB_CONST__16_LadderMult
input double _16_LadderMult     = 1.0;   // >1.0 enables ladder: order N = max open lot x this; first 4 orders always BaseLot
#endif
#ifdef LAB_CONST__16_LadderMult
const double _16_LadderMult = LAB_CONSTVAL__16_LadderMult;
#endif
#ifndef LAB_CONST__16_MaxLotPerOrder
input double _16_MaxLotPerOrder = 1.0;   // per-order ceiling for the ladder (= original Max_Lot_Martingale; RC_MaxLot still clamps after)
#endif
#ifdef LAB_CONST__16_MaxLotPerOrder
const double _16_MaxLotPerOrder = LAB_CONSTVAL__16_MaxLotPerOrder;
#endif
input group "=== 16 SL / Exits (Kangaroo engine = single exit owner) ==="
#ifndef LAB_CONST__16_SlAtrMult
input double _16_SlAtrMult        = 18.0;   // per-order broker SL = mult x Risk-ATR (~$90 at gold-1800-era ATR)
#endif
#ifdef LAB_CONST__16_SlAtrMult
const double _16_SlAtrMult = LAB_CONSTVAL__16_SlAtrMult;
#endif
#ifndef LAB_CONST__16_MaxSlPips
input double _16_MaxSlPips        = 9000.0; // SL distance ceiling in pips, digit-aware (= original 9000 = $90 on XAU; 0=off)
#endif
#ifdef LAB_CONST__16_MaxSlPips
const double _16_MaxSlPips = LAB_CONSTVAL__16_MaxSlPips;
#endif
#ifndef LAB_CONST__16_TpSingleAtrMult
input double _16_TpSingleAtrMult  = 0.35;   // exit 1: single open order closes at mult x Risk-ATR profit (~80 gold pips at ATR ~$2.3)
#endif
#ifdef LAB_CONST__16_TpSingleAtrMult
const double _16_TpSingleAtrMult = LAB_CONSTVAL__16_TpSingleAtrMult;
#endif
#ifndef LAB_CONST__16_BasketTpUsdPer01
input double _16_BasketTpUsdPer01 = 16.0;   // exit 2: close whole side at net$ >= this x (total lots / 0.01) - dollar-true version of pip-sum 160
#endif
#ifdef LAB_CONST__16_BasketTpUsdPer01
const double _16_BasketTpUsdPer01 = LAB_CONSTVAL__16_BasketTpUsdPer01;
#endif
#ifndef LAB_CONST__16_OverlapMinUsd
input double _16_OverlapMinUsd    = 5.0;    // exit 3: overlap pair-close (newest+oldest) when combined net$ >= this
#endif
#ifdef LAB_CONST__16_OverlapMinUsd
const double _16_OverlapMinUsd = LAB_CONSTVAL__16_OverlapMinUsd;
#endif
#ifndef LAB_CONST__16_OverlapMinOrders
input int    _16_OverlapMinOrders = 4;      // exit 3 active only from this many open orders
#endif
#ifdef LAB_CONST__16_OverlapMinOrders
const int _16_OverlapMinOrders = LAB_CONSTVAL__16_OverlapMinOrders;
#endif
#ifndef LAB_CONST__16_FlattenOn
input bool   _16_FlattenOn            = false; // exit 4 (ladder_flatten, A/B module): default OFF per ORDER-072 decision 5
#endif
#ifdef LAB_CONST__16_FlattenOn
const bool _16_FlattenOn = LAB_CONSTVAL__16_FlattenOn;
#endif
#ifndef LAB_CONST__16_FlattenMinOrders
input int    _16_FlattenMinOrders     = 6;     // exit 4: allowed from this many open orders
#endif
#ifdef LAB_CONST__16_FlattenMinOrders
const int _16_FlattenMinOrders = LAB_CONSTVAL__16_FlattenMinOrders;
#endif
#ifndef LAB_CONST__16_MaxControlledLossUsd
input double _16_MaxControlledLossUsd = 400.0; // exit 4: close-all side once net$ >= -this (controlled-loss DD release)
#endif
#ifdef LAB_CONST__16_MaxControlledLossUsd
const double _16_MaxControlledLossUsd = LAB_CONSTVAL__16_MaxControlledLossUsd;
#endif
#ifndef LAB_CONST__16_EmergencyDDPct
input double _16_EmergencyDDPct       = 70.0;  // emergency close-all at equity DD% from peak (tighter than original's unverified 80; cage KillDD fires first at default profile)
#endif
#ifdef LAB_CONST__16_EmergencyDDPct
const double _16_EmergencyDDPct = LAB_CONSTVAL__16_EmergencyDDPct;
#endif
#endif

#ifdef LAB_ENTRY_17
// ORDER-082: Wave5 - Elliott wave-4 retrace entry, arms to catch wave-5.
// Naked probe only (guard G4): StackMode=90 single, no grid/recovery/martingale.
// Swings come from in-code confirmed fractals (Wave5Swings.mqh) - built-in only,
// no iCustom/ZigZag (repaint ban). Structural SL/TP anchors published into the
// globals below (guard G1: declared here so ExitManager, included before
// entries in LabCore, can compile against them).
input group "=== 17 Entry: Wave5 (Elliott wave-4 retrace arm, both directions) ==="
#ifndef LAB_CONST__17_FractalDepth
input int    _17_FractalDepth   = 3;      // confirmed-fractal bars each side (repaint guard: newest usable pivot is always >= this many bars back)
#endif
#ifdef LAB_CONST__17_FractalDepth
const int _17_FractalDepth = LAB_CONSTVAL__17_FractalDepth;
#endif
#ifndef LAB_CONST__17_Wave3MinMult
input double _17_Wave3MinMult   = 0.618;  // wave-3 confirm: must run >= this x |wave1| beyond the wave-1 break (permissive default - Fable D2, our addition)
#endif
#ifdef LAB_CONST__17_Wave3MinMult
const double _17_Wave3MinMult = LAB_CONSTVAL__17_Wave3MinMult;
#endif
#ifndef LAB_CONST__17_EntryFib
input double _17_EntryFib       = 38.2;   // wave-4 zone arm level, % retrace of wave3 (sweep {23.6,38.2,50,61.8})
#endif
#ifdef LAB_CONST__17_EntryFib
const double _17_EntryFib = LAB_CONSTVAL__17_EntryFib;
#endif
#ifndef LAB_CONST__17_SLbufferATR
input double _17_SLbufferATR    = 0.5;    // SL = wave-1 top/bottom +/- this x Risk-ATR buffer (absorbs spread/wick)
#endif
#ifdef LAB_CONST__17_SLbufferATR
const double _17_SLbufferATR = LAB_CONSTVAL__17_SLbufferATR;
#endif
#ifndef LAB_CONST__17_UseStructLevels
input bool   _17_UseStructLevels = true;  // ExitManager: use g_wave5_sl_price/g_wave5_tp_price instead of SLMode/ExitMode switch
#endif
#ifdef LAB_CONST__17_UseStructLevels
const bool _17_UseStructLevels = LAB_CONSTVAL__17_UseStructLevels;
#endif
#ifndef LAB_CONST__17_DivergTrail
input bool   _17_DivergTrail    = true;   // tighten trail on RSI divergence once price reaches the target zone
#endif
#ifdef LAB_CONST__17_DivergTrail
const bool _17_DivergTrail = LAB_CONSTVAL__17_DivergTrail;
#endif
#ifndef LAB_CONST__17_MaxSwings
input int    _17_MaxSwings      = 8;      // pivots to collect per Wave5_CollectSwings call
#endif
#ifdef LAB_CONST__17_MaxSwings
const int _17_MaxSwings = LAB_CONSTVAL__17_MaxSwings;
#endif
#ifndef LAB_CONST__17_RSI_Period
input int    _17_RSI_Period     = 14;     // RSI period for divergence check (own handle g_hRSI17)
#endif
#ifdef LAB_CONST__17_RSI_Period
const int _17_RSI_Period = LAB_CONSTVAL__17_RSI_Period;
#endif
#endif

#ifdef LAB_ENTRY_18
input group "=== Entry 18: JumStoch (LWMA displacement + Stoch filter) ==="
#ifndef LAB_CONST__18_Direction
input int    _18_Direction = 1;    // 1=BUY instance, 2=SELL instance (fixed; bidirectional = 2 instances w/ own magic)
#endif
#ifdef LAB_CONST__18_Direction
const int _18_Direction = LAB_CONSTVAL__18_Direction;
#endif
#ifndef LAB_CONST__18_DirMode
input int    _18_DirMode   = 1;    // 1=FAITHFUL momentum-join (validated source mapping) · 2=REVERSION (Lane-A brief) - A/B this
#endif
#ifdef LAB_CONST__18_DirMode
const int _18_DirMode = LAB_CONSTVAL__18_DirMode;
#endif
#ifndef LAB_CONST__18_MaPeriod
input int    _18_MaPeriod  = 25;   // LWMA period (source maPereode=25)
#endif
#ifdef LAB_CONST__18_MaPeriod
const int _18_MaPeriod = LAB_CONSTVAL__18_MaPeriod;
#endif
#ifndef LAB_CONST__18_KPeriod
input int    _18_KPeriod   = 32;   // Stoch %K (source kperiod=32)
#endif
#ifdef LAB_CONST__18_KPeriod
const int _18_KPeriod = LAB_CONSTVAL__18_KPeriod;
#endif
#ifndef LAB_CONST__18_DPeriod
input int    _18_DPeriod   = 12;   // Stoch %D (source dperiod=12)
#endif
#ifdef LAB_CONST__18_DPeriod
const int _18_DPeriod = LAB_CONSTVAL__18_DPeriod;
#endif
#ifndef LAB_CONST__18_Slowing
input int    _18_Slowing   = 12;   // Stoch slowing (source slowing=12)
#endif
#ifdef LAB_CONST__18_Slowing
const int _18_Slowing = LAB_CONSTVAL__18_Slowing;
#endif
#ifndef LAB_CONST__18_LoLevel
input double _18_LoLevel   = 25.0; // lower stoch band (source lo_level=25)
#endif
#ifdef LAB_CONST__18_LoLevel
const double _18_LoLevel = LAB_CONSTVAL__18_LoLevel;
#endif
#ifndef LAB_CONST__18_UpLevel
input double _18_UpLevel   = 75.0; // upper stoch band (source up_level=75)
#endif
#ifdef LAB_CONST__18_UpLevel
const double _18_UpLevel = LAB_CONSTVAL__18_UpLevel;
#endif
#endif

//==================== Trend MA (shared: entry11 + filter + runtrend) =
input group "=== Trend MA (shared) ==="
#ifndef LAB_CONST__0_FastMA
input int             _0_FastMA   = 20;
#endif
#ifdef LAB_CONST__0_FastMA
const int _0_FastMA = LAB_CONSTVAL__0_FastMA;
#endif
#ifndef LAB_CONST__0_SlowMA
input int             _0_SlowMA   = 50;
#endif
#ifdef LAB_CONST__0_SlowMA
const int _0_SlowMA = LAB_CONSTVAL__0_SlowMA;
#endif
#ifndef LAB_CONST__0_MAMethod
input ENUM_MA_METHOD  _0_MAMethod = MODE_EMA;
#endif
#ifdef LAB_CONST__0_MAMethod
const ENUM_MA_METHOD _0_MAMethod = LAB_CONSTVAL__0_MAMethod;
#endif
#ifndef LAB_CONST__0_MA_TF
input ENUM_TIMEFRAMES _0_MA_TF    = PERIOD_CURRENT;
#endif
#ifdef LAB_CONST__0_MA_TF
const ENUM_TIMEFRAMES _0_MA_TF = LAB_CONSTVAL__0_MA_TF;
#endif

//==================== Filter (7x) ==================================
input group "=== 7x Filter params ==="
#ifndef LAB_CONST__71_ATRMA
input int    _71_ATRMA    = 20;    // ATR_EXPAND smoothing period
#endif
#ifdef LAB_CONST__71_ATRMA
const int _71_ATRMA = LAB_CONSTVAL__71_ATRMA;
#endif
#ifndef LAB_CONST__71_ATRRatio
input double _71_ATRRatio = 1.0;   // trade when ATR > ratio*ATR_MA
#endif
#ifdef LAB_CONST__71_ATRRatio
const double _71_ATRRatio = LAB_CONSTVAL__71_ATRRatio;
#endif
#ifndef LAB_CONST__72_SlopeBar
input int    _72_SlopeBar = 3;     // MA_SLOPE bars back
#endif
#ifdef LAB_CONST__72_SlopeBar
const int _72_SlopeBar = LAB_CONSTVAL__72_SlopeBar;
#endif

//==================== Regime (50x) =================================
input group "=== 50x Regime (market-state gate) ==="
#ifndef LAB_CONST__50_RegimeMode
input int             _50_RegimeMode      = 0;          // 0=off 1=filter 2=direction
#endif
#ifdef LAB_CONST__50_RegimeMode
const int _50_RegimeMode = LAB_CONSTVAL__50_RegimeMode;
#endif
#ifndef LAB_CONST__50_AllowTrendUp
input bool            _50_AllowTrendUp    = true;       // mode 1 only
#endif
#ifdef LAB_CONST__50_AllowTrendUp
const bool _50_AllowTrendUp = LAB_CONSTVAL__50_AllowTrendUp;
#endif
#ifndef LAB_CONST__50_AllowTrendDown
input bool            _50_AllowTrendDown  = true;       // mode 1 only
#endif
#ifdef LAB_CONST__50_AllowTrendDown
const bool _50_AllowTrendDown = LAB_CONSTVAL__50_AllowTrendDown;
#endif
#ifndef LAB_CONST__50_AllowRange
input bool            _50_AllowRange      = true;       // mode 1 only
#endif
#ifdef LAB_CONST__50_AllowRange
const bool _50_AllowRange = LAB_CONSTVAL__50_AllowRange;
#endif
#ifndef LAB_CONST__50_Regime_TF
input ENUM_TIMEFRAMES _50_Regime_TF       = PERIOD_H4;
#endif
#ifdef LAB_CONST__50_Regime_TF
const ENUM_TIMEFRAMES _50_Regime_TF = LAB_CONSTVAL__50_Regime_TF;
#endif
#ifndef LAB_CONST__50_ADX_Period
input int             _50_ADX_Period      = 14;
#endif
#ifdef LAB_CONST__50_ADX_Period
const int _50_ADX_Period = LAB_CONSTVAL__50_ADX_Period;
#endif
#ifndef LAB_CONST__50_ADX_TrendMin
input double          _50_ADX_TrendMin    = 25.0;
#endif
#ifdef LAB_CONST__50_ADX_TrendMin
const double _50_ADX_TrendMin = LAB_CONSTVAL__50_ADX_TrendMin;
#endif
#ifndef LAB_CONST__50_StormATRmult
input double          _50_StormATRmult    = 2.0;        // 0=storm disabled
#endif
#ifdef LAB_CONST__50_StormATRmult
const double _50_StormATRmult = LAB_CONSTVAL__50_StormATRmult;
#endif
#ifndef LAB_CONST__50_StormLookback
input int             _50_StormLookback   = 100;
#endif
#ifdef LAB_CONST__50_StormLookback
const int _50_StormLookback = LAB_CONSTVAL__50_StormLookback;
#endif

//==================== Exit / TP (2x) ===============================
input group "=== 2x Exit / TP params ==="
#ifndef LAB_CONST__21_TP_Pip
input double _21_TP_Pip       = 500;   // 21 Fixed TP
#endif
#ifdef LAB_CONST__21_TP_Pip
const double _21_TP_Pip = LAB_CONSTVAL__21_TP_Pip;
#endif
#ifndef LAB_CONST__22_TP_ATRmult
input double _22_TP_ATRmult   = 3.0;   // 22 ATR TP (x Risk-ATR)
#endif
#ifdef LAB_CONST__22_TP_ATRmult
const double _22_TP_ATRmult = LAB_CONSTVAL__22_TP_ATRmult;
#endif
#ifndef LAB_CONST__2_BasketTP_Money
input double _2_BasketTP_Money = 0;    // close basket at +money (0=off) - ⚠️ ABSOLUTE, see _2_BasketTP_BalPct
#endif
#ifdef LAB_CONST__2_BasketTP_Money
const double _2_BasketTP_Money = LAB_CONSTVAL__2_BasketTP_Money;
#endif
#ifndef LAB_CONST__2_BasketTP_ATRmult
input double _2_BasketTP_ATRmult = 0;  // close basket at +(Risk-ATR x mult x total lots) in money (0=use fixed money)
#endif
#ifdef LAB_CONST__2_BasketTP_ATRmult
const double _2_BasketTP_ATRmult = LAB_CONSTVAL__2_BasketTP_ATRmult;
#endif
// additive (2026-07-23): basket TP as % of CURRENT BALANCE instead of an absolute figure.
// Fixes the cent-vs-USD account confusion ("TP at 25" means $25 on a USD account but
// $0.25 on a cent account - same number, 100x different meaning). A percentage means the
// same thing everywhere AND auto-scales as the account grows.
// PRECEDENCE (highest first): _2_BasketTP_BalPct > _2_BasketTP_ATRmult > _2_BasketTP_Money.
// 0 = off (default) -> existing ATRmult/Money behavior completely unchanged.
#ifndef LAB_CONST__2_BasketTP_BalPct
input double _2_BasketTP_BalPct = 0;   // close basket at +this % of balance (0=off, portable)
#endif
#ifdef LAB_CONST__2_BasketTP_BalPct
const double _2_BasketTP_BalPct = LAB_CONSTVAL__2_BasketTP_BalPct;
#endif
#ifndef LAB_CONST__23_TrailStart
input double _23_TrailStart   = 300;   // 23 trail start (pip gain)
#endif
#ifdef LAB_CONST__23_TrailStart
const double _23_TrailStart = LAB_CONSTVAL__23_TrailStart;
#endif
#ifndef LAB_CONST__23_TrailStep
input double _23_TrailStep    = 100;   // 23 trail distance
#endif
#ifdef LAB_CONST__23_TrailStep
const double _23_TrailStep = LAB_CONSTVAL__23_TrailStep;
#endif

// additive: 2-stage partial close as the basket approaches _2_BasketTP_Money.
// OFF by default (both pct thresholds 0 = never fires). Zeus GridLog port (14):
// _04_PartialPct1/_04_PartialFrac1 + _04_PartialPct2/_04_PartialFrac2.
#ifndef LAB_CONST__2_PartialPct1
input double _2_PartialPct1  = 0;      // close frac1 of basket volume at this % of TP target (0=off)
#endif
#ifdef LAB_CONST__2_PartialPct1
const double _2_PartialPct1 = LAB_CONSTVAL__2_PartialPct1;
#endif
#ifndef LAB_CONST__2_PartialFrac1
input double _2_PartialFrac1 = 0.30;
#endif
#ifdef LAB_CONST__2_PartialFrac1
const double _2_PartialFrac1 = LAB_CONSTVAL__2_PartialFrac1;
#endif
#ifndef LAB_CONST__2_PartialPct2
input double _2_PartialPct2  = 0;      // close frac2 of basket volume at this % of TP target (0=off)
#endif
#ifdef LAB_CONST__2_PartialPct2
const double _2_PartialPct2 = LAB_CONSTVAL__2_PartialPct2;
#endif
#ifndef LAB_CONST__2_PartialFrac2
input double _2_PartialFrac2 = 0.30;
#endif
#ifdef LAB_CONST__2_PartialFrac2
const double _2_PartialFrac2 = LAB_CONSTVAL__2_PartialFrac2;
#endif

// additive: suppress per-leg broker TP entirely (default false = unchanged).
// GridLog(14) parity set turns this on - standalone Zeus legs carry TP=0.0,
// exit is basket-money-TP only (+ per-leg SL). See Exit_InitialTP for detail.
#ifndef LAB_CONST__2_SuppressLegTP
input bool _2_SuppressLegTP = false;
#endif
#ifdef LAB_CONST__2_SuppressLegTP
const bool _2_SuppressLegTP = LAB_CONSTVAL__2_SuppressLegTP;
#endif

// additive ORDER-125: vertical-barrier exit (QuantCorner Triple Barrier, time
// leg). Force-closes the WHOLE basket once its oldest leg has been open for N
// closed bars on the chart TF - the time-based force-close the grid/DCA family
// lacked (recovery-days tail that the equity curve hides). 0 = off (default,
// byte-identical). Basket-level close, so it does not fragment mode-93 ladders.
#ifndef LAB_CONST__2_MaxHoldBars
input int _2_MaxHoldBars = 0;          // force-close basket after N bars from first leg (0=off)
#endif
#ifdef LAB_CONST__2_MaxHoldBars
const int _2_MaxHoldBars = LAB_CONSTVAL__2_MaxHoldBars;
#endif

// additive: dynamic basket close-money target that grows with the number of
// open orders in the basket (corpus EX183/EX078). close_target = base +
// (open_order_count / C) * base. Evaluated as an ADDITIONAL/alternative
// basket-TP check alongside the existing _2_BasketTP_Money/_2_BasketTP_ATRmult
// target (Exit_ManageBasket fires on whichever target is reached first) - it
// does not replace or alter them. OFF by default (_57_DynCloseOn=false ->
// no-op, identical to current behavior).
#ifndef LAB_CONST__57_DynCloseOn
input bool   _57_DynCloseOn      = false; // 57 dynamic close-money target on/off
#endif
#ifdef LAB_CONST__57_DynCloseOn
const bool _57_DynCloseOn = LAB_CONSTVAL__57_DynCloseOn;
#endif
#ifndef LAB_CONST__57_DynCloseBase
input double _57_DynCloseBase    = 10.0;  // 57 base $ target - ⚠️ ABSOLUTE, see _57_DynCloseBalPct
#endif
#ifdef LAB_CONST__57_DynCloseBase
const double _57_DynCloseBase = LAB_CONSTVAL__57_DynCloseBase;
#endif
// additive (2026-07-23): dyn-close BASE as % of balance instead of absolute money
// (the per-order growth factor _57_DynCloseDivisor is already unitless). Wins over
// _57_DynCloseBase when > 0. 0 = off (default) -> unchanged.
#ifndef LAB_CONST__57_DynCloseBalPct
input double _57_DynCloseBalPct  = 0;     // 57 base target as % of balance (0=off, portable)
#endif
#ifdef LAB_CONST__57_DynCloseBalPct
const double _57_DynCloseBalPct = LAB_CONSTVAL__57_DynCloseBalPct;
#endif
#ifndef LAB_CONST__57_DynCloseDivisor
input double _57_DynCloseDivisor = 4.0;   // 57 C: divisor controlling growth per open order
#endif
#ifdef LAB_CONST__57_DynCloseDivisor
const double _57_DynCloseDivisor = LAB_CONSTVAL__57_DynCloseDivisor;
#endif

//==================== Stop loss (3x) ===============================
input group "=== 3x Stop loss params ==="
#ifndef LAB_CONST__31_SL_Pip
input double _31_SL_Pip        = 1000; // 31 fixed pip
#endif
#ifdef LAB_CONST__31_SL_Pip
const double _31_SL_Pip = LAB_CONSTVAL__31_SL_Pip;
#endif
#ifndef LAB_CONST__33_SL_ATRmult
input double _33_SL_ATRmult    = 2.0;  // 33 ATR x mult (x Risk-ATR)
#endif
#ifdef LAB_CONST__33_SL_ATRmult
const double _33_SL_ATRmult = LAB_CONSTVAL__33_SL_ATRmult;
#endif
#ifndef LAB_CONST__33_SL_MaxPips
input double _33_SL_MaxPips    = 0.0;  // 33 hard ceiling on ATR SL distance, in pips (0=off; pip=10*point on 3/5-digit)
#endif
#ifdef LAB_CONST__33_SL_MaxPips
const double _33_SL_MaxPips = LAB_CONSTVAL__33_SL_MaxPips;
#endif
#ifndef LAB_CONST__33_SL_MaxATRmult
input double _33_SL_MaxATRmult = 0.0;  // 33 portable ATR-relative ceiling (0=use legacy pip cap)
#endif
#ifdef LAB_CONST__33_SL_MaxATRmult
const double _33_SL_MaxATRmult = LAB_CONSTVAL__33_SL_MaxATRmult;
#endif
#ifndef LAB_CONST__33_AdaptiveON
input bool   _33_AdaptiveON    = false;// 33 regime-scale: SL*=clamp(ATR/SMA(ATR,N),.7,1.5)
#endif
#ifdef LAB_CONST__33_AdaptiveON
const bool _33_AdaptiveON = LAB_CONSTVAL__33_AdaptiveON;
#endif
#ifndef LAB_CONST__33_AdaptiveN
input int    _33_AdaptiveN     = 50;   // 33 adaptive SMA period
#endif
#ifdef LAB_CONST__33_AdaptiveN
const int _33_AdaptiveN = LAB_CONSTVAL__33_AdaptiveN;
#endif
#ifndef LAB_CONST__32_SL_Money
input double _32_SL_Money      = 0;    // 32 basket money stop (0=off) - ⚠️ ABSOLUTE, see _32_SL_BalPct
#endif
#ifdef LAB_CONST__32_SL_Money
const double _32_SL_Money = LAB_CONSTVAL__32_SL_Money;
#endif
// additive (2026-07-23): basket money-stop as % of CURRENT BALANCE (portable across
// cent/USD accounts + auto-scales with account size). Wins over _32_SL_Money when > 0.
// 0 = off (default) -> _32_SL_Money behavior unchanged.
#ifndef LAB_CONST__32_SL_BalPct
input double _32_SL_BalPct     = 0;    // 32 basket stop at -this % of balance (0=off, portable)
#endif
#ifdef LAB_CONST__32_SL_BalPct
const double _32_SL_BalPct = LAB_CONSTVAL__32_SL_BalPct;
#endif
#ifndef LAB_CONST__34_DonchianBars
input int    _34_DonchianBars  = 50;   // 34 Donchian lookback
#endif
#ifdef LAB_CONST__34_DonchianBars
const int _34_DonchianBars = LAB_CONSTVAL__34_DonchianBars;
#endif
#ifndef LAB_CONST__35_SRBars
input int    _35_SRBars        = 20;   // 35 swing S/R lookback
#endif
#ifdef LAB_CONST__35_SRBars
const int _35_SRBars = LAB_CONSTVAL__35_SRBars;
#endif
#ifndef LAB_CONST__36_SD_Mult
input double _36_SD_Mult       = 2.0;  // 36 n x SD
#endif
#ifdef LAB_CONST__36_SD_Mult
const double _36_SD_Mult = LAB_CONSTVAL__36_SD_Mult;
#endif
#ifndef LAB_CONST__36_SD_Period
input int    _36_SD_Period     = 20;   // 36 SD lookback
#endif
#ifdef LAB_CONST__36_SD_Period
const int _36_SD_Period = LAB_CONSTVAL__36_SD_Period;
#endif

//==================== ATR (signal + risk) ==========================
input group "=== ATR (2 contexts) ==="
#ifndef LAB_CONST__0_ATR_Period
input int             _0_ATR_Period     = 14;            // signal ATR (entry/stack)
#endif
#ifdef LAB_CONST__0_ATR_Period
const int _0_ATR_Period = LAB_CONSTVAL__0_ATR_Period;
#endif
#ifndef LAB_CONST__0_ATR_TF
input ENUM_TIMEFRAMES _0_ATR_TF         = PERIOD_CURRENT;
#endif
#ifdef LAB_CONST__0_ATR_TF
const ENUM_TIMEFRAMES _0_ATR_TF = LAB_CONSTVAL__0_ATR_TF;
#endif
#ifndef LAB_CONST__3_RiskATR_Period
input int             _3_RiskATR_Period = 14;            // risk ATR (SL/TP/sizing)
#endif
#ifdef LAB_CONST__3_RiskATR_Period
const int _3_RiskATR_Period = LAB_CONSTVAL__3_RiskATR_Period;
#endif
#ifndef LAB_CONST__3_RiskATR_TF
input ENUM_TIMEFRAMES _3_RiskATR_TF     = PERIOD_CURRENT;// raise 1-2 steps for stable stops
#endif
#ifdef LAB_CONST__3_RiskATR_TF
const ENUM_TIMEFRAMES _3_RiskATR_TF = LAB_CONSTVAL__3_RiskATR_TF;
#endif

//==================== Money management (4x/5x) =====================
input group "=== 4x/5x Money management ==="
#ifndef LAB_CONST__41_FixedLot
input double _41_FixedLot   = 0.01;  // 41 fixed first lot
#endif
#ifdef LAB_CONST__41_FixedLot
const double _41_FixedLot = LAB_CONSTVAL__41_FixedLot;
#endif
#ifndef LAB_CONST__42_RiskPct
input double _42_RiskPct    = 1.0;   // 42 risk% balance per first order
#endif
#ifdef LAB_CONST__42_RiskPct
const double _42_RiskPct = LAB_CONSTVAL__42_RiskPct;
#endif

// additive (2026-07-23, user request): FIRSTLOT_BALANCE = 43 - lot scales linearly
// with account size, WITHOUT needing an SL distance (FIRSTLOT_RISK=42 falls back to
// fixed lot when the EA has no per-order SL, e.g. grid/basket entries - this mode
// covers that gap).   lot = _43_LotPerAnchor x (balance / _43_BalanceAnchor)
// Default anchor 1000 + lot 0.01 reads as "0.01 lot per 1000 of account currency".
//
// 💡 WHY THIS IS CENT/USD-ACCOUNT SAFE (the whole point):  balance and _43_BalanceAnchor
// are BOTH in account currency, so their ratio is UNITLESS - it means the same thing on a
// USD account and on a cent account. Set the anchor in whatever units YOUR account shows:
//   USD acct,  $1,000 shown as 1000    -> anchor 1000
//   cent acct, $1,000 shown as 100000  -> anchor 100000
// Both then scale identically as the account grows. This is the general fix for the
// "money params are confusing across cent/USD ports" problem: express money as a RATIO
// (percent-of-balance / balance-anchor), never as an absolute figure. Same trick is now
// available for every basket money target below (_2_BasketTP_BalPct etc).
// Inert unless FirstLotMode == FIRSTLOT_BALANCE is selected.
#ifndef LAB_CONST__43_LotPerAnchor
input double _43_LotPerAnchor  = 0.01;    // 43 lot per one _43_BalanceAnchor of balance
#endif
#ifdef LAB_CONST__43_LotPerAnchor
const double _43_LotPerAnchor = LAB_CONSTVAL__43_LotPerAnchor;
#endif
#ifndef LAB_CONST__43_BalanceAnchor
input double _43_BalanceAnchor = 1000.0;  // 43 balance unit the lot above refers to (account currency)
#endif
#ifdef LAB_CONST__43_BalanceAnchor
const double _43_BalanceAnchor = LAB_CONSTVAL__43_BalanceAnchor;
#endif
#ifndef LAB_CONST__51_ProgFactor
input double _51_ProgFactor = 0.5;   // 51/54 coefficient
#endif
#ifdef LAB_CONST__51_ProgFactor
const double _51_ProgFactor = LAB_CONSTVAL__51_ProgFactor;
#endif
#ifndef LAB_CONST__52_ProgMult
input double _52_ProgMult   = 1.3;   // 52 multiplier
#endif
#ifdef LAB_CONST__52_ProgMult
const double _52_ProgMult = LAB_CONSTVAL__52_ProgMult;
#endif
#ifndef LAB_CONST__53_PlusLot
input double _53_PlusLot    = 0.01;  // 53 additive step
#endif
#ifdef LAB_CONST__53_PlusLot
const double _53_PlusLot = LAB_CONSTVAL__53_PlusLot;
#endif
#ifndef LAB_CONST__55_LogPowerFactor
input double _55_LogPowerFactor  = 1.3;   // 55 PROG_LOG_POWER: lot = firstLot * factor^(ln(orderN))
#endif
#ifdef LAB_CONST__55_LogPowerFactor
const double _55_LogPowerFactor = LAB_CONSTVAL__55_LogPowerFactor;
#endif
#ifndef LAB_CONST__55_UseLnNotLog10
input bool   _55_UseLnNotLog10   = true;  // 55: true=ln, false=log10 (Zeus GridLog _05_UseLnNotLog10)
#endif
#ifdef LAB_CONST__55_UseLnNotLog10
const bool _55_UseLnNotLog10 = LAB_CONSTVAL__55_UseLnNotLog10;
#endif

// additive: PROG_FIBONACCI (corpus EX191). lot(lv) = firstLot * fib(lv), fib =
// 1,2,3,5,8,13,... (fib(0)=1 -> level 0 = firstLot, same 1-indexing convention
// as the other cases). Capped at the multiplier reached at _56_FibMaxStep so
// the sequence stops growing past that step (default step 5 -> 13x cap) -
// this is the whole point vs unbounded martingale (PROG_MULTIPLIER). Inert
// unless LotProg == PROG_FIBONACCI is selected.
#ifndef LAB_CONST__56_FibMaxStep
input int    _56_FibMaxStep      = 5;     // 56 cap step index (default 5 -> 13x multiplier ceiling)
#endif
#ifdef LAB_CONST__56_FibMaxStep
const int _56_FibMaxStep = LAB_CONSTVAL__56_FibMaxStep;
#endif

// additive: DD-adaptive first-lot multiplier (Zeus GridLog _05_DdAdaptive).
// Applied ONLY to the first order of a new basket (level 0), always capped by
// _4_DdHardCapMult, so this cannot itself become a second unbounded martingale.
// OFF by default (_4_DdAdaptiveOn=false -> multiplier always 1.0).
#ifndef LAB_CONST__4_DdAdaptiveOn
input bool   _4_DdAdaptiveOn    = false;
#endif
#ifdef LAB_CONST__4_DdAdaptiveOn
const bool _4_DdAdaptiveOn = LAB_CONSTVAL__4_DdAdaptiveOn;
#endif
#ifndef LAB_CONST__4_DdTier1Pct
input double _4_DdTier1Pct      = 10.0;   // floating account DD% at first-order time
#endif
#ifdef LAB_CONST__4_DdTier1Pct
const double _4_DdTier1Pct = LAB_CONSTVAL__4_DdTier1Pct;
#endif
#ifndef LAB_CONST__4_DdTier1Mult
input double _4_DdTier1Mult     = 1.2;
#endif
#ifdef LAB_CONST__4_DdTier1Mult
const double _4_DdTier1Mult = LAB_CONSTVAL__4_DdTier1Mult;
#endif
#ifndef LAB_CONST__4_DdTier2Pct
input double _4_DdTier2Pct      = 20.0;
#endif
#ifdef LAB_CONST__4_DdTier2Pct
const double _4_DdTier2Pct = LAB_CONSTVAL__4_DdTier2Pct;
#endif
#ifndef LAB_CONST__4_DdTier2Mult
input double _4_DdTier2Mult     = 1.5;
#endif
#ifdef LAB_CONST__4_DdTier2Mult
const double _4_DdTier2Mult = LAB_CONSTVAL__4_DdTier2Mult;
#endif
#ifndef LAB_CONST__4_DdHardCapMult
input double _4_DdHardCapMult   = 1.5;    // never exceeds this regardless of DD depth
#endif
#ifdef LAB_CONST__4_DdHardCapMult
const double _4_DdHardCapMult = LAB_CONSTVAL__4_DdHardCapMult;
#endif

//==================== Protection cage (0x + RC_) ===================
input group "=== 0x Protection (cage - always on) ==="
#ifndef LAB_CONST_ProtectLevel
input ENUM_PROTECT_PROFILE ProtectLevel = PROTECT_NORMAL; // 02 sets KillDD/Load/Steps
#endif
#ifdef LAB_CONST_ProtectLevel
const ENUM_PROTECT_PROFILE ProtectLevel = LAB_CONSTVAL_ProtectLevel;
#endif
#ifndef LAB_CONST_RC_MaxLot
input double RC_MaxLot     = 0.20;   // per-order lot ceiling
#endif
#ifdef LAB_CONST_RC_MaxLot
const double RC_MaxLot = LAB_CONSTVAL_RC_MaxLot;
#endif
#ifndef LAB_CONST_RC_RecMultMax
input double RC_RecMultMax = 1.3;    // cap effective progression multiplier
#endif
#ifdef LAB_CONST_RC_RecMultMax
const double RC_RecMultMax = LAB_CONSTVAL_RC_RecMultMax;
#endif
// additive: explicit stack/recovery depth override, independent of ProtectLevel's
// RC_MaxRecSteps (2/3/5). 0 = OFF (falls back to existing min(RC_MaxRecSteps,_9_MaxLevels)
// behavior - Boss_11/12/13 default is 0, so RiskControl_MaxLevels() is UNCHANGED for them).
// Set > 0 to let a grid-heavy entry (e.g. GridLog/14) reach a deeper basket while
// ProtectLevel still governs KillDD/DepositLoad independently of step-count.
#ifndef LAB_CONST_RC_MaxLevelsOverride
input int RC_MaxLevelsOverride = 0;
#endif
#ifdef LAB_CONST_RC_MaxLevelsOverride
const int RC_MaxLevelsOverride = LAB_CONSTVAL_RC_MaxLevelsOverride;
#endif
// additive: account-level DD gate (PortfolioGuardian_v1 port, MERGE-04). 0 = OFF.
// Blocks NEW first-entries (level 0) while account equity sits more than this %
// below its high-water mark. Open baskets + their stack-adds finish normally
// (resize-not-kill). HWM persists via a scoped GlobalVariable ("Boss2_..._acct_hwm",
// ORDER-132) so a restart cannot forget the peak (tester GVs are sandboxed per pass).
#ifndef LAB_CONST_RC_AcctDDLimitPct
input double RC_AcctDDLimitPct = 0.0;
#endif
#ifdef LAB_CONST_RC_AcctDDLimitPct
const double RC_AcctDDLimitPct = LAB_CONSTVAL_RC_AcctDDLimitPct;
#endif
// additive-EXCEPTION (MERGE-05B, signed off 2026-07-06): persist hard-kill halt
// + equity peak via GlobalVariables so restart/recompile cannot resurrect a
// killed EA (audit MERGE-05A: memory-only halt = CRITICAL live gap). Default ON
// deliberately: tester GVs are per-pass sandboxed -> backtest numbers unchanged
// (regression-proven), live safety is the whole point. Manual un-halt: delete the
// "Boss2_..._rc_state" GV (exact name is printed in the HALT restore log line;
// ORDER-132 scoped key, one enum RUNNING/KILL_PENDING/HALTED) or set this false
// + reattach. Pre-132 "Boss_<magic>_rc_halted" keys migrate automatically.
#ifndef LAB_CONST_RC_PersistHalt
input bool RC_PersistHalt = true;
#endif
#ifdef LAB_CONST_RC_PersistHalt
const bool RC_PersistHalt = LAB_CONSTVAL_RC_PersistHalt;
#endif
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
#ifndef LAB_CONST_RC_AdoptLegacyHalt
input bool RC_AdoptLegacyHalt = false;
#endif
#ifdef LAB_CONST_RC_AdoptLegacyHalt
const bool RC_AdoptLegacyHalt = LAB_CONSTVAL_RC_AdoptLegacyHalt;
#endif

//==================== 8x Recovery (offensive add-into-loss) ========
// OFF unless RecoveryMode != 80. Every add clamped by the cage
// (RiskControl_MaxLevels + RC_RecMultMax + RC_MaxLot + deposit load).
input group "=== 8x Recovery (cage-capped) ==="
#ifndef LAB_CONST__8_TriggerATR
input double _8_TriggerATR = 1.5;   // start recovering when adverse >= x * Risk-ATR
#endif
#ifdef LAB_CONST__8_TriggerATR
const double _8_TriggerATR = LAB_CONSTVAL__8_TriggerATR;
#endif
#ifndef LAB_CONST__8_StepATR
input double _8_StepATR    = 1.0;   // add one order per x * Risk-ATR of further adverse
#endif
#ifdef LAB_CONST__8_StepATR
const double _8_StepATR = LAB_CONSTVAL__8_StepATR;
#endif
#ifndef LAB_CONST__8_RecMult
input double _8_RecMult    = 1.3;   // 83 Aggressive per-step multiplier (clamped by RC_RecMultMax)
#endif
#ifdef LAB_CONST__8_RecMult
const double _8_RecMult = LAB_CONSTVAL__8_RecMult;
#endif
#ifndef LAB_CONST__8_DDRefMoney
input double _8_DDRefMoney = 100.0; // 82 Adaptive DD reference ($ of basket loss = +1x size) - ⚠️ ABSOLUTE, see below
#endif
#ifdef LAB_CONST__8_DDRefMoney
const double _8_DDRefMoney = LAB_CONSTVAL__8_DDRefMoney;
#endif
// additive (2026-07-23): same reference as % of balance (portable cent/USD + scales with
// account). Wins over _8_DDRefMoney when > 0. 0 = off (default) -> unchanged.
#ifndef LAB_CONST__8_DDRefBalPct
input double _8_DDRefBalPct = 0;    // 82 Adaptive DD reference as % of balance (0=off, portable)
#endif
#ifdef LAB_CONST__8_DDRefBalPct
const double _8_DDRefBalPct = LAB_CONSTVAL__8_DDRefBalPct;
#endif

//==================== Hedge (defensive opposite lock) ==============
// OFF unless HedgeMode != 0. One hedge leg at a time; released by DD.
input group "=== Hedge (defensive lock) ==="
#ifndef LAB_CONST__H_TriggerDDPct
input double _H_TriggerDDPct = 8.0;  // open hedge when basket floating DD% >= this
#endif
#ifdef LAB_CONST__H_TriggerDDPct
const double _H_TriggerDDPct = LAB_CONSTVAL__H_TriggerDDPct;
#endif
#ifndef LAB_CONST__H_ReleaseDDPct
input double _H_ReleaseDDPct = 3.0;  // close hedge when basket DD% recovers <= this
#endif
#ifdef LAB_CONST__H_ReleaseDDPct
const double _H_ReleaseDDPct = LAB_CONSTVAL__H_ReleaseDDPct;
#endif
#ifndef LAB_CONST__H_Ratio
input double _H_Ratio        = 1.0;  // hedge lots = ratio * net exposed lots
#endif
#ifdef LAB_CONST__H_Ratio
const double _H_Ratio = LAB_CONSTVAL__H_Ratio;
#endif
#ifndef LAB_CONST__H_MaxLot
input double _H_MaxLot       = 0.0;  // hedge lot ceiling (0 = use RC_MaxLot only)
#endif
#ifdef LAB_CONST__H_MaxLot
const double _H_MaxLot = LAB_CONSTVAL__H_MaxLot;
#endif

//==================== MacroGate self-gate (ORDER-073 Phase-3) ======
// Moved here from LabCore.mqh (ORDER-124 chore 2 - all inputs live in Inputs.mqh).
// OFF by default = fully inert (the cage and every live EA see no change). When
// ON, THIS EA reads the MRIS regime timeline and sets its own MACROGATE_* GVs,
// which the Execution bridge then honours - this is how a SINGLE-EA
// strategy-tester A/B (gate off vs on) is run, since the tester cannot also run
// the standalone (Boss)_MacroGate watchdog. In LIVE, leave this OFF and use the
// standalone watchdog instead.
input group "=== MacroGate self-gate (backtest A/B only) ==="
#ifndef LAB_CONST__MG_SelfGate
input bool   _MG_SelfGate       = false;                     // enable in-EA macro gate (backtest A/B only)
#endif
#ifdef LAB_CONST__MG_SelfGate
const bool _MG_SelfGate = LAB_CONSTVAL__MG_SelfGate;
#endif
#ifndef LAB_CONST__MG_RegimeFile
input string _MG_RegimeFile     = "EA_LAB_mris_regime.csv";  // regime timeline CSV
#endif
#ifdef LAB_CONST__MG_RegimeFile
const string _MG_RegimeFile = LAB_CONSTVAL__MG_RegimeFile;
#endif
#ifndef LAB_CONST__MG_InCommon
input bool   _MG_InCommon       = true;                      // read from Common\Files
#endif
#ifdef LAB_CONST__MG_InCommon
const bool _MG_InCommon = LAB_CONSTVAL__MG_InCommon;
#endif
#ifndef LAB_CONST__MG_LotMult
input double _MG_LotMult        = 0.5;                       // new-order lot multiplier while gated
#endif
#ifdef LAB_CONST__MG_LotMult
const double _MG_LotMult = LAB_CONSTVAL__MG_LotMult;
#endif
#ifndef LAB_CONST__MG_BlockNew
input bool   _MG_BlockNew       = true;                      // also veto new orders while gated
#endif
#ifdef LAB_CONST__MG_BlockNew
const bool _MG_BlockNew = LAB_CONSTVAL__MG_BlockNew;
#endif
#ifndef LAB_CONST__MG_TriggerRiskOff
input bool   _MG_TriggerRiskOff = true;                      // gate on RISK_OFF too (false = STRESS only)
#endif
#ifdef LAB_CONST__MG_TriggerRiskOff
const bool _MG_TriggerRiskOff = LAB_CONSTVAL__MG_TriggerRiskOff;
#endif
#ifndef LAB_CONST__MG_OffsetHours
input int    _MG_OffsetHours    = 0;                         // server = CSV time + N hours
#endif
#ifdef LAB_CONST__MG_OffsetHours
const int _MG_OffsetHours = LAB_CONSTVAL__MG_OffsetHours;
#endif

//==================== General ======================================
input group "=== General ==="
#ifndef LAB_CONST__0_Magic
input long _0_Magic     = 990001;
#endif
#ifdef LAB_CONST__0_Magic
const long _0_Magic = LAB_CONSTVAL__0_Magic;
#endif
#ifndef LAB_CONST__0_Slippage
input int  _0_Slippage  = 20;
#endif
#ifdef LAB_CONST__0_Slippage
const int _0_Slippage = LAB_CONSTVAL__0_Slippage;
#endif
#ifndef LAB_CONST__0_MaxSpread
input int  _0_MaxSpread = 0;         // max spread in POINTS (broker SYMBOL_SPREAD units; 0 = ignore). Blocks NEW market+pending placement only - an accepted GTC pending can still fill later at a wide spread
#endif
#ifdef LAB_CONST__0_MaxSpread
const int _0_MaxSpread = LAB_CONSTVAL__0_MaxSpread;
#endif

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
