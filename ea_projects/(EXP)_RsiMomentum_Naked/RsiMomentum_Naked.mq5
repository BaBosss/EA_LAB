//+------------------------------------------------------------------+
//| RsiMomentum_Naked.mq5                                            |
//| ORDER-127 - flat-lot RSI-as-MOMENTUM probe                       |
//| Modes: A=RSI/SMA cross · B=RSI-50 break · C=RSI new-high/low     |
//| Filters (default OFF = byte-identical): EMA-align · MACD · BB    |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_RsiMomentum_Naked - RSI momentum flat-lot probe (ORDER-127)"

#include <Trade\Trade.mqh>

input bool   _00_OptimizeMode = false;
//--- [01] entry signal (RSI as momentum)
input int    _01_RsiMode      = 1;     // 0=A RSI/SMA cross · 1=B RSI-50 break · 2=C RSI new-high/low breakout
input int    _01_RsiPeriod    = 14;
input double _01_Level        = 50.0;  // mode B: momentum cross level
input int    _01_SmaPeriod    = 20;    // mode A: SMA period of RSI (the "SMA(20) RSI")
input int    _01_Lookback     = 20;    // mode C: RSI breakout lookback
//--- [03] risk shaping (ATR SL from recent swing, fixed RR)
input int    _03_AtrPeriod    = 14;
input double _03_BufferAtrMult = 0.50; // SL buffer beyond the swing (momentum needs room)
input double _03_RR           = 2.0;   // TP = RR x SL distance
//--- [05/06] execution
input double _05_LotSize      = 0.01;
input long   _06_Magic        = 999097;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;
//--- [07] EMA-align filter (default OFF -> no effect)
input bool   _07_UseEmaFilter = false; // long only if close>EMA, short only if close<EMA
input int    _07_EmaPeriod    = 200;
//--- [08] MACD-confirm filter (default OFF)
input bool   _08_UseMacdFilter= false; // long only if MACD main>signal, short only if main<signal
input int    _08_MacdFast     = 12;
input int    _08_MacdSlow     = 26;
input int    _08_MacdSignal   = 9;
//--- [09] BB squeeze-breakout filter (default OFF) — momentum framing (broke OUT of band), NOT mean-touch
input bool   _09_UseBbFilter  = false; // long only if close>upper band, short only if close<lower band
input int    _09_BbPeriod     = 20;
input double _09_BbDev        = 2.0;

static bool     g_suppress_log=false;
static datetime g_last_bar_time=0;
static bool     g_bar_checked=false;
static int      g_rsi=INVALID_HANDLE, g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE, g_macd=INVALID_HANDLE, g_bb=INVALID_HANDLE;
static CTrade   g_trade;

bool HasOpenPosition()
{
   for(int i=0;i<PositionsTotal();i++) { ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; }
   return false;
}

// RSI-as-momentum signal on the just-closed bar (shift 1). Returns +1 long, -1 short, 0 none.
int RsiSignal()
{
   int need=MathMax(_01_SmaPeriod,_01_Lookback)+5;
   double r[]; ArraySetAsSeries(r,true);
   if(CopyBuffer(g_rsi,0,0,need,r)<need) return 0;
   double r1=r[1], r2=r[2];

   if(_01_RsiMode==1) {                                   // B: RSI-50 (Level) break
      if(r2<=_01_Level && r1>_01_Level) return 1;
      if(r2>=_01_Level && r1<_01_Level) return -1;
      return 0;
   }
   if(_01_RsiMode==0) {                                   // A: RSI crosses its own SMA(SmaPeriod)
      double s1=0,s2=0;
      for(int k=0;k<_01_SmaPeriod;k++){ s1+=r[1+k]; s2+=r[2+k]; }
      s1/=_01_SmaPeriod; s2/=_01_SmaPeriod;
      if(r2<=s2 && r1>s1) return 1;
      if(r2>=s2 && r1<s1) return -1;
      return 0;
   }
   // C: RSI new-high / new-low breakout over Lookback (momentum continuation)
   double hi=r[2], lo=r[2];
   for(int k=2;k<=_01_Lookback+1;k++){ if(r[k]>hi) hi=r[k]; if(r[k]<lo) lo=r[k]; }
   if(r1>hi) return 1;
   if(r1<lo) return -1;
   return 0;
}

