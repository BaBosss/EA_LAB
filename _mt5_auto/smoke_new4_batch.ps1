$ErrorActionPreference = "Continue"
$s   = "D:\EA_LAB\scripts"
$log = "D:\EA_LAB\_mt5_auto\smoke_new4.log"
$sets = "D:\EA_LAB\_mt5_auto\sweeps\_sets"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line; Add-Content $log $line -Encoding UTF8
}

Set-Content $log "" -Encoding UTF8
Log "=== BATCH START: 4 new EA concepts smoke tests ==="

$jobs = @(
    @{ Expert="EA_ZSCORE";     Symbol="EURUSD"; Period="H4"; Set="ZSCORE_smoke.set";    Label="ZSCORE_EUR_H4"   },
    @{ Expert="EA_ZSCORE";     Symbol="EURGBP"; Period="H4"; Set="ZSCORE_smoke.set";    Label="ZSCORE_EURGBP_H4"},
    @{ Expert="EA_XAU_NY";     Symbol="XAUUSD"; Period="H1"; Set="XAUNT_smoke.set";     Label="XAUNT_XAUUSD_H1" },
    @{ Expert="EA_KAUFMAN_ER"; Symbol="XAUUSD"; Period="H4"; Set="KAUERMAN_smoke.set";  Label="KER_XAUUSD_H4"   },
    @{ Expert="EA_KAUFMAN_ER"; Symbol="GBPUSD"; Period="H4"; Set="KAUERMAN_smoke.set";  Label="KER_GBPUSD_H4"   },
    @{ Expert="EA_IB_OCO";     Symbol="XAUUSD"; Period="H4"; Set="IBOCO_smoke.set";     Label="IBOCO_XAUUSD_H4" },
    @{ Expert="EA_IB_OCO";     Symbol="GBPUSD"; Period="H4"; Set="IBOCO_smoke.set";     Label="IBOCO_GBPUSD_H4" }
)

foreach ($j in $jobs) {
    $reportPath = "D:\EA_LAB\_mt5_auto\reports\$($j.Label).htm"
    if (Test-Path $reportPath) { Log "SKIP $($j.Label)"; continue }
    Log "RUN $($j.Label) $($j.Symbol) $($j.Period)"
    try {
        & "$s\mt5_run.ps1" -Expert $j.Expert -Symbol $j.Symbol -Period $j.Period -Model 2 `
            -FromDate "2023.01.01" -ToDate "2026.06.01" `
            -SetFile "$sets\$($j.Set)" -ReportName $j.Label
        Log "DONE $($j.Label)"
    } catch {
        Log "ERROR $($j.Label): $($_.Exception.Message)"
    }
}

Log "=== ALL DONE ==="
