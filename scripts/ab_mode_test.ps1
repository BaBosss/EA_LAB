<#
ab_mode_test.ps1 - compare a base MT5 backtest against the same set with overrides.

Runs two Model-1 backtests serially through mt5_run.ps1, parses both HTML reports,
prints a compact comparison table, and appends one CSV row to _mt5_auto\ab_results.csv.

Example:
  powershell -File scripts\ab_mode_test.ps1 `
    -Expert 'EALabTpl\Boss_11_GridTrend' -Symbol XAUUSD -Period H1 `
    -FromDate 2024.01.01 -ToDate 2024.07.01 `
    -BaseSet 'D:\EA_LAB\ea_template\sets\Boss11_regression_smoke.set' `
    -Overrides 'RecoveryMode=81' -Label 'boss11_rec81' `
    -Terminal 'D:\Meta 5b\terminal64.exe' -DataDir 'D:\Meta 5b' -Portable
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [Parameter(Mandatory)][string]$BaseSet,
  [Parameter(Mandatory)][string]$Overrides,
  [Parameter(Mandatory)][string]$Label,
  [string]$OutCsv = "D:\EA_LAB\_mt5_auto\ab_results.csv",
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355",
  [int]$TimeoutSec = 1800,
  [switch]$Portable
)
$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$runner = Join-Path $PSScriptRoot "mt5_run.ps1"
$tmpDir = Join-Path $root "_mt5_auto\ab_sets"
New-Item -ItemType Directory -Force $tmpDir, (Split-Path $OutCsv -Parent) | Out-Null

if (-not (Test-Path $runner))  { throw "mt5_run.ps1 not found: $runner" }
if (-not (Test-Path $BaseSet)) { throw "BaseSet not found: $BaseSet" }

function Get-SetMap([string]$Path) {
  $map = [ordered]@{}
  foreach ($line in Get-Content $Path) {
    $t = $line.Trim()
    if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) {
      $k, $v = $t.Split("=", 2)
      $map[$k.Trim()] = $v.Trim()
    }
  }
  return $map
}

function Apply-Overrides([System.Collections.IDictionary]$Base, [string]$Spec) {
  $map = [ordered]@{}
  foreach ($k in $Base.Keys) { $map[$k] = $Base[$k] }
  foreach ($part in $Spec.Split(";")) {
    $t = $part.Trim()
    if (-not $t) { continue }
    if (-not $t.Contains("=")) { throw "Invalid override fragment: $t" }
    $k, $v = $t.Split("=", 2)
    $map[$k.Trim()] = $v.Trim()
  }
  return $map
}

function Write-SetFile([string]$Path, [System.Collections.IDictionary]$Map, [string]$Header) {
  $lines = @("; $Header")
  foreach ($k in $Map.Keys) { $lines += "$k=$($Map[$k])" }
  [IO.File]::WriteAllLines($Path, $lines)
}

function Parse-Report([string]$HtmPath) {
  $text = Get-Content $HtmPath -Raw
  $text = $text -replace '<[^>]+>', '|'
  $parts = ($text -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $out = @{
    net = ""
    pf = ""
    trades = ""
    eqdd = ""
    baldd = ""
  }
  for ($i = 0; $i -lt $parts.Count - 1; $i++) {
    switch ($parts[$i]) {
      "Total Net Profit:" { $out.net = ($parts[$i + 1] -replace '\s', '') }
      "Profit Factor:" { $out.pf = ($parts[$i + 1] -replace '\s', '') }
      "Total Trades:" { $out.trades = ($parts[$i + 1] -replace '\s', '') }
      "Equity Drawdown Maximal:" { $out.eqdd = ($parts[$i + 1] -replace '\s', '') }
      "Balance Drawdown Maximal:" { $out.baldd = ($parts[$i + 1] -replace '\s', '') }
    }
  }
  return [pscustomobject]$out
}

function To-Scalar([string]$Value) {
  if (-not $Value) { return $null }
  $m = [regex]::Match($Value, '[-+]?\d+(?:,\d{3})*(?:\.\d+)?')
  if (-not $m.Success) { return $null }
  return [double]($m.Value -replace ',', '')
}

function Format-Delta($Value) {
  if ($null -eq $Value) { return "" }
  return "{0:+0.00;-0.00;0.00}" -f $Value
}

$baseMap = Get-SetMap $BaseSet
$variantMap = Apply-Overrides -Base $baseMap -Spec $Overrides
$safeLabel = ($Label -replace '[^A-Za-z0-9_.-]', '_')
$baseSetPath = Join-Path $tmpDir "${safeLabel}_base.set"
$variantSetPath = Join-Path $tmpDir "${safeLabel}_variant.set"
Write-SetFile -Path $baseSetPath -Map $baseMap -Header "$Label base"
Write-SetFile -Path $variantSetPath -Map $variantMap -Header "$Label variant :: $Overrides"

$baseReport = "AB_${safeLabel}_BASE"
$variantReport = "AB_${safeLabel}_VAR"
$runnerCommonArgs = @{
  Expert = $Expert
  Symbol = $Symbol
  Period = $Period
  FromDate = $FromDate
  ToDate = $ToDate
  Model = 1
  Terminal = $Terminal
  DataDir = $DataDir
  TimeoutSec = $TimeoutSec
}
if ($Portable) { $runnerCommonArgs.Portable = $true }

Write-Host ">> base run" -ForegroundColor Cyan
$baseOut = & $runner @runnerCommonArgs -SetFile $baseSetPath -ReportName $baseReport 2>&1 | Out-String
$baseHtm = Join-Path $root "_mt5_auto\reports\$baseReport.htm"
if (-not (Test-Path $baseHtm)) {
  throw "Base report not produced. Raw launcher output:`n$baseOut"
}

