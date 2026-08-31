$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$py='C:\Users\patip\.local\bin\python.exe'
if(-not (Test-Path -LiteralPath $py)){throw 'system Python unavailable'}
& $py -m unittest discover -s (Join-Path $root 'tools\boss19_p4b_timeline\tests') -p 'test_*.py' -v
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
Write-Host 'PASS Boss19 P4 timeline tests'
