$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\smoke_batch4.log"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function Smoke($expert, $label, $symbol, $period="H1") {
    $rpt = "SMOKE_B4_${label}_${symbol}"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP $rpt"; return }
    Log "START $rpt"
    try {
        & "$s\mt5_run.ps1" -Expert $expert -Symbol $symbol -Period $period -Model 1 `
            -FromDate "2023.01.01" -ToDate "2026.06.01" -ReportName $rpt -TimeoutSec 300
        Log "DONE $rpt"
    } catch { Log "ERROR $rpt : $($_.Exception.Message)" }
    Stop-Process -Name terminal64 -Force -EA SilentlyContinue
    Start-Sleep 3
}

Set-Content $log "" -Encoding UTF8
Log "=== SMOKE BATCH4 START ==="

# Try these with exact filenames as expert names
$eas = @(
    @{Expert="Ghost Bot 01 G07 (1)";          Label="GhostBot_G07"},
    @{Expert="Ghost by JOMHOD MA5";           Label="Ghost_JOMHOD"},
    @{Expert="Winning Pro 2.5 (Update)";      Label="WinningPro25"},
    @{Expert="The Day Zone v2";               Label="DayZone_v2"},
    @{Expert="EA TREND V2";                   Label="EA_TREND_V2"},
    @{Expert="(Boss) Hedging Balance";         Label="Boss_Hedging"},
    @{Expert="Grid Profit-2-way  RV1[LOCK]V3"; Label="GridProfit2way"},
    @{Expert="(NuiIndy) Perfect Tri Arbitrage Any Symbols"; Label="NuiIndy_TriArb"},
    @{Expert="Grizzy[BUY]v1.0";              Label="Grizzy_BUY"}
)

foreach ($ea in $eas) {
    Smoke $ea.Expert $ea.Label "EURUSD"
    Smoke $ea.Expert $ea.Label "XAUUSD"
}

Log "=== ALL DONE ==="
