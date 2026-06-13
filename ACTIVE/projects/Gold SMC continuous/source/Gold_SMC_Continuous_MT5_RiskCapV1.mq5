//+------------------------------------------------------------------+
//|  Gold_SMC_Continuous_MT5_RiskCapV1.mq5                           |
//|  Logic: 24/5 Dynamic Breakout + FVG Retest + Engulfing Entry     |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://manus.im"
#property version   "27.12" 
#property description "Risk Cap v1 build with explicit capped-lot and DD controls"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

//=== Inputs =========================================================
input string ___SMC_LOGIC___     = "=== 🏦 24/5 SMC M1 SNIPER ===";
input int    InpSwingPeriod      = 3;     
input double InpRiskReward       = 3.0;    

input string ___SMART_RECOVERY___= "=== 🧠 QUANTUM BASKET RECOVERY ===";
input double InpLotSize          = 0.01;   
input double InpLotMultiplier    = 2.0;    
input int    InpMinGapPts        = 150;    

input string ___MONEY_TARGETS___ = "=== 💰 MONEY TARGETS ===";
input double InpTakeProfitUSD    = 1.0;    
input double InpDailyTargetUSD   = 100.0;  
input int    InpSLBufferPts      = 15;     

input string ___RISK_CAP_V1___    = "=== RISK CAP PATCH V1 ===";
input double InpMaxLotAbsolute    = 0.20;
input double InpMaxDepositLoadPercent = 30.0;
input double InpMaxFloatingDDPercent  = 20.0;
input double InpMaxDailyLossPercent   = 5.0;
input int    InpMaxRecoverySteps      = 3;
input double InpRecoveryMultiplierMax = 1.3;
input double InpStopNewEntriesWhenDDPercent = 15.0;
input double InpCloseAllWhenDDPercent       = 25.0;
input bool   InpOneRecoveryChainAtATime     = true;
input bool   InpBlockNewCycleAfterLoss      = true;
input int    InpCooldownBarsAfterStop       = 20;

input string ___SYSTEM___        = "=== 🔧 SYSTEM ===";
input int    InpMagic            = 270000;
input int    InpSlippage         = 3;
input color  InpDashBGColor      = clrBlack;
input color  InpDashTextColor    = clrWhite;

//=== Variables ======================================================
CTrade         m_trade;
CPositionInfo  m_position;

double   PipPoint;
datetime g_lastBar = 0;
string   g_dashState = "SCANNING DYNAMIC RANGE";
color    g_dashStateColor = clrYellow;

datetime g_dailyDate = 0;
bool     g_dailyTargetHit = false;

int      g_breakoutDir = 0; 
double   g_fvgTop = 0, g_fvgBot = 0;
bool     g_pulledBack = false;

int      g_cooldownBarsRemaining = 0;
bool     g_riskPauseActive = false;
datetime g_lastCooldownBar = 0;
double   g_diagMaxLotUsed = 0.0;
double   g_diagMaxDepositLoad = 0.0;
double   g_diagMaxFloatingDDPercent = 0.0;
int      g_diagMaxRecoveryStepsUsed = 0;
bool     g_wasCloseAllActive = false;
bool     g_wasStopNewEntriesActive = false;
bool     g_wasDailyLossActive = false;
bool     g_wasCooldownActive = false;
bool     g_wasRecoveryBlockActive = false;
bool     g_wasLotCapActive = false;
long     g_diagCloseAllEventCount = 0;
long     g_diagStopNewEntriesEventCount = 0;
long     g_diagDailyLossStopEventCount = 0;
long     g_diagCooldownEventCount = 0;
long     g_diagRecoveryBlockEventCount = 0;
long     g_diagLotCapEventCount = 0;
long     g_diagCloseAllActiveTicks = 0;
long     g_diagStopNewEntriesActiveTicks = 0;
long     g_diagDailyLossActiveTicks = 0;
long     g_diagCooldownActiveTicks = 0;

