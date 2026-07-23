//+------------------------------------------------------------------+
//| (MR)_PostNewsReversion_XAUc_rev01.mq5                              |
//|                                                                    |
//| User Strategy 5 — "Post-News Reversion" (2026-07-23 cent-scalp     |
//| brief). ⚠️ SUBSTITUTION, read before trusting any backtest number: |
//| MT5 Strategy Tester has no economic-calendar feed for historical   |
//| backtests -- there is no "15 minutes after NFP" signal available   |
//| offline. This EA instead detects a NEWS-LIKE EVENT MECHANICALLY:   |
//| a single M5 bar whose range is an outsized multiple of recent ATR  |
//| (a volatility spike proxy for "something just happened"), then     |
//| waits DelayBars, then checks distance from EMA(20) M5 the same way |
//| the brief specifies. This is NOT the same signal as a real news    |
//| feed -- a real news EA will catch scheduled releases this proxy    |
//| misses (or vice versa on unscheduled spikes), so verdict from this |
//| backtest characterizes the "overshoot-after-any-vol-spike" concept |
//| only, not "post-scheduled-news" specifically. If validated, a live |
//| deploy should gate on a real calendar feed, not this proxy.        |
//|                                                                    |
//| Entry (long; mirror short): SpikeBarAtrMult*ATR spike detected at   |
//| bar[DelayBars+1], DelayBars have since closed, AND close[1] is      |
//| >= ExtendPts beyond EMA(20) in the SAME direction as the spike      |
//| (overshoot continuing / not yet reverted) -> fade back toward the   |
//| mean. Half-lot per the brief (highest-risk satellite leg).          |
//|                                                                    |
//| L1: one position, real SL/TP, HALF fixed lot, bar-open gated,      |
//| magic-scoped, hard caps. No grid/martingale. Magic 992015.        |
//+------------------------------------------------------------------+
#property strict
#property description "(MR)_PostNewsReversion_XAUc_rev01 — vol-spike-proxy overshoot reversion (NOT a real news feed), single-position, real SL/TP, half-lot"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] SPIKE PROXY (stands in for 'news') ";
input int    _01_AtrPeriod    = 14;
input double _01_SpikeBarAtrMult = 3.0; // a bar this many x ATR = "news-like event" proxy trigger
input int    _01_DelayBars    = 3;      // wait this many CLOSED M5 bars after the spike (~15min at M5)

input string _g02_            = "── [02] OVERSHOOT TRIGGER ─────────────────";
input int    _02_EmaPeriod    = 20;
input int    _02_ExtendPts    = 250;    // fade once price is this many points beyond EMA(20)

input string _g03_            = "── [03] STOP / TARGET ─────────────────────";
input int    _03_TpPoints     = 120;
input int    _03_SlPoints     = 150;

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;   // ⚠️ rev01 bug: default 0.005 (brief's "half lot") was BELOW
                                          // XAU's broker min-lot (0.01) -> every order silently rejected,
                                          // 0 trades at ANY threshold (confirmed by isolation test 2026-07-23).
                                          // 0.01 is the smallest valid size on this symbol; "half of the
                                          // cohort's 0.01" is not achievable with fixed-lot sizing here.

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 3.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992015;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }

// find the most recent spike bar within a small look-back window; returns its shift and sign, or -1 if none
int FindSpike(const double atr,int &sign)
{
   sign=0;
   for(int sh=_01_DelayBars+1; sh<=_01_DelayBars+3; sh++)     // small tolerance window around the expected delay
   {
      double rng=iHigh(_Symbol,PERIOD_CURRENT,sh)-iLow(_Symbol,PERIOD_CURRENT,sh);
      if(rng >= _01_SpikeBarAtrMult*atr)
      {
         double c=iClose(_Symbol,PERIOD_CURRENT,sh), o=iOpen(_Symbol,PERIOD_CURRENT,sh);
         sign=(c>o)?+1:-1;
         return sh;
      }
   }
   return -1;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   g_ema=iMA(_Symbol,PERIOD_CURRENT,_02_EmaPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(g_atr==INVALID_HANDLE||g_ema==INVALID_HANDLE){ Print("PostNewsReversion: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("PostNewsReversion init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); }
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

   const double atr=Buf1(g_atr,1); if(atr<=0.0) return;
   int spikeSign=0;
   if(FindSpike(atr,spikeSign) < 0) return;                     // no recent spike-proxy event

   const double ema=Buf1(g_ema,1);
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double pt=_Point;
   const double dist=c1-ema;

   // fade the overshoot IN THE SAME DIRECTION AS THE SPIKE (spike up + still stretched up -> sell; mirror)
   const bool shortSig = _04_SellOk && (spikeSign>0) && (dist >= _02_ExtendPts*pt);
   const bool longSig  = _04_BuyOk  && (spikeSign<0) && (dist <= -_02_ExtendPts*pt);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);

   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_04_LotSize < minLot){ if(!g_suppress_log) PrintFormat("PostNewsReversion: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_04_LotSize,minLot); return; }

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=ask-_03_SlPoints*pt, tp=ask+_03_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN POSTNEWS-BUY @%.2f",ask); return; }
      if(!g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"POSTNEWS_BUY") && !g_suppress_log)
         PrintFormat("POSTNEWS-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=bid+_03_SlPoints*pt, tp=bid-_03_TpPoints*pt;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN POSTNEWS-SELL @%.2f",bid); return; }
      if(!g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"POSTNEWS_SELL") && !g_suppress_log)
         PrintFormat("POSTNEWS-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
}