Write-Host ">> variant run ($Overrides)" -ForegroundColor Cyan
$variantOut = & $runner @runnerCommonArgs -SetFile $variantSetPath -ReportName $variantReport 2>&1 | Out-String
$variantHtm = Join-Path $root "_mt5_auto\reports\$variantReport.htm"
if (-not (Test-Path $variantHtm)) {
  throw "Variant report not produced. Raw launcher output:`n$variantOut"
}

$baseStats = Parse-Report $baseHtm
$variantStats = Parse-Report $variantHtm

$deltaNet = (To-Scalar $variantStats.net) - (To-Scalar $baseStats.net)
$deltaPf = (To-Scalar $variantStats.pf) - (To-Scalar $baseStats.pf)
$deltaTrades = (To-Scalar $variantStats.trades) - (To-Scalar $baseStats.trades)
$deltaEqdd = (To-Scalar $variantStats.eqdd) - (To-Scalar $baseStats.eqdd)
$deltaBaldd = (To-Scalar $variantStats.baldd) - (To-Scalar $baseStats.baldd)

$table = @(
  [pscustomobject]@{
    case = "base"
    net = $baseStats.net
    pf = $baseStats.pf
    trades = $baseStats.trades
    eqdd = $baseStats.eqdd
    baldd = $baseStats.baldd
    delta_net = ""
    delta_pf = ""
    delta_trades = ""
    delta_eqdd = ""
    delta_baldd = ""
  }
  [pscustomobject]@{
    case = "base+override"
    net = $variantStats.net
    pf = $variantStats.pf
    trades = $variantStats.trades
    eqdd = $variantStats.eqdd
    baldd = $variantStats.baldd
    delta_net = Format-Delta $deltaNet
    delta_pf = Format-Delta $deltaPf
    delta_trades = Format-Delta $deltaTrades
    delta_eqdd = Format-Delta $deltaEqdd
    delta_baldd = Format-Delta $deltaBaldd
  }
)

$table | Format-Table -AutoSize | Out-Host

$csvRow = [pscustomobject]@{
  timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  label = $Label
  expert = $Expert
  symbol = $Symbol
  period = $Period
  from = $FromDate
  to = $ToDate
  base_set = $BaseSet
  overrides = $Overrides
  base_report = $baseReport
  variant_report = $variantReport
  base_net = $baseStats.net
  variant_net = $variantStats.net
  delta_net = Format-Delta $deltaNet
  base_pf = $baseStats.pf
  variant_pf = $variantStats.pf
  delta_pf = Format-Delta $deltaPf
  base_trades = $baseStats.trades
  variant_trades = $variantStats.trades
  delta_trades = Format-Delta $deltaTrades
  base_eqdd = $baseStats.eqdd
  variant_eqdd = $variantStats.eqdd
  delta_eqdd = Format-Delta $deltaEqdd
  base_baldd = $baseStats.baldd
  variant_baldd = $variantStats.baldd
  delta_baldd = Format-Delta $deltaBaldd
}

$exists = Test-Path $OutCsv
$csvRow | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8 -Append:$exists
Write-Host "CSV appended -> $OutCsv" -ForegroundColor Green
