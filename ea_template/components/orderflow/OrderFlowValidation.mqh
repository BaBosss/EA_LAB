//+------------------------------------------------------------------+
//| OrderFlowValidation.mqh                                          |
//| Fail-closed validation and shared deterministic calculations.    |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ORDERFLOW_VALIDATION_MQH
#define EA_LAB_ORDERFLOW_VALIDATION_MQH

#include "OrderFlowTypes.mqh"

const double OF_EPSILON = 1.0e-9;

bool OF_IsFinite(const double value)
{
   return MathIsValidNumber(value);
}

bool OF_HasText(const string value)
{
   return StringLen(value) > 0;
}

bool OF_ValidFreshnessPolicy(const OFFreshnessPolicy &policy,
                             string &reason)
{
   if(policy.max_m5_age_seconds <= 0 ||
      policy.max_m15_age_seconds <= 0 ||
      policy.max_profile_age_seconds <= 0 ||
      policy.max_quote_age_seconds <= 0)
   {
      reason = "MISSING_EXPLICIT_FRESHNESS_POLICY";
      return false;
   }
   if(policy.required_record_class != OF_RECORD_CLASS_QUALIFIED &&
      policy.required_record_class != OF_RECORD_CLASS_FIXTURE)
   {
      reason = "INVALID_REQUIRED_RECORD_CLASS";
      return false;
   }
   return true;
}

bool OF_ValidateContract(const OFDataContract &contract,
                         const OFFreshnessPolicy &policy,
                         string &reason)
{
   if(!OF_ValidFreshnessPolicy(policy, reason))
      return false;

   if(!OF_HasText(contract.dataset_id) ||
      !OF_HasText(contract.source_id) ||
      !OF_HasText(contract.source_revision) ||
      !OF_HasText(contract.signal_instrument_id) ||
      !OF_HasText(contract.profile_instrument_id) ||
      !OF_HasText(contract.session_definition_id) ||
      !OF_HasText(contract.timezone_ruleset_id) ||
      !OF_HasText(contract.profile_algorithm_id) ||
      !OF_HasText(contract.value_area_algorithm_id) ||
      !OF_HasText(contract.volume_provenance_id))
   {
      reason = "MISSING_REQUIRED_PIN";
      return false;
   }

   if(contract.record_class != policy.required_record_class)
   {
      reason = "RECORD_CLASS_MISMATCH";
      return false;
   }

   if(contract.record_class == OF_RECORD_CLASS_QUALIFIED && !contract.source_qualified)
   {
      reason = "UNQUALIFIED_SOURCE";
      return false;
   }

   if(contract.data_identity != OF_DATA_IDENTITY_TRUE_ORDERFLOW)
   {
      reason = (contract.data_identity == OF_DATA_IDENTITY_PRICE_ACTION_PROXY)
               ? "PROXY_NOT_TRUE_ORDERFLOW"
               : "INVALID_DATA_IDENTITY";
      return false;
   }

   if(contract.volume_provenance != OF_VOLUME_EXECUTED_ASK_BID)
   {
      reason = "EXECUTED_ASK_BID_REQUIRED";
      return false;
   }

   if(contract.signal_instrument_id != contract.profile_instrument_id)
   {
      if(!contract.instrument_mapping_qualified ||
         !OF_HasText(contract.instrument_mapping_id))
      {
         reason = "UNQUALIFIED_INSTRUMENT_MAPPING";
         return false;
      }
   }
   else if(contract.instrument_mapping_qualified &&
           !OF_HasText(contract.instrument_mapping_id))
   {
      reason = "CONTRADICTORY_MAPPING_PIN";
      return false;
   }

   return true;
}

bool OF_ValidOHLC(const double open,
                  const double high,
                  const double low,
                  const double close)
{
   if(!OF_IsFinite(open) || !OF_IsFinite(high) ||
      !OF_IsFinite(low) || !OF_IsFinite(close))
      return false;
   if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0)
      return false;
   if(high < low || high + OF_EPSILON < MathMax(open, close) ||
      low - OF_EPSILON > MathMin(open, close))
      return false;
   return true;
}

