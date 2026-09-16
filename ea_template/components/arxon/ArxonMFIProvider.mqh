//+------------------------------------------------------------------+
//| ArxonMFIProvider.mqh                                             |
//| Order-free Arxon MFI+ B1 component provider.                     |
//+------------------------------------------------------------------+
#ifndef ARXON_MFI_PROVIDER_MQH
#define ARXON_MFI_PROVIDER_MQH

#define ARXON_MFI_REFERENCE_LENGTH 7
#define ARXON_MFI_WARMUP_BARS     (ARXON_MFI_REFERENCE_LENGTH + 1)

enum ArxonMFIVolumeBasis
{
   ARXON_MFI_VOLUME_UNKNOWN = 0,
   ARXON_MFI_VOLUME_REAL    = 1,
   ARXON_MFI_VOLUME_TICK    = 2
};

enum ArxonMFIState
{
   ARXON_MFI_STATE_INVALID = 0,
   ARXON_MFI_STATE_BULL    = 1,
   ARXON_MFI_STATE_NEUTRAL = 2,
   ARXON_MFI_STATE_BEAR    = 3
};

enum ArxonMFIExtreme
{
   ARXON_MFI_EXTREME_INVALID    = 0,
   ARXON_MFI_EXTREME_NONE       = 1,
   ARXON_MFI_EXTREME_OVERBOUGHT = 2,
   ARXON_MFI_EXTREME_OVERSOLD   = 3
};

enum ArxonMFIReason
{
   ARXON_MFI_REASON_NONE                 = 0,
   ARXON_MFI_REASON_UNKNOWN_VOLUME_BASIS = 1,
   ARXON_MFI_REASON_ARRAY_TOO_SHORT      = 2,
   ARXON_MFI_REASON_INVALID_INDEX        = 3,
   ARXON_MFI_REASON_INSUFFICIENT_BARS    = 4,
   ARXON_MFI_REASON_NONFINITE_INPUT      = 5,
   ARXON_MFI_REASON_NEGATIVE_VOLUME      = 6,
   ARXON_MFI_REASON_ZERO_FLOW_UNDEFINED  = 7,
   ARXON_MFI_REASON_MFI_OUT_OF_RANGE     = 8
};

struct ArxonMFIResult
{
   bool                 valid;
   double               mfi_value;
   ArxonMFIState        state;
   ArxonMFIExtreme      extreme;
   datetime             source_bar_time;
   datetime             confirmed_at;
   ArxonMFIReason       reason;
   ArxonMFIVolumeBasis  volume_basis;
   int                  source_index;
   int                  length;
};

bool ArxonMFI_VolumeBasisValid(const ArxonMFIVolumeBasis basis)
{
   return (basis == ARXON_MFI_VOLUME_REAL || basis == ARXON_MFI_VOLUME_TICK);
}

void ArxonMFI_ResetResult(ArxonMFIResult &out,
                          const ArxonMFIVolumeBasis basis,
                          const int source_index)
{
   out.valid           = false;
   out.mfi_value       = 0.0;
   out.state           = ARXON_MFI_STATE_INVALID;
   out.extreme         = ARXON_MFI_EXTREME_INVALID;
   out.source_bar_time = (datetime)0;
   out.confirmed_at    = (datetime)0;
   out.reason          = ARXON_MFI_REASON_NONE;
   out.volume_basis    = basis;
   out.source_index    = source_index;
   out.length          = ARXON_MFI_REFERENCE_LENGTH;
}

bool ArxonMFI_ClassifyValue(const double value,
                            ArxonMFIState &state,
                            ArxonMFIExtreme &extreme)
{
   if(!MathIsValidNumber(value) || value < 0.0 || value > 100.0)
   {
      state = ARXON_MFI_STATE_INVALID;
      extreme = ARXON_MFI_EXTREME_INVALID;
      return false;
   }

   if(value > 55.0)
      state = ARXON_MFI_STATE_BULL;
   else if(value < 45.0)
      state = ARXON_MFI_STATE_BEAR;
   else
      state = ARXON_MFI_STATE_NEUTRAL;

   if(value > 90.0)
      extreme = ARXON_MFI_EXTREME_OVERBOUGHT;
   else if(value < 10.0)
      extreme = ARXON_MFI_EXTREME_OVERSOLD;
   else
      extreme = ARXON_MFI_EXTREME_NONE;

   return true;
}

string ArxonMFI_ReasonName(const ArxonMFIReason reason)
{
   switch(reason)
   {
      case ARXON_MFI_REASON_NONE:                 return "NONE";
      case ARXON_MFI_REASON_UNKNOWN_VOLUME_BASIS: return "UNKNOWN_VOLUME_BASIS";
      case ARXON_MFI_REASON_ARRAY_TOO_SHORT:      return "ARRAY_TOO_SHORT";
      case ARXON_MFI_REASON_INVALID_INDEX:        return "INVALID_INDEX";
      case ARXON_MFI_REASON_INSUFFICIENT_BARS:    return "INSUFFICIENT_BARS";
      case ARXON_MFI_REASON_NONFINITE_INPUT:      return "NONFINITE_INPUT";
      case ARXON_MFI_REASON_NEGATIVE_VOLUME:      return "NEGATIVE_VOLUME";
      case ARXON_MFI_REASON_ZERO_FLOW_UNDEFINED:  return "ZERO_FLOW_UNDEFINED";
      case ARXON_MFI_REASON_MFI_OUT_OF_RANGE:     return "MFI_OUT_OF_RANGE";
   }
   return "UNRECOGNIZED_REASON";
}

