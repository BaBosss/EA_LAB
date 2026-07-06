//+------------------------------------------------------------------+
//| AcctGate_Test.mq5 - boundary asserts for RiskControl acct-DD gate |
//| (MERGE-04/MERGE-06). MUST run with tests\AcctGate_Test.set        |
//| (RC_AcctDDLimitPct=5.0) - inputs cannot change at runtime, so the |
//| test drives the boundary by setting g_rc_acct_hwm directly around |
//| the live tester equity. PASS/FAIL in journal.                     |
//+------------------------------------------------------------------+
#include "../core/RiskControl.mqh"

int OnInit()
{
   int fail = 0;

   if(RC_AcctDDLimitPct != 5.0)
   {
      Print("[FAIL] AcctGate_Test: must run with tests\\AcctGate_Test.set (RC_AcctDDLimitPct=5.0)");
      return INIT_SUCCEEDED;
   }

   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0.0) { Print("[FAIL] AcctGate_Test: no equity"); return INIT_SUCCEEDED; }

   // DD 4.0% < limit 5% -> must allow
   g_rc_acct_trip = false;
   g_rc_acct_hwm  = eq / (1.0 - 0.040);
   if(!RiskControl_AcctGateOK()) { Print("[FAIL] DD 4.0% under limit 5% should be ALLOWED"); fail++; }

   // DD 6.0% > limit -> must block
   g_rc_acct_hwm  = eq / (1.0 - 0.060);
   if(RiskControl_AcctGateOK())  { Print("[FAIL] DD 6.0% over limit 5% should be BLOCKED"); fail++; }

   // DD 5.1% just over -> must block (>= semantics, float-safe margin)
   g_rc_acct_hwm  = eq / (1.0 - 0.051);
   if(RiskControl_AcctGateOK())  { Print("[FAIL] DD 5.1% should be BLOCKED"); fail++; }

   // DD 4.9% just under -> must allow
   g_rc_acct_hwm  = eq / (1.0 - 0.049);
   if(!RiskControl_AcctGateOK()) { Print("[FAIL] DD 4.9% should be ALLOWED"); fail++; }

   // uninitialized HWM (0) -> must allow (fail-open before first anchor)
   g_rc_acct_hwm  = 0.0;
   if(!RiskControl_AcctGateOK()) { Print("[FAIL] hwm=0 must be ALLOWED"); fail++; }

   if(fail == 0) Print("[PASS] AcctGate_Test: all 5 asserts OK");
   else          PrintFormat("[FAIL] AcctGate_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
