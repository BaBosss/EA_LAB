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
   quote.source_id         = "fixture-exchange-feed";
   quote.source_revision   = "fixture-r1";
   quote.observed_at       = last_bar.close_time;
   quote.available_at      = last_bar.close_time + 1;
   quote.bid               = bid;
   quote.ask               = ask;
   quote.all_in_cost_price = cost;
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
   OFDecision result;
   bool signalled = OF01_Replay(contract, policy, profile, context, bars,
                                quote, quote.available_at, result);
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
   OFDecision result;
   AssertTrue(OF01_Replay(contract, policy, profile, context, bars,
                          quote, quote.available_at, result), "OF01 short signal");
   AssertTrue(result.geometry.direction == OF_DIRECTION_SHORT, "OF01 short direction");
   AssertNear(112.7, result.geometry.stop_price, "OF01 short structural stop");

   quote.bid = 107.0;
   quote.ask = 107.1;
   bool signalled = OF01_Replay(contract, policy, profile, context, bars,
                                quote, quote.available_at, result);
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
   OFDecision result;
   AssertTrue(OF02_Replay(contract, policy, profile, context, bars,
                          quote, quote.available_at, result), "OF02 long signal");
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
   OFDecision result;
   AssertTrue(OF02_Replay(contract, policy, profile, context, bars,
                          quote, quote.available_at, result), "OF02 short signal");
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
   OFState state;
   OF_ResetState(state);
   OFDecision result;
   OF01_ProcessBar(contract, policy, profile, context, bars, 20,
                   quote, quote.available_at, state, result);
   AssertTrue(result.decision == OF_DECISION_ARMED, "OF01 armed before revision reset");
   profile.profile_revision = "profile-r2";
   OF01_ProcessBar(contract, policy, profile, context, bars, 21,
                   quote, quote.available_at, state, result);
   AssertTrue(result.decision == OF_DECISION_CANCELLED &&
              result.code == "OF01_REVISION_OR_CONTEXT_RESET",
              "profile revision cancels armed state");
}

void OnStart()
{
   TestValidationRefusals();
   TestOF01Long();
   TestOF01ShortAndRR();
   TestOF02Long();
   TestOF02Short();
   TestRevisionReset();
   PrintFormat("ORDERFLOW_COMPONENTS_TEST_SUMMARY passed=%d failed=%d", g_passed, g_failed);
   if(g_failed > 0)
      Print("ORDERFLOW_COMPONENTS_TEST_FAILURE");
}
