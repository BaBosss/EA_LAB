//+------------------------------------------------------------------+
//| OrderFlowProxyAvailabilityAudit.mq5                              |
//| Read-only MT5 service: capability audit, never strategy quality. |
//+------------------------------------------------------------------+
#property strict
#property service
#property version "1.00"
#property description "Non-trading MT5 activity/quote proxy availability audit"

#include "OrderFlowProxyCopyEvidence.mqh"

input datetime InpCoverageFrom = D'2020.01.01 00:00:00';
input datetime InpCoverageTo = 0;
input string InpOutputJsonl = "EA_LAB_orderflow_proxy_availability.jsonl";

struct RateAudit
{
   long     server_first_date;
   long     last_bar_date;
   int      copied;
   long     first_copied;
   long     last_copied;
   long     tick_volume_positive;
   long     tick_volume_zero;
   long     real_volume_positive;
   long     real_volume_zero;
   bool     copy_failed;
   int      copy_error;
};

struct TickAudit
{
   ulong total;
   long  first_time_msc;
   long  last_time_msc;
   ulong bid_ask_valid;
   ulong last_valid;
   ulong volume_positive;
   ulong volume_real_positive;
   ulong flag_last;
   ulong flag_volume;
   ulong flag_bid;
   ulong flag_ask;
   ulong up_count;
   ulong down_count;
   ulong unchanged_count;
   long  copy_failures;
   int   last_copy_error;
   long  zero_copy_chunks;
   long  m5_boundary_resets;
   long  directional_bars;
};

struct CapabilityAudit
{
   bool   d1_pair_copy_ok;
   int    d1_pair_copy_error;
   long   previous_d1_open;
   long   current_d1_open;
   string previous_d1_record_id;
   string current_d1_record_id;
   bool   profile_tick_copy_ok;
   bool   profile_count_consistent;
   bool   profile_complete;
   long   profile_expected_count;
   long   profile_returned_count;
   int    profile_array_size;
   int    profile_copy_error;
   int    profile_rate_snapshot_error;
   string profile_reason;
   string profile_interval_receipt;
   ulong  profile_bid_ask_valid;
   bool   m5_window_copy_ok;
   int    m5_window_copy_error;
   bool   m5_sequence_ok;
   bool   m5_positive_tick_volume_all;
   long   candidate_m5_open;
   long   quote_copy_failures;
   long   quote_data_present_intervals;
   long   quote_count_consistent_intervals;
   long   quote_complete_intervals;
   string quote_interval_receipts;
   string count_basis;
   bool   completeness_qualified;
   long   quote_zero_denominator_bars;
   long   candidate_up_count;
   long   candidate_down_count;
   long   candidate_unchanged_count;
};

string AuditUpper(string value)
{
   StringToUpper(value);
   return value;
}

string JsonEscape(const string value)
{
   string escaped = value;
   StringReplace(escaped, "\\", "\\\\");
   StringReplace(escaped, "\"", "\\\"");
   StringReplace(escaped, "\r", "\\r");
   StringReplace(escaped, "\n", "\\n");
   return escaped;
}

string JsonString(const string value)
{
   return "\"" + JsonEscape(value) + "\"";
}

string JsonBool(const bool value)
{
   return value ? "true" : "false";
}

string LongToString(const long value)
{
   return StringFormat("%I64d", value);
}

bool SuffixCharactersValid(const string suffix)
{
   for(int i = 0; i < StringLen(suffix); ++i)
   {
      ushort character = StringGetCharacter(suffix, i);
      bool valid = (character >= 'A' && character <= 'Z') ||
                   (character >= 'a' && character <= 'z') ||
                   (character >= '0' && character <= '9') ||
                   character == '.' || character == '_' || character == '-';
      if(!valid)
         return false;
   }
   return true;
}

bool CurrencyMetadataMatches(const string symbol,
                             const string logical)
{
   if(StringLen(logical) != 6)
      return false;
   string expected_base = StringSubstr(logical, 0, 3);
   string expected_profit = StringSubstr(logical, 3, 3);
   string actual_base = AuditUpper(SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE));
   string actual_profit = AuditUpper(SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT));
   if(StringLen(actual_base) == 0 || StringLen(actual_profit) == 0)
      return true; // Name matching remains explicit; missing metadata is reported separately.
   return actual_base == expected_base && actual_profit == expected_profit;
}

int DiscoverExactBrokerSymbol(const string logical,
                              string &exact_symbol,
                              string &suffix,
                              string &candidates)
{
   exact_symbol = "";
   suffix = "";
   candidates = "";
   string logical_upper = AuditUpper(logical);
   int matches = 0;
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; ++i)
   {
      string symbol = SymbolName(i, false);
      string symbol_upper = AuditUpper(symbol);
      if(StringFind(symbol_upper, logical_upper, 0) != 0)
         continue;
      string found_suffix = StringSubstr(symbol, StringLen(logical));
      if(!SuffixCharactersValid(found_suffix) ||
         !CurrencyMetadataMatches(symbol, logical_upper))
         continue;
      if(matches > 0)
         candidates += "|";
      candidates += symbol;
      exact_symbol = symbol;
      suffix = found_suffix;
      ++matches;
   }
   if(matches != 1)
   {
      exact_symbol = "";
      suffix = "";
   }
   return matches;
}

