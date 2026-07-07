//+------------------------------------------------------------------+
//| (Boss)_RSI_MR_GridLog_rev01.mq5                                  |
//|                                                                    |
//| ORIGIN: original design inspired by the reverse-engineered        |
//| BEHAVIOR of "RSI from pips_EA" (ORDER-036 survivor, fxDreema-built|
//| compiled black box — no source ever seen). Behavioral analysis:  |
//| D:\EA_LAB\RSI_FROM_PIPS_REVERSE_ENGINEERING.md. This is an        |
//| independent implementation, NOT a derivative of any source.       |
//| Spec card chain_id: EA_RSI_MR_GRIDLOG_20260707_01.               |
//|                                                                    |
//| PRINCIPLE (from RE): RSI(14) mean-reversion, DUAL-SIDE — buy when |
//| oversold, sell when overbought, re-arm each side only after RSI   |
//| returns through 50 (stops machine-gunning at a stuck extreme).    |
//| A gentle averaging grid adds legs as price runs adverse; the      |
//| original used LINEAR +0.01 lot (NOT martingale) — that mildness   |
//| is why it survived when ~1300 martingale grids died. Basket exits |
//| together on net profit.                                           |
//|                                                                    |
//| DELIBERATE UPGRADES OVER THE ORIGINAL:                            |
//|   - REAL per-order stop loss. Original ran SL=0 on every order    |
//|     (its only structural weakness — disconnect = naked). Closed.  |
//|   - ATR-based grid spacing (original = fixed 30 pips). Fixed pips |
//|     are why the original was EURUSD-specific (ORDER-047: DD 50%+  |
//|     on every other symbol). ATR spacing self-scales to let it     |
//|     travel across instruments.                                    |
//|   - LOG lot escalation (even gentler than the original's linear). |
//|   - EMA20 directional filter with ASYMMETRIC base lot (user idea):|
//|     with-trend base larger, counter-trend smaller.                |
//|   - Hard caps + emergency DD close-all (original had none).        |
//|   - V2 signal toggles wired but OFF for the first clean validate: |
//|     MACD-histogram confirm, and average-RSI (mean of 9/14/21).    |
//|                                                                    |
//| RISK: Grid averaging (one mechanism) + LOG lot (conservative, not |
//| martingale) + real SL, NO hedge => L3, allowed with caps.         |
//|                                                                    |
//| NAMING: (Boss)_<strategy>_rev01.mq5 | Magic 990103 (standalone)  |
//| STATUS: NEW — smoke -> BWD/IS/OOS -> spread -> Model-0 -> MC      |
//| BEFORE any demo/live. Do NOT trust the survivor's numbers; this   |
//| is a fresh build and validates from scratch.                      |
//+------------------------------------------------------------------+
#property strict
#property description "(Boss)_RSI_MR_GridLog_rev01 — RSI mean-reversion dual-side averaging grid, LOG lot, real SL"
#property description "Symbol: EURUSD  TF: H1  Validated: NOT YET — smoke/BWD/OOS/Model-0/MC pending"

#include <Trade\Trade.mqh>
#include "STANDALONE_RISK_BUNDLE.mqh"

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input string _g00_             = "── [00] TESTER / OPTIMIZER ────────────────";
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] SIGNAL — RSI(14) mean-reversion, dual-side, re-arm through 50
//--------------------------------------------------------------------
input string _g01_             = "── [01] SIGNAL ─────────────────────────────";
input int    _01_RsiPeriod     = 14;
input double _01_RsiOversold   = 30.0;   // buy when RSI < this
input double _01_RsiOverbought = 70.0;   // sell when RSI > this
input double _01_RsiReArm      = 50.0;   // side re-arms after RSI returns through this level
input int    _01_AtrPeriod     = 14;

//--------------------------------------------------------------------
// [01b] EMA DIRECTIONAL FILTER — asymmetric base lot (user idea)
//--------------------------------------------------------------------
input string _g01b_            = "── [01b] EMA FILTER (asymmetric lot) ──────";
input bool   _01_UseEmaFilter  = true;
input int    _01_EmaPeriod     = 20;
input double _01_WithTrendMult = 2.0;    // Close>EMA20: buy base x2  (=> 0.02 vs 0.01)
input double _01_CounterMult   = 1.0;    // Close>EMA20: sell base x1

