$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\isoos_batch3.log"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function RunTest($expert, $label, $symbol, $period, $from, $to, $tag) {
    $rpt = "${label}_${tag}"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP $rpt"; return }
    Log "START $rpt"
    try {
        & "$s\mt5_run.ps1" -Expert $expert -Symbol $symbol -Period $period -Model 1 `
            -FromDate $from -ToDate $to -ReportName $rpt
        Log "DONE $rpt"
    } catch { Log "ERROR $rpt : $($_.Exception.Message)" }
    Stop-Process -Name terminal64 -Force -EA SilentlyContinue
    Start-Sleep 3
}

Set-Content $log "" -Encoding UTF8
Log "=== IS/OOS BATCH3 START ==="

$jobs = @(
    @{Expert="(NuiIndy) Dynamic RSI+ADX Style (4)"; Label="NuiIndy_RSI_ADX"; Symbol="EURUSD"; Period="H1"},
    @{Expert="(ST) EA03 Count MACD v1";              Label="ST_EA03_MACD";    Symbol="EURUSD"; Period="H1"},
    @{Expert="(Oh) Grid Upper lower V23";            Label="Oh_GridUL_V23";   Symbol="EURUSD"; Period="H1"}
)

foreach ($j in $jobs) {
    RunTest $j.Expert $j.Label $j.Symbol $j.Period "2023.01.01" "2026.06.01" "IS"
    RunTest $j.Expert $j.Label $j.Symbol $j.Period "2020.01.01" "2023.01.01" "OOS"
}

Log "=== ALL DONE ==="
