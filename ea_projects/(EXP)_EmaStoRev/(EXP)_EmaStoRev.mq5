//+------------------------------------------------------------------+
//| (EXP)_EmaStoRev.mq5                                              |
//| ORDER-107 Stage-0 — SMC×STO skeleton (user idea 2026-07-16)      |
//| STRIP the SMC/OB zone (expensive) — test the CHEAP core first:   |
//|   HTF EMA gate (direction) + Stochastic cross from extreme       |
//|   (reversion entry) + STO-reverse exit + breakeven at STO 50.    |
//| If this naked skeleton has no edge, an OB zone won't save it      |
//| (a zone only LOCATES the same reversion entry). Cheap death test.|
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_EmaStoRev — ORDER-107 SMC×STO Stage-0 skeleton (no OB zone)"

#include <Trade\Trade.mqh>

//--- [00] tester/opt
input bool   _00_OptimizeMode = false;

//--- [01] HTF EMA direction gate (buy-only above, sell-only below)
input ENUM_TIMEFRAMES _01_EmaTF   = PERIOD_H1;   // higher-TF bias (SMC used M15/H1)
input int    _01_EmaPeriod        = 100;

//--- [02] Stochastic (trading TF) — the reversion trigger
input int    _02_StoK             = 5;
input int    _02_StoD             = 3;
input int    _02_StoSlow          = 3;
input double _02_OverSold         = 20.0;   // buy: %K crosses up %D while below this
input double _02_OverBought       = 80.0;   // sell: %K crosses down %D while above this
input double _02_BEatLevel        = 50.0;   // move SL to breakeven when STO reaches this in favor

//--- [03] risk
input double _03_SlAtrMult        = 2.0;
input int    _03_AtrPeriod        = 14;
input double _03_TpAtrMult        = 0.0;    // 0 = no fixed TP (exit is STO-reverse). >0 = ATR TP cap

//--- [08] ADX regime filter (user idea — cut counter-trend losers; additive, default OFF)
input bool   _08_UseAdxFilter     = false;  // true = only enter reversion when trend is weak (ADX < max)
input int    _08_AdxPeriod        = 14;
input double _08_AdxMax           = 25.0;   // block entry when ADX[1] >= this (strong trend = don't fade it)

//--- [05] trade
input double _05_LotSize          = 0.01;

//--- [06] system
input long   _06_Magic            = 991070;
input ulong  _06_Deviation        = 20;
input bool   _06_AllowLive        = false;

//--------------------------------------------------------------------
static bool     g_suppress_log   = false;
static int      g_adx_handle     = INVALID_HANDLE;
static int      g_sto_handle     = INVALID_HANDLE;
static int      g_ema_handle     = INVALID_HANDLE;
static int      g_atr_handle     = INVALID_HANDLE;
static datetime g_last_bar       = 0;
static CTrade   g_trade;

//--------------------------------------------------------------------
bool StoAt(const int shift, double &k, double &d)
{
   double bk[], bd[];
   if(g_sto_handle == INVALID_HANDLE) return false;
   if(CopyBuffer(g_sto_handle, 0, shift, 1, bk) < 1) return false;  // MAIN = %K
   if(CopyBuffer(g_sto_handle, 1, shift, 1, bd) < 1) return false;  // SIGNAL = %D
   k = bk[0]; d = bd[0];
   return true;
}

double EmaAt(const int shift)
{
   double b[];
   if(g_ema_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_ema_handle, 0, shift, 1, b) < 1) return 0.0;
   return b[0];
}

double AtrAt(const int shift)
{
   double b[];
   if(g_atr_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_atr_handle, 0, shift, 1, b) < 1) return 0.0;
   return b[0];
}

// direction from HTF EMA: +1 buy-allowed, -1 sell-allowed, 0 none
int TrendDir()
{
   const double ema = EmaAt(1);
   if(ema <= 0.0) return 0;
   const double c = iClose(_Symbol, _01_EmaTF, 1);
   if(c <= 0.0) return 0;
   return (c > ema) ? 1 : -1;
}

bool GetMyPosition(ulong &ticket, long &type, double &open_price, double &sl)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      ticket = t;
      type = PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      return true;
   }
   return false;
}

