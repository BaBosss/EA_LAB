//+------------------------------------------------------------------+
//| EA_DONCHIAN_ADD.mq5 — Donchian Turtle breakout + pullback adds   |
//| ORDER-125b | Magic 990031 | BTC/ETH H4 target                    |
//| Entry #1: close breaks N-bar Donchian channel (same as v1)       |
//| Adds:     AddMode 0 = repeat-breakout (v1 behavior)              |
//|           AddMode 1 = Stochastic pullback-in-trend cross         |
//| Exit:     reverse Donchian signal OR ATR*SL hard stop per leg    |
//+------------------------------------------------------------------+
#property strict
#property description "EA_DONCHIAN_ADD — Turtle breakout + STO pullback adds"
#property description "A/B vehicle for ORDER-125b. Base = EA_DONCHIAN v1 locked logic."

#include <Trade\Trade.mqh>

//--- [00] Optimizer
input string  _g00_  = "── [00] OPTIMIZER ──────────────────────";
input bool    _00_OptimizeMode  = false;

//--- [01] Signal
input string  _g01_  = "── [01] SIGNAL ─────────────────────────";
input int     _01_DonchPeriod   = 35;
input int     _01_ATRPeriod     = 10;

//--- [02] SL / TP
input string  _g02_  = "── [02] SL / TP ────────────────────────";
input double  _02_SL_ATR_mult   = 2.25;
input double  _02_TP_ATR_mult   = 0.0;   // 0 = off, ride trend

//--- [03] Filters
input string  _g03_  = "── [03] FILTERS ────────────────────────";
input bool    _03_UseEmaFilter  = true;
input int     _03_EMAperiod     = 200;
input bool    _03_UseAdxFilter  = true;
input int     _03_ADXperiod     = 14;
input double  _03_ADXthreshold  = 20.0;

//--- [04] Pyramid / adds
input string  _g04_  = "── [04] PYRAMID / ADDS ─────────────────";
input int     _04_MaxPyramid    = 3;     // total legs cap (1 = no adds)
input int     _04_AddMode       = 1;     // 0=repeat-breakout adds · 1=STO pullback adds
input int     _04_StoK          = 14;    // %K period (sweep 9/14/21 — default-noise lesson)
input int     _04_StoD          = 3;
input int     _04_StoSlow       = 3;
input double  _04_StoLevel      = 30.0;  // long add: K crosses UP through this after dipping below
                                         // short add: K crosses DOWN through (100 - this)
input double  _04_MinAddGapATR  = 0.5;   // min |price - last own entry| in ATR before an add

//--- [05] Trade management
input string  _g05_  = "── [05] TRADE MGMT ─────────────────────";
input double  _05_FixedLot      = 0.01;
input int     _05_MaxSpreadPts  = 0;

//--- [06] System
input string  _g06_  = "── [06] SYSTEM ─────────────────────────";
input bool    _06_AllowLive     = false;
input int     _06_Magic         = 990031;

//--- globals
CTrade Trade;
int  g_atr_handle = INVALID_HANDLE;
int  g_ema_handle = INVALID_HANDLE;
int  g_adx_handle = INVALID_HANDLE;
int  g_sto_handle = INVALID_HANDLE;
bool g_suppress_log = false;
static datetime g_last_bar = 0;

//+------------------------------------------------------------------+
double NormalizeLot(const string sym, double lot)
{
   double mn = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / st) * st;
   return MathMin(MathMax(lot, mn), mx);
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

