//+------------------------------------------------------------------+
//| StopsLevel_Probe.mq5 - ORDER-950 route 1. READ-ONLY, opens nothing.|
//|                                                                   |
//| THE QUESTION. Guard G4 (Wave5_SLValid, ExitManager.mqh:25-41) has  |
//| been observed firing ZERO times across every run so far. Its       |
//| minimum-distance branch refuses a structural SL closer to the      |
//| market than SYMBOL_TRADE_STOPS_LEVEL. Whether that branch is even  |
//| REACHABLE at the shipped _17_SLbufferATR=0.5 is a question about   |
//| two numbers this broker publishes, and nothing had read them.      |
//|                                                                   |
//| It prints the stops level, the freeze level, the point size and a  |
//| running ATR, so the comparison is made against measured values     |
//| rather than against an assumption about "typical" XAUUSD spreads.  |
//| ORDER-950 route 1 explicitly prefers this to route 3 (forcing the  |
//| guard with an unrealistic buffer), because route 3 proves the code |
//| path is live and says nothing about deployment risk.               |
//+------------------------------------------------------------------+
#property strict

input int    _probe_AtrPeriod = 14;
input ENUM_TIMEFRAMES _probe_TF = PERIOD_H1;

int    g_atr   = INVALID_HANDLE;
bool   g_done  = false;
double g_minAtr = 0.0, g_maxAtr = 0.0, g_sumAtr = 0.0;
int    g_nAtr  = 0;

int OnInit()
  {
   g_atr = iATR(_Symbol, _probe_TF, _probe_AtrPeriod);
   if(g_atr == INVALID_HANDLE)
     {
      Print("[PROBE] FATAL: iATR handle failed");
      return(INIT_FAILED);
     }
   long stops  = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freeze = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double pt   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dig   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double spr   = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   PrintFormat("[PROBE] symbol=%s digits=%d point=%.10f", _Symbol, dig, pt);
   PrintFormat("[PROBE] SYMBOL_TRADE_STOPS_LEVEL=%d points => minDist=%.5f price units",
               (int)stops, stops * pt);
   PrintFormat("[PROBE] SYMBOL_TRADE_FREEZE_LEVEL=%d points | current spread=%.0f points",
               (int)freeze, spr);
   return(INIT_SUCCEEDED);
  }

void OnTick()
  {
   double a[];
   if(CopyBuffer(g_atr, 0, 1, 1, a) != 1) return;
   double v = a[0];
   if(v <= 0.0) return;
   if(g_nAtr == 0 || v < g_minAtr) g_minAtr = v;
   if(v > g_maxAtr) g_maxAtr = v;
   g_sumAtr += v;
   g_nAtr++;
  }

void OnDeinit(const int reason)
  {
   long   stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double pt    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDist = stops * pt;
   if(g_nAtr <= 0)
     {
      Print("[PROBE] no ATR samples collected - nothing to compare");
      return;
     }
   double avg = g_sumAtr / g_nAtr;
   // The shipped buffer. Stated as a literal on purpose: this probe must not depend on
   // Inputs.mqh, so what it compares against is visible in its own output.
   double buffer = 0.5;
   // "samples", not "bars": collection is in OnTick, so this counts TICKS. The first run's line
   // said bars and was quoted that way before the miscount was noticed; the min/avg/max were
   // right, the noun was not, and a wrong noun on a right number is how a number gets re-used
   // for a question it cannot answer.
   PrintFormat("[PROBE] ATR(%d,%s) over %d tick samples: min=%.5f avg=%.5f max=%.5f",
               _probe_AtrPeriod, EnumToString(_probe_TF), g_nAtr, g_minAtr, avg, g_maxAtr);
   PrintFormat("[PROBE] shipped _17_SLbufferATR=%.2f => SL sits %.5f..%.5f from the invalidation level",
               buffer, buffer * g_minAtr, buffer * g_maxAtr);
   PrintFormat("[PROBE] broker minDist=%.5f | ratio smallestBuffer/minDist=%s",
               minDist,
               (minDist > 0.0 ? DoubleToString(buffer * g_minAtr / minDist, 2) : "n/a (stops level 0)"));
   if(minDist <= 0.0)
      Print("[PROBE] VERDICT: stops level is 0 on this feed, so the minimum-distance branch of "
            "Wave5_SLValid CANNOT fire here at any buffer. Only the wrong-side branch can.");
   else if(buffer * g_minAtr > minDist)
      PrintFormat("[PROBE] VERDICT: even the SMALLEST buffered distance (%.5f) exceeds minDist "
                  "(%.5f), so the minimum-distance branch is unreachable at the shipped buffer "
                  "unless price gaps onto a fresh invalidation level.", buffer * g_minAtr, minDist);
   else
      Print("[PROBE] VERDICT: the buffered distance can fall under minDist, so the branch IS "
            "reachable at the shipped buffer and its zero fire count needs another explanation.");
   Print("[PASS] StopsLevel_Probe: probe executed and emitted verdict");
  }
