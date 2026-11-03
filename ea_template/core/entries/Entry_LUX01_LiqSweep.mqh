// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file core/entries/Entry_LUX01_LiqSweep.mqh
// sha256 87c67413e33242e9f372081dc4eaa713562c1e7f53806bdda3e3fe6579f00ef9; renumbered 22 -> 28 (inputs _22_* -> _28_*). Logic unchanged.
//+------------------------------------------------------------------+
//| Entry_LUX01_LiqSweep.mqh (V2 Pure Entry Module)                 |
//| Strategy: LuxAlgo Session Liquidity Sweep + CHoCH + FVG          |
//| Conformant to EA_Template V2 (IEntry.mqh). Pure signal only.     |
//| NO CTrade, NO OrderSend, NO Lot Sizing, NO hardcoded risk.       |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_LUX01_LIQSWEEP_MQH
#define BOSS_LAB_ENTRY_LUX01_LIQSWEEP_MQH

#include "IEntry.mqh"
#include "../Indicators.mqh"

// Safe parameter fallback for standalone test harness builds without shadowing Inputs.mqh
#ifndef BOSS_LAB_INPUTS_MQH
   int    _28_AsianHourFrom   = 0;
   int    _28_AsianHourTo     = 7;
   int    _28_TradeHourFrom   = 7;
   int    _28_TradeHourTo     = 16;
   int    _28_MaxSweepBars    = 12;
   double _28_MinFvgPips      = 3.0;
#else
   #ifndef LAB_ENTRY_28
      int    _28_AsianHourFrom   = 0;
      int    _28_AsianHourTo     = 7;
      int    _28_TradeHourFrom   = 7;
      int    _28_TradeHourTo     = 16;
      int    _28_MaxSweepBars    = 12;
      double _28_MinFvgPips      = 3.0;
   #endif
#endif

enum ENUM_LUX01_STAGE
{
   LUX01_STAGE_IDLE            = 0,
   LUX01_STAGE_SWEEP_DETECTED  = 1,
   LUX01_STAGE_CHOCH_CONFIRMED = 2,
   LUX01_STAGE_FVG_ACTIVE      = 3
};

// Global state variables for FSM
datetime         g_lux01_last_bar_time       = 0;
int              g_lux01_bar_number          = 0;
ENUM_LUX01_STAGE g_lux01_stage               = LUX01_STAGE_IDLE;
int              g_lux01_side                = 0; // 1 = BUY, 2 = SELL

int              g_lux01_current_day         = -1;
double           g_lux01_asian_high          = 0.0;
double           g_lux01_asian_low           = 999999.0;
bool             g_lux01_asian_complete      = false;
bool             g_lux01_session_traded      = false;

int              g_lux01_sweep_bar           = -1;
int              g_lux01_choch_bar           = -1;
double           g_lux01_fvg_top             = 0.0;
double           g_lux01_fvg_bottom          = 0.0;

// Diagnostic counters (complete closed-sum accounting)
int              g_lux01_n_eval              = 0;
int              g_lux01_n_bad_bar           = 0;
int              g_lux01_n_asian_building    = 0;
int              g_lux01_n_already_traded    = 0;
int              g_lux01_n_outside_session   = 0;
int              g_lux01_n_sweep_detected    = 0;
int              g_lux01_n_choch_confirmed   = 0;
int              g_lux01_n_fvg_activated     = 0;
int              g_lux01_n_fvg_waiting       = 0;
int              g_lux01_n_expired           = 0;
int              g_lux01_n_invalidated       = 0;
int              g_lux01_n_confirmed         = 0;
int              g_lux01_n_idle_monitoring   = 0;

//+------------------------------------------------------------------+
//| Reset transient setup state                                      |
//+------------------------------------------------------------------+
void LUX01_Reset()
{
   g_lux01_stage      = LUX01_STAGE_IDLE;
   g_lux01_side       = 0;
   g_lux01_sweep_bar  = -1;
   g_lux01_choch_bar  = -1;
   g_lux01_fvg_top    = 0.0;
   g_lux01_fvg_bottom = 0.0;
}

