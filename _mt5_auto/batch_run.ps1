$ErrorActionPreference = "Continue"
$s    = "D:\EA_LAB\scripts"
$base = "D:\EA_LAB\_mt5_auto\reports"
$log  = "D:\EA_LAB\_mt5_auto\batch_isoos_log.txt"

function Log($msg) {
    $line = "$((Get-Date -Format 'HH:mm:ss')) $msg"
    Write-Output $line
    Add-Content $log $line -Encoding UTF8
}

$jobs = @(
    @{Expert="Immortal Gold";                    Symbol="XAUUSD"; Period="H1"; Label="ImmortalGold"; SetFile=""},
    @{Expert="EA Among Us";                      Symbol="EURUSD"; Period="H1"; Label="EAAmongUs";    SetFile=""},
    @{Expert="(GPM) Almost 1 Direction v1.9.3"; Symbol="EURUSD"; Period="H1"; Label="GPM_1dir";     SetFile=""},
    @{Expert="Quantum Speed";                    Symbol="EURUSD"; Period="H1"; Label="QSpeed_b2";    SetFile="D:\EA_LAB\_mt5_auto\QSpeed_robust.set"},
    @{Expert="JanusGrid_EA_v2_5";               Symbol="EURUSD"; Period="H1"; Label="JanusGrid";    SetFile=""}
)

Set-Content $log "" -Encoding UTF8
Log "=== BATCH START ==="

foreach ($j in $jobs) {
    $sf = if ($j.SetFile) { @("-SetFile", $j.SetFile) } else { @() }

    if (Test-Path "$base\$($j.Label)_IS.htm") {
        Log "SKIP IS $($j.Label)"
    } else {
        Log "START IS $($j.Label) $($j.Symbol) $($j.Period)"
        try {
            & "$s\mt5_run.ps1" -Expert $j.Expert -Symbol $j.Symbol -Period $j.Period -Model 1 `
                -FromDate "2023.01.01" -ToDate "2026.06.01" -ReportName "$($j.Label)_IS" @sf
            Log "DONE IS $($j.Label)"
        } catch { Log "ERROR IS $($j.Label): $($_.Exception.Message)" }
    }

    if (Test-Path "$base\$($j.Label)_OOS.htm") {
        Log "SKIP OOS $($j.Label)"
    } else {
        Log "START OOS $($j.Label) $($j.Symbol) $($j.Period)"
        try {
            & "$s\mt5_run.ps1" -Expert $j.Expert -Symbol $j.Symbol -Period $j.Period -Model 1 `
                -FromDate "2020.01.01" -ToDate "2023.01.01" -ReportName "$($j.Label)_OOS" @sf
            Log "DONE OOS $($j.Label)"
        } catch { Log "ERROR OOS $($j.Label): $($_.Exception.Message)" }
    }
}

Log "=== ALL DONE ==="
