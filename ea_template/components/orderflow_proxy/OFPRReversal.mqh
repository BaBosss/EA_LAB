//+------------------------------------------------------------------+
//| OFPRReversal.mqh                                                 |
//| OFPR-00/01/02 order-free completed-M5 reversal mechanics.       |
//+------------------------------------------------------------------+
#ifndef EA_LAB_OFPR_REVERSAL_MQH
#define EA_LAB_OFPR_REVERSAL_MQH

#include "TickActivityProfile.mqh"

const double OFPR_ZONE_ATR_MULTIPLIER = 0.20;
const double OFPR_WICK_RATIO_MIN = 0.40;
const double OFPR_IMBALANCE_THRESHOLD = 0.20;
const double OFPR_MIN_NET_RR = 1.50;
const int OFPR_TRIGGER_BARS = 3;

bool OFPR_IsVariant(const ENUM_OFP_VARIANT variant)
{
   return variant == OFPR_00_PROFILE_PRICE_CONTROL ||
          variant == OFPR_01_TICK_ACTIVITY ||
          variant == OFPR_02_QUOTE_IMBALANCE;
}

bool OFPR_TestCandidate(const ENUM_OFP_VARIANT variant,
                        const OFPProfile &profile,
                        const OFPBar &bars[],
                        const int index,
                        int &direction,
                        double &atr,
                        double &buffer)
{
   if(!OFP_ATR14Preceding(bars, index, atr))
      return false;
   buffer = OFPR_ZONE_ATR_MULTIPLIER * atr;
   OFPBar bar = bars[index];
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return false;

   bool long_candidate =
      OFP_RangeOverlaps(bar.low, bar.high,
                        profile.val - buffer, profile.val + buffer) &&
      bar.close > profile.val && bar.close < profile.vah &&
      (MathMin(bar.open, bar.close) - bar.low) / range + OFP_EPSILON >=
         OFPR_WICK_RATIO_MIN;
   bool short_candidate =
      OFP_RangeOverlaps(bar.low, bar.high,
                        profile.vah - buffer, profile.vah + buffer) &&
      bar.close > profile.val && bar.close < profile.vah &&
      (bar.high - MathMax(bar.open, bar.close)) / range + OFP_EPSILON >=
         OFPR_WICK_RATIO_MIN;
   if(long_candidate == short_candidate)
      return false;
   direction = long_candidate ? OFP_DIRECTION_LONG : OFP_DIRECTION_SHORT;

   if(OFP_VariantNeedsActivity(variant) &&
      !OFP_RelativeActivityPasses(bars, index))
      return false;
   if(OFP_VariantNeedsImbalance(variant))
   {
      double ratio = 0.0;
      if(!OFP_QuoteImbalance(bar, ratio))
         return false;
      if(direction == OFP_DIRECTION_LONG &&
         ratio > -OFPR_IMBALANCE_THRESHOLD + OFP_EPSILON)
         return false;
      if(direction == OFP_DIRECTION_SHORT &&
         ratio < OFPR_IMBALANCE_THRESHOLD - OFP_EPSILON)
         return false;
   }
   return true;
}

