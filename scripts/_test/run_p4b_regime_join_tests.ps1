$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $RepoRoot 'scripts\use_python.ps1')
$py=Assert-PortablePython -Root $RepoRoot -Provision
$test=Join-Path $RepoRoot 'tools\p4b_unit_attribution\tests\test_broad36_regime_join.py'
& $py $test -v
if($LASTEXITCODE -ne 0){throw "Boss19 P4B regime join tests failed exit=$LASTEXITCODE"}
Write-Output '[PASS] Boss19 P4B regime join tests passed'
