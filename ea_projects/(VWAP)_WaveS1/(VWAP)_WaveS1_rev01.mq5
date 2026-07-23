//+------------------------------------------------------------------+
//| (VWAP)_WaveS1_rev01.mq5                                           |
//|                                                                    |
//| VWAP Wave — Setup 1 "Price-Discovery Continuation", distilled      |
//| from the full VWAP Wave System spec (ORDER-064 conv 010) down to   |
//| ONE mechanism, no ML/Wyckoff/VolumeProfile bloat:                  |
//|                                                                    |
//|   VWAP = session (daily) anchored Σ(TP×tickVol)/Σ(tickVol).        |
//|   Bands = VWAP ± Mult1×σ where σ = vol-weighted stdev of TP−VWAP.  |
//|   ACCEPTANCE: >= AcceptBars consecutive closed bars beyond +band   |
//|   (price discovery, market left balance)... then                   |
//|   ENTRY: first closed bar that PULLS BACK to touch the band zone   |
//|   (close <= band+buf) while staying above VWAP -> continuation     |
//|   entry in the breakout direction. Symmetric for sells.            |
//|   SL = ATR×SlMult · TP = ATR×TpMult · optional flat at day end.    |
//|                                                                    |
//| Everything recomputed from the current day's bars each bar-open    |
//| (state-free, recompile-safe). Novel vs cohort: fair-value anchor   |
//| mechanism + intraday behavior — nothing in the cohort uses either. |
//|                                                                    |
//| L1: single position, real SL/TP, fixed lot, bar-open gated,        |
//| magic-scoped, hard caps. Magic 991007. Full funnel before demo.    |
//+------------------------------------------------------------------+
#property strict
#property description "(VWAP)_WaveS1_rev01 — daily-VWAP band continuation, single-position, intraday"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] VWAP / BANDS ──────────────────────";
input double _01_BandMult     = 1.0;   // band = VWAP +/- this x sigma
input int    _01_AcceptBars   = 3;     // closed bars beyond band = acceptance
input double _01_PullbackBufSigma = 0.25; // pullback zone width in sigma units
input int    _01_MinDayBars   = 12;    // need this many bars of the day before trading

input string _g02_            = "── [02] SL / TP / ATR ─────────────────────";
input int    _02_AtrPeriod    = 14;
input double _02_SlAtrMult    = 1.5;
input double _02_TpAtrMult    = 3.0;

input string _g03_            = "── [03] FILTERS / SESSION ─────────────────";
input bool   _03_UseEma       = false; // EMA200 optional (intraday: default off)
input int    _03_EmaPeriod    = 200;
input bool   _03_CloseEndOfDay= true;  // flat before the daily VWAP anchor resets
input int    _03_LastEntryHour= 20;    // no new entries at/after this server hour

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_Buys         = true;
input bool   _04_Sells        = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 991007;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
static datetime g_traded_day=0;         // one entry per day max (S1 fires once per discovery)

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }

bool OwnTicket(ulong &ticket){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic){ ticket=t; return true; } } ticket=0; return false; }

datetime DayStart(const datetime t){ return t - (t % 86400); }

// how many closed bars back to the start of bar-1's trading day (bar 1 = most recent closed)
int DayBarCount()
{
   datetime d1 = DayStart(iTime(_Symbol,PERIOD_CURRENT,1));
   int n = 0;
   for(int s = 1; s < 2000; s++)
   {
      if(DayStart(iTime(_Symbol,PERIOD_CURRENT,s)) != d1) break;
      n++;
   }
   return n;
}

