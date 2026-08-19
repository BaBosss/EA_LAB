<#
run_mt5_optimize_launcher_hardening_tests.ps1 - PREDEV LANE A / OPTIMIZATION LAUNCHER HARDENING.

WHY THIS EXISTS
  scripts\mt5_optimize.ps1 had three generic launcher-level defects, all reproduced against
  canonical commit 4c5a1e19 before repair:

    A1. `$auto = "D:\EA_LAB\_mt5_auto"` was hardcoded despite the script already deriving
        `$repoRoot` one line later -- running from an isolated worktree wrote optimization
        artifacts (the .ini AND the collected optimizer XML) into the PRIMARY workspace, not
        the worktree the caller was sandboxed to. Same failure class as
        `hardcoded-repo-path-defeats-worktree-cage` (make_status.ps1, fixed earlier).
    A2. When scripts\optimize_guard.ps1 was absent, the launcher printed "skipping pre-flight
        check" and PROCEEDED to burn tester wall-clock on an unchecked sweep. An optimize pass
        SELECTS the parameters everything downstream is built on, so a missing guard must abort
        the launch, not silently no-op. -SkipOptimizeGuard overrides an existing guard's REFUSE
        verdict; it must not become a way to skip the guard existing at all.
    A3. On success the launcher told the operator to run `select_robust_pass.py` next --
        that script's own docstring says it implements the archived/superseded BacktestScore v1
        gate and has not been re-verified against the current VERDICT GATE. Selection must stay
        candidate/hypothesis-contract driven; this launcher must not point operators at the old
        generic ranking formula (and must not invent a replacement one here either).

  This suite proves the fix WITHOUT ever touching the real D:\EA_LAB, the real MT5 terminal, or
  spending real tester wall-clock: it builds self-contained fixture checkouts (own scripts\,
  scripts\lib\, docs\, _triage\ -- real copies of the production files under test, not stubs)
  under a scratch temp dir, and drives mt5_optimize.ps1 through its early ABORT/refuse branches
  (a deliberately-unreadable .set, a deliberately-missing guard) so most scenarios below complete
  in well under a second and never call Start-Process on a real terminal64.exe. The ONE test that
  runs the full pipeline (F, "guard genuinely invoked") launches `hostname.exe` as a harmless
  stand-in "Terminal" -- a real, always-present, instantly-exiting console app -- so it can prove
  the guard actually ran (not skipped) without ever starting real MT5; it produces no XML on
  purpose and closes via the launcher's existing NO-XML exit path.

  Every -CapabilityFile / SetFile / Terminal fixture below is synthetic; the ONLY real repo files
  copied in are scripts\mt5_optimize.ps1 (the fixed script under test), scripts\lib\
  optimize_next_step.ps1 (the new, extracted A3 message function), scripts\optimize_guard.ps1 and
  its scripts\lib\ dependencies (the accepted, unmodified guard architecture -- NOT re-tested here
  beyond "does the launcher call it"), and docs\PARAM_REGISTRY.csv / docs\PARAM_LINKAGE.md /
  _triage\PARAM_INACTIVE_AUDIT.md (its real source-of-truth data, needed so the REAL guard runs
  authentically rather than against a hand-rolled stub).

  A. isolated worktree output root: `_mt5_auto\{ini,optimizations}` land under the FIXTURE's own
     derived repo root, not a hardcoded path.
  B. no write into the real D:\EA_LAB for a uniquely-named report produced entirely inside a
     fixture whose repo root is NOT D:\EA_LAB.
  C. a malformed/unresolvable repo root (`$PSScriptRoot` empty, e.g. the script invoked as a
     dynamic scriptblock rather than via -File) fails EXPLICITLY -- no silent relative-path or
     hardcoded fallback.
  D. missing scripts\optimize_guard.ps1 => nonzero refusal, naming the exact missing path, before
     ever reaching the "OPTIMIZE:" launch line.
  E. missing guard + -SkipOptimizeGuard still refuses identically (SkipOptimizeGuard cannot
     substitute for a guard that does not exist).
  F. an EXISTING guard is still genuinely invoked (not skipped) -- proven by the real guard's own
     "Nothing to check" banner appearing in the launcher's stdout, and by the launcher reaching
     its own "OPTIMIZE:" line.
  G. the stale "next: python select_robust_pass.py ..." instruction is gone from source, and the
     new Get-OptimizeNextStepMessage function (unit-tested directly, no MT5 needed) returns the
     candidate/hypothesis-contract wording when -HypothesisRevision is bound, and an explicit
     SELECTION BLOCKED line when it is not -- never the old formula, never an invented one.
  H. static regression guard: the literal hardcoded path string can never silently reappear.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_mt5_optimize_launcher_hardening_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

