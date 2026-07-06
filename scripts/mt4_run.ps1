<#
mt4_run.ps1 — headless MT4 single backtest.

MT4 differs from MT5: launch is `terminal.exe "<config.ini>"` (no /config:),
and the [Tester] keys are TestExpert / TestSymbol / TestPeriod / TestModel /
TestFromDate / TestToDate / TestReport / TestShutdownTerminal.

Runs with the EA's COMPILED DEFAULT inputs unless -SetFile is given (a .set is
copied into <DataDir>\tester\ and referenced by TestExpertParameters).

MT4 writes <TestReport>.htm to the INSTALL dir (D:\Meta4) by default; this script
searches install dir + data dir, then MOVES it into _mt4_auto\reports.

SAFETY: aborts if an MT4 terminal is already running (single-instance). Close it
first, or pass -Force.

Example:
  & .\mt4_run.ps1 -Expert "AI Gold Sniper EA" -Symbol XAUUSD `
       -FromDate 2025.05.22 -ToDate 2026.05.22 -ReportName AIGOLD_XAU_1y
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [string]$SetFile = "",
  [int]$Model = 2,                               # 0=every tick, 1=control pts, 2=open prices
  [int]$Deposit = 10000,
  [int]$Spread = 0,                              # tester fixed spread in POINTS (0 = current/default) — for spread-stress tests
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta4\terminal.exe",
  [string]$InstallDir = "D:\Meta4",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0",
  [int]$TimeoutSec = 900,
  [switch]$Force
)
$ErrorActionPreference = "Stop"

if (-not $Force) {
  $g = [Diagnostics.Stopwatch]::StartNew()
  while ((Get-Process terminal -ErrorAction SilentlyContinue) -and $g.Elapsed.TotalSeconds -lt 25) {
    Start-Sleep -Seconds 2
  }
  if (Get-Process terminal -ErrorAction SilentlyContinue) {
    Write-Output "ABORT: an MT4 terminal is still running after 25s. Close it first, or pass -Force."; exit 2
  }
}
if (-not (Test-Path $Terminal)) { Write-Output "ABORT: terminal not found: $Terminal"; exit 2 }

$auto = "D:\EA_LAB\_mt4_auto"
New-Item -ItemType Directory -Force "$auto\reports", "$auto\ini" | Out-Null

# MT4 may write the report to the install dir OR the data dir — clean both first.
$candidates = @((Join-Path $InstallDir "$ReportName.htm"), (Join-Path $DataDir "$ReportName.htm"))
foreach ($c in $candidates) { if (Test-Path $c) { Remove-Item $c -Force } }
$destHtm = "$auto\reports\$ReportName.htm"

# Optional params: copy .set into tester\ and reference by filename only.
$paramLine = $null
if ($SetFile -and (Test-Path $SetFile)) {
  New-Item -ItemType Directory -Force (Join-Path $DataDir "tester") | Out-Null
  $setName = [IO.Path]::GetFileName($SetFile)
  Copy-Item $SetFile (Join-Path $DataDir "tester\$setName") -Force
  $paramLine = "TestExpertParameters=$setName"
}

$lines = @(
  "[Tester]",
  "TestExpert=$Expert",
  "TestSymbol=$Symbol",
  "TestPeriod=$Period",
  "TestModel=$Model",
  "TestOptimization=false",
  "TestDateEnable=true",
  "TestFromDate=$FromDate",
  "TestToDate=$ToDate",
  "TestReport=$ReportName",
  "TestReplaceReport=true",
  "TestShutdownTerminal=true",
  "TestVisualEnable=false"
)
if ($Spread -gt 0) { $lines += "TestSpread=$Spread" }
if ($paramLine) { $lines += $paramLine }
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

Write-Output "launch: $Expert | $Symbol $Period | $FromDate..$ToDate | model=$Model | set=$([IO.Path]::GetFileName($SetFile))"
$proc = Start-Process -FilePath $Terminal -ArgumentList "`"$ini`"" -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
$found = $null
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  foreach ($c in $candidates) { if (Test-Path $c) { $found = $c; break } }
  if ($found) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 8) {
    Start-Sleep -Seconds 2
    foreach ($c in $candidates) { if (Test-Path $c) { $found = $c; break } }
    break
  }
  Start-Sleep -Seconds 4
}
if ($found) {
  Move-Item $found $destHtm -Force
  # MT4 writes a matching <name>.gif (equity chart) alongside
  foreach ($dir in @($InstallDir, $DataDir)) {
    Get-ChildItem $dir -Filter "$ReportName*.gif" -File -ErrorAction SilentlyContinue |
      Move-Item -Destination "$auto\reports\" -Force
  }
  Write-Output "OK REPORT: $destHtm"
}
else {
  Write-Output "NO REPORT (exited=$($proc.HasExited)). Check EA name / symbol history / login."
}
