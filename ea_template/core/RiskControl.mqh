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
bool   g_rc_kill_pending = false;   // ORDER-129: kill fired, broker flatness not yet verified

// ORDER-132 (Codex F6): ONE persisted state value ("rc_state") replaces the old
// rc_halted + rc_kill_pending flag pair - two independent writes could crash
// into the contradictory HALTED&&KILL_PENDING combination, and a manual reset
// that deleted only one flag immediately re-derived the other.
#define RC_STATE_RUNNING      0.0
#define RC_STATE_KILL_PENDING 1.0
#define RC_STATE_HALTED       2.0
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
      if(!DryRun) Persist_Set("acct_hwm", g_rc_acct_hwm);   // ORDER-132b (Codex R2): observation instances never write terminal GVs
   }
}

void RiskControl_AcctGateInit()
{
   g_rc_acct_trip = false;
   g_rc_acct_hwm  = 0.0;
   if(RC_AcctDDLimitPct <= 0.0) return;
   Persist_MigrateLegacy("acct_hwm");   // ORDER-132: magic-only -> scoped key (one-shot, no-op in tester)
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

// ORDER-138 #1 + 138b (Codex roadmap SEV-1 + audit F1): legacy pre-132 keys are
// magic-only - no server/login identity. Adopting ANY of them can act against
// the WRONG account: an active kill/halt executes an irreversible close-all,
// and a foreign higher-equity rc_peak_eq makes KillDD liquidate this account on
// the first tick. Every legacy key this init would read therefore needs
// explicit operator consent via the RC_AdoptLegacyHalt input. Returns false =
// caller must INIT_FAILED (nothing was migrated or deleted). Split into
// _Ex(flag) so PersistMigrate_Test can exercise BOTH consent paths in one
// tester pass; production callers use RiskControl_Init().
bool RiskControl_InitEx(const bool adoptLegacyHalt)
{
   g_rc_halted      = false;
   g_rc_peak_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_rc_max_dd_pct  = 0.0;
   g_rc_cap_blocks  = 0;
   // MERGE-05B: restore hard-kill state so restart/recompile cannot resurrect
   // a killed EA. Tester passes start with a clean GV sandbox -> no-op there.
   g_rc_kill_pending = false;
   // ORDER-138 #1 + 138b (Codex F1): fail-closed BEFORE any migration/cleanup
   // while any legacy key THIS init would read exists without consent. The gate
   // covers more than active kill/halt: a foreign (higher-equity) legacy
   // rc_peak_eq would migrate in, KillDD would measure DD from the wrong
   // account's peak and could liquidate THIS account on the first tick; a
   // foreign acct_hwm false-trips the entry gate the same way. Inactive 0.0
   // kill/halt leftovers are benign residue - normal cleanup below handles them.
   {
      bool legacyKill = RC_PersistHalt && (Persist_GetLegacy("rc_kill_pending", 0.0) > 0.5);
      bool legacyHalt = RC_PersistHalt && (Persist_GetLegacy("rc_halted", 0.0) > 0.5);
      bool legacyPeak = RC_PersistHalt && Persist_HasLegacy("rc_peak_eq");
      bool legacyHwm  = (RC_AcctDDLimitPct > 0.0) && Persist_HasLegacy("acct_hwm");
      if((legacyKill || legacyHalt || legacyPeak || legacyHwm) && !adoptLegacyHalt)
      {
         string which = "";
         if(legacyKill) which += Persist_LegacyKey("rc_kill_pending") + " ";
         if(legacyHalt) which += Persist_LegacyKey("rc_halted") + " ";
         if(legacyPeak) which += Persist_LegacyKey("rc_peak_eq") + " ";
         if(legacyHwm)  which += Persist_LegacyKey("acct_hwm");
         PrintFormat("[RISK] FATAL: legacy pre-132 state found (%s- magic-only keys, account identity unknown) and RC_AdoptLegacyHalt=false. "
                     "Upgrading THIS account's own pre-132 state: set RC_AdoptLegacyHalt=true for one attach, verify the migration journal lines, then set it back to false. "
                     "State imported from ANOTHER account (terminal switched login): delete the Boss_%I64d_* GlobalVariables via Tools->Global Variables (F3) instead. "
                     "Nothing was migrated or deleted.",
                     which, _0_Magic);
         return false;
      }
   }
   if(RC_PersistHalt)
   {
      // ORDER-132 (Codex F4): migrate pre-132 magic-only keys to the scoped
      // format ONCE (Persist_MigrateLegacy deletes the legacy key after a
      // confirmed copy; DryRun never writes). Must run BEFORE any scoped read.
      Persist_MigrateLegacy("rc_peak_eq");

      // ORDER-132 (Codex F6): single persisted state enum. Read scoped rc_state;
      // when absent, derive once from the legacy two-flag format and persist it.
      double st = RC_STATE_RUNNING;
      if(Persist_Has("rc_state"))
         st = Persist_Get("rc_state", RC_STATE_RUNNING);
      else
      {
         if(Persist_GetLegacy("rc_kill_pending", 0.0) > 0.5)   st = RC_STATE_KILL_PENDING;
         else if(Persist_GetLegacy("rc_halted", 0.0) > 0.5)    st = RC_STATE_HALTED;
         if(st != RC_STATE_RUNNING && !DryRun)
         {
            if(Persist_Set("rc_state", st))
               PrintFormat("[RISK] migrated legacy halt/kill flags -> %s=%.0f", Persist_Key("rc_state"), st);
         }
      }
      // consume legacy flags once superseded - stale leftovers must never be
      // re-imported by a later account switch (F4) or resurrect a manually
      // cleared halt. Never delete on a failed migration write or from DryRun.
      if(!DryRun && (Persist_Has("rc_state") || st == RC_STATE_RUNNING))
      {
         Persist_DelLegacy("rc_kill_pending");
         Persist_DelLegacy("rc_halted");
      }
      if(!DryRun) Persist_Flush();

      if(st == RC_STATE_KILL_PENDING)
      {
         // ORDER-129: a restart/crash in the middle of an unconfirmed kill must resume the
         // kill, even if equity has bounced back above the threshold by the time we return.
         g_rc_kill_pending = true;
         Print("[RISK] KILL-PENDING restored from persist - resuming close-all reconciliation");
      }
      else if(st == RC_STATE_HALTED)
      {
         g_rc_halted = true;
         double p = Persist_Get("rc_peak_eq", g_rc_peak_equity);
         if(p > g_rc_peak_equity) g_rc_peak_equity = p;
         PrintFormat("[RISK] HALT restored from persist (peak %.2f) - manual un-halt: delete GV %s or set RC_PersistHalt=false",
                     g_rc_peak_equity, Persist_Key("rc_state"));
      }
      if(!g_rc_halted && Persist_Has("rc_peak_eq"))
      {
         // not halted, but keep the pre-restart equity peak so KillDD keeps
         // measuring from the true high-water mark (anti slow-bleed reset)
         double p = Persist_Get("rc_peak_eq", 0.0);
         if(p > g_rc_peak_equity) g_rc_peak_equity = p;
      }
   }
   RiskControl_AcctGateInit();
   return true;
}

bool RiskControl_Init() { return RiskControl_InitEx(RC_AdoptLegacyHalt); }

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
      if(RC_PersistHalt && !DryRun) Persist_Set("rc_peak_eq", g_rc_peak_equity);   // ORDER-132b (Codex R2)
   }
   if(g_rc_peak_equity <= 0.0) return 0.0;
   double dd = 100.0 * (g_rc_peak_equity - eq) / g_rc_peak_equity;
   if(dd > g_rc_max_dd_pct) g_rc_max_dd_pct = dd;
   return dd;
}

