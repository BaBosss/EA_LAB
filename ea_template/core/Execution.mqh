//+------------------------------------------------------------------+
//| Execution.mqh (V2) - ONLY place that touches CTrade / OrderSend. |
//|  DryRun=true logs intents. Lot clamped to RC_MaxLot here (final).|
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_EXECUTION_MQH
#define BOSS_LAB_EXECUTION_MQH
#include "Inputs.mqh"
#include <Trade/Trade.mqh>

#ifdef LAB_MG_TESTER_EVIDENCE_QUAL
// Passive tester-only all-attempt evidence. The compile flag alone is not
// enough: every entry point also requires MQL_TESTER, so non-tester behavior
// takes the original path below. Request acceptance and later fills are
// deliberately separate units.
#define MGTT_VOLUME_TOLERANCE_STEP_MULT 0.00000001

struct MGTT_AttemptRecord
{
   long id;
   int  end_count;
   int  submit_count;
};
struct MGTT_SubmitRecord
{
   long id;
   long attempt_id;
   int  return_count;
   int  native_count;
};
struct MGTT_NativeRecord
{
   long  id;
   long  submit_id;
   string path;
   double requested_volume;
   double volume_step;
   ulong order_id;
   ulong result_deal_id;
   int   result_count;
   string category;
   bool  accepted_request;
   bool  fill_finalized;
   bool  fill_complete;
   double complete_entry_volume;
};
struct MGTT_DealRecord
{
   ulong  deal_id;
   ulong  order_id;
   string symbol;
   long   deal_type;
   long   entry_type;
   double volume;
   bool   entry_known;
   bool   emitted;
   bool   history_verified;
   int    callback_count;
};

bool   g_mgtt_run_started=false;
bool   g_mgtt_run_ended=false;
string g_mgtt_session="";
long   g_mgtt_sequence=0;
long   g_mgtt_next_intent=0;
long   g_mgtt_active_intent=0;
long   g_mgtt_next_attempt=0;
long   g_mgtt_next_submit=0;
long   g_mgtt_next_native=0;
bool   g_mgtt_open_context=false;
long   g_mgtt_context_attempt=0;
long   g_mgtt_context_submit=0;
string g_mgtt_context_path="";
double g_mgtt_context_volume=0.0;
double g_mgtt_context_step=0.0;
int    g_mgtt_context_native_count=0;

long g_mgtt_strategy_intent_total=0;
long g_mgtt_execution_entry_total=0;
long g_mgtt_pre_submit_terminal_total=0;
long g_mgtt_macro_block_total=0;
long g_mgtt_submit_total=0;
long g_mgtt_native_request_total=0;
long g_mgtt_accepted_request_total=0;
long g_mgtt_rejected_request_total=0;
long g_mgtt_unresolved_request_total=0;
long g_mgtt_entry_fill_total=0;
long g_mgtt_entry_inout_fill_total=0;
long g_mgtt_evidence_error_count=0;
string g_mgtt_unresolved_ids="NONE";
bool   g_mgtt_fill_coverage_finalized=false;

MGTT_AttemptRecord g_mgtt_attempts[];
MGTT_SubmitRecord  g_mgtt_submits[];
MGTT_NativeRecord  g_mgtt_natives[];
MGTT_DealRecord    g_mgtt_deals[];

bool MGTT_IsActive()
{
   return (bool)MQLInfoInteger(MQL_TESTER);
}

void MGTT_Emit(const string event_name,const string fields)
{
   if(!MGTT_IsActive() || !g_mgtt_run_started || g_mgtt_run_ended) return;
   g_mgtt_sequence++;
   PrintFormat("[MGTT] event=%s session=%s seq=%I64d %s",
               event_name,g_mgtt_session,g_mgtt_sequence,fields);
}

void MGTT_EvidenceError(const string event_name,const string fields)
{
   g_mgtt_evidence_error_count++;
   MGTT_Emit(event_name,fields);
}

void MGTT_RunBegin(const string build_receipt,const string config_fingerprint,
                   const bool self_gate,const string frozen_session="")
{
   if(!MGTT_IsActive()) return;
   if(g_mgtt_run_started && !g_mgtt_run_ended)
   {
      MGTT_EvidenceError("DUPLICATE_RUN_BEGIN","reason=ACTIVE_SESSION");
      return;
   }
   g_mgtt_run_started=true;
   g_mgtt_run_ended=false;
   g_mgtt_session=(frozen_session!="" ? frozen_session :
                   StringFormat("MGTT-%I64d-%u",(long)TimeLocal(),GetTickCount()));
   g_mgtt_sequence=0;
   g_mgtt_next_intent=0;
   g_mgtt_active_intent=0;
   g_mgtt_next_attempt=0;
   g_mgtt_next_submit=0;
   g_mgtt_next_native=0;
   g_mgtt_open_context=false;
   g_mgtt_context_attempt=0;
   g_mgtt_context_submit=0;
   g_mgtt_context_path="";
   g_mgtt_context_volume=0.0;
   g_mgtt_context_step=0.0;
   g_mgtt_context_native_count=0;
   g_mgtt_strategy_intent_total=0;
   g_mgtt_execution_entry_total=0;
   g_mgtt_pre_submit_terminal_total=0;
   g_mgtt_macro_block_total=0;
   g_mgtt_submit_total=0;
   g_mgtt_native_request_total=0;
   g_mgtt_accepted_request_total=0;
   g_mgtt_rejected_request_total=0;
   g_mgtt_unresolved_request_total=0;
   g_mgtt_entry_fill_total=0;
   g_mgtt_entry_inout_fill_total=0;
   g_mgtt_evidence_error_count=0;
   g_mgtt_unresolved_ids="NONE";
   g_mgtt_fill_coverage_finalized=false;
   ArrayResize(g_mgtt_attempts,0);
   ArrayResize(g_mgtt_submits,0);
   ArrayResize(g_mgtt_natives,0);
   ArrayResize(g_mgtt_deals,0);
   MGTT_Emit("RUN_BEGIN",StringFormat("build=%s config=%s feature=LAB_MG_TESTER_EVIDENCE_QUAL MG_SelfGate=%d volume_tolerance=step_x_1e-8",
             build_receipt,config_fingerprint,(self_gate?1:0)));
}

long MGTT_StrategyIntentBegin(const int direction)
{
   if(!MGTT_IsActive() || !g_mgtt_run_started) return 0;
   long id=++g_mgtt_next_intent;
   g_mgtt_active_intent=id;
   g_mgtt_strategy_intent_total++;
   MGTT_Emit("STRATEGY_INTENT",StringFormat("intent_id=%I64d direction=%d",id,direction));
   return id;
}

void MGTT_StrategyIntentRefusal(const long id,const string reason)
{
   if(id<=0) return;
   MGTT_Emit("UPSTREAM_REFUSAL",StringFormat("intent_id=%I64d reason=%s",id,reason));
   if(g_mgtt_active_intent==id) g_mgtt_active_intent=0;
}

void MGTT_StrategyIntentEnd(const long id)
{
   if(g_mgtt_active_intent==id) g_mgtt_active_intent=0;
}

long MGTT_ExecutionBegin(const string path,const int direction,
                         const double requested_volume)
{
   long id=++g_mgtt_next_attempt;
   int n=ArraySize(g_mgtt_attempts);
   ArrayResize(g_mgtt_attempts,n+1);
   g_mgtt_attempts[n].id=id;
   g_mgtt_attempts[n].end_count=0;
   g_mgtt_attempts[n].submit_count=0;
   g_mgtt_execution_entry_total++;
   long parent=g_mgtt_active_intent;
   MGTT_Emit("EXECUTION_ENTRY",StringFormat("attempt_id=%I64d path=%s parent_intent=%I64d direction=%d requested_volume=%.8f",
             id,path,parent,direction,requested_volume));
   if(parent>0)
      MGTT_Emit("EXECUTION_LINK",StringFormat("intent_id=%I64d attempt_id=%I64d",parent,id));
   return id;
}

int MGTT_AttemptIndex(const long id)
{
   for(int i=ArraySize(g_mgtt_attempts)-1;i>=0;i--)
      if(g_mgtt_attempts[i].id==id) return i;
   return -1;
}

void MGTT_ExecutionEnd(const long attempt_id,const string terminal_status)
{
   int i=MGTT_AttemptIndex(attempt_id);
   if(i<0)
      MGTT_EvidenceError("UNKNOWN_EXECUTION_END",StringFormat("attempt_id=%I64d",attempt_id));
   else
   {
      g_mgtt_attempts[i].end_count++;
      if(g_mgtt_attempts[i].end_count!=1)
         MGTT_EvidenceError("DUPLICATE_EXECUTION_END",StringFormat("attempt_id=%I64d count=%d",attempt_id,g_mgtt_attempts[i].end_count));
   }
   MGTT_Emit("EXECUTION_END",StringFormat("attempt_id=%I64d terminal_status=%s",
              attempt_id,terminal_status));
}