//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   g_sto_handle = iStochastic(_Symbol, PERIOD_CURRENT, _02_StoK, _02_StoD, _02_StoSlow, MODE_SMA, STO_LOWHIGH);
   g_ema_handle = iMA(_Symbol, _01_EmaTF, _01_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _03_AtrPeriod);
   if(g_sto_handle == INVALID_HANDLE || g_ema_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
   { Print("EmaStoRev: indicator handle failed"); return INIT_FAILED; }

   if(_08_UseAdxFilter)
   {
      g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, _08_AdxPeriod);
      if(g_adx_handle == INVALID_HANDLE) { Print("EmaStoRev: iADX handle failed"); return INIT_FAILED; }
   }

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_sto_handle != INVALID_HANDLE) IndicatorRelease(g_sto_handle);
   if(g_ema_handle != INVALID_HANDLE) IndicatorRelease(g_ema_handle);
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
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
   // bar-open gate (signal + exit evaluated on closed bars — no intrabar repaint)
   const datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur == g_last_bar) return;
   g_last_bar = cur;

   double k1, d1, k2, d2;
   if(!StoAt(1, k1, d1) || !StoAt(2, k2, d2)) return;

   //--- manage an open position first (BE + STO-reverse exit)
   ulong ticket; long ptype; double popen, psl;
   if(GetMyPosition(ticket, ptype, popen, psl))
   {
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(ptype == POSITION_TYPE_BUY)
      {
         // breakeven when STO reaches BE level in favor and price is above entry
         if(k1 >= _02_BEatLevel && psl < popen && bid > popen)
            g_trade.PositionModify(ticket, NormalizeDouble(popen, digits), PositionGetDouble(POSITION_TP));
         // exit: %K crosses DOWN %D while in overbought (opposite extreme + cross-back)
         if(k2 >= d2 && k1 < d1 && k1 >= _02_OverBought)
            g_trade.PositionClose(ticket);
      }
      else // SELL
      {
         if(k1 <= (100.0 - _02_BEatLevel) && (psl > popen || psl == 0.0) && ask < popen)
            g_trade.PositionModify(ticket, NormalizeDouble(popen, digits), PositionGetDouble(POSITION_TP));
         if(k2 <= d2 && k1 > d1 && k1 <= _02_OverSold)
            g_trade.PositionClose(ticket);
      }
      return; // one position at a time — no new entry while in a trade
   }

   //--- entry
   const int dir = TrendDir();
   if(dir == 0) return;

   // [08] ADX regime filter — skip reversion entries when the trend is too strong to fade
   if(_08_UseAdxFilter && g_adx_handle != INVALID_HANDLE)
   {
      double adx[];
      if(CopyBuffer(g_adx_handle, 0, 1, 1, adx) < 1) return;   // data gap → skip (conservative)
      if(adx[0] >= _08_AdxMax) return;                          // strong trend → don't fade
   }

   const double atr = AtrAt(1);
   if(atr <= 0.0) return;

   bool buy_sig  = (dir == 1)  && (k2 <= d2 && k1 > d1) && (k1 < _02_OverSold);      // cross up in oversold
   bool sell_sig = (dir == -1) && (k2 >= d2 && k1 < d1) && (k1 > _02_OverBought);    // cross down in overbought
   if(!buy_sig && !sell_sig) return;

   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl_dist = atr * _03_SlAtrMult;
   const double tp_dist = (_03_TpAtrMult > 0.0) ? atr * _03_TpAtrMult : 0.0;

   if(buy_sig)
   {
      double sl = NormalizeDouble(ask - sl_dist, digits);
      double tp = (tp_dist > 0.0) ? NormalizeDouble(ask + tp_dist, digits) : 0.0;
      g_trade.Buy(_05_LotSize, _Symbol, ask, sl, tp, "EMASTO_BUY");
   }
   else
   {
      double sl = NormalizeDouble(bid + sl_dist, digits);
      double tp = (tp_dist > 0.0) ? NormalizeDouble(bid - tp_dist, digits) : 0.0;
      g_trade.Sell(_05_LotSize, _Symbol, bid, sl, tp, "EMASTO_SELL");
   }
}
