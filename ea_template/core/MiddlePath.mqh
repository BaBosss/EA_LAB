//+------------------------------------------------------------------+
//| MiddlePath.mqh (V2) - AAM Module 2: Middle Path Veto. Not an entry|
//| system - a NEW-ENTRY veto: when price sits between two structural |
//| lines with no clear side to reference for SL/target, there is no  |
//| edge to trade against, so no new (flat) entry is allowed. Additive|
//| and OFF by default (UseMiddlePathVeto=false).                     |
//|                                                                    |
//| Line source is selectable (_MID_LineSource, 2026-08-12 session     |
//| decision - the chassis had no existing line-detection engine):    |
//|   MID_LINES_DONCHIAN - rolling highest-high/lowest-low as the 2    |
//|     channel bounds (fast, always-computable, matches SL_STRUCT_    |
//|     DONCHIAN's own indicators - no touch-counting).                |
//|   MID_LINES_PIVOT    - real multi-touch swing-pivot Line Engine    |
//|     per spec 2.2 (LineNode: price/touches/last_touch/tf_origin/    |
//|     weight), scoped to a SINGLE timeframe (_Period) in this order -|
//|     the spec's tf_origin field is populated but multi-TF merging   |
//|     is not built here.                                             |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_MIDDLEPATH_MQH
#define BOSS_LAB_MIDDLEPATH_MQH
#include "Inputs.mqh"
#include "Indicators.mqh"
#include "ExitManager.mqh"   // Exit_InitialSL() - only used by the opt-in 2.5 room/RR check

struct LineNode
{
   double   price;
   int      touches;
   datetime last_touch;
   int      tf_origin;
   double   weight;
};

struct SpaceState
{
   double line_above, line_below;
   double space_up, space_down;
   double position_ratio;
   bool   in_middle_path;
   bool   valid;
};

LineNode g_mid_lines[];
datetime g_mid_lines_bar       = 0;
bool     g_mid_lines_has_cache = false;

//==================== Line sources ===================================
bool MidPath_IsPivotHigh(const int shift, const int depth)
{
   double h = iHigh(_Symbol, _Period, shift);
   if(h <= 0.0) return false;
   for(int i = 1; i <= depth; i++)
   {
      if(iHigh(_Symbol, _Period, shift - i) >= h) return false;
      if(iHigh(_Symbol, _Period, shift + i) >= h) return false;
   }
   return true;
}

bool MidPath_IsPivotLow(const int shift, const int depth)
{
   double l = iLow(_Symbol, _Period, shift);
   if(l <= 0.0) return false;
   for(int i = 1; i <= depth; i++)
   {
      if(iLow(_Symbol, _Period, shift - i) <= l) return false;
      if(iLow(_Symbol, _Period, shift + i) <= l) return false;
   }
   return true;
}

int MidPath_FindNear(const LineNode &lines[], const int count, const double price, const double bucket)
{
   for(int i = 0; i < count; i++)
      if(MathAbs(lines[i].price - price) <= bucket) return i;
   return -1;
}

// merges a fresh pivot touch into the nearest existing line (within `bucket` price
// units) or creates a new LineNode. weight = touches (single-TF scope - see file
// header; the spec's "+ tf" half of the weight formula needs multi-TF scanning this
// order does not build).
void MidPath_AddTouch(LineNode &lines[], int &count, const double price, const datetime t,
                       const double bucket, const int maxLines)
{
   int idx = MidPath_FindNear(lines, count, price, bucket);
   if(idx >= 0)
   {
      lines[idx].price      = (lines[idx].price * lines[idx].touches + price) / (lines[idx].touches + 1);
      lines[idx].touches++;
      lines[idx].last_touch = t;
      lines[idx].weight     = (double)lines[idx].touches;
      return;
   }
   if(count >= maxLines) return;   // cap reached - drop the touch rather than grow unbounded
   ArrayResize(lines, count + 1);
   lines[count].price      = price;
   lines[count].touches    = 1;
   lines[count].last_touch = t;
   lines[count].tf_origin  = (int)_Period;
   lines[count].weight     = 1.0;
   count++;
}

void MidPath_BuildPivotLines()
{
   int count = 0;
   ArrayResize(g_mid_lines, 0);

   double atrPts = Indi_ATR_Points(0);
   double pt     = Indi_Point();
   double bucket = MathMax(atrPts * _MID_ClusterATRmult, 1.0) * pt;   // degenerate-ATR guard: never a 0/negative bucket

   int depth    = MathMax(_MID_PivotDepth, 1);
   int lookback = MathMax(_MID_LineLookbackBars, depth * 2 + 1);
   int maxLines = MathMax(_MID_MaxLines, 1);

   for(int s = depth; s < lookback + depth; s++)
   {
      datetime t = iTime(_Symbol, _Period, s);
      if(t <= 0) break;   // ran out of history
      if(MidPath_IsPivotHigh(s, depth))
         MidPath_AddTouch(g_mid_lines, count, iHigh(_Symbol, _Period, s), t, bucket, maxLines);
      if(MidPath_IsPivotLow(s, depth))
         MidPath_AddTouch(g_mid_lines, count, iLow(_Symbol, _Period, s), t, bucket, maxLines);
   }
}

