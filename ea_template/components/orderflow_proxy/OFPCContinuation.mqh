//+------------------------------------------------------------------+
//| OFPCContinuation.mqh                                             |
//| OFPC-00/01/02 order-free completed-M5 continuation mechanics.   |
//+------------------------------------------------------------------+
#ifndef EA_LAB_OFPC_CONTINUATION_MQH
#define EA_LAB_OFPC_CONTINUATION_MQH

#include "TickActivityProfile.mqh"

const double OFPC_ZONE_ATR_MULTIPLIER = 0.20;
const double OFPC_IMBALANCE_THRESHOLD = 0.20;
const double OFPC_TARGET_R_MULTIPLIER = 2.00;
const int OFPC_RETEST_BARS = 6;
const int OFPC_CONFIRM_BARS = 3;

bool OFPC_IsVariant(const ENUM_OFP_VARIANT variant)
{
   return variant == OFPC_00_PROFILE_PRICE_CONTROL ||
          variant == OFPC_01_TICK_ACTIVITY ||
          variant == OFPC_02_QUOTE_IMBALANCE;
}

int OFPC_ContextDirection(const OFPContextBar &context,
                          const OFPProfile &profile)
{
   if(context.close > profile.vah)
      return OFP_DIRECTION_LONG;
   if(context.close < profile.val)
      return OFP_DIRECTION_SHORT;
   return OFP_DIRECTION_NONE;
}

bool OFPC_CloseBeyondOuter(const OFPBar &bar,
                           const int direction,
                           const double edge,
                           const double buffer)
{
   return direction == OFP_DIRECTION_LONG
          ? bar.close > edge + buffer
          : bar.close < edge - buffer;
}

bool OFPC_ClosePastOppositeOuter(const OFPBar &bar,
                                 const int direction,
                                 const double edge,
                                 const double buffer)
{
   return direction == OFP_DIRECTION_LONG
          ? bar.close < edge - buffer
          : bar.close > edge + buffer;
}

bool OFPC_StartFirst(const OFPProfile &profile,
                     const OFPBar &bars[],
                     const int index,
                     const int direction,
                     OFPState &state)
{
   double atr = 0.0;
   if(!OFP_ATR14Preceding(bars, index, atr))
      return false;
   double edge = direction == OFP_DIRECTION_LONG ? profile.vah : profile.val;
   double buffer = OFPC_ZONE_ATR_MULTIPLIER * atr;
   if(!OFPC_CloseBeyondOuter(bars[index], direction, edge, buffer))
      return false;
   OFP_ResetState(state);
   state.phase = OFPC_PHASE_SECOND;
   state.direction = direction;
   state.first_index = index;
   state.setup_index = index;
   state.edge = edge;
   state.frozen_atr14 = atr;
   state.frozen_buffer = buffer;
   return true;
}

