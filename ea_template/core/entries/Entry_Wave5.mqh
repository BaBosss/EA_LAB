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

// ORDER-432 finding 6 (Codex blind audit 2026-07-27). Until now every rejection here
// returned Entry_MakeNone with a reason string that LabCore then discarded without
// logging (LabCore.mqh:459/469 -- `reason` is written by every entry seam in this repo
// and read by none). The consequence is the one the VERDICT GATE names explicitly:
// "no eligible signal", "the guard rejected everything" and "the guard never executed"
// all produce zero trades and are indistinguishable in a report, so a guard could never
// be written up as passed on the evidence available.
//
// These counters are the minimum that makes any Wave5 guard testable at all. They are
// diagnostic only -- nothing branches on them, so they cannot change a decision.
int g_w5_n_eval        = 0;   // bars evaluated (the denominator for everything below)
int g_w5_n_no_swings   = 0;
int g_w5_n_bad_pattern = 0;
int g_w5_n_no_tick     = 0;   // SymbolInfoTick failed (symbol not synced - a real path)
int g_w5_n_not_in_zone = 0;   // retrace has not reached the fib zone YET (still valid)
int g_w5_n_struct_inv  = 0;   // wave4 overlapped wave1 - structure BROKEN (a different thing)
int g_w5_n_latched     = 0;
int g_w5_n_no_atr      = 0;   // ORDER-432 finding 2: Risk-ATR unreadable -> entry refused
int g_w5_n_sl_invalid  = 0;   // guard G4: structural SL failed the broker stops-level check
int g_w5_n_signalled   = 0;

void Entry_Wave5_Init()
{
   g_wave5_last_bar     = 0;
   g_wave5_latched_peak = 0;
   g_wave5_sl_price      = 0.0;
   g_wave5_tp_price      = 0.0;
   g_wave5_entry_ref     = 0.0;
   g_w5_n_eval = 0; g_w5_n_no_swings = 0; g_w5_n_bad_pattern = 0;
   g_w5_n_no_tick = 0; g_w5_n_not_in_zone = 0; g_w5_n_struct_inv = 0;
   g_w5_n_latched = 0; g_w5_n_no_atr = 0;
   g_w5_n_sl_invalid = 0; g_w5_n_signalled = 0;
}

// Printed once at OnDeinit. A guard that fired ZERO times is reported as zero on
// purpose: per the VERDICT GATE that reads as UNTESTED, and it must not be written up
// as "passed" just because the run was clean.
//
// `unaccounted` is the load-bearing field. The first version of these counters missed
// the no-tick return entirely, and the way that was caught was luck: the arithmetic
// happened to close in that run (2568+255+87+26 = 2936) only because the path never
// fired, and that closing sum was then presented as EVIDENCE the counters were wired
// correctly. An invariant used as evidence has to be enforced, not observed -- so the
// sum is now computed here. Any future return path added without a counter makes
// `unaccounted` non-zero and says so in the log, instead of quietly weakening every
// number on the line.
void Entry_Wave5_LogCounters()
{
   int counted = g_w5_n_no_swings + g_w5_n_bad_pattern + g_w5_n_no_tick +
                 g_w5_n_not_in_zone + g_w5_n_struct_inv + g_w5_n_latched +
                 g_w5_n_no_atr + g_w5_n_sl_invalid + g_w5_n_signalled;
   int unaccounted = g_w5_n_eval - counted;
   PrintFormat("[17][counters] evaluated=%d signalled=%d unaccounted=%d | rejected: no_swings=%d bad_pattern=%d no_tick=%d not_in_zone=%d struct_invalid=%d already_latched=%d NO_RISK_ATR=%d sl_invalid=%d",
               g_w5_n_eval, g_w5_n_signalled, unaccounted, g_w5_n_no_swings, g_w5_n_bad_pattern,
               g_w5_n_no_tick, g_w5_n_not_in_zone, g_w5_n_struct_inv, g_w5_n_latched,
               g_w5_n_no_atr, g_w5_n_sl_invalid);
   if(unaccounted != 0)
      PrintFormat("[17][counters] WARN unaccounted=%d - a return path in Entry_Evaluate has no counter; every rejection number above is understated", unaccounted);
}

