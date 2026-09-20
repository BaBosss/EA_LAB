//+------------------------------------------------------------------+
//| OrderFlowProxyValidation.mqh                                     |
//| Fail-closed validation and completed-bar proxy calculations.     |
//+------------------------------------------------------------------+
#ifndef EA_LAB_ORDERFLOW_PROXY_VALIDATION_MQH
#define EA_LAB_ORDERFLOW_PROXY_VALIDATION_MQH

#include "OrderFlowProxyTypes.mqh"

const double OFP_EPSILON = 1.0e-9;
const string OFP_DATA_IDENTITY = "MT5_ACTIVITY_QUOTE_PROXY";
const string OFP_PROFILE_IDENTITY = "TICK_ACTIVITY_PROFILE";
const string OFP_IMBALANCE_IDENTITY = "QUOTE_DIRECTION_IMBALANCE_PROXY";
const string OFP_PROFILE_RECIPE_ID = "MT5_TICK_ACTIVITY_PROFILE_V1";
const string OFP_SESSION_ID = "MT5_BROKER_D1_BAR_V1";

bool OFP_IsFinitePositive(const double value)
{
   return MathIsValidNumber(value) && value > 0.0;
}

bool OFP_ValidateContract(const OFPDataContract &contract,
                          string &reason)
{
   if(contract.data_identity != OFP_DATA_IDENTITY ||
      contract.profile_identity != OFP_PROFILE_IDENTITY ||
      contract.imbalance_identity != OFP_IMBALANCE_IDENTITY ||
      contract.profile_recipe_id != OFP_PROFILE_RECIPE_ID ||
      contract.session_id != OFP_SESSION_ID ||
      StringLen(contract.signal_instrument_id) == 0 ||
      StringLen(contract.signal_source_id) == 0)
   {
      reason = "PROXY_LABEL_REQUIRED";
      return false;
   }
   return true;
}

bool OFP_ValidateProfile(const OFPProfile &profile,
                         const OFPDataContract &contract,
                         const datetime evaluation_time,
                         string &reason)
{
   if(profile.profile_identity != OFP_PROFILE_IDENTITY ||
      profile.profile_recipe_id != OFP_PROFILE_RECIPE_ID ||
      profile.session_id != OFP_SESSION_ID ||
      StringLen(profile.record_id) == 0)
   {
      reason = "INVALID_PROXY_PROFILE_IDENTITY";
      return false;
   }
   if(profile.instrument_id != contract.signal_instrument_id ||
      profile.source_id != contract.signal_source_id)
   {
      reason = "CROSS_INSTRUMENT_OR_SOURCE";
      return false;
   }
   if(StringLen(profile.previous_d1_record_id) == 0 ||
      StringLen(profile.current_d1_record_id) == 0 ||
      profile.previous_d1_record_id == profile.current_d1_record_id ||
      profile.previous_d1_sequence == 0 ||
      profile.current_d1_sequence != profile.previous_d1_sequence + 1 ||
      profile.previous_d1_open_time != profile.session_start ||
      profile.current_d1_open_time != profile.session_end)
   {
      reason = "INVALID_D1_BOUNDARY";
      return false;
   }
   if(!profile.completed || profile.session_start <= 0 ||
      profile.session_end <= profile.session_start ||
      profile.available_at < profile.session_end ||
      profile.available_at > evaluation_time)
   {
      reason = "INVALID_COMPLETED_PROXY_PROFILE";
      return false;
   }
   if(!OFP_IsFinitePositive(profile.bin_size) ||
      !OFP_IsFinitePositive(profile.val) ||
      !OFP_IsFinitePositive(profile.poc) ||
      !OFP_IsFinitePositive(profile.vah) ||
      !(profile.val < profile.poc && profile.poc < profile.vah) ||
      profile.total_activity == 0 ||
      profile.value_area_activity == 0 ||
      profile.value_area_activity > profile.total_activity)
   {
      reason = "INVALID_PROXY_PROFILE_GEOMETRY";
      return false;
   }
   return true;
}