void MGTT_PreSubmitTerminal(const long attempt_id,const string reason)
{
   g_mgtt_pre_submit_terminal_total++;
   if(reason=="MACRO") g_mgtt_macro_block_total++;
   MGTT_Emit("PRE_SUBMIT_TERMINAL",StringFormat("attempt_id=%I64d reason=%s",
             attempt_id,reason));
   MGTT_ExecutionEnd(attempt_id,reason);
}

long MGTT_SubmitBegin(const long attempt_id,const string path,
                      const double normalized_volume)
{
   long id=++g_mgtt_next_submit;
   int n=ArraySize(g_mgtt_submits);
   ArrayResize(g_mgtt_submits,n+1);
   g_mgtt_submits[n].id=id;
   g_mgtt_submits[n].attempt_id=attempt_id;
   g_mgtt_submits[n].return_count=0;
   g_mgtt_submits[n].native_count=0;
   int ai=MGTT_AttemptIndex(attempt_id);
   if(ai>=0) g_mgtt_attempts[ai].submit_count++;
   g_mgtt_submit_total++;
   g_mgtt_open_context=true;
   g_mgtt_context_attempt=attempt_id;
   g_mgtt_context_submit=id;
   g_mgtt_context_path=path;
   g_mgtt_context_volume=normalized_volume;
   g_mgtt_context_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   g_mgtt_context_native_count=0;
   MGTT_Emit("SUBMIT_CALL",StringFormat("attempt_id=%I64d submit_id=%I64d normalized_volume=%.8f",
             attempt_id,id,normalized_volume));
   return id;
}

int MGTT_SubmitIndex(const long id)
{
   for(int i=ArraySize(g_mgtt_submits)-1;i>=0;i--)
      if(g_mgtt_submits[i].id==id) return i;
   return -1;
}

bool MGTT_IsKnownNonAcceptanceRetcode(const uint retcode)
{
   // Enumerate documented non-acceptance values. Numeric gaps (for example
   // 10005 and 10037) are unknown, not silently folded into rejection.
   switch(retcode)
   {
      case 10004:
      case 10006:
      case 10007:
      case 10011:
      case 10012:
      case 10013:
      case 10014:
      case 10015:
      case 10016:
      case 10017:
      case 10018:
      case 10019:
      case 10020:
      case 10021:
      case 10022:
      case 10023:
      case 10024:
      case 10025:
      case 10026:
      case 10027:
      case 10028:
      case 10029:
      case 10030:
      case 10031:
      case 10032:
      case 10033:
      case 10034:
      case 10035:
      case 10036:
      case 10038:
      case 10039:
      case 10040:
      case 10041:
      case 10042:
      case 10043:
      case 10044:
      case 10045:
      case 10046:
         return true;
   }
   return false;
}

bool MGTT_IsAmbiguousNonAcceptanceRetcode(const uint retcode)
{
   // Processing/state observations are not proof of a terminal rejection.
   // Keep them unresolved even when the transport boolean is false.
   return (retcode==TRADE_RETCODE_TIMEOUT || retcode==TRADE_RETCODE_CONNECTION ||
           retcode==TRADE_RETCODE_ERROR || retcode==TRADE_RETCODE_ORDER_CHANGED ||
           retcode==TRADE_RETCODE_NO_CHANGES || retcode==TRADE_RETCODE_LOCKED ||
           retcode==TRADE_RETCODE_POSITION_CLOSED);
}

string MGTT_ClassifyNative(const bool transport_ok,const uint retcode,
                           const ulong order_id,const ulong deal_id,
                           const double result_volume,const string path,
                           const double requested_volume,const double volume_step,
                           bool &accepted_market,bool &accepted_pending)
{
   accepted_market=false;
   accepted_pending=false;
   bool accepted_code=(retcode==TRADE_RETCODE_DONE ||
                       retcode==TRADE_RETCODE_DONE_PARTIAL ||
                       retcode==TRADE_RETCODE_PLACED);
   bool positive_identity=(order_id>0 || deal_id>0);
   bool positive_volume=(MathIsValidNumber(result_volume) && result_volume>0.0);
   if(!transport_ok)
   {
      if(accepted_code || positive_identity || positive_volume ||
         MGTT_IsAmbiguousNonAcceptanceRetcode(retcode) ||
         !MGTT_IsKnownNonAcceptanceRetcode(retcode))
         return "UNRESOLVED_RESULT";
      return "REQUEST_REJECTED";
   }

   // A true transport boolean paired with any documented non-acceptance
   // retcode is contradictory. Timeout/connection remain ambiguous under
   // either boolean. Neither combination can prove a clean rejection.
   if(MGTT_IsKnownNonAcceptanceRetcode(retcode))
      return "UNRESOLVED_RESULT";

   double tolerance=MathMax(1.0e-12,volume_step*MGTT_VOLUME_TOLERANCE_STEP_MULT);
   if(path=="MARKET")
   {
      if(retcode==TRADE_RETCODE_DONE && positive_identity &&
         MathIsValidNumber(result_volume) && result_volume>0.0 &&
         MathIsValidNumber(requested_volume) && requested_volume>0.0 &&
         MathIsValidNumber(volume_step) && volume_step>0.0 &&
         MathAbs(result_volume-requested_volume)<=tolerance)
      {
         accepted_market=true;
         return "MARKET_ACCEPTED_DONE";
      }
      if(retcode==TRADE_RETCODE_DONE_PARTIAL && positive_identity &&
         MathIsValidNumber(result_volume) && result_volume>0.0 &&
         MathIsValidNumber(requested_volume) && requested_volume>0.0 &&
         MathIsValidNumber(volume_step) && volume_step>0.0 &&
         result_volume<=requested_volume+tolerance)
      {
         accepted_market=true;
         return "MARKET_ACCEPTED_PARTIAL";
      }
      if(retcode==TRADE_RETCODE_PLACED && order_id>0)
      {
         accepted_pending=true;
         return "MARKET_ACCEPTED_PENDING";
      }
      if(accepted_code) return "UNRESOLVED_RESULT";
   }
   else if(path=="PENDING")
   {
      if((retcode==TRADE_RETCODE_PLACED || retcode==TRADE_RETCODE_DONE) &&
         order_id>0)
      {
         accepted_pending=true;
         return "PENDING_PLACED";
      }
      if(accepted_code) return "UNRESOLVED_RESULT";
   }
   return "UNRESOLVED_RESULT";
}

int MGTT_DealIndex(const ulong deal_id)
{
   for(int i=0;i<ArraySize(g_mgtt_deals);i++)
      if(g_mgtt_deals[i].deal_id==deal_id) return i;
   return -1;
}

void MGTT_ReconcileDeals()
{
   for(int d=0;d<ArraySize(g_mgtt_deals);d++)
   {
      if(g_mgtt_deals[d].emitted) continue;
      if(!g_mgtt_deals[d].entry_known)
      {
         long entry_value=0;
         if(HistoryDealGetInteger(g_mgtt_deals[d].deal_id,DEAL_ENTRY,entry_value))
         {
            g_mgtt_deals[d].entry_type=entry_value;
            g_mgtt_deals[d].entry_known=true;
         }
         else continue;
      }
      if(g_mgtt_deals[d].entry_type!=DEAL_ENTRY_IN &&
         g_mgtt_deals[d].entry_type!=DEAL_ENTRY_INOUT)
      {
         g_mgtt_deals[d].emitted=true;
         continue;
      }
      for(int n=0;n<ArraySize(g_mgtt_natives);n++)
      {
         bool matched=(g_mgtt_deals[d].order_id>0 &&
                       g_mgtt_deals[d].order_id==g_mgtt_natives[n].order_id) ||
                      (g_mgtt_deals[d].deal_id>0 &&
                       g_mgtt_deals[d].deal_id==g_mgtt_natives[n].result_deal_id);
         if(!matched) continue;
         g_mgtt_entry_fill_total++;
         string entry_name="IN";
         if(g_mgtt_deals[d].entry_type==DEAL_ENTRY_INOUT)
         {
            entry_name="INOUT";
            g_mgtt_entry_inout_fill_total++;
         }
          g_mgtt_deals[d].emitted=true;
         MGTT_Emit("FILL_OBSERVED",StringFormat("order_id=%I64u deal_id=%I64u entry_type=%s volume=%.8f net_new_exposure=UNAVAILABLE",
                   g_mgtt_deals[d].order_id,g_mgtt_deals[d].deal_id,
                   entry_name,g_mgtt_deals[d].volume));
         break;
      }
   }
}

int MGTT_NativeIndex(const long id)
{
   for(int i=ArraySize(g_mgtt_natives)-1;i>=0;i--)
      if(g_mgtt_natives[i].id==id) return i;
   return -1;
}

