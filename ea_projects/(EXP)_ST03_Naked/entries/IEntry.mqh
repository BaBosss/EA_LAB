//+------------------------------------------------------------------+
//| IEntry.mqh (V2) - the entry seam. Each style returns EntrySignal |
//| (pure signal, no order management). Mirrors EA_CORE_V1 shape.    |
//|   direction: 0=NONE 1=BUY 2=SELL                                 |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_IENTRY_MQH
#define BOSS_LAB_IENTRY_MQH

struct EntrySignal
{
   int    direction;
   double strength;
   double confidence;
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

#endif // BOSS_LAB_IENTRY_MQH
