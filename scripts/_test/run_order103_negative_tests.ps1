<#
.SYNOPSIS
    ORDER-103 Contract C1-ENFORCE -- negative/structural test suite for the 4 fixes
    (Fix 4 snapshot primitives, Fix 1 append-chain integrity, Fix 3 Source-A exact
    binding, Fix 2 fail-closed staged-snapshot pre-commit hook).

.DESCRIPTION
    Two testing styles are used, both explicitly never touching the shared EA_LAB
    working tree/history:
      - Fix 1 / Fix 4: dot-sources check_taskboard_archive.ps1 IN-PROCESS (safe --
        the script only calls `exit` from Invoke-Main, which the
        `if ($MyInvocation.InvocationName -ne '.')` guard skips when dot-sourced)
        and calls Invoke-ArchiveChainIntegrityCheck / Get-Snapshot directly against
        throwaway git repos created under $env:TEMP for each case.
      - Fix 3: calls Invoke-ExceptionClosure directly (also via dot-source) against
        small synthetic in-memory block/exception objects -- no markdown fixtures
        needed, avoids hand-computing sha256 values by hand.
      - Fix 2: REAL `git commit` inside a throwaway temp repo with
        core.hooksPath pointed at a copy of .githooks (mirrors the real hook
        exactly), asserting block/pass by exit code.

    The suite includes explicit regression coverage for the ORDER-103 Fix 1
    lettered cases plus the staged-hook and closure-precedence edge cases added
    during independent review.

    Run: powershell -NoProfile -File scripts\_test\run_order103_negative_tests.ps1
    Exit code: 0 if every case matched its expected outcome, 1 otherwise.
