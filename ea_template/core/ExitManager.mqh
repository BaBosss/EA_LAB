//+------------------------------------------------------------------+
//| ExitManager.mqh (V2) - TP/SL/trailing + basket exits.            |
//|  Exit 2x: 21 FixTP / 22 ATR_TP / 23 Trail / 24 RunTrend          |
//|  SL   3x: 30 None /31 Pip /32 Money /33 ATR(+adaptive) /34 Don   |
//|           /35 SR /36 SD. SL/TP use RISK-ATR (not signal ATR).    |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_EXITMANAGER_MQH
#define BOSS_LAB_EXITMANAGER_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "Execution.mqh"

double Exit_Point() { return Indi_Point(); }

#ifdef LAB_ENTRY_17
// ORDER-082 guard G4: SL must sit on the correct side of the current tick AND
// beyond the broker's SYMBOL_TRADE_STOPS_LEVEL. If invalid, the caller (entry
// seam) must return Entry_MakeNone - NEVER silently fall back to a distance
// SL, which would change the strategy without telling anyone.
// NOTE: structural mode (this entry) is banned with stacking (StackMode !=
// STACK_SINGLE) until separately designed - naked probe only (guard G4).
bool Wave5_SLValid(const int dir, const double slPrice)
{
   if(slPrice <= 0.0) return false;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return false;
   double pt = Exit_Point();
   long stopsLevelPts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLevelPts * pt;

   if(dir == 1) // long: SL below bid, at least minDist away
   {
      if(slPrice >= t.bid) return false;
      if(minDist > 0.0 && (t.bid - slPrice) < minDist) return false;
      return true;
   }
   if(dir == 2) // short: SL above ask, at least minDist away
   {
      if(slPrice <= t.ask) return false;
      if(minDist > 0.0 && (slPrice - t.ask) < minDist) return false;
      return true;
   }
   return false;
}
#endif

// effective Risk-ATR (price), with optional regime adaptive scaling (mode 33)
double Exit_RiskATR_Scaled()
{
   double atr = Indi_RiskATR(0);
   if(atr <= 0.0) return 0.0;
   if(_33_AdaptiveON)
   {
      double ma = Indi_RiskATR_MA(_33_AdaptiveN);
      if(ma > 0.0)
      {
         double scale = atr / ma;
         if(scale < 0.7) scale = 0.7;
         if(scale > 1.5) scale = 1.5;
         atr *= scale;
      }
   }
   return atr;
}

// additive: _33_SL_MaxPips (0 = off) hard-caps the ATR SL distance (price units).
// pip = 10*point on 3/5-digit symbols. Zeus GridLog parity: SL = min(mult*ATR, 150 pips).
double Exit_CapATRDist(const double distPrice)
{
   if(_33_SL_MaxATRmult > 0.0)
   {
      double atrCap = Indi_RiskATR(0) * _33_SL_MaxATRmult;
      return (atrCap > 0.0 ? MathMin(distPrice, atrCap) : distPrice);
   }
   if(_33_SL_MaxPips <= 0.0) return distPrice;
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pipPrice = ((dg == 3 || dg == 5) ? 10.0 : 1.0) * Exit_Point();
   double cap = _33_SL_MaxPips * pipPrice;
   return (cap > 0.0 ? MathMin(distPrice, cap) : distPrice);
}

