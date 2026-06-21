# v3 filter comparison — MACD 12/26/9, SL300/TP400, GBPUSD H1, 2023-2026 (ceiling window).
# 4 variants: RSI/EMA filters on/off. Direct single backtests (reliable, no optimizer).
# Goal: does RSI+EMA beat the PF=1.11 MACD+ZLF ceiling?

$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$run  = "D:\EA_LAB\scripts\mt5_run.ps1"

# Common base inputs (MACD 12/26/9, SL300/TP400, no ZLF — v3 uses RSI/EMA instead)
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
InpEmaPeriod=50
"@

$variants = @(
  @{ name="A_noRSI_noEMA"; rsi="false"; ema="false" },
  @{ name="B_RSI_noEMA";   rsi="true";  ema="false" },
  @{ name="C_noRSI_EMA";   rsi="false"; ema="true"  },
  @{ name="D_RSI_EMA";     rsi="true";  ema="true"  }
)

$results = @()
foreach ($v in $variants) {
  $setPath = "$auto\v3cmp_$($v.name).set"
  $content = $base + "`nInpUseRsiFilter=$($v.rsi)`nInpUseEmaFilter=$($v.ema)`n"
  [IO.File]::WriteAllText($setPath, $content)

  $report = "V3CMP_$($v.name)"
  Write-Host "=== Running $($v.name) (RSI=$($v.rsi) EMA=$($v.ema)) ==="
  & $run -Expert "EA_RUNNER" -Symbol GBPUSD -Period H1 `
         -FromDate 2023.01.01 -ToDate 2026.01.01 `
         -SetFile $setPath -Model 2 -ReportName $report -TimeoutSec 600 | Out-Host

  $htm = "$auto\reports\$report.htm"
  if (Test-Path $htm) {
    $raw = Get-Content $htm -Raw
    # Profit Factor
    $pf = if ($raw -match "Profit Factor[:</td>\s]*</td>\s*<td[^>]*>\s*<b>([0-9.]+)") { $matches[1] }
          elseif ($raw -match "Profit Factor.*?([0-9]+\.[0-9]+)") { $matches[1] } else { "?" }
    # Total trades
    $tr = if ($raw -match "Total Trades[:</td>\s]*</td>\s*<td[^>]*>\s*<b>([0-9]+)") { $matches[1] }
          elseif ($raw -match "Total Trades.*?([0-9]+)") { $matches[1] } else { "?" }
    # Total net profit
    $np = if ($raw -match "Total Net Profit[:</td>\s]*</td>\s*<td[^>]*>\s*<b>(-?[0-9. ]+)") { $matches[1].Trim() } else { "?" }
    $results += [PSCustomObject]@{ Variant=$v.name; PF=$pf; Trades=$tr; NetProfit=$np }
  } else {
    $results += [PSCustomObject]@{ Variant=$v.name; PF="NO REPORT"; Trades="-"; NetProfit="-" }
  }
}

Write-Host "`n========== V3 FILTER COMPARISON (GBPUSD H1 2023-2026, MACD 12/26/9 SL300/TP400) =========="
$results | Format-Table -AutoSize
Write-Host "Ceiling to beat: MACD+ZLF = PF 1.11"
