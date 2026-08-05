//+------------------------------------------------------------------+
//| HarmonicABCD_Naked.mq5                                           |
//| ORDER-098-M - flat-lot harmonic AB=CD reversal probe             |
//| Last 3 alternating swing pivots A,B,C -> project D with CD~=AB    |
//| symmetry + BC retrace 0.382-0.886 of AB. Enter reversal at D.     |
//| Naked, one position at a time. Reversion-geometry (low prior).    |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_HarmonicABCD_Naked - harmonic AB=CD flat-lot probe"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode  = false;
input int    _01_LookbackBars  = 120;   // bars scanned for pivots
input int    _01_SwingRadius   = 3;     // pivot strength
input double _02_BcRetraceLo   = 0.382; // BC retrace of AB, lower bound
input double _02_BcRetraceHi   = 0.886; // BC retrace of AB, upper bound
input double _02_DzoneTolAB     = 0.10; // D-zone tolerance as fraction of AB
input double _03_BufferAtrMult = 0.30;  // SL buffer beyond D
input int    _03_AtrPeriod     = 14;
input double _04_TpFrac        = 0.786; // TP = D + TpFrac*(C-D) (partial toward C)
input double _05_LotSize       = 0.01;
input long   _06_Magic         = 990096;
input ulong  _06_Deviation     = 20;
input bool   _06_AllowLive     = false;

static bool     g_suppress_log  = false;
static datetime g_last_bar_time = 0;
static bool     g_bar_checked   = false;
static int      g_atr           = INVALID_HANDLE;
static CTrade   g_trade;

bool HasOpenPosition()
{
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; }
   return false;
}
bool IsLow(const int shift,const double &lows[])
{ for(int k=1;k<=_01_SwingRadius;k++) if(lows[shift-k]>=lows[shift] || lows[shift+k]>=lows[shift]) return false; return true; }
bool IsHigh(const int shift,const double &highs[])
{ for(int k=1;k<=_01_SwingRadius;k++) if(highs[shift-k]<=highs[shift] || highs[shift+k]<=highs[shift]) return false; return true; }

// collect the 3 most-recent ALTERNATING pivots (newest first). returns count.
int CollectPivots(double &price[],bool &isHigh[])
{
   const int n=_01_LookbackBars+_01_SwingRadius+3;
   double hi[],lo[]; ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,n,hi)<n || CopyLow(_Symbol,PERIOD_CURRENT,0,n,lo)<n) return 0;
   int cnt=0; int lastType=0; // +1 high, -1 low
   for(int s=_01_SwingRadius+1; s<=_01_LookbackBars && cnt<3; s++){
      bool ih=IsHigh(s,hi), il=IsLow(s,lo);
      if(ih && lastType!=1){ price[cnt]=hi[s]; isHigh[cnt]=true;  lastType=1;  cnt++; }
      else if(il && lastType!=-1){ price[cnt]=lo[s]; isHigh[cnt]=false; lastType=-1; cnt++; }
   }
   return cnt;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(_02_BcRetraceHi<=_02_BcRetraceLo) return INIT_PARAMETERS_INCORRECT;
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

   double pr[3]; bool ih[3];
   if(CollectPivots(pr,ih)<3) return;
   // pr[0]=C (newest), pr[1]=B, pr[2]=A
   double C=pr[0],B=pr[1],A=pr[2];
   double close1=iClose(_Symbol,PERIOD_CURRENT,1); if(close1<=0) return;
   double low1=iLow(_Symbol,PERIOD_CURRENT,1), high1=iHigh(_Symbol,PERIOD_CURRENT,1);

   int dir=0; double Dproj=0.0, ab=0.0;
   // bullish AB=CD: A high, B low, C high ; D low below, buy the reversal
   if(ih[0] && !ih[1] && ih[2]){
      ab=A-B; if(ab<=0) return;
      double bc=(C-B)/ab; if(bc<_02_BcRetraceLo || bc>_02_BcRetraceHi) return;
      Dproj=C-ab;                         // CD = AB
      double tol=_02_DzoneTolAB*ab;
      if(low1<=Dproj+tol && close1>=Dproj-tol && close1>Dproj-tol) dir=1;  // price reached D zone and held
   }
   // bearish AB=CD: A low, B high, C low ; D high above, sell the reversal
   else if(!ih[0] && ih[1] && !ih[2]){
      ab=B-A; if(ab<=0) return;
      double bc=(B-C)/ab; if(bc<_02_BcRetraceLo || bc>_02_BcRetraceHi) return;
      Dproj=C+ab;
      double tol=_02_DzoneTolAB*ab;
      if(high1>=Dproj-tol && close1<=Dproj+tol) dir=-1;
   }
   if(dir==0) return;

   double atr[1]; if(CopyBuffer(g_atr,0,1,1,atr)<1 || atr[0]<=0) return;
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double buffer=MathMax(atr[0]*_03_BufferAtrMult,point);
   double entry=(dir==1?ask:bid);
   double sl=(dir==1?Dproj-buffer:Dproj+buffer);
   double dist=MathAbs(entry-sl); if(dist<=point) return;
   double tp=(dir==1? entry+_04_TpFrac*(C-Dproj) : entry-_04_TpFrac*(Dproj-C));
   if(dir==1 && tp<=entry) return; if(dir==-1 && tp>=entry) return;
   sl=NormalizeDouble(sl,d); tp=NormalizeDouble(tp,d);

   const bool allow=_06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER); if(!allow) return;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("HarmonicABCD: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }

   bool ok;
   if(dir==1) ok=g_trade.Buy(_05_LotSize,_Symbol,ask,sl,tp,"HARM_BUY");
   else       ok=g_trade.Sell(_05_LotSize,_Symbol,bid,sl,tp,"HARM_SELL");
   if(!ok && !g_suppress_log) PrintFormat("HARM FAILED retcode=%d",g_trade.ResultRetcode());
}
