//+------------------------------------------------------------------+
//| (EXP)_StoMultiTap.mq5                                            |
//| ORDER-133 — Multi-tap S/R + Stochastic cycle fade                |
//|   (แกะจาก Miissterkiiss/Bitnefit "กราฟไม่ง้อเซียน 3" school)      |
//|                                                                  |
//| Core = fade a swing-pivot S/R zone, but ONLY after the zone has  |
//| been RE-TESTED across >= MinTaps Stochastic OB/OS "rounds"       |
//| (never the first touch). A "round" = Stoch entering the extreme  |
//| at the zone, then leaving it (%K back through 50) before the     |
//| next one counts. NOVEL LEVER for the portfolio = MinTaps: the    |
//| Bitnefit "นับรอบ STO ที่แนวเดิม" idea encoded mechanically.       |
//|                                                                  |
//| MinTaps=1 = control cell (== plain first-touch reversion, the    |
//| SMC×STO family). If MinTaps=2 does not beat MinTaps=1, the lever  |
//| has no value — designed to falsify itself at smoke.              |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_StoMultiTap — ORDER-133 multi-tap S/R + Stoch cycle fade (reversion, naked L1)"

#include <Trade\Trade.mqh>

//--- [00] tester/opt
input bool   _00_OptimizeMode  = false;

//--- [01] S/R zone (swing-pivot fractal)
input int    _01_SwingStrength = 5;     // fractal left/right bars (5/5 ~ Miissterkiiss แนวตีมือ)
input double _01_ZoneTolAtr    = 0.25;  // zone half-band = this * ATR around the pivot
input double _01_BreakAtr      = 0.5;   // close beyond zone by this*ATR = level broken (reset)

//--- [02] Stochastic (trading TF) — the cycle/round trigger
input int    _02_StoK          = 9;     // Miissterkiiss uses Stoch(9,3,3)
input int    _02_StoD          = 3;
input int    _02_StoSlow       = 3;
input double _02_OverSold      = 20.0;
input double _02_OverBought    = 80.0;

//--- [03] MULTI-TAP lever (the novelty) + MTF confirm
input int    _03_MinTaps       = 2;     // 🔴 rounds required before arming (1 = first-touch control)
input bool   _03_UseMtf        = true;  // higher-TF Stoch must agree
input ENUM_TIMEFRAMES _03_MtfTF = PERIOD_H1; // set to ~4x the chart TF
input double _03_MtfSellMin    = 60.0;  // SELL: HTF %K must be >= this
input double _03_MtfBuyMax     = 40.0;  // BUY : HTF %K must be <= this

//--- [04] risk / exit
input int    _04_AtrPeriod     = 14;
input double _04_SlBufAtr      = 0.5;   // SL beyond the zone extreme by this*ATR
input double _04_RR            = 1.5;   // TP = RR * risk (fade back into range)

//--- [08] ADX regime filter (additive, default OFF — SMC×STO lesson)
input bool   _08_UseAdxFilter  = false;
input int    _08_AdxPeriod     = 14;
input double _08_AdxMax        = 25.0;  // block entry when ADX[1] >= this (too trendy to fade)

//--- [05] trade
input double _05_LotSize       = 0.01;

//--- [06] system
input long   _06_Magic         = 991075;   // lab-only (SMC×STO live-demo = 991070, DO NOT collide)
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;

//--------------------------------------------------------------------
static bool     g_suppress_log = false;
static int      g_sto_handle   = INVALID_HANDLE;
static int      g_mtf_handle   = INVALID_HANDLE;
static int      g_atr_handle   = INVALID_HANDLE;
static int      g_adx_handle   = INVALID_HANDLE;
static datetime g_last_bar     = 0;
static CTrade   g_trade;

//--- active resistance zone (fade SELL)
static bool     g_res_active   = false;
static double   g_res_hi       = 0.0;   // upper band
static double   g_res_lo       = 0.0;   // lower band (price "reaches" the zone here)
static int      g_res_taps     = 0;
static bool     g_res_inRound  = false;

//--- active support zone (fade BUY)
static bool     g_sup_active   = false;
static double   g_sup_hi       = 0.0;   // upper band (price "reaches" the zone here)
static double   g_sup_lo       = 0.0;   // lower band
static int      g_sup_taps     = 0;
static bool     g_sup_inRound  = false;

