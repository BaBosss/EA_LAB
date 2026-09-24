//+------------------------------------------------------------------+
//| ZoneCompressedGrid_Transactional_Test.mq5                        |
//| Deterministic Phase A transaction and transient-read tests.      |
//+------------------------------------------------------------------+
#property strict
#include "../core/entries/Entry_ZoneCompressedGrid.mqh"

void ZCAG_TestState(ZCAG_RuntimeState &state)
{
   state.regime_bar_time=10;
   state.decision_bar_time=20;
   state.decision_bar_ordinal=20;
   state.bull=true;
   state.ladder_armed=true;
   state.step_frozen=true;
   state.anchor=100.0;
   state.step=5.0;
   state.reached=2;
   state.bars_since_touch=3;
}

void ZCAG_ValidRegime(ZCAG_RegimeSnapshot &snapshot)
{
   snapshot.bar_time=11;
   snapshot.close_read=true;
   snapshot.middle_read=true;
   snapshot.upper_read=true;
   snapshot.close1=111.0;
   snapshot.middle=100.0;
   snapshot.upper=110.0;
}

void ZCAG_ValidDecision(ZCAG_DecisionSnapshot &snapshot)
{
   snapshot.bar_time=21;
   snapshot.decision_bar_ordinal=21;
   snapshot.high_read=true;
   snapshot.low_read=true;
   snapshot.close1_read=true;
   snapshot.close2_read=true;
   snapshot.step_atr_read=true;
   snapshot.structure_atr_read=true;
   snapshot.z_history_read=true;
   snapshot.structure_history_read=true;
   snapshot.high1=101.0;
   snapshot.low1=88.0;
   snapshot.close1=91.0;
   snapshot.close2=89.0;
   snapshot.step_atr=5.0;
   snapshot.structure_atr=2.0;
   snapshot.z_count=4;
   snapshot.z_closes[0]=91.0;
   snapshot.z_closes[1]=96.0;
   snapshot.z_closes[2]=100.0;
   snapshot.z_closes[3]=104.0;
   snapshot.structure_count=12;
   double lows[12]={110.0,109.0,108.0,100.0,106.0,107.0,
                    108.0,99.0,109.0,110.0,111.0,112.0};
   for(int i=0;i<12;i++) snapshot.structure_lows[i]=lows[i];
}

void ZCAG_ValidConfig(ZCAG_DecisionConfig &config)
{
   config.step_atr_mult=1.0;
   config.min_levels=2;
   config.max_levels=11;
   config.expiry_bars=48;
   config.pivot_left=2;
   config.pivot_right=2;
   config.break_atr_mult=5.0;
   config.zone_atr_width=5.0;
   config.z_threshold=-0.5;
}

bool ZCAG_InvalidDecisionLeavesState(
   ZCAG_RuntimeState &state,ZCAG_DecisionSnapshot &snapshot,
   const ZCAG_DecisionConfig &config)
{
   ZCAG_RuntimeState before=state;
   bool ready=false;
   return (ZCAG_ApplyDecisionSnapshot(state,snapshot,config,ready) ==
           ZCAG_APPLY_INVALID && ZCAG_RuntimeStateEqual(state,before));
}

