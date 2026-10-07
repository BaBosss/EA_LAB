//+------------------------------------------------------------------+
//| Entry_Wave5.mqh (ORDER-082, LAB_ENTRY_17) - Elliott wave-4 retrace|
//| arm to catch wave-5. Labels wave1(impulse)/wave2(retrace)/wave3   |
//| (confirmed break + min-run), arms a ZONE on the wave-4 retrace    |
//| between _17_EntryFib% and the structural invalidation (wave-1     |
//| top/bottom). Both directions. Once-per-structure latch keyed on   |
//| the wave-3 peak datetime (ST03 pattern, Entry_ST03.mqh:27,41).    |
//| Publishes structural SL/TP anchors into the Inputs.mqh globals    |
//| (guard G1) for ExitManager's #ifdef LAB_ENTRY_17 overrides.       |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_WAVE5_MQH
#define BOSS_LAB_ENTRY_WAVE5_MQH
#ifdef LAB_ENTRY_17
#include "IEntry.mqh"
#include "../Indicators.mqh"
#include "Wave5Swings.mqh"

datetime g_wave5_last_bar     = 0;   // once-per-bar gate (recompile-safe: reset in Init)
datetime g_wave5_latched_peak = 0;   // wave-3-peak datetime already signalled (ever, incl. after close)

// ORDER-432 finding 6 (Codex blind audit 2026-07-27). Until now every rejection here
// returned Entry_MakeNone with a reason string that LabCore then discarded without
// logging (LabCore.mqh:459/469 -- `reason` is written by every entry seam in this repo
// and read by none). The consequence is the one the VERDICT GATE names explicitly:
// "no eligible signal", "the guard rejected everything" and "the guard never executed"
// all produce zero trades and are indistinguishable in a report, so a guard could never
// be written up as passed on the evidence available.
//
// These counters are the minimum that makes any Wave5 guard testable at all. They are
// diagnostic only -- nothing branches on them, so they cannot change a decision.
int g_w5_n_eval        = 0;   // bars evaluated (the denominator for everything below)
int g_w5_n_no_swings   = 0;
int g_w5_n_bad_pattern = 0;
int g_w5_n_no_tick     = 0;   // SymbolInfoTick failed (symbol not synced - a real path)
int g_w5_n_not_in_zone = 0;   // retrace has not reached the fib zone YET (still valid)
int g_w5_n_struct_inv  = 0;   // wave4 overlapped wave1 - structure BROKEN (a different thing)
int g_w5_n_latched     = 0;
int g_w5_n_no_atr      = 0;   // ORDER-432 finding 2: Risk-ATR unreadable -> entry refused
int g_w5_n_sl_invalid  = 0;   // guard G4: structural SL failed the broker stops-level check
int g_w5_n_signalled   = 0;

//==================== B17 Stage-0 per-structure ladder ====================
// The legacy Entry_Evaluate seam remains below for accepted callers/tests.
// LabCore routes the B17 wrapper through B17_OnTick, which owns independent
// structures and never uses shared Stack/Recovery/Hedge basket semantics.
enum B17_LevelState
{
   B17_LEVEL_UNOPENED=0,
   B17_LEVEL_OPENED=1,
   B17_LEVEL_CLOSED=2,
   B17_LEVEL_EXPIRED_SKIPPED=3,
   B17_LEVEL_EXPIRED_BLOCKED=4,
   B17_LEVEL_PARTIAL_FILLED_CONSUMED=5
};

enum B17_Lifecycle
{
   B17_LIFECYCLE_ACTIVE=0,
   B17_LIFECYCLE_CLOSE_INTENT=1,
   B17_LIFECYCLE_CLOSED=2
};

enum B17_BAR_DECISION
{
   B17_BAR_NONE=0,
   B17_BAR_ENTER_LEVEL=1,
   B17_BAR_INVALIDATE=2
};

enum B17_OPEN_OUTCOME
{
   B17_OPEN_BLOCKED=0,
   B17_OPEN_FULL=1,
   B17_OPEN_PARTIAL=2,
   B17_OPEN_AMBIGUOUS=3
};

enum B17_LevelReason
{
   B17_REASON_NONE=0,
   B17_REASON_DEEPEST_SKIP=1,
   B17_REASON_RAW_WAVE1_INVALIDATION=2,
   B17_REASON_RISKCONTROL_BLOCK=3,
   B17_REASON_BROKER_BLOCK=4,
   B17_REASON_PARTIAL_FILL=5,
   B17_REASON_FULL_FILL=6,
   B17_REASON_AMBIGUOUS_NO_RETRY=7,
   B17_REASON_SUBMITTING_NO_RETRY=8,
   B17_REASON_ATR_MISSING=9,
   B17_REASON_TARGET_ATTACH_FAILED=10,
   B17_REASON_CLOSED=11
};

#define B17_LEVEL_CAP 4
#define B17_ATR_PERIOD 14

struct B17_Level
{
   double fib_pct;
   double price;
   B17_LevelState state;
   B17_LevelReason reason;
   double allocated_risk_money;
   double raw_lot;
   double normalized_lot;
   double filled_lot;
   double actual_price_risk;
   double actual_risk_money;
   double discarded_quota_money;
   double target_price;
   bool quota_accounted;
};

struct B17_Structure
{
   string structure_id;
   uint structure_hash;
   long magic;
   int direction;
   datetime wave1_origin_time;
   datetime wave1_end_time;
   datetime wave2_end_time;
   datetime wave3_time;
   datetime activation_time;
   double wave1_origin_price;
   double wave1_end_price;
   double wave2_end_price;
   double wave3_peak_price;
   double wave1_length;
   double raw_wave1_invalidation;
   B17_Lifecycle lifecycle;
   bool close_intent;
   int close_reason;
   datetime last_action_bar;
   bool ever_filled;
   datetime first_fill_time;
   double first_fill_price;
   double initial_balance_snapshot;
   double total_setup_risk_pct;
   double total_setup_risk_money;
   double discarded_quota_money;
   double balance_base_snapshot;
   double equity_base_snapshot;
   double basket_atr_snapshot;
   datetime basket_atr_time;
   double risk_atr_value;
   datetime risk_atr_time;
   ENUM_TIMEFRAMES risk_atr_tf;
   ENUM_TIMEFRAMES basket_atr_tf;
   double shared_structure_target;
   int level_count;
   B17_Level levels[B17_LEVEL_CAP];
   bool duplicate_retry_forbidden;
   bool restored;
   bool orphaned;
   bool collision;
};

B17_Structure g_b17_structures[];
datetime g_b17_last_closed_bar=0;
int g_b17_risk_atr_handle=INVALID_HANDLE;
int g_b17_basket_atr_handle=INVALID_HANDLE;

void B17_ResetLevel(B17_Level &level)
{
   level.fib_pct=0.0; level.price=0.0;
   level.state=B17_LEVEL_UNOPENED; level.reason=B17_REASON_NONE;
   level.allocated_risk_money=0.0; level.raw_lot=0.0;
   level.normalized_lot=0.0; level.filled_lot=0.0;
   level.actual_price_risk=0.0; level.actual_risk_money=0.0;
   level.discarded_quota_money=0.0; level.target_price=0.0;
   level.quota_accounted=false;
}

void B17_ResetStructure(B17_Structure &state)
{
   state.structure_id=""; state.structure_hash=0; state.magic=0;
   state.direction=0; state.wave1_origin_time=0; state.wave1_end_time=0;
   state.wave2_end_time=0; state.wave3_time=0; state.activation_time=0;
   state.wave1_origin_price=0.0; state.wave1_end_price=0.0;
   state.wave2_end_price=0.0; state.wave3_peak_price=0.0;
   state.wave1_length=0.0; state.raw_wave1_invalidation=0.0;
   state.lifecycle=B17_LIFECYCLE_ACTIVE; state.close_intent=false;
   state.close_reason=0; state.last_action_bar=0; state.ever_filled=false;
   state.first_fill_time=0; state.first_fill_price=0.0;
   state.initial_balance_snapshot=0.0; state.total_setup_risk_pct=0.0;
   state.total_setup_risk_money=0.0; state.discarded_quota_money=0.0;
   state.balance_base_snapshot=0.0; state.equity_base_snapshot=0.0;
   state.basket_atr_snapshot=0.0; state.basket_atr_time=0;
   state.risk_atr_value=0.0; state.risk_atr_time=0;
   state.risk_atr_tf=PERIOD_CURRENT; state.basket_atr_tf=PERIOD_CURRENT;
   state.shared_structure_target=0.0; state.level_count=0;
   state.duplicate_retry_forbidden=false; state.restored=false;
   state.orphaned=false; state.collision=false;
   for(int i=0;i<B17_LEVEL_CAP;i++) B17_ResetLevel(state.levels[i]);
}

