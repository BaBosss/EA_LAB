<#
parity_run.ps1 - ORDER-1021 (slice S8). The 7-point Parent-Variant parity harness, design 5.5.

WHAT IT DOES. For one hypothesis revision and one case, it runs TWO tester passes on ONE lane over
ONE window with ONE model - the generated thin wrapper, and the PARENT Boss configured with the
wrapper's EFFECTIVE CONFIG - then hands both sets of artifacts to _triage\factory_os\parity.py,
which judges the seven points. Parity runs BEFORE any evidence from a wrapper counts; evidence
from an unparified wrapper is void.

WHY IT SHARES tpl_regression's LANE PIN. design 5.5: parity re-runs whenever core\ changes, which
is tpl_regression's trigger, "so the two cages share a lane pin and should share a runner". The
pin is written out EXPLICITLY here and not inherited from mt5_run.ps1's defaults - Decision log
2026-07-30 records a cage that compiled one install and measured another, and ORDER-371 records
that numbers do not transfer across installs.

THE BINARY IT MEASURED IS THE BINARY IT BUILT. Both .ex5 files are asserted present and NEWER than
every ea_template source file before either run starts. A parity pass over a stale wrapper would
compare the current parent against last week's variant and call the difference a defect.

WHY THE TWO SIDES GET DIFFERENT INPUT PAGES FROM ONE .set. The wrapper exposes only the inputs
its revision leaves live and the parent exposes the build's full surface - that is the POINT of
the capability-token rollout. (The counts are gen_wrapper.const_plan()'s to state, not this
header's: the wrapper's count moved 38->29 within hours of first being written into prose.) What
has to match is the EFFECTIVE CONFIGURATION, so both sides are handed the same full-surface .set:
the parent honours all of it, the wrapper silently ignores the keys its binary no longer has, and
point 2 demands they arrive at the same effective_config_hash - now TRIANGULAR against the
compiler's expected hash too, so a .set that silently failed to apply on BOTH sides cannot pass.

