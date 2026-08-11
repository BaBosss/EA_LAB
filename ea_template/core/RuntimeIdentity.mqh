// Runtime identity sidecar (VPS DEMO / Forward-Test identity blocker).
// This is telemetry only: it never changes an entry, lot, exit, or risk decision.
#ifndef BOSS_RUNTIME_IDENTITY_MQH
#define BOSS_RUNTIME_IDENTITY_MQH

datetime g_ri_attach_time = 0;
long     g_ri_epoch_counter = 0;
string   g_ri_attach_epoch = "";
bool     g_ri_first_trade_seen = false;

string RI_JsonEscape(string value)
  {
   StringReplace(value, "\\", "\\\\");
   StringReplace(value, "\"", "\\\"");
   StringReplace(value, "\r", "\\r");
   StringReplace(value, "\n", "\\n");
   return(value);
  }

string RI_GVName()
  {
   string seed = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "|" +
                 IntegerToString((long)_0_Magic) + "|" + LAB_ENTRY_TAG;
   string digest = CFG_Sha256Hex(seed);
   return("EA_LAB_RI_EPOCH_" + StringSubstr(digest, 0, 20));
  }

string RI_FileName()
  {
   return("EA_LAB_identity_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +
          "_" + IntegerToString((long)_0_Magic) + ".json");
  }

bool RI_HasFirstTradeAfterAttach()
  {
   datetime from = g_ri_attach_time;
   datetime to = TimeCurrent() + 86400;
   if(from <= 0 || !HistorySelect(from, to)) return(false);
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != (long)_0_Magic) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(deal_time >= g_ri_attach_time) return(true);
     }
   return(false);
  }

bool RI_Write()
  {
   long login = AccountInfoInteger(ACCOUNT_LOGIN);
   if(login == 0) return(false);
   string cfg = CFG_Fingerprint();
   string first = g_ri_first_trade_seen ? ("\"" + RI_JsonEscape(g_ri_attach_epoch) + "\"") : "null";
   string evidence = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string fname = RI_FileName();
   string tmp = fname + ".tmp";
   int fh = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
   if(fh == INVALID_HANDLE)
     {
      PrintFormat("[IDENTITY] FileOpen(%s) failed err=%d", tmp, GetLastError());
      return(false);
     }
   string json = StringFormat(
      "{\"schema\":\"runtime_identity/1\",\"account_login\":\"%I64d\",\"magic\":\"%I64d\","
      "\"ea_logical_identity\":\"%s\",\"build_receipt\":\"%s\","
      "\"config_fingerprint\":\"%s\",\"config_fingerprint_version\":\"%s\","
      "\"symbol\":\"%s\",\"timeframe\":\"%s\",\"attach_epoch\":\"%s\","
      "\"first_trade_epoch\":%s,\"evidence_timestamp\":\"%s\","
      "\"evidence_source\":\"EA_RUNTIME_COMMON_FILE\"}",
      login, (long)_0_Magic, RI_JsonEscape(LAB_ENTRY_TAG), LAB_BUILD_RECEIPT,
      cfg, CFG_FP_VERSION, RI_JsonEscape(_Symbol), EnumToString(_Period),
      RI_JsonEscape(g_ri_attach_epoch), first, RI_JsonEscape(evidence));
   FileWriteString(fh, json);
   FileClose(fh);
   if(!FileMove(tmp, FILE_COMMON, fname, FILE_COMMON | FILE_REWRITE))
     {
      int err = GetLastError();
      FileDelete(tmp, FILE_COMMON);
      PrintFormat("[IDENTITY] FileMove failed err=%d - identity sidecar not published", err);
      return(false);
     }
   PrintFormat("[IDENTITY] account=%I64d magic=%I64d ea=%s build_receipt=%s cfg=%s epoch=%s first_trade_epoch=%s",
               login, (long)_0_Magic, LAB_ENTRY_TAG, LAB_BUILD_RECEIPT, cfg,
               g_ri_attach_epoch, (g_ri_first_trade_seen ? g_ri_attach_epoch : "null"));
   return(true);
  }

void RuntimeIdentity_Init()
  {
   g_ri_attach_time = TimeCurrent();
   string gv = RI_GVName();
   double prior = 0.0;
   if(GlobalVariableCheck(gv)) prior = GlobalVariableGet(gv);
   g_ri_epoch_counter = (long)MathFloor(prior) + 1;
   if(g_ri_epoch_counter < 1) g_ri_epoch_counter = 1;
   GlobalVariableSet(gv, (double)g_ri_epoch_counter);
   GlobalVariablesFlush();
   g_ri_attach_epoch = "epoch-" + IntegerToString(g_ri_epoch_counter);
   g_ri_first_trade_seen = false;
   if(StringLen(LAB_BUILD_RECEIPT) == 0 || LAB_BUILD_RECEIPT == "UNSTAMPED")
      Print("[IDENTITY] WARNING: build receipt is UNSTAMPED; monitoring must keep this runtime NON-GREEN");
   RI_Write();
  }

void RuntimeIdentity_Update()
  {
   if(g_ri_first_trade_seen) return;
   if(!RI_HasFirstTradeAfterAttach()) return;
   g_ri_first_trade_seen = true;
   RI_Write();
  }

#endif // BOSS_RUNTIME_IDENTITY_MQH