bool B17_InitStructureState(B17_Structure &state,const string structure_id,
                            const long magic,const int direction,
                            const datetime wave3_time,const datetime activation_time,
                            const double raw_invalidation,const double wave1_length,
                            const double wave3_origin,const double wave3_peak,
                            const double balance,const double total_risk_pct,
                            const double &fibs[],const int level_count,
                            const ENUM_B17_RISK_ALLOCATION allocation)
{
   B17_ResetStructure(state);
   if(StringLen(structure_id)==0 || magic<=0 ||
      (direction!=1 && direction!=2) || wave3_time<=0 || activation_time<=0 ||
      !MathIsValidNumber(raw_invalidation) || raw_invalidation<=0.0 ||
      !MathIsValidNumber(wave1_length) || wave1_length<=0.0 ||
      !MathIsValidNumber(wave3_origin) || !MathIsValidNumber(wave3_peak) ||
      MathAbs(wave3_peak-wave3_origin)<=0.0 ||
      !MathIsValidNumber(balance) || balance<=0.0 ||
      !MathIsValidNumber(total_risk_pct) || total_risk_pct<=0.0 ||
      level_count<=0 || level_count>B17_LEVEL_CAP || ArraySize(fibs)<level_count)
      return false;
   double previous=0.0;
   for(int i=0;i<level_count;i++)
      if(!MathIsValidNumber(fibs[i]) || fibs[i]<=previous || fibs[i]>=100.0)
         return false;
      else previous=fibs[i];

   state.structure_id=structure_id;
   state.structure_hash=Persist_StructHash(structure_id);
   state.magic=magic; state.direction=direction;
   state.wave3_time=wave3_time; state.activation_time=activation_time;
   state.raw_wave1_invalidation=raw_invalidation;
   state.wave1_length=wave1_length;
   state.wave2_end_price=wave3_origin;
   state.wave3_peak_price=wave3_peak;
   state.initial_balance_snapshot=balance;
   state.total_setup_risk_pct=total_risk_pct;
   state.total_setup_risk_money=balance*total_risk_pct/100.0;
   state.level_count=level_count;
   double denominator=(allocation==B17_RISK_LINEAR_DEPTH_WEIGHTED ?
                       (double)(level_count*(level_count+1))/2.0 :
                       (double)level_count);
   double wave3_length=MathAbs(wave3_peak-wave3_origin);
   for(int i=0;i<level_count;i++)
   {
      B17_ResetLevel(state.levels[i]);
      state.levels[i].fib_pct=fibs[i];
      double distance=(fibs[i]/100.0)*wave3_length;
      state.levels[i].price=(direction==1 ? wave3_peak-distance : wave3_peak+distance);
      double numerator=(allocation==B17_RISK_LINEAR_DEPTH_WEIGHTED ? (double)(i+1) : 1.0);
      state.levels[i].allocated_risk_money=state.total_setup_risk_money*numerator/denominator;
   }
   return true;
}

bool B17_LevelCanSubmit(const B17_Structure &state,const int level)
{
   return (state.lifecycle==B17_LIFECYCLE_ACTIVE &&
           level>=0 && level<state.level_count &&
           state.levels[level].state==B17_LEVEL_UNOPENED);
}

void B17_AccountDiscard(B17_Structure &state,const int level,const double used_risk)
{
   if(level<0 || level>=state.level_count || state.levels[level].quota_accounted) return;
   double used=MathMax(0.0,MathMin(used_risk,state.levels[level].allocated_risk_money));
   double discarded=state.levels[level].allocated_risk_money-used;
   state.levels[level].discarded_quota_money=discarded;
   state.discarded_quota_money+=discarded;
   state.levels[level].quota_accounted=true;
}

B17_BAR_DECISION B17_ApplyClosedBar(B17_Structure &state,
                                     const double closed_price,
                                     const datetime closed_bar,
                                     int &level)
{
   level=-1;
   if(state.lifecycle!=B17_LIFECYCLE_ACTIVE || closed_bar<=0 ||
      state.last_action_bar==closed_bar || !MathIsValidNumber(closed_price))
      return B17_BAR_NONE;
   bool invalidated=(state.direction==1 ?
                     closed_price<=state.raw_wave1_invalidation :
                     closed_price>=state.raw_wave1_invalidation);
   if(invalidated)
   {
      state.last_action_bar=closed_bar;
      state.lifecycle=B17_LIFECYCLE_CLOSE_INTENT;
      state.close_intent=true;
      state.close_reason=B17_REASON_RAW_WAVE1_INVALIDATION;
      for(int i=0;i<state.level_count;i++)
      {
         if(state.levels[i].state!=B17_LEVEL_UNOPENED) continue;
         state.levels[i].state=B17_LEVEL_EXPIRED_SKIPPED;
         state.levels[i].reason=B17_REASON_RAW_WAVE1_INVALIDATION;
         B17_AccountDiscard(state,i,0.0);
      }
      return B17_BAR_INVALIDATE;
   }
   int deepest=-1;
   for(int i=0;i<state.level_count;i++)
   {
      if(state.levels[i].state!=B17_LEVEL_UNOPENED) continue;
      bool reached=(state.direction==1 ? closed_price<=state.levels[i].price :
                                        closed_price>=state.levels[i].price);
      if(reached) deepest=i;
   }
   if(deepest<0) return B17_BAR_NONE;
   state.last_action_bar=closed_bar;
   for(int i=0;i<deepest;i++)
   {
      if(state.levels[i].state!=B17_LEVEL_UNOPENED) continue;
      state.levels[i].state=B17_LEVEL_EXPIRED_SKIPPED;
      state.levels[i].reason=B17_REASON_DEEPEST_SKIP;
      B17_AccountDiscard(state,i,0.0);
   }
   level=deepest;
   return B17_BAR_ENTER_LEVEL;
}

bool B17_ArmSubmission(B17_Structure &state,const int level)
{
   if(!B17_LevelCanSubmit(state,level)) return false;
   state.levels[level].state=B17_LEVEL_EXPIRED_BLOCKED;
   state.levels[level].reason=B17_REASON_SUBMITTING_NO_RETRY;
   return true;
}

void B17_ConsumeLevelOutcome(B17_Structure &state,const int level,
                             const B17_OPEN_OUTCOME outcome,
                             const double requested_lot,
                             const double filled_lot,
                             const double actual_risk_money,
                             const string reason)
{
   if(level<0 || level>=state.level_count) return;
   bool submitting=(state.levels[level].state==B17_LEVEL_EXPIRED_BLOCKED &&
                    state.levels[level].reason==B17_REASON_SUBMITTING_NO_RETRY);
   if(state.levels[level].state!=B17_LEVEL_UNOPENED && !submitting) return;
   state.levels[level].normalized_lot=MathMax(0.0,requested_lot);
   state.levels[level].filled_lot=MathMax(0.0,filled_lot);
   state.levels[level].actual_risk_money=MathMax(0.0,actual_risk_money);
   if(outcome==B17_OPEN_FULL)
   {
      state.levels[level].state=B17_LEVEL_OPENED;
      state.levels[level].reason=B17_REASON_FULL_FILL;
      state.ever_filled=true;
      B17_AccountDiscard(state,level,state.levels[level].actual_risk_money);
   }
   else if(outcome==B17_OPEN_PARTIAL)
   {
      state.levels[level].state=B17_LEVEL_PARTIAL_FILLED_CONSUMED;
      state.levels[level].reason=B17_REASON_PARTIAL_FILL;
      state.ever_filled=true;
      B17_AccountDiscard(state,level,state.levels[level].actual_risk_money);
   }
   else
   {
      state.levels[level].state=B17_LEVEL_EXPIRED_BLOCKED;
      state.levels[level].reason=(outcome==B17_OPEN_AMBIGUOUS ?
                                  B17_REASON_AMBIGUOUS_NO_RETRY :
                                  B17_REASON_BROKER_BLOCK);
      if(outcome==B17_OPEN_AMBIGUOUS)
         state.duplicate_retry_forbidden=true;
      B17_AccountDiscard(state,level,0.0);
   }
   // Preserve a searchable literal in source/evidence for the frozen rule.
   if(outcome==B17_OPEN_AMBIGUOUS && reason=="AMBIGUOUS_NO_DUPLICATE_RETRY")
      state.duplicate_retry_forbidden=true;
}

bool B17_FreezeFirstFill(B17_Structure &state,const double fill_price,
                         const datetime fill_time,const double balance,
                         const double equity,const double basket_atr,
                         const datetime basket_atr_time)
{
   if(state.first_fill_time>0) return false;
   if(fill_price<=0.0 || fill_time<=0 || balance<=0.0 || equity<=0.0) return false;
   state.first_fill_price=fill_price; state.first_fill_time=fill_time;
   state.balance_base_snapshot=balance; state.equity_base_snapshot=equity;
   state.basket_atr_snapshot=basket_atr; state.basket_atr_time=basket_atr_time;
   state.shared_structure_target=(state.direction==1 ?
                                  fill_price+state.wave1_length :
                                  fill_price-state.wave1_length);
   return true;
}

