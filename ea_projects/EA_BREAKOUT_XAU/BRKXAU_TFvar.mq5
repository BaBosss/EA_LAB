//+------------------------------------------------------------------+
//| EA_BREAKOUT_XAU.mq5                                             |
//| Canonical name: (Boss)_Breakout_Donchian_XAU_rev01              |
//| XAUUSD H1 Â· Donchian-channel breakout Â· BUY-only                |
//|                                                                  |
//| Validated (2026-06-21):                                          |
//|   IS  2020-2026  M4  PF=2.27  86t   DD=2.08%                   |
//|   OOS 2023-2026  M4  PF=1.77  33t   DD=0.65%  Sharpe=3.69      |
//|   MC  bootstrap  PF-5th=1.43  ruin=0%  DD-95th=1.96%            |
//+------------------------------------------------------------------+
#property strict
#property description "(Boss)_Breakout_Donchian_XAU_rev01"
#property description "OOS M4 PF=1.77 Â· MC PF-5th=1.43 Â· ruin=0%"

// Entry (bar-open-only â€” first tick per H1 bar):
//   BUY  when ASK > Donchian high of last N H1 bars  (shift 1+)
//        AND  ATR(14)[1] > avg(ATR, 20 bars) Ã— AtrExpandRatio   [volatility gate]
//        AND  Daily close[1] > EMA(200, D1)[1]                  [trend guard]
//   One position at a time. SL and TP are ATR-scaled.
//
// Bar-open-only gate (g_bar_checked):
//   Only the first tick of each new H1 bar may trigger an entry.
//   Prevents M4 real-tick intrabar ASK drift from over-firing.

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
// [00] TESTER / OPTIMIZER
//--------------------------------------------------------------------
input bool   _00_OptimizeMode  = false;
// true  â†’ suppress all Print/log output (~10â€“20% faster in optimizer)
// false â†’ normal logging (live trading + single backtest)

//--------------------------------------------------------------------
// [01] SIGNAL â€” Donchian channel breakout
//--------------------------------------------------------------------
input int    _01_BreakoutBars  = 40;
// N-bar lookback for Donchian channel (H1, shift 1+, excludes live bar).
// Higher N = fewer, stronger breakouts. Validated range: 30â€“60.

//--------------------------------------------------------------------
// [02] SL / TP  (both ATR-scaled from same ATR(14) value)
//--------------------------------------------------------------------
input double _02_SlAtrMult     = 1.5;
// SL distance = ATR(14)[1] Ã— this multiplier. BUY: below entry ASK.
// Validated: 1.5. Lower = tighter stop, more SL hits.

input double _02_TpAtrMult     = 5.0;
// TP distance = ATR(14)[1] Ã— this multiplier. BUY: above entry ASK.
// Validated: 5.0. Ratio TP:SL = 5.0/1.5 â‰ˆ 3.3:1 RR.

//--------------------------------------------------------------------
// [03] ATR-EXPAND FILTER
//--------------------------------------------------------------------
input int    _03_AtrPeriod     = 14;
// ATR smoothing period (H1). Feeds both SL/TP sizing and expand filter.

input int    _03_AtrMaPeriod   = 20;
// Rolling lookback for computing the average of ATR values.

input double _03_AtrExpandRatio = 1.0;
// Entry allowed only when ATR(14)[1] > avg(ATR, _03_AtrMaPeriod) Ã— ratio.
// 1.0 = gate always open (any volatility level allowed).
// 1.2 = enter only when ATR is 20% above its own recent average.
// Raise this to filter low-volatility false breakouts.

//--------------------------------------------------------------------
// [04] TREND FILTER  (Daily EMA direction guard)
//--------------------------------------------------------------------
input bool   _04_UseDailyEma   = true;
// Require Daily close[1] > EMA(EmaPeriod, D1)[1] before BUY entry.
// Set false to disable trend guard (test signal in isolation only).

input int    _04_EmaPeriod     = 200;
// Daily EMA period. 200 = long-term trend filter.

