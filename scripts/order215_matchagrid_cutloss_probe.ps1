<#
order215_matchagrid_cutloss_probe.ps1 - ORDER-215: does MatchaGrid's InpCutLossMode=0 ever cut anything?

THE PROBLEM THIS EXISTS TO SOLVE
  MatchaGrid runs real money on account 159475669 (magic 20240001). Every report on file for it -
  including the one behind the scorecard's headline PF 2.08 - was launched with an .ini that only
  pins the 5 grid-shape inputs (InpLotStart/InpStepAddLot/InpStepEveryOrders/InpProfitTarget/
  InpGridPoints). The InpCutLoss* family (Mode/Percent/Fixed/BuySide/SellSide/Total) was NEVER listed
  in any .ini's [TesterInputs] - which per mt5_run.ps1's own ORDER-165 gotcha means those five values
  came from whatever happened to be cached in this terminal's MQL5\Profiles\Tester\MatchaGrid.set at
  the time, not from anything reproducible. Recon (ORDER215_MATCHAGRID_RECON.md) found the same values
  in all 5 reports checked (Mode=0, Percent=10, Fixed=50) - encouraging, but 5 samples of an unpinned
  cache is not evidence the cache was ever set on purpose.

  Re-reading those reports (ORDER215_MATCHAGRID_CUTLOSS_FINDING.md) found something sharper: across
  3.4 years of trustworthy (non-degenerate-tick) history, not one basket close resembles a percentage-
  of-balance cut. Everything else in that window is ordinary grid churn. Two readings fit equally well:
  either Mode=0 means "disabled" (in which case "bounded grid + hard SL" - the entire reason this EA
  is not filed as uncapped-ruin - describes a switch that has never been on), or Mode=0 is a real mode
  whose trigger this data simply never reached. This script is built to tell those two apart the way
  ORDER-222 did for NuiIndy: by deliberately manufacturing the drawdown that would need to reach it.

WHY EVERY INPUT IS PINNED EXPLICITLY, NOT LEFT TO THE INI's PARTIAL LIST
  Because the gap above IS part of the finding. Every run this script launches uses a FULL .set with
  all 15 known inputs written out, so nothing here depends on the per-terminal cache - which closes
  the exact reproducibility hole that let the CutLoss family go unpinned in every prior run.

HOW RISK IS RAISED
  MatchaGrid's grid packs more baskets per unit price move as InpGridPoints shrinks, and each new step
  adds InpStepAddLot on top of InpLotStart every InpStepEveryOrders fills - so BOTH a tighter grid and
  a steeper add-lot raise realized loss on an adverse run. The ladder below tightens the grid first
  (cheaper to reason about: same number of price levels, more baskets alive at once) before touching
  the lot-add step, mirroring the NuiIndy probe's choice to move exactly one lever at a time.

STAGES
  0  control     - reproduce MG_CHFJPY_OOS_corr (PF 2.08, DD 23.75%, 1409 trades) from a FULLY PINNED
                   .set instead of the partial .ini + cache the archived run used. A mismatch here
                   means the cache held something different from what recon assumed, and everything
                   downstream needs to be re-planned before it is trusted.
  1  ladder      - CutLoss left at the live values (Mode=0, Percent=10, Fixed=50) - i.e. do NOT change
                   the thing under test yet. Walk InpGridPoints down until equity drawdown clears both
                   thresholds by a wide margin. If a cut appears at ANY rung, Mode=0 is not simply "off"
                   and stage 2 does not need to run.
  2  isolate     - at the rung stage 1 reaches without a cut, hold risk fixed and change ONLY the
                   thresholds: run Percent=1 / Fixed=1 (about as tight as a percent/fixed cut could be
                   built) against the live Percent=10 / Fixed=50. If the two arms trade IDENTICALLY,
                   Mode=0 does not respond to either threshold at all - the strongest evidence this
                   script can produce that the switch is inert regardless of its configured value.
                   If they diverge, Mode=0 does respond to something, and Percent/Fixed matter after
                   all - the failure this data has shown is a THRESHOLD problem (10/50 too loose), not
                   a disabled mechanism.

  Every run is Model 4 (a grid's fill behaviour is the whole story - doctrine already treats any grid
  measured below Model 4 as not evidence at all) on the clean 2020.01.01-2023.01.01 window, which
  ORDER-215's own recon confirmed has healthy tick density (58.8 ticks/bar) unlike the two QWEN reports
  that were discarded as degenerate. Every run is checked against both sidecars afterwards.