double B17_TargetForFill(const B17_Structure &state,const double fill_price,
                         const double risk_atr)
{
   if(_17_PerLegTargetMode==B17_ATR_TARGET)
      return (state.direction==1 ? fill_price+_22_TP_ATRmult*risk_atr :
                                   fill_price-_22_TP_ATRmult*risk_atr);
   if(_17_StructTargetMode==B17_SHARED_STRUCTURE_TARGET)
      return state.shared_structure_target;
   return (state.direction==1 ? fill_price+state.wave1_length :
                                fill_price-state.wave1_length);
}

bool B17_ApplyCloseReconcile(B17_Structure &state,const bool flat)
{
   if(!flat)
   {
      state.lifecycle=B17_LIFECYCLE_CLOSE_INTENT;
      state.close_intent=true;
      return false;
   }
   state.lifecycle=B17_LIFECYCLE_CLOSED;
   state.close_intent=false;
   for(int i=0;i<state.level_count;i++)
      if(state.levels[i].state==B17_LEVEL_OPENED ||
         state.levels[i].state==B17_LEVEL_PARTIAL_FILLED_CONSUMED)
      {
         state.levels[i].state=B17_LEVEL_CLOSED;
         state.levels[i].reason=B17_REASON_CLOSED;
      }
   return true;
}

bool B17_CanRevive(const B17_Structure &state)
{
   return state.lifecycle!=B17_LIFECYCLE_CLOSED;
}

void B17_CopyPersistedState(const B17_Structure &source,B17_Structure &target)
{
   target=source;
   target.restored=true;
}

bool B17_PersistedStateEqual(const B17_Structure &left,const B17_Structure &right)
{
   if(left.structure_id!=right.structure_id || left.magic!=right.magic ||
      left.direction!=right.direction || left.lifecycle!=right.lifecycle ||
      left.close_intent!=right.close_intent ||
      left.first_fill_time!=right.first_fill_time ||
      left.initial_balance_snapshot!=right.initial_balance_snapshot ||
      left.total_setup_risk_money!=right.total_setup_risk_money ||
      left.balance_base_snapshot!=right.balance_base_snapshot ||
      left.equity_base_snapshot!=right.equity_base_snapshot ||
      left.basket_atr_snapshot!=right.basket_atr_snapshot ||
      left.basket_atr_time!=right.basket_atr_time ||
      left.shared_structure_target!=right.shared_structure_target ||
      left.level_count!=right.level_count) return false;
   for(int i=0;i<left.level_count;i++)
      if(left.levels[i].state!=right.levels[i].state ||
         left.levels[i].reason!=right.levels[i].reason ||
         left.levels[i].allocated_risk_money!=right.levels[i].allocated_risk_money ||
         left.levels[i].discarded_quota_money!=right.levels[i].discarded_quota_money)
         return false;
   return true;
}

double B17_AggregateActiveRisk(const B17_Structure &structures[])
{
   double total=0.0;
   for(int i=0;i<ArraySize(structures);i++)
      if(structures[i].lifecycle!=B17_LIFECYCLE_CLOSED)
         total+=structures[i].total_setup_risk_money;
   return total;
}

bool B17_MagicCollides(const B17_Structure &structures[],const long magic,
                       const string structure_id)
{
   for(int i=0;i<ArraySize(structures);i++)
      if(structures[i].magic==magic && structures[i].structure_id!=structure_id &&
         structures[i].lifecycle!=B17_LIFECYCLE_CLOSED)
         return true;
   return false;
}

bool B17_MagicOwns(const long owner_magic,const long observed_magic)
{
   return (owner_magic>0 && owner_magic==observed_magic);
}

bool B17_RiskInputsValid(const double risk_atr,const double tick_value,
                         const double tick_size)
{
   return (MathIsValidNumber(risk_atr) && risk_atr>0.0 &&
           MathIsValidNumber(tick_value) && tick_value>0.0 &&
           MathIsValidNumber(tick_size) && tick_size>0.0);
}

bool B17_BasketAtrInputsValid(const ENUM_B17_BASKET_TARGET_MODE mode,
                              const double basket_atr,
                              const datetime source_time)
{
   if(mode!=B17_BASKET_ATR_TARGET) return true;
   return (MathIsValidNumber(basket_atr) && basket_atr>0.0 && source_time>0);
}

void Entry_Wave5_Init()
{
   g_wave5_last_bar     = 0;
   g_wave5_latched_peak = 0;
   g_wave5_sl_price      = 0.0;
   g_wave5_tp_price      = 0.0;
   g_wave5_entry_ref     = 0.0;
   g_w5_n_eval = 0; g_w5_n_no_swings = 0; g_w5_n_bad_pattern = 0;
   g_w5_n_no_tick = 0; g_w5_n_not_in_zone = 0; g_w5_n_struct_inv = 0;
   g_w5_n_latched = 0; g_w5_n_no_atr = 0;
   g_w5_n_sl_invalid = 0; g_w5_n_signalled = 0;
}

// Printed once at OnDeinit. A guard that fired ZERO times is reported as zero on
// purpose: per the VERDICT GATE that reads as UNTESTED, and it must not be written up
// as "passed" just because the run was clean.
//
// `unaccounted` is the load-bearing field. The first version of these counters missed
// the no-tick return entirely, and the way that was caught was luck: the arithmetic
// happened to close in that run (2568+255+87+26 = 2936) only because the path never
// fired, and that closing sum was then presented as EVIDENCE the counters were wired
// correctly. An invariant used as evidence has to be enforced, not observed -- so the
// sum is now computed here. Any future return path added without a counter makes
// `unaccounted` non-zero and says so in the log, instead of quietly weakening every
// number on the line.
void Entry_Wave5_LogCounters()
{
   int counted = g_w5_n_no_swings + g_w5_n_bad_pattern + g_w5_n_no_tick +
                 g_w5_n_not_in_zone + g_w5_n_struct_inv + g_w5_n_latched +
                 g_w5_n_no_atr + g_w5_n_sl_invalid + g_w5_n_signalled;
   int unaccounted = g_w5_n_eval - counted;
   PrintFormat("[17][counters] evaluated=%d signalled=%d unaccounted=%d | rejected: no_swings=%d bad_pattern=%d no_tick=%d not_in_zone=%d struct_invalid=%d already_latched=%d NO_RISK_ATR=%d sl_invalid=%d",
               g_w5_n_eval, g_w5_n_signalled, unaccounted, g_w5_n_no_swings, g_w5_n_bad_pattern,
               g_w5_n_no_tick, g_w5_n_not_in_zone, g_w5_n_struct_inv, g_w5_n_latched,
               g_w5_n_no_atr, g_w5_n_sl_invalid);
   if(unaccounted != 0)
      PrintFormat("[17][counters] WARN unaccounted=%d - a return path in Entry_Evaluate has no counter; every rejection number above is understated", unaccounted);
}