// SL distance in points for a fresh order (RISK sizing); 0 if not price-based
double Exit_SLDistancePoints()
{
   double pt = Exit_Point();
#ifdef LAB_ENTRY_17
   // guard G3: structural mode must feed the real distance to MM_FirstLot's
   // risk sizing, not silently degrade to fixed lot. Direction is implicit in
   // g_wave5_entry_ref vs g_wave5_sl_price (entry set on the same signal that
   // set the SL, so the sign of the difference is always correct).
   if(_17_UseStructLevels && g_wave5_sl_price > 0.0 && g_wave5_entry_ref > 0.0)
   {
      double d = MathAbs(g_wave5_entry_ref - g_wave5_sl_price);
      return (pt > 0.0 ? d / pt : 0.0);
   }
#endif
   switch(SLMode)
   {
      case SL_FIXED_POINTS: return _31_SL_Pip;
      case SL_ATR:          return (pt > 0.0 ? Exit_CapATRDist(_33_SL_ATRmult * Exit_RiskATR_Scaled()) / pt : 0.0);
      case SL_SD:           return (pt > 0.0 ? _36_SD_Mult * Indi_SD(1) / pt : 0.0);
      case SL_STRUCT_DONCHIAN:
      case SL_STRUCT_SR:
      {
         MqlTick t;
         if(!SymbolInfoTick(_Symbol, t)) return 0.0;
         int bars = (SLMode == SL_STRUCT_DONCHIAN ? _34_DonchianBars : _35_SRBars);
         double lo = Indi_LowestLow(bars, 1);
         double hi = Indi_HighestHigh(bars, 1);
         double dLo = (lo > 0.0 ? (t.bid - lo) / pt : 0.0);
         double dHi = (hi > 0.0 ? (hi - t.ask) / pt : 0.0);
         double d = MathMax(dLo, dHi);
         return (d > 0.0 ? d : 0.0);
      }
      default: return 0.0;  // NONE, MONEY
   }
}

// initial SL price for a new order (0 = no per-order price SL)
double Exit_InitialSL(const int dir, const double entryPrice)
{
   double pt = Exit_Point();
#ifdef LAB_ENTRY_17
   // guard G2: override at the TOP, before the switch - no shared-enum member
   // added (byte-identical guard for builds 11-16). guard G4 already vetted
   // g_wave5_sl_price in the entry seam (Entry_Wave5.mqh); Wave5_SLValid is a
   // defense-in-depth re-check here (price may have moved between signal and
   // order-open on the same tick sequence).
   if(_17_UseStructLevels && g_wave5_sl_price > 0.0)
   {
      if(!Wave5_SLValid(dir, g_wave5_sl_price)) return 0.0;
      return NormalizeDouble(g_wave5_sl_price, _Digits);
   }
#endif
   switch(SLMode)
   {
      case SL_FIXED_POINTS:
         return (dir == 1 ? entryPrice - _31_SL_Pip * pt : entryPrice + _31_SL_Pip * pt);
      case SL_ATR:
      {
         double a = Exit_CapATRDist(_33_SL_ATRmult * Exit_RiskATR_Scaled());
         return (dir == 1 ? entryPrice - a : entryPrice + a);
      }
      case SL_SD:
      {
         double a = _36_SD_Mult * Indi_SD(1);
         return (dir == 1 ? entryPrice - a : entryPrice + a);
      }
      case SL_STRUCT_DONCHIAN:
         return (dir == 1 ? Indi_LowestLow(_34_DonchianBars, 1) : Indi_HighestHigh(_34_DonchianBars, 1));
      case SL_STRUCT_SR:
         return (dir == 1 ? Indi_LowestLow(_35_SRBars, 1) : Indi_HighestHigh(_35_SRBars, 1));
      default:
         return 0.0;  // NONE, MONEY
   }
}

// initial TP price (0 = managed dynamically)
double Exit_InitialTP(const int dir, const double entryPrice)
{
   // additive: _2_SuppressLegTP (default false = unchanged behavior) forces
   // every leg to have NO per-order broker TP, relying solely on the basket
   // money TP (_2_BasketTP_Money) to close the whole basket together. Needed
   // by GridLog(14) port: standalone Zeus opens every leg with TP=0.0 (real
   // per-order SL only) - without this, chassis EXIT_ATR_TP attaches a live
   // per-leg TP that lets individual legs close independently of the basket,
   // fragmenting one basket-cycle into several partial trades (breaks parity).
   if(_2_SuppressLegTP) return 0.0;
   double pt = Exit_Point();
#ifdef LAB_ENTRY_17
   // guard G2: g_wave5_tp_price is a REFERENCE zone (100% expansion), not a
   // hard broker TP per user answer 3 (Task 4: trailing-from-start owns the
   // exit). Still published here so a downstream reader can attach it if a
   // future variant wants a hard TP; probe leaves ExitMode=EXIT_TRAIL so this
   // branch is not reached in the naked-probe run (defensive parity only).
   if(_17_UseStructLevels && g_wave5_tp_price > 0.0 && ExitMode != EXIT_TRAIL && ExitMode != EXIT_RUN_TREND)
      return NormalizeDouble(g_wave5_tp_price, _Digits);
#endif
   switch(ExitMode)
   {
      case EXIT_FIXED_TP:
         return (dir == 1 ? entryPrice + _21_TP_Pip * pt : entryPrice - _21_TP_Pip * pt);
      case EXIT_ATR_TP:
      {
         double a = _22_TP_ATRmult * Exit_RiskATR_Scaled();
         return (dir == 1 ? entryPrice + a : entryPrice - a);
      }
      default:
         return 0.0;  // TRAIL, RUN_TREND
   }
}