//+------------------------------------------------------------------+
int OnInit() {
    PipPoint = _Point; if(_Digits == 5 || _Digits == 3) PipPoint = _Point * 10;
    m_trade.SetExpertMagicNumber(InpMagic); m_trade.SetDeviationInPoints(InpSlippage); m_trade.SetTypeFilling(ORDER_FILLING_IOC);
    MqlDateTime dt; TimeCurrent(dt); dt.hour=0; dt.min=0; dt.sec=0; g_dailyDate = StructToTime(dt);
    CreateDashboard(); return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { 
    ExportRiskDiagnostics();
    RemoveDashboard(); ObjectDelete(0, "DYN_HIGH"); ObjectDelete(0, "DYN_LOW"); 
    ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT"); 
}

//+------------------------------------------------------------------+
void OnTick() {
    MqlDateTime dt; TimeCurrent(dt); dt.hour=0; dt.min=0; dt.sec=0;
    datetime todayD1 = StructToTime(dt);
    if(todayD1 != g_dailyDate) { 
        g_dailyDate = todayD1; g_dailyTargetHit = false; 
        g_breakoutDir = 0; g_pulledBack = false;
        ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT");
    }

    int orderCount = 0; double currentFloat = 0; double lastLot = 0; double lastPrice = 0; datetime latestTime = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(m_position.SelectByIndex(i) && m_position.Magic() == InpMagic && m_position.Symbol() == _Symbol) {
            orderCount++; currentFloat += m_position.Profit() + m_position.Swap();
            if (m_position.Time() > latestTime) { latestTime = m_position.Time(); lastLot = m_position.Volume(); lastPrice = m_position.PriceOpen(); }
        }
    }

    UpdateRiskDiagnostics(orderCount);

    double dailyProf = GetDailyProfit();
    double balanceNow = AccountInfoDouble(ACCOUNT_BALANCE);
    double maxDailyLossMoney = balanceNow * InpMaxDailyLossPercent / 100.0;
    bool dailyLossActive = (maxDailyLossMoney > 0.0 && dailyProf <= -maxDailyLossMoney);
    double floatingDDPercent = GetFloatingDDPercent();
    double hardCloseDDPercent = MathMin(InpMaxFloatingDDPercent, InpCloseAllWhenDDPercent);
    bool hardCloseActive = (orderCount > 0 && hardCloseDDPercent > 0.0 && floatingDDPercent >= hardCloseDDPercent);
    UpdateRiskStateTracking(orderCount, dailyLossActive, hardCloseActive, floatingDDPercent);

    if(dailyLossActive) {
        CloseAll();
        StartCooldown();
        g_dashState = "RISK CAP: DAILY LOSS STOP"; g_dashStateColor = clrRed; UpdateDashboard(dailyProf, 0, 0); return;
    }

    if(dailyProf >= InpDailyTargetUSD) g_dailyTargetHit = true;

    if(g_dailyTargetHit) { 
        if(PositionsTotal() > 0) CloseAll();
        g_dashState = "🏆 DAILY TARGET HIT! (SLEEPING)"; g_dashStateColor = clrGold; UpdateDashboard(dailyProf, 0, 0); return; 
    }

    if(hardCloseActive) {
        CloseAll();
        StartCooldown();
        g_dashState = "RISK CAP: FLOATING DD CLOSE ALL"; g_dashStateColor = clrRed; UpdateDashboard(dailyProf, 0, 0); return;
    }
    
    if(orderCount > 0 && currentFloat >= InpTakeProfitUSD) {
        CloseAll(); Print("💰 CONTINUOUS BULLET SUCCESS! Collected: $", currentFloat); 
        g_breakoutDir = 0; g_pulledBack = false; 
        ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT");
        return; 
    }

    datetime tCur[]; ArraySetAsSeries(tCur, true);
    if(CopyTime(_Symbol, _Period, 0, 1, tCur) <= 0) return;
    if(tCur[0] == g_lastBar) return;
    DecrementCooldownOnNewBar(tCur[0]);

    double HArr[], LArr[], OArr[], CArr[];
    ArraySetAsSeries(HArr, true); ArraySetAsSeries(LArr, true); ArraySetAsSeries(OArr, true); ArraySetAsSeries(CArr, true);
    if(CopyHigh(_Symbol, _Period, 0, InpSwingPeriod+5, HArr) <= 0 || CopyLow(_Symbol, _Period, 0, InpSwingPeriod+5, LArr) <= 0 || CopyOpen(_Symbol, _Period, 0, 5, OArr) <= 0 || CopyClose(_Symbol, _Period, 0, 5, CArr) <= 0) return;

    // 🔄 1. DYNAMIC RANGE
    int hiIdx = ArrayMaximum(HArr, 3, InpSwingPeriod);
    int loIdx = ArrayMinimum(LArr, 3, InpSwingPeriod);
    double dynHigh = HArr[hiIdx], dynLow = LArr[loIdx];

    if(g_breakoutDir == 0 && orderCount == 0) {
        DrawLine("DYN_HIGH", dynHigh, clrOrange); DrawLine("DYN_LOW", dynLow, clrOrange);
    }

    // 🚀 2. BREAKOUT + FVG
    if(g_breakoutDir == 0 && orderCount == 0) {
        g_dashState = "SCANNING BREAKOUT + FVG"; g_dashStateColor = clrYellow;
        if(CArr[2] > dynHigh && LArr[1] > HArr[3]) {
            g_breakoutDir = 1; g_fvgTop = LArr[1]; g_fvgBot = HArr[3]; g_pulledBack = false;
            DrawLine("FVG_TOP", g_fvgTop, clrLime); DrawLine("FVG_BOT", g_fvgBot, clrLime);
        }
        else if(CArr[2] < dynLow && HArr[1] < LArr[3]) {
            g_breakoutDir = -1; g_fvgTop = LArr[3]; g_fvgBot = HArr[1]; g_pulledBack = false;
            DrawLine("FVG_TOP", g_fvgTop, clrRed); DrawLine("FVG_BOT", g_fvgBot, clrRed);
        }
    }

    // 🧹 3. FVG INVALIDATION
    if(g_breakoutDir == 1 && CArr[1] < g_fvgBot) { g_breakoutDir = 0; g_pulledBack = false; ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT"); }
    if(g_breakoutDir == -1 && CArr[1] > g_fvgTop) { g_breakoutDir = 0; g_pulledBack = false; ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT"); }

    // 🎯 4. PULLBACK & ENGULFING
    bool buySignal = false, sellSignal = false; double calcSL = 0;

    if(g_breakoutDir != 0 && orderCount == 0) {
        if(!g_pulledBack) {
            g_dashState = "WAITING PULLBACK TO FVG"; g_dashStateColor = clrMagenta;
            if(g_breakoutDir == 1 && LArr[1] <= g_fvgTop) g_pulledBack = true;
            if(g_breakoutDir == -1 && HArr[1] >= g_fvgBot) g_pulledBack = true;
        }

        if(g_pulledBack) {
            g_dashState = "WAITING ENGULFING TRIGGER"; g_dashStateColor = clrDeepSkyBlue;
            if(g_breakoutDir == 1) { 
                if(CArr[1] > OArr[1] && OArr[1] <= CArr[2] && CArr[1] >= OArr[2]) { buySignal = true; calcSL = g_fvgBot - (InpSLBufferPts * PipPoint); }
            }
            else if(g_breakoutDir == -1) { 
                if(CArr[1] < OArr[1] && OArr[1] >= CArr[2] && CArr[1] <= OArr[2]) { sellSignal = true; calcSL = g_fvgTop + (InpSLBufferPts * PipPoint); }
            }
        }
    }

    if(orderCount > 0) {
        g_dashState = "RECOVERY WAITING..."; g_dashStateColor = clrMagenta;
        bool hasBearishFVG = (HArr[1] < LArr[3]); bool hasBullishFVG = (LArr[1] > HArr[3]); 
        if(hasBullishFVG && CArr[2] > dynHigh) { buySignal = true; calcSL = HArr[3]; }
        if(hasBearishFVG && CArr[2] < dynLow) { sellSignal = true; calcSL = LArr[3]; }
    }

    if(!buySignal && !sellSignal) { UpdateDashboard(dailyProf, dynHigh, dynLow); return; }

    bool isRecoveryEntry = (orderCount > 0);
    if(IsEntryBlockedByRisk(orderCount, isRecoveryEntry)) { UpdateDashboard(dailyProf, dynHigh, dynLow); return; }

    // 💰 5. EXECUTION & RESET
    double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double nextLot = InpLotSize;
    
    if(orderCount > 0) {
        double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        double effectiveMultiplier = MathMin(InpLotMultiplier, InpRecoveryMultiplierMax);
        nextLot = NormalizeDouble(MathRound((lastLot * effectiveMultiplier) / step) * step, 2);
        if(nextLot <= lastLot) nextLot = NormalizeDouble(lastLot + step, 2);
    }
    nextLot = ApplyLotCap(nextLot);
    if(nextLot <= 0.0) { UpdateDashboard(dailyProf, dynHigh, dynLow); return; }

    double tpPrice = 0; string cmt = "";
    if(buySignal) {
        if(orderCount == 0 || MathAbs(curAsk - lastPrice) >= InpMinGapPts * PipPoint) {
            if(IsProjectedDepositLoadBlocked(nextLot, ORDER_TYPE_BUY, curAsk, isRecoveryEntry)) { UpdateDashboard(dailyProf, dynHigh, dynLow); return; }
            tpPrice = curAsk + ((curAsk - calcSL) * InpRiskReward);
            cmt = (orderCount > 0) ? "CT_Rec_Buy" : "CT_1st_Buy";
            if(m_trade.Buy(nextLot, _Symbol, curAsk, 0, tpPrice, cmt)) { 
                g_diagMaxLotUsed = MathMax(g_diagMaxLotUsed, nextLot);
                g_lastBar = tCur[0]; g_breakoutDir = 0; g_pulledBack = false; ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT");
                g_dashState = "🚀 CONT. BUY EXECUTED!"; g_dashStateColor = clrLime; 
            }
        }
    }
    else if(sellSignal) {
        if(orderCount == 0 || MathAbs(curBid - lastPrice) >= InpMinGapPts * PipPoint) {
            if(IsProjectedDepositLoadBlocked(nextLot, ORDER_TYPE_SELL, curBid, isRecoveryEntry)) { UpdateDashboard(dailyProf, dynHigh, dynLow); return; }
            tpPrice = curBid - ((calcSL - curBid) * InpRiskReward);
            cmt = (orderCount > 0) ? "CT_Rec_Sell" : "CT_1st_Sell";
            if(m_trade.Sell(nextLot, _Symbol, curBid, 0, tpPrice, cmt)) { 
                g_diagMaxLotUsed = MathMax(g_diagMaxLotUsed, nextLot);
                g_lastBar = tCur[0]; g_breakoutDir = 0; g_pulledBack = false; ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT");
                g_dashState = "🚀 CONT. SELL EXECUTED!"; g_dashStateColor = clrRed; 
            }
        }
    }

    UpdateDashboard(dailyProf, dynHigh, dynLow);
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
        return;

    if(!HistoryDealSelect(trans.deal))
        return;

    if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
        return;

    if((int)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagic)
        return;

    long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
        return;

    double closedPL = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                    + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
    if(InpBlockNewCycleAfterLoss && closedPL < 0.0)
        StartCooldown();
}

void DrawLine(string name, double price, color clr) { if(ObjectFind(0, name) < 0) { ObjectCreate(0, name, OBJ_HLINE, 0, 0, price); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH); ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); } else { ObjectSetDouble(0, name, OBJPROP_PRICE, price); } }
double GetDailyProfit() { double dp = 0; if(HistorySelect(g_dailyDate, TimeCurrent() + 86400)) { for(int i=0; i<HistoryDealsTotal(); i++) { ulong ticket = HistoryDealGetTicket(i); if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagic && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol) { long type = HistoryDealGetInteger(ticket, DEAL_ENTRY); if(type == DEAL_ENTRY_OUT || type == DEAL_ENTRY_OUT_BY) dp += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION); } } } for(int i = 0; i < PositionsTotal(); i++) if(m_position.SelectByIndex(i) && m_position.Magic() == InpMagic && m_position.Symbol() == _Symbol) dp += m_position.Profit() + m_position.Swap(); return dp; }
void CloseAll() { bool rem=true; int ret=0; while(rem && ret<10) { rem=false; for(int i=PositionsTotal()-1;i>=0;i--) { if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagic) { if(!m_trade.PositionClose(m_position.Ticket())) rem=true; } } ret++; if(rem) Sleep(500); } }