//--------------------------------------------------------------------
// [01c] V2 SIGNAL TOGGLES — wired, OFF for first validation
//--------------------------------------------------------------------
input string _g01c_           = "── [01c] V2 SIGNAL OPTIONS (off) ──────────";
input bool   _01_UseMacdConfirm = false; // require MACD histogram sign to agree with entry side
input int    _01_MacdFast       = 12;
input int    _01_MacdSlow       = 26;
input int    _01_MacdSignal     = 9;
input bool   _01_UseAvgRsi       = false;// replace single RSI with mean of RSI(9),RSI(14),RSI(21)

//--------------------------------------------------------------------
// [02] STOP LOSS — real per-order SL (THE upgrade over the original)
//--------------------------------------------------------------------
input string _g02_             = "── [02] STOP LOSS ─────────────────────────";
input double _02_SlAtrMult     = 6.0;    // MR needs room; grid is averaging not scalping
input double _02_SlMaxPips     = 200.0;  // hard ceiling regardless of ATR

//--------------------------------------------------------------------
// [03] GRID DISTANCE — ATR-based (fixes the EURUSD-only limitation)
//--------------------------------------------------------------------
input string _g03_             = "── [03] GRID DISTANCE ─────────────────────";
input double _03_DistAtrMult   = 1.0;    // add next leg when price runs ATR x this adverse
input double _03_MinDistPips   = 20.0;   // floor so dead-vol spacing never degenerates

//--------------------------------------------------------------------
// [04] TAKE PROFIT — per-side basket (NET_ALL) + partial close
//--------------------------------------------------------------------
input string _g04_             = "── [04] TAKE PROFIT / PARTIAL CLOSE ───────";
input double _04_TpUsd         = 15.0;   // per-side basket floating-profit target ($)
input double _04_TpTargetMult  = 1.0;
input double _04_PartialPct1   = 50.0;
input double _04_PartialFrac1  = 0.30;
input double _04_PartialPct2   = 75.0;
input double _04_PartialFrac2  = 0.30;

//--------------------------------------------------------------------
// [05] LOT SIZING — LOG escalation
//--------------------------------------------------------------------
input string _g05_             = "── [05] LOT SIZING ────────────────────────";
input double _05_BaseLot       = 0.01;
input double _05_LogFactor     = 1.3;
input bool   _05_UseLnNotLog10 = true;

//--------------------------------------------------------------------
// [06] RISK CAPS — hard, checked before EVERY OrderSend
//--------------------------------------------------------------------
input string _g06_             = "── [06] RISK CAPS ─────────────────────────";
input int    _06_MaxPositions  = 8;      // TOTAL both sides (original max ever = 6-8)
input double _06_MaxTotalLot   = 1.00;
input double _06_DailyLossPct  = 5.0;
input double _06_EmergencyDdPct= 40.0;   // close everything + halt past this equity DD

//--------------------------------------------------------------------
// [07] SYSTEM
//--------------------------------------------------------------------
input string _g07_             = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic         = 990103;
input ulong  _07_Deviation     = 20;
input bool   _07_AllowLive     = false;  // real orders ONLY when true; false for all tests

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static int      g_atr_handle     = INVALID_HANDLE;
static int      g_ema_handle     = INVALID_HANDLE;
static int      g_macd_handle    = INVALID_HANDLE;
static int      g_rsi_handle     = INVALID_HANDLE;   // RSI(_01_RsiPeriod)
static int      g_rsi9_handle    = INVALID_HANDLE;   // avg-RSI components
static int      g_rsi21_handle   = INVALID_HANDLE;
static datetime g_last_bar       = 0;
static bool     g_bar_checked    = false;
static CTrade   g_trade;
static double   g_day_start_balance = 0.0;
static datetime g_day_stamp      = 0;
static bool     g_halted_today   = false;

// Per-side re-arm state (buy side, sell side)
static bool     g_buy_armed      = true;
static bool     g_sell_armed     = true;
// Partial-close latches per side
static bool     g_buy_partial1   = false, g_buy_partial2  = false;
static bool     g_sell_partial1  = false, g_sell_partial2 = false;

//--------------------------------------------------------------------
// Pip / indicator helpers (digit-aware, broker-aware)
//--------------------------------------------------------------------
double PipSize(const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}

