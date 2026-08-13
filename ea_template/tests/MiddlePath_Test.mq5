//+------------------------------------------------------------------+
//| MiddlePath_Test.mq5 - asserts for core\MiddlePath.mqh AAM Module 2|
//| (Middle Path Veto). No .set needed - runs on compiled defaults    |
//| (UseMiddlePathVeto=false). CalcSpace() pure-math asserts hand-     |
//| build g_mid_lines[] directly (same technique AcctGate_Test uses   |
//| driving g_rc_acct_hwm). The ATR-dependent half runs on the first   |
//| tick, same reason StackStep_Test defers to OnTick, not OnInit:     |
//| ATR needs bars, and at OnInit time here it is expected to still    |
//| read <=0 - which this test also asserts is handled as "don't      |
//| know" (no veto), not treated as a false compression signal.       |
//+------------------------------------------------------------------+
#include "../core/MiddlePath.mqh"

bool g_done = false;
int  g_fail = 0;

void SetLine(const int i, const double price, const double weight)
{
   if(ArraySize(g_mid_lines) < i + 1) ArrayResize(g_mid_lines, i + 1);
   g_mid_lines[i].price      = price;
   g_mid_lines[i].touches    = 1;
   g_mid_lines[i].last_touch = TimeCurrent();
   g_mid_lines[i].tf_origin  = (int)_Period;
   g_mid_lines[i].weight     = weight;
}

int OnInit()
{
   if(!Indi_Init()) { Print("[FAIL] MiddlePath_Test: Indi_Init failed"); return INIT_SUCCEEDED; }

   if(UseMiddlePathVeto != false)
   { Print("[FAIL] must run with compiled defaults (UseMiddlePathVeto=false)"); g_fail++; }

   // default-disabled gate must always allow, regardless of price/lines
   if(!MiddlePath_AllowEntry(1)) { Print("[FAIL] MiddlePath_AllowEntry(BUY) must be true when disabled"); g_fail++; }
   if(!MiddlePath_AllowEntry(2)) { Print("[FAIL] MiddlePath_AllowEntry(SELL) must be true when disabled"); g_fail++; }

   // pre-tick: ATR not ready yet -> CalcSpace must read as "don't know" (no veto),
   // never as a false compression/middle-path hit.
   ArrayResize(g_mid_lines, 0);
   SpaceState pre = MidPath_CalcSpace(1000.0);
   if(pre.valid || pre.in_middle_path)
   { Print("[FAIL] MidPath_CalcSpace() with ATR not ready must be valid=false, in_middle_path=false"); g_fail++; }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Indi_Deinit(); }

void OnTick()
{
   if(g_done) return;
   g_done = true;

   double atr = Indi_ATR(0);
   if(atr <= 0.0) { Print("[FAIL] MiddlePath_Test: ATR still not ready on first tick"); PrintFormat("[FAIL] MiddlePath_Test: %d assert(s) failed", g_fail + 1); return; }

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) { Print("[FAIL] MiddlePath_Test: no tick data"); return; }
   double price = t.bid;

   // centered channel: price exactly halfway between two equal-weight lines ->
   // ratio ~0.5, inside the default (MID_LOW=0.35, MID_HIGH=0.65) band -> veto.
   ArrayResize(g_mid_lines, 2);
   SetLine(0, price + 5.0 * atr, 10.0);
   SetLine(1, price - 5.0 * atr, 10.0);
   SpaceState centered = MidPath_CalcSpace(price);
   if(!centered.valid || MathAbs(centered.position_ratio - 0.5) > 0.01)
   { PrintFormat("[FAIL] centered CalcSpace: valid=%s ratio=%.4f (want valid=true, ratio~0.5)",
                 (centered.valid ? "true" : "false"), centered.position_ratio); g_fail++; }
   if(!centered.in_middle_path)
   { Print("[FAIL] centered case (ratio~0.5) must be in_middle_path=true (inside 0.35..0.65)"); g_fail++; }

   // near the lower line: ratio near 0 -> outside the band -> must NOT veto.
   SetLine(0, price + 5.0 * atr, 10.0);
   SetLine(1, price - 0.05 * atr, 10.0);
   SpaceState nearEdge = MidPath_CalcSpace(price);
   if(nearEdge.in_middle_path)
   { PrintFormat("[FAIL] near-edge case ratio=%.4f must NOT be in_middle_path", nearEdge.position_ratio); g_fail++; }

   // compression: both lines within MIN_CHANNEL_ATR combined -> veto=true, valid=false
   // (spec 2.3 distinguishes this from the outside-lines case, which does not veto).
   SetLine(0, price + 0.1 * atr, 10.0);
   SetLine(1, price - 0.1 * atr, 10.0);
   SpaceState compressed = MidPath_CalcSpace(price);
   if(!compressed.in_middle_path || compressed.valid)
   { PrintFormat("[FAIL] compression case: in_middle_path=%s valid=%s (want true/false)",
                 (compressed.in_middle_path ? "true" : "false"), (compressed.valid ? "true" : "false")); g_fail++; }

   // weight filter: a line below MIN_LINE_WEIGHT must be ignored entirely - with
   // only one (filtered) candidate line, the result is "outside every known line",
   // not a compression hit.
   ArrayResize(g_mid_lines, 1);
   SetLine(0, price + 1.0 * atr, MathMax(MIN_LINE_WEIGHT - 0.5, 0.0));
   SpaceState weak = MidPath_CalcSpace(price);
   if(weak.valid || weak.in_middle_path)
   { Print("[FAIL] a line under MIN_LINE_WEIGHT must be ignored (behaves as no line there)"); g_fail++; }

   // Donchian line source: exactly 2 lines, both trusted (weight >= MIN_LINE_WEIGHT),
   // high >= low.
   ArrayResize(g_mid_lines, 0);
   MidPath_BuildDonchianLines();
   if(ArraySize(g_mid_lines) != 2)
   { PrintFormat("[FAIL] MidPath_BuildDonchianLines() produced %d line(s), want 2", ArraySize(g_mid_lines)); g_fail++; }
   else if(g_mid_lines[0].price < g_mid_lines[1].price || g_mid_lines[0].weight < MIN_LINE_WEIGHT || g_mid_lines[1].weight < MIN_LINE_WEIGHT)
   { Print("[FAIL] MidPath_BuildDonchianLines() lines must be ordered hi>=lo and always clear MIN_LINE_WEIGHT"); g_fail++; }

   // Pivot line source: must not fault, and every produced node must be internally
   // consistent (touches>=1, weight==touches per this order's single-TF scope).
   ArrayResize(g_mid_lines, 0);
   MidPath_BuildPivotLines();
   int pn = ArraySize(g_mid_lines);
   bool pivotOk = true;
   for(int i = 0; i < pn; i++)
      if(g_mid_lines[i].touches < 1 || MathAbs(g_mid_lines[i].weight - (double)g_mid_lines[i].touches) > 0.0001)
         pivotOk = false;
   if(!pivotOk)
   { Print("[FAIL] MidPath_BuildPivotLines() produced an internally inconsistent LineNode"); g_fail++; }

   ArrayResize(g_mid_lines, 0);

   if(g_fail == 0) Print("[PASS] MiddlePath_Test: all 12 asserts OK");
   else             PrintFormat("[FAIL] MiddlePath_Test: %d assert(s) failed", g_fail);
}
