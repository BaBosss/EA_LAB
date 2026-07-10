//+------------------------------------------------------------------+
//|                                     (EXP)_ST03_Naked_rev00.mq5   |
//| ORDER-071 rev02 Stage 1 — EXPERIMENT ONLY, NOT FOR DEPLOY.       |
//| Isolates the ST03 MACD-consecutive-count entry signal (verbatim  |
//| entries\Entry_ST03.mqh copy of the lab port, parity 133/133 vs   |
//| runner) with trend-style exits. Deliberately minimal:            |
//|  - ONE market position per signal, flat 0.10 lot, no grid, no    |
//|    escalation, no recovery (single-position mode).               |
//|  - ATR(14) stop loss = SlAtrMult*ATR from entry on EVERY pos.    |
//|  - ExitMode 1 = fixed TP at TpAtrMult*ATR (RR test 2.0 / 3.0)    |
//|  - ExitMode 2 = ATR trailing stop, TrailAtrMult*ATR behind best  |
//|    price (SL ratchet, favorable direction only), no fixed TP     |
//|  - ExitMode 3 = Donchian-break: close when closed bar crosses    |
//|    the opposite Donchian(20, H1) band, no fixed TP               |
//| Lab conventions: bar-open gate (whole pipeline once per new bar),|
//| closed-bar indicator values (shift 1), digit/tick-aware price    |
//| normalize, broker-aware lot normalize, magic-scoped positions.   |
//| Magic 999071.                                                    |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "1.00"
#property description "(EXP) ST03 naked-signal x trend-exit matrix - ORDER-071 rev02 Stage 1 experiment"
#property strict

#include <Trade\Trade.mqh>
#include "entries\Entry_ST03.mqh"   // pulls entries\IEntry.mqh + ..\Indicators.mqh (shim)

//==================== Experiment inputs =============================
input group "=== Experiment: exits ==="
input int    ExitMode     = 1;      // 1=fixed TP (TpAtrMult*ATR)  2=ATR trail  3=Donchian-break
input double TpAtrMult    = 2.0;    // ExitMode 1: TP distance = mult * ATR (test 2.0 / 3.0)
input double SlAtrMult    = 2.0;    // ALL modes: initial SL = mult * ATR from entry
input double TrailAtrMult = 2.0;    // ExitMode 2: trail distance = mult * ATR behind best price
input int    DonchianBars = 20;     // ExitMode 3: opposite-band lookback (H1)
input int    AtrPeriod    = 14;     // ATR period (SL / TP / trail)

input group "=== Experiment: general ==="
input double FixedLot     = 0.10;   // flat lot, every position
input long   MagicNo      = 999071;
input int    SlippagePts  = 20;

//==================== Globals =======================================
CTrade   g_trade;
int      g_hATR      = INVALID_HANDLE;
datetime g_lastBar   = 0;           // bar-open gate

//==================== Helpers =======================================
double Atr1()                        // closed-bar ATR (deterministic on bar-open)
{
   double buf[];
   if(CopyBuffer(g_hATR, 0, 1, 1, buf) < 1) return 0.0;
   return buf[0];
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

// our single position, scoped by symbol + magic. returns ticket or 0.
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

double DonchianOppositeBand(const bool isLong)
{
   // band over the DonchianBars bars BEFORE the just-closed bar (shift 2..),
   // so the closed bar's own extreme cannot trigger against itself.
   if(isLong)
   {
      int idx = iLowest(_Symbol, PERIOD_H1, MODE_LOW, DonchianBars, 2);
      if(idx < 0) return 0.0;
      return iLow(_Symbol, PERIOD_H1, idx);
   }
   int idx = iHighest(_Symbol, PERIOD_H1, MODE_HIGH, DonchianBars, 2);
   if(idx < 0) return 0.0;
   return iHigh(_Symbol, PERIOD_H1, idx);
}

//==================== Exit management (bar-open) ====================
void ManagePosition(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   const bool  isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double curSL = PositionGetDouble(POSITION_SL);

   if(ExitMode == 2)
   {
      // ATR trail: ratchet SL toward TrailAtrMult*ATR behind the closed bar's
      // extreme. SL only ever tightens -> over time it sits behind the best
      // price reached, with no stored state to lose on restart/recompile.
      double atr = Atr1();
      if(atr <= 0.0) return;
      double newSL = 0.0;
      if(isLong)  newSL = NormPrice(iHigh(_Symbol, _Period, 1) - TrailAtrMult * atr);
      else        newSL = NormPrice(iLow(_Symbol, _Period, 1) + TrailAtrMult * atr);
      double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick <= 0.0) tick = _Point;
      bool improves = (isLong ? (newSL > curSL + tick) : (curSL <= 0.0 || newSL < curSL - tick));
      if(improves)
         g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
      return;
   }

   if(ExitMode == 3)
   {
      // Donchian-break: closed bar crossed the opposite Donchian(20,H1) band.
      double band = DonchianOppositeBand(isLong);
      if(band <= 0.0) return;
      double close1 = iClose(_Symbol, PERIOD_H1, 1);
      bool broke = (isLong ? (close1 < band) : (close1 > band));
      if(broke)
         g_trade.PositionClose(ticket, ULONG_MAX);
      return;
   }
   // ExitMode 1: broker-side SL/TP set at entry — nothing to manage.
}

