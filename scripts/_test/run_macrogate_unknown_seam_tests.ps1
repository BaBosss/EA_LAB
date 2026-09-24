<#
Focused compile/runtime cage for MacroGate_UnknownSeam_Test.

This is a no-trade unit fixture. It performs static seam assertions, deploys
only the test and its MacroGate include into an order-owned EA_LAB_TEST tree,
requires a 0-error/0-warning compile, and uses Model 1 only to execute the
fixture. It never invokes optimizer or performance research.
#>
[CmdletBinding()]
param(
  [string]$Symbol = "XAUUSD",
  [string]$FromDate = "2024.11.02",
  [string]$ToDate = "2024.11.05"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$coreSource = Join-Path $repoRoot "ea_template\core\MacroGate_Core.mqh"
$testSource = Join-Path $repoRoot "ea_template\tests\MacroGate_UnknownSeam_Test.mq5"
$mt5Run = Join-Path $repoRoot "scripts\mt5_run.ps1"
$terminal = "D:\Meta 5\terminal64.exe"
$metaEditor = "D:\Meta 5\MetaEditor64.exe"

foreach($required in @($coreSource, $testSource, $mt5Run, $terminal, $metaEditor))
{
  if(-not (Test-Path -LiteralPath $required -PathType Leaf))
  {
    throw "required file missing: $required"
  }
}

$coreText = Get-Content -LiteralPath $coreSource -Raw
$testText = Get-Content -LiteralPath $testSource -Raw

function Assert-StaticMatch
{
  param([string]$Name, [string]$Pattern, [string]$Text)
  if(-not [regex]::IsMatch($Text, $Pattern,
      [Text.RegularExpressions.RegexOptions]::Multiline))
  {
    throw "STATIC_ASSERT_FAIL $Name"
  }
  Write-Output "STATIC_ASSERT_PASS $Name"
}

Assert-StaticMatch "explicit-unknown-token" 'if\s*\(\s*s\s*==\s*"UNKNOWN"\s*\)\s*return\s+MG_ST_UNKNOWN\s*;' $coreText
Assert-StaticMatch "malformed-is-invalid" 'return\s+MG_ST_INVALID\s*;' $coreText
Assert-StaticMatch "non-tester-unknown-skipped" 'if\s*\(\s*st\s*==\s*MG_ST_UNKNOWN\s*&&\s*!MQLInfoInteger\s*\(\s*MQL_TESTER\s*\)\s*\)\s*\{\s*skipped\+\+;\s*continue;\s*\}' $coreText
Assert-StaticMatch "tester-unknown-clears-and-returns" 'if\s*\(\s*st\s*==\s*MG_ST_UNKNOWN\s*\)\s*\{\s*[\s\S]*?MG_ClearAll\s*\(\s*"explicit UNKNOWN quarantine marker"\s*\)\s*;\s*return\s*;\s*\}' $coreText
Assert-StaticMatch "fixture-is-tester-gated" 'MQLInfoInteger\s*\(\s*MQL_TESTER\s*\)' $testText

if([regex]::IsMatch($testText,
   '\b(?:CTrade|OrderSend|PositionClose|PositionClosePartial|OrderDelete)\b|(?:^|[^A-Za-z0-9_])(?:Buy|Sell|BuyLimit|SellLimit)\s*\('))
{
  throw "STATIC_ASSERT_FAIL no-trade fixture contains a trade mutation API"
}
Write-Output "STATIC_ASSERT_PASS no-trade-api"

$termPath = (Resolve-Path -LiteralPath $terminal).Path
function Get-PrimaryLaneProcess
{
  @(Get-Process terminal64 -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -eq $termPath })
}

if(@(Get-PrimaryLaneProcess).Count -gt 0)
{
  Write-Output "TESTER_BUSY primary MT5 lane is running; no deploy, kill, or force attempted"
  exit 2
}

$data = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355"
$junction = Get-Item "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal" -Force -ErrorAction SilentlyContinue
if($junction -and $junction.LinkType -and $junction.Target)
{
  $data = Join-Path ([string]$junction.Target) "9CA16B8382AE4CF692710FB36B9DA355"
}

$orderRoot = Join-Path $data "MQL5\Experts\EA_LAB_TEST\ORDER-NEWS-MACRO-MG-CORE-SEAM-V1-20260922"
$coreDeploy = Join-Path $orderRoot "core"
$testDeploy = Join-Path $orderRoot "tests"
New-Item -ItemType Directory -Force -Path $coreDeploy, $testDeploy | Out-Null

