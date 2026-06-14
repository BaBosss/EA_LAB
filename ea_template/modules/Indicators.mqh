//+------------------------------------------------------------------+
//| Indicators.mqh - built-in indicator handles only (iMA/iATR)      |
//| + price-structure helpers (iHighest/iLowest). NO external/custom |
//| indicators, so backtests run fast with no file dependencies.     |
//+------------------------------------------------------------------+
#ifndef EA_LAB_INDICATORS_MQH
#define EA_LAB_INDICATORS_MQH
#include "Inputs.mqh"

int g_hFastMA = INVALID_HANDLE;
int g_hSlowMA = INVALID_HANDLE;
int g_hATR    = INVALID_HANDLE;

ENUM_TIMEFRAMES Indi_TF(const ENUM_TIMEFRAMES tf) { return (tf == PERIOD_CURRENT ? _Period : tf); }

bool Indi_Init()
{
   g_hFastMA = iMA(_Symbol, Indi_TF(InpMA_TF), InpFastMA, 0, InpMAMethod, PRICE_CLOSE);
   g_hSlowMA = iMA(_Symbol, Indi_TF(InpMA_TF), InpSlowMA, 0, InpMAMethod, PRICE_CLOSE);
   g_hATR    = iATR(_Symbol, Indi_TF(InpATR_TF), InpATR_Period);
   return (g_hFastMA != INVALID_HANDLE && g_hSlowMA != INVALID_HANDLE && g_hATR != INVALID_HANDLE);
}

void Indi_Deinit()
{
   if(g_hFastMA != INVALID_HANDLE) IndicatorRelease(g_hFastMA);
   if(g_hSlowMA != INVALID_HANDLE) IndicatorRelease(g_hSlowMA);
   if(g_hATR    != INVALID_HANDLE) IndicatorRelease(g_hATR);
   g_hFastMA = g_hSlowMA = g_hATR = INVALID_HANDLE;
}

// returns 0.0 if buffer not ready yet (caller treats 0 as "no data")
double Indi_CopyOne(const int handle, const int shift)
{
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

double Indi_FastMA(const int shift = 0) { return Indi_CopyOne(g_hFastMA, shift); }
double Indi_SlowMA(const int shift = 0) { return Indi_CopyOne(g_hSlowMA, shift); }
double Indi_ATR(const int shift = 0)    { return Indi_CopyOne(g_hATR, shift); }

// ATR expressed in points (price/_Point)
double Indi_ATR_Points(const int shift = 0)
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0) return 0.0;
   return Indi_ATR(shift) / pt;
}

double Indi_LowestLow(const int bars, const int startShift = 1)
{
   int idx = iLowest(_Symbol, _Period, MODE_LOW, bars, startShift);
   if(idx < 0) return 0.0;
   return iLow(_Symbol, _Period, idx);
}

double Indi_HighestHigh(const int bars, const int startShift = 1)
{
   int idx = iHighest(_Symbol, _Period, MODE_HIGH, bars, startShift);
   if(idx < 0) return 0.0;
   return iHigh(_Symbol, _Period, idx);
}

#endif // EA_LAB_INDICATORS_MQH
