<#
run_portable_python_tests.ps1 - S1 fresh-worktree portable-Python preflight.

The archive is intentionally ignored, so a clean linked worktree can contain python.exe while
still being unable to import encodings. The production fast-tier runner provisions from the
approved common checkout before it launches cages; this test locks both the valid path and the
precise failure when no archive is available.

PART 3/4 (2026-08-18) lock the pre-commit integration: a newly created linked worktree hydrates
itself through Assert-PortablePython -Provision (the same call .githooks/pre-commit now makes
before check_attested_pin_staged.py), and a source checkout without the archive fails loudly.
Scope note: this covers CURRENT LINKED-WORKTREE OPERABILITY only -- a portable independent fresh
clone (no source checkout to copy from) remains PARKED/FUTURE.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\use_python.ps1')

$pass = 0
$fail = 0
function Good([string]$Message) { $script:pass++; Write-Host "  [PASS] $Message" }
function Bad([string]$Message) { $script:fail++; Write-Host "  [FAIL] $Message" -ForegroundColor Red }

# git plumbing writes progress to stderr, and PS 5.1 turns that into a terminating
# NativeCommandError under $ErrorActionPreference='Stop' (neither 2>&1 nor 2>$null
# prevents it). Relax EAP around the call and discard stderr; only the exit code matters.
function Invoke-GitPlumbing {
    param([string[]]$GitArgs)
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $null = & git @GitArgs 2>$null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
    return $code
}

try {
    $exe = Assert-PortablePython -Root $RepoRoot -Provision
    if ($exe -and (Test-Path -LiteralPath (Join-Path $RepoRoot 'tools\python312\python312.zip') -PathType Leaf)) {
        Good 'a provisioned portable runtime imports encodings'
    } else {
        Bad 'a provisioned portable runtime did not expose its stdlib archive'
    }
} catch {
    Bad ("the provisioned runtime was rejected: {0}" -f $_.Exception.Message)
}

