//+------------------------------------------------------------------+
//| MacroGate tester-transfer qualification probe.                   |
//| No order path: imports the production loader/hash/parser helpers.|
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

// MGTT_PROBE_CASE_BEGIN -- qualify_transfer.ps1 replaces only this block in
// an order-owned frozen source copy. The canonical diagnostic defaults to the
// positive accepted REAL feed and declares exactly one tester dependency.
#property tester_file "REAL_FULL_2020_2025_macrogate_native.csv"
#define MGTT_PROBE_FILENAME "REAL_FULL_2020_2025_macrogate_native.csv"
#define MGTT_PROBE_EXPECTED_FILENAME "REAL_FULL_2020_2025_macrogate_native.csv"
#define MGTT_PROBE_EXPECTED_SHA256 "6aba7e1e7bd01e82469db580ae666c9903803c4fb8d206f4cc44f8aab8afbb2a"
#define MGTT_PROBE_EXPECTED_BYTES 73544
#define MGTT_PROBE_EXPECTED_ROWS 2192
#define MGTT_PROBE_EXPECTED_FIRST "2020.01.01 02:00"
#define MGTT_PROBE_EXPECTED_LAST "2025.12.31 02:00"
#define MGTT_PROBE_BUILD_RECEIPT "br-00000000000000000000000000000000"
#define MGTT_PROBE_CONFIG_FINGERPRINT "d3d548b77d96037fbee8a483bd25206f2d323600f2e00cf8ad012c7f566c2456"
#define MGTT_PROBE_SESSION_ID "MGTT-CANONICAL-TEMPLATE-NOT-A-RUN"
// MGTT_PROBE_CASE_END

#define LAB_MG_TESTER_EVIDENCE_QUAL
#define MGTT_LEDGER_PROBE_SYNTHETIC
#define LAB_ENTRY_15
#define LAB_ENTRY_TAG "15_ST03"
#include "../../ea_template/core/Inputs.mqh"
#include "../../ea_template/core/HedgeSafety.mqh"
#include "../../ea_template/core/InputSurface_gen.mqh"
#include "../../ea_template/core/Indicators.mqh"
#include "../../ea_template/core/Regime.mqh"
#include "../../ea_template/core/MacroGate_Core.mqh"
#include "../../ea_template/core/Execution.mqh"
#include "../../ea_template/core/RiskControl.mqh"
#include "../../ea_template/core/MoneyManagement.mqh"
#include "../../ea_template/core/ExitManager.mqh"
#include "../../ea_template/core/Stack.mqh"
#include "../../ea_template/core/Recovery.mqh"
#include "../../ea_template/core/Hedge.mqh"
#include "../../ea_template/core/Basket.mqh"
#include "../../ea_template/core/MiddlePath.mqh"
#include "../../ea_template/core/entries/Entry_ST03.mqh"
// Enumerate the same locked constants as Boss15 after all defining headers.
// No LabCore event handler or strategy initialization is imported or called.
#include "../../ea_template/core/LockedConstants_gen.mqh"

void ProbeLog(const string message)
{
   PrintFormat("[MGTT_PROBE] runtime_session=%s %s",g_mgtt_session,message);
}

bool ProbeHash(const string name,uchar &raw[],const string expected)
{
   string observed="";
   if(!MGTT_Sha256Hex(raw,observed) || observed!=expected)
   {
      PrintFormat("[MGTT_PROBE] HASH_FAIL name=%s bytes=%d expected=%s observed=%s",
                  name,ArraySize(raw),expected,observed);
      return false;
   }
   PrintFormat("[MGTT_PROBE] HASH_PASS name=%s bytes=%d sha256=%s",
               name,ArraySize(raw),observed);
   return true;
}

bool ProbeHashVectors()
{
   uchar abc[]={97,98,99};
   uchar lf[]={97,10};
   uchar crlf[]={97,13,10};
   uchar bom[]={239,187,191,97,10};
   uchar counted[]={0,1,2,3};
   if(!ProbeHash("ABC",abc,"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")) return false;
   if(!ProbeHash("RAW_LF",lf,"87428fc522803d31065e7bce3cf03fe475096631e5e07bbd7a0fde60c4cf25c7")) return false;
   if(!ProbeHash("RAW_CRLF",crlf,"8e4621379786ef42a4fec155cd525c291dd7db3c1fde3478522f4f61c03fd1bd")) return false;
   if(!ProbeHash("RAW_BOM",bom,"be4fccb045869c7ad387b9081a44cfd495b37efc020da4b44542de0d980c747f")) return false;
   if(!ProbeHash("RAW_COUNT_4",counted,"054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8")) return false;
   return true;
}

