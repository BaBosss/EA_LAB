//+------------------------------------------------------------------+
//|                               (EXP)_AlligatorAO_Naked_rev00.mq5  |
//| WOBR-triage thesis probe (lead 2) — EXPERIMENT ONLY, NOT DEPLOY.  |
//| Bill Williams Alligator + Awesome Oscillator TREND signal, naked, |
//| on FX majors + XAU H1/H4. Standing thesis: FX majors = reversion, |
//| so a trend signal should smoke ~1.0 and die (companion to the     |
//| (EXP)_IchiADX probe which confirmed dead). Scaffold copied        |
//| verbatim from (EXP)_IchiADX_Naked_rev00.mq5.                      |
//|  - ONE market position per signal, flat lot, no grid/recovery.    |
//|  - Entry = Alligator lines fanned in trend direction + AO zero    |
//|    cross in the same direction. Pure trend-following.             |
//|  - ATR(14) SL. ExitMode 1 = fixed TP; 2 = ATR trail (default).    |
//| Lab conventions: bar-open gate, closed-bar reads (shift 1),       |
//| digit/tick-aware normalize, broker-aware lot, magic-scoped.       |
//| Magic 999093.                                                     |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "1.00"
#property description "(EXP) Alligator+AO naked trend smoke - WOBR triage thesis probe (lead 2)"
#property strict

#include <Trade\Trade.mqh>

//==================== Inputs ========================================
input group "=== Signal: Alligator + AO ==="
input int    JawPeriod   = 13;      // Alligator jaw (blue) SMMA period
input int    JawShift    = 8;       // jaw forward shift
input int    TeethPeriod = 8;       // Alligator teeth (red) SMMA period
input int    TeethShift  = 5;       // teeth forward shift
input int    LipsPeriod  = 5;       // Alligator lips (green) SMMA period
input int    LipsShift   = 3;       // lips forward shift

input group "=== Exits ==="
input int    ExitMode     = 2;      // 1=fixed TP (TpAtrMult*ATR)  2=ATR trailing (trend ride)
input double TpAtrMult    = 3.0;    // ExitMode 1: TP distance = mult * ATR
input double SlAtrMult     = 2.0;   // ALL modes: initial SL = mult * ATR from entry
input double TrailAtrMult = 2.5;    // ExitMode 2: trail distance = mult * ATR behind closed-bar extreme
input int    AtrPeriod    = 14;     // ATR period (SL / TP / trail)

input group "=== General ==="
input double FixedLot     = 0.10;   // flat lot, every position
input long   MagicNo      = 999093;
input int    SlippagePts  = 20;

//==================== Globals =======================================
CTrade   g_trade;
int      g_hAll = INVALID_HANDLE;   // iAlligator
int      g_hAO  = INVALID_HANDLE;   // iAO (Awesome Oscillator)
int      g_hATR = INVALID_HANDLE;
datetime g_lastBar = 0;             // bar-open gate

// iAlligator buffer indices
#define ALLIG_JAW     0
#define ALLIG_TEETH   1
#define ALLIG_LIPS    2

//==================== Helpers =======================================
double Buf(const int handle, const int bufIdx, const int shift)
{
   double b[];
   if(CopyBuffer(handle, bufIdx, shift, 1, b) < 1) return EMPTY_VALUE;
   return b[0];
}

double Atr1()
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
// returns 1=BUY  2=SELL  0=none. Alligator fanned in trend direction
// + AO zero-cross same direction. All reads on closed bars.
int Signal()
{
   double jaw   = Buf(g_hAll, ALLIG_JAW,   1);
   double teeth = Buf(g_hAll, ALLIG_TEETH, 1);
   double lips  = Buf(g_hAll, ALLIG_LIPS,  1);
   if(jaw==EMPTY_VALUE || teeth==EMPTY_VALUE || lips==EMPTY_VALUE) return 0;

   double ao1 = Buf(g_hAO, 0, 1);
   double ao2 = Buf(g_hAO, 0, 2);
   if(ao1==EMPTY_VALUE || ao2==EMPTY_VALUE) return 0;

   // fanned-up = mouth open bullish (lips>teeth>jaw); fanned-down bearish
   bool fanUp   = (lips > teeth) && (teeth > jaw);
   bool fanDown = (lips < teeth) && (teeth < jaw);
   // AO zero cross
   bool aoCrossUp   = (ao2 <= 0.0) && (ao1 > 0.0);
   bool aoCrossDown = (ao2 >= 0.0) && (ao1 < 0.0);

   if(fanUp   && aoCrossUp)   return 1;
   if(fanDown && aoCrossDown) return 2;
   return 0;
}

