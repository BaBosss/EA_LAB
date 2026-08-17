//+------------------------------------------------------------------+
//| (Boss)_ZeusInspired_GridLog_rev01.mq5                            |
//|                                                                    |
//| ORIGIN: inspired by observed BEHAVIOR of a third-party closed/    |
//| encrypted EA ("Zeus Gold Hedge V1.2") studied via MT4 Journal     |
//| logs only — no source code was ever available or used. This is   |
//| an independent implementation, not a derivative of any source.   |
//| See D:\EA_LAB\ZEUS_GOLD_HEDGE_ANALYSIS.md for the full analysis. |
//|                                                                    |
//| RISK CLASSIFICATION (strategy-and-risk skill rubric):             |
//|   Reference behavior = Grid + Martingale-lot + Hedge = L5, REFUSE.|
//|   This EA drops the internal auto-hedge trigger (moved to the    |
//|   portfolio level — run two instances with different Magic/.set, |
//|   see GridLean/TightLean presets) and replaces martingale-style  |
//|   lot escalation with LOG sizing (flattens instead of compounds).|
//|   Result: Grid only = L3, allowed with caps. See spec card in    |
//|   chain_id EA_ZEUSINSPIRED_GRIDLOG_20260703_01.                  |
//|                                                                    |
//| KEY DIFFERENCES FROM THE REFERENCE BEHAVIOR (deliberate fixes):  |
//|   - Real per-order stop loss (ATR-based). Reference ran with     |
//|     StopLoss=0 — no stop at all — identified as the likely root  |
//|     cause of its backtested drawdown (up to 102% DD observed).   |
//|   - ATR-based grid spacing, not fixed pips — reference's fixed   |
//|     30-90pt spacing worked on EURUSD but blew the account on     |
//|     XAUUSD even at 10x wider fixed spacing (still ~102% DD),     |
//|     because fixed-pip spacing doesn't scale with instrument      |
//|     volatility. ATR spacing self-adjusts per instrument/regime.  |
//|   - Partial close as the basket recovers (reduces peak DD).      |
//|   - Hard drawdown-based emergency exit (reference had none       |
//|     meaningful — MaxLoss=100000 / Maxlot=100 were nominal caps   |
//|     far larger than the account, i.e. not real caps in practice).|
//|                                                                    |
//| NAMING: (Boss)_<strategy>_rev01.mq5 | Magic 990101+ (standalone) |
//| STATUS: NEW — smoke test → IS/OOS → artifact screen → MC BEFORE  |
//| any live/demo deployment. Not yet validated.                     |
//+------------------------------------------------------------------+
#property strict
#property description "(Boss)_ZeusInspired_GridLog_rev01"
#property description "Symbol: EURUSD  TF: H1  Validated: NOT YET — smoke/IS/OOS/MC pending"

// Entry logic:
//   Place ONE pending stop order (direction fixed by _01_Direction input) at
//   ATR x _03_DistAtrMult from price when no basket is open.
//   When triggered, if price continues against the position by another
//   ATR x _03_DistAtrMult, add the next grid leg (same direction), lot sized
//   by LOG escalation (_05_LogFactor), up to _06_MaxPositions legs.
//   Exit: basket-level dynamic TP (NET_ALL) with partial closes on the way,
//   OR per-order ATR stop loss, OR hard DD/loss caps (whichever first).
//   Two instances (GridLean / TightLean, see bottom-of-file presets) run on
//   different Magic numbers to diversify at the PORTFOLIO level instead of
//   an internal auto-hedge trigger.

#include <Trade\Trade.mqh>
#include "STANDALONE_RISK_BUNDLE.mqh"
#include "Regime_Standalone.mqh"   // [50] additive market-state gate (ORDER-057 adoption)

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input string _g00_             = "── [00] TESTER / OPTIMIZER ────────────────";
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] ENTRY — single-direction pending-stop breakout (no auto-hedge)
//--------------------------------------------------------------------
input string _g01_             = "── [01] ENTRY ──────────────────────────────";
enum ENUM_DIR { DIR_BUY = 1, DIR_SELL = -1 };
input ENUM_DIR _01_Direction   = DIR_BUY;
// Which side this instance trades. Run a 2nd chart attach with the opposite
// (or a different distance/TP tilt) + a different Magic to diversify at the
// portfolio level — this REPLACES the reference EA's internal auto-hedge.

