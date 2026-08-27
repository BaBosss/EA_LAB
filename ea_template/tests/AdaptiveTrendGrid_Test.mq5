//+------------------------------------------------------------------+
//| AdaptiveTrendGrid_Test.mq5 - bounded Boss19 pure-helper smoke.   |
//| No broker state, order placement, tester result, or runtime edge |
//| is claimed here; the test only pins mapping and lot-law helpers.  |
//+------------------------------------------------------------------+
#property strict

#define LAB_ENTRY_19
#define LAB_ENTRY_TAG "19_AdaptiveTrendGrid_Test"
#define OnInit  LabCore_OnInit
#define OnTick  LabCore_OnTick
#define OnDeinit LabCore_OnDeinit
#include "../core/LabCore.mqh"
#undef OnInit
#undef OnTick
#undef OnDeinit

int OnInit()
{
   int fail = 0;
   if(!B19_OrderMatches(ORDER_TYPE_BUY_LIMIT, 1, false)) fail++;
   if(B19_OrderMatches(ORDER_TYPE_BUY_LIMIT, 1, true)) fail++;
   if(!B19_OrderMatches(ORDER_TYPE_BUY_STOP, 1, true)) fail++;
   if(!B19_OrderMatches(ORDER_TYPE_SELL_LIMIT, 2, false)) fail++;
   if(B19_OrderMatches(ORDER_TYPE_SELL_STOP, 2, false)) fail++;

   if(MathAbs(B19_LotForLevel(1, 1) - 0.01) > 1.0e-9) fail++;
   if(MathAbs(B19_LotForLevel(1, 3) - 0.02) > 1.0e-9) fail++;
   if(MathAbs(B19_LotForLevel(2, 2) - (0.01 / 1.3)) > 1.0e-9) fail++;

   if(fail == 0) Print("[PASS] AdaptiveTrendGrid_Test: mapping and lot-law helpers OK");
   else          PrintFormat("[FAIL] AdaptiveTrendGrid_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}

void OnDeinit(const int reason)
{
   Entry_AdaptiveTrendGrid_Deinit();
   Indi_Deinit();
}
