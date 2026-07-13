//+------------------------------------------------------------------+
//| (TRD)_Probe_MAHP_TanhVol_rev01.mq5                                |
//|                                                                    |
//| ORDER-104 (SSRN-151 W1 probe). 2-MA crossover chassis with TWO    |
//| independent, factorial toggles to A/B two techniques from         |
//| Kakushadze & Serur "151 Trading Strategies":                      |
//|   • Toggle A (UseHPFilter, 8.1): denoise price with a CAUSAL       |
//|     Hodrick-Prescott filter BEFORE computing the MAs → fewer       |
//|     false crosses. PRIMARY test (affects entry timing + count).   |
//|   • Toggle B (UseTanhVol, 10.4): scale lot by |tanh(R/kappa)|/sigma|
//|     (momentum-strength × inverse-vol). SECONDARY (sizing only —    |
//|     does NOT change entry/exit, so whipsaw-count stays attributable|
//|     to Toggle A).                                                  |
//|                                                                    |
//| 🔴 HP filter is ONE-SIDED / CAUSAL: solved over a trailing window  |
//|    ending at the last CLOSED bar (window = past bars only). The    |
//|    paper's HP is two-sided (uses future bars) — using that in an   |
//|    EA = look-ahead = fake backtest. Here the newest window index   |
//|    IS the signal bar; no bar with index < signal bar is read.      |
//|                                                                    |
//| State-free: MAs + HP recomputed from a fixed lookback every bar,   |
//| so recompile/restart cannot corrupt state.                        |
//| L1: single position, real SL always on, bar-open gated,           |
//| magic-scoped, hard caps, tester-gate. Magic 991041.               |
//+------------------------------------------------------------------+
#property strict
#property description "(TRD)_Probe_MAHP_TanhVol rev01 — 2-MA crossover + causal-HP denoise + tanh vol-scale (ORDER-104 A/B probe)"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] MA CROSSOVER ──────────────────────";
input int    _01_FastMA       = 10;    // T1 (shorter)
input int    _01_SlowMA       = 30;    // T2 (longer)

input string _g02_            = "── [02] TOGGLE A: HP-FILTER DENOISE (8.1) ─";
input bool   _02_UseHPFilter  = false; // false = MAs on raw close · true = MAs on causal-HP-denoised price
input int    _02_HP_Window    = 120;   // trailing window (past bars) the HP is solved over; must be > SlowMA
input double _02_HP_Lambda    = 14400; // HP smoothing (100·n²; try 1600 / 14400 / 129600)

input string _g03_            = "── [03] TOGGLE B: TANH VOL-SCALE (10.4) ───";
input bool   _03_UseTanhVol   = false; // false = fixed lot · true = lot × |tanh(R/κ)| × (TargetVol/σ) [SIZING ONLY]
input int    _03_R_Period     = 20;    // bars for momentum return R
input int    _03_Kappa_Period = 100;   // bars for κ = stdev of 1-bar returns
input double _03_TargetVol    = 0.0;   // 0 = skip the 1/σ term (pure |tanh|) · else per-bar σ target for inverse-vol
input double _03_MultMin      = 0.10;  // lot multiplier floor
input double _03_MultMax      = 3.00;  // lot multiplier cap

input string _g04_            = "── [04] EXIT (ATR SL/TP) ──────────────────";
input int    _04_AtrPeriod    = 14;
input double _04_SlAtrMult    = 2.0;
input double _04_TpAtrMult    = 3.0;

input string _g05_            = "── [05] TRADE MGMT ────────────────────────";
input bool   _05_Buys         = true;
input bool   _05_Sells        = true;
input double _05_LotSize      = 0.01;  // base lot (Toggle B scales this)

input string _g06_            = "── [06] RISK CAPS ─────────────────────────";
input double _06_DailyLossPct = 5.0;
input double _06_EmergencyDdPct = 25.0;

input string _g07_            = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic        = 991041;
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

#define HP_MAXN 512

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;
static int      g_win=0;   // resolved HP/MA window length

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }

bool OwnTicket(ulong &ticket){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic){ ticket=t; return true; } } ticket=0; return false; }

