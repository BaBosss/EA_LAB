//+------------------------------------------------------------------+
//| (TRD)_PA_Probe_rev01.mq5                                          |
//|                                                                    |
//| PHASE 0 of the PriceAction-module plan (KNOWLEDGE_SYNTHESIS_EA_   |
//| DEVPLAN.md). Purpose: measure what a candle-PA CONFIRM does to a  |
//| base signal, IN CONTEXT — the value of PA depends on whether it   |
//| is used with-trend (continuation) or counter-trend (reversal).    |
//|                                                                    |
//| Controlled A/B: flat lot, ONE position at a time, fixed ATR SL +  |
//| RR TP (NO grid) so we isolate SIGNAL QUALITY, not stacking.       |
//|   _01_UsePA = false -> base signal only (baseline)                |
//|   _01_UsePA = true  -> base signal AND an engulfing in that dir   |
//| Two base signals:                                                 |
//|   MODE_CONTINUATION : EMA trend; buy in uptrend / sell in down.   |
//|   MODE_REVERSAL     : RSI extreme; buy oversold / sell overbought.|
//| Read the RESULT as a tendency across metrics (expectancy/payoff/  |
//| win%/DD/#trades), not PF alone. NOT a deploy candidate — a probe. |
//+------------------------------------------------------------------+
#property strict
#property description "(TRD)_PA_Probe_rev01 — Phase-0 candle-confirm A/B (continuation vs reversal)"

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
input string _g00_             = "── [00] TESTER / OPTIMIZER ────────────────";
input bool   _00_OptimizeMode  = false;

//--------------------------------------------------------------------
// [01] SIGNAL + PA TOGGLE (the A/B lever)
//--------------------------------------------------------------------
input string _g01_             = "── [01] SIGNAL ────────────────────────────";
enum ENUM_MODE { MODE_CONTINUATION = 0, MODE_REVERSAL = 1 };
input ENUM_MODE _01_Mode       = MODE_CONTINUATION;
input bool   _01_UsePA         = false;   // A/B: false=base signal only, true=require engulfing confirm
input int    _01_EmaPeriod     = 50;      // continuation trend filter
input int    _01_RsiPeriod     = 14;      // reversal oscillator
input double _01_RsiOS         = 35.0;    // reversal: buy when RSI < OS
input double _01_RsiOB         = 65.0;    // reversal: sell when RSI > OB
input double _01_EngulfMinBodyRatio = 1.0; // engulf body must be >= this x prior body (1.0 = classic)

//--------------------------------------------------------------------
// [02] EXIT — flat, single position, ATR SL + RR TP (isolates signal quality)
//--------------------------------------------------------------------
input string _g02_             = "── [02] EXIT ──────────────────────────────";
input int    _02_AtrPeriod     = 14;
input double _02_SlAtrMult      = 2.0;    // SL = ATR * mult
input double _02_RR             = 1.5;    // TP = SL * RR

//--------------------------------------------------------------------
// [05] LOT (flat — we are measuring signal, not sizing)
//--------------------------------------------------------------------
input string _g05_             = "── [05] LOT (flat) ────────────────────────";
input double _05_Lot           = 0.10;

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input string _g06_             = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic         = 990301;
input ulong  _06_Deviation     = 30;
input bool   _06_AllowLive     = false;

//--------------------------------------------------------------------
static bool     g_suppress_log = false;
static int      g_atr_handle   = INVALID_HANDLE;
static int      g_ema_handle   = INVALID_HANDLE;
static int      g_rsi_handle   = INVALID_HANDLE;
static datetime g_last_bar     = 0;
static CTrade   g_trade;

double GetBuf(const int handle, const int shift)
{
   double b[1];
   if(handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle, 0, shift, 1, b) < 1) return 0.0;
   return b[0];
}

bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == _06_Magic)
         return true;
   }
   return false;
}

