//+------------------------------------------------------------------+
//| (MR)_RangeFade_XAUc_rev01.mq5                                     |
//|                                                                    |
//| User Strategy 2 — "Range Fade" (2026-07-23 cent-scalp brief).      |
//| M5 20-bar Hi/Lo range: fade the edges, but ONLY when the range is  |
//| wide enough (>=MinRangePts) to be worth the spread. Trend          |
//| kill-switch: ADX(14) on M15 above AdxKillLevel disables entries    |
//| entirely (the user's own answer to "reversion dies in a trend").   |
//|                                                                    |
//| Entry (short at range top; mirror long at range bottom): range     |
//| width over the last N closed M5 bars >= MinRangePts AND close[1]   |
//| >= rangeHigh-TouchBufPts -> sell, target = range mid (TpMode=0)    |
//| or fixed TpPoints (TpMode=1); SL = SlPoints beyond the range edge. |
//|                                                                    |
//| L1: one position, real SL/TP, fixed lot, bar-open gated,           |
//| magic-scoped, hard caps. No grid/martingale. Magic 992012.        |
//+------------------------------------------------------------------+
#property strict
#property description "(MR)_RangeFade_XAUc_rev01 — 20-bar M5 range-edge fade with ADX trend kill-switch, single-position, real SL/TP"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] RANGE + TOUCH ─────────────────────";
input int    _01_RangeBars    = 20;
input int    _01_MinRangePts  = 1500;  // range width must be >= this many points (0.01=1pt on XAU -> 1500pt=$15)
input int    _01_TouchBufPts  = 20;    // "at the edge" = within this many points of the extreme

input string _g02_            = "── [02] TREND KILL-SWITCH ─────────────────";
input int    _02_AdxM15Period = 14;
input double _02_AdxKillLevel = 25.0;  // ADX(M15) above this -> no new entries (trend regime)

input string _g03_            = "── [03] TARGET / STOP ─────────────────────";
input int    _03_TpMode       = 0;     // 0 = target range midpoint, 1 = fixed _03_TpPoints
input int    _03_TpPoints     = 80;
input int    _03_SlPoints     = 50;    // beyond the touched edge

input string _g04_            = "── [04] SESSION (GMT hours) ───────────────";
input int    _04_StartGmt     = 0;
input int    _04_EndGmt       = 24;    // 24 = no restriction (range logic is session-agnostic by design)
input int    _04_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g05_            = "── [05] TRADE MGMT ────────────────────────";
input bool   _05_BuyOk        = true;
input bool   _05_SellOk       = true;
input double _05_LotSize      = 0.01;

input string _g06_            = "── [06] RISK CAPS ─────────────────────────";
input double _06_DailyLossPct = 3.0;
input double _06_EmergencyDdPct = 25.0;

input string _g07_            = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic        = 992012;
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

input string _g08_            = "── [08] D1 REGIME OVERLAY (default OFF, shared design, ADDS to the M15 ADX kill-switch) ";
input bool   _08_UseRegimeGate = false;  // default OFF = byte-identical baseline
input int    _08_AdxD1Period   = 14;
input double _08_AdxD1Max      = 20.0;   // require D1 ADX <= this (this EA WANTS non-trend, opposite sense of MomentumBurst)
input int    _08_SlopePersistDays = 10;  // require EMA(D1,50) slope NOT persistently one-way for this many days
                                          // (S2 wants a range regime: reject if D1 shows a real persistent
                                          // trend, complementing the existing M15 ADX kill-switch which is
                                          // shorter-horizon and noisier)

