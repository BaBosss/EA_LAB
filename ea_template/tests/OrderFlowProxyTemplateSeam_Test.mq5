//+------------------------------------------------------------------+
//| OrderFlowProxyTemplateSeam_Test.mq5                              |
//| Compile-only harness. Do not execute or attach under this order. |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "../components/orderflow_proxy/provider/OrderFlowProxyTemplateSeam.mqh"

void SetExactReceipt(OFPProviderIntervalReceipt &receipt,
                     const string kind,
                     const int ordinal,
                     const string role,
                     const long start_msc,
                     const long end_msc,
                     const long count,
                     const long first_time_msc,
                     const long last_time_msc,
                     const string quote_stream_sha256)
{
   receipt.kind = kind;
   receipt.ordinal = ordinal;
   receipt.role = role;
   receipt.interval_start_msc = start_msc;
   receipt.interval_end_msc = end_msc;
   receipt.pass1_count = count;
   receipt.pass2_count = count;
   receipt.pass1_first_time_msc = first_time_msc;
   receipt.pass2_first_time_msc = first_time_msc;
   receipt.pass1_last_time_msc = last_time_msc;
   receipt.pass2_last_time_msc = last_time_msc;
   receipt.pass1_valid_bid_ask_count = count;
   receipt.pass2_valid_bid_ask_count = count;
   receipt.pass1_quote_stream_sha256 = quote_stream_sha256;
   receipt.pass2_quote_stream_sha256 = quote_stream_sha256;
   receipt.pass1_api_success = true;
   receipt.pass2_api_success = true;
   receipt.repeat_identity = true;
   receipt.rate_snapshot_stable = true;
}

void BuildExactEurUsdReceipts(OFPProviderIntervalReceipt &receipts[])
{
   const long counts[22] =
   {
      48715,120,101,108,162,154,141,121,115,137,123,
      205,141,127,144,83,50,43,42,96,107,183
   };
   const long first_times[22] =
   {
      1789603201013,1789769100121,1789769400631,1789769700511,
      1789770000543,1789770301305,1789770600747,1789770900711,
      1789771200492,1789771500087,1789771800072,1789772100064,
      1789772400051,1789772700077,1789773003492,1789773300155,
      1789773600923,1789773900100,1789774200089,1789774501818,
      1789774803320,1789775100043
   };
   const long last_times[22] =
   {
      1789689598082,1789769397789,1789769694254,1789769998963,
      1789770298931,1789770595754,1789770898073,1789771190475,
      1789771486227,1789771798296,1789772090652,1789772398932,
      1789772698765,1789772984027,1789773294671,1789773595847,
      1789773897304,1789774186860,1789774496030,1789774795773,
      1789775098159,1789775398086
   };
   const string hashes[22] =
   {
      "f157f896590fd2f7ede3662509f95bfbe8a18c6a359c42054f19eb07c7c6bf1c",
      "2829188b786ea2459cc184691e48e3884ff2addcf91f0e6bfe86b118c35f6de5",
      "44c17c4730c572db8915c5f4bf69e8f408ba6d663419271c11f7af53ff934b6b",
      "3867d5abf97f450457b5ed6b6e8728b8a318930d76bc8bdb2ff1d3cf79c11568",
      "2d9100ea55cc83ad7472af06d896dab7cecdeca3d0e9e931c44c529b92896645",
      "8f461bc0ad0281495c0e5b76d27abff7e34f7d2f8d4844194ea16f3f091f43aa",
      "cee3243a5564e94753ce63ca3a04d8efec42a147b05f27b2ae458273de2f4880",
      "04310d23bf956cddb5071e1ad7b4db55624f5dc2de4adac28a9afa371fb9e457",
      "f3ca6eef5af8b267b8019eafe4df82006f9885102d05fd5de435e6f808ccd64c",
      "fe9b88f039313f62d0794c8fd2da239818f309c6b75a9d940911be41df027d28",
      "fcf0ff7da049c1a93ad05ea05c6a4956f03582dd47982365df0290d8abd458eb",
      "9a3d808059921c11ede40de1962bd4d452770627e2580e8457ecb05dc0300586",
      "b85d453d71b9db1ef489dd14b5d4a5863ce49f5fb9b493b1e991ec9522cd954f",
      "5f77f4eac116a9891ef98d019e41d5c879de2a3811d69c5e12f3343fdd9f8ef3",
      "59260538ae2f4e8f2b37579e6557abc8003787b494d4231f2fea653f735e69cf",
      "e487347a9b150730ae614bfc183047c45fcfd5394ffc236573a6f2855ded92d6",
      "408dc35eadb746fe66a8782dca3f582b3d440c930e830fd569197b287a3bacfe",
      "6d87763b86c5d500a9b0ce527d516897d8a71bc53dfa5bbc0134c6829ca4dd4a",
      "060411915d82aa0f598f8d3784947fa6db16d9c34fb2064531dc792a8e6b8458",
      "e56aee2473ae92785914fbc62574234934ca0edf19d27d71fd7d7bfb1915bf27",
      "d2485e3c5709cd293220bcee98cea0a158e194d1320155463e73159a1a317e4c",
      "c0334f23a84811ff53b6b696b9cb4becb2dbde30caf26fc6fd55ff7ce1bd0394"
   };

   ArrayResize(receipts, OFP_PROVIDER_REQUIRED_INTERVALS);
   SetExactReceipt(receipts[0], "D1_PROFILE", 0, "PROFILE",
                   1789603200000, 1789689600000,
                   counts[0], first_times[0], last_times[0], hashes[0]);
   const long first_m5 = 1789769100000;
   for(int i = 0; i < 21; ++i)
      SetExactReceipt(receipts[i+1], "M5", i,
                      i == 20 ? "CANDIDATE" : "WARMUP",
                      first_m5 + (long)i * 300000,
                      first_m5 + (long)(i+1) * 300000,
                      counts[i+1], first_times[i+1], last_times[i+1],
                      hashes[i+1]);
}

