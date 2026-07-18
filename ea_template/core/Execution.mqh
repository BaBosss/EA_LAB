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
   lot = MathFloor(lot / step + 0.0000001) * step;
   // ORDER-129 (ORDER-125 RiskLot pattern): digits follow the broker's volume step —
   // NormalizeDouble(,2) corrupted 0.001-step symbols. Below-minimum after caps/rounding
   // returns 0 (callers skip): the old floor-to-minimum could send MORE than the RC_MaxLot
   // ceiling claimed to allow.
   int stepDigits = 0;
   double s = step;
   while(stepDigits < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; stepDigits++; }
   lot = NormalizeDouble(lot, stepDigits);
   if(lot < minv)
   {
      static datetime last_log = 0;
      datetime now = TimeCurrent();
      if(now - last_log >= 60)
      {
         last_log = now;
         PrintFormat("[EXEC] lot %.4f below broker min %.4f after caps - order skipped (not floored up)", lot, minv);
      }
      return 0.0;
   }
   return lot;
}

// ORDER-129: _0_MaxSpread was a declared-but-never-read input (operator sets it believing
// entries are blocked, EA opens through news/rollover widening anyway). One predicate,
// checked in BOTH open paths (market + pending). 0 keeps the historical no-op default.
bool Exec_SpreadOK()
{
   if(_0_MaxSpread <= 0) return true;
   long spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);   // points
   if(spr <= (long)_0_MaxSpread) return true;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      PrintFormat("[EXEC] spread %d > max %d - new order blocked", (int)spr, _0_MaxSpread);
   }
   return false;
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

// ---- MacroGate bridge (ORDER-073 Phase-3, additive) ----------------------
// The (Boss)_MacroGate watchdog EA may set, per magic, during a RISK_OFF/STRESS
// macro regime:
//   MACROGATE_BLOCK_<magic>   = 1    -> veto NEW orders (same idea as NewsGuard)
//   MACROGATE_LOTMULT_<magic> = 0.5  -> shrink the NEW-order lot by this factor
// Both apply to the OPEN / PENDING paths ONLY - management, exits and partial-
// close are untouched. Critically the multiplier is applied HERE (open path),
// never inside Exec_NormalizeLot, which also sizes partial CLOSES. Inert when
// the GVs are absent; fail-safe (clearing GVs on stale/missing regime data) is
// the watchdog's job so the chassis stays dumb. Log throttled to 1/min.
#define MACROGATE_GV_MAX_AGE_SEC 3600   // live: if the watchdog stops refreshing a GV, fail open within this

bool Exec_MacroBlocked()
{
   string gv = "MACROGATE_BLOCK_" + IntegerToString(_0_Magic);
   if(!GlobalVariableCheck(gv)) return false;
   // fail open if a dead/removed watchdog stranded this GV (Codex QA 2026-07-18). Skip the
   // age check in the tester, where the self-gate refreshes GVs in sim time each bar and there
   // is no crash-strand risk (single EA) - GlobalVariableTime vs sim TimeCurrent is unreliable.
   if(!MQLInfoInteger(MQL_TESTER) && (TimeCurrent() - GlobalVariableTime(gv)) > MACROGATE_GV_MAX_AGE_SEC) return false;
   if(GlobalVariableGet(gv) < 0.5) return false;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      PrintFormat("[EXEC] MACROGATE block active (%s) - new order skipped", gv);
   }
   return true;
}

// New-order lot multiplier from MacroGate. Default 1.0 (no change). Only values
// in (0,1) take effect, so the gate can only REDUCE size (reduce-lot doctrine -
// never scale up, never zero out).
double Exec_MacroLotMult()
{
   string gv = "MACROGATE_LOTMULT_" + IntegerToString(_0_Magic);
   if(!GlobalVariableCheck(gv)) return 1.0;
   if(!MQLInfoInteger(MQL_TESTER) && (TimeCurrent() - GlobalVariableTime(gv)) > MACROGATE_GV_MAX_AGE_SEC) return 1.0; // stale watchdog -> fail open
   double m = GlobalVariableGet(gv);
   if(!MathIsValidNumber(m) || m <= 0.0 || m >= 1.0) return 1.0;   // NaN / out of (0,1) -> no-op
   return m;
}

bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)
{
   if(Exec_NewsBlocked() || Exec_MacroBlocked()) return false;   // news + macro veto (new orders only)
   if(!Exec_SpreadOK()) return false;                            // ORDER-129: enforce _0_MaxSpread
   lot = Exec_NormalizeLot(lot * Exec_MacroLotMult());           // macro reduce-lot (open path only)
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

// ORDER-132 (Codex system-review SEV-1 #5): projected margin of every OWN resting
// pending if it filled at its order price. A GTC ladder consumes margin at FILL
// time, when the deposit-load cage can no longer refuse it - Stack's budget gate
// (Stack_MarginBudgetOK) reserves this ahead of placement. Unpriceable orders
// contribute 0 here; the per-leg gate is the fail-closed side.
double Exec_PendingMarginProjection()
{
   double sum = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      double lot   = OrderGetDouble(ORDER_VOLUME_CURRENT);
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      long   type  = OrderGetInteger(ORDER_TYPE);
      bool   isBuy = (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT ||
                      type == ORDER_TYPE_BUY_STOP_LIMIT);
      double m = 0.0;
      if(OrderCalcMargin(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, m))
         sum += m;
   }
   return sum;
}

