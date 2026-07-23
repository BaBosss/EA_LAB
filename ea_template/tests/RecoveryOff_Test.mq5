//+------------------------------------------------------------------+
//| RecoveryOff_Test.mq5 - asserts for core\Recovery.mqh REC_NONE(80) |
//| OFF path (ORDER-158 part 3). No .set -> RecoveryMode defaults to |
//| REC_NONE. Regression guard for the "80: OFF path, identical to   |
//| stub" comment in Recovery_OnTick() - proves the off path really   |
//| ignores rstep/basketDD, not just that it returns something.      |
//| Pattern from Persist_Test.mq5 - no CORE deps, asserts in OnInit.  |
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

   if(RecoveryMode != REC_NONE)
   {
      Print("[FAIL] RecoveryOff_Test: must run WITHOUT a .set (expects default RecoveryMode=REC_NONE)");
      return INIT_SUCCEEDED;
   }

   if(Recovery_Enabled())
   { Print("[FAIL] Recovery_Enabled() true with RecoveryMode=REC_NONE"); fail++; }

   // default branch must return baseLot unchanged - and, critically, must NOT
   // scale with rstep or basketDD (that would mean the "off" path is silently
   // still escalating). Use a big rstep + big basketDD to try to provoke drift.
   double baseLot = 0.10;
   double gotOff  = Recovery_AddLot(baseLot, /*rstep*/50, /*basketDD*/100000.0);
   double wantOff = RiskControl_ClampLot(baseLot);
   if(MathAbs(gotOff - wantOff) > 0.0000001)
   { PrintFormat("[FAIL] REC_NONE AddLot: got %.6f want %.6f (should ignore rstep/basketDD)", gotOff, wantOff); fail++; }

   if(fail == 0) Print("[PASS] RecoveryOff_Test: all 2 asserts OK");
   else          PrintFormat("[FAIL] RecoveryOff_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
