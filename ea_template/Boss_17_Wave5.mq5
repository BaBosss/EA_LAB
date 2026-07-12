//+------------------------------------------------------------------+
//|                                          Boss_17_Wave5.mq5        |
//|   Boss Lab V2 chassis - Entry 17: Wave5 (ORDER-082).              |
//|   Elliott wave-4 retrace arm to catch wave-5, both directions.    |
//|   Structural SL (wave-1 top/bottom + ATR buffer) / TP (100%       |
//|   expansion from entry), trailing-from-start + RSI-divergence     |
//|   tighten. Naked probe: StackMode single, no grid/martingale.     |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.00"
#property description "Boss Lab V2 - 17 Wave5 (Elliott wave-4 retrace arm, both directions, structural SL/TP, trailing+divergence tighten)"
#property strict

#define LAB_ENTRY_17
#define LAB_ENTRY_TAG "17_Wave5"
#include "core/LabCore.mqh"
