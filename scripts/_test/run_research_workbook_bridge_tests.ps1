$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $root 'scripts\use_python.ps1')
$python=Assert-PortablePython -Root $root -Provision
& $python -B -X utf8 -m py_compile (Join-Path $root 'tools\research_workbook_bridge\bridge.py') (Join-Path $root 'tools\research_workbook_bridge\tests\test_bridge.py')
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
& node --check (Join-Path $root 'tools\research_workbook_bridge\validate_workbook.cjs')
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
& $python -B -X utf8 (Join-Path $root 'tools\research_workbook_bridge\tests\test_bridge.py') -v
exit $LASTEXITCODE
