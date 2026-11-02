# publish_status.ps1 - refresh the canonical status-publisher worktree and publish the owner dashboard.
# ASCII-only source on purpose (PowerShell 5.1).
#
# A10 pilot P1 option (a), 2026-11-02. The publisher is a clean worktree that tracks origin/master,
# named in scripts\status_publisher_root.txt. This script:
#   1. creates it (detached at origin/master) only when -Create is passed;
#   2. refuses if it is not a worktree of THIS repository, or has edits other than the files
#      make_status itself regenerates;
#   3. moves it to the freshly fetched origin/master by FAST-FORWARD ONLY (refuses otherwise);
#   4. runs make_status.ps1 from inside it, which publishes to OneDrive because that root is the
#      recorded publisher root.
# It never touches the primary checkout D:\EA_LAB, never commits and never pushes.
param(
    [switch]$Create,
    [string]$PublisherRoot = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\repo_paths.ps1')
$here = Resolve-EaLabRepoRoot -AnchorPath $PSCommandPath
if (-not $PublisherRoot) { $PublisherRoot = Get-EaLabStatusPublisherRoot -RepoRoot $here }
if (-not $PublisherRoot) { Write-Output 'ABORT: no recorded publisher root (scripts\status_publisher_root.txt).'; exit 2 }

# Files make_status.ps1 regenerates in the publisher checkout; anything else dirty is refused.
$generated = @('STATUS.html', 'EA_LAB_MAP.html')

function Invoke-Git([string[]]$GitArgs) {
    $out = & git @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed: $out" }
    return $out
}

$hereCommon = [System.IO.Path]::GetFullPath((Invoke-Git @('-C', $here, 'rev-parse', '--path-format=absolute', '--git-common-dir')))
if (-not (Test-Path -LiteralPath $PublisherRoot)) {
    if (-not $Create) { Write-Output "ABORT: publisher worktree $PublisherRoot does not exist. Re-run with -Create."; exit 2 }
    Invoke-Git @('-C', $here, 'fetch', '-q', 'origin') | Out-Null
    Invoke-Git @('-C', $here, 'worktree', 'add', '--detach', $PublisherRoot, 'origin/master') | Out-Null
    Write-Output "created publisher worktree $PublisherRoot at origin/master"
}

$pubTop = [System.IO.Path]::GetFullPath((Invoke-Git @('-C', $PublisherRoot, 'rev-parse', '--show-toplevel'))).TrimEnd('\')
if ($pubTop -ne [System.IO.Path]::GetFullPath($PublisherRoot).TrimEnd('\')) { Write-Output "ABORT: $PublisherRoot is not a worktree top level ($pubTop)."; exit 2 }
$pubCommon = [System.IO.Path]::GetFullPath((Invoke-Git @('-C', $PublisherRoot, 'rev-parse', '--path-format=absolute', '--git-common-dir')))
if ($pubCommon -ne $hereCommon) { Write-Output "ABORT: $PublisherRoot belongs to a different repository ($pubCommon)."; exit 2 }

Invoke-Git (@('-C', $PublisherRoot, 'restore', '--') + $generated) | Out-Null
$dirty = @(Invoke-Git @('-C', $PublisherRoot, 'status', '--porcelain', '--untracked-files=no') | Where-Object { $_ })
if ($dirty.Count) { Write-Output "ABORT: publisher worktree has edits: $($dirty -join '; ')"; exit 2 }

Invoke-Git @('-C', $PublisherRoot, 'fetch', '-q', 'origin') | Out-Null
$current = (Invoke-Git @('-C', $PublisherRoot, 'rev-parse', 'HEAD')).Trim()
$target  = (Invoke-Git @('-C', $PublisherRoot, 'rev-parse', 'origin/master')).Trim()
& git -C $PublisherRoot merge-base --is-ancestor $current $target
if ($LASTEXITCODE -ne 0) { Write-Output "ABORT: origin/master $target is not a fast-forward of publisher HEAD $current."; exit 3 }
if ($current -ne $target) { Invoke-Git @('-C', $PublisherRoot, 'checkout', '-q', '--detach', $target) | Out-Null }
Write-Output "publisher at $target (was $current)"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PublisherRoot 'scripts\make_status.ps1')
exit $LASTEXITCODE
