//+------------------------------------------------------------------+
//| MacroGate_UnknownSeam_Test.mq5 - no-trade explicit UNKNOWN test  |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#include "../core/MacroGate_Core.mqh"

#define TEST_MAGIC 7792201
#define TEST_FILE  "MacroGate_UnknownSeam_Test.csv"

const double TEST_LOT_MULT = 0.37;
int  g_fail = 0;
bool g_verdictPrinted = false;
int  g_positionsAtStart = 0;
int  g_ordersAtStart = 0;

void TFail(const string message)
{
   Print("[MGU ASSERT] ", message);
   g_fail++;
}

void TCheck(const bool condition, const string message)
{
   if(!condition) TFail(message);
}

void ClearOwned()
{
   GlobalVariableDel(MG_BlockGV(TEST_MAGIC));
   GlobalVariableDel(MG_LotMultGV(TEST_MAGIC));
}

void Configure(const bool triggerRiskOff, const int rowStaleHours)
{
   ClearOwned();
   MG_Setup(TEST_LOT_MULT, true, triggerRiskOff, 0, 0, rowStaleHours);
   if(MG_ParseMagics(IntegerToString(TEST_MAGIC)) != 1)
      TFail("expected exactly one configured magic");
}

bool WriteFixture(const string rows)
{
   int h = FileOpen(TEST_FILE, FILE_WRITE | FILE_TXT | FILE_ANSI, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
   {
      TFail(StringFormat("cannot create tester fixture (err %d)", GetLastError()));
      return false;
   }
   FileWriteString(h, "datetime,state,ri\r\n");
   FileWriteString(h, rows);
   FileClose(h);
   return true;
}

bool LoadFixture(const string rows)
{
   if(!WriteFixture(rows)) return false;
   if(!MG_LoadRegime(TEST_FILE, false))
   {
      TFail("fixture failed to load");
      return false;
   }
   return true;
}

void ExpectInactive(const string label)
{
   TCheck(!GlobalVariableCheck(MG_BlockGV(TEST_MAGIC)), label + ": BLOCK must be absent");
   TCheck(!GlobalVariableCheck(MG_LotMultGV(TEST_MAGIC)), label + ": LOTMULT must be absent");
   TCheck(!mg_gated[0], label + ": internal gated flag must be false");
}

void ExpectGate(const string label)
{
   string bgv = MG_BlockGV(TEST_MAGIC);
   string lgv = MG_LotMultGV(TEST_MAGIC);
   TCheck(GlobalVariableCheck(bgv), label + ": BLOCK missing");
   TCheck(GlobalVariableCheck(lgv), label + ": LOTMULT missing");
   if(GlobalVariableCheck(bgv))
      TCheck(GlobalVariableGet(bgv) > 0.5, label + ": BLOCK value wrong");
   if(GlobalVariableCheck(lgv))
      TCheck(MathAbs(GlobalVariableGet(lgv) - TEST_LOT_MULT) < 0.0000001,
             label + ": LOTMULT value wrong");
   TCheck(mg_gated[0], label + ": internal gated flag must be true");
}

void TestParserAndTransitionMarker()
{
   TCheck(MG_StateFromString("UNKNOWN") == MG_ST_UNKNOWN,
          "explicit UNKNOWN must parse as MG_ST_UNKNOWN");
   TCheck(MG_StateFromString(" unknown ") == MG_ST_UNKNOWN,
          "explicit UNKNOWN must retain ordinary trim/case normalization");
   TCheck(MG_StateFromString("UNKNOWN_DST_TRANSITION") == MG_ST_INVALID,
          "unrecognized transition text must remain invalid");
   TCheck(MG_StateFromString("MALFORMED") == MG_ST_INVALID,
          "malformed token must not become explicit UNKNOWN");
   TCheck(MG_StateName(MG_ST_INVALID) == "INVALID",
          "invalid state must remain distinguishable from UNKNOWN");

   Configure(true, 168);
   string rows =
      "2024.11.02 03:00,NEUTRAL,0\r\n"
      "2024.11.03 00:00,UNKNOWN,\r\n"
      "2024.11.04 03:00,RISK_OFF,0\r\n";
   if(!LoadFixture(rows)) return;

   TCheck(mg_rowCount == 3, "tester must retain explicit UNKNOWN in the timeline");
   int r = MG_RowAsOf(D'2024.11.03 12:00');
   TCheck(r == 1, "2024-11-03 probe must select the quarantine marker, not prior NEUTRAL");
   if(r == 1)
      TCheck(mg_rowState[r] == MG_ST_UNKNOWN,
             "2024-11-03 selected row must be explicit UNKNOWN");

   GlobalVariableSet(MG_BlockGV(TEST_MAGIC), 1.0);
   GlobalVariableSet(MG_LotMultGV(TEST_MAGIC), TEST_LOT_MULT);
   mg_gated[0] = true;
   MG_Tick(D'2024.11.01 12:00');
   ExpectInactive("before first row");

   MG_Tick(D'2024.11.03 12:00');
   ExpectInactive("2024-11-03 explicit UNKNOWN");
}

void TestGatedTransitions()
{
   Configure(true, 168);
   string rows =
      "2024.01.01 00:00,RISK_OFF,0\r\n"
      "2024.01.02 00:00,UNKNOWN,\r\n"
      "2024.01.03 00:00,STRESS,0\r\n"
      "2024.01.04 00:00,UNKNOWN,\r\n"
      "2024.01.05 00:00,RISK_OFF,0\r\n";
   if(!LoadFixture(rows)) return;

   MG_Tick(D'2024.01.01 12:00');
   ExpectGate("RISK_OFF");
   MG_Tick(D'2024.01.02 12:00');
   ExpectInactive("RISK_OFF -> UNKNOWN");
   MG_Tick(D'2024.01.03 12:00');
   ExpectGate("UNKNOWN -> STRESS");
   MG_Tick(D'2024.01.04 12:00');
   ExpectInactive("STRESS -> UNKNOWN");
   MG_Tick(D'2024.01.05 12:00');
   ExpectGate("UNKNOWN -> RISK_OFF");
   ClearOwned();
}

void TestInactiveTransitions()
{
   Configure(true, 168);
   string rows =
      "2024.02.01 00:00,NEUTRAL,0\r\n"
      "2024.02.02 00:00,UNKNOWN,\r\n"
      "2024.02.03 00:00,RISK_ON,0\r\n"
      "2024.02.04 00:00,UNKNOWN,\r\n";
   if(!LoadFixture(rows)) return;

   MG_Tick(D'2024.02.01 12:00');
   ExpectInactive("NEUTRAL");
   MG_Tick(D'2024.02.02 12:00');
   ExpectInactive("NEUTRAL -> UNKNOWN");
   MG_Tick(D'2024.02.03 12:00');
   ExpectInactive("RISK_ON");
   MG_Tick(D'2024.02.04 12:00');
   ExpectInactive("RISK_ON -> UNKNOWN");
}

void TestMalformedAndOrdering()
{
   Configure(true, 168);
   string malformedRows =
      "2024.03.01 00:00,RISK_ON,0\r\n"
      "2024.03.02 00:00,MALFORMED_TOKEN,0\r\n"
      "2024.03.03 00:00,RISK_OFF,0\r\n";
   if(LoadFixture(malformedRows))
   {
      TCheck(mg_rowCount == 2, "malformed token must be skipped, not retained");
      int r = MG_RowAsOf(D'2024.03.02 12:00');
      TCheck(r == 0, "malformed row must not replace the prior recognized row");
      if(r == 0)
         TCheck(mg_rowState[r] == MG_ST_RISK_ON,
                "malformed row must not be converted to UNKNOWN");
   }

   Configure(true, 168);
   string unsortedRows =
      "2024.04.02 00:00,RISK_OFF,0\r\n"
      "2024.04.01 00:00,NEUTRAL,0\r\n";
   TCheck(WriteFixture(unsortedRows), "cannot write unsorted fixture");
   bool loaded = MG_LoadRegime(TEST_FILE, false);
   TCheck(!loaded, "unsorted recognized rows must fail safe");
   TCheck(!mg_ok && mg_rowCount == 0,
          "unsorted failure must leave the guard inactive with zero rows");
}

void TestStalenessAndTriggerPolicy()
{
   Configure(true, 1);
   if(LoadFixture("2024.05.01 00:00,RISK_OFF,0\r\n"))
   {
      MG_Tick(D'2024.05.01 00:30');
      ExpectGate("fresh RISK_OFF");
      mg_lastAlert = TimeLocal();
      MG_Tick(D'2024.05.01 02:00');
      ExpectInactive("stale row");
   }

   Configure(false, 168);
   string rows =
      "2024.06.01 00:00,RISK_OFF,0\r\n"
      "2024.06.01 01:00,STRESS,0\r\n";
   if(!LoadFixture(rows)) return;
   MG_Tick(D'2024.06.01 00:30');
   ExpectInactive("RISK_OFF with trigger disabled");
   MG_Tick(D'2024.06.01 01:30');
   ExpectGate("STRESS with RISK_OFF trigger disabled");
   ClearOwned();
}

void PrintVerdict()
{
   if(g_verdictPrinted) return;
   g_verdictPrinted = true;
   if(g_fail == 0)
      Print("[PASS] MacroGate_UnknownSeam_Test: all no-trade asserts OK");
   else
      PrintFormat("[FAIL] MacroGate_UnknownSeam_Test: %d assert(s) failed", g_fail);
}

int OnInit()
{
   g_positionsAtStart = PositionsTotal();
   g_ordersAtStart = OrdersTotal();

   TCheck((bool)MQLInfoInteger(MQL_TESTER),
          "fixture must execute only inside MQL_TESTER");
   TestParserAndTransitionMarker();
   TestGatedTransitions();
   TestInactiveTransitions();
   TestMalformedAndOrdering();
   TestStalenessAndTriggerPolicy();

   TCheck(PositionsTotal() == g_positionsAtStart,
          "test changed position count despite no-trade contract");
   TCheck(OrdersTotal() == g_ordersAtStart,
          "test changed pending-order count despite no-trade contract");

   MG_Deinit();
   FileDelete(TEST_FILE);
   PrintVerdict();
   return INIT_SUCCEEDED;
}

void OnTick()
{
}

void OnDeinit(const int reason)
{
   ClearOwned();
   FileDelete(TEST_FILE);
}
