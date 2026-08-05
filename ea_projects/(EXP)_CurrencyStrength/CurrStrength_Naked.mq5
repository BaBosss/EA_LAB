//+------------------------------------------------------------------+
//| CurrStrength_Naked.mq5                                           |
//| ORDER-098-D — Currency-Strength-Meter naked entry (fxDreema      |
//|   CCI-Strength / correlation lineage — idea extracted, NOT the   |
//|   no-SL Jobot arbitrage code).                                   |
//|                                                                  |
//| Mechanism: measure each currency's momentum vs USD from a 7-pair |
//| USD-major basket, then trade the CHART symbol toward its stronger|
//| leg. strength(base) - strength(quote) > +thr → BUY; < -thr →SELL.|
//| Non-degenerate on CROSSES (EURJPY/GBPJPY/EURGBP) where the diff  |
//| combines two independent USD-legs; on USD pairs it reduces to    |
//| that pair's own momentum (test on crosses).                     |
//|                                                                  |
//| NAKED PROBE: flat lot, single order, ATR SL/TP. NO grid/MM.      |
//| Purpose (flat-lot doctrine): does strength-diff entry have edge  |
//| ALONE before adding the "strongest-vs-weakest ranking + order    |
//| tricks" build-on layer? Has a real SL (unlike the course files). |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_CurrStrength_Naked — currency-strength-meter naked probe, ORDER-098-D"

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] STRENGTH METER
//--------------------------------------------------------------------
input int    _01_LookbackBars  = 24;    // momentum lookback: (Close[1]/Close[1+N] - 1), N bars
input double _01_EntryThreshold= 0.010;  // |strength(base)-strength(quote)| must exceed this (fraction, 0.010 = 1.0%)
input bool   _01_AllowBuy      = true;
input bool   _01_AllowSell     = true;
// The 7-pair USD-major basket that anchors every currency's strength vs USD. Fixed set (not an
// input array — MT5 tester needs each of these symbols' history synchronized; keep the list small
// and standard so a normal broker has them all). Each currency's strength = its % momentum vs USD:
//   EUR=+mom(EURUSD) GBP=+mom(GBPUSD) AUD=+mom(AUDUSD) NZD=+mom(NZDUSD)
//   JPY=-mom(USDJPY) CHF=-mom(USDCHF) CAD=-mom(USDCAD)   USD=0 (baseline).

//--------------------------------------------------------------------
// [02] SL / TP  (ATR-based, digit-aware)
//--------------------------------------------------------------------
input int    _02_AtrPeriod     = 14;
input double _02_SlAtrMult      = 2.0;   // SL = this * ATR
input double _02_TpAtrMult      = 3.0;   // TP = this * ATR (RR 1.5 default)

//--------------------------------------------------------------------
// [05] TRADE MANAGEMENT — flat-lot, no grid/MM (naked probe)
//--------------------------------------------------------------------
input double _05_LotSize       = 0.01;

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input long   _06_Magic         = 990982;
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;   // SAFETY GATE — real orders only when true

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static datetime g_last_bar_time  = 0;
static bool     g_bar_checked    = false;
static CTrade   g_trade;
static int      g_atr_handle     = INVALID_HANDLE;
// USD-major basket + per-currency strength mapping are hardcoded in CurrencyStrength() below
// (7 pairs: EURUSD GBPUSD AUDUSD NZDUSD USDJPY USDCHF USDCAD).

//--------------------------------------------------------------------
// Helpers
//--------------------------------------------------------------------
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

// % momentum of `symbol` over the lookback: Close[1]/Close[1+N] - 1. Returns false if that
// symbol's bars aren't available yet (tester not synchronized / history missing) so callers
// FAIL-CLOSED rather than trade on a zero/garbage reading.
bool Momentum(const string symbol, double &mom_out)
{
   const int shift_new = 1;
   const int shift_old = 1 + _01_LookbackBars;
   double c_new = iClose(symbol, PERIOD_CURRENT, shift_new);
   double c_old = iClose(symbol, PERIOD_CURRENT, shift_old);
   if(c_new <= 0.0 || c_old <= 0.0) return false;
   mom_out = (c_new / c_old) - 1.0;
   return true;
}