double BufAt(const int handle, const int shift)
{
   double b[1];
   if(handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle, 0, shift, 1, b) < 1) return 0.0;
   return b[0];
}

// RSI value at shift — single or average of 9/14/21 depending on toggle.
double RsiValue(const int shift)
{
   if(!_01_UseAvgRsi) return BufAt(g_rsi_handle, shift);
   double r14 = BufAt(g_rsi_handle,  shift);
   double r9  = BufAt(g_rsi9_handle, shift);
   double r21 = BufAt(g_rsi21_handle, shift);
   if(r14 <= 0.0 || r9 <= 0.0 || r21 <= 0.0) return r14;   // fall back if a buffer not ready
   return (r9 + r14 + r21) / 3.0;
}

double GetATR(const int shift) { return BufAt(g_atr_handle, shift); }

// MACD histogram (main - signal) at shift; returns 0 if handle off/not ready.
double MacdHist(const int shift)
{
   if(g_macd_handle == INVALID_HANDLE) return 0.0;
   double main[1], sig[1];
   if(CopyBuffer(g_macd_handle, 0, shift, 1, main) < 1) return 0.0;
   if(CopyBuffer(g_macd_handle, 1, shift, 1, sig)  < 1) return 0.0;
   return main[0] - sig[0];
}

//--------------------------------------------------------------------
// Per-side basket introspection — OWN positions by MAGIC + POSITION_TYPE
//--------------------------------------------------------------------
int SideCount(const ENUM_POSITION_TYPE side)
{
   int n = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == side)
         n++;
   }
   return n;
}

int TotalCount() { return SideCount(POSITION_TYPE_BUY) + SideCount(POSITION_TYPE_SELL); }

double TotalLot()
{
   double lot = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic)
         lot += PositionGetDouble(POSITION_VOLUME);
   }
   return lot;
}

double SideFloatingProfit(const ENUM_POSITION_TYPE side)
{
   double p = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == side)
         p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

// Worst (deepest-adverse) open price on a side — reference for next grid leg.
double SideAnchorPrice(const ENUM_POSITION_TYPE side)
{
   double anchor = 0.0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != _07_Magic ||
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      double op = PositionGetDouble(POSITION_PRICE_OPEN);
      if(side == POSITION_TYPE_BUY)  anchor = (anchor == 0.0) ? op : MathMin(anchor, op);
      else                           anchor = (anchor == 0.0) ? op : MathMax(anchor, op);
   }
   return anchor;
}

//--------------------------------------------------------------------
// LOG lot (orderN=1 -> baseLot) + EMA-asymmetric base multiplier
//--------------------------------------------------------------------
double CalcLogLot(const int orderN, const double baseLot)
{
   double n = (double)orderN;
   double exponent = _05_UseLnNotLog10 ? MathLog(n) : MathLog10(n);
   return baseLot * MathPow(_05_LogFactor, exponent);
}

// Asymmetric base lot for a side given the EMA trend context (evaluated at signal time).
double SideBaseLot(const ENUM_POSITION_TYPE side)
{
   double baseLot = _05_BaseLot;
   if(_01_UseEmaFilter && g_ema_handle != INVALID_HANDLE)
   {
      double ema = BufAt(g_ema_handle, 1);
      double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(ema > 0.0 && close1 > 0.0)
      {
         bool up = (close1 > ema);
         // with-trend side gets WithTrendMult, counter-trend gets CounterMult
         if(side == POSITION_TYPE_BUY)  baseLot *= (up ? _01_WithTrendMult : _01_CounterMult);
         else                           baseLot *= (up ? _01_CounterMult   : _01_WithTrendMult);
      }
   }
   return baseLot;
}

double NextSideLot(const ENUM_POSITION_TYPE side, const int orderN)
{
   return SRB_NormalizeLot(CalcLogLot(orderN, SideBaseLot(side)));
}

//--------------------------------------------------------------------
// Hard risk caps — checked before EVERY OrderSend
//--------------------------------------------------------------------
bool RiskCapsOk(const double addLot)
{
   if(g_halted_today) return false;

   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0.0)
   {
      double dd_pct = (balance - equity) / balance * 100.0;
      if(dd_pct >= _06_EmergencyDdPct) return false;
   }
   if(g_day_start_balance > 0.0)
   {
      double day_loss_pct = (g_day_start_balance - equity) / g_day_start_balance * 100.0;
      if(day_loss_pct >= _06_DailyLossPct)
      {
         g_halted_today = true;
         return false;
      }
   }
   if(TotalCount() >= _06_MaxPositions) return false;
   if(TotalLot() + addLot > _06_MaxTotalLot) return false;
   return true;
}