//------------------------------------------------------------------
// Causal one-sided Hodrick-Prescott filter.
// Solves (I + λ·D'D) x = y for x, where D is the 2nd-difference operator.
// y[0] = OLDEST price in window, y[n-1] = NEWEST (the signal bar).
// M = I + λA is symmetric positive-definite PENTADIAGONAL → banded
// Cholesky (bandwidth 2) in O(n). Returns false on numerical failure.
//------------------------------------------------------------------
bool HPSolve(const double &y[], const int n, const double lambda, double &x[])
{
   if(n < 4 || n > HP_MAXN) return false;
   // pentadiagonal bands of A = D'D  (standard HP Gram matrix)
   double md[HP_MAXN], m1[HP_MAXN], m2[HP_MAXN];   // M diag, super-1, super-2
   for(int i=0;i<n;i++)
   {
      double aii;
      if(i==0 || i==n-1)            aii=1.0;
      else if(i==1 || i==n-2)       aii=5.0;
      else                          aii=6.0;
      md[i]=1.0+lambda*aii;                         // + I
   }
   for(int i=0;i<n-1;i++)
   {
      double a1;
      if(i==0 || i==n-2)            a1=-2.0;
      else                          a1=-4.0;
      m1[i]=lambda*a1;
   }
   for(int i=0;i<n-2;i++) m2[i]=lambda*1.0;

   // banded Cholesky:  M = L L^T,  bands ld (diag), l1 (i,i-1), l2 (i,i-2)
   double ld[HP_MAXN], l1[HP_MAXN], l2[HP_MAXN];
   for(int i=0;i<n;i++)
   {
      double v2 = (i>=2) ? m2[i-2]/ld[i-2] : 0.0;              // l2[i]
      double v1;
      if(i>=1)
      {
         double num = m1[i-1] - v2*( (i>=2)? l1[i-1] : 0.0 );
         v1 = num/ld[i-1];
      }
      else v1 = 0.0;
      double diag = md[i] - v2*v2 - v1*v1;
      if(diag <= 0.0) return false;                            // not PD → bail
      l2[i]=v2; l1[i]=v1; ld[i]=MathSqrt(diag);
   }
   // forward solve  L z = y
   double z[HP_MAXN];
   for(int i=0;i<n;i++)
   {
      double s = y[i];
      if(i>=1) s -= l1[i]*z[i-1];
      if(i>=2) s -= l2[i]*z[i-2];
      z[i]=s/ld[i];
   }
   // back solve  L^T x = z
   for(int i=n-1;i>=0;i--)
   {
      double s = z[i];
      if(i+1<n) s -= l1[i+1]*x[i+1];
      if(i+2<n) s -= l2[i+2]*x[i+2];
      x[i]=s/ld[i];
   }
   return true;
}

// mean of x[a..b] inclusive
double MeanRange(const double &x[], const int a, const int b)
{
   double s=0; for(int i=a;i<=b;i++) s+=x[i]; return s/(double)(b-a+1);
}

//------------------------------------------------------------------
// Build the (optionally HP-denoised) price series over the trailing
// window ending at bar `sigShift` (closed bar), then read the fast/slow
// MA at the signal bar and one bar earlier — all from PAST bars only.
//------------------------------------------------------------------
bool MAState(const int sigShift, double &curFast,double &curSlow,double &prevFast,double &prevSlow)
{
   const int n = g_win;
   if(n < _01_SlowMA+2) return false;
   // need bars sigShift .. sigShift+n-1 to exist
   if(Bars(_Symbol,PERIOD_CURRENT) < sigShift+n+1) return false;

   double y[HP_MAXN], x[HP_MAXN];
   // y[n-1] = newest (signal bar), y[0] = oldest
   for(int k=0;k<n;k++)
   {
      int bar = sigShift + (n-1-k);
      y[k] = iClose(_Symbol,PERIOD_CURRENT,bar);
      if(y[k]<=0) return false;
   }
   if(_02_UseHPFilter){ if(!HPSolve(y,n,_02_HP_Lambda,x)) return false; }
   else { for(int k=0;k<n;k++) x[k]=y[k]; }

   const int last = n-1;            // signal bar
   curFast  = MeanRange(x, last-_01_FastMA+1, last);
   curSlow  = MeanRange(x, last-_01_SlowMA+1, last);
   prevFast = MeanRange(x, last-_01_FastMA,   last-1);
   prevSlow = MeanRange(x, last-_01_SlowMA,   last-1);
   return true;
}