bool OFPC_BuildGeometry(const ENUM_OFP_VARIANT variant,
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
   double entry = state.direction == OFP_DIRECTION_LONG ? quote.ask : quote.bid;
   double stop = state.direction == OFP_DIRECTION_LONG
                 ? state.retest_low - state.frozen_buffer
                 : state.retest_high + state.frozen_buffer;
   double gross_risk = state.direction == OFP_DIRECTION_LONG
                       ? entry - stop : stop - entry;
   if(gross_risk <= 0.0)
   {
      OFP_SetDecision(out, OFP_DECISION_REJECTED, variant,
                      "OFPC_INVALID_GEOMETRY",
                      "prospective quote is not beyond structural stop");
      return false;
   }
   double target = state.direction == OFP_DIRECTION_LONG
                   ? entry + OFPC_TARGET_R_MULTIPLIER * gross_risk
                   : entry - OFPC_TARGET_R_MULTIPLIER * gross_risk;
   double net_risk = gross_risk + quote.all_in_cost_price;
   double net_reward = OFPC_TARGET_R_MULTIPLIER * gross_risk -
                       quote.all_in_cost_price;
   if(net_risk <= 0.0 || net_reward <= 0.0)
   {
      OFP_SetDecision(out, OFP_DECISION_REJECTED, variant,
                      "OFPC_COST_CONSUMES_GEOMETRY",
                      "prospective geometry is non-positive after cost");
      return false;
   }

   OFP_SetDecision(out, OFP_DECISION_SIGNAL, variant,
                   "OFPC_PROXY_GEOMETRY_READY",
                   "MT5 proxy only; order-free; time exit remains consumer-owned");
   out.geometry.direction = state.direction;
   out.geometry.prospective_entry = entry;
   out.geometry.stop_price = stop;
   out.geometry.target_price = target;
   out.geometry.gross_risk = gross_risk;
   out.geometry.net_risk = net_risk;
   out.geometry.net_reward = net_reward;
   out.geometry.net_rr = net_reward / net_risk;
   out.geometry.setup_time = bars[state.setup_index].close_time;
   out.geometry.trigger_time = bars[trigger_index].close_time;
   out.geometry.retest_window_completed_m5_bars = OFPC_RETEST_BARS;
   out.geometry.confirmation_window_completed_m5_bars = OFPC_CONFIRM_BARS;
   out.geometry.consumer_time_exit_m5_bars_after_fill = 12;
   return true;
}

bool OFPC_Replay(const ENUM_OFP_VARIANT variant,
                 const OFPDataContract &contract,
                 const OFPProfile &profile,
                 const OFPContextBar &contexts[],
                 const OFPBar &bars[],
                 const OFPProspectiveQuote &quote,
                 const OFPDecisionEnvelope &envelope,
                 OFPDecision &out)
{
   string reason = "";
   if(!OFPC_IsVariant(variant) ||
      !OFP_ValidateContract(contract, reason) ||
      !OFP_ValidateProfile(profile, contract, envelope.evaluation_time, reason) ||
      !OFP_ValidateContexts(contexts, profile, contract, envelope.evaluation_time, reason) ||
      !OFP_ValidateBars(bars, profile, contract, envelope.evaluation_time, reason) ||
      !OFP_ValidateQuoteProvenance(quote, profile, contract, reason) ||
      !OFP_ValidateEnvelope(bars, envelope, reason))
   {
      OFP_SetDecision(out, OFP_DECISION_INVALID, variant, reason,
                      "OFPC input contract rejected before replay");
      return false;
   }

   OFPState state;
   OFP_ResetState(state);
   OFP_SetDecision(out, OFP_DECISION_NONE, variant, "OFPC_NO_SIGNAL", "");
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
      int context_direction = OFPC_ContextDirection(context, profile);
      if(state.phase != OFP_PHASE_IDLE)
      {
         if(OFPC_ClosePastOppositeOuter(bars[index], state.direction,
                                        state.edge, state.frozen_buffer))
         {
            OFP_ResetState(state);
            continue;
         }
         else if(state.phase == OFPC_PHASE_SECOND)
         {
            bool consecutive = index == state.first_index + 1;
            bool beyond = OFPC_CloseBeyondOuter(bars[index], state.direction,
                                                state.edge, state.frozen_buffer);
            bool evidence_ok = true;
            if(OFP_VariantNeedsActivity(variant))
               evidence_ok = OFP_RelativeActivityPasses(bars, index);
            if(evidence_ok && OFP_VariantNeedsImbalance(variant))
            {
               double ratio = 0.0;
               evidence_ok = OFP_QuoteImbalance(bars[index], ratio) &&
                             (state.direction == OFP_DIRECTION_LONG
                              ? ratio + OFP_EPSILON >= OFPC_IMBALANCE_THRESHOLD
                              : ratio - OFP_EPSILON <= -OFPC_IMBALANCE_THRESHOLD);
            }
            if(!consecutive || !beyond || !evidence_ok)
            {
               OFP_ResetState(state);
               if(context_direction != OFP_DIRECTION_NONE)
                  OFPC_StartFirst(profile, bars, index, context_direction, state);
               continue;
            }
            state.phase = OFPC_PHASE_RETEST;
            state.setup_index = index;
            continue;
         }
         else if(state.phase == OFPC_PHASE_RETEST)
         {
            int elapsed = index - state.setup_index;
            bool overlaps = OFP_RangeOverlaps(bars[index].low, bars[index].high,
                                              state.edge - state.frozen_buffer,
                                              state.edge + state.frozen_buffer);
            bool breakout_side = state.direction == OFP_DIRECTION_LONG
                                 ? bars[index].close > state.edge
                                 : bars[index].close < state.edge;
            if(elapsed > OFPC_RETEST_BARS ||
               (elapsed >= OFPC_RETEST_BARS && (!overlaps || !breakout_side)))
            {
               OFP_ResetState(state);
               continue;
            }
            else if(!overlaps || !breakout_side)
               continue;
            else
            {
               state.phase = OFPC_PHASE_CONFIRM;
               state.retest_index = index;
               state.retest_low = bars[index].low;
               state.retest_high = bars[index].high;
               continue;
            }
         }
         else
         {
            int elapsed = index - state.retest_index;
            state.retest_low = MathMin(state.retest_low, bars[index].low);
            state.retest_high = MathMax(state.retest_high, bars[index].high);
            bool beyond_retest = state.direction == OFP_DIRECTION_LONG
                                 ? bars[index].close > bars[state.retest_index].high
                                 : bars[index].close < bars[state.retest_index].low;
            bool directional = true;
            if(OFP_VariantNeedsImbalance(variant))
            {
               double ratio = 0.0;
               directional = OFP_QuoteImbalance(bars[index], ratio) &&
                             (state.direction == OFP_DIRECTION_LONG
                              ? ratio > 0.0 : ratio < 0.0);
            }
            if(elapsed > OFPC_CONFIRM_BARS ||
               (elapsed >= OFPC_CONFIRM_BARS && (!beyond_retest || !directional)))
            {
               OFP_ResetState(state);
               continue;
            }
            else if(!beyond_retest || !directional)
               continue;
            else if(index == ArraySize(bars) - 1)
               return OFPC_BuildGeometry(variant, contract, profile, bars, index,
                                         quote, envelope, state, out);
            else
            {
               OFP_ResetState(state);
               continue;
            }
         }
      }

      if(state.phase == OFP_PHASE_IDLE && context_direction != OFP_DIRECTION_NONE)
         OFPC_StartFirst(profile, bars, index, context_direction, state);
   }
   return false;
}