// VWAP + sigma over the day's bars from oldest up to (and including) bar `uptoShift`
bool DayVwap(const int oldestShift, const int uptoShift, double &vwap, double &sigma)
{
   double sumPV=0, sumV=0, sumVar=0;
   for(int s = oldestShift; s >= uptoShift; s--)
   {
      double tp = (iHigh(_Symbol,PERIOD_CURRENT,s)+iLow(_Symbol,PERIOD_CURRENT,s)+iClose(_Symbol,PERIOD_CURRENT,s))/3.0;
      double v  = (double)iTickVolume(_Symbol,PERIOD_CURRENT,s);
      if(v <= 0) v = 1;
      sumPV += tp*v; sumV += v;
   }
   if(sumV <= 0) return false;
   vwap = sumPV/sumV;
   for(int s = oldestShift; s >= uptoShift; s--)
   {
      double tp = (iHigh(_Symbol,PERIOD_CURRENT,s)+iLow(_Symbol,PERIOD_CURRENT,s)+iClose(_Symbol,PERIOD_CURRENT,s))/3.0;
      double v  = (double)iTickVolume(_Symbol,PERIOD_CURRENT,s);
      if(v <= 0) v = 1;
      sumVar += v*(tp-vwap)*(tp-vwap);
   }
   sigma = MathSqrt(sumVar/sumV);
   return (sigma > 0);
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr = iATR(_Symbol,PERIOD_CURRENT,_02_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("VWAPWave: handle fail"); return INIT_FAILED; }
   if(_03_UseEma){ g_ema=iMA(_Symbol,PERIOD_CURRENT,_03_EmaPeriod,0,MODE_EMA,PRICE_CLOSE); if(g_ema==INVALID_HANDLE) return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false; g_traded_day=0;
   if(!g_suppress_log) PrintFormat("VWAPWave init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
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
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;

   MqlDateTime dtNow; TimeToStruct(TimeCurrent(), dtNow);

   // ---- manage open position: flat at end of day
   ulong tk=0;
   if(OwnTicket(tk))
   {
      if(_03_CloseEndOfDay)
      {
         datetime posDay = 0;
         if(PositionSelectByTicket(tk)) posDay = DayStart((datetime)PositionGetInteger(POSITION_TIME));
         if(posDay != 0 && DayStart(TimeCurrent()) != posDay) g_trade.PositionClose(tk);
      }
      return;
   }

   // ---- flat: look for S1 on the current day's closed bars
   if(!RiskOk()) return;
   if(dtNow.hour >= _03_LastEntryHour) return;
   datetime today = DayStart(iTime(_Symbol,PERIOD_CURRENT,1));
   if(g_traded_day == today) return;                      // one shot per day

   int nDay = DayBarCount();
   if(nDay < _01_MinDayBars) return;
   int oldest = nDay;                                     // oldest bar of bar-1's day (shift)

   // bands at each of the last AcceptBars+1 closed bars (computed with data up to that bar)
   // pattern: bars 2..AcceptBars+1 all CLOSED beyond band -> bar 1 pulls back into band zone
   const double atr=Buf(g_atr,0,1); if(atr<=0) return;
   double vw1=0, sg1=0;
   if(!DayVwap(oldest, 1, vw1, sg1)) return;
   double upper1 = vw1 + _01_BandMult*sg1, lower1 = vw1 - _01_BandMult*sg1;
   double buf = _01_PullbackBufSigma*sg1;

   bool acceptUp = true, acceptDn = true;
   for(int s = 2; s <= _01_AcceptBars+1; s++)
   {
      if(s > nDay) { acceptUp=false; acceptDn=false; break; }          // acceptance must be within today
      double vws=0, sgs=0;
      if(!DayVwap(oldest, s, vws, sgs)) { acceptUp=false; acceptDn=false; break; }
      double c = iClose(_Symbol,PERIOD_CURRENT,s);
      if(c <= vws + _01_BandMult*sgs) acceptUp = false;
      if(c >= vws - _01_BandMult*sgs) acceptDn = false;
      if(!acceptUp && !acceptDn) break;
   }

   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   double ema=_03_UseEma?Buf(g_ema,0,1):0.0;
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl=_02_SlAtrMult*atr, tp=_02_TpAtrMult*atr;

   // pullback: bar-1 close back inside the band zone but still on the breakout side of VWAP
   bool bull=_04_Buys  && acceptUp && (c1 <= upper1+buf) && (c1 > vw1) && (!_03_UseEma||c1>ema);
   bool bear=_04_Sells && acceptDn && (c1 >= lower1-buf) && (c1 < vw1) && (!_03_UseEma||c1<ema);
   if(!bull && !bear) return;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_04_LotSize < minLot){ if(!g_suppress_log) PrintFormat("WaveS1: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_04_LotSize,minLot); return; }

   if(bull){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN VWAP-BUY @%.2f",ask); return; }
      if(g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"VWAP_BUY"))
         g_traded_day = today;
      else if(!g_suppress_log) PrintFormat("VWAP-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN VWAP-SELL @%.2f",bid); return; }
      if(g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"VWAP_SELL"))
         g_traded_day = today;
      else if(!g_suppress_log) PrintFormat("VWAP-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
}
