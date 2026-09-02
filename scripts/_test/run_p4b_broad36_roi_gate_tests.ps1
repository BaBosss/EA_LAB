$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\use_python.ps1')
$py = Assert-PortablePython -Root $root -Provision
$tests = Join-Path $root 'tools\p4b_unit_attribution\tests'
& $py -m unittest discover -s $tests -p 'test_broad36_roi_gate.py' -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host '[PASS] Boss19 P4 broad36 ROI gate focused tests passed'
exit 0
