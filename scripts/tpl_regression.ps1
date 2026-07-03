<#
tpl_regression.ps1 - Boss V2 chassis smoke-regression (added 2026-07-03).

Purpose: Boss V2 has no unit-test suite. This is the substitute: run the 3 Boss
entry EAs with COMPILED DEFAULTS on a pinned window/model, extract PF / trades /
net profit, and compare against ea_template\regression_baseline.csv. Any core\
edit that changes these numbers (with all new modes OFF by default) = behavior
drift = investigate before merging. A default-value change also trips this on
purpose - defaults ARE behavior.

Usage:
  powershell -File scripts\tpl_regression.ps1                  # compare vs baseline
  powershell -File scripts\tpl_regression.ps1 -UpdateBaseline  # (re)capture baseline
Requires: MT5 GUI closed (mt5_run.ps1 guard). ~3 sequential tester runs.
#>
[CmdletBinding()]
param(
  [switch]$UpdateBaseline,
  [string]$Symbol = "XAUUSD",
  [string]$Period = "H1",
  [string]$FromDate = "2024.01.01",
  [string]$ToDate = "2024.07.01",
  [int]$Model = 1
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$baseline = Join-Path $root "ea_template\regression_baseline.csv"
$experts = @("EALabTpl\Boss_11_GridTrend", "EALabTpl\Boss_12_Breakout", "EALabTpl\Boss_13_MeanRev")

function Parse-Report([string]$htm) {
  # MT5 writes UTF-16LE with BOM; Get-Content -Raw decodes it via the BOM.
  $t = Get-Content $htm -Raw
  $t = $t -replace '<[^>]+>', '|'
  $parts = ($t -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $out = @{}
  $keys = @{ 'Total Net Profit:'='net'; 'Profit Factor:'='pf'; 'Total Trades:'='trades'; 'Equity Drawdown Maximal:'='eqdd' }
  for ($i = 0; $i -lt $parts.Count - 1; $i++) {
    if ($keys.ContainsKey($parts[$i])) { $out[$keys[$parts[$i]]] = ($parts[$i+1] -replace '\s','') }
  }
  return $out
}

$rows = @()
foreach ($e in $experts) {
  $name = ($e -split '\\')[-1]
  $rep = "TPLREG_$name"
  Write-Host ">> running $name ($Symbol $Period $FromDate-$ToDate Model $Model)" -ForegroundColor Cyan
  $res = & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $e -Symbol $Symbol -Period $Period `
          -FromDate $FromDate -ToDate $ToDate -Model $Model -ReportName $rep
  $htm = Join-Path $root "_mt5_auto\reports\$rep.htm"
  if (-not (Test-Path $htm)) { Write-Host "[FAIL] $name - no report produced ($res)" -ForegroundColor Red; exit 1 }
  $m = Parse-Report $htm
  $rows += [pscustomobject]@{ ea=$name; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
  Write-Host ("   net={0} pf={1} trades={2} eqdd={3}" -f $m['net'], $m['pf'], $m['trades'], $m['eqdd'])
}

if ($UpdateBaseline) {
  $rows | Export-Csv $baseline -NoTypeInformation -Encoding UTF8
  Write-Host "baseline written -> $baseline" -ForegroundColor Green
  exit 0
}

if (-not (Test-Path $baseline)) { Write-Host "no baseline - run with -UpdateBaseline first"; exit 1 }
$base = Import-Csv $baseline
$fail = 0
foreach ($r in $rows) {
  $b = $base | Where-Object ea -eq $r.ea
  if (-not $b) { Write-Host "[WARN] $($r.ea) not in baseline" -ForegroundColor Yellow; $fail++; continue }
  if (($b.net -ne $r.net) -or ($b.pf -ne $r.pf) -or ($b.trades -ne $r.trades)) {
    Write-Host ("[DRIFT] {0}: baseline net={1} pf={2} n={3}  now net={4} pf={5} n={6}" -f `
      $r.ea, $b.net, $b.pf, $b.trades, $r.net, $r.pf, $r.trades) -ForegroundColor Red
    $fail++
  } else {
    Write-Host "[OK] $($r.ea) matches baseline" -ForegroundColor Green
  }
}
if ($fail -gt 0) { Write-Host "=== REGRESSION: $fail drift(s) ===" -ForegroundColor Red; exit 1 }
Write-Host "=== REGRESSION CLEAN ===" -ForegroundColor Green
exit 0