void ResetRateAudit(RateAudit &audit)
{
   audit.server_first_date = 0;
   audit.last_bar_date = 0;
   audit.copied = 0;
   audit.first_copied = 0;
   audit.last_copied = 0;
   audit.tick_volume_positive = 0;
   audit.tick_volume_zero = 0;
   audit.real_volume_positive = 0;
   audit.real_volume_zero = 0;
   audit.copy_failed = false;
   audit.copy_error = 0;
}

void AuditRates(const string symbol,
                const ENUM_TIMEFRAMES timeframe,
                const datetime from_time,
                const datetime to_time,
                RateAudit &audit)
{
   ResetRateAudit(audit);
   long value = 0;
   if(SeriesInfoInteger(symbol, timeframe, SERIES_SERVER_FIRSTDATE, value))
      audit.server_first_date = value;
   value = 0;
   if(SeriesInfoInteger(symbol, timeframe, SERIES_LASTBAR_DATE, value))
      audit.last_bar_date = value;

   MqlRates rates[];
   ResetLastError();
   audit.copied = CopyRates(symbol, timeframe, from_time, to_time, rates);
   audit.copy_error = GetLastError();
   if(audit.copied < 0 || audit.copy_error != 0 ||
      audit.copied != ArraySize(rates))
   {
      audit.copy_failed = true;
      return;
   }
   if(audit.copied == 0)
      return;
   audit.first_copied = (long)rates[0].time;
   audit.last_copied = (long)rates[audit.copied-1].time;
   for(int i = 0; i < audit.copied; ++i)
   {
      if(rates[i].tick_volume > 0)
         ++audit.tick_volume_positive;
      else
         ++audit.tick_volume_zero;
      if(rates[i].real_volume > 0)
         ++audit.real_volume_positive;
      else
         ++audit.real_volume_zero;
   }
}

void ResetTickAudit(TickAudit &audit)
{
   audit.total = 0;
   audit.first_time_msc = 0;
   audit.last_time_msc = 0;
   audit.bid_ask_valid = 0;
   audit.last_valid = 0;
   audit.volume_positive = 0;
   audit.volume_real_positive = 0;
   audit.flag_last = 0;
   audit.flag_volume = 0;
   audit.flag_bid = 0;
   audit.flag_ask = 0;
   audit.up_count = 0;
   audit.down_count = 0;
   audit.unchanged_count = 0;
   audit.copy_failures = 0;
   audit.last_copy_error = 0;
   audit.zero_copy_chunks = 0;
   audit.m5_boundary_resets = 0;
   audit.directional_bars = 0;
}

void AuditTicks(const string symbol,
                const datetime from_time,
                const datetime to_time,
                TickAudit &audit)
{
   ResetTickAudit(audit);
   ulong from_msc = (ulong)from_time * 1000;
   ulong final_msc = (ulong)to_time * 1000 + 999;
   const ulong day_msc = 86400000;
   bool have_previous_mid = false;
   double previous_mid = 0.0;
   long active_m5_open_msc = -1;
   long bar_up_count = 0;
   long bar_down_count = 0;
   while(from_msc <= final_msc)
   {
      ulong chunk_end = MathMin(from_msc + day_msc - 1, final_msc);
      MqlTick ticks[];
      ResetLastError();
      int copied = CopyTicksRange(symbol, ticks, COPY_TICKS_ALL, from_msc, chunk_end);
      int copy_error = GetLastError();
      audit.last_copy_error = copy_error;
      if(copied < 0 || copy_error != 0 || copied != ArraySize(ticks))
      {
         ++audit.copy_failures;
         copied = 0;
      }
      else if(copied == 0)
         ++audit.zero_copy_chunks;
      if(copied > 0)
      {
         for(int i = 0; i < copied; ++i)
         {
            MqlTick tick = ticks[i];
            if(audit.total == 0)
               audit.first_time_msc = tick.time_msc;
            audit.last_time_msc = tick.time_msc;
            ++audit.total;
            bool bid_ask_valid = MathIsValidNumber(tick.bid) && tick.bid > 0.0 &&
                                 MathIsValidNumber(tick.ask) && tick.ask > 0.0;
            if(bid_ask_valid)
            {
               ++audit.bid_ask_valid;
               double mid = (tick.bid + tick.ask) * 0.5;
               long m5_open_msc = (tick.time_msc / 300000) * 300000;
               if(active_m5_open_msc != m5_open_msc)
               {
                  if(active_m5_open_msc >= 0)
                  {
                     if(bar_up_count + bar_down_count > 0)
                        ++audit.directional_bars;
                     ++audit.m5_boundary_resets;
                  }
                  active_m5_open_msc = m5_open_msc;
                  have_previous_mid = false;
                  bar_up_count = 0;
                  bar_down_count = 0;
               }
               if(have_previous_mid)
               {
                  if(mid > previous_mid)
                  {
                     ++audit.up_count;
                     ++bar_up_count;
                  }
                  else if(mid < previous_mid)
                  {
                     ++audit.down_count;
                     ++bar_down_count;
                  }
                  else
                     ++audit.unchanged_count;
               }
               previous_mid = mid;
               have_previous_mid = true;
            }
            if(MathIsValidNumber(tick.last) && tick.last > 0.0)
               ++audit.last_valid;
            if(tick.volume > 0)
               ++audit.volume_positive;
            if(MathIsValidNumber(tick.volume_real) && tick.volume_real > 0.0)
               ++audit.volume_real_positive;
            if((tick.flags & TICK_FLAG_LAST) != 0)
               ++audit.flag_last;
            if((tick.flags & TICK_FLAG_VOLUME) != 0)
               ++audit.flag_volume;
            if((tick.flags & TICK_FLAG_BID) != 0)
               ++audit.flag_bid;
            if((tick.flags & TICK_FLAG_ASK) != 0)
               ++audit.flag_ask;
         }
      }
      if(chunk_end == final_msc)
         break;
      from_msc = chunk_end + 1;
   }
   if(active_m5_open_msc >= 0 && bar_up_count + bar_down_count > 0)
      ++audit.directional_bars;
}