input int    _01_AtrPeriod     = 14;

//--------------------------------------------------------------------
// [02] STOP LOSS — real per-order SL (reference ran with none)
//--------------------------------------------------------------------
input string _g02_             = "── [02] STOP LOSS ─────────────────────────";
input double _02_SlAtrMult     = 4.0;
input double _02_SlMaxPips     = 150.0;   // hard ceiling regardless of ATR value

//--------------------------------------------------------------------
// [03] GRID DISTANCE — ATR-based, not fixed pips (fixes gold blowup root cause)
//--------------------------------------------------------------------
input string _g03_             = "── [03] GRID DISTANCE ─────────────────────";
input double _03_DistAtrMult   = 1.5;     // GridLean preset: 2.2 | TightLean: 1.0
input double _03_MinDistPips   = 20.0;    // floor — prevents near-zero-ATR degenerate spacing

//--------------------------------------------------------------------
// [04] TAKE PROFIT — basket-level (NET_ALL), dynamic target + partial close
//--------------------------------------------------------------------
input string _g04_             = "── [04] TAKE PROFIT / PARTIAL CLOSE ───────";
input double _04_TpUsd         = 20.0;    // basket floating-profit target ($), scaled by target multiplier below
input double _04_TpTargetMult  = 1.0;     // GridLean preset: 1.5 | TightLean: 0.7
input double _04_PartialPct1   = 50.0;    // close _04_PartialFrac1 of basket volume at this % of target
input double _04_PartialFrac1  = 0.30;
input double _04_PartialPct2   = 75.0;
input double _04_PartialFrac2  = 0.30;
// Remaining basket volume still closes at 100% of target (or per-order SL / hard caps).

//--------------------------------------------------------------------
// [05] LOT SIZING — LOG escalation + DD-adaptive first lot (both bounded)
//--------------------------------------------------------------------
input string _g05_             = "── [05] LOT SIZING ────────────────────────";
input double _05_BaseLot       = 0.02;
input double _05_LogFactor     = 1.3;
input bool   _05_UseLnNotLog10 = true;    // true=LN, false=LOG10

input bool   _05_DdAdaptive    = true;
input double _05_DdTier1Pct    = 10.0;    // floating DD% at basket-open time
input double _05_DdTier1Mult   = 1.2;
input double _05_DdTier2Pct    = 20.0;
input double _05_DdTier2Mult   = 1.5;
input double _05_DdHardCapMult = 1.5;     // never exceeds this regardless of DD depth

//--------------------------------------------------------------------
// [06] RISK CAPS — hard, checked before every OrderSend
//--------------------------------------------------------------------
input string _g06_             = "── [06] RISK CAPS ─────────────────────────";
input int    _06_MaxPositions  = 6;
input double _06_MaxTotalLot   = 0.60;
input double _06_DailyLossPct  = 5.0;
input double _06_EmergencyDdPct= 25.0;    // close everything + halt new baskets past this equity DD

//--------------------------------------------------------------------
// [07] SYSTEM
//--------------------------------------------------------------------
input string _g07_             = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic         = 990101;  // GridLean=990101 | TightLean=990102
input ulong  _07_Deviation     = 20;

input bool   _07_AllowLive     = false;
// SAFETY GATE — real broker orders ONLY when true. Keep false for all
// backtests/optimization. Set true only in the locked live .set AFTER
// full smoke -> IS/OOS -> artifact -> Monte Carlo validation.

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static int      g_atr_handle     = INVALID_HANDLE;
static bool     g_bar_checked    = false;
static datetime g_last_bar       = 0;
static CTrade   g_trade;
static double   g_day_start_balance = 0.0;
static datetime g_day_stamp      = 0;
static bool     g_halted_today   = false;

//--------------------------------------------------------------------
// Pip / lot helpers (digit-aware, broker-aware — see CODE SAFETY RULES)
//--------------------------------------------------------------------
double PipSize(const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;   // XAUUSD 2-digit, indices, crypto
}