EntrySignal Entry_Evaluate()
{
   // evaluate exactly once per CLOSED bar (ST03 pattern)
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_wave5_last_bar) return Entry_MakeNone("wave5: intrabar (bar already counted)");
   g_wave5_last_bar = curBar;
   g_w5_n_eval++;

   Swing sw[];
   int n = Wave5_CollectSwings(sw, _17_MaxSwings, _17_FractalDepth);
   if(n < 4) { g_w5_n_no_swings++; return Entry_MakeNone("wave5: not enough confirmed swings (need 4 for 1-2-3)"); }

   // sw[] is newest-first, strictly alternating high/low. A 1-2-3 structure
   // needs FOUR pivots (wave1_end and wave3_peak must be the SAME type, so
   // they cannot be adjacent). Label the 4 most recent:
   //   sw[3] = wave1 origin, sw[2] = wave1 end (= wave2 origin),
   //   sw[1] = wave2 end (= wave3 origin), sw[0] = wave3 peak
   // For a long: low(sw3) -> high(sw2) -> low(sw1) -> high(sw0).
   Swing w1_origin = sw[3];
   Swing w1_end    = sw[2];
   Swing w2_end    = sw[1];
   Swing w3_peak   = sw[0];

   // wave1 impulse direction from its origin->end leg; wave3 peak must match type.
   int dir = 0; // 1 = long (wave1 up), 2 = short (wave1 down)
   if(w1_end.isHigh && !w1_origin.isHigh && w3_peak.isHigh) dir = 1;
   else if(!w1_end.isHigh && w1_origin.isHigh && !w3_peak.isHigh) dir = 2;
   else { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: 1-2-3 pivot pattern invalid"); }

   double wave1Len = MathAbs(w1_end.price - w1_origin.price);
   if(wave1Len <= 0.0) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave1 zero length"); }

   // wave2 must NOT retrace past wave1 origin (EW rule: a valid 1-2-3).
   if(dir == 1 && w2_end.price <= w1_origin.price) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave2 broke wave1 origin"); }
   if(dir == 2 && w2_end.price >= w1_origin.price) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave2 broke wave1 origin"); }

   // wave3-confirm: broke past wave1 end (top/bottom) by >= _17_Wave3MinMult x
   // wave1Len (Fable D2, permissive default).
   double breakDist = (dir == 1 ? w3_peak.price - w1_end.price : w1_end.price - w3_peak.price);
   if(breakDist < _17_Wave3MinMult * wave1Len) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave3 run too short / did not break wave1"); }

   // latch: one signal ever per wave3-peak datetime.
   if(w3_peak.time == g_wave5_latched_peak) { g_w5_n_latched++; return Entry_MakeNone("wave5: this wave3 peak already latched"); }

   // wave-4 retrace zone: between _17_EntryFib% of the FULL wave-3 length
   // (wave3 origin -> peak) and the structural invalidation (wave-1 top/bottom).
   // No 50% hard guard per AMENDMENT/Fable D1.
   Swing latest = w3_peak; // kept for the signal reason string
   double wave3Len = MathAbs(w3_peak.price - w2_end.price);
   double fibDist  = (_17_EntryFib / 100.0) * wave3Len;
   double fibLevel = (dir == 1 ? w3_peak.price - fibDist : w3_peak.price + fibDist);
   double invalidationLevel = w1_end.price; // wave-1 top (long) / wave-1 bottom (short)

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) { g_w5_n_no_tick++; return Entry_MakeNone("wave5: no tick"); }
   // ORDER-432 finding 1 (Codex blind audit 2026-07-27, traced and confirmed by the
   // user). This used to be `(dir == 1 ? t.bid : t.ask)` -- the WRONG side. The order
   // actually fills at ask for a long and bid for a short (LabCore.mqh Lab_OpenOrder),
   // so the recorded reference was one spread closer to the SL than the real entry.
   // Mode-42 risk sizing divides by |entry_ref - sl| (ExitManager Exit_SLDistancePoints),
   // so a distance short by one spread makes the lot LARGER than the requested risk:
   // long, bid 2000.00 / ask 2000.20 / SL 1990.00 sizes off 10.00 while the true risk
   // is 10.20. The TP anchor below has the same problem in the other direction -- a
   // "100% expansion from entry" measured from bid is short of a full expansion.
   //
   // Both uses want the price the position is actually opened at, so both now take it.
   // This CHANGES BEHAVIOUR by one spread and the regression baseline moves with it;
   // that is correct here, because the old baseline is a record of the defect.
   double px = (dir == 1 ? t.ask : t.bid);
   double closePx = iClose(_Symbol, _Period, 1);

   bool inZone;
   if(dir == 1)
      inZone = (closePx <= fibLevel && closePx > invalidationLevel);
   else
      inZone = (closePx >= fibLevel && closePx < invalidationLevel);

   if(!inZone)
   {
      // beyond invalidation (structure broke) or not retraced enough yet:
      // never chase with a resting limit - no pending bookkeeping in this seam.
      // counted separately on purpose: "overlapped wave1" means the STRUCTURE broke and
      // this setup is dead, while "not yet in the zone" means it is still perfectly
      // valid and merely early. Lumping them under one `not_in_zone` label (as the
      // first version did) makes the counter misreport what it counts, which is a
      // smaller version of the problem these counters exist to solve.
      if(dir == 1 && closePx <= invalidationLevel) { g_w5_n_struct_inv++; return Entry_MakeNone("wave5: wave4 overlapped wave1 top - invalid"); }
      if(dir == 2 && closePx >= invalidationLevel) { g_w5_n_struct_inv++; return Entry_MakeNone("wave5: wave4 overlapped wave1 bottom - invalid"); }
      g_w5_n_not_in_zone++;
      return Entry_MakeNone("wave5: wave4 not yet in entry zone");
   }

   // ORDER-432 finding 2 (Codex blind audit 2026-07-27, verified 2026-07-27).
   // Indi_RiskATR returns 0.0 when CopyBuffer fails (Indicators.mqh:104 -- the sentinel
   // is indistinguishable from a real reading of zero), and this line used to multiply
   // it unchecked. A failed read therefore became a LEGAL ZERO BUFFER: slPrice collapsed
   // onto invalidationLevel exactly, and Wave5_SLValid can still approve that, because
   // the zone test above already guarantees the level sits on the correct side of the
   // tick. The EA would then open on a value it failed to read, with a stop sitting
   // precisely on the structural level the buffer exists to stand clear of -- so the
   // first wick through the wave-1 top takes it out.
   //
   // Refuse the entry instead. This is guard G4's rule applied one line earlier: an
   // ingredient that could not be read is never silently replaced by a default, because
   // that changes the strategy without telling anyone. A missed trade is the correct
   // price for unreadable data.
   //
   // NOTE this is live independently of FirstLotMode: unlike finding 1 (mode 42 only,
   // and no .set in this repo uses mode 42), this path is on the SL itself, so it
   // applies to the three Wave5 legs currently attached on demo, all of which run the
   // compiled default FirstLotMode=41.
   double riskAtr = Indi_RiskATR(0);
   if(_17_SLbufferATR > 0.0 && !(riskAtr > 0.0))
   {
      g_w5_n_no_atr++;
      static datetime w5_atr_log = 0;
      datetime now_atr = TimeCurrent();
      if(now_atr - w5_atr_log >= 60)
      {
         w5_atr_log = now_atr;
         Print("[17] Risk-ATR unreadable (CopyBuffer returned no data) - entry SKIPPED rather than opened with a zero SL buffer (ORDER-432 finding 2)");
      }
      return Entry_MakeNone("wave5: Risk-ATR unreadable - refusing a zero SL buffer");
   }
   double buffer  = _17_SLbufferATR * riskAtr;
   double slPrice = (dir == 1 ? invalidationLevel - buffer : invalidationLevel + buffer);

   // guard G4: broker-validity check BEFORE latching/publishing. Invalid SL =
   // Entry_MakeNone, never a silent distance-SL fallback (would change the
   // strategy without telling anyone). Latch (below) only happens once valid.
   if(!Wave5_SLValid(dir, slPrice))
   {
      g_w5_n_sl_invalid++;
      return Entry_MakeNone("wave5: structural SL fails broker stops-level check");
   }

   // valid signal: latch, publish anchors, emit.
   g_w5_n_signalled++;
   g_wave5_latched_peak = latest.time;
   g_wave5_sl_price  = slPrice;
   g_wave5_entry_ref = px;
   g_wave5_tp_price  = (dir == 1 ? px + wave1Len : px - wave1Len); // 100% expansion from entry (Fable D3)

   EntrySignal s;
   s.direction  = dir;
   s.strength   = breakDist;
   s.confidence = 1.0;
   s.valid      = true;
   s.reason     = "wave5: wave4 zone arm dir=" + IntegerToString(dir) +
                  " fib=" + DoubleToString(_17_EntryFib, 1) +
                  " peak=" + TimeToString(latest.time);
   return s;
}

//==================== B17 Stage-0 persistence / runtime ===================
string B17_MakeStructureId(const int direction,const datetime w1_origin,
                           const datetime w1_end,const datetime w2_end,
                           const datetime w3_peak)
{
   return StringFormat("B17|%d|%I64d|%I64d|%I64d|%I64d",direction,
                       (long)w1_origin,(long)w1_end,(long)w2_end,(long)w3_peak);
}

long B17_ProposedMagic(const string structure_id,const long base_magic)
{
   uint h=Persist_Hash32(structure_id+"|"+IntegerToString(base_magic));
   long magic=1000000+(long)(h%2000000000);
   if(magic==base_magic) magic++;
   return magic;
}

void B17_RegisterOwnedMagic(const long magic)
{
   if(magic<=0) return;
   for(int i=0;i<ArraySize(g_b17_owned_magics);i++)
      if(g_b17_owned_magics[i]==magic) return;
   int n=ArraySize(g_b17_owned_magics);
   ArrayResize(g_b17_owned_magics,n+1);
   g_b17_owned_magics[n]=magic;
}

