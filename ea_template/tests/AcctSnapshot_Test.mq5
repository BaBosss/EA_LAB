//+------------------------------------------------------------------+
//| AcctSnapshot_Test.mq5 - assert harness for AccountSnapshotExporter|
//| (ORDER-092). Includes AccountSnapshot_Core.mqh (run_tests.ps1     |
//| copies it beside the deployed tests from tools\AccountSnapshot\). |
//|                                                                   |
//| Flow (tester, XAUUSD H1 Model 1, a few days):                     |
//|  P0 first tick: hedging-account gate, open dummy positions -      |
//|     magic A x2 BUY (0.02+0.01), magic B x1 SELL (0.01),           |
//|     magic 0 x1 BUY (0.01, "manual"), 1 pending BUY-LIMIT under    |
//|     magic B far below market.                                     |
//|  P1 ~20 ticks later (price has moved): Snap_Export to a TEST      |
//|     filename in Common\Files, read the CSV back and assert:       |
//|     - ACCOUNT row: equity/balance/margin > 0, margin level > 0,   |
//|       currency + stop-out fields present                          |
//|     - per-magic grouping: A = 2 pos / 0.03 lots, B = 1 pos +      |
//|       1 pending, magic 0 = 1 pos; symbols column = _Symbol        |
//|     - floating P&L nonzero while positions are open, and          |
//|       sum(magic float) == equity - balance (swap-inclusive)       |
//|     - SYMBOL row: 4 positions / 0.05 lots on _Symbol              |
//|     - oldest_open_hours >= 0 and sane (< test span)               |
//|  Cleanup: close everything, delete pending + the TEST CSV.        |
//| The trade calls live HERE (tester-only harness) - the exporter    |
//| include under test contains none (verified by static grep in the  |
//| ORDER-092 build check).                                           |
//| Verdict "[PASS]/[FAIL] AcctSnapshot_Test" printed once at the end.|
//+------------------------------------------------------------------+
#include "AccountSnapshot_Core.mqh"
#include <Trade\Trade.mqh>

#define MAGIC_A   917201
#define MAGIC_B   917202
#define SNAP_TEST_FILE "EA_LAB_snapshot_TEST.csv"

int    g_fail = 0;
int    g_phase = 0;      // 0=setup 1=wait-ticks 2=done
int    g_ticks = 0;
CTrade t_trade;

void TFail(const string m) { Print("[SNAP-TEST FAIL] ", m); g_fail++; }

bool OpenPos(const long magic, const bool buy, const double lots)
{
   t_trade.SetExpertMagicNumber((ulong)magic);
   if(buy) return t_trade.Buy(lots, _Symbol, 0.0, 0.0, 0.0, "SnapTest");
   return t_trade.Sell(lots, _Symbol, 0.0, 0.0, 0.0, "SnapTest");
}

void CloseAllTest()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      t_trade.PositionClose(tk);
   }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      t_trade.OrderDelete(tk);
   }
}

//--- one parsed CSV row (18 fields)
string g_f[18];

bool ReadRow(const int fh)
{
   for(int i = 0; i < 18; i++)
   {
      if(FileIsEnding(fh)) return false;
      g_f[i] = FileReadString(fh);
   }
   return true;
}

