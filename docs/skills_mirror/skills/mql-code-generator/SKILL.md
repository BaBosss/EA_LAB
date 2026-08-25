---
name: mql-code-generator
description: >
  Generate compile-ready MQL5 EA code from a Master EA Spec Card. Use when the
  user has a completed Spec Card from strategy-and-risk and wants MQL5 code,
  or asks to implement/modify EA code for grid, hedge, LOG lot, or PA distance
  modules.
---

# MQL5 Code Generator

## ROLE
Generate modular, compile-ready MQL5 code from a Master EA Spec Card.
Supports: LOG Lot (LN + LOG10), Price Action Distance gating, Multi-Close
Hedge TP, Scale Ladder.

## INPUT
Requires a Master EA Spec Card (YAML) from the strategy-and-risk skill.
If none exists, route the user there first — do not invent a spec.

## ARCHITECTURE AND PATHS (chassis-first default; routing owned by docs/PIPELINE.md)

Boss V2 / `ea_template/core` is the default chassis-first path. A standalone EA is an
exception and must state its reason (for example, an MT4 target or an experiment that
must not touch `ea_template`). New standalone work belongs under
`D:\EA_LAB\ea_projects\<EA>\`. `EA_CORE` is a read-only archive, not an active
authoring path.

When a standalone path is explicitly justified, use its local template and patterns:
Key patterns to copy into every new standalone EA:

```mql5
// Numbered param groups with separator labels (show nicely in MT5 Settings dialog)
input string _g01_ = "── [01] SIGNAL ────────────────────────────";
input int    _01_MyParam = 14;
// [00] OptimizeMode, [01] Signal, [02] SL/TP, [03] Filter, [05] TradeMgmt, [06] System

// Bar-open-only gate (CRITICAL — prevents duplicate entries on each tick of a bar)
static datetime g_last_bar = 0;
void OnTick() {
   const datetime cur_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(cur_bar == g_last_bar) return;
   g_last_bar = cur_bar;
   // ... rest of logic uses close[1]/high[1]/low[1] etc.
}

// Tester-gate fix (CRITICAL — without this, AllowLive=false blocks Strategy Tester too → 0 trades)
// [06] System section:
input bool _06_AllowLive = false;
// In order placement:
const bool allow = _06_AllowLive || (bool)MQLInfoInteger(MQL_TESTER);
if(!allow) { /* dry-run log */ return; }

// OnTester() for Sharpe criterion (optimizer uses Criterion=6 = Custom)
double OnTester() {
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < 30) return -1.0;
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   return (sharpe > 0 ? sharpe : -1.0);
}

// Suppress log during optimize (speeds up sweeps)
static bool g_suppress_log = false;
// In OnInit: g_suppress_log = _00_OptimizeMode || (bool)MQLInfoInteger(MQL_OPTIMIZATION);
```

Naming: `(Boss)_<StrategyLogic>_rev<NN>.mq5`, magic numbers 990001+ for standalone EAs.
Include `STANDALONE_RISK_BUNDLE.mqh` for RiskEngine+LotSizer if needed (optional).

## CODE SAFETY RULES (apply to ALL generated code)

1. **Pip size must be digit-aware — never hard-code `_Point * 10`:**
```mql5
double PipSize(const string symbol)
{
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    // 5/3-digit FX quotes: pip = 10 points. 4/2-digit and metals/indices: pip = point×10 only for FX.
    if(digits == 5 || digits == 3) return point * 10.0;
    return point;   // XAUUSD 2-digit, indices, crypto: treat 1 point move as configured
}
// For non-FX symbols prefer expressing distances in POINTS via input, not pips.
```

2. **LOT NORMALIZATION — reject unsafe requests; never `NormalizeDouble(lot,2)`:**
```mql5
int VolumeDigits(const double step)
{
    if(!MathIsValidNumber(step) || step <= 0.0) return -1;
    int digits = 0;
    double scaled = step;
    while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-9)
    {
        scaled *= 10.0;
        digits++;
    }
    return (MathAbs(scaled - MathRound(scaled)) <= 1e-9) ? digits : -1;
}