void ResetCapabilityAudit(CapabilityAudit &audit)
{
   audit.d1_pair_copy_ok = false;
   audit.d1_pair_copy_error = 0;
   audit.previous_d1_open = 0;
   audit.current_d1_open = 0;
   audit.previous_d1_record_id = "";
   audit.current_d1_record_id = "";
   audit.profile_tick_copy_ok = false;
   audit.profile_count_consistent = false;
   audit.profile_complete = false;
   audit.profile_expected_count = 0;
   audit.profile_returned_count = 0;
   audit.profile_array_size = 0;
   audit.profile_copy_error = 0;
   audit.profile_rate_snapshot_error = 0;
   audit.profile_reason = "COMPLETION_EVIDENCE_MISSING";
   audit.profile_interval_receipt = "{}";
   audit.profile_bid_ask_valid = 0;
   audit.m5_window_copy_ok = false;
   audit.m5_window_copy_error = 0;
   audit.m5_sequence_ok = false;
   audit.m5_positive_tick_volume_all = false;
   audit.candidate_m5_open = 0;
   audit.quote_copy_failures = 0;
   audit.quote_data_present_intervals = 0;
   audit.quote_count_consistent_intervals = 0;
   audit.quote_complete_intervals = 0;
   audit.quote_interval_receipts = "[]";
   audit.count_basis = OFP_CopyCountBasisName(OFP_COUNT_BASIS_UNQUALIFIED);
   audit.completeness_qualified = false;
   audit.quote_zero_denominator_bars = 0;
   audit.candidate_up_count = 0;
   audit.candidate_down_count = 0;
   audit.candidate_unchanged_count = 0;
}

bool RateSnapshotEqual(const MqlRates &left,
                       const MqlRates &right)
{
   return left.time == right.time &&
          left.open == right.open &&
          left.high == right.high &&
          left.low == right.low &&
          left.close == right.close &&
          left.tick_volume == right.tick_volume &&
          left.spread == right.spread &&
          left.real_volume == right.real_volume;
}

bool SeriesSynchronized(const string symbol,
                        const ENUM_TIMEFRAMES timeframe)
{
   long synchronized = 0;
   return SeriesInfoInteger(symbol, timeframe, SERIES_SYNCHRONIZED, synchronized) &&
          synchronized != 0;
}

