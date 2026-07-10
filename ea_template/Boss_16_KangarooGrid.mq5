//+------------------------------------------------------------------+
//|                                       Boss_16_KangarooGrid.mq5   |
//|   Boss Lab V2 chassis - Entry 16: KangarooGrid (ORDER-072).      |
//|   Gold_Kangaroo-inspired rebuild: RSI fade + ATR adverse grid,   |
//|   FLAT lots, capped depth, per-order ATR SL, dollar-based basket |
//|   exits + overlap pair-close. Spec: KANGAROO_LOGIC_NOTES.md par.4|
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.00"
#property description "Boss Lab V2 - 16 KangarooGrid (RSI fade, ATR adverse grid, flat lots, overlap pair-close, hard 10-order cap)"
#property strict

#define LAB_ENTRY_16
#define LAB_ENTRY_TAG "16_KangarooGrid"
#include "core/LabCore.mqh"
