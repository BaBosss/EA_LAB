//+------------------------------------------------------------------+
//| (TRND)_TsMom_XAU_rev01.mq5                                        |
//|                                                                    |
//| S2 — D1 Time-Series Momentum (TSMOM). Absolute multi-month        |
//| momentum in gold: enter long when Close is above its value N bars |
//| ago AND above SMA100; short on the mirror. A dead-zone (|mom| <   |
//| 1*ATR) skips weak signals. One position, flip on reversal. Exit   |
//| = wide 3*ATR(D1) stop + Chandelier trail 3*ATR from the best      |
//| close since entry (no fixed TP). Edge = slow under-reaction to    |
//| macro regime shifts (real yields / CB+ETF flows); huge stops make |
//| it cost-immune vs a 20-35pt spread. Distinct from any pullback or |
//| session EA: the signal IS the multi-month momentum sign.          |
//|                                                                    |
//| L1: single position, real ATR SL + Chandelier trail, fixed lot,   |
//| bar-open gated, magic-scoped, hard caps. No grid/basket/martingale|
//| Magic 992001. Home = XAUUSD. Smoke on D1 MAIN before any funnel.  |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_TsMom_XAU_rev01 — D1 time-series momentum, single-position, ATR stop + Chandelier trail"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] MOMENTUM SIGNAL ───────────────────";
input int    _01_MomLookback  = 60;    // Close[1] vs Close[1+this]  (multi-month TSMOM)
input int    _01_SmaPeriod    = 100;   // trend confirm: price vs SMA
input int    _01_AtrPeriod    = 20;    // ATR for dead-zone + stops
input double _01_DeadAtrMult  = 1.0;   // skip if |momentum| < this * ATR (weak-signal filter)

input string _g01b_           = "── [01b] REGIME GATE (last-optimize lever) ";
input bool   _01_UseAdxGate   = false; // default OFF = byte-identical to rev01 baseline
input int    _01_AdxPeriod    = 14;
input double _01_AdxMin        = 25.0;  // when gate ON: enter only if ADX >= this (trend present)

input string _g02_            = "── [02] STOP / TRAIL ──────────────────────";
input double _02_SlAtrMult    = 3.0;   // initial hard stop = this * ATR
input double _02_TrailAtrMult = 3.0;   // Chandelier trail = bestClose -/+ this * ATR

input string _g03_            = "── [03] TRADE MGMT ────────────────────────";
input bool   _03_BuyOk        = true;
input bool   _03_SellOk       = true;
input double _03_LotSize      = 0.01;

input string _g04_            = "── [04] RISK CAPS ─────────────────────────";
input double _04_DailyLossPct = 5.0;
input double _04_EmergencyDdPct = 25.0;

input string _g05_            = "── [05] SYSTEM ────────────────────────────";
input long   _05_Magic        = 992001;
input ulong  _05_Deviation    = 20;
input bool   _05_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_sma=INVALID_HANDLE, g_atr=INVALID_HANDLE, g_adx=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
static double   g_ext_close=0.0;   // running best close since entry (highest for long, lowest for short)

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
double ATRv(const int sh){ return Buf(g_atr,0,sh); }

// return +1 own long, -1 own short, 0 flat
int OwnDir()
{
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_05_Magic)
         return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)? +1 : -1; }
   return 0;
}
bool OwnPosSelect()
{
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_05_Magic) return true; }
   return false;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_sma = iMA(_Symbol,PERIOD_CURRENT,_01_SmaPeriod,0,MODE_SMA,PRICE_CLOSE);
   g_atr = iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_sma==INVALID_HANDLE||g_atr==INVALID_HANDLE){ Print("TsMom: handle fail"); return INIT_FAILED; }
   if(_01_UseAdxGate){ g_adx=iADX(_Symbol,PERIOD_CURRENT,_01_AdxPeriod); if(g_adx==INVALID_HANDLE){ Print("TsMom: ADX handle fail"); return INIT_FAILED; } }
   g_trade.SetExpertMagicNumber(_05_Magic); g_trade.SetDeviationInPoints(_05_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false; g_ext_close=0.0;
   if(!g_suppress_log) PrintFormat("TsMom init magic=%d AllowLive=%s",_05_Magic,_05_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_sma!=INVALID_HANDLE)IndicatorRelease(g_sma); if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); if(g_adx!=INVALID_HANDLE)IndicatorRelease(g_adx); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<20) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_04_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_04_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   const double atr=ATRv(1); if(atr<=0.0) return;
   const int    digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const int    dir=OwnDir();

   // ---- signal (evaluated on closed bar 1) ----
   const double c1  = iClose(_Symbol,PERIOD_CURRENT,1);
   const double cN  = iClose(_Symbol,PERIOD_CURRENT,1+_01_MomLookback);
   const double sma = Buf(g_sma,0,1);
   double mom = (cN>0.0)? (c1-cN) : 0.0;
   const bool  strong = (MathAbs(mom) >= _01_DeadAtrMult*atr);
   const bool  trendOk = (!_01_UseAdxGate) || (Buf(g_adx,0,1) >= _01_AdxMin);   // regime gate
   const bool  longSig  = _03_BuyOk  && strong && trendOk && (mom>0.0) && (c1>sma);
   const bool  shortSig = _03_SellOk && strong && trendOk && (mom<0.0) && (c1<sma);

   // ---- manage open position: flip-close, then Chandelier trail ----
   if(dir!=0)
   {
      if(!OwnPosSelect()){ g_ext_close=0.0; }   // safety
      else
      {
         // flip on reversal signal -> close and let the next bar open the other side
         if((dir>0 && shortSig) || (dir<0 && longSig)){ g_trade.PositionClose(_Symbol); g_ext_close=0.0; return; }

         // seed running extreme if lost (e.g. after restart) from entry price
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         if(g_ext_close<=0.0) g_ext_close = entry;
         if(dir>0) g_ext_close = MathMax(g_ext_close, c1);
         else      g_ext_close = MathMin(g_ext_close, c1);

         double newSL = (dir>0)? g_ext_close - _02_TrailAtrMult*atr
                               : g_ext_close + _02_TrailAtrMult*atr;
         newSL = NormalizeDouble(newSL,digits);
         double curSL = PositionGetDouble(POSITION_SL);
         double tp    = PositionGetDouble(POSITION_TP);   // stays 0 (no fixed TP)
         bool improve = (dir>0)? (curSL==0.0 || newSL>curSL) : (curSL==0.0 || newSL<curSL);
         if(improve){ const bool allowM=_05_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
            if(allowM) g_trade.PositionModify(_Symbol,newSL,tp); }
      }
      return;   // one action per bar; do not open while holding
   }

   // ---- flat: open on fresh signal ----
   if(!RiskOk()) return;
   if(!longSig && !shortSig) return;
   const bool allow=_05_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   double slDist=_02_SlAtrMult*atr;

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN TSMOM-BUY @%.2f",ask); return; }
      if(g_trade.Buy(_03_LotSize,_Symbol,ask,NormalizeDouble(ask-slDist,digits),0.0,"TSMOM_BUY")) g_ext_close=ask; }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN TSMOM-SELL @%.2f",bid); return; }
      if(g_trade.Sell(_03_LotSize,_Symbol,bid,NormalizeDouble(bid+slDist,digits),0.0,"TSMOM_SELL")) g_ext_close=bid; }
}
