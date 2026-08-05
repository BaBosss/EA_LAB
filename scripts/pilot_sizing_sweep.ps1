<#
pilot_sizing_sweep.ps1 - ORDER-1240 (slice S13). Resolve the first lot MECHANICALLY.

WHAT QUESTION THIS ANSWERS, AND WHY IT IS NOT "WHICH LOT PERFORMS BEST". ORDER-1230 ran all 16 pilot
cells and every flat-lot probe came back UNTESTED-INERT: at _41_FixedLot=0.01 on a 0.01-step broker
the LOG-power progression is quantized away, so H01's escalated and flat-lot arms are byte-identical
trade lists and the pre-registered falsifier is satisfied by a mechanism that never ran.

Fixing that means choosing a first lot. Choosing it AFTER seeing which value produces the nicest PF
would be choosing the configuration having seen the result - the exact move ORDER-1220's
pre-registration exists to prevent, arriving through the back door. So the criterion is declared
first, it is mechanical, and it does not read PF at all:

    THE FIRST LOT IS THE SMALLEST VALUE ON THE DECLARED GRID AT WHICH THE FLAT-LOT PROBE
    RETURNS `EXERCISED` ON THE DECLARED REFERENCE CELL.

`EXERCISED` is pilot_probe_compare.py's verdict and it is a statement about the MEASUREMENT being
possible - the escalated arm placed more than one distinct volume and the trade lists differ - never
about the outcome. Nothing in this script inspects a profit factor, and that is deliberate: a
criterion that cannot see PF cannot be talked into a PF.

WHY THE SMALLEST AND NOT THE CLEANEST. Every step up in first lot is a step up in money at risk, on
a hypothesis whose class label is ENGINE-EDGE - permanently small sizing, never sized up on PF
(CLAUDE.md). The smallest value that makes the mechanism measurable is therefore the only defensible
one; anything larger is buying separation with risk the hypothesis is not allowed to spend.

THE GRID AND THE REFERENCE CELL ARE PINNED IN THIS FILE, committed before the sweep runs, so the
answer is a lookup and not a judgement. XAUUSD H1 is the reference because it has the most trades of
any cell in the matrix (180) and is the symbol tpl_regression already pins - a thin cell could return
INERT for want of a deep basket rather than for want of lot separation.

USAGE  powershell -NoProfile -File scripts\pilot_sizing_sweep.ps1
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  [string]$Revision  = 'B14-H01-r1',
  # DECLARED BEFORE THE RUN. 0.01 is the current (inert) value and is included as the NEGATIVE
  # CONTROL: if it does not come back INERT, the ORDER-1230 diagnosis is wrong and this sweep must
  # stop rather than pick a number. 0.10 is the known-EXERCISED anchor from ORDER-1230's control, so
  # the grid provably contains at least one of each answer and a sweep that returns all-INERT or
  # all-EXERCISED is a broken harness rather than a result.
  [double[]]$FirstLots = @(0.01, 0.02, 0.03, 0.04, 0.05, 0.10),
  [string]$Symbol    = 'XAUUSD',
  [string]$Period    = 'H1',
  [string]$FromDate  = '2023.01.01',
  [string]$ToDate    = '2025.12.31',
  [int]$Model        = 1,
  [string]$Parent    = 'EALabTpl\Boss_14_GridLog',
  [string]$Terminal  = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir   = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$OutDir    = ''
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py = Join-Path $root 'tools\python312\python.exe'
$env:PYTHONIOENCODING = 'utf-8'
if (-not $OutDir) { $OutDir = Join-Path $root 'factory\runs\pilot\_sizing' }
New-Item -ItemType Directory -Force $OutDir | Out-Null

. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
function Fail([string]$msg) { Write-Host ("[FAIL] " + $msg) -ForegroundColor Red; exit 1 }

Write-Host "=== ORDER-1240 sizing sweep -- MECHANICAL, and it never reads a profit factor ===" -ForegroundColor Cyan
Write-Host ("  criterion: the SMALLEST first lot at which the flat-lot probe returns EXERCISED") -ForegroundColor Cyan
Write-Host ("  reference: " + $Symbol + " " + $Period + " " + $FromDate + ".." + $ToDate + " model " + $Model) -ForegroundColor Cyan
Write-Host ("  lane     : " + $Terminal) -ForegroundColor Cyan
Write-Host ("  grid     : " + ($FirstLots -join ', ') + "   (0.01 = negative control, 0.10 = positive anchor)") -ForegroundColor Cyan

$pins = & $py -c @"
import sys
sys.path.insert(0, r'$root\_triage\factory_os')
import hypothesis_b14 as HB
for k, v in sorted(HB.HYPOTHESES['$Revision'.rsplit('-r', 1)[0]]['config'].items()):
    sys.stdout.write('%s=%s\n' % (k, v))
"@
if ($LASTEXITCODE -ne 0) { Fail ("could not read the pinned config for " + $Revision) }

function New-Set([string]$tag, [hashtable]$over) {
  $eff = [ordered]@{}
  foreach ($p in $pins) { if ($p.Trim()) { $kv = $p.Trim() -split '=', 2; $eff[$kv[0]] = $kv[1] } }
  foreach ($k in $over.Keys) { $eff[$k] = $over[$k] }
  $setFile = Join-Path $OutDir ('sizing_' + $tag + '.set')
  $genArgs = @((Join-Path $root '_triage\factory_os\gen_default_preset.py'), '--build', 'LAB_ENTRY_14', '--out', $setFile)
  foreach ($k in $eff.Keys) { $genArgs += @('--override', ($k + '=' + $eff[$k])) }
  $o = & $py $genArgs
  if ($LASTEXITCODE -ne 0) { Fail ("gen_default_preset.py refused for " + $tag + ": " + ($o -join ' ')) }
  return $setFile
}

