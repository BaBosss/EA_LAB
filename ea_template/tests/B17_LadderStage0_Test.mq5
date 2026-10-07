//+------------------------------------------------------------------+
//| B17_LadderStage0_Test.mq5 - deterministic Stage-0 semantics.    |
//| Engineering fixture only: no order, tester-performance, or PnL. |
//+------------------------------------------------------------------+
#property strict

#define LAB_ENTRY_17
#define LAB_ENTRY_TAG "17_LadderStage0_Test"
#include "../core/Inputs.mqh"
#include "../core/Indicators.mqh"
#include "../core/Regime.mqh"
#include "../core/Execution.mqh"
#include "../core/RiskControl.mqh"
#include "../core/MoneyManagement.mqh"
#include "../core/ExitManager.mqh"
#include "../core/Basket.mqh"
#include "../core/entries/Entry_Wave5.mqh"

void B17T_Fail(const string message,int &fail)
{
   PrintFormat("[FAIL] B17_LadderStage0_Test: %s",message);
   fail++;
}

void B17T_Expect(const bool condition,const string message,int &fail)
{
   if(!condition) B17T_Fail(message,fail);
}

void B17T_Init(B17_Structure &state,const string id,const long magic,
               const int direction,const double invalidation,
               const double wave1_length,const double balance,
               const ENUM_B17_RISK_ALLOCATION allocation)
{
   double fibs[4]={23.6,38.2,50.0,61.8};
   B17_ResetStructure(state);
   double wave3_peak=(direction==1 ? invalidation+wave1_length :
                                      invalidation-wave1_length);
   B17_InitStructureState(state,id,magic,direction,1000,900,
                          invalidation,wave1_length,invalidation,wave3_peak,
                          balance,1.0,
                          fibs,4,allocation);
}

