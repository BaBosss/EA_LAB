//+------------------------------------------------------------------+
//| (MR)_AsianPingPong_XAUc_rev01.mq5                                  |
//|                                                                    |
//| User Strategy 4 — "Asian Session Grid-less Ping-Pong" (2026-07-23  |
//| cent-scalp brief). 05:00-13:00 Thai (=22:00-06:00 GMT, crosses      |
//| midnight -- session check supports wraparound) fade to Bollinger   |
//| (20,2) M5 band mid. ONE trade per direction at a time (explicit    |
//| user requirement: "ไม่ทบ" -- not a grid). Spread is the dominant   |
//| risk in this session per the brief (Asian spread widens more than  |
//| other sessions on this account) -> spread gate is the primary      |
//| lever, checked every entry.                                        |
//|                                                                    |
//| Entry (short at upper band; mirror long at lower band): close[1]   |
//| >= upperBand -> sell, target = midBand, SL = 2.5*currentSpread     |
//| beyond the band (the brief's own formula -- ties SL directly to    |
//| the spread that is this session's main threat).                   |
//|                                                                    |
//| L1 SIMPLIFICATION: chassis is single-position overall (not          |
//| "one per direction" independently) -- same one-position-at-a-time  |
//| discipline as the rest of the cohort. Documented deviation from    |
//| the brief's literal wording; the practical effect is the same      |
//| (no averaging/no stacking) since only one side can be open anyway. |
//|                                                                    |
//| L1: one position, real SL/TP, fixed lot, bar-open gated,           |
//| magic-scoped, hard caps. No grid/martingale. Magic 992014.        |
//+------------------------------------------------------------------+
#property strict
#property description "(MR)_AsianPingPong_XAUc_rev01 — Asian-session Bollinger-band fade to mid, single-position, spread-linked SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] BOLLINGER BAND ────────────────────";
input int    _01_BbPeriod     = 20;
input double _01_BbDeviation  = 2.0;

input string _g02_            = "── [02] STOP (spread-linked, per brief) ───";
input double _02_SlSpreadMult = 2.5;   // SL = this * current spread, beyond the touched band

input string _g03_            = "── [03] SESSION (GMT hours, wraps midnight)";
input int    _03_StartGmt     = 22;    // 05:00 Thai (UTC+7)
input int    _03_EndGmt       = 6;     // 13:00 Thai (UTC+7) -- wraps past midnight GMT
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)
input int    _03_MaxSpreadPts = 35;    // brief flags Asian spread as the dominant risk here

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 3.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992014;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_bbUp=INVALID_HANDLE, g_bbMid=INVALID_HANDLE, g_bbLo=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return d.hour; }
bool InSession(const int gh){ if(_03_StartGmt<=_03_EndGmt) return (gh>=_03_StartGmt && gh<_03_EndGmt); return (gh>=_03_StartGmt || gh<_03_EndGmt); }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_bbUp =iBands(_Symbol,PERIOD_CURRENT,_01_BbPeriod,0,_01_BbDeviation,PRICE_CLOSE);   // MODE_UPPER=1,MODE_MAIN=0,MODE_LOWER=2 in buffer index
   if(g_bbUp==INVALID_HANDLE){ Print("AsianPingPong: BB handle fail"); return INIT_FAILED; }
   g_bbMid=g_bbUp; g_bbLo=g_bbUp;   // same handle, different buffer indices used at read time
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("AsianPingPong init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_bbUp!=INVALID_HANDLE)IndicatorRelease(g_bbUp); }
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

   if(OwnPos()) return;
   if(!RiskOk()) return;
   if(!InSession(GmtHourOf(TimeCurrent()))) return;
   const long spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread>_03_MaxSpreadPts) return;                            // primary lever for this session per the brief

   const double upBand =Buf1(g_bbUp,1,1);   // MODE_UPPER
   const double midBand=Buf1(g_bbUp,0,1);   // MODE_MAIN
   const double loBand =Buf1(g_bbUp,2,1);   // MODE_LOWER
   if(upBand<=0.0 || loBand<=0.0) return;
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double pt=_Point;

   const bool shortSig = _04_SellOk && (c1>=upBand);
   const bool longSig  = _04_BuyOk  && (!shortSig) && (c1<=loBand);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double slDist=_02_SlSpreadMult*spread*pt;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_04_LotSize < minLot){ if(!g_suppress_log) PrintFormat("AsianPingPong: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_04_LotSize,minLot); return; }

   if(shortSig){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=upBand+slDist, tp=midBand;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN PINGPONG-SELL @%.2f",bid); return; }
      if(!g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"PINGPONG_SELL") && !g_suppress_log)
         PrintFormat("PINGPONG-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=loBand-slDist, tp=midBand;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN PINGPONG-BUY @%.2f",ask); return; }
      if(!g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"PINGPONG_BUY") && !g_suppress_log)
         PrintFormat("PINGPONG-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
}