function Invoke-Arm([string]$setPath, [string]$reportName) {
  $runStart = Get-Date
  & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $Parent -Symbol $Symbol -Period $Period `
      -FromDate $FromDate -ToDate $ToDate -SetFile $setPath -Model $Model `
      -ReportName $reportName -Terminal $Terminal -DataDir $DataDir | Out-Null
  $rc = $LASTEXITCODE
  if ($rc -ne 0) { Fail ($reportName + ": mt5_run.ps1 exited " + $rc + " -- the tester did not produce this run.") }
  $htm = Join-Path $root ('_mt5_auto\reports\' + $reportName + '.htm')
  if (-not (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $rc -Label $reportName)) {
    Fail ($reportName + ": the report is not evidence from THIS run.")
  }
  return $htm
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($lot in $FirstLots) {
  $tag = ('lot' + ($lot.ToString('0.00') -replace '\.', 'p'))
  Write-Host ""
  Write-Host (">> first lot " + $lot.ToString('0.00')) -ForegroundColor Cyan
  $escSet  = New-Set ($tag + '_esc')  @{ '_41_FixedLot' = $lot.ToString('0.00'); 'LotProg' = 'PROG_LOG_POWER' }
  $flatSet = New-Set ($tag + '_flat') @{ '_41_FixedLot' = $lot.ToString('0.00'); 'LotProg' = 'PROG_NONE' }
  $escHtm  = Invoke-Arm $escSet  ('S13SIZE_' + $tag + '_esc')
  $flatHtm = Invoke-Arm $flatSet ('S13SIZE_' + $tag + '_flat')

  $cmpJson = & $py (Join-Path $root 'scripts\pilot_probe_compare.py') $escHtm $flatHtm
  if ($LASTEXITCODE -ne 0) { Fail ("pilot_probe_compare.py failed at lot " + $lot) }
  $cmp = ($cmpJson -join "`n") | ConvertFrom-Json
  $results.Add([pscustomobject]@{
    first_lot = $lot; state = $cmp.probe_state
    volumes = ($cmp.escalated_distinct_volumes -join '/')
    deepest = $cmp.escalated_deepest_level
  }) | Out-Null
  Write-Host ("   " + $cmp.probe_state + "   escalated volumes: " + ($cmp.escalated_distinct_volumes -join ', ')) -ForegroundColor DarkGray
}

Write-Host ""
Write-Host ("  {0,10} {1,-16} {2,-24} {3}" -f 'first lot', 'probe', 'escalated volumes', 'deepest')
foreach ($r in $results) {
  $c = if ($r.state -eq 'EXERCISED') { 'Green' } else { 'Yellow' }
  Write-Host ("  {0,10:N2} {1,-16} {2,-24} L{3}" -f $r.first_lot, $r.state, $r.volumes, $r.deepest) -ForegroundColor $c
}

# --- the criterion, applied ------------------------------------------------------------------------
# @() on every filter: `(pipeline).Count` is $null when exactly one item matches.
$exercised = @($results | Where-Object { $_.state -eq 'EXERCISED' } | Sort-Object first_lot)
$control   = @($results | Where-Object { $_.first_lot -eq 0.01 })

Write-Host ""
# THE NEGATIVE CONTROL IS CHECKED BEFORE THE ANSWER IS READ. If 0.01 does not come back INERT then
# the ORDER-1230 diagnosis was wrong, and every number below is describing something else. A sweep
# that cannot reproduce the problem it was written to fix must not be allowed to pick a value.
if ($control.Count -eq 1 -and $control[0].state -eq 'EXERCISED') {
  Fail ("NEGATIVE CONTROL FAILED: first lot 0.01 came back EXERCISED, but ORDER-1230 measured it as INERT across all 16 cells. The diagnosis this sweep is built on does not reproduce, so no value is selected. Investigate before choosing anything.")
}
if ($exercised.Count -eq 0) {
  Fail ("no first lot on the declared grid returns EXERCISED, INCLUDING the 0.10 anchor that ORDER-1230's control measured as EXERCISED. That is a harness failure, not a result -- do not widen the grid until it is explained.")
}
if ($exercised.Count -eq $results.Count) {
  Fail ("EVERY value on the grid returns EXERCISED, including the 0.01 negative control. See above.")
}

$chosen = $exercised[0]
Write-Host ("=== CRITERION RESOLVES TO _41_FixedLot = " + $chosen.first_lot.ToString('0.00') + " ===") -ForegroundColor Green
Write-Host ("    the SMALLEST grid value returning EXERCISED (volumes " + $chosen.volumes + ", deepest L" + $chosen.deepest + ")")
Write-Host ("    negative control at 0.01: " + $control[0].state + "  <- the ORDER-1230 defect reproduces")
Write-Host ("    no profit factor was read to reach this number.") -ForegroundColor DarkGray

$outFile = Join-Path $OutDir 'sizing_sweep_result.json'
$payload = [ordered]@{
  entity = 'PilotSizingSweep'; order = 'ORDER-1240'
  criterion = 'the smallest first lot at which the flat-lot probe returns EXERCISED on the declared reference cell'
  criterion_reads_pf = $false
  reference_cell = ($Symbol + ' ' + $Period + ' ' + $FromDate + '..' + $ToDate + ' model ' + $Model)
  lane = $Terminal; revision = $Revision
  grid = $FirstLots; results = $results
  negative_control_0p01 = $control[0].state
  chosen_first_lot = $chosen.first_lot
}
$sw = New-Object System.IO.StreamWriter($outFile, $false, (New-Object System.Text.UTF8Encoding($false)))
$sw.WriteLine(($payload | ConvertTo-Json -Depth 8))
$sw.Close()
Write-Host ("    -> " + $outFile)
exit 0
