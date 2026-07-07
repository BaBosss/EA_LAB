//+------------------------------------------------------------------+
//| STANDALONE_RISK_BUNDLE.mqh                                       |
//|                                                                  |
//| Lightweight risk management for standalone EAs — the two best    |
//| assets of EA_CORE_V1 (RiskEngine + LotSizer) ported into ONE     |
//| self-contained include, WITHOUT the 24-module framework chain.   |
//|                                                                  |
//| Provides:                                                        |
//|   - broker-aware lot normalization (reads SYMBOL_VOLUME_MIN/MAX/STEP)
//|   - hard max-lot SAFETY cap (tighter than broker max)            |
//|   - halt flags (freeze trading on a risk event)                  |
//|   - progressive step-on-loss sizing with max-legs cap            |
//|     + mandatory halt-freeze guard (never compound through a halt)|
//|                                                                  |
//| Functions are prefixed SRB_ to avoid clashing with the real      |
//| framework's Risk_/LotSizer_ names. No file I/O, no diagnostics   |
//| chain — logging is optional Print() gated by SRB_SetVerbose().   |
//|                                                                  |
//| USAGE in a standalone EA:                                        |
//|   #include "STANDALONE_RISK_BUNDLE.mqh"                          |
//|   // OnInit:                                                      |
//|     SRB_Init(_Symbol, /*max_lot_cap*/ 0.10);                     |
//|     SRB_SetVerbose(!g_suppress_log);                             |
//|     SRB_LotSizerInit(/*base*/0.01,/*step*/0.01,/*max*/0.10,     |
//|                      /*legs*/5,/*mode*/SRB_MODE_STEP_ON_LOSS,    |
//|                      /*onmax*/SRB_ONMAX_FREEZE);                  |
//|   // before an entry:                                            |
//|     if(!SRB_CanTrade(lot)) return;                               |
//|     double lot = SRB_NextLot();                                  |
//|   // after a close:                                              |
//|     SRB_OnResult(was_profit);                                    |
//|                                                                  |
//| Ported verbatim from CORE/RiskEngine_v1.mqh + LotSizer_v1.mqh    |
//| (math unchanged; logging swapped for Print). 2026-06-22.         |
//+------------------------------------------------------------------+
#ifndef __STANDALONE_RISK_BUNDLE_MQH__
#define __STANDALONE_RISK_BUNDLE_MQH__

// --- Halt flags (bitmask) ---
#define SRB_HALT_NONE            0
#define SRB_HALT_TOTAL           1
#define SRB_HALT_MANUAL          2
#define SRB_HALT_SYMBOL_ECON     4

// --- LotSizer modes ---
#define SRB_MODE_FIXED           0   // always base lot (escalation off)
#define SRB_MODE_STEP_ON_LOSS    1   // lot = base + step * loss_streak

// --- On-max behavior ---
#define SRB_ONMAX_FREEZE         0   // hold at max-legs level until a win
#define SRB_ONMAX_RESET          1   // snap streak back to 0

//--------------------------------------------------------------------
// State
//--------------------------------------------------------------------
static bool   g_srb_initialized   = false;
static bool   g_srb_verbose       = false;
static string g_srb_symbol        = "";
static double g_srb_min_lot       = 0.01;
static double g_srb_max_lot       = 0.10;   // SAFETY cap (may be tighter than broker max)
static double g_srb_lot_step      = 0.01;
static int    g_srb_halt_flags    = 0;
static string g_srb_last_reason   = "";

static bool   g_srb_ls_initialized = false;
static int    g_srb_ls_mode        = SRB_MODE_STEP_ON_LOSS;
static int    g_srb_ls_onmax       = SRB_ONMAX_FREEZE;
static double g_srb_ls_base_lot    = 0.01;
static double g_srb_ls_step_lot    = 0.01;
static double g_srb_ls_max_lot     = 0.10;
static int    g_srb_ls_max_legs    = 5;
static int    g_srb_ls_loss_streak = 0;

//--------------------------------------------------------------------
// Internal log helper (Print only when verbose)
//--------------------------------------------------------------------
void _SRB_Log(const string msg)
{
   if(g_srb_verbose) Print("[SRB] ", msg);
}

