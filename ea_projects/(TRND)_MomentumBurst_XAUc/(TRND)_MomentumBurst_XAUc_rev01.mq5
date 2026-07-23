//+------------------------------------------------------------------+
//| (TRND)_MomentumBurst_XAUc_rev01.mq5                                |
//|                                                                    |
//| User Strategy 3 — "Momentum Burst" (2026-07-23 cent-scalp brief).  |
//| The trend-following counterpart to Strategies 1/2/4 (reversion) —  |
//| designed so this EA wins on the days those lose (trend), giving    |
//| the portfolio a hedge leg rather than 3 correlated reversion legs. |
//|                                                                    |
//| Entry (long; mirror short): close[1] breaks above the N-bar Hi     |
//| (excluding bar[1]) AND the breakout bar's body >= BodyAtrMult*ATR   |
//| (a real impulse, not a drift-through) -> buy. SL = SlPoints,        |
//| TP = TpPoints; once profit >= TrailActivatePts, trail SL at         |
//| TrailDistPts behind price (tightened each tick, one-way).           |
//|                                                                    |
//| L1: one position, real SL/TP, fixed lot, bar-open gated,           |
//| magic-scoped, hard caps. No grid/martingale. Magic 992013.        |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_MomentumBurst_XAUc_rev01 — N-bar breakout with impulse filter + post-profit trail, single-position, real SL/TP"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] BREAKOUT + IMPULSE ────────────────";
input int    _01_BreakoutBars = 15;
input int    _01_AtrPeriod    = 14;
input double _01_BodyAtrMult  = 1.5;   // breakout bar body must be >= this * ATR (real impulse)

input string _g02_            = "── [02] STOP / TARGET / TRAIL ─────────────";
input int    _02_TpPoints        = 100;
input int    _02_SlPoints        = 60;
input int    _02_TrailActivatePts= 60;   // start trailing once profit >= this many points
input int    _02_TrailDistPts    = 40;   // trail distance behind price once active

input string _g03_            = "── [03] SESSION (GMT hours) ───────────────";
input int    _03_StartGmt     = 0;
input int    _03_EndGmt       = 24;    // 24 = no restriction (this is the always-on hedge leg)
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 3.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992013;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return d.hour; }
bool InSession(const int gh){ if(_03_StartGmt<=_03_EndGmt) return (gh>=_03_StartGmt && gh<_03_EndGmt); return (gh>=_03_StartGmt || gh<_03_EndGmt); }
bool OwnSelect(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }
double HiN(const int n,const int sh){ double h=-1; for(int i=sh;i<sh+n;i++) h=MathMax(h,iHigh(_Symbol,PERIOD_CURRENT,i)); return h; }
double LoN(const int n,const int sh){ double l=1e18; for(int i=sh;i<sh+n;i++) l=MathMin(l,iLow(_Symbol,PERIOD_CURRENT,i)); return l; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("MomentumBurst: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("MomentumBurst init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_05_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_05_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double pt=_Point;

   // ---- post-profit trail: runs every tick (broker-side SL modify, not a bar-gated decision) ----
   if(OwnSelect())
   {
      const long ptype=PositionGetInteger(POSITION_TYPE);
      const double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      const bool isBuy=(ptype==POSITION_TYPE_BUY);
      const double prof=(isBuy?(bid-entry):(entry-ask))/pt;
      if(prof >= _02_TrailActivatePts)
      {
         const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         double newSL=isBuy? (bid-_02_TrailDistPts*pt) : (ask+_02_TrailDistPts*pt);
         newSL=NormalizeDouble(newSL,digits);
         double curSL=PositionGetDouble(POSITION_SL);
         bool improve=isBuy? (curSL==0.0||newSL>curSL) : (curSL==0.0||newSL<curSL);
         if(improve && allow) g_trade.PositionModify(_Symbol,newSL,PositionGetDouble(POSITION_TP));
      }
      return;
   }

   // ---- entry: bar-gated ----
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;

   if(!RiskOk()) return;
   if(!InSession(GmtHourOf(TimeCurrent()))) return;

   const double atr=Buf1(g_atr,1); if(atr<=0.0) return;
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   const double body=MathAbs(c1-o1);
   if(body < _01_BodyAtrMult*atr) return;                        // require a real impulse bar

   const double hiN=HiN(_01_BreakoutBars,2), loN=LoN(_01_BreakoutBars,2);  // excludes bar[1] itself
   const bool longSig = _04_BuyOk  && (c1>hiN) && (c1>o1);
   const bool shortSig= _04_SellOk && (c1<loN) && (c1<o1);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=ask-_02_SlPoints*pt, tp=ask+_02_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN MOMBURST-BUY @%.2f",ask); return; }
      g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"MOMBURST_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=bid+_02_SlPoints*pt, tp=bid-_02_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN MOMBURST-SELL @%.2f",bid); return; }
      g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"MOMBURST_SELL"); }
}