//==================== Exit management (bar-open) ====================
void ManagePosition(const ulong ticket)
{
   if(ExitMode != 2) return;   // ExitMode 1: broker-side SL/TP set at entry
   if(!PositionSelectByTicket(ticket)) return;
   const bool   isLong = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   const double curSL  = PositionGetDouble(POSITION_SL);
   double atr = Atr1();
   if(atr <= 0.0) return;
   double newSL = 0.0;
   if(isLong) newSL = NormPrice(iHigh(_Symbol, _Period, 1) - TrailAtrMult * atr);
   else       newSL = NormPrice(iLow(_Symbol, _Period, 1)  + TrailAtrMult * atr);
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0) tick = _Point;
   bool improves = (isLong ? (newSL > curSL + tick) : (curSL <= 0.0 || newSL < curSL - tick));
   if(improves)
      g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
}

//==================== Entry =========================================
void TryEnter(const int dir)
{
   if(dir == 0) return;
   double atr = Atr1();
   if(atr <= 0.0) return;
   const bool isBuy = (dir == 1);
   double px = SymbolInfoDouble(_Symbol, isBuy ? SYMBOL_ASK : SYMBOL_BID);
   if(px <= 0.0) return;

   double sl = NormPrice(isBuy ? px - SlAtrMult * atr : px + SlAtrMult * atr);
   double tp = 0.0;
   if(ExitMode == 1)
      tp = NormPrice(isBuy ? px + TpAtrMult * atr : px - TpAtrMult * atr);

   double stopsDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stopsDist > 0.0)
   {
      if(MathAbs(px - sl) < stopsDist) sl = NormPrice(isBuy ? px - stopsDist : px + stopsDist);
      if(tp != 0.0 && MathAbs(tp - px) < stopsDist) tp = NormPrice(isBuy ? px + stopsDist : px - stopsDist);
   }

   double lot = NormLot(FixedLot);
   if(lot <= 0.0) return;

   if(isBuy) g_trade.Buy(lot, _Symbol, 0.0, sl, tp, "AlligAO");
   else      g_trade.Sell(lot, _Symbol, 0.0, sl, tp, "AlligAO");
}

//==================== MQL5 events ===================================
int OnInit()
{
   if(ExitMode < 1 || ExitMode > 2)
   {
      Print("(EXP)_AlligatorAO: ExitMode must be 1 or 2, got ", ExitMode);
      return INIT_PARAMETERS_INCORRECT;
   }
   g_hAll = iAlligator(_Symbol, _Period, JawPeriod, JawShift, TeethPeriod, TeethShift,
                       LipsPeriod, LipsShift, MODE_SMMA, PRICE_MEDIAN);
   if(g_hAll == INVALID_HANDLE) { Print("(EXP)_AlligatorAO: iAlligator handle failed"); return INIT_FAILED; }
   g_hAO = iAO(_Symbol, _Period);
   if(g_hAO == INVALID_HANDLE) { Print("(EXP)_AlligatorAO: iAO handle failed"); return INIT_FAILED; }
   g_hATR = iATR(_Symbol, _Period, AtrPeriod);
   if(g_hATR == INVALID_HANDLE) { Print("(EXP)_AlligatorAO: iATR handle failed"); return INIT_FAILED; }
   g_lastBar = 0;
   g_trade.SetExpertMagicNumber(MagicNo);
   g_trade.SetDeviationInPoints(SlippagePts);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_hAll != INVALID_HANDLE) IndicatorRelease(g_hAll);
   if(g_hAO  != INVALID_HANDLE) IndicatorRelease(g_hAO);
   if(g_hATR != INVALID_HANDLE) IndicatorRelease(g_hATR);
   g_hAll = g_hAO = g_hATR = INVALID_HANDLE;
}

void OnTick()
{
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_lastBar) return;
   g_lastBar = curBar;

   ulong ticket = OwnPositionTicket();
   if(ticket != 0)
   {
      ManagePosition(ticket);
      return;                        // single-position mode: never add while holding
   }
   TryEnter(Signal());
}

double OnTester()
{
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   return pf;
}
//+------------------------------------------------------------------+
