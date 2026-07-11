<#
run_mt4_tests.ps1 - ORDER-083B: compile + tester-assert harness for the MQL4
NewsGuard port. MT4 twin of ea_template\tests\run_tests.ps1 (which stays
MT5-only; this lives in the project folder because the MT4 lane has no shared
test dir).

  powershell -File "ea_projects\(Boss)_NewsGuard\run_mt4_tests.ps1"

Steps:
 1. deploy NewsGuard_Core_MT4.mqh + (Boss)_NewsGuard_MT4.mq4 +
    NewsGuard_Test_MT4.mq4 into <MT4 DataDir>\MQL4\Experts\
 2. compile both .mq4 with D:\Meta4\metaeditor.exe (fails on any error/warning)
 3. copy the compiled .ex4s back into this project folder
 4. run NewsGuard_Test_MT4 in the MT4 tester (scripts\mt4_run.ps1,
    XAUUSD M5 Model 0, one day) and grep the tester journal for the
    [PASS]/[FAIL] verdict + the fail-safe ALERT + the B->N downgrade warning.
Exit 0 = compile clean AND test PASS.
#>
[CmdletBinding()]
param(
  [string]$Symbol   = "XAUUSD",
  [string]$Period   = "M5",
  [int]$Model       = 0,
  [string]$FromDate = "2026.04.01",
  [string]$ToDate   = "2026.04.02",
  [string]$MetaEditor = "D:\Meta4\metaeditor.exe",
  [string]$DataDir  = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0"
)
$ErrorActionPreference = "Stop"
$proj    = $PSScriptRoot
$root    = (Resolve-Path (Join-Path $proj '..\..')).Path
$experts = Join-Path $DataDir "MQL4\Experts"

# 1) deploy ------------------------------------------------------------------
foreach ($f in @('NewsGuard_Core_MT4.mqh', '(Boss)_NewsGuard_MT4.mq4', 'NewsGuard_Test_MT4.mq4')) {
  Copy-Item -LiteralPath (Join-Path $proj $f) -Destination $experts -Force
}

# 2) compile (0 errors / 0 warnings required) ---------------------------------
$compileOk = $true
foreach ($src in @('(Boss)_NewsGuard_MT4.mq4', 'NewsGuard_Test_MT4.mq4')) {
  $srcPath = Join-Path $experts $src
  $logPath = [IO.Path]::ChangeExtension($srcPath, '.log')
  if (Test-Path $logPath) { Remove-Item $logPath -Force }
  $ex4 = [IO.Path]::ChangeExtension($srcPath, '.ex4')
  if (Test-Path $ex4) { Remove-Item $ex4 -Force }
  Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$srcPath`"", "/log" -Wait -NoNewWindow
  $log = if (Test-Path $logPath) { Get-Content $logPath } else { @() }
  $result = ($log | Select-String -Pattern 'Result:' | Select-Object -Last 1)
  Write-Host ("compile {0}: {1}" -f $src, $(if ($result) { $result.Line.Trim() } else { 'no Result line' }))
  $errors   = if ($result -and $result.Line -match '(\d+)\s+error')   { [int]$matches[1] } else { 999 }
  $warnings = if ($result -and $result.Line -match '(\d+)\s+warning') { [int]$matches[1] } else { 999 }
  if (-not (Test-Path $ex4) -or $errors -ne 0 -or $warnings -ne 0) {
    $compileOk = $false
    $log | Select-String -Pattern 'error|warning' | ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }
  }
}
if (-not $compileOk) { Write-Host "=== COMPILE FAILED (need 0 errors / 0 warnings) ===" -ForegroundColor Red; exit 1 }

# 3) compiled .ex4 back into the repo project folder --------------------------
Copy-Item -LiteralPath (Join-Path $experts '(Boss)_NewsGuard_MT4.ex4') -Destination $proj -Force

# 4) tester run + journal grep -------------------------------------------------
$testerLog = Join-Path $DataDir ("tester\logs\" + (Get-Date -Format 'yyyyMMdd') + ".log")
$beforeLines = if (Test-Path $testerLog) { @(Get-Content $testerLog).Count } else { 0 }
& powershell -File (Join-Path $root 'scripts\mt4_run.ps1') `
    -Expert 'NewsGuard_Test_MT4' -Symbol $Symbol -Period $Period `
    -FromDate $FromDate -ToDate $ToDate -Model $Model `
    -ReportName 'TEST_NewsGuard_MT4' | Out-Host

if (-not (Test-Path $testerLog)) { Write-Host "NO TESTER JOURNAL at $testerLog" -ForegroundColor Red; exit 1 }
$tail = @(Get-Content $testerLog | Select-Object -Skip $beforeLines)

$verdictHit = $tail | Select-String -Pattern '\[(PASS|FAIL)\] NewsGuard_Test_MT4' | Select-Object -Last 1
$verdict = if ($null -eq $verdictHit) { 'NO-VERDICT' }
           elseif ($verdictHit.Line -match '\[PASS\]') { 'PASS' } else { 'FAIL' }
$alerts    = @($tail | Select-String -Pattern '\[NEWSGUARD\] ALERT').Count
$downgrade = @($tail | Select-String -Pattern 'WARNING magic=917202.*treating as N').Count
$churn     = @($tail | Select-String -Pattern 'owner EA re-entering during news window').Count
$pending   = @($tail | Select-String -Pattern 'deleted pending ticket').Count
$failLines = $tail | Select-String -Pattern '\[NG-TEST FAIL\]'

Write-Host ""
Write-Host ("verdict            : {0}  ({1})" -f $verdict, $(if ($verdictHit) { $verdictHit.Line.Trim() } else { 'verdict line not found' }))
Write-Host ("fail-safe ALERTs   : {0} (expect >=1: missing-file phase)" -f $alerts)
Write-Host ("B->N warning lines : {0} (expect >=1)" -f $downgrade)
Write-Host ("churn alerts        : {0} (expect >=1)" -f $churn)
Write-Host ("pending deletes     : {0} (expect >=1)" -f $pending)
$failLines | ForEach-Object { Write-Host ("  " + $_.Line.Trim()) }

if ($verdict -eq 'PASS' -and $alerts -ge 1 -and $downgrade -ge 1 -and $churn -ge 1 -and $pending -ge 1 -and @($failLines).Count -eq 0) {
  Write-Host "=== NEWSGUARD MT4 TESTS PASS ===" -ForegroundColor Green; exit 0
}
Write-Host "=== NEWSGUARD MT4 TESTS NOT PASSING ===" -ForegroundColor Red
exit 1
