//+------------------------------------------------------------------+
//| Entry_ZoneCompressedGrid.mqh - ZCAG Phase A transactional core. |
//| Pure helpers only: deliberately unwired until PARAM_LINKAGE is   |
//| released and a separately accepted Phase B contract exists.     |
//+------------------------------------------------------------------+
#ifndef BOSS_LAB_ENTRY_ZONECOMPRESSEDGRID_MQH
#define BOSS_LAB_ENTRY_ZONECOMPRESSEDGRID_MQH

// BEGIN ZCAG DETERMINISTIC KERNEL
enum ZCAG_HistoryStatus
{
   ZCAG_INVALID_HISTORY=0,
   ZCAG_VALID_NON_PIVOT=1,
   ZCAG_VALID_PIVOT=2
};

enum ZCAG_ApplyStatus
{
   ZCAG_APPLY_INVALID=0,
   ZCAG_APPLY_ALREADY_CONSUMED=1,
   ZCAG_APPLY_COMMITTED=2
};

struct ZCAG_ZResult
{
   bool   valid;
   double value;
};

struct ZCAG_RuntimeState
{
   datetime regime_bar_time;
   datetime decision_bar_time;
   long     decision_bar_ordinal;
   bool     bull;
   bool     ladder_armed;
   bool     step_frozen;
   double   anchor;
   double   step;
   int      reached;
   int      bars_since_touch;
};

struct ZCAG_RegimeSnapshot
{
   datetime bar_time;
   bool     close_read;
   bool     middle_read;
   bool     upper_read;
   double   close1;
   double   middle;
   double   upper;
};

#define ZCAG_MAX_SNAPSHOT_BARS 128
struct ZCAG_DecisionSnapshot
{
   datetime bar_time;
   long     decision_bar_ordinal;
   bool     high_read;
   bool     low_read;
   bool     close1_read;
   bool     close2_read;
   bool     step_atr_read;
   bool     structure_atr_read;
   bool     z_history_read;
   bool     structure_history_read;
   double   high1;
   double   low1;
   double   close1;
   double   close2;
   double   step_atr;
   double   structure_atr;
   int      z_count;
   double   z_closes[ZCAG_MAX_SNAPSHOT_BARS];
   int      structure_count;
   double   structure_lows[ZCAG_MAX_SNAPSHOT_BARS];
};

struct ZCAG_DecisionConfig
{
   double step_atr_mult;
   int    min_levels;
   int    max_levels;
   int    expiry_bars;
   int    pivot_left;
   int    pivot_right;
   double break_atr_mult;
   double zone_atr_width;
   double z_threshold;
};

bool ZCAG_FinitePositive(const double value)
{
   return (MathIsValidNumber(value) && value > 0.0);
}

bool ZCAG_ExposureInvariant(const double base_lot,const int max_levels,
                            const double max_exposure)
{
   if(!ZCAG_FinitePositive(base_lot) || max_levels <= 0 ||
      !ZCAG_FinitePositive(max_exposure)) return false;
   return (max_exposure <= base_lot*max_levels+1.0e-12);
}

double ZCAG_LevelPrice(const double anchor,const double step,const int level)
{
   if(!MathIsValidNumber(anchor) || !ZCAG_FinitePositive(step) || level < 0)
      return 0.0;
   return anchor-step*level;
}

int ZCAG_ReachedLevels(const double anchor,const double step,
                       const double closed_low,const int max_levels)
{
   if(!MathIsValidNumber(anchor) || !ZCAG_FinitePositive(step) ||
      !MathIsValidNumber(closed_low) || max_levels <= 0) return 0;
   double depth=(anchor-closed_low)/step;
   if(!MathIsValidNumber(depth) || depth < 1.0) return 0;
   int reached=(int)MathFloor(depth+1.0e-12);
   if(reached > max_levels) reached=max_levels;
   return reached;
}

