//+------------------------------------------------------------------+
//| Recovery82_Test.mq5 - asserts for core\Recovery.mqh REC_ADAPTIVE  |
//| (82). ORDER-158: this mode was mislabeled "(stub)" in Inputs.mqh  |
//| but the code (Recovery_AddLot case REC_ADAPTIVE) does real DD-    |
//| scaled lot math clamped by RC_RecMultMax - this test proves it.   |
//| MUST run with tests\Recovery82_Test.set (RecoveryMode=82,         |
//| RC_RecMultMax=1.8, _8_DDRefMoney=100, _8_DDRefBalPct=0, RC_MaxLot |
//| =0.50) - inputs cannot change at runtime, so each case below is   |
//| chosen to stay inside/outside that single fixed cage.             |
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

   if(RecoveryMode != REC_ADAPTIVE || RC_RecMultMax != 1.8 || _8_DDRefMoney != 100.0
      || _8_DDRefBalPct != 0.0 || RC_MaxLot != 0.50)
   {
      Print("[FAIL] Recovery82_Test: must run with tests\\Recovery82_Test.set "
            "(RecoveryMode=82, RC_RecMultMax=1.8, _8_DDRefMoney=100, _8_DDRefBalPct=0, RC_MaxLot=0.50)");
      return INIT_SUCCEEDED;
   }

   if(!Recovery_Enabled())
   { Print("[FAIL] Recovery_Enabled() false with RecoveryMode=REC_ADAPTIVE"); fail++; }

   // basketDD <= 0 -> mult stays 1.0 -> lot == baseLot unchanged
   double got1 = Recovery_AddLot(0.10, 1, 0.0);
   if(MathAbs(got1 - 0.10) > 0.0000001)
   { PrintFormat("[FAIL] DD<=0: got %.6f want 0.10", got1); fail++; }

   // basketDD=50 -> mult = 1 + 50/100 = 1.5 (under cap 1.8) -> lot = 0.10*1.5 = 0.15
   double got2 = Recovery_AddLot(0.10, 1, 50.0);
   if(MathAbs(got2 - 0.15) > 0.0000001)
   { PrintFormat("[FAIL] DD=50 (mult=1.5, under cap): got %.6f want 0.15", got2); fail++; }

   // basketDD=200 -> raw mult = 1 + 200/100 = 3.0, clamped to RC_RecMultMax=1.8
   // -> lot = 0.10*1.8 = 0.18 (still under RC_MaxLot=0.50, so the mult-cap is what bites)
   double got3 = Recovery_AddLot(0.10, 1, 200.0);
   if(MathAbs(got3 - 0.18) > 0.0000001)
   { PrintFormat("[FAIL] DD=200 (mult clamp to RC_RecMultMax=1.8): got %.6f want 0.18", got3); fail++; }

   // baseLot=0.40, basketDD=200 -> raw = 0.40*1.8 = 0.72, now RC_MaxLot=0.50 bites
   // (the absolute cage cap on top of the escalation-mult cap)
   double got4 = Recovery_AddLot(0.40, 1, 200.0);
   if(MathAbs(got4 - 0.50) > 0.0000001)
   { PrintFormat("[FAIL] RC_MaxLot final cap: got %.6f want 0.50 (raw would be 0.72)", got4); fail++; }

   // rstep is NOT part of the REC_ADAPTIVE formula (only REC_AGGRESSIVE uses it) -
   // same basketDD, different rstep, must give identical lot.
   double got5a = Recovery_AddLot(0.10, 1, 50.0);
   double got5b = Recovery_AddLot(0.10, 9, 50.0);
   if(MathAbs(got5a - got5b) > 0.0000001)
   { PrintFormat("[FAIL] REC_ADAPTIVE must ignore rstep: rstep1=%.6f rstep9=%.6f", got5a, got5b); fail++; }

   if(fail == 0) Print("[PASS] Recovery82_Test: all 5 asserts OK");
   else          PrintFormat("[FAIL] Recovery82_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
