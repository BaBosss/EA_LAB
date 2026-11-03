// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file core/entries/Entry_LUX03_OrderBlock.mqh
// sha256 447391487f78cd9c6600a6a633a1aed6bbdbd2f7a59fc2e2489e3af8ca8b3bd2; number kept (23). Logic unchanged.
//+------------------------------------------------------------------+
//| Entry_LUX03_OrderBlock.mqh (V2 Pure Entry Module)               |
//| Strategy: LuxAlgo Confirmed Volume Order Block (OB) Retest       |
//| Conformant to EA_Template V2 (IEntry.mqh). Pure signal only.     |
//| NO CTrade, NO OrderSend, NO Lot Sizing, NO hardcoded risk.       |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_LUX03_ORDERBLOCK_MQH
#define BOSS_LAB_ENTRY_LUX03_ORDERBLOCK_MQH

#include "IEntry.mqh"
#include "../Indicators.mqh"

// Safe parameter fallback for standalone test harness builds without shadowing Inputs.mqh
#ifndef BOSS_LAB_INPUTS_MQH
   int    _23_OB_SwingDepth       = 5;
   double _23_OB_VolMult          = 1.5;
   int    _23_OB_MaxZoneAge       = 40;
   bool   _23_OB_RequireDiscount  = true;
   int    _23_OB_HourFrom         = 7;
   int    _23_OB_HourTo           = 19;
#else
   #ifndef LAB_ENTRY_23
      int    _23_OB_SwingDepth       = 5;
      double _23_OB_VolMult          = 1.5;
      int    _23_OB_MaxZoneAge       = 40;
      bool   _23_OB_RequireDiscount  = true;
      int    _23_OB_HourFrom         = 7;
      int    _23_OB_HourTo           = 19;
   #endif
#endif

enum ENUM_LUX03_STAGE
{
   LUX03_STAGE_SCANNING        = 0,
   LUX03_STAGE_AWAITING_RETEST = 1,
   LUX03_STAGE_IN_ZONE         = 2
};

// Global state variables for FSM
datetime         g_lux03_last_bar_time       = 0;
int              g_lux03_bar_number          = 0;
ENUM_LUX03_STAGE g_lux03_stage               = LUX03_STAGE_SCANNING;
int              g_lux03_side                = 0; // 1 = BUY, 2 = SELL

double           g_lux03_ob_top              = 0.0;
double           g_lux03_ob_bottom           = 0.0;
int              g_lux03_ob_bar              = -1;
datetime         g_lux03_ob_time             = 0;

double           g_lux03_swing_high          = 0.0;
double           g_lux03_swing_low           = 999999.0;

// Diagnostic counters (complete closed-sum accounting)
int              g_lux03_n_eval              = 0;
int              g_lux03_n_bad_bar           = 0;
int              g_lux03_n_outside_session   = 0;
int              g_lux03_n_ob_formed         = 0;
int              g_lux03_n_zone_touch        = 0;
int              g_lux03_n_waiting_touch     = 0;
int              g_lux03_n_rejection_waiting = 0;
int              g_lux03_n_zone_aged         = 0;
int              g_lux03_n_mitigated         = 0;
int              g_lux03_n_discount_veto     = 0;
int              g_lux03_n_confirmed         = 0;
int              g_lux03_n_scanning_idle     = 0;

//+------------------------------------------------------------------+
//| Reset transient zone state                                       |
//+------------------------------------------------------------------+
void LUX03_Reset()
{
   g_lux03_stage     = LUX03_STAGE_SCANNING;
   g_lux03_side      = 0;
   g_lux03_ob_top    = 0.0;
   g_lux03_ob_bottom = 0.0;
   g_lux03_ob_bar    = -1;
   g_lux03_ob_time   = 0;
}

//+------------------------------------------------------------------+
//| Initialize module (recompile / init safe)                        |
//+------------------------------------------------------------------+
void Entry_LUX03_Init()
{
   g_lux03_last_bar_time       = 0;
   g_lux03_bar_number          = 0;
   g_lux03_swing_high          = 0.0;
   g_lux03_swing_low           = 999999.0;

   g_lux03_n_eval              = 0;
   g_lux03_n_bad_bar           = 0;
   g_lux03_n_outside_session   = 0;
   g_lux03_n_ob_formed         = 0;
   g_lux03_n_zone_touch        = 0;
   g_lux03_n_waiting_touch     = 0;
   g_lux03_n_rejection_waiting = 0;
   g_lux03_n_zone_aged         = 0;
   g_lux03_n_mitigated         = 0;
   g_lux03_n_discount_veto     = 0;
   g_lux03_n_confirmed         = 0;
   g_lux03_n_scanning_idle     = 0;

   LUX03_Reset();
}

