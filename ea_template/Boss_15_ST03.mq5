//+------------------------------------------------------------------+
//|                                               Boss_15_ST03.mq5   |
//|   Boss Lab V2 chassis - Entry 15: ST03 MACD consecutive-count.   |
//|   Port of EA_CORE StrategySignal_v4 (MERGE-07, owner override).  |
//|   ⚠ DO NOT DEPLOY until ST03 replica (990010) survives judge     |
//|   2026-09-22 - the edge is unproven (OOS PF 0.86 vs 3.93 claim). |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.00"
#property description "Boss Lab V2 - 15 ST03 (MACD consecutive-count edge-trigger, v4 port - NOT deploy-approved)"
#property strict

// MGTT qualification is an explicit compile-time opt-in. The ordinary Boss15
// control compiles without LAB_MG_TESTER_EVIDENCE_QUAL and therefore carries
// neither tester dependencies nor evidence instrumentation. The qualification
// host creates a frozen wrapper copy that defines the flag before these lines.
#ifdef LAB_MG_TESTER_EVIDENCE_QUAL
#property tester_file "REAL_FULL_2020_2025_macrogate_native.csv"
#property tester_file "MAIN_seed_2026092501_macrogate_native.csv"
#property tester_file "BWD_seed_2026092501_macrogate_native.csv"
#property tester_file "MAIN_seed_2026092502_macrogate_native.csv"
#property tester_file "BWD_seed_2026092502_macrogate_native.csv"
#property tester_file "MAIN_seed_2026092503_macrogate_native.csv"
#property tester_file "BWD_seed_2026092503_macrogate_native.csv"
#property tester_file "MAIN_seed_2026092504_macrogate_native.csv"
#property tester_file "BWD_seed_2026092504_macrogate_native.csv"
#property tester_file "MAIN_seed_2026092505_macrogate_native.csv"
#property tester_file "BWD_seed_2026092505_macrogate_native.csv"
#endif

#define LAB_ENTRY_15
#define LAB_ENTRY_TAG "15_ST03"
#include "core/LabCore.mqh"
