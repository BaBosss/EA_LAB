//+------------------------------------------------------------------+
//| Inputs.mqh - all enums + inputs for EA_LabTemplate                |
//| MUST be included first (owns the input/enum surface).             |
//| Dropdown enums select STRUCTURE (optimize across modes fast);     |
//| each mode's related params stay configurable/optimizable.         |
//+------------------------------------------------------------------+
#ifndef EA_LAB_INPUTS_MQH
#define EA_LAB_INPUTS_MQH

//==================== Dropdown axes (structure) =====================
enum ENUM_ENTRY_STYLE
{
   ENTRY_GRID_TREND_MA = 0   // Grid trend-following (MA cross)
   // future: BREAKOUT, SWING, MEAN_REV
};

enum ENUM_EXIT_MODE
{
   EXIT_FIXED_TP   = 0,      // fixed TP (points)
   EXIT_TRAIL      = 1,      // trailing stop
   EXIT_RUN_TREND  = 2,      // close basket when MA cross reverses
   EXIT_ATR_TP     = 3       // TP = ATR * mult
};

enum ENUM_SL_MODE
{
   SL_NONE           = 0,
   SL_FIXED_POINTS   = 1,
   SL_MONEY          = 2,    // basket money stop
   SL_ATR            = 3,    // SL = ATR * mult
   SL_STRUCT_DONCHIAN= 4,    // break of N-bar low/high
   SL_STRUCT_SR      = 5     // break of recent swing support/resistance
};

enum ENUM_FIRST_LOT_MODE
{
   FIRSTLOT_FIXED = 0,       // fixed lot
   FIRSTLOT_RISK  = 1        // risk% / SL distance
};

enum ENUM_LOT_PROGRESSION
{
   PROG_NONE       = 0,      // next orders same lot
   PROG_LINEAR     = 1,      // lot * (1 + factor*level)
   PROG_MULTIPLIER = 2,      // lot * mult^level (martingale)
   PROG_PLUS       = 3,      // lot + plus*level (additive)
   PROG_LOG        = 4       // lot * (1 + factor*log(level+1))
};

enum ENUM_TRADE_DIR
{
   TRADEDIR_BOTH       = 0,
   TRADEDIR_LONG_ONLY  = 1,
   TRADEDIR_SHORT_ONLY = 2
};

enum ENUM_TREND_FILTER
{
   TFILTER_NONE       = 0,
   TFILTER_ATR_EXPAND = 1,  // only trade when ATR > MA(ATR)*ratio (volatility expanding)
   TFILTER_MA_SLOPE   = 2   // only trade when fast MA slope confirms direction
};

enum ENUM_RECOVERY_MODE
{
   REC_NONE       = 0,
   REC_LIGHT      = 1,
   REC_ADAPTIVE   = 2,       // (stub this phase)
   REC_AGGRESSIVE = 3        // (stub this phase)
};

enum ENUM_HEDGE_MODE
{
   HEDGE_OFF = 0             // future
};

//==================== Mode selectors ===============================
input group "=== Mode selectors (dropdown) ==="
input ENUM_ENTRY_STYLE     InpEntryStyle     = ENTRY_GRID_TREND_MA;
input ENUM_EXIT_MODE       InpExitMode       = EXIT_ATR_TP;
input ENUM_SL_MODE         InpSLMode         = SL_ATR;
input ENUM_FIRST_LOT_MODE  InpFirstLotMode   = FIRSTLOT_FIXED;
input ENUM_LOT_PROGRESSION InpLotProgression = PROG_NONE;
input ENUM_RECOVERY_MODE   InpRecoveryMode   = REC_NONE;
input ENUM_HEDGE_MODE      InpHedgeMode      = HEDGE_OFF;
input bool                 InpBasketEnabled  = false;
input bool                 InpDryRun         = false;   // true = log intents, no real orders

