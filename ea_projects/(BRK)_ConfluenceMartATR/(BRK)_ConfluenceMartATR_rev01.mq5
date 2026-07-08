//+------------------------------------------------------------------+
//| (BRK)_ConfluenceMartATR_rev01.mq5                               |
//|                                                                    |
//| User request 2026-07-08: combine Donchian breakout + diagonal    |
//| trendline(triangle) breakout as a CONFLUENCE entry, add a        |
//| PULLBACK entry, and a MARTINGALE x ATR-spaced recovery basket    |
//| (DD headroom exists — the clean breakout ran ~3% DD).            |
//|                                                                    |
//| RISK CLASSIFICATION: Grid(ATR spacing) + Martingale-lot = L4     |
//| (two of {grid,martingale,hedge}). User explicitly accepted the   |
//| risk on 2026-07-08. Mandatory hard caps enforced before EVERY    |
//| OrderSend: max martingale steps, max total lot, emergency DD     |
//| close-all, daily loss halt. NO hedge => not L5.                  |
//|                                                                    |
//| ENTRY: bullish only when close breaks BOTH the N-bar Donchian    |
//| high AND the projected upper trendline (2-pivot fit). Mirror for |
//| short. Optional pullback: after the signal, wait to enter until  |
//| price retraces toward the broken level (better price / RR).      |
//| RECOVERY: if the basket goes adverse by ATR x mult, add a leg    |
//| (martingale lot), basket exits at net $ target or hard caps.     |
//|                                                                    |
//| DURATION: measured post-backtest from the deal list (script      |
//| max_recovery_days.py) — reports the longest time a basket stayed |
//| open before closing at target. Magic 991003. Validate from       |
//| scratch before any demo.                                          |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_ConfluenceMartATR_rev01 — Donchian+trendline confluence + pullback + capped martingale-ATR recovery (L4)"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] CONFLUENCE ENTRY ──────────────────";
input int    _01_DonchBars      = 40;    // Donchian breakout lookback
input int    _01_PivotLR        = 3;     // trendline pivot half-width
input int    _01_ScanBars       = 120;
input bool   _01_RequireConverge = true; // triangle filter on the trendline
input double _01_BufferAtrMult   = 0.10;
input bool   _01_UseTrendlineToo = true; // true = require BOTH Donchian AND trendline; false = Donchian only

input string _g01b_           = "── [01b] PULLBACK ─────────────────────────";
input bool   _01_UsePullback    = true;
input double _01_PullbackAtrMult = 0.5;  // enter when price retraces this x ATR back toward the broken level
input int    _01_PullbackMaxBars = 8;    // give up the pullback wait after this many bars

input string _g02_            = "── [02] ATR / TREND ───────────────────────";
input int    _02_AtrPeriod    = 14;
input bool   _02_UseEma       = true;
input int    _02_EmaPeriod    = 200;

input string _g03_            = "── [03] RECOVERY (martingale x ATR grid) ──";
input double _03_AddAtrMult   = 1.5;     // add a leg when price runs this x ATR adverse from the last leg
input double _03_BaseLot      = 0.01;
input double _03_MartMult     = 1.6;     // leg N lot = base x mult^(N-1)  (CAPPED)
input double _03_TpUsd        = 8.0;     // basket net-profit target ($)

input string _g06_            = "── [06] HARD CAPS (L4 mandatory) ──────────";
input int    _06_MaxSteps     = 5;       // max martingale legs (hard)
input double _06_MaxTotalLot  = 0.30;    // hard total exposure cap
input double _06_DailyLossPct = 5.0;
input double _06_EmergencyDdPct = 15.0;  // close-all + halt (martingale's real safety net)

input string _g07_            = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic        = 991003;
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

//--------------------------------------------------------------------
static bool     g_suppress_log = false;
static int      g_atr_handle=INVALID_HANDLE, g_ema_handle=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
// pullback-arm state
static int      g_arm_dir=0;          // 0 none, +1 pending long, -1 pending short
static double   g_arm_level=0.0;      // the broken level to pull back to
static int      g_arm_age=0;

double PipSize(const string s){ int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS); double p=SymbolInfoDouble(s,SYMBOL_POINT); return (d==5||d==3)?p*10.0:p; }
double BufAt(const int h,const int sh){ double b[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,sh,1,b)<1) return 0.0; return b[0]; }
double GetATR(const int sh){ return BufAt(g_atr_handle,sh); }

