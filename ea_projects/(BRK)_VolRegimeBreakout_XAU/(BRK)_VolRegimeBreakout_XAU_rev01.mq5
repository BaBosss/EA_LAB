//+------------------------------------------------------------------+
//| (BRK)_VolRegimeBreakout_XAU_rev01.mq5                             |
//|                                                                    |
//| Idea C — volatility-regime-gated breakout (momentum + filter       |
//| overlay). Base signal = plain N-bar Donchian breakout. The lever   |
//| under test is the GATE: only take the breakout when realized vol  |
//| is EXPANDING (ATR(14) > its own SMA(VolSmaPeriod) * ExpandMult) -- |
//| a volatility-regime filter, distinct from MacroGate (which gates  |
//| on a macro/fundamental regime series, not realized price vol) and |
//| from (BRK)_SqueezeBreakout (which requires prior COMPRESSION,     |
//| BB-inside-Keltner, before the release -- this EA has no            |
//| compression precondition, just "is vol expanding right now").      |
//|                                                                    |
//| Entry (long; mirror short): close[1] > Highest(High,1..N,shift=2)  |
//| (N-bar high excluding the trigger bar) AND ATR(14)[1] >             |
//| ExpandMult*SMA(ATR(14), VolSmaPeriod)[1] -> buy. SL = ATR*SlMult,   |
//| TP = TpRR*risk.                                                     |
//|                                                                    |
//| L1: one position, real SL, fixed lot, bar-open gated, magic-scoped |
//| hard caps. No grid/martingale. Magic 992009.                      |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_VolRegimeBreakout_XAU_rev01 — Donchian breakout gated by expanding realized-vol regime, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] DONCHIAN BREAKOUT ─────────────────";
input int    _01_DonchianN    = 20;    // N-bar high/low lookback (excludes the trigger bar)

input string _g02_            = "── [02] VOL-REGIME GATE ───────────────────";
input int    _02_AtrPeriod    = 14;
input int    _02_VolSmaPeriod = 50;    // rolling average of ATR, the "normal vol" baseline
input double _02_ExpandMult   = 1.15;  // require ATR >= this * its own SMA (vol expanding)

input string _g03_            = "── [03] STOP / TARGET ─────────────────────";
input double _03_SlAtrMult    = 2.0;
input double _03_TpRR         = 2.0;

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992009;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf1(const int h,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,a)<1) return 0.0; return a[0]; }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }
double DonchHigh(const int n,const int startShift){ double h=-1; for(int i=startShift;i<startShift+n;i++) h=MathMax(h,iHigh(_Symbol,PERIOD_CURRENT,i)); return h; }
double DonchLow (const int n,const int startShift){ double l=1e18; for(int i=startShift;i<startShift+n;i++) l=MathMin(l,iLow(_Symbol,PERIOD_CURRENT,i)); return l; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_02_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("VolRegimeBreakout: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("VolRegimeBreakout init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_05_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_05_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

double AtrSma(const int n)  // simple average of the last n CLOSED-bar ATR readings (shift 1..n)
{
   double s=0.0; for(int i=1;i<=n;i++) s+=Buf1(g_atr,i);
   return s/n;
}

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   if(OwnPos()) return;
   if(!RiskOk()) return;

   const double atr=Buf1(g_atr,1); if(atr<=0.0) return;
   const double volBase=AtrSma(_02_VolSmaPeriod); if(volBase<=0.0) return;
   const bool volExpanding=(atr >= _02_ExpandMult*volBase);
   if(!volExpanding) return;                                     // vol-regime gate

   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double donHi=DonchHigh(_01_DonchianN,2), donLo=DonchLow(_01_DonchianN,2);   // excludes bar[1] itself

   const bool longSig = _04_BuyOk  && (c1>donHi);
   const bool shortSig= _04_SellOk && (c1<donLo);
   if(!longSig && !shortSig) return;

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double sl=_03_SlAtrMult*atr, tp=_03_TpRR*sl;

   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN VOLREG-BUY @%.2f",ask); return; }
      g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"VOLREG_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN VOLREG-SELL @%.2f",bid); return; }
      g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"VOLREG_SELL"); }
}
