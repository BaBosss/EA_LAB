#ifndef ORDERFLOW_PROXY_COPY_EVIDENCE_MQH
#define ORDERFLOW_PROXY_COPY_EVIDENCE_MQH

enum OFPCopyCountBasis
{
   OFP_COUNT_BASIS_UNQUALIFIED = 0,
   OFP_COUNT_BASIS_FIXTURE_EXACT = 1
};

struct OFPCopyEvidence
{
   OFPCopyCountBasis count_basis;
   long expected_native_count;
   long returned_count;
   int  array_size;
   int  copy_error;
   int  rate_snapshot_error;
   long requested_start_msc;
   long requested_end_msc;
   long first_time_msc;
   long last_time_msc;
   bool timestamps_monotonic;
   bool timestamps_in_range;
   bool prices_valid;
   bool source_matches;
   bool symbol_matches;
   bool boundary_matches;
   bool rate_snapshot_stable;
   bool synchronized_before;
   bool synchronized_after;
};

struct OFPCopyValidation
{
   bool data_present;
   bool count_consistent;
   bool complete;
   string reason;
};

string OFP_CopyCountBasisName(const OFPCopyCountBasis basis)
{
   if(basis == OFP_COUNT_BASIS_FIXTURE_EXACT)
      return "FIXTURE_EXACT_NATIVE_EVENT_COUNT";
   return "UNQUALIFIED_COPY_TICKS_ALL_VS_MQLRATES_TICK_VOLUME";
}

void OFP_ResetCopyEvidence(OFPCopyEvidence &evidence)
{
   evidence.count_basis = OFP_COUNT_BASIS_UNQUALIFIED;
   evidence.expected_native_count = 0;
   evidence.returned_count = 0;
   evidence.array_size = 0;
   evidence.copy_error = 0;
   evidence.rate_snapshot_error = 0;
   evidence.requested_start_msc = 0;
   evidence.requested_end_msc = 0;
   evidence.first_time_msc = 0;
   evidence.last_time_msc = 0;
   evidence.timestamps_monotonic = true;
   evidence.timestamps_in_range = true;
   evidence.prices_valid = true;
   evidence.source_matches = true;
   evidence.symbol_matches = true;
   evidence.boundary_matches = true;
   evidence.rate_snapshot_stable = true;
   evidence.synchronized_before = true;
   evidence.synchronized_after = true;
}

void OFP_ValidateCopyEvidence(const OFPCopyEvidence &evidence,
                              OFPCopyValidation &validation)
{
   validation.data_present = evidence.returned_count > 0 || evidence.array_size > 0;
   validation.count_consistent = false;
   validation.complete = false;
   validation.reason = "COPY_EVIDENCE_REFUSED";

   if(evidence.expected_native_count <= 0)
   {
      validation.reason = "INVALID_EXPECTED_NATIVE_COUNT";
      return;
   }
   if(evidence.requested_start_msc <= 0 ||
      evidence.requested_end_msc <= evidence.requested_start_msc ||
      !evidence.boundary_matches)
   {
      validation.reason = "INTERVAL_BOUNDARY_MISMATCH";
      return;
   }
   if(!evidence.symbol_matches || !evidence.source_matches)
   {
      validation.reason = "COPY_PROVENANCE_MISMATCH";
      return;
   }
   if(evidence.copy_error != 0)
   {
      validation.reason = "COPY_ERROR_" + IntegerToString(evidence.copy_error);
      return;
   }
   if(evidence.rate_snapshot_error != 0)
   {
      validation.reason = "RATE_SNAPSHOT_ERROR_" + IntegerToString(evidence.rate_snapshot_error);
      return;
   }
   if(evidence.returned_count < 0 || evidence.array_size < 0 ||
      evidence.returned_count != evidence.array_size)
   {
      validation.reason = "COPY_COUNT_ARRAY_DISAGREEMENT";
      return;
   }
   if(evidence.returned_count < evidence.expected_native_count)
   {
      validation.reason = "COPY_COUNT_UNDER_EXPECTED";
      return;
   }
   if(evidence.returned_count > evidence.expected_native_count)
   {
      validation.reason = "COPY_COUNT_OVER_EXPECTED";
      return;
   }
   if(!evidence.synchronized_before)
   {
      validation.reason = "SERIES_UNSYNCHRONIZED_BEFORE";
      return;
   }
   if(!evidence.synchronized_after)
   {
      validation.reason = "SERIES_UNSYNCHRONIZED_AFTER";
      return;
   }
   if(!evidence.rate_snapshot_stable)
   {
      validation.reason = "RATE_SNAPSHOT_CHANGED";
      return;
   }
   if(!evidence.timestamps_monotonic)
   {
      validation.reason = "NONMONOTONIC_TICK_TIMESTAMPS";
      return;
   }
   if(!evidence.timestamps_in_range)
   {
      validation.reason = "TICK_OUTSIDE_INTERVAL";
      return;
   }
   if(!evidence.prices_valid)
   {
      validation.reason = "INVALID_TICK_PRICE";
      return;
   }

   validation.count_consistent = true;
   if(evidence.count_basis != OFP_COUNT_BASIS_FIXTURE_EXACT)
   {
      validation.reason = "COUNT_BASIS_UNQUALIFIED";
      return;
   }
   validation.complete = true;
   validation.reason = "COMPLETE_FIXTURE_EXACT_COUNT";
}

#endif