// Strength of a single currency vs USD, derived from the basket. USD itself = 0 baseline.
// Returns false if any needed basket symbol is unavailable (fail-closed).
bool CurrencyStrength(const string ccy, double &s_out)
{
   if(ccy == "USD") { s_out = 0.0; return true; }
   double mom;
   if(ccy == "EUR") { if(!Momentum("EURUSD", mom)) return false; s_out =  mom; return true; }
   if(ccy == "GBP") { if(!Momentum("GBPUSD", mom)) return false; s_out =  mom; return true; }
   if(ccy == "AUD") { if(!Momentum("AUDUSD", mom)) return false; s_out =  mom; return true; }
   if(ccy == "NZD") { if(!Momentum("NZDUSD", mom)) return false; s_out =  mom; return true; }
   if(ccy == "JPY") { if(!Momentum("USDJPY", mom)) return false; s_out = -mom; return true; }
   if(ccy == "CHF") { if(!Momentum("USDCHF", mom)) return false; s_out = -mom; return true; }
   if(ccy == "CAD") { if(!Momentum("USDCAD", mom)) return false; s_out = -mom; return true; }
   return false;  // unknown currency (chart symbol outside the 8-ccy universe)
}

// Splits the chart symbol into base/quote (first 3 / next 3 chars). Returns false if the chart
// symbol isn't a clean 6-letter pair or carries a broker suffix that breaks the split.
bool SplitChartPair(string &base_out, string &quote_out)
{
   string s = _Symbol;
   if(StringLen(s) < 6) return false;
   base_out  = StringSubstr(s, 0, 3);
   quote_out = StringSubstr(s, 3, 3);
   return true;
}

// Signal: +1 buy, -1 sell, 0 none. Trades chart pair toward its stronger leg.
int CheckStrengthSignal()
{
   string base, quote;
   if(!SplitChartPair(base, quote)) return 0;

   double s_base, s_quote;
   if(!CurrencyStrength(base,  s_base))  return 0;   // fail-closed if basket data unavailable
   if(!CurrencyStrength(quote, s_quote)) return 0;

   const double diff = s_base - s_quote;
   if(diff >  _01_EntryThreshold) return  1;
   if(diff < -_01_EntryThreshold) return -1;
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

   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _02_AtrPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("CurrStrength init FAILED: could not create ATR handle");
      return INIT_FAILED;
   }

   // Warn (not fail) if the chart symbol is outside the 8-currency universe — the EA will then
   // never signal (CurrencyStrength returns false), which is a silent no-trade, so make it loud.
   string b, q;
   if(SplitChartPair(b, q))
   {
      double tmp;
      if(!CurrencyStrength(b, tmp) || !CurrencyStrength(q, tmp))
         Print("CurrStrength WARNING: chart ", _Symbol,
               " has a leg outside the USD-major basket universe — EA will not trade here.");
   }

   if(!g_suppress_log)
      PrintFormat("CurrStrength_Naked init | lookback=%d thr=%.4f SLx=%.1f TPx=%.1f lot=%.2f magic=%d",
                  _01_LookbackBars, _01_EntryThreshold, _02_SlAtrMult, _02_TpAtrMult,
                  _05_LotSize, (int)_06_Magic);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 15) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}

bool CurrentAtr(double &atr_out)
{
   double buf[];
   if(CopyBuffer(g_atr_handle, 0, 1, 1, buf) < 1) return false;
   atr_out = buf[0];
   return (atr_out > 0.0);
}

//--------------------------------------------------------------------
// OnTick
//--------------------------------------------------------------------
void OnTick()
{
   const datetime bar1_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(bar1_time != g_last_bar_time)
   {
      g_last_bar_time = bar1_time;
      g_bar_checked   = false;
   }
   if(g_bar_checked) return;
   g_bar_checked = true;

   if(HasOpenPosition()) return;

   const int dir = CheckStrengthSignal();
   if(dir == 0) return;
   if(dir ==  1 && !_01_AllowBuy)  return;
   if(dir == -1 && !_01_AllowSell) return;

   double atr;
   if(!CurrentAtr(atr)) return;   // fail-closed if ATR not ready

   const int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = _02_SlAtrMult * atr;
   const double tp_dist = _02_TpAtrMult * atr;

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

   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      if(!g_suppress_log)
         PrintFormat("DRYRUN %s px=%.5f SL=%.5f TP=%.5f", dir == 1 ? "BUY" : "SELL", entry_price, sl_price, tp_price);
      return;
   }

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("CurrStrength: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }

   bool ok = (dir == 1)
      ? g_trade.Buy (_05_LotSize, _Symbol, ask, sl_price, tp_price, "CSTR_BUY")
      : g_trade.Sell(_05_LotSize, _Symbol, bid, sl_price, tp_price, "CSTR_SELL");

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
