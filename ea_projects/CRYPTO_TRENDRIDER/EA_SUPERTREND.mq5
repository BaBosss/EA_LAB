//+------------------------------------------------------------------+
//|  EA_SUPERTREND.mq5                                                |
//|  Standalone trend-follower from 200-prompt catalog #68.          |
//|  SuperTrend(ATR10, mult3) flip + EMA200 + ADX(14) filters.       |
//|  NAKED v1 — no grid/martingale/hedge (lab "naked edge first").   |
//|                                                                   |
//|  NOTE: ALL indicators use PERIOD_CURRENT (not a hardcoded TF) so  |
//|  -Period genuinely changes the signal TF and the EA is single-TF  |
//|  (Model-2 compatible / parallel-smoke safe). [lesson 2026-06-27]  |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//──────────────────────────────────────────────────────────────────
input string _g01_ = "── [01] SIGNAL ────────────────────────────";
input int    _01_ATRperiod    = 10;     // SuperTrend ATR period
input double _01_Multiplier   = 3.0;    // SuperTrend ATR multiplier

input string _g02_ = "── [02] SL / TP ───────────────────────────";
input double _02_SL_ATR_mult  = 2.0;    // hard SL = ATR * this (0 = no hard SL, rely on flip exit)
input double _02_TP_ATR_mult  = 0.0;    // fixed TP = ATR * this (0 = off, ride trend to flip)

input string _g03_ = "── [03] FILTERS ───────────────────────────";
input bool   _03_UseEmaFilter = true;   // long only above EMA, short only below
input int    _03_EMAperiod    = 200;
input bool   _03_UseAdxFilter = true;   // only trade when trend has strength
input int    _03_ADXperiod    = 14;
input double _03_ADXthreshold  = 20.0;

input string _g05_ = "── [05] TRADE MGMT ────────────────────────";
input double _05_FixedLot      = 0.01;
input double _05_RiskPct        = 0.0;   // snowball: 0 = fixed lot; else size each entry to risk this % of equity over the SL distance
input int    _05_MaxSpreadPts  = 0;     // 0 = off; else skip entry if spread > this (points)

input string _g06_ = "── [06] SYSTEM ────────────────────────────";
input bool   _06_AllowLive     = false; // tester always simulates; live gated by this
input long   _06_Magic         = 990020;

//──────────────────────────────────────────────────────────────────
CTrade   g_trade;
int      g_atr_handle = INVALID_HANDLE;
int      g_ema_handle = INVALID_HANDLE;
int      g_adx_handle = INVALID_HANDLE;

// SuperTrend recursive state (updated once per closed bar)
double   g_final_upper = 0.0;
double   g_final_lower = 0.0;
int      g_trend       = 0;     // +1 up, -1 down, 0 uninitialised
double   g_close_prev  = 0.0;   // close of the bar before the one being processed
bool     g_st_ready    = false;

datetime g_last_bar    = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _01_ATRperiod);
   g_ema_handle = iMA (_Symbol, PERIOD_CURRENT, _03_EMAperiod, 0, MODE_EMA, PRICE_CLOSE);
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, _03_ADXperiod);
   if(g_atr_handle == INVALID_HANDLE || g_ema_handle == INVALID_HANDLE || g_adx_handle == INVALID_HANDLE)
   {
      Print("EA_SUPERTREND: indicator handle failed");
      return(INIT_FAILED);
   }
   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   g_trend    = 0;
   g_st_ready = false;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}

//+------------------------------------------------------------------+
//| Lot normalize to broker constraints                              |
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;
   lot = MathFloor(lot / lotStep) * lotStep;
   return MathMin(MathMax(lot, minLot), maxLot);
}

// snowball sizing: lot such that a full SL hit costs RiskPct% of current equity.
double RiskLot(double slDist)
{
   if(_05_RiskPct <= 0.0 || slDist <= 0.0) return NormalizeLot(_05_FixedLot);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return 0.0;
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) return 0.0;
   double lossPerLot = (slDist / tickSize) * tickVal;
   if(lossPerLot <= 0.0) return 0.0;
   double rawLot = (equity * (_05_RiskPct / 100.0)) / lossPerLot;
   // do NOT floor up to broker min lot in risk-mode — that would silently exceed RiskPct. Skip instead.
   if(rawLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) return 0.0;
   return NormalizeLot(rawLot);
}

//+------------------------------------------------------------------+
//| Own position direction: +1 long, -1 short, 0 none               |
//+------------------------------------------------------------------+
int OwnPositionDir()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      return (type == POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
}

void CloseOwnPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      g_trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
//| Update SuperTrend with the just-closed bar (shift `s`).          |
//| Returns: +2 flip-to-up, -2 flip-to-down, +1 up, -1 down.         |
//+------------------------------------------------------------------+
int UpdateSuperTrend(const int s)
{
   double atr[1];
   if(CopyBuffer(g_atr_handle, 0, s, 1, atr) != 1) return 0;

   double hi  = iHigh (_Symbol, PERIOD_CURRENT, s);
   double lo  = iLow  (_Symbol, PERIOD_CURRENT, s);
   double cl  = iClose(_Symbol, PERIOD_CURRENT, s);
   double hl2 = (hi + lo) * 0.5;

   double upperBasic = hl2 + _01_Multiplier * atr[0];
   double lowerBasic = hl2 - _01_Multiplier * atr[0];

   if(!g_st_ready)
   {
      // seed
      g_final_upper = upperBasic;
      g_final_lower = lowerBasic;
      g_trend       = (cl >= hl2) ? 1 : -1;
      g_close_prev  = cl;
      g_st_ready    = true;
      return g_trend;
   }

   double finalUpper = (upperBasic < g_final_upper || g_close_prev > g_final_upper)
                       ? upperBasic : g_final_upper;
   double finalLower = (lowerBasic > g_final_lower || g_close_prev < g_final_lower)
                       ? lowerBasic : g_final_lower;

   int prevTrend = g_trend;
   int newTrend  = prevTrend;
   if(prevTrend == 1)        newTrend = (cl < finalLower) ? -1 : 1;
   else /* prevTrend == -1*/ newTrend = (cl > finalUpper) ?  1 : -1;

   // commit state
   g_final_upper = finalUpper;
   g_final_lower = finalLower;
   g_close_prev  = cl;
   g_trend       = newTrend;

   if(prevTrend == -1 && newTrend == 1) return  2;   // flip up
   if(prevTrend ==  1 && newTrend == -1) return -2;   // flip down
   return newTrend;
}

//+------------------------------------------------------------------+
bool SpreadOK()
{
   if(_05_MaxSpreadPts <= 0) return true;
   long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (sp <= _05_MaxSpreadPts);
}

//+------------------------------------------------------------------+
void OpenTrade(const bool isLong, const double atrVal)
{
   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;

   double slDist = (_02_SL_ATR_mult > 0.0) ? atrVal * _02_SL_ATR_mult : 0.0;
   double lot = (_05_RiskPct > 0.0 && slDist > 0.0) ? RiskLot(slDist) : NormalizeLot(_05_FixedLot);
   if(lot <= 0) return;

   double price = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0.0, tp = 0.0;
   if(_02_SL_ATR_mult > 0.0)
      sl = isLong ? price - atrVal * _02_SL_ATR_mult
                  : price + atrVal * _02_SL_ATR_mult;
   if(_02_TP_ATR_mult > 0.0)
      tp = isLong ? price + atrVal * _02_TP_ATR_mult
                  : price - atrVal * _02_TP_ATR_mult;

   if(isLong) g_trade.Buy (lot, _Symbol, 0.0, sl, tp, "ST_ATR10x3");
   else       g_trade.Sell(lot, _Symbol, 0.0, sl, tp, "ST_ATR10x3");
}

//+------------------------------------------------------------------+
void OnTick()
{
   // bar-open gate: evaluate once per newly-closed bar
   const datetime cur_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_bar == g_last_bar) return;
   g_last_bar = cur_bar;

   // need enough bars for EMA200 etc.
   if(Bars(_Symbol, PERIOD_CURRENT) < _03_EMAperiod + 5) return;

   // process the just-closed bar (shift 1)
   int stSig = UpdateSuperTrend(1);
   if(stSig == 0) return;

   double atr[1];
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr) != 1) return;

   int dir = OwnPositionDir();

   // ---- EXIT on flip against position (also frees us to reverse) ----
   if(dir == 1 && (stSig == -2 || g_trend == -1)) { CloseOwnPosition(); dir = 0; }
   if(dir == -1 && (stSig ==  2 || g_trend ==  1)) { CloseOwnPosition(); dir = 0; }

   // only act on a fresh flip for entries
   bool flipUp   = (stSig ==  2);
   bool flipDown = (stSig == -2);
   if(!flipUp && !flipDown) return;

   // ---- FILTERS ----
   double cl1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(_03_UseEmaFilter)
   {
      double ema[1];
      if(CopyBuffer(g_ema_handle, 0, 1, 1, ema) != 1) return;
      if(flipUp   && cl1 <  ema[0]) return;
      if(flipDown && cl1 >  ema[0]) return;
   }
   if(_03_UseAdxFilter)
   {
      double adx[1];
      if(CopyBuffer(g_adx_handle, 0, 1, 1, adx) != 1) return;   // buffer 0 = main ADX line
      if(adx[0] < _03_ADXthreshold) return;
   }
   if(!SpreadOK()) return;

   // ---- ENTRY (OnlyOnePositionPerSymbol) ----
   if(flipUp   && dir <= 0) { if(dir < 0) CloseOwnPosition(); OpenTrade(true,  atr[0]); }
   if(flipDown && dir >= 0) { if(dir > 0) CloseOwnPosition(); OpenTrade(false, atr[0]); }
}

//+------------------------------------------------------------------+
double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}
//+------------------------------------------------------------------+
