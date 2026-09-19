#property strict
#property script_show_inputs

#include "../components/orderflow/OrderFlowComponents.mqh"

int g_passed = 0;
int g_failed = 0;

void AssertTrue(const bool condition, const string name)
{
   if(condition)
   {
      ++g_passed;
      Print("PASS ", name);
   }
   else
   {
      ++g_failed;
      Print("FAIL ", name);
   }
}

void AssertNear(const double expected, const double actual, const string name)
{
   AssertTrue(MathAbs(expected - actual) <= 1.0e-8, name);
}

void BuildContract(OFDataContract &contract, OFFreshnessPolicy &policy)
{
   contract.dataset_id                    = "fixture-orderflow-positive-v1";
   contract.source_id                     = "fixture-exchange-feed";
   contract.source_revision               = "fixture-r1";
   contract.signal_instrument_id           = "FIXTURE.INSTRUMENT";
   contract.profile_instrument_id          = "FIXTURE.INSTRUMENT";
   contract.instrument_mapping_id          = "";
   contract.instrument_mapping_qualified   = false;
   contract.execution_source_id            = "fixture-broker-quote-feed";
   contract.execution_source_revision      = "fixture-quote-r1";
   contract.execution_instrument_id        = "FIXTURE.INSTRUMENT";
   contract.signal_price_unit_id           = "FIXTURE.PRICE";
   contract.execution_price_unit_id        = "FIXTURE.PRICE";
   contract.cost_price_unit_id             = "FIXTURE.PRICE";
   contract.execution_mapping_id           = "";
   contract.execution_mapping_qualified    = false;
   contract.execution_normalization_id     = "";
   contract.execution_normalization_qualified = false;
   contract.session_definition_id          = "fixture-session-v1";
   contract.timezone_ruleset_id            = "fixture-utc-v1";
   contract.profile_algorithm_id           = "fixture-profile-v1";
   contract.value_area_algorithm_id        = "fixture-va-v1";
   contract.volume_provenance_id           = "fixture-executed-sides-v1";
   contract.source_qualified               = false;
   contract.data_identity                  = OF_DATA_IDENTITY_TRUE_ORDERFLOW;
   contract.volume_provenance              = OF_VOLUME_EXECUTED_ASK_BID;
   contract.record_class                   = OF_RECORD_CLASS_FIXTURE;

   policy.max_m5_age_seconds      = 3600;
   policy.max_m15_age_seconds     = 7200;
   policy.max_profile_age_seconds = 86400;
   policy.max_quote_age_seconds   = 60;
   policy.required_record_class   = OF_RECORD_CLASS_FIXTURE;
}

void BuildProfile(OFProfile &profile)
{
   profile.record_id        = "profile-1";
   profile.profile_id       = "prior-session-profile";
   profile.profile_revision = "profile-r1";
   profile.source_revision  = "fixture-r1";
   profile.session_start    = (datetime)1699980000;
   profile.session_end      = (datetime)1699992000;
   profile.available_at     = (datetime)1699992100;
   profile.completed        = true;
   profile.val              = 100.0;
   profile.poc              = 106.0;
   profile.vah              = 112.0;
}

void SetContext(OFContextBar &context,
                const string id,
                const ulong sequence,
                const double open,
                const double high,
                const double low,
                const double close)
{
   context.record_id       = id;
   context.source_revision = "fixture-r1";
   context.sequence        = sequence;
   context.period_seconds  = 900;
   context.open_time       = (datetime)1699998500;
   context.close_time      = (datetime)1699999400;
   context.available_at    = (datetime)1699999410;
   context.completed       = true;
   context.open            = open;
   context.high            = high;
   context.low             = low;
   context.close           = close;
}

void SetBar(OFBar &bar,
            const string id,
            const ulong sequence,
            const datetime open_time,
            const double open,
            const double high,
            const double low,
            const double close,
            const double ask_volume,
            const double bid_volume)
{
   bar.record_id             = id;
   bar.source_revision       = "fixture-r1";
   bar.sequence              = sequence;
   bar.period_seconds        = 300;
   bar.open_time             = open_time;
   bar.close_time            = open_time + 300;
   bar.available_at          = open_time + 301;
   bar.completed             = true;
   bar.open                  = open;
   bar.high                  = high;
   bar.low                   = low;
   bar.close                 = close;
   bar.executed_ask_volume   = ask_volume;
   bar.executed_bid_volume   = bid_volume;
   bar.total_executed_volume = ask_volume + bid_volume;
}