int ZCAG_RunTransactionalTests()
{
   int fail=0;
   ZCAG_RuntimeState state;
   ZCAG_TestState(state);

   // Regime Bollinger transient: neither timestamp nor bull/ladder state moves.
   ZCAG_RegimeSnapshot regime;
   ZCAG_ValidRegime(regime);
   regime.upper_read=false;
   ZCAG_RuntimeState before_regime=state;
   if(ZCAG_ApplyRegimeSnapshot(state,regime) != ZCAG_APPLY_INVALID ||
      !ZCAG_RuntimeStateEqual(state,before_regime)) fail++;

   // Exact same closed regime bar retries and commits once.
   regime.upper_read=true;
   if(ZCAG_ApplyRegimeSnapshot(state,regime) != ZCAG_APPLY_COMMITTED ||
      state.regime_bar_time != 11 || !state.bull) fail++;
   ZCAG_RuntimeState after_regime=state;
   if(ZCAG_ApplyRegimeSnapshot(state,regime) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_regime)) fail++;

   // A newer bear/reset commits, then replaying the older bull snapshot
   // cannot rewind regime or restore the invalidated ladder.
   ZCAG_RegimeSnapshot newer_bear=regime;
   newer_bear.bar_time=12;
   newer_bear.close1=99.0;
   if(ZCAG_ApplyRegimeSnapshot(state,newer_bear) != ZCAG_APPLY_COMMITTED ||
      state.bull || state.ladder_armed || state.step_frozen) fail++;
   ZCAG_RuntimeState after_bear=state;
   if(ZCAG_ApplyRegimeSnapshot(state,regime) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_bear)) fail++;

   ZCAG_DecisionConfig config;
   ZCAG_ValidConfig(config);
   ZCAG_DecisionSnapshot decision;

   // Current decision H/L/C read classes.
   ZCAG_TestState(state);
   ZCAG_ValidDecision(decision);
   decision.high_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;
   decision.high_read=true;
   decision.low_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;
   decision.low_read=true;
   decision.close1_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;
   decision.close1_read=true;
   decision.close2_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;

   // Both ATR transient classes.
   ZCAG_ValidDecision(decision);
   decision.step_atr_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;
   decision.step_atr_read=true;
   decision.structure_atr_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;

   // Z-score source gap and nonfinite source are transactional failures.
   ZCAG_ValidDecision(decision);
   decision.z_history_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;
   decision.z_history_read=true;
   decision.z_closes[2]=MathSqrt(-1.0);
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;

   // A missing recent structure bar is INVALID_HISTORY, never NON_PIVOT.
   ZCAG_ValidDecision(decision);
   decision.structure_lows[4]=0.0;
   if(ZCAG_PivotAt(decision.structure_lows,decision.structure_count,
                   3,config.pivot_left,config.pivot_right) !=
      ZCAG_INVALID_HISTORY) fail++;
   if(!ZCAG_InvalidDecisionLeavesState(state,decision,config)) fail++;

   // A readable candidate that merely loses a comparison is distinct.
   ZCAG_ValidDecision(decision);
   decision.structure_lows[3]=109.0;
   if(ZCAG_PivotAt(decision.structure_lows,decision.structure_count,
                   3,config.pivot_left,config.pivot_right) !=
      ZCAG_VALID_NON_PIVOT) fail++;

   // Every other entry condition can pass while below-minimum depth blocks.
   ZCAG_TestState(state);
   state.reached=1;
   ZCAG_ValidDecision(decision);
   decision.low1=94.0;
   decision.close1=96.0;
   decision.close2=94.0;
   decision.z_closes[0]=96.0;
   bool ready=false;
   if(ZCAG_ApplyDecisionSnapshot(state,decision,config,ready) !=
      ZCAG_APPLY_COMMITTED || ready || state.reached != 1) fail++;

   // A close outside the qualified support zone blocks entry readiness.
   ZCAG_TestState(state);
   ZCAG_ValidDecision(decision);
   ZCAG_DecisionConfig narrow_zone=config;
   narrow_zone.zone_atr_width=4.0;
   ready=false;
   if(ZCAG_ApplyDecisionSnapshot(state,decision,narrow_zone,ready) !=
      ZCAG_APPLY_COMMITTED || ready) fail++;

   // A fully qualifying snapshot commits once and exposes entry readiness.
   ZCAG_TestState(state);
   ZCAG_ValidDecision(decision);
   ready=false;
   if(ZCAG_ApplyDecisionSnapshot(state,decision,config,ready) !=
      ZCAG_APPLY_COMMITTED ||
      state.decision_bar_time != 21 ||
      state.bars_since_touch != 4 || !ready) fail++;
   ZCAG_RuntimeState after_decision=state;
   if(ZCAG_ApplyDecisionSnapshot(state,decision,config,ready) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_decision) || ready) fail++;

   // Strictly older decisions are consumed without aging or readiness.
   ZCAG_DecisionSnapshot older_decision=decision;
   older_decision.bar_time=19;
   older_decision.decision_bar_ordinal=19;
   ready=true;
   if(ZCAG_ApplyDecisionSnapshot(state,older_decision,config,ready) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_decision) || ready) fail++;

   // T1 -> T3 commits monotonically; replaying T2 or T1 cannot recommit.
   ZCAG_TestState(state);
   ZCAG_DecisionSnapshot decision_t1;
   ZCAG_ValidDecision(decision_t1);
   ready=false;
   if(ZCAG_ApplyDecisionSnapshot(state,decision_t1,config,ready) !=
      ZCAG_APPLY_COMMITTED) fail++;
   ZCAG_DecisionSnapshot decision_t3=decision_t1;
   decision_t3.bar_time=23;
   decision_t3.decision_bar_ordinal=23;
   ready=false;
   if(ZCAG_ApplyDecisionSnapshot(state,decision_t3,config,ready) !=
      ZCAG_APPLY_COMMITTED) fail++;
   ZCAG_RuntimeState after_t3=state;
   ZCAG_DecisionSnapshot decision_t2=decision_t1;
   decision_t2.bar_time=22;
   decision_t2.decision_bar_ordinal=22;
   ready=true;
   if(ZCAG_ApplyDecisionSnapshot(state,decision_t2,config,ready) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_t3) || ready) fail++;
   ready=true;
   if(ZCAG_ApplyDecisionSnapshot(state,decision_t1,config,ready) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_t3) || ready) fail++;

   // A transient missed bar is not committed. The later valid ordinal carries
   // the complete three-bar gap and expires before entry readiness.
   ZCAG_TestState(state);
   config.expiry_bars=6;
   ZCAG_DecisionSnapshot missed=decision_t1;
   missed.bar_time=21;
   missed.decision_bar_ordinal=21;
   missed.high_read=false;
   if(!ZCAG_InvalidDecisionLeavesState(state,missed,config)) fail++;
   ZCAG_DecisionSnapshot after_gap=decision_t1;
   after_gap.bar_time=23;
   after_gap.decision_bar_ordinal=23;
   ready=true;
   if(ZCAG_ApplyDecisionSnapshot(state,after_gap,config,ready) !=
      ZCAG_APPLY_COMMITTED || state.decision_bar_ordinal != 23 ||
      state.ladder_armed || state.step_frozen ||
      state.bars_since_touch != 0 || ready) fail++;

   // A strictly newer timestamp with a non-increasing or unrepresentable
   // closed-bar ordinal fails closed without state mutation.
   ZCAG_TestState(state);
   ZCAG_DecisionSnapshot invalid_elapsed=decision_t1;
   invalid_elapsed.bar_time=21;
   invalid_elapsed.decision_bar_ordinal=20;
   if(!ZCAG_InvalidDecisionLeavesState(state,invalid_elapsed,config)) fail++;
   invalid_elapsed.decision_bar_ordinal=2147483668;
   if(!ZCAG_InvalidDecisionLeavesState(state,invalid_elapsed,config)) fail++;

   // Same-bar retry after a gap commit ages zero and keeps state byte-equal.
   ZCAG_TestState(state);
   ZCAG_DecisionSnapshot gap_no_expiry=decision_t1;
   gap_no_expiry.bar_time=23;
   gap_no_expiry.decision_bar_ordinal=23;
   config.expiry_bars=48;
   ready=false;
   if(ZCAG_ApplyDecisionSnapshot(state,gap_no_expiry,config,ready) !=
      ZCAG_APPLY_COMMITTED || state.bars_since_touch != 6) fail++;
   ZCAG_RuntimeState after_gap_commit=state;
   ready=true;
   if(ZCAG_ApplyDecisionSnapshot(state,gap_no_expiry,config,ready) !=
      ZCAG_APPLY_ALREADY_CONSUMED ||
      !ZCAG_RuntimeStateEqual(state,after_gap_commit) || ready) fail++;

   // Frozen predecessor arithmetic remains intact.
   if(!ZCAG_ExposureInvariant(0.01,11,0.11)) fail++;
   if(ZCAG_ExposureInvariant(0.01,11,0.1100001)) fail++;
   if(ZCAG_ReachedLevels(100.0,10.0,65.0,11) != 3) fail++;
   if(MathAbs(ZCAG_RawLot(0.01,3,0.11)-0.03) > 1.0e-12) fail++;
   if(MathAbs(ZCAG_Target(100.0,10.0,3)-80.0) > 1.0e-12) fail++;
   if(MathAbs(ZCAG_Stop(100.0,4.0,1.5)-94.0) > 1.0e-12) fail++;

   // Repaired config constraints fail closed.
   ZCAG_DecisionConfig invalid_config=config;
   invalid_config.min_levels=0;
   if(ZCAG_ValidateDecisionConfig(invalid_config)) fail++;
   invalid_config=config;
   invalid_config.min_levels=config.max_levels+1;
   if(ZCAG_ValidateDecisionConfig(invalid_config)) fail++;
   invalid_config=config;
   invalid_config.zone_atr_width=-0.1;
   if(ZCAG_ValidateDecisionConfig(invalid_config)) fail++;
   return fail;
}

int OnInit()
{
   int fail=ZCAG_RunTransactionalTests();
   if(fail == 0)
      Print("[PASS] ZoneCompressedGrid_Transactional_Test");
   else
      PrintFormat("[FAIL] ZoneCompressedGrid_Transactional_Test: %d",fail);
   return (fail == 0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick() {}