Copy-Item -LiteralPath $coreSource -Destination (Join-Path $coreDeploy "MacroGate_Core.mqh") -Force
$deployedMq5 = Join-Path $testDeploy "MacroGate_UnknownSeam_Test.mq5"
Copy-Item -LiteralPath $testSource -Destination $deployedMq5 -Force

$deployedEx5 = [IO.Path]::ChangeExtension($deployedMq5, ".ex5")
$compileLog = Join-Path $testDeploy "MacroGate_UnknownSeam_Test.compile.log"
if(Test-Path -LiteralPath $deployedEx5) { Remove-Item -LiteralPath $deployedEx5 -Force }
if(Test-Path -LiteralPath $compileLog) { Remove-Item -LiteralPath $compileLog -Force }

$compileArgs = @('/compile:"' + $deployedMq5 + '"', '/log:"' + $compileLog + '"')
Start-Process -FilePath $metaEditor -ArgumentList $compileArgs -Wait | Out-Null

if(-not (Test-Path -LiteralPath $compileLog -PathType Leaf))
{
  throw "COMPILE_FAIL no MetaEditor log produced"
}
$compileText = Get-Content -LiteralPath $compileLog -Raw -Encoding Unicode
$result = [regex]::Match($compileText,
  'Result:\s*(\d+)\s+errors?(?:,\s*(\d+)\s+warnings?)?')
if(-not $result.Success)
{
  throw "COMPILE_FAIL no parseable Result line"
}
$errors = [int]$result.Groups[1].Value
$warnings = if($result.Groups[2].Success) { [int]$result.Groups[2].Value } else { 0 }
if($errors -ne 0 -or $warnings -ne 0 -or
   -not (Test-Path -LiteralPath $deployedEx5 -PathType Leaf))
{
  throw "COMPILE_FAIL errors=$errors warnings=$warnings ex5=$([bool](Test-Path -LiteralPath $deployedEx5))"
}
Write-Output "COMPILE_PASS 0 errors 0 warnings"

if(@(Get-PrimaryLaneProcess).Count -gt 0)
{
  Write-Output "TESTER_BUSY primary MT5 lane became busy after compile; no kill or force attempted"
  Write-Output "ARTIFACTS_LEFT $orderRoot"
  exit 2
}

$terminalHash = Split-Path -Leaf $data
$metaQuotesRoot = Split-Path -Parent (Split-Path -Parent $data)
$agentRoot = Join-Path (Join-Path $metaQuotesRoot "Tester") $terminalHash
$expert = "EA_LAB_TEST\ORDER-NEWS-MACRO-MG-CORE-SEAM-V1-20260922\tests\MacroGate_UnknownSeam_Test"
$reportName = "TEST_MacroGate_UnknownSeam"
$runStart = Get-Date

$runArgs = @{
  Expert = $expert
  Symbol = $Symbol
  Period = "H1"
  FromDate = $FromDate
  ToDate = $ToDate
  Model = 1
  ReportName = $reportName
  Terminal = $terminal
  DataDir = $data
  TimeoutSec = 180
  AllowLegacyIdentity = $true
}
$runOutput = (& $mt5Run @runArgs 2>&1 | Out-String)
$runExit = $LASTEXITCODE

if($runExit -eq 2 -and $runOutput -match 'already running')
{
  Write-Output "TESTER_BUSY primary MT5 lane won the launch race; no kill or force attempted"
  Write-Output "ARTIFACTS_LEFT $orderRoot"
  exit 2
}
if($runExit -ne 0)
{
  throw "FOCUSED_TEST_RUN_FAIL exit=$runExit output=$($runOutput.Trim())"
}

$freshLog = Get-ChildItem -LiteralPath $agentRoot -Recurse -Filter "*.log" -ErrorAction SilentlyContinue |
  Where-Object { $_.LastWriteTime -ge $runStart } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if($null -eq $freshLog)
{
  throw "FOCUSED_TEST_RUN_FAIL no fresh tester journal"
}

$verdicts = @(Select-String -LiteralPath $freshLog.FullName -Pattern '\[(PASS|FAIL)\] MacroGate_UnknownSeam_Test')
if($verdicts.Count -ne 1)
{
  throw "FOCUSED_TEST_RUN_FAIL expected exactly one verdict, found $($verdicts.Count)"
}
if($verdicts[0].Line -notmatch '\[PASS\]')
{
  throw "FOCUSED_TEST_RUN_FAIL $($verdicts[0].Line.Trim())"
}

Write-Output "FOCUSED_TEST_PASS MacroGate_UnknownSeam_Test"
Write-Output "ARTIFACTS_LEFT $orderRoot (bounded order-owned test surface; no post-run cleanup authority assumed)"
exit 0
