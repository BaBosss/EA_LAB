//+------------------------------------------------------------------+
//| Hedge.mqh (V2) - gated OFF stub (deferred). HEDGE_OFF only.      |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_HEDGE_MQH
#define BOSS_LAB_HEDGE_MQH
#include "Inputs.mqh"

bool Hedge_Enabled() { return (HedgeMode != HEDGE_OFF); }

void Hedge_OnTick()
{
   if(HedgeMode == HEDGE_OFF) return;
   // future
}

#endif // BOSS_LAB_HEDGE_MQH