// ORDER-129 kill reconciliation: KILL_PENDING -> (broker verified flat) -> HALTED.
// Exec_CloseAll() now returns proof-of-flat; HALT (and its persist) only latch on that
// proof. While pending, this retries EVERY tick regardless of current DD — previously a
// single failed close during a liquidity gap left residual exposure unmanaged forever
// once DD drifted back under the threshold (Codex system review SEV-1).
bool RiskControl_KillReconcile()
{
   if(Exec_CloseAll())
   {
      g_rc_kill_pending = false;
      g_rc_halted       = true;
      // ORDER-129b (Codex audit): DryRun performs no real closes, so its "flat" is
      // simulated - never let an observation instance persist HALT into the terminal
      // GVs that a later REAL attach on this magic would inherit.
      bool persisted = false;
      if(RC_PersistHalt && !DryRun)
      {
         // ORDER-132 (F6): checked writes + durable flush - a crash right after an
         // unflushed HALT write must not come back RUNNING with the kill forgotten.
         bool ok = Persist_Set("rc_state", RC_STATE_HALTED);
         ok = Persist_Set("rc_peak_eq", g_rc_peak_equity) && ok;
         Persist_Flush();
         if(!ok) Print("[RISK] ERROR: HALT persist incomplete - halt state may not survive a restart");
         persisted = ok;
      }
      // ORDER-132b (Codex R1): the log must state what actually happened - never
      // claim "(persisted)" off the config flag while the write failed.
      PrintFormat("[RISK] HARD KILL complete: broker flat verified -> halt%s",
                  (persisted ? " (persisted)" : ""));
      return true;
   }
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      Print("[RISK] kill reconciliation: residual position/pending remains - retrying close-all");
   }
   return false;
}

