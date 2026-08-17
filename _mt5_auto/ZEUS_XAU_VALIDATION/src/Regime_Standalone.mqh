//+------------------------------------------------------------------+
//| Regime_Standalone.mqh — self-contained port of ea_template/core/  |
//| Regime.mqh (V2) for the standalone (Boss)_ZeusInspired_GridLog    |
//| chassis (STANDALONE_RISK_BUNDLE, NOT LabCore).                    |
//|                                                                    |
//| Identical trend/range (ADX +DI/-DI) + storm (ATR spike) classify  |
//| and entry-gate logic as the LabCore module. The ONLY change is    |
//| that the _50_* inputs are declared HERE (LabCore pulls them from  |
//| Inputs.mqh, which Zeus does not include). Cached per _50_Regime_TF |
//| bar; _50_RegimeMode 0 = inert/no-op (bit-identical to un-grafted). |
//|                                                                    |
//| Graft path = ORDER-057 adoption ("_50_ as a new funnel axis on    |
//| the next EA"). Direction convention 1=BUY / 2=SELL.               |
//+------------------------------------------------------------------+
#ifndef ZEUS_REGIME_STANDALONE_MQH
#define ZEUS_REGIME_STANDALONE_MQH

//--------------------------------------------------------------------
// [50] REGIME GATE — additive market-state filter for NEW baskets only
//--------------------------------------------------------------------
input string          _g50_               = "── [50] REGIME GATE ──────────────────────";
input int             _50_RegimeMode      = 0;          // 0=off 1=filter(block-range) 2=direction-lock
input bool            _50_AllowTrendUp    = true;       // mode 1 only
input bool            _50_AllowTrendDown  = true;       // mode 1 only
input bool            _50_AllowRange      = true;       // mode 1 only
input ENUM_TIMEFRAMES _50_Regime_TF       = PERIOD_H4;
input int             _50_ADX_Period      = 14;
input double          _50_ADX_TrendMin    = 25.0;
input double          _50_StormATRmult    = 2.0;        // 0=storm disabled
input int             _50_StormLookback   = 100;

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

#endif // ZEUS_REGIME_STANDALONE_MQH
