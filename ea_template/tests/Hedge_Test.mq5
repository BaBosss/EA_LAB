//+------------------------------------------------------------------+
//| Hedge_Test.mq5 - asserts for core\Hedge.mqh HEDGE_LOCK(1) path    |
//| (ORDER-158 part 3). MUST run with tests\Hedge_Test.set            |
//| (HedgeMode=1, _H_TriggerDDPct=8.0, _H_ReleaseDDPct=3.0,           |
//| _H_Ratio=1.0, _H_MaxLot=0.0). No live positions are opened in this|
//| harness (repo test convention - see AcctGate/Persist/StackStep) so|
//| this proves the module is enabled + its read-only accessors are   |
//| well-defined on a flat basket, not the full open/release trigger  |
//| trade path (that path is exercised indirectly by the ORDER-158    |
//| part-2 A/B sweep harness, which runs the real EA in the tester).  |
//| Pattern from AcctGate_Test.mq5 - no CORE deps, asserts in OnInit. |
//+------------------------------------------------------------------+
// Hedge.mqh's Hedge_OnTick() references LAB_ENTRY_TAG (normally #defined by the
// Boss_XX.mq5 wrapper before Inputs.mqh). This test includes Hedge.mqh directly
// (no CORE deps, same convention as Persist_Test/AcctGate_Test) so it must supply
// the symbol itself - value is irrelevant, this test never opens orders (Hedge_OnTick()
// IS called on a flat basket in this test, but never reaches the Exec_Open branch).
#define LAB_ENTRY_TAG "TEST"
#include "../core/Hedge.mqh"

int OnInit()
{
   int fail = 0;

   if(HedgeMode != HEDGE_LOCK || _H_TriggerDDPct != 8.0 || _H_ReleaseDDPct != 3.0
      || _H_Ratio != 1.0 || _H_MaxLot != 0.0)
   {
      Print("[FAIL] Hedge_Test: must run with tests\\Hedge_Test.set "
            "(HedgeMode=1, _H_TriggerDDPct=8.0, _H_ReleaseDDPct=3.0, _H_Ratio=1.0, _H_MaxLot=0.0)");
      return INIT_SUCCEEDED;
   }

   if(!Hedge_Enabled())
   { Print("[FAIL] Hedge_Enabled() false with HedgeMode=HEDGE_LOCK"); fail++; }

   // release threshold must be strictly below the trigger threshold, else the
   // module would open and immediately release on the same tick (hysteresis
   // sanity on the fixed .set this test locks in).
   if(!(_H_ReleaseDDPct < _H_TriggerDDPct))
   { PrintFormat("[FAIL] config sanity: _H_ReleaseDDPct(%.2f) must be < _H_TriggerDDPct(%.2f)", _H_ReleaseDDPct, _H_TriggerDDPct); fail++; }

   // flat basket (no positions this window) - accessors must be well-defined zeros,
   // not garbage/NaN, and Hedge_OnTick() must not throw with an empty basket.
   if(Hedge_Count() != 0)
   { PrintFormat("[FAIL] Hedge_Count() = %d, want 0 (no positions)", Hedge_Count()); fail++; }

   if(MathAbs(Hedge_NetDirectionalLots()) > 0.0000001)
   { PrintFormat("[FAIL] Hedge_NetDirectionalLots() = %.6f, want 0.0", Hedge_NetDirectionalLots()); fail++; }

   // Hedge_BasketDDPct(): Exec_BasketProfit()==0 on a flat basket is NOT < 0,
   // so the function must take its early-return zero path, not divide/derive.
   if(MathAbs(Hedge_BasketDDPct()) > 0.0000001)
   { PrintFormat("[FAIL] Hedge_BasketDDPct() = %.6f, want 0.0 (flat basket early-return path)", Hedge_BasketDDPct()); fail++; }

   Hedge_OnTick();   // must not fault on a flat basket + HEDGE_LOCK enabled
   if(Hedge_Count() != 0)
   { PrintFormat("[FAIL] Hedge_OnTick() opened %d leg(s) on a flat basket (DD=0%% < trigger 8%%)", Hedge_Count()); fail++; }

   if(fail == 0) Print("[PASS] Hedge_Test: all 6 asserts OK");
   else          PrintFormat("[FAIL] Hedge_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