long MGTT_NativeBegin(const MqlTradeRequest &request)
{
   long id=++g_mgtt_next_native;
   g_mgtt_native_request_total++;
   g_mgtt_context_native_count++;
   int si=MGTT_SubmitIndex(g_mgtt_context_submit);
   if(si>=0) g_mgtt_submits[si].native_count++;
   int n=ArraySize(g_mgtt_natives);
   ArrayResize(g_mgtt_natives,n+1);
   g_mgtt_natives[n].id=id;
   g_mgtt_natives[n].submit_id=g_mgtt_context_submit;
   g_mgtt_natives[n].path=g_mgtt_context_path;
   g_mgtt_natives[n].requested_volume=g_mgtt_context_volume;
   g_mgtt_natives[n].volume_step=g_mgtt_context_step;
   g_mgtt_natives[n].order_id=0;
   g_mgtt_natives[n].result_deal_id=0;
   g_mgtt_natives[n].result_count=0;
   g_mgtt_natives[n].category="UNRESOLVED_RESULT";
   g_mgtt_natives[n].accepted_request=false;
   g_mgtt_natives[n].fill_finalized=false;
   g_mgtt_natives[n].fill_complete=false;
   g_mgtt_natives[n].complete_entry_volume=0.0;
   MGTT_Emit("NATIVE_SEND_BEGIN",StringFormat("submit_id=%I64d native_id=%I64d action=%d",
             g_mgtt_context_submit,id,(int)request.action));
   return id;
}

void MGTT_NativeResult(const long native_id,const bool transport_ok,
                       const MqlTradeResult &result,const int last_error)
{
   int ni=MGTT_NativeIndex(native_id);
   if(ni<0)
   {
      MGTT_EvidenceError("UNKNOWN_NATIVE_SEND_RESULT",StringFormat("native_id=%I64d",native_id));
      return;
   }
   g_mgtt_natives[ni].result_count++;
   if(g_mgtt_natives[ni].result_count!=1)
   {
      MGTT_EvidenceError("DUPLICATE_NATIVE_SEND_RESULT",StringFormat("native_id=%I64d count=%d",native_id,g_mgtt_natives[ni].result_count));
      return;
   }
   bool accepted_market=false,accepted_pending=false;
   string category=MGTT_ClassifyNative(transport_ok,result.retcode,
       result.order,result.deal,result.volume,g_mgtt_natives[ni].path,
       g_mgtt_natives[ni].requested_volume,g_mgtt_natives[ni].volume_step,
       accepted_market,accepted_pending);
   if(category=="REQUEST_REJECTED") g_mgtt_rejected_request_total++;
   else if(category=="UNRESOLVED_RESULT")
   {
      g_mgtt_unresolved_request_total++;
      if(g_mgtt_unresolved_ids=="NONE")
         g_mgtt_unresolved_ids=IntegerToString(native_id);
      else
         g_mgtt_unresolved_ids+=","+IntegerToString(native_id);
   }
   else g_mgtt_accepted_request_total++;

   g_mgtt_natives[ni].order_id=result.order;
   g_mgtt_natives[ni].result_deal_id=result.deal;
   g_mgtt_natives[ni].category=category;
   g_mgtt_natives[ni].accepted_request=(accepted_market || accepted_pending);
   MGTT_Emit("NATIVE_SEND_RESULT",StringFormat("native_id=%I64d transport_bool=%d retcode=%u last_error=%d order_id=%I64u deal_id=%I64u result_volume=%.8f normalized_requested_volume=%.8f volume_step=%.8f category=%s rejected_timeout_does_not_prove_no_later_fill=1 caller_error_preservation=NOT_CLAIMED",
              native_id,(transport_ok?1:0),result.retcode,last_error,
              result.order,result.deal,result.volume,g_mgtt_natives[ni].requested_volume,
              g_mgtt_natives[ni].volume_step,category));
   MGTT_ReconcileDeals();
}

void MGTT_SubmitReturn(const long submit_id,const bool library_bool,
                       const uint retcode,const double result_volume)
{
   int si=MGTT_SubmitIndex(submit_id);
   if(si<0)
      MGTT_EvidenceError("UNKNOWN_SUBMIT_RETURN",StringFormat("submit_id=%I64d",submit_id));
   else
   {
      g_mgtt_submits[si].return_count++;
      if(g_mgtt_submits[si].return_count!=1)
         MGTT_EvidenceError("DUPLICATE_SUBMIT_RETURN",StringFormat("submit_id=%I64d count=%d",submit_id,g_mgtt_submits[si].return_count));
   }
   MGTT_Emit("SUBMIT_RETURN",StringFormat("submit_id=%I64d library_bool=%d retcode=%u volume=%.8f native_call_count=%d",
             submit_id,(library_bool?1:0),retcode,result_volume,
             g_mgtt_context_native_count));
   g_mgtt_open_context=false;
}

void MGTT_OnTradeTransaction(const MqlTradeTransaction &trans,
                             const MqlTradeRequest &request,
                             const MqlTradeResult &result)
{
   if(!MGTT_IsActive() || !g_mgtt_run_started || g_mgtt_run_ended) return;
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(trans.symbol!=_Symbol) return;
   if(trans.deal_type!=DEAL_TYPE_BUY && trans.deal_type!=DEAL_TYPE_SELL) return;
   int existing=MGTT_DealIndex(trans.deal);
   if(existing>=0)
   {
      double tolerance=MathMax(1.0e-12,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*MGTT_VOLUME_TOLERANCE_STEP_MULT);
      bool identical=(g_mgtt_deals[existing].order_id==trans.order &&
                      g_mgtt_deals[existing].symbol==trans.symbol &&
                      g_mgtt_deals[existing].deal_type==(long)trans.deal_type &&
                      MathAbs(g_mgtt_deals[existing].volume-trans.volume)<=tolerance);
      g_mgtt_deals[existing].callback_count++;
      if(identical)
         MGTT_Emit("DUPLICATE_DEAL_IDEMPOTENT",StringFormat("order_id=%I64u deal_id=%I64u callback_count=%d",trans.order,trans.deal,g_mgtt_deals[existing].callback_count));
      else
         MGTT_EvidenceError("CONTRADICTORY_DEAL",StringFormat("order_id=%I64u deal_id=%I64u",trans.order,trans.deal));
      return;
   }
   int n=ArraySize(g_mgtt_deals);
   ArrayResize(g_mgtt_deals,n+1);
   g_mgtt_deals[n].deal_id=trans.deal;
   g_mgtt_deals[n].order_id=trans.order;
   g_mgtt_deals[n].symbol=trans.symbol;
   g_mgtt_deals[n].deal_type=(long)trans.deal_type;
   g_mgtt_deals[n].entry_type=-1;
   g_mgtt_deals[n].volume=trans.volume;
   g_mgtt_deals[n].entry_known=false;
   g_mgtt_deals[n].emitted=false;
   g_mgtt_deals[n].history_verified=false;
   g_mgtt_deals[n].callback_count=1;
   MGTT_ReconcileDeals();
}

bool MGTT_OrderStateIsActive(const long state)
{
   return (state==ORDER_STATE_STARTED || state==ORDER_STATE_PLACED ||
           state==ORDER_STATE_PARTIAL || state==ORDER_STATE_REQUEST_ADD ||
           state==ORDER_STATE_REQUEST_MODIFY || state==ORDER_STATE_REQUEST_CANCEL);
}

