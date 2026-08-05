//+------------------------------------------------------------------+
//| (BRK)_AsianRange_XAU_rev01.mq5                                    |
//|                                                                    |
//| S5 — Asian Range Breakout at London Open. Gold builds a narrow    |
//| accumulation range during the thin Asian session; London open     |
//| (07:00 GMT) injects the day's first deep liquidity + fixing flow  |
//| that resolves the range directionally. Edge = the liquidity        |
//| TRANSITION at a known time, not the compression itself.            |
//|                                                                    |
//| Mechanics: measure the Asian range (00:00-07:00 GMT). Only if it   |
//| is NARROW (<= 0.3*ATR_D1) place an OCO pair of stop orders just    |
//| beyond the range edges. On fill, cancel the opposite. SL = far     |
//| range side (capped 1.5*ATR_H1); TP = 2R. Cancel unfilled at        |
//| 10:00 GMT; time-exit any open trade at 14:00 GMT.                  |
//|                                                                    |
//| Server time = GMT + _06_ServerGmtOffset (Exness = +3). All session |
//| gates are computed in GMT via that offset.                        |
//|                                                                    |
//| L1: one position at a time, real SL, fixed lot, bar-open gated,    |
//| magic-scoped, hard caps. No grid/martingale. Magic 992002.        |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_AsianRange_XAU_rev01 — narrow Asian-range OCO breakout at London open, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] SESSION (GMT hours) ───────────────";
input int    _01_AsiaStartGmt = 0;     // Asian range window start (GMT hour)
input int    _01_AsiaEndGmt   = 7;     // Asian range end / London open (GMT hour)
input int    _01_TradeEndGmt  = 10;    // stop accepting fills (cancel pendings) at this GMT hour
input int    _01_FlatGmt      = 14;    // force-flat any open trade at this GMT hour

input string _g02_            = "── [02] NARROW-RANGE GATE + BUFFER ────────";
input int    _02_AtrD1Period  = 14;
input double _02_MaxRangeAtrD1 = 0.30; // trade only if Asia range <= this * ATR(D1)
input double _02_BufAtrH1Mult = 0.10;  // stop-order buffer beyond range edge = this * ATR(H1)

input string _g03_            = "── [03] STOP / TARGET ─────────────────────";
input int    _03_AtrH1Period  = 14;
input double _03_SlCapAtrH1   = 1.5;   // cap SL distance at this * ATR(H1)
input double _03_TpRR         = 2.0;   // TP = this * risk (R multiple)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992002;
input int    _06_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atrD1=INVALID_HANDLE, g_atrH1=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
static datetime g_placed_day=0;   // gmtDay we already attempted placement for

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }

int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv,d); return ((d.hour - _06_ServerGmtOffset)%24 + 24)%24; }
datetime GmtDayOf(const datetime srv){ datetime g=srv - (datetime)_06_ServerGmtOffset*3600; MqlDateTime d; TimeToStruct(g,d); return (datetime)(d.year*10000+d.mon*100+d.day); }

bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }
int  OwnPendings(){ int n=0; for(int i=0;i<OrdersTotal();i++){ ulong t=OrderGetTicket(i); if(!OrderSelect(t)) continue;
   if(OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==_06_Magic) n++; } return n; }
void DeletePendings(){ for(int i=OrdersTotal()-1;i>=0;i--){ ulong t=OrderGetTicket(i); if(!OrderSelect(t)) continue;
   if(OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==_06_Magic) g_trade.OrderDelete(t); } }
void CloseOwnPos(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) g_trade.PositionClose(t); } }

// Asian range for a given gmtDay from closed M30 bars. returns false if no bars found.
bool AsiaRange(const datetime gmtDay,double &hi,double &lo)
{
   hi=-1; lo=1e18; bool any=false;
   for(int sh=1; sh<=40; sh++)
   {
      datetime bt=iTime(_Symbol,PERIOD_CURRENT,sh); if(bt<=0) break;
      if(GmtDayOf(bt)!=gmtDay) { if(any) break; else continue; }
      int gh=GmtHourOf(bt);
      if(gh>=_01_AsiaStartGmt && gh<_01_AsiaEndGmt){ hi=MathMax(hi,iHigh(_Symbol,PERIOD_CURRENT,sh)); lo=MathMin(lo,iLow(_Symbol,PERIOD_CURRENT,sh)); any=true; }
   }
   return any && hi>lo;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atrD1=iATR(_Symbol,PERIOD_D1,_02_AtrD1Period);
   g_atrH1=iATR(_Symbol,PERIOD_H1,_03_AtrH1Period);
   if(g_atrD1==INVALID_HANDLE||g_atrH1==INVALID_HANDLE){ Print("AsianRange: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false; g_placed_day=0;
   if(!g_suppress_log) PrintFormat("AsianRange init magic=%d gmtOff=%d AllowLive=%s",_06_Magic,_06_ServerGmtOffset,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atrD1!=INVALID_HANDLE)IndicatorRelease(g_atrD1); if(g_atrH1!=INVALID_HANDLE)IndicatorRelease(g_atrH1); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_05_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_05_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate (M30)

   const datetime srv=TimeCurrent();
   const int gmtHour=GmtHourOf(srv);
   const datetime gmtDay=GmtDayOf(srv);
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);

   // 1) force-flat window
   if(gmtHour>=_01_FlatGmt){ if(OwnPos()) CloseOwnPos(); if(OwnPendings()>0) DeletePendings(); return; }

   // 2) cancel unfilled pendings after trade window
   if(gmtHour>=_01_TradeEndGmt){ if(!OwnPos() && OwnPendings()>0) DeletePendings(); }

   // 3) OCO: a fill cancels the opposite pending
   if(OwnPos()){ if(OwnPendings()>0) DeletePendings(); return; }

   // 4) placement once per gmtDay at London open
   if(gmtHour>=_01_AsiaEndGmt && gmtHour<_01_TradeEndGmt && g_placed_day!=gmtDay)
   {
      g_placed_day=gmtDay;                       // mark attempted (no retry same day)
      if(!RiskOk()) return;
      const double atrD1=Buf1(g_atrD1,1), atrH1=Buf1(g_atrH1,1);
      if(atrD1<=0.0||atrH1<=0.0) return;
      double hi,lo; if(!AsiaRange(gmtDay,hi,lo)) return;
      const double range=hi-lo;
      if(range>_02_MaxRangeAtrD1*atrD1) return;   // not narrow enough -> skip today

      const double buf=_02_BufAtrH1Mult*atrH1;
      const double slCap=_03_SlCapAtrH1*atrH1;
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

      if(_04_BuyOk){
         double entry=hi+buf; double sl=lo; if(entry-sl>slCap) sl=entry-slCap;
         double risk=entry-sl; double tp=entry+_03_TpRR*risk;
         if(entry>ask){ if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ASIA-BUYSTOP @%.2f",entry); }
            else g_trade.BuyStop(_04_LotSize,NormalizeDouble(entry,digits),_Symbol,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),ORDER_TIME_GTC,0,"ASIA_BUYSTOP"); } }
      if(_04_SellOk){
         double entry=lo-buf; double sl=hi; if(sl-entry>slCap) sl=entry+slCap;
         double risk=sl-entry; double tp=entry-_03_TpRR*risk;
         if(entry<bid){ if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ASIA-SELLSTOP @%.2f",entry); }
            else g_trade.SellStop(_04_LotSize,NormalizeDouble(entry,digits),_Symbol,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),ORDER_TIME_GTC,0,"ASIA_SELLSTOP"); } }
   }
}