static bool     g_suppress_log=false;
static int      g_adxM15=INVALID_HANDLE, g_adxD1=INVALID_HANDLE, g_emaD1=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_04_ServerGmtOffset*3600,d); return d.hour; }
bool InSession(const int gh){ if(_04_StartGmt<=_04_EndGmt) return (gh>=_04_StartGmt && gh<_04_EndGmt); return (gh>=_04_StartGmt || gh<_04_EndGmt); }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) return true; } return false; }
double RangeHigh(const int n,const int sh){ double h=-1; for(int i=sh;i<sh+n;i++) h=MathMax(h,iHigh(_Symbol,PERIOD_CURRENT,i)); return h; }
double RangeLow (const int n,const int sh){ double l=1e18; for(int i=sh;i<sh+n;i++) l=MathMin(l,iLow(_Symbol,PERIOD_CURRENT,i)); return l; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_adxM15=iADX(_Symbol,PERIOD_M15,_02_AdxM15Period);
   if(g_adxM15==INVALID_HANDLE){ Print("RangeFade: ADX handle fail"); return INIT_FAILED; }
   if(_08_UseRegimeGate){
      g_adxD1=iADX(_Symbol,PERIOD_D1,_08_AdxD1Period);
      g_emaD1=iMA(_Symbol,PERIOD_D1,50,0,MODE_EMA,PRICE_CLOSE);
      if(g_adxD1==INVALID_HANDLE||g_emaD1==INVALID_HANDLE){ Print("RangeFade: regime handle fail"); return INIT_FAILED; }
   }
   g_trade.SetExpertMagicNumber(_07_Magic); g_trade.SetDeviationInPoints(_07_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("RangeFade init magic=%d AllowLive=%s",_07_Magic,_07_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_adxM15!=INVALID_HANDLE)IndicatorRelease(g_adxM15); if(g_adxD1!=INVALID_HANDLE)IndicatorRelease(g_adxD1); if(g_emaD1!=INVALID_HANDLE)IndicatorRelease(g_emaD1); }

// true = OK to trade a range-fade (D1 is NOT in a persistent trend): ADX(D1) below AdxD1Max OR
// slope sign hasn't held for SlopePersistDays. Complements the shorter-horizon M15 kill-switch.
bool RegimeOkForRange()
{
   if(!_08_UseRegimeGate) return true;
   double a[1]; if(CopyBuffer(g_adxD1,0,1,1,a)<1) return false;
   if(a[0] > _08_AdxD1Max) return false;
   double e[]; if(CopyBuffer(g_emaD1,0,1,_08_SlopePersistDays+1,e)<_08_SlopePersistDays+1) return false;
   ArraySetAsSeries(e,true);
   bool allUp=true, allDown=true;
   for(int i=0;i<_08_SlopePersistDays;i++){ if(e[i]<=e[i+1]) allUp=false; if(e[i]>=e[i+1]) allDown=false; }
   return !(allUp||allDown);   // reject if D1 has been persistently one-directional
}
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_06_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_06_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   if(OwnPos()) return;
   if(!RiskOk()) return;
   if(!InSession(GmtHourOf(TimeCurrent()))) return;
   if(Buf1(g_adxM15,1) > _02_AdxKillLevel) return;               // trend kill-switch
   if(!RegimeOkForRange()) return;                               // optional D1-level trend-persistence gate

   const double pt=_Point;
   const double rHi=RangeHigh(_01_RangeBars,1), rLo=RangeLow(_01_RangeBars,1);
   const double width=rHi-rLo;
   if(width < _01_MinRangePts*pt) return;                        // not worth the spread
   const double mid=(rHi+rLo)/2.0;
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double buf=_01_TouchBufPts*pt;

   const bool shortSig = _05_SellOk && (c1 >= rHi-buf);
   const bool longSig  = _05_BuyOk  && (!shortSig) && (c1 <= rLo+buf);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_07_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_05_LotSize < minLot){ if(!g_suppress_log) PrintFormat("RangeFade: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_05_LotSize,minLot); return; }

   if(shortSig){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=rHi+_03_SlPoints*pt;
      double tp=(_03_TpMode==0)? mid : bid-_03_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN RANGEFADE-SELL @%.2f",bid); return; }
      if(!g_trade.Sell(_05_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"RANGEFADE_SELL") && !g_suppress_log)
         PrintFormat("RANGEFADE-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=rLo-_03_SlPoints*pt;
      double tp=(_03_TpMode==0)? mid : ask+_03_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN RANGEFADE-BUY @%.2f",ask); return; }
      if(!g_trade.Buy(_05_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"RANGEFADE_BUY") && !g_suppress_log)
         PrintFormat("RANGEFADE-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
}
