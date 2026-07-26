//+------------------------------------------------------------------+
//| (TRD)_SuperTrendFlip_rev03.mq5                                    |
//|                                                                    |
//| rev03 (2026-07-26) = rev02 + ONE new optional lever, default-off:   |
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
#property description "(TRD)_SuperTrendFlip_rev03 — rev02 + optional capped pyramid into winners (default-off)"

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
static int      g_atr=INVALID_HANDLE, g_ema=INVALID_HANDLE;
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
bool SuperTrend(const int shift, int &trend, double &line)
{
   int total = _01_Lookback;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(g_atr, 0, shift, total, atrBuf) < total) return false;

   // walk oldest -> newest
   double up=0, dn=0, fup=0, fdn=0;
   int    tr = 1;
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
      if(tr == 1 && c < fdn)      tr = -1;
      else if(tr == -1 && c > fup) tr = 1;
   }
   trend = tr;
   line  = (tr == 1 ? fdn : fup);
   return true;
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
   g_trade.SetExpertMagicNumber(_06_Magic); g_trade.SetDeviationInPoints(_06_Deviation); g_trade.SetTypeFilling(ORDER_FILLING_FOK);
   g_last_bar=0; g_day_start_balance=AccountInfoDouble(ACCOUNT_BALANCE); g_day_stamp=0; g_halted_today=false;
   if(!g_suppress_log) PrintFormat("STFlip init magic=%d AllowLive=%s",_06_Magic,_06_AllowLive?"Y":"N");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ if(g_atr!=INVALID_HANDLE)IndicatorRelease(g_atr); if(g_ema!=INVALID_HANDLE)IndicatorRelease(g_ema); }
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

   int trNow=0, trPrev=0; double lineNow=0, linePrev=0;
   if(!SuperTrend(1, trNow, lineNow)) return;      // state at last closed bar
   if(!SuperTrend(2, trPrev, linePrev)) return;    // state one bar earlier

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

      // (3) trail every leg to the line (ratchet only)
      const double ns = NormalizeDouble(lineNow, digits);
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC)!=_06_Magic) continue;
         double psl=PositionGetDouble(POSITION_SL), ptp=PositionGetDouble(POSITION_TP);
         if(isBuy){ if(ns > psl) g_trade.PositionModify(t, ns, ptp); }
         else     { if(ns < psl || psl==0) g_trade.PositionModify(t, ns, ptp); }
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
      // add must already be protected by the same line the rest of the basket trails to
      if(isBuy  && ns >= px) return;
      if(!isBuy && ns <= px) return;

      double addLot = _04_LotSize * MathPow(_07_AddLotFactor, (double)st.count);
      addLot = NormalizeLotSafe(addLot);
      if(addLot <= 0.0) return;
      // The add gets its OWN TP computed from the current ATR, exactly like a fresh entry does.
      // (Do NOT read POSITION_TP here: after the trail loop above, whichever position is left
      //  selected may not even be ours -- that would copy a foreign EA's TP onto our order.)
      const double addTp = (_02_ExitMode>=1)
                         ? NormalizeDouble(isBuy ? px+_02_TpAtrMult*atrNow : px-_02_TpAtrMult*atrNow, digits)
                         : 0.0;
      if(!AllowTrade()) { if(!g_suppress_log) PrintFormat("DRYRUN ST-ADD#%d @%.2f",st.count,px); return; }
      bool ok = isBuy ? g_trade.Buy (addLot,_Symbol,px,ns,addTp,"ST_ADD")
                      : g_trade.Sell(addLot,_Symbol,px,ns,addTp,"ST_ADD");
      if(!ok && !g_suppress_log) PrintFormat("ST-ADD FAILED retcode=%d",g_trade.ResultRetcode());
      return;
   }

   // ---- flat: enter on a fresh flip only
   if(!RiskOk()) return;
   const bool flippedUp   = (trPrev==-1 && trNow==1);
   const bool flippedDown = (trPrev==1  && trNow==-1);
   if(!flippedUp && !flippedDown) return;

   const double c1=iClose(_Symbol,PERIOD_CURRENT,1);
   double ema=_03_UseEma?Buf(g_ema,0,1):0.0;
   const bool allow=_06_AllowLive||(bool)MQLInfoInteger(MQL_TESTER);
   const double atr=Buf(g_atr,0,1); if(atr<=0) return;

   bool bull=_04_Buys  && flippedUp   && (!_03_UseEma||c1>ema);
   bool bear=_04_Sells && flippedDown && (!_03_UseEma||c1<ema);

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

   if(_01_UseDonchian && (bull||bear))                                 // confluence: flip must break the prior range
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
      double sl=(_02_ExitMode==2)?NormalizeDouble(ask-_02_SlAtrMult*atr,digits):NormalizeDouble(lineNow,digits);
      double tp=(_02_ExitMode>=1)?NormalizeDouble(ask+_02_TpAtrMult*atr,digits):0.0;
      if(sl>=ask) return;                                              // SL must be below price
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ST-BUY @%.2f sl=%.2f",ask,sl); return; }
      if(!g_trade.Buy(_04_LotSize,_Symbol,ask,sl,tp,"ST_BUY") && !g_suppress_log)
         PrintFormat("ST-BUY FAILED retcode=%d",g_trade.ResultRetcode()); }
   else { double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double sl=(_02_ExitMode==2)?NormalizeDouble(bid+_02_SlAtrMult*atr,digits):NormalizeDouble(lineNow,digits);
      double tp=(_02_ExitMode>=1)?NormalizeDouble(bid-_02_TpAtrMult*atr,digits):0.0;
      if(sl<=bid) return;
      if(!allow){ if(!g_suppress_log) PrintFormat("DRYRUN ST-SELL @%.2f sl=%.2f",bid,sl); return; }
      if(!g_trade.Sell(_04_LotSize,_Symbol,bid,sl,tp,"ST_SELL") && !g_suppress_log)
         PrintFormat("ST-SELL FAILED retcode=%d",g_trade.ResultRetcode()); }
}