// ORDER-129: reports completion — a failed delete used to vanish silently, leaving a live
// GTC order behind an EA that believed itself flat (Codex system review SEV-1).
bool Exec_CancelAllPending()
{
   bool allOk = true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ulong tk = OrderGetTicket(i);
      if(DryRun) { PrintFormat("[DRYRUN] cancel pending %I64u", tk); continue; }
      if(g_trade.OrderDelete(tk))
         PrintFormat("[EXEC] pending cancelled %I64u", tk);
      else
      {
         allOk = false;
         PrintFormat("[EXEC] pending cancel FAILED %I64u retcode=%d", tk, (int)g_trade.ResultRetcode());
      }
   }
   return allOk;
}

// place one resting leg. isStop: true=STOP (pyramid, with-trend fill),
// false=LIMIT (scale-in, against-trend fill). tp always 0 in mode 93
// (basket exit is the single exit owner - see Inputs.mqh note).
bool Exec_PlacePending(const int direction, const bool isStop, double lot,
                       double price, const double sl, const string comment)
{
   if(Exec_NewsBlocked() || Exec_MacroBlocked()) return false;   // news + macro veto (new orders only)
   if(!Exec_SpreadOK()) return false;                            // ORDER-129: enforce _0_MaxSpread
   lot = Exec_NormalizeLot(lot * Exec_MacroLotMult());           // macro reduce-lot (open path only)
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

// ORDER-129: close-all now PROVES flatness instead of assuming it. Returns true only when,
// after issuing every close/cancel, a broker-state re-scan finds zero own positions AND zero
// own pendings. The hard-kill persists HALT only on a true return (reconciliation loop in
// RiskControl retries every tick otherwise) — previously every PositionClose result was
// discarded and HALT latched with residual exposure still live (Codex system review SEV-1).
bool Exec_CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(DryRun) continue;
      if(!g_trade.PositionClose(tk))
         PrintFormat("[EXEC] close FAILED %I64u retcode=%d", tk, (int)g_trade.ResultRetcode());
   }
   // basket gone = ladder leftovers must go too (no-op when no pendings exist)
   Exec_CancelAllPending();
   if(DryRun) return true;   // intent mode: nothing real to verify
   // broker-state confirmation - never trust the per-call results alone
   return (Exec_CountAll() == 0 && Exec_CountPending() == 0);
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

// ORDER-129b (Codex audit): close-volume normalizer. Same broker min/step/max arithmetic
// as Exec_NormalizeLot but WITHOUT the RC_MaxLot cage clamp - RC_MaxLot is a ceiling on
// new RISK, and capping a partial CLOSE with it would silently shrink risk REDUCTION
// (e.g. 50% of a 1.0-lot legacy position "closed" as 0.10 with the milestone marked done).
double Exec_NormalizeCloseLot(double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   if(lot > maxv) lot = maxv;
   lot = MathFloor(lot / step + 0.0000001) * step;
   int stepDigits = 0;
   double s = step;
   while(stepDigits < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; stepDigits++; }
   lot = NormalizeDouble(lot, stepDigits);
   if(lot < minv) return 0.0;
   return lot;
}

// additive: partial-close every own position by `frac` of its current volume
// (skips legs where the resulting close volume would be <=0 or >= full volume,
// i.e. below broker min-lot step after normalize). Used by ExitManager's
// milestone partial-close (_2_PartialPct1/2) - Zeus GridLog port (14).
// ORDER-132 (Codex F3): returns whether every ATTEMPTED close was accepted by
// the broker - a rejected partial used to vanish silently while the caller
// marked its milestone done. Skipped (unrepresentable-volume) legs do not fail
// the call: they can never become executable at this volume, so retrying them
// is noise, not risk reduction.
bool Exec_ClosePartialFraction(const double frac)
{
   if(frac <= 0.0) return true;   // nothing requested = vacuous success
   bool allOk = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong  tk  = PositionGetInteger(POSITION_TICKET);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = Exec_NormalizeCloseLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;   // skip if it would close the whole leg
      if(DryRun)
      {
         PrintFormat("[DRYRUN] partial-close ticket=%I64u vol=%.2f frac=%.2f -> %.2f", tk, vol, frac, closeVol);
         continue;
      }
      if(!g_trade.PositionClosePartial(tk, closeVol))
      {
         allOk = false;
         PrintFormat("[EXEC] partial-close FAILED %I64u vol=%.2f retcode=%d", tk, closeVol, (int)g_trade.ResultRetcode());
      }
   }
   return allOk;
}

#endif // BOSS_LAB_EXECUTION_MQH
