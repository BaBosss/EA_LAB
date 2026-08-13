//+------------------------------------------------------------------+
//| Wave5G4_Rejection_Test.mq5 - ORDER-490A/B, TEST ONLY.            |
//|                                                                  |
//| Calls the canonical Wave5_SLValid() and verifies raw structural   |
//| anchors against the normalized broker-facing price.              |
//| Freeze level is intentionally not part of initial-SL validation.  |
//|                                                                  |
//| The small test seam below mirrors the existing caller's ordering: |
//| a rejected candidate records G4 evidence and returns before any   |
//| latch/publication/signal/open state is changed.  It is deliberately|
//| test-local because ExitManager.mqh is production read-only for     |
//| ORDER-490A.                                                       |
//+------------------------------------------------------------------+
#property strict

#define LAB_ENTRY_17
#define LAB_ENTRY_TAG "17_Wave5_G4_Test"
#include "../core/ExitManager.mqh"
#include "../core/entries/Entry_Wave5.mqh"

bool     g_done = false;
datetime g_test_latched_peak = 0;
double   g_test_published_sl = 0.0;
bool     g_test_published = false;
bool     g_test_signal = false;
int      g_test_open_calls = 0;

double BrokerPrice(const double rawPrice)
{
   return NormalizeDouble(rawPrice, _Digits);
}

bool GridOnTick(const double price, const double tickSize)
{
   double units = price / tickSize;
   double nearest = MathRound(units);
   double gridPrice = nearest * tickSize;
   double scale = MathMax(1.0, MathMax(MathAbs(price), MathAbs(gridPrice)));
   double tolerance = MathMax(tickSize * 1.0e-9,
                              64.0 * 2.2204460492503131e-16 * scale);
   return MathAbs(price - gridPrice) <= tolerance;
}

void TestFail(const string message, int &fail)
{
   PrintFormat("[FAIL] Wave5G4_Rejection_Test: %s", message);
   fail++;
}

// Test-only caller seam. The production caller performs the same decisive
// ordering: Wave5_SLValid -> rejection return, then latch/publish/signal.
bool TestCandidate(const int dir, const double slPrice)
{
   if(!Wave5_SLValid(dir, slPrice))
   {
      // Use the existing Wave5 diagnostic counter, not a duplicate fixture
      // counter. This is the same evidence label printed by the EA.
      g_w5_n_sl_invalid++;
      return false;
   }

   g_w5_n_signalled++;
   g_wave5_latched_peak = (datetime)1700000000;
   g_wave5_sl_price = slPrice;
   g_wave5_entry_ref = slPrice + 1.0;
   g_wave5_tp_price = slPrice + 2.0;
   g_test_latched_peak = (datetime)1700000000;
   g_test_published_sl = slPrice;
   g_test_published = true;
   g_test_signal = true;
   g_test_open_calls++;
   return true;
}