bool ProbeParserSemantics()
{
   mg_rowCount=0;
   mg_offsetHours=0;
   int skipped=0;
   datetime previous=0;
   bool ascending=true;
   MG_ParseRegimeDataLine("2020.01.01 02:00,UNKNOWN,0",skipped,previous,ascending);
   if(mg_rowCount!=1 || mg_rowState[0]!=MG_ST_UNKNOWN || skipped!=0 ||
      MG_RowAsOf(StringToTime("2020.01.01 02:00"))!=0)
      return false;
   // Equal timestamps remain accepted by the historical parser.
   MG_ParseRegimeDataLine("2020.01.01 02:00,NEUTRAL,0",skipped,previous,ascending);
   if(mg_rowCount!=2 || !ascending) return false;
   MG_ParseRegimeDataLine("not-a-time,RISK_OFF,0",skipped,previous,ascending);
   if(skipped!=1) return false;
   MG_ParseRegimeDataLine("2019.12.31 02:00,STRESS,0",skipped,previous,ascending);
   if(ascending) return false;
   Print("[MGTT_PROBE] PARSER_PASS UNKNOWN/equal/backwards/malformed semantics");
   return true;
}

bool ProbeLedgerPrimary()
{
   if(!g_mgtt_run_started) return false;

   // BASE/self-gate-off evidence must still be active.
   long intent_id=MGTT_StrategyIntentBegin(1);
   long blocked_attempt=MGTT_ExecutionBegin("MARKET",1,0.10);
   MGTT_PreSubmitTerminal(blocked_attempt,"MACRO");
   MGTT_StrategyIntentEnd(intent_id);

   // Synthetic rejected native request: no OrderSend is invoked by this probe.
   long rejected_attempt=MGTT_ExecutionBegin("MARKET",1,0.10);
   long rejected_submit=MGTT_SubmitBegin(rejected_attempt,"MARKET",0.10);
   MqlTradeRequest rejected_request={};
   rejected_request.action=TRADE_ACTION_DEAL;
   long rejected_native=MGTT_NativeBegin(rejected_request);
   MqlTradeResult rejected_result={};
   rejected_result.retcode=TRADE_RETCODE_REJECT;
   MGTT_NativeResult(rejected_native,false,rejected_result,1234);
   MGTT_SubmitReturn(rejected_submit,false,rejected_result.retcode,rejected_result.volume);
   MGTT_ExecutionEnd(rejected_attempt,"SUBMIT_RETURN_FALSE");

   // Synthetic accepted pending request followed by a separately correlated fill.
   long pending_attempt=MGTT_ExecutionBegin("PENDING",1,0.10);
   long pending_submit=MGTT_SubmitBegin(pending_attempt,"PENDING",0.10);
   MqlTradeRequest pending_request={};
   pending_request.action=TRADE_ACTION_PENDING;
   long pending_native=MGTT_NativeBegin(pending_request);
   MqlTradeResult pending_result={};
   pending_result.retcode=TRADE_RETCODE_PLACED;
   pending_result.order=123456;
   MGTT_NativeResult(pending_native,true,pending_result,0);
   MGTT_SubmitReturn(pending_submit,true,pending_result.retcode,pending_result.volume);
   MGTT_ExecutionEnd(pending_attempt,"PENDING_RETURN_TRUE");

   int deals=ArraySize(g_mgtt_deals);
   ArrayResize(g_mgtt_deals,deals+1);
   g_mgtt_deals[deals].deal_id=654321;
   g_mgtt_deals[deals].order_id=123456;
   g_mgtt_deals[deals].symbol=_Symbol;
   g_mgtt_deals[deals].deal_type=DEAL_TYPE_BUY;
   g_mgtt_deals[deals].entry_type=DEAL_ENTRY_IN;
   g_mgtt_deals[deals].volume=0.10;
   g_mgtt_deals[deals].entry_known=true;
   g_mgtt_deals[deals].emitted=false;
   g_mgtt_deals[deals].history_verified=true;
   g_mgtt_deals[deals].callback_count=1;
   MGTT_ReconcileDeals();
   if(!MGTT_ProbeCertifyNativeFill(pending_native,0.10) || !MGTT_FinalizeFillCoverage())
      return false;

   if(g_mgtt_strategy_intent_total!=1 ||
      g_mgtt_execution_entry_total!=3 ||
      g_mgtt_pre_submit_terminal_total!=1 ||
      g_mgtt_macro_block_total!=1 ||
      g_mgtt_submit_total!=2 ||
      g_mgtt_native_request_total!=2 ||
      g_mgtt_accepted_request_total!=1 ||
      g_mgtt_rejected_request_total!=1 ||
      g_mgtt_unresolved_request_total!=0 ||
      g_mgtt_entry_fill_total!=1 ||
      !MGTT_CompletenessCertified())
   {
      ProbeLog("CERTIFIED_CAGE_FAIL");
      return false;
   }
   ProbeLog("CERTIFIED_COUNTS_PASS self_gate=0 no_order_send=1 history_proof=SYNTHETIC_PASSIVE_CAGE");

   // Identical repeated callbacks are idempotent and never double-count fills.
   MqlTradeTransaction trans={};
   MqlTradeRequest request={};
   MqlTradeResult result={};
   trans.type=TRADE_TRANSACTION_DEAL_ADD;
   trans.deal=654321;
   trans.order=123456;
   trans.symbol=_Symbol;
   trans.deal_type=DEAL_TYPE_BUY;
   trans.volume=0.10;
   MGTT_OnTradeTransaction(trans,request,result);
   if(g_mgtt_evidence_error_count!=0 || g_mgtt_entry_fill_total!=1 ||
      !MGTT_CompletenessCertified())
   {
      ProbeLog("IDEMPOTENT_DEAL_FAIL");
      return false;
   }
   ProbeLog("IDEMPOTENT_DEAL_PASS count_once=1");

   MGTT_RunEnd(0);
   return true;
}

