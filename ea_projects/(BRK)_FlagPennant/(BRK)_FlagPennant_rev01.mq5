//+------------------------------------------------------------------+
//| (BRK)_FlagPennant_rev01.mq5                                       |
//|                                                                    |
//| Flag/pennant continuation breakout. A strong one-way impulse       |
//| ("pole", >= PoleAtrMult x ATR over PoleBars) followed by a TIGHT   |
//| consolidation ("flag", range <= FlagRangeAtrMult x ATR for         |
//| FlagBars, retracing < MaxRetrace of the pole) = trend pausing,     |
//| not reversing. Entry when price breaks the flag boundary IN THE    |
//| POLE DIRECTION. Distinct from every cohort mechanism: Donchian     |
//| (BRK) breaks a level, Squeeze waits for vol compression of the     |
//| WHOLE market, Zeus rides ATR-channel momentum — this one requires  |
//| an impulse FIRST and buys its continuation.                        |
//|                                                                    |
//| L1: single position, real ATR SL + RR TP, fixed lot, bar-open     |
//| gated, magic-scoped, hard caps. No grid, no basket. Magic 991005. |
//| Origin: user ordered new hunt 2026-07-09; flag/pennant is the      |
//| named next-EV mechanism in SESSION_2026-07-09_HANDOFF. Gold-       |
//| momentum = proven edge class -> validate on XAUUSD H1 first, full  |
//| funnel (3-window + MC on one continuous span) before any demo.     |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_FlagPennant_rev01 — impulse-flag continuation breakout, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] POLE (impulse) ────────────────────";
input int    _01_PoleBars     = 5;     // impulse measured over this many bars
input double _01_PoleAtrMult  = 3.0;   // impulse must exceed ATR x this

input string _g02_            = "── [02] FLAG (consolidation) ──────────────";
input int    _02_FlagBars     = 6;     // consolidation length
input double _02_FlagRangeAtrMult = 1.5; // flag hi-lo must stay under ATR x this
input double _02_MaxRetrace   = 0.5;   // flag may give back at most this fraction of the pole
input double _02_BufAtrMult   = 0.10;  // break buffer beyond flag boundary

input string _g03_            = "── [03] SL / TP / ATR ─────────────────────";
input int    _03_AtrPeriod    = 14;
input double _03_SlAtrMult    = 1.5;
input double _03_TpAtrMult    = 4.0;

input string _g04_            = "── [04] TREND FILTER ──────────────────────";
input bool   _04_UseEma       = true;
input int    _04_EmaPeriod    = 200;

input string _g05_            = "── [05] TRADE MGMT ────────────────────────";
input bool   _05_BuyBreaks    = true;
input bool   _05_SellBreaks   = true;
input double _05_LotSize      = 0.01;

input string _g06_            = "── [06] RISK CAPS ─────────────────────────";
input double _06_DailyLossPct = 5.0;
input double _06_EmergencyDdPct = 25.0;

input string _g07_            = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic        = 991005;
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
double ATRv(const int sh){ return Buf(g_atr,0,sh); }

bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr = iATR(_Symbol,PERIOD_CURRENT,_03_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("FlagPennant: handle fail"); return INIT_FAILED; }
   if(_04_UseEma){ g_ema=iMA(_Symbol,PERIOD_CURRENT,_04_EmaPeriod,0,MODE_EMA,PRICE_CLOSE); if(g_ema==INVALID_HANDLE) return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_07_Magic); g_trade.SetDeviationInPoints(_07_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("FlagPennant init magic=%d AllowLive=%s",_07_Magic,_07_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_06_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_06_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;
   if(OwnPos()) return;
   const double atr=ATRv(1); if(atr<=0.0) return;
   if(!RiskOk()) return;

   // ---- flag window: bars 1.._02_FlagBars · pole window: the _01_PoleBars bars before it
   double flagHi=-1, flagLo=1e18;
   for(int i=1;i<=_02_FlagBars;i++){ flagHi=MathMax(flagHi,iHigh(_Symbol,PERIOD_CURRENT,i)); flagLo=MathMin(flagLo,iLow(_Symbol,PERIOD_CURRENT,i)); }
   if(flagHi-flagLo > _02_FlagRangeAtrMult*atr) return;            // consolidation not tight -> no flag

   const int poleEnd  = _02_FlagBars+1;                            // most recent pole bar
   const int poleStart= _02_FlagBars+_01_PoleBars;                 // oldest pole bar
   const double poleOpen  = iOpen(_Symbol,PERIOD_CURRENT,poleStart);
   const double poleClose = iClose(_Symbol,PERIOD_CURRENT,poleEnd);
   const double pole = poleClose-poleOpen;                         // signed impulse
   if(MathAbs(pole) < _01_PoleAtrMult*atr) return;                 // no impulse -> no pole

   const bool bullPole = (pole>0);
   // flag must hold, not give the pole back
   if(bullPole  && (poleClose-flagLo) > _02_MaxRetrace*MathAbs(pole)) return;
   if(!bullPole && (flagHi-poleClose) > _02_MaxRetrace*MathAbs(pole)) return;

   // ---- entry: bar-1 close breaks the flag boundary in the pole direction
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double buf=_02_BufAtrMult*atr;
   // c1 is part of the flag window; break = close beyond the OTHER flag bars' extreme
   double innHi=-1, innLo=1e18;                                    // flag extremes excluding bar 1
   for(int i=2;i<=_02_FlagBars;i++){ innHi=MathMax(innHi,iHigh(_Symbol,PERIOD_CURRENT,i)); innLo=MathMin(innLo,iLow(_Symbol,PERIOD_CURRENT,i)); }
   double ema=_04_UseEma?Buf(g_ema,0,1):0.0;
   const bool allow=_07_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl=_03_SlAtrMult*atr, tp=_03_TpAtrMult*atr;

   bool bull=_05_BuyBreaks  && bullPole  && (c1>innHi+buf) && (!_04_UseEma||c1>ema);
   bool bear=_05_SellBreaks && !bullPole && (c1<innLo-buf) && (!_04_UseEma||c1<ema);
   if(!bull && !bear) return;

   if(bull){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN FLAG-BUY @%.2f",ask); return; }
      g_trade.Buy(_05_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"FLAG_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN FLAG-SELL @%.2f",bid); return; }
      g_trade.Sell(_05_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"FLAG_SELL"); }
}
