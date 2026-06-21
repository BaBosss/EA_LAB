<#
mt4_optimize.ps1 — headless MT4 OPTIMIZATION (sibling of mt4_run.ps1).

MT4 differs from MT5: there is no auto-exported optimization XML. MT4 runs the
optimization and (a) caches passes under <DataDir>\tester\caches\*.opt (binary),
and (b) with TestReport set + TestReplaceReport, writes an OPTIMIZATION report
.htm that contains the pass table (one row per parameter combo). We collect that
.htm; parse_mt4_opt.py turns the pass table into CSV.

The .set must carry MT4 optimization ranges:
  Name=value
  Name,F=1        ; F=1 optimize this input, F=0 freeze
  Name,1=start
  Name,2=step
  Name,3=stop

SAFETY: aborts if an MT4 terminal is already running (single-instance).

Example:
  & .\mt4_optimize.ps1 -Expert "KRAPOOK BLUE ANT GOAL KEEPER 1.00" -Symbol EURUSDc `
      -SetFile "...\KRAPOOK_opt.set" -FromDate 2023.12.01 -ToDate 2025.06.01 `
      -ReportName OPT_KRAPOOK_EUR
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [Parameter(Mandatory)][string]$SetFile,        # .set WITH ,F/,1/,2/,3 optimize ranges
  [int]$Model = 2,                               # 2 = open prices (fast screen-grade)
  [int]$Optimization = 2,                        # MT4: 2 = genetic, 1 = full, 0 = off
  [int]$Deposit = 10000,
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta4\terminal.exe",
  [string]$InstallDir = "D:\Meta4",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\208874223073CBC8F9A8DE40460E6DD0",
  [int]$TimeoutSec = 3600,
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
if (-not (Test-Path $SetFile))  { Write-Output "ABORT: set not found: $SetFile"; exit 2 }

$auto = "D:\EA_LAB\_mt4_auto"
New-Item -ItemType Directory -Force "$auto\optimizations", "$auto\ini" | Out-Null

# clean any prior report in both candidate dirs
$candidates = @((Join-Path $InstallDir "$ReportName.htm"), (Join-Path $DataDir "$ReportName.htm"))
foreach ($c in $candidates) { if (Test-Path $c) { Remove-Item $c -Force } }
$destHtm = "$auto\optimizations\$ReportName.htm"

# copy the optimize .set into tester\
New-Item -ItemType Directory -Force (Join-Path $DataDir "tester") | Out-Null
$setName = [IO.Path]::GetFileName($SetFile)
Copy-Item $SetFile (Join-Path $DataDir "tester\$setName") -Force

$lines = @(
  "[Tester]",
  "TestExpert=$Expert",
  "TestExpertParameters=$setName",
  "TestSymbol=$Symbol",
  "TestPeriod=$Period",
  "TestModel=$Model",
  "TestOptimization=true",
  "TestOptimizationType=$Optimization",
  "TestDateEnable=true",
  "TestFromDate=$FromDate",
  "TestToDate=$ToDate",
  "TestReport=$ReportName",
  "TestReplaceReport=true",
  "TestShutdownTerminal=true",
  "TestVisualEnable=false"
)
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

Write-Output "OPTIMIZE: $Expert | $Symbol $Period | $FromDate..$ToDate | type=$Optimization | set=$setName"
$proc = Start-Process -FilePath $Terminal -ArgumentList "`"$ini`"" -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
$found = $null
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  foreach ($c in $candidates) { if (Test-Path $c) { $found = $c; break } }
  if ($found) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 10) {
    Start-Sleep -Seconds 3
    foreach ($c in $candidates) { if (Test-Path $c) { $found = $c; break } }
    break
  }
  Start-Sleep -Seconds 6
}
if ($found) {
  Move-Item $found $destHtm -Force
  Write-Output "OK OPT REPORT: $destHtm"
  Write-Output "next: python parse_mt4_opt.py `"$destHtm`" --csv"
}
else {
  Write-Output "NO OPT REPORT (exited=$($proc.HasExited)). MT4 headless optimization may not export an .htm on this build - check $DataDir\tester\caches\*.opt and the Experts/Journal log."
}
