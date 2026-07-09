//+------------------------------------------------------------------+
//| Regime.mqh (V2) - additive market-state gate for NEW entries.    |
//| Trend/range via ADX(+DI/-DI); storm overlay via ATR spike.       |
//| Cached per _50_Regime_TF bar; mode 0 = inert/no-op.              |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_REGIME_MQH
#define BOSS_LAB_REGIME_MQH
#include "Inputs.mqh"

enum ENUM_REGIME_STATE
{
   REGIME_TREND_UP = 0,
   REGIME_TREND_DOWN,
   REGIME_RANGE,
   REGIME_STORM
};

int g_hRegimeADX = INVALID_HANDLE;
int g_hRegimeATR = INVALID_HANDLE;
datetime g_regime_last_bar = 0;
ENUM_REGIME_STATE g_regime_state = REGIME_RANGE;
bool g_regime_has_cache = false;

ENUM_TIMEFRAMES Regime_TF()
{
   return (_50_Regime_TF == PERIOD_CURRENT ? _Period : _50_Regime_TF);
}

bool Regime_Enabled()
{
   return (_50_RegimeMode == 1 || _50_RegimeMode == 2);
}

bool Regime_CopyOne(const int handle, const int buffer, const int shift, double &out)
{
   double buf[];
   if(CopyBuffer(handle, buffer, shift, 1, buf) < 1) return false;
   out = buf[0];
   return true;
}

bool Regime_ATR_SMA(const int period, const int startShift, double &out)
{
   if(period <= 0) return false;
   double buf[];
   if(CopyBuffer(g_hRegimeATR, 0, startShift, period, buf) < period) return false;
   double sum = 0.0;
   for(int i = 0; i < period; i++) sum += buf[i];
   out = sum / period;
   return true;
}

ENUM_REGIME_STATE Regime_ClassifyClosedBar()
{
   double adx = 0.0, plusDI = 0.0, minusDI = 0.0;
   if(!Regime_CopyOne(g_hRegimeADX, 0, 1, adx) ||
      !Regime_CopyOne(g_hRegimeADX, 1, 1, plusDI) ||
      !Regime_CopyOne(g_hRegimeADX, 2, 1, minusDI))
      return REGIME_RANGE;

   if(_50_StormATRmult > 0.0 && _50_StormLookback > 0)
   {
      double atrNow = 0.0, atrSma = 0.0;
      if(Regime_CopyOne(g_hRegimeATR, 0, 1, atrNow) &&
         Regime_ATR_SMA(_50_StormLookback, 2, atrSma) &&
         atrNow > 0.0 && atrSma > 0.0 &&
         atrNow > (_50_StormATRmult * atrSma))
         return REGIME_STORM;
   }

   if(adx < _50_ADX_TrendMin) return REGIME_RANGE;
   if(plusDI > minusDI) return REGIME_TREND_UP;
   if(minusDI > plusDI) return REGIME_TREND_DOWN;
   return REGIME_RANGE;
}

ENUM_REGIME_STATE Regime_Current()
{
   if(!Regime_Enabled()) return REGIME_RANGE;

   datetime barT = iTime(_Symbol, Regime_TF(), 0);
   if(barT <= 0) return REGIME_RANGE;

   if(!g_regime_has_cache || barT != g_regime_last_bar)
   {
      g_regime_last_bar = barT;
      g_regime_state = Regime_ClassifyClosedBar();
      g_regime_has_cache = true;
   }
   return g_regime_state;
}

bool Regime_BlocksFlatEntry()
{
   if(!Regime_Enabled()) return false;

   ENUM_REGIME_STATE state = Regime_Current();
   if(state == REGIME_STORM) return true;

   if(_50_RegimeMode == 1)
   {
      if(state == REGIME_TREND_UP) return !_50_AllowTrendUp;
      if(state == REGIME_TREND_DOWN) return !_50_AllowTrendDown;
      return !_50_AllowRange;
   }

   if(_50_RegimeMode == 2)
      return (state == REGIME_RANGE);

   return false;
}

bool Regime_AllowsEntryDirection(const int direction)
{
   if(!Regime_Enabled()) return true;
   if(direction != 1 && direction != 2) return true;

   ENUM_REGIME_STATE state = Regime_Current();
   if(state == REGIME_STORM) return false;

   if(_50_RegimeMode == 1)
   {
      if(state == REGIME_TREND_UP) return _50_AllowTrendUp;
      if(state == REGIME_TREND_DOWN) return _50_AllowTrendDown;
      return _50_AllowRange;
   }

   if(_50_RegimeMode == 2)
   {
      if(state == REGIME_TREND_UP) return (direction == 1);
      if(state == REGIME_TREND_DOWN) return (direction == 2);
      return false;
   }

   return true;
}

bool Regime_Init()
{
   g_hRegimeADX = INVALID_HANDLE;
   g_hRegimeATR = INVALID_HANDLE;
   g_regime_last_bar = 0;
   g_regime_state = REGIME_RANGE;
   g_regime_has_cache = false;

   if(!Regime_Enabled()) return true;

   g_hRegimeADX = iADX(_Symbol, Regime_TF(), _50_ADX_Period);
   g_hRegimeATR = iATR(_Symbol, Regime_TF(), _50_ADX_Period);
   return (g_hRegimeADX != INVALID_HANDLE && g_hRegimeATR != INVALID_HANDLE);
}

void Regime_Deinit()
{
   if(g_hRegimeADX != INVALID_HANDLE) IndicatorRelease(g_hRegimeADX);
   if(g_hRegimeATR != INVALID_HANDLE) IndicatorRelease(g_hRegimeATR);
   g_hRegimeADX = INVALID_HANDLE;
   g_hRegimeATR = INVALID_HANDLE;
   g_regime_last_bar = 0;
   g_regime_state = REGIME_RANGE;
   g_regime_has_cache = false;
}

#endif // BOSS_LAB_REGIME_MQH
