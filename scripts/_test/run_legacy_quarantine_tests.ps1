<#
run_legacy_quarantine_tests.ps1 - Lane C: legacy optimization path quarantine tests.

USAGE  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\_test\run_legacy_quarantine_tests.ps1

ASCII-only (Windows PowerShell 5.1 decodes a BOM-less .ps1 as ANSI).

Cages the Lane C quarantine: the six legacy optimization-selection paths
(select_robust_pass.py, set_from_robust.py, run_pipeline.py, log_run.py optimize,
walkforward.ps1, OPTIMIZE_GUIDE.md) must REFUSE by default (exit 3 +
"REFUSED (LEGACY / NON_FACTORY)") and only run with explicit
--allow-legacy-selection / -AllowLegacySelection, emitting
"LEGACY / NON_FACTORY ... NON-AUTHORITATIVE" markers.

Negative constraint (by design): NO test here asserts any PF/DD/RF/trade
threshold as current Factory policy. Assertions are exit codes, refusal/legacy
marker strings, and legacy output shape only.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
# NOTE: the worktree copy of tools\python312 may lack python312.zip (stdlib
# archive) and fail at startup; prefer the working main-repo interpreter.
# Executing it does not modify D:\EA_LAB; worktree scripts are still the
# code under test, and their hardcoded D:\EA_LAB output writes are guarded
# by the SHA256 backup/restore below.
$python = 'D:\EA_LAB\tools\python312\python.exe'
if (-not (Test-Path -LiteralPath $python)) { $python = Join-Path $RepoRoot 'tools\python312\python.exe' }
if (-not (Test-Path -LiteralPath $python)) { Write-Output "FAIL: portable python not found"; exit 1 }
$scripts = Join-Path $RepoRoot 'scripts'
$fixture = Join-Path $scripts '_test\fixtures\legacy_quarantine\opt_fixture.xml'
if (-not (Test-Path -LiteralPath $fixture)) { Write-Output "FAIL: fixture not found at $fixture"; exit 1 }
$failures = @()
function Check { param([int]$N, [string]$Name, [bool]$Ok, [string]$Detail)
  if ($Ok) { Write-Output "  [PASS] case $N : $Name" }
  else { Write-Output "  [FAIL] case $N : $Name -- $Detail"; $script:failures += "case $N ($Name): $Detail" } }
function Run-Py { param([string[]]$PyArgs)
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $global:LASTEXITCODE = 0
  $out = & $python @PyArgs 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $prevEap
  return [pscustomobject]@{ rc = $rc; text = ($out | Out-String) } }
function Backup-GuardFile { param([string]$Path, $State)
  $bak = "$Path.lq_bak"
  if (Test-Path -LiteralPath $Path) { $State[$Path] = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash; Copy-Item -LiteralPath $Path -Destination $bak -Force }
  else { if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force }; $State[$Path] = $null } }
function Restore-GuardFiles { param($State)
  foreach ($k in $State.Keys) {
    $bak = "$k.lq_bak"
    if (Test-Path -LiteralPath $bak) {
      Move-Item -LiteralPath $bak -Destination $k -Force
      if ($State[$k] -ne $null) { $h = (Get-FileHash -LiteralPath $k -Algorithm SHA256).Hash
        if ($h -ne $State[$k]) { $script:failures += "guard file hash mismatch after restore: $k" } }
    } else { if (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Force } }
  } }
