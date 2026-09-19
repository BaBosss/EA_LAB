//+------------------------------------------------------------------+
//| OF02Continuation.mqh                                             |
//| Order-free completed-bar value-edge continuation component.      |
//+------------------------------------------------------------------+
#ifndef EA_LAB_OF02_CONTINUATION_MQH
#define EA_LAB_OF02_CONTINUATION_MQH

#include "OrderFlowValidation.mqh"

const double OF02_ZONE_ATR_MULTIPLIER = 0.20;
const double OF02_VOLUME_MULTIPLIER   = 1.50;
const double OF02_DELTA_THRESHOLD     = 0.20;
const double OF02_TARGET_R_MULTIPLIER = 2.00;
const int    OF02_RETEST_BARS         = 6;
const int    OF02_CONFIRM_BARS        = 3;

int OF02_ContextDirection(const OFContextBar &context,
                          const OFProfile &profile)
{
   if(context.close > profile.vah)
      return OF_DIRECTION_LONG;
   if(context.close < profile.val)
      return OF_DIRECTION_SHORT;
   return OF_DIRECTION_NONE;
}

bool OF02_CloseBeyondOuter(const OFBar &bar,
                           const int direction,
                           const double edge,
                           const double buffer)
{
   return (direction == OF_DIRECTION_LONG)
          ? bar.close > edge + buffer
          : bar.close < edge - buffer;
}

bool OF02_ClosePastOppositeOuter(const OFBar &bar,
                                 const int direction,
                                 const double edge,
                                 const double buffer)
{
   // "Opposite outer edge" is the far boundary on the value-area side of
   // the frozen breakout zone: VAH-buffer for long, VAL+buffer for short.
   return (direction == OF_DIRECTION_LONG)
          ? bar.close < edge - buffer
          : bar.close > edge + buffer;
}

void OF02_StartFirstBreakout(const OFDataContract &contract,
                             const OFProfile &profile,
                             const OFContextBar &context,
                             const OFBar &bars[],
                             const int index,
                             const int direction,
                             const double atr,
                             OFState &state,
                             OFDecision &out)
{
   state.phase         = OF02_PHASE_WAIT_SECOND;
   state.direction     = direction;
   state.setup_index   = index;
   state.elapsed_bars  = 0;
   state.edge          = (direction == OF_DIRECTION_LONG) ? profile.vah : profile.val;
   state.frozen_atr14  = atr;
   state.frozen_buffer = atr * OF02_ZONE_ATR_MULTIPLIER;
   OF_PinState(state, contract, profile, context);
   OF_SetDecision(out, OF_DECISION_ARMED, "OF02_FIRST_BREAKOUT_CLOSE",
                  "first completed close beyond frozen outer zone; waiting for second");
}

bool OF02_BuildGeometry(const OFBar &bars[],
                        const int trigger_index,
                        const OFQuote &quote,
                        const OFDataContract &contract,
                        const OFFreshnessPolicy &policy,
                        const datetime as_of,
                        OFState &state,
                        OFDecision &out)
{
   string reason = "";
   if(!OF_ValidateQuote(quote, contract, policy,
                        bars[trigger_index].close_time, as_of, reason))
   {
      OF_SetDecision(out, OF_DECISION_INVALID, reason,
                     "OF02 confirmation had no valid caller-supplied prospective quote/cost");
      return false;
   }

   double entry = (state.direction == OF_DIRECTION_LONG) ? quote.ask : quote.bid;
   double stop = (state.direction == OF_DIRECTION_LONG)
                 ? state.retest_low - state.frozen_buffer
                 : state.retest_high + state.frozen_buffer;
   double gross_risk = (state.direction == OF_DIRECTION_LONG)
                       ? entry - stop : stop - entry;
   if(gross_risk <= 0.0)
   {
      OF_SetDecision(out, OF_DECISION_REJECTED, "OF02_INVALID_GEOMETRY",
                     "prospective quote is not beyond the frozen structural stop");
      return false;
   }
   double target = (state.direction == OF_DIRECTION_LONG)
                   ? entry + OF02_TARGET_R_MULTIPLIER * gross_risk
                   : entry - OF02_TARGET_R_MULTIPLIER * gross_risk;
   double net_risk = gross_risk + quote.all_in_cost_price;
   double net_reward = OF02_TARGET_R_MULTIPLIER * gross_risk -
                       quote.all_in_cost_price;
   if(net_risk <= 0.0 || net_reward <= 0.0)
   {
      OF_SetDecision(out, OF_DECISION_REJECTED, "OF02_COST_CONSUMES_GEOMETRY",
                     "caller-supplied cost makes the prospective geometry non-positive");
      return false;
   }

   OF_SetDecision(out, OF_DECISION_SIGNAL, "OF02_SIGNAL_GEOMETRY_READY",
                  "order-free geometry; TEMPLATE_EXIT_BINDING_REQUIRED; time exit consumer-owned");
   out.geometry.direction                  = state.direction;
   out.geometry.prospective_entry          = entry;
   out.geometry.stop_price                 = stop;
   out.geometry.target_price               = target;
   out.geometry.gross_risk                 = gross_risk;
   out.geometry.net_reward                 = net_reward;
   out.geometry.net_risk                   = net_risk;
   out.geometry.net_rr                     = net_reward / net_risk;
   out.geometry.setup_time                 = bars[state.setup_index].close_time;
   out.geometry.trigger_time               = bars[trigger_index].close_time;
   out.geometry.retest_window_completed_m5_bars = OF02_RETEST_BARS;
   out.geometry.confirmation_window_completed_m5_bars = OF02_CONFIRM_BARS;
   out.geometry.consumer_time_exit_m5_bars_after_fill = 12;
   out.geometry.quote_record_id            = quote.record_id;
   out.geometry.prospective_quote_not_fill = true;
   return true;
}

