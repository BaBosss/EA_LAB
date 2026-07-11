//+------------------------------------------------------------------+
//|                                  (EXP)_IchiADX_Naked_rev00.mq5   |
//| WOBR-triage thesis probe — EXPERIMENT ONLY, NOT FOR DEPLOY.       |
//| Tests whether an Ichimoku+ADX TREND signal has any naked edge on  |
//| FX majors H1 (EURUSD/USDJPY/GBPUSD). Standing thesis says FX      |
//| majors = reversion, so a trend signal here should smoke ~1.0 and  |
//| die. This EA is the cheapest falsification of that.               |
//| Deliberately minimal (signal-scanner naked-smoke rules):          |
//|  - ONE market position per signal, flat lot, no grid/escalation/  |
//|    recovery (single-position mode).                               |
//|  - Entry = fresh Tenkan/Kijun cross ALIGNED with Kumo (cloud) +   |
//|    ADX(14)>AdxMin + DI direction. Pure trend-following.           |
//|  - ATR(14) SL = SlAtrMult*ATR. ExitMode 1 = fixed TP TpAtrMult*ATR|
//|    ExitMode 2 = ATR trailing (trend ride, default).               |
//| Lab conventions: bar-open gate, closed-bar indicator reads        |
//| (shift 1), digit/tick-aware normalize, broker-aware lot, magic-   |
//| scoped positions, tester-gate-safe (no AllowLive block needed —   |
//| this EA never gates on live/demo). Magic 999092.                  |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "1.00"
#property description "(EXP) Ichimoku+ADX naked trend smoke - WOBR triage thesis probe"
#property strict

#include <Trade\Trade.mqh>

//==================== Inputs ========================================
input group "=== Signal: Ichimoku + ADX ==="
input int    TenkanPeriod = 9;      // Ichimoku Tenkan-sen
input int    KijunPeriod  = 26;     // Ichimoku Kijun-sen
input int    SenkouPeriod = 52;     // Ichimoku Senkou Span B
input int    AdxPeriod    = 14;     // ADX period
input double AdxMin       = 20.0;   // ADX must exceed this to allow entry (trend-strength gate)
input bool   RequireCloud = true;   // require close[1] above/below the Kumo for entry

input group "=== Exits ==="
input int    ExitMode     = 2;      // 1=fixed TP (TpAtrMult*ATR)  2=ATR trailing (trend ride)
input double TpAtrMult    = 3.0;    // ExitMode 1: TP distance = mult * ATR
input double SlAtrMult    = 2.0;    // ALL modes: initial SL = mult * ATR from entry
input double TrailAtrMult = 2.5;    // ExitMode 2: trail distance = mult * ATR behind closed-bar extreme
input int    AtrPeriod    = 14;     // ATR period (SL / TP / trail)

input group "=== General ==="
input double FixedLot     = 0.10;   // flat lot, every position
input long   MagicNo      = 999092;
input int    SlippagePts  = 20;

//==================== Globals =======================================
CTrade   g_trade;
int      g_hIchi = INVALID_HANDLE;
int      g_hADX  = INVALID_HANDLE;
int      g_hATR  = INVALID_HANDLE;
datetime g_lastBar = 0;             // bar-open gate

// iIchimoku buffer indices
#define ICHI_TENKAN   0
#define ICHI_KIJUN    1
#define ICHI_SENKOUA  2
#define ICHI_SENKOUB  3
// iADX buffer indices
#define ADX_MAIN      0
#define ADX_PLUSDI    1
#define ADX_MINUSDI   2

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
// returns 1=BUY  2=SELL  0=none. Fresh Tenkan/Kijun cross aligned
// with cloud + ADX strength + DI direction. All reads on closed bars.
int Signal()
{
   double t1 = Buf(g_hIchi, ICHI_TENKAN, 1);
   double t2 = Buf(g_hIchi, ICHI_TENKAN, 2);
   double k1 = Buf(g_hIchi, ICHI_KIJUN,  1);
   double k2 = Buf(g_hIchi, ICHI_KIJUN,  2);
   double sa = Buf(g_hIchi, ICHI_SENKOUA, 1);
   double sb = Buf(g_hIchi, ICHI_SENKOUB, 1);
   if(t1==EMPTY_VALUE || t2==EMPTY_VALUE || k1==EMPTY_VALUE || k2==EMPTY_VALUE) return 0;
   if(RequireCloud && (sa==EMPTY_VALUE || sb==EMPTY_VALUE)) return 0;

   double adx = Buf(g_hADX, ADX_MAIN,    1);
   double dip = Buf(g_hADX, ADX_PLUSDI,  1);
   double dim = Buf(g_hADX, ADX_MINUSDI, 1);
   if(adx==EMPTY_VALUE || dip==EMPTY_VALUE || dim==EMPTY_VALUE) return 0;
   if(adx <= AdxMin) return 0;

   double c1 = iClose(_Symbol, _Period, 1);
   double cloudTop = MathMax(sa, sb);
   double cloudBot = MathMin(sa, sb);

   // fresh bullish TK cross
   bool bullCross = (t2 <= k2) && (t1 > k1);
   bool bearCross = (t2 >= k2) && (t1 < k1);

   if(bullCross && dip > dim && (!RequireCloud || c1 > cloudTop)) return 1;
   if(bearCross && dim > dip && (!RequireCloud || c1 < cloudBot)) return 2;
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

   if(isBuy) g_trade.Buy(lot, _Symbol, 0.0, sl, tp, "IchiADX");
   else      g_trade.Sell(lot, _Symbol, 0.0, sl, tp, "IchiADX");
}

//==================== MQL5 events ===================================
int OnInit()
{
   if(ExitMode < 1 || ExitMode > 2)
   {
      Print("(EXP)_IchiADX: ExitMode must be 1 or 2, got ", ExitMode);
      return INIT_PARAMETERS_INCORRECT;
   }
   g_hIchi = iIchimoku(_Symbol, _Period, TenkanPeriod, KijunPeriod, SenkouPeriod);
   if(g_hIchi == INVALID_HANDLE) { Print("(EXP)_IchiADX: iIchimoku handle failed"); return INIT_FAILED; }
   g_hADX = iADX(_Symbol, _Period, AdxPeriod);
   if(g_hADX == INVALID_HANDLE) { Print("(EXP)_IchiADX: iADX handle failed"); return INIT_FAILED; }
   g_hATR = iATR(_Symbol, _Period, AtrPeriod);
   if(g_hATR == INVALID_HANDLE) { Print("(EXP)_IchiADX: iATR handle failed"); return INIT_FAILED; }
   g_lastBar = 0;
   g_trade.SetExpertMagicNumber(MagicNo);
   g_trade.SetDeviationInPoints(SlippagePts);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_hIchi != INVALID_HANDLE) IndicatorRelease(g_hIchi);
   if(g_hADX  != INVALID_HANDLE) IndicatorRelease(g_hADX);
   if(g_hATR  != INVALID_HANDLE) IndicatorRelease(g_hATR);
   g_hIchi = g_hADX = g_hATR = INVALID_HANDLE;
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
