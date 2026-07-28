<#
test_runner_output_capture.ps1 - regression cage for the ORDER-372 defect class.

THE DEFECT
  A PowerShell function returns EVERYTHING its body writes to the success stream, not just what
  `return` names. So a helper that calls mt5_run.ps1 without capturing its output silently folds
  the runner's own Write-Output diagnostics into its return value. The caller then holds a string[]
  where it expected one object:
     - `if ($r)` passes anyway, because a non-empty array is truthy
     - `$r | Add-Member ...` throws "Cannot bind argument to parameter 'InputObject' because it is
       null" on the $null that `return $null` appends
     - and the runner's real message - the one that says WHY, e.g. "ABORT: MT5 instance already
       running" - is consumed as data instead of shown
  The crash therefore lands far from its cause with the explanation destroyed. That is exactly how
  it presented on 2026-07-28: the wrapper printed "[FAIL] no report produced" while the backtest was
  in fact still running, and the abort reason never reached the operator.

WHAT THIS FILE PROVES
  PART 1  the bug is real - the OLD pattern really does return a polluted array (a test that cannot
          fail proves nothing, so this asserts the broken behaviour explicitly)
  PART 2  the fix works - the NEW pattern returns exactly one object and still surfaces the text
  PART 3  nobody reintroduces it - greps every repo script for a call to a runner .ps1 that sits
          inside a function and is neither captured nor discarded

  Run:  powershell -File D:\EA_LAB\scripts\tests\test_runner_output_capture.ps1
  Exit: 0 all green, 1 any failure.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$script:fails = 0
$script:ran   = 0

function Assert([string]$what, [scriptblock]$cond) {
  $script:ran++
  $ok = $false
  try { $ok = [bool](& $cond) } catch { $ok = $false; Write-Host "    (threw: $($_.Exception.Message))" -ForegroundColor DarkGray }
  if ($ok) { Write-Host "  [PASS] $what" -ForegroundColor Green }
  else     { Write-Host "  [FAIL] $what" -ForegroundColor Red; $script:fails++ }
}

# ---------------------------------------------------------------------------
# A mock runner that behaves like mt5_run.ps1: chatty on stdout, meaningful exit code.
# ---------------------------------------------------------------------------
$mockDir = Join-Path $env:TEMP "ea_lab_runner_capture_test"
New-Item -ItemType Directory -Force $mockDir | Out-Null
$mockRunner = Join-Path $mockDir "mock_runner.ps1"
@'
param([switch]$Fail)
Write-Output "launch: MockEA | EURUSD H1 | set=mock.set"
if ($Fail) { Write-Output "ABORT: MT5 instance already running."; exit 2 }
Write-Output "OK REPORT: mock.htm (leverage verified 1:100)"
exit 0
'@ | Set-Content -Path $mockRunner -Encoding ASCII

# Stand-in for Read-Result: returns an object on success, $null when there is no report.
function Get-FakeResult([bool]$exists) {
  if (-not $exists) { return $null }
  return [PSCustomObject]@{ report = "mock"; pf = "1.98" }
}

Write-Host ""
Write-Host "PART 1 - the OLD pattern is genuinely broken (asserting the bug, not the fix)" -ForegroundColor Cyan

function Invoke-Old([bool]$reportExists, [switch]$FailRunner) {
  & $mockRunner -Fail:$FailRunner            # <-- uncaptured: this is the defect
  $r = Get-FakeResult $reportExists
  if (-not $r) { return $null }
  return $r
}

$oldOk = Invoke-Old $true
Assert "OLD pattern pollutes the return value even on success (returns >1 item)" {
  @($oldOk).Count -gt 1
}
Assert "OLD pattern's polluted return is NOT a usable result object (top item is a string)" {
  @($oldOk)[0] -is [string]
}

$oldBad = Invoke-Old $false -FailRunner
Assert "OLD pattern returns a truthy array even when there is NO report" {
  [bool]$oldBad -eq $true
}
Assert "OLD pattern therefore throws on Add-Member - the observed ORDER-372 crash" {
  $threw = $false
  try { $oldBad | Add-Member -NotePropertyName cutloss -NotePropertyValue 30 -ErrorAction Stop }
  catch { $threw = $true }
  $threw
}

Write-Host ""
Write-Host "PART 2 - the NEW pattern is correct" -ForegroundColor Cyan

