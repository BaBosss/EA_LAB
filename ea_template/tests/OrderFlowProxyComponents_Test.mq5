//+------------------------------------------------------------------+
//| OrderFlowProxyComponents_Test.mq5                                |
//| Compile-only harness. Do not execute or attach under this order. |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "../components/orderflow_proxy/OrderFlowProxyComponents.mqh"

void OnStart()
{
   OFPDataContract contract;
   contract.data_identity = OFP_DATA_IDENTITY;
   contract.profile_identity = OFP_PROFILE_IDENTITY;
   contract.imbalance_identity = OFP_IMBALANCE_IDENTITY;
   contract.profile_recipe_id = OFP_PROFILE_RECIPE_ID;
   contract.session_id = OFP_SESSION_ID;
   contract.signal_instrument_id = "FIXTURE";
   contract.signal_source_id = "FIXTURE_SOURCE";

   OFPQuoteTick ticks[];
   ArrayResize(ticks, 3);
   for(int i = 0; i < ArraySize(ticks); ++i)
   {
      ticks[i].instrument_id = contract.signal_instrument_id;
      ticks[i].source_id = contract.signal_source_id;
      ticks[i].time_msc = (long)(100 + i) * 1000;
      ticks[i].bid = 100.0 + i;
      ticks[i].ask = 100.0 + i;
      ticks[i].last = 999.0;
   }
   OFPD1Record previous_d1;
   previous_d1.record_id = "fixture-d1-100";
   previous_d1.instrument_id = contract.signal_instrument_id;
   previous_d1.source_id = contract.signal_source_id;
   previous_d1.sequence = 100;
   previous_d1.open_time = 100;
   previous_d1.available_at = 200;
   previous_d1.completed = true;
   OFPD1Record current_d1;
   current_d1.record_id = "fixture-d1-101";
   current_d1.instrument_id = contract.signal_instrument_id;
   current_d1.source_id = contract.signal_source_id;
   current_d1.sequence = 101;
   current_d1.open_time = 200;
   current_d1.available_at = 200;
   current_d1.completed = false;
   OFPProfile profile;
   string profile_reason = "";
   bool profile_built = OFP_BuildTickActivityProfile(ticks, previous_d1,
                                                       current_d1, 200,
                                                       1.0, 0.1,
                                                       "fixture-profile",
                                                       profile, profile_reason);

   OFPContextBar contexts[];
   ArrayResize(contexts, 1);
   contexts[0].record_id = "fixture-m15";
   contexts[0].instrument_id = contract.signal_instrument_id;
   contexts[0].source_id = contract.signal_source_id;
   contexts[0].d1_record_id = current_d1.record_id;
   contexts[0].d1_sequence = current_d1.sequence;
   contexts[0].d1_open_time = current_d1.open_time;
   contexts[0].sequence = 1;
   contexts[0].period_seconds = 900;
   contexts[0].open_time = 200;
   contexts[0].close_time = 1100;
   contexts[0].available_at = 1100;
   contexts[0].completed = true;
   contexts[0].close = 105.0;

   OFPBar bars[];
   ArrayResize(bars, 21);
   for(int i = 0; i < ArraySize(bars); ++i)
   {
      bars[i].record_id = "fixture-m5-" + IntegerToString(i);
      bars[i].instrument_id = contract.signal_instrument_id;
      bars[i].source_id = contract.signal_source_id;
      bars[i].d1_record_id = current_d1.record_id;
      bars[i].d1_sequence = current_d1.sequence;
      bars[i].d1_open_time = current_d1.open_time;
      bars[i].sequence = (ulong)(i + 1);
      bars[i].period_seconds = 300;
      bars[i].open_time = 1100 + i * 300;
      bars[i].close_time = bars[i].open_time + 300;
      bars[i].available_at = bars[i].close_time;
      bars[i].completed = true;
      bars[i].open = 105.0;
      bars[i].high = 105.5;
      bars[i].low = 104.5;
      bars[i].close = 105.0;
      bars[i].tick_volume = 100;
      bars[i].quote_up_count = 1;
      bars[i].quote_down_count = 0;
      bars[i].quote_unchanged_count = 0;
      bars[i].quote_proxy_valid = true;
   }

   OFPProspectiveQuote quote;
   quote.record_id = "fixture-quote";
   quote.instrument_id = contract.signal_instrument_id;
   quote.source_id = contract.signal_source_id;
   quote.d1_record_id = current_d1.record_id;
   quote.d1_sequence = current_d1.sequence;
   quote.d1_open_time = current_d1.open_time;
   quote.observed_at = bars[20].close_time + 1;
   quote.available_at = quote.observed_at;
   quote.bid = 105.0;
   quote.ask = 105.1;
   quote.all_in_cost_price = 0.0;

   OFPDecisionEnvelope envelope;
   envelope.evaluation_time = quote.available_at;
   envelope.current_closed_bar_record_id = bars[20].record_id;
   envelope.current_closed_bar_close_time = bars[20].close_time;

   OFPDecision decisions[6];
   bool results[6];
   results[0] = OFPR00_Replay(contract, profile, contexts, bars, quote, envelope, decisions[0]);
   results[1] = OFPR01_Replay(contract, profile, contexts, bars, quote, envelope, decisions[1]);
   results[2] = OFPR02_Replay(contract, profile, contexts, bars, quote, envelope, decisions[2]);
   results[3] = OFPC00_Replay(contract, profile, contexts, bars, quote, envelope, decisions[3]);
   results[4] = OFPC01_Replay(contract, profile, contexts, bars, quote, envelope, decisions[4]);
   results[5] = OFPC02_Replay(contract, profile, contexts, bars, quote, envelope, decisions[5]);

   double mids[] = {100.0, 101.0, 100.0};
   long up_count = 0;
   long down_count = 0;
   long unchanged_count = 0;
   double ratio = 0.0;
   bool moves_counted = OFP_CountQuoteMoves(mids, up_count, down_count,
                                             unchanged_count, ratio);
   string bar_proxy_reason = "";
   bool bar_proxy_built = OFP_BuildBarQuoteProxy(ticks, bars[20],
                                                  bar_proxy_reason);
   int true_count = 0;
   for(int i = 0; i < ArraySize(results); ++i)
      true_count += results[i] ? 1 : 0;
   PrintFormat("COMPILE_ONLY profile=%s variants_true=%d moves=%s bar_proxy=%s reason=%s/%s",
               profile_built ? "true" : "false", true_count,
               moves_counted ? "true" : "false",
               bar_proxy_built ? "true" : "false",
               profile_reason, bar_proxy_reason);
}
