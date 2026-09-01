//+------------------------------------------------------------------+
//| Probe_19_AdaptiveTrendGrid_P4BUnitExport.mq5                     |
//| Diagnostic-only sibling of Probe_19_AdaptiveTrendGrid.          |
//| Strategy/risk mechanics remain owned by the unchanged LabCore.   |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.01"
#property description "Boss19 P4B source-bound unit identity diagnostic"
#property strict

#define LAB_ENTRY_19
#define LAB_ENTRY_TAG "19_AdaptiveTrendGrid"
#include "core/LabCore.mqh"

#define P4B_UNIT_SCHEMA "BOSS19_P4B_UNIT_SOURCE_V1"

string P4B_UnitExportFile()
{
   string s = _Symbol;
   StringReplace(s, "/", "_");
   StringReplace(s, "\\", "_");
   StringReplace(s, ":", "_");
   return "P4B_B19_UNIT_" + s + "_" + IntegerToString((int)_Period) + "_" +
          IntegerToString((int)_0_Magic) + ".csv";
}

void P4B_WriteHeader(const int fh)
{
   FileWrite(fh,      "schema_version","symbol","period","period_name","magic","account_margin_mode",
      "deal_id","position_id","order_id","deal_entry","deal_type",
      "deal_time_server","deal_time_msc","volume","price","commission","swap","profit");
}

bool P4B_SelectedDealIsEligible(const ulong deal)
{
   if(deal == 0) return false;
   if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) return false;
   if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != (long)_0_Magic) return false;
   const long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
   return (dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL);
}

void P4B_WriteSelectedDeal(const int fh, const ulong deal)
{
   const long positionId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   const long orderId = HistoryDealGetInteger(deal, DEAL_ORDER);
   const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
   const long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
   const long timeSec = HistoryDealGetInteger(deal, DEAL_TIME);
   const long timeMsc = HistoryDealGetInteger(deal, DEAL_TIME_MSC);

   FileWrite(fh,
      P4B_UNIT_SCHEMA,
      _Symbol,
      IntegerToString((int)_Period),
      EnumToString((ENUM_TIMEFRAMES)_Period),      IntegerToString((int)_0_Magic),
      IntegerToString((int)AccountInfoInteger(ACCOUNT_MARGIN_MODE)),
      StringFormat("%I64u", deal),
      StringFormat("%I64d", positionId),
      StringFormat("%I64d", orderId),
      IntegerToString((int)entry),
      IntegerToString((int)dealType),
      TimeToString((datetime)timeSec, TIME_DATE|TIME_SECONDS),
      StringFormat("%I64d", timeMsc),
      DoubleToString(HistoryDealGetDouble(deal, DEAL_VOLUME), 8),
      DoubleToString(HistoryDealGetDouble(deal, DEAL_PRICE), _Digits),
      DoubleToString(HistoryDealGetDouble(deal, DEAL_COMMISSION), 8),
      DoubleToString(HistoryDealGetDouble(deal, DEAL_SWAP), 8),
      DoubleToString(HistoryDealGetDouble(deal, DEAL_PROFIT), 8));
}

void P4B_WriteDeal(const ulong deal)
{
   if(deal == 0 || !HistoryDealSelect(deal))
   {
      PrintFormat("[P4B_UNIT] REFUSE deal-select %I64u", deal);
      return;
   }
   if(!P4B_SelectedDealIsEligible(deal)) return;

   const string fname = P4B_UnitExportFile();
   const int fh = FileOpen(fname, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ, ',');   if(fh == INVALID_HANDLE)
   {
      PrintFormat("[P4B_UNIT] REFUSE file-open %s error=%d", fname, GetLastError());
      return;
   }
   if(FileSize(fh) == 0) P4B_WriteHeader(fh);
   FileSeek(fh, 0, SEEK_END);
   P4B_WriteSelectedDeal(fh, deal);
   FileFlush(fh);
   FileClose(fh);
}

bool P4B_WriteFinalHistorySnapshot()
{
   const string fname = P4B_UnitExportFile();
   if(!HistorySelect(0, TimeCurrent()))
   {
      PrintFormat("[P4B_UNIT] REFUSE final-history-select error=%d", GetLastError());
      return false;
   }
   const int fh = FileOpen(fname, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ, ',');
   if(fh == INVALID_HANDLE)
   {
      PrintFormat("[P4B_UNIT] REFUSE final-file-open %s error=%d", fname, GetLastError());
      return false;
   }
   P4B_WriteHeader(fh);
   int emitted = 0;
   const int total = HistoryDealsTotal();   for(int i = 0; i < total; i++)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || !P4B_SelectedDealIsEligible(deal)) continue;
      P4B_WriteSelectedDeal(fh, deal);
      emitted++;
   }
   FileFlush(fh);
   FileClose(fh);
   PrintFormat("[P4B_UNIT] final snapshot rows=%d history_deals=%d file=%s", emitted, total, fname);
   return (emitted > 0);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Observation only. Never call execution, strategy, risk, or state-mutating helpers here.
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0) return;
   P4B_WriteDeal(trans.deal);
}

double OnTester()
{
   // Tester-finalization only. Rebuild from source history after forced end-of-test closes exist.
   // This value is not used as an optimization criterion in this research-only fixed run.
   if(!P4B_WriteFinalHistorySnapshot())
      Print("[P4B_UNIT] REFUSE final snapshot incomplete");
   return 0.0;
}