bool ProbeDuplicateTerminals()
{
   MGTT_RunBegin(MGTT_PROBE_BUILD_RECEIPT,MGTT_PROBE_CONFIG_FINGERPRINT,false,
                 MGTT_PROBE_SESSION_ID+"-DUPTERM");
   long attempt=MGTT_ExecutionBegin("MARKET",1,0.10);
   long submit=MGTT_SubmitBegin(attempt,"MARKET",0.10);
   MqlTradeRequest request={}; request.action=TRADE_ACTION_DEAL;
   long native_id=MGTT_NativeBegin(request);
   MqlTradeResult result={}; result.retcode=TRADE_RETCODE_REJECT;
   MGTT_NativeResult(native_id,false,result,1);
   MGTT_NativeResult(native_id,false,result,1);
   MGTT_SubmitReturn(submit,false,result.retcode,0.0);
   MGTT_SubmitReturn(submit,false,result.retcode,0.0);
   MGTT_ExecutionEnd(attempt,"FIRST");
   MGTT_ExecutionEnd(attempt,"SECOND");
   if(g_mgtt_evidence_error_count!=3 || MGTT_CompletenessCertified()) return false;
   ProbeLog("DUPLICATE_TERMINALS_FAIL_CLOSED_PASS execution_end=2 submit_return=2 native_result=2");
   MGTT_RunEnd(0);
   return true;
}

bool ProbeMissingFillCoverage()
{
   MGTT_RunBegin(MGTT_PROBE_BUILD_RECEIPT,MGTT_PROBE_CONFIG_FINGERPRINT,false,
                 MGTT_PROBE_SESSION_ID+"-MISSINGFILL");
   long attempt=MGTT_ExecutionBegin("PENDING",1,0.10);
   long submit=MGTT_SubmitBegin(attempt,"PENDING",0.10);
   MqlTradeRequest request={}; request.action=TRADE_ACTION_PENDING;
   long native_id=MGTT_NativeBegin(request);
   MqlTradeResult result={}; result.retcode=TRADE_RETCODE_PLACED; result.order=987654;
   MGTT_NativeResult(native_id,true,result,0);
   MGTT_SubmitReturn(submit,true,result.retcode,0.0);
   MGTT_ExecutionEnd(attempt,"PENDING_RETURN_TRUE");
   if(MGTT_CompletenessCertified()) return false;
   ProbeLog("MISSING_PARTIAL_PENDING_FILL_FAIL_CLOSED_PASS");
   MGTT_RunEnd(0);
   return true;
}

bool ProbeRepeatedDealContent()
{
   MGTT_RunBegin(MGTT_PROBE_BUILD_RECEIPT,MGTT_PROBE_CONFIG_FINGERPRINT,false,
                 MGTT_PROBE_SESSION_ID+"-DEALCONTENT");
   MqlTradeTransaction trans={}; MqlTradeRequest request={}; MqlTradeResult result={};
   trans.type=TRADE_TRANSACTION_DEAL_ADD; trans.deal=4444; trans.order=3333;
   trans.symbol=_Symbol; trans.deal_type=DEAL_TYPE_BUY; trans.volume=0.10;
   MGTT_OnTradeTransaction(trans,request,result);
   MGTT_OnTradeTransaction(trans,request,result);
   if(g_mgtt_evidence_error_count!=0 || ArraySize(g_mgtt_deals)!=1) return false;
   trans.volume=0.20;
   MGTT_OnTradeTransaction(trans,request,result);
   if(g_mgtt_evidence_error_count!=1 || MGTT_CompletenessCertified()) return false;
   ProbeLog("CONTRADICTORY_DEAL_FAIL_CLOSED_PASS identical_counted_once=1");
   MGTT_RunEnd(0);
   return true;
}