bool MGTT_FinalizeOneNativeFill(const int ni)
{
   if(!g_mgtt_natives[ni].accepted_request) return true;
   if(g_mgtt_natives[ni].fill_finalized) return g_mgtt_natives[ni].fill_complete;
   ulong order_id=g_mgtt_natives[ni].order_id;
   if(order_id==0 && g_mgtt_natives[ni].result_deal_id>0)
   {
      long linked_order=0;
      if(!HistoryDealGetInteger(g_mgtt_natives[ni].result_deal_id,DEAL_ORDER,linked_order) || linked_order<=0)
         return false;
      order_id=(ulong)linked_order;
      g_mgtt_natives[ni].order_id=order_id;
   }
   if(order_id==0 || OrderSelect(order_id) || !HistoryOrderSelect(order_id)) return false;
   for(int other=0;other<ArraySize(g_mgtt_natives);other++)
      if(other!=ni && g_mgtt_natives[other].accepted_request &&
         g_mgtt_natives[other].order_id==order_id) return false;
   long order_state=HistoryOrderGetInteger(order_id,ORDER_STATE);
   if(MGTT_OrderStateIsActive(order_state)) return false;
   double initial=HistoryOrderGetDouble(order_id,ORDER_VOLUME_INITIAL);
   double remaining=HistoryOrderGetDouble(order_id,ORDER_VOLUME_CURRENT);
   double step=g_mgtt_natives[ni].volume_step;
   double tolerance=MathMax(1.0e-12,step*MGTT_VOLUME_TOLERANCE_STEP_MULT);
   if(!MathIsValidNumber(initial) || !MathIsValidNumber(remaining) ||
      !MathIsValidNumber(step) || step<=0.0 || initial<=0.0 || remaining<0.0 || remaining>initial+tolerance)
      return false;
   double final_filled=initial-remaining;
   if(final_filled<=tolerance) return false;

   int history_count=0;
   double history_volume=0.0;
   int deals_total=HistoryDealsTotal();
   for(int i=0;i<deals_total;i++)
   {
      ulong deal_id=HistoryDealGetTicket(i);
      if(deal_id==0 || (ulong)HistoryDealGetInteger(deal_id,DEAL_ORDER)!=order_id) continue;
      long entry=HistoryDealGetInteger(deal_id,DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_IN && entry!=DEAL_ENTRY_INOUT) continue;
      long deal_type=HistoryDealGetInteger(deal_id,DEAL_TYPE);
      string symbol=HistoryDealGetString(deal_id,DEAL_SYMBOL);
      double volume=HistoryDealGetDouble(deal_id,DEAL_VOLUME);
      if(symbol!=_Symbol || (deal_type!=DEAL_TYPE_BUY && deal_type!=DEAL_TYPE_SELL) ||
         !MathIsValidNumber(volume) || volume<=0.0) return false;
      int di=MGTT_DealIndex(deal_id);
      if(di<0 || g_mgtt_deals[di].order_id!=order_id ||
         g_mgtt_deals[di].symbol!=symbol || g_mgtt_deals[di].deal_type!=deal_type ||
         !g_mgtt_deals[di].entry_known || g_mgtt_deals[di].entry_type!=entry ||
         MathAbs(g_mgtt_deals[di].volume-volume)>tolerance || !g_mgtt_deals[di].emitted)
         return false;
      g_mgtt_deals[di].history_verified=true;
      history_count++;
      history_volume+=volume;
   }
   if(history_count<=0 || MathAbs(history_volume-final_filled)>tolerance) return false;
   for(int d=0;d<ArraySize(g_mgtt_deals);d++)
   {
      if(g_mgtt_deals[d].order_id==order_id &&
         (g_mgtt_deals[d].entry_type==DEAL_ENTRY_IN || g_mgtt_deals[d].entry_type==DEAL_ENTRY_INOUT) &&
         !g_mgtt_deals[d].history_verified) return false;
   }
   g_mgtt_natives[ni].fill_finalized=true;
   g_mgtt_natives[ni].fill_complete=true;
   g_mgtt_natives[ni].complete_entry_volume=history_volume;
   MGTT_Emit("FILL_COVERAGE_FINAL",StringFormat("native_id=%I64d order_id=%I64u history_deal_count=%d cumulative_entry_volume=%.8f order_state=%d",
             g_mgtt_natives[ni].id,order_id,history_count,history_volume,(int)order_state));
   return true;
}

bool MGTT_FinalizeFillCoverage()
{
   bool needs_history=false;
   for(int i=0;i<ArraySize(g_mgtt_natives);i++)
      if(g_mgtt_natives[i].accepted_request && !g_mgtt_natives[i].fill_finalized)
         needs_history=true;
   if(needs_history && !HistorySelect(0,TimeCurrent()+86400)) return false;
   MGTT_ReconcileDeals();
   bool complete=true;
   for(int i=0;i<ArraySize(g_mgtt_natives);i++)
   {
      if(g_mgtt_natives[i].result_count!=1) { complete=false; continue; }
      if(g_mgtt_natives[i].accepted_request && !MGTT_FinalizeOneNativeFill(i))
      {
         complete=false;
         MGTT_Emit("FILL_COVERAGE_UNAVAILABLE",StringFormat("native_id=%I64d order_id=%I64u category=%s",
                   g_mgtt_natives[i].id,g_mgtt_natives[i].order_id,g_mgtt_natives[i].category));
      }
   }
   g_mgtt_fill_coverage_finalized=complete;
   return complete;
}

#ifdef MGTT_LEDGER_PROBE_SYNTHETIC
bool MGTT_ProbeCertifyNativeFill(const long native_id,const double volume)
{
   int ni=MGTT_NativeIndex(native_id);
   if(ni<0 || !g_mgtt_natives[ni].accepted_request || volume<=0.0) return false;
   g_mgtt_natives[ni].fill_finalized=true;
   g_mgtt_natives[ni].fill_complete=true;
   g_mgtt_natives[ni].complete_entry_volume=volume;
   return true;
}
#endif

bool MGTT_CompletenessCertified()
{
   if(g_mgtt_unresolved_request_total>0) return false;
   if(g_mgtt_evidence_error_count>0) return false;
   if(g_mgtt_execution_entry_total!=g_mgtt_pre_submit_terminal_total+g_mgtt_submit_total)
      return false;
   if(g_mgtt_native_request_total!=g_mgtt_accepted_request_total+
      g_mgtt_rejected_request_total+g_mgtt_unresolved_request_total)
      return false;
   for(int i=0;i<ArraySize(g_mgtt_attempts);i++)
      if(g_mgtt_attempts[i].end_count!=1 || g_mgtt_attempts[i].submit_count>1) return false;
   for(int i=0;i<ArraySize(g_mgtt_submits);i++)
      if(g_mgtt_submits[i].return_count!=1) return false;
   for(int i=0;i<ArraySize(g_mgtt_natives);i++)
      if(g_mgtt_natives[i].result_count!=1 ||
         (g_mgtt_natives[i].accepted_request &&
          (!g_mgtt_natives[i].fill_finalized || !g_mgtt_natives[i].fill_complete)))
         return false;
   for(int i=0;i<ArraySize(g_mgtt_deals);i++)
      if(!g_mgtt_deals[i].emitted) return false;
   return true;
}

void MGTT_RunEnd(const int deinit_reason)
{
   if(!MGTT_IsActive() || !g_mgtt_run_started || g_mgtt_run_ended) return;
   MGTT_FinalizeFillCoverage();
   bool certified=MGTT_CompletenessCertified();
   string ratio="null";
   string availability="UNAVAILABLE_NOT_CERTIFIED";
   if(certified && g_mgtt_execution_entry_total>0)
   {
      ratio=DoubleToString((double)g_mgtt_macro_block_total/
                           (double)g_mgtt_execution_entry_total,12);
      availability="CERTIFIED";
   }
   MGTT_Emit("RUN_END",StringFormat("last_sequence=%I64d strategy_intent_total=%I64d execution_entry_total=%I64d pre_submit_terminal_total=%I64d submit_total=%I64d native_request_total=%I64d accepted_request_total=%I64d rejected_request_total=%I64d unresolved_request_total=%I64d unresolved_ids=%s entry_fill_total=%I64d entry_inout_fill_total=%I64d fill_coverage_finalized=%d macro_block_total=%I64d evidence_error_count=%I64d blocked_execution_entry_share_v1=%s availability=%s deinit_reason=%d normal_completion=HOST_MUST_CERTIFY",
             g_mgtt_sequence+1,g_mgtt_strategy_intent_total,
             g_mgtt_execution_entry_total,g_mgtt_pre_submit_terminal_total,
             g_mgtt_submit_total,g_mgtt_native_request_total,
             g_mgtt_accepted_request_total,g_mgtt_rejected_request_total,
              g_mgtt_unresolved_request_total,g_mgtt_unresolved_ids,
              g_mgtt_entry_fill_total,
              g_mgtt_entry_inout_fill_total,(g_mgtt_fill_coverage_finalized?1:0),g_mgtt_macro_block_total,
             g_mgtt_evidence_error_count,
             ratio,availability,deinit_reason));
   g_mgtt_run_ended=true;
}

class CLabEvidenceTrade : public CTrade
{
public:
   virtual bool OrderSend(const MqlTradeRequest &request,MqlTradeResult &result)
   {
      if(!MGTT_IsActive() || !g_mgtt_open_context)
         return CTrade::OrderSend(request,result);
      long native_id=MGTT_NativeBegin(request);
      bool transport_ok=CTrade::OrderSend(request,result); // exactly one forward
      int raw_last_error=GetLastError();
      MGTT_NativeResult(native_id,transport_ok,result,raw_last_error);
      return transport_ok;
   }
};

CLabEvidenceTrade g_trade;
#else
CTrade g_trade;
#endif
int    g_exec_open_intents = 0;

void Exec_Init()
{
   g_trade.SetExpertMagicNumber((ulong)_0_Magic);
   g_trade.SetDeviationInPoints((ulong)_0_Slippage);
   g_trade.SetAsyncMode(false);
   g_trade.LogLevel(LOG_LEVEL_ERRORS);
}

bool Exec_IdentityIsMine(const string symbol, const long magic)
{
   if(symbol != _Symbol) return false;
#ifdef LAB_ENTRY_21
   // Cast before arithmetic: source groups occupy base+1 through base+5.
   return magic > (long)_21_DF03_MagicStart && magic <= (long)_21_DF03_MagicStart + 5;
#else
   return magic == _0_Magic;
#endif
}

bool Exec_PosIsMine(const int index)
{
   ulong tk = PositionGetTicket(index);
   if(tk == 0) return false;
   return Exec_IdentityIsMine(PositionGetString(POSITION_SYMBOL), (long)PositionGetInteger(POSITION_MAGIC));
}

// Hedge legs use the same magic as the directional basket, so magic/symbol
// ownership alone cannot distinguish their role. Keep the role predicate in
// this dependency-low layer so directional consumers do not include Hedge.mqh.
bool Exec_PosIsHedge(const int index)
{
   if(!Exec_PosIsMine(index)) return false;
   return (StringFind(PositionGetString(POSITION_COMMENT), " H") >= 0);
}