bool B17_PersistStructure(const B17_Structure &state)
{
   if(DryRun) return true;
   bool ok=true;
   ok=Persist_StructSet(state.structure_id,state.magic,"dir",state.direction)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w1ot",state.wave1_origin_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w1et",state.wave1_end_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w2t",state.wave2_end_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w3t",state.wave3_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"act",state.activation_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w1op",state.wave1_origin_price)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w1ep",state.wave1_end_price)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w2p",state.wave2_end_price)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w3p",state.wave3_peak_price)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"w1len",state.wave1_length)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"rawinv",state.raw_wave1_invalidation)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"life",state.lifecycle)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"cintent",state.close_intent?1.0:0.0)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"creason",state.close_reason)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"lastbar",state.last_action_bar)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"ever",state.ever_filled?1.0:0.0)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"fftime",state.first_fill_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"ffprice",state.first_fill_price)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"initbal",state.initial_balance_snapshot)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"riskpct",state.total_setup_risk_pct)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"riskmoney",state.total_setup_risk_money)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"discard",state.discarded_quota_money)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"balbase",state.balance_base_snapshot)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"eqbase",state.equity_base_snapshot)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"batr",state.basket_atr_snapshot)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"batrt",state.basket_atr_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"ratr",state.risk_atr_value)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"ratrt",state.risk_atr_time)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"ratrtf",state.risk_atr_tf)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"batrtf",state.basket_atr_tf)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"sharedtp",state.shared_structure_target)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"nlevels",state.level_count)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"dupretry",state.duplicate_retry_forbidden?1.0:0.0)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"orphan",state.orphaned?1.0:0.0)&&ok;
   ok=Persist_StructSet(state.structure_id,state.magic,"collide",state.collision?1.0:0.0)&&ok;
   for(int i=0;i<state.level_count;i++)
   {
      string p="l"+IntegerToString(i);
      ok=Persist_StructSet(state.structure_id,state.magic,p+"fib",state.levels[i].fib_pct)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"px",state.levels[i].price)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"st",state.levels[i].state)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"why",state.levels[i].reason)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"alloc",state.levels[i].allocated_risk_money)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"rawlot",state.levels[i].raw_lot)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"normlot",state.levels[i].normalized_lot)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"filllot",state.levels[i].filled_lot)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"prisk",state.levels[i].actual_price_risk)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"rmoney",state.levels[i].actual_risk_money)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"discard",state.levels[i].discarded_quota_money)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"target",state.levels[i].target_price)&&ok;
      ok=Persist_StructSet(state.structure_id,state.magic,p+"qacct",state.levels[i].quota_accounted?1.0:0.0)&&ok;
   }
   if(ok) ok=Persist_StructCommitIndex(state.structure_id,state.magic);
   Persist_Flush();
   return ok;
}

bool B17_LoadValue(const uint hash,const long magic,const string name,double &value)
{
   if(!Persist_StructHasFromHash(hash,magic,name)) return false;
   value=Persist_StructGetFromHash(hash,magic,name,0.0);
   return MathIsValidNumber(value);
}

bool B17_LoadField(const uint hash,const long magic,const string name,double &field)
{
   double value=0.0;
   if(!B17_LoadValue(hash,magic,name,value)) return false;
   field=value;
   return true;
}

bool B17_LoadPersisted(const uint hash,const long magic,B17_Structure &state)
{
   B17_ResetStructure(state);
   double dir,w1ot,w1et,w2t,w3t,act;
   if(!B17_LoadValue(hash,magic,"dir",dir) ||
      !B17_LoadValue(hash,magic,"w1ot",w1ot) ||
      !B17_LoadValue(hash,magic,"w1et",w1et) ||
      !B17_LoadValue(hash,magic,"w2t",w2t) ||
      !B17_LoadValue(hash,magic,"w3t",w3t) ||
      !B17_LoadValue(hash,magic,"act",act)) return false;
   string id=B17_MakeStructureId((int)dir,(datetime)w1ot,(datetime)w1et,
                                 (datetime)w2t,(datetime)w3t);
   if(Persist_StructHash(id)!=hash) return false;
   state.structure_id=id; state.structure_hash=hash; state.magic=magic;
   state.direction=(int)dir; state.wave1_origin_time=(datetime)w1ot;
   state.wave1_end_time=(datetime)w1et; state.wave2_end_time=(datetime)w2t;
   state.wave3_time=(datetime)w3t; state.activation_time=(datetime)act;
   double v=0.0;
   if(!B17_LoadField(hash,magic,"w1op",state.wave1_origin_price)) return false;
   if(!B17_LoadField(hash,magic,"w1ep",state.wave1_end_price)) return false;
   if(!B17_LoadField(hash,magic,"w2p",state.wave2_end_price)) return false;
   if(!B17_LoadField(hash,magic,"w3p",state.wave3_peak_price)) return false;
   if(!B17_LoadField(hash,magic,"w1len",state.wave1_length)) return false;
   if(!B17_LoadField(hash,magic,"rawinv",state.raw_wave1_invalidation)) return false;
   if(!B17_LoadValue(hash,magic,"life",v)) return false; state.lifecycle=(B17_Lifecycle)(int)v;
   if(!B17_LoadValue(hash,magic,"cintent",v)) return false; state.close_intent=(v>0.5);
   if(!B17_LoadValue(hash,magic,"creason",v)) return false; state.close_reason=(int)v;
   if(!B17_LoadValue(hash,magic,"lastbar",v)) return false; state.last_action_bar=(datetime)v;
   if(!B17_LoadValue(hash,magic,"ever",v)) return false; state.ever_filled=(v>0.5);
   if(!B17_LoadValue(hash,magic,"fftime",v)) return false; state.first_fill_time=(datetime)v;
   if(!B17_LoadField(hash,magic,"ffprice",state.first_fill_price)) return false;
   if(!B17_LoadField(hash,magic,"initbal",state.initial_balance_snapshot)) return false;
   if(!B17_LoadField(hash,magic,"riskpct",state.total_setup_risk_pct)) return false;
   if(!B17_LoadField(hash,magic,"riskmoney",state.total_setup_risk_money)) return false;
   if(!B17_LoadField(hash,magic,"discard",state.discarded_quota_money)) return false;
   if(!B17_LoadField(hash,magic,"balbase",state.balance_base_snapshot)) return false;
   if(!B17_LoadField(hash,magic,"eqbase",state.equity_base_snapshot)) return false;
   if(!B17_LoadField(hash,magic,"batr",state.basket_atr_snapshot)) return false;
   if(!B17_LoadValue(hash,magic,"batrt",v)) return false; state.basket_atr_time=(datetime)v;
   if(!B17_LoadField(hash,magic,"ratr",state.risk_atr_value)) return false;
   if(!B17_LoadValue(hash,magic,"ratrt",v)) return false; state.risk_atr_time=(datetime)v;
   if(!B17_LoadValue(hash,magic,"ratrtf",v)) return false; state.risk_atr_tf=(ENUM_TIMEFRAMES)(int)v;
   if(!B17_LoadValue(hash,magic,"batrtf",v)) return false; state.basket_atr_tf=(ENUM_TIMEFRAMES)(int)v;
   if(!B17_LoadField(hash,magic,"sharedtp",state.shared_structure_target)) return false;
   if(!B17_LoadValue(hash,magic,"nlevels",v)) return false; state.level_count=(int)v;
   if(state.level_count<=0 || state.level_count>B17_LEVEL_CAP) return false;
   if(!B17_LoadValue(hash,magic,"dupretry",v)) return false; state.duplicate_retry_forbidden=(v>0.5);
   if(!B17_LoadValue(hash,magic,"orphan",v)) return false; state.orphaned=(v>0.5);
   if(!B17_LoadValue(hash,magic,"collide",v)) return false; state.collision=(v>0.5);
   for(int i=0;i<state.level_count;i++)
   {
      string p="l"+IntegerToString(i);
      if(!B17_LoadField(hash,magic,p+"fib",state.levels[i].fib_pct)) return false;
      if(!B17_LoadField(hash,magic,p+"px",state.levels[i].price)) return false;
      if(!B17_LoadValue(hash,magic,p+"st",v)) return false; state.levels[i].state=(B17_LevelState)(int)v;
      if(!B17_LoadValue(hash,magic,p+"why",v)) return false; state.levels[i].reason=(B17_LevelReason)(int)v;
      if(!B17_LoadField(hash,magic,p+"alloc",state.levels[i].allocated_risk_money)) return false;
      if(!B17_LoadField(hash,magic,p+"rawlot",state.levels[i].raw_lot)) return false;
      if(!B17_LoadField(hash,magic,p+"normlot",state.levels[i].normalized_lot)) return false;
      if(!B17_LoadField(hash,magic,p+"filllot",state.levels[i].filled_lot)) return false;
      if(!B17_LoadField(hash,magic,p+"prisk",state.levels[i].actual_price_risk)) return false;
      if(!B17_LoadField(hash,magic,p+"rmoney",state.levels[i].actual_risk_money)) return false;
      if(!B17_LoadField(hash,magic,p+"discard",state.levels[i].discarded_quota_money)) return false;
      if(!B17_LoadField(hash,magic,p+"target",state.levels[i].target_price)) return false;
      if(!B17_LoadValue(hash,magic,p+"qacct",v)) return false; state.levels[i].quota_accounted=(v>0.5);
   }
   state.restored=true;
   return true;
}

int B17_ActiveStructureCount()
{
   int count=0;
   for(int i=0;i<ArraySize(g_b17_structures);i++)
      if(g_b17_structures[i].lifecycle!=B17_LIFECYCLE_CLOSED) count++;
   return count;
}

