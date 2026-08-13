//+------------------------------------------------------------------+
//| EventBusHeat_Test.mq5 - asserts for core\Basket.mqh AAM Module 1  |
//| (Global Event Bus) + Module 3 (Portfolio Heat, lot-notional).     |
//| No .set needed - runs on compiled defaults (_HEAT_Enable=false).  |
//| Claim/preempt/expiry asserts run in OnInit (TimeCurrent() is      |
//| valid there, same as AcctGate_Test); Event_MakeID's ATR-bucket    |
//| asserts run on the first tick (ATR needs bars - same reason       |
//| StackStep_Test defers to OnTick, not OnInit). GVs this test        |
//| touches are deleted before AND after, so a crashed prior run never|
//| poisons a later one (same discipline AcctGate_Test uses).         |
//+------------------------------------------------------------------+
#include "../core/Basket.mqh"

string g_evt  = "UNITTEST_EVTBUS_PROBE";
bool   g_done = false;
int    g_fail = 0;

void CleanupEventGVs(const string eventId)
{
   string names[4];
   names[0] = Event_ClaimGV(eventId);
   names[1] = Event_ScoreGV(eventId);
   names[2] = Event_OwnerGV(eventId);
   names[3] = Event_TtlGV(eventId);
   for(int i = 0; i < 4; i++)
      if(GlobalVariableCheck(names[i])) GlobalVariableDel(names[i]);
}

int OnInit()
{
   CleanupEventGVs(g_evt);   // defensive: a crashed prior run could have left state behind

   // --- Module 3: default-disabled heat gate must always fail-open ---
   if(_HEAT_Enable != false)
   { Print("[FAIL] EventBusHeat_Test: must run with compiled defaults (_HEAT_Enable=false)"); g_fail++; }
   if(!Basket_HeatCheckPass(_Symbol, 1000.0))   // absurd lot size - disabled gate must not care
   { Print("[FAIL] Basket_HeatCheckPass() must be fail-open (true) when _HEAT_Enable=false"); g_fail++; }

   // --- Module 3: pure cluster membership (no live/position data needed) ---
   if(!Heat_SameCluster("XAUUSD", "XAGUSD"))
   { Print("[FAIL] Heat_SameCluster(XAUUSD,XAGUSD) must be true (metals cluster)"); g_fail++; }
   if(Heat_SameCluster("XAUUSD", "EURUSD"))
   { Print("[FAIL] Heat_SameCluster(XAUUSD,EURUSD) must be false (different clusters)"); g_fail++; }
   if(!Heat_SameCluster("EURUSD", "EURUSD"))
   { Print("[FAIL] Heat_SameCluster(sym,sym) must always be true"); g_fail++; }

   // --- Module 1: first claim on a fresh event_id must succeed ---
   if(!Event_TryClaim(g_evt, "StrategyA", 1.0, 60))
   { Print("[FAIL] Event_TryClaim() first claim on a fresh id must succeed"); g_fail++; }
   if(!Event_IsActive(g_evt))
   { Print("[FAIL] Event_IsActive() must be true right after a successful claim"); g_fail++; }

   // --- an equal or under-margin score must NOT preempt the incumbent ---
   if(Event_TryClaim(g_evt, "StrategyB", 1.0, 60))
   { Print("[FAIL] Event_TryClaim() equal score must NOT preempt the incumbent"); g_fail++; }
   double justUnder = _EVT_PreemptMargin - 0.0001;
   if(Event_TryClaim(g_evt, "StrategyC", justUnder, 60))
   { Print("[FAIL] Event_TryClaim() score just under PreemptMargin must NOT preempt"); g_fail++; }

   // --- a score clearing PreemptMargin DOES preempt ---
   double clears = _EVT_PreemptMargin + 0.5;
   if(!Event_TryClaim(g_evt, "StrategyD", clears, 60))
   { Print("[FAIL] Event_TryClaim() score clearing PreemptMargin must preempt"); g_fail++; }

   // --- parent-block: an active claim must block a child; empty parent never blocks ---
   if(!Event_IsChildBlocked(g_evt))
   { Print("[FAIL] Event_IsChildBlocked() must be true while the parent claim is active"); g_fail++; }
   if(Event_IsChildBlocked(""))
   { Print("[FAIL] Event_IsChildBlocked(\"\") must be false (no parent = nothing to block on)"); g_fail++; }

   // --- expiry: force a claim into the past, must read back inactive and be re-claimable ---
   string evtExpired = g_evt + "_EXPIRE";
   CleanupEventGVs(evtExpired);
   if(!Event_TryClaim(evtExpired, "StrategyE", 1.0, 1))
   { Print("[FAIL] Event_TryClaim() with ttl=1 must still succeed as a claim"); g_fail++; }
   GlobalVariableSet(Event_ClaimGV(evtExpired), (double)(TimeCurrent() - 100));   // no need to sleep in a test
   if(Event_IsActive(evtExpired))
   { Print("[FAIL] Event_IsActive() must be false once now - claimTime exceeds ttl"); g_fail++; }
   if(!Event_TryClaim(evtExpired, "StrategyF", 0.01, 60))   // even a tiny score must win once expired
   { Print("[FAIL] Event_TryClaim() must succeed against an EXPIRED incumbent regardless of score"); g_fail++; }
   CleanupEventGVs(evtExpired);

   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(g_done) return;
   g_done = true;

   // --- Module 1: Event_MakeID quantization (needs ATR -> bars -> first tick) ---
   datetime bar = iTime(_Symbol, PERIOD_M15, 0);
   double   px  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(px <= 0.0)
   { Print("[FAIL] EventBusHeat_Test: no bid price on first tick"); g_fail++; }
   else
   {
      string id1 = Event_MakeID(_Symbol, px, 1, bar);
      string id2 = Event_MakeID(_Symbol, px, 1, bar);
      if(id1 != id2 || StringLen(id1) == 0)
      { Print("[FAIL] Event_MakeID() must be deterministic for identical inputs"); g_fail++; }

      string idOtherDir = Event_MakeID(_Symbol, px, 2, bar);
      if(idOtherDir == id1)
      { Print("[FAIL] Event_MakeID() must differ when direction differs"); g_fail++; }
   }

   CleanupEventGVs(g_evt);

   if(g_fail == 0) Print("[PASS] EventBusHeat_Test: all 17 asserts OK");
   else             PrintFormat("[FAIL] EventBusHeat_Test: %d assert(s) failed", g_fail);
}