bool Exec_PosIsDirectional(const int index)
{
   return (Exec_PosIsMine(index) && !Exec_PosIsHedge(index));
}

double Exec_NormalizeLot(double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   // ORDER-432 finding 5 (Codex blind audit 2026-07-27). This used to invent 0.01 when
   // the property read failed. That is a guess about the broker's contract and it is
   // wrong in both directions: with a real step of 0.001 an intended 0.015 floors to
   // 0.01 and the broker ACCEPTS it, so the position is 33% small and nothing says so;
   // with a real step of 0.1 the same guess leaves 0.15 unrounded and the broker
   // REJECTS it. One fallback, two silent failures.
   //
   // Return 0.0 -- the same "caller skips this order" contract this function already
   // uses for a lot below the broker minimum, and the same rule MM_FirstLot follows:
   // a runtime data failure costs a missed trade, never a differently-sized one.
   //
   // NOTE the sibling Exec_NormalizeCloseLot is deliberately NOT changed the same way;
   // see the comment there. Codex cited only this site, and applying one rule to both
   // would have been wrong.
   if(step <= 0.0)
   {
      static datetime step_log = 0;
      datetime now_step = TimeCurrent();
      if(now_step - step_log >= 60)
      {
         step_log = now_step;
         Print("[EXEC] SYMBOL_VOLUME_STEP unreadable - OPEN skipped rather than sized against a guessed step (ORDER-432 finding 5)");
      }
      return 0.0;
   }
   if(RC_MaxLot > 0.0 && lot > RC_MaxLot) lot = RC_MaxLot;   // final hard ceiling
   if(lot > maxv) lot = maxv;
   lot = MathFloor(lot / step + 0.0000001) * step;
   // ORDER-129 (ORDER-125 RiskLot pattern): digits follow the broker's volume step —
   // NormalizeDouble(,2) corrupted 0.001-step symbols. Below-minimum after caps/rounding
   // returns 0 (callers skip): the old floor-to-minimum could send MORE than the RC_MaxLot
   // ceiling claimed to allow.
   int stepDigits = 0;
   double s = step;
   while(stepDigits < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; stepDigits++; }
   lot = NormalizeDouble(lot, stepDigits);
   if(lot < minv)
   {
      static datetime last_log = 0;
      datetime now = TimeCurrent();
      if(now - last_log >= 60)
      {
         last_log = now;
         PrintFormat("[EXEC] lot %.4f below broker min %.4f after caps - order skipped (not floored up)", lot, minv);
      }
      return 0.0;
   }
   return lot;
}

// ORDER-129: _0_MaxSpread was a declared-but-never-read input (operator sets it believing
// entries are blocked, EA opens through news/rollover widening anyway). One predicate,
// checked in BOTH open paths (market + pending). 0 keeps the historical no-op default.
bool Exec_SpreadOK()
{
   if(_0_MaxSpread <= 0) return true;
   long spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);   // points
   if(spr <= (long)_0_MaxSpread) return true;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      PrintFormat("[EXEC] spread %d > max %d - new order blocked", (int)spr, _0_MaxSpread);
   }
   return false;
}

// ---- NewsGuard bridge (ORDER-083, additive) ------------------------------
// The (Boss)_NewsGuard watchdog EA may set GlobalVariable
// NEWSGUARD_BLOCK_<magic> = 1 around high-impact news. While it exists and
// reads >= 0.5, NEW orders (market opens + pending placement) are vetoed
// here - the single OrderSend choke point. Management / modify / close
// paths are untouched. Inert when the GV does not exist (tester GVs are
// per-pass sandboxed, so regression numbers cannot move unless a test
// sets the GV itself). Log throttled to once per minute to avoid spam
// while grid/ladder modules keep retrying during the window.
bool Exec_NewsBlocked()
{
   string gv = "NEWSGUARD_BLOCK_" + IntegerToString(_0_Magic);
   if(!GlobalVariableCheck(gv)) return false;
   if(GlobalVariableGet(gv) < 0.5) return false;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      PrintFormat("[EXEC] NEWSGUARD block active (%s) - new order skipped", gv);
   }
   return true;
}

// ---- MacroGate bridge (ORDER-073 Phase-3, additive) ----------------------
// The (Boss)_MacroGate watchdog EA may set, per magic, during a RISK_OFF/STRESS
// macro regime:
//   MACROGATE_BLOCK_<magic>   = 1    -> veto NEW orders (same idea as NewsGuard)
//   MACROGATE_LOTMULT_<magic> = 0.5  -> shrink the NEW-order lot by this factor
// Both apply to the OPEN / PENDING paths ONLY - management, exits and partial-
// close are untouched. Critically the multiplier is applied HERE (open path),
// never inside Exec_NormalizeLot, which also sizes partial CLOSES. Inert when
// the GVs are absent; fail-safe (clearing GVs on stale/missing regime data) is
// the watchdog's job so the chassis stays dumb. Log throttled to 1/min.
#define MACROGATE_GV_MAX_AGE_SEC 3600   // live: if the watchdog stops refreshing a GV, fail open within this

bool Exec_MacroBlocked()
{
   string gv = "MACROGATE_BLOCK_" + IntegerToString(_0_Magic);
   if(!GlobalVariableCheck(gv)) return false;
   // fail open if a dead/removed watchdog stranded this GV (Codex QA 2026-07-18). Skip the
   // age check in the tester, where the self-gate refreshes GVs in sim time each bar and there
   // is no crash-strand risk (single EA) - GlobalVariableTime vs sim TimeCurrent is unreliable.
   if(!MQLInfoInteger(MQL_TESTER) && (TimeCurrent() - GlobalVariableTime(gv)) > MACROGATE_GV_MAX_AGE_SEC) return false;
   if(GlobalVariableGet(gv) < 0.5) return false;
   static datetime last_log = 0;
   datetime now = TimeCurrent();
   if(now - last_log >= 60)
   {
      last_log = now;
      PrintFormat("[EXEC] MACROGATE block active (%s) - new order skipped", gv);
   }
   return true;
}

// New-order lot multiplier from MacroGate. Default 1.0 (no change). Only values
// in (0,1) take effect, so the gate can only REDUCE size (reduce-lot doctrine -
// never scale up, never zero out).
double Exec_MacroLotMult()
{
   string gv = "MACROGATE_LOTMULT_" + IntegerToString(_0_Magic);
   if(!GlobalVariableCheck(gv)) return 1.0;
   if(!MQLInfoInteger(MQL_TESTER) && (TimeCurrent() - GlobalVariableTime(gv)) > MACROGATE_GV_MAX_AGE_SEC) return 1.0; // stale watchdog -> fail open
   double m = GlobalVariableGet(gv);
   if(!MathIsValidNumber(m) || m <= 0.0 || m >= 1.0) return 1.0;   // NaN / out of (0,1) -> no-op
   return m;
}

// ---- Prepared market-open seam (ZCAG Phase A, additive) -----------------
// Existing Exec_Open callers deliberately remain on the legacy path below.
// This seam allows a caller to prepare one final lot, run heat and margin
// checks against that exact value, and submit it without a second MacroGate
// multiplier or volume normalization.
struct Exec_MacroSnapshot
{
   bool     valid;
   bool     block_exists;
   double   block_value;
   datetime block_time;
   bool     mult_exists;
   double   mult_value;
   datetime mult_time;
   bool     effective_block;
   double   effective_mult;
};

struct Exec_PreparedOpen
{
   bool               valid;
   int                direction;
   double             final_checked_lot;
   Exec_MacroSnapshot macro;
};

enum Exec_PreparedOpenOutcome
{
   EXEC_PREPARED_REFUSED=0,
   EXEC_PREPARED_INTENT_ONLY=1,
   EXEC_PREPARED_MARKET_DONE=2
};

bool Exec_MacroEffectiveMultiplier(const bool exists,const double identity_value,
                                   double &effective_mult)
{
   effective_mult=1.0;
   if(!exists) return true;
   if(!MathIsValidNumber(identity_value)) return false;
   // Preserve the existing MacroGate policy: finite values outside (0,1)
   // are identity-bearing no-ops, never an upscale or zero-lot command.
   if(identity_value > 0.0 && identity_value < 1.0)
      effective_mult=identity_value;
   return true;
}

bool Exec_MacroIdentityEqual(const Exec_MacroSnapshot &left,
                             const Exec_MacroSnapshot &right)
{
   if(!left.valid || !right.valid) return false;
   return (left.block_exists == right.block_exists &&
           left.block_value  == right.block_value &&
           left.block_time   == right.block_time &&
           left.mult_exists  == right.mult_exists &&
           left.mult_value   == right.mult_value &&
           left.mult_time    == right.mult_time &&
           left.effective_block == right.effective_block &&
           left.effective_mult  == right.effective_mult);
}

