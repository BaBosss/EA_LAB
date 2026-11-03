//+------------------------------------------------------------------+
//|                                      Boss_29_PendingBreakout.mq5 |
//|   Boss Lab V2 chassis - Entry 29: Pending Stop Breakout Ladder.  |
//|   Multi-level Buy Stop / Sell Stop pending ladder + OCO.         |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.00"
#property description "Boss Lab V2 - 29 Pending Breakout (High/Low Range + Stop Ladder + OCO)"
#property strict
// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file Boss_19_PendingBreakout.mq5
// sha256 dc38b6ae67c708f4e2377067ddd1ba789f6dda118785ed9d8f8ca7549365634c; renumbered 19 -> 29 (inputs _19_* -> _29_*). Logic unchanged.

#define LAB_ENTRY_29
#define LAB_ENTRY_TAG "29_PendingBreakout"
#include "core/LabCore.mqh"