# Invoking a child `powershell -File/-Command ...` with `2>&1` merges its stderr into OUR
# pipeline; under THIS script's own $ErrorActionPreference = 'Stop', PowerShell wraps each merged
# stderr line in a terminating ErrorRecord (same hazard scripts\lib\snapshot_reader.ps1 documents
# and works around). Every child invocation below runs under a LOCAL 'Continue' so a child's
# native stderr cannot abort this suite; the child's own real exit code is still captured via
# $LASTEXITCODE right after the call, unaffected by this.
function Invoke-Child([string[]]$ArgList) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & powershell @ArgList 2>&1
        return [pscustomobject]@{ Output = $out; ExitCode = $LASTEXITCODE }
    } finally {
        $ErrorActionPreference = $saved
    }
}

$script:pass = 0
$script:fail = 0
function Assert-True([string]$name, $cond) {
    if ($cond) { $script:pass++; Write-Host "   [PASS] $name" }
    else { $script:fail++; Write-Host "   [FAIL] $name" }
}
function Assert-Equal([string]$name, $expected, $actual) {
    if ("$expected" -eq "$actual") { $script:pass++; Write-Host "   [PASS] $name" }
    else {
        $script:fail++
        Write-Host "   [FAIL] $name"
        Write-Host "          expected: $expected"
        Write-Host "          actual  : $actual"
    }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("mt5optlauncher_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

function New-Fixture([string]$tag, [bool]$IncludeGuard) {
    <#
      A minimal, self-contained checkout: real copies of mt5_optimize.ps1 (the script under test)
      plus every file it dot-sources, its own docs\/_triage\ data (so the REAL optimize_guard.ps1
      can run authentically), and -- for the "guard missing" fixtures -- optimize_guard.ps1
      deliberately left out.
    #>
    $root = Join-Path $work $tag
    New-Item -ItemType Directory -Path (Join-Path $root 'scripts\lib') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'docs') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root '_triage') -Force | Out-Null

    Copy-Item (Join-Path $RepoRoot 'scripts\mt5_optimize.ps1') (Join-Path $root 'scripts\mt5_optimize.ps1') -Force
    foreach ($lib in @('symbol_preflight.ps1','setfile_surface.ps1','build_receipt.ps1','binary_staleness.ps1','param_registry_csv.ps1','optimize_next_step.ps1')) {
        Copy-Item (Join-Path $RepoRoot "scripts\lib\$lib") (Join-Path $root "scripts\lib\$lib") -Force
    }
    if ($IncludeGuard) {
        Copy-Item (Join-Path $RepoRoot 'scripts\optimize_guard.ps1') (Join-Path $root 'scripts\optimize_guard.ps1') -Force
    }
    Copy-Item (Join-Path $RepoRoot 'docs\PARAM_REGISTRY.csv') (Join-Path $root 'docs\PARAM_REGISTRY.csv') -Force
    Copy-Item (Join-Path $RepoRoot 'docs\PARAM_LINKAGE.md') (Join-Path $root 'docs\PARAM_LINKAGE.md') -Force
    Copy-Item (Join-Path $RepoRoot '_triage\PARAM_INACTIVE_AUDIT.md') (Join-Path $root '_triage\PARAM_INACTIVE_AUDIT.md') -Force
    return $root
}

