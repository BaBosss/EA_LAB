[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
. (Join-Path $RepoRoot 'scripts/use_python.ps1')
$b21Python = Assert-PortablePython -Root $RepoRoot -Provision
& $b21Python -B (Join-Path $RepoRoot 'tools/df03_compat/test_b21.py')
exit $LASTEXITCODE