// ORDER-132b (Codex R3): MT5 deletes terminal GlobalVariables ~4 weeks after
// their last use. A HALTED EA returns every tick without touching rc_state, and
// a long-flat EA touches rc_peak_eq only on new highs - both could silently
// expire and resurrect a killed EA as RUNNING after a much-later restart.
// Re-touch every critical key daily. Live/demo only: the tester sandbox has no
// TTL and stays byte-identical without this churn.
void RiskControl_PersistRefresh()
{
   if(!RC_PersistHalt || DryRun) return;
   if(MQLInfoInteger(MQL_TESTER)) return;
   static datetime last = 0;
   datetime now = TimeCurrent();
   if(last != 0 && now - last < 86400) return;
   last = now;
   if(g_rc_halted)            Persist_Set("rc_state", RC_STATE_HALTED);
   else if(g_rc_kill_pending) Persist_Set("rc_state", RC_STATE_KILL_PENDING);
   if(g_rc_peak_equity > 0.0 && Persist_Has("rc_peak_eq")) Persist_Set("rc_peak_eq", g_rc_peak_equity);
   if(RC_AcctDDLimitPct > 0.0 && g_rc_acct_hwm > 0.0)      Persist_Set("acct_hwm", g_rc_acct_hwm);
}

// HARD KILL - returns true while the kill state owns this tick
bool RiskControl_CheckDD()
{
   RiskControl_PersistRefresh();  // TTL keep-alive (no-op in tester/DryRun/off)
   RiskControl_AcctHwmUpdate();   // no-op unless RC_AcctDDLimitPct > 0
   if(g_rc_kill_pending)          // reconcile first, independent of current DD
   {
      RiskControl_KillReconcile();
      return true;
   }
   // ORDER-194: HALTED is terminal - never re-evaluate DD from here. g_rc_peak_equity is
   // frozen at the pre-kill peak and equity is (by definition) below the kill line, so the
   // breach below stays permanently true: without this guard the whole kill path re-ran
   // EVERY TICK for the rest of the run. Measured 2026-07-24: 14.4M / 11.8M / 3.5M
   // "[RISK] HARD KILL" lines in single tester logs, one log file 777 MB. On live it also
   // meant a GlobalVariablesFlush() (disk write) per tick forever via KillReconcile's
   // persist block - a halted EA quietly hammering the terminal's gvariables.dat.
   // Still sweep anything that appears on this magic AFTER the halt (halted must stay
   // flat), but only when something actually exists - the idle path must cost nothing.
   if(g_rc_halted)
   {
      if(Exec_CountAll() > 0 || Exec_CountPending() > 0) RiskControl_KillReconcile();
      return true;
   }
   double kill = RC_KillDDPct();
   double dd   = RiskControl_CurrentDDPct();
   if(kill > 0.0 && dd >= kill)
   {
      PrintFormat("[RISK] HARD KILL: DD %.2f%% >= %.2f%% (profile %d) -> closing all",
                  dd, kill, ProtectLevel);
      g_rc_kill_pending = true;
      if(RC_PersistHalt && !DryRun)
      {
         // ORDER-132 (F6): persist KILL_PENDING checked + flushed BEFORE the first
         // close attempt - a crash mid-close must resume the kill on restart
         if(!Persist_Set("rc_state", RC_STATE_KILL_PENDING))
            Print("[RISK] ERROR: kill-pending persist failed - a restart mid-kill would forget the kill");
         Persist_Flush();
      }
      RiskControl_KillReconcile();
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