//--------------------------------------------------------------------
// Close / partial-close one side's basket (by MAGIC + POSITION_TYPE)
//--------------------------------------------------------------------
void CloseSide(const ENUM_POSITION_TYPE side)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _07_Magic &&
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == side)
         g_trade.PositionClose(t);
   }
}

void CloseAll()
{
   CloseSide(POSITION_TYPE_BUY);
   CloseSide(POSITION_TYPE_SELL);
}

void PartialCloseSide(const ENUM_POSITION_TYPE side, const double frac)
{
   const bool allow = _07_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         PositionGetInteger(POSITION_MAGIC) != _07_Magic ||
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      double vol      = PositionGetDouble(POSITION_VOLUME);
      double closeVol = SRB_NormalizeLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;
      g_trade.PositionClosePartial(t, closeVol);
   }
}

void ManageSidePartial(const ENUM_POSITION_TYPE side, const double tpTarget)
{
   bool isBuy = (side == POSITION_TYPE_BUY);
   bool p1 = isBuy ? g_buy_partial1 : g_sell_partial1;
   bool p2 = isBuy ? g_buy_partial2 : g_sell_partial2;

   double fp = SideFloatingProfit(side);
   if(tpTarget <= 0.0 || fp <= 0.0)
   {
      if(isBuy) { g_buy_partial1 = false; g_buy_partial2 = false; }
      else      { g_sell_partial1 = false; g_sell_partial2 = false; }
      return;
   }
   double pct = fp / tpTarget * 100.0;
   if(!p1 && pct >= _04_PartialPct1) { PartialCloseSide(side, _04_PartialFrac1); p1 = true; }
   if(!p2 && pct >= _04_PartialPct2) { PartialCloseSide(side, _04_PartialFrac2); p2 = true; }

   if(isBuy) { g_buy_partial1 = p1; g_buy_partial2 = p2; }
   else      { g_sell_partial1 = p1; g_sell_partial2 = p2; }
}

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   // HEDGING account is MANDATORY: this EA holds a BUY basket and a SELL basket
   // at the same time (dual-side mean-reversion). On a NETTING account an
   // opposing order nets/closes the existing position instead of opening a new
   // one — SideCount() would be wrong and the whole basket logic breaks silently.
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
        != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("RSI_MR_GridLog: INIT_FAILED — requires a HEDGING account (dual-side baskets). ",
            "Current account is NETTING/exchange. Attach on a hedging account.");
      return INIT_FAILED;
   }

   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _01_AtrPeriod);
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, _01_RsiPeriod, PRICE_CLOSE);
   if(g_atr_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE)
   { Print("RSI_MR_GridLog: ATR/RSI handle failed"); return INIT_FAILED; }

   if(_01_UseEmaFilter)
   {
      g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, _01_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_ema_handle == INVALID_HANDLE) { Print("RSI_MR_GridLog: EMA handle failed"); return INIT_FAILED; }
   }
   if(_01_UseAvgRsi)
   {
      g_rsi9_handle  = iRSI(_Symbol, PERIOD_CURRENT, 9,  PRICE_CLOSE);
      g_rsi21_handle = iRSI(_Symbol, PERIOD_CURRENT, 21, PRICE_CLOSE);
      if(g_rsi9_handle == INVALID_HANDLE || g_rsi21_handle == INVALID_HANDLE)
      { Print("RSI_MR_GridLog: avg-RSI handles failed"); return INIT_FAILED; }
   }
   if(_01_UseMacdConfirm)
   {
      g_macd_handle = iMACD(_Symbol, PERIOD_CURRENT, _01_MacdFast, _01_MacdSlow, _01_MacdSignal, PRICE_CLOSE);
      if(g_macd_handle == INVALID_HANDLE) { Print("RSI_MR_GridLog: MACD handle failed"); return INIT_FAILED; }
   }

   SRB_Init(_Symbol, _06_MaxTotalLot);
   SRB_SetVerbose(!g_suppress_log);

   g_trade.SetExpertMagicNumber(_07_Magic);
   g_trade.SetDeviationInPoints(_07_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_bar = 0; g_bar_checked = false;
   g_buy_armed = true; g_sell_armed = true;
   g_buy_partial1 = g_buy_partial2 = g_sell_partial1 = g_sell_partial2 = false;
   g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_day_stamp = 0; g_halted_today = false;

   if(!g_suppress_log)
      PrintFormat("RSI_MR_GridLog init | magic=%d RSI(%d) %.0f/%.0f EMAfilter=%s AllowLive=%s",
                  _07_Magic, _01_RsiPeriod, _01_RsiOversold, _01_RsiOverbought,
                  _01_UseEmaFilter ? "on" : "off", _07_AllowLive ? "YES" : "NO");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle  != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ema_handle  != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_macd_handle != INVALID_HANDLE) IndicatorRelease(g_macd_handle);
   if(g_rsi_handle  != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_rsi9_handle != INVALID_HANDLE) IndicatorRelease(g_rsi9_handle);
   if(g_rsi21_handle!= INVALID_HANDLE) IndicatorRelease(g_rsi21_handle);
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double dd = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   if(dd <= 0.0) return -1.0;
   return pf / (1.0 + dd / 100.0);
}