double GetDepositLoadPercent()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity <= 0.0)
        return 0.0;
    return AccountInfoDouble(ACCOUNT_MARGIN) / equity * 100.0;
}

double GetFloatingDDPercent()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(balance <= 0.0 || equity >= balance)
        return 0.0;
    return (balance - equity) / balance * 100.0;
}

void UpdateRiskDiagnostics(const int orderCount)
{
    double depositLoad = GetDepositLoadPercent();
    double floatingDD = GetFloatingDDPercent();
    g_diagMaxDepositLoad = MathMax(g_diagMaxDepositLoad, depositLoad);
    g_diagMaxFloatingDDPercent = MathMax(g_diagMaxFloatingDDPercent, floatingDD);
    g_diagMaxRecoveryStepsUsed = MathMax(g_diagMaxRecoveryStepsUsed, MathMax(0, orderCount - 1));
}

void TrackStateCounter(const bool active,
                       bool &wasActive,
                       long &eventCounter,
                       long &activeTicks)
{
    // Event counters count transition into a state.
    // Active tick counters count how long the state persisted.
    if(active) {
        activeTicks++;
        if(!wasActive)
            eventCounter++;
    }
    wasActive = active;
}

void TrackEventCounter(const bool active,
                       bool &wasActive,
                       long &eventCounter)
{
    if(active && !wasActive)
        eventCounter++;
    wasActive = active;
}

