<##
.SYNOPSIS
    Focused ORDER-103 regression tests for ARCHIVE_MANIFEST staged-scope gating.

.DESCRIPTION
    Uses throwaway repositories and the production check_precommit_staged.ps1.
    The four cases prove that active-only state changes do not inherit unrelated
    manifest drift, while true archive changes and explicit manifest changes
    remain fail-closed. No shared repository index or worktree is touched.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir -and $MyInvocation.MyCommand.Path) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    if (-not $scriptDir) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)
}

$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'
. $validator -RepoRoot $RepoRoot 6>$null

$scratchRoot = Join-Path $env:TEMP ('order103_manifest_scope_' + $PID)
function Remove-Scratch {
    if (-not [IO.Directory]::Exists($scratchRoot)) { return }
    foreach ($file in [IO.Directory]::EnumerateFiles($scratchRoot, '*', [IO.SearchOption]::AllDirectories)) {
        $attributes = [IO.File]::GetAttributes($file)
        if (($attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
            $writable = [int]$attributes -band (-bnot [int][IO.FileAttributes]::ReadOnly)
            [IO.File]::SetAttributes($file, [IO.FileAttributes]$writable)
        }
    }
    [IO.Directory]::Delete($scratchRoot, $true)
}
Remove-Scratch
[IO.Directory]::CreateDirectory($scratchRoot) | Out-Null
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Name, [bool]$Pass, [string]$Detail = '')
    $results.Add([pscustomobject]@{ Name = $Name; Pass = $Pass; Detail = $Detail })
}

function Git {
    param([string]$Dir, [string]$Arguments)
    $r = Invoke-GitRaw -RepoRoot $Dir -Arguments $Arguments
    if ($r.ExitCode -ne 0) { throw "git $Arguments failed in $Dir`: $($r.StdErr)" }
    return $r
}

function Write-Bytes {
    param([string]$Path, [byte[]]$Bytes)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

function Write-Utf8 {
    param([string]$Path, [string]$Text, [bool]$Bom = $false)
    $encoding = New-Object System.Text.UTF8Encoding($Bom)
    Write-Bytes -Path $Path -Bytes $encoding.GetBytes($Text)
}

function Invoke-Guard {
    param([string]$Dir)
    $guard = Join-Path $Dir 'scripts\check_precommit_staged.ps1'
    $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $guard -RepoRoot $Dir 2>&1)
    return [pscustomobject]@{
        ExitCode = $LASTEXITCODE
        Output   = ($output -join [Environment]::NewLine)
    }
}

function Write-GeneratedArtifacts {
    param([string]$Dir, [switch]$Stage)

    $archive = Get-Snapshot -RepoRoot $Dir -Mode Staged -RelPath 'ARCHIVE_TASKBOARD_2026-07A.md'
    $active  = Get-Snapshot -RepoRoot $Dir -Mode Staged -RelPath 'AGENT_TASKBOARD.md'
    $archiveBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $archive.Bytes) -SourceTag 'current-archive')
    $activeBlocks  = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $active.Bytes) -SourceTag 'current-active')
    $scan = Invoke-ExceptionScan -CurrentActiveBlocks $activeBlocks -CurrentArchiveBlocks $archiveBlocks
    $closure = Invoke-ExceptionClosure -PolicyExceptions $scan.Policy -ActiveBlocks $activeBlocks -ArchiveBlocks $archiveBlocks
    if (@($scan.Integrity).Count -gt 0 -or @($closure.IntegrityFailures).Count -gt 0 -or @($closure.Unresolved).Count -gt 0) {
        throw 'synthetic candidate unexpectedly has archive policy/integrity findings'
    }

    $artifactRoot = Join-Path $Dir 'docs\memory_control'
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    $rows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $archiveBlocks -ArchiveBlobSha $archive.Identity)
    Write-ArchiveManifestCsv -Rows $rows -Path (Join-Path $artifactRoot 'ARCHIVE_MANIFEST.csv')
    $report = [ordered]@{
        PolicyExceptions = @($scan.Policy)
        CanonicallyReviewed = @($closure.Reviewed)
        UnresolvedPolicyExceptions = @($closure.Unresolved)
        IntegrityFailures = @($scan.Integrity) + @($closure.IntegrityFailures)
    }
    Write-TextFileLfNoBom -Path (Join-Path $artifactRoot 'ARCHIVE_INDEX.md') `
        -Text (Build-ArchiveIndexMarkdown -ManifestRows $rows -ArchiveBlobSha $archive.Identity -ArchiveRawFileSha256 (Get-Sha256Hex -Bytes $archive.Bytes))
    Write-TextFileLfNoBom -Path (Join-Path $artifactRoot 'RECONCILE_EXCEPTIONS.md') `
        -Text (Build-ExceptionsMarkdown -Report $report)
    if ($Stage) { Git -Dir $Dir -Arguments 'add -- docs/memory_control/ARCHIVE_MANIFEST.csv docs/memory_control/ARCHIVE_INDEX.md docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null }
}