double ZCAG_RawLot(const double base_lot,const int reached,
                   const double max_exposure)
{
   if(!ZCAG_FinitePositive(base_lot) || reached <= 0 ||
      !ZCAG_FinitePositive(max_exposure)) return 0.0;
   double lot=base_lot*reached;
   if(!MathIsValidNumber(lot) || lot <= 0.0) return 0.0;
   return MathMin(lot,max_exposure);
}

ZCAG_ZResult ZCAG_PopulationZ(const double current,const double sum,
                              const double sum_squares,const int count)
{
   ZCAG_ZResult result;
   result.valid=false;
   result.value=0.0;
   if(count <= 1 || !MathIsValidNumber(current) ||
      !MathIsValidNumber(sum) || !MathIsValidNumber(sum_squares))
      return result;
   double mean=sum/count;
   double variance=sum_squares/count-mean*mean;
   if(!MathIsValidNumber(variance) || variance <= 0.0) return result;
   double deviation=MathSqrt(variance);
   if(!ZCAG_FinitePositive(deviation)) return result;
   double z=(current-mean)/deviation;
   if(!MathIsValidNumber(z)) return result;
   result.valid=true;
   result.value=z;
   return result;
}

bool ZCAG_ZQualifies(const ZCAG_ZResult &z,const double threshold)
{
   return (z.valid && MathIsValidNumber(threshold) && z.value <= threshold);
}

bool ZCAG_HigherLow(const double latest,const double prior)
{
   return (MathIsValidNumber(latest) && MathIsValidNumber(prior) &&
           latest > prior);
}

bool ZCAG_SupportQualified(const double closed_low,
                           const double closed_close,
                           const double pivot,
                           const double structure_atr,
                           const double zone_atr_width)
{
   if(!MathIsValidNumber(closed_low) ||
      !MathIsValidNumber(closed_close) ||
      !ZCAG_FinitePositive(pivot) ||
      !ZCAG_FinitePositive(structure_atr) ||
      !MathIsValidNumber(zone_atr_width) ||
      zone_atr_width < 0.0)
      return false;
   double width=structure_atr*zone_atr_width;
   double upper=pivot+width;
   double lower=pivot-width;
   if(!MathIsValidNumber(width) || !MathIsValidNumber(upper) ||
      !MathIsValidNumber(lower))
      return false;
   return (closed_low <= upper && closed_close >= lower);
}

double ZCAG_Target(const double anchor,const double step,const int reached)
{
   if(!MathIsValidNumber(anchor) || !ZCAG_FinitePositive(step) ||
      reached <= 0)
      return 0.0;
   return ZCAG_LevelPrice(anchor,step,reached-1);
}

double ZCAG_Stop(const double pivot,const double structure_atr,
                 const double break_atr_mult)
{
   if(!ZCAG_FinitePositive(pivot) ||
      !ZCAG_FinitePositive(structure_atr) ||
      !MathIsValidNumber(break_atr_mult) ||
      break_atr_mult < 0.0)
      return 0.0;
   double stop=pivot-structure_atr*break_atr_mult;
   return (MathIsValidNumber(stop) ? stop : 0.0);
}

bool ZCAG_Reclaimed(const double close1,const double close2,const double rung)
{
   return (MathIsValidNumber(close1) && MathIsValidNumber(close2) &&
           MathIsValidNumber(rung) && close1 > rung && close2 <= rung);
}

bool ZCAG_Expired(const int bars_since_touch,const int expiry_bars)
{
   return (expiry_bars > 0 && bars_since_touch >= expiry_bars);
}

void ZCAG_ResetLadderState(ZCAG_RuntimeState &state)
{
   state.ladder_armed=false;
   state.step_frozen=false;
   state.anchor=0.0;
   state.step=0.0;
   state.reached=0;
   state.bars_since_touch=0;
}