bool OF_ValidateProfile(const OFProfile &profile,
                        const OFDataContract &contract,
                        const OFFreshnessPolicy &policy,
                        const datetime as_of,
                        string &reason)
{
   if(!OF_HasText(profile.record_id) || !OF_HasText(profile.profile_id) ||
      !OF_HasText(profile.profile_revision) ||
      profile.source_revision != contract.source_revision)
   {
      reason = "PROFILE_PIN_MISMATCH";
      return false;
   }
   if(!profile.completed || profile.session_start <= 0 ||
      profile.session_end <= profile.session_start)
   {
      reason = "PROFILE_SESSION_NOT_COMPLETED";
      return false;
   }
   if(profile.available_at < profile.session_end || profile.available_at > as_of)
   {
      reason = "PROFILE_FUTURE_OR_CLOCK_CONTRADICTION";
      return false;
   }
   if((long)(as_of - profile.available_at) > policy.max_profile_age_seconds)
   {
      reason = "STALE_PROFILE";
      return false;
   }
   if(!OF_IsFinite(profile.val) || !OF_IsFinite(profile.poc) ||
      !OF_IsFinite(profile.vah) || !(profile.val < profile.poc && profile.poc < profile.vah))
   {
      reason = "CONTRADICTORY_PROFILE_LEVELS";
      return false;
   }
   return true;
}

bool OF_ValidateContext(const OFContextBar &bar,
                        const OFDataContract &contract,
                        const OFProfile &profile,
                        const OFFreshnessPolicy &policy,
                        const datetime as_of,
                        string &reason)
{
   if(!OF_HasText(bar.record_id) || bar.source_revision != contract.source_revision ||
      bar.sequence == 0)
   {
      reason = "M15_PIN_MISMATCH";
      return false;
   }
   if(bar.period_seconds != 900 || !bar.completed ||
      bar.open_time <= 0 || bar.close_time - bar.open_time != bar.period_seconds ||
      bar.available_at < bar.close_time || bar.available_at > as_of)
   {
      reason = "M15_INCOMPLETE_OR_FUTURE";
      return false;
   }
   if(profile.session_end >= bar.close_time)
   {
      reason = "PROFILE_NOT_PRIOR_TO_CONTEXT";
      return false;
   }
   if((long)(as_of - bar.available_at) > policy.max_m15_age_seconds)
   {
      reason = "STALE_M15_CONTEXT";
      return false;
   }
   if(!OF_ValidOHLC(bar.open, bar.high, bar.low, bar.close))
   {
      reason = "INVALID_M15_OHLC";
      return false;
   }
   return true;
}

bool OF_ValidateBars(const OFBar &bars[],
                     const OFDataContract &contract,
                     const OFFreshnessPolicy &policy,
                     const datetime as_of,
                     string &reason)
{
   int count = ArraySize(bars);
   if(count <= 0)
   {
      reason = "MISSING_M5_HISTORY";
      return false;
   }

   for(int i = 0; i < count; ++i)
   {
      OFBar bar = bars[i];
      if(!OF_HasText(bar.record_id) || bar.source_revision != contract.source_revision ||
         bar.sequence == 0)
      {
         reason = "M5_PIN_MISMATCH";
         return false;
      }
      if(bar.period_seconds != 300 || !bar.completed ||
         bar.open_time <= 0 || bar.close_time - bar.open_time != bar.period_seconds ||
         bar.available_at < bar.close_time || bar.available_at > as_of)
      {
         reason = "M5_INCOMPLETE_OR_FUTURE";
         return false;
      }
      if(!OF_ValidOHLC(bar.open, bar.high, bar.low, bar.close))
      {
         reason = "INVALID_M5_OHLC";
         return false;
      }
      if(!OF_IsFinite(bar.executed_ask_volume) ||
         !OF_IsFinite(bar.executed_bid_volume) ||
         !OF_IsFinite(bar.total_executed_volume) ||
         bar.executed_ask_volume < 0.0 || bar.executed_bid_volume < 0.0 ||
         bar.total_executed_volume <= 0.0)
      {
         reason = "INVALID_EXECUTED_VOLUME";
         return false;
      }
      double sides = bar.executed_ask_volume + bar.executed_bid_volume;
      double tolerance = MathMax(OF_EPSILON, bar.total_executed_volume * 1.0e-9);
      if(sides <= 0.0 || MathAbs(sides - bar.total_executed_volume) > tolerance)
      {
         reason = "CONTRADICTORY_EXECUTED_VOLUME";
         return false;
      }
      if(i > 0)
      {
         if(bar.sequence <= bars[i-1].sequence ||
            bar.open_time < bars[i-1].close_time ||
            bar.close_time <= bars[i-1].close_time ||
            bar.available_at <= bars[i-1].available_at)
         {
            reason = "M5_NON_MONOTONIC_OR_DUPLICATE";
            return false;
         }
         for(int j = 0; j < i; ++j)
         {
            if(bar.record_id == bars[j].record_id)
            {
               reason = "M5_DUPLICATE_RECORD_ID";
               return false;
            }
         }
      }
   }

   if((long)(as_of - bars[count-1].available_at) > policy.max_m5_age_seconds)
   {
      reason = "STALE_M5_HISTORY";
      return false;
   }
   return true;
}

