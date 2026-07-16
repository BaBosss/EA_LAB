//+------------------------------------------------------------------+
//|                                   (EXP)_OsmaWpr_Naked_rev00.mq5   |
//| ORDER-091 build #1 — naked probe of the TSD "MR_Trade_OsMA_WPR"  |
//| mechanism (TheStrategyLab family, the genuine NEVER-TOUCHED       |
//| cluster in the .mq4 catalog: OsMA + Williams%R, lab never tested  |
//| these signals). EXPERIMENT ONLY, NOT FOR DEPLOY.                  |
//|  Mechanism (faithful to TSD_MR_Trade_OsMA_WPR_0_36.mq4):          |
//|   - DIRECTION = OsMA(fast,slow,signal) sign on closed bar         |
//|     (OsMA = MACD main - signal = the histogram; >0 up, <0 down).  |
//|   - FILTER = Williams %R must be in a non-extreme zone in the      |
//|     trade direction (avoids entering already-exhausted moves).    |
//|   - ENTRY = price breaks the PREVIOUS bar's High/Low in the       |
//|     signal direction (TSD used a buy/sell STOP at prev extreme;   |
//|     naked = market-on-break, one position).                       |
//|   - SL = previous bar's opposite extreme (structural).            |
//|   - TP = RewardRisk * (entry - SL) distance (R-multiple).         |
//| Lab conventions: bar-open gate, closed-bar reads (shift 1),       |
//| digit/tick-aware normalize, broker-aware lot, magic-scoped,       |
//| tester-gate-safe (never gates on live/demo). Magic 999095.        |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "1.00"
#property description "(EXP) OsMA + Williams%R naked breakout probe - TSD-family, ORDER-091 build #1"
#property strict

#include <Trade\Trade.mqh>

//==================== Inputs ========================================
input group "=== Direction: OsMA (MACD histogram) ==="
input int    OsmaFast    = 12;     // OsMA fast EMA
input int    OsmaSlow    = 26;     // OsMA slow EMA
input int    OsmaSignal  = 9;      // OsMA signal SMA

input group "=== Filter: Williams %R ==="
input int    WprPeriod   = 14;     // Williams %R period
input double WprMax       = 20.0;  // for a BUY, WPR must be > -(100-WprMax) i.e. not already overbought
                                    // (WprMax=20 -> WPR must be below -20 zone entry allowed up to -20..-80 band)

input group "=== Exits ==="
input double RewardRisk  = 1.5;    // TP = RewardRisk * SL-distance
input int    AtrPeriod   = 14;     // ATR (unused for SL here; kept for future trail)
input bool   UseTrail    = false;  // optional ATR trail (off for the naked signal test)
input double TrailAtrMult= 2.0;

input group "=== General ==="
input double FixedLot     = 0.10;
input long   MagicNo      = 999095;
input int    SlippagePts  = 20;

//==================== Globals =======================================
CTrade   g_trade;
int      g_hOsma = INVALID_HANDLE;
int      g_hWpr  = INVALID_HANDLE;
int      g_hATR  = INVALID_HANDLE;
datetime g_lastBar = 0;

double Buf(const int handle, const int bufIdx, const int shift)
{
   double b[];
   if(CopyBuffer(handle, bufIdx, shift, 1, b) < 1) return EMPTY_VALUE;
   return b[0];
}
double NormPrice(const double p)
{
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) return NormalizeDouble(p, _Digits);
   return NormalizeDouble(MathRound(p / tick) * tick, _Digits);
}
double NormLot(const double lot)
{
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double v = lot;
   if(step > 0.0) v = MathFloor(v / step + 0.5) * step;
   v = MathMax(minL, MathMin(maxL, v));
   return NormalizeDouble(v, 2);
}
ulong OwnPositionTicket()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNo) continue;
      return tk;
   }
   return 0;
}