int SideCount(const ENUM_POSITION_TYPE side){ int n=0; for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic && (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==side) n++; } return n; }
int TotalCount(){ return SideCount(POSITION_TYPE_BUY)+SideCount(POSITION_TYPE_SELL); }
double TotalLot(){ double l=0; for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) l+=PositionGetDouble(POSITION_VOLUME); } return l; }
double BasketProfit(){ double p=0; for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) p+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP); } return p; }
double WorstPrice(const ENUM_POSITION_TYPE side){ double a=0; for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)!=_Symbol||PositionGetInteger(POSITION_MAGIC)!=_07_Magic||(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=side) continue;
   double op=PositionGetDouble(POSITION_PRICE_OPEN); if(side==POSITION_TYPE_BUY) a=(a==0)?op:MathMin(a,op); else a=(a==0)?op:MathMax(a,op); } return a; }

double NormLot(double lot){ double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=MathFloor(lot/st)*st; return MathMin(MathMax(lot,mn),mx); }
double LegLot(const int stepN){ return NormLot(_03_BaseLot*MathPow(_03_MartMult,(double)(stepN-1))); }

void CloseAll(){ for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) g_trade.PositionClose(t); } }

bool FindPivots(const bool wantHigh,int &x1,double &y1,int &x2,double &y2){ int k=_01_PivotLR,found=0;
   for(int s=k+1;s<=_01_ScanBars && found<2;s++){ double v=wantHigh?iHigh(_Symbol,PERIOD_CURRENT,s):iLow(_Symbol,PERIOD_CURRENT,s); bool piv=true;
      for(int j=1;j<=k&&piv;j++){ double l=wantHigh?iHigh(_Symbol,PERIOD_CURRENT,s-j):iLow(_Symbol,PERIOD_CURRENT,s-j); double r=wantHigh?iHigh(_Symbol,PERIOD_CURRENT,s+j):iLow(_Symbol,PERIOD_CURRENT,s+j);
         if(wantHigh){ if(l>=v||r>=v) piv=false; } else { if(l<=v||r<=v) piv=false; } }
      if(piv){ if(found==0){x1=s;y1=v;} else {x2=s;y2=v;} found++; s+=k; } } return found==2; }
double ProjLine(const int x1,const double y1,const int x2,const double y2,const int tgt,double &slope){ double dx=(double)(x2-x1); if(dx==0){slope=0;return y1;} slope=(y1-y2)/dx; return y1+slope*(double)(x1-tgt); }

// Confluence breakout check at last closed bar. Returns +1 bull, -1 bear, 0 none, and the broken level.
int Confluence(double &level)
{
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), c2=iClose(_Symbol,PERIOD_CURRENT,2);
   const double atr=GetATR(1); const double buf=_01_BufferAtrMult*atr;
   double ema=_02_UseEma?BufAt(g_ema_handle,1):0.0;
   // Donchian levels over bars 2.._01_DonchBars+1 (exclude the breakout bar itself)
   double dHigh=-1,dLow=1e18;
   for(int i=2;i<=_01_DonchBars+1;i++){ dHigh=MathMax(dHigh,iHigh(_Symbol,PERIOD_CURRENT,i)); dLow=MathMin(dLow,iLow(_Symbol,PERIOD_CURRENT,i)); }
   bool donBull=(c1>dHigh+buf), donBear=(c1<dLow-buf);
   // trendline
   bool tlBull=true, tlBear=true; double upLine=0,loLine=0;
   if(_01_UseTrendlineToo){
      int hx1,hx2,lx1,lx2; double hy1,hy2,ly1,ly2;
      if(!FindPivots(true,hx1,hy1,hx2,hy2)||!FindPivots(false,lx1,ly1,lx2,ly2)) return 0;
      double us,ls; upLine=ProjLine(hx1,hy1,hx2,hy2,1,us); loLine=ProjLine(lx1,ly1,lx2,ly2,1,ls);
      if(_01_RequireConverge && !(us<=0 && ls>=0)) return 0;
      tlBull=(c2<=upLine)&&(c1>upLine+buf); tlBear=(c2>=loLine)&&(c1<loLine-buf);
   }
   bool bull=donBull && tlBull && (!_02_UseEma||c1>ema);
   bool bear=donBear && tlBear && (!_02_UseEma||c1<ema);
   if(bull){ level=(_01_UseTrendlineToo?MathMax(dHigh,upLine):dHigh); return 1; }
   if(bear){ level=(_01_UseTrendlineToo?MathMin(dLow,loLine):dLow); return -1; }
   return 0;
}