USAGE
  powershell -File scripts\order215_matchagrid_cutloss_probe.ps1 -Stage 0
  powershell -File scripts\order215_matchagrid_cutloss_probe.ps1 -Stage 1
  powershell -File scripts\order215_matchagrid_cutloss_probe.ps1 -Stage 2 -GridPoints 60
NEVER: touch the live account, use Model < 4, run this on 2026H1 (the holdout), or delete/replace the
per-terminal Tester profile cache for MatchaGrid (leave whatever is cached alone - this script never
depends on it, but other lanes on this box might).
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('0','1','2')][string]$Stage,
  [string]$Symbol   = "CHFJPY",
  [string]$Period   = "M15",
  [string]$FromDate = "2020.01.01",   # the clean OOS/BWD window recon confirmed is healthy-tick
  [string]$ToDate   = "2023.01.01",
  [int]$Deposit     = 10000,
  [int]$Leverage    = 100,
  [int]$GridPoints  = 0,               # stage 2: the rung stage 1 found
  [int]$TimeoutSec  = 3600,
  [string]$Terminal = "",             # pass through to mt5_run.ps1 to use a second instance (e.g. Meta 5b) when the primary is busy
  [string]$DataDir  = "",
  [switch]$Portable
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
$root    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$expert  = "MatchaGrid"
$outDir  = Join-Path $root "_mt5_auto\ab_sets\order215"
$reports = Join-Path $root "_mt5_auto\reports"
New-Item -ItemType Directory -Force $outDir | Out-Null

# The live-config baseline, pinned explicitly (see header - no prior run ever pinned CutLoss*).
$liveBase = @{
  InpLotStart        = '0.01'
  InpStepAddLot      = '0.01'
  InpStepEveryOrders = '5'
  InpProfitTarget    = '14'
  InpGridPoints      = '350'
  InpCutLossMode     = '0'
  InpCutLossPercent  = '10'
  InpCutLossFixed    = '50'
  InpCutLossBuySide  = 'true'
  InpCutLossSellSide = 'true'
  InpCutLossTotal    = 'false'
  InpMagicNumber     = '20240001'
  InpMagicPrefix     = 'MG'
  InpEnableTrading   = 'true'
  InpSlippage        = '10'
}

function New-ProbeSet([string]$name, [hashtable]$over) {
  $vals = $liveBase.Clone()
  foreach ($k in $over.Keys) { $vals[$k] = $over[$k] }
  $out = foreach ($k in $vals.Keys) { "$k=$($vals[$k])" }
  $p = Join-Path $outDir "$name.set"
  Set-Content -Path $p -Value $out -Encoding ASCII
  return $p
}

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
  $lev = $null
  $lm = [regex]::Match(($flat -replace '\|', ' '), 'Leverage:\s*1:(\d+)'); if ($lm.Success) { $lev = [int]$lm.Groups[1].Value }
  $bars = Field 'Bars:'; $ticks = Field 'Ticks:'
  $trunc = $null
  $ts = Join-Path $reports "$reportName.truncation_check.json"
  if (Test-Path $ts) { $trunc = (Get-Content $ts -Raw | ConvertFrom-Json) }
  return [PSCustomObject]@{
    report = $reportName; pf = (Field 'Profit Factor:'); trades = (Field 'Total Trades:')
    net = (Field 'Total Net Profit:'); eqdd_pct = $eqdd; leverage = $lev; bars = $bars; ticks = $ticks
    truncated = $(if ($trunc) { $trunc.truncated } else { $null })
  }
}

