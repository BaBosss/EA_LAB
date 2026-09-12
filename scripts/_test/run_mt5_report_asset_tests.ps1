[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\use_python.ps1')
$pythonExe = Assert-PortablePython -Root $root -Provision

& $pythonExe -m py_compile `
    (Join-Path $root 'tools\reporting\mt5_report_assets.py') `
    (Join-Path $root 'tools\reporting\tests\test_mt5_report_assets.py')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $pythonExe -m unittest discover `
    -s (Join-Path $root 'tools\reporting\tests') -p 'test_mt5_report_assets.py' -v
exit $LASTEXITCODE
