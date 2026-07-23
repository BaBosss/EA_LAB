//+------------------------------------------------------------------+
//| (MR)_VwapSnapback_EUR_rev01.mq5                                    |
//|                                                                    |
//| Idea A — VWAP-distance snapback (mean-reversion). Distinct from    |
//| (VWAP)_WaveS1 (a CONTINUATION EA: waits for acceptance beyond the  |
//| band then trades the pullback IN the breakout direction). This EA |
//| does the opposite: when price stretches an EXTREME distance from  |
//| session VWAP (institutional fair value), it tends to snap back    |
//| toward it — a classic reversion mechanism, distinct from RSI/BB    |
//| oscillators the lab has already smoked dead. Reversion signals    |
//| are "guilty until proven" here -> placed on a RANGER (EURUSD), not |
//| XAU, per the right-home rule.                                     |
//|                                                                    |
//| Entry (long; mirror short): close[1] <= VWAP - ExtendSigma*sigma   |
//| (price stretched far below fair value) AND close[1] > close[2]     |
//| (already turning back up) -> buy, target = VWAP itself (TP),      |
//| SL = ExtendSigma+SlBufSigma*sigma beyond entry. Session-gated       |
//| (skip the illiquid EOD/weekend edges). VWAP resets daily.          |
//|                                                                    |
//| L1: one position, real SL, fixed lot, bar-open gated, magic-scoped |
//| hard caps. No grid/martingale. Magic 992007.                      |
//+------------------------------------------------------------------+
#property strict
#property description "(MR)_VwapSnapback_EUR_rev01 — daily-VWAP extreme-distance snapback, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] VWAP + BAND ───────────────────────";
input int    _01_SigmaLookback= 60;    // bars used to estimate sigma of (price-VWAP)
input double _01_ExtendSigma  = 2.5;   // entry trigger: distance from VWAP, in sigma
input double _01_SlBufSigma   = 0.5;   // SL sits this far beyond the trigger distance

input string _g02_            = "── [02] SESSION (GMT hours) ───────────────";
input int    _02_StartGmt     = 2;
input int    _02_EndGmt       = 21;
input int    _02_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g03_            = "── [03] TRADE MGMT ────────────────────────";
input bool   _03_BuyOk        = true;
input bool   _03_SellOk       = true;
input double _03_LotSize      = 0.01;

input string _g04_            = "── [04] RISK CAPS ─────────────────────────";
input double _04_DailyLossPct = 5.0;
input double _04_EmergencyDdPct = 25.0;

input string _g05_            = "── [05] SYSTEM ────────────────────────────";
input long   _05_Magic        = 992007;
input ulong  _05_Deviation    = 20;
input bool   _05_AllowLive    = false;

static bool     g_suppress_log=false;
static datetime g_last_bar=0, g_vwap_day=0;
static double   g_vwap_pv=0.0, g_vwap_v=0.0;     // running sums for today's VWAP
static double   g_dist_hist[];                    // rolling (price-VWAP) samples for sigma
static int      g_dist_n=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_02_ServerGmtOffset*3600,d); return d.hour; }
datetime DayOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv,d); return (datetime)(d.year*10000+d.mon*100+d.day); }
bool OwnPos(const long magic){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   ArrayResize(g_dist_hist,_01_SigmaLookback); ArrayInitialize(g_dist_hist,0.0);
   g_dist_n=0; g_vwap_day=0; g_vwap_pv=0.0; g_vwap_v=0.0;
   g_trade.SetExpertMagicNumber(_05_Magic); g_trade.SetDeviationInPoints(_05_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("VwapSnapback init magic=%d AllowLive=%s",_05_Magic,_05_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){}
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_04_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_04_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   // roll VWAP forward using the just-closed bar (bar[1]) and reset at day boundary
   const datetime day1=DayOf(iTime(_Symbol,PERIOD_CURRENT,1));
   if(day1!=g_vwap_day){ g_vwap_day=day1; g_vwap_pv=0.0; g_vwap_v=0.0; }
   const double tp1=(iHigh(_Symbol,PERIOD_CURRENT,1)+iLow(_Symbol,PERIOD_CURRENT,1)+iClose(_Symbol,PERIOD_CURRENT,1))/3.0;
   const double vol1=(double)iTickVolume(_Symbol,PERIOD_CURRENT,1);
   g_vwap_pv+=tp1*vol1; g_vwap_v+=vol1;
   if(g_vwap_v<=0.0) return;
   const double vwap=g_vwap_pv/g_vwap_v;

   // maintain rolling sigma of (close-vwap)
   const double dist=iClose(_Symbol,PERIOD_CURRENT,1)-vwap;
   for(int i=_01_SigmaLookback-1;i>0;i--) g_dist_hist[i]=g_dist_hist[i-1];
   g_dist_hist[0]=dist; if(g_dist_n<_01_SigmaLookback) g_dist_n++;
   if(g_dist_n<_01_SigmaLookback) return;                          // wait for full window
   double mean=0.0; for(int i=0;i<_01_SigmaLookback;i++) mean+=g_dist_hist[i]; mean/=_01_SigmaLookback;
   double var=0.0; for(int i=0;i<_01_SigmaLookback;i++){ double e=g_dist_hist[i]-mean; var+=e*e; } var/=_01_SigmaLookback;
   const double sigma=MathSqrt(var); if(sigma<=0.0) return;

   if(OwnPos(_05_Magic)) return;
   if(!RiskOk()) return;
   const int gmtHour=GmtHourOf(TimeCurrent());
   if(gmtHour<_02_StartGmt || gmtHour>=_02_EndGmt) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_05_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), c2=iClose(_Symbol,PERIOD_CURRENT,2);
   const double lo=vwap-_01_ExtendSigma*sigma, hi=vwap+_01_ExtendSigma*sigma;

   const bool longSig = _03_BuyOk  && (c1<=lo) && (c1>c2);   // stretched low, already turning up
   const bool shortSig= _03_SellOk && (c1>=hi) && (c1<c2);   // stretched high, already turning down
   if(!longSig && !shortSig) return;

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=vwap-(_01_ExtendSigma+_01_SlBufSigma)*sigma, tp=vwap;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN VWAPSNAP-BUY @%.5f",ask); return; }
      g_trade.Buy(_03_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"VWAPSNAP_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=vwap+(_01_ExtendSigma+_01_SlBufSigma)*sigma, tp=vwap;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN VWAPSNAP-SELL @%.5f",bid); return; }
      g_trade.Sell(_03_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"VWAPSNAP_SELL"); }
}
