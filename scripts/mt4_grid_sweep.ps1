<#
mt4_grid_sweep.ps1 — deterministic grid optimization for an MT4 EA.

WHY not genetic: MT4's headless optimization .htm gives per-pass metrics but NOT
the parameter values, so you cannot lock the winning .set. A grid sweep generates
one labeled .set per combo, runs it via mt4_run.ps1, and records params+metrics
together. It also enables PLATEAU selection (pick a combo whose neighbours are
also good) instead of the overfit-prone single best pass.

Edit the $base lines + $grid hashtable for each EA, then run. Results -> CSV
with every swept param column + PF/trades/DD so select-plateau is possible.

Sequential by necessity (MT4 single-instance). ~8-12s/combo on Model 2.
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [Parameter(Mandatory)][string]$Tag,            # report/label prefix, e.g. SWEEP_KRAPOOK_EUR
  [Parameter(Mandatory)][string]$BaseSet,        # path to a .set with all FIXED (non-swept) lines
  [Parameter(Mandatory)][string]$GridJson,       # JSON: {"FieldA":[..],"FieldB":[..],"FieldC":[..]}
  [int]$Model = 2,
  [string]$OutCsv = ""
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
$auto = "D:\EA_LAB\_mt4_auto"
$sweepDir = "$auto\sweeps"
New-Item -ItemType Directory -Force $sweepDir | Out-Null
if (-not $OutCsv) { $OutCsv = "$sweepDir\$Tag.csv" }

$grid = $GridJson | ConvertFrom-Json
$fields = $grid.PSObject.Properties.Name
$baseLines = Get-Content $BaseSet | Where-Object { $_.Trim() -and $_.Contains("=") }

# build the cartesian product of the grid
$combos = @(@{})
foreach ($f in $fields) {
  $next = @()
  foreach ($c in $combos) {
    foreach ($v in $grid.$f) {
      $nc = $c.Clone(); $nc[$f] = $v; $next += $nc
    }
  }
  $combos = $next
}
Write-Output "GRID: $($combos.Count) combos over [$($fields -join ', ')] | $Expert | $Symbol"

# CSV header
($fields + @("trades","PF","net","DD%","win%")) -join "," | Out-File $OutCsv -Encoding utf8

$i = 0
foreach ($c in $combos) {
  $i++
  $rn = "$Tag" + "_$i"
  # write per-combo .set: base lines, then override swept fields
  $lines = @()
  foreach ($bl in $baseLines) {
    $k = ($bl -split "=",2)[0].Trim()
    if ($fields -notcontains $k) { $lines += $bl }
  }
  foreach ($f in $fields) { $lines += "$f=$($c[$f])" }
  $setPath = "$sweepDir\$rn.set"
  [IO.File]::WriteAllLines($setPath, $lines)

  Get-Process terminal -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 1500
  # ORDER-372: gate on the runner's exit code and the report's mtime - a cell whose run aborted
  # would otherwise re-record the SAME cell's numbers from a previous sweep, which does not look
  # wrong in the output, it looks reproducible.
  $runStart = Get-Date
  & "D:\EA_LAB\scripts\mt4_run.ps1" -Expert $Expert -Symbol $Symbol -FromDate $FromDate -ToDate $ToDate -SetFile $setPath -Model $Model -ReportName $rn -TimeoutSec 150 | Out-Null
  $runnerExit = $LASTEXITCODE

  $rep = "$auto\reports\$rn.htm"
  $vals = $fields | ForEach-Object { $c[$_] }
  if (Test-ReportIsFresh -Htm $rep -RunStart $runStart -RunnerExit $runnerExit -Label $rn) {
    $csvRow = & python "D:\EA_LAB\scripts\parse_mt4_report.py" $rep --csv 2>$null
    # parse_mt4_report --csv cols: expert,symbol,period,total_trades,profit_factor,net_profit,max_drawdown_pct,win_pct,quality,screen
    $p = $csvRow -split ","
    $row = ($vals + @($p[3], $p[4], $p[5], $p[6], $p[7])) -join ","
  } else {
    $row = ($vals + @("NO_REPORT","","","","")) -join ","
  }
  $row | Out-File $OutCsv -Append -Encoding utf8
  Write-Output "[$i/$($combos.Count)] $($fields | ForEach-Object {"$_=$($c[$_])"} ) -> $(if(Test-Path $rep){'ok'}else{'NO_REPORT'})"
}
Write-Output "DONE -> $OutCsv"