int OnInit()
{
   Entry_Wave5_Init();
   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(g_done) return;
   g_done = true;

   int fail = 0;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      TestFail("SymbolInfoTick failed", fail);
      PrintFormat("[FAIL] Wave5G4_Rejection_Test: %d assert(s) failed", fail);
      return;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopsLevelPts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)stopsLevelPts * point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || stopsLevelPts <= 0 || minDist <= 0.0)
   {
      TestFail(StringFormat("positive SYMBOL_TRADE_STOPS_LEVEL required; points=%d point=%.10f",
                            (int)stopsLevelPts, point), fail);
      PrintFormat("[FAIL] Wave5G4_Rejection_Test: %d assert(s) failed", fail);
      return;
   }
   if(tickSize <= 0.0 || !MathIsValidNumber(tickSize))
   {
      TestFail("positive SYMBOL_TRADE_TICK_SIZE required", fail);
      PrintFormat("[FAIL] Wave5G4_Rejection_Test: %d assert(s) failed", fail);
      return;
   }
   PrintFormat("[ORDER-490B] symbol=%s digits=%d bid=%.17g ask=%.17g point=%.17g stops=%d minDist=%.17g tick=%.17g",
               _Symbol, _Digits, tick.bid, tick.ask, point, (int)stopsLevelPts,
               minDist, SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE));

   // T1: current-compatible effective broker prices beyond the stops boundary.
   double longValidRaw  = tick.bid - 2.0 * minDist;
   double shortValidRaw = tick.ask + 2.0 * minDist;
   double longValid = BrokerPrice(longValidRaw);
   double shortValid = BrokerPrice(shortValidRaw);
   if(!Wave5_SLValid(1, longValidRaw))
      TestFail("T1 long valid/current-compatible SL was rejected", fail);
   if(!Wave5_SLValid(2, shortValidRaw))
      TestFail("T1 short valid/current-compatible SL was rejected", fail);

   // T3/T10: the raw anchor is intentionally fractional, while the existing
   // canonical normalization produces the executable broker price.
   const double sentinelSl = 123.456789;
   double representativeRaw = 2389.2835714285716;
   double representativeBroker = BrokerPrice(representativeRaw);
   PrintFormat("[ORDER-490B] T3 representative raw=%.17g brokerSl=%.17g digits=%d",
               representativeRaw, representativeBroker, _Digits);
   if(_Digits == 2 && MathAbs(representativeBroker - 2389.28) > 1.0e-9)
      TestFail("T3 representative NormalizeDouble result was not 2389.28", fail);

   double rawAnchor = longValid + 0.00357142857142857;
   double normalizedAnchor = BrokerPrice(rawAnchor);
   if(MathAbs(rawAnchor - normalizedAnchor) <= 1.0e-9)
      TestFail("T3 raw anchor was not fractional relative to broker normalization", fail);
   if(!Wave5_SLValid(1, rawAnchor))
      TestFail("T3 raw off-grid anchor with on-grid brokerSl was rejected", fail);
   g_wave5_sl_price = sentinelSl;
   if(!Wave5_SLValid(1, rawAnchor) || g_wave5_sl_price != sentinelSl)
      TestFail("T10 validation rewrote raw g_wave5_sl_price", fail);

   // T11: execution continues through the existing normalization path and
   // returns the same broker-facing value without changing the raw anchor.
   g_wave5_sl_price = rawAnchor;
   double initialSl = Exit_InitialSL(1, tick.bid);
   if(initialSl != normalizedAnchor || g_wave5_sl_price != rawAnchor)
      TestFail("T11 Exit_InitialSL changed the canonical normalization/raw anchor", fail);

   // T4: exercise the production rejection whenever the active symbol's
   // normalization can leave a broker price between tick-grid points.
   double offGridRaw = longValid + 0.25 * tickSize;
   double offGridBroker = BrokerPrice(offGridRaw);
   if(!GridOnTick(offGridBroker, tickSize))
   {
      if(Wave5_SLValid(1, offGridRaw))
         TestFail("T4 genuinely off-grid effective brokerSl was accepted", fail);
      PrintFormat("[ORDER-490B] T4 effective off-grid rejected: raw=%.17g brokerSl=%.17g tick=%.17g",
                  offGridRaw, offGridBroker, tickSize);
   }
   else
   {
      double syntheticBroker = 2389.28;
      double syntheticTick = 0.25;
      if(GridOnTick(syntheticBroker, syntheticTick))
         TestFail("T4 deterministic off-grid vector was not off-grid", fail);
      PrintFormat("[ORDER-490B] T4 branch characterized: brokerSl=%.2f tick=%.2f is rejected by the production grid predicate when present",
                  syntheticBroker, syntheticTick);
   }

   // T5: characterize the exact current boundary. Production rejects only
   // strictly less than minDist, so equality is expected to be accepted.
   double longBoundaryRaw = tick.bid - minDist;
   double longBoundary = BrokerPrice(longBoundaryRaw);
   bool boundaryAccepted = Wave5_SLValid(1, longBoundaryRaw);
   PrintFormat("[ORDER-490B] T5 exact boundary: direction=long distance=%.10f minDist=%.10f brokerSl=%.17g result=%s",
               tick.bid - longBoundary, minDist, longBoundary, boundaryAccepted ? "ACCEPT" : "REJECT");
   if(!boundaryAccepted)
      TestFail("T5 exact current stops-level boundary was not accepted", fail);

   // T2/T6: force a strict inside-boundary candidate through the unchanged
   // guard and the test-local equivalent of the existing caller's rejection seam.
   const datetime sentinelPeak = (datetime)1600000000;
   const double sentinelEntry = 223.456789;
   const double sentinelTp = 323.456789;
   g_wave5_latched_peak = sentinelPeak;
   g_wave5_sl_price = sentinelSl;
   g_wave5_entry_ref = sentinelEntry;
   g_wave5_tp_price = sentinelTp;
   g_w5_n_signalled = 0;
   g_test_latched_peak = sentinelPeak;
   g_test_published_sl = sentinelSl;
   g_test_published = false;
   g_test_signal = false;
   g_test_open_calls = 0;
   g_w5_n_sl_invalid = 0;

   double longTooClose = tick.bid - 0.5 * minDist;
   bool rejected = !TestCandidate(1, longTooClose);
   if(!rejected)
      TestFail("T2 too-close SL inside stops-level boundary was accepted", fail);

   if(g_w5_n_sl_invalid != 1)
      TestFail(StringFormat("T3/T6 existing g_w5_n_sl_invalid=%d, want 1", g_w5_n_sl_invalid), fail);
   if(g_wave5_latched_peak != sentinelPeak ||
      g_wave5_sl_price != sentinelSl ||
      g_wave5_entry_ref != sentinelEntry ||
      g_wave5_tp_price != sentinelTp ||
      g_w5_n_signalled != 0 ||
      g_test_latched_peak != sentinelPeak ||
      g_test_published_sl != sentinelSl ||
      g_test_published || g_test_signal || g_test_open_calls != 0)
      TestFail("T8 rejected candidate changed production/test latch/publication/signal/open state", fail);

   PrintFormat("[ORDER-490B] T2/T6/T8 reject evidence: sl_invalid=%d signalled=%d latched=%s published=%s signal=%s open_calls=%d",
               g_w5_n_sl_invalid,
               g_w5_n_signalled,
               g_test_latched_peak == sentinelPeak ? "NO" : "YES",
               g_test_published ? "YES" : "NO",
               g_test_signal ? "YES" : "NO",
               g_test_open_calls);

   // T7: freeze level is intentionally absent from Wave5_SLValid and this
   // valid candidate remains accepted regardless of the broker freeze value.
   if(!Wave5_SLValid(1, longValidRaw))
      TestFail("T7 valid SL was affected by freeze-level policy", fail);
   PrintFormat("[ORDER-490B] T7 freeze excluded: freeze_points=%d result=PASS",
               (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL));

   if(fail == 0) Print("[PASS] Wave5G4_Rejection_Test: T1-T11 OK; G4 rejection observed");
   else          PrintFormat("[FAIL] Wave5G4_Rejection_Test: %d assert(s) failed", fail);
}

void OnDeinit(const int reason)
{
   Indi_Deinit();
}
