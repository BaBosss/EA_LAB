<#
mt5_run.ps1 â€” headless MT5 single backtest.

Generates a Strategy Tester .ini (inputs from a .set), launches terminal64.exe
/config, waits for the HTML report, MOVES it (MT5 writes Report=<name> to the
terminal DATA folder) into _mt5_auto/reports, returns its path.

SAFETY: aborts if the MT5 GUI is already running. Close MT5 first, or -Force.

Example:
  & .\mt5_run.ps1 -Expert "MatchaGrid" -Symbol CHFJPY -FromDate 2023.01.01 `
                  -ToDate 2025.12.31 -SetFile "...\AUDCAD_robust_v1.set" -ReportName MG_CHFJPY_MAIN

  The example window IS the MAIN window (2023.01.01-2025.12.31) on purpose. It used to end in
  June 2026, which is six months inside the 2026H1 holdout - and examples get copied.
  Spending the holdout is a deliberate, once-only act; if a run is meant to do it, put
  HOLDOUT-OK on that line so the check_state holdout guard lets it through.
#>
param(
  [Parameter(Mandatory)][string]$Expert,
  [Parameter(Mandatory)][string]$Symbol,
  [string]$Period = "H1",
  [Parameter(Mandatory)][string]$FromDate,
  [Parameter(Mandatory)][string]$ToDate,
  [string]$SetFile = "",
  [int]$Model = 4,                              # 4 = every tick based on real ticks
  # NOTE: no -Spread param on purpose. MT5 (verified build 5836, ORDER-085 2026-07-10) IGNORES both
  # "Spread=" and "TestSpread=" in the /config [Tester] section â€” tester spread always comes from
  # recorded history/ticks. Spread stress must be done arithmetically on the trade list (or via a
  # custom symbol). Do NOT re-add the param without re-verifying: a silent no-op here fakes a "pass".
  [int]$Deposit = 10000,
  # âš ï¸ ORDER-165 (2026-07-23, corrected same day): leverage ini format matters.
  #   - numeric form ("Leverage=100")   -> SILENTLY IGNORED; tester uses its own cached
  #     last-used leverage setting (mutated by any GUI session) = non-reproducible.
  #   - "1:N" form   ("Leverage=1:100") -> WORKS - sets the real simulation leverage
  #     (verified against tester agent logs "initial deposit ... leverage 1:N", 4/4 samples;
  #     the report's "Leverage:" line agrees with the agent = report is truthful).
  # This script wrote the numeric form since inception -> every historical run used whatever
  # leverage the terminal's tester cache happened to hold. Now writes 1:N AND asserts the
  # report's leverage post-run (exit 3 on mismatch) - belt and suspenders.
  # âš ï¸ SAME CLASS, BIGGER BUG - INPUT CACHE: [TesterInputs] only overrides the inputs you list;
  # every UNLISTED input comes from the per-terminal cache MQL5\Profiles\Tester\<Expert>.set
  # (last-used values, rewritten by ANY run/GUI session). A run without a FULL -SetFile is
  # therefore non-reproducible. Proven 2026-07-23: identical Boss_11 binary + identical ticks
  # gave BUY 0.2-lot n=9 (lane1: cached SLMode=30-no-SL + Recovery82 + risk-sizing) vs SELL
  # 0.01-lot n=480 (lane2: pristine defaults) - this, not leverage and not "engine drift",
  # was the ORDER-162 8/8 regression false alarm. The script now WARNS on missing -SetFile.
  [int]$Leverage = 100,                         # tester leverage 1:N - written as 1:N AND asserted post-run
  [Parameter(Mandatory)][string]$ReportName,
  [string]$Terminal = "D:\Meta 5\terminal64.exe",
  [string]$DataDir = "C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355",
  [int]$TimeoutSec = 1800,
  [int]$ReserveCores = 4,        # leave this many logical CPUs free so the desktop stays responsive
  [switch]$Portable,             # run this terminal in /portable mode (data dir = install folder) for parallel instances
  [switch]$Force,
  [switch]$AllowLegacyIdentity,  # explicit non-green escape hatch for historical/fixture runs
  [string]$BuildReceiptRegistry = '', # optional exact-run registry; default remains canonical portfolio registry
  [string]$LaneId = '',
  [string]$UniversePath = '',
  [string]$CapabilityFile = ''
)
$ErrorActionPreference = "Stop"
$FrozenTesterCurrency = 'USD'

# Guard is now scoped to THIS install's exe path, not the global "terminal64" name, so a
# second portable instance (different exe path) can run in parallel without false aborts.
$TermPath = (Resolve-Path $Terminal -ErrorAction SilentlyContinue).Path
function Get-SameInstall {
  Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $TermPath }
}
if (-not $Force) {
  # a previous headless run of THIS install may still be closing â€” wait up to 25s before deciding
  $g = [Diagnostics.Stopwatch]::StartNew()
  while ((Get-SameInstall) -and $g.Elapsed.TotalSeconds -lt 25) {
    Start-Sleep -Seconds 2
  }
  if (Get-SameInstall) {
    Write-Output "ABORT: MT5 instance '$Terminal' already running. Close it, use a different -Terminal, or -Force."; exit 2
  }
}
if (-not (Test-Path $Terminal)) { Write-Output "ABORT: terminal not found: $Terminal"; exit 2 }

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'lib\symbol_preflight.ps1')
$universeCandidate = Join-Path $repoRoot 'factory\universe.jsonl'
if (-not $UniversePath -and (Test-Path -LiteralPath $universeCandidate -PathType Leaf)) { $UniversePath = $universeCandidate }
try {
  $symbolResolution = Resolve-TesterSymbol -LogicalSymbol $Symbol -TerminalPath $TermPath -DataDir $DataDir `
    -LaneId $LaneId -UniversePath $UniversePath -CapabilityFile $CapabilityFile
}
catch {
  Write-Output "ABORT: $($_.Exception.Message)"
  exit 2
}
$TesterSymbol = $symbolResolution.tester_symbol
Write-Output "symbol preflight: logical=$($symbolResolution.logical_symbol) tester=$TesterSymbol status=$($symbolResolution.comparison_status) economics=$($symbolResolution.economics_check) source=$($symbolResolution.capability_source)"
$auto = Join-Path $repoRoot '_mt5_auto'
New-Item -ItemType Directory -Force "$auto\reports", "$auto\ini" | Out-Null
$srcHtm = Join-Path $DataDir "$ReportName.htm"        # MT5 writes here (bare Report name)
$destHtm = "$auto\reports\$ReportName.htm"
# D3 fix (ORDER-094): a stale DESTINATION report from a previous run must not survive a run
# that produces NO fresh report - otherwise every downstream reader (tpl_regression, run_tests,
# any caller that just checks "does the .htm exist") sees old evidence and calls it a pass.
# Clear both source-side (tester DataDir) and destination-side (_mt5_auto\reports) before launch.
# âš ï¸ ORDER-372 (2026-07-28) - THE HOLE THIS CLEAR DOES NOT COVER, READ BEFORE RELYING ON IT:
# the two `exit 2` aborts above (GUI/lane busy at ~L72, terminal-not-found at ~L75) return BEFORE
# this line runs, so on the abort path a previous run's report is left exactly where it was. That
# is deliberate - an abort must not delete files belonging to whichever lane is currently running -
# but it means "the .htm exists" is NOT evidence that THIS invocation produced it. Demonstrated
# live: order215_matchagrid_cutloss_probe.ps1 pointed at a bogus -Terminal aborted with exit 2 and
# then reported PF=1.77 off a leftover report as though it were a fresh measurement.
# â‡’ CALLERS MUST CHECK THE EXIT CODE (0 ok / 1 no report / 2 abort / 3 leverage mismatch), and
#   ideally also that the report's mtime is newer than the moment they started the run. Both probe
#   scripts now do exactly that; copy that gate rather than inferring freshness from existence.
#   ORDER-1268 added a THIRD abort (exit 2): a -SetFile that cannot be read, or that declares a
#   surface it does not carry. It is deliberately the existing code rather than a new one -- every
#   caller already handles 2 as "did not run", and a fourth code nobody checks is a refusal that
#   reads as a pass. It is taken AFTER the clear below, so that abort leaves no report at all.
Get-ChildItem $DataDir -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem "$auto\reports" -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force