function New-Fixture {
    param([string]$Tag)
    $dir = Join-Path $scratchRoot $Tag
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Git -Dir $dir -Arguments 'init -q' | Out-Null
    Git -Dir $dir -Arguments 'config user.email test@example.com' | Out-Null
    Git -Dir $dir -Arguments 'config user.name "manifest scope test"' | Out-Null
    Git -Dir $dir -Arguments 'config core.autocrlf false' | Out-Null

    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'scripts\lib') | Out-Null
    Copy-Item (Join-Path $RepoRoot 'scripts\check_precommit_staged.ps1') (Join-Path $dir 'scripts\check_precommit_staged.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1') (Join-Path $dir 'scripts\check_taskboard_archive.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\lib\b1_guard.ps1') (Join-Path $dir 'scripts\lib\b1_guard.ps1') -Force

    $archive = "## Block A`nbody A`n"
    $active = "## ORDER-1 -- active -- ``OPEN```n"
    Write-Utf8 -Path (Join-Path $dir 'ARCHIVE_TASKBOARD_2026-07A.md') -Text $archive
    Write-Utf8 -Path (Join-Path $dir 'AGENT_TASKBOARD.md') -Text $active
    Git -Dir $dir -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md AGENT_TASKBOARD.md' | Out-Null
    Write-GeneratedArtifacts -Dir $dir -Stage

    # Commit a canonical-LF manifest so the fresh generator's CRLF output is
    # pre-existing byte drift, while the artifact remains semantically valid.
    $manifestPath = Join-Path $dir 'docs\memory_control\ARCHIVE_MANIFEST.csv'
    $manifestText = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8).Replace("`r`n", "`n")
    Write-Utf8 -Path $manifestPath -Text $manifestText -Bom $true
    Git -Dir $dir -Arguments 'add -- docs/memory_control/ARCHIVE_MANIFEST.csv' | Out-Null
    Git -Dir $dir -Arguments 'commit -q -m "fixture base"' | Out-Null
    $baseSha = (Get-GitObjectId -RepoRoot $dir -Spec 'HEAD').Trim()

    # The production checker carries these history refs as constants. In this
    # synthetic repo, point them at the fixture's own committed base only.
    $guardPath = Join-Path $dir 'scripts\check_precommit_staged.ps1'
    $guardText = [IO.File]::ReadAllText($guardPath, [Text.Encoding]::UTF8)
    $guardText = $guardText.Replace('0ced19485c6c6ce9a23541f785ab82bae4fcad25', $baseSha)
    $guardText = $guardText.Replace('GIT:4aebbc37^:AGENT_TASKBOARD.md', ('GIT:{0}:AGENT_TASKBOARD.md' -f $baseSha))
    $guardText = $guardText.Replace('GIT:4aebbc37:AGENT_TASKBOARD.md', ('GIT:{0}:AGENT_TASKBOARD.md' -f $baseSha))
    $guardText = $guardText.Replace('GIT:4aebbc37:ARCHIVE_TASKBOARD_2026-07A.md', ('GIT:{0}:ARCHIVE_TASKBOARD_2026-07A.md' -f $baseSha))
    Write-Utf8 -Path $guardPath -Text $guardText
    return $dir
}