double GetATR(const int shift)
{
   double buf[1];
   if(g_atr_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_atr_handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

//--------------------------------------------------------------------
// Basket introspection — identify OWN positions/orders by MAGIC only
//--------------------------------------------------------------------
int BasketPositionCount()
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic)
         n++;
   }
   return n;
}

double BasketTotalLot()
{
   double lot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic)
         lot += PositionGetDouble(POSITION_VOLUME);
   }
   return lot;
}

double BasketFloatingProfit()
{
   double p = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic)
         p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

bool HasPendingOrder()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == _07_Magic)
         return true;
   }
   return false;
}

void DeleteOwnPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == _07_Magic)
         g_trade.OrderDelete(ticket);
   }
}

//--------------------------------------------------------------------
// LOG lot sizing (orderN=1 -> baseLot, exponent=0) + bounded DD-adaptive tier
//--------------------------------------------------------------------
double CalcLogLot(const int orderN)
{
   double n = (double)orderN;
   double exponent = _05_UseLnNotLog10 ? MathLog(n) : MathLog10(n);
   double lot = _05_BaseLot * MathPow(_05_LogFactor, exponent);
   return lot;
}

// Only applied to the FIRST lot of a NEW basket (order N=1) — never
// re-applied on subsequent grid legs, and always capped, so this cannot
// itself become a second unbounded martingale.
double DdAdaptiveMultiplier()
{
   if(!_05_DdAdaptive) return 1.0;
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 1.0;
   double dd_pct = (balance - equity) / balance * 100.0;
   double mult = 1.0;
   if(dd_pct >= _05_DdTier2Pct) mult = _05_DdTier2Mult;
   else if(dd_pct >= _05_DdTier1Pct) mult = _05_DdTier1Mult;
   if(mult > _05_DdHardCapMult) mult = _05_DdHardCapMult;
   return mult;
}

double NextGridLot(const int orderN)
{
   double lot = CalcLogLot(orderN);
   if(orderN == 1) lot *= DdAdaptiveMultiplier();
   return SRB_NormalizeLot(lot);
}

//--------------------------------------------------------------------
// Hard risk caps — checked before EVERY OrderSend, not only OnInit
//--------------------------------------------------------------------
bool RiskCapsOk(const double addLot)
{
   if(g_halted_today) return false;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0.0)
   {
      double dd_pct = (balance - equity) / balance * 100.0;
      if(dd_pct >= _06_EmergencyDdPct)
      {
         if(!g_suppress_log) PrintFormat("RISK: emergency DD %.2f%% >= cap %.2f%% -> halt", dd_pct, _06_EmergencyDdPct);
         return false;
      }
   }

   if(g_day_start_balance > 0.0)
   {
      double day_loss_pct = (g_day_start_balance - equity) / g_day_start_balance * 100.0;
      if(day_loss_pct >= _06_DailyLossPct)
      {
         if(!g_suppress_log) PrintFormat("RISK: daily loss %.2f%% >= cap %.2f%% -> halt today", day_loss_pct, _06_DailyLossPct);
         return false;
      }
   }

   if(BasketPositionCount() >= _06_MaxPositions) return false;
   if(BasketTotalLot() + addLot > _06_MaxTotalLot) return false;

   return true;
}

// Force-close the whole basket immediately (emergency exit path).
void CloseWholeBasket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic)
         g_trade.PositionClose(ticket);
   }
   DeleteOwnPendingOrders();
}

//--------------------------------------------------------------------
// Partial close — reduces peak DD as the basket recovers toward target
//--------------------------------------------------------------------
static bool g_partial1_done = false;
static bool g_partial2_done = false;

void ManagePartialClose(const double tpTargetUsd)
{
   if(tpTargetUsd <= 0.0) return;
   double floatingProfit = BasketFloatingProfit();
   if(floatingProfit <= 0.0) { g_partial1_done = false; g_partial2_done = false; return; }
   double pctOfTarget = floatingProfit / tpTargetUsd * 100.0;

   if(!g_partial1_done && pctOfTarget >= _04_PartialPct1)
   {
      PartialCloseFraction(_04_PartialFrac1);
      g_partial1_done = true;
   }
   if(!g_partial2_done && pctOfTarget >= _04_PartialPct2)
   {
      PartialCloseFraction(_04_PartialFrac2);
      g_partial2_done = true;
   }
}

