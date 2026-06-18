$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\validate_macd_chf.log"
$expert = "(ST) EA03 Count MACD v1"
$setf = "D:\EA_LAB\_mt5_auto\MACD_GBPUSD_locked.set"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function RunTest($symbol, $label, $from, $to) {
    $rpt = "MACDCHF_${label}"
    Log "START $rpt ($symbol $from..$to)"
    try {
        & "$s\mt5_run.ps1" -Expert $expert -Symbol $symbol -Period H1 -Model 1 `
            -FromDate $from -ToDate $to -SetFile $setf -ReportName $rpt -TimeoutSec 300
        Log "DONE $rpt"
    } catch { Log "ERROR $rpt : $($_.Exception.Message)" }
    Stop-Process -Name terminal64 -Force -EA SilentlyContinue
    Start-Sleep 3
}

Set-Content $log "" -Encoding UTF8
Log "=== VALIDATE MACD CHF pairs (IS 2023-2026 / OOS 2020-2023) ==="

# GBPCHF
RunTest "GBPCHF" "GBPCHF_IS"  "2023.01.01" "2026.06.01"
RunTest "GBPCHF" "GBPCHF_OOS" "2020.01.01" "2023.01.01"
# EURCHF
RunTest "EURCHF" "EURCHF_IS"  "2023.01.01" "2026.06.01"
RunTest "EURCHF" "EURCHF_OOS" "2020.01.01" "2023.01.01"

Log "=== DONE ==="