try {
    # A — active-only change with pre-existing CRLF-only worktree drift.
    $a = New-Fixture -Tag 'case_a'
    $manifestA = Join-Path $a 'docs\memory_control\ARCHIVE_MANIFEST.csv'
    $manifestTextA = [IO.File]::ReadAllText($manifestA, [Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`n", "`r`n")
    Write-Utf8 -Path $manifestA -Text $manifestTextA -Bom $true
    [IO.File]::AppendAllText((Join-Path $a 'AGENT_TASKBOARD.md'), "# active-only state change`n", [Text.Encoding]::UTF8)
    Git -Dir $a -Arguments 'add -- AGENT_TASKBOARD.md' | Out-Null
    $ra = Invoke-Guard -Dir $a
    Add-Result -Name 'A-active-only-change-ignores-preexisting-manifest-eol-drift' `
        -Pass ($ra.ExitCode -eq 0) -Detail $ra.Output

    # B — archive input changed, but the manifest remains stale.
    $b = New-Fixture -Tag 'case_b'
    [IO.File]::AppendAllText((Join-Path $b 'ARCHIVE_TASKBOARD_2026-07A.md'), "`n## Block B`nbody B`n", [Text.Encoding]::UTF8)
    Git -Dir $b -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md' | Out-Null
    $rb = Invoke-Guard -Dir $b
    Add-Result -Name 'B-archive-change-with-stale-manifest-blocks' `
        -Pass (($rb.ExitCode -ne 0) -and ($rb.Output -match 'ARCHIVE_MANIFEST')) -Detail $rb.Output

    # C — archive input changed and all generated artifacts are regenerated.
    $c = New-Fixture -Tag 'case_c'
    [IO.File]::AppendAllText((Join-Path $c 'ARCHIVE_TASKBOARD_2026-07A.md'), "`n## Block B`nbody B`n", [Text.Encoding]::UTF8)
    Git -Dir $c -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md' | Out-Null
    Write-GeneratedArtifacts -Dir $c -Stage
    $rc = Invoke-Guard -Dir $c
    Add-Result -Name 'C-archive-change-with-fresh-manifest-passes' `
        -Pass ($rc.ExitCode -eq 0) -Detail $rc.Output

    # D — staged acceptance remains isolated from an unstaged ORDER-1560-like
    # worktree addition.
    $d = New-Fixture -Tag 'case_d'
    [IO.File]::AppendAllText((Join-Path $d 'AGENT_TASKBOARD.md'), "# staged state change`n", [Text.Encoding]::UTF8)
    Git -Dir $d -Arguments 'add -- AGENT_TASKBOARD.md' | Out-Null
    [IO.File]::AppendAllText((Join-Path $d 'AGENT_TASKBOARD.md'), "`n## ORDER-1560 -- unrelated worktree-only content -- ``OPEN```n", [Text.Encoding]::UTF8)
    $rd = Invoke-Guard -Dir $d
    Add-Result -Name 'D-unstaged-worktree-content-does-not-contaminate-staged-acceptance' `
        -Pass (($rd.ExitCode -eq 0) -and ((Get-Content -Raw (Join-Path $d 'AGENT_TASKBOARD.md')) -match 'ORDER-1560')) -Detail $rd.Output

    $allPass = $true
    Write-Host '=== staged manifest scope regression results ==='
    foreach ($r in $results) {
        $status = if ($r.Pass) { 'PASS' } else { $allPass = $false; 'FAIL' }
        Write-Host (('[{0}] {1}' -f $status, $r.Name))
        if (-not $r.Pass) { Write-Host $r.Detail }
    }
    if ($allPass) { Write-Host 'ALL CASES PASSED'; exit 0 }
    Write-Host 'ONE OR MORE CASES FAILED'; exit 1
}
finally {
    Remove-Scratch
}
