<#
run_portable_python_tests.ps1 - S1 fresh-worktree portable-Python preflight.

The archive is intentionally ignored, so a clean linked worktree can contain python.exe while
still being unable to import encodings. The production fast-tier runner provisions from the
approved common checkout before it launches cages; this test locks both the valid path and the
precise failure when no archive is available.
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

try {
    $exe = Assert-PortablePython -Root $RepoRoot
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

Write-Host ("portable-python {0}/{1} PASS" -f $pass, ($pass + $fail))
if ($fail) { exit 1 }
exit 0