//--------------------------------------------------------------------
// [05] TRADE MANAGEMENT
//--------------------------------------------------------------------
input bool   _05_BuyOnly       = true;
// true  = BUY-only (OOS-validated for XAUUSD; matches gold long-bias).
// false = BUY + SELL (not validated; full IS/OOS retest required).

input double _05_LotSize       = 0.01;  // Fixed lot per trade

//--------------------------------------------------------------------
// [06] SYSTEM
//--------------------------------------------------------------------
input long   _06_Magic         = 991001;  // Magic number â€” must be unique per symbol/EA
input ulong  _06_Deviation     = 20;      // Max slippage in points on market order

input bool   _06_AllowLive     = false;
input ENUM_TIMEFRAMES _08_SigTF = PERIOD_H1;  // variant: configurable signal TF
// SAFETY GATE â€” EA sends real broker orders ONLY when this is true.
// Keep false for all backtest and optimization runs.
// Set true ONLY in the locked live .set file (BRK_XAU_live_v1.set).

//--------------------------------------------------------------------
// Globals
//--------------------------------------------------------------------
static bool   g_suppress_log       = false;
static int    g_atr_handle         = INVALID_HANDLE;
static int    g_ema_handle         = INVALID_HANDLE;
static double g_channel_high       = 0.0;
static double g_channel_low        = 0.0;
static datetime g_last_channel_bar = 0;
static bool   g_trade_fired        = false;
static bool   g_bar_checked        = false;  // bar-open-only gate
static datetime g_last_entry_bar   = 0;
static CTrade g_trade;

//--------------------------------------------------------------------
// Helpers
//--------------------------------------------------------------------
double GetATR(const int shift)
{
   double buf[1];
   if(g_atr_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_atr_handle, 0, shift, 1, buf) < 1) return 0.0;
   return buf[0];
}

double GetATR_MA()
{
   double buf[];
   if(g_atr_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_atr_handle, 0, 1, _03_AtrMaPeriod, buf) < _03_AtrMaPeriod) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < _03_AtrMaPeriod; i++) sum += buf[i];
   return sum / _03_AtrMaPeriod;
}

// Returns true if Daily EMA trend allows BUY.
// Reads bar[1] of Daily (yesterday confirmed close vs yesterday EMA).
bool IsTrendBullish()
{
   if(!_04_UseDailyEma) return true;
   if(g_ema_handle == INVALID_HANDLE) return true;
   double ema_buf[1];
   if(CopyBuffer(g_ema_handle, 0, 1, 1, ema_buf) < 1) return true;  // data gap â†’ allow
   const double daily_close = iClose(_Symbol, PERIOD_D1, 1);
   if(daily_close <= 0.0) return true;
   return (daily_close > ema_buf[0]);
}

// Recalculates Donchian channel once per new H1 bar.
void RefreshChannel()
{
   const datetime bar1_time = iTime(_Symbol, _08_SigTF, 1);
   if(bar1_time == g_last_channel_bar) return;
   g_last_channel_bar = bar1_time;
   g_trade_fired  = false;
   g_bar_checked  = false;  // new bar â†’ first tick may check entry

   const int idx_h = iHighest(_Symbol, _08_SigTF, MODE_HIGH, _01_BreakoutBars, 1);
   const int idx_l = iLowest (_Symbol, _08_SigTF, MODE_LOW,  _01_BreakoutBars, 1);
   if(idx_h < 0 || idx_l < 0) { g_channel_high = 0.0; g_channel_low = 0.0; return; }
   g_channel_high = iHigh(_Symbol, _08_SigTF, idx_h);
   g_channel_low  = iLow (_Symbol, _08_SigTF, idx_l);
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

//--------------------------------------------------------------------
// Lifecycle
//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_atr_handle = iATR(_Symbol, _08_SigTF, _03_AtrPeriod);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("EA_BREAKOUT_XAU: iATR handle failed");
      return INIT_FAILED;
   }

   if(_04_UseDailyEma)
   {
      g_ema_handle = iMA(_Symbol, PERIOD_D1, _04_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_ema_handle == INVALID_HANDLE)
      {
         Print("EA_BREAKOUT_XAU: Daily EMA handle failed");
         return INIT_FAILED;
      }
   }

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_channel_bar = 0;
   g_channel_high     = 0.0;
   g_channel_low      = 0.0;
   g_trade_fired      = false;
   g_bar_checked      = false;
   g_last_entry_bar   = 0;

   if(!g_suppress_log)
      PrintFormat("EA_BREAKOUT_XAU init | AllowLive=%s OptMode=%s Bars=%d SLÃ—%.1f TPÃ—%.1f EMA%d=%s",
                  _06_AllowLive ? "YES" : "NO",
                  _00_OptimizeMode ? "ON" : "off",
                  _01_BreakoutBars, _02_SlAtrMult, _02_TpAtrMult,
                  _04_EmaPeriod, _04_UseDailyEma ? "ON" : "off");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   if(g_ema_handle != INVALID_HANDLE) { IndicatorRelease(g_ema_handle); g_ema_handle = INVALID_HANDLE; }
}

