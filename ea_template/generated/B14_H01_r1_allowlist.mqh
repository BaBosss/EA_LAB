//+------------------------------------------------------------------+
//| B14_H01_r1_allowlist.mqh - GENERATED FILE, DO NOT EDIT BY HAND.
//| generator : _triage/factory_os/gen_wrapper.py
//| revision  : B14-H01-r1
//| regenerate: tools\python312\python.exe _triage/factory_os/gen_wrapper.py --write
//|
//| ORDER-1021 (design 5.3). One token per capability module this revision's
//| PINNED CONFIG can reach. The set is derived by capability.enabled_tokens()
//| from the same selectors the architecture digest reads, so it cannot disagree
//| with the module_set on this revision's Hypothesis row.
//|
//| MQL5 has no `#if EXPR==n` and no `#elif` (Inputs.mqh:11 says so), so this file
//| emits TOKEN #defines only -- plus, below, the per-input const decisions, which
//| are token #defines too. Any design that assumes expression conditionals is
//| wrong on this platform.
//+------------------------------------------------------------------+
#ifndef BOSS_ALLOWLIST_B14_H01_R1_MQH
#define BOSS_ALLOWLIST_B14_H01_R1_MQH

#define LAB_CAP_CORE
#define LAB_CAP_ENTRY_GRIDLOG
#define LAB_CAP_EXEC
#define LAB_CAP_EXIT
#define LAB_CAP_INDICATORS
#define LAB_CAP_LOTPROG
#define LAB_CAP_MM
#define LAB_CAP_RISK
#define LAB_CAP_STACK

//--- design 5.3 / 5.4: the inputs this revision compiles away ---------------
//| 78 const, 38 left on the Inputs page.
//| Each pair switches ea_template/core/Inputs.mqh from its `input` branch to
//| its `const` branch. LAB_CONSTVAL_* carries the EFFECTIVE value -- the
//| canonical default for an unreachable input, the PINNED value for a locked
//| one -- so a lock is applied rather than merely declared.
//|
//| NOT const-ed although unreachable under this config, and the reason is
//| load-bearing: a still-live input decides whether each of these matters,
//| so const-ing them would freeze one arm of a decision the optimizer is
//| allowed to sweep. See gen_wrapper.const_plan().
//|   _4_DdHardCapMult       kept, because _4_DdAdaptiveOn is still an input
//|   _4_DdTier1Mult         kept, because _4_DdAdaptiveOn is still an input
//|   _4_DdTier1Pct          kept, because _4_DdAdaptiveOn is still an input
//|   _4_DdTier2Mult         kept, because _4_DdAdaptiveOn is still an input
//|   _4_DdTier2Pct          kept, because _4_DdAdaptiveOn is still an input
//|   _57_DynCloseBase       kept, because _57_DynCloseOn is still an input
//|   _57_DynCloseDivisor    kept, because _57_DynCloseOn is still an input

