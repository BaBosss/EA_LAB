//+------------------------------------------------------------------+
//| (TRD)_SuperTrendFlip_rev05.mq5                                    |
//|                                                                    |
//| rev05 (2026-07-27) = rev04 + ONE new optional lever, default-off:   |
//|   _02_SlBufferAtr — hold the stop N*ATR BEYOND the SuperTrend line  |
//|   instead of exactly ON it (0.0 = rev04 behaviour, bit for bit).    |
//|                                                                    |
//|   WHY THIS EXISTS — measured, not theorised. Exit reasons counted   |
//|   across the 12 existing Model-4 half-year reports of the validated |
//|   BTCUSD H4 pyramid config:                                         |
//|       MAIN 2023-25 : 50 exits, 50 by SL, 0 by flip                  |
//|       BWD  2020-22 : 66 exits, 62 by SL, 0 by flip (4 end-of-test)  |
//|   Not one flip-close in six years, and it CANNOT happen: the stop   |
//|   sits exactly on the line, so price must pass through the stop to  |
//|   close beyond the line -- the stop always fires first and          |
//|   CloseAllOwn("flip") is unreachable except on a gap.               |
//|   So the exit this EA advertises as the edge under test ("the line  |
//|   IS the stop ... exit timing is the edge being tested") has never  |
//|   actually run. What ran was "leave on the first intrabar touch",   |
//|   which is a different, strictly earlier rule.                      |
//|   A buffer lets a wick through and hands the exit decision back to  |
//|   the bar close, i.e. to the flip logic that was always intended.   |
//|                                                                    |
//|   PRICE OF THIS LEVER — state it, do not bury it: risk per trade    |
//|   grows on BOTH sides. The stop is further away by N*ATR, AND a     |
//|   flip-close executes at the next bar OPEN rather than at the line, |
//|   so a fast move can exit materially worse than the stop would      |
//|   have. Every cage number taken with buffer>0 (worst leg % equity,  |
//|   MC ruin, eqDD) must be re-earned; none of rev03's carry over.     |
//|                                                                    |
//| rev04 (2026-07-26) = rev03 + ONE optional lever, default-off:       |
//|   RE-ENTRY inside a live trend leg (_08_ReMode). The base EA can    |
//|   only enter on a FRESH FLIP, so once the trailing line takes it    |
//|   out mid-trend it sits flat until the next flip — every            |
//|   continuation of a trend it correctly identified is forfeited.     |
//|   This lever buys those bars back WITHOUT loosening the trend       |
//|   definition: direction still comes from the same SuperTrend, the   |
//|   EMA and ER gates still apply, the stop is still the line.         |
//|   Three anchors, deliberately NON-nested so the optimizer can tell  |
//|   them apart (they cannot degenerate into each other):              |
//|     1 = depth  — retrace >= N*ATR from the leg extreme  (distance)  |
//|     2 = STO    — %K re-crosses up out of the oversold band (momentum)|
//|     3 = S-R    — retest of the static level broken at leg start     |
//|   Bounded by construction: re-entries are counted from DEAL HISTORY |
//|   inside the current leg (flat->open transitions only, so pyramid   |
//|   adds are not miscounted) and hard-capped by _08_MaxReEntries.     |
//|   State-free like the rest of this EA: a restart cannot desync it.  |
//|   WHAT THIS LEVER DOES *NOT* BOUND — say it plainly: CONCURRENT     |
//|   exposure is unchanged (re-entry only fires from flat, so open     |
//|   legs stay <= 1+_07_MaxAdds), but SEQUENTIAL baskets per leg now   |
//|   stack: up to 1+_08_MaxReEntries baskets, each able to spend a     |
//|   full _07_BasketMaxLossPct before it is killed. Only               |
//|   _05_DailyLossPct bounds that sum. Size the pair together.         |
//|   Donchian confluence is INTENTIONALLY bypassed for re-entries — it |
//|   asks price to break the prior range, which a pullback by          |
//|   definition does not do; leaving it on would silently disable the  |
//|   lever on exactly the host it was built for (BTCUSD H4 Donchian-20).|
//| rev01/rev02/rev03 untouched — their evidence stands.                |
//|                                                                    |
//| rev03 = rev02 + ONE optional lever, default-off:                    |
//|   capped PYRAMID into winners (_07_UsePyramid). Adds only while the  |
//|   basket is in profit and only after price advances N*ATR beyond the |
//|   LAST fill; every leg trails the same SuperTrend line; a flip or a  |
//|   floating-loss breach closes the WHOLE basket. Worst case is        |
//|   therefore bounded by construction, not by hope:                    |
//|     legs <= 1+_07_MaxAdds (hard cap, init-refused above 10)          |
//|     lot per leg is flat or DECREASING (_07_AddLotFactor>1 refused)   |
//|     basket floating loss >= _07_BasketMaxLossPct of balance -> flat  |
//|   This is NOT martingale: adds require profit, never a loss.         |
//|   Add count is derived from live positions each bar (state-free), so |
//|   a restart mid-basket cannot desync it.                             |
//| rev01/rev02 untouched — their evidence stands.                       |
//|                                                                    |
//| rev02 = rev01 + Kaufman Efficiency Ratio regime gate (_03_UseER).   |
//| Why: cells #13/#14/#15 all show the same failure — the flip fires   |
//| in chop. EDGE_CATALOG records the fix for this exact family:        |
//| EA_KAUFMAN_ER (ER>0.30 gate + SuperTrend signal) scored PF 2.34/50t |
//| on XAUUSD H4 where naked EA_SUPERTREND scored 1.92/33t, corr 0.946  |
//| (same edge, ER version keeps it dormant in ranging periods).        |
//| ER = |close[1]-close[1+N]| / SUM|close[i]-close[i+1]|  (0..1):      |
//| 1.0 = perfectly straight move, ~0 = pure chop. Gate blocks ENTRY    |
//| only; open-position management is untouched.                        |
//| rev01 stays byte-identical so the evidence taken with it holds.     |
//|                                                                    |
//| SuperTrend flip trend-follower. Classic SuperTrend: median price   |
//| +/- ATR(p)*mult with band ratcheting; trend flips when close       |
//| crosses the active band. Enter ON the flip in the new direction;   |
//| exit by TRAILING the stop along the SuperTrend line itself (the    |
//| line IS the stop) — no fixed TP by default. Distinct from cohort:  |
//| Donchian/squeeze/trendline enter on level breaks with fixed RR;    |
//| this one holds as long as the ATR-ratcheted line holds = exit      |
//| timing is the edge being tested, not entry.                        |
//|                                                                    |
//| SuperTrend state is RECOMPUTED from a fixed lookback every bar     |
//| (no persistent state) so recompile/restart cannot corrupt it.      |
//|                                                                    |
//| L1 with pyramid OFF: single position. With pyramid ON: <=1+MaxAdds |
//| same-direction legs, flat-or-decreasing lot, basket-DD kill.       |
//| Base: real SL always on (the line), fixed lot,                     |
//| bar-open gated, magic-scoped, hard caps. Magic 991006.            |
//| Origin: ORDER-064 idea mining 2026-07-09 — ATR-band-flip family    |
//| converged from 5 independent sources (convs 025/043/009/022 +     |
//| STRATEGY_200 #68). Gold-momentum = proven edge class -> XAUUSD H1  |
//| first, full funnel before any demo.                                |
//+------------------------------------------------------------------+
#property strict
#property description "(TRD)_SuperTrendFlip_rev05 — rev04 + optional ATR buffer on the line-stop (default-off)"

