//+------------------------------------------------------------------+
//| MoneyManagement.mqh - lot sizing in two axes:                    |
//|  first order : FIXED / RISK (risk% / SL distance)                |
//|  progression : NONE / LINEAR / MULTIPLIER / PLUS / LOG           |
//| All results clamped by RiskControl (MaxLot) + Exec normalize.    |
//+------------------------------------------------------------------+
//| *** DEPRECATED - V1 MODULE, DO NOT USE FOR NEW WORK ***          |
//|                                                                   |
//| Part of the V1 chassis (ea_template/EA_LabTemplate.mq5 +          |
//| ea_template/modules/). Superseded by Boss V2's own                |
//| ea_template/core/MoneyManagement.mqh. Not maintained: 0 rows in   |
//| the deployments inventory, 0 backtest reports, 0 .set files       |
//| reference this file (unmodified since 2026-06-18).                |
//|                                                                   |
//| Two known live defects this file still has, uncorrected (this is |
//| a comment-only banner - no logic below was touched):             |
//|  1. Silent lot-mode fallback: MM_FirstLot() below defaults to     |
//|     InpFixedLot whenever RISK mode can't produce a slDistance,    |
//|     with no warning/failure. core/MoneyManagement.mqh removed    |
//|     this exact fallback in MM-SAFETY-001 (2026-07-24) - an        |
//|     unusable config now fails the attach / skips the order        |
//|     instead of silently borrowing another mode's value.           |
//|  2. The lot this module sizes is normalized downstream by         |
//|     Exec_NormalizeLot() (ea_template/modules/Execution.mqh),      |
//|     which rounds a below-minimum lot UP to the broker minimum;    |
//|     Boss V2's normalizer returns 0 (skip the order) instead of    |
//|     silently sizing up past what was requested.                   |
//|                                                                   |
//| Do not deploy anything using this module. See                    |
//| docs/EA_CORE_AND_TEMPLATE_GUIDE.md section 3.1 (V1 vs V2) and     |
//| ea_template/DESIGN_V2.md for the full V1->V2 rationale.           |
//+------------------------------------------------------------------+
#ifndef EA_LAB_MM_MQH
#define EA_LAB_MM_MQH
#include "Inputs.mqh"
#include "RiskControl.mqh"

// money per 1.0 point move per 1.0 lot (account currency)
double MM_MoneyPerPointPerLot()
{
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickSize <= 0.0) return 0.0;
   return tickVal * (point / tickSize);
}

// first-order lot. slDistancePoints required for RISK mode (else falls back to fixed).
double MM_FirstLot(const double slDistancePoints)
{
   double lot = InpFixedLot;
   if(InpFirstLotMode == FIRSTLOT_RISK && slDistancePoints > 0.0)
   {
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
      double perPoint  = MM_MoneyPerPointPerLot();
      if(perPoint > 0.0)
         lot = riskMoney / (slDistancePoints * perPoint);
   }
   return RiskControl_ClampLot(lot);
}

// lot for grid/recovery order at given level (0 = first, 1.. = added)
double MM_NextLot(const double firstLot, const int level)
{
   int lv = level;
   int maxLv = RiskControl_MaxLevels();
   if(lv > maxLv) lv = maxLv;

   double lot = firstLot;
   switch(InpLotProgression)
   {
      case PROG_LINEAR:
         lot = firstLot * (1.0 + InpProgFactor * lv);
         break;
      case PROG_MULTIPLIER:
      {
         double m = InpProgMultiplier;
         if(InpRecoveryMultMax > 0.0 && m > InpRecoveryMultMax) m = InpRecoveryMultMax;
         lot = firstLot * MathPow(m, lv);
         break;
      }
      case PROG_PLUS:
         lot = firstLot + InpProgPlusLot * lv;
         break;
      case PROG_LOG:
         lot = firstLot * (1.0 + InpProgFactor * MathLog((double)(lv + 1)));
         break;
      case PROG_NONE:
      default:
         lot = firstLot;
         break;
   }
   return RiskControl_ClampLot(lot);
}

#endif // EA_LAB_MM_MQH
