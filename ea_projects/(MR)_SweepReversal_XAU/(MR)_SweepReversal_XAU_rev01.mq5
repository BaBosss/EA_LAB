//+------------------------------------------------------------------+
//| (MR)_SweepReversal_XAU_rev01.mq5                                  |
//|                                                                    |
//| SS4 — Liquidity-Sweep Reversal (15m). Stops cluster just beyond   |
//| prior-day high/low and $25 round numbers. A fast wick beyond such |
//| a level that fails to hold = stop-run + rejection, reverts. Gold's|
//| clustered stops make this mechanical. Mean-reversion; distinct    |
//| from pivot-distance / BB reversion — reference is STRUCTURAL       |
//| liquidity levels and the trigger is a sweep-and-reject.           |
//|                                                                    |
//| Short (mirror long): a bar wicks >= 0.3*ATR above a resistance    |
//| level (prior-day-high or the $25 grid) AND closes back below it   |
//| AND RSI>65 -> sell. SL = sweep-extreme + buffer; TP = 1.8*ATR.    |
//| Skip when ADX(H4)>28 (trend day = sweeps continue). Session-gated.|
//|                                                                    |
//| L1: one position, real SL, fixed lot, bar-open gated, magic-scoped |
//| hard caps. No grid/martingale. Magic 992006. Server=GMT+offset.   |
//+------------------------------------------------------------------+
#property strict
#property description "(MR)_SweepReversal_XAU_rev01 — liquidity sweep-and-reject reversal, single-position, real SL"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] SWEEP TRIGGER ─────────────────────";
input int    _01_RsiPeriod    = 14;
input double _01_RsiHi        = 65.0;  // short confirm
input double _01_RsiLo        = 35.0;  // long confirm
input double _01_RoundStep    = 25.0;  // round-number grid ($ per level)
input int    _01_AtrPeriod    = 14;
input double _01_SweepAtrMult = 0.3;   // wick must exceed level by >= this * ATR

input string _g02_            = "── [02] REGIME FILTER ─────────────────────";
input int    _02_AdxH4Period  = 14;
input double _02_AdxMax        = 28.0;  // skip if ADX(H4) above this (trend day)

input string _g03_            = "── [03] STOP / TARGET ─────────────────────";
input double _03_SlBufAtrMult = 0.3;   // SL = sweep extreme +/- this * ATR
input double _03_TpAtrMult     = 1.8;

input string _g04_            = "── [04] SESSION (GMT hours) ───────────────";
input int    _04_StartGmt     = 7;
input int    _04_EndGmt       = 20;
input int    _04_ServerGmtOffset = 3;  // server = GMT + this (Exness = +3)

input string _g05_            = "── [05] TRADE MGMT ────────────────────────";
input bool   _05_BuyOk        = true;
input bool   _05_SellOk       = true;
input double _05_LotSize      = 0.01;

input string _g06_            = "── [06] RISK CAPS ─────────────────────────";
input double _06_DailyLossPct = 5.0;
input double _06_EmergencyDdPct = 25.0;

input string _g07_            = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic        = 992006;
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_rsi=INVALID_HANDLE, g_adxH4=INVALID_HANDLE, g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }
int  GmtHourOf(const datetime srv){ MqlDateTime d; TimeToStruct(srv - (datetime)_04_ServerGmtOffset*3600,d); return d.hour; }
bool OwnPos(){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) return true; } return false; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_rsi=iRSI(_Symbol,PERIOD_CURRENT,_01_RsiPeriod,PRICE_CLOSE);
   g_adxH4=iADX(_Symbol,PERIOD_H4,_02_AdxH4Period);
   g_atr=iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_rsi==INVALID_HANDLE||g_adxH4==INVALID_HANDLE||g_atr==INVALID_HANDLE){ Print("SweepRev: handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_07_Magic); g_trade.SetDeviationInPoints(_07_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("SweepRev init magic=%d AllowLive=%s",_07_Magic,_07_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_rsi!=INVALID_HANDLE)IndicatorRelease(g_rsi); if(g_adxH4!=INVALID_HANDLE)IndicatorRelease(g_adxH4); if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_06_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_06_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;   // bar-open gate

   if(OwnPos()) return;
   const double atr=Buf(g_atr,0,1); if(atr<=0.0) return;
   if(!RiskOk()) return;
   const int gmtHour=GmtHourOf(TimeCurrent());
   if(gmtHour<_04_StartGmt || gmtHour>=_04_EndGmt) return;
   if(Buf(g_adxH4,0,1) > _02_AdxMax) return;              // trend day -> sweeps continue, stand down

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const bool allow=_07_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double hi1=iHigh(_Symbol,PERIOD_CURRENT,1), lo1=iLow(_Symbol,PERIOD_CURRENT,1), c1=iClose(_Symbol,PERIOD_CURRENT,1);
   const double rsi=Buf(g_rsi,0,1);
   const double pdh=iHigh(_Symbol,PERIOD_D1,1), pdl=iLow(_Symbol,PERIOD_D1,1);
   const double step=(_01_RoundStep>0.0)?_01_RoundStep:25.0;
   const double roundAbove=MathCeil(c1/step)*step, roundBelow=MathFloor(c1/step)*step;
   const double minPoke=_01_SweepAtrMult*atr;

   // ---- short: swept a resistance level then closed back below, RSI hot ----
   bool shortSig=false; double swHi=0.0;
   double resLv[2]; resLv[0]=pdh; resLv[1]=roundAbove;
   if(_05_SellOk && rsi>_01_RsiHi)
      for(int i=0;i<2;i++){ double L=resLv[i]; if(L<=0) continue;
         if(hi1>L && c1<L && (hi1-L)>=minPoke){ shortSig=true; swHi=hi1; break; } }

   // ---- long: swept a support level then closed back above, RSI cold ----
   bool longSig=false; double swLo=0.0;
   double supLv[2]; supLv[0]=pdl; supLv[1]=roundBelow;
   if(!shortSig && _05_BuyOk && rsi<_01_RsiLo)
      for(int i=0;i<2;i++){ double L=supLv[i]; if(L<=0) continue;
         if(lo1<L && c1>L && (L-lo1)>=minPoke){ longSig=true; swLo=lo1; break; } }

   if(!shortSig && !longSig) return;

   if(shortSig){ double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=swHi+_03_SlBufAtrMult*atr, tp=bid-_03_TpAtrMult*atr;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN SWEEP-SELL @%.2f L-swept",bid); return; }
      g_trade.Sell(_05_LotSize,_Symbol,bid,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"SWEEP_SELL"); }
   else { double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=swLo-_03_SlBufAtrMult*atr, tp=ask+_03_TpAtrMult*atr;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN SWEEP-BUY @%.2f",ask); return; }
      g_trade.Buy(_05_LotSize,_Symbol,ask,NormalizeDouble(sl,digits),NormalizeDouble(tp,digits),"SWEEP_BUY"); }
}
