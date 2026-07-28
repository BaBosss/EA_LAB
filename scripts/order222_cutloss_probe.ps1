<#
order222_cutloss_probe.ps1 - ORDER-222: does NuiIndy's CutLoss_Percent=30 actually cut?

THE PROBLEM THIS EXISTS TO SOLVE
  NuiIndy is an uncapped-ruin martingale running real money (magic 1524, account 159475669).
  CutLoss_Percent is the only thing standing between it and a wipeout. ORDER-212 checked the
  provenance of the recommended value 30 and found it clean - but also found that the two runs
  behind it peaked at 15.40% and 16.56% equity drawdown against a 30% threshold. The switch has
  never fired in any evidence we hold. Those numbers prove the setting COSTS NOTHING, which is
  trivially true of a switch that never triggers, and say nothing about whether it PROTECTS.

  So the job is not to re-measure PF. It is to manufacture a drawdown big enough to reach the
  threshold and then watch what the switch does.

HOW THE RISK IS RAISED, AND WHY NOT BY LOWERING THE DEPOSIT
  Base lot in this EA is equity / Lot_Divided (500000 as shipped). Lot therefore scales WITH
  equity, so percentage drawdown is deposit-invariant: halving the deposit halves the lots and
  gets you the same %DD. The lever that actually moves %DD is Lot_Divided itself - dividing it
  by 2 doubles the lot carried against the same equity. That is what the ladder below walks.

  Escalation (Multiple3=1.2, applied per open order beyond 12) is deliberately NOT touched. It
  is the shape of the live configuration, and changing it would test a different EA.

STAGES
  0  control     - reproduce the 2022 cut30 run at the leverage the ini MEANT to ask for.
                   The two archived runs wrote `Leverage=100`, the numeric form, which the
                   tester silently ignores (ORDER-165); both reports came back at 1:2000. So the
                   evidence on file was measured with 20x the margin headroom it claimed. This
                   stage says whether that mattered.
  1  ladder      - CutLoss_Percent=100 (kill effectively off), Lot_Divided walked down until
                   equity drawdown exceeds 30%. Finding nothing here is itself a result: it
                   would mean the threshold is unreachable at live-shaped settings.
  2  ab          - at the first ladder rung that broke 30%, run CutLoss=30 against CutLoss=100.
                   PASS  = the cut fires AND the cut run ends better off than the uncut one.
                   DEAD  = the cut fires and leaves you WORSE off -> revisit the value 30, not
                           the mechanism.
                   MIDDLE= fires, outcome close -> keep it, and record it as a damage cap
                           rather than a return enhancer.

  Every run is Model 4 (basket martingale - fill behaviour is the whole story) and every run is
  checked against BOTH sidecars afterwards: a DD-kill truncates the report while leaving it
  looking like a normal full-window result, which for this order is the exact signal we want,
  not a nuisance.

USAGE
  powershell -File scripts\order222_cutloss_probe.ps1 -Stage 0
  powershell -File scripts\order222_cutloss_probe.ps1 -Stage 1
  powershell -File scripts\order222_cutloss_probe.ps1 -Stage 2 -LotDivided 125000
NEVER: touch the live account, use Model < 4, or run this on 2026H1 (the holdout).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('0','1','2')][string]$Stage,
  [string]$Symbol   = "EURUSD",
  [string]$Period   = "H1",
  [string]$FromDate = "2022.01.01",   # BWD stress year; NOT the holdout
  [string]$ToDate   = "2023.01.01",
  [int]$Deposit     = 10000,
  [int]$Leverage    = 100,
  [double]$LotDivided = 0,            # stage 2: the rung that broke 30%
  [int]$TimeoutSec  = 3600
)
$ErrorActionPreference = "Stop"
$root    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expert  = "(NuiIndy) Dynamic RSI+ADX Style (4)"
$baseSet = Join-Path $root "_mt5_auto\ab_sets\nuiindy_sets\NUI_cut30only.set"
$outDir  = Join-Path $root "_mt5_auto\ab_sets\order222"
$reports = Join-Path $root "_mt5_auto\reports"
New-Item -ItemType Directory -Force $outDir | Out-Null