void UpdateRiskStateTracking(const int orderCount,
                             const bool dailyLossActive,
                             const bool hardCloseActive,
                             const double floatingDDPercent)
{
    bool stopNewEntriesActive = ((InpStopNewEntriesWhenDDPercent > 0.0 &&
                                  floatingDDPercent >= InpStopNewEntriesWhenDDPercent) ||
                                 GetDepositLoadPercent() >= InpMaxDepositLoadPercent);
    bool cooldownActive = (InpBlockNewCycleAfterLoss &&
                           g_cooldownBarsRemaining > 0);
    bool recoveryBlockActive = (orderCount > 0 &&
                                orderCount >= InpMaxRecoverySteps + 1);

    TrackStateCounter(dailyLossActive,
                      g_wasDailyLossActive,
                      g_diagDailyLossStopEventCount,
                      g_diagDailyLossActiveTicks);
    TrackStateCounter((dailyLossActive || hardCloseActive),
                      g_wasCloseAllActive,
                      g_diagCloseAllEventCount,
                      g_diagCloseAllActiveTicks);
    TrackStateCounter(stopNewEntriesActive,
                      g_wasStopNewEntriesActive,
                      g_diagStopNewEntriesEventCount,
                      g_diagStopNewEntriesActiveTicks);
    TrackStateCounter(cooldownActive,
                      g_wasCooldownActive,
                      g_diagCooldownEventCount,
                      g_diagCooldownActiveTicks);
    TrackEventCounter(recoveryBlockActive,
                      g_wasRecoveryBlockActive,
                      g_diagRecoveryBlockEventCount);
}

