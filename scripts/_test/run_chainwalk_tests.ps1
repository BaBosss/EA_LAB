<#
.SYNOPSIS
    ORDER-270 -- fast, targeted cage for Invoke-ArchiveChainIntegrityCheck.

.DESCRIPTION
    The ORDER-103 negative suite already covers this walk, but it costs 30-45
    minutes because other cases in it shell the whole validator out against a
    clone of the real repo. A cage nobody runs is not a cage. This file is the
    narrow version: it dot-sources the validator and calls the walk IN-PROCESS
    against throwaway git repos under $env:TEMP. It must finish in seconds.

    It exists specifically so the walk can be made faster WITHOUT reopening
    BLOCKER 6 ("checkpoint laundering through a merge"), which ORDER-103
    REWORK3 already paid to close. Case `merge-changing-archive-fails` is that
    blocker; case `path-filter-would-hide-the-laundering-merge` is a
    characterization test documenting WHY the obvious optimization
    (path-filtering the rev-list) is not safe here.

    Run: powershell -NoProfile -File scripts\_test\run_chainwalk_tests.ps1
    Exit code: 0 if every case matched its expected outcome, 1 otherwise.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [int]$PerfChainLength = 120,
    [double]$PerfBudgetSeconds = 3.0
)

$ErrorActionPreference = 'Stop'
$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'
. $validator -RepoRoot $RepoRoot 6>$null   # dot-source for functions only (no Invoke-Main/exit)

$ARCHIVE = 'ARCHIVE_TASKBOARD_TEST.md'