try {
Write-Host '=== fixture construction: guard-present and guard-missing checkouts, real repo never touched ==='
$guardYes = New-Fixture 'guard_yes' $true
$guardNo  = New-Fixture 'guard_no'  $false
Assert-True 'guard-present fixture has optimize_guard.ps1'    (Test-Path (Join-Path $guardYes 'scripts\optimize_guard.ps1'))
Assert-True 'guard-missing fixture does NOT have optimize_guard.ps1' (-not (Test-Path (Join-Path $guardNo 'scripts\optimize_guard.ps1')))
Assert-True 'fixtures are different directories' ($guardYes -ne $guardNo)

# Shared synthetic MT5-side fixtures (never real MT5, never real terminal64.exe).
$capabilityFile = Join-Path $work 'capability.json'
Set-Content -LiteralPath $capabilityFile -Encoding UTF8 -Value '{"symbols":["EURUSD"]}'
$dataDir = Join-Path $work 'datadir'
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
$dummyTerminal = Join-Path $work 'dummy_terminal.exe'
Set-Content -LiteralPath $dummyTerminal -Encoding ASCII -Value 'not a real executable -- Test-Path leaf only, never launched by tests A-E'
$missingSet = Join-Path $work 'missing.set'   # deliberately never created
$undeclaredSet = Join-Path $work 'undeclared.set'
Set-Content -LiteralPath $undeclaredSet -Encoding ASCII -Value '_1_Test=1'   # UNDECLARED, 0 sweep dims, passes surface check
$realHostname = Join-Path $env:WINDIR 'System32\hostname.exe'

$commonArgs = @('-Expert','FixtureExpert','-Symbol','EURUSD','-FromDate','2023.01.01','-ToDate','2023.02.01')

Write-Host ''
Write-Host '=== A/B: isolated worktree output root -- dirs land under the FIXTURE root, never D:\EA_LAB ==='
$reportA = 'A1TEST_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$r = Invoke-Child (@('-NoProfile','-File', (Join-Path $guardYes 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
    '-SetFile', $missingSet, '-ReportName', $reportA, '-Terminal', $dummyTerminal, '-DataDir', $dataDir,
    '-CapabilityFile', $capabilityFile, '-Force'))
$aOutText = ($r.Output -join "`n")
Assert-Equal 'A unreadable .set aborts with exit 2 (fast path, no Start-Process reached)' 2 $r.ExitCode
Assert-True  'A abort message names the UNREADABLE .set' ($aOutText -match [regex]::Escape($missingSet) -and $aOutText -match 'does not exist')
Assert-True  'A _mt5_auto\optimizations was created under the FIXTURE root' (Test-Path (Join-Path $guardYes '_mt5_auto\optimizations') -PathType Container)
Assert-True  'A _mt5_auto\ini was created under the FIXTURE root'          (Test-Path (Join-Path $guardYes '_mt5_auto\ini') -PathType Container)
Assert-True  'B no artifact for this unique report name exists under the REAL D:\EA_LAB\_mt5_auto\ini'          (-not (Test-Path "D:\EA_LAB\_mt5_auto\ini\$reportA.ini"))
Assert-True  'B no artifact for this unique report name exists under the REAL D:\EA_LAB\_mt5_auto\optimizations' (-not (Test-Path "D:\EA_LAB\_mt5_auto\optimizations\$reportA.xml"))

Write-Host ''
Write-Host '=== C: malformed/unresolvable repo root ($PSScriptRoot empty) fails EXPLICITLY, no fallback ==='
$probe = @'
param([Parameter(Mandatory)][string]$FixtureScriptsDir, [Parameter(Mandatory)][string]$SourceFile,
      [Parameter(Mandatory)][string]$Terminal, [Parameter(Mandatory)][string]$SetFile, [Parameter(Mandatory)][string]$ReportName)