#define LAB_CONST_ExitMode
#define LAB_CONSTVAL_ExitMode EXIT_ATR_TP
#define LAB_CONST_FirstLotMode
#define LAB_CONSTVAL_FirstLotMode FIRSTLOT_FIXED
#define LAB_CONST_HedgeMode
#define LAB_CONSTVAL_HedgeMode HEDGE_OFF
#define LAB_CONST_LotProg
#define LAB_CONSTVAL_LotProg PROG_LOG_POWER
#define LAB_CONST_RC_MaxLevelsOverride
#define LAB_CONSTVAL_RC_MaxLevelsOverride 0
#define LAB_CONST_RC_RecMultMax
#define LAB_CONSTVAL_RC_RecMultMax 1.3
#define LAB_CONST_RecoveryMode
#define LAB_CONSTVAL_RecoveryMode REC_NONE
#define LAB_CONST_SLMode
#define LAB_CONSTVAL_SLMode SL_NONE
#define LAB_CONST_StackConfirm
#define LAB_CONSTVAL_StackConfirm CONF_DISTANCE
#define LAB_CONST_StackMode
#define LAB_CONSTVAL_StackMode STACK_GRID_AGAINST
#define LAB_CONST_TradeDir
#define LAB_CONSTVAL_TradeDir TRADEDIR_BOTH
#define LAB_CONST_TrendFilter
#define LAB_CONSTVAL_TrendFilter TFILTER_NONE
#define LAB_CONST__0_FastMA
#define LAB_CONSTVAL__0_FastMA 20
#define LAB_CONST__0_MAMethod
#define LAB_CONSTVAL__0_MAMethod MODE_EMA
#define LAB_CONST__0_MA_TF
#define LAB_CONSTVAL__0_MA_TF PERIOD_CURRENT
#define LAB_CONST__0_MaxSpread
#define LAB_CONSTVAL__0_MaxSpread 0
#define LAB_CONST__0_SlowMA
#define LAB_CONSTVAL__0_SlowMA 50
#define LAB_CONST__21_TP_Pip
#define LAB_CONSTVAL__21_TP_Pip 500
#define LAB_CONST__23_TrailStart
#define LAB_CONSTVAL__23_TrailStart 300
#define LAB_CONST__23_TrailStep
#define LAB_CONSTVAL__23_TrailStep 100
#define LAB_CONST__2_BasketTP_ATRmult
#define LAB_CONSTVAL__2_BasketTP_ATRmult 0
#define LAB_CONST__2_MaxHoldBars
#define LAB_CONSTVAL__2_MaxHoldBars 0
#define LAB_CONST__2_PartialFrac1
#define LAB_CONSTVAL__2_PartialFrac1 0.30
#define LAB_CONST__2_PartialFrac2
#define LAB_CONSTVAL__2_PartialFrac2 0.30
#define LAB_CONST__2_PartialPct1
#define LAB_CONSTVAL__2_PartialPct1 0
#define LAB_CONST__2_PartialPct2
#define LAB_CONSTVAL__2_PartialPct2 0
#define LAB_CONST__31_SL_Pip
#define LAB_CONSTVAL__31_SL_Pip 1000
#define LAB_CONST__32_SL_Money
#define LAB_CONSTVAL__32_SL_Money 0
#define LAB_CONST__33_AdaptiveN
#define LAB_CONSTVAL__33_AdaptiveN 50
#define LAB_CONST__33_AdaptiveON
#define LAB_CONSTVAL__33_AdaptiveON false
#define LAB_CONST__33_SL_ATRmult
#define LAB_CONSTVAL__33_SL_ATRmult 2.0
#define LAB_CONST__33_SL_MaxATRmult
#define LAB_CONSTVAL__33_SL_MaxATRmult 0.0
#define LAB_CONST__33_SL_MaxPips
#define LAB_CONSTVAL__33_SL_MaxPips 0.0
#define LAB_CONST__34_DonchianBars
#define LAB_CONSTVAL__34_DonchianBars 50
#define LAB_CONST__35_SRBars
#define LAB_CONSTVAL__35_SRBars 20
#define LAB_CONST__36_SD_Mult
#define LAB_CONSTVAL__36_SD_Mult 2.0
#define LAB_CONST__36_SD_Period
#define LAB_CONSTVAL__36_SD_Period 20
#define LAB_CONST__42_RiskPct
#define LAB_CONSTVAL__42_RiskPct 1.0
#define LAB_CONST__43_BalanceAnchor
#define LAB_CONSTVAL__43_BalanceAnchor 1000.0
#define LAB_CONST__43_LotPerAnchor
#define LAB_CONSTVAL__43_LotPerAnchor 0.01
#define LAB_CONST__50_ADX_Period
#define LAB_CONSTVAL__50_ADX_Period 14
#define LAB_CONST__50_ADX_TrendMin
#define LAB_CONSTVAL__50_ADX_TrendMin 25.0
#define LAB_CONST__50_AllowRange
#define LAB_CONSTVAL__50_AllowRange true
#define LAB_CONST__50_AllowTrendDown
#define LAB_CONSTVAL__50_AllowTrendDown true
#define LAB_CONST__50_AllowTrendUp
#define LAB_CONSTVAL__50_AllowTrendUp true
#define LAB_CONST__50_RegimeMode
#define LAB_CONSTVAL__50_RegimeMode 0
#define LAB_CONST__50_Regime_TF
#define LAB_CONSTVAL__50_Regime_TF PERIOD_H4
#define LAB_CONST__50_StormATRmult
#define LAB_CONSTVAL__50_StormATRmult 2.0
#define LAB_CONST__50_StormLookback
#define LAB_CONSTVAL__50_StormLookback 100
#define LAB_CONST__51_ProgFactor
#define LAB_CONSTVAL__51_ProgFactor 0.5
#define LAB_CONST__52_ProgMult
#define LAB_CONSTVAL__52_ProgMult 1.3
#define LAB_CONST__53_PlusLot
#define LAB_CONSTVAL__53_PlusLot 0.01
#define LAB_CONST__56_FibMaxStep
#define LAB_CONSTVAL__56_FibMaxStep 5
#define LAB_CONST__57_DynCloseBalPct
#define LAB_CONSTVAL__57_DynCloseBalPct 0
#define LAB_CONST__71_ATRMA
#define LAB_CONSTVAL__71_ATRMA 20
#define LAB_CONST__71_ATRRatio
#define LAB_CONSTVAL__71_ATRRatio 1.0
#define LAB_CONST__72_SlopeBar
#define LAB_CONSTVAL__72_SlopeBar 3
#define LAB_CONST__8_DDRefBalPct
#define LAB_CONSTVAL__8_DDRefBalPct 0
#define LAB_CONST__8_DDRefMoney
#define LAB_CONSTVAL__8_DDRefMoney 100.0
#define LAB_CONST__8_RecMult
#define LAB_CONSTVAL__8_RecMult 1.3
#define LAB_CONST__8_StepATR
#define LAB_CONSTVAL__8_StepATR 1.0
#define LAB_CONST__8_TriggerATR
#define LAB_CONSTVAL__8_TriggerATR 1.5
#define LAB_CONST__9_PA_MinBodyRatio
#define LAB_CONSTVAL__9_PA_MinBodyRatio 1.0
#define LAB_CONST__9_PendingLegs
#define LAB_CONSTVAL__9_PendingLegs 0
#define LAB_CONST__9_PendingMode
#define LAB_CONSTVAL__9_PendingMode 0
#define LAB_CONST__9_RegimeGateAdds
#define LAB_CONSTVAL__9_RegimeGateAdds false
#define LAB_CONST__9_StepMinPips
#define LAB_CONSTVAL__9_StepMinPips 0
#define LAB_CONST__H_MaxLot
#define LAB_CONSTVAL__H_MaxLot 0.0
#define LAB_CONST__H_Ratio
#define LAB_CONSTVAL__H_Ratio 1.0
#define LAB_CONST__H_ReleaseDDPct
#define LAB_CONSTVAL__H_ReleaseDDPct 3.0
#define LAB_CONST__H_TriggerDDPct
#define LAB_CONSTVAL__H_TriggerDDPct 8.0
#define LAB_CONST__MG_BlockNew
#define LAB_CONSTVAL__MG_BlockNew true
#define LAB_CONST__MG_InCommon
#define LAB_CONSTVAL__MG_InCommon true
#define LAB_CONST__MG_LotMult
#define LAB_CONSTVAL__MG_LotMult 0.5
#define LAB_CONST__MG_OffsetHours
#define LAB_CONSTVAL__MG_OffsetHours 0
#define LAB_CONST__MG_RegimeFile
#define LAB_CONSTVAL__MG_RegimeFile "EA_LAB_mris_regime.csv"
#define LAB_CONST__MG_SelfGate
#define LAB_CONSTVAL__MG_SelfGate false
#define LAB_CONST__MG_TriggerRiskOff
#define LAB_CONSTVAL__MG_TriggerRiskOff true

#endif // BOSS_ALLOWLIST_B14_H01_R1_MQH