#include <Trade\Trade.mqh>

input string _g00_            = "── [00] TESTER ────────────────────────────";
input bool   _00_OptimizeMode = false;

input string _g01_            = "── [01] SUPERTREND ────────────────────────";
input int    _01_AtrPeriod    = 10;
input double _01_Mult         = 3.0;
input int    _01_Lookback     = 400;   // bars recomputed each bar-open (state-free)

input string _g01b_           = "── [01b] CONFLUENCE (rescue levers) ───────";
input bool   _01_UseDonchian  = false; // flip must coincide with a Donchian break
input int    _01_DonBars      = 60;    // Donchian lookback (prior bars, excl. signal bar)

input string _g02_            = "── [02] EXIT ──────────────────────────────";
input int    _02_ExitMode     = 0;     // 0=trail SL on the ST line (no TP) · 1=fixed ATR RR TP + line trail · 2=fixed tight-SL/wide-TP (no line mgmt)
input double _02_TpAtrMult    = 6.0;   // modes 1+2
input double _02_SlAtrMult    = 1.0;   // mode 2 only (tight SL)
input double _02_SlBufferAtr  = 0.0;   // modes 0+1: hold the stop N*ATR BEYOND the line (0.0 = on the line = rev04)

input string _g03_            = "── [03] TREND FILTER ──────────────────────";
input bool   _03_UseEma       = true;
input int    _03_EmaPeriod    = 200;

input string _g03b_           = "── [03b] KAUFMAN ER REGIME GATE ───────────";
input bool   _03_UseER        = false; // default-off: rev02 with UseER=false must equal rev01
input int    _03_ErPeriod     = 10;    // bars over which efficiency is measured (closed bars only)
input double _03_ErMin        = 0.30;  // block entry when ER < this (EDGE_CATALOG: 0.30 = trending)

input string _g07_            = "── [07] PYRAMID (scale into winners) ──────";
input bool   _07_UsePyramid   = false; // default-off: rev03 with this off must equal rev02
input int    _07_MaxAdds      = 3;     // HARD depth cap: basket can never exceed 1+MaxAdds legs
input double _07_AddAtAtr     = 1.0;   // add only after price advanced N*ATR beyond the LAST fill
input double _07_AddLotFactor = 1.0;   // 1.0 = flat adds · <1 = decreasing · >1 REFUSED at init
input double _07_BasketMaxLossPct = 8.0; // close the whole basket when floating loss >= % of balance

input string _g08_            = "── [08] RE-ENTRY INSIDE A LIVE TREND ──────";
input int    _08_ReMode       = 0;     // 0=off (rev04 must equal rev03) · 1=ATR pullback depth · 2=stochastic re-cross · 3=S-R retest
input int    _08_MaxReEntries = 1;     // HARD cap per trend leg (init-refused above 5)
input double _08_PbAtrMult    = 1.0;   // mode 1: retrace from the leg extreme, in ATR
input int    _08_StoK         = 14;    // mode 2
input int    _08_StoD         = 3;     // mode 2
input int    _08_StoSlow      = 3;     // mode 2
input double _08_StoLevel     = 25.0;  // mode 2: oversold band (sell side mirrors at 100-level)
input int    _08_SrBars       = 20;    // mode 3: lookback that defines the level broken at leg start
input double _08_SrAtrMult    = 0.5;   // mode 3: how close to that level counts as a retest, in ATR