//+------------------------------------------------------------------+
//| Initialize module (recompile / init safe)                        |
//+------------------------------------------------------------------+
void Entry_LUX01_Init()
{
   g_lux01_last_bar_time     = 0;
   g_lux01_bar_number        = 0;
   g_lux01_current_day       = -1;
   g_lux01_asian_high        = 0.0;
   g_lux01_asian_low         = 999999.0;
   g_lux01_asian_complete    = false;
   g_lux01_session_traded    = false;

   g_lux01_n_eval            = 0;
   g_lux01_n_bad_bar         = 0;
   g_lux01_n_asian_building  = 0;
   g_lux01_n_already_traded  = 0;
   g_lux01_n_outside_session = 0;
   g_lux01_n_sweep_detected  = 0;
   g_lux01_n_choch_confirmed = 0;
   g_lux01_n_fvg_activated   = 0;
   g_lux01_n_fvg_waiting     = 0;
   g_lux01_n_expired         = 0;
   g_lux01_n_invalidated     = 0;
   g_lux01_n_confirmed       = 0;
   g_lux01_n_idle_monitoring = 0;

   LUX01_Reset();
}

//+------------------------------------------------------------------+
//| Log diagnostic counters with closed-sum invariant check          |
//+------------------------------------------------------------------+
void Entry_LUX01_LogCounters()
{
   int counted = g_lux01_n_bad_bar + g_lux01_n_asian_building + g_lux01_n_already_traded +
                 g_lux01_n_outside_session + g_lux01_n_sweep_detected + g_lux01_n_choch_confirmed +
                 g_lux01_n_fvg_activated + g_lux01_n_fvg_waiting + g_lux01_n_expired +
                 g_lux01_n_invalidated + g_lux01_n_confirmed + g_lux01_n_idle_monitoring;
   int unaccounted = g_lux01_n_eval - counted;

   PrintFormat("[22_LUX01][counters] evaluated=%d confirmed=%d unaccounted=%d | sweep=%d choch=%d fvg=%d | expired=%d inval=%d traded=%d outside=%d asian=%d bad=%d idle=%d",
               g_lux01_n_eval, g_lux01_n_confirmed, unaccounted,
               g_lux01_n_sweep_detected, g_lux01_n_choch_confirmed, g_lux01_n_fvg_activated,
               g_lux01_n_expired, g_lux01_n_invalidated, g_lux01_n_already_traded,
               g_lux01_n_outside_session, g_lux01_n_asian_building, g_lux01_n_bad_bar,
               g_lux01_n_idle_monitoring);

   if(unaccounted != 0)
   {
      PrintFormat("[22_LUX01][counters] WARN unaccounted=%d - invariant breached in Entry_LUX01_LogCounters", unaccounted);
   }
}