EntrySignal Entry_Evaluate()
{
   // evaluate exactly once per CLOSED bar (ST03 pattern)
   datetime curBar = iTime(_Symbol, _Period, 0);
   if(curBar == g_wave5_last_bar) return Entry_MakeNone("wave5: intrabar (bar already counted)");
   g_wave5_last_bar = curBar;
   g_w5_n_eval++;

   Swing sw[];
   int n = Wave5_CollectSwings(sw, _17_MaxSwings, _17_FractalDepth);
   if(n < 4) { g_w5_n_no_swings++; return Entry_MakeNone("wave5: not enough confirmed swings (need 4 for 1-2-3)"); }

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
   else { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: 1-2-3 pivot pattern invalid"); }

   double wave1Len = MathAbs(w1_end.price - w1_origin.price);
   if(wave1Len <= 0.0) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave1 zero length"); }

   // wave2 must NOT retrace past wave1 origin (EW rule: a valid 1-2-3).
   if(dir == 1 && w2_end.price <= w1_origin.price) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave2 broke wave1 origin"); }
   if(dir == 2 && w2_end.price >= w1_origin.price) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave2 broke wave1 origin"); }

   // wave3-confirm: broke past wave1 end (top/bottom) by >= _17_Wave3MinMult x
   // wave1Len (Fable D2, permissive default).
   double breakDist = (dir == 1 ? w3_peak.price - w1_end.price : w1_end.price - w3_peak.price);
   if(breakDist < _17_Wave3MinMult * wave1Len) { g_w5_n_bad_pattern++; return Entry_MakeNone("wave5: wave3 run too short / did not break wave1"); }

   // latch: one signal ever per wave3-peak datetime.
   if(w3_peak.time == g_wave5_latched_peak) { g_w5_n_latched++; return Entry_MakeNone("wave5: this wave3 peak already latched"); }

   // wave-4 retrace zone: between _17_EntryFib% of the FULL wave-3 length
   // (wave3 origin -> peak) and the structural invalidation (wave-1 top/bottom).
   // No 50% hard guard per AMENDMENT/Fable D1.
   Swing latest = w3_peak; // kept for the signal reason string
   double wave3Len = MathAbs(w3_peak.price - w2_end.price);
   double fibDist  = (_17_EntryFib / 100.0) * wave3Len;
   double fibLevel = (dir == 1 ? w3_peak.price - fibDist : w3_peak.price + fibDist);
   double invalidationLevel = w1_end.price; // wave-1 top (long) / wave-1 bottom (short)

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) { g_w5_n_no_tick++; return Entry_MakeNone("wave5: no tick"); }
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
      // counted separately on purpose: "overlapped wave1" means the STRUCTURE broke and
      // this setup is dead, while "not yet in the zone" means it is still perfectly
      // valid and merely early. Lumping them under one `not_in_zone` label (as the
      // first version did) makes the counter misreport what it counts, which is a
      // smaller version of the problem these counters exist to solve.
      if(dir == 1 && closePx <= invalidationLevel) { g_w5_n_struct_inv++; return Entry_MakeNone("wave5: wave4 overlapped wave1 top - invalid"); }
      if(dir == 2 && closePx >= invalidationLevel) { g_w5_n_struct_inv++; return Entry_MakeNone("wave5: wave4 overlapped wave1 bottom - invalid"); }
      g_w5_n_not_in_zone++;
      return Entry_MakeNone("wave5: wave4 not yet in entry zone");
   }

   // ORDER-432 finding 2 (Codex blind audit 2026-07-27, verified 2026-07-27).
   // Indi_RiskATR returns 0.0 when CopyBuffer fails (Indicators.mqh:104 -- the sentinel
   // is indistinguishable from a real reading of zero), and this line used to multiply
   // it unchecked. A failed read therefore became a LEGAL ZERO BUFFER: slPrice collapsed
   // onto invalidationLevel exactly, and Wave5_SLValid can still approve that, because
   // the zone test above already guarantees the level sits on the correct side of the
   // tick. The EA would then open on a value it failed to read, with a stop sitting
   // precisely on the structural level the buffer exists to stand clear of -- so the
   // first wick through the wave-1 top takes it out.
   //
   // Refuse the entry instead. This is guard G4's rule applied one line earlier: an
   // ingredient that could not be read is never silently replaced by a default, because
   // that changes the strategy without telling anyone. A missed trade is the correct
   // price for unreadable data.
   //
   // NOTE this is live independently of FirstLotMode: unlike finding 1 (mode 42 only,
   // and no .set in this repo uses mode 42), this path is on the SL itself, so it
   // applies to the three Wave5 legs currently attached on demo, all of which run the
   // compiled default FirstLotMode=41.
   double riskAtr = Indi_RiskATR(0);
   if(_17_SLbufferATR > 0.0 && !(riskAtr > 0.0))
   {
      g_w5_n_no_atr++;
      static datetime w5_atr_log = 0;
      datetime now_atr = TimeCurrent();
      if(now_atr - w5_atr_log >= 60)
      {
         w5_atr_log = now_atr;
         Print("[17] Risk-ATR unreadable (CopyBuffer returned no data) - entry SKIPPED rather than opened with a zero SL buffer (ORDER-432 finding 2)");
      }
      return Entry_MakeNone("wave5: Risk-ATR unreadable - refusing a zero SL buffer");
   }
   double buffer  = _17_SLbufferATR * riskAtr;
   double slPrice = (dir == 1 ? invalidationLevel - buffer : invalidationLevel + buffer);

   // guard G4: broker-validity check BEFORE latching/publishing. Invalid SL =
   // Entry_MakeNone, never a silent distance-SL fallback (would change the
   // strategy without telling anyone). Latch (below) only happens once valid.
   if(!Wave5_SLValid(dir, slPrice))
   {
      g_w5_n_sl_invalid++;
      return Entry_MakeNone("wave5: structural SL fails broker stops-level check");
   }

   // valid signal: latch, publish anchors, emit.
   g_w5_n_signalled++;
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