void StartCooldown()
{
    g_riskPauseActive = true;
    if(InpCooldownBarsAfterStop > 0)
        g_cooldownBarsRemaining = MathMax(g_cooldownBarsRemaining, InpCooldownBarsAfterStop);
}

void DecrementCooldownOnNewBar(const datetime barTime)
{
    if(barTime == g_lastCooldownBar)
        return;
    g_lastCooldownBar = barTime;

    if(g_cooldownBarsRemaining > 0)
        g_cooldownBarsRemaining--;
    if(g_cooldownBarsRemaining <= 0)
        g_riskPauseActive = false;
}

bool IsEntryBlockedByRisk(const int orderCount, const bool isRecoveryEntry)
{
    double floatingDD = GetFloatingDDPercent();
    if(InpStopNewEntriesWhenDDPercent > 0.0 && floatingDD >= InpStopNewEntriesWhenDDPercent) {
        if(isRecoveryEntry)
            TrackEventCounter(true, g_wasRecoveryBlockActive, g_diagRecoveryBlockEventCount);
        g_dashState = "RISK CAP: DD BLOCK"; g_dashStateColor = clrRed;
        return true;
    }

    if(GetDepositLoadPercent() >= InpMaxDepositLoadPercent) {
        if(isRecoveryEntry)
            TrackEventCounter(true, g_wasRecoveryBlockActive, g_diagRecoveryBlockEventCount);
        else
            TrackEventCounter(true, g_wasStopNewEntriesActive, g_diagStopNewEntriesEventCount);
        g_dashState = "RISK CAP: DEPOSIT LOAD BLOCK"; g_dashStateColor = clrRed;
        return true;
    }

    if(!isRecoveryEntry && InpBlockNewCycleAfterLoss && g_cooldownBarsRemaining > 0) {
        g_dashState = "RISK CAP: COOLDOWN"; g_dashStateColor = clrOrange;
        return true;
    }

    if(isRecoveryEntry && orderCount >= InpMaxRecoverySteps + 1) {
        TrackEventCounter(true, g_wasRecoveryBlockActive, g_diagRecoveryBlockEventCount);
        g_dashState = "RISK CAP: MAX RECOVERY STEPS"; g_dashStateColor = clrRed;
        return true;
    }

    if(InpOneRecoveryChainAtATime && isRecoveryEntry && orderCount <= 0) {
        TrackEventCounter(true, g_wasRecoveryBlockActive, g_diagRecoveryBlockEventCount);
        return true;
    }

    return false;
}

