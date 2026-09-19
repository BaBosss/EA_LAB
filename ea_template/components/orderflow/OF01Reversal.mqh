//+------------------------------------------------------------------+
//| OF01Reversal.mqh                                                 |
//| Order-free completed-bar value-edge rejection component.         |
//+------------------------------------------------------------------+
#ifndef EA_LAB_OF01_REVERSAL_MQH
#define EA_LAB_OF01_REVERSAL_MQH

#include "OrderFlowValidation.mqh"

const double OF01_ZONE_ATR_MULTIPLIER = 0.20;
const double OF01_VOLUME_MULTIPLIER   = 1.50;
const double OF01_DELTA_THRESHOLD     = 0.20;
const double OF01_WICK_RATIO_MIN      = 0.40;
const double OF01_MIN_NET_RR          = 1.50;
const int    OF01_TRIGGER_BARS        = 3;

bool OF01_ContextInsideValue(const OFContextBar &context,
                             const OFProfile &profile)
{
   return context.close > profile.val && context.close < profile.vah;
}

bool OF01_TestCandidate(const OFBar &bars[],
                        const int index,
                        const OFProfile &profile,
                        int &direction,
                        double &atr,
                        double &buffer)
{
   if(!OF_Previous20MedianVolume(bars, index, buffer))
      return false;
   double median = buffer;
   if(!OF_ATR14Preceding(bars, index, atr))
      return false;
   buffer = atr * OF01_ZONE_ATR_MULTIPLIER;

   OFBar bar = bars[index];
   if(bar.total_executed_volume + OF_EPSILON < OF01_VOLUME_MULTIPLIER * median)
      return false;

   double range = bar.high - bar.low;
   if(range <= 0.0)
      return false;
   double delta = OF_SignedDelta(bar);

   bool long_overlap = OF_RangeOverlaps(bar.low, bar.high,
                                        profile.val - buffer,
                                        profile.val + buffer);
   double lower_wick = MathMin(bar.open, bar.close) - bar.low;
   bool long_test = long_overlap &&
                    bar.close > profile.val && bar.close < profile.vah &&
                    delta <= -OF01_DELTA_THRESHOLD &&
                    lower_wick / range + OF_EPSILON >= OF01_WICK_RATIO_MIN;

   bool short_overlap = OF_RangeOverlaps(bar.low, bar.high,
                                         profile.vah - buffer,
                                         profile.vah + buffer);
   double upper_wick = bar.high - MathMax(bar.open, bar.close);
   bool short_test = short_overlap &&
                     bar.close < profile.vah && bar.close > profile.val &&
                     delta >= OF01_DELTA_THRESHOLD &&
                     upper_wick / range + OF_EPSILON >= OF01_WICK_RATIO_MIN;

   if(long_test == short_test)
      return false;
   direction = long_test ? OF_DIRECTION_LONG : OF_DIRECTION_SHORT;
   return true;
}

