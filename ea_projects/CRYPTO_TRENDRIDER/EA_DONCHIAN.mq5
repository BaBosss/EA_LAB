//+------------------------------------------------------------------+
//| EA_DONCHIAN.mq5 — Donchian 55-bar Turtle breakout (naked v1)   |
//| PDF prompt #94 | Magic 990030 | XAU H4 target                   |
//| Entry: close breaks N-bar Donchian channel (computed in-EA)     |
//| Exit:  reverse signal OR ATR*SL_ATR_mult hard stop              |
//+------------------------------------------------------------------+
#property strict
#property description "EA_DONCHIAN v1 — Donchian Turtle breakout"
#property description "Symbol: XAUUSD  TF: H4  Status: smoke"

#include <Trade\Trade.mqh>

//--- [00] Optimizer
input string  _g00_  = "── [00] OPTIMIZER ──────────────────────";
input bool    _00_OptimizeMode  = false;

//--- [01] Signal
input string  _g01_  = "── [01] SIGNAL ─────────────────────────";
input int     _01_DonchPeriod   = 55;
input int     _01_ATRPeriod     = 10;

//--- [02] SL / TP
input string  _g02_  = "── [02] SL / TP ────────────────────────";
input double  _02_SL_ATR_mult   = 2.0;
input double  _02_TP_ATR_mult   = 0.0;   // 0 = off, ride trend

//--- [03] Filters
input string  _g03_  = "── [03] FILTERS ────────────────────────";
input bool    _03_UseEmaFilter  = true;
input int     _03_EMAperiod     = 200;
input bool    _03_UseAdxFilter  = true;
input int     _03_ADXperiod     = 14;
input double  _03_ADXthreshold  = 20.0;

//--- [04] Pyramid (0 = OFF for smoke)
input string  _g04_  = "── [04] PYRAMID ────────────────────────";
input int     _04_MaxPyramid    = 0;

//--- [05] Trade management
input string  _g05_  = "── [05] TRADE MGMT ─────────────────────";
input double  _05_FixedLot      = 0.01;
input double  _05_RiskPct        = 0.0;   // snowball: 0 = fixed lot; else risk this % of equity per leg over the SL distance
input int     _05_MaxSpreadPts  = 0;

//--- [06] System
input string  _g06_  = "── [06] SYSTEM ─────────────────────────";
input bool    _06_AllowLive     = false;
input int     _06_Magic         = 990030;

//--- globals
CTrade Trade;
int  g_atr_handle = INVALID_HANDLE;
int  g_ema_handle = INVALID_HANDLE;
int  g_adx_handle = INVALID_HANDLE;
bool g_suppress_log = false;
static datetime g_last_bar = 0;

//+------------------------------------------------------------------+
double PipSize(const string sym)
{
   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point  = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}

double NormalizeLot(const string sym, double lot)
{
   double mn = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / st) * st;
   return MathMin(MathMax(lot, mn), mx);
}

// snowball sizing: lot such that a full SL hit costs RiskPct% of current equity.
double RiskLot(const string sym, double slDist)
{
   if(_05_RiskPct <= 0.0 || slDist <= 0.0) return NormalizeLot(sym, _05_FixedLot);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double tickVal  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tickVal <= 0.0 || tickSize <= 0.0) return NormalizeLot(sym, _05_FixedLot);
   double lossPerLot = (slDist / tickSize) * tickVal;
   if(lossPerLot <= 0.0) return NormalizeLot(sym, _05_FixedLot);
   double riskMoney = equity * (_05_RiskPct / 100.0);
   return NormalizeLot(sym, riskMoney / lossPerLot);
}

int CountOwn(ENUM_POSITION_TYPE pt)
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != _06_Magic)  continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == pt) cnt++;
   }
   return cnt;
}

