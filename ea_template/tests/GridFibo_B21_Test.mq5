#property strict
#define LAB_ENTRY_21
#define LAB_ENTRY_TAG "21_GridFibo"
#include "../core/Inputs.mqh"
#include "../core/Execution.mqh"
#include "../core/RiskControl.mqh"
#include "../core/Basket.mqh"

// Compile-only harness seam: production Boss_21 includes RuntimeIdentity.mqh through LabCore.
// This stub preserves that void API without importing the full LabCore fingerprint/include graph.
void RuntimeIdentity_Update() {}

#include "../core/entries/Entry_GridFibo.mqh"

// Compile-only API/ownership harness. Never load into a terminal/tester.
bool B21_TestOwnership()
{
   long base = (long)_21_DF03_MagicStart;
   if(Exec_IdentityIsMine(_Symbol, base)) return false;
   if(Exec_IdentityIsMine(_Symbol, base + 6)) return false;
   for(int group = 1; group <= 5; group++)
      if(!Exec_IdentityIsMine(_Symbol, base + group)) return false;
   return !Exec_IdentityIsMine(_Symbol + "_foreign", base + 1);
}
void B21_TestSignatures()
{
   double lot = 0.01;
   bool config = DF03_B21ConfigValid();
   bool permit = DF03_B21NewOrder(_Symbol, (long)_21_DF03_MagicStart + 1, 0, lot);
   DF03_AdapterInit(); DF03_AdapterTick(); DF03_AdapterTrade(); DF03_AdapterTimer();
   long lparam = 0;
   double dparam = 0.0;
   string sparam = "";
   DF03_AdapterChartEvent(0, lparam, dparam, sparam); DF03_AdapterDeinit(0);
}
int OnInit() { return INIT_FAILED; }
void OnTick() {}
void OnDeinit(const int reason) {}
