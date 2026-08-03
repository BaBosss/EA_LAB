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
        -SetFile "...\EURCAD.set" -FromDate 2023.01.01 -ToDate 2025.12.31 -ReportName OPT_EURCAD

  The example window IS MAIN (2023.01.01-2025.12.31). Optimizing past it selects parameters on
  the 2026H1 holdout, which spends it - the exact leak found on 2026-07-25. Enforced by the
  holdout guard in check_state.ps1; HOLDOUT-OK on a line opts out when that is intended.
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
  [int]$Criterion = 7,                          # 7 = Complex Criterion (policy 2026-07-25; 0=balance max drives the genetic population into spikes) - engine-edge-class EAs pass -Criterion 1 (PF max)
  [int]$Deposit = 10000,
  [int]$Leverage = 100,                         # tester account leverage (1:N)
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355",
  [int]$TimeoutSec = 7200,
  [switch]$Portable,   # 2nd portable install (D:\Meta 5b): pass -Terminal/-DataDir there too
  [switch]$Force,
  [switch]$SkipOptimizeGuard,  # override: proceed even if optimize_guard.ps1 refuses a swept dimension
  # ORDER-1253. Both are passed straight through to optimize_guard.ps1 and both default to the
  # behaviour every existing call site already gets.
  #
  # WHY THEY HAD TO EXIST. The pilot's own probe .ini names a GENERATED WRAPPER as its Expert, so
  # the guard resolves no Boss build and prints "build-inertness NOT checked" for every dimension
  # -- and with no revision declared, the per-hypothesis ParameterBinding layer (design 5.4, the
  # one resolver) never runs either. The two checks with the most evidence behind them were both
  # silently inactive on exactly the sweeps the Factory OS pilot exists to judge, and the decision
  # record's `binding` field was null on every real submission as a result.
  [string]$HypothesisRevision = '',
  [Nullable[int]]$GuardBuild = $null
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
  "Deposit=$Deposit", "Currency=USD", "Leverage=1:$Leverage", "ExecutionMode=0", "Visual=0",
  # Leverage MUST be written as 1:N - a bare "Leverage=100" is silently ignored and the
  # tester falls back to the server default (observed: OPT_MDX_GBP ran at 1:2000).
  "Report=$ReportName", "ReplaceReport=1", "ShutdownTerminal=1", "[TesterInputs]"
) + $inputs
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

# ORDER-198 follow-up (user 2026-07-24: "บังคับแบบ warn + override ได้"): pre-flight every
# optimize pass through optimize_guard.ps1 (ORDER-192b) BEFORE burning tester wall-clock on
# a sweep that provably can't do anything (dead/overridden/inactive dimension) or that
# optimizes away a safety cap (RC_*/ProtectLevel/_9_MaxLevels). Default = blocks on REFUSE;
# -SkipOptimizeGuard proceeds anyway (still prints the REFUSE lines via -WarnOnly, never silent).
$guardScript = Join-Path $PSScriptRoot "optimize_guard.ps1"
# ORDER-1253 (design 8.6 item 6). The guard's verdicts used to be printed and lost, so "the guard
# has been observed refusing a real case" was unanswerable from anything committed. Every pass
# through here now leaves ONE record.
#
# SCOPE, STATED HONESTLY: this is the only MT5 OPTIMIZER launcher in the repo (mt5_run.ps1 and
# run_backtest.ps1 both write `Optimization=0`), so every optimizer sweep is recorded. It is NOT
# "every parameter selection is recorded" -- a PowerShell grid loop over single tests selects a
# config with the optimizer flag at 0 and this guard never sees it (memory
# `optimization-flag-launders-hand-rolled-selection`). That hole is unchanged by this record.
#
# The repo root is derived, not typed: a hardcoded D:\EA_LAB defeats the worktree cage (memory
# `hardcoded-repo-path-defeats-worktree-cage`, and the `$auto` line above is an instance of it).
$decisionLog = Join-Path (Split-Path -Parent $PSScriptRoot) "factory\optimize_decisions.jsonl"
$guardExtra = @{ DecisionLog = $decisionLog; Lane = $Terminal }
if ($HypothesisRevision -ne '') { $guardExtra['HypothesisRevision'] = $HypothesisRevision }
if ($null -ne $GuardBuild)      { $guardExtra['Build'] = $GuardBuild }
if (Test-Path $guardScript) {
  if ($SkipOptimizeGuard) {
    Write-Output "optimize_guard: -SkipOptimizeGuard passed, running in warn-only mode (will not block)"
    & $guardScript -IniPath $ini -WarnOnly @guardExtra | Write-Output
  }
  else {
    & $guardScript -IniPath $ini @guardExtra | Write-Output
    if ($LASTEXITCODE -ne 0) {
      Write-Output "ABORT: optimize_guard.ps1 refused at least one swept dimension in $ini (see REFUSE lines above)."
      Write-Output "        Re-run with -SkipOptimizeGuard to proceed anyway (e.g. a confirmed false positive)."
      exit 3
    }
  }
}
else {
  Write-Output "optimize_guard: scripts\optimize_guard.ps1 not found, skipping pre-flight check"
}

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