//==================== Entry: Grid Trend MA =========================
input group "=== Trade direction bias ==="
input ENUM_TRADE_DIR InpTradeDirection = TRADEDIR_BOTH;  // BOTH / LONG_ONLY / SHORT_ONLY

input group "=== Trend filter (entry quality gate) ==="
input ENUM_TREND_FILTER InpTrendFilter    = TFILTER_NONE; // NONE=always trade, ATR_EXPAND=trend only
input int               InpFilterATRMA    = 20;           // ATR_EXPAND: MA period for ATR smoothing
input double            InpFilterATRRatio = 1.0;          // ATR_EXPAND: trade when ATR > ratio*ATR_MA
input int               InpFilterSlopeBar = 3;            // MA_SLOPE: bars back to check slope

input group "=== Entry: Grid Trend MA ==="
input int            InpFastMA          = 20;
input int            InpSlowMA          = 50;
input ENUM_MA_METHOD InpMAMethod        = MODE_EMA;
input ENUM_TIMEFRAMES InpMA_TF          = PERIOD_CURRENT;
input bool           InpGridStepUseATR  = true;   // grid spacing from ATR (else points)
input double         InpGridStepATRmult = 1.0;
input double         InpGridStepPoints  = 300;
input int            InpMaxGridLevels   = 5;       // max stacked orders in trend

//==================== Exit (TP / trailing) =========================
input group "=== Exit (TP / trailing) ==="
input double InpTP_Points       = 500;    // EXIT_FIXED_TP
input double InpTP_ATRmult      = 3.0;    // EXIT_ATR_TP
input double InpTP_BasketMoney  = 0;      // close basket at +money (0=off)
input double InpTrailStartPoints= 300;    // EXIT_TRAIL
input double InpTrailStepPoints = 100;

//==================== Stop loss ====================================
input group "=== Stop loss ==="
input double InpSL_Points        = 1000;  // SL_FIXED_POINTS
input double InpSL_ATRmult       = 2.0;   // SL_ATR
input double InpSL_BasketMoney   = 0;     // SL_MONEY: close basket at -money (0=off)
input int    InpSL_DonchianBars  = 50;    // SL_STRUCT_DONCHIAN lookback
input int    InpSL_SRBars        = 20;    // SL_STRUCT_SR swing lookback

//==================== ATR (shared) =================================
input group "=== ATR (shared) ==="
input int             InpATR_Period = 14;
input ENUM_TIMEFRAMES InpATR_TF     = PERIOD_CURRENT;

//==================== Money management =============================
input group "=== Money management ==="
input double InpFixedLot      = 0.01;   // FIRSTLOT_FIXED
input double InpRiskPct       = 1.0;    // FIRSTLOT_RISK (% balance per first order)
input double InpProgFactor    = 0.5;    // LINEAR / LOG coefficient
input double InpProgMultiplier= 1.3;    // MULTIPLIER
input double InpProgPlusLot   = 0.01;   // PLUS additive step

//==================== Risk control (adjustable + protective) =======
// Defaults = recommended "cage" profile. These are optimizable inputs;
// staying inside the profile feeds a live-suitability (RiskControl) score
// computed later in the funnel. Hard kill below always protects.
input group "=== Risk control ==="
input double InpMaxLot             = 0.20;  // per-order lot ceiling (clamp)
input double InpMaxDepositLoadPct  = 30;    // block new orders above this used-margin %
input int    InpMaxRecoverySteps   = 3;     // cap progression levels
input double InpRecoveryMultMax    = 1.3;   // cap effective progression multiplier
input double InpCloseAllWhenDDPct  = 25;    // HARD KILL: equity DD% -> close all + halt

//==================== General ======================================
input group "=== General ==="
input long InpMagic           = 990001;
input int  InpSlippagePoints  = 20;
input int  InpMaxSpreadPoints = 0;      // 0 = ignore spread filter

#endif // EA_LAB_INPUTS_MQH
