//+------------------------------------------------------------------+
//| Execution_CheckedLot_Test.mq5 - pure prepared-open invariants.   |
//+------------------------------------------------------------------+
#property strict
#include "../core/Execution.mqh"

void Exec_TestMacro(Exec_MacroSnapshot &snapshot)
{
   snapshot.valid=true;
   snapshot.block_exists=false;
   snapshot.block_value=0.0;
   snapshot.block_time=0;
   snapshot.mult_exists=false;
   snapshot.mult_value=1.0;
   snapshot.mult_time=0;
   snapshot.effective_block=false;
   snapshot.effective_mult=1.0;
}

void Exec_TestPrepared(Exec_PreparedOpen &prepared,
                       const Exec_MacroSnapshot &snapshot,
                       const double lot)
{
   prepared.valid=true;
   prepared.direction=1;
   prepared.final_checked_lot=lot;
   prepared.macro=snapshot;
}

int Exec_RunCheckedLotTests()
{
   int fail=0;
   double effective=0.0;

   // No multiplier.
   if(!Exec_MacroEffectiveMultiplier(false,1.0,effective) ||
      effective != 1.0) fail++;

   // Valid reduce.
   if(!Exec_MacroEffectiveMultiplier(true,0.5,effective) ||
      effective != 0.5) fail++;

   // Finite invalid values preserve the legacy no-op policy.
   if(!Exec_MacroEffectiveMultiplier(true,0.0,effective) ||
      effective != 1.0) fail++;
   if(!Exec_MacroEffectiveMultiplier(true,1.5,effective) ||
      effective != 1.0) fail++;

   // Nonfinite identity cannot be prepared.
   if(Exec_MacroEffectiveMultiplier(true,MathSqrt(-1.0),effective)) fail++;

   double final_lot=0.0;
   if(!Exec_CheckedNormalizeLot(0.11,0.5,0.01,100.0,0.01,1.0,
                                final_lot) ||
      final_lot != 0.05) fail++;
   if(Exec_CheckedNormalizeLot(0.11,0.5,0.01,100.0,0.0,1.0,
                               final_lot)) fail++;
   if(Exec_CheckedNormalizeLot(0.11,0.5,0.0,100.0,0.01,1.0,
                               final_lot)) fail++;
   if(Exec_CheckedNormalizeLot(0.11,0.5,0.01,0.0,0.01,1.0,
                               final_lot)) fail++;

   Exec_MacroSnapshot prepared_macro;
   Exec_TestMacro(prepared_macro);
   prepared_macro.mult_exists=true;
   prepared_macro.mult_value=0.5;
   prepared_macro.mult_time=100;
   prepared_macro.effective_mult=0.5;

   Exec_PreparedOpen prepared;
   Exec_TestPrepared(prepared,prepared_macro,0.05);
   double submitted=0.0;

   // One final identity reaches both gates and the submission-facing seam.
   if(!Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                      prepared_macro,submitted) ||
      !Exec_CheckedLotIdentity(0.05,0.05,0.05,submitted)) fail++;

   // Heat or margin checking a different lot is rejected.
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.04,0.05,
                                     prepared_macro,submitted)) fail++;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.04,
                                     prepared_macro,submitted)) fail++;

   // Changed multiplier identity is rejected even if it would normalize alike.
   Exec_MacroSnapshot changed=prepared_macro;
   changed.mult_value=0.4;
   changed.effective_mult=0.4;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     changed,submitted)) fail++;

   changed=prepared_macro;
   changed.mult_time++;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     changed,submitted)) fail++;

   // Same raw identity but changed effective multiplier is rejected.
   changed=prepared_macro;
   changed.effective_mult=1.0;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     changed,submitted)) fail++;

   // Same raw identity but changed effective block is rejected.
   changed=prepared_macro;
   changed.effective_block=true;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     changed,submitted)) fail++;

   // Changed block identity is rejected, including a newly active block.
   changed=prepared_macro;
   changed.block_exists=true;
   changed.block_value=1.0;
   changed.block_time=101;
   changed.effective_block=true;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     changed,submitted)) fail++;

   // Invalid prepared state and invalid current identity fail closed.
   prepared.valid=false;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     prepared_macro,submitted)) fail++;
   prepared.valid=true;
   changed=prepared_macro;
   changed.valid=false;
   if(Exec_PreparedOpenAcceptsChecks(prepared,0.05,0.05,
                                     changed,submitted)) fail++;

   // DryRun remains true as intent only, never broker-confirmed execution.
   if(Exec_AssessPreparedOpenResult(true,false,0,0,0.0,0.05,0.0) !=
      EXEC_PREPARED_INTENT_ONLY) fail++;

   // DONE + deal + exact positive volume proves one complete market fill.
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_MARKET_DONE) fail++;
   // Floating-point noise below the broker-step tolerance remains exact.
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE,123,
                                    0.05000000001,0.05,0.01) !=
      EXEC_PREPARED_MARKET_DONE) fail++;

   // Transport failure and every non-DONE result fail closed.
   if(Exec_AssessPreparedOpenResult(false,false,TRADE_RETCODE_DONE,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE_PARTIAL,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_PLACED,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_REJECT,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_TIMEOUT,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_REQUOTE,123,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;

   // A missing deal, partial/different volume, nonfinite volume, or invalid
   // broker step cannot be reported as a completed prepared open.
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE,0,
                                    0.05,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE,123,
                                    0.04,0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE,123,
                                    MathSqrt(-1.0),0.05,0.01) !=
      EXEC_PREPARED_REFUSED) fail++;
   if(Exec_AssessPreparedOpenResult(false,true,TRADE_RETCODE_DONE,123,
                                    0.05,0.05,0.0) !=
      EXEC_PREPARED_REFUSED) fail++;
   return fail;
}

int OnInit()
{
   int fail=Exec_RunCheckedLotTests();
   if(fail == 0)
      Print("[PASS] Execution_CheckedLot_Test");
   else
      PrintFormat("[FAIL] Execution_CheckedLot_Test: %d",fail);
   return (fail == 0 ? INIT_SUCCEEDED : INIT_FAILED);
}

void OnTick() {}
