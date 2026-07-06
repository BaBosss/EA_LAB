<#
run_tests.ps1 - Boss V2 module smoke-assert harness (MERGE-06).

Runs every tests\*.mq5 in the Strategy Tester and greps the agent journal for
its [PASS]/[FAIL] line. One command, exit 0 = all green.

  powershell -File ea_template\tests\run_tests.ps1

Per-test inputs: optional tests\<Name>.set (same basename) is passed via -SetFile.
Requires MT5 GUI closed (mt5_run.ps1 guard). Adding a test = drop <Name>.mq5 here
printing "[PASS] <Name>: ..." or "[FAIL] <Name>..." in OnInit/first tick.
#>
[CmdletBinding()]
param(
  [string]$Symbol = "XAUUSD",
  [string]$Period = "H1",
  [string]$FromDate = "2024.01.02",
  [string]$ToDate = "2024.01.05"
)
$ErrorActionPreference = "Stop"
$root    = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$testDir = $PSScriptRoot
$deployedTests = "D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Experts\EALabTpl\tests"
$agentRoot = "D:\MetaTraderData\Roaming\MetaQuotes\Tester\9CA16B8382AE4CF692710FB36B9DA355"

# deploy (copies ea_template incl. tests) - compile of Boss files comes free
& (Join-Path $root 'ea_template\deploy.ps1') -Compile | Out-Null

$results = @()
foreach ($mq5 in Get-ChildItem (Join-Path $testDir '*.mq5')) {
  $name = $mq5.BaseName
  # compile the test EA in the deployed location
  & 'D:\Meta 5\MetaEditor64.exe' /compile:"$deployedTests\$name.mq5" /log | Out-Null
  if (-not (Test-Path "$deployedTests\$name.ex5")) {
    $results += [pscustomobject]@{ test=$name; result='COMPILE-FAIL' }; continue
  }
  $setArg = @{}
  $set = Join-Path $testDir "$name.set"
  if (Test-Path $set) { $setArg['SetFile'] = $set }
  & (Join-Path $root 'scripts\mt5_run.ps1') -Expert "EALabTpl\tests\$name" -Symbol $Symbol -Period $Period `
      -FromDate $FromDate -ToDate $ToDate -Model 1 -ReportName "TEST_$name" @setArg | Out-Null
  # newest agent journal, last verdict line for this test
  $log = Get-ChildItem $agentRoot -Recurse -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $hit = Select-String -Path $log.FullName -Pattern "\[(PASS|FAIL)\] $name" | Select-Object -Last 1
  $verdict = if ($null -eq $hit) { 'NO-VERDICT' } elseif ($hit.Line -match '\[PASS\]') { 'PASS' } else { 'FAIL' }
  $results += [pscustomobject]@{ test=$name; result=$verdict }
}

$results | Format-Table -AutoSize
$bad = @($results | Where-Object { $_.result -ne 'PASS' })
if ($bad.Count -gt 0) { Write-Host "=== TESTS: $($bad.Count) not passing ===" -ForegroundColor Red; exit 1 }
Write-Host "=== ALL TESTS PASS ===" -ForegroundColor Green
exit 0