void CloseAll(ENUM_POSITION_TYPE pt)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != _06_Magic)  continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;
      Trade.PositionClose(tk);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _01_ATRPeriod);
   if(_03_UseEmaFilter)
      g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, _03_EMAperiod, 0, MODE_EMA, PRICE_CLOSE);
   if(_03_UseAdxFilter)
      g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, _03_ADXperiod);

   if(g_atr_handle == INVALID_HANDLE
      || (_03_UseEmaFilter && g_ema_handle == INVALID_HANDLE)
      || (_03_UseAdxFilter && g_adx_handle == INVALID_HANDLE))
   {
      Print("EA_DONCHIAN: indicator init FAILED"); return(INIT_FAILED);
   }

   Trade.SetExpertMagicNumber(_06_Magic);
   if(!g_suppress_log)
      Print("EA_DONCHIAN v1 init OK | Magic=", _06_Magic,
            " | Donch=", _01_DonchPeriod, " | MaxPyramid=", _04_MaxPyramid);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Bar-open gate
   const datetime cur_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_bar == g_last_bar) return;
   g_last_bar = cur_bar;

   // Tester gate
   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;

   // Spread guard
   if(_05_MaxSpreadPts > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > _05_MaxSpreadPts) return;

   // Indicator buffers (shift 1 = last completed bar)
   double atr_buf[1], ema_buf[1], adx_buf[1];
   if(CopyBuffer(g_atr_handle, 0, 1, 1, atr_buf) < 1) return;
   if(_03_UseEmaFilter && CopyBuffer(g_ema_handle, 0, 1, 1, ema_buf) < 1) return;
   if(_03_UseAdxFilter && CopyBuffer(g_adx_handle, 0, 1, 1, adx_buf) < 1) return;

   // ADX gate (applies to both long and short)
   if(_03_UseAdxFilter && adx_buf[0] < _03_ADXthreshold) return;

   // Donchian channel: N-bar high/low of bars PRIOR to bar-1 (shift=2 so bar-1 close can break above)
   // shift=2 means we measure the channel from bars 2..N+1; bar-1 is the breakout candle.
   int hi_idx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, _01_DonchPeriod, 2);
   int lo_idx = iLowest (_Symbol, PERIOD_CURRENT, MODE_LOW,  _01_DonchPeriod, 2);
   if(hi_idx < 0 || lo_idx < 0) return;

   double upper  = iHigh (_Symbol, PERIOD_CURRENT, hi_idx);
   double lower  = iLow  (_Symbol, PERIOD_CURRENT, lo_idx);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double ema_v  = _03_UseEmaFilter ? ema_buf[0] : 0.0;

   bool long_ok  = (close1 > upper) && (!_03_UseEmaFilter || close1 > ema_v);
   bool short_ok = (close1 < lower) && (!_03_UseEmaFilter || close1 < ema_v);

   // Exit on reverse signal
   if(CountOwn(POSITION_TYPE_BUY)  > 0 && short_ok) CloseAll(POSITION_TYPE_BUY);
   if(CountOwn(POSITION_TYPE_SELL) > 0 && long_ok)  CloseAll(POSITION_TYPE_SELL);

   // Entry
   double sl_dist = atr_buf[0] * _02_SL_ATR_mult;
   double lot     = (_05_RiskPct > 0.0 && sl_dist > 0.0) ? RiskLot(_Symbol, sl_dist)
                                                         : NormalizeLot(_Symbol, _05_FixedLot);
   double tp_dist = (_02_TP_ATR_mult > 0.0) ? atr_buf[0] * _02_TP_ATR_mult : 0.0;
   int    max_pos = (_04_MaxPyramid > 0) ? _04_MaxPyramid : 1;

   int n_longs  = CountOwn(POSITION_TYPE_BUY);
   int n_shorts = CountOwn(POSITION_TYPE_SELL);

   if(long_ok && n_longs < max_pos && n_shorts == 0)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = ask - sl_dist;
      double tp  = (tp_dist > 0.0) ? ask + tp_dist : 0.0;
      if(!g_suppress_log) Print("DONCH BUY  ask=", ask, " sl=", sl, " lot=", lot, " Donch_upper=", upper);
      Trade.Buy(lot, _Symbol, ask, sl, tp, "DONCH_L");
   }
   else if(short_ok && n_shorts < max_pos && n_longs == 0)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = bid + sl_dist;
      double tp  = (tp_dist > 0.0) ? bid - tp_dist : 0.0;
      if(!g_suppress_log) Print("DONCH SELL bid=", bid, " sl=", sl, " lot=", lot, " Donch_lower=", lower);
      Trade.Sell(lot, _Symbol, bid, sl, tp, "DONCH_S");
   }
}

//+------------------------------------------------------------------+
double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return(-1.0);
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return(sharpe > 0.0 ? sharpe : -1.0);
}
//+------------------------------------------------------------------+