input string _g04_            = "── [04] TRADE MGMT ────────────────────────";
input bool   _04_Buys         = true;
input bool   _04_Sells        = true;
input double _04_LotSize      = 0.01;

input string _g05_            = "── [05] RISK CAPS ─────────────────────────";
input double _05_DailyLossPct = 5.0;
input double _05_EmergencyDdPct = 25.0;

input string _g06_            = "── [06] SYSTEM ────────────────────────────";
input long   _06_Magic        = 991006;
input ulong  _06_Deviation    = 20;
input bool   _06_AllowLive    = false;

static bool     g_suppress_log=false;
static int      g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE, g_sto=INVALID_HANDLE;
static datetime g_last_bar=0;
static CTrade   g_trade;
static double   g_day_start_balance=0.0; static datetime g_day_stamp=0; static bool g_halted_today=false;

double Buf(const int h,const int b,const int sh){ double a[1]; if(h==INVALID_HANDLE) return 0.0; if(CopyBuffer(h,b,sh,1,a)<1) return 0.0; return a[0]; }

bool OwnTicket(ulong &ticket){ for(int i=0;i<PositionsTotal();i++){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
   if(PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==_06_Magic){ ticket=t; return true; } } ticket=0; return false; }

const bool AllowTrade(){ return _06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER); }

// Broker-aware lot: floor to step, clamp to [min,max]. A lot below the broker minimum is refused
// server-side with NO visible error, which reads as "no signal" in the tester -- so return 0.0 and
// let the caller skip instead of firing an order that silently dies.
double NormalizeLotSafe(double lot)
{
   const double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   const double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(st>0.0) lot = MathFloor(lot/st)*st;
   if(lot < mn) return 0.0;
   return MathMin(lot,mx);
}

// One pass over our own positions. Everything the basket logic needs comes from the live
// positions, never from a persistent counter: a restart/recompile mid-trade must not be able to
// desync the add count from reality (same state-free principle as the SuperTrend recompute).
struct OwnStats { int count; long type; double lastEntry; double floating; double lots; };
bool OwnScan(OwnStats &s)
{
   s.count=0; s.type=-1; s.lastEntry=0.0; s.floating=0.0; s.lots=0.0;
   datetime newest=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      s.count++;
      s.type = PositionGetInteger(POSITION_TYPE);
      s.floating += PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      s.lots += PositionGetDouble(POSITION_VOLUME);
      datetime ot=(datetime)PositionGetInteger(POSITION_TIME);
      if(ot>=newest){ newest=ot; s.lastEntry=PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return s.count>0;
}

void CloseAllOwn(const string why)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
      if(!g_trade.PositionClose(t) && !g_suppress_log)
         PrintFormat("ST-CLOSEALL(%s) FAILED ticket=%I64u retcode=%d",why,t,g_trade.ResultRetcode());
   }
}

// Kaufman Efficiency Ratio over the last _03_ErPeriod CLOSED bars.
// ER = |net change| / sum(|bar-to-bar change|) in [0..1]: 1 = straight line, ~0 = chop.
// Returns false when the ratio cannot be computed (missing bars, or a flat stretch where the
// path length is zero) -- callers must treat false as "gate not satisfied", never as "pass",
// so a data hole can never open a trade it would otherwise have blocked.
bool EfficiencyRatio(double &er)
{
   er = 0.0;
   const int n = _03_ErPeriod;
   if(n < 2) return false;
   if(iBars(_Symbol,PERIOD_CURRENT) < n + 2) return false;

   const double cNew = iClose(_Symbol,PERIOD_CURRENT,1);
   const double cOld = iClose(_Symbol,PERIOD_CURRENT,1+n);
   double path = 0.0;
   for(int i = 1; i <= n; i++)
      path += MathAbs(iClose(_Symbol,PERIOD_CURRENT,i) - iClose(_Symbol,PERIOD_CURRENT,i+1));
   if(path <= 0.0) return false;

   er = MathAbs(cNew - cOld) / path;
   return true;
}

