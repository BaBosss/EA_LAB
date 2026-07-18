//+------------------------------------------------------------------+
//|                                            Boss_18_JumStoch.mq5   |
//|   Boss Lab V2 chassis - Entry 18: JumStoch LWMA-displacement +   |
//|   Stochastic filter (seed signal only; grid/DCA/exit = chassis). |
//|   Port of the JUMSTOCH "Trend" block (ORDER-091C-D1). Direction   |
//|   mapping is A/B-switched via _18_DirMode (1=faithful momentum,   |
//|   2=reversion) - see Entry_JumStoch.mqh header. NOT deploy-       |
//|   approved: Lane-A A/B in progress (2026-07-18).                  |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.00"
#property description "Boss Lab V2 - 18 JumStoch (LWMA+Stoch seed on chassis DCA; A/B direction-mode)"
#property strict

#define LAB_ENTRY_18
#define LAB_ENTRY_TAG "18_JumStoch"
#include "core/LabCore.mqh"