double NormalizeLot(const string symbol, const double requestedLot)
{
    const double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    const double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    const double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    const int digits = VolumeDigits(lotStep);
    if(!MathIsValidNumber(requestedLot) || requestedLot <= 0.0 ||
       !MathIsValidNumber(minLot) || !MathIsValidNumber(maxLot) ||
       !MathIsValidNumber(lotStep) || minLot <= 0.0 || maxLot <= 0.0 ||
       lotStep <= 0.0 || minLot > maxLot || digits < 0)
        return 0.0;
    if(requestedLot < minLot) return 0.0; // never increase requested risk

    const double capped = MathMin(requestedLot, maxLot);
    const double floored = MathFloor(capped / lotStep) * lotStep;
    const double normalized = NormalizeDouble(floored, digits); // digits come from step
    if(!MathIsValidNumber(normalized) || normalized < minLot || normalized > maxLot)
        return 0.0;
    return normalized;
}
```
The same contract applies to fixed, risk-based, LOG, grid, and hedge lots: a
non-positive/invalid broker constraint fails closed; a requested lot below the broker
minimum returns invalid/0; valid requests are floored to the broker step and formatted
with precision derived from that step. Never clamp a sub-minimum request up to the
minimum, and never recommend `NormalizeDouble(lot,2)`.

3. **TRADE RESULT SEMANTICS — a `CTrade::Buy`/`Sell`/etc. `true` is not broker confirmation.**
After a successful method call, inspect the appropriate `ResultRetcode()` and
`ResultRetcodeDescription()`, then inspect/log the resulting deal, order, or
server-state where applicable. Treat missing/failed confirmation as a failed operation. This
is a knowledge/cage rule; it does not authorize changing `Execution.mqh` here.

4. **COPYBUFFER / INDICATOR READS — handle creation is not data readiness.**
Require `CopyBuffer` to return the expected count; do not use an ambiguous `0.0`
failure sentinel when zero is a legitimate indicator value. Declare array direction
explicitly (`ArraySetAsSeries` or an explicit non-series convention), document
closed-bar [1] versus forming-bar [0], and fail closed on protective/risk-path indicator
read failures where appropriate.

5. **FILLING POLICY — broker-compatible, never universal by invention.**
Inspect `SYMBOL_FILLING_MODE` and select/log only a filling mode compatible with the
symbol and execution mode. Do not hardcode one universal ORDER_FILLING policy or
invent a universal ORDER_FILLING_* policy.
This milestone changes knowledge/cages only; it does not change production behavior.

6. **NETTING / HEDGING — account semantics must be explicit.**
When multi-position behavior matters, inspect the account margin mode explicitly.
Hedge modules must refuse incompatible netting assumptions; future scenario tests must
distinguish netting and hedging behavior where relevant.

7. **Identify own positions by MAGIC NUMBER, never by comment equality.**
   Brokers may truncate or rewrite comments. If sub-grouping is needed
   (e.g. GRID vs HEDGE), encode it in the magic number (offset scheme) or
   match comment by prefix as fallback only.

8. **Always check `ACCOUNT_MARGIN_MODE == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING`
   in OnInit before enabling any hedge module.** Fail INIT otherwise.

9. **Every EA must implement the spec's hard caps**: max_positions,
   max_total_lot, daily_loss_limit, emergency_exit_dd — checked before every
   OrderSend, not only in OnInit.

10. **Refuse L5** (Hedge+Martingale+Grid combined). L4 only with explicit user
   risk acceptance recorded in the spec.

## KEY CODE PATTERNS

### LOG Lot Calculation
```mql5
double CalcLogLot(int orderN, double baseLot, double factor, string logType)
{
    double n = (double)orderN;
    double exponent = (logType == "LN") ? MathLog(n) : MathLog10(n);
    return NormalizeLot(_Symbol, baseLot * MathPow(factor, exponent));
}
// orderN=1 → exponent=0 → lot = baseLot (always base on first order)
```

### PA Distance Gate
```mql5
bool CheckPADistanceGate(string paSignal, double minDistPips)
{
    double lastGridPrice = GetLastGridPrice();
    double currentPrice  = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distPips      = MathAbs(currentPrice - lastGridPrice) / PipSize(_Symbol);
    bool   signalOK      = DetectPASignal(paSignal);      // candle pattern check
    bool   distOK        = (distPips >= minDistPips);
    return (signalOK && distOK);   // BOTH conditions required
}
```

### Multi-Close Hedge TP
```mql5
void ManageHedgeTpMultiClose(double minDistPips, double hedgeTpPips,
                              double profitThreshPips)
{
    double hedgeProfit = GetHedgeFloatProfit();
    if(hedgeProfit < profitThreshPips * PipSize(_Symbol)) return;

    // Close ALL grid positions farther than minDistPips from current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicGrid) continue;  // magic, not comment

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double dist      = MathAbs(currentPrice - openPrice) / PipSize(_Symbol);
        if(dist >= minDistPips)
            Trade.PositionClose(ticket);
    }

    // Set TP on remaining hedge positions (selected by InpMagicHedge)
    SetHedgeTP(hedgeTpPips);
}
```

### Scale Ladder Hedge
```mql5
void OpenScaleLadderHedge(double gridOrderLot)
{
    // Every new grid order triggers equivalent hedge addition
    double hedgeLot = NormalizeLot(_Symbol, gridOrderLot);
    if(g_hedgeActive)
        OpenAdditionalHedge(hedgeLot);  // Add to existing hedge
    else
        OpenFirstHedge(hedgeLot);       // Open new hedge
}
```

## RUNTIME VARIABLES
Use `input` parameters for everything the optimizer should reach; mirror them
into `g_*` runtime variables only via `ApplyPreset()` / `ValidateCombination()`.

```mql5
// Distance
double g_minDistPips        = 40.0;
string g_paSignal           = "ENGULFING";
double g_atrDistMultiplier  = 1.5;