void BuildHistory(OFBar &bars[], const int event_count, const string prefix)
{
   ArrayResize(bars, 20 + event_count);
   datetime start = (datetime)1699994000;
   for(int i = 0; i < 20; ++i)
   {
      SetBar(bars[i], prefix + "-history-" + IntegerToString(i + 1),
             (ulong)(i + 1), start + i * 300,
             106.0, 106.5, 105.5, 106.0, 50.0, 50.0);
   }
}

void BuildQuote(OFQuote &quote, const string id, const OFBar &last_bar,
                const double bid, const double ask, const double cost)
{
   quote.record_id         = id;
   quote.execution_source_id       = "fixture-broker-quote-feed";
   quote.execution_source_revision = "fixture-quote-r1";
   quote.instrument_id             = "FIXTURE.INSTRUMENT";
   quote.price_unit_id             = "FIXTURE.PRICE";
   quote.cost_price_unit_id        = "FIXTURE.PRICE";
   quote.observed_at       = last_bar.close_time + 1;
   quote.available_at      = last_bar.close_time + 2;
   quote.bid               = bid;
   quote.ask               = ask;
   quote.all_in_cost_price = cost;
}

void BuildEnvelope(OFDecisionEnvelope &envelope,
                   const OFBar &last_bar,
                   const datetime evaluation_time)
{
   envelope.evaluation_time             = evaluation_time;
   envelope.current_closed_bar_record_id = last_bar.record_id;
   envelope.current_closed_bar_close_time = last_bar.close_time;
}

void TestValidationRefusals()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   BuildContract(contract, policy);
   string reason = "";
   AssertTrue(OF_ValidateContract(contract, policy, reason), "contract fixture accepted explicitly");

   contract.data_identity = OF_DATA_IDENTITY_PRICE_ACTION_PROXY;
   reason = "";
   AssertTrue(!OF_ValidateContract(contract, policy, reason) &&
              reason == "PROXY_NOT_TRUE_ORDERFLOW", "proxy rejected as true orderflow");

   BuildContract(contract, policy);
   contract.volume_provenance = OF_VOLUME_TICK_COUNT_PROXY;
   reason = "";
   AssertTrue(!OF_ValidateContract(contract, policy, reason) &&
              reason == "EXECUTED_ASK_BID_REQUIRED", "tick count rejected as executed sides");

   BuildContract(contract, policy);
   contract.profile_instrument_id = "OTHER.INSTRUMENT";
   reason = "";
   AssertTrue(!OF_ValidateContract(contract, policy, reason) &&
              reason == "UNQUALIFIED_INSTRUMENT_MAPPING", "unqualified mapping rejected");

   BuildContract(contract, policy);
   contract.execution_instrument_id = "OTHER.INSTRUMENT";
   reason = "";
   AssertTrue(!OF_ValidateContract(contract, policy, reason) &&
              reason == "UNQUALIFIED_EXECUTION_MAPPING",
              "cross-instrument quote rejected without mapping and normalization");

   contract.execution_mapping_id = "fixture-execution-map-v1";
   contract.execution_mapping_qualified = true;
   contract.execution_normalization_id = "fixture-normalization-v1";
   contract.execution_normalization_qualified = true;
   reason = "";
   AssertTrue(OF_ValidateContract(contract, policy, reason),
              "explicit qualified cross-instrument mapping accepted");

   BuildContract(contract, policy);
   contract.cost_price_unit_id = "OTHER.UNIT";
   reason = "";
   AssertTrue(!OF_ValidateContract(contract, policy, reason) &&
              reason == "INCONSISTENT_PRICE_COST_UNITS",
              "inconsistent price and cost units rejected");

   BuildContract(contract, policy);
   policy.max_m5_age_seconds = 0;
   reason = "";
   AssertTrue(!OF_ValidateContract(contract, policy, reason) &&
              reason == "MISSING_EXPLICIT_FRESHNESS_POLICY",
              "non-positive typed freshness rejected");
}