function Remove-TempScratchDirectory {
    param([string]$Path)
    $tempRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $resolved = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    if (-not $resolved.StartsWith($tempRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to remove scratch path outside TEMP: '$resolved'"
    }
    if ([System.IO.Path]::GetFileName($resolved) -notlike 'chainwalk_tests_*') {
        throw "refusing to remove unexpected TEMP directory: '$resolved'"
    }
    if (Test-Path -LiteralPath $resolved) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

$scratchRoot = Join-Path $env:TEMP ('chainwalk_tests_' + $PID)
Remove-TempScratchDirectory -Path $scratchRoot
New-Item -ItemType Directory -Force -Path $scratchRoot | Out-Null
$suiteExitCode = 1

try {

$results = New-Object System.Collections.Generic.List[object]
function Add-Result {
    param([string]$Name, [bool]$Pass, [string]$Detail = '')
    $results.Add([pscustomobject]@{ Name = $Name; Pass = $Pass; Detail = $Detail })
}

function New-TempGitRepo {
    param([string]$Tag)
    $dir = Join-Path $scratchRoot $Tag
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'init -q -b main' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config user.email test@example.com' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config user.name "chainwalk test"' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config core.autocrlf false' | Out-Null
    return $dir
}

function Write-CommitFile {
    param([string]$Dir, [string]$RelPath, [string]$Content, [string]$Message)
    $full = Join-Path $Dir $RelPath
    [System.IO.File]::WriteAllBytes($full, [System.Text.Encoding]::UTF8.GetBytes($Content))
    Invoke-GitRaw -RepoRoot $Dir -Arguments ('add -- "{0}"' -f $RelPath) | Out-Null
    $r = Invoke-GitRaw -RepoRoot $Dir -Arguments ('commit -q -m "{0}"' -f $Message)
    if ($r.ExitCode -ne 0) { throw "commit failed: $($r.StdErr)" }
    return (Get-GitObjectId -RepoRoot $Dir -Spec 'HEAD')
}

function New-Block {
    param([string]$Id, [string]$Body = 'body')
    return ("## ORDER-{0} -- synthetic block`n{1}`n`n" -f $Id, $Body)
}

function Invoke-Walk {
    param([string]$Dir, [string]$Checkpoint)
    return Invoke-ArchiveChainIntegrityCheck -RepoRoot $Dir -CheckpointSha $Checkpoint -ArchiveRelPath $ARCHIVE -HeadRef 'HEAD'
}

# ---------------------------------------------------------------- baseline ----
# c0 = checkpoint holding one block; then a clean append of a second block.
$dir = New-TempGitRepo -Tag 'clean'
$a1 = New-Block -Id '001'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
$a2 = $a1 + (New-Block -Id '002')
Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a2 -Message 'append 002' | Out-Null
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
Add-Result -Name 'clean-append-passes' -Pass ($r.IsClean -eq $true) -Detail $r.Reason

# Commits that never touch the archive must not disturb the walk. This is the
# case the optimization is FOR -- it must keep passing after the rewrite.
$dir = New-TempGitRepo -Tag 'filler'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
foreach ($i in 1..8) {
    Write-CommitFile -Dir $dir -RelPath ("unrelated_{0}.txt" -f $i) -Content "noise $i" -Message "unrelated $i" | Out-Null
}
Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a2 -Message 'append 002' | Out-Null
foreach ($i in 9..12) {
    Write-CommitFile -Dir $dir -RelPath ("unrelated_{0}.txt" -f $i) -Content "noise $i" -Message "unrelated $i" | Out-Null
}
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
$changedSteps = @($r.Steps | Where-Object { $_.Changed })
Add-Result -Name 'unrelated-commits-do-not-disturb-walk' -Pass (($r.IsClean -eq $true) -and ($changedSteps.Count -eq 1)) -Detail ("clean={0} changedSteps={1} (expected 1) reason={2}" -f $r.IsClean, $changedSteps.Count, $r.Reason)

# ------------------------------------------------------------- tamper set ----
$dir = New-TempGitRepo -Tag 'mutate'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
$mutated = (New-Block -Id '001' -Body 'body TAMPERED') + (New-Block -Id '002')
Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $mutated -Message 'append with earlier mutation' | Out-Null
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
Add-Result -Name 'mutate-earlier-block-fails' -Pass ($r.IsClean -eq $false) -Detail $r.Reason

$dir = New-TempGitRepo -Tag 'shrink'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a2 -Message 'checkpoint'
Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'truncate' | Out-Null
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
Add-Result -Name 'shrink-fails' -Pass ($r.IsClean -eq $false) -Detail $r.Reason

$dir = New-TempGitRepo -Tag 'noh2'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content ($a1 + "extra prose glued onto the previous block`n") -Message 'append without H2' | Out-Null
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
Add-Result -Name 'suffix-without-new-H2-fails' -Pass ($r.IsClean -eq $false) -Detail $r.Reason

$dir = New-TempGitRepo -Tag 'deleted'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
Invoke-GitRaw -RepoRoot $dir -Arguments ('rm -q -- "{0}"' -f $ARCHIVE) | Out-Null
Invoke-GitRaw -RepoRoot $dir -Arguments 'commit -q -m "delete archive"' | Out-Null
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
Add-Result -Name 'archive-deleted-midchain-fails' -Pass ($r.IsClean -eq $false) -Detail $r.Reason

# ------------------------------------------------------- BLOCKER 6 (merge) ----
# A merge is allowed to sit in the first-parent line, but it MUST NOT change the
# archive relative to its first parent -- otherwise content enters the archive
# through a second parent that the first-parent walk never validated.

function New-MergeFixture {
    <# main:  ckpt -> mainCommit           (archive = $MainArchive)
       side:  ckpt -> sideCommit           (archive = $SideArchive)
       then merge side into main, resolving the archive to $MergeArchive. #>
    param([string]$Tag, [string]$MainArchive, [string]$SideArchive, [string]$MergeArchive)
    $d = New-TempGitRepo -Tag $Tag
    $cp = Write-CommitFile -Dir $d -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
    Invoke-GitRaw -RepoRoot $d -Arguments 'checkout -q -b side' | Out-Null
    Write-CommitFile -Dir $d -RelPath $ARCHIVE -Content $SideArchive -Message 'side edit' | Out-Null
    Invoke-GitRaw -RepoRoot $d -Arguments 'checkout -q main' | Out-Null
    Write-CommitFile -Dir $d -RelPath $ARCHIVE -Content $MainArchive -Message 'main edit' | Out-Null
    # Merge with no auto-commit so the archive can be resolved deliberately.
    Invoke-GitRaw -RepoRoot $d -Arguments 'merge --no-commit --no-ff side' | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $d $ARCHIVE), [System.Text.Encoding]::UTF8.GetBytes($MergeArchive))
    Invoke-GitRaw -RepoRoot $d -Arguments ('add -- "{0}"' -f $ARCHIVE) | Out-Null
    $rc = Invoke-GitRaw -RepoRoot $d -Arguments 'commit -q --no-edit -m "merge side"'
    if ($rc.ExitCode -ne 0) { throw "merge commit failed: $($rc.StdErr)" }
    return [pscustomobject]@{ Dir = $d; Checkpoint = $cp }
}

$a2side = $a1 + (New-Block -Id '900' -Body 'laundered through the second parent')
$a3 = $a2 + (New-Block -Id '003')

# Merge that leaves the archive exactly as its first parent left it -> legal.
$fx = New-MergeFixture -Tag 'merge_clean' -MainArchive $a2 -SideArchive $a2side -MergeArchive $a2
$r = Invoke-Walk -Dir $fx.Dir -Checkpoint $fx.Checkpoint
Add-Result -Name 'merge-not-changing-archive-passes' -Pass ($r.IsClean -eq $true) -Detail $r.Reason

# BLOCKER 6 ITSELF, in two shapes. Both must stay red forever.
#
# Shape A -- the merge resolves the archive to something that matches NEITHER
# parent (a hand-edited "conflict resolution").
$fxA = New-MergeFixture -Tag 'merge_launder_a' -MainArchive $a2 -SideArchive $a2side -MergeArchive $a3
$r = Invoke-Walk -Dir $fxA.Dir -Checkpoint $fxA.Checkpoint
Add-Result -Name 'merge-changing-archive-fails-BLOCKER6-shapeA' -Pass ($r.IsClean -eq $false) -Detail $r.Reason

# Shape B -- the merge takes the SECOND parent's archive verbatim. This is the
# truer laundering shape: the bytes arrive exactly as the side branch wrote them,
# having never been validated as a first-parent append. It is also the shape most
# likely to be simplified away by path-filtered history, which is why it gets its
# own case rather than being folded into shape A.
$fxB = New-MergeFixture -Tag 'merge_launder_b' -MainArchive $a2 -SideArchive $a2side -MergeArchive $a2side
$r = Invoke-Walk -Dir $fxB.Dir -Checkpoint $fxB.Checkpoint
Add-Result -Name 'merge-changing-archive-fails-BLOCKER6-shapeB-second-parent-verbatim' -Pass ($r.IsClean -eq $false) -Detail $r.Reason

# Design invariant, checked directly rather than trusted: whatever commit list the
# walk iterates MUST still contain the laundering merge. Path-filtering the
# rev-list is the optimization ORDER-270 was tempted by; this case measures
# whether that filter drops either laundering shape. If it does for ANY shape, no
# implementation may iterate the path-filtered list.
$filterDrops = @()
foreach ($fx in @(@{ N = 'shapeA'; F = $fxA }, @{ N = 'shapeB'; F = $fxB })) {
    $mergeSha = Get-GitObjectId -RepoRoot $fx.F.Dir -Spec 'HEAD'
    $unfiltered = Invoke-GitRaw -RepoRoot $fx.F.Dir -Arguments ('rev-list --first-parent "{0}..HEAD"' -f $fx.F.Checkpoint)
    $filtered = Invoke-GitRaw -RepoRoot $fx.F.Dir -Arguments ('rev-list --first-parent "{0}..HEAD" -- "{1}"' -f $fx.F.Checkpoint, $ARCHIVE)
    $inUnfiltered = (($unfiltered.StdOut -split '\s+' | Where-Object { $_ }) -contains $mergeSha)
    $inFiltered = (($filtered.StdOut -split '\s+' | Where-Object { $_ }) -contains $mergeSha)
    if ($inUnfiltered -and -not $inFiltered) { $filterDrops += $fx.N }
}
# The walk must iterate a list that keeps every laundering merge. We assert the
# property the CODE relies on: the chain it actually walks is the unfiltered one.
$walkedChain = Get-GitFirstParentChain -RepoRoot $fxB.Dir -FromSha $fxB.Checkpoint -ToRef 'HEAD'
$mergeShaB = Get-GitObjectId -RepoRoot $fxB.Dir -Spec 'HEAD'
Add-Result -Name 'walked-chain-still-contains-every-laundering-merge' -Pass ($walkedChain -contains $mergeShaB) `
    -Detail ("chainLength={0} containsMerge={1} -- path-filtered rev-list would DROP: {2}" -f $walkedChain.Count, ($walkedChain -contains $mergeShaB), $(if ($filterDrops.Count) { $filterDrops -join ',' } else { '(none observed on this git version -- do NOT read that as permission to path-filter; simplification rules are version- and shape-dependent)' }))

# ------------------------------------------------------------------- perf ----
# The regression guard for the whole point of ORDER-270: a long chain of commits
# that never touch the archive must not cost one git spawn per commit.
$dir = New-TempGitRepo -Tag 'perf'
$ckpt = Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a1 -Message 'checkpoint'
foreach ($i in 1..$PerfChainLength) {
    Write-CommitFile -Dir $dir -RelPath ("noise_{0}.txt" -f $i) -Content "noise $i" -Message "noise $i" | Out-Null
}
Write-CommitFile -Dir $dir -RelPath $ARCHIVE -Content $a2 -Message 'append 002' | Out-Null
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$r = Invoke-Walk -Dir $dir -Checkpoint $ckpt
$sw.Stop()
$elapsed = $sw.Elapsed.TotalSeconds
Add-Result -Name ("perf-{0}-commit-chain-under-{1}s" -f $PerfChainLength, $PerfBudgetSeconds) `
    -Pass (($r.IsClean -eq $true) -and ($elapsed -lt $PerfBudgetSeconds)) `
    -Detail ("clean={0} elapsed={1:N2}s budget={2:N2}s" -f $r.IsClean, $elapsed, $PerfBudgetSeconds)

# ---------------------------------------------------------------- report ----
$failed = @($results | Where-Object { -not $_.Pass })
foreach ($res in $results) {
    $tag = if ($res.Pass) { 'PASS' } else { 'FAIL' }
    Write-Host ("[{0}] {1}" -f $tag, $res.Name)
    if ($res.Detail) { Write-Host ("       {0}" -f $res.Detail) }
}
Write-Host ''
Write-Host ("{0}/{1} cases passed" -f ($results.Count - $failed.Count), $results.Count)
if ($failed.Count -eq 0) {
    Write-Host 'ALL CASES PASSED'
    $suiteExitCode = 0
} else {
    Write-Host 'ONE OR MORE CASES FAILED -- see above'
    $suiteExitCode = 1
}

} finally {
    Remove-TempScratchDirectory -Path $scratchRoot
}

exit $suiteExitCode
