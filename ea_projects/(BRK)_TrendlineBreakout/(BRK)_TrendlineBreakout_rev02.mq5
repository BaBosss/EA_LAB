//+------------------------------------------------------------------+
//| (BRK)_TrendlineBreakout_rev02.mq5                                |
//|                                                                    |
//| rev02 (ORDER-067, 2026-07-09): + H4 ADX regime gate (default OFF). |
//| Offline conditioning of rev01's 351 trades showed ALL losses       |
//| concentrate in ADX<20 range regime (PF 0.17) while trend regime    |
//| is positive every year 2020-2026 (PF 1.64-2.05); MC PF-5th         |
//| 1.011 -> 1.208 gated. This rev turns that finding into a real      |
//| in-EA gate for full-funnel confirmation. Magic 991008 (distinct    |
//| from live #8 = 991002, which stays untouched).                     |
//|                                                                    |
//| DIAGONAL trendline / triangle breakout — NOT horizontal S/R.      |
//| Fits an upper trendline through the last 2 confirmed pivot HIGHS  |
//| and a lower trendline through the last 2 pivot LOWS, projects both |
//| to the current bar, and trades a CLOSE beyond the projected line. |
//| Optional convergence filter => specifically triangle/wedge breaks |
//| (upper sloping down AND lower sloping up, gap narrowing).          |
//|                                                                    |
//| L1: single position, real ATR stop + RR take-profit, fixed lot,   |
//| bar-open gated, magic-scoped, hard daily/DD caps. No grid.        |
//| Origin: user request 2026-07-08 for a trendline/triangle breakout |
//| beyond the horizontal-level breakouts (BRK-XAU Donchian, London   |
//| session, Zeus ATR-channel) already validated. Magic 991002.       |
//| STATUS: NEW — validate from scratch (3-window + MC + WFA) before  |
//| any demo. Gold-momentum is the proven edge class; test there 1st. |
//+------------------------------------------------------------------+
#property strict
#property description "(BRK)_TrendlineBreakout_rev01 — diagonal trendline/triangle breakout, single-position, real SL"

#include <Trade\Trade.mqh>

//--------------------------------------------------------------------
input string _g00_            = "── [00] TESTER / OPTIMIZER ────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] PIVOTS / TRENDLINE ─────────────────";
input int    _01_PivotLeftRight = 3;    // fractal half-width: high[i] is a pivot if highest over +/- this
input int    _01_ScanBars       = 120;  // how many closed bars back to search for the 2 most-recent pivots
input bool   _01_RequireConverge = true;// true => only triangle/wedge (upper slope<0 AND lower slope>0)
input double _01_BufferAtrMult   = 0.10;// close must clear the line by this x ATR (avoid marginal pokes)

input string _g02_            = "── [02] SL / TP ───────────────────────────";
input double _02_SlAtrMult    = 1.5;
input double _02_TpAtrMult    = 4.0;    // RR ~2.7
input int    _02_AtrPeriod    = 14;

input string _g03_            = "── [03] TREND FILTER ──────────────────────";
input bool   _03_UseEma       = true;
input int    _03_EmaPeriod    = 200;    // only long above EMA, short below (breakout with the trend)

input string _g04_            = "── [04] ADX REGIME GATE (rev02) ───────────";
input bool   _04_UseAdxGate   = false;  // block entries when higher-TF ADX below threshold
input ENUM_TIMEFRAMES _04_AdxTf = PERIOD_H4;
input int    _04_AdxPeriod    = 14;
input double _04_AdxMin       = 20.0;

input string _g05_            = "── [05] TRADE MGMT ────────────────────────";
input bool   _05_BuyBreaks    = true;
input bool   _05_SellBreaks   = true;
input double _05_LotSize      = 0.01;

input string _g06_            = "── [06] RISK CAPS ─────────────────────────";
input double _06_DailyLossPct = 5.0;
input double _06_EmergencyDdPct = 25.0;