void CheckNewDay()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   datetime day_stamp = (datetime)(dt.year * 10000 + dt.mon * 100 + dt.day);
   if(day_stamp != g_day_stamp)
   {
      g_day_stamp = day_stamp;
      g_day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_halted_today = false;
   }
}

//--------------------------------------------------------------------
// Grid escalation for one side (add a LOG-lot leg on ATR-adverse move)
//--------------------------------------------------------------------
void ManageSideGrid(const ENUM_POSITION_TYPE side, const double distPrice,
                    const double slPips, const bool allow)
{
   int cnt = SideCount(side);
   if(cnt <= 0 || cnt >= _06_MaxPositions) return;

   double anchor = SideAnchorPrice(side);
   if(anchor <= 0.0) return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool trigger = (side == POSITION_TYPE_BUY) ? (bid <= anchor - distPrice)
                                              : (ask >= anchor + distPrice);
   if(!trigger) return;

   double lot = NextSideLot(side, cnt + 1);
   if(lot <= 0.0 || !RiskCapsOk(lot)) return;
   if(!allow)
   {
      if(!g_suppress_log) PrintFormat("DRYRUN GRID_ADD %s leg=%d lot=%.2f",
                                      side == POSITION_TYPE_BUY ? "BUY" : "SELL", cnt + 1, lot);
      return;
   }
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = PipSize(_Symbol);
   double slDist = slPips * pip;
   if(side == POSITION_TYPE_BUY)
      g_trade.Buy(lot, _Symbol, ask, NormalizeDouble(ask - slDist, digits), 0.0, "GRID_ADD");
   else
      g_trade.Sell(lot, _Symbol, bid, NormalizeDouble(bid + slDist, digits), 0.0, "GRID_ADD");
}

//--------------------------------------------------------------------
// Manage one side: partial close -> basket TP -> grid escalation
//--------------------------------------------------------------------
void ManageSide(const ENUM_POSITION_TYPE side, const double tpTarget,
                const double distPrice, const double slPips, const bool allow)
{
   if(SideCount(side) <= 0) return;
   ManageSidePartial(side, tpTarget);
   if(SideFloatingProfit(side) >= tpTarget)
   {
      if(!g_suppress_log) PrintFormat("BASKET TP %s: fp=%.2f target=%.2f",
                                      side == POSITION_TYPE_BUY ? "BUY" : "SELL",
                                      SideFloatingProfit(side), tpTarget);
      CloseSide(side);
      return;
   }
   ManageSideGrid(side, distPrice, slPips, allow);
}

