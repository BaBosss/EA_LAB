// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file core/SignedVolatility.mqh
// sha256 6ee2d3b087b3c3f38bb49fb76a03919bd5ac2d08560c2f2addb562e7be37d18c; used only by Entry_TrendRider (build 27). Logic unchanged.
//+------------------------------------------------------------------+
//| SignedVolatility.mqh (V2 - Hardened)                             |
//| Based on Second Brain research RC-DOI-RESTA00503-001 & HYP-SB-004|
//| Decomposes intraday returns into Upside (RSV+) and Downside      |
//| (RSV-) semivariance to detect jump asymmetry & panic liquidation.|
//|                                                                  |
//| Hardened per Codex Independent Architecture Review 2026-10-19:   |
//| 1. Full cache key: (symbol, tf, lookback, threshold, bar_time)   |
//| 2. Epsilon aligned to 1e-12                                      |
//| 3. Sizing uses inverse volatility (sqrt of variance ratio)       |
//| 4. Data errors fail closed for new exposure when enabled         |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_SIGNED_VOLATILITY_MQH
#define BOSS_LAB_SIGNED_VOLATILITY_MQH

enum ENUM_SIGNED_VOL_REGIME
{
   SVOL_BALANCED = 0,        // Symmetric diffusion (|VAR| <= threshold)
   SVOL_DOWNSIDE_JUMP = 1,   // Heavy downside panic selling (VAR > +threshold)
   SVOL_UPSIDE_SQUEEZE = 2,  // Rapid upside squeeze (VAR < -threshold)
   SVOL_DATA_ERROR = 3       // Missing or corrupt history data
};

struct SignedVolatilityState
{
   // Cache key dimensions
   string                  cached_symbol;
   ENUM_TIMEFRAMES         cached_tf;
   int                     cached_lookback;
   double                  cached_threshold;
   datetime                cached_bar_time;

   // Computed outputs
   double                  rsv_plus;
   double                  rsv_minus;
   double                  total_variance;
   double                  asymmetry_ratio;
   ENUM_SIGNED_VOL_REGIME  regime;
   bool                    is_valid;
   bool                    is_error;
};

// Global cache per execution instance
SignedVolatilityState g_svol_state;

//+------------------------------------------------------------------+
//| Reset Cache State                                                |
//+------------------------------------------------------------------+
void SignedVol_Reset()
{
   g_svol_state.cached_symbol = "";
   g_svol_state.cached_tf = PERIOD_CURRENT;
   g_svol_state.cached_lookback = 0;
   g_svol_state.cached_threshold = 0.0;
   g_svol_state.cached_bar_time = 0;

   g_svol_state.rsv_plus = 0.0;
   g_svol_state.rsv_minus = 0.0;
   g_svol_state.total_variance = 0.0;
   g_svol_state.asymmetry_ratio = 0.0;
   g_svol_state.regime = SVOL_BALANCED;
   g_svol_state.is_valid = false;
   g_svol_state.is_error = false;
}

//+------------------------------------------------------------------+
//| Core Semivariance Decomposition Function                         |
//+------------------------------------------------------------------+
bool SignedVol_Compute(const string symbol,
                       const ENUM_TIMEFRAMES tf,
                       const int lookback,
                       double &rsv_plus,
                       double &rsv_minus,
                       double &var_ratio,
                       ENUM_SIGNED_VOL_REGIME &regime,
                       const double asymmetry_threshold = 0.25)
{
   rsv_plus = 0.0;
   rsv_minus = 0.0;
   var_ratio = 0.0;
   regime = SVOL_BALANCED;

   if(lookback < 2 || asymmetry_threshold <= 0.0)
   {
      regime = SVOL_DATA_ERROR;
      return false;
   }

   double closes[];
   ArraySetAsSeries(closes, true);
   int needed = lookback + 1;
   int copied = CopyClose(symbol, tf, 1, needed, closes);
   if(copied < needed)
   {
      regime = SVOL_DATA_ERROR;
      return false;
   }

   for(int i = 0; i < lookback; i++)
   {
      double prev = closes[i + 1];
      double curr = closes[i];
      if(prev <= 0.0 || curr <= 0.0)
      {
         regime = SVOL_DATA_ERROR;
         return false;
      }

      double ret = (curr - prev) / prev;
      double ret_sq = ret * ret;

      if(ret > 0.0)
         rsv_plus += ret_sq;
      else if(ret < 0.0)
         rsv_minus += ret_sq;
   }

   double total_var = rsv_plus + rsv_minus;
   if(total_var <= 1e-12)
   {
      var_ratio = 0.0;
      regime = SVOL_BALANCED;
      return true;
   }

   var_ratio = (rsv_minus - rsv_plus) / total_var;

   if(var_ratio > asymmetry_threshold)
      regime = SVOL_DOWNSIDE_JUMP;
   else if(var_ratio < -asymmetry_threshold)
      regime = SVOL_UPSIDE_SQUEEZE;
   else
      regime = SVOL_BALANCED;

   return true;
}

