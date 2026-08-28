<#
mt5_optimize.ps1 — headless MT5 OPTIMIZATION.

Same proven pattern as mt5_run.ps1 (Report=<bare name> -> written to the terminal
DATA folder, then moved here). Runs a genetic optimization using the optimize
ranges baked into the base .set (the ||start||step||stop||Y lines), then collects
the optimizer XML for the pre-registered candidate/hypothesis selection contract
to consume (NOT select_robust_pass.py -- that script implements the archived,
superseded BacktestScore v1 gate; see the "next:" line this script prints).

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
  [ValidateRange(0,60)][int]$XmlFlushGraceSec = 15, # bounded post-exit wait for delayed optimizer XML flush
  [switch]$Portable,   # 2nd portable install (D:\Meta 5b): pass -Terminal/-DataDir there too
  [switch]$Force,
  [switch]$AllowLegacyIdentity,  # explicit non-green escape hatch for historical/fixture runs
  [string]$BuildReceiptRegistry = '',  # optional exact per-run receipt ledger; defaults to canonical portfolio ledger
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
  # Optional ParameterBinding overlay for an attributed validation run. optimize_guard treats
  # this as an ADD-ONLY overlay (canonical bindings win), so it can never relax canonical policy.
  [string]$BindingsRoot = '',
  [Nullable[int]]$GuardBuild = $null,
  [string]$LaneId = '',
  [string]$UniversePath = '',
  [string]$CapabilityFile = ''
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $Terminal -PathType Leaf)) {
  Write-Output "ABORT: terminal not found: $Terminal"; exit 2
}
# Checked BEFORE any use of $PSScriptRoot: both the dot-source below (Join-Path) and the
# repo-root derivation (Split-Path -Parent) THROW a parameter-binding exception on an empty
# string rather than returning one, so the checked value must be $PSScriptRoot itself, not
# something derived from it a line later.
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
  Write-Output "ABORT: could not resolve the repo root -- `$PSScriptRoot is empty. Run this script with -File (not as an inline scriptblock/expression) so PowerShell sets `$PSScriptRoot; refusing to fall back to a guessed or hardcoded path."
  exit 2
}
. (Join-Path $PSScriptRoot 'lib\symbol_preflight.ps1')
$repoRoot = Split-Path -Parent $PSScriptRoot
$universeCandidate = Join-Path $repoRoot 'factory\universe.jsonl'
if (-not $UniversePath -and (Test-Path -LiteralPath $universeCandidate -PathType Leaf)) { $UniversePath = $universeCandidate }
try {
  $symbolResolution = Resolve-TesterSymbol -LogicalSymbol $Symbol -TerminalPath $Terminal -DataDir $DataDir `
    -LaneId $LaneId -UniversePath $UniversePath -CapabilityFile $CapabilityFile
}
catch {
  Write-Output "ABORT: $($_.Exception.Message)"
  exit 2
}
$TesterSymbol = $symbolResolution.tester_symbol
Write-Output "symbol preflight: logical=$($symbolResolution.logical_symbol) tester=$TesterSymbol status=$($symbolResolution.comparison_status) economics=$($symbolResolution.economics_check) source=$($symbolResolution.capability_source)"
# guard scoped by exe PATH (same convention as mt5_run.ps1) so the two installs
# can run in parallel without aborting each other
$running = Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Terminal }
if ($running -and -not $Force) {
  Write-Output "ABORT: this MT5 instance is running ($Terminal). Close it first, or -Force."; exit 2
}

$auto = Join-Path $repoRoot "_mt5_auto"
New-Item -ItemType Directory -Force "$auto\optimizations", "$auto\ini" | Out-Null
$srcXml = Join-Path $DataDir "$ReportName.xml"
$destXml = "$auto\optimizations\$ReportName.xml"
Get-ChildItem $DataDir -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force

# A-F2: CLEAR THE DESTINATION TOO, BEFORE THE LAUNCH.
# The line above clears the SOURCE side only. The destination is keyed on the report name, and the
# collection step at the bottom of this script is conditional (`if (Test-Path $srcXml)`), so a run
# that produced nothing used to leave the PREVIOUS run's XML sitting at
# _mt5_auto\optimizations\<ReportName>.xml -- which is the path every downstream consumer reads
# (scripts\pilot_probe.ps1 records it as this run's `xml`; scripts\pilot_probe_select.py loads
# surfaces out of that directory). pilot_probe.ps1's own comment records a smoke run where exactly
# that happened: a cell whose launcher aborted found the XML from that cell's earlier successful
# run and reported xml_present=true. That reader was given an mtime freshness test; the launcher
# was not, so the stale artefact stayed readable by everyone else.
#
# QUARANTINED, NOT DELETED. The file may be another lane's evidence, so it is renamed rather than
# removed and the rename is PRINTED -- an artefact that disappears silently is its own problem.
# SCOPE IS EXACTLY THIS REPORT NAME: this touches $destXml and nothing else in the directory.
if (Test-Path -LiteralPath $destXml -PathType Leaf) {
  $supersededXml = $destXml + '.superseded-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
  Move-Item -LiteralPath $destXml -Destination $supersededXml -Force
  Write-Output "STALE DEST XML: a previous artefact was already at $destXml under this report name. Quarantined to $supersededXml so this run cannot be read off it. Nothing else in $auto\optimizations was touched."
}

# Hygiene: clear the optimization cache so every run is provably fresh.
# (2026-07-04 note: a suspected cross-date cache-reuse bug was DISPROVEN by a
# controlled rerun - identical IS vs full-window rows on GBPAUD turned out to be
# genuine range-dormancy, both resting-stop sides unhit for the final 13 months.
# Clearing stays as cheap insurance against ever confusing the two cases.)
$testerCache = Join-Path $DataDir "Tester\cache"
if (Test-Path $testerCache) {
  Get-ChildItem $testerCache -Filter "*.opt" -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

# ORDER-1268: the same REFUSE-OR-RECORD gate mt5_run.ps1 applies, and this launcher needed it
# MORE. mt5_run at least warned when no .set was supplied; this one read whatever it was handed
# and said nothing at all. An optimize pass launched off a partial file explores a grid whose
# UNSWEPT axes come from the per-terminal tester cache, so the winning row names a configuration
# that cannot be reproduced -- and an optimize result is exactly the artifact this lab then locks
# a .set from. The judging lives in scripts\lib\setfile_surface.ps1; one owner, three launchers (mt5_run · mt5_optimize · run_backtest).
. (Join-Path $PSScriptRoot 'lib\setfile_surface.ps1')
$surface = Get-SetSurfaceState -Path $SetFile
if ($surface.Refuse) {
  Write-Output "ABORT: $($surface.Message)"
  exit 2
}
Write-Output "surface: $($surface.State) -- $($surface.Message)"

# Normal optimization evidence must bind the exact executable and full config before the
# optimizer selects anything. Legacy use is available only as an explicitly non-green escape.
. (Join-Path $PSScriptRoot 'lib\build_receipt.ps1')
. (Join-Path $PSScriptRoot 'lib\binary_staleness.ps1')
$expertsDir = Get-TesterExpertsDir -TerminalPath $Terminal -DataDir $DataDir -Portable:$Portable
$receiptRegistry = if ([string]::IsNullOrWhiteSpace($BuildReceiptRegistry)) { Join-Path $repoRoot 'portfolio\build_receipts.jsonl' } else { $BuildReceiptRegistry }
$buildIdentity = Get-BuildReceiptStatus -Expert $Expert -ExpertsDir $expertsDir `
  -RegistryPath $receiptRegistry
if (($Expert -replace '\.ex5$','') -ieq 'Boss_14_GridLog') {
  $buildIdentity = Get-ManagedCompatibilityStatus -ExpertsDir $expertsDir `
    -RegistryPath $receiptRegistry
}
$configIdentity = Get-SetConfigIdentity -Path $SetFile -Surface $surface
if (-not $AllowLegacyIdentity -and (-not $buildIdentity.Valid -or -not $configIdentity.Valid)) {
  Write-Output ("ABORT: identity refusal -- build={0} ({1}); config={2} ({3}). Pass -AllowLegacyIdentity only for explicitly non-green legacy/fixture work." -f
    $buildIdentity.State, $buildIdentity.Reason, $configIdentity.State, $configIdentity.Reason)
  exit 2
}
if ($AllowLegacyIdentity) {
  Write-Output ("identity: LEGACY_ALLOWED -- build={0} ({1}); config={2} ({3})" -f
    $buildIdentity.State, $buildIdentity.Reason, $configIdentity.State, $configIdentity.Reason)
} else {
  Write-Output (Format-LaunchIdentityLine -Build $buildIdentity -Config $configIdentity)
}

# ORDER-1461, and this is the entry point that mattered most. An OPTIMIZATION run does not
# merely report a wrong number off a stale binary -- it SELECTS the parameters everything
# downstream is built on. The rule and its measurements live in scripts\lib\binary_staleness.ps1,
# shared with mt5_run.ps1 and run_backtest.ps1. Advisory: it cannot abort and cannot change an
# exit code.
Write-Output (Get-StaleCheckLine -Expert $Expert -ExpertsDir $expertsDir -RepoRoot $repoRoot)

$inputs = @()
if ($surface.State -ne 'NOSETFILE') {
  foreach ($l in Get-Content $SetFile) {
    $t = $l.Trim()
    if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) { $inputs += $t }
  }
}

$lines = @(
  "; logical_symbol=$($symbolResolution.logical_symbol)", "; tester_symbol=$TesterSymbol", "; symbol_comparison_status=$($symbolResolution.comparison_status)", "; economics_check=$($symbolResolution.economics_check)",
  "[Tester]", "Expert=$Expert", "Symbol=$TesterSymbol", "Period=$Period", "Model=$Model",
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
# `hardcoded-repo-path-defeats-worktree-cage`; the `$auto` line above was once an instance of
# this and is now derived from `$repoRoot` -- see run_mt5_optimize_launcher_hardening_tests.ps1).
$decisionLog = Join-Path $repoRoot "factory\optimize_decisions.jsonl"
$guardExtra = @{ DecisionLog = $decisionLog; Lane = $Terminal }
if ($HypothesisRevision -ne '') { $guardExtra['HypothesisRevision'] = $HypothesisRevision }
if ($BindingsRoot -ne '')       { $guardExtra['BindingsRoot'] = $BindingsRoot }
if ($null -ne $GuardBuild)      { $guardExtra['Build'] = $GuardBuild }
# The guard's presence is required, not advisory: an optimize pass SELECTS the parameters
# everything downstream is built on, so a missing guard must ABORT the launch, not silently
# skip the pre-flight and let the sweep proceed unchecked. -SkipOptimizeGuard overrides an
# existing guard's REFUSE verdict (a governed, printed override); it is not a substitute for
# the guard existing at all, so this check runs BEFORE -SkipOptimizeGuard is considered.
if (-not (Test-Path -LiteralPath $guardScript -PathType Leaf)) {
  Write-Output "ABORT: optimize_guard.ps1 not found at $guardScript. The governed pre-flight guard is required before every optimize pass (ORDER-192b) -- it cannot be skipped by omission."
  Write-Output "        Corrective action: restore the file (e.g. 'git checkout -- scripts\optimize_guard.ps1'), or run from a repo checkout that has it. -SkipOptimizeGuard only overrides a REFUSE verdict from an EXISTING guard; it cannot substitute for a missing one."
  exit 5
}
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

Write-Output "OPTIMIZE: $Expert | logical=$($symbolResolution.logical_symbol) tester=$TesterSymbol $Period | $FromDate..$ToDate | mode=$Optimization"
$mtArgs = @("/config:`"$ini`""); if ($Portable) { $mtArgs += "/portable" }
$proc = Start-Process -FilePath $Terminal -ArgumentList $mtArgs -PassThru
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
  if (Test-Path $srcXml) { Start-Sleep -Seconds 2; break }
  if ($proc.HasExited -and $sw.Elapsed.TotalSeconds -gt 10) { Start-Sleep -Seconds 2; break }
  Start-Sleep -Seconds 6
}
# Some MT5 builds flush the optimizer XML a few seconds AFTER terminal64.exe exits.
# Do not convert that exporter race into a false NO-XML failure: once the process is known
# exited, give only this exact source path a bounded grace period. Stale-destination quarantine
# above remains unchanged, and a genuinely absent XML still exits 4.
if (-not (Test-Path -LiteralPath $srcXml) -and $proc.HasExited -and $XmlFlushGraceSec -gt 0) {
  $flushSw = [Diagnostics.Stopwatch]::StartNew()
  while ($flushSw.Elapsed.TotalSeconds -lt $XmlFlushGraceSec) {
    if (Test-Path -LiteralPath $srcXml -PathType Leaf) {
      Write-Output ("XML FLUSH GRACE: source appeared {0:N1}s after post-exit polling began." -f $flushSw.Elapsed.TotalSeconds)
      break
    }
    Start-Sleep -Milliseconds 500
  }
}
if (Test-Path $srcXml) {
  Move-Item $srcXml $destXml -Force
  Write-Output "OK OPTIMIZER XML: $destXml"
  . (Join-Path $PSScriptRoot 'lib\optimize_next_step.ps1')
  Write-Output (Get-OptimizeNextStepMessage -DestXml $destXml -HypothesisRevision $HypothesisRevision)
}
else {
  Write-Output "NO XML (exited=$($proc.HasExited)). If the test ran but produced no .xml, the optimization report may export differently on this build. Check the $ReportName files in $DataDir and the Tester logs."
  # A-F2: state the CONSUMER-side fact, not only the source-side one. The destination was
  # quarantined before launch, so a reader of $destXml sees an absent artefact rather than a
  # previous run's surface under this run's report name. Asserted, not assumed: if something
  # re-created the path between the quarantine and here, say so instead of claiming absence.
  if (Test-Path -LiteralPath $destXml) {
    Write-Output "        WARNING: $destXml EXISTS despite this run producing no optimizer XML. It was not written by this run's collection step. Do not read it as this run's surface."
  } else {
    Write-Output "        Consumer path: the destination is ABSENT ($destXml). No previous run's surface can be read as this run's evidence."
  }
  # ORDER-1253: EXIT 4, not 0. This printed the line above and then fell off the end of the
  # script, which PowerShell exits 0 for -- so a launcher whose ONLY product is an optimizer XML
  # reported SUCCESS when that XML did not exist. Measured, not theorised: a pilot probe
  # submission with a malformed symbol ran 14.4s, produced nothing, and was written into
  # factory/runs/pilot/probe/ as `launcher_exit_code: 0`, indistinguishable from the 675.5s run
  # beside it that produced a real surface.
  #
  # BLAST RADIUS, stated rather than discovered: every caller of this script that checks the exit
  # code now sees a failure where it previously saw success -- scripts/optimize_loop.ps1,
  # scripts/run_batch.ps1, scripts/qwen_batch_runner.ps1. That is the correction, not a
  # side effect: each of them was accepting "no optimization happened" as a completed pass.
  exit 4
}