bool OF_ValidateQuote(const OFQuote &quote,
                      const OFDataContract &contract,
                      const OFFreshnessPolicy &policy,
                      const datetime trigger_close_time,
                      const datetime as_of,
                      string &reason)
{
   if(!OF_HasText(quote.record_id) || quote.source_id != contract.source_id ||
      quote.source_revision != contract.source_revision)
   {
      reason = "QUOTE_PIN_MISMATCH";
      return false;
   }
   if(quote.observed_at < trigger_close_time ||
      quote.available_at < quote.observed_at || quote.available_at > as_of)
   {
      reason = "QUOTE_FUTURE_OR_PRE_TRIGGER";
      return false;
   }
   if((long)(as_of - quote.available_at) > policy.max_quote_age_seconds)
   {
      reason = "STALE_QUOTE";
      return false;
   }
   if(!OF_IsFinite(quote.bid) || !OF_IsFinite(quote.ask) ||
      !OF_IsFinite(quote.all_in_cost_price) || quote.bid <= 0.0 ||
      quote.ask < quote.bid || quote.all_in_cost_price < 0.0)
   {
      reason = "INVALID_QUOTE_OR_COST";
      return false;
   }
   return true;
}

double OF_SignedDelta(const OFBar &bar)
{
   double denominator = bar.executed_ask_volume + bar.executed_bid_volume;
   if(denominator <= 0.0)
      return 0.0;
   return (bar.executed_ask_volume - bar.executed_bid_volume) / denominator;
}

bool OF_Previous20MedianVolume(const OFBar &bars[],
                               const int index,
                               double &median)
{
   if(index < 20 || index >= ArraySize(bars))
      return false;
   double values[];
   ArrayResize(values, 20);
   for(int i = 0; i < 20; ++i)
      values[i] = bars[index - 20 + i].total_executed_volume;

   for(int i = 1; i < 20; ++i)
   {
      double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
      {
         values[j+1] = values[j];
         --j;
      }
      values[j+1] = key;
   }
   median = (values[9] + values[10]) * 0.5;
   return OF_IsFinite(median) && median > 0.0;
}

bool OF_ATR14Preceding(const OFBar &bars[],
                       const int index,
                       double &atr)
{
   if(index < 15 || index >= ArraySize(bars))
      return false;
   double total = 0.0;
   for(int i = index - 14; i < index; ++i)
   {
      double previous_close = bars[i-1].close;
      double tr = MathMax(bars[i].high - bars[i].low,
                          MathMax(MathAbs(bars[i].high - previous_close),
                                  MathAbs(bars[i].low - previous_close)));
      if(!OF_IsFinite(tr) || tr <= 0.0)
         return false;
      total += tr;
   }
   atr = total / 14.0;
   return OF_IsFinite(atr) && atr > 0.0;
}

bool OF_RangeOverlaps(const double low_a,
                      const double high_a,
                      const double low_b,
                      const double high_b)
{
   return high_a >= low_b && low_a <= high_b;
}

bool OF_StatePinsMatch(const OFState &state,
                       const OFDataContract &contract,
                       const OFProfile &profile,
                       const OFContextBar &context)
{
   return state.dataset_id == contract.dataset_id &&
          state.source_revision == contract.source_revision &&
          state.profile_id == profile.profile_id &&
          state.profile_revision == profile.profile_revision &&
          state.context_record_id == context.record_id;
}

void OF_PinState(OFState &state,
                 const OFDataContract &contract,
                 const OFProfile &profile,
                 const OFContextBar &context)
{
   state.dataset_id        = contract.dataset_id;
   state.source_revision   = contract.source_revision;
   state.profile_id        = profile.profile_id;
   state.profile_revision  = profile.profile_revision;
   state.context_record_id = context.record_id;
}

#endif // EA_LAB_ORDERFLOW_VALIDATION_MQH
