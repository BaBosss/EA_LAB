//+------------------------------------------------------------------+
//| OrderFlowTemplateSeam.mqh                                       |
//| Geometry-preserving proposal for a future qualified consumer.    |
//| Deliberately does NOT include or return current EntrySignal.      |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ORDERFLOW_TEMPLATE_SEAM_MQH
#define EA_LAB_ORDERFLOW_TEMPLATE_SEAM_MQH

#include "OrderFlowTypes.mqh"

struct OFTemplateSeamProposal
{
   bool       component_signal_valid;
   int        direction;
   OFGeometry geometry;
   bool       current_entry_signal_compatible;
   bool       order_execution_authorized;
   bool       time_exit_implemented;
   string     binding_status;
};

bool OF_BuildTemplateSeamProposal(const OFDecision &decision,
                                  OFTemplateSeamProposal &proposal)
{
   proposal.component_signal_valid       = decision.decision == OF_DECISION_SIGNAL;
   proposal.direction                    = decision.geometry.direction;
   proposal.geometry                     = decision.geometry;
   proposal.current_entry_signal_compatible = false;
   proposal.order_execution_authorized   = false;
   proposal.time_exit_implemented        = false;
   proposal.binding_status               = "TEMPLATE_EXIT_BINDING_REQUIRED";
   return proposal.component_signal_valid;
}

#endif // EA_LAB_ORDERFLOW_TEMPLATE_SEAM_MQH
