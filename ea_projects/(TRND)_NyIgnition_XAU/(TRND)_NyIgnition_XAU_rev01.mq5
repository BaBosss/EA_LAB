//+------------------------------------------------------------------+
//| (TRND)_NyIgnition_XAU_rev01.mq5                                   |
//|                                                                    |
//| SS2 — NY Session Momentum Ignition (15m). The US open (13:30 GMT) |
//| reprices real yields — gold's dominant driver. The first strong   |
//| 15m impulse after 13:30 tends to extend as US flow dominates.     |
//| Ride the ignition. Distinct from S8 (event-gated post-news): SS2  |
//| fires EVERY session on a body-size trigger, no calendar needed.   |
//|                                                                    |
//| Entry: the first bar whose OPEN is in [13:30,15:00) GMT that       |
//| closes with body >= 0.7*ATR(15m) AND agrees with EMA50 slope ->    |
//| market entry same direction, one trade/day. SL=1.3*ATR, TP=2*ATR; |
//| after +1R switch to a 1.5*ATR Chandelier trail. Force-flat 20:00. |
//|                                                                    |
//| L1: one position, real SL, fixed lot, bar-open gated, magic-scoped |
//| hard caps. No grid/martingale. Magic 992005. Server=GMT+offset.   |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_NyIgnition_XAU_rev01 — NY-open momentum ignition, single-position, real SL + post-1R trail"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] NY IGNITION TRIGGER ───────────────";
input int    _01_SigStartGmtH = 13;    // signal window start hour (GMT)
input int    _01_SigStartMin  = 30;    // ... and minute
input int    _01_SigEndGmtH   = 15;    // signal window end hour (GMT, exclusive)
input int    _01_EmaSlope     = 50;    // slope reference EMA
input int    _01_AtrPeriod    = 14;
input double _01_BodyAtrMult  = 0.7;   // require |close-open| >= this * ATR (real impulse)

input string _g02_            = "── [02] STOP / TARGET / TRAIL ─────────────";
input double _02_SlAtrMult    = 1.3;
input double _02_TpAtrMult    = 2.0;
input double _02_TrailAtrMult = 1.5;   // Chandelier trail after +1R
input double _02_TrailAfterR  = 1.0;   // start trailing once profit >= this * R

input string _g03_            = "── [03] SESSION FLAT (GMT) ────────────────";
input int    _03_FlatGmtH     = 20;    // force-flat at this GMT hour
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992005;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_ema=INVALID_HANDLE, g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
static datetime g_traded_day=0;

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
datetime ToGmt(const datetime srv){ return srv - (datetime)_03_ServerGmtOffset*3600; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(ToGmt(srv),d); return d.hour; }
datetime GmtDayOf(const datetime srv){ MqlDateTime d; TimeToStruct(ToGmt(srv),d); return (datetime)(d.year*10000+d.mon*100+d.day); }

int OwnDir(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic)
      return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?+1:-1; } return 0; }
bool OwnSelect(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }
void CloseOwn(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) g_trade.PositionClose(t); } }

// is bar[1]'s OPEN time inside the [start, end) GMT signal window?
bool InSignalWindow()
{
   datetime bt=iTime(_Symbol,PERIOD_CURRENT,1); if(bt<=0) return false;
   MqlDateTime d; TimeToStruct(ToGmt(bt),d);
   int startMinOfDay=_01_SigStartGmtH*60+_01_SigStartMin;
   int endMinOfDay  =_01_SigEndGmtH*60;
   int m=d.hour*60+d.min;
   return (m>=startMinOfDay && m<endMinOfDay);
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_ema=iMA(_Symbol,PERIOD_CURRENT,_01_EmaSlope,0,MODE_EMA,PRICE_CLOSE);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_ema==INVALID_HANDLE||g_atr==INVALID_HANDLE){ Print("NyIgnition: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false; g_traded_day=0;
   if(!g_suppress_log) PrintFormat("NyIgnition init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
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

   const double atr=Buf(g_atr,0,1); if(atr<=0.0) return;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const int gmtHour=GmtHourOf(TimeCurrent());
   const int dir=OwnDir();

   // force-flat at session end
   if(gmtHour>=_03_FlatGmtH){ if(dir!=0) CloseOwn(); return; }

   // manage: trail after +1R
   if(dir!=0)
   {
      if(OwnSelect())
      {
         double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID), ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double R=_02_SlAtrMult*atr;
         double prof=(dir>0)?(bid-entry):(entry-ask);
         if(prof>=_02_TrailAfterR*R)
         {
            double newSL=(dir>0)?(bid-_02_TrailAtrMult*atr):(ask+_02_TrailAtrMult*atr);
            newSL=NormalizeDouble(newSL,digits);
            double curSL=PositionGetDouble(POSITION_SL);
            bool improve=(dir>0)?(newSL>curSL):(curSL==0.0||newSL<curSL);
            if(improve && allow) g_trade.PositionModify(_Symbol,newSL,PositionGetDouble(POSITION_TP));
         }
      }
      return;
   }

   // entry: first qualifying impulse bar in the NY window, one/day
   if(!RiskOk()) return;
   if(GmtDayOf(TimeCurrent())==g_traded_day) return;
   if(!InSignalWindow()) return;

   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   const double body=MathAbs(c1-o1);
   if(body < _01_BodyAtrMult*atr) return;                 // not a real impulse
   const double emaNow=Buf(g_ema,0,1), emaPrev=Buf(g_ema,0,2);
   const bool slopeUp=(emaNow>emaPrev), slopeDn=(emaNow<emaPrev);

   const bool longSig = _04_BuyOk  && (c1>o1) && slopeUp;
   const bool shortSig= _04_SellOk && (c1<o1) && slopeDn;
   if(!longSig && !shortSig) return;

   double sl=_02_SlAtrMult*atr, tp=_02_TpAtrMult*atr;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_04_LotSize < minLot){ if(!g_suppress_log) PrintFormat("NyIgnition: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_04_LotSize,minLot); return; }

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN NYIG-BUY @%.2f",ask); return; }
      if(g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"NYIG_BUY")) g_traded_day=GmtDayOf(TimeCurrent());
      else if(!g_suppress_log) PrintFormat("NYIG-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN NYIG-SELL @%.2f",bid); return; }
      if(g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"NYIG_SELL")) g_traded_day=GmtDayOf(TimeCurrent());
      else if(!g_suppress_log) PrintFormat("NYIG-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
}