void OnStart()
{
   OFPThinkMarketsA2Evidence evidence;
   evidence.policy_id = OFP_PROVIDER_POLICY_THINKMARKETS_A2_V1;
   evidence.classification = OFP_PROVIDER_CLASS_CURRENT_WINDOW;
   evidence.provider_server = OFP_PROVIDER_SERVER_THINKMARKETS_LIVE;
   evidence.terminal_build = OFP_PROVIDER_TERMINAL_BUILD;
   evidence.logical_symbol = "EURUSD";
   evidence.broker_symbol = "EURUSD";
   evidence.reviewed_repo_head = OFP_PROVIDER_REVIEWED_REPO_HEAD;
   evidence.evidence_manifest_sha256 = OFP_PROVIDER_EVIDENCE_MANIFEST_SHA256;
   evidence.bundle_sha256 =
      "776df940030826e6dc60389c0b2fe731999d66b8853a8651231947f73d1de75c";
   evidence.profile_interval_start = 1789603200;
   evidence.profile_interval_end = 1789689600;
   evidence.candidate_m5_open = 1789775100;
   evidence.true_orderflow = false;
   evidence.executed_volume_delta_qualified = false;

   OFPProviderIntervalReceipt receipts[];
   BuildExactEurUsdReceipts(receipts);

   OFPDecision decision;
   OFP_SetDecision(decision, OFP_DECISION_SIGNAL,
                   OFPC_02_QUOTE_IMBALANCE,
                   "OFPC_PROXY_GEOMETRY_READY", "compile-only");
   decision.geometry.direction = OFP_DIRECTION_LONG;
   decision.geometry.prospective_entry = 1.1000;
   decision.geometry.stop_price = 1.0900;
   decision.geometry.target_price = 1.1200;
   decision.geometry.gross_risk = 0.0100;
   decision.geometry.net_risk = 0.0102;
   decision.geometry.net_reward = 0.0198;
   decision.geometry.net_rr = 1.941176470588;
   decision.geometry.setup_time = evidence.candidate_m5_open - 900;
   decision.geometry.trigger_time = evidence.candidate_m5_open + 300;
   decision.geometry.retest_window_completed_m5_bars = 6;
   decision.geometry.confirmation_window_completed_m5_bars = 3;
   decision.geometry.consumer_time_exit_m5_bars_after_fill = 12;
   decision.geometry.prospective_quote_not_fill = true;
   decision.geometry.fill_simulated = false;

   OFPTemplateSeamResult result;
   bool ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, result);

   // Compile-only mutation calls.  Each changes one caller-owned field from
   // the reviewed EURUSD bundle and must be refused by the native binding.
   receipts[1].pass1_count++;
   OFPTemplateSeamResult count_mutation;
   bool count_ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, count_mutation);
   receipts[1].pass1_count--;

   receipts[1].pass1_first_time_msc++;
   OFPTemplateSeamResult timestamp_mutation;
   bool timestamp_ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, timestamp_mutation);
   receipts[1].pass1_first_time_msc--;

   string exact_quote_hash = receipts[1].pass1_quote_stream_sha256;
   receipts[1].pass1_quote_stream_sha256 =
      "0829188b786ea2459cc184691e48e3884ff2addcf91f0e6bfe86b118c35f6de5";
   OFPTemplateSeamResult quote_hash_mutation;
   bool quote_hash_ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, quote_hash_mutation);
   receipts[1].pass1_quote_stream_sha256 = exact_quote_hash;

   receipts[1].rate_snapshot_stable = false;
   OFPTemplateSeamResult snapshot_mutation;
   bool snapshot_ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, snapshot_mutation);
   receipts[1].rate_snapshot_stable = true;

   string exact_bundle_sha256 = evidence.bundle_sha256;
   evidence.bundle_sha256 =
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   OFPTemplateSeamResult bundle_mutation;
   bool bundle_ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, bundle_mutation);
   evidence.bundle_sha256 = exact_bundle_sha256;

   // Compile-time shape checks for fail-closed authority and full geometry.
   bool geometry_preserved =
      result.decision.geometry.stop_price == decision.geometry.stop_price &&
      result.geometry.target_price == decision.geometry.target_price &&
      result.provider_identity.evidence_manifest_sha256 == evidence.evidence_manifest_sha256;
   bool authority_closed =
      !result.current_entry_signal_compatible &&
      !result.order_execution_authorized &&
      result.time_exit_consumer_owned;

   evidence.logical_symbol = "BTCUSD";
   evidence.broker_symbol = "BTCUSD";
   OFPTemplateSeamResult blocked;
   bool btc_ready = OFP_BuildTemplateSeamResult(decision, evidence, receipts, blocked);
   PrintFormat("COMPILE_ONLY ready=%s preserved=%s authority=%s mutations=%s/%s/%s/%s/%s btc=%s status=%s/%s",
               ready ? "true" : "false",
               geometry_preserved ? "true" : "false",
               authority_closed ? "true" : "false",
               count_ready ? "true" : "false",
               timestamp_ready ? "true" : "false",
               quote_hash_ready ? "true" : "false",
               snapshot_ready ? "true" : "false",
               bundle_ready ? "true" : "false",
               btc_ready ? "true" : "false",
               result.binding_status, blocked.refusal_reason);
}