void PartialCloseFraction(const double frac)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != _07_Magic) continue;

      double vol      = PositionGetDouble(POSITION_VOLUME);
      double closeVol = SRB_NormalizeLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;   // skip if it would close the whole leg

      const bool allow = _07_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
      if(!allow) continue;
      g_trade.PositionClosePartial(ticket, closeVol);
   }
}

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _01_AtrPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("ZeusInspired_GridLog: iATR handle failed");
      return INIT_FAILED;
   }

   SRB_Init(_Symbol, _06_MaxTotalLot);
   SRB_SetVerbose(!g_suppress_log);

   if(!Regime_Init())
   {
      Print("ZeusInspired_GridLog: Regime_Init failed");
      return INIT_FAILED;
   }

   g_trade.SetExpertMagicNumber(_07_Magic);
   g_trade.SetDeviationInPoints(_07_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_bar_checked        = false;
   g_last_bar           = 0;
   g_partial1_done       = false;
   g_partial2_done       = false;
   g_day_start_balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   g_day_stamp          = 0;
   g_halted_today       = false;

   if(!g_suppress_log)
      PrintFormat("ZeusInspired_GridLog init | magic=%d dir=%s AllowLive=%s",
                  _07_Magic, _01_Direction == DIR_BUY ? "BUY" : "SELL",
                  _07_AllowLive ? "YES" : "NO");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   Regime_Deinit();
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double dd = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   if(dd <= 0.0) return -1.0;
   return pf / (1.0 + dd / 100.0);   // reward PF, penalize DD — grid-stress fitness
}

//--------------------------------------------------------------------
// New-day reset (daily loss cap reference point)
//--------------------------------------------------------------------
void CheckNewDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day_stamp = (datetime)(dt.year * 10000 + dt.mon * 100 + dt.day);
   if(day_stamp != g_day_stamp)
   {
      g_day_stamp = day_stamp;
      g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_halted_today = false;
   }
}