#>
param(
    [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$validator = Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1'
. $validator -RepoRoot $RepoRoot 6>$null   # dot-source for functions only (no Invoke-Main/exit)

function Remove-TempScratchDirectory {
    param([string]$Path)

    $tempRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $resolved = [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $requiredPrefix = $tempRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($requiredPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "refusing to remove scratch path outside TEMP: '$resolved'"
    }
    if ([System.IO.Path]::GetFileName($resolved) -notlike 'order103_negtests_*') {
        throw "refusing to remove unexpected TEMP directory: '$resolved'"
    }

    $longPath = if ($resolved.StartsWith('\\')) {
        '\\?\UNC\' + $resolved.Substring(2)
    } else {
        '\\?\' + $resolved
    }
    if ([System.IO.Directory]::Exists($longPath)) {
        foreach ($file in [System.IO.Directory]::EnumerateFiles($longPath, '*', [System.IO.SearchOption]::AllDirectories)) {
            $attributes = [System.IO.File]::GetAttributes($file)
            if (($attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) {
                $writableAttributes = [int]$attributes -band (-bnot [int][System.IO.FileAttributes]::ReadOnly)
                [System.IO.File]::SetAttributes($file, [System.IO.FileAttributes]$writableAttributes)
            }
        }
        [System.IO.Directory]::Delete($longPath, $true)
    }
}

$scratchRoot = Join-Path $env:TEMP ('order103_negtests_' + $PID)
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
    Invoke-GitRaw -RepoRoot $dir -Arguments 'init -q' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config user.email test@example.com' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config user.name "order103 test"' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config core.autocrlf false' | Out-Null
    return $dir
}

function Write-CommitFile {
    param([string]$Dir, [string]$RelPath, [string]$Content, [string]$Message)
    $full = Join-Path $Dir $RelPath
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllBytes($full, [System.Text.Encoding]::UTF8.GetBytes($Content))
    Invoke-GitRaw -RepoRoot $Dir -Arguments ('add -- "{0}"' -f $RelPath) | Out-Null
    $r = Invoke-GitRaw -RepoRoot $Dir -Arguments ('commit -q -m "{0}"' -f $Message)
    if ($r.ExitCode -ne 0) { throw "commit failed: $($r.StdErr)" }
    return (Get-GitObjectId -RepoRoot $Dir -Spec 'HEAD')
}

function Invoke-PowerShellFile {
    param(
        [string]$Dir,
        [string]$ScriptRelPath,
        [string]$Arguments = ''
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = ('-NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f $ScriptRelPath, $Arguments)
    $psi.WorkingDirectory = $Dir
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return [pscustomobject]@{ ExitCode = $proc.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function New-RealWorkingTreeFixture {
    <# Clone committed history, then overlay only the current ORDER-103 build files.
       The Source-A binding is now committed, so HEAD supplies its trust anchor;
       overlaying the current validator/hook candidate lets the suite exercise the
       still-uncommitted enforcement code without touching the shared repo. #>
    param([string]$Tag)
    $dir = Join-Path $scratchRoot $Tag
    $clone = Invoke-GitRaw -RepoRoot $scratchRoot -Arguments ('-c core.longpaths=true clone -q --no-local -- "{0}" "{1}"' -f $RepoRoot, $dir)
    if ($clone.ExitCode -ne 0) { throw "real-fixture clone failed: $($clone.StdErr)" }
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config user.email test@example.com' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config user.name "order103 test"' | Out-Null
    Invoke-GitRaw -RepoRoot $dir -Arguments 'config core.autocrlf true' | Out-Null

    $overlay = @(
        '.githooks\pre-commit',
        'scripts\check_taskboard_archive.ps1',
        'scripts\check_precommit_staged.ps1',
        'scripts\check_experiment_events.ps1',
        'scripts\experiment_event_log.ps1',
        'ARCHIVE_TASKBOARD_2026-07A.md',
        'docs\memory_control\ARCHIVE_MANIFEST.csv',
        'docs\memory_control\ARCHIVE_INDEX.md',
        'docs\memory_control\RECONCILE_EXCEPTIONS.md'
    )
    foreach ($rel in $overlay) {
        $dest = Join-Path $dir $rel
        $parent = Split-Path -Parent $dest
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Copy-Item -LiteralPath (Join-Path $RepoRoot $rel) -Destination $dest -Force
    }
    [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\check_verdict_kill.ps1'),'exit 0',(New-Object System.Text.UTF8Encoding($false)))
    return $dir
}

# ============================================================================
# FIX 1 -- append-chain integrity (temp repos, in-process function calls)
# ============================================================================

# --- (checkpoint) a fresh 3-commit repo: checkpoint, then a clean H2 append, then
#     a mutation of an earlier block. Exercises: ancestor-ok, clean-append=pass,
#     mutate=fail, checkpoint-not-ancestor=fail (separate unrelated repo), and the
#     suffix-must-open-new-H2 rule. ---
$repo1 = New-TempGitRepo -Tag 'fix1_base'
$archiveRel = 'ARCHIVE.md'
$v0 = "## Block A`nbody A`n"
$checkpointSha = Write-CommitFile -Dir $repo1 -RelPath $archiveRel -Content $v0 -Message 'checkpoint'

# (c) clean append -- new H2 block, must PASS
$v1 = $v0 + "`n## Block B`nbody B`n"
$headShaClean = Write-CommitFile -Dir $repo1 -RelPath $archiveRel -Content $v1 -Message 'append B'
$r1 = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1 -CheckpointSha $checkpointSha -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-clean-append-new-H2-passes' -Pass ($r1.IsClean -eq $true) -Detail $r1.Reason

# (f) suffix that extends the last block WITHOUT a new H2 -- must FAIL
$repo1f = New-TempGitRepo -Tag 'fix1_suffixnoh2'
$cp1f = Write-CommitFile -Dir $repo1f -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
$vBad = $v0 + "extra prose appended to the same block, no new H2`n"
Write-CommitFile -Dir $repo1f -RelPath $archiveRel -Content $vBad -Message 'bad extend' | Out-Null
$rf = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1f -CheckpointSha $cp1f -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-suffix-extends-last-block-without-new-H2-fails' -Pass ($rf.IsClean -eq $false) -Detail $rf.Reason

# A separator belongs between archive blocks. Blank lines and one horizontal rule
# before the first new H2 must therefore PASS; prose/table rows still fail above.
$repo1sep = New-TempGitRepo -Tag 'fix1_separator'
$cp1sep = Write-CommitFile -Dir $repo1sep -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
$vSeparated = $v0 + "`n---`n`n## NEWBLOCK`nbody B`n"
Write-CommitFile -Dir $repo1sep -RelPath $archiveRel -Content $vSeparated -Message 'append separated block' | Out-Null
$rSeparated = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1sep -CheckpointSha $cp1sep -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-append-newblock-after-separator-passes' -Pass ($rSeparated.IsClean -eq $true) -Detail $rSeparated.Reason

# (a) mutate an earlier block's bytes (checkpoint content itself changed) -- must FAIL
$repo1a = New-TempGitRepo -Tag 'fix1_mutate'
$cp1a = Write-CommitFile -Dir $repo1a -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
$vMut = "## Block A`nBODY A MUTATED`n" + "`n## Block B`nbody B`n"
Write-CommitFile -Dir $repo1a -RelPath $archiveRel -Content $vMut -Message 'mutate+append' | Out-Null
$ra = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1a -CheckpointSha $cp1a -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-mutate-earlier-block-fails' -Pass ($ra.IsClean -eq $false) -Detail $ra.Reason

# (d) truncate/remove an append -- shrink the file -- must FAIL
$repo1d = New-TempGitRepo -Tag 'fix1_truncate'
$cp1d = Write-CommitFile -Dir $repo1d -RelPath $archiveRel -Content $v1 -Message 'checkpoint (has B already)'
Write-CommitFile -Dir $repo1d -RelPath $archiveRel -Content $v0 -Message 'truncate away B' | Out-Null
$rd = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1d -CheckpointSha $cp1d -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-truncate-append-fails' -Pass ($rd.IsClean -eq $false) -Detail $rd.Reason

# (g) checkpoint not an ancestor of HEAD -- use a checkpoint sha from an UNRELATED repo
$repo1g = New-TempGitRepo -Tag 'fix1_unrelated'
Write-CommitFile -Dir $repo1g -RelPath $archiveRel -Content $v0 -Message 'unrelated commit' | Out-Null
$fakeCheckpoint = ('a' * 40)   # syntactically valid-looking but nonexistent sha
$rg = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1g -CheckpointSha $fakeCheckpoint -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-checkpoint-missing-object-fails-closed' -Pass ($rg.IsClean -eq $false) -Detail $rg.Reason

# checkpoint-not-ancestor with a REAL but unrelated commit (two independent temp repos,
# reuse repo1's checkpoint sha inside repo1g's history where it does not exist as an
# ancestor -- already covered by the missing-object case above structurally; additionally
# prove the ancestor-but-different-branch case using a diverged branch inside ONE repo).
$repo1gg = New-TempGitRepo -Tag 'fix1_diverged'
$cpDiverged = Write-CommitFile -Dir $repo1gg -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
Invoke-GitRaw -RepoRoot $repo1gg -Arguments 'checkout -q -b sidebranch' | Out-Null
Write-CommitFile -Dir $repo1gg -RelPath $archiveRel -Content $v1 -Message 'side append' | Out-Null
Invoke-GitRaw -RepoRoot $repo1gg -Arguments 'checkout -q master' | Out-Null
$vMain = $v0 + "`n## Block C (main line, no B)`nbody C`n"
Write-CommitFile -Dir $repo1gg -RelPath $archiveRel -Content $vMain -Message 'main line append' | Out-Null
# checkpoint IS an ancestor of master here (both branches came from it) -- sanity: this
# should PASS on master (proves ancestor-but-diverged-elsewhere is fine when the
# CHECKED ref's own line is clean).
$rgg = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1gg -CheckpointSha $cpDiverged -ArchiveRelPath $archiveRel -HeadRef 'master'
Add-Result -Name 'fix1-checkpoint-ancestor-via-shared-root-passes-on-clean-branch' -Pass ($rgg.IsClean -eq $true) -Detail $rgg.Reason

# (e) two valid H2 appends are committed, then their established byte order is
# swapped. The final file still contains both blocks, but the intermediate chain
# identity was rewritten and must fail closed.
$repo1e = New-TempGitRepo -Tag 'fix1_reordered_appends'
$cp1e = Write-CommitFile -Dir $repo1e -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
$vOrderB = $v0 + "`n## Block B`nbody B`n"
Write-CommitFile -Dir $repo1e -RelPath $archiveRel -Content $vOrderB -Message 'append B' | Out-Null
$vOrderBC = $vOrderB + "`n## Block C`nbody C`n"
Write-CommitFile -Dir $repo1e -RelPath $archiveRel -Content $vOrderBC -Message 'append C' | Out-Null
$vOrderCB = $v0 + "`n## Block C`nbody C`n`n## Block B`nbody B`n"
Write-CommitFile -Dir $repo1e -RelPath $archiveRel -Content $vOrderCB -Message 'swap B and C' | Out-Null
$re = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1e -CheckpointSha $cp1e -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-reordered-appends-fails' `
    -Pass (($re.IsClean -eq $false) -and ($re.Reason -match 'mutation|reorder|prefix')) `
    -Detail $re.Reason

# (i) commits that do not touch the archive may occur between the checkpoint and
# a legitimate H2 append. They remain part of history but do not break the chain.
$repo1i = New-TempGitRepo -Tag 'fix1_interspersed_unrelated'
$cp1i = Write-CommitFile -Dir $repo1i -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
Write-CommitFile -Dir $repo1i -RelPath 'ordinary.txt' -Content "ordinary change`n" -Message 'unrelated commit' | Out-Null
Write-CommitFile -Dir $repo1i -RelPath $archiveRel -Content $v1 -Message 'append B after unrelated commit' | Out-Null
$ri = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1i -CheckpointSha $cp1i -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-archive-commits-separated-by-unrelated-commits-passes' `
    -Pass ($ri.IsClean -eq $true) -Detail $ri.Reason

# (j) restoring the checkpoint bytes in a later commit does not erase the
# intervening mutation from history; the walk must reject that broken link.
$repo1j = New-TempGitRepo -Tag 'fix1_mutate_then_restore'
$cp1j = Write-CommitFile -Dir $repo1j -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
Write-CommitFile -Dir $repo1j -RelPath $archiveRel -Content "## Block A`nmutated body`n" -Message 'mutate earlier block' | Out-Null
Write-CommitFile -Dir $repo1j -RelPath $archiveRel -Content $v0 -Message 'restore original bytes' | Out-Null
$restoredBytes = Get-GitBlobBytes -RepoRoot $repo1j -Ref 'HEAD' -Path $archiveRel
$checkpointBytes = Get-GitBlobBytes -RepoRoot $repo1j -Ref $cp1j -Path $archiveRel
$finalMatchesCheckpoint = ($restoredBytes.Length -eq $checkpointBytes.Length) -and (Test-BytePrefix -Prefix $checkpointBytes -Full $restoredBytes)
$rj = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1j -CheckpointSha $cp1j -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-mutate-then-restore-still-caught' `
    -Pass ($finalMatchesCheckpoint -and ($rj.IsClean -eq $false) -and ($rj.Reason -match 'mutation|reorder|prefix')) `
    -Detail ("final_matches_checkpoint={0} reason={1}" -f $finalMatchesCheckpoint, $rj.Reason)

# (g) the checkpoint object exists locally but is on a sibling branch and is not
# an ancestor of HEAD by any path. This is distinct from both a missing object and
# a checkpoint reachable only through a merge's non-first parent.
$repo1NotAncestor = New-TempGitRepo -Tag 'fix1_checkpoint_not_ancestor'
Write-CommitFile -Dir $repo1NotAncestor -RelPath $archiveRel -Content $v0 -Message 'shared root' | Out-Null
Invoke-GitRaw -RepoRoot $repo1NotAncestor -Arguments 'checkout -q -b checkpoint-branch' | Out-Null
$cpNotAncestor = Write-CommitFile -Dir $repo1NotAncestor -RelPath 'checkpoint.txt' -Content "checkpoint branch`n" -Message 'unrelated checkpoint'
Invoke-GitRaw -RepoRoot $repo1NotAncestor -Arguments 'checkout -q master' | Out-Null
Write-CommitFile -Dir $repo1NotAncestor -RelPath 'main.txt' -Content "main branch`n" -Message 'main head' | Out-Null
$checkpointObjectExists = Test-GitCommitObjectExists -RepoRoot $repo1NotAncestor -Sha $cpNotAncestor
$checkpointIsAncestor = Test-GitIsAncestor -RepoRoot $repo1NotAncestor -AncestorSha $cpNotAncestor -Ref 'HEAD'
$rNotAncestor = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1NotAncestor -CheckpointSha $cpNotAncestor -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-checkpoint-not-ancestor-fails-closed' `
    -Pass ($checkpointObjectExists -and (-not $checkpointIsAncestor) -and ($rNotAncestor.IsClean -eq $false) -and ($rNotAncestor.Reason -match 'NOT an ancestor') -and ($rNotAncestor.Reason -notmatch 'not found|non-first-parent')) `
    -Detail ("object_exists={0} any_path_ancestor={1} reason={2}" -f $checkpointObjectExists, $checkpointIsAncestor, $rNotAncestor.Reason)

# --- (h) shallow clone missing checkpoint -- clone repo1d (has multiple commits) with
#     --depth 1 so the checkpoint commit is not present -- must FAIL. ---
$shallowDir = Join-Path $scratchRoot 'fix1_shallow'
$rClone = Invoke-GitRaw -RepoRoot $scratchRoot -Arguments ('clone -q --depth 1 --no-local -- "{0}" "{1}"' -f $repo1d, $shallowDir)
if ($rClone.ExitCode -eq 0) {
    $rh = Invoke-ArchiveChainIntegrityCheck -RepoRoot $shallowDir -CheckpointSha $cp1d -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
    Add-Result -Name 'fix1-shallow-clone-missing-checkpoint-fails-closed' -Pass ($rh.IsClean -eq $false) -Detail $rh.Reason
} else {
    Add-Result -Name 'fix1-shallow-clone-missing-checkpoint-fails-closed' -Pass $false -Detail "SKIPPED -- shallow clone of a local repo failed in this environment: $($rClone.StdErr)"
}

# --- fresh full clone of the clean repo1 (checkpoint..HEAD) must PASS ---
$fullCloneDir = Join-Path $scratchRoot 'fix1_fullclone'
$rClone2 = Invoke-GitRaw -RepoRoot $scratchRoot -Arguments ('clone -q --no-local -- "{0}" "{1}"' -f $repo1, $fullCloneDir)
$rFull = Invoke-ArchiveChainIntegrityCheck -RepoRoot $fullCloneDir -CheckpointSha $checkpointSha -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-fresh-full-clone-passes' -Pass (($rClone2.ExitCode -eq 0) -and ($rFull.IsClean -eq $true)) -Detail $rFull.Reason

# --- detached HEAD with full ancestry must PASS (detached-ness alone is not a failure) ---
Invoke-GitRaw -RepoRoot $repo1 -Arguments ('checkout -q "{0}"' -f $headShaClean) | Out-Null
$rDetached = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1 -CheckpointSha $checkpointSha -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Invoke-GitRaw -RepoRoot $repo1 -Arguments 'checkout -q master' | Out-Null
Add-Result -Name 'fix1-detached-head-with-full-ancestry-passes' -Pass ($rDetached.IsClean -eq $true) -Detail $rDetached.Reason

# A checkpoint reachable only through a merge's non-first parent is an ancestor
# of HEAD, but it is not part of HEAD's literal first-parent line. It therefore
# cannot anchor the linear chain and must fail closed instead of being joined to
# an unrelated main-line commit by the range walk.
$repo1CheckpointNonFirstParent = New-TempGitRepo -Tag 'fix1_checkpoint_non_first_parent'
$rootCheckpointBase = Write-CommitFile -Dir $repo1CheckpointNonFirstParent -RelPath $archiveRel -Content $v0 -Message 'root archive'
Invoke-GitRaw -RepoRoot $repo1CheckpointNonFirstParent -Arguments 'checkout -q -b trusted' | Out-Null
$cpNonFirstParent = Write-CommitFile -Dir $repo1CheckpointNonFirstParent -RelPath 'trusted.txt' -Content "trusted checkpoint marker`n" -Message 'trusted checkpoint'
Invoke-GitRaw -RepoRoot $repo1CheckpointNonFirstParent -Arguments 'checkout -q master' | Out-Null
Write-CommitFile -Dir $repo1CheckpointNonFirstParent -RelPath 'main.txt' -Content "main line`n" -Message 'main line' | Out-Null
$mergeCheckpointNonFirstParent = Invoke-GitRaw -RepoRoot $repo1CheckpointNonFirstParent -Arguments 'merge -q --no-ff trusted -m "merge trusted branch"'
$firstParentCheckpointList = @(Get-GitFirstParentChain -RepoRoot $repo1CheckpointNonFirstParent -FromSha $rootCheckpointBase -ToRef 'HEAD')
$checkpointIsAnyPathAncestor = Test-GitIsAncestor -RepoRoot $repo1CheckpointNonFirstParent -AncestorSha $cpNonFirstParent -Ref 'HEAD'
$checkpointIsLiteralFirstParent = $firstParentCheckpointList -contains $cpNonFirstParent
$rCheckpointNonFirstParent = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1CheckpointNonFirstParent -CheckpointSha $cpNonFirstParent -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-checkpoint-only-on-non-first-parent-fails-closed' `
    -Pass (($mergeCheckpointNonFirstParent.ExitCode -eq 0) -and $checkpointIsAnyPathAncestor -and (-not $checkpointIsLiteralFirstParent) -and ($rCheckpointNonFirstParent.IsClean -eq $false) -and ($rCheckpointNonFirstParent.Reason -match 'non-first-parent')) `
    -Detail ("merge_exit={0} any_path_ancestor={1} literal_first_parent={2} chain_clean={3} reason={4}" -f $mergeCheckpointNonFirstParent.ExitCode, $checkpointIsAnyPathAncestor, $checkpointIsLiteralFirstParent, $rCheckpointNonFirstParent.IsClean, $rCheckpointNonFirstParent.Reason)

# BLOCKER 2 regression: an archive append that arrives in a merge commit through
# the merge's second parent must fail closed. The first-parent walk still defines
# the trusted linear history, but merges are not allowed to carry archive changes.
$repo1Merge = New-TempGitRepo -Tag 'fix1_merge_second_parent'
$cp1Merge = Write-CommitFile -Dir $repo1Merge -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
Invoke-GitRaw -RepoRoot $repo1Merge -Arguments 'checkout -q -b side' | Out-Null
Write-CommitFile -Dir $repo1Merge -RelPath $archiveRel -Content $v1 -Message 'side archive append' | Out-Null
Invoke-GitRaw -RepoRoot $repo1Merge -Arguments 'checkout -q master' | Out-Null
Write-CommitFile -Dir $repo1Merge -RelPath 'unrelated.txt' -Content "main line`n" -Message 'main unrelated' | Out-Null
$mergeSecondParent = Invoke-GitRaw -RepoRoot $repo1Merge -Arguments 'merge -q --no-ff side -m "merge side archive append"'
$rMergeSecondParent = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1Merge -CheckpointSha $cp1Merge -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-merge-second-parent-archive-change-fails' `
    -Pass (($mergeSecondParent.ExitCode -eq 0) -and ($rMergeSecondParent.IsClean -eq $false) -and ($rMergeSecondParent.Reason -match 'merge commit|non-first-parent')) `
    -Detail ("merge_exit={0} chain_clean={1} reason={2}" -f $mergeSecondParent.ExitCode, $rMergeSecondParent.IsClean, $rMergeSecondParent.Reason)

# BLOCKER 3 committed-chain leg: prepending bytes before the first H2 is not an
# append and must be rejected even though those bytes are outside Get-Blocks.
$repo1PreambleCommitted = New-TempGitRepo -Tag 'fix1_preamble_committed'
$cp1Preamble = Write-CommitFile -Dir $repo1PreambleCommitted -RelPath $archiveRel -Content $v0 -Message 'checkpoint'
Write-CommitFile -Dir $repo1PreambleCommitted -RelPath $archiveRel -Content ("TAMPER-PREAMBLE`n" + $v0) -Message 'prepend preamble' | Out-Null
$rPreambleCommitted = Invoke-ArchiveChainIntegrityCheck -RepoRoot $repo1PreambleCommitted -CheckpointSha $cp1Preamble -ArchiveRelPath $archiveRel -HeadRef 'HEAD'
Add-Result -Name 'fix1-pre-h2-preamble-tamper-committed-chain-fails' -Pass ($rPreambleCommitted.IsClean -eq $false) -Detail $rPreambleCommitted.Reason

# BLOCKER 1 regression: clone HEAD, which now contains the committed binding block,
# overlay the validator candidate, mutate prose unique to that anchored append,
# regenerate artifacts, then require Strict to reject the mutation. The old
# checkpoint->HEAD-only walk blessed this as exit 0 because no check covered
# HEAD->working.
$repo1Working = New-RealWorkingTreeFixture -Tag 'fix1_working_mutation'
$workingArchivePath = Join-Path $repo1Working 'ARCHIVE_TASKBOARD_2026-07A.md'
$beforeMutation = [System.IO.File]::ReadAllText($workingArchivePath, [System.Text.Encoding]::UTF8)
$needle = 'canonical-id-wildcard hole'
$mutatedText = $beforeMutation.Replace($needle, 'TAMPERED')
if ($mutatedText -eq $beforeMutation) {
    Add-Result -Name 'fix1-mutate-appended-block-prose-then-regen-strict-fails' -Pass $false -Detail "fixture did not contain unique mutation needle '$needle'"
} else {
    [System.IO.File]::WriteAllText($workingArchivePath, $mutatedText, (New-Object System.Text.UTF8Encoding($false)))
    $regenAfterMutation = Invoke-PowerShellFile -Dir $repo1Working -ScriptRelPath 'scripts\check_taskboard_archive.ps1' -Arguments '-Generate'
    $strictAfterMutation = Invoke-PowerShellFile -Dir $repo1Working -ScriptRelPath 'scripts\check_taskboard_archive.ps1' -Arguments '-Strict'
    Add-Result -Name 'fix1-mutate-appended-block-prose-then-regen-strict-fails' `
        -Pass (($regenAfterMutation.ExitCode -eq 0) -and ($strictAfterMutation.ExitCode -eq 2)) `
        -Detail ("generate_exit={0} strict_exit={1} strict_tail={2}" -f $regenAfterMutation.ExitCode, $strictAfterMutation.ExitCode, (($strictAfterMutation.StdOut + $strictAfterMutation.StdErr).Trim() -replace "`r?`n", ' | '))
}

# BLOCKER 3 working-tree leg, end-to-end through the public -Strict path. HEAD's
# real archive starts at byte zero with its first H2; a prepended preamble must be
# visible to the extension check and rejected before it can be committed.
$repo1PreambleWorking = New-RealWorkingTreeFixture -Tag 'fix1_preamble_working'
$preambleWorkingPath = Join-Path $repo1PreambleWorking 'ARCHIVE_TASKBOARD_2026-07A.md'
$preambleOriginalBytes = [System.IO.File]::ReadAllBytes($preambleWorkingPath)
$preambleBytes = [System.Text.Encoding]::UTF8.GetBytes("TAMPER-PREAMBLE`n")
$preambleCandidate = New-Object 'byte[]' ($preambleBytes.Length + $preambleOriginalBytes.Length)
[Array]::Copy($preambleBytes, 0, $preambleCandidate, 0, $preambleBytes.Length)
[Array]::Copy($preambleOriginalBytes, 0, $preambleCandidate, $preambleBytes.Length, $preambleOriginalBytes.Length)
[System.IO.File]::WriteAllBytes($preambleWorkingPath, $preambleCandidate)
$strictPreambleWorking = Invoke-PowerShellFile -Dir $repo1PreambleWorking -ScriptRelPath 'scripts\check_taskboard_archive.ps1' -Arguments '-Strict'
Add-Result -Name 'fix1-pre-h2-preamble-tamper-fails' `
    -Pass (($strictPreambleWorking.ExitCode -eq 2) -and (($strictPreambleWorking.StdOut + $strictPreambleWorking.StdErr) -match 'preamble|pre-H2')) `
    -Detail ("strict_exit={0} output={1}" -f $strictPreambleWorking.ExitCode, (($strictPreambleWorking.StdOut + $strictPreambleWorking.StdErr).Trim() -replace "`r?`n", ' | '))

# ============================================================================
# FIX 4 -- CRLF/clean-filter parity (staged identity via `git rev-parse :path`,
# NOT `git hash-object <working-file>`)
# ============================================================================
$repo4 = New-TempGitRepo -Tag 'fix4_crlf'
Invoke-GitRaw -RepoRoot $repo4 -Arguments 'config core.autocrlf true' | Out-Null
$crlfContent = "## Block A`r`nbody A`r`n"
$fullPath = Join-Path $repo4 'ARCHIVE.md'
[System.IO.File]::WriteAllBytes($fullPath, [System.Text.Encoding]::UTF8.GetBytes($crlfContent))
Invoke-GitRaw -RepoRoot $repo4 -Arguments 'add -- ARCHIVE.md' | Out-Null
$stagedSnap = Get-Snapshot -RepoRoot $repo4 -Mode Staged -RelPath 'ARCHIVE.md'
$workingHashObjectId = Get-GitHashObjectId -RepoRoot $repo4 -RelPath 'ARCHIVE.md'
# The point of Fix 4: staged identity (git rev-parse :path) is the TRUE index oid
# regardless of what a raw hash-object of the (possibly CRLF, possibly filtered)
# working file would give. Assert the staged Get-Snapshot identity equals what
# `git rev-parse :path` gives directly (i.e. Get-Snapshot really is using the
# staged/index source, not silently falling back to a working-tree hash).
$directStagedOid = Get-GitObjectId -RepoRoot $repo4 -Spec ':ARCHIVE.md'
Add-Result -Name 'fix4-staged-identity-matches-git-rev-parse-colon-path' -Pass ($stagedSnap.Identity -eq $directStagedOid) -Detail "Get-Snapshot(Staged).Identity=$($stagedSnap.Identity) direct-rev-parse=$directStagedOid working-hash-object=$workingHashObjectId"

# Exercise canonical-LF/CRLF handling through the real public Strict path, not
# only through the snapshot identity primitive above.
$repo4Strict = New-RealWorkingTreeFixture -Tag 'fix4_crlf_strict'
$strictCrlf = Invoke-PowerShellFile -Dir $repo4Strict -ScriptRelPath 'scripts\check_taskboard_archive.ps1' -Arguments '-Strict'
Add-Result -Name 'fix4-crlf-real-strict-end-to-end-passes' -Pass ($strictCrlf.ExitCode -eq 0) -Detail ("strict_exit={0}" -f $strictCrlf.ExitCode)

# Exact pre-H2 bytes after Git checkout filtering: alter only one EOL byte in the
# existing nonempty preamble. Canonical-text comparison would miss this; the raw
# expected-checkout comparison must reject it.
$repo4PreambleEol = New-RealWorkingTreeFixture -Tag 'fix4_preamble_eol_exact'
$preambleEolPath = Join-Path $repo4PreambleEol 'ARCHIVE_TASKBOARD_2026-07A.md'
$preambleEolBytes = [System.IO.File]::ReadAllBytes($preambleEolPath)
$firstCrLf = -1
for ($i = 0; $i -lt ($preambleEolBytes.Length - 1); $i++) {
    if ($preambleEolBytes[$i] -eq 13 -and $preambleEolBytes[$i + 1] -eq 10) { $firstCrLf = $i; break }
}
if ($firstCrLf -lt 0) {
    Add-Result -Name 'fix1-pre-h2-eol-byte-tamper-fails' -Pass $false -Detail 'fixture preamble had no CRLF to mutate'
} else {
    $preambleEolMutated = New-Object 'byte[]' ($preambleEolBytes.Length - 1)
    [Array]::Copy($preambleEolBytes, 0, $preambleEolMutated, 0, $firstCrLf)
    [Array]::Copy($preambleEolBytes, $firstCrLf + 1, $preambleEolMutated, $firstCrLf, $preambleEolBytes.Length - $firstCrLf - 1)
    [System.IO.File]::WriteAllBytes($preambleEolPath, $preambleEolMutated)
    $strictPreambleEol = Invoke-PowerShellFile -Dir $repo4PreambleEol -ScriptRelPath 'scripts\check_taskboard_archive.ps1' -Arguments '-Strict'
    Add-Result -Name 'fix1-pre-h2-eol-byte-tamper-fails' -Pass (($strictPreambleEol.ExitCode -eq 2) -and (($strictPreambleEol.StdOut + $strictPreambleEol.StdErr) -match 'byte-for-byte')) -Detail ("strict_exit={0}" -f $strictPreambleEol.ExitCode)
}

# ============================================================================
# FIX 3 -- Source-A exact-identity binding (in-memory synthetic exceptions, no
# markdown fixtures needed -- exercises Invoke-ExceptionClosure directly)
# ============================================================================

function New-FakeBlock {
    param([string]$Header, [string]$Content, [string]$BlockType, [string]$StatusClass, [string]$StatusLabel, [string[]]$CanonicalIds, [string]$BlockId)
    $sha = Get-Sha256Hex -Bytes ([System.Text.Encoding]::UTF8.GetBytes($Content))
    return [pscustomobject]@{
        Header = $Header; Content = $Content; Sha256 = $sha; BlockType = $BlockType
        StatusClass = $StatusClass; StatusLabel = $StatusLabel; CanonicalIds = @($CanonicalIds); BlockId = $BlockId
    }
}

$targetBlock = New-FakeBlock -Header '## ORDER-900 -- test target' -Content 'target block body' `
    -BlockType 'ORDER' -StatusClass 'NonTerminal' -StatusLabel 'OPEN' -CanonicalIds @('900') -BlockId '900|ORDER|current-archive#1'
$reviewBlock = New-FakeBlock -Header '## REVIEW ORDER-900' -Content 'review body' `
    -BlockType 'REVIEW-NOTE' -StatusClass 'Terminal' -StatusLabel 'REVIEWED' -CanonicalIds @('900') -BlockId '900|REVIEW-NOTE|current-archive#2'
$targetSha = $targetBlock.Sha256

$rawExceptions = @([pscustomobject]@{ Kind = 'non-terminal-in-archive'; BlockId = $targetBlock.BlockId; Header = $targetBlock.Header; Detail = 'status=OPEN'; CanonicalId = '900'; Sha256 = $targetSha })

function Invoke-FakeClosure {
    param(
        [string]$BindingTableRow,
        [string]$BindingStatusLabel = 'REVIEWED(Opus, test)',
        [string]$C1ClosureTableRow = ''
    )
    $bindingContent = @"
| kind | block_id | block_sha256 | review_ref |
|---|---|---|---|
$BindingTableRow
"@
    $bindingBlock = New-FakeBlock -Header '## C1-ENFORCE-SOURCEA-BINDING -- test' -Content $bindingContent `
        -BlockType 'OTHER' -StatusClass 'Terminal' -StatusLabel $BindingStatusLabel -CanonicalIds @() -BlockId 'binding#1'
    $archiveBlocks = @($targetBlock, $reviewBlock, $bindingBlock)
    if ($C1ClosureTableRow) {
        $closureContent = @"
| kind | block_id | block_sha256 | disposition | evidence |
|---|---|---|---|---|
$C1ClosureTableRow
"@
        $closureBlock = New-FakeBlock -Header '## C1-CLOSURE -- test' -Content $closureContent `
            -BlockType 'OTHER' -StatusClass 'Terminal' -StatusLabel 'REVIEWED(Opus, test)' -CanonicalIds @() -BlockId 'closure#1'
        $archiveBlocks += $closureBlock
    }
    return Invoke-ExceptionClosure -PolicyExceptions $rawExceptions -ActiveBlocks @() -ArchiveBlocks $archiveBlocks
}

# exact match -> closed
$rowExact = "| non-terminal-in-archive | $($targetBlock.BlockId -replace '\|','\|') | $targetSha | ## REVIEW ORDER-900 |"
$closureExact = Invoke-FakeClosure -BindingTableRow $rowExact
Add-Result -Name 'fix3-exact-binding-closes' -Pass (($closureExact.Reviewed.Count -eq 1) -and ($closureExact.Unresolved.Count -eq 0) -and ($closureExact.IntegrityFailures.Count -eq 0)) -Detail "reviewed=$($closureExact.Reviewed.Count) unresolved=$($closureExact.Unresolved.Count) integrity=$($closureExact.IntegrityFailures.Count)"

# wrong hash -> STALE, stays unresolved (not closed)
$rowWrongHash = "| non-terminal-in-archive | $($targetBlock.BlockId -replace '\|','\|') | " + ('0' * 64) + " | ## REVIEW ORDER-900 |"
$closureStale = Invoke-FakeClosure -BindingTableRow $rowWrongHash
Add-Result -Name 'fix3-wrong-hash-stays-unresolved-stale' -Pass (($closureStale.Unresolved.Count -eq 1) -and ($closureStale.Unresolved[0].StaleClosureNote -ne $null)) -Detail "unresolved=$($closureStale.Unresolved.Count) staleNote=$($closureStale.Unresolved[0].StaleClosureNote)"

# id matches but wrong kind (phase/forged-style mismatch) -> not closed
$rowWrongKind = "| terminal-no-linked-review | $($targetBlock.BlockId -replace '\|','\|') | $targetSha | ## REVIEW ORDER-900 |"
$closureWrongKind = Invoke-FakeClosure -BindingTableRow $rowWrongKind
Add-Result -Name 'fix3-wrong-kind-same-blockid-unknown-row-integrity' -Pass ($closureWrongKind.IntegrityFailures.Count -eq 1 -and $closureWrongKind.IntegrityFailures[0].Kind -eq 'sourcea-binding-unknown-row') -Detail "integrity=$($closureWrongKind.IntegrityFailures.Count) kind=$($closureWrongKind.IntegrityFailures[0].Kind)"

# duplicate row (same kind+block_id twice) -> integrity failure
$rowDup = $rowExact + "`n" + $rowExact
$closureDup = Invoke-FakeClosure -BindingTableRow $rowDup
Add-Result -Name 'fix3-duplicate-row-is-integrity' -Pass (@($closureDup.IntegrityFailures | Where-Object { $_.Kind -eq 'sourcea-binding-duplicate-row' }).Count -eq 1) -Detail "integrity kinds: $(($closureDup.IntegrityFailures | ForEach-Object { $_.Kind }) -join ',')"

# unknown target (matches no exception) -> integrity failure
$rowUnknown = "| non-terminal-in-archive | 999\|ORDER\|current-archive#99 | $targetSha | ## REVIEW ORDER-900 |"
$closureUnknown = Invoke-FakeClosure -BindingTableRow $rowUnknown
Add-Result -Name 'fix3-unknown-target-is-integrity' -Pass (@($closureUnknown.IntegrityFailures | Where-Object { $_.Kind -eq 'sourcea-binding-unknown-row' }).Count -eq 1) -Detail "integrity kinds: $(($closureUnknown.IntegrityFailures | ForEach-Object { $_.Kind }) -join ',')"

# malformed hash -> integrity failure
$rowMalformed = "| non-terminal-in-archive | $($targetBlock.BlockId -replace '\|','\|') | not-a-real-hash | ## REVIEW ORDER-900 |"
$closureMalformed = Invoke-FakeClosure -BindingTableRow $rowMalformed
Add-Result -Name 'fix3-malformed-hash-is-integrity' -Pass (@($closureMalformed.IntegrityFailures | Where-Object { $_.Kind -eq 'sourcea-binding-malformed-hash' }).Count -eq 1) -Detail "integrity kinds: $(($closureMalformed.IntegrityFailures | ForEach-Object { $_.Kind }) -join ',')"

# The same exact exception can be named by both closure sources. Source A wins
# deterministically, Source B is reported as additional evidence, and the raw
# exception appears exactly once in the reviewed partition.
$rowSourceB = "| non-terminal-in-archive | $($targetBlock.BlockId -replace '\|','\|') | $targetSha | accepted | independent Source B evidence |"
$closureBoth = Invoke-FakeClosure -BindingTableRow $rowExact -C1ClosureTableRow $rowSourceB
$bothReviewed = @($closureBoth.Reviewed)
Add-Result -Name 'fix3-sourcea-and-sourceb-simultaneous-closure-precedence' `
    -Pass (($bothReviewed.Count -eq 1) -and ($closureBoth.Unresolved.Count -eq 0) -and ($closureBoth.IntegrityFailures.Count -eq 0) -and ($bothReviewed[0].ClosureSource -eq 'A-sourcea-binding') -and ($bothReviewed[0].ClosureDetail -match 'also independently closable via B.*A precedence applied, not double-counted')) `
    -Detail ("reviewed={0} unresolved={1} integrity={2} source={3} detail={4}" -f $bothReviewed.Count, $closureBoth.Unresolved.Count, $closureBoth.IntegrityFailures.Count, $bothReviewed[0].ClosureSource, $bothReviewed[0].ClosureDetail)

# ============================================================================
# FIX 2 -- fail-closed staged-snapshot pre-commit hook, REAL commits in a temp repo
# ============================================================================

function New-TempHookRepo {
    param([string]$Tag)
    $dir = New-TempGitRepo -Tag $Tag
    $hooksDir = Join-Path $dir '.githooks'
    New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
    Copy-Item (Join-Path $RepoRoot '.githooks\pre-commit') (Join-Path $hooksDir 'pre-commit') -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'scripts') | Out-Null
    Copy-Item (Join-Path $RepoRoot 'scripts\check_precommit_staged.ps1') (Join-Path $dir 'scripts\check_precommit_staged.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1') (Join-Path $dir 'scripts\check_taskboard_archive.ps1') -Force
    Copy-Item (Join-Path $RepoRoot 'scripts\check_experiment_events.ps1') (Join-Path $dir 'scripts\check_experiment_events.ps1') -Force
    # ...and the event checker dot-sources the append utility (its rule engine),
    # so the fixture must carry that dependency too or the hook fails on line 19
    # of check_experiment_events.ps1 (missing-dependency = fail-closed, by design).
    Copy-Item (Join-Path $RepoRoot 'scripts\experiment_event_log.ps1') (Join-Path $dir 'scripts\experiment_event_log.ps1') -Force
    # check_state.ps1 is repo-specific (checks EA_LAB docs) -- stub a trivial pass-through
    # so the temp-repo hook test isolates the ORDER-103 Fix 2 logic, not the unrelated
    # anti-drift guard.
    'exit 0' | Set-Content -Path (Join-Path $dir 'scripts\check_state.ps1') -Encoding UTF8
    [System.IO.File]::WriteAllText((Join-Path $dir 'scripts\check_verdict_kill.ps1'),'exit 0',(New-Object System.Text.UTF8Encoding($false)))
    # NOTE: hooksPath deliberately NOT set here -- callers seed their checkpoint/setup
    # commits first (which may themselves touch protected files) and only call
    # Enable-TempHook right before the commit actually under test, so setup commits
    # aren't accidentally blocked by the very hook being tested.
    New-Item -ItemType Directory -Force -Path (Join-Path $dir 'docs\memory_control') | Out-Null
    return $dir
}

function Enable-TempHook {
    param([string]$Dir)
    Invoke-GitRaw -RepoRoot $Dir -Arguments 'config core.hooksPath .githooks' | Out-Null
}

function Write-StagedArtifactsForHookRepo {
    <# Generate the three protected artifacts from the repo's INDEX snapshots,
       exactly like check_precommit_staged.ps1. This makes mutation tests reach
       the chain guard instead of vacuously stopping at the missing-artifact gate. #>
    param([string]$Dir)

    $candidateArchive = Get-Snapshot -RepoRoot $Dir -Mode Staged -RelPath 'ARCHIVE_TASKBOARD_2026-07A.md'
    $candidateActive = Get-Snapshot -RepoRoot $Dir -Mode Staged -RelPath 'AGENT_TASKBOARD.md'
    $candidateActiveBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $candidateActive.Bytes) -SourceTag 'current-active')
    $candidateArchiveBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $candidateArchive.Bytes) -SourceTag 'current-archive')
    $candidateScan = Invoke-ExceptionScan -CurrentActiveBlocks $candidateActiveBlocks -CurrentArchiveBlocks $candidateArchiveBlocks
    $candidateClosure = Invoke-ExceptionClosure -PolicyExceptions $candidateScan.Policy -ActiveBlocks $candidateActiveBlocks -ArchiveBlocks $candidateArchiveBlocks
    $candidateReport = [ordered]@{
        PolicyExceptions = @($candidateScan.Policy)
        CanonicallyReviewed = @($candidateClosure.Reviewed)
        UnresolvedPolicyExceptions = @($candidateClosure.Unresolved)
        IntegrityFailures = @($candidateScan.Integrity) + @($candidateClosure.IntegrityFailures)
    }
    if ($candidateReport.IntegrityFailures.Count -gt 0) {
        throw "candidate staged content has integrity failures: $($candidateReport.IntegrityFailures.Count)"
    }

    $candidateRows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $candidateArchiveBlocks -ArchiveBlobSha $candidateArchive.Identity)
    $artifactRoot = Join-Path $Dir 'docs\memory_control'
    New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
    Write-ArchiveManifestCsv -Rows $candidateRows -Path (Join-Path $artifactRoot 'ARCHIVE_MANIFEST.csv')
    Write-TextFileLfNoBom -Path (Join-Path $artifactRoot 'ARCHIVE_INDEX.md') -Text (Build-ArchiveIndexMarkdown -ManifestRows $candidateRows -ArchiveBlobSha $candidateArchive.Identity -ArchiveRawFileSha256 (Get-Sha256Hex -Bytes $candidateArchive.Bytes))
    Write-TextFileLfNoBom -Path (Join-Path $artifactRoot 'RECONCILE_EXCEPTIONS.md') -Text (Build-ExceptionsMarkdown -Report $candidateReport)
    Invoke-GitRaw -RepoRoot $Dir -Arguments 'add -- docs/memory_control/ARCHIVE_MANIFEST.csv docs/memory_control/ARCHIVE_INDEX.md docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null
}

function New-RealHookFixture {
    <# Real HEAD data + candidate hook/checkers, with a temp-only check_state stub.
       Refresh and commit generated artifacts before enabling the hook so each
       artifact-only/active-only case starts from a genuinely consistent base. #>
    param([string]$Tag)
    $dir = New-RealWorkingTreeFixture -Tag $Tag
    'exit 0' | Set-Content -Path (Join-Path $dir 'scripts\check_state.ps1') -Encoding UTF8
    Write-StagedArtifactsForHookRepo -Dir $dir
    # --allow-empty: when HEAD's committed artifacts are already generator-fresh
    # (true since 2026-07-16), the regenerated candidates are byte-identical and
    # `git add` stages nothing -- a plain commit then exits 1 ("nothing to
    # commit") and this fixture dies before any case runs. The baseline only
    # needs a commit point on a consistent base, so an empty commit is correct.
    $baselineCommit = Invoke-GitRaw -RepoRoot $dir -Arguments 'commit -q --allow-empty -m "temp baseline: refresh generated artifacts"'
    if ($baselineCommit.ExitCode -ne 0) { throw "real hook fixture baseline commit failed: $($baselineCommit.StdErr)" }
    Enable-TempHook -Dir $dir
    return $dir
}

# --- ordinary commit (touches no protected file) must PASS ---
$hookRepoOrdinary = New-TempHookRepo -Tag 'fix2_ordinary'
Write-CommitFile -Dir $hookRepoOrdinary -RelPath 'scripts\check_taskboard_archive.ps1' -Content ((Get-Content (Join-Path $RepoRoot 'scripts\check_taskboard_archive.ps1') -Raw)) -Message 'seed' | Out-Null
$normalFile = Join-Path $hookRepoOrdinary 'src\some_code.txt'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $normalFile) | Out-Null
'hello world' | Set-Content -Path $normalFile -Encoding UTF8
Invoke-GitRaw -RepoRoot $hookRepoOrdinary -Arguments 'add -- src/some_code.txt' | Out-Null
Enable-TempHook -Dir $hookRepoOrdinary
$rOrdinary = Invoke-GitRaw -RepoRoot $hookRepoOrdinary -Arguments 'commit -q -m "ordinary code change"'
Add-Result -Name 'fix2-ordinary-commit-not-blocked' -Pass ($rOrdinary.ExitCode -eq 0) -Detail ($rOrdinary.StdOut + $rOrdinary.StdErr)

