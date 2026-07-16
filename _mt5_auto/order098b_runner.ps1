<#
order098b_runner.ps1 — sequential smoke/plateau runner for ORDER-098-B (MacdDiv_Naked).
Runs a filtered subset of a pre-registered run list, parses each report, appends one
row per run to D:\EA_LAB\_mt5_auto\order098b_bwd_plateau.csv. Foreground/synchronous only.
#>
param(
  [string[]]$Only = @(),   # ReportName filter; empty = run everything in $runs
  [string]$CsvPath = "D:\EA_LAB\_mt5_auto\order098b_bwd_plateau.csv"
)
$ErrorActionPreference = "Stop"
$auto = "D:\EA_LAB\_mt5_auto"
$setsDir = "$auto\ab_sets\order098b"
$nbDir = "$setsDir\neighbors"

# dot-source portable python
. D:\EA_LAB\scripts\use_python.ps1

$BWD_FROM = "2020.01.01"; $BWD_TO = "2023.01.01"
$MAIN_FROM = "2023.01.01"; $MAIN_TO = "2026.01.01"
$HOLDOUT_FROM = "2026.01.01"; $HOLDOUT_TO = "2026.07.01"

$runs = @()

# --- Block 1: BWD window, 4 center cells ---
$runs += @{cell="EUR_H1"; window="BWD"; variant="center"; param_changed=""; symbol="EURUSD"; period="H1"; from=$BWD_FROM; to=$BWD_TO; set="$setsDir\MacdDiv_Naked_EURUSD_H1_optPF.set"; name="O098B_BWD_EURUSD_H1"}
$runs += @{cell="EUR_H4"; window="BWD"; variant="center"; param_changed=""; symbol="EURUSD"; period="H4"; from=$BWD_FROM; to=$BWD_TO; set="$setsDir\MacdDiv_Naked_EURUSD_H4_optPF.set"; name="O098B_BWD_EURUSD_H4"}
$runs += @{cell="XAU_H1"; window="BWD"; variant="center"; param_changed=""; symbol="XAUUSD"; period="H1"; from=$BWD_FROM; to=$BWD_TO; set="$setsDir\MacdDiv_Naked_XAUUSD_H1_optPF.set"; name="O098B_BWD_XAUUSD_H1"}
$runs += @{cell="XAU_H4"; window="BWD"; variant="center"; param_changed=""; symbol="XAUUSD"; period="H4"; from=$BWD_FROM; to=$BWD_TO; set="$setsDir\MacdDiv_Naked_XAUUSD_H4_optPF.set"; name="O098B_BWD_XAUUSD_H4"}

# --- Block 2: MAIN window, H4 neighbor plateau, XAUUSD ---
$xauNb = @(
  @{p="Slow36"; f="XAU_H4_Slow36.set"}, @{p="Slow40"; f="XAU_H4_Slow40.set"}, @{p="Slow48"; f="XAU_H4_Slow48.set"},
  @{p="Fast10"; f="XAU_H4_Fast10.set"}, @{p="Fast16"; f="XAU_H4_Fast16.set"},
  @{p="Buf0.10"; f="XAU_H4_Buf0.10.set"}, @{p="Buf0.25"; f="XAU_H4_Buf0.25.set"},
  @{p="ATRp14"; f="XAU_H4_ATRp14.set"}, @{p="ATRp26"; f="XAU_H4_ATRp26.set"}
)
foreach ($nb in $xauNb) {
  $runs += @{cell="XAU_H4"; window="MAIN"; variant="neighbor"; param_changed=$nb.p; symbol="XAUUSD"; period="H4"; from=$MAIN_FROM; to=$MAIN_TO; set="$nbDir\$($nb.f)"; name="O098B_NB_XAU_H4_$($nb.p)"}
}

# --- Block 2: MAIN window, H4 neighbor plateau, EURUSD ---
$eurNb = @(
  @{p="Slow32"; f="EUR_H4_Slow32.set"}, @{p="Slow40"; f="EUR_H4_Slow40.set"}, @{p="Slow44"; f="EUR_H4_Slow44.set"},
  @{p="Fast14"; f="EUR_H4_Fast14.set"}, @{p="Fast22"; f="EUR_H4_Fast22.set"},
  @{p="Buf0.10"; f="EUR_H4_Buf0.10.set"}, @{p="Buf0.15"; f="EUR_H4_Buf0.15.set"},
  @{p="ATRp10"; f="EUR_H4_ATRp10.set"}, @{p="ATRp18"; f="EUR_H4_ATRp18.set"}
)
foreach ($nb in $eurNb) {
  $runs += @{cell="EUR_H4"; window="MAIN"; variant="neighbor"; param_changed=$nb.p; symbol="EURUSD"; period="H4"; from=$MAIN_FROM; to=$MAIN_TO; set="$nbDir\$($nb.f)"; name="O098B_NB_EUR_H4_$($nb.p)"}
}

