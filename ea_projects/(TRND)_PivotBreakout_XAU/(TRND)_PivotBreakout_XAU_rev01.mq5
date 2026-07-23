//+------------------------------------------------------------------+
//| (TRND)_PivotBreakout_XAU_rev01.mq5                                |
//|                                                                    |
//| New idea — Classic Daily Pivot Breakout (momentum). Distinct from  |
//| every breakout EA in the cohort: reference levels are the CLASSIC  |
//| floor-trader pivot formula computed from the prior D1 bar (Pivot,  |
//| R1, S1) -- fixed, well-known institutional reference levels, not   |
//| a rolling N-bar Donchian range (S1/SS1/VolRegimeBreakout) or a      |
//| session opening-range (SS1) or an ATR-distance stretch. Distinct   |
//| from the idea-bank `GoldenEmber_Pivot` entry too: that one has no   |
//| source in this repo (imported NZDUSD idea-bank results only,       |
//| flagged STALE in signal-landscape memory) -- this is a fresh XAU   |
//| build, not a port of it.                                           |
//|                                                                    |
//| Pivot = (H[1]+L[1]+C[1])/3 ; R1 = 2*Pivot-L[1] ; S1 = 2*Pivot-H[1]  |
//| (all from the prior CLOSED D1 bar, recomputed once per new D1 bar).|
//|                                                                    |
//| Entry (long; mirror short): close[1] (working TF) crosses above R1 |
//| with a confirming bullish close -> buy (mirror: crosses below S1   |
//| -> sell). SL = ATR*SlAtrMult, TP = TpRR*risk. One trade per         |
//| direction per D1 session (reset at D1 rollover).                    |
//|                                                                    |
//| L1: one position, real SL/TP, fixed lot, bar-open gated,           |
//| magic-scoped, hard caps. No grid/martingale. Magic 992017.        |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_PivotBreakout_XAU_rev01 — classic daily-pivot R1/S1 breakout, single-position, real SL/TP"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] PIVOT + ATR ───────────────────────";
input int    _01_AtrPeriod    = 14;

input string _g02_            = "── [02] STOP / TARGET ─────────────────────";
input double _02_SlAtrMult    = 2.0;
input double _02_TpRR         = 2.0;

input string _g03_            = "── [03] SESSION (GMT hours) ───────────────";
input int    _03_StartGmt     = 0;
input int    _03_EndGmt       = 24;    // 24 = no restriction
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992017;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE;
static datetime g_last_bar=0, g_pivot_day=0, g_traded_day_long=0, g_traded_day_short=0;
static double   g_pivot=0.0, g_r1=0.0, g_s1=0.0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return d.hour; }
bool InSession(const int gh){ if(_03_StartGmt<=_03_EndGmt) return (gh>=_03_StartGmt && gh<_03_EndGmt); return (gh>=_03_StartGmt || gh<_03_EndGmt); }
datetime GmtDayOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return (datetime)(d.year*10000+d.mon*100+d.day); }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("PivotBreakout: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_pivot_day=0; g_traded_day_long=0; g_traded_day_short=0;
   g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("PivotBreakout init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
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
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   // recompute the classic pivot once per new D1 session, from the prior CLOSED D1 bar
   const datetime today=GmtDayOf(TimeCurrent());
   if(today!=g_pivot_day)
   {
      g_pivot_day=today;
      double h1=iHigh(_Symbol,PERIOD_D1,1), l1=iLow(_Symbol,PERIOD_D1,1), c1=iClose(_Symbol,PERIOD_D1,1);
      if(h1>0.0 && l1>0.0 && c1>0.0)
      {
         g_pivot=(h1+l1+c1)/3.0;
         g_r1=2.0*g_pivot-l1;
         g_s1=2.0*g_pivot-h1;
      }
      g_traded_day_long=0; g_traded_day_short=0;   // fresh session, allow one trade per direction again
   }
   if(g_pivot<=0.0) return;

   if(OwnPos()) return;
   if(!RiskOk()) return;
   if(!InSession(GmtHourOf(TimeCurrent()))) return;

   const double atr=Buf1(g_atr,1); if(atr<=0.0) return;
   const double c1w=iClose(_Symbol,PERIOD_CURRENT,1), o1w=iOpen(_Symbol,PERIOD_CURRENT,1);

   const bool longSig = _04_BuyOk  && (g_traded_day_long!=today)  && (c1w>g_r1) && (c1w>o1w);
   const bool shortSig= _04_SellOk && (g_traded_day_short!=today) && (c1w<g_s1) && (c1w<o1w);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double slDist=_02_SlAtrMult*atr;

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=ask-slDist, tp=ask+_02_TpRR*slDist;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN PIVOT-BUY @%.2f R1=%.2f",ask,g_r1); g_traded_day_long=today; return; }
      if(g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"PIVOT_BUY")) g_traded_day_long=today; }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=bid+slDist, tp=bid-_02_TpRR*slDist;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN PIVOT-SELL @%.2f S1=%.2f",bid,g_s1); g_traded_day_short=today; return; }
      if(g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"PIVOT_SELL")) g_traded_day_short=today; }
}
