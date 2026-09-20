//+------------------------------------------------------------------+
//| TickActivityProfile.mqh                                          |
//| MT5_TICK_ACTIVITY_PROFILE_V1. Never executed-volume profile.     |
//+------------------------------------------------------------------+
#ifndef EA_LAB_TICK_ACTIVITY_PROFILE_MQH
#define EA_LAB_TICK_ACTIVITY_PROFILE_MQH

#include "OrderFlowProxyValidation.mqh"

int OFP_FindBin(const long &indices[],
                const long index)
{
   for(int i = 0; i < ArraySize(indices); ++i)
   {
      if(indices[i] == index)
         return i;
   }
   return -1;
}

ulong OFP_BinCount(const long &indices[],
                   const ulong &counts[],
                   const long index)
{
   int position = OFP_FindBin(indices, index);
   return position >= 0 ? counts[position] : 0;
}

bool OFP_BuildTickActivityProfile(const OFPQuoteTick &ticks[],
                                  const OFPD1Record &previous_d1,
                                  const OFPD1Record &current_d1,
                                  const datetime available_at,
                                  const double trade_tick_size,
                                  const double point,
                                  const string record_id,
                                  OFPProfile &profile,
                                  string &reason)
{
   if(StringLen(previous_d1.record_id) == 0 ||
      StringLen(current_d1.record_id) == 0 ||
      previous_d1.record_id == current_d1.record_id ||
      StringLen(previous_d1.instrument_id) == 0 ||
      StringLen(previous_d1.source_id) == 0 ||
      previous_d1.instrument_id != current_d1.instrument_id ||
      previous_d1.source_id != current_d1.source_id ||
      previous_d1.sequence == 0 ||
      current_d1.sequence != previous_d1.sequence + 1)
   {
      reason = "NON_ADJACENT_D1_RECORDS";
      return false;
   }
   datetime session_start = previous_d1.open_time;
   datetime session_end = current_d1.open_time;
   if(!previous_d1.completed || current_d1.completed ||
      session_start <= 0 || session_end <= session_start ||
      previous_d1.available_at < session_end ||
      current_d1.available_at < session_end ||
      available_at < previous_d1.available_at ||
      available_at < current_d1.available_at || StringLen(record_id) == 0)
   {
      reason = "INVALID_D1_BOUNDARY";
      return false;
   }
   double bin_size = 0.0;
   string bin_source = "";
   if(OFP_IsFinitePositive(trade_tick_size))
   {
      bin_size = trade_tick_size;
      bin_source = "SYMBOL_TRADE_TICK_SIZE";
   }
   else if(OFP_IsFinitePositive(point))
   {
      bin_size = point;
      bin_source = "SYMBOL_POINT";
   }
   else
   {
      reason = "NO_POSITIVE_BIN_SIZE";
      return false;
   }

   long indices[];
   ulong counts[];
   ulong total = 0;
   long start_msc = (long)session_start * 1000;
   long end_msc = (long)session_end * 1000;
   for(int i = 0; i < ArraySize(ticks); ++i)
   {
      if(ticks[i].instrument_id != previous_d1.instrument_id ||
         ticks[i].source_id != previous_d1.source_id)
      {
         reason = "CROSS_INSTRUMENT_OR_SOURCE";
         return false;
      }
      if(ticks[i].time_msc < start_msc || ticks[i].time_msc >= end_msc)
         continue;
      if(!OFP_IsFinitePositive(ticks[i].bid) || !OFP_IsFinitePositive(ticks[i].ask))
         continue; // Last is deliberately never substituted.
      double mid = (ticks[i].bid + ticks[i].ask) * 0.5;
      long bin_index = (long)MathFloor(mid / bin_size + 1.0e-12);
      int position = OFP_FindBin(indices, bin_index);
      if(position < 0)
      {
         int size = ArraySize(indices);
         ArrayResize(indices, size + 1);
         ArrayResize(counts, size + 1);
         indices[size] = bin_index;
         counts[size] = 1;
      }
      else
         ++counts[position];
      ++total;
   }
   if(total == 0)
   {
      reason = "NO_QUALIFYING_QUOTE_TICKS";
      return false;
   }

   for(int i = 1; i < ArraySize(indices); ++i)
   {
      long key_index = indices[i];
      ulong key_count = counts[i];
      int j = i - 1;
      while(j >= 0 && indices[j] > key_index)
      {
         indices[j+1] = indices[j];
         counts[j+1] = counts[j];
         --j;
      }
      indices[j+1] = key_index;
      counts[j+1] = key_count;
   }

   int poc_position = 0;
   for(int i = 1; i < ArraySize(indices); ++i)
   {
      if(counts[i] > counts[poc_position])
         poc_position = i;
   }
   long poc_bin = indices[poc_position];
   long minimum_bin = indices[0];
   long maximum_bin = indices[ArraySize(indices)-1];
   long included_low = poc_bin;
   long included_high = poc_bin;
   long lower = poc_bin - 1;
   long upper = poc_bin + 1;
   ulong accumulated = counts[poc_position];
   double target = 0.70 * (double)total;
   while((double)accumulated < target)
   {
      if(lower < minimum_bin && upper > maximum_bin)
         break;
      long lower_count = lower >= minimum_bin ? (long)OFP_BinCount(indices, counts, lower) : -1;
      long upper_count = upper <= maximum_bin ? (long)OFP_BinCount(indices, counts, upper) : -1;
      if(lower_count > upper_count)
      {
         included_low = lower;
         accumulated += (ulong)lower_count;
         --lower;
      }
      else if(upper_count > lower_count)
      {
         included_high = upper;
         accumulated += (ulong)upper_count;
         ++upper;
      }
      else
      {
         if(lower_count >= 0)
         {
            included_low = lower;
            accumulated += (ulong)lower_count;
            --lower;
         }
         if(upper_count >= 0)
         {
            included_high = upper;
            accumulated += (ulong)upper_count;
            ++upper;
         }
      }
   }

   profile.record_id = record_id;
   profile.instrument_id = previous_d1.instrument_id;
   profile.source_id = previous_d1.source_id;
   profile.profile_identity = OFP_PROFILE_IDENTITY;
   profile.profile_recipe_id = OFP_PROFILE_RECIPE_ID;
   profile.session_id = OFP_SESSION_ID;
   profile.previous_d1_record_id = previous_d1.record_id;
   profile.previous_d1_sequence = previous_d1.sequence;
   profile.previous_d1_open_time = previous_d1.open_time;
   profile.current_d1_record_id = current_d1.record_id;
   profile.current_d1_sequence = current_d1.sequence;
   profile.current_d1_open_time = current_d1.open_time;
   profile.session_start = session_start;
   profile.session_end = session_end;
   profile.available_at = available_at;
   profile.completed = true;
   profile.bin_size = bin_size;
   profile.bin_size_source = bin_source;
   profile.poc_bin_index = poc_bin;
   profile.val_bin_index = included_low;
   profile.vah_outer_bin_index = included_high + 1;
   profile.val = (double)included_low * bin_size;
   profile.poc = ((double)poc_bin + 0.5) * bin_size;
   profile.vah = (double)(included_high + 1) * bin_size;
   profile.total_activity = total;
   profile.value_area_activity = accumulated;
   return true;
}

#endif // EA_LAB_TICK_ACTIVITY_PROFILE_MQH