void Exit_ApplyTrailing()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double pt = Exit_Point();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long   type  = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      ulong  tk    = PositionGetInteger(POSITION_TICKET);
      if(type == POSITION_TYPE_BUY)
      {
         double gain = (t.bid - open) / pt;
         if(gain >= _23_TrailStart)
         {
            double newSL = t.bid - _23_TrailStep * pt;
            if(newSL > curSL) Exec_ModifyPosition(tk, newSL, curTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double gain = (open - t.ask) / pt;
         if(gain >= _23_TrailStart)
         {
            double newSL = t.ask + _23_TrailStep * pt;
            if(curSL == 0.0 || newSL < curSL) Exec_ModifyPosition(tk, newSL, curTP);
         }
      }
   }
}

#ifdef LAB_ENTRY_17
// ORDER-082 Task 4: RSI-divergence tighten. Self-contained fractal scan
// (fixed depth=2, independent of Wave5Swings.mqh which is included AFTER
// ExitManager.mqh in LabCore - deliberate duplication to avoid an include-
// order dependency) over closed bars, comparing the two most recent confirmed
// price-pivots against Indi_RSI17 at the same shift (closed-bar RSI, shift 1+).
#define WAVE5_DIVERG_DEPTH 2

bool Wave5_IsPivotHigh(const int shift, const int depth)
{
   double c = iHigh(_Symbol, _Period, shift);
   for(int k = 1; k <= depth; k++)
   {
      if(iHigh(_Symbol, _Period, shift - k) > c) return false;
      if(iHigh(_Symbol, _Period, shift + k) > c) return false;
   }
   return true;
}

bool Wave5_IsPivotLow(const int shift, const int depth)
{
   double c = iLow(_Symbol, _Period, shift);
   for(int k = 1; k <= depth; k++)
   {
      if(iLow(_Symbol, _Period, shift - k) < c) return false;
      if(iLow(_Symbol, _Period, shift + k) < c) return false;
   }
   return true;
}

// dir=1 (long): bearish divergence = newer confirmed high > older confirmed
// high, but RSI at the newer high < RSI at the older high. dir=2 mirrors on
// lows (bullish divergence = newer low < older low, RSI newer > RSI older -
// used here to tighten a SELL basket the same way).
bool Wave5_DivergenceDetected(const int dir)
{
   int found = 0;
   int shifts[2];
   int scanCap = 200; // bounded lookback, plenty for a couple of swings
   for(int s = WAVE5_DIVERG_DEPTH + 1; s <= scanCap && found < 2; s++)
   {
      bool isPivot = (dir == 1 ? Wave5_IsPivotHigh(s, WAVE5_DIVERG_DEPTH) : Wave5_IsPivotLow(s, WAVE5_DIVERG_DEPTH));
      if(!isPivot) continue;
      shifts[found] = s;
      found++;
   }
   if(found < 2) return false;

   int newerShift = shifts[0], olderShift = shifts[1]; // shifts[0] closer to now (smaller shift)
   double rsiNewer = Indi_RSI17(newerShift);
   double rsiOlder = Indi_RSI17(olderShift);
   if(rsiNewer <= 0.0 || rsiOlder <= 0.0) return false; // RSI not ready

   if(dir == 1)
   {
      double pxNewer = iHigh(_Symbol, _Period, newerShift);
      double pxOlder = iHigh(_Symbol, _Period, olderShift);
      return (pxNewer > pxOlder && rsiNewer < rsiOlder);
   }
   else
   {
      double pxNewer = iLow(_Symbol, _Period, newerShift);
      double pxOlder = iLow(_Symbol, _Period, olderShift);
      return (pxNewer < pxOlder && rsiNewer > rsiOlder);
   }
}