//==================== Entry =========================================
void TryEnter(const EntrySignal &s)
{
   if(!s.valid || s.direction == 0) return;

   double atr = Atr1();
   if(atr <= 0.0) return;

   const bool  isBuy = (s.direction == 1);
   double px = SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID);
   if(px <= 0.0) return;

   double sl = NormPrice(isBuy ? px - SlAtrMult * atr : px + SlAtrMult * atr);
   double tp = 0.0;
   if(ExitMode == 1)
      tp = NormPrice(isBuy ? px + TpAtrMult * atr : px - TpAtrMult * atr);

   // stops-level guard (tester-safe: usually 0, live brokers may enforce)
   double stopsDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stopsDist > 0.0)
   {
      if(MathAbs(px - sl) < stopsDist) sl = NormPrice(isBuy ? px - stopsDist : px + stopsDist);
      if(tp != 0.0 && MathAbs(tp - px) < stopsDist) tp = NormPrice(isBuy ? px + stopsDist : px - stopsDist);
   }

   double lot = NormLot(FixedLot);
   if(lot <= 0.0) return;

   if(isBuy) g_trade.Buy(lot, _Symbol, 0.0, sl, tp, s.reason);
   else      g_trade.Sell(lot, _Symbol, 0.0, sl, tp, s.reason);
}

//==================== MQL5 events ===================================
int OnInit()
{
   if(ExitMode < 1 || ExitMode > 3)
   {
      Print("(EXP)_ST03_Naked: ExitMode must be 1/2/3, got ", ExitMode);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!Indi_Init())
   {
      Print("(EXP)_ST03_Naked: iMACD handle failed");
      return INIT_FAILED;
   }
   g_hATR = iATR(_Symbol, _Period, AtrPeriod);
   if(g_hATR == INVALID_HANDLE)
   {
      Print("(EXP)_ST03_Naked: iATR handle failed");
      return INIT_FAILED;
   }
   Entry_ST03_Init();               // recompile-safe: resets latches + bar gate
   g_lastBar = 0;
   g_trade.SetExpertMagicNumber(MagicNo);
   g_trade.SetDeviationInPoints(SlippagePts);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Indi_Deinit();
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   g_hATR = INVALID_HANDLE;
}

void OnTick()
{
   // bar-open gate: whole pipeline runs once per NEW bar only
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_lastBar) return;
   g_lastBar = curBar;

   // LabCore-parity: Entry_Evaluate() runs EVERY bar, position open or not,
   // so the ST03 consecutive-counters + edge latches evolve identically to
   // the Boss_15 chassis. The signal is simply ignored while holding.
   EntrySignal s = Entry_Evaluate();

   ulong ticket = OwnPositionTicket();
   if(ticket != 0)
   {
      ManagePosition(ticket);
      return;                        // single-position mode: never add while holding
   }
   TryEnter(s);
}
//+------------------------------------------------------------------+
