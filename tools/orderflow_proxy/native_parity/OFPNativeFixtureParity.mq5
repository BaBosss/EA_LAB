//+------------------------------------------------------------------+
//| OFPNativeFixtureParity.mq5                                       |
//| Tester-only, no-trade replay of accepted synthetic OFP fixtures. |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "SYNTHETIC_FIXTURE native parity only; never market evidence"

#include "../../../ea_template/components/orderflow_proxy/OrderFlowProxyComponents.mqh"
#include "generated/NativeFixtureData.mqh"

input string InpRuntimeContractId = "NOT_EXECUTED_UNFROZEN";

string OFP_NativeStatus(const OFPDecision &decision)
{
   switch(decision.decision)
   {
      case OFP_DECISION_NONE:      return "NO_SIGNAL";
      case OFP_DECISION_SIGNAL:    return "SIGNAL";
      case OFP_DECISION_CANCELLED: return "CANCELLED";
      case OFP_DECISION_EXPIRED:   return "EXPIRED";
      case OFP_DECISION_REJECTED:  return "REJECTED";
      case OFP_DECISION_INVALID:   return "INVALID";
   }
   return "UNKNOWN";
}

bool OFP_NativeReplay(const ENUM_OFP_VARIANT variant,
                      const OFPDataContract &contract,
                      const OFPProfile &profile,
                      const OFPContextBar &contexts[],
                      const OFPBar &bars[],
                      const OFPProspectiveQuote &quote,
                      const OFPDecisionEnvelope &envelope,
                      OFPDecision &decision)
{
   switch(variant)
   {
      case OFPR_00_PROFILE_PRICE_CONTROL:
         return OFPR00_Replay(contract, profile, contexts, bars, quote, envelope, decision);
      case OFPR_01_TICK_ACTIVITY:
         return OFPR01_Replay(contract, profile, contexts, bars, quote, envelope, decision);
      case OFPR_02_QUOTE_IMBALANCE:
         return OFPR02_Replay(contract, profile, contexts, bars, quote, envelope, decision);
      case OFPC_00_PROFILE_PRICE_CONTROL:
         return OFPC00_Replay(contract, profile, contexts, bars, quote, envelope, decision);
      case OFPC_01_TICK_ACTIVITY:
         return OFPC01_Replay(contract, profile, contexts, bars, quote, envelope, decision);
      case OFPC_02_QUOTE_IMBALANCE:
         return OFPC02_Replay(contract, profile, contexts, bars, quote, envelope, decision);
      default:
         OFP_SetDecision(decision, OFP_DECISION_INVALID, variant,
                         "INVALID_VARIANT", "generated fixture variant is invalid");
         return false;
   }
}

string OFP_NativeFloat(const double value)
{
   return DoubleToString(value, OFP_NATIVE_FLOAT_DECIMAL_PLACES);
}

bool OFP_RunNativeFixtureCase(const int case_index)
{
   OFPNativeFixtureMeta meta;
   OFPDataContract contract;
   OFPProfile profile;
   OFPContextBar contexts[];
   OFPBar bars[];
   OFPProspectiveQuote quote;
   OFPDecisionEnvelope envelope;
   if(!OFP_LoadNativeFixtureCase(case_index, meta, contract, profile,
                                 contexts, bars, quote, envelope))
      return false;

   OFPDecision decision;
   bool replay_return = OFP_NativeReplay(meta.variant, contract, profile,
                                         contexts, bars, quote, envelope, decision);
   string record =
      "OFP_NATIVE_PARITY_CASE|run_id=" + InpRuntimeContractId +
      "|native_origin=ACTUAL_CANONICAL_MQL_REPLAY" +
      "|run_class=" + OFP_NATIVE_RUN_CLASS +
      "|case_id=" + meta.case_id +
      "|variant=" + meta.variant_name +
      "|status=" + OFP_NativeStatus(decision) +
      "|replay_return=" + (replay_return ? "true" : "false") +
      "|direction=" + IntegerToString(decision.geometry.direction) +
      "|current_closed_bar_record_id=" + envelope.current_closed_bar_record_id +
      "|setup_time=" + IntegerToString((int)decision.geometry.setup_time) +
      "|trigger_time=" + IntegerToString((int)decision.geometry.trigger_time) +
      "|prospective_entry=" + OFP_NativeFloat(decision.geometry.prospective_entry) +
      "|stop_price=" + OFP_NativeFloat(decision.geometry.stop_price) +
      "|target_price=" + OFP_NativeFloat(decision.geometry.target_price) +
      "|net_rr=" + OFP_NativeFloat(decision.geometry.net_rr) +
      "|data_identity=" + contract.data_identity +
      "|profile_identity=" + profile.profile_identity +
      "|imbalance_identity=" + contract.imbalance_identity +
      "|fixture_sha256=" + OFP_NATIVE_FIXTURE_SHA256 +
      "|source_graph_sha256=" + OFP_NATIVE_SOURCE_GRAPH_SHA256;
   Print(record);
   return true;
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER))
      return INIT_FAILED;
   if(StringFind(InpRuntimeContractId, "OFP-NATIVE-FIXTURE-") != 0)
      return INIT_PARAMETERS_INCORRECT;

   int completed = 0;
   for(int case_index = 0; case_index < OFP_NATIVE_FIXTURE_CASE_COUNT; ++case_index)
   {
      if(!OFP_RunNativeFixtureCase(case_index))
         return INIT_FAILED;
      ++completed;
   }
   Print("OFP_NATIVE_PARITY_COMPLETED|run_id=" + InpRuntimeContractId +
         "|native_origin=ACTUAL_CANONICAL_MQL_REPLAY" +
         "|run_class=" + OFP_NATIVE_RUN_CLASS +
         "|case_count=" + IntegerToString(completed) +
         "|fixture_sha256=" + OFP_NATIVE_FIXTURE_SHA256 +
         "|source_graph_sha256=" + OFP_NATIVE_SOURCE_GRAPH_SHA256);
   return INIT_SUCCEEDED;
}