//+------------------------------------------------------------------+
//| Log diagnostic counters with closed-sum invariant check          |
//+------------------------------------------------------------------+
void Entry_LUX03_LogCounters()
{
   int counted = g_lux03_n_bad_bar + g_lux03_n_outside_session + g_lux03_n_ob_formed +
                 g_lux03_n_zone_touch + g_lux03_n_waiting_touch + g_lux03_n_rejection_waiting +
                 g_lux03_n_zone_aged + g_lux03_n_mitigated + g_lux03_n_discount_veto +
                 g_lux03_n_confirmed + g_lux03_n_scanning_idle;
   int unaccounted = g_lux03_n_eval - counted;

   PrintFormat("[23_LUX03][counters] evaluated=%d confirmed=%d unaccounted=%d | ob_formed=%d touch=%d wait_touch=%d wait_reject=%d | aged=%d mitigated=%d veto=%d outside=%d bad=%d scanning=%d",
               g_lux03_n_eval, g_lux03_n_confirmed, unaccounted,
               g_lux03_n_ob_formed, g_lux03_n_zone_touch, g_lux03_n_waiting_touch,
               g_lux03_n_rejection_waiting, g_lux03_n_zone_aged, g_lux03_n_mitigated,
               g_lux03_n_discount_veto, g_lux03_n_outside_session, g_lux03_n_bad_bar,
               g_lux03_n_scanning_idle);

   if(unaccounted != 0)
   {
      PrintFormat("[23_LUX03][counters] WARN unaccounted=%d - invariant breached in Entry_LUX03_LogCounters", unaccounted);
   }
}