$tmp = Join-Path $env:TEMP 'lq_quarantine_tests'
if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$prevEnc = $env:PYTHONIOENCODING; $env:PYTHONIOENCODING = 'utf-8'
$guardState = @{}
try {
  foreach ($g in @('D:\EA_LAB\RUN_REGISTRY.csv','D:\EA_LAB\RUN_REGISTRY.md','D:\EA_LAB\RUN_LOG.csv')) { Backup-GuardFile $g $guardState }
  # case 1: select_robust_pass.py default refusal
  $r = Run-Py @((Join-Path $scripts 'select_robust_pass.py'), $fixture)
  Check 1 'select_robust_pass.py refuses by default (exit 3 + REFUSED banner)' `
    ($r.rc -eq 3 -and $r.text.Contains('REFUSED (LEGACY / NON_FACTORY)') -and $r.text.Contains('NOT the current Factory selection contract')) "rc=$($r.rc) text=$($r.text)"
  # case 2: select_robust_pass.py opt-in
  $r = Run-Py @((Join-Path $scripts 'select_robust_pass.py'), $fixture, '--allow-legacy-selection')
  Check 2 'select_robust_pass.py opt-in runs (exit 0 + LEGACY/NON-AUTHORITATIVE + plateau=THIN)' `
    ($r.rc -eq 0 -and $r.text.Contains('LEGACY / NON_FACTORY') -and $r.text.Contains('NON-AUTHORITATIVE') -and $r.text.Contains('plateau=THIN')) "rc=$($r.rc) text=$($r.text)"
  # case 3: import guard (temp .py, NON-empty passes)
  $guardPy = Join-Path $tmp 'import_guard.py'
  $pyCode = @"
import sys
sys.path.insert(0, r'$scripts')
import select_robust_pass as SRP
passes = [
    {"profit_factor": 1.45, "max_drawdown_percent": 12.5, "recovery_factor": 1.80, "total_trades": 180, "net_profit": 1500, "expected_payoff": 8.33, "sharpe_ratio": 1.10},
    {"profit_factor": 1.30, "max_drawdown_percent": 18.0, "recovery_factor": 1.60, "total_trades": 150, "net_profit": 2000, "expected_payoff": 13.33, "sharpe_ratio": 0.95},
    {"profit_factor": 2.50, "max_drawdown_percent": 35.0, "recovery_factor": 2.00, "total_trades": 90, "net_profit": 5000, "expected_payoff": 55.56, "sharpe_ratio": 1.40},
    {"profit_factor": 0.90, "max_drawdown_percent": 10.0, "recovery_factor": 0.80, "total_trades": 200, "net_profit": -300, "expected_payoff": -1.50, "sharpe_ratio": 0.40},
]
try:
    SRP.select_robust(passes)
    print("REFUSED_MISSING")
    sys.exit(1)
except SRP.LegacySelectionRefused:
    print("REFUSED_OK")
r = SRP.select_robust(passes, allow_legacy=True)
assert r["plateau"] == "THIN", r["plateau"]
assert r["survivors"] == 2, r["survivors"]
assert r["robust"] is not None
print("OPTIN_OK plateau=THIN survivors=2")
"@
  Set-Content -LiteralPath $guardPy -Value $pyCode -Encoding ASCII
  $r = Run-Py @($guardPy)
  Check 3 'import guard: select_robust() raises LegacySelectionRefused by default; allow_legacy=True works' `
    ($r.rc -eq 0 -and $r.text.Contains('REFUSED_OK') -and $r.text.Contains('OPTIN_OK plateau=THIN survivors=2')) "rc=$($r.rc) text=$($r.text)"
  # temp base .set for cases 4/5
  $baseSet = Join-Path $tmp 'base.set'
  Set-Content -LiteralPath $baseSet -Value @('_03_DistAtrMult=8.0||8.0||0||8.0||N','_22_TP_ATRmult=1.0||1.0||0||1.0||N') -Encoding ASCII
  $sfr = Join-Path $scripts 'set_from_robust.py'
  # case 4: set_from_robust.py default refusal, no .set written
  $outSet = Join-Path $tmp 'out_default.set'
  $r = Run-Py @($sfr, $fixture, '--base', $baseSet, '-o', $outSet)
  Check 4 'set_from_robust.py refuses by default (exit 3, no .set written)' `
    ($r.rc -eq 3 -and $r.text.Contains('REFUSED (LEGACY / NON_FACTORY)') -and (-not (Test-Path -LiteralPath $outSet))) "rc=$($r.rc) text=$($r.text)"
  # case 5: set_from_robust.py opt-in
  $outSet2 = Join-Path $tmp 'out_optin.set'
  $r = Run-Py @($sfr, $fixture, '--base', $baseSet, '-o', $outSet2, '--allow-legacy-selection')
  $fileOk = $false
  if (Test-Path -LiteralPath $outSet2) {
    $c = Get-Content -LiteralPath $outSet2 -Raw
    $fileOk = $c.Contains('LEGACY / NON_FACTORY') -and $c.Contains('_03_DistAtrMult=8||8||0||8||N') -and $c.Contains('_22_TP_ATRmult=1||1||0||1||N')
  }
  Check 5 'set_from_robust.py opt-in: exit 0, overrode 2/2, output carries LEGACY marker + rewritten lines' `
    ($r.rc -eq 0 -and $r.text.Contains('overrode 2/2') -and $fileOk) "rc=$($r.rc) text=$($r.text) fileOk=$fileOk"
  # case 6: run_pipeline.py narrow guard -- default run skips optimizer XML
  # (REFUSED note + skipped-count) but single-test HTML scoring is unaffected
  # (score_backtest.score() never touches the legacy selector, so it is not gated).
  $rp = Join-Path $scripts 'run_pipeline.py'
  $pipeRoot = Join-Path $tmp 'lq_pipe_root'
  New-Item -ItemType Directory -Force -Path $pipeRoot | Out-Null
  Copy-Item -LiteralPath $fixture -Destination (Join-Path $pipeRoot 'opt_fixture.xml')
  $r = Run-Py @($rp, $pipeRoot)
  Check 6 'run_pipeline.py default: exit 0, REFUSED note, optimizer XML skipped (not processed)' `
    ($r.rc -eq 0 -and $r.text.Contains('REFUSED (LEGACY / NON_FACTORY)') -and $r.text.Contains('optimizer=0') -and $r.text -match '1 optimizer XML file\(s\) skipped') "rc=$($r.rc) text=$($r.text)"
  # case 7: run_pipeline.py opt-in with temp root
  $r = Run-Py @($rp, $pipeRoot, '--allow-legacy-selection')
  $mdOk = $false
  $mdPath = 'D:\EA_LAB\RUN_REGISTRY.md'
  if (Test-Path -LiteralPath $mdPath) { $mdOk = (Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8).Contains('LEGACY / NON_FACTORY') }
  Check 7 'run_pipeline.py opt-in: exit 0, LEGACY banner, optimizer=1, RUN_REGISTRY.md carries LEGACY marker' `
    ($r.rc -eq 0 -and $r.text.Contains('LEGACY / NON_FACTORY') -and $r.text.Contains('NON-AUTHORITATIVE') -and $r.text.Contains('optimizer=1') -and $mdOk) "rc=$($r.rc) text=$($r.text) mdOk=$mdOk"
  # case 8: log_run.py optimize default refusal
  $lr = Join-Path $scripts 'log_run.py'
  $r = Run-Py @($lr, $fixture)
  Check 8 'log_run.py optimize logging refuses by default (exit 3 + REFUSED banner)' `
    ($r.rc -eq 3 -and $r.text.Contains('REFUSED (LEGACY / NON_FACTORY)')) "rc=$($r.rc) text=$($r.text)"
  # case 9: log_run.py optimize opt-in
  $r = Run-Py @($lr, $fixture, '--allow-legacy-selection')
  Check 9 'log_run.py optimize opt-in: exit 0 + logged [optimize]' `
    ($r.rc -eq 0 -and $r.text.Contains('logged [optimize]')) "rc=$($r.rc) text=$($r.text)"
  # cases 10/11: walkforward.ps1 via child powershell -Command (hashtable -ParamGrid cannot cross -File)
  $wf = Join-Path $scripts 'walkforward.ps1'
  $cmd10 = "& '$wf' -Expert 'DummyEA' -Symbol 'EURUSD' -ParamGrid @(@{Name='_03_DistAtrMult';Values=@(8.0,9.0,10.0)}) -OutPrefix 'lq_dummy'"
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $global:LASTEXITCODE = 0
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd10 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $prevEap
  $text = ($out | Out-String)
  # NOTE: rc is checked as non-zero, not literally 3 -- confirmed via a minimal
  # vanilla repro that PowerShell 5.1 does not relay a nested script's `exit 3`
  # as the literal $LASTEXITCODE when invoked as `& 'script.ps1' ...` inside a
  # -Command string (it surfaces as 1); this is a pre-existing host quirk, not
  # a guard defect. -File can't be used here because -ParamGrid needs a real
  # hashtable array, which can't cross the -File string-args boundary.
  Check 10 'walkforward.ps1 refuses by default (non-zero exit + REFUSED banner)' `
    ($rc -ne 0 -and $text.Contains('REFUSED (LEGACY / NON_FACTORY)')) "rc=$rc text=$text"
  $cmd11 = "& '$wf' -Expert 'DummyEA' -Symbol 'EURUSD' -ParamGrid @(@{Name='_03_DistAtrMult';Values=@(8.0,9.0,10.0)}) -OutPrefix 'lq_dummy' -EaSourcePath '$tmp\DummyEA.mq5' -SetDir '$tmp\wf_set' -OutCsv '$tmp\wf_out.csv' -SummaryJson '$tmp\wf_summary.json' -DryRun -AllowLegacySelection"
  $prevEap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $global:LASTEXITCODE = 0
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command $cmd11 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $prevEap
  $text = ($out | Out-String)
  Check 11 'walkforward.ps1 -DryRun -AllowLegacySelection: exit 0 + LEGACY banner + DRY RUN marker' `
    ($rc -eq 0 -and $text.Contains('LEGACY / NON_FACTORY') -and ($text -match 'DRY.?RUN')) "rc=$rc text=$text"
  # case 12: guide banner
  $guide = Join-Path $RepoRoot 'ea_template\OPTIMIZE_GUIDE.md'
  $guideOk = $false
  if (Test-Path -LiteralPath $guide) { $guideOk = (Get-Content -LiteralPath $guide -Raw -Encoding UTF8).Contains('LEGACY / NON-FACTORY / NON-AUTHORITATIVE') }
  Check 12 'OPTIMIZE_GUIDE.md carries LEGACY / NON-FACTORY / NON-AUTHORITATIVE banner' $guideOk 'banner missing or file absent'
} finally {
  Restore-GuardFiles $guardState
  if (Test-Path -LiteralPath $tmp) { Remove-Item -Recurse -Force $tmp }
  $env:PYTHONIOENCODING = $prevEnc
}
Write-Output ''
if ($failures.Count -gt 0) {
  Write-Output "FAIL: $($failures.Count) case(s) failed:"
  foreach ($f in $failures) { Write-Output "  - $f" }
  exit 1
}
Write-Output 'PASS: all 12 legacy-quarantine cases green'
exit 0
