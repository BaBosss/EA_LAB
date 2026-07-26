//+------------------------------------------------------------------+
//| Ma4Ma20Wpr_Naked.mq5                                             |
//| (EXP) naked probe of the manual-trader "MA4/MA20 + WPR" scalp     |
//| tip (user intake 2026-07-25). EXPERIMENT ONLY - NOT FOR DEPLOY.   |
//|                                                                  |
//| Mechanism, faithful to the post:                                 |
//|  - MA4 crosses MA20 -> direction = the side MA4 crossed to, and  |
//|    MA4 must still be POINTING that way (slope), because the post |
//|    says "MA4 ชี้ไปทิศทางไหน กราฟจะไปทางนั้น".                     |
//|  - CONFIRMATION: price must close BEYOND MA20 for N bars         |
//|    (post: M1 needs 1-2 bars, M5 confirms harder) -> _01_Confirm. |
//|  - WPR checks the move is really up/down: %R on the up-half of   |
//|    its range for a long (and not already pinned at the extreme). |
//|  - Cross only stays valid for a few bars (_01_CrossValidBars),   |
//|    one entry per cross, single position, closed-bar reads.       |
//|                                                                  |
//| Exits are the lab default naked shape (swing+ATR SL, fixed RR).  |
//| Optional MA20 close-back exit is default OFF => naked baseline   |
//| is byte-identical without it. Lab conventions: bar-open gate,    |
//| shift-1 reads, magic scope, stops-level clamp, tester-safe gate. |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "1.00"
#property strict
#property description "(EXP)_Ma4Ma20Wpr_Naked - MA4/MA20 cross + MA20 close-confirm + Williams %R scalp probe"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode   = false;
//--- [01] entry signal: MA4 / MA20 cross + MA20 close confirmation
input int    _01_FastPeriod     = 4;      // MA4
input int    _01_SlowPeriod     = 20;     // MA20
input ENUM_MA_METHOD _01_MaMethod = MODE_SMA;
input int    _01_CrossValidBars = 3;      // cross must have happened within the last N closed bars
input int    _01_ConfirmBars    = 1;      // closes beyond MA20 required (post: M1 = 1-2 bars, M5 = safer)
input bool   _01_UseMa4Slope    = true;   // "MA4 ชี้ไปทิศทางไหน" - MA4 must still point that way
input int    _01_SlopeBars      = 1;      // slope measured over this many bars
//--- [02] Williams %R direction check
input bool   _02_UseWpr         = true;
input int    _02_WprPeriod      = 14;
input double _02_WprMid         = 50.0;   // long needs %R above -Mid (upper half = pushing up)
input double _02_WprGuard       = 5.0;    // ...but below -Guard: skip a move already pinned at the extreme
input bool   _02_WprMustRise    = false;  // extra: %R itself moving in the trade direction (default OFF)
//--- [03] risk shaping (swing extreme + ATR buffer, fixed RR)
input int    _03_AtrPeriod      = 14;
input int    _03_SwingBars      = 3;      // SL beyond the extreme of the last N closed bars
input double _03_BufferAtrMult  = 0.50;   // buffer beyond that extreme
input double _03_RR             = 1.5;    // TP = RR x SL distance
//--- [04] optional exit lever (default OFF -> naked baseline unchanged)
input bool   _04_ExitOnMa20Back = false;  // close early when a bar closes back through MA20 against us
//--- [05/06] execution
input double _05_LotSize        = 0.01;
input long   _06_Magic          = 999098;
input ulong  _06_Deviation      = 20;
input bool   _06_AllowLive      = false;

static bool     g_suppress_log=false;
static datetime g_last_bar_time=0;
static bool     g_bar_checked=false;
static datetime g_traded_cross=0;   // bar time of the cross already traded (one entry per cross)
static int      g_fast=INVALID_HANDLE, g_slow=INVALID_HANDLE, g_wpr=INVALID_HANDLE, g_atr=INVALID_HANDLE;
static CTrade   g_trade;

