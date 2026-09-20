//+------------------------------------------------------------------+
//| ThinkMarketsA2Evidence.mqh                                      |
//| Typed current-window evidence for THINKMARKETS_LIVE_A2_V1.      |
//+------------------------------------------------------------------+
#ifndef EA_LAB_THINKMARKETS_A2_EVIDENCE_MQH
#define EA_LAB_THINKMARKETS_A2_EVIDENCE_MQH

const string OFP_PROVIDER_POLICY_THINKMARKETS_A2_V1 = "THINKMARKETS_LIVE_A2_V1";
const string OFP_PROVIDER_CLASS_CURRENT_WINDOW = "RESEARCH_INPUT_ONLY_CURRENT_WINDOW";
const string OFP_PROVIDER_SERVER_THINKMARKETS_LIVE = "ThinkMarkets-Live";
const int OFP_PROVIDER_TERMINAL_BUILD = 6182;
const int OFP_PROVIDER_REQUIRED_INTERVALS = 22;
const string OFP_PROVIDER_REVIEWED_REPO_HEAD =
   "041178539fe07a306af2b68b3209b8401822534c";
const string OFP_PROVIDER_EVIDENCE_MANIFEST_SHA256 =
   "1b33325e46aceee5f80041e599cc1c20f71124adbbc726721b89bef83664ff0f";

struct OFPProviderIntervalReceipt
{
   string kind;
   int    ordinal;
   string role;
   long   interval_start_msc;
   long   interval_end_msc;
   long   pass1_count;
   long   pass2_count;
   long   pass1_first_time_msc;
   long   pass2_first_time_msc;
   long   pass1_last_time_msc;
   long   pass2_last_time_msc;
   long   pass1_valid_bid_ask_count;
   long   pass2_valid_bid_ask_count;
   string pass1_quote_stream_sha256;
   string pass2_quote_stream_sha256;
   bool   pass1_api_success;
   bool   pass2_api_success;
   bool   repeat_identity;
   bool   rate_snapshot_stable;
};

struct OFPThinkMarketsA2Evidence
{
   string   policy_id;
   string   classification;
   string   provider_server;
   int      terminal_build;
   string   logical_symbol;
   string   broker_symbol;
   string   reviewed_repo_head;
   string   evidence_manifest_sha256;
   string   bundle_sha256;
   datetime profile_interval_start;
   datetime profile_interval_end;
   datetime candidate_m5_open;
   bool     true_orderflow;
   bool     executed_volume_delta_qualified;
};

bool OFP_IsLowerHexSha256(const string value)
{
   if(StringLen(value) != 64)
      return false;
   for(int i = 0; i < 64; ++i)
   {
      ushort character = StringGetCharacter(value, i);
      bool digit = character >= '0' && character <= '9';
      bool lower_hex = character >= 'a' && character <= 'f';
      if(!digit && !lower_hex)
         return false;
   }
   return true;
}

bool OFP_ExpectedThinkMarketsA2Window(const string symbol,
                                      datetime &profile_start,
                                      datetime &profile_end,
                                      datetime &candidate_open)
{
   if(symbol == "XAUUSD")
   {
      profile_start = 1789603200;
      profile_end = 1789689600;
      candidate_open = 1789775400;
      return true;
   }
   if(symbol == "EURUSD" || symbol == "GBPUSD" ||
      symbol == "EURGBP" || symbol == "USDJPY" || symbol == "EURJPY")
   {
      profile_start = 1789603200;
      profile_end = 1789689600;
      candidate_open = 1789775100;
      return true;
   }
   return false;
}

