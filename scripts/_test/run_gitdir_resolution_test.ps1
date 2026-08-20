<#
run_gitdir_resolution_test.ps1 - M0-LANE2 cage for Audit D-F8.

WHAT IT CAGES
  `Get-GitStateStamp` in scripts\_test\run_fast_cages.ps1, and the shared
  `Resolve-EaLabGitDir` in scripts\lib\repo_paths.ps1.

THE DEFECT, MEASURED AT CANONICAL 649207d6
  Both consumers assumed `<repo>\.git` is a DIRECTORY. In a linked worktree it is a FILE
  holding `gitdir: <path>`, so:
      Get-Content 'D:\EA_LAB_M0_L2_canonical\.git\HEAD'  ->  throws
      Get-GitStateStamp -GitDir '...\.git'               ->  head = 'UNREADABLE'
  The instrument that exists to prove "HEAD did not move during this run" was blind in exactly
  the checkouts the lanes run in. Worse than blind: 'UNREADABLE' -eq 'UNREADABLE' is TRUE, so
  `head_moved_since_tier_start` read FALSE regardless of what happened.

  A linked worktree needs TWO paths, not one. HEAD and index live in the PER-WORKTREE gitdir;
  refs/heads/* live in the COMMON dir. Resolving only the first trades 'UNREADABLE' for
  'PACKED-OR-ABSENT' and still never yields a sha - which is why this cage asserts on a 40-hex
  value and not merely on "not UNREADABLE".

BOTH DIRECTIONS ARE REQUIRED
  A fix that only ever returns a sha is not a resolver, it is a constant. So this cage also
  drives a NORMAL checkout (a throwaway `git init` repo) and asserts the same 40-hex answer
  there, and it asserts the DEFECTIVE read still fails on the linked worktree - proving the
  cage is measuring the thing that was broken, not something incidentally green.

FIXTURE HYGIENE
  The throwaway repo is created under the system temp dir, never under any EA_LAB checkout, and
  GIT_INDEX_FILE / GIT_DIR / GIT_WORK_TREE are cleared before any git runs in it (memory:
  git-index-file-poisons-fixture-repos - an inherited GIT_INDEX_FILE once deleted 5,135 entries
  from a real commit's index). No worktree is created or removed: the linked-worktree half uses
  the checkout this file is running from, which IS one.

ASCII-only on purpose (PS 5.1 reads scripts as ANSI; non-ASCII from a suite inside the hook
raises UnicodeEncodeError and the suite reports THREW instead of its verdict).
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}
$RepoRoot = ([System.IO.Path]::GetFullPath($RepoRoot)).TrimEnd('\')

$script:pass = 0
$script:fail = 0
function Assert-True {
    param([string]$Name, $Cond, [string]$Detail = '')
    if ($Cond) { $script:pass++; Write-Host ("  [PASS] {0}" -f $Name) -ForegroundColor Green }
    else {
        $script:fail++
        Write-Host ("  [FAIL] {0}" -f $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("         {0}" -f $Detail) -ForegroundColor Red }
    }
}

Write-Host '[gitdir-resolution-test] running'
Write-Host ("[gitdir-resolution-test] repo root under test: {0}" -f $RepoRoot)

# ---------------------------------------------------------------------------
# Load the two implementations. run_fast_cages.ps1 is a RUNNER, so it cannot simply be
# dot-sourced (it would execute the whole tier). Its two functions are extracted by AST -
# by name, from the parsed file, not by a text slice - and evaluated in this scope. That way
# this cage drives the SAME BYTES the runner ships, and renaming the function breaks the cage
# loudly instead of leaving it testing a private copy.
# ---------------------------------------------------------------------------
. (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1')

$cagesPath = Join-Path $RepoRoot 'scripts\_test\run_fast_cages.ps1'
Assert-True 'run_fast_cages.ps1 exists' (Test-Path -LiteralPath $cagesPath) $cagesPath
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($cagesPath, [ref]$null, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) { throw "run_fast_cages.ps1 does not parse: $($parseErrors[0].Message)" }

$wanted = @('Get-IndexPath', 'Resolve-CageGitDirs', 'Get-GitStateStamp')
$defs = @{}
foreach ($fn in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
    if ($wanted -contains $fn.Name) { $defs[$fn.Name] = $fn.Extent.Text }
}
foreach ($w in $wanted) {
    Assert-True ("run_fast_cages.ps1 still defines {0}" -f $w) ($defs.ContainsKey($w)) `
        'the cage extracts this function by name; a rename must break the cage, not silently skip it'
}
$script:GitDirMemo = @{}
foreach ($w in $wanted) { if ($defs.ContainsKey($w)) { . ([scriptblock]::Create($defs[$w])) } }

$hex40 = '^[0-9a-f]{40}$'

# ---------------------------------------------------------------------------
# A. THE DEFECT ITSELF, on this checkout. Only meaningful when this checkout really is a
#    linked worktree; when it is not, the case reports SKIPPED rather than passing for free
#    (memory: falsifier-satisfied-by-unexercised-mechanism).
# ---------------------------------------------------------------------------
$dotGit = Join-Path $RepoRoot '.git'
$isLinked = (Test-Path -LiteralPath $dotGit -PathType Leaf)
Write-Host ("[gitdir-resolution-test] this checkout is a {0}" -f $(if ($isLinked) { 'LINKED WORKTREE (.git is a FILE)' } else { 'NORMAL checkout (.git is a DIRECTORY)' }))

if ($isLinked) {
    # A1. The OLD read must still fail here. If it does not, this cage is no longer measuring
    #     the defect and its green is worthless.
    $oldHead = 'READ-OK'
    try { $oldHead = (Get-Content -LiteralPath (Join-Path $dotGit 'HEAD') -Raw -ErrorAction Stop).Trim() }
    catch { $oldHead = 'UNREADABLE' }
    Assert-True 'DEFECT CONTROL: the naive <root>\.git\HEAD read still fails on a linked worktree' `
        ($oldHead -eq 'UNREADABLE') ("naive read returned '{0}'" -f $oldHead)

    # A2. The fixed instrument must return a real sha.
    $stamp = Get-GitStateStamp -GitDir $dotGit
    Assert-True 'linked worktree: Get-GitStateStamp head is not UNREADABLE' ($stamp.head -ne 'UNREADABLE') `
        ("head='{0}'" -f $stamp.head)
    Assert-True 'linked worktree: Get-GitStateStamp ref is a 40-hex sha' ([bool]($stamp.ref -match $hex40)) `
        ("ref='{0}'" -f $stamp.ref)
    Assert-True 'linked worktree: index proxy resolves (ticks/len are not the -1 failure marker)' `
        ($stamp.index_ticks -ne -1 -and $stamp.index_len -ne -1) `
        ("index_ticks={0} index_len={1}" -f $stamp.index_ticks, $stamp.index_len)

    # A3. The sha must be the REAL HEAD, not merely well-formed. A resolver that returns a
    #     plausible constant would pass A2 and fail here.
    $realHead = (& git -C $RepoRoot rev-parse HEAD).Trim()
    Assert-True 'linked worktree: the stamped ref equals git rev-parse HEAD' ($stamp.ref -eq $realHead) `
        ("stamp='{0}' git='{1}'" -f $stamp.ref, $realHead)

    # A4. The shared library resolver agrees with git.
    $libDir = Resolve-EaLabGitDir -RepoRoot $RepoRoot
    $gitDir = ((& git -C $RepoRoot rev-parse --absolute-git-dir).Trim() -replace '/', '\').TrimEnd('\')
    Assert-True 'linked worktree: Resolve-EaLabGitDir matches git rev-parse --absolute-git-dir' `
        ($libDir -eq $gitDir) ("lib='{0}' git='{1}'" -f $libDir, $gitDir)
    Assert-True 'linked worktree: the resolved gitdir is NOT <root>\.git' ($libDir -ne $dotGit) `
        ("resolved='{0}'" -f $libDir)
} else {
    Write-Host '  [SKIPPED] linked-worktree cases: this checkout is not a linked worktree' -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# B. NORMAL CHECKOUT MUST BE UNCHANGED. A throwaway `git init` repo in the system temp dir.
# ---------------------------------------------------------------------------
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gitdircage_" + [guid]::NewGuid().ToString('N').Substring(0, 10))
$createdTmp = $false
try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $createdTmp = $true

    # THE FIXTURE TRAP. An inherited GIT_INDEX_FILE / GIT_DIR / GIT_WORK_TREE points git at the
    # PARENT process's repo, so a fixture `git add` can write the real repo's index. Cleared
    # here, restored in finally.
    $savedEnv = @{}
    foreach ($v in @('GIT_INDEX_FILE', 'GIT_DIR', 'GIT_WORK_TREE')) {
        $savedEnv[$v] = [Environment]::GetEnvironmentVariable($v)
        Remove-Item -Path ("Env:" + $v) -ErrorAction SilentlyContinue
    }
    try {
        Push-Location $tmp
        try {
            & git init --quiet 2>$null | Out-Null
            & git config user.email 'cage@example.invalid' 2>$null | Out-Null
            & git config user.name  'gitdir cage' 2>$null | Out-Null
            Set-Content -LiteralPath (Join-Path $tmp 'a.txt') -Value 'one' -Encoding ASCII
            & git add a.txt 2>$null | Out-Null
            & git commit --quiet --no-verify -m 'fixture' 2>$null | Out-Null
            $fixHead = (& git rev-parse HEAD).Trim()
        } finally { Pop-Location }

        Assert-True 'fixture repo: .git is a DIRECTORY (a normal checkout)' `
            (Test-Path -LiteralPath (Join-Path $tmp '.git') -PathType Container)
        Assert-True 'fixture repo: HEAD commit is a 40-hex sha' ([bool]($fixHead -match $hex40)) $fixHead

        $fixStamp = Get-GitStateStamp -GitDir (Join-Path $tmp '.git')
        Assert-True 'normal checkout: head reads through unchanged (a ref: line, not UNREADABLE)' `
            ($fixStamp.head -like 'ref: *') ("head='{0}'" -f $fixStamp.head)
        Assert-True 'normal checkout: ref equals the fixture HEAD sha' ($fixStamp.ref -eq $fixHead) `
            ("ref='{0}' expected='{1}'" -f $fixStamp.ref, $fixHead)
        Assert-True 'normal checkout: index proxy resolves' `
            ($fixStamp.index_ticks -ne -1 -and $fixStamp.index_len -ne -1) `
            ("index_ticks={0} index_len={1}" -f $fixStamp.index_ticks, $fixStamp.index_len)

        $fixLibDir = Resolve-EaLabGitDir -RepoRoot $tmp
        Assert-True 'normal checkout: Resolve-EaLabGitDir returns <root>\.git' `
            ($fixLibDir -eq (Join-Path $tmp '.git').TrimEnd('\')) ("got '{0}'" -f $fixLibDir)

        # C. SPECIFICITY. Handed a directory that is not in a repo at all, the resolver must
        #    REFUSE, not return a made-up path. A resolver that always answers cannot detect
        #    anything.
        #    THE FIRST DRAFT OF THIS CASE WAS WRONG and it is worth recording why: it put the
        #    non-repo directory INSIDE the fixture repo, where `git rev-parse` correctly walks up
        #    and returns the fixture's gitdir - so the case failed while the code was right. A
        #    subdirectory of a repo IS in that repo. The non-repo has to be outside every repo.
        $notRepo = Join-Path ([System.IO.Path]::GetTempPath()) ("gitdircage_norepo_" + [guid]::NewGuid().ToString('N').Substring(0, 10))
        New-Item -ItemType Directory -Path $notRepo -Force | Out-Null
        try {
            $threw = $false
            try { $null = Resolve-EaLabGitDir -RepoRoot $notRepo } catch { $threw = $true }
            Assert-True 'SPECIFICITY: Resolve-EaLabGitDir refuses a directory outside any repo' $threw `
                'it returned a path instead of throwing'
        } finally {
            Remove-Item -LiteralPath $notRepo -Recurse -Force -ErrorAction SilentlyContinue
        }

        # D. THE REINTRODUCED DEFECT, in the fixture. Replace the fixture's .git DIRECTORY with a
        #    `gitdir:` FILE pointing at it - the exact shape of a linked worktree - and prove the
        #    naive read goes RED while the resolved read stays GREEN. This is the both-directions
        #    proof for machines where this checkout is not itself a linked worktree.
        $realGit = Join-Path $tmp '.git'
        $moved   = Join-Path $tmp 'moved_gitdir'
        Move-Item -LiteralPath $realGit -Destination $moved
        Set-Content -LiteralPath $realGit -Value ("gitdir: " + $moved) -Encoding ASCII
        $script:GitDirMemo = @{}   # the memo is keyed by path; this path's shape just changed

        $naive = 'READ-OK'
        try { $naive = (Get-Content -LiteralPath (Join-Path $realGit 'HEAD') -Raw -ErrorAction Stop).Trim() }
        catch { $naive = 'UNREADABLE' }
        Assert-True 'REINTRODUCED DEFECT: naive <root>\.git\HEAD read fails on the gitdir-FILE shape' `
            ($naive -eq 'UNREADABLE') ("naive read returned '{0}'" -f $naive)

        $fixStamp2 = Get-GitStateStamp -GitDir $realGit
        Assert-True 'REINTRODUCED DEFECT: the resolved stamp still returns the real HEAD sha' `
            ($fixStamp2.ref -eq $fixHead) ("ref='{0}' expected='{1}'" -f $fixStamp2.ref, $fixHead)
        $libDir2 = Resolve-EaLabGitDir -RepoRoot $tmp
        Assert-True 'REINTRODUCED DEFECT: Resolve-EaLabGitDir follows the gitdir: file' `
            ($libDir2 -eq $moved.TrimEnd('\')) ("got '{0}' expected '{1}'" -f $libDir2, $moved)
    }
    finally {
        foreach ($v in $savedEnv.Keys) {
            if ($null -ne $savedEnv[$v]) { Set-Item -Path ("Env:" + $v) -Value $savedEnv[$v] }
        }
    }
}
finally {
    # Only what this cage created, and only under the system temp dir.
    if ($createdTmp -and $tmp -and (Test-Path -LiteralPath $tmp)) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host ("[gitdir-resolution-test] {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail -gt 0) { exit 1 }
exit 0