bool ProbeClassification()
{
   bool am=false,ap=false;
   uint ambiguous[]={TRADE_RETCODE_ERROR,TRADE_RETCODE_ORDER_CHANGED,
                     TRADE_RETCODE_NO_CHANGES,TRADE_RETCODE_LOCKED,
                     TRADE_RETCODE_POSITION_CLOSED};
   for(int i=0;i<ArraySize(ambiguous);i++)
   {
      if(MGTT_ClassifyNative(false,ambiguous[i],0,0,0.0,
                            "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT") return false;
      if(MGTT_ClassifyNative(true,ambiguous[i],0,0,0.0,
                            "PENDING",0.10,0.01,am,ap)!="UNRESOLVED_RESULT") return false;
   }
   if(MGTT_ClassifyNative(false,99999,0,0,0.0,
                          "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT") return false;
   if(MGTT_ClassifyNative(false,TRADE_RETCODE_TIMEOUT,0,0,0.0,
                          "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT") return false;
   if(MGTT_ClassifyNative(false,TRADE_RETCODE_CONNECTION,0,0,0.0,
                          "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT") return false;
   if(MGTT_ClassifyNative(false,TRADE_RETCODE_REJECT,0,0,0.0,
                          "MARKET",0.10,0.01,am,ap)!="REQUEST_REJECTED") return false;
   if(MGTT_ClassifyNative(true,TRADE_RETCODE_REJECT,0,0,0.0,
                          "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT") return false;

   if(MGTT_ClassifyNative(false,TRADE_RETCODE_DONE,1,1,0.10,
                          "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT")
      return false;
   if(MGTT_ClassifyNative(true,TRADE_RETCODE_DONE_PARTIAL,1,1,0.05,
                          "MARKET",0.10,0.01,am,ap)!="MARKET_ACCEPTED_PARTIAL")
      return false;

   ProbeLog("CLASSIFICATION_FAIL_CLOSED_PASS unknown_false=UNRESOLVED known_reject=REQUEST_REJECTED");
   return true;
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print("[MGTT_PROBE] REFUSE non-tester execution");
      return INIT_FAILED;
   }
   string actual_config=CFG_Fingerprint();
   if(CFG_BuildTag()!="LAB_ENTRY_15" || actual_config=="" ||
      actual_config!=MGTT_PROBE_CONFIG_FINGERPRINT)
   {
      PrintFormat("[MGTT_PROBE] CONFIG_MISMATCH expected=%s actual=%s build=%s",
                  MGTT_PROBE_CONFIG_FINGERPRINT,actual_config,CFG_BuildTag());
      return INIT_FAILED;
   }
   PrintFormat("[CFG] input surface: build=%s keys=%d scope=%s effective_config_hash=%s",
               CFG_BuildTag(),CFG_SurfaceKeys(),CFG_FP_SCOPE,actual_config);
   if(!ProbeHashVectors() || !ProbeParserSemantics())
   {
      Print("[MGTT_PROBE] SELFTEST_FAIL before loader");
      return INIT_FAILED;
   }
   MGTT_RunBegin(MGTT_PROBE_BUILD_RECEIPT,actual_config,false,
                 MGTT_PROBE_SESSION_ID);
   MG_Setup(0.5,true,true,0,8760,168);
   if(!MGTT_LoadQualifiedRegime(MGTT_PROBE_FILENAME,false,
                                MGTT_PROBE_BUILD_RECEIPT,
                                actual_config,
                                MGTT_PROBE_SESSION_ID))
   {
      Print("[MGTT_PROBE] LOAD_FAIL_NO_TRADES");
      return INIT_FAILED;
   }
   if(!ProbeLedgerPrimary() || !ProbeDuplicateTerminals() ||
      !ProbeMissingFillCoverage() || !ProbeRepeatedDealContent() ||
      !ProbeClassification())
   {
      Print("[MGTT_PROBE] LEDGER_CAGE_FAIL_NO_TRADES");
      return INIT_FAILED;
   }
   ProbeLog("LOAD_PASS_NO_TRADES ADVERSARIAL_FAIL_CLOSED_PASS");
   return INIT_SUCCEEDED;
}

void OnTick() {}
void OnDeinit(const int reason)
{
   if(g_mgtt_run_started && !g_mgtt_run_ended) MGTT_RunEnd(reason);
}