void CollectExactTickEvidence(const string symbol,
                              const ENUM_TIMEFRAMES timeframe,
                              const datetime interval_start,
                              const datetime interval_end,
                              const long expected_native_count,
                              OFPCopyEvidence &evidence,
                              ulong &bid_ask_valid,
                              long &up_count,
                              long &down_count,
                              long &unchanged_count)
{
   OFP_ResetCopyEvidence(evidence);
   evidence.count_basis = OFP_COUNT_BASIS_UNQUALIFIED;
   evidence.expected_native_count = expected_native_count;
   evidence.requested_start_msc = (long)interval_start * 1000;
   evidence.requested_end_msc = (long)interval_end * 1000;
   evidence.boundary_matches = interval_start > 0 && interval_end > interval_start;
   evidence.synchronized_before = SeriesSynchronized(symbol, timeframe);
   string source_before = AccountInfoString(ACCOUNT_SERVER);
   string symbol_path_before = SymbolInfoString(symbol, SYMBOL_PATH);
   bid_ask_valid = 0;
   up_count = 0;
   down_count = 0;
   unchanged_count = 0;
   MqlTick ticks[];
   ulong from_msc = (ulong)interval_start * 1000;
   ulong to_msc = (ulong)interval_end * 1000 - 1;
   ResetLastError();
   int copied = CopyTicksRange(symbol, ticks, COPY_TICKS_ALL, from_msc, to_msc);
   evidence.copy_error = GetLastError();
   evidence.returned_count = copied;
   evidence.array_size = ArraySize(ticks);
   evidence.synchronized_after = SeriesSynchronized(symbol, timeframe);
   evidence.source_matches = source_before == AccountInfoString(ACCOUNT_SERVER);
   evidence.symbol_matches = symbol_path_before == SymbolInfoString(symbol, SYMBOL_PATH);
   bool have_previous_mid = false;
   double previous_mid = 0.0;
   long previous_time_msc = -1;
   int inspect_count = copied;
   if(inspect_count < 0)
      inspect_count = 0;
   if(inspect_count > ArraySize(ticks))
      inspect_count = ArraySize(ticks);
   for(int i = 0; i < inspect_count; ++i)
   {
      if(i == 0)
         evidence.first_time_msc = ticks[i].time_msc;
      evidence.last_time_msc = ticks[i].time_msc;
      if(previous_time_msc > ticks[i].time_msc)
         evidence.timestamps_monotonic = false;
      if(ticks[i].time_msc < evidence.requested_start_msc ||
         ticks[i].time_msc >= evidence.requested_end_msc)
         evidence.timestamps_in_range = false;
      previous_time_msc = ticks[i].time_msc;
      if(!MathIsValidNumber(ticks[i].bid) || ticks[i].bid <= 0.0 ||
         !MathIsValidNumber(ticks[i].ask) || ticks[i].ask <= 0.0)
      {
         evidence.prices_valid = false;
         continue;
      }
      ++bid_ask_valid;
      double mid = (ticks[i].bid + ticks[i].ask) * 0.5;
      if(have_previous_mid)
      {
         if(mid > previous_mid)
            ++up_count;
         else if(mid < previous_mid)
            ++down_count;
         else
            ++unchanged_count;
      }
      previous_mid = mid;
      have_previous_mid = true;
   }
}

string CopyReceiptJson(const string interval_id,
                       const bool candidate,
                       const OFPCopyEvidence &evidence,
                       const OFPCopyValidation &validation,
                       const ulong bid_ask_valid,
                       const long up_count,
                       const long down_count,
                       const long unchanged_count)
{
   return "{\"interval_id\":" + JsonString(interval_id) +
          ",\"candidate\":" + JsonBool(candidate) +
          ",\"count_basis\":" + JsonString(OFP_CopyCountBasisName(evidence.count_basis)) +
          ",\"expected_native_count\":" + LongToString(evidence.expected_native_count) +
          ",\"returned_count\":" + LongToString(evidence.returned_count) +
          ",\"array_size\":" + IntegerToString(evidence.array_size) +
          ",\"copy_error\":" + IntegerToString(evidence.copy_error) +
          ",\"rate_snapshot_error\":" + IntegerToString(evidence.rate_snapshot_error) +
          ",\"requested_start_msc\":" + LongToString(evidence.requested_start_msc) +
          ",\"requested_end_msc\":" + LongToString(evidence.requested_end_msc) +
          ",\"first_time_msc\":" + LongToString(evidence.first_time_msc) +
          ",\"last_time_msc\":" + LongToString(evidence.last_time_msc) +
          ",\"timestamps_monotonic\":" + JsonBool(evidence.timestamps_monotonic) +
          ",\"timestamps_in_range\":" + JsonBool(evidence.timestamps_in_range) +
          ",\"prices_valid\":" + JsonBool(evidence.prices_valid) +
          ",\"source_matches\":" + JsonBool(evidence.source_matches) +
          ",\"symbol_matches\":" + JsonBool(evidence.symbol_matches) +
          ",\"boundary_matches\":" + JsonBool(evidence.boundary_matches) +
          ",\"rate_snapshot_stable\":" + JsonBool(evidence.rate_snapshot_stable) +
          ",\"synchronized_before\":" + JsonBool(evidence.synchronized_before) +
          ",\"synchronized_after\":" + JsonBool(evidence.synchronized_after) +
          ",\"bid_ask_valid\":" + LongToString((long)bid_ask_valid) +
          ",\"up_count\":" + LongToString(up_count) +
          ",\"down_count\":" + LongToString(down_count) +
          ",\"unchanged_count\":" + LongToString(unchanged_count) +
          ",\"data_present\":" + JsonBool(validation.data_present) +
          ",\"count_consistent\":" + JsonBool(validation.count_consistent) +
          ",\"complete\":" + JsonBool(validation.complete) +
          ",\"reason\":" + JsonString(validation.reason) + "}";
}