//--------------------------------------------------------------------
// Engulfing on the last CLOSED bars: prev = shift2, signal bar = shift1.
// Bull: prior bar bearish, signal bar bullish, signal body engulfs prior body.
//--------------------------------------------------------------------
bool BullEngulf()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1), c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 2), c2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double body1 = MathAbs(c1 - o1), body2 = MathAbs(c2 - o2);
   bool priorBear = (c2 < o2);
   bool sigBull   = (c1 > o1);
   bool engulf    = (c1 >= o2 && o1 <= c2);   // signal body covers prior body
   bool bigEnough = (body2 <= 0.0) ? false : (body1 >= _01_EngulfMinBodyRatio * body2);
   return (priorBear && sigBull && engulf && bigEnough);
}

bool BearEngulf()
{
   double o1 = iOpen(_Symbol, PERIOD_CURRENT, 1), c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double o2 = iOpen(_Symbol, PERIOD_CURRENT, 2), c2 = iClose(_Symbol, PERIOD_CURRENT, 2);
   double body1 = MathAbs(c1 - o1), body2 = MathAbs(c2 - o2);
   bool priorBull = (c2 > o2);
   bool sigBear   = (c1 < o1);
   bool engulf    = (c1 <= o2 && o1 >= c2);
   bool bigEnough = (body2 <= 0.0) ? false : (body1 >= _01_EngulfMinBodyRatio * body2);
   return (priorBull && sigBear && engulf && bigEnough);
}

//--------------------------------------------------------------------
// Base signal direction (before PA): +1 buy, -1 sell, 0 none.
//--------------------------------------------------------------------
int BaseSignal()
{
   if(_01_Mode == MODE_CONTINUATION)
   {
      double ema1 = GetBuf(g_ema_handle, 1);
      double ema5 = GetBuf(g_ema_handle, 5);
      double c1   = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(ema1 <= 0.0 || ema5 <= 0.0) return 0;
      bool up   = (c1 > ema1 && ema1 > ema5);   // price above a rising EMA
      bool down = (c1 < ema1 && ema1 < ema5);
      if(up)   return +1;
      if(down) return -1;
      return 0;
   }
   // MODE_REVERSAL
   double rsi = GetBuf(g_rsi_handle, 1);
   if(rsi <= 0.0) return 0;
   if(rsi < _01_RsiOS) return +1;   // oversold -> buy the bounce
   if(rsi > _01_RsiOB) return -1;   // overbought -> sell the fade
   return 0;
}

int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _02_AtrPeriod);
   g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, _01_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, _01_RsiPeriod, PRICE_CLOSE);
   if(g_atr_handle == INVALID_HANDLE || g_ema_handle == INVALID_HANDLE || g_rsi_handle == INVALID_HANDLE)
   { Print("PA_Probe: handle failed"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   return TesterStatistics(STAT_EXPECTED_PAYOFF);   // expectancy per trade — the Phase-0 lens
}

void OnTick()
{
   const datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur == g_last_bar) return;
   g_last_bar = cur;

   if(HasOpenPosition()) return;   // one position at a time; SL/TP manage the exit

   int sig = BaseSignal();
   if(sig == 0) return;

   // PA confirm gate (the A/B lever)
   if(_01_UsePA)
   {
      if(sig > 0 && !BullEngulf()) return;
      if(sig < 0 && !BearEngulf()) return;
   }

   const double atr = GetBuf(g_atr_handle, 1);
   if(atr <= 0.0) return;
   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double slDist = _02_SlAtrMult * atr;
   const double tpDist = slDist * _02_RR;

   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(_05_Lot < minLot){ if(!g_suppress_log) PrintFormat("PA_Probe: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_Lot,minLot); return; }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(sig > 0)
   {
      double sl = NormalizeDouble(ask - slDist, digits);
      double tp = NormalizeDouble(ask + tpDist, digits);
      if(!g_trade.Buy(_05_Lot, _Symbol, ask, sl, tp, "PA_PROBE") && !g_suppress_log)
         PrintFormat("PA_PROBE-BUY FAILED retcode=%d",g_trade.ResultRetcode());
   }
   else
   {
      double sl = NormalizeDouble(bid + slDist, digits);
      double tp = NormalizeDouble(bid - tpDist, digits);
      if(!g_trade.Sell(_05_Lot, _Symbol, bid, sl, tp, "PA_PROBE") && !g_suppress_log)
         PrintFormat("PA_PROBE-SELL FAILED retcode=%d",g_trade.ResultRetcode());
   }
}