bool ZCAG_RuntimeStateEqual(const ZCAG_RuntimeState &left,
                            const ZCAG_RuntimeState &right)
{
   return (left.regime_bar_time == right.regime_bar_time &&
           left.decision_bar_time == right.decision_bar_time &&
           left.decision_bar_ordinal == right.decision_bar_ordinal &&
           left.bull == right.bull &&
           left.ladder_armed == right.ladder_armed &&
           left.step_frozen == right.step_frozen &&
           left.anchor == right.anchor &&
           left.step == right.step &&
           left.reached == right.reached &&
           left.bars_since_touch == right.bars_since_touch);
}

bool ZCAG_ValidateRegimeSnapshot(const ZCAG_RegimeSnapshot &snapshot)
{
   return (snapshot.bar_time > 0 && snapshot.close_read &&
           snapshot.middle_read && snapshot.upper_read &&
           ZCAG_FinitePositive(snapshot.close1) &&
           ZCAG_FinitePositive(snapshot.middle) &&
           ZCAG_FinitePositive(snapshot.upper) &&
           snapshot.upper >= snapshot.middle);
}

ZCAG_ApplyStatus ZCAG_ApplyRegimeSnapshot(
   ZCAG_RuntimeState &state,const ZCAG_RegimeSnapshot &snapshot)
{
   if(state.regime_bar_time > 0 &&
      snapshot.bar_time <= state.regime_bar_time)
      return ZCAG_APPLY_ALREADY_CONSUMED;
   if(!ZCAG_ValidateRegimeSnapshot(snapshot)) return ZCAG_APPLY_INVALID;

   bool next_bull=state.bull;
   bool reset_ladder=false;
   if(snapshot.close1 > snapshot.upper)
      next_bull=true;
   else if(snapshot.close1 < snapshot.middle)
   {
      next_bull=false;
      reset_ladder=true;
   }

   // Commit only after the complete snapshot and transition are valid.
   state.bull=next_bull;
   if(reset_ladder) ZCAG_ResetLadderState(state);
   state.regime_bar_time=snapshot.bar_time;
   return ZCAG_APPLY_COMMITTED;
}

bool ZCAG_ContiguousPositive(const double &values[],const int count)
{
   if(count <= 0 || count > ArraySize(values)) return false;
   for(int i=0;i<count;i++)
      if(!ZCAG_FinitePositive(values[i])) return false;
   return true;
}

ZCAG_HistoryStatus ZCAG_PivotAt(const double &lows[],const int count,
                                const int shift,const int left_bars,
                                const int right_bars)
{
   if(left_bars <= 0 || right_bars <= 0 ||
      shift < right_bars+1 || shift+left_bars >= count ||
      shift-right_bars < 1)
      return ZCAG_INVALID_HISTORY;
   if(!ZCAG_ContiguousPositive(lows,count)) return ZCAG_INVALID_HISTORY;

   double candidate=lows[shift];
   for(int j=1;j<=right_bars;j++)
      if(candidate >= lows[shift-j]) return ZCAG_VALID_NON_PIVOT;
   for(int j=1;j<=left_bars;j++)
      if(candidate >= lows[shift+j]) return ZCAG_VALID_NON_PIVOT;
   return ZCAG_VALID_PIVOT;
}

bool ZCAG_FindTwoPivotsContiguous(const double &lows[],const int count,
                                  const int left_bars,const int right_bars,
                                  double &latest,double &prior)
{
   latest=0.0;
   prior=0.0;
   if(!ZCAG_ContiguousPositive(lows,count)) return false;
   int first=right_bars+1;
   int last=count-left_bars-1;
   if(first > last) return true;
   for(int shift=first;shift<=last;shift++)
   {
      ZCAG_HistoryStatus status=ZCAG_PivotAt(lows,count,shift,
                                             left_bars,right_bars);
      if(status == ZCAG_INVALID_HISTORY) return false;
      if(status != ZCAG_VALID_PIVOT) continue;
      if(latest <= 0.0) latest=lows[shift];
      else
      {
         prior=lows[shift];
         return true;
      }
   }
   return true;
}

