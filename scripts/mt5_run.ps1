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
  [int]$ReserveCores = 4,        # leave this many logical CPUs free so the desktop stays responsive
  [switch]$Portable,             # run this terminal in /portable mode (data dir = install folder) for parallel instances
  [switch]$Force
)
$ErrorActionPreference = "Stop"

# Guard is now scoped to THIS install's exe path, not the global "terminal64" name, so a
# second portable instance (different exe path) can run in parallel without false aborts.
$TermPath = (Resolve-Path $Terminal -ErrorAction SilentlyContinue).Path
function Get-SameInstall {
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $TermPath }
}
if (-not $Force) {
  # a previous headless run of THIS install may still be closing — wait up to 25s before deciding
  $g = [Diagnostics.Stopwatch]::StartNew()
  while ((Get-SameInstall) -and $g.Elapsed.TotalSeconds -lt 25) {
    Start-Sleep -Seconds 2
  }
  if (Get-SameInstall) {
    Write-Output "ABORT: MT5 instance '$Terminal' already running. Close it, use a different -Terminal, or -Force."; exit 2
  }
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

$portTag = if ($Portable) { " [portable]" } else { "" }
Write-Output "launch: $Expert | $Symbol $Period | $FromDate..$ToDate | set=$([IO.Path]::GetFileName($SetFile))$portTag"
$argList = if ($Portable) { "/config:`"$ini`" /portable" } else { "/config:`"$ini`"" }
$proc = Start-Process -FilePath $Terminal -ArgumentList $argList -PassThru
# FREEZE GUARD: keep the box responsive even under every-tick (Model 4) load.
#  - BelowNormal priority so the desktop/UI never starves behind the tester.
#  - reserve $ReserveCores logical CPUs (affinity mask) so the machine never pegs to 100%.
# Root cause of the 2026-06-23/25 freezes: long M4 runs at default priority pegged all
# cores; a run that overran the timeout was left alive and kept chewing CPU.
try {
  Start-Sleep -Milliseconds 800   # let terminal64 spin up before we touch it
  if (-not $proc.HasExited) {
    $proc.PriorityClass = [Diagnostics.ProcessPriorityClass]::BelowNormal
    $logical = [Environment]::ProcessorCount
    if ($logical -gt ($ReserveCores + 1)) {
      $useBits = $logical - $ReserveCores
      $mask = ([bigint]1 -shl $useBits) - 1
      $proc.ProcessorAffinity = [IntPtr][int64]$mask
    }
  }
} catch { Write-Output "  (priority/affinity guard skipped: $($_.Exception.Message))" }
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (Test-Path $srcHtm) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 8) { Start-Sleep -Seconds 2; break }
  Start-Sleep -Seconds 4
}
# TIMEOUT KILL: never leave a runaway tester alive eating the machine.
if (-not $proc.HasExited -and -not (Test-Path $srcHtm)) {
  Write-Output ("TIMEOUT after {0}s - killing terminal64 (PID {1}) so it cannot keep pegging CPU." -f $TimeoutSec, $proc.Id)
  try { $proc.Kill() } catch {}
  Start-Sleep -Seconds 2
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
