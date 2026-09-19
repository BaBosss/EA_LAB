//+------------------------------------------------------------------+
//| B17_StructSL_ATRExit_Test.mq5 - engineering routing fixture.     |
//| No strategy/performance claim and no order is ever opened.       |
//+------------------------------------------------------------------+
#property strict

#define LAB_ENTRY_17
#define LAB_ENTRY_TAG "17_StructSL_ATRExit_Test"
#include "../core/ExitManager.mqh"
#include "../core/entries/Entry_Wave5.mqh"

void B17_Fail(const string message, int &fail)
{
   PrintFormat("[FAIL] B17_StructSL_ATRExit_Test: %s", message);
   fail++;
}

void B17_ExpectRoute(const ENUM_EXIT_MODE mode,
                     const bool expectedOverride,
                     const string label,
                     int &fail)
{
   bool actual = Exit_B17StructTPOverridesMode(mode);
   if(actual != expectedOverride)
      B17_Fail(StringFormat("%s route=%s, want %s",
                           label,
                           actual ? "STRUCTURAL_TP" : "GENERIC_EXIT",
                           expectedOverride ? "STRUCTURAL_TP" : "GENERIC_EXIT"), fail);
}

int OnInit()
{
   int fail = 0;

   // All currently declared ExitMode values are pinned explicitly. Fixed TP and
   // the existing structural-target mode retain the prior structural override;
   // ATR, Trail, and RunTrend remain generic/dynamic owners.
   B17_ExpectRoute(EXIT_FIXED_TP,          true,  "EXIT_FIXED_TP", fail);
   B17_ExpectRoute(EXIT_ATR_TP,            false, "EXIT_ATR_TP", fail);
   B17_ExpectRoute(EXIT_TRAIL,             false, "EXIT_TRAIL", fail);
   B17_ExpectRoute(EXIT_RUN_TREND,         false, "EXIT_RUN_TREND", fail);
   B17_ExpectRoute(EXIT_STRUCTURAL_TARGET, true,  "EXIT_STRUCTURAL_TARGET", fail);

   // Adversarial: a non-zero published Wave5 target cannot make ATR select the
   // structural TP. This exercises both the pure router and Exit_InitialTP.
   double savedTp = g_wave5_tp_price;
   g_wave5_tp_price = 987654.321;
   if(Exit_B17StructTPOverridesMode(EXIT_ATR_TP))
      B17_Fail("non-zero g_wave5_tp_price made ATR structural-owned", fail);
   if(ExitMode == EXIT_ATR_TP)
   {
      double routedTp = Exit_InitialTP(1, 1.0);
      if(routedTp == NormalizeDouble(g_wave5_tp_price, _Digits))
         B17_Fail("Exit_InitialTP leaked the published structural TP into ATR mode", fail);
   }
   g_wave5_tp_price = savedTp;

   // The structural-SL fail-closed seam remains live and independent of TP
   // routing. Use canonical Entry_Wave5 globals; do not duplicate its semantics.
   double savedSl = g_wave5_sl_price;
   g_wave5_sl_price = 1.0;
   if(!_17_UseStructLevels)
      B17_Fail("fixture requires the unchanged structural-level default enabled", fail);
   else if(!Exit_StructSLMissing(0.0))
      B17_Fail("structural-SL missing guard is no longer enabled/available", fail);
   g_wave5_sl_price = savedSl;

   if(fail == 0)
   {
      Print("[PASS] B17_StructSL_ATRExit_Test: all five ExitMode routes, ATR adversarial case, and structural-SL seam passed");
      return INIT_SUCCEEDED;
   }

   PrintFormat("[FAIL] B17_StructSL_ATRExit_Test: %d assertion(s) failed", fail);
   return INIT_FAILED;
}

void OnTick()
{
   // Engineering fixture only. Intentionally no signal evaluation or trading.
}
