# run_all_smoke.ps1
$ErrorActionPreference = "Stop"

$csvPath = "D:\EA_LAB\_mt5_autoucket_d_smoke_results.csv"
$mt5Parser = "D:\EA_LAB\scripts\parse_mt5_report.py"
$mt4Parser = "D:\EA_LAB\scripts\parse_mt4_report.py"
$mt5Runner = "D:\EA_LAB\scripts\mt5_run.ps1"
$mt4Runner = "D:\EA_LAB\scripts\mt4_run.ps1"

function Get-ProcessMetrics {
    param($reportPath, $parser)
    $result = python $parser $reportPath --json 2>&1
    $json = $result | Where-Object { $_ -match "^\s*\{" } | Select-Object -First 1
    if (-not $json) { return $null }
    return $json | ConvertFrom-Json
}

function Add-CSVRow {
    param($eaName, $track, $symbol, $period, $trades, $pf, $netProfit, $ddPct, $sharpe, $gate, $notes)
    $row = "$eaName,$track,$symbol,$period,$trades,$pf,$netProfit,$ddPct,$sharpe,$gate,$notes"
    Add-Content -Path $csvPath -Value $row
    Write-Output "  CSV: $eaName | $gate | PF=$pf | trades=$trades | $notes"
}

Write-Output "=== Starting all smoke tests ==="
