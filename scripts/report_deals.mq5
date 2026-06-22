//+------------------------------------------------------------------+
//|                                                 report_deals.mq5  |
//|   Export the LIVE/DEMO account deal history to CSV WITH magic.    |
//|                                                                  |
//|   Why this exists: the MT5 account "Report" (HTML/XLSX) export    |
//|   does NOT carry the per-deal magic number, so it cannot be used  |
//|   to attribute P&L to individual EAs. This script walks the deal  |
//|   history via the HistoryDeal API (DEAL_MAGIC) and writes a clean |
//|   CSV that parse_live_deals.ps1 rolls up by (magic, symbol).      |
//|                                                                  |
//|   USAGE: copy into <DataDir>\MQL5\Scripts\, refresh Navigator,    |
//|   drag onto any chart, set InpFromDate, run. Output goes to the   |
//|   COMMON Files folder; the exact path is printed to the Experts   |
//|   log on completion.                                              |
//|                                                                  |
//|   Pairs with the ea-live-monitor skill.                          |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"
#property version   "1.00"
#property script_show_inputs
#property strict

input datetime InpFromDate   = D'2026.06.22 00:00:00'; // history start (deploy date)
input string   InpOutputName = "live_deals.csv";       // CSV name in Common\Files
input bool     InpClosedOnly = true;                   // only realized (OUT/INOUT) deals

//+------------------------------------------------------------------+
string EntryToStr(const long e)
{
   switch((ENUM_DEAL_ENTRY)e)
   {
      case DEAL_ENTRY_IN:    return("IN");
      case DEAL_ENTRY_OUT:   return("OUT");
      case DEAL_ENTRY_INOUT: return("INOUT");
      case DEAL_ENTRY_OUT_BY:return("OUT_BY");
   }
   return("?");
}

string TypeToStr(const long t)
{
   switch((ENUM_DEAL_TYPE)t)
   {
      case DEAL_TYPE_BUY:      return("BUY");
      case DEAL_TYPE_SELL:     return("SELL");
      case DEAL_TYPE_BALANCE:  return("BALANCE");
      case DEAL_TYPE_CREDIT:   return("CREDIT");
      case DEAL_TYPE_CHARGE:   return("CHARGE");
      case DEAL_TYPE_CORRECTION:return("CORRECTION");
   }
   return("OTHER");
}

//+------------------------------------------------------------------+
void OnStart()
{
   if(!HistorySelect(InpFromDate, TimeCurrent()))
   {
      PrintFormat("report_deals: HistorySelect failed err=%d", GetLastError());
      return;
   }

   const int total = HistoryDealsTotal();
   PrintFormat("report_deals: %d deals from %s", total, TimeToString(InpFromDate));

   // FILE_COMMON → <TerminalCommon>\Files\<name> ; CSV separator ',' written explicitly.
   const int fh = FileOpen(InpOutputName, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(fh == INVALID_HANDLE)
   {
      PrintFormat("report_deals: FileOpen('%s') failed err=%d", InpOutputName, GetLastError());
      return;
   }

   // header — parse_live_deals.ps1 keys off these exact column names
   FileWrite(fh, "time","ticket","magic","symbol","type","entry",
                 "volume","price","profit","swap","commission","net","comment");

   int written = 0;
   double sum_net = 0.0;
   for(int i=0; i<total; i++)
   {
      const ulong t = HistoryDealGetTicket(i);
      if(t == 0) continue;

      const long   entry = HistoryDealGetInteger(t, DEAL_ENTRY);
      const long   dtype = HistoryDealGetInteger(t, DEAL_TYPE);

      // realized P&L lives on OUT / INOUT deals; IN deals carry 0 profit.
      if(InpClosedOnly && entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT)
         continue;

      const datetime dtime = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
      const long   magic   = HistoryDealGetInteger(t, DEAL_MAGIC);
      const string sym     = HistoryDealGetString (t, DEAL_SYMBOL);
      const double vol     = HistoryDealGetDouble (t, DEAL_VOLUME);
      const double price   = HistoryDealGetDouble (t, DEAL_PRICE);
      const double profit  = HistoryDealGetDouble (t, DEAL_PROFIT);
      const double swap    = HistoryDealGetDouble (t, DEAL_SWAP);
      const double comm    = HistoryDealGetDouble (t, DEAL_COMMISSION);
      const double net     = profit + swap + comm;
      string comment       = HistoryDealGetString (t, DEAL_COMMENT);
      StringReplace(comment, ",", ";");   // keep CSV intact

      FileWrite(fh,
                TimeToString(dtime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                (long)t, magic, sym, TypeToStr(dtype), EntryToStr(entry),
                DoubleToString(vol,2), DoubleToString(price,5),
                DoubleToString(profit,2), DoubleToString(swap,2),
                DoubleToString(comm,2), DoubleToString(net,2),
                comment);
      written++;
      sum_net += net;
   }

   FileClose(fh);
   PrintFormat("report_deals: wrote %d rows, sum net=%.2f → Common\\Files\\%s",
               written, sum_net, InpOutputName);
   PrintFormat("report_deals: full path = %s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + InpOutputName);
}
//+------------------------------------------------------------------+
