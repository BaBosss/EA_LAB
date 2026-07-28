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

# Uses PowerShell's own parser rather than counting braces. The first version of this check tracked
# function boundaries by tallying { and } per line, which also counted braces inside strings and
# comments and could therefore leave a function early and stop looking. The AST knows exactly where
# a FunctionDefinitionAst begins and ends, so the question "is this call inside a function" stops
# being a guess.
foreach ($f in Get-ChildItem $scriptDir -Filter *.ps1 -File) {
  $parseErrors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$parseErrors)
  if ($null -eq $ast) { continue }

  $funcs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
  if ($funcs.Count -eq 0) { continue }

  foreach ($fn in $funcs) {
    $cmds = $fn.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($cmd in $cmds) {
      # Only actual invocations. `& (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert ...` contains a
      # NESTED CommandAst for the Join-Path argument, whose own pipeline is neither assigned nor
      # piped - so without this filter the inner argument gets reported while the outer call, which
      # IS assigned, is correctly skipped. The call operator is what distinguishes an invocation
      # from an expression that merely names the runner.
      if ($cmd.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Unknown) { continue }
      $cmdText = $cmd.Extent.Text
      $callsRunner = $false
      foreach ($rn in $runnerNames) { if ($cmdText -match [regex]::Escape($rn)) { $callsRunner = $true } }
      if (-not $callsRunner) { continue }

      # Disposition is a property of the enclosing pipeline / statement, which the AST gives us
      # directly: assigned ($x = & ...), or piped somewhere (| Out-Null, | Where-Object, ...).
      $pipeline = $cmd.Parent
      $assigned = $false
      $piped    = $false
      if ($pipeline -is [System.Management.Automation.Language.PipelineAst]) {
        $piped = $pipeline.PipelineElements.Count -gt 1
        if ($pipeline.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) { $assigned = $true }
      }
      if ($assigned -or $piped) { continue }
      $offenders.Add(("{0}:{1}  {2}" -f $f.Name, $cmd.Extent.StartLineNumber, ($cmdText -split "`n")[0].Trim()))
    }
  }
}

if ($offenders.Count -gt 0) {
  Write-Host "  uncaptured runner calls inside functions:" -ForegroundColor Red
  $offenders | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
Assert "no uncaptured runner call inside any function under scripts\" { $offenders.Count -eq 0 }

Write-Host ""
Write-Host "PART 4 - the freshness guard itself behaves" -ForegroundColor Cyan

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\report_freshness.ps1')

$fresh = Join-Path $mockDir "fresh.htm"
$stale = Join-Path $mockDir "stale.htm"
"x" | Set-Content $stale
"x" | Set-Content $fresh
# Stamp the timestamps explicitly rather than sleeping between writes. Sleeping cost 2.2s of the
# 3.0s this suite took and made the assertions depend on wall-clock timing; setting mtime directly
# is instant and states the intent - one file is an hour older than the run, the other a minute
# newer - instead of hoping the clock cooperated.
$runStart = Get-Date
(Get-Item $stale).LastWriteTime = $runStart.AddHours(-1)
(Get-Item $fresh).LastWriteTime = $runStart.AddMinutes(1)

Assert "fresh report + exit 0 = accepted"        { Test-ReportIsFresh -Htm $fresh -RunStart $runStart -RunnerExit 0 -Quiet }
Assert "STALE report + exit 0 = REFUSED"         { -not (Test-ReportIsFresh -Htm $stale -RunStart $runStart -RunnerExit 0 -Quiet) }
Assert "fresh report but exit 2 (abort) = REFUSED" { -not (Test-ReportIsFresh -Htm $fresh -RunStart $runStart -RunnerExit 2 -Quiet) }
Assert "fresh report but exit 1 (no report) = REFUSED" { -not (Test-ReportIsFresh -Htm $fresh -RunStart $runStart -RunnerExit 1 -Quiet) }
Assert "exit 3 (leverage mismatch) still accepts - the report IS from this run" {
  Test-ReportIsFresh -Htm $fresh -RunStart $runStart -RunnerExit 3 -Quiet
}
Assert "missing file = REFUSED" { -not (Test-ReportIsFresh -Htm (Join-Path $mockDir 'nope.htm') -RunStart $runStart -RunnerExit 0 -Quiet) }
Assert "library is inert toward its caller (sets no StrictMode / ErrorActionPreference)" {
  # Check STATEMENTS, not raw text: the library's own header explains why it avoids these, so a
  # raw-text grep matches its documentation and fails on a correct file. (This assertion did
  # exactly that on first run - the test was wrong, not the library.)
  # Order matters and got this wrong once: filtering ^\s*# lines FIRST deletes the block comment's
  # own closing "#>" token, after which the <#...#> strip finds no terminator and removes nothing.
  # Strip block comments first, then line comments.
  $raw  = Get-Content (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\report_freshness.ps1') -Raw
  $code = [regex]::Replace($raw, '(?s)<#.*?#>', '')
  $code = (($code -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
  ($code -notmatch 'Set-StrictMode') -and ($code -notmatch '\$ErrorActionPreference\s*=')
}

Write-Host ""
Write-Host "PART 5 - every runner caller that parses a report gates it for freshness" -ForegroundColor Cyan

# The bug PART 3 cannot see: a caller may discard the runner's output correctly (| Out-Null) and
# still infer "the .htm exists, therefore this run made it". That inference is what let an aborted
# run report a previous run's numbers. Any script that calls a runner AND then reads a report must
# either use the shared guard or check $LASTEXITCODE itself.
$ungated = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem $scriptDir -Filter *.ps1 -File) {
  # The runners themselves are not callers. Without this they self-match on the usage examples in
  # their own header comments - which is how this check first reported mt4_run.ps1 and
  # mt4_optimize.ps1 as offenders against their own report-move logic.
  if ($runnerNames -contains $f.Name) { continue }

  # Comment lines must not count as calls, for the same reason.
  $codeLines = Get-Content $f.FullName | Where-Object { $_ -notmatch '^\s*#' }
  $txt = ($codeLines -join "`n")
  $txt = [regex]::Replace($txt, '(?s)<#.*?#>', '')

  $callsRunner = $false
  foreach ($rn in $runnerNames) { if ($txt -match ('&[^\r\n]*' + [regex]::Escape($rn))) { $callsRunner = $true } }
  if (-not $callsRunner) { continue }
  # does it then read a report?
  if ($txt -notmatch '\.htm') { continue }
  $gated = ($txt -match 'Test-ReportIsFresh') -or ($txt -match '\$LASTEXITCODE')
  if (-not $gated) { $ungated.Add($f.Name) }
}
if ($ungated.Count -gt 0) {
  Write-Host "  runner callers that read a report without gating it:" -ForegroundColor Red
  $ungated | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
Assert "no runner caller reads a report without a freshness/exit-code gate" { $ungated.Count -eq 0 }

Remove-Item $mockDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($script:fails -gt 0) {
  Write-Host ("RESULT: {0}/{1} assertions FAILED" -f $script:fails, $script:ran) -ForegroundColor Red
  exit 1
}
Write-Host ("RESULT: all {0} assertions passed" -f $script:ran) -ForegroundColor Green
exit 0
