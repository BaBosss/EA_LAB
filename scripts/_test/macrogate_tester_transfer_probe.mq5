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
// MGTT_PROBE_CASE_END

#define LAB_MG_TESTER_EVIDENCE_QUAL
#include "../../ea_template/core/MacroGate_Core.mqh"
#include "../../ea_template/core/Execution.mqh"

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

bool ProbeLedgerEvidence()
{
   MGTT_RunBegin("MGTT_LEDGER_PROBE","MGTT_LEDGER_CFG",false);
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
   g_mgtt_deals[deals].entry_type=DEAL_ENTRY_IN;
   g_mgtt_deals[deals].volume=0.10;
   g_mgtt_deals[deals].entry_known=true;
   g_mgtt_deals[deals].emitted=false;
   MGTT_ReconcileDeals();

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
      Print("[MGTT_LEDGER_PROBE] CERTIFIED_CAGE_FAIL");
      return false;
   }
   Print("[MGTT_LEDGER_PROBE] CERTIFIED_COUNTS_PASS self_gate=0 no_order_send=1");

   // An unmatched synthetic fill must make completeness unavailable.
   int unmatched=ArraySize(g_mgtt_deals);
   ArrayResize(g_mgtt_deals,unmatched+1);
   g_mgtt_deals[unmatched].deal_id=777777;
   g_mgtt_deals[unmatched].order_id=888888;
   g_mgtt_deals[unmatched].entry_type=DEAL_ENTRY_IN;
   g_mgtt_deals[unmatched].volume=0.10;
   g_mgtt_deals[unmatched].entry_known=true;
   g_mgtt_deals[unmatched].emitted=false;
   MGTT_ReconcileDeals();
   if(MGTT_CompletenessCertified())
   {
      Print("[MGTT_LEDGER_PROBE] UNMATCHED_FAIL_CLOSED_FAIL");
      return false;
   }
   ArrayResize(g_mgtt_deals,unmatched);
   if(!MGTT_CompletenessCertified())
   {
      Print("[MGTT_LEDGER_PROBE] UNMATCHED_RESTORE_FAIL");
      return false;
   }

   // Duplicate OnTradeTransaction identity must also fail certification.
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
   if(g_mgtt_evidence_error_count!=1 || MGTT_CompletenessCertified())
   {
      Print("[MGTT_LEDGER_PROBE] DUPLICATE_FAIL_CLOSED_FAIL");
      return false;
   }

   bool am=false,ap=false;
   if(MGTT_ClassifyNative(false,TRADE_RETCODE_DONE,1,1,0.10,
                          "MARKET",0.10,0.01,am,ap)!="UNRESOLVED_RESULT")
      return false;
   if(MGTT_ClassifyNative(true,TRADE_RETCODE_DONE_PARTIAL,1,1,0.05,
                          "MARKET",0.10,0.01,am,ap)!="MARKET_ACCEPTED_PARTIAL")
      return false;

   Print("[MGTT_LEDGER_PROBE] ADVERSARIAL_FAIL_CLOSED_PASS");
   MGTT_RunEnd(0);
   return true;
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
   {
      Print("[MGTT_PROBE] REFUSE non-tester execution");
      return INIT_FAILED;
   }
   if(!ProbeHashVectors() || !ProbeParserSemantics())
   {
      Print("[MGTT_PROBE] SELFTEST_FAIL before loader");
      return INIT_FAILED;
   }
   MG_Setup(0.5,true,true,0,8760,168);
   if(!MGTT_LoadQualifiedRegime(MGTT_PROBE_FILENAME,false,
                                "MGTT_PROBE_BUILD",
                                "MGTT_PROBE_CONFIG"))
   {
      Print("[MGTT_PROBE] LOAD_FAIL_NO_TRADES");
      return INIT_FAILED;
   }
   if(!ProbeLedgerEvidence())
   {
      Print("[MGTT_PROBE] LEDGER_CAGE_FAIL_NO_TRADES");
      return INIT_FAILED;
   }
   Print("[MGTT_PROBE] LOAD_PASS_NO_TRADES");
   return INIT_SUCCEEDED;
}

void OnTick() {}
void OnDeinit(const int reason) {}
