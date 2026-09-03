[CmdletBinding()]
param([string]$RepoRoot = '')
$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$python = Assert-PortablePython -Root $RepoRoot -Provision
$test = Join-Path $RepoRoot 'tools\reporting\tests\test_post_broad_diagnostic_pack.py'
& $python -W error $test
if ($LASTEXITCODE -ne 0) { throw "post-broad diagnostic pack tests failed exit=$LASTEXITCODE" }
Write-Host '[PASS] post-broad diagnostic pack focused suite'
exit 0