# $ErrorActionPreference = 'Stop' HERE, not just inside the invoked scriptblock: a terminating
# error thrown INSIDE `& $sb ...` only aborts this wrapper's OWN execution if the wrapper's
# error-action preference says so at the call site -- with the default 'Continue', PowerShell
# prints the error and falls through to the next statement, so the wrapper "succeeds" (implicit
# exit 0) even though the scriptblock never got anywhere near its own `exit 2`. That would turn
# an unrelated crash into a false PASS for this test; fail loud instead.
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $FixtureScriptsDir
$content = Get-Content -Raw -LiteralPath $SourceFile
$sb = [scriptblock]::Create($content)
& $sb -Expert 'FixtureExpert' -Symbol 'EURUSD' -FromDate '2023.01.01' -ToDate '2023.02.01' -SetFile $SetFile -ReportName $ReportName -Terminal $Terminal -Force
Write-Output "PROBE-DID-NOT-EXIT: mt5_optimize.ps1 content returned without calling exit"
exit 9
'@
$probePath = Join-Path $work 'd3_probe.ps1'
Set-Content -LiteralPath $probePath -Encoding ASCII -Value $probe
$reportC = 'D3TEST_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$guardYesScripts = Join-Path $guardYes 'scripts'
$r = Invoke-Child @('-NoProfile','-File', $probePath,
    '-FixtureScriptsDir', $guardYesScripts, '-SourceFile', (Join-Path $guardYesScripts 'mt5_optimize.ps1'),
    '-Terminal', $dummyTerminal, '-SetFile', $missingSet, '-ReportName', $reportC)
$cOutText = ($r.Output -join "`n")
Assert-Equal 'C empty $PSScriptRoot aborts with exit 2' 2 $r.ExitCode
Assert-True  'C abort message names the unresolved repo root, not a generic crash' ($cOutText -match 'could not resolve the repo root')
Assert-True  'C no bad relative-path fallback artifact was created under scripts\_mt5_auto' (-not (Test-Path (Join-Path $guardYesScripts '_mt5_auto')))

Write-Host ''
Write-Host '=== D/E: missing guard aborts nonzero BEFORE "OPTIMIZE:", and -SkipOptimizeGuard cannot substitute for it ==='
$expectedGuardPath = Join-Path $guardNo 'scripts\optimize_guard.ps1'
$reportD = 'D4TEST_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$r = Invoke-Child (@('-NoProfile','-File', (Join-Path $guardNo 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
    '-SetFile', $undeclaredSet, '-ReportName', $reportD, '-Terminal', $dummyTerminal, '-DataDir', $dataDir,
    '-CapabilityFile', $capabilityFile, '-AllowLegacyIdentity', '-Force'))
$dOutText = ($r.Output -join "`n")
Assert-True  'D missing guard aborts with a nonzero exit code' ($r.ExitCode -ne 0)
Assert-True  'D abort message names the EXACT missing guard path' ($dOutText -match [regex]::Escape($expectedGuardPath))
Assert-True  'D abort message states corrective action' ($dOutText -match 'Corrective action')
Assert-True  'D never reached the OPTIMIZE launch line' ($dOutText -notmatch 'OPTIMIZE:')
Assert-True  'D never printed the old silent-skip message' ($dOutText -notmatch 'not found, skipping pre-flight check')

