//+------------------------------------------------------------------+
//| FVGFill_RSIgate.mq5                                              |
//| ORDER-098-C — FVG-fill + RSI confluence gate (fxDreema course)   |
//| (098-B was MacdDiv — this is the next FVG-lineage experiment.)   |
//| Fork of (EXP)_FVGFill_Naked (ORDER-098-A). Same FVG-retrace      |
//| geometry, ADDS an RSI oversold/overbought gate (course rule:     |
//| "RSI<30 || RSI>70"). Purpose: naked FVG-fill had NO edge at any  |
//| exit geometry (098-A REJECT, 26 cells never PF>1) — does an RSI  |
//| confluence gate resurrect it? Flat-lot, single order, no grid/MM.|
//|                                                                  |
//| A/B design: _03_UseRsiGate=false → byte-behaviour-identical to   |
//| FVGFill_Naked, so any lift is attributable to the gate alone.    |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_FVGFill_RSIgate — FVG-fill + RSI confluence gate, ORDER-098-C"

// Signal geometry (FVG-retrace + engulfing confirm) is IDENTICAL to FVGFill_Naked rev02 — see that
// file's header for the persistent gap-state ring-buffer rationale. The ONLY behavioural change here
// is the RSI gate applied to an otherwise-valid signal (see CheckFvgFillSignal usage in OnTick).
// Confluence rule (fxDreema FVG-series course, e.g. "RSI<30 || RSI>70"):
//   Bullish FVG fill (buy)  fires only when RSI[1] <  _03_RsiBuyMax   (oversold — buy the dip).
//   Bearish FVG fill (sell) fires only when RSI[1] >  _03_RsiSellMin  (overbought — sell the rip).
// RSI is read on shift 1 (the just-closed bar, same bar the fill is confirmed on) → no look-ahead.

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
input int    _01_MaxAgeBars    = 50;   // max bars a detected gap stays pending before being dropped unfilled

//--------------------------------------------------------------------
// [02] SL / TP  (fixed pips, digit-aware)
//--------------------------------------------------------------------
input double _02_SlPips        = 20.0;   // SL distance in pips — FX symbols only
input double _02_TpPips        = 15.0;   // TP distance in pips — FX symbols only
input double _02_NonFxPipMult  = 10.0;   // non-FX (XAU/XAG/index) pip = SYMBOL_POINT * this

//--------------------------------------------------------------------
// [03] RSI CONFLUENCE GATE  (the ORDER-098-B lever — fxDreema course rule)
//--------------------------------------------------------------------
input bool   _03_UseRsiGate    = true;   // false → identical to FVGFill_Naked (A/B baseline)
input int    _03_RsiPeriod     = 14;     // RSI period
input ENUM_APPLIED_PRICE _03_RsiPrice = PRICE_CLOSE;
input double _03_RsiBuyMax     = 30.0;   // buy only if RSI[1] <  this (oversold)
input double _03_RsiSellMin    = 70.0;   // sell only if RSI[1] >  this (overbought)

//--------------------------------------------------------------------
// [05] TRADE MANAGEMENT — flat-lot, no grid/MM (naked probe)
//--------------------------------------------------------------------
input double _05_LotSize       = 0.01;   // Fixed lot per trade — NEVER escalated

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input long   _06_Magic         = 990981;  // Magic — free slot, unique per symbol/EA
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;   // SAFETY GATE — real orders only when true

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static datetime g_last_bar_time  = 0;
static bool     g_bar_checked    = false;
static CTrade   g_trade;
static int      g_rsi_handle     = INVALID_HANDLE;

// Pending-gap ring buffer (persistent across bars, see FVGFill_Naked header)
#define ZONE_CAP 20
static double   g_zone_hi[ZONE_CAP];
static double   g_zone_lo[ZONE_CAP];
static int      g_zone_dir[ZONE_CAP];   // 1 = bullish gap, -1 = bearish gap
static int      g_zone_age[ZONE_CAP];   // bars since formed
static int      g_zone_count = 0;
static int      g_bar_counter = 0;

//--------------------------------------------------------------------
// Helpers
//--------------------------------------------------------------------
bool IsForexSymbol(const string symbol)
{
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "XAG") >= 0) return false;
   if(StringFind(symbol, "US30") >= 0 || StringFind(symbol, "US500") >= 0 ||
      StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "OIL") >= 0 ||
      StringFind(symbol, "WTI") >= 0 || StringFind(symbol, "BRENT") >= 0) return false;
   return (StringLen(symbol) == 6);
}

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

// Reads RSI on shift 1 (the just-closed bar). Returns false if the value is unavailable
// (handle not ready / not enough history) so the caller can FAIL-CLOSED (skip the trade)
// rather than trade on a garbage RSI reading.
bool GetRsi1(double &rsi_out)
{
   if(g_rsi_handle == INVALID_HANDLE) return false;
   double buf[];
   if(CopyBuffer(g_rsi_handle, 0, 1, 1, buf) < 1) return false;
   rsi_out = buf[0];
   return true;
}