# --- protected commit with a VALID, self-consistent staged set must PASS. Build the
#     checkpoint/HEAD archive at 4aebbc37-equivalent inside this temp repo, then a
#     valid next commit that appends a clean H2 block + regenerates the 3 artifacts. ---
$hookRepoValid = New-TempHookRepo -Tag 'fix2_valid'
$initialArchive = "## Block A`nbody A`n"
$initialActive = "## ORDER-1 -- x -- ``OPEN```n"
Write-CommitFile -Dir $hookRepoValid -RelPath 'ARCHIVE_TASKBOARD_2026-07A.md' -Content $initialArchive -Message 'checkpoint archive' | Out-Null
Write-CommitFile -Dir $hookRepoValid -RelPath 'AGENT_TASKBOARD.md' -Content $initialActive -Message 'checkpoint active' | Out-Null
$initCheckpointSha = Get-GitObjectId -RepoRoot $hookRepoValid -Spec 'HEAD'   # checkpoint = commit with BOTH files present
$initHeadSha = $initCheckpointSha

# Point the temp repo's own validator instance at ITS checkpoint (the real validator's
# check_precommit_staged.ps1 hardcodes the real EA_LAB checkpoint sha, which does not
# exist in this synthetic repo -- patch a repo-local copy so the hook's chain check has
# a checkpoint it can actually resolve).
$stagedCheckerPath = Join-Path $hookRepoValid 'scripts\check_precommit_staged.ps1'
(Get-Content $stagedCheckerPath -Raw) -replace [regex]::Escape('0ced19485c6c6ce9a23541f785ab82bae4fcad25'), $initCheckpointSha | Set-Content -Path $stagedCheckerPath -Encoding UTF8
$validatorPathInRepo = Join-Path $hookRepoValid 'scripts\check_taskboard_archive.ps1'
(Get-Content $validatorPathInRepo -Raw) -replace [regex]::Escape("'0ced19485c6c6ce9a23541f785ab82bae4fcad25'"), "'$initCheckpointSha'" `
    -replace [regex]::Escape("GIT:4aebbc37\^:AGENT_TASKBOARD.md"), "GIT:$initCheckpointSha`:AGENT_TASKBOARD.md" |
    Out-Null   # (the two PreSplit/SplitActive/SplitArchive GIT:4aebbc37 refs are exercised elsewhere; patch not required for this pass/fail path since check_precommit_staged.ps1 supplies its own Split* args)
