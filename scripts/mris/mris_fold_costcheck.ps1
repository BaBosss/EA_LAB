# mris_fold_costcheck.ps1 - ORDER-200 Phase D COST ESTIMATE.
# Answers the only question that matters before flipping -EnableCrisisFold on a live account:
# "how many days would this have throttled my lots, and in which regimes?"
#
# Joins the two historical replays by date:
#   mris_backtest_timeline.ps1  -> regime_<label>.csv  (core 8-barometer state per day)
#   mris_crisis_backtest.ps1    -> crisis_<label>.csv  (3 crisis scores per day)
# then applies the SAME fold ladder as mris_export_regime.ps1 (RISK_ON->NEUTRAL->RISK_OFF,
# never STRESS, never upward, 'active' only) and reports the before/after state distribution.
#
# A "throttled day" = a day the fold made more cautious than the core layer alone. In a real
# crisis that is the point; in a calm window it is pure cost, which is why calm_2019 is in the
# default set. Read-only: writes nothing outside $OutDir. Zero LLM tokens.
[CmdletBinding()]
param(
  [string]$Config    = "D:\EA_LAB\scripts\mris\crisis_models.json",
  [string]$OutDir    = "D:\EA_LAB\portfolio\mris\backtest",
  [string[]]$Windows = @(
    "covid_2020:2020-02-01:2020-05-15",
    "inflation_2022:2022-02-15:2022-08-15",
    "yield_spike_2023:2023-08-01:2023-11-15",
    "calm_2019:2019-05-01:2019-07-31"
  ),
  [switch]$SkipReplays   # reuse existing CSVs instead of re-fetching history
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSCommandPath -Parent
$cfg = Get-Content $Config -Raw -Encoding UTF8 | ConvertFrom-Json
$activeMin = [double]$cfg.labels.active_min

if (-not $SkipReplays) {
  Write-Host "=== replaying core regime timeline ==="
  & "$root\mris_backtest_timeline.ps1" -Windows $Windows -OutDir $OutDir | Out-Null
  Write-Host "=== replaying crisis models ==="
  & "$root\mris_crisis_backtest.ps1" -Windows $Windows -OutDir $OutDir | Out-Null
}

# ladder + min_coverage come from crisis_models.json fold_policy - the SAME object
# mris_export_regime.ps1 reads, so this estimate cannot describe a policy nobody runs.
$fp = $cfg.fold_policy
$ladder = @{}
if ($fp -and $fp.ladder) { foreach ($p in $fp.ladder.PSObject.Properties) { $ladder[$p.Name] = "$($p.Value)" } }
else { $ladder = @{ 'RISK_ON' = 'NEUTRAL'; 'NEUTRAL' = 'RISK_OFF' } }
$minCov = if ($fp -and $null -ne $fp.min_coverage) { [double]$fp.min_coverage } else { 0.5 }
$throttleStates = @('RISK_OFF','STRESS')   # states where MacroGate reduces lot / blocks new
Write-Host ("fold policy: ladder=" + (($ladder.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)->$($_.Value)" }) -join ' ') + "  min_coverage=$minCov  active_min=$activeMin")

$grand = @()
foreach ($w in $Windows) {
  $parts = $w -split ':'
  $label = $parts[0]
  $regCsv = Join-Path $OutDir "regime_$label.csv"
  $criCsv = Join-Path $OutDir "crisis_$label.csv"
  if (!(Test-Path $regCsv) -or !(Test-Path $criCsv)) {
    Write-Host "!! $label : missing replay CSV - SKIPPED (no cost estimate for this window)"
    continue
  }

  # core states keyed by yyyy-MM-dd (regime CSV stamps 'yyyy.MM.dd 00:00')
  $core = @{}
  foreach ($r in (Import-Csv $regCsv)) {
    $d = ("$($r.datetime)" -split ' ')[0] -replace '\.', '-'
    $core[$d] = "$($r.state)"
  }

  $n=0; $folded=0; $newlyThrottled=0; $headroom=0
  $beforeDist=@{}; $afterDist=@{}
  foreach ($c in (Import-Csv $criCsv)) {
    $d = "$($c.date)"
    if (-not $core.ContainsKey($d)) { continue }
    $before = $core[$d]
    $n++
    $anyActive = $false
    foreach ($mn in @('YIELD_SHOCK','CREDIT_STRESS','INFLATION_OIL')) {
      $v = $c.$mn
      if ($null -eq $v -or "$v".Trim() -eq "") { continue }
      # same evidence gate the exporter applies. Older CSVs have no *_cov column; treat a
      # missing coverage as 1 so this stays backward compatible rather than silently zeroing.
      $cvRaw = $c."${mn}_cov"
      $cv = if ($null -ne $cvRaw -and "$cvRaw".Trim() -ne "") { [double]$cvRaw } else { 1.0 }
      if ([double]$v -ge $activeMin -and $cv -ge $minCov) { $anyActive = $true }
    }
    $after = $before
    if ($anyActive -and $ladder.ContainsKey($before)) { $after = $ladder[$before] }
    if ($after -ne $before) { $folded++ }
    if (($throttleStates -notcontains $before) -and ($throttleStates -contains $after)) { $newlyThrottled++ }
    if ($throttleStates -notcontains $before) { $headroom++ }
    if (!$beforeDist.ContainsKey($before)) { $beforeDist[$before]=0 }; $beforeDist[$before]++
    if (!$afterDist.ContainsKey($after))   { $afterDist[$after]=0 };   $afterDist[$after]++
  }

  if ($n -eq 0) { Write-Host "!! $label : no overlapping dates between the two replays - SKIPPED"; continue }
  $pctFold = [math]::Round(100.0*$folded/$n,1)
  $pctThr  = [math]::Round(100.0*$newlyThrottled/$n,1)
  Write-Host ""
  Write-Host "=== $label : $n days ==="
  Write-Host ("   core  : " + (($beforeDist.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  '))
  Write-Host ("   folded: " + (($afterDist.GetEnumerator()  | Sort-Object Name | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '  '))
  Write-Host ("   days changed by fold: {0}/{1} ({2}%)   NEWLY throttled (lot-reduce/block engaged): {3} ({4}%)" -f $folded,$n,$pctFold,$newlyThrottled,$pctThr)
  # HEADROOM = days the core layer was NOT already throttling. If that is tiny, the fold had
  # nowhere to act and a 0% cost reading means "saturated control", not "free". ORDER-203 found
  # exactly this: calm_2019 read 0% only because the core sat in RISK_OFF 48/51 days (an
  # artifact of the AUDJPY user_pin). Surfacing headroom stops that misreading recurring.
  $pctHead = [math]::Round(100.0*$headroom/$n,1)
  if ($pctHead -lt 20) { Write-Host ("   !! LOW HEADROOM: core was already throttling on {0}/{1} days - this window CANNOT measure fold cost" -f ($n-$headroom),$n) }
  $grand += [pscustomobject]@{ window=$label; days=$n; folded=$folded; pct_folded=$pctFold; newly_throttled=$newlyThrottled; pct_throttled=$pctThr; headroom_pct=$pctHead }
}

Write-Host ""
Write-Host "=== COST SUMMARY (what flipping -EnableCrisisFold would have done) ==="
$grand | Format-Table -AutoSize
# Only a calm window WITH headroom can price the fold. A saturated one reads 0% for the wrong
# reason, so it is reported as unusable rather than quietly averaged in with the good ones.
$calmAll = @($grand | Where-Object { $_.window -like 'calm*' -or $_.window -like 'precovid*' })
$calmUsable = @($calmAll | Where-Object { $_.headroom_pct -ge 20 })
$calmDead   = @($calmAll | Where-Object { $_.headroom_pct -lt 20 })
if ($calmUsable.Count -gt 0) {
  Write-Host "READ THIS FIRST - pure cost, measured only on calm windows the core left room in:"
  foreach ($c in $calmUsable) { Write-Host ("   {0,-16} {1}/{2} days throttled ({3}%)  [headroom {4}%]" -f $c.window,$c.newly_throttled,$c.days,$c.pct_throttled,$c.headroom_pct) }
  Write-Host "Throttling in a calm tape buys nothing - judge the switch on these numbers."
} else {
  Write-Host "READ THIS FIRST: no USABLE calm control window in this run - cost is unmeasured. Add one with headroom."
}
if ($calmDead.Count -gt 0) {
  Write-Host ("EXCLUDED as saturated (core already throttling, cannot price the fold): " + (($calmDead | ForEach-Object { "$($_.window) headroom=$($_.headroom_pct)%" }) -join ', '))
}
