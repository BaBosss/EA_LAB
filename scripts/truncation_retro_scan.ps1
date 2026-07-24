<#
truncation_retro_scan.ps1 - ORDER-193(d): sweep every report already on disk and flag the
ones whose metrics may describe only part of their test window.

WHY
  The DD hard-kill is not gated out of the Strategy Tester. When it fires, the EA closes
  everything and halts for the rest of the run, and the MT5 report says nothing about it -
  the Profit Factor is presented exactly like a full-window result. The kill point also
  moves with the tester deposit, which is a run setting rather than a property of the
  strategy, so two runs that look comparable may not be. Any verdict written on a truncated
  sample is a verdict about a different experiment than the one intended.

  This answers the retrospective question: how much of what we already concluded rests on
  runs like that?

WHY NOT JUST LOOP check_truncated_run.ps1
  Spawning a PowerShell child per report costs ~1-2s; at ~4,800 reports that is hours. The
  logic is duplicated here deliberately and kept in sync by the shared constants below -
  check_truncated_run.ps1 stays the single-report tool used inside mt5_run.ps1.

USAGE
  powershell -File scripts\truncation_retro_scan.ps1
  powershell -File scripts\truncation_retro_scan.ps1 -Csv _triage\my_scan.csv
#>
[CmdletBinding()]
param(
  [string]$ReportDir = "_mt5_auto\reports",
  [string]$Csv = "_triage\TRUNCATION_RETRO_SCAN.csv",
  [double]$GapPctThreshold = 10.0,
  [int]$GapDaysFloor = 7,
  [double]$MinKillThresholdPct = 15.0   # tightest RC_KillDDPct(); below this a kill is impossible
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dir  = Join-Path $root $ReportDir
$reps = Get-ChildItem (Join-Path $dir '*.htm') -ErrorAction SilentlyContinue | Sort-Object Name
Write-Host "scanning $($reps.Count) reports in $dir ..." -ForegroundColor Cyan

$rows = New-Object System.Collections.Generic.List[object]
$i = 0
foreach ($r in $reps) {
  $i++
  if ($i % 500 -eq 0) { Write-Host "  ...$i/$($reps.Count)" -ForegroundColor DarkGray }
  try { $flat = ([IO.File]::ReadAllText($r.FullName, [Text.Encoding]::Unicode)) -replace '<[^>]+>', '|' }
  catch { continue }

  # window, straight out of the report: "Period: | H1 (2024.01.01 - 2024.07.01)"
  $pm = [regex]::Match($flat, '\(\s*(\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})\s*\)')
  if (-not $pm.Success) { continue }
  $from = [datetime]::ParseExact($pm.Groups[1].Value, 'yyyy.MM.dd', $null)
  $to   = [datetime]::ParseExact($pm.Groups[2].Value, 'yyyy.MM.dd', $null)

  # last entry/exit deal timestamp
  $dm = [regex]::Matches($flat, '(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\|+\d+\|+[^|]+\|+(buy|sell)\|')
  if ($dm.Count -eq 0) { continue }
  $last = [datetime]::ParseExact($dm[$dm.Count-1].Groups[1].Value, 'yyyy.MM.dd HH:mm:ss', $null)

  $eqdd = $null
  $em = [regex]::Match($flat, 'Equity Drawdown Maximal:\|+[^(]*\((\d+(?:\.\d+)?)%\)')
  if ($em.Success) { $eqdd = [double]$em.Groups[1].Value }

  $gapDays = [math]::Round(($to - $last).TotalDays, 1)
  $span    = ($to - $from).TotalDays
  $gapPct  = if ($span -gt 0) { [math]::Round(($gapDays / $span) * 100.0, 1) } else { $null }

  $bigGap      = ($gapDays -ge $GapDaysFloor) -and (($null -eq $gapPct) -or ($gapPct -ge $GapPctThreshold))
  $killPossible = ($null -eq $eqdd) -or ($eqdd -ge $MinKillThresholdPct)
  $verdict = if ($bigGap -and $killPossible) { 'SUSPECT' } elseif ($bigGap) { 'QUIET_TAIL' } else { 'OK' }

  $rows.Add([pscustomobject]@{
    report = $r.BaseName; window = "$($pm.Groups[1].Value)..$($pm.Groups[2].Value)"
    last_deal = $last.ToString('yyyy.MM.dd'); gap_days = $gapDays; gap_pct = $gapPct
    eqdd_pct = $eqdd; verdict = $verdict
  })
}

$csvPath = Join-Path $root $Csv
$rows | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
$sus = $rows | Where-Object verdict -eq 'SUSPECT'
$qt  = $rows | Where-Object verdict -eq 'QUIET_TAIL'
Write-Host ""
Write-Host ("scanned {0} | OK {1} | QUIET_TAIL {2} | SUSPECT {3}" -f $rows.Count, ($rows.Count - $sus.Count - $qt.Count), $qt.Count, $sus.Count) -ForegroundColor Cyan
Write-Host ""
Write-Host "=== SUSPECT (big idle tail AND drawdown in kill territory - metrics may be partial) ===" -ForegroundColor Red
$sus | Sort-Object -Property @{Expression='gap_pct';Descending=$true} | Select-Object -First 40 |
  Format-Table report, window, last_deal, gap_days, gap_pct, eqdd_pct -AutoSize
Write-Host "full results -> $csvPath"
exit 0