# Repoint the Split*/PreSplit sources check_precommit_staged.ps1 uses to this repo's own checkpoint.
(Get-Content $stagedCheckerPath -Raw) `
    -replace [regex]::Escape("GIT:4aebbc37^:AGENT_TASKBOARD.md"), "GIT:$initCheckpointSha`:AGENT_TASKBOARD.md" `
    -replace [regex]::Escape("GIT:4aebbc37:AGENT_TASKBOARD.md"), "GIT:$initCheckpointSha`:AGENT_TASKBOARD.md" `
    -replace [regex]::Escape("GIT:4aebbc37:ARCHIVE_TASKBOARD_2026-07A.md"), "GIT:$initCheckpointSha`:ARCHIVE_TASKBOARD_2026-07A.md" |
    Set-Content -Path $stagedCheckerPath -Encoding UTF8
Invoke-GitRaw -RepoRoot $hookRepoValid -Arguments 'add -- scripts/check_precommit_staged.ps1' | Out-Null
Invoke-GitRaw -RepoRoot $hookRepoValid -Arguments 'commit -q -m "patch checkpoint for this synthetic repo"' | Out-Null

$validNextArchive = $initialArchive + "`n## Block B`nbody B`n"
[System.IO.File]::WriteAllBytes((Join-Path $hookRepoValid 'ARCHIVE_TASKBOARD_2026-07A.md'), [System.Text.Encoding]::UTF8.GetBytes($validNextArchive))
Invoke-GitRaw -RepoRoot $hookRepoValid -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md' | Out-Null

