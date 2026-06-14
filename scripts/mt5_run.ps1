<#
mt5_run.ps1 — headless MT5 single backtest.

Generates a Strategy Tester .ini (with inputs from a .set), launches
terminal64.exe /config, waits for the HTML report, returns its path.

SAFETY: aborts if the MT5 GUI is already running (headless conflicts with an
open terminal on the same data folder). Close MT5 first, or pass -Force.

Example:
  .\mt5_run.ps1 -Expert "MatchaGrid" -Symbol CHFJPY -FromDate 2023.06.01 `
                -ToDate 2026.06.01 -SetFile "D:\EA_LAB\_shortlist_sets\AUDCAD_robust_v1.set" `
                -ReportName MG_CHFJPY_IS
#>
param(
  [Parameter(Mandatory)][string]$Expert,        # name under MQL5\Experts, no .ex5
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,      # 2023.06.01
  [Parameter(Mandatory)][string]$ToDate,        # 2026.06.01
  [string]$SetFile = "",
  [int]$Model = 4,                              # 4 = every tick based on real ticks
  [int]$Deposit = 10000,
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [int]$TimeoutSec = 1200,
  [switch]$Force
)
$ErrorActionPreference = "Stop"

if ((Get-Process terminal64 -ErrorAction SilentlyContinue) -and -not $Force) {
  Write-Output "ABORT: MT5 GUI is running. Close it first (headless run needs the data folder free), or pass -Force."
  exit 2
}
if (-not (Test-Path $Terminal)) { Write-Output "ABORT: terminal not found: $Terminal"; exit 2 }

$auto = "D:\EA_LAB\_mt5_auto"
New-Item -ItemType Directory -Force "$auto\reports", "$auto\ini" | Out-Null
$report = "$auto\reports\$ReportName"
$htm = "$report.htm"
if (Test-Path $htm) { Remove-Item $htm -Force }

$inputs = @()
if ($SetFile -and (Test-Path $SetFile)) {
  foreach ($l in Get-Content $SetFile) {
    $t = $l.Trim()
    if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) { $inputs += $t }
  }
}

$lines = @(
  "[Tester]", "Expert=$Expert", "Symbol=$Symbol", "Period=$Period", "Model=$Model",
  "Optimization=0", "FromDate=$FromDate", "ToDate=$ToDate", "ForwardMode=0",
  "Deposit=$Deposit", "Currency=USD", "Leverage=100", "ExecutionMode=0", "Visual=0",
  "Report=$report", "ReplaceReport=1", "ShutdownTerminal=1", "[TesterInputs]"
) + $inputs
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

Write-Output "launch: $Expert | $Symbol $Period | $FromDate..$ToDate | set=$([IO.Path]::GetFileName($SetFile))"
$proc = Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (Test-Path $htm) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited) { break }
  Start-Sleep -Seconds 4
}
if (Test-Path $htm) { Write-Output "OK REPORT: $htm" }
else { Write-Output "NO REPORT (timeout/blocked; exited=$($proc.HasExited)). Check EA name, symbol history, and login." }