ulong OwnPositionTicket()
{
   for(int i=PositionsTotal()-1;i>=0;i--) { ulong t=PositionGetTicket(i); if(t==0) continue;
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return t; }
   return 0;
}

// MA4/MA20 cross + MA4 slope + MA20 close-confirm + %R. Closed bars only (shift>=1).
// Returns +1 long / -1 short / 0 none; crossBar = bar time of the cross that fired.
int Signal(datetime &crossBar)
{
   crossBar=0;
   int need=_01_CrossValidBars+_01_ConfirmBars+_01_SlopeBars+3;
   double f[],s[]; ArraySetAsSeries(f,true); ArraySetAsSeries(s,true);
   if(CopyBuffer(g_fast,0,0,need,f)<need) return 0;
   if(CopyBuffer(g_slow,0,0,need,s)<need) return 0;

   // most recent cross inside the validity window (k = the bar that closed on the new side)
   int dir=0, kCross=-1;
   for(int k=1;k<=_01_CrossValidBars;k++)
   {
      if(f[k]>s[k] && f[k+1]<=s[k+1]) { dir= 1; kCross=k; break; }
      if(f[k]<s[k] && f[k+1]>=s[k+1]) { dir=-1; kCross=k; break; }
   }
   if(dir==0) return 0;

   // MA4 must still be on that side of MA20 on the just-closed bar
   if(dir== 1 && f[1]<=s[1]) return 0;
   if(dir==-1 && f[1]>=s[1]) return 0;

   // ...and still pointing that way
   if(_01_UseMa4Slope)
   {
      double slope=f[1]-f[1+_01_SlopeBars];
      if(dir== 1 && slope<=0.0) return 0;
      if(dir==-1 && slope>=0.0) return 0;
   }

   // price closed beyond MA20 for _01_ConfirmBars consecutive closed bars
   for(int j=1;j<=_01_ConfirmBars;j++)
   {
      double c=iClose(_Symbol,PERIOD_CURRENT,j);
      if(c<=0.0) return 0;
      if(dir== 1 && c<=s[j]) return 0;
      if(dir==-1 && c>=s[j]) return 0;
   }

   // Williams %R lives in [-100,0]: near 0 = top of range, near -100 = bottom.
   if(_02_UseWpr)
   {
      double w[]; ArraySetAsSeries(w,true);
      if(CopyBuffer(g_wpr,0,0,4,w)<4) return 0;
      if(dir==1)
      {
         if(w[1]<=-_02_WprMid)   return 0;   // not pushing up
         if(w[1]>=-_02_WprGuard) return 0;   // already pinned at the top
         if(_02_WprMustRise && w[1]<=w[2]) return 0;
      }
      else
      {
         if(w[1]>=-(100.0-_02_WprMid))   return 0;
         if(w[1]<=-(100.0-_02_WprGuard)) return 0;
         if(_02_WprMustRise && w[1]>=w[2]) return 0;
      }
   }

   crossBar=iTime(_Symbol,PERIOD_CURRENT,kCross);
   return dir;
}

