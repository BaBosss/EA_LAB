$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$auto = "D:\EA_LAB\_mt5_auto"
$log  = "$auto\gr_plateau_batch.log"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function Run($label, $setFile, $from, $to, $tag) {
    $rpt = "GR_${label}_${tag}"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP $rpt"; return }
    Log "START $rpt"
    try {
        & "$s\mt5_run.ps1" `
            -Expert "The Gold Reaper MT5_4.3_fix_@FundedMillionAiress" `
            -Symbol XAUUSD -Period H1 -Model 1 `
            -FromDate $from -ToDate $to `
            -SetFile $setFile `
            -ReportName $rpt
        Log "DONE $rpt"
    } catch { Log "ERROR $rpt : $($_.Exception.Message)" }
    Stop-Process -Name terminal64 -Force -EA SilentlyContinue
    Start-Sleep 3
}

Set-Content $log "" -Encoding UTF8
Log "=== GoldReaper plateau sweep START ==="
Log "IS=2023.01.01-2025.06.01  OOS=2025.06.01-2026.06.01  Model=M1 (1-min OHLC)"

$IS_FROM  = "2023.01.01"
$IS_TO    = "2025.06.01"
$OOS_FROM = "2025.06.01"
$OOS_TO   = "2026.06.01"

$default = "$auto\GoldReaper_cent_v1.set"
$ff1     = "$auto\GoldReaper_FF1.set"
$ff3     = "$auto\GoldReaper_FF3.set"

# IS sweep — all 3 FakeOutFilter values
Run "FF2" $default $IS_FROM $IS_TO "IS"
Run "FF1" $ff1     $IS_FROM $IS_TO "IS"
Run "FF3" $ff3     $IS_FROM $IS_TO "IS"

# OOS — default only (baseline); add FF1/FF3 OOS manually if IS shows improvement
Run "FF2" $default $OOS_FROM $OOS_TO "OOS"

Log "=== DONE - parse results then decide FF1/FF3 OOS ==="