bool ArxonMFI_EvaluateAt(const double &high[],
                         const double &low[],
                         const double &close[],
                         const double &volume[],
                         const datetime &source_bar_time[],
                         const datetime &confirmed_at[],
                         const int bar_count,
                         const int source_index,
                         const ArxonMFIVolumeBasis volume_basis,
                         ArxonMFIResult &out)
{
   ArxonMFI_ResetResult(out, volume_basis, source_index);

   if(bar_count <= 0 ||
      ArraySize(high) < bar_count ||
      ArraySize(low) < bar_count ||
      ArraySize(close) < bar_count ||
      ArraySize(volume) < bar_count ||
      ArraySize(source_bar_time) < bar_count ||
      ArraySize(confirmed_at) < bar_count)
   {
      out.reason = ARXON_MFI_REASON_ARRAY_TOO_SHORT;
      return false;
   }

   if(source_index < 0 || source_index >= bar_count)
   {
      out.reason = ARXON_MFI_REASON_INVALID_INDEX;
      return false;
   }

   out.source_bar_time = source_bar_time[source_index];
   out.confirmed_at = confirmed_at[source_index];

   if(!ArxonMFI_VolumeBasisValid(volume_basis))
   {
      out.reason = ARXON_MFI_REASON_UNKNOWN_VOLUME_BASIS;
      return false;
   }

   if(bar_count < ARXON_MFI_WARMUP_BARS || source_index < ARXON_MFI_REFERENCE_LENGTH)
   {
      out.reason = ARXON_MFI_REASON_INSUFFICIENT_BARS;
      return false;
   }

   double positive_sum = 0.0;
   double negative_sum = 0.0;
   const int first_flow_index = source_index - ARXON_MFI_REFERENCE_LENGTH + 1;

   for(int i = first_flow_index; i <= source_index; i++)
   {
      if(!MathIsValidNumber(high[i]) || !MathIsValidNumber(low[i]) ||
         !MathIsValidNumber(close[i]) || !MathIsValidNumber(high[i - 1]) ||
         !MathIsValidNumber(low[i - 1]) || !MathIsValidNumber(close[i - 1]) ||
         !MathIsValidNumber(volume[i]))
      {
         out.reason = ARXON_MFI_REASON_NONFINITE_INPUT;
         return false;
      }

      if(volume[i] < 0.0)
      {
         out.reason = ARXON_MFI_REASON_NEGATIVE_VOLUME;
         return false;
      }

      const double typical = (high[i] + low[i] + close[i]) / 3.0;
      const double previous_typical = (high[i - 1] + low[i - 1] + close[i - 1]) / 3.0;
      const double raw_flow = typical * volume[i];

      if(!MathIsValidNumber(typical) || !MathIsValidNumber(previous_typical) ||
         !MathIsValidNumber(raw_flow))
      {
         out.reason = ARXON_MFI_REASON_NONFINITE_INPUT;
         return false;
      }

      if(typical > previous_typical)
         positive_sum += raw_flow;
      else if(typical < previous_typical)
         negative_sum += raw_flow;
   }

   double mfi = 0.0;
   if(negative_sum > 0.0)
   {
      const double ratio = positive_sum / negative_sum;
      mfi = 100.0 - (100.0 / (1.0 + ratio));
   }
   else if(positive_sum > 0.0)
      mfi = 100.0;
   else
   {
      out.reason = ARXON_MFI_REASON_ZERO_FLOW_UNDEFINED;
      return false;
   }

   ArxonMFIState state = ARXON_MFI_STATE_INVALID;
   ArxonMFIExtreme extreme = ARXON_MFI_EXTREME_INVALID;
   if(!ArxonMFI_ClassifyValue(mfi, state, extreme))
   {
      out.reason = ARXON_MFI_REASON_MFI_OUT_OF_RANGE;
      return false;
   }

   out.valid = true;
   out.mfi_value = mfi;
   out.state = state;
   out.extreme = extreme;
   out.reason = ARXON_MFI_REASON_NONE;
   return true;
}

bool ArxonMFI_EvaluateLatest(const double &high[],
                             const double &low[],
                             const double &close[],
                             const double &volume[],
                             const datetime &source_bar_time[],
                             const datetime &confirmed_at[],
                             const int bar_count,
                             const ArxonMFIVolumeBasis volume_basis,
                             ArxonMFIResult &out)
{
   return ArxonMFI_EvaluateAt(high, low, close, volume, source_bar_time,
                              confirmed_at, bar_count, bar_count - 1,
                              volume_basis, out);
}

#endif