void TestOF01Long()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);
   SetContext(context, "m15-of01-long", 1, 105.0, 106.0, 104.0, 105.0);
   OFBar bars[];
   BuildHistory(bars, 2, "OF01_LONG");
   SetBar(bars[20], "OF01_LONG-event-1", 21, (datetime)1700000000,
          100.4, 101.0, 99.5, 100.3, 70.0, 130.0);
   SetBar(bars[21], "OF01_LONG-event-2", 22, (datetime)1700000300,
          100.4, 101.8, 100.1, 101.5, 60.0, 50.0);
   OFQuote quote;
   BuildQuote(quote, "q-of01-long", bars[21], 101.5, 101.6, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[21], quote.available_at);
   OFDecision result;
   bool signalled = OF01_Replay(contract, policy, profile, context, bars,
                                quote, envelope, result);
   AssertTrue(signalled && result.decision == OF_DECISION_SIGNAL, "OF01 long signal");
   AssertTrue(result.geometry.direction == OF_DIRECTION_LONG, "OF01 long direction");
   AssertNear(99.3, result.geometry.stop_price, "OF01 long structural stop");
   AssertNear(106.0, result.geometry.target_price, "OF01 long frozen POC target");
   AssertTrue(result.geometry.net_rr >= 1.5, "OF01 long net RR gate");
   AssertTrue(result.geometry.prospective_quote_not_fill, "OF01 quote is not fill");
   OFTemplateSeamProposal seam;
   AssertTrue(OF_BuildTemplateSeamProposal(result, seam), "Template seam carries component signal");
   AssertTrue(!seam.current_entry_signal_compatible &&
              !seam.order_execution_authorized &&
              seam.binding_status == "TEMPLATE_EXIT_BINDING_REQUIRED",
              "Template seam blocks lossy current EntrySignal binding");
   AssertTrue(seam.geometry.confirmation_window_completed_m5_bars == 3,
              "Template seam preserves completed-bar expiry without wall-clock assumption");
}

void TestOF01ShortAndRR()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);
   SetContext(context, "m15-of01-short", 2, 107.0, 108.0, 106.0, 107.0);
   OFBar bars[];
   BuildHistory(bars, 2, "OF01_SHORT");
   SetBar(bars[20], "OF01_SHORT-event-1", 21, (datetime)1700000000,
          111.6, 112.5, 111.0, 111.7, 130.0, 70.0);
   SetBar(bars[21], "OF01_SHORT-event-2", 22, (datetime)1700000300,
          111.6, 111.8, 110.2, 110.5, 50.0, 60.0);
   OFQuote quote;
   BuildQuote(quote, "q-of01-short", bars[21], 110.4, 110.5, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[21], quote.available_at);
   OFDecision result;
   AssertTrue(OF01_Replay(contract, policy, profile, context, bars,
                          quote, envelope, result), "OF01 short signal");
   AssertTrue(result.geometry.direction == OF_DIRECTION_SHORT, "OF01 short direction");
   AssertNear(112.7, result.geometry.stop_price, "OF01 short structural stop");

   quote.bid = 107.0;
   quote.ask = 107.1;
   bool signalled = OF01_Replay(contract, policy, profile, context, bars,
                                quote, envelope, result);
   AssertTrue(!signalled && result.decision == OF_DECISION_REJECTED,
              "OF01 prospective quote RR rejection");
}

void TestOF02Long()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);
   SetContext(context, "m15-of02-long", 3, 111.0, 113.0, 110.5, 112.4);
   OFBar bars[];
   BuildHistory(bars, 4, "OF02_LONG");
   SetBar(bars[20], "OF02_LONG-event-1", 21, (datetime)1700000000,
          112.1, 112.6, 112.0, 112.4, 55.0, 45.0);
   SetBar(bars[21], "OF02_LONG-event-2", 22, (datetime)1700000300,
          112.3, 112.8, 112.2, 112.6, 120.0, 60.0);
   SetBar(bars[22], "OF02_LONG-event-3", 23, (datetime)1700000600,
          112.4, 112.5, 111.9, 112.2, 55.0, 55.0);
   SetBar(bars[23], "OF02_LONG-event-4", 24, (datetime)1700000900,
          112.2, 112.9, 112.1, 112.7, 70.0, 50.0);
   OFQuote quote;
   BuildQuote(quote, "q-of02-long", bars[23], 112.7, 112.8, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[23], quote.available_at);
   OFDecision result;
   AssertTrue(OF02_Replay(contract, policy, profile, context, bars,
                          quote, envelope, result), "OF02 long signal");
   AssertTrue(result.geometry.direction == OF_DIRECTION_LONG, "OF02 long direction");
   AssertNear(111.7, result.geometry.stop_price, "OF02 long structural stop");
   AssertNear(115.0, result.geometry.target_price, "OF02 long prospective 2R target");
   AssertTrue(result.geometry.retest_window_completed_m5_bars == 6 &&
              result.geometry.confirmation_window_completed_m5_bars == 3 &&
              result.geometry.consumer_time_exit_m5_bars_after_fill == 12,
              "OF02 preserves bar windows and consumer-owned fill-relative time exit");
}

