//+------------------------------------------------------------------+
//| ArxonMFIProvider_Test.mq5                                        |
//| Deterministic no-trade harness for the Arxon MFI+ B1 provider.   |
//+------------------------------------------------------------------+
#property strict

#include "../components/arxon/ArxonMFIProvider.mqh"

void FillBars(const double &typical[],
              const double &volumes[],
              const int count,
              double &high[],
              double &low[],
              double &close[],
              double &volume[],
              datetime &source_time[],
              datetime &confirmed_time[])
{
   ArrayResize(high, count);
   ArrayResize(low, count);
   ArrayResize(close, count);
   ArrayResize(volume, count);
   ArrayResize(source_time, count);
   ArrayResize(confirmed_time, count);

   for(int i = 0; i < count; i++)
   {
      high[i] = typical[i];
      low[i] = typical[i];
      close[i] = typical[i];
      volume[i] = volumes[i];
      source_time[i] = (datetime)(1700000000 + i * 60);
      confirmed_time[i] = (datetime)(1700000060 + i * 60);
   }
}

void TestFail(const string message, int &fail)
{
   PrintFormat("[FAIL] ArxonMFIProvider_Test: %s", message);
   fail++;
}

bool Near(const double got, const double want, const double tolerance)
{
   return MathAbs(got - want) <= tolerance;
}

void AssertReason(const string label,
                  const ArxonMFIResult &result,
                  const ArxonMFIReason want,
                  int &fail)
{
   if(result.valid || result.reason != want)
   {
      TestFail(StringFormat("%s reason=%s valid=%s, want %s invalid",
                            label,
                            ArxonMFI_ReasonName(result.reason),
                            result.valid ? "true" : "false",
                            ArxonMFI_ReasonName(want)), fail);
   }
}

void AssertBoundary(const double value,
                    const ArxonMFIState want_state,
                    const ArxonMFIExtreme want_extreme,
                    const string label,
                    int &fail)
{
   ArxonMFIState state = ARXON_MFI_STATE_INVALID;
   ArxonMFIExtreme extreme = ARXON_MFI_EXTREME_INVALID;
   if(!ArxonMFI_ClassifyValue(value, state, extreme) ||
      state != want_state || extreme != want_extreme)
   {
      TestFail(StringFormat("boundary %s classified state=%d extreme=%d",
                            label, (int)state, (int)extreme), fail);
   }
}

void AssertValidMFI(const string label,
                    const ArxonMFIResult &result,
                    const double want_mfi,
                    const ArxonMFIState want_state,
                    const ArxonMFIExtreme want_extreme,
                    int &fail)
{
   if(!result.valid)
   {
      TestFail(StringFormat("%s invalid: %s", label,
                            ArxonMFI_ReasonName(result.reason)), fail);
      return;
   }
   if(!Near(result.mfi_value, want_mfi, 1.0e-9) ||
      result.state != want_state || result.extreme != want_extreme)
   {
      TestFail(StringFormat("%s got mfi=%.12f state=%d extreme=%d",
                            label, result.mfi_value, (int)result.state,
                            (int)result.extreme), fail);
   }
}

bool SameResult(const ArxonMFIResult &a, const ArxonMFIResult &b)
{
   return a.valid == b.valid &&
          Near(a.mfi_value, b.mfi_value, 1.0e-12) &&
          a.state == b.state &&
          a.extreme == b.extreme &&
          a.source_bar_time == b.source_bar_time &&
          a.confirmed_at == b.confirmed_at &&
          a.reason == b.reason &&
          a.volume_basis == b.volume_basis &&
          a.source_index == b.source_index &&
          a.length == b.length;
}

void TestBoundaries(int &fail)
{
   AssertBoundary(44.999, ARXON_MFI_STATE_BEAR, ARXON_MFI_EXTREME_NONE, "44.999", fail);
   AssertBoundary(45.0, ARXON_MFI_STATE_NEUTRAL, ARXON_MFI_EXTREME_NONE, "45", fail);
   AssertBoundary(50.0, ARXON_MFI_STATE_NEUTRAL, ARXON_MFI_EXTREME_NONE, "50", fail);
   AssertBoundary(55.0, ARXON_MFI_STATE_NEUTRAL, ARXON_MFI_EXTREME_NONE, "55", fail);
   AssertBoundary(55.001, ARXON_MFI_STATE_BULL, ARXON_MFI_EXTREME_NONE, "55.001", fail);
   AssertBoundary(9.999, ARXON_MFI_STATE_BEAR, ARXON_MFI_EXTREME_OVERSOLD, "9.999", fail);
   AssertBoundary(10.0, ARXON_MFI_STATE_BEAR, ARXON_MFI_EXTREME_NONE, "10", fail);
   AssertBoundary(90.0, ARXON_MFI_STATE_BULL, ARXON_MFI_EXTREME_NONE, "90", fail);
   AssertBoundary(90.001, ARXON_MFI_STATE_BULL, ARXON_MFI_EXTREME_OVERBOUGHT, "90.001", fail);
}

