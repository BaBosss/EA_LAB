//+------------------------------------------------------------------+
//| FVGFill_Naked.mq5                                                |
//| ORDER-098-A — FVG/ICT-zone-fill entry (fxDreema EX009/EX196 algo)|
//| NAKED PROBE: single order, fixed lot, SL/TP only. NO grid, NO MM.|
//| Purpose: does the entry alone have edge? (flat-lot doctrine)     |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_FVGFill_Naked — flat-lot FVG-fill probe, ORDER-098-A"

// Signal (evaluated once per new closed bar — bar-open-only gate), PERSISTENT gap-state version
// (rev02 — the original one-shot 4-bar-snapshot check under-sampled badly: 0-5 trades over 3yr,
// ORDER-098-A first smoke was ruled INCONCLUSIVE, not dead. Real FVG retests often happen many
// bars after the gap forms, so the gap zone must be remembered, not re-derived from a fixed window):
//   On each new closed bar, using shift 1..3 (shift1=newest closed):
//     Bullish FVG forms when  Low[1] > High[3]   → store zone [High[3] .. Low[1]], bullish, age=0.
//     Bearish FVG forms when  High[1] < Low[3]   → store zone [High[1] .. Low[3]], bearish, age=0.
//   Every subsequent new bar, for each pending zone (age <= _01_MaxAgeBars):
//     Bullish fill: Close[1] falls inside the zone AND Close[1]>Open[1] (confirm candle bullish)
//                   AND body[1] > body[2] (engulfing-size confirm, per EX009 spec "body[0]>body[1]").
//     Bearish = mirror. First zone that fires consumes itself (removed); zones older than the
//     age cap are dropped unfilled. Fixed-size ring buffer, oldest dropped if buffer is full.

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

// Pending-gap ring buffer (persistent across bars, see header comment)
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

void AddZone(const int dir, const double hi, const double lo)
{
   // NOTE: if the buffer is full, this overwrites slot 0 without a true FIFO shift (probe-grade
   // simplification — losing track of one old gap early is not a correctness bug, just an
   // acceptable edge case at a 20-concurrent-pending-gap cap that H1/H4 majors are unlikely to hit).
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

// Detects new gaps on the freshest 3 closed bars, ages/prunes pending zones, and checks every
// pending zone for a retrace-fill. Returns 1 = bullish fill signal, -1 = bearish, 0 = none.
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

   // New gap detection (shift1 vs shift3, shift2 = middle impulse candle, unused in the check)
   if(low1 > high3)  AddZone( 1, low1, high3);   // bullish: zone = [high3 .. low1]
   if(high1 < low3)  AddZone(-1, low3, high1);   // bearish: zone = [low3 .. high1] (hi field holds low3)

   const double body1 = MathAbs(close1 - open1);
   const double body2 = MathAbs(close2 - open2);
   int signal = 0;
   int fired_idx = -1;

   // Age + prune + fill-check, oldest-first
   for(int i = 0; i < g_zone_count; i++)
   {
      g_zone_age[i]++;
      if(g_zone_age[i] > _01_MaxAgeBars) { RemoveZone(i); i--; continue; }
      if(signal != 0) continue;  // one fill per bar; keep pruning the rest of the list

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

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("FVGFill: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }

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
