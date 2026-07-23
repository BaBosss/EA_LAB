//+------------------------------------------------------------------+
//| (TRND)_GapContinuation_XAU_rev01.mq5                              |
//|                                                                    |
//| New idea — Gap Continuation (momentum). Distinct from every other  |
//| EA in the cohort: reference is the OVERNIGHT/SESSION-BOUNDARY      |
//| price GAP (yesterday's D1 close vs today's D1 open), not an        |
//| intraday range/breakout/pullback. XAU frequently gaps on           |
//| overnight macro news (rates, geopolitics) and continuation ("gap   |
//| and go") is a documented momentum pattern, distinct from S5        |
//| Asian-drift-carry (measures INTRADAY session drift, not the        |
//| overnight close-to-open gap itself) and from every breakout EA     |
//| (those react to an intraday range, not a discrete overnight jump). |
//|                                                                    |
//| Entry (long; mirror short): at the first working-TF bar of the D1  |
//| session, gap = D1Open[0] - D1Close[1]. If |gap| >= MinGapAtrMult *  |
//| ATR(D1) -> enter in the gap direction (continuation). SL = far side |
//| of the gap (capped), TP = TpRR*risk. One trade/day, force-flat at   |
//| FlatGmt.                                                            |
//|                                                                    |
//| L1: one position, real SL/TP, fixed lot, bar-open gated,           |
//| magic-scoped, hard caps. No grid/martingale. Magic 992016.        |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_GapContinuation_XAU_rev01 — D1 overnight-gap continuation, single-position, real SL/TP"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] GAP TRIGGER ───────────────────────";
input int    _01_AtrD1Period  = 14;
input double _01_MinGapAtrMult= 0.3;   // |gap| must be >= this * ATR(D1) to trade

input string _g02_            = "── [02] STOP / TARGET ─────────────────────";
input double _02_SlAtrMult    = 1.5;   // SL capped at this * ATR(D1) beyond entry
input double _02_TpRR         = 2.0;

input string _g03_            = "── [03] SESSION FLAT (GMT) ────────────────";
input int    _03_FlatGmt      = 20;
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992016;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atrD1=INVALID_HANDLE;
static datetime g_last_bar=0, g_traded_day=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return d.hour; }
datetime GmtDayOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return (datetime)(d.year*10000+d.mon*100+d.day); }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }
void CloseOwn(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) g_trade.PositionClose(t); } }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atrD1=iATR(_Symbol,PERIOD_D1,_01_AtrD1Period);
   if(g_atrD1==INVALID_HANDLE){ Print("GapContinuation: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_traded_day=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("GapContinuation init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atrD1!=INVALID_HANDLE)IndicatorRelease(g_atrD1); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<20) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_05_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_05_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   const int gmtHour=GmtHourOf(TimeCurrent());
   const bool own=OwnPos();
   if(gmtHour>=_03_FlatGmt){ if(own) CloseOwn(); return; }
   if(own) return;   // one position at a time (L1)

   if(!RiskOk()) return;
   const datetime gmtDay=GmtDayOf(TimeCurrent());
   if(g_traded_day==gmtDay) return;

   // gap = D1 bar[0]'s open (today, still forming) vs D1 bar[1]'s close (yesterday, closed)
   const double d1OpenToday=iOpen(_Symbol,PERIOD_D1,0), d1CloseYest=iClose(_Symbol,PERIOD_D1,1);
   if(d1OpenToday<=0.0 || d1CloseYest<=0.0) return;
   const double atrD1=Buf1(g_atrD1,1); if(atrD1<=0.0) return;
   const double gap=d1OpenToday-d1CloseYest;
   if(MathAbs(gap) < _01_MinGapAtrMult*atrD1) return;

   const bool longSig = _04_BuyOk  && (gap>0.0);
   const bool shortSig= _04_SellOk && (gap<0.0);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double slDist=_02_SlAtrMult*atrD1;

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=ask-slDist, tp=ask+_02_TpRR*slDist;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN GAP-BUY @%.2f gap=%.2f",ask,gap); g_traded_day=gmtDay; return; }
      if(g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"GAP_BUY")) g_traded_day=gmtDay; }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=bid+slDist, tp=bid-_02_TpRR*slDist;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN GAP-SELL @%.2f gap=%.2f",bid,gap); g_traded_day=gmtDay; return; }
      if(g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"GAP_SELL")) g_traded_day=gmtDay; }
}