input string _g07_            = "── [07] SYSTEM ────────────────────────────";
input long   _07_Magic        = 991008;  // rev02 default — live #8 keeps 991002
input ulong  _07_Deviation    = 20;
input bool   _07_AllowLive    = false;

//--------------------------------------------------------------------
static bool     g_suppress_log = false;
static int      g_atr_handle   = INVALID_HANDLE;
static int      g_ema_handle   = INVALID_HANDLE;
static int      g_adx_handle   = INVALID_HANDLE;   // rev02 regime gate
static datetime g_last_bar     = 0;
static CTrade   g_trade;
static double   g_day_start_balance = 0.0;
static datetime g_day_stamp    = 0;
static bool     g_halted_today = false;

double PipSize(const string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(digits == 5 || digits == 3) return point * 10.0;
   return point;
}
double BufAt(const int h, const int shift){ double b[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,0,shift,1,b)<1) return 0.0; return b[0]; }
double GetATR(const int shift){ return BufAt(g_atr_handle, shift); }

bool OwnPosition()
{
   for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_07_Magic) return true; }
   return false;
}

// Find the two most-recent confirmed pivot highs (or lows) within ScanBars.
// Returns bar indices (shift from current, larger=older) into idx[0]=recent, idx[1]=older, and their prices.
bool FindPivots(const bool wantHigh, int &x1, double &y1, int &x2, double &y2)
{
   int k = _01_PivotLeftRight;
   int found = 0;
   // start from the most-recent CONFIRMED pivot: a pivot at shift s needs k bars on its right (s-k..s-1),
   // so the smallest confirmable s is k+1. Scan outward (increasing shift = older).
   for(int s = k+1; s <= _01_ScanBars && found < 2; s++)
   {
      double v = wantHigh ? iHigh(_Symbol, PERIOD_CURRENT, s) : iLow(_Symbol, PERIOD_CURRENT, s);
      bool isPivot = true;
      for(int j = 1; j <= k && isPivot; j++)
      {
         double l = wantHigh ? iHigh(_Symbol, PERIOD_CURRENT, s-j) : iLow(_Symbol, PERIOD_CURRENT, s-j);
         double r = wantHigh ? iHigh(_Symbol, PERIOD_CURRENT, s+j) : iLow(_Symbol, PERIOD_CURRENT, s+j);
         if(wantHigh){ if(l >= v || r >= v) isPivot=false; }
         else        { if(l <= v || r <= v) isPivot=false; }
      }
      if(isPivot)
      {
         if(found==0){ x1=s; y1=v; }
         else        { x2=s; y2=v; }
         found++;
         s += k; // skip ahead so the two pivots aren't adjacent noise
      }
   }
   return (found==2);
}

// Project the line through (x1,y1)-(x2,y2) to bar shift=targetShift. x is "bars ago" (bigger=older).
double ProjectLine(const int x1,const double y1,const int x2,const double y2,const int targetShift,double &slopePerBar)
{
   double dx = (double)(x2 - x1);            // forward-time span (x2 older/larger shift, x1 recent)
   if(dx == 0.0){ slopePerBar=0.0; return y1; }
   slopePerBar = (y1 - y2) / dx;             // price change per bar going FORWARD in time (shift decreasing)
   // value at targetShift: from x1, move (x1 - targetShift) bars forward
   return y1 + slopePerBar * (double)(x1 - targetShift);
}