void AuditExactCapability(const string symbol,
                          const datetime as_of,
                          CapabilityAudit &audit)
{
   ResetCapabilityAudit(audit);
   int d1_shift = iBarShift(symbol, PERIOD_D1, as_of, false);
   if(d1_shift < 0)
      return;
   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   ResetLastError();
   int d1_copied = CopyRates(symbol, PERIOD_D1, d1_shift, 2, d1_rates);
   audit.d1_pair_copy_error = GetLastError();
   if(d1_copied != 2 || d1_copied != ArraySize(d1_rates) ||
      audit.d1_pair_copy_error != 0 || d1_rates[1].time <= 0 ||
      d1_rates[0].time <= d1_rates[1].time)
      return;
   audit.d1_pair_copy_ok = true;
   audit.previous_d1_open = (long)d1_rates[1].time;
   audit.current_d1_open = (long)d1_rates[0].time;
   audit.previous_d1_record_id = symbol + "|D1|" + LongToString(audit.previous_d1_open);
   audit.current_d1_record_id = symbol + "|D1|" + LongToString(audit.current_d1_open);
   long profile_up = 0;
   long profile_down = 0;
   long profile_unchanged = 0;
   OFPCopyEvidence profile_evidence;
   CollectExactTickEvidence(symbol, PERIOD_D1,
                            d1_rates[1].time, d1_rates[0].time,
                            d1_rates[1].tick_volume,
                            profile_evidence, audit.profile_bid_ask_valid,
                            profile_up, profile_down, profile_unchanged);
   MqlRates d1_after[];
   ArraySetAsSeries(d1_after, true);
   ResetLastError();
   int d1_after_copied = CopyRates(symbol, PERIOD_D1, d1_shift, 2, d1_after);
   profile_evidence.rate_snapshot_error = GetLastError();
   profile_evidence.rate_snapshot_stable =
      d1_after_copied == 2 && d1_after_copied == ArraySize(d1_after) &&
      RateSnapshotEqual(d1_rates[0], d1_after[0]) &&
      RateSnapshotEqual(d1_rates[1], d1_after[1]);
   OFPCopyValidation profile_validation;
   OFP_ValidateCopyEvidence(profile_evidence, profile_validation);
   audit.profile_tick_copy_ok = profile_validation.data_present;
   audit.profile_count_consistent = profile_validation.count_consistent;
   audit.profile_complete = profile_validation.complete;
   audit.profile_expected_count = profile_evidence.expected_native_count;
   audit.profile_returned_count = profile_evidence.returned_count;
   audit.profile_array_size = profile_evidence.array_size;
   audit.profile_copy_error = profile_evidence.copy_error;
   audit.profile_rate_snapshot_error = profile_evidence.rate_snapshot_error;
   audit.profile_reason = profile_validation.reason;
   audit.profile_interval_receipt =
      CopyReceiptJson(audit.previous_d1_record_id, false,
                      profile_evidence, profile_validation,
                      audit.profile_bid_ask_valid,
                      profile_up, profile_down, profile_unchanged);

   int containing_m5_shift = iBarShift(symbol, PERIOD_M5, as_of, false);
   if(containing_m5_shift < 0)
      return;
   datetime containing_open = iTime(symbol, PERIOD_M5, containing_m5_shift);
   int candidate_shift = containing_m5_shift;
   if(as_of < containing_open + PeriodSeconds(PERIOD_M5))
      ++candidate_shift;
   MqlRates m5_rates[];
   ArraySetAsSeries(m5_rates, true);
   ResetLastError();
   int m5_copied = CopyRates(symbol, PERIOD_M5, candidate_shift, 21, m5_rates);
   audit.m5_window_copy_error = GetLastError();
   if(m5_copied != 21 || m5_copied != ArraySize(m5_rates) ||
      audit.m5_window_copy_error != 0)
      return;
   audit.m5_window_copy_ok = true;
   audit.m5_sequence_ok = true;
   audit.m5_positive_tick_volume_all = true;
   audit.candidate_m5_open = (long)m5_rates[0].time;
   string receipts = "[";
   for(int i = 0; i < 21; ++i)
   {
      int exact_shift = iBarShift(symbol, PERIOD_M5, m5_rates[i].time, true);
      if(exact_shift != candidate_shift + i)
         audit.m5_sequence_ok = false;
      if(m5_rates[i].tick_volume <= 0)
         audit.m5_positive_tick_volume_all = false;
      ulong valid = 0;
      long up = 0;
      long down = 0;
      long unchanged = 0;
      OFPCopyEvidence interval_evidence;
      CollectExactTickEvidence(symbol, PERIOD_M5,
                               m5_rates[i].time,
                               m5_rates[i].time + PeriodSeconds(PERIOD_M5),
                               m5_rates[i].tick_volume,
                               interval_evidence, valid, up, down, unchanged);
      MqlRates m5_after[];
      ArraySetAsSeries(m5_after, true);
      ResetLastError();
      int m5_after_copied = CopyRates(symbol, PERIOD_M5,
                                      candidate_shift + i, 1, m5_after);
      interval_evidence.rate_snapshot_error = GetLastError();
      interval_evidence.rate_snapshot_stable =
         m5_after_copied == 1 && m5_after_copied == ArraySize(m5_after) &&
         RateSnapshotEqual(m5_rates[i], m5_after[0]);
      interval_evidence.boundary_matches = interval_evidence.boundary_matches &&
         m5_rates[i].time + PeriodSeconds(PERIOD_M5) <= as_of;
      OFPCopyValidation interval_validation;
      OFP_ValidateCopyEvidence(interval_evidence, interval_validation);
      if(!interval_validation.complete)
         ++audit.quote_copy_failures;
      if(interval_validation.data_present)
         ++audit.quote_data_present_intervals;
      if(interval_validation.count_consistent)
         ++audit.quote_count_consistent_intervals;
      if(interval_validation.complete)
         ++audit.quote_complete_intervals;
      if(up + down <= 0)
         ++audit.quote_zero_denominator_bars;
      if(i > 0)
         receipts += ",";
      string interval_id = symbol + "|M5|" + LongToString((long)m5_rates[i].time);
      receipts += CopyReceiptJson(interval_id, i == 0,
                                  interval_evidence, interval_validation,
                                  valid, up, down, unchanged);
      if(i == 0)
      {
         audit.candidate_up_count = up;
         audit.candidate_down_count = down;
         audit.candidate_unchanged_count = unchanged;
      }
   }
   receipts += "]";
   audit.quote_interval_receipts = receipts;
   audit.completeness_qualified = audit.profile_complete &&
                                  audit.quote_complete_intervals == 21;
}

