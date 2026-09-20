//+------------------------------------------------------------------+
//| OrderFlowProxyTemplateSeam.mqh                                  |
//| Geometry-preserving, source-only proxy consumer seam.           |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ORDERFLOW_PROXY_TEMPLATE_SEAM_MQH
#define EA_LAB_ORDERFLOW_PROXY_TEMPLATE_SEAM_MQH

#include "../OrderFlowProxyComponents.mqh"
#include "ThinkMarketsA2Evidence.mqh"

struct OFPTemplateSeamResult
{
   bool                      component_signal_valid;
   bool                      provider_window_valid;
   int                       direction;
   OFPDecision               decision;
   OFPGeometry               geometry;
   OFPThinkMarketsA2Evidence provider_identity;
   bool                      current_entry_signal_compatible;
   bool                      order_execution_authorized;
   bool                      time_exit_consumer_owned;
   string                    binding_status;
   string                    refusal_reason;
};

bool OFP_BuildTemplateSeamResult(
   const OFPDecision &decision,
   const OFPThinkMarketsA2Evidence &provider_evidence,
   const OFPProviderIntervalReceipt &receipts[],
   OFPTemplateSeamResult &result)
{
   result.component_signal_valid = decision.decision == OFP_DECISION_SIGNAL;
   result.provider_window_valid = false;
   result.direction = decision.geometry.direction;
   result.decision = decision;
   result.geometry = decision.geometry;
   result.provider_identity = provider_evidence;
   result.current_entry_signal_compatible = false;
   result.order_execution_authorized = false;
   result.time_exit_consumer_owned = true;
   result.binding_status = "PROVIDER_EVIDENCE_REJECTED";
   result.refusal_reason = "";

   string reason = "";
   if(!OFP_ValidateThinkMarketsA2Evidence(provider_evidence, receipts, reason))
   {
      result.refusal_reason = reason;
      return false;
   }
   result.provider_window_valid = true;
   if(!result.component_signal_valid)
   {
      result.binding_status = "COMPONENT_SIGNAL_NOT_READY";
      result.refusal_reason = StringLen(decision.code) > 0
                              ? decision.code : "COMPONENT_SIGNAL_NOT_READY";
      return false;
   }

   result.binding_status = OFP_PROVIDER_CLASS_CURRENT_WINDOW;
   result.refusal_reason = "";
   return true;
}

#endif // EA_LAB_ORDERFLOW_PROXY_TEMPLATE_SEAM_MQH
