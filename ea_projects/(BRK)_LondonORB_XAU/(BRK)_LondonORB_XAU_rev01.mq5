//+------------------------------------------------------------------+
//| (BRK)_LondonORB_XAU_rev01.mq5                                     |
//|                                                                    |
//| SS1 — London Opening Range Breakout (15m). The first hour of the  |
//| London session (07:00-08:00 GMT) sets the day's opening balance;  |
//| the day's first deep liquidity resolves that range directionally. |
//| Edge = the liquidity transition at London open. Distinct from the |
//| Asian-range EA: reference window is London's OWN opening hour and  |
//| the gate is an OR-width BAND (real range, not a news-blown one),   |
//| not Asian compression.                                            |
//|                                                                    |
//| Mechanics: build OR over 07:00-08:00 GMT. Require OR width in      |
//| [0.8, 2.5] * ATR(H1). Place OCO stop pair beyond the OR edges      |
//| (buffer = 0.1*ATR(15m)). On fill cancel the opposite. SL = far OR  |
//| side (cap 1.5*ATR_H1); TP = 2R. Cancel unfilled at 12:00 GMT;      |
//| force-flat at 16:00 GMT.                                           |
//|                                                                    |
//| Server time = GMT + _06_ServerGmtOffset (Exness = +3).            |
//| L1: one position, real SL, fixed lot, bar-open gated, magic-scoped |
//| hard caps. No grid/martingale. Magic 992003. Partial-TP is a       |
//| later mgmt lever; this L1 uses a single 2R target.                 |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_LondonORB_XAU_rev01 — London opening-range OCO breakout, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] SESSION (GMT hours) ───────────────";
input int    _01_OrStartGmt   = 7;     // opening-range start (London open, GMT hour)
input int    _01_OrEndGmt     = 8;     // opening-range end (GMT hour)
input int    _01_TradeEndGmt  = 12;    // cancel unfilled pendings at this GMT hour
input int    _01_FlatGmt      = 16;    // force-flat any open trade at this GMT hour

input string _g02_            = "── [02] OR-WIDTH BAND + BUFFER ────────────";
input int    _02_AtrH1Period  = 14;
input double _02_MinOrAtrH1   = 0.8;   // OR width must be >= this * ATR(H1) (real range)
input double _02_MaxOrAtrH1   = 2.5;   // ... and <= this * ATR(H1) (not news-blown)
input int    _02_AtrTfPeriod  = 14;    // ATR on the working TF (15m) for the buffer
input double _02_BufAtrTfMult = 0.10;  // stop-order buffer = this * ATR(TF)

input string _g03_            = "── [03] STOP / TARGET ─────────────────────";
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
input long   _06_Magic        = 992003;
input int    _06_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

input string _g07_            = "── [07] BUILD-ON LEVERS (default OFF) ─────";
input bool   _07_UseTrendFilter = false; // ON: only break in the EMA-direction (OCO becomes one-sided)
input int    _07_TrendEmaPeriod = 200;
input double _07_PartialPct     = 0.0;   // >0: close this %% of the position at +PartialAtR, then SL->BE
input double _07_PartialAtR      = 1.0;   // partial trigger, in R
                                          // NOTE: partial needs base lot >= 2*minlot (0.01 cannot be split)

static bool     g_suppress_log=false;
static int      g_atrH1=INVALID_HANDLE, g_atrTf=INVALID_HANDLE, g_ema=INVALID_HANDLE;
static ulong    g_partial_done=0;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
static datetime g_placed_day=0;

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

// Opening range for a gmtDay from closed working-TF bars.
bool OpeningRange(const datetime gmtDay,double &hi,double &lo)
{
   hi=-1; lo=1e18; bool any=false;
   for(int sh=1; sh<=40; sh++)
   {
      datetime bt=iTime(_Symbol,PERIOD_CURRENT,sh); if(bt<=0) break;
      if(GmtDayOf(bt)!=gmtDay){ if(any) break; else continue; }
      int gh=GmtHourOf(bt);
      if(gh>=_01_OrStartGmt && gh<_01_OrEndGmt){ hi=MathMax(hi,iHigh(_Symbol,PERIOD_CURRENT,sh)); lo=MathMin(lo,iLow(_Symbol,PERIOD_CURRENT,sh)); any=true; }
   }
   return any && hi>lo;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atrH1=iATR(_Symbol,PERIOD_H1,_02_AtrH1Period);
   g_atrTf=iATR(_Symbol,PERIOD_CURRENT,_02_AtrTfPeriod);
   if(g_atrH1==INVALID_HANDLE||g_atrTf==INVALID_HANDLE){ Print("LondonORB: handle fail"); return INIT_FAILED; }
   if(_07_UseTrendFilter){ g_ema=iMA(_Symbol,PERIOD_CURRENT,_07_TrendEmaPeriod,0,MODE_EMA,PRICE_CLOSE);
      if(g_ema==INVALID_HANDLE){ Print("LondonORB: EMA handle fail"); return INIT_FAILED; } }
   g_partial_done=0;
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false; g_placed_day=0;
   if(!g_suppress_log) PrintFormat("LondonORB init magic=%d gmtOff=%d AllowLive=%s",_06_Magic,_06_ServerGmtOffset,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atrH1!=INVALID_HANDLE)IndicatorRelease(g_atrH1); if(g_atrTf!=INVALID_HANDLE)IndicatorRelease(g_atrTf); if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); }

