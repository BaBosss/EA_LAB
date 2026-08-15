//+------------------------------------------------------------------+
//| HedgeSafety_Test.mq5 - deterministic acceptance for T1 and T6.   |
//| The production OnInit calls the same pure result function with the |
//| live AccountInfoInteger(ACCOUNT_MARGIN_MODE); no tester exemption. |
//+------------------------------------------------------------------+
#include "../core/HedgeSafety.mqh"

int OnInit()
{
   int fail = 0;

   if(HedgeSafety_InitResult(ACCOUNT_MARGIN_MODE_RETAIL_NETTING, true, true, 3.0, 8.0) != INIT_FAILED)
   { Print("[FAIL] HedgeSafety_Test: netting + Hedge/Recovery did not map to INIT_FAILED"); fail++; }
   if(HedgeSafety_InitResult(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING, true, true, 3.0, 8.0) != INIT_SUCCEEDED)
   { Print("[FAIL] HedgeSafety_Test: hedging positive control did not map to INIT_SUCCEEDED"); fail++; }
   if(HedgeSafety_InitResult(ACCOUNT_MARGIN_MODE_RETAIL_NETTING, false, false, 3.0, 8.0) != INIT_SUCCEEDED)
   { Print("[FAIL] HedgeSafety_Test: disabled Hedge/Recovery unexpectedly rejected netting"); fail++; }

   if(HedgeSafety_InitResult(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING, true, true, 8.0, 8.0) != INIT_FAILED)
   { Print("[FAIL] HedgeSafety_Test: equal release/trigger did not fail closed"); fail++; }
   if(HedgeSafety_InitResult(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING, true, true, 9.0, 8.0) != INIT_FAILED)
   { Print("[FAIL] HedgeSafety_Test: release above trigger did not fail closed"); fail++; }
   if(HedgeSafety_InitResult(ACCOUNT_MARGIN_MODE_RETAIL_HEDGING, true, true, 3.0, 8.0) != INIT_SUCCEEDED)
   { Print("[FAIL] HedgeSafety_Test: strict-less hysteresis positive control failed"); fail++; }

   if(fail == 0) Print("[PASS] HedgeSafety_Test: T1/T6 deterministic gates pass");
   else          PrintFormat("[FAIL] HedgeSafety_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
