//+------------------------------------------------------------------+
//| (EXP)_BRK_SplitRetest.mq5                                        |
//| ORDER-108 — break-and-retest split entry (user idea 2026-07-16)  |
//| Base = EA_BREAKOUT_XAU (Donchian BUY-only). Signal/SL/TP/filters  |
//| IDENTICAL to base — the ONLY change is entry STRUCTURE:           |
//|   baseline  : one market order at ASK (UseSplitEntry=false)       |
//|   split     : market leg (MarketLot) at ASK + pending buy-limit   |
//|               leg (PendingLot) at the broken level (retest),      |
//|               expiry ExpiryBars                                   |
//|   pending-only: MarketLot=0 -> only the retest limit             |
//| Purpose: measure whether catching the retest at a maker price     |
//| (no spread, tighter SL) lifts EV/signal vs pure market entry,     |
//| WITHOUT losing the runaway breakouts (that's what the market leg  |
//| is for — adverse-selection guard).                                |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_BRK_SplitRetest — ORDER-108 break-retest split entry probe"

// Entry (bar-open-only, first tick per H1 bar) — signal identical to base:
//   BUY when ASK > Donchian high(N)[1+]  AND  ATR(14)[1] > avg(ATR,20)×ratio  AND  D1 close[1] > EMA(200,D1)[1]
// Split adds a pending buy-limit at the broken channel-high (retest), same ATR SL/TP measured from its fill price.

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
input bool   _00_OptimizeMode  = false;

//--- [01] SIGNAL — Donchian breakout (identical to base)
input int    _01_BreakoutBars  = 40;

//--- [02] SL / TP (ATR-scaled, identical to base)
input double _02_SlAtrMult     = 1.5;
input double _02_TpAtrMult     = 5.0;

//--- [03] ATR-expand filter (identical)
input int    _03_AtrPeriod     = 14;
input int    _03_AtrMaPeriod   = 20;
input double _03_AtrExpandRatio = 1.0;

//--- [04] Daily EMA trend guard (identical)
input bool   _04_UseDailyEma   = true;
input int    _04_EmaPeriod     = 200;

//--- [05] Trade management (identical)
input bool   _05_BuyOnly       = true;
input double _05_LotSize       = 0.01;   // used ONLY when _07_UseSplitEntry=false (baseline)

//--- [06] System
input long   _06_Magic         = 991008;  // distinct from live BRK-XAU 991001
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;

//--- [07] SPLIT-RETEST ENTRY (the ORDER-108 lever — additive, default OFF)
input bool   _07_UseSplitEntry   = false; // false = baseline market-only (byte-behaviour of base EA)
input double _07_MarketLot        = 0.02; // market leg (catches runaway breakouts). 0 = pending-only mode
input double _07_PendingLot       = 0.01; // pending buy-limit leg at the retest level. 0 = market-only
input double _07_RetestOffsetAtr  = 0.0;  // limit = channel_high + offset×ATR. <0 = deeper retest (fills less, better price)
input int    _07_ExpiryBars       = 5;    // pending order lifetime in H1 bars, then auto-cancels

//--------------------------------------------------------------------
static bool     g_suppress_log     = false;
static int      g_atr_handle       = INVALID_HANDLE;
static int      g_ema_handle       = INVALID_HANDLE;
static double   g_channel_high     = 0.0;
static double   g_channel_low      = 0.0;
static datetime g_last_channel_bar = 0;
static bool     g_trade_fired      = false;
static bool     g_bar_checked      = false;
static datetime g_last_entry_bar   = 0;
static CTrade   g_trade;

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

bool IsTrendBullish()
{
   if(!_04_UseDailyEma) return true;
   if(g_ema_handle == INVALID_HANDLE) return true;
   double ema_buf[1];
   if(CopyBuffer(g_ema_handle, 0, 1, 1, ema_buf) < 1) return true;
   const double daily_close = iClose(_Symbol, PERIOD_D1, 1);
   if(daily_close <= 0.0) return true;
   return (daily_close > ema_buf[0]);
}

void RefreshChannel()
{
   const datetime bar1_time = iTime(_Symbol, PERIOD_H1, 1);
   if(bar1_time == g_last_channel_bar) return;
   g_last_channel_bar = bar1_time;
   g_trade_fired  = false;
   g_bar_checked  = false;

   const int idx_h = iHighest(_Symbol, PERIOD_H1, MODE_HIGH, _01_BreakoutBars, 1);
   const int idx_l = iLowest (_Symbol, PERIOD_H1, MODE_LOW,  _01_BreakoutBars, 1);
   if(idx_h < 0 || idx_l < 0) { g_channel_high = 0.0; g_channel_low = 0.0; return; }
   g_channel_high = iHigh(_Symbol, PERIOD_H1, idx_h);
   g_channel_low  = iLow (_Symbol, PERIOD_H1, idx_l);
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

// A live pending order (our magic) means a retest leg is still armed — do not re-fire.
bool HasPendingOrder()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         OrderGetInteger(ORDER_MAGIC) == _06_Magic)
         return true;
   }
   return false;
}