void AddZone(const int dir, const double hi, const double lo)
{
   int slot = (g_zone_count < ZONE_CAP) ? g_zone_count++ : 0;
   g_zone_hi[slot] = hi; g_zone_lo[slot] = lo; g_zone_dir[slot] = dir; g_zone_age[slot] = 0;
}

void RemoveZone(const int idx)
{
   for(int i = idx; i < g_zone_count - 1; i++)
   {
      g_zone_hi[i] = g_zone_hi[i+1]; g_zone_lo[i] = g_zone_lo[i+1];
      g_zone_dir[i] = g_zone_dir[i+1]; g_zone_age[i] = g_zone_age[i+1];
   }
   g_zone_count--;
}

int CheckFvgFillSignal()
{
   g_bar_counter++;

   const double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   const double low1  = iLow (_Symbol, PERIOD_CURRENT, 1);
   const double high3 = iHigh(_Symbol, PERIOD_CURRENT, 3);
   const double low3  = iLow (_Symbol, PERIOD_CURRENT, 3);
   const double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   const double open1  = iOpen (_Symbol, PERIOD_CURRENT, 1);
   const double close2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   const double open2  = iOpen (_Symbol, PERIOD_CURRENT, 2);

   if(high1 <= 0 || low1 <= 0 || high3 <= 0 || low3 <= 0) return 0;

   if(low1 > high3)  AddZone( 1, low1, high3);   // bullish: zone = [high3 .. low1]
   if(high1 < low3)  AddZone(-1, low3, high1);   // bearish: zone = [low3 .. high1]

   const double body1 = MathAbs(close1 - open1);
   const double body2 = MathAbs(close2 - open2);
   int signal = 0;
   int fired_idx = -1;

   for(int i = 0; i < g_zone_count; i++)
   {
      g_zone_age[i]++;
      if(g_zone_age[i] > _01_MaxAgeBars) { RemoveZone(i); i--; continue; }
      if(signal != 0) continue;

      if(g_zone_dir[i] == 1)
      {
         const bool retrace_in_gap  = (close1 >= g_zone_lo[i] && close1 <= g_zone_hi[i]);
         const bool bullish_confirm = (close1 > open1) && (body1 > body2);
         if(retrace_in_gap && bullish_confirm) { signal = 1; fired_idx = i; }
      }
      else
      {
         const bool retrace_in_gap  = (close1 <= g_zone_hi[i] && close1 >= g_zone_lo[i]);
         const bool bearish_confirm = (close1 < open1) && (body1 > body2);
         if(retrace_in_gap && bearish_confirm) { signal = -1; fired_idx = i; }
      }
   }

   if(fired_idx >= 0) RemoveZone(fired_idx);
   return signal;
}

// Applies the RSI confluence gate to a raw FVG signal. Returns the signal unchanged when the gate
// is off; otherwise passes it only if RSI[1] is on the correct side of the threshold. FAIL-CLOSED:
// if the RSI value can't be read while the gate is on, the trade is suppressed (returns 0).
int ApplyRsiGate(const int raw_dir)
{
   if(raw_dir == 0) return 0;
   if(!_03_UseRsiGate) return raw_dir;

   double rsi;
   if(!GetRsi1(rsi)) return 0;   // fail-closed: no reliable RSI → no trade

   if(raw_dir == 1)  return (rsi <  _03_RsiBuyMax)  ? 1  : 0;
   else              return (rsi >  _03_RsiSellMin) ? -1 : 0;
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
   g_zone_count    = 0;
   g_bar_counter   = 0;

   if(_03_UseRsiGate)
   {
      g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, _03_RsiPeriod, _03_RsiPrice);
      if(g_rsi_handle == INVALID_HANDLE)
      {
         Print("FVGFill_RSIgate init FAILED: could not create RSI handle");
         return INIT_FAILED;
      }
   }

   if(!g_suppress_log)
      PrintFormat("FVGFill_RSIgate init | RSIgate=%s p=%d buy<%.0f sell>%.0f | SL=%.1f TP=%.1f lot=%.2f magic=%d",
                  _03_UseRsiGate ? "ON" : "off", _03_RsiPeriod, _03_RsiBuyMax, _03_RsiSellMin,
                  _02_SlPips, _02_TpPips, _05_LotSize, (int)_06_Magic);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_rsi_handle != INVALID_HANDLE) { IndicatorRelease(g_rsi_handle); g_rsi_handle = INVALID_HANDLE; }
}

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
   const datetime bar1_time = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(bar1_time != g_last_bar_time)
   {
      g_last_bar_time = bar1_time;
      g_bar_checked   = false;
   }
   if(g_bar_checked) return;
   g_bar_checked = true;

   if(HasOpenPosition()) return;

   // FVG geometry first, then RSI confluence gate (both read shift 1 = just-closed bar, no look-ahead).
   const int raw = CheckFvgFillSignal();
   const int dir = ApplyRsiGate(raw);
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
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("FVGFillRSI: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }

   bool ok = (dir == 1)
      ? g_trade.Buy (_05_LotSize, _Symbol, ask, sl_price, tp_price, "FVGRSI_BUY")
      : g_trade.Sell(_05_LotSize, _Symbol, bid, sl_price, tp_price, "FVGRSI_SELL");

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
