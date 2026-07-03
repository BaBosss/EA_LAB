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
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * _42_RiskPct / 100.0;
      double perPoint  = MM_MoneyPerPointPerLot();
      if(perPoint > 0.0)
         lot = riskMoney / (slDistancePoints * perPoint);
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
      case PROG_NONE:
      default:
         lot = firstLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

#endif // BOSS_LAB_MM_MQH