string RateJson(const RateAudit &audit)
{
   double tick_zero_rate = audit.copied > 0
                           ? (double)audit.tick_volume_zero / audit.copied : 1.0;
   double real_zero_rate = audit.copied > 0
                           ? (double)audit.real_volume_zero / audit.copied : 1.0;
   return "{\"server_first_date\":" + LongToString(audit.server_first_date) +
          ",\"last_bar_date\":" + LongToString(audit.last_bar_date) +
          ",\"copied\":" + IntegerToString(audit.copied) +
          ",\"first_copied\":" + LongToString(audit.first_copied) +
          ",\"last_copied\":" + LongToString(audit.last_copied) +
          ",\"tick_volume_positive\":" + LongToString(audit.tick_volume_positive) +
          ",\"tick_volume_zero\":" + LongToString(audit.tick_volume_zero) +
          ",\"tick_volume_zero_rate\":" + DoubleToString(tick_zero_rate, 8) +
           ",\"real_volume_positive\":" + LongToString(audit.real_volume_positive) +
           ",\"real_volume_zero\":" + LongToString(audit.real_volume_zero) +
           ",\"real_volume_zero_rate\":" + DoubleToString(real_zero_rate, 8) +
           ",\"copy_failed\":" + JsonBool(audit.copy_failed) +
           ",\"copy_error\":" + IntegerToString(audit.copy_error) + "}";
}

string Capability(const CapabilityAudit &exact,
                  const double point,
                  const double trade_tick_size)
{
   bool bin_ready = trade_tick_size > 0.0 || point > 0.0;
   bool p0 = exact.d1_pair_copy_ok && exact.profile_complete &&
             exact.profile_bid_ask_valid > 0 && bin_ready &&
             exact.completeness_qualified;
   if(!p0)
      return "BLOCKED_DATA";
   bool p1 = exact.m5_window_copy_ok && exact.m5_sequence_ok &&
             exact.m5_positive_tick_volume_all &&
             exact.quote_complete_intervals == 21 &&
             exact.quote_copy_failures == 0;
   if(!p1)
      return "BLOCKED_DATA";
   return exact.candidate_up_count + exact.candidate_down_count > 0
          ? "P2_READY" : "P1_READY";
}

string RawObservedCapability(const CapabilityAudit &exact,
                             const double point,
                             const double trade_tick_size)
{
   bool bin_ready = trade_tick_size > 0.0 || point > 0.0;
   if(!exact.d1_pair_copy_ok || !exact.profile_tick_copy_ok ||
      exact.profile_bid_ask_valid <= 0 || !bin_ready)
      return "NO_PROFILE_DATA";
   if(!exact.profile_count_consistent)
      return "PROFILE_DATA_PRESENT_NOT_COUNT_CONSISTENT";
   if(!exact.m5_window_copy_ok || !exact.m5_sequence_ok ||
      !exact.m5_positive_tick_volume_all || exact.quote_data_present_intervals != 21)
      return "P0_PREREQUISITES_OBSERVED_UNQUALIFIED";
   if(exact.quote_count_consistent_intervals != 21)
      return "M5_DATA_PRESENT_NOT_COUNT_CONSISTENT";
   if(exact.candidate_up_count + exact.candidate_down_count > 0)
      return "P2_PREREQUISITES_OBSERVED_UNQUALIFIED";
   return "P1_PREREQUISITES_OBSERVED_UNQUALIFIED";
}

string CompletenessBlockersJson(const CapabilityAudit &exact)
{
   string blockers = "[\"COMPLETENESS_UNQUALIFIED\",\"" +
                     JsonEscape(exact.profile_reason) + "\"";
   if(exact.quote_complete_intervals != 21)
      blockers += ",\"M5_INTERVAL_COMPLETENESS_REFUSED\"";
   if(exact.d1_pair_copy_error != 0)
      blockers += ",\"D1_COPY_ERROR_" + IntegerToString(exact.d1_pair_copy_error) + "\"";
   if(exact.m5_window_copy_error != 0)
      blockers += ",\"M5_COPY_ERROR_" + IntegerToString(exact.m5_window_copy_error) + "\"";
   return blockers + "]";
}