void TestOneSidedAndInvalids(int &fail)
{
   double rising_tp[8] = {10, 11, 12, 13, 14, 15, 16, 17};
   double falling_tp[8] = {17, 16, 15, 14, 13, 12, 11, 10};
   double equal_tp[8] = {10, 10, 10, 10, 10, 10, 10, 10};
   double volume_one[8] = {1, 1, 1, 1, 1, 1, 1, 1};
   double volume_zero[8] = {0, 0, 0, 0, 0, 0, 0, 0};

   double h[], l[], c[], v[];
   datetime source[], confirmed[];
   ArxonMFIResult result;

   FillBars(rising_tp, volume_one, 8, h, l, c, v, source, confirmed);
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_TICK, result);
   AssertValidMFI("rising one-sided positive flow", result, 100.0,
                  ARXON_MFI_STATE_BULL, ARXON_MFI_EXTREME_OVERBOUGHT, fail);

   FillBars(falling_tp, volume_one, 8, h, l, c, v, source, confirmed);
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_TICK, result);
   AssertValidMFI("falling one-sided negative flow", result, 0.0,
                  ARXON_MFI_STATE_BEAR, ARXON_MFI_EXTREME_OVERSOLD, fail);

   FillBars(equal_tp, volume_one, 8, h, l, c, v, source, confirmed);
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_TICK, result);
   AssertReason("equal-price zero-flow", result,
                ARXON_MFI_REASON_ZERO_FLOW_UNDEFINED, fail);

   FillBars(rising_tp, volume_zero, 8, h, l, c, v, source, confirmed);
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_TICK, result);
   AssertReason("zero-volume zero-flow", result,
                ARXON_MFI_REASON_ZERO_FLOW_UNDEFINED, fail);

   FillBars(rising_tp, volume_one, 8, h, l, c, v, source, confirmed);
   v[7] = -1.0;
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_TICK, result);
   AssertReason("negative volume", result,
                ARXON_MFI_REASON_NEGATIVE_VOLUME, fail);

   FillBars(rising_tp, volume_one, 8, h, l, c, v, source, confirmed);
   h[7] = MathSqrt(-1.0);
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_TICK, result);
   AssertReason("non-finite OHLC", result,
                ARXON_MFI_REASON_NONFINITE_INPUT, fail);

   FillBars(rising_tp, volume_one, 8, h, l, c, v, source, confirmed);
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_UNKNOWN, result);
   AssertReason("unknown volume basis", result,
                ARXON_MFI_REASON_UNKNOWN_VOLUME_BASIS, fail);
}

void TestWarmupMixedAndDeterminism(int &fail)
{
   double mixed_tp[8] = {10, 11, 10, 12, 11, 13, 14, 12};
   double volume_one[8] = {1, 1, 1, 1, 1, 1, 1, 1};
   double h[], l[], c[], v[];
   datetime source[], confirmed[];
   ArxonMFIResult result;

   FillBars(mixed_tp, volume_one, 8, h, l, c, v, source, confirmed);
   ArxonMFI_EvaluateAt(h, l, c, v, source, confirmed, 7, 6,
                       ARXON_MFI_VOLUME_REAL, result);
   AssertReason("insufficient bars", result,
                ARXON_MFI_REASON_INSUFFICIENT_BARS, fail);

   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_REAL, result);
   const double expected_mfi = 100.0 - (100.0 / (1.0 + (50.0 / 33.0)));
   AssertValidMFI("mixed hand-computed fixture", result, expected_mfi,
                  ARXON_MFI_STATE_BULL, ARXON_MFI_EXTREME_NONE, fail);
   if(result.source_bar_time != source[7] || result.confirmed_at != confirmed[7])
      TestFail("mixed fixture source_bar_time/confirmed_at mismatch", fail);

   ArxonMFIResult again;
   ArxonMFI_EvaluateLatest(h, l, c, v, source, confirmed, 8,
                           ARXON_MFI_VOLUME_REAL, again);
   if(!SameResult(result, again))
      TestFail("same input did not reproduce identical output", fail);

   double extended_tp[10] = {10, 11, 10, 12, 11, 13, 14, 12, 99, 1};
   double extended_volume[10] = {1, 1, 1, 1, 1, 1, 1, 1, 5, 5};
   double eh[], el[], ec[], ev[];
   datetime esource[], econfirmed[];
   ArxonMFIResult prefix;
   FillBars(extended_tp, extended_volume, 10, eh, el, ec, ev, esource, econfirmed);
   ArxonMFI_EvaluateAt(eh, el, ec, ev, esource, econfirmed, 10, 7,
                       ARXON_MFI_VOLUME_REAL, prefix);
   if(!SameResult(result, prefix))
      TestFail("prefix invariance failed for source index 7 after appending bars", fail);
}

int OnInit()
{
   int fail = 0;

   TestBoundaries(fail);
   TestOneSidedAndInvalids(fail);
   TestWarmupMixedAndDeterminism(fail);

   if(fail == 0)
      Print("[PASS] ArxonMFIProvider_Test");
   else
      PrintFormat("[FAIL] ArxonMFIProvider_Test: %d assert(s) failed", fail);

   return INIT_SUCCEEDED;
}