bool OFP_ValidateContexts(const OFPContextBar &contexts[],
                          const OFPProfile &profile,
                          const OFPDataContract &contract,
                          const datetime evaluation_time,
                          string &reason)
{
   int count = ArraySize(contexts);
   if(count <= 0)
   {
      reason = "M15_CONTEXT_REQUIRED";
      return false;
   }
   for(int i = 0; i < count; ++i)
   {
      OFPContextBar context = contexts[i];
      if(context.instrument_id != contract.signal_instrument_id ||
         context.source_id != contract.signal_source_id)
      {
         reason = "CROSS_INSTRUMENT_OR_SOURCE";
         return false;
      }
      if(context.d1_record_id != profile.current_d1_record_id ||
         context.d1_sequence != profile.current_d1_sequence ||
         context.d1_open_time != profile.current_d1_open_time)
      {
         reason = "STALE_OR_MIXED_D1_SESSION";
         return false;
      }
      if(StringLen(context.record_id) == 0 || context.sequence == 0 ||
         !context.completed || context.period_seconds != 900 ||
         context.open_time <= 0 ||
         context.close_time - context.open_time != 900 ||
         context.available_at < context.close_time ||
         context.available_at > evaluation_time ||
         context.open_time < profile.current_d1_open_time ||
         profile.session_end >= context.close_time ||
         !OFP_IsFinitePositive(context.close))
      {
         reason = "INVALID_OR_NONCAUSAL_M15_CONTEXT";
         return false;
      }
      for(int j = 0; j < i; ++j)
      {
         if(context.record_id == contexts[j].record_id)
         {
            reason = "DUPLICATE_M15_RECORD_ID";
            return false;
         }
      }
      if(i > 0 &&
         (context.sequence <= contexts[i-1].sequence ||
          context.open_time < contexts[i-1].close_time ||
          context.close_time <= contexts[i-1].close_time ||
          context.available_at <= contexts[i-1].available_at))
      {
         reason = "NON_MONOTONIC_M15_CONTEXT";
         return false;
      }
   }
   return true;
}

bool OFP_SelectContext(const OFPContextBar &contexts[],
                       const datetime available_at,
                       OFPContextBar &selected)
{
   int index = -1;
   for(int i = 0; i < ArraySize(contexts); ++i)
   {
      if(contexts[i].available_at <= available_at)
         index = i;
   }
   if(index < 0)
      return false;
   selected = contexts[index];
   return true;
}

bool OFP_ValidOHLC(const OFPBar &bar)
{
   return OFP_IsFinitePositive(bar.open) &&
          OFP_IsFinitePositive(bar.high) &&
          OFP_IsFinitePositive(bar.low) &&
          OFP_IsFinitePositive(bar.close) &&
          bar.high >= MathMax(bar.open, bar.close) &&
          bar.low <= MathMin(bar.open, bar.close) &&
          bar.high >= bar.low;
}

bool OFP_ValidateBars(const OFPBar &bars[],
                      const OFPProfile &profile,
                      const OFPDataContract &contract,
                      const datetime evaluation_time,
                      string &reason)
{
   int count = ArraySize(bars);
   if(count <= 0)
   {
      reason = "M5_HISTORY_REQUIRED";
      return false;
   }
   for(int i = 0; i < count; ++i)
   {
      OFPBar bar = bars[i];
      if(bar.instrument_id != contract.signal_instrument_id ||
         bar.source_id != contract.signal_source_id)
      {
         reason = "CROSS_INSTRUMENT_OR_SOURCE";
         return false;
      }
      if(bar.d1_record_id != profile.current_d1_record_id ||
         bar.d1_sequence != profile.current_d1_sequence ||
         bar.d1_open_time != profile.current_d1_open_time)
      {
         reason = "STALE_OR_MIXED_D1_SESSION";
         return false;
      }
      if(StringLen(bar.record_id) == 0 || bar.sequence == 0 ||
         !bar.completed || bar.period_seconds != 300 ||
         bar.open_time <= 0 || bar.close_time - bar.open_time != 300 ||
         bar.available_at < bar.close_time ||
         bar.available_at > evaluation_time ||
         bar.open_time < profile.current_d1_open_time ||
         !OFP_ValidOHLC(bar) || bar.tick_volume < 0 ||
         bar.quote_up_count < 0 || bar.quote_down_count < 0 ||
         bar.quote_unchanged_count < 0)
      {
         reason = "INVALID_OR_NONCAUSAL_M5_BAR";
         return false;
      }
      for(int j = 0; j < i; ++j)
      {
         if(bar.record_id == bars[j].record_id)
         {
            reason = "DUPLICATE_M5_RECORD_ID";
            return false;
         }
      }
      if(i > 0 &&
         (bar.sequence <= bars[i-1].sequence ||
          bar.open_time < bars[i-1].close_time ||
          bar.close_time <= bars[i-1].close_time ||
          bar.available_at <= bars[i-1].available_at))
      {
         reason = "NON_MONOTONIC_M5_HISTORY";
         return false;
      }
   }
   return true;
}

