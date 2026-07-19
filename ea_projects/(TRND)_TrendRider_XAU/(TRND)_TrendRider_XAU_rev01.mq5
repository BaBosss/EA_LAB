//+------------------------------------------------------------------+
//| (TRND)_TrendRider_XAU_rev01.mq5                                   |
//|                                                                    |
//| S1 — Golden Trend Rider (H4 pullback-continuation). Gold's macro  |
//| drivers move slowly, so directional legs persist. In an           |
//| established trend (EMA50>EMA200, ADX>min, EMAs separated by ATR),  |
//| a pullback to EMA21 that closes back in the trend direction gives  |
//| a defined-risk continuation entry. Distinct from S2 (absolute     |
//| multi-month momentum): S1's edge is intra-trend pullback           |
//| STRUCTURE, sized off a tight 2*ATR stop with a Chandelier trail.   |
//|                                                                    |
//| Entry (long; mirror short): regime up AND low[1]<=EMA21<close[1]   |
//| AND bullish bar, in-session. SL=2*ATR. Trail = HighestHigh(N) -    |
//| 2.5*ATR, tightened each bar. No fixed TP (let the trail run).      |
//| Session-gated (07:00-20:00 GMT via ServerGmtOffset).              |
//|                                                                    |
//| L1: one position, real SL + Chandelier trail, fixed lot, bar-open  |
//| gated, magic-scoped, hard caps. No grid/martingale. Magic 992004. |
//| Partial-at-1.5R is a later mgmt lever; this L1 uses trail-only.    |
//+------------------------------------------------------------------+
#property strict
#property description "(TRND)_TrendRider_XAU_rev01 — H4 trend pullback-continuation, single-position, ATR stop + Chandelier trail"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] TREND REGIME ──────────────────────";
input int    _01_EmaFast      = 50;
input int    _01_EmaSlow      = 200;
input int    _01_EmaPull      = 21;    // pullback reference
input int    _01_AdxPeriod    = 14;
input double _01_AdxMin       = 25.0;  // trend-strength floor
input int    _01_AtrPeriod    = 14;
input double _01_SepAtrMult   = 0.5;   // require |EMAfast-EMAslow| >= this*ATR (real separation)

input string _g02_            = "── [02] STOP / TRAIL ──────────────────────";
input double _02_SlAtrMult    = 2.0;
input int    _02_ChHighBars   = 10;    // Chandelier lookback (highest high / lowest low)
input double _02_ChAtrMult    = 2.5;

input string _g03_            = "── [03] SESSION (GMT hours) ───────────────";
input int    _03_StartGmt     = 7;
input int    _03_EndGmt       = 20;
input int    _03_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_BuyOk        = true;
input bool   _04_SellOk       = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 992004;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_emaF=INVALID_HANDLE, g_emaS=INVALID_HANDLE, g_emaP=INVALID_HANDLE, g_adx=INVALID_HANDLE, g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv,d); return ((d.hour - _03_ServerGmtOffset)%24 + 24)%24; }

int OwnDir(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic)
      return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?+1:-1; } return 0; }
bool OwnSelect(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_emaF=iMA(_Symbol,PERIOD_CURRENT,_01_EmaFast,0,MODE_EMA,PRICE_CLOSE);
   g_emaS=iMA(_Symbol,PERIOD_CURRENT,_01_EmaSlow,0,MODE_EMA,PRICE_CLOSE);
   g_emaP=iMA(_Symbol,PERIOD_CURRENT,_01_EmaPull,0,MODE_EMA,PRICE_CLOSE);
   g_adx =iADX(_Symbol,PERIOD_CURRENT,_01_AdxPeriod);
   g_atr =iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_emaF==INVALID_HANDLE||g_emaS==INVALID_HANDLE||g_emaP==INVALID_HANDLE||g_adx==INVALID_HANDLE||g_atr==INVALID_HANDLE){ Print("TrendRider: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("TrendRider init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_emaF!=INVALID_HANDLE)IndicatorRelease(g_emaF); if(g_emaS!=INVALID_HANDLE)IndicatorRelease(g_emaS); if(g_emaP!=INVALID_HANDLE)IndicatorRelease(g_emaP); if(g_adx!=INVALID_HANDLE)IndicatorRelease(g_adx); if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_05_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_05_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

double HighestHigh(const int n){ double h=-1; for(int i=1;i<=n;i++) h=MathMax(h,iHigh(_Symbol,PERIOD_CURRENT,i)); return h; }
double LowestLow(const int n){ double l=1e18; for(int i=1;i<=n;i++) l=MathMin(l,iLow(_Symbol,PERIOD_CURRENT,i)); return l; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   const double atr=Buf(g_atr,0,1); if(atr<=0.0) return;
   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const int dir=OwnDir();

   // ---- manage open position: Chandelier trail (tighten only) ----
   if(dir!=0)
   {
      if(OwnSelect())
      {
         double newSL = (dir>0)? HighestHigh(_02_ChHighBars) - _02_ChAtrMult*atr
                               : LowestLow(_02_ChHighBars)  + _02_ChAtrMult*atr;
         newSL=NormalizeDouble(newSL,digits);
         double curSL=PositionGetDouble(POSITION_SL);
         bool improve=(dir>0)?(curSL==0.0||newSL>curSL):(curSL==0.0||newSL<curSL);
         if(improve && allow) g_trade.PositionModify(_Symbol,newSL,PositionGetDouble(POSITION_TP));
      }
      return;
   }

   // ---- flat: look for a pullback-continuation entry, in-session ----
   if(!RiskOk()) return;
   const int gmtHour=GmtHourOf(TimeCurrent());
   if(gmtHour<_03_StartGmt || gmtHour>=_03_EndGmt) return;

   const double emaF=Buf(g_emaF,0,1), emaS=Buf(g_emaS,0,1), emaP=Buf(g_emaP,0,1), adx=Buf(g_adx,0,1);
   const double lo1=iLow(_Symbol,PERIOD_CURRENT,1), hi1=iHigh(_Symbol,PERIOD_CURRENT,1);
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   const double sep=MathAbs(emaF-emaS);

   const bool upReg  = (emaF>emaS) && (adx>=_01_AdxMin) && (sep>=_01_SepAtrMult*atr);
   const bool dnReg  = (emaF<emaS) && (adx>=_01_AdxMin) && (sep>=_01_SepAtrMult*atr);
   const bool pbLong = upReg && (lo1<=emaP) && (c1>emaP) && (c1>o1);   // dipped to EMA21, closed back above, bullish
   const bool pbShort= dnReg && (hi1>=emaP) && (c1<emaP) && (c1<o1);

   const bool longSig = _04_BuyOk  && pbLong;
   const bool shortSig= _04_SellOk && pbShort;
   if(!longSig && !shortSig) return;

   double slDist=_02_SlAtrMult*atr;
   if(longSig){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN TR-BUY @%.2f",ask); return; }
      g_trade.Buy(_04_LotSize,_Symbol,ask,NormalizeDouble(ask-slDist,digits),0.0,"TR_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN TR-SELL @%.2f",bid); return; }
      g_trade.Sell(_04_LotSize,_Symbol,bid,NormalizeDouble(bid+slDist,digits),0.0,"TR_SELL"); }
}