//+------------------------------------------------------------------+
//| Main Entry Evaluation function                                   |
//+------------------------------------------------------------------+
EntrySignal Entry_Evaluate()
{
   // 1. Evaluate once per completed candle at new bar open
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == 0) return Entry_MakeNone("LUX03: iTime unavailable");
   if(curBar == g_lux03_last_bar_time) return Entry_MakeNone("LUX03: intrabar tick");

   g_lux03_last_bar_time = curBar;
   g_lux03_bar_number++;
   g_lux03_n_eval++;

   // 2. Fetch completed candle data
   double c1 = iClose(_Symbol, _Period, 1);
   double o1 = iOpen(_Symbol, _Period, 1);
   double h1 = iHigh(_Symbol, _Period, 1);
   double l1 = iLow(_Symbol, _Period, 1);
   long   v1 = iTickVolume(_Symbol, _Period, 1);
   datetime t1 = iTime(_Symbol, _Period, 1);

   double c2 = iClose(_Symbol, _Period, 2);
   double o2 = iOpen(_Symbol, _Period, 2);
   double h2 = iHigh(_Symbol, _Period, 2);
   double l2 = iLow(_Symbol, _Period, 2);

   if(c1 <= 0.0 || o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c2 <= 0.0 || o2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
   {
      g_lux03_n_bad_bar++;
      return Entry_MakeNone("LUX03: bar data not ready");
   }

   // 3. Update broad swing equilibrium
   g_lux03_swing_high = MathMax(g_lux03_swing_high, h1);
   g_lux03_swing_low  = MathMin(g_lux03_swing_low, l1);
   double equilibrium = (g_lux03_swing_high + g_lux03_swing_low) / 2.0;

   // 4. Session Check
   MqlDateTime dt;
   TimeToStruct(t1, dt);
   bool inSession = (_23_OB_HourFrom <= _23_OB_HourTo)
                       ? (dt.hour >= _23_OB_HourFrom && dt.hour < _23_OB_HourTo)
                       : (dt.hour >= _23_OB_HourFrom || dt.hour < _23_OB_HourTo);
   if(!inSession)
   {
      if(g_lux03_stage != LUX03_STAGE_SCANNING) LUX03_Reset();
      g_lux03_n_outside_session++;
      return Entry_MakeNone("LUX03: outside operating hours");
   }

   // 5. State Machine Management
   if(g_lux03_stage == LUX03_STAGE_IN_ZONE)
   {
      if(g_lux03_bar_number - g_lux03_ob_bar > _23_OB_MaxZoneAge)
      {
         g_lux03_n_zone_aged++;
         LUX03_Reset();
         return Entry_MakeNone("LUX03: order block aged out");
      }

      // Bullish OB rejection: candle closes back above OB top
      if(g_lux03_side == 1)
      {
         if(c1 < g_lux03_ob_bottom) // Mitigated/breached
         {
            g_lux03_n_mitigated++;
            LUX03_Reset();
            return Entry_MakeNone("LUX03: Bullish OB mitigated by close below bottom");
         }
         if(c1 > g_lux03_ob_top)
         {
            // Discount zone gate
            if(_23_OB_RequireDiscount && c1 > equilibrium)
            {
               g_lux03_n_discount_veto++;
               LUX03_Reset();
               return Entry_MakeNone("LUX03: Bullish OB entry vetoed outside discount zone");
            }

            g_lux03_n_confirmed++;
            LUX03_Reset(); // Zone consumed

            EntrySignal sig;
            sig.direction  = 1;
            sig.strength   = 1.0;
            sig.confidence = 1.0;
            sig.valid      = true;
            sig.reason     = "LUX03_BULLISH_OB_RETEST_CONFIRMED";
            return sig;
         }
      }
      // Bearish OB rejection: candle closes back below OB bottom
      else if(g_lux03_side == 2)
      {
         if(c1 > g_lux03_ob_top) // Mitigated/breached
         {
            g_lux03_n_mitigated++;
            LUX03_Reset();
            return Entry_MakeNone("LUX03: Bearish OB mitigated by close above top");
         }
         if(c1 < g_lux03_ob_bottom)
         {
            // Premium zone gate
            if(_23_OB_RequireDiscount && c1 < equilibrium)
            {
               g_lux03_n_discount_veto++;
               LUX03_Reset();
               return Entry_MakeNone("LUX03: Bearish OB entry vetoed outside premium zone");
            }

            g_lux03_n_confirmed++;
            LUX03_Reset(); // Zone consumed

            EntrySignal sig;
            sig.direction  = 2;
            sig.strength   = 1.0;
            sig.confidence = 1.0;
            sig.valid      = true;
            sig.reason     = "LUX03_BEARISH_OB_RETEST_CONFIRMED";
            return sig;
         }
      }

      g_lux03_n_rejection_waiting++;
      return Entry_MakeNone("LUX03: inside OB zone, awaiting rejection close");
   }

   if(g_lux03_stage == LUX03_STAGE_AWAITING_RETEST)
   {
      if(g_lux03_bar_number - g_lux03_ob_bar > _23_OB_MaxZoneAge)
      {
         g_lux03_n_zone_aged++;
         LUX03_Reset();
         return Entry_MakeNone("LUX03: order block aged out");
      }

      // Check touch into zone
      if(g_lux03_side == 1)
      {
         if(c1 < g_lux03_ob_bottom)
         {
            g_lux03_n_mitigated++;
            LUX03_Reset();
            return Entry_MakeNone("LUX03: Bullish OB mitigated before retest");
         }
         if(l1 <= g_lux03_ob_top && h1 >= g_lux03_ob_bottom)
         {
            g_lux03_stage = LUX03_STAGE_IN_ZONE;
            g_lux03_n_zone_touch++;
            return Entry_MakeNone("LUX03: Bullish OB touched, entering zone");
         }
      }
      else if(g_lux03_side == 2)
      {
         if(c1 > g_lux03_ob_top)
         {
            g_lux03_n_mitigated++;
            LUX03_Reset();
            return Entry_MakeNone("LUX03: Bearish OB mitigated before retest");
         }
         if(h1 >= g_lux03_ob_bottom && l1 <= g_lux03_ob_top)
         {
            g_lux03_stage = LUX03_STAGE_IN_ZONE;
            g_lux03_n_zone_touch++;
            return Entry_MakeNone("LUX03: Bearish OB touched, entering zone");
         }
      }

      g_lux03_n_waiting_touch++;
      return Entry_MakeNone("LUX03: awaiting OB zone touch");
   }

   // 6. Stage: SCANNING -> Identify Volume Order Block
   if(g_lux03_stage == LUX03_STAGE_SCANNING)
   {
      // Calculate 20-period volume SMA
      double volSum = 0.0;
      for(int i = 1; i <= 20; i++)
      {
         volSum += (double)iTickVolume(_Symbol, _Period, i);
      }
      double volSma = volSum / 20.0;
      bool volSpike = (volSma > 0.0 && (double)v1 >= volSma * _23_OB_VolMult);

      // Bullish OB: Bar 2 was down candle (Close < Open), Bar 1 is high volume rally breaking Bar 2 High
      if(c2 < o2 && c1 > h2 && volSpike)
      {
         g_lux03_stage     = LUX03_STAGE_AWAITING_RETEST;
         g_lux03_side      = 1;
         g_lux03_ob_top    = h2;
         g_lux03_ob_bottom = l2;
         g_lux03_ob_bar    = g_lux03_bar_number;
         g_lux03_ob_time   = iTime(_Symbol, _Period, 2);
         g_lux03_n_ob_formed++;
         return Entry_MakeNone("LUX03: Bullish Volume Order Block identified");
      }
      // Bearish OB: Bar 2 was up candle (Close > Open), Bar 1 is high volume drop breaking Bar 2 Low
      else if(c2 > o2 && c1 < l2 && volSpike)
      {
         g_lux03_stage     = LUX03_STAGE_AWAITING_RETEST;
         g_lux03_side      = 2;
         g_lux03_ob_top    = h2;
         g_lux03_ob_bottom = l2;
         g_lux03_ob_bar    = g_lux03_bar_number;
         g_lux03_ob_time   = iTime(_Symbol, _Period, 2);
         g_lux03_n_ob_formed++;
         return Entry_MakeNone("LUX03: Bearish Volume Order Block identified");
      }
   }

   g_lux03_n_scanning_idle++;
   return Entry_MakeNone("LUX03: scanning for order blocks");
}

#endif // BOSS_LAB_ENTRY_LUX03_ORDERBLOCK_MQH