void OF02_ProcessBar(const OFDataContract &contract,
                     const OFFreshnessPolicy &policy,
                     const OFProfile &profile,
                     const OFContextBar &context,
                     const OFBar &bars[],
                     const int index,
                     const OFQuote &quote,
                     const datetime as_of,
                     OFState &state,
                     OFDecision &out)
{
   OF_SetDecision(out, OF_DECISION_NONE, "OF02_NO_SIGNAL", "");

   if(state.phase != OF_PHASE_IDLE && !OF_StatePinsMatch(state, contract, profile, context))
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_CANCELLED, "OF02_REVISION_OR_CONTEXT_RESET",
                     "source/profile/context identity changed while armed");
      return;
   }

   int context_direction = OF02_ContextDirection(context, profile);
   if(state.phase == OF_PHASE_IDLE)
   {
      if(context_direction == OF_DIRECTION_NONE)
         return;
      double atr = 0.0;
      if(!OF_ATR14Preceding(bars, index, atr))
         return;
      double edge = (context_direction == OF_DIRECTION_LONG) ? profile.vah : profile.val;
      double buffer = atr * OF02_ZONE_ATR_MULTIPLIER;
      if(!OF02_CloseBeyondOuter(bars[index], context_direction, edge, buffer))
         return;
      OF02_StartFirstBreakout(contract, profile, context, bars, index,
                              context_direction, atr, state, out);
      return;
   }

   if(index <= state.setup_index)
      return;

   if(OF02_ClosePastOppositeOuter(bars[index], state.direction,
                                  state.edge, state.frozen_buffer))
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_CANCELLED, "OF02_CLOSE_PAST_OPPOSITE_OUTER_EDGE",
                     "completed close crossed the value-side boundary of the frozen zone");
      return;
   }

   if(state.phase == OF02_PHASE_WAIT_SECOND)
   {
      if(index != state.setup_index + 1 ||
         !OF02_CloseBeyondOuter(bars[index], state.direction,
                                state.edge, state.frozen_buffer))
      {
         // A non-consecutive sequence is discarded.  A new beyond-zone close
         // may immediately become a fresh first close with a newly frozen ATR.
         int direction = state.direction;
         OF_ResetState(state);
         double atr = 0.0;
         if(OF_ATR14Preceding(bars, index, atr))
         {
            double edge = (direction == OF_DIRECTION_LONG) ? profile.vah : profile.val;
            double buffer = atr * OF02_ZONE_ATR_MULTIPLIER;
            if(OF02_CloseBeyondOuter(bars[index], direction, edge, buffer))
               OF02_StartFirstBreakout(contract, profile, context, bars, index,
                                       direction, atr, state, out);
         }
         return;
      }

      double median = 0.0;
      double delta = OF_SignedDelta(bars[index]);
      bool directional_delta = (state.direction == OF_DIRECTION_LONG)
                               ? delta >= OF02_DELTA_THRESHOLD
                               : delta <= -OF02_DELTA_THRESHOLD;
      bool evidence_ok = OF_Previous20MedianVolume(bars, index, median) &&
                         bars[index].total_executed_volume + OF_EPSILON >=
                            OF02_VOLUME_MULTIPLIER * median &&
                         directional_delta;
      if(!evidence_ok)
      {
         // The second bar can become the first bar of a new consecutive pair.
         int direction = state.direction;
         OF_ResetState(state);
         double atr = 0.0;
         if(OF_ATR14Preceding(bars, index, atr))
            OF02_StartFirstBreakout(contract, profile, context, bars, index,
                                    direction, atr, state, out);
         return;
      }

      state.phase        = OF02_PHASE_WAIT_RETEST;
      state.setup_index  = index;
      state.elapsed_bars = 0;
      OF_SetDecision(out, OF_DECISION_ARMED, "OF02_BREAKOUT_CONFIRMED",
                     "two closes and second-bar volume/delta accepted; waiting retest");
      return;
   }

   if(state.phase == OF02_PHASE_WAIT_RETEST)
   {
      state.elapsed_bars = index - state.setup_index;
      if(state.elapsed_bars > OF02_RETEST_BARS)
      {
         OF_ResetState(state);
         OF_SetDecision(out, OF_DECISION_EXPIRED, "OF02_RETEST_EXPIRED",
                        "no accepted retest in the next six completed M5 bars");
         return;
      }
      bool overlaps = OF_RangeOverlaps(bars[index].low, bars[index].high,
                                       state.edge - state.frozen_buffer,
                                       state.edge + state.frozen_buffer);
      bool closes_breakout_side = (state.direction == OF_DIRECTION_LONG)
                                  ? bars[index].close > state.edge
                                  : bars[index].close < state.edge;
      if((!overlaps || !closes_breakout_side) &&
         state.elapsed_bars >= OF02_RETEST_BARS)
      {
         OF_ResetState(state);
         OF_SetDecision(out, OF_DECISION_EXPIRED, "OF02_RETEST_EXPIRED",
                        "no accepted retest in the next six completed M5 bars");
         return;
      }
      if(!overlaps || !closes_breakout_side)
         return;

      state.phase        = OF02_PHASE_WAIT_CONFIRM;
      state.retest_index = index;
      state.elapsed_bars = 0;
      state.retest_low   = bars[index].low;
      state.retest_high  = bars[index].high;
      OF_SetDecision(out, OF_DECISION_ARMED, "OF02_RETEST_ACCEPTED",
                     "retest overlaps frozen zone and closes on breakout side");
      return;
   }

   if(state.phase != OF02_PHASE_WAIT_CONFIRM || index <= state.retest_index)
      return;

   state.elapsed_bars = index - state.retest_index;
   state.retest_low   = MathMin(state.retest_low, bars[index].low);
   state.retest_high  = MathMax(state.retest_high, bars[index].high);
   if(state.elapsed_bars > OF02_CONFIRM_BARS)
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_EXPIRED, "OF02_CONFIRM_EXPIRED",
                     "no accepted confirmation in the next three completed M5 bars");
      return;
   }

   double delta = OF_SignedDelta(bars[index]);
   bool directional_delta = (state.direction == OF_DIRECTION_LONG) ? delta > 0.0 : delta < 0.0;
   bool beyond_retest = (state.direction == OF_DIRECTION_LONG)
                        ? bars[index].close > bars[state.retest_index].high
                        : bars[index].close < bars[state.retest_index].low;
   if((!directional_delta || !beyond_retest) &&
      state.elapsed_bars >= OF02_CONFIRM_BARS)
   {
      OF_ResetState(state);
      OF_SetDecision(out, OF_DECISION_EXPIRED, "OF02_CONFIRM_EXPIRED",
                     "no accepted confirmation in the next three completed M5 bars");
      return;
   }
   if(!directional_delta || !beyond_retest)
      return;

   OF02_BuildGeometry(bars, index, quote, contract, policy, as_of, state, out);
   OF_ResetState(state);
}

bool OF02_Replay(const OFDataContract &contract,
                 const OFFreshnessPolicy &policy,
                 const OFProfile &profile,
                 const OFContextBar &context,
                 const OFBar &bars[],
                 const OFQuote &quote,
                 const datetime as_of,
                 OFDecision &out)
{
   string reason = "";
   if(!OF_ValidateContract(contract, policy, reason) ||
      !OF_ValidateProfile(profile, contract, policy, as_of, reason) ||
      !OF_ValidateContext(context, contract, profile, policy, as_of, reason) ||
      !OF_ValidateBars(bars, contract, policy, as_of, reason))
   {
      OF_SetDecision(out, OF_DECISION_INVALID, reason,
                     "OF02 input contract rejected before replay");
      return false;
   }

   OFState state;
   OF_ResetState(state);
   OFDecision step;
   for(int i = 0; i < ArraySize(bars); ++i)
   {
      OF02_ProcessBar(contract, policy, profile, context, bars, i,
                      quote, as_of, state, step);
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

#endif // EA_LAB_OF02_CONTINUATION_MQH
