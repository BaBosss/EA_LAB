//+------------------------------------------------------------------+
//| PersistMigrate_Test.mq5 - ORDER-132 migration + rc_state asserts.
//| Seeds LEGACY (pre-132, magic-only "Boss_<magic>_*") GlobalVariables
//| directly, then runs RiskControl_InitEx and asserts: state restored,
//| single scoped rc_state enum written, legacy keys consumed, peak
//| migrated. ORDER-138 #1 + 138b: adopting ANY legacy key the init
//| would read (active kill/halt, rc_peak_eq, gated acct_hwm) needs
//| explicit consent (RC_AdoptLegacyHalt) - S1/S2 pass true (the
//| consented upgrade path), S6-S9 assert the fail-closed + recovery
//| paths. Tester GVs are per-pass sandboxed, so this is a safe
//| stand-in for the live upgrade path; the demo-chart verification
//| checklist lives in ea_template\PERSIST_MIGRATION_ORDER132.md.
//+------------------------------------------------------------------+
#include "../core/RiskControl.mqh"

int OnInit()
{
   // ORDER-138 (Codex roadmap SEV-1 2026-07-19): this test calls GlobalVariablesDeleteAll("Boss"),
   // whose prefix matches BOTH legacy "Boss_*" AND live scoped "Boss2_*" keys. In the Strategy
   // Tester every pass gets a sandboxed GV space, so the deletes only touch this pass. But
   // deploy.ps1 mirrors the whole template (incl tests\) into the terminal Experts tree, so an
   // accidental CHART attach would wipe halt/kill/HWM/pair state for EVERY Boss instance on the
   // live terminal. Refuse to run anywhere but the tester - fail closed.
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print("[PersistMigrate_Test] FATAL: tester-only (it calls GlobalVariablesDeleteAll - would wipe live Boss safety GVs). Refusing chart/live attach.");
      return INIT_FAILED;
   }
   int fail = 0;
   string mg = IntegerToString(_0_Magic);

   // --- scenario 1: legacy HALT + peak, consented upgrade -> halted, rc_state=2,
   // legacy consumed (ORDER-138 #1: active legacy halt needs adopt=true)
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_halted", 1.0);
   GlobalVariableSet("Boss_" + mg + "_rc_peak_eq", 55555.0);
   RiskControl_InitEx(true);
   if(!RiskControl_IsHalted())                            { Print("[FAIL] S1: not halted after legacy migrate");     fail++; }
   if(Persist_Get("rc_state", -1.0) != 2.0)               { Print("[FAIL] S1: rc_state != HALTED");                  fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_halted"))   { Print("[FAIL] S1: legacy rc_halted not consumed");       fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_peak_eq"))  { Print("[FAIL] S1: legacy rc_peak_eq not consumed");      fail++; }
   if(Persist_Get("rc_peak_eq", 0.0) != 55555.0)          { Print("[FAIL] S1: peak not migrated to scoped key");     fail++; }

   // --- scenario 2: legacy KILL_PENDING, consented -> pending resumes, rc_state=1
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_kill_pending", 1.0);
   RiskControl_InitEx(true);
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

   // --- scenario 6 (ORDER-138 #1): ACTIVE legacy kill + NO consent -> init fails
   // closed, kill NOT adopted, nothing migrated or deleted (cross-account guard)
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_kill_pending", 1.0);
   if(RiskControl_InitEx(false))                               { Print("[FAIL] S6: init did not fail closed on active legacy kill"); fail++; }
   if(g_rc_kill_pending)                                       { Print("[FAIL] S6: kill adopted without consent");                   fail++; }
   if(!GlobalVariableCheck("Boss_" + mg + "_rc_kill_pending")) { Print("[FAIL] S6: legacy key deleted on refused init");            fail++; }
   if(Persist_Has("rc_state"))                                 { Print("[FAIL] S6: scoped rc_state fabricated on refused init");    fail++; }

   // --- scenario 7 (ORDER-138 #1): same state, consent given -> migrates normally
   // (recovery path after the operator sets RC_AdoptLegacyHalt=true once)
   if(!RiskControl_InitEx(true))                              { Print("[FAIL] S7: consented init failed");                          fail++; }
   if(!g_rc_kill_pending)                                     { Print("[FAIL] S7: kill-pending not restored after consent");        fail++; }
   if(Persist_Get("rc_state", -1.0) != 1.0)                   { Print("[FAIL] S7: rc_state != KILL_PENDING");                       fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_rc_kill_pending")) { Print("[FAIL] S7: legacy key not consumed after consented migrate"); fail++; }

   // --- scenario 8 (ORDER-138b Codex F1): foreign legacy rc_peak_eq ALONE (no
   // active flags) + no consent -> fail closed. A higher-equity foreign peak
   // would otherwise make KillDD liquidate this account on the first tick.
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_peak_eq", 99999999.0);
   if(RiskControl_InitEx(false))                              { Print("[FAIL] S8: init did not fail closed on legacy peak");        fail++; }
   if(!GlobalVariableCheck("Boss_" + mg + "_rc_peak_eq"))     { Print("[FAIL] S8: legacy peak deleted on refused init");            fail++; }
   if(Persist_Has("rc_peak_eq"))                              { Print("[FAIL] S8: legacy peak migrated without consent");           fail++; }

   // --- scenario 9 (ORDER-138b Codex F7): active legacy HALT branch + mixed keys
   // (halt + peak + acct_hwm), no consent -> fail closed with EVERY legacy key
   // preserved, nothing scoped (the .set enables the acct gate: RC_AcctDDLimitPct=5)
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_rc_halted", 1.0);
   GlobalVariableSet("Boss_" + mg + "_rc_peak_eq", 55555.0);
   GlobalVariableSet("Boss_" + mg + "_acct_hwm", 66666.0);
   if(RiskControl_InitEx(false))                              { Print("[FAIL] S9: init did not fail closed on active legacy halt"); fail++; }
   if(RiskControl_IsHalted())                                 { Print("[FAIL] S9: halt adopted without consent");                   fail++; }
   if(!GlobalVariableCheck("Boss_" + mg + "_rc_halted") ||
      !GlobalVariableCheck("Boss_" + mg + "_rc_peak_eq") ||
      !GlobalVariableCheck("Boss_" + mg + "_acct_hwm"))       { Print("[FAIL] S9: legacy keys not fully preserved");                fail++; }
   if(Persist_Has("rc_state") || Persist_Has("rc_peak_eq") ||
      Persist_Has("acct_hwm"))                                { Print("[FAIL] S9: partial migration on refused init");              fail++; }

   // --- scenario 10 (ORDER-138c Codex re-audit F7): legacy acct_hwm ALONE trips the
   // consent gate (RC_AcctDDLimitPct=5 via .set), and the consented path migrates it
   GlobalVariablesDeleteAll("Boss");
   GlobalVariableSet("Boss_" + mg + "_acct_hwm", 77777.0);
   if(RiskControl_InitEx(false))                              { Print("[FAIL] S10: init did not fail closed on legacy acct_hwm");   fail++; }
   if(!GlobalVariableCheck("Boss_" + mg + "_acct_hwm"))       { Print("[FAIL] S10: legacy acct_hwm deleted on refused init");      fail++; }
   if(!RiskControl_InitEx(true))                              { Print("[FAIL] S10: consented init failed");                        fail++; }
   if(Persist_Get("acct_hwm", 0.0) < 77776.0)                 { Print("[FAIL] S10: acct_hwm not migrated after consent");          fail++; }
   if(GlobalVariableCheck("Boss_" + mg + "_acct_hwm"))        { Print("[FAIL] S10: legacy acct_hwm not consumed after consent");   fail++; }

   GlobalVariablesDeleteAll("Boss");
   if(fail == 0) Print("[PASS] PersistMigrate_Test: all 10 scenarios OK");
   else          PrintFormat("[FAIL] PersistMigrate_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
