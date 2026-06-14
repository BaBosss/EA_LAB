//+------------------------------------------------------------------+
//| Hedge.mqh - gated OFF stub (future).                            |
//+------------------------------------------------------------------+
#ifndef EA_LAB_HEDGE_MQH
#define EA_LAB_HEDGE_MQH
#include "Inputs.mqh"

bool Hedge_Enabled() { return (InpHedgeMode != HEDGE_OFF); }

void Hedge_OnTick()
{
   if(InpHedgeMode == HEDGE_OFF) return;
   // future
}

#endif // EA_LAB_HEDGE_MQH