//==================== Signal ========================================
// returns 1=BUY 2=SELL 0=none. OsMA sign = direction, WPR filter = not
// already exhausted, price breaks prev-bar extreme = trigger. Closed bars.
int Signal()
{
   // all reads on CLOSED bars: OsMA[1]/WPR[1] = direction+filter as of the just-closed bar,
   // and the just-closed bar[1] must have broken bar[2]'s extreme (breakout confirmed on close).
   double osma = Buf(g_hOsma, 0, 1);
   double wpr  = Buf(g_hWpr,  0, 1);
   if(osma==EMPTY_VALUE || wpr==EMPTY_VALUE) return 0;

   double close1 = iClose(_Symbol, _Period, 1);
   double high2  = iHigh (_Symbol, _Period, 2);
   double low2   = iLow  (_Symbol, _Period, 2);
   if(high2<=0 || low2<=0 || close1<=0) return 0;

   // WPR in [-100,0]. BUY filter = up-move not already overbought (wpr below the top band).
   // SELL filter = down-move not already oversold.
   bool buyFilter  = (wpr < -WprMax);
   bool sellFilter = (wpr > -(100.0 - WprMax));

   if(osma > 0.0 && buyFilter  && close1 > high2) return 1;   // bull OsMA + filter + close broke prior high
   if(osma < 0.0 && sellFilter && close1 < low2 ) return 2;   // bear OsMA + filter + close broke prior low
   return 0;
}

//==================== Exit management ===============================
void ManagePosition(const ulong ticket)
{
   if(!UseTrail) return;
   if(!PositionSelectByTicket(ticket)) return;
   double atr[]; if(CopyBuffer(g_hATR,0,1,1,atr)<1) return;
   const bool isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double curSL = PositionGetDouble(POSITION_SL);
   double newSL = isLong ? NormPrice(iHigh(_Symbol,_Period,1) - TrailAtrMult*atr[0])
                         : NormPrice(iLow (_Symbol,_Period,1) + TrailAtrMult*atr[0]);
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); if(tick<=0) tick=_Point;
   bool improves = isLong ? (newSL > curSL + tick) : (curSL<=0.0 || newSL < curSL - tick);
   if(improves) g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
}

//==================== Entry =========================================
void TryEnter(const int dir)
{
   if(dir == 0) return;
   const bool isBuy = (dir == 1);
   double px = SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID);
   if(px <= 0.0) return;

   // structural SL = prev-bar opposite extreme
   double prevHigh = iHigh(_Symbol,_Period,1), prevLow = iLow(_Symbol,_Period,1);
   double sl = NormPrice(isBuy ? prevLow : prevHigh);
   double slDist = MathAbs(px - sl);
   if(slDist <= 0.0) return;
   double tp = NormPrice(isBuy ? px + RewardRisk*slDist : px - RewardRisk*slDist);

   double stopsDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stopsDist > 0.0)
   {
      if(MathAbs(px - sl) < stopsDist) sl = NormPrice(isBuy ? px - stopsDist : px + stopsDist);
      if(MathAbs(tp - px) < stopsDist) tp = NormPrice(isBuy ? px + stopsDist : px - stopsDist);
   }
   double lot = NormLot(FixedLot);
   if(lot <= 0.0) return;
   if(isBuy) g_trade.Buy (lot, _Symbol, 0.0, sl, tp, "OsmaWpr");
   else      g_trade.Sell(lot, _Symbol, 0.0, sl, tp, "OsmaWpr");
}

//==================== MQL5 events ===================================
int OnInit()
{
   g_hOsma = iOsMA(_Symbol, _Period, OsmaFast, OsmaSlow, OsmaSignal, PRICE_CLOSE);
   if(g_hOsma == INVALID_HANDLE) { Print("(EXP)_OsmaWpr: iOsMA failed"); return INIT_FAILED; }
   g_hWpr = iWPR(_Symbol, _Period, WprPeriod);
   if(g_hWpr == INVALID_HANDLE) { Print("(EXP)_OsmaWpr: iWPR failed"); return INIT_FAILED; }
   g_hATR = iATR(_Symbol, _Period, AtrPeriod);
   if(g_hATR == INVALID_HANDLE) { Print("(EXP)_OsmaWpr: iATR failed"); return INIT_FAILED; }
   g_lastBar = 0;
   g_trade.SetExpertMagicNumber(MagicNo);
   g_trade.SetDeviationInPoints(SlippagePts);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason)
{
   if(g_hOsma!=INVALID_HANDLE) IndicatorRelease(g_hOsma);
   if(g_hWpr !=INVALID_HANDLE) IndicatorRelease(g_hWpr);
   if(g_hATR !=INVALID_HANDLE) IndicatorRelease(g_hATR);
}
void OnTick()
{
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_lastBar) return;      // bar-open gate: evaluate signal once per bar
   g_lastBar = curBar;

   ulong ticket = OwnPositionTicket();
   if(ticket != 0) { ManagePosition(ticket); return; }  // single-position mode
   TryEnter(Signal());
}
double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   return TesterStatistics(STAT_PROFIT_FACTOR);
}
//+------------------------------------------------------------------+