int OnInit(){ g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr_handle=iATR(_Symbol,PERIOD_CURRENT,_02_AtrPeriod); if(g_atr_handle==INVALID_HANDLE) return INIT_FAILED;
   if(_02_UseEma){ g_ema_handle=iMA(_Symbol,PERIOD_CURRENT,_02_EmaPeriod,0,MODE_EMA,PRICE_CLOSE); if(g_ema_handle==INVALID_HANDLE) return INIT_FAILED; }
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){ Print("ConflMart: needs HEDGING account (basket)"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_07_Magic); g_trade.SetDeviationInPoints(_07_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false; g_arm_dir=0;
   return INIT_SUCCEEDED; }
void OnDeinit(const int r){ if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle); if(g_ema_handle!=INVALID_HANDLE) IndicatorRelease(g_ema_handle); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool CapsOk(const double addLot){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_06_EmergencyDdPct) return false; }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_06_DailyLossPct){ g_halted_today=true; return false; } }
   if(TotalCount()>=_06_MaxSteps) return false; if(TotalLot()+addLot>_06_MaxTotalLot) return false; return true; }

void OpenLeg(const int dir,const int stepN){ double lot=LegLot(stepN); if(lot<=0||!CapsOk(lot)) return;
   const bool allow=_07_AllowLive||(bool)MQLInfoInteger(MQL_TESTER); if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN leg%d %s lot=%.2f",stepN,dir>0?"BUY":"SELL",lot); return; }
   if(dir>0){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK); g_trade.Buy(lot,_Symbol,ask,0,0,"CM_BUY"); }
   else     { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID); g_trade.Sell(lot,_Symbol,bid,0,0,"CM_SELL"); } }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;
   const double atr=GetATR(1); if(atr<=0.0) return;

   // ── emergency exit ───────────────────────────────
   double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_06_EmergencyDdPct){ if(TotalCount()>0){ if(!g_suppress_log) PrintFormat("EMERGENCY DD %.1f%%",dd); CloseAll(); } g_halted_today=true; g_arm_dir=0; return; } }

   // ── manage open basket: TP or add martingale leg ─
   int buys=SideCount(POSITION_TYPE_BUY), sells=SideCount(POSITION_TYPE_SELL);
   if(buys+sells>0){
      if(BasketProfit()>=_03_TpUsd){ if(!g_suppress_log) PrintFormat("BASKET TP %.2f",BasketProfit()); CloseAll(); g_arm_dir=0; return; }
      ENUM_POSITION_TYPE side=(buys>0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL; int cnt=(buys>0)?buys:sells;
      if(cnt<_06_MaxSteps){ double anchor=WorstPrice(side); double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID),ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         bool add=(side==POSITION_TYPE_BUY)?(bid<=anchor-_03_AddAtrMult*atr):(ask>=anchor+_03_AddAtrMult*atr);
         if(add) OpenLeg((side==POSITION_TYPE_BUY)?1:-1, cnt+1); }
      return;
   }

   // ── pullback arm handling ────────────────────────
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   if(_01_UsePullback && g_arm_dir!=0){
      g_arm_age++;
      if(g_arm_age>_01_PullbackMaxBars){ g_arm_dir=0; }        // give up
      else{
         bool ready=(g_arm_dir>0)?(c1<=g_arm_level+_01_PullbackAtrMult*atr):(c1>=g_arm_level-_01_PullbackAtrMult*atr);
         if(ready && CapsOk(LegLot(1))){ OpenLeg(g_arm_dir,1); g_arm_dir=0; }
      }
      return;
   }

   // ── new confluence signal ────────────────────────
   double level; int sig=Confluence(level);
   if(sig==0) return;
   if(_01_UsePullback){ g_arm_dir=sig; g_arm_level=level; g_arm_age=0; }  // wait for pullback
   else if(CapsOk(LegLot(1))) OpenLeg(sig,1);                             // enter now
}