bool Exec_ReadMacroSnapshot(Exec_MacroSnapshot &snapshot)
{
   snapshot.valid=false;
   snapshot.block_exists=false;
   snapshot.block_value=0.0;
   snapshot.block_time=0;
   snapshot.mult_exists=false;
   snapshot.mult_value=1.0;
   snapshot.mult_time=0;
   snapshot.effective_block=false;
   snapshot.effective_mult=1.0;

   string block_gv="MACROGATE_BLOCK_"+IntegerToString(_0_Magic);
   snapshot.block_exists=GlobalVariableCheck(block_gv);
   if(snapshot.block_exists)
   {
      snapshot.block_value=GlobalVariableGet(block_gv);
      snapshot.block_time=GlobalVariableTime(block_gv);
      if(!MathIsValidNumber(snapshot.block_value) || snapshot.block_time <= 0)
         return false;
   }

   string mult_gv="MACROGATE_LOTMULT_"+IntegerToString(_0_Magic);
   snapshot.mult_exists=GlobalVariableCheck(mult_gv);
   if(snapshot.mult_exists)
   {
      snapshot.mult_value=GlobalVariableGet(mult_gv);
      snapshot.mult_time=GlobalVariableTime(mult_gv);
      if(!MathIsValidNumber(snapshot.mult_value) ||
         snapshot.mult_time <= 0) return false;
   }

   bool block_fresh=snapshot.block_exists;
   bool mult_fresh=snapshot.mult_exists;
   if(!MQLInfoInteger(MQL_TESTER))
   {
      datetime now=TimeCurrent();
      if(block_fresh && now-snapshot.block_time > MACROGATE_GV_MAX_AGE_SEC)
         block_fresh=false;
      if(mult_fresh && now-snapshot.mult_time > MACROGATE_GV_MAX_AGE_SEC)
         mult_fresh=false;
   }

   snapshot.effective_block=(block_fresh && snapshot.block_value >= 0.5);
   if(!Exec_MacroEffectiveMultiplier(mult_fresh,snapshot.mult_value,
                                     snapshot.effective_mult))
      return false;
   snapshot.valid=true;
   return true;
}

// Pure normalization seam used by prepared opens and deterministic tests.
// Invalid broker properties fail closed. The requested lot is multiplied,
// capped and rounded exactly once.
bool Exec_CheckedNormalizeLot(const double requested_lot,const double macro_mult,
                              const double min_volume,const double max_volume,
                              const double volume_step,const double hard_cap,
                              double &final_checked_lot)
{
   final_checked_lot=0.0;
   if(!MathIsValidNumber(requested_lot) || requested_lot <= 0.0 ||
      !MathIsValidNumber(macro_mult) || macro_mult <= 0.0 || macro_mult > 1.0 ||
      !MathIsValidNumber(min_volume) || min_volume <= 0.0 ||
      !MathIsValidNumber(max_volume) || max_volume < min_volume ||
      !MathIsValidNumber(volume_step) || volume_step <= 0.0 ||
      !MathIsValidNumber(hard_cap) || hard_cap < 0.0)
      return false;

   double lot=requested_lot*macro_mult;
   if(!MathIsValidNumber(lot) || lot <= 0.0) return false;
   if(hard_cap > 0.0 && lot > hard_cap) lot=hard_cap;
   if(lot > max_volume) lot=max_volume;
   lot=MathFloor(lot/volume_step+0.0000001)*volume_step;

   int step_digits=0;
   double scaled_step=volume_step;
   while(step_digits < 8 &&
         MathAbs(scaled_step-MathRound(scaled_step)) > 1.0e-9)
   {
      scaled_step*=10.0;
      step_digits++;
   }
   lot=NormalizeDouble(lot,step_digits);
   if(!MathIsValidNumber(lot) || lot < min_volume || lot > max_volume)
      return false;
   final_checked_lot=lot;
   return true;
}

bool Exec_CheckedLotIdentity(const double final_checked_lot,
                             const double heat_checked_lot,
                             const double margin_checked_lot,
                             const double submission_lot)
{
   return (MathIsValidNumber(final_checked_lot) && final_checked_lot > 0.0 &&
           final_checked_lot == heat_checked_lot &&
           final_checked_lot == margin_checked_lot &&
           final_checked_lot == submission_lot);
}

// Pure assessment seam: a CTrade transport boolean is not proof that a
// market order executed. DryRun is deliberately a distinct intent-only
// outcome; live success requires one complete, exact-volume deal.
Exec_PreparedOpenOutcome Exec_AssessPreparedOpenResult(
   const bool dry_run,const bool transport_ok,const uint retcode,
   const ulong deal,const double result_volume,
   const double submission_lot,const double volume_step)
{
   if(dry_run) return EXEC_PREPARED_INTENT_ONLY;
   if(!transport_ok || retcode != TRADE_RETCODE_DONE || deal == 0)
      return EXEC_PREPARED_REFUSED;
   if(!MathIsValidNumber(result_volume) || result_volume <= 0.0 ||
      !MathIsValidNumber(submission_lot) || submission_lot <= 0.0 ||
      !MathIsValidNumber(volume_step) || volume_step <= 0.0)
      return EXEC_PREPARED_REFUSED;

   // Broker volumes are step-quantized. Tolerate only floating-point noise,
   // never a material fraction of one volume step or a partial fill.
   double tolerance=MathMax(1.0e-12,volume_step*1.0e-8);
   if(MathAbs(result_volume-submission_lot) > tolerance)
      return EXEC_PREPARED_REFUSED;
   return EXEC_PREPARED_MARKET_DONE;
}

bool Exec_PreparedOpenAcceptsChecks(const Exec_PreparedOpen &prepared,
                                    const double heat_checked_lot,
                                    const double margin_checked_lot,
                                    const Exec_MacroSnapshot &current_macro,
                                    double &submission_lot)
{
   submission_lot=0.0;
   if(!prepared.valid || (prepared.direction != 1 && prepared.direction != 2))
      return false;
   if(!Exec_MacroIdentityEqual(prepared.macro,current_macro))
      return false;
   if(current_macro.effective_block) return false;
   if(!Exec_CheckedLotIdentity(prepared.final_checked_lot,
                               heat_checked_lot,margin_checked_lot,
                               prepared.final_checked_lot))
      return false;
   submission_lot=prepared.final_checked_lot;
   return true;
}

bool Exec_PrepareOpen(const int direction,const double requested_lot,
                      Exec_PreparedOpen &prepared)
{
   prepared.valid=false;
   prepared.direction=direction;
   prepared.final_checked_lot=0.0;
   if(direction != 1 && direction != 2) return false;
   if(Exec_NewsBlocked() || !Exec_SpreadOK()) return false;
   if(!Exec_ReadMacroSnapshot(prepared.macro) ||
      prepared.macro.effective_block)
      return false;

   double min_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double max_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double volume_step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(!Exec_CheckedNormalizeLot(requested_lot,prepared.macro.effective_mult,
                                min_volume,max_volume,volume_step,RC_MaxLot,
                                prepared.final_checked_lot))
      return false;
   prepared.valid=true;
   return true;
}

