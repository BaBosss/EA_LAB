<#
run_truncation_message_tests.ps1 - ORDER-372.

WHAT IT GUARDS
  scripts\check_truncated_run.ps1 - specifically the TEXT it emits, not just its exit code.

WHY THE TEXT IS THE THING
  That script's output is written verbatim into <report>.truncation_check.json by mt5_run.ps1,
  and detector_digest.ps1 plus every human reader treat that `detail` field as the finding. So a
  sentence that overclaims is not cosmetic - it is the artifact.

  The defect this locks down: the final "[OK] traded through to the end of the window" was an
  unconditional else-branch. A 7-day window whose last deal fell on day 0.6 printed

      idle tail 6.4 days (91.4% of window)
      [OK] traded through to the end of the window

  - two lines from the same script, one of them false. It happened because $bigGap requires
  gapDays >= $GapDaysFloor (7) AND the percentage, so on any window shorter than the floor the
  percentage test cannot fire and the run falls through to the unconditional OK.

  The thresholds are deliberately NOT retuned by this suite. What is asserted is that the message
  never claims more than was measured, and that the short-window blind spot is stated rather than
  expressed as silence.

  ASCII only: PS 5.1 decodes a BOM-less .ps1 as ANSI.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$script:fails = 0
$script:ran   = 0
$checker = Join-Path (Split-Path -Parent $PSScriptRoot) 'check_truncated_run.ps1'

function Assert([string]$what, [scriptblock]$cond) {
  $script:ran++
  $ok = $false
  try { $ok = [bool](& $cond) } catch { $ok = $false; Write-Host "    (threw: $($_.Exception.Message))" -ForegroundColor DarkGray }
  if ($ok) { Write-Host "  [PASS] $what" -ForegroundColor Green }
  else     { Write-Host "  [FAIL] $what" -ForegroundColor Red; $script:fails++ }
}

# Per-process: a shared fixed path lets two concurrent pre-commit hooks delete each other's
# fixtures mid-run and fail a commit that was fine.
$tmp = Join-Path $env:TEMP ("ea_lab_trunc_msg_test_" + $PID)
New-Item -ItemType Directory -Force $tmp | Out-Null

# Build a report MT5-shaped enough for the checker: a Period line it can read its own window from,
# deal rows in the column order the parser walks, and an Equity Drawdown Maximal cell.
function New-FakeReport {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$From,
    [Parameter(Mandatory)][string]$To,
    [Parameter(Mandatory)][string]$LastDealTime,
    [Parameter(Mandatory)][double]$EqddPct
  )
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('<html><body><table>')
  [void]$sb.Append('<tr><td>Period:</td><td>H1 (' + $From + ' - ' + $To + ')</td></tr>')
  [void]$sb.Append('<tr><td>Equity Drawdown Maximal:</td><td>2 561.47 (' + $EqddPct + '%)</td></tr>')
  # one early deal so there is always a trade, plus the deal that sets the tail
  [void]$sb.Append('<tr><td>' + $From + ' 01:00:00</td><td>1</td><td>EURUSD</td><td>buy</td><td>in</td><td>0.01</td></tr>')
  [void]$sb.Append('<tr><td>' + $LastDealTime + '</td><td>2</td><td>EURUSD</td><td>sell</td><td>in</td><td>0.01</td></tr>')
  [void]$sb.Append('</table></body></html>')
  # MT5 writes UTF-16LE with a BOM and the checker relies on -Raw honouring it.
  [IO.File]::WriteAllText($Path, $sb.ToString(), [Text.Encoding]::Unicode)
}

function Run-Checker([string]$Report) {
  $out = & $checker -Report $Report 2>&1 6>&1 | Out-String
  return [PSCustomObject]@{ text = $out; code = $LASTEXITCODE }
}

Write-Host ""
Write-Host "check_truncated_run.ps1 - message honesty" -ForegroundColor Cyan

# 1. genuinely traded to the end: the original wording must survive unchanged
$r1 = Join-Path $tmp "full.htm"
New-FakeReport -Path $r1 -From '2023.01.01' -To '2023.12.31' -LastDealTime '2023.12.30 22:00:00' -EqddPct 3.0
$o1 = Run-Checker $r1
Assert "full-window run still says 'traded through to the end of the window'" {
  $o1.text -match 'traded through to the end of the window'
}
Assert "full-window run exits 0" { $o1.code -eq 0 }

# 2. THE BUG: short window, huge idle share, suppressed by the absolute day floor
$r2 = Join-Path $tmp "shortwin.htm"
New-FakeReport -Path $r2 -From '2022.03.01' -To '2022.03.08' -LastDealTime '2022.03.01 13:22:00' -EqddPct 29.76
$o2 = Run-Checker $r2
Assert "short window with a 91% idle tail does NOT claim it traded through to the end" {
  $o2.text -notmatch 'traded through to the end of the window'
}
Assert "...and states the measured idle tail instead" { $o2.text -match 'idle tail' }
Assert "...and names the blind spot: the day floor made this check powerless here" {
  ($o2.text -match 'no power here') -or ($o2.text -match 'suppressed only by')
}
Assert "...and still exits 0 (it is not a truncation claim, just an honest one)" { $o2.code -eq 0 }

# 3. long window, big tail, drawdown far below any kill threshold -> quiet-tail INFO, exit 0
$r3 = Join-Path $tmp "quiet.htm"
New-FakeReport -Path $r3 -From '2023.01.01' -To '2023.12.31' -LastDealTime '2023.06.01 10:00:00' -EqddPct 2.0
$o3 = Run-Checker $r3
Assert "long quiet tail below kill territory is reported as a quiet tail, not a truncation" {
  $o3.text -match 'quiet tail'
}
Assert "quiet tail exits 0 (must not share an exit code with a truncation)" { $o3.code -eq 0 }

# 4. long window, big tail, drawdown in kill territory -> SUSPECT, exit 2
$r4 = Join-Path $tmp "suspect.htm"
New-FakeReport -Path $r4 -From '2023.01.01' -To '2023.12.31' -LastDealTime '2023.06.01 10:00:00' -EqddPct 26.0
$o4 = Run-Checker $r4
Assert "big tail + drawdown in kill territory is SUSPECT" { $o4.text -match 'SUSPECT' }
Assert "SUSPECT exits 2" { $o4.code -eq 2 }

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($script:fails -gt 0) {
  Write-Host ("RESULT: {0}/{1} assertions FAILED" -f $script:fails, $script:ran) -ForegroundColor Red
  exit 1
}
Write-Host ("RESULT: all {0} assertions passed" -f $script:ran) -ForegroundColor Green
exit 0