// Lot
double g_baseLot            = 0.01;
string g_lotMode            = "FIXED";
double g_logFactor          = 1.3;
string g_logType            = "LN";
double g_martMultiplier     = 1.5;
int    g_martMaxSteps       = 4;
double g_linearStep         = 0.01;

// Hedge
bool   g_hedgeEnabled       = false;
int    g_hedgeTriggerOrder  = 4;
double g_hedgeTpPips        = 10.0;
double g_minCloseDist       = 30.0;
double g_profitThreshold    = 5.0;
bool   g_hedgeActive        = false;
double g_totalHedgeLot      = 0.0;
```

## EA_CORE_V1 PLATFORM NOTE
When the user is working inside the EA_CORE_V1 archive, treat it as read-only and
follow platform rules instead of standalone patterns:
- Raw MT5 terminal calls ONLY inside `CORE\RuntimeMarketDataTerminalAdapter_v1.mqh`
- New strategy logic goes through StrategySignal/EntryGate/ExitGate contracts
- No `CTrade`/`OrderSend` until the live-execution phase is officially opened
Ask which target (standalone EA vs platform module) before generating.

## RULES
- ApplyPreset() / ValidateCombination() write to g_* only
- PA Distance: BOTH signal AND distance must be true
- LOG orderN=1 always returns baseLot (exponent=0)
- Multi-close hedge: finds ALL distant grid orders
- L4 requires user risk acceptance; L5 → REFUSE

## FINAL RULE
```
NEXT STEP:
Send the generated source to the mql-code-reviewer skill for a mandatory
PASS before compile. After PASS, compile 0/0 and proceed to
backtest-optimize-rigor.
```

> Routing between stages is owned by `docs/PIPELINE.md` — this skill owns its own stage mechanics only.


---

## 🔒 CHASSIS-FIRST RULE (2026-07-10)

Default output ไม่ใช่ EA เดี่ยวเต็มตัวอีกต่อไป — **สร้าง Entry/Module .mqh บน Boss V2 chassis
(pattern: อ่าน Boss_14/16 แล้ว wire แบบเดียวกัน)** + ต้องผ่าน cage เสมอ: compile 0/0 →
`ea_template\tpl_regression.ps1` CLEAN → `tests\run_tests.ps1` PASS (แตะ core = บังคับทั้งคู่) ·
core edits ต้อง additive + default-off สำหรับ EA เดิม · standalone .mq5 เต็มตัว = เฉพาะมีเหตุผล
(MT4 target / experiment (EXP)_* ที่ห้ามแตะ ea_template)
