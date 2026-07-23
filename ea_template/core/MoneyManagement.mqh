//+------------------------------------------------------------------+
//| MoneyManagement.mqh (V2) - lot sizing.                           |
//|  first order : 41 Fixed / 42 Risk% (risk / SL distance)          |
//|  progression : 50 None / 51 Lin / 52 Mult / 53 Plus / 54 Log     |
//|  All clamped by RiskControl (RC_MaxLot) + Exec normalize.        |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_MM_MQH
#define BOSS_LAB_MM_MQH
#include "Inputs.mqh"
#include "RiskControl.mqh"

double MM_MoneyPerPointPerLot()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickSize <= 0.0) return 0.0;
   return tickVal * (point / tickSize);
}

// additive (2026-07-23): convert a "% of balance" input into an absolute money figure in
// ACCOUNT CURRENCY. The one shared helper behind every _*_BalPct input, so all of them
// resolve identically and there is a single place to audit.
//
// Why percent instead of absolute money: a bare "25" means $25 on a USD account but $0.25
// on a cent account - the same .set silently trades a 100x different target. A percentage
// of balance is unitless, so it means the same thing on both, AND it scales as the account
// grows (no re-tuning a hard-coded money target after a deposit).
//
// Returns 0.0 when pct <= 0 (caller treats 0 as "feature off" and falls back to its legacy
// absolute input), or when balance is unavailable/non-positive - fail-safe: a broken
// balance read disables the percentage target rather than inventing one.
double MM_BalancePct(const double pct)
{
   if(pct <= 0.0) return 0.0;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 0.0;
   return balance * pct / 100.0;
}

// additive: DD-adaptive first-lot multiplier (Zeus GridLog _05_DdAdaptive port).
// Applied ONLY to the first order of a new basket, tiered on current floating
// account DD%, always clamped by _4_DdHardCapMult. OFF by default (returns 1.0).
double MM_DdAdaptiveMultiplier()
{
   if(!_4_DdAdaptiveOn) return 1.0;
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0.0) return 1.0;
   double ddPct = (balance - equity) / balance * 100.0;
   double mult = 1.0;
   if(ddPct >= _4_DdTier2Pct) mult = _4_DdTier2Mult;
   else if(ddPct >= _4_DdTier1Pct) mult = _4_DdTier1Mult;
   if(_4_DdHardCapMult > 0.0 && mult > _4_DdHardCapMult) mult = _4_DdHardCapMult;
   return mult;
}

// first-order lot. slDistancePoints required for RISK mode (else fixed).
double MM_FirstLot(const double slDistancePoints)
{
   double lot = _41_FixedLot;
   if(FirstLotMode == FIRSTLOT_RISK && slDistancePoints > 0.0)
   {
      double riskMoney = MM_BalancePct(_42_RiskPct);   // same math as before, shared helper
      double perPoint  = MM_MoneyPerPointPerLot();
      if(perPoint > 0.0 && riskMoney > 0.0)
         lot = riskMoney / (slDistancePoints * perPoint);
   }
   // additive (2026-07-23): balance-scaled sizing that does NOT need an SL distance, so
   // grid/basket entries (no per-order SL) can also scale with account size - FIRSTLOT_RISK
   // silently falls back to _41_FixedLot for those, which is the gap this closes.
   //   lot = _43_LotPerAnchor x (balance / _43_BalanceAnchor)
   // Ratio is unitless -> identical behavior on cent and USD accounts (set the anchor in
   // whatever units the account displays). Guarded: a non-positive anchor or unreadable
   // balance leaves lot at _41_FixedLot rather than dividing by zero / sizing off garbage.
   else if(FirstLotMode == FIRSTLOT_BALANCE && _43_BalanceAnchor > 0.0 && _43_LotPerAnchor > 0.0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance > 0.0)
         lot = _43_LotPerAnchor * (balance / _43_BalanceAnchor);
   }
   lot *= MM_DdAdaptiveMultiplier();   // no-op unless _4_DdAdaptiveOn
   return RiskControl_ClampLot(lot);
}

// lot for stacked order at given level (0 = first).
double MM_NextLot(const double firstLot, const int level)
{
   int lv    = level;
   int maxLv = RiskControl_MaxLevels();
   if(lv > maxLv) lv = maxLv;

   double lot = firstLot;
   switch(LotProg)
   {
      case PROG_LINEAR:
         lot = firstLot * (1.0 + _51_ProgFactor * lv);
         break;
      case PROG_MULTIPLIER:
      {
         double m = _52_ProgMult;
         if(RC_RecMultMax > 0.0 && m > RC_RecMultMax) m = RC_RecMultMax;
         lot = firstLot * MathPow(m, lv);
         break;
      }
      case PROG_PLUS:
         lot = firstLot + _53_PlusLot * lv;
         break;
      case PROG_LOG:
         lot = firstLot * (1.0 + _51_ProgFactor * MathLog((double)(lv + 1)));
         break;
      case PROG_LOG_POWER:
      {
         // Zeus GridLog port (14): lot = baseLot * factor^(ln orderN) [or log10],
         // orderN = lv+1 (1-indexed, so level 0 -> orderN 1 -> exponent 0 -> lot=firstLot).
         double orderN   = (double)(lv + 1);
         double exponent = (_55_UseLnNotLog10 ? MathLog(orderN) : MathLog10(orderN));
         lot = firstLot * MathPow(_55_LogPowerFactor, exponent);
         break;
      }
      case PROG_FIBONACCI:
      {
         // corpus EX191: fib = 1,2,3,5,8,13,... (fib(0)=1, fib(1)=2, ...),
         // lot(lv) = firstLot * fib(lv). Capped at the multiplier reached at
         // _56_FibMaxStep - beyond the cap, HOLD the capped multiplier instead
         // of continuing to grow (this is the anti-martingale point). Computed
         // iteratively, no recursion; level index guarded >= 0.
         int cap = (_56_FibMaxStep >= 0 ? _56_FibMaxStep : 0);
         int idx = lv;
         if(idx < 0) idx = 0;
         if(idx > cap) idx = cap;
         double fibPrev = 1.0, fibCur = 1.0; // fib(0)=1
         for(int i = 1; i <= idx; i++)
         {
            double next = fibPrev + fibCur;
            fibPrev = fibCur;
            fibCur  = next;
         }
         lot = firstLot * fibCur;
         break;
      }
      case PROG_NONE:
      default:
         lot = firstLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

#endif // BOSS_LAB_MM_MQH