void B17_LogLedger(const B17_Structure &state,const string event_name)
{
   double pnl=(state.magic>0 ? Exec_BasketProfitMagic(state.magic) : 0.0);
   PrintFormat("[B17][ledger] event=%s structure_id=%s structure_magic=%I64d direction=%d wave3_time=%I64d raw_wave1_invalidation=%.10f lifecycle=%d first_fill_time=%I64d active_structure_count=%d frozen_risk_base=%.2f total_setup_risk_pct=%.6f quota=%.2f discarded_quota=%.2f aggregate_active_structure_risk=%.2f risk_atr_tf=%s risk_atr=%.10f risk_atr_time=%I64d signal_atr=INERT/NO_DIRECT_CONSUMER basket_atr_tf=%s basket_atr=%.10f basket_atr_time=%I64d shared_target=%.10f basket_owned_pnl=%.2f close_intent=%d restored=%d orphan=%d collision=%d duplicate_retry_forbidden=%d",
               event_name,state.structure_id,state.magic,state.direction,
               (long)state.wave3_time,state.raw_wave1_invalidation,state.lifecycle,
               (long)state.first_fill_time,B17_ActiveStructureCount(),
               state.initial_balance_snapshot,state.total_setup_risk_pct,
               state.total_setup_risk_money,state.discarded_quota_money,
               B17_AggregateActiveRisk(g_b17_structures),EnumToString(state.risk_atr_tf),
               state.risk_atr_value,(long)state.risk_atr_time,
               EnumToString(state.basket_atr_tf),state.basket_atr_snapshot,
               (long)state.basket_atr_time,state.shared_structure_target,pnl,
               state.close_intent?1:0,state.restored?1:0,state.orphaned?1:0,
               state.collision?1:0,state.duplicate_retry_forbidden?1:0);
   for(int i=0;i<state.level_count;i++)
      PrintFormat("[B17][level] structure_id=%s magic=%I64d index=%d fib=%.3f price=%.10f state=%d reason=%d allocated_risk=%.2f raw_lot=%.8f normalized_lot=%.8f filled_lot=%.8f actual_sl_price_risk=%.10f actual_risk_money=%.2f discarded_quota=%.2f target=%.10f",
                  state.structure_id,state.magic,i,state.levels[i].fib_pct,
                  state.levels[i].price,state.levels[i].state,state.levels[i].reason,
                  state.levels[i].allocated_risk_money,state.levels[i].raw_lot,
                  state.levels[i].normalized_lot,state.levels[i].filled_lot,
                  state.levels[i].actual_price_risk,state.levels[i].actual_risk_money,
                  state.levels[i].discarded_quota_money,state.levels[i].target_price);
}

ENUM_TIMEFRAMES B17_RiskATRTimeframe()
{
   if(_Period==PERIOD_H1)
      return (_17_RiskATRContext==B17_ATR_PRIMARY_CONTEXT ? PERIOD_H1 : PERIOD_H4);
   if(_Period==PERIOD_H4)
      return (_17_RiskATRContext==B17_ATR_PRIMARY_CONTEXT ? PERIOD_H4 : PERIOD_D1);
   return PERIOD_CURRENT;
}

bool B17_ReadATR(const int handle,const ENUM_TIMEFRAMES timeframe,
                 double &value,datetime &source_time)
{
   value=0.0; source_time=0;
   if(handle==INVALID_HANDLE) return false;
   double buffer[];
   if(CopyBuffer(handle,0,1,1,buffer)!=1 || !MathIsValidNumber(buffer[0]) || buffer[0]<=0.0)
      return false;
   datetime t=iTime(_Symbol,timeframe,1);
   if(t<=0) return false;
   value=buffer[0]; source_time=t;
   return true;
}

int B17_FindStructureId(const string structure_id)
{
   for(int i=0;i<ArraySize(g_b17_structures);i++)
      if(g_b17_structures[i].structure_id==structure_id) return i;
   return -1;
}

int B17_FindStructureMagic(const long magic)
{
   for(int i=0;i<ArraySize(g_b17_structures);i++)
      if(g_b17_structures[i].magic==magic) return i;
   return -1;
}

bool B17_BuildLatestStructure(B17_Structure &candidate)
{
   Swing sw[];
   int n=Wave5_CollectSwings(sw,_17_MaxSwings,_17_FractalDepth);
   if(n<4) return false;
   Swing w1_origin=sw[3],w1_end=sw[2],w2_end=sw[1],w3_peak=sw[0];
   int direction=0;
   if(w1_end.isHigh && !w1_origin.isHigh && w3_peak.isHigh) direction=1;
   else if(!w1_end.isHigh && w1_origin.isHigh && !w3_peak.isHigh) direction=2;
   else return false;
   double wave1_length=MathAbs(w1_end.price-w1_origin.price);
   if(wave1_length<=0.0) return false;
   if(direction==1 && w2_end.price<=w1_origin.price) return false;
   if(direction==2 && w2_end.price>=w1_origin.price) return false;
   double break_distance=(direction==1 ? w3_peak.price-w1_end.price :
                                           w1_end.price-w3_peak.price);
   if(break_distance<_17_Wave3MinMult*wave1_length) return false;
   string id=B17_MakeStructureId(direction,w1_origin.time,w1_end.time,
                                 w2_end.time,w3_peak.time);
   double fibs[B17_LEVEL_CAP]={_17_FibLevel1,_17_FibLevel2,
                               _17_FibLevel3,_17_FibLevel4};
   long magic=B17_ProposedMagic(id,_0_Magic);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!B17_InitStructureState(candidate,id,magic,direction,w3_peak.time,
                              iTime(_Symbol,_Period,1),w1_end.price,wave1_length,
                              w2_end.price,w3_peak.price,balance,_42_RiskPct,
                              fibs,_17_LadderLevelCount,_17_RiskAllocation))
      return false;
   candidate.wave1_origin_time=w1_origin.time;
   candidate.wave1_end_time=w1_end.time;
   candidate.wave2_end_time=w2_end.time;
   candidate.wave1_origin_price=w1_origin.price;
   candidate.wave1_end_price=w1_end.price;
   return true;
}

bool B17_AddLatestStructure()
{
   B17_Structure candidate;
   if(!B17_BuildLatestStructure(candidate)) return false;
   if(B17_FindStructureId(candidate.structure_id)>=0) return false;
   if(_17_ConcurrencyMode==B17_SINGLE_ACTIVE_STRUCTURE && B17_ActiveStructureCount()>0)
      return false;
   if(B17_MagicCollides(g_b17_structures,candidate.magic,candidate.structure_id) ||
      Exec_AnyBrokerMagic(candidate.magic))
   {
      candidate.collision=true;
      g_b17_orphaned_exposure=true;
      PrintFormat("[B17] COLLISION structure_id=%s proposed_magic=%I64d - NEW ENTRY FAIL CLOSED",
                  candidate.structure_id,candidate.magic);
      return false;
   }
   int n=ArraySize(g_b17_structures);
   ArrayResize(g_b17_structures,n+1);
   g_b17_structures[n]=candidate;
   B17_RegisterOwnedMagic(candidate.magic);
   if(!B17_PersistStructure(g_b17_structures[n]))
   {
      g_b17_structures[n].orphaned=true;
      g_b17_orphaned_exposure=true;
      Print("[B17] activation persistence failed - NEW ENTRY FAIL CLOSED");
      return false;
   }
   B17_LogLedger(g_b17_structures[n],"ACTIVATED");
   return true;
}

bool B17_RestoreStructures()
{
   ArrayResize(g_b17_structures,0);
   ArrayResize(g_b17_owned_magics,0);
   g_b17_orphaned_exposure=false;
   long magics[]; uint hashes[];
   int total=Persist_StructList(magics,hashes);
   for(int i=0;i<total;i++)
   {
      B17_Structure restored;
      if(!B17_LoadPersisted(hashes[i],magics[i],restored))
      {
         if(Exec_MagicHasBrokerExposure(magics[i]))
         {
            B17_RegisterOwnedMagic(magics[i]);
            g_b17_orphaned_exposure=true;
            PrintFormat("[B17] ORPHAN magic=%I64d persisted state missing/ambiguous with live exposure - NEW ENTRY FAIL CLOSED",magics[i]);
         }
         continue;
      }
      int existing=B17_FindStructureMagic(restored.magic);
      if(existing>=0 && g_b17_structures[existing].structure_id!=restored.structure_id)
      {
         g_b17_structures[existing].collision=true;
         g_b17_orphaned_exposure=true;
         PrintFormat("[B17] COLLISION restored magic=%I64d has multiple structure identities - NEW ENTRY FAIL CLOSED",restored.magic);
         continue;
      }
      int n=ArraySize(g_b17_structures);
      ArrayResize(g_b17_structures,n+1);
      g_b17_structures[n]=restored;
      if(restored.lifecycle!=B17_LIFECYCLE_CLOSED ||
         Exec_MagicHasBrokerExposure(restored.magic))
         B17_RegisterOwnedMagic(restored.magic);
      B17_LogLedger(g_b17_structures[n],"RESTORED");
   }

   // A live B17-commented position without a matching complete persisted
   // identity is an orphan. Own it for hard-risk sweeps, but do not guess Fib
   // rights or resume normal entries.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      string comment=PositionGetString(POSITION_COMMENT);
      if(StringFind(comment,"B17:")!=0) continue;
      long magic=(long)PositionGetInteger(POSITION_MAGIC);
      if(B17_FindStructureMagic(magic)>=0) continue;
      B17_RegisterOwnedMagic(magic);
      g_b17_orphaned_exposure=true;
      PrintFormat("[B17] ORPHAN live ticket=%I64u magic=%I64d has no restorable structure - NEW ENTRY FAIL CLOSED",ticket,magic);
   }
   return !g_b17_orphaned_exposure;
}

