//+------------------------------------------------------------------+
//| HedgeOff_Test.mq5 - asserts for core\Hedge.mqh HEDGE_OFF(0) path  |
//| (ORDER-158 part 3). No .set -> HedgeMode defaults to HEDGE_OFF.  |
//| Regression guard for the "0: OFF path, identical to old stub"    |
//| comment in Hedge_OnTick().                                        |
//| Pattern from Persist_Test.mq5 - no CORE deps, asserts in OnInit.  |
//+------------------------------------------------------------------+
// Hedge.mqh's Hedge_OnTick() references LAB_ENTRY_TAG (normally #defined by the
// Boss_XX.mq5 wrapper before Inputs.mqh). This test includes Hedge.mqh directly
// (no CORE deps, same convention as Persist_Test/AcctGate_Test) so it must supply
// the symbol itself - value is irrelevant, this test never opens orders.
#define LAB_ENTRY_TAG "TEST"
#include "../core/Hedge.mqh"

int OnInit()
{
   int fail = 0;

   if(HedgeMode != HEDGE_OFF)
   {
      Print("[FAIL] HedgeOff_Test: must run WITHOUT a .set (expects default HedgeMode=HEDGE_OFF)");
      return INIT_SUCCEEDED;
   }

   if(Hedge_Enabled())
   { Print("[FAIL] Hedge_Enabled() true with HedgeMode=HEDGE_OFF"); fail++; }

   // structural sanity on a flat (no positions) tester window - these must all
   // be zero/neutral regardless of HedgeMode, but worth pinning down here since
   // this is the only test that runs with the OFF default.
   if(Hedge_Count() != 0)
   { PrintFormat("[FAIL] Hedge_Count() = %d, want 0 (no positions)", Hedge_Count()); fail++; }

   if(MathAbs(Hedge_NetDirectionalLots()) > 0.0000001)
   { PrintFormat("[FAIL] Hedge_NetDirectionalLots() = %.6f, want 0.0", Hedge_NetDirectionalLots()); fail++; }

   if(MathAbs(Hedge_BasketDDPct()) > 0.0000001)
   { PrintFormat("[FAIL] Hedge_BasketDDPct() = %.6f, want 0.0", Hedge_BasketDDPct()); fail++; }

   if(fail == 0) Print("[PASS] HedgeOff_Test: all 4 asserts OK");
   else          PrintFormat("[FAIL] HedgeOff_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