string BuildJson(const string logical,
                 const string exact_symbol,
                 const string suffix,
                 const string candidates,
                 const int match_count,
                 const datetime from_time,
                 const datetime to_time,
                 const RateAudit &d1,
                  const RateAudit &m15,
                  const RateAudit &m5,
                  const TickAudit &ticks,
                  const CapabilityAudit &exact,
                  const double point,
                 const double trade_tick_size)
{
   string capability = match_count == 1
                        ? Capability(exact, point, trade_tick_size)
                       : "BLOCKED_DATA";
   string raw_observed = match_count == 1
                         ? RawObservedCapability(exact, point, trade_tick_size)
                         : "MAPPING_UNRESOLVED";
   double bid_ask_valid_rate = ticks.total > 0
                               ? (double)ticks.bid_ask_valid / (double)ticks.total : 0.0;
   return "{\"schema\":\"orderflow_proxy_mt5_audit/v1\"" +
          ",\"authority\":\"CAPABILITY_ONLY_NO_STRATEGY_QUALITY\"" +
          ",\"logical_symbol\":" + JsonString(logical) +
          ",\"broker_symbol\":" + JsonString(exact_symbol) +
          ",\"suffix\":" + JsonString(suffix) +
          ",\"mapping_candidates\":" + JsonString(candidates) +
          ",\"mapping_match_count\":" + IntegerToString(match_count) +
          ",\"terminal_name\":" + JsonString(TerminalInfoString(TERMINAL_NAME)) +
          ",\"terminal_path\":" + JsonString(TerminalInfoString(TERMINAL_PATH)) +
          ",\"terminal_data_path\":" + JsonString(TerminalInfoString(TERMINAL_DATA_PATH)) +
          ",\"terminal_build\":" + IntegerToString((int)TerminalInfoInteger(TERMINAL_BUILD)) +
          ",\"server\":" + JsonString(AccountInfoString(ACCOUNT_SERVER)) +
          ",\"coverage_from\":" + LongToString((long)from_time) +
          ",\"coverage_to\":" + LongToString((long)to_time) +
          ",\"symbol_point\":" + DoubleToString(point, 12) +
          ",\"symbol_trade_tick_size\":" + DoubleToString(trade_tick_size, 12) +
          ",\"rates_d1\":" + RateJson(d1) +
          ",\"rates_m15\":" + RateJson(m15) +
          ",\"rates_m5\":" + RateJson(m5) +
          ",\"copyticks\":{\"count\":" + LongToString((long)ticks.total) +
          ",\"first_time_msc\":" + LongToString(ticks.first_time_msc) +
          ",\"last_time_msc\":" + LongToString(ticks.last_time_msc) +
          ",\"bid_ask_valid\":" + LongToString((long)ticks.bid_ask_valid) +
          ",\"bid_ask_valid_rate\":" + DoubleToString(bid_ask_valid_rate, 8) +
          ",\"last_valid\":" + LongToString((long)ticks.last_valid) +
          ",\"volume_positive\":" + LongToString((long)ticks.volume_positive) +
          ",\"volume_real_positive\":" + LongToString((long)ticks.volume_real_positive) +
          ",\"flag_last\":" + LongToString((long)ticks.flag_last) +
          ",\"flag_volume\":" + LongToString((long)ticks.flag_volume) +
          ",\"flag_bid\":" + LongToString((long)ticks.flag_bid) +
          ",\"flag_ask\":" + LongToString((long)ticks.flag_ask) +
          ",\"quote_up_count\":" + LongToString((long)ticks.up_count) +
          ",\"quote_down_count\":" + LongToString((long)ticks.down_count) +
           ",\"quote_unchanged_count\":" + LongToString((long)ticks.unchanged_count) +
           ",\"m5_boundary_resets\":" + LongToString(ticks.m5_boundary_resets) +
           ",\"directional_bars\":" + LongToString(ticks.directional_bars) +
           ",\"copy_failures\":" + LongToString(ticks.copy_failures) +
           ",\"last_copy_error\":" + IntegerToString(ticks.last_copy_error) +
           ",\"zero_copy_chunks\":" + LongToString(ticks.zero_copy_chunks) +
           ",\"quote_proxy_formable\":" + JsonBool(ticks.directional_bars > 0) + "}" +
           ",\"exact_capability_intervals\":{" +
           "\"d1_pair_copy_ok\":" + JsonBool(exact.d1_pair_copy_ok) +
           ",\"d1_pair_copy_error\":" + IntegerToString(exact.d1_pair_copy_error) +
           ",\"previous_d1_open\":" + LongToString(exact.previous_d1_open) +
           ",\"current_d1_open\":" + LongToString(exact.current_d1_open) +
           ",\"previous_d1_record_id\":" + JsonString(exact.previous_d1_record_id) +
           ",\"current_d1_record_id\":" + JsonString(exact.current_d1_record_id) +
           ",\"profile_tick_copy_ok\":" + JsonBool(exact.profile_tick_copy_ok) +
           ",\"profile_count_consistent\":" + JsonBool(exact.profile_count_consistent) +
           ",\"profile_complete\":" + JsonBool(exact.profile_complete) +
           ",\"profile_expected_count\":" + LongToString(exact.profile_expected_count) +
           ",\"profile_returned_count\":" + LongToString(exact.profile_returned_count) +
           ",\"profile_array_size\":" + IntegerToString(exact.profile_array_size) +
           ",\"profile_copy_error\":" + IntegerToString(exact.profile_copy_error) +
           ",\"profile_rate_snapshot_error\":" + IntegerToString(exact.profile_rate_snapshot_error) +
           ",\"profile_reason\":" + JsonString(exact.profile_reason) +
           ",\"profile_interval_receipt\":" + exact.profile_interval_receipt +
           ",\"profile_bid_ask_valid\":" + LongToString((long)exact.profile_bid_ask_valid) +
           ",\"m5_window_copy_ok\":" + JsonBool(exact.m5_window_copy_ok) +
           ",\"m5_window_copy_error\":" + IntegerToString(exact.m5_window_copy_error) +
           ",\"m5_sequence_ok\":" + JsonBool(exact.m5_sequence_ok) +
           ",\"m5_positive_tick_volume_all\":" + JsonBool(exact.m5_positive_tick_volume_all) +
           ",\"candidate_m5_open\":" + LongToString(exact.candidate_m5_open) +
           ",\"quote_copy_failures\":" + LongToString(exact.quote_copy_failures) +
           ",\"quote_data_present_intervals\":" + LongToString(exact.quote_data_present_intervals) +
           ",\"quote_count_consistent_intervals\":" + LongToString(exact.quote_count_consistent_intervals) +
           ",\"quote_complete_intervals\":" + LongToString(exact.quote_complete_intervals) +
           ",\"quote_zero_denominator_bars\":" + LongToString(exact.quote_zero_denominator_bars) +
           ",\"candidate_quote_up_count\":" + LongToString(exact.candidate_up_count) +
           ",\"candidate_quote_down_count\":" + LongToString(exact.candidate_down_count) +
           ",\"candidate_quote_unchanged_count\":" + LongToString(exact.candidate_unchanged_count) +
           ",\"count_basis\":" + JsonString(exact.count_basis) +
           ",\"completeness_qualified\":" + JsonBool(exact.completeness_qualified) +
           ",\"m5_interval_receipts\":" + exact.quote_interval_receipts + "}" +
           ",\"raw_observed_capability\":" + JsonString(raw_observed) +
           ",\"completeness_blockers\":" + CompletenessBlockersJson(exact) +
           ",\"capability\":" + JsonString(capability) +
          ",\"orders_sent\":0,\"positions_modified\":0" +
          ",\"symbol_selection_mutated\":false,\"chart_attachment_required\":false}";
}