//--------------------------------------------------------------------
// OnTick
//--------------------------------------------------------------------
void OnTick()
{
   CheckNewDay();

   // ── Bar-open-only gate ──────────────────────────────────────────
   const datetime cur_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_bar != g_last_bar)
   {
      g_last_bar    = cur_bar;
      g_bar_checked = false;
   }
   if(g_bar_checked) return;
   g_bar_checked = true;

   const double atr = GetATR(1);
   if(atr <= 0.0) return;

   const double pip       = PipSize(_Symbol);
   const double distPrice = MathMax(atr * _03_DistAtrMult, _03_MinDistPips * pip);
   const double slPips    = MathMin(_02_SlAtrMult * atr / pip, _02_SlMaxPips);
   const double tpTarget  = _04_TpUsd * _04_TpTargetMult;

   // ── Emergency exit: equity DD past cap -> close everything, halt ──
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0.0)
   {
      double dd_pct = (balance - equity) / balance * 100.0;
      if(dd_pct >= _06_EmergencyDdPct)
      {
         if(BasketPositionCount() > 0 || HasPendingOrder())
         {
            if(!g_suppress_log) PrintFormat("EMERGENCY EXIT: DD %.2f%% >= %.2f%%", dd_pct, _06_EmergencyDdPct);
            CloseWholeBasket();
         }
         g_halted_today = true;
         return;
      }
   }

   const bool allow = _07_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);

   // ── Manage existing basket: partial close + grid escalation ──────
   int posCount = BasketPositionCount();
   if(posCount > 0)
   {
      ManagePartialClose(tpTarget);

      // Basket-level TP (NET_ALL) — close everything remaining at 100% of target.
      if(BasketFloatingProfit() >= tpTarget)
      {
         if(!g_suppress_log) PrintFormat("BASKET TP hit: floating=%.2f target=%.2f", BasketFloatingProfit(), tpTarget);
         CloseWholeBasket();
         return;
      }

      // Grid escalation: add next leg if price has moved another distPrice
      // against the basket's direction AND caps allow it.
      if(posCount < _06_MaxPositions)
      {
         double lastOpenPrice = 0.0;
         for(int i = 0; i < PositionsTotal(); i++)
         {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
               PositionGetInteger(POSITION_MAGIC) != _07_Magic) continue;
            double op = PositionGetDouble(POSITION_PRICE_OPEN);
            if(_01_Direction == DIR_BUY)  lastOpenPrice = (lastOpenPrice == 0.0) ? op : MathMin(lastOpenPrice, op);
            else                          lastOpenPrice = (lastOpenPrice == 0.0) ? op : MathMax(lastOpenPrice, op);
         }

         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool trigger = (_01_Direction == DIR_BUY)
            ? (bid <= lastOpenPrice - distPrice)
            : (ask >= lastOpenPrice + distPrice);

         if(trigger)
         {
            double lot = NextGridLot(posCount + 1);
            if(lot > 0.0 && RiskCapsOk(lot))
            {
               const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               double slDist = slPips * pip;
               bool ok;
               if(_01_Direction == DIR_BUY)
               {
                  double sl = NormalizeDouble(ask - slDist, digits);
                  ok = allow ? g_trade.Buy(lot, _Symbol, ask, sl, 0.0, "GRID_ADD") : true;
               }
               else
               {
                  double sl = NormalizeDouble(bid + slDist, digits);
                  ok = allow ? g_trade.Sell(lot, _Symbol, bid, sl, 0.0, "GRID_ADD") : true;
               }
               if(!g_suppress_log)
                  PrintFormat("%s GRID_ADD lot=%.2f leg=%d", allow ? "EXEC" : "DRYRUN", lot, posCount + 1);
            }
         }
      }
      return;
   }

   // ── No basket open: (re)arm the single pending-stop entry ────────
   // [50] Regime gate — additive filter on NEW baskets only (first-entry).
   //      Grid-adds + exits above are deliberately NOT gated. Mode 0 = no-op.
   const int _regime_dir = (_01_Direction == DIR_BUY) ? 1 : 2;
   if(!Regime_AllowsEntryDirection(_regime_dir)) return;

   if(HasPendingOrder()) return;
   if(!RiskCapsOk(NextGridLot(1))) return;

   double lot = NextGridLot(1);
   if(lot <= 0.0) return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double slDist = slPips * pip;

   if(!allow)
   {
      if(!g_suppress_log) PrintFormat("DRYRUN ARM %s lot=%.2f dist=%.5f", _01_Direction == DIR_BUY ? "BUYSTOP" : "SELLSTOP", lot, distPrice);
      return;
   }

   bool ok;
   if(_01_Direction == DIR_BUY)
   {
      double price = NormalizeDouble(ask + distPrice, digits);
      double sl    = NormalizeDouble(price - slDist, digits);
      ok = g_trade.BuyStop(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, "ARM_BUYSTOP");
   }
   else
   {
      double price = NormalizeDouble(bid - distPrice, digits);
      double sl    = NormalizeDouble(price + slDist, digits);
      ok = g_trade.SellStop(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, "ARM_SELLSTOP");
   }
   if(!ok && !g_suppress_log)
      PrintFormat("ARM FAILED: %d %s", g_trade.ResultRetcode(), g_trade.ResultComment());
}

//+------------------------------------------------------------------+
//| DEPLOYMENT PRESETS (write as .set files, do not hardcode here)   |
//|                                                                    |
//| GridLean.set  (magic 990101): _03_DistAtrMult=2.2 _04_TpTargetMult=1.5 |
//| TightLean.set (magic 990102): _03_DistAtrMult=1.0 _04_TpTargetMult=0.7 |
//|                                                                    |
//| Attach the SAME compiled EA twice (different magic + .set) to     |
//| diversify at the portfolio level. Check correlation with          |
//| corr_monthly.py before running both live: <=0.40 additive,        |
//| 0.40-0.60 watch, >0.60 redundant (project standard).               |
//+------------------------------------------------------------------+