# --- Block 3: BWD confirm for top-2 highest-MAIN-PF H4 neighbors per cell ---
# XAU_H4 MAIN PF ranking: ATRp26=1.90, ATRp14=1.89 (top 2) > Slow48=1.85 > ...
# EUR_H4 MAIN PF ranking: ATRp10=1.70, ATRp18=1.70 (tied top 2, tie-break by Net) > Slow44=1.67 > ...
$runs += @{cell="XAU_H4"; window="BWD"; variant="neighbor"; param_changed="ATRp26"; symbol="XAUUSD"; period="H4"; from=$BWD_FROM; to=$BWD_TO; set="$nbDir\XAU_H4_ATRp26.set"; name="O098B_NBBWD_XAU_H4_ATRp26"}
$runs += @{cell="XAU_H4"; window="BWD"; variant="neighbor"; param_changed="ATRp14"; symbol="XAUUSD"; period="H4"; from=$BWD_FROM; to=$BWD_TO; set="$nbDir\XAU_H4_ATRp14.set"; name="O098B_NBBWD_XAU_H4_ATRp14"}
$runs += @{cell="EUR_H4"; window="BWD"; variant="neighbor"; param_changed="ATRp10"; symbol="EURUSD"; period="H4"; from=$BWD_FROM; to=$BWD_TO; set="$nbDir\EUR_H4_ATRp10.set"; name="O098B_NBBWD_EUR_H4_ATRp10"}
$runs += @{cell="EUR_H4"; window="BWD"; variant="neighbor"; param_changed="ATRp18"; symbol="EURUSD"; period="H4"; from=$BWD_FROM; to=$BWD_TO; set="$nbDir\EUR_H4_ATRp18.set"; name="O098B_NBBWD_EUR_H4_ATRp18"}

# --- Block 4: HOLDOUT window (never used for selection), center optPF sets, H4 only ---
$runs += @{cell="EUR_H4"; window="HOLDOUT"; variant="center"; param_changed=""; symbol="EURUSD"; period="H4"; from=$HOLDOUT_FROM; to=$HOLDOUT_TO; set="$setsDir\MacdDiv_Naked_EURUSD_H4_optPF.set"; name="O098B_HOLDOUT_EURUSD_H4"}
$runs += @{cell="XAU_H4"; window="HOLDOUT"; variant="center"; param_changed=""; symbol="XAUUSD"; period="H4"; from=$HOLDOUT_FROM; to=$HOLDOUT_TO; set="$setsDir\MacdDiv_Naked_XAUUSD_H4_optPF.set"; name="O098B_HOLDOUT_XAUUSD_H4"}

if ($Only.Count -gt 0) {
  $runs = $runs | Where-Object { $Only -contains $_.name }
}

if (-not (Test-Path $CsvPath)) {
  "cell,window,variant,param_changed,PF,Net,Trades,DDpct,WinPct,status" | Out-File -FilePath $CsvPath -Encoding utf8
}

foreach ($r in $runs) {
  Write-Output "=== RUN: $($r.name) ($($r.cell) $($r.window) $($r.variant) $($r.param_changed)) ==="
  $out = & powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "MacdDiv_Naked" -Symbol $r.symbol -Period $r.period -Model 1 -FromDate $r.from -ToDate $r.to -SetFile $r.set -ReportName $r.name -TimeoutSec 600 2>&1 | Out-String
  Write-Output $out

  $status = "ERROR"
  $reportPath = "$auto\reports\$($r.name).htm"
  if ($out -match "OK REPORT") { $status = "OK" }
  elseif ($out -match "TIMEOUT") { $status = "TIMEOUT" }
  elseif ($out -match "ABORT: MT5 instance") {
    Write-Output "BUSY - waiting 30s and retrying once..."
    Start-Sleep -Seconds 30
    $out2 = & powershell -File D:\EA_LAB\scripts\mt5_run.ps1 -Expert "MacdDiv_Naked" -Symbol $r.symbol -Period $r.period -Model 1 -FromDate $r.from -ToDate $r.to -SetFile $r.set -ReportName $r.name -TimeoutSec 600 2>&1 | Out-String
    Write-Output $out2
    if ($out2 -match "OK REPORT") { $status = "OK" }
    elseif ($out2 -match "TIMEOUT") { $status = "TIMEOUT" }
    else { $status = "BUSY" }
  }
  elseif ($out -match "NO REPORT") { $status = "ERROR" }

  $PF=""; $Net=""; $Trades=""; $DD=""; $Win=""
  if ($status -eq "OK" -and (Test-Path $reportPath)) {
    try {
      $j = python D:\EA_LAB\scripts\parse_mt5_report.py $reportPath --json | Out-String
      $obj = $j | ConvertFrom-Json
      $PF = $obj.profit_factor
      $Net = $obj.net_profit
      $Trades = $obj.total_trades
      $DD = $obj.equity_drawdown_relative_pct
      $Win = $obj.profit_trades_pct
    } catch {
      Write-Output "PARSE ERROR for $($r.name): $($_.Exception.Message)"
      $status = "ERROR"
    }
  }

  $row = '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}' -f $r.cell,$r.window,$r.variant,$r.param_changed,$PF,$Net,$Trades,$DD,$Win,$status
  Add-Content -Path $CsvPath -Value $row
  Write-Output "ROW: $row"
}
Write-Output "DONE."
