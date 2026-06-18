$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\smoke_candidate5.log"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function Smoke($expert, $label, $symbol, $period="H1") {
    $rpt = "SMOKE_C5_${label}_${symbol}"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP $rpt (already done)"; return }
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
Log "=== SMOKE CANDIDATE5 START ==="

# MACD on new symbols (seeking low-correlation candidate #5)
$macdSymbols = @("EURGBP","AUDUSD","NZDUSD","GBPCHF","EURCHF","AUDNZD")
foreach ($sym in $macdSymbols) {
    Smoke "(ST) EA03 Count MACD v1" "MACD" $sym
}

# NuiIndy on new symbols
$nuiSymbols = @("GBPUSD","AUDUSD","NZDUSD","USDCHF","GBPCHF","AUDCAD")
foreach ($sym in $nuiSymbols) {
    Smoke "(NuiIndy) Dynamic RSI+ADX Style (4)" "NuiIndy" $sym
}

Log "=== ALL DONE ==="
Write-Output "Done. Check log at $log"