void OnStart()
{
   const string logical_symbols[] = {
      "XAUUSD", "EURUSD", "GBPUSD", "EURGBP",
      "USDJPY", "EURJPY", "BTCUSD", "ETHUSD"
   };
   datetime to_time = InpCoverageTo > 0 ? InpCoverageTo : TimeCurrent();
   int handle = FileOpen(InpOutputJsonl,
                         FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("ORDERFLOW_PROXY_AUDIT_REFUSED file_error=%d", GetLastError());
      return;
   }

   for(int i = 0; i < ArraySize(logical_symbols); ++i)
   {
      string exact_symbol = "";
      string suffix = "";
      string candidates = "";
      int matches = DiscoverExactBrokerSymbol(logical_symbols[i], exact_symbol,
                                               suffix, candidates);
      RateAudit d1;
      RateAudit m15;
      RateAudit m5;
      TickAudit ticks;
      CapabilityAudit exact;
      ResetRateAudit(d1);
      ResetRateAudit(m15);
      ResetRateAudit(m5);
      ResetTickAudit(ticks);
      ResetCapabilityAudit(exact);
      double point = 0.0;
      double trade_tick_size = 0.0;
      if(matches == 1)
      {
         point = SymbolInfoDouble(exact_symbol, SYMBOL_POINT);
         trade_tick_size = SymbolInfoDouble(exact_symbol, SYMBOL_TRADE_TICK_SIZE);
         AuditRates(exact_symbol, PERIOD_D1, InpCoverageFrom, to_time, d1);
         AuditRates(exact_symbol, PERIOD_M15, InpCoverageFrom, to_time, m15);
         AuditRates(exact_symbol, PERIOD_M5, InpCoverageFrom, to_time, m5);
         AuditTicks(exact_symbol, InpCoverageFrom, to_time, ticks);
         AuditExactCapability(exact_symbol, to_time, exact);
      }
      FileWriteString(handle,
                      BuildJson(logical_symbols[i], exact_symbol, suffix,
                                 candidates, matches, InpCoverageFrom, to_time,
                                 d1, m15, m5, ticks, exact,
                                 point, trade_tick_size) + "\r\n");
   }
   FileClose(handle);
   PrintFormat("ORDERFLOW_PROXY_AUDIT_COMPLETE output=Common\\Files\\%s symbols=%d",
               InpOutputJsonl, ArraySize(logical_symbols));
}
