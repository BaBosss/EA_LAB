$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\smoke_new_batch.log"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function Smoke($expert, $label, $symbol, $period="H1") {
    $rpt = "SMOKE_NEW_${label}_${symbol}"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP $rpt"; return }
    Log "START $rpt"
    try {
        & "$s\mt5_run.ps1" -Expert $expert -Symbol $symbol -Period $period -Model 1 `
            -FromDate "2023.01.01" -ToDate "2026.06.01" -ReportName $rpt
        Log "DONE $rpt"
    } catch { Log "ERROR $rpt : $($_.Exception.Message)" }
}

Set-Content $log "" -Encoding UTF8
Log "=== SMOKE BATCH START ==="

$eus = "EURUSD"
$xau = "XAUUSD"

# Trading EAs to smoke (EURUSD H1 + XAUUSD H1)
$eas = @(
    @{Expert="Multi-Timeframe Trend Following"; Label="MTF_Trend"},
    @{Expert="Black Wolf EA";                   Label="BlackWolf"},
    @{Expert="The Day Zone v2";                 Label="DayZone_v2"},
    @{Expert="(NuiIndy) Dynamic RSI+ADX Style (4)"; Label="NuiIndy_RSI_ADX"},
    @{Expert="Winning Pro 2.5 (Update)";        Label="WinningPro25"},
    @{Expert="Grid197 MO ATR";                  Label="Grid197_ATR"},
    @{Expert="EX162 - EMA Rising and EMA Crossover"; Label="EX162_EMA"},
    @{Expert="EX177 - Grid Trading System and Hedging Lots rev 2.2"; Label="EX177_Grid"},
    @{Expert="Ghost Bot 01 G07 (1)";            Label="GhostBot_G07"},
    @{Expert="Grizzy[BUY]v1.0";                Label="Grizzy_BUY"},
    @{Expert="HalfTrend_MTF_EA";               Label="HalfTrend_MTF"},
    @{Expert="ESQ1004 1-13-17 BB RSI X Pyramid All Perfect mq5"; Label="ESQ1004_BBR"},
    @{Expert="(oh) Master GRID ATR Accumulative Deduction -B V22A"; Label="oh_MasterGrid_ATR"},
    @{Expert="Ben_CR_2025_v1.2 (10) (2) (5) (16) (4)"; Label="Ben_CR_2025"},
    @{Expert="Ghost by JOMHOD MA5";            Label="Ghost_JOMHOD"},
    @{Expert="(ST) EA03 Count MACD v1";        Label="ST_EA03_MACD"},
    @{Expert="143 E4.7.4 v1";                  Label="E4_7_4"},
    @{Expert="Scalping Trading v2.3";           Label="ScalpTrade_v23"},
    @{Expert="EA TREND V2";                     Label="EA_TREND_V2"},
    @{Expert="(Oh) Grid Upper lower V23";       Label="Oh_GridUL_V23"}
)

foreach ($ea in $eas) {
    Smoke $ea.Expert $ea.Label $eus
    Smoke $ea.Expert $ea.Label $xau
}

Log "=== ALL DONE ==="
