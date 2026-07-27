//+------------------------------------------------------------------+
//| BasketGuard_Core.mqh - the decision half of (Boss)_BasketGuard.  |
//|                                                                  |
//| Everything here is PURE: no terminal calls, no globals, no I/O.  |
//| That is deliberate. The guard's whole job is one comparison, and |
//| a comparison that can only be exercised by blowing up a real     |
//| account is a comparison nobody ever tests. Keeping it pure means |
//| run_tests.ps1 can drive it through the cases that matter -- the  |
//| boundary, the wrong sign, the zero baseline -- at zero risk.     |
//|                                                                  |
//| The terminal half (reading positions, closing them, persisting   |
//| the halt) lives in the .mq5 and is deliberately dumb.            |
//+------------------------------------------------------------------+
#property copyright "EA_LAB"

#define BG_ALERT_THROTTLE_SEC   300

//--- what the guard decided to do on this poll
enum BG_Action
{
   BG_ACTION_NONE = 0,    // basket is fine, or there is no basket
   BG_ACTION_CUT  = 1,    // breach: close every position of the watched magic
   BG_ACTION_HOLD = 2     // already halted: close anything that reappeared
};

//+------------------------------------------------------------------+
//| The loss that trips the guard, as a positive currency amount.    |
//|                                                                  |
//| Returns 0.0 for any nonsensical input (non-positive baseline or  |
//| percentage). 0.0 is read by BG_Decide as "no valid limit" and    |
//| never as "cut at zero loss" -- an invalid config must leave the  |
//| account alone, not liquidate it. That direction is the whole     |
//| reason this returns a sentinel instead of asserting.             |
//+------------------------------------------------------------------+
double BG_LossLimitAbs(const double baseline, const double pct)
{
   if(baseline <= 0.0) return 0.0;
   if(pct      <= 0.0) return 0.0;
   if(pct      >  90.0) return 0.0;   // refuse to arm a limit that cannot save the account
   return baseline * pct / 100.0;
}

//+------------------------------------------------------------------+
//| The one decision.                                                |
//|                                                                  |
//| floatingPL is signed as MT5 reports it: negative = losing.       |
//| limitAbs is positive. We breach when the loss is at least the    |
//| limit, i.e. floatingPL <= -limitAbs.                             |
//|                                                                  |
//| halted=true short-circuits to HOLD whenever positions exist,     |
//| regardless of P/L.                                               |
//|                                                                  |
//| HOLD IS CONTAINMENT, NOT PREVENTION. Nothing here can stop a     |
//| closed-source EA from opening a position; the guard only notices |
//| afterwards and closes it, up to InpTimerSeconds late. Against an |
//| EA that re-enters immediately this becomes an open/close churn   |
//| that pays the spread every cycle and never ends on its own. The  |
//| reentries counter exists so that churn shows up in the status    |
//| file instead of quietly draining the account. Only taking the EA |
//| off its chart actually stops it, and that is a human step -- so  |
//| the halt escalates loudly rather than pretending it is handled.  |
//+------------------------------------------------------------------+
BG_Action BG_Decide(const int positions, const double floatingPL,
                    const double limitAbs, const bool halted)
{
   if(positions <= 0) return BG_ACTION_NONE;
   if(halted)         return BG_ACTION_HOLD;
   if(limitAbs <= 0.0) return BG_ACTION_NONE;   // invalid/unarmed limit: do nothing
   if(floatingPL <= -limitAbs) return BG_ACTION_CUT;
   return BG_ACTION_NONE;
}

//+------------------------------------------------------------------+
//| How close the basket is to the limit, 0..100+ percent.           |
//| Only used for logging, but it is the number that makes a         |
//| heartbeat readable: "37% of the way to the cut" beats a raw P/L  |
//| nobody can scale in their head.                                  |
//+------------------------------------------------------------------+
double BG_UsagePct(const double floatingPL, const double limitAbs)
{
   if(limitAbs <= 0.0) return 0.0;
   if(floatingPL >= 0.0) return 0.0;
   return (-floatingPL) / limitAbs * 100.0;
}

//+------------------------------------------------------------------+
//| One CSV line for the monitoring chain.                           |
//|                                                                  |
//| checks and fires are cumulative counters. fires is the field     |
//| that matters: the doctrine bar says a guard reporting zero       |
//| firings is UNTESTED, not proven safe, and a guard that cannot    |
//| report its own firing count cannot be held to that bar at all.   |
//+------------------------------------------------------------------+
//| The state word is NOT derived from the halt flag alone. A cut that
//| left positions behind -- AutoTrading off, trade context busy, market
//| closed -- must never report HALTED, because a monitoring chain reading
//| this file would take HALTED to mean the basket is gone. It is the
//| difference between "contained" and "we tried and failed", and only one
//| of those needs a human tonight.
string BG_State(const bool halted, const int positionsLeft)
{
   if(halted && positionsLeft > 0) return "CUT_FAILED";
   if(halted)                      return "HALTED";
   return "ARMED";
}

string BG_StatusLine(const datetime stamp, const long magic, const int positions,
                     const double floatingPL, const double limitAbs,
                     const bool halted, const bool dryRun,
                     const long checks, const long fires, const long reentries)
{
   return StringFormat("%s,%I64d,%d,%.2f,%.2f,%.1f,%s,%s,%I64d,%I64d,%I64d",
                       TimeToString(stamp, TIME_DATE|TIME_SECONDS),
                       magic, positions, floatingPL, limitAbs,
                       BG_UsagePct(floatingPL, limitAbs),
                       BG_State(halted, positions),
                       (dryRun ? "DRYRUN" : "LIVE"),
                       checks, fires, reentries);
}

string BG_StatusHeader()
{
   return "stamp,magic,positions,floating_pl,limit_abs,usage_pct,state,mode,checks,fires,reentries";
}