# Build the artifacts EXACTLY the way check_precommit_staged.ps1's own regen does
# (staged identity via Get-Snapshot, not a HEAD-based Get-ArchiveContentIdentity --
# using the latter here would embed the OLD (pre-commit) HEAD blob sha into
# archive_blob_sha, which is precisely the Fix 4 mixed-source bug this order exists
# to avoid, and would make this "valid" fixture wrongly fail its own hook).
$validStagedArchive = Get-Snapshot -RepoRoot $hookRepoValid -Mode Staged -RelPath 'ARCHIVE_TASKBOARD_2026-07A.md'
$validStagedActive  = Get-Snapshot -RepoRoot $hookRepoValid -Mode Staged -RelPath 'AGENT_TASKBOARD.md'
$validActiveBlocks  = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $validStagedActive.Bytes) -SourceTag 'current-active')
$validArchiveBlocks = @(Get-ClassifiedBlocks -Text (Get-NormalizedTextFromBytes -Bytes $validStagedArchive.Bytes) -SourceTag 'current-archive')
$validScan = Invoke-ExceptionScan -CurrentActiveBlocks $validActiveBlocks -CurrentArchiveBlocks $validArchiveBlocks
$validClosure = Invoke-ExceptionClosure -PolicyExceptions $validScan.Policy -ActiveBlocks $validActiveBlocks -ArchiveBlocks $validArchiveBlocks
$validReport = [ordered]@{
    PolicyExceptions = @($validScan.Policy); CanonicallyReviewed = @($validClosure.Reviewed)
    UnresolvedPolicyExceptions = @($validClosure.Unresolved); IntegrityFailures = @($validScan.Integrity) + @($validClosure.IntegrityFailures)
}
$validManifestRows = @(New-ArchiveManifestRows -CurrentArchiveBlocks $validArchiveBlocks -ArchiveBlobSha $validStagedArchive.Identity)
New-Item -ItemType Directory -Force -Path (Join-Path $hookRepoValid 'docs\memory_control') | Out-Null
Write-ArchiveManifestCsv -Rows $validManifestRows -Path (Join-Path $hookRepoValid 'docs\memory_control\ARCHIVE_MANIFEST.csv')
Write-TextFileLfNoBom -Path (Join-Path $hookRepoValid 'docs\memory_control\ARCHIVE_INDEX.md') -Text (Build-ArchiveIndexMarkdown -ManifestRows $validManifestRows -ArchiveBlobSha $validStagedArchive.Identity -ArchiveRawFileSha256 (Get-Sha256Hex -Bytes $validStagedArchive.Bytes))
Write-TextFileLfNoBom -Path (Join-Path $hookRepoValid 'docs\memory_control\RECONCILE_EXCEPTIONS.md') -Text (Build-ExceptionsMarkdown -Report $validReport)

