//+------------------------------------------------------------------+
//| RiskControl.mqh (V2) - supreme safety cage (always on).          |
//|  ProtectLevel (01/02/03) drives KillDD / DepositLoad / MaxSteps. |
//|  RC_MaxLot + RC_RecMultMax = explicit sizing caps.               |
//|  Hard kill: equity DD% >= killDD -> close all + halt.            |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_RISKCONTROL_MQH
#define BOSS_LAB_RISKCONTROL_MQH
#include "Inputs.mqh"
#include "Execution.mqh"

bool   g_rc_halted      = false;
double g_rc_peak_equity = 0.0;
double g_rc_max_dd_pct  = 0.0;
int    g_rc_cap_blocks  = 0;

// ProtectLevel -> cage thresholds
double RC_KillDDPct()
{
   switch(ProtectLevel)
   {
      case PROTECT_TIGHT:  return 15.0;
      case PROTECT_LOOSE:  return 40.0;
      default:             return 25.0;  // NORMAL
   }
}
double RC_MaxDepositLoadPct()
{
   switch(ProtectLevel)
   {
      case PROTECT_TIGHT:  return 20.0;
      case PROTECT_LOOSE:  return 50.0;
      default:             return 30.0;
   }
}
int RC_MaxRecSteps()
{
   switch(ProtectLevel)
   {
      case PROTECT_TIGHT:  return 2;
      case PROTECT_LOOSE:  return 5;
      default:             return 3;
   }
}

void RiskControl_Init()
{
   g_rc_halted      = false;
   g_rc_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_rc_max_dd_pct  = 0.0;
   g_rc_cap_blocks  = 0;
}

bool RiskControl_IsHalted() { return g_rc_halted; }

double RiskControl_DepositLoadPct()
{
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double mar = AccountInfoDouble(ACCOUNT_MARGIN);
   if(bal <= 0.0) return 0.0;
   return 100.0 * mar / bal;
}

double RiskControl_CurrentDDPct()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_rc_peak_equity) g_rc_peak_equity = eq;
   if(g_rc_peak_equity <= 0.0) return 0.0;
   double dd = 100.0 * (g_rc_peak_equity - eq) / g_rc_peak_equity;
   if(dd > g_rc_max_dd_pct) g_rc_max_dd_pct = dd;
   return dd;
}

// HARD KILL - returns true if it fired this tick
bool RiskControl_CheckDD()
{
   double kill = RC_KillDDPct();
   double dd   = RiskControl_CurrentDDPct();
   if(kill > 0.0 && dd >= kill)
   {
      Exec_CloseAll();
      g_rc_halted = true;
      PrintFormat("[RISK] HARD KILL: DD %.2f%% >= %.2f%% (profile %d) -> closed all + halt",
                  dd, kill, ProtectLevel);
      return true;
   }
   return false;
}

bool RiskControl_AllowNewOrder()
{
   if(g_rc_halted) return false;
   double maxLoad = RC_MaxDepositLoadPct();
   if(maxLoad > 0.0 && RiskControl_DepositLoadPct() >= maxLoad)
   {
      g_rc_cap_blocks++;
      return false;
   }
   return true;
}

double RiskControl_ClampLot(double lot)
{
   if(RC_MaxLot > 0.0 && lot > RC_MaxLot) lot = RC_MaxLot;
   return lot;
}

// effective stacking/recovery levels allowed = min(stack max, cage max).
// additive: RC_MaxLevelsOverride (default 0=off) lets a grid-heavy entry decouple
// depth from ProtectLevel's RC_MaxRecSteps (2/3/5, sized for Recovery-mode steps,
// not Stack depth) while KillDD/DepositLoad still come from ProtectLevel untouched.
// Default 0 -> cageMax = RC_MaxRecSteps() exactly as before (Boss_11/12/13 unaffected).
int RiskControl_MaxLevels()
{
   int cageMax  = (RC_MaxLevelsOverride > 0 ? RC_MaxLevelsOverride : RC_MaxRecSteps());
   int stackMax = (_9_MaxLevels > 0 ? _9_MaxLevels : 1000);
   return (cageMax < stackMax ? cageMax : stackMax);
}

double RiskControl_WorstDDPct() { return g_rc_max_dd_pct; }
int    RiskControl_CapBlocks()  { return g_rc_cap_blocks; }

#endif // BOSS_LAB_RISKCONTROL_MQH
