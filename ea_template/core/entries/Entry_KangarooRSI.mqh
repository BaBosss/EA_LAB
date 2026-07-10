//+------------------------------------------------------------------+
//| Entry_KangarooRSI.mqh (V2) - entry 16: RSI fade, fixed direction.|
//| KangarooInspired rebuild (ORDER-072, KANGAROO_LOGIC_NOTES.md).   |
//| The original Gold_Kangaroo entry is encrypted (fxDreema) - this  |
//| is entry v0 chosen by spec decision 3: the nearest validated     |
//| counter-trend signal in the lab's stock = RSI mean-reversion.    |
//|                                                                  |
//| BUY instance arms when RSI(last CLOSED bar) < _16_RsiLow;        |
//| SELL instance arms when RSI > _16_RsiHigh. Direction is fixed    |
//| per instance (_16_Direction, Boss_14 pattern) - bidirectional =  |
//| two chart instances with their own magics, never one dual-engine.|
//|                                                                  |
//| Signal itself is stateless; the "market entry at bar open" gate  |
//| lives in Kangaroo.mqh (it calls Entry_Evaluate() only on the     |
//| first tick of a new bar while flat). Grid adds do NOT consult    |
//| this signal - adverse-distance only, matching the original grid. |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_KANGAROO_RSI_MQH
#define BOSS_LAB_ENTRY_KANGAROO_RSI_MQH
#include "IEntry.mqh"
#include "../Indicators.mqh"

void Entry_KangarooRSI_Init()
{
   // stateless entry - nothing to reset (kept for OnInit symmetry with 14/15)
}

EntrySignal Entry_Evaluate()
{
   int dir = (_16_Direction == 1 ? 1 : 2);   // fixed direction, never both

   double rsi = Indi_RSI16(1);               // last CLOSED bar (no forming-bar repaint)
   if(rsi <= 0.0) return Entry_MakeNone("RSI not ready");

   if(dir == 1 && rsi < _16_RsiLow)
   {
      EntrySignal s;
      s.direction  = 1;
      s.strength   = rsi;
      s.confidence = 1.0;
      s.valid      = true;
      s.reason     = "RSI fade buy";
      return s;
   }
   if(dir == 2 && rsi > _16_RsiHigh)
   {
      EntrySignal s;
      s.direction  = 2;
      s.strength   = rsi;
      s.confidence = 1.0;
      s.valid      = true;
      s.reason     = "RSI fade sell";
      return s;
   }
   return Entry_MakeNone("RSI neutral");
}

#endif // BOSS_LAB_ENTRY_KANGAROO_RSI_MQH