void SRB_SetVerbose(const bool on) { g_srb_verbose = on; }

//--------------------------------------------------------------------
// Init — reads broker volume constraints for the symbol, applies a
// SAFETY max-lot cap (never above the broker max, never below min).
//--------------------------------------------------------------------
bool SRB_Init(const string symbol, const double max_lot_cap = 0.10)
{
   g_srb_symbol = (symbol == "" ? _Symbol : symbol);

   double broker_min  = SymbolInfoDouble(g_srb_symbol, SYMBOL_VOLUME_MIN);
   double broker_max  = SymbolInfoDouble(g_srb_symbol, SYMBOL_VOLUME_MAX);
   double broker_step = SymbolInfoDouble(g_srb_symbol, SYMBOL_VOLUME_STEP);

   g_srb_min_lot  = (broker_min  > 0.0) ? broker_min  : 0.01;
   g_srb_lot_step = (broker_step > 0.0) ? broker_step : 0.01;

   // Safety cap = the tighter of (caller cap, broker max). Never below min.
   double cap = (max_lot_cap > 0.0) ? max_lot_cap : g_srb_min_lot;
   if(broker_max > 0.0 && cap > broker_max) cap = broker_max;
   if(cap < g_srb_min_lot) cap = g_srb_min_lot;
   g_srb_max_lot = cap;

   g_srb_halt_flags  = 0;
   g_srb_last_reason = "";
   g_srb_initialized = true;
   _SRB_Log(StringFormat("init %s min=%.2f max(cap)=%.2f step=%.2f",
            g_srb_symbol, g_srb_min_lot, g_srb_max_lot, g_srb_lot_step));
   return true;
}

bool SRB_IsReady()      { return g_srb_initialized; }
int  SRB_HaltFlags()    { return g_srb_halt_flags; }
bool SRB_IsHalted()     { return (g_srb_halt_flags != 0); }
bool SRB_HasHalt(const int flag) { return ((g_srb_halt_flags & flag) == flag); }
string SRB_LastReason() { return g_srb_last_reason; }

void SRB_SetHalt(const int flags, const string reason = "")
{
   g_srb_halt_flags  = (g_srb_halt_flags | flags);
   g_srb_last_reason = reason;
   _SRB_Log("HALT set flags=" + IntegerToString(flags) + " " + reason);
}

void SRB_ClearAllHalts()
{
   g_srb_halt_flags  = 0;
   g_srb_last_reason = "";
   _SRB_Log("halts cleared");
}

//--------------------------------------------------------------------
// Lot normalization (verbatim math from Risk_NormalizeLot)
//   - below min        → 0.0 (reject)
//   - above max(cap)   → clamped to cap
//   - snapped DOWN to the nearest step from min
//--------------------------------------------------------------------
int _SRB_LotDigits(const double step)
{
   double s = step; int d = 0;
   while(s < 1.0 && d < 8) { s *= 10.0; d++; }
   return d;
}

double SRB_NormalizeLot(const double lot)
{
   const double vmin = g_srb_min_lot, vmax = g_srb_max_lot, vstep = g_srb_lot_step;
   if(lot <= 0.0 || vmin <= 0.0 || vmax < vmin || vstep <= 0.0) return 0.0;
   if(lot < vmin) return 0.0;

   double bounded = lot;
   if(bounded > vmax) bounded = vmax;

   const double steps = MathFloor((bounded - vmin) / vstep + 0.0000001);
   const double norm  = vmin + (steps * vstep);
   return NormalizeDouble(norm, _SRB_LotDigits(vstep));
}

// True only if initialized, not halted, and the requested lot normalizes > 0.
bool SRB_CanTrade(const double requested_lot)
{
   if(!g_srb_initialized) return false;
   if(SRB_IsHalted())     return false;
   return (SRB_NormalizeLot(requested_lot) > 0.0);
}