int OnInit()
{
   g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, _02_AtrPeriod);
   if(g_atr_handle==INVALID_HANDLE){ Print("TLBrk: ATR fail"); return INIT_FAILED; }
   if(_03_UseEma){ g_ema_handle = iMA(_Symbol, PERIOD_CURRENT, _03_EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(g_ema_handle==INVALID_HANDLE){ Print("TLBrk: EMA fail"); return INIT_FAILED; } }
   if(_04_UseAdxGate){ g_adx_handle = iADX(_Symbol, _04_AdxTf, _04_AdxPeriod);
      if(g_adx_handle==INVALID_HANDLE){ Print("TLBrk: ADX fail"); return INIT_FAILED; } }
   g_trade.SetExpertMagicNumber(_07_Magic);
   g_trade.SetDeviationInPoints(_07_Deviation);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("TLBrk init magic=%d conv=%s AllowLive=%s", _07_Magic, _01_RequireConverge?"y":"n", _07_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_atr_handle); if(g_ema_handle!=INVALID_HANDLE) IndicatorRelease(g_ema_handle); if(g_adx_handle!=INVALID_HANDLE) IndicatorRelease(g_adx_handle); }

double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1.0; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT); double pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1.0; return pf/(1.0+dd/100.0); }

void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day);
   if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }

bool RiskOk()
{
   if(g_halted_today) return false;
   double eq=AccountInfoDouble(ACCOUNT_EQUITY), bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_06_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_06_DailyLossPct){ g_halted_today=true; return false; } }
   return true;
}

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0);
   if(cur==g_last_bar) return;
   g_last_bar=cur;

   if(OwnPosition()) return;              // single position — SL/TP manage the exit
   const double atr=GetATR(1); if(atr<=0.0) return;
   if(!RiskOk()) return;

   if(_04_UseAdxGate)                     // rev02: block new entries in range regime (closed H4 bar)
   {
      double a[1];
      if(CopyBuffer(g_adx_handle, 0, 1, 1, a) < 1) return;
      if(a[0] < _04_AdxMin) return;
   }

   int hx1,hx2,lx1,lx2; double hy1,hy2,ly1,ly2;
   bool haveHi = FindPivots(true,  hx1,hy1,hx2,hy2);
   bool haveLo = FindPivots(false, lx1,ly1,lx2,ly2);
   if(!haveHi || !haveLo) return;

   double upSlope, loSlope;
   double upLine = ProjectLine(hx1,hy1,hx2,hy2, 1, upSlope);   // projected upper trendline at last closed bar
   double loLine = ProjectLine(lx1,ly1,lx2,ly2, 1, loSlope);

   // Triangle/wedge filter: upper must slope DOWN (<=0) and lower slope UP (>=0) = converging.
   if(_01_RequireConverge && !(upSlope <= 0.0 && loSlope >= 0.0)) return;

   const double c1 = iClose(_Symbol,PERIOD_CURRENT,1);
   const double c2 = iClose(_Symbol,PERIOD_CURRENT,2);
   const double buf = _01_BufferAtrMult * atr;
   const double pip = PipSize(_Symbol);
   const int digits = (int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   double ema = _03_UseEma ? BufAt(g_ema_handle,1) : 0.0;
   const bool allow = _07_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);

   // Bullish break: previous bar was below/at the upper line, last closed bar closes above it + buffer.
   bool bull = _05_BuyBreaks && (c2 <= upLine) && (c1 > upLine + buf) && (!_03_UseEma || c1 > ema);
   bool bear = _05_SellBreaks && (c2 >= loLine) && (c1 < loLine - buf) && (!_03_UseEma || c1 < ema);
   if(!bull && !bear) return;

   double sl = _02_SlAtrMult*atr, tp = _02_TpAtrMult*atr;
   if(bull)
   {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN TL-BUY @%.5f up=%.5f", ask, upLine); return; }
      g_trade.Buy(_05_LotSize,_Symbol,ask,NormalizeDouble(ask-sl,digits),NormalizeDouble(ask+tp,digits),"TL_BUY");
   }
   else
   {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN TL-SELL @%.5f lo=%.5f", bid, loLine); return; }
      g_trade.Sell(_05_LotSize,_Symbol,bid,NormalizeDouble(bid+sl,digits),NormalizeDouble(bid-tp,digits),"TL_SELL");
   }
}
