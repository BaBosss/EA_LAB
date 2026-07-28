<#
check_truncated_run.ps1 - ORDER-193: did this backtest actually reach the end of its window?

WHY THIS EXISTS
  The safety cage (RiskControl.mqh) hard-kills on equity drawdown and then HALTS for the
  rest of the run. It is NOT gated out of the Strategy Tester - it fires in backtests too.
  When it fires, the EA closes everything and stops trading, but the MT5 report says
  nothing about it: you get a Profit Factor computed over however much of the window ran
  before the kill, presented exactly like a full-window result.

  Measured 2026-07-24 (ORDER-188 case A): a fixed 0.10 lot on Boss_12 died at eqDD 25.09%
  on trade 115 of 164 - 30% of the window silently never happened, and the reported PF
  (0.71) described only the first 70%.

  Worse for the funnel: the kill point depends on the tester DEPOSIT, which is a run
  setting, not a property of the strategy. The same EA with the same parameters can be
  truncated at one deposit and complete at another - so two runs that look comparable are
  not. Any verdict written on a truncated sample is a verdict on a different experiment
  than the one intended.

WHAT THIS CHECKS
  The report's LAST deal time against the window's end date. A run that stopped trading
  long before its window ended is either truncated by the cage or simply signal-starved
  at the end - this script cannot always tell those apart, so it reports SUSPECT and names
  the evidence rather than pretending to a verdict. Use -TesterLog to confirm: a genuine
  cage kill leaves a "[RISK] HARD KILL" line.

  (Before ORDER-194 the kill re-fired every tick, so those logs ran to millions of lines
  and hundreds of MB. Post-fix a killed run leaves one line, which makes -TesterLog cheap.)

USAGE
  powershell -File scripts\check_truncated_run.ps1 -Report _mt5_auto\reports\FOO.htm -ToDate 2024.07.01
  powershell -File scripts\check_truncated_run.ps1 -Report ... -ToDate ... -TesterLog <path to tester log>
EXIT CODES
  0 = run reached its window (or evidence is inconclusive but no gap)
  2 = SUSPECT: stopped trading well before the window end
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Report,
  [string]$ToDate = "",                           # yyyy.MM.dd; omit to read it out of the report itself
  [string]$FromDate = "",                         # optional; enables the "% of window" figure
  [string]$TesterLog = "",                        # optional; confirms a cage kill outright
  [double]$GapPctThreshold = 10.0,                # flag when the idle tail exceeds this share of the window
  [int]$GapDaysFloor = 7                          # ...and is at least this many days (short windows)
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path $Report)) { Write-Host "[FAIL] report not found: $Report" -ForegroundColor Red; exit 1 }

# MT5 writes UTF-16LE with a BOM; -Raw honours it.
$flat = (Get-Content $Report -Raw) -replace '<[^>]+>', '|'
$parts = ($flat -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }

# Deal rows look like: <time> <deal#> <symbol> <buy|sell> <in|out> <volume> ...
# Take the last timestamp that heads a real deal row, ignoring the opening "balance" row.
$lastDeal = $null; $entries = 0
for ($i = 0; $i -lt $parts.Count - 4; $i++) {
  if ($parts[$i] -match '^(\d{4}\.\d{2}\.\d{2}) \d{2}:\d{2}:\d{2}$') {
    $t = $parts[$i]
    if ($parts[$i+3] -eq 'buy' -or $parts[$i+3] -eq 'sell') {
      $lastDeal = $t
      if ($parts[$i+4] -eq 'in') { $entries++ }
    }
  }
}
if (-not $lastDeal) { Write-Host "[INFO] no deals in report - nothing to judge" -ForegroundColor Yellow; exit 0 }

# The report states its own window ("Period: | H1 (2024.01.01 - 2024.07.01)"), so neither
# date has to be supplied. That is what makes a retro-scan over the whole reports/ folder
# possible: no external bookkeeping about which run covered which window.
if (-not $ToDate -or -not $FromDate) {
  $pm = [regex]::Match($flat, '\(\s*(\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})\s*\)')
  if ($pm.Success) {
    if (-not $FromDate) { $FromDate = $pm.Groups[1].Value }
    if (-not $ToDate)   { $ToDate   = $pm.Groups[2].Value }
  }
}
if (-not $ToDate) { Write-Host "[INFO] could not read the test window from the report and none was supplied - skipping" -ForegroundColor Yellow; exit 0 }

$end      = [datetime]::ParseExact($ToDate, 'yyyy.MM.dd', $null)
$lastTime = [datetime]::ParseExact($lastDeal, 'yyyy.MM.dd HH:mm:ss', $null)
$gapDays  = [math]::Round(($end - $lastTime).TotalDays, 1)

$gapPct = $null
if ($FromDate) {
  $start = [datetime]::ParseExact($FromDate, 'yyyy.MM.dd', $null)
  $span  = ($end - $start).TotalDays
  if ($span -gt 0) { $gapPct = [math]::Round(($gapDays / $span) * 100.0, 1) }
}