bool OF01_BuildGeometry(const OFBar &bars[],
                        const int trigger_index,
                        const OFProfile &profile,
                        const OFQuote &quote,
                        const OFDataContract &contract,
                        const OFFreshnessPolicy &policy,
                        const OFDecisionEnvelope &envelope,
                        OFState &state,
                        OFDecision &out)
{
   string reason = "";
   if(!OF_ValidateQuote(quote, contract, policy,
                        bars[trigger_index].record_id,
                        bars[trigger_index].close_time, envelope, reason))
   {
      OF_SetDecision(out, OF_DECISION_INVALID, reason,
                     "OF01 trigger had no valid caller-supplied prospective quote/cost");
      return false;
   }

   double extreme_low  = bars[state.setup_index].low;
   double extreme_high = bars[state.setup_index].high;
   for(int i = state.setup_index + 1; i <= trigger_index; ++i)
   {
      extreme_low  = MathMin(extreme_low, bars[i].low);
      extreme_high = MathMax(extreme_high, bars[i].high);
   }

   double entry = (state.direction == OF_DIRECTION_LONG) ? quote.ask : quote.bid;
   double stop  = (state.direction == OF_DIRECTION_LONG)
                  ? extreme_low - state.frozen_buffer
                  : extreme_high + state.frozen_buffer;
   double target = profile.poc;
   double gross_risk = (state.direction == OF_DIRECTION_LONG)
                       ? entry - stop : stop - entry;
   double gross_reward = (state.direction == OF_DIRECTION_LONG)
                         ? target - entry : entry - target;
   double net_risk = gross_risk + quote.all_in_cost_price;
   double net_reward = gross_reward - quote.all_in_cost_price;

   if(gross_risk <= 0.0 || net_risk <= 0.0 || net_reward <= 0.0)
   {
      OF_SetDecision(out, OF_DECISION_REJECTED, "OF01_INVALID_GEOMETRY",
                     "POC/stop/quote geometry is not directionally valid after supplied cost");
      return false;
   }
   double rr = net_reward / net_risk;
   if(rr + OF_EPSILON < OF01_MIN_NET_RR)
   {
      OF_SetDecision(out, OF_DECISION_REJECTED, "OF01_NET_RR_BELOW_1_5",
                     "prospective quote/cost fails the locked research-prototype RR gate");
      return false;
   }

   OF_SetDecision(out, OF_DECISION_SIGNAL, "OF01_SIGNAL_GEOMETRY_READY",
                  "order-free geometry; TEMPLATE_EXIT_BINDING_REQUIRED");
   out.geometry.direction                  = state.direction;
   out.geometry.prospective_entry          = entry;
   out.geometry.stop_price                 = stop;
   out.geometry.target_price               = target;
   out.geometry.gross_risk                 = gross_risk;
   out.geometry.net_reward                 = net_reward;
   out.geometry.net_risk                   = net_risk;
   out.geometry.net_rr                     = rr;
   out.geometry.setup_time                 = bars[state.setup_index].close_time;
   out.geometry.trigger_time               = bars[trigger_index].close_time;
   out.geometry.confirmation_window_completed_m5_bars = OF01_TRIGGER_BARS;
   out.geometry.quote_record_id            = quote.record_id;
   out.geometry.setup_context_record_id    = state.context_record_id;
   out.geometry.prospective_quote_not_fill = true;
   return true;
}

// Processes exactly one newly completed M5 bar from a prevalidated chronological
// array.  Replay() below is the safer public entry point for an offline consumer.
void OF01_ProcessBar(const OFDataContract &contract,
                     const OFFreshnessPolicy &policy,
                     const OFProfile &profile,
                     const OFContextBar &context,
                     const OFBar &bars[],
                     const int index,
                     const OFQuote &quote,
                     const OFDecisionEnvelope &envelope,
                     OFState &state,
                     OFDecision &out)
{
   OF_SetDecision(out, OF_DECISION_NONE, "OF01_NO_SIGNAL", "");

   if(state.phase != OF_PHASE_IDLE && !OF_StatePinsMatch(state, contract, profile, context))
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_CANCELLED, "OF01_REVISION_OR_CONTEXT_RESET",
                     "source/profile/context identity changed while armed");
      return;
   }

   if(state.phase == OF_PHASE_IDLE)
   {
      if(!OF01_ContextInsideValue(context, profile))
         return;
      int direction = OF_DIRECTION_NONE;
      double atr = 0.0;
      double buffer = 0.0;
      if(!OF01_TestCandidate(bars, index, profile, direction, atr, buffer))
         return;

      state.phase         = OF01_PHASE_WAIT_TRIGGER;
      state.direction     = direction;
      state.setup_index   = index;
      state.elapsed_bars  = 0;
      state.edge          = (direction == OF_DIRECTION_LONG) ? profile.val : profile.vah;
      state.frozen_atr14  = atr;
      state.frozen_buffer = buffer;
      state.test_low      = bars[index].low;
      state.test_high     = bars[index].high;
      OF_PinState(state, contract, profile, context);
      OF_SetDecision(out, OF_DECISION_ARMED, "OF01_ARMED",
                     "test bar accepted; frozen ATR-derived zone and stop buffer");
      return;
   }

   if(state.phase != OF01_PHASE_WAIT_TRIGGER || index <= state.setup_index)
      return;

   state.elapsed_bars = index - state.setup_index;
   bool beyond_outer = (state.direction == OF_DIRECTION_LONG)
                       ? bars[index].close < state.edge - state.frozen_buffer
                       : bars[index].close > state.edge + state.frozen_buffer;
   state.outside_close_count = beyond_outer ? state.outside_close_count + 1 : 0;
   if(state.outside_close_count >= 2)
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_CANCELLED, "OF01_TWO_CLOSES_BEYOND_OUTER_EDGE",
                     "two consecutive completed closes invalidated the rejection");
      return;
   }

   if(state.elapsed_bars > OF01_TRIGGER_BARS)
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_EXPIRED, "OF01_TRIGGER_EXPIRED",
                     "no completed-bar trigger within the next three M5 bars");
      return;
   }

   bool triggered = (state.direction == OF_DIRECTION_LONG)
                    ? bars[index].close > state.test_high
                    : bars[index].close < state.test_low;
   if(!triggered && state.elapsed_bars >= OF01_TRIGGER_BARS)
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_EXPIRED, "OF01_TRIGGER_EXPIRED",
                     "no completed-bar trigger within the next three M5 bars");
      return;
   }
   if(!triggered)
      return;

   OF01_BuildGeometry(bars, index, profile, quote, contract, policy, envelope, state, out);
   OF_ResetState(state);
}

