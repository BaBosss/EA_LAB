# run_status_publisher_root_tests.ps1 - the status-publisher decision (A10 pilot P1 option a).
# Proves: only the recorded root publishes; missing/blank/relative records publish nowhere; the
# explicit test override still wins; publish_status.ps1 refuses a missing publisher without -Create.
# Everything runs under the system temp dir; no checkout, OneDrive or git state is touched.
# Continue, not Stop: child refusals write to stderr, which PS 5.1 turns into terminating errors under Stop.
$ErrorActionPreference = 'Continue'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $RepoRoot 'scripts\lib\repo_paths.ps1')
$pass = 0; $fail = 0
function Assert-Equal([string]$name, $expected, $actual) {
    if ($expected -eq $actual) { $script:pass++; Write-Host "  [PASS] $name" }
    else { $script:fail++; Write-Host "  [FAIL] $name -- expected '$expected', got '$actual'" }
}
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('statuspub_' + [guid]::NewGuid().ToString('N').Substring(0, 10))
$repo = Join-Path $tmp 'repo'
New-Item -ItemType Directory -Force (Join-Path $repo 'scripts') | Out-Null
$rec = Join-Path $repo 'scripts\status_publisher_root.txt'
try {
    Write-Host '=== recorded root ==='
    Assert-Equal 'missing record -> no publisher' '' (Get-EaLabStatusPublisherRoot -RepoRoot $repo)
    Assert-Equal 'missing record -> repo does not publish' $false (Test-EaLabStatusPublisher -Repo $repo)
    Set-Content -LiteralPath $rec -Value '   '
    Assert-Equal 'blank record -> no publisher' '' (Get-EaLabStatusPublisherRoot -RepoRoot $repo)
    Set-Content -LiteralPath $rec -Value 'relative\path'
    Assert-Equal 'relative record -> no publisher' '' (Get-EaLabStatusPublisherRoot -RepoRoot $repo)
    Set-Content -LiteralPath $rec -Value ($repo + '\')
    Assert-Equal 'record naming this repo (trailing slash) -> publishes' $true (Test-EaLabStatusPublisher -Repo $repo)
    Set-Content -LiteralPath $rec -Value 'D:\EA_LAB_CONTROL\w\status-publisher'
    Assert-Equal 'record naming another root -> this repo does not publish' $false (Test-EaLabStatusPublisher -Repo $repo)
    Assert-Equal 'primary checkout is not the recorded publisher' $false (Test-EaLabStatusPublisher -Repo 'D:\EA_LAB' -PrimaryRepoRoot (Get-EaLabStatusPublisherRoot -RepoRoot $repo))
    Write-Host '=== explicit override (tests, fake destination only) ==='
    Assert-Equal 'override equal to repo + fake destination -> publishes' $true (Test-EaLabStatusPublisher -Repo $repo -PrimaryRepoRoot $repo -RealDestination $false)
    Assert-Equal 'override elsewhere + fake destination -> does not publish' $false (Test-EaLabStatusPublisher -Repo $repo -PrimaryRepoRoot (Join-Path $tmp 'other') -RealDestination $false)
    Assert-Equal 'override equal to repo + REAL destination -> ignored, does not publish' $false (Test-EaLabStatusPublisher -Repo $repo -PrimaryRepoRoot $repo -RealDestination $true)
    Assert-Equal 'override + default (real) destination -> ignored, does not publish' $false (Test-EaLabStatusPublisher -Repo $repo -PrimaryRepoRoot $repo)
    Write-Host '=== destination classification (fail closed: only plain temp paths are fake) ==='
    Assert-Equal 'default STATUS.md path is real' $true (Test-EaLabRealOneDrivePath -Path 'C:\Users\patip\OneDrive\EA_LAB_STATUS.md')
    Assert-Equal 'sibling file in real OneDrive is real' $true (Test-EaLabRealOneDrivePath -Path 'C:\Users\patip\OneDrive\EA_LAB_STATUS.html')
    Assert-Equal '\\?\ device alias is real' $true (Test-EaLabRealOneDrivePath -Path '\\?\C:\Users\patip\OneDrive\EA_LAB_STATUS.html')
    Assert-Equal 'FileSystem:: provider alias is real' $true (Test-EaLabRealOneDrivePath -Path 'FileSystem::C:\Users\patip\OneDrive\EA_LAB_STATUS.md')
    Assert-Equal 'UNC path is real' $true (Test-EaLabRealOneDrivePath -Path '\\localhost\C$\Users\patip\OneDrive\x.md')
    Assert-Equal 'relative path is real' $true (Test-EaLabRealOneDrivePath -Path 'OneDrive\x.md')
    Assert-Equal 'non-temp plain path elsewhere is real' $true (Test-EaLabRealOneDrivePath -Path 'D:\somewhere\EA_LAB_STATUS.md')
    Assert-Equal 'plain temp fake destination is fake' $false (Test-EaLabRealOneDrivePath -Path (Join-Path $tmp 'fake\EA_LAB_STATUS.md'))
    Assert-Equal 'temp path escaping via .. is real' $true (Test-EaLabRealOneDrivePath -Path (Join-Path $tmp '..\..\..\..\Users\patip\OneDrive\x.md'))
    Write-Host '=== committed record ==='
    Assert-Equal 'this checkout records the canonical publisher worktree' 'D:\EA_LAB_CONTROL\w\status-publisher' (Get-EaLabStatusPublisherRoot -RepoRoot $RepoRoot)
    Write-Host '=== publish_status.ps1 refusals ==='
    $missing = Join-Path $tmp 'no-such-publisher'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\publish_status.ps1') -PublisherRoot $missing 2>&1 | Out-String
    Assert-Equal 'missing publisher without -Create -> exit 2' 2 $LASTEXITCODE
    Assert-Equal 'missing publisher is not created' $false (Test-Path -LiteralPath $missing)
    $plain = Join-Path $tmp 'plain-dir'; New-Item -ItemType Directory -Force $plain | Out-Null
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'scripts\publish_status.ps1') -PublisherRoot $plain 2>&1 | Out-String
    Assert-Equal 'non-worktree directory -> refused (non-zero exit)' $true ($LASTEXITCODE -ne 0)
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host ""
Write-Host "[status-publisher-root] $pass passed, $fail failed"
if ($fail) { exit 1 } else { exit 0 }