ZCAG_ZResult ZCAG_SnapshotZ(const ZCAG_DecisionSnapshot &snapshot)
{
   ZCAG_ZResult invalid;
   invalid.valid=false;
   invalid.value=0.0;
   if(!snapshot.z_history_read || snapshot.z_count <= 1 ||
      snapshot.z_count > ZCAG_MAX_SNAPSHOT_BARS)
      return invalid;
   double sum=0.0;
   double sum_squares=0.0;
   for(int i=0;i<snapshot.z_count;i++)
   {
      double value=snapshot.z_closes[i];
      if(!ZCAG_FinitePositive(value)) return invalid;
      sum+=value;
      sum_squares+=value*value;
   }
   return ZCAG_PopulationZ(snapshot.z_closes[0],sum,sum_squares,
                           snapshot.z_count);
}

bool ZCAG_ValidateDecisionConfig(const ZCAG_DecisionConfig &config)
{
   return (ZCAG_FinitePositive(config.step_atr_mult) &&
           config.min_levels > 0 &&
           config.min_levels <= config.max_levels &&
           config.max_levels > 0 && config.expiry_bars > 0 &&
           config.pivot_left > 0 && config.pivot_right > 0 &&
           MathIsValidNumber(config.break_atr_mult) &&
           config.break_atr_mult >= 0.0 &&
           MathIsValidNumber(config.zone_atr_width) &&
           config.zone_atr_width >= 0.0 &&
           MathIsValidNumber(config.z_threshold));
}

bool ZCAG_ValidateDecisionSnapshot(const ZCAG_DecisionSnapshot &snapshot,
                                   const ZCAG_DecisionConfig &config)
{
   if(!ZCAG_ValidateDecisionConfig(config) || snapshot.bar_time <= 0 ||
      snapshot.decision_bar_ordinal <= 0 ||
      !snapshot.high_read || !snapshot.low_read ||
      !snapshot.close1_read || !snapshot.close2_read ||
      !snapshot.step_atr_read || !snapshot.structure_atr_read ||
      !snapshot.z_history_read || !snapshot.structure_history_read ||
      !ZCAG_FinitePositive(snapshot.high1) ||
      !ZCAG_FinitePositive(snapshot.low1) ||
      !ZCAG_FinitePositive(snapshot.close1) ||
      !ZCAG_FinitePositive(snapshot.close2) ||
      !ZCAG_FinitePositive(snapshot.step_atr) ||
      !ZCAG_FinitePositive(snapshot.structure_atr) ||
      snapshot.structure_count <= 0 ||
      snapshot.structure_count > ZCAG_MAX_SNAPSHOT_BARS)
      return false;
   if(!ZCAG_ContiguousPositive(snapshot.structure_lows,
                               snapshot.structure_count))
      return false;
   ZCAG_ZResult z=ZCAG_SnapshotZ(snapshot);
   return z.valid;
}