void AssertCsv()
{
   int fh = FileOpen(SNAP_TEST_FILE, FILE_READ | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(fh == INVALID_HANDLE) { TFail("cannot read back the snapshot CSV"); return; }

   bool sawHeader = false, sawAccount = false, sawSymbolRow = false;
   bool sawA = false, sawB = false, saw0 = false;
   double eq = 0, bal = 0, magicFloatSum = 0;
   int magicRows = 0;

   while(ReadRow(fh))
   {
      string rt = g_f[0];
      if(rt == "row_type") { sawHeader = true; continue; }
      if(rt == "ACCOUNT")
      {
         sawAccount = true;
         eq  = StringToDouble(g_f[4]);
         bal = StringToDouble(g_f[5]);
         double margin = StringToDouble(g_f[6]);
         double mlvl   = StringToDouble(g_f[8]);
         if(eq <= 0)  TFail("ACCOUNT equity <= 0");
         if(bal <= 0) TFail("ACCOUNT balance <= 0");
         if(margin <= 0) TFail("ACCOUNT margin <= 0 with 4 open positions");
         if(mlvl <= 0)   TFail("ACCOUNT margin level <= 0 with open positions");
         if(StringLen(g_f[3]) == 0) TFail("ACCOUNT currency empty");
         if(g_f[9] != "PERCENT" && g_f[9] != "MONEY") TFail("ACCOUNT stopout_mode invalid: " + g_f[9]);
      }
      else if(rt == "MAGIC")
      {
         magicRows++;
         long   magic = StringToInteger(g_f[11]);
         string syms  = g_f[12];
         double fl    = StringToDouble(g_f[13]);
         double lots  = StringToDouble(g_f[14]);
         int    pos   = (int)StringToInteger(g_f[15]);
         double ageH  = StringToDouble(g_f[16]);
         int    pend  = (int)StringToInteger(g_f[17]);
         magicFloatSum += fl;
         if(StringFind(syms, _Symbol) < 0)
            TFail(StringFormat("MAGIC %d symbols column '%s' missing %s", (int)magic, syms, _Symbol));
         if(ageH < 0 || ageH > 24 * 30)
            TFail(StringFormat("MAGIC %d oldest_open_hours insane: %.1f", (int)magic, ageH));
         if(magic == MAGIC_A)
         {
            sawA = true;
            if(pos != 2) TFail(StringFormat("magic A open_positions=%d expected 2", pos));
            if(MathAbs(lots - 0.03) > 0.001) TFail(StringFormat("magic A lots=%.2f expected 0.03", lots));
            if(pend != 0) TFail(StringFormat("magic A pending=%d expected 0", pend));
         }
         else if(magic == MAGIC_B)
         {
            sawB = true;
            if(pos != 1) TFail(StringFormat("magic B open_positions=%d expected 1", pos));
            if(pend != 1) TFail(StringFormat("magic B pending=%d expected 1", pend));
         }
         else if(magic == 0)
         {
            saw0 = true;
            if(pos != 1) TFail(StringFormat("magic 0 open_positions=%d expected 1", pos));
         }
         else TFail(StringFormat("unexpected magic row: %d", (int)magic));
      }
      else if(rt == "SYMBOL")
      {
         sawSymbolRow = true;
         if(g_f[12] != _Symbol) { TFail("SYMBOL row for unexpected symbol: " + g_f[12]); continue; }
         double lots = StringToDouble(g_f[14]);
         int    pos  = (int)StringToInteger(g_f[15]);
         if(pos != 4) TFail(StringFormat("SYMBOL open_positions=%d expected 4", pos));
         if(MathAbs(lots - 0.05) > 0.001) TFail(StringFormat("SYMBOL lots=%.2f expected 0.05", lots));
      }
      else TFail("unknown row_type: " + rt);
   }
   FileClose(fh);

   if(!sawHeader)    TFail("header row missing");
   if(!sawAccount)   TFail("ACCOUNT row missing");
   if(!sawA)         TFail("MAGIC row for magic A missing");
   if(!sawB)         TFail("MAGIC row for magic B missing");
   if(!saw0)         TFail("MAGIC row for magic 0 (manual trades) missing");
   if(!sawSymbolRow) TFail("SYMBOL row missing");
   if(magicRows != 3) TFail(StringFormat("expected exactly 3 MAGIC rows, got %d", magicRows));
   if(MathAbs(magicFloatSum) < 0.005)
      TFail("floating P&L sums to ~0 with open positions (must be nonzero: spread cost alone > 0)");
   if(sawAccount && MathAbs((eq - bal) - magicFloatSum) > 0.05)
      TFail(StringFormat("float consistency: equity-balance=%.2f vs sum(magic float)=%.2f",
                         eq - bal, magicFloatSum));
}

void Verdict()
{
   CloseAllTest();
   FileDelete(SNAP_TEST_FILE, FILE_COMMON);
   if(g_fail == 0) Print("[PASS] AcctSnapshot_Test: all asserts OK");
   else            PrintFormat("[FAIL] AcctSnapshot_Test: %d assert(s) failed", g_fail);
   g_phase = 2;
}

int OnInit() { return INIT_SUCCEEDED; }

void OnDeinit(const int reason)
{
   if(g_phase != 2) PrintFormat("[FAIL] AcctSnapshot_Test: incomplete run (phase %d)", g_phase);
   FileDelete(SNAP_TEST_FILE, FILE_COMMON);   // never leave the TEST file in Common\Files
}

void OnTick()
{
   if(g_phase == 2) return;

   if(g_phase == 0)
   {
      if(!MQLInfoInteger(MQL_TESTER))
      {
         TFail("harness contains trade calls - it must only ever run in the tester");
         Verdict();
         return;
      }
      if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)
         != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      {
         TFail("tester account is NETTING - same-symbol multi-magic test impossible here");
         Verdict();
         return;
      }
      if(!OpenPos(MAGIC_A, true, 0.02) || !OpenPos(MAGIC_A, true, 0.01))
         TFail("could not open magic A positions");
      if(!OpenPos(MAGIC_B, false, 0.01))
         TFail("could not open magic B position");
      if(!OpenPos(0, true, 0.01))
         TFail("could not open magic 0 (manual) position");
      t_trade.SetExpertMagicNumber((ulong)MAGIC_B);
      double px = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.5, _Digits);
      if(!t_trade.BuyLimit(0.01, px, _Symbol, 0.0, 0.0, ORDER_TIME_GTC, 0, "SnapTestPend"))
         TFail("could not place pending order");
      if(g_fail > 0) { Verdict(); return; }
      g_phase = 1;
      return;
   }

   // phase 1: let price move a little so floating P&L is unambiguous, then export+assert
   g_ticks++;
   if(g_ticks < 20) return;
   if(!Snap_Export(SNAP_TEST_FILE)) TFail("Snap_Export returned false");
   AssertCsv();
   Verdict();
}
