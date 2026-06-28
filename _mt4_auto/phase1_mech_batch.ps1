$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt4_auto\reports"
$auto = "D:\EA_LAB\_mt4_auto"
$log  = "$auto\phase1_mech_batch.log"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

function Run($label, $expert, $setFile) {
    $rpt = "MECH_$label"
    $dst = "$base\$rpt.htm"
    if (Test-Path $dst) { Log "SKIP $rpt"; return }
    Log "START $rpt ($expert)"
    try {
        & "$s\mt4_run.ps1" `
            -Expert $expert `
            -Symbol XAUUSD -Period H1 -Model 2 `
            -FromDate "2024.01.01" -ToDate "2025.06.01" `
            -SetFile $setFile `
            -ReportName $rpt
        Log "DONE $rpt"
    } catch { Log "ERROR $rpt : $($_.Exception.Message)" }
    Stop-Process -Name terminal -Force -EA SilentlyContinue
    Start-Sleep 3
}

Set-Content $log "" -Encoding UTF8
Log "=== MT4 Phase 1 Mechanism Gate START ==="
Log "Symbol=XAUUSD  Period=2024.01.01-2025.06.01  Model=M2 (open prices)"
Log "Goal: check lot escalation pattern - bounded vs uncapped martingale"

Run "Elephant" "EA_Golden_Elephant"  "$auto\ELEPHANT_base.set"
Run "GoldStuff" "Gold Stuff EA V7.0" "$auto\GOLDSTUFF_pipx10.set"

Log "=== DONE: inspect trade logs for lot escalation ==="


