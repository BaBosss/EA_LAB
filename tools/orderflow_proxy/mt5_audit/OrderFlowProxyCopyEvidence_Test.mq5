//+------------------------------------------------------------------+
//| OrderFlowProxyCopyEvidence_Test.mq5                              |
//| Compile-only harness for the shared pure completeness predicate. |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "OrderFlowProxyCopyEvidence.mqh"

void OnStart()
{
   OFPCopyEvidence evidence;
   OFPCopyValidation validation;
   OFP_ResetCopyEvidence(evidence);
   evidence.count_basis = OFP_COUNT_BASIS_FIXTURE_EXACT;
   evidence.expected_native_count = 2;
   evidence.returned_count = 2;
   evidence.array_size = 2;
   evidence.requested_start_msc = 1000;
   evidence.requested_end_msc = 2000;
   evidence.first_time_msc = 1100;
   evidence.last_time_msc = 1900;
   OFP_ValidateCopyEvidence(evidence, validation);
   if(!validation.complete || !validation.count_consistent)
      Print("OFP_COPY_EVIDENCE_FIXTURE_POSITIVE_FAILED ", validation.reason);

   evidence.count_basis = OFP_COUNT_BASIS_UNQUALIFIED;
   OFP_ValidateCopyEvidence(evidence, validation);
   if(validation.complete || !validation.count_consistent ||
      validation.reason != "COUNT_BASIS_UNQUALIFIED")
      Print("OFP_COPY_EVIDENCE_UNQUALIFIED_REFUSAL_FAILED ", validation.reason);

   evidence.copy_error = 4403;
   OFP_ValidateCopyEvidence(evidence, validation);
   if(validation.complete || validation.reason != "COPY_ERROR_4403")
      Print("OFP_COPY_EVIDENCE_ERROR_REFUSAL_FAILED ", validation.reason);
}
