// Compile-only signature consumer. NEVER attach/run this expert.
#property strict
#include "../core/entries/Entry_GridFibo.mqh"
#include "../core/entries/Entry_GridFibo.mqh" // exercise the include guard

int OnInit() { return INIT_FAILED; }
void OnTick() {}
void OnDeinit(const int reason) {}

// Uncalled: the compiler checks each public API with the parent's actual types.
// No terminal event reaches this function, including failed-init deinitialization.
void DF03_CompileCheckOnly(const int id, const long& lparam,
                          const double& dparam, const string& sparam)
{
   DF03_AdapterInit();
   DF03_AdapterTick();
   DF03_AdapterTrade();
   DF03_AdapterTimer();
   DF03_AdapterChartEvent(id, lparam, dparam, sparam);
   DF03_AdapterDeinit(id);
}