Invoke-GitRaw -RepoRoot $hookRepoValid -Arguments 'add -- docs/memory_control/ARCHIVE_MANIFEST.csv docs/memory_control/ARCHIVE_INDEX.md docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null
Enable-TempHook -Dir $hookRepoValid
$rValid = Invoke-GitRaw -RepoRoot $hookRepoValid -Arguments 'commit -q -m "valid protected commit: append B + refresh artifacts"'
Add-Result -Name 'fix2-valid-protected-commit-passes' -Pass ($rValid.ExitCode -eq 0) -Detail ($rValid.StdOut + $rValid.StdErr)

# --- INVALID protected commit: archive changed but artifacts NOT staged -- must BLOCK ---
$hookRepoMissingArtifact = New-TempHookRepo -Tag 'fix2_missing_artifact'
Write-CommitFile -Dir $hookRepoMissingArtifact -RelPath 'ARCHIVE_TASKBOARD_2026-07A.md' -Content $initialArchive -Message 'checkpoint archive' | Out-Null
Write-CommitFile -Dir $hookRepoMissingArtifact -RelPath 'AGENT_TASKBOARD.md' -Content $initialActive -Message 'checkpoint active' | Out-Null
$cpMA = Get-GitObjectId -RepoRoot $hookRepoMissingArtifact -Spec 'HEAD'   # checkpoint = commit with BOTH files present
$scMA = Join-Path $hookRepoMissingArtifact 'scripts\check_precommit_staged.ps1'
(Get-Content $scMA -Raw) `
    -replace [regex]::Escape('0ced19485c6c6ce9a23541f785ab82bae4fcad25'), $cpMA `
    -replace [regex]::Escape("GIT:4aebbc37^:AGENT_TASKBOARD.md"), "GIT:$cpMA`:AGENT_TASKBOARD.md" `
    -replace [regex]::Escape("GIT:4aebbc37:AGENT_TASKBOARD.md"), "GIT:$cpMA`:AGENT_TASKBOARD.md" `
    -replace [regex]::Escape("GIT:4aebbc37:ARCHIVE_TASKBOARD_2026-07A.md"), "GIT:$cpMA`:ARCHIVE_TASKBOARD_2026-07A.md" |
    Set-Content -Path $scMA -Encoding UTF8
