<#
ORDER-541 driver - Boss_14 GridLog symbol screen, 12 symbols x 2 arms.

WHAT IT RUNS (exactly what the order specifies, nothing more)
  A = flat-lot probe, StackMode=90  -> does the ENTRY have an edge on this pair
  B = grid,           StackMode=92  -> does the whole system make money
  Model 4, MAIN 2023.01.01-2025.12.31, lane D:\Meta 5c, base .set = Boss14_GridLog_AUDNZD_DEMO.set

  The base .set is copied to a *_flat.set for arm A; the original is never edited.

READS RESULTS THE ORDER'S WAY
  Every row records PF **with trades and DD% beside it**. A grid can clear a PF bar by barely
  being in the market (ORDER-430: the hosts that "survived" BWD took 52-62 trades while the ones
  that failed took 343-473), so PF alone cannot say whether a pair is resilient or just absent.

LABELS ARE TRIAGE, NOT VERDICTS
  A >= 1.2                -> entry-edge
  A < 1.0  AND B > 1.0    -> ENGINE-EDGE-CANDIDATE   (NOT "escalation-only", NOT dead: the
                             2026-07-19 carve-out retired that auto-kill)
  A and B < 1.0           -> no-pulse
  A 1.0-1.2               -> watch

Appends one CSV row per symbol as it goes, so a crash loses at most the cell in flight.
#>
$ErrorActionPreference = "Stop"
. (Join-Path "D:\EA_LAB\scripts" 'lib\report_freshness.ps1')

$root    = "D:\EA_LAB"
$runner  = "$root\scripts\mt5_run.ps1"
$baseSet = "$root\ea_template\sets\Boss14_GridLog_AUDNZD_DEMO.set"
$outDir  = "$root\_mt5_auto\ab_sets\order541"
$outCsv  = "$root\_mt5_auto\ORDER541_B14_SCREEN.csv"
$lane    = "D:\Meta 5c"
$reports = "$root\_mt5_auto\reports"
New-Item -ItemType Directory -Force $outDir | Out-Null

$symbols = @('NZDJPY','CADCHF','GBPCAD','EURAUD','AUDCHF','NZDCAD','CHFJPY','GBPCHF','EURNZD','AUDUSD','USDCAD','GBPNZD')

# arm A set: same file with StackMode forced to 90. Original untouched.
$flatSet = Join-Path $outDir "Boss14_GridLog_flat90.set"
$lines = Get-Content $baseSet
$seen = $false
$out = foreach ($l in $lines) {
  if ($l -match '^StackMode=') { $seen = $true; 'StackMode=90' } else { $l }
}
if (-not $seen) { $out += 'StackMode=90' }
Set-Content -Path $flatSet -Value $out -Encoding ASCII
Write-Output "arm-A set written: $flatSet (StackMode=90)"

if (-not (Test-Path $outCsv)) {
  'symbol,arm,stackmode,pf,trades,net,eqdd_pct,leverage,status' | Set-Content $outCsv -Encoding UTF8
}

function Read-Metrics([string]$reportName) {
  $htm = Join-Path $reports "$reportName.htm"
  if (-not (Test-Path $htm)) { return $null }
  $flat  = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
  $parts = ($flat -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  function F($label) {
    for ($i = 0; $i -lt $parts.Count - 1; $i++) { if ($parts[$i] -eq $label) { return $parts[$i+1] } }
    return $null
  }
  $eqdd = $null
  $raw = F 'Equity Drawdown Maximal:'
  if ($raw) { $m = [regex]::Match($raw, '\((\d+(?:\.\d+)?)%\)'); if ($m.Success) { $eqdd = [double]$m.Groups[1].Value } }
  $lev = $null
  $lm = [regex]::Match(($flat -replace '\|', ' '), 'Leverage:\s*1:(\d+)'); if ($lm.Success) { $lev = [int]$lm.Groups[1].Value }
  return [PSCustomObject]@{ pf=(F 'Profit Factor:'); trades=(F 'Total Trades:'); net=(F 'Total Net Profit:'); eqdd=$eqdd; lev=$lev }
}

$i = 0
foreach ($sym in $symbols) {
  $i++
  foreach ($arm in @(@{n='A'; set=$flatSet; sm=90}, @{n='B'; set=$baseSet; sm=92})) {
    $rep = "O541_${sym}_H1_MAIN_$($arm.n)"
    Write-Output ""
    Write-Output "[$i/12] $sym arm $($arm.n) (StackMode=$($arm.sm)) -> $rep"

    $runStart = Get-Date
    & $runner -Expert "EALabTpl\Boss_14_GridLog" -Symbol $sym -Period H1 `
        -FromDate 2023.01.01 -ToDate 2025.12.31 -Model 4 `
        -SetFile $arm.set -ReportName $rep `
        -Terminal "$lane\terminal64.exe" -DataDir $lane -Portable -TimeoutSec 5400 | Out-Null
    $runnerExit = $LASTEXITCODE

    $htm = Join-Path $reports "$rep.htm"
    if (-not (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $runnerExit -Label $rep)) {
      # NO-DATA vs FAIL cannot be told apart from here; the order says write it and move on rather
      # than stopping the sweep for one cell.
      "$sym,$($arm.n),$($arm.sm),,,,,,NO_FRESH_REPORT(exit=$runnerExit)" | Add-Content $outCsv -Encoding UTF8
      Write-Output "   -> NO FRESH REPORT (runner exit $runnerExit) - recorded and continuing"
      continue
    }
    $m = Read-Metrics $rep
    if (-not $m) {
      "$sym,$($arm.n),$($arm.sm),,,,,,PARSE_FAIL" | Add-Content $outCsv -Encoding UTF8
      Write-Output "   -> report present but unparsable"
      continue
    }
    "$sym,$($arm.n),$($arm.sm),$($m.pf),$($m.trades),$($m.net),$($m.eqdd),$($m.lev),OK" | Add-Content $outCsv -Encoding UTF8
    Write-Output "   -> PF=$($m.pf)  trades=$($m.trades)  net=$($m.net)  eqDD=$($m.eqdd)%  lev=1:$($m.lev)"
  }
}

Write-Output ""
Write-Output "DONE -> $outCsv"
Import-Csv $outCsv | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