# ORDER-1268: WHAT DOES THIS .set SAY ABOUT ITS OWN SURFACE, AND DOES THE RUN RECORD IT?
# Until 2026-08-03 this block accepted ANY existing file and warned only when NONE was supplied,
# so a single-assignment .set launched a run whose other 115 inputs came from the per-terminal
# tester cache, and nothing the run produced said so. The policy is REFUSE OR RECORD (see
# scripts\lib\setfile_surface.ps1 for why it is not simply "refuse": ORDER-700 already reasoned
# that a guard which refuses the 2,177 legacy files gets switched off, and was right).
#
# DELIBERATELY PLACED AFTER THE REPORT CLEAR ABOVE, not before it. The ORDER-372 note there says
# an abort taken BEFORE the clear leaves a previous run's report exactly where it was, and that a
# probe then read PF=1.77 off it as though it were fresh. Refusing here means the destination is
# already empty, so a caller that ignores the exit code finds NO report rather than an old one.
. (Join-Path $PSScriptRoot 'lib\setfile_surface.ps1')
$surface = Get-SetSurfaceState -Path $SetFile
if ($surface.Refuse) {
  Write-Output "ABORT: $($surface.Message)"
  exit 2
}
Write-Output "surface: $($surface.State) -- $($surface.Message)"