//--------------------------------------------------------------------
// OnTick
//--------------------------------------------------------------------
void OnTick()
{
   CheckNewDay();

   const datetime cur_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_bar != g_last_bar) { g_last_bar = cur_bar; g_bar_checked = false; }
   if(g_bar_checked) return;
   g_bar_checked = true;

   const double atr = GetATR(1);
   if(atr <= 0.0) return;

   const double pip       = PipSize(_Symbol);
   const double distPrice = MathMax(atr * _03_DistAtrMult, _03_MinDistPips * pip);
   const double slPips    = MathMin(_02_SlAtrMult * atr / pip, _02_SlMaxPips);
   const double tpTarget  = _04_TpUsd * _04_TpTargetMult;

   // ── Emergency exit ───────────────────────────────────────────────
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance > 0.0)
   {
      double dd_pct = (balance - equity) / balance * 100.0;
      if(dd_pct >= _06_EmergencyDdPct)
      {
         if(TotalCount() > 0)
         {
            if(!g_suppress_log) PrintFormat("EMERGENCY EXIT: DD %.2f%% >= %.2f%%", dd_pct, _06_EmergencyDdPct);
            CloseAll();
         }
         g_halted_today = true;
         return;
      }
   }

   const bool allow = _07_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);

   // ── Manage existing baskets (both sides) ─────────────────────────
   ManageSide(POSITION_TYPE_BUY,  tpTarget, distPrice, slPips, allow);
   ManageSide(POSITION_TYPE_SELL, tpTarget, distPrice, slPips, allow);

   // ── Signal + re-arm bookkeeping (evaluated on closed bar) ────────
   double rsi = RsiValue(1);
   if(rsi <= 0.0) return;

   // Re-arm each side once RSI returns through the mid level.
   if(rsi >= _01_RsiReArm) g_buy_armed  = true;   // buys re-arm after RSI climbs back to mid
   if(rsi <= _01_RsiReArm) g_sell_armed = true;   // sells re-arm after RSI falls back to mid

   // Optional MACD-histogram confirm.
   double hist = _01_UseMacdConfirm ? MacdHist(1) : 0.0;

   // ── BUY entry: oversold, armed, no buy basket yet ────────────────
   if(rsi < _01_RsiOversold && g_buy_armed && SideCount(POSITION_TYPE_BUY) == 0)
   {
      bool macdOk = !_01_UseMacdConfirm || (hist > 0.0);   // momentum turning up
      double lot  = NextSideLot(POSITION_TYPE_BUY, 1);
      if(macdOk && lot > 0.0 && RiskCapsOk(lot))
      {
         if(allow)
         {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            double sl = NormalizeDouble(ask - slPips * pip, digits);
            if(g_trade.Buy(lot, _Symbol, ask, sl, 0.0, "MR_BUY"))
            { g_buy_armed = false; g_buy_partial1 = g_buy_partial2 = false; }
         }
         else { if(!g_suppress_log) PrintFormat("DRYRUN MR_BUY lot=%.2f rsi=%.1f", lot, rsi); g_buy_armed = false; }
      }
   }

   // ── SELL entry: overbought, armed, no sell basket yet ────────────
   if(rsi > _01_RsiOverbought && g_sell_armed && SideCount(POSITION_TYPE_SELL) == 0)
   {
      bool macdOk = !_01_UseMacdConfirm || (hist < 0.0);
      double lot  = NextSideLot(POSITION_TYPE_SELL, 1);
      if(macdOk && lot > 0.0 && RiskCapsOk(lot))
      {
         if(allow)
         {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            double sl = NormalizeDouble(bid + slPips * pip, digits);
            if(g_trade.Sell(lot, _Symbol, bid, sl, 0.0, "MR_SELL"))
            { g_sell_armed = false; g_sell_partial1 = g_sell_partial2 = false; }
         }
         else { if(!g_suppress_log) PrintFormat("DRYRUN MR_SELL lot=%.2f rsi=%.1f", lot, rsi); g_sell_armed = false; }
      }
   }
}

//+------------------------------------------------------------------+
//| DEPLOYMENT NOTES                                                  |
//|  - Validate from scratch (do NOT trust RSI-from-pips numbers):    |
//|    smoke EURUSD H1 -> BWD 2020-22 -> spread30 -> Model-0 (bwd+fwd)|
//|    -> optimize {DistAtrMult, LogFactor, RSI thresholds,           |
//|    WithTrendMult} IS 2020-23 / OOS 2023-26 -> multi-symbol travel |
//|    (AUDUSD/GBPUSD/USDJPY — the ATR-spacing payoff) -> MC.         |
//|  - V2 toggles (_01_UseMacdConfirm / _01_UseAvgRsi) OFF for the    |
//|    first clean validation; test each as a separate variant after.|
//|  - No hedge, LOG lot, real SL => L3. Hard caps enforced pre-send. |
//+------------------------------------------------------------------+
