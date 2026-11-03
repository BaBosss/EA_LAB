// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file core/entries/Entry_LUX02_BOSRetest.mqh
// sha256 1bb472f7040fbe47dddb9710d14f756818489fe5cdea87fa77a0177c53cddc76; renumbered 20 -> 26 (inputs _20_* -> _26_*). Logic unchanged.
//+------------------------------------------------------------------+
//| Entry_LUX02_BOSRetest.mqh (V2 Pure Entry Module)                |
//| Strategy: LuxAlgo Valid BOS Pullback Retest Engine               |
//| Conformant to EA_Template V2 (IEntry.mqh). Pure signal only.     |
//| NO CTrade, NO OrderSend, NO Lot Sizing, NO hardcoded risk.       |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_LUX02_BOSRETEST_MQH
#define BOSS_LAB_ENTRY_LUX02_BOSRETEST_MQH

#include "IEntry.mqh"
#include "../Indicators.mqh"

// Safe parameter fallback for standalone test harness builds without shadowing Inputs.mqh
#ifndef BOSS_LAB_INPUTS_MQH
   int    _26_SwingDepth      = 5;
   int    _26_MaxPullbackBars = 25;
   double _26_RetestBufferATR = 0.3;
   double _26_InvalATR        = 1.5;
   int    _26_HourFrom        = 7;
   int    _26_HourTo          = 20;
#else
   #ifndef LAB_ENTRY_26
      // Fallback variables if Inputs.mqh is included without LAB_ENTRY_26 enabled
      int    _26_SwingDepth      = 5;
      int    _26_MaxPullbackBars = 25;
      double _26_RetestBufferATR = 0.3;
      double _26_InvalATR        = 1.5;
      int    _26_HourFrom        = 7;
      int    _26_HourTo          = 20;
   #endif
#endif

enum ENUM_LUX02_STAGE
{
   LUX02_STAGE_IDLE         = 0,
   LUX02_STAGE_WAIT_RETEST  = 1,
   LUX02_STAGE_WAIT_CONFIRM = 2
};

// Global state variables for causal FSM
datetime         g_lux02_last_bar_time       = 0;
int              g_lux02_bar_number          = 0;
ENUM_LUX02_STAGE g_lux02_stage               = LUX02_STAGE_IDLE;
int              g_lux02_side                = 0; // 1 = BUY, 2 = SELL
int              g_lux02_bos_index           = -1;
int              g_lux02_retest_index        = -1;

double           g_lux02_level               = 0.0;
double           g_lux02_stop_anchor         = 0.0;
double           g_lux02_last_stop_anchor    = 0.0;

datetime         g_lux02_last_high_pivot_time= 0;
double           g_lux02_last_high_pivot     = 0.0;
datetime         g_lux02_last_low_pivot_time = 0;
double           g_lux02_last_low_pivot      = 0.0;

// Anti-Infinite-Re-Arming latch: records pivot timestamps already armed/consumed
datetime         g_lux02_consumed_high_pivot_time = 0;
datetime         g_lux02_consumed_low_pivot_time  = 0;

// Diagnostic counters (complete closed-sum accounting)
int              g_lux02_n_eval              = 0;
int              g_lux02_n_bad_bar           = 0;
int              g_lux02_n_bos_armed         = 0;
int              g_lux02_n_retested          = 0;
int              g_lux02_n_waiting_retest    = 0;
int              g_lux02_n_confirmed         = 0;
int              g_lux02_n_waiting_confirm   = 0;
int              g_lux02_n_invalidated       = 0;
int              g_lux02_n_expired           = 0;
int              g_lux02_n_session_blocked   = 0;
int              g_lux02_n_idle_no_setup     = 0;

// Getter for structural stop anchor
double Entry_LUX02_GetLastStopAnchor()
{
   return g_lux02_last_stop_anchor;
}

//+------------------------------------------------------------------+
//| Reset transient state machine (keeps consumed pivot latches)     |
//+------------------------------------------------------------------+
void LUX02_Reset()
{
   g_lux02_stage              = LUX02_STAGE_IDLE;
   g_lux02_side               = 0;
   g_lux02_bos_index          = -1;
   g_lux02_retest_index       = -1;
   g_lux02_level              = 0.0;
   g_lux02_stop_anchor        = 0.0;
}