// Recompute SuperTrend over the lookback ending at bar `shift` (closed bars only).
// Returns trend (+1 up / -1 down) and the active line value at that bar.
// `legStart` (out) = the shift of the bar on which the CURRENT trend began, harvested from the same
// single pass so the re-entry lever costs no extra recomputation. It is **-1 when no flip was
// observed inside the lookback** and callers MUST refuse to trade on that.
// Why -1 and not "oldest bar available": the oldest bar is not a conservative substitute, it is a
// silent uncapping. LegFreshEntries() counts re-entries from legStart, so pinning legStart to a
// ROLLING 400-bar window turns the documented guarantee ("MaxReEntries per trend leg") into
// "MaxReEntries per Lookback bars" -- re-entries age out of the window and the cap re-arms, with
// _01_Lookback as the tunable that decides how fast. The same substitution also hands mode 3 an
// arbitrary S-R window, since `tr` is seeded to +1 at the oldest bar and the first "flip" detected
// after a wrong seed is an artifact of the seed, not a real leg start.
bool SuperTrend(const int shift, int &trend, double &line, int &legStart)
{
   int total = _01_Lookback;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(g_atr, 0, shift, total, atrBuf) < total) return false;

   // walk oldest -> newest
   double up=0, dn=0, fup=0, fdn=0;
   int    tr = 1;
   int    legI = -1;              // -1 until a real flip is OBSERVED inside the lookback
   for(int i = total-1; i >= 0; i--)
   {
      int bar = shift + i;
      double med = (iHigh(_Symbol,PERIOD_CURRENT,bar) + iLow(_Symbol,PERIOD_CURRENT,bar)) / 2.0;
      double atr = atrBuf[i];
      up = med + _01_Mult*atr;
      dn = med - _01_Mult*atr;
      double closePrev = iClose(_Symbol,PERIOD_CURRENT,bar+1);
      // ratchet
      if(i == total-1){ fup = up; fdn = dn; tr = 1; }
      else
      {
         fup = (up < fup || closePrev > fup) ? up : fup;
         fdn = (dn > fdn || closePrev < fdn) ? dn : fdn;
      }
      double c = iClose(_Symbol,PERIOD_CURRENT,bar);
      if(tr == 1 && c < fdn)      { tr = -1; legI = i; }
      else if(tr == -1 && c > fup) { tr =  1; legI = i; }
   }
   trend = tr;
   line  = (tr == 1 ? fdn : fup);
   legStart = (legI < 0 ? -1 : shift + legI);
   return true;
}

// Fresh entries (flat -> open transitions) made inside the current trend leg, read from deal history.
// State-free on purpose: a restart or recompile mid-leg cannot desync the count, the same principle
// the SuperTrend recompute and the pyramid's OwnScan already follow. Counting flat->open transitions
// (rather than every DEAL_ENTRY_IN) is what keeps pyramid ADDs out of the tally -- an add never takes
// the open count from 0 to 1. Returns -1 when history cannot be read; callers must treat that as
// "do not trade", never as "no entries yet", or an unreadable history would UNCAP the lever.
int LegFreshEntries(const datetime legStartTime)
{
   if(!HistorySelect(legStartTime, TimeCurrent()+1)) return -1;
   int open=0, fresh=0;
   const int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      const ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol) continue;
      if(HistoryDealGetInteger(d,DEAL_MAGIC)!=_06_Magic) continue;
      // Only real buy/sell deals move the ledger. A balance/credit/commission deal booked with our
      // symbol+magic carries DEAL_ENTRY==0, which IS DEAL_ENTRY_IN -- it would count as an entry.
      const long ty=HistoryDealGetInteger(d,DEAL_TYPE);
      if(ty!=DEAL_TYPE_BUY && ty!=DEAL_TYPE_SELL) continue;
      const long e=HistoryDealGetInteger(d,DEAL_ENTRY);
      if(e==DEAL_ENTRY_IN)                                   { if(open==0) fresh++; open++; }
      else if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY)     { if(open>0)  open--; }
      else if(e==DEAL_ENTRY_INOUT)                           { fresh++; }   // netting reversal: closes and re-opens
      else return -1;                                                       // unknown -> fail CLOSED
   }
   return fresh;
}

// Has the pullback finished pulling back? One trigger per mode, evaluated on closed bars only.
// Every mode additionally demands that the last closed bar resumed IN the trend direction: a
// retracement only becomes a re-entry once it has stopped being a retracement.
bool ReEntryTrigger(const int trend, const int legStartShift)
{
   const bool isBuy = (trend==1);
   const double c1=iClose(_Symbol,PERIOD_CURRENT,1), o1=iOpen(_Symbol,PERIOD_CURRENT,1);
   if(isBuy  && c1<=o1) return false;
   if(!isBuy && c1>=o1) return false;

   const int legBars = legStartShift-1;          // closed bars in the leg, ending at bar 1
   if(legBars < 3) return false;                 // too young to have a retracement worth naming
   const double atr=Buf(g_atr,0,1); if(atr<=0.0) return false;

   if(_08_ReMode==1)                             // ---- distance anchor: depth from the leg extreme
   {
      // The retrace must be searched STRICTLY after the extreme (count h-1 covers shifts 1..h-1).
      // Including the extreme bar itself lets a single wide-range impulse bar satisfy "retraced
      // N*ATR" with no retracement at all -- the classic shape that manufactures backtest edge.
      if(isBuy)
      {
         const int h=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,legBars,1);
         if(h<2) return false;                   // extreme IS the resume bar -> nothing retraced yet
         const int l=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,h-1,1);
         if(l<0) return false;
         return (iHigh(_Symbol,PERIOD_CURRENT,h)-iLow(_Symbol,PERIOD_CURRENT,l)) >= _08_PbAtrMult*atr;
      }
      const int l=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,legBars,1);
      if(l<2) return false;
      const int h=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,l-1,1);
      if(h<0) return false;
      return (iHigh(_Symbol,PERIOD_CURRENT,h)-iLow(_Symbol,PERIOD_CURRENT,l)) >= _08_PbAtrMult*atr;
   }

   if(_08_ReMode==2)                             // ---- momentum anchor: %K re-crosses out of the band
   {
      // CopyBuffer into a NON-series array fills in ASCENDING time: k[0]=bar2 (older), k[1]=bar1.
      // Getting this backwards does not zero-trade -- it silently tests the OPPOSITE condition
      // (buying as %K collapses INTO the band) and still fills a whole result surface, which an
      // optimizer will happily select on. Same convention as EA_DONCHIAN_ADD.mq5:262.
      double k[2];
      if(CopyBuffer(g_sto,0,1,2,k)<2) return false;
      const double kPrev=k[0], kLast=k[1];
      if(isBuy)  return (kPrev <= _08_StoLevel        && kLast >  _08_StoLevel);
      return             (kPrev >= 100.0-_08_StoLevel && kLast <  100.0-_08_StoLevel);
   }

   if(_08_ReMode==3)                             // ---- static anchor: retest of the level broken at leg start
   {
      const int from=legStartShift+1;
      if(iBars(_Symbol,PERIOD_CURRENT) < from+_08_SrBars+1) return false;
      const double tol=_08_SrAtrMult*atr;
      if(isBuy)
      {
         const int h=iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,_08_SrBars,from);
         if(h<0) return false;
         const double lvl=iHigh(_Symbol,PERIOD_CURRENT,h);
         return (iLow(_Symbol,PERIOD_CURRENT,1) <= lvl+tol && c1 > lvl);   // dipped to it, closed above
      }
      const int l=iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,_08_SrBars,from);
      if(l<0) return false;
      const double lvl=iLow(_Symbol,PERIOD_CURRENT,l);
      return (iHigh(_Symbol,PERIOD_CURRENT,1) >= lvl-tol && c1 < lvl);
   }
   return false;
}

