//+------------------------------------------------------------------+
//| (MR)_EmaScalp_XAUc_rev01.mq5                                      |
//|                                                                    |
//| User Strategy 1 — "EMA Mean Reversion Scalp" (2026-07-23 brief,    |
//| cent-account XAU scalp portfolio, core template for Strategies    |
//| 2-5). Reversion class -> guilty until proven per signal-scanner;   |
//| this is the FIRST test, not a pre-validated edge.                 |
//|                                                                    |
//| Mechanism: when M1 close strays >= ExtendAtrMult*ATR(14) from       |
//| EMA(8), fade back toward the mean. TP/SL are points on the        |
//| symbol's own tick size (works identically on XAUUSD/XAUUSDc --     |
//| cent-account convention mirrors standard pricing 1:1, only the    |
//| account currency differs). Spread-gated (skip if current spread   |
//| exceeds MaxSpreadPts -- the whole point-budget in this brief is a  |
//| race against a 20-30pt spread). Session-gated 14:00-23:00 Thai     |
//| (=07:00-16:00 GMT, input as GMT hours + Exness offset like the     |
//| rest of the cohort).                                              |
//|                                                                    |
//| ARCHITECTURE NOTE vs the rest of this cohort: every other EA here  |
//| gates ALL logic on bar-open (once per bar). This one must NOT --   |
//| the 7-minute TIME EXIT has no broker-side order type, so it has to |
//| be checked on every tick against POSITION_TIME. Entries stay       |
//| bar-gated (avoid re-firing mid-bar); the time-exit check runs      |
//| every tick, independent of the bar gate.                          |
//|                                                                    |
//| L1: one position, real SL/TP, fixed lot, magic-scoped, hard caps.  |
//| No grid/martingale. Magic 992011.                                 |
//+------------------------------------------------------------------+
#property strict
#property description "(MR)_EmaScalp_XAUc_rev01 — M1 EMA-distance mean-reversion scalp, single-position, real SL/TP + time-exit"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] EMA-DISTANCE TRIGGER ──────────────";
input int    _01_EmaPeriod    = 8;
input int    _01_AtrPeriod    = 14;
input double _01_ExtendAtrMult= 1.5;   // fade when |close-EMA| >= this * ATR(14)

input string _g02_            = "── [02] STOP / TARGET / TIME-EXIT ─────────";
input int    _02_TpPoints     = 60;    // in symbol points (_Point) -- must beat the spread on its own
input int    _02_SlPoints     = 60;    // rev01 default was 90 (needs 60% WR to breakeven); 60 = 1:1 RR, 50% WR breakeven
input int    _02_TimeExitSec  = 420;   // 7 minutes; checked every tick, not bar-gated

input string _g03_            = "── [03] SPREAD + SESSION ──────────────────";
input int    _03_MaxSpreadPts = 30;    // skip new entries if current spread exceeds this
input int    _03_StartGmt     = 7;     // 14:00 Thai (UTC+7) = 07:00 GMT
input int    _03_EndGmt       = 16;    // 23:00 Thai (UTC+7) = 16:00 GMT
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 3.0;   // brief specifies 3% daily stop (tighter than the cohort default 5%)
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992011;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_ema=INVALID_HANDLE, g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_03_ServerGmtOffset*3600,d); return d.hour; }
bool OwnSelect(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_ema=iMA(_Symbol,PERIOD_CURRENT,_01_EmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_ema==INVALID_HANDLE||g_atr==INVALID_HANDLE){ Print("EmaScalp: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("EmaScalp init magic=%d symbol=%s point=%.5f AllowLive=%s",_06_Magic,_Symbol,_Point,_06_AllowLive?"Y":"N");
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
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);

   // ---- time-exit: runs EVERY TICK, independent of the bar gate (no broker-side order for this) ----
   if(OwnSelect())
   {
      const long openTime=(long)PositionGetInteger(POSITION_TIME);
      if((long)TimeCurrent()-openTime >= _02_TimeExitSec)
      {
         if(allow) g_trade.PositionClose(_Symbol);
         else if(!g_suppress_log) PrintFormat("DRYRUN time-exit @%s",TimeToString(TimeCurrent()));
      }
      return;   // one position at a time (L1) -- no new entry while one is open
   }

   // ---- entry: bar-gated (avoid re-firing on every tick of the same bar) ----
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;

   if(!RiskOk()) return;
   const int gmtHour=GmtHourOf(TimeCurrent());
   if(gmtHour<_03_StartGmt || gmtHour>=_03_EndGmt) return;
   const long spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread>_03_MaxSpreadPts) return;                          // the core lever this brief is built around

   const double atr=Buf1(g_atr,1); if(atr<=0.0) return;
   const double ema=Buf1(g_ema,1);
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), c2=iClose(_Symbol,PERIOD_CURRENT,2);
   const double dist=c1-ema;
   const bool stretched=(MathAbs(dist) >= _01_ExtendAtrMult*atr);
   if(!stretched) return;

   // fade back toward EMA: stretched below -> buy, stretched above -> sell
   const bool longSig = _04_BuyOk  && (dist<0.0);
   const bool shortSig= _04_SellOk && (dist>0.0);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double pt=_Point;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_04_LotSize < minLot){ if(!g_suppress_log) PrintFormat("EmaScalp: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_04_LotSize,minLot); return; }

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=ask-_02_SlPoints*pt, tp=ask+_02_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN EMASCALP-BUY @%.5f",ask); return; }
      if(!g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"EMASCALP_BUY") && !g_suppress_log)
         PrintFormat("EMASCALP-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=bid+_02_SlPoints*pt, tp=bid-_02_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN EMASCALP-SELL @%.5f",bid); return; }
      if(!g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"EMASCALP_SELL") && !g_suppress_log)
         PrintFormat("EMASCALP-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
}