Invoke-GitRaw -RepoRoot $hookRepoMissingArtifact -Arguments 'add -- scripts/check_precommit_staged.ps1' | Out-Null
Invoke-GitRaw -RepoRoot $hookRepoMissingArtifact -Arguments 'commit -q -m "patch checkpoint"' | Out-Null
$badNextArchive = $initialArchive + "`n## Block B`nbody B`n"
[System.IO.File]::WriteAllBytes((Join-Path $hookRepoMissingArtifact 'ARCHIVE_TASKBOARD_2026-07A.md'), [System.Text.Encoding]::UTF8.GetBytes($badNextArchive))
Invoke-GitRaw -RepoRoot $hookRepoMissingArtifact -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md' | Out-Null
Enable-TempHook -Dir $hookRepoMissingArtifact
$rMissing = Invoke-GitRaw -RepoRoot $hookRepoMissingArtifact -Arguments 'commit -q -m "archive changed, forgot artifacts"'
Add-Result -Name 'fix2-archive-changed-without-artifacts-blocks' -Pass ($rMissing.ExitCode -ne 0) -Detail ($rMissing.StdOut + $rMissing.StdErr)

# --- INVALID protected commit: staged archive mutates an earlier block -- must BLOCK ---
$hookRepoMutate = New-TempHookRepo -Tag 'fix2_mutate'
Write-CommitFile -Dir $hookRepoMutate -RelPath 'ARCHIVE_TASKBOARD_2026-07A.md' -Content $initialArchive -Message 'checkpoint archive' | Out-Null
Write-CommitFile -Dir $hookRepoMutate -RelPath 'AGENT_TASKBOARD.md' -Content $initialActive -Message 'checkpoint active' | Out-Null
$cpMut = Get-GitObjectId -RepoRoot $hookRepoMutate -Spec 'HEAD'
$scMut = Join-Path $hookRepoMutate 'scripts\check_precommit_staged.ps1'
(Get-Content $scMut -Raw) -replace [regex]::Escape('0ced19485c6c6ce9a23541f785ab82bae4fcad25'), $cpMut | Set-Content -Path $scMut -Encoding UTF8
Invoke-GitRaw -RepoRoot $hookRepoMutate -Arguments 'add -- scripts/check_precommit_staged.ps1' | Out-Null
Invoke-GitRaw -RepoRoot $hookRepoMutate -Arguments 'commit -q -m "patch checkpoint"' | Out-Null
$mutatedArchive = "## Block A`nBODY A MUTATED`n"
[System.IO.File]::WriteAllBytes((Join-Path $hookRepoMutate 'ARCHIVE_TASKBOARD_2026-07A.md'), [System.Text.Encoding]::UTF8.GetBytes($mutatedArchive))
Invoke-GitRaw -RepoRoot $hookRepoMutate -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md' | Out-Null
# Stage a complete set of artifacts generated from the mutated candidate. The
# chain/mutation guard -- not the missing-artifact gate -- must be the blocker.
Write-StagedArtifactsForHookRepo -Dir $hookRepoMutate
Enable-TempHook -Dir $hookRepoMutate
$rMutate = Invoke-GitRaw -RepoRoot $hookRepoMutate -Arguments 'commit -q -m "mutate staged archive"'
$mutateOutput = $rMutate.StdOut + $rMutate.StdErr
Add-Result -Name 'fix2-staged-archive-mutation-blocks' `
    -Pass (($rMutate.ExitCode -ne 0) -and ($mutateOutput -match 'fails append-chain integrity') -and ($mutateOutput -notmatch 'required artifact\(s\) not staged')) `
    -Detail $mutateOutput

# BLOCKER 1 regressions: a protected artifact or active-board change must trigger
# the full staged consistency check even when the archive blob itself is unchanged.
$hookRepoArtifactOnly = New-RealHookFixture -Tag 'fix2_artifact_only'
$artifactOnlyPath = Join-Path $hookRepoArtifactOnly 'docs\memory_control\RECONCILE_EXCEPTIONS.md'
[System.IO.File]::AppendAllText($artifactOnlyPath, "`nTAMPER-ARTIFACT-ONLY`n", [System.Text.Encoding]::UTF8)
Invoke-GitRaw -RepoRoot $hookRepoArtifactOnly -Arguments 'add -- docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null
$rArtifactOnly = Invoke-GitRaw -RepoRoot $hookRepoArtifactOnly -Arguments 'commit -q -m "tamper artifact only"'
$artifactOnlyOutput = $rArtifactOnly.StdOut + $rArtifactOnly.StdErr
Add-Result -Name 'fix2-artifact-only-change-blocks' `
    -Pass (($rArtifactOnly.ExitCode -ne 0) -and ($artifactOnlyOutput -match 'staged artifact\(s\) inconsistent')) `
    -Detail $artifactOnlyOutput

# Byte-exact artifact comparison: with clean filtering disabled, an EOL-only
# staged artifact mutation must produce a different blob and be blocked.
$hookRepoArtifactEol = New-RealHookFixture -Tag 'fix2_artifact_eol_only'
Invoke-GitRaw -RepoRoot $hookRepoArtifactEol -Arguments 'config core.autocrlf false' | Out-Null
$artifactEolPath = Join-Path $hookRepoArtifactEol 'docs\memory_control\RECONCILE_EXCEPTIONS.md'
$artifactEolText = [System.IO.File]::ReadAllText($artifactEolPath, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`n", "`r")
[System.IO.File]::WriteAllBytes($artifactEolPath, [System.Text.Encoding]::UTF8.GetBytes($artifactEolText))
Invoke-GitRaw -RepoRoot $hookRepoArtifactEol -Arguments 'add -- docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null
$rArtifactEol = Invoke-GitRaw -RepoRoot $hookRepoArtifactEol -Arguments 'commit -q -m "tamper artifact EOL bytes only"'
$artifactEolOutput = $rArtifactEol.StdOut + $rArtifactEol.StdErr
Add-Result -Name 'fix2-artifact-eol-byte-change-blocks' `
    -Pass (($rArtifactEol.ExitCode -ne 0) -and ($artifactEolOutput -match 'byte-identical')) `
    -Detail $artifactEolOutput

$hookRepoActiveOnly = New-RealHookFixture -Tag 'fix2_active_only'
$activeOnlyPath = Join-Path $hookRepoActiveOnly 'AGENT_TASKBOARD.md'
$activeOnlyText = [System.IO.File]::ReadAllText($activeOnlyPath, [System.Text.Encoding]::UTF8)
# ORDER-071 already exists in the committed archive. Reintroducing it on the
# active board creates a cross-active-and-archive exception that post-commit
# Strict would reject unless the hook evaluates the staged active snapshot.
[System.IO.File]::WriteAllText($activeOnlyPath, ($activeOnlyText + "`n## ORDER-071 -- DUPLICATED-TAMPER -- ``OPEN```n"), (New-Object System.Text.UTF8Encoding($false)))
Invoke-GitRaw -RepoRoot $hookRepoActiveOnly -Arguments 'add -- AGENT_TASKBOARD.md' | Out-Null
$rActiveOnly = Invoke-GitRaw -RepoRoot $hookRepoActiveOnly -Arguments 'commit -q -m "tamper active only"'
$activeOnlyOutput = $rActiveOnly.StdOut + $rActiveOnly.StdErr
Add-Result -Name 'fix2-active-only-change-blocks' `
    -Pass (($rActiveOnly.ExitCode -ne 0) -and ($activeOnlyOutput -match 'staged artifact\(s\) inconsistent|full candidate consistency')) `
    -Detail $activeOnlyOutput

# A staged deletion of any protected file is rejected before snapshot reads.
$hookRepoDelete = New-RealHookFixture -Tag 'fix2_protected_delete'
Invoke-GitRaw -RepoRoot $hookRepoDelete -Arguments 'rm -q -- docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null
$rProtectedDelete = Invoke-GitRaw -RepoRoot $hookRepoDelete -Arguments 'commit -q -m "delete protected file"'
$protectedDeleteOutput = $rProtectedDelete.StdOut + $rProtectedDelete.StdErr
Add-Result -Name 'fix2-protected-file-deleted-blocks' `
    -Pass (($rProtectedDelete.ExitCode -ne 0) -and ($protectedDeleteOutput -match "protected file 'docs/memory_control/RECONCILE_EXCEPTIONS.md'.*DELETION")) `
    -Detail $protectedDeleteOutput

# Rename detection intentionally asks Git for --no-renames, so a protected rename
# is represented as deletion of the protected source plus an ordinary added path.
$hookRepoRename = New-RealHookFixture -Tag 'fix2_protected_rename'
Invoke-GitRaw -RepoRoot $hookRepoRename -Arguments 'mv -- AGENT_TASKBOARD.md AGENT_TASKBOARD_RENAMED.md' | Out-Null
$rProtectedRename = Invoke-GitRaw -RepoRoot $hookRepoRename -Arguments 'commit -q -m "rename protected file"'
$protectedRenameOutput = $rProtectedRename.StdOut + $rProtectedRename.StdErr
Add-Result -Name 'fix2-protected-file-renamed-blocks' `
    -Pass (($rProtectedRename.ExitCode -ne 0) -and ($protectedRenameOutput -match "protected file 'AGENT_TASKBOARD.md'.*DELETION")) `
    -Detail $protectedRenameOutput

# Mixing an ordinary staged file with an inconsistent protected artifact remains
# blocked for the protected inconsistency; the ordinary path is not a block reason.
$hookRepoMixed = New-RealHookFixture -Tag 'fix2_mixed_protected_ordinary'
$mixedProtectedPath = Join-Path $hookRepoMixed 'docs\memory_control\RECONCILE_EXCEPTIONS.md'
[System.IO.File]::AppendAllText($mixedProtectedPath, "`nINCONSISTENT-PROTECTED-CONTENT`n", [System.Text.Encoding]::UTF8)
New-Item -ItemType Directory -Force -Path (Join-Path $hookRepoMixed 'src') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $hookRepoMixed 'src\ordinary.txt'), "ordinary staged content`n", [System.Text.Encoding]::UTF8)
Invoke-GitRaw -RepoRoot $hookRepoMixed -Arguments 'add -- docs/memory_control/RECONCILE_EXCEPTIONS.md src/ordinary.txt' | Out-Null
$rMixed = Invoke-GitRaw -RepoRoot $hookRepoMixed -Arguments 'commit -q -m "mixed protected and ordinary staging"'
$mixedOutput = $rMixed.StdOut + $rMixed.StdErr
Add-Result -Name 'fix2-mixed-protected-and-ordinary-staging-blocks-on-protected-only' `
    -Pass (($rMixed.ExitCode -ne 0) -and ($mixedOutput -match 'staged artifact\(s\) inconsistent') -and ($mixedOutput -match 'RECONCILE_EXCEPTIONS.md') -and ($mixedOutput -notmatch 'BLOCK:.*ordinary.txt')) `
    -Detail $mixedOutput

