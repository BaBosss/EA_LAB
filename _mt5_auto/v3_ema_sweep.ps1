# v3 EMA-period sweep — EMA-only (RSI dropped, it's dead weight), MACD 12/26/9,
# SL300/TP400, GBPUSD H1 2023-2026. Finds v3's true ceiling vs MACD+ZLF=1.11.

$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$run  = "D:\EA_LAB\scripts\mt5_run.ps1"

$base = @"
InpAllowLiveOrders=true
InpUseZeroLineFilter=false
InpMinCrossStrength=0.0
InpCountBars=0
InpVerboseLogging=false
InpHoldBars=0
InpStopLossPoints=300
InpTakeProfitPoints=400
InpMacdFast=12
InpMacdSlow=26
InpMacdSignal=9
InpRsiPeriod=14
InpRsiOverbought=70.0
InpRsiOversold=30.0
InpUseRsiFilter=false
InpUseEmaFilter=true
"@

$periods = @(20, 30, 50, 100, 200)
$results = @()
foreach ($ep in $periods) {
  $setPath = "$auto\v3ema_$ep.set"
  [IO.File]::WriteAllText($setPath, $base + "`nInpEmaPeriod=$ep`n")
  $report = "V3EMA_$ep"
  Write-Host "=== EMA period $ep ==="
  & $run -Expert "EA_RUNNER" -Symbol GBPUSD -Period H1 `
         -FromDate 2023.01.01 -ToDate 2026.01.01 `
         -SetFile $setPath -Model 2 -ReportName $report -TimeoutSec 600 | Out-Host
  $htm = "$auto\reports\$report.htm"
  if (Test-Path $htm) {
    $raw = Get-Content $htm -Raw
    $pf = if ($raw -match "Profit Factor.*?([0-9]+\.[0-9]+)") { $matches[1] } else { "?" }
    $tr = if ($raw -match "Total Trades.*?([0-9]+)") { $matches[1] } else { "?" }
    $np = if ($raw -match "Total Net Profit[:</td>\s]*</td>\s*<td[^>]*>\s*<b>(-?[0-9. ]+)") { $matches[1].Trim() } else { "?" }
    $results += [PSCustomObject]@{ EMAperiod=$ep; PF=$pf; Trades=$tr; NetProfit=$np }
  } else {
    $results += [PSCustomObject]@{ EMAperiod=$ep; PF="NO REPORT"; Trades="-"; NetProfit="-" }
  }
}
Write-Host "`n========== V3 EMA-PERIOD SWEEP (EMA-only, GBPUSD H1 2023-2026) =========="
$results | Format-Table -AutoSize
Write-Host "Ceiling to beat: MACD+ZLF = PF 1.11"
