//+------------------------------------------------------------------+
//| PersistIntent_Test.mq5 - ORDER-138 #2/#3 transactional-intent asserts.
//| #2: Kangaroo pair-close intent = two tickets + commit marker
//|     (complete-or-none: a torn write must restore as NO intent).
//| #3: full-basket close intents (k16_closeall / exit_closeall) are
//|     persisted, restored on init, and released only via the broker-
//|     flat-proof path (which also cleans the persisted key).
//| Tester GVs are per-pass sandboxed - safe stand-in for live restarts.
//+------------------------------------------------------------------+
#define LAB_ENTRY_16   // _16_* inputs + Kangaroo module are gated on this token
#include "../core/entries/IEntry.mqh"
// Kangaroo_TryFirstEntry links against the entry seam; this test never trades
EntrySignal Entry_Evaluate() { return Entry_MakeNone("test-stub"); }
#include "../core/ExitManager.mqh"
#include "../core/Kangaroo.mqh"

int OnInit()
{
   // same fail-closed rule as PersistMigrate_Test (ORDER-138 #4): this test calls
   // GlobalVariablesDeleteAll("Boss") which also matches live scoped Boss2_* keys
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print("[PersistIntent_Test] FATAL: tester-only (it calls GlobalVariablesDeleteAll - would wipe live Boss safety GVs). Refusing chart/live attach.");
      return INIT_FAILED;
   }
   int fail = 0;

   // --- scenario 1 (#2): torn write - leg without commit marker -> restore = NO
   // intent, leftover leg wiped (complete-or-none)
   GlobalVariablesDeleteAll("Boss");
   Persist_Set("k16_pair_a", 12345.0);   // leg written, crash before marker
   Kangaroo_Init();
   if(g_k16_pair_a != 0 || g_k16_pair_b != 0) { Print("[FAIL] S1: torn pair intent was restored");        fail++; }
   if(Persist_Has("k16_pair_a"))              { Print("[FAIL] S1: torn leg not wiped on restore");        fail++; }

   // --- scenario 2 (#2): committed arm round-trip - PairPersist writes legs +
   // marker durably, a later init restores both legs
   GlobalVariablesDeleteAll("Boss");
   g_k16_pair_a = 111; g_k16_pair_b = 222;
   if(!Kangaroo_PairPersist())                { Print("[FAIL] S2: durable arm reported failure");         fail++; }
   if(!Persist_Has("k16_pair_ok"))            { Print("[FAIL] S2: commit marker missing after arm");      fail++; }
   Kangaroo_Init();
   if(g_k16_pair_a != 111 || g_k16_pair_b != 222) { Print("[FAIL] S2: committed pair not restored");      fail++; }

   // --- scenario 3 (#2): clear round-trip - un-arm removes legs AND marker
   g_k16_pair_a = 0; g_k16_pair_b = 0;
   Kangaroo_PairPersist();
   if(Persist_Has("k16_pair_ok") || Persist_Has("k16_pair_a") || Persist_Has("k16_pair_b"))
                                              { Print("[FAIL] S3: cleared intent left keys behind");      fail++; }

   // --- scenario 4 (#3): persisted k16_closeall restores, then releases only
   // through the broker-flat-proof path (flat account -> proof succeeds, key gone)
   GlobalVariablesDeleteAll("Boss");
   Persist_Set("k16_closeall", 1.0);
   Kangaroo_Init();
   if(!g_k16_closeall_pending)                { Print("[FAIL] S4: k16 close-all intent not restored");    fail++; }
   Kangaroo_ManageExits();                    // have==0 + armed intent -> CloseBasket proof path
   if(g_k16_closeall_pending)                 { Print("[FAIL] S4: intent not released on flat proof");    fail++; }
   if(Persist_Has("k16_closeall"))            { Print("[FAIL] S4: persisted intent leaked after proof");  fail++; }

   // --- scenario 5 (#3): persisted exit_closeall restores via ExitManager_Init,
   // then releases through Exit_SafetyMoneyStop's flat-proof route
   GlobalVariablesDeleteAll("Boss");
   Persist_Set("exit_closeall", 1.0);
   ExitManager_Init();
   if(!g_exit_closeall_pending)               { Print("[FAIL] S5: exit close-all intent not restored");   fail++; }
   Exit_SafetyMoneyStop();                    // CountAll==0 + armed -> CloseBasket proof path
   if(g_exit_closeall_pending)                { Print("[FAIL] S5: intent not released on flat proof");    fail++; }
   if(Persist_Has("exit_closeall"))           { Print("[FAIL] S5: persisted intent leaked after proof");  fail++; }

   // --- scenario 6 (#3): no persisted intent -> init stays clean (no fabrication)
   GlobalVariablesDeleteAll("Boss");
   Kangaroo_Init();
   ExitManager_Init();
   if(g_k16_closeall_pending || g_exit_closeall_pending)
                                              { Print("[FAIL] S6: intent fabricated from clean slate");   fail++; }

   GlobalVariablesDeleteAll("Boss");
   if(fail == 0) Print("[PASS] PersistIntent_Test: all 6 scenarios OK");
   else          PrintFormat("[FAIL] PersistIntent_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