// tighten every matching-direction open position to a near-touch trail
// (small fraction of _23_TrailStep), regardless of current gain threshold -
// this is the divergence "take it in, edge may be fading" tighten, distinct
// from Exit_ApplyTrailing's normal _23_TrailStart-gated trail.
void Wave5_TightenTrail(const int dir)
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;
   double pt = Exit_Point();
   double tightDist = MathMax(_23_TrailStep * 0.25, 1.0) * pt;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(dir == 1 && type != POSITION_TYPE_BUY) continue;
      if(dir == 2 && type != POSITION_TYPE_SELL) continue;
      double curSL = PositionGetDouble(POSITION_SL);
      double curTP = PositionGetDouble(POSITION_TP);
      ulong  tk    = PositionGetInteger(POSITION_TICKET);
      if(type == POSITION_TYPE_BUY)
      {
         double newSL = t.bid - tightDist;
         if(newSL > curSL) Exec_ModifyPosition(tk, newSL, curTP);
      }
      else
      {
         double newSL = t.ask + tightDist;
         if(curSL == 0.0 || newSL < curSL) Exec_ModifyPosition(tk, newSL, curTP);
      }
   }
}

// hook called from Exit_ManageBasket after the base trail. No-op unless
// _17_DivergTrail and price has reached the target zone.
void Wave5_DivergenceTightenHook()
{
   if(!_17_DivergTrail) return;
   if(g_wave5_tp_price <= 0.0) return;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return;

   if(Exec_CountDir(1) > 0)
   {
      bool inZone = (t.bid >= g_wave5_tp_price);
      if(inZone && Wave5_DivergenceDetected(1)) Wave5_TightenTrail(1);
   }
   if(Exec_CountDir(2) > 0)
   {
      bool inZone = (t.ask <= g_wave5_tp_price);
      if(inZone && Wave5_DivergenceDetected(2)) Wave5_TightenTrail(2);
   }
}
#endif // LAB_ENTRY_17

// additive: 2-stage partial close as basket floating profit approaches the
// _2_BasketTP_Money target (Zeus GridLog port (14)). OFF unless both pct
// thresholds are > 0. Mirrors standalone ManagePartialClose(): flags reset
// whenever floating profit dips back to/below zero (re-arms for the next
// approach to target within the same basket).
bool g_exit_partial1_done = false;
bool g_exit_partial2_done = false;

