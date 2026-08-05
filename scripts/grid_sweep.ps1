# =============================== HOLDOUT-BURNED ===============================
# ORDER-238 (2026-07-27). One or more test windows in this file end after
# 2025.12.31 -- that is, inside the 2026H1 holdout. They are deliberately LEFT
# AS-IS: they record what past runs actually did, and rewriting them would
# misrepresent that history.
#
# Therefore: do NOT re-run this script to produce selection evidence, and do NOT
# copy its window into new work. A holdout is spent the first time it is touched.
# The current MAIN window is pinned in the VERDICT GATE section of CLAUDE.md.
#
# THIS FILE: the date appears only in the WINDOWS SPEC example in the header.
#   Windows are supplied by the caller -- but the example is what people copy.
# ==============================================================================
<#
grid_sweep.ps1 ? sequential parameter-grid backtest sweep for ONE EA on ONE symbol.

Expands a compact override spec into a cartesian grid, runs each combo as a single
Model-4 backtest via mt5_run.ps1 (which is the ONLY MT5 instance ? runs are serial),
parses the report, and appends one row per combo to an output CSV.

DESIGN NOTES
  * One MT5 INSTALL runs one tester at a time, so this script is sequential per install.
    For PARALLELISM, run a 2nd copy pointed at a different install via -Terminal/-DataDir/-Portable
    (e.g. D:\Meta 5b /portable). The process guard is scoped by exe path, so two installs do
    not abort each other. KEEP MODEL 4 SERIAL (every-tick = freeze risk on this box); only
    parallelize light Model-2 smokes.
  * Robust to a single bad combo: a backtest that yields no report is logged as a
    FAIL row and the sweep continues (no hang ? mt5_run.ps1 has its own timeout).
  * The EA must already be COMPILED into the terminal Experts folder. This script
    does NOT compile. (Lesson: editing the .mq5 + compiling to the source folder is
    NOT enough ? the .ex5 must live in <DataDir>\MQL5\Experts.)

OVERRIDES SPEC (compact cartesian):
  "Key1=a,b,c;Key2=x,y"  ->  all combinations of Key1 in {a,b,c} X Key2 in {x,y}
  Keys must match the .set parameter names exactly (e.g. _01_ConsoAtrMult).

WINDOWS SPEC (one or more test windows, label:from:to separated by ';'):
  "IS:2023.01.01:2025.06.01;OOS1:2025.06.01:2026.06.01;OOS2:2020.01.01:2022.12.31"

EXAMPLE:
  & .\grid_sweep.ps1 -Expert "(Boss)_LondonConsoBreakout_rev01" -Symbol GBPJPY -Period H1 `
      -BaseSet "D:\EA_LAB\_mt5_auto\CB_GBP_H1_IS_leader.set" `
      -Overrides "_01_ConsoAtrMult=1.0,1.5,2.0;_02_TpAtrMult=2.0,3.0,4.0" `
      -Windows "IS:2023.01.01:2025.06.01;OOS2:2020.01.01:2022.12.31" `
      -OutCsv "D:\EA_LAB\_mt5_auto\sweeps\CB_GBPJPY.csv" -ReportPrefix "CB_GBPJPY"
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$BaseSet,
  [Parameter(Mandatory)][string]$Overrides,
  [Parameter(Mandatory)][string]$Windows,
  [Parameter(Mandatory)][string]$OutCsv,
  [Parameter(Mandatory)][string]$ReportPrefix,
  [int]$Model = 4,
  [int]$PerTestTimeoutSec = 600,
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355",
  [switch]$Portable
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
$runner = "D:\EA_LAB\scripts\mt5_run.ps1"
if (-not (Test-Path $BaseSet)) { Write-Output "ABORT: base set not found: $BaseSet"; exit 2 }
if (-not (Test-Path $runner))  { Write-Output "ABORT: mt5_run.ps1 not found"; exit 2 }
New-Item -ItemType Directory -Force (Split-Path $OutCsv), "D:\EA_LAB\_mt5_auto\sweeps\_sets" | Out-Null

# ---- parse base set into an ordered map ----
$base = [ordered]@{}
foreach ($l in Get-Content $BaseSet) {
  $t = $l.Trim()
  if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) {
    $k,$v = $t.Split("=",2); $base[$k.Trim()] = $v.Trim()
  }
}

# ---- expand overrides into cartesian grid ----
$dims = @()
foreach ($part in $Overrides.Split(";")) {
  if (-not $part.Contains("=")) { continue }
  $k,$vals = $part.Split("=",2)
  $dims += ,@{ Key=$k.Trim(); Vals=@($vals.Split(",") | ForEach-Object { $_.Trim() }) }
}
$combos = @(@{})
foreach ($d in $dims) {
  $next = @()
  foreach ($c in $combos) { foreach ($v in $d.Vals) {
    $cc = @{}; foreach ($kk in $c.Keys) { $cc[$kk] = $c[$kk] }; $cc[$d.Key] = $v; $next += $cc
  } }
  $combos = $next
}

