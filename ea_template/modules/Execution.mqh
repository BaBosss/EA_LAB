//+------------------------------------------------------------------+
//| Execution.mqh - ONLY place that touches CTrade / OrderSend.      |
//| InpDryRun=true logs intents without sending. Lot clamped to      |
//| InpMaxLot here as a final hard ceiling.                          |
//+------------------------------------------------------------------+
#ifndef EA_LAB_EXECUTION_MQH
#define EA_LAB_EXECUTION_MQH
#include "Inputs.mqh"
#include <Trade/Trade.mqh>

CTrade g_trade;
int    g_exec_open_intents = 0;   // counts opens incl dry-run (diagnostics)

void Exec_Init()
{
   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints((ulong)InpSlippagePoints);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
}

bool Exec_PosIsMine(const int index)
{
   ulong tk = PositionGetTicket(index);
   if(tk == 0) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) return false;
   return true;
}

double Exec_NormalizeLot(double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   if(InpMaxLot > 0.0 && lot > InpMaxLot) lot = InpMaxLot;   // final hard ceiling
   if(lot > maxv) lot = maxv;
   if(lot < minv) lot = minv;
   lot = MathFloor(lot / step + 0.0000001) * step;
   return NormalizeDouble(lot, 2);
}

// direction: 1=buy, 2=sell. price 0 => market.
bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)
{
   lot = Exec_NormalizeLot(lot);
   if(lot <= 0.0) return false;
   g_exec_open_intents++;
   if(InpDryRun)
   {
      PrintFormat("[DRYRUN] open dir=%d lot=%.2f sl=%.5f tp=%.5f %s", direction, lot, sl, tp, comment);
      return true;
   }
   if(direction == 1) return g_trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   if(direction == 2) return g_trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
   return false;
}

int Exec_CountDir(const int direction)   // direction 0=any, 1=buy, 2=sell
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 0) n++;
      else if(direction == 1 && type == POSITION_TYPE_BUY) n++;
      else if(direction == 2 && type == POSITION_TYPE_SELL) n++;
   }
   return n;
}

int    Exec_CountAll() { return Exec_CountDir(0); }

double Exec_BasketProfit()
{
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

// most-recently opened price in a direction (for grid spacing)
double Exec_LastPriceDir(const int direction)
{
   datetime best = 0;
   double   price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY) continue;
      if(direction == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) { best = t; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
}

void Exec_CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(!InpDryRun) g_trade.PositionClose(tk);
   }
}

bool Exec_ModifyPosition(const ulong ticket, const double sl, const double tp)
{
   if(InpDryRun) return true;
   return g_trade.PositionModify(ticket, sl, tp);
}

#endif // EA_LAB_EXECUTION_MQH