void MidPath_BuildDonchianLines()
{
   ArrayResize(g_mid_lines, 2);
   double hi = Indi_HighestHigh(MathMax(_MID_DonchianBars, 1), 1);
   double lo = Indi_LowestLow(MathMax(_MID_DonchianBars, 1), 1);
   datetime t = iTime(_Symbol, _Period, 1);

   g_mid_lines[0].price = hi; g_mid_lines[0].touches = 1; g_mid_lines[0].last_touch = t;
   g_mid_lines[0].tf_origin = (int)_Period; g_mid_lines[0].weight = 1.0e6;   // channel bound, not touch-counted - always clears MIN_LINE_WEIGHT
   g_mid_lines[1].price = lo; g_mid_lines[1].touches = 1; g_mid_lines[1].last_touch = t;
   g_mid_lines[1].tf_origin = (int)_Period; g_mid_lines[1].weight = 1.0e6;
}

// cached per closed bar (same pattern as Regime_Current()) - rebuilding the pivot
// scan every tick would be wasteful and the Donchian proxy is already bar-stable.
void MidPath_RefreshLines()
{
   datetime barT = iTime(_Symbol, _Period, 0);
   if(g_mid_lines_has_cache && barT == g_mid_lines_bar) return;
   g_mid_lines_bar      = barT;
   g_mid_lines_has_cache = true;
   if(_MID_LineSource == MID_LINES_PIVOT) MidPath_BuildPivotLines();
   else                                   MidPath_BuildDonchianLines();
}

//==================== Core space calc (AAM spec 2.3) =================
SpaceState MidPath_CalcSpace(const double price)
{
   SpaceState s;
   s.line_above = DBL_MAX;
   s.line_below = -DBL_MAX;
   s.space_up = 0.0; s.space_down = 0.0; s.position_ratio = 0.5;
   s.in_middle_path = false; s.valid = false;

   double atr = Indi_ATR(0);
   if(atr <= 0.0) return s;   // no ATR yet -> cannot normalize; "don't know" must not veto

   int n = ArraySize(g_mid_lines);
   for(int i = 0; i < n; i++)
   {
      if(g_mid_lines[i].weight < MIN_LINE_WEIGHT) continue;   // weak line - not trusted as a boundary
      if(g_mid_lines[i].price > price && g_mid_lines[i].price < s.line_above) s.line_above = g_mid_lines[i].price;
      if(g_mid_lines[i].price < price && g_mid_lines[i].price > s.line_below) s.line_below = g_mid_lines[i].price;
   }

   // edge case: outside every known line (breakout past the mapped structure) -
   // per spec 2.3, do not veto here; let other modules judge a breakout.
   if(s.line_above >= DBL_MAX || s.line_below <= -DBL_MAX)
   {
      s.valid = false;
      s.in_middle_path = false;
      return s;
   }

   s.space_up   = (s.line_above - price) / atr;
   s.space_down = (price - s.line_below) / atr;

   // edge case: the two lines are too close together to have room to run - a
   // compression zone, which per spec 2.3 DOES veto (unlike the outside-lines case).
   if(s.space_up + s.space_down < MIN_CHANNEL_ATR)
   {
      s.valid = false;
      s.in_middle_path = true;
      return s;
   }

   s.position_ratio = s.space_down / (s.space_up + s.space_down);
   s.in_middle_path = (s.position_ratio > MID_LOW && s.position_ratio < MID_HIGH);
   s.valid = true;
   return s;
}

//==================== Entry gate (AAM spec 2.4 + optional 2.5) =======
// direction: 0=NONE 1=BUY 2=SELL (matches EntrySignal.direction, IEntry.mqh).
bool MiddlePath_AllowEntry(const int direction)
{
   if(!UseMiddlePathVeto) return true;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol, t)) return true;   // no tick data -> fail-open, cannot evaluate
   double price = (direction == 1 ? t.ask : (direction == 2 ? t.bid : (t.bid + t.ask) / 2.0));

   MidPath_RefreshLines();
   SpaceState sp = MidPath_CalcSpace(price);

   if(sp.in_middle_path)
   {
      PrintFormat("[MIDPATH] veto MIDDLE_PATH ratio=%.3f src=%d", sp.position_ratio, (int)_MID_LineSource);
      return false;
   }

   // spec 2.5 (opt-in, default off): also require enough room to the boundary to
   // clear MinRR x the prospective SL distance for THIS direction.
   if(_MID_UseRoomCheck && sp.valid && (direction == 1 || direction == 2))
   {
      double slPrice = Exit_InitialSL(direction, price);
      if(slPrice > 0.0)
      {
         double slDist = MathAbs(price - slPrice);
         double room   = (direction == 1 ? (sp.line_above - price) : (price - sp.line_below));
         if(slDist > 0.0 && room < slDist * _MID_MinRR)
         {
            PrintFormat("[MIDPATH] veto ROOM_RR room=%.5f need=%.5f (slDist=%.5f x MinRR=%.2f)",
                        room, slDist * _MID_MinRR, slDist, _MID_MinRR);
            return false;
         }
      }
   }
   return true;
}

#endif // BOSS_LAB_MIDDLEPATH_MQH