bool OFPC00_Replay(const OFPDataContract &contract,
                   const OFPProfile &profile,
                   const OFPContextBar &contexts[],
                   const OFPBar &bars[],
                   const OFPProspectiveQuote &quote,
                   const OFPDecisionEnvelope &envelope,
                   OFPDecision &out)
{
   return OFPC_Replay(OFPC_00_PROFILE_PRICE_CONTROL, contract, profile,
                      contexts, bars, quote, envelope, out);
}

bool OFPC01_Replay(const OFPDataContract &contract,
                   const OFPProfile &profile,
                   const OFPContextBar &contexts[],
                   const OFPBar &bars[],
                   const OFPProspectiveQuote &quote,
                   const OFPDecisionEnvelope &envelope,
                   OFPDecision &out)
{
   return OFPC_Replay(OFPC_01_TICK_ACTIVITY, contract, profile,
                      contexts, bars, quote, envelope, out);
}

bool OFPC02_Replay(const OFPDataContract &contract,
                   const OFPProfile &profile,
                   const OFPContextBar &contexts[],
                   const OFPBar &bars[],
                   const OFPProspectiveQuote &quote,
                   const OFPDecisionEnvelope &envelope,
                   OFPDecision &out)
{
   return OFPC_Replay(OFPC_02_QUOTE_IMBALANCE, contract, profile,
                      contexts, bars, quote, envelope, out);
}

#endif // EA_LAB_OFPC_CONTINUATION_MQH