ZCAG_ApplyStatus ZCAG_ApplyDecisionSnapshot(
   ZCAG_RuntimeState &state,const ZCAG_DecisionSnapshot &snapshot,
   const ZCAG_DecisionConfig &config,bool &entry_ready)
{
   entry_ready=false;
   if(state.decision_bar_time > 0 &&
      snapshot.bar_time <= state.decision_bar_time)
      return ZCAG_APPLY_ALREADY_CONSUMED;
   if(!ZCAG_ValidateDecisionSnapshot(snapshot,config))
      return ZCAG_APPLY_INVALID;

   long elapsed_decision_bars=0;
   if(state.decision_bar_time > 0)
   {
      if(state.decision_bar_ordinal <= 0 ||
         snapshot.decision_bar_ordinal <= state.decision_bar_ordinal)
         return ZCAG_APPLY_INVALID;
      elapsed_decision_bars=(snapshot.decision_bar_ordinal-
                             state.decision_bar_ordinal);
      // bars_since_touch is an int. Refuse an unrepresentable elapsed gap
      // instead of overflowing or approximating from wall-clock time.
      if(elapsed_decision_bars <= 0 ||
         elapsed_decision_bars > 2147483647)
         return ZCAG_APPLY_INVALID;
   }
   else if(state.decision_bar_ordinal != 0)
      return ZCAG_APPLY_INVALID;

   double latest=0.0;
   double prior=0.0;
   if(!ZCAG_FindTwoPivotsContiguous(snapshot.structure_lows,
                                    snapshot.structure_count,
                                    config.pivot_left,config.pivot_right,
                                    latest,prior))
      return ZCAG_APPLY_INVALID;

   bool ladder_armed=state.ladder_armed;
   bool step_frozen=state.step_frozen;
   double anchor=state.anchor;
   double step=state.step;
   int reached=state.reached;
   int bars_since_touch=state.bars_since_touch;

   if(!state.bull)
   {
      ladder_armed=false;
      step_frozen=false;
      anchor=0.0;
      step=0.0;
      reached=0;
      bars_since_touch=0;
   }
   else
   {
      double provisional=snapshot.step_atr*config.step_atr_mult;
      if(!ZCAG_FinitePositive(provisional)) return ZCAG_APPLY_INVALID;
      if(!ladder_armed)
      {
         ladder_armed=true;
         anchor=snapshot.high1;
      }
      else if(!step_frozen && snapshot.high1 > anchor)
         anchor=snapshot.high1;

      if(!step_frozen)
      {
         step=provisional;
         if(snapshot.low1 <= ZCAG_LevelPrice(anchor,step,1))
         {
            step_frozen=true;
            reached=ZCAG_ReachedLevels(anchor,step,snapshot.low1,
                                       config.max_levels);
            bars_since_touch=0;
         }
      }
      else
      {
         if(bars_since_touch < 0 ||
            elapsed_decision_bars > 2147483647-bars_since_touch)
            return ZCAG_APPLY_INVALID;
         bars_since_touch+=(int)elapsed_decision_bars;
         int new_reached=ZCAG_ReachedLevels(anchor,step,snapshot.low1,
                                            config.max_levels);
         if(new_reached > reached) reached=new_reached;
      }

      if(step_frozen && ZCAG_Expired(bars_since_touch,config.expiry_bars))
      {
         ladder_armed=false;
         step_frozen=false;
         anchor=0.0;
         step=0.0;
         reached=0;
         bars_since_touch=0;
      }
      else if(latest > 0.0 &&
              snapshot.close1 <
              ZCAG_Stop(latest,snapshot.structure_atr,
                        config.break_atr_mult))
      {
         ladder_armed=false;
         step_frozen=false;
         anchor=0.0;
         step=0.0;
         reached=0;
         bars_since_touch=0;
      }
      else if(step_frozen && reached >= config.min_levels &&
              latest > 0.0 && prior > 0.0)
      {
         ZCAG_ZResult z=ZCAG_SnapshotZ(snapshot);
         double rung=ZCAG_LevelPrice(anchor,step,reached);
         entry_ready=(ZCAG_HigherLow(latest,prior) &&
                      ZCAG_SupportQualified(snapshot.low1,snapshot.close1,
                                            latest,snapshot.structure_atr,
                                            config.zone_atr_width) &&
                      ZCAG_ZQualifies(z,config.z_threshold) &&
                      ZCAG_Reclaimed(snapshot.close1,snapshot.close2,rung));
      }
   }

   // One atomic commit after every required read/history validation succeeds.
   state.ladder_armed=ladder_armed;
   state.step_frozen=step_frozen;
   state.anchor=anchor;
   state.step=step;
   state.reached=reached;
   state.bars_since_touch=bars_since_touch;
   state.decision_bar_time=snapshot.bar_time;
   state.decision_bar_ordinal=snapshot.decision_bar_ordinal;
   return ZCAG_APPLY_COMMITTED;
}
// END ZCAG DETERMINISTIC KERNEL

#endif // BOSS_LAB_ENTRY_ZONECOMPRESSEDGRID_MQH
