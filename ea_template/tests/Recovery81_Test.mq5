//+------------------------------------------------------------------+
//| Recovery81_Test.mq5 - asserts for core\Recovery.mqh REC_LIGHT(81) |
//| ORDER-158: 81 is the FLAT-LOT TWIN that scripts\                  |
//| hedge_recovery_sweep.ps1 (part 2) pairs against every escalated   |
//| 82/83 cell - this test proves that twin relationship at the code  |
//| level: REC_LIGHT must return baseLot completely unescalated,      |
//| regardless of rstep or basketDD, while still being "enabled"      |
//| (same add-mechanism as 82/83, just no lot growth).                |
//| MUST run with tests\Recovery81_Test.set (RecoveryMode=81).        |
//| Pattern from AcctGate_Test.mq5 - no CORE deps, asserts in OnInit. |
//+------------------------------------------------------------------+
// Recovery.mqh's Recovery_OpenAdd() references LAB_ENTRY_TAG (normally #defined by
// the Boss_XX.mq5 wrapper before Inputs.mqh). This test includes Recovery.mqh
// directly (no CORE deps, same convention as Persist_Test/AcctGate_Test) so it
// must supply the symbol itself - value is irrelevant, this test never opens orders.
#define LAB_ENTRY_TAG "TEST"
#include "../core/Recovery.mqh"

int OnInit()
{
   int fail = 0;

   if(RecoveryMode != REC_LIGHT)
   {
      Print("[FAIL] Recovery81_Test: must run with tests\\Recovery81_Test.set (RecoveryMode=81)");
      return INIT_SUCCEEDED;
   }

   if(!Recovery_Enabled())
   { Print("[FAIL] Recovery_Enabled() false with RecoveryMode=REC_LIGHT"); fail++; }

   // the whole point of 81: lot == baseLot, unconditionally - no rstep or basketDD
   // dependence at all (that is what makes it a valid flat-lot twin for 82/83).
   double baseLot = 0.10;
   double got1 = Recovery_AddLot(baseLot, 1, 0.0);
   if(MathAbs(got1 - RiskControl_ClampLot(baseLot)) > 0.0000001)
   { PrintFormat("[FAIL] rstep=1,DD=0: got %.6f want %.6f", got1, RiskControl_ClampLot(baseLot)); fail++; }

   double got2 = Recovery_AddLot(baseLot, 20, 5000.0);
   if(MathAbs(got2 - RiskControl_ClampLot(baseLot)) > 0.0000001)
   { PrintFormat("[FAIL] rstep=20,DD=5000 (must NOT escalate): got %.6f want %.6f", got2, RiskControl_ClampLot(baseLot)); fail++; }

   if(MathAbs(got1 - got2) > 0.0000001)
   { PrintFormat("[FAIL] REC_LIGHT must be identical across rstep/basketDD: %.6f vs %.6f", got1, got2); fail++; }

   // different baseLot -> output tracks baseLot 1:1 (no hidden multiplier)
   double got3 = Recovery_AddLot(0.25, 1, 0.0);
   if(MathAbs(got3 - RiskControl_ClampLot(0.25)) > 0.0000001)
   { PrintFormat("[FAIL] baseLot=0.25: got %.6f want %.6f", got3, RiskControl_ClampLot(0.25)); fail++; }

   if(fail == 0) Print("[PASS] Recovery81_Test: all 4 asserts OK");
   else          PrintFormat("[FAIL] Recovery81_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
