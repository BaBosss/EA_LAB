//+------------------------------------------------------------------+
//|                                           Boss_27_TrendRider.mq5 |
//|   Boss Lab V2 chassis - Entry 27: TrendRider XAU                 |
//|   H4 trend pullback-continuation, ATR stop + Chandelier trail.   |
//+------------------------------------------------------------------+
#property copyright "EA_LAB / Boss"
#property version   "2.00"
#property description "Boss Lab V2 - 27 TrendRider (H4 Pullback-Continuation + Chandelier Trail)"
#property strict
// A10 C2 port 2026-11-03: ported from the untracked local D:\EA_LAB file Boss_21_TrendRider.mq5
// sha256 35de1a011d0d501bb9f1e99c21798c82a98d5938099a3a9d5ddd1b7d47cf5fb2; renumbered 21 -> 27 (inputs _21_* -> _27_*). Logic unchanged.

#define LAB_ENTRY_27
#define LAB_ENTRY_TAG "27_TrendRider"
#include "core/LabCore.mqh"