bool Exec_SubmitPreparedOpen(const Exec_PreparedOpen &prepared,
                             const double heat_checked_lot,
                             const double margin_checked_lot,
                             const double sl,const double tp,
                             const string comment)
{
   // All choke-point guards are rechecked immediately before submission.
   if(Exec_NewsBlocked() || !Exec_SpreadOK()) return false;
   Exec_MacroSnapshot current_macro;
   if(!Exec_ReadMacroSnapshot(current_macro)) return false;

   double submission_lot=0.0;
   if(!Exec_PreparedOpenAcceptsChecks(prepared,heat_checked_lot,
                                      margin_checked_lot,current_macro,
                                      submission_lot))
      return false;

   g_exec_open_intents++;
   if(DryRun)
   {
      PrintFormat("[DRYRUN] prepared open dir=%d lot=%.2f sl=%.5f tp=%.5f %s",
                  prepared.direction,submission_lot,sl,tp,comment);
      return (Exec_AssessPreparedOpenResult(true,false,0,0,0.0,
                                            submission_lot,0.0) ==
              EXEC_PREPARED_INTENT_ONLY);
   }
   bool transport_ok=false;
   if(prepared.direction == 1)
      transport_ok=g_trade.Buy(submission_lot,_Symbol,0.0,sl,tp,comment);
   else if(prepared.direction == 2)
      transport_ok=g_trade.Sell(submission_lot,_Symbol,0.0,sl,tp,comment);

   Exec_PreparedOpenOutcome outcome=Exec_AssessPreparedOpenResult(
      false,transport_ok,g_trade.ResultRetcode(),g_trade.ResultDeal(),
      g_trade.ResultVolume(),submission_lot,
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   return (outcome == EXEC_PREPARED_MARKET_DONE);
}

#ifdef LAB_MG_TESTER_EVIDENCE_QUAL
// Qualification branch for the legacy market-open choke point. The order of
// guards, normalization, g_exec_open_intents increment, DryRun behavior,
// CTrade call and returned boolean is the same as Exec_Open below.
bool Exec_OpenObserved(const int direction,double lot,const double sl,
                       const double tp,const string comment)
{
   long attempt_id=MGTT_ExecutionBegin("MARKET",direction,lot);
   if(Exec_NewsBlocked()) { MGTT_PreSubmitTerminal(attempt_id,"NEWS"); return false; }
   if(Exec_MacroBlocked()) { MGTT_PreSubmitTerminal(attempt_id,"MACRO"); return false; }
   if(!Exec_SpreadOK()) { MGTT_PreSubmitTerminal(attempt_id,"SPREAD"); return false; }
   lot=Exec_NormalizeLot(lot*Exec_MacroLotMult());
   if(lot<=0.0) { MGTT_PreSubmitTerminal(attempt_id,"VOLUME"); return false; }
   g_exec_open_intents++;
   if(DryRun)
   {
      PrintFormat("[DRYRUN] open dir=%d lot=%.2f sl=%.5f tp=%.5f %s",direction,lot,sl,tp,comment);
      MGTT_PreSubmitTerminal(attempt_id,"DRYRUN");
      return true;
   }
   if(direction!=1 && direction!=2)
   {
      MGTT_PreSubmitTerminal(attempt_id,"EXISTING_NO_SUBMIT");
      return false;
   }
   long submit_id=MGTT_SubmitBegin(attempt_id,"MARKET",lot);
   bool library_bool=(direction==1 ?
      g_trade.Buy(lot,_Symbol,0.0,sl,tp,comment) :
      g_trade.Sell(lot,_Symbol,0.0,sl,tp,comment));
   uint retcode=g_trade.ResultRetcode();
   double result_volume=g_trade.ResultVolume();
   MGTT_SubmitReturn(submit_id,library_bool,retcode,result_volume);
   MGTT_ExecutionEnd(attempt_id,(library_bool?"SUBMIT_RETURN_TRUE":"SUBMIT_RETURN_FALSE"));
   return library_bool;
}
#endif

bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)
{
#ifdef LAB_MG_TESTER_EVIDENCE_QUAL
   if(MGTT_IsActive()) return Exec_OpenObserved(direction,lot,sl,tp,comment);
#endif
   if(Exec_NewsBlocked() || Exec_MacroBlocked()) return false;   // news + macro veto (new orders only)
   if(!Exec_SpreadOK()) return false;                            // ORDER-129: enforce _0_MaxSpread
   lot = Exec_NormalizeLot(lot * Exec_MacroLotMult());           // macro reduce-lot (open path only)
   if(lot <= 0.0) return false;
   g_exec_open_intents++;
   if(DryRun)
   {
      PrintFormat("[DRYRUN] open dir=%d lot=%.2f sl=%.5f tp=%.5f %s", direction, lot, sl, tp, comment);
      return true;
   }
   if(direction == 1) return g_trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   if(direction == 2) return g_trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
   return false;
}

int Exec_CountDir(const int direction)   // 0=any 1=buy 2=sell
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 0) n++;
      else if(direction == 1 && type == POSITION_TYPE_BUY) n++;
      else if(direction == 2 && type == POSITION_TYPE_SELL) n++;
   }
   return n;
}

// Directional basket counts deliberately exclude defensive hedge legs. The
// legacy Exec_CountDir/Exec_CountAll contract remains available for full
// ownership/flatness scans and close-all reconciliation.
int Exec_CountDirectionalDir(const int direction)   // 0=directional any, 1=buy, 2=sell
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 0) n++;
      else if(direction == 1 && type == POSITION_TYPE_BUY) n++;
      else if(direction == 2 && type == POSITION_TYPE_SELL) n++;
   }
   return n;
}

double Exec_TotalDirectionalLots()
{
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

int Exec_CountAll() { return Exec_CountDir(0); }

double Exec_TotalLots()
{
   double lots = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      lots += PositionGetDouble(POSITION_VOLUME);
   }
   return lots;
}

double Exec_BasketProfit()
{
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

double Exec_LastPriceDir(const int direction)
{
   datetime best = 0;
   double   price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY) continue;
      if(direction == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) { best = t; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
}

// open time of the most-recent order in a direction (for retrigger confirm)
datetime Exec_LastTimeDir(const int direction)
{
   datetime best = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY) continue;
      if(direction == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) best = t;
   }
   return best;
}

double Exec_LastDirectionalPriceDir(const int direction)
{
   datetime best = 0;
   double   price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY) continue;
      if(direction == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) { best = t; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
}

datetime Exec_LastDirectionalTimeDir(const int direction)
{
   datetime best = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      if(direction == 1 && type != POSITION_TYPE_BUY) continue;
      if(direction == 2 && type != POSITION_TYPE_SELL) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t >= best) best = t;
   }
   return best;
}

// ---- pending-order infra (MERGE-03, STACK_PYRAMID 93) --------------------
// Old modes never place pendings, so the cancel below is a no-op for them.

bool Exec_OrdIsMine(const int index)
{
   ulong tk = OrderGetTicket(index);
   if(tk == 0) return false;
   return Exec_IdentityIsMine(OrderGetString(ORDER_SYMBOL), (long)OrderGetInteger(ORDER_MAGIC));
}

int Exec_CountPending()
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(Exec_OrdIsMine(i)) n++;
   return n;
}

// ORDER-132 (Codex system-review SEV-1 #5): projected margin of every resting
// pending ON THE ACCOUNT if it filled at its order price. A GTC ladder consumes
// margin at FILL time, when the deposit-load cage can no longer refuse it -
// Stack's budget gate (Stack_MarginBudgetOK) reserves this ahead of placement.
// ORDER-132b (Codex E4): deliberately NOT filtered to own symbol/magic - the
// deposit-load cap is an ACCOUNT-level cage, so a sibling EA's resting ladder
// must count against the same budget (double-reserving across EAs errs safe).
// Unpriceable orders contribute 0 here; the per-leg gate is the fail-closed side.
double Exec_PendingMarginProjection()
{
   double sum = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      string sym   = OrderGetString(ORDER_SYMBOL);
      double lot   = OrderGetDouble(ORDER_VOLUME_CURRENT);
      double price = OrderGetDouble(ORDER_PRICE_OPEN);
      long   type  = OrderGetInteger(ORDER_TYPE);
      bool   isBuy = (type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_LIMIT ||
                      type == ORDER_TYPE_BUY_STOP_LIMIT);
      double m = 0.0;
      if(OrderCalcMargin(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, sym, lot, price, m))
         sum += m;
   }
   return sum;
}

// ORDER-129: reports completion — a failed delete used to vanish silently, leaving a live
// GTC order behind an EA that believed itself flat (Codex system review SEV-1).
bool Exec_CancelAllPending()
{
   bool allOk = true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!Exec_OrdIsMine(i)) continue;
      ulong tk = OrderGetTicket(i);
      if(DryRun) { PrintFormat("[DRYRUN] cancel pending %I64u", tk); continue; }
      if(g_trade.OrderDelete(tk))
         PrintFormat("[EXEC] pending cancelled %I64u", tk);
      else
      {
         allOk = false;
         PrintFormat("[EXEC] pending cancel FAILED %I64u retcode=%d", tk, (int)g_trade.ResultRetcode());
      }
   }
   return allOk;
}

