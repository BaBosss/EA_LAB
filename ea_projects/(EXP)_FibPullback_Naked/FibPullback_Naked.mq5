//+------------------------------------------------------------------+
//| FibPullback_Naked.mq5                                            |
//| ORDER-098-J - flat-lot Fibonacci-retracement pullback probe      |
//| Trend-continuation: enter WITH the last impulse leg when price    |
//| retraces into the 0.382-0.618 golden pocket. SL = 100%-retrace    |
//| invalidation (origin of the leg). Naked, one position at a time.  |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_FibPullback_Naked - Fibonacci pullback flat-lot probe"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode  = false;
input int    _01_LookbackBars  = 80;    // bars scanned for swing pivots
input int    _01_SwingRadius   = 2;     // pivot strength (bars each side)
input int    _01_MinBarsApart  = 3;     // (reserved) min separation
input double _02_FibLo         = 0.382; // near edge of entry pocket
input double _02_FibHi         = 0.618; // far edge of entry pocket
input double _03_BufferAtrMult = 0.10;  // SL buffer beyond the leg origin
input int    _03_AtrPeriod     = 14;
input double _04_TpRR          = 2.0;   // TP as multiple of risk (R)
input double _05_LotSize       = 0.01;
input long   _06_Magic         = 990095;
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;

static bool g_suppress_log=false;
static datetime g_last_bar_time=0;
static bool g_bar_checked=false;
static int g_atr=INVALID_HANDLE;
static CTrade g_trade;

bool HasOpenPosition()
{
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; }
   return false;
}

bool IsLow(const int shift,const double &lows[])
{
   for(int k=1;k<=_01_SwingRadius;k++) if(lows[shift-k]>=lows[shift] || lows[shift+k]>=lows[shift]) return false; return true;
}
bool IsHigh(const int shift,const double &highs[])
{
   for(int k=1;k<=_01_SwingRadius;k++) if(highs[shift-k]<=highs[shift] || highs[shift+k]<=highs[shift]) return false; return true;
}

// dir=+1 up-impulse (buy pullback), -1 down-impulse (sell pullback), 0 none.
// Fills H (swing high price), L (swing low price) of the most-recent impulse leg.
int LastLeg(double &H,double &L)
{
   const int n=_01_LookbackBars+_01_SwingRadius+3;
   double hi[],lo[]; ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,n,hi)<n || CopyLow(_Symbol,PERIOD_CURRENT,0,n,lo)<n) return 0;
   int shHigh=-1,shLow=-1;
   for(int s=_01_SwingRadius+1;s<=_01_LookbackBars;s++){ if(IsHigh(s,hi)){ shHigh=s; break; } }
   for(int s=_01_SwingRadius+1;s<=_01_LookbackBars;s++){ if(IsLow(s,lo)){ shLow=s; break; } }
   if(shHigh<0 || shLow<0 || shHigh==shLow) return 0;
   H=hi[shHigh]; L=lo[shLow];
   if(H<=L) return 0;
   // the more-recent pivot ends the leg; the older pivot is its origin
   if(shLow>shHigh) return 1;   // low older -> up-leg L->H
   return -1;                    // high older -> down-leg H->L
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(_02_FibLo<=0.0 || _02_FibHi<=_02_FibLo || _02_FibHi>=1.0) return INIT_PARAMETERS_INCORRECT;
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_03_AtrPeriod);
   if(g_atr==INVALID_HANDLE) return INIT_FAILED;
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){ if(g_atr!=INVALID_HANDLE) IndicatorRelease(g_atr); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<15) return -1.0; double s=TesterStatistics(STAT_SHARPE_RATIO); return s>0?s:-1.0; }

void OnTick()
{
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,1); if(bt!=g_last_bar_time){ g_last_bar_time=bt; g_bar_checked=false; }
   if(g_bar_checked) return; g_bar_checked=true; if(HasOpenPosition()) return;

   double H,L; int dir=LastLeg(H,L); if(dir==0) return;
   double R=H-L; if(R<=0) return;
   double close1=iClose(_Symbol,PERIOD_CURRENT,1); if(close1<=0) return;

   // golden pocket + 100%-retrace invalidation guard
   double pocketLo,pocketHi; bool inPocket=false;
   if(dir==1){ pocketLo=H-_02_FibHi*R; pocketHi=H-_02_FibLo*R; inPocket=(close1>=pocketLo && close1<=pocketHi && close1>L); }
   else      { pocketLo=L+_02_FibLo*R; pocketHi=L+_02_FibHi*R; inPocket=(close1>=pocketLo && close1<=pocketHi && close1<H); }
   if(!inPocket) return;

   double atr[1]; if(CopyBuffer(g_atr,0,1,1,atr)<1 || atr[0]<=0) return;
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double buffer=MathMax(atr[0]*_03_BufferAtrMult,point);
   double entry=(dir==1?ask:bid);
   double sl=(dir==1?L-buffer:H+buffer);
   double dist=MathAbs(entry-sl); if(dist<=point) return;
   double tp=(dir==1?entry+_04_TpRR*dist:entry-_04_TpRR*dist);
   sl=NormalizeDouble(sl,d); tp=NormalizeDouble(tp,d);

   const bool allow=_06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER); if(!allow) return;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("FibPullback: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }

   bool ok;
   if(dir==1) ok=g_trade.Buy(_05_LotSize,_Symbol,ask,sl,tp,"FIBPB_BUY");
   else       ok=g_trade.Sell(_05_LotSize,_Symbol,bid,sl,tp,"FIBPB_SELL");
   if(!ok && !g_suppress_log) PrintFormat("FIBPB FAILED retcode=%d",g_trade.ResultRetcode());
}
