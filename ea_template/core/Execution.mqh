//+------------------------------------------------------------------+
//| Execution.mqh (V2) - ONLY place that touches CTrade / OrderSend. |
//|  DryRun=true logs intents. Lot clamped to RC_MaxLot here (final).|
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_EXECUTION_MQH
#define BOSS_LAB_EXECUTION_MQH
#include "Inputs.mqh"
#include <Trade/Trade.mqh>

CTrade g_trade;
int    g_exec_open_intents = 0;

void Exec_Init()
{
   g_trade.SetExpertMagicNumber((ulong)_0_Magic);
   g_trade.SetDeviationInPoints((ulong)_0_Slippage);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
}

bool Exec_PosIsMine(const int index)
{
   ulong tk = PositionGetTicket(index);
   if(tk == 0) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if((long)PositionGetInteger(POSITION_MAGIC) != _0_Magic) return false;
   return true;
}

double Exec_NormalizeLot(double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   if(RC_MaxLot > 0.0 && lot > RC_MaxLot) lot = RC_MaxLot;   // final hard ceiling
   if(lot > maxv) lot = maxv;
   if(lot < minv) lot = minv;
   lot = MathFloor(lot / step + 0.0000001) * step;
   return NormalizeDouble(lot, 2);
}

bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)
{
   lot = Exec_NormalizeLot(lot);
   if(lot <= 0.0) return false;
   g_exec_open_intents++;
   if(DryRun)
   {
      PrintFormat("[DRYRUN] open dir=%d lot=%.2f sl=%.5f tp=%.5f %s", direction, lot, sl, tp, comment);
      return true;
   }
   if(direction == 1) return g_trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   if(direction == 2) return g_trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
   return false;
}

int Exec_CountDir(const int direction)   // 0=any 1=buy 2=sell
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

int Exec_CountAll() { return Exec_CountDir(0); }

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

// open time of the most-recent order in a direction (for retrigger confirm)
datetime Exec_LastTimeDir(const int direction)
{
   datetime best = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY) continue;
      if(direction == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) best = t;
   }
   return best;
}

void Exec_CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(!DryRun) g_trade.PositionClose(tk);
   }
}

bool Exec_ModifyPosition(const ulong ticket, const double sl, const double tp)
{
   if(DryRun) return true;
   return g_trade.PositionModify(ticket, sl, tp);
}

#endif // BOSS_LAB_EXECUTION_MQH
