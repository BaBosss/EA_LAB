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
int g_hBB     = INVALID_HANDLE;
int g_hRSI    = INVALID_HANDLE;

ENUM_TIMEFRAMES Indi_TF(const ENUM_TIMEFRAMES tf) { return (tf == PERIOD_CURRENT ? _Period : tf); }

bool Indi_Init()
{
   g_hFastMA = iMA(_Symbol, Indi_TF(InpMA_TF), InpFastMA, 0, InpMAMethod, PRICE_CLOSE);
   g_hSlowMA = iMA(_Symbol, Indi_TF(InpMA_TF), InpSlowMA, 0, InpMAMethod, PRICE_CLOSE);
   g_hATR    = iATR(_Symbol, Indi_TF(InpATR_TF), InpATR_Period);
   g_hBB     = iBands(_Symbol, _Period, InpMR_BB_Period, 0, InpMR_BB_Dev, PRICE_CLOSE);
   g_hRSI    = iRSI(_Symbol, _Period, InpMR_RSI_Period, PRICE_CLOSE);
   return (g_hFastMA != INVALID_HANDLE && g_hSlowMA != INVALID_HANDLE &&
           g_hATR != INVALID_HANDLE && g_hBB != INVALID_HANDLE && g_hRSI != INVALID_HANDLE);
}

void Indi_Deinit()
{
   if(g_hFastMA != INVALID_HANDLE) IndicatorRelease(g_hFastMA);
   if(g_hSlowMA != INVALID_HANDLE) IndicatorRelease(g_hSlowMA);
   if(g_hATR    != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hBB     != INVALID_HANDLE) IndicatorRelease(g_hBB);
   if(g_hRSI    != INVALID_HANDLE) IndicatorRelease(g_hRSI);
   g_hFastMA = g_hSlowMA = g_hATR = g_hBB = g_hRSI = INVALID_HANDLE;
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

// ATR simple moving average (uses existing g_hATR buffer — no extra handle needed)
// shift=1 to avoid look-ahead: reads period bars starting one bar back
double Indi_ATR_MA(const int period, const int startShift = 1)
{
   double buf[];
   if(CopyBuffer(g_hATR, 0, startShift, period, buf) < period) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < period; i++) sum += buf[i];
   return sum / period;
}

// True when ATR(0) > ATR_MA * ratio (volatility expanding = trending)
bool Indi_ATR_IsExpanding(const int period, const double ratio = 1.0)
{
   double atr_now = Indi_ATR(0);
   double atr_ma  = Indi_ATR_MA(period);
   if(atr_now <= 0.0 || atr_ma <= 0.0) return false;
   return atr_now > atr_ma * ratio;
}

// True when fast MA is sloping in direction: dir=1 means fastMA rising, dir=2 falling
bool Indi_MA_IsSloping(const int direction, const int barsBack = 3)
{
   double now  = Indi_FastMA(0);
   double prev = Indi_FastMA(barsBack);
   if(now <= 0.0 || prev <= 0.0) return false;
   if(direction == 1) return now > prev;
   if(direction == 2) return now < prev;
   return false;
}

// ATR expressed in points (price/_Point)
double Indi_ATR_Points(const int shift = 0)
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0) return 0.0;
   return Indi_ATR(shift) / pt;
}

// BB buffers: 0=upper, 1=basis(mid), 2=lower
double Indi_BB_Upper(const int shift = 1) { return Indi_CopyOne(g_hBB, shift); }   // uses buffer 0
double Indi_BB_Lower(const int shift = 1)
{
   double buf[];
   if(CopyBuffer(g_hBB, 2, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}
double Indi_RSI(const int shift = 1) { return Indi_CopyOne(g_hRSI, shift); }

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