# Identity is a launch precondition for normal evidence. The explicit legacy switch exists for
# old/fixture callers, but its output is deliberately non-green so a caller cannot mistake it for
# a stamped M2/M3 run.
. (Join-Path $PSScriptRoot 'lib\build_receipt.ps1')
. (Join-Path $PSScriptRoot 'lib\binary_staleness.ps1')
$expertsDir = Get-TesterExpertsDir -TerminalPath $TermPath -DataDir $DataDir -Portable:$Portable
$receiptRegistry = if ($BuildReceiptRegistry) { [IO.Path]::GetFullPath($BuildReceiptRegistry) } else { Join-Path $repoRoot 'portfolio\build_receipts.jsonl' }
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

# ORDER-1461: IS THE BINARY THIS RUN IS ABOUT TO LOAD OLDER THAN ITS SOURCE?
# The rule, its measurements and the visible-before-refusing reasoning all live in
# scripts\lib\binary_staleness.ps1 -- SHARED, because mt5_optimize.ps1 and run_backtest.ps1
# write Expert= into a tester .ini exactly like this file does, and covering only this one
# left the detector off two thirds of the run path (the optimizer being the worse omission:
# a stale binary there SELECTS the parameters everything downstream is built on).
Write-Output (Get-StaleCheckLine -Expert $Expert -ExpertsDir $expertsDir -RepoRoot $repoRoot)

$inputs = @()
if ($surface.State -ne 'NOSETFILE') {
  foreach ($l in Get-Content $SetFile) {
    $t = $l.Trim()
    if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) { $inputs += $t }
  }
}

# ORDER-165: leverage MUST be the "1:N" string form - the numeric form is silently ignored
# and the tester then uses its own cached last-used leverage (see -Leverage note above).
$lines = @(
  "; logical_symbol=$($symbolResolution.logical_symbol)", "; tester_symbol=$TesterSymbol", "; symbol_comparison_status=$($symbolResolution.comparison_status)", "; economics_check=$($symbolResolution.economics_check)",
  "[Tester]", "Expert=$Expert", "Symbol=$TesterSymbol", "Period=$Period", "Model=$Model",
  "Optimization=0", "FromDate=$FromDate", "ToDate=$ToDate", "ForwardMode=0",
  "Deposit=$Deposit", "Currency=$FrozenTesterCurrency", "Leverage=1:$Leverage", "ExecutionMode=0", "Visual=0",
  "Report=$ReportName", "ReplaceReport=1", "ShutdownTerminal=1", "[TesterInputs]"
) + $inputs
$ini = "$auto\ini\$ReportName.ini"
[IO.File]::WriteAllLines($ini, $lines)

