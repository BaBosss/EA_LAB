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

// AAM Module 4.3 (dual-threshold hysteresis) - fully additive state, separate
// from g_regime_state above. Regime_Current()/Regime_BlocksFlatEntry()/
// Regime_AllowsEntryDirection() are untouched by this block on purpose: the
// existing regression baseline must stay byte-identical for callers who never
// opt into Regime_ClassifyStable().
datetime g_regime_stable_last_bar = 0;
bool     g_regime_stable_has_cache = false;
ENUM_REGIME_STATE g_regime_stable_state     = REGIME_RANGE;
ENUM_REGIME_STATE g_regime_stable_candidate = REGIME_RANGE;
int      g_regime_stable_confirm = 0;

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

// Raw classification for the hysteresis wrapper: same STORM overlay + DI-direction
// logic as Regime_ClassifyClosedBar(), but the trend/range boundary uses
// _50_ADX_TrendMin as the IN threshold (entering trend) and _50_ADX_TrendMin_Exit
// as the OUT threshold (leaving trend) depending on whether the caller-supplied
// "currently stable" state is already trending. This is the dual-threshold half
// of AAM spec Module 4.3; the confirm-bar counter lives in Regime_ClassifyStable().
ENUM_REGIME_STATE Regime_ClassifyRawHyst(const ENUM_REGIME_STATE currentStable)
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

   bool wasTrend = (currentStable == REGIME_TREND_UP || currentStable == REGIME_TREND_DOWN);
   double threshold = (wasTrend ? _50_ADX_TrendMin_Exit : _50_ADX_TrendMin);
   if(adx < threshold) return REGIME_RANGE;
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

// AAM Module 4.3 - dual-threshold + confirm-bars hysteresis wrapper. Opt-in: no
// existing caller is switched to this path by this change. Cached per
// Regime_TF() closed bar, same as Regime_Current(), but keeps its own
// state/candidate/confirm counters so the two paths cannot cross-contaminate.
ENUM_REGIME_STATE Regime_ClassifyStable()
{
   if(!Regime_Enabled()) return REGIME_RANGE;

   datetime barT = iTime(_Symbol, Regime_TF(), 0);
   if(barT <= 0) return g_regime_stable_state;

   if(g_regime_stable_has_cache && barT == g_regime_stable_last_bar)
      return g_regime_stable_state;

   g_regime_stable_last_bar   = barT;
   g_regime_stable_has_cache  = true;

   ENUM_REGIME_STATE raw = Regime_ClassifyRawHyst(g_regime_stable_state);

   if(raw == g_regime_stable_state)
   {
      g_regime_stable_confirm = 0;
      return g_regime_stable_state;
   }

   int confirmBars = (_50_RegimeConfirmBars > 0 ? _50_RegimeConfirmBars : 1);
   if(raw == g_regime_stable_candidate)
   {
      g_regime_stable_confirm++;
      if(g_regime_stable_confirm >= confirmBars)
      {
         g_regime_stable_state   = g_regime_stable_candidate;
         g_regime_stable_confirm = 0;
      }
   }
   else
   {
      g_regime_stable_candidate = raw;
      g_regime_stable_confirm   = 1;
   }
   return g_regime_stable_state;
}

// AAM Module 4.6 - advisory exit-mode suggestion by regime. Pure function, no
// side effects, not called from the default OnTick pipeline: ExitManager.mqh
// includes this file so a future order can wire it in behind its own opt-in
// input, without this order changing anyone's live exit behavior today.
// TREND -> runner-style exit; RANGE -> ATR TP (no runner); STORM/unknown ->
// no suggestion, return the currently configured ExitMode unchanged.
ENUM_EXIT_MODE Regime_SuggestExitMode()
{
   switch(Regime_ClassifyStable())
   {
      case REGIME_TREND_UP:
      case REGIME_TREND_DOWN: return EXIT_RUN_TREND;
      case REGIME_RANGE:      return EXIT_ATR_TP;
      default:                return ExitMode;
   }
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

   g_regime_stable_last_bar   = 0;
   g_regime_stable_has_cache  = false;
   g_regime_stable_state      = REGIME_RANGE;
   g_regime_stable_candidate  = REGIME_RANGE;
   g_regime_stable_confirm    = 0;

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

   g_regime_stable_last_bar   = 0;
   g_regime_stable_has_cache  = false;
   g_regime_stable_state      = REGIME_RANGE;
   g_regime_stable_candidate  = REGIME_RANGE;
   g_regime_stable_confirm    = 0;
}

#endif // BOSS_LAB_REGIME_MQH
