//+------------------------------------------------------------------+
//| Persist.mqh (V2) - tiny GlobalVariables helper (MERGE-05B).      |
//| Key pattern: Boss_<magic>_<name>. Live-terminal GVs survive      |
//| restart/recompile (gvariables.dat); tester GVs are sandboxed per |
//| pass, so persisted state can never move backtest numbers.        |
//| Port of the StatePersistence_v1 PATTERN only - no CORE deps.     |
//| Persist ONLY state that cannot be rebuilt from open positions.   |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_PERSIST_MQH
#define BOSS_LAB_PERSIST_MQH
#include "Inputs.mqh"

string Persist_Key(const string name) { return "Boss_" + IntegerToString(_0_Magic) + "_" + name; }

void Persist_Set(const string name, const double value) { GlobalVariableSet(Persist_Key(name), value); }

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

#endif // BOSS_LAB_PERSIST_MQH
