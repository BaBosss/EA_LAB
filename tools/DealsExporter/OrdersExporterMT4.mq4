//+------------------------------------------------------------------+
//| OrdersExporterMT4.mq4 - read-only monitor sensor (ORDER-060+CR-P0)|
//| MT4 twin of DealsExporter.mq5. Attach to ONE chart on the         |
//| monitored MT4 account. Writes BOTH monitor feeds from one EA:     |
//|   1. closed-order history -> <Common>\Files\EA_LAB_mt4_orders_<login>.csv |
//|      (once on attach, boot re-exports, then daily at InpExportHour)       |
//|   2. floating-risk snapshot -> <Common>\Files\EA_LAB_snapshot_<login>.csv |
//|      (every timer tick + on attach; equity/margin/per-magic baskets)      |
//| Merge (CR-P0, 2026-07-26): floating snapshot = the tested                 |
//| AccountSnapshot_CoreMT4.mqh, so the operator attaches ONE EA not two.     |
//| The standalone AccountSnapshotExporter.mq4 is now redundant for monitor   |
//| terminals (kept for reference/fallback).                                  |
//| No trade functions anywhere in this file OR its include.                  |
//| ⚠ GOTCHA: MT4 only exposes what the Account History tab shows -   |
//|   right-click the History tab -> "All History" once, or rows will |
//|   silently be missing. Journal prints the row count so you can    |
//|   sanity-check against the tab.                                   |
//+------------------------------------------------------------------+
#property strict
#include "..\AccountSnapshot\AccountSnapshot_CoreMT4.mqh"   // floating snapshot (Snapshot_Run/Snap_FileName)

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
   Exporter_Run();       // deals snapshot immediately on attach (proof it works)
   Snapshot_Run();       // floating snapshot too (has its own login=0 guard inside)
   g_last_export_day = 0;
   g_boot_ticks = 0;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { EventKillTimer(); }

void OnTimer()
{
   Snapshot_Run();       // floating snapshot on EVERY tick (read-only) so open-position risk stays fresh
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