//====================================================================
// LotSizer — progressive step-on-loss (verbatim from LotSizer_v1)
//====================================================================
bool SRB_LotSizerInit(const double base_lot = 0.01,
                      const double step_lot = 0.01,
                      const double max_lot  = 0.10,
                      const int    max_legs = 5,
                      const int    mode     = SRB_MODE_STEP_ON_LOSS,
                      const int    on_max   = SRB_ONMAX_FREEZE)
{
   g_srb_ls_base_lot = (base_lot > 0.0)  ? base_lot : 0.01;
   g_srb_ls_step_lot = (step_lot >= 0.0) ? step_lot : 0.01;
   // Cap can never sit below base, or entries silently zero out.
   g_srb_ls_max_lot  = (max_lot >= g_srb_ls_base_lot) ? max_lot : g_srb_ls_base_lot;
   g_srb_ls_max_legs = (max_legs >= 1) ? max_legs : 1;
   g_srb_ls_mode     = (mode == SRB_MODE_FIXED) ? SRB_MODE_FIXED : SRB_MODE_STEP_ON_LOSS;
   g_srb_ls_onmax    = (on_max == SRB_ONMAX_RESET) ? SRB_ONMAX_RESET : SRB_ONMAX_FREEZE;
   g_srb_ls_loss_streak = 0;
   g_srb_ls_initialized = true;
   _SRB_Log(StringFormat("lotsizer init base=%.2f step=%.2f max=%.2f legs=%d mode=%d",
            g_srb_ls_base_lot, g_srb_ls_step_lot, g_srb_ls_max_lot, g_srb_ls_max_legs, g_srb_ls_mode));
   return true;
}

int  SRB_LossStreak() { return g_srb_ls_loss_streak; }
void SRB_LotSizerReset() { g_srb_ls_loss_streak = 0; }

int SRB_CurrentLevel()
{
   if(g_srb_ls_mode == SRB_MODE_FIXED) return 0;
   int lvl = g_srb_ls_loss_streak;
   if(lvl > g_srb_ls_max_legs) lvl = g_srb_ls_max_legs;
   return lvl;
}

double _SRB_RawLot(const int loss_streak)
{
   if(g_srb_ls_mode == SRB_MODE_FIXED) return g_srb_ls_base_lot;
   int lvl = loss_streak;
   if(lvl < 0) lvl = 0;
   if(lvl > g_srb_ls_max_legs) lvl = g_srb_ls_max_legs;
   double lot = g_srb_ls_base_lot + (g_srb_ls_step_lot * lvl);
   if(lot > g_srb_ls_max_lot) lot = g_srb_ls_max_lot;   // hard cap
   return lot;
}

// Volume for the next entry. Guards in order:
//   1. not ready / fixed mode → base (normalized)
//   2. halted                 → base only (escalation frozen, never compounded)
//   3. progressive            → base + step*level, capped by max_lot AND max_legs
//   4. broker normalize       → final min/step/max authority
double SRB_NextLot()
{
   if(!g_srb_ls_initialized) return 0.0;

   if(g_srb_ls_mode == SRB_MODE_FIXED)
      return SRB_NormalizeLot(g_srb_ls_base_lot);

   if(SRB_IsHalted())
   {
      _SRB_Log("escalation frozen by halt → base lot");
      return SRB_NormalizeLot(g_srb_ls_base_lot);
   }

   return SRB_NormalizeLot(_SRB_RawLot(g_srb_ls_loss_streak));
}

// Report a closed trade. Win resets streak; loss escalates one leg (bounded).
void SRB_OnResult(const bool was_profit)
{
   if(!g_srb_ls_initialized) return;

   if(was_profit)
   {
      if(g_srb_ls_loss_streak != 0) _SRB_Log("win → streak reset");
      g_srb_ls_loss_streak = 0;
      return;
   }

   if(g_srb_ls_loss_streak < g_srb_ls_max_legs)
   {
      g_srb_ls_loss_streak++;
   }
   else if(g_srb_ls_onmax == SRB_ONMAX_RESET)
   {
      g_srb_ls_loss_streak = 0;
      _SRB_Log("max legs → streak reset");
   }
   else
   {
      _SRB_Log("max legs → lot frozen");
   }
}

#endif // __STANDALONE_RISK_BUNDLE_MQH__
