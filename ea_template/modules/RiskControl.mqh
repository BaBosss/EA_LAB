//+------------------------------------------------------------------+
//| RiskControl.mqh - supreme safety authority.                      |
//|  (1) Hard kill: equity DD% >= InpCloseAllWhenDDPct -> close+halt |
//|  (2) Adjustable caps (optimizable inputs): MaxLot, DepositLoad   |
//|  (3) Adherence stats -> later feed live-suitability/RiskControl  |
//|      score in the funnel (not a hard optimize ban).              |
//+------------------------------------------------------------------+
#ifndef EA_LAB_RISKCONTROL_MQH
#define EA_LAB_RISKCONTROL_MQH
#include "Inputs.mqh"
#include "Execution.mqh"

bool   g_rc_halted      = false;
double g_rc_peak_equity = 0.0;
double g_rc_max_dd_pct  = 0.0;   // worst DD seen this run (adherence)
int    g_rc_cap_blocks  = 0;     // times a new order was blocked by a cap

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

// (1) HARD KILL - returns true if it fired this tick
bool RiskControl_CheckDD()
{
   double dd = RiskControl_CurrentDDPct();
   if(InpCloseAllWhenDDPct > 0.0 && dd >= InpCloseAllWhenDDPct)
   {
      Exec_CloseAll();
      g_rc_halted = true;
      PrintFormat("[RISK] HARD KILL: DD %.2f%% >= %.2f%% -> closed all + halted", dd, InpCloseAllWhenDDPct);
      return true;
   }
   return false;
}

// (2) gate for opening new orders
bool RiskControl_AllowNewOrder()
{
   if(g_rc_halted) return false;
   if(InpMaxDepositLoadPct > 0.0 && RiskControl_DepositLoadPct() >= InpMaxDepositLoadPct)
   {
      g_rc_cap_blocks++;
      return false;
   }
   return true;
}

double RiskControl_ClampLot(double lot)
{
   if(InpMaxLot > 0.0 && lot > InpMaxLot) lot = InpMaxLot;
   return lot;
}

// effective recovery levels allowed (cap)
int RiskControl_MaxLevels()
{
   return (InpMaxRecoverySteps > 0 ? InpMaxRecoverySteps : 1000);
}

// (3) adherence accessors (for diagnostics / future score)
double RiskControl_WorstDDPct()  { return g_rc_max_dd_pct; }
int    RiskControl_CapBlocks()   { return g_rc_cap_blocks; }

#endif // EA_LAB_RISKCONTROL_MQH
