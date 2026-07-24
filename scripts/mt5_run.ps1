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
  # NOTE: no -Spread param on purpose. MT5 (verified build 5836, ORDER-085 2026-07-10) IGNORES both
  # "Spread=" and "TestSpread=" in the /config [Tester] section — tester spread always comes from
  # recorded history/ticks. Spread stress must be done arithmetically on the trade list (or via a
  # custom symbol). Do NOT re-add the param without re-verifying: a silent no-op here fakes a "pass".
  [int]$Deposit = 10000,
  # ⚠️ ORDER-165 (2026-07-23, corrected same day): leverage ini format matters.
  #   - numeric form ("Leverage=100")   -> SILENTLY IGNORED; tester uses its own cached
  #     last-used leverage setting (mutated by any GUI session) = non-reproducible.
  #   - "1:N" form   ("Leverage=1:100") -> WORKS - sets the real simulation leverage
  #     (verified against tester agent logs "initial deposit ... leverage 1:N", 4/4 samples;
  #     the report's "Leverage:" line agrees with the agent = report is truthful).
  # This script wrote the numeric form since inception -> every historical run used whatever
  # leverage the terminal's tester cache happened to hold. Now writes 1:N AND asserts the
  # report's leverage post-run (exit 3 on mismatch) - belt and suspenders.
  # ⚠️ SAME CLASS, BIGGER BUG - INPUT CACHE: [TesterInputs] only overrides the inputs you list;
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
# D3 fix (ORDER-094): a stale DESTINATION report from a previous run must not survive a run
# that produces NO fresh report - otherwise every downstream reader (tpl_regression, run_tests,
# any caller that just checks "does the .htm exist") sees old evidence and calls it a pass.
# Clear both source-side (tester DataDir) and destination-side (_mt5_auto\reports) before launch.
Get-ChildItem $DataDir -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem "$auto\reports" -Filter "$ReportName*" -File -ErrorAction SilentlyContinue | Remove-Item -Force

$inputs = @()
if ($SetFile -and (Test-Path $SetFile)) {
  foreach ($l in Get-Content $SetFile) {
    $t = $l.Trim()
    if ($t -and -not $t.StartsWith(";") -and $t.Contains("=")) { $inputs += $t }
  }
} else {
  # ORDER-165: without a set file, every input comes from the per-terminal tester cache
  # (MQL5\Profiles\Tester\<Expert>.set = last-used values, rewritten by any session that
  # touches this EA in this terminal) - the run is NOT reproducible and not comparable to
  # any other run of the "same" EA. Loud warning, not a hard fail: some callers (default-
  # capture, throwaway probes) do this deliberately.
  Write-Output "WARN: no -SetFile - unlisted inputs come from this terminal's tester cache (MQL5\Profiles\Tester) = NON-REPRODUCIBLE. Pass a FULL .set for any number you intend to keep."
}

# ORDER-165: leverage MUST be the "1:N" string form - the numeric form is silently ignored
# and the tester then uses its own cached last-used leverage (see -Leverage note above).
$lines = @(
  "[Tester]", "Expert=$Expert", "Symbol=$Symbol", "Period=$Period", "Model=$Model",
  "Optimization=0", "FromDate=$FromDate", "ToDate=$ToDate", "ForwardMode=0",
  "Deposit=$Deposit", "Currency=USD", "Leverage=1:$Leverage", "ExecutionMode=0", "Visual=0",
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
  # ORDER-193 TRUNCATION CHECK: the safety cage hard-kills on equity DD and then halts for
  # the rest of the run, and it is NOT gated out of the tester. The report gives no hint:
  # you get a PF computed over however much of the window ran before the kill, formatted
  # exactly like a full-window result. Worse, the kill point moves with -Deposit, which is
  # a run setting - so two runs that look comparable may not be.
  # Warning only: never changes this script's exit code (callers depend on 0/1/3). Sidecar
  # written for the same reason the leverage one is - tpl_regression.ps1 and friends do not
  # read exit codes, so a print alone would vanish.
  $truncOut = ""; $truncCode = 0
  try {
    $truncOut  = & (Join-Path $PSScriptRoot 'check_truncated_run.ps1') -Report $destHtm -FromDate $FromDate -ToDate $ToDate 2>&1 | Out-String
    $truncCode = $LASTEXITCODE
  } catch { $truncOut = "truncation check failed: $_"; $truncCode = -1 }
  [PSCustomObject]@{ report_name=$ReportName; truncated=($truncCode -eq 2); detail=$truncOut.Trim() } |
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
  # Sidecar JSON (ORDER-165, added because a real caller — tpl_regression.ps1 — never checks
  # mt5_run.ps1's exit code at all; a printed warning + exit 3 alone would pass through it
  # silently). Written every time so callers have one stable path to check instead of each
  # re-implementing the report regex. requested/actual are null when the report has no usable
  # leverage line (0-trade / degenerate report) — that's "unknown", not "match" or "mismatch".
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