bool OFP_ValidateProviderReceipt(const OFPProviderIntervalReceipt &receipt,
                                 const string expected_kind,
                                 const int expected_ordinal,
                                 const string expected_role,
                                 const long expected_start_msc,
                                 const long expected_end_msc,
                                 string &reason)
{
   if(receipt.kind != expected_kind || receipt.ordinal != expected_ordinal ||
      receipt.role != expected_role ||
      receipt.interval_start_msc != expected_start_msc ||
      receipt.interval_end_msc != expected_end_msc)
   {
      reason = "INTERVAL_RECEIPT_ORDER_MISMATCH";
      return false;
   }
   if(receipt.interval_start_msc <= 0 ||
      receipt.interval_end_msc <= receipt.interval_start_msc ||
      receipt.pass1_count <= 0 || receipt.pass2_count <= 0 ||
      receipt.pass1_valid_bid_ask_count != receipt.pass1_count ||
      receipt.pass2_valid_bid_ask_count != receipt.pass2_count)
   {
      reason = "MALFORMED_INTERVAL_COUNTS";
      return false;
   }
   if(receipt.pass1_first_time_msc < receipt.interval_start_msc ||
      receipt.pass1_first_time_msc >= receipt.interval_end_msc ||
      receipt.pass1_last_time_msc < receipt.pass1_first_time_msc ||
      receipt.pass1_last_time_msc >= receipt.interval_end_msc ||
      receipt.pass2_first_time_msc < receipt.interval_start_msc ||
      receipt.pass2_first_time_msc >= receipt.interval_end_msc ||
      receipt.pass2_last_time_msc < receipt.pass2_first_time_msc ||
      receipt.pass2_last_time_msc >= receipt.interval_end_msc)
   {
      reason = "MALFORMED_INTERVAL_TIMES";
      return false;
   }
   if(!OFP_IsLowerHexSha256(receipt.pass1_quote_stream_sha256) ||
      !OFP_IsLowerHexSha256(receipt.pass2_quote_stream_sha256))
   {
      reason = "MALFORMED_QUOTE_STREAM_SHA256";
      return false;
   }
   if(!receipt.pass1_api_success || !receipt.pass2_api_success)
   {
      reason = "COPY_API_ERROR";
      return false;
   }
   if(!receipt.rate_snapshot_stable)
   {
      reason = "RATE_SNAPSHOT_CHANGED";
      return false;
   }
   if(!receipt.repeat_identity ||
      receipt.pass1_count != receipt.pass2_count ||
      receipt.pass1_first_time_msc != receipt.pass2_first_time_msc ||
      receipt.pass1_last_time_msc != receipt.pass2_last_time_msc ||
      receipt.pass1_valid_bid_ask_count != receipt.pass2_valid_bid_ask_count ||
      receipt.pass1_quote_stream_sha256 != receipt.pass2_quote_stream_sha256)
   {
      reason = "REPEAT_IDENTITY_MISMATCH";
      return false;
   }
   return true;
}

bool OFP_ValidateThinkMarketsA2Evidence(
   const OFPThinkMarketsA2Evidence &evidence,
   const OFPProviderIntervalReceipt &receipts[],
   string &reason)
{
   if(evidence.policy_id != OFP_PROVIDER_POLICY_THINKMARKETS_A2_V1 ||
      evidence.classification != OFP_PROVIDER_CLASS_CURRENT_WINDOW ||
      evidence.provider_server != OFP_PROVIDER_SERVER_THINKMARKETS_LIVE ||
      evidence.terminal_build != OFP_PROVIDER_TERMINAL_BUILD ||
      evidence.reviewed_repo_head != OFP_PROVIDER_REVIEWED_REPO_HEAD ||
      evidence.evidence_manifest_sha256 != OFP_PROVIDER_EVIDENCE_MANIFEST_SHA256)
   {
      reason = "PROVIDER_IDENTITY_MISMATCH";
      return false;
   }
   if(evidence.logical_symbol != evidence.broker_symbol)
   {
      reason = "SYMBOL_MAPPING_MISMATCH";
      return false;
   }
   datetime expected_profile_start = 0;
   datetime expected_profile_end = 0;
   datetime expected_candidate_open = 0;
   if(!OFP_ExpectedThinkMarketsA2Window(evidence.logical_symbol,
                                        expected_profile_start,
                                        expected_profile_end,
                                        expected_candidate_open))
   {
      reason = "SYMBOL_NOT_REVIEWED_QUALIFIED";
      return false;
   }
   if(evidence.profile_interval_start <= 0 ||
      evidence.profile_interval_end <= evidence.profile_interval_start ||
      evidence.profile_interval_end > evidence.candidate_m5_open)
   {
      reason = "FUTURE_OR_INVALID_PROFILE_INTERVAL";
      return false;
   }
   if(evidence.profile_interval_start != expected_profile_start ||
      evidence.profile_interval_end != expected_profile_end ||
      evidence.candidate_m5_open != expected_candidate_open)
   {
      reason = "CURRENT_WINDOW_MISMATCH";
      return false;
   }
   if(evidence.true_orderflow || evidence.executed_volume_delta_qualified)
   {
      reason = "PROXY_CLAIM_BOUNDARY_VIOLATION";
      return false;
   }
   if(!OFP_IsLowerHexSha256(evidence.bundle_sha256))
   {
      reason = "MALFORMED_BUNDLE_SHA256";
      return false;
   }
   if(ArraySize(receipts) != OFP_PROVIDER_REQUIRED_INTERVALS)
   {
      reason = "INTERVAL_RECEIPT_COUNT_MISMATCH";
      return false;
   }
   if(!OFP_ValidateProviderReceipt(receipts[0], "D1_PROFILE", 0, "PROFILE",
                                    (long)evidence.profile_interval_start * 1000,
                                    (long)evidence.profile_interval_end * 1000,
                                    reason))
      return false;

   long first_m5_start = (long)(evidence.candidate_m5_open - 20 * 300) * 1000;
   for(int i = 0; i < 21; ++i)
   {
      string role = i == 20 ? "CANDIDATE" : "WARMUP";
      if(!OFP_ValidateProviderReceipt(receipts[i+1], "M5", i, role,
                                      first_m5_start + (long)i * 300000,
                                      first_m5_start + (long)(i+1) * 300000,
                                      reason))
         return false;
   }
   reason = "";
   return true;
}

#endif // EA_LAB_THINKMARKETS_A2_EVIDENCE_MQH
