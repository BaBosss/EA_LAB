//+------------------------------------------------------------------+
//| Wave5Swings.mqh (ORDER-082, LAB_ENTRY_17) - confirmed-swing       |
//| detector from built-in fractals (iHigh/iLow). No iCustom, no      |
//| external ZigZag - repaint-free: newest usable pivot is always     |
//| >= fractalDepth bars back (confirmed on both sides).              |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_WAVE5SWINGS_MQH
#define BOSS_LAB_WAVE5SWINGS_MQH
#ifdef LAB_ENTRY_17

struct Swing
{
   double   price;
   datetime time;
   int      barShift;
   bool     isHigh;
};

// A shift `s` is a confirmed fractal high/low when it is the extreme of the
// window [s-fractalDepth .. s+fractalDepth] (both sides closed - no repaint,
// since we only ever look at shift >= fractalDepth from "now").
bool Wave5_IsFractalHigh(const int shift, const int fractalDepth)
{
   double center = iHigh(_Symbol, _Period, shift);
   for(int k = 1; k <= fractalDepth; k++)
   {
      if(iHigh(_Symbol, _Period, shift - k) > center) return false; // newer bar higher
      if(iHigh(_Symbol, _Period, shift + k) > center) return false; // older bar higher
   }
   return true;
}

bool Wave5_IsFractalLow(const int shift, const int fractalDepth)
{
   double center = iLow(_Symbol, _Period, shift);
   for(int k = 1; k <= fractalDepth; k++)
   {
      if(iLow(_Symbol, _Period, shift - k) < center) return false;
      if(iLow(_Symbol, _Period, shift + k) < center) return false;
   }
   return true;
}

// Collect the most recent confirmed alternating pivots, newest first.
// Scan starts at shift = fractalDepth (the newest shift that can possibly be
// confirmed - needs fractalDepth NEWER bars closed on its right) and walks
// backward in time (increasing shift) until maxSwings collected or history
// runs out. Consecutive same-type raw fractals collapse to the more extreme
// one before alternation is enforced.
int Wave5_CollectSwings(Swing &out[], const int maxSwings, const int fractalDepth)
{
   ArrayResize(out, 0);
   if(maxSwings <= 0 || fractalDepth <= 0) return 0;

   int bars = Bars(_Symbol, _Period);
   int maxShift = bars - fractalDepth - 1;
   if(maxShift < fractalDepth) return 0;

   // raw pass: walk from newest confirmable shift outward, collapsing
   // consecutive same-type pivots (keep the more extreme).
   Swing raw[];
   ArrayResize(raw, 0);
   int rawCount = 0;
   int scanCap = MathMin(maxShift, 5000); // sanity cap on lookback depth

   for(int s = fractalDepth; s <= scanCap; s++)
   {
      bool isH = Wave5_IsFractalHigh(s, fractalDepth);
      bool isL = (!isH && Wave5_IsFractalLow(s, fractalDepth));
      if(!isH && !isL) continue;

      double px = (isH ? iHigh(_Symbol, _Period, s) : iLow(_Symbol, _Period, s));
      datetime tm = iTime(_Symbol, _Period, s);

      if(rawCount > 0 && raw[rawCount - 1].isHigh == isH)
      {
         // same-type run: keep the more extreme pivot
         bool replace = (isH ? (px > raw[rawCount - 1].price) : (px < raw[rawCount - 1].price));
         if(replace)
         {
            raw[rawCount - 1].price    = px;
            raw[rawCount - 1].time     = tm;
            raw[rawCount - 1].barShift = s;
         }
         continue;
      }

      ArrayResize(raw, rawCount + 1);
      raw[rawCount].price    = px;
      raw[rawCount].time     = tm;
      raw[rawCount].barShift = s;
      raw[rawCount].isHigh   = isH;
      rawCount++;

      if(rawCount >= maxSwings + 2) break; // small buffer, alternation already enforced by construction
   }

   int n = MathMin(rawCount, maxSwings);
   ArrayResize(out, n);
   for(int i = 0; i < n; i++) out[i] = raw[i];
   return n;
}

#endif // LAB_ENTRY_17
#endif // BOSS_LAB_WAVE5SWINGS_MQH
