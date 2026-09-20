//+------------------------------------------------------------------+
//| OrderFlowProxyTemplateSeam_Test.mq5                              |
//| Compile-only harness. Do not execute or attach under this order. |
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs

#include "../components/orderflow_proxy/provider/OrderFlowProxyTemplateSeam.mqh"

void SetReceipt(OFPProviderIntervalReceipt &receipt,
                const string kind,
                const int ordinal,
                const string role,
                const long start_msc,
                const long end_msc)
{
   receipt.kind = kind;
   receipt.ordinal = ordinal;
   receipt.role = role;
   receipt.interval_start_msc = start_msc;
   receipt.interval_end_msc = end_msc;
   receipt.pass1_count = 1;
   receipt.pass2_count = 1;
   receipt.pass1_first_time_msc = start_msc + 1;
   receipt.pass2_first_time_msc = start_msc + 1;
   receipt.pass1_last_time_msc = end_msc - 1;
   receipt.pass2_last_time_msc = end_msc - 1;
   receipt.pass1_valid_bid_ask_count = 1;
   receipt.pass2_valid_bid_ask_count = 1;
   receipt.pass1_quote_stream_sha256 =
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   receipt.pass2_quote_stream_sha256 =
      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
   receipt.pass1_api_success = true;
   receipt.pass2_api_success = true;
   receipt.repeat_identity = true;
   receipt.rate_snapshot_stable = true;
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
      "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
   evidence.profile_interval_start = 1789603200;
   evidence.profile_interval_end = 1789689600;
   evidence.candidate_m5_open = 1789775100;
   evidence.true_orderflow = false;
   evidence.executed_volume_delta_qualified = false;

   OFPProviderIntervalReceipt receipts[];
   ArrayResize(receipts, OFP_PROVIDER_REQUIRED_INTERVALS);
   SetReceipt(receipts[0], "D1_PROFILE", 0, "PROFILE", 1789603200000, 1789689600000);
   long first_m5 = (evidence.candidate_m5_open - 20 * 300) * 1000;
   for(int i = 0; i < 21; ++i)
      SetReceipt(receipts[i+1], "M5", i, i == 20 ? "CANDIDATE" : "WARMUP",
                 first_m5 + (long)i * 300000,
                 first_m5 + (long)(i+1) * 300000);

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
   PrintFormat("COMPILE_ONLY ready=%s preserved=%s authority=%s btc=%s status=%s/%s",
               ready ? "true" : "false",
               geometry_preserved ? "true" : "false",
               authority_closed ? "true" : "false",
               btc_ready ? "true" : "false",
               result.binding_status, blocked.refusal_reason);
}
