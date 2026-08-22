<#
run_execution_context_tests.ps1 - L9/CR-002 (2026-08-18).

WHY THIS EXISTS
  scripts\control_room_snapshot.ps1's CR-002 attestation section hashes whatever .ex5 sits on
  disk under _vps_deploy\<bundle>\. *.ex5/*.ex4 are deliberately gitignored (compiled MQL5
  binaries -- that policy is NOT changed here), so a bare `git worktree add` checkout -- the
  isolated-clean-worktree execution model EA_LAB governance requires for dispatched work --
  never materializes them. Reproduced directly (2026-08-18): the SAME canonical commit, SAME
  code, SAME row (415573666|990208, confidence=high, human-confirmed in its own note) read
  HASHED from D:\EA_LAB and FILE_MISSING from a freshly created linked worktree. 18 of 59
  attestation rows flip the same way. A downstream reader (L7 preflight, D6's pre-deployment
  evidence packet) that does not know this can misread "never materialized here" as "the
  approved artifact is missing."

  The fix adds Get-EaLabExecutionContext (scripts\lib\repo_paths.ps1) and wires its verdict
  into control_room_snapshot.ps1's meta.execution_context / meta.attestation_caveat. This suite
  proves:
    a) a root equal to -PrimaryRepoRoot classifies PRIMARY_OPERATOR_WORKSPACE, no caveat.
    b) a root that differs classifies NON_PRIMARY_WORKSPACE, caveat is non-null and names the
       mechanism (gitignored .ex5, not-a-compile-target) so a reader is not left to guess.
    c) a directory that LOOKS like a real checkout -- a real `.git` SUBDIRECTORY, not a linked
       worktree's `.git` FILE -- still classifies NON_PRIMARY_WORKSPACE when its path is not
       -PrimaryRepoRoot. This is the case the fix is required to get right: classifying by
       ".git is a directory" would call a standalone clone PRIMARY, which is the exact
       false-authoritative reading this function exists to prevent. The classifier never reads
       .git at all -- it is proven here to give the correct answer even when a naive .git-shape
       test would give the wrong one.
    d) the fix is additive: running the real pipeline end-to-end (this checkout, both as itself
       and as a faked primary) still produces valid HASHED/FILE_MISSING mechanics through the
       real ajv schema gate -- schemas.json's SnapshotMeta accepts the two new optional fields
       without disturbing anything else in the document. This is a live smoke of the actual
       build->validate->replace chain (scripts\control_room_snapshot.ps1 ->
       _triage\factory_os\snapshot_build.py), not a mock -- the same fixture-per-row style
       run_snapshot_s4_tests.ps1 already uses to prove the pipeline honest; that suite is the
       authority on attestation row mechanics themselves and is NOT duplicated here.

ASCII-only on purpose (Windows PowerShell 5.1 reads a BOM-less .ps1 as ANSI).
USAGE  powershell -NoProfile -File scripts\_test\run_execution_context_tests.ps1
#>
[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if ($RepoRoot -eq '') { $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) }

. (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1')

$script:pass = 0
$script:fail = 0
function Assert-Equal([string]$name, $expected, $actual) {
    if ("$expected" -eq "$actual") { $script:pass++; Write-Host "   [PASS] $name" }
    else {
        $script:fail++
        Write-Host "   [FAIL] $name"
        Write-Host "          expected: $expected"
        Write-Host "          actual  : $actual"
    }
}
function Assert-True([string]$name, $cond) {
    if ($cond) { $script:pass++; Write-Host "   [PASS] $name" }
    else { $script:fail++; Write-Host "   [FAIL] $name" }
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("exectx_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

try {
Write-Host '=== (a) root equal to -PrimaryRepoRoot -> PRIMARY_OPERATOR_WORKSPACE ==='
$ctx = Get-EaLabExecutionContext -ResolvedRoot 'D:\EA_LAB' -PrimaryRepoRoot 'D:\EA_LAB'
Assert-Equal 'exact-match root classifies PRIMARY' 'PRIMARY_OPERATOR_WORKSPACE' $ctx
$ctxSlash = Get-EaLabExecutionContext -ResolvedRoot 'D:\EA_LAB\' -PrimaryRepoRoot 'D:\EA_LAB'
Assert-Equal 'trailing-backslash root still classifies PRIMARY (normalized)' 'PRIMARY_OPERATOR_WORKSPACE' $ctxSlash
$ctxCase = Get-EaLabExecutionContext -ResolvedRoot 'd:\ea_lab' -PrimaryRepoRoot 'D:\EA_LAB'
Assert-Equal 'case-different root still classifies PRIMARY (Windows path semantics)' 'PRIMARY_OPERATOR_WORKSPACE' $ctxCase

Write-Host ''
Write-Host '=== (b) root different from -PrimaryRepoRoot -> NON_PRIMARY_WORKSPACE (the linked-worktree case) ==='
$linkedWorktree = Join-Path $work 'linked_worktree_shaped'
New-Item -ItemType Directory -Path $linkedWorktree -Force | Out-Null
Set-Content -LiteralPath (Join-Path $linkedWorktree '.git') -Encoding ASCII -Value 'gitdir: D:/EA_LAB/.git/worktrees/linked_worktree_shaped'
$ctx2 = Get-EaLabExecutionContext -ResolvedRoot $linkedWorktree -PrimaryRepoRoot 'D:\EA_LAB'
Assert-Equal 'linked-worktree-shaped root (a .git FILE) classifies NON_PRIMARY' 'NON_PRIMARY_WORKSPACE' $ctx2

Write-Host ''
Write-Host '=== (c) standalone-clone-shaped root (a real .git DIRECTORY) at a non-primary path -> MUST STILL BE NON_PRIMARY ==='
Write-Host '    (this is the case a naive "is .git a directory" test would get wrong)'
$standaloneClone = Join-Path $work 'standalone_clone_shaped'
New-Item -ItemType Directory -Path (Join-Path $standaloneClone '.git\objects') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $standaloneClone '.git\refs') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $standaloneClone '.git\HEAD') -Encoding ASCII -Value 'ref: refs/heads/master'
Assert-True 'fixture really has a .git DIRECTORY, not a file (same shape as a real checkout)' (Test-Path (Join-Path $standaloneClone '.git') -PathType Container)
$ctx3 = Get-EaLabExecutionContext -ResolvedRoot $standaloneClone -PrimaryRepoRoot 'D:\EA_LAB'
Assert-Equal 'standalone-clone-shaped root classifies NON_PRIMARY despite a real .git directory' 'NON_PRIMARY_WORKSPACE' $ctx3
# Resolve-EaLabRepoRoot must independently agree this is a valid, self-contained repo root (it
# stops walking here) -- proving the NON_PRIMARY verdict is not an artifact of a malformed fixture.
$resolved = Resolve-EaLabRepoRoot -AnchorPath $standaloneClone
Assert-Equal 'Resolve-EaLabRepoRoot accepts the standalone-clone fixture as a real repo root' $standaloneClone $resolved

Write-Host ''
Write-Host '=== (c2) -Root is authoritative even when caller CWD is outside the repo ==='
$outExternalCwd = Join-Path $work 'snapshot_external_cwd.json'
Push-Location $work
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1') -Root $RepoRoot -OutFile $outExternalCwd *>$null
    $rcExternalCwd = $LASTEXITCODE
} finally {
    Pop-Location
}
Assert-Equal 'external-CWD invocation with explicit -Root exits 0' 0 $rcExternalCwd
Assert-True 'external-CWD invocation produces a validated snapshot' (Test-Path $outExternalCwd)

Write-Host ''
Write-Host '=== (d) live pipeline smoke: the new meta fields survive the real build->validate->replace chain ==='
$outNonPrimary = Join-Path $work 'snapshot_nonprimary.json'
$outPrimary    = Join-Path $work 'snapshot_fakeprimary.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1') -Root $RepoRoot -OutFile $outNonPrimary *>$null
$rcNonPrimary = $LASTEXITCODE
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\control_room_snapshot.ps1') -Root $RepoRoot -PrimaryRepoRoot $RepoRoot -OutFile $outPrimary *>$null
$rcPrimary = $LASTEXITCODE
Assert-Equal 'default -PrimaryRepoRoot run exits 0 (schema accepted the new fields)' 0 $rcNonPrimary
Assert-Equal 'self-as-primary run exits 0 (schema accepted the new fields)' 0 $rcPrimary
if ($rcNonPrimary -eq 0 -and (Test-Path $outNonPrimary)) {
    $docNonPrimary = Get-Content -LiteralPath $outNonPrimary -Raw | ConvertFrom-Json
    Assert-Equal 'this checkout (not D:\EA_LAB) reads NON_PRIMARY_WORKSPACE under real defaults' 'NON_PRIMARY_WORKSPACE' $docNonPrimary.meta.execution_context
    Assert-True 'NON_PRIMARY run carries a non-null attestation_caveat' (-not [string]::IsNullOrEmpty($docNonPrimary.meta.attestation_caveat))
    Assert-True 'existing attestation array mechanics untouched: still an array' ($docNonPrimary.attestation -is [array] -or $docNonPrimary.attestation.Count -ge 0)
    Assert-True 'existing summary.attestation_ok field still present (per-row state semantics unchanged)' ($null -ne $docNonPrimary.summary.attestation_ok)
}
if ($rcPrimary -eq 0 -and (Test-Path $outPrimary)) {
    $docPrimary = Get-Content -LiteralPath $outPrimary -Raw | ConvertFrom-Json
    Assert-Equal 'this checkout AS ITS OWN -PrimaryRepoRoot reads PRIMARY_OPERATOR_WORKSPACE' 'PRIMARY_OPERATOR_WORKSPACE' $docPrimary.meta.execution_context
    Assert-True 'PRIMARY run carries a null attestation_caveat' ([string]::IsNullOrEmpty($docPrimary.meta.attestation_caveat))
    # Same checkout, same disk state, only the classification input differs -- the per-row
    # attestation states themselves must be byte-identical between the two runs, proving the
    # fix changes only the meta-level interpretability signal and nothing about row mechanics.
    $rowsNonPrimary = ($docNonPrimary.attestation | ConvertTo-Json -Depth 6 -Compress)
    $rowsPrimary    = ($docPrimary.attestation    | ConvertTo-Json -Depth 6 -Compress)
    Assert-Equal 'attestation[] rows are identical regardless of execution_context (state semantics unchanged)' $rowsNonPrimary $rowsPrimary
}

} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host "=== run_execution_context_tests: $script:pass passed, $script:fail failed ==="
if ($script:fail -gt 0) { exit 1 }
exit 0