void TestOF02Short()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);
   SetContext(context, "m15-of02-short", 4, 101.0, 101.5, 99.0, 99.6);
   OFBar bars[];
   BuildHistory(bars, 4, "OF02_SHORT");
   SetBar(bars[20], "OF02_SHORT-event-1", 21, (datetime)1700000000,
          99.9, 100.0, 99.4, 99.6, 45.0, 55.0);
   SetBar(bars[21], "OF02_SHORT-event-2", 22, (datetime)1700000300,
          99.7, 99.8, 99.2, 99.4, 60.0, 120.0);
   SetBar(bars[22], "OF02_SHORT-event-3", 23, (datetime)1700000600,
          99.6, 100.1, 99.5, 99.8, 55.0, 55.0);
   SetBar(bars[23], "OF02_SHORT-event-4", 24, (datetime)1700000900,
          99.8, 99.9, 99.1, 99.3, 50.0, 70.0);
   OFQuote quote;
   BuildQuote(quote, "q-of02-short", bars[23], 99.2, 99.3, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[23], quote.available_at);
   OFDecision result;
   AssertTrue(OF02_Replay(contract, policy, profile, context, bars,
                          quote, envelope, result), "OF02 short signal");
   AssertTrue(result.geometry.direction == OF_DIRECTION_SHORT, "OF02 short direction");
   AssertNear(100.3, result.geometry.stop_price, "OF02 short structural stop");
   AssertNear(97.0, result.geometry.target_price, "OF02 short prospective 2R target");
}

void TestRevisionReset()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);
   SetContext(context, "m15-reset", 5, 105.0, 106.0, 104.0, 105.0);
   OFBar bars[];
   BuildHistory(bars, 2, "RESET");
   SetBar(bars[20], "RESET-event-1", 21, (datetime)1700000000,
          100.4, 101.0, 99.5, 100.3, 70.0, 130.0);
   SetBar(bars[21], "RESET-event-2", 22, (datetime)1700000300,
          100.4, 101.8, 100.1, 101.5, 60.0, 50.0);
   OFQuote quote;
   BuildQuote(quote, "q-reset", bars[21], 101.5, 101.6, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[21], quote.available_at);
   OFState state;
   OF_ResetState(state);
   OFDecision result;
   OF01_ProcessBar(contract, policy, profile, context, bars, 20,
                   quote, envelope, state, result);
   AssertTrue(result.decision == OF_DECISION_ARMED, "OF01 armed before revision reset");
   profile.profile_revision = "profile-r2";
   OF01_ProcessBar(contract, policy, profile, context, bars, 21,
                   quote, envelope, state, result);
   AssertTrue(result.decision == OF_DECISION_CANCELLED &&
              result.code == "OF01_REVISION_OR_CONTEXT_RESET",
              "profile revision cancels armed state");
}

