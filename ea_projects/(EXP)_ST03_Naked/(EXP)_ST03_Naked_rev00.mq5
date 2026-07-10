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
//| Stage 2 (same order): input GateMode 0-3 = H4 direction gate     |
//| (MACD / ADX+DI / EMA50-slope) that blocks NEW entries only.      |
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

input group "=== Experiment: HTF gate (Stage 2, ORDER-071 rev02) ==="
// Gate blocks NEW entries only - it NEVER closes an open position.
// All H4 values read on closed H4 bars (shift 1), bar-open evaluation.
input int    GateMode     = 0;      // 0=none 1=H4 MACD direction 2=H4 ADX(14)>20 + DI direction 3=H4 EMA50 slope

input group "=== Experiment: general ==="
input double FixedLot     = 0.10;   // flat lot, every position
input long   MagicNo      = 999071;
input int    SlippagePts  = 20;

//==================== Globals =======================================
CTrade   g_trade;
int      g_hATR      = INVALID_HANDLE;
int      g_hGateMACD = INVALID_HANDLE;  // GateMode 1: iMACD(12,26,9) on H4
int      g_hGateADX  = INVALID_HANDLE;  // GateMode 2: iADX(14) on H4
int      g_hGateEMA  = INVALID_HANDLE;  // GateMode 3: iMA(50,EMA) on H4
datetime g_lastBar   = 0;           // bar-open gate

// GateMode fixed params (Stage 2 spec - deliberately NOT swept this stage:
// isolate one variable = gate direction logic)
#define GATE_ADX_MIN       20.0    // mode 2: closed-bar H4 ADX(14) must exceed this
#define GATE_EMA_SLOPE_REF 5       // mode 3: slope = EMA50[1] vs EMA50[5]

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

//==================== HTF gate (Stage 2) ============================
double GateBuf(const int handle, const int bufIdx, const int shift)
{
   double b[];
   if(CopyBuffer(handle, bufIdx, shift, 1, b) < 1) return EMPTY_VALUE;
   return b[0];
}

// true = direction dir (1=BUY 2=SELL) is allowed to open a NEW entry.
// Fail-closed: if the H4 data is not ready, block (no half-warmed trades).
bool GateAllows(const int dir)
{
   if(GateMode == 0) return true;

   if(GateMode == 1)   // H4 MACD(12,26,9) main-vs-signal position
   {
      double m = GateBuf(g_hGateMACD, 0, 1);
      double s = GateBuf(g_hGateMACD, 1, 1);
      if(m == EMPTY_VALUE || s == EMPTY_VALUE) return false;
      if(dir == 1) return (m > s);
      if(dir == 2) return (m < s);
      return false;
   }

   if(GateMode == 2)   // H4 ADX(14) > GATE_ADX_MIN AND DI+ vs DI- direction
   {
      double adx = GateBuf(g_hGateADX, 0, 1);   // MAIN_LINE
      double dip = GateBuf(g_hGateADX, 1, 1);   // PLUSDI_LINE
      double dim = GateBuf(g_hGateADX, 2, 1);   // MINUSDI_LINE
      if(adx == EMPTY_VALUE || dip == EMPTY_VALUE || dim == EMPTY_VALUE) return false;
      if(adx <= GATE_ADX_MIN) return false;
      if(dir == 1) return (dip > dim);
      if(dir == 2) return (dim > dip);
      return false;
   }

   if(GateMode == 3)   // H4 EMA50 slope direction (EMA50[1] vs EMA50[5])
   {
      double emaNow  = GateBuf(g_hGateEMA, 0, 1);
      double emaPrev = GateBuf(g_hGateEMA, 0, GATE_EMA_SLOPE_REF);
      if(emaNow == EMPTY_VALUE || emaPrev == EMPTY_VALUE) return false;
      if(dir == 1) return (emaNow > emaPrev);
      if(dir == 2) return (emaNow < emaPrev);
      return false;
   }

   return true;   // unknown mode is rejected in OnInit; defensive default
}

//==================== Entry =========================================
void TryEnter(const EntrySignal &s)
{
   if(!s.valid || s.direction == 0) return;
   if(!GateAllows(s.direction)) return;   // Stage 2: gate blocks NEW entries only

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
   if(GateMode < 0 || GateMode > 3)
   {
      Print("(EXP)_ST03_Naked: GateMode must be 0/1/2/3, got ", GateMode);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(GateMode == 1)
   {
      g_hGateMACD = iMACD(_Symbol, PERIOD_H4, 12, 26, 9, PRICE_CLOSE);
      if(g_hGateMACD == INVALID_HANDLE) { Print("(EXP)_ST03_Naked: H4 gate iMACD failed"); return INIT_FAILED; }
   }
   if(GateMode == 2)
   {
      g_hGateADX = iADX(_Symbol, PERIOD_H4, 14);
      if(g_hGateADX == INVALID_HANDLE) { Print("(EXP)_ST03_Naked: H4 gate iADX failed"); return INIT_FAILED; }
   }
   if(GateMode == 3)
   {
      g_hGateEMA = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(g_hGateEMA == INVALID_HANDLE) { Print("(EXP)_ST03_Naked: H4 gate iMA failed"); return INIT_FAILED; }
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
   if(g_hATR      != INVALID_HANDLE) IndicatorRelease(g_hATR);
   if(g_hGateMACD != INVALID_HANDLE) IndicatorRelease(g_hGateMACD);
   if(g_hGateADX  != INVALID_HANDLE) IndicatorRelease(g_hGateADX);
   if(g_hGateEMA  != INVALID_HANDLE) IndicatorRelease(g_hGateEMA);
   g_hATR = g_hGateMACD = g_hGateADX = g_hGateEMA = INVALID_HANDLE;
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
