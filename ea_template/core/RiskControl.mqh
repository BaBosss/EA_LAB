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
#include "Persist.mqh"

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

// additive: account-level DD gate (PortfolioGuardian_v1 port - MERGE-04).
// OFF unless RC_AcctDDLimitPct > 0. Tracks the account-equity high-water mark
// (persisted in a GlobalVariable so a restart/recompile cannot forget the peak)
// and blocks NEW first-entries while DD-from-HWM >= limit. Open baskets and
// their stack-adds are untouched (resize-not-kill).
double g_rc_acct_hwm  = 0.0;
bool   g_rc_acct_trip = false;

void RiskControl_AcctHwmUpdate()
{
   if(RC_AcctDDLimitPct <= 0.0) return;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq > g_rc_acct_hwm)
   {
      g_rc_acct_hwm = eq;
      Persist_Set("acct_hwm", g_rc_acct_hwm);
   }
}

void RiskControl_AcctGateInit()
{
   g_rc_acct_trip = false;
   g_rc_acct_hwm  = 0.0;
   if(RC_AcctDDLimitPct <= 0.0) return;
   if(Persist_Has("acct_hwm"))
   {
      g_rc_acct_hwm = Persist_Get("acct_hwm", 0.0);
      PrintFormat("[RISK] acct-DD gate: HWM %.2f restored from %s", g_rc_acct_hwm, Persist_Key("acct_hwm"));
   }
   RiskControl_AcctHwmUpdate();
}

// gate for NEW first-entries only (LabCore level-0 paths). true = allowed.
bool RiskControl_AcctGateOK()
{
   if(RC_AcctDDLimitPct <= 0.0) return true;
   if(g_rc_acct_hwm <= 0.0) return true;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = 100.0 * (g_rc_acct_hwm - eq) / g_rc_acct_hwm;
   bool blocked = (dd >= RC_AcctDDLimitPct);
   if(blocked != g_rc_acct_trip)
   {
      g_rc_acct_trip = blocked;
      PrintFormat("[RISK] acct-DD gate %s: DD %.2f%% vs limit %.2f%% (HWM %.2f) - %s",
                  (blocked ? "TRIP" : "RELEASE"), dd, RC_AcctDDLimitPct, g_rc_acct_hwm,
                  (blocked ? "blocking new first-entries" : "first-entries allowed again"));
   }
   return !blocked;
}

void RiskControl_Init()
{
   g_rc_halted      = false;
   g_rc_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_rc_max_dd_pct  = 0.0;
   g_rc_cap_blocks  = 0;
   // MERGE-05B: restore hard-kill state so restart/recompile cannot resurrect
   // a killed EA. Tester passes start with a clean GV sandbox -> no-op there.
   if(RC_PersistHalt)
   {
      if(Persist_Get("rc_halted", 0.0) > 0.5)
      {
         g_rc_halted = true;
         double p = Persist_Get("rc_peak_eq", g_rc_peak_equity);
         if(p > g_rc_peak_equity) g_rc_peak_equity = p;
         PrintFormat("[RISK] HALT restored from persist (peak %.2f) - manual un-halt: delete GV %s or set RC_PersistHalt=false",
                     g_rc_peak_equity, Persist_Key("rc_halted"));
      }
      else if(Persist_Has("rc_peak_eq"))
      {
         // not halted, but keep the pre-restart equity peak so KillDD keeps
         // measuring from the true high-water mark (anti slow-bleed reset)
         double p = Persist_Get("rc_peak_eq", 0.0);
         if(p > g_rc_peak_equity) g_rc_peak_equity = p;
      }
   }
   RiskControl_AcctGateInit();
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
   if(eq > g_rc_peak_equity)
   {
      g_rc_peak_equity = eq;
      if(RC_PersistHalt) Persist_Set("rc_peak_eq", g_rc_peak_equity);
   }
   if(g_rc_peak_equity <= 0.0) return 0.0;
   double dd = 100.0 * (g_rc_peak_equity - eq) / g_rc_peak_equity;
   if(dd > g_rc_max_dd_pct) g_rc_max_dd_pct = dd;
   return dd;
}

// HARD KILL - returns true if it fired this tick
bool RiskControl_CheckDD()
{
   RiskControl_AcctHwmUpdate();   // no-op unless RC_AcctDDLimitPct > 0
   double kill = RC_KillDDPct();
   double dd   = RiskControl_CurrentDDPct();
   if(kill > 0.0 && dd >= kill)
   {
      Exec_CloseAll();
      g_rc_halted = true;
      if(RC_PersistHalt)
      {
         Persist_Set("rc_halted", 1.0);
         Persist_Set("rc_peak_eq", g_rc_peak_equity);
      }
      PrintFormat("[RISK] HARD KILL: DD %.2f%% >= %.2f%% (profile %d) -> closed all + halt%s",
                  dd, kill, ProtectLevel, (RC_PersistHalt ? " (persisted)" : ""));
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
