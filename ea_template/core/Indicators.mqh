//+------------------------------------------------------------------+
//| Indicators.mqh (V2) - built-in handles only.                     |
//|  Signal-ATR (entry/stack) + Risk-ATR (SL/TP/sizing) = 2 contexts.|
//|  StdDev for SL mode 36. BB/RSI only built for entry 13.          |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_INDICATORS_MQH
#define BOSS_LAB_INDICATORS_MQH
#include "Inputs.mqh"

int g_hFastMA  = INVALID_HANDLE;
int g_hSlowMA  = INVALID_HANDLE;
int g_hATR     = INVALID_HANDLE;   // signal ATR
int g_hRiskATR = INVALID_HANDLE;   // risk ATR (SL/TP/MM)
int g_hSD      = INVALID_HANDLE;   // StdDev (SL mode 36)
#ifdef LAB_ENTRY_13
int g_hBB      = INVALID_HANDLE;
int g_hRSI     = INVALID_HANDLE;
#endif

ENUM_TIMEFRAMES Indi_TF(const ENUM_TIMEFRAMES tf) { return (tf == PERIOD_CURRENT ? _Period : tf); }

bool Indi_Init()
{
   g_hFastMA  = iMA(_Symbol, Indi_TF(_0_MA_TF), _0_FastMA, 0, _0_MAMethod, PRICE_CLOSE);
   g_hSlowMA  = iMA(_Symbol, Indi_TF(_0_MA_TF), _0_SlowMA, 0, _0_MAMethod, PRICE_CLOSE);
   g_hATR     = iATR(_Symbol, Indi_TF(_0_ATR_TF), _0_ATR_Period);
   g_hRiskATR = iATR(_Symbol, Indi_TF(_3_RiskATR_TF), _3_RiskATR_Period);
   g_hSD      = iStdDev(_Symbol, _Period, _36_SD_Period, 0, MODE_SMA, PRICE_CLOSE);
   bool ok = (g_hFastMA != INVALID_HANDLE && g_hSlowMA != INVALID_HANDLE &&
              g_hATR != INVALID_HANDLE && g_hRiskATR != INVALID_HANDLE && g_hSD != INVALID_HANDLE);
#ifdef LAB_ENTRY_13
   g_hBB  = iBands(_Symbol, _Period, _13_BB_Period, 0, _13_BB_Dev, PRICE_CLOSE);
   g_hRSI = iRSI(_Symbol, _Period, _13_RSI_Period, PRICE_CLOSE);
   ok = ok && (g_hBB != INVALID_HANDLE && g_hRSI != INVALID_HANDLE);
#endif
   return ok;
}

void Indi_Deinit()
{
   if(g_hFastMA  != INVALID_HANDLE) IndicatorRelease(g_hFastMA);
   if(g_hSlowMA  != INVALID_HANDLE) IndicatorRelease(g_hSlowMA);
   if(g_hATR     != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hRiskATR != INVALID_HANDLE) IndicatorRelease(g_hRiskATR);
   if(g_hSD      != INVALID_HANDLE) IndicatorRelease(g_hSD);
   g_hFastMA = g_hSlowMA = g_hATR = g_hRiskATR = g_hSD = INVALID_HANDLE;
#ifdef LAB_ENTRY_13
   if(g_hBB  != INVALID_HANDLE) IndicatorRelease(g_hBB);
   if(g_hRSI != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   g_hBB = g_hRSI = INVALID_HANDLE;
#endif
}

double Indi_CopyOne(const int handle, const int shift)
{
   double buf[];
   if(CopyBuffer(handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

double Indi_FastMA(const int shift = 0) { return Indi_CopyOne(g_hFastMA, shift); }
double Indi_SlowMA(const int shift = 0) { return Indi_CopyOne(g_hSlowMA, shift); }
double Indi_ATR(const int shift = 0)    { return Indi_CopyOne(g_hATR, shift); }     // signal
double Indi_RiskATR(const int shift = 0){ return Indi_CopyOne(g_hRiskATR, shift); } // risk
double Indi_SD(const int shift = 1)     { return Indi_CopyOne(g_hSD, shift); }

// ATR SMA over `period` bars (look-ahead safe: starts one bar back)
double Indi_ATR_MA(const int period, const int startShift = 1)
{
   double buf[];
   if(CopyBuffer(g_hATR, 0, startShift, period, buf) < period) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < period; i++) sum += buf[i];
   return sum / period;
}

// Risk-ATR SMA (for adaptive SL regime-scaling)
double Indi_RiskATR_MA(const int period, const int startShift = 1)
{
   double buf[];
   if(CopyBuffer(g_hRiskATR, 0, startShift, period, buf) < period) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < period; i++) sum += buf[i];
   return sum / period;
}

bool Indi_ATR_IsExpanding(const int period, const double ratio = 1.0)
{
   double atr_now = Indi_ATR(0);
   double atr_ma  = Indi_ATR_MA(period);
   if(atr_now <= 0.0 || atr_ma <= 0.0) return false;
   return atr_now > atr_ma * ratio;
}

bool Indi_MA_IsSloping(const int direction, const int barsBack = 3)
{
   double now  = Indi_FastMA(0);
   double prev = Indi_FastMA(barsBack);
   if(now <= 0.0 || prev <= 0.0) return false;
   if(direction == 1) return now > prev;
   if(direction == 2) return now < prev;
   return false;
}

double Indi_Point() { double p = SymbolInfoDouble(_Symbol, SYMBOL_POINT); return (p > 0.0 ? p : _Point); }

double Indi_ATR_Points(const int shift = 0)      { double pt = Indi_Point(); return (pt > 0.0 ? Indi_ATR(shift)/pt : 0.0); }
double Indi_RiskATR_Points(const int shift = 0)  { double pt = Indi_Point(); return (pt > 0.0 ? Indi_RiskATR(shift)/pt : 0.0); }

#ifdef LAB_ENTRY_13
double Indi_BB_Upper(const int shift = 1) { return Indi_CopyOne(g_hBB, shift); }   // buffer 0
double Indi_BB_Lower(const int shift = 1)
{
   double buf[];
   if(CopyBuffer(g_hBB, 2, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}
double Indi_RSI(const int shift = 1) { return Indi_CopyOne(g_hRSI, shift); }
#endif

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

#endif // BOSS_LAB_INDICATORS_MQH
