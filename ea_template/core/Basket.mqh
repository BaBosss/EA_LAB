//+------------------------------------------------------------------+
//| Basket.mqh (V2) - AAM Module 1 (Global Event Bus) + Module 3      |
//| (Portfolio Heat Manager). Both are additive and OFF by default    |
//| (_HEAT_Enable=false; nothing calls the Event Bus yet) - existing  |
//| callers are byte-identical unless they opt in.                    |
//|                                                                    |
//| Fail-safe doctrine (same as MacroGate_Core.mqh): an unreadable or |
//| expired GlobalVariable is treated as "no claim" / "gate open",    |
//| never as a permanent block. A corrupt/missing state must widen    |
//| the gate, not narrow it.                                          |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_BASKET_MQH
#define BOSS_LAB_BASKET_MQH
#include "Inputs.mqh"

//==================== Module 1: Global Event Bus ====================
// GV prefix EVTBUS_ (parallels MACROGATE_ in MacroGate_Core.mqh). Per event_id,
// 4 GlobalVariables: EVTBUS_<id> (claim time), _S (claimer score), _O (owner
// strategy hash), _T (ttl_seconds used at claim time - needed so a LATER caller
// can tell whether a claim is still active without being re-told the TTL).
//
// Scope of this order: MakeEventID / TryClaimEvent / IsChildBlocked, matching
// the 3 primitives the build prompt asked for. Nothing in the chassis calls
// these yet (no entry currently tags structural levels) - they are additive
// infrastructure for a future order to wire in.
#define EVTBUS_PREFIX "EVTBUS_"

string Event_ClaimGV(const string eventId) { return EVTBUS_PREFIX + eventId; }
string Event_ScoreGV(const string eventId) { return EVTBUS_PREFIX + eventId + "_S"; }
string Event_OwnerGV(const string eventId) { return EVTBUS_PREFIX + eventId + "_O"; }
string Event_TtlGV(const string eventId)   { return EVTBUS_PREFIX + eventId + "_T"; }

// FNV-1a string hash, masked to 53 bits so it round-trips exactly through a
// GlobalVariable double (MT5 GVs are double-only - this is the same "encode the
// payload, not just a flag" idea MacroGate/AAM spec 0.x use for cross-EA state).
double Event_StrategyHash(const string s)
{
   ulong h = 1469598103934665603;
   int n = StringLen(s);
   for(int i = 0; i < n; i++)
   {
      h ^= (ulong)StringGetCharacter(s, i);
      h *= 1099511628211;
   }
   return (double)(h & 0x1FFFFFFFFFFFFF);
}

// AAM spec 1.3: quantize (symbol, level, direction, bar) into a stable event_id so
// signals from different strategies that describe the same structural level collide
// into one claim instead of each getting its own (which would make the whole bus a
// no-op). level is quantized by an ATR(M15,14) bucket; time is quantized to
// _EVT_BucketSeconds so signals a few minutes apart on the same structure still merge.
string Event_MakeID(const string sym, const double level, const int dir, const datetime barTime)
{
   int h = iATR(sym, PERIOD_M15, 14);
   double atr = 0.0;
   if(h != INVALID_HANDLE)
   {
      double buf[];
      if(CopyBuffer(h, 0, 0, 1, buf) >= 1) atr = buf[0];
      IndicatorRelease(h);
   }
   double bucket = atr * _EVT_BucketATRmult;
   if(bucket <= 0.0)
      bucket = SymbolInfoDouble(sym, SYMBOL_POINT) * 100.0;   // degenerate-ATR guard: never divide by 0/negative

   long qLevel = (long)MathRound(level / bucket);
   long qBucketSec = (long)MathMax(_EVT_BucketSeconds, 1);
   long qTime  = (barTime > 0 ? ((long)barTime / qBucketSec) * qBucketSec : 0);
   return StringFormat("%s_%d_%I64d_%I64d", sym, dir, qLevel, qTime);
}

