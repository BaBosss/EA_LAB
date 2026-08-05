//+------------------------------------------------------------------+
//| Recovery83_Test.mq5 - asserts for core\Recovery.mqh REC_AGGRESSIVE|
//| (83). ORDER-158: this mode was mislabeled "(stub, gated)" in      |
//| Inputs.mqh but the code (Recovery_AddLot case REC_AGGRESSIVE) is  |
//| a real geometric MathPow(m, rstep) escalation - this test proves  |
//| it, AND proves a structural nuance worth guarding: RC_RecMultMax  |
//| clamps the PER-STEP multiplier m, not the final compounded lot -  |
//| so total size still grows geometrically with rstep even though   |
//| every single step's multiplier is capped. The absolute RC_MaxLot |
//| ceiling (via RiskControl_ClampLot) is the only thing that stops   |
//| runaway growth at high rstep. If a future refactor changes this   |
//| (e.g. caps the compounded result instead), this test will fail -  |
//| that is the point: it is a deliberate behavior fence, not just a  |
//| smoke check.                                                       |
//| MUST run with tests\Recovery83_Test.set (RecoveryMode=83,         |
//| _8_RecMult=2.0, RC_RecMultMax=1.5, RC_MaxLot=3.0).                 |
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

   if(RecoveryMode != REC_AGGRESSIVE || _8_RecMult != 2.0 || RC_RecMultMax != 1.5 || RC_MaxLot != 3.0)
   {
      Print("[FAIL] Recovery83_Test: must run with tests\\Recovery83_Test.set "
            "(RecoveryMode=83, _8_RecMult=2.0, RC_RecMultMax=1.5, RC_MaxLot=3.0)");
      return INIT_SUCCEEDED;
   }

   if(!Recovery_Enabled())
   { Print("[FAIL] Recovery_Enabled() false with RecoveryMode=REC_AGGRESSIVE"); fail++; }

   // m = min(_8_RecMult=2.0, RC_RecMultMax=1.5) = 1.5 (per-step multiplier is clamped)
   double m = 1.5;
   double baseLot = 0.10;

   // rstep=1 -> lot = 0.10 * 1.5^1 = 0.15
   double got1  = Recovery_AddLot(baseLot, 1, 0.0);
   double want1 = baseLot * MathPow(m, 1);
   if(MathAbs(got1 - want1) > 0.0000001)
   { PrintFormat("[FAIL] rstep=1: got %.6f want %.6f", got1, want1); fail++; }

   // rstep=3 -> lot = 0.10 * 1.5^3 = 0.3375
   double got2  = Recovery_AddLot(baseLot, 3, 0.0);
   double want2 = baseLot * MathPow(m, 3);
   if(MathAbs(got2 - want2) > 0.0000001)
   { PrintFormat("[FAIL] rstep=3: got %.6f want %.6f", got2, want2); fail++; }

   // rstep=5 -> lot = 0.10 * 1.5^5 = 0.759375, still under RC_MaxLot=3.0
   double got3  = Recovery_AddLot(baseLot, 5, 0.0);
   double want3 = baseLot * MathPow(m, 5);
   if(MathAbs(got3 - want3) > 0.0000001)
   { PrintFormat("[FAIL] rstep=5: got %.6f want %.6f", got3, want3); fail++; }

   // structural nuance: total is NOT flat despite m being capped - growth from
   // rstep=3 to rstep=5 must match the uncapped geometric ratio m^2 = 2.25,
   // proving the cap applies once to m, not to the compounded result.
   double ratio = got3 / got2;
   if(MathAbs(ratio - MathPow(m, 2)) > 0.0001)
   { PrintFormat("[FAIL] geometric growth rstep3->rstep5: ratio %.4f want %.4f (m^2)", ratio, MathPow(m, 2)); fail++; }

   // basketDD is NOT part of the REC_AGGRESSIVE formula (only REC_ADAPTIVE uses it) -
   // same rstep, different basketDD, must give identical lot.
   double got4a = Recovery_AddLot(baseLot, 2, 0.0);
   double got4b = Recovery_AddLot(baseLot, 2, 99999.0);
   if(MathAbs(got4a - got4b) > 0.0000001)
   { PrintFormat("[FAIL] REC_AGGRESSIVE must ignore basketDD: dd0=%.6f dd99999=%.6f", got4a, got4b); fail++; }

   // absolute cage: baseLot=1.0, rstep=5 -> raw = 1.0 * 1.5^5 = 7.59375,
   // RC_MaxLot=3.0 must clamp the final result (RiskControl_ClampLot final ceiling).
   double got5 = Recovery_AddLot(1.0, 5, 0.0);
   if(MathAbs(got5 - 3.0) > 0.0000001)
   { PrintFormat("[FAIL] RC_MaxLot final cap: got %.6f want 3.0 (raw would be %.6f)", got5, 1.0 * MathPow(m, 5)); fail++; }

   if(fail == 0) Print("[PASS] Recovery83_Test: all 6 asserts OK");
   else          PrintFormat("[FAIL] Recovery83_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
