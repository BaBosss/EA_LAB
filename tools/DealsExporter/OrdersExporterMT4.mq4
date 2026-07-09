//+------------------------------------------------------------------+
//| OrdersExporterMT4.mq4 - read-only nightly history snapshot        |
//| MT4 twin of DealsExporter.mq5 (ORDER-060). Attach to ONE chart on |
//| the monitored MT4 account. Writes the closed-order history as CSV |
//| to the COMMON Files folder:                                       |
//|   <Common>\Files\EA_LAB_mt4_orders_<login>.csv                    |
//| No trade functions anywhere in this file - it cannot touch the    |
//| account. Full-snapshot overwrite each export = idempotent.        |
//| Exports once on attach, then daily at InpExportHour.              |
//| ⚠ GOTCHA: MT4 only exposes what the Account History tab shows -   |
//|   right-click the History tab -> "All History" once, or rows will |
//|   silently be missing. Journal prints the row count so you can    |
//|   sanity-check against the tab.                                   |
//+------------------------------------------------------------------+
#property strict

input int      InpExportHour  = 23;              // server hour to export daily
input datetime InpHistoryFrom = D'2026.01.01';   // export orders closed after this

datetime g_last_export_day = 0;

string Exporter_FileName()
{
   return "EA_LAB_mt4_orders_" + IntegerToString(AccountNumber()) + ".csv";
}

void Exporter_Run()
{
   int total = OrdersHistoryTotal();
   int fh = FileOpen(Exporter_FileName(), FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE)
   {
      Print("[EXPORT] FileOpen failed err=", GetLastError());
      return;
   }
   FileWrite(fh, "ticket", "open_time", "close_time", "symbol", "magic", "type",
                 "lots", "open_price", "close_price", "profit", "swap", "commission", "comment");
   int rows = 0;
   for(int i = 0; i < total; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderCloseTime() == 0) continue;              // still open (shouldn't appear, guard anyway)
      if(OrderCloseTime() < InpHistoryFrom) continue;
      FileWrite(fh,
         IntegerToString(OrderTicket()),
         TimeToString(OrderOpenTime(), TIME_DATE | TIME_SECONDS),
         TimeToString(OrderCloseTime(), TIME_DATE | TIME_SECONDS),
         OrderSymbol(),
         IntegerToString(OrderMagicNumber()),
         IntegerToString(OrderType()),                 // 0=buy 1=sell 6=balance ...
         DoubleToString(OrderLots(), 2),
         DoubleToString(OrderOpenPrice(), 5),
         DoubleToString(OrderClosePrice(), 5),
         DoubleToString(OrderProfit(), 2),
         DoubleToString(OrderSwap(), 2),
         DoubleToString(OrderCommission(), 2),
         OrderComment());
      rows++;
   }
   FileClose(fh);
   Print("[EXPORT] ", rows, " order rows (history tab total=", total,
         ") -> Common\\Files\\", Exporter_FileName());
}

int g_boot_ticks = 0;   // rotation-mode support: re-export shortly after login while history syncs

int OnInit()
{
   EventSetTimer(120);   // 2-min ticks: first two re-export (fresh-login history sync), then daily check
   Exporter_Run();       // snapshot immediately on attach (proof it works)
   g_last_export_day = 0;
   g_boot_ticks = 0;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer()
{
   if(g_boot_ticks < 2)  // rotation mode: terminal may live only minutes after a fresh login
   {
      g_boot_ticks++;
      Exporter_Run();
      return;
   }
   datetime now = TimeCurrent();
   datetime day = now - (now % 86400);
   if(TimeHour(now) >= InpExportHour && day != g_last_export_day)
   {
      Exporter_Run();
      g_last_export_day = day;
   }
}

void OnTick() {}
