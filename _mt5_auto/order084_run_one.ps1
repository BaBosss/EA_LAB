param(
  [Parameter(Mandatory)][int]$Bars,
  [Parameter(Mandatory)][string]$Sl,
  [Parameter(Mandatory)][string]$Tf,
  [Parameter(Mandatory)][string]$Window,
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate
)
$ErrorActionPreference = "Continue"
. D:\EA_LAB\scripts\use_python.ps1

$setFile = "D:\EA_LAB\_mt5_auto\ab_sets\order084_xauny\NY_b${Bars}_s${Sl}.set"
$reportName = "O084NY_b${Bars}_s${Sl}_${Tf}_${Window}"
$csvPath = "D:\EA_LAB\_mt5_auto\order084_xauny_sweep.csv"

function Append-Row($status, $pf, $net, $trades, $ddpct, $winpct) {
  $line = "$Bars,$Sl,$Tf,$Window,$pf,$net,$trades,$ddpct,$winpct,$status"
  Add-Content -Path $csvPath -Value $line
  Write-Output "ROW: $line"
}

$out = & powershell -File D:\EA_LAB\scripts\mt5_run.ps1 `
  -Expert "EA_XAU_NY" -Symbol XAUUSD -Period $Tf -Model 1 `
  -FromDate $FromDate -ToDate $ToDate -Deposit 10000 -Leverage 100 `
  -SetFile $setFile -ReportName $reportName `
  -Terminal "D:\Meta 5b\terminal64.exe" -DataDir "D:\Meta 5b" -Portable 2>&1
$out | ForEach-Object { Write-Output $_ }
$exitCode = $LASTEXITCODE

$reportPath = "D:\EA_LAB\_mt5_auto\reports\$reportName.htm"

if ($out -match "ABORT") {
  Append-Row "BUSY" "" "" "" "" ""
  exit 0
}
if ($exitCode -ne 0 -or -not (Test-Path $reportPath)) {
  Append-Row "NO_REPORT" "" "" "" "" ""
  exit 0
}

$parsed = & python D:\EA_LAB\scripts\parse_mt5_report.py $reportPath --json | ConvertFrom-Json
if (-not $parsed) {
  Append-Row "PARSE_ERROR" "" "" "" "" ""
  exit 0
}
$pf = $parsed.profit_factor
$net = $parsed.net_profit
$trades = $parsed.total_trades
$ddpct = $parsed.equity_drawdown_relative_pct
$winpct = $parsed.profit_trades_pct
Append-Row "OK" $pf $net $trades $ddpct $winpct
