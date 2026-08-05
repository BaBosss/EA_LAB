//+------------------------------------------------------------------+
//| (EXP)_AdaptGridMC_rev01.mq5                                       |
//|                                                                    |
//| Adaptive Grid MC-zone probe (FINDYOUR8 catalog #1). Long-only     |
//| BUY ladder between ZoneLo(P10) and ZoneHi(P90) — zone numbers     |
//| come from the OFFLINE Monte-Carlo block-bootstrap script           |
//| _mt5_auto/adaptgrid_mc_zone.py and are fed in via .set; the EA is |
//| a dumb executor of those levels. Spacing = SpacingAtrMult *        |
//| ATR(D1,30) (arithmetic) or constant-%% geometric ladder. FLAT lot  |
//| per level (optional inverse-ATR anti-martingale scaler, default    |
//| OFF, clamped [0.5x..2x]). Per-level TP = one spacing up. NO adds   |
//| outside the band (price < ZoneLo = ride existing book, no rescue). |
//|                                                                    |
//| Risk ownership: band cap (MaxLevels + zone edges) + HARD KILL at   |
//| equity <= (1-KillDdPct) * cycle-start equity -> close all + halt,  |
//| halt persisted via GlobalVariable (survives restart; reset by      |
//| deleting the GV or ResetHalt input). L3: grid only, no martingale, |
//| no hedge. Magic 992007.                                            |
//+------------------------------------------------------------------+
#property strict
#property description "(EXP)_AdaptGridMC_rev01 — MC-zone bounded flat-lot buy grid, band-capped, -20% equity hard kill"

#include <Trade\Trade.mqh>

input string _g00_             = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode  = false;

input string _g01_             = "── [01] ZONE (from adaptgrid_mc_zone.py) ──";
input double _01_ZoneLo        = 0.0;    // P10 lower edge (0 = EA refuses to trade)
input double _01_ZoneHi        = 0.0;    // P90 upper edge
input double _01_SpacingAtrMult= 0.3;    // spacing = this * ATR(D1,30)  (arith mode)
input bool   _01_GeoSpacing    = false;  // true: L_i = ZoneLo*ratio^i, ratio=(Hi/Lo)^(1/N)
input int    _01_MaxLevels     = 20;     // hard level cap (<=40)

input string _g02_             = "── [02] LOT ───────────────────────────────";
input double _02_BaseLot       = 0.01;   // FLAT per level
input bool   _02_InvAtrLot     = false;  // lot = base*BaseATR/CurATR, clamp [0.5x..2x]
input double _02_BaseAtr       = 0.0;    // pin at zone-generation time (0 = first ATR seen)

input string _g05_             = "── [05] RISK CAPS ─────────────────────────";
input double _05_KillDdPct     = 20.0;   // equity <= (1-this%)*cycle-start -> close all + HALT
input double _05_MaxTotalLot   = 0.40;
input bool   _05_ResetHalt     = false;  // true once to clear a persisted halt, then set back

input string _g06_             = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic         = 992007;
input ulong  _06_Deviation     = 30;
input bool   _06_AllowLive     = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_cycle_eq0=0.0;      // cycle-start equity (set when book goes 0 -> 1)
static bool     g_halted=false;
static double   g_base_atr=0.0;
static int      g_nlv=0;
static double   g_levels[41];

string HaltGvName(){ return StringFormat("AGMC_HALT_%d_%s",(int)_06_Magic,_Symbol); }
string CycGvName(){  return StringFormat("AGMC_CYC0_%d_%s",(int)_06_Magic,_Symbol); }

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }

double NormalizeLotB(double lot){
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0) lot=MathFloor(lot/st)*st; return MathMin(MathMax(lot,mn),mx); }

int OwnCount(double &totLot){ int n=0; totLot=0.0;
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic){ n++; totLot+=PositionGetDouble(POSITION_VOLUME); } }
   return n; }

// a level is occupied if an open own position's TP sits at that level's TP (level+its spacing)
bool LevelOccupied(const int idx){
   double tpWant=LevelTp(idx); double tol=0.25*(LevelTp(idx)-g_levels[idx]);
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      if(MathAbs(PositionGetDouble(POSITION_TP)-tpWant)<=tol) return true; }
   return false; }

double LevelTp(const int idx){ // TP of level idx = next level up (top level: same step again)
   if(idx+1<g_nlv) return g_levels[idx+1];
   return g_levels[idx] + (g_nlv>=2 ? (g_levels[g_nlv-1]-g_levels[g_nlv-2]) : 0.0); }

