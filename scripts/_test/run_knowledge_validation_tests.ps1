[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) {
    $here = $PSScriptRoot
    if (-not $here -and $MyInvocation.MyCommand.Path) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    if (-not $here) { throw 'cannot resolve script directory; pass -RepoRoot explicitly' }
    $RepoRoot = Split-Path -Parent (Split-Path -Parent $here)
}

& (Join-Path $RepoRoot 'scripts\check_second_brain.ps1') -Root $RepoRoot -KnowledgeOnly
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$python = Assert-PortablePython -Root $RepoRoot
$tests = Join-Path $RepoRoot 'tools\knowledge_validation\tests'
& $python -m unittest discover -s $tests -p 'test_*.py' -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '[PASS] knowledge handoff and offline guard replay validation tests passed'
exit 0