# ---- parse windows ----
$wins = @()
foreach ($w in $Windows.Split(";")) {
  $lbl,$from,$to = $w.Split(":",3); $wins += @{ Label=$lbl; From=$from; To=$to }
}

function Parse-Report($path) {
  $raw = [IO.File]::ReadAllText($path, [Text.Encoding]::Unicode)
  $txt = ($raw -replace '<[^>]+>', ' ') -replace '&nbsp;', ' '
  function Grab($label) {
    $m = [regex]::Match($txt, [regex]::Escape($label) + '\s*([-\d.,]+)')
    if ($m.Success) { return ($m.Groups[1].Value -replace ',', '') } return ''
  }
  $mdd = [regex]::Match($txt, 'Equity Drawdown Maximal:\s*([\d.,]+)\s*\(([\d.,]+)%\)')
  $win = [regex]::Match($txt, 'Profit Trades \(% of total\):\s*(\d+)\s*\(([\d.,]+)%\)')
  [PSCustomObject]@{
    PF     = Grab 'Profit Factor:'
    Net    = Grab 'Total Net Profit:'
    Trades = Grab 'Total Trades:'
    Sharpe = Grab 'Sharpe Ratio:'
    DDpct  = if ($mdd.Success) { $mdd.Groups[2].Value } else { '' }
    Win    = if ($win.Success) { $win.Groups[2].Value } else { '' }
  }
}

$total = $combos.Count * $wins.Count
Write-Output "SWEEP $ReportPrefix : $($combos.Count) combos x $($wins.Count) windows = $total runs"
$n = 0; $results = @()
for ($ci = 0; $ci -lt $combos.Count; $ci++) {
  $combo = $combos[$ci]
  # build the per-combo set
  $set = [ordered]@{}; foreach ($k in $base.Keys) { $set[$k] = $base[$k] }
  $tag = @(); foreach ($k in $combo.Keys) { $set[$k] = $combo[$k]; $tag += ($k -replace '^_\d+_','') + $combo[$k] }
  $tagStr = ($tag -join "_") -replace '[^A-Za-z0-9._]',''
  $setPath = "D:\EA_LAB\_mt5_auto\sweeps\_sets\${ReportPrefix}_c${ci}.set"
  $setLines = @("; $ReportPrefix combo $ci : $tagStr"); foreach ($k in $set.Keys) { $setLines += "$k=$($set[$k])" }
  [IO.File]::WriteAllLines($setPath, $setLines)

  foreach ($w in $wins) {
    $n++
    $rep = "${ReportPrefix}_c${ci}_$($w.Label)"
    Write-Output "[$n/$total] combo$ci $tagStr | $($w.Label) $($w.From)..$($w.To)"
    $runnerArgs = @{
      Expert = $Expert; Symbol = $Symbol; Period = $Period; Model = $Model
      FromDate = $w.From; ToDate = $w.To; SetFile = $setPath
      ReportName = $rep; TimeoutSec = $PerTestTimeoutSec
      Terminal = $Terminal; DataDir = $DataDir
    }
    if ($Portable) { $runnerArgs.Portable = $true }
    # ORDER-372: gate on the runner's exit code and the report's mtime. This script is already
    # marked HOLDOUT-BURNED and must not produce selection evidence, but a retired script that
    # still runs can still mislead, so it gets the same guard as the live ones.
    $runStart = Get-Date
    $out = & $runner @runnerArgs 2>&1 | Out-String
    $runnerExit = $LASTEXITCODE
    $repPath = "D:\EA_LAB\_mt5_auto\reports\$rep.htm"
    if (Test-ReportIsFresh -Htm $repPath -RunStart $runStart -RunnerExit $runnerExit -Label $rep) {
      $r = Parse-Report $repPath
      $row = [PSCustomObject]@{
        Combo=$ci; Params=$tagStr; Window=$w.Label; PF=$r.PF; Trades=$r.Trades
        Net=$r.Net; DDpct=$r.DDpct; Win=$r.Win; Sharpe=$r.Sharpe; Status="OK"
      }
    } else {
      $row = [PSCustomObject]@{
        Combo=$ci; Params=$tagStr; Window=$w.Label; PF=''; Trades=''
        Net=''; DDpct=''; Win=''; Sharpe=''; Status="NO_REPORT"
      }
    }
    $results += $row
    $results | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8   # rewrite each step = crash-safe
    Write-Output "    -> PF=$($row.PF) trades=$($row.Trades) DD%=$($row.DDpct) [$($row.Status)]"
  }
}
Write-Output "DONE $ReportPrefix : wrote $($results.Count) rows -> $OutCsv"