// All filters default OFF => returns true (byte-identical to naked). dir=+1 long / -1 short.
bool PassFilters(const int dir)
{
   if(_07_UseEmaFilter) {
      double e[1]; if(CopyBuffer(g_ema,0,1,1,e)<1) return false;
      double c=iClose(_Symbol,PERIOD_CURRENT,1);
      if(dir==1 && c<=e[0]) return false;
      if(dir==-1 && c>=e[0]) return false;
   }
   if(_08_UseMacdFilter) {
      double mm[1],ms[1]; if(CopyBuffer(g_macd,0,1,1,mm)<1 || CopyBuffer(g_macd,1,1,1,ms)<1) return false;
      if(dir==1 && mm[0]<=ms[0]) return false;
      if(dir==-1 && mm[0]>=ms[0]) return false;
   }
   if(_09_UseBbFilter) {
      double up[1],lw[1]; if(CopyBuffer(g_bb,1,1,1,up)<1 || CopyBuffer(g_bb,2,1,1,lw)<1) return false;
      double c=iClose(_Symbol,PERIOD_CURRENT,1);
      if(dir==1 && c<=up[0]) return false;    // require breakout ABOVE upper band (momentum)
      if(dir==-1 && c>=lw[0]) return false;   // require breakout BELOW lower band
   }
   return true;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(_01_RsiMode<0 || _01_RsiMode>2) { if(!g_suppress_log) Print("bad _01_RsiMode"); return INIT_FAILED; }
   g_rsi =iRSI(_Symbol,PERIOD_CURRENT,_01_RsiPeriod,PRICE_CLOSE);
   g_atr =iATR(_Symbol,PERIOD_CURRENT,_03_AtrPeriod);
   g_ema =iMA(_Symbol,PERIOD_CURRENT,_07_EmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_macd=iMACD(_Symbol,PERIOD_CURRENT,_08_MacdFast,_08_MacdSlow,_08_MacdSignal,PRICE_CLOSE);
   g_bb  =iBands(_Symbol,PERIOD_CURRENT,_09_BbPeriod,0,_09_BbDev,PRICE_CLOSE);
   if(g_rsi==INVALID_HANDLE || g_atr==INVALID_HANDLE || g_ema==INVALID_HANDLE || g_macd==INVALID_HANDLE || g_bb==INVALID_HANDLE) return INIT_FAILED;
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_rsi!=INVALID_HANDLE) IndicatorRelease(g_rsi);
   if(g_atr!=INVALID_HANDLE) IndicatorRelease(g_atr);
   if(g_ema!=INVALID_HANDLE) IndicatorRelease(g_ema);
   if(g_macd!=INVALID_HANDLE) IndicatorRelease(g_macd);
   if(g_bb!=INVALID_HANDLE) IndicatorRelease(g_bb);
}
double OnTester() { double t=TesterStatistics(STAT_TRADES); if(t<15) return -1.0; double s=TesterStatistics(STAT_SHARPE_RATIO); return s>0?s:-1.0; }

void OnTick()
{
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,1); if(bt!=g_last_bar_time) { g_last_bar_time=bt; g_bar_checked=false; }
   if(g_bar_checked) return; g_bar_checked=true; if(HasOpenPosition()) return;

   int dir=RsiSignal(); if(dir==0) return;
   if(!PassFilters(dir)) return;

   double atr[1]; if(CopyBuffer(g_atr,0,1,1,atr)<1 || atr[0]<=0) return;
   int d=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS); double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   // SL beyond the recent swing extreme (bars 1..3), buffer = ATR x mult
   double ext=(dir==1?iLow(_Symbol,PERIOD_CURRENT,1):iHigh(_Symbol,PERIOD_CURRENT,1));
   for(int s=2;s<=3;s++) ext=(dir==1?MathMin(ext,iLow(_Symbol,PERIOD_CURRENT,s)):MathMax(ext,iHigh(_Symbol,PERIOD_CURRENT,s)));
   double entry=(dir==1?ask:bid), buffer=MathMax(atr[0]*_03_BufferAtrMult,point);
   double sl=(dir==1?ext-buffer:ext+buffer); double dist=MathAbs(entry-sl); if(dist<=point) return;
   double tp=(dir==1?entry+_03_RR*dist:entry-_03_RR*dist);
   sl=NormalizeDouble(sl,d); tp=NormalizeDouble(tp,d);

   const bool allow=_06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER); if(!allow) return;
   if(dir==1) g_trade.Buy(_05_LotSize,_Symbol,ask,sl,tp,"RSIMOM_BUY"); else g_trade.Sell(_05_LotSize,_Symbol,bid,sl,tp,"RSIMOM_SELL");
}
