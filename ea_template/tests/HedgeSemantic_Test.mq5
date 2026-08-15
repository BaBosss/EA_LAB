//+------------------------------------------------------------------+
//| HedgeSemantic_Test.mq5 - real hedging-account fixture for the    |
//| directional-count and generic-management exclusions.              |
//+------------------------------------------------------------------+
#define LAB_ENTRY_TAG "SEM"
#include "../core/Hedge.mqh"

int  g_stage = 0;
bool g_done  = false;

int OnInit()
{
   Exec_Init();
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
      != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[FAIL] HedgeSemantic_Test: real hedge fixture requires ACCOUNT_MARGIN_MODE_RETAIL_HEDGING");
      g_done = true;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(!g_done) Exec_CloseAll();
}

void OnTick()
{
   if(g_done) return;

   if(g_stage == 0)
   {
      double lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(lot <= 0.0 || !Exec_Open(2, lot, 0.0, 0.0, "SEM CORE")
         || !Exec_Open(1, lot, 0.0, 0.0, "SEM H"))
      {
         Print("[FAIL] HedgeSemantic_Test: fixture orders could not be opened");
         g_done = true;
         return;
      }
      g_stage = 1;
      return;
   }

   int rawBuy  = Exec_CountDir(1);
   int rawSell = Exec_CountDir(2);
   int directionalBuy  = Exec_CountDirectionalDir(1);
   int directionalSell = Exec_CountDirectionalDir(2);
   if(rawBuy == 0 || rawSell == 0) return; // wait for the broker fixture to appear

   int rawStackDir = (rawBuy > 0 ? 1 : 2);
   int directionalStackDir = (directionalBuy > 0 ? 1 : 2);
   int directionalLegs = 0;
   int hedgeLegs = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(Exec_PosIsDirectional(i)) directionalLegs++;
      if(Exec_PosIsHedge(i)) hedgeLegs++;
   }
   PrintFormat("[REPRO] pre_fix raw counts: buy=%d sell=%d stack_add_dir=%d; post directional counts: buy=%d sell=%d stack_add_dir=%d",
               rawBuy, rawSell, rawStackDir, directionalBuy, directionalSell, directionalStackDir);
   if(rawStackDir != 1)
      Print("[FAIL] HedgeSemantic_Test: fixture did not reproduce the pre-fix opposite-direction add");
   else if(directionalStackDir != 2 || directionalBuy != 0 || directionalSell != 1
           || directionalLegs != 1 || hedgeLegs != 1)
      PrintFormat("[FAIL] HedgeSemantic_Test: hedge exclusion failed post-fix (directional buy=%d sell=%d legs=%d hedge=%d)",
                  directionalBuy, directionalSell, directionalLegs, hedgeLegs);
   else
      Print("[PASS] HedgeSemantic_Test: pre-fix opposite add reproduced; post-fix Stack direction and generic directional fixture pass");

   Exec_CloseAll();
   g_done = true;
}