int B17T_Run()
{
   int fail=0;

   // D1/D5: one frozen setup budget, never multiplied by level count.
   B17_Structure equal_state;
   B17T_Init(equal_state,"S-EQUAL",17001,1,90.0,10.0,10000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   B17T_Expect(MathAbs(equal_state.total_setup_risk_money-100.0)<1.0e-9,
               "D1 setup-risk money is not the activation-balance snapshot",fail);
   double equal_sum=0.0;
   for(int i=0;i<equal_state.level_count;i++)
      equal_sum+=equal_state.levels[i].allocated_risk_money;
   B17T_Expect(MathAbs(equal_sum-100.0)<1.0e-9,
               "equal allocation changed total setup risk",fail);

   B17_Structure weighted_state;
   B17T_Init(weighted_state,"S-WEIGHT",17002,1,90.0,10.0,10000.0,
             B17_RISK_LINEAR_DEPTH_WEIGHTED);
   double expected[4]={10.0,20.0,30.0,40.0};
   double weighted_sum=0.0;
   for(int i=0;i<weighted_state.level_count;i++)
   {
      B17T_Expect(MathAbs(weighted_state.levels[i].allocated_risk_money-expected[i])<1.0e-9,
                  "linear-depth risk-money weight differs from i/sum(1..N)",fail);
      weighted_sum+=weighted_state.levels[i].allocated_risk_money;
   }
   B17T_Expect(MathAbs(weighted_sum-100.0)<1.0e-9,
               "weighted allocation changed total setup risk",fail);

   // Deepest reached wins; shallower rights expire and never backfill.
   int level=-1;
   B17_BAR_DECISION decision=B17_ApplyClosedBar(equal_state,94.0,1100,level);
   B17T_Expect(decision==B17_BAR_ENTER_LEVEL && level==2,
               "multi-level crossed bar did not select deepest reached level",fail);
   B17T_Expect(equal_state.levels[0].state==B17_LEVEL_EXPIRED_SKIPPED &&
               equal_state.levels[1].state==B17_LEVEL_EXPIRED_SKIPPED,
               "shallower crossed levels were not expired",fail);
   B17T_Expect(B17_ApplyClosedBar(equal_state,93.0,1100,level)==B17_BAR_NONE,
               "same structure acted twice on one closed bar",fail);
   B17_ConsumeLevelOutcome(equal_state,2,B17_OPEN_FULL,0.20,0.20,30.0,
                           "FULL_FILL");
   B17T_Expect(!B17_LevelCanSubmit(equal_state,2),
               "opened level can submit twice",fail);

   // Raw Wave1 invalidation has same-bar precedence over any Fib reach.
   B17_Structure invalidated;
   B17T_Init(invalidated,"S-INVALID",17003,1,90.0,10.0,10000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   decision=B17_ApplyClosedBar(invalidated,89.0,1200,level);
   B17T_Expect(decision==B17_BAR_INVALIDATE &&
               invalidated.lifecycle==B17_LIFECYCLE_CLOSE_INTENT,
               "raw Wave1 invalidation did not beat same-bar entry",fail);
   for(int i=0;i<invalidated.level_count;i++)
      B17T_Expect(invalidated.levels[i].state==B17_LEVEL_EXPIRED_SKIPPED,
                  "invalidation did not expire unopened quota",fail);

   // Block, partial and ambiguous outcomes consume the level and discard quota.
   B17_Structure outcomes;
   B17T_Init(outcomes,"S-OUTCOMES",17004,2,110.0,10.0,10000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   B17_ConsumeLevelOutcome(outcomes,0,B17_OPEN_BLOCKED,0.10,0.0,0.0,
                           "RISKCONTROL_BLOCK");
   B17T_Expect(outcomes.levels[0].state==B17_LEVEL_EXPIRED_BLOCKED &&
               !B17_LevelCanSubmit(outcomes,0),
               "EXPIRED_BLOCKED did not consume the right",fail);
   B17_ConsumeLevelOutcome(outcomes,1,B17_OPEN_PARTIAL,0.10,0.04,10.0,
                           "PARTIAL_FILL");
   B17T_Expect(outcomes.levels[1].state==B17_LEVEL_PARTIAL_FILLED_CONSUMED &&
               !B17_LevelCanSubmit(outcomes,1),
               "partial fill did not consume the level",fail);
   B17_ConsumeLevelOutcome(outcomes,2,B17_OPEN_AMBIGUOUS,0.10,0.0,0.0,
                           "AMBIGUOUS_NO_DUPLICATE_RETRY");
   B17T_Expect(outcomes.levels[2].state==B17_LEVEL_EXPIRED_BLOCKED &&
               outcomes.duplicate_retry_forbidden &&
               !B17_LevelCanSubmit(outcomes,2),
               "ambiguous open left a duplicate-retry path",fail);

   // First-fill D2/D3/shared-target snapshots are immutable across later fills.
   B17_Structure snapshots;
   B17T_Init(snapshots,"S-SNAPSHOT",17005,1,90.0,12.0,10000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   B17T_Expect(B17_FreezeFirstFill(snapshots,101.25,1300,10050.0,10040.0,
                                  2.5,1299),
               "first-fill snapshot failed",fail);
   double shared_target=snapshots.shared_structure_target;
   B17T_Expect(MathAbs(shared_target-113.25)<1.0e-9,
               "shared structural target is not first actual fill + Wave1Length",fail);
   B17T_Expect(!B17_FreezeFirstFill(snapshots,999.0,1400,20000.0,21000.0,
                                   9.0,1399) &&
               snapshots.first_fill_time==1300 &&
               snapshots.balance_base_snapshot==10050.0 &&
               snapshots.equity_base_snapshot==10040.0 &&
               snapshots.basket_atr_snapshot==2.5 &&
               snapshots.basket_atr_time==1299 &&
               snapshots.shared_structure_target==shared_target,
               "later fill drifted a D2/D3/target baseline",fail);

   // Restart copy must retain identity, magic, rights, snapshots and close intent.
   snapshots.levels[0].state=B17_LEVEL_CLOSED;
   snapshots.levels[1].state=B17_LEVEL_EXPIRED_BLOCKED;
   snapshots.lifecycle=B17_LIFECYCLE_CLOSE_INTENT;
   snapshots.close_intent=true;
   B17_Structure replay;
   B17_CopyPersistedState(snapshots,replay);
   B17T_Expect(B17_PersistedStateEqual(snapshots,replay),
               "restart replay lost structure state",fail);
   B17T_Expect(!B17_ApplyCloseReconcile(replay,false) &&
               replay.lifecycle==B17_LIFECYCLE_CLOSE_INTENT,
               "failed close released close intent",fail);
   B17T_Expect(B17_ApplyCloseReconcile(replay,true) &&
               replay.lifecycle==B17_LIFECYCLE_CLOSED &&
               !B17_CanRevive(replay),
               "flat structure did not close terminally",fail);

   // Same/opposite structures remain independent; aggregate risk is additive.
   B17_Structure structures[3];
   B17T_Init(structures[0],"S-A",17101,1,90.0,10.0,10000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   B17T_Init(structures[1],"S-B",17102,1,91.0,10.0,20000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   B17T_Init(structures[2],"S-C",17103,2,110.0,10.0,30000.0,
             B17_RISK_EQUAL_PER_LEVEL);
   B17T_Expect(MathAbs(B17_AggregateActiveRisk(structures)-600.0)<1.0e-9,
               "overlapping aggregate risk report is wrong",fail);
   B17T_Expect(B17_MagicCollides(structures,17102,"S-OTHER") &&
               !B17_MagicCollides(structures,17102,"S-B"),
               "structure/Magic collision policy is wrong",fail);
   B17T_Expect(B17_MagicOwns(17101,17101) && !B17_MagicOwns(17101,17102),
               "cross-Magic ownership predicate leaked",fail);

   // Missing ATR and broker normalization fail closed; minimum lot is never raised.
   B17T_Expect(!B17_RiskInputsValid(0.0,1.0,1.0) &&
               !B17_BasketAtrInputsValid(B17_BASKET_ATR_TARGET,0.0,1300) &&
               B17_BasketAtrInputsValid(B17_BASKET_MONEY_TARGET,0.0,0),
               "missing RiskATR/BasketATR policy is wrong",fail);
   double normalized=0.0;
   B17T_Expect(!Exec_CheckedNormalizeLot(0.004,1.0,0.01,100.0,0.01,1.0,
                                         normalized) && normalized==0.0,
               "broker minimum lot was raised instead of rejected",fail);
   B17T_Expect(Exec_CheckedNormalizeLot(0.029,1.0,0.01,100.0,0.01,1.0,
                                        normalized) && normalized==0.02,
               "volume step was not floored",fail);

   return fail;
}

int OnInit()
{
   int fail=B17T_Run();
   if(fail==0) Print("[PASS] B17_LadderStage0_Test");
   else PrintFormat("[FAIL] B17_LadderStage0_Test: %d",fail);
   return (fail==0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick() {}
