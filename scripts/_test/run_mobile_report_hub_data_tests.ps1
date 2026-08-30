$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\use_python.ps1')
$pythonExe = Assert-PortablePython -Root $root -Provision
& $pythonExe -m unittest discover -s (Join-Path $root 'tools\mobile_report_hub\tests') -p 'test_*.py' -v
exit $LASTEXITCODE