//+------------------------------------------------------------------+
//| Initialize module (recompile / init safe)                        |
//+------------------------------------------------------------------+
void Entry_LUX02_Init()
{
   g_lux02_last_bar_time            = 0;
   g_lux02_bar_number               = 0;
   g_lux02_last_high_pivot_time     = 0;
   g_lux02_last_high_pivot          = 0.0;
   g_lux02_last_low_pivot_time      = 0;
   g_lux02_last_low_pivot           = 0.0;
   g_lux02_consumed_high_pivot_time = 0;
   g_lux02_consumed_low_pivot_time  = 0;
   g_lux02_last_stop_anchor         = 0.0;

   g_lux02_n_eval                   = 0;
   g_lux02_n_bad_bar                = 0;
   g_lux02_n_bos_armed              = 0;
   g_lux02_n_retested               = 0;
   g_lux02_n_waiting_retest         = 0;
   g_lux02_n_confirmed              = 0;
   g_lux02_n_waiting_confirm        = 0;
   g_lux02_n_invalidated            = 0;
   g_lux02_n_expired                = 0;
   g_lux02_n_session_blocked        = 0;
   g_lux02_n_idle_no_setup          = 0;

   LUX02_Reset();
}

//+------------------------------------------------------------------+
//| Log diagnostic counters with unaccounted invariant check         |
//+------------------------------------------------------------------+
void Entry_LUX02_LogCounters()
{
   int counted = g_lux02_n_bad_bar + g_lux02_n_invalidated + g_lux02_n_expired +
                 g_lux02_n_retested + g_lux02_n_waiting_retest + g_lux02_n_session_blocked +
                 g_lux02_n_confirmed + g_lux02_n_waiting_confirm + g_lux02_n_bos_armed +
                 g_lux02_n_idle_no_setup;
   int unaccounted = g_lux02_n_eval - counted;

   PrintFormat("[20_LUX02][counters] evaluated=%d confirmed=%d unaccounted=%d | armed=%d retested=%d wait_retest=%d wait_confirm=%d | invalidated=%d expired=%d session_blocked=%d bad_bar=%d idle_no_setup=%d",
               g_lux02_n_eval, g_lux02_n_confirmed, unaccounted,
               g_lux02_n_bos_armed, g_lux02_n_retested, g_lux02_n_waiting_retest,
               g_lux02_n_waiting_confirm, g_lux02_n_invalidated, g_lux02_n_expired,
               g_lux02_n_session_blocked, g_lux02_n_bad_bar, g_lux02_n_idle_no_setup);

   if(unaccounted != 0)
   {
      PrintFormat("[20_LUX02][counters] WARN unaccounted=%d - a return path in Entry_Evaluate has no counter; accounting invariant breached", unaccounted);
   }
}