bool OFP_ValidateEnvelope(const OFPBar &bars[],
                          const OFPDecisionEnvelope &envelope,
                          string &reason)
{
   int count = ArraySize(bars);
   if(count <= 0 || envelope.evaluation_time <= 0 ||
      StringLen(envelope.current_closed_bar_record_id) == 0)
   {
      reason = "INVALID_DECISION_ENVELOPE";
      return false;
   }
   OFPBar last = bars[count-1];
   if(envelope.current_closed_bar_record_id != last.record_id ||
      envelope.current_closed_bar_close_time != last.close_time ||
      envelope.evaluation_time < last.available_at)
   {
      reason = "DECISION_ENVELOPE_MISMATCH";
      return false;
   }
   if(envelope.evaluation_time >= last.close_time + last.period_seconds)
   {
      reason = "DECISION_WINDOW_MISSING_CLOSED_BAR";
      return false;
   }
   return true;
}

bool OFP_Previous20MedianTickVolume(const OFPBar &bars[],
                                    const int index,
                                    double &median)
{
   if(index < 20 || index >= ArraySize(bars))
      return false;
   double values[];
   ArrayResize(values, 20);
   for(int i = 0; i < 20; ++i)
   {
      if(!bars[index-20+i].completed || bars[index-20+i].tick_volume < 0)
         return false;
      values[i] = (double)bars[index-20+i].tick_volume;
   }
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
   return MathIsValidNumber(median) && median > 0.0;
}

bool OFP_RelativeActivityPasses(const OFPBar &bars[],
                                const int index)
{
   double median = 0.0;
   return OFP_Previous20MedianTickVolume(bars, index, median) &&
          bars[index].completed &&
          (double)bars[index].tick_volume + OFP_EPSILON >= 1.50 * median;
}

bool OFP_ATR14Preceding(const OFPBar &bars[],
                        const int index,
                        double &atr)
{
   if(index < 15 || index >= ArraySize(bars))
      return false;
   double total = 0.0;
   for(int i = index - 14; i < index; ++i)
   {
      double previous_close = bars[i-1].close;
      double true_range = MathMax(bars[i].high - bars[i].low,
                                  MathMax(MathAbs(bars[i].high - previous_close),
                                          MathAbs(bars[i].low - previous_close)));
      if(!OFP_IsFinitePositive(true_range))
         return false;
      total += true_range;
   }
   atr = total / 14.0;
   return OFP_IsFinitePositive(atr);
}

bool OFP_QuoteImbalance(const OFPBar &bar,
                        double &ratio)
{
   long denominator = bar.quote_up_count + bar.quote_down_count;
   if(!bar.quote_proxy_valid || denominator <= 0)
      return false;
   ratio = (double)(bar.quote_up_count - bar.quote_down_count) /
           (double)denominator;
   return MathIsValidNumber(ratio);
}

bool OFP_CountQuoteMoves(const double &mids[],
                         long &up_count,
                         long &down_count,
                         long &unchanged_count,
                         double &ratio)
{
   up_count = 0;
   down_count = 0;
   unchanged_count = 0;
   for(int i = 0; i < ArraySize(mids); ++i)
   {
      if(!OFP_IsFinitePositive(mids[i]))
         return false;
      if(i == 0)
         continue;
      if(mids[i] > mids[i-1])
         ++up_count;
      else if(mids[i] < mids[i-1])
         ++down_count;
      else
         ++unchanged_count;
   }
   long denominator = up_count + down_count;
   if(denominator <= 0)
      return false;
   ratio = (double)(up_count - down_count) / (double)denominator;
   return true;
}

