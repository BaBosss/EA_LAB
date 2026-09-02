$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$py = Assert-PortablePython -Root $RepoRoot -Provision
$test = Join-Path $RepoRoot 'tools\p4b_unit_attribution\tests\test_broad36_prejoin.py'
& $py $test -v
if ($LASTEXITCODE -ne 0) { throw "Boss19 P4 broad36 prejoin tests failed exit=$LASTEXITCODE" }
Write-Output '[PASS] Boss19 P4 broad36 prejoin readiness tests passed'