function New-ProbeSet([string]$name, [hashtable]$over) {
  $seen = @{}
  $out = foreach ($l in (Get-Content $baseSet)) {
    if ($l -match '^([A-Za-z_][\w]*)=') {
      $k = $matches[1]
      if ($over.ContainsKey($k)) { $seen[$k] = $true; "$k=$($over[$k])" } else { $l }
    } else { $l }
  }
  foreach ($k in $over.Keys) { if (-not $seen.ContainsKey($k)) { $out += "$k=$($over[$k])" } }
  $p = Join-Path $outDir "$name.set"
  Set-Content -Path $p -Value $out -Encoding ASCII
  return $p
}

# Read what actually happened, from the report itself - never from what we asked for.
function Read-Result([string]$reportName) {
  $htm = Join-Path $reports "$reportName.htm"
  if (-not (Test-Path $htm)) { return $null }
  $flat  = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
  $parts = ($flat -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  function Field($label) {
    for ($i = 0; $i -lt $parts.Count - 1; $i++) { if ($parts[$i] -eq $label) { return $parts[$i+1] } }
    return $null
  }
  $eqdd = $null
  $raw = Field 'Equity Drawdown Maximal:'
  if ($raw) { $m = [regex]::Match($raw, '\((\d+(?:\.\d+)?)%\)'); if ($m.Success) { $eqdd = [double]$m.Groups[1].Value } }
  $pf = Field 'Profit Factor:'
  $tr = Field 'Total Trades:'
  $np = Field 'Total Net Profit:'
  $lev = $null
  $lm = [regex]::Match(($flat -replace '\|', ' '), 'Leverage:\s*1:(\d+)'); if ($lm.Success) { $lev = [int]$lm.Groups[1].Value }

  $trunc = $null
  $ts = Join-Path $reports "$reportName.truncation_check.json"
  if (Test-Path $ts) { $trunc = (Get-Content $ts -Raw | ConvertFrom-Json) }

  return [PSCustomObject]@{
    report = $reportName; pf = $pf; trades = $tr; net = $np; eqdd_pct = $eqdd; leverage = $lev
    truncated = $(if ($trunc) { $trunc.truncated } else { $null })
    trunc_detail = $(if ($trunc) { $trunc.detail } else { '' })
  }
}

# ORDER-372 (2026-07-28): this function used to call mt5_run.ps1 WITHOUT capturing its output.
# In PowerShell a function returns everything its body writes to the success stream, not just what
# `return` names - so mt5_run.ps1's own Write-Output diagnostics ("launch: ...", "NO REPORT ...",
# "ABORT: ...") became part of Invoke-Probe's return value. The caller then held a string[] instead
# of one object, `if ($r)` passed because a non-empty array is truthy, and `$r | Add-Member` threw
# "Cannot bind argument to parameter 'InputObject' because it is null" on the $null that `return
# $null` had appended. The crash therefore surfaced far from its cause AND swallowed the runner's
# real message - which on the run that exposed this said `ABORT: MT5 instance already running`,
# the one fact that would have explained everything immediately.
# Fix: capture the runner's output, print it as text, and keep the object as the only stream output.
function Invoke-Probe([string]$name, [string]$setPath) {
  Write-Host ">> $name" -ForegroundColor Cyan
  $runStart = Get-Date
  $runnerOut = & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $expert -Symbol $Symbol -Period $Period `
      -FromDate $FromDate -ToDate $ToDate -Model 4 -Deposit $Deposit -Leverage $Leverage `
      -SetFile $setPath -ReportName $name -TimeoutSec $TimeoutSec 2>&1
  $runnerExit = $LASTEXITCODE
  foreach ($line in @($runnerOut)) { Write-Host "   | $line" -ForegroundColor DarkGray }
  # mt5_run.ps1's exit codes are load-bearing and were previously discarded: 0 ok, 1 no report,
  # 2 abort (GUI/lane busy or terminal missing), 3 leverage mismatch. Naming the code turns a bare
  # "no report produced" into a diagnosis.
  $why = switch ($runnerExit) {
    1 { "runner exit 1 = NO REPORT (check EA name / symbol history / login)" }
    2 { "runner exit 2 = ABORT (MT5 instance for this install already running, or terminal not found)" }
    3 { "runner exit 3 = LEVERAGE MISMATCH (report kept but numbers are not comparable)" }
    default { $null }
  }
  # ORDER-372 second defect, found by end-to-end testing the fix above: an ABORTED run can report a
  # PREVIOUS run's numbers as if they were fresh. mt5_run.ps1's ORDER-094 D3 clear exists precisely to
  # stop "a stale report surviving a run that produced none" - but it runs AFTER the two `exit 2`
  # abort checks, so the abort path is the one hole it does not cover. Observed live: pointing the
  # runner at a non-existent terminal aborted with exit 2, and this probe then printed PF=1.77 off a
  # leftover .htm. File existence is NOT evidence that THIS run produced it, so gate on two things:
  #   (a) the exit code - 1 (no report) and 2 (abort) mean nothing was produced, whatever is on disk
  #   (b) the report's mtime - it must be newer than the moment this run started
  # Exit 3 is different: the report IS from this run, it just used the wrong leverage, so it stays a
  # warning rather than a refusal.
  if ($runnerExit -eq 1 -or $runnerExit -eq 2) {
    Write-Host "   [FAIL] runner produced no report - $why" -ForegroundColor Red
    Write-Host "          (any $name.htm on disk is from an EARLIER run and is deliberately ignored)" -ForegroundColor Red
    return $null
  }
  $htmPath = Join-Path $reports "$name.htm"
  if (Test-Path $htmPath) {
    $age = (Get-Item $htmPath).LastWriteTime
    if ($age -lt $runStart) {
      Write-Host ("   [FAIL] STALE REPORT: $name.htm was written {0}, before this run started {1} - refusing to report it as fresh." -f $age, $runStart) -ForegroundColor Red
      return $null
    }
  }
  $r = Read-Result $name
  if (-not $r) {
    Write-Host "   [FAIL] no report produced$(if ($why) { " - $why" })" -ForegroundColor Red
    return $null
  }
  if ($why) { Write-Host "   [WARN] $why" -ForegroundColor Yellow }
  # The leverage assertion is not decoration here: the archived evidence for this very setting
  # ran at 1:2000 while its ini asked for 1:100, and nobody noticed for nine days.
  $levNote = if ($r.leverage -eq $Leverage) { "leverage 1:$($r.leverage) OK" } else { "LEVERAGE 1:$($r.leverage) != requested 1:$Leverage" }
  Write-Host ("   PF=$($r.pf)  trades=$($r.trades)  net=$($r.net)  eqDD=$($r.eqdd_pct)%  $levNote  truncated=$($r.truncated)") `
    -ForegroundColor $(if ($r.leverage -eq $Leverage) { 'Green' } else { 'Red' })
  return $r
}

$results = @()

if ($Stage -eq '0') {
  Write-Host "=== STAGE 0: does the archived cut30 evidence survive being run at the leverage it asked for? ===" -ForegroundColor Cyan
  $s = New-ProbeSet 'O222_ctrl_cut30' @{ CutLoss_Percent = '30' }
  $results += Invoke-Probe 'O222_S0_cut30_lev100' $s
  Write-Host ""
  Write-Host "Compare against the archived 1:2000 run NUI_EURUSD_cut30only_2022: PF 1.19, 933 trades, eqDD 15.40%." -ForegroundColor Yellow
}
elseif ($Stage -eq '1') {
  Write-Host "=== STAGE 1: walk the lot up (CutLoss off) until equity drawdown passes 30% ===" -ForegroundColor Cyan
  foreach ($ld in @(250000, 125000, 62500, 31250)) {
    $s = New-ProbeSet ("O222_ld{0}_nocut" -f $ld) @{ Lot_Divided = "$ld.0"; CutLoss_Percent = '100' }
    $r = Invoke-Probe ("O222_S1_ld{0}_nocut" -f $ld) $s
    if ($r) { $r | Add-Member -NotePropertyName lot_divided -NotePropertyValue $ld; $results += $r }
    if ($r -and $r.eqdd_pct -ne $null -and $r.eqdd_pct -gt 30.0) {
      Write-Host ("   >> threshold reached at Lot_Divided=$ld (eqDD $($r.eqdd_pct)%). Run stage 2 with -LotDivided $ld") -ForegroundColor Green
      break
    }
  }
}
elseif ($Stage -eq '2') {
  if ($LotDivided -le 0) { Write-Host "[FAIL] -LotDivided is required for stage 2 (use the rung stage 1 found)" -ForegroundColor Red; exit 1 }
  Write-Host "=== STAGE 2: A/B the switch at a drawdown that actually reaches it ===" -ForegroundColor Cyan
  foreach ($cut in @(30, 100)) {
    $s = New-ProbeSet ("O222_ld{0}_cut{1}" -f $LotDivided, $cut) @{ Lot_Divided = "$LotDivided.0"; CutLoss_Percent = "$cut" }
    $r = Invoke-Probe ("O222_S2_ld{0}_cut{1}" -f $LotDivided, $cut) $s
    if ($r) { $r | Add-Member -NotePropertyName cutloss -NotePropertyValue $cut; $results += $r }
  }
  # @() so a single match stays a collection: a bare ($pipeline) is the scalar itself and a bare
  # ($pipeline).Count is $null - not 1 - when EXACTLY ONE item matches. Same class of silent pass
  # that hid 48 stale binaries in ORDER-341.
  $c30  = @($results | Where-Object { $_ -and $_.cutloss -eq 30 })  | Select-Object -First 1
  $c100 = @($results | Where-Object { $_ -and $_.cutloss -eq 100 }) | Select-Object -First 1
  if ($c30 -and $c100) {
    Write-Host ""
    # Identical output on both arms is the one answer that means "still untested". Say it plainly
    # rather than letting a matching PF read as a passing A/B.
    if (($c30.net -eq $c100.net) -and ($c30.trades -eq $c100.trades)) {
      Write-Host ">> [INCONCLUSIVE] both arms are identical - the kill STILL never fired. Push the risk further." -ForegroundColor Red
    } else {
      Write-Host ">> the arms diverge, so the switch did something. Judge it on net + eqDD, and confirm the cut arm's truncation sidecar says truncated=true (that IS the kill)." -ForegroundColor Green
    }
  }
}

Write-Host ""
$results | Where-Object { $_ } | Format-Table report, pf, trades, net, eqdd_pct, leverage, truncated -AutoSize
# Stage 2 is run once per rung, so the rung has to be in the filename - the first version of this
# script did not include it and the ld=125000 result file was silently overwritten by the ld=250000
# confirmation run. The reports themselves survived, so nothing was lost, but a results file that
# quietly replaces a different experiment's results is its own small version of this order's theme.
$suffix = if ($Stage -eq '2') { "2_ld{0}" -f $LotDivided } else { $Stage }
$csv = Join-Path $root ("_triage\ORDER222_probe_stage{0}.csv" -f $suffix)
# ORDER-372: `Where-Object { $_ }` drops $null but NOT strings, and under the output-leak bug above
# $results was mostly leaked runner text. Export-Csv on a string exports its .Length - which is why
# EVERY probe CSV in _triage predating this fix contains a "Length" column of byte counts instead of
# PF/trades/net/eqDD. That is also why the bug lived so long: on a run that SUCCEEDED it corrupted
# the CSV silently, and only crashed when a run failed and appended a $null for Add-Member to reject.
# Keep only real result objects, and never let an empty set overwrite a previous experiment's file.
$clean = @($results | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'report' })
if ($clean.Count -eq 0) {
  Write-Host "no usable results this run - leaving $csv untouched rather than blanking it" -ForegroundColor Yellow
} else {
  $clean | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
  Write-Host "results -> $csv"
}
