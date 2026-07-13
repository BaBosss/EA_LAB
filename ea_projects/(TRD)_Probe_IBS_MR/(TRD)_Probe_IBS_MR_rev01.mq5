//+------------------------------------------------------------------+
//| (TRD)_Probe_IBS_MR_rev01.mq5                                      |
//|                                                                    |
//| ORDER-104 W2 probe (SSRN-151 §4.4). Internal Bar Strength         |
//| mean-reversion: IBS = (Close-Low)/(High-Low) ∈ [0,1] on the last  |
//| CLOSED bar. Low IBS = closed near the low = "cheap" → buy; high    |
//| IBS = closed near the high = "rich" → sell. Exit when IBS reverts  |
//| past mid (0.5) or on ATR SL/TP. Single-instrument, single position.|
//| Distinct from MAHP probe: pure single-bar mean-reversion signal,   |
//| no smoothing/lag. Magic 991042.                                    |
//| State-free (IBS recomputed each bar), bar-open gated, tester-gate, |
//| magic-scoped, hard caps.                                           |
//+------------------------------------------------------------------+
#property strict
#property description "(TRD)_Probe_IBS_MR rev01 — Internal Bar Strength mean-reversion (ORDER-104 W2)"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] IBS SIGNAL ────────────────────────";
input double _01_BuyBelow     = 0.20;  // IBS < this → buy (cheap)
input double _01_SellAbove    = 0.80;  // IBS > this → sell (rich)
input double _01_ExitMid      = 0.50;  // exit when IBS reverts past this

input string _g02_            = "── [02] EXIT (ATR SL/TP safety) ───────────";
input int    _02_AtrPeriod    = 14;
input double _02_SlAtrMult     = 2.0;
input double _02_TpAtrMult     = 3.0;

input string _g03_            = "── [03] TRADE MGMT ────────────────────────";
input bool   _03_Buys         = true;
input bool   _03_Sells        = true;
input double _03_LotSize      = 0.01;

input string _g04_            = "── [04] RISK CAPS ─────────────────────────";
input double _04_DailyLossPct = 5.0;
input double _04_EmergencyDdPct = 25.0;

input string _g05_            = "── [05] SYSTEM ────────────────────────────";
input long   _05_Magic        = 991042;
input ulong  _05_Deviation    = 20;
input bool   _05_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }

bool OwnTicket(ulong &ticket){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_05_Magic){ ticket=t; return true; } } ticket=0; return false; }

// IBS on last closed bar; -1 on degenerate bar
double IBS()
{
   double h=iHigh(_Symbol,PERIOD_CURRENT,1), l=iLow(_Symbol,PERIOD_CURRENT,1), c=iClose(_Symbol,PERIOD_CURRENT,1);
   double rng=h-l;
   if(rng<=0) return -1.0;
   return (c-l)/rng;
}

double NormalizeLot(double lot)
{
   double minl=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maxl=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX), step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;
   lot=MathFloor(lot/step)*step;
   if(lot<minl) lot=minl; if(lot>maxl) lot=maxl;
   return NormalizeDouble(lot,2);
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(_01_BuyBelow>=_01_SellAbove){ Print("IBS: BuyBelow<SellAbove required"); return INIT_PARAMETERS_INCORRECT; }
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_02_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("IBS: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_05_Magic); g_trade.SetDeviationInPoints(_05_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("IBS init magic=%d AllowLive=%s",_05_Magic,_05_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
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

   double ibs=IBS(); if(ibs<0) return;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double atr=Buf(g_atr,0,1); if(atr<=0) return;

   // manage: exit on reversion past mid (SL/TP also armed)
   ulong tk=0;
   if(OwnTicket(tk))
   {
      if(!PositionSelectByTicket(tk)) return;
      long ptype=PositionGetInteger(POSITION_TYPE);
      if(ptype==POSITION_TYPE_BUY  && ibs>=_01_ExitMid){ g_trade.PositionClose(tk); }
      else if(ptype==POSITION_TYPE_SELL && ibs<=_01_ExitMid){ g_trade.PositionClose(tk); }
      return;
   }

   if(!RiskOk()) return;
   bool bull=_03_Buys  && (ibs<_01_BuyBelow);
   bool bear=_03_Sells && (ibs>_01_SellAbove);
   if(!bull && !bear) return;

   const bool allow=_05_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double lot=NormalizeLot(_03_LotSize);

   if(bull){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=NormalizeDouble(ask-_02_SlAtrMult*atr,digits), tp=NormalizeDouble(ask+_02_TpAtrMult*atr,digits);
      if(sl>=ask) return;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN IBS-BUY @%.5f ibs=%.2f",ask,ibs); return; }
      g_trade.Buy(lot,_Symbol,ask,sl,tp,"IBS_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=NormalizeDouble(bid+_02_SlAtrMult*atr,digits), tp=NormalizeDouble(bid-_02_TpAtrMult*atr,digits);
      if(sl<=bid) return;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN IBS-SELL @%.5f ibs=%.2f",bid,ibs); return; }
      g_trade.Sell(lot,_Symbol,bid,sl,tp,"IBS_SELL"); }
}
