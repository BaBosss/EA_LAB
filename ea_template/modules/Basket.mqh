//+------------------------------------------------------------------+
//| Basket.mqh - gated OFF stub (future). Basket money TP/SL itself  |
//| already lives in ExitManager; this hook is for future multi-     |
//| symbol/group basket logic.                                       |
//+------------------------------------------------------------------+
#ifndef EA_LAB_BASKET_MQH
#define EA_LAB_BASKET_MQH
#include "Inputs.mqh"

bool Basket_Enabled() { return InpBasketEnabled; }

void Basket_OnTick()
{
   if(!InpBasketEnabled) return;
   // future
}

#endif // EA_LAB_BASKET_MQH