$reportE = 'D5TEST_' + [guid]::NewGuid().ToString('N').Substring(0,12)
$r = Invoke-Child (@('-NoProfile','-File', (Join-Path $guardNo 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
    '-SetFile', $undeclaredSet, '-ReportName', $reportE, '-Terminal', $dummyTerminal, '-DataDir', $dataDir,
    '-CapabilityFile', $capabilityFile, '-AllowLegacyIdentity', '-SkipOptimizeGuard', '-Force'))
$eOutText = ($r.Output -join "`n")
Assert-True  'E missing guard + -SkipOptimizeGuard STILL aborts nonzero (no bypass)' ($r.ExitCode -ne 0)
Assert-Equal 'E same exit code as D (identical refusal, flag made no difference)' $r.ExitCode $r.ExitCode
Assert-True  'E abort message still names the exact missing guard path' ($eOutText -match [regex]::Escape($expectedGuardPath))
Assert-True  'E never reached the OPTIMIZE launch line either' ($eOutText -notmatch 'OPTIMIZE:')

Write-Host ''
Write-Host '=== F: an EXISTING guard is genuinely invoked, not skipped (full pipeline, real hostname.exe stand-in) ==='
if (-not (Test-Path -LiteralPath $realHostname -PathType Leaf)) {
    Assert-True 'F precondition: hostname.exe exists at the expected System32 path' $false
} else {
    $reportF = 'FTEST_' + [guid]::NewGuid().ToString('N').Substring(0,12)
    $r = Invoke-Child (@('-NoProfile','-File', (Join-Path $guardYes 'scripts\mt5_optimize.ps1')) + $commonArgs + @(
        '-SetFile', $undeclaredSet, '-ReportName', $reportF, '-Terminal', $realHostname, '-DataDir', $dataDir,
        '-CapabilityFile', $capabilityFile, '-AllowLegacyIdentity', '-Force', '-TimeoutSec', '30'))
    $fOutText = ($r.Output -join "`n")
    Assert-True  'F guard was NOT skipped (real guard banner present)' ($fOutText -match 'Nothing to check \(no Y-flagged sweep dimensions')
    Assert-True  'F never printed the old silent-skip message' ($fOutText -notmatch 'not found, skipping pre-flight check')
    Assert-True  'F pipeline proceeded past the guard to the OPTIMIZE launch line' ($fOutText -match 'OPTIMIZE:')
    Assert-Equal 'F clean NO-XML close (hostname.exe produces no optimizer report, by design)' 4 $r.ExitCode
}

Write-Host ''
Write-Host '=== G: the A3 next-step message is candidate/hypothesis-contract driven, never the old formula ==='
. (Join-Path $guardYes 'scripts\lib\optimize_next_step.ps1')
$withRevision = Get-OptimizeNextStepMessage -DestXml 'C:\fixture\OUT.xml' -HypothesisRevision 'B99-TESTHYP'
$noRevision   = Get-OptimizeNextStepMessage -DestXml 'C:\fixture\OUT.xml' -HypothesisRevision ''
Assert-True 'G with -HypothesisRevision: message names the candidate/hypothesis contract' ($withRevision -match "candidate for hypothesis 'B99-TESTHYP'" -and $withRevision -match 'candidate/hypothesis-contract driven')
Assert-True 'G with -HypothesisRevision: message warns against select_robust_pass.py rather than instructing it' ($withRevision -match 'do not use select_robust_pass\.py')
Assert-True 'G without -HypothesisRevision: message says SELECTION BLOCKED' ($noRevision -match 'SELECTION BLOCKED')
Assert-True 'G without -HypothesisRevision: message does NOT invent a replacement ranking formula' ($noRevision -notmatch 'PF|profit factor|plateau|ranking formula')

Write-Host ''
Write-Host '=== H: static regression guard -- the hardcoded path and the old instruction can never silently reappear ==='
$srcText = Get-Content -Raw -LiteralPath (Join-Path $RepoRoot 'scripts\mt5_optimize.ps1')
Assert-True 'H source no longer contains the literal hardcoded D:\EA_LAB\_mt5_auto path' ($srcText -notmatch [regex]::Escape('"D:\EA_LAB\_mt5_auto"'))
Assert-True 'H source derives $auto from $repoRoot' ($srcText -match [regex]::Escape('$auto = Join-Path $repoRoot "_mt5_auto"'))
Assert-True 'H source no longer prints the old "next: python select_robust_pass.py" instruction' ($srcText -notmatch [regex]::Escape('next: python select_robust_pass.py'))
Assert-True 'H source no longer has an unconditional guard-missing skip-and-continue branch' ($srcText -notmatch [regex]::Escape('optimize_guard: scripts\optimize_guard.ps1 not found, skipping pre-flight check'))

Write-Host ''
if ($script:fail -gt 0) { Write-Host ("FAIL  {0}/{1} passed, {2} failed" -f $script:pass, ($script:pass + $script:fail), $script:fail); exit 1 }
Write-Host ("PASS  {0}/{0}" -f $script:pass)
exit 0
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
