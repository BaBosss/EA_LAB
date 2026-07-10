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

// ---- NewsGuard bridge (ORDER-083, additive) ------------------------------
// The (Boss)_NewsGuard watchdog EA may set GlobalVariable
// NEWSGUARD_BLOCK_<magic> = 1 around high-impact news. While it exists and
// reads >= 0.5, NEW orders (market opens + pending placement) are vetoed
// here - the single OrderSend choke point. Management / modify / close
// paths are untouched. Inert when the GV does not exist (tester GVs are
// per-pass sandboxed, so regression numbers cannot move unless a test
// sets the GV itself). Log throttled to once per minute to avoid spam
// while grid/ladder modules keep retrying during the window.
bool Exec_NewsBlocked()
{
   string gv = "NEWSGUARD_BLOCK_" + IntegerToString(_0_Magic);
   if(!GlobalVariableCheck(gv)) return false;
   if(GlobalVariableGet(gv) < 0.5) return false;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      PrintFormat("[EXEC] NEWSGUARD block active (%s) - new order skipped", gv);
   }
   return true;
}

bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)
{
   if(Exec_NewsBlocked()) return false;   // ORDER-083: news window veto (new orders only)
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

double Exec_TotalLots()
{
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

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

// ---- pending-order infra (MERGE-03, STACK_PYRAMID 93) --------------------
// Old modes never place pendings, so the cancel below is a no-op for them.

bool Exec_OrdIsMine(const int index)
{
   ulong tk = OrderGetTicket(index);
   if(tk == 0) return false;
   if(OrderGetString(ORDER_SYMBOL) != _Symbol) return false;
   if((long)OrderGetInteger(ORDER_MAGIC) != _0_Magic) return false;
   return true;
}

int Exec_CountPending()
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(Exec_OrdIsMine(i)) n++;
   return n;
}

void Exec_CancelAllPending()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ulong tk = OrderGetTicket(i);
      if(DryRun) { PrintFormat("[DRYRUN] cancel pending %I64u", tk); continue; }
      if(g_trade.OrderDelete(tk))
         PrintFormat("[EXEC] pending cancelled %I64u", tk);
   }
}

// place one resting leg. isStop: true=STOP (pyramid, with-trend fill),
// false=LIMIT (scale-in, against-trend fill). tp always 0 in mode 93
// (basket exit is the single exit owner - see Inputs.mqh note).
bool Exec_PlacePending(const int direction, const bool isStop, double lot,
                       double price, const double sl, const string comment)
{
   if(Exec_NewsBlocked()) return false;   // ORDER-083: news window veto (new orders only)
   lot = Exec_NormalizeLot(lot);
   if(lot <= 0.0) return false;
   price = NormalizeDouble(price, _Digits);
   if(DryRun)
   {
      PrintFormat("[DRYRUN] pending dir=%d stop=%d lot=%.2f at %.5f sl=%.5f %s",
                  direction, (isStop ? 1 : 0), lot, price, sl, comment);
      return true;
   }
   bool ok = false;
   if(direction == 1) ok = (isStop ? g_trade.BuyStop(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment)
                                   : g_trade.BuyLimit(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment));
   else               ok = (isStop ? g_trade.SellStop(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment)
                                   : g_trade.SellLimit(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment));
   if(ok) PrintFormat("[EXEC] pending placed dir=%d stop=%d lot=%.2f at %.5f (%s)",
                      direction, (isStop ? 1 : 0), lot, price, comment);
   else   PrintFormat("[EXEC] pending FAILED dir=%d at %.5f retcode=%d",
                      direction, price, (int)g_trade.ResultRetcode());
   return ok;
}

void Exec_CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(!DryRun) g_trade.PositionClose(tk);
   }
   // basket gone = ladder leftovers must go too (no-op when no pendings exist)
   Exec_CancelAllPending();
}

// additive (ORDER-072, Kangaroo/16 overlap pair-close): close ONE own position
// by ticket. No other build calls this - behavior of Boss_11..15 unchanged.
bool Exec_CloseTicket(const ulong ticket)
{
   if(DryRun)
   {
      PrintFormat("[DRYRUN] close ticket %I64u", ticket);
      return true;
   }
   return g_trade.PositionClose(ticket);
}

bool Exec_ModifyPosition(const ulong ticket, const double sl, const double tp)
{
   if(DryRun) return true;
   return g_trade.PositionModify(ticket, sl, tp);
}

// additive: partial-close every own position by `frac` of its current volume
// (skips legs where the resulting close volume would be <=0 or >= full volume,
// i.e. below broker min-lot step after normalize). Used by ExitManager's
// milestone partial-close (_2_PartialPct1/2) - Zeus GridLog port (14).
void Exec_ClosePartialFraction(const double frac)
{
   if(frac <= 0.0) return;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong  tk  = PositionGetInteger(POSITION_TICKET);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = Exec_NormalizeLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;   // skip if it would close the whole leg
      if(DryRun)
      {
         PrintFormat("[DRYRUN] partial-close ticket=%I64u vol=%.2f frac=%.2f -> %.2f", tk, vol, frac, closeVol);
         continue;
      }
      g_trade.PositionClosePartial(tk, closeVol);
   }
}

#endif // BOSS_LAB_EXECUTION_MQH
