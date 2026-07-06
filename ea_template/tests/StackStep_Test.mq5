//+------------------------------------------------------------------+
//| StackStep_Test.mq5 - asserts for Stack step/pip math (MERGE-06).  |
//| Guards the digit-aware pip size and the ATR-step + MinPips-floor  |
//| logic that both grid modes and the 93 pyramid ladder depend on.   |
//| ATR needs bars, so asserts run on the first tick, not OnInit.     |
//+------------------------------------------------------------------+
#include "../core/Stack.mqh"

bool g_done = false;

int OnInit()
{
   if(!Indi_Init()) { Print("[FAIL] StackStep_Test: Indi_Init failed"); g_done = true; }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Indi_Deinit(); }

void OnTick()
{
   if(g_done) return;
   g_done = true;
   int fail = 0;

   // digit-aware pip: 10*point on 3/5-digit symbols, else = point
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double expPip = ((digits == 5 || digits == 3) ? 10.0 * point : point);
   if(Stack_PipSize() != expPip)
   { PrintFormat("[FAIL] pip size: got %.5f want %.5f (digits=%d)", Stack_PipSize(), expPip, digits); fail++; }

   // step must be positive and finite once ATR is ready
   double step = Stack_StepPrice();
   if(step <= 0.0)          { Print("[FAIL] Stack_StepPrice() <= 0 with ATR ready"); fail++; }
   if(step > 10000.0*point*1000) { Print("[FAIL] Stack_StepPrice() absurdly large");  fail++; }

   // step floor: MinPips floor must dominate when it exceeds the ATR step
   // (recompute the same components the module uses - catches unit drift)
   double atrStepPts = (_9_StepUseATR ? _9_StepATRmult * Indi_ATR_Points(_9_StepATRShift) : _9_StepPoints);
   if(atrStepPts <= 0.0) atrStepPts = (_9_StepPoints > 0.0 ? _9_StepPoints : 300.0);
   double expStep = atrStepPts * point;
   if(_9_StepMinPips > 0.0)
   {
      double floorPrice = _9_StepMinPips * expPip;
      if(expStep < floorPrice) expStep = floorPrice;
   }
   if(MathAbs(step - expStep) > point * 0.001)
   { PrintFormat("[FAIL] step mismatch: got %.5f want %.5f", step, expStep); fail++; }

   if(fail == 0) Print("[PASS] StackStep_Test: all 4 asserts OK");
   else          PrintFormat("[FAIL] StackStep_Test: %d assert(s) failed", fail);
}
