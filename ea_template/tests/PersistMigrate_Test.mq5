//+------------------------------------------------------------------+
//| PersistMigrate_Test.mq5 - ORDER-132 migration + rc_state asserts.
//| Seeds LEGACY (pre-132, magic-only "Boss_<magic>_*") GlobalVariables
//| directly, then runs RiskControl_Init and asserts: state restored,
//| single scoped rc_state enum written, legacy keys consumed, peak
//| migrated. Tester GVs are per-pass sandboxed, so this is a safe
//| stand-in for the live upgrade path; the demo-chart verification
//| checklist lives in ea_template\PERSIST_MIGRATION_ORDER132.md.
//+------------------------------------------------------------------+
#include "../core/RiskControl.mqh"

int OnInit()
{
   int fail = 0;
   string mg = IntegerToString(_0_Magic);

   // --- scenario 1: legacy HALT + peak -> halted, rc_state=2, legacy consumed
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_halted", 1.0);
   GlobalVariableSet("Boss_" + mg + "_rc_peak_eq", 55555.0);
   RiskControl_Init();
   if(!RiskControl_IsHalted())                            { Print("[FAIL] S1: not halted after legacy migrate");     fail++; }
   if(Persist_Get("rc_state", -1.0) != 2.0)               { Print("[FAIL] S1: rc_state != HALTED");                  fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_halted"))   { Print("[FAIL] S1: legacy rc_halted not consumed");       fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_peak_eq"))  { Print("[FAIL] S1: legacy rc_peak_eq not consumed");      fail++; }
   if(Persist_Get("rc_peak_eq", 0.0) != 55555.0)          { Print("[FAIL] S1: peak not migrated to scoped key");     fail++; }

   // --- scenario 2: legacy KILL_PENDING -> pending resumes, rc_state=1
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_kill_pending", 1.0);
   RiskControl_Init();
   if(!g_rc_kill_pending)                                     { Print("[FAIL] S2: kill-pending not restored");           fail++; }
   if(Persist_Get("rc_state", -1.0) != 1.0)                   { Print("[FAIL] S2: rc_state != KILL_PENDING");            fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_kill_pending")) { Print("[FAIL] S2: legacy rc_kill_pending not consumed"); fail++; }

   // --- scenario 3: clean slate -> running, and no rc_state key fabricated
   GlobalVariablesDeleteAll("Boss");
   RiskControl_Init();
   if(RiskControl_IsHalted() || g_rc_kill_pending)        { Print("[FAIL] S3: dirty state on clean slate");          fail++; }
   if(Persist_Has("rc_state"))                            { Print("[FAIL] S3: rc_state written without transition"); fail++; }

   // --- scenario 4: scoped rc_state wins over stale legacy leftovers
   GlobalVariablesDeleteAll("Boss");
   Persist_Set("rc_state", 2.0);
   GlobalVariableSet("Boss_" + mg + "_rc_halted", 0.0);   // stale legacy remnant (says running)
   RiskControl_Init();
   if(!RiskControl_IsHalted())                            { Print("[FAIL] S4: scoped rc_state ignored");             fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_halted"))   { Print("[FAIL] S4: stale legacy not cleaned up");         fail++; }

   // --- scenario 5: legacy acct_hwm migrates through the gate init path.
   // RC_AcctDDLimitPct default 0 = gate off (migration skipped, key untouched) -
   // assert directly on the Persist helper the gate uses.
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_acct_hwm", 77777.0);
   Persist_MigrateLegacy("acct_hwm");
   if(Persist_Get("acct_hwm", 0.0) != 77777.0)            { Print("[FAIL] S5: acct_hwm not migrated");               fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_acct_hwm"))    { Print("[FAIL] S5: legacy acct_hwm not consumed");        fail++; }

   GlobalVariablesDeleteAll("Boss");
   if(fail == 0) Print("[PASS] PersistMigrate_Test: all 5 scenarios OK");
   else          PrintFormat("[FAIL] PersistMigrate_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
