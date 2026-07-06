//+------------------------------------------------------------------+
//| Persist_Test.mq5 - assert harness for core\Persist.mqh (MERGE-05B)
//| Run in Strategy Tester (any symbol, short window). PASS/FAIL in
//| journal. Pattern from EA_CORE <Module>_v1_Test.mq5 - no CORE deps.
//| Note: proves helper logic in-pass; cross-restart survival is MT5
//| platform behavior (gvariables.dat) - verify once on demo chart.
//+------------------------------------------------------------------+
#include "../core/Persist.mqh"

int OnInit()
{
   int fail = 0;

   // clean slate
   Persist_Del("t_x");
   if(Persist_Has("t_x"))                       { Print("[FAIL] Del/Has: key still exists");        fail++; }
   if(Persist_Get("t_x", 7.5) != 7.5)           { Print("[FAIL] Get fallback: expected 7.5");       fail++; }

   // set / has / roundtrip
   Persist_Set("t_x", 42.25);
   if(!Persist_Has("t_x"))                      { Print("[FAIL] Set/Has: key missing after Set");   fail++; }
   if(Persist_Get("t_x", 0.0) != 42.25)         { Print("[FAIL] roundtrip: expected 42.25");        fail++; }

   // overwrite
   Persist_Set("t_x", -1.0);
   if(Persist_Get("t_x", 0.0) != -1.0)          { Print("[FAIL] overwrite: expected -1.0");         fail++; }

   // key isolation per magic
   string k = Persist_Key("t_x");
   if(StringFind(k, IntegerToString(_0_Magic)) < 0) { Print("[FAIL] key missing magic: ", k);       fail++; }

   // restore-path simulation (what RiskControl_Init does after a kill)
   Persist_Set("rc_halted", 1.0);
   Persist_Set("rc_peak_eq", 12345.67);
   bool   halted = (Persist_Get("rc_halted", 0.0) > 0.5);
   double peak   = Persist_Get("rc_peak_eq", 0.0);
   if(!halted || peak != 12345.67)              { Print("[FAIL] restore sim: halted/peak wrong");   fail++; }

   // cleanup
   Persist_Del("t_x"); Persist_Del("rc_halted"); Persist_Del("rc_peak_eq");
   if(Persist_Has("rc_halted"))                 { Print("[FAIL] cleanup: rc_halted survived Del");  fail++; }

   if(fail == 0) Print("[PASS] Persist_Test: all 8 asserts OK");
   else          PrintFormat("[FAIL] Persist_Test: %d assert(s) failed", fail);
   return INIT_SUCCEEDED;
}

void OnTick() {}