// normalize a volume to the symbol's lot step / min / max
double NormVol(double v)
{
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP), mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(st<=0.0) st=0.01;
   v=MathFloor(v/st)*st;
   if(v<mn) return 0.0;
   if(v>mx) v=mx;
   return NormalizeDouble(v,2);
}

// Partial-TP lever: at +PartialAtR, bank PartialPct%% and pull SL to breakeven.
void ManagePartial(const bool allow)
{
   if(_07_PartialPct<=0.0) return;
   for(int i=0;i<PositionsTotal();i++)
   {
      ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      if(g_partial_done==t) return;                                   // already banked on this ticket
      const bool isBuy=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      const double entry=PositionGetDouble(POSITION_PRICE_OPEN), sl=PositionGetDouble(POSITION_SL);
      if(sl<=0.0) return;
      const double R=MathAbs(entry-sl); if(R<=0.0) return;             // R from the still-original stop
      const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      const double prof=isBuy?(bid-entry):(entry-ask);
      if(prof < _07_PartialAtR*R) return;
      const double vol=PositionGetDouble(POSITION_VOLUME);
      const double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
      const double cut=NormVol(vol*_07_PartialPct/100.0);
      if(cut<=0.0 || (vol-cut)<mn) return;                            // cannot split (e.g. base lot == min lot)
      if(!allow) return;
      if(g_trade.PositionClosePartial(t,cut))
      {
         g_partial_done=t;
         const int dg=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
         g_trade.PositionModify(_Symbol,NormalizeDouble(entry,dg),PositionGetDouble(POSITION_TP));  // SL -> BE
      }
      return;
   }
}
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

   const datetime srv=TimeCurrent();
   const int gmtHour=GmtHourOf(srv);
   const datetime gmtDay=GmtDayOf(srv);
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);

   if(gmtHour>=_01_FlatGmt){ if(OwnPos()) CloseOwnPos(); if(OwnPendings()>0) DeletePendings(); return; }
   if(gmtHour>=_01_TradeEndGmt){ if(!OwnPos() && OwnPendings()>0) DeletePendings(); }
   if(OwnPos()){ if(OwnPendings()>0) DeletePendings(); ManagePartial(allow); return; }

   if(gmtHour>=_01_OrEndGmt && gmtHour<_01_TradeEndGmt && g_placed_day!=gmtDay)
   {
      g_placed_day=gmtDay;
      if(!RiskOk()) return;
      const double atrH1=Buf1(g_atrH1,1), atrTf=Buf1(g_atrTf,1);
      if(atrH1<=0.0||atrTf<=0.0) return;
      double hi,lo; if(!OpeningRange(gmtDay,hi,lo)) return;
      const double width=hi-lo;
      if(width < _02_MinOrAtrH1*atrH1 || width > _02_MaxOrAtrH1*atrH1) return;   // OR-width band gate

      const double buf=_02_BufAtrTfMult*atrTf;
      const double slCap=_03_SlCapAtrH1*atrH1;
      const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

      // trend-filter lever: when ON, only arm the side that agrees with the EMA (OCO -> one-sided)
      bool trendUp=true, trendDn=true;
      if(_07_UseTrendFilter){ const double ema=Buf1(g_ema,1), c1=iClose(_Symbol,PERIOD_CURRENT,1);
         if(ema<=0.0) return; trendUp=(c1>ema); trendDn=(c1<ema); }

      if(_04_BuyOk && trendUp){
         double entry=hi+buf; double sl=lo; if(entry-sl>slCap) sl=entry-slCap;
         double risk=entry-sl; double tp=entry+_03_TpRR*risk;
         if(entry>ask){ if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ORB-BUYSTOP @%.2f",entry); }
            else g_trade.BuyStop(_04_LotSize,NormalizeDouble(entry,digits),_Symbol,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),ORDER_TIME_GTC,0,"ORB_BUYSTOP"); } }
      if(_04_SellOk && trendDn){
         double entry=lo-buf; double sl=hi; if(sl-entry>slCap) sl=entry+slCap;
         double risk=sl-entry; double tp=entry-_03_TpRR*risk;
         if(entry<bid){ if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ORB-SELLSTOP @%.2f",entry); }
            else g_trade.SellStop(_04_LotSize,NormalizeDouble(entry,digits),_Symbol,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),ORDER_TIME_GTC,0,"ORB_SELLSTOP"); } }
   }
}
