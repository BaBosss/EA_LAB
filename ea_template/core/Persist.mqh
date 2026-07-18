//+------------------------------------------------------------------+
//| Persist.mqh (V2) - tiny GlobalVariables helper (MERGE-05B).      |
//| ORDER-132 (Codex F4): keys are scoped by SERVER+LOGIN+SYMBOL+    |
//| MAGIC - the old magic-only key let a terminal that switched      |
//| accounts (or one magic reused on two symbols) inherit another    |
//| instance's halt/kill state and reconcile it against the WRONG    |
//| account. Legacy "Boss_<magic>_<name>" keys are migrated once at  |
//| init (Persist_MigrateLegacy) then deleted, so a later login to a |
//| different account cannot re-import them.                         |
//| Live-terminal GVs survive restart/recompile (gvariables.dat);    |
//| tester GVs are sandboxed per pass, so persisted state can never  |
//| move backtest numbers. Persist ONLY state that cannot be rebuilt |
//| from open positions.                                             |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_PERSIST_MQH
#define BOSS_LAB_PERSIST_MQH
#include "Inputs.mqh"

// scope id: <srvhash4>_<login>_<symbol>_<magic>. The server folds in as a djb2
// checksum (4 hex chars) because full server names would blow the 63-char
// GlobalVariable name limit. NOT cached: an account switch reloads the EA
// WITHOUT resetting program globals, so a cached scope would silently keep the
// old account's identity - the exact bug class this scoping removes.
string Persist_ScopeId()
{
   string srv = AccountInfoString(ACCOUNT_SERVER);
   uint h = 5381;
   for(int i = 0; i < StringLen(srv); i++)
      h = ((h << 5) + h) + (uint)StringGetCharacter(srv, i);
   return StringFormat("%04x_%I64d_%s_%I64d",
                       (int)(h & 0xFFFF),
                       AccountInfoInteger(ACCOUNT_LOGIN),
                       _Symbol,
                       _0_Magic);
}

string Persist_Key(const string name) { return "Boss2_" + Persist_ScopeId() + "_" + name; }

// ORDER-132 (Codex F6): checked write - a silently failed GlobalVariableSet used
// to let critical kill/halt state evaporate across restarts. Callers on critical
// transitions must check this and Persist_Flush() afterwards.
bool Persist_Set(const string name, const double value)
{
   string key = Persist_Key(name);
   ResetLastError();
   if(GlobalVariableSet(key, value) == 0)
   {
      PrintFormat("[PERSIST] ERROR: GlobalVariableSet failed for %s (err %d)", key, GetLastError());
      return false;
   }
   return true;
}

// force gvariables.dat to disk - call after critical state transitions (F6:
// a crash right after an unflushed write could resurrect a killed EA as RUNNING)
void Persist_Flush() { GlobalVariablesFlush(); }

bool Persist_Has(const string name) { return GlobalVariableCheck(Persist_Key(name)); }

double Persist_Get(const string name, const double fallback)
{
   string key = Persist_Key(name);
   if(!GlobalVariableCheck(key)) return fallback;
   return GlobalVariableGet(key);
}

void Persist_Del(const string name)
{
   string key = Persist_Key(name);
   if(GlobalVariableCheck(key)) GlobalVariableDel(key);
}

// ---- legacy (pre-ORDER-132) magic-only keys ------------------------------
string Persist_LegacyKey(const string name) { return "Boss_" + IntegerToString(_0_Magic) + "_" + name; }

bool Persist_HasLegacy(const string name) { return GlobalVariableCheck(Persist_LegacyKey(name)); }

double Persist_GetLegacy(const string name, const double fallback)
{
   string key = Persist_LegacyKey(name);
   if(!GlobalVariableCheck(key)) return fallback;
   return GlobalVariableGet(key);
}

void Persist_DelLegacy(const string name)
{
   string key = Persist_LegacyKey(name);
   if(GlobalVariableCheck(key)) GlobalVariableDel(key);
}

// one-shot migration: copy legacy value to the scoped key ONLY when the scoped
// key does not exist yet, then DELETE the legacy key so a different account on
// this terminal can never re-import this instance's state (Codex F4 class).
// The legacy key survives a failed scoped write (nothing is lost). DryRun is an
// observation instance - it never writes or deletes terminal GVs (129b F5
// doctrine), so under DryRun this only logs what it WOULD do.
// Returns true when a migration write happened.
bool Persist_MigrateLegacy(const string name)
{
   if(Persist_Has(name)) return false;         // already scoped - scoped value wins
   if(!Persist_HasLegacy(name)) return false;  // nothing to migrate
   double v = Persist_GetLegacy(name, 0.0);
   if(DryRun)
   {
      PrintFormat("[PERSIST] DryRun: would migrate %s -> %s (%.2f) - skipped (no writes in DryRun)",
                  Persist_LegacyKey(name), Persist_Key(name), v);
      return false;
   }
   if(!Persist_Set(name, v)) return false;     // keep legacy on failed write
   Persist_DelLegacy(name);
   PrintFormat("[PERSIST] migrated legacy %s -> %s (%.2f)", Persist_LegacyKey(name), Persist_Key(name), v);
   return true;
}

#endif // BOSS_LAB_PERSIST_MQH
