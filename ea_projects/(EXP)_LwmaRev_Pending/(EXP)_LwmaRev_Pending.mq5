//+------------------------------------------------------------------+
//| (EXP)_LwmaRev_Pending.mq5                                        |
//| ORDER-091C-D1d / ORDER-080 — pending-limit vs market on a        |
//| REVERSION signal, in MT5 (user 2026-07-16: do it in MT5 for      |
//| easy test/optimize instead of porting the MT4 JUMSTOCH binary).  |
//| Clean naked LWMA mean-reversion + entry-mode toggle:             |
//|   market  : enter at current price (pays spread)                 |
//|   pending : buy/sell-LIMIT further from price (maker, no spread, |
//|             better fill) — but may not fill (fill-rate cost).    |
//| Measures the market-vs-pending EV delta + fill-rate on the SAME  |
//| signal. Answers the user's "ตั้ง pending ประหยัด spread" for the  |
//| reversion family (Thread A; break-retest = Thread B done).       |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_LwmaRev_Pending — LWMA reversion, market vs pending-limit A/B (MT5)"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode = false;

//--- [01] LWMA reversion signal
input int    _01_LwmaPeriod   = 34;
input int    _01_AtrPeriod    = 14;
input double _02_EntryDevAtr  = 1.5;   // enter when |close[1]-LWMA| > this × ATR (price stretched)

//--- [03] ENTRY MODE (the A/B lever)
input int    _03_EntryMode    = 0;     // 0 = market · 1 = pending-limit
input double _03_PendOffsetAtr = 0.5;  // pending placed this much FURTHER from price (deeper stretch)
input int    _03_ExpiryBars   = 5;     // pending lifetime (bars) then auto-cancel

//--- [04] bracket SL/TP (ATR-scaled, same for both modes)
input double _04_SlAtrMult    = 2.0;
input double _04_TpAtrMult    = 2.0;

//--- [05/06] trade / system
input double _05_LotSize      = 0.01;
input long   _06_Magic        = 991091;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

//--------------------------------------------------------------------
static bool     g_suppress_log = false;
static int      g_lwma_handle  = INVALID_HANDLE;
static int      g_atr_handle   = INVALID_HANDLE;
static datetime g_last_bar     = 0;
static CTrade   g_trade;

double Buf(const int handle, const int shift)
{
   double b[];
   if(handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(handle, 0, shift, 1, b) < 1) return 0.0;
   return b[0];
}

bool HasMyPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == _06_Magic)
         return true;
   }
   return false;
}

bool HasMyOrder()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      ulong t = OrderGetTicket(i);
      if(!OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == _06_Magic)
         return true;
   }
   return false;
}

int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_lwma_handle = iMA(_Symbol, PERIOD_CURRENT, _01_LwmaPeriod, 0, MODE_LWMA, PRICE_CLOSE);
   g_atr_handle  = iATR(_Symbol, PERIOD_CURRENT, _01_AtrPeriod);
   if(g_lwma_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
   { Print("LwmaRev: handle failed"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_lwma_handle != INVALID_HANDLE) IndicatorRelease(g_lwma_handle);
   if(g_atr_handle  != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
}

double OnTester()
{
   double t = TesterStatistics(STAT_TRADES);
   if(t < 15) return -1.0;
   double s = TesterStatistics(STAT_SHARPE_RATIO);
   return (s > 0 ? s : -1.0);
}

void OnTick()
{
   const datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur == g_last_bar) return;
   g_last_bar = cur;

   if(HasMyPosition()) return;
   if(_03_EntryMode == 1 && HasMyOrder()) return;   // pending still armed

   const double lwma = Buf(g_lwma_handle, 1);
   const double atr  = Buf(g_atr_handle, 1);
   if(lwma <= 0.0 || atr <= 0.0) return;
   const double c1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(c1 <= 0.0) return;

   const double dev = c1 - lwma;                    // >0 above LWMA (short-revert), <0 below (long-revert)
   int dir = 0;
   if(dev < -_02_EntryDevAtr * atr) dir = 1;        // stretched below → buy back to mean
   else if(dev > _02_EntryDevAtr * atr) dir = -1;   // stretched above → sell back to mean
   if(dir == 0) return;

   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;

   const int    digits  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = atr * _04_SlAtrMult;
   const double tp_dist = atr * _04_TpAtrMult;
   const double minstop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   if(_03_EntryMode == 0)
   {
      //--- MARKET entry (pays spread)
      if(dir == 1)
      {
         double sl = NormalizeDouble(ask - sl_dist, digits), tp = NormalizeDouble(ask + tp_dist, digits);
         g_trade.Buy(_05_LotSize, _Symbol, ask, sl, tp, "LWMAREV_MKT_B");
      }
      else
      {
         double sl = NormalizeDouble(bid + sl_dist, digits), tp = NormalizeDouble(bid - tp_dist, digits);
         g_trade.Sell(_05_LotSize, _Symbol, bid, sl, tp, "LWMAREV_MKT_S");
      }
   }
   else
   {
      //--- PENDING-LIMIT entry (maker, no spread, deeper stretch; may not fill)
      const datetime exp = (datetime)(TimeCurrent() + (long)_03_ExpiryBars * PeriodSeconds(PERIOD_CURRENT));
      if(dir == 1)
      {
         double px = NormalizeDouble(ask - _03_PendOffsetAtr * atr, digits);   // buy-limit below market
         if(px < ask - minstop)
         {
            double sl = NormalizeDouble(px - sl_dist, digits), tp = NormalizeDouble(px + tp_dist, digits);
            g_trade.BuyLimit(_05_LotSize, px, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, exp, "LWMAREV_PEND_B");
         }
      }
      else
      {
         double px = NormalizeDouble(bid + _03_PendOffsetAtr * atr, digits);   // sell-limit above market
         if(px > bid + minstop)
         {
            double sl = NormalizeDouble(px + sl_dist, digits), tp = NormalizeDouble(px - tp_dist, digits);
            g_trade.SellLimit(_05_LotSize, px, _Symbol, sl, tp, ORDER_TIME_SPECIFIED, exp, "LWMAREV_PEND_S");
         }
      }
   }
}