$portTag = if ($Portable) { " [portable]" } else { "" }
Write-Output "launch: $Expert | logical=$($symbolResolution.logical_symbol) tester=$TesterSymbol $Period | $FromDate..$ToDate | set=$([IO.Path]::GetFileName($SetFile))$portTag"
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
  # ORDER-193 TRUNCATION CHECK: the safety cage hard-kills on equity DD and then halts for
  # the rest of the run, and it is NOT gated out of the tester. The report gives no hint:
  # you get a PF computed over however much of the window ran before the kill, formatted
  # exactly like a full-window result. Worse, the kill point moves with -Deposit, which is
  # a run setting - so two runs that look comparable may not be.
  # Warning only: never changes this script's exit code (callers depend on 0/1/3). Sidecar
  # written for the same reason the leverage one is - tpl_regression.ps1 and friends do not
  # read exit codes, so a print alone would vanish.
  # ORDER-219: the 6>&1 is load-bearing. check_truncated_run.ps1 prints its whole diagnosis
  # with Write-Host, which in PS 5.0+ goes to the INFORMATION stream (6), not the success
  # stream - so `2>&1 | Out-String` captured nothing and every one of the 182 sidecars
  # written before 2026-07-26 has detail:"". The sidecar existed, the field existed, and the
  # reason the run was flagged was thrown away at the moment of writing.
  $truncOut = ""; $truncCode = $null
  try {
    $global:LASTEXITCODE = $null
    $truncOut  = & (Join-Path $PSScriptRoot 'check_truncated_run.ps1') -Report $destHtm -FromDate $FromDate -ToDate $ToDate 2>&1 6>&1 | Out-String
    $truncCode = $LASTEXITCODE
  } catch { $truncOut = "truncation check failed: $_"; $truncCode = -1 }
  . (Join-Path $PSScriptRoot 'lib\truncation_evidence.ps1')
  New-TruncationEvidence -ReportName $ReportName -CheckerExitCode $truncCode -Detail $truncOut |
    ConvertTo-Json | Set-Content "$auto\reports\$ReportName.truncation_check.json" -Encoding utf8
  if ($truncCode -eq 2) {
    Write-Output "WARN TRUNCATED-RUN: $ReportName stopped trading well before its window ended - metrics may cover only part of the window. Detail: $($truncOut.Trim())"
  }
  $global:LASTEXITCODE = 0   # the check is advisory; do not let its code leak into ours
  # ORDER-165 LEVERAGE ASSERTION: verify the tester actually used the leverage we pinned.
  # The report's "Leverage:" line reflects the real simulation leverage (agrees with the
  # tester agent log's "initial deposit ... leverage 1:N" - verified 4/4 samples 2026-07-23,
  # +4 more independent samples same day: 100/500/9999/250 all matched exactly via the 1:N
  # ini form, while numeric-only form gave a fixed 1:7 regardless of the requested number).
  # Mismatch = ini didn't take (format regression / future build change) -> fail loudly
  # (exit 3, distinct from no-report exit 1) instead of letting a silently-wrong margin
  # context poison downstream verdicts.
  # Sidecar JSON (ORDER-165, added because a real caller â€” tpl_regression.ps1 â€” never checks
  # mt5_run.ps1's exit code at all; a printed warning + exit 3 alone would pass through it
  # silently). Written every time so callers have one stable path to check instead of each
  # re-implementing the report regex. requested/actual are null when the report has no usable
  # leverage line (0-trade / degenerate report) â€” that's "unknown", not "match" or "mismatch".
  $rpt = [IO.File]::ReadAllText($destHtm, [Text.Encoding]::Unicode)
  $lm = [regex]::Match(($rpt -replace '<[^>]+>', ' '), 'Leverage:\s*1:(\d+)')
  $sidecar = "$auto\reports\$ReportName.leverage_check.json"
  if ($lm.Success) {
    $actualLev = [int]$lm.Groups[1].Value
    # "1:0" shows up on some no-trade/degenerate reports (seen: TPLREG_B18_bisect1.htm) -
    # that's "not recorded", not "account leverage is zero". Warn, don't false-fail.
    if ($actualLev -eq 0) {
      [PSCustomObject]@{ report_name=$ReportName; requested_leverage=$Leverage; actual_leverage=$null; match=$null; status='NOT_RECORDED' } |
        ConvertTo-Json | Set-Content -Path $sidecar -Encoding UTF8
      Write-Output "OK REPORT: $destHtm (WARN: report shows leverage 1:0 = not recorded - assertion skipped)"
      exit 0
    }
    $isMatch = ($actualLev -eq $Leverage)
    [PSCustomObject]@{ report_name=$ReportName; requested_leverage=$Leverage; actual_leverage=$actualLev; match=$isMatch; status=$(if ($isMatch) { 'MATCH' } else { 'MISMATCH' }) } |
      ConvertTo-Json | Set-Content -Path $sidecar -Encoding UTF8
    if (-not $isMatch) {
      Write-Output ("LEVERAGE MISMATCH: asserted 1:{0} but tester ran at the account's 1:{1} - report kept at {2} but numbers are NOT comparable to 1:{0} runs. Log this lane into a 1:{0} account or pass -Leverage {1} deliberately. Machine-readable: $sidecar" -f $Leverage, $actualLev, $destHtm)
      exit 3
    }
    Write-Output "OK REPORT: $destHtm (leverage verified 1:$actualLev)"
    exit 0
  }
  # 0-trade reports can omit the Leverage line - surface it rather than guess.
  [PSCustomObject]@{ report_name=$ReportName; requested_leverage=$Leverage; actual_leverage=$null; match=$null; status='NO_LEVERAGE_LINE' } |
    ConvertTo-Json | Set-Content -Path $sidecar -Encoding UTF8
  Write-Output "OK REPORT: $destHtm (WARN: leverage line not found in report - assertion skipped)"
  exit 0
}
else {
  Write-Output "NO REPORT (exited=$($proc.HasExited)). Check EA name / symbol history / login."
  exit 1
}