bool OFP_BuildBarQuoteProxy(const OFPQuoteTick &ticks[],
                            OFPBar &bar,
                            string &reason)
{
   bar.quote_up_count = 0;
   bar.quote_down_count = 0;
   bar.quote_unchanged_count = 0;
   bar.quote_proxy_valid = false;
   long start_msc = (long)bar.open_time * 1000;
   long end_msc = (long)bar.close_time * 1000;
   long previous_time = -1;
   bool have_previous_mid = false;
   double previous_mid = 0.0;
   for(int i = 0; i < ArraySize(ticks); ++i)
   {
      if(ticks[i].instrument_id != bar.instrument_id ||
         ticks[i].source_id != bar.source_id)
      {
         reason = "CROSS_INSTRUMENT_OR_SOURCE";
         return false;
      }
      if(ticks[i].time_msc <= previous_time)
      {
         reason = "NON_MONOTONIC_QUOTE_TICKS";
         return false;
      }
      previous_time = ticks[i].time_msc;
      if(ticks[i].time_msc < start_msc || ticks[i].time_msc >= end_msc)
         continue;
      if(!OFP_IsFinitePositive(ticks[i].bid) ||
         !OFP_IsFinitePositive(ticks[i].ask))
         continue; // Last is deliberately never substituted.
      double mid = (ticks[i].bid + ticks[i].ask) * 0.5;
      if(have_previous_mid)
      {
         if(mid > previous_mid)
            ++bar.quote_up_count;
         else if(mid < previous_mid)
            ++bar.quote_down_count;
         else
            ++bar.quote_unchanged_count;
      }
      previous_mid = mid;
      have_previous_mid = true;
   }
   if(bar.quote_up_count + bar.quote_down_count <= 0)
   {
      reason = "QUOTE_IMBALANCE_DENOMINATOR_ZERO";
      return false;
   }
   bar.quote_proxy_valid = true;
   return true;
}

bool OFP_RangeOverlaps(const double low_a,
                       const double high_a,
                       const double low_b,
                       const double high_b)
{
   return high_a >= low_b && low_a <= high_b;
}

bool OFP_ValidateQuoteProvenance(const OFPProspectiveQuote &quote,
                                 const OFPProfile &profile,
                                 const OFPDataContract &contract,
                                 string &reason)
{
   if(quote.instrument_id != contract.signal_instrument_id ||
      quote.source_id != contract.signal_source_id)
   {
      reason = "CROSS_INSTRUMENT_OR_SOURCE";
      return false;
   }
   if(quote.d1_record_id != profile.current_d1_record_id ||
      quote.d1_sequence != profile.current_d1_sequence ||
      quote.d1_open_time != profile.current_d1_open_time)
   {
      reason = "STALE_OR_MIXED_D1_SESSION";
      return false;
   }
   return true;
}

bool OFP_ValidateQuote(const OFPProspectiveQuote &quote,
                       const OFPBar &trigger,
                       const OFPProfile &profile,
                       const OFPDataContract &contract,
                       const OFPDecisionEnvelope &envelope,
                       string &reason)
{
   if(!OFP_ValidateQuoteProvenance(quote, profile, contract, reason))
      return false;
   if(trigger.record_id != envelope.current_closed_bar_record_id ||
      StringLen(quote.record_id) == 0 ||
      quote.observed_at <= trigger.close_time ||
      quote.observed_at > envelope.evaluation_time ||
      quote.available_at < quote.observed_at ||
      quote.available_at > envelope.evaluation_time ||
      !OFP_IsFinitePositive(quote.bid) ||
      !OFP_IsFinitePositive(quote.ask) ||
      quote.ask < quote.bid ||
      !MathIsValidNumber(quote.all_in_cost_price) ||
      quote.all_in_cost_price < 0.0)
   {
      reason = "INVALID_PROSPECTIVE_QUOTE";
      return false;
   }
   return true;
}

bool OFP_VariantNeedsActivity(const ENUM_OFP_VARIANT variant)
{
   return variant == OFPR_01_TICK_ACTIVITY ||
          variant == OFPR_02_QUOTE_IMBALANCE ||
          variant == OFPC_01_TICK_ACTIVITY ||
          variant == OFPC_02_QUOTE_IMBALANCE;
}

bool OFP_VariantNeedsImbalance(const ENUM_OFP_VARIANT variant)
{
   return variant == OFPR_02_QUOTE_IMBALANCE ||
          variant == OFPC_02_QUOTE_IMBALANCE;
}

#endif // EA_LAB_ORDERFLOW_PROXY_VALIDATION_MQH