# Count basket-close clusters that could plausibly be a cut event, from the deals table directly -
# same technique ORDER-222 used on NuiIndy: group 'out' deals by identical timestamp, sum profit.
function Get-CloseClusters([string]$reportName) {
  $htm = Join-Path $reports "$reportName.htm"
  if (-not (Test-Path $htm)) { return @() }
  $flat = (Get-Content $htm -Raw) -replace '<[^>]+>', '|'
  $a = ($flat -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $deals = New-Object System.Collections.Generic.List[object]
  for ($i = 0; $i -lt $a.Count - 12; $i++) {
    if ($a[$i] -match '^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$' -and ($a[$i+3] -eq 'buy' -or $a[$i+3] -eq 'sell') -and $a[$i+4] -eq 'out') {
      $pv = ($a[$i+10] -replace '\s', '') -replace '[^0-9.\-]', ''
      $bv = ($a[$i+11] -replace '\s', '') -replace '[^0-9.\-]', ''
      if ($pv -ne '' -and $pv -ne '-') { $deals.Add([PSCustomObject]@{ t = $a[$i]; profit = [double]$pv; balance = $(if ($bv -ne '' -and $bv -ne '-') { [double]$bv } else { $null }) }) }
    }
  }
  # A negative cluster alone is NOT evidence of a cut - ordinary grid churn produces these too, and
  # gets bigger (in dollars) exactly as risk is raised, which is the trap: measured on 2022-04-26 at
  # GridPoints=200, a 53-position cluster summing -88.02 turned out to be -0.63% of the PRIOR balance
  # (14078.43 -> 14392.11, balance actually higher after) - ordinary churn, not a cut, just scaled up
  # by a tighter grid holding more concurrent positions. The signature a real percentage/fixed cut
  # would leave is what ORDER-222 used on NuiIndy: the cluster sum is a clean, large fraction of the
  # balance immediately before it. So report the fraction, and let the caller judge against the
  # actual InpCutLossPercent/InpCutLossFixed values - never just "a negative cluster exists".
  $out = @()
  foreach ($grp in ($deals | Group-Object t | Where-Object { $_.Count -ge 3 })) {
    $sum = [math]::Round(($grp.Group | Measure-Object profit -Sum).Sum, 2)
    if ($sum -ge 0) { continue }
    $idx = [array]::IndexOf($deals.t, $grp.Name)
    $priorBal = $(if ($idx -gt 0) { $deals[$idx - 1].balance } else { $null })
    $pct = $(if ($priorBal) { [math]::Round(($sum / $priorBal) * 100.0, 2) } else { $null })
    $out += [PSCustomObject]@{ t = $grp.Name; n = $grp.Count; sum = $sum; prior_balance = $priorBal; pct_of_balance = $pct }
  }
  return @($out | Sort-Object pct_of_balance)
}

function Invoke-Probe([string]$name, [string]$setPath) {
  Write-Host ">> $name" -ForegroundColor Cyan
  $extra = @{}
  if ($Terminal) { $extra.Terminal = $Terminal }
  if ($DataDir)  { $extra.DataDir  = $DataDir }
  if ($Portable) { $extra.Portable = $true }
  # ORDER-372 (2026-07-28): same defect as order222_cutloss_probe.ps1, fixed the same way and for
  # the same reason. Calling the runner without capturing its output makes the runner's Write-Output
  # diagnostics part of THIS function's return value, so the caller gets a string[] rather than one
  # object; `if ($r)` then passes on a truthy array and the later `$r | Add-Member` (below) throws on
  # the $null that `return $null` appended, far from the cause and with the runner's real message -
  # e.g. "ABORT: MT5 instance already running" - discarded. ORDER-215's re-measure funnel is still
  # open and runs through here, so this was live.
  $runStart = Get-Date
  $runnerOut = & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $expert -Symbol $Symbol -Period $Period `
      -FromDate $FromDate -ToDate $ToDate -Model 4 -Deposit $Deposit -Leverage $Leverage `
      -SetFile $setPath -ReportName $name -TimeoutSec $TimeoutSec @extra 2>&1
  $runnerExit = $LASTEXITCODE
  foreach ($line in @($runnerOut)) { Write-Host "   | $line" -ForegroundColor DarkGray }
  # This script is what demonstrated the stale-report defect: run with a bogus -Terminal it aborted
  # with exit 2 and then printed PF=1.77 from a leftover report. The gate was originally inlined
  # here; it now calls the shared library so "fresh" has one definition across every caller.
  $htmPath = Join-Path $reports "$name.htm"
  if (-not (Test-ReportIsFresh -Htm $htmPath -RunStart $runStart -RunnerExit $runnerExit -Label $name)) {
    return $null
  }
  $r = Read-Result $name
  if (-not $r) {
    Write-Host "   [FAIL] report passed the freshness gate but could not be parsed" -ForegroundColor Red
    return $null
  }
  $levNote = if ($r.leverage -eq $Leverage) { "leverage OK" } else { "LEVERAGE 1:$($r.leverage) != requested 1:$Leverage" }
  Write-Host ("   PF=$($r.pf)  trades=$($r.trades)  net=$($r.net)  eqDD=$($r.eqdd_pct)%  bars=$($r.bars)  ticks=$($r.ticks)  $levNote  truncated=$($r.truncated)") `
    -ForegroundColor $(if ($r.leverage -eq $Leverage) { 'Green' } else { 'Red' })
  $clusters = Get-CloseClusters $name
  # A cut candidate = a cluster whose loss is a LARGE, clean fraction of the balance right before it
  # (NuiIndy's real cut was -30.02%, -30.6%, etc.) - not merely negative. 15% is a generous floor;
  # InpCutLossPercent=10 or a $50 fixed hit on typical live-sized balances should clear it easily if
  # either mechanism is actually responding.
  $cutCandidates = @($clusters | Where-Object { $_.pct_of_balance -ne $null -and $_.pct_of_balance -le -15.0 })
  if ($clusters.Count -gt 0) {
    Write-Host ("   loss-clusters (>=3 positions, net negative): {0}  |  cut-candidates (>=15% of prior balance): {1}" -f $clusters.Count, $cutCandidates.Count) -ForegroundColor Yellow
    $clusters | Select-Object -First 5 | ForEach-Object { Write-Host ("      {0}  n={1}  realized={2}  ({3}% of prior balance {4})" -f $_.t, $_.n, $_.sum, $_.pct_of_balance, $_.prior_balance) -ForegroundColor Gray }
  } else {
    Write-Host "   loss-clusters: none" -ForegroundColor Gray
  }
  $worstPct = $(if ($clusters.Count -gt 0) { ($clusters | Sort-Object pct_of_balance | Select-Object -First 1).pct_of_balance } else { $null })
  $r | Add-Member -NotePropertyName clusters -NotePropertyValue $clusters.Count
  $r | Add-Member -NotePropertyName cut_candidates -NotePropertyValue $cutCandidates.Count
  $r | Add-Member -NotePropertyName worst_cluster_pct -NotePropertyValue $worstPct
  return $r
}

$results = @()

if ($Stage -eq '0') {
  Write-Host "=== STAGE 0: reproduce MG_CHFJPY_OOS_corr from a FULLY PINNED set (no cache dependency) ===" -ForegroundColor Cyan
  $s = New-ProbeSet 'O215_ctrl_live' @{}
  $results += Invoke-Probe 'O215_S0_ctrl_live' $s
  Write-Host ""
  Write-Host "Compare against the archived MG_CHFJPY_OOS_corr: PF 2.08, 1409 trades, eqDD 23.75%." -ForegroundColor Yellow
  Write-Host "A mismatch here means the terminal's cached CutLoss values were NOT what recon assumed." -ForegroundColor Yellow
}
elseif ($Stage -eq '1') {
  Write-Host "=== STAGE 1: tighten the grid (CutLoss left at live 0/10/50) until DD clears both thresholds ===" -ForegroundColor Cyan
  foreach ($gp in @(200, 120, 80, 50)) {
    $s = New-ProbeSet ("O215_gp{0}_live" -f $gp) @{ InpGridPoints = "$gp" }
    $r = Invoke-Probe ("O215_S1_gp{0}_live" -f $gp) $s
    if ($r) { $r | Add-Member -NotePropertyName grid_points -NotePropertyValue $gp; $results += $r }
    if ($r -and $r.cut_candidates -gt 0) {
      Write-Host ("   >> a cut-CANDIDATE (>=15% of prior balance) appeared at GridPoints=$gp under the LIVE CutLoss config - Mode=0 may not be inert. Verify it is a genuine percentage/fixed match to InpCutLossPercent=10 / InpCutLossFixed=50 before concluding, then stop here.") -ForegroundColor Green
      break
    }
    if ($r -and $r.eqdd_pct -ne $null -and $r.eqdd_pct -gt 30.0) {
      Write-Host ("   >> DD $($r.eqdd_pct)% clears both thresholds (10% / an implied ~50 on a `$10k deposit) with NO cut-candidate observed (largest cluster only $($r.worst_cluster_pct)% of balance). Run stage 2 with -GridPoints $gp") -ForegroundColor Yellow
      break
    }
  }
}
elseif ($Stage -eq '2') {
  if ($GridPoints -le 0) { Write-Host "[FAIL] -GridPoints is required for stage 2 (use the rung stage 1 found)" -ForegroundColor Red; exit 1 }
  Write-Host "=== STAGE 2: at fixed elevated risk, change ONLY the CutLoss thresholds ===" -ForegroundColor Cyan
  foreach ($arm in @(
    @{ name = 'live_thresholds'; pct = '10'; fixed = '50' },
    @{ name = 'tight_thresholds'; pct = '1';  fixed = '1' }
  )) {
    $s = New-ProbeSet ("O215_gp{0}_{1}" -f $GridPoints, $arm.name) @{ InpGridPoints = "$GridPoints"; InpCutLossPercent = $arm.pct; InpCutLossFixed = $arm.fixed }
    $r = Invoke-Probe ("O215_S2_gp{0}_{1}" -f $GridPoints, $arm.name) $s
    if ($r) { $r | Add-Member -NotePropertyName arm -NotePropertyValue $arm.name; $results += $r }
  }
  $live = $results | Where-Object arm -eq 'live_thresholds'
  $tight = $results | Where-Object arm -eq 'tight_thresholds'
  if ($live -and $tight) {
    Write-Host ""
    if (($live.net -eq $tight.net) -and ($live.trades -eq $tight.trades) -and ($live.clusters -eq $tight.clusters)) {
      Write-Host ">> [FINDING] identical outcome at Percent=10/Fixed=50 vs Percent=1/Fixed=1 - InpCutLossMode=0 does NOT respond to either threshold. This is the strongest evidence this script can produce that the mode is disabled, not merely untriggered." -ForegroundColor Red
    } else {
      Write-Host ">> [FINDING] the arms diverge - InpCutLossMode=0 DOES respond to the threshold inputs. The live 10/50 values are simply too loose to have fired in tested history, a THRESHOLD problem, not a disabled mechanism." -ForegroundColor Green
    }
  }
}

Write-Host ""
$results | Where-Object { $_ } | Format-Table report, pf, trades, net, eqdd_pct, clusters, cut_candidates, worst_cluster_pct, truncated -AutoSize
$csv = Join-Path $root ("_triage\ORDER215_probe_stage{0}.csv" -f $Stage)
# ORDER-372 - see the matching note in order222_cutloss_probe.ps1. Where-Object { $_ } drops $null
# but not strings, and Export-Csv on a string writes its .Length, which is why every pre-fix probe
# CSV in _triage has a "Length" column of byte counts where the metrics should be.
$clean = @($results | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'report' })
if ($clean.Count -eq 0) {
  Write-Host "no usable results this run - leaving $csv untouched rather than blanking it" -ForegroundColor Yellow
} else {
  $clean | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
  Write-Host "results -> $csv"
}