REQUIRES: MT5 GUI closed (mt5_run.ps1's guard), and ea_template\deploy.ps1 -Compile plus a compile
of the generated wrappers. Like tpl_regression.ps1 this is a MANUAL evidence tool: it costs two
tester runs per case and is not in the pre-commit tier.

USAGE  powershell -NoProfile -File scripts\parity_run.ps1 -Case must-trade
ASCII only (PS 5.1 reads a BOM-less .ps1 as ANSI).
#>
[CmdletBinding()]
param(
  [string]$Revision = 'B14-H01-r1',
  [string]$Parent   = 'EALabTpl\Boss_14_GridLog',
  [ValidateSet('must-trade', 'deliberate-refusal', 'locked-absent', 'cage-fires')]
  [string]$Case     = 'must-trade',
  [string]$Symbol   = 'XAUUSD',
  [string]$Period   = 'H1',
  [string]$FromDate = '2024.01.01',
  [string]$ToDate   = '2024.07.01',
  # Model 1 by default because parity asks whether the two BINARIES agree, and both sides run the
  # same model whatever it is. Model 4 is what a grid VERDICT needs (CLAUDE.md cage discipline) and
  # is available with -Model 4; the harness records which one it used, so nobody has to guess.
  [int]$Model       = 1,
  [string]$Terminal = 'D:\Meta 5\terminal64.exe',
  [string]$DataDir  = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$AgentRoot = 'C:\Users\patip\AppData\Roaming\MetaQuotes\Tester\9CA16B8382AE4CF692710FB36B9DA355',
  [string]$WorkDir  = ''
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$py = Join-Path $root 'tools\python312\python.exe'
if (-not $WorkDir) { $WorkDir = Join-Path $env:TEMP ('parity_' + [Guid]::NewGuid().ToString('N').Substring(0,8)) }
New-Item -ItemType Directory -Force $WorkDir | Out-Null

# The shared report-freshness gate. `run_report_freshness_tests` PART 5 refused this script's
# first commit for not using it, and it was right: mt5_run.ps1's own header says "the .htm exists
# is NOT evidence that THIS invocation produced it". A parity run that parsed a leftover report
# would compare one side's fresh numbers against the other side's from an hour ago and attribute
# the difference to the wrapper -- which is the one conclusion this harness exists to license.
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')

function Fail([string]$msg) { Write-Host ("[FAIL] " + $msg) -ForegroundColor Red; exit 1 }

$slug = $Revision -replace '-', '_'
$Wrapper = 'EALabTpl\generated\' + $slug

# --- the case table -------------------------------------------------------------------------------
# Each case is (kind, overrides on top of the revision's effective config). The KIND is what
# parity.py checks the observation's DIRECTION against, and it is declared here rather than
# inferred from the result - a direction inferred from the outcome is not a pre-registration.
#
# 🔴 THE DESIGN'S OWN REFUSAL EXAMPLE IS NOT EXPRESSIBLE ON THIS REVISION, and that is worth
# recording rather than working around silently. design 5.5 names "_42_RiskPct mis-paired with an
# SLMode that yields no distance, which MM-SAFETY-001 fails at OnInit". Under B14-H01 BOTH
# ingredients are compiled away: FirstLotMode is const FIRSTLOT_FIXED and SLMode is const SL_NONE,
# so a .set naming either is ignored by the wrapper and the two sides would refuse for DIFFERENT
# reasons - which is a parity failure manufactured by the case, not found by it. The refusal case
# therefore uses _41_FixedLot=0, which is (a) the same MM_ConfigValid fail-closed seam, (b) an
# input LIVE on the wrapper's own page (SIZING/OPERATOR - it survives every lock this revision
# has), so both sides reach it identically.
$cases = @{
  'must-trade'         = @{ kind = 'must-trade';         overrides = @() }
  'deliberate-refusal' = @{ kind = 'deliberate-refusal'; overrides = @('_41_FixedLot=0.0') }
  # design 5.5 case 3: a locked parameter is absent from the wrapper's Inputs page AND its value
  # is provably applied. _2_MaxHoldBars is const 0 in the wrapper; handing BOTH sides a .set that
  # asks for 5 makes the parent force-close every basket after 5 bars and leaves the wrapper
  # untouched. The two sides MUST therefore DIFFER, which is the only case here that is a pass
  # when parity does not hold - see the -Case handling at the end.
  'locked-absent'      = @{ kind = 'neutral';            overrides = @('_2_MaxHoldBars=5') }
  # 🔴 THE CASE THAT EXISTS BECAUSE THE MUST-TRADE CASE LEFT TWO POINTS UNTESTED. On the pinned
  # config the account-DD gate is armed at 12% and the window's drawdown never reaches it, so
  # RiskControl_AcctGateOK never changes state, never prints, and points 6 (terminal side effects)
  # and 7 (alerts) had NOTHING to compare on either side. The repo's own rule is that a guard with
  # zero fires is UNTESTED and must not be written up as passed -- so rather than accept that, this
  # case arms the gate at 0.3% so it TRIPS and RELEASES inside the window and both sides have real
  # [RISK] lines and real persisted HWM keys to disagree about.
  'cage-fires'         = @{ kind = 'must-trade';         overrides = @('RC_AcctDDLimitPct=0.3') }
}
# NOTE: named $caseDef, not $case. PowerShell variable names are CASE-INSENSITIVE, so `$case`
# IS the `$Case` parameter -- assigning the hashtable to it overwrote a [ValidateSet] parameter
# with a Hashtable and the script refused itself on its first run.
$caseDef = $cases[$Case]

# --- 1. the effective config, and the .set that carries it ----------------------------------------
$pins = & $py -c @"
import sys, os, io
sys.path.insert(0, r'$root\_triage\factory_os')
import gen_registry_rows as grr, hypothesis_b14 as HB, preset
read = lambda rel: io.open(os.path.join(r'$root', rel.replace('/', os.sep)), encoding='utf-8-sig').read()
surface = preset.parse_surface(read(preset.INPUTS_REL), HB.BUILD_TAG)
hyp = HB.HYPOTHESES['$Revision'.rsplit('-r', 1)[0]]
for k, v in sorted(hyp['config'].items()):
    sys.stdout.write('%s=%s\n' % (k, v))
"@
if ($LASTEXITCODE -ne 0) { Fail ("could not read the pinned config for " + $Revision + ": " + ($pins -join ' ')) }

$setFile = Join-Path $WorkDir 'effective.set'
$genArgs = @((Join-Path $root '_triage\factory_os\gen_default_preset.py'), '--build', 'LAB_ENTRY_14', '--out', $setFile)
# MERGED into one key->value map before any of it reaches the compiler, case winning over the
# revision's pin. Appending both lists made `RC_AcctDDLimitPct` appear TWICE in the `hypothesis`
# layer and `compile_preset` refused it by name -- correctly, because rank exists BETWEEN layers
# and not inside one, and silently taking the last row is the last-wins defect `build_tag` was
# split out to stop. The refusal caught a real ambiguity in this runner; it was not in the way.
$eff = [ordered]@{}
foreach ($p in $pins)           { if ($p.Trim()) { $kv = $p.Trim() -split '=', 2; $eff[$kv[0]] = $kv[1] } }
foreach ($o in $caseDef.overrides) { $kv = $o -split '=', 2; $eff[$kv[0]] = $kv[1] }
foreach ($k in $eff.Keys)       { $genArgs += @('--override', ($k + '=' + $eff[$k])) }
$presetOut = & $py $genArgs
if ($LASTEXITCODE -ne 0) { Fail ("gen_default_preset.py refused: " + ($presetOut -join ' ')) }
$expected = ($presetOut | Where-Object { $_ -like 'expected_hash=*' }) -replace 'expected_hash=', ''
Write-Host (">> effective config: " + $Revision + " + case '" + $Case + "' -> " + $setFile) -ForegroundColor Cyan
Write-Host (">> compiler expects effective_config_hash=" + $expected) -ForegroundColor DarkGray

# --- 2. both binaries exist, and are NEWER than every source they were built from ------------------
$srcNewest = (Get-ChildItem (Join-Path $root 'ea_template') -Recurse -Include *.mq5, *.mqh |
              Sort-Object LastWriteTime -Descending | Select-Object -First 1)
foreach ($pair in @(@($Wrapper, 'wrapper'), @($Parent, 'parent'))) {
  $ex5 = Join-Path $DataDir ('MQL5\Experts\' + $pair[0] + '.ex5')
  if (-not (Test-Path $ex5)) {
    Fail ("no compiled " + $pair[1] + " at " + $ex5 + " - run ea_template\deploy.ps1 -Compile and compile the generated wrappers first. A parity run against an absent binary measures nothing.")
  }
  if ((Get-Item $ex5).LastWriteTime -lt $srcNewest.LastWriteTime) {
    Fail ("the " + $pair[1] + " binary (" + (Get-Item $ex5).LastWriteTime.ToString('HH:mm:ss') + ") is OLDER than " + $srcNewest.Name + " (" + $srcNewest.LastWriteTime.ToString('HH:mm:ss') + "). ORDER-371: the binary this would measure is not the binary this source builds.")
  }
}

# --- 3. the two runs ------------------------------------------------------------------------------
# The agent log is APPEND-ONLY and shared by every run of the day, so a line count is snapshotted
# before each pass and only the lines it APPENDED are handed to the comparator. Slicing by wall
# clock instead would pull in a neighbouring run's lines whenever two starts share a second.
function Get-LogSizes {
  $h = @{}
  Get-ChildItem -Path $AgentRoot -Recurse -Filter '*.log' -ErrorAction SilentlyContinue |
    ForEach-Object { $h[$_.FullName] = (Get-Content -LiteralPath $_.FullName -Encoding Unicode).Count }
  return $h
}

function Invoke-Side([string]$label, [string]$expert) {
  $runStart = Get-Date
  $before = Get-LogSizes
  $report = 'PARITY_' + $slug + '_' + ($Case -replace '-', '') + '_' + $label
  Write-Host (">> " + $label + ": " + $expert) -ForegroundColor Cyan
  & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $expert -Symbol $Symbol -Period $Period `
      -FromDate $FromDate -ToDate $ToDate -SetFile $setFile -Model $Model `
      -ReportName $report -Terminal $Terminal -DataDir $DataDir | Out-Null
  $rc = $LASTEXITCODE
  # THE TESTER'S EXIT CODE IS CHECKED FIRST. An ABORT (mt5_run refuses while the MT5 GUI holds the
  # same install, exit 2) produces no new log lines, and a comparator handed two empty slices would
  # report "both sides observed nothing" -- which reads as a parity finding and is a tooling
  # failure. "I could not run it" and "it disagreed" must never share an exit path.
  if ($rc -ne 0) { Fail ("side " + $label + ": mt5_run.ps1 exited " + $rc + " -- the tester did not produce this run. NOTHING about parity is known from it.") }

  $after = Get-LogSizes
  $slice = @()
  foreach ($f in $after.Keys) {
    $n0 = 0; if ($before.ContainsKey($f)) { $n0 = $before[$f] }
    if ($after[$f] -gt $n0) {
      $lines = Get-Content -LiteralPath $f -Encoding Unicode
      $slice += $lines[$n0..($after[$f] - 1)]
    }
  }
  if ($slice.Count -eq 0) {
    Fail ("side " + $label + ": the run finished but appended NO lines to any agent log under " + $AgentRoot + ". The comparator would see an empty slice and call every log-derived point UNTESTED; say so here instead.")
  }
  $logOut = Join-Path $WorkDir ($label + '.log.txt')
  Set-Content -LiteralPath $logOut -Value $slice -Encoding UTF8
  $htm = Join-Path $root ('_mt5_auto\reports\' + $report + '.htm')
  if (-not (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $rc -Label $report)) {
    Fail ("side " + $label + ": the report at " + $htm + " is not evidence from THIS run (absent, or written before it started). Parity would otherwise compare one side's fresh numbers against the other side's leftovers.")
  }
  $ex5 = Join-Path $DataDir ('MQL5\Experts\' + $expert + '.ex5')

  $man = [ordered]@{
    label = $label; case = $Case; kind = $caseDef.kind; expert = $expert
    binary = $ex5; binary_mtime = (Get-Item $ex5).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    report = $htm; log = $logOut; lane = $Terminal
    symbol = $Symbol; period = $Period; from = $FromDate; to = $ToDate; model = $Model
    set = $setFile; expected_hash = $expected
  }
  $manPath = Join-Path $WorkDir ($label + '.json')
  ($man | ConvertTo-Json) | Set-Content -LiteralPath $manPath -Encoding UTF8
  Write-Host ("   log slice " + $slice.Count + " line(s) -> " + $logOut) -ForegroundColor DarkGray
  return $manPath
}

$manA = Invoke-Side 'wrapper' $Wrapper
$manB = Invoke-Side 'parent'  $Parent

Write-Host ""
& $py (Join-Path $root '_triage\factory_os\parity.py') $manA $manB
$verdict = $LASTEXITCODE

# `locked-absent` is the one case that PASSES by differing: it exists to prove a const-ed input is
# genuinely absent from the wrapper (the .set asks for _2_MaxHoldBars=5 and only the parent obeys).
# Its expectation is inverted HERE rather than inside parity.py, because parity.py answers one
# question -- do these two runs agree -- and a module that also knew which answer was wanted for
# which case would be able to talk itself into either.
if ($Case -eq 'locked-absent') {
  if ($verdict -eq 0) {
    Fail "case 'locked-absent' asked both sides for _2_MaxHoldBars=5 and they AGREED. The parent should have honoured it and the wrapper should not - identical behaviour means the input was never really compiled away, or the .set never reached the parent."
  }
  Write-Host ">> case 'locked-absent' PASSES BY DIFFERING: the parent honoured _2_MaxHoldBars=5 and the wrapper could not, which is a const that is APPLIED and not merely declared." -ForegroundColor Green
  Write-Host (">> artifacts: " + $WorkDir)
  exit 0
}
Write-Host (">> artifacts: " + $WorkDir)
exit $verdict