# --- no-PS fail-closed + exact diagnostic string (simulate by stripping PATH of any
#     dir containing powershell.exe/pwsh for the child git-commit process only) ---
$hookRepoNoPs = New-TempHookRepo -Tag 'fix2_nops'
Write-CommitFile -Dir $hookRepoNoPs -RelPath 'src\x.txt' -Content 'x' -Message 'seed' | Out-Null
'y' | Set-Content -Path (Join-Path $hookRepoNoPs 'src\x.txt') -Encoding UTF8
Invoke-GitRaw -RepoRoot $hookRepoNoPs -Arguments 'add -- src/x.txt' | Out-Null
Enable-TempHook -Dir $hookRepoNoPs
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = 'git'
$psi.Arguments = 'commit -q -m "no ps available"'
$psi.WorkingDirectory = $hookRepoNoPs
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
# Rebuild PATH excluding any directory containing powershell.exe or pwsh.exe.
$origPathDirs = $env:PATH -split ';'
$filteredDirs = @($origPathDirs | Where-Object {
    $d = $_
    if (-not $d) { return $true }
    -not ((Test-Path (Join-Path $d 'powershell.exe')) -or (Test-Path (Join-Path $d 'pwsh.exe')))
})
$psi.EnvironmentVariables['PATH'] = ($filteredDirs -join ';')
$proc = [System.Diagnostics.Process]::Start($psi)
$noPsStdout = $proc.StandardOutput.ReadToEnd()
$noPsStderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()
$noPsBlocked = ($proc.ExitCode -ne 0)
$noPsDiagnosticPresent = ($noPsStdout + $noPsStderr) -match 'PRECOMMIT-FAIL-CLOSED: PowerShell not found'
Add-Result -Name 'fix2-no-powershell-fails-closed-with-exact-diagnostic' -Pass ($noPsBlocked -and $noPsDiagnosticPresent) -Detail ("exit=$($proc.ExitCode) out=$noPsStdout err=$noPsStderr")

# BLOCKER 2 end-to-end regression: reconstruct the REAL binding transaction from
# its committed parent and the exact four blobs in the binding commit, then commit
# those blobs through the installed production hook. This remains repeatable after
# HEAD advances and proves the archive's actual ---/blank separator convention all
# the way through `git commit` without relying on a working-only candidate.
$hookRepoBinding = Join-Path $scratchRoot 'fix2_real_binding_commit'
$cloneBinding = Invoke-GitRaw -RepoRoot $scratchRoot -Arguments ('-c core.longpaths=true clone -q --no-local -- "{0}" "{1}"' -f $RepoRoot, $hookRepoBinding)
if ($cloneBinding.ExitCode -ne 0) { throw "binding fixture clone failed: $($cloneBinding.StdErr)" }
Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments 'config user.email test@example.com' | Out-Null
Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments 'config user.name "order103 test"' | Out-Null
Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments 'config core.autocrlf true' | Out-Null

$bindingLog = Invoke-GitRaw -RepoRoot $RepoRoot -Arguments 'log -1 --format=%H --grep="ORDER-103 C1-ENFORCE: append Source-A exact-identity binding"'
$bindingSha = $bindingLog.StdOut.Trim()
if ($bindingLog.ExitCode -ne 0 -or -not $bindingSha) { throw 'real ORDER-103 binding commit not found in source history' }
$bindingParent = (Invoke-GitRaw -RepoRoot $RepoRoot -Arguments ('rev-parse "{0}^"' -f $bindingSha)).StdOut.Trim()
$checkoutParent = Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments ('checkout -q "{0}"' -f $bindingParent)
if ($checkoutParent.ExitCode -ne 0) { throw "binding parent checkout failed: $($checkoutParent.StdErr)" }

foreach ($rel in @('.githooks/pre-commit','scripts/check_taskboard_archive.ps1','scripts/check_precommit_staged.ps1','scripts/check_experiment_events.ps1','scripts/experiment_event_log.ps1')) {
    $dest = Join-Path $hookRepoBinding $rel
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath (Join-Path $RepoRoot $rel) -Destination $dest -Force
}
[System.IO.File]::WriteAllText((Join-Path $hookRepoBinding 'scripts\check_verdict_kill.ps1'),'exit 0',(New-Object System.Text.UTF8Encoding($false)))
foreach ($rel in @('ARCHIVE_TASKBOARD_2026-07A.md','docs/memory_control/ARCHIVE_MANIFEST.csv','docs/memory_control/ARCHIVE_INDEX.md','docs/memory_control/RECONCILE_EXCEPTIONS.md')) {
    $dest = Join-Path $hookRepoBinding $rel
    $parent = Split-Path -Parent $dest
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllBytes($dest, (Get-GitBlobBytes -RepoRoot $RepoRoot -Ref $bindingSha -Path $rel))
}

Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments 'config core.hooksPath .githooks' | Out-Null
Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments 'add -- ARCHIVE_TASKBOARD_2026-07A.md docs/memory_control/ARCHIVE_MANIFEST.csv docs/memory_control/ARCHIVE_INDEX.md docs/memory_control/RECONCILE_EXCEPTIONS.md' | Out-Null
# The binding archive blob is the real transaction, while the operator-facing
# generated text must reflect the current exact-binding documentation.
Write-StagedArtifactsForHookRepo -Dir $hookRepoBinding
$rBindingCommit = Invoke-GitRaw -RepoRoot $hookRepoBinding -Arguments 'commit -m "real ORDER-103 binding candidate"'
$bindingCommitOutput = $rBindingCommit.StdOut + $rBindingCommit.StdErr
Add-Result -Name 'fix2-real-commit-of-binding-through-hook-passes' `
    -Pass (($rBindingCommit.ExitCode -eq 0) -and ($bindingCommitOutput -match '\[precommit-staged\] PASS')) `
    -Detail ("exit={0} output={1}" -f $rBindingCommit.ExitCode, ($bindingCommitOutput.Trim() -replace "`r?`n", ' | '))

# ============================================================================
Write-Host ''
Write-Host '=== ORDER-103 negative test suite results ==='
$allPass = $true
foreach ($r in $results) {
    $status = if ($r.Pass) { 'PASS' } else { $allPass = $false; 'FAIL' }
    Write-Host ("[{0}] {1,-65} {2}" -f $status, $r.Name, $r.Detail)
}
Write-Host ''
if ($allPass) {
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
