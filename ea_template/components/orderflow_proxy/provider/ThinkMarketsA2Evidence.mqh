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
const string OFP_PROVIDER_BUNDLE_SCHEMA = "orderflow_proxy_provider_bundle/v1";
const string OFP_PROVIDER_NATIVE_INTEGRITY_SCHEMA =
   "orderflow_proxy_native_payload_integrity/v1";

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

string OFP_CanonicalBool(const bool value)
{
   return value ? "true" : "false";
}

void OFP_AppendIntegrityScalar(string &serialized,
                               const string name,
                               const string type_tag,
                               const string value)
{
   // Accepted values are ASCII.  The fixed field order plus byte length makes
   // the record unambiguous and matches provider_bundle.py exactly.
   serialized += name + "|" + type_tag + "|" +
                 IntegerToString(StringLen(value)) + "|" + value + "\n";
}

string OFP_Sha256Hex(const string value)
{
   uchar data[], key[], hash[];
   int size = StringToCharArray(value, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(size <= 1)
      return "";
   ArrayResize(data, size - 1);
   ArrayResize(key, 0);
   if(CryptEncode(CRYPT_HASH_SHA256, data, key, hash) != 32)
      return "";
   string hexadecimal = "";
   const string digits = "0123456789abcdef";
   for(int i = 0; i < 32; ++i)
   {
      hexadecimal += StringSubstr(digits, (int)(hash[i] >> 4), 1);
      hexadecimal += StringSubstr(digits, (int)(hash[i] & 0x0f), 1);
   }
   return hexadecimal;
}

bool OFP_ExpectedThinkMarketsA2Digests(const string symbol,
                                       string &bundle_sha256,
                                       string &integrity_sha256)
{
   if(symbol == "XAUUSD")
   {
      bundle_sha256 = "eb4ae690ae9c8cbe32e5ca3b69baef1e1ce42ebe63e1fa3eba560ab95da71a8d";
      integrity_sha256 = "217efde6f0f1e9528fb22fe26c8ed0921d97e595fe0c8a0d69f72bb25dba8381";
      return true;
   }
   if(symbol == "EURUSD")
   {
      bundle_sha256 = "776df940030826e6dc60389c0b2fe731999d66b8853a8651231947f73d1de75c";
      integrity_sha256 = "3c898de1e43fa4e703b0a9f2b2adf9304d8269dbfd5624faba239ec666686228";
      return true;
   }
   if(symbol == "GBPUSD")
   {
      bundle_sha256 = "3fa11f7c2db87873dcf809dafa344a487b9869fb091c351d68a3da7da7383046";
      integrity_sha256 = "ce455c8bf7f22bc3830f7791b5136992e0196d332d24e8aa1787bf1413d7fde5";
      return true;
   }
   if(symbol == "EURGBP")
   {
      bundle_sha256 = "330fb9d2e0cdbd4d82ab7fa25c998c47a51a0f1f520cbfe1f14fadc807966c92";
      integrity_sha256 = "468be594fc8f89a938add1e6673ce9f0f6a88206bd2e01c8d5733059a1739d24";
      return true;
   }
   if(symbol == "USDJPY")
   {
      bundle_sha256 = "26f6af2bba8bfa786e1940b1f818d4a84d2c7cec3c332ebe65267e5226953287";
      integrity_sha256 = "6059ab6923f47699d305085055c996e699cab487fc06e5640def01c7c3162a28";
      return true;
   }
   if(symbol == "EURJPY")
   {
      bundle_sha256 = "e9c2d00c7d193e5e488e0b30bb25418f6f506db7933eb33233ede02c73f10576";
      integrity_sha256 = "f10d000ac11fcb96f99cf0e9d9ea4624661405f6331859b5fa64ad6580743885";
      return true;
   }
   return false;
}

string OFP_ThinkMarketsA2PayloadIntegritySha256(
   const OFPThinkMarketsA2Evidence &evidence,
   const OFPProviderIntervalReceipt &receipts[])
{
   // bundle_sha256 is explicitly excluded: it is checked against a separate
   // per-symbol pin, avoiding digest recursion.  The integrity digest itself
   // is never accepted from the caller.
   string serialized = OFP_PROVIDER_NATIVE_INTEGRITY_SCHEMA + "\n";
   OFP_AppendIntegrityScalar(serialized, "schema", "s", OFP_PROVIDER_BUNDLE_SCHEMA);
   OFP_AppendIntegrityScalar(serialized, "policy_id", "s", evidence.policy_id);
   OFP_AppendIntegrityScalar(serialized, "classification", "s", evidence.classification);
   OFP_AppendIntegrityScalar(serialized, "provider_server", "s", evidence.provider_server);
   OFP_AppendIntegrityScalar(serialized, "terminal_build", "i", IntegerToString(evidence.terminal_build));
   OFP_AppendIntegrityScalar(serialized, "logical_symbol", "s", evidence.logical_symbol);
   OFP_AppendIntegrityScalar(serialized, "broker_symbol", "s", evidence.broker_symbol);
   OFP_AppendIntegrityScalar(serialized, "reviewed_repo_head", "s", evidence.reviewed_repo_head);
   OFP_AppendIntegrityScalar(serialized, "evidence_manifest_sha256", "s", evidence.evidence_manifest_sha256);
   OFP_AppendIntegrityScalar(serialized, "profile_interval_start", "i", IntegerToString((long)evidence.profile_interval_start));
   OFP_AppendIntegrityScalar(serialized, "profile_interval_end", "i", IntegerToString((long)evidence.profile_interval_end));
   OFP_AppendIntegrityScalar(serialized, "candidate_m5_open", "i", IntegerToString((long)evidence.candidate_m5_open));
   OFP_AppendIntegrityScalar(serialized, "true_orderflow", "b", OFP_CanonicalBool(evidence.true_orderflow));
   OFP_AppendIntegrityScalar(serialized, "executed_volume_delta_qualified", "b", OFP_CanonicalBool(evidence.executed_volume_delta_qualified));
   OFP_AppendIntegrityScalar(serialized, "current_entry_signal_compatible", "b", "false");
   OFP_AppendIntegrityScalar(serialized, "order_execution_authorized", "b", "false");
   OFP_AppendIntegrityScalar(serialized, "time_exit_consumer_owned", "b", "true");
   OFP_AppendIntegrityScalar(serialized, "receipt_count", "i", IntegerToString(ArraySize(receipts)));

   for(int i = 0; i < ArraySize(receipts); ++i)
   {
      const string prefix = "receipt[" + StringFormat("%02d", i) + "].";
      OFP_AppendIntegrityScalar(serialized, prefix + "kind", "s", receipts[i].kind);
      OFP_AppendIntegrityScalar(serialized, prefix + "ordinal", "i", IntegerToString(receipts[i].ordinal));
      OFP_AppendIntegrityScalar(serialized, prefix + "role", "s", receipts[i].role);
      OFP_AppendIntegrityScalar(serialized, prefix + "interval_start_msc", "i", IntegerToString(receipts[i].interval_start_msc));
      OFP_AppendIntegrityScalar(serialized, prefix + "interval_end_msc", "i", IntegerToString(receipts[i].interval_end_msc));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass1_count", "i", IntegerToString(receipts[i].pass1_count));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass2_count", "i", IntegerToString(receipts[i].pass2_count));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass1_first_time_msc", "i", IntegerToString(receipts[i].pass1_first_time_msc));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass2_first_time_msc", "i", IntegerToString(receipts[i].pass2_first_time_msc));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass1_last_time_msc", "i", IntegerToString(receipts[i].pass1_last_time_msc));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass2_last_time_msc", "i", IntegerToString(receipts[i].pass2_last_time_msc));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass1_valid_bid_ask_count", "i", IntegerToString(receipts[i].pass1_valid_bid_ask_count));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass2_valid_bid_ask_count", "i", IntegerToString(receipts[i].pass2_valid_bid_ask_count));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass1_quote_stream_sha256", "s", receipts[i].pass1_quote_stream_sha256);
      OFP_AppendIntegrityScalar(serialized, prefix + "pass2_quote_stream_sha256", "s", receipts[i].pass2_quote_stream_sha256);
      OFP_AppendIntegrityScalar(serialized, prefix + "pass1_api_success", "b", OFP_CanonicalBool(receipts[i].pass1_api_success));
      OFP_AppendIntegrityScalar(serialized, prefix + "pass2_api_success", "b", OFP_CanonicalBool(receipts[i].pass2_api_success));
      OFP_AppendIntegrityScalar(serialized, prefix + "repeat_identity", "b", OFP_CanonicalBool(receipts[i].repeat_identity));
      OFP_AppendIntegrityScalar(serialized, prefix + "rate_snapshot_stable", "b", OFP_CanonicalBool(receipts[i].rate_snapshot_stable));
   }
   return OFP_Sha256Hex(serialized);
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
   string expected_bundle_sha256 = "";
   string expected_integrity_sha256 = "";
   if(!OFP_ExpectedThinkMarketsA2Digests(evidence.logical_symbol,
                                         expected_bundle_sha256,
                                         expected_integrity_sha256))
   {
      reason = "SYMBOL_NOT_REVIEWED_QUALIFIED";
      return false;
   }
   if(evidence.bundle_sha256 != expected_bundle_sha256)
   {
      reason = "BUNDLE_SHA256_MISMATCH";
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
   string actual_integrity_sha256 =
      OFP_ThinkMarketsA2PayloadIntegritySha256(evidence, receipts);
   if(actual_integrity_sha256 == "")
   {
      reason = "PAYLOAD_INTEGRITY_HASH_FAILED";
      return false;
   }
   if(actual_integrity_sha256 != expected_integrity_sha256)
   {
      reason = "NATIVE_PAYLOAD_INTEGRITY_MISMATCH";
      return false;
   }
   reason = "";
   return true;
}

#endif // EA_LAB_THINKMARKETS_A2_EVIDENCE_MQH