bool OFPR_BuildGeometry(const ENUM_OFP_VARIANT variant,
                        const OFPDataContract &contract,
                        const OFPProfile &profile,
                        const OFPBar &bars[],
                        const int trigger_index,
                        const OFPProspectiveQuote &quote,
                        const OFPDecisionEnvelope &envelope,
                        OFPState &state,
                        OFPDecision &out)
{
   string reason = "";
   if(!OFP_ValidateQuote(quote, bars[trigger_index], profile, contract,
                         envelope, reason))
   {
      OFP_SetDecision(out, OFP_DECISION_INVALID, variant, reason,
                      "prospective quote is not causally bound to confirmation");
      return false;
   }
   double extreme_low = bars[state.setup_index].low;
   double extreme_high = bars[state.setup_index].high;
   for(int i = state.setup_index + 1; i <= trigger_index; ++i)
   {
      extreme_low = MathMin(extreme_low, bars[i].low);
      extreme_high = MathMax(extreme_high, bars[i].high);
   }
   double entry = state.direction == OFP_DIRECTION_LONG ? quote.ask : quote.bid;
   double stop = state.direction == OFP_DIRECTION_LONG
                 ? extreme_low - state.frozen_buffer
                 : extreme_high + state.frozen_buffer;
   double target = profile.poc;
   double gross_risk = state.direction == OFP_DIRECTION_LONG
                       ? entry - stop : stop - entry;
   double gross_reward = state.direction == OFP_DIRECTION_LONG
                         ? target - entry : entry - target;
   double net_risk = gross_risk + quote.all_in_cost_price;
   double net_reward = gross_reward - quote.all_in_cost_price;
   if(gross_risk <= 0.0 || gross_reward <= 0.0 ||
      net_risk <= 0.0 || net_reward <= 0.0)
   {
      OFP_SetDecision(out, OFP_DECISION_REJECTED, variant,
                      "OFPR_INVALID_GEOMETRY",
                      "proxy POC/stop/quote geometry is invalid after cost");
      return false;
   }
   double net_rr = net_reward / net_risk;
   if(net_rr + OFP_EPSILON < OFPR_MIN_NET_RR)
   {
      OFP_SetDecision(out, OFP_DECISION_REJECTED, variant,
                      "OFPR_NET_RR_BELOW_1_50",
                      "prospective geometry fails frozen net RR gate");
      return false;
   }

   OFP_SetDecision(out, OFP_DECISION_SIGNAL, variant,
                   "OFPR_PROXY_GEOMETRY_READY",
                   "MT5 proxy only; order-free; prospective quote is not a fill");
   out.geometry.direction = state.direction;
   out.geometry.prospective_entry = entry;
   out.geometry.stop_price = stop;
   out.geometry.target_price = target;
   out.geometry.gross_risk = gross_risk;
   out.geometry.net_risk = net_risk;
   out.geometry.net_reward = net_reward;
   out.geometry.net_rr = net_rr;
   out.geometry.setup_time = bars[state.setup_index].close_time;
   out.geometry.trigger_time = bars[trigger_index].close_time;
   out.geometry.confirmation_window_completed_m5_bars = OFPR_TRIGGER_BARS;
   return true;
}

bool OFPR_StartCandidate(const ENUM_OFP_VARIANT variant,
                         const OFPProfile &profile,
                         const OFPContextBar &context,
                         const OFPBar &bars[],
                         const int index,
                         OFPState &state)
{
   if(!(context.close > profile.val && context.close < profile.vah))
      return false;
   int direction = OFP_DIRECTION_NONE;
   double atr = 0.0;
   double buffer = 0.0;
   if(!OFPR_TestCandidate(variant, profile, bars, index,
                          direction, atr, buffer))
      return false;
   OFP_ResetState(state);
   state.phase = OFPR_PHASE_TRIGGER;
   state.direction = direction;
   state.setup_index = index;
   state.edge = direction == OFP_DIRECTION_LONG ? profile.val : profile.vah;
   state.frozen_atr14 = atr;
   state.frozen_buffer = buffer;
   state.test_low = bars[index].low;
   state.test_high = bars[index].high;
   return true;
}