// open price of the most recently opened own position of this type (0 if none)
double LastOwnOpenPrice(ENUM_POSITION_TYPE pt)
{
   double   price = 0.0;
   datetime best  = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)    continue;
      if(PositionGetInteger(POSITION_MAGIC)  != _06_Magic)  continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != pt) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(ot >= best) { best = ot; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
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
   if(_04_AddMode == 1)
      g_sto_handle = iStochastic(_Symbol, PERIOD_CURRENT, _04_StoK, _04_StoD, _04_StoSlow,
                                 MODE_SMA, STO_LOWHIGH);

   if(g_atr_handle == INVALID_HANDLE
      || (_03_UseEmaFilter && g_ema_handle == INVALID_HANDLE)
      || (_03_UseAdxFilter && g_adx_handle == INVALID_HANDLE)
      || (_04_AddMode == 1 && g_sto_handle == INVALID_HANDLE))
   {
      Print("EA_DONCHIAN_ADD: indicator init FAILED"); return(INIT_FAILED);
   }

   Trade.SetExpertMagicNumber(_06_Magic);
   if(!g_suppress_log)
      Print("EA_DONCHIAN_ADD init OK | Magic=", _06_Magic, " | Donch=", _01_DonchPeriod,
            " | MaxPyramid=", _04_MaxPyramid, " | AddMode=", _04_AddMode);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_sto_handle != INVALID_HANDLE) IndicatorRelease(g_sto_handle);
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

   // ADX gate blocks NEW first-entries and breakout adds; pullback adds keep their own trend guard
   const bool adx_ok = (!_03_UseAdxFilter || adx_buf[0] >= _03_ADXthreshold);

   // Donchian channel (identical to v1: bars 2..N+1, bar-1 = breakout candle)
   int hi_idx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, _01_DonchPeriod, 2);
   int lo_idx = iLowest (_Symbol, PERIOD_CURRENT, MODE_LOW,  _01_DonchPeriod, 2);
   if(hi_idx < 0 || lo_idx < 0) return;

   double upper  = iHigh (_Symbol, PERIOD_CURRENT, hi_idx);
   double lower  = iLow  (_Symbol, PERIOD_CURRENT, lo_idx);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double ema_v  = _03_UseEmaFilter ? ema_buf[0] : 0.0;

   bool long_brk  = (close1 > upper) && (!_03_UseEmaFilter || close1 > ema_v);
   bool short_brk = (close1 < lower) && (!_03_UseEmaFilter || close1 < ema_v);

   // Exit on reverse signal (regardless of ADX — same as v1 close path)
   if(CountOwn(POSITION_TYPE_BUY)  > 0 && short_brk) CloseAll(POSITION_TYPE_BUY);
   if(CountOwn(POSITION_TYPE_SELL) > 0 && long_brk)  CloseAll(POSITION_TYPE_SELL);

   int n_longs  = CountOwn(POSITION_TYPE_BUY);
   int n_shorts = CountOwn(POSITION_TYPE_SELL);
   int max_pos  = MathMax(_04_MaxPyramid, 1);

   double lot     = NormalizeLot(_Symbol, _05_FixedLot);
   double sl_dist = atr_buf[0] * _02_SL_ATR_mult;
   double tp_dist = (_02_TP_ATR_mult > 0.0) ? atr_buf[0] * _02_TP_ATR_mult : 0.0;

   // ---- STO pullback add signal (AddMode 1, only while a trend position is open)
   bool add_long_sto = false, add_short_sto = false;
   if(_04_AddMode == 1 && (n_longs > 0 || n_shorts > 0))
   {
      double k_buf[2];   // start_pos=1,count=2 → ascending time: k_buf[0]=bar2, k_buf[1]=bar1
      if(CopyBuffer(g_sto_handle, MAIN_LINE, 1, 2, k_buf) < 2) return;
      double k_prev = k_buf[0];   // bar 2
      double k_last = k_buf[1];   // bar 1 (last completed)
      double lvl_lo = _04_StoLevel, lvl_hi = 100.0 - _04_StoLevel;
      // long add: %K dipped below lvl_lo then crossed back up, trend intact
      add_long_sto  = (n_longs  > 0) && (k_prev < lvl_lo) && (k_last >= lvl_lo)
                      && (!_03_UseEmaFilter || close1 > ema_v);
      // short add: %K rose above lvl_hi then crossed back down, trend intact
      add_short_sto = (n_shorts > 0) && (k_prev > lvl_hi) && (k_last <= lvl_hi)
                      && (!_03_UseEmaFilter || close1 < ema_v);
   }

   // ---- LONG side
   if(n_shorts == 0 && n_longs < max_pos)
   {
      bool first    = (n_longs == 0) && long_brk && adx_ok;
      bool add_brk  = (n_longs > 0) && (_04_AddMode == 0) && long_brk && adx_ok;
      bool add_sto  = add_long_sto;
      if(first || add_brk || add_sto)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         bool gap_ok = true;
         if(!first && _04_MinAddGapATR > 0.0)
         {
            double lastp = LastOwnOpenPrice(POSITION_TYPE_BUY);
            gap_ok = (lastp <= 0.0) || (MathAbs(ask - lastp) >= _04_MinAddGapATR * atr_buf[0]);
         }
         if(gap_ok)
         {
            double sl = ask - sl_dist;
            double tp = (tp_dist > 0.0) ? ask + tp_dist : 0.0;
            string tag = first ? "DONCH_L" : (add_sto ? "ADD_STO_L" : "ADD_BRK_L");
            if(!g_suppress_log) Print(tag, " ask=", ask, " sl=", sl, " lot=", lot);
            Trade.Buy(lot, _Symbol, ask, sl, tp, tag);
         }
      }
   }
   // ---- SHORT side (independent if — else-if would let an empty long-block
   // evaluation swallow short signals whenever we are flat, since the long
   // OUTER condition is always true at 0 positions)
   if(n_longs == 0 && n_shorts < max_pos)
   {
      bool first    = (n_shorts == 0) && short_brk && adx_ok;
      bool add_brk  = (n_shorts > 0) && (_04_AddMode == 0) && short_brk && adx_ok;
      bool add_sto  = add_short_sto;
      if(first || add_brk || add_sto)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool gap_ok = true;
         if(!first && _04_MinAddGapATR > 0.0)
         {
            double lastp = LastOwnOpenPrice(POSITION_TYPE_SELL);
            gap_ok = (lastp <= 0.0) || (MathAbs(bid - lastp) >= _04_MinAddGapATR * atr_buf[0]);
         }
         if(gap_ok)
         {
            double sl = bid + sl_dist;
            double tp = (tp_dist > 0.0) ? bid - tp_dist : 0.0;
            string tag = first ? "DONCH_S" : (add_sto ? "ADD_STO_S" : "ADD_BRK_S");
            if(!g_suppress_log) Print(tag, " bid=", bid, " sl=", sl, " lot=", lot);
            Trade.Sell(lot, _Symbol, bid, sl, tp, tag);
         }
      }
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