bool OF01_ReplayChronological(const OFDataContract &contract,
                              const OFFreshnessPolicy &policy,
                              const OFProfile &profile,
                              const OFContextBar &contexts[],
                              const OFBar &bars[],
                              const OFQuote &quote,
                              const OFDecisionEnvelope &envelope,
                              OFDecision &out)
{
   string reason = "";
   if(!OF_ValidateContract(contract, policy, reason) ||
      !OF_ValidateProfile(profile, contract, policy, envelope.evaluation_time, reason) ||
      !OF_ValidateContexts(contexts, contract, profile, envelope.evaluation_time, reason) ||
      !OF_ValidateBars(bars, contract, policy, envelope.evaluation_time, reason) ||
      !OF_ValidateDecisionEnvelope(bars, envelope, reason))
   {
      OF_SetDecision(out, OF_DECISION_INVALID, reason,
                     "OF01 input contract rejected before replay");
      return false;
   }

   OFState state;
   OF_ResetState(state);
   OFDecision step;
   for(int i = 0; i < ArraySize(bars); ++i)
   {
      OFContextBar context;
      bool causal_profile = OF_ProfileAvailableAtDecision(profile, policy, bars[i].available_at);
      bool causal_context = OF_SelectContextForDecision(contexts, policy,
                                                        bars[i].available_at, context);
      if(!causal_profile || !causal_context)
      {
         if(state.phase != OF_PHASE_IDLE)
         {
            OF_ResetState(state);
            OF_SetDecision(out, OF_DECISION_CANCELLED,
                           "OF01_CONTEXT_UNAVAILABLE_AT_DECISION",
                           "profile/M15 context unavailable at historical decision time");
            return false;
         }
         continue;
      }
      OF01_ProcessBar(contract, policy, profile, context, bars, i,
                      quote, envelope, state, step);
      if(step.decision == OF_DECISION_SIGNAL ||
         step.decision == OF_DECISION_INVALID ||
         step.decision == OF_DECISION_REJECTED)
      {
         out = step;
         return step.decision == OF_DECISION_SIGNAL;
      }
      out = step;
   }
   return false;
}

// Compatibility wrapper for a single context record.  It is used only from
// that record's actual available_at onward; it is never copied backward.
bool OF01_Replay(const OFDataContract &contract,
                 const OFFreshnessPolicy &policy,
                 const OFProfile &profile,
                 const OFContextBar &context,
                 const OFBar &bars[],
                 const OFQuote &quote,
                 const OFDecisionEnvelope &envelope,
                 OFDecision &out)
{
   OFContextBar contexts[];
   ArrayResize(contexts, 1);
   contexts[0] = context;
   return OF01_ReplayChronological(contract, policy, profile, contexts,
                                   bars, quote, envelope, out);
}

#endif // EA_LAB_OF01_REVERSAL_MQH