double NormalizeVolumeDown(const double lots)
{
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(step <= 0.0)
        step = 0.01;

    double capped = MathMin(lots, MathMin(maxLot, InpMaxLotAbsolute));
    if(capped < minLot)
        return 0.0;

    double normalized = MathFloor(capped / step) * step;
    normalized = NormalizeDouble(normalized, 2);
    if(normalized < minLot)
        return 0.0;
    return normalized;
}

double ApplyLotCap(const double requestedLot)
{
    double cappedLot = NormalizeVolumeDown(requestedLot);
    if(cappedLot + 0.0000001 < requestedLot)
        TrackEventCounter(true, g_wasLotCapActive, g_diagLotCapEventCount);
    else
        TrackEventCounter(false, g_wasLotCapActive, g_diagLotCapEventCount);
    return cappedLot;
}

bool IsProjectedDepositLoadBlocked(const double lot,
                                   const ENUM_ORDER_TYPE orderType,
                                   const double price,
                                   const bool isRecoveryEntry)
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equity <= 0.0)
        return true;

    double margin = 0.0;
    if(!OrderCalcMargin(orderType, _Symbol, lot, price, margin))
        margin = 0.0;

    double projectedLoad = (AccountInfoDouble(ACCOUNT_MARGIN) + margin) / equity * 100.0;
    g_diagMaxDepositLoad = MathMax(g_diagMaxDepositLoad, projectedLoad);
    if(projectedLoad > InpMaxDepositLoadPercent) {
        if(isRecoveryEntry)
            TrackEventCounter(true, g_wasRecoveryBlockActive, g_diagRecoveryBlockEventCount);
        else
            TrackEventCounter(true, g_wasStopNewEntriesActive, g_diagStopNewEntriesEventCount);
        g_dashState = "RISK CAP: PROJECTED LOAD BLOCK"; g_dashStateColor = clrRed;
        return true;
    }

    return false;
}

