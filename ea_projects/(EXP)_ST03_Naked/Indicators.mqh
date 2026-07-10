//+------------------------------------------------------------------+
//| Indicators.mqh — MINIMAL SHIM for (EXP)_ST03_Naked (ORDER-071    |
//| rev02 Stage 1). Satisfies the verbatim entries\Entry_ST03.mqh    |
//| copy's `#include "../Indicators.mqh"` without dragging the full  |
//| ea_template core chain (Inputs.mqh defines an ExitMode enum that |
//| collides with this experiment's required `input ExitMode` name). |
//| Every symbol below is copied VERBATIM from the lab core:         |
//|  - ENUM_TRADE_DIR values 60/61/62  = ea_template\core\Inputs.mqh |
//|  - _15_* input defaults            = ea_template\core\Inputs.mqh |
//|  - Indi_MACD() + iMACD() handle    = ea_template\core\Indicators |
//|    .mqh (LAB_ENTRY_15 block)                                     |
//| Source snapshot date: 2026-07-10. Do not edit values.            |
//+------------------------------------------------------------------+
#ifndef EXP_ST03NKD_INDICATORS_MQH
#define EXP_ST03NKD_INDICATORS_MQH

// verbatim enum (core Inputs.mqh: value = numbered-dropdown code)
enum ENUM_TRADE_DIR
{
   TRADEDIR_BOTH       = 60,  // 60 Both
   TRADEDIR_LONG_ONLY  = 61,  // 61 Long only
   TRADEDIR_SHORT_ONLY = 62   // 62 Short only
};

input group "=== 15 Entry: ST03 (verbatim lab defaults) ==="
input int            _15_MacdFast    = 12;    // MACD fast EMA (matches EA_RUNNER_ST03 defaults)
input int            _15_MacdSlow    = 26;    // MACD slow EMA
input int            _15_MacdSignal  = 9;     // MACD signal SMA
input int            _15_CountBars   = 2;     // consecutive closed bars in one MACD state before firing
input bool           _15_EdgeTrigger = true;  // true=fire once per state-run (ST_EA03) / false=level (over-trades)
input int            _15_RearmBars   = 0;     // re-fire every K bars within a run (0=pure edge, 1~=level)
input ENUM_TRADE_DIR TradeDir        = TRADEDIR_BOTH;   // Direction 6x

int g_hMACD = INVALID_HANDLE;   // built-in iMACD (entry 15 only)

bool Indi_Init()
{
   g_hMACD = iMACD(_Symbol, _Period, _15_MacdFast, _15_MacdSlow, _15_MacdSignal, PRICE_CLOSE);
   return (g_hMACD != INVALID_HANDLE);
}

void Indi_Deinit()
{
   if(g_hMACD != INVALID_HANDLE) IndicatorRelease(g_hMACD);
   g_hMACD = INVALID_HANDLE;
}

// MACD main (buffer 0) + signal (buffer 1) at shift, success-flagged because
// legitimate MACD values can be 0.0 (the Indi_CopyOne sentinel is ambiguous here)
bool Indi_MACD(const int shift, double &mainOut, double &signalOut)
{
   double m[], s[];
   if(CopyBuffer(g_hMACD, 0, shift, 1, m) < 1) return false;
   if(CopyBuffer(g_hMACD, 1, shift, 1, s) < 1) return false;
   mainOut = m[0]; signalOut = s[0];
   return true;
}

#endif // EXP_ST03NKD_INDICATORS_MQH
