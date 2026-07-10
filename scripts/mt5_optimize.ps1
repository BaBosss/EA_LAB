<#
mt5_optimize.ps1 — headless MT5 OPTIMIZATION.

Same proven pattern as mt5_run.ps1 (Report=<bare name> -> written to the terminal
DATA folder, then moved here). Runs a genetic optimization using the optimize
ranges baked into the base .set (the ||start||step||stop||Y lines), then collects
the optimizer XML so select_robust_pass.py can pick the robust pass.

STATUS: launcher built on the verified single-test mechanism. The single-test
path is proven; the optimization XML auto-export is expected to work the same way
but should be confirmed on first real run (MT5 must be CLOSED).

Example:
  & .\mt5_optimize.ps1 -Expert "Boss - 2 Adaptive Smart Grid" -Symbol EURCAD `
        -SetFile "...\EURCAD.set" -FromDate 2023.06.01 -ToDate 2026.06.01 -ReportName OPT_EURCAD
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [Parameter(Mandatory)][string]$SetFile,       # base .set WITH optimize ranges (||...||Y)
  [int]$Model = 1,                              # 1 = 1-min OHLC (fast) for optimization
  [int]$Optimization = 2,                       # 2 = fast genetic, 1 = slow complete
  [int]$Criterion = 0,                          # 0 = max balance
  [int]$Deposit = 10000,
  [int]$Leverage = 100,                         # tester account leverage (1:N)
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355",
  [int]$TimeoutSec = 7200,
  [switch]$Portable,   # 2nd portable install (D:\Meta 5b): pass -Terminal/-DataDir there too
  [switch]$Force
)
$ErrorActionPreference = "Stop"
# guard scoped by exe PATH (same convention as mt5_run.ps1) so the two installs
# can run in parallel without aborting each other
$running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Terminal }
if ($running -and -not $Force) {
  Write-Output "ABORT: this MT5 instance is running ($Terminal). Close it first, or -Force."; exit 2
}

$auto = "D:\EA_LAB\_mt5_auto"
New-Item -ItemType Directory -Force "$auto\optimizations", "$auto\ini" | Out-Null
$srcXml = Join-Path $DataDir "$ReportName.xml"
$destXml = "$auto\optimizations\$ReportName.xml"
Get-ChildItem $DataDir -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force

# Hygiene: clear the optimization cache so every run is provably fresh.
# (2026-07-04 note: a suspected cross-date cache-reuse bug was DISPROVEN by a
# controlled rerun - identical IS vs full-window rows on GBPAUD turned out to be
# genuine range-dormancy, both resting-stop sides unhit for the final 13 months.
# Clearing stays as cheap insurance against ever confusing the two cases.)
$testerCache = Join-Path $DataDir "Tester\cache"
if (Test-Path $testerCache) {
  Get-ChildItem $testerCache -Filter "*.opt" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

$inputs = @()
foreach ($l in Get-Content $SetFile) {
  $t = $l.Trim()
  if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) { $inputs += $t }
}

$lines = @(
  "[Tester]", "Expert=$Expert", "Symbol=$Symbol", "Period=$Period", "Model=$Model",
  "Optimization=$Optimization", "OptimizationCriterion=$Criterion",
  "FromDate=$FromDate", "ToDate=$ToDate", "ForwardMode=0",
  "Deposit=$Deposit", "Currency=USD", "Leverage=$Leverage", "ExecutionMode=0", "Visual=0",
  "Report=$ReportName", "ReplaceReport=1", "ShutdownTerminal=1", "[TesterInputs]"
) + $inputs
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

Write-Output "OPTIMIZE: $Expert | $Symbol $Period | $FromDate..$ToDate | mode=$Optimization"
$mtArgs = @("/config:`"$ini`""); if ($Portable) { $mtArgs += "/portable" }
$proc = Start-Process -FilePath $Terminal -ArgumentList $mtArgs -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (Test-Path $srcXml) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 10) { Start-Sleep -Seconds 2; break }
  Start-Sleep -Seconds 6
}
if (Test-Path $srcXml) {
  Move-Item $srcXml $destXml -Force
  Write-Output "OK OPTIMIZER XML: $destXml"
  Write-Output "next: python select_robust_pass.py `"$destXml`" --strategy <strat>"
}
else {
  Write-Output "NO XML (exited=$($proc.HasExited)). If the test ran but produced no .xml, the optimization report may export differently on this build. Check the $ReportName files in $DataDir and the Tester logs."
}