bool OFPR_Replay(const ENUM_OFP_VARIANT variant,
                 const OFPDataContract &contract,
                 const OFPProfile &profile,
                 const OFPContextBar &contexts[],
                 const OFPBar &bars[],
                 const OFPProspectiveQuote &quote,
                 const OFPDecisionEnvelope &envelope,
                 OFPDecision &out)
{
   string reason = "";
   if(!OFPR_IsVariant(variant) ||
      !OFP_ValidateContract(contract, reason) ||
      !OFP_ValidateProfile(profile, contract, envelope.evaluation_time, reason) ||
      !OFP_ValidateContexts(contexts, profile, contract, envelope.evaluation_time, reason) ||
      !OFP_ValidateBars(bars, profile, contract, envelope.evaluation_time, reason) ||
      !OFP_ValidateQuoteProvenance(quote, profile, contract, reason) ||
      !OFP_ValidateEnvelope(bars, envelope, reason))
   {
      OFP_SetDecision(out, OFP_DECISION_INVALID, variant, reason,
                      "OFPR input contract rejected before replay");
      return false;
   }

   OFPState state;
   OFP_ResetState(state);
   OFP_SetDecision(out, OFP_DECISION_NONE, variant, "OFPR_NO_SIGNAL", "");
   for(int index = 0; index < ArraySize(bars); ++index)
   {
      OFPContextBar context;
      bool causal_context = OFP_SelectContext(contexts, bars[index].available_at, context);
      bool causal_profile = profile.available_at <= bars[index].available_at;
      if(!causal_context || !causal_profile)
      {
         OFP_ResetState(state);
         continue;
      }

      if(state.phase != OFP_PHASE_IDLE)
      {
         int elapsed = index - state.setup_index;
         bool beyond_outer = state.direction == OFP_DIRECTION_LONG
                             ? bars[index].close < state.edge - state.frozen_buffer
                             : bars[index].close > state.edge + state.frozen_buffer;
         state.outside_close_count = beyond_outer ? state.outside_close_count + 1 : 0;
         bool expired_or_cancelled = state.outside_close_count >= 2 ||
                                     elapsed > OFPR_TRIGGER_BARS;
         bool triggered = state.direction == OFP_DIRECTION_LONG
                          ? bars[index].close > state.test_high
                          : bars[index].close < state.test_low;
         if(!triggered && elapsed >= OFPR_TRIGGER_BARS)
            expired_or_cancelled = true;
         if(expired_or_cancelled)
         {
            OFP_ResetState(state);
            continue;
         }
         else if(triggered)
         {
            if(index == ArraySize(bars) - 1)
               return OFPR_BuildGeometry(variant, contract, profile, bars, index,
                                         quote, envelope, state, out);
            OFP_ResetState(state);
            continue;
         }
         else
            continue;
      }

      OFPR_StartCandidate(variant, profile, context, bars, index, state);
   }
   return false;
}

bool OFPR00_Replay(const OFPDataContract &contract,
                   const OFPProfile &profile,
                   const OFPContextBar &contexts[],
                   const OFPBar &bars[],
                   const OFPProspectiveQuote &quote,
                   const OFPDecisionEnvelope &envelope,
                   OFPDecision &out)
{
   return OFPR_Replay(OFPR_00_PROFILE_PRICE_CONTROL, contract, profile,
                      contexts, bars, quote, envelope, out);
}

bool OFPR01_Replay(const OFPDataContract &contract,
                   const OFPProfile &profile,
                   const OFPContextBar &contexts[],
                   const OFPBar &bars[],
                   const OFPProspectiveQuote &quote,
                   const OFPDecisionEnvelope &envelope,
                   OFPDecision &out)
{
   return OFPR_Replay(OFPR_01_TICK_ACTIVITY, contract, profile,
                      contexts, bars, quote, envelope, out);
}

bool OFPR02_Replay(const OFPDataContract &contract,
                   const OFPProfile &profile,
                   const OFPContextBar &contexts[],
                   const OFPBar &bars[],
                   const OFPProspectiveQuote &quote,
                   const OFPDecisionEnvelope &envelope,
                   OFPDecision &out)
{
   return OFPR_Replay(OFPR_02_QUOTE_IMBALANCE, contract, profile,
                      contexts, bars, quote, envelope, out);
}

#endif // EA_LAB_OFPR_REVERSAL_MQH
