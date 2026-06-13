//+------------------------------------------------------------------+
//|  Gold_SMC_Continuous_MT5.mq5                                     |
//|  Logic: 24/5 Dynamic Breakout + FVG Retest + Engulfing Entry     |
//+------------------------------------------------------------------+
#property copyright "Manus AI"
#property link      "https://manus.im"
#property version   "27.00" 
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

//+------------------------------------------------------------------+
int OnInit() {
    PipPoint = _Point; if(_Digits == 5 || _Digits == 3) PipPoint = _Point * 10;
    m_trade.SetExpertMagicNumber(InpMagic); m_trade.SetDeviationInPoints(InpSlippage); m_trade.SetTypeFilling(ORDER_FILLING_IOC);
    MqlDateTime dt; TimeCurrent(dt); dt.hour=0; dt.min=0; dt.sec=0; g_dailyDate = StructToTime(dt);
    CreateDashboard(); return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { 
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

    double dailyProf = GetDailyProfit();
    if(dailyProf >= InpDailyTargetUSD) g_dailyTargetHit = true;

    if(g_dailyTargetHit) { 
        if(PositionsTotal() > 0) CloseAll();
        g_dashState = "🏆 DAILY TARGET HIT! (SLEEPING)"; g_dashStateColor = clrGold; UpdateDashboard(dailyProf, 0, 0); return; 
    }

    int orderCount = 0; double currentFloat = 0; double lastLot = 0; double lastPrice = 0; datetime latestTime = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(m_position.SelectByIndex(i) && m_position.Magic() == InpMagic && m_position.Symbol() == _Symbol) {
            orderCount++; currentFloat += m_position.Profit() + m_position.Swap();
            if (m_position.Time() > latestTime) { latestTime = m_position.Time(); lastLot = m_position.Volume(); lastPrice = m_position.PriceOpen(); }
        }
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

    // 💰 5. EXECUTION & RESET
    double curAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double curBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double nextLot = InpLotSize;
    
    if(orderCount > 0) {
        double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        nextLot = NormalizeDouble(MathRound((lastLot * InpLotMultiplier) / step) * step, 2);
        if(nextLot <= lastLot) nextLot = NormalizeDouble(lastLot + step, 2);
    }

    double tpPrice = 0; string cmt = "";
    if(buySignal) {
        if(orderCount == 0 || MathAbs(curAsk - lastPrice) >= InpMinGapPts * PipPoint) {
            tpPrice = curAsk + ((curAsk - calcSL) * InpRiskReward);
            cmt = (orderCount > 0) ? "CT_Rec_Buy" : "CT_1st_Buy";
            if(m_trade.Buy(nextLot, _Symbol, curAsk, 0, tpPrice, cmt)) { 
                g_lastBar = tCur[0]; g_breakoutDir = 0; g_pulledBack = false; ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT");
                g_dashState = "🚀 CONT. BUY EXECUTED!"; g_dashStateColor = clrLime; 
            }
        }
    }
    else if(sellSignal) {
        if(orderCount == 0 || MathAbs(curBid - lastPrice) >= InpMinGapPts * PipPoint) {
            tpPrice = curBid - ((calcSL - curBid) * InpRiskReward);
            cmt = (orderCount > 0) ? "CT_Rec_Sell" : "CT_1st_Sell";
            if(m_trade.Sell(nextLot, _Symbol, curBid, 0, tpPrice, cmt)) { 
                g_lastBar = tCur[0]; g_breakoutDir = 0; g_pulledBack = false; ObjectDelete(0, "FVG_TOP"); ObjectDelete(0, "FVG_BOT");
                g_dashState = "🚀 CONT. SELL EXECUTED!"; g_dashStateColor = clrRed; 
            }
        }
    }

    UpdateDashboard(dailyProf, dynHigh, dynLow);
}

//+------------------------------------------------------------------+
void DrawLine(string name, double price, color clr) { if(ObjectFind(0, name) < 0) { ObjectCreate(0, name, OBJ_HLINE, 0, 0, price); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH); ObjectSetInteger(0, name, OBJPROP_WIDTH, 1); } else { ObjectSetDouble(0, name, OBJPROP_PRICE, price); } }
double GetDailyProfit() { double dp = 0; if(HistorySelect(g_dailyDate, TimeCurrent() + 86400)) { for(int i=0; i<HistoryDealsTotal(); i++) { ulong ticket = HistoryDealGetTicket(i); if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagic && HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol) { long type = HistoryDealGetInteger(ticket, DEAL_ENTRY); if(type == DEAL_ENTRY_OUT || type == DEAL_ENTRY_OUT_BY) dp += HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION); } } } for(int i = 0; i < PositionsTotal(); i++) if(m_position.SelectByIndex(i) && m_position.Magic() == InpMagic && m_position.Symbol() == _Symbol) dp += m_position.Profit() + m_position.Swap(); return dp; }
void CloseAll() { bool rem=true; int ret=0; while(rem && ret<10) { rem=false; for(int i=PositionsTotal()-1;i>=0;i--) { if(m_position.SelectByIndex(i) && m_position.Symbol()==_Symbol && m_position.Magic()==InpMagic) { if(!m_trade.PositionClose(m_position.Ticket())) rem=true; } } ret++; if(rem) Sleep(500); } }

