//+------------------------------------------------------------------+
//| DealsExporter.mq5 - read-only nightly deals snapshot (ORDER-039) |
//| Attach to ONE chart on the monitored account (demo/live). Writes  |
//| the full deal history as CSV to the COMMON Files folder so a      |
//| collector script outside the terminal sandbox can pick it up:     |
//|   <Common>\Files\EA_LAB_deals_<login>.csv                         |
//| No trade functions anywhere in this file - it cannot touch the    |
//| account. Full-snapshot overwrite each export = idempotent.        |
//| Exports once on attach, then daily at InpExportHour.              |
//+------------------------------------------------------------------+
#property strict

input int    InpExportHour = 23;               // server hour to export daily
input datetime InpHistoryFrom = D'2026.01.01'; // export deals from this date

datetime g_last_export_day = 0;

string Exporter_FileName()
{
   return "EA_LAB_deals_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
}

void Exporter_Run()
{
   if(!HistorySelect(InpHistoryFrom, TimeCurrent() + 86400))
   {
      Print("[EXPORT] HistorySelect failed");
      return;
   }
   int total = HistoryDealsTotal();
   int fh = FileOpen(Exporter_FileName(), FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE)
   {
      PrintFormat("[EXPORT] FileOpen failed err=%d", GetLastError());
      return;
   }
   FileWrite(fh, "ticket", "time", "symbol", "magic", "type", "entry",
                 "volume", "price", "profit", "swap", "commission", "comment");
   int rows = 0;
   for(int i = 0; i < total; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      FileWrite(fh,
         IntegerToString((long)tk),
         TimeToString((datetime)HistoryDealGetInteger(tk, DEAL_TIME), TIME_DATE | TIME_SECONDS),
         HistoryDealGetString(tk, DEAL_SYMBOL),
         IntegerToString(HistoryDealGetInteger(tk, DEAL_MAGIC)),
         IntegerToString(HistoryDealGetInteger(tk, DEAL_TYPE)),
         IntegerToString(HistoryDealGetInteger(tk, DEAL_ENTRY)),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_VOLUME), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_PRICE), 5),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_PROFIT), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_SWAP), 2),
         DoubleToString(HistoryDealGetDouble(tk, DEAL_COMMISSION), 2),
         HistoryDealGetString(tk, DEAL_COMMENT));
      rows++;
   }
   FileClose(fh);
   PrintFormat("[EXPORT] %d deal rows -> Common\\Files\\%s", rows, Exporter_FileName());
}

int g_boot_ticks = 0;   // rotation-mode support: re-export shortly after login while history syncs

int OnInit()
{
   EventSetTimer(120);   // 2-min ticks: first two re-export (fresh-login history sync), then daily check
   Exporter_Run();       // snapshot immediately on attach (proof it works)
   g_last_export_day = 0;
   g_boot_ticks = 0;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer()
{
   if(g_boot_ticks < 2)  // rotation mode: terminal may live only minutes after a fresh login —
   {                     // history often finishes syncing AFTER OnInit, so export again at +2/+4 min
      g_boot_ticks++;
      Exporter_Run();
      return;
   }
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime day = (datetime)(TimeCurrent() - (TimeCurrent() % 86400));
   if(dt.hour >= InpExportHour && day != g_last_export_day)
   {
      Exporter_Run();
      g_last_export_day = day;
   }
}

void OnTick() {}
