//+------------------------------------------------------------------+
//| (TST)_SwapChargeProbe.mq5                                        |
//|                                                                  |
//| Answers one question with a measurement instead of lore: DOES the |
//| strategy tester actually charge swap on this symbol?              |
//| Opens ONE long at the first bar, holds it for the whole run, and  |
//| prints the accumulated POSITION_SWAP plus the price-only P&L so   |
//| the two can be compared. Tester-only, AllowLive has no path here. |
//| Created 2026-07-26 (BTCUSD pyramid candidate, pre-holdout).       |
//+------------------------------------------------------------------+
#property strict
#property description "(TST)_SwapChargeProbe — holds one long for the run and reports the swap the tester charged"

#include <Trade\Trade.mqh>

input double _01_Lot   = 0.01;
input bool   _01_Sell  = false;   // flip to measure the short side
input long   _06_Magic = 999001;

static CTrade g_trade;
static bool   g_opened = false;
static double g_open_price = 0.0;

int OnInit()
{
   if(!(bool)MQLInfoInteger(MQL_TESTER)){ Print("SWAPCHARGE: tester-only probe, refusing"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(g_opened) return;
   const double px = _01_Sell ? SymbolInfoDouble(_Symbol,SYMBOL_BID) : SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   bool ok = _01_Sell ? g_trade.Sell(_01_Lot,_Symbol,px,0,0,"SWAPCHARGE")
                      : g_trade.Buy (_01_Lot,_Symbol,px,0,0,"SWAPCHARGE");
   if(!ok){ PrintFormat("SWAPCHARGE: open failed retcode=%d",g_trade.ResultRetcode()); return; }
   g_opened = true; g_open_price = px;
   PrintFormat("SWAPCHARGE OPEN %s %s %.4f @ %.2f",_Symbol,(_01_Sell?"SELL":"BUY"),_01_Lot,px);
}

void OnDeinit(const int reason)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      const double swap   = PositionGetDouble(POSITION_SWAP);
      const double profit = PositionGetDouble(POSITION_PROFIT);
      const double open   = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur    = PositionGetDouble(POSITION_PRICE_CURRENT);
      const double contract = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
      const double priceOnly = (_01_Sell ? (open-cur) : (cur-open)) * contract * _01_Lot;
      const long   days   = (TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME))/86400;
      PrintFormat("SWAPCHARGE RESULT %s %s | days_held=%d | POSITION_SWAP=%.4f | POSITION_PROFIT=%.4f | price_only=%.4f | swap_per_day=%.4f",
                  _Symbol,(_01_Sell?"SELL":"BUY"),(int)days,swap,profit,priceOnly,(days>0?swap/days:0.0));
   }
}