bool BuildLevels(){
   if(_01_ZoneLo<=0.0 || _01_ZoneHi<=_01_ZoneLo) return false;
   int cap=(int)MathMin(_01_MaxLevels,40);
   if(_01_GeoSpacing){
      g_nlv=MathMax(2,cap);
      double ratio=MathPow(_01_ZoneHi/_01_ZoneLo,1.0/(double)(g_nlv-1));
      for(int i=0;i<g_nlv;i++) g_levels[i]=_01_ZoneLo*MathPow(ratio,i);
   }else{
      double atr=Buf(g_atr,0,1); if(atr<=0.0) return false;
      double sp=_01_SpacingAtrMult*atr; if(sp<=0.0) return false;
      int n=(int)MathFloor((_01_ZoneHi-_01_ZoneLo)/sp)+1;
      g_nlv=(int)MathMax(2,MathMin(n,cap));
      for(int i=0;i<g_nlv;i++) g_levels[i]=_01_ZoneLo+sp*i;
   }
   return true; }

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr=iATR(_Symbol,PERIOD_D1,30);
   if(g_atr==INVALID_HANDLE){ Print("AGMC: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   g_last_bar=0; g_base_atr=_02_BaseAtr;
   // persisted halt / cycle state
   if(_05_ResetHalt){ GlobalVariableDel(HaltGvName()); GlobalVariableDel(CycGvName()); }
   g_halted=GlobalVariableCheck(HaltGvName());
   g_cycle_eq0=GlobalVariableCheck(CycGvName())?GlobalVariableGet(CycGvName()):0.0;
   if(_01_ZoneLo<=0.0||_01_ZoneHi<=_01_ZoneLo)
      Print("AGMC: zone not set (_01_ZoneLo/_01_ZoneHi from adaptgrid_mc_zone.py) — EA will stand down");
   if(g_halted) Print("AGMC: HALT flag persisted — no trading until _05_ResetHalt");
   if(!g_suppress_log) PrintFormat("AGMC init magic=%d zone=[%.2f..%.2f] AllowLive=%s",(int)_06_Magic,_01_ZoneLo,_01_ZoneHi,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE) IndicatorRelease(g_atr); }

double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1;
   double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(dd<=0) return -1; return pf/(1.0+dd/100.0); }

void CloseAllOwn(){
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic) g_trade.PositionClose(t); } }

void OnTick()
{
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;  // bar-open gate
   if(g_halted) return;

   double totLot; int nOpen=OwnCount(totLot);

   // ---- hard kill: equity vs cycle-start ----
   if(nOpen>0 && g_cycle_eq0>0.0){
      double eq=AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq<=g_cycle_eq0*(1.0-_05_KillDdPct/100.0)){
         Print("AGMC: HARD KILL tripped — closing all + persistent halt");
         CloseAllOwn(); g_halted=true; GlobalVariableSet(HaltGvName(),1.0); return; } }

   if(nOpen==0 && g_cycle_eq0>0.0){ g_cycle_eq0=0.0; GlobalVariableDel(CycGvName()); }  // cycle ended flat

   if(!BuildLevels()) return;
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(bid<_01_ZoneLo || bid>_01_ZoneHi) return;                  // band cap: no adds outside zone

   // caps before any send
   if(nOpen>=g_nlv || nOpen>=(int)MathMin(_01_MaxLevels,40)) return;
   double lot=_02_BaseLot;
   if(_02_InvAtrLot){ double a=Buf(g_atr,0,1); if(g_base_atr<=0.0) g_base_atr=a;
      if(a>0.0&&g_base_atr>0.0){ double f=g_base_atr/a; f=MathMin(MathMax(f,0.5),2.0); lot=_02_BaseLot*f; } }
   lot=NormalizeLotB(lot);
   if(totLot+lot>_05_MaxTotalLot) return;

   // nearest level at-or-above bid that price has reached (bid<=level) and unoccupied -> buy 1/bar
   for(int i=0;i<g_nlv;i++){
      if(g_levels[i]<bid) continue;                 // price hasn't fallen to this level
      if(g_levels[i]-bid > (LevelTp(i)-g_levels[i])) break;   // only the level within one spacing of price
      if(LevelOccupied(i)) break;
      const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double tp=NormalizeDouble(LevelTp(i),digits);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN AGMC BUY L%d @%.2f tp %.2f",i,ask,tp); return; }
      if(g_cycle_eq0<=0.0){ g_cycle_eq0=AccountInfoDouble(ACCOUNT_EQUITY); GlobalVariableSet(CycGvName(),g_cycle_eq0); }
      g_trade.Buy(lot,_Symbol,ask,0.0,tp,StringFormat("AGMC_L%d",i));
      break;
   }
}