//+------------------------------------------------------------------+
//| Robust Cache Key Validation & Update                             |
//+------------------------------------------------------------------+
bool SignedVol_UpdateCache(const string symbol,
                           const ENUM_TIMEFRAMES tf,
                           const int lookback,
                           const double asymmetry_threshold = 0.25)
{
   datetime current_bar = iTime(symbol, tf, 0);

   // Full composite cache key check: must match all 5 dimensions
   if(g_svol_state.is_valid &&
      !g_svol_state.is_error &&
      g_svol_state.cached_bar_time == current_bar &&
      g_svol_state.cached_symbol == symbol &&
      g_svol_state.cached_tf == tf &&
      g_svol_state.cached_lookback == lookback &&
      MathAbs(g_svol_state.cached_threshold - asymmetry_threshold) < 1e-6)
   {
      return true;
   }

   double r_plus = 0.0, r_minus = 0.0, v_ratio = 0.0;
   ENUM_SIGNED_VOL_REGIME reg = SVOL_BALANCED;

   bool ok = SignedVol_Compute(symbol, tf, lookback, r_plus, r_minus, v_ratio, reg, asymmetry_threshold);

   // Populate full cache state
   g_svol_state.cached_symbol = symbol;
   g_svol_state.cached_tf = tf;
   g_svol_state.cached_lookback = lookback;
   g_svol_state.cached_threshold = asymmetry_threshold;
   g_svol_state.cached_bar_time = current_bar;

   if(!ok)
   {
      g_svol_state.is_valid = false;
      g_svol_state.is_error = true;
      g_svol_state.regime = SVOL_DATA_ERROR;
      return false;
   }

   g_svol_state.rsv_plus = r_plus;
   g_svol_state.rsv_minus = r_minus;
   g_svol_state.total_variance = r_plus + r_minus;
   g_svol_state.asymmetry_ratio = v_ratio;
   g_svol_state.regime = reg;
   g_svol_state.is_valid = true;
   g_svol_state.is_error = false;
   return true;
}

//+------------------------------------------------------------------+
//| Directional Gate: Checks if new LONG entry is permitted          |
//| When enabled, data errors fail closed (returns false)            |
//+------------------------------------------------------------------+
bool SignedVol_AllowsLong(const string symbol,
                          const ENUM_TIMEFRAMES tf,
                          const int lookback = 20,
                          const double asymmetry_threshold = 0.25,
                          const bool enabled = true)
{
   if(!enabled) return true; // Disabled mode is inert pass-through

   if(!SignedVol_UpdateCache(symbol, tf, lookback, asymmetry_threshold))
      return false; // Fail-closed on missing data or corrupt bars

   if(g_svol_state.regime == SVOL_DOWNSIDE_JUMP || g_svol_state.regime == SVOL_DATA_ERROR)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Directional Gate: Checks if new SHORT entry is permitted         |
//| When enabled, data errors fail closed (returns false)            |
//+------------------------------------------------------------------+
bool SignedVol_AllowsShort(const string symbol,
                           const ENUM_TIMEFRAMES tf,
                           const int lookback = 20,
                           const double asymmetry_threshold = 0.25,
                           const bool enabled = true)
{
   if(!enabled) return true;

   if(!SignedVol_UpdateCache(symbol, tf, lookback, asymmetry_threshold))
      return false;

   if(g_svol_state.regime == SVOL_UPSIDE_SQUEEZE || g_svol_state.regime == SVOL_DATA_ERROR)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Dynamic Lot Scale Factor based on Inverse-Volatility             |
//| Uses square-root of variance ratio (true inverse volatility)     |
//+------------------------------------------------------------------+
double SignedVol_GetLotScale(const string symbol,
                             const ENUM_TIMEFRAMES tf,
                             const int lookback = 20,
                             const double baseline_variance = 0.0001,
                             const bool enabled = true)
{
   if(!enabled) return 1.0;

   if(!SignedVol_UpdateCache(symbol, tf, lookback, 0.25))
      return 1.0;

   if(baseline_variance <= 1e-12 || g_svol_state.total_variance <= baseline_variance)
      return 1.0;

   // Aligned to true inverse volatility: sqrt(baseline_var / current_var)
   double factor = MathSqrt(baseline_variance / g_svol_state.total_variance);
   return MathMax(0.20, MathMin(1.0, factor));
}

#endif // BOSS_LAB_SIGNED_VOLATILITY_MQH