void ExportRiskDiagnostics()
{
    string commonPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\";
    int csv = FileOpen("risk_cap_diagnostics.csv", FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
    if(csv != INVALID_HANDLE) {
        FileWrite(csv,
                  "max_lot_used",
                  "max_deposit_load",
                  "max_floating_dd_percent",
                  "recovery_steps_used",
                  "close_all_event_count",
                  "stop_new_entries_event_count",
                  "daily_loss_stop_event_count",
                  "cooldown_event_count",
                  "recovery_block_event_count",
                  "lot_cap_event_count",
                  "close_all_active_ticks",
                  "stop_new_entries_active_ticks",
                  "daily_loss_active_ticks",
                  "cooldown_active_ticks");
        FileWrite(csv,
                  DoubleToString(g_diagMaxLotUsed, 2),
                  DoubleToString(g_diagMaxDepositLoad, 2),
                  DoubleToString(g_diagMaxFloatingDDPercent, 2),
                  IntegerToString(g_diagMaxRecoveryStepsUsed),
                  IntegerToString(g_diagCloseAllEventCount),
                  IntegerToString(g_diagStopNewEntriesEventCount),
                  IntegerToString(g_diagDailyLossStopEventCount),
                  IntegerToString(g_diagCooldownEventCount),
                  IntegerToString(g_diagRecoveryBlockEventCount),
                  IntegerToString(g_diagLotCapEventCount),
                  IntegerToString(g_diagCloseAllActiveTicks),
                  IntegerToString(g_diagStopNewEntriesActiveTicks),
                  IntegerToString(g_diagDailyLossActiveTicks),
                  IntegerToString(g_diagCooldownActiveTicks));
        FileClose(csv);
    }

    int txt = FileOpen("risk_cap_summary.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
    if(txt != INVALID_HANDLE) {
        FileWriteString(txt, "Risk Cap Patch v1 Summary\r\n");
        FileWriteString(txt, "common_files_path=" + commonPath + "\r\n");
        FileWriteString(txt, "max_lot_used=" + DoubleToString(g_diagMaxLotUsed, 2) + "\r\n");
        FileWriteString(txt, "max_deposit_load=" + DoubleToString(g_diagMaxDepositLoad, 2) + "\r\n");
        FileWriteString(txt, "max_floating_dd_percent=" + DoubleToString(g_diagMaxFloatingDDPercent, 2) + "\r\n");
        FileWriteString(txt, "recovery_steps_used=" + IntegerToString(g_diagMaxRecoveryStepsUsed) + "\r\n");
        FileWriteString(txt, "counter_semantics=event counters count transition into a state; active tick counters count how long the state persisted\r\n");
        FileWriteString(txt, "close_all_event_count=" + IntegerToString(g_diagCloseAllEventCount) + "\r\n");
        FileWriteString(txt, "stop_new_entries_event_count=" + IntegerToString(g_diagStopNewEntriesEventCount) + "\r\n");
        FileWriteString(txt, "daily_loss_stop_event_count=" + IntegerToString(g_diagDailyLossStopEventCount) + "\r\n");
        FileWriteString(txt, "cooldown_event_count=" + IntegerToString(g_diagCooldownEventCount) + "\r\n");
        FileWriteString(txt, "recovery_block_event_count=" + IntegerToString(g_diagRecoveryBlockEventCount) + "\r\n");
        FileWriteString(txt, "lot_cap_event_count=" + IntegerToString(g_diagLotCapEventCount) + "\r\n");
        FileWriteString(txt, "close_all_active_ticks=" + IntegerToString(g_diagCloseAllActiveTicks) + "\r\n");
        FileWriteString(txt, "stop_new_entries_active_ticks=" + IntegerToString(g_diagStopNewEntriesActiveTicks) + "\r\n");
        FileWriteString(txt, "daily_loss_active_ticks=" + IntegerToString(g_diagDailyLossActiveTicks) + "\r\n");
        FileWriteString(txt, "cooldown_active_ticks=" + IntegerToString(g_diagCooldownActiveTicks) + "\r\n");
        FileClose(txt);
    }

    PrintFormat("RISK_CAP_SUMMARY max_lot=%.2f max_deposit_load=%.2f max_floating_dd=%.2f recovery_steps=%d close_all_events=%I64d stop_new_events=%I64d daily_loss_events=%I64d cooldown_events=%I64d recovery_block_events=%I64d lot_cap_events=%I64d close_all_ticks=%I64d stop_new_ticks=%I64d cooldown_ticks=%I64d files=%s",
                g_diagMaxLotUsed,
                g_diagMaxDepositLoad,
                g_diagMaxFloatingDDPercent,
                g_diagMaxRecoveryStepsUsed,
                g_diagCloseAllEventCount,
                g_diagStopNewEntriesEventCount,
                g_diagDailyLossStopEventCount,
                g_diagCooldownEventCount,
                g_diagRecoveryBlockEventCount,
                g_diagLotCapEventCount,
                g_diagCloseAllActiveTicks,
                g_diagStopNewEntriesActiveTicks,
                g_diagCooldownActiveTicks,
                commonPath);
}

void CreateDashboard() { int x = 20, y = 20; ObjectCreate(0, "DashBG", OBJ_RECTANGLE_LABEL, 0, 0, 0); ObjectSetInteger(0, "DashBG", OBJPROP_XDISTANCE, x); ObjectSetInteger(0, "DashBG", OBJPROP_YDISTANCE, y); ObjectSetInteger(0, "DashBG", OBJPROP_XSIZE, 340); ObjectSetInteger(0, "DashBG", OBJPROP_YSIZE, 200); ObjectSetInteger(0, "DashBG", OBJPROP_BGCOLOR, InpDashBGColor); ObjectSetInteger(0, "DashBG", OBJPROP_BORDER_COLOR, clrDodgerBlue); ObjectSetInteger(0, "DashBG", OBJPROP_CORNER, CORNER_LEFT_UPPER); CreateLabel("DashTitle", "⏰ CONTINUOUS SMC (V27)", x+15, y+15, 12, clrGold); CreateLabel("DashLine1", "------------------------------------------------------", x+15, y+35, 10, clrGray); CreateLabel("DashBal", "Balance: ", x+15, y+55, 10, InpDashTextColor); CreateLabel("DashDPL", "Daily P/L: ", x+15, y+75, 10, InpDashTextColor); CreateLabel("DashLine2", "------------------------------------------------------", x+15, y+95, 10, clrGray); CreateLabel("DashZHi", "Dynamic Range High: ", x+15, y+115, 10, clrOrange); CreateLabel("DashZLo", "Dynamic Range Low: ", x+15, y+135, 10, clrOrange); CreateLabel("DashStat", "Status: ", x+15, y+165, 10, InpDashTextColor); }
void UpdateDashboard(double dailyProfit, double hZone, double lZone) { if(ObjectFind(0, "DashBG") < 0) CreateDashboard(); ObjectSetString(0, "DashBal", OBJPROP_TEXT, StringFormat("Balance:  %.2f USD", AccountInfoDouble(ACCOUNT_BALANCE))); ObjectSetString(0, "DashDPL", OBJPROP_TEXT, StringFormat("Daily P/L: %+.2f / %.2f USD", dailyProfit, InpDailyTargetUSD)); ObjectSetInteger(0, "DashDPL", OBJPROP_COLOR, (dailyProfit >= 0) ? clrLime : clrRed); ObjectSetString(0, "DashZHi", OBJPROP_TEXT, StringFormat("Dyn Range High: %.3f", hZone)); ObjectSetString(0, "DashZLo", OBJPROP_TEXT, StringFormat("Dyn Range Low:  %.3f", lZone)); ObjectSetString(0, "DashStat", OBJPROP_TEXT, "Status: " + g_dashState); ObjectSetInteger(0, "DashStat", OBJPROP_COLOR, g_dashStateColor); ChartRedraw(0); }
void CreateLabel(string name, string text, int x, int y, int size, color clr) { ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetString(0, name, OBJPROP_FONT, "Trebuchet MS"); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER); }
void RemoveDashboard() { ObjectDelete(0, "DashBG"); ObjectDelete(0, "DashTitle"); ObjectDelete(0, "DashLine1"); ObjectDelete(0, "DashBal"); ObjectDelete(0, "DashDPL"); ObjectDelete(0, "DashLine2"); ObjectDelete(0, "DashZHi"); ObjectDelete(0, "DashZLo"); ObjectDelete(0, "DashStat"); ChartRedraw(0); }
//+------------------------------------------------------------------+