// AAM spec 1.4 (atomic claim + preemption). Returns true = caller may act on this
// event; false = someone else already holds it and this caller's score did not
// clear _EVT_PreemptMargin. Never closes an incumbent's already-open position -
// winning a preemption only stops the NEXT claimant from also entering.
bool Event_TryClaim(const string eventId, const string strategy, const double score, const int ttlSeconds)
{
   if(StringLen(eventId) == 0 || ttlSeconds <= 0) return false;   // malformed call - refuse, do not guess

   string gv  = Event_ClaimGV(eventId);
   string sgv = Event_ScoreGV(eventId);
   string ogv = Event_OwnerGV(eventId);
   string tgv = Event_TtlGV(eventId);

   if(GlobalVariableCheck(gv))
   {
      datetime claimedAt = (datetime)GlobalVariableGet(gv);
      int ownerTtl = (GlobalVariableCheck(tgv) ? (int)GlobalVariableGet(tgv) : 0);
      // fail-safe: an unreadable claim timestamp or ttl reads as EXPIRED (open the
      // gate), never as a permanent block - same doctrine as MacroGate_Core.mqh.
      bool expired = (claimedAt <= 0) || (ownerTtl <= 0) || ((TimeCurrent() - claimedAt) > ownerTtl);
      if(!expired)
      {
         double ownerScore = (GlobalVariableCheck(sgv) ? GlobalVariableGet(sgv) : 0.0);
         if(score <= ownerScore * _EVT_PreemptMargin)
            return false;   // loses the claim fight
         // wins -> falls through and overwrites below
      }
   }

   GlobalVariableSet(gv,  (double)TimeCurrent());
   GlobalVariableSet(sgv, score);
   GlobalVariableSet(ogv, Event_StrategyHash(strategy));
   GlobalVariableSet(tgv, (double)ttlSeconds);
   return true;
}

bool Event_IsActive(const string eventId)
{
   string gv = Event_ClaimGV(eventId);
   if(!GlobalVariableCheck(gv)) return false;
   datetime claimedAt = (datetime)GlobalVariableGet(gv);
   if(claimedAt <= 0) return false;                                 // fail-safe: unreadable -> not active
   string tgv = Event_TtlGV(eventId);
   int ttl = (GlobalVariableCheck(tgv) ? (int)GlobalVariableGet(tgv) : 0);
   if(ttl <= 0) return false;                                       // fail-safe: unknown ttl -> cannot prove active
   return (TimeCurrent() - claimedAt) <= ttl;
}

// AAM spec 1.6 (parent-event revenge-entry block). SCOPED: only the "parent claim
// still active" half is implemented here. The spec's second condition -
// EventClosedLoss(parent_id) && BarsSinceEventClose(parent_id) < REVENGE_BLOCK_BARS
// - needs a trade-outcome ledger (win/loss + close bar, per event_id) that neither
// this chassis nor the AAM spec document itself defines (EventClosedLoss /
// BarsSinceEventClose are referenced in the spec but never implemented there
// either). Faking that half with an invented heuristic would be worse than not
// having it - it would look tested and not be. _EVT_RevengeBlockBars is wired as
// a real input now so a future order can add the outcome ledger without another
// input-surface change.
bool Event_IsChildBlocked(const string parentId)
{
   if(StringLen(parentId) == 0) return false;
   return Event_IsActive(parentId);
}

//==================== Module 3: Portfolio Heat Manager ==============
// Lot-notional, NOT R-multiple (2026-08-12 user decision, see AGENT session): this
// chassis has no R bookkeeping and several StackModes (e.g. 93 pyramid, basket-SL-
// only builds) carry no per-leg SL price at all, so "R" is not a coherent unit
// here. _HEAT_MaxClusterLots / _HEAT_MaxPortfolioLots are LOTS, correlation-
// weighted, across every open position on the ACCOUNT (not just this EA's own
// magic/symbol - that is the entire point of a portfolio-level cap).
string HEAT_CLUSTER_METALS[]   = {"XAUUSD", "XAGUSD", "XPTUSD"};
string HEAT_CLUSTER_USD_MAJ[]  = {"EURUSD", "GBPUSD", "AUDUSD", "NZDUSD"};
string HEAT_CLUSTER_USD_SAFE[] = {"USDJPY", "USDCHF", "USDCAD"};
string HEAT_CLUSTER_INDEX[]    = {"US30", "NAS100", "SPX500"};
string HEAT_CLUSTER_CRYPTO[]   = {"BTCUSD", "ETHUSD"};

bool Heat_InArray(const string sym, const string &arr[])
{
   for(int i = 0; i < ArraySize(arr); i++) if(arr[i] == sym) return true;
   return false;
}

bool Heat_SameCluster(const string s1, const string s2)
{
   if(s1 == s2) return true;
   if(Heat_InArray(s1, HEAT_CLUSTER_METALS)   && Heat_InArray(s2, HEAT_CLUSTER_METALS))   return true;
   if(Heat_InArray(s1, HEAT_CLUSTER_USD_MAJ)  && Heat_InArray(s2, HEAT_CLUSTER_USD_MAJ))  return true;
   if(Heat_InArray(s1, HEAT_CLUSTER_USD_SAFE) && Heat_InArray(s2, HEAT_CLUSTER_USD_SAFE)) return true;
   if(Heat_InArray(s1, HEAT_CLUSTER_INDEX)    && Heat_InArray(s2, HEAT_CLUSTER_INDEX))    return true;
   if(Heat_InArray(s1, HEAT_CLUSTER_CRYPTO)   && Heat_InArray(s2, HEAT_CLUSTER_CRYPTO))   return true;
   return false;
}