//--------------------------------------------------------------------
bool StoAt(const int handle, const int shift, double &k, double &d)
{
   double bk[], bd[];
   if(handle == INVALID_HANDLE) return false;
   if(CopyBuffer(handle, 0, shift, 1, bk) < 1) return false; // MAIN = %K
   if(CopyBuffer(handle, 1, shift, 1, bd) < 1) return false; // SIGNAL = %D
   k = bk[0]; d = bd[0];
   return true;
}

double AtrAt(const int shift)
{
   double b[];
   if(g_atr_handle == INVALID_HANDLE) return 0.0;
   if(CopyBuffer(g_atr_handle, 0, shift, 1, b) < 1) return 0.0;
   return b[0];
}

// confirmed fractal at shift s (strength bars each side, all closed)
bool IsFractalHigh(const int s)
{
   const double h = iHigh(_Symbol, PERIOD_CURRENT, s);
   if(h <= 0.0) return false;
   for(int j = 1; j <= _01_SwingStrength; j++)
   {
      if(iHigh(_Symbol, PERIOD_CURRENT, s - j) >= h) return false; // right side (newer)
      if(iHigh(_Symbol, PERIOD_CURRENT, s + j) >  h) return false; // left side (older)
   }
   return true;
}
bool IsFractalLow(const int s)
{
   const double l = iLow(_Symbol, PERIOD_CURRENT, s);
   if(l <= 0.0) return false;
   for(int j = 1; j <= _01_SwingStrength; j++)
   {
      if(iLow(_Symbol, PERIOD_CURRENT, s - j) <= l) return false;
      if(iLow(_Symbol, PERIOD_CURRENT, s + j) <  l) return false;
   }
   return true;
}

bool GetMyPosition(ulong &ticket, long &type)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != _06_Magic) continue;
      ticket = t;
      type = PositionGetInteger(POSITION_TYPE);
      return true;
   }
   return false;
}