function Invoke-New([bool]$reportExists, [switch]$FailRunner) {
  $out  = & $mockRunner -Fail:$FailRunner 2>&1     # <-- captured
  $code = $LASTEXITCODE
  $script:lastRunnerText = (@($out) -join "`n")
  $script:lastRunnerCode = $code
  $r = Get-FakeResult $reportExists
  if (-not $r) { return $null }
  return $r
}

$newOk = Invoke-New $true
Assert "NEW pattern returns EXACTLY one item on success" { @($newOk).Count -eq 1 }
Assert "NEW pattern returns a real object, not a string" { $newOk.pf -eq "1.98" }
Assert "NEW pattern still surfaces the runner's text (not swallowed)" {
  $script:lastRunnerText -match 'OK REPORT'
}

$newBad = Invoke-New $false -FailRunner
Assert "NEW pattern returns falsey when there is no report" { -not $newBad }
Assert "NEW pattern preserves the runner's exit code for diagnosis" { $script:lastRunnerCode -eq 2 }
Assert "NEW pattern preserves the ABORT reason - the fact that explains the failure" {
  $script:lastRunnerText -match 'ABORT: MT5 instance already running'
}
Assert "NEW pattern's falsey return does not throw on Add-Member guarded by if" {
  $threw = $false
  try { if ($newBad) { $newBad | Add-Member -NotePropertyName x -NotePropertyValue 1 -ErrorAction Stop } }
  catch { $threw = $true }
  -not $threw
}

Write-Host ""
Write-Host "PART 3 - no script reintroduces the pattern" -ForegroundColor Cyan

# Look for a runner invocation that is INSIDE a function and whose output goes nowhere.
# Captured (`$x = &`), discarded (`| Out-Null`, `$null = &`), or piped onward all count as handled.
$runnerNames = @('mt5_run.ps1', 'mt4_run.ps1', 'mt5_optimize.ps1', 'mt4_optimize.ps1')
$scriptDir   = Split-Path -Parent $PSScriptRoot
$offenders   = New-Object System.Collections.Generic.List[string]

foreach ($f in Get-ChildItem $scriptDir -Filter *.ps1 -File) {
  $lines = Get-Content $f.FullName
  $inFunc = $false; $depth = 0
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $ln = $lines[$i]
    if ($ln -match '^\s*function\s+') { $inFunc = $true; $depth = 0 }
    if ($inFunc) {
      $depth += ([regex]::Matches($ln, '\{')).Count
      $depth -= ([regex]::Matches($ln, '\}')).Count
      if ($depth -le 0 -and $i -gt 0 -and $ln -match '\}') { $inFunc = $false }
    }
    if (-not $inFunc) { continue }
    $callsRunner = $false
    foreach ($rn in $runnerNames) { if ($ln -match [regex]::Escape($rn)) { $callsRunner = $true } }
    if (-not $callsRunner) { continue }
    if ($ln -notmatch '&') { continue }              # a mention in a comment/string, not a call
    if ($ln -match '^\s*#') { continue }             # comment line
    # handled forms
    if ($ln -match '\$\w+\s*=\s*&')      { continue }   # $out = & runner
    if ($ln -match '\$null\s*=\s*&')     { continue }   # $null = & runner
    # a call may continue across backticked lines; look ahead for the disposition
    $window = ($lines[$i..([Math]::Min($i + 6, $lines.Count - 1))] -join ' ')
    if ($window -match 'Out-Null|\|\s*Out-|\$\w+\s*=\s*&|\$null\s*=\s*&') { continue }
    $offenders.Add(("{0}:{1}  {2}" -f $f.Name, ($i + 1), $ln.Trim()))
  }
}

if ($offenders.Count -gt 0) {
  Write-Host "  uncaptured runner calls inside functions:" -ForegroundColor Red
  $offenders | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
Assert "no uncaptured runner call inside any function under scripts\" { $offenders.Count -eq 0 }

Remove-Item $mockDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($script:fails -gt 0) {
  Write-Host ("RESULT: {0}/{1} assertions FAILED" -f $script:fails, $script:ran) -ForegroundColor Red
  exit 1
}
Write-Host ("RESULT: all {0} assertions passed" -f $script:ran) -ForegroundColor Green
exit 0
