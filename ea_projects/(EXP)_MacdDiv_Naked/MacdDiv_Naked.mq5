//+------------------------------------------------------------------+
//| MacdDiv_Naked.mq5                                               |
//| ORDER-098-B - flat-lot MACD divergence probe                    |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_MacdDiv_Naked - MACD divergence flat-lot probe"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode = false;
input int    _01_LookbackBars = 80;
input int    _01_SwingRadius  = 2;
input int    _01_MinBarsApart = 3;
input int    _02_MacdFast     = 12;
input int    _02_MacdSlow     = 26;
input int    _02_MacdSignal   = 9;
input double _03_BufferAtrMult = 0.10;
input int    _03_AtrPeriod    = 14;
input double _05_LotSize      = 0.01;
input long   _06_Magic        = 999094;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

//--- [07] RSI-timing precision filter (ORDER-117 Track B — filter on a RAW base, no existing filter)
input bool   _07_UseRsiGate   = false; // false = byte-identical baseline. true = require RSI to confirm reversal timing
input int    _07_RsiPeriod    = 14;
input double _07_RsiBuyMax     = 45.0; // buy (bullish div) only if RSI(1) <= this (oversold confirms the reversal)
input double _07_RsiSellMin    = 55.0; // sell (bearish div) only if RSI(1) >= this (overbought confirms)

//--- [08] MACD-cross timing filter (ORDER-217 - independent confirmation, reads buffer 1 which the EA never otherwise touches)
input bool   _08_UseMacdCross    = false; // false = byte-identical baseline. true = require MACD main/signal cross in the divergence direction within N bars
input int    _08_CrossWithinBars = 3;     // lookback window (closed bars) to find a same-direction MACD/signal crossover

static bool g_suppress_log=false;
static datetime g_last_bar_time=0;
static bool g_bar_checked=false;
static int g_macd=INVALID_HANDLE, g_atr=INVALID_HANDLE, g_rsi=INVALID_HANDLE;
static CTrade g_trade;

bool HasOpenPosition()
{
   for(int i=0;i<PositionsTotal();i++) { ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; }
   return false;
}

bool MacdAt(const int shift,double &value)
{
   double b[1]; if(CopyBuffer(g_macd,0,shift,1,b)<1) return false; value=b[0]; return true;
}

