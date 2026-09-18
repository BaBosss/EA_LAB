#property copyright "EA_LAB / Boss"
#property version "2.00"
#property description "B21 DF03 source-native research integration; pending independent review"
#property strict
#define LAB_ENTRY_21
#define LAB_ENTRY_TAG "21_GridFibo"
#include "core/LabCore.mqh"

void OnTrade() { if(g_df03_ready) DF03_AdapterTrade(); }
void OnTimer() { if(g_df03_ready) DF03_AdapterTimer(); }
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_df03_ready) DF03_AdapterChartEvent(id, lparam, dparam, sparam);
}