// Effective basket target in account currency. ATR mode scales the target by
// current Risk-ATR and aggregate open volume, so it remains portable across
// instruments whose price and tick-value scales differ. Default ATR mult=0
// preserves the legacy fixed-money target exactly.
double Exit_BasketTargetMoney()
{
   if(_2_BasketTP_ATRmult <= 0.0) return _2_BasketTP_Money;

   double atr       = Indi_RiskATR(0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lots      = Exec_TotalLots();
   if(atr <= 0.0 || tickValue <= 0.0 || tickSize <= 0.0 || lots <= 0.0) return 0.0;

   return atr * _2_BasketTP_ATRmult * (tickValue / tickSize) * lots;
}

// additive: dynamic close-money target (corpus EX183/EX078). close_target =
// base + (open_order_count / C) * base - grows with how many orders are open
// in the basket. Evaluated as an ADDITIONAL/alternative target check in
// Exit_ManageBasket next to the existing fixed/ATR basket TP - whichever
// target is reached first closes the basket. Returns 0 (= off) unless
// _57_DynCloseOn is true, so behavior is unchanged by default.
double Exit_DynCloseTargetMoney()
{
   if(!_57_DynCloseOn) return 0.0;
   if(_57_DynCloseDivisor <= 0.0) return _57_DynCloseBase;
   int openCount = Exec_CountAll();
   return _57_DynCloseBase + ((double)openCount / _57_DynCloseDivisor) * _57_DynCloseBase;
}

void Exit_ManagePartialClose()
{
   // mode 93 (pending ladder): partial-close would fragment ladder legs while
   // resting siblings are still armed - basket TP is the single exit owner
   if(StackMode == STACK_PYRAMID) return;
   double targetMoney = Exit_BasketTargetMoney();
   if(targetMoney <= 0.0) return;                      // needs a target to measure % against
   if(_2_PartialPct1 <= 0.0 && _2_PartialPct2 <= 0.0) return;   // both off

   double profit = Exec_BasketProfit();
   if(profit <= 0.0) { g_exit_partial1_done = false; g_exit_partial2_done = false; return; }

   double pctOfTarget = profit / targetMoney * 100.0;

   if(!g_exit_partial1_done && _2_PartialPct1 > 0.0 && pctOfTarget >= _2_PartialPct1)
   {
      Exec_ClosePartialFraction(_2_PartialFrac1);
      g_exit_partial1_done = true;
   }
   if(!g_exit_partial2_done && _2_PartialPct2 > 0.0 && pctOfTarget >= _2_PartialPct2)
   {
      Exec_ClosePartialFraction(_2_PartialFrac2);
      g_exit_partial2_done = true;
   }
}

// ORDER-129b (Codex audit F1): the basket money-STOP is a safety exit, not management
// cadence - it must run every tick even when _0_BarOpenOnly gates the rest of the
// pipeline. Only the LOSS leg lives here; profit targets/trailing stay bar-gateable in
// Exit_ManageBasket (they can only leave money on the table, not compound a loss).
// Returns true if it flattened the basket this tick.
bool Exit_SafetyMoneyStop()
{
   if(_32_SL_Money <= 0.0) return false;
   if(Exec_CountAll() <= 0) return false;
   double profit = Exec_BasketProfit();
   if(profit <= -_32_SL_Money)
   {
      PrintFormat("[EXIT] basket money-stop (safety, intrabar): net %.2f <= -%.2f -> close all",
                  profit, _32_SL_Money);
      Exec_CloseAll();
      return true;
   }
   return false;
}

// per-tick basket management; returns true if it closed the whole basket
bool Exit_ManageBasket()
{
   if(Exec_CountAll() <= 0) return false;

   Exit_ManagePartialClose();   // no-op unless _2_PartialPct1/2 set

   double profit = Exec_BasketProfit();
   double targetMoney = Exit_BasketTargetMoney();
   if(targetMoney > 0.0 && profit >= targetMoney) { Exec_CloseAll(); return true; }
   double dynTargetMoney = Exit_DynCloseTargetMoney();   // no-op (0.0) unless _57_DynCloseOn
   if(dynTargetMoney > 0.0 && profit >= dynTargetMoney) { Exec_CloseAll(); return true; }
   if(_32_SL_Money > 0.0 && profit <= -_32_SL_Money)          { Exec_CloseAll(); return true; }

   if(ExitMode == EXIT_RUN_TREND)
   {
      double f = Indi_FastMA(0), s = Indi_SlowMA(0);
      if(f > 0.0 && s > 0.0)
      {
         if(Exec_CountDir(1) > 0 && f < s) { Exec_CloseAll(); return true; }
         if(Exec_CountDir(2) > 0 && f > s) { Exec_CloseAll(); return true; }
      }
   }

   if(ExitMode == EXIT_TRAIL) Exit_ApplyTrailing();

#ifdef LAB_ENTRY_17
   // Task 4: trailing-from-start owns the exit (ExitMode=EXIT_TRAIL, user
   // answer 3); this hook only tightens once RSI divergence appears in the
   // target zone. No-op unless _17_DivergTrail.
   if(ExitMode == EXIT_TRAIL) Wave5_DivergenceTightenHook();
#endif

   return false;
}

#endif // BOSS_LAB_EXITMANAGER_MQH