void TestOF01ZoneOverlapWithoutCenterTouch()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);

   OFBar long_bars[];
   BuildHistory(long_bars, 2, "OF01_ZONE_LONG");
   SetContext(context, "m15-zone-long", 10, 105.0, 106.0, 104.0, 105.0);
   SetBar(long_bars[20], "zone-long-setup", 21, (datetime)1700000000,
          100.5, 100.6, 100.1, 100.35, 70.0, 130.0);
   SetBar(long_bars[21], "zone-long-trigger", 22, (datetime)1700000300,
          100.4, 101.8, 100.1, 101.5, 60.0, 50.0);
   OFQuote quote;
   BuildQuote(quote, "q-zone-long", long_bars[21], 101.5, 101.6, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, long_bars[21], quote.available_at);
   OFDecision result;
   AssertTrue(OF01_Replay(contract, policy, profile, context, long_bars,
                          quote, envelope, result),
              "OF01 long zone overlap does not require VAL center touch");

   OFBar short_bars[];
   BuildHistory(short_bars, 2, "OF01_ZONE_SHORT");
   SetContext(context, "m15-zone-short", 11, 107.0, 108.0, 106.0, 107.0);
   SetBar(short_bars[20], "zone-short-setup", 21, (datetime)1700000000,
          111.5, 111.9, 111.4, 111.65, 130.0, 70.0);
   SetBar(short_bars[21], "zone-short-trigger", 22, (datetime)1700000300,
          111.6, 111.8, 110.2, 110.5, 50.0, 60.0);
   BuildQuote(quote, "q-zone-short", short_bars[21], 110.4, 110.5, 0.05);
   BuildEnvelope(envelope, short_bars[21], quote.available_at);
   AssertTrue(OF01_Replay(contract, policy, profile, context, short_bars,
                          quote, envelope, result),
              "OF01 short zone overlap does not require VAH center touch");

   long_bars[20].low = 100.3;
   long_bars[20].open = 100.7;
   long_bars[20].high = 100.8;
   long_bars[20].close = 100.55;
   BuildQuote(quote, "q-zone-outside", long_bars[21], 101.5, 101.6, 0.05);
   BuildEnvelope(envelope, long_bars[21], quote.available_at);
   AssertTrue(!OF01_Replay(contract, policy, profile, context, long_bars,
                           quote, envelope, result) &&
              result.decision == OF_DECISION_NONE,
              "OF01 bar outside frozen zone remains negative");
}

void TestChronologicalAvailabilityAndProgression()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   BuildContract(contract, policy);
   BuildProfile(profile);
   OFBar bars[];
   BuildHistory(bars, 2, "CHRONOLOGY");
   SetBar(bars[20], "chronology-setup", 21, (datetime)1700000000,
          100.4, 101.0, 99.5, 100.3, 70.0, 130.0);
   SetBar(bars[21], "chronology-trigger", 22, (datetime)1700000300,
          100.4, 101.8, 100.1, 101.5, 60.0, 50.0);
   OFQuote quote;
   BuildQuote(quote, "q-chronology", bars[21], 101.5, 101.6, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[21], quote.available_at);
   OFDecision result;

   OFContextBar late_context;
   SetContext(late_context, "m15-late", 20, 105.0, 106.0, 104.0, 105.0);
   late_context.available_at = bars[20].available_at + 1;
   AssertTrue(!OF01_Replay(contract, policy, profile, late_context, bars,
                           quote, envelope, result) &&
              result.decision == OF_DECISION_NONE,
              "late M15 context cannot create earlier OF01 setup");

   OFProfile late_profile = profile;
   late_profile.available_at = bars[20].available_at + 1;
   OFContextBar setup_context;
   SetContext(setup_context, "m15-setup", 21, 105.0, 106.0, 104.0, 105.0);
   setup_context.available_at = bars[20].available_at - 1;
   AssertTrue(!OF01_Replay(contract, policy, late_profile, setup_context, bars,
                           quote, envelope, result) &&
              result.decision == OF_DECISION_NONE,
              "late profile cannot create earlier OF01 setup");

   OFContextBar contexts[];
   ArrayResize(contexts, 2);
   contexts[0] = setup_context;
   contexts[1] = setup_context;
   contexts[1].record_id = "m15-next-completed";
   contexts[1].sequence = setup_context.sequence + 1;
   contexts[1].open_time = setup_context.open_time + 900;
   contexts[1].close_time = setup_context.close_time + 900;
   contexts[1].available_at = bars[21].available_at - 1;
   AssertTrue(OF01_ReplayChronological(contract, policy, profile, contexts, bars,
                                       quote, envelope, result) &&
              result.geometry.setup_context_record_id == "m15-setup",
              "ordinary completed M15 progression preserves armed setup provenance");

   OFBar continuation[];
   BuildHistory(continuation, 4, "CHRONOLOGY_OF02");
   SetBar(continuation[20], "chronology-of02-first", 21, (datetime)1700000000,
          112.1, 112.6, 112.0, 112.4, 55.0, 45.0);
   SetBar(continuation[21], "chronology-of02-second", 22, (datetime)1700000300,
          112.3, 112.8, 112.2, 112.6, 120.0, 60.0);
   SetBar(continuation[22], "chronology-of02-retest", 23, (datetime)1700000600,
          112.4, 112.5, 111.9, 112.2, 55.0, 55.0);
   SetBar(continuation[23], "chronology-of02-confirm", 24, (datetime)1700000900,
          112.2, 112.9, 112.1, 112.7, 70.0, 50.0);
   SetContext(contexts[0], "m15-of02-setup", 40, 111.0, 113.0, 110.5, 112.4);
   contexts[0].available_at = continuation[20].available_at - 1;
   contexts[1] = contexts[0];
   contexts[1].record_id = "m15-of02-next-completed";
   contexts[1].sequence = contexts[0].sequence + 1;
   contexts[1].open_time = contexts[0].open_time + 900;
   contexts[1].close_time = contexts[0].close_time + 900;
   contexts[1].available_at = continuation[22].available_at - 1;
   BuildQuote(quote, "q-chronology-of02", continuation[23], 112.7, 112.8, 0.05);
   BuildEnvelope(envelope, continuation[23], quote.available_at);
   AssertTrue(OF02_ReplayChronological(contract, policy, profile, contexts,
                                       continuation, quote, envelope, result) &&
              result.geometry.setup_context_record_id == "m15-of02-setup",
              "OF02 ordinary M15 progression preserves armed setup provenance");
}

