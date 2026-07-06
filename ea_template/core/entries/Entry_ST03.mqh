//+------------------------------------------------------------------+
//| Entry_ST03.mqh (V2) - MACD consecutive-count signal (MERGE-07).  |
//| Port of EA_CORE StrategySignal_v4 (the ST_EA03 "Count MACD" core, |
//| OOS PF 2.47 GBPUSD H1 on the ORIGINAL standalone). Logic verbatim:|
//|  - closed bar (shift 1): main>signal = buy-state, < = sell-state  |
//|  - consecutive count cb/cs; emit when count >= _15_CountBars      |
//|  - EDGE trigger (default): fire ONCE per state-run, latch until   |
//|    the MACD state flips (level mode over-trades: 571 vs 36 trades |
//|    - the exact bug the edge latch was built to fix)               |
//|  - _15_RearmBars (Part C): re-fire every K bars within a run      |
//| Counters advance once per NEW bar only; intrabar returns none.    |
//| ⚠ Edge status: signal ยังพิสูจน์ตัวเองไม่ได้ (replica 990010 =    |
//| WATCH, OOS 0.86) - port นี้ = owner override 2026-07-06 เพื่อให้   |
//| แม่พิมพ์ครบ · ห้าม deploy Boss_15 จนกว่า replica ผ่าน judge       |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_ST03_MQH
#define BOSS_LAB_ENTRY_ST03_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

int      g_st03_cb          = 0;      // consecutive closed bars in MACD buy-state
int      g_st03_cs          = 0;      // consecutive closed bars in MACD sell-state
bool     g_st03_fired_buy   = false;  // edge latch: BUY already fired this run
bool     g_st03_fired_sell  = false;
int      g_st03_since_buy   = 0;      // bars since last BUY fire (rearm cadence)
int      g_st03_since_sell  = 0;
datetime g_st03_last_bar    = 0;      // once-per-bar gate (recompile-safe: reset in Init)

void Entry_ST03_Init()
{
   g_st03_cb = 0;  g_st03_cs = 0;
   g_st03_fired_buy = false;  g_st03_fired_sell = false;
   g_st03_since_buy = 0;      g_st03_since_sell = 0;
   g_st03_last_bar  = 0;
}

EntrySignal Entry_Evaluate()
{
   // v4 contract: evaluate exactly once per CLOSED bar
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_st03_last_bar) return Entry_MakeNone("st03: intrabar (bar already counted)");
   g_st03_last_bar = curBar;

   double main1 = 0.0, sig1 = 0.0;
   if(!Indi_MACD(1, main1, sig1)) return Entry_MakeNone("MACD not ready");

   const bool buyState  = (main1 > sig1);
   const bool sellState = (main1 < sig1);

   if(buyState)
   {
      g_st03_cb++;
      g_st03_cs = 0;
      g_st03_fired_sell = false;   // left sell-run -> re-arm SELL latch
      g_st03_since_sell = 0;
      if(g_st03_fired_buy && _15_RearmBars > 0)
      {
         g_st03_since_buy++;
         if(g_st03_since_buy >= _15_RearmBars) { g_st03_fired_buy = false; g_st03_since_buy = 0; }
      }
   }
   else if(sellState)
   {
      g_st03_cs++;
      g_st03_cb = 0;
      g_st03_fired_buy = false;
      g_st03_since_buy = 0;
      if(g_st03_fired_sell && _15_RearmBars > 0)
      {
         g_st03_since_sell++;
         if(g_st03_since_sell >= _15_RearmBars) { g_st03_fired_sell = false; g_st03_since_sell = 0; }
      }
   }
   else
   {
      // exact equality = neutral: reset everything (v4 verbatim)
      g_st03_cb = 0;  g_st03_cs = 0;
      g_st03_fired_buy = false;  g_st03_fired_sell = false;
      g_st03_since_buy = 0;      g_st03_since_sell = 0;
   }

   const double strength = MathAbs(main1 - sig1);

   if(g_st03_cb >= _15_CountBars && (!_15_EdgeTrigger || !g_st03_fired_buy)
      && TradeDir != TRADEDIR_SHORT_ONLY)
   {
      g_st03_fired_buy = true;
      g_st03_since_buy = 0;
      EntrySignal s;
      s.direction = 1; s.strength = strength; s.confidence = 1.0; s.valid = true;
      s.reason = "MACD cb=" + IntegerToString(g_st03_cb) + ">=" + IntegerToString(_15_CountBars) + " BUY";
      return s;
   }
   if(g_st03_cs >= _15_CountBars && (!_15_EdgeTrigger || !g_st03_fired_sell)
      && TradeDir != TRADEDIR_LONG_ONLY)
   {
      g_st03_fired_sell = true;
      g_st03_since_sell = 0;
      EntrySignal s;
      s.direction = 2; s.strength = strength; s.confidence = 1.0; s.valid = true;
      s.reason = "MACD cs=" + IntegerToString(g_st03_cs) + ">=" + IntegerToString(_15_CountBars) + " SELL";
      return s;
   }
   return Entry_MakeNone("waiting cb=" + IntegerToString(g_st03_cb) +
                         " cs=" + IntegerToString(g_st03_cs));
}

#endif // BOSS_LAB_ENTRY_ST03_MQH