int OnInit()
{
   g_suppress_log=_00_OptimizeMode||(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   g_atr = iATR(_Symbol,PERIOD_CURRENT,_01_AtrPeriod);
   if(g_atr==INVALID_HANDLE){ Print("STFlip: handle fail"); return INIT_FAILED; }
   if(_03_UseEma){ g_ema=iMA(_Symbol,PERIOD_CURRENT,_03_EmaPeriod,0,MODE_EMA,PRICE_CLOSE); if(g_ema==INVALID_HANDLE) return INIT_FAILED; }
   // ER gate misconfiguration must fail LOUD at init, never silently block every entry:
   // ER lives in [0..1], so ErMin>=1.0 (or ErPeriod<2) is a gate that can never open. An
   // optimizer sweeping past that boundary would otherwise emit 0-trade passes that read
   // as "no signal" instead of "impossible setting".
   if(_03_UseER && (_03_ErPeriod < 2 || _03_ErMin <= 0.0 || _03_ErMin >= 1.0))
   { PrintFormat("STFlip: ER gate unusable (ErPeriod=%d ErMin=%.3f must be >=2 and 0<ErMin<1)",_03_ErPeriod,_03_ErMin); return INIT_FAILED; }
   // Pyramid guards — every one of these is a way to build an unbounded ladder by accident, so
   // they fail INIT rather than warn. This EA stays flat-lot-per-leg by construction.
   if(_07_UsePyramid)
   {
      if(_02_ExitMode==2)
      { Print("STFlip: pyramid needs line management (ExitMode 0 or 1); mode 2 never trails -> refusing"); return INIT_FAILED; }
      if(_07_MaxAdds < 1 || _07_MaxAdds > 10)
      { PrintFormat("STFlip: MaxAdds=%d out of range 1..10 (hard depth cap)",_07_MaxAdds); return INIT_FAILED; }
      if(_07_AddLotFactor > 1.0)
      { PrintFormat("STFlip: AddLotFactor=%.2f >1 = escalating ladder, refused (flat or decreasing only)",_07_AddLotFactor); return INIT_FAILED; }
      if(_07_AddLotFactor <= 0.0 || _07_AddAtAtr <= 0.0)
      { Print("STFlip: AddLotFactor and AddAtAtr must be >0"); return INIT_FAILED; }
      if(_07_BasketMaxLossPct <= 0.0 || _07_BasketMaxLossPct > _05_EmergencyDdPct)
      { PrintFormat("STFlip: BasketMaxLossPct=%.1f must be >0 and <= EmergencyDdPct=%.1f",_07_BasketMaxLossPct,_05_EmergencyDdPct); return INIT_FAILED; }
   }
   // A buffer under ExitMode 2 would be a SILENT no-op: that mode builds its stop from
   // _02_SlAtrMult and never touches the line at all. Refuse loudly rather than let a sweep
   // spend a whole axis discovering that one of its settings did nothing.
   // Bounded on BOTH sides, like every other lever here (_07_MaxAdds 1..10, _08_MaxReEntries 1..5,
   // _03_ErMin 0..1). A one-sided bound accepts SlBufferAtr=10, where the stop sits ~10 ATR from the
   // line and per-leg risk silently dwarfs whatever cage was pre-registered -- and a sweep will
   // happily select the widest buffer that survived the sample rather than the widest that is
   // survivable. 3 ATR is already far outside anything defensible for this EA.
   if(_02_SlBufferAtr < 0.0 || _02_SlBufferAtr > 3.0)
   { PrintFormat("STFlip: SlBufferAtr=%.2f out of range 0..3 ATR",_02_SlBufferAtr); return INIT_FAILED; }
   if(_02_SlBufferAtr > 0.0 && _02_ExitMode==2)
   { Print("STFlip: SlBufferAtr applies to the line-stop (ExitMode 0 or 1); mode 2 ignores the line -> refusing"); return INIT_FAILED; }

   // Re-entry guards. Same doctrine as the ER gate: a setting that can never fire (or can never stop
   // firing) must fail LOUD at init, because in an optimizer sweep it would otherwise surface as a
   // harmless 0-trade row instead of an impossible configuration.
   if(_08_ReMode < 0 || _08_ReMode > 3)
   { PrintFormat("STFlip: ReMode=%d unknown (0=off 1=pullback 2=STO 3=S-R)",_08_ReMode); return INIT_FAILED; }
   if(_08_ReMode > 0)
   {
      // Decided explicitly rather than by omission: ExitMode 2 never manages an open position, so a
      // flip cannot close the basket and "re-entry inside the same leg" stops meaning what it says.
      if(_02_ExitMode==2)
      { Print("STFlip: re-entry needs line management (ExitMode 0 or 1); mode 2 never closes on a flip -> refusing"); return INIT_FAILED; }
      if(_08_MaxReEntries < 1 || _08_MaxReEntries > 5)
      { PrintFormat("STFlip: MaxReEntries=%d out of range 1..5 (hard cap per trend leg)",_08_MaxReEntries); return INIT_FAILED; }
      if(_08_ReMode==1 && _08_PbAtrMult <= 0.0)
      { Print("STFlip: PbAtrMult must be >0"); return INIT_FAILED; }
      if(_08_ReMode==2)
      {
         if(_08_StoK<1 || _08_StoD<1 || _08_StoSlow<1 || _08_StoLevel<=0.0 || _08_StoLevel>=50.0)
         { PrintFormat("STFlip: STO re-entry unusable (K/D/Slow must be >=1, 0<StoLevel<50, got %.1f)",_08_StoLevel); return INIT_FAILED; }
         g_sto=iStochastic(_Symbol,PERIOD_CURRENT,_08_StoK,_08_StoD,_08_StoSlow,MODE_SMA,STO_LOWHIGH);
         if(g_sto==INVALID_HANDLE){ Print("STFlip: stochastic handle fail"); return INIT_FAILED; }
      }
      if(_08_ReMode==3 && (_08_SrBars < 2 || _08_SrAtrMult <= 0.0))
      { Print("STFlip: S-R re-entry needs SrBars>=2 and SrAtrMult>0"); return INIT_FAILED; }
   }
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("STFlip init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); if(g_sto!=INVALID_HANDLE)IndicatorRelease(g_sto); }
double OnTester(){ double t=TesterStatistics(STAT_TRADES); if(t<30) return -1; double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT),pf=TesterStatistics(STAT_PROFIT_FACTOR); if(dd<=0) return -1; return pf/(1.0+dd/100.0); }
void CheckNewDay(){ MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); datetime d=(datetime)(dt.year*10000+dt.mon*100+dt.day); if(d!=g_day_stamp){ g_day_stamp=d; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_halted_today=false; } }
bool RiskOk(){ if(g_halted_today) return false; double eq=AccountInfoDouble(ACCOUNT_EQUITY),bal=AccountInfoDouble(ACCOUNT_BALANCE);
   if(bal>0){ double dd=(bal-eq)/bal*100.0; if(dd>=_05_EmergencyDdPct){ g_halted_today=true; return false; } }
   if(g_day_start_balance>0){ double dl=(g_day_start_balance-eq)/g_day_start_balance*100.0; if(dl>=_05_DailyLossPct){ g_halted_today=true; return false; } }
   return true; }

void OnTick()
{
   CheckNewDay();
   const datetime cur=iTime(_Symbol,PERIOD_CURRENT,0); if(cur==g_last_bar) return; g_last_bar=cur;

   int trNow=0, trPrev=0, legNow=0, legPrev=0; double lineNow=0, linePrev=0;
   if(!SuperTrend(1, trNow, lineNow, legNow)) return;      // state at last closed bar
   if(!SuperTrend(2, trPrev, linePrev, legPrev)) return;   // state one bar earlier

   const int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);

   // ---- manage the open basket: trail every leg along the line, exit ALL if the line flipped,
   //      kill the basket on a floating-loss breach, then consider ONE pyramid add per bar.
   OwnStats st;
   if(OwnScan(st))
   {
      if(_02_ExitMode==2) return;                                     // mode 2: SL/TP only, no management

      const bool isBuy = (st.type==POSITION_TYPE_BUY);

      // (1) flip against the basket -> everything out, no exceptions and before anything else
      if((isBuy && trNow==-1) || (!isBuy && trNow==1)){ CloseAllOwn("flip"); return; }

      // (2) basket DD kill: bounded worst case is what makes pyramiding accountable, so this is
      //     checked on every bar and BEFORE any add can be placed.
      const double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      if(_07_BasketMaxLossPct>0.0 && bal>0.0 && st.floating < 0.0 &&
         (-st.floating / bal * 100.0) >= _07_BasketMaxLossPct)
      { CloseAllOwn("basket-DD"); return; }

      // (3) trail every leg to the line (ratchet only), optionally held N*ATR beyond it.
      //     The buffer is computed ONLY when it is switched on, so with _02_SlBufferAtr=0 this
      //     block executes the identical arithmetic rev04 did -- no extra CopyBuffer, no
      //     multiply-by-zero, nothing that could round differently. Parity has to be free.
      //     NOTE the two ENTRY stops further down are NOT branch-gated this way: they compute
      //     `lineNow -/+ _02_SlBufferAtr*atr` unconditionally. Parity still holds there, but by
      //     IEEE-754 argument rather than by construction -- `atr` is guaranteed >0 by its own
      //     guard, so `0.0*atr` is exactly +0.0 and `x-(+0.0)==x` bit for bit. Stated here because
      //     a comment that overstates its scope is how the NEXT revision waves through a real break.
      double stopLine = lineNow;
      if(_02_SlBufferAtr > 0.0)
      {
         const double atrMgmt = Buf(g_atr,0,1);
         if(atrMgmt <= 0.0) return;            // cannot size the buffer -> leave stops where they are
         stopLine = isBuy ? lineNow - _02_SlBufferAtr*atrMgmt
                          : lineNow + _02_SlBufferAtr*atrMgmt;
      }
      const double ns = NormalizeDouble(stopLine, digits);
      // While trailing, remember the TIGHTEST protection any leg already holds. The trail loop
      // discards an `ns` that moved backwards (ratchet), but the pyramid add below does not have
      // that protection -- it would take the raw `ns`. With a buffer that gap widens: `ns` now
      // moves with ATR, not just with the line, so on a bar where ATR expanded the newest and
      // least-proven leg would be opened with the LOOSEST stop in the basket. Clamp it instead.
      double bestSl = 0.0; bool haveBest = false;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
         double psl=PositionGetDouble(POSITION_SL), ptp=PositionGetDouble(POSITION_TP);
         if(isBuy){ if(ns > psl) { if(!g_trade.PositionModify(t, ns, ptp) && !g_suppress_log)
                                      PrintFormat("ST-TRAIL FAILED ticket=%I64u retcode=%d",t,g_trade.ResultRetcode()); } }
         else     { if(ns < psl || psl==0) { if(!g_trade.PositionModify(t, ns, ptp) && !g_suppress_log)
                                      PrintFormat("ST-TRAIL FAILED ticket=%I64u retcode=%d",t,g_trade.ResultRetcode()); } }
         const double eff = PositionGetDouble(POSITION_SL);
         if(eff > 0.0)
         {
            if(!haveBest) { bestSl = eff; haveBest = true; }
            else          { bestSl = isBuy ? MathMax(bestSl, eff) : MathMin(bestSl, eff); }
         }
      }

      // (4) pyramid: add ONLY into an advancing winner, capped, one add per bar.
      //     Trigger is measured from the LAST fill (st.lastEntry), not from the first, so the
      //     spacing cannot be collapsed by a single large candle adding several legs at once.
      if(!_07_UsePyramid) return;
      if(st.count >= 1+_07_MaxAdds) return;
      if(!RiskOk()) return;
      const double atrNow=Buf(g_atr,0,1); if(atrNow<=0) return;
      const double px = isBuy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
      const double advanced = isBuy ? (px - st.lastEntry) : (st.lastEntry - px);
      if(advanced < _07_AddAtAtr*atrNow) return;
      // Admission is judged on the LINE, not on the buffered stop. Judging it on `ns` would let the
      // buffer loosen the gate as a side effect -- adds would land in situations rev04 refused, and
      // the basket cage (checked once per bar-open, above) was never sized for that. The buffer is
      // allowed to change where the stop SITS; it is not allowed to change which adds are ALLOWED.
      // Compare the NORMALIZED line, not the raw one: at buffer=0 `nsLine` is bit-identical to `ns`,
      // so this gate is exactly rev04's. Comparing raw `lineNow` would differ from `ns` by up to one
      // tick of rounding and quietly break parity in the one place nobody would look for it.
      const double nsLine = NormalizeDouble(lineNow, digits);
      if(isBuy  && nsLine >= px) return;
      if(!isBuy && nsLine <= px) return;

      double addLot = _04_LotSize * MathPow(_07_AddLotFactor, (double)st.count);
      addLot = NormalizeLotSafe(addLot);
      if(addLot <= 0.0) return;
      // The add gets its OWN TP computed from the current ATR, exactly like a fresh entry does.
      // (Do NOT read POSITION_TP here: after the trail loop above, whichever position is left
      //  selected may not even be ours -- that would copy a foreign EA's TP onto our order.)
      const double addTp = (_02_ExitMode>=1)
                         ? NormalizeDouble(isBuy ? px+_02_TpAtrMult*atrNow : px-_02_TpAtrMult*atrNow, digits)
                         : 0.0;
      // Never open the newest leg looser than the basket's existing protection (see bestSl above).
      double addSl = ns;
      if(_02_SlBufferAtr > 0.0)          // gated so that buffer=0 runs rev04's code path untouched
      {
         if(haveBest) addSl = isBuy ? MathMax(ns, bestSl) : MathMin(ns, bestSl);
         if(addSl <= 0.0) return;
         if(isBuy  && addSl >= px) return;
         if(!isBuy && addSl <= px) return;
      }
      if(!AllowTrade()) { if(!g_suppress_log) PrintFormat("DRYRUN ST-ADD#%d @%.2f",st.count,px); return; }
      bool ok = isBuy ? g_trade.Buy (addLot,_Symbol,px,addSl,addTp,"ST_ADD")
                      : g_trade.Sell(addLot,_Symbol,px,addSl,addTp,"ST_ADD");
      if(!ok && !g_suppress_log) PrintFormat("ST-ADD FAILED retcode=%d",g_trade.ResultRetcode());
      return;
   }

   // ---- flat: enter on a fresh flip, or (lever [08]) re-enter inside a leg that is still running
   if(!RiskOk()) return;
   const bool flippedUp   = (trPrev==-1 && trNow==1);
   const bool flippedDown = (trPrev==1  && trNow==-1);
   bool reUp=false, reDown=false;
   if(!flippedUp && !flippedDown)
   {
      if(_08_ReMode==0) return;                                  // rev04 with the lever off == rev03
      if(legNow < 1) return;         // leg start not observed inside the lookback -> cannot bound it
      const int fresh = LegFreshEntries(iTime(_Symbol,PERIOD_CURRENT,legNow));
      if(fresh < 1) return;          // -1 (unreadable history) and 0 (leg never traded) both mean no
      if(fresh-1 >= _08_MaxReEntries) return;                    // hard cap, per leg
      if(!ReEntryTrigger(trNow, legNow)) return;
      reUp   = (trNow==1);
      reDown = (trNow==-1);
   }
   const bool isRe = (reUp || reDown);

   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   double ema=_03_UseEma?Buf(g_ema,0,1):0.0;
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double atr=Buf(g_atr,0,1); if(atr<=0) return;

   bool bull=_04_Buys  && (flippedUp||reUp)     && (!_03_UseEma||c1>ema);
   bool bear=_04_Sells && (flippedDown||reDown) && (!_03_UseEma||c1<ema);

   // ---- ER regime gate: block the ENTRY in chop. Open positions are NOT touched by this.
   if(_03_UseER && (bull||bear))
   {
      double er=0.0;
      if(!EfficiencyRatio(er)) return;                                 // cannot measure -> do not trade
      if(er < _03_ErMin)
      {
         if(!g_suppress_log) PrintFormat("ST-SKIP ER %.3f < %.3f (chop)",er,_03_ErMin);
         return;
      }
   }

   // Confluence: the FLIP must break the prior range. Skipped for re-entries by design — a pullback
   // entry is defined by price coming BACK into the range, so applying this here would mean the lever
   // can never fire on any host that uses Donchian confluence (i.e. the one it was built for).
   if(_01_UseDonchian && !isRe && (bull||bear))
   {
      double hi=-1, lo=1e18;
      for(int i=2;i<=_01_DonBars+1;i++){ hi=MathMax(hi,iHigh(_Symbol,PERIOD_CURRENT,i)); lo=MathMin(lo,iLow(_Symbol,PERIOD_CURRENT,i)); }
      if(bull && c1<=hi) bull=false;
      if(bear && c1>=lo) bear=false;
   }
   if(!bull && !bear) return;

   // silent-rejection guard: a lot below the broker minimum is refused by the server with NO visible
   // error, which reads as "no signal" (0 trades) in the tester -- see PostNewsReversion rev01 bug.
   const double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(_04_LotSize < minLot){ if(!g_suppress_log) PrintFormat("SuperTrendFlip: LotSize %.3f < broker min %.3f -- every order would silently reject, refusing to trade",_04_LotSize,minLot); return; }

   if(bull){ double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double sl=(_02_ExitMode==2)?NormalizeDouble(ask-_02_SlAtrMult*atr,digits)
                                 :NormalizeDouble(lineNow-_02_SlBufferAtr*atr,digits);
      double tp=(_02_ExitMode>=1)?NormalizeDouble(ask+_02_TpAtrMult*atr,digits):0.0;
      if(sl>=ask || sl<=0.0) return;   // SL must be below price AND positive: a buffer larger than
                                       // the price itself yields sl<=0, which the server rejects
                                       // silently -> reads as "no signal" in an optimizer row
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ST-%s @%.2f sl=%.2f",isRe?"RE-BUY":"BUY",ask,sl); return; }
      if(!g_trade.Buy(_04_LotSize,_Symbol,ask,sl,tp,isRe?"ST_RE_BUY":"ST_BUY") && !g_suppress_log)
         PrintFormat("ST-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=(_02_ExitMode==2)?NormalizeDouble(bid+_02_SlAtrMult*atr,digits)
                                 :NormalizeDouble(lineNow+_02_SlBufferAtr*atr,digits);
      double tp=(_02_ExitMode>=1)?NormalizeDouble(bid-_02_TpAtrMult*atr,digits):0.0;
      if(sl<=bid) return;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ST-%s @%.2f sl=%.2f",isRe?"RE-SELL":"SELL",bid,sl); return; }
      if(!g_trade.Sell(_04_LotSize,_Symbol,bid,sl,tp,isRe?"ST_RE_SELL":"ST_SELL") && !g_suppress_log)
         PrintFormat("ST-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
}