// place one resting leg. isStop: true=STOP (pyramid, with-trend fill),
// false=LIMIT (scale-in, against-trend fill). tp always 0 in mode 93
// (basket exit is the single exit owner - see Inputs.mqh note).
bool Exec_PlacePending(const int direction, const bool isStop, double lot,
                       double price, const double sl, const string comment)
{
#ifdef LAB_MG_TESTER_EVIDENCE_QUAL
   if(MGTT_IsActive())
   {
      long attempt_id=MGTT_ExecutionBegin("PENDING",direction,lot);
      if(Exec_NewsBlocked()) { MGTT_PreSubmitTerminal(attempt_id,"NEWS"); return false; }
      if(Exec_MacroBlocked()) { MGTT_PreSubmitTerminal(attempt_id,"MACRO"); return false; }
      if(!Exec_SpreadOK()) { MGTT_PreSubmitTerminal(attempt_id,"SPREAD"); return false; }
      lot=Exec_NormalizeLot(lot*Exec_MacroLotMult());
      if(lot<=0.0) { MGTT_PreSubmitTerminal(attempt_id,"VOLUME"); return false; }
      price=NormalizeDouble(price,_Digits);
      if(DryRun)
      {
         PrintFormat("[DRYRUN] pending dir=%d stop=%d lot=%.2f at %.5f sl=%.5f %s",
                     direction,(isStop?1:0),lot,price,sl,comment);
         MGTT_PreSubmitTerminal(attempt_id,"DRYRUN");
         return true;
      }
      long submit_id=MGTT_SubmitBegin(attempt_id,"PENDING",lot);
      bool raw_ok=false;
      if(direction==1)
         raw_ok=(isStop ? g_trade.BuyStop(lot,price,_Symbol,sl,0.0,ORDER_TIME_GTC,0,comment)
                        : g_trade.BuyLimit(lot,price,_Symbol,sl,0.0,ORDER_TIME_GTC,0,comment));
      else
         raw_ok=(isStop ? g_trade.SellStop(lot,price,_Symbol,sl,0.0,ORDER_TIME_GTC,0,comment)
                        : g_trade.SellLimit(lot,price,_Symbol,sl,0.0,ORDER_TIME_GTC,0,comment));
      uint raw_retcode=g_trade.ResultRetcode();
      double result_volume=g_trade.ResultVolume();
      MGTT_SubmitReturn(submit_id,raw_ok,raw_retcode,result_volume);

      // Preserve the existing pending return rule exactly: a true CTrade bool
      // is narrowed to DONE/PLACED, but the raw boolean remains in evidence.
      bool ok=raw_ok;
      if(ok && raw_retcode!=TRADE_RETCODE_DONE &&
               raw_retcode!=TRADE_RETCODE_PLACED) ok=false;
      if(ok) PrintFormat("[EXEC] pending placed dir=%d stop=%d lot=%.2f at %.5f (%s)",
                         direction,(isStop?1:0),lot,price,comment);
      else   PrintFormat("[EXEC] pending FAILED dir=%d at %.5f retcode=%d",
                         direction,price,(int)raw_retcode);
      MGTT_ExecutionEnd(attempt_id,(ok?"PENDING_RETURN_TRUE":"PENDING_RETURN_FALSE"));
      return ok;
   }
#endif
   if(Exec_NewsBlocked() || Exec_MacroBlocked()) return false;   // news + macro veto (new orders only)
   if(!Exec_SpreadOK()) return false;                            // ORDER-129: enforce _0_MaxSpread
   lot = Exec_NormalizeLot(lot * Exec_MacroLotMult());           // macro reduce-lot (open path only)
   if(lot <= 0.0) return false;
   price = NormalizeDouble(price, _Digits);
   if(DryRun)
   {
      PrintFormat("[DRYRUN] pending dir=%d stop=%d lot=%.2f at %.5f sl=%.5f %s",
                  direction, (isStop ? 1 : 0), lot, price, sl, comment);
      return true;
   }
   bool ok = false;
   if(direction == 1) ok = (isStop ? g_trade.BuyStop(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment)
                                   : g_trade.BuyLimit(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment));
   else               ok = (isStop ? g_trade.SellStop(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment)
                                   : g_trade.SellLimit(lot, price, _Symbol, sl, 0.0, ORDER_TIME_GTC, 0, comment));
   // ORDER-132b (Codex E3): the CTrade boolean alone proves only the client-side
   // structure check - require a server-accepted retcode before reporting success.
   if(ok)
   {
      uint rc = g_trade.ResultRetcode();
      if(rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED) ok = false;
   }
   if(ok) PrintFormat("[EXEC] pending placed dir=%d stop=%d lot=%.2f at %.5f (%s)",
                      direction, (isStop ? 1 : 0), lot, price, comment);
   else   PrintFormat("[EXEC] pending FAILED dir=%d at %.5f retcode=%d",
                      direction, price, (int)g_trade.ResultRetcode());
   return ok;
}

// ORDER-129: close-all now PROVES flatness instead of assuming it. Returns true only when,
// after issuing every close/cancel, a broker-state re-scan finds zero own positions AND zero
// own pendings. The hard-kill persists HALT only on a true return (reconciliation loop in
// RiskControl retries every tick otherwise) — previously every PositionClose result was
// discarded and HALT latched with residual exposure still live (Codex system review SEV-1).
bool Exec_CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsMine(i)) continue;
      ulong tk = PositionGetInteger(POSITION_TICKET);
      if(DryRun) continue;
      if(!g_trade.PositionClose(tk))
         PrintFormat("[EXEC] close FAILED %I64u retcode=%d", tk, (int)g_trade.ResultRetcode());
   }
   // basket gone = ladder leftovers must go too (no-op when no pendings exist)
   Exec_CancelAllPending();
   if(DryRun) return true;   // intent mode: nothing real to verify
   // broker-state confirmation - never trust the per-call results alone
   return (Exec_CountAll() == 0 && Exec_CountPending() == 0);
}

// additive (ORDER-072, Kangaroo/16 overlap pair-close): close ONE own position
// by ticket. No other build calls this - behavior of Boss_11..15 unchanged.
bool Exec_CloseTicket(const ulong ticket)
{
   if(DryRun)
   {
      PrintFormat("[DRYRUN] close ticket %I64u", ticket);
      return true;
   }
   return g_trade.PositionClose(ticket);
}

bool Exec_ModifyPosition(const ulong ticket, const double sl, const double tp)
{
   if(DryRun) return true;
   return g_trade.PositionModify(ticket, sl, tp);
}

// ORDER-129b (Codex audit): close-volume normalizer. Same broker min/step/max arithmetic
// as Exec_NormalizeLot but WITHOUT the RC_MaxLot cage clamp - RC_MaxLot is a ceiling on
// new RISK, and capping a partial CLOSE with it would silently shrink risk REDUCTION
// (e.g. 50% of a 1.0-lot legacy position "closed" as 0.10 with the milestone marked done).
double Exec_NormalizeCloseLot(double lot)
{
   double minv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxv = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lot > maxv) lot = maxv;
   // ORDER-432 finding 5, the OTHER half -- and the direction is deliberately opposite
   // to Exec_NormalizeLot above. This normalizes a partial CLOSE. Returning 0.0 here
   // would mean "do not close", so applying the open path's fail-closed rule would make
   // an unreadable broker property REFUSE TO REDUCE RISK -- the worst possible reading
   // of "fail safe". Codex cited only the open site; one rule for both would have been
   // wrong.
   //
   // So: never invent a step, but never refuse to close either. Skip the flooring and
   // send the requested volume, letting the broker validate it. The close is attempted,
   // and it is not silently shrunk against a guess.
   if(step <= 0.0)
   {
      static datetime cstep_log = 0;
      datetime now_cstep = TimeCurrent();
      if(now_cstep - cstep_log >= 60)
      {
         cstep_log = now_cstep;
         Print("[EXEC] SYMBOL_VOLUME_STEP unreadable on a CLOSE - sending the requested volume unrounded (refusing to close would be worse than an unrounded close)");
      }
      return (lot < minv ? 0.0 : lot);
   }
   lot = MathFloor(lot / step + 0.0000001) * step;
   int stepDigits = 0;
   double s = step;
   while(stepDigits < 8 && MathAbs(s - MathRound(s)) > 1e-9) { s *= 10.0; stepDigits++; }
   lot = NormalizeDouble(lot, stepDigits);
   if(lot < minv) return 0.0;
   return lot;
}

// additive: partial-close every own position by `frac` of its current volume
// (skips legs where the resulting close volume would be <=0 or >= full volume,
// i.e. below broker min-lot step after normalize). Used by ExitManager's
// milestone partial-close (_2_PartialPct1/2) - Zeus GridLog port (14).
// ORDER-132 (Codex F3): returns whether every ATTEMPTED close was accepted by
// the broker - a rejected partial used to vanish silently while the caller
// marked its milestone done. Skipped (unrepresentable-volume) legs do not fail
// the call: they can never become executable at this volume, so retrying them
// is noise, not risk reduction.
// ORDER-132b (Codex E1+E2): success now requires a server-accepted retcode (the
// CTrade boolean alone proves only the structure check), and `doneTickets`
// carries per-ticket completion across retries - without it, a milestone retry
// re-fractioned legs that already succeeded, repeatedly draining the cushion
// leg while the broker kept rejecting its sibling (unbounded over-close).
bool Exec_TicketInList(const ulong tk, const ulong &list[])
{
   for(int i = ArraySize(list) - 1; i >= 0; i--)
      if(list[i] == tk) return true;
   return false;
}

bool Exec_ClosePartialFraction(const double frac, ulong &doneTickets[])
{
   if(frac <= 0.0) return true;   // nothing requested = vacuous success
   bool allOk = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!Exec_PosIsDirectional(i)) continue;
      ulong  tk  = PositionGetInteger(POSITION_TICKET);
      if(Exec_TicketInList(tk, doneTickets)) continue;   // already reduced in this milestone
      double vol = PositionGetDouble(POSITION_VOLUME);
      double closeVol = Exec_NormalizeCloseLot(vol * frac);
      if(closeVol <= 0.0 || closeVol >= vol) continue;   // skip if it would close the whole leg
      if(DryRun)
      {
         PrintFormat("[DRYRUN] partial-close ticket=%I64u vol=%.2f frac=%.2f -> %.2f", tk, vol, frac, closeVol);
         continue;
      }
      bool sent = g_trade.PositionClosePartial(tk, closeVol);
      uint rc   = g_trade.ResultRetcode();
      if(sent && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
      {
         int n = ArraySize(doneTickets);
         ArrayResize(doneTickets, n + 1);
         doneTickets[n] = tk;
      }
      else
      {
         allOk = false;
         PrintFormat("[EXEC] partial-close FAILED %I64u vol=%.2f sent=%d retcode=%d", tk, closeVol, (sent ? 1 : 0), (int)rc);
      }
   }
   return allOk;
}

#endif // BOSS_LAB_EXECUTION_MQH