//------------------------------------------------------------------
// Toggle B: lot multiplier = clamp(|tanh(R/κ)| × (TargetVol/σ), min, max)
//------------------------------------------------------------------
double LotMultiplier()
{
   if(!_03_UseTanhVol) return 1.0;
   const int rp=_03_R_Period, kp=_03_Kappa_Period;
   if(Bars(_Symbol,PERIOD_CURRENT) < kp+2) return 1.0;
   double c0=iClose(_Symbol,PERIOD_CURRENT,1);
   double cN=iClose(_Symbol,PERIOD_CURRENT,1+rp);
   if(cN<=0) return 1.0;
   double R=(c0-cN)/cN;
   // κ and σ = stdev of 1-bar simple returns over kappa window (closed bars)
   double sum=0,sum2=0; int cnt=0;
   for(int i=1;i<=kp;i++)
   {
      double a=iClose(_Symbol,PERIOD_CURRENT,i), b=iClose(_Symbol,PERIOD_CURRENT,i+1);
      if(b<=0) continue;
      double r=(a-b)/b; sum+=r; sum2+=r*r; cnt++;
   }
   if(cnt<5) return 1.0;
   double mean=sum/cnt; double var=sum2/cnt-mean*mean; if(var<0) var=0;
   double sigma=MathSqrt(var);
   double kappa = (sigma>0)? sigma : 1e-9;
   double strength = MathAbs(MathTanh(R/kappa));
   double mult = strength;
   if(_03_TargetVol>0.0 && sigma>0.0) mult = strength*(_03_TargetVol/sigma);
   if(mult<_03_MultMin) mult=_03_MultMin;
   if(mult>_03_MultMax) mult=_03_MultMax;
   return mult;
}

double NormalizeLot(double lot)
{
   double minl=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxl=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) step=0.01;
   lot=MathRound(lot/step)*step;
   if(lot<minl) lot=minl;
   if(lot>maxl) lot=maxl;
   return NormalizeDouble(lot,2);
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(_01_FastMA<1 || _01_SlowMA<=_01_FastMA){ Print("Probe: FastMA<SlowMA required"); return INIT_PARAMETERS_INCORRECT; }
   g_win = _02_HP_Window;
   if(g_win < _01_SlowMA+2) g_win = _01_SlowMA+2;
   if(g_win > HP_MAXN)      g_win = HP_MAXN;
   g_atr = iATR(_Symbol,PERIOD_CURRENT,_04_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("Probe: ATR handle fail"); return INIT_FAILED; }
   g_trade.SetExpertMagicNumber(_07_Magic); g_trade.SetDeviationInPoints(_07_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("Probe init magic=%d HP=%s tanh=%s win=%d AllowLive=%s",
       _07_Magic,_02_UseHPFilter?"Y":"N",_03_UseTanhVol?"Y":"N",g_win,_07_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); }
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

   double cf,cs,pf,ps;
   if(!MAState(1,cf,cs,pf,ps)) return;                       // MA state at last closed bar (past bars only)

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   const double atr=Buf(g_atr,0,1); if(atr<=0) return;

   // ---- manage: exit on opposite cross (SL/TP also armed) ----
   ulong tk=0;
   if(OwnTicket(tk))
   {
      if(!PositionSelectByTicket(tk)) return;
      long ptype=PositionGetInteger(POSITION_TYPE);
      if(ptype==POSITION_TYPE_BUY  && cf<cs){ g_trade.PositionClose(tk); }
      else if(ptype==POSITION_TYPE_SELL && cf>cs){ g_trade.PositionClose(tk); }
      return;                                                // one position at a time
   }

   // ---- flat: enter on a fresh cross ----
   if(!RiskOk()) return;
   const bool flipUp   = (pf<=ps && cf>cs);
   const bool flipDown = (pf>=ps && cf<cs);
   bool bull=_05_Buys  && flipUp;
   bool bear=_05_Sells && flipDown;
   if(!bull && !bear) return;

   const bool allow=_07_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double lot=NormalizeLot(_05_LotSize*LotMultiplier());

   if(bull){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=NormalizeDouble(ask-_04_SlAtrMult*atr,digits);
      double tp=NormalizeDouble(ask+_04_TpAtrMult*atr,digits);
      if(sl>=ask) return;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN BUY @%.5f sl=%.5f lot=%.2f",ask,sl,lot); return; }
      g_trade.Buy(lot,_Symbol,ask,sl,tp,"MAHP_BUY"); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=NormalizeDouble(bid+_04_SlAtrMult*atr,digits);
      double tp=NormalizeDouble(bid-_04_TpAtrMult*atr,digits);
      if(sl<=bid) return;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN SELL @%.5f sl=%.5f lot=%.2f",bid,sl,lot); return; }
      g_trade.Sell(lot,_Symbol,bid,sl,tp,"MAHP_SELL"); }
}
