//+------------------------------------------------------------------+
//| HedgeSemantic_Test.mq5 - real hedging-account fixture for the    |
//| directional-count and generic-management exclusions.              |
//+------------------------------------------------------------------+
#define LAB_ENTRY_TAG "SEM"
#include "../core/Hedge.mqh"

int  g_stage = 0;
bool g_done  = false;
bool g_verdict = false;
int  g_wait_ticks = 0;

void HedgeSemantic_Fail(const string message)
{
   PrintFormat("[FAIL] HedgeSemantic_Test: %s", message);
   g_verdict = true;
   g_done = true;
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      HedgeSemantic_Fail("Strategy Tester execution is required; refusing all trade operations");
      return INIT_FAILED;
   }

   Exec_Init();
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
      != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      HedgeSemantic_Fail("real hedge fixture requires ACCOUNT_MARGIN_MODE_RETAIL_HEDGING");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(!g_verdict)
      Print("[FAIL] HedgeSemantic_Test: terminated without a verdict");
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
         HedgeSemantic_Fail("fixture orders could not be opened");
         return;
      }
      g_stage = 1;
      return;
   }

   int rawBuy  = Exec_CountDir(1);
   int rawSell = Exec_CountDir(2);
   int directionalBuy  = Exec_CountDirectionalDir(1);
   int directionalSell = Exec_CountDirectionalDir(2);
   if(rawBuy == 0 || rawSell == 0)
   {
      if(++g_wait_ticks >= 1000)
         HedgeSemantic_Fail("fixture positions did not become visible before bounded wait");
      return;
   }

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
      HedgeSemantic_Fail("fixture did not reproduce the pre-fix opposite-direction add");
   else if(directionalStackDir != 2 || directionalBuy != 0 || directionalSell != 1
           || directionalLegs != 1 || hedgeLegs != 1)
   {
      PrintFormat("[FAIL] HedgeSemantic_Test: hedge exclusion failed post-fix (directional buy=%d sell=%d legs=%d hedge=%d)",
                  directionalBuy, directionalSell, directionalLegs, hedgeLegs);
      g_verdict = true;
   }
   else
   {
      Print("[PASS] HedgeSemantic_Test: pre-fix opposite add reproduced; post-fix Stack direction and generic directional fixture pass");
      g_verdict = true;
   }

   Exec_CloseAll();
   g_done = true;
}