void TestQuoteExecutionAndDecisionEnvelope()
{
   OFDataContract contract;
   OFFreshnessPolicy policy;
   OFProfile profile;
   OFContextBar context;
   BuildContract(contract, policy);
   BuildProfile(profile);
   SetContext(context, "m15-quote", 30, 105.0, 106.0, 104.0, 105.0);
   OFBar bars[];
   BuildHistory(bars, 2, "QUOTE");
   SetBar(bars[20], "quote-setup", 21, (datetime)1700000000,
          100.4, 101.0, 99.5, 100.3, 70.0, 130.0);
   SetBar(bars[21], "quote-trigger", 22, (datetime)1700000300,
          100.4, 101.8, 100.1, 101.5, 60.0, 50.0);
   OFQuote quote;
   BuildQuote(quote, "q-envelope", bars[21], 101.5, 101.6, 0.05);
   OFDecisionEnvelope envelope;
   BuildEnvelope(envelope, bars[21], quote.available_at);
   OFDecision result;
   AssertTrue(OF01_Replay(contract, policy, profile, context, bars,
                          quote, envelope, result),
              "post-confirmation quote inside current-bar envelope accepted");

   quote.instrument_id = "OTHER.INSTRUMENT";
   AssertTrue(!OF01_Replay(contract, policy, profile, context, bars,
                           quote, envelope, result) &&
              result.code == "QUOTE_EXECUTION_PIN_MISMATCH",
              "contradictory quote instrument rejected");

   BuildQuote(quote, "q-unit", bars[21], 101.5, 101.6, 0.05);
   quote.cost_price_unit_id = "OTHER.UNIT";
   AssertTrue(!OF01_Replay(contract, policy, profile, context, bars,
                           quote, envelope, result) &&
              result.code == "QUOTE_PRICE_COST_UNIT_MISMATCH",
              "quote cost unit mismatch rejected");

   int delays[2] = {300, 301};
   for(int i = 0; i < 2; ++i)
   {
      BuildQuote(quote, "q-late-" + IntegerToString(delays[i]),
                 bars[21], 101.5, 101.6, 0.05);
      quote.observed_at = bars[21].close_time + delays[i];
      quote.available_at = quote.observed_at + 1;
      BuildEnvelope(envelope, bars[21], quote.available_at);
      AssertTrue(!OF01_Replay(contract, policy, profile, context, bars,
                              quote, envelope, result) &&
                 result.code == "DECISION_WINDOW_MISSING_CLOSED_BAR",
                 "late quote with omitted closed M5 history rejected " +
                 IntegerToString(delays[i]));
   }
}

void OnStart()
{
   TestValidationRefusals();
   TestOF01Long();
   TestOF01ShortAndRR();
   TestOF02Long();
   TestOF02Short();
   TestRevisionReset();
   TestOF01ZoneOverlapWithoutCenterTouch();
   TestChronologicalAvailabilityAndProgression();
   TestQuoteExecutionAndDecisionEnvelope();
   PrintFormat("ORDERFLOW_COMPONENTS_TEST_SUMMARY passed=%d failed=%d", g_passed, g_failed);
   if(g_failed > 0)
      Print("ORDERFLOW_COMPONENTS_TEST_FAILURE");
}
