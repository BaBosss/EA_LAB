<#
tpl_regression.ps1 - Boss V2 chassis smoke-regression (added 2026-07-03).

Purpose: Boss V2 has no unit-test suite. This is the substitute: run the 3 Boss
entry EAs with COMPILED DEFAULTS on a pinned window/model, extract PF / trades /
net profit, and compare against ea_template\regression_baseline.csv. Any core\
edit that changes these numbers (with all new modes OFF by default) = behavior
drift = investigate before merging. A default-value change also trips this on
purpose - defaults ARE behavior.

Usage:
  powershell -File scripts\tpl_regression.ps1                                       # compare vs baseline
  powershell -File scripts\tpl_regression.ps1 -UpdateBaseline                       # DRY RUN: prints old-vs-new diff, does NOT write, exits 1
  powershell -File scripts\tpl_regression.ps1 -UpdateBaseline -ConfirmBaseline      # accepts the diff and writes the baseline
Requires: MT5 GUI closed (mt5_run.ps1 guard). ~6 sequential tester runs.
#>
[CmdletBinding()]
param(
  [switch]$UpdateBaseline,
  [switch]$ConfirmBaseline,
  [string]$Symbol = "XAUUSD",
  [string]$Period = "H1",
  [string]$FromDate = "2024.01.01",
  [string]$ToDate = "2024.07.01",
  [int]$Model = 1
)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$baseline = Join-Path $root "ea_template\regression_baseline.csv"
# ORDER-129 cage fix (Codex system review 2026-07-18): the cage used to run whatever .ex5
# was already installed — an agent could edit core\, run this, and get CLEAN from a stale
# binary. Now every run first mirrors + compiles CURRENT source (deploy.ps1 deletes old
# .ex5 before compiling and fails on any compile error), so the numbers always describe
# the source tree being judged.
. (Join-Path $PSScriptRoot 'lib\report_freshness.ps1')
Write-Host ">> deploy + compile current source (deploy.ps1 -Compile)" -ForegroundColor Cyan
& (Join-Path $root "ea_template\deploy.ps1") -Compile
if ($LASTEXITCODE -ne 0) { Write-Host "[FAIL] deploy/compile failed - regression aborted (never test stale binaries)" -ForegroundColor Red; exit 1 }
# ORDER-129: dynamic discovery so a new Boss wrapper can never be silently absent from the
# cage (Boss_17/18 were missing from the old static list).
$experts = @(Get-ChildItem (Join-Path $root "ea_template\Boss_*.mq5") | Sort-Object Name |
             ForEach-Object { "EALabTpl\" + $_.BaseName })
# Boss_14 compiled defaults barely trade on the pinned window (4 trades) - too thin to catch
# drift, so it runs a PINNED set instead (frozen copy of XAU_DEMO; never edit during optimize work).
# Boss_16 (ORDER-094): compiled defaults are also thin on this 6-month window - pinned to the
# existing frozen ORDER-072 smoke set (Boss16_Kangaroo_XAU_smoke.set) instead.
$setOverride = @{
  "EALabTpl\Boss_14_GridLog"      = (Join-Path $root "ea_template\sets\regression\Boss_14_GridLog_regression_full.set")
  "EALabTpl\Boss_16_KangarooGrid" = (Join-Path $root "ea_template\sets\regression\Boss_16_KangarooGrid_regression_full.set")
}
# ORDER-165 (2026-07-23): EVERY expert now runs with a FULL pinned .set. Root cause of the
# 8/8 false-drift: [TesterInputs] only overrides listed inputs - every UNLISTED input comes
# from the per-terminal tester cache (MQL5\Profiles\Tester\<Expert>.set = last-used values,
# rewritten by any GUI/batch session touching that EA). The old cage ran 6 of 8 EAs with NO
# set at all (and 14/16 with PARTIAL sets), so its numbers silently tracked whatever the
# cache held - reproducible only while nobody else touched the terminal. Full default
# surfaces were captured 2026-07-23 (cache wiped -> compiled defaults -> report harvest);
# 14/16 overlay their frozen smoke params on that surface. Leverage is pinned to 1:100 by
# mt5_run (ini "1:N" form + post-run assertion, exit 3 on mismatch).
$defaultSetDir = Join-Path $root "ea_template\sets\regression"

function Parse-Report([string]$htm) {
  # MT5 writes UTF-16LE with BOM; Get-Content -Raw decodes it via the BOM.
  $t = Get-Content $htm -Raw
  $t = $t -replace '<[^>]+>', '|'
  $parts = ($t -split '\|') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $out = @{}
  $keys = @{ 'Total Net Profit:'='net'; 'Profit Factor:'='pf'; 'Total Trades:'='trades'; 'Equity Drawdown Maximal:'='eqdd' }
  for ($i = 0; $i -lt $parts.Count - 1; $i++) {
    if ($keys.ContainsKey($parts[$i])) { $out[$keys[$parts[$i]]] = ($parts[$i+1] -replace '\s','') }
  }
  return $out
}

$rows = @()
foreach ($e in $experts) {
  $name = ($e -split '\\')[-1]
  $rep = "TPLREG_$name"
  Write-Host ">> running $name ($Symbol $Period $FromDate-$ToDate Model $Model)" -ForegroundColor Cyan
  # ORDER-165: full pinned set for every expert - never run the cage on cached inputs.
  $setFile = if ($setOverride.ContainsKey($e)) { $setOverride[$e] } else { Join-Path $defaultSetDir "${name}_defaults.set" }
  if (-not (Test-Path $setFile)) { Write-Host "[FAIL] $name - pinned set missing: $setFile (capture defaults per ORDER-165 before running the cage)" -ForegroundColor Red; exit 1 }
  $runStart = Get-Date
  $res = & (Join-Path $PSScriptRoot 'mt5_run.ps1') -Expert $e -Symbol $Symbol -Period $Period `
          -FromDate $FromDate -ToDate $ToDate -Model $Model -ReportName $rep -SetFile $setFile
  $runnerExit = $LASTEXITCODE
  if ($runnerExit -eq 3) { Write-Host "[FAIL] $name - LEVERAGE MISMATCH (see mt5_run output above) - cage numbers would not be comparable" -ForegroundColor Red; exit 1 }
  $htm = Join-Path $root "_mt5_auto\reports\$rep.htm"
  # ORDER-372: this used to check only exit 3 and then Test-Path, so an ABORT (exit 2) with a
  # leftover report would have compared the template against a PREVIOUS run's numbers - the exact
  # failure mode this regression cage exists to catch, hidden inside the cage itself.
  if (-not (Test-ReportIsFresh -Htm $htm -RunStart $runStart -RunnerExit $runnerExit -Label $name)) {
    Write-Host "[FAIL] $name - no fresh report produced ($res)" -ForegroundColor Red; exit 1
  }
  $m = Parse-Report $htm
  $rows += [pscustomobject]@{ ea=$name; net=$m['net']; pf=$m['pf']; trades=$m['trades']; eqdd=$m['eqdd'] }
  Write-Host ("   net={0} pf={1} trades={2} eqdd={3}" -f $m['net'], $m['pf'], $m['trades'], $m['eqdd'])
}

if ($UpdateBaseline) {
  # D4 fix (ORDER-094): -UpdateBaseline used to silently overwrite the baseline with whatever
  # this run produced - no diff shown, no confirmation required. That let a real behavior
  # regression get baked in as the new "truth" by accident. Now: always print an old-vs-new
  # diff table; only WRITE the file when -ConfirmBaseline is also passed.
  $oldBase = if (Test-Path $baseline) { Import-Csv $baseline } else { @() }
  Write-Host ""
  Write-Host "=== BASELINE DIFF (old -> new) ===" -ForegroundColor Cyan
  $diffRows = @()
  foreach ($r in $rows) {
    $b = $oldBase | Where-Object ea -eq $r.ea
    $diffRows += [pscustomobject]@{
      ea         = $r.ea
      old_net    = if ($b) { $b.net } else { '(none)' }
      new_net    = $r.net
      old_pf     = if ($b) { $b.pf } else { '(none)' }
      new_pf     = $r.pf
      old_trades = if ($b) { $b.trades } else { '(none)' }
      new_trades = $r.trades
      old_eqdd   = if ($b) { $b.eqdd } else { '(none)' }
      new_eqdd   = $r.eqdd
    }
  }
  $diffRows | Format-Table -AutoSize
  if (-not $ConfirmBaseline) {
    Write-Host "=== BASELINE NOT WRITTEN - re-run with -UpdateBaseline -ConfirmBaseline to accept the diff above ===" -ForegroundColor Red
    exit 1
  }
  $rows | Export-Csv $baseline -NoTypeInformation -Encoding UTF8
  Write-Host "baseline written -> $baseline" -ForegroundColor Green
  exit 0
}

if (-not (Test-Path $baseline)) { Write-Host "no baseline - run with -UpdateBaseline -ConfirmBaseline first"; exit 1 }
$base = Import-Csv $baseline
$fail = 0
# ORDER-129b (Codex audit): two-way set comparison. A deleted/renamed wrapper used to
# vanish from the run silently while its baseline row went unchecked -> false CLEAN.
if ($rows.Count -eq 0) { Write-Host "[FAIL] zero experts discovered - refusing to declare CLEAN on an empty run" -ForegroundColor Red; exit 1 }
foreach ($b in $base) {
  if (-not ($rows | Where-Object ea -eq $b.ea)) {
    Write-Host "[MISSING] $($b.ea) is in the baseline but was not tested (source deleted/renamed?)" -ForegroundColor Red
    $fail++
  }
}
foreach ($r in $rows) {
  $b = $base | Where-Object ea -eq $r.ea
  if (-not $b) { Write-Host "[WARN] $($r.ea) not in baseline" -ForegroundColor Yellow; $fail++; continue }
  if (($b.net -ne $r.net) -or ($b.pf -ne $r.pf) -or ($b.trades -ne $r.trades) -or ($b.eqdd -ne $r.eqdd)) {
    Write-Host ("[DRIFT] {0}: baseline net={1} pf={2} n={3} eqdd={4}  now net={5} pf={6} n={7} eqdd={8}" -f `
      $r.ea, $b.net, $b.pf, $b.trades, $b.eqdd, $r.net, $r.pf, $r.trades, $r.eqdd) -ForegroundColor Red
    $fail++
  } else {
    Write-Host "[OK] $($r.ea) matches baseline" -ForegroundColor Green
  }
}
if ($fail -gt 0) { Write-Host "=== REGRESSION: $fail drift(s) ===" -ForegroundColor Red; exit 1 }
Write-Host "=== REGRESSION CLEAN ===" -ForegroundColor Green
exit 0