# Rule the cage IN or OUT using the report's own drawdown. The kill thresholds are the
# only three RC_KillDDPct() can return (15 TIGHT / 25 NORMAL / 40 LOOSE), so a run whose
# maximum equity drawdown never reached the tightest of them cannot have been killed - it
# simply stopped signalling. Without this, every thin-signal EA trips the alarm: the first
# cage run with this check flagged Boss_14 (eqDD 1.49%) and Boss_17 (eqDD 1.03%), neither
# of which could possibly have been killed. Two false alarms out of eight is how a warning
# gets ignored, and an ignored warning is worse than none.
$MIN_KILL_THRESHOLD_PCT = 15.0
$eqddPct = $null
# Read it out of the already-split parts, the same way the deal rows are read. Regexing the
# flattened blob is fragile here: MT5 prints the figure as "2 561.47 (25.09%)" - a space as
# the thousands separator - with an arbitrary run of tag-separators before it.
for ($i = 0; $i -lt $parts.Count - 1; $i++) {
  if ($parts[$i] -eq 'Equity Drawdown Maximal:') {
    $pm = [regex]::Match($parts[$i+1], '\((\d+(?:\.\d+)?)%\)')
    if ($pm.Success) { $eqddPct = [double]$pm.Groups[1].Value }
    break
  }
}
$killPossible = ($null -eq $eqddPct) -or ($eqddPct -ge $MIN_KILL_THRESHOLD_PCT)

$killConfirmed = $false
if ($TesterLog -and (Test-Path $TesterLog)) {
  $hit = Select-String -Path $TesterLog -Pattern '\[RISK\] HARD KILL:' -Encoding unicode -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($hit) { $killConfirmed = $true; Write-Host "[EVIDENCE] $($hit.Line.Trim())" -ForegroundColor Yellow }
}

Write-Host ("last deal {0} | window ends {1} | idle tail {2} days{3} | entry deals {4}{5}" -f `
  $lastDeal, $ToDate, $gapDays, $(if ($null -ne $gapPct) { " ($gapPct% of window)" } else { "" }), $entries,
  $(if ($null -ne $eqddPct) { " | eqDD $eqddPct%" } else { "" }))

$bigGap = ($gapDays -ge $GapDaysFloor) -and (($null -eq $gapPct) -or ($gapPct -ge $GapPctThreshold))
if ($killConfirmed) {
  Write-Host "[TRUNCATED] the cage hard-killed this run - the reported metrics cover only the part before the kill. Do NOT compare them against full-window runs, and do not write a verdict on them." -ForegroundColor Red
  exit 2
}
if ($bigGap -and $killPossible) {
  Write-Host "[SUSPECT] stopped trading well before the window ended, AND the drawdown reached kill territory. Re-run with -TesterLog to confirm whether the cage killed it; do not use these metrics until you know." -ForegroundColor Red
  exit 2
}
if ($bigGap) {
  # Worth saying out loud - a PF built on a burst of trades in one regime is not the same
  # claim as a PF earned across the window - but it is not a truncation, so it must not
  # share an exit code with one.
  Write-Host ("[INFO] quiet tail: no trades for the last {0} days, but eqDD {1}% never approached the tightest kill threshold ({2}%), so the cage did NOT stop this run - the signal simply went quiet. Note the sample is concentrated in part of the window." -f `
    $gapDays, $eqddPct, $MIN_KILL_THRESHOLD_PCT) -ForegroundColor Yellow
  exit 0
}
# ORDER-372: this used to be an unconditional else-branch, so it asserted "traded through to the
# end of the window" for ANY run that failed to clear $bigGap - including runs with a large
# measured idle tail that only escaped the flag because of the absolute $GapDaysFloor. Observed:
# a 7-day window whose last deal was on day 0.6 printed "idle tail 6.4 days (91.4% of window)"
# and then "[OK] traded through to the end of the window" on the next line. Both came from this
# script, one of them was false, and this text is what gets written into the truncation sidecar
# that detector_digest.ps1 and every downstream reader treat as the verdict.
# The threshold is deliberately NOT changed here - retuning a guard's sensitivity is its own
# decision with its own evidence. What changes is that the message may no longer claim more than
# was measured, and the blind spot is named out loud instead of being expressed as silence.
$tailIsTrivial = ($gapDays -lt 1.0)
if ($tailIsTrivial) {
  Write-Host "[OK] traded through to the end of the window" -ForegroundColor Green
  exit 0
}
$suppressedBy = if (($null -ne $gapPct) -and ($gapPct -ge $GapPctThreshold) -and ($gapDays -lt $GapDaysFloor)) {
  " NOTE: the share of the window ({0}%) is above the {1}% flag threshold and was suppressed only by the {2}-day absolute floor - on a window this short that floor cannot be reached, so this check has no power here." -f $gapPct, $GapPctThreshold, $GapDaysFloor
} else { "" }
Write-Host ("[OK] reached the window end within tolerance - idle tail {0} days{1}, below the flag threshold ({2} days AND {3}% of window).{4}" -f `
  $gapDays, $(if ($null -ne $gapPct) { " ($gapPct% of window)" } else { "" }), $GapDaysFloor, $GapPctThreshold, $suppressedBy) -ForegroundColor Green
exit 0
