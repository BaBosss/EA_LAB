//+------------------------------------------------------------------+
//| FVGFill_Naked.mq5                                                |
//| ORDER-098-A — FVG/ICT-zone-fill entry (fxDreema EX009/EX196 algo)|
//| NAKED PROBE: single order, fixed lot, SL/TP only. NO grid, NO MM.|
//| Purpose: does the entry alone have edge? (flat-lot doctrine)     |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_FVGFill_Naked — flat-lot FVG-fill probe, ORDER-098-A"

// Signal (evaluated once per new closed bar — bar-open-only gate):
//   Using shift 1..4 = last 4 fully-closed bars (shift1 = most recently closed).
//   Bullish FVG gap:   Low[2]  > High[4]                      (3-bar gap, shift3 = middle impulse candle, unused in the check)
//   Bullish fill entry: High[4] <= Close[1] <= Low[2]         (price closed back inside the gap)
//                        AND Close[1] > Open[1]                (confirm candle is itself bullish)
//                        AND |Close[1]-Open[1]| > |Close[2]-Open[2]|   (engulfing-size confirm, per spec "body[0]>body[1]")
//   Bearish = mirror (High[2] < Low[4], retrace inside, bearish confirm candle, body-size confirm).
//   NOTE: this is a one-shot check against the last 4 closed bars each new bar (no persistent gap-state
//   tracking across many bars) — matches the literal fxDreema EX009 block logic. A gap that isn't retested
//   within this 4-bar window is not tracked further. This is the intended MVP scope for a flat-lot probe.

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] SIGNAL — FVG-fill (EX009/EX196)
//--------------------------------------------------------------------
input bool   _01_AllowBuy      = true;
input bool   _01_AllowSell     = true;

//--------------------------------------------------------------------
// [02] SL / TP  (fixed pips, digit-aware — locked per EX009 spec)
//--------------------------------------------------------------------
input double _02_SlPips        = 20.0;   // SL distance in pips (EX009 spec, locked) — FX symbols only
input double _02_TpPips        = 15.0;   // TP distance in pips (EX009 spec, locked) — FX symbols only
input double _02_NonFxPipMult  = 10.0;
// "pip" is ambiguous for non-FX symbols (XAU/XAG/indices) — the FX pip formula (point*10 on
// 5/3-digit quotes) does NOT apply. For those, pip = SYMBOL_POINT * this multiplier instead
// (default 10x matches the common $0.10-per-"pip" gold convention on a 2-digit XAUUSD quote,
// i.e. SL 20"pip" = $2.00, TP 15"pip" = $1.50 — sane vs typical gold spread ~$0.20-0.50).
// See IsForexSymbol() for the FX/non-FX split.

//--------------------------------------------------------------------
// [05] TRADE MANAGEMENT — flat-lot, no grid/MM (naked probe)
//--------------------------------------------------------------------
input double _05_LotSize       = 0.01;   // Fixed lot per trade — NEVER escalated

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input long   _06_Magic         = 990980;  // Magic number — free slot, unique per symbol/EA
input ulong  _06_Deviation     = 20;

input bool   _06_AllowLive     = false;
// SAFETY GATE — real broker orders only when true. Keep false for all backtest/optimization.

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static datetime g_last_bar_time  = 0;
static bool     g_bar_checked    = false;
static CTrade   g_trade;

//--------------------------------------------------------------------
// Helpers
//--------------------------------------------------------------------
// Crude but effective FX-pair detector: excludes metals/indices explicitly, then
// falls back to the "6-letter currency pair" shape most FX symbols share.
bool IsForexSymbol(const string symbol)
{
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0) return false;
   if(StringFind(symbol, "US30") >= 0 || StringFind(symbol, "US500") >= 0 ||
      StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "OIL") >= 0 ||
      StringFind(symbol, "WTI") >= 0 || StringFind(symbol, "BRENT") >= 0) return false;
   return (StringLen(symbol) == 6);  // EURUSD, USDJPY, GBPUSD, ... (broker suffixes like 'm'/'c' break this — acceptable for a probe)
}

// Digit-aware pip size — FX uses the standard point*10 rule on 5/3-digit quotes; non-FX
// (metals/indices) uses an explicit configurable multiplier instead of guessing (BLOCKER
// fix: applying the FX formula to XAUUSD's 2-digit quote gave SL/TP distances smaller than
// typical spread — a pure execution artifact, not a real entry test).
double PipSize(const string symbol)
{
   int d = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double p = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(IsForexSymbol(symbol)) return (d == 5 || d == 3) ? p * 10.0 : p;
   return p * _02_NonFxPipMult;
}

bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _06_Magic)
         return true;
   }
   return false;
}

// Returns 1 = bullish FVG-fill signal, -1 = bearish, 0 = none.
// Uses shift 1..4 (all fully-closed bars) on the current chart TF.
int CheckFvgFillSignal()
{
   const double high2 = iHigh(_Symbol, PERIOD_CURRENT, 2);
   const double low2  = iLow (_Symbol, PERIOD_CURRENT, 2);
   const double high4 = iHigh(_Symbol, PERIOD_CURRENT, 4);
   const double low4  = iLow (_Symbol, PERIOD_CURRENT, 4);
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double open1  = iOpen (_Symbol, PERIOD_CURRENT, 1);
   const double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   const double open2  = iOpen (_Symbol, PERIOD_CURRENT, 2);

   if(high2 <= 0 || low2 <= 0 || high4 <= 0 || low4 <= 0) return 0;

   const double body1 = MathAbs(close1 - open1);
   const double body2 = MathAbs(close2 - open2);

   // Bullish FVG: gap between shift4-high and shift2-low
   if(low2 > high4)
   {
      const bool retrace_in_gap = (close1 >= high4 && close1 <= low2);
      const bool bullish_confirm = (close1 > open1) && (body1 > body2);
      if(retrace_in_gap && bullish_confirm) return 1;
   }

   // Bearish FVG: gap between shift4-low and shift2-high
   if(high2 < low4)
   {
      const bool retrace_in_gap = (close1 <= low4 && close1 >= high2);
      const bool bearish_confirm = (close1 < open1) && (body1 > body2);
      if(retrace_in_gap && bearish_confirm) return -1;
   }

   return 0;
}

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_bar_time = 0;
   g_bar_checked   = false;

   if(!g_suppress_log)
      PrintFormat("FVGFill_Naked init | AllowLive=%s OptMode=%s SL=%.1fpip TP=%.1fpip lot=%.2f magic=%d",
                  _06_AllowLive ? "YES" : "NO", _00_OptimizeMode ? "ON" : "off",
                  _02_SlPips, _02_TpPips, _05_LotSize, (int)_06_Magic);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}

// Custom optimize fitness: Sharpe-weighted, requires >=15 trades.
double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 15) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}

//--------------------------------------------------------------------
// OnTick
//--------------------------------------------------------------------
void OnTick()
{
   // Bar-open-only gate: only the first tick of each new bar may attempt entry.
   const datetime bar1_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(bar1_time != g_last_bar_time)
   {
      g_last_bar_time = bar1_time;
      g_bar_checked   = false;
   }
   if(g_bar_checked) return;
   g_bar_checked = true;

   if(HasOpenPosition()) return;

   const int dir = CheckFvgFillSignal();
   if(dir == 0) return;
   if(dir ==  1 && !_01_AllowBuy)  return;
   if(dir == -1 && !_01_AllowSell) return;

   const double pip     = PipSize(_Symbol);
   const int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = _02_SlPips * pip;
   const double tp_dist = _02_TpPips * pip;

   double sl_price, tp_price, entry_price;
   if(dir == 1)
   {
      entry_price = ask;
      sl_price = NormalizeDouble(ask - sl_dist, digits);
      tp_price = NormalizeDouble(ask + tp_dist, digits);
   }
   else
   {
      entry_price = bid;
      sl_price = NormalizeDouble(bid + sl_dist, digits);
      tp_price = NormalizeDouble(bid - tp_dist, digits);
   }

   // Safety gate — real orders only when AllowLive; always trade in the Strategy Tester
   // (MQL_TESTER true) so a default-param backtest doesn't silently produce zero trades.
   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      if(!g_suppress_log)
         PrintFormat("DRYRUN %s px=%.5f SL=%.5f TP=%.5f", dir == 1 ? "BUY" : "SELL", entry_price, sl_price, tp_price);
      return;
   }

   bool ok = (dir == 1)
      ? g_trade.Buy (_05_LotSize, _Symbol, ask, sl_price, tp_price, "FVGFILL_BUY")
      : g_trade.Sell(_05_LotSize, _Symbol, bid, sl_price, tp_price, "FVGFILL_SELL");

   if(ok)
   {
      if(!g_suppress_log)
         PrintFormat("EXEC %s lot=%.2f sl=%.5f tp=%.5f ret=%d",
                     dir == 1 ? "BUY" : "SELL", _05_LotSize, sl_price, tp_price, g_trade.ResultRetcode());
   }
   else
   {
      if(!g_suppress_log)
         PrintFormat("ORDER FAILED: %d %s", g_trade.ResultRetcode(), g_trade.ResultComment());
   }
}
