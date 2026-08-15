//+------------------------------------------------------------------+
//| HedgeSafety.mqh - fail-closed configuration gates for the         |
//| Hedge/Recovery semantic contract.                                  |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_HEDGE_SAFETY_MQH
#define BOSS_LAB_HEDGE_SAFETY_MQH

#include "Inputs.mqh"

// Hedge and Recovery both rely on independent positions. A netting account
// cannot provide that invariant: an opposite order modifies/reverses the one
// net position instead of creating a separate leg. Keep this pure so the exact
// INIT_FAILED contract is deterministic-testable and OnInit has no tester bypass.
int HedgeSafety_InitResult(const long accountMarginMode,
                           const bool recoveryOrHedgeEnabled,
                           const bool hedgeEnabled,
                           const double releaseDDPct,
                           const double triggerDDPct)
{
   if(recoveryOrHedgeEnabled && accountMarginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      return INIT_FAILED;
   if(hedgeEnabled && !(releaseDDPct < triggerDDPct))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

bool HedgeSafety_ValidateOnInit()
{
   long mode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   bool recoveryOrHedgeEnabled = (RecoveryMode != REC_NONE || HedgeMode != HEDGE_OFF);
   bool hedgeEnabled = (HedgeMode != HEDGE_OFF);
   int result = HedgeSafety_InitResult(mode, recoveryOrHedgeEnabled, hedgeEnabled,
                                       _H_ReleaseDDPct, _H_TriggerDDPct);
   if(result == INIT_FAILED)
   {
      if(recoveryOrHedgeEnabled && mode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         PrintFormat("[INIT] FATAL: Hedge/Recovery requires ACCOUNT_MARGIN_MODE_RETAIL_HEDGING; account mode=%d",
                     (int)mode);
      }
      else
      {
         PrintFormat("[INIT] FATAL: Hedge hysteresis requires _H_ReleaseDDPct < _H_TriggerDDPct; release=%.5f trigger=%.5f",
                     _H_ReleaseDDPct, _H_TriggerDDPct);
      }
      return false;
   }
   return true;
}

#endif // BOSS_LAB_HEDGE_SAFETY_MQH