bool B17_RuntimeConfigValid()
{
   if(!_17_UseStructLevels)
   {
      Print("[INIT][B17] FATAL: Stage-0 requires raw-Wave1 buffered emergency SL ownership");
      return false;
   }
   if(_Period!=PERIOD_H1 && _Period!=PERIOD_H4)
   {
      Print("[INIT][B17] FATAL: Stage-0 RiskATR context mapping is defined only for H1/H4 charts");
      return false;
   }
   if(_17_BasketATR_TF!=PERIOD_H1 && _17_BasketATR_TF!=PERIOD_H4 &&
      _17_BasketATR_TF!=PERIOD_D1)
   {
      Print("[INIT][B17] FATAL: BasketATR TF must be H1/H4/D1");
      return false;
   }
   if(_17_LadderLevelCount<=0 || _17_LadderLevelCount>B17_LEVEL_CAP ||
      !(_17_FibLevel1>0.0 && _17_FibLevel1<_17_FibLevel2 &&
        _17_FibLevel2<_17_FibLevel3 && _17_FibLevel3<_17_FibLevel4 &&
        _17_FibLevel4<100.0) || _42_RiskPct<=0.0)
   {
      Print("[INIT][B17] FATAL: invalid Fib vector/count or total setup risk percent");
      return false;
   }
   if(_17_ConcurrencyMode==B17_OVERLAPPING_STRUCTURES &&
      AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
   {
      Print("[INIT][B17] FATAL: overlapping same/opposite structures require a hedging account for per-Magic ownership");
      return false;
   }
   if(_17_LadderExitMode==B17_BASKET_EXIT)
   {
      if(_17_BasketTargetMode==B17_BASKET_MONEY_TARGET && _2_BasketTP_BalPct<=0.0)
      {
         Print("[INIT][B17] FATAL: basket money target requires _2_BasketTP_BalPct > 0");
         return false;
      }
      if(_17_BasketTargetMode==B17_BASKET_ATR_TARGET && _2_BasketTP_ATRmult<=0.0)
      {
         Print("[INIT][B17] FATAL: basket ATR target requires _2_BasketTP_ATRmult > 0");
         return false;
      }
   }
   return true;
}

bool B17_Init()
{
   g_b17_last_closed_bar=0;
   if(!B17_RuntimeConfigValid()) return false;
   ENUM_TIMEFRAMES risk_tf=B17_RiskATRTimeframe();
   g_b17_risk_atr_handle=iATR(_Symbol,risk_tf,B17_ATR_PERIOD);
   g_b17_basket_atr_handle=iATR(_Symbol,_17_BasketATR_TF,B17_ATR_PERIOD);
   if(g_b17_risk_atr_handle==INVALID_HANDLE ||
      g_b17_basket_atr_handle==INVALID_HANDLE)
   {
      Print("[INIT][B17] FATAL: RiskATR/BasketATR handle creation failed");
      return false;
   }
   B17_RestoreStructures();
   PrintFormat("[CFG][B17] total_setup_risk_pct=_42_RiskPct %.6f per structure; allocation=%d concurrency=%d ladder_exit=%d per_leg_target=%d struct_target=%d RiskATR=14/%s BasketATR=14/%s SignalATR=INERT/NO_DIRECT_CONSUMER SLbufferATR=%.3f",
               _42_RiskPct,_17_RiskAllocation,_17_ConcurrencyMode,
               _17_LadderExitMode,_17_PerLegTargetMode,_17_StructTargetMode,
               EnumToString(risk_tf),EnumToString(_17_BasketATR_TF),_17_SLbufferATR);
   return true;
}

void B17_Deinit()
{
   if(g_b17_risk_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_b17_risk_atr_handle);
   if(g_b17_basket_atr_handle!=INVALID_HANDLE)
      IndicatorRelease(g_b17_basket_atr_handle);
   g_b17_risk_atr_handle=INVALID_HANDLE;
   g_b17_basket_atr_handle=INVALID_HANDLE;
}

void B17_ExpireRemainingRights(B17_Structure &state,const B17_LevelReason reason)
{
   for(int i=0;i<state.level_count;i++)
   {
      if(state.levels[i].state!=B17_LEVEL_UNOPENED) continue;
      state.levels[i].state=B17_LEVEL_EXPIRED_SKIPPED;
      state.levels[i].reason=reason;
      B17_AccountDiscard(state,i,0.0);
   }
}

void B17_ArmClose(B17_Structure &state,const int reason)
{
   state.lifecycle=B17_LIFECYCLE_CLOSE_INTENT;
   state.close_intent=true;
   state.close_reason=reason;
   B17_ExpireRemainingRights(state,(B17_LevelReason)reason);
   B17_PersistStructure(state); // durable before first close attempt
}

bool B17_ReconcileClose(B17_Structure &state)
{
   if(state.lifecycle!=B17_LIFECYCLE_CLOSE_INTENT) return false;
   bool flat=Exec_CloseMagic(state.magic);
   B17_ApplyCloseReconcile(state,flat);
   B17_PersistStructure(state);
   B17_LogLedger(state,flat?"CLOSED_FLAT":"CLOSE_RECONCILE_PENDING");
   return true;
}

void B17_UpdateLevelClosures(B17_Structure &state)
{
   for(int i=0;i<state.level_count;i++)
   {
      if(state.levels[i].state!=B17_LEVEL_OPENED &&
         state.levels[i].state!=B17_LEVEL_PARTIAL_FILLED_CONSUMED) continue;
      ulong ticket; double volume,price; datetime opened;
      if(!Exec_FindMagicLevelPosition(state.magic,i,ticket,volume,price,opened))
      {
         state.levels[i].state=B17_LEVEL_CLOSED;
         state.levels[i].reason=B17_REASON_CLOSED;
      }
   }
}

double B17_BasketTargetMoney(const B17_Structure &state)
{
   if(_17_BasketTargetMode==B17_BASKET_MONEY_TARGET)
   {
      double base=(_17_BasketMoneyBase==B17_BALANCE_PCT ?
                   state.balance_base_snapshot : state.equity_base_snapshot);
      return base*_2_BasketTP_BalPct/100.0;
   }
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double lots=Exec_TotalLotsMagic(state.magic);
   if(state.basket_atr_snapshot<=0.0 || tick_value<=0.0 ||
      tick_size<=0.0 || lots<=0.0) return 0.0;
   return state.basket_atr_snapshot*_2_BasketTP_ATRmult*
          (tick_value/tick_size)*lots;
}

void B17_ManageExisting()
{
   for(int i=0;i<ArraySize(g_b17_structures);i++)
   {
      if(g_b17_structures[i].lifecycle==B17_LIFECYCLE_CLOSED) continue;
      if(g_b17_structures[i].lifecycle==B17_LIFECYCLE_CLOSE_INTENT)
      {
         B17_ReconcileClose(g_b17_structures[i]);
         continue;
      }
      B17_UpdateLevelClosures(g_b17_structures[i]);
      if(g_b17_structures[i].ever_filled &&
         !Exec_MagicHasBrokerExposure(g_b17_structures[i].magic))
      {
         B17_ExpireRemainingRights(g_b17_structures[i],B17_REASON_CLOSED);
         B17_ApplyCloseReconcile(g_b17_structures[i],true);
         B17_PersistStructure(g_b17_structures[i]);
         B17_LogLedger(g_b17_structures[i],"FLAT_TERMINAL_CLOSE");
         continue;
      }
      if(_17_LadderExitMode==B17_BASKET_EXIT && g_b17_structures[i].ever_filled)
      {
         double target=B17_BasketTargetMoney(g_b17_structures[i]);
         double pnl=Exec_BasketProfitMagic(g_b17_structures[i].magic);
         if(target>0.0 && pnl>=target)
         {
            B17_ArmClose(g_b17_structures[i],100+B17_REASON_CLOSED);
            B17_ReconcileClose(g_b17_structures[i]);
         }
      }
   }
   // Trailing is separate from the frozen target definition: it may tighten
   // broker SLs but never rewrites a structure/leg target snapshot.
   if(ExitMode==EXIT_TRAIL) Exit_ApplyTrailing();
}

void B17_BlockLevel(B17_Structure &state,const int level,
                    const B17_LevelReason reason,const string evidence)
{
   B17_ConsumeLevelOutcome(state,level,B17_OPEN_BLOCKED,0.0,0.0,0.0,evidence);
   state.levels[level].reason=reason;
   B17_PersistStructure(state);
   B17_LogLedger(state,evidence);
}

void B17_ProcessLevel(B17_Structure &state,const int level)
{
   double risk_atr=0.0; datetime risk_time=0;
   ENUM_TIMEFRAMES risk_tf=B17_RiskATRTimeframe();
   if(!B17_ReadATR(g_b17_risk_atr_handle,risk_tf,risk_atr,risk_time))
   {
      B17_BlockLevel(state,level,B17_REASON_ATR_MISSING,"MISSING_RISK_ATR");
      return;
   }
   state.risk_atr_value=risk_atr; state.risk_atr_time=risk_time;
   state.risk_atr_tf=risk_tf; state.basket_atr_tf=_17_BasketATR_TF;
   double basket_atr=0.0; datetime basket_time=0;
   bool basket_read=B17_ReadATR(g_b17_basket_atr_handle,_17_BasketATR_TF,
                                basket_atr,basket_time);
   if(!B17_BasketAtrInputsValid(_17_BasketTargetMode,basket_atr,basket_time))
   {
      B17_BlockLevel(state,level,B17_REASON_ATR_MISSING,"MISSING_BASKET_ATR");
      return;
   }
   if(!RiskControl_AcctGateOK() || !RiskControl_AllowNewOrder())
   {
      B17_BlockLevel(state,level,B17_REASON_RISKCONTROL_BLOCK,"RISKCONTROL_BLOCK");
      return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
   {
      B17_BlockLevel(state,level,B17_REASON_BROKER_BLOCK,"QUOTE_UNAVAILABLE");
      return;
   }
   double entry=(state.direction==1 ? tick.ask : tick.bid);
   double sl=(state.direction==1 ?
              state.raw_wave1_invalidation-_17_SLbufferATR*risk_atr :
              state.raw_wave1_invalidation+_17_SLbufferATR*risk_atr);
   if(!Wave5_SLValid(state.direction,sl))
   {
      B17_BlockLevel(state,level,B17_REASON_BROKER_BLOCK,"BROKER_SL_INVALID");
      return;
   }
   double tick_value=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double price_risk=MathAbs(entry-sl);
   double raw_lot=0.0;
   if(!B17_RiskInputsValid(risk_atr,tick_value,tick_size) ||
      !MM_RawLotForRiskMoney(state.levels[level].allocated_risk_money,
                             price_risk,tick_value,tick_size,raw_lot))
   {
      B17_BlockLevel(state,level,B17_REASON_RISKCONTROL_BLOCK,"RISK_SIZING_UNAVAILABLE");
      return;
   }
   state.levels[level].raw_lot=raw_lot;
   double cage_lot=Exec_NormalizeLot(raw_lot);
   if(cage_lot<=0.0 || !Basket_HeatCheckPass(_Symbol,cage_lot))
   {
      B17_BlockLevel(state,level,B17_REASON_RISKCONTROL_BLOCK,"LOT_OR_HEAT_BLOCK");
      return;
   }
   double margin=0.0;
   ENUM_ORDER_TYPE order_type=(state.direction==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcMargin(order_type,_Symbol,cage_lot,entry,margin) ||
      !MathIsValidNumber(margin) || margin<0.0 ||
      margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      B17_BlockLevel(state,level,B17_REASON_RISKCONTROL_BLOCK,"MARGIN_BLOCK");
      return;
   }

   // Persist a consumed/in-flight right before the one and only submit. A
   // crash after this flush can miss a trade; it cannot duplicate one.
   if(!B17_ArmSubmission(state,level) || !B17_PersistStructure(state))
   {
      g_b17_orphaned_exposure=true;
      return;
   }
   string comment=StringFormat("B17:%08x:L%d",state.structure_hash,level);
   Exec_MagicOpenResult opened=Exec_OpenForMagic(state.magic,state.direction,
                                                  raw_lot,sl,0.0,comment);
   B17_OPEN_OUTCOME outcome=B17_OPEN_BLOCKED;
   double fill_lot=opened.filled_volume;
   double fill_price=opened.fill_price;
   datetime fill_time=opened.fill_time;
   if(opened.outcome==EXEC_MAGIC_FULL_FILL) outcome=B17_OPEN_FULL;
   else if(opened.outcome==EXEC_MAGIC_PARTIAL_FILL) outcome=B17_OPEN_PARTIAL;
   else if(opened.outcome==EXEC_MAGIC_AMBIGUOUS)
   {
      ulong ticket; double volume,price; datetime when;
      if(Exec_FindMagicLevelPosition(state.magic,level,ticket,volume,price,when))
      {
         fill_lot=volume; fill_price=price; fill_time=when;
         double tolerance=MathMax(1.0e-12,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*1.0e-8);
         outcome=(MathAbs(volume-opened.requested_volume)<=tolerance ?
                  B17_OPEN_FULL : B17_OPEN_PARTIAL);
      }
      else outcome=B17_OPEN_AMBIGUOUS;
   }
   double actual_price_risk=(fill_price>0.0 ? MathAbs(fill_price-sl) : 0.0);
   double actual_risk=(fill_lot>0.0 && tick_size>0.0 ?
                       (actual_price_risk/tick_size)*tick_value*fill_lot : 0.0);
   B17_ConsumeLevelOutcome(state,level,outcome,opened.requested_volume,
                           fill_lot,actual_risk,
                           outcome==B17_OPEN_AMBIGUOUS ?
                           "AMBIGUOUS_NO_DUPLICATE_RETRY" : "BROKER_RESULT");
   state.levels[level].actual_price_risk=actual_price_risk;

   if(outcome==B17_OPEN_FULL || outcome==B17_OPEN_PARTIAL)
   {
      if(state.first_fill_time<=0 &&
         !B17_FreezeFirstFill(state,fill_price,fill_time,
                              AccountInfoDouble(ACCOUNT_BALANCE),
                              AccountInfoDouble(ACCOUNT_EQUITY),
                              basket_read?basket_atr:0.0,
                              basket_read?basket_time:0))
      {
         B17_ArmClose(state,B17_REASON_TARGET_ATTACH_FAILED);
      }
      if(_17_LadderExitMode==B17_PER_LEG_EXIT &&
         state.lifecycle==B17_LIFECYCLE_ACTIVE)
      {
         double target=B17_TargetForFill(state,fill_price,risk_atr);
         state.levels[level].target_price=target;
         if(target<=0.0 || !Exec_ModifyMagicLevelTarget(state.magic,level,
                                                        NormalizeDouble(sl,_Digits),
                                                        NormalizeDouble(target,_Digits)))
            B17_ArmClose(state,B17_REASON_TARGET_ATTACH_FAILED);
      }
   }
   B17_PersistStructure(state);
   B17_LogLedger(state,outcome==B17_OPEN_FULL?"FULL_FILL":
                       outcome==B17_OPEN_PARTIAL?"PARTIAL_FILL":
                       outcome==B17_OPEN_AMBIGUOUS?"AMBIGUOUS_NO_DUPLICATE_RETRY":
                       "EXPIRED_BLOCKED");
   if(state.lifecycle==B17_LIFECYCLE_CLOSE_INTENT) B17_ReconcileClose(state);
}

void B17_ProcessClosedBar(const double close_price,const datetime closed_bar)
{
   B17_AddLatestStructure();
   for(int i=0;i<ArraySize(g_b17_structures);i++)
   {
      if(g_b17_structures[i].lifecycle!=B17_LIFECYCLE_ACTIVE) continue;
      int level=-1;
      B17_BAR_DECISION decision=B17_ApplyClosedBar(g_b17_structures[i],
                                                    close_price,closed_bar,level);
      if(decision==B17_BAR_INVALIDATE)
      {
         B17_PersistStructure(g_b17_structures[i]);
         B17_LogLedger(g_b17_structures[i],"RAW_WAVE1_INVALIDATION");
         B17_ReconcileClose(g_b17_structures[i]);
         continue;
      }
      if(decision==B17_BAR_ENTER_LEVEL && !g_b17_orphaned_exposure)
         B17_ProcessLevel(g_b17_structures[i],level);
   }
}

void B17_OnTick()
{
   if(RiskControl_CheckDD() || RiskControl_IsHalted()) return;
   B17_ManageExisting();
   if(g_b17_orphaned_exposure) return;
   datetime current_bar=iTime(_Symbol,_Period,0);
   if(current_bar<=0 || current_bar==g_b17_last_closed_bar) return;
   g_b17_last_closed_bar=current_bar;
   datetime closed_bar=iTime(_Symbol,_Period,1);
   double close_price=iClose(_Symbol,_Period,1);
   if(closed_bar<=0 || close_price<=0.0) return;
   B17_ProcessClosedBar(close_price,closed_bar);
}

#endif // LAB_ENTRY_17
#endif // BOSS_LAB_ENTRY_WAVE5_MQH
