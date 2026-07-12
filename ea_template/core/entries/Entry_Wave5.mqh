//+------------------------------------------------------------------+
//| Entry_Wave5.mqh (ORDER-082, LAB_ENTRY_17) - Elliott wave-4 retrace|
//| arm to catch wave-5. Labels wave1(impulse)/wave2(retrace)/wave3   |
//| (confirmed break + min-run), arms a ZONE on the wave-4 retrace    |
//| between _17_EntryFib% and the structural invalidation (wave-1     |
//| top/bottom). Both directions. Once-per-structure latch keyed on   |
//| the wave-3 peak datetime (ST03 pattern, Entry_ST03.mqh:27,41).    |
//| Publishes structural SL/TP anchors into the Inputs.mqh globals    |
//| (guard G1) for ExitManager's #ifdef LAB_ENTRY_17 overrides.       |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_WAVE5_MQH
#define BOSS_LAB_ENTRY_WAVE5_MQH
#ifdef LAB_ENTRY_17
#include "IEntry.mqh"
#include "../Indicators.mqh"
#include "Wave5Swings.mqh"

datetime g_wave5_last_bar     = 0;   // once-per-bar gate (recompile-safe: reset in Init)
datetime g_wave5_latched_peak = 0;   // wave-3-peak datetime already signalled (ever, incl. after close)

void Entry_Wave5_Init()
{
   g_wave5_last_bar     = 0;
   g_wave5_latched_peak = 0;
   g_wave5_sl_price      = 0.0;
   g_wave5_tp_price      = 0.0;
   g_wave5_entry_ref     = 0.0;
}

EntrySignal Entry_Evaluate()
{
   // evaluate exactly once per CLOSED bar (ST03 pattern)
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_wave5_last_bar) return Entry_MakeNone("wave5: intrabar (bar already counted)");
   g_wave5_last_bar = curBar;

   Swing sw[];
   int n = Wave5_CollectSwings(sw, _17_MaxSwings, _17_FractalDepth);
   if(n < 4) return Entry_MakeNone("wave5: not enough confirmed swings (need 4 for 1-2-3)");

   // sw[] is newest-first, strictly alternating high/low. A 1-2-3 structure
   // needs FOUR pivots (wave1_end and wave3_peak must be the SAME type, so
   // they cannot be adjacent). Label the 4 most recent:
   //   sw[3] = wave1 origin, sw[2] = wave1 end (= wave2 origin),
   //   sw[1] = wave2 end (= wave3 origin), sw[0] = wave3 peak
   // For a long: low(sw3) -> high(sw2) -> low(sw1) -> high(sw0).
   Swing w1_origin = sw[3];
   Swing w1_end    = sw[2];
   Swing w2_end    = sw[1];
   Swing w3_peak   = sw[0];

   // wave1 impulse direction from its origin->end leg; wave3 peak must match type.
   int dir = 0; // 1 = long (wave1 up), 2 = short (wave1 down)
   if(w1_end.isHigh && !w1_origin.isHigh && w3_peak.isHigh) dir = 1;
   else if(!w1_end.isHigh && w1_origin.isHigh && !w3_peak.isHigh) dir = 2;
   else return Entry_MakeNone("wave5: 1-2-3 pivot pattern invalid");

   double wave1Len = MathAbs(w1_end.price - w1_origin.price);
   if(wave1Len <= 0.0) return Entry_MakeNone("wave5: wave1 zero length");

   // wave2 must NOT retrace past wave1 origin (EW rule: a valid 1-2-3).
   if(dir == 1 && w2_end.price <= w1_origin.price) return Entry_MakeNone("wave5: wave2 broke wave1 origin");
   if(dir == 2 && w2_end.price >= w1_origin.price) return Entry_MakeNone("wave5: wave2 broke wave1 origin");

   // wave3-confirm: broke past wave1 end (top/bottom) by >= _17_Wave3MinMult x
   // wave1Len (Fable D2, permissive default).
   double breakDist = (dir == 1 ? w3_peak.price - w1_end.price : w1_end.price - w3_peak.price);
   if(breakDist < _17_Wave3MinMult * wave1Len) return Entry_MakeNone("wave5: wave3 run too short / did not break wave1");

   // latch: one signal ever per wave3-peak datetime.
   if(w3_peak.time == g_wave5_latched_peak) return Entry_MakeNone("wave5: this wave3 peak already latched");

   // wave-4 retrace zone: between _17_EntryFib% of the FULL wave-3 length
   // (wave3 origin -> peak) and the structural invalidation (wave-1 top/bottom).
   // No 50% hard guard per AMENDMENT/Fable D1.
   Swing latest = w3_peak; // kept for the signal reason string
   double wave3Len = MathAbs(w3_peak.price - w2_end.price);
   double fibDist  = (_17_EntryFib / 100.0) * wave3Len;
   double fibLevel = (dir == 1 ? w3_peak.price - fibDist : w3_peak.price + fibDist);
   double invalidationLevel = w1_end.price; // wave-1 top (long) / wave-1 bottom (short)

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return Entry_MakeNone("wave5: no tick");
   double px = (dir == 1 ? t.bid : t.ask);
   double closePx = iClose(_Symbol, _Period, 1);

   bool inZone;
   if(dir == 1)
      inZone = (closePx <= fibLevel && closePx > invalidationLevel);
   else
      inZone = (closePx >= fibLevel && closePx < invalidationLevel);

   if(!inZone)
   {
      // beyond invalidation (structure broke) or not retraced enough yet:
      // never chase with a resting limit - no pending bookkeeping in this seam.
      if(dir == 1 && closePx <= invalidationLevel) return Entry_MakeNone("wave5: wave4 overlapped wave1 top - invalid");
      if(dir == 2 && closePx >= invalidationLevel) return Entry_MakeNone("wave5: wave4 overlapped wave1 bottom - invalid");
      return Entry_MakeNone("wave5: wave4 not yet in entry zone");
   }

   double riskAtr = Indi_RiskATR(0);
   double buffer  = _17_SLbufferATR * riskAtr;
   double slPrice = (dir == 1 ? invalidationLevel - buffer : invalidationLevel + buffer);

   // guard G4: broker-validity check BEFORE latching/publishing. Invalid SL =
   // Entry_MakeNone, never a silent distance-SL fallback (would change the
   // strategy without telling anyone). Latch (below) only happens once valid.
   if(!Wave5_SLValid(dir, slPrice))
      return Entry_MakeNone("wave5: structural SL fails broker stops-level check");

   // valid signal: latch, publish anchors, emit.
   g_wave5_latched_peak = latest.time;
   g_wave5_sl_price  = slPrice;
   g_wave5_entry_ref = px;
   g_wave5_tp_price  = (dir == 1 ? px + wave1Len : px - wave1Len); // 100% expansion from entry (Fable D3)

   EntrySignal s;
   s.direction  = dir;
   s.strength   = breakDist;
   s.confidence = 1.0;
   s.valid      = true;
   s.reason     = "wave5: wave4 zone arm dir=" + IntegerToString(dir) +
                  " fib=" + DoubleToString(_17_EntryFib, 1) +
                  " peak=" + TimeToString(latest.time);
   return s;
}

#endif // LAB_ENTRY_17
#endif // BOSS_LAB_ENTRY_WAVE5_MQH