// Opt-in refinement (spec 3.3 frames dynamic corr as "more accurate, use when
// static isn't enough" - not the MVP). Paired by index over the same lookback
// window from "now" on both symbols (no cross-symbol time-join - matches the
// spec's own GetReturns()/PearsonCorr() sketch, which shows no join step either).
// Returns 0.0 (not an error signal, just "no dynamic signal") on any data gap;
// EffectiveCorr() below still falls back to the static floor either way.
double Heat_RollingCorr(const string s1, const string s2, const int windowBars)
{
   if(s1 == s2) return 1.0;
   if(windowBars <= 1) return 0.0;
   if(!SymbolSelect(s1, true) || !SymbolSelect(s2, true)) return 0.0;

   MqlRates r1[], r2[];
   int n1 = CopyRates(s1, PERIOD_M15, 1, windowBars + 1, r1);
   int n2 = CopyRates(s2, PERIOD_M15, 1, windowBars + 1, r2);
   if(n1 < windowBars + 1 || n2 < windowBars + 1) return 0.0;

   double ret1[], ret2[];
   ArrayResize(ret1, windowBars);
   ArrayResize(ret2, windowBars);
   for(int i = 0; i < windowBars; i++)
   {
      ret1[i] = (r1[i].close > 0.0 ? MathLog(r1[i + 1].close / r1[i].close) : 0.0);
      ret2[i] = (r2[i].close > 0.0 ? MathLog(r2[i + 1].close / r2[i].close) : 0.0);
   }

   double mean1 = 0.0, mean2 = 0.0;
   for(int i = 0; i < windowBars; i++) { mean1 += ret1[i]; mean2 += ret2[i]; }
   mean1 /= windowBars; mean2 /= windowBars;

   double cov = 0.0, var1 = 0.0, var2 = 0.0;
   for(int i = 0; i < windowBars; i++)
   {
      double d1 = ret1[i] - mean1, d2 = ret2[i] - mean2;
      cov  += d1 * d2;
      var1 += d1 * d1;
      var2 += d2 * d2;
   }
   if(var1 <= 0.0 || var2 <= 0.0) return 0.0;
   return cov / MathSqrt(var1 * var2);
}

// AAM spec 3.3: always the conservative max(dynamic, static) - never trust rolling
// correlation alone (it under-reads risk-off correlation spikes right when it
// matters most).
double Heat_EffectiveCorr(const string s1, const string s2)
{
   double sta = (Heat_SameCluster(s1, s2) ? _HEAT_ClusterCorr : _HEAT_DefaultCorr);
   if(!_HEAT_UseDynamicCorr) return sta;
   double dyn = MathAbs(Heat_RollingCorr(s1, s2, _HEAT_CorrWindowBars));
   return MathMax(dyn, sta);
}

// AAM spec 3.4, lot-notional. Loops every open position on the ACCOUNT (cross-
// magic, cross-symbol - PositionGetTicket()/PositionGetString() see every EA's
// positions, not just this one's), same iteration idiom as Execution.mqh.
// _HEAT_Enable=false (default) -> always true (fail-open, matches every other
// opt-in gate's inert default in this chassis).
bool Basket_HeatCheckPass(const string newSym, const double newRiskLots)
{
   if(!_HEAT_Enable) return true;
   if(newRiskLots <= 0.0) return true;

   double portfolioHeat = 0.0;
   double clusterHeat   = 0.0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      string sym  = PositionGetString(POSITION_SYMBOL);
      double lots = PositionGetDouble(POSITION_VOLUME);
      double corr = Heat_EffectiveCorr(newSym, sym);
      portfolioHeat += lots * corr;
      if(Heat_SameCluster(newSym, sym)) clusterHeat += lots;
   }

   if(clusterHeat + newRiskLots > _HEAT_MaxClusterLots)
   {
      PrintFormat("[HEAT] veto CLUSTER_HEAT sym=%s cluster=%.2f new=%.2f cap=%.2f",
                  newSym, clusterHeat, newRiskLots, _HEAT_MaxClusterLots);
      return false;
   }
   if(portfolioHeat + newRiskLots > _HEAT_MaxPortfolioLots)
   {
      PrintFormat("[HEAT] veto PORTFOLIO_HEAT sym=%s heat=%.2f new=%.2f cap=%.2f",
                  newSym, portfolioHeat, newRiskLots, _HEAT_MaxPortfolioLots);
      return false;
   }
   return true;
}

void Basket_OnTick()
{
   // future: multi-symbol basket coordination (Event Bus consumers, heat telemetry)
}

#endif // BOSS_LAB_BASKET_MQH