$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ('portable_python_missing_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path (Join-Path $fixture 'tools\python312') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'tools\python312\python.exe') `
              -Destination (Join-Path $fixture 'tools\python312\python.exe') -Force
    try {
        [void](Assert-PortablePython -Root $fixture)
        Bad 'a runtime without python312.zip was accepted'
    } catch {
        $message = $_.Exception.Message
        if ($message -match 'python312\.zip' -and $message -match 'stdlib archive') {
            Good 'a missing python312.zip is refused with an actionable prerequisite'
        } else {
            Bad ("missing archive refusal was not specific: {0}" -f $message)
        }
    }
} finally {
    if (Test-Path -LiteralPath $fixture) {
        Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# PART 3: a newly created linked worktree provisions itself the way the pre-commit hook does.
# Root the worktree beside the checkout, not under %TEMP%: the repo tracks paths over 180
# characters, and the default temp prefix pushes the longest one past Windows MAX_PATH
# (git: "Filename too long"). The parent of the checkout root is short in both real
# contexts -- C:\ea_lab_tmp under the fast tier's staged snapshot, D:\EA_LAB\.worktrees
# for a manual run -- and already exists.
$wt = Join-Path (Split-Path $RepoRoot -Parent) ('pyguard_wt_' + [guid]::NewGuid().ToString('N'))
try {
    $code = Invoke-GitPlumbing -GitArgs @('-C', $RepoRoot, 'worktree', 'add', '--detach', $wt, 'HEAD')
    if ($code -ne 0) {
        Bad 'git worktree add failed for the regression worktree'
    } else {
        $wtExe = Join-Path $wt 'tools\python312\python.exe'
        $wtZip = Join-Path $wt 'tools\python312\python312.zip'
        if (-not (Test-Path -LiteralPath $wtExe -PathType Leaf)) {
            Bad 'the fresh linked worktree did not materialize the tracked python.exe'
        } else {
            Good 'a fresh linked worktree contains the tracked python.exe'
        }
        if (Test-Path -LiteralPath $wtZip -PathType Leaf) {
            Remove-Item -LiteralPath $wtZip -Force
        }
        if (Test-Path -LiteralPath $wtZip) {
            Bad 'the fresh linked worktree unexpectedly contained python312.zip'
        } else {
            Good 'the fresh linked worktree is structurally missing the ignored python312.zip'
        }
        try {
            $wtExe2 = Assert-PortablePython -Root $wt -Provision
            if ((Test-Path -LiteralPath $wtZip -PathType Leaf) -and $wtExe2) {
                Good 'Assert-PortablePython -Provision hydrated the worktree from the source checkout'
            } else {
                Bad 'provisioning returned but the worktree still lacks python312.zip'
            }
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $probe = @(& $wtExe -c 'import encodings' 2>&1)
            $ErrorActionPreference = $prevEap
            if ($LASTEXITCODE -eq 0) {
                Good 'the hydrated worktree runtime imports encodings'
            } else {
                Bad ("the hydrated worktree runtime still cannot import encodings: {0}" -f (($probe | Select-Object -Last 3) -join ' '))
            }
            Push-Location $wt
            try {
                $prevEap = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                $guard = @(& $wtExe '_triage/factory_os/check_attested_pin_staged.py' 2>&1)
                $ErrorActionPreference = $prevEap
                if ($LASTEXITCODE -eq 0) {
                    Good 'the mandatory check_attested_pin_staged.py executes in the hydrated worktree'
                } else {
                    Bad ("check_attested_pin_staged.py failed in the hydrated worktree: {0}" -f (($guard | Select-Object -Last 3) -join ' '))
                }
            } finally {
                Pop-Location
            }
        } catch {
            Bad ("worktree provisioning threw: {0}" -f $_.Exception.Message)
        }
    }
} finally {
    if (Test-Path -LiteralPath $wt) {
        [void](Invoke-GitPlumbing -GitArgs @('-C', $RepoRoot, 'worktree', 'remove', '--force', $wt))
    }
    [void](Invoke-GitPlumbing -GitArgs @('-C', $RepoRoot, 'worktree', 'prune'))
}

# PART 4: a source checkout without the archive fails loudly (no silent fallback).
$fix = Join-Path ([System.IO.Path]::GetTempPath()) ('pyguard_fix_' + [guid]::NewGuid().ToString('N'))
$fixWt = Join-Path ([System.IO.Path]::GetTempPath()) ('pyguard_fixwt_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path (Join-Path $fix 'tools\python312') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'tools\python312\python.exe') `
              -Destination (Join-Path $fix 'tools\python312\python.exe') -Force
    [void](Invoke-GitPlumbing -GitArgs @('-C', $fix, 'init', '-q'))
    [void](Invoke-GitPlumbing -GitArgs @('-C', $fix, 'add', 'tools/python312/python.exe'))
    [void](Invoke-GitPlumbing -GitArgs @('-C', $fix, '-c', 'user.name=pyguard-test', '-c', 'user.email=pyguard@test', 'commit', '-qm', 'fixture'))
    [void](Invoke-GitPlumbing -GitArgs @('-C', $fix, 'worktree', 'add', '--detach', $fixWt, 'HEAD'))
    try {
        [void](Assert-PortablePython -Root $fixWt -Provision)
        Bad 'a source checkout without python312.zip was accepted by -Provision'
    } catch {
        $message = $_.Exception.Message
        if ($message -match 'python312\.zip' -and $message -match 'stdlib archive') {
            Good 'a missing source-runtime archive is refused with an actionable prerequisite'
        } else {
            Bad ("missing source archive refusal was not specific: {0}" -f $message)
        }
    }
} finally {
    if (Test-Path -LiteralPath $fixWt) {
        [void](Invoke-GitPlumbing -GitArgs @('-C', $fix, 'worktree', 'remove', '--force', $fixWt))
    }
    [void](Invoke-GitPlumbing -GitArgs @('-C', $fix, 'worktree', 'prune'))
    if (Test-Path -LiteralPath $fix) {
        Remove-Item -LiteralPath $fix -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ("portable-python {0}/{1} PASS" -f $pass, ($pass + $fail))
if ($fail) { exit 1 }
exit 0