//+------------------------------------------------------------------+
//| Check pivot high at bar k (closed bars only)                     |
//+------------------------------------------------------------------+
bool LUX02_IsPivotHigh(const int k, const int depth)
{
   double pk = iHigh(_Symbol, _Period, k);
   if(pk <= 0.0) return false;
   for(int n = 1; n <= depth; n++)
   {
      double leftH  = iHigh(_Symbol, _Period, k + n);
      double rightH = iHigh(_Symbol, _Period, k - n);
      if(pk <= leftH || pk <= rightH) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check pivot low at bar k (closed bars only)                      |
//+------------------------------------------------------------------+
bool LUX02_IsPivotLow(const int k, const int depth)
{
   double pk = iLow(_Symbol, _Period, k);
   if(pk <= 0.0) return false;
   for(int n = 1; n <= depth; n++)
   {
      double leftL  = iLow(_Symbol, _Period, k + n);
      double rightL = iLow(_Symbol, _Period, k - n);
      if(pk >= leftL || pk >= rightL) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Main Entry Evaluation function (called per tick or bar open)     |
//+------------------------------------------------------------------+
EntrySignal Entry_Evaluate()
{
   // 1. Evaluate exactly once per closed bar at new bar open
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == 0) return Entry_MakeNone("LUX02: iTime unavailable");
   if(curBar == g_lux02_last_bar_time)
   {
      return Entry_MakeNone("LUX02: intrabar tick");
   }
   g_lux02_last_bar_time = curBar;
   g_lux02_bar_number++;
   g_lux02_n_eval++;

   // 2. Fetch completed candle prices (index 1 is completed bar, index 2 is prior closed bar)
   double c1 = iClose(_Symbol, _Period, 1);
   double o1 = iOpen(_Symbol, _Period, 1);
   double h1 = iHigh(_Symbol, _Period, 1);
   double l1 = iLow(_Symbol, _Period, 1);
   datetime t1 = iTime(_Symbol, _Period, 1);

   double c2 = iClose(_Symbol, _Period, 2);

   if(c1 <= 0.0 || o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c2 <= 0.0)
   {
      g_lux02_n_bad_bar++;
      return Entry_MakeNone("LUX02: bar 1/2 data not ready");
   }

   // 3. Scan for swing pivots confirmed at bar 1
   // A pivot of radius N is centered at k = N + 1
   int depth = (_26_SwingDepth >= 2 ? _26_SwingDepth : 5);
   int pivotIndex = depth + 1;

   if(LUX02_IsPivotHigh(pivotIndex, depth))
   {
      g_lux02_last_high_pivot      = iHigh(_Symbol, _Period, pivotIndex);
      g_lux02_last_high_pivot_time = iTime(_Symbol, _Period, pivotIndex);
   }
   if(LUX02_IsPivotLow(pivotIndex, depth))
   {
      g_lux02_last_low_pivot       = iLow(_Symbol, _Period, pivotIndex);
      g_lux02_last_low_pivot_time  = iTime(_Symbol, _Period, pivotIndex);
   }

   // ATR computation for buffers
   double atr = Indi_ATR(1);
   if(atr <= 0.0)
   {
      atr = 10.0 * _Point; // safe minimum fallback
   }
   double tol      = _26_RetestBufferATR * atr;
   double invalTol = _26_InvalATR * atr;

   // 4. State Machine: Non-Idle Management
   if(g_lux02_stage != LUX02_STAGE_IDLE)
   {
      // A. Check Invalidation
      bool invalid = (g_lux02_side == 1) ? (c1 < g_lux02_level - invalTol)
                                         : (c1 > g_lux02_level + invalTol);
      if(invalid)
      {
         g_lux02_n_invalidated++;
         LUX02_Reset();
         return Entry_MakeNone("LUX02: invalidated by closing beyond threshold");
      }

      // B. Check Expiry
      int age = g_lux02_bar_number - g_lux02_bos_index;
      int confirmedAge = (g_lux02_retest_index >= 0) ? (g_lux02_bar_number - g_lux02_retest_index) : 0;
      if(age > _26_MaxPullbackBars || (g_lux02_stage == LUX02_STAGE_WAIT_CONFIRM && confirmedAge > 10))
      {
         g_lux02_n_expired++;
         LUX02_Reset();
         return Entry_MakeNone("LUX02: expired setup age");
      }

      // C. Wait Retest Stage
      if(g_lux02_stage == LUX02_STAGE_WAIT_RETEST)
      {
         bool touch = (g_lux02_side == 1) ? (l1 <= g_lux02_level + tol)
                                          : (h1 >= g_lux02_level - tol);
         // Retest must occur on a strictly later bar than BOS
         if(g_lux02_bar_number - g_lux02_bos_index >= 1 && touch)
         {
            g_lux02_retest_index = g_lux02_bar_number;
            g_lux02_stage        = LUX02_STAGE_WAIT_CONFIRM;
            g_lux02_stop_anchor  = (g_lux02_side == 1 ? l1 : h1);
            g_lux02_n_retested++;
            return Entry_MakeNone("LUX02: retest touch registered, awaiting confirmation bar");
         }
         else
         {
            g_lux02_n_waiting_retest++;
            return Entry_MakeNone("LUX02: waiting for retest touch");
         }
      }

      // D. Wait Confirm Stage
      if(g_lux02_stage == LUX02_STAGE_WAIT_CONFIRM)
      {
         if(g_lux02_side == 1) g_lux02_stop_anchor = MathMin(g_lux02_stop_anchor, l1);
         else                  g_lux02_stop_anchor = MathMax(g_lux02_stop_anchor, h1);

         // Bullish confirmation: bar closes green and above the broken level
         // Bearish confirmation: bar closes red and below the broken level
         bool confirmed = (g_lux02_side == 1) ? (c1 > o1 && c1 > g_lux02_level)
                                              : (c1 < o1 && c1 < g_lux02_level);
         if(confirmed)
         {
            // Session filter check evaluated on confirmation bar timestamp t1
            if(_26_HourFrom != _26_HourTo)
            {
               MqlDateTime dt;
               TimeToStruct(t1, dt);
               int h = dt.hour;
               bool inSession = (_26_HourFrom <= _26_HourTo)
                                   ? (h >= _26_HourFrom && h < _26_HourTo)
                                   : (h >= _26_HourFrom || h < _26_HourTo);
               if(!inSession)
               {
                  g_lux02_n_session_blocked++;
                  LUX02_Reset();
                  return Entry_MakeNone("LUX02: confirmation outside session window");
               }
            }

            // Emit valid entry signal
            int triggerDir = g_lux02_side;
            g_lux02_n_confirmed++;
            g_lux02_last_stop_anchor = g_lux02_stop_anchor;
            LUX02_Reset(); // Level consumed

            EntrySignal sig;
            sig.direction  = triggerDir; // 1 = BUY, 2 = SELL
            sig.strength   = 1.0;
            sig.confidence = 1.0;
            sig.valid      = true;
            sig.reason     = (triggerDir == 1 ? "LUX02_BULLISH_BOS_RETEST_CONFIRMED"
                                              : "LUX02_BEARISH_BOS_RETEST_CONFIRMED");
            return sig;
         }
         else
         {
            g_lux02_n_waiting_confirm++;
            return Entry_MakeNone("LUX02: waiting for confirmation close");
         }
      }
   }

   // 5. Idle State: Scan for Break of Structure (BOS)
   if(g_lux02_stage == LUX02_STAGE_IDLE)
   {
      // Bullish BOS: candle closes above confirmed swing high that hasn't been consumed
      // Edge trigger: bar 2 was <= level and bar 1 closed > level (fresh crossing)
      if(g_lux02_last_high_pivot > 0.0 &&
         g_lux02_last_high_pivot_time > g_lux02_consumed_high_pivot_time &&
         c2 <= g_lux02_last_high_pivot && c1 > g_lux02_last_high_pivot)
      {
         g_lux02_stage                    = LUX02_STAGE_WAIT_RETEST;
         g_lux02_side                     = 1; // BUY setup
         g_lux02_bos_index                = g_lux02_bar_number;
         g_lux02_level                    = g_lux02_last_high_pivot;
         g_lux02_consumed_high_pivot_time = g_lux02_last_high_pivot_time; // Latch consumed pivot!
         g_lux02_n_bos_armed++;
         return Entry_MakeNone("LUX02: Bullish BOS detected, armed for retest");
      }

      // Bearish BOS: candle closes below confirmed swing low that hasn't been consumed
      // Edge trigger: bar 2 was >= level and bar 1 closed < level (fresh crossing)
      if(g_lux02_last_low_pivot > 0.0 &&
         g_lux02_last_low_pivot_time > g_lux02_consumed_low_pivot_time &&
         c2 >= g_lux02_last_low_pivot && c1 < g_lux02_last_low_pivot)
      {
         g_lux02_stage                    = LUX02_STAGE_WAIT_RETEST;
         g_lux02_side                     = 2; // SELL setup
         g_lux02_bos_index                = g_lux02_bar_number;
         g_lux02_level                    = g_lux02_last_low_pivot;
         g_lux02_consumed_low_pivot_time  = g_lux02_last_low_pivot_time; // Latch consumed pivot!
         g_lux02_n_bos_armed++;
         return Entry_MakeNone("LUX02: Bearish BOS detected, armed for retest");
      }
   }

   g_lux02_n_idle_no_setup++;
   return Entry_MakeNone("LUX02: no setup");
}

#endif // BOSS_LAB_ENTRY_LUX02_BOSRETEST_MQH