void CreateDashboard() { int x = 20, y = 20; ObjectCreate(0, "DashBG", OBJ_RECTANGLE_LABEL, 0, 0, 0); ObjectSetInteger(0, "DashBG", OBJPROP_XDISTANCE, x); ObjectSetInteger(0, "DashBG", OBJPROP_YDISTANCE, y); ObjectSetInteger(0, "DashBG", OBJPROP_XSIZE, 340); ObjectSetInteger(0, "DashBG", OBJPROP_YSIZE, 200); ObjectSetInteger(0, "DashBG", OBJPROP_BGCOLOR, InpDashBGColor); ObjectSetInteger(0, "DashBG", OBJPROP_BORDER_COLOR, clrDodgerBlue); ObjectSetInteger(0, "DashBG", OBJPROP_CORNER, CORNER_LEFT_UPPER); CreateLabel("DashTitle", "⏰ CONTINUOUS SMC (V27)", x+15, y+15, 12, clrGold); CreateLabel("DashLine1", "------------------------------------------------------", x+15, y+35, 10, clrGray); CreateLabel("DashBal", "Balance: ", x+15, y+55, 10, InpDashTextColor); CreateLabel("DashDPL", "Daily P/L: ", x+15, y+75, 10, InpDashTextColor); CreateLabel("DashLine2", "------------------------------------------------------", x+15, y+95, 10, clrGray); CreateLabel("DashZHi", "Dynamic Range High: ", x+15, y+115, 10, clrOrange); CreateLabel("DashZLo", "Dynamic Range Low: ", x+15, y+135, 10, clrOrange); CreateLabel("DashStat", "Status: ", x+15, y+165, 10, InpDashTextColor); }
void UpdateDashboard(double dailyProfit, double hZone, double lZone) { if(ObjectFind(0, "DashBG") < 0) CreateDashboard(); ObjectSetString(0, "DashBal", OBJPROP_TEXT, StringFormat("Balance:  %.2f USD", AccountInfoDouble(ACCOUNT_BALANCE))); ObjectSetString(0, "DashDPL", OBJPROP_TEXT, StringFormat("Daily P/L: %+.2f / %.2f USD", dailyProfit, InpDailyTargetUSD)); ObjectSetInteger(0, "DashDPL", OBJPROP_COLOR, (dailyProfit >= 0) ? clrLime : clrRed); ObjectSetString(0, "DashZHi", OBJPROP_TEXT, StringFormat("Dyn Range High: %.3f", hZone)); ObjectSetString(0, "DashZLo", OBJPROP_TEXT, StringFormat("Dyn Range Low:  %.3f", lZone)); ObjectSetString(0, "DashStat", OBJPROP_TEXT, "Status: " + g_dashState); ObjectSetInteger(0, "DashStat", OBJPROP_COLOR, g_dashStateColor); ChartRedraw(0); }
void CreateLabel(string name, string text, int x, int y, int size, color clr) { ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0); ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x); ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y); ObjectSetString(0, name, OBJPROP_TEXT, text); ObjectSetString(0, name, OBJPROP_FONT, "Trebuchet MS"); ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size); ObjectSetInteger(0, name, OBJPROP_COLOR, clr); ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER); }
void RemoveDashboard() { ObjectDelete(0, "DashBG"); ObjectDelete(0, "DashTitle"); ObjectDelete(0, "DashLine1"); ObjectDelete(0, "DashBal"); ObjectDelete(0, "DashDPL"); ObjectDelete(0, "DashLine2"); ObjectDelete(0, "DashZHi"); ObjectDelete(0, "DashZLo"); ObjectDelete(0, "DashStat"); ChartRedraw(0); }
//+------------------------------------------------------------------+