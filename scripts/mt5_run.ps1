<#
mt5_run.ps1 — headless MT5 single backtest.

Generates a Strategy Tester .ini (inputs from a .set), launches terminal64.exe
/config, waits for the HTML report, MOVES it (MT5 writes Report=<name> to the
terminal DATA folder) into _mt5_auto/reports, returns its path.

SAFETY: aborts if the MT5 GUI is already running. Close MT5 first, or -Force.

Example:
  & .\mt5_run.ps1 -Expert "MatchaGrid" -Symbol CHFJPY -FromDate 2023.06.01 `
                  -ToDate 2026.06.01 -SetFile "...\AUDCAD_robust_v1.set" -ReportName MG_CHFJPY_IS
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [string]$SetFile = "",
  [int]$Model = 4,                              # 4 = every tick based on real ticks
  [int]$Deposit = 10000,
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355",
  [int]$TimeoutSec = 1800,
  [switch]$Force
)
$ErrorActionPreference = "Stop"

if ((Get-Process terminal64 -ErrorAction SilentlyContinue) -and -not $Force) {
  Write-Output "ABORT: MT5 GUI is running. Close it first, or pass -Force."; exit 2
}
if (-not (Test-Path $Terminal)) { Write-Output "ABORT: terminal not found: $Terminal"; exit 2 }

$auto = "D:\EA_LAB\_mt5_auto"
New-Item -ItemType Directory -Force "$auto\reports", "$auto\ini" | Out-Null
$srcHtm = Join-Path $DataDir "$ReportName.htm"        # MT5 writes here (bare Report name)
$destHtm = "$auto\reports\$ReportName.htm"
Get-ChildItem $DataDir -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force

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
  "Report=$ReportName", "ReplaceReport=1", "ShutdownTerminal=1", "[TesterInputs]"
) + $inputs
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

Write-Output "launch: $Expert | $Symbol $Period | $FromDate..$ToDate | set=$([IO.Path]::GetFileName($SetFile))"
$proc = Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ini`"" -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (Test-Path $srcHtm) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 8) { Start-Sleep -Seconds 2; break }
  Start-Sleep -Seconds 4
}
if (Test-Path $srcHtm) {
  Move-Item $srcHtm $destHtm -Force
  Get-ChildItem $DataDir -Filter "$ReportName*.png" -File -ErrorAction SilentlyContinue |
    Move-Item -Destination "$auto\reports\" -Force
  Write-Output "OK REPORT: $destHtm"
}
else {
  Write-Output "NO REPORT (exited=$($proc.HasExited)). Check EA name / symbol history / login."
}
