<#
.SYNOPSIS
    Regenerate the three docs/memory_control archive artifacts from the STAGED
    taskboards, so a taskboard-archive move can pass its own pre-commit check.

.DESCRIPTION
    check_taskboard_archive.ps1 -Generate cannot be used mid-move: it embeds the
    archive-content identity taken from HEAD:ARCHIVE_TASKBOARD_2026-07A.md, while
    check_precommit_staged.ps1 compares the artifacts against a candidate built from
    the STAGED archive. Those two identities differ by construction during a move, so
    -Generate always produces artifacts the hook then rejects.

    This writes exactly the candidate the hook builds -- same functions, same staged
    identity, same LF/no-BOM writers -- by dot-sourcing the validator and mirroring
    check_precommit_staged.ps1 lines 262-306. It is not a workaround: the staged
    identity is the semantically correct one for a snapshot that is about to become
    the commit.

    Run it AFTER `git add`-ing both taskboards and BEFORE `git commit`, then stage the
    three artifacts it writes.

.NOTES
    ASCII-only on purpose: PowerShell 5.1 decodes a BOM-less .ps1 as ANSI, which
    corrupts any non-ASCII literal (a literal em-dash becomes '?').
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is EMPTY under `powershell.exe -File <relative-path>` from a non-PowerShell
# shell, and evaluating Split-Path on it in the param default throws before the body runs.
# Same defect I shipped in make_taskboard_digest.ps1 and fixed there without sweeping for
# other copies -- so it bit again here, on the very script whose job is to keep the archive
# artifacts honest.
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent $here
}

# 6>$null matches how check_precommit_staged.ps1 dot-sources this; the validator's
# main body is guarded by `if ($MyInvocation.InvocationName -ne '.')` so this only
# imports functions.
. (Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1') -RepoRoot $RepoRoot 6>$null

$ARCHIVE_REL = 'ARCHIVE_TASKBOARD_2026-07A.md'

# The LOGICAL staged active board (manifest + declared taskboards/active parts), exactly
# what check_precommit_staged.ps1 builds its candidate from since the 2026-08-22 split.
# Reading the bare manifest saw no active orders, so every order that is both active and
# archived dropped out of the exception scan: the regenerated RECONCILE_EXCEPTIONS.md
# disagreed with the hook's candidate (and ORDER-095's Source-A binding row turned into a
# false integrity failure).
$stagedActiveBytes = Get-SourceBytes -RepoRoot $RepoRoot -SourceSpec 'ACTIVE:Staged'
$stagedArchive = Get-Snapshot -RepoRoot $RepoRoot -Mode Staged -RelPath $ARCHIVE_REL

Write-Host ("[regen] staged logical active board sha256 = {0}" -f (Get-Sha256Hex -Bytes $stagedActiveBytes))
Write-Host ("[regen] staged archive identity = {0}" -f $stagedArchive.Identity)

$activeBlocks  = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $stagedActiveBytes)  -SourceTag 'current-active')
$archiveBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $stagedArchive.Bytes) -SourceTag 'current-archive')

$scan    = Invoke-ExceptionScan    -CurrentActiveBlocks $activeBlocks -CurrentArchiveBlocks $archiveBlocks
$closure = Invoke-ExceptionClosure -PolicyExceptions $scan.Policy -ActiveBlocks $activeBlocks -ArchiveBlocks $archiveBlocks

$integrityCount  = @($scan.Integrity).Count + @($closure.IntegrityFailures).Count
$unresolvedCount = @($closure.Unresolved).Count
Write-Host ("[regen] policy={0} reviewed={1} unresolved={2} integrity={3}" -f `
    @($scan.Policy).Count, @($closure.Reviewed).Count, $unresolvedCount, $integrityCount)

# Refuse to write artifacts that would bless a broken snapshot. The hook would catch
# this anyway; failing here makes the reason legible instead of arriving as an
# artifact-mismatch three steps later.
if ($integrityCount -gt 0) { Write-Host '[regen] ABORT: staged snapshot has integrity failures' -ForegroundColor Red; exit 2 }
if ($unresolvedCount -gt 0) { Write-Host '[regen] ABORT: staged snapshot has unresolved policy exceptions' -ForegroundColor Red; exit 2 }

$report = [ordered]@{
    PolicyExceptions           = @($scan.Policy)
    CanonicallyReviewed        = @($closure.Reviewed)
    UnresolvedPolicyExceptions = @($closure.Unresolved)
    IntegrityFailures          = @($scan.Integrity) + @($closure.IntegrityFailures)
}

$mcDir        = Join-Path $RepoRoot 'docs\memory_control'
$manifestPath = Join-Path $mcDir 'ARCHIVE_MANIFEST.csv'
$indexPath    = Join-Path $mcDir 'ARCHIVE_INDEX.md'
$excPath      = Join-Path $mcDir 'RECONCILE_EXCEPTIONS.md'

$rows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $archiveBlocks -ArchiveBlobSha $stagedArchive.Identity)
Write-ArchiveManifestCsv -Rows $rows -Path $manifestPath
Write-TextFileLfNoBom -Path $indexPath -Text (Build-ArchiveIndexMarkdown -ManifestRows $rows -ArchiveBlobSha $stagedArchive.Identity -ArchiveRawFileSha256 (Get-Sha256Hex -Bytes $stagedArchive.Bytes))
Write-TextFileLfNoBom -Path $excPath   -Text (Build-ExceptionsMarkdown -Report $report)

Write-Host ("[regen] wrote {0} manifest row(s) to:" -f $rows.Count) -ForegroundColor Green
Write-Host "  docs/memory_control/ARCHIVE_MANIFEST.csv"
Write-Host "  docs/memory_control/ARCHIVE_INDEX.md"
Write-Host "  docs/memory_control/RECONCILE_EXCEPTIONS.md"
Write-Host "[regen] now: git add those three, then run scripts/check_precommit_staged.ps1"
exit 0