//+------------------------------------------------------------------+
//| Main Entry Evaluation function                                   |
//+------------------------------------------------------------------+
EntrySignal Entry_Evaluate()
{
   // 1. Evaluate once per completed candle at new bar open
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == 0) return Entry_MakeNone("LUX01: iTime unavailable");
   if(curBar == g_lux01_last_bar_time) return Entry_MakeNone("LUX01: intrabar tick");

   g_lux01_last_bar_time = curBar;
   g_lux01_bar_number++;
   g_lux01_n_eval++;

   // 2. Fetch completed bar prices
   double c1 = iClose(_Symbol, _Period, 1);
   double o1 = iOpen(_Symbol, _Period, 1);
   double h1 = iHigh(_Symbol, _Period, 1);
   double l1 = iLow(_Symbol, _Period, 1);
   datetime t1 = iTime(_Symbol, _Period, 1);

   double h3 = iHigh(_Symbol, _Period, 3);
   double l3 = iLow(_Symbol, _Period, 3);

   if(c1 <= 0.0 || o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || h3 <= 0.0 || l3 <= 0.0)
   {
      g_lux01_n_bad_bar++;
      return Entry_MakeNone("LUX01: bar data not ready");
   }

   MqlDateTime dt;
   TimeToStruct(t1, dt);

   // Check day transition: reset Asian range and daily traded latch
   if(dt.day != g_lux01_current_day)
   {
      g_lux01_current_day    = dt.day;
      g_lux01_asian_high     = 0.0;
      g_lux01_asian_low      = 999999.0;
      g_lux01_asian_complete = false;
      g_lux01_session_traded = false;
      LUX01_Reset();
   }

   // 3. Asian Session Accumulation (e.g. UTC 0..7)
   if(dt.hour >= _28_AsianHourFrom && dt.hour < _28_AsianHourTo)
   {
      g_lux01_asian_high = MathMax(g_lux01_asian_high, h1);
      g_lux01_asian_low  = MathMin(g_lux01_asian_low, l1);
      g_lux01_n_asian_building++;
      return Entry_MakeNone("LUX01: building Asian session range");
   }

   if(dt.hour >= _28_AsianHourTo && !g_lux01_asian_complete)
   {
      g_lux01_asian_complete = true;
   }

   if(!g_lux01_asian_complete)
   {
      g_lux01_n_asian_building++;
      return Entry_MakeNone("LUX01: awaiting Asian range completion");
   }

   if(g_lux01_session_traded)
   {
      g_lux01_n_already_traded++;
      return Entry_MakeNone("LUX01: session trade already consumed for today");
   }

   // 4. Trade Session Filter (e.g. UTC 7..16 London / NY)
   bool inTradeSession = (dt.hour >= _28_TradeHourFrom && dt.hour < _28_TradeHourTo);
   if(!inTradeSession)
   {
      if(g_lux01_stage != LUX01_STAGE_IDLE) LUX01_Reset();
      g_lux01_n_outside_session++;
      return Entry_MakeNone("LUX01: outside trading session");
   }

   double minFvgDist = _28_MinFvgPips * 10.0 * _Point;

   // 5. State Machine Management
   if(g_lux01_stage == LUX01_STAGE_FVG_ACTIVE)
   {
      if(g_lux01_bar_number - g_lux01_choch_bar > 8)
      {
         g_lux01_n_expired++;
         LUX01_Reset();
         return Entry_MakeNone("LUX01: FVG expired without retrace");
      }

      // Bullish FVG retrace
      if(g_lux01_side == 1)
      {
         if(c1 < g_lux01_fvg_bottom)
         {
            g_lux01_n_invalidated++;
            LUX01_Reset();
            return Entry_MakeNone("LUX01: FVG invalidated by close below bottom");
         }
         if(l1 <= g_lux01_fvg_top && c1 >= g_lux01_fvg_bottom)
         {
            g_lux01_n_confirmed++;
            g_lux01_session_traded = true;
            LUX01_Reset();

            EntrySignal sig;
            sig.direction  = 1;
            sig.strength   = 1.0;
            sig.confidence = 1.0;
            sig.valid      = true;
            sig.reason     = "LUX01_BULLISH_SWEEP_CHOCH_FVG";
            return sig;
         }
      }
      // Bearish FVG retrace
      else if(g_lux01_side == 2)
      {
         if(c1 > g_lux01_fvg_top)
         {
            g_lux01_n_invalidated++;
            LUX01_Reset();
            return Entry_MakeNone("LUX01: FVG invalidated by close above top");
         }
         if(h1 >= g_lux01_fvg_bottom && c1 <= g_lux01_fvg_top)
         {
            g_lux01_n_confirmed++;
            g_lux01_session_traded = true;
            LUX01_Reset();

            EntrySignal sig;
            sig.direction  = 2;
            sig.strength   = 1.0;
            sig.confidence = 1.0;
            sig.valid      = true;
            sig.reason     = "LUX01_BEARISH_SWEEP_CHOCH_FVG";
            return sig;
         }
      }

      g_lux01_n_fvg_waiting++;
      return Entry_MakeNone("LUX01: waiting for FVG retrace");
   }

   if(g_lux01_stage == LUX01_STAGE_CHOCH_CONFIRMED)
   {
      if(g_lux01_bar_number - g_lux01_choch_bar > 4)
      {
         g_lux01_n_expired++;
         LUX01_Reset();
         return Entry_MakeNone("LUX01: CHoCH expired without FVG creation");
      }

      // Check FVG creation (displacement between bar 1 and bar 3)
      if(g_lux01_side == 1 && l1 > h3 + minFvgDist)
      {
         g_lux01_fvg_top    = l1;
         g_lux01_fvg_bottom = h3;
         g_lux01_stage      = LUX01_STAGE_FVG_ACTIVE;
         g_lux01_n_fvg_activated++;
         return Entry_MakeNone("LUX01: Bullish FVG active, awaiting retrace");
      }
      else if(g_lux01_side == 2 && h1 < l3 - minFvgDist)
      {
         g_lux01_fvg_top    = l3;
         g_lux01_fvg_bottom = h1;
         g_lux01_stage      = LUX01_STAGE_FVG_ACTIVE;
         g_lux01_n_fvg_activated++;
         return Entry_MakeNone("LUX01: Bearish FVG active, awaiting retrace");
      }

      g_lux01_n_fvg_waiting++;
      return Entry_MakeNone("LUX01: waiting for FVG formation");
   }

   if(g_lux01_stage == LUX01_STAGE_SWEEP_DETECTED)
   {
      if(g_lux01_bar_number - g_lux01_sweep_bar > _28_MaxSweepBars)
      {
         g_lux01_n_expired++;
         LUX01_Reset();
         return Entry_MakeNone("LUX01: Sweep expired without CHoCH");
      }

      // Bullish CHoCH: strong displacement candle closing upward
      if(g_lux01_side == 1 && c1 > o1 && c1 > g_lux01_asian_low + minFvgDist)
      {
         g_lux01_stage     = LUX01_STAGE_CHOCH_CONFIRMED;
         g_lux01_choch_bar = g_lux01_bar_number;
         g_lux01_n_choch_confirmed++;
         return Entry_MakeNone("LUX01: Bullish CHoCH confirmed");
      }
      // Bearish CHoCH: strong displacement candle closing downward
      else if(g_lux01_side == 2 && c1 < o1 && c1 < g_lux01_asian_high - minFvgDist)
      {
         g_lux01_stage     = LUX01_STAGE_CHOCH_CONFIRMED;
         g_lux01_choch_bar = g_lux01_bar_number;
         g_lux01_n_choch_confirmed++;
         return Entry_MakeNone("LUX01: Bearish CHoCH confirmed");
      }

      g_lux01_n_idle_monitoring++;
      return Entry_MakeNone("LUX01: sweep active, awaiting CHoCH break");
   }

   // 6. IDLE Stage: Scan for Asian Range Sweep
   if(g_lux01_stage == LUX01_STAGE_IDLE)
   {
      // Bullish Sweep: Low breached Asian low, but bar closed back above Asian low
      if(l1 < g_lux01_asian_low && c1 > g_lux01_asian_low)
      {
         g_lux01_stage     = LUX01_STAGE_SWEEP_DETECTED;
         g_lux01_side      = 1;
         g_lux01_sweep_bar = g_lux01_bar_number;
         g_lux01_n_sweep_detected++;
         return Entry_MakeNone("LUX01: Asian Low liquidity sweep detected");
      }
      // Bearish Sweep: High breached Asian high, but bar closed back below Asian high
      else if(h1 > g_lux01_asian_high && c1 < g_lux01_asian_high)
      {
         g_lux01_stage     = LUX01_STAGE_SWEEP_DETECTED;
         g_lux01_side      = 2;
         g_lux01_sweep_bar = g_lux01_bar_number;
         g_lux01_n_sweep_detected++;
         return Entry_MakeNone("LUX01: Asian High liquidity sweep detected");
      }
   }

   g_lux01_n_idle_monitoring++;
   return Entry_MakeNone("LUX01: monitoring session range");
}

#endif // BOSS_LAB_ENTRY_LUX01_LIQSWEEP_MQH