// Optional early exit: a closed bar back on the wrong side of MA20.
void ManageOpen(const ulong ticket)
{
   if(!_04_ExitOnMa20Back) return;
   if(!PositionSelectByTicket(ticket)) return;
   double s[1]; if(CopyBuffer(g_slow,0,1,1,s)<1) return;
   double c=iClose(_Symbol,PERIOD_CURRENT,1); if(c<=0.0) return;
   const bool isLong=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   if(( isLong && c<s[0]) || (!isLong && c>s[0])) g_trade.PositionClose(ticket);
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(_01_FastPeriod<1 || _01_SlowPeriod<2 || _01_FastPeriod>=_01_SlowPeriod)
   { if(!g_suppress_log) Print("bad MA periods (need 1<=Fast<Slow)"); return INIT_FAILED; }
   if(_01_CrossValidBars<1 || _01_ConfirmBars<1 || _01_SlopeBars<1 || _03_SwingBars<1)
   { if(!g_suppress_log) Print("bad bar-count input (must be >=1)"); return INIT_FAILED; }
   if(_02_WprGuard<0.0 || _02_WprGuard>=_02_WprMid)
   { if(!g_suppress_log) Print("bad WPR band (need 0<=Guard<Mid)"); return INIT_FAILED; }
   if(_03_RR<=0.0) { if(!g_suppress_log) Print("bad _03_RR"); return INIT_FAILED; }

   g_fast=iMA(_Symbol,PERIOD_CURRENT,_01_FastPeriod,0,_01_MaMethod,PRICE_CLOSE);
   g_slow=iMA(_Symbol,PERIOD_CURRENT,_01_SlowPeriod,0,_01_MaMethod,PRICE_CLOSE);
   g_wpr =iWPR(_Symbol,PERIOD_CURRENT,_02_WprPeriod);
   g_atr =iATR(_Symbol,PERIOD_CURRENT,_03_AtrPeriod);
   if(g_fast==INVALID_HANDLE || g_slow==INVALID_HANDLE || g_wpr==INVALID_HANDLE || g_atr==INVALID_HANDLE) return INIT_FAILED;
   g_last_bar_time=0; g_bar_checked=false; g_traded_cross=0;
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_fast!=INVALID_HANDLE) IndicatorRelease(g_fast);
   if(g_slow!=INVALID_HANDLE) IndicatorRelease(g_slow);
   if(g_wpr !=INVALID_HANDLE) IndicatorRelease(g_wpr);
   if(g_atr !=INVALID_HANDLE) IndicatorRelease(g_atr);
}
double OnTester() { double t=TesterStatistics(STAT_TRADES); if(t<30) return -1.0; return TesterStatistics(STAT_PROFIT_FACTOR); }

void OnTick()
{
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,1); if(bt!=g_last_bar_time) { g_last_bar_time=bt; g_bar_checked=false; }
   if(g_bar_checked) return; g_bar_checked=true;

   ulong ticket=OwnPositionTicket();
   if(ticket!=0) { ManageOpen(ticket); return; }        // single-position mode

   datetime crossBar=0;
   int dir=Signal(crossBar); if(dir==0) return;
   if(crossBar==g_traded_cross) return;                 // one entry per cross

   double atr[1]; if(CopyBuffer(g_atr,0,1,1,atr)<1 || atr[0]<=0.0) return;
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(ask<=0.0 || bid<=0.0 || point<=0.0) return;

   // SL beyond the extreme of the last _03_SwingBars closed bars + ATR buffer
   double ext=(dir==1?iLow(_Symbol,PERIOD_CURRENT,1):iHigh(_Symbol,PERIOD_CURRENT,1));
   for(int k=2;k<=_03_SwingBars;k++)
      ext=(dir==1?MathMin(ext,iLow(_Symbol,PERIOD_CURRENT,k)):MathMax(ext,iHigh(_Symbol,PERIOD_CURRENT,k)));
   double entry=(dir==1?ask:bid), buffer=MathMax(atr[0]*_03_BufferAtrMult,point);
   double sl=(dir==1?ext-buffer:ext+buffer);
   double dist=MathAbs(entry-sl); if(dist<=point) return;
   double tp=(dir==1?entry+_03_RR*dist:entry-_03_RR*dist);

   // broker stops-level clamp (matters on M1/M5 where the swing SL can be tighter than allowed)
   double stops=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   if(stops>0.0)
   {
      if(MathAbs(entry-sl)<stops) sl=(dir==1?entry-stops:entry+stops);
      if(MathAbs(tp-entry)<stops) tp=(dir==1?entry+stops:entry-stops);
   }
   sl=NormalizeDouble(sl,d); tp=NormalizeDouble(tp,d);

   const bool allow=_06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER); if(!allow) return;
   if(dir==1) g_trade.Buy (_05_LotSize,_Symbol,ask,sl,tp,"MA4MA20WPR_BUY");
   else       g_trade.Sell(_05_LotSize,_Symbol,bid,sl,tp,"MA4MA20WPR_SELL");
   g_traded_cross=crossBar;
}
//+------------------------------------------------------------------+
