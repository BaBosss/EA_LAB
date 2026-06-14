//+------------------------------------------------------------------+
//| IEntry.mqh - the HYBRID SEAM.                                    |
//| Every entry style returns an EntrySignal (pure signal, no order  |
//| management). Fields mirror EA_CORE_V1 StrategySignalResult so an |
//| entry can later be lifted into core as StrategySignal_v2.        |
//|   direction: 0=NONE 1=BUY 2=SELL  (== SIGNAL_DIRECTION_*)        |
//+------------------------------------------------------------------+
#ifndef EA_LAB_IENTRY_MQH
#define EA_LAB_IENTRY_MQH

struct EntrySignal
{
   int    direction;    // 0 none, 1 buy, 2 sell
   double strength;     // raw signal strength (e.g. MA gap)
   double confidence;   // 0..1
   bool   valid;
   string reason;
};

EntrySignal Entry_MakeNone(const string reason)
{
   EntrySignal s;
   s.direction  = 0;
   s.strength   = 0.0;
   s.confidence = 0.0;
   s.valid      = false;
   s.reason     = reason;
   return s;
}

// each entry style implements:  EntrySignal Entry_Evaluate(string sym, ENUM_TIMEFRAMES tf)

#endif // EA_LAB_IENTRY_MQH