//--------------------------------------------------------------------
int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);

   if(_01_SwingStrength < 1) { Print("StoMultiTap: SwingStrength must be >=1"); return INIT_FAILED; }
   if(_03_MinTaps < 1)       { Print("StoMultiTap: MinTaps must be >=1"); return INIT_FAILED; }

   g_sto_handle = iStochastic(_Symbol, PERIOD_CURRENT, _02_StoK, _02_StoD, _02_StoSlow, MODE_SMA, STO_LOWHIGH);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _04_AtrPeriod);
   if(g_sto_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
   { Print("StoMultiTap: indicator handle failed"); return INIT_FAILED; }

   if(_03_UseMtf)
   {
      g_mtf_handle = iStochastic(_Symbol, _03_MtfTF, _02_StoK, _02_StoD, _02_StoSlow, MODE_SMA, STO_LOWHIGH);
      if(g_mtf_handle == INVALID_HANDLE) { Print("StoMultiTap: MTF Stoch handle failed"); return INIT_FAILED; }
   }
   if(_08_UseAdxFilter)
   {
      g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, _08_AdxPeriod);
      if(g_adx_handle == INVALID_HANDLE) { Print("StoMultiTap: iADX handle failed"); return INIT_FAILED; }
   }

   g_trade.SetExpertMagicNumber(_06_Magic);
   g_trade.SetDeviationInPoints(_06_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar = 0;
   g_res_active = false; g_res_taps = 0; g_res_inRound = false;
   g_sup_active = false; g_sup_taps = 0; g_sup_inRound = false;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_sto_handle != INVALID_HANDLE) IndicatorRelease(g_sto_handle);
   if(g_mtf_handle != INVALID_HANDLE) IndicatorRelease(g_mtf_handle);
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
   // bar-open gate (signal + management on closed bars — no intrabar repaint)
   const datetime cur = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur == g_last_bar) return;
   g_last_bar = cur;

   double k1, d1, k2, d2;
   if(!StoAt(g_sto_handle, 1, k1, d1) || !StoAt(g_sto_handle, 2, k2, d2)) return;
   const double atr = AtrAt(1);
   if(atr <= 0.0) return;

   //--- manage an open position first (RR TP/SL are fixed at entry; exit also on opposite Stoch cross)
   ulong ticket; long ptype;
   if(GetMyPosition(ticket, ptype))
   {
      if(ptype == POSITION_TYPE_BUY)
      {
         if(k2 >= d2 && k1 < d1 && k1 >= _02_OverBought) g_trade.PositionClose(ticket); // reached opposite extreme
      }
      else
      {
         if(k2 <= d2 && k1 > d1 && k1 <= _02_OverSold)   g_trade.PositionClose(ticket);
      }
      return; // one position at a time
   }

   //--- (1) update S/R zones from the newest confirmed fractal
   const int fs = _01_SwingStrength + 1; // shift of a just-confirmed fractal
   const double tol = _01_ZoneTolAtr * atr;

   if(IsFractalHigh(fs))
   {
      const double p = iHigh(_Symbol, PERIOD_CURRENT, fs);
      // fresh zone only if none active or the pivot is outside the current band (else keep counting taps)
      if(!g_res_active || p > g_res_hi || p < g_res_lo)
      {
         g_res_active = true; g_res_hi = p + tol; g_res_lo = p - tol;
         g_res_taps = 0; g_res_inRound = false;
      }
   }
   if(IsFractalLow(fs))
   {
      const double p = iLow(_Symbol, PERIOD_CURRENT, fs);
      if(!g_sup_active || p > g_sup_hi || p < g_sup_lo)
      {
         g_sup_active = true; g_sup_hi = p + tol; g_sup_lo = p - tol;
         g_sup_taps = 0; g_sup_inRound = false;
      }
   }

   const double hi1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   const double lo1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   const double cl1 = iClose(_Symbol, PERIOD_CURRENT, 1);

   //--- (2) resistance: invalidate on break-up, else count OB rounds at the zone
   bool sell_arm = false;
   if(g_res_active)
   {
      if(cl1 > g_res_hi + _01_BreakAtr * atr) { g_res_active = false; }
      else
      {
         const bool atZone = (hi1 >= g_res_lo);           // price reached into the resistance band
         if(atZone && k1 >= _02_OverBought && !g_res_inRound)
         { g_res_inRound = true; g_res_taps++; }          // count ONE round on entry into OB-at-zone
         if(k1 < 50.0) g_res_inRound = false;             // round must fully cycle out before the next
         sell_arm = (g_res_taps >= _03_MinTaps);
      }
   }

   //--- (3) support: invalidate on break-down, else count OS rounds at the zone
   bool buy_arm = false;
   if(g_sup_active)
   {
      if(cl1 < g_sup_lo - _01_BreakAtr * atr) { g_sup_active = false; }
      else
      {
         const bool atZone = (lo1 <= g_sup_hi);
         if(atZone && k1 <= _02_OverSold && !g_sup_inRound)
         { g_sup_inRound = true; g_sup_taps++; }
         if(k1 > 50.0) g_sup_inRound = false;
         buy_arm = (g_sup_taps >= _03_MinTaps);
      }
   }

   //--- (4) trigger = Stoch cross back at the armed zone
   bool sell_sig = sell_arm && (k2 >= d2 && k1 < d1) && (k1 >= _02_OverBought);
   bool buy_sig  = buy_arm  && (k2 <= d2 && k1 > d1) && (k1 <= _02_OverSold);
   if(!sell_sig && !buy_sig) return;

   //--- (5) MTF Stoch confirm
   if(_03_UseMtf)
   {
      double mk, md;
      if(!StoAt(g_mtf_handle, 1, mk, md)) return;  // data gap → skip (conservative)
      if(sell_sig && mk < _03_MtfSellMin) return;
      if(buy_sig  && mk > _03_MtfBuyMax)  return;
   }

   //--- (6) ADX regime filter — don't fade a strong trend
   if(_08_UseAdxFilter && g_adx_handle != INVALID_HANDLE)
   {
      double adx[];
      if(CopyBuffer(g_adx_handle, 0, 1, 1, adx) < 1) return;
      if(adx[0] >= _08_AdxMax) return;
   }

   const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
   if(!allow) return;

   const int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double buf = _04_SlBufAtr * atr;

   if(sell_sig)
   {
      const double sl_price = g_res_hi + buf;            // SL beyond the zone extreme
      const double risk     = sl_price - bid;
      if(risk <= 0.0) return;
      const double tp_price = bid - _04_RR * risk;       // TP back into range
      g_trade.Sell(_05_LotSize, _Symbol, bid,
                   NormalizeDouble(sl_price, digits),
                   NormalizeDouble(tp_price, digits), "STMT_SELL");
      g_res_active = false;                              // consume the zone after entry
   }
   else // buy_sig
   {
      const double sl_price = g_sup_lo - buf;
      const double risk     = ask - sl_price;
      if(risk <= 0.0) return;
      const double tp_price = ask + _04_RR * risk;
      g_trade.Buy(_05_LotSize, _Symbol, ask,
                  NormalizeDouble(sl_price, digits),
                  NormalizeDouble(tp_price, digits), "STMT_BUY");
      g_sup_active = false;
   }
}
