//+------------------------------------------------------------------+
//| (TRND)_AsianDriftCarry_XAU_rev01.mq5                              |
//|                                                                    |
//| Idea B — Asian-session drift carried into London (momentum/carry). |
//| Distinct from S5 AsianRange (breaks the Asian COMPRESSION range)   |
//| and SS1 LondonORB (breaks London's OWN opening-hour range): this   |
//| EA measures the Asian session's net directional DRIFT (close vs   |
//| open of the 00:00-07:00 GMT session) and, if that drift is         |
//| meaningful, trades London open IN THAT DIRECTION — a session-carry |
//| continuation, not a breakout of either session's own range.       |
//|                                                                    |
//| Entry: at the first working-TF bar at/after 07:00 GMT, compute     |
//| asianDrift = close(07:00) - open(00:00). If |asianDrift| >=         |
//| MinDriftAtr*ATR(H1) -> enter in the drift direction. SL =           |
//| SlAtrMult*ATR, TP = TpRR*risk. One trade/day, force-flat at         |
//| FlatGmt. Server time = GMT + ServerGmtOffset (Exness = +3).        |
//|                                                                    |
//| L1: one position, real SL, fixed lot, bar-open gated, magic-scoped |
//| hard caps. No grid/martingale. Magic 992008.                      |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_AsianDriftCarry_XAU_rev01 — Asian-session drift carried into London open, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] ASIAN SESSION + DRIFT TRIGGER ─────";
input int    _01_AsianStartGmt= 0;     // Asian session start (GMT hour)
input int    _01_AsianEndGmt  = 7;     // ... end / London open (GMT hour)
input int    _01_AtrH1Period  = 14;
input double _01_MinDriftAtr  = 0.5;   // |asianDrift| must be >= this * ATR(H1) to trade

input string _g02_            = "── [02] STOP / TARGET ─────────────────────";
input int    _02_AtrTfPeriod  = 14;    // ATR on the working TF for SL sizing
input double _02_SlAtrMult    = 1.5;
input double _02_TpRR         = 2.0;

input string _g03_            = "── [03] SESSION FLAT (GMT) ────────────────";
input int    _03_FlatGmt      = 16;
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992008;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atrH1=INVALID_HANDLE, g_atrTf=INVALID_HANDLE;
static datetime g_last_bar=0, g_traded_day=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
datetime ToGmt(const datetime srv){ return srv - (datetime)_03_ServerGmtOffset*3600; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(ToGmt(srv),d); return d.hour; }
datetime GmtDayOf(const datetime srv){ MqlDateTime d; TimeToStruct(ToGmt(srv),d); return (datetime)(d.year*10000+d.mon*100+d.day); }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }
void CloseOwn(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) g_trade.PositionClose(t); } }

// Asian session open/close (working-TF closed bars) for a GMT day
bool AsianOpenClose(const datetime gmtDay,double &openPx,double &closePx)
{
   openPx=0.0; closePx=0.0; bool any=false;
   for(int sh=1; sh<=60; sh++)
   {
      datetime bt=iTime(_Symbol,PERIOD_CURRENT,sh); if(bt<=0) break;
      if(GmtDayOf(bt)!=gmtDay){ if(any) break; else continue; }
      int gh=GmtHourOf(bt);
      if(gh>=_01_AsianStartGmt && gh<_01_AsianEndGmt)
      {
         if(!any){ closePx=iClose(_Symbol,PERIOD_CURRENT,sh); any=true; }  // most-recent (highest sh scanned first .. but we scan sh ascending from 1)
         openPx=iOpen(_Symbol,PERIOD_CURRENT,sh);                          // keeps overwriting -> ends on the earliest (largest sh) bar's open
      }
   }
   return any;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atrH1=iATR(_Symbol,PERIOD_H1,_01_AtrH1Period);
   g_atrTf=iATR(_Symbol,PERIOD_CURRENT,_02_AtrTfPeriod);
   if(g_atrH1==INVALID_HANDLE||g_atrTf==INVALID_HANDLE){ Print("AsianDriftCarry: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_traded_day=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("AsianDriftCarry init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atrH1!=INVALID_HANDLE)IndicatorRelease(g_atrH1); if(g_atrTf!=INVALID_HANDLE)IndicatorRelease(g_atrTf); }
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

   const int gmtHour=GmtHourOf(TimeCurrent());
   const int dir_own = OwnPos()?1:0;

   if(gmtHour>=_03_FlatGmt){ if(dir_own!=0) CloseOwn(); return; }
   if(dir_own!=0) return;                                    // one position, no management lever yet (L1)

   if(!RiskOk()) return;
   if(gmtHour!=_01_AsianEndGmt) return;                        // fire only on the London-open bar
   const datetime gmtDay=GmtDayOf(TimeCurrent());
   if(g_traded_day==gmtDay) return;

   const double atrH1=Buf1(g_atrH1,1); if(atrH1<=0.0) return;
   double aOpen,aClose; if(!AsianOpenClose(gmtDay,aOpen,aClose)) return;
   const double drift=aClose-aOpen;
   if(MathAbs(drift) < _01_MinDriftAtr*atrH1) return;          // drift too weak, no carry signal

   const bool longSig = _04_BuyOk  && (drift>0.0);
   const bool shortSig= _04_SellOk && (drift<0.0);
   if(!longSig && !shortSig) return;

   const double atrTf=Buf1(g_atrTf,1); if(atrTf<=0.0) return;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double sl=_02_SlAtrMult*atrTf, tp=_02_TpRR*sl;

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN DRIFT-BUY @%.2f",ask); g_traded_day=gmtDay; return; }
      if(g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"DRIFT_BUY")) g_traded_day=gmtDay; }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN DRIFT-SELL @%.2f",bid); g_traded_day=gmtDay; return; }
      if(g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"DRIFT_SELL")) g_traded_day=gmtDay; }
}
