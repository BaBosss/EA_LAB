//+------------------------------------------------------------------+
//| (BRK)_SqueezeBreakout_rev01.mq5                                  |
//|                                                                    |
//| Volatility-squeeze breakout (TTM-squeeze style). Bollinger Bands  |
//| (20,2) contracting INSIDE Keltner Channels (EMA20 +/- ATR*mult) = |
//| a low-volatility "squeeze". When the squeeze RELEASES (BB expands |
//| back outside Keltner) and price closes beyond the prior range, we |
//| enter in the breakout direction — the moment compressed vol       |
//| releases is when momentum moves are most explosive. Distinct from |
//| the Donchian range-break (BRK-XAU) and ATR-channel (Zeus): this   |
//| one WAITS for volatility compression first.                       |
//|                                                                    |
//| L1: single position, real ATR SL + RR TP, fixed lot, bar-open     |
//| gated, magic-scoped, hard caps. No grid, no basket. Magic 991004. |
//| Origin: user asked for a NEW mechanism 2026-07-08. Gold-momentum  |
//| is the proven edge class -> validate on XAUUSD first, full funnel |
//| (3-window + MC + WFA on ONE continuous span) before any demo.     |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_SqueezeBreakout_rev01 — volatility-squeeze release breakout, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] SQUEEZE (BB inside Keltner) ───────";
input int    _01_BbPeriod     = 20;
input double _01_BbDev        = 2.0;
input int    _01_KcPeriod     = 20;
input double _01_KcAtrMult    = 1.5;   // Keltner width = ATR x this
input int    _01_MinSqueezeBars = 6;   // require this many recent bars in-squeeze before a release counts

input string _g02_            = "── [02] BREAKOUT / RANGE ──────────────────";
input int    _01_RangeBars    = 20;    // breakout beyond the high/low of this many bars
input double _02_BufAtrMult   = 0.10;

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
input long   _07_Magic        = 991004;
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_bb=INVALID_HANDLE, g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE, g_kcEma=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double PipSize(const string s){ int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS); double p=SymbolInfoDouble(s,SYMBOL_POINT); return (d==5||d==3)?p*10.0:p; }
double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
double ATRv(const int sh){ return Buf(g_atr,0,sh); }

bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) return true; } return false; }

// Is bar `sh` in a squeeze? (BB entirely inside Keltner)
bool InSqueeze(const int sh)
{
   double bbU=Buf(g_bb,1,sh), bbL=Buf(g_bb,2,sh);           // iBands: 0 mid,1 upper,2 lower
   double ema=Buf(g_kcEma,0,sh), atr=ATRv(sh);
   if(bbU==0||atr==0) return false;
   double kcU=ema+_01_KcAtrMult*atr, kcL=ema-_01_KcAtrMult*atr;
   return (bbU < kcU && bbL > kcL);
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_bb  = iBands(_Symbol,PERIOD_CURRENT,_01_BbPeriod,0,_01_BbDev,PRICE_CLOSE);
   g_atr = iATR(_Symbol,PERIOD_CURRENT,_03_AtrPeriod);
   g_kcEma = iMA(_Symbol,PERIOD_CURRENT,_01_KcPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(g_bb==INVALID_HANDLE||g_atr==INVALID_HANDLE||g_kcEma==INVALID_HANDLE){ Print("Squeeze: handle fail"); return INIT_FAILED; }
   if(_04_UseEma){ g_ema=iMA(_Symbol,PERIOD_CURRENT,_04_EmaPeriod,0,MODE_EMA,PRICE_CLOSE); if(g_ema==INVALID_HANDLE) return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_07_Magic); g_trade.SetDeviationInPoints(_07_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("Squeeze init magic=%d AllowLive=%s",_07_Magic,_07_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_bb!=INVALID_HANDLE)IndicatorRelease(g_bb); if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); if(g_kcEma!=INVALID_HANDLE)IndicatorRelease(g_kcEma); if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); }
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

   // squeeze RELEASE: bar 1 is NOT in squeeze, but the _01_MinSqueezeBars bars before it WERE.
   if(InSqueeze(1)) return;                       // still compressed -> wait
   for(int i=2;i<=_01_MinSqueezeBars+1;i++) if(!InSqueeze(i)) return;  // require prior compression

   // directional breakout beyond the prior range (bars 2.._01_RangeBars+1)
   double hi=-1,lo=1e18;
   for(int i=2;i<=_01_RangeBars+1;i++){ hi=MathMax(hi,iHigh(_Symbol,PERIOD_CURRENT,i)); lo=MathMin(lo,iLow(_Symbol,PERIOD_CURRENT,i)); }
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double buf=_02_BufAtrMult*atr;
   double ema=_04_UseEma?Buf(g_ema,0,1):0.0;
   const bool allow=_07_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double sl=_03_SlAtrMult*atr, tp=_03_TpAtrMult*atr;

   bool bull=_05_BuyBreaks  && (c1>hi+buf) && (!_04_UseEma||c1>ema);
   bool bear=_05_SellBreaks && (c1<lo-buf) && (!_04_UseEma||c1<ema);
   if(!bull && !bear) return;

   if(bull){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN SQZ-BUY @%.2f",ask); return; }
      g_trade.Buy(_05_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"SQZ_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN SQZ-SELL @%.2f",bid); return; }
      g_trade.Sell(_05_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"SQZ_SELL"); }
}