// [08] MACD main (buffer 0) vs signal (buffer 1) crossover in `dir`'s direction, found within the
// last `within_bars` closed bars. Only called when _08_UseMacdCross==true.
bool MacdCrossedRecently(const int dir,const int within_bars)
{
   const int need=within_bars+1;
   double macd[],sig[]; ArraySetAsSeries(macd,true); ArraySetAsSeries(sig,true);
   if(CopyBuffer(g_macd,0,1,need,macd)<need) return false;
   if(CopyBuffer(g_macd,1,1,need,sig)<need) return false;
   for(int i=0;i<within_bars;i++) {
      const double m_now=macd[i],s_now=sig[i],m_prev=macd[i+1],s_prev=sig[i+1];
      if(dir==1 && m_prev<=s_prev && m_now>s_now) return true;
      if(dir==-1 && m_prev>=s_prev && m_now<s_now) return true;
   }
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

int Divergence(double &swing_price,double &swing_macd)
{
   const int n=_01_LookbackBars+_01_SwingRadius+3;
   double hi[],lo[]; ArraySetAsSeries(hi,true); ArraySetAsSeries(lo,true);
   if(CopyHigh(_Symbol,PERIOD_CURRENT,0,n,hi)<n || CopyLow(_Symbol,PERIOD_CURRENT,0,n,lo)<n) return 0;
   int low1=-1,low2=-1,high1=-1,high2=-1; double m1,m2;
   for(int s=_01_SwingRadius+1;s<=_01_LookbackBars;s++) {
      if(low1<0 && IsLow(s,lo)) low1=s; else if(low1>=0 && s-low1>=_01_MinBarsApart && IsLow(s,lo)) { low2=s; break; }
   }
   for(int s=_01_SwingRadius+1;s<=_01_LookbackBars;s++) {
      if(high1<0 && IsHigh(s,hi)) high1=s; else if(high1>=0 && s-high1>=_01_MinBarsApart && IsHigh(s,hi)) { high2=s; break; }
   }
   if(low1>=0 && low2>=0 && MacdAt(low1,m1) && MacdAt(low2,m2) && lo[low1]<lo[low2] && m1>m2) { swing_price=lo[low1]; swing_macd=m1; return 1; }
   if(high1>=0 && high2>=0 && MacdAt(high1,m1) && MacdAt(high2,m2) && hi[high1]>hi[high2] && m1<m2) { swing_price=hi[high1]; swing_macd=m1; return -1; }
   return 0;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_macd=iMACD(_Symbol,PERIOD_CURRENT,_02_MacdFast,_02_MacdSlow,_02_MacdSignal,PRICE_CLOSE);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_03_AtrPeriod);
   g_rsi=iRSI(_Symbol,PERIOD_CURRENT,_07_RsiPeriod,PRICE_CLOSE);
   if(g_macd==INVALID_HANDLE || g_atr==INVALID_HANDLE || g_rsi==INVALID_HANDLE) return INIT_FAILED;
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { if(g_macd!=INVALID_HANDLE) IndicatorRelease(g_macd); if(g_atr!=INVALID_HANDLE) IndicatorRelease(g_atr); if(g_rsi!=INVALID_HANDLE) IndicatorRelease(g_rsi); }
double OnTester() { double t=TesterStatistics(STAT_TRADES); if(t<15) return -1.0; double s=TesterStatistics(STAT_SHARPE_RATIO); return s>0?s:-1.0; }

void OnTick()
{
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,1); if(bt!=g_last_bar_time) { g_last_bar_time=bt; g_bar_checked=false; }
   if(g_bar_checked) return; g_bar_checked=true; if(HasOpenPosition()) return;
   double p,m; int dir=Divergence(p,m); if(dir==0) return;
   // [07] RSI-timing gate (default OFF = identical): only take the divergence entry when RSI confirms the reversal
   if(_07_UseRsiGate) { double rb[1]; if(CopyBuffer(g_rsi,0,1,1,rb)<1) return; if(dir==1 && rb[0]>_07_RsiBuyMax) return; if(dir==-1 && rb[0]<_07_RsiSellMin) return; }
   // [08] MACD-cross timing gate (default OFF = identical): only take the divergence entry when MACD
   // has crossed its own signal line in the same direction within the last N bars.
   if(_08_UseMacdCross) { if(!MacdCrossedRecently(dir,_08_CrossWithinBars)) return; }
   double atr[1]; if(CopyBuffer(g_atr,0,1,1,atr)<1 || atr[0]<=0) return;
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT); double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double ext=(dir==1?iLow(_Symbol,PERIOD_CURRENT,1):iHigh(_Symbol,PERIOD_CURRENT,1));
   for(int s=2;s<=3;s++) ext=(dir==1?MathMin(ext,iLow(_Symbol,PERIOD_CURRENT,s)):MathMax(ext,iHigh(_Symbol,PERIOD_CURRENT,s)));
   double entry=dir==1?ask:bid, buffer=MathMax(atr[0]*_03_BufferAtrMult,point); double sl=dir==1?ext-buffer:ext+buffer; double dist=MathAbs(entry-sl); if(dist<=point) return; double tp=dir==1?entry+2.0*dist:entry-2.0*dist;
   sl=NormalizeDouble(sl,d); tp=NormalizeDouble(tp,d);
   const bool allow=_06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER); if(!allow) return;
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("MacdDiv: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }
   bool ok;
   if(dir==1) ok=g_trade.Buy(_05_LotSize,_Symbol,ask,sl,tp,"MACDDIV_BUY"); else ok=g_trade.Sell(_05_LotSize,_Symbol,bid,sl,tp,"MACDDIV_SELL");
   if(!ok && !g_suppress_log) PrintFormat("MACDDIV FAILED retcode=%d",g_trade.ResultRetcode());
}