//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_atr_handle = iATR(_Symbol, PERIOD_H1, _03_AtrPeriod);
   if(g_atr_handle == INVALID_HANDLE) { Print("BRK_SplitRetest: iATR handle failed"); return INIT_FAILED; }

   if(_04_UseDailyEma)
   {
      g_ema_handle = iMA(_Symbol, PERIOD_D1, _04_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_ema_handle == INVALID_HANDLE) { Print("BRK_SplitRetest: Daily EMA handle failed"); return INIT_FAILED; }
   }

   // Split dual-leg (market buy + limit buy) needs HEDGING — on a netting account the two
   // buy legs merge into one aggregated position and the second SL/TP overwrites the first,
   // destroying the intended two-leg structure. Guard only when BOTH legs are live.
   if(_07_UseSplitEntry && _07_MarketLot > 0.0 && _07_PendingLot > 0.0)
   {
      if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         Print("BRK_SplitRetest: split dual-leg requires a HEDGING account (netting merges the two buy legs)");
         return INIT_FAILED;
      }
   }

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   g_last_channel_bar = 0; g_channel_high = 0.0; g_channel_low = 0.0;
   g_trade_fired = false;  g_bar_checked = false; g_last_entry_bar = 0;

   if(!g_suppress_log)
      PrintFormat("BRK_SplitRetest init | AllowLive=%s Split=%s mkt=%.2f pend=%.2f off=%.2f exp=%dbar Bars=%d",
                  _06_AllowLive ? "YES" : "NO", _07_UseSplitEntry ? "ON" : "off",
                  _07_MarketLot, _07_PendingLot, _07_RetestOffsetAtr, _07_ExpiryBars, _01_BreakoutBars);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   if(g_ema_handle != INVALID_HANDLE) { IndicatorRelease(g_ema_handle); g_ema_handle = INVALID_HANDLE; }
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 15) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}

//--------------------------------------------------------------------
void OnTick()
{
   RefreshChannel();
   if(g_channel_high <= 0.0) return;
   if(g_trade_fired) return;

   if(g_bar_checked) return;
   g_bar_checked = true;

   if(HasOpenPosition()) return;
   if(_07_UseSplitEntry && HasPendingOrder()) return;  // retest leg still armed

   const double atr_now = GetATR(1);
   const double atr_ma  = GetATR_MA();
   if(atr_now <= 0.0 || atr_ma <= 0.0) return;
   if(atr_now <= atr_ma * _03_AtrExpandRatio) return;

   if(!IsTrendBullish()) return;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   int dir = 0;
   if(ask > g_channel_high)                     dir =  1;
   else if(!_05_BuyOnly && bid < g_channel_low) dir = -1;
   if(dir == 0) return;
   if(_05_BuyOnly && dir == -1) return;

   const double sl_dist = atr_now * _02_SlAtrMult;
   const double tp_dist = atr_now * _02_TpAtrMult;
   const int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double sl_price, tp_price;
   if(dir == 1) { sl_price = NormalizeDouble(ask - sl_dist, digits); tp_price = NormalizeDouble(ask + tp_dist, digits); }
   else         { sl_price = NormalizeDouble(bid + sl_dist, digits); tp_price = NormalizeDouble(bid - tp_dist, digits); }

   // Safety gate — real orders only when AllowLive; tester always simulates.
   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow)
   {
      if(!g_suppress_log)
         PrintFormat("DRYRUN %s ask=%.2f ch=%.2f ATR=%.4f", dir==1?"BUY":"SELL", ask, g_channel_high, atr_now);
      g_trade_fired = true;
      return;
   }

   //--- SPLIT-RETEST path (BUY breakout only) ---
   if(_07_UseSplitEntry && dir == 1)
   {
      bool any = false;

      // market leg — catches the runaway breakouts that never retest (adverse-selection guard)
      if(_07_MarketLot > 0.0)
      {
         if(g_trade.Buy(_07_MarketLot, _Symbol, ask, sl_price, tp_price, "BRK_MKT"))
            any = true;
         else if(!g_suppress_log)
            PrintFormat("MKT leg FAILED: %d %s", g_trade.ResultRetcode(), g_trade.ResultComment());
      }

      // pending buy-limit leg at the broken level (retest) — maker fill, no spread, tighter SL
      if(_07_PendingLot > 0.0)
      {
         const double minstop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
         double limit_price = NormalizeDouble(g_channel_high + _07_RetestOffsetAtr * atr_now, digits);
         // a valid BUY-LIMIT must sit below current ask (with broker min-stop room); else no room for a retest entry
         if(limit_price < ask - minstop)
         {
            const double p_sl = NormalizeDouble(limit_price - sl_dist, digits);
            const double p_tp = NormalizeDouble(limit_price + tp_dist, digits);
            const datetime exp = (datetime)(TimeCurrent() + (long)_07_ExpiryBars * PeriodSeconds(PERIOD_H1));
            if(g_trade.BuyLimit(_07_PendingLot, limit_price, _Symbol, p_sl, p_tp, ORDER_TIME_SPECIFIED, exp, "BRK_RETEST"))
               any = true;
            else if(!g_suppress_log)
               PrintFormat("PEND leg FAILED: %d %s", g_trade.ResultRetcode(), g_trade.ResultComment());
         }
         else if(!g_suppress_log)
            PrintFormat("PEND skipped: limit %.2f not below ask %.2f - minstop", limit_price, ask);
      }

      if(any) { g_trade_fired = true; g_last_entry_bar = iTime(_Symbol, PERIOD_H1, 0); }
      return;
   }

   //--- BASELINE path (market-only; identical to base EA) ---
   bool ok = (dir == 1)
      ? g_trade.Buy (_05_LotSize, _Symbol, ask, sl_price, tp_price, "BRKOUT_BUY")
      : g_trade.Sell(_05_LotSize, _Symbol, bid, sl_price, tp_price, "BRKOUT_SELL");

   if(ok)
   {
      g_trade_fired    = true;
      g_last_entry_bar = iTime(_Symbol, PERIOD_H1, 0);
   }
   else if(!g_suppress_log)
      PrintFormat("ORDER FAILED: %d %s", g_trade.ResultRetcode(), g_trade.ResultComment());
}