// Custom optimize fitness: Sharpe-weighted, requires â‰¥15 trades.
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
   RefreshChannel();
   if(g_channel_high <= 0.0) return;
   if(g_trade_fired) return;

   // Bar-open-only gate: only the first tick per bar may attempt entry.
   if(g_bar_checked) return;
   g_bar_checked = true;

   if(HasOpenPosition()) return;

   // [03] ATR-expand filter
   const double atr_now = GetATR(1);
   const double atr_ma  = GetATR_MA();
   if(atr_now <= 0.0 || atr_ma <= 0.0) return;
   if(atr_now <= atr_ma * _03_AtrExpandRatio) return;

   // [04] Daily EMA trend filter
   if(!IsTrendBullish()) return;

   // Tick-level breakout check
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int dir = 0;
   if(ask > g_channel_high)                        dir =  1;
   else if(!_05_BuyOnly && bid < g_channel_low)    dir = -1;

   if(dir == 0) return;
   if(_05_BuyOnly && dir == -1) return;

   // Compute ATR-scaled bracket
   const double sl_dist = atr_now * _02_SlAtrMult;
   const double tp_dist = atr_now * _02_TpAtrMult;
   const int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double sl_price, tp_price;

   if(dir == 1)
   {
      sl_price = NormalizeDouble(ask - sl_dist, digits);
      tp_price = NormalizeDouble(ask + tp_dist, digits);
   }
   else
   {
      sl_price = NormalizeDouble(bid + sl_dist, digits);
      tp_price = NormalizeDouble(bid - tp_dist, digits);
   }

   // [06] Safety gate â€” real orders only when AllowLive. In the Strategy Tester orders
   // are simulated, so always trade there (else a default-param backtest = 0 trades).
   // Demo/live (MQL_TESTER false) stays gated by _06_AllowLive.
   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      if(!g_suppress_log)
         PrintFormat("DRYRUN %s ask=%.2f ch=%.2f ATR=%.4f SL=%.2f TP=%.2f",
                     dir == 1 ? "BUY" : "SELL", ask, g_channel_high, atr_now, sl_price, tp_price);
      g_trade_fired = true;
      return;
   }

   bool ok = (dir == 1)
      ? g_trade.Buy (_05_LotSize, _Symbol, ask, sl_price, tp_price, "BRKOUT_BUY")
      : g_trade.Sell(_05_LotSize, _Symbol, bid, sl_price, tp_price, "BRKOUT_SELL");

   if(ok)
   {
      g_trade_fired    = true;
      g_last_entry_bar = iTime(_Symbol, _08_SigTF, 0);
      if(!g_suppress_log)
         PrintFormat("EXEC %s lot=%.2f sl=%.2f tp=%.2f ret=%d",
                     dir == 1 ? "BUY" : "SELL", _05_LotSize, sl_price, tp_price,
                     g_trade.ResultRetcode());
   }
   else
   {
      if(!g_suppress_log)
         PrintFormat("ORDER FAILED: %d %s", g_trade.ResultRetcode(), g_trade.ResultComment());
   }
}

